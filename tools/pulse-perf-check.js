#!/usr/bin/env node
//
// pulse-perf-check.js - a standing check on the performance mode arithmetic.
//
//   node tools/pulse-perf-check.js
//
// qml/PulsePerfEngine.js is a `.pragma library` file with no QML in it, so its functions
// run here as they are. What is asserted, and why each one matters:
//
//   * the wire model reproduces the link measurement of 2 Oct (chapter 9a): the shipped
//     2000 x 25 mm at 70 ms is ~34%, 5000 at 70 ms ~84%, 60 ms ~96%, 55 ms over 100%
//   * the engine's table for blue at the 15 mm expert default and at the 1 mm production
//     floor (chapter 7)
//   * NOTHING the engine can plan is above the 85% budget - every range 5..35 m, every
//     floor 1..50 mm, every samples ceiling, at 921600 and at a wrong 115200
//   * the configurations that killed the link (5000 at 55 and at 60 ms) never come out
//   * the listen time holds the period: 5000 x 25 mm (62.5 m per side) runs at ~87 ms
//   * the baud choice: the 12-minute 115200 run of 9a goes to the table
//   * RED AND BLACK (Task 2b, 4 Oct): the exact byte count reproduces the USB/wifi desk run,
//     and the link-fit plan never goes above 85%, below the 72 ms floor or the listen time,
//     never coarser than 50 mm, never above 1020 samples, never fewer pings than today
//
// Exit code 0 = all checks passed.

const fs = require("fs");
const path = require("path");

const repo = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(repo, "qml", "PulsePerfEngine.js"), "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const E = new Function(src + "\nreturn { bytesPerPing, loadPercent, listenTimeMs, realPeriodMs, rangePerSideM, plan, chooseBaud, pulseCycles, BUDGET, bytesPerPingExact, loadPercentExact, redPlan, RED_PING_FLOOR_MS };")();

let failures = 0;
function check(cond, what) {
    if (cond) { console.log("  ok   " + what); }
    else      { console.log("  FAIL " + what); failures++; }
}
function near(a, b, tol) { return Math.abs(a - b) <= tol; }

const BLUE = 921600, RED = 115200, C = 1500;

console.log("the wire model against the 9a measurement");
check(E.bytesPerPing(5000) === 5360, "5000 samples = 25 fragments x 214 + 10 = 5360 bytes per ping");
check(near(E.loadPercent(2000, 70, BLUE), 34, 2), "shipped 2000 @ 70 ms ~34% (measured 31-37%): " + E.loadPercent(2000, 70, BLUE).toFixed(1));
check(near(E.loadPercent(5000, 70, BLUE), 84, 1.5), "5000 @ 70 ms ~84% (measured 80-88): " + E.loadPercent(5000, 70, BLUE).toFixed(1));
check(near(E.loadPercent(5000, 60, BLUE), 97, 2), "5000 @ 60 ms ~96% (measured, the edge): " + E.loadPercent(5000, 60, BLUE).toFixed(1));
check(E.loadPercent(5000, 55, BLUE) > 100, "5000 @ 55 ms over 100% (killed the link): " + E.loadPercent(5000, 55, BLUE).toFixed(1));
check(near(E.realPeriodMs(70, E.rangePerSideM(5000, 25, 2), 1480), 87.5, 1),
      "5000 x 25 mm = 62.5 m per side: the firmware holds ~87 ms (measured 87): " + E.realPeriodMs(70, 62.5, 1480).toFixed(1));

function blue(rangeM, expertFloor, hwFloor, extra) {
    return E.plan(Object.assign({ rangeM, channels: 2, hwFloorMm: hwFloor, expertFloorMm: expertFloor,
                                  maxSamples: 5000, periodMs: 70, baud: BLUE, soundSpeed: C }, extra || {}));
}

console.log("blue at the 15 mm expert default (chapter 7)");
const t15 = { 35: [15, 4700], 25: [15, 3350], 15: [15, 2000], 10: [15, 1350], 5: [15, 700] };
for (const r of Object.keys(t15)) {
    const p = blue(+r, 15, 15);
    check(p.spacingMm === t15[r][0] && p.samples === t15[r][1] && p.limitedBy === "min spacing" && p.rangeM >= +r,
          r + " m -> " + p.spacingMm + " mm x " + p.samples + " (" + p.rangeM.toFixed(2) + " m, " + p.loadPercent.toFixed(0) + "%, " + p.limitedBy + ")");
}

console.log("production blue at a 1 mm floor (chapter 7)");
const t1 = { 35: 14, 25: 10, 15: 6, 10: 4, 5: 2 };
for (const r of Object.keys(t1)) {
    const p = blue(+r, 1, 1);
    check(p.spacingMm === t1[r] && p.samples === 5000 && p.rangeM >= +r && p.loadPercent <= 85,
          r + " m -> " + p.spacingMm + " mm x " + p.samples + " (" + p.loadPercent.toFixed(1) + "%)");
}

console.log("the Max range ceiling's 50 m (3 Oct): the longest range 70 ms still listens to");
check(E.listenTimeMs(50, C) <= 70 && E.listenTimeMs(55, C) > 70,
      "listen time 50 m = " + E.listenTimeMs(50, C).toFixed(1) + " ms, 55 m = " + E.listenTimeMs(55, C).toFixed(1) + " ms");
for (const [r, f, sp, n] of [[40, 15, 16, 5000], [45, 15, 18, 5000], [50, 15, 20, 5000], [50, 1, 20, 5000]]) {
    const p = blue(r, f, f);
    check(p.spacingMm === sp && p.samples === n && p.realPeriodMs === 70 && p.loadPercent <= 85,
          r + " m at a " + f + " mm floor -> " + p.spacingMm + " mm x " + p.samples + " @ " + p.realPeriodMs + " ms, " + p.loadPercent.toFixed(1) + "%");
}

console.log("the hardware floor binds the expert row; the expert can only tighten");
check(blue(10, 1, 15).spacingMm === 15, "Basic2D with Min spacing blue at 1 mm still gets 15 mm");
check(blue(10, 20, 15).spacingMm === 20, "Min spacing blue 20 mm on Basic2D gives 20 mm");
check(blue(25, 1, 1, { maxSamples: 2000 }).samples <= 2000, "Max samples 2000 is a ceiling");
check(blue(25, 1, 1, { maxSamples: 2000 }).limitedBy === "max samples", "... and is named as what binds");

console.log("nothing above the 85% budget, anywhere");
let worst = 0, worstAt = "", over = 0, period = 0;
for (const baud of [BLUE, RED]) {
    for (let r = 5; r <= 35; r += 1) {
        for (let f = 1; f <= 50; f++) {
            for (const sm of [500, 1000, 2000, 3350, 5000]) {
                const p = blue(r, f, 1, { maxSamples: sm, baud });
                const l = p.loadPercent;
                if (l > worst) { worst = l; worstAt = r + " m, floor " + f + ", max " + sm + ", baud " + baud; }
                if (l > 85.0001) over++;
                if (p.realPeriodMs < 70) period++;
                if (p.samples > sm || p.samples > 5000) over++;
            }
        }
    }
}
check(over === 0, "no plan over 85% or over its samples ceiling (worst " + worst.toFixed(2) + "% at " + worstAt + ")");
check(period === 0, "no plan runs faster than 70 ms");

console.log("the configurations that killed the link never come out");
const at60 = blue(25, 1, 1, { periodMs: 60 }), at55 = blue(25, 1, 1, { periodMs: 55 });
check(at60.loadPercent <= 85 && at60.samples < 5000 && at60.limitedBy === "link", "asked for 60 ms: " + at60.samples + " x " + at60.spacingMm + " mm, " + at60.loadPercent.toFixed(1) + "%");
check(at55.loadPercent <= 85 && at55.samples < 5000, "asked for 55 ms: " + at55.samples + " x " + at55.spacingMm + " mm, " + at55.loadPercent.toFixed(1) + "%");
const wrong = blue(25, 15, 15, { baud: RED });
check(wrong.loadPercent <= 85 && wrong.limitedBy === "link", "a blue budgeted on 115200 fits 115200: " + wrong.samples + " x " + wrong.spacingMm + " mm");

console.log("the pulse that suits a spacing (Pulse follows the range)");
const pc = { 2: 4, 4: 5, 6: 7, 8: 10, 10: 10, 14: 10, 15: 10, 20: 10 };
for (const sp of Object.keys(pc)) {
    const n = E.pulseCycles(+sp, 460, C);
    check(n === pc[sp], sp + " mm at 460 kHz -> " + n + " cycles");
}
check(E.pulseCycles(8, 460, C) === 10, "8 mm keeps today's 10 cycles - the match point");
check(E.pulseCycles(1, 460, C) === 4, "never below 4 cycles");
let longest = 0;
for (let sp = 1; sp <= 100; sp++)
    for (const f of [320, 460, 820, 850])
        longest = Math.max(longest, E.pulseCycles(sp, f, C));
check(longest === 10, "NEVER above 10 cycles, at any spacing or frequency (the hardware partner: resistors) - longest " + longest);
check(E.pulseCycles(4, 820, C) === 9, "the count follows the frequency: 4 mm at 820 kHz -> " + E.pulseCycles(4, 820, C));

console.log("which baud to trust");
let b = E.chooseBaud(115200, false, 80000, BLUE);
check(b.baud === BLUE, "the 12-minute run of 9a (115200 reported, 80 kB/s arriving) -> the table: " + b.source);
b = E.chooseBaud(921600, true, 31000, BLUE);
check(b.baud === BLUE && /reported/.test(b.source), "a settled 921600 is taken as reported");
b = E.chooseBaud(115200, true, 0, BLUE);
check(b.baud === 0, "nothing flowing -> wait, never budget on a default");
b = E.chooseBaud(0, true, 31000, BLUE);
check(b.baud === BLUE, "nothing reported -> the table");

console.log("red and black - the exact byte count against the desk run of 4 Oct (115200)");
check(E.bytesPerPingExact(500) === 552, "500 samples = 2 x 214 + 114 + 10 = 552 bytes (the full-fragment count says " + E.bytesPerPing(500) + ")");
check(E.bytesPerPingExact(5000) === E.bytesPerPing(5000), "at whole fragments the two counts agree (blue untouched)");
// measured: [samples, period really run (ms), measured % of 115200]
const desk = [[500, 1000 / 14.0, 69.6], [300, 1000 / 14.0, 43.6], [200, 1000 / 14.0, 29.9],
              [500, 80, 62.6], [600, 1000 / 14.0, 81.5], [800, 110, 70.7], [1000, 150, 65.2]];
for (const [smp, t, meas] of desk) {
    const pred = E.loadPercentExact(smp, t, RED, 330);
    check(near(pred, meas, 2.0), smp + " samples at " + t.toFixed(1) + " ms: predicted " + pred.toFixed(1) + "%, measured " + meas + "%");
}

console.log("red and black - the link-fit plan");
const P = (r) => E.redPlan({ rangeMm: r, baud: RED, finestMm: 2, coarsestMm: 50, samplesMax: 1020, periodMaxMs: 154, floorMs: 72 });
let p2 = P(25000);
check(p2.samples === 600 && p2.spacingMm === 42 && p2.periodMs === 72, "25 m (the shallow scheme's deepest): 600 x 42 mm at 72 ms (today 500 x 50 asked at 50, run at 71.4)");
p2 = P(5000);
check(p2.samples === 600 && p2.spacingMm === 9 && p2.periodMs === 72, "5 m: 600 x 9 mm at 72 ms (today 500 x 10)");
p2 = P(40000);
check(p2.samples === 800 && p2.spacingMm === 50 && p2.periodMs === 92, "40 m: 800 x 50 mm at 92 ms - 10.9 pings/s, today 9.1 at 110");
p2 = P(50000);
check(p2.samples === 1000 && p2.periodMs === 115, "50 m: 1000 x 50 mm at 115 ms - 8.7 pings/s, today 6.7 at 150");
p2 = P(60000);
check(p2.samples === 1020, "beyond 51 m the samples stop at 1020, as today");
let redWorst = 0, everBelowFloor = false, everCoarse = false, everFewer = false, shrinks = false;
for (let r = 1000; r <= 60000; r += 250) {
    const q = P(r);
    redWorst = Math.max(redWorst, q.loadPercent);
    if (q.periodMs < 72) everBelowFloor = true;
    if (q.spacingMm > 50) everCoarse = true;
    if (q.rangeMm < Math.min(r, 1020 * 50)) shrinks = true;
    // today's period for the same range: 50 asked (71.4 real) up to 25 m, then 2 x res - 50
    const todayT = r <= 25000 ? 1000 / 14.0 : Math.min(154, Math.max(72, 2 * Math.ceil(r / 500) - 50));
    if (q.periodMs > todayT + 1) everFewer = true;
}
check(redWorst <= 85.0, "nothing the plan can produce is above 85% of 115200 (worst " + redWorst.toFixed(1) + "%)");
check(!everBelowFloor, "never below the 72 ms floor");
check(!everCoarse, "never coarser than 50 mm");
check(!shrinks, "always acquires at least the range the scheme asked for");
check(!everFewer, "never fewer pings than today at the same range");

console.log(failures === 0 ? "\nAll performance arithmetic checks passed." : "\n" + failures + " check(s) FAILED.");
process.exit(failures === 0 ? 0 : 1);
