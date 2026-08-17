#include "echogram_sidescan_tvg.h"

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstring>
#include <vector>

namespace {

std::atomic<float>    g_spreading{EchogramSideScanTvg::kDefaultSpreadingDbDec};
std::atomic<float>    g_absorption{EchogramSideScanTvg::kDefaultAbsorptionDbM};
std::atomic<float>    g_refRange{EchogramSideScanTvg::kDefaultRefRangeM};
std::atomic<float>    g_capDb{EchogramSideScanTvg::kDefaultCapDb};
std::atomic<float>    g_noiseFloor{EchogramSideScanTvg::kDefaultNoiseFloorStrength};
std::atomic<float>    g_boostBeta{EchogramSideScanTvg::kDefaultBoostBeta};
std::atomic<bool>     g_mosaic{false};
std::atomic<uint32_t> g_version{1};

template <typename T>
void storeClampedAndBump(std::atomic<T>& slot, T value)
{
    if (slot.exchange(value) != value) {
        g_version.fetch_add(1);
    }
}

// Per-thread gain-curve cache: the curve only depends on (version,
// resolution, offset, n), which are constant across consecutive epochs of
// the same channel, so in practice it is computed once per settings change.
struct GainCache {
    uint32_t version = 0;
    float    resolution = -1.0f;
    float    offset = -1.0f;
    int      n = -1;
    std::vector<float> gain;
};
thread_local GainCache t_gainCache;

const std::vector<float>& gainCurve(int n, float resolution, float offsetM)
{
    GainCache& c = t_gainCache;
    const uint32_t ver = EchogramSideScanTvg::version();
    if (c.version == ver && c.resolution == resolution && c.offset == offsetM && c.n == n) {
        return c.gain;
    }

    c.version = ver;
    c.resolution = resolution;
    c.offset = offsetM;
    c.n = n;
    c.gain.resize(size_t(n));

    const float S     = EchogramSideScanTvg::spreading();
    const float a     = EchogramSideScanTvg::absorption();
    const float rRef  = EchogramSideScanTvg::refRange();
    const float cap   = EchogramSideScanTvg::capDb();
    const float floorDb = EchogramSideScanTvg::kFloorDb;
    const float r0    = EchogramSideScanTvg::kMinRangeM;
    const float log10Ref = std::log10(rRef);

    for (int i = 0; i < n; ++i) {
        const float r = offsetM + float(i) * resolution;
        const float rr = (r > r0) ? r : r0;
        float gDb = S * (std::log10(rr) - log10Ref) + a * (r - rRef);
        if (gDb > cap) gDb = cap;
        else if (gDb < floorDb) gDb = floorDb;
        c.gain[size_t(i)] = std::pow(10.0f, gDb * 0.05f);
    }
    return c.gain;
}

// Per-ping noise floor: median of the water-column window (past the
// ring-down, before any realistic first return). Sampled (<=64 values) so
// the cost is constant. Returns 0 when the window is not usable (very
// shallow water / offset window) — fail-safe: no subtraction.
float noiseFloor(const uint8_t* src, int n, float resolution, float offsetM)
{
    const int i0 = std::max(0, int((EchogramSideScanTvg::kNoiseWinLoM - offsetM) / resolution + 0.5f));
    const int i1 = std::min(n - 1, int((EchogramSideScanTvg::kNoiseWinHiM - offsetM) / resolution + 0.5f));
    const int span = i1 - i0 + 1;
    if (span < 16) {
        return 0.0f;
    }

    uint8_t buf[64];
    int m = 0;
    const int stride = std::max(1, span / 64);
    for (int i = i0; i <= i1 && m < 64; i += stride) {
        buf[m++] = src[i];
    }
    std::nth_element(buf, buf + m / 2, buf + m);
    float floorV = float(buf[m / 2]);
    if (floorV > EchogramSideScanTvg::kNoiseFloorMax) {
        floorV = EchogramSideScanTvg::kNoiseFloorMax;
    }
    return floorV;
}

} // namespace

void EchogramSideScanTvg::setSpreading(float dbPerDecade)
{
    if (!(dbPerDecade >= 0.0f)) dbPerDecade = 0.0f; // also catches NaN
    if (dbPerDecade > kMaxSpreadingDbDec) dbPerDecade = kMaxSpreadingDbDec;
    storeClampedAndBump(g_spreading, dbPerDecade);
}

float EchogramSideScanTvg::spreading() { return g_spreading.load(); }

void EchogramSideScanTvg::setAbsorption(float dbPerMeter)
{
    if (!(dbPerMeter >= 0.0f)) dbPerMeter = 0.0f;
    if (dbPerMeter > kMaxAbsorptionDbM) dbPerMeter = kMaxAbsorptionDbM;
    storeClampedAndBump(g_absorption, dbPerMeter);
}

float EchogramSideScanTvg::absorption() { return g_absorption.load(); }

void EchogramSideScanTvg::setRefRange(float meters)
{
    if (!(meters >= kMinRefRangeM)) meters = kDefaultRefRangeM; // also catches NaN
    if (meters > kMaxRefRangeM) meters = kMaxRefRangeM;
    storeClampedAndBump(g_refRange, meters);
}

float EchogramSideScanTvg::refRange() { return g_refRange.load(); }

void EchogramSideScanTvg::setCapDb(float capDb)
{
    if (!(capDb >= 0.0f)) capDb = kDefaultCapDb;
    if (capDb > kMaxCapDb) capDb = kMaxCapDb;
    storeClampedAndBump(g_capDb, capDb);
}

float EchogramSideScanTvg::capDb() { return g_capDb.load(); }

void EchogramSideScanTvg::setNoiseFloorStrength(float strength01)
{
    if (!(strength01 >= 0.0f)) strength01 = 0.0f; // also catches NaN
    if (strength01 > 1.0f) strength01 = 1.0f;
    storeClampedAndBump(g_noiseFloor, strength01);
}

float EchogramSideScanTvg::noiseFloorStrength() { return g_noiseFloor.load(); }

void EchogramSideScanTvg::setBoostBeta(float beta)
{
    if (!(beta >= 0.0f)) beta = 0.0f;
    if (beta > kMaxBoostBeta) beta = kMaxBoostBeta;
    storeClampedAndBump(g_boostBeta, beta);
}

float EchogramSideScanTvg::boostBeta() { return g_boostBeta.load(); }

void EchogramSideScanTvg::setMosaicEnabled(bool enabled) { g_mosaic.store(enabled); }

bool EchogramSideScanTvg::mosaicEnabled() { return g_mosaic.load(); }

uint32_t EchogramSideScanTvg::version() { return g_version.load(); }

void EchogramSideScanTvg::apply(const QVector<uint8_t>& raw, float resolution, float offsetM, QVector<uint8_t>& out)
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

    if (!(resolution > 0.0f)) {
        std::memcpy(dst, src, size_t(n)); // fail-safe: neutral
        return;
    }

    const std::vector<float>& gain = gainCurve(n, resolution, offsetM);
    const float nfStrength = g_noiseFloor.load();
    const float floorV = (nfStrength > 0.001f) ? nfStrength * noiseFloor(src, n, resolution, offsetM) : 0.0f;
    const float beta = g_boostBeta.load();

    if (beta <= 0.01f) {
        for (int i = 0; i < n; ++i) {
            float v = (float(src[i]) - floorV) * gain[size_t(i)];
            const int q = int(v + 0.5f);
            dst[i] = (q > 255) ? uint8_t(255) : (q < 0 ? uint8_t(0) : uint8_t(q));
        }
        return;
    }

    // Detail boost path: keep the gained signal in floats, then unsharp with
    // a running-sum box blur along range.
    thread_local std::vector<float> scratch;
    if (int(scratch.size()) < n) {
        scratch.resize(size_t(n));
    }
    for (int i = 0; i < n; ++i) {
        float v = (float(src[i]) - floorV) * gain[size_t(i)];
        scratch[size_t(i)] = (v > 0.0f) ? v : 0.0f;
    }

    int win = int(kBoostWinM / resolution + 0.5f);
    if (win < 3) win = 3;
    if (win > 101) win = 101;
    if ((win & 1) == 0) ++win;
    const int half = win / 2;

    double runSum = 0.0;
    for (int i = 0; i < win && i < n; ++i) {
        runSum += scratch[size_t(i)];
    }
    if (n <= win) {
        const float mean = float(runSum / double(n));
        for (int i = 0; i < n; ++i) {
            const float v = scratch[size_t(i)] + beta * (scratch[size_t(i)] - mean);
            const int q = int(v + 0.5f);
            dst[i] = (q > 255) ? uint8_t(255) : (q < 0 ? uint8_t(0) : uint8_t(q));
        }
        return;
    }

    const float invWin = 1.0f / float(win);
    for (int i = 0; i < n; ++i) {
        // window centered on i where possible, clamped at the edges
        if (i > half && i + half < n) {
            runSum += double(scratch[size_t(i + half)]) - double(scratch[size_t(i - half - 1)]);
        }
        const float blur = float(runSum) * invWin;
        const float v = scratch[size_t(i)] + beta * (scratch[size_t(i)] - blur);
        const int q = int(v + 0.5f);
        dst[i] = (q > 255) ? uint8_t(255) : (q < 0 ? uint8_t(0) : uint8_t(q));
    }
}
