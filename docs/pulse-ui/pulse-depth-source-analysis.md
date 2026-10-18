# The depth source on the shore and in the shallows - analysis and plan (18 Oct 2026)

Branch `feature/pulse-depth-source` (1.44 for experts, `b0d4711a`). Input: Olav's field run on 18 Oct from 14:58 -
`pulse_181026.log` (1.44 with the `DEPTH:` live-rangefinder field and the `BT:` lines), `2D_pulse_log_2026.10.18_15.00.29.plog`
(production PULSE red, shore -> water -> shore several times) and `SS_pulse_log_2026.10.18_15.10.27.plog` (beta PULSE blue,
a mission starting and ending on the shore). Earlier reading: the backlog section "The depth source - analysis, 4 Oct
2026" (F1-F6). The coding is done in a separate chat from this plan.

**How it was measured.** The log gives what the app showed and the live rangefinder. The `.plog` files were replayed
through a line-by-line port of the bottom-track algorithm and its realtime pass schedule (`tools/pulse-bt-bench/`), which
reproduces the app's own logged per-ping bottom track to 0.01 m for 81 of 93 red lines and 112 of 144 blue lines - shore
noise included. So every gate below was tried on these pings before any app code.

---

## 1. What the run shows

### 1.1 The runaway on the shore, exactly as predicted (red)

At 14:58:32 the app committed the red on the shore at a 3 m range. In **three seconds** the dynamic scheme went
3.0 -> 7.0 -> 15.5 -> 25 -> 31 -> 48.5 -> 52 m (`DYNAMIC: plan` lines) and stayed at **51 m (1020 x 50 mm @ 118 ms)**,
the readout at **40.3-45.9 m** for as long as the boat was ashore (14:58-15:00:50, 15:04:00-15:04:45, 15:06:20-15:07).
`BT: last 10 s` there: every epoch far end, **ratio max 0.90**, rangefinder live **0.12** the whole time.

- The ratio cap of 0.90 is the algorithm's own search edge (F4), now measured on the device.
- Every step of the climb is a jump of 4-11 m confirmed within one processing pass - the 5 m / 3-sample jump filter
  cannot stop it (see 1.5).
- **Back in the water the real bottom wins at once**: at 15:00:58 the bottom track found 0.53 m in the 51 m range and the
  scheme came down to 3 m in the same second. A real echo beats the far-end noise; the problem is only when there is none.

### 1.2 Blue on the shore: 12-20 m at a 25 m range, 31-35 m at 50 m - and a cap at 35.06

- At 25.1 m per side (15:07-15:10:50) the bottom track read **11-19.82 m**; at 50 m (15:20:24-15:21, 15:39-15:40,
  15:46) **25-35.06 m**. Rangefinder live 0.15-0.18.
- **35.06 is a hard ceiling**: blue's `distProcessing` has `maxDistance` **35** (`distProcPulseBlue[4]`), so the search
  ends there whatever the range. Hence the ratio on the shore is only 0.63-0.70 at 50 m - a plain "far end of the range"
  gate misses most of it (1.6).
- **No readout above 35.02 m is in the log** for the blue (10 s lines and 1 m crossings). Where the "40+ on the shore"
  was seen is an open question (Q1) - candidates: a playback of the blue log while a red was committed (red's `maxDistance`
  50 would allow 45), or something fed by the rangefinder (1.4).

### 1.3 The rangefinder is frozen in the app while the bottom track is the source - confirmed (F2)

`DEPTH: ... rangefinder 0.12 (now 0.12, live 1.23 raw, 0.0 s old)` in the water at 15:01:20 (red), and
`rangefinder 18.90 (now 18.90, live 9.58 raw ...)` on the blue at 15:14 - `dataset.dist` holds a value from before the
switch, the live reading moves. Anything that would choose the rangefinder today chooses a stale number.

### 1.4 The rangefinder itself: red clean, blue spiking

From the 10 s `BT:` windows in the water (bottom track 0.5-15 m, no far end):

| | windows in water | rangefinder max > bottom track + 5 m | rangefinder 0.00 | on the shore |
|---|---|---|---|---|
| red | 18 | **0** | 0 | 0.12 steady; **40-44 m** in 4 of 23 windows |
| blue | 156 | **31 (20%)** - 24-44 m spikes | 56 (from 15:25 the device sent 0) | 0.15-0.18 steady |

Where both read the bottom they agree closely: red 0.4-5.6 m within ~0.1-0.3 m; blue 4-11 m with the rangefinder
~0.2 m deeper. **The rangefinder is only a fallback for the shallows, never a source on its own** - Olav's own reason
for moving to the bottom track, now in numbers. The `.plog` cannot help here: the device's depth arrives as NMEA `DBT`,
and the logger does not record NMEA.

### 1.5 The jump filter does not filter, and the readout flickers (new)

Each realtime pass re-publishes the last ~6 epochs (the BT window): **~6 writes per ping** (840 per 10 s at
13.9 pings/s), each one a separate batch, so `bottomTrackDepthChanged`, `filterDepthRecords` and NMEA see every
re-publish in turn, oldest to newest. On the bench:

- A jump > 5 m is confirmed by three *consecutive epochs of the same pass* - within ~70 ms. The runaway's steps (4-11 m,
  each confirmed in one pass) go straight through.
- ~1% of publishes are NaN (no bottom); each one resets the filter (F6), and the next value is accepted unconfirmed.
- The readout jumps between the values of different epochs within milliseconds - the burst of `crossed above/below 1 m`
  lines at 14:58:32-33 (0.84 / 1.88 / 1.50 / 1.22 ... in the same 10 ms).

### 1.6 The shore can be told from the echogram itself - two gates, tried on every ping

Labelled from the two recordings (shore stretches vs water), per epoch:

| gate | red: shore removed | red: water lost | blue: shore removed | blue: water lost |
|---|---|---|---|---|
| **A - geometry**: bottom track > 0.75 of the *reachable end* = min(maxDistance, 0.9 x the trace's range) | 94.0% | 0.03% | 92.3% | 0.29% |
| **B - echo contrast**: trace peak at the found bottom (+-0.1 m) / trace median past 0.4 m < 1.5, majority of 9 epochs | 93.1% | 0.00% | 99.9% | 1.71% |
| **A or B** | 94.2% | 0.03% | **99.9%** | 1.71% |

- Real bottoms in the water: at most **0.64 of the range** on the red (only right after the scheme shrank the range under
  a 5 m bottom), **0.39** on the blue. The shore values: 0.78-0.90 on the red.
- What A misses on the red is the edge of the water (bottom track at its 0.32 floor, transducer touching) - harmless, no
  runaway. What A misses on the blue is the 35 m cap; B catches it.
- B's "water lost" on the blue is the first ~110 pings after entering the water at 15:11 (bottom track 0.3-12 m and the
  rangefinder 0.2-10 m disagreeing in very shallow water) and a shore stretch mislabelled as water - readings that are
  most likely wrong anyway.
- The algorithm's own peak score does **not** separate shore from water (7-10 M on both): the distance ramp lifts far-end
  noise to the score of a real bottom. So upstream's `threshold` is not a usable "no bottom" knob here.

### 1.7 The shallows (F5 confirmed, plus Olav's second echo)

- The red bottom track sits at **0.32-0.34 m** at its floor (log and bench), the blue at 0.32-0.36.
- With the rangefinder at 0.12-0.28 m the red bottom track read **0.44-0.70 m - about 2-3 x the rangefinder**: the second
  or third echo, Olav's observation on the screen. So "bottom track says ~0.5 m" in very shallow water is not a reading.
- Only ~85 shallow lines exist (the `BT:` line prints at most once a second, and only on a would-be rejection) - not
  enough to set the crossover. A dense shallow line is the one instrument still missing (P2).

### 1.8 The NaN and the epoch record (F3 stands)

Every per-epoch consumer (2D bottom line, 3D/mosaic, CSV, waypoint depth, loupe) reads the raw bottom track of the epoch.
Gates must therefore act where the epoch is written, and must be **deterministic per epoch**: each epoch is rewritten ~6
times as the window slides, so a rule that depends on "the last good value" would answer differently each time.

---

## 2. The plan - one idea per commit, for the coding chat

Order matters: P3 stops the runaway and the 40+ values; P9 must land with or before P3 reaches users, because P3 removes
the accident that today finds a deep bottom (see P9).

| # | what | where | proves it |
|---|---|---|---|
| **P1** | The bench in the repo (`tools/pulse-bt-bench/`) - **done in this session** | tools | README |
| **P2** | Instrument: a dense **`SHALLOW:`** line while bottom track or live rangefinder < 1.5 m - bottom track, rangefinder, ratio bt/rf, at most 5 a second | `Dataset` | a shallow-only sweep (P2 test below) |
| **P3** | **Gate A at the epoch write**: bottom track > 0.75 x min(maxDistance, 0.9 x trace range) is stored as no bottom (NaN, source unchanged) in `onDistCompleted` / `onDistCompletedBatch`; the `BT:` line counts *rejected* instead of *would reject* | `Dataset` | bench: 94% / 92% of shore pings gone, <0.3% water; device: on the shore the readout no longer climbs, `DYNAMIC: plan` stays shallow |
| **P4** | **Gate B, echo contrast** (peak at the bottom / trace median < 1.5, majority over 9 epochs) - computed from the epoch's own amplitude, no algorithm change | `Dataset` | bench: blue shore 99.9% gone; device: blue on the shore, nothing above a dash |
| **P5** | **One value per ping**: the readout and NMEA take the newest finite epoch of each pass, once; `filterDepthRecords` is fed once per epoch and ignores NaN (F6) | `Dataset` | no `crossed` bursts; the jump filter starts to mean something |
| **P6** | **The rangefinder always recorded** (upstream's behaviour: value and epoch); only the *choice* depends on the source. Fixes F2 | `Dataset` | `DEPTH:` "now" equals "live" |
| **P7** | **One depth, chosen in C++** - `Dataset` publishes it; readout, NMEA and the dynamic scheme read it; the QML `selectedDepth` only reads. Shallow crossover (**0.6 m, agreed 18 Oct**; exact numbers from P2): use the rangefinder only while it reads < ~0.6 m (hysteresis ~0.5/0.7) **and** the bottom track agrees it is shallow - at its floor (<= minDistance + 0.12 m), at ~2-3 x the rangefinder (second echo), or no bottom. Otherwise the bottom track | `Dataset`, `main.cpp` (NMEA), `PulseDepthEngine.qml` | bench + the shallow sweep; a blue rangefinder spike can never be shown |
| **P8** | **No bottom and the shore on screen**: no bottom (both gates) for >= 2 s -> hold the last value for those 2 s, then a dash; NMEA sends no depth. "On the shore" = no bottom AND the rangefinder steady at its ringdown (<= 0.18 m) or silent - then the dash immediately, as Olav asked (dash only when sure) | `PulseDepthEngine.qml` | shore: dash, no NMEA; water: unchanged |
| **P9** | **The dynamic scheme on no bottom**: hold the range, never feed a rejected depth; and a **search**: no bottom for >= 3 s while *not* on the shore -> double the range every ~2 s up to the maximum until a bottom is found, then the normal rule. Today the runaway does this by accident (a red started over 10 m of water at its 3 m range only finds the bottom because the false bottom drags the range out); P3 removes the accident | `PulseDepthEngine.qml` | start live over deep water: `DYNAMIC: search` steps, then the bottom |
| ~~P10~~ | ~~Blue's `maxDistance` 35~~ - **withdrawn 18 Oct (Q3)**: it should follow the performance mode max range; fixed in the performance-mode chat, not here | - | - |

**Not in the plan:** changing the algorithm (not needed - P3/P4 sit around it); lowering `minDistance` (F5: it would
report the ringdown); bounding the search from the last depth (restarts the bottom track, history-dependent); the upstream
`threshold` (1.6: does not separate).

**Classic:** P3-P7 are in `Dataset` (shared) and reach classic too; nobody uses classic any more (30 Sept).

### Tests for the coding chat

- **Bench first, for every gate change**: re-run both 18 Oct recordings and report shore removed / water lost.
- **P2 shallow sweep** (on the P2 build): drive slowly from ~1.5 m onto the shore and back, twice, recording a `.plog`;
  the `SHALLOW:` lines are what set P7's numbers.
- **Device after P3-P9**: the same run as 18 Oct - shore -> water -> shore with the red, a mission with the blue - plus one
  start of the app with the boat already over deep water (P9).

## 3. Questions for Olav

- **Q1** Where did you see the 40+ m on the blue - the on-screen depth, Seascape (NMEA), or a playback afterwards? The log
  has no blue readout above 35.02 m, and the bottom track cannot exceed 35.06 with blue's `maxDistance` 35.
- **Q2** The crossover: you suggested ~2 m. The data says the bottom track is right from ~0.4 m upwards and the blue
  rangefinder spikes in 20% of 10 s windows, so I propose using the rangefinder only below ~0.6 m and only when the bottom
  track agrees it is shallow. OK?
- **Q3** Blue's `maxDistance` 35 with performance mode reaching 50 m per side - keep, or raise to the configured swath?
- **Q4** Gate B gives up ~110 pings of very shallow, confused readings on the blue as it leaves the shore (a dash there
  instead of 0.3-12 m). Acceptable?

---

## 4. Olav's answers, 18 Oct - and what they change

- **Q1 - the blue's false readings:** ~19 m as shipped, ~30 m with performance mode (5000 samples, fine spacing) - the
  measured 11-19.8 m at 25 m per side and 25-35.1 m at 50 m. Not 40+. Documented in the performance doc, chapter 10a.
- **Q2 - the crossover: 0.6 m, not 2 m.** *"If the findings are conclusive we need not apply it deeper than 0.6 meters
  then this is the refinement based on logs and we use that instead of 2 meters."* P7 uses 0.6 m (hysteresis ~0.5/0.7),
  final numbers from the P2 shallow sweep.
- **Q3 - blue's maxDistance should follow the performance mode max range.** Overlooked in the performance-mode beta. **Not
  in this work**: it goes to the performance-mode chat with the 10 m max-range issue. **P10 is withdrawn from this plan.**
  P3's reachable end already uses min(maxDistance, 0.9 x range), so the gate stays right when that changes.
- **Q4 - the blue left the shore with only ~5-15 cm of water under it.** So the ~110 confused pings at 15:11 were a
  transducer too shallow to measure at all, and a dash there is correct. **Gate B's water cost on the blue is in fact
  zero** on this data.

### 4.1 The shallowest depth the log shows as stable

"Stable" here = 9 consecutive pings within max(3 cm, 5%) of each other, with a clear echo (contrast >= 1.6), from the
bench, binned by the bottom track's own value in the water stretches:

| bottom track | red: pings | red: stable | blue: pings | blue: stable |
|---|---|---|---|---|
| 0.30-0.34 m (its floor) | 337 | 75% - *stuck at the floor, not a reading* | 293 | 67% - *floor* |
| 0.34-0.40 m | 150 | 69% | 197 | 55% (half at the floor) |
| 0.40-0.50 m | 317 | 79% | 54 | 22% |
| 0.50-0.80 m | 249 | ~52% | 128 | ~15% |
| 0.80-1.00 m | 233 | 73% | 48 | 52% |
| 1.00-1.50 m | 1260 | **94%** | 88 | 78% |
| 1.50-2.00 m | 363 | **91%** | 79 | 61% |
| 2.00-3.00 m | 191 | 81% | 147 | **95%** |
| 3.00-5.00 m | 367 | 89% | 384 | **99%** |
| 5.00-12 m | 310 | **97%** | 6526 | **96-100%** |

**What it says, and how far it can be trusted:**

- **Red/black: stable from ~1.0 m**; between 0.4 and 1.0 m about half to three quarters of the pings; below ~0.35 m it
  cannot read at all (the floor), and with the rangefinder at 0.12-0.28 m it reads the second or third echo (1.7). That is
  what the 0.6 m crossover is for: the rangefinder below it.
- **Blue: stable from ~2 m on this data, probably from ~1 m.** But the blue drove through 0.4-2 m in well under a minute
  each time over a sloping bottom, so "unstable" there is partly a bottom that really changed - only ~300 blue pings lie
  between 0.4 and 2 m. One quiet moment says more: **at 15:25:01 the blue lay still in ~0.4 m of water for 10 s, bottom
  track 0.34-0.38, rangefinder 0.37-0.43** - both agreed. So 0.4 m can be read; whether it is reliable cannot be said from
  this log.
- **A firm minimum for the blue needs a stationary test** (on the P2 build, `SHALLOW:` lines and a `.plog`): the blue held
  still at about **0.3, 0.5, 0.8, 1.2 and 2 m**, 20 s each, the depth checked by hand (a pole or a line). Then the
  statement for the manual is a measurement, not a guess.

---

## 5. Two clarifications before coding (18 Oct)

### 5.1 Why the crossover is 0.6 m when the bottom track is "stable" only from ~1-2 m

- **Stable is not the same as right.** Between 0.4 and 1 m the red bottom track agreed with the rangefinder whenever both
  were logged together (15:03:20 0.43 / 0.45, 15:03:30 0.39 / 0.37, 15:05:00 0.44 / 0.44, 15:05:10 0.90 / 0.90). The
  "unstable" share there is mostly the boat moving over a sloping bottom near the shore; the stability measure counts a
  real change as instability.
- **The bottom track is wrong, not just jittery, only below ~0.35 m**: at its floor (0.32) or on the second/third echo
  (0.44-0.85 m while the real depth is 0.12-0.28 m).
- **So the switch is keyed on the rangefinder, not on the bottom track**: rangefinder < 0.6 m AND the bottom track at its
  floor or at ~2-3 x the rangefinder (or no bottom). That catches wrong bottom-track values up to ~0.85 m (and further),
  which a bottom-track threshold of 0.6 would miss.
- **Why not higher:** between 0.6 and 2 m both agree, so the rangefinder buys nothing there; it adds its own failures (its
  0.12 ringdown whenever it loses the bottom, the blue's spikes and zeros); and every switch is a visible step (the blue's
  rangefinder reads ~0.2 m deeper).
- **Per model:** 0.6 m is from the red. The blue's band is set by the stationary test (4.1); if the blue needs 1 m, the
  threshold is a profile value.

### 5.2 The big-jump filter - its purpose, why it fails, what a reliable one needs

Olav: the filter was written to *drop insane values so they do not infect the CSV log of the angler capturing
bathymetric data*. Today it cannot do that:

- **It never reaches the records.** The 2D line, the 3D bathymetry, the CSV export and the waypoint depth read the raw
  bottom track of the epoch (F3). The filter only shapes the readout and NMEA.
- **The live CSV logger** (`Logger::loggingCsvStream`, switched on in ConnectionViewer) writes the epoch's *rangefinder*
  and a bottom-depth column that is always NaN. While the bottom track is the source, the epoch has no rangefinder (F2),
  so each row carries **0** as depth. *To confirm with Olav which CSV the anglers use* - this logger, the export, or a
  third-party app fed by NMEA.
- **It is fed ~6 re-publishes per ping**, so "3 agreeing samples" are three neighbouring epochs of one pass, ~70 ms.
- **A NaN resets it** (F6); **5 m is absolute**: a 4 m spike at 1 m depth passes, a real 6 m drop-off at 30 m is held.
- **It holds the previous value** - in a record that is a fake point, not a gap.

**P5b - the outlier filter, rebuilt** (replaces `filterDepthRecords`, after P3/P4 so it only sees what the gates let through):

1. **At the epoch write in `Dataset`**, the same place as the gates: one decision per epoch that the readout, NMEA, the
   2D line, the 3D surface, the export and the CSV all inherit.
2. **Deterministic per epoch**: the same epoch re-published six times gets the same answer.
3. **Reference = the running median of the last ~1 s of accepted epochs**, not the last value.
4. **Relative threshold**: an outlier is > max(0.5 m, 30% of the reference) from it - right at 1 m and at 40 m.
5. **A jump is accepted when it persists for ~1 s of distinct epochs** (time, not samples) - drop-offs persist, spikes do not.
6. **NaN is ignored**, never a reset.
7. **A rejected epoch is stored as no value (NaN)**, never the old value - a gap in the CSV and the bathymetry, not a fake
   point. The readout may hold the last good value meanwhile.
8. **When a jump is confirmed, the held epochs are rewritten with their real values** (epochs are rewritable; the bottom
   track already does it), so a real drop-off loses nothing in the records - it only appears ~1 s late on screen.
9. **Counted and logged** (`BT:` rejected by the outlier filter), and bench-tested on both 18 Oct recordings: zero rejects
   on the real slopes (red 1.4 -> 5.6 m at 15:01:40-15:02:10; blue 11 -> 2.5 m at 15:15:21-15:15:53), the spikes gone.
10. **The CSV logger** writes the chosen depth (P7) in its depth column - its own small commit, once Olav says which CSV
    matters.
