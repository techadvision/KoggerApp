# Pulse UI — staged strategy

Status: draft for approval, 9 Sept 2026. Repo `techadvision/KoggerApp`, branch point `master @ 38dd8a31` (Pulse v1.38).

---

## What the code analysis found

The worry was that the Pulse UI is hopelessly welded into `Plot2D.qml`. It is not. The block between

```
//Pulse additiona - UI controls and methods   (line 1114)
...
//end of pulse additions                      (line 2506)
```

is ~1400 lines containing **five top-level items** and 29 ids, and it reaches outside itself for only these things:

| Reference | Refs | What it actually is |
|---|---|---|
| `plot.*` | 106 | The `WaterFall` C++ root object — a real backend API, not Plot2D internals |
| `plot.quickChangeMaxRangeValue` | 10 | A plain QML `property real` declared at Plot2D:365 |
| `oldDataIndicator.visible` | 4 | Pulse's own alert rectangle (Plot2D:438) |
| `pauseDataIndicator.visible` | 4 | Pulse's own alert rectangle (Plot2D:506) |
| `oldDataWarningRemovalTimer.start/stop` | 4 | Pulse's own timer (Plot2D:411) |
| `echogramLevelsSlider.startValue/stopValue` | 2 | Upstream Kogger levels slider (Plot2D:2564) |
| `echogramVisible` | 2 | Upstream Kogger checkbox (Plot2D:2851) |
| `position()` | 1 | Plot2D helper |

And in the other direction, only **two** ids inside the block are called from outside it: `quickChangeObjects.applyFiltering()` (Plot2D:231, 341) and `selectorMaxDepth.value` (Plot2D:753, 769, 775, 815 — inside the pinch handler).

That is the whole contract. It is small enough that the extraction is a mechanical, reviewable move rather than a rewrite.

**Why it is this clean:** essentially all state already travels through the two singletons `pulseSettings` and `pulseRuntimeSettings`, plus `settingsBus`. The refactor you did for the demo-mode branch already paid most of this bill.

### Five top-level items to move

| Lines | Item | Note |
|---|---|---|
| 1117–2421 | `GridLayout { id: quickChangeObjects }` | The control cluster: 3× `HorizontalController`, `DepthAndTemperature`, 3 `RowLayout`s, 2 `Connections`, 3 `Timer`s |
| 2422–2439 | `Loader { id: pulseInfoLoader }` | Already swaps `PulseTabbedSettingsExpert/Normal` by `expertMode` — the natural hook for a UI-variant switch |
| 2440–2455 | `Image { id: companyWaterMark }` | TECHADVISION mark |
| 2456–2495 | `Rectangle { id: recordingOnScreen }` | Recording indicator |
| 2496–2505 | `Timer { id: closePulseSettingsTimer }` | |

### Two things found on the way that matter for design

1. **Split screen duplicates the whole control cluster.** `main.qml` instantiates `Plot2D` twice (`waterViewFirst` indx 1, `waterViewSecond` indx 2). Nothing in the Pulse block is gated on `indx`, so with two plots open both panes draw the full control set — and because the controls read the shared `pulseSettings`/`pulseRuntimeSettings` singletons, they are not really per-pane anyway. This has to be decided in the design, not patched afterwards: either one shared control layer above both panes, or per-pane controls with per-pane state.
2. **Upstream is 537 commits ahead of master** (we are 337 ahead of it). That next upstream merge is the expensive one, and `Plot2D.qml` is exactly where it will hurt. Doing the extraction *before* that merge is what makes it cheap — after extraction, upstream's `Plot2D.qml` changes and your UI stop touching the same lines.

---

## Stage 0 — Housekeeping

- [x] `feature/demo-mode` merged into `master` (fast-forward, clean tree, no conflicts).
- [ ] **You push:** `git push origin master` — the sandboxed shell has no GitHub credentials.
- [ ] Create and publish `feature/pulse-ui-separation` off master.
- [ ] Tag the pre-refactor state: `git tag pulse-v1.38-pre-ui-split` — a cheap known-good point to diff renders against.

---

## Stage 1 — Extract `PulseApp.qml` (behaviour-preserving)

The rule for this stage: **zero visual change**. Anything that looks different afterwards is a bug, not an improvement. That is what makes it verifiable.

**The new component.** `PulseApp.qml`, an `Item` that fills its parent, with one required property:

```qml
Item {
    id: pulseApp
    property var plot            // the WaterFall root of the owning Plot2D
    anchors.fill: parent

    // exposed back to Plot2D:
    function applyFiltering(v) { quickChangeObjects.applyFiltering(v) }
    property alias maxDepthValue: selectorMaxDepth.value
    ...
}
```

**Steps, in order — each one compiles and runs:**

1. **Register first.** Add `PulseApp.qml` to `qml/qml.qrc` (next to `Plot2D.qml`, line 104) before writing anything into it. A QML file that is not in the qrc fails at runtime, not at build time, and that wastes an hour.
2. **Move the five items verbatim** into `PulseApp.qml`. No reformatting, no renaming, no "while I'm here" fixes — a clean `git diff` that is pure motion is the entire point.
3. **Fix the six inbound references:**
   - `plot.*` → keep the name `plot` as the property name and nothing in the moved code changes at all. This is why the property is called `plot`.
   - `quickChangeMaxRangeValue` → already `plot.quickChangeMaxRangeValue` at every use site; works unchanged.
   - `oldDataIndicator`, `pauseDataIndicator`, `oldDataWarningRemovalTimer` → **move these into `PulseApp.qml` too.** They are Pulse's own On-Screen Alerts section (Plot2D:374–649); moving them removes three of the six couplings outright and takes the alerts block out of `Plot2D.qml` as well. The four call sites outside stay in `Plot2D` and become `pulseApp.showOldDataWarning()` etc. — a two-function API.
   - `echogramLevelsSlider`, `echogramVisible` → genuinely upstream Kogger UI. Expose them as `plot.setLevels(low, high)` (already exists at Plot2D:32) and a small `plot.echogramVisible` alias. Two lines in `Plot2D.qml`.
   - `position()` → one call; pass through as `plot.position(...)`.
4. **Fix the two outbound references:** `quickChangeObjects.applyFiltering(...)` → `pulseApp.applyFiltering(...)`; `selectorMaxDepth.value` in the pinch handler → `pulseApp.maxDepthValue`. Leave the pinch area itself in `Plot2D.qml` for now, as you suggested.
5. **Instantiate** in `Plot2D.qml` where the block used to be: `PulseApp { plot: plot }`.
6. **Decide split-screen behaviour explicitly** — for this stage, the safe choice is to gate on `indx === 1` so nothing changes from what users see today if that is in fact the current behaviour. Check it on the device before choosing; if both panes really do show controls today, keep that and note it as a Stage 3 design question.

**Verification for this stage** (do not skip — this is where a "pure move" quietly stops being pure):

- Build for Android and run against a recorded `.klf` file, so the input is identical between before and after.
- Screenshot the same file position on `pulse-v1.38-pre-ui-split` and on the branch, at three window sizes (phone portrait, tablet landscape, split screen). Diff the images.
- Walk the control surface once: colour chooser, frequency/channel, max depth, illumination, water-body filter, minimise checkbox, pause + history scroll + magnifier + add-waypoint, recording button, info tabs — normal and expert mode, 2D and side-scan device.
- Check the QML console is free of new binding-loop and undefined-reference warnings; an extracted component surfaces those loudly.

**Estimate:** the move itself is a day. The verification is the other day.

---

## Stage 2 — Give the variant switch somewhere to live

Small stage, done on the same branch once Stage 1 is green.

`pulseInfoLoader` already selects its source by `expertMode`. Add one more axis — a `uiVariant` string on `pulseSettings` — so `PulseApp.qml` and the tabbed settings can both be swapped:

```
PulseApp.qml            → dispatches on pulseSettings.uiVariant
  PulseAppClassic.qml   → today's UI, byte-for-byte
  PulseAppV2.qml        → the new design, built in Stage 4
```

Keep `PulseAppClassic.qml` alive and shipping until the new one wins on the water. A hidden switch in expert settings is enough to flip between them — that is what lets you and Dennis compare on a real boat rather than in a mockup.

---

## Stage 3 — Market scan and design directions (the "something to aim for")

Runs in parallel with Stages 1–2; it needs no code.

**Scan.** Garmin (the SAR benchmark, so the one that matters most), Humminbird, Lowrance, Deeper, plus non-marine references for touch-first instrument UIs. What to capture for each: how settings are summoned and dismissed, what stays permanently on screen, how the echogram is squeezed rather than covered, hit-target sizes, and how they handle a paused/history state.

**Your stated constraints, which most of those devices do not have:**
- Android app across a wide span of screen sizes, not a fixed-size chartplotter bezel.
- Split screen with two plots.
- Windows exists today, iOS must come — so the design cannot lean on Android-only affordances.
- Operated from shore, often one-handed, often in sunlight, sometimes with wet hands or gloves.

**Directions to mock up (three, then pick):**

- **A — Slide-out panel.** Settings enter from the left or right edge and compress the echogram instead of covering it. Closest to what you saw on other sounders; familiar to a Garmin-trained SAR user; deals well with the tabbed-settings problem you are unhappy about, because the tabs become a panel rather than a modal. Weakest on narrow phone screens.
- **B — Auto-hiding overlay.** Controls fade after a few seconds of no touch and return on tap, leaving essentially the whole screen as echogram. Best for small screens and split screen. Risk: a control you cannot see is a control a SAR operator does not trust under pressure — needs a persistent minimal strip.
- **C — Refined current.** Keep your on-screen philosophy, which is genuinely a differentiator (live tuning from shore is the USP), but modernize: consistent spacing scale, one icon family, better contrast against a bright orange echogram, larger touch targets, and the minimise checkbox promoted to a proper collapse affordance.

My reading of your screenshots: the *information* on screen is right and the density is defensible for a tuning-heavy product — what dates it is the visual treatment (mixed pill shapes, +/- steppers doing work a slider would do better, the checkbox metaphor for minimise/info) rather than the layout logic. So C may well be closer to the answer than it looks, possibly C with A's panel replacing the tabbed settings.

**Deliverable of this stage:** a design canvas with the three directions drawn at phone-portrait, tablet-landscape and split-screen widths, so the responsive behaviour is decided at design time rather than discovered at implementation time. Say the word and I will build it.

---

## Stage 4 — Build the chosen variant

Separate branch off the separation work, as `PulseAppV2.qml`. Only starts once Stage 1 is merged and Stage 3 has a picked direction. The point of Stages 1–2 is that this stage can be as adventurous as you like without endangering the shipping UI.

Sub-stages worth keeping distinct: (a) the control surface, (b) the settings panel replacing `PulseTabbedSettingsNormal/Expert`, (c) the `PulseInfo` elements that live inside the tabs, which you flagged for redesign.

---

## Stage 5 — Take the upstream merge

Do this *after* Stage 1 is on master. 537 upstream commits are waiting, and the whole argument for the separation is that this merge stops being a `Plot2D.qml` conflict festival. Merging upstream first would mean paying the old price one more time for no reason.

---

## Recommended order

```
Stage 0  push + branch + tag              you, today
Stage 1  extract PulseApp.qml             ~2 days, zero visual change
Stage 3  market scan + 3 directions       in parallel, no code
Stage 2  uiVariant switch                 small, after Stage 1 is green
Stage 4  build the chosen variant         the fun part
Stage 5  upstream merge                   now cheap
```

The one thing not to reorder: Stage 1 before Stage 5.

---

## Stage 3 progress — design directions (9 Sept 2026)

A design canvas now exists with three directions drawn against the app's real control vocabulary, plus three cases: the 2D readout question, phone portrait, and split screen. Artboards are interactive.

**The three directions**

- **A — Edge rail.** Slim left rail always present; tapping a control slides a panel in that compresses the echogram. Absorbs the tabbed settings. Leaves both the top and the bottom of the picture clear, which is what side scan and 2D each need without two layouts. Costs 76px of width; portrait must become a sheet.
- **B — Quiet screen.** Readout, range scale, link status, pause and record stay; everything else appears on tap and auto-hides unless pinned. Biggest echogram, best on phone and split. Risk: invisible controls are controls a SAR operator does not trust.
- **C — Refined cluster.** Same corner and groups, drawn as one object; sliders instead of +/- steppers; minimise becomes a proper collapse. Lowest risk, maps almost one-to-one onto the extracted `PulseApp.qml`. Still covers a corner, still does not solve the phone, still needs A's panel for the settings.

**Market scan — what the conventions actually are** (from Garmin ECHOMAP UHD2, Humminbird APEX/SOLIX/HELIX, Lowrance HDS PRO manuals, plus Deeper)

- Range scale on the right, image scrolling right to left — universal. Do not deviate.
- **No vendor fixes the depth/temperature position**; it is user-placed overlay data everywhere. Deeper's top-right is the one precedent. So the 2D readout position is genuinely Techadvision's call, not a convention to follow.
- **No documented "keep the bottom clear" convention exists** — but Garmin's `Edge` setting and Humminbird's RTS window confirm bottom-hardness reading is a first-class use case. Treat the keep-clear zone as our own design decision.
- **Split screen: per-pane controls with the active pane outlined** (Lowrance states this explicitly) is the established answer to "which pane am I adjusting". Copied directly into the Split artboard.
- Humminbird's **pin-or-auto-hide data bar** is the most transferable single idea, and is what Direction B is built on.
- Every serious unit keeps a hardware fallback (joystick, cursor pad, power key) — they all assume touch will fail with wet hands. On an app that means large targets and gestures that work with one thumb.
- Not findable: published touch-target sizes, night-mode confirmation, and user criticism (search was blocked).

**Open decision this surfaced.** Split screen cannot hold per-pane settings while `pulseSettings` / `pulseRuntimeSettings` are global singletons. Decide whether panes share settings or get their own *before* Stage 1 fixes the split-screen behaviour, because it changes where the state lives.

---

## Direction chosen — edge rail (11 Sept 2026)

**Decision: Direction A.** Slim always-present rail on the left; tapping a control slides a panel in that compresses the echogram. On a phone the panel becomes a bottom sheet that takes height from the echogram rather than covering it. Directions B and C are kept on a "Not taken" page of the canvas — B's pin-or-auto-hide idea and C's slider-instead-of-stepper change are both worth borrowing.

### Where every setting lives — three tiers, one panel

**Tier 1, the rail** (always on screen, one tap, changes the picture now): Colours · Channel/cone · Max range · Intensity · Water body filter · Pause & inspect · Record. Exactly today's quick set. Settings sits at the foot of the rail.

**Tier 2, the same panel scrolled** (today's Settings tab, minus the tabs — one list of groups that open in place, no drill-in, no back button):

- Screen & echogram — 2D echogram screen speed (1-5), side-/downscan meters, display temperature on screen, sidescan mid lines removal, optimize to include second echo
- Installation — transducer beneath water surface, PULSEblue left-hand side mount, PULSEblue cable facing front, speed of sound in water
- Position source — autopilot / device GPS / NMEA GPS
- NMEA output — enable UDP server, send to IP, UDP port, DBT interval, include MTW
- Connection — Pulse Wi-Fi server UDP port, USB baud rate
- Recording — start/stop and the file list from the Recording tab
- Troubleshooting — restart the echo sounder, force reselection of device, beta key code

**Tier 3, expert**: not a tab and not a screen — the same list continues past a rule once the switch is on. The 17 expert groups are unchanged.

**Rules.** One panel, one width (340-380px), never covering the picture. Device-dependent controls are absent rather than greyed out. Tapping the rail button that opened a panel closes it; only one open at a time. No Apply button anywhere — the one exception is the existing `stopEchogramToConfigure`, which the panel header should announce while it is on.

### Colours

PULSE blue has 6 themes (`themeModelBlue`); a 2D transducer has 20 (`themeModelRed`, in dark/bright pairs). Twenty items cannot be a pop-up over the echogram, so colours open the panel as a swatch grid showing the real ramp rather than an icon. The existing `useFavoriteThemes2D` / `favoriteThemes2DNew` earns its place here: star the three or four you use, and a long press on the rail button cycles only those without opening anything — the one-thumb-from-shore path.

### Channel and frequency — and how the split is switched on

The same rail button asks a different question per device, and the panel should name the real value rather than leaving an icon to imply it:

- **PULSE blue** — a VIEW choice, all of it 460 kHz. `ecoViewIndex` today offers down scan (0) or side scan (1).
- **PULSE red** — a CONE choice: `ecoConeIndex` 0/1/2 maps to `transFreqWide` 510, `transFreqMedium` 710, `transFreqNarrow` 810 kHz.

**Split-screen activation needs no new toggle.** Add a third option to the blue view chooser — "Both, split screen" — and picking either single view again is the deactivation. One control, no new mode to explain. Two sub-options appear only while Both is on: arrangement (stacked / side by side) and whether the panes keep separate ranges.

### Split screen — what is shared

One PULSE blue, two renderings of the same ping stream. One control layer, which is also the fix for `Plot2D` drawing its full cluster twice.

- **Shared:** colour, intensity, water body filter — one picture, one look. Pause and record are global too.
- **Per pane:** range only. 25 m across-track and 12 m down are genuinely different numbers.

The active pane therefore only decides where range applies: the rail names it, the pane carries a border, tapping the other pane switches (Lowrance's convention).

**Open decision, and the one to settle before Stage 1 touches split-screen behaviour:** `pulseSettings` and `pulseRuntimeSettings` are global singletons, so per-pane range needs somewhere to live. The minimal shape is a small per-pane state object owned by `PulseApp.qml`, with everything else still reading the singletons.

---

## Phone portrait — how the settings appear (11 Sept 2026)

The answer is a **second sheet height, not a second screen**.

- **Short (~25% of the screen).** Quick controls, and any single setting you are actively dragging. The echogram keeps most of the screen.
- **Tall (~75%).** Opening Settings raises the same sheet; the group list scrolls inside it, a strip of echogram stays at the top, the expert switch is pinned at the sheet's foot so it never scrolls away, and the dock stays put.
- **The drop-back rule.** The moment you touch a value that changes the picture, the sheet drops to the short height and shows only the row you are holding, with the echogram restored above it; releasing raises it again. A breadcrumb at the top of the short sheet says where you came from.

The rule this encodes: **if changing it changes the picture, you must be able to see the picture while you change it.** That is what keeps live tuning from shore working on a phone, and it is why this stays one sheet at two heights rather than a settings page you navigate into.

**Open question:** split screen in portrait. Two stacked panes on a 390 dp phone leave roughly 380 dp each before the sheet opens at all. Worth deciding whether portrait simply refuses the split and offers landscape instead.

## Forward-looking requirements, and the one change that serves all of them

Four things Olav wants next all reduce to the same piece of architecture.

1. **Expert mode must toggle on and off without a restart.** Today toggling closes the whole expert tab and the expert user has to restart the app. The list-plus-pinned-switch shape fixes this by construction: turning expert off shortens a list instead of closing the screen you are standing on.
2. **Frequency choice for blue will come back.** It existed; 820 kHz did not perform well enough and was removed. It must be re-activatable without uncommenting code.
3. **Per-view settings must hold in single-pane view.** Not the case today. Settings belong to the **view** (side scan / down scan / 2D), not to the pane — a pane only displays a view — so the value is right whether the view is alone or beside another.
4. **Device profiles must scale.** New hardware IDs are coming, plus a new profile for the IP connector, selected by detecting the connected address (`*.144.*`). The IP link removes the wifi range constraint, so that profile can offer far more tuning of resolution, samples and screen-update period, and a real echogram speed changer — none of which is safe on wifi, where it costs maximum wireless range.

### The change

The good news: `pulseRed` and `pulseBlue` in `PulseRuntimeSettings.qml` are **already profile records** — a `property var` of ~35 keys each. What does not scale is how they are read and how the UI decides what to offer.

- **What breaks today:** about forty per-device properties are each written as `userManualSetName === modelPulseRed ? pulseRed.X : pulseBlue.X`. The branch is repeated once per property, so a third device means editing forty ternaries by hand. `activeModel` resolves from two name constants plus the channel count, which has no room for a third answer. And nothing declares what the UI should *offer* — it infers options from `is2DTransducer`, which is why removing 820 kHz meant commenting out a model array in `Plot2D.qml` rather than changing a value.

- **Four steps:**
  1. **Keyed map** — `profiles: { "PULSEred": {…}, "PULSEblue": {…}, "PULSEblue-IP": {…} }`. Adding hardware is adding one entry.
  2. **One lookup** — `activeProfile` resolves once; every per-device property becomes `activeProfile.chartSamples`. Forty ternaries become forty plain reads.
  3. **A `ui` block per profile** — declaring what the interface should offer: frequencies, cones, views, and which of resolution, samples and period are tunable and between what limits.
  4. **A resolver, not a ternary** — detected device name, channel count and connection, including the address so `192.168.144.*` picks the IP variant. Manual override still wins, as today.

- **What that buys:** blue carries `frequencies: [460]` today so the chooser is absent; add 820 when the hardware is good enough and the chooser appears, with no code change and no risk of it appearing where it is wrong. The IP variant becomes a profile whose `ui` block unlocks the extra tuning. New hardware is one entry with no new branch anywhere.

**Sequencing:** do this as its own step between the `PulseApp.qml` extraction (Stage 1) and building the new UI (Stage 4), because the new panels should be built reading a profile rather than branching on `is2DTransducer`.

---

## Revisions from review (11 Sept 2026)

### 2D uses the side-scan controls unchanged

The three-way comparison of readout positions is dropped. The 2D screen gets the same rail, the same panel and the same pill vocabulary. Only one button asks a different question — a **view** on PULSE blue, a **cone** on PULSE red — and the panel names the actual frequency either way (510 wide / 710 medium / 810 narrow).

### Depth and temperature: always on, large, and the corner follows the flow

This is a rule, not a preference:

- **Side scan** flows downward, newest pings at the top → readout at the **lower left**, clear of the newest data.
- **2D / down scan** flows sideways → readout lifts to the **top left**, at the water-surface end, clear of the bottom return and its double echo. The bottom-left corner of a 2D screen is deliberately left empty.

Both are large. Neither is ever hidden — except in paused mode, below.

### Paused and inspect becomes its own mode

Today the history bar is drawn on top of the echogram (vertical for side scan, horizontal for down scan). It moves **out of the picture into a gutter beside it**: a vertical gutter at the left for side scan, a horizontal one along the foot for 2D, matching each flow direction.

While paused, the rail, the readout and the recording pip all step aside — none is needed, and depth is not shown today either. What remains on the picture is the crosshair and the loupe. One button gets out, and it is the largest thing in the gutter.

The loupe is rebuilt: roughly three times the area, both values labelled rather than abbreviated, the zoom factor shown in the header, and two real buttons — a ghost **Dismiss** and a filled **Add waypoint** with a pin.

Most of this lives in `plot2d_aim` and `plot2d_zoom` (h/cpp). Taking the scroll bar out of the picture is what makes the aim and zoom geometry simple: they no longer have to avoid a control drawn on top of the data.

### The mosaic joins the view chooser; the green pill goes

The green pill on the echogram is removed. The mosaic becomes a view like any other, so the PULSE blue chooser has five entries:

1. Down scan
2. Side scan
3. Side + down (split)
4. **Side + mosaic** (split)
5. **Mosaic only**

Arrangement (stacked / side by side) and separate-range-per-view appear as sub-options whenever a split is selected. This replaces today's screen-swap with something more flexible than upstream's movable split, and it needs no new toggle anywhere.

### Phone portrait: general settings take the whole screen

Confirmed. There is no honest way to keep a strip of echogram and still show a list, so the general settings are a full page — close button, the same group list, expert switch pinned at the foot.

What does **not** become a page is anything that changes the picture. Touch a value that affects the render and you get the short sheet with the echogram above it. That is the line: **a page for what you set, a sheet for what you tune.**

---

## Round 2 additions (11 Sept 2026)

### The status chip was invented — correction

The "1.24 km · 84%" chip drawn in the first round has **no basis in the code**. There is no RSSI, link-quality, battery or distance property anywhere in the QML. The chip now shows only what the app genuinely knows: the active device and whether data is arriving live, which is the state `oldDataIndicator` and `pauseDataIndicator` already track.

Real telemetry would need a source per value first — link quality and RSSI from the IP gateway, battery from the boat over the autopilot link, distance from the Seascape position already arriving at 5 Hz measured against the launch point. All plausible, none present. Worth deciding which are worth the plumbing before designing a chip around them.

### Overlay placement, completed

For side scan the **recording indicator moves to the bottom** as well, for the same reason as the readout: side scan flows downward, so the newest pings are at the top and every overlay belongs at the foot. On 2D the reverse holds and overlays sit at the top.

### Editing a setting — seven row types

One row is one setting: label left, control right, 64px tall (stacked into label / bound / control in the 380px panel).

| Type | Real examples | Control |
|---|---|---|
| Switch | Echogram enabled · Use TVG for mosaic · Use bottom track depth | 56×32 switch |
| Stepper | TVG gain · Absorption · Noise floor subtraction · Bottom track window | − value + with the allowed range under the label |
| Choice | Frequency 510/710/810 · Chart resolution · Baud rate | segmented when the profile lists ≤4 values, a list in the same panel when more |
| Slider | Intensity · Water body filter · Horizontal smoothing | track + knob + value |
| Text | NMEA send to IP · Beta key code | tap to edit in place, validated |
| Read-only | Firmware version · Serial number · UUID | dim value, no border, no target |
| Action | Restart the echo sounder · Force reselection · Device swap | outlined button; destructive confirms **in the row**, never a dialog |

**Three rules worth arguing for:**

1. **The allowed range is always on screen** — under the label, so a limit is never discovered by hitting it. Today several of these bounds survive only as a magic number in the label (`Dist confidence adjust (14)`, `Transducer pulse adjust (10)`).
2. **Units sit with the value, not the label** — "TVG gain" and "12 dB/m", not "TVG gain (dB/m)". The label says what it is, the value says how much.
3. **Tap the number for a keypad** — stepping is for nudging; typing is for when you already know you want 37. Long-press still runs, as today.

**And one that only becomes possible after the profile work:** every profile carries a default for every value, so a row that no longer matches its default can say so and offer the way back. That matters most in expert tuning, which is exactly where it is easiest to get lost.

### Keeping the upstream UI

Upstream controls are **hidden, not deleted** — they stay in `Plot2D.qml` behind a single visibility flag so the next upstream merge still shows what the Kogger author has built and features can be cherry-picked later. This round already contains one such pick: the side-and-down split screen, which upstream has and the Pulse app does not. The consequence for Stage 1 is that `PulseApp.qml` takes the Pulse UI while the upstream elements stay in place, keeping diffs against upstream readable and making "turn one back on to evaluate it" a one-line change.

### Branding

The TECHADVISION wordmark (`image/logo_techadvision_gray.png`, already in the repo as the echogram watermark) is rotated into the foot of the edge rail at about 42% opacity, below the settings button. Visible, subtle, and nowhere near the controls — and it replaces the watermark currently sitting on the picture itself.

---

## Stage 1 progress — 12 Sept 2026

**Done, committed on `feature/pulse-ui-separation`:**

- Tag `pulse-v1.38-pre-ui-split` marks the known-good state before the move.
- `docs/pulse-ui/` created so these documents live on disk and in git rather than only in the Claude project.
- `qml/PulseApp.qml` created (1720 lines); `qml/Plot2D.qml` 3760 → 2095 lines; `qml/qml.qrc` updated.

**The move was verified as pure motion.** 1672 of the moved lines are byte-identical to the same lines at the tag. The only edits inside the moved code were the two the analysis predicted:

- `pinch2D.` → `pinch.` (2 sites)
- `oldDataResetSeconds` → `plot.oldDataResetSeconds` (5 sites)

**The seam.** Plot2D keeps the Pulse property block and the pinch area, as intended, and now reaches the UI through three members only:

| Plot2D now calls | Was | Sites |
|---|---|---|
| `pulseUi.applyFiltering(v)` | `quickChangeObjects.applyFiltering(v)` | 2 |
| `pulseUi.maxDepthValue` | `selectorMaxDepth.value` | 4 |
| `pulseUi.armOldDataWarning()` | five inline statements in `mousearea` | 1 |

`PulseApp` defaults its `plot` property to `parent` rather than taking a `plot: plot` binding from Plot2D, which would have self-resolved to its own property instead of the WaterFall root.

**Two pre-existing oddities found and deliberately left alone**, because this stage changes nothing but location:

- `pulseSettingsLoader.active` is referenced in `closePulseSettingsTimer` but no such id exists anywhere — it was already dead at the tag (`Plot2D.qml:2501`). The timer therefore does nothing.
- `pinch2D` declares its own `property bool isLiveView`, while the line beside it logs `plot.isLiveView`. Two different values, one of them probably not the one intended.

**Not yet done — this is the part that still needs a device:**

- Build for Android and run against a recorded `.klf` file.
- Screenshot the same file position at the tag and on this branch, at phone portrait, tablet landscape and split screen, and diff the images.
- Walk the control surface once in each mode: normal and expert, 2D and side scan.
- Check the QML console for new binding-loop and undefined-reference warnings — an extracted component surfaces those loudly, and that is the main thing this stage can get wrong.

Nothing here has been compiled. The verification above is static: brace balance, identifier cross-checks and a byte comparison against the tag.

---

## Stage status

**Stage 1 — extract `PulseApp.qml`: COMPLETE and verified on device (12 Sept 2026).**

Built and run on the tablet test device. Verified by loading a `plog` file in demo
mode as a playback, which exercises most of the app; no issues found. Branch
`feature/pulse-ui-separation`, pushed via GitHub Desktop.

Commits: `cd3a11e5` docs · `45f67d7c` the extraction · `64d52bdc` stage notes.

Two pre-existing defects were found during the move and deliberately left alone,
because Stage 1 changed location only. Both are still open:

- `pulseSettingsLoader.active` is referenced in `closePulseSettingsTimer` but no
  such id exists anywhere. Already dead at the tag. That timer does nothing.
- `pinch2D` declares its own `property bool isLiveView` while the line beside it
  logs `plot.isLiveView`. Two different values; one of them is probably not the
  one intended.

### What is next, and the one open decision

Stage 1 was the prerequisite for everything else. Two candidates for the next
stage, and they are genuinely a choice:

**A — Take the upstream merge now.** Upstream was 537 commits ahead when this work
started. The whole argument for doing the extraction first was that it makes this
merge cheap: upstream's `Plot2D.qml` changes and the Pulse UI no longer touch the
same lines. It will never be cheaper than it is right now, and everything built
after it would be built on current upstream instead of needing a second painful
merge later. Against it: it is a large, unglamorous chunk with real risk, and it
produces nothing visible.

**B — Do the device-profile rework.** Self-contained, well understood, and the
thing that unblocks four separate requirements at once (820 kHz returning, the IP
connector variant, new hardware IDs, per-view settings). The new panels should be
written reading a profile rather than branching on `is2DTransducer`, so this wants
to happen before the UI work regardless.

The recommendation is **A, then B**. The merge only gets more expensive, and doing
it while the extraction is fresh means any conflict is still in living memory. But
B is the better choice if visible progress matters more right now than paying the
cheapest possible price for the merge.

After those: the `uiVariant` switch (small), then building the new UI against the
design canvas, then the phone layouts.

---

## Stage 2 progress — the variant switch (12 Sept 2026)

Stage 1 was merged to `master` as a fast-forward (`38dd8a31..9093762b`, four commits,
no conflicts). Stage 2 is on `feature/pulse-ui-variant-switch`.

### What it does

```
PulseApp.qml            dispatcher, 97 lines — dispatches on pulseSettings.uiVariant
  PulseAppClassic.qml   today's UI, unchanged since the Stage 1 extraction
  PulseAppV2.qml        the new design — a placeholder until Stage 4
```

`PulseAppClassic.qml` is the Stage 1 file renamed. Twenty-one lines differ from it,
all of them the header comment and the root `id`; the 1700 lines of UI are untouched.

### The three decisions worth recording

**1. The seam became functions only.** Plot2D held `pulseUi.maxDepthValue` as a
property alias, and wrote to it at four sites in the pinch handler — never read it.
A Loader's item cannot be the target of an alias, so that became `pulseUi.setMaxDepth(v)`,
forwarded by the dispatcher. Plot2D now reaches the UI through three functions and
nothing else:

| Plot2D calls | Sites |
|---|---|
| `pulseUi.applyFiltering(v)` | 2 |
| `pulseUi.setMaxDepth(v)` | 4 |
| `pulseUi.armOldDataWarning()` | 1 |

**2. `sourceComponent`, not `source`.** The Loader picks between two inline
`Component`s rather than a URL string. An inline Component binds `plot` and `pinch`
lexically, so the variant is created with them already set. Going through a URL would
build the object first and set the properties afterwards, and every `plot.*` binding
in the 1700 lines would evaluate once against `null` on the way past — exactly the
startup warning noise Stage 1 said to watch for.

**3. Any unknown variant resolves to classic.** `uiVariant` is persisted, so a string
written by a future build or a half-finished experiment must never be able to start
the app without an interface.

### The switch, and the way back

A checkbox in expert settings → Experimental: **"New UI (PULSE UI v2)"**. It writes the
string directly in `onToggled`, so a third variant needs no new property.

Turning it on removes that switch from the screen, because the settings panel lives
inside the classic UI — and `uiVariant` survives a restart. `PulseAppV2.qml` therefore
carries its own **"Back to the classic UI"** button, and whatever replaces the
placeholder in Stage 4 has to keep carrying one until the new settings panel exists.

### The variant contract

Every `PulseApp*` variant provides:

```qml
property var  plot            // the WaterFall root — passed in, never guessed
property var  pinch           // Plot2D's PinchArea, for its isLiveView flag
property real maxDepthValue   // writable; the max-depth selector's value
function applyFiltering(value)
function armOldDataWarning()
```

The V2 placeholder implements it with two deliberate no-ops: while it is showing, the
water-body filter and the old-data warning are driven by nothing. That is expected,
not a fault.

### Files touched

| File | Change |
|---|---|
| `qml/PulseApp.qml` | replaced by the 97-line dispatcher |
| `qml/PulseAppClassic.qml` | the Stage 1 file, renamed; header + `id` only |
| `qml/PulseAppV2.qml` | new placeholder |
| `qml/Plot2D.qml` | 4 sites: `maxDepthValue =` → `setMaxDepth()` |
| `qml/PulseSettings.qml` | `property string uiVariant: "classic"` |
| `qml/PulseInfoExpert.qml` | the switch row |
| `qml/qml.qrc` | both new files registered |

### Verified statically; not yet built

No Qt toolchain is reachable from the sandboxed shell, so as in Stage 1 the checking
is static: brace/paren/bracket balance on every touched file, the qrc parsed as XML
with every entry confirmed present on disk and no duplicates, both variants checked
against the contract, and a line-by-line diff of the classic against the Stage 1 file.

**Still needs the device:**

- Build and run. Confirm the classic UI is bit-for-bit what it was — the Loader is the
  only thing between it and Plot2D now.
- Watch the QML console at startup for `plot`-is-null warnings. Decision 2 above is what
  should prevent them; this is the check that proves it.
- Flip the switch: classic → v2 shows the placeholder, the button returns, the setting
  survives a restart in both positions.
- Split screen, where two Plot2Ds each build their own dispatcher.

### Still open from Stage 1

Both pre-existing defects are untouched and still open: the dead `pulseSettingsLoader`
reference in `closePulseSettingsTimer`, and `pinch2D`'s own `isLiveView` shadowing
`plot.isLiveView`.
