#!/usr/bin/env node
//
// pulse-depth-plan-check.js - a standing check on the dynamic range planner's arithmetic
// (P1 of docs/pulse-ui/pulse-motor-noise-plan.md, 6 Nov 2026).
//
//   node tools/pulse-depth-plan-check.js
//
// Gate A (src/depth_gates.h) stores a bottom beyond 0.75 x 0.9 = 0.675 of the ACQUIRED range
// as "no bottom". The planner in qml/PulseDepthEngine.qml must therefore never ask for a
// range that puts the real bottom over that line - the old depth + 2 m rule did, for every
// bottom past 4.15 m, and the readout lapped between a value and a dash every ~4 s.
//
// plannedRangeRes() is lifted out of the QML file as the JavaScript it is and run through
// the rest of the real chain: the clamp in calculateDynamicResolution, the +1 m deepening
// step of updateDynamicResolutionWithStep (candidateRes + 2), the deep branch's samples x
// 50 mm, and PulsePerfEngine.redPlan, which is what finally sizes the acquired trace.
// What is asserted, depth 0.3 .. 18 m in 0.1 m steps:
//
//   * second echo optimize OFF, at every fraction the expert row offers (0.45 .. 0.65) and
//     with and without the deepening step: bottom / acquired range <= the fraction, and so
//     under gate A's 0.675
//   * second echo optimize ON: candidateRes is exactly Math.round((2 x depth + margin) x 2),
//     the rule as it was before P1 - that branch is untouched - and the ratio is under 0.5
//   * the margin still rules the shallows: under 3 m the range is depth + margin as before
//   * the numbers the plan quotes, on the half-metre grid rounded up: 4 m -> 7.0 m wanted,
//     8 m -> 13.5 m, 18 m -> the 30 m cap
//
// Exit code 0 = all checks passed.

const fs = require("fs");
const path = require("path");

const repo = path.resolve(__dirname, "..");

// ---- the planner's rule, out of the QML ------------------------------------------
const qml = fs.readFileSync(path.join(repo, "qml", "PulseDepthEngine.qml"), "utf8");
function lift(name) {
    const m = new RegExp("function\\s+" + name + "\\s*\\(").exec(qml);
    if (!m) throw new Error("could not find function " + name + " in PulseDepthEngine.qml");
    let i = qml.indexOf("{", m.index), depth = 0;
    for (let j = i; j < qml.length; j++) {
        if (qml[j] === "{") depth++;
        else if (qml[j] === "}") { depth--; if (depth === 0) return qml.slice(m.index, j + 1); }
    }
    throw new Error("unbalanced braces in " + name);
}
const plannedRangeRes = new Function(lift("plannedRangeRes") + "\nreturn plannedRangeRes;")();

// ---- the link-fit plan, as the engine calls it --------------------------------------
const perf = fs.readFileSync(path.join(repo, "qml", "PulsePerfEngine.js"), "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const E = new Function(perf + "\nreturn { redPlan };")();

// the runtime values as PulseRuntimeSettings.qml declares them for red/black
const MARGIN_M = 2, RES_MIN = 2, RES_MAX = 50, SAMPLES_MIN = 600, SAMPLES_MAX = 1020, SAMPLES_STEP = 20;
const GATE_A = 0.75 * 0.9;

// the range the scheme asks for (what the DYNAMIC: plan line calls "range wanted"), in metres
function wantedRangeM(depth, fraction, doubleEcho) {
    return 0.5 * plannedRangeRes(depth, MARGIN_M, fraction, doubleEcho);
}

// the range the trace is then acquired at - redPlan rounds the spacing up to a whole mm, so
// this is never under the wanted range
function acquiredRangeM(depth, fraction, doubleEcho, deepening) {
    let candidateRes = plannedRangeRes(depth, MARGIN_M, fraction, doubleEcho);
    let rangeMm;
    if (candidateRes <= 50) {
        candidateRes = Math.max(candidateRes, RES_MIN);
        candidateRes = Math.min(candidateRes, RES_MAX);
        if (deepening) candidateRes += 2;              // updateDynamicResolutionWithStep
        rangeMm = 500 * candidateRes;
    } else {
        let samples = candidateRes * 10;                // updateDynamicSamplesAndPeriod
        samples = Math.max(samples, SAMPLES_MIN);
        samples = Math.min(samples, SAMPLES_MAX);
        if (deepening) samples += SAMPLES_STEP;         // updateDynamicPeriodAndSamplesWithStep
        rangeMm = samples * RES_MAX;
    }
    const p = E.redPlan({ rangeMm, baud: 115200, floorMs: 72, periodMaxMs: 154, coarsestMm: RES_MAX,
                          finestMm: RES_MIN, samplesMax: SAMPLES_MAX, floorSamples: 600, soundSpeed: 1480 });
    return p.rangeMm / 1000;
}

let failures = 0;
function check(cond, what) {
    if (cond) { console.log("  ok   " + what); }
    else      { console.log("  FAIL " + what); failures++; }
}

const depths = [];
for (let d = 0.3; d <= 18.0001; d += 0.1) depths.push(Math.round(d * 10) / 10);

console.log("second echo optimize off: the bottom stays under gate A at every offered fraction");
for (const fraction of [0.45, 0.5, 0.55, 0.6, 0.65]) {
    for (const deepening of [false, true]) {
        let worst = 0, worstAt = 0;
        for (const d of depths) {
            const r = d / acquiredRangeM(d, fraction, false, deepening);
            if (r > worst) { worst = r; worstAt = d; }
        }
        check(worst <= fraction + 1e-9 && worst < GATE_A,
              "fraction " + fraction + (deepening ? " after the +1 m step" : "") + ": worst ratio "
              + worst.toFixed(3) + " at " + worstAt + " m (gate A at " + GATE_A.toFixed(3) + ")");
    }
}

console.log("second echo optimize on: the 2 x depth branch is the rule it was");
{
    let same = true, worst = 0;
    for (const d of depths) {
        if (plannedRangeRes(d, MARGIN_M, 0.6, true) !== Math.round((2 * d + MARGIN_M) * 2)) same = false;
        worst = Math.max(worst, d / acquiredRangeM(d, 0.6, true, false));
    }
    check(same, "candidateRes is Math.round((2 x depth + margin) x 2) at every depth");
    check(worst < 0.5, "worst ratio " + worst.toFixed(3) + ", under 0.5");
}

console.log("the shallows and the plan's numbers");
{
    let marginRules = true;
    for (const d of depths) {
        if (d >= 3.0) break;
        if (plannedRangeRes(d, MARGIN_M, 0.6, false) !== Math.round((d + MARGIN_M) * 2)) marginRules = false;
    }
    check(marginRules, "under 3 m the range is depth + margin, as before");
    const r4 = wantedRangeM(4, 0.6, false), r8 = wantedRangeM(8, 0.6, false), r18 = acquiredRangeM(18, 0.6, false, false);
    check(r4 === 7.0,  "4 m -> " + r4.toFixed(1) + " m wanted (was 6.0), acquired " + acquiredRangeM(4, 0.6, false, false).toFixed(1));
    check(r8 === 13.5, "8 m -> " + r8.toFixed(1) + " m wanted (was 10.0), acquired " + acquiredRangeM(8, 0.6, false, false).toFixed(1));
    check(r18 === 30,  "18 m -> " + r18.toFixed(1) + " m acquired, the 600 x 50 mm cap");
    let noFpSlip = true;   // 2.7 / 0.6 x 2 = 9.000000000000002 must not round up to 10
    for (const d of depths) if (Math.abs(d / 0.6 * 2 - Math.round(d / 0.6 * 2)) < 1e-6
                                && plannedRangeRes(d, MARGIN_M, 0.6, false) !== Math.max(Math.round((d + MARGIN_M) * 2), Math.round(d / 0.6 * 2))) noFpSlip = false;
    check(noFpSlip, "an exact half metre is not rounded up by floating-point noise");
    check(plannedRangeRes(5, MARGIN_M, 0, false) === plannedRangeRes(5, MARGIN_M, 0.6, false)
          && plannedRangeRes(5, MARGIN_M, 1.5, false) === plannedRangeRes(5, MARGIN_M, 0.6, false),
          "a fraction outside (0, 1) falls back to 0.6");
}

console.log(failures === 0 ? "all checks passed" : failures + " check(s) FAILED");
process.exit(failures === 0 ? 0 : 1);
