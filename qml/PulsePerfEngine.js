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

// THE PULSE THAT SUITS A SPACING (3 Oct 2026, the partner doc section 5). A CW pulse of N
// cycles at f covers a range cell of c x N / f / 2; two samples per cell is the match, so
// N = 4 x spacing x f / c - about 1.2 x spacing in mm at 460 kHz. 4-30 cycles: below ~4 a
// resonant transducer rings longer than it is told anyway; 30 is the expert row's ceiling.
function pulseCycles(spacingMm, freqKHz, soundSpeed) {
    var c = soundSpeed > 0 ? soundSpeed : 1500
    var f = (freqKHz > 0 ? freqKHz : 460) * 1000
    var n = Math.round(4 * (spacingMm / 1000) * f / c)
    return Math.max(4, Math.min(30, n))
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
