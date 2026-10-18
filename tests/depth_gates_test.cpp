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

    std::printf(fails ? "%d FAILED\n" : "all passed\n", fails);
    return fails ? 1 : 0;
}
