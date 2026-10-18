// g++ -std=c++17 -I../src tests/depth_gates_test.cpp -o /tmp/depth_gates_test && /tmp/depth_gates_test
// No Qt: checks the pure arithmetic of src/depth_gates.h against hand cases and the numbers of the analysis.
#include "depth_gates.h"
#include <cassert>
#include <cstdio>
#include <vector>

using namespace depthgates;

static int fails = 0;
#define CHECK(c) do { if (!(c)) { std::printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); ++fails; } } while (0)

int main()
{
    // Gate A: the red on the shore - 45.9 m found at a 51 m range, maxDistance 50 -> reach min(50, 45.9) = 45.9,
    // 0.75 x 45.9 = 34.4 -> rejected. A 5.6 m bottom at 13.2 m range is kept. 0.53 m in the 51 m range is kept.
    CHECK(gateA(45.9f, 50.0f, 51.0f));
    CHECK(gateA(40.3f, 50.0f, 51.0f));
    CHECK(!gateA(5.6f, 50.0f, 13.2f));
    CHECK(!gateA(0.53f, 50.0f, 51.0f));
    // the blue: 19.8 m at 25.1 m per side, maxDistance 35 -> reach 22.6, edge 16.9 -> rejected; 11.5 m kept (B's job)
    CHECK(gateA(19.8f, 35.0f, 25.1f));
    CHECK(!gateA(11.5f, 35.0f, 25.1f));
    // at 50 m per side the 35.06 cap: reach min(35, 45) = 35, edge 26.25 -> 33 rejected, 25 kept
    CHECK(gateA(33.0f, 35.0f, 50.0f));
    CHECK(!gateA(25.0f, 35.0f, 50.0f));
    // no bottom / no range: never rejects
    CHECK(!gateA(NAN, 50.0f, 51.0f));
    CHECK(!gateA(10.0f, 50.0f, 0.0f));
    // a maxDistance that is unknown (NaN, the first pass) falls back to the range alone
    CHECK(gateA(45.9f, NAN, 51.0f));
    CHECK(reachableEnd(NAN, 51.0f) == 0.9f * 51.0f);

    // Echo contrast: a flat trace of 20 with a bottom echo of 200 at 5 m (10 mm spacing)
    std::vector<uint8_t> amp(1000, 20);
    for (int i = 495; i < 505; ++i) amp[i] = 200;
    const float c = echoContrast(amp.data(), int(amp.size()), 0.01f, 0.0f, 5.0f);
    CHECK(std::fabs(c - 200.0f / 21.0f) < 1e-4f);
    // no echo at the found bottom: contrast ~1
    const float c2 = echoContrast(amp.data(), int(amp.size()), 0.01f, 0.0f, 8.0f);
    CHECK(std::fabs(c2 - 20.0f / 21.0f) < 1e-4f);
    // a bottom past the trace, or none: NaN
    CHECK(std::isnan(echoContrast(amp.data(), int(amp.size()), 0.01f, 0.0f, 12.0f)));
    CHECK(std::isnan(echoContrast(amp.data(), int(amp.size()), 0.01f, 0.0f, NAN)));
    // the ringdown is skipped: a loud first 0.4 m does not lift the median
    std::vector<uint8_t> ring(1000, 20);
    for (int i = 0; i < 40; ++i) ring[i] = 255;
    for (int i = 495; i < 505; ++i) ring[i] = 200;
    CHECK(std::fabs(echoContrast(ring.data(), 1000, 0.01f, 0.0f, 5.0f) - 200.0f / 21.0f) < 1e-4f);

    // Gate B's vote: 9 epochs, weak in the majority -> reject; a re-published epoch overwrites its own entry;
    // the vote for e ignores epochs after e
    GateBVoter v;
    for (int e = 0; e < 9; ++e) v.set(e, true, e < 5);        // 5 weak of 9
    CHECK(v.reject(8));
    v.set(4, true, false);                                      // 4 weak of 9 - not a majority
    CHECK(!v.reject(8));
    for (int e = 9; e < 20; ++e) v.set(e, true, true);
    CHECK(v.reject(19));
    CHECK(!v.reject(8));                                        // unchanged by what came after
    CHECK(!v.reject(100));                                      // unknown epoch
    v.set(21, false, false);                                    // no bottom -> never rejected
    CHECK(!v.reject(21));
    // epochs without a bottom do not count: 3 weak of 3 with bottom among 9 -> reject
    GateBVoter w;
    for (int e = 0; e < 9; ++e) w.set(e, e % 3 == 0, true);
    CHECK(w.reject(6));

    // The outlier filter. A steady 5 m bottom at 14 epochs/s; a 2-epoch spike to 44 m is held (NaN), then
    // the bottom continues and the spike stays out; a real drop to 8 m persists and is released after ~1 s
    // with the held epochs rewritten; a slope within 30%/s is never touched.
    OutlierFilter f;
    for (int e = 0; e < 30; ++e) { auto r = f.apply(e, 5.0f, 14); CHECK(!r.held); CHECK(r.stored == 5.0f); }
    auto s1 = f.apply(30, 44.0f, 14); CHECK(s1.held); CHECK(std::isnan(s1.stored));
    auto s2 = f.apply(31, 43.5f, 14); CHECK(s2.held);
    for (int e = 32; e < 60; ++e) { auto r = f.apply(e, 5.1f, 14); CHECK(!r.held); CHECK(!r.confirmed); }
    int confirmedAt = -1; size_t releasedN = 0;
    for (int e = 60; e < 90; ++e) {
        auto r = f.apply(e, 8.0f, 14);
        if (r.confirmed && confirmedAt < 0) { confirmedAt = e; releasedN = r.released.size(); }
        if (confirmedAt >= 0 && e > confirmedAt) CHECK(!r.held && r.stored == 8.0f);
        if (confirmedAt < 0) CHECK(r.held);
    }
    CHECK(confirmedAt == 69);            // need = 10 of 14 -> the 10th held epoch confirms
    CHECK(releasedN == 9);               // the nine before it are released with their real value
    // a re-published epoch is judged afresh against the epochs before it (the realtime pass re-publishes the
    // last ~6): the same value gets the same answer, a changed value is judged on its own
    CHECK(!f.apply(88, 8.0f, 14).held);
    CHECK(f.apply(88, 44.0f, 14).held);
    CHECK(!f.apply(88, 8.0f, 14).held);
    // a slope: 1.4 -> 5.6 m over 30 s at 14/s (0.01 m per epoch) - never held
    OutlierFilter g; bool anyHeld = false;
    for (int e = 0; e < 420; ++e) anyHeld = anyHeld || g.apply(e, 1.4f + 0.01f * e, 14).held;
    CHECK(!anyHeld);
    // the first values after a long gap (the shore) are accepted without a reference
    OutlierFilter h;
    for (int e = 0; e < 10; ++e) h.apply(e, 45.0f, 9);
    for (int e = 10; e < 200; ++e) h.noBottom(e);
    CHECK(!h.apply(200, 0.53f, 14).held);
    // NaN is ignored, not a reset: the reference survives a no-bottom epoch
    OutlierFilter k;
    for (int e = 0; e < 20; ++e) k.apply(e, 5.0f, 14);
    k.apply(20, NAN, 14);
    CHECK(k.apply(21, 30.0f, 14).held);

    // The choice. minDistance 0.25 (floor 0.37). Red at 15:03:30: bt 0.39 / rf 0.37 - both read the bottom, the
    // bottom track is right and keeps the readout (not at its floor, not a second echo); the
    // transducer touching: bt 0.32 / rf 0.12 -> shallow; the second echo: bt 0.55 / rf 0.22 -> shallow (2.5 x);
    // bt 0.90 / rf 0.90 -> not shallow (over rfEnter); bt 1.1 / rf 0.46 -> the bottom track does not agree
    // (2.4 x is a second echo... of 0.46: yes it agrees) -> shallow; bt 5.0 / rf 0.4 -> no (12 x), the blue's
    // ringdown while the bottom track reads a real 5 m bottom; no bottom / rf 0.3 -> shallow.
    CHECK(!shallowMode(false, true, 0.37f, 0.39f, 0.25f));
    CHECK(shallowMode(false, true, 0.12f, 0.32f, 0.25f));
    CHECK(shallowMode(false, true, 0.22f, 0.55f, 0.25f));
    CHECK(!shallowMode(false, true, 0.90f, 0.90f, 0.25f));
    CHECK(shallowMode(false, true, 0.46f, 1.10f, 0.25f));
    CHECK(!shallowMode(false, true, 0.40f, 5.00f, 0.25f));
    CHECK(shallowMode(false, true, 0.30f, NAN, 0.25f));
    // hysteresis: in shallow mode the rangefinder may rise to 0.7 before handing back; a stale rangefinder
    // hands back at once; a blue spike (rf 24 m) never enters
    CHECK(shallowMode(true, true, 0.65f, 0.34f, 0.25f));
    CHECK(!shallowMode(true, true, 0.75f, 0.34f, 0.25f));
    CHECK(!shallowMode(true, false, 0.30f, 0.34f, 0.25f));
    CHECK(!shallowMode(false, true, 24.0f, 9.5f, 0.25f));
    CHECK(!shallowMode(false, true, 0.55f, 0.60f, 0.25f));   // over rfEnter: stays with the bottom track

    std::printf(fails ? "%d FAILED\n" : "all passed\n", fails);
    return fails ? 1 : 0;
}
