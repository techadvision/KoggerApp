#pragma once

#include <stdint.h>
#include <QVector>

// PULSE addition — side scan phase (S1/S2/S4 of the side scan TVG plan).
//
// Range-varied gain for SIDE SCAN rendering (waterfall imageType 3 and,
// optionally, the map mosaic). Deliberately a separate module from
// EchogramTvg (the vertical 2D echogram law): side scan needs a log-law
// over slant range, its own parameter set, and two optional post steps.
// The validated vertical-echogram TVG is never touched.
//
// Law (offline-validated on SS_pulse_log_2026.07.20, 39,976 pings):
//   gain_dB(r) = S * log10(max(r, r0) / rRef) + a * (r - rRef)
//     S    = spreading term in dB/decade. Physical spreading would be ~30,
//            but the transducer applies internal gain already — the log's
//            empirical falloff was only ~12-18 dB/decade, and field tuning
//            landed lower still — the value is an expert tunable.
//     a    = absorption term in dB/m (frequency dependent: 510 vs 810 kHz
//            vs future chirp band).
//     rRef = reference range in m: gain is exactly 1 there, so the near
//            field keeps its familiar brightness and only the far field is
//            lifted (and the nadir region slightly dimmed).
//   gain_dB clamped to [kFloorDb, capDb]; cap expressed in dB (not a ratio)
//   so long chirp ranges (150 m/side) don't go flat like the 30x cap of the
//   vertical law did at ~33 m.
//
// Optional steps (both display-only, like everything here):
//   1. Noise-floor subtraction (strength stepper, default 0.1): per-ping
//      median of the water column window [kNoiseWinLoM, kNoiseWinHiM],
//      scaled by the strength, is subtracted before the gain. TVG amplifies
//      the far-field noise that the side scan AGC's mean-subtraction used
//      to hide; this removes it at the source. Strength (not on/off)
//      because in shallow water the window overlaps ring-down/first
//      returns and full subtraction eats real signal.
//      ("variant 4" of the offline comparison strips.)
//   2. Detail boost (default 1.2, field-tuned): unsharp mask along range,
//      out = v + beta * (v - boxblur(v, kBoostWinM)). Gradually restores the
//      local-contrast crispness of the AGC on top of level-correct data
//      ("variant 5"). beta is an expert stepper.
//
// Threading mirrors EchogramTvg/EchogramWaterColumn: atomics + a version
// counter for the per-epoch caches (Epoch::Echogram::ssTvgCompensated), a
// thread_local gain-curve cache keyed on (version, resolution, offset, n).
// Used from both the 2D render thread (chartTo) and the mosaic compute
// worker, which operates on epoch deep copies.
//
// Fail-safe: non-positive resolution -> plain copy (neutral). The mosaic
// source switch falls back to the AGC buffer whenever the TVG buffer is
// not available (see mosaic_processor.cpp).
class EchogramSideScanTvg
{
public:
    static constexpr float kDefaultSpreadingDbDec = 5.0f;  // field-tuned (Olav, shallow lake 2026-08-16); SS-log fit was 15 — deeper water / chirp may want more
    static constexpr float kMaxSpreadingDbDec     = 40.0f;
    static constexpr float kDefaultAbsorptionDbM  = 0.0f;  // field-tuned: 0 best on 25 m ranges; matters for chirp long range
    static constexpr float kMaxAbsorptionDbM      = 1.0f;
    static constexpr float kDefaultRefRangeM      = 15.0f; // gain = 1 here (field-tuned)
    static constexpr float kMinRefRangeM          = 1.0f;
    static constexpr float kMaxRefRangeM          = 50.0f;
    static constexpr float kDefaultCapDb          = 40.0f;
    static constexpr float kMaxCapDb              = 60.0f;
    static constexpr float kFloorDb               = -12.0f; // max near-field dim
    static constexpr float kMinRangeM             = 0.5f;   // r0: log-law lower bound
    static constexpr float kNoiseWinLoM           = 0.8f;   // noise-floor estimation window
    static constexpr float kNoiseWinHiM           = 2.5f;   //   (water column, past ring-down)
    static constexpr float kNoiseFloorMax         = 80.0f;  // never subtract more than this (8-bit)
    static constexpr float kDefaultNoiseFloorStrength = 0.1f; // fraction of the estimated floor actually subtracted (base level, field-tuned)
    static constexpr float kDefaultBoostBeta      = 1.2f;   // field-tuned: boost is essential (0 = "beautify" smear)
    static constexpr float kMaxBoostBeta          = 2.0f;
    static constexpr float kBoostWinM             = 0.4f;   // unsharp window along range

    // All setters clamp, and bump the version when the value changed.
    static void  setSpreading(float dbPerDecade);
    static float spreading();
    static void  setAbsorption(float dbPerMeter);
    static float absorption();
    static void  setRefRange(float meters);
    static float refRange();
    static void  setCapDb(float capDb);
    static float capDb();
    // Fraction [0..1] of the estimated per-ping noise floor that is
    // subtracted. 0 = off. Tunable because in shallow water the estimation
    // window overlaps ring-down/first returns and full subtraction eats
    // real signal (field report 2026-08-16, 6 m lake).
    static void  setNoiseFloorStrength(float strength01);
    static float noiseFloorStrength();
    static void  setBoostBeta(float beta);
    static float boostBeta();

    // Mosaic source switch: when true (and the buffer is fresh) the mosaic
    // renders from ssTvgCompensated instead of the AGC `compensated` buffer.
    // Not part of version() — it selects a buffer, it doesn't change one.
    static void setMosaicEnabled(bool enabled);
    static bool mosaicEnabled();

    // Monotonic counter, incremented whenever a gain-affecting value changes.
    static uint32_t version();

    // out = process(raw): noise floor (optional) -> gain -> detail boost
    // (optional), everything clamped to 0..255.
    static void apply(const QVector<uint8_t>& raw, float resolution, float offsetM, QVector<uint8_t>& out);

private:
    EchogramSideScanTvg() = delete;
};
