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
    int   gateBWindow   = 9;
    float gateBSkipM    = 0.4f;
    float gateBPeakM    = 0.1f;
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
    float floorMargin = 0.12f;  // "at its floor": bottom track <= minDistance + this
    float secondEchoMin = 1.7f; // "a second echo": bottom track / rangefinder within this band
    float secondEchoMax = 3.3f;
    float ringdownM = 0.22f;    // the rangefinder's own ringdown (0.12 red, 0.15-0.20 blue on the shore, 18 Oct)
    float rfFreshS = 1.5f;      // a rangefinder older than this is silent
};

// a rangefinder reading that is a reading: the device sends 0.00 when it has none (the blue from 15:25 on 18 Oct)
inline bool rfIsReading(float rf) { return std::isfinite(rf) && rf > 0.0f; }


// the bottom track agrees that it is shallow (btRaw and rf without the mount offset)
inline bool shallowAgrees(float btRaw, float rf, float minDistance, const ChoiceParams& p = ChoiceParams())
{
    if (!std::isfinite(btRaw))
        return true;                                   // no bottom: nothing contradicts the rangefinder
    if (btRaw <= minDistance + p.floorMargin)
        return true;                                   // at its floor
    if (std::isfinite(rf) && rf > 0.0f) {
        const float k = btRaw / rf;
        return k >= p.secondEchoMin && k <= p.secondEchoMax;   // the second or third echo
    }
    return false;
}

// the hysteresis: the new shallow-mode state from the previous one
inline bool shallowMode(bool wasShallow, bool rfFresh, float rf, float btRaw, float minDistance, const ChoiceParams& p = ChoiceParams())
{
    const bool agrees = shallowAgrees(btRaw, rf, minDistance, p);
    if (wasShallow)
        return rfFresh && rf <= p.rfLeave && agrees;
    return rfFresh && rf < p.rfEnter && agrees;
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
};

class OutlierFilter {
public:
    struct Result {
        float stored = NAN;      // what the epoch stores: the value, or NaN while held
        bool  held = false;      // rejected for now (an outlier against the reference)
        bool  confirmed = false; // this epoch confirmed a jump: 'released' holds the earlier held epochs
        std::vector<std::pair<int, float>> released;
    };

    Result apply(int epoch, float value, int windowEpochs, const OutlierParams& p = OutlierParams())
    {
        Result r;
        const int w = std::max(3, windowEpochs);
        trim(epoch - 4 * w);
        accepted_.erase(epoch);
        held_.erase(epoch);
        if (!std::isfinite(value))
            return r;

        std::vector<float> refs;
        for (auto it = accepted_.lower_bound(epoch - w); it != accepted_.end() && it->first < epoch; ++it)
            refs.push_back(it->second);
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

        held_[epoch] = value;
        r.held = true;
        // does the jump persist? the held epochs of the last window, agreeing with each other
        std::vector<std::pair<int, float>> hv;
        for (auto it = held_.lower_bound(epoch - w + 1); it != held_.end() && it->first <= epoch; ++it)
            hv.push_back(*it);
        const int need = std::max(p.minReference, (p.persistTenths * w + 9) / 10);
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
            }
        }
        return r;
    }

    void noBottom(int epoch) { accepted_.erase(epoch); held_.erase(epoch); }
    void clear() { accepted_.clear(); held_.clear(); }

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
};

} // namespace depthgates
