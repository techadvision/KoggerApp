#!/usr/bin/env node
//
// PULSE ICON CHECK
//
// An SVG that declares neither fill nor stroke draws BLACK, because that is SVG's default.
// On the PULSE UI's near-black surfaces that is not a wrong colour, it is an invisible
// control: the Record button on the rail was there and tappable for a whole device build
// while nothing could be seen to tap (13 Sept 2026).
//
// Nothing else in this repo can catch that. The qrc check proves the file EXISTS, the
// version check proves the QML LOADS - and the icon still comes out black. So this reads
// every icon the Pulse QML actually names and asks one question: does it say what colour
// it draws in?
//
// It deliberately does NOT check WHICH colour. White on the rail, red while recording,
// and the coloured device badges are all correct; only silence is wrong.

const fs = require("fs");
const path = require("path");

const ROOT      = path.join(__dirname, "..");
const QML_DIR   = path.join(ROOT, "qml");
const ICON_ROOT = path.join(ROOT, "resources");

// ONLY THE DARK SURFACES. Black is not wrong everywhere - the settings popup draws on a
// light ground, and several of its icons are deliberately colourless and have always been
// fine there (pulse_open, pulse_reconnect, pulse_return_signal_*, xbox-x and the original
// pulse_recording_inactive). It is wrong on the echogram, the rail, the pills, the
// connection screen and the setup card, which are all near-black by design. Widen this
// list when a new dark surface is built, not before.
const DARK_SURFACES = [
  "PulseRail.qml",
  "PulseRailButton.qml",
  "PulsePillColumn.qml",
  "PulseAppV2.qml",
  "PulseAppClassic.qml",
  "PulseConnectionScreen.qml",
  "PulseSetupOverlay.qml",
];

const iconRef = /"\.\/(icons\/[^"]+\.svg)"/g;

// A colour is "stated" if the file carries any fill= or stroke= that is not "none".
// currentColor counts as NOT stated: it is a CSS idea and a QML Image has nothing to
// resolve it against - which is how the source button's first glyph drew dark.
const NOT_A_COLOUR = ["", "none", "currentcolor", "transparent"];

function statesAColour(svg) {
  // The attribute form: fill="#fff" / stroke="white".
  for (const m of svg.matchAll(/(?:fill|stroke)\s*=\s*"([^"]*)"/g))
    if (!NOT_A_COLOUR.includes(m[1].trim().toLowerCase())) return true;

  // The CSS form, which the Fabric.js exports in this repo use: an inline style=, or a
  // <style> block. Miss this and two thirds of the icon set look colourless when they
  // are not - the first draft of this tool did exactly that.
  for (const m of svg.matchAll(/(?:fill|stroke)\s*:\s*([^;"'}\s]+)/g))
    if (!NOT_A_COLOUR.includes(m[1].trim().toLowerCase())) return true;

  return false;
}

let failures = 0;
const seen = new Map(); // icon path -> Set of qml files naming it

for (const name of fs.readdirSync(QML_DIR).filter((f) => f.endsWith(".qml")).sort()) {
  if (!DARK_SURFACES.includes(name)) continue;
  const src = fs.readFileSync(path.join(QML_DIR, name), "utf8");
  for (const m of src.matchAll(iconRef)) {
    if (!seen.has(m[1])) seen.set(m[1], new Set());
    seen.get(m[1]).add(name);
  }
}

for (const [icon, users] of [...seen.entries()].sort()) {
  const full = path.join(ICON_ROOT, icon);
  if (!fs.existsSync(full)) {
    console.log(`  FAIL  ${icon} is named by ${[...users].join(", ")} but is not on disk`);
    failures++;
    continue;
  }
  if (!statesAColour(fs.readFileSync(full, "utf8"))) {
    console.log(
      `  FAIL  ${icon} states no fill and no stroke - it draws BLACK, and on the ` +
        `Pulse surfaces that is an invisible control (named by ${[...users].join(", ")})`
    );
    failures++;
  }
}

console.log(`  ok    ${seen.size} icons on the Pulse dark surfaces checked for a stated colour`);

if (failures) {
  console.log(`\n${failures} PROBLEM${failures === 1 ? "" : "S"} - a control nobody can see is worse than one that is missing`);
  process.exit(1);
}
console.log("\nALL CHECKS PASSED");
