# Echogram speed and high performance mode — analysis and implementation plan

*PULSE blue, red and black. Revisions: 27 Sept (Olav's answers), 29 Sept (hardware partner's input), 29 Sept (split into
tasks, red/black added, 50 ms period), 30 Sept (Olav's answers at the start of session 7). Checked against the KoggerApp code (1.39; render and pause code re-checked on
`feature/pulse-small-screens`). This is the reference for the implementation prompts. Chapter 12 is the same story told
for sales.*

## The plan in one page

**Task 1 — Echogram speed for everyone (all devices, all links, no warning).**
Speed becomes a pure display stretch of the echogram. It never touches the transducer, so it works on wifi and IP alike.
The side scan gets **True proportions**: the user sets boat speed (1.0–5.0 km/h, one decimal), and the picture keeps a
metre a metre in both directions. **Free** mode keeps today's look. The hard part is not the stretch itself but keeping
**pause → tap → loupe → add waypoint** correct under any stretch, including below 1.0. Task 1 is mostly that work.
Boat speed is user-set; setting it automatically from the autopilot is a later option on top, never a replacement.

**Task 2a — High performance mode, PULSE blue.**
On IP, or on wifi after an explicit warning: 5000 samples, finest spacing for the range, ping period 50 ms (51 ms at the
35 m swath). Across-track detail becomes 2.5× (35 m) to 12× (5 m) finer. The data rate is 3.5× today's blue.

**Task 2b — High performance mode, PULSE red and black.**
Same idea for the single-channel 2D sounders: keep the depth-following (auto max depth) and dynamic resolution, but with
5000 samples instead of 500. Spacing becomes **5–10× finer** at every depth. The period is 50 ms down to ~35 m and then
follows the physics (71 ms at 50 m, against today's 150 ms). The data rate is up to 10× today's red, so **the wifi
warning matters most here**.

**Order:** Task 1, then 2a and 2b (either order; 2a is smaller). 2a and 2b share one engine and one settings row, so
whichever comes second mostly adds a profile.

## Settled

**27 Sept (Olav)**

- **5000 × 3 mm = 7.5 m per side** (blue), confirmed, so range per side = `samples × spacing ÷ 2` holds for every case.
- **5000 samples is the firmware maximum.**
- **Boat speed**: slider, 1 decimal, 1–5 km/h, user-set.
- **Bottom that was never captured may stay black.**
- **Max depth drag**: the visible range follows the finger all the time; the transducer is reconfigured only when the
  drag slows or stops.
- **The blue prototype is its own model**, `Basic2D` (`modelPulseBlueProto`), and its 15 mm floor belongs to that model.
- **CHIRP blue**: new hardware id, its own treatment later; expert setters only for now.

**29 Sept (hardware partner, via Olav)**

- **Only the ping period stresses the hardware.** High sample counts and fine spacing are *not* a concern.
- **The partner proposes 50 ms** (today 70 ms on blue). Use it wherever 5000 samples still capture the full range;
  otherwise the full data response comes first and the stretch provides the speed.
- **Speed comes from stretching the image**, not from the period, and the side scan stretch must stay modest in Free mode.

**29 Sept (Olav)**

- **Split the work**: speed first (all devices, no warning), performance mode after.
- **Performance mode is not SAR-only.** Bait-boat users (on red, black and blue) and surveyors use the IP connector too,
  and 1+ km with no effort on the IP link is a major selling point. So red and black get a much better echogram as well.
- **The wifi warning is essential**, for every device.
- **Red/black's current dynamic scheme exists for wifi.** Few samples, spacing raised with depth to grow the visible
  echogram (and serve auto max depth) at a fixed ~60–68 kB/s. Beyond ~14 m the spacing stops rising because the
  rendering engine did not cope beyond 15+ m, and the period is raised instead, up to a very high value.
- **Red/black may keep the visible-echogram adjustment** (auto max depth). They are single channel, so at the same sample
  count they carry half of blue's data.
- **Boat speed stays a user setting.** Setting it from the autopilot is an ambition for later, and many users have no
  autopilot at all.

**30 Sept (Olav, session 7)**

- **Pause no longer drops to 1.0.** That was a workaround from the struggle to get pause → add waypoint right, and it
  confuses users. The code applied the 2D stretch **twice** (s columns per epoch in the column table, then a painter
  scale of s), which is fixed in slice A (below).
- **Boat speed follows the unit of the existing speed gauge** (km/h, m/s, mph, kn).
- **Only the pill shows the result**, and it stays up **5 s** after a change so the user sees what he did.
- **Ping period for True mode: the value the echosounder confirms** (Device parameters → ping period,
  `ch1Period_Copy`), not a measured one. *Note: with a recording on screen there is no device to confirm anything; the
  demo's prescan already knows the recorded period (`demoPeriodMs_`), and an opened file needs the same answer. To
  settle in slice B.*
- **No Free mode on the side scan.** It is always a true render. §5.3's Free column for the side scan is withdrawn.
- **2D standardises on km/h as well.** Design to come after the side scan.
- **Cap 3 with the "1 : 3.1" label**, to start with.
- **Split screen: each pane computes its own stretch.** The side scan stays true as in full screen; the down scan does
  what it does full screen.
- **While paused, nothing sits on the picture.** The user pauses to investigate; pills and other on-screen objects go.
- **Stored 2D speed values**: the decision is left to me, for Olav to review (see the backlog, session 7).
- **Rail: the speed button goes in the pinned (non-scrolling) part.**
- **Task 2 additions:** an expert **resolution floor** (minimum sample spacing), persistent slider **1–16 mm**, default
  1 mm (perhaps 2); High performance mode is a **persistent preference**; the wifi warning is for **192.168.10.x**, while
  the IP link (**192.168.144.x**) needs none.

## 1. What the current code says

**Display (Task 1)**

- **The stretch exists for the horizontal picture only, and only above 1.0.** `Plot2D::horizontalStretch()` returns
  `echogramSpeed_` only when `isHorizontal_`, unflipped and `> 1.0`. `getImage()` applies it as a **painter scale** on a
  canvas that is narrower by the same factor. The side scan (vertical flow) path rotates the canvas and never scales it,
  and `main.qml` forces `echogramSpeed = 1` for blue and blue-proto.
- **Pause switches the stretch off.** `main.qml`'s `setEchogramPaused(true)` writes `echogramSpeed = 1.0` for 2D pictures
  and restores it on resume. So today the paused picture is a *different* picture from the live one, one epoch per pixel,
  and the tap mapping only ever has to be right at 1.0. This is the workaround Olav's concern points at.
- **The tap → epoch mapping goes through `cursor_.indexes`.** `getEpochIndxByMousePos()` takes the screen column
  (`mouseX`, or `width − 1 − mouseY` for vertical) and returns `cursor_.indexes[column]`. The reindex
  (`head + round((x − W) / hor_ratio) − 1`) already handles fractional ratios, including below 1. What does not agree
  with it today is the painter scale, which is why pause falls back to 1.0.
- **The reverse, epoch → screen** (`getMousePosByDepthAndEpochIndx`, used to draw markers), returns the *first* column
  holding that epoch. At a stretch of 3 an epoch spans three columns, so a marker would sit at the band's edge rather
  than its centre.
- **`Plot2DAim` keeps its own copy of `echogramSpeed_`**, and on pause snapshots `rightmostEpochOnScreen()` and
  `visibleColsOnScreen()`. Both must mean the same thing under any stretch.
- **Across-track is drawn in metres, not samples** (`cursor.distance.from/to`), in the echogram and in the loupe. That is
  why a change of samples or spacing does not change the geometry, and it is what True proportions rests on.

**Acquisition (Task 2)**

- **Blue's *Side scan width* row** (25/35 m, `echogramWidth`) sets `chartResolution = echogramWidth` (mm) and
  `distMax = 1000 × echogramWidth` at a fixed 2000 samples — a data-rate workaround whose comment says *"Fits anglers,
  but not SAR."* The width stays as the range ceiling (`displayMaxRangeCeiling`).
- **Red/black's engine is `PulseDepthEngine.calculateDynamicResolution`**: spacing = `round(2 × (depth + margin))` mm at
  500 samples while that stays ≤ 50 mm, then spacing stays at 50 mm and samples (500–1020) and period (50–154 ms) grow
  instead. It returns early for anything but red and red-proto.
- **Spacing is whole millimetres** (`setChartResolution`, `uint16`) and is sent as a full chart setup with the *current*
  count, so spacing and samples go out as **two messages**, with a mismatched state in between. Send them in the order
  that shrinks the trace first, or better, use one combined setter.
- **Two writers to `ch1Period`**: `DeviceItem`'s `onDynamicPeriodChanged` writes it without checking
  `doDynamicResolution`. Performance mode must own it explicitly.
- **`PULSEblue-IP` unlocks** samples 500–12000 and period 20–300 ms in `ui.tunable`, still unused. Samples max becomes
  5000; the period floor becomes the partner's per-model value. **Red has no IP profile key yet**: the resolver sends a
  recognised red straight to `PULSEred`, and `pulse-profile-check.js` asserts *"red on the IP gateway is still red"*.
  Task 2b inverts that, as the strategy doc of 12 Sept anticipated.

## 2. Background — the budget

Data rate ∝ samples ÷ period. Expressed in samples per second (the byte rate adds the protocol overhead, so measure it in
the app):

| Device and mode | Samples | Period | Samples/s | vs its wifi today |
|---|---|---|---|---|
| Blue, wifi today | 2000 | 70 ms | 28.6 k | 1× |
| Blue, performance | 5000 | 50 ms | 100 k | **3.5×** |
| Red/black, wifi today | 500–1020 | 50–154 ms | 6.7–10 k | 1× |
| Red/black, performance | 2500–5000 | 50–71 ms | 50–100 k | **up to 10×** |

## 3. Background — limits from physics and hardware

**Ping period floor, physics side.** The transducer must listen for the whole range before pinging again:
`T_min = 2 × range ÷ c + margin`, with c ≈ 1480 m/s and a ~3 ms margin.

| Range (one way) | 5–25 m | 30 m | 35 m | 40 m | 50 m |
|---|---|---|---|---|---|
| T_min | < 40 ms | 44 ms | 51 ms | 58 ms | 71 ms |

- **Blue**: range is per side, at most the 35 m swath. **50 ms works up to ~34 m per side**; at the 35 m swath use 51 ms.
  So the partner's 50 ms is the period for blue in practice.
- **Red/black**: range is the full trace, up to 50 m (+ double echo). **50 ms up to ~35 m**, then the period follows
  `T_min`, reaching 71 ms at 50 m. That is still half of today's 150 ms at depth.
- **To confirm on the water**: whether the firmware adds per-ping time on top of listening (for example to ship 5000
  samples). If the epoch rate at 50 ms falls short of 20/s, the margin grows.

**Hardware limits belong to the model.** The link decides the budget, the hardware decides the limits:

```
hardwareLimits: {
    "PULSEblue": { spacingFloorMm: 1,  samplesMax: 5000, periodMinMs: 50 },
    "Basic2D":   { spacingFloorMm: 15, samplesMax: 5000, periodMinMs: 50 },  // blue prototype
    "PULSEred":  { spacingFloorMm: 2,  samplesMax: 5000, periodMinMs: 50 },  // floor as today's profile; 1 mm to confirm
    // PULSE black: same as red (confirmed). Red-proto: as red. CHIRP blue: its own entry when its id exists
}
```

The period floor is **the partner's number**. Expert rows are clamped to these limits, so nothing in the UI can push a
unit past what the partner has cleared.

**Spacing floor = sample rate** (`c ÷ 2d`). The Basic2D prototype stops at 15 mm, exactly 50 kHz, which suggests its board
tops out there. Production blue goes to 1 mm (750 kHz), and the partner confirms fine spacing is no strain.

## 4. Background — what is the correct picture?

**For a side scan, the truth is a metre is a metre in both directions**: a metre along the track takes the same number of
screen pixels as a metre across it. A tyre looks round, a boat as long as it is. The mosaic is true by construction
because it is drawn on the map. The waterfall only gets there if its along-track scale is set on purpose. As far as I know,
professional survey side scan software offers this (speed or aspect-ratio correction), while recreational units let range
and scroll speed distort freely. For a SAR-led product, true proportions is the stronger default.

```
across-track metres per pixel = 2R ÷ P         (R = visible range per side, P = pane width across-track in pixels)
along-track metres per ping   = v × T          (v = boat speed, T = the period the device reports)
stretch_true (pixels per ping) = v × T × P ÷ (2R)
```

**It does not collide with dynamic samples and spacing.** Those decide how much *detail* a ping carries across-track. The
*geometry* comes from the renderer's metre-based mapping: a 5000 × 2 mm ping and a 2000 × 25 mm ping land on the same
pixels, one sharper. Keeping proportions while max depth changes simply means **zooming both axes together**, like a map.

**The stretch it needs**, full-screen side scan, P ≈ 1600 (a split screen halves P and every number):

| Boat speed | 35 m | 25 m | 15 m | 10 m | 5 m |
|---|---|---|---|---|---|
| 1 km/h, T 70 | 0.44 | 0.62 | 1.04 | 1.56 | 3.1 |
| 3 km/h, T 70 | 1.33 | 1.87 | 3.1 | 4.7 | 9.3 |
| 3 km/h, T 50 | 0.95 | 1.33 | 2.2 | 3.3 | 6.7 |
| 5 km/h, T 70 | 2.22 | 3.1 | 5.2 | 7.8 | 15.6 |

- **Below 1** (long range, slow boat) the picture is *compressed*: several pings share a pixel row. Showing one ping per row
  is safe, because an object at that range spans tens of pings (the beam's along-track footprint there is decimetres, the
  ping spacing centimetres), so nothing is skipped over.
- **Large values** (short range) are the truth showing through: the boat moves 58 mm between pings while a pixel across
  covers 6 mm. What looks bad at large stretch is blockiness; **interpolate between neighbouring pings above ~1.5**.
- **So: hold true proportions up to a cap** (start at 3), and beyond it let the picture be shortened along-track and **say
  so** with a small label in the pill column, for example **"1 : 3.1"**. With cap 3 at 3 km/h, true proportions hold down to
  ~16 m full-screen at 70 ms, ~11 m at 50 ms, and further in a split screen.
- **The 50 ms period of Task 2a helps directly**: the same proportions need 30% less stretch.

**For 2D (red, black, blue's down scan)** 1:1 is not best practice. Depth is metres against hundreds of metres travelled,
and every 2D sounder exaggerates vertically; users read slopes that way. The steeper-looking bottom when max depth
changes is normal 2D behaviour. A constant exaggeration (slopes that don't change with range) is possible later, but is
not part of this work.

## 5. Task 1 — Echogram speed for everyone

**Scope**: every device, wifi and IP, no warning. Display only; the transducer never hears about it.

### 5.1 One stretch mechanism, in the column mapping

- **Move the stretch out of the painter and into `cursor_.indexes`.** Every screen column maps to an epoch at full canvas
  resolution: a stretch of 3 repeats each epoch over three columns; a stretch of 0.5 puts every other epoch in a column.
  Drop the painter scale and the narrowed canvas. Then drawing, tap, loupe, bottom track, markers and the scroll clamp all
  read **one mapping**, and there is nothing left for a tap to disagree with.
- **Both orientations.** Generalise `horizontalStretch()` into one `stretch()` that applies to the vertical (side scan) path
  too, and allow values below 1.0.
- **Interpolate between the two neighbouring epochs** when a column sits between them and the stretch is above ~1.5. This
  is a render choice only; the mapping still names one epoch per column for taps.
- **Epoch → screen returns the centre of the epoch's band**, not the first column, so markers sit where the ping is drawn.

### 5.2 Pause keeps the picture

- **Remove the pause-time reset to 1.0** in `setEchogramPaused`. What was on screen when the user paused is what he taps
  on. Freezing into a different picture is exactly what makes a waypoint land somewhere unexpected.
- **`Plot2DAim`'s snapshots** (`lastIndexAtPause_`, `visibleColsAtPause_`) are taken after the reindex, so under the new
  mapping they describe the stretched picture. Its private `echogramSpeed_` copy should read the same `stretch()`
  rather than keep its own.
- **The stretch is frozen while paused.** Changing speed or range while paused must not reflow the picture under the
  crosshair. It applies on resume.
- **The position chain stays epoch-based**: tap → column → epoch (position and yaw at that ping) + across-track distance
  → waypoint. The stretch changes only *which column* shows an epoch, never the epoch's position, so the waypoint maths is
  untouched. The one precision note: in compressed rows a tap picks the ping drawn in that row, at most one ping
  (a few centimetres) from its neighbour.

### 5.3 The controls

| | **Side scan pane** | **2D and down scan panes** |
|---|---|---|
| Mode preference | **"Side scan proportions: True / Free"** (segmented row), **default True** | always Free |
| True | **Boat speed** 1.0–5.0 km/h, one decimal, default 3.0; stretch = `stretch_true`, capped | — |
| Free | **Echogram speed** 1.0–2.0× (modest, per the partner) | **Echogram speed**, today's control and range, now pause-safe |
| Max depth | True: zooms both axes. Free: across-track only | across-track (depth) only |

- True reads **the period the device reports** (`ch1Period_Copy`), so it stays right when Task 2 moves to 50 ms or when an
  expert experiments.
- Each pane computes its own stretch from its own width, so a split side-over-down gets True on top and 2D below.
- The history rescales with the stretch: zooming re-draws what is on screen at the new scale.
- Boat speed hint: *"Set to the speed you drive. Shapes are true at that speed."*
- Persistent: the mode, boat speed, echogram speed (each its own key, so switching modes finds the old value).
- **Later, optional: boat speed from the autopilot.** `vruVelocityH` is already a root context property. An "Auto" choice
  can feed it smoothed into the same formula, and the manual slider stays the default and the fallback without MAVLink.
  Out of scope for Task 1.

### 5.4 Test on the device

- Pause at stretch 3 and at 0.5, tap a bright target, add a waypoint, and compare against the same target tapped at 1.0 — the
  position must agree within a ping.
- The crosshair and the loupe must sit on the target in both orientations, left- and right-hand mount.
- True mode: change max depth 25 → 10; a known object must keep its shape. Split screen: each pane its own stretch.
- Cap label appears and disappears at the right range.
- 2D: echogram speed behaves as today, and pausing no longer changes the picture.

## 6. Shared by Tasks 2a and 2b — the performance engine and the switch

**The engine** (one, not per device), run whenever range, mode or model changes:

```
limits = hardwareLimits[model]
R      = acquisition range (blue: visible range per side; red/black: see 8)
T      = max(limits.periodMinMs, ceil(2 × R_oneway ÷ c) + margin)        // 50 ms until physics says otherwise
S_max  = limits.samplesMax                                                // 5000
d      = max(limits.spacingFloorMm, ceil(channels × R ÷ S_max))           // whole mm; channels = 2 blue, 1 red/black
S      = min(ceil(channels × R ÷ d) rounded up to 50, S_max)
```

Written through `pulseRuntimeSettings.setParam()` into `liveParams`, like `PulseDepthEngine` does today. Runtime only;
every start returns to profile defaults plus the user's persistent choices.

**The drag throttle** (max depth): the visible range follows the finger; the transducer is sent a value only when the handle
slows below ~2 m/s of range or rests ~300 ms, at most once a second, latest value only, always on release. A fast sweep
sends nothing and leaves no staircase.

**The switch**

- Persistent **per link type**: `highPerformance.ip` / `highPerformance.wifi`, each unset / on / off. The first
  `192.168.144.*` connection turns an unset `ip` **on**; `wifi` defaults **off**.
- *Connection* category: **"High performance mode"**. On wifi, turning it on asks in the row (action-row pattern), and the
  number is the device's own:
  > **This sends up to 3.5× (blue) / 10× (red, black) more data over wifi and will shorten your wireless range.** The
  > echogram may freeze or drop out at distances that work today. Switch on?
- Off, every device behaves exactly as today, including red's wifi scheme.

**Expert rows** (what the CHIRP work needs now, and useful for testing 2a/2b):

- Raw samples, spacing and period rows; an expert write takes that key over for the session (*"set by you — Reset to
  hand back"*); clamped only by `hardwareLimits`, never by the budget. Runtime like all of `liveParams`.
- Small and independent: it can be built ahead of the engine if the partner needs it sooner.

## 7. Task 2a — PULSE blue

At 50 ms (51 ms at 35 m), 5000 samples:

| Swath per side | Spacing × samples | vs today | Basic2D (floor 15 mm) |
|---|---|---|---|
| 35 m | 14 mm × 5000 @ 51 ms | 2.5× finer | 15 mm × 4700 |
| 25 m | 10 mm × 5000 | 2.5× finer | 15 mm × 3350 |
| 15 m | 6 mm × 5000 | 4× finer | 15 mm × 2000 |
| 10 m | 4 mm × 5000 | 6× finer | 15 mm × 1350 |
| 5 m | 2 mm × 5000 | 12× finer | 15 mm × 700 |

- **Acquisition range = visible range per side**, via the drag throttle. Never-captured bottom stays black.
- **The *Side scan width* row stays as the ceiling** (25/35 m); its data-rate workaround goes away in performance mode.
- **`PULSEblue-IP`** becomes the first profile that changes the wire: samples max 5000, period from `hardwareLimits`.
- **Check**: the mosaic and the loupe with mixed-resolution blue epochs; the side scan TVG (`imageType 3`) at changing
  spacing, which should be fine since it runs in metres, but should be looked at.
- **Echogram speed**: in True mode the 50 ms period makes the picture flow 1.4× faster at the same boat speed,
  automatically, because the stretch formula reads the reported period.

## 8. Task 2b — PULSE red and black

**Keep what red is good at, spend the new budget on detail.** The depth-following engine stays: acquisition range follows the
bottom (depth + margin, or 2 × depth + margin with double-echo optimise) in auto, or the user's max depth in manual. What
changes is the sample budget: 5000 instead of 500, so the spacing can be fine at every depth.

Today on wifi against performance mode (margin 2 m):

| Bottom depth | Today (wifi) | Performance | Finer |
|---|---|---|---|
| 3 m | 10 mm × 500 @ 50 ms | 2 mm × 2500 @ 50 ms | 5× |
| 8 m | 20 mm × 500 @ 50 ms | 2 mm × 5000 @ 50 ms | 10× |
| 13 m | 30 mm × 500 @ 50 ms | 3 mm × 5000 @ 50 ms | 10× |
| 18 m | 40 mm × 500 @ 50 ms | 4 mm × 5000 @ 50 ms | 10× |
| 28 m | 50 mm × 600 @ 70 ms | 6 mm × 5000 @ 50 ms | 8× |
| 38 m | 50 mm × 800 @ 110 ms | 8 mm × 5000 @ 58 ms | 6×, and 2× faster |
| 48 m | 50 mm × 1000 @ 150 ms | 10 mm × 5000 @ 71 ms | 5×, and 2× faster |

*Today's column is `calculateDynamicResolution` as written; the ~14 m point where Olav says the spacing stopped rising may
come from a different constant on the device, to confirm.*

- **The spacing stays in the range where rendering has always worked** (2–10 mm, against today's 50 mm ceiling). The old
  limit was artefacts at coarse spacing, so it should not come back; the new load to check is 5000 samples per epoch
  (chapter 9, item 7).
- **Steps get smaller and rarer.** With 5000 samples, one spacing step covers a much larger depth band, so the
  reconfigurations that produce red's stairway under the bottom become rarer. The existing stable-reading counter stays.
- **Profile key**: `resolveProfileKey` gains a `keyFor(model, address)` for red as it has for blue; a `PULSEred-IP`
  record carries the performance limits. The check tool's assertion *"red on the IP gateway is still red"* inverts.
- **Off, red is exactly today's wifi scheme** — including its period growth, which only ever makes the period longer and so
  is the safe direction for the hardware (worth a nod from the partner anyway).
- **TVG**: red's `imageType 2` computes gain in metres, so the finer spacing does not change brightness (confirmed 12 Sept).
- **Echogram speed**: unchanged control (Task 1). In performance mode the period drops from up to 150 ms to at most 71 ms
  in deep water, so the deep-water picture also flows up to 2× faster.

## 9. Measurements before building Task 2

1. **Epoch rate at 50 ms with 5000 samples** (blue at 35 m, red at 30 m): 20 epochs/s means no hidden per-ping overhead.
2. **IP link at 1.2 km** with 100 kS/s: the echogram must stay solid. Measure the app's received byte rate as well, so the
   wifi warning quotes a true number.
3. **Wifi at 3.5× and 10×**: how far does it still work? This sets the warning's tone.
4. **Red spacing floor**: can red and black go to 1 mm like production blue? It matters in shallow bait-boat water.
5. **Stretch cap** for True mode, with interpolation on (try 2, 3, 4), and Free's 2.0× ceiling.
6. **Drag throttle** constants on the tablet.
7. **Render check at 5000 samples on red**: no artefacts and no lag on the target tablets, full and split screen.

## 10. Questions answered (29 Sept)

1. **The red renderer limit beyond ~15 m was a broken picture (artefacts) at coarse spacing**, not lag. Performance mode
   keeps red's spacing at 2–10 mm, far below where it broke, so the limit should not return. Rendering 5000 samples per
   epoch is a different load, though, so Task 2b includes a render check on the target tablets (chapter 9, item 7).
2. **PULSE black is the same as red** for this work: same profile, limits and dynamic scheme. Task 2b covers both.
3. **2D panes keep today's "echogram speed ×"** control in Task 1, made pause-safe. Boat speed is for the side scan only.
4. **The side scan defaults to True proportions.** Free is one tap away for users who prefer today's look.

## 11. For later

- Boat speed from the autopilot (`vruVelocityH`), as an optional "Auto" beside the manual slider.
- Constant vertical exaggeration for 2D.
- CHIRP blue's own profile when its hardware id exists.

---

## 12. For sales: PULSE High Performance

*The same features, told as the story a customer will see. Every number comes from the analysis above; ones that still
depend on water tests are marked "up to".*

### The headline

**See it the way it really is — at a kilometre and beyond.**

The new IP telemetry link keeps the echogram rock-solid past 1 km. Bait-boat anglers, surveyors and SAR teams have seen
it, and they want it. High Performance turns that link into what the customer actually sees: **a far sharper echogram on
every PULSE, and a side scan in true proportions.** Connect, and it switches itself on.

### Selling points

**1. Up to ten times sharper on PULSE red and black.**
The same transducer, now sending ten times the detail. At 10 m depth the picture is drawn in 2 mm steps where it used to
be 20 mm. Fish, weed and bottom structure come out crisp instead of blocky, and in deep water the picture scrolls twice as
fast as before. For bait-boat anglers that is the spot, the fish and the drop-off, clearly visible, a kilometre out.

**2. Up to twelve times sharper on PULSE blue — exactly where you look.**
Bring the side scan range in and PULSE blue re-tunes itself: down to 2 mm at 5 m, where today's picture uses 25 mm. Less
range, more detail, every time. For SAR, the difference between "something is down there" and "that is what we are
looking for".

**3. True proportions: shapes you can trust.**
Most sounders squash or stretch the picture every time you change range or speed. PULSE does the maths for you: set your
boat speed, and a tyre looks round and a car looks like a car, at every range. Zoom in and the whole picture zooms, like a
map. And pause, tap, send the boat — the waypoint lands where you tapped.

**4. Built to last, simple to use.**
The transducer runs at the pace our hardware engineers designed it for; the extra speed and shape come from the app, not
from wearing out the hardware. Two controls anyone understands: **how deep** and **how fast**.

**5. It just works.**
PULSE recognises the IP link and switches High Performance on by itself. On wifi? It's there too, with an honest warning
that it trades wireless range for picture quality, so the customer decides.

### What the user sees

- Drag max depth: **the picture follows your finger instantly**. Let go, and **it sharpens in front of your eyes**.
- Set boat speed to 3 km/h, drive at 3 km/h: **the side scan draws the bottom in true shape**.
- On a red over IP: **every fish arch and weed bed in fine detail**, down to 50 m.

### One-liners

- *"True shape. Real detail. A kilometre out."*
- *"PULSE High Performance: the IP link's power, turned into detail you can see."*
- *"Made in Germany, tuned on the water with SAR professionals, anglers and surveyors."*

### Honest boundaries (so nothing is oversold)

- The detail gain needs the IP telemetry link; on wifi it costs range, and the app says so.
- On blue the biggest gain is at short range: about 2.5× at 25–35 m, more than 10× at 5 m. On red/black, 5–10× at every
  depth.
- True proportions assumes the boat drives at the speed set on the slider; very close in, the picture is marked when it is
  shortened for readability.
- Final numbers are being tuned on the water before release.
