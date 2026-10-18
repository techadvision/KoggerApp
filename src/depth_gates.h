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

} // namespace depthgates
