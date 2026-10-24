#pragma once
// DEPTH GATES - the shore and the shallows, decided where the epoch is written (the depth-source plan,
// docs/pulse-ui/pulse-depth-source-analysis.md, 18 Oct 2026).
//
// The bottom track never says "no bottom": with no echo it returns the loudest noise of its search, which sits
// at the far end of the range (ratio 0.90 of the acquired range on a red, blue's 35 m maxDistance), and the
// dynamic scheme then sizes the range from that depth - the runaway to 45 m on the shore. These gates sit
// AROUND the algorithm, not in it: an epoch's value is tested against the epoch's own trace and stored as NaN
// when it cannot be a bottom. Every consumer (2D line, 3D, export, CSV, waypoint, readout, NMEA) reads the
// epoch, so they all inherit the one decision; and every rule is deterministic per epoch - the same epoch is
// re-published ~6 times as the window slides and must get the same answer each time.
//
// Plain C++ on purpose: tools/pulse-bt-bench/gates.py mirrors these constants and this arithmetic and scores
// them on the 18 Oct recordings (shore removed / water lost); tests/depth_gates_test.cpp compiles this header
// without Qt. Change a constant here and in gates.py together.
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <map>
#include <utility>
#include <vector>

namespace depthgates {

struct Params {
    // Gate A - geometry. A bottom beyond this fraction of the reachable end is the search edge, not a bottom.
    // Reachable end = min(maxDistance, rangeFraction x the trace's acquired range). Real bottoms in the water
    // reached 0.64 of the range on the red (only right after the scheme shrank the range), 0.39 on the blue;
    // the shore sits at 0.78-0.90.
    float gateAFraction      = 0.75f;
    float gateARangeFraction = 0.9f;
    // Gate B - echo contrast. The trace peak within +-gateBPeakM of the found bottom over the trace median past
    // gateBSkipM (the ringdown), decided by majority over the last gateBWindow epochs. Catches blue's 35 m cap,
    // which A cannot see (ratio 0.63-0.70 at 50 m).
    float gateBContrast = 1.5f;
    // B judges only a bottom beyond this fraction of the reachable end. A blue's nadir echo is weak in shallow water
    // (the side-scan returns beyond nadir raise the trace median), and in the ANDY gravel pit (3.5 m, 25 m per
    // side) B at 1.5 dashed 5% of the real bottom, in runs of up to 5 s. The false bottoms B exists for sit at
    // 0.63-0.99 of the reach (the shore, blue's 35 m cap); real bottoms at 0.15-0.5. Nearer false bottoms (the
    // second echo at 2 x, features at 3-4 x in the gravel pit) are not B's: see the analysis, section 7.
    float gateBFromFraction = 0.5f;
    int   gateBWindow   = 9;
    float gateBSkipM    = 0.4f;
    float gateBPeakM    = 0.1f;
    // P11 - the second echo (21 Oct 2026, from the ANDY gravel pit). The bottom track sometimes picks the bottom's
    // second (or third) reflection: 7 m over a 3.5 m bottom, in runs of 1-3 s, with a real if weaker echo at it, so
    // the gates cannot see it and the outlier filter can only hold it. Its signature, bench-verified on ANDY (39
    // false epochs, 0 good): the value sits at secondEchoMin-secondEchoMax x the filter's reference AND the trace has
    // an echo at HALF the distance at least as loud as at the value. Alone, the half-echo test fires on 2% of good
    // epochs and the band on none. AND the half must be the reference's bottom (within the filter's own tolerance):
    // a blue's merged side-scan trace is nearly flat (~35 everywhere in the gravel pit), so "at least as loud at
    // half" holds for a far feature at 9.85 m over a 3.65 m bottom too, and its half (4.9) is a side return, not the
    // bottom - without the match P11 fired on 100 ANDY epochs, 78 of them wrongly; with it on 47, all of them the
    // second echo. Then the half is the bottom.
    float secondEchoMin = 1.7f;
    float secondEchoMax = 3.3f;
    // The half must be the reference's bottom within a tolerance of its own, not the filter's 0.5 m: in the shallows
    // 0.5 m is everything (Max, 24 Oct: "1.21 m is a reflection of the 0.60 m bottom" with the reference at the 0.4
    // floor and the rangefinder at 1.6). And neither the reference nor the half may sit at the tracker's floor: a
    // second echo of a floor is not a measurement either (the floor values no longer reach the filter, so the
    // reference cannot be one; the guard stays as a belt).
    float secondEchoHalfAbsM = 0.05f;  // a few samples of the trace
    float secondEchoHalfRel  = 0.15f;
};

inline float reachableEnd(float maxDistance, float rangeM, const Params& p = Params())
{
    const float byRange = p.gateARangeFraction * rangeM;
    return (std::isfinite(maxDistance) && maxDistance > 0.0f) ? std::min(maxDistance, byRange) : byRange;
}

// true = reject (the far end of what the search could reach)
inline bool gateA(float bt, float maxDistance, float rangeM, const Params& p = Params())
{
    if (!std::isfinite(bt) || !(rangeM > 0.0f))
        return false;
    return bt > p.gateAFraction * reachableEnd(maxDistance, rangeM, p);
}

// The echo contrast of one epoch: peak amplitude within +-peakM of the found bottom / (median of the trace past
// skipM + 1). NaN when it cannot be computed (no bottom, bottom outside the trace, trace too short).
inline float echoContrast(const uint8_t* amp, int n, float resolution, float offsetM, float bt, const Params& p = Params())
{
    if (!amp || n <= 0 || !(resolution > 0.0f) || !std::isfinite(bt))
        return NAN;
    const int i0 = std::max(1, int((p.gateBSkipM - offsetM) / resolution));
    if (i0 >= n)
        return NAN;
    // median of amp[i0..n) through a 256-bin histogram (uint8 amplitudes)
    int hist[256] = {0};
    for (int i = i0; i < n; ++i)
        ++hist[amp[i]];
    const int body = n - i0;
    const int half = (body - 1) / 2;    // numpy's median of an even count is the mean of the two middle values;
    int acc = 0, med = 0;               // here the lower middle value - a 1-count difference on a uint8
    for (int v = 0; v < 256; ++v) {
        acc += hist[v];
        if (acc > half) { med = v; break; }
    }
    const int k = int((bt - offsetM) / resolution);
    const int w = int(p.gateBPeakM / resolution);
    const int a = std::max(0, k - w), b = std::min(n, k + w + 1);
    if (b <= a)
        return NAN;
    int peak = 0;
    for (int i = a; i < b; ++i)
        peak = std::max<int>(peak, amp[i]);
    return float(peak) / float(med + 1);
}

// P11: the refined position of the bottom's first echo when bt is a second echo of the reference, else NaN.
// amp is the trace the bottom track saw (a blue's two sides merged), ref the outlier filter's reference (NaN = none).
// floorM = minDistance + ChoiceParams::floorMargin: a reference or a half at or under it is the tracker's floor, not a bottom.
inline float secondEchoHalf(const uint8_t* amp, int n, float resolution, float offsetM, float bt, float ref, float floorM = 0.0f, const Params& p = Params())
{
    if (!amp || n <= 0 || !(resolution > 0.0f) || !std::isfinite(bt) || !std::isfinite(ref) || !(ref > 0.0f) || ref <= floorM)
        return NAN;
    const float k = bt / ref;
    if (k < p.secondEchoMin || k > p.secondEchoMax)
        return NAN;
    const int w = int(p.gateBPeakM / resolution);
    auto peakAround = [&](float m, int& at) {
        const int c = int((m - offsetM) / resolution);
        const int a = std::max(0, c - w), b = std::min(n, c + w + 1);
        int peak = -1; at = -1;
        for (int i = a; i < b; ++i)
            if (int(amp[i]) > peak) { peak = amp[i]; at = i; }
        return peak;
    };
    int atFull = -1, atHalf = -1;
    const int full = peakAround(bt, atFull);
    const int half = peakAround(bt * 0.5f, atHalf);
    if (full < 0 || half < 0 || half < full)
        return NAN;
    const float h = offsetM + atHalf * resolution;
    if (h <= floorM || std::fabs(h - ref) > std::max(p.secondEchoHalfAbsM, p.secondEchoHalfRel * ref))
        return NAN;
    return h;
}

// A percentile of the trace past skipM, through the same 256-bin histogram. -1 when there is nothing to measure.
inline int tracePercentile(const uint8_t* amp, int n, float resolution, float offsetM, int pct, const Params& p = Params())
{
    if (!amp || n <= 0 || !(resolution > 0.0f))
        return -1;
    const int i0 = std::max(1, int((p.gateBSkipM - offsetM) / resolution));
    if (i0 >= n)
        return -1;
    int hist[256] = {0};
    for (int i = i0; i < n; ++i)
        ++hist[amp[i]];
    const int body = n - i0;
    const int target = std::min(body - 1, (body * pct) / 100);
    int acc = 0;
    for (int v = 0; v < 256; ++v) {
        acc += hist[v];
        if (acc > target) return v;
    }
    return 255;
}

// Gate B's majority vote. Per epoch it remembers whether the epoch had a bottom and whether its echo was weak
// (contrast below the threshold, or not computable); reject(e) is true when, of the last gateBWindow epochs up
// to e that had a bottom, more than half were weak. A re-published epoch overwrites its own entry, so the vote
// for e depends only on epochs <= e.
class GateBVoter {
public:
    void set(int epoch, bool hasBottom, bool weak)
    {
        flags_[epoch] = uint8_t(1 | (hasBottom ? 2 : 0) | (weak ? 4 : 0));
        if (flags_.size() > 256)
            flags_.erase(flags_.begin(), flags_.lower_bound(epoch - 128));
    }
    bool reject(int epoch, const Params& p = Params()) const
    {
        auto it = flags_.find(epoch);
        if (it == flags_.end() || !(it->second & 2))
            return false;
        int n = 0, weak = 0;
        for (auto jt = flags_.lower_bound(epoch - p.gateBWindow + 1); jt != flags_.end() && jt->first <= epoch; ++jt) {
            if (!(jt->second & 2)) continue;
            ++n;
            if (jt->second & 4) ++weak;
        }
        return n > 0 && 2 * weak > n;
    }
    void clear() { flags_.clear(); }
private:
    std::map<int, uint8_t> flags_;
};

// THE CHOICE (P7) - one depth, chosen in C++ (Dataset::chooseDepth), read by the readout, NMEA and the dynamic
// scheme alike. The bottom track is the source; the rangefinder only in the shallows, where the bottom track
// is wrong rather than jittery: at its floor (minDistance + ~0.07 m) or on the second/third echo (0.44-0.85 m
// while the real depth is 0.12-0.28 m). So the switch is keyed on the RANGEFINDER - under rfEnter, back over
// rfLeave (hysteresis) - AND the bottom track must agree it is shallow: at its floor, at ~2-3 x the rangefinder,
// or no bottom. Between 0.6 and 2 m both agree, so the rangefinder buys nothing there and would add its own
// failures (its 0.12 ringdown when it loses the bottom, the blue's spikes and zeros). 0.6 m is from the red;
// the blue's number comes from the stationary test (analysis 4.1, 5.1). The shore (P8): no bottom AND the
// rangefinder steady at its ringdown (<= ringdownM) or silent - then no depth at all, at once.
struct ChoiceParams {
    float rfEnter = 0.5f;       // the rangefinder takes over under this
    float rfLeave = 0.7f;       // and hands back over this
    // "AT ITS FLOOR": bottom track <= minDistance + floorMargin. The tracker reports its floor for anything nearer
    // than it can resolve - 0.32-0.35 on a 2D, 0.34-0.43 on a blue (Max's bank, 24 Oct 2026: 0.34 and 0.40 for 100 s
    // in 20-30 cm of water, shown as a depth). A floor value is never a measurement: at the epoch write it is "no
    // bottom" (gateBottomTrackLocked), at the choice it is the bottom track AGREEING that it is shallow (the raw
    // value), so a steady rangefinder takes over and otherwise the readout dashes. 0.18 (was 0.12) takes in the
    // blue's 0.40-0.43; in every recording of 18-24 Oct no epoch under 0.43 lies in water deeper than a metre.
    float floorMargin = 0.18f;
    float secondEchoMin = 1.7f; // "a second echo": bottom track / rangefinder within this band
    float secondEchoMax = 3.3f;
    // THE RANGEFINDER'S OWN ZONE (21 Oct 2026, the stationary shallow test). Up to ringdownM a reading is unusable: the
    // red's ringdown is a crisp 0.12 and it reads 0.20-0.23 in 20 cm of water, but the black's ringdown IN THE AIR sits
    // at 0.18-0.20 for minutes (20 Oct, 20:15-20:18; the office floor 19 Oct) and the app cannot tell a red from a black.
    // So, for a 2D, a STEADY reading in (rfRingLowM, ringdownM] is "too shallow or out of the water" - no depth from
    // either source (rfVeto) - and the rangefinder takes over only above ringdownM, when steady. Below rfRingLowM it is
    // the ringdown proper: the shore state's business. In every 2D recording (18-21 Oct) the zone is entered only in
    // 10-20 cm of water and in the air.
    // THE BLUE HAS NO OWN ZONE: its rangefinder sits at a steady 0.20 over a 3.5 m bottom for 73% of the ANDY
    // recording and 3% of 18 Oct's 5-11 m - that IS its ringdown, nothing shallow about it - so for the blue the
    // zone's floor is ringdownM itself (rfRingLowBlueM) and only a steady reading above 0.25 counts. Dataset::chooseDepth
    // sets rfRingLowM from the preset.
    float ringdownM = 0.25f;    // 0.12 red; 0.12-0.14 black on the shore, 0.18-0.20 in the air; 0.12-0.23 blue
    float rfRingLowM = 0.16f;       // 2D (red / black)
    float rfRingLowBlueM = 0.25f;   // blue: = ringdownM, no zone
    // STEADY: a real reading of still water holds within a few centimetres for a second (the red at 20 cm: 0.22, 0.22,
    // 0.23; the blue at 30 cm: 0.30-0.34); a rangefinder toggling with its ringdown (0.18 / 0.30, the red at the shore
    // 20 Oct; 0.18 / 0.33, the black at 30 cm 21 Oct) does not. Entering needs rfSteadyEnterM, staying rfSteadyStayM.
    float rfSteadySeconds = 1.0f;
    float rfSteadyEnterM = 0.03f;
    float rfSteadyStayM = 0.06f;
    float rfSteadyMaxM = 1.0f;   // the rangefinder is the trusted instrument only this shallow
    // THE VETO: with the rangefinder steady on a reading, a bottom track at more than rfVetoRatio times it is not a
    // bottom (the blue in 30 cm of water: rangefinder 0.30-0.34, bottom track 10-34 m for a minute, 21 Oct); a second
    // or third echo (1.7-3.3 x) is the shallow rule's business. In a replay as live: the .plog carries the DBT
    // sentences, so the file's own rangefinder is what the steady reading sees (Olav's experts evaluate test passes
    // in the replay). A device connected during a replay mixes its rangefinder in - unplug it (8.1 item 8).
    float rfVetoRatio = 4.0f;
    // FAR NOISE: out of the water the black's rangefinder read 34-44 m for a minute, jumping by metres (20 Oct), the red's
    // 40-44 in 4 of 23 shore windows (18 Oct). A reading beyond farNoiseM that wanders by more than farNoiseSpread is
    // the device's far-end noise, not a depth - the rangefinder hears nothing, as at its ringdown. A real 35 m bottom
    // holds within a few percent.
    float farNoiseM = 30.0f;
    float farNoiseSpread = 0.15f;
    // THE SHORE STATE (19 Oct 2026, from the three-transducer run). The rangefinder at its ringdown for 1.5 s says
    // the device's own detector hears nothing; with that, the trace must be QUIET or the bottom track AT ITS FLOOR
    // for two thirds of the last second's passes. Quiet = 95th percentile of the trace past 0.4 m under quietP95:
    // red shore 20-34 / water 5th pct 51 (18 Oct: 28-59 / 70); blue shore 26-31 / water >= 47 (ANDY 3.5 m: >= 32).
    // The black cannot be quiet - its long crystal rings for metres (shore p95 136-187, louder than its water) - but
    // on the shore its bottom track sits at the floor 98% of the time (red 4%, water 4-7%: the 10-20 cm stretches,
    // where a dash is right). A 10-20 cm puddle looks the same as the shore to every instrument we have; "too
    // shallow or out of water" is the honest wording.
    // Red 60, not 40 (the office floor, 19 Oct evening): a damp transducer pressed to a damp cloth rang at p95 40-53 and
    // the 18 Oct shore reached 59; the red's water sits at 51+ (5th pct) but the state also needs the rangefinder's
    // ringdown, which water of 30 cm or more never gives, so the overlap costs nothing there.
    int   quietP95Red  = 60;
    int   quietP95Blue = 36;
    float shoreSeconds = 1.0f;   // the quiet-or-floor-or-frozen vote spans this
    // FROZEN: the black lifted off the floor read 0.41 m for a minute - 0.41, 0.41, 0.41 - and 0.53 pressed down; its
    // floor is wherever its long ringdown ends, not minDistance + 0.12, and its trace is loud. A real bottom at 40 cm
    // jitters by centimetres ping to ping; a ringdown does not. So a raw bottom track that has not moved by more than
    // frozenSpreadM over the last second, under frozenMaxM, votes for the shore like a floored one does.
    float frozenSpreadM = 0.03f;
    float frozenMaxM = 1.0f;
    float rfFreshS = 1.5f;      // a rangefinder older than this is silent
};

// a rangefinder reading that is a reading: the device sends 0.00 when it has none (the blue from 15:25 on 18 Oct)
inline bool rfIsReading(float rf) { return std::isfinite(rf) && rf > 0.0f; }

// THE STEADY READING: the median of the last rfSteadySeconds of readings when they hold together, else NaN.
// `readings` are the readings (rfIsReading) of that window, any order; `wasSteady` selects the hysteresis band.
inline float rfSteadyReading(std::vector<float> readings, bool wasSteady, const ChoiceParams& p = ChoiceParams())
{
    if (readings.size() < 3)
        return NAN;
    std::sort(readings.begin(), readings.end());
    const float spread = readings.back() - readings.front();
    const float median = readings[readings.size() / 2];
    if (spread > (wasSteady ? p.rfSteadyStayM : p.rfSteadyEnterM) + 1e-4f)   // the device sends centimetres
        return NAN;
    if (median <= p.rfRingLowM || median >= p.rfSteadyMaxM)
        return NAN;
    return median;
}

// THE VETO at the epoch write: true when this bottom track value cannot be a bottom given a steady rangefinder.
// rfSteady is rfSteadyReading()'s result (NaN when not steady).
inline bool rfVeto(float rfSteady, float btRaw, const ChoiceParams& p = ChoiceParams())
{
    if (!std::isfinite(rfSteady) || !std::isfinite(btRaw))
        return false;
    if (rfSteady <= p.ringdownM)
        return true;                              // the rangefinder's own zone: too shallow or out of the water
    return btRaw > p.rfVetoRatio * rfSteady;      // a far false bottom over a rangefinder that reads the real one
}


// the bottom track agrees that it is shallow (btRaw and rf without the mount offset)
inline bool shallowAgrees(float btRaw, float rf, float minDistance, const ChoiceParams& p = ChoiceParams())
{
    if (!std::isfinite(btRaw))
        return false;   // no bottom is not agreement: a pass the gates emptied over 3.5 m of water must not hand the
                        // readout to a rangefinder reading its ringdown (the ANDY blue's rangefinder sits at 0.20 over
                        // its 3.5 m bottom for most of the recording - a replay shows that, the file carries the DBT)
    if (btRaw <= minDistance + p.floorMargin)
        return true;                                   // at its floor
    if (std::isfinite(rf) && rf > 0.0f) {
        const float k = btRaw / rf;
        return k >= p.secondEchoMin && k <= p.secondEchoMax;   // the second or third echo
    }
    return false;
}

// the hysteresis: the new shallow-mode state from the previous one. rfSteady is rfSteadyReading()'s result.
inline bool shallowMode(bool wasShallow, bool rfFresh, float rf, float rfSteady, float btRaw, float minDistance, const ChoiceParams& p = ChoiceParams())
{
    // Entering needs the bottom track's agreement; STAYING does not (19 Oct 2026): in 0.3-0.5 m of water the bottom
    // track alternates between its floor (agrees) and a reading (does not), and the source flipped five times a
    // second. While the rangefinder stays under rfLeave the two read the same water anyway. In either direction a
    // rangefinder in its own zone (<= ringdownM) has nothing to offer: it is not reading water (the black in the air
    // showed 0.20 m for the four seconds before the shore state formed, 19 Oct evening).
    if (wasShallow)
        return rfFresh && rf > p.ringdownM && rf <= p.rfLeave;
    // Entering needs a STEADY reading (21 Oct 2026): 0.35 as a fixed entry floor was a guess at where the toggling
    // with the ringdown ends; steadiness is what tells a reading from the toggling, at any level above ringdownM.
    return rfFresh && std::isfinite(rfSteady) && rfSteady > p.ringdownM && rf < p.rfEnter && shallowAgrees(btRaw, rf, minDistance, p);
}

// THE OUTLIER FILTER (P5b) - the big-jump filter rebuilt where it can do its job. Its purpose (Olav): drop
// insane values so they do not infect the CSV log of the angler capturing bathymetric data. The old one
// shaped only the readout and NMEA, was fed ~6 re-publishes a ping, used an absolute 5 m, held the previous
// value (a fake point, not a gap) and was reset by every NaN. This one sits at the epoch write, after the
// gates, so every consumer inherits it, and:
//  - the reference is the running median of the epochs accepted in the last ~1 s before this one (never
//    "the last value"), so the same epoch re-published gets the same answer;
//  - the threshold is relative: an outlier is more than max(absM, rel x reference) away - right at 1 m and
//    at 40 m;
//  - a jump is accepted when it persists for ~1 s of distinct epochs that agree with each other: a drop-off
//    persists, a spike does not;
//  - a rejected epoch is stored as NaN - a gap in the CSV and the bathymetry, never the old value;
//  - when a jump is confirmed, the epochs held meanwhile are released with their real values (the caller
//    rewrites them), so a real drop-off loses nothing in the records - it appears ~1 s late on screen;
//  - NaN (no bottom) is ignored, never a reset.
// windowEpochs is the number of epochs in ~1 s - time, not samples - supplied by the caller from the ping rate.
struct OutlierParams {
    float absM = 0.5f;
    float rel  = 0.3f;
    int   minReference = 3;     // fewer accepted epochs in the window than this: nothing to compare with, accept
    int   persistTenths = 7;    // a jump persists when this many tenths of the window's epochs hold it
    // A big jump needs longer: a bottom cannot change by 12 m inside one second under a moving boat (the 18 Oct
    // blue at its 0.32 floor jumping to 12 m, confirmed after 1 s and drawn as a 5 s block). The persistence window
    // grows by jumpSecondsPerM for every metre of jump beyond jumpFreeM, up to persistMaxWindows windows.
    float jumpFreeM = 2.0f;
    float jumpSecondsPerM = 0.5f;
    int   persistMaxWindows = 4;
    // A witness (the live rangefinder, when it is a reading) that agrees with the OLD reference and not with the
    // candidate vetoes the confirmation - the bottom track says 10 m, the rangefinder still says 0.3-0.6 (the 18 Oct
    // blue leaving the shore: 6.6 s of 9-10 m over 5-15 cm of water) - for up to witnessMaxWindows windows; after
    // that the jump is accepted anyway (the witness may be stuck). The veto is remembered for a window, so one
    // rangefinder spike (8.24 in that stretch) cannot open the door.
    int   witnessMaxWindows = 8;
    // THE RETURN (21 Oct 2026, Olav's ANDY replay): the filter followed a 5 s excursion to 6-8 m (accepted after its
    // persistence - nothing says it is false) and then HELD the real 3.46 m when it came back, as an outlier against
    // the 8 m it now believed: a dash where the bottom track was right again. So the reference a confirmed jump left
    // behind is remembered, and a value that returns to it is accepted at once, for returnWindows windows. Only the
    // older bottom gets this - the excursion must earn its acceptance again each time, or the two would alternate.
    int   returnWindows = 15;
};

class OutlierFilter {
public:
    struct Result {
        float stored = NAN;      // what the epoch stores: the value, or NaN while held
        bool  held = false;      // rejected for now (an outlier against the reference)
        bool  returned = false;  // accepted at once as a return to the bottom a confirmed jump left behind
        bool  confirmed = false; // this epoch confirmed a jump: 'released' holds the earlier held epochs
        std::vector<std::pair<int, float>> released;
    };

    Result apply(int epoch, float value, int windowEpochs, float witness = NAN, const OutlierParams& p = OutlierParams())
    {
        Result r;
        const int w = std::max(3, windowEpochs);
        trim(epoch - (p.persistMaxWindows + 4) * w);
        accepted_.erase(epoch);
        held_.erase(epoch);
        if (!std::isfinite(value))
            return r;

        // the reference: the last w ACCEPTED epochs before this one - not "the last w epochs", or a held stretch
        // would empty the reference and the next value would walk in unjudged (the backdoor the first version had)
        std::vector<float> refs;
        for (auto it = accepted_.lower_bound(epoch); it != accepted_.begin() && int(refs.size()) < w;)
            refs.push_back((--it)->second);
        if (int(refs.size()) < p.minReference) {
            accepted_[epoch] = value;
            r.stored = value;
            return r;
        }
        const float ref = median(refs);
        if (std::fabs(value - ref) <= std::max(p.absM, p.rel * ref)) {
            accepted_[epoch] = value;
            r.stored = value;
            return r;
        }
        // the return to the bottom a confirmed jump left behind
        if (std::isfinite(previousRef_) && epoch - previousRefEpoch_ <= p.returnWindows * w
            && std::fabs(value - previousRef_) <= std::max(p.absM, p.rel * previousRef_)) {
            accepted_[epoch] = value;
            r.stored = value;
            r.returned = true;
            return r;
        }

        held_[epoch] = value;
        r.held = true;
        // does the jump persist? the held epochs of the last span, agreeing with each other. The span is one window
        // (~1 s) for a jump of up to jumpFreeM, longer for a bigger one; a witness agreeing with the old reference
        // stretches it further, up to witnessMaxWindows.
        const float jump = std::fabs(value - ref);
        float spanWindows = 1.0f + std::max(0.0f, jump - p.jumpFreeM) * p.jumpSecondsPerM;
        spanWindows = std::min(spanWindows, float(p.persistMaxWindows));
        const bool witnessAgrees = std::isfinite(witness) && std::fabs(witness - ref) <= std::max(p.absM, p.rel * ref)
                                   && std::fabs(witness - value) > std::max(p.absM, p.rel * value);
        if (witnessAgrees)
            lastVeto_ = epoch;
        if (lastVeto_ >= 0 && epoch - lastVeto_ < w)
            spanWindows = std::max(spanWindows, float(p.witnessMaxWindows));
        const int span = int(spanWindows * w + 0.5f);
        std::vector<std::pair<int, float>> hv;
        for (auto it = held_.lower_bound(epoch - span + 1); it != held_.end() && it->first <= epoch; ++it)
            hv.push_back(*it);
        const int need = std::max(p.minReference, (p.persistTenths * span + 9) / 10);
        if (int(hv.size()) >= need) {
            std::vector<float> vals;
            for (const auto& e : hv) vals.push_back(e.second);
            const float hm = median(vals);
            const float tol = std::max(p.absM, p.rel * hm);
            bool agree = true;
            for (float x : vals) agree = agree && std::fabs(x - hm) <= tol;
            if (agree) {
                for (const auto& e : hv) {
                    accepted_[e.first] = e.second;
                    held_.erase(e.first);
                    if (e.first != epoch)
                        r.released.push_back(e);
                }
                r.held = false;
                r.confirmed = true;
                r.stored = value;
                if (!std::isfinite(previousRef_) || epoch - previousRefEpoch_ > p.returnWindows * w
                    || std::fabs(ref - previousRef_) > std::max(p.absM, p.rel * previousRef_)) {
                    previousRef_ = ref;          // the bottom this jump left; a return to the remembered one keeps it
                    previousRefEpoch_ = epoch;
                }
            }
        }
        return r;
    }

    void noBottom(int epoch) { accepted_.erase(epoch); held_.erase(epoch); }
    void clear() { accepted_.clear(); held_.clear(); lastVeto_ = -1; previousRef_ = NAN; previousRefEpoch_ = -1; }

    // the reference apply() would judge this epoch against (the median of the last w accepted epochs before it),
    // NaN when there are too few - for P11, which needs it before the value is judged
    float reference(int epoch, int windowEpochs, const OutlierParams& p = OutlierParams()) const
    {
        const int w = std::max(3, windowEpochs);
        std::vector<float> refs;
        for (auto it = accepted_.lower_bound(epoch); it != accepted_.begin() && int(refs.size()) < w;)
            refs.push_back((--it)->second);
        if (int(refs.size()) < p.minReference)
            return NAN;
        return median(refs);
    }

private:
    static float median(std::vector<float>& v)
    {
        std::sort(v.begin(), v.end());
        return v[(v.size() - 1) / 2];    // the lower middle value (as the bench)
    }
    void trim(int before)
    {
        accepted_.erase(accepted_.begin(), accepted_.lower_bound(before));
        held_.erase(held_.begin(), held_.lower_bound(before));
    }
    std::map<int, float> accepted_, held_;
    int lastVeto_ = -1;
    float previousRef_ = NAN;      // the reference a confirmed jump left behind (the return rule)
    int   previousRefEpoch_ = -1;
};

} // namespace depthgates
