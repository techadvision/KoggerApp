#include "echogram_watercolumn.h"

#include <algorithm>
#include <atomic>
#include <cmath>
#include <vector>

namespace {

std::atomic<float> g_strength{0.0f};
std::atomic<float> g_bandM{0.30f}; // EMA of the detected ring-down band edge (Dreamlake: 0.26-0.30 m)
std::atomic<float> g_guardM{EchogramWaterColumn::kDefaultBottomGuardM};

// Last valid bottom on this render thread — fallback for black-stripe-patched
// epochs that carry interpolated amplitudes but no bottom-track distance.
thread_local float t_lastBottomM = -1.0f;

// Per-epoch surface band knee detection (single-ping variant of the
// AnalyzeSuite median-row-profile method; the cross-ping robustness comes
// from the EMA smoothing in updateSurfaceBand instead).
// Returns the knee depth in meters, or a negative value when no reliable
// detection is possible for this epoch.
float detectSurfaceBandKnee(const uint8_t* src, int n, float resolution, float offsetM)
{
    if (offsetM > EchogramWaterColumn::kSurfBandMinM * 0.5f) {
        return -1.0f; // data window starts below the surface — band not visible
    }

    const int i0 = std::max(0, int((EchogramWaterColumn::kSurfBandMinM - offsetM) / resolution + 0.5f));
    const int iMax = std::min(n - 1, int((EchogramWaterColumn::kSurfBandMaxM - offsetM) / resolution + 0.5f));
    if (iMax <= i0 + 2) {
        return -1.0f;
    }

    // surfacePeak: max amplitude in the guaranteed band region [0 .. kSurfBandMinM]
    int ref = 0;
    for (int i = 0; i <= i0; ++i) {
        if (src[i] > ref) {
            ref = src[i];
        }
    }

    // noise floor: median of the tail region [0.7 .. 1.0] * kSurfBandMaxM
    const int tail0 = i0 + int(0.7f * float(iMax - i0));
    int tailBuf[64];
    int m = 0;
    const int span = iMax - tail0 + 1;
    const int stride = std::max(1, span / 64);
    for (int i = tail0; i <= iMax && m < 64; i += stride) {
        tailBuf[m++] = src[i];
    }
    if (m < 3) {
        return -1.0f;
    }
    std::nth_element(tailBuf, tailBuf + m / 2, tailBuf + m);
    const int floorN = tailBuf[m / 2];

    if (ref <= floorN + 2) {
        return -1.0f; // no distinct surface peak above the noise floor
    }

    const float thr = float(floorN) + std::max(1.0f, float(ref - floorN) * EchogramWaterColumn::kSurfBandThr);

    int g = i0;
    while (g < iMax && float(src[g]) >= thr) {
        ++g;
    }
    return offsetM + float(g) * resolution;
}

void updateSurfaceBand(const uint8_t* src, int n, float resolution, float offsetM)
{
    const float knee = detectSurfaceBandKnee(src, n, resolution, offsetM);
    if (knee < 0.0f) {
        return;
    }
    float band = g_bandM.load();
    band += EchogramWaterColumn::kBandEmaAlpha * (knee - band);
    if (band < EchogramWaterColumn::kSurfBandMinM) band = EchogramWaterColumn::kSurfBandMinM;
    if (band > EchogramWaterColumn::kSurfBandMaxM) band = EchogramWaterColumn::kSurfBandMaxM;
    g_bandM.store(band);
}

} // namespace

void EchogramWaterColumn::setStrength(float strength01)
{
    if (!(strength01 >= 0.0f)) { // also catches NaN
        strength01 = 0.0f;
    }
    if (strength01 > 1.0f) {
        strength01 = 1.0f;
    }
    g_strength.store(strength01);
}

float EchogramWaterColumn::strength()
{
    return g_strength.load();
}

bool EchogramWaterColumn::isActive()
{
    return g_strength.load() > 0.001f;
}

float EchogramWaterColumn::surfaceBandM()
{
    return g_bandM.load();
}

void EchogramWaterColumn::setBottomGuardM(float guardM)
{
    if (!(guardM >= 0.0f)) { // also catches NaN
        guardM = kDefaultBottomGuardM;
    }
    if (guardM > kMaxBottomGuardM) {
        guardM = kMaxBottomGuardM;
    }
    g_guardM.store(guardM);
}

float EchogramWaterColumn::bottomGuardM()
{
    return g_guardM.load();
}

const uint8_t* EchogramWaterColumn::apply(const uint8_t* src, int n, float resolution, float offsetM, float bottomM)
{
    if (!src || n <= 0 || !(resolution > 0.0f) || !isActive()) {
        return src;
    }
    if (std::isfinite(bottomM) && bottomM > 0.0f) {
        t_lastBottomM = bottomM; // remember for black-stripe-patched neighbours
    } else if (t_lastBottomM > 0.0f) {
        bottomM = t_lastBottomM; // patched epoch: filter like its neighbours
    } else {
        return src; // fail-safe: no bottom known at all -> no filtering
    }

    // keep the band tracker fed while the filter is in use
    updateSurfaceBand(src, n, resolution, offsetM);

    const float guardM = g_guardM.load();
    const float zGuard = bottomM - guardM; // below this: untouched (bottom guard)
    const int iGuard = std::min(n, std::max(0, int((zGuard - offsetM) / resolution)));
    if (iGuard <= 0) {
        return src; // bottom too shallow — nothing above it to filter
    }

    const float f = strength();
    const float wcF = 1.0f - f; // column scale
    // Surface cap weighted quadratically: with a single merged control, the
    // column scale alone would keep the (near-saturated) ring-down band just
    // under a 1:1 cap and the soft-knee would never engage. (1-f)^2 makes the
    // band compress noticeably at mid strengths while keeping its texture.
    const float sfF = (1.0f - f) * (1.0f - f); // surface cap (0..1 of full scale)

    // amplitude-keep zone: between zKeepTop and the guard, strong echoes are
    // preserved (scaled by a height taper) while weak debris follows wcF
    const float zKeepTop = bottomM - (guardM + kWcKeepZoneM);
    const float invKeepZone = 1.0f / kWcKeepZoneM;
    const float invKeepAmpSpan = 1.0f / (kAmpKeepHi - kAmpKeepLo);

    const float sLoZ = g_bandM.load();
    const float sHiZ = sLoZ + kSurfFadeM;

    thread_local std::vector<uint8_t> scratch;
    if (int(scratch.size()) < n) {
        scratch.resize(size_t(n));
    }
    uint8_t* dst = scratch.data();

    for (int i = 0; i < iGuard; ++i) {
        const float z = offsetM + float(i) * resolution;
        float t = float(src[i]);

        // 1. water column: multiplicative dim. In the near-bottom keep zone the
        // dim is amplitude-selective: weak debris keeps the column scale (no
        // halo), strong echoes are preserved, tapering with height above the
        // guard so partially-covered fish fade smoothly instead of being cut.
        float scale = wcF;
        if (z > zKeepTop) {
            float taper = (z - zKeepTop) * invKeepZone; // 0 at zone top -> 1 at guard
            if (taper > 1.0f) taper = 1.0f;
            float ampKeep = (t - kAmpKeepLo) * invKeepAmpSpan;
            if (ampKeep < 0.0f) ampKeep = 0.0f;
            else if (ampKeep > 1.0f) ampKeep = 1.0f;
            ampKeep = ampKeep * ampKeep * (3.0f - 2.0f * ampKeep); // smoothstep
            scale = wcF + (1.0f - wcF) * ampKeep * taper;
        }
        t *= scale;

        // 2. surface ring-down band: soft-knee compression above a fading cap
        if (z < sHiZ) {
            float cap01 = sfF;
            if (z > sLoZ) {
                cap01 = sfF + (1.0f - sfF) * (z - sLoZ) / kSurfFadeM;
            }
            const float cap = cap01 * 255.0f;
            if (t > cap) {
                t = cap + (t - cap) * kSurfSoftK;
            }
        }

        const int v = int(t + 0.5f);
        dst[i] = (v > 255) ? uint8_t(255) : (v < 0 ? uint8_t(0) : uint8_t(v));
    }

    // bottom band and everything below: verbatim copy
    for (int i = iGuard; i < n; ++i) {
        dst[i] = src[i];
    }

    return dst;
}
