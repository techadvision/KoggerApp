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
class EchogramTvg
{
public:
    static constexpr float kDefaultDbPerMeter = 0.9f; // Dreamlake harvest mean (0.66-1.11 dB/m over 4 logs)
    static constexpr float kMaxDbPerMeter     = 15.0f; // physical plausibility clamp (as in AnalyzeSuite)
    static constexpr float kGainCap           = 30.0f; // ~ +29.5 dB, unbounded deep-water gain guard

    // Global decay constant in dB/m. Clamped to [0, kMaxDbPerMeter].
    // Setting a new value bumps the version so cached buffers recompute.
    static void  setDbPerMeter(float dbPerMeter);
    static float dbPerMeter();

    // Monotonic counter, incremented whenever the constant changes.
    static uint32_t version();

    // Fills out with the TVG-compensated copy of raw.
    // z(i) = offsetM + i * resolution (meters); out[i] = min(255, raw[i] * min(gain(z), kGainCap)).
    // Fail-safe: with k <= 0 or a non-positive resolution the output is a
    // plain copy of raw (neutral gain).
    static void apply(const QVector<uint8_t>& raw, float resolution, float offsetM, QVector<uint8_t>& out);

private:
    EchogramTvg() = delete;
};
