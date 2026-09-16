#include "echogram_blend.h"

#include <atomic>
#include <cmath>

namespace {

// Defaults are the recommendation, not a neutral starting point: RMS on the
// raw amplitudes is the multi-look estimator the header derives. A build with
// no expert rows on it still shows the blend.
std::atomic<int> gMode  { EchogramBlend::Rms };
std::atomic<int> gDomain{ EchogramBlend::Raw };

// Channel balance, dB, positive favouring the second channel. Zero is "the two
// transducers are assumed matched", which is the only defensible default when
// nothing has measured them.
std::atomic<float> gTrimDb{ 0.0f };

inline uint8_t clamp255(float v)
{
    if (v <= 0.0f)   return 0;
    if (v >= 255.0f) return 255;
    return uint8_t(v + 0.5f);
}

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

void EchogramBlend::setTrimDb(float db)
{
    // +/- 12 dB is far wider than any plausible pair of transducers; the clamp is
    // there so a bad write cannot silently delete one channel.
    if (db < -12.0f) db = -12.0f;
    if (db >  12.0f) db =  12.0f;
    gTrimDb.store(db, std::memory_order_relaxed);
}

float EchogramBlend::trimDb()
{
    return gTrimDb.load(std::memory_order_relaxed);
}

void EchogramBlend::trimGains(float& gainFirst, float& gainSecond)
{
    const float db = trimDb();
    if (db == 0.0f) {
        gainFirst  = 1.0f;
        gainSecond = 1.0f;
        return;
    }
    // Half the trim each way, and 20*log10 because these are amplitudes, not
    // powers: gain = 10^((+/- db/2) / 20) = 10^(+/- db/40).
    gainSecond = std::pow(10.0f,  db / 40.0f);
    gainFirst  = std::pow(10.0f, -db / 40.0f);
}

void EchogramBlend::apply(const uint8_t* a, float gainA,
                          const uint8_t* b, float gainB,
                          int n, QVector<uint8_t>& out)
{
    if (!a || !b || n <= 0) {
        out.clear();
        return;
    }

    if (out.size() != n) {
        out.resize(n);
    }
    uint8_t* dst = out.data();

    // With no trim the two gains are exactly 1.0, so the fast paths below are
    // the untrimmed arithmetic to the bit - a balance nobody has set costs
    // nothing and changes nothing.
    const bool trimmed = (gainA != 1.0f) || (gainB != 1.0f);

    switch (mode()) {
    case Mean:
        if (!trimmed) {
            for (int i = 0; i < n; ++i) {
                dst[i] = uint8_t((int(a[i]) + int(b[i]) + 1) >> 1);
            }
        }
        else {
            for (int i = 0; i < n; ++i) {
                dst[i] = clamp255(0.5f * (gainA * float(a[i]) + gainB * float(b[i])));
            }
        }
        break;

    case Max:
        if (!trimmed) {
            for (int i = 0; i < n; ++i) {
                dst[i] = a[i] > b[i] ? a[i] : b[i];
            }
        }
        else {
            for (int i = 0; i < n; ++i) {
                const float av = gainA * float(a[i]);
                const float bv = gainB * float(b[i]);
                dst[i] = clamp255(av > bv ? av : bv);
            }
        }
        break;

    case Rms:
    default:
        // sqrt((a^2 + b^2)/2). Untrimmed, both inputs are at most 255 so the
        // result is too; a trim can push one of them past that, hence the clamp
        // on the trimmed path only.
        if (!trimmed) {
            for (int i = 0; i < n; ++i) {
                const int ai = a[i];
                const int bi = b[i];
                const float meanIntensity = 0.5f * float(ai * ai + bi * bi);
                dst[i] = uint8_t(std::sqrt(meanIntensity) + 0.5f);
            }
        }
        else {
            for (int i = 0; i < n; ++i) {
                const float av = gainA * float(a[i]);
                const float bv = gainB * float(b[i]);
                dst[i] = clamp255(std::sqrt(0.5f * (av * av + bv * bv)));
            }
        }
        break;
    }
}
