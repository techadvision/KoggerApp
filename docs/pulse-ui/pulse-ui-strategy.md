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

