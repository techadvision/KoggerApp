#include "echogram_tvg.h"

#include <atomic>
#include <cmath>
#include <cstring>

namespace {
std::atomic<float>    g_dbPerMeter{EchogramTvg::kDefaultDbPerMeter};
std::atomic<uint32_t> g_version{1};
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
    if (!(k > 0.0f) || !(resolution > 0.0f)) {
        // neutral gain — plain copy (fail-safe)
        std::memcpy(dst, src, size_t(n));
        return;
    }

    // gain(z) = 10^(k*z/20) = exp(g*z), g = k*ln(10)/20.
    // Computed incrementally: one multiply per sample instead of exp().
    const double g = double(k) * 0.115129254649702287; // ln(10)/20
    const double stepFactor = std::exp(g * double(resolution));
    const double z0 = (offsetM > 0.0f) ? double(offsetM) : 0.0;
    double gain = std::exp(g * z0);

    const double cap = double(kGainCap);
    for (int i = 0; i < n; ++i) {
        const double gEff = (gain < cap) ? gain : cap;
        const int v = int(double(src[i]) * gEff + 0.5);
        dst[i] = (v > 255) ? uint8_t(255) : uint8_t(v);
        gain *= stepFactor;
    }
}
