# Echogram speed and high performance mode — analysis and implementation plan

*PULSE blue, red and black. Revisions: 27 Sept (Olav's answers), 29 Sept (hardware partner's input), 29 Sept (split into
tasks, red/black added, 50 ms period), 30 Sept (Olav's answers at the start of session 7), 2 Oct (the serial baud rate is
the real ceiling; expert "Performance mode" category; Olav's answers on 8N1, the fixed red/black baud and the prototypes). Checked against the KoggerApp code (1.39; render and pause code
re-checked on `feature/pulse-small-screens`, the chart protocol on `feature/pulse-side-scan-waypoints`). This is the
reference for the implementation prompts. Chapter 12 is the same story told for sales.*

## Status, 30 Sept 2026 (night)

**Task 1 is built and verified on the device** (session 7, in 1.41): the stretch is one mapping, pause keeps the
picture, the side scan is always true in the gauge's unit, the down scan has its own speed, a blue's panes keep their
own max range, and the pinch follows along-the-flow = speed, across = range. Interpolation above ~1.5x and 2D in km/h
are not done. **Next is side scan waypoints (session 8); Task 2a/2b come after that.**

**2 Oct:** Task 2 re-planned around the serial baud rate (chapter 2a). Task 2a stays next after the waypoints;
Blue's period stays 70 ms. Performance mode is a blue feature; red/black in the field (115200, fixed by the delivered wifi
AP) get **link-fit tuning** of their dynamic scheme instead (Task 2b, chapter 8), and a **black v2** at 921600 is
recommended as future hardware (8.4).

**2 Oct, evening - Task 2a step 1 built** on `feature/pulse-performance-mode` (off the published 1.42): the expert
*Performance mode* category (6.2's four persistent rows, stored, nothing acting on them yet) and two measured read-outs,
*Serial link* (reported baud, kB/s on the wire, % used) and *Lost chart samples* (10 s and since start), plus a `LINK:`
log line every 10 s. **The engine runs only while expert mode is on** (Olav, 2 Oct). The measurement of 9.2 is done (9a): 5000 @ 70 ms
runs at ~84% and is stable; 55 ms kills the link. Next: step 2, the blue engine. Measurement procedure: backlog, *Performance mode, step 1*.

**2 Oct, night - Task 2a step 2 built (not yet on a device):** the blue engine (`PulsePerformanceEngine.qml`, arithmetic
in `PulsePerfEngine.js`, checked by `tools/pulse-perf-check.js`). Max range side decides; 70 ms; spacing and samples
within the floors and an 85% budget of a baud decided once per connection; one writer of the four keys while it holds
them; one parameter at a time, the chart confirmed by the stream; off hands the shipped values back. True proportions
now read the real period. Commits and device checks: backlog, *Performance mode, step 2*.

## The plan in one page

**Task 1 — Echogram speed for everyone (all devices, all links, no warning).**
Speed becomes a pure display stretch of the echogram. It never touches the transducer, so it works on wifi and IP alike.
The side scan gets **True proportions** (always, no Free mode since 30 Sept): the user sets boat speed, and the picture
keeps a metre a metre in both directions. The hard part is not the stretch itself but keeping
**pause → tap → loupe → add waypoint** correct under any stretch, including below 1.0. Task 1 is mostly that work.
Boat speed is user-set; setting it automatically from the autopilot is a later option on top, never a replacement.
**Built and verified in 1.41 (session 7); unaffected by the baud rate.**

**The ceiling for Task 2 is the serial link, not the radio.** Between the IP connector (or the wifi AP) and the transducer
runs a UART: **921600 baud on blue, 115200 on red/black**. One byte per sample, 10 bits per byte on the wire. That caps
blue at about 86 000 samples/s and red/black at about 10 800, before any headroom (chapter 2a; fragment size measured from
logs on 2 Oct).

**Task 2a — High performance mode, PULSE blue.** Expert-only first (chapter 6).
**The period stays at 70 ms** (settled 2 Oct: the optimal setting; speed is the stretch's job). At 70 ms the UART carries
the firmware's full 5000 samples at 84%, so performance mode on blue is *the same period, 2.5× the samples*: across-track
detail 2.5× (35 m) to 12× (5 m) finer at the production floor of 1 mm, or 15 mm everywhere at the expert default floor.

**Task 2b — PULSE red and black in the field: link-fit tuning, not a performance mode.** For all users, no warning.
At 115200 there is no data rate to add, so performance mode is a blue feature. But the dynamic scheme can use the link it
has *better*, through the profile's period and samples, which the app already writes (chapter 8):
- **Stop overdriving the link in shallow water**: 500 samples at 50 ms needs ~99% of the UART, and the log shows the pings
  arriving at ~14–15/s instead of 20. Commanding **~59 ms** (57 ms with the slower poll) gives a steady ~17/s at 84%: more pings than today in practice,
  evenly spaced, with room for the other messages.
- **Spend the unused headroom in deep water** (today 65–71% load beyond ~30 m): faster pings at the same detail
  (recommended for 2D), or 1.2–1.3× finer spacing at today's pace.
- **Slow the app's version poll** while chart data flows (it is the app that polls, every 300 ms, not the firmware):
  ~2.3% of a 115200 link back, which takes the shallow-water period to ~57 ms. First step of 2b (8.3).

**Task 2c — later, with new hardware: a PULSE black v2** (recommendation in chapter 8.4). Blue's electronics with one
channel, a new hardware name and a 921600 UART make it a performance-mode device with no new engine: 5000 samples at
70 ms, 5× finer than today's black in deep water and 10× in the shallows.

**Order:** Task 1 (done), then 2a, then 2b (small, independent, can come any time). 2c when the hardware exists.

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

**30 Sept evening (Olav, after slice B on the device)**

- **The boat speed behaves as intended**: at the recorded speed the side scan shows objects as they are; faster or slower
  stretches or squashes them along the track.
- **The down scan gets its own speed** (a factor for now, `echogramSpeedDown`) - no speed ever reached it before.
- **A blue's side and down panes keep their own max range**, shown as *Max range side* and *Max range down*, in full
  screen and split; a pinch changes only the pane it is on.

**2 Oct (partner, via Olav)**

- **The baud rate between the IP connector / wifi AP and the transducer is the most important limit**: 921600 on blue,
  115200 on red/black.
- **A new expert category "Performance mode"** with four persistent settings: *Enable performance mode* (default off),
  *Max samples* (default 5000), *Min spacing blue* (default 15 mm), *Min spacing 2D* (default 2 mm). They let the expert
  limit the engine himself; the category may be reshaped when the mode opens to all users.
- **This supersedes the 30 Sept "Task 2 additions"** resolution floor (one slider, 1–16 mm, default 1): there are now two
  floors, blue 15 mm and 2D 2 mm, plus a samples ceiling. The 30 Sept address rule stays for when the mode opens to all
  users: the wifi warning is for **192.168.10.x**; the IP link (**192.168.144.x**) needs none.

**2 Oct (Olav's answers)**

- **The UART is 8N1.** The firmware's chart fragment size is not known yet.
- **The red/black baud rate stays 115200 on units in the field.** The app *could* change it on the transducer
  persistently, but the wifi AP delivered with the boats cannot easily follow on the receiving end, so it is not done.
- **Pro versions of the 2D and the pure down scan black are likely**, and they will run at **921600**.
- **`Basic2D` is the hardware name of two prototypes**: the blue prototype runs at **921600**, the red prototype at
  **115200**.

**2 Oct (Olav, second)**

- **Blue keeps 70 ms.** It is the optimal setting; echogram speed comes from the image stretch.
- **Red/black's ping period is set by the app** through the runtime profile (the dynamic scheme already raises it beyond
  14–15 m), so it can be tuned without firmware work.
- **Red sells little, black is popular.** A **black v2** with a new hardware name and blue's crystals (one channel) is
  possible in the not-too-distant future; for now a recommendation only (8.4).
- **Performance mode is therefore a blue feature** (and a black v2's, later). Red/black in the field get link-fit tuning (8).

**2 Oct, night (Olav, the step 2 design)**

- **Max range side decides** the acquisition range; the down pane's range does not.
- **The Transducer rows (samples, spacing, period) are read-only** while the engine holds them - one writer.
- **distMax follows the range** (`1000 x R`).
- **True proportions read the real period**, `max(confirmed, 2R/c + 3 ms)`.
- **Off hands the shipped values back** and keeps an expert's other Transducer experiments.
- **The throttle**: 300 ms of rest, a chart setup at most once a second (replaces 6.1's "slows below 2 m/s").
- **One transducer parameter at a time** (the upstream author's rule; Olav's setup pass follows it): the engine sends
  the period, then the chart (spacing + samples as one message), then distMax, each confirmed before the next.

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

Data rate ∝ samples ÷ period, **one byte per sample** (confirmed in `IDBinChart::parsePayload`: v0 is the single 2D
channel, v1 carries the two side scan channels byte-interleaved, which is also why blue's range is `samples × spacing ÷ 2`).

| Device and mode | Samples | Period | Samples/s | UART load |
|---|---|---|---|---|
| Blue today | 2000 | 70 ms | 28.6 k | 33% of 921600 |
| Blue, 29 Sept plan | 5000 | 50 ms | 100 k | **115% — does not fit** |
| Blue, performance (detail first) | 5000 | 70 ms | 71.4 k | 84% |
| Red/black today, shallow | 500 | 50 ms (commanded) | 10 k | **≈ 99% of 115200** |
| Red/black today, deep | 1000 | 150 ms | 6.7 k | 61% |

## 2a. Background — the serial link (new, 2 Oct)

**The arithmetic.** A UART at 8N1 (confirmed 2 Oct) moves `baud ÷ 10` bytes per second. Each chart fragment is a KP1
frame (`0xBB 0x55`, address, mode, id, 1-byte length, payload, 2-byte Fletcher checksum) whose payload starts with a 6-byte
chart header (`seqOffset`, `sampleResol`, `absOffset`). **Measured from the two logs (below): the firmware sends 200
samples per fragment**, 214 bytes on the wire — **93.5% efficiency**. A ping of S samples therefore costs
`ceil(S ÷ 200) × 214` bytes, plus a 10-byte temperature frame per ping, plus the app's version poll (≈ 95 bytes of answers
every ~300 ms ≈ 320 bytes/s).

| | Blue, 921600 | Red/black, 115200 |
|---|---|---|
| Bytes/s on the wire | 92 160 | 11 520 |
| Samples/s, framing only | ≈ 86 000 | ≈ 10 800 |
| **Samples/s at 85% load** (engine budget, after temperature and polls) | **≈ 73 000** | **≈ 8 900** |
| Samples per ping at 50 ms | ≈ 3 650 | ≈ 400 |
| Samples per ping at 70 ms | 5 000 (fits, 84%) | ≈ 600 |
| Shortest period for 5000 samples | 70 ms | ≈ 560 ms |

### Measured from the logs (2 Oct)

Two raw logs in `docs/`, parsed frame by frame (sync, Fletcher checksum, id, `seqOffset`):

| | `2D_pulse_log_2026.07.15_15.50.34.plog` (red, Basic2D prototype) | `SS_pulse_log_2026.01.14_Titan.plog` (blue, larger prototype) |
|---|---|---|
| Baud reported by the device (`ID_UART`) | **115200** | **921600** |
| Ping period commanded (`ID_DATASET` ch 1) | 50 ms | 70 ms |
| Samples per fragment | **200** (100 for the last) | **200** |
| Samples per ping | 500 (99%) | 2000 (2× 1000 interleaved); some 1400–1800 |
| Spacing | 12–30 mm (dynamic resolution) | 25 mm |
| Pings / version polls | 31 731 / 7 577 | 3 811 / 965 |
| Pings per second (from the poll clock, ≈) | **≈ 14–15** (20 commanded) | ≈ 13–14 (14.3 commanded) |
| Fragments lost inside a ping | 186 gaps, 0.13% of samples | **2 031 gaps, ≈ 5% of samples** |
| UART load implied by what was commanded | **≈ 99%** | ≈ 34% |

What the logs say:

- **The fragment size is 200 samples on both devices**, so the 95% assumed earlier becomes 93.5%; every budget above uses it.
- **The device reports its baud rate in the stream** (`ID_UART`): 115200 and 921600, exactly as Olav said. The engine can
  rely on it — this is what tells the two `Basic2D` prototypes apart.
- **Red does not reach its commanded 50 ms.** 500 samples every 50 ms would need about 99% of the 115200 UART, and the
  log shows roughly 14–15 pings per second instead of 20, with almost no fragments lost. The firmware (or the AP) is
  evidently pacing the pings to what the link can carry. *So red is already link-bound today*, which confirms the 2b
  conclusion from the measurement side. (The ping rate comes from the app's version poll, every 3 × 100 ms while data
  flows (`link_defs.h`); calibrated against blue, whose commanded rate is known, it is accurate to ~10%.)
- **Blue's loss is not the UART.** At 34% load the serial link has room; the ≈ 5% lost fragments and the odd sample counts
  match Olav's warning that this prototype ran with abnormal settings, and a January log predates the IP link, so the
  5.8 GHz radio is the likely cause. A loss counter in the expert category (6.2) is what separates the two in future.
- **The version poll costs ≈ 3% of red's UART.** It is harmless on blue, but on a 115200 unit it is not free. Slowing it
  while chart data is flowing is a small, separate improvement worth noting for red.

The 85% leaves room for the other messages each ping carries (distance, timestamp, attitude, temperature) and for jitter.
It is an engine constant, not a user setting, and the first device test should tune it (chapter 9).

**What this changes**

- **Blue cannot have 5000 samples and 50 ms at once.** The engine has to pick: detail (5000 @ 70 ms) or ping rate
  (~3650 @ 50 ms). The partner's rule from 29 Sept, *the full data response first, then speed up with image stretch*,
  decides it: **detail first**, and Olav settled it on 2 Oct: **blue stays at 70 ms**, which carries 5000 samples at 84%.
  Blue's performance mode is *the same period, 2.5× the samples*.
- **Red/black are at their ceiling today.** 500 samples every 50 ms would be ~99% of 115200 (the logs show the pings
  slowing to fit) — the existing wifi scheme was in
  practice also a UART scheme, and its period growth at depth keeps it under the UART too. At 115200 there is nothing
  to add, only to fit better (chapter 8). The baud rate, not wifi, is why.
- **The wifi warning shrinks.** Blue can at most reach ~2.6× today's data rate (the UART caps it), not 3.5×. Red/black at
  115200 cannot raise the data rate at all, so a redistribution mode costs no wireless range.
- **The IP link is not the bottleneck** for either device: 92 kB/s is about 0.75 Mbit/s.
- **Lost fragments show up as broken pings.** If the engine overruns the UART, `IDBinChart` sees `seqOffset` gaps
  (`lossHistory_` already counts them). That counter is the natural live check for the 85% assumption, and a candidate
  expert read-out (chapter 6).

## 3. Background — limits from physics and hardware

**Ping period floor, physics side.** The transducer must listen for the whole range before pinging again:
`T_min = 2 × range ÷ c + margin`, with c ≈ 1480 m/s and a ~3 ms margin.

| Range (one way) | 5–25 m | 30 m | 35 m | 40 m | 50 m |
|---|---|---|---|---|---|
| T_min | < 40 ms | 44 ms | 51 ms | 58 ms | 71 ms |

With the UART now setting blue's period at 50–70 ms, physics never binds on blue. On red/black at 115200 the UART binds
long before physics.

**Hardware limits belong to the model — and the baud rate is best read from the device.** The device already reports its
UART rate: `ConnectionViewer` copies `chosen.baudrate` into `pulseRuntimeSettings.rawDev_devBaudRate`, which Expert info
shows today. **The engine should use the reported rate** when it is known (> 0) and fall back to the table only when it is
not. That makes three things right with no special cases:

- **The two `Basic2D` prototypes** share one hardware name (`modelPulseRedProto` and `modelPulseBlueProto` are both
  `"Basic2D"`), so a model-keyed table cannot tell them apart — but their reported baud (115200 vs 921600) does.
- **The pro 2D and pro black** get the 921600 budget the moment they report it, before anyone adds a profile.
- **A field unit someone has reconfigured** gets the budget it actually has.

Fallback table (used only while no rate has been reported):

```
hardwareLimits: {
    "PULSEblue":      { baud: 921600, spacingFloorMm: 1,  samplesMax: 5000, periodMinMs: 50 },
    "Basic2D (blue)": { baud: 921600, spacingFloorMm: 15, samplesMax: 5000, periodMinMs: 50 },  // 2 channels
    "Basic2D (red)":  { baud: 115200, spacingFloorMm: 2,  samplesMax: 5000, periodMinMs: 50 },  // 1 channel
    "PULSEred":       { baud: 115200, spacingFloorMm: 2,  samplesMax: 5000, periodMinMs: 50 },
    // PULSE black: as red. Pro 2D / pro black: 921600, own entries when their ids exist. CHIRP blue: likewise.
}
```

The two `Basic2D` rows are told apart by channel count, the same signal the resolver already uses for an unrecognised
name. *To check in the code before relying on it*: that `dev.baudrate` reflects the transducer's UART over a UDP link, and
not a default or the last serial setting.

These are **hardware facts and stay in code**. The expert category of chapter 6 can only *tighten* them, never loosen
them: the engine uses `max(hardware floor, expert min spacing)` and `min(hardware max, expert max samples, what the UART
allows)`.

**Spacing floor = sample rate** (`c ÷ 2d`). The Basic2D prototype stops at 15 mm, exactly 50 kHz, which suggests its board
tops out there. Production blue goes to 1 mm (750 kHz), and the partner confirms fine spacing is no strain. The expert
default of 15 mm for blue keeps a prototype safe until the expert deliberately lowers it.

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
- **A shorter period helps directly**: at 50 ms the same proportions need 30% less stretch. Task 2a reaches 50 ms on blue
  only with fewer samples (chapter 7), so do not count on it.

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

## 6. The engine and the expert category

### 6.1 The engine

One engine, not per device, run whenever range, mode, model or an expert limit changes:

```
hw     = hardwareLimits[model]
floor  = max(hw.spacingFloorMm, expert.minSpacing(blue or 2D))      // expert can only tighten
Smax   = min(hw.samplesMax, expert.maxSamples)
U      = (hw.baud / 10 × 0.85 − 320) × 200 / 214                    // samples/s: headroom, polls, 200-sample fragments
                                                                    // (10-byte temperature frame per ping on top)
R      = acquisition range (blue: visible range per side; red/black: see 8)
Swant  = min(Smax, channels × R ÷ floor)                            // channels = 2 blue, 1 red/black
T      = blue: 70 ms (fixed, 2 Oct). Others: clamp(Swant ÷ U, max(hw.periodMinMs, T_min(R)), Tcap)
S      = min(Swant, U × T)                                          // what actually fits at that period
d      = max(floor, ceil(channels × R ÷ S))                         // whole mm
S      = ceil(channels × R ÷ d), rounded up to 50
```

- **Blue's period is fixed at 70 ms**, so on blue the engine only chooses samples and spacing. The general form (period
  from the bytes per ping, never below `T_min`) is what a black v2 and red/black's link-fit tuning (8.2) use.
- Written through `pulseRuntimeSettings.setParam()` into `liveParams`, like `PulseDepthEngine` does today. The *outputs*
  are runtime; the *limits* in 6.2 are persistent.
- **The drag throttle** (max depth): the visible range follows the finger; the transducer is sent a value only when the
  handle slows below ~2 m/s of range or rests ~300 ms, at most once a second, latest value only, always on release.

### 6.2 Expert → "Performance mode" (new category, 2 Oct)

| Row | Type | Persistent key | Default | Range / note |
|---|---|---|---|---|
| Enable performance mode | switch | `perfModeEnabled` | **off** | Off = every device exactly as today |
| Max samples | stepper (50s) | `perfMaxSamples` | **5000** | 500–5000; never above the firmware's 5000 |
| Min spacing blue | stepper (1 mm) | `perfMinSpacingBlueMm` | **15** | 1–50; also applies to Basic2D, never below its 15 |
| Min spacing 2D | stepper (1 mm) | `perfMinSpacing2DMm` | **2** | 1–50; red, black, red-proto |

- **Placement**: its own category under the *Expert settings* title, beside Transducer. The settings panel's rules apply as
  they are: the category exists only while `expertMode` is on, and both spacing rows are always shown so an expert can
  prepare the other device's limit before swapping.
- **Recommended: the engine runs only while expert mode is on.** `perfModeEnabled` stays stored, but turning expert mode off
  returns every device to its standard behaviour without the expert having to remember the switch. It also keeps an
  ordinary user from inheriting an expert's experiment on a shared tablet.
- **Persistent by design**, which is different from `liveParams`: these are *limits the expert has cleared for his hardware*
  (the prototype's 15 mm, for example), not experiments, so they should survive a restart.
- **Hints** say what binds, so the expert sees why the engine chose what it chose: *"Limited by link: 3 650 samples at
  50 ms"*, *"Limited by min spacing"*.
- **Suggested read-outs** in the same category (read-only rows): *Serial link* ("921600 baud, 84% used") and *Lost
  fragments* from `IDBinChart`'s `lossHistory_`. Together they show whether the 85% headroom holds on the water.
- **Raw expert rows** (Transducer: samples, spacing, period) keep their take-over rule: an expert write holds that key for
  the session, *"set by you — Reset to hand back"*, clamped by `hardwareLimits` only. The engine leaves a held key alone.
- **When the mode opens to all users** (later): the per-link switch from the earlier version returns —
  `highPerformance.ip` on at the first `192.168.144.*` connection, `highPerformance.wifi` (192.168.10.x) off — with the wifi warning
  quoting the device's real figure (blue: *up to 2.6× more data*). The four expert limits stay as the ceiling.

## 7. Task 2a — PULSE blue (921600 baud, 70 ms)

**The period is fixed at 70 ms** (settled 2 Oct). The engine of 6.1 then has one job: spend the 5000 samples on the
finest spacing the range and the floor allow.

| Swath per side | Floor 15 mm (expert default) | Floor 1 mm (production) | vs today | UART load at 5000 |
|---|---|---|---|---|
| 35 m | 15 mm × 4700 | 14 mm × 5000 | 2.5× finer | 84% |
| 25 m | 15 mm × 3350 | 10 mm × 5000 | 2.5× finer | 84% |
| 15 m | 15 mm × 2000 | 6 mm × 5000 | 4× finer | 84% |
| 10 m | 15 mm × 1350 | 4 mm × 5000 | 6× finer | 84% |
| 5 m | 15 mm × 700 | 2 mm × 5000 | 12× finer | 84% |

*"vs today" is the 1 mm column against today's 25 mm (35 mm at the 35 m swath).*

- **At the 15 mm default, performance mode already improves today's picture** (15 mm against 25/35 mm) and leaves the
  UART lightly loaded at short range. Lowering the floor is the expert's decision per unit.
- **Speed is Task 1's stretch**, which reads the reported 70 ms, so True proportions is unaffected.
- **Acquisition range = visible range per side**, via the drag throttle. Never-captured bottom stays black.
- **The *Side scan width* row stays as the ceiling** (25/35 m); its data-rate workaround goes away while performance mode is on.
- **`PULSEblue-IP`**: samples max 5000, period 70 ms; the first profile that changes the wire.
- **Check**: the mosaic and the loupe with mixed-resolution blue epochs; the side scan TVG (`imageType 3`) at changing
  spacing, which runs in metres and should be fine.

## 8. Task 2b — PULSE red and black in the field (115200 baud)

**Performance mode is a blue feature.** At 115200 there is no data rate left to add, so red and black get no performance
mode. What they can get is a **better-fitted dynamic scheme**, for every user and every link, with no warning: it never
sends more data than today.

### 8.1 What the link can carry

Per ping: `ceil(S ÷ 200)` chart fragments (214 bytes each, the last one shorter) + a 10-byte temperature frame. Per second:
the app's version poll, ≈ 320 bytes. Budget: 85% of 11 520 bytes/s. Period never below `T_min` of the range.

### 8.2 Today against a link-fitted scheme

Margin 2 m; "today" is `calculateDynamicResolution` as written.

| Bottom depth | Today (commanded) | Load | **A: same samples, period that fits** (recommended) | B: today's pace, extra samples |
|---|---|---|---|---|
| 3–23 m | 10–50 mm × 500 @ 50 ms | **≈ 99%** | × 500 @ **59 ms** — steady 17/s at 84% (**57 ms**, 17.5/s, with the slower poll of 8.3) | — (no headroom) |
| 28 m | 50 mm × 600 @ 70 ms | 84% | unchanged | unchanged |
| 38 m | 50 mm × 800 @ 110 ms | 71% | × 800 @ **92 ms** — 10.9/s (was 9.1) | 43 mm × 950 @ 110 ms, 1.2× finer |
| 48 m | 50 mm × 1000 @ 150 ms | 65% | × 1000 @ **115 ms** — 8.7/s (was 6.7) | 39 mm × 1300 @ 150 ms, 1.3× finer |

- **Shallow water (the common case) is overdriven today.** The log of 15 July shows ~14–15 pings/s against 20 commanded:
  something (the firmware or the AP) is pacing the pings to the link, irregularly. Commanding 59 ms gives **more pings than
  today in practice, evenly spaced**, and leaves room for the other messages. No change in detail.
- **Deep water has headroom that is wasted today.** The period was raised generously to stay under the wifi budget. A
  link-fitted period gives **~30% more pings at the same detail** (A), or slightly finer spacing at today's pace (B). For a
  2D picture — fish arches, bait-boat users — **A is the recommendation**; B gains too little to be visible.
- **Even ping spacing matters for Task 1.** The stretch and any later km/h speed for 2D read the period. A commanded 50 ms
  that really runs at ~67 ms makes the picture flow slower than the setting says; a period that fits is also a period that
  is true.
- **How**: the profile already carries `dynamicPeriodMin` (50), `dynamicSamplesMin/Max` and the period growth in
  `PulseDepthEngine.updateDynamicSamplesAndPeriod`. The change is to compute the period from the bytes per ping instead of
  the fixed `2 × res − 50` rule, and to raise `dynamicPeriodMin` to ~59 ms for 500 samples. It applies to red, black and
  the red prototype alike, because all three report 115200 — the engine can key it on the reported baud.
- **Partner check**: 59 ms is *longer* than today's 50, so it is the safe direction for the hardware; the deep-water periods
  stay well above 70 ms.

### 8.3 Slow the version poll — part of Task 2b

**It is the app, not the transducer firmware.** Confirmed in the code and in the logs:

- `Link::onCheckedTimerEnd()` (`src/link/link.cpp`) runs every `linkCheckingTimeInterval` = 100 ms. While data flows it
  emits `sendDoRequestAll` every `requestAllCntBig` = 3 ticks, i.e. **every 300 ms**, and every tick while no data flows
  (`requestAllCntSmall` = 1).
- That reaches `DeviceManager::onSendRequestAll()` → `DevDriver::doRequestAll()` → `idVersion->requestAll()`, which sends
  three `ID_VERSION` requests (v0, v1, v2).
- The logs carry those requests as frames of type 3 (7 577 rounds in the red log, 965 in the blue one), each answered by the
  transducer. **The answers, ≈ 95 bytes per round, are what costs the link**: ≈ 320 bytes/s, **≈ 2.8% of 115200**. The
  requests themselves travel the other way on a full-duplex UART and cost nothing that matters.

**The poll is not needed to know the link is alive while chart data flows.** Liveness is data-driven: `isReceivesData_`
follows the count of complete frames and drops after `linkNumTimeoutsBig` = 10 ticks (1 s) without any. What the poll
still does while data flows is notice a *different* device answering (a swap, which the detection rework relies on) and
keep the version fields fresh.

**Recommendation**

- **While data flows, poll every ~2 s instead of 300 ms**: `requestAllCntBig` 3 → 20. Keep `requestAllCntSmall` = 1 so
  discovery and reconnection stay as fast as today.
- **Effect**: the answers drop from ≈ 320 to ≈ 50 bytes/s, giving back ≈ 2.3% of a 115200 link. With it, red/black's
  fitted shallow-water period in 8.2 improves from **59 ms to ~57 ms** (≈ 17.5 pings/s). On blue it is irrelevant to the
  budget but harmless.
- **Cost**: a swapped transducer is noticed up to ~2 s later than today while data flows. The swap prompt is a user-facing
  question anyway, so 2 s is invisible in practice. Worth checking on the device with the swap test of the detection rework.
- **Shared Kogger code**: `link_defs.h` and `link.cpp` are upstream files, so this is one constant in a shared file — note
  it in `upstream-merge-survey.md` as a deliberate PULSE divergence. If a global change is unwanted, the alternative is a
  per-link value the app sets through a new small setter on `Link`, used only for links carrying chart data.
- **Do it first in Task 2b**: it is the smallest change, independent of the period work, and the 8.2 numbers assume it.

### 8.4 Recommendation for a PULSE black v2 (future hardware)

The black is popular and red is not, so a v2 black is where the 2D detail gain belongs.

- **A new hardware name** (not `Basic2D`, not `PULSEred`), so the profile, the limits and the resolver can tell it apart
  from day one.
- **921600 baud on the UART**, as blue. It is the one change that unlocks everything else; and the **delivered wifi AP and
  IP connector must be configured for 921600** for v2 units, since the receiving end is what kept today's units at 115200.
- **Blue's crystal and front end**, one channel. At 921600, 5000 single-channel samples at 70 ms load the UART to 83%, so
  the blue engine applies unchanged with `channels = 1`:

| Range | Spacing × samples @ 70 ms | vs today's black |
|---|---|---|
| 5 m | 1 mm × 5000 | 10× finer |
| 10 m | 2 mm × 5000 | 10× finer |
| 20 m | 4 mm × 5000 | 10× finer |
| 30 m | 6 mm × 5000 | 8× finer |
| 50 m | 10 mm × 5000 @ 71 ms | 5× finer, 2× the pings |

- **Keep the period at 70 ms** (above `T_min` up to ~50 m), like blue; the stretch provides the speed.
- **Firmware**: keep reporting the baud in `ID_UART` and the period in `ID_DATASET` (the app relies on both). Fragments of
  200 samples are fine; 249 would save another ~1.5% of the link.
- **App side it is mostly data**: a profile record and a `hardwareLimits` entry. Performance mode, the engine and the expert
  limits (*Min spacing 2D*) already cover it.
- **If CHIRP arrives in the same generation**, its pulse length changes how fine a spacing is still useful; its defaults are
  then a measurement on the water.

## 9. Measurements before building Task 2

1. **Fragment size and reported baud**: answered from the logs (200 samples per fragment; `ID_UART` reports 115200 /
   921600). Still worth checking that `dev.baudrate` in the app shows the same value over the UDP link.
2. **Blue at 5000 samples, 70 ms**: 14.3 epochs/s and no lost fragments over an hour. Then step the period down to find
   where fragments start to drop — that is the real headroom (the engine assumes 85%).
3. **Red/black link-fit (8.2)**: at 500 samples and 59 ms, the epoch rate must be a steady ~17/s (against today's
   ~14–15/s irregular at 50 ms); in deep water check the faster pings of option A.
4. **Basic2D**: answered — blue prototype 921600, red prototype 115200.
5. **Wifi with blue at ~84% UART** (≈ 2.6× today's data): how far does it still work? That sets the warning's tone.
6. **Red/black UART**: answered — fixed at 115200 in the field; the pro versions will run at 921600.
7. **Version poll**: after slowing it (8.3), the app must still notice a device that goes away within a few seconds.
8. **Stretch cap** for True mode, with interpolation on (try 2, 3, 4).
9. **Drag throttle** constants on the tablet.
10. **Render check at 5000 samples** on blue (and a black v2 later): no artefacts and no lag on the target tablets.

### 9a. The link measurement, 2 Oct 2026 (night) — G30 + PULSE blue prototype (Basic2D, 921600), on the ground, IP link

Read from the `LINK:` lines (10 s windows; wire bytes counted as they arrive, 8 bytes of framing per frame). "Pings/s" is
`(B/s − ~330 B/s of version poll) ÷ 5 360 B` per 5000-sample ping (25 fragments × 214 + 10), or ÷ 2 150 for 2000 samples.

| Samples × spacing | Period asked | Measured | Of 921600 | Pings/s implied | What it means |
|---|---|---|---|---|---|
| 2000 × 25 mm | 70 ms | 29–34 kB/s | **31–37%** | 14.3 | as shipped; the arithmetic of chapter 2 to within 2% |
| 5000 × 25 mm | 70 ms | 58–67 kB/s | **63–72%** | **11.5 → 87 ms** | **the firmware holds the listen time**: 62.5 m per side needs `2R/c + 3 ms` ≈ 88 ms |
| 5000 × 25 mm | 65 → 40 ms | ~62 kB/s, unchanged | ~67% | 11.5 | the period asked is ignored below the listen time |
| 5000 × 15 mm | 70 ms | 73–84 kB/s, 10+ min | **80–88% (≈ 84)** | 14.3 | **performance mode's operating point**: stable, loss as at 33% |
| 5000 × 15 mm | 65 ms | 76–91 kB/s | ≈ 90% | 15.4 | |
| 5000 × 15 mm | 60 ms | 77–100 kB/s | ≈ 96% (1 s peaks 108%) | 16.4 | the edge |
| 5000 × 15 mm | 55 ms | — | would need ≈ 106% | — | **link lost; the transducer needs a power cycle** |

**What it settles**

1. **The model holds.** Every row agrees with `ceil(S ÷ 200) × 214 + 10` bytes per ping at the commanded (or physics-
   bound) rate, to within a few percent. The 200-sample fragment is confirmed on a live unit.
2. **5000 samples at 70 ms runs at ~84% and is stable** for over 10 minutes. **Blue's 70 ms is confirmed** as the
   operating point, and the 85% budget of 6.1 is the right number: there is ~12% to the edge and no more.
3. **Overload does not degrade, it kills.** Lost chart samples stayed at 0.1–0.3% at every load from 33% to 96% — that is
   the radio/IP path, not the UART — and then, at 55 ms, the link died with no warning and the transducer had to be power
   cycled. **The loss counter is not an early warning.** The engine must budget by arithmetic and stay at or below ~85%;
   it must never search upward for headroom on the water.
4. **The firmware stretches a period that is too short for the range** (row 2-3): `samples × spacing ÷ 2` of range per
   side sets a floor of `2R ÷ c + ~3 ms`. Two consequences:
   - **True proportions (Task 1) reads the confirmed period**, which then is not the real one: at 5000 × 25 mm the
     picture would be stretched 24% too little. Not reachable with the shipped settings (25 m per side → 37 ms floor),
     only with expert values. The engine never asks for more range than the visible range per side (≤ 35 m → 50 ms floor),
     so it is safe by construction; the expert rows are not.
   - **The engine must compute the real period** as `max(T, 2R ÷ c + 3 ms)` before it budgets — a longer real period is
     less load, so this errs on the safe side, but the stretch needs the real number.
5. **The reported baud is not always there.** One whole 12-minute run read `baud 115200` while ~80 kB/s — seven times what
   115200 carries — came through; in the other runs it was right from the second line. The value is a default until the
   device's `ID_UART` answer has settled, and sometimes it does not settle. **The engine must check the reported baud
   against the measured rate** (it cannot be lower than what is arriving) and fall back to the model's table when it fails
   — the read-out now does exactly this (`32aa6e01`).
6. **The prototype's spacing floor is real**: dragging spacing below 15 mm made the device report 0 mm and the chart stream
   stopped (polls only, ~330 B/s). Known since 27 Sept; the Transducer row still allows 1 mm on it.

**Found with the expert rows, fixed:** Samples ran to 15 000 and above 5000 killed the link (`e3f41c31`, now 5000); the
Ping period ran 0–2000 ms and a drag fell below 30 ms and killed the link (`18ce749e`, now 40–160).

**For the hardware partner:** the transducer accepts a period its UART cannot carry and then stops answering until power
is cycled. Clamping the period to what the link carries (or dropping pings rather than locking up) would make a wrong
setting recoverable.

## 10. Questions answered

**29 Sept**

1. **The red renderer limit beyond ~15 m was a broken picture (artefacts) at coarse spacing**, not lag. Performance mode keeps
   spacing far below where it broke.
2. **PULSE black is the same as red** for this work: same profile, limits, dynamic scheme — and the same 115200 UART.
3. **2D panes keep today's "echogram speed ×"** control in Task 1, made pause-safe. Boat speed is for the side scan only.
4. **The side scan is always True proportions** (30 Sept: no Free mode on the side scan).

**2 Oct**

5. **The bottleneck is the UART** (921600 blue, 115200 red/black), not the radio and not the IP link.
6. **Performance mode starts as an expert category** with four persistent limits, enable default off.
7. **8N1**; the fragment size is **200 samples** on both devices (measured from the two logs in `docs/`).
8. **Red/black stay at 115200 in the field** (the delivered wifi AP is fixed); **pro 2D and pro black will be 921600**.
9. **`Basic2D` is two prototypes**: blue at 921600, red at 115200 — so the engine reads the reported baud rate.
10. **Blue keeps 70 ms.** Performance mode is a blue feature; red/black get link-fit tuning; a black v2 is recommended (8.4).

## 11. For later

- Opening performance mode to all users: the per-link switch and the wifi warning (6.2, last bullet).
- Boat speed from the autopilot (`vruVelocityH`), as an optional "Auto" beside the manual slider.
- Constant vertical exaggeration for 2D.
- CHIRP blue's own profile and `hardwareLimits` entry when its hardware id exists — including its baud rate.
- PULSE black v2 (8.4): new hardware name, 921600, blue's front end; then performance mode with `channels = 1`.

---

## 12. For sales: PULSE High Performance

*The same features, told as the story a customer will see. Every number comes from the analysis above; ones that still
depend on water tests are marked "up to". Revised 2 Oct: High Performance is a PULSE blue feature; today's red/black get a
smoother picture, and the detail leap waits for a black v2.*

### The headline

**See it the way it really is — at a kilometre and beyond.**

The new IP telemetry link keeps the echogram rock-solid past 1 km. Bait-boat anglers, surveyors and SAR teams have seen
it, and they want it. PULSE turns that into what the customer actually sees: **a side scan in true proportions, and on
PULSE blue up to twelve times the detail.**

### Selling points

**1. True proportions: shapes you can trust — on every PULSE.**
Most sounders squash or stretch the picture every time you change range or speed. PULSE does the maths for you: set your
boat speed, and a tyre looks round and a car looks like a car, at every range. Zoom in and the whole picture zooms, like a
map. And pause, tap, send the boat — the waypoint lands where you tapped. Works on wifi and IP alike.

**2. Up to twelve times sharper on PULSE blue — exactly where you look.**
Bring the side scan range in and PULSE blue re-tunes itself: down to 2 mm at 5 m, where today's picture uses 25 mm. Less
range, more detail, every time. For SAR, the difference between "something is down there" and "that is what we are
looking for".

**3. Built to last, simple to use.**
The transducer runs at the pace our hardware engineers designed it for, and every setting stays inside what its data link
can carry — no dropped pings, no overheated electronics. The extra speed and shape come from the app. Two controls anyone
understands: **how deep** and **how fast**.

**4. PULSE black: smoother today, sharper tomorrow.**
Today's PULSE black gets a picture that flows evenly at every depth, and up to 30% more pings in deep water, from the
same hardware. And a next-generation black is on the drawing board: the electronics of PULSE blue in a single-beam 2D,
built for up to ten times the detail. *(Black v2 is not announced: no dates, no promises to owners of today's units.)*

### What the user sees

- Drag max depth: **the picture follows your finger instantly**. Let go, and on PULSE blue **it sharpens in front of your eyes**.
- Set boat speed to 3 km/h, drive at 3 km/h: **the side scan draws the bottom in true shape**.

### One-liners

- *"True shape. Real detail. A kilometre out."*
- *"PULSE blue High Performance: the IP link's power, turned into detail you can see."*
- *"Made in Germany, tuned on the water with SAR professionals, anglers and surveyors."*

### Honest boundaries (so nothing is oversold)

- High Performance is expert-only for now, while it is tuned on the water.
- On blue the biggest gain is at short range: about 2.5× at 25–35 m, up to 12× at 5 m. On wifi it costs some range.
- Today's PULSE red and black keep their link: a smoother, evener picture, not more detail. The 2D detail leap needs a black v2.
- True proportions assumes the boat drives at the speed set on the slider; very close in, the picture is marked when it is
  shortened for readability.
