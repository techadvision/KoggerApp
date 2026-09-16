#!/usr/bin/env node
//
// PULSE QML BINDING CHECK
//
// A property assigned on a component that does not declare it is a LOAD failure, not a
// runtime one: the whole QML tree fails to build, the root object is null, and the app
// exits before it draws a pixel.
//
//     qrc:/main.qml:3029:17: Cannot assign to non-existent property "onAbortOpening"
//     Core::UILoad: QML root object is null
//
// That cost a device build on 16 Sept 2026. Half a commit landed - the pill and its
// blocker - without the five properties and signals they hang on, because the patch that
// was meant to add them raised before it wrote the file. Every check in this folder passed
// on it: the version check proves the QML uses no API newer than its import, the icon
// check proves an icon states its colour, the qrc check proves a file exists. NONE of them
// resolves a name against the type it is assigned to.
//
// So this reads every component in qml/, learns what each one DECLARES, then reads every
// place one is instantiated and asks whether each binding and handler has somewhere to
// land. It only knows about components in this repo - QtQuick types are not its business
// and are skipped by name.
//
// IT ONLY JUDGES COMPONENTS ROOTED IN A PLAIN Item, and that narrowing is what makes it
// sound rather than merely quiet. A component whose root is a QtQuick Controls type -
// SpinBoxCustom, CheckButton, CCheck, CText, CCombo, CSlider - inherits a large surface
// this check cannot see, so `text`, `checked`, `from`, `to`, `value` and `stepSize` are all
// perfectly legitimate on it and would all be reported. Judging those would produce twelve
// hundred lines of noise, and a check that must be ignored is worse than no check at all.
//
// An Item root has almost no inherited surface, so what the file declares IS what it
// offers. That is precisely the Pulse v2 family - the rail, the pills, the panel, the
// groups, the overlays - which is where this bug class lives and where it cost a build.
// A component rooted in ANOTHER of our Item-rooted components inherits its declarations,
// so the chain is followed rather than guessed at.

const fs = require("fs");
const path = require("path");

const ROOT    = path.join(__dirname, "..");
const QML_DIR = path.join(ROOT, "qml");

// Item's own surface, plus the attached properties every child of a Layout or a Component
// carries. Assigning any of these is always legitimate and says nothing about the type.
const BUILTIN_PROPS = new Set([
  "id", "objectName", "visible", "enabled", "opacity", "x", "y", "z", "width", "height",
  "implicitWidth", "implicitHeight", "clip", "focus", "activeFocusOnTab", "rotation",
  "scale", "transformOrigin", "smooth", "antialiasing", "state", "states", "transitions",
  "transform", "children", "data", "resources", "parent", "baselineOffset", "containmentMask",
  "accessible", "layer", "anchors", "Layout", "Component", "Keys", "KeyNavigation",
  "Accessible", "Drag", "DragHandler", "LayoutMirroring", "EnterKey", "SplitView",
  "StackView", "ScrollBar", "ToolTip", "Binding", "Behavior"
]);

// Signals every Item has. on<Prop>Changed is handled separately, from the declarations.
const BUILTIN_SIGNALS = new Set([
  "onCompleted", "onDestruction", "onVisibleChanged", "onEnabledChanged", "onOpacityChanged",
  "onXChanged", "onYChanged", "onZChanged", "onWidthChanged", "onHeightChanged",
  "onParentChanged", "onChildrenChanged", "onFocusChanged", "onActiveFocusChanged",
  "onStateChanged", "onRotationChanged", "onScaleChanged", "onClipChanged",
  "onImplicitWidthChanged", "onImplicitHeightChanged", "onChildrenRectChanged",
  "onBaselineOffsetChanged", "onSmoothChanged", "onAntialiasingChanged",
  "onActiveFocusOnTabChanged", "onPressed", "onReleased", "onClicked"
]);

// Names this check is knowingly silent about, with the reason. Add here rather than
// loosening a rule - an exception that is written down stays visible.
const KNOWN = [];

function listQml(dir) {
  return fs.readdirSync(dir)
           .filter(f => f.endsWith(".qml"))
           .map(f => path.join(dir, f));
}

// Strip line comments and string literals so braces inside them cannot move the depth.
// Block comments are handled by a tiny state machine because QML files here use them.
function neutralise(src) {
  const out = [];
  let inBlock = false;
  for (let line of src.split("\n")) {
    if (inBlock) {
      const end = line.indexOf("*/");
      if (end < 0) { out.push(""); continue; }
      line = line.slice(end + 2);
      inBlock = false;
    }
    let res = "";
    for (let i = 0; i < line.length; i++) {
      const two = line.slice(i, i + 2);
      if (two === "//") break;
      if (two === "/*") { inBlock = true; i++; continue; }
      const c = line[i];
      if (c === '"' || c === "'") {
        const quote = c;
        res += '""';
        i++;
        while (i < line.length && line[i] !== quote) {
          if (line[i] === "\\") i++;
          i++;
        }
        continue;
      }
      res += c;
    }
    if (inBlock) {
      const start = res.length;
      out.push(res.slice(0, start));
    } else {
      out.push(res);
    }
  }
  return out;
}

// The type a component derives from: the first object it opens after its imports.
function rootTypeOf(lines) {
  for (const line of lines) {
    const m = /^([A-Z]\w*)\s*\{\s*$/.exec(line);
    if (m) return m[1];
  }
  return null;
}

// What a component offers to whoever instantiates it.
function declarationsOf(lines) {
  const props   = new Set();
  const signals = new Set();
  for (const line of lines) {
    let m = /^\s*(?:readonly\s+)?property\s+(?:alias|[\w.<>]+)\s+(\w+)\s*[:;]?/.exec(line);
    if (m) { props.add(m[1]); continue; }
    // The parameter list is OPTIONAL in QML - CContact declares five signals without one -
    // so requiring a bracket here reported every handler of them as unlandable.
    m = /^\s*signal\s+(\w+)\s*(?:\(|$)/.exec(line);
    if (m) { signals.add(m[1]); continue; }
  }
  return { props, signals };
}

// Every place `Name {` opens a block, with the assignments made at that block's own level.
function instantiations(lines, componentNames) {
  const found = [];
  for (let i = 0; i < lines.length; i++) {
    const m = /^(\s*)([A-Z]\w*)\s*\{\s*$/.exec(lines[i]);
    if (!m) continue;
    const name = m[2];
    if (!componentNames.has(name)) continue;

    const bodyIndent = m[1].length;
    let depth = 1;
    const assigns = [];
    const local = new Set();   // properties this instantiation declares on itself
    for (let j = i + 1; j < lines.length && depth > 0; j++) {
      const line = lines[j];
      // Only lines at this block's own level are its bindings; anything deeper belongs to
      // a child object and is that type's business, not this one's.
      if (depth === 1) {
        // A PROPERTY DECLARED ON THE INSTANCE is part of that instance's surface, and QML
        // allows it - PulseInfoExpert declares `property int deviceValue` on three
        // controllers and then handles onDeviceValueChanged. Collected BEFORE the binding
        // test below, because a declaration with an initialiser looks like one.
        const d = /^(\s*)(?:readonly\s+)?property\s+(?:alias|[\w.<>]+)\s+(\w+)/.exec(line);
        // NO `continue` HERE. The declaration line may itself open a brace -
        // `property var fallback: ({` is how ExtraInfoPanel writes its fallbacks - and
        // skipping the depth accounting below left the object literal's keys looking
        // like bindings on the component. Record it and fall through.
        if (d && d[1].length > bodyIndent) local.add(d[2]);
        const a = /^(\s*)(\w+)\s*:(?!:)/.exec(line);
        if (a && a[1].length > bodyIndent) assigns.push({ name: a[2], line: j + 1 });
      }
      for (const c of line) {
        if (c === "{") depth++;
        else if (c === "}") depth--;
        if (depth === 0) break;
      }
    }
    found.push({ name, line: i + 1, assigns, local });
  }
  return found;
}

const files = listQml(QML_DIR);
const raw = new Map();                 // component name -> { root, props, signals }
for (const f of files) {
  const lines = neutralise(fs.readFileSync(f, "utf8"));
  const d = declarationsOf(lines);
  raw.set(path.basename(f, ".qml"), { root: rootTypeOf(lines), props: d.props, signals: d.signals });
}

// Only components whose root is Item, or another of ours that resolves to Item. Anything
// else inherits a surface this check cannot see, so it is not judged.
function resolve(name, seen) {
  const e = raw.get(name);
  if (!e || (seen && seen.has(name))) return null;
  if (e.root === "Item") return { props: new Set(e.props), signals: new Set(e.signals) };
  if (!raw.has(e.root)) return null;
  const base = resolve(e.root, new Set([...(seen || []), name]));
  if (!base) return null;
  for (const p of e.props)   base.props.add(p);
  for (const g of e.signals) base.signals.add(g);
  return base;
}

const components = new Map();
for (const name of raw.keys()) {
  const r = resolve(name, null);
  if (r) components.set(name, r);
}

const problems = [];
let checkedSites = 0;
let checkedNames = 0;

for (const f of files) {
  const lines = neutralise(fs.readFileSync(f, "utf8"));
  for (const site of instantiations(lines, components)) {
    const decl = components.get(site.name);
    checkedSites++;
    for (const a of site.assigns) {
      checkedNames++;
      const n = a.name;
      if (BUILTIN_PROPS.has(n)) continue;
      if (decl.props.has(n)) continue;
      if (site.local.has(n)) continue;

      if (/^on[A-Z]/.test(n)) {
        if (BUILTIN_SIGNALS.has(n)) continue;
        const sig = n[2].toLowerCase() + n.slice(3);
        if (decl.signals.has(sig)) continue;
        // on<Property>Changed, from a property this component declares.
        const changed = /^on([A-Z]\w*)Changed$/.exec(n);
        if (changed) {
          const prop = changed[1][0].toLowerCase() + changed[1].slice(1);
          if (decl.props.has(prop) || site.local.has(prop)) continue;
        }
        problems.push({
          file: path.basename(f), line: a.line, site: site.name, name: n,
          why: "no signal and no such property on " + site.name
        });
        continue;
      }

      problems.push({
        file: path.basename(f), line: a.line, site: site.name, name: n,
        why: site.name + " declares no property of that name"
      });
    }
  }
}

for (const k of KNOWN) console.log("  known " + k);
console.log("  ok    " + checkedNames + " bindings checked across " + checkedSites +
            " instantiations of " + components.size + " Item-rooted components" +
            " (" + (raw.size - components.size) + " skipped: not Item-rooted)");

if (problems.length) {
  console.log("");
  for (const p of problems) {
    console.log("  FAIL  " + p.file + ":" + p.line + "  " + p.site + "." + p.name +
                "  -  " + p.why);
  }
  console.log("");
  console.log("A binding with nowhere to land is a LOAD failure: the whole tree fails and");
  console.log("the app exits before it draws. Declare the property or signal, or remove");
  console.log("the assignment.");
  console.log("");
  console.log("CHECKS FAILED");
  process.exit(1);
}

console.log("");
console.log("ALL CHECKS PASSED");
