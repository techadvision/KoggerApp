#pragma once

#include <stdint.h>
#include <QVector>

// PULSE addition — Stage A of the TVG & display-filtering plan.
//
// Stateless time-varied-gain (TVG) helper for the 2D echogram display.
// Ported from the validated AnalyzeSuite implementation (bottomcomp.html,
// computeTvgGain): gain(z) = 10^(k*z/20) with a fixed decay constant k in
// dB/m, hard-capped at kGainCap. Unlike AnalyzeSuite there is no per-file
// regression fit here (real-time app) — k is a constant, tunable from the
// expert settings. Display-only: raw amplitudes and logs are never touched.
//
// The class keeps a single global k (atomic, thread-safe) plus a version
// counter so per-epoch caches (Epoch::Echogram::tvgCompensated) can detect
// a stale gain curve and recompute lazily, mirroring the existing
// updateCompesated() pattern.
//
// P5 of the motor-noise plan (7 Nov 2026): an optional noise-floor step
// before the gain, the side scan law's step 1 ported. Motor noise on the
// transducer cable raises the whole trace by a range-flat level that the
// gain then multiplies into fog that brightens with depth; subtracting
// strength x floor first removes it at the source, and echoes keep their
// level law. The estimate differs from side scan's because a 2D trace has
// a bottom in it and the water column can be short: a LOW PERCENTILE
// (kNoiseFloorPct, 30th) of the raw samples from kSurfBandMaxM (below the
// ring-down) to the end of the trace. Not the median - the band under the
// bottom is an echo tail of ~70 raw that is there with the motor off too,
// and once the planner keeps the bottom at 0.6 of the range (P1) that tail
// is 30-45% of every trace, so the median lands 10-50 raw units above the
// water column (offline check on Andy's 3 Nov plogs, tools/pulse-tvg-presets/
// tvg2d.py). The 30th percentile tracks the water column within a few units
// and under-reads rather than over-reads on the built-in red. Per ping and
// unsmoothed because the noise is bursty - the water level flips 7 <-> 50
// between adjacent pings on the noisy boat. Exact zeros are lost fragments
// and are excluded; a ping with more than (1 - kNoiseFloorMinShare) of its
// samples missing is not judged (floor 0, no subtraction), as side scan's
// "window not usable" rule. Bottom-independent, so the per-epoch cache
// stays valid under a live bottom track; the strength bumps version().
class EchogramTvg
{
public:
    static constexpr float kDefaultDbPerMeter = 0.9f; // Dreamlake harvest mean (0.66-1.11 dB/m over 4 logs)
    static constexpr float kMaxDbPerMeter     = 15.0f; // physical plausibility clamp (as in AnalyzeSuite)
    static constexpr float kGainCap           = 30.0f; // ~ +29.5 dB, unbounded deep-water gain guard
    static constexpr float kSurfBandMaxM      = 1.0f;  // floor is judged from here (below the ring-down) to the end
    static constexpr float kNoiseFloorMax     = 80.0f; // never subtract more than this (8-bit), as side scan
    static constexpr int   kNoiseFloorPct     = 30;    // the percentile that reads as the floor (see above)
    static constexpr int   kNoiseFloorMinSamples = 16; // fewer usable samples than this: not judged
    static constexpr float kNoiseFloorMinShare = 0.6f; // usable (non-zero) share of the window below this: not judged
    static constexpr float kDefaultNoiseFloorStrength = 0.0f; // release behaviour unchanged, as side scan's default

    // Global decay constant in dB/m. Clamped to [0, kMaxDbPerMeter].
    // Setting a new value bumps the version so cached buffers recompute.
    static void  setDbPerMeter(float dbPerMeter);
    static float dbPerMeter();

    // Fraction [0..1] of the estimated per-ping noise floor that is
    // subtracted before the gain. 0 = off. Clamped; bumps the version.
    static void  setNoiseFloorStrength(float strength01);
    static float noiseFloorStrength();

    // Monotonic counter, incremented whenever the constant or the floor
    // strength changes.
    static uint32_t version();

    // Fills out with the TVG-compensated copy of raw.
    // z(i) = offsetM + i * resolution (meters);
    // out[i] = clamp(0..255, (raw[i] - strength * floor) * min(gain(z), kGainCap)).
    // Fail-safe: with k <= 0 and the floor off, or a non-positive resolution,
    // the output is a plain copy of raw (neutral gain).
    static void apply(const QVector<uint8_t>& raw, float resolution, float offsetM, QVector<uint8_t>& out);

private:
    EchogramTvg() = delete;
};
