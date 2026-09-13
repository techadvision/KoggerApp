#!/usr/bin/env node
//
// PULSE QML VERSION CHECK
//
// The sandboxed shell has no Qt, so nothing here compiles anything. This catches ONE
// class of error that brace balance cannot and that costs a whole round trip on the
// device: an API newer than the file's own `import QtQuick x.y`.
//
// The import pins the TYPE version regardless of which Qt the app is built with. A file
// saying `import QtQuick 2.15` gets the 2.15 Rectangle even under Qt 6.8, so a Qt 6.7
// property on it is not a warning - the type fails to load, and every file that
// instantiates it fails with it, all the way up to main.qml. The app does not start.
//
// That is exactly how PulseRail.qml killed the app on 13 Sept 2026 with
// topRightRadius/bottomRightRadius.
//
// To extend: add an entry to NEWER_THAN below. Keep the `why` short - it is what the
// failure message says, and the point is that the next person does not have to look it up.

const fs = require("fs");
const path = require("path");

const QML_DIR = path.join(__dirname, "..", "qml");

// identifier -> { since: minimum QtQuick version that has it, why }
const NEWER_THAN = [
  { re: /\btopLeftRadius\s*:/,     since: [6, 7], why: "Rectangle per-corner radius (Qt 6.7)" },
  { re: /\btopRightRadius\s*:/,    since: [6, 7], why: "Rectangle per-corner radius (Qt 6.7)" },
  { re: /\bbottomLeftRadius\s*:/,  since: [6, 7], why: "Rectangle per-corner radius (Qt 6.7)" },
  { re: /\bbottomRightRadius\s*:/, since: [6, 7], why: "Rectangle per-corner radius (Qt 6.7)" },
  { re: /^\s*TapHandler\s*\{/m,    since: [2, 12], why: "TapHandler (QtQuick 2.12)" },
  { re: /^\s*HoverHandler\s*\{/m,  since: [2, 15], why: "HoverHandler (QtQuick 2.15)" },
];

// KNOWN AND TOLERATED. One entry per finding, with the reason it is not being fixed here.
// An entry is a statement that the file loads on the device TODAY - not that the rule is
// wrong. Empty this list rather than growing it.
const KNOWN = [
  {
    file: "Scene3DToolbar.qml",
    match: "HoverHandler",
    // Upstream's 3D toolbar, instantiated unconditionally in main.qml - and the app starts,
    // so whatever Qt 6.8 does with a 2.15 type under a 2.12 import, it is not refusing it
    // here. The fix is a one-line import bump in a file PULSE does not own, which belongs
    // with the next upstream merge rather than with the Pulse UI work.
  },
];

function isKnown(file, why) {
  return KNOWN.some((k) => k.file === file && why.includes(k.match));
}

function declaredVersion(src) {
  // `import QtQuick 2.15` pins the version. `import QtQuick` with none is Qt 6 style and
  // means "whatever this build has", so nothing here can be too new for it.
  const m = src.match(/^\s*import\s+QtQuick\s+(\d+)\.(\d+)\s*$/m);
  if (m) return [Number(m[1]), Number(m[2])];
  if (/^\s*import\s+QtQuick\s*$/m.test(src)) return null; // unversioned - allow everything
  return null;
}

function lt(a, b) {
  return a[0] < b[0] || (a[0] === b[0] && a[1] < b[1]);
}

function stripCommentsAndStrings(src) {
  let out = "";
  for (let i = 0; i < src.length; ) {
    if (src[i] === '"') {
      i++;
      while (i < src.length && src[i] !== '"') i += src[i] === "\\" ? 2 : 1;
      i++; out += '""'; continue;
    }
    if (src.startsWith("//", i)) { while (i < src.length && src[i] !== "\n") i++; continue; }
    if (src.startsWith("/*", i)) { i = src.indexOf("*/", i) + 2; continue; }
    out += src[i++];
  }
  return out;
}

let failures = 0;
let scanned = 0;

for (const name of fs.readdirSync(QML_DIR).filter((f) => f.endsWith(".qml")).sort()) {
  const full = path.join(QML_DIR, name);
  const raw = fs.readFileSync(full, "utf8");
  const src = stripCommentsAndStrings(raw);
  const ver = declaredVersion(raw);
  scanned++;
  if (!ver) continue; // unversioned import, or no QtQuick import at all

  for (const rule of NEWER_THAN) {
    if (rule.re.test(src) && lt(ver, rule.since)) {
      const line = src.slice(0, src.search(rule.re)).split("\n").length;
      if (isKnown(name, rule.why)) {
        console.log(`  known ${name}:${line} ${rule.why} - see KNOWN in this file`);
        continue;
      }
      console.log(
        `  FAIL  ${name}:${line} uses ${rule.why} but declares ` +
          `import QtQuick ${ver[0]}.${ver[1]} - the type will fail to load`
      );
      failures++;
    }
  }
}

console.log(`  ok    ${scanned} qml files scanned for API newer than their own QtQuick import`);

if (failures) {
  console.log(`\n${failures} PROBLEM${failures === 1 ? "" : "S"} - this is a startup crash, not a warning`);
  process.exit(1);
}
console.log("\nALL CHECKS PASSED");
