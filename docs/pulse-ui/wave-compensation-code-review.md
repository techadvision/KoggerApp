# Wave-motion compensation: code review, log validation and solution design

| Version | Date | What changed |
|---|---|---|
| v1 | 13 Oct 2026 | Read-only code review of *"Wave-motion compensation for Pulse echograms and side scan: initial analysis"* (Olav, 11 Oct 2026) |
| v2 | 13 Oct 2026 | Olav's answers worked in; solution design (section 5) |
| **v3 (final)** | 13 Oct 2026 | Assumptions checked against a real Pulse Blue log with MAVLink (`SS_pulse_log_2026.01.14_Titan.plog`, section 6). Bottom-track findings corrected. Depth-source design reworked to Olav's goals (no fixed crossover). Mosaic causes re-ranked. |

No app code was changed. The offline bench used for section 6 (a `.plog` parser and a line-by-line port of the bottom track) is in `docs/pulse-ui/wave-compensation-bench/`.

| Source | Version |
|---|---|
| `KoggerApp` (Pulse) | `feature/pulse-depth-source` @ `b0d4711a` |
| `dronekit` (fork) | `recover/local-edits` @ `078f7579` |
| ArduPilot reference | `dronekit/ClientLib/libs/ardupilot`, `ArduPilot-4.6.0-beta1-4316-ge682702ded` (master, Oct 2025) |
| Log | `SS_pulse_log_2026.01.14_Titan.plog`: Pulse Blue, 14 Jan 2026, 14:59–15:04 UTC, 288 s, 8.5 MB |

Verdicts on the analysis: **Confirms**, **Corrects**, **Contradicts**. **Out of scope** means another repo, field data or a datasheet.

---

## 0. Decisions from Olav

1. **Forwarding stays in the DroneKit fork.** The ESP design (vehicle stream into KoggerApp, KoggerApp forwards it) is not an option. The apps may control the fork, or forward themselves, if the design needs it.
2. **The duplicates are by design:** one device, possibly with no Wi-Fi or mobile data, or several devices on one network. **Pulse must remove them.** This is a required bug fix.
3. **The fixed 1 Hz is an old ELRS workaround.** It becomes a user preference in the upstream app: 1 Hz stays as one option, alongside a high-performance mode up to what ArduPilot can deliver.
4. **The time link between pings and motion has to be solved.**
5. **The side scan mosaic centre artifacts** are investigated and fixed as part of this work.
6. **Use the pitch and roll already in the epochs.** Add MAVLink messages only if precision demands it.
7. **Depth source (13 Oct, latest):** "rangefinder up to 2 m, then bottom track" is **not a fixed condition**. Tune it for the best overall result. The two goals are to **eliminate the crazy on-shore readings** and to **allow fairly shallow readings**; bottom track has trouble below about 0.5 m, possibly because of its settings. The bottom-track profiles are `distProcPulseRed` and `distProcPulseBlue` in `PulseRuntimeSettings.qml`.

---

## 1. The findings that drive the design

The ✔ column shows whether the Titan log confirms each finding.

| # | Finding | ✔ |
|---|---|---|
| 1 | The fork forwards `HEARTBEAT`, `ATTITUDE`, `GLOBAL_POSITION_INT` and `SYSTEM_TIME`, and nothing else. `GLOBAL_POSITION_INT` already carries EKF `alt` (mm) and `vz` (cm/s); Pulse drops them. | ✔ exactly these 4 |
| 2 | The fork requests **1 Hz** on all streams. | ✔ 1000 ± 1 ms, all 288 s |
| 3 | Each forwarded message arrives twice on one device (broadcast + loopback). | Not in this log: the loopback copy was added to `UdpSender` on 15 Aug 2026, after this recording. Newer logs will have duplicates. |
| 4 | Attitude reaches the epochs by arrival order, with no time. ATTITUDE's `time_boot_ms` is dropped. | ✔ the arrival position of each burst among the pings wanders by ±45 ms (1σ) short term and ±100 ms over minutes |
| 5 | Interpolated pitch and roll are wrapped into 0–360°. | Code (roll in this log stays within −4.4…+3.4°, so interpolated negative roll would show as ~356°) |
| 6 | The per-ping transducer timestamp is off (`datasetTimestamp: 0`) and ignored on Android. | ✔ no `ID_TIMESTAMP` or `ID_EVENT` frames in the log |
| 7 | The `.plog` has no host time. | ✔ raw frames only |
| 8 | **Bottom track (v3, corrected):** the 5-epoch sum only selects the region; the ±4 % refine returns the single-ping pick. But the pick is **written one epoch late**, and the sum covers 4 epochs, not 5. | ✔ in the port: shipped track at epoch *i*+1 = single-ping pick at *i* (mean difference 0.6 mm) |
| 9 | The firmware rangefinder is fooled on Blue, and reports a fixed **~0.27 m** in deep water. | ✔ 3.3 % of pings at 0.256–0.278 m while the bottom is 3–9 m; 4 % shorter by >1 m |
| 10 | The mosaic draws each ping with the yaw, position and altitude its epoch has at first draw, and never redraws. Altitude errors are amplified near nadir. | Code; the log ranks the causes (section 6.6) |
| 11 | **Replay creates a duplicate position every second.** The second MAVLink block emits each `GLOBAL_POSITION_INT` again, with boot-ms as the time, which opens a new epoch. The next ping then shares the previous ping's position. | Code (the log contains `SYSTEM_TIME`, so the first emit gets 2026 time and the second gets 1970) |
| 12 | `$PUDBT` / `$PUMTW` read as proprietary sentences. | Code |

---

## 2. (a) Answers to the section 11 questions

Only the answers that changed in v3 are written out in full. The rest are condensed from v1/v2.

**Q1 NMEA:**

- `$PUDBT` / `$PUMTW` over UDP to the broadcast address plus `127.0.0.1`, port 3500 (3000–3500), every 250 / 500 / 1000 ms (depth) and 1000 ms (temperature).
- The value is a sample-and-hold of the filtered, offset-corrected selected depth. Non-finite values are skipped; the fields go empty after `max(1 s, 2 × interval)`.
- *Corrects:* there is no per-ping output.

**Q2 manufacturer code:** none is registered. `$PU…` already reads as proprietary. Keep it for Carp Pilot Pro and Seascape, and add DPT/MTW plus a registered proprietary sentence.

**Q3 timestamp flag:**

- `"datasetTimestamp": 0` in `pulseRed` (`PulseRuntimeSettings.qml:2697`, which also serves Black) and in `pulseBlue` (`:2809`). Use `1` for channel 1. It sets `MASK_TIMESTAMP_V0`.
- The clock is the transducer MCU's. v0 (`U4`) or v1 (`U4 + U4 unix`) and the units are unknown.
- On Android it is ignored (`#if !defined(Q_OS_ANDROID)`, `device_manager.cpp:280–305`), but the frames land in the `.plog`.
- *Confirmed by the log:* no timestamp frames while the flag is 0.

**Q4 log format:**

- The `.plog` is raw frames in arrival order.
- **This log contains:** 38 030 chart fragments (`ID_CHART` v1, side scan interleaved) forming 3 811 pings; 3 815 `$SDDBT` (one per ping); 4 015 temperature frames; device polls; 290 `HEARTBEAT`; 289 each of `ATTITUDE`, `GLOBAL_POSITION_INT` and `SYSTEM_TIME`. No host time, no bottom track.
- **Every forwarded MAVLink frame has sequence number 0**, because the fork re-encodes with `pack()`. Sequence numbers cannot be used for loss or duplicate detection.

**Q5 interpolation:**

- Arrival-order assignment into `pool_.last()`, then linear interpolation between raw epochs using evenly spaced synthetic times.
- In this log, each second's burst arrives as **HB → ATT → GPI → SYS back to back**, with ATT and GPI sharing `time_boot_ms` (282 of 289 identical, the rest 1 ms apart). So the raw attitude and the raw position land on the **same** epoch, and the course-over-ground fallback yaw is not used for drawing.
- *Corrects* "exact match"; and see finding 11 (replay).

**Q6 upstream attitude/heave:** attitude per epoch yes; heave, vertical velocity and attitude time no. The lever arm is rotated by yaw only.

**Q7 forward list:** see finding 1. It is shared in the library base class; `ExperimentalApi.startUdpMavlinkForwarding()` turns it on. *Corrects:* ATTITUDE is already forwarded.

**Q8 stream rates:**

- `StreamRates` sends `REQUEST_DATA_STREAM` at 1 Hz for 8 groups on connect and on every heartbeat restore (`Rates(int)` ignores its argument).
- In ArduPilot this sets `SRn_*`, wipes per-message intervals for those groups, is **not saved on Rover**, and is ignored if `MAVn_OPTIONS` bit 2 "Ignore Streamrate" is set (`SERIALn_OPTIONS` in older releases).
- *Contradicts* "rates come from the boat's parameters". The log shows exactly 1 Hz.

**Q9–Q12:** out of scope (Seascape levelling, Carp Pilot Pro autopilots, beam angles, per-boat offsets).

**Q13 bottom track (v3, corrected):**

- **Where:** `BottomTrackProcessor::bottomTrackProcessing`, run live over `[prevTo − window, currTo)` → `Dataset::onDistCompletedBatch` → per-epoch `bottomProcessing.distance` and `filterDepthRecords` → readout and NMEA.
- **Parameters:**
  - Red/Black `[1 OneBeamNarrow, window 5, gap 4 %, min 0.25 m, max 50 m, gain slope 2, threshold 0]`.
  - Blue `[2 SideScan, 5, 4 %, 0.25, 35, 2, 0]`.
- **What it really does** (code, confirmed with the port on the log):
  1. A per-epoch edge response with a distance ramp.
  2. A running sum of the responses. Because of the subtract-before-overwrite indexing, the sum holds **window − 1 = 4** epochs, not 5.
  3. The maximum of the sum (between min and max) selects a region.
  4. With a gap > 0, the pick is refined within ±gap × index on the response of **the oldest epoch in the sum** (`win_center_index`).
  5. The result is written to `iepoch − window/2`, **one epoch after the epoch whose response was refined.**
  - In practice the output is the single-ping pick, delayed by one ping. The sum only rejects outliers. On the Titan log, shipped output at *i*+1 vs single-ping pick at *i*: mean |difference| 0.6 mm over 3 713 pings.
- **Gating:** none around the previous pick. **Confidence:** none. With threshold 0 there is no "no bottom" answer.
- **Floor:** the search starts at `int(minDistance / t1 / resolution)`. For Blue at 25 mm, that is index 8, so the shallowest reportable value is (8 + 2.4 + 1) × 1.2 × 0.025 = **0.34 m**. For Red/Black at 5 mm it is about 0.32 m (backlog F5). **The < 0.5 m trouble is mostly the settings:** `minDistance` 0.25 m plus the kernel's reach and the ringdown just beyond it (section 5.7).
- *Corrects* §7 of the analysis, and v1/v2 of this document. Heave is **not** averaged by the sum as long as it stays within ±4 % of depth: ±32 cm at 8 m, but only ±8 cm at 2 m. Beyond that, the refine clips towards the 4-epoch region. The one-ping write delay (about 70 ms) is a bug for heave timing: 4–7 cm at wave speeds (section 6.4).

**Q14 Red, Black and Blue:**

- Red and Black: one profile.
- Blue: port and starboard merged as `(a + b) >> 2` before the pick, giving one altitude.
- Lost chart fragments are filled from the previous ping by the black-stripe processor before bottom track runs (`Dataset::addChart`, `BlackStripesProcessor::update`; Blue forward steps 1). That is why Blue's bottom track survives a lossy link (section 6.3).

**Q15 log contents:**

- The `.plog` holds the rangefinder (`$SDDBT`, one per ping, recoverable by order) but not the bottom track (recomputed on replay).
- The dataset holds the bottom track; the rangefinder is not stored while bottom track is the source (F2).

---

## 3. Why upstream KoggerApp does not suffer from this

Upstream parses MAVLink arriving on the **vehicle side** (any link except the proxy) and forwards it to the GCS on the proxy. In the ESP topology, autopilot MAVLink and sonar frames share one stream near the boat. So arrival order is a fair proxy for time, there are no duplicates, and Kogger devices can carry an internal IMU in-band.

That is a reasonable trade-off in that topology. Pulse's topology has two paths with different, varying latencies: autopilot → radio → Android → DroneKit → UDP, and transducer → IP bridge. Pulse added a first block that parses frames *from* the proxy and kept the upstream block for non-proxy links and replay. Both blocks run on replay, which is finding 11.

---

## 4. Corrections to the analysis

| # | Analysis says | Shown | Verdict |
|---|---|---|---|
| C1 | Add ATTITUDE and LOCAL_POSITION_NED | ATTITUDE is already forwarded. `GLOBAL_POSITION_INT` carries EKF `alt`/`vz`; LOCAL_POSITION_NED is not needed | Corrects |
| C2 | Rates come from the boat's parameters | The fork forces 1 Hz on connect and on every heartbeat restore; the log shows exactly 1 Hz | Contradicts |
| C3 | Yaw at 5 Hz | 1 Hz in the log | Contradicts |
| C4 | Exact match for coinciding epochs | Arrival order; burst position jitters ±45 ms (1σ) short term and ±100 ms over minutes | Corrects |
| C5 | Reuse the interpolation for heave | Only with time-based assignment; plus the 0–360° wrap | Corrects |
| C6 | One flag gives per-epoch timestamps | It enables the frames; Android drops them | Corrects |
| C7 | Pulse logs have no time data | MAVLink in the `.plog` is time-tagged; pings are not | Corrects in part |
| C8 | 0.5 m/s × 100 ms = 5 cm | A 30–50 cm sawtooth at 1.5 s peaks at 0.6–1.05 m/s → 6–10 cm per 100 ms | Corrects |
| C9 | A dedicated estimator in the fork | On the autopilot (Lua), or use the EKF `vz` | Corrects |
| C10 | 70 ms, 14 epochs/s | 70.6 ms (14.17/s) in this log, but varies with settings; epochs ≠ pings | Confirms rate, corrects "epochs" |
| C11 | Bottom track gates around the previous pick | No gating. A 4-epoch sum selects a region; ±4 % refine; written one epoch late | Corrects |
| C12 | Tracker confidence | None | Corrects |
| C13 | The bottom line as reference | It is the single-ping pick shifted by one ping, quantised to 3 cm on Blue (25 mm × 1.2), ±2.7 cm ping-to-ping in calm water. Usable once the shift is removed | Refines (v3) |
| C14 | Standard sentences | `$PU…` is proprietary by form | Corrects |
| C15 | Motion staleness check | Needs motion times first | Adds |
| C16 | Tilt error 1/cos(tilt) | D·(1/cos(tilt − β) − 1) for tilt > β | Refines |
| C17 | Heave distorts slant-range correction | Self-consistent with a per-ping altitude. Errors come from altitude outliers and the one-ping shift, amplified near nadir | Refines |
| C18 | Pitch shifts pings | Range-proportional shear r·sin(pitch) | Refines |
| C19 | A shared clock makes things comparable | Only via host receive stamps, not taken today | Refines |
| C20 | – | Duplicates (newer forks) must be removed in Pulse | Adds |
| C21 | Mosaic yaw "at 5 Hz" | 1 Hz, linearly interpolated; course-over-ground fallback only when ATT is missing or late | Adds |
| C22 | Firmware range finder vs bottom track | Range finder reads 0.11–0.19 m deeper than bottom track (grows with depth), and false 0.27 m readings in deep water | Adds (v3) |

---

## 5. Solution design

### 5.0 Overview

```
 ArduPilot (6X, Rover)                                    Pulse (KoggerApp)
 ATTITUDE, GLOBAL_POSITION_INT, SYSTEM_TIME,     UDP      ┌───────────────────────────────┐
 HEARTBEAT [+ optional]  ── radio ──► DroneKit fork ────► │ WP2 intake: de-dup, keep       │
        ▲                             (Seascape / CPP)    │  time_boot_ms, alt, vz;        │
        │ SET_MESSAGE_INTERVAL        WP1: rate profiles, │  host receive stamp;           │
        └──────────────────────────── forward targets     │  autopilot↔host clock map      │
                                                          │ WP3 ping time (transducer      │
 Transducer ── IP bridge ───────────────────────────────► │  stamp ↔ host clock map)       │
                                                          │ WP4 motion buffer → per-epoch  │
                                                          │  attitude/heave at ping time   │
                                                          │ WP5 mosaic · WP6 depth source  │
                                                          │ WP7 heave · WP8 log · WP9 NMEA │
                                                          └───────────────────────────────┘
```

**One clock in Pulse:** host monotonic time, stamped on every received datagram and frame. The autopilot and transducer clocks are mapped onto it. All raw stamps are kept.

### 5.1 MAVLink message review

What ArduPilot (Rover) can send that bears on motion (`ap_message.h`, `GCS_MAVLink_Parameters.cpp:228–389`, `GCS_Common.cpp`):

| Message (id) | Group | Content | Time | Use |
|---|---|---|---|---|
| **ATTITUDE (30)** | EXTRA1 | roll, pitch, yaw (rad, float), rates | `time_boot_ms` = send time | **Tilt, lever arm, yaw. Sufficient.** |
| ATTITUDE_QUATERNION (31) | on request | the same as a quaternion | `time_boot_ms` | No gain |
| **GLOBAL_POSITION_INT (33)** | POSITION | lat/lon 1e-7°, **alt / relative_alt mm, vz cm/s** (positive down) | `time_boot_ms` | **Position and an EKF heave candidate; already forwarded** |
| LOCAL_POSITION_NED (32) | POSITION | the same EKF state as floats | `time_boot_ms` | Only if 33's 1 cm/s steps limit |
| RAW_IMU / SCALED_IMU2/3 / HIGHRES_IMU | RAW_SENSORS / request | body-frame IMU | yes | **Not live:** decimated, vibration aliases, needs rotating |
| AHRS2 | EXTRA1 | secondary attitude/altitude | – | Cross-check only |
| VIBRATION, EKF_STATUS_REPORT | request / EXTRA3 | quality, variances | – | Optional 1 Hz quality gate |
| SYSTEM_TIME (2) | EXTRA3 | UNIX + boot | both | Clock mapping (forwarded) |
| TIMESYNC (111) | request/response | ns | – | Optional round-trip measurement |
| NAMED_VALUE_FLOAT (251) | script | name/value | `time_boot_ms` | **The carrier for a Lua heave estimator, if needed** |

**Conclusion:**

- No new messages are needed for the first implementation. The existing per-epoch pitch and roll are usable once they are assigned by time, unwrapped, and arrive at ≥10 Hz.
- ATTITUDE is stamped at send time, at most one loop late: 20 ms at Rover's `SCHED_LOOP_RATE` = 50.
- **Log note:** `vz` arrives in 1 cm/s steps (−2…+2 cm/s in this calm session), and `alt` at 1 Hz. Whether the EKF is good enough for heave can only be decided on a wavy session at ≥10 Hz (section 7).

### 5.2 WP1: rate control from the app

The user picks a profile in the upstream app; the fork applies it.

| Profile | ATTITUDE | GLOBAL_POSITION_INT | SYSTEM_TIME | Others | Method |
|---|---|---|---|---|---|
| **Long range (legacy)** | 1 Hz | 1 Hz | 1 Hz | 1 Hz | `REQUEST_DATA_STREAM` (today) |
| **Standard** (default) | 10 Hz | 10 Hz | 1 Hz | 1–2 Hz | groups at 1–2 Hz, then per-message `SET_MESSAGE_INTERVAL` |
| **High performance** | max (≈ loop rate, 50 Hz default) | max | 1 Hz | 2–5 Hz | as above |
| **Boat-defined** | – | – | – | – | no request; the boat's `SRn_*` apply. Pair with "Ignore Streamrate" |
| **Custom** | user | user | user | user | per message |

- **Order:** send the group requests first, then the per-message intervals. Re-apply both on `CONNECTED`, `HEARTBEAT_FIRST` and `HEARTBEAT_RESTORED`, because a group request wipes the intervals.
- ArduPilot caps intervals at about the loop period and buckets similar rates together.
- **Bandwidth:** 80 B per ATTITUDE + `GLOBAL_POSITION_INT` pair, so 0.8 kB/s at 10 Hz and 4 kB/s at 50 Hz.
- **Fork changes:**
  1. `Rates` honours its values.
  2. A `RatePlan` API, `ExperimentalApi.setTelemetryRateProfile(...)`.
  3. Measured rate per message, reported to the app.
  4. "Boat-defined" sends nothing.

### 5.3 WP2 + WP3: the clock link

- **ATTITUDE already has a time** (`time_boot_ms`). Pulse must keep it, and the same field in `GLOBAL_POSITION_INT`.
- **Autopilot ↔ host:**
  - For each MAVLink message, take `d = t_rx_host − time_boot_ms`.
  - The lower envelope of `d` over 10–30 s, with a slow linear fit for drift, gives the mapping.
  - Bursts only add delay, so they sit above the envelope and drop out.
  - **Log check:** bursts arrive with ±45 ms (1σ) jitter against a steady ping clock, so an envelope over ≥10 samples is needed. At 1 Hz that means ≥10 s; at 10 Hz, 1 s.
- **Transducer ↔ host:** the same envelope fit on `t_rx_host(first chart fragment) − t_transducer` (WP3, once the frame is known).
  - **Fallback without a transducer stamp:** the receive time of the first fragment minus the modelled acquisition and transfer time, smoothed with the known ping period. The log gives 70.6 ms against `ch1Period` 70.
- **Constant offsets** per installation type are calibrated by cross-correlating the bottom line with motion (section 7). **Remove the bottom track's one-ping shift (Q13) first**, or the calibration absorbs a 70 ms bug.
- **Lost pings must not shift time.** 40 % of pings in this log have a lost fragment and about 8 % lost their first fragment, so they merged with the next ping (3 400–3 800-byte pings). With per-ping stamps a lost ping costs nothing; with counting it does. That is one more reason for WP3.

### 5.4 WP2: removing duplicates (required)

- **Messages with a time field:** key (sysid, compid, msgid, time field), seen within about 2 s. This catches the loopback/broadcast pair and two apps on two devices.
- **Messages without one** (HEARTBEAT): key (sysid, compid, msgid, payload CRC) within 200 ms. The two copies are byte-identical, and **the sequence number is always 0**, so it cannot be used.
- **Where:** `DeviceManager::frameInput`, before parsing. Apply it live **and on replay**.
- **Replay double-emit (finding 11):** frames not on the proxy link are parsed by both blocks. That emits position twice, the second with boot-ms used as UNIX seconds, and opens an epoch each second that shares the previous ping's position. Fix by emitting once, with the mapped time. This is separate from the de-duplication, and needed even for this January log.
- Normalise the peer address in `Link::updateMavlinkPeer`.
- **Optional fork modes:** Auto (broadcast + loopback, the default) / Same device / Network / Unicast. Pulse de-duplicates in all of them.

### 5.5 WP4: the motion buffer and per-epoch motion

1. A ring buffer of (t_host, yaw, pitch, roll, alt, vz, source), de-duplicated, about 60 s.
2. Per epoch, at `pingTimeHost`:
   - interpolate yaw (shortest arc), pitch and roll (linear, **no wrap**), alt and vz;
   - write them into the existing `_attitude` (interpolated), plus heave and motion age;
   - a ping newer than the newest sample waits for it, or is extrapolated and flagged provisional.
3. No arrival-order writes when the time mapping exists. Today's path remains as the fallback.
4. Fix `interpAttParam`: wrap yaw only.
5. Positions are interpolated at ping time and do not open epochs, so epochs equal pings.

### 5.6 WP5: mosaic centre artifacts (re-ranked with the log)

**Mechanism** (`MosaicProcessor::updateData`):

- Each epoch gives a line from the sonar position perpendicular to `tryRetValidYaw()`, at z = −bottom-track distance.
- Quads between consecutive lines are filled. Slant range = the 3D distance from the boat at z = 0 to the pixel.
- The nadir band is interpolated from the edge values at `outerFactor × depth`.
- Drawing waits for min(bottom track, chart, max(attitude, track yaw), sonar position) (`DataHorizon`).
- An epoch is drawn once and never redrawn when its yaw, position or altitude changes later.

**Geometry near the track:**

- **Altitude.** Ground range is x = √(r² − h²). At h = 8 m:
  - an altitude 0.1 m too **low** paints water column out to x = 1.3 m; 0.5 m low, to 2.8 m; 1.0 m low, to 3.9 m;
  - an altitude 0.1 / 0.5 / 1.0 m too **high** leaves a centre gap out to 1.3 / 2.9 / 4.1 m.
- **Yaw.** Two consecutive lines with spacing *s* and yaw difference Δψ cross at *s*/tan Δψ from the track. In the log, *s* = 4.7 cm per ping (0.66 m/s). The course-over-ground yaw differs from the heading by a median **4.4°** (p90 8.4°), so a fallback switch crosses at 0.6 m: right at the centre.

**The causes, ranked with the evidence:**

| Rank | Cause | Evidence | Fix |
|---|---|---|---|
| 1 | **Altitude outliers** (bottom-track false picks), each painting a 3–4 m centre streak or gap | In the port, with the black-stripe fill as in the app: 0.7 % of pings jump > 0.5 m from the 1 s median, about one every 10 s. All are "too deep", i.e. centre gaps. Without the fill (or where the fill is used up): 10 % | Per-ping altitude with an outlier gate (median / confidence); skip or hold instead of drawing |
| 2 | **Replay duplicate position** (finding 11): every second two consecutive pings share a position, so *s* = 0 and lines meet at the track | Code; applies to every replayed `.plog` with MAVLink, including this one | Single emit on replay (WP2) |
| 3 | **Live duplicates** (forks from Aug 2026 on), same effect live | Not in this log (fork predates them) | De-duplication (WP2) |
| 4 | **Yaw fallback** (course over ground) when ATT is missing or arrives after GPI | Not triggered in this log (ATT and GPI arrive back to back), but the 4.4° crab shows the size if it happens | Horizon waits for real attitude; redraw on change (WP4/WP5) |
| 5 | **1 Hz yaw** linearly interpolated | Yaw step per second: median 0.6°, p90 7.4° (turns) → crossings at 0.4–5 m in turns | ≥10 Hz (WP1), time-based (WP4) |
| 6 | **The bottom track's one-ping shift** | Negligible on a flat bottom; matters on slopes and with heave | Fix the index (WP6) |
| 7 | Lost near-range fragments filled from the previous ping | 6.6 % of bytes lost on the January link | Mostly gone with the new IP link |

**Investigation plan:**

- A `MOSAIC:` instrument per drawn epoch: yaw and its source, final yaw, position source, spacing, altitude and its jump, crossing radius.
- A/B renders of a Blue `.plog` with each fix alone.
- A debug overlay of the measurement lines.
- Start with this log: the replay double-emit and the altitude outliers can both be tested on it.

**Fixes:** de-duplication; single emit on replay; time-based motion; the horizon waiting for real attitude; redraw when yaw, position or altitude change after drawing (0.5°, 5 cm, 5 cm), reusing the `onBottomTrack3DAdded` invalidation; recompute the sonar position on yaw change; a gated per-ping altitude for the mosaic.

### 5.7 WP6: the depth source: no fixed crossover, tuned to two goals

**What the log adds:**

- On Blue, the rangefinder is **fooled in deep water.** It reports a fixed **0.256–0.278 m** on 3.3 % of pings while the bottom is at 3–9 m, and is >1 m short on 4 %. "Rangefinder says shallow" is therefore **not** proof of shallow water.
- Bottom track (with the app's black-stripe fill) is steadier: ±2.7 cm ping to ping, 0.7 % outliers.
- The two **disagree systematically:** the rangefinder reads 0.11 m deeper at 3 m and 0.19 m deeper at 9 m (about 5 cm + 1.6 % of depth). Bottom track picks the leading edge. The gap could also come from `t1` scaling or the sound-speed setting. Which one is right needs a lead-line check. Until then, **a switch between sources makes a 10–20 cm step.**
- This log has no shore and no shallow section (bottom track 2.4–15.6 m), so the shore and the < 0.5 m behaviour come from the 4 Oct desk and shore runs (backlog F4/F5).

**Design: a per-ping selector with a state, not a depth threshold.**

| State | Enter when | Shown and NMEA depth | Leave when |
|---|---|---|---|
| **Water, bottom track** | default | bottom track (gated, confidence ≥ threshold) | – |
| **Shallow** | bottom track at or near its floor (≤ floor + 0.1 m), **and** rangefinder below the floor and steady (N pings within ±5 cm), **and** the rangefinder reading is **not** the ~0.27 m signature unless bottom track agrees | rangefinder, bias-corrected to bottom track | bottom track leaves its floor by > hysteresis for M pings |
| **Disagree / hold** | the two differ by more than an adaptive band (e.g. 0.3 m + 5 %) and neither is clearly invalid | last good value, flagged; NMEA empty after the stale time | agreement for N pings |
| **No bottom / shore** | bottom track's pick beyond ~0.75 of the acquired range (F4) **and** rangefinder at its ringdown (0.12–0.14 m in air) for ≥ T s | dash (or 0.0, as Olav decided); NMEA empty; the dynamic resolution scheme frozen | either source valid again for N pings |

- The thresholds (floor margin, bands, N, M, T) are **tuning values in the profile** (`distProcPulseRed` / `distProcPulseBlue`, or a sibling `depthSelect…` array). They start from the measured floor and are tuned on the sweep logs. There is no fixed 2 m.
- **Lower the bottom-track floor where it is safe:** `minDistance` 0.25 m is the main term of the 0.32–0.34 m floor. Lowering it without a ringdown mask makes bottom track lock onto the ringdown (F5). So:
  - (a) learn a per-transducer ringdown profile (median trace near the transducer while the bottom is deep) and subtract or mask it;
  - (b) then lower `minDistance` towards the end of the ringdown (about 0.15 m for Red/Black at 5 mm).
  - Blue at 25 mm is too coarse for < 0.5 m anyway; it relies on the shallow state.
- **Bottom-track fixes:** the one-epoch write offset (write to the refined epoch); the effective window (window − 1); a confidence output (the summed peak); a calibrated `threshold` so "no bottom" exists; "not computed yet" separated from NaN "no bottom".
- **For compensation:** heave and tilt are applied to whichever raw value the selector chose. The proprietary NMEA sentence carries the source. Hysteresis bands must exceed the heave, or the decision must use the **heave-corrected** depth when motion is active. Otherwise the state flaps at every crest.
- **Store the rangefinder per epoch** (B3), always.

### 5.8 WP8: logging timestamps without breaking the `.plog`

- A sidecar `<name>.plog.idx` of (byte offset, host monotonic ns, host UTC ns) per frame. At this log's density (~54 000 frames in 288 s, ~190/s) that is about 3.8 kB/s.
- No format change. Replay without it works as today.
- Not in-stream marker frames: unknown routes can create devices, and a fake `SYSTEM_TIME` would break the clock map.

### 5.9 WP9: NMEA

Keep `$PUDBT` / `$PUMTW`; add `$SDDPT` / `$SDMTW` behind a setting; add a versioned proprietary sentence with a registered code.

Proprietary sentence fields:

- ping time
- raw selected depth
- source
- corrected depth
- heave, roll and pitch applied
- motion source and age
- confidence

### 5.10 WP7: heave estimation and correction (after section 7)

- **Inputs:** EKF `vz`/`alt` (forwarded); RTK altitude; a Lua `NAMED_VALUE_FLOAT` if the EKF is not good enough.
- **Filtering:** causal for the readout and NMEA; a delayed zero-phase pass for re-correcting the last 1–2 s of echogram columns.
- **Sign and depth:** heave positive up; depth = *r* − *h*.
- **Lever arm:** a transducer vector in the boat frame.

### 5.11 Order and dependencies

| Step | Work | For the section 7 session? | Depends on |
|---|---|---|---|
| 1 | `ID_TIMESTAMP` bench test | **yes** | – |
| 2 | Sidecar `.plog.idx` (WP8) | **yes** | – |
| 3 | De-duplication + single emit on replay (WP2) | helpful (and fixes mosaic cause 2 today) | – |
| 4 | Fork rate profiles (WP1) + app preference | **yes**, or set intervals by hand | – |
| 5 | Keep `time_boot_ms`/alt/vz; autopilot↔host map (WP2) | offline equivalent is enough | 2 |
| 6 | Ping time handler + map (WP3) | offline equivalent is enough | 1, 2 |
| 7 | Bottom-track fixes: write offset, confidence, threshold (WP6) | **yes** (the reference) | – |
| 8 | Motion buffer, time-based motion, wrap fix (WP4) | no | 3, 5, 6 |
| 9 | Mosaic instrument + A/B (WP5) | no (can start now on this log) | 3 |
| 10 | Depth selector (WP6), tuned on sweep logs | no | 7, rangefinder per epoch |
| 11 | Heave correction + NMEA (WP7, WP9) | no | section 7 result, 8, 10 |

---

## 6. Validation against the Titan log (v3)

`SS_pulse_log_2026.01.14_Titan.plog`: Pulse Blue, 14 Jan 2026, 288 s, near 52.025 N, 8.011 E. Parsed with the bench (`plog.py`). All 54 355 frames passed the Fletcher check, with no unparsed bytes.

### 6.1 Session

- **Side scan v1:** 2 000 bytes per ping = 1 000 samples per side × 25 mm = 25 m per side.
- **3 811 pings counted.** The rate measured against the autopilot clock is **14.17/s (70.6 ms)**.
- Speed 0.66 m/s median (max 1.0); 4.7 cm per ping.
- Calm water: roll σ 0.5° (−4.4…+3.4°), pitch σ 0.3°, `vz` −2…+2 cm/s, EKF `alt` σ 0.18 m over 5 min.
- **This session cannot validate heave magnitude.** It validates plumbing, timing and bottom track.

### 6.2 MAVLink path

| Assumption | Result |
|---|---|
| Forward list = HB, ATT, GPI, SYS | ✔ only these, sysid 1, compid 1 |
| 1 Hz from the fork | ✔ Δ`time_boot_ms` = 999–1001 ms for all three |
| Duplicates | None. The loopback copy was added on 15 Aug 2026; expect them in newer logs |
| Sequence numbers | **All 0** (re-encoded), so they are useless for loss or duplicate detection (new) |
| Order and timing within a burst | HB → ATT → GPI → SYS back to back; ATT and GPI have the same `time_boot_ms` (282 of 289). The raw attitude and position share one epoch, so the yaw fallback is not used (new) |
| Arrival order vs pings | Pings per 1 s burst interval: 14 (162×), 15 (88×), 13 (30×), tails 10–16. Burst arrival against a steady ping clock: **σ = 45 ms short term (p5…p95 −76…+75 ms)** and ±100 ms wander per minute (lost pings or latency drift; not separable without ping stamps) |
| `SYSTEM_TIME` | Present, with valid UNIX time (GPS). The autopilot↔UNIX mapping works offline |
| GPI `hdg` field vs ATT yaw | Identical (median difference 0.00°); both are the EKF heading |
| Course over ground vs heading (moving) | Median 4.4°, p90 8.4° (crab / current) |

### 6.3 Link loss and the black-stripe fill

- 6.6 % of chart bytes were lost; **40 % of pings** have at least one lost fragment; about 300 pings lost their first fragment (and merged with the next one in the parser).
- This is the January link, before the IP telemetry.
- The app fills lost fragments from the previous ping before bottom track runs (Blue forward steps = 1). With that fill, bottom-track outliers > 0.5 m drop from **10 %** (zero fill) to **0.7 %**. **The black-stripe fill is part of the bottom-track contract**, and the offline bench must reproduce it.

### 6.4 Bottom track (line-by-line port, app's fill)

| Metric | Shipped (window 5, gap 4 %) | Single ping (window 1) | Firmware rangefinder |
|---|---|---|---|
| Range | 2.35–15.6 m | – | 0.26–… m |
| Ping-to-ping σ (deviation from 1 s median, < 1 m) | **2.7 cm** | 3.9 cm | 2.1 cm |
| Outliers > 1 m from the 1 s median | 27 (0.7 %) | 75 | 145 (3.8 %) |
| False ~0.27 m readings | 0 | 0 | **125 (3.3 %)** |
| Beyond 0.75 of the range (false far bottom) | 0 | 7 | 2 |

- **Shipped value at epoch *i* + 1 = single-ping value at epoch *i*:** mean |difference| 0.6 mm over 3 713 pings, against 11 mm at lag 0. This confirms the one-epoch write offset and shows that the sum only selects the region.
- **Rangefinder vs bottom track:** they agree within 0.3 m on 94 % of pings. The rangefinder reads deeper by 0.11 m (2–4 m), 0.12 m (4–6 m), 0.17 m (6–8 m) and 0.19 m (8–10 m).
- **Quantisation:** Blue's bottom track moves in steps of t1 × resolution = 1.2 × 25 mm = 3 cm. Red/Black at 2–10 mm resolution are finer.
- **For section 7:** a 5–10 cm heave residual is measurable against bottom track (σ ≈ 3 cm), as long as the one-ping shift is removed.

### 6.5 Assumptions that changed in v3

1. "The 5-epoch sum smears heave" → **it does not, within ±4 % of depth.** The real issues are the one-epoch write delay, the clipping beyond ±4 %, and the 4-epoch effective window.
2. "Mosaic artifacts from yaw switching" → **not in this log.** The leading causes here are altitude outliers and, on replay, the duplicate position each second.
3. "Rangefinder below ~2 m" → it **cannot be trusted alone even in deep water** on Blue (the 0.27 m signature). The selector must use bottom-track agreement and states (5.7).
4. "Duplicates always" → **only with forks from Aug 2026**; still a required fix.
5. "Assignment error ≈ one ping" → confirmed: σ 45 ms, ±100 ms slow wander.

### 6.6 What this log cannot answer

Heave magnitude and filter performance (calm water); shore and < 0.5 m behaviour (no such section); EKF heave quality at ≥10 Hz; transducer timestamp format (flag off).

---

## 7. Preparation for the log-analysis session (section 10 of the analysis)

1. **`ID_TIMESTAMP` bench test:** `"datasetTimestamp": 1` on a branch; `.plog` files on desktop and tablet. Establish the version, units, wrap, jitter, and the frame order relative to `ID_CHART`.
2. **Rates:** until WP1 exists, set ATTITUDE and `GLOBAL_POSITION_INT` to 10–25 Hz with `SET_MESSAGE_INTERVAL` after connecting and after every heartbeat restore. Alternatively, set "Ignore Streamrate" on the boat and raise `SRn_EXTRA1` / `SRn_POSITION`. Check in the `.plog` that it took effect (this log shows how: Δ`time_boot_ms`).
3. **Pixhawk:** `LOG_BITMASK` with IMU (full rate), ATT, GPS and `XKF*`; `LOG_DISARMED = 1`. Check `VIBE` and clipping; note `EK3_SRC1_*` and RTK; retrieve the `.bin` from the SD card.
4. **Pulse:** expert mode; dynamic resolution off; fixed range and period; bottom track on; record a `.plog` (plus the sidecar if built). `datasetSDDBT` stays 1. Keep `pulse.log`. **Use a Red or Black for the heave test** (finer resolution than Blue's 3 cm steps); Blue for the mosaic.
5. **Protocol:** a sharp lift-and-drop sync mark at the start and end; **real waves** (this log was calm); a flat-water control; a short shore and shallow sweep for WP6.
6. **Offline:** the bench (`plog.py`, `bt.py` with the black-stripe fill). De-duplicate MAVLink. Remove the one-ping shift. Align by GPS time, then the sync marks, then cross-correlation. Compute heave from: `.bin` IMU, `XKF1.VD`, `GLOBAL_POSITION_INT` alt/vz, RTK, M10, each zero-phase and causal. Report the residual, lag, sign and noise floor. Run the mosaic instrument on this Titan log now.

---

## 8. Challenges to five points in the analysis (unchanged)

- **"5–10 cm" for the IMU:** an MRU figure. The limits are attitude error × horizontal acceleration, vibration, aliasing of decimated IMU data, and filter phase. Set the criterion from the `.bin`.
- **Sign and frame:** NED (`vz` positive down, `alt` positive up). Heave positive up at the transducer, *h*_T = *h*_IMU + vertical part of (R − I)·*L*; depth = *r* − *h*. Check the sign with a lift test.
- **High-pass phase** (2nd-order Butterworth): residual 0.48 / 0.36 / 0.24 / 0.14 / 0.07 × amplitude at f/f_c = 3 / 4 / 6 / 10 / 20. Zero-phase offline and for delayed echogram re-correction; causal for NMEA.
- **Interpolating at 10 Hz:** 5.5 mm at T = 1.5 s, A = 0.25 m. Timing dominates: 7 cm per 70 ms. The bottom track's one-ping shift is exactly such a 70 ms error.
- **Roll on side scan:** lever arm, the merged altitude biased short, coverage and nadir shifts, banding. Pitch and yaw give a range-proportional shear.

---

## 9. Still to verify

- `ID_TIMESTAMP` version, units, wrap and frame order.
- Arriving rates on current Seascape builds, and whether Seascape overrides the fork's 1 Hz request.
- The ArduPilot version on the 6X (option names, HIGHRES_IMU).
- Bottom track's live NaN at the end of each run (`BT:` counts); the one-epoch offset in the live (batched) path, which matches the port's single pass.
- The replay double position: replay this Titan log with a breakpoint in `Dataset::addPosition`.
- Which of rangefinder and bottom track is right (the 0.11–0.19 m gap): lead line.
- The mosaic causes ranked in 5.6 (instrument + A/B).
- Beam angles of Red, Black and Blue.
