#!/usr/bin/env node
//
// pulse-profile-check.js — a standing check on the device profiles.
//
//   node tools/pulse-profile-check.js
//
// There is no Qt toolchain in the sandboxed shell, so this is how the profile
// data gets exercised without a build. It reads qml/PulseRuntimeSettings.qml,
// evaluates the two profile records as the JavaScript they are, transcribes the
// accessors that QML applies to them, and asserts:
//
//   * both profiles carry the same key set, and the same ui.offers key set
//   * every read of the form committedProfile.X / activeProfile.X in the QML
//     resolves to a key that exists on BOTH records
//   * red and blue still resolve to exactly the values they had before the
//     profile rework
//   * adding 820 kHz back to blue's view list is a DATA edit: the chooser grows,
//     every view still reports the right mode and frequency, and nothing else
//     has to change
//
// Exit code 0 = all checks passed.

const fs = require("fs");
const path = require("path");

const repo = path.resolve(__dirname, "..");
const qmlPath = path.join(repo, "qml", "PulseRuntimeSettings.qml");
const src = fs.readFileSync(qmlPath, "utf8");

function literal(name, open, close) {
  const re = new RegExp("property var\\s+" + name + ":\\s*(\\" + open + ")", "m");
  const m = re.exec(src);
  if (!m) throw new Error("could not find property var " + name);
  let i = m.index + m[0].length - 1, depth = 0, inLine = false, inBlock = false, inStr = null;
  for (; i < src.length; i++) {
    const c = src[i], n = src[i + 1];
    if (inLine) { if (c === "\n") inLine = false; continue; }
    if (inBlock) { if (c === "*" && n === "/") { inBlock = false; i++; } continue; }
    if (inStr) { if (c === "\\") i++; else if (c === inStr) inStr = null; continue; }
    if (c === "/" && n === "/") { inLine = true; i++; continue; }
    if (c === "/" && n === "*") { inBlock = true; i++; continue; }
    if (c === '"' || c === "'") { inStr = c; continue; }
    if (c === open) depth++;
    else if (c === close) { depth--; if (depth === 0) return src.slice(m.index + m[0].length - 1, i + 1); }
  }
  throw new Error("unterminated literal for " + name);
}

const distProcPulseRed  = eval("(" + literal("distProcPulseRed",  "[", "]") + ")");
const distProcPulseBlue = eval("(" + literal("distProcPulseBlue", "[", "]") + ")");
const pulseRed  = eval("(" + literal("pulseRed",  "{", "}") + ")");
const pulseBlue = eval("(" + literal("pulseBlue", "{", "}") + ")");
const profiles  = { PULSEred: pulseRed, PULSEblue: pulseBlue };

// ---- the accessors, transcribed from PulseRuntimeSettings.qml -------------
function resolve(committedName) {
  const committedProfile = committedName === "PULSEred" ? profiles.PULSEred : profiles.PULSEblue;
  const ui = committedProfile.ui || {};
  const uiViews  = ui.views  || [];
  const uiCones  = ui.cones  || [];
  const viewAt = i => (i >= 0 && i < uiViews.length ? uiViews[i] : null);
  const clampViewIndex = i => {
    const n = uiViews.length;
    if (n <= 0) return 0;
    return i < 0 ? 0 : i >= n ? n - 1 : i;
  };
  const coneAt = i => (i >= 0 && i < uiCones.length ? uiCones[i] : null);
  const coneFreq = (i, fb) => { const e = coneAt(i); return e ? e.freq : fb; };
  const res = (ui.tunable && ui.tunable.resolution) || { minMm: 2, maxMm: 50, marginM: 2 };
  return {
    committedProfile, uiViews, uiCones,
    uiOffers: ui.offers || {}, uiBrand: ui.brand || {},
    offersViewChoice: uiViews.length > 1,
    offersConeChoice: uiCones.length > 1,
    viewIcons: uiViews.map(e => e.icon),
    coneIcons: uiCones.map(e => e.icon),
    clampViewIndex, coneAt,
    viewMode: i => { const e = viewAt(clampViewIndex(i)); return e ? e.mode : "down"; },
    transFreqWide:   coneFreq(0, committedProfile.transFreq),
    transFreqMedium: coneFreq(1, committedProfile.transFreq),
    transFreqNarrow: coneFreq(2, committedProfile.transFreq),
    dyn: [res.minMm, res.maxMm, res.marginM]
  };
}

let fails = 0;
const eq = (label, got, want) => {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (ok) console.log("  ok    " + label + " = " + JSON.stringify(got));
  else { fails++; console.log("  FAIL  " + label + "\n          got  " + JSON.stringify(got) + "\n          want " + JSON.stringify(want)); }
};

// ---- 1. the records agree with each other --------------------------------
console.log("=== record shape ===");
eq("same top-level keys", Object.keys(pulseRed).sort(), Object.keys(pulseBlue).sort());
eq("same ui keys", Object.keys(pulseRed.ui).sort(), Object.keys(pulseBlue.ui).sort());
eq("same offers keys", Object.keys(pulseRed.ui.offers).sort(), Object.keys(pulseBlue.ui.offers).sort());
eq("same brand keys", Object.keys(pulseRed.ui.brand).sort(), Object.keys(pulseBlue.ui.brand).sort());

// ---- 2. every profile read in the QML resolves ---------------------------
const reads = [...new Set([
  ...[...src.matchAll(/committedProfile\.(\w+)/g)].map(m => m[1]),
  ...[...src.matchAll(/activeProfile\.(\w+)/g)].map(m => m[1])
])].sort();
const missing = reads.filter(k => !(k in pulseRed) || !(k in pulseBlue));
eq("every committedProfile./activeProfile. read has a key (" + reads.length + " reads)", missing, []);

// ---- 3. today's answers, unchanged ---------------------------------------
console.log("=== PULSEred committed ===");
const R = resolve("PULSEred");
eq("offers a cone choice", R.offersConeChoice, true);
eq("offers no view choice", R.offersViewChoice, false);
eq("cone frequencies", [0, 1, 2].map(i => R.coneAt(i).freq), [510, 710, 810]);
eq("legacy transFreq wide/medium/narrow", [R.transFreqWide, R.transFreqMedium, R.transFreqNarrow], [510, 710, 810]);
eq("dynamic resolution min/max/margin", R.dyn, [2, 50, 2]);
eq("offers map", R.uiOffers, { doubleEchoOptimize: true, screenSpeed2D: true, scanWidthMeters: false,
  nmeaMtw: true, sideScanMounting: false, depthFilter: true, depthFilterBottomTrack: false });
eq("second wordmark shown", R.uiBrand.logoBlack !== "", true);

console.log("=== PULSEblue committed ===");
const B = resolve("PULSEblue");
eq("offers no cone choice", B.offersConeChoice, false);
eq("offers a view choice", B.offersViewChoice, true);
eq("view modes 0,1", [B.viewMode(0), B.viewMode(1)], ["down", "side"]);
eq("legacy transFreq all fall back to transFreq", [B.transFreqWide, B.transFreqMedium, B.transFreqNarrow],
   [pulseBlue.transFreq, pulseBlue.transFreq, pulseBlue.transFreq]);
eq("dynamic resolution min/max/margin", B.dyn, [2, 50, 2]);
eq("offers map", B.uiOffers, { doubleEchoOptimize: false, screenSpeed2D: false, scanWidthMeters: true,
  nmeaMtw: false, sideScanMounting: true, depthFilter: false, depthFilterBottomTrack: true });
eq("second wordmark hidden", B.uiBrand.logoBlack !== "", false);
eq("a stale ecoViewIndex of 3 is clamped", [B.clampViewIndex(3), B.viewMode(3)], [1, "side"]);

// ---- 4. the acceptance test ----------------------------------------------
console.log("=== 820 kHz returns as a data edit ===");
pulseBlue.ui.views = [
  { icon: "./icons/ui/pulse_view_down_scan_460.svg", mode: "down", freq: 460 },
  { icon: "./icons/ui/pulse_view_down_scan_820.svg", mode: "down", freq: 820 },
  { icon: "./icons/ui/pulse_view_side_scan_460.svg", mode: "side", freq: 460 },
  { icon: "./icons/ui/pulse_view_side_scan_820.svg", mode: "side", freq: 820 }
];
const B820 = resolve("PULSEblue");
eq("four buttons", B820.viewIcons.length, 4);
eq("modes 0..3", [0, 1, 2, 3].map(i => B820.viewMode(i)), ["down", "down", "side", "side"]);
eq("frequencies 0..3", [0, 1, 2, 3].map(i => B820.uiViews[i].freq), [460, 820, 460, 820]);
eq("index 3 is a real view now, not clamped", B820.clampViewIndex(3), 3);
console.log("        index 1 is DOWN scan at 820 — the code this replaced hard-coded index 1 as side scan.");

console.log("=== a single-view device offers nothing ===");
pulseBlue.ui.views = [{ icon: "x", mode: "down", freq: 460 }];
const B1 = resolve("PULSEblue");
eq("no chooser for one view", B1.offersViewChoice, false);
eq("stale index 3 clamps to 0", [B1.clampViewIndex(3), B1.viewMode(3)], [0, "down"]);

console.log(fails === 0 ? "\nALL CHECKS PASSED" : "\n" + fails + " CHECK(S) FAILED");
process.exit(fails === 0 ? 0 : 1);
