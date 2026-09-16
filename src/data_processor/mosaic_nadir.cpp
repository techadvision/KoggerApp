#include "mosaic_nadir.h"

#include <atomic>

namespace {

// Defaults are the recommendation: 0.3 is where the ground spacing has passed
// about three and a half times the slant resolution and the beam is deep in its
// null; 1.0 is the conventional 45 degree line, by which point both terms are
// acceptable. The two are expert rows so the pair can be moved on the water.
std::atomic<bool>  gEnabled{ true };
std::atomic<float> gInner  { 0.3f };
std::atomic<float> gOuter  { 1.0f };

} // namespace

void MosaicNadir::setEnabled(bool enabled)
{
    gEnabled.store(enabled, std::memory_order_relaxed);
}

bool MosaicNadir::enabled()
{
    return gEnabled.load(std::memory_order_relaxed);
}

void MosaicNadir::setInnerFactor(float factor)
{
    if (factor < 0.0f) factor = 0.0f;
    if (factor > 1.5f) factor = 1.5f;
    gInner.store(factor, std::memory_order_relaxed);
}

float MosaicNadir::innerFactor()
{
    return gInner.load(std::memory_order_relaxed);
}

void MosaicNadir::setOuterFactor(float factor)
{
    if (factor < 0.1f) factor = 0.1f;
    if (factor > 2.5f) factor = 2.5f;
    gOuter.store(factor, std::memory_order_relaxed);
}

float MosaicNadir::outerFactor()
{
    return gOuter.load(std::memory_order_relaxed);
}

float MosaicNadir::weightAt(float groundOffsetM, float depthM)
{
    if (!enabled() || !(depthM > 0.0f)) {
        return 0.0f;
    }

    const float outer = outerFactor() * depthM;
    if (!(outer > 0.0f) || groundOffsetM >= outer) {
        return 0.0f;
    }

    // inner is read through outer rather than clamped at the setter, so the two
    // rows can be moved in either order without one of them refusing a value
    // because of where the other happens to be at that instant.
    float inner = innerFactor() * depthM;
    if (inner >= outer) {
        inner = 0.0f;
    }
    if (groundOffsetM <= inner) {
        return 1.0f;
    }

    const float u = (outer - groundOffsetM) / (outer - inner); // 0 at outer, 1 at inner
    return u * u * (3.0f - 2.0f * u);
}
