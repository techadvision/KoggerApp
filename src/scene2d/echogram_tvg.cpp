#include "echogram_tvg.h"

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstring>
#include <vector>

namespace {
std::atomic<float>    g_dbPerMeter{EchogramTvg::kDefaultDbPerMeter};
std::atomic<float>    g_noiseFloor{EchogramTvg::kDefaultNoiseFloorStrength};
std::atomic<uint32_t> g_version{1};

// P5: the per-ping floor, in raw units. The kNoiseFloorPct-th percentile of
// the non-zero samples from kSurfBandMaxM to the end of the trace, 0 when
// the trace cannot be judged (see the header). Runs on the render thread
// (chartTo) and the mosaic worker, hence the thread_local scratch.
float noiseFloor(const uint8_t* src, int n, float resolution, float offsetM)
{
    const int i0 = std::max(0, int((EchogramTvg::kSurfBandMaxM - offsetM) / resolution + 0.5f));
    const int span = n - i0;
    if (span < EchogramTvg::kNoiseFloorMinSamples) {
        return 0.0f;
    }

    thread_local std::vector<uint8_t> buf;
    buf.clear();
    buf.reserve(size_t(span));
    for (int i = i0; i < n; ++i) {
        if (src[i] != 0) {
            buf.push_back(src[i]);
        }
    }
    const int m = int(buf.size());
    if (m < EchogramTvg::kNoiseFloorMinSamples || float(m) < EchogramTvg::kNoiseFloorMinShare * float(span)) {
        return 0.0f;
    }

    const int k = (m - 1) * EchogramTvg::kNoiseFloorPct / 100;
    std::nth_element(buf.begin(), buf.begin() + k, buf.end());
    float floorV = float(buf[size_t(k)]);
    if (floorV > EchogramTvg::kNoiseFloorMax) {
        floorV = EchogramTvg::kNoiseFloorMax;
    }
    return floorV;
}
} // namespace

void EchogramTvg::setDbPerMeter(float dbPerMeter)
{
    if (!(dbPerMeter >= 0.0f)) { // also catches NaN
        dbPerMeter = 0.0f;
    }
    if (dbPerMeter > kMaxDbPerMeter) {
        dbPerMeter = kMaxDbPerMeter;
    }

    if (g_dbPerMeter.exchange(dbPerMeter) != dbPerMeter) {
        g_version.fetch_add(1);
    }
}

float EchogramTvg::dbPerMeter()
{
    return g_dbPerMeter.load();
}

void EchogramTvg::setNoiseFloorStrength(float strength01)
{
    if (!(strength01 >= 0.0f)) { // also catches NaN
        strength01 = 0.0f;
    }
    if (strength01 > 1.0f) {
        strength01 = 1.0f;
    }

    if (g_noiseFloor.exchange(strength01) != strength01) {
        g_version.fetch_add(1);
    }
}

float EchogramTvg::noiseFloorStrength()
{
    return g_noiseFloor.load();
}

uint32_t EchogramTvg::version()
{
    return g_version.load();
}

void EchogramTvg::apply(const QVector<uint8_t>& raw, float resolution, float offsetM, QVector<uint8_t>& out)
{
    const int n = raw.size();
    if (out.size() != n) {
        out.resize(n);
    }
    if (n <= 0) {
        return;
    }

    const uint8_t* src = raw.constData();
    uint8_t* dst = out.data();

    const float k = dbPerMeter();
    if (!(resolution > 0.0f)) {
        // neutral — plain copy (fail-safe)
        std::memcpy(dst, src, size_t(n));
        return;
    }

    // P5: the noise floor comes off before the gain multiplies it, with a
    // soft knee (P5b): fully at the floor, not at all from (1 + kNoiseKnee)
    // x floor up, so echoes keep their level while the fog goes.
    const float nfStrength = g_noiseFloor.load();
    const double floorRaw = (nfStrength > 0.001f) ? double(noiseFloor(src, n, resolution, offsetM)) : 0.0;
    const double floorV = double(nfStrength) * floorRaw;
    const double kneeInv = (floorRaw > 0.0) ? 1.0 / (double(kNoiseKnee) * floorRaw) : 0.0;

    if (!(k > 0.0f) && floorV <= 0.0) {
        // neutral gain, no floor — plain copy (fail-safe)
        std::memcpy(dst, src, size_t(n));
        return;
    }

    // gain(z) = 10^(k*z/20) = exp(g*z), g = k*ln(10)/20.
    // Computed incrementally: one multiply per sample instead of exp().
    // With k <= 0 the gain stays 1 and only the floor applies.
    const double g = (k > 0.0f) ? double(k) * 0.115129254649702287 : 0.0; // ln(10)/20
    const double stepFactor = std::exp(g * double(resolution));
    const double z0 = (offsetM > 0.0f) ? double(offsetM) : 0.0;
    double gain = std::exp(g * z0);

    const double cap = double(kGainCap);
    for (int i = 0; i < n; ++i) {
        const double gEff = (gain < cap) ? gain : cap;
        const double s = double(src[i]);
        double w = 1.0 - (s - floorRaw) * kneeInv; // 1 at the floor, 0 at (1 + knee) x floor
        if (w > 1.0) w = 1.0; else if (w < 0.0) w = 0.0;
        const double a = s - floorV * w;
        const int v = (a > 0.0) ? int(a * gEff + 0.5) : 0;
        dst[i] = (v > 255) ? uint8_t(255) : uint8_t(v);
        gain *= stepFactor;
    }
}
