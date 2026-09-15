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

**Stage 5 — the upstream merge: COMPLETE, builds and runs (12 Sept 2026).**
Branch `merge/upstream-1.0.3`. Upstream's C++ taken, upstream's new QML refused.
Nine fixes after the merge commit before it ran. Full account, including what is
still unverified, in `upstream-merge-survey.md`.

**Stage 2 — the `uiVariant` switch: COMPLETE and verified on device (12 Sept 2026).**
Branch `feature/pulse-ui-variant-switch`. See the Stage 2 section below.

**Stage 1 — extract `PulseApp.qml`: COMPLETE and verified on device (12 Sept 2026).**
Merged to `master` as a fast-forward, `38dd8a31..9093762b`.

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

### Verified on device (12 Sept 2026)

Built and run. Confirmed:

- The classic UI behaves as before through the Loader — demo-mode playback, which
  exercises most of the app, is unchanged.
- The switch works from expert settings, and the v2 placeholder appears.
- **No `plot`-is-null warnings in the application output.** This is the one that
  mattered: it is what Decision 2 above (`sourceComponent` rather than `source`) was
  chosen to prevent, and the reason the 1700 lines of `plot.*` bindings survive being
  moved behind a Loader.

Static checking beforehand, since no Qt toolchain is reachable from the sandboxed
shell: brace/paren/bracket balance on every touched file, the qrc parsed as XML with
every entry confirmed present on disk and no duplicates, both variants checked against
the contract, and a line-by-line diff of the classic against the Stage 1 file.

**Not yet exercised, and cheap to fold into the next run on the water:**

- The placeholder's "Back to the classic UI" button, and that `uiVariant` survives a
  restart in both positions.
- Split screen, where two Plot2Ds each build their own dispatcher.

### Still open from Stage 1

Both pre-existing defects are untouched and still open: the dead `pulseSettingsLoader`
reference in `closePulseSettingsTimer`, and `pinch2D`'s own `isLiveView` shadowing
`plot.isLiveView`.

---

## Stage 5 survey — the upstream merge is not the job we thought (12 Sept 2026)

Before touching anything, the merge was dry-run on a throwaway branch and aborted.
What it found changes the recommendation, so it is recorded here in full.

### The numbers

| | |
|---|---|
| Merge base | `eb46efd6`, upstream **0.14.3**, 15 April 2026 |
| Upstream now | `3a7f5266`, **1.0.3**, 7 September 2026 |
| Divergence | upstream +537 commits, Pulse +343 |
| Files changed | upstream 629, Pulse 328, **71 touched by both** |
| Dry-run result | **50 conflicted paths** — 34 both-modified, 15 modify/delete, 1 both-added |
| Also incoming | 359 new files, 60 renames, 39 deletions |

### What actually happened upstream

**Upstream rewrote the user interface.** Not evolved — rewrote. Where 0.14.3 had a flat
`qml/` directory and a `qml.qrc`, 1.0.3 has **188 QML files** in proper Qt QML modules,
one `CMakeLists.txt` per directory, URI imports (`import app`):

```
qml/kqml_types  qml/controls  qml/menus  qml/settings
qml/devices     qml/scene2d   qml/scene3d  qml/app      (+ qml/legacy_qml)
```

The consequences for us, in order of how much they hurt:

1. **`qml/main.qml` is now five lines.** It imports `app` and instantiates
   `MainWindow` (1689 lines). Ours is **3081 lines** and is where the entire Pulse
   startup lives — device detection, the settings bus wiring, the singletons, the
   profile logic. Our delta against the base is +899/−95. There is no merge between a
   3081-line file and a 5-line file; there is only a port.
2. **`qml/Plot2D.qml` was deleted** and reborn as `qml/scene2d/Plot2D.qml`, 2119 lines.
   Our delta against the base is **+722/−60** — and this is the one place Stage 1 paid
   off exactly as predicted. Before the extraction that number would have been about
   2100. It is now a replay of a readable patch onto a relocated file.
3. **`KoggerApp.pro` and `qml/qml.qrc` are gone.** Our **50 Pulse-only QML files** are
   registered in that qrc. They would need re-homing into the module layout — most
   naturally as our own `qml/pulse/` module, which is arguably where they should have
   been all along.
4. **The C++ survived.** `qmlRegisterType<qPlot2D>("WaterFall", ...)` is still there, so
   `PulseAppClassic.qml` is still talking to the same backend object. The C++ conflicts
   are real but ordinary: `plot2D_aim.cpp` 10 hunks, `qPlot2D.cpp` 7, `plot2D_grid.cpp`
   6, `plot2D.cpp` 4, `mosaic_processor.cpp` 4, `core.cpp` 4, the rest 1–3 each.

### What this means for the plan

The strategy document argued Stage 1 would make this merge cheap because "upstream's
`Plot2D.qml` changes and your UI stop touching the same lines." That was right about
`Plot2D.qml` and wrong about the merge, because nobody knew upstream had rewritten the
UI around it. **This is a port onto a new architecture, not a conflict-resolution
session.** Stage 1 and Stage 2 are not wasted — `PulseAppClassic.qml` and
`PulseAppV2.qml` conflict with nothing and would move across as a module — but the
`main.qml` port is work that no amount of QML tidying on our side would have avoided.

The cost side is now known. **The value side is not:** nobody has yet asked what is
actually in those 537 commits that the Pulse app would want. That question should be
answered before the merge is either started or abandoned.

**Answered the same day — see `upstream-merge-survey.md`.** The short version: the C++
is the valuable half and it can be taken without the UI, because `qPlot2D` grew from 104
members to 140 and **lost nothing**. Our QML calls 95 of them and upstream dropped none.
The recommendation there is to merge `src/` and keep `qml/`.


---

## Next stage — the device-profile rework (starting point for the next session)

Agreed order was: merge first, then profiles, then build the new UI. The merge is done,
so **this is next**, and it should land before any Stage 4 panel is written — the new
panels must read a profile rather than branch on `is2DTransducer`.

### Why this one

Four separate requirements collapse into a single piece of architecture:

1. Expert mode must toggle without a restart.
2. 820 kHz for blue must be re-activatable without uncommenting code.
3. Per-view settings must hold in single-pane view.
4. New hardware IDs are coming, plus the IP-connector profile selected by `192.168.144.*`.

### What is already right

`pulseRed` and `pulseBlue` in `PulseRuntimeSettings.qml` are **already profile records** —
a `property var` of roughly 35 keys each. The data shape is fine. What does not scale is
how they are read and how the UI decides what to offer.

### What breaks today

- About forty per-device properties are each written as
  `userManualSetName === modelPulseRed ? pulseRed.X : pulseBlue.X`. A third device means
  editing forty ternaries by hand.
- `activeModel` resolves from two name constants plus the channel count. There is no room
  for a third answer.
- Nothing declares what the UI should *offer*. It infers options from `is2DTransducer`,
  which is why removing 820 kHz meant commenting out a model array in `Plot2D.qml`.

### The four steps

1. **Keyed map** — `profiles: { "PULSEred": {…}, "PULSEblue": {…}, "PULSEblue-IP": {…} }`.
   Adding hardware becomes adding one entry.
2. **One lookup** — `activeProfile` resolves once; every per-device property becomes
   `activeProfile.chartSamples`. Forty ternaries become forty plain reads.
3. **A `ui` block per profile** — declaring what the interface should offer: frequencies,
   cones, views, and which of resolution, samples and update period are tunable, between
   what limits. Blue carries `frequencies: [460]` today, so the chooser is absent; add 820
   when the hardware is good enough and the chooser appears, with no code change.
4. **A resolver, not a ternary** — detected device name, channel count and connection,
   including the address, so `192.168.144.*` picks the IP variant. Manual override still
   wins, as it does today.

### What the merge changed about this

Upstream's **settings-migration module** (`1c33fb9c0`, `d3d6a7111`) is now in the tree.
The profile rework is exactly the kind of change that needs stored settings migrated
rather than silently reinterpreted, and `PulseSettings.qml` still says of its own version
field: *"nothing reads settingsVersion today — it is a marker, not a migration trigger."*
Worth settling the `Qt.labs.settings` → `QtCore` move at the same time, since both touch
the same file and the deprecation already warns at startup.

### How to start

1. Merge `merge/upstream-1.0.3` into `master` and push, so the profile work branches off
   a tree that builds and runs.
2. Read `PulseRuntimeSettings.qml` and inventory the forty ternaries before changing any
   of them — the list is the specification.
3. Branch `feature/device-profiles` off master.
4. Do the keyed map and the single `activeProfile` lookup first, with no behaviour change
   and no new UI, and verify on device that red and blue still behave exactly as now.
   Only then add the third profile and the `ui` blocks.

The same rule that made Stage 1 work applies: the mechanical move first, verified, before
anything new is built on it.

---

## The upstream merge landed on master — 12 Sept 2026

`merge/upstream-1.0.3` is on `master` as a **fast-forward**, `d780a94b..b3262306`,
549 commits, clean tree, no conflicts to resolve. Nothing was re-decided; this is
the branch that was already built and run on the tablet. Not pushed — `origin/master`
is 549 behind and Olav pushes via GitHub Desktop.

One operational note for future sessions: the checkout initially half-failed because
the sandboxed shell had no delete permission on the folder, so git could not unlink
the files that only exist on one of the two branches. It left ~230 stray files and a
stale `.git/index.lock`. The fix is to grant delete permission for the repo folder
*before* any branch switch that moves this much of the tree.

---

## Device-profile rework — steps 1 and 2 done, 12 Sept 2026

Branch `feature/device-profiles`, off `master` at `b3262306`. One file touched:
`qml/PulseRuntimeSettings.qml`, +74 −42. No behaviour change, no new UI, no third
profile yet — the mechanical move first, exactly as Stage 1 was done.

### The inventory, which is the specification

There were **36** device-dependent bindings, not forty, and they were not all the
same shape:

| Count | Shape | Keyed on |
|---|---|---|
| 33 | `userManualSetName === modelPulseRed ? pulseRed.X : pulseBlue.X` | `userManualSetName` |
| 1 | `distProcessing` → `distProcPulseRed` / `distProcPulseBlue` | `userManualSetName` |
| 2 | `echogramTvgEnabled`, `sideScanTvgEnabled`, three-way with `false` | `activeModel` |

### The finding that changed the plan: two lookups, not one

The strategy said "one lookup — `activeProfile` resolves once". That would have been a
**behaviour change**. The 34 configuration properties key on `userManualSetName` (the
committed model); the 2 TVG properties key on `activeModel`, which demo mode and an
opened `.klf` deliberately override, because a log carries its own identity and that is
what must drive display gain. The file already said so in the long note above
`activeModel`: *"this covers the DISPLAY path only. Resolution, samples, ranges and dist
processing still come from the committed device profile."*

Collapsing them would put an opened log's gain curve on the connected transducer's
configuration, or the other way round. So there are two resolvers:

```qml
property var profiles: ({ "PULSEred": pulseRed, "PULSEblue": pulseBlue })

property var committedProfile: (userManualSetName === modelPulseRed) ? profiles[modelPulseRed]
                                                                     : profiles[modelPulseBlue]
property var activeProfile:    profiles[activeModel]
```

`committedProfile` reproduces the old fallback exactly: anything that is not `PULSEred`
resolves to blue, including `""` and the `Basic2D` proto names. That is preserved on
purpose and is **not** obviously right — it is a step-3 question once a third profile
exists, and it is written down in the file as such.

`activeProfile` is `undefined` when nothing is identified, which is what keeps the TVG
defaults falling back to `false` rather than guessing. Same three-way as before.

### Other decisions

- **The two profile records are untouched.** `pulseRed` and `pulseBlue` keep every key
  and every value; the map just points at them.
- **`distProcPulseRed` / `distProcPulseBlue` were folded in as a `distProcessing` key**,
  by reference, not by copy. This matters: `PulseInfoExpert.qml` mutates
  `distProcessing[n]` **in place** and then reassigns the property to force a change
  signal, which permanently breaks the binding. That was already true before this change
  and is unchanged by it — same arrays, same aliasing, same broken binding. Worth fixing
  one day; not today.

### Static verification (no Qt toolchain in the sandboxed shell)

- All 36 reads resolve to keys that exist in **both** profile records — checked by
  parsing the records and cross-referencing every `committedProfile.X` / `activeProfile.X`.
- Both records carry the same 37 keys, in the same order.
- Brace and bracket balance unchanged; the one unbalanced `(` is pre-existing, in a comment.
- Nothing outside this file ever referenced `pulseRed`, `pulseBlue`, `distProcPulseRed`
  or `distProcPulseBlue`, so the blast radius really is one file.

### Needs a device build before step 3

Red and blue must behave **exactly** as now: resolution, samples, ranges, frequencies,
datasets, bottom-track processing, and the TVG on both a live transducer and a replayed
log. The one thing to watch in the application output is any `undefined` read — a missing
profile key fails silently in QML rather than loudly.

### Step 3 and 4, still to do

- A `ui` block per profile, declaring what the interface should **offer** (frequencies,
  cones, views, and which of resolution/samples/period are tunable, between what limits).
  This is what replaces inferring options from `is2DTransducer` — **61 reads of it across
  10 QML files**, so it is a real piece of work, not a rename.
- A resolver that takes detected name, channel count and connection address, so
  `192.168.144.*` picks the IP variant. Manual override still wins.
- Then the third profile, `PULSEblue-IP`.
- Also still branching on the model outside this file: `main.qml` (15 refs),
  `PulseAppClassic.qml` (26), `ConnectionViewer.qml` (10), `DeviceItem.qml` (5),
  `Plot2D.qml` (5), `PulseInfoExpert.qml` (4), and four more files with one or two each.
  `HorizontalController.qml:188` branches on `devName` rather than `userManualSetName` —
  a third key source, worth settling when the resolver is written.

---

## Backlog — known, deliberately not being fixed now

Recorded 12 Sept 2026. None of these is part of the UI work; the first is a rendering
defect, the second is the first thing to do **after** the UI is in order.

### 1. The side scan mosaic does not apply the TVG

Observed as fact on the render: the mosaic is bright along the centre of the scan line
and much darker towards the outer part — the signature of an ungained image, since the
TVG is exactly what flattens brightness across range. The echogram path has
`sideScanTvgEnabled` and `sideScanTvgMosaicEnabled` (the latter defaults to `false`,
"mosaic renders TVG buffer instead of AGC"); the mosaic is evidently not taking that
path. Left alone for now.

### 2. Shallow and on-shore depth — the important one after the UI

From Dennis's feedback, two related failures:

- **Depths shallower than 0.5 m cannot be measured at all.**
- **Erratic depth values on some echo sounders when the boat is on the shore** —
  `bottomTrack` cannot determine a depth in that situation.

Two candidate fixes, and they are not exclusive:

- Check whether the upstream author has already fixed this; upstream 1.0.3's bottom-track
  work is now in the tree and unexamined for this.
- Otherwise: **use the rangefinder depth value until it passes 1–2 m, then hand over to
  the `bottomTrack` value** once the rangefinder reports deeper than that. A crossover
  rather than a choice.

### 3. The water-body filter dims the bottom in the mosaic

Overlooked when the filter was built. In the 2D echogram the two were deliberately
separated: `EchogramWaterColumn` (`src/scene2d/echogram_watercolumn.{h,cpp}`, a PULSE
addition) filters **only the water column above the bottom**, with
`echogramWaterBodyBottomMargin` keeping a band above the bottom untouched and an explicit
fail-safe that never dims a bottom it has not detected. The header says it outright:
*"the low-level cut (setEchogramLowLevel) is intentionally left untouched — this is
display-only, above the bottom."*

The mosaic never got that treatment. It goes through
`DataProcessor::setMosaicLevels` → `mosaicColorTable_.setLevels(low, high)` — a flat
colour-table cut applied to the whole image, bottom included. So a high filter value
darkens the entire bottom render, and at the highest setting the bottom disappears
altogether.

The fix is the same shape as the 2D one: the mosaic needs a water-column-aware filter
rather than a global level cut, which means it needs the bottom track available at
mosaic-build time. Related to item 1 — both are the mosaic missing what the echogram
path already has.

### 4. Dynamic resolution steps are visible in the 2D TVG render — CLOSED 12 Sept 2026

`doDynamicResolution` (true for red, false for blue) re-resolves the echogram to suit the
depth — finer sample spacing the shallower it gets, between `dynamicResolutionMin` 2 mm
and `dynamicResolutionMax` 50 mm. It is what produces the stairway under the bottom and
what feeds the auto-depth feature, and its purpose is sound: maximum detail at a stable
data rate, which mattered a great deal on wifi.

But it also moves the TVG render. Passing a resolution step visibly changes colour
strength, because the gain curve is applied per sample and the samples have just changed
what they mean in metres. The TVG needs to be computed against **range in metres**, not
sample index, so a resolution change is invisible in the rendered brightness. Worth
confirming which of the two TVG implementations (2D `imageType 2`, side scan `imageType 3`)
does it which way before designing the fix.

Note the IP link removes the constraint that motivated dynamic resolution in the first
place — that profile can afford far more samples — so the `ui` block work in step 3 and
this item meet each other.

**CLOSED — it was the `imageType == 2` shadowing, and it is fixed.** Confirmed on the
tablet 12 Sept 2026. This was never a defect in PULSE's TVG, because PULSE's TVG was not
running. The two gain laws differ in exactly the way that produces this symptom:

- `EchogramTvg` (PULSE, `imageType` 2) computes `gain(z) = 10^(k·z/20)` where **z is range
  in metres**, stepped by `resolution` per sample. Re-resolving the trace changes how many
  samples cover a metre and changes nothing about the gain at that metre.
- Upstream's TGC (now `imageType` 4) computes `gain = gN + (i/n)·(gF − gN)` — a ramp over
  **sample index over sample count**. Both ends of that fraction move when dynamic
  resolution re-resolves the trace, so the gain at a given depth jumps at every resolution
  step. That is the colour-strength change that was being seen.

The open question this item recorded — *"worth confirming which of the two TVG
implementations does it which way"* — is answered: PULSE's works in metres and was always
right; upstream's works in samples. Nothing further to do here as long as `imageType` 2
stays `EchogramTvg`.

### 5. Re-identify the device and re-run setup when the app is wrong about it

Confirmed on the tablet, 12 Sept 2026, with the profile branch:

- committed **red**, play a **blue** log → the echogram renders as side scan, but the rest
  of the app stays red (transducer cone chooser and so on)
- committed **blue**, play a **red** log → mirror image

This is the documented split working as designed, not a defect introduced by the profile
rework — the display path follows the data, the configuration path follows the committed
device, and `PulseRuntimeSettings.qml` has said so since the demo-mode work: *"Resolution,
samples, ranges and dist processing still come from the committed device profile, so playing
a log that does not match the connected transducer is still something the demonstrator has
to be aware of — until there is a proper way to re-identify the sounder and re-run setup."*

This item is that missing way. Three situations, one mechanism:

1. **The user picks one device and connects another.** Today the wrong choice sticks.
2. **The app is started before the transducer is powered on.** Same outcome by accident
   rather than by mistake, and much more common.
3. **Two devices in the boat, red and blue.** Powering one down and the other up should
   either swap the profile automatically, or at minimum offer a one-tap manual swap.

**Most of the machinery already exists, in two halves that are not connected to each other:**

- `ConnectionViewer.selectCorrectDevice` (with `useDevTypeDetection: true`, the current
  path) already re-commits on a board-enum change:
  `if (model !== "" && userManualSetName !== model) userManualSetName = model`. It maps
  `dev.devType` to a model, with a settle window so a blue unit's second channel does not
  commit it as red first. So **detection already handles the swap.**
- The **re-setup** lives in `DeviceItem.qml` behind `swapDeviceNow`: `resetAllSetupStates()`,
  clear `devDetected` / `devIdentified` / `devConfigured` / `devSettingsEnforced` /
  `appConfigured`, reset `numberOfDatasetChannels`, `forceUpdateResolution = true`. Today
  `swapDeviceNow` is raised only by a **checkbox in expert settings**.

So the gap is one wire: when the resolver commits a model different from the one already
committed, raise `swapDeviceNow` itself instead of waiting for an expert to tick a box. That
is a small, well-bounded change and it belongs in **step 4 of the profile work**, where the
resolver is written — the resolver is the one place that knows a model actually changed.

Two things to settle when it is built:

- **A swap must not be silent.** The app reconfigures a transducer as a consequence; the
  user should see that it happened and be able to refuse it. A toast with an undo is
  probably the right weight — a modal is not.
- **Playback is not a device swap.** Opening a log that disagrees with the connected
  transducer must *not* reconfigure the hardware. The two-lookup split already draws that
  line correctly: `activeProfile` moves for a log, `committedProfile` must not. Any
  auto-swap has to key on the *connection*, never on `activeModel`.

**One inconsistency this exposed, pre-existing and now easy to fix.** In
`Plot2D.onActiveModelChanged` the water-body filter push is gated on
`pulseRuntimeSettings.is2DTransducer`, which comes from `committedProfile`. During a
mismatched playback that gate reads the connected transducer while the picture on screen is
the log's. It was equally wrong before the refactor — but it was one of forty ternaries then,
and it is a named property now.

---

## Device-profile rework — step 3, the `ui` block, 12 Sept 2026

Branch `feature/device-profiles`. Seven QML files plus one new tool. The profile stopped
being only *what the device is* and became *what its interface offers*.

### The inventory, which was the specification

`is2DTransducer` was read **61 times across 10 files**. Reading all of them showed they are
not one thing but three, and only the first belongs in a `ui` block:

| Kind | Example | Verdict |
|---|---|---|
| **What the UI offers** | should the cone chooser exist; should "Include MTW" appear | → `ui` block |
| **How the picture is laid out** | which way the colour bar is drawn, where the loupe sits | stays |
| **What the device is** | dynamic resolution only applies to a 2D transducer | stays |

61 → **46** reads. The 15 that went were every one of the first kind. `is2DTransducer` is
still there and still right — it is a fact about the transducer. It simply stopped being
used as a stand-in for a question it was never asked.

### What the `ui` block declares

```qml
"ui": {
    "cones":   [ { icon, freq, name }, … ],   // red: 510 / 710 / 810.  blue: []
    "views":   [ { icon, mode, freq }, … ],   // blue: down 460, side 460.  red: []
    "offers":  { doubleEchoOptimize, screenSpeed2D, scanWidthMeters,
                 nmeaMtw, sideScanMounting, depthFilter, depthFilterBottomTrack },
    "brand":   { infoImage, logo, logoBlack },
    "tunable": { resolution: {enabled,minMm,maxMm,marginM}, samples: {…}, period: {…} }
}
```

Read through plain properties — `uiViews`, `uiCones`, `uiViewIcons`, `uiConeIcons`,
`offersViewChoice`, `offersConeChoice`, `uiOffers`, `uiBrand` — rather than through
functions, so that every binding's dependency on the profile is visible and a device swap
re-evaluates it. The functions (`coneAt`, `viewAt`, `viewMode`, `clampViewIndex`) are for
handlers and timers, where binding capture does not apply.

**Every key exists on every profile.** A forgotten key reads `undefined` in QML, and a
control that vanishes because someone did not write a line is the worst kind of thing to
discover on the water. `tools/pulse-profile-check.js` enforces it.

### The rule the chooser now follows

**Never offer a choice of one.** `offersViewChoice` is `uiViews.length > 1`,
`offersConeChoice` is `uiCones.length > 1`. That reproduces today exactly — the Red shows
three cones and no view chooser, the Blue two views and no cone chooser — and it means a
future device with a single fixed view simply has no button, with nothing to remember.

### One latent bug found and fixed on the way

Two places decided the grid and the range call from the view *index*:

```qml
if (pulseSettings.ecoViewIndex === 1) { /* side scan */ }
```

That was only true while the list had exactly two entries. In the original four-entry list
index 1 was **down scan at 820**, and both of these would have drawn it as a side scan the
moment 820 came back. They now ask `viewMode(index)`, which reads the entry's own `mode`.
The stored `ecoViewIndex` is also clamped to the current list everywhere it is used, because
a persisted index outlives the list it was chosen from — which is exactly what happened when
820 was withdrawn and left indices 2 and 3 pointing at nothing.

### Other changes worth recording

- **`transFreqWide` / `transFreqMedium` / `transFreqNarrow` now derive from the cone list**
  and were deleted from the profile records, so a frequency is written down in exactly one
  place. A device with no cone list (the Blue) falls back to its own `transFreq` — which is
  what those three held for it anyway: 460, 460, 460.
- **`dynamicResolutionMin` / `Max` / `Margin` come from `ui.tunable.resolution`.** Both
  profiles carry 2 / 50 / 2 today, so nothing changes — but the IP profile can widen them
  without touching code, which is the whole point, since the IP link no longer pays for
  resolution in wireless range.
- **`enableTemperature` reads `useTemperature`**, an existing profile key, instead of
  inferring a temperature sensor from the transducer geometry. Same answer, honest question.
- **`DeviceItem`'s two cone→frequency mappings became one lookup each.** The guard changed
  from "the model is red or Basic2D" to "this device offers cones". For `Basic2D` the old
  code set `transFreq` from `transFreqWide`, which resolved through the blue profile to 460
  — the value `transFreq` already held — so the outcome is identical; the only difference is
  that the binding is no longer broken for nothing.
- **`samples` and `period` in `ui.tunable` are declared but not yet consumed.** There is
  nothing to vary between red and blue. They are the interface the IP profile needs in step
  4, and saying so beats inventing a use for them now.

### `tools/pulse-profile-check.js` — a standing check, and the acceptance test

No Qt toolchain is reachable from the sandboxed shell, so the profile data is exercised
another way: the tool reads `PulseRuntimeSettings.qml`, evaluates the two profile records as
the JavaScript they are, transcribes the accessors QML applies to them, and asserts the lot.

```
node tools/pulse-profile-check.js
```

It checks that both records carry the same keys (and the same `ui.offers` and `ui.brand`
keys), that all 34 `committedProfile.` / `activeProfile.` reads in the QML resolve, and that
red and blue still produce exactly the values they produced before the rework.

Then it runs **the acceptance test for this whole step**: it adds the two 820 kHz entries to
blue's view list and asserts that the chooser grows to four buttons, that every view reports
the right mode and frequency, and that index 3 stops being clamped — all with **no change
anywhere but the profile**. It then cuts the list to one view and asserts the chooser
disappears and a stale index clamps to 0. All checks pass.

So: **820 kHz is now a data edit.** The two entries and the icons to use are written into the
blue profile as a comment, and both icons are already in the repo and registered in
`resources/icons.qrc`.

### Still to verify on device

Nothing here has been compiled. Static checking was: brace/paren/bracket balance unchanged on
all seven files, every `pulseRuntimeSettings.X` reference in the whole `qml/` tree checked
against the declared properties and functions, and the profile harness above. What a build
has to confirm:

1. **Red**: three cone buttons, each setting the frequency it used to; the 2D-only settings
   rows (second echo, screen speed, MTW, depth filter and its margin) still present.
2. **Blue**: two view buttons; down scan draws a horizontal grid, side scan a vertical one;
   the blue-only rows (side-/downscan meters, both PULSEblue mounting checkboxes, depth
   filter w/bottom track) still present.
3. **The info page** shows the right artwork for each device, and the black wordmark appears
   on red only.
4. **The application output** carries no `undefined` reads — a missing profile key fails
   silently in QML, and that is the one thing this step could get wrong.

### Two pre-existing dangling references found by the sweep

Neither is touched — both read a property that does not exist, which in QML is `undefined`
rather than an error:

- `DeviceItem.qml:1722` — `if (pulseRuntimeSettings.dspSmoothFactor_ok)`. There is no such
  property, so that branch has never run.
- `main.qml:136` — `updateBottomTrack: pulseRuntimeSettings.updateBottomTrack` broadcasts
  `undefined` to the settings bus.

---

## Handover — where a cold session picks up (12 Sept 2026)

**Repo state (updated at session close).** Steps 1–3 were built and tested on the tablet
during the session and are now **merged into `master`** as a fast-forward,
`b3262306..3838ab31`. The tree is clean and `node tools/pulse-profile-check.js` passes on
master. `master` is **555 commits ahead of `origin/master` and not pushed** — Olav pushes via
GitHub Desktop, and that is the first thing to do.

| Commit | What |
|---|---|
| `7bd5edf5` | steps 1–2: the keyed profile map and the two resolvers |
| `a7d82b4c` | backlog: mosaic filter, TVG vs dynamic resolution |
| `ecdb784a` | backlog: re-identify the device and re-run setup |
| `de08df71` | step 3: the `ui` block |
| `359a31c3` | this handover |
| `3838ab31` | 820 correction, black-stripes backlog, the imageType 2 clash |

**The first job of the next session is the `imageType == 2` clash**, not step 4 — see the
section above. Upstream's linear TGC is shadowing `EchogramTvg`, so the 2D TVG is rendering
the wrong gain law today. Decided: move upstream's TGC to a free image type (4), restore 2 to
`EchogramTvg`, and compare both renders on the tablet before going further. Everything built
on the 2D gain is standing on this.

### Step 4 — the resolver and the third profile

1. **A resolver, not a ternary.** `committedProfile` is still
   `(userManualSetName === modelPulseRed) ? red : blue`, which is today's fallback preserved
   on purpose. Replace it with a resolver over detected name, channel count and connection —
   including the address, so `192.168.144.*` picks the IP variant. Manual override still
   wins, as it does now. `ConnectionViewer.modelForBoard()` already maps `dev.devType` to a
   model and is the natural home for it.
2. **`PULSEblue-IP` as a third profile entry.** One entry in `profiles`, with a `ui.tunable`
   block that unlocks resolution, samples and update period — none of which was safe on wifi,
   where it cost maximum wireless range, and all of which the IP link affords.
3. **Wire the auto-swap** (backlog item 5). The resolver is the one place that knows a model
   actually changed, so it is where `swapDeviceNow` should be raised — visibly, refusably,
   and keyed on the connection, never on `activeModel`.
4. **Then Stage 4 of the UI work**, building the new panels against a profile rather than
   against `is2DTransducer`.

### Open questions step 4 has to answer

- **Is "anything not PULSEred is blue" the right fallback** once a third profile exists? It
  certainly is not once there are two blues. The resolver is where that gets decided.
- **`HorizontalController.qml:188` branches on `devName`**, not `userManualSetName` — a third
  key source. Settle it when the resolver is written.
- **Settings migration.** Upstream's migration module (`1c33fb9c0`, `d3d6a7111`) is now in the
  tree, and `PulseSettings.qml` still says of its own version field: *"nothing reads
  settingsVersion today — it is a marker, not a migration trigger."* A third profile changes
  what stored indices mean, so this is the moment. Worth settling the
  `Qt.labs.settings` → `QtCore` move at the same time, since both touch the same file and the
  deprecation already warns at startup.

---

## Correction — 820 kHz was expert-gated, not removed (12 Sept 2026)

The step 3 write-up said 820 was withdrawn because the hardware did not perform. Half right.
**One professional report** found the current blue transducer has insufficient power to render
820 properly in deeper water, so 820 was pulled from the **ordinary** chooser — experts can
still activate it, from *"Pulse blue High/Low Frequenzy"* in the experimental expert category
(`PulseInfoExpert.qml:166`), which writes `transFreq` and `useBlueHighFrequency` directly.

That changes what "bringing 820 back" means, and step 3 as built does not cover it.

**The right shape is an `expertOnly` flag on a view entry — and it needs one design decision
first.** `ecoViewIndex` is a *position* in `ui.views`. A list that grows and shrinks with
expert mode makes a stored position mean different things in the two modes: pick side scan as
an expert at index 3, leave expert mode, and index 3 is now out of range or, worse, a
different view. The clamp added in step 3 stops it crashing, not from being wrong.

So: **entries need stable ids, and the preference must store the id rather than the index.**
`ecoViewIndex` / `ecoConeIndex` become `ecoViewId` / `ecoConeId`, with a migration for the
stored integers. That is a step 4 item, and it wants the settings-migration module that came
in with upstream 1.0.3 anyway. Recorded in the blue profile as a comment at the point where
someone would otherwise just add the two entries.

---

## Backlog item 6 — the TVG bypasses the black-stripes fix

**What Olav sees.** Black stripes are missing data — always possible, especially over UDP on
wifi. The black-stripes mechanism evaluates a window forward and back, detects the gap and
computes the most likely render. It is an echogram-render nicety and nothing more, but users
care about it a great deal. On PULSE blue the TVG render bypasses it.

**CONFIRMED ON RED TOO, 12 Sept 2026**, visually, on the build that restored `EchogramTvg`
to `imageType` 2 — which is the first build where red's own TVG has ever actually rendered.
That settles the open question in this item: it is not blue-only, and the table below
already predicted it. Both 2D TVG (2) and side scan TVG (3) render from a cached buffer
that no one invalidates when the black-stripes pass patches the amplitudes. The fix stands
as written: one data version on `Echogram`, bumped on every write to `amplitude`, folded
into all four cache guards.

**It is structural, and it is not only blue.** `BlackStripesProcessor::update()` patches the
epoch's raw amplitudes in place — `amplitude[i] = ethalonVector[i].second`
(`src/black_stripes_processor.cpp:98`). Every image type except raw renders from a **cached
buffer derived from that amplitude vector**, and none of the caches is invalidated when the
amplitude vector is written:

| imageType | buffer | cache guard in `chartTo()` |
|---|---|---|
| 0 | `amplitude` | none needed — reads the patched data, so raw is the only immune path |
| 1 | `compensated` (AGC) | `if (eg.compensated.isEmpty())` — built once, never rebuilt |
| 2 | `tgc` / `tvgCompensated` | `isEmpty()` / a **global gain** version, not a data version |
| 3 | `ssTvgCompensated` | `ssTvgVersion != EchogramSideScanTvg::version()` — same |

`EchogramTvg::version()` and `EchogramSideScanTvg::version()` tag *which gain constants the
buffer was built with*. They say nothing about whether the underlying samples have since
changed. So any epoch whose derived buffer was built before the black-stripes pass patched it
keeps rendering the stripes — and the backward pass, which repairs epochs that have already
been drawn once, is exactly the case that goes stale.

Blue shows it because blue defaults to side scan TVG (imageType 3) and has two subchannels;
red with the 2D TVG on is on the same footing. Red only looks better where the patch happens
to land before the first render.

**The fix is small and general:** give `Echogram` a data version bumped on every write to
`amplitude` — the black-stripes patch and the initial fill — and fold it into all four cache
guards alongside the existing gain version. One counter, four comparisons, and the nicety
works on every image type instead of only on raw.

---

## Found while diagnosing the above — a LIVE defect from the upstream merge

Not a backlog item. `Epoch::chartTo()` in `src/epoch.h` has **two `else if (imageType == 2)`
branches**:

```cpp
} else if (imageType == 2) {          // upstream 1.0.3: their linear TGC
    if (eg.tgc.isEmpty()) eg.updateTgc();
    src = eg.tgc.constData();
}
else if (imageType == 2) {            // PULSE: TVG display compensation  <-- UNREACHABLE
    ... eg.tvgCompensated ...
}
```

The second is dead. Upstream's TGC branch was added at imageType 2, the id PULSE's own TVG
already used, and it shadows it. **So the 2D TVG is currently rendering upstream's linear TGC
— a straight ramp from gain 0.5 to 2.5 across the trace — and `EchogramTvg` is not running at
all.** `resolveEchogramCompensation()` still returns 2 and the toggle still appears to work,
which is why it would not announce itself; the picture is simply produced by the wrong gain
law. The side scan TVG (imageType 3) is unaffected.

This is exactly what the merge notes warned about — *"upstream's side scan renders with TGC
differently"* — landing in the 2D path instead.

**Decide before building on it:** give upstream's TGC its own image type (4 is free) and
restore 2 to `EchogramTvg`, or keep upstream's and retire PULSE's deliberately. The first is
almost certainly right — the PULSE TVG constant is field-tuned (`echogramTvgDbPerMeter` 0.9,
from the Dreamlake harvest) and upstream's ramp is not the same law — but it is a decision
about the picture, so it is Olav's, and it needs a device comparison either way.

---

## Step 4 session — 12 Sept 2026

Branch `feature/device-profiles-step4`, off `master` at `392fd124`. Three commits,
nothing compiled here: there is no Qt toolchain in the sandboxed shell, so every
claim below is static plus `node tools/pulse-profile-check.js`, which passes.

| Commit | What |
|---|---|
| `91bbd63f` | the `imageType == 2` clash, and a way to compare the two gain laws |
| `be448012` | stable entry ids for views and cones |
| `7bf03b69` | the resolver, `PULSEblue-IP`, and the detection-driven device swap |

### 1. The live defect: upstream's TGC was shadowing `EchogramTvg`

Fixed as decided. Upstream 1.0.3's linear TGC moves to **imageType 4**; **2 is
`EchogramTvg` again**. Both laws are kept, because retiring one is a decision about
the picture rather than a merge conflict.

**How to compare on the tablet.** Expert settings → *TVG 2D settings* → **"Compare:
upstream TGC ramp instead of PULSE TVG"**, visible only while the 2D TVG is on. It
flips a live render between the two without touching the TVG on/off state. It is a
runtime property, so every launch starts on PULSE's TVG — the comparison is a
deliberate act, never a state to wake up in. With a log open, the expert
compensation label names which law is rendering: `(tvg 2D)` or `(tgc upstream)`.

Two guards had to follow the new id: the side scan TVG toggle now treats 4 as a 2D
compensation to step aside from, and the 2D toggle resolves through
`echogram2DGainId` rather than a literal 2.

**Expect this while comparing:** `echogramTvgDbPerMeter` does nothing on upstream's
ramp. That law has its own near/far constants (`Core::setTgcGainNear` /
`setTgcGainFar`, defaults 0.5 and 2.5) and no PULSE UI touches them — upstream's QML
was refused at the merge. If the ramp turns out to be worth keeping, those need a
control before it can be tuned at all.

### 2. Stable entry ids — what unblocks an expert-only 820

`ecoViewIndex` / `ecoConeIndex` stored a **position**. Positions only mean anything
while the list they came from is unchanged, and those lists are exactly what has to
be free to change. Every entry now carries a stable `id` and an `expertOnly` flag,
both required on every entry; `ecoViewId` / `ecoConeId` store the id.

- **Migration**: one-shot, in `PulseSettings.Component.onCompleted` beside the
  auto-filter one, for the same reason — `main.cpp` builds `pulseSettings` after
  `pulseRuntimeSettings` and before `main.qml`, so it is the earliest point where the
  profiles are readable and still before any chooser has seeded itself. It resolves
  against the profile that **owns** the list (blue for views, red for cones), not
  against `committedProfile`, because nothing is committed at startup. Idempotent;
  the two integers stay in the file, read-only, as somebody's stored settings.
- **The fallback is never written back.** A stored id that is not currently offered
  resolves to the same **mode** at another frequency where there is one — `side820`
  → `side460` when expert mode goes off — and the stored id is left alone, so turning
  expert mode back on restores the expert's own choice. Only a tap writes.
- `uiViews` / `uiCones` are now the **offered** lists, filtered on `expertMode`;
  `uiViewsAll` / `uiConesAll` are what the device carries. The legacy positional
  `transFreqWide/Medium/Narrow` read the full list so they cannot move with expert
  mode. Because the filter reads `expertMode` as a property, the choosers grow and
  shrink with no restart.

**820 is now purely a data edit**: four entries, two of them `expertOnly`. The exact
lines are written into the blue profile at the point where someone would otherwise
just add them, and the check tool runs that edit as its acceptance test in **both**
expert positions. Whether to make the edit is a hardware question, not a code one,
so it has not been made.

### 3. The resolver

`resolveProfileKey(model, address, channels)` replaces
`(userManualSetName === modelPulseRed) ? red : blue`.

**A profile key is not a model.** The model is what the hardware *is* — what
`userManualSetName` holds and what all 60-odd comparisons outside
`PulseRuntimeSettings` mean. A key is the model **plus how it is connected**.
`PULSEblue-IP` is a key only and is never written into `userManualSetName`, so
everything that asks "is this a blue" still gets yes. `activeProfile` stays keyed on
the model for the mirror reason: a log carries a transducer's identity, not a
connection, so nothing about how the data reached the app may change its gain curve.

**What it deliberately does not do** is second-guess the Basic2D settle window.
Deciding red from "one channel right now" would configure a red transducer during
exactly the window that machinery exists to protect. So the channel count is used
**only** where nothing else has an answer: a device this build does not recognise by
name — which is how the new hardware ids will arrive. Everything already known keeps
the behaviour it had, and the tool asserts each of those cases by name.

**The address** comes from C++: `LinkManagerWrapper::openedIpAddress()`, alongside
the existing PULSE-added invokables, reading the open UDP/TCP link out of the link
model. Not from the `ConnectionViewer` delegate — a `ListView` row only exists while
it is realised, so the answer would have depended on whether the user had the
connection panel open. `""` means unknown and reads as **no opinion**, never as a
negative, so a connection the app cannot see behaves exactly as before.
`ConnectionViewer.refreshConnectionAddress()` publishes it from three places: every
`selectCorrectDevice` pass, `core.onConnectionChanged` (which covers a link the link
manager opens by itself at startup), and the Open/Close button.

**Answering the open question from the last handover:** *is "anything not PULSEred is
blue" still the right fallback?* With three profiles that are two blues and one red,
yes — and it is now said out loud in one function instead of hiding in a ternary.
It stops being right the moment a second **red-like** device exists, and that is the
line the resolver is written to make easy to change.

### 4. `PULSEblue-IP`

Blue plus overrides, merged — not a second copy of 37 keys that would then have to be
kept in step with blue forever. `mergedProfile()` is a two-level merge; arrays replace
outright, because a views or cones list is a list and never a patch.

**Only `ui.tunable` is overridden**, and this is the part to look at:
`samples` and `period` become tunable (they were declared for exactly this profile and
are still unconsumed), and **nothing transmitted to the device changes** —
`chartResolution`, `chartSamples`, `ch1Period` and the live `dynamicResolution*` limits
stay exactly blue's. So committing the IP profile is provably a no-op on the wire and
the first build can prove it. The IP link affords far more than wifi did, where every
extra sample was paid for in maximum wireless range — but what those numbers should
**be** is a measurement on the water, not a guess made in a profile record. That is the
next decision this profile is waiting on.

### 5. The device swap, wired

Detection finding a different transducer no longer re-commits silently. It goes through
`requestDeviceSwap()`, which **asks on screen**: accepting re-runs the whole device
setup, and a reconfiguration cannot honestly be undone, so the choice comes first
rather than an undo afterwards. Declining is remembered for that device, so it asks
once. An expert switch — *Swap device* → **"Swap device automatically, without
asking"** — turns the asking off.

- A **first** commit is not a swap. `"..."` → blue is the app learning what is on the
  wire; that covers "started before the transducer was powered on" and stays silent.
- **Playback is not a swap.** This is called from the detection path only, never from
  `activeModel`.
- Order matters inside `acceptDeviceSwap()`: `swapDeviceNow` runs
  `DeviceItem.onSwapDeviceNowChanged` **synchronously**, which clears every setup state
  and puts `userManualSetName` back to `"..."`. The target is committed **after** that,
  which is what starts the configuration pass; committing first would be undone a line
  later.
- The prompt is drawn in the classic UI's own alert vocabulary and gated on
  `indx === 1`, so a split screen shows one and not two. Stage 4 replaces it along with
  everything else on that layer.

### What a device build has to confirm

1. **The gain law.** 2D TVG on a red: the picture should change the moment the compare
   switch is flipped, and PULSE's should be the one that responds to the TVG gain
   (dB/m) stepper. This is the one that everything else built on the 2D gain is
   standing on.
2. **Red and blue unchanged.** Three cone buttons on red, two view buttons on blue,
   the right grid direction for each view, the right per-device settings rows. The
   resolver is asserted statically but a build is what proves the bindings fire.
3. **The migration.** The startup log prints `SETTINGS: migrating ecoViewIndex n ->
   ecoViewId ...` exactly once, on the first run after this build, and never again.
   The chooser should come up on the view and cone that were selected before.
4. **The swap.** Committed red, power up the blue: the prompt appears once, naming
   both devices; **Keep** dismisses it and it does not come back for that device;
   **Switch** re-runs setup and the app comes up as a blue. Then the same in reverse.
5. **The IP profile.** Only reachable on the 192.168.144 gateway. `PROFILE: committed
   key -> PULSEblue-IP` should appear in the log, and **nothing about the picture or
   the device configuration should change** — that is what makes it safe to widen
   later.
6. **The application output**, as always: no `undefined` reads. A missing profile key
   fails silently in QML, and that is still the one thing this work could get wrong.

### Still open

- **The IP profile's real numbers** — resolution, samples, update period. Deliberately
  left at blue's.
- **Which 2D gain law wins.** If upstream's ramp is kept, it needs a control for its
  near/far constants; if PULSE's is kept, upstream's branch at 4 can go.
- **`HorizontalController.qml:188` branches on `devName`**, not `userManualSetName` —
  the third key source, still unsettled. It did not block the resolver, so it was left
  alone.
- **Settings migration**, the module that came in with upstream 1.0.3. The view/cone
  ids migrate themselves, but `settingsVersion` still says of itself *"nothing reads it
  today — it is a marker, not a migration trigger"*, and the `Qt.labs.settings` →
  `QtCore` move still warns at startup. Both touch the same file.
- Two **pre-existing** defects, both still open from Stage 1: the dead
  `pulseSettingsLoader` reference in `closePulseSettingsTimer`, and `pinch2D`'s own
  `isLiveView` shadowing `plot.isLiveView`.
- **New, found on the way, not fixed**: the four alert indicators in
  `PulseAppClassic.qml` bind `60 + insetTop()` and `_isAndroid ? 80 : 60`, but both are
  declared on `quickChangeObjects` — their **sibling**, not their root — so those
  bindings cannot resolve and never could, from well before the extraction. On Android
  the indicators are drawn 60 high instead of 80 and sit under the inset. Cheap to fix
  by moving the two helpers to the root item; worth doing next time that file is open.

---

## Step 4 — first device build, and what it found (12 Sept 2026)

Branch `feature/device-profiles-step4`. Commit `56f011bf` carries the two fixes below.

### Confirmed on the tablet

- **The 2D TVG is running for the first time since the upstream merge.** This also closed
  backlog item 4 outright — the resolution-dependent colour strength was upstream's ramp
  being a function of sample index, not a defect in PULSE's TVG. See that item above for
  the two gain laws side by side.
- **Black stripes are bypassed on red as well as blue** (backlog item 6), which is the
  first time red's own TVG has rendered at all and so the first time this was observable
  there. The item's open question is closed; the proposed fix is unchanged.

### Not yet verified

- **`PULSEblue-IP`.** Olav cannot reach the IP gateway at the moment. Nothing about the
  profile has been exercised on hardware: not the address publishing, not
  `resolveProfileKey` picking the variant, not the `PROFILE: committed key ->
  PULSEblue-IP` log line. Everything else in step 4 has now been on the device; this has
  not. To check when the gateway is available: the key appears in the log on connecting,
  and **nothing about the picture or the device configuration changes** — that is the
  whole acceptance test, since the profile is deliberately blue on the wire.

### The undefined warnings were the 3D ruler, not the profiles

```
qrc:/Scene3DRightToolbar.qml:94: Error: Cannot assign [undefined] to bool
qrc:/main.qml:1835:25: Unable to assign [undefined] to bool     (x3, repeating)
```

`Scene3dView` exposes the ruler as a **child controller** — `Q_PROPERTY(QObject* ruler)`,
with `enabled` / `drawing` / `selected` / `hasGeometry` and
`clear` / `finishDrawing` / `cancelDrawing` / `deleteSelected` on the controller. But **22
sites** across `main.qml` and `Scene3DRightToolbar.qml` addressed them flat on the view:
`renderer.rulerEnabled`, `renderer.rulerFinishDrawing()`, `root.view.rulerEnabled`. None of
those exist there, so every read was `undefined`, the three ruler buttons could never
become visible, and the handlers would have thrown had they been reachable. **The 3D ruler
has been dead since the merge.** All 22 rewritten to go through `.ruler.`; the controller is
built in the view's constructor, so it is never null and needs no guard.

Worth knowing for the next merge: this is the shape upstream-QML fallout takes — it does
not fail the build, it fails one binding at a time and says so once in the log.

### A new log was classified by the previous log's channel count

The reported symptom: *committed red, open a side scan log → does not come up as side
scan; open a red log, then the side scan again → correct.*

`activeModel` classifies an opened file from `numberOfDatasetChannels`, and
`onChannelListUpdated` **only ever assigned** it — it returns early while the channel list
is still just the placeholder, and nothing cleared it between logs. So a newly opened log
was displayed as whatever the last one was until a full list arrived; with nothing opened
yet the count was 0 and the first side scan fell back to the committed device, which is
exactly what was seen.

Now cleared when a file starts opening, where `wasKlfFileOpened` is already set. `0` means
"not known yet" and `activeModel` already falls back to `committedModel` for it. Safe on the
live path: ConnectionViewer's Basic2D window latches the **maximum** channel count seen, so
a transient 0 cannot lower it, and `onNumberOfDatasetChannelsChanged` does nothing at 0.

The classification was also entirely silent, which is why this had to be reproduced by
hand. It now logs every update including the early returns (`CHANNELS: ...`), so a
misclassified replay says so in the application output.

### Backlog item 7 — the colour chooser follows the committed device, not the picture

Reported in the same test: *"the icon side/down even adapted, while colour did not."*
Correct on both counts, and the reason is one property.

`PulseAppClassic.isDevice2DTransducer()` sets `showAs2DTransducer` from
`userManualSetName` — the **committed** model — and `showAs2DTransducer` is what chooses
between the two colour selectors:

| | gated on | during a mismatched replay |
|---|---|---|
| echogram orientation, grid | `activeModel` (`Plot2D.onActiveModelChanged`) | follows the **log** — correct |
| `themeSelectorColorSS` / `themeSelectorColor2D` | `showAs2DTransducer` | follows the **committed device** |

So a red-committed app replaying a side scan draws a side scan and offers the 20-entry
`themeModelRed` palette for it, instead of the 6-entry `themeModelBlue` one the picture
actually uses.

**The colour palette is a display concern, not a configuration one** — it is which ramp is
painted on the samples on screen, and it belongs on the same side of the split as the
echogram itself. The fix is to gate the two selectors on the display model rather than on
`showAs2DTransducer`; `showAs2DTransducer` should keep meaning "the committed device is a
2D transducer", because that is what its other callers want.

Deliberately **not fixed now** — Olav's call, and not the focus. Recorded because it is a
clean, small example of the display-vs-configuration line being drawn in the wrong place,
and Stage 4 has to draw that line everywhere.

### The device swap, on playback

The swap wired in step 4 is keyed on the **connection** and is deliberately never raised by
playback, so what was tested above exercised the display path rather than the swap. The
"re-identify the device" backlog item therefore remains only half answered: a connected
device that disagrees is now handled, an **opened log** that disagrees still leaves the rest
of the app configured for the committed device. Whether opening a log should ever offer to
re-run setup is a real question and probably the answer is no — a log is not a device — but
it is worth writing down that the two halves were tested together and only one of them is
in scope.

---

## Backlog items 8 and 9 — added 12 Sept 2026

Both come from the same place: the app assumes the thing it is showing and the thing it is
connected to are the same thing. They are not, during a demo or a replay — and a demo in
front of an audience is exactly when that has to be graceful.

**There is a date on this.** An exhibition in late September. Both items below are
demonstration failures rather than field failures, which moves them ahead of most of the
rest of the backlog and puts them in the same bracket as the UI work itself.

### 8. Playing a log of the wrong type should adapt the whole UI, not half of it

The generalisation of item 7, and the one that matters at a show: a visitor — or one of us,
in a hurry — picks a side scan log while the app is set up as a red, and gets a side scan
picture wrapped in a 2D interface. Item 7 is the colour chooser; the same split runs through
the cone/view chooser, the per-device settings rows, and the brand artwork.

**The split as it stands, and it is deliberate:**

| path | keyed on | follows |
|---|---|---|
| display — echogram, grid, gain law | `activeModel` | the log |
| configuration — what is written to the transducer | `committedProfileKey` | the connected device |

That is right when a transducer is connected: an opened log must never reconfigure hardware.
It is wrong when **nothing is connected**, which is every demo and every exhibition laptop —
there is no hardware to protect, and the only honest answer is that the log IS the device.

**The shape of the fix, and why it is cheap now.** `committedProfileKey` is one function,
`resolveProfileKey(model, address, channels)`. It gains one more input: whether a device is
actually connected. With no connection and a log or demo running, it resolves from the log's
identity — which `activeModel` already computes — instead of from `userManualSetName`. Two
consequences worth stating:

- A **connected** device behaves exactly as it does today. The rule only relaxes where there
  is nothing to break.
- It wants to be visible, not magic. The app is claiming to be a device it is not connected
  to, and at a show somebody will ask. A quiet marker — the device name with the log's
  identity, or the existing "playing a log" state made to say which device — is enough.

The alternative shape is an explicit **presentation mode**: the user names the device the
demo should present as, and everything follows it. More control, more to explain, and one
more thing to forget to switch off. The connection-aware resolver is the better default; a
manual override on top of it is where presentation mode belongs if it is ever wanted.

### 9. Reconnecting to a real transducer after a demo, without restarting the app

Today this needs an app restart. That is a bad thing to discover in front of a stand.

**It is deliberate, and documented in the code.** `Core::startDemo()` closes live links, and
`Core::stopDemo()` says of itself:

> *Deliberately NOT calling `linkManagerWrapperPtr_->openClosedLinks()` here. Reopening links
> makes the app immediately start hunting for a transducer that is not there, which is what
> produced the "Configuring transducer..." / "Fixing transducer com link..." overlay once a
> demo ended. Link manager connections are restored so a user-initiated connect works
> normally, but reconnecting stays an explicit action.*

The reasoning is sound — the overlay it prevents was a real defect — but "an explicit action"
was never given anywhere to be explicit **from**, so in practice it became "restart the app".

**Three things, and only the first is required:**

1. **An affordance.** Something that says the demo is over and offers to reconnect. The
   connection panel can already open a link; nothing points at it at the moment it is needed.
2. **Re-run detection afterwards.** `exitDemoMode()` already clears the state properly —
   `userManualSetName`, `devName`, `numberOfDatasetChannels` all go back to fresh — but
   **nothing re-runs `ConnectionViewer.selectCorrectDevice()`**, whose only triggers are a
   device-list change, a channel-count change and the Basic2D settle timer. So even with the
   link back up, identification may not re-run until the device happens to say something that
   changes the list. A `selectCorrectDevice("exitDemoMode")` after the link reopens closes
   that gap.
3. **Verify the explicit path actually works.** The comment asserts that a user-initiated
   connect works normally after a demo. That has not been tested since the demo work landed,
   and the symptom being reported — "I need to restart" — is consistent with it not working
   rather than merely not being discoverable. Worth establishing which of the two it is
   before designing anything.

**This is cheaper than it was.** The re-setup machinery the swap now uses (`swapDeviceNow` →
`DeviceItem.resetAllSetupStates()` → re-commit) is exactly what "come back from a demo and
find the transducer" needs. Leaving demo mode and swapping device are the same operation
wearing different clothes, and item 9 should reuse the wire step 4 built rather than grow a
second one.

---

## Backlog item 10 — the device swap leaves parts of the UI behind (12 Sept 2026)

The first exercise of the step-4 swap machinery on hardware. **USB only**, one red and one
blue transducer on the bench, both expert switches under *Swap device*:

- **"Swap device automatically, without asking"** (`deviceSwapAutomatic`) — **partly works.**
  The red↔blue swap does happen, the setup re-runs, and the gray overlay **does** clear. What
  did not follow the new device: **the echogram orientation** and **the colour choices**.
- **"Force reselection of device"** (the expert checkbox that raises `swapDeviceNow` by hand)
  — leaves a full-window **gray overlay that is never removed**.

The **prompt** path — a detected device disagreeing with the committed one — is still
untested; it needs one transducer powered down and the other up.

### Orientation and colour are one property, and it is assigned rather than bound

Both symptoms come from `showAs2DTransducer`, a plain `property bool` on
`quickChangeObjects` (`PulseAppClassic.qml:469`):

- `reArrangeQuickChangeObject()` calls `plot2DGrid.setGridHorizontal(...)` from it — the
  **orientation**.
- `themeSelectorColorSS` / `themeSelectorColor2D` are gated `visible: !showAs2DTransducer` /
  `visible: showAs2DTransducer` — the **colour chooser**. That is backlog item 7, now
  observed on a live swap instead of a replay.

It is computed by `isDevice2DTransducer()`, which reads `userManualSetName`, falling back to
`devName`, and — this is the part that matters — **matches neither branch when the name is
`"..."`, in which case it silently keeps the previous device's value.** It is applied only by
`setUserInterface()` and `reArrangeQuickChangeObject()`, and those run on exactly two signals:
`devManualSelected` becoming **true**, and any change of `appConfigured`.

A detection-driven swap hits both gaps at once. `devManualSelected` is set **false** by the
swap and is only ever set true again by a **tap** in the chooser, so that trigger is gone. And
`appConfigured` fires first on its reset to false — at which point `userManualSetName` is back
to `"..."` and the recomputation keeps the **old** device's answer. Whether the later
transition back to true repaints correctly evidently depends on ordering, which is exactly
what "partly works" looks like.

**The fix is the shape, not the timing.** `showAs2DTransducer` should be a **binding** on the
resolved profile rather than a variable assigned from two handlers — then orientation and the
colour chooser follow a swap, and a replayed log, by construction. That is the same line item
8 draws (display follows the picture, configuration follows the connection), so this should be
done **with** item 8 rather than patched separately.

### The overlay

`hideBackground` (`main.qml:2637`) is a full-window gray rectangle at 0.8 opacity,
`visible: mainview.windowShadow`, and `windowShadow` is written imperatively from four places
and nowhere else:

| | what writes it | where |
|---|---|---|
| raised | the 1 s `selectorDelayTimer` firing with no selection made; `onSwapDeviceNowChanged` | `main.qml:2741`, `2770` |
| lowered | `devManualSelected` becoming true (a tap in the chooser); `devConfigured` becoming true | `main.qml:2778`, `2787` |

Which explains why one path recovers and the other does not: the automatic swap commits a
device and completes a configuration pass, so `devConfigured` goes true and lowers it. Force
reselection commits nothing — it waits for a chooser tap that can never come, because
`onUserManualSetNameChanged` sets `selectionMade = true` and `revealGate = false` as soon as
anything re-commits a model, and the reveal timer then fires into `if (!selectionMade)` and
does nothing. The overlay is raised with nothing under it and no way to dismiss it. (It
carries no `MouseArea`, so it obscures rather than blocks — in front of an audience that
distinction is worth nothing.)

The minimal fix is to stop assigning `windowShadow` and bind it to the one thing it means —
*the chooser is asking a question* — with the automatic swap, which asks nothing, never
raising it at all. **But Olav's call is to rethink the overlay properly as part of the UI
update rather than patch it here**, and that is right: it belongs with the connection screen
below.

### What still has to be tested, and when

Everything above is USB on the bench. The proper run is on a **boat with a real device**, and
that boat arrives with the **IP connector on the `192.168.144.*` address** — so one session can
cover item 10, the prompt path, and the still-unverified `PULSEblue-IP` acceptance test
(`PROFILE: committed key -> PULSEblue-IP` in the log, and **nothing** about the picture or the
device configuration changing).

---

## Stage 4 design gap — the connection screen was never prototyped

The design canvas covers the echogram screen, the rail, the settings panel and the phone
layouts. It does not cover the **connection screen** — the device chooser, the connection
list, and the overlay states around them — and that surface now looks dated next to everything
else being drawn.

It is also where three open things already point: the device chooser that the swap paths
reveal and hide, the gray overlay above, and item 9's missing "the demo is over, reconnect"
affordance. Prototyping it once, whole, is cheaper than fixing each of those where it sits.

**Not now.** When the UI work starts, propose a prototype session for this screen alone.

---

## Handover — where the next session picks up (12 Sept 2026, second session of the day)

**Repo state.** Branch `feature/device-profiles-step4`, seven commits, off `master` at
`392fd124`. Clean tree. `node tools/pulse-profile-check.js` passes. **Not merged to master
and not pushed** — that is the first housekeeping step, via GitHub Desktop.

| Commit | What |
|---|---|
| `91bbd63f` | the `imageType == 2` clash + the gain-law compare switch |
| `be448012` | stable entry ids for views and cones |
| `7bf03b69` | the resolver, `PULSEblue-IP`, detection-driven device swap |
| `006ea7e0` | step 4 write-up |
| `56f011bf` | the 3D ruler references, and the stale channel count |
| `fb0339b4` | first device build: two backlog items closed, three findings |
| `cc36dc1e` | backlog 8 and 9 |

### Verified on the tablet

- The 2D TVG renders through `EchogramTvg` again, and that closed backlog item 4 —
  the resolution-dependent colour strength was upstream's sample-index ramp.
- Black stripes are bypassed on red as well as blue (backlog item 6 question closed).
- The `undefined` warnings are gone — they were the 3D ruler, now addressed through
  `.ruler.`.
- Red behaves as a red: manual selection, cone chooser, 2D render.

### NOT verified, in the order it matters

1. **The device swap prompt has never been exercised.** The *automatic* swap has now been
   tried over USB, red↔blue, and partly works — see backlog item 10, which is what that run
   produced. The **prompt** path has not: it needs both transducers with the app committed to
   one, that one powered down and the other up. Expect the prompt once, naming both; **Keep**
   dismisses it and it must not come back for that device; **Switch** re-runs setup and the
   app comes up as the other device. Then the same in reverse.
2. **The stale-channel-count fix.** Re-run the sequence that found it: committed red, open a
   side scan log **first**, with nothing opened before it. It should come up as side scan
   immediately, and the log should show `CHANNELS: 0 -> 2 ... side scan`.
3. **The id migration.** On the first run of this build, the log should show
   `SETTINGS: migrating ecoViewIndex n -> ecoViewId ...` **once**, and never again; the
   chooser should come up on the view and cone that were selected before.
4. **`PULSEblue-IP`** — blocked on reaching the IP gateway. Acceptance test: the log shows
   `PROFILE: committed key -> PULSEblue-IP` and **nothing about the picture or the device
   configuration changes**.
5. **`expertOnly` has never run on a device** — no entry carries it yet. It is asserted in
   both expert positions by the check tool, and the first real use will be 820.

### Open decisions, unchanged

- **Which 2D gain law wins.** The compare switch exists for this. If upstream's ramp is
  kept it needs a control for its near/far constants; if PULSE's is kept, `imageType 4`
  can go.
- **The IP profile's real numbers** — resolution, samples, update period. Deliberately left
  at blue's, so the profile is currently a no-op on the wire.
- **Whether to bring 820 back**, now that it is a four-line data edit with two `expertOnly`
  entries.

### The backlog, in the order the late-September exhibition suggests

1. **Item 8** — a wrong-type log should adapt the whole UI. Connection-aware
   `resolveProfileKey`: with nothing connected, the log is the device.
2. **Item 9** — reconnect to a real transducer after a demo. Establish first whether the
   explicit reconnect path works at all, then give it an affordance and re-run detection.
3. **Item 10** — the parts of the UI that do not follow a device swap (orientation and
   colour), and the overlay that force-reselection strands. The UI half is the same binding
   item 8 fixes; the overlay is deliberately left to the UI update. The proper re-test waits
   for the boat and the IP connector.
4. **Item 7** — the colour chooser following the committed device. Subsumed by 8 if 8 is
   done properly, and worth doing as part of it rather than separately.
5. Items 1, 2, 3, 5, 6 as previously recorded. Item 2 (shallow and on-shore depth) is still
   the most important one that is not about demonstrations.

Then **Stage 4** of the UI work — the panels built against a profile, which is what the
whole device-profile rework was for. It has one prototyping gap to close first: the
**connection screen**, which was never drawn and now carries the overlay and the reconnect
affordance as well. See the section above item 10's handover.

### Two pre-existing defects, still open and still deliberately untouched

- `pulseSettingsLoader.active` referenced in `closePulseSettingsTimer`; no such id exists.
- `pinch2D` declares its own `isLiveView` while the line beside it logs `plot.isLiveView`.
- And the one found this session: `insetTop()` / `_isAndroid` are declared on
  `quickChangeObjects` but used by its **siblings**, the four alert indicators. Those
  bindings have never resolved. Fix by moving the two helpers to the root item next time
  that file is open.

---

## Backlog item 8 — done: with nothing connected, the log is the device (12 Sept 2026)

Branch `feature/device-profiles-step4`, commit `89c1d584`. Six files. Nothing compiled here;
static checks and `node tools/pulse-profile-check.js` below.

Items **7** and **10**'s UI half are folded in, as agreed — they turned out to be one
property, not three problems.

### The change is one input to the resolver

`committedProfileKey` resolved from `userManualSetName`. It now resolves from
`presentedModel`, which is the committed model **except** while presenting a log with nothing
connected, when it is the log's own identity:

```qml
property bool   hasConnectedDevice: linkIsOpen || deviceIsPresent
property bool   isPresentingLog:    !hasConnectedDevice
                                    && (isInDemoMode || wasKlfFileOpened || isOpeningKlfFile)
                                    && activeModel !== ""
property string presentedModel:     isPresentingLog ? activeModel : userManualSetName
```

**Either signal keeps today's behaviour.** They are two separate facts on purpose: a link can
be open with nothing on it, and a device can be known while its link is closed — a demo closes
live links. Requiring *both* to be false before relaxing means the relaxation only happens
where there is provably nothing to break.

- `linkIsOpen` — new `LinkManagerWrapper::hasOpenedLink()`, beside `openedIpAddress()`, reading
  the link model in C++. Any transport, so a USB transducer counts exactly like an IP gateway.
  Published by `ConnectionViewer.refreshConnectionAddress()`, from the same three places as the
  address.
- `deviceIsPresent` — the same `chosen` that `selectCorrectDevice` already acts on, so the two
  can never disagree.

**What it deliberately does not do is write `userManualSetName`.** The committed *model* is
untouched: nothing re-commits, no configuration pass starts, and closing the log puts
everything back. Only the *key* the UI reads moves. That is the same line step 4 drew for
`PULSEblue-IP` — a profile key is not a model — and it is what makes this safe to leave on.

**And it is why there was no 46-site sweep.** Every remaining `is2DTransducer` read hangs off
`committedProfile`, so all of them adapt in the unconnected case without being touched. Putting
the fix in the resolver instead of in the call sites is the whole economy of the step-1 to
step-3 work paying out.

### The claim is visible

The demo badge now names the device the app is presenting as — `Demo · PULSE blue`,
`Log · PULSE red` — and appears for a plain opened log as well as for a demo, whenever nothing
is connected. While a transducer *is* connected it says exactly what it said before, because
nothing has been relaxed. At a stand somebody will ask what it thinks it is; this is the
answer, and it costs one line.

### Items 7 and 10 — one property, assigned instead of bound

`quickChangeObjects.showAs2DTransducer` drove **both** the echogram orientation (via
`setUserInterface()` / `reArrangeQuickChangeObject()`) and **which colour palette is offered**
(`themeSelectorColorSS` vs `themeSelectorColor2D`). It was a `property bool` assigned by
`isDevice2DTransducer()`, which:

- read `userManualSetName`, falling back to `devName`, and **matched neither branch while that
  name was `"..."`** — silently keeping the previous device's answer;
- was only ever re-run by two functions, which in turn ran on `devManualSelected` going **true**
  — which a swap clears and never re-raises — and on any change of `appConfigured`, the first
  of which is its reset to false.

That is the whole of item 10's "not all parts of the UI responded", and item 7's colour chooser
with it. It is now a **binding**:

```qml
property bool showAs2DTransducer: pulseRuntimeSettings ? pulseRuntimeSettings.displayIs2DTransducer : false
onShowAs2DTransducerChanged: setUserInterface()
```

`displayIs2DTransducer` is the display side of `is2DTransducer`: `activeProfile.is2DTransducer`
when anything is identified, the committed answer when nothing is. `is2DTransducer` keeps
meaning what it meant — a fact about the committed device — because that is what its other
forty readers want. The change handler carries the imperative half (`setHorizontalNow()`,
`setGridHorizontal()`, the range push), which is the one thing a binding cannot do. Both
functions now guard on `plot`, since a binding can fire before the plot exists.

`PulseInfoColorScheme.qml`'s six reads moved to `displayIs2DTransducer` as well — which palette,
which legend, which favourites are all decisions about the ramp painted on the samples on
screen. A red-committed app replaying a side scan now offers the 6-entry blue palette it is
actually painting with, instead of the 20-entry red one.

### What a device build has to confirm

1. **Nothing connected, blue log on a red-committed app** (the exhibition case). The log should
   drive the *whole* interface: side scan orientation and grid, the blue view chooser instead of
   the red cone chooser, the 6-entry blue palette, the blue settings rows, blue artwork. The log
   should show `PROFILE: committed key -> PULSEblue (presenting a log, nothing connected;
   committed PULSEred)`. Close the log: everything returns to red, and **no configuration pass
   runs** on the way in or out.
2. **The same with a transducer connected** — nothing must change from today. This is the
   guard, and it is the more important of the two.
3. **The badge** reads `Demo · PULSE blue` / `Log · PULSE red` when presenting, and plain `Demo`
   when a device is connected.
4. **The swap** (item 10's other half): committed red, blue powered up — the orientation and the
   colour chooser must now follow. `DEV_UI: showAs2DTransducer ->` says when it moved and what
   both models were.
5. **The application output**: no new `undefined` reads, and no binding loop from
   `onShowAs2DTransducerChanged` calling `setUserInterface()`, which writes
   `pulseRuntimeSettings.isHorizontalGrid` — nothing `showAs2DTransducer` depends on, so it
   should not loop, but an extracted binding is exactly where that announces itself.

### The one open question

**Demo mode with hardware attached.** `Core::startDemo()` closes live links, so `linkIsOpen`
goes false — but a physically attached transducer may keep `deviceIsPresent` true, and then the
relaxation does not happen. That is deliberate and conservative: hardware is there, so today's
behaviour stands. It also means a demo run at a desk with a transducer plugged in behaves as it
does now rather than as the exhibition case does.

Whether demo mode should relax **regardless** of attached hardware is a real question and it is
Olav's: demo mode already forces `devConfigured` true and silences the things that talk to the
device, so it arguably already treats the device as absent. Against it: the settings bus would
push the log's profile values while a transducer sits there with its link closed. Worth
deciding once it is known whether a transducer will be connected at the stand.

### Static verification

No Qt toolchain in the sandboxed shell. Brace/paren/bracket balance unchanged against `HEAD` on
all six files (the two pre-existing imbalances are still exactly where they were); every
`pulseRuntimeSettings.X` reference in the whole `qml/` tree resolves to a declared property or
function, save the two known dangling ones (`dspSmoothFactor_ok`, `updateBottomTrack`); no
remaining writer of `showAs2DTransducer`, so the binding cannot be broken by an assignment; and
`node tools/pulse-profile-check.js` passes.

---

## Item 8, first device build — three hiccups and what they were (12 Sept 2026)

Commit `96765d14`. The core of item 8 worked: with nothing connected, a replayed log drove the
colour chooser and the view/cone chooser, which is the thing that was broken. Three things did
not, and all three are the same class of defect as item 10 — a value that is computed once, or
a question asked of the wrong model.

### 1. A demo now presents as the log whether or not a device is connected

**Olav's call, and it is the right one.** Starting a playback is the explicit act: the user
goes to the Recording tab and picks a file. `Core::startDemo()` already closes the live links
on the way in, so nothing is being talked to whether or not a transducer is plugged in. The
stop button in that tab is the way back, and the app returns to the connected device by itself
— `presentedModel` falls back to `userManualSetName` the moment `isInDemoMode` goes false.

This matters for the exhibition specifically: an aquarium is ordered, the stand may well have a
transducer connected and a second Android device projecting a log, and Olav will not be there.
The behaviour cannot depend on whether a cable happens to be in.

A **plain opened file** still asks, because opening one closes no links and the configuration
machinery keeps running — there, a connected transducer really is being talked to.

### 2. Why the first playback behaved differently from every later one

Reported: with nothing connected and the app set to red, the first blue log did not adapt;
after a second playback — of either type — it did.

`linkIsOpen` was published from `selectCorrectDevice`, `core.onConnectionChanged` and the
Open/Close button. **A demo closing the links on its way in goes through none of them, and
`stopDemo()` deliberately does not reopen them**, so the flag was stale in both directions: it
could still read "a link is open" through the whole first demo, which blocked the relaxation.
`ConnectionViewer` now refreshes it on every `isInDemoMode` change as well, and change 1 above
removes the dependency for demos entirely.

Not proven on hardware — it is the explanation that fits "first one fails, every later one
works, regardless of type". `isPresentingLog` now logs both its inputs whenever it moves, so
the next build says which it was instead of leaving it to be inferred.

### 3. The max depth selector kept the previous device's number — and its step

Two separate faults in one control.

**The value.** `valueField.text` starts as a binding on `defaultValue`, but `setSelectorValue()`
assigns it imperatively, and that **destroys the binding** the first time anything moves the
control — a tap, a pinch, a programmatic set. From then on a `defaultValue` that *changes* was
silently ignored. That is why swapping from a blue picture to a red one kept showing blue's
20 m instead of red's own stored preference: each device does keep its own value, and the
control had simply stopped listening. `HorizontalController` now re-seeds on
`onDefaultValueChanged`, with an equality guard so the control's own write-back — which updates
the stored value, and therefore `defaultValue` — cannot bounce back through it.

**The step.** Side scan steps in 5 m, 2D in 1 m, and the selector branched on
`is2DTransducer` — the **committed** device. Every question this control asks is about the
echogram on screen, so all of it now reads `displayIs2DTransducer`: the minimum, the step,
whether long-press is allowed, the value to show, and the auto-range paths.

**And the write-back moved to the same key as the read.** It was keyed on `userManualSetName`
while `defaultValue` read through the device type — two different questions about the same
value, which is exactly how a number lands in one device's preference and is read back out of
another's.

### The shape all three share

A binding that is overwritten, or a question asked of the committed device when the answer
belongs to the picture. Stage 4 should treat both as things to design out rather than to find:
every per-device value wants one owner and one key, and anything the user judges by looking at
it reads the display model.

### Still to come from this: item 9

Olav's other point — *terminating the playback is a good moment to check whether a device is
connected* — is backlog item 9, and this build has made it cheaper. Leaving demo mode already
restores the profile by itself; what is still missing is reopening the link and re-running
detection, plus something on screen that says the demo is over and offers it.

---

## Second device build — the log named all three causes (12 Sept 2026)

Commit `b5f74f1a`. Olav ran the build with a PULSE red on the 192.168.10.1 wifi gateway and
captured the application output. The diagnostics added in the previous commit did their job:
every one of these was read off the log rather than guessed.

### 1. The first playback drew a side scan horizontally — a binding-order bug, not a state bug

The log, in order:

```
DEV_UI: showAs2DTransducer -> false | active PULSEblue | committed PULSEred
qPlot2.h setHorizontalNow                                    ← wrong
CONTROL: selectorMaxDepth default -> 15 (was showing 3)
PROFILE: committed key -> PULSEblue | model PULSEblue (presenting a log, nothing connected;
                                                       committed PULSEred)
```

`setUserInterface()` ran **synchronously from the change handler**, at a moment when
`showAs2DTransducer` already said blue but `uiViews` was still the **red** profile's empty
list. Its side-scan branch asks `viewModeForId(pulseSettings.ecoViewId) === "side"`, could not
resolve the id against a list that does not contain it, and fell through to horizontal.

`activeProfile`, `committedProfileKey`, `uiProfile` and `uiViews` are one chain that moves
together, and QML guarantees no order within it. The handler now defers through
**`Qt.callLater`**, which runs once the chain has settled and coalesces the duplicate call the
log also shows.

**This is the whole of "it only works on the second attempt."** By the second demo
`userManualSetName` had been cleared to `"..."` by the first demo's exit, so the profile had
already resolved to blue before the handler ran — and the second attempt was right for a reason
that had nothing to do with it being second. The same explains why matching log types always
worked: nothing had to move.

### 2. The chooser switched palette; the picture did not

*"Now the colour selection shows HQ. Rendered colours are S-Dark."* Exactly right, and a
palette is not applied by being **shown**.

`themeSelectorColor2D` carries `onVisibleChanged: recalcSelectedIndex()`, and that function
ends by pushing its theme into the plot. `themeSelectorColorSS` had no equivalent: becoming
visible changed which swatches the user saw and nothing else, so the plot kept whatever theme
was last pushed — the red one. It now has `applyStoredTheme()` on the same hook.

And `recalcSelectedIndex()`'s guard moved from `userManualSetName === modelPulseBlue` to the
display model, so the 2D selector stands aside whenever the **picture** is a side scan, not
whenever the committed device is a blue. Asking the committed device is what let it push a red
theme over a blue picture in the first place.

### 3. Stopping a demo now reconnects — backlog item 9

The log after stop:

```
DEMO: leaving demo mode
PROFILE: presenting a log -> false | ... | linkOpen false | devicePresent false
devList: numberOfDatasetChannels -> 0
selectCorrectDevice: 0 dev(s)
```

The profile returns by itself, exactly as designed — and the link never comes back. Olav's
reading was right: *"we do not engage the link manager properly after having shut everything
down."*

`Core::startDemo()` closes the live links and `Core::stopDemo()` deliberately does not reopen
them, because reopening while the app still believed it was mid-configuration is what produced
the *"Configuring transducer…"* overlay. The comment said reconnecting should stay an explicit
action — but **no affordance was ever given to be explicit from**, so in practice it became
"restart the app".

**Pressing stop is that action.** The overlay cannot come from here: `exitDemoMode()` has just
cleared `dataUpdateActive`, `devConfigured`, `unableToConfigure` and `devName`, so the app
reopens the link in the state it would have had at a cold start with a device attached. It then
bumps `redetectRequestId`; `ConnectionViewer` answers with `selectCorrectDevice()` immediately
**and once more after a 1.5 s settle**, because a link takes a moment to open and a transducer a
moment to speak, and neither need produce a device-list change, a channel-count change or a
Basic2D settle — `selectCorrectDevice`'s only other triggers.

`LinkManagerWrapper::openClosedLinks()` is now `Q_INVOKABLE`; it was already there, just not
reachable from QML.

### What the log also showed, and is not fixed

- **The demo's ghost device trips the beta-key force-break.** On the first demo:
  `forceBreakConnection for device Device ID: -1.0 … triggered, should break? true and
  isConnected true`. The replay announces an unidentified device before the log's real identity
  arrives, and the beta gate treats it as an unsupported unit. It did no visible harm — the
  links were already closed — but it is the kind of thing that only misbehaves in front of an
  audience. Worth a guard on `isInDemoMode` next time that code is open.
- **`Echogram speed: New value 1 (persistent 1.3)`** on entering a blue demo: the speed
  follows the log's profile and does not return the stored value afterwards. Cosmetic, noted.

### What the next build has to show

1. **First demo, mismatched type, transducer connected.** A side scan log on a red-committed
   app: `setVerticalNow`, the blue palette actually rendered, the blue view chooser, 5 m steps.
   No second attempt needed. `DEV_UI: applying display model, 2D? false | view side` says the
   deferred pass saw a settled profile.
2. **Stop the demo.** `DEMO: reopening the links the demo closed`, then
   `devList: re-detection requested (#1)` and `devList: selectCorrectDevice trigger =
   redetectRequested`, then the real transducer identified again — `devList: DEV_DETECT(devType)`
   — with no restart and no "Configuring transducer…" overlay left on screen.
3. **The palette on the way back**: stopping a blue demo on a red-committed app must return the
   red theme to the picture, not leave the blue one loaded.

---

## Third device build — two flaws left, and they were the same one twice (12 Sept 2026)

Commit `5393eb4f`. Olav: *"Now we are talking. This worked very well."* The deferred redraw,
the pushed palette and the reconnect on stop all behaved. Two things remained, and both are the
pattern this whole run has been about: **a display question answered by the committed device,
and a binding destroyed by an assignment.**

### 1. The range ceiling stayed on the previous device

With a blue log presented on a red-committed app the max depth selector could still be stepped
to **52** — red's profile ceiling, its 50 m dist max plus 2 — instead of stopping at the blue
swath width.

`maximumDepth` was a binding on `committedProfile.maximumDepth`, and **three places assigned
it**: `DeviceItem` when configuring a blue, `main.qml`'s manual blue pick, and the expert
dist-max control. Any one of those destroys the binding for the rest of the session, and from
then on the ceiling is frozen at whichever device happened to be current. This is the same
fault as the max depth *value* last round, one property over.

Two answers exist and only one of them can live in a profile record:

- **A 2D transducer's ceiling is hardware** — a profile key, as it is now.
- **A side scan's ceiling is the configured swath width**, which the user picks in Settings.
  No static number can hold that, which is exactly why those three assignments existed.

So the dynamic answer gets its own property. `maximumDepth` is a binding that cannot be broken,
`maximumDepthOverride` is what the UI writes, and `0` means "no answer, use the profile". A
`Binding` in `main.qml` drives the override from `pulseSettings.echogramWidth` **while the
picture is a side scan**, with `restoreMode: RestoreBindingOrValue` so an expert's own 2D
dist-max survives a side scan log played in between.

In `main.qml` because it exists once. `PulseAppClassic` is instantiated per `Plot2D`, so two
copies would fight over one property in split screen — and the binding needs nothing from the
UI layer anyway: `displayIs2DTransducer` is the whole question.

**One consequence worth knowing:** editing the expert dist-max *while a side scan picture is on
screen* now has its ceiling reverted by that binding (the width wins). `distMax` itself is
still written. Arguably right — the swath width is the honest ceiling for a side scan — but it
is a behaviour change and it is written down here rather than discovered.

### 2. The side scan ruler drew only its right half

`Plot2DGrid::calculateRulerTicks()` mirrors the ticks to both sides of the centre line when
`!is2DTransducer` and does not otherwise. That flag reaches the grid over the settings bus
from `pulseRuntimeSettings.is2DTransducer` — the **committed** profile. Start a 2D transducer,
play a blue log, and the picture turns vertical while the ruler keeps the 2D tick set: one
side only.

A ruler draws the picture's own scale. `main.qml` now publishes **`displayIs2DTransducer`** as
its own bus key; `plot2D_grid` reads it for the mirroring, and `plot2D` for
`reRangeDistance()`, which decides the *shape* of the auto range — `0..max` for a 2D echogram,
symmetric for a side scan — and wants the same answer for the same reason. Both fall back to
`is2DTransducer` when the new key is absent, so a snapshot that does not carry it behaves
exactly as before, and `is2DTransducer` keeps meaning what it says for the configuration path.

This one also matters beyond the demo case: with a transducer connected and a mismatched log
playing — the exhibition with the aquarium — the committed and display answers genuinely differ,
and only the display one is right for anything drawn.

### The pattern, now stated once for Stage 4

Five separate defects this session reduced to two rules, and the new UI should be built so that
neither can recur:

1. **Anything the user judges by looking at it reads the display model.** Orientation, grid,
   ruler, palette, range shape, range ceiling, step size. `is2DTransducer` answers "what is
   connected"; `displayIs2DTransducer` answers "what is on screen". Nothing that draws should
   ask the first.
2. **A value with two sources gets one binding and one override, never an assignment.** Every
   fault above was a `property x: <expression>` that some handler later assigned to, silently
   and permanently. Where a dynamic answer is needed, it goes in its own property that the
   binding falls back from.

### What the next build has to show

1. **Max depth on a presented blue log**: the selector stops at the configured swath width
   (35 if that is what Settings says), not at 52, and 1 m steps return on a 2D picture.
2. **The side scan ruler**: ticks on both sides of the centre line after starting 2D and
   opening a blue log. The log says `VALUE_CHANGE: publishing displayIs2DTransducer false`
   followed by `VALUE_CHANGE: grid is2DTransducer_ (display) was updated to false`.
3. **Nothing changed for a live device of either kind**, which is the guard as always.

---

## CORRECTION — the third build's change was reverted (12 Sept 2026)

**The section above is what was attempted, not what is in the tree.** On device it made things
worse: the colour chooser and the layout stopped adapting to a replayed log — behaviour that
had been confirmed working the build before — the ruler was still wrong, and the max depth step
went back to 1 m on a side scan.

`5393eb4f` is reverted by `b187cc31`. The tree is back to `b5f74f1a`, the build Olav confirmed
as *"now we are talking"*, plus the ruler fix alone (`1b27c122`).

### What went wrong, honestly

**One commit carried two unrelated changes** — the `maximumDepth` binding-plus-override
restructure and the display-model bus key — so when the build came back worse there was no way
to tell which half did it without another round trip. That is the process error, and it is the
one worth not repeating: the device is a slow, precious test rig, and a commit sent to it should
test one idea.

**One defect in it is provable.** Both bus keys were made to write the *same* member through an
`if / else if`:

```cpp
if (m.contains("displayIs2DTransducer")) is2DTransducer_ = …;
else if (m.contains("is2DTransducer"))   is2DTransducer_ = …;
```

The settings bus sends **partial maps** — `onIs2DTransducerChanged` sends one key,
`onDisplayIs2DTransducerChanged` the other — so that variable ended up holding whichever key
arrived last. A coin flip between the committed and the display answer, re-tossed on every
change. That alone could keep the ruler wrong.

**The colour and step regression is not explained by the code.** Both read
`pulseRuntimeSettings.displayIs2DTransducer` in QML, which the reverted commit did not touch.
If it recurs, the log settles it: `DEV_UI: showAs2DTransducer ->` says what the UI believes and
what both models were at that moment.

### What is in the tree now

The ruler, isolated:

- `main.qml` publishes `displayIs2DTransducer` as its **own** bus key.
- `Plot2DGrid` keeps it in its **own** member with a "seen it" flag, so the two keys can never
  overwrite each other, and falls back to the committed answer only while the display key has
  never arrived.
- Only `calculateRulerTicks()`'s mirroring reads it. `plot2D.cpp` is untouched;
  `reRangeDistance()` keeps asking the question it always asked.

### Still open, and to be done on its own

**The range ceiling.** The diagnosis stands and is worth keeping: `maximumDepth` is a binding on
`committedProfile.maximumDepth` that three places assign to — `DeviceItem` configuring a blue,
`main.qml`'s manual blue pick, and the expert dist-max control — and any one of them freezes the
ceiling at whichever device was current, which is why a presented blue log can still be stepped
to red's 52. A side scan's true ceiling is the configured swath width, which no static profile
key can hold.

The fix shape (an unbreakable binding plus an explicit override) is probably still right. What
it must not be again is one commit with something else in it.

---

## Backlog items 11–13 — parked deliberately, 12 Sept 2026

All three are recorded rather than fixed. The reason is the same for each: **the new UI
replaces the thing they live in**, and tuning a control that is about to be redesigned is work
paid for twice.

### 11. The max depth selector's ceiling still follows the wrong device

A blue log presented on a red-committed app can still be stepped to **52** — red's profile
ceiling — instead of stopping at the blue swath width.

The diagnosis is complete and stands: `maximumDepth` is a binding on
`committedProfile.maximumDepth`, and **three places assign it** — `DeviceItem` configuring a
blue, `main.qml`'s manual blue pick, and the expert dist-max control. Any one of those destroys
the binding for the rest of the session and freezes the ceiling at whichever device was current.
A side scan's true ceiling is the configured **swath width**, which no static profile key can
hold, which is why those assignments exist at all.

The fix shape is an unbreakable binding plus an explicit override property that the UI writes.
**It has been attempted once and reverted** (see the correction above) — not because the shape
was wrong but because it travelled with an unrelated change. Do it alone, or do it as part of
the new range control, which is where it will end up anyway.

### 12. The side scan ruler, and a regression nobody has explained

The ruler fix in `1b27c122` — a display-model bus key with its own member in `Plot2DGrid` — is
**unverified on device**. It is the isolated retry after the reverted attempt.

What is genuinely unexplained, and worth stating plainly rather than dressing up: on one build
the colour chooser and the layout **did** adapt to a replayed log, and on the next they did not,
and the change in between did not touch the QML property (`displayIs2DTransducer`) that both of
them read. Reverting that change did **not** restore the behaviour either, which rules out the
simple story. Something in this area is order- or state-dependent in a way the code reading has
not caught.

**Do not chase it from the code.** When it next appears, one log line settles it:

```
DEV_UI: showAs2DTransducer -> <value> | active <model> | committed <model>
```

If `active` says PULSEblue and `showAs2DTransducer` says true, the profile chain is at fault. If
`showAs2DTransducer` says false and the picture is still red, the fault is downstream of it.
That is a five-minute answer with the log and an unbounded one without.

### 13. A USB connection crashed the app, with no log

Once, on a USB-connected transducer, during this run. No output was captured, so there is
nothing to go on.

**Left alone on purpose:** nobody uses USB at the moment — the field connection is the wifi
gateway, and from the boat onwards the IP connector on `192.168.144.*`. Recorded so that if it
recurs it is the second sighting rather than the first, and so a future session does not spend
the exhibition window on a transport no customer is using.

---

## Session close — 12 Sept 2026 (second day session)

**Branch `feature/device-profiles-step4`, 20 commits, clean tree, `node
tools/pulse-profile-check.js` passes. Not merged to master and not pushed** — Olav pushes via
GitHub Desktop, and that is the first housekeeping step.

### What this session did

Backlog items **7, 8, 9 and half of 10** — the demo-facing work the late-September exhibition
put first.

| | |
|---|---|
| **Item 8** | `committedProfileKey` resolves from the log's identity when nothing is connected, and always in demo mode. A demo presents as the log whether or not a transducer is plugged in; a plain opened file still asks. It never writes `userManualSetName`, so nothing re-commits and closing the log puts everything back. |
| **Item 7 + 10's UI half** | `showAs2DTransducer` became a binding on a new `displayIs2DTransducer`, so the orientation and the colour chooser follow the picture. `PulseInfoColorScheme`'s six reads moved with it. |
| **Item 9** | Stopping a demo reopens the links and re-runs identification. **Confirmed working well on device.** |
| Along the way | The max depth *value* per device; the deferred redraw (`Qt.callLater`); the side scan palette actually being pushed to the plot; the connection facts refreshed across demo transitions. |

### Verified on the tablet

- A mismatched log drives the whole interface — colour chooser, view chooser, orientation — with
  nothing connected.
- Reconnecting to the real transducer after a demo, without a restart. *"Works really well."*
- The gain law, the stale channel count and the 3D ruler fixes from earlier in the day.

### Not verified

1. **The ruler fix** (`1b27c122`) — the isolated retry, never built.
2. **The device swap prompt** — still no hardware evidence; needs both transducers, one powered
   down and the other up.
3. **`PULSEblue-IP`** — blocked on the IP gateway, which arrives with the boat. Acceptance test:
   `PROFILE: committed key -> PULSEblue-IP` in the log and **nothing** about the picture or the
   device configuration changing.
4. **Item 10's bench findings** — the overlay that force-reselection strands, and the swap over
   USB, both waiting for the boat run.
5. **`expertOnly`** — no entry carries it yet; the first real use will be 820 kHz.

### The backlog, as it now stands

| # | What | State |
|---|---|---|
| 1 | The side scan mosaic does not apply the TVG | open |
| 2 | Shallow (<0.5 m) and on-shore depth | open — **the most important one that is not about demonstrations** |
| 3 | The water body filter dims the bottom in the mosaic | open |
| 4 | Resolution steps visible in the 2D TVG render | **closed** — it was the `imageType 2` clash |
| 5 | Re-identify the device and re-run setup | **done** for a connected device (the swap); a log that disagrees is item 8's territory |
| 6 | The TVG bypasses the black-stripes fix | open, confirmed on both devices |
| 7 | The colour chooser followed the committed device | **done**, with item 8 |
| 8 | A wrong-type log should adapt the whole UI | **done** |
| 9 | Reconnect to a real transducer after a demo | **done**, confirmed on device |
| 10 | The device swap leaves parts of the UI behind | UI half **done**; the overlay parked for the UI update; re-test waits for the boat |
| 11 | The max depth selector's ceiling | parked — the control is being redesigned |
| 12 | The side scan ruler, and the unexplained regression | fix unverified; chase it from the log, not the code |
| 13 | A USB connection crashed the app, no log | parked — nobody uses USB |

Smaller, still open: the demo's ghost device tripping the beta-key `forceBreakConnection`;
echogram speed not returning to its stored value after a blue demo; `insetTop()` / `_isAndroid`
declared on `quickChangeObjects` but used by its siblings; the dead `pulseSettingsLoader`
reference in `closePulseSettingsTimer`; `pinch2D`'s own `isLiveView` shadowing
`plot.isLiveView`; `HorizontalController.qml:188` branching on `devName`; and the upstream
settings-migration module plus the `Qt.labs.settings` → `QtCore` move.

### The two rules this session earned, for Stage 4 to design out

1. **Anything the user judges by looking at it reads the display model.** Orientation, grid,
   ruler, palette, range shape, range ceiling, step size. `is2DTransducer` answers "what is
   connected"; `displayIs2DTransducer` answers "what is on screen". Nothing that draws should
   ask the first.
2. **A value with two sources gets one binding and one override, never an assignment.** Every
   fault this session was a `property x: <expression>` that some handler later assigned to,
   silently and permanently.

And one about process, learned the hard way: **a commit sent to the device tests one idea.** The
device is a slow, precious test rig; two changes in one commit cost a round trip to un-mix.

### Where the next session starts

**Stage 4 — the new UI**, against the design canvas and Direction A (the edge rail), built
reading a profile rather than branching on `is2DTransducer`. The device-profile rework exists
for exactly this.

Its one prototyping gap comes first: **the connection screen was never drawn**. It carries the
device chooser, the gray overlay from item 10, and the reconnect affordance from item 9 — three
open things that all land on one surface. Prototype it whole before building any of them.

---

## Stage 4 — the connection screen, prototyped (12 Sept 2026)

The prototyping gap Stage 4 had to close before anything is built. Drawn on page 4
of the design canvas, **Connection screen**, five artboards plus notes.

### What it is today

`echoSounderSelectorRect` in `main.qml` (2724–3115). Two `EchoSounderSelector`
panels 450 × 800 px inside a 1000 × 800 `freeContainer`, sliding to centre over
`hideBackground` — a full-window gray sheet with a dot pattern at 0.8 opacity —
revealed by a 1 s `selectorDelayTimer` whenever nothing auto-selected, and faded
out by a 3.5 s animation once something is picked.

Olav's verdict: *"I was happy with it two years back. Not anymore."* Too large,
does not fit a split screen, and it does not scale — a new model is being
developed now, and red and black already share one profile.

**Four open things land on this one surface**, which is why it was worth drawing
whole rather than patching in three places:

| | |
|---|---|
| the model chooser | where `userManualSetName` originates |
| the gray overlay | backlog item 10 — force reselection strands it forever |
| the reconnect affordance | backlog item 9 — "an explicit action" with nowhere to be explicit from |
| the device-swap prompt | step 4, currently drawn inside `PulseAppClassic` and gated on `indx === 1` |

### What it becomes

**A surface you can reach, that reveals itself only when it has a question.**
Detection still wins and still closes it without a tap — that is the common case
and none of it changes. What changes is that the screen is reachable on purpose
(a new **source** button at the foot of the rail), and that it can never outlive
the question that raised it.

Three rules, each one a defect designed out rather than found later:

**1. The cards are data, not code.**

```qml
"cards": [
  { id: "red",   badge: "#d81f26", art: "2d",   profile: "PULSEred"  },
  { id: "black", badge: "#3a3a3c", art: "2d",   profile: "PULSEred"  },
  { id: "blue",  badge: "#3d7fd0", art: "side", profile: "PULSEblue" }
]
```

Two entries, one profile. Red and black *are* the same hardware, and the owner
still gets to pick the one he bought — the app commits the same profile either
way. A new model is one more entry, exactly as 820 kHz became one data edit in
step 3, and `tools/pulse-profile-check.js` can assert the card list the same way
it asserts the view list.

**2. The scrim is a binding on one question.** Today `windowShadow` is a plain
`property bool` written from four handlers:

| | writes | where |
|---|---|---|
| raised | `selectorDelayTimer.onTriggered`, `onSwapDeviceNowChanged` | `main.qml:2750`, `2779` |
| lowered | `onDevManualSelectedChanged`, `onDevConfiguredChanged` | `main.qml:2787`, `2796` |

Force reselection commits nothing, so neither lowering path runs and the sheet is
raised with nothing under it — item 10. The prototype replaces the lot with

```qml
readonly property bool chooserAsking:
       swapDeviceNow
    || pendingSwapModel !== ""
    || (committedModel === "..." && graceElapsed && !isPresentingLog)
```

and the surface itself is `visible: chooserAsking`. That is rule 2 from the last
session — *one binding and one override, never an assignment* — applied before
the bug exists. Plus a close button whenever there is an echogram to go back to,
so cancelling is always possible.

**3. The picture the sounder makes is its identity.** Each card carries a real
echogram — a 2D trace for red and black, a side scan swath for blue — not a
photograph of a box. It is what `image/pulse_info_red_black_large.png` and
`pulse_info_blue_large.png` already do, it needs no photography for hardware that
does not exist yet, and it reads across a room at an exhibition. 272 px wide,
wrapping, so the same screen works at 1280, at an Android split screen (cards
become rows) and on a phone.

### Seven states, one surface

| state | what is on screen | the fact it binds to |
|---|---|---|
| Nothing identified | the cards, no dismiss | `committedModel === "..." && graceElapsed` |
| Detection answered | nothing — it closes itself | `committedModel !== "..."` |
| Unrecognised device | the cards, "which is it closest to" | `forceBreakConnection` |
| A device disagrees | prompt over the running picture | `pendingSwapModel !== ""` |
| Force reselection | the cards, **with a close button** | `swapDeviceNow` |
| Lost connection | the wire strip turns red, offers Reconnect | `hasDeviceLostConnection && didEverReceiveData` |
| Presenting a log | **no scrim** — a badge and Stop | `isPresentingLog` |

Every one of those facts is already computed. Nothing new is stored; one binding
reads them instead of four handlers writing a bool.

The **wire strip** is the single honest line at the top: nothing on the wire /
searching / found (with name, channel count, firmware, serial and address) /
unrecognised / lost. It is the only thing that changes between the states, and it
is what makes "nothing connected" a first-class state rather than something that
looks broken — which is exactly what Olav uses this screen for.

### The demo and recording indicators

Olav's ask: *"we have a nice recording indicator. And we need a demo indicator.
And a button to stop the demo that matches the new UI design, as well as a button
to find/open the desired file."*

- The **source button** at the foot of the rail is the permanent door to this
  screen — and it is what item 9 never had. The source chip top-right is the same
  door: what the app thinks it is, one tap to change it.
- While a log is presenting, an indicator pill names the device the app is
  presenting **as** — `Demo · PULSE blue` — which is item 8's claim made visible,
  with **Stop** in the same pill. Stop already reopens the links and re-runs
  detection (built and confirmed on device), so the pill becomes *"Finding the
  transducer again…"* and then the live chip.
- **Open a recording** sits on the connection screen, because that screen is the
  answer to "there is no transducer, what am I looking at".
- The indicator stack is one column bottom-right on side scan and top-right on a
  2D picture, by the existing flow rule — newest pings are at the top of a side
  scan, so overlays belong at the foot.

### What this prototype does not decide

- **The link panel itself.** `ConnectionViewer`'s +UDP / +TCP / MAVProxy / baud /
  flasher rows stay where they are, behind the **Connections** button. They are
  upstream's developer surface and nothing here needs them moved.
- **The card artwork.** The prototype reuses the canvas's echogram images. Real
  cards want a short, well-chosen trace per model — a small job, and one Olav
  should pick the frames for.
- **Whether the swap prompt keeps its own artboard or becomes a state of this
  screen.** Drawn as a prompt over the running picture, because a swap can happen
  mid-use and the picture must not stop. Moving it off `PulseAppClassic` does
  retire the `indx === 1` gate — one surface above both panes cannot draw twice.

### What to build first

The chooser and the binding, in that order, and **on their own** — the device is
a slow test rig and force reselection is the one state that is provably broken
today and provably fixed in a single screenshot.


### Revision the same day — the cards carry the hardware, not the echogram

Olav's verdict on the prototype: *"This is a very nice design. We will use this, it
is a huge improvement compared to the original solution."* With three changes.

**1. The card art is the product render.** Rule 3 above said the picture a sounder
makes is its identity. That was the right instinct for a screen full of echograms
and the wrong answer for this one: the question being asked is *which one is in
your hand*, so the answer is a picture of the thing in your hand. Three renders
supplied, keyed off their backgrounds, trimmed and committed as

```
image/pulse_device_red.png     116 × 229   cylinder, red band, conical element
image/pulse_device_black.png   560 × 330   wide downscan block
image/pulse_device_blue.png    328 × 281   side scan wedge, TECHADVISION embossed
```

The filename carries the model, so a card entry names its art without a lookup.
They are **not in any qrc yet** — nothing references them until the screen is built.

**Contained, never cropped.** A cylinder, a wide block and a wedge are three very
different aspect ratios; `background-size: contain` on a light plate lets each keep
its own shape at a common height. Cropping to a uniform thumbnail would cut the
blue wedge in half and make the red one unreadable. The plate is light
(`#f5f6f7 → #dbdde0`) because the hardware is dark grey and black — on a dark card
the black downscan would simply disappear.

**And the wordmark stays live text under the render**, never baked into the image.
That is the direct fix for what Olav reported about today's screen: the current
`pulse_info_*.png` artwork has *PULSE red* / *PULSE black* drawn into the pixels, so
enlarging the card enlarges the lettering as pixels and it goes to mush. Text that
is text survives every size — 292 px on a tablet, 100 px beside the wordmark at
640, 84 px on a phone.

**2. PULSE black is a true downscan.** Not "a second red". It runs the **same
profile** as red — same 510 / 710 / 810 kHz, same `PULSEred` key — but the beam is a
downscan rather than a cone, so the picture differs. The card says what it is while
the app keys on the profile, which is exactly the two-entries-one-profile shape the
card list was built for.

> Worth watching, not deciding now: a true downscan and a conical 2D have different
> beam geometry, so bottom track and TVG may eventually want different numbers. If
> they ever do, black stops being a card entry and becomes a profile entry — which
> costs one line, because that is what the keyed map is for.

**3. The header names the app.** `Pulse Echo Sounder`, the official name, replaces
the generic "Echo sounder".


---

## Prototyping complete — where the build starts (12 Sept 2026, session close)

**The connection screen is signed off.** *"Excellent. We will use this."* The design
canvas now carries it as page 4, and the Stage 4 prototyping gap is closed. Nothing
about the app has been built yet — every commit in this session is documentation or
assets.

The three renders are registered in `images.qrc` alongside the other `image/` assets
(this supersedes the "not in any qrc yet" note above). 22 entries, no duplicates,
every entry present on disk, and the file is already listed in `CMakeLists.txt:156`.
`node tools/pulse-profile-check.js` still passes.

### Repo state

Branch `feature/device-profiles-step4`, **25 commits, 17 ahead of origin, not
pushed** — Olav pushes via GitHub Desktop, and that is the first housekeeping step.
This session added four:

| Commit | What |
|---|---|
| `72bfae7b` | the connection-screen prototype, written up |
| `e3da8c23` | the three product renders, named by model |
| `2ac4fd2f` | the revision — hardware on the cards, black is a true downscan |
| `2e590bd3` | the renders registered in `images.qrc` |

### The build order, and why

**1. `PulseConnectionScreen.qml` — the chooser and the binding, alone.**

A new `PulseApp*`-level component, not a `main.qml` addition: one surface above both
`Plot2D` panes, which is what retires the `indx === 1` gate the swap prompt carries
today. It reads a `cards` list from the profile map, exactly as the choosers read
`ui.views` and `ui.cones`, and it is shown by one binding:

```qml
readonly property bool chooserAsking:
       swapDeviceNow
    || pendingSwapModel !== ""
    || (committedModel === "..." && graceElapsed && !isPresentingLog)
```

Then `windowShadow` and its four writers go, and `echoSounderSelectorRect`,
`freeContainer` and both `EchoSounderSelector` instances come out of `main.qml`
(~390 lines, 2724–3115). **Nothing else in the same commit.** Force reselection is
the one state that is provably broken today and provably fixed in one screenshot, so
that is the whole acceptance test for the first device build:

- Force reselection shows the cards **and can be cancelled**. Today it strands a
  gray sheet with nothing under it.
- Nothing detected → the cards, no dismiss. Detection answers → the screen closes
  itself, with no tap and no change from today.
- Committing a card still writes `userManualSetName` and nothing else, so the whole
  configuration path behaves exactly as it does now.

**2. The card list into the profile map.** `cards` beside `ui.views` / `ui.cones`,
with red / black / blue, and `pulse-profile-check.js` extended to assert it the way
it already asserts the view list — including the acceptance test that a fourth entry
appears with no change outside the profile record.

**3. The swap prompt and the wire strip.** Move the prompt out of
`PulseAppClassic` onto the new surface, and give the strip its five states from the
facts that already exist (`linkIsOpen`, `deviceIsPresent`, `devName`,
`numberOfDatasetChannels`, `connectionAddress`, `forceBreakConnection`,
`hasDeviceLostConnection`).

**4. The rail's source button and the demo indicator.** These belong to
`PulseAppV2`, so they wait for the rail itself. Until then the connection screen is
reached the way it is reached today.

### Still open, unchanged

- **The boat run**: the swap prompt has never been exercised on hardware, item 10's
  bench findings need re-testing, and `PULSEblue-IP` is still blocked on the IP
  gateway. One session on the water covers all three.
- **Backlog 11 / 12 / 13** stay parked.
- **Backlog 2** — shallow and on-shore depth — remains the most important item that
  is not about demonstrations.
- **Black's beam geometry**: a true downscan shares red's profile today. If bottom
  track or TVG ever want different numbers for it, black stops being a card entry and
  becomes a profile entry. One line, which is what the keyed map is for.


---

## Stage 4, step 1 — the connection screen, built (12 Sept 2026)

Signed off on device: *"Perfect."* Eleven commits across seven device builds, on
branch `feature/device-profiles-step4` — now 38 commits, of which 30 are not yet
on `origin/feature/device-profiles-step4`. (`master` and `origin/master` are
level, so the branch is the only thing outstanding.)

`qml/PulseConnectionScreen.qml` (registered in `qml/qml.qrc`) is instantiated once
in `main.qml` above both `Plot2D` panes. Out of `main.qml` went
`echoSounderSelectorRect`, its 1 s `selectorDelayTimer`, `freeContainer`, both
`EchoSounderSelector` panels, the `selectedRed`/`selectedBlue` states with their
slide transitions and 3.5 s fade, `hideBackground`, and `windowShadow` — 3121
lines down to 2898.

| Commit | What |
|---|---|
| `4d6a4c14` | the chooser and the one binding; the old chooser out of `main.qml` |
| `3760e373` | it fits the screen it is on, and scrolls |
| `623a4c37` | it opens at once when nothing can answer it |
| `32304000` | the cards wear the real wordmark |
| `76522080` | a status strip that says what the link is doing |
| `aaa8cc9e` | start a simulation |
| `eea40a7d` | a panel of its own |
| `aa7dd484` | transducer, and Downscan |
| `9581b284` | the two buttons chained across the foot of the panel |
| `8b5b941c` | the caption out of the chain, so the gaps are equal |
| `043883bf` | the strip identifies a transducer |

### The one binding, and the defect underneath it

`windowShadow` was a plain bool written by four handlers. Force reselection
commits nothing, so neither lowering path ran and the sheet was raised with
nothing under it — backlog item 10. All four writers are gone:

```qml
chooserAsking = swapDeviceNow
             || (userManualSetName === "..." && !isPresentingLog
                 && (graceElapsed || !somethingMayStillAnswer))
```

**Item 10's root cause, found and fixed.** `main.qml`'s `onSwapDeviceNowChanged`
cleared `swapDeviceNow`. That `Connections` object is created at load and
`DeviceItem`'s later, so main's handler ran **first**, and clearing the flag there
re-entered the signal and left `DeviceItem`'s handler looking at a flag that was
already false — so the reset it exists to perform never ran at all. That is both
the stranded sheet on force reselection *and* the bench symptom where an accepted
swap kept the previous device's orientation and colours. `main.qml` now keeps only
`devManualSelected = false` (which `resetAllSetupStates()` does not do) and lets
`DeviceItem` own the flag, which is the order `acceptDeviceSwap()` always
documented.

`graceElapsed` is a 1.2 s latch, applied only when `somethingMayStillAnswer`
(`hasConnectedDevice || lastCommittedModel !== ""`). With nothing connected and
nothing ever committed, nothing is going to answer, so the screen opens at once.

### Layout

Two shapes and one breakpoint, measured in **design units** (pixels ÷ `uiScale`)
so it means the same thing on a phone, a tablet and an Android split screen:
`wide` (≥ 620 × 340 du) puts the render above the wordmark, as many cards per row
as fit; `narrow` puts it beside the wordmark, one card per row and a card ~150 px
tall instead of ~420. Everything lives in a `Flickable` that centres its content
when it fits and scrolls when it does not (`contentHeight = content.height +
content.y * 2`).

The **panel** is the measure: the card row sets its width, and the strip above it
takes the same one. Every other width derives from the width *inside* the panel,
so the cards can never be wider than the box holding them.

The two buttons sit in a **chain** across the foot — a `RowLayout` of five
children where the three *spacers* carry `Layout.fillWidth` and the buttons do
not. Alone, the outer two gaps split the room and the simulation button is
centred; with `Keep` present, all three share it. The caption is deliberately
*outside* the chain, positioned under the button it explains, because as a chain
item it made that button's slot far wider than the button and the gaps came out
equal between slots while looking wrong between buttons.

### Three QML rules this step paid for

1. **Never set a plain `width`/`height` on a direct child of a Layout.** A Layout
   overwrites it with the implicit size. The cards never went side by side because
   the `Flow` holding them sat in a `ColumnLayout` with a plain `width`, and a
   `Flow`'s implicit width is not its row width. Use `Layout.preferredWidth`, or
   do not use a Layout. (A `Column`/`Row` positioner is not a Layout — `width` is
   fine there.)
2. **A chain distributes between items, not between the things you can see.** If
   an item is wider than its visible content, the equal gaps will not look equal.
3. **Wrapping text needs a width that does not depend on its height.** The strip's
   row is given an explicit width rather than `anchors.fill`, so the detail line
   can decide its own height.

### The cards, and the artwork

Data, in the shape step 2 moves into the profile map — `id`, `name`, `tagline`,
`art`, `logo`, `badge`, `profile`. Red and black are two cards on one profile.

The wordmark is `pulse_logo_red/_black/_blue`, the same 500 × 99 files the profile
map already names as `ui.brand.logo` / `ui.brand.logoBlack`. They are dark ink
drawn for a light ground, so the light plate grew to carry the render *and* the
wordmark and the dark card below keeps only the tagline. This does not undo the
prototyping rule about baked-in lettering: that was about `pulse_info_*.png`,
where the letters share pixels with the artwork. A live-text name remains as the
fallback when an image does not load, so a new model can arrive as a data edit
with its logo a commit behind.

### Behaviour that must not regress

- Committing a card writes `userManualSetName` and `devManualSelected` exactly as
  the old selectors did, with blue's three-line `chartResolution` / `distMax` /
  `maximumDepth` seed carried over verbatim and in the same order.
- Every way out of the screen commits a model, so it cannot strand itself. With
  nothing ever committed there is no dismiss, by design.
- `Start a simulation` calls `enterDemoMode()` — the Recording tab's demo path,
  not its browse path. That makes `isPresentingLog` true, so the screen closes
  itself the same way detection closes it. Stopping is still the Recording tab's
  button, which already reopens the links and re-runs detection (item 9).

### Confirmed on device

Force reselection shows the cards and can be cancelled; stopping a simulation
raises the screen again; nothing detected shows the cards with no dismiss;
detection still closes the screen by itself; the narrow layout adapts in an
Android split screen; and the screen is up as fast as the echogram.

### Left open, on purpose

- **Wording, for the finalisation pass.** The strip still says "sounder" in
  *"Sounder found, nothing open on it yet"* and *"Power the sounder on"*. And
  *"Not connected"* was observed while the tablet was on a wifi network with
  nothing answering on it — Olav's call whether that is describing the right
  thing.
- `qml/EchoSounderSelector.qml` is dead code, left on disk and in `qml.qrc` on
  purpose for these builds. It goes with the step 3 wire strip.
- Backlog 11 / 12 / 13 stay parked. The boat run still covers the swap prompt on
  hardware, item 10's bench re-test and `PULSEblue-IP`.


---

## Stage 4, step 2 — the card list is profile data (12 Sept 2026)

Confirmed on device: *"The chooser is the same as before."* One commit,
`dcc62e7e`, on `feature/device-profiles-step4` — now 39 commits, of which 31 are
not yet on `origin/feature/device-profiles-step4`.

The three cards left `PulseConnectionScreen.qml` for the profile map, beside
`ui.views` / `ui.cones`, one list per record and in the record each card commits
to: red's holds `red` and `black`, blue's holds `blue`. The screen keeps one line
of device data.

```qml
readonly property var cards: pulseRuntimeSettings ? pulseRuntimeSettings.uiCards : []
```

A new model is now one entry in a profile record, with nothing to change in the
screen at all.

### Three things the move had to decide

**`profile` is written in the card, not inferred from the record holding it.**
Red and black both name `modelPulseRed`. Inferring it from the enclosing record
gives the same answer today and makes "two cards on one profile" an accident of
where an entry sits rather than a stated fact — and what a card commits is a
MODEL, which is not what the map is keyed by.

**A card names WHICH wordmark it wears, never the path.** The record already
holds `ui.brand.logo` and `ui.brand.logoBlack`, so the card carries
`"wordmark": "logo"` or `"logoBlack"` and `cardForScreen()` resolves it —
renaming a model's artwork stays one edit. That function is also the single place
the seven-key shape the screen reads is stated: `id`, `name`, `tagline`, `art`,
`logo`, `badge`, `profile`.

**A variant offers no cards of its own.** `PULSEblue-IP` is blue's record plus
overrides, so it inherits blue's `cards` through `mergedProfile()`. Left alone it
would have drawn the blue card twice and, worse, handed a profile KEY to
`userManualSetName`. A record offers its cards only when its key IS its model,
which is exactly what `devName` says:

```qml
if (!prof || prof.devName !== key)
    continue        // a variant is not a model
```

`uiCards` is also the one `ui*` accessor that does **not** read the committed
profile. Every other one answers "what does the transducer on the wire offer".
This one is the question asked when nothing is committed and there may be nothing
on the wire at all, so it spans the whole map.

### What the check asserts now

`node tools/pulse-profile-check.js`, on top of everything it already did: every
card field present and non-empty; every badge a hex colour; every `wordmark`
naming a wordmark its own record carries, and no card repeating a brand path;
every card committing a model and never a profile key; card ids unique across
records; the assembled list three long in record order with each logo resolved;
the exact seven-key shape; and every render and wordmark both on disk *and* in
`images.qrc`.

And the acceptance test — the same promise the 820 kHz test makes about views. A
FOURTH card is one entry added to `pulseRed.ui.cards`: it reaches the screen in
record order, its logo resolves the same way as every other, it commits a model,
it arrives in the same shape, and the three that were already there come back
byte-identical. No accessor, no resolver line and no second record had to change.

The check now also reads `modelPulseRed` / `modelPulseBlue` out of the QML rather
than retyping them, because the card records name the models by property.

### Left open, on purpose

Step 3 (the swap prompt off `PulseAppClassic`, plus the wire strip) and step 4
(the rail's source button) are untouched, and the `deviceSwapPending` term is
still held back from `chooserAsking`. Backlog 11 / 12 / 13 stay parked. The
wording pass is open, unchanged from step 1.

Two checks were suggested after the build and have not been reported back. Both
cost nothing on the next one:

- `CONN_SCREEN: built 3 cards` in the log is the whole test for the variant rule.
  Three is the only number that proves both records contributed *and* that blue
  was not offered twice.
- Tapping **black** specifically. Its `profile` now comes out of red's record
  rather than being typed on the screen, so it is the one card where the
  committed model could have changed silently.

---

---

## The IP variant is not blue-only — red and black need it too (12 Sept 2026)

Recorded as a requirement. Deliberately not built.

`PULSEblue-IP` exists today as though the IP telemetry link were a blue feature.
It is not. The 192.168.144.* connection carries **every** PULSE echo sounder: the
echogram is routed through the data channel of the Skydroid and SIYI devices, and
that is as available to a red or a black as it is to a blue.

What it is worth is a compromise red and black were designed under and can now
drop. Their data rate is held at about 60 kbit/s come what may, because on the
5.8 GHz wifi every extra bit was paid for in wireless range. On the IP link it is
not. The first thing to spend it on is the **period** — `ch1Period` is 50 ms on
red and black today — exposed to the user as an echogram speed change. On wifi
that would skyrocket the data rate and cost range; on IP it is free.

### What it touches, when it is built

**The resolver stops sending red straight home.** `resolveProfileKey()` returns
`modelPulseRed` outright for a recognised red and never looks at the address;
`blueKeyFor(address)` is the only place the connection enters the answer, and
`pulse-profile-check.js` asserts *"red on the IP gateway is still red"*. That
assertion inverts, and `blueKeyFor` generalises into a `keyFor(model, address)`
that every model passes through. The fallback is unaffected: with nothing
identified on an IP address, blue remains the right guess.

**It is a different KIND of variant from `PULSEblue-IP`.** Blue's IP record was
built to be provably a no-op on the wire — `chartResolution`, `chartSamples` and
`ch1Period` identical to blue, on purpose, so the first build could prove that
committing it changed nothing. A red IP record whose whole point is a faster
period is the opposite: it changes what is transmitted, deliberately. Its
acceptance test is a measurement on the water — echogram speed against range —
not an equality.

**Two things are already in its favour.** `ui.tunable.period` is declared and
unconsumed on red for exactly this case, and a variant offering no cards of its
own falls out of step 2, so a red IP record appears with no change to the
connection screen at all.

What the numbers should BE is still a measurement, exactly as blue's are. The
limits are what let the UI expose the control in the first place; the period the
echogram actually runs at is decided on the water.


---

## Stage 4, step 3 — the swap prompt moved, and what the move exposed (13 Sept 2026)

Two commits on `feature/device-profiles-step4`: `468d3c68` the prompt becomes a
mode of the connection screen, `7cf9d7d8` `EchoSounderSelector.qml` off disk and
out of `qml.qrc`. The branch is 35 commits ahead of
`origin/feature/device-profiles-step4`.

### What the device confirmed

Blue committed by hand, then the wifi joined with a red already powered on. The
connection screen came up carrying the swap question — *"Connected to PULSE
red"*, switch or keep — instead of a banner over the echogram. That is the step,
and it works.

### What it was standing in front of

Everything else in the run is one family, and Olav's reading of it was right:
*"they likely all originate from previous parked items."* They do. The move did
not cause them; it put them on a screen where they are unmissable, which is what
a full-bleed surface does with state that was previously only half-visible
behind a running picture.

---

### Defect A — an accepted swap moves the model and not the presentation

Accepting red gave a screen that was *initially correct* and then, in Olav's
words, *"all of a sudden"* became mostly blue:

| what appeared | what it should be | the value behind it |
|---|---|---|
| the horizontal side scan view, bottom half only on a one-channel device | red's 2D view | `ecoViewId` / the view applied at configure time |
| HQ, blue's preferred colour map | S dark, red's preference | `pulseSettings.colorMapIndexReal` |
| max depth stepped by 5, ceiling 25 | red's hardware ceiling, 52 | `maximumDepth` — **backlog item 11** |
| temperature shown | correct for red, off by default on blue | the datasetTemp path |

And: *"Behaviour is not always consistent though."* That sentence is the
diagnosis. Inconsistency between runs is the signature of a value written by
assignment from more than one place — which answer you get depends on which
handler ran last, and that ordering is not stable.

**The mechanism, stated once.** `resetAllSetupStates()` resets the *device
parameter handshake* — twenty-odd `*_ok` acknowledgement flags, the four
category flags, `devConfigured`, the dynamic-resolution pair. It touches nothing
on the presentation side, because in the shape the app had when it was written
there was nothing on the presentation side to touch.

Presentation state today is in two classes:

* **a binding on the profile.** It follows a swap by construction and needs no
  reset at all. This is what backlog items 7 and 10 produced when
  `isDevice2DTransducer()` became `displayIs2DTransducer`, and it is why
  orientation and the colour *chooser* now follow a swap correctly.
* **a shared value written by assignment from per-model preferences.** It
  freezes at whichever model wrote it last, and a swap re-runs none of the
  assignments.

All four rows in the table are the second class. `colorMapIndexReal` is the
clearest: the two real preferences are `colorMapIndex2D` and
`colorMapIndexSideScan`, and `colorMapIndexReal` is the shared value actually
pushed to the renderer — assigned in five places in `PulseAppClassic.qml`, each
from whichever model happened to be current. `maximumDepth` is the same shape
with three writers, which is item 11 exactly, and the ceiling of 25 is blue's
`pulseSettings.echogramWidth` still standing after the swap to red.

**So the fix is not a bigger reset.** It is rule 2 — *a value with two sources
gets one binding and one override, never an assignment* — applied to the
presentation state as a whole, the way item 7/10 applied it to the display
model. A value that is a binding on the committed profile has nothing to reset,
so "how do we properly reset on a swap" stops being a question rather than
getting a longer answer. That is the Stage 4 work these symptoms belong to, and
it is bigger than one commit.

---

### Defect B — the app auto-selects a device that is no longer there

Bench sequence, no boat needed: wifi off, echogram stops, then the expert force
reselection. The connection screen comes up. About ten seconds later the app
commits red on its own and shows the frozen echogram again. Nothing is connected
at all.

**Nothing in the app is a liveness fact.** Every fact detection relies on was
learned once and never expires:

* `linkIsOpen` stays true — a UDP socket does not close because the wifi went
  away.
* the device stays in `devList` with `devType` and a name, so
  `selectCorrectDevice()`'s `chosen` is still non-null and `deviceIsPresent`
  stays true.
* `devName` survives the reselection: `DeviceItem.onSwapDeviceNowChanged` has
  `//pulseRuntimeSettings.devName = "..."` commented out. (`exitDemoMode()`, by
  contrast, *does* clear it — the three resets in this app are three hand-copied
  lists that have drifted, and the swap one is the thinnest.)
* `hasDeviceLostConnection` **cannot** become true here. `lostConnectionTimer`
  requires `didEverReceiveData`, and the reselection had just set that false;
  nothing re-raises it, because it is raised by `onDevNameChanged` and the name
  never changed.

So after the reselection the app holds a complete, confident, entirely stale
identity — and `selectCorrectDevice()`'s *"nothing committed yet"* branch fires
on exactly that state, because the reselection is what puts `userManualSetName`
back to `"..."`:

```qml
if (previous !== "" && previous !== "...") {
    pulseRuntimeSettings.requestDeviceSwap(previous, model)
} else {
    pulseRuntimeSettings.userManualSetName = model   // no test that anything is answering
}
```

The guard that would have asked — `previous !== "..."` — is the very thing a
force reselection destroys. **A force reselection is therefore the one state in
which the app is guaranteed to answer its own question from stale facts.**

The root of it is below QML: a dead link reports itself open and a dead device
stays in the list. Olav's instinct that the C++ is to blame is right about the
root. But the app does not have to act on it, and there is one true liveness
signal already wired: `dataset.onDataUpdate`, which restarts the 2.5 s
`lostConnectionTimer`. That pair is "data arrived within the last 2.5 s", and
nothing reads it as a fact today.

---

### Defect C — the strip claims a connection that does not exist

Same run: the strip said *"Connected to PULSE red"* with nothing on the wire.
`linkState` reaches `talking` on `linkIsOpen && linkNamed`, and both are stale
for the reasons above, while its `lost` state is unreachable because it is built
on `hasDeviceLostConnection`, which defect B shows cannot be raised after a
reset. The strip is not lying on its own account; it is reporting the app's own
best facts faithfully, and they are wrong.

This is the same root as the open wording note from step 1 — *"Not connected"*
observed on a wifi network with nothing answering. Both are the link state
machine describing a socket rather than a transducer. The wording pass should
not be attempted until the states underneath it are true.

---

### The one fix proposed now

Deliberately small, one idea, and testable on the bench without the boat.

**1. A real liveness latch.** `isAnswering` in `PulseRuntimeSettings`, raised in
`DeviceItem`'s `dataset.onDataUpdate` and lowered unconditionally at the top of
`lostConnectionTimer` — above its `didEverReceiveData` and `devName` guards,
which is what makes it survivable across a reset. One raiser, one lowerer, in
the shape `graceElapsed` already uses. A log or a demo also produces
`onDataUpdate`, so the latch is not on its own a statement about hardware.

**2. A first commit is instant; a re-commit must prove the device is still
there.**

```qml
// A FIRST commit is the app learning what is on the wire, and it must stay
// instant - that path is every cold start. A LATER one, after something wiped
// the commit, has to prove the device is still answering: the devList keeps a
// dead device and the link stays "open" when the wifi goes away, so an identity
// is not evidence of a transducer.
if (!pulseRuntimeSettings.everCommittedModel || pulseRuntimeSettings.isAnswering)
    pulseRuntimeSettings.userManualSetName = model
```

`everCommittedModel` is the same fact `PulseConnectionScreen` already keeps as
`lastCommittedModel`; it belongs in `PulseRuntimeSettings`, and the screen
should read it rather than keep its own copy — but that is a second commit and
not this one.

**What this deliberately does not do.** It adds no new trigger for
`selectCorrectDevice()`. Detection re-runs on a device-list change, a redetect
request and the Basic2D settle window, and on none of those after a force
reselection with a live device — which is exactly why *"force reselection shows
the cards and can be cancelled"* works today. Making data arrival a trigger
would close the screen on the next frame and undo a confirmed step-1 behaviour.
The cold start is untouched for the same reason: the gate is not applied to a
first commit, so there is no path where the app waits for data it will only
receive after it configures.

**Acceptance, on the bench.** Wifi off, force reselection: the screen comes up
and *stays* up, and no model is committed. Wifi on with a transducer: cold start
still commits as fast as it does today, and a force reselection still shows the
cards and still cancels.

### Not being done now, on purpose

* Defect A in full — it is rule 2 across the presentation state, and item 11 is
  one of its four known instances.
* The strip's states (defect C), and the wording pass that waits on them.
* Backlog 11 / 12 / 13, still parked.
* The rail's source button and the demo indicator — step 4, waiting for
  `PulseAppV2`.
* The IP variant for red and black, recorded as a requirement.

---

## What the logcat showed, and the B fix built from it (13 Sept 2026)

The run was captured end to end. Two things came out of it that were not
visible from the code alone.

### The ten seconds, named

```
CONN_SCREEN: asking -> true | committed PULSEred | swapNow true | ...
DEV_RESELECT: raised in main - clearing devManualSelected; DeviceItem owns the reset
...
devList: selectCorrectDevice trigger = unableToConfigure
devList: observed device PULSEred SN 139 baud 115200
selectCorrectDevice: 1 dev(s): [0]t=128/sn=139*
devList: DEV_DETECT(devType): board 128 -> model PULSEred channels 0 maxCh 0 settled false | previously ...
```

The trigger is not a device-list change. It is **`unableToConfigure`**, and the
chain is exact:

1. the force reselection puts `userManualSetName` back to `"..."`;
2. configuration cannot start — the log says so plainly: *"onUserManualSetNameChanged
   observed, but devName is ... so nothing will happen"*;
3. so `PulseAppClassic`'s *"Configuring transducer…"* overlay stays visible, and
   its `breakAndReconnectLinkTimer` — `interval: 10000` — elapses. That is Olav's
   ten seconds, to the second;
4. `unableToConfigure` goes true, `ConnectionViewer.onUnableToConfigureChanged`
   re-runs `selectCorrectDevice()`;
5. the dead PULSEred is still in `devList` with its board enum and serial, and
   `previously` is `"..."`, so the silent-commit branch fires.

`channels 0` on that line is the whole indictment: nothing had arrived at all,
and the app committed a transducer anyway.

**`unableToConfigure` is being asked a question it cannot answer.** It means
"configuration is taking too long", which is a sensible reason to re-run
selection when a model IS committed and the device is not co-operating. With
nothing committed, configuration was never attempted, so the same flag means
only "you have not been told which device this is yet" — and re-running
selection then is the app answering the user's open question on their behalf.

### The blue window — the root of defect A

This is the one the code did not show, and it is worse than the symptom list
suggested. Between the reset and the re-commit, with `userManualSetName === "..."`:

```
EchogramCompensation: Plot2D onActiveModelChanged -> (none committed)
PROFILE: committed key -> PULSEblue | model ...  | address 192.168.10.1 | channels 0
DEV_PARAM: dev.chartResolution set to pulseRuntimeSettings.chartResolution 25
Detected pulseRuntimeSettings.distMax got new value  25000
Detected pulseRuntimeSettings.transBoost got new value  1
```

and ten seconds later, after red is committed:

```
PROFILE: committed key -> PULSEred | model PULSEred | address 192.168.10.1 | channels 0
DEV_PARAM: dev.chartResolution set to pulseRuntimeSettings.chartResolution 2
Detected pulseRuntimeSettings.distMax got new value  50000
Detected pulseRuntimeSettings.transBoost got new value  0
```

**`"..."` is not a neutral state. It is blue.** `resolveProfileKey()` falls
through to `blueKeyFor(address)` for an uncommitted model, so every binding on
`committedProfile` snaps to blue's numbers, and those are not merely read — they
are *written to the transducer*. A red device spends the whole window being
configured as a side scan: resolution 25 instead of 2, 25 m instead of 50, boost
on instead of off.

That resolver line already carried the warning — *"Still not obviously right,
and still the thing to revisit when a second red-like device exists"*. It turns
out not to need a second red-like device. The fallback is right for an
**unrecognised device**, which is a thing on the wire with a name this build does
not know. `"..."` is not that. It is **no device**, and it has been borrowing
blue's answers all along.

This is the root of every symptom in defect A. The view, the colour map, the max
depth ceiling and the temperature are not four independent regressions; they are
four values that were read or assigned during a window in which the whole app
believed it was a blue. It also explains *"the screen was initially set up as it
should… and all of a sudden"* — the swap is instant, the blue window starts a
moment later.

**Proposed, not built.** `"..."` should hold the last committed profile rather
than fall back to blue, because "I have not been told yet" is a reason to change
nothing, not a reason to guess. With nothing ever committed there is nothing to
hold and blue remains the right guess, so the cold start is unaffected. One
change at the resolver, and it removes the window that every one of defect A's
symptoms lives in — which is a great deal cheaper than the rule-2 sweep across
the presentation state, and probably has to happen before that sweep can be
judged at all.

### What was built — `f2aafa11`

Olav's criterion, and it is the right one: *"A device present should show itself
by the fact that it is sending data."*

* **`isAnswering`** in `PulseRuntimeSettings` — raised only by
  `dataset.onDataUpdate`, lowered only at the top of the 2.5 s
  `lostConnectionTimer` that the same signal restarts, *above* its
  `didEverReceiveData` and demo guards so it owes nothing to any reset. It says
  data is flowing, not "hardware is present"; a replayed log produces
  `onDataUpdate` too, which is why the one place that reads it also requires a
  device in the list.
* **`everCommittedModel`** — has this run ever learned what is on the wire. It
  survives every reset on purpose: it separates "still finding out for the first
  time" from "being asked to find out again", and those deserve different
  confidence.
* Detection's silent-commit branch requires one or the other. A first commit
  stays instant — that path is every cold start, and gating it would mean
  waiting for data the device may only send once configured. A re-commit has to
  see data.

**What it deliberately does not change**, on Olav's instruction: a wifi drop
during ordinary use. The commit is not cleared there, so detection's
`model !== userManualSetName` guard already skips the branch entirely — the
echogram keeps its screen and resumes on its own when the transducer answers
again. Losing a wireless link is normal and must never throw the user back to
the connection screen. No new trigger for `selectCorrectDevice()` either: making
data arrival one would close the screen on the next frame after a force
reselection and undo a confirmed step 1 behaviour.

### Still open, and worth a decision rather than a fix

A force reselection with a **live** device still auto-commits after those same
ten seconds — `isAnswering` is true, so the new gate lets it through, exactly as
today. That may be wrong on its own terms: a force reselection is a request to
be asked, and answering it automatically ten seconds later is the same
overreach in a case where the app happens to be right. The narrower fix is that
`unableToConfigure` should not trigger a re-selection at all while nothing is
committed. It is a behaviour question, not a defect, so it waits for Olav.

---

## Detection and configuration — how it should be (13 Sept 2026)

An analysis, not a change. Nothing below is built.

Olav's statement of intent, which is the right one and has never been written
down in the code:

> 1. When data is flowing in, figure out what device is actually sending data.
> 2. Show the echogram screen, but also configure that device to behave like we
>    want (apply profile).
> 3. Make sure the user understands that we are in a configuration state. And
>    halt the echogram while we configure to reduce the network traffic while
>    configuring, to increase the chance of success on a weak link.

And his account of how it got where it is: *"The configure device comm link
alert was specifically a workaround to fix a fact that I was not at all trying
to configure the correct device (device list problem)."*

### The observation that forced this

With `f2aafa11` on the device: wifi off, force reselection — the screen came up
and stayed up, which is right. Then the wifi came back, the device reconnected,
**the echogram was visibly moving behind the scrim** — and no automatic
selection happened.

The new gate is not what held it. `selectCorrectDevice()` was never run again.
Its triggers are a device-list change, a redetect request, the Basic2D settle
window, and `unableToConfigure` — and that last one had already gone true at the
ten-second mark and does not fire a second time, because `onUnableToConfigureChanged`
only acts on the rising edge. The list did not change. So the gate was not
consulted; nothing asked the question at all.

**Detection is a set of events, and it needs to be a rule.** Every defect in
this area is a missing or spurious edge on one of five unrelated signals, and no
amount of adding edges converges.

That observation also settles a question the gate was written around: **the
transducer free-runs.** Data was arriving with no model committed and no
configuration performed. So waiting for data before committing cannot deadlock,
and the `everCommittedModel` exemption in `f2aafa11` — a first commit is exempt
because the device might only send data once configured — is unnecessary. The
rule can be uniform.

### What the app actually knows

Sorted by what each boolean *means*, not by what it is called.

**Traffic — five names, one real fact.**

| | raised by | lowered by | what it really means |
|---|---|---|---|
| `isAnswering` | `dataset.onDataUpdate` | 2.5 s `lostConnectionTimer` | **data arrived within 2.5 s** — the only true one, and new |
| `isReceivingData` | `onDevNameChanged` | `onDevNameChanged`, `lostConnectionTimer` | the device has a NAME |
| `didEverReceiveData` | `onDevNameChanged` | every reset | the device has announced a name since the last reset — neither "ever" nor "data" |
| `dataUpdateActive` | `onDataUpdate` | **nothing**, except `exitDemoMode()` | data has flowed at some point this run |
| `hasDeviceLostConnection` | `lostConnectionTimer`, gated on `didEverReceiveData` | several | unreachable after any reset, by construction |

`dataUpdateActive` is the load-bearing one and the most misleading: a one-way
latch named like a live state. It has exactly one reader —
`configurationInProgressIndicator.visible` — and that reader is the origin of
defect B, because the overlay becoming visible is what starts
`breakAndReconnectLinkTimer`. With the latch never lowered, the overlay is
visible whenever the device is not configured, *forever*, whether or not
anything is connected.

**Identity — two real facts and three ghosts.**

* `userManualSetName` — the committed MODEL. One meaning, well kept.
* `devName` — the selected device's raw name. Real, but survives a reselection.
* `devIdentified` — raised in two places with two different meanings: in
  `onDevNameChanged` for "we know its name", and at the end of
  `configurePulseDevice()` for "we have finished setting it up".
* `devDetected` — **never set true anywhere.** Its one reader,
  `quickChangeObjects.isDeviceDetected`, has therefore always been false.
* `appConfigured` — written in four places and **read nowhere**.
* `devManualSelected` — set by the manual pick, cleared by a swap, never
  re-raised; it now means "the last commit was a manual one, and no swap has
  happened since", which is not what any of its three readers want.

**Configuration — this part is sound.** The twenty `*_ok` acknowledgements, the
four category flags and `devConfigured` are a real handshake: set a parameter,
wait for the device to echo it back, move on. It is the one mechanism here that
does what its name says, and nothing below proposes touching it.

### What it should be

**Three facts about the transducer on the wire, and only three.**

1. `isAnswering` — data arrived within the last 2.5 s. Already built.
2. `committedModel` — which model the app is configured for; `"..."` for none.
   This is `userManualSetName` and needs no change.
3. `awaitingUserChoice` — **the user has asked to decide, and detection must not
   answer.** This is the fact the app has never had.

Everything else is derived:

```
silent        = !isAnswering
undecided     = committedModel === "..."
configuring   = !undecided && !devConfigured
ready         = devConfigured
```

**The third fact is the whole knot.** Today, "the app does not know" and "the
user is choosing" are the same state — `userManualSetName === "..."` — and they
want opposite behaviour. A returning device should be identified immediately; a
force reselection must not be answered automatically ten seconds later. With one
flag to distinguish them, detection becomes a single rule:

> Commit a model when a device is identified in the list, **and** data is
> arriving, **and** nothing is committed, **and** the user is not choosing.

Re-evaluated whenever any term changes — which is what makes it a rule rather
than five handlers racing. It covers the cold start, the device returning after
a dropped link, and the force reselection, with no special cases and no timers.

It also explains why `chooserAsking` opens with `swapDeviceNow ||`: that term is
reaching for "the user is choosing", but `swapDeviceNow` is cleared
synchronously by `DeviceItem`, so it cannot carry that meaning and the
`nothingIdentified` term has to cover for it. `awaitingUserChoice` is the honest
version of what that binding was already trying to say.

**Purpose 3, honestly.** The overlay should say "configuring" when the app is
configuring — `configuring && isAnswering` — and not when a latch says data once
flowed. That single substitution makes it disappear when the link dies, which is
correct (you are not configuring, you are disconnected), and with it the ten
second timer never starts.

**And the band-aid retires on Olav's own argument.** `breakAndReconnectLinkTimer`,
`unableToConfigure` and *"Fixing transducer com link…"* exist because the app
used to configure a device it had never properly selected. `selectCorrectDevice()`
fixed that at the source. This is precisely the reasoning already written into
`main.qml` when the auto-reboot dataflow guard was removed — *"a band-aid for
the old stuck-configuring state caused by never binding a real 'dev'; that is
now handled at the source"* — and it applies here word for word. A configuration
that genuinely stalls should keep saying *"Configuring transducer…"*, which is
true, rather than escalate into an action that re-opens a settled question.

### Proposed order, one idea each

Each is bench-testable with a wifi toggle; none needs the boat.

**1. The overlay tells the truth.** `configurationInProgressIndicator.visible`
reads `isAnswering` in place of `dataUpdateActive` — one term, one reader, no
other site touched. Bench: wifi off, the overlay disappears instead of
escalating; and defect B's ten-second trigger never starts, because the timer is
started by that overlay becoming visible.

**2. Detection follows data.** `awaitingUserChoice`, raised by the force
reselection and cleared by any commit, and the rule above. This is the one that
fixes the observation at the top: the device comes back, data arrives, the model
is committed, without a force reselection ever being auto-answered. The
`everCommittedModel` exemption from `f2aafa11` comes out at the same time — the
transducer free-runs, so it is not needed.

**3. Retire the band-aid.** `breakAndReconnectLinkTimer`, `unableToConfigure`,
the *"Fixing transducer com link…"* string and `ConnectionViewer`'s
`onUnableToConfigureChanged` trigger. Deliberately after 1 and 2, so that if a
real stall ever did depend on it, that shows up while the mechanism is still in
the tree.

**4. `"..."` holds the last profile.** The blue window, from the previous
section. Independent of 1–3 and could go first; it is the root of defect A's
symptom list.

**5. The ghosts.** `devDetected` (never true), `appConfigured` (never read),
`devManualSelected` (means something no reader wants), and the naming of
`isReceivingData` / `didEverReceiveData` / `dataUpdateActive`, which describe a
name and a latch rather than traffic. A cleanup commit, not mixed into any of
the above.

**6. The presentation sweep** — rule 2 across the values defect A exposed, which
should only be judged once 4 has removed the window they were being measured in.

### What still belongs to the C++

A dead link reports itself open and a dead device stays in the list. The rule
above means the app no longer *acts* on that, which is enough for every symptom
seen so far — but `linkIsOpen` and `deviceIsPresent` remain facts nothing
retracts, and the status strip will keep having to work around them until
something does. Recorded, not scheduled.

---

## The configuration state, and the escape hatch (13 Sept 2026)

Settled with Olav: the three user intents above, plus a requirement for the new
UI. *"Today we have 'configuring transducer…' only. A bit more information would
be great. Especially if there are struggles… if he is at the water right now
then something is better than nothing."*

### The app already knows everything the screen should say

The handshake is twenty acknowledgements in five groups, and it knows, at every
moment, exactly which parameter has not come back. The log prints it already:

```
DEV_PARAM checking transSetup
DEV_PARAM transFreq OK as 710
DEV_PARAM transPulse OK as 10
DEV_PARAM transBoost OK as 0
DEV_PARAM onTransChanged is OK, let's move on
```

All of that is thrown away at the UI, which shows one string. Nothing new has to
be computed to say considerably more — group progress, and on a stall the name
of the group that is not answering.

### What a stall should say

Four groups carry anything a user would recognise (`dspSetup` and `soundSpeed`
are acknowledged by default):

| group | parameters | plain name — TO BE CORRECTED BY OLAV | what failing costs |
|---|---|---|---|
| `distSetup` | distMax, distDeadZone, distConfidence | Depth range | how deep it looks |
| `chartSetup` | chartSamples, chartResolution, chartOffset | Echogram detail | resolution and scale |
| `transSetup` | transFreq, transPulse, transBoost | Transducer | the cone / frequency |
| `datasetSetup` | ch1Period, datasetChart, datasetDist, datasetSDDBT, datasetTemp, datasetEuler, datasetTimestamp | What it sends | echogram, depth, temperature |

Only Olav can write the second and third columns properly — what a failed
`transFreq` costs a SAR crew is not what it costs an angler.

### The escape hatch

**"Use it anyway."** Offered when the app has enough acknowledged to draw a
picture — `datasetChart` acknowledged and data arriving — and what it forfeits is
whatever is still unacknowledged. If `datasetChart` itself is what will not go
through there is no echogram to offer, and the honest answer is to say so.

Mechanically it is small: leave the `*_ok` flags exactly as they are, stop
halting the echogram, and let `completeDeviceConfigurationTimer` keep retrying
quietly underneath. A parameter that lands later simply lands.

`devConfigured` stays FALSE, because it is the truth. The new fact is that the
user has accepted running without it.

### The rule that makes it safe rather than misleading

**An unacknowledged parameter means the app does not know what the device is
using.** So for anything unacknowledged the UI must show the DEVICE's value, not
the wanted one. If `transFreq` never lands, the cone selector must not read 710
while the transducer transmits at whatever it had — a surveyor logging a swath
at the wrong frequency, believing the number on screen, is a worse outcome than
no echogram at all.

That is the two rules again: the wanted value and the actual value are two
sources, so one of them gets the binding and the interface reads the one that is
true.

And it does not end at the overlay. Having accepted, the user keeps a quiet
standing marker — the same shape as the demo pill step 4 is getting, saying what
the app is rather than nagging:

```
Demo · PULSE blue                    PULSE red · 1 setting unconfirmed
```

### When to offer it

Not on a fixed timeout. `breakAndReconnectLinkTimer`'s ten seconds measured
elapsed time, which punishes a slow link that is making steady progress — and a
weak link is exactly the case the halt-the-echogram rule exists to protect.

Measure **progress, not time**: offer the hatch after N seconds in which no
acknowledgement has arrived. Same idea as `isAnswering` — movement rather than a
clock — and it means a Skydroid link crawling through the handshake is left
alone while a genuinely stuck one is caught quickly.

### Still open

- The plain names and the consequence wording, above.
- N, and whether the offer appears on its own or behind a "this is taking a
  while" line first.
- Whether the marker is dismissible, and whether accepting should be remembered
  for that device or asked again each session.

### Settled on the mockup (13 Sept 2026)

Four states drawn over the echogram and reviewed: *"The principles are OK…
I think we have a solution!"*

**The card grows as it has more to say, and collapses to a pill when it is only
reporting.** Quiet while setting up, a named progress list when it is slow, a
question with two answers when something will not go through, a standing pill
afterwards. The same principle as measuring progress rather than elapsed time:
the interface gets talkative exactly when it is struggling and no sooner.

**The wording, approved in principle.** *"Setting up PULSE red"* rather than
"Configuring transducer" — configuring is what we do, setting up is what a
person recognises. *"The picture is paused for a moment so the settings get
through"* — a frozen echogram looks like a fault unless the halt is explained.
*"One setting did not get through"* as the headline, then what still works, then
what to distrust, in that order, because someone at the water wants "can I fish"
answered before "what broke". *"Start anyway"* and *"Keep waiting"*, with *"It
keeps trying either way"* underneath, because it does.

**The mark on the control is a rule, not a drawing.** Olav: *"the inability to
change it should be visible as suggested, but not exactly like in the mock up…
we will have a different way to set it compared to my current UI design with
pill controls."* So what carries forward is the treatment and not the shape:

> A setting that did not get through shows the value the TRANSDUCER is using,
> never the one that was asked for, and the control carries a mark saying it
> could not be set.

The new UI settles what that control looks like. A surveyor logging a swath at
the wrong frequency while the screen reads 710 is worse off than one with no
echogram, which is why this survives whatever the control becomes.

**The standing marker is dismissible, and counts rather than names.** Olav:
*"let us also allow the user to dismiss it so he have less clutter on the
echogram screen… There may be more problems than just the cone."* So it reads
*"PULSE red · 2 settings not set"*, tapping it opens the list, and an × puts it
away.

Dismissing it is safe for one reason, and only that reason: **it dismisses the
reminder, not the truth.** The marks on the controls stay, so the reading can
never quietly become wrong because a pill was closed. Dismissal lasts until the
next setup pass — a swap or a reconfigure brings it back, because that is a new
claim about a new configuration.

**Still Olav's to write**: the four group names (Depth range · Picture quality ·
Cone · Echogram and readings as drafted — and "Cone" is right for red and black
but wrong for blue, so the name belongs in the profile record exactly as the
cards do), the no-progress interval, and whether accepting is remembered per
device or asked each session.

### The group names, and the strip's four states (13 Sept 2026)

**The names, settled by Olav — each one IS a category flag**, which is what
makes them cheap: the handshake already raises exactly these four.

| shown | flag |
|---|---|
| Depth range | `onDistSetupChanged` |
| Image quality | `onChartSetupChanged` |
| Cone | `onTransChanged` |
| Echogram settings | `onDatasetChanged` |

One thing left in it: blue has no cone choice, so "Cone" is wrong for a blue.
That puts the user-facing name in the profile record — the same move the cards
made in step 2, and for the same reason.

### The strip, proved wrong by a screenshot

Wifi off, the red *"Lost connection"* indicator up in the corner, and the strip
still green: *"Connected to PULSEred, 192.168.10.1, s/n 139"*. Olav: *"we do
know that an existing dataflow has stopped, and that this kind of is not
matching a green 'Connected to…' rather than a gray 'Was connected to…'"*

**Two indicators on one screen disagreeing, reading two different facts.** The
corner overlay reads `hasDeviceLostConnection`. The strip reads

```qml
linkLost: hasDeviceLostConnection && didEverReceiveData
```

and the force reselection had just cleared `didEverReceiveData`. So the strip's
"lost" branch was unreachable, it fell through to `linkOpen && linkNamed` — both
stale — and reported a live connection over a dead link. Exactly the drift the
analysis predicted, caught on a screenshot rather than argued from the code.

**Four states, and Olav's past tense is the one that was missing.**

| | when | dot |
|---|---|---|
| Connected to PULSE red | data arriving now | green |
| Connection lost | a model is committed and the data stopped — we expect it back | amber |
| Was connected to PULSE red | the data stopped and nothing is committed — the identity is history, not a claim | gray |
| Not connected | nothing has presented itself this run | gray |

Green is a claim about NOW, so it needs `isAnswering` and nothing else. The two
middle rows are the two silences: which one you are in is decided by
`committedModel` and `awaitingUserChoice`, so the strip still needs no state of
its own.

The third row is the one the old machine could not express, and it is the better
answer to the step 1 wording note as well — *"Not connected"* was never wrong
about the socket, it was wrong about what the owner had.

### Noticed in the same screenshot

The strip's detail line reads `192.168.10.1   fw   s/n 139` — an empty firmware
version. `linkDetail` skips the field only when `rawDev_firmwareVersion` is the
string `"not set"`, so an empty value prints the label with nothing after it.
One line, whenever the strip is next touched.

---

## Reconfigure the transducer, and the zero it uncovered (13 Sept 2026)

The first of the six agreed changes, built alone on Olav's instruction — one
commit to the device, one idea to judge.

### What it is — `f22593a2`

`reconfigureNow` re-runs the parameter handshake on the model that is **already
committed**: `resetAllSetupStates()` and then `configurePulseDevice()`, which
halts the echogram for the handshake exactly as a first setup does. Nothing is
un-committed, so there is no `"..."` window — no connection screen over a
working echogram, no re-opened detection question, no stale device list
answering it, and no blue window. Defect B's path is not guarded against here;
it does not exist.

Exactly one handler reads the flag and it clears it **before** doing any work.
Item 10 was two handlers on `swapDeviceNow` where the first cleared it and
re-entered the signal, leaving the second looking at a flag already false.

Added **beside** "Force reselection of device" rather than replacing it: that
control is what becomes "Choose a different transducer" when
`awaitingUserChoice` is built, and taking it away now would remove the one
control the bench testing runs through.

### The first device run failed, and the second did not — `74bb45bd`

Same action, two runs, identical through the entire handshake, differing in one
number:

```
run 1 (broke)   chartResolution OK as 0 . We set it dynamically for 2D anyway
run 2 (worked)  chartResolution OK for PULSEred as 2
```

and run 1 carried, before anything else:

```
chartResolution: dev.chartResolution !== pulseRuntimeSettings.dynamicResolution. Enforce!
```

**`resetAllSetupStates()` writes `dynamicResolution = 0` on every reset**,
meaning *nothing has been computed yet*. That write fires
`onDynamicResolutionChanged`, which finds `dev.chartResolution` (2) different
from `dynamicResolution` (0) and enforces the zero onto the transducer. A chart
resolution of zero stops the echogram dead.

**Two things kept it hidden.** The swap path clears `doDynamicResolution`
*before* resetting, so its early return swallows the zero — which is exactly why
run 2 worked, a force reselection having just turned dynamic resolution off. And
`chartSetup()` accepts any `dev.chartResolution` while dynamic resolution is on
(*"we set it dynamically for 2D transducers anyway"*), so the handshake blesses
the zero instead of catching it: `DEV_PARAM_COMPLETE` then reports
`chartResolution is 0` as a successful setup.

`f22593a2` did not introduce this. It was the first caller to reset while
dynamic resolution was still running, which was all it took.

The guard is on the **enforcer**, not on any caller: every reset passes through
that handler, so a guard there covers the callers that exist and any future one.

**Confirmed on device**: reconfigure works, and separately — writing a real
resolution from the expert settings brought a stuck echogram back **without a
power cycle**. Worth knowing in the field: a dead echogram after a bad
configuration may only need a resolution written.

### Left open by this pair

- **`chartSetup()` cannot catch a bad chart resolution at all** while dynamic
  resolution is on. That blanket accept is the reason a zero was reported as
  success, and it is a second defect and a second commit.
- **A force reselection with a live transducer still jumps straight back into
  the echogram.** Not a new break: `f2aafa11`'s gate lets a re-commit through
  when the device is answering, and after a reselection with a live device it
  is. `awaitingUserChoice` is what fixes it, and it is next in the order.
- **The expert checkbox needed two taps once.** If it repeats, the auto-clear
  timing on `SettingsCheckBox` is the suspect.
- **The setup is a fan-out, not a function.** `configurePulseDevice()` is one of
  several subscribers to `onUserManualSetNameChanged` — DistProcessing, the
  fixBlackStripes trio, HorizontalController's auto function, Plot2D's
  EchogramCompensation and the cone/view restore are others. Reconfigure calls
  only the one. It is sufficient for a parameter re-push, which is what this
  action promises, but "re-run the whole setup" would need its own broadcast.

---

## Steps 2 to 5, built and confirmed (13 Sept 2026)

One idea per device build, on Olav's instruction. Five of the six are in.

### Step 2 — the user is choosing, and detection must not answer — `d369d98f`

`awaitingUserChoice` separates the two states that were one. "The app does not
know what is on the wire" and "the user has asked to decide" were both
`userManualSetName === "..."`, and they want opposite behaviour.

> commit a model when a device is identified in the list, **and** data is
> arriving, **and** nothing is committed, **and** the user is not choosing.

**Data arriving became a trigger, and that is the half `f2aafa11` was missing.**
Its gate was never wrong — it was never *consulted*, because nothing re-ran
`selectCorrectDevice()` when a quiet transducer started talking again. That is
why the echogram was visibly moving behind the scrim with nothing committed. The
trigger was held back until `awaitingUserChoice` existed; without it the first
frame after a reselection would have re-committed and closed the screen.

`everCommittedModel` is gone — the transducer free-runs, so the rule needs no
exemption. The expert control became **"Choose a different transducer"**, and
`swapDeviceNow` is no longer asked to MEAN anything.

Confirmed: *"All seems to be working."* Plus a cold start still auto-selecting,
and a wifi drop with a model committed recovering by itself with no screen.

### Step 3 — the band-aid retires — `89b7d2c6`

One mechanism, so one commit: the overlay's visibility is what ARMED the ten
second timer. `dataUpdateActive` — a one-way latch never lowered, named like a
live state, with this overlay as its only reader — became `isAnswering`. Gone
with it: `breakAndReconnectLinkTimer`, the *"Fixing transducer com link…"*
escalation, `ConnectionViewer`'s `onUnableToConfigureChanged` trigger, and the
`unableToConfigure` flag.

Confirmed: the overlay appears briefly and goes, with no escalation. That string
never showed again.

### Two defects the testing found

**A lost connection is data stopping — `0e2e6ef4`.** Break the wifi at the
moment of commit and the echogram stayed off. `hasDeviceLostConnection` was
raised only if `didEverReceiveData`, which every reset clears and only
`onDevNameChanged` raises — so after a reselection, same transducer, same name,
it stayed false. And `onHasDeviceLostConnectionChanged`'s "regained" arm is the
**only** thing that restarts `completeDeviceConfigurationTimer`. No raise, no
fall, no resumed configuration. Now keyed on data having been arriving, which no
reset can wipe.

The tell was in Olav's own report: the runs that recovered showed the
lost-connection warning, and the failing one never did.

**The box can be taken down again — `a0f44ff9`.** Both arms of that handler sat
behind the same flag — the show *and* the remove — so a reselection after the box
went up left it on screen through a regained connection, a new choice and a
complete reconfiguration.

**Not reproducible afterwards**, and recorded as *may still exist*: four
attempts at the original failure all recovered. Olav's own theory is the likeliest
— with the transducer never power-cycled, every value is already correct and the
handshake runs too fast to catch.

### Step 4 — `"..."` is not blue, it is no device — `957032cc`

The root of defect A, and only the log showed it. Between a reset and the next
commit the resolver fell through to blue, so every binding on `committedProfile`
snapped to blue's numbers — and those are written to the transducer. A red spent
the window configured as a side scan at 25 m instead of 50.

So the four symptoms after an accepted swap were never four regressions. They
were four values read or assigned inside a window in which the whole app believed
it was a blue.

`"..."` is not an unrecognised device — that case is a real question worth
guessing at, and keeps its channel-count fallback. `"..."` is NO device, and the
honest answer to "I have not been told yet" is to change nothing, so it holds the
last model this run knew about. The cold start is untouched: nothing to hold, and
blue remains the right guess.

Confirmed from the log, which is the only place it shows:
`PROFILE: committed key -> PULSEred | model ...` where it used to say `PULSEblue`.

### Step 5 — the strip has two silences — `655c3aff`

Green is a claim about now, so it reads `isAnswering` and nothing else. And the
two silences are different questions: a model committed and the data stopped is
**"Connection lost"** (amber, we expect it back); nothing committed and the data
stopped is **"Was connected to PULSE red"** (gray, the identity is history).

Confirmed on device: green while live; gray when the wifi goes before or during
the connection screen; back to green when it returns with the screen still up;
*"Not connected"* on a cold start with nothing powered.

**Amber has one reachable route today, and that is worth knowing**: the screen
only shows while it is asking something, and the only question it asks with a
model still committed is a pending device swap. So amber needs two transducers
until the rail's source button exists — and then it becomes the common case,
because that button is a door into this screen with a model committed. It is
built for a door that has not been hung yet.

A lost connection does NOT raise this screen, and must not: `chooserAsking` has
no lost-connection term. Coming here deliberately with the link down is the gray
state, which is what Olav observed.

### Decided: the spinner does not come with us

The `LostConnectionOverlay` — the red spinning wheel and its three strings,
*"Hang on ...."*, *"Lost connection"* and *"Unknown device"* — is part of the old
struggle-to-configure machinery and is not carried into the new UI. Olav: *"We
already have a design to reveal to the user what is going on during setup and
potential problems. So this should go away anyway."*

It stays for now only because it is the classic UI's one signal, and removing it
before the replacement exists would leave nothing. The replacement is two things,
both already designed: the strip's amber **"Connection lost"** for the connection
screen, and a new warning over the echogram for a drop during use.

---

## Step 6 — the setup screen, built in two halves (13 Sept 2026)

### Part 1 — the card says what it is doing — `2c66a3c5`

`PulseSetupOverlay.qml` is a new component, registered in `qml/qml.qrc` and
instantiated **once in `main.qml`**. That placement is the point. The thing it
replaces, `configurationInProgressIndicator`, lived inside `PulseAppClassic.qml`,
which `Plot2D.qml` instantiates **per pane** — so a split view drew two of them,
one over the other, both animating. Lifting it to `main.qml` fixes a latent
double-draw and two inset bindings that could not be resolved from inside a pane.

The four groups Olav named are read straight off the category flags; nothing new
is computed. Progress is the count of the sixteen `*_ok` acknowledgements.

The card **earns its words**. Quiet for the first `talkativeAfterMs: 2500` — most
setups are over before it says anything at all — then the named list, and only
after `stalledAfterMs: 6000` **with no acknowledgement arriving** does it name
the group that is not answering. Six seconds of silence, not six seconds
elapsed: a slow link making steady progress is left alone, which is the whole
reason `breakAndReconnectLinkTimer`'s ten-second clock had to go.

Confirmed on device, together with the first reproduction of the failure below:
*"The newly built part works."* Two notes taken: **the fonts and sizes are a
little tight and want a phone test**, and — the real value — *"we may finally
have insight in what CAN happen in case of wifi loss during setup."* The screen
that was built to explain a stall was what made the next defect visible.

### The echogram that would not restart, and what it taught — `785405c0`, `22dee3bf`, `f522a4b4`

Break the link **during** configuration and the echogram never came back. Three
commits, and the first two were wrong in the same instructive way.

`785405c0` guarded the pause on `isAnswering` and restarted
`completeDeviceConfigurationTimer` when the link was lost. Necessary, not
sufficient.

`22dee3bf` applied what looked like the established rule — do not trust a
parameter until the device confirms it — and verified `datasetChart` against
`datasetChart_Copy`. Olav's log killed it:

```
device reports 0 - telling it 1 again
... link dies ...
CONFIRMED BY THE DEVICE as 1
```

**The confirmation is an echo one signal later, not proof.** And the guard built
on it was holding the circle shut: the app was waiting for a confirmation that
could only arrive on data that the app was refusing to ask for.

`f522a4b4` is three lines and does one thing: **into silence, keep telling the
transducer to send the echogram, and nothing else.** Olav: *"Works."*

The finding underneath is worth more than the fix. **No property on the app side
proves the echogram is on.** `dev.datasetChart` takes the write immediately;
`datasetChart_Copy` follows one signal later, which on a dying link is one signal
that may never come. In this one direction **the data IS the acknowledgement** —
frames arriving is the only honest proof.

That matters because it is the same rule the escape hatch below is built on:
*show the DEVICE's value for anything unconfirmed*. The rule is right, and it
still cost two commits here, because `datasetChart_Copy` looks exactly like a
device value and is not one. Where the device's answer is the data itself, no
copy property can stand in for it.

### Part 2 — the escape hatch — `82db3303`

Six seconds of silence turns the card from narration into a question: **"One
setting did not get through"** — or *"Some settings…"* for more than one — with
the consequence in the user's terms, not ours:

> You will still get the echogram, the depth and the temperature. That setting
> stays as the transducer last had it, so what the screen shows may not be what
> is in the water.

**Start anyway** (amber) and **Keep waiting** (outline, which simply restarts the
stall timer), under one line that removes the fear of choosing wrong: *"It keeps
trying either way."*

`runUnconfirmed` means exactly one thing — **stop halting the echogram while we
wait**. It is not a configured state: `devConfigured` stays false, every `*_ok`
stays where it was, and the timer keeps pushing in the background, so a parameter
that lands later simply lands. The only change in `DeviceItem.qml` is that the
pause branch is skipped and `datasetChart` kept asserted.

**A fresh setup never inherits it.** `configurePulseDevice()` clears
`runUnconfirmed` before anything else, so the next transducer, the next
reselection and the next reconfigure all start from waiting again. The choice is
about this situation, not about this user.

Afterwards the card is replaced by a standing marker — `PULSE red · Cone not
set`, or `PULSE red · 2 settings not set` — carrying the caveat onto the echogram
screen rather than hiding it. Olav asked for it to be dismissible, and his reason
is the right one: *"There may be more problems than just the cone."* The marker
has done its job once it has been read; after that it is clutter, and clutter on
the echogram screen costs more than the reminder is worth.

### Confirmed on device, and the test rig Olav built to do it

*"This seems to be 100 % according to the design!"*

The hatch had no honest test: breaking the wifi stalls everything at once, which
is not the case the hatch is for. Olav made the real one by **commenting out a
single acknowledgement** in `datasetSetup()`:

```qml
pulseRuntimeSettings.ch1Period_Copy = dev.ch1Period
// TEST CASE - FAILED SETUP: disable this to trigger a failed setup
//pulseRuntimeSettings.ch1Period_ok = true
console.log("DEV_PARAM ch1Period OK as", dev.ch1Period)
```

One parameter never acknowledges on a **healthy** link, while every other group
completes normally — which is exactly the situation the escape hatch was
designed for and the only way to reach it deliberately. **This is the rig for
every future change to the card.** Any of the sixteen `*_ok` lines works; the
group it belongs to is the group the card names.

All four behaviours confirmed in one run: the question appears; **Start anyway**
starts the echogram; **Keep waiting** returns to waiting and the question comes
back; accepting leaves the marker top-left; the × dismisses it. And Olav's last
observation is the one that proves `runUnconfirmed` is honest rather than a
shortcut — *"my timer keeps banging trying to fix the problem"*. That is
`completeDeviceConfigurationTimer` still pushing the unacknowledged parameter
underneath a running echogram, which is precisely what *"It keeps trying either
way"* promises the user.

### A note on the commit trail

`7b7c4beb` — *"docs(pulse-ui): handover — V2 starts here, and one correction"* —
**carries no handover.** For this file its diff is an exact inverse of `cc05867c`:
same thirty-three lines, every sign flipped. It removed the section above rather
than adding anything, and the write-up its message promises never reached disk.

The mechanism that fits is a full-file rewrite from a copy taken before `cc05867c`
landed — everything written in between disappears silently, and if the new text
also fails to make it in, the net commit is a pure revert wearing a misleading
message. On a document this long that is invisible in review.

**So: patch this file by anchored replacement, never by rewriting it whole.** And
the rig above is deliberately written down twice — here, and as a comment in
`DeviceItem.qml`'s `datasetSetup()` — because it was lost once already.

### What part 2 still owes

- Whether "Start anyway" should be **remembered per device** or asked again each
  session — still open, and deliberately not decided by this commit.
- The **per-group consequence wording**. One sentence covers all four groups
  today. What a failed `transFreq` costs a SAR crew is not what it costs an
  angler, and only Olav can write those four lines.
- The marker's **name for the group** is the display name, so blue's missing cone
  choice lands here too: the user-facing group name belongs in the profile
  record, the same move the cards made in step 2.

---

## Stage 4 (a) — the control surface, built (13 Sept 2026)

`feature/device-profiles-step4` merged to `master` as a fast-forward first — 71 commits,
`392fd124..3b0a9abe`, all device-confirmed — and this work is `feature/pulse-ui-v2-rail`
cut off that.

| Commit | What |
|---|---|
| `3b0a9abe` | the failed-setup rig, kept as a comment in `datasetSetup()` |
| `418b023e` | the rail, its tier-1 buttons and the source button |
| `3fa3ea49` | the rail keeps a floor under the Android status bar |
| `f165d46c` | the rail collapses, and comes back |
| `f4e05e07` | the collapsed tab used Qt 6.7 per-corner radii — the crash |
| `d30511b7` | `tools/pulse-qml-version-check.js`, so that class of crash is static |
| `80de2e28` | the source button's icon is white like the rest of the rail |
| `f477a318` | the rail takes its width from the picture rather than covering it |
| `5dead674` | the escape-hatch confirmation restored, and the commit trail noted |
| `bea0207f` | this section |
| `f7940d10` | the link's one honest line becomes a fact of the app |
| `b6870c50` | the source button shows what the link is doing |
| `949113a2` | the setup card respects the rail's width |
| `9550f366` | the pill says what the echogram is, and how to leave it |
| `34afc57f` | recording asks, in both directions |
| `a86338e8` | the Record button was drawing black on a black rail |
| `2bcee29c` | collapse and its drawer tab were invisible for the same reason |
| `8e98e48a` | `tools/pulse-icon-check.js`, so that class is static too |

### The fork is answered: the late-September exhibition runs on the CLASSIC UI

This reverses the recommendation the previous session recorded, and it is worth saying why,
because the reversal is not a change of judgement — it is a premise that turned out to be
false.

The old argument was: *if the stand runs classic, the demo indicator, the stop button and
the file-open have to be built into `PulseAppClassic` and then thrown away.* They do not.
All three already exist on the classic path:

- the demo indicator is `demoModeBadge` in `PulseAppClassic.qml`, and since backlog item 8
  it already names the presented device — `Demo · PULSE blue`, the exhibition claim made
  visible;
- file-open is **"Start a simulation"** on `PulseConnectionScreen`, built and confirmed;
- stop is the Recording tab, and `exitDemoMode()` — reopen the links, re-run detection — is
  the part that was hard, and it works.

What V2 (a) adds over that is **vocabulary, not capability**. At an unattended stand nobody
is admiring the vocabulary. With the premise gone, the rest follows:

1. *"Risk is bounded, `uiVariant` falls back to classic"* needs a person. It is a one-switch
   recovery and the switch lives in expert settings inside the UI that would be
   misbehaving. Olav will not be there. A bound that depends on a hand is not a bound at
   this stand.
2. **4 (a) is the control surface with no settings panel.** On V2 nobody at the stand could
   change colour, range, intensity or filter. An aquarium exhibit where a visitor cannot
   touch the range is a worse exhibit than one where they can.
3. **The device time between now and late September is already spoken for** — the boat run
   covers the swap prompt, item 10's re-test and the `PULSEblue-IP` acceptance test. Putting
   V2 on the stand makes every remaining V2 commit exhibition-critical, which is exactly the
   pressure that produces the mixed commits this process exists to prevent.

The honest case for V2 is that the stand is the publicity moment and the new UI is the
differentiator against Garmin. But what sells a new UI is a person driving it, and there
isn't one; unattended, the stand mostly shows a moving echogram, and classic moves it just
as well. **What follows: V2 is built on its own branch with no deadline on it, which is the
condition under which one-idea-per-commit actually holds.**

**One exhibition risk stays, and it belongs to classic rather than to V2.** If a parameter
group stalls at an unattended stand, the setup card asks *"Start anyway / Keep waiting"* and
nobody answers it — the echogram stays halted for the rest of the day. Worth deciding
whether that question should take itself after a few minutes. Recorded, not scheduled.

### The correction that still stands

The **rule-2 presentation sweep is not a task to schedule** — it is a constraint on how V2
is written. The assignment sites that cause defect A live in the controls V2 replaces
(`colorMapIndexReal` is assigned six times inside the classic colour chooser; the max-depth
ceiling is backlog item 11). One binding on the profile plus one explicit override, never an
assignment, applied as each control is built. Same reason **items 11 and 12 stay parked on
V2**: they come off the shelf inside the control they belong to, and not before.

### What 4 (a) contains

The rail, tier 1 only: Colours · View/Cone · Max range · Intensity · Water body filter ·
Pause & inspect · Record, then the source button, Settings, collapse, the way back to
classic, and the wordmark. **The panel the tier-1 buttons open is 4 (b)**, the larger half,
so five of them emit and log. Drawn but inert rather than omitted, because this slice is the
surface and its geometry, and a rail missing buttons has the wrong proportions to judge on a
device.

**Two are live, and neither needed a panel.** The source button is the permanent door to the
connection screen. Record is the other, because it has no value to set - only a state to
enter - and it asks rather than toggles. The pill column carries the rest: what the echogram
IS, and the way out of it.

Not in it: the settings panel and every tier-2/3 group; split screen and the "Both, split
screen" view option; per-pane range and the per-pane state object; compression of the
echogram by anything other than the rail; the paused-and-inspect mode, which is mostly
`plot2d_aim` and `plot2d_zoom` in C++ rather than QML.

### The rail's two masters, named rather than blurred

This is rule 1 as it applies to a control surface, and getting it wrong here is how defect
A's whole family recurs.

- **Which buttons exist** reads the **committed** profile — `offersViewChoice` /
  `offersConeChoice`. A chooser offers HARDWARE choices; you cannot change the cone of a
  transducer you do not have. Absent rather than greyed out, which the profile map already
  says by never offering a choice of one.
- **Everything drawn about the picture** reads `displayIs2DTransducer`. With a blue log
  presenting on a committed red, the rail must not say "cone" over a side scan.

Nothing in `PulseRail.qml`, `PulseRailButton.qml` or `PulseAppV2.qml` reads `is2DTransducer`,
and nothing in them should ever start to.

### One binding, one override — and the third way out

The connection screen's visibility now has two sources: the app's own `chooserAsking`, and
the user, because the source button is the permanent door that backlog item 9 never had. So
it is ONE binding over both and ONE override, and **nothing anywhere assigns `visible`**:

```qml
readonly property bool userAsked:
    pulseRuntimeSettings ? pulseRuntimeSettings.connectionScreenRequested : false
readonly property bool screenShowing: chooserAsking || userAsked
visible: screenShowing
enabled: screenShowing
```

The override lives on `pulseRuntimeSettings` rather than on the screen, for the reason
`enterDemoMode()` lives there too: `PulseConnectionScreen` is instantiated in `main.qml` and
**QML ids do not cross files**, so a root context property is the only route from anywhere
else.

**There are three ways out, not two.** `commitCard()` and `keepCurrent()` were the obvious
pair. Starting a simulation is the third — it is on that screen — and left alone, a screen
the source button raised would have stayed up over the replay it had just started.
`enterDemoMode()` clears the flag beside `awaitingUserChoice`, which is the same class of
thing for the same reason: starting a simulation is an answer.

**`canGoBack`, beside `canCancel`.** The case `canCancel` cannot answer is the screen opened
by hand over a running demo with nothing ever committed: `canCancel` is false, so there was
no cancel button, and the source button would have been a trap. `canGoBack` is
`canCancel || (userAsked && !chooserAsking)` — gated on `!chooserAsking` deliberately, so
when the app genuinely needs an answer there is still no way out but a choice, and no button
appears that would leave the screen up.

### Where the control surface lives, and why it could not stay in `PulseAppV2`

It was built inside `PulseAppV2` and moved to `main.qml` on the first device build, and the
reason generalises well past the rail.

**`qPlot2D` paints the echogram across its entire item, and `PulseApp` is that item's
child.** There is no render-rect or margin property on it. So nothing built inside `Plot2D`
can take width from the picture — it can only cover it. **Everything the edge-rail direction
does by compressing the echogram rather than covering it must therefore be the panes'
SIBLING**, and that is as true of the sliding panel in 4 (b) as it is of the rail. Better to
learn it from sixteen lines now than from the panel later.

The whole of the compression is one line on the pane `GridLayout` inside `plotsContainer`:

```qml
anchors.leftMargin: pulseRail.visible ? pulseRail.inset : 0
```

Zero in classic and zero while collapsed, both through the rail's own `inset`, so there is no
second mechanism to keep in step. Two things came free: the per-pane gate goes — one rail
above both panes, the way `PulseConnectionScreen` and `PulseSetupOverlay` already are, so a
split screen stops drawing two of them without anything about split screen being touched —
and because the rail sits *inside* `plotsContainer` rather than at the foot of `main.qml`
(anchors reach only a parent or a sibling), it never intrudes on the 3D pane.

Olav's first instinct was to keep `main.qml` untouched for upstream-merge safety, and then
his own correction: *"It is a separate section anyway that the upstream author cannot
hamper."*

**`PulseAppV2` now draws nothing.** It keeps the variant contract and the platform helpers,
because what lands there next is everything that genuinely belongs ON the picture and takes
no width from it: the readout, the indicator stack, and the paused crosshair and loupe. The
helpers are declared on the ROOT of that file on purpose — the pre-existing defect in
`PulseAppClassic`, where four alert blocks bind `insetTop()` from outside the sibling that
declares it, cannot recur by construction.

### What the device found

**1. The insets.** The top rail button sat half under the Android clock. `safeTop` arrives
as zero on an ordinary tablet because `main.qml`'s `insetTop()` answers 0 unless DeX is on —
the app draws full-bleed under the status bar deliberately, since an echogram wants every
pixel. Right for the picture, wrong for a control. Same floor and the same 34 du constant as
`PulseConnectionScreen`, which met this first when its header sat under the clock in a split
screen. The two surfaces must agree or the rail and the screen it opens sit at different
heights.

**2. The rail covered the picture.** Olav: *"Must be avoided, echogram to cover the remaining
part of the screen."* That is the compression above. His own scoping of the cost is worth
keeping: *"Having the entire echogram available albeit some controls on the screen is
valuable. The SAR users tend to use huge tablet hardware anyway."* — **phone size in portrait
is another matter entirely**, and it is the open half of the rail question. The canvas
already answers it differently: portrait drops the rail for a dock plus a bottom sheet at two
heights, because 76 du off a 390 dp screen is a real bite and because the drop-back rule
needs vertical space, not horizontal. Nothing built so far commits either way — `PulseRail`
takes its geometry entirely from properties.

**3. Collapse and leave read as one thing when they share a glyph.** The arrow at the foot
was tapped expecting the rail to get out of the way; it left V2 entirely. They no longer
share one: `pulse_setting_collapse` hides the rail, `pulse_arrow_left` still returns to
classic. Collapsed, the rail is 30 du of drawer handle vertically centred on the left edge —
without it, collapsing would not hide the rail but lose it, because the state is persisted
and the only way back would be a restart. `pulseSettings.v2RailCollapsed` is its own key
rather than `areUiControlsVisible`: that one hides the classic quick controls, and one value
driving two interfaces is how a user ends up in classic wondering where his controls went.

**4. The app would not start** — and this is the one worth keeping.

```
qrc:/PulseRail.qml:115: "Rectangle.bottomRightRadius" is not available in QtQuick 2.15.
```

**`import QtQuick 2.15` pins the TYPE version whatever Qt the app is built with.** A Qt 6.7
property on a 2.15 `Rectangle` does not warn — the type fails to load, and every file that
instantiates it fails with it, up to `main.qml`. The QML root object is null and the app
dies at startup.

Nothing the sandboxed shell was doing could catch that: braces balanced, the qrc parsed,
every icon was on disk. So `node tools/pulse-qml-version-check.js` now reads each file's own
declared import and flags version-gated API against it. It fails on the exact two lines that
died, which is the only test that matters for a checker. **Run it beside
`pulse-profile-check.js` after any QML change.**

It also found one pre-existing case: `Scene3DToolbar.qml:111` uses `HoverHandler` (2.15)
under `import QtQuick 2.12`. The app starts today, so Qt is not refusing it there; the fix is
a one-line import bump in a file PULSE does not own and belongs with the next upstream merge.
Recorded in `KNOWN` at the top of the checker rather than fixed, so the tool stays usable as
a gate.

**5. Three controls were invisible, not missing.** *"I do not think I have a record button at
all."* It was there the whole time, and tappable. **An SVG that states neither `fill` nor
`stroke` draws BLACK**, because that is SVG's default - and on a `#cc0f1317` rail that is not
a wrong colour, it is a control nobody can see. `pulse_recording_inactive.svg` is one such
file; hunting it turned up `pulse_setting_collapse` and `pulse_setting_show` in the same
state, which is exactly why neither the collapse button nor its drawer tab had been reported:
neither could be seen to be tried.

The Record button now uses `pulse_recording_mini` (white) and keeps the red
`pulse_recording_active` for when it IS recording. Collapse and the tab get
`pulse_rail_hide` / `pulse_rail_show` - white, and pointing sideways, which is the direction
a rail on the left edge actually moves; the old pair pointed up and down.

`node tools/pulse-icon-check.js` asks one question of every icon the dark-surface QML names:
does it say what colour it draws in? Not WHICH colour - white on the rail, red while
recording and the coloured device badges are all correct; only silence is wrong. It is scoped
to the dark surfaces on purpose, because the settings popup draws on a light ground where
black is right, and six of its icons are colourless and always have been fine there.

Worth recording how close that tool came to being useless: the first draft matched only
`fill="..."` and called two thirds of the icon set broken, because the Fabric.js exports in
this repo state their colours in `style=`. **A checker that cries wolf is worse than none**,
and the test that saved it was the same one the version checker has - it must fail on the
exact file that failed on the device, and pass on everything that did not.

### Two smaller things, recorded rather than fixed

- `resources/icons.qrc` lists `icons/app/kogger_app.png` and `icons/ui/tool.svg` twice.
- The classic on-screen recording indicator is a live example of the defect V2 is designed to
  make impossible: `recordingOnScreen` has `visible: isRecordingKlf` **and** a `Connections`
  handler that assigns `recordingOnScreen.visible`. The binding is destroyed the first time
  recording is toggled; it only looks fine because the assignment happens to write the same
  value. It is also a one-tap stop with no question — which is the control the pill replaces.

### Confirmed on device

Five builds, in this order, and every line below is Olav's verdict rather than an
expectation.

- **The rail, the source button, the tier-1 logging.** *"Great start."* Every button tap
  produced its own "panel arrives in stage 4 (b)" line.
- **The insets, and the echogram taking the rest of the width.** Both passed on the rebuild.
- **The source screen and the dot.** *"The source page behaves like it did. The dot for the
  source button works like it should (at least green and yellow/amber)."* The hoist was
  invisible, which is what a pure motion commit is supposed to be.
- **The setup card respecting the rail.** Passed.
- **The pills.** *"Pill demo and pill file open: Works. Closing both sets up the live
  transducer again."* That last clause is the one that mattered: `exitFileView()` is not a
  copy of the demo path, and closing a file puts the picture straight back on a live,
  configured transducer without sending it round the setup pass again.
- **Recording, both questions.** *"Works as agreed. Nice to have the question and ability to
  abort when wrongly pressed."*
- **Hide and show the rail.** Works.

**Still unproven, and cheap to fold into the next run:** the GREY dot, which needs a log
carrying the picture with nothing committed - force reselection, then Start a simulation from
the screen it raises. It is nearly unreachable otherwise, because grey means nothing is
committed and that is also when the connection screen is up covering the rail.

### Backlog, added this session

**Opening a file freezes the UI, and playback already knows how not to.** Olav's idea:
`core.openLogFile` blocks while playback ships one epoch at a time at a set pace — so burst
through at far less than one epoch per 50 ms and let the echogram emerge incrementally
instead of making the user wait on a frozen screen. *"But as a next step, to be considered."*

### Still open, unchanged

- **The boat run**: the swap prompt on hardware, item 10's bench re-test, and the
  `PULSEblue-IP` acceptance test. One session on the water covers all three.
- **The per-pane state object** — still the only thing blocking split screen and the
  "Both, split screen" view option, and still undecided.
- **The four per-group consequence sentences** for the setup card. Olav's to write, and the
  right moment to ask is when the card is next touched.
- **Phone portrait**, per finding 2 above.
- Backlog 11, 12 and 13 stay parked.

---

## Stage 4 (b), step 1 — the panel, and Colours (13 Sept 2026)

Tablet first and Colours first, on Olav's call: *"that will give a good impression of how
everything will work."* Phone comes after, and the drafts for it are carried in the design
as we go rather than built.

| Commit | What |
|---|---|
| `cd072551` | the palette becomes one binding and one writer |
| `d6c85cde` | the panel, and Colours in it |
| `d772a847` | `displayThemeId` read two keys it does not own |
| `dc6684d3` | the colour rows draw the real ramp |

### Three colour keys, six writers, seven handlers

The research before the design is what made this step worth doing at all.

| Key | What it is |
|---|---|
| `colorMapIndexSideScan` | **blue's own preference** — an index into `themeModelBlue` (6) |
| `colorMapIndex2D` | **red's own preference** — an index into the master `themeModelRed` (20) |
| `colorMapIndexReal` | the **shared applied theme id**, published to the C++ over the settings bus |

The classic chooser assigns that third key from **six** places and needs **seven** handlers to
keep it honest. V2 replaces all of it with `displayThemeId` — ONE binding over the two stored
preferences and the display model — and one handler in `main.qml` that acts on it and is the
only writer of `colorMapIndexReal`. None of the seven has an equivalent: nothing has to be
visible for the value to be true, the display model changing re-evaluates the binding, and
neither chooser can reach the other's key.

It also talks to **both panes**, which classic never did — the classic chooser lives inside
`Plot2D` and speaks to its own `plot`, so a second pane kept the previous palette.

### Two defects this step produced, and what each cost

**1. A binding that read two keys it does not own.** `colorMapIndex2D` and
`colorMapIndexSideScan` live on `pulseSettings`, not on `pulseRuntimeSettings`, and were
written unqualified. An unqualified name an object does not own resolves to nothing, so both
terms arrived `undefined`, the range test failed, and the binding sat permanently on
`model[0]`. Olav's screenshot said so exactly: *"Blue"* is `themeModelBlue[0]`, highlighted
and immovable. **`themeIdAt` now logs when it falls back** — the silent version is what hid a
completely dead binding for a whole device build.

**2. The rows were stretching a badge.** The theme art is not a ramp; it is an oval with the
vendor's initials in it, and pulling one to 3:1 squashed the oval. Olav: *"Need to keep the
aspect ratio of the bullets. Or — optional, as suggested in a design render, to offer the
color spectrum."*

**The spectrum, and it needed no new C++.** `qPlot2D::echogramThemeStops(int id)` is already
`Q_INVOKABLE`, returns the renderer's own colour table for ANY id as `{pos, color}` stops, and
had never been called from QML. Every row now paints that table, so it shows the palette the
echogram will be drawn in rather than a picture of it — and there is no aspect ratio left to
preserve, because a ramp is supposed to fill its frame. The badge survives as the fallback for
an id the table does not answer for. The tables are read once at startup: they are compiled in
and cannot change while the app runs.

### Open — blue is getting red's themes and favourites

Olav, on the working build: *"the pulse blue gets the pulse red color choices and favorites.
Legacy solution had separate colors for blue. In preparations for the UI changes that got
messed up along the way."* Deferred by his call, to keep the rail and panel growing while the
testing is cheap.

**What the deferral should NOT look for, because it is already answered.** The V2 path cannot
cause this: `pulseBlue` carries `is2DTransducer: false`, so `displayIs2DTransducer` is false
for a blue, `displayThemeModel` resolves to `themeModelBlue`, `offerFavourites` is false, and
`colorMapIndexSideScan` has exactly ONE writer in `main.qml` — gated on the same term. Neither
chooser can reach the other device's key by construction.

So it is one of two things, and **the log line added with the fallback fix tells them apart**
without a build:

```
THEME: display theme -> <id> | 2D or side scan | stored index <i>
```

- If a connected blue says **2D**, the display model is answering wrong and the fault is
  upstream of colours entirely — it would equally affect the pill's corner and the ruler.
- If it says **side scan** and the picture is still red's palette, the STORED value is
  corrupted: the legacy 2D selector used to write a position from the red list into the other
  device's key, and a wrong index survives a restart. That is a migration, not a binding.

Either way the answer starts from one log line rather than from the code.

## Stage 4 (b), steps 2–5 — the rest of tier 1 (13 Sept 2026)

Five commits finished the seven tier-1 rail buttons. Each was built, put on the device, and
confirmed by Olav before the next one started; the notes below are what each one found, not
what it intended.

| Commit | What |
|---|---|
| `a0148596` | intensity and the water body filter, on the rail |
| `5be418eb` | view and cone entries carry their own name |
| `23620ae6` | the view and cone chooser |
| `3a4a1284` | max range, and backlog item 11 with it |
| `db2a42d4` | paused is its own mode, with a way out of it |

### The slider row, and a control that did nothing at all

`PulseSliderRow.qml` is the first of the canvas's seven row types and the last new primitive
tier 1 needed. Two rules from the canvas are built into it rather than applied to it: **the
allowed range is always on screen** under the label — several of today's bounds survive only
as a magic number inside a label, `Dist confidence adjust (14)`, and a limit discovered by
hitting it is a limit nobody knew about — and **units sit with the value, not the label**.
There is no Apply button: every move acts, and the host drops duplicates so dragging across
one step does not write the same value forty times.

Building it found that **V2's water body filter did nothing whatsoever**. `applyFiltering()`
was a deliberate no-op left from the variant split, so the control existed, moved, stored its
value and changed no picture. It was not reported as a defect because nothing in V2 had ever
called it.

### A name is profile data, not a lookup table

The chooser needed a human name for each view and each cone. The shape that suggests itself —
a switch in the chooser mapping `sideScanRaw` to "Side scan" — is the shape that guarantees a
profile edit and a chooser edit have to happen together, which is exactly how `PULSEblue-IP`
came to be half-supported in the first place. So `title` was added to **every** view and cone
entry in the profile map, and the chooser reads it. `tools/pulse-profile-check.js` was run
after the change, per the standing rule.

`PulseChoiceGroup.qml` is a list rather than a segmented control even at three entries,
against the canvas's own four-or-fewer rule, and on purpose: the entries carry a frequency,
and **510 kHz beside "Wide" is the whole point** of moving this out of a 76 px pop-up. A
segment wide enough to hold both is a row.

### Max range — one key named once, and backlog item 11 with it

The classic selector **reads two preferences and writes three**. A blue in side scan writes
`maxDepthValuePulseBlueFixed` and reads `maxDepthValuePulseBlue` back, while `setSideScan()`
applies `…Fixed` — three names for one number, and which one you get depends on the path you
took to the control. V2 names the key **once**:

```qml
readonly property string displayMaxRangeKey:
      displayIs2DTransducer ? "maxDepthValue"
    : isSideScan2DView      ? "maxDepthValuePulseBlue"
    :                         "maxDepthValuePulseBlueFixed"
readonly property int displayMaxRange: pulseSettings[displayMaxRangeKey]
function storeDisplayMaxRange(v) { ... }
```

One binding to read, one function to write, and the key chosen in one place — rule 2 applied
to a value with three sources instead of two.

**Backlog item 11 came out of the park because the control it belongs to was being built**,
which is the condition Olav set for it. `maximumDepth` is a binding that three places assign
to, so the first assignment freezes it and the ceiling stops tracking the device. V2 does not
assign: it reads the hardware limit for a 2D transducer and live `echogramWidth` for a side
scan, with `maxRangeCeilingOverride` as the single, explicit escape.

**A third defect surfaced while testing it.** `PulseAppV2.maxDepthValue` was a *binding* that
`Plot2D` assigns to on every pinch — so a pinch changed the range and immediately forgot it.
It is now a plain property routed through `storeDisplayMaxRange()`. This is rule 2 catching
something that had already shipped in V2 and had not been noticed.

Olav on the result: *"the drag handles compared to my old plus and minus buttons are far more
efficient to use. So I am happy with this design choice."*

### Paused is its own mode

`PulsePausedGutter.qml` replaces the rail while the picture is frozen, rather than adding a
state to it. The reasoning is in the file: while the picture is frozen you are **inspecting**
it, and nothing on the rail helps with that — you are not choosing a palette with a crosshair
in your other hand. One button gets out and it is the largest thing on the surface, because a
frozen echogram with no obvious way back is the kind of thing a user reports as a crash.

It takes the rail's own width deliberately, so the echogram does not **jump** the moment you
pause it. The word PAUSED is set down the gutter rather than in a corner pill: classic puts it
top right, which is where the V2 indicator stack now lives, and two things claiming one corner
is how a corner stops being read at all. Olav: *"Love the 'PAUSED' in the rail also."*

---

## Session close — 13 Sept 2026, the rail and panel session

### What is achieved

Stage 4 (a) and the whole of Stage 4 (b) tier 1. **V2 is now a usable UI**, not a shell: seven
rail buttons, a sliding panel that compresses rather than covers, and a paused mode. Branch
`feature/pulse-ui-v2-rail`, **28 commits, unpushed** — Olav pushes via GitHub Desktop.

Eight new QML files (`PulseRail`, `PulseRailButton`, `PulsePillColumn`, `PulsePanel`,
`PulseColourGroup`, `PulseSliderRow`, `PulseChoiceGroup`, `PulsePausedGutter`), three new
white icons, and two new static checkers — `tools/pulse-qml-version-check.js` and
`tools/pulse-icon-check.js` — joining `tools/pulse-profile-check.js`. All three exist because
the sandbox has no Qt: **static checking is what substitutes for compiling**, and each was
written the moment a class of defect reached the device that a check could have caught first.

### The decisions, and why each was taken

**The rail lives in `main.qml`, not in `PulseAppV2`.** Olav's first instinct was the opposite —
*"if I put it into the PulseAppV2 then I mess as little as possible with the main.qml"* — and
he reversed it on seeing the build: *"It is a separate section anyway that the upstream author
cannot hamper."* The forcing reason is physical: `qPlot2D` paints the echogram across its
**entire item**, so anything that takes width from the picture must be the panes' **sibling**.
A rail inside `PulseAppV2` can only ever cover the echogram, and Olav had already ruled that
out: *"Must be avoided, echogram to cover the remaining part of the screen."*

Two numbers carry the whole of the compression, and neither guesses about the other:

```qml
readonly property real pulseRailInset: ...
readonly property real pulsePanelInset: pulsePanel.visible ? pulsePanel.inset : 0
```

**Hiding the rail and leaving V2 are different glyphs.** They were the same arrow, and the
arrow was tapped expecting the rail to hide — it left V2 and returned to classic. Two icons
now, `pulse_rail_hide.svg` and `pulse_rail_show.svg`.

**Every control reports; nothing stores.** `PulseSliderRow`, `PulseColourGroup` and
`PulseChoiceGroup` are all handed a value and emit a signal. A control that owns its own copy
of a value is a control that can disagree with the picture.

**Cross-file reach goes through `pulseRuntimeSettings`, never through an id.** QML ids do not
cross files; the rail could not see `pulseConnectionScreen`, so the connection screen's
visibility became `connectionScreenRequested` — one binding, one override, rule 2 again.

**Tablet first, colours first**, on Olav's call. Phone portrait is carried as design drafts
rather than built.

### Shortcomings — what is not done, and what is known to be wrong

**Not built yet (tier 1 remainder and beyond):**

1. **The aim / zoom.** The next task. Research is done — see below — but no design has been
   presented and no code written.
2. **Settings, regular and expert.** Tier 2 is seven groups, tier 3 is seventeen expert
   groups, and **six of the seven row types are still unwritten** — only the slider row exists.
3. **Depth and temperature on the echogram.** Belongs to `PulseAppV2`: lower left on a side
   scan, top left on a 2D picture, by the flow rule.
4. **`armOldDataWarning()` is still a no-op in V2.** Deliberate at the split, and still a
   real gap — classic warns, V2 does not.

**Known defective, deferred by Olav's call** (*"my test work will become easier the more
features I have available… so I suggest we move ahead and handle the problems at the end"*):

5. **Blue is getting red's colour choices and favourites.** Half-diagnosed: the V2 path is
   ruled out by construction, and the `THEME:` log line tells the two remaining causes apart
   without a build. Full reasoning in the step 1 section above.
6. **The grey source dot is unproven.** Green and amber confirmed on device; grey needs a log
   carrying the picture with nothing committed.
7. **A demo for red, after the app has been behaving like a blue, draws a single-channel side
   scan flowing from the top.** Olav's words, and one of several such quirks he intends to
   write down himself at the end of 4 (b).
8. **Classic's `recordingOnScreen` has `visible: isRecordingKlf` AND a handler that assigns
   `visible`** — a live rule-2 violation, in classic, found while working on the rail.
9. **`resources/icons.qrc` lists two files twice.**
10. **`Scene3DToolbar.qml`'s HoverHandler needs an import bump** — it is the sole entry in the
    `KNOWN` list of `pulse-qml-version-check.js`, i.e. a suppressed true positive.

**Wanted, not started:** burst playback to remove the file-open freeze. Olav's idea, in his
words: *"utilize the method set for playback… burst through and then let the echogram grow
really fast with far less time than one epoch per 50 ms. That will eliminate the waiting time
for the user as echogram starts emerging incrementally."*

### The aim — research done, so the next session does not repeat it

**The C++ is already there and already `Q_INVOKABLE`.** `src/scene2d/qPlot2D.h`:
`setZoomPreviewMode(bool)`, `setZoomPreviewSourceSize(int)`,
`setZoomPreviewReferenceDepthPixels(int)`, `setZoomPreviewSourceByEpochDepth(int, float)`,
`setZoomPreviewFlipY(bool)`, `notifyAimTouchEnd()`, `getAimEpochIndex()`,
`setAimEpochIndex(int)`. **`main.qml:1505-1508` and `:1560` are a working call pattern** — the
3D sync loupe already drives all of it.

**`setZoomPreviewSourceSize` is the single knob** that answers Olav's phone note: *"we may
distinguish size of zoom box with phone when we get into that."* Zoom box size is one number,
not a rebuild.

**The contact data is `Q_PROPERTY`, not signals:** `contactVisible`, `contactLat`,
`contactLon`, `contactDepth`, `contactIsActive`, `contactPositionX/Y`, `contactIndx`.
`contactDialog` (`main.qml` ~1672, `Plot2D.qml` ~1964) is the **waypoint-naming dialog**, not
the loupe.

**The green pause button, and why V2 will not copy it.** `HorizontalCheckController.qml:110-113`
paints the play/pause checkbox green when `pulseRuntimeSettings.mavlinkDetected` is true; the
flag is set at `Plot2D.qml:159` from `deviceManagerWrapper.mavlinkDetected`, and `main.qml`
already gates on `mavlinkDetected || (core.filePath && core.filePath.length > 0)`. Olav's own
verdict on it: *"an easy way to give a signal to the user. But not intuitive at all. Somehow
we should signal it, at least when we are inside the pause screen."*

So V2 states the **consequence** rather than the technology — while paused, a line on the
picture reading roughly *"Long press to add a waypoint"* against *"No position data — a
waypoint cannot be placed here."* **The exact wording is Olav's to confirm**, like the four
per-group consequence sentences on the setup card; it is not to be assumed.

Note that the position test is `mavlinkDetected` **or a loaded log file** — a waypoint can be
placed on a recording, and a design that only asks about live telemetry gets that wrong.

### Standing constraints, restated so a cold session inherits them

- **Patch this document by anchored replacement, never by rewriting it whole.** `7b7c4beb` was
  an exact inverse of `cc05867c` for this file and silently deleted a handover section; the
  mechanism was a full-file rewrite from a stale copy.
- **One idea per commit.** The device is a slow test rig and mixed commits cost a round trip.
- **Show the design before building**, as with the connection screen and the setup card.
- **Run `node tools/pulse-profile-check.js` after any profile change.**
- **Nothing under `build/` is touched.** Ask for folder access and delete permission before any
  branch switch or file removal.
- **Split screen and the "Both, split screen" view option are not to be touched** — per-pane
  range has nowhere to live yet and the per-pane state object is an open decision.
- **Backlog 12 and 13 stay parked**; they are parked *on V2*, so they are raised only when the
  control they belong to is being built. (11 came out under exactly that rule.)
- The three design rules, which are designed out rather than swept afterwards: anything judged
  by **looking** reads `displayIs2DTransducer`, never `is2DTransducer`; a value with two
  sources gets **one binding and one override, never an assignment**; and **never a plain
  width or height on a direct child of a Layout**.

### Still with Olav, and blocking nothing

The boat run with two transducers, the real swap, the PULSEblue-IP acceptance test, and the
four per-group consequence sentences for the setup card — *"mine to write — ask me when the
card is next touched, not before."*

### Two things outside this branch

- **`feature/device-profiles-step4` still has to be merged to master.**
- **The late-September aquarium exhibition: classic UI or V2?** Asked at the start of this
  session and still unanswered. It is the one open question that could reorder everything
  above, because it sets whether V2 needs to be presentable in two weeks or merely correct.

---

## Stage 4 (b), step 6 — the aim / zoom (14 Sept 2026)

Three commits finished the last tier-1 control. **`feature/pulse-ui-v2-rail`, 32 commits,
still unpushed.**

| Commit | What |
|---|---|
| `50b5fa63` | the loupe rebuilt, and the green pause button answered inside it |
| `bbc9eef1` | the paused gutter follows the flow |
| `73e1bdc4` | the history bar comes off the picture and into the gutter |

### The exhibition question, answered — and then de-fanged

**V2 runs at the aquarium.** But it is not a deadline: *"do not fear the exhibition. My
partner who builds the echo sounder is the one on the stand. I am not worried about the
exhibition at all."* His partner brings several devices, some carrying the **production
release**; this build is for internal testers, and if V2 is not right he simply uses the
old version. So V2 being presentable is the **direction**, not a two-week gate — the
deferred defects stay deferred and nothing is reordered on the exhibition's account.

### The route: the loupe stayed in C++, and the research explains why only half of it could move

The session-close research established that the zoom-preview API is entirely `Q_INVOKABLE`
and that `main.qml:1505-1508` drives it. Both true. What it did not reach is that **the
loupe's values are not reachable from QML at all**: `Plot2DAim::cand_`
(`plot2D_aim.h:60-84`) privately holds `depth`, `crossMeters`, `lat`, `lon`, `anchorPx`,
`crossDev`, the three hit rects and `haveTarget`, and none of it is a `Q_PROPERTY`. A QML
loupe therefore needs a C++ **exposure layer** before it can print one number — a different
C++ change, not the absence of one.

Against that, the panel to be rebuilt is already one self-contained function:
`Plot2DZoom::draw()`, 305 lines, taking `boxSizePx` and `zoomFactor` and returning its own
hit rects. And the deciding argument is those hit rects: **the buttons and their tap targets
come out of the same code in the same coordinate space.** A QML overlay over a
C++-managed crosshair puts the picture and the touch target in two coordinate systems that
must agree across `deviceScale_`, which on a slow test rig is a three-round-trip class of
bug.

So `draw()` dispatches on `Input::v2Style` in its first three lines and everything below
them is the loupe exactly as it shipped. **Classic's loupe is untouched by construction** —
it is still what `uiVariant` falls back *to*.

Two corrections to the research while we are here. The box is **250** design px at both call
sites, not 180, so "three times the area" was measured against something else; V2 is 320 and
the panel roughly doubles because the bands sit outside the tile. And the phone knob on this
route is **`Input::boxSizePx`**, not `setZoomPreviewSourceSize` — that one belongs to the
QML route. The percent `loupeZoom` slider in settings drives `setLoupeZoom`, which is
**upstream's** loupe and a different thing entirely, so there was no contradiction to fix.

### What the loupe rebuild actually fixes

Three of the four changes are defects rather than styling.

**The two values were painted ON the data** — `D: 12.3` and `v: 4.5` inside the top of the
zoom image, over the patch of echogram you magnified in order to read them. Labelling them
in place would only widen the obstruction, so they come out into their own band. Rows rather
than a left/right pair, so the numbers align on their right edge; and the second row's
**label** is what changes on a dual side scan — `Lateral left` / `Lateral right` — where the
old panel swapped the value's prefix for a bare `<` or `>`.

**Dismiss and Add were two equal grey halves** told apart by an icon alone: a destructive
action and a constructive one at identical weight. Ghost and filled now, unequal, below the
tile. With no position the Add button is **absent rather than greyed**, the rail's own rule,
and Dismiss takes the whole width.

**The magnification was invisible.** It is in the header, reading the same `zoomFactor` field
the crop divides by rather than a second constant.

**And the green pause button is answered here rather than on the picture.** Classic greens
the play/pause checkbox on `mavlinkDetected`: the technology, announced before anyone asked,
in a corner with nothing to do with waypoints. V2 says **nothing at all** while a waypoint
can be placed — the Add button being there is the whole message, and a sentence repeating it
would be a second thing claiming one job. It states the consequence only when it cannot, in
that button's own slot, in Olav's words:

> No position — you can inspect the echogram, but not mark it

The premise of the first draft was wrong and Olav corrected it rather than the prose: the
gesture is **not a long press**. `Plot2D.qml`'s `onPositionChanged` calls
`plotMousePosition(x, y)` on every move while paused and `onReleased` commits a drag "exactly
the same sequence your single-tap uses", so the loupe tracks the finger continuously and the
release point arms. There is no long press to advertise.

`uiVariantIsV2` is one binding in `PulseRuntimeSettings` and one key on the runtime bus,
pushed at startup as well as on change — the aim layer can be asked to draw before a model is
committed, and a loupe that came up classic in v2 until the first commit would be a defect
nobody could reproduce twice.

**Device verdict: *"This actually looks good."*** With one note: **the size may need tuning
for phone and split screen**, which is the `boxSizePx` line and nothing else.

### The gutter follows the flow — the no-jump rule loses

The first gutter took the rail's width and ran down the left whatever the picture was doing,
so that pausing never moved the echogram sideways. Olav overrode it: *"We do #2, follow the
flow. That is the only intuitive way."*

A side scan keeps the vertical gutter at the left. **A 2D picture gets a horizontal gutter
along the foot**, so pausing gives the rail's width back and takes height at the bottom and
the picture reflows. The trade is paid openly: `main.qml`'s inset comment now says the
no-jump promise holds for a side scan only, rather than standing as something that used to be
true. `pulseRailInset` answers for the left edge and `pulsePausedFootInset` is a separate
number — they are margins on different sides, and a reader holding one must not be able to
apply it to the other.

`alongFoot` is handed in from `isHorizontalGrid`, the same flag the history bar has always
used to choose between its two sliders, so the gutter and the bar it was about to swallow
cannot disagree about which way the echogram runs.

### The history bar leaves the picture, and why that is a fix rather than tidiness

Olav's reason: *"the old design results in a moving magnifying box also when using the
current drag handles (as they are present in the paused echogram areas)."*

`TimeLineShifter` is `anchors.fill` on the window — the horizontal variant across the top of
the picture, the vertical one down its left — so **dragging the bar dragged the aim
underneath it.** The aim's touch handling belongs to the plot and the bar was sitting on the
plot. Off the picture that cannot happen at all, which beats any amount of event-swallowing:
there is no longer an event to swallow.

Each gutter takes the slider matching its flow and **neither slider is rewritten**. The
position stays where it lived — `historyTimeLineScroll` is assigned from both panes'
`onTimelinePositionChanged`, so it remains the holder and the gutter binds to it; a user move
comes back as a signal and `main.qml` does the same three things the old handler did,
`resetAim()` included.

One QML trap worth recording: **a rotated `Text` keeps its unrotated bounding box.** Anchoring
the slider to `PAUSED.top` ran the slider straight through the word. The fix is to box it in
an `Item` whose height is the text's natural **width**, which is the length the word occupies
once turned.

### Two defects found while building, neither fixed here

**1. No depth for the 2D view.** Confirmed by Olav on the device: the loupe's `Bottom` row is
labelled but blank on a 2D picture while `Cursor` reads correctly, so `cand_.depth` arrives
NaN. The labelled blank is the designed "not known" state working; the missing value is not.

**2. `waterViewFirst` is a cross-file `id` reach, and it cannot resolve.**
`TimelineSliderVertical.qml:104,113` and `TimelineSliderHorizontal.qml:93,102` call
`waterViewFirst.setDragActive(...)`, but `waterViewFirst` is an id declared in `main.qml` and
**QML ids do not cross files** — it is not a context property either (`core.cpp` registers no
such thing). So the call throws, `onPressed` aborts before its `update(mouse)` and
**`setDragActive` has never once run**. That is why tapping the bar does nothing while
dragging works, and it is very likely a second half of the moving-magnifier complaint. It is
the same class as the rail's `pulseConnectionScreen` problem and wants the same answer: a
signal out, wired in `main.qml`. Deliberately not in the move commit — a move is not a
change.

### Housekeeping — stale git locks in the working tree

The sandbox shell could not unlink `.git/index.lock` and `.git/HEAD.lock` (the bridge treats
`.git` as protected even with delete permission granted on the folder). They were moved into
`.git/_stale/` so git could continue. **`.git/_stale/`, any remaining `.git/*.lock` and the
`.git/objects/*/tmp_obj_*` files should be deleted by hand** — GitHub Desktop will refuse to
operate while a real `index.lock` is present.

---

## Step 6 on the device — five faults, and the one that was not a fault (14 Sept 2026)

The loupe was right on the first build (*"This actually looks good"*). Everything below came
out of the next three. **Branch `feature/pulse-ui-v2-rail`, 39 commits, unpushed.**

| Commit | What |
|---|---|
| `f6236733` | the paused gutter constrained to its own axis |
| `e89ce444` | the history pill moves again |
| `686e298b` | the loupe gets a depth on a 2D picture |
| `6ea676fa` | and reads bottom track first |
| `a98fe9e9` | `pulseSettings` handed over instead of looked up |
| `5bb69ec4` | the two warnings that fix left behind |

### 1. A conditional anchor is set but never cleared

*"This was not very successful for side scan, 2D is however good… need to constrain the X
axis."* The gutter filled the whole window, its panel over the picture and its controls
centred on screen.

The orientation was carried by `anchors.top` and `anchors.right`, each `undefined` for the
orientation that does not want it. But **`isHorizontalGrid` defaults to `true`**, so the
gutter is *born* along the foot with `anchors.right` set — and **assigning `undefined` to an
anchor does not clear one that is already there**. A side scan then added the top anchor and
kept the right: four sides anchored, gutter fills the window. A 2D picture never flips, which
is exactly why it stayed correct.

The orientation is width and height now, with two anchors that are set once. **An anchor that
is only ever set cannot get stuck** — and that is the general lesson, not a detail of this
control.

### 2. Rule 2, broken by the person writing the rule down

*"The sliding pill in the history bar does not move."*

`value` on each slider binds to the gutter's `timelinePosition`, and the gutter *also* called
`setPosition()` when the slider became visible. `setPosition` writes `slider.value`, which
the alias exposes as `value` — **an assignment to a bound property**. The first pause
destroyed the binding permanently.

Both calls are gone: one binding, no push handler. Worth knowing that **`TimeLineShifter`
carries the same hazard and pays for it the other way round** — it pushes `setPosition()`
from three separate handlers precisely because its binding is destroyed the same way and
something has to keep the pill honest afterwards.

### 3. The 2D depth, and a dead line beside the hole it was shaped to fill

```cpp
if (isSideScan) { depth = eg->bottomProcessing.getDistance(); }
else            { depth = epTap->rangeFinder(); }
if (!isfinite(depth)) { depth = epTap->rangeFinder(); }   // re-reads what just failed
```

A genuine second source for a side scan; for 2D a re-read of the value that had already come
back empty. And `Epoch::rangeFinder()` returns `NAN` whenever the epoch carries no
rangefinder datum, which on a PULSE red is the ordinary case because the depth comes out of
bottom track. So 2D had one source and it was usually the wrong one.

**Then the order was turned round on Olav's call** — *"Here in zoom we can use bottom
track"* — and with it a correction to what this document's backlog implied:

- **Bottom track** may have serious trouble **on the shore**, and struggles below about
  **0.5 m**.
- **The rangefinder** is the one that gets **fooled by sideways features** — badly on a side
  scan, and to some degree on a 2D picture too.

Reading a hard bottom under a crosshair is precisely where a sideways feature would lie to
you, so **both branches now lead with bottom track**. The planned crossover — rangefinder
below one to two metres, bottom track above — is a separate mechanism that must key off **the
rangefinder value** to know which side of the threshold it is on. It belongs with the depth
readout and stays on the todo.

### 4. `pulseSettings` was never resolvable inside `PulseRuntimeSettings.qml`

Eleven `ReferenceError: pulseSettings is not defined` at startup, on every line in that file
that reads persistent settings.

**The cause is creation order, not spelling.** `src/main.cpp` creates
`PulseRuntimeSettings.qml` and publishes `pulseRuntimeSettings` *first*, then creates
`PulseSettings.qml` and publishes `pulseSettings`. So while every binding in the runtime file
evaluates for the first time, the name it wants does not exist. In Qt 6, **a context property
added after a context has been used to create objects does not reliably re-resolve names that
already failed** — so this is not only noise: any binding never re-triggered afterwards keeps
what it computed from `undefined`.

**A capital `PulseSettings` does not fix it.** That is a type name, and a type name yields an
object only for a singleton: `pragma Singleton` is commented out in `PulseSettings.qml`,
`qml/qmldir` is empty, and `qmldir` is in no `.qrc`.

So the object is **handed over**. `main.cpp` sets it as a property the moment PulseSettings
exists; a property re-evaluates every binding that reads it, which a late context property
cannot promise. It carries the same name the file already uses, because **an object's own
property outranks a context property** in QML scope resolution, so all thirteen reads are
untouched.

Olav on the blast radius: *"this explains a lot of problems with wrong choice of colors, max
depths ++. Correct reference will likely fix many minor issues I have seen."* Line 1153 is
`displayThemeId`, which falls back to `model[0]` when its stored index is undefined — **a live
candidate for the deferred "blue gets red's colour choices and favourites"**, which should be
re-tested before anyone debugs it further.

### 5. Two warnings that fix left behind, both general hazards

**`TypeError: Cannot assign to read-only property "uiVariantIsV2"`.** The runtime bus echoes
every key it is handed, and `main.qml`'s `onRuntimeChanged` writes each echoed key straight
back into `pulseRuntimeSettings`. A QML→C++ key is a `readonly` binding here, so the
write-back throws — and **any** future one-way key would do the same. A named list,
`mainview.runtimeKeysQmlOwns`, is read past rather than a `try/catch`: a swallowed exception
would also hide the day a genuinely writable key stops being writable.

**`Unable to assign [undefined] to int`**, three places. The ReferenceErrors in a new coat —
bindings evaluate once before injection. The value is right a moment later; only the warning
was left. The three int reads go through `psInt(key, fallback)` and name their own floor.

### The one that was not a fault — `waterViewFirst`

A claim made in this session and **withdrawn on the device**: that
`waterViewFirst.setDragActive(…)` in the two slider files is a cross-file `id` reach that
cannot resolve, and that it is why tapping the bar does nothing.

Wrong on both counts. Tapping the bar **does** jump the pill, and **no ReferenceError appears
in logcat**. Qt documents ids as file-scoped, but in the implementation a component's ids live
in its **QML context**, and a child component's context chains up to the context it was
created in — so an id from `main.qml` is reachable from a component instantiated inside it.
`setDragActive` runs.

It stays a **robustness** risk rather than a defect: Qt documents ids as file-scoped precisely
because the compiler is allowed to stop honouring that chain. Recorded here so the wrong
theory is not repeated back later.

### Still in the log, not fixed

`TimelineSliderHorizontal.qml:100` — *Parameter "mouse" is not declared. Injection of
parameters into signal handlers is deprecated.* Works today, breaks on a future Qt, and the
same shape is in `TimelineSliderVertical.qml`. A natural companion to the `waterViewFirst`
cleanup, since both live in those two files.

---

## Where the next sessions pick up (14 Sept 2026)

Olav's own ordering, and he wants the last three in **separate chats** because of their
volume.

**Next, and the natural continuation of this one — three overlays that share a vocabulary:**

1. **Depth and temperature on the echogram.** Belongs to `PulseAppV2`: lower left on a side
   scan, top left on a 2D picture, by the flow rule. Both large, never hidden except while
   paused.
2. **The old-data warning.** `armOldDataWarning()` is still a no-op in V2. Olav wants the
   **same design pattern as the demo pill**, with its own message.
3. **An echogram-speed indication**, in a similar form and look, taken while the pattern is
   open.

> **Done — 14 Sept 2026.** All three, plus the depth engine none of them could work
> without. See *Stage 4 (b), step 7* at the end of this document.

> **Settings are done as of 14 Sept** — tier 2 complete, tier 3's manipulation half
> complete, its four information groups still placeholders. **Split screen is next**, and it
> grew: see *Where the next session picks up* at the very end of this document.

**Then, in their own chats:**

4. **Settings, tier 2 and tier 3.** Seven regular groups and seventeen expert groups, and
   **six of the seven row types are still unwritten** — only the slider row exists. The
   largest remaining piece by far.

   > **Tier 2 done — 14 Sept 2026.** All seven row types written, five categories, two of
   > the seven dropped. See *Stage 4 (b), tier 2* at the end of this document. Tier 3 is
   > still ahead.
   >
   > **Tier 3 settings done too — 14 Sept 2026.** Eight manipulation groups under an
   > *Expert settings* title; the four information groups are still placeholders. See
   > *Stage 4 (b), tier 3* at the end.
5. **Split screen, and a button on the rail to reveal it.** A decision that changes the rail
   rather than adding to it: offering screen options **kills the need for the side/down view
   chooser on PULSE blue**, because the layout choice subsumes it. The button count therefore
   stays the same. Note this **reverses the standing "do not touch split screen" rule**, and
   it makes the parked per-pane state object (and backlog 12/13) live again — they were parked
   *on V2*, to be raised when the control they belong to is built, and this is that control.
6. **Bug fixing**, once the surface is complete. Olav's plan has always been to sum up the
   todos at the end of 4 (b) and add the quirks he has been collecting himself.

**And a pass rather than a number:** phone size is deliberately left for later, but **split
screen should be cared for** — *"likely there may be multiple things to adjust."* The rail,
the panel, the setup card, the paused gutter and the loupe all take width or height from a
pane, and in a split each pane is roughly half.


---

## Stage 4 (b), step 7 — three overlays, one vocabulary (14 Sept 2026)

Olav asked for them in one chat "because they are one design, not three". They are, and the
design turned out to be a sentence already written: **the left edge says what the water is,
the right edge says what the picture is**, and both pick their corner by the flow.
**`feature/pulse-ui-v2-rail`, 45 commits, unpushed.**

| Commit | What |
|---|---|
| `9969a0e1` | the depth engine V2 never had |
| `d8cfd50b` | depth and temperature on the V2 echogram |
| `ef39945c` | the echogram speed says what the picture is doing |
| `c8435f89` | temperature stays gated on the beta name — it was not a leftover |
| `a1d92690` | you scrolled back, and the way back to live |

### The finding that came before the design — V2 has been running the sounder blind

`DepthAndTemperature.qml` was never a readout. Two hundred of its 640 lines drew something;
the rest took the depth off the dataset, ran the auto display level, and computed the
dynamic resolution — writing `dynamicSamples` and `dynamicPeriod`, which `DeviceItem.qml`
turns into `chartSamples` and `ch1Period` **on the transducer**, and `autoDepthMaxLevel`,
which the display range follows.

All of it was reachable only by instantiating the readout, and `PulseAppV2` does not
instantiate it. **Nothing else in any `.qml` writes those three keys.** So under the new UI
the sounder has been running at the defaults — 500 samples, 50 ms period — at every depth,
for the whole of stage 4. Not a cosmetic gap behind a missing number: the resolution
behaviour the classic UI depends on was simply absent, and no one would have found it by
looking at the picture.

It is `PulseDepthEngine.qml` now, **one instance above both panes** — the move the
connection screen, the setup overlay and the pill column already made, for the same reason:
one dataset, one transducer, one set of runtime keys. Per-pane it ran *twice* in a split
screen, two 100 ms timers writing the same keys from two copies of `lastStableDepth`.

The readouts get one key, `pulseRuntimeSettings.depthMeters`. **The rule for choosing the
depth lives in the engine alone** — bottom track first, the rangefinder when bottom track
is not initiated, never a NaN — so the classic readout and the v2 one cannot show different
sources. The `bottomTrackMinDepth` crossover is still not implemented; it has to key off the
*rangefinder* value to know which side of the threshold it is on.

### The vocabulary, which was not invented here

V2 already had exactly two families and the job was to put each overlay in the right one.

- **The readout family** — large white numerals, `Text.Outline`, no container. For a value
  read continuously. A capsule here would hide the echogram it sits on.
- **The pill family** — capsule, body `#cc0f1317`, 1 px accent border, 17 px text, hairline
  divider, then a **word** in the action slot. For something transient. The accent carries
  the class: blue `#3d7fd0` what the picture is, red `#d81f26` recording, amber `#d8a21f`
  something is wrong or is being asked.

So the depth readout goes left and opposite the pills, at the same height, and the two new
indications are pills in the existing column. Nothing to learn twice.

### The readout, and the anchor lesson taken further

`PulseDepthReadout.qml`, hosted by `PulseAppV2` — the first thing that file has ever drawn.
Inside the pane by construction, so it owes the rail and the panel no arithmetic.

**No anchors on the moving part.** Step 6 cost a round trip to an anchor set for one
orientation that could not be cleared for the other. The strongest form of *an anchor that is
only ever set cannot get stuck* is not to use one: the block's position is `x` and `y`, and
the flow changes one number. The only anchors are baselines between siblings in a line.

**No MouseArea.** Classic absorbs every press over a 350×200 patch of picture, which eats
the pinch there and, while paused, would eat the aim. Units are a settings question.

Damping is classic's, kept rather than reinvented — 250 ms for depth, 1 s for temperature,
last good value held.

### The temperature clause that looked like scaffolding

`enableTemperature` ANDs `pulseRuntimeSettings.pulseBetaName === "..."`, hiding temperature
on every device carrying a beta name. It was read as a debug leftover and dropped, and Olav
corrected it: **beta devices of the red ("basic 2D") can have the temperature hidden, and as
many as twenty customers are on that hardware.** Dropping it would have printed a number
nothing behind it can measure.

It is blunt — it answers "beta" where the real question is "this beta build has no
temperature sensor" — and a **profile key would say it properly**. That is a change to the
profile records, not to a readout, and it is on the todo rather than made here.

### The speed is two numbers doing two jobs

`pulseRuntimeSettings.echogramSpeed` is what the picture runs at and is the **only one that
reaches C++** (`settingsBus` → `Plot2D::applyRuntime` → `echogramSpeed_`).
`pulseSettings.echogramSpeed` is what the user set and is persistence; `main.qml:231`
mirrors it into the runtime key. Olav on why there are two: *"there are (at least were) some
duplicated settings in pulseSettings and pulseRuntimeSettings to overcome problems to
communicate to C++."*

The pill **says the runtime value and triggers on the persistent one**, and that split falls
straight out of rule 1 while dodging both edges for nothing: `setEchogramPaused` writes 1.0
into the runtime key on pause and restores it on resume, so triggering on the runtime key
would flash `1.0×` as the picture freezes and `1.8×` again as it thaws — which is exactly
what classic's top-centre indicator has been doing under V2. That indicator is now gated to
classic, with the `Echogram speed: New value X (persistent Y)` log line left outside the
gate because it belongs to neither variant.

And what the setting actually does, in Olav's words: *"Echogram speed setter affects the
size of the getImage in C++. The speed increase is an illusion, echogram is stretched making
the pixels flow faster over the screen."* `plot2D.cpp:441` — `painter->scale(echogramSpeed_,
1.0)`, horizontal pictures only, and only above 1.0.

### Old data: a binding, not an arming

Classic arms the warning from a drag handler, runs a 6 s countdown across two timers and a
third for the hide, and then **drags the picture back to live by itself**. Olav removed that
whole mechanism: *"The 6 Sec countdown can then be removed. User can decide for himself, and
the warning is anyway on the screen."*

So the pill is up while the timeline is off the head and gone when it is back — bound to
`historyTimeLineScroll`, the one holder of the position, which both panes already write and
the paused gutter already binds to. **No timer in the file at all.** His sentence is *"You
scrolled back"*, and the demo pill's action slot carries **Live now**, which does at the
user's moment what the timer used to do at its own.

`armOldDataWarning()` stops being a no-op and keeps the one job that genuinely belongs to a
pane: **the hold**. `plot2D.cpp:1531`'s `followLive` drags the picture back to the head on
every ping unless `echogramHoldHistory_` says otherwise, so without it a scrolled-back
echogram is yanked live before it can be read. Armed by the drag, released the moment the
timeline is back at the head by any route, so it cannot be left on. (`followLive` is
32-bit-only today, so on a 64-bit build the hold changes nothing — still wrong to leave
unset.)

### Olav's own list, for the bug-fixing chat

Reported this session and deliberately **not** touched here.

1. **Mix and match across user choices** — colour palette, max distance, intensity, water
   filter. A stored choice for one device showing up under another.
2. **A red that has seen a blue demo keeps a vertical running 2D view, irreversibly.** This
   is almost certainly the same shape as the speed defect below: state written on entering a
   blue profile and never unwritten on leaving it.
3. **The runtime speed never returns from a blue profile.** `main.qml:192` forces
   `pulseRuntimeSettings.echogramSpeed = 1` for blue and nothing restores it when the
   profile goes back to red. The stored 1.3 is intact; the picture is never told. One line.
4. **A slider whose value is correct but is not applied to the echogram.**
5. And more that Olav is collecting.

The `a98fe9e9` injection fix is a live candidate for several of 1 — *"this explains a lot of
problems with wrong choice of colors, max depths ++"* — and the deferred **blue gets red's
colour choices and favourites** should be re-tested before anyone debugs it further. **That
re-test has not been done and is still owed.**

### One more for rule 1

`Plot2D.qml:533` gates the speed pinch on `is2DTransducer`, the **committed** device, where
every other display question now reads `displayIs2DTransducer`. Classic code, one word, not
changed here.


---

## Stage 4 (b), tier 2 — the settings list (14 Sept 2026)

Olav kept this in the same chat rather than opening its own, and it ran to seven commits.
**`feature/pulse-ui-v2-rail`, 53 commits, unpushed.**

| Commit | What |
|---|---|
| `60469149` | the settings list, and a setting that looks like it belongs to its category |
| `49837335` | the choice row, and two categories closed out |
| `47e0ea7e` | the stepper row, Installation and Connection |
| `46fb70c4` | the read-only row, and NMEA output |
| `2adb3175` | View a file, and no Recording category |
| `13aa18bd` | the action row, and Troubleshooting |
| `c870fdb1` | the text row, the key code, and one rule instead of two |

### The hierarchy, and the one rule it rests on

The list as first drawn told a category apart from a setting by a chevron and nothing else.
Olav, on the Android Wi-Fi list in dark mode: a combination of blue and white fonts over a
slightly brighter grey makes it *"super readable"*. Three treatments were drawn at the
panel's real 360 px width — colour alone, colour and indent, colour and indent and a
brighter card — and he chose the middle one: *"Color and indent is the most intuitive
way."*

The colour rule is worth stating once because **it is not new**:

> **Blue is what varies; white is what is fixed.**

A closed category is only a label, so it is white. Open it and its name turns blue, because
it is now the thing you are inside. Every value in the panel was already blue for that
reason. The panel gains no new meaning for blue — it applies the one it had.

The indent is one step and one only: 6 px of gap, a 2 px rule, then 16. There is no second
level of nesting to distinguish, and a second step would invent a hierarchy that does not
exist. **The rule runs the height of the CHILDREN rather than of the group**, so it stops
where the last row stops instead of trailing into the gap before the next category. One
category is open at a time, which is the rule the panel already followed for rail groups.

The chevron is **drawn** from two rectangles rotating about a shared vertex rather than
loaded, so there is no new SVG that could ship without a stated colour and draw black on a
black panel — which is how three rail controls went missing on 13 Sept.

### Reads are bindings, writes go through one signal

Every row binds its value straight to `pulseSettings` or `pulseRuntimeSettings` and reports
a change; `main.qml` assigns it and nothing else does. A property-and-signal pair per
setting would be a hundred of each by the time tier 3 lands, and the rule they exist to
protect — one writer per key — is kept exactly as well by one.

Writing by string key works because it is an **assignment**; a **binding cannot be formed on
a string key**, which is why the rows bind their reads explicitly instead of the list being
described as data. Three signals, not one: `settingChanged(target, key, value)` for a value,
`actionRequested(id)` for a button that carries none, and `keyCodeEntered(code)` for the one
thing that is neither.

**Absent rather than greyed, at both levels.** A row the profile does not offer takes no
height; a category whose rows are all absent is not offered at all. Connection is the live
case — both its rows are expert or beta, so an ordinary user never sees the category.

### The trap that was not walked into

The obvious shape for the category is `default property alias content: kids.data`. Aliasing
the **default** property redirects every child declared under the root — including the
header and body declared in the same file — into `kids`, which lives inside `body`, so the
component tries to contain itself. There is no compiler in this shell to catch that. A named
alias instead, with rows assigned as a list and taking their width from the group's
`contentWidth` rather than from `parent`, **which is not their parent until after they are
reparented**.

### The seven row types

| Type | File | Where it landed, and what it decided |
|---|---|---|
| Slider | `PulseSliderRow` | existed since tier 1; the echogram speed rides it as tenths, 10–50, so the row needs no float mode it would use once |
| Switch | `PulseSwitchRow` | the knob's x follows `checked` through a Behavior; nothing assigns it |
| Choice | `PulseSegmentRow` | options carry `{ value, title }` — the row never maps an INDEX onto a meaning, which is the mistake `ecoViewIndex` made |
| Stepper | `PulseStepperRow` | press-and-hold, ten steps at a time after ~2 s; snaps to the step grid rather than accumulating |
| Read-only | `PulseReadOnlyRow` | dim, no border, no target — it must not look like the rows that respond |
| Action | `PulseActionRow` | confirms **in the row**; the question stands where the hint was, so the row does not change height |
| Text | `PulseTextRow` | two elements, not one field in two modes — see below |

**Segmented or stepper** is decided by what the options are: segmented when they are answers
with **names** (metres or feet, 25 m or 35 m), a stepper when they are points on a **ladder**
(UDP port 3000–3500). Six four-digit segments at panel width is a squeeze that only gets
worse on a phone.

**The text row is two elements because of rule 2.** A `TextInput` whose `text` is bound to
the stored value cannot also be typed into: beginning an edit would have to assign it, and
the first assignment destroys the binding for good — after which the row shows whatever it
last held rather than what is stored. So the resting element binds and is never written, the
editor is written and never binds, and Cancel costs nothing because nothing outside the
editor ever saw the draft. It is a `TextInput` rather than Controls' `TextField` so it does
not arrive wearing whichever Controls style the app is built with.

### The categories, and the two that went away

**Screen & echogram** · **Installation** · **NMEA output** · **Connection** ·
**Troubleshooting**.

**Position source became a row inside Installation.** The document promised three sources and
`PulseSettings.qml` does declare all three keys, but only `positionSourceAutoPilot` is ever
READ — `DeviceItem.qml:1892` and `:1933`, and nothing in any `.qml` or `.cpp` touches the
other two. Olav: no urgent plan to offer the others, and *"it will be more intuitive to add
it under the installation category"*, where the boat is rigged. A category of one is a
category that should have been a row.

**Recording is gone entirely.** Its tab had three jobs and the new surface has taken all
three — the rail's Record starts, the pill asks before stopping, the connection screen
starts a demo. Olav: *"All redundant... But in settings we do not need this as a category."*
The job with no home was **opening a file**, and he put it on the connection screen beside
Start a simulation and before the Keep button, reading **"View a file"**. Its own
`FileDialog`, because the two acts are different machinery: `core.openLogFile()` renders the
whole recording and sets `wasKlfFileOpened`, `enterDemoMode()` closes the live links and
paces it — and they accept different file types. Both make `isPresentingLog` true, so the
screen closes itself either way.

**No "choose a different transducer" row** in Troubleshooting, though the document lists one:
the rail's source button opens the connection screen, which is that action with a picture of
every device on it. Repeating it would be the duplicated ability tier 3 needs cleaning of,
arriving fresh in tier 2.

**Reconfigure is offered to everyone**, where classic keeps it under the expert Device swap
group. Olav agreed: *"the judgement to expose the reconfigure: Agreed!"* It is the honest
answer to "the app and the transducer have drifted apart", which is not an expert's problem.

### Wording, where a label was explaining the widget

Two rows said what the control was rather than what the setting means.

- Classic's unit row is a checkbox whose **label changes** — "Metric depth (checked)" /
  "Imperial depth (unchecked)". Olav: the extra words existed only *"to explain how the old
  checkbox would work"*. Two buttons, Metres and Feet, and the explanation is unnecessary.
  His verdict: *"much better"*.
- "DBT message interval ms" with a value of 250 became **How often** with **4 / s**. Nobody
  thinks in milliseconds between depth sentences.

### The key code: one rule instead of two

Entering a code rewrites four keys and two access levels, and that logic lived inside
`KeyCodeInput.qml` — a **classic** control the v2 list cannot reach. It is
`pulseRuntimeSettings.applyKeyCode(code, salt)` now, called by both, and classic's copy is
**deleted rather than left beside it**. The salt is an argument rather than a read of
`installToken`: `main.cpp`'s creation order has already cost one session eleven
ReferenceErrors, and a function that takes what it needs cannot be caught by it.

The row is masked at rest and plain while typing — a secret worth not showing over a
shoulder at a stand, and a field you cannot read while typing into it is a field you cannot
correct. It says what the code **bought** rather than showing two small badges: "Expert —
every setting is shown", "Beta tester", or that the code grants nothing.

### Two things found while wiring tier 2

**A mirror only classic had.** `isSideScanLeftHand` is the runtime key the bus carries to
`Plot2D` and the grid; `isSideScanOnLeftHandSide` is the persistent one. `main.qml` copied it
at startup and on a link event, but the only **on-change** mirror lived in
`PulseInfoSettings.qml` and `PulseAppClassic.qml` — both classic — so under v2 the mounting
switch would have stored a value the picture never heard about. One handler in `main.qml`
now answers for both variants.

**A row that states an address it does not read.** Classic's "NMEA send to IP" draws the
literal string `255.255.255.255` while `NMEASender` reads
`pulseSettings.nmeaBroadcastAddress`, which `main.qml:143` overwrites from the runtime key.
Right until the day it is not. The v2 read-only row binds the key.

### Sound speed — the design, settled but not built

`pulseRuntimeSettings.soundSpeed` is `property int soundSpeed: committedProfile.soundSpeed`,
a **binding**, and classic's controls in `PulseInfoSettings.qml` and `PulseInfoExpert.qml`
assign to it — destroying it permanently, so after one touch the sound speed stops
following a device swap for the rest of the run. Rule 2, live in the tree.

Olav's reasoning for what it should be: the generic profile value is proper for many
situations, but *"a professional would prefer to be able to measure and make up his own mind.
And in THAT case, the pulseRuntimeSetting is the better choice. The value is kept for the
usage session, but not set for the next."*

So it takes the one-binding-one-override shape that backlog item 11 used for the range
ceiling: the profile supplies the default, an expert override wins while it is set, and
**nothing ever assigns the bound property**. Because the override lives on the runtime object
it dies with the app on its own — no new persistent key.

**And the override survives a device swap**, confirmed by Olav: *"Sound of speed is water
dependent and not transducer dependent. Meaning should I change to another transducer then my
changed speed value in the setting should win over the profile sound of speed."*

It is expert-only, so it lands with tier 3, alongside the expert dist-max control which needs
the same treatment.

### What tier 3 inherits

Seventeen expert groups, all seven row types already written, and Olav's own note on them:
*"For expert we may need to clean up a little, and also to avoid duplicated abilities. I have
no time to properly clean up before implementation though."* A duplicate usually shows up as
two rows of the same type writing the same key, which is easier to see once every expert row
has had to declare which type it is.


---

## Stage 4 (b), tier 3 — the expert section, and the defect it uncovered (14 Sept 2026)

**`feature/pulse-ui-v2-rail`, 62 commits, unpushed.**

| Commit | What |
|---|---|
| `09e0dc00` | the expert section, under two titles |
| `33ed0c04` | the three picture-tuning expert groups, and a stepper that walks a list |
| `bc752b14` | the profile stops being edited by the controls that read it |
| `5eeba3ba` | the last four manipulation groups |
| `c57820a4` | a row is as tall as its content |
| `c2f17129` | depth manipulation actually changes the depth |
| `0608cef4` | **device parameters have one source of truth** |
| `61bf8824` | the runtime bus stops handing managed parameters back |

### Two titles, and the code already knew which group was which

Tier 3 adds twelve categories to tier 2's five. Olav: *"the volume of headers become more
manageable"* under a title, and there are two kinds — manipulations and pure information.
The split needed no judgement: under **Expert settings**, every row of all eight groups is a
control; under **Expert info**, every row of all four — forty-eight of them — is a `Text`
with nothing beside it.

The title is a LABEL, not a container. It does not open, does not indent what follows, and
nothing hangs off it. Dimmer than a category on purpose: a category name is a thing you tap.

**"Device swap" is gone**, and its three rows are all accounted for rather than dropped with
it — reconfigure and *swap without asking* went to Troubleshooting, and *choose a different
transducer* is the rail's source button. **The expert switch moved into Experimental
settings**, which reads the ENTITLEMENT (`pulseSettings.isExpert`) while every other expert
category reads `expertMode` — so turning expert off leaves exactly one category on screen,
which is the way back. Classic's is `visible: expertMode` and hides itself.

Olav on the remaining edge: switching expert off *and* returning to v1 needs an app restart,
because expert mode hides the expert tab in the old UI. *"This is fine, do not change it."*

### The stepper learned an uneven ladder

Almost every expert value is a list like `[0, 0.1, 0.15, 0.2, 0.25, 0.4, 0.5, 0.75, 1.0]`:
ordered, but with no single step, so min/max/step cannot describe it. Set `values` and the
stepper walks the list by index. A stepper rather than the canvas's *"a list in the same
panel"* — fourteen segments do not fit a 360 px panel, and a scrolling list inside a
scrolling panel is two scrolls fighting over one finger.

**Nearest, not `indexOf`.** A stored value can arrive from a profile default or an older
build's list, and `indexOf` would answer −1 and strand the control at one end.

### A row is as tall as its content

Three collisions on the device, one bug in seven files. Every row type added up a one-line
label, a one-line hint and its control and called that its height — so any hint long enough
to **wrap** overflowed and was overlapped by the next row. Depth filter, Black stripes and
Depth manipulation are exactly the rows whose hints are sentences.

A guessed height is right until the words change, and the words change in every translation.
Every row now measures. The slider row had the same fault with the opposite shape — track
pinned to `parent.bottom` inside a fixed 104 du — so all seven now obey one rule.

### Depth manipulation, and two dead halves in classic

`pulseRuntimeSettings.fakeDepthAddition` **is read by nothing**. `dataset::_fakeDepthAddition`
is what shifts the picture, and classic's control sets the property *and* calls
`dataset.setFakeDepthAddition()`. The generic settings path wrote the property alone.

And **classic's "Reset false depth" does not work either**: it zeroes `fakeDepthAddition`,
which re-syncs the thumb, but the control carries `emitOnUserActionOnly` so
`setFakeDepthAddition(0)` is never called and the C++ offset stays. It also raises
`resetBottomTrackActive`, declared once and read **nowhere** in any `.qml` or `.cpp`. Both
halves dead — the button has been clearing the displayed number and nothing else.

*Push fake depth to KLF view* is gone from v2. Olav: *"We actually do not need this setting
at all... Now we can make screenshots running demo, and then depth value is always
correct."*

Classic's bottom-track *min depth evaluation* list reads `[0.0, 0.5, 0.10, 0.15, ...]` —
`0.5` where `0.05` was meant, second in a list that continues at `0.10`. Olav: *"That 0.5 was
clearly a typo."* v2 uses the corrected ascending list; classic still has it.

---

## The live device parameter state (14 Sept 2026, `0608cef4`)

The largest change of the day, and it came out of wiring one expert group.

### What was wrong

Thirty runtime values are `property X: committedProfile.X`. **Sixteen of them were assigned
somewhere** — forty sites across `DeviceItem`, `PulseAppClassic`, `PulseConnectionScreen`,
`PulseInfoExpert` and `main.qml`; `transFreq` alone from eleven places. An assignment
destroys a binding permanently, so **after the first touch the value stopped following the
committed profile.** Nothing changed on a swap, so none of `DeviceItem`'s `onXChanged`
handlers fired, so the new device was never told anything.

`distProcessing` was worse. The binding hands back the **profile's own array**, so
`distProcessing[5] = v` edited `distProcPulseRed` in place — the control rewriting the record
it reads its own default from, for every later read including one after swapping back.

### What it is, and the question that named it

Called an "expert override" first. Olav's question corrected it: `DeviceItem` writes
`chartSamples` from the depth engine on every resolution step, so the same store holds engine
output, configuration output and an expert's experiment. It is the **live parameter state**,
kept per profile, seeded from the profile.

```
the profile record           the default for this device
       |
liveParams[profileKey]       whatever anyone has set on top
       |
the property (readonly)      what everything reads
```

Three rules fall out with no special cases, and they are exactly the three Olav asked for:

- **Runtime**, so every app start returns to profile defaults — an expert trying samples on a
  new SIYI device *"will need to start from scratch at app start"*.
- **Keyed by profile**, so a red's state and a blue's never mix — *"the modifications should
  be for the (either) blue or red"* — and swapping away and back within a session finds the
  experiment still there.
- **Readonly**, so no stray assignment can destroy a binding again.

### The question that decided whether it works at all

Olav: *"The C++ needs to be told we change a lot of these parameters in QML. DeviceItem
typically surveils the pulseRuntimeSettings and then writes using the linked methods."*

It keeps working, untouched. Those handlers watch the property's **change signal** —
`function onChartSamplesChanged() { dev.chartSamples = ... }` — and a readonly property with
a binding emits that exactly as an assigned one did. QML does not distinguish *changed
because someone assigned it* from *changed because the binding re-evaluated*. All ten
handlers are untouched, and a swap now makes the values actually change, so the device
finally gets configured.

### Three things worth knowing before touching it

**`setParam` builds a new object** rather than mutating the map and assigning it back. A
`var` property handed the same reference has no reason to emit its change signal, and without
that signal nothing re-evaluates and the whole mechanism silently does nothing while looking
correct. It is the same mistake one level down that let the old controls edit the profile's
array: reusing a reference someone else holds.

**`soundSpeed` is deliberately outside the map.** Everything in it is per-device; sound speed
is a property of the water. Olav: *"should I change to another transducer then my changed
speed value in the setting should win over the profile sound of speed."* It has its own
`soundSpeedOverride`, runtime, and nothing clears it.

**The runtime bus had a dynamic writer no scan could find.** `main.qml:264` writes every
echoed key back by string, which produced `Cannot assign to read-only property
"maximumDepth"` on the first build. Managed keys are skipped there now, the same way
`uiVariantIsV2` is — and it loses nothing, because the C++ publishes only `devName` and a few
uuid keys onto that bus, so every managed key on it is a value QML sent out.

### What it did NOT fix

Confirmed on the device: **the device-change problems are not fixed.** Olav: *"I have lived
with these issues through series of builds now, and while the app behaves partly terrible I
think we can fix fairly efficient."* It is the last step before phone sizing.

The colour half was never going to be this: `colorMapIndexSideScan` and `colorMapIndex2D` are
stored preferences, not profile-bound. That remains the deferred **blue gets red's colour
choices and favourites**, and **the re-test after the `a98fe9e9` injection fix is still
owed** — along with the logcat check for `SETTINGS: persistent settings injected into
pulseRuntimeSettings -> ok`.


---

## Where the next session picks up — the view chooser and split screen (14 Sept 2026)

Olav's scope, given at the close of the settings session. **This is the feature the upstream
author has and the Pulse app never had**, and it replaces a control rather than adding one.

### What it replaces

**The side/down view chooser is totally redundant** once this exists — the layout choice
subsumes it, which is the decision already recorded under the roadmap above: the rail's
button count does not grow.

**The old green pill is to be removed.** It swapped between side/down scan and the mosaic;
upstream has a draggable handle where the Pulse legacy control simply moved the split between
0 and 100 %. It appears to have been gone for some time already. Neither survives.

### The six views

**A 2D transducer needs none of this** — there is one picture and no second pane to offer.
Everything below is a side scan.

| | Top | Bottom |
|---|---|---|
| Single | down scan | — |
| Single | side scan | — |
| Single | mosaic | — |
| Split | side scan | down scan |
| Split | side scan | mosaic |
| Split | down scan | mosaic |

**The choice is persisted.** A screen preference is exactly the kind of thing a user sets
once for how they work, so it is a `pulseSettings` key, not a runtime one — the opposite of
the live parameter state.

### The open design question, and Olav's own steer

*"We need some way to illustrate these options, like other echo sounders have. Maybe we could
use our current icons to illustrate side and down? For mosaic perhaps a sweep with pattern?
Maybe check how others do this first and offer some suggestions?"*

So the next session **researches before designing**: how Garmin, Humminbird and Lowrance draw
their screen-layout chooser — they all have one and it is a solved convention — then offers
suggestions rather than picking one. `pulse_view_down_scan.svg` and `pulse_view_side_scan.svg`
already exist and are candidates for the two halves of each tile; the mosaic has no icon yet.

**Design first, as with the connection screen, the setup card, the loupe and the settings
hierarchy.** The hierarchy was settled from three treatments drawn at the panel's real width,
which cost one message and no device build; the same approach fits here, where the question is
entirely visual.

> **ANSWERED below** — see *The screen chooser, and the row that should not have been there*.

### What this unparks

The per-pane state object, and backlog items 12 and 13 with it. They were parked **on V2**, to
be raised when the control they belong to is built — and this is that control. `pulseSettings`
and `pulseRuntimeSettings` are global singletons, so **per-pane range has nowhere to live**;
the minimal shape is a small per-pane state object owned by `PulseApp.qml` with everything
else still reading the singletons. Settle it before the split-screen behaviour is touched.

From the market scan: **per-pane controls with the active pane outlined** (Lowrance states it
explicitly) is the established answer to "which pane am I adjusting". Shared across panes:
colour, intensity, water body filter, pause, record. Per pane: range only.

### And the order after it

1. **The four Expert info groups** — forty-eight read-only rows, mechanical, and the place
   duplicated abilities will show up as a value displayed in one group and set in another.
2. **Split screen** — this section.
3. **Bug fixing**, which Olav wants as the last step before phone sizing. The device-change
   problems survived the live-parameter-state work: *"I have lived with these issues through
   series of builds now, and while the app behaves partly terrible I think we can fix fairly
   efficient."*
4. **Phone size**, deliberately last.

**Still owed and now several sessions old:** the logcat check for `SETTINGS: persistent
settings injected into pulseRuntimeSettings -> ok` with no ReferenceError above it, and the
re-test of whether PULSE blue still takes red's colour choices and favourites.

**Still with Olav and blocking nothing:** the boat run with two transducers, the real swap,
the PULSEblue-IP acceptance test. And `feature/device-profiles-step4` has still not been
merged to master, with `feature/pulse-ui-v2-rail` now **64 commits unpushed**.


---

## The screen chooser, and the row that should not have been there (14 Sept 2026)

**`feature/pulse-ui-v2-rail`, 64 commits, unpushed.**

| Commit | What |
|---|---|
| `71a415a9` | the screen chooser, and what it took the place of |
| `7b54cefb` | the three full screens apply, and the screen preference becomes what decides the picture |

### The market scan, which settled the shape before any drawing

All three benchmarks answer this the same way, and it is not the obvious way: **the layout
and its contents are one choice, shown as one picture of the resulting screen.** Nobody asks
"how many panes" and then "what goes in each" on the everyday path.

- **Lowrance HDS Live** — press and hold an application button on the Home page and you get
  its *quick split pages*: "Each full screen application has several pre-configured quick
  split pages. They show the selected application combined with one of the other panels."
  They are fixed: "The number of quick split pages cannot be changed, and the pages cannot be
  customized or deleted." That is Olav's six views exactly.
- **Humminbird HELIX** — a flat list of named views, model-determined, cycled with the VIEW
  key. Combos are presets, not composable: "The available combo views are determined by your
  Humminbird model."
- **Garmin echoMAP** — Combos are named preset pages. The two-question wizard
  (`Combos > Customize > Add`, first function, second function, "Select **Split** to choose
  the direction of the split screen") is the CUSTOMISING path, not the everyday one.

So the six views were never a compromise; they are the convention.

**And the per-pane answer was already written down.** Lowrance states it outright: "In a
multiple panel page, only one panel can be active at a time. **The active panel is outlined
with a border.** You can only access the page menu of an active panel." Tap a panel to
activate it. Humminbird calls the same thing the Active Side.

### Three treatments, and the one that fits the menu already there

Drawn at the panel's real 360 px, as with the connection screen, the setup card, the loupe
and the settings hierarchy — a 2×3 tile grid, a six-row list, and three-and-three under
Single/Split headings. Olav chose the **list**: *"should fit well with our current fall out
menu."* `PulseScreenGroup` is `PulseChoiceGroup`'s row with a screen picture where the icon
was, so the panel gains no new row shape and scrolls in the Flickable it already has.

### The marks are drawn, not loaded, and that is the point

Three new SVGs for the three halves would be three more files that could ship declaring no
colour and draw black on a black panel — how three rail controls went missing on 13 Sept.
`PulseScreenMark` is a `Canvas` and every fill in it is a named colour **in that file**, so
`tools/pulse-icon-check.js` has nothing to find and nothing to miss. The settings chevron was
drawn from two rectangles for the same reason.

A Canvas rather than Rectangles because the mosaic is a trapezoid and the bottom is a curve;
rotating a rectangle into place would be a worse lie than drawing the shape.

Of three mosaic candidates — a tiled swath in plan view, a sweep with a dotted pattern, and
the 3D ground receding in perspective — the **tiled swath** was chosen. It says what the
mosaic IS rather than what the sonar does to make it.

### The rail's button count does not grow, and the model it reads changed

The screen chooser took the **view chooser's place**, which is the decision already recorded
under the roadmap. One button, two questions, exactly as before: a **Cone** on red, a
**Screen** on blue.

But it does not read what the view chooser read:

> A view or a cone is a **hardware** choice — you cannot change the cone of a transducer you
> do not have — so those follow the committed profile. A screen layout is a thing you judge
> by **looking** at it, so `offersScreenChoice` reads `displayIs2DTransducer`, and a side
> scan log played back on a red device keeps its layouts.

That is rule 1 applied, not a new rule.

### The frequency the view chooser was also answering

The old chooser answered two questions at once — what the **transducer** does (mode and
frequency, through `setParam("transFreq", v.freq)`) and what the **screen** shows. The screen
chooser answers only the second. Nothing is lost today because **every view blue offers is
460 kHz**; the 820 kHz pair is commented out. Olav: *"Now we only offer 460 for most. Let us
keep it like that. We should allow a frequency chooser later when power is fixed."*

### Side over down, and the row that has no data behind it

Asked whether the device gives side and down at once, Olav: *"Not really. It is, right now,
no true downscan. Right now it is a single channel of choice only. But people want it. We
should work with interpolating the two channels into one view for downscan."*

The honest answer to that is to leave the row out — absent rather than greyed, the rule the
settings list already follows. **That is not the answer he gave:** *"Allow downscan view
already now. We use the same source as for downscan today. Fix it later."*

So the split draws **both panes from the one channel**, as the full-screen down scan already
does, and the difference between the halves is the grid and the range rather than the data.
`offersSplitSideDown` is the one place that knows, so the row can be withdrawn in one edit if
the stand-in reads worse on the water than no row at all. When the interpolated down scan
exists it replaces the bottom pane's source and the entry table does not change.

### The split axis, asked twice and answered differently the second time

*"Side scan on top in landscape"* was the first answer. The second, a message later, was a
doubt worth more than the answer: *"I have a feeling that a landscape tablet may handle
mosaic as a vertical split screen better. Just a hunch. Garmin & co likely know better than
me."*

**They do, and what they know is that it is not one rule.** Two of the three do not fix the
direction at all — they make it a choice. Garmin: *"Select **Split** to choose the direction
of the split screen (optional)."* Lowrance's page editor: *"Change the panel arrangement (only
possible when 2 or more panels)"*, with panel sizes adjusted separately through
`System Controls > adjust splits`. Only Humminbird ships it fixed, and Humminbird ships
combos its model chose.

So the hunch is right, and the reason it is right is not about landscape. It is about what
the two panes have in common:

> **Panes that share an axis stack along it. Panes that do not, split the screen's long way.**

- **Side + down** are both scrolling echograms on the same time axis. Stacked top over bottom,
  the same feature sits at the same horizontal position in both and the eye can carry it from
  one to the other. That is worth keeping in landscape, which is what "side scan on top" was
  reaching for.
- **Anything + mosaic** shares nothing. The mosaic is a map and wants area in both directions;
  halving a wide screen top-over-bottom leaves it a letterbox showing a thin strip of ground,
  while halving it left/right leaves two near-square panes. So the mosaic splits along the
  long side — left/right in landscape, top/bottom in portrait.

**"Side scan first" survives as leading position** rather than as "top": top in portrait, left
in landscape. Note that this is the OPPOSITE of the arrangement in the file today, where
`scene3dContainer` is the first pane and `plotsContainer` the second — the echogram would move
to the left of the mosaic.

`PulseScreenMark` draws every split top-over-bottom, which is now true of only one of the
three. It follows the pane arrangement when the splits are built, not before.

**And the Garmin/Lowrance answer itself — make the direction a user choice — is deliberately
not taken.** The whole point of this control was that the rail's button count does not grow.
A default that is right is worth more than a setting that asks.

### What this unparks after all

The row Olav put back is the row that needs a second echogram pane, so **the per-pane state
object is back on** — and with it backlog items 12 and 13. Only `split_side_down` needs it:
every other split is one echogram pane plus the mosaic, and the mosaic has no range.

Shared across panes: colour, intensity, water body filter, pause, record. **Per pane: range
only**, which is not a nicety — the side half's range is swath width and the down half's is
depth, and they are different numbers for the same water.

### Where the next session picks up

1. **Settle the per-pane range shape**, then apply the three splits on the axis rule above.
2. **Remove what it replaced** — `applyViewId`, the rail's view branch, and the green pill —
   and only once the full screens are proven on the water. *"Now the green pill is back, and
   that is the only way I can swap between mosaic and the side scan view I have."*
3. Then the order Olav set: the four Expert info groups, **bug fixing** (the device-change
   problems, still not fixed), and phone size last.


---

## Bug fixing, groups A and B (15 Sept 2026)

**`feature/pulse-ui-v2-rail`, 81 commits, unpushed. None of this is compiled or on a device.**

| Commit | What |
|---|---|
| `d75e4f12` | the rail lights the button whose panel is open |
| `e8634060` | one applier for all three ways a source is chosen |
| `689e33f7` | opening a file takes the connection screen down |
| `65ed7074` | choosing a new source stops the old one first |
| `b5849994` | `applyEchogramMode` reads the range key instead of naming one |

### The fault shape, confirmed twice more

The backlog states it once and uses it to predict where the next one will be found:

> A flag or a call whose only writer lives in the classic UI reads false in v2, and the
> branch nobody tested is the one that runs.

Group B produced two more instances, and the second is the more interesting of the pair.

**The plain one.** `awaitingUserChoice` and `connectionScreenRequested` are what hold the
connection screen up. Committing a card cleared both; `enterDemoMode` cleared both, inline,
in its own body; the file path cleared neither. So the screen the user went through to reach
*View a file* stayed up over the file it had just loaded. The clears now live in
`answerSourceQuestion(how)` and all three paths call it — the shape the group is about,
applied to the group's own fix.

**The one worth remembering.** `chooserAsking`'s third term guarded on `isPresentingLog`,
and that read *looks* right. It is not, because `isPresentingLog` is a question about the
**profile** and carries two conditions this term must not inherit:

- it requires `activeModel !== ""`, and an opened file has no model until its channel list
  arrives. With nothing ever committed — **a cold start, which is exactly when the welcome
  screen is up** — `activeModel` falls back to the committed model, which is `""`. So
  through the whole of the open the guard read false.
- it requires `!hasConnectedDevice` for the file case, because an opened log must never
  reconfigure a transducer that is plugged in. True for the profile and wrong here: opening
  a file **is** an answer to "what am I looking at" whatever is connected.

So the fault is not a missing writer this time, it is **a property borrowed for a question
it was not answering**. `logIsOnScreen` is the plainer question — is there a log on screen or
on its way — and it is the one that term always wanted. Worth watching for: this UI now has
several derived booleans about the source, and the next defect of this class will be one of
them read in a place that needed a neighbour.

### One list, and the second trigger it needs

`mainview.applyForSource(reason)` is the backlog's "a source has been chosen — apply
everything the picture needs". The backlog says the commit path had it and the other two did
not. **The commit path did not have it either:** `onUserManualSetNameChanged` ran two of the
six applies, and the only near-complete set was the colour block's `Component.onCompleted`,
running once at startup. Two partial lists, no complete one.

**Range last, and that is ordering rather than taste.** `applyScreenId` → `applyEchogramMode`
writes `isSideScan2DView`, which is what `displayMaxRangeKey` is keyed on, which is what
`displayMaxRange` reads. Applying range first applies the outgoing mode's number.

**And the trigger no call at the moment of choosing can replace.** A log does not say what it
is until its channel list arrives — several frames after the dialog closed — so the applier
also runs on `presentedModel`. That is the half that makes the picture adapt to the log
rather than to the last device, and it is exactly Olav's own reframing of the whole group:

> *"Seems most problems are related to having the UI self-adapt to the chosen log file."*

Note what it does **not** do: `presentedModel` does not move when a blue log is opened on a
committed blue, which is the case he reported as already working. The applier is silent
there, and that is the design rather than a gap.

**The file-open call is in `onSendIsFileOpening`, not beside a dialog.** That handler is the
one point every route to an opened file passes through — the connection screen's *View a
file*, the drag and drop, the menu bar's open. Three calls at three dialogs would have been
three places to forget, which is the shape this group exists to stop.

### Stopping the old source, and the frame that must not exist

`enterDemoMode` returned early on `isInDemoMode`, and `Core::startDemo` refuses outright
while `isDemoMode_` is set — so choosing a second recording logged *"already running"* and
did nothing, with nothing on screen to say why.

The swap calls `core.stopDemo()` and **not `exitDemoMode()`**. exitDemoMode's other half is
backlog item 9 — clear the committed model, reopen the live links, ask for re-detection —
which a swap would undo two lines later, with the app hunting for a transducer in between.
`stopDemoPlayback(why)` is that same half on its own, and it is the mirror of what
`enterDemoMode` already does to a file view it is replacing.

**`isInDemoMode` stays true across a demo-to-demo swap, deliberately.** Lowering it drops
`isPresentingLog` and `logIsOnScreen` for a frame, and with nothing committed — a demo from a
cold start, which is most of them — that frame is the connection screen coming back over the
file being chosen. The same reasoning puts `stopDemoPlayback` **after** `wasKlfFileOpened` is
raised on the file path. Both are one-frame gaps that only appear on the cold-start path,
which is the path least likely to be the one being tested.

### The rail, and the line that is gone rather than repeated

The backlog offered two shapes and named the second as the one that stops the defect
recurring. That is the one built: the `ColumnLayout` declares `openGroup` **once** and each
`PulseRailButton` compares its parent's value with its own `buttonId`, so a new button lights
up with **no line at all**.

The parent read is the one implicit thing in it, and it is implicit because QML ids do not
cross files — `PulseRailButton.qml` cannot see `rail`. The `undefined` test is what makes it
safe, and `openGroup` stays settable at the call site for a button ever nested somewhere
other than the column. The empty-string test is not belt and braces: `collapse` and
`backToClassic` carry buttonIds and open no group, and `""` is also a closed panel, so
without it every button would light at once whenever the panel was shut.

### Where the next session picks up

1. **Build it in Qt Creator and put it on the tablet.** Nothing here is compiled. The logcat
   to read is `SOURCE:` — it prints the reason, the presented model, 2D or side scan, and the
   range key on every apply, so a path that applies nothing is visible as a missing line
   rather than as a wrong picture.
2. **Group C**, which is C++ and is the one thing in the demo path this session did not
   touch: the restart lives in `Core::onDemoFinished` and loops whenever `demoLoopEnabled_`
   is set, knowing nothing about the pause. Note the branch already carries two uncompiled
   C++ changes, so that build is overdue on its own account.
3. Then **D**, which wanted B finished before it could be judged, and **E** last of the
   tablet work.

**Still owed and now several sessions old:** the logcat check for `SETTINGS: persistent
settings injected into pulseRuntimeSettings -> ok` with no ReferenceError above it, and
`feature/device-profiles-step4` still not merged to master.


---

## Session close — 15 Sept 2026, the bug-fixing session

**`feature/pulse-ui-v2-rail`, 94 commits, unpushed, clean tree.** Groups A, B, C and D-1 are
built and device-confirmed. Everything after group C is QML only, so the next build needs no
`moc` round.

The blow-by-blow is in `pulse-bug-backlog.md`, which was rewritten as the work landed and is
the file a cold session should read first. What belongs *here* is the three things this
session taught that outlive the bugs.

### One: the fault shape has a second form, and it is harder to see

The backlog states the first form and uses it to predict:

> A flag or a call whose only writer lives in the classic UI reads false in v2, and the branch
> nobody tested is the one that runs.

Group B produced a textbook instance — `awaitingUserChoice` and `connectionScreenRequested`
cleared on two paths out of three. But it also produced this, which is **not** a missing
writer:

> **A property borrowed for a question it was not answering.**

`chooserAsking` guarded on `isPresentingLog`, and that read looks right. It is not:
`isPresentingLog` is a question about the **profile** and carries two conditions the guard must
not inherit — it needs `activeModel !== ""`, which an opening file does not have until its
channel list arrives, and it needs `!hasConnectedDevice`, which is true for the profile and
wrong for "is a log being looked at". On a cold start, the exact case where the welcome screen
is up, the guard read false for the whole open.

The cure was a plainer property, `logIsOnScreen`. The warning is that **this UI now has several
derived booleans about the source**, and the next defect of this class will be one of them read
somewhere that needed its neighbour. When a guard looks right and behaves wrong, check what
question the property was written to answer before checking its value.

### Two: "not implemented" was twice "implemented and switched off"

The mosaic TVG was reported as missing. `EchogramSideScanTvg`, the per-epoch
`ssTvgCompensated` buffer, `MosaicProcessor::ensureMosaicSource()` / `mosaicSourceBuf()` and
`qPlot2D::setSsTvgMosaicEnabled` were all in the tree, wired end to end. The default was
`false` and the switch was in the expert tier. The same session found the mosaic's black point
wired to the water body filter — not a missing feature either, but a wire into the wrong
socket.

**So the first move on a "we must implement X" is a search for X, not a design for it.** Both
of these were one-commit changes that had been described for weeks as work.

### Three: rule 2 needs `readonly` to be a rule rather than a hope

`echogramTvgEnabled` and `sideScanTvgEnabled` were bindings on `activeProfile` that the expert
controls assigned to. Classic's rows even carried `writeBackOnUserActionOnly: true` with a
comment naming the exact failure — *"otherwise the first device identification kills the
profile binding"* — which narrows the window to a real click without closing it. **A real click
is what the control is for.**

One binding plus one override is only half the rule. The other half is that the value is
`readonly`, so the next control that reaches for the old spelling fails loudly on its first
click instead of quietly ending the profile's say for the rest of the run. Three properties now
have that shape and there are no writers left to any of them.

### Where the next session picks up

**The manual-choice matrix at the end of the backlog, and nothing else first.** Olav isolated
the variable — start, choose the model, then play a log of that model — and blue is clean on
every row while red fails on exactly two. Both are predicted to be one fault: no 2D picture
ever gets an orientation written, because `applyEchogramMode` is reachable only through
`applyScreenId`, which returns early unless `offersScreenChoice`, which is
`!displayIs2DTransducer`.

The prediction is falsifiable and should be tested as one: **one fix, two rows.** If the
orientation closes and the range does not, `applyMaxRange`'s branch on
`panes[i].isViewHorizontal()` is a second fault.

After that, and in this order: D-2, which is blocked on a single `THEME:` log line and must not
be coded before it is read; then E, the split-screen pass; then phone sizing. The two larger
ideas — a file-side prescan and burst playback — share their expensive step and should be
designed together, not grown separately.

---

## The 2D orientation, written at last — rows 3 and 4 (15 Sept 2026, `a47c1114`)

The prediction held, and reading the path end to end sharpened it in two places. One of
them changed the fix; the other changes how it is falsified on the device.

### It is not "row 4 follows from row 3". Both rows follow from the same uncalled function

The backlog derived the range failure *from* the orientation failure, and that reads
plausibly but is one step too long. `applyEchogramMode` does **two separate things**, and
red was missing both:

- it writes `isSideScan2DView` / `isHorizontalGrid`, which reach `grid_`, `plot_` and `aim_`
  over the settings bus — **row 3, the orientation**;
- it restarts one of the two 10 ms timers, and *the timer* calls
  `setHorizontalNow()` / `setVerticalNow()` **and** the matching
  `plotDistanceRange2d()` / `plotDistanceRange()` — **row 4, the range law**.

Those are two different pieces of state. `isHorizontalGrid` is a QML preference published
over the bus; `isHorizontal_` is a private C++ member of `Plot2D` whose **only** writer is
`setHorizontal(bool)`, reached from `setHorizontalNow()` / `setVerticalNow()`, reached from
those two timers. `applyMaxRange` branches on `isViewHorizontal()`, which reads that member.

So the prediction — one fix, two rows — is right, for a better reason than the backlog gave.
It is not a cascade. It is one function that nobody called, carrying both answers.

### The call could not simply be made: `applyEchogramMode` had the polarity bug inside it

```
var down = (mode !== "side")
pulseRuntimeSettings.isSideScan2DView = down
```

Correct for the only caller it had ever had. A lie for a red, and an expensive one:
`flipImage = isSideScanOnLeftHandSide_ && isSideScan2DView_` in **both** `plot2D.cpp:460`
and `plot2D_grid.cpp:104`, so a red would have rendered mirrored with its ruler inverted,
and `PulseDepthEngine.pictureIsSideScan` would have changed its mind about which depth
source to trust.

**Classic had already answered the question**, which is the second instance this week of
"read what is there before designing". `PulseAppClassic.setUserInterface()`, the
`showAs2DTransducer` branch, sets the grid horizontal, ranges with `plotDistanceRange2d`,
and **does not touch `isSideScan2DView` at all**. Horizontal, and not a side scan.

The property asks *"is a **side scan** being drawn as a 2D picture?"*, and a 2D transducer
answers no however the picture flows:

```
var sideScanShownAs2D = down && !pulseRuntimeSettings.displayIs2DTransducer
```

`chartOffset` moved onto that same condition rather than onto `down`. It is a
blue-in-downscan correction — a red has nothing to offset — and it is a `setParam`, a
**device write**, which D-1 says should not fire on a file path without a reason.

### The guard was the second fault shape, and that is why reachability was the fix

The backlog offered two shapes and preferred the second. The second is right, and the reason
is sharper than "it stops it recurring":

```
if (pulseSettings.uiVariant !== "v2" || !pulseRuntimeSettings.offersScreenChoice)
    return
```

`offersScreenChoice` answers **"may the user pick a screen?"**. It was being read here as
**"does this picture have a layout?"** — and every picture has one. That is exactly *a
property borrowed for a question it was not answering*, the shape this session's close named
after `chooserAsking` borrowed `isPresentingLog`. Writing the orientation into
`applyForSource` instead would have left the borrowed read in place and added a second
writer beside it; rule 2 has an opinion about second writers.

**The guard stays and a branch is taken instead of deleting it.** The rest of
`applyScreenId` genuinely *is* the chooser's business: `screenForId()` for a 2D picture
returns a blue entry — side, mosaic, a split — and would pin panes that do not exist. A 2D
picture needs the mode half and nothing else:

```
if (!pulseRuntimeSettings.offersScreenChoice) {
    applyEchogramMode("down")
    waterViewFirst.setGridMode("")
    waterViewSecond.setGridMode("")
    return
}
```

`"down"` is the mode rather than a workaround: a 2D echogram is the same geometry as a blue
in downscan, and `applyEchogramMode` now tells the two apart **by the device** rather than
by the mode name it was handed.

### Blue is unchanged by construction

On the blue path `displayIs2DTransducer` is false, so `sideScanShownAs2D === down` and the
new branch is unreachable. **If blue regresses, the polarity is backwards** — that is the
whole of the blue-side test.

### How to falsify it, and the trap waiting in row 4

`applyEchogramMode` now logs:

```
MODE: down -> horizontal | side scan as 2D false | 2D device | range 13 from maxDepthValue
```

- **No `MODE:` line at all on a red** — the call is still unreachable and nothing here worked.
- **`vertical`, or `side scan as 2D true`** — the polarity is backwards.
- **The line is right and the picture is still vertical** — the write is not reaching the
  renderer, and the settings bus is the next place to look, not this function.

**The trap is row 4.** `applyForSource` calls `applyMaxRange()` immediately after
`applyScreenId`, and `applyMaxRange` branches on `panes[i].isViewHorizontal()` — which is
still the **outgoing** value, because the timer that sets it has not fired yet. Row 4 should
close anyway, because the timer re-ranges 10 ms later from the same
`quickChangeMaxRangeValue` with its own matching range call, and the timer is the last
writer. But if the orientation comes right and 13 still lands as about 2, **do not start at
`applyMaxRange`'s branch**: start at whether the timer fired. `applyMaxRange` asking the
*pane* how it is drawn, when the answer belongs to the *preference*, is the same borrowed-
property shape one layer down — and it is a separate commit if it bites, because it is a
separate idea.

**QML only, one commit, not compiled and not on a device.**

---

## The cold-start demo — two faults, and why the sweep missed one (15 Sept 2026, `3ef7249a`, `f0b4bcb3`)

Olav took the matrix one level further: **no manual model choice at all — start the app and
go straight to a demo.** Red was clean. Blue came up wearing red's palette, red's max depth,
red's intensity and water body filter, with **no chooser button on the rail at all** — and a
pill that correctly read *"Demo · PULSE blue"*.

That contradiction is the whole diagnosis. Two faults, and it is the pair that produces an
app stuck between two identities.

### One: the threading guarantee in `enterDemoMode` was not true

```
//Safe to emit here and not a frame later: demoIsSideScan is set during core.startDemo()
//above - the prescan reports before it returns
```

`Core::startDemo` ends by handing off to the `DeviceManager` worker with
`Qt::AutoConnection`, and that worker lives on `DevManThread`. Across threads that is
**queued**, so `demoPrescan` has not run when the call returns. The answer arrives several
frames later through `demoStarted` → `Core::demoPeriodChanged` → `onDemoPeriodChanged`, the
only place `demoIsSideScan` is ever written.

So `applyBlackStripesToCore` and `sourceChosen("demo")` both read a stale flag. **Stale is
`false`, and `false` is red.** A red replay passed on the default happening to be right for
it — the same accident that let the 2D orientation bug hide for weeks.

This is the first form of the fault shape wearing new clothes: not a writer living in the
classic UI, but a writer living **on another thread**. The branch nobody tested is still the
one that runs.

### Two: the settings bus destroys bindings, and no search could have found the writer

The pill was the evidence. It reads `presentedModel`, it said *blue*, and `presentedModel`
reads `activeModel` — so the classification **did** arrive and `activeModel` **did** move.
Yet everything gated on `displayIs2DTransducer` stayed red. The only way both hold is that
`displayIs2DTransducer` had stopped being a binding.

```
// main.qml, onRuntimeChanged
if (k in pulseRuntimeSettings) {
    pulseRuntimeSettings[k] = m[k]
}
```

`displayIs2DTransducer` is published to the bus, was not in `runtimeKeysQmlOwns`, and was not
`readonly`. The echo assigned it. **An assignment destroys a binding permanently** — rule 2's
exact failure, from a writer that is a *dynamic write by string*.

**The 15 Sept sweep could not have found this.** It searched for visible assignments and
concluded there were no writers left to any profile-bound property. `pulseRuntimeSettings[k]
= m[k]` matches no grep for a property name. The comment directly above that loop had already
named the hazard — *"a DYNAMIC write by string that no static scan could find"* — about
`maximumDepth`, and the lesson was not generalised.

**`SettingsBus::flushRuntime()` diffs and emits only changed keys**, which is what made this
intermittent rather than constant. The echo, and the binding's death, land on the first tick
where the value actually moves, so the property **freezes at the first answer it ever gives**:

- *commit a device, then play its log* — freezes on the committed device, which is right, and
  nothing looks wrong. This is why every earlier test passed.
- *cold start straight into a demo* — fault one makes `activeModel` red for a frame, and it
  freezes on **red**, permanently.

And it explains why Group B's `onPresentedModelChanged` repair never repaired anything: the
properties it was meant to move had lost the ability to move.

### The chooser button, and why "both are missing" was one control

`PulseRail` has **one** button for this: `buttonId: rail.offersCone ? "cone" : "screen"`,
`visible: rail.offersScreen || rail.offersCone`. With `offersScreen` frozen false (red) and
`offersCone` false because blue has only one cone, neither question claimed it and it vanished.
Not two controls missing — one control that nothing asked for.

### The sweep, done properly this time

Every key `main.qml` publishes to the runtime bus, against what it is in
`PulseRuntimeSettings`:

| key | what it is | protected before |
|---|---|---|
| `displayIs2DTransducer` | binding on `activeProfile` | **no** |
| `is2DTransducer` | binding on `committedProfile` | **no** |
| `maximumDepth` | `readonly`, managed parameter | yes, via `isManagedParam` |
| `uiVariantIsV2` | `readonly` | yes, already listed |
| the other eleven | plain properties, written imperatively | assignment is intended |

Exactly two. Both are now `readonly` **and** in `runtimeKeysQmlOwns` — the `uiVariantIsV2`
shape, which is rule 3 verbatim: the list makes the echo a no-op, and `readonly` makes the
next writer fail loudly on its first attempt rather than quietly ending the app's ability to
tell a red from a blue. The C++ only *reads* these two in `applyRuntime` and never pushes
them, so refusing them on the way back in loses nothing.

### Rule 3, restated because it needed restating

> **A binding that is published is a binding that will be assigned.**

Publishing a derived value to the settings bus puts it on a round trip, and the return leg is
a dynamic write. Any binding on that trip needs `readonly` plus a place in
`runtimeKeysQmlOwns`, and neither half is optional: the list alone leaves the next writer
silent, and `readonly` alone turns a working no-op into a thrown error.

### On the device

- `DEMO: the replay is classified - side scan -> applying the picture's settings` should
  appear **after** `DEMO: running at N ms/epoch`, and the `SOURCE:` line that follows should
  name the right model. If `SOURCE: demo` still appears before `DEMO: running at`, the move
  did not take.
- **The loop restart is the regression to watch.** `demoSourceClassified()` is guarded by
  `demoSourceApplied` because `DeviceManager` re-emits `demoStarted` on every loop restart;
  unguarded, `applyMaxRange` would snap the range back to the stored preference each time the
  file looped. Set a range by hand mid-demo and let the file loop — it must stay where it was
  put, and the classification line must not appear a second time.
- **Black stripes on a blue cold-start demo** were also wrong before this and were never
  reported — worth a look for gaps or empty columns now that they are right.

**QML only, two commits, not compiled and not on a device.**

---

## Per-picture preferences, and the handler that watched its own output (15 Sept 2026, `7dc2676b`)

With the cold-start faults fixed, Olav swapped between a red log and a blue log repeatedly —
the first time that has worked — and immediately found what the swap made visible: the
intensity and the water body filter do not move with the model. They never did.

The interesting part is not the feature. It is what building it exposed about the shape of the
existing wiring.

### The third instance of one pattern, and it should be a named pattern now

Three preferences are now per-picture, and all three have the same four parts:

| | key chosen once | derived read | one writer | applied by a handler on |
|---|---|---|---|---|
| colour theme | inline in `displayThemeId` | `displayThemeId` | `onThemeChosen` | `onDisplayThemeIdChanged` |
| max range | `displayMaxRangeKey` | `displayMaxRange` | `storeDisplayMaxRange` | `onDisplayMaxRangeChanged` |
| intensity / filter | `displayIntensityKey`, `displayFilterKey` | `displayIntensity`, `displayFilter` | `storeDisplayIntensity`, `storeDisplayFilter` | `onDisplayIntensityChanged`, `onDisplayFilterChanged` |

**The handler on the derived read is what makes a model swap free.** Nothing restores anything;
the key the read uses changes, so the value changes, so the handler fires. A restore path is
what this shape replaces, and a restore path is a thing somebody forgets to call.

**Only the display number splits.** For all three, the value the C++ actually consumes stays a
single shared key written by the applier — `colorMapIndexReal`, and now `intensityRealValue`
and `filterRealValue`. The applier is the only place that knows which picture's preference is
in force, so it is the only honest writer of the applied value. That also means classic, the
persistent bus and `Plot2D`'s pinch path need no changes at all.

### The handler that watched its own output

`onIntensityRealValueChanged` and `onFilterRealValueChanged` were the apply triggers. The
moment the appliers began *writing* those two keys, those handlers became an applier
triggering itself. It terminates — Qt emits `changed` only on a real difference — so it would
never have hung, and it would never have been noticed either.

**A handler belongs on the input, not on the output.** That is the same family as the two
faults this branch already has a name for:

> A property borrowed for a question it was not answering.

Here the property was not borrowed, it was *inverted*: the handler asked "has the applied value
moved?" when the question was "has the preference moved?". Those are the same thing right up
until the applier becomes the writer, and then they are a loop.

**Worth checking the rest of the file against this**, because it is cheap to look for: a
`Connections` handler whose body calls a function that assigns the very property the handler
is named after.

### Two-way, not three-way, and why the range is the exception

`displayMaxRangeKey` has three keys because a blue's **swath width** and its **depth** are
different physical quantities measured in the same unit — the number genuinely means something
else in each mode. Intensity and the water body filter do not change meaning when a blue goes
from side scan to downscan; they are brightness and a water-column cut either way. So they take
`displayIs2DTransducer`, the colour theme's split.

**The test to apply to the next one:** three keys when the number *means* something different
in the two blue modes, two when it is the same quantity judged by a different eye.

**QML only, one commit, not compiled and not on a device.**

---

## The obvious hook was the wrong hook, twice in one session (15 Sept 2026, `d8510413`)

The demo loop came back with every slider right and the picture ranged to two metres.
`Plot2D::setDataChannel()` ends by taking the plot's range from the dataset, the loop restart
rebuilds the channel list, and the range is re-derived from the first epochs of a file whose
bottom has not been acquired. The detail is in the backlog. What belongs here is the shape.

### A third form of the fault, and it is about time rather than about naming

The branch already has two:

> A flag or a call whose only writer lives in the classic UI reads false in v2.

> A property borrowed for a question it was not answering.

This session produced a third, twice:

> **The signal named after the event fires before the event has happened.**

`demoIsSideScan` was read in `enterDemoMode` because `core.startDemo()` had been called — but
that call is a queued hand-off to a worker thread, so the prescan had not run. And `demoLooped`
is emitted by `startNextDemoPass()` *before* its own queued `invokeMethod`, so a handler there
would apply settings the new pass has not yet had a chance to destroy.

Both signals are honestly named. Both fire at the moment the app *asks* for the thing, not at
the moment the thing has happened. **`Qt::AutoConnection` across a thread boundary is the tell**,
and this codebase hands work to `DevManThread` constantly.

**The rule that falls out of it:** repair a value at the signal that fires *after* the thing
that damaged it, not at the signal named after the action that will damage it.
`channelListUpdated` is emitted at the end of `onChannelsUpdated()`, downstream of the
`setDataChannel` loop, which is why it is the right hook and `demoLooped` — unused, obvious,
and inviting — is the wrong one.

### And a note on what makes a re-apply safe

The repair re-applies a stored preference on an event the user did not cause, which is
normally how you overwrite somebody's work. It is safe here for one checkable reason:
**every route by which a user changes the range writes the preference** — the panel slider
through `storeDisplayMaxRange`, the pinch through `PulseAppV2.maxDepthValue` into the same
writer. There is no way to hold a range that is not stored.

**That is the question to ask before adding any repair of this kind**, and it is the same
question the one-writer rule answers: if a control can change the picture without writing the
preference, a re-apply is a data-loss bug rather than a fix.

**QML only, one commit, not compiled and not on a device.**
