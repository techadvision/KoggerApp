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
//   * the connection screen's card list assembles out of the records: every card
//     commits a MODEL and never a profile key, a variant offers none of its own,
//     each card's logo resolves to a wordmark its record already names, every
//     card's artwork is on disk and in images.qrc, and a FOURTH card is a data
//     edit inside one profile record with nothing else to change
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

// The records name the models by property, not by string, so the check has to know
// them before it can eval a record — and reading them here rather than retyping them
// is what keeps this file honest if one is ever renamed.
function stringProp(name) {
  const m = new RegExp("property string\\s+" + name + ":\\s*\"([^\"]*)\"").exec(src);
  if (!m) throw new Error("could not find property string " + name);
  return m[1];
}
const modelPulseRed  = stringProp("modelPulseRed");
const modelPulseBlue = stringProp("modelPulseBlue");

const distProcPulseRed  = eval("(" + literal("distProcPulseRed",  "[", "]") + ")");
const distProcPulseBlue = eval("(" + literal("distProcPulseBlue", "[", "]") + ")");
const pulseRed  = eval("(" + literal("pulseRed",  "{", "}") + ")");
const pulseBlue = eval("(" + literal("pulseBlue", "{", "}") + ")");

// PULSEblue-IP is blue plus a small override set, merged exactly as
// PulseRuntimeSettings.mergedProfile() does it: two levels, arrays replace.
const pulseBlueIpOverrides = eval("(" + literal("pulseBlueIpOverrides", "{", "}") + ")");
const isPlainObject = v => v !== null && typeof v === "object" && !Array.isArray(v);
function mergedProfile(base, overrides) {
  const out = { ...base };
  for (const k of Object.keys(overrides)) {
    const b = base[k], o = overrides[k];
    out[k] = isPlainObject(b) && isPlainObject(o) ? { ...b, ...o } : o;
  }
  return out;
}
const pulseBlueIp = mergedProfile(pulseBlue, pulseBlueIpOverrides);
const profiles  = { PULSEred: pulseRed, PULSEblue: pulseBlue, "PULSEblue-IP": pulseBlueIp };

// ---- the resolver, transcribed from PulseRuntimeSettings.qml -------------
const MODEL_RED = "PULSEred", MODEL_BLUE = "PULSEblue", MODEL_BLUE_IP = "PULSEblue-IP";
const PROTO = "Basic2D";
const IP_PREFIX = "192.168.144.";
const isIpVariantAddress = a => typeof a === "string" && a.indexOf(IP_PREFIX) === 0;
const blueKeyFor = a => (isIpVariantAddress(a) ? MODEL_BLUE_IP : MODEL_BLUE);
function resolveProfileKey(model, address, channels) {
  if (model === MODEL_RED) return MODEL_RED;
  if (model === MODEL_BLUE) return blueKeyFor(address);
  if (model !== "" && model !== "..." && model !== PROTO) {
    if (channels === 1) return MODEL_RED;
    if (channels >= 2) return blueKeyFor(address);
  }
  return blueKeyFor(address);
}

// ---- the accessors, transcribed from PulseRuntimeSettings.qml -------------
function resolve(committedKey, expertMode = false) {
  const committedProfile = profiles[committedKey] !== undefined ? profiles[committedKey] : profiles.PULSEblue;
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

// ---- the card assembly, transcribed from PulseRuntimeSettings.qml -------
// cardsFromProfiles() walks the WHOLE map, because the card list is the question
// asked when nothing is committed; cardForScreen() is the one place the shape the
// screen reads is stated, and where `wordmark` becomes a path out of the record's
// own brand block.
function cardForScreen(card, brand) {
  return {
    id:      card.id,
    name:    card.name,
    tagline: card.tagline,
    art:     card.art,
    logo:    brand && brand[card.wordmark] !== undefined ? brand[card.wordmark] : "",
    badge:   card.badge,
    profile: card.profile
  };
}
function cardsFromProfiles(map) {
  const out = [];
  for (const key of Object.keys(map)) {
    const prof = map[key];
    if (!prof || prof.devName !== key) continue;      // a variant is not a model
    const ui = prof.ui;
    if (!ui || !ui.cards) continue;
    for (const c of ui.cards) out.push(cardForScreen(c, ui.brand));
  }
  return out;
}
// A record offers cards only when its key IS its model. That is the same rule the
// QML applies, and it is what keeps "PULSEblue-IP" out of userManualSetName.
const modelKeys = Object.keys(profiles).filter(k => profiles[k].devName === k);

let fails = 0;
const eq = (label, got, want) => {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (ok) console.log("  ok    " + label + " = " + JSON.stringify(got));
  else { fails++; console.log("  FAIL  " + label + "\n          got  " + JSON.stringify(got) + "\n          want " + JSON.stringify(want)); }
};

// ---- 1. the records agree with each other --------------------------------
console.log("=== record shape ===");
const ref = Object.keys(pulseRed).sort();
for (const [name, prof] of Object.entries(profiles)) {
  eq(name + ": same top-level keys", Object.keys(prof).sort(), ref);
  eq(name + ": same ui keys", Object.keys(prof.ui).sort(), Object.keys(pulseRed.ui).sort());
  eq(name + ": same offers keys", Object.keys(prof.ui.offers).sort(), Object.keys(pulseRed.ui.offers).sort());
  eq(name + ": same brand keys", Object.keys(prof.ui.brand).sort(), Object.keys(pulseRed.ui.brand).sort());
  eq(name + ": same tunable keys", Object.keys(prof.ui.tunable).sort(), Object.keys(pulseRed.ui.tunable).sort());
}

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
// Within one profile an id must be unique — it is what a stored preference names.
for (const [name, prof] of Object.entries(profiles)) {
  const mine = [...(prof.ui.views || []), ...(prof.ui.cones || [])].map(e => e.id);
  eq(name + ": ids unique within the profile", mine.filter((id, i) => mine.indexOf(id) !== i), []);
}
// Across profiles an id MAY repeat — a variant shares its parent's list, which is the
// point of PULSEblue-IP — but it must never describe two different things.
const byId = new Map();
const conflicts = [];
for (const { where, e } of allEntries) {
  const seen = byId.get(e.id);
  const shape = JSON.stringify(e);
  if (seen === undefined) byId.set(e.id, { where, shape });
  else if (seen.shape !== shape) conflicts.push(seen.where + " vs " + where + " (id " + e.id + ")");
}
eq("an id never describes two different entries", conflicts, []);

// ---- 2. every profile read in the QML resolves ---------------------------
const reads = [...new Set([
  ...[...src.matchAll(/committedProfile\.(\w+)/g)].map(m => m[1]),
  ...[...src.matchAll(/activeProfile\.(\w+)/g)].map(m => m[1])
])].sort();
const missing = reads.filter(k => Object.values(profiles).some(p => !(k in p)));
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
// ---- 3b. the resolver ----------------------------------------------------
console.log("=== the resolver: model + address + channels -> profile key ===");
const WIFI = "192.168.10.1", IPGW = "192.168.144.1";
// a recognised model decides outright, and only blue looks at the address
eq("red on wifi", resolveProfileKey(MODEL_RED, WIFI, 1), MODEL_RED);
eq("red on the IP gateway is still red", resolveProfileKey(MODEL_RED, IPGW, 1), MODEL_RED);
eq("blue on wifi", resolveProfileKey(MODEL_BLUE, WIFI, 2), MODEL_BLUE);
eq("blue on the IP gateway is the IP variant", resolveProfileKey(MODEL_BLUE, IPGW, 2), MODEL_BLUE_IP);
eq("blue on serial (no address) is plain blue", resolveProfileKey(MODEL_BLUE, "", 2), MODEL_BLUE);
// today's behaviour, preserved exactly: nothing committed falls back to blue
eq("nothing committed -> blue, as before", resolveProfileKey("", "", 0), MODEL_BLUE);
eq("still inside the settle window -> blue, as before", resolveProfileKey("...", "", 1), MODEL_BLUE);
eq("a 1-channel Basic2D is NOT resolved to red behind the settle window",
   resolveProfileKey(PROTO, "", 1), MODEL_BLUE);
// the only new answer: hardware this build has never heard of
eq("unknown device, 1 channel -> red", resolveProfileKey("PULSEgreen", "", 1), MODEL_RED);
eq("unknown device, 2 channels -> blue", resolveProfileKey("PULSEgreen", "", 2), MODEL_BLUE);
eq("unknown device, 2 channels on the IP gateway -> IP variant",
   resolveProfileKey("PULSEgreen", IPGW, 2), MODEL_BLUE_IP);
eq("unknown device, no channels yet -> blue fallback", resolveProfileKey("PULSEgreen", "", 0), MODEL_BLUE);
// the prefix is a prefix, not a substring
eq("a wifi address that merely contains the digits is not the IP gateway",
   resolveProfileKey(MODEL_BLUE, "10.0.192.168.144.1", 2), MODEL_BLUE);
eq("the whole 192.168.144.* subnet counts", resolveProfileKey(MODEL_BLUE, "192.168.144.37", 2), MODEL_BLUE_IP);

console.log("=== PULSEblue-IP is blue on the wire, and only its limits differ ===");
const IP = resolve(MODEL_BLUE_IP);
const wireKeys = Object.keys(pulseBlue).filter(k => k !== "ui");
eq("every non-ui key is byte-identical to blue",
   wireKeys.filter(k => JSON.stringify(pulseBlueIp[k]) !== JSON.stringify(pulseBlue[k])), []);
eq("same views as blue", JSON.stringify(IP.uiViewsAll), JSON.stringify(pulseBlue.ui.views));
eq("same offers as blue", IP.uiOffers, pulseBlue.ui.offers);
eq("same brand as blue", IP.uiBrand, pulseBlue.ui.brand);
eq("live dynamic resolution unchanged for now", IP.dyn, [2, 50, 2]);
eq("samples become tunable", pulseBlueIp.ui.tunable.samples.enabled, true);
eq("period becomes tunable", pulseBlueIp.ui.tunable.period.enabled, true);
eq("and they are NOT tunable on blue",
   [pulseBlue.ui.tunable.samples.enabled, pulseBlue.ui.tunable.period.enabled], [false, false]);

// ---- 3c. the connection screen's cards -----------------------------------
// The list the chooser draws is data in the profile records, assembled across them.
// A card is a promise about hardware the owner bought, so each field is checked, not
// assumed — a card with no artwork or a card that commits a profile key would both
// pass a build and fail on the water.
console.log("=== the connection screen's card list ===");
eq("only the two models offer cards", modelKeys, [modelPulseRed, modelPulseBlue]);

const cardEntries = [];
for (const key of modelKeys)
  (profiles[key].ui.cards || []).forEach((c, i) =>
    cardEntries.push({ where: key + ".cards[" + i + "]", c, brand: profiles[key].ui.brand }));

const badField = f => cardEntries.filter(x => typeof x.c[f] !== "string" || x.c[f] === "").map(x => x.where);
for (const f of ["id", "name", "tagline", "art", "wordmark", "badge", "profile"])
  eq("every card has a non-empty " + f, badField(f), []);
eq("every badge is a hex colour",
   cardEntries.filter(x => !/^#[0-9a-fA-F]{6}$/.test(x.c.badge)).map(x => x.where), []);
// The point of `wordmark`: the path is never repeated, so it has to name a real one.
eq("every wordmark names a wordmark its own record carries",
   cardEntries.filter(x => typeof x.brand[x.c.wordmark] !== "string" || x.brand[x.c.wordmark] === "")
              .map(x => x.where + " -> " + x.c.wordmark), []);
eq("no card repeats a brand path of its own",
   cardEntries.filter(x => /image\//.test(x.c.wordmark)).map(x => x.where), []);
// A CARD COMMITS A MODEL. userManualSetName holds what the hardware IS; a profile key
// is the model plus how it is connected, and writing one there breaks every
// "is this a blue" comparison in the app.
eq("every card commits a model, never a profile key",
   cardEntries.filter(x => !modelKeys.includes(x.c.profile)).map(x => x.where + " -> " + x.c.profile), []);
// Ids are what chosenCardId holds while the screen is up, so two cards cannot share one.
const cardIds = cardEntries.map(x => x.c.id);
eq("card ids unique across every record", cardIds.filter((id, i) => cardIds.indexOf(id) !== i), []);

console.log("=== the assembled list, as the screen reads it ===");
const CARDS = cardsFromProfiles(profiles);
eq("three cards, in record order", CARDS.map(c => c.id), ["red", "black", "blue"]);
eq("the variant offers none of its own — blue is not drawn twice",
   CARDS.filter(c => c.id === "blue").length, 1);
// Two cards on one profile is the whole point of a card list being separate from a
// profile map: red and black are the same hardware and the owner picks what he bought.
eq("red and black are two cards on one profile",
   CARDS.filter(c => c.profile === modelPulseRed).map(c => c.id), ["red", "black"]);
eq("blue is the only card on blue",
   CARDS.filter(c => c.profile === modelPulseBlue).map(c => c.id), ["blue"]);
eq("every card arrives in exactly the shape the screen reads",
   [...new Set(CARDS.map(c => Object.keys(c).join(",")))],
   ["id,name,tagline,art,logo,badge,profile"]);
eq("each logo resolved out of its record's brand, not repeated in the card",
   CARDS.map(c => c.logo),
   [pulseRed.ui.brand.logo, pulseRed.ui.brand.logoBlack, pulseBlue.ui.brand.logo]);

// Artwork is half of what a card IS. A missing file shows an empty plate on the one
// screen that has to work before anything else does.
const assetOk = rel => {
  const f = rel.replace(/^\.\//, "");
  return fs.existsSync(path.join(repo, f)) && qrc.includes("<file>" + f + "</file>");
};
const qrc = fs.readFileSync(path.join(repo, "images.qrc"), "utf8");
eq("every card's render is on disk and in images.qrc",
   CARDS.filter(c => !assetOk(c.art)).map(c => c.id + " -> " + c.art), []);
eq("every card's wordmark is on disk and in images.qrc",
   CARDS.filter(c => !assetOk(c.logo)).map(c => c.id + " -> " + c.logo), []);

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

// ---- 6. the card acceptance test -----------------------------------------
// The same promise the 820 kHz test makes about views, made about cards: a FOURTH
// card is one more entry inside one profile record. Nothing below touches the screen,
// the assembly, the resolver or any other record — if this passes, the edit is data.
console.log("=== a fourth card is a data edit inside one profile record ===");
const cardsBefore = JSON.stringify(CARDS);
pulseRed.ui.cards = [
  ...pulseRed.ui.cards,
  { id: "amber", name: "PULSE amber", tagline: "2D echo sounder",
    art: "./image/pulse_device_red.png", wordmark: "logoBlack",
    badge: "#e0a021", profile: modelPulseRed }
];
const CARDS4 = cardsFromProfiles(profiles);
eq("the screen is handed four cards", CARDS4.map(c => c.id), ["red", "black", "amber", "blue"]);
eq("the new card keeps its record's order, ahead of the next record's", CARDS4[2].id, "amber");
eq("its logo resolves the same way as every other", CARDS4[2].logo, pulseRed.ui.brand.logoBlack);
eq("it commits a model", modelKeys.includes(CARDS4[2].profile), true);
eq("it arrives in the same shape", Object.keys(CARDS4[2]).join(","), "id,name,tagline,art,logo,badge,profile");
eq("and the three that were there are untouched",
   JSON.stringify(CARDS4.filter(c => c.id !== "amber")), cardsBefore);
console.log("        the only edit above is one entry in pulseRed.ui.cards — no accessor,");
console.log("        no resolver line and no second record had to change.");

console.log(fails === 0 ? "\nALL CHECKS PASSED" : "\n" + fails + " CHECK(S) FAILED");
process.exit(fails === 0 ? 0 : 1);
