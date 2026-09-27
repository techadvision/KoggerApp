#!/usr/bin/env node
//
// PULSE MANIFEST CHECK
//
// Qt Creator's Android manifest editor appends one
//     <meta-data android:name="android.app.splash_screen_drawable" .../>
// every time it saves the file, and never removes the old one. The history shows it
// exactly: every "Version update" commit since 1.38 added one line (2 -> 5 -> 6 -> 7),
// and upstream's own history had reached 52 before a merge reset it. Seven identical
// entries are harmless - Android keeps the last value of a repeated key - but the file
// grows without bound and hides a real duplicate that DISAGREES among copies that agree.
//
// So this asks two questions of the manifest: is any meta-data name, or any
// uses-permission / uses-feature name, declared twice inside the same parent element?
// And has the editor written a package attribute into <manifest>?
//
// Run it after touching the manifest in Qt Creator's editor, beside the other checks.
// Exit code 1 on a duplicate.

const fs = require("fs");
const path = require("path");

const MANIFEST = path.join(__dirname, "..", "platform", "android", "AndroidManifest.xml");
const text = fs.readFileSync(MANIFEST, "utf8");

// Scope: the element a line lives in. meta-data under <activity> and under <provider>
// may legitimately share a name, so each is counted per enclosing element.
const scopes = [];
let current = "manifest";
const seen = new Map();   // "scope|tag|name" -> [line numbers]

text.split(/\r?\n/).forEach((line, i) => {
    const open = line.match(/<(activity|provider|application|service|receiver)\b[^>]*?android:name="([^"]+)"/);
    if (open && !/\/>\s*$/.test(line)) {
        scopes.push(current);
        current = `${open[1]} ${open[2]}`;
    } else if (/<application\b/.test(line) && !/\/>\s*$/.test(line)) {
        scopes.push(current);
        current = "application";
    }

    const decl = line.match(/<(meta-data|uses-permission|uses-feature|property)\b[^>]*?android:name="([^"]+)"/);
    if (decl) {
        const key = `${current}|${decl[1]}|${decl[2]}`;
        if (!seen.has(key)) seen.set(key, []);
        seen.get(key).push(i + 1);
    }

    if (/<\/(activity|provider|application|service|receiver)>/.test(line))
        current = scopes.pop() || "manifest";
});

let failed = false;

// Qt Creator's manifest editor also writes package="" into the <manifest> element when it
// opens the file. The gradle build refuses a package attribute (the namespace lives in
// build.gradle), so Olav removes it by hand in the source view. Say so before the build does.
const manifestTag = text.match(/<manifest\b[^>]*>/);
if (manifestTag && /\spackage\s*=/.test(manifestTag[0])) {
    console.log('PACKAGE ATTRIBUTE on <manifest>: remove package="..." - Qt Creator\'s editor adds it');
    failed = true;
}

for (const [key, lines] of seen) {
    if (lines.length > 1) {
        const [scope, tag, name] = key.split("|");
        console.log(`DUPLICATE ${tag} "${name}" in ${scope}: lines ${lines.join(", ")}`);
        failed = true;
    }
}

if (failed && [...seen.values()].some(l => l.length > 1)) {
    console.log("\nIf the duplicate is android.app.splash_screen_drawable, Qt Creator's manifest editor wrote it.");
    console.log("Keep one line and delete the rest; the value is the same in every copy.");
}
if (failed)
    process.exit(1);
console.log(`manifest check: ${seen.size} declarations, no duplicates`);
