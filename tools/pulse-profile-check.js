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
//   * every view and cone entry carries a unique, stable id and an expertOnly
//     flag, and no id is ever reused between profiles
//   * adding 820 kHz back to blue's view list is a DATA edit: the chooser grows,
//     every view still reports the right mode and frequency, and nothing else
//     has to change
//   * expert-only entries do what they promise: hidden with expert mode off,
//     a stored id that is not offered falls back to the same MODE without the
//     stored preference being rewritten, and the choice returns when expert
//     mode does
//   * the one-shot ecoViewIndex/ecoConeIndex -> id migration lands on the entry
//     the stored position used to mean, and is idempotent
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
function resolve(committedName, expertMode = false) {
  const committedProfile = committedName === "PULSEred" ? profiles.PULSEred : profiles.PULSEblue;
  const ui = committedProfile.ui || {};
  const uiViewsAll = ui.views || [];
  const uiConesAll = ui.cones || [];
  const offered = list => list.filter(e => !e.expertOnly || expertMode);
  const uiViews  = offered(uiViewsAll);
  const uiCones  = offered(uiConesAll);
  const viewAt = i => (i >= 0 && i < uiViews.length ? uiViews[i] : null);
  const clampViewIndex = i => {
    const n = uiViews.length;
    if (n <= 0) return 0;
    return i < 0 ? 0 : i >= n ? n - 1 : i;
  };
  const coneAt = i => (i >= 0 && i < uiCones.length ? uiCones[i] : null);
  // legacy positional readers read the FULL list, so they cannot move with expert mode
  const coneFreq = (i, fb) => (i >= 0 && i < uiConesAll.length ? uiConesAll[i].freq : fb);
  const indexOfId = (list, id) => list.findIndex(e => e.id === id);
  const entryForId = (list, id) => { const i = indexOfId(list, id); return i >= 0 ? list[i] : null; };
  const resolveId = (list, id, allList) => {
    if (list.length <= 0) return "";
    if (indexOfId(list, id) >= 0) return id;
    const hidden = entryForId(allList, id);
    if (hidden && hidden.mode !== undefined) {
      for (const e of list) if (e.mode === hidden.mode) return e.id;
    }
    return list[0].id;
  };
  const resolveViewId = id => resolveId(uiViews, id, uiViewsAll);
  const resolveConeId = id => resolveId(uiCones, id, uiConesAll);
  const res = (ui.tunable && ui.tunable.resolution) || { minMm: 2, maxMm: 50, marginM: 2 };
  return {
    committedProfile, uiViews, uiCones, uiViewsAll, uiConesAll,
    resolveViewId, resolveConeId,
    viewIdAt: i => (i >= 0 && i < uiViews.length ? uiViews[i].id : ""),
    coneIdAt: i => (i >= 0 && i < uiCones.length ? uiCones[i].id : ""),
    viewIndexForId: id => { const i = indexOfId(uiViews, resolveViewId(id)); return i < 0 ? 0 : i; },
    coneIndexForId: id => { const i = indexOfId(uiCones, resolveConeId(id)); return i < 0 ? 0 : i; },
    viewModeForId: id => { const e = entryForId(uiViews, resolveViewId(id)); return e ? e.mode : "down"; },
    coneForId: id => entryForId(uiCones, resolveConeId(id)),
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

// ---- 1b. entry ids: present, well formed, unique, never reused -----------
// An id is what sits in the user's settings file, so these are promises, not tidiness.
console.log("=== entry ids ===");
const allEntries = [];
for (const [name, prof] of Object.entries(profiles)) {
  for (const kind of ["views", "cones"]) {
    (prof.ui[kind] || []).forEach((e, i) => allEntries.push({ where: name + "." + kind + "[" + i + "]", e }));
  }
}
eq("every entry has a non-empty string id",
   allEntries.filter(x => typeof x.e.id !== "string" || x.e.id === "").map(x => x.where), []);
eq("every entry declares expertOnly",
   allEntries.filter(x => typeof x.e.expertOnly !== "boolean").map(x => x.where), []);
const ids = allEntries.map(x => x.e.id);
eq("no id is used twice anywhere", ids.filter((id, i) => ids.indexOf(id) !== i), []);

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
// ---- 4. the migration ----------------------------------------------------
// Transcribed from PulseRuntimeSettings.migrateViewId / migrateConeId, which resolve
// against the profile that OWNS the list (blue for views, red for cones) rather than
// against whatever is committed — nothing is committed when this runs.
console.log("=== ecoViewIndex / ecoConeIndex -> id migration ===");
const migrate = (all, storedId, legacyIndex) => {
  if (storedId !== "") return "";
  if (all.length <= 0) return "";
  const i = legacyIndex < 0 ? 0 : legacyIndex >= all.length ? all.length - 1 : legacyIndex;
  return all[i].id;
};
const blueViews = pulseBlue.ui.views, redCones = pulseRed.ui.cones;
eq("stored view 0 -> first view id", migrate(blueViews, "", 0), blueViews[0].id);
eq("stored view 1 -> second view id", migrate(blueViews, "", 1), blueViews[1].id);
eq("a stale stored view 3 clamps to the last entry", migrate(blueViews, "", 3), blueViews[blueViews.length - 1].id);
eq("stored cones 0,1,2 -> wide, medium, narrow",
   [0, 1, 2].map(i => migrate(redCones, "", i)), ["wide", "medium", "narrow"]);
eq("idempotent: an already-migrated id is left alone", migrate(blueViews, "side460", 0), "");

// ---- 5. the acceptance test ----------------------------------------------
console.log("=== 820 kHz returns as an EXPERT-ONLY data edit ===");
pulseBlue.ui.views = [
  { id: "down460", expertOnly: false, icon: "./icons/ui/pulse_view_down_scan_460.svg", mode: "down", freq: 460 },
  { id: "down820", expertOnly: true,  icon: "./icons/ui/pulse_view_down_scan_820.svg", mode: "down", freq: 820 },
  { id: "side460", expertOnly: false, icon: "./icons/ui/pulse_view_side_scan_460.svg", mode: "side", freq: 460 },
  { id: "side820", expertOnly: true,  icon: "./icons/ui/pulse_view_side_scan_820.svg", mode: "side", freq: 820 }
];
const Bx = resolve("PULSEblue", true);   // expert mode on
eq("expert sees four buttons", Bx.viewIcons.length, 4);
eq("expert modes 0..3", [0, 1, 2, 3].map(i => Bx.viewMode(i)), ["down", "down", "side", "side"]);
eq("expert frequencies 0..3", [0, 1, 2, 3].map(i => Bx.uiViews[i].freq), [460, 820, 460, 820]);
eq("expert index 3 is a real view, not clamped", Bx.clampViewIndex(3), 3);
eq("an expert picking side820 gets side820", Bx.resolveViewId("side820"), "side820");
eq("and it sits at position 3", Bx.viewIndexForId("side820"), 3);

const Bn = resolve("PULSEblue", false);  // the same profile, expert mode off
eq("an ordinary user sees two buttons", Bn.viewIcons.length, 2);
eq("ordinary ids are the 460 pair", [Bn.viewIdAt(0), Bn.viewIdAt(1)], ["down460", "side460"]);
eq("a stored side820 shows side460, SAME MODE", Bn.resolveViewId("side820"), "side460");
eq("a stored down820 shows down460, SAME MODE", Bn.resolveViewId("down820"), "down460");
eq("which is what the picture does", Bn.viewModeForId("side820"), "side");
console.log("        the stored id is never rewritten by resolve*Id(), so turning expert");
console.log("        mode back on restores side820 — only a tap on the chooser writes it.");

console.log("=== a single-view device offers nothing ===");
pulseBlue.ui.views = [{ id: "down460", expertOnly: false, icon: "x", mode: "down", freq: 460 }];
const B1 = resolve("PULSEblue");
eq("no chooser for one view", B1.offersViewChoice, false);
eq("stale index 3 clamps to 0", [B1.clampViewIndex(3), B1.viewMode(3)], [0, "down"]);
eq("an id from a list that no longer exists resolves to the only entry",
   B1.resolveViewId("side820"), "down460");

console.log("=== every cone hidden: the chooser and its readers stay safe ===");
pulseRed.ui.cones = redCones.map(c => ({ ...c, expertOnly: true }));
const R0 = resolve("PULSEred", false);
eq("no cone chooser at all", R0.offersConeChoice, false);
eq("coneForId returns null rather than a wrong cone", R0.coneForId("wide"), null);
eq("legacy transFreq wide/medium/narrow still read the full list",
   [R0.transFreqWide, R0.transFreqMedium, R0.transFreqNarrow], [510, 710, 810]);

console.log(fails === 0 ? "\nALL CHECKS PASSED" : "\n" + fails + " CHECK(S) FAILED");
process.exit(fails === 0 ? 0 : 1);
