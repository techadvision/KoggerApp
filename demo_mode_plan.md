# Demo Mode (PLOG Replay) — Analysis & Implementation Plan

Status: ANALYSIS + STAGED PLAN — no code written yet.
Target: exhibition demo for the Pulse Echo Sounder app.
v1 written 2026-08-17 after the side scan TVG job.
v2 revised 2026-08-17 — corrected frame period, added `isInDemoMode` gating
design, added exit-demo / app-reset scope, split the work into stages.
**Stage 1 is the only thing being built first: start and run a demo from a file.**

## Goal

Play a recorded .plog file back into the app **as if a live transducer were
connected**: the echogram flows in real time, palettes / views / expert
settings (TVG, water body filter) all work live, the boat track and mosaic
build up on the map as the "boat" moves. No device interaction (no frequency
change, no settings to hardware) — display flow only. Optional endless loop:
when the file is played through, restart. Bonus: no startup freeze (today
`openLogFile` blocks until the whole file is parsed).

## Key architectural finding (why this is EASY)

The app already contains 90 % of the mechanism. `DeviceManager::openFile()`
(src/device/device_manager.cpp:579) does this today:

```
read file in 1 MB chunks
  → Parsers::FrameParser.setContext(chunk) / process()
  → for every complete frame: frameInput(someUuid, nullptr, frameParser)   // :664
```

`frameInput(QUuid, Link*, FrameParser)` (device_manager.cpp:189) is the **same
entry point** that live link data arrives through (LinkManager → frameReady →
frameInput). Charts, attitude, NMEA (DBT depth), MAVLink (position/yaw) —
everything in the log flows through the identical parsing/dispatch code
whether it comes from a UDP link or from this file loop. Device objects
(DevQProperty) are auto-created from the frames themselves; with
`link == nullptr` outgoing configuration writes go nowhere and that already
works (it is how file view works today).

**Demo mode = the openFile loop with a clock.** Instead of parsing the whole
file as fast as possible, emit frames paced so that chart epochs arrive at
the recorded rate. Everything downstream (Dataset, bottom track, black
stripes, 2D waterfall, TVG/WBF, mosaic, boat track) behaves exactly as live,
because from `frameInput` onward the code cannot tell the difference.

This also solves the freeze: data is streamed, so there is never a
whole-file parse blocking the UI. (The same worker could later back an
incremental/streamed normal file open.)

### Demo mode is a THIRD state, not "file view"

This is the single most important design constraint and it was implicit in v1.
The app today has two states, distinguished in QML by
`pulseRuntimeSettings.wasKlfFileOpened`:

| | live | file view | **demo (new)** |
|---|---|---|---|
| `wasKlfFileOpened` | false | true | **false** |
| `isInDemoMode` | false | false | **true** |
| Dataset state | `kConnection` | `kFile` | **`kConnection`** |
| data arrives over time | yes | no (bulk) | **yes** |
| device is writable | yes | no | no |

Demo must **not** set `wasKlfFileOpened`, because that flag is what disables
live-style behaviour all over Plot2D.qml — the live-view / "old data"
indicator (Plot2D.qml:348, :369, :382, :487, :972, :1741, :1764), the UI
controls row (:1779) and the timeline follow logic. Demo wants all of that
ON. Conversely demo must **not** be treated as live either, because the live
path runs device configuration against a device that does not exist. Hence a
separate flag.

## Corrected fact: epoch period is 50 ms for 2D, 70 ms for side scan

v1 stated "frames arrive every 70 ms". That is correct for side scan
recordings only. For the 2D transducers the period is **50 ms**. This is
already the source of truth in the app — `PulseRuntimeSettings.qml`:

- `pulseRed` (2D, `is2DTransducer: true`): `"ch1Period": 50`  (line 370)
- `pulseBlue` (side scan): `"ch1Period": 70`  (line 408)

So the fallback default must be device-dependent, not a constant:

```qml
// fallback only — auto-measure wins when the log has timestamps
property int demoFallbackPeriodMs: pulseRuntimeSettings.is2DTransducer ? 50 : 70
```

Two further notes on period:

1. **`ch1Period` is also the flow-speed control.** On the device side,
   shortening the period speeds the echogram up (subject to the transmission
   link keeping up); the app already exploits this — `DepthAndTemperature.qml`
   drives `dynamicPeriod` between `dynamicPeriodMax: 50` and
   `dynamicPeriodMin: 154` (PulseRuntimeSettings.qml:162-166) as depth
   changes. A demo-side period getter/setter is therefore the natural speed
   control and is strictly better than an abstract `speedFactor`, because it
   maps onto a real device concept the team already reasons about.
2. **Out of scope for Stage 1.** Stage 1 uses auto-measure with the
   device-dependent fallback and no user-facing speed control at all. The
   getter/setter lands in Stage 3.

Because the pacing is auto-measured from the log's own MAVLink/NMEA
timestamps at demo start, the 50-vs-70 question only decides what happens for
logs with no usable timestamps. It is still worth having right.

## Proposed design

### 1. DeviceManager: paced replay worker (the core, ~150 lines)

New slots `startDemo(QString path)` / `stopDemo()` plus a QTimer-driven state
machine on the DeviceManager thread:

- State: open QFile, FrameParser, current chunk + offset, epoch counter.
- Each timer tick: `process()` frames (calling `frameInput` for each complete
  one) **until one chart epoch boundary passes**, then return and wait for
  the next tick. Epoch boundary = a completed ID_CHART (0x03) reassembly —
  the v0/v1 chart is complete when the next ping's `seqOffset == 0` frame
  arrives (same logic IDBinChart uses; the replay worker can simply watch for
  CONTENT/0x03 frames whose payload starts with seqOffset 0).
- Tick interval = measured epoch period (see below).
- On EOF: emit `demoLoopedOrFinished()`; Core decides (loop → reset + restart
  from byte 0; or stop).

Pacing source, pragmatic order:

1. **Auto-measure at demo start (recommended):** quick pre-scan of the file
   (frame scan only, no dispatch — well under a second in C++ even for 90 MB)
   counting chart epochs; divide by the time span from MAVLink/NMEA
   timestamps in the log → true average ping period. Falls back to (2) if no
   timestamps found.
2. Device-dependent fallback: **50 ms for 2D, 70 ms for side scan** (see
   above). The channel count in the log tells us which: 1 channel → 2D,
   2 channels → side scan, mirroring how `numberOfDatasetChannels` already
   drives `pulseBetaName` in DeviceItem.qml:2028-2035.

Guard: clamp the measured period to a sane band (say 20–500 ms) so a log with
a corrupt or wildly sparse timestamp stream cannot produce a 5-second-per-ping
crawl or a flood.

### 2. Core: demo lifecycle glue (~80 lines)

`Q_INVOKABLE Core::startDemo(path)`:

- Same reset steps `openLogFile` already does (core.cpp:605-631: close links,
  remove link-manager connections, `resetDataset`, `dataHorizon_->clear()`,
  `releasePlotCaches()`, `clearProcessing`, clear 3D scene) — **extract these
  into one private helper** and call it from both, rather than copy-pasting.
- **Dataset state — RESOLVED (was open question #1).** Use
  `Dataset::DatasetState::kConnection`. Evidence: `openLogFile` sets `kFile`
  (core.cpp:658) for browsing; the live path sets `kConnection` when a
  non-proxy link opens (core.cpp:2319). Demo wants the live behaviour, so
  `startDemo` must set `kConnection` explicitly — it will not get it for
  free, because no link is opened.
- Invoke `deviceManager startDemo(...)` instead of `openFile(...)`.
- On `demoLoopedOrFinished`: if loop enabled → run the reset helper again and
  restart the worker (Stage 2). Full reset per loop is deliberate: it caps
  memory (dataset/mosaic would otherwise grow unbounded over an exhibition
  day) and gives a clean "new pass" every few minutes.
- `stopDemo()`: stop worker, then the reset described in §4 below.
- Apply `resolveEchogramCompensation()` (PulseRuntimeSettings.qml:148) at
  demo start, same as the file-open timer in PulseInfoRecording.qml does, so
  TVG toggles are honored.

### 3. `isInDemoMode` — the runtime flag and exactly what it gates

Add to `PulseRuntimeSettings.qml`, next to the other GENERAL SETUP STATES:

```qml
property bool   isInDemoMode:           false   // A .plog file is being replayed as if live
property string demoFilePath:           ""      // File chosen for replay
property int    demoMeasuredPeriodMs:   0       // 0 = not measured yet, else the pacing in use
```

The flag exists to **calm the app down**: everything that exists to talk to a
device, or to react to a device, must stand still while a ghost device
"streams". Concretely:

**a) Device configuration must not run.**
`DeviceItem.qml:1092 configurePulseDevice()` already has exactly the right
precedent at :1094 — it early-returns on `wasKlfFileOpened`. Extend both that
guard and the repeat timer:

```qml
// DeviceItem.qml:1094
if (pulseRuntimeSettings.wasKlfFileOpened || pulseRuntimeSettings.isInDemoMode) {
    console.log("DEV_PARAM: demo/file replay — no device setup")
    return
}
// DeviceItem.qml:1177, inside completeDeviceConfigurationTimer.onTriggered
if (pulseRuntimeSettings.wasKlfFileOpened || pulseRuntimeSettings.isInDemoMode)
    return
```

Also gate the three reset/reconfigure hooks in the same file that would
otherwise fire on replayed data:
`onUserManualSetNameChanged` (:1915 → calls `configurePulseDevice`),
`onSwapDeviceNowChanged` (:1924) and `onHasDeviceLostConnectionChanged`
(:1951 → calls `resetAllSetupStates`).

**b) The CONFIGURATION STATES block must read "done".**
Guards alone stop the machinery, but the UI reads these flags for its
"device ready" affordances, and `ifSetupCompleted()` (DeviceItem.qml:1154)
should return true immediately so `completeDeviceConfigurationTimer` stops
repeating (its `repeat:` is bound to `!devConfigured`, :1174). Add a function
to PulseRuntimeSettings.qml (it already hosts `resolveEchogramCompensation`,
so a function there is idiomatic):

```qml
// Put the CONFIGURATION STATES block into "nothing to do" so the config
// machinery goes quiet while a file is replayed. Mirror-image of
// DeviceItem.resetAllSetupStates().
function setConfigStatesForDemo(inDemo) {
    var v = inDemo   // true while demoing, false restores the fresh-start defaults
    onDeviceVersionChanged = false
    devConfigured          = v
    echogramPausedForConfig= false
    echogramEnabledByConfig= false
    onDistSetupChanged     = v;  distMax_ok = v; distDeadZone_ok = v; distConfidence_ok = v
    onChartSetupChanged    = v;  chartSamples_ok = v; chartResolution_ok = v; chartOffset_ok = v
    onDatasetChanged       = v;  ch1Period_ok = v; datasetTimestamp_ok = v; datasetChart_ok = v
                                 datasetTemp_ok = v; datasetEuler_ok = v; datasetDist_ok = v
                                 datasetSDDBT_ok = v
    onTransChanged         = v;  transFreq_ok = v; transPulse_ok = v; transBoost_ok = v
    onDspSetupChanged      = true;  dspHorSmooth_ok = true   // never used, stays true
    onSoundChanged         = true;  soundSpeed_ok   = true   // never configured, stays true
    unableToConfigure      = false
}
```

Note the asymmetry that is intentional: `onDspSetupChanged`/`onSoundChanged`
and their leaves are declared `true` at rest (PulseRuntimeSettings.qml:87-91)
and must stay true in both directions.

**c) Automatic resolution / period changes must not run.**
`DepthAndTemperature.qml` reacts to incoming depth and rewrites
`dynamicResolution` and `dynamicPeriod` (:134-136, inside
`updateDynamicResolutionWithStep` at :102) and `dynamicPeriod`/`dynamicSamples`
again at :188-224 (inside `calculateDynamicResolution` at :149). On replayed
data the resolution is already baked into the recording — recomputing it is at
best a no-op write to a null link and at worst UI oscillation as the "boat"
crosses depth steps. Gate the single entry point both paths run through:

```qml
// DepthAndTemperature.qml, top of calculateDynamicResolution()  (:149)
if (pulseRuntimeSettings.isInDemoMode)
    return
```

and skip `initialAutoLevelCalculatorTimer` (:320) / the
`forceUpdateResolution = true` writes at :290 and :324 while in demo. Whether
`autoLevelCalculate()`'s **display-level** half (:257-273, `autoDepthMaxLevel`)
should also be suppressed is a judgement call — it changes only what the
echogram shows, not the device, and it looks good in a demo. Recommendation:
keep the auto display level, kill only the resolution/period/samples writes.

**d) No false "lost connection".**
`lostConnectionTimer` (DeviceItem.qml:2044, 2500 ms) restarts on every
`dataset.onDataUpdate` (:2022). During playback data flows, so it never
fires — good. But at **demo stop and at every loop boundary** there is a gap
> 2.5 s, which sets `hasDeviceLostConnection = true` (:2052) → the overlay via
`main.qml:491 showLostConnection()` and a `resetAllSetupStates()` (:1954).
`showLostConnection` today only skips for `wasKlfFileOpened` (main.qml:493),
so add `|| isInDemoMode` there and stop/ignore the timer while demoing.

**e) Recording must be blocked.**
`PulseInfoRecording.qml:138` disables the record MouseArea for
`wasKlfFileOpened`; add `&& !isInDemoMode` — recording a replay would produce
a confusing second-generation log.

**f) Not gated on purpose.** Palette, view switching, level sliders, TVG /
water-body-filter expert settings, mosaic, 3D — all act on the live-flowing
data exactly as on a real connection. That is the entire point of injecting
at `frameInput` level; leaving them untouched is the feature, not an
oversight.

### 4. Exiting demo mode — and the missing "reset to fresh" (new in v2)

**Today the app has no proper reset.** The closest thing is
`DeviceItem.qml:1874 onReconnectAfterLogViewChanged`, which clears ~15 runtime
flags, calls `resetAllSetupStates()` and then `core.closeLogFile()`. Its twin
`onSwapDeviceNowChanged` (:1924) repeats almost the same list minus
`wasKlfFileOpened` and `core.closeLogFile()`. Two near-duplicate partial
resets that have already drifted apart is exactly the kind of thing that
makes "stop the demo and go back to normal" flaky.

Scope for demo exit, in order of preference:

1. **Consolidate first.** Extract one `resetAppToFreshState()` — best placed
   in `PulseRuntimeSettings.qml` for the property half (it owns the declared
   defaults, so restoring them is a local operation) plus a thin QML caller
   that also invokes the C++ half. Have `onReconnectAfterLogViewChanged`,
   `onSwapDeviceNowChanged` and the new `stopDemo` path all call it, with a
   parameter for the one genuine difference (whether to reopen links).
   This is a small refactor that pays for itself immediately and removes the
   drift.
2. **Property half** (restore declared defaults): GENERAL SETUP STATES
   (:34-50), the whole CONFIGURATION STATES block (via
   `setConfigStatesForDemo(false)`), TRAFFIC STATES (:96-100), the
   `*_Copy` parameter mirrors (:334-351, back to -1), dynamic resolution
   state (`dynamicResolutionInit`, `dynamicResolution`, `dynamicPeriod`,
   `dynamicSamples`, `pulseBlueResSetOnce`, `forceUpdateResolution`),
   bottom-track state (:236-239), the KLF flags (:43-44, :178) and the new
   demo flags. `userManualSetName`/`devName`/`pulseBetaName` back to `"..."`.
3. **C++ half**: `Core::stopDemo()` → stop the worker, then the same helper
   `openLogFile`/`closeLogFile` use — `resetDataset()`, `clearProcessing`,
   `scene3dViewPtr_->clear()` + navigation arrow reset, `dataHorizon_->clear()`,
   `releasePlotCaches()`, `resetRenderBuffers()`, and on the DeviceManager
   side `delAllDev()` + `vru_.cleanVru()` (device_manager.cpp:697-703 already
   does exactly this in `closeFile`). Then either leave the app idle
   ("as if just started, no device") or reopen links if the user wants live.
   `openedfilePath_` must be cleared; `filePath_` too if it was set.
4. **Acceptance for "fresh":** after exit, starting a demo again — or plugging
   in a real transducer — must behave identically to a cold app start. That is
   the test, and it is worth writing down because it is the part most likely
   to be half-done.

Note this reset work is genuinely useful beyond demo mode: it is the same
gap that makes device swap and post-file-view reconnect fragile today.

### 5. QML entry point (~100 lines)

- A "Demo" row in the Recording tab (PulseInfoRecording.qml, next to
  "Showing file" at :147-198): pick file → Start demo / Stop demo.
  Expert-gated at first (`pulseSettings.isExpert`, as the existing rows at
  :291 and :306 are).
- A visible **DEMO** badge overlay so exhibition visitors and staff cannot
  confuse it with live sonar. (Stage 2 — it must not block Stage 1.)
- Loop checkbox (default ON) — Stage 2. Speed/period stepper — Stage 3.
- Optional kiosk autostart: if a configured demo file exists (settings key or
  fixed filename in the app folder), start demo on app launch. One small
  block in main.qml `Component.onCompleted`. Stage 3.
- Android: reuse `fixFilePathString` for `content://` URLs, as
  `openLogFile` already does (core.cpp:600).

## Staged plan

### Stage 1 — run and start a demo from a file  ← BUILD THIS FIRST

Everything needed to press a button and watch a recorded file flow like live
sonar. Nothing else.

1. `PulseRuntimeSettings.qml`: add `isInDemoMode`, `demoFilePath`,
   `demoMeasuredPeriodMs`, and `setConfigStatesForDemo(bool)`.
2. `DeviceManager`: `startDemo(path)` / `stopDemo()` + paced worker with
   auto-measured period and the 50/70 ms device-dependent fallback.
3. `Core`: extract the shared reset helper out of `openLogFile`; add
   `startDemo` / `stopDemo`; set `DatasetState::kConnection`; apply
   `resolveEchogramCompensation()`.
4. Gates (a)–(e) from §3 above.
5. Minimal QML: file picker + Start/Stop in the Recording tab, expert-gated.
6. If the worker becomes its own class rather than methods on
   `DeviceManager`, remember BOTH build systems: `CMakeLists.txt` **and**
   `src/device/device.pri` (pulled in by `KoggerApp.pro`). Keeping it as
   methods on `DeviceManager` avoids that entirely — recommended for Stage 1.

**Stage 1 acceptance criteria**

- Pick a 2D .plog → Start demo → echogram scrolls left-to-right at
  approximately the recorded rate (sanity check: a 60-second stretch of the
  recording takes ~60 seconds of wall clock).
- Depth and temperature readouts update; bottom track draws; the boat track
  and mosaic build up on the map.
- Palette / view / level changes and the TVG + water-body-filter expert
  toggles all act on the flowing data, live.
- The console shows **no** `DEV_PARAM` configuration churn and no
  `DYNAMIC:` resolution/period writes for the whole run.
- No "lost connection" overlay appears during playback.
- No UI freeze at start (contrast with `openLogFile` today).
- Stop demo leaves the app usable — full "as-if-new" reset is Stage 2, but
  Stage 1 must not leave it wedged.

### Stage 2 — loop, reset, badge

- `demoLoopedOrFinished` → reset + restart from byte 0; loop checkbox.
- The `resetAppToFreshState()` consolidation of §4, and proper demo exit.
- DEMO badge overlay.
- Verify the loop boundary produces no lost-connection overlay and no
  unbounded memory growth over an hour of looping.

### Stage 3 — speed control and kiosk

- Period getter/setter as the speed control (see §"Corrected fact" note 1),
  exposed in expert settings.
- Kiosk autostart from a configured file.
- Grey out (rather than merely inert) the device-interaction controls under
  `isInDemoMode`.

## What will NOT work in demo (expected, fine)

- Any device interaction: frequency change, range/resolution setup, boost,
  firmware — the "device" is a ghost created from recorded frames. Controls
  either sit inert (writes go nowhere, as in file view today) or get greyed
  out via `isInDemoMode` in Stage 3.
- Recording during demo — blocked, see §3(e).

## Open questions still to resolve

1. ~~Dataset state for auto-scroll~~ — **RESOLVED: `kConnection`**, see §2.
2. ~~Auto-range / dynamic resolution behavior on replayed data~~ —
   **RESOLVED by design: gated off via `isInDemoMode`**, see §3(c). The one
   remaining judgement call is whether to keep the auto **display level**
   (recommendation: keep it).
3. `SEPARATE_READING` ifdef: the paced worker should work with both build
   variants — or replace that mechanism entirely, since the demo worker is
   strictly more general than the chunked-with-`processEvents` loop
   (device_manager.cpp:606-675). Decide in Stage 1; the cheap answer is to
   write the worker outside the ifdef and leave `openFile` alone.
4. Device tab UI during demo (shows ghost device info — acceptable? badge?).
5. Whether the demo file should ship with the app for the exhibition or be
   picked from disk each time.

## Effort estimate

Stage 1: DeviceManager worker ~150 lines, Core glue ~80, QML ~60, gates ~30.
One focused day of implementation + one day of testing with the existing 2D
and side scan logs. Stage 2 adds the reset consolidation, which is the part
most likely to expand — budget a second day for it alone. All changes are
additive and the demo path is dormant unless started; no upstream files
beyond `device_manager.{h,cpp}`, `core.{h,cpp}` and QML — and therefore no
build-file changes at all, provided the worker stays inside `DeviceManager`
(otherwise: `CMakeLists.txt` **and** `src/device/device.pri`).

## Rejected alternatives (for the record)

- **Epoch-level re-feed** (parse whole file first, then push epochs into
  Dataset on a timer): keeps today's startup freeze, needs new "append epoch
  as live" plumbing and cursor sync, bypasses the protocol path so NMEA/
  MAVLink/temp/depth would need separate handling. More code, less realism.
- **Video/screen capture**: not interactive — palettes/views/TVG frozen.
  Worthless next to the real thing given how cheap option A is.
- **A `speedFactor` float instead of a period setter**: an invented concept
  where the codebase already has a real one (`ch1Period`). Deferred to Stage 3
  and reframed as a period getter/setter.

## Relevant knowledge from the TVG job (context for a fresh chat)

- .plog = raw KP1 (0xBB 0x55) / KP2 (0xCC 0x55) protocol byte stream;
  fletcher checksum; ID_CHART 0x03 v1 = two byte-interleaved side scan
  channels; resolution mm→m ×0.001; position/yaw via MAVLink frames
  (device_manager.cpp), depth via NMEA $SDDBT. Working Python reference
  parser exists — useful for offline pre-checks of demo log files.
- 89 MB SS log ≈ 40k epochs ≈ 47 min at 70 ms — good demo length feel;
  loop reset every ~47 min is invisible in an exhibition setting.
  (A 2D log of the same size runs shorter at 50 ms — ~33 min.)
- Recommended demo content: a log with clear features + the TVG/WBF settings
  from the partner test as the "wow" toggle moment (AGC vs sidescan tvg).
