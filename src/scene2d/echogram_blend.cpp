#include "echogram_blend.h"

#include <atomic>
#include <cmath>

namespace {

// Defaults are the recommendation, not a neutral starting point: RMS on the
// raw amplitudes is the multi-look estimator the header derives. A build with
// no expert rows on it still shows the blend.
std::atomic<int> gMode  { EchogramBlend::Rms };
std::atomic<int> gDomain{ EchogramBlend::Raw };

} // namespace

void EchogramBlend::setMode(int mode)
{
    if (mode < Single || mode > Max) {
        return;
    }
    gMode.store(mode, std::memory_order_relaxed);
}

int EchogramBlend::mode()
{
    return gMode.load(std::memory_order_relaxed);
}

void EchogramBlend::setDomain(int domain)
{
    if (domain < Raw || domain > AfterGain) {
        return;
    }
    gDomain.store(domain, std::memory_order_relaxed);
}

int EchogramBlend::domain()
{
    return gDomain.load(std::memory_order_relaxed);
}

void EchogramBlend::apply(const uint8_t* a, const uint8_t* b, int n, QVector<uint8_t>& out)
{
    if (!a || !b || n <= 0) {
        out.clear();
        return;
    }

    if (out.size() != n) {
        out.resize(n);
    }
    uint8_t* dst = out.data();

    switch (mode()) {
    case Mean:
        for (int i = 0; i < n; ++i) {
            dst[i] = uint8_t((int(a[i]) + int(b[i]) + 1) >> 1);
        }
        break;

    case Max:
        for (int i = 0; i < n; ++i) {
            dst[i] = a[i] > b[i] ? a[i] : b[i];
        }
        break;

    case Rms:
    default:
        // sqrt((a^2 + b^2)/2). Both inputs are at most 255, so the result is
        // at most 255 and no clamp is needed.
        for (int i = 0; i < n; ++i) {
            const int ai = a[i];
            const int bi = b[i];
            const float meanIntensity = 0.5f * float(ai * ai + bi * bi);
            dst[i] = uint8_t(std::sqrt(meanIntensity) + 0.5f);
        }
        break;
    }
}
