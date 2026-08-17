#pragma once

#include <stdint.h>

// PULSE addition — Stage B of the TVG & display-filtering plan.
//
// Water-body display filter for the 2D echogram, ported from the validated
// AnalyzeSuite implementation (bottomcomp.html render loop + surface band
// auto-detection). One strength value [0..1] drives two coupled actions:
//
//   1. Water column: multiplicative dim of everything above the per-epoch
//      detected bottom. Near the bottom (kWcKeepZoneM above the guard) the
//      dim becomes amplitude-selective: weak debris is filtered like the
//      rest of the column, strong echoes (bottom shoulder, bottom-feeding
//      fish) are kept. The guard zone directly above the bottom is never
//      touched (bottom-guard rule).
//   2. Surface ring-down band: soft-knee compression (residual slope
//      kSurfSoftK, i.e. ~4:1) above a cap instead of a hard cut, so the band
//      keeps texture. The band extent is auto-detected from the data with a
//      noise-floor-relative knee (threshold = floor + kSurfBandThr *
//      (surfacePeak - floor), search window kSurfBandMinM..kSurfBandMaxM),
//      smoothed across epochs with an EMA. The cap fades back over
//      kSurfFadeM below the band edge.
//
// Fail-safe: an epoch without a finite bottom-track distance is rendered
// unfiltered (never dim an undetected bottom). Display-only; raw amplitudes
// and logs are never touched. The existing upstream low/high level pipeline
// (setEchogramLowLevel/HightLevel) is intentionally left untouched — this is
// a separate, additive Pulse-only path.
//
// Threading mirrors EchogramTvg: one global atomic strength; apply() writes
// into a thread-local scratch buffer and returns a pointer to it (or the
// input pointer when it is a no-op), so no per-epoch cache invalidation is
// needed and live bottom-track updates are always honoured.
class EchogramWaterColumn
{
public:
    // Reference constants as validated in AnalyzeSuite (do not retune casually).
    // Near-bottom handling: REDESIGNED vs the AnalyzeSuite reference after
    // on-device testing (2026-08-09). The reference depth-fade spared
    // everything near the bottom, so TVG-amplified debris rendered as a
    // glowing "halo" above the bottom contour in palettes that paint mid-low
    // values bright (Furuno, D Dark), and masked bottom-feeding fish. The
    // keep zone is now AMPLITUDE-based: within kWcKeepZoneM above the guard,
    // weak samples (debris) follow the column filter while strong echoes
    // (bottom shoulder, bottom-hugging fish) are kept, tapering off with
    // height so a fish slightly above the zone fades smoothly instead of
    // being cut.
    static constexpr float kWcKeepZoneM        = 0.30f; // amplitude-keep zone above the guard
    static constexpr float kAmpKeepLo          = 140.0f; // below this (8-bit): treated as debris/noise
    static constexpr float kAmpKeepHi          = 220.0f; // above this: fully kept (fish/bottom-strength)
    static constexpr float kDefaultBottomGuardM = 0.05f; // untouched zone above the bottom (safety net)
    static constexpr float kMaxBottomGuardM     = 1.0f;
    static constexpr float kSurfBandMinM = 0.10f; // ring-down band is at least this deep
    static constexpr float kSurfBandMaxM = 1.0f;  // ... and searched at most to here
    static constexpr float kSurfBandThr  = 0.15f; // knee: median falls below floor + 15% of (peak - floor)
    static constexpr float kSurfFadeM    = 0.15f; // soft transition below the band edge
    static constexpr float kSurfSoftK    = 0.25f; // soft-knee residual slope above the cap
    static constexpr float kBandEmaAlpha = 0.05f; // per-epoch smoothing of the detected band edge

    // Combined filter strength [0..1] (UI slider 0-20 mapped to /20).
    // 0 = off. Internally: columnScale = 1 - strength, surfaceCap =
    // (1 - strength)^2 — the two merged AnalyzeSuite sliders with a fixed
    // relative weighting (quadratic cap so the soft-knee engages at mid
    // strengths; see the .cpp comment).
    static void  setStrength(float strength01);
    static float strength();
    static bool  isActive();

    // Bottom guard in meters: the zone directly above the detected bottom that
    // is never filtered. Smaller = filtering bites closer to the bottom
    // (dims the debris halo; a strong fish echo at the bottom stands out).
    // Clamped to [0, kMaxBottomGuardM].
    static void  setBottomGuardM(float guardM);
    static float bottomGuardM();

    // Currently detected (EMA-smoothed) ring-down band edge in meters.
    static float surfaceBandM();

    // Filters one epoch's amplitude vector (raw or TVG-compensated).
    //   src/n       amplitude samples, z(i) = offsetM + i*resolution
    //   bottomM     per-epoch bottom-track distance in meters (NAN = none)
    // Epochs without a finite bottom fall back to the last valid bottom seen
    // on this thread — black-stripe-patched epochs (interpolated amplitudes,
    // no bottom track) then filter like their neighbours instead of rendering
    // as bright unfiltered stripes. Only when no bottom has been seen at all
    // does the column render unfiltered (fail-safe: never dim a bottom we
    // know nothing about).
    // Returns a pointer to an internal thread-local buffer with the filtered
    // copy, or `src` itself when filtering is a no-op. The returned pointer
    // is valid until the next apply() call on the same thread.
    static const uint8_t* apply(const uint8_t* src, int n, float resolution, float offsetM, float bottomM);

private:
    EchogramWaterColumn() = delete;
};
