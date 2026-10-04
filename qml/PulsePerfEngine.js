.pragma library
// PULSE PERFORMANCE MODE - THE ARITHMETIC (step 2, 2 Oct 2026)
//
// Pure functions, no QML and no state, so tools/pulse-perf-check.js can run every number
// here in node without a build. The engine (PulsePerformanceEngine.qml) owns the gate, the
// throttle and the one-at-a-time sends; this file only answers "what should the transducer
// be told for this range". Chapter 6.1 of claude/pulse-high-performance-mode.md, with the
// link measurement of chapter 9a behind every constant.
//
// THE RULE THE MEASUREMENT SET (9a): overload does not degrade, it kills. 5000 x 15 mm at
// 70 ms ran at ~84% of 921600 for 10+ minutes; 55 ms killed the link without warning and
// the transducer needed a power cycle, while lost samples stayed at 0.1-0.3% right up to
// it. So the budget is computed, never searched for on the water, and nothing here may
// ever come out above BUDGET.

var FRAGMENT_SAMPLES = 200      // samples per chart fragment, measured from the logs
var FRAGMENT_BYTES   = 214      // one full fragment on the wire: 200 + 6 header + 8 framing
var TEMP_FRAME_BYTES = 10       // the temperature frame each ping carries
var POLL_BYTES_PER_S = 330      // the app's version poll answers, measured (9a)
var BUDGET           = 0.85     // of the UART's bytes/s; 9a: ~12% to the edge and no more
var LISTEN_MARGIN_MS = 3        // the firmware holds 2R/c + ~3 ms (9a, rows 2-3)
var HW_MAX_SAMPLES   = 5000     // the firmware's maximum (27 Sept)
var SAMPLE_STEP      = 50

// What one ping of S samples (both channels counted) costs on the wire.
function bytesPerPing(samples) {
    return Math.ceil(samples / FRAGMENT_SAMPLES) * FRAGMENT_BYTES + TEMP_FRAME_BYTES
}

// The UART's byte rate at 8N1 (10 bits per byte).
function wireBytesPerSecond(baud) {
    return baud / 10
}

// What the engine may spend per second on pings, after the polls.
function budgetBytesPerSecond(baud) {
    return BUDGET * wireBytesPerSecond(baud) - POLL_BYTES_PER_S
}

// The load S samples every T ms put on a UART of `baud`, polls included, in percent.
function loadPercent(samples, periodMs, baud) {
    if (!(baud > 0) || !(periodMs > 0))
        return -1
    var bps = bytesPerPing(samples) * 1000 / periodMs + POLL_BYTES_PER_S
    return bps * 100 / wireBytesPerSecond(baud)
}

// The firmware's listen time for a range per side: it will not ping faster than this,
// whatever it is asked (9a, rows 2-3).
function listenTimeMs(rangePerSideM, soundSpeed) {
    var c = soundSpeed > 0 ? soundSpeed : 1500
    return 2 * rangePerSideM / c * 1000 + LISTEN_MARGIN_MS
}

// The period the transducer will REALLY run at.
function realPeriodMs(askedMs, rangePerSideM, soundSpeed) {
    return Math.max(askedMs, listenTimeMs(rangePerSideM, soundSpeed))
}

// The range per side a setting covers: samples x spacing / channels. One byte per sample,
// a blue's two channels interleaved, so 5000 x 3 mm = 7.5 m per side (27 Sept).
function rangePerSideM(samples, spacingMm, channels) {
    return samples * spacingMm / 1000 / (channels > 0 ? channels : 1)
}

function _roundUpToStep(n) {
    return Math.ceil(n / SAMPLE_STEP) * SAMPLE_STEP
}

// THE PLAN. Input:
//   rangeM          the visible range per side the user is looking at (Max range side)
//   channels        2 for a blue
//   hwFloorMm       the hardware's spacing floor (hardwareSpacingFloorMm: 15 on Basic2D)
//   expertFloorMm   Min spacing blue - the expert can only tighten
//   maxSamples      Max samples - likewise
//   periodMs        what is asked (70 on blue, fixed 2 Oct)
//   baud            the UART rate the engine has decided to trust (see chooseBaud)
//   soundSpeed      m/s
// Output: samples, spacingMm, periodMs, realPeriodMs, rangeM (what the setting covers),
// loadPercent, limitedBy ("min spacing" | "max samples" | "link"), and the floor used.
function plan(p) {
    var ch     = p.channels > 0 ? p.channels : 2
    var floor  = Math.max(1, p.hwFloorMm || 1, p.expertFloorMm || 1)
    var sMax   = Math.min(HW_MAX_SAMPLES, p.maxSamples > 0 ? p.maxSamples : HW_MAX_SAMPLES)
    sMax       = Math.floor(sMax / SAMPLE_STEP) * SAMPLE_STEP
    var rMm    = Math.max(1, p.rangeM) * 1000
    var T      = p.periodMs > 0 ? p.periodMs : 70
    var budget = budgetBytesPerSecond(p.baud)

    var d = Math.max(floor, Math.ceil(ch * rMm / sMax))
    var limitedBy = (d === floor) ? "min spacing" : "max samples"
    var s, real
    for (;;) {
        s = _roundUpToStep(ch * rMm / d)
        if (s > sMax) { d += 1; continue }          // the rounding to 50 went over the ceiling
        real = realPeriodMs(T, rangePerSideM(s, d, ch), p.soundSpeed)
        if (budget > 0 && bytesPerPing(s) * 1000 / real > budget) {
            d += 1                                  // coarser, same range, fewer samples
            limitedBy = "link"
            continue
        }
        break
    }
    return {
        samples:      s,
        spacingMm:    d,
        periodMs:     T,
        realPeriodMs: real,
        rangeM:       rangePerSideM(s, d, ch),
        loadPercent:  loadPercent(s, real, p.baud),
        limitedBy:    limitedBy,
        floorMm:      floor
    }
}

// ---- PULSE RED AND BLACK: THE LINK-FIT DYNAMIC SCHEME (Task 2b, 4 Oct 2026) -------------
//
// THE EXACT BYTE COUNT. bytesPerPing() above charges every fragment a full 214 bytes. That is
// exact for blue's 5000 samples (25 full fragments) and errs on the safe side elsewhere, and
// blue's engine keeps it. A red ping of 500 samples is 2 full fragments and one of 100
// samples (114 bytes): 552 bytes, not 652. The USB desk run of 4 Oct proved it - 14.0 pings x
// 552 B + polls = 8 050 B/s against 7 960-8 070 measured; the full-fragment count would be
// 9 450. A fitted red period needs the exact count or it comes out ~20% too long.
function bytesPerPingExact(samples) {
    var full = Math.floor(samples / FRAGMENT_SAMPLES)
    var rest = samples - full * FRAGMENT_SAMPLES
    return full * FRAGMENT_BYTES + (rest > 0 ? rest + (FRAGMENT_BYTES - FRAGMENT_SAMPLES) : 0) + TEMP_FRAME_BYTES
}

function loadPercentExact(samples, periodMs, baud, pollBytesPerS) {
    if (!(baud > 0) || !(periodMs > 0))
        return -1
    var poll = pollBytesPerS >= 0 ? pollBytesPerS : POLL_BYTES_PER_S
    return (bytesPerPingExact(samples) * 1000 / periodMs + poll) * 100 / wireBytesPerSecond(baud)
}

// THE PING FLOOR. Red and black do not ping faster than ~71.4 ms (14.0 pings/s), whatever is
// asked, sent or used: measured 4 Oct on a red and a black, USB and wifi AP, 200 to 600
// samples, 30-82% of the link (backlog, "The desk run"). Above it the asked period is
// honoured exactly (80 -> 12.5/s, 110 -> 9.1, 150 -> 6.7). 72 ms is asked so the period the
// app believes is the period the transducer runs - which the 2D speed reads.
var RED_PING_FLOOR_MS = 72

// THE PLAN FOR A RED OR BLACK. Olav, 4 Oct: "We will go with the facts: if the transducer
// cannot go beneath the 71 then we adjust to real life facts ... tune the samples to provide
// the best possible quality." Input:
//   rangeMm      the range the dynamic scheme wants acquired (today: 500 x its spacing, i.e.
//                depth + margin, doubled for the second echo; past 25 m its samples x 50 mm)
//   baud         the UART rate (115200 on every red and black in the field)
//   floorMs      the ping floor (RED_PING_FLOOR_MS); periodMaxMs the longest period allowed
//   coarsestMm   the coarsest spacing (50 mm - beyond it the 2D renderer broke, 29 Sept)
//   finestMm     the finest spacing the profile allows
//   samplesMax   the most samples the scheme may use (1020 today)
//   floorSamples the profile's chartSamples - the samples carried at the floor (600 on red)
//   pollBytesPerS  the version poll's cost (330 measured)
// The rule:
//   * AT THE FLOOR, carry the most samples the link allows at 85% (600 at 115200) and spend
//     them on detail: spacing = range / 600. Same 14 pings/s as today, ~20% finer spacing,
//     ~82% of the link - the load 600 x 50 mm at 70 ms already runs at 28 m today.
//   * BEYOND 600 x 50 mm (30 m) the spacing stays at 50 mm, the samples follow the range,
//     and the period is the shortest the link carries at 85% - never below the floor, never
//     below the listen time. 800 samples at 92 ms (10.9 pings/s, was 9.1 at 110), 1000 at
//     115 (8.7/s, was 6.7 at 150): ~20-30% more pings for fish arches at the same detail.
function redPlan(p) {
    var baud    = p.baud > 0 ? p.baud : 115200
    var floorMs = p.floorMs > 0 ? p.floorMs : RED_PING_FLOOR_MS
    var tMax    = p.periodMaxMs > 0 ? p.periodMaxMs : 154
    var coarse  = p.coarsestMm > 0 ? p.coarsestMm : 50
    var fine    = p.finestMm > 0 ? p.finestMm : 2
    var sMax    = p.samplesMax > 0 ? p.samplesMax : 1020
    var poll    = p.pollBytesPerS >= 0 ? p.pollBytesPerS : POLL_BYTES_PER_S
    var rMm     = Math.max(1, p.rangeMm)
    var budget  = BUDGET * wireBytesPerSecond(baud) - poll        // bytes/s for the pings

    // THE SAMPLES AT THE FLOOR ARE THE PROFILE'S (Olav, 4 Oct: "if we want 600 samples for
    // the red it should be in the profile"): p.floorSamples is the profile's chartSamples, so
    // the setup and the plan send the same number. Without it, the most the link allows at
    // 85% (in steps of 50) - which is how the profile's 600 was chosen, and what
    // tools/pulse-perf-check.js holds the profile to.
    var sAtFloor = SAMPLE_STEP
    while (sAtFloor + SAMPLE_STEP <= sMax
           && bytesPerPingExact(sAtFloor + SAMPLE_STEP) * 1000 / floorMs <= budget)
        sAtFloor += SAMPLE_STEP
    var linkMax = sAtFloor
    if (p.floorSamples > 0)
        sAtFloor = Math.min(sMax, p.floorSamples)

    var s, d, t, limitedBy
    if (rMm <= sAtFloor * coarse) {
        s = sAtFloor
        d = Math.max(fine, Math.ceil(rMm / s))
        t = floorMs
        limitedBy = "ping floor - samples spent on detail"
        if (s > linkMax) {      // a profile asking more than the link carries at the floor
            t = Math.min(tMax, Math.ceil(bytesPerPingExact(s) * 1000 / budget))
            limitedBy = "link (the profile's " + s + " samples do not fit at the floor)"
        }
    } else {
        d = coarse
        s = Math.min(sMax, Math.ceil(rMm / d))
        t = Math.ceil(bytesPerPingExact(s) * 1000 / budget)
        limitedBy = "link"
        if (t < floorMs) { t = floorMs; limitedBy = "ping floor" }
        var listen = Math.ceil(2 * (s * d / 1000) / (p.soundSpeed > 0 ? p.soundSpeed : 1480) * 1000 + LISTEN_MARGIN_MS)
        if (t < listen) { t = listen; limitedBy = "listen time" }
        if (t > tMax) { t = tMax; limitedBy = "longest period" }
    }
    return {
        samples:     s,
        spacingMm:   d,
        periodMs:    t,
        rangeMm:     s * d,
        loadPercent: loadPercentExact(s, t, baud, poll),
        pingsPerS:   1000 / t,
        limitedBy:   limitedBy
    }
}

// THE PULSE THAT SUITS A SPACING (3 Oct 2026, the partner doc section 5). A CW pulse of N
// cycles at f covers a range cell of c x N / f / 2; two samples per cell is the match, so
// N = 4 x spacing x f / c - about 1.2 x spacing in mm at 460 kHz. Bounded 4-10 cycles: below
// ~4 a resonant transducer rings longer than it is told anyway, and ABOVE 10 THE HARDWARE IS AT
// RISK - the hardware partner, 3 Oct: the extra transmit energy of a longer pulse can blow
// resistors. 10 is the standard pulse, so the switch only ever SHORTENS it (up to ~20 m at
// 460 kHz); beyond that it is the standard 10 cycles.
var PULSE_MIN_CYCLES = 4
var PULSE_MAX_CYCLES = 10
function pulseCycles(spacingMm, freqKHz, soundSpeed) {
    var c = soundSpeed > 0 ? soundSpeed : 1500
    var f = (freqKHz > 0 ? freqKHz : 460) * 1000
    var n = Math.round(4 * (spacingMm / 1000) * f / c)
    return Math.max(PULSE_MIN_CYCLES, Math.min(PULSE_MAX_CYCLES, n))
}

// WHICH BAUD TO BUDGET ON, decided ONCE per connection while the shipped settings run.
// The device reports its UART in ID_UART, but the value is a default (115200) until the
// answer has settled, and on the G30 one whole 12-minute run never settled (9a, item 5).
// Decided while the shipped 2000 samples at 70 ms flow (~31 kB/s), any 115200 claim is
// proven impossible by the measured rate (the read-out's linkBaudPlausible). Decided later,
// at a short range with few samples, a default 115200 could pass the same test - which is
// why it is decided once and latched, not re-asked on every plan.
//   reported, plausible, measured: DeviceManagerWrapper's linkBaud / linkBaudPlausible /
//   linkBytesPerSecond. table: the model's rate (921600 for the blue family).
function chooseBaud(reported, plausible, measuredBytesPerSecond, tableBaud) {
    if (!(measuredBytesPerSecond > 0))
        return { baud: 0, source: "waiting for data" }
    if (reported > 0 && plausible)
        return { baud: reported, source: "reported by the device" }
    return { baud: tableBaud, source: reported > 0 ? "model table (the reported " + reported + " cannot carry what arrives)"
                                                   : "model table (nothing reported)" }
}
