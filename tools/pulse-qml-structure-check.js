#!/usr/bin/env node
//
// PULSE QML STRUCTURE CHECK
//
// WHY THIS EXISTS, WRITTEN THE DAY IT WOULD HAVE EARNED ITS PLACE. On 17 Sept 2026 a
// patch inserted two rows into PulseSettingsList.qml at the wrong offset and produced
//
//     }
//                 },        <- an orphan closing brace, then a comma
//     ...
//     onActivated: list.actionRequested("revealAppLog")
//     ]                     <- the content array closed at column 0, one brace short
//
// and ALL FOUR existing checks passed on it. None of them could have done otherwise:
// the version check reads import statements, the icon check reads icon names, the
// profile check reads profile records, and the binding check resolves property names
// against component declarations. Every one of them scans; none of them BALANCES. A
// file in that state does not load, and the first thing to say so would have been Qt,
// on a device, after a full Android build.
//
// So this asks the one question the other four do not: does every bracket close, in
// order, in a file the app is going to parse as a whole?
//
// IT IS DELIBERATELY NOT A QML PARSER. A real parser would need the type system to say
// anything useful and would be a project rather than a check. Balance is cheap, has no
// false positives once strings and comments are removed honestly, and catches the entire
// class of "the patch went in at the wrong offset" - which is how a machine edits a file
// and therefore how this repository's files get broken.
//
// The lesson it is built on is the fourth check's own: A STATIC CHECK EARNS ITS PLACE BY
// WHAT IT IS SILENT ABOUT. This one says nothing at all about style, naming, structure
// or QML semantics. It speaks only when a file cannot load.

const fs   = require("fs");
const path = require("path");

const ROOT    = path.join(__dirname, "..");
const QML_DIR = path.join(ROOT, "qml");

// Strip comments, string literals AND REGEX LITERALS, keeping newlines so a reported line
// number is the line the author is looking at. Done as a one-pass state machine rather
// than with regexes, because a regex that removes strings will eat a // inside one - and
// the QML in this repo is full of URLs, paths and "//" inside comments.
//
// THE REGEX LITERAL IS NOT OPTIONAL, and it was the first thing this check got wrong.
// main.qml:3831 holds
//
//     /^(?:UDP\([^)]+\)|bus\/usb\/\d+\/\d+)\|\d+\|1$/
//
// whose character class contains a lone ')' and whose escaped parens are not parens at
// all. Read as code that is a file which does not balance, and the check's first run
// reported it as a failure in a file Qt loads every day. Allowlisting the line was the
// wrong repair - the parser did not know something legitimate, so the parser was taught
// it, exactly as the binding check's three false-positive classes were fixed rather than
// excused.
//
// TELLING A REGEX FROM A DIVISION is the one heuristic here, and it is the usual one: a
// '/' opens a regex unless the last significant character was an identifier character, a
// digit, or a closing ')' ']' '}' - the things a value can end with. It can be fooled by
// `if (x) /re/.test(y)`, which this repository does not contain and which would read as a
// division either way. Anything it gets wrong shows up as a FAIL on a file that loads, so
// it cannot pass a broken file silently - it can only ever be noisy, which is the failure
// direction a check is allowed to have.
function strip(src) {
  let out   = "";
  let i     = 0;
  const n   = src.length;

  const BLOCK = 1, LINE = 2, SQUOTE = 3, DQUOTE = 4, TEMPLATE = 5, REGEX = 6;
  let state = 0;
  let last  = "";      // last significant character emitted
  let inClass = false; // inside a regex [...] character class

  const endsAValue = (ch) => /[A-Za-z0-9_$)\]}]/.test(ch);

  while (i < n) {
    const c  = src[i];
    const c2 = src[i + 1];

    if (state === 0) {
      if (c === "/" && c2 === "*")      { state = BLOCK;    i += 2; continue; }
      if (c === "/" && c2 === "/")      { state = LINE;     i += 2; continue; }
      if (c === "/" && !endsAValue(last)) { state = REGEX; inClass = false; i += 1; continue; }
      if (c === "'")                    { state = SQUOTE;   i += 1; continue; }
      if (c === '"')                    { state = DQUOTE;   i += 1; continue; }
      if (c === "`")                    { state = TEMPLATE; i += 1; continue; }
      out += c;
      if (!/\s/.test(c)) last = c;
      i += 1; continue;
    }

    if (state === REGEX) {
      if (c === "\\")                  { i += 2; continue; }
      if (c === "\n")                  { out += "\n"; state = 0; i += 1; continue; }
      if (c === "[")                   { inClass = true;  i += 1; continue; }
      if (c === "]")                   { inClass = false; i += 1; continue; }
      if (c === "/" && !inClass)       { state = 0; last = "/"; i += 1; continue; }
      i += 1; continue;
    }

    if (state === BLOCK) {
      if (c === "*" && c2 === "/") { state = 0; i += 2; continue; }
      if (c === "\n") out += "\n";
      i += 1; continue;
    }
    if (state === LINE) {
      if (c === "\n") { state = 0; out += "\n"; }
      i += 1; continue;
    }
    // inside a string: an escape swallows the next character, whatever it is
    if (c === "\\") { i += 2; continue; }
    if ((state === SQUOTE   && c === "'")  ||
        (state === DQUOTE   && c === '"')  ||
        (state === TEMPLATE && c === "`")) { state = 0; last = "_"; i += 1; continue; }
    if (c === "\n") out += "\n";   // an unterminated string would otherwise eat the file
    i += 1;
  }

  return out;
}

const OPEN  = { "{": "}", "[": "]", "(": ")" };
const CLOSE = { "}": "{", "]": "[", ")": "(" };

function check(file) {
  const src     = fs.readFileSync(file, "utf8");
  const code    = strip(src);
  const stack   = [];
  let   line    = 1;
  const rel     = path.relative(ROOT, file);

  for (let i = 0; i < code.length; i++) {
    const c = code[i];
    if (c === "\n") { line++; continue; }

    if (OPEN[c]) { stack.push({ c, line }); continue; }

    if (CLOSE[c]) {
      if (!stack.length) {
        return `${rel}:${line} closes a '${c}' that was never opened`;
      }
      const top = stack.pop();
      if (top.c !== CLOSE[c]) {
        return `${rel}:${line} closes with '${c}' but the innermost open is ` +
               `'${top.c}' from line ${top.line}`;
      }
    }
  }

  if (stack.length) {
    const top = stack[stack.length - 1];
    return `${rel}: '${top.c}' opened at line ${top.line} is never closed ` +
           `(${stack.length} unclosed in total)`;
  }

  return null;
}

const files = fs
  .readdirSync(QML_DIR)
  .filter((f) => f.endsWith(".qml") || f.endsWith(".js"))
  .map((f) => path.join(QML_DIR, f))
  .sort();

console.log("=== every QML file closes every bracket it opens ===");

let failures = 0;
for (const file of files) {
  const problem = check(file);
  if (problem) {
    console.log(`  FAIL  ${problem}`);
    failures++;
  }
}

console.log(`  ok    ${files.length} files in qml/ balanced`);

if (failures) {
  console.log(
    `\n${failures} PROBLEM${failures === 1 ? "" : "S"} - a file in this state does not ` +
      `load, and the next thing to say so is Qt after a full Android build`
  );
  process.exit(1);
}
console.log("\nALL CHECKS PASSED");
