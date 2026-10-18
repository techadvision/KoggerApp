# The depth source on the shore and in the shallows - analysis and plan (18 Oct 2026)

Branch `feature/pulse-depth-source` (1.44 for experts, `b0d4711a`; built P2-P9 in section 6). Input: Olav's field run on 18 Oct from 14:58 -
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

---

## 6. Built - P2 to P9, 18 Oct 2026 (the coding chat)

Ten commits on `feature/pulse-depth-source` after the analysis, one idea each, `a90ae1c7..4c2cb91a`. Nothing has been
compiled by the coding chat (no Qt in its shell): the pure parts are unit-tested, the gates are bench-tested, the Qt
and QML parts are read, not run. **First build and the device run are Olav's.**

| # | commit | what landed | proof so far |
|---|---|---|---|
| bench | `a90ae1c7` | the bench's Python finally in the repo (`*.py` was ignored repo-wide; P1 had committed only the README) and `gates.py`, the shore checks: labels every epoch shore / water from the app log's clock and scores each gate | baseline below |
| P2 | `50321441` | `SHALLOW:` line, up to 5 a second under 1.5 m - bottom track raw (flagged at its floor), rangefinder live + age, bt/rf, floor, range | reads correctly in code; the shallow sweep is the test |
| P3 | `b14dd4b4` | gate A at the epoch write; `BottomTrackUpdate` carries the pass's `maxDistance`; `src/depth_gates.h` (pure C++, `tests/depth_gates_test.cpp` without Qt); `BT:` counts *rejected* | bench: red 100% / 0.45%, blue 92.7% / 0.00% |
| P4 | `247e12b9` | gate B on the merged `(a + b) >> 2` trace the bottom track itself saw, majority of the last 9 epochs | bench: blue 100% / 1.43% (the 5-15 cm pings, Q4), red 100% / 0.53% |
| P5 | `55129370` | one value per pass: collected per batch, published once in `onLastBottomTrackEpochChanged` - the newest epoch with a bottom, or NaN | by construction (one emit per pass) |
| P5b | `6cd181eb` | `depthgates::OutlierFilter` at the epoch write, after the gates: running median of the last ~1 s, relative threshold, ~1 s persistence, held = NaN, released on a confirmed jump; `filterDepthRecords` stays on the rangefinder path only | bench: zero held on both real slopes; 13 / 3753 red and 23 / 7780 blue water epochs held, all spikes or the second-echo step |
| P6 | `4c7b5a65` | the rangefinder always recorded (value + epoch); `dataUpdate` still only when it is the source | `DEPTH:` "now" must equal "live" on the device |
| P7 | `300b0931` | `Dataset::chooseDepth()` - `chosenDepth` / `chosenDepthSource` / `noBottom` / `onShore`; NMEA listens to it alone; the QML engine only reads | `tests/depth_gates_test.cpp` (the crossover cases) |
| P8 | `bc7a4745` | engine: hold 2 s then dash; on the shore the dash at once; both readouts draw `-.-` for NaN | device |
| P9 | `4c2cb91a` | the scheme reads the chosen depth, never a NaN; on the shore the range holds; in the water no bottom for 3 s -> `DYNAMIC: search`, range doubled every 2 s to the maximum, fresh plan when a bottom is found | device: start over deep water |

### 6.1 The bench, as it now runs

```
python3 tools/pulse-bt-bench/run2d.py testlogs/depth-source/2D_pulse_log_2026.10.18_15.00.29.plog "(1,5,0.04,0.25,50,2,0)" red.npz
python3 tools/pulse-bt-bench/run2d.py testlogs/depth-source/SS_pulse_log_2026.10.18_15.10.27.plog "(2,5,0.04,0.25,35,2,0)" blue.npz fill
python3 tools/pulse-bt-bench/gates.py testlogs/depth-source/2D_pulse_log_2026.10.18_15.00.29.plog red.npz  testlogs/depth-source/pulse_181026.log
python3 tools/pulse-bt-bench/gates.py testlogs/depth-source/SS_pulse_log_2026.10.18_15.10.27.plog blue.npz testlogs/depth-source/pulse_181026.log
```

The clock: the `.plog` has no timestamps, so `gates.py` accumulates the `LINK:` lines' ping rates from the file's start
time; checked against the red's range changes (`DYNAMIC: plan` against the range steps in the file) it is within ~1 s,
and a 5 s margin around each shore stretch is left unscored. The blue recording ends at 15:20:52 (8812 epochs) - only
its first 50 m shore stretch is in the file; 15:39 and 15:46 are in the log alone.

| gate | red: shore removed | red: water lost | blue: shore removed | blue: water lost |
|---|---|---|---|---|
| A | 100% (527) | 0.45% (17) | 92.7% (771) | 0.00% (0) |
| B | 100% | 0.53% (20) | 100% | 1.43% (113) |
| A or B | 100% | 0.56% (21) | 100% | 1.43% (113) |
| outlier (after the gates) | - | 0.35% held (13), 10 released | - | 0.30% held (23), 0 released |
| the real slopes | 1.42 -> 5.65 m, 413 epochs: **0 held** | | 2.09 -> 11.14 m, 448 epochs: **0 held** | |

The red's 17-21 "water lost" are the first two seconds after launching (the range still 51 m and the far-end 45 m values
the readout then showed - removing them is right), one 0.53 and one 4.6 m right after the range shrank. The blue's 113 are
the 15:11 pings with 5-15 cm of water (Q4). The red's 13 held are the 0.46 -> 1.1 m step at 15:03:53 - a second echo
taking over - released once it persisted; the blue's 23 are the 9-19 m spikes at 15:20:09-12 and the confused 15:11 pings.

### 6.2 What changed for whoever reads the code next

- **One decision per epoch, in `Dataset::gateBottomTrackLocked`**, under the pool lock, with the raw value from the
  processor: range -> gate A -> contrast and vote -> gate B -> outlier filter -> stored value (NaN = no bottom). Both the
  singular and the batch path go through it; a blue's two channels get the first channel's verdict.
- **The constants live once**, in `src/depth_gates.h` (`Params`, `OutlierParams`, `ChoiceParams`), mirrored by
  `gates.py` / `outlier.py`. Changing one without the other makes the bench lie.
- **`_bottomTrackDepth` is per pass**, offset-corrected, NaN allowed. **`chosenDepth`** is what the app shows and sends.
  `bottomTrackDepth` and `dist` remain as instruments.
- **The crossover** (`ChoiceParams`): rangefinder < 0.5 in, > 0.7 out, only while the bottom track is at its floor
  (`minDistance` + 0.12), a second echo (1.7-3.3 x) or absent. At 15:03:30 (bt 0.39 / rf 0.37) the bottom track keeps
  the readout: both read the bottom and it is right. The blue's band is still the stationary test's to set.
- **"On the shore"** is computed in C++ (no bottom AND the rangefinder <= 0.18 for the last ~1 s, or silent) so NMEA and
  the readout agree. **In a replayed file the rangefinder is always silent** (the logger does not record NMEA), so a
  no-bottom pass in a replay shows the dash at once rather than holding 2 s. Accepted; say so if it surprises in a demo.
- **The outlier window is time**: the epochs that arrived in the last second (live), 14 in a replay.
- `filterDepthRecords` is now the rangefinder-only path's filter. `_useDepthFilterWithBottomTrack` switches the new one.
- The QML engine's `isBottomTrackInitiated` / side-scan source rule is gone with its 0.0 fallback; `processBottomTrack`
  (a profile value) is what the Dataset chooses from.

### 6.3 Still open

- **5.2 item 10, the CSV logger** writing the chosen depth - waits for Olav's answer on which CSV the anglers use.
- **Q3 / P10**: blue's `maxDistance` following the performance-mode range - the performance-mode chat.
- **The P2 shallow sweep and the stationary blue test** (4.1) set the final crossover numbers.
- **Device after P3-P9**: the 18 Oct run again (shore -> water -> shore with the red, a mission with the blue), one start
  over deep water for the search. Lines to look for: `BT: last 10 s | ... gate A rejected N | gate B rejected N | outlier
  held N`, `DEPTH: chosen source ... -> none (shore)`, `DEPTH: on the shore ... dash`, `DYNAMIC: search`, and the
  `DEPTH:` 10 s line's `(now x, live x)` agreeing.

---

## 7. After the first replay (18 Oct, evening) - reading the BT: line, the shore as a pill, the bottom track's knobs

### 7.1 The `BT:` lines in Olav's replay, and what was wrong with them

Olav replayed both 18 Oct logs on the new build: the bottom line followed the echogram and the readout was right, yet the
log said `BT: epoch 1509 | bottom track - m raw of 25.13 m acquired (-) | ... | no bottom` once a second and
`no bottom 1065` of 4323 publishes in 10 s.

**How to read the line.** `bottom track - m raw` is the value the processor delivered for that epoch *before* the gates
(`-` = none); `of 25.13 m acquired (-)` the trace's range and the value's fraction of it; `rangefinder live 6.48 (0.1 s
old)` the raw device depth and its age; and the last field is the **reason the line was printed**, not a count - the line
only prints (at most once a second) when something is worth saying: `gate A rejected ...`, `gate B rejected ...`, `held by
the outlier filter`, `kept, disagrees with the rangefinder`, or `no bottom`. The counts are in the `BT: last 10 s` line
only. So "no number next to it" is not "OK" - it is a reason; a quiet second prints nothing at all.

**Why a quarter of the publishes said "no bottom" while everything looked right.** The window is centred: epoch *i*
gets its value when epoch *i* + windowSize/2 has been processed, so every pass publishes its newest windowSize/2 epochs
as NaN and the next pass fills them (~70 ms later). Live, the dataset runs ~2 epochs ahead of the pass and the tail is
reached; a replay feeds the dataset in bursts and leaves it unreached every pass. The instrument reports the newest
epoch of each batch - exactly those - and counted them. The readout never saw it (P5 takes the newest epoch *with* a
bottom), the line was drawn once the value arrived. Fixed in `e99e4fe6`: `BottomTrackUpdate.pending` marks the unreached
tail; the Dataset stores NaN for it as before but gives no verdict, no vote, no count and no line. The `no bottom` count
now means what it says.

### 7.2 "Out of the water" as a pill - can it be said with confidence?

The shore state in C++ is: no bottom this pass **and** the rangefinder at its ringdown for the last ~1.5 s, or silent.
Checked window by window against the 18 Oct log (97 water windows, 10 shore windows across both recordings): **no water
window meets the rule, every shore window does** - after two corrections made in `ada19e6d`:

- **A rangefinder of 0.00 is no reading.** The blue sent 0.00 from 15:25 on while tracking a 5-11 m bottom; 0 <= 0.18
  would have counted as "ringdown", and one pass without a bottom there would have been "the shore". Now 0 is treated like
  silence everywhere the rangefinder is judged (the choice, the shore, the `BT:` and `SHALLOW:` lines).
- **Ringdown by two thirds of the readings, ceiling 0.22 m.** The red's rangefinder spikes to 40-44 m on the shore now
  and then (4 of 23 shore windows), which broke an all-readings test; the blue read 0.20 on the shore at 15:20:33.

What "silent" means in practice: with a live device the rangefinder is always there, so the state is driven by the
ringdown; **in a replay it is always silent** (the logger does not record NMEA), so every no-bottom pass in a replay is
"the shore" - a dash at once, and a pill would appear in demos. For the pill, therefore: **require the positive evidence**
(a rangefinder reading at its ringdown), **sustained for ~3 s**, auto-dismissed when a bottom returns; never from silence
alone. Under that rule the 18 Oct data gives zero false alarms and every shore stretch after 3 s. One day of data is not
"9x %" - but the rule is built from two independent instruments agreeing (no echo in the trace, the rangefinder hearing
only itself), and the failure that would fool both is a genuinely unmeasurable situation (a transducer in 10 cm of water),
where Garmin's wording - "too shallow or out of water" - is honest anyway. Recommendation: build it (small: the engine
already has the state; a pill like "You scrolled back", text "Out of the water or too shallow"), with the 3 s rule and
the positive-evidence rule. **Not built yet - waiting for Olav's go.**

### 7.3 The bottom track's three knobs - what each does in the algorithm

From the port (`tools/pulse-bt-bench/bt.py`, line for line `bottom_track_processor.cpp`). Per epoch the trace is turned
into a **"cash" profile**: a moving average whose width grows with distance (`init_win`, `scale_win`), then an edge
detector - a weighted sum of the profile at five scaled positions (`c1..c5` at `i`, `1.1 i`, `1.2 i`, ...): negative
weight just before, positive at and after, so the score peaks where the trace *rises and stays up* - the leading edge of
a bottom. Then the score is multiplied by a **distance ramp**, and the per-epoch profiles are **summed over the window**;
the bottom is the argmax of the summed score within [minDistance, maxDistance], refined within the **vertical gap** on the
centre epoch's own profile.

- **Gain slope** is the ramp: score x (1000/gainSlope + distance in cm). It exists because a far echo is weaker than a
  near one and the detector would otherwise always prefer the near, loud edge (the ringdown's tail, fish, the thermocline).
  With gain 2 the factor is 850 at 3.5 m, 1200 at 7 m, 1900 at 14 m, 2500 at 20 m - **a 20 m feature is given three
  times the weight of a 3.5 m bottom**. That is the whole mechanism of the shore runaway and of the gravel pit's far
  false bottoms. Lower gain = less far preference; it does not make the near echo any louder.
- **Window** is the temporal sum: W epochs vote on where the edge is. More W = more robust to one noisy ping, and a slower
  tracker: the value for epoch *i* is known only after W/2 more pings (the centred window), so **the delay is W/2 pings -
  0.14 s at W 5, 1.07 s at W 31 at 14 pings/s**, exactly what Olav measured; and on a slope the summed peak smears, so a
  changing bottom is read late and a short false excursion is *spread* over more epochs rather than removed.
- **Vertical gap** is the per-epoch refinement: within +-gap x the windowed position, this epoch's own profile picks the
  exact edge. It sets precision against noise: 0.04 at 3.5 m lets the value wander +-14 cm per ping (the 90th percentile
  of |delta| was 6 cm at 0.04-0.08 and 3 cm at 0-0.02 in the gravel pit); it has **no effect on false bottoms** - a wrong
  windowed position is refined wrongly.
- **Threshold** (minimum summed score) does not separate anything (section 1.6): the ramp lifts far-end noise to the score
  of a real bottom.

### 7.4 The ANDY gravel-pit log, swept (`tools/pulse-bt-bench/sweep.py`) - corrected the same evening

`SS_pulse_log_ANDY_2026.10.03_11.16.09.plog`: a blue in ~3.5 m of water with 25 m per side, 5293 epochs, the bottom
track at 3.3-3.5 m with excursions to 7 m (the second echo, 2 x), 10-15 m (3-4 x) and 18-20 m. There is no ground truth.

**The first version of this section was wrong, and Olav's eye caught it.** Its reference was the baseline run's own
rolling median, which the baseline's 2-4 s excursions drag along, so every other setting was scored against the
baseline's mistakes and looked worse than it was; it concluded "keep W 5 and gain 2". Olav's own tuning (W 30, gain 1.0,
vgap 0) visibly cleaned the same stretch. The reference is now the +-5 s rolling median of the per-epoch median across
all sets with gain <= 2 (the gain 4-8 sets are wrong on their face and may not vote), and the table counts excursions.
Judged after the gates and the outlier filter *as rebuilt below* (7.6):

| W | gain | vgap | false (raw) | excursions (>= 1 s) | longest | after gates+filter: false | dash | delta p90 | delay |
|---|---|---|---|---|---|---|---|---|---|
| **5** | **2** | **0.04** (profile) | 6.63% | 37 (7) | 69 ep | **3.41%** | 5.2% | 0.06 m | 0.14 s |
| 15 | 2 | 0.04 | 5.24% | 15 (6) | 64 | 3.11% | 2.9% | 0.06 | 0.50 |
| 31 | 2 | 0.04 | 3.41% | 9 (5) | 52 | 2.29% | 1.7% | 0.03 | 1.07 |
| 5 | 1 | 0.04 | 2.36% | 16 (2) | 41 | 1.66% | 0.9% | 0.03 | 0.14 |
| 5 | 0.5 | 0.04 | 1.29% | 12 (1) | 26 | 0.72% | 0.8% | 0.03 | 0.14 |
| 9 | 1 | 0 | 2.02% | 9 (2) | 41 | 1.65% | 0.6% | 0.00 | 0.29 |
| **15** | **1** | **0** | 1.78% | 7 (3) | 37 | 1.43% | 0.7% | 0.00 | 0.50 |
| **15** | **0.5** | **0** | 0.81% | 6 (1) | 16 | **0.30%** | 0.7% | 0.00 | 0.50 |
| 21 | 1 | 0 | 1.63% | 8 (3) | 22 | 0.99% | 1.2% | 0.00 | 0.71 |
| 31 | 1 | 0 (Olav) | 0.97% | 5 (2) | 16 | 0.36% | 1.0% | 0.00 | 1.07 |
| 31 | 0.5 | 0 | 0.45% | 3 (0) | 12 | 0.46% | 0.4% | 0.00 | 1.07 |
| 5 | 4 | 0.04 | 13.5% | 49 (12) | 94 | 4.64% | 11.7% | 0.09 | 0.14 |
| 5 | 8 | 0.04 | 23.2% | 82 (24) | 124 | 8.59% | 18.9% | 0.21 | 0.14 |

What it says:

1. **Gain slope is the knob, and lower is better for the blue** - exactly what the ramp predicts (7.3): at gain 2 a
   20 m feature outweighs a 3.5 m bottom three to one. Gain 1 halves the false readings, 0.5 halves them again
   (6.6 -> 2.4 -> 1.3% raw at W 5). The gates then take the far half of what is left.
2. **The window helps on top**, at its price in delay: at gain 0.5-1, W 15 (0.5 s) removes most of the remaining
   excursions, W 31 (1.07 s) a few more. Olav's reading - reliability for latency - is right; the gates do not change
   that trade, they make it cheaper by taking the far features that no window removes.
3. **Vertical gap 0 (or 0.02)**: precision only - the ping-to-ping jitter halves (3 cm vs 6 cm) with no change in false
   readings.
4. **Gate B was too eager for a blue in shallow water** - found here, fixed. A blue's nadir echo is weak (peak ~42 of
   255 at 3.5 m) and the side-scan returns beyond nadir raise the trace median, so B at 1.5 dashed 5% of the real
   bottom, in runs of up to 5 s. B now judges only a bottom beyond **half the reachable end**, where the false bottoms
   it exists for live (shore 0.78-0.99, blue's cap 0.67-0.88 of the reach; real bottoms 0.15-0.5). ANDY good-dashed
   5.2% -> 0.34% with the far features still removed; the 18 Oct blue's water lost 1.43% -> 0.15%; the red unchanged.
5. **Recommendation for the blue profile: W 15, gain 0.5, vertical gap 0** - 0.30% residual on ANDY with 0.5 s of
   delay, and on the 18 Oct blue it removes 100% of the shore, loses 0.00% of the water and holds nothing. Olav's
   (30, 1.0, 0) is the same picture at 1.07 s. **The profile is not changed in this branch** - Olav's call, and one
   more log would be good before it is. The red (preset 1) has not been swept at all.
6. **What is left after everything is the second echo** (runs of 1-3 s at 7.06 m) and near features inside half the
   reach. The second echo has a bench-confirmed signature: an echo at **half** the candidate's distance at least as
   strong as at the candidate (83-100% of the second-echo epochs; but 2-3% of good epochs also have a loud half-point,
   so the test alone is not enough) **and** the half matching the reference the outlier filter already keeps. The two
   together never fire on a real bottom in this log. Candidate **P11**; not built.

### 7.5 Commits this round

`e99e4fe6` pending tail - `ada19e6d` rangefinder 0.00 / ringdown rule - `82aab06b` gate B beyond half the reach,
`sweep.py`, this section - `ec950cf1` the shallows and the shore after the second replay (7.6).

### 7.6 Olav's second replay - the shallows are not right yet, and what was wrong

**The ANDY replay with a blue on the desk.** The replay's `rangefinder live 0.23` came from the live device beside the
tablet (the ANDY `.plog` carries no `ID_DIST` at all; the demo plays into a dataset the connected device also feeds).
That exposed a real flaw: `DEPTH: chosen source bottom track -> rangefinder (shallow)` flipped every time the gates
emptied a pass, because "no bottom" counted as the bottom track *agreeing* that it is shallow, and 0.23 < 0.5. **No
bottom is not agreement** any more: the rangefinder takes over only when the bottom track is at its floor or on a
second echo. In the field this would have shown 0.2 m for a pass whenever a far feature was gated away.

**The 18 Oct blue leaving the shore (15:11).** Olav's log: the bottom track at its floor (0.32, rangefinder 0.29-0.36)
jumps to 12.31 m in one epoch; the outlier filter holds it (`held by the outlier filter`), it persists ~1 s and is
*confirmed*; the held epochs are rewritten and a 9-10 m block stands for 6.6 s over 5-15 cm of water, while the
rangefinder reads 0.3-0.6 the whole time. Three changes to the filter (`depth_gates.h`, mirrored in `outlier.py`):

- **A big jump needs longer.** Persistence is 1 s for a jump of up to 2 m, +0.5 s per metre beyond, capped at 4 s: a
  bottom cannot change by 12 m inside one second under a moving boat. A real drop-off from 0.3 to 10 m (a quay wall)
  now appears up to 4 s late on screen and loses nothing in the record (the release still rewrites).
- **The rangefinder is a witness** - never a value. While it is a fresh reading that agrees with the old reference and
  not with the candidate (0.3-0.6 against 0.32, not against 10), the confirmation is vetoed, for up to 8 s; the veto is
  remembered for a window, so one spike (the 8.24 in that stretch) cannot open the door. A rangefinder that reads the
  new depth too (a real drop-off) vetoes nothing.
- **The reference is the last 14 *accepted* epochs**, not the last 14 epochs: a held stretch used to empty the
  reference, and the next value walked in unjudged - a backdoor past the persistence rule.

The bench cannot carry the witness (no rangefinder in a `.plog`), so on the bench that 15:11 block is still confirmed at
4 s; on the device it is vetoed for its whole 6.6 s. Both slopes stay at zero held; red and blue 18 Oct otherwise
unchanged.

**The shore rule got a third instrument.** With the desk device's rangefinder at 0.23 and the ANDY far features gated
away for 4 s, "no bottom and ringdown" was one centimetre from "the shore". In air there is no return at all: the 95th
percentile of the trace past 0.4 m is <= 15 on the blue's shore and <= 59 on the red's, against >= 32 (ANDY) / >= 47
(18 Oct) / >= 70 in the water. The shore now needs **no bottom AND a quiet trace AND (ringdown or silent)** - thresholds
26 blue, 65 red, by the bottom-track preset; ringdown ceiling 0.25. The `BT: last 10 s` line prints `trace p95 a-b` so
the thresholds can be checked on every run; `disagree` is counted, not printed.

**Was the build current?** Olav's log shows it was: `no bottom 0` with the pending tail, `gate A rejected ... gate B
rejected: no echo (contrast 1.14)` at 0.79 of the range, `held by the outlier filter`. Nothing from this section
(`ec950cf1`) is in it yet.
