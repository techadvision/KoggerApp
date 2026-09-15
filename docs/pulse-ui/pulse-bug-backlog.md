# The Pulse v2 bug backlog

14 September 2026, at the close of the feature work. Every screen-chooser feature is
built; what follows is what stands between that and a build Olav would put in front of a
customer. Companion to `pulse-ui-strategy.md`, which holds the design reasoning.

**Order, from Olav: get the regular tablet right first. Small screens are the last thing,
after this list.**

---

## How this list is grouped, and why the grouping matters

The items are not in the order they were noticed. They are grouped by **what is actually
broken**, because six of them are three faults wearing different clothes, and fixing the
fault closes the group. Each group is sized to one chat session.

One shape runs through several of them and is worth stating once, because it predicts
where the next one will be found:

> **A flag or a call whose only writer lives in the classic UI reads false in v2, and the
> branch nobody tested is the one that runs.**

That is exactly how the depth readout came to say 0.0 m on every side scan
(`isBottomTrackInitiated` is written from `DisplaySettings` and the expert panel, neither
of which `PulseAppV2` instantiates), and how the depth engine came to not run at all
before that. **Group B below is a deliberate sweep for the rest of that class**, rather
than a list of separate bugs.

---

## Group A — the rail says nothing about what is open — **DONE, 15 Sept 2026 (`d75e4f12`)**

One fault, five symptoms, and it was the cheapest win on the list.

- **Only the Colours button lit up when its panel was open.** Cone, Max depth,
  Intensity, Water body filter and Settings did not. `PulseRail.qml` set
  `pending: rail.openGroup === "colours"` on exactly one button; every other
  `PulseRailButton` was missing the line. Users could not tell which control they were
  looking at.

**Fixed with the second shape, which is the one that stops this recurring.** The line is
gone rather than written ten more times. The rail's `ColumnLayout` declares
`openGroup: rail.openGroup` **once**; `PulseRailButton` defaults its own `openGroup` from
its parent and derives `readonly property bool pending: buttonId !== "" && buttonId ===
openGroup`. A new button lights up correctly with **no line at all** — it only needs a
`buttonId`, which it needs anyway to do anything.

Three details worth keeping in mind when the next button is added:

- The **parent read** is what makes it free, and it is the one implicit thing here: QML ids
  do not cross files, so `PulseRailButton.qml` cannot see `rail`. The `undefined` test is
  what makes it safe — a parent with no such property answers `""` rather than throwing on
  every evaluation — and `openGroup` is still settable at the call site for a button ever
  nested inside something other than the column.
- The **empty test is not belt and braces.** `collapse` and `backToClassic` carry buttonIds
  and open no group, and `""` is also what `openGroup` reads when the panel is closed;
  without it every button would light at once on a closed panel.
- **`cone`/`screen` lights up for free** because its `buttonId` is already dynamic.

---

## Group B — the file/demo path sets nothing up — **DONE, 15 Sept 2026 (`e8634060` … `b5849994`)**

The largest group, and the one Olav has been describing for several sessions as "the
device change problems". His own reframing on 14 September is the key to it:

> *"Starting the app AS BLUE, thereafter going to source and opening a blue log file: now
> problems with applying the wrong settings seems less of a problem. Seems most problems
> are related to having the UI self-adapt to the chosen log file."*

That moves the suspect from the **commit** path to the **log-open** path. Every item here
is something that is applied when a device is committed and is NOT applied when a file is
opened or a demo starts.

- **Opening a file does not leave the connection screen.** The file loads, but the
  welcome screen stays up until a sounder alternative is picked. The screen's `asking`
  binding does not know a file arrived.
- **Starting a demo does not apply the preferred max depth.**
- **Intensity, water body filter and max depth do not reach the echogram at demo start** —
  the sliders show the stored value and the picture does not have it. Note that
  `applyIntensity` / `applyWaterBodyFilter` / `applyMaxRange` are called once, from the
  colour block's `Component.onCompleted`; a demo starting later gets none of them.
- **Choosing a new file while a demo is running does nothing.** The old demo is never
  stopped, so the new one never starts. Stop first, then start with the new file.
- **2D and side scan must keep separate persistent max depths.** `displayMaxRangeKey`
  already names three keys correctly; check what the demo path writes.

**Fix shape:** one function that says "a source has been chosen — apply everything the
picture needs", called from the commit path AND the file-open path AND the demo-start
path. Today the commit path has it and the other two do not.

### What was actually there, which is worse than the line above says

**The commit path did not have it either.** `onUserManualSetNameChanged` ran
`applyScreenId` and `applyConeId` — two of the six applies. The only place that ran
anything like the full set was the colour block's `Component.onCompleted`, **once**, at
startup. So there were two partial lists and no complete one, and every source chosen after
startup got whichever partial list its path happened to reach.

### The four commits

- **`e8634060` — `mainview.applyForSource(reason)` is the one list.** Theme → intensity →
  water body filter → screen mode → cone → **range last**, and the ordering is
  load-bearing: `applyScreenId` → `applyEchogramMode` writes `isSideScan2DView`, and that
  is what decides which of the three stored range keys `displayMaxRange` reads. It reaches
  the other files through `signal sourceChosen(string reason)` on `pulseRuntimeSettings`,
  the same route the rail's source button already takes. Callers: the commit handler, the
  startup block, `enterDemoMode`, and the file-open completion.

  **Plus a second trigger that no call at the moment of choosing can replace.** A log does
  not say whether it is 2D or side scan until its channel list arrives, several frames after
  the dialog closed — so `applyForSource` also runs on `presentedModel`. That is the half
  that makes the picture adapt to the log rather than to the last device, and it is silent
  in exactly the case Olav reported as already working (a blue log on a committed blue does
  not move `presentedModel`).

  **The file-open call is in `onSendIsFileOpening`, not beside a dialog**, because that
  handler is the one point every route to an opened file passes through — the connection
  screen's *View a file*, the drag and drop, and the menu bar's open. A call at each dialog
  would have been three places to forget.

- **`689e33f7` — opening a file takes the connection screen down.** Two faults, both the
  predicted shape. The **flags**: `awaitingUserChoice` and `connectionScreenRequested` were
  cleared by committing a card and by `enterDemoMode`, and by nothing on the file path.
  Both clears now live in `answerSourceQuestion(how)` on `pulseRuntimeSettings` and all
  three paths call it. The **binding**: `chooserAsking`'s third term guarded on
  `isPresentingLog`, which requires `activeModel !== ""` and therefore a channel list — so
  on a cold start, which is *when the welcome screen is up*, an opening file had no model
  and the guard read false for the whole open. The new `logIsOnScreen` is the plainer
  question that term was always asking, without `isPresentingLog`'s two profile-side
  conditions.

- **`65ed7074` — choosing a new source stops the old one first.** `enterDemoMode` returned
  early on `isInDemoMode`; `Core::startDemo` refuses while `isDemoMode_` is set, so nothing
  happened at all. The same file still returns early; a different one calls `core.stopDemo()`
  and carries on. **Not `exitDemoMode()`** — its other half is backlog item 9 (clear the
  committed model, reopen the links, ask for re-detection), which a swap would undo two
  lines later while the app hunted for a transducer. **`isInDemoMode` stays true across the
  swap**, or `logIsOnScreen` drops for a frame and the connection screen flashes back over
  the file being chosen. `stopDemoPlayback(why)` is that same half on its own, for opening a
  file over a running demo, and it is called *after* `wasKlfFileOpened` is raised for the
  same reason.

- **`b5849994` — `applyEchogramMode` reads the key instead of naming one.** The side branch
  assigned `pulseSettings.maxDepthValuePulseBlueFixed` by hand and **the down branch assigned
  nothing at all**, so entering down scan re-ranged the plot against the number the outgoing
  mode had left in `quickChangeMaxRangeValue`. Both branches now read
  `pulseRuntimeSettings.displayMaxRange`, after the `isSideScan2DView` write and not before.

**Not compiled and not on a device.** Every one of these is QML and the shell has no Qt.

**Session size:** one full session. This is the group with the most user-visible payoff.

---

## Group C — the demo loop, and the crash that came out of it — **DONE, 15 Sept 2026 (`2b2074f8`)**

- **The demo restarts at end of file. Keep that** — Olav wants it. **But not while
  paused:** restarting under a pause produces "huge artifacts", and it is important for
  demonstrations that a paused picture stays put.
- **It also crashed the app.** `SIGABRT`, `ASSERT "!(max < min)"` in `qBound<int>` inside
  `Plot2DAim::draw`, paused, in a split screen, with `DEMO: running at 70 ms/epoch` on the
  line above. A demo restart clears the dataset; `data_width` goes to 0; `qBound(0, x, -1)`
  aborts the process.

**The defensive half was done** — `e3d75733` makes the loupe answer "no epoch" instead of
aborting. **The behavioural half is now done too**, and it removes the cause rather than the
symptom: the restart calls `prepareDemoPipeline()`, which does a full
`resetRealtimeSessionState()`, so a frozen view was left pointing at epochs that had just
been destroyed.

### How it is held

**Held, not cancelled, and held WITHOUT stopping.** `isDemoMode_` stays true, so the pill
still reads *Demo* and the app still believes it is replaying — the replay has simply run
out of file, nothing new arrives, and the paused picture stays exactly where the user left
it. Resuming pays the debt.

- The loop body moved into `Core::startNextDemoPass()`, so a pass started by a resume is
  byte-for-byte the pass the end-of-file path would have started. Two callers, one body.
- **`stopDemo()` clears `demoRestartPending_`.** Stopping from the paused gutter is an
  ordinary case, and a flag left set would fire a pass into a stopped demo on the next
  resume.
- **The `epochsPlayed == 0` branch is untouched.** A pass that played nothing means the file
  could not be read, and that stops whether paused or not — holding a restart that is going
  to fail again helps nobody.
- **C++ had never been told about the pause.** `echogramPause` is a QML property, so
  `setDemoPaused(bool)` is pushed in from `main.qml`'s `setEchogramPaused` — the single
  writer of that property, and the route the rail's Pause button and the paused gutter both
  already take.

**Not compiled.** This is the branch's THIRD uncompiled C++ change, with the per-pane grid
(`2efbccb3`) and the loupe guard (`e3d75733`). That build is now overdue on its own account.

**One thing deliberately left**, because it is a second idea: with `demoLoopEnabled_` false,
end of file while paused still stops the demo, and `exitDemoMode()` then clears the committed
model, reopens the links and asks for re-detection — all under a frozen picture. Loop is on
by default and Olav wants it on, so it does not bite today.

**Session size:** small, and it can ride along with Group B since it is the same demo
path.

---

## Group D — the chooser offers what a log file cannot do — **D-1 and D-3 done, D-2 needs one log line**

A file is not a transducer, and three controls have not been told.

- ~~**The cone chooser cannot work during playback.**~~ **DONE, `2cf5c267`.** Choosing a cone
  is `setParam("transFreq")` to hardware, so with a recording on screen it either reaches
  nothing or — at an exhibition, with a transducer in an aquarium — reaches the device and
  changes nothing the user can see. Olav's answer was taken: *"OK to have the bar expanded,
  but not clickable choices."* The group stays visible, the rows drop to 0.45 opacity and
  take no taps, and a note sits above them.

  **Disabled rather than absent**, which is the opposite of what the rail and the settings
  list do and is deliberate: absent is right when a device does not HAVE an ability, and
  here the ability exists and is momentarily unusable — a row that vanishes while a log
  plays and returns when it stops reads as a bug rather than as a rule.

  **The current row keeps its mark**, because the chooser is the committed device's question
  and the highlight is still true; the note is what stops it being read as the recording's
  frequency. `choosable` reads `logIsOnScreen`, not `isPresentingLog`, for the reason the
  connection screen uses it too.

- **Colours: 2D and side scan must each keep their own set.** Still open, and now several
  sessions old. **The v2 path was read end to end this session and looks correct**:
  `displayThemeId` reads `colorMapIndex2D` for red and `colorMapIndexSideScan` for blue,
  `displayThemeModel` hands out the matching list, `onThemeChosen` writes only the key
  belonging to the model on screen, and favourites are offered for 2D only
  (`offerFavourites: displayIs2DTransducer`).

  **So it is one of two things, and one log line says which** — open the Colours panel on a
  blue and read:

  ```
  THEME: display theme -> <id> | 2D or side scan | stored index <n>
  ```

  *side scan* with a red theme showing → the stored `colorMapIndexSideScan` is corrupt from
  the legacy selector, and this is a **migration**. *2D* for a blue → the display model is
  answering wrong, the colours are innocent, and the same fault would break the pill's corner
  and the ruler — a much bigger fish. **Do not write code for this before the line is read.**
- **The view chooser is gone and the cone chooser stays** — done, recorded here only
  because it closes Olav's note on the pair. The rail's button count is unchanged.

**Session size:** half a session, and it wants Group B done first — several of these only
show up on the file path.

---

## Group E — the split screen meets the overlays

The screen chooser is finished; the things that draw ON a pane have not caught up with a
pane being half the size.

- **The zoom/loupe box is too large in a split.** It is sized against the whole pane, and
  a split pane is half of one.
- **The Stop demo / Close file pill sits above the tick ruler on a side scan** and needs
  to drop below it.
- **Everything else that takes width or height from a pane** — the rail, the panel, the
  setup card, the paused gutter, the depth readout — has not been walked in a split.
  Olav, when the split was still parked: *"likely there may be multiple things to adjust."*

**This is a pass, not a number.** It is also the natural rehearsal for phone sizing: a
split pane on a tablet is roughly a phone-sized picture, so whatever is fixed here is
already most of the small-screen work.

**Session size:** one session, and it should be the LAST of the tablet work — it is the
one that benefits from everything else being stable.

---

## Found on the device build of 15 Sept, after A and B

- **The demo pill survives opening a file — and it turned out to be the file's pill.**
  Checked with Olav: it reads *"Viewing recording … Close"*, not *"Demo … Stop"*. So
  `isInDemoMode` did fall, `stopDemoPlayback("a file was opened")` did run, and the pill is
  wearing the right identity and doing the right thing. What was seen was the pill changing
  identity in place rather than a stale one persisting. **Nothing to fix unless the replay
  itself is still feeding underneath** — the observable for that is the echogram continuing
  to scroll under a static file, and the logcat line is `DEMO: stopping the replay - a file
  was opened`.

- **A red demo now flows vertically, and the live feed has started doing the same.**
  Olav, 15 Sept: *"opposite from before when echogram came horizontal for dual side scan —
  only now the live feed also opens that way like it inherited the blue render prefs."* This
  is the older *"demo for red after blue shows as a single-channel side scan"* quirk moving
  rather than closing, and it now reaches the live picture. **Olav is deferring it** — *"the
  inability to properly enforce the user's preferred settings also is not working all over
  the place. We will come back to that."* Note for whoever picks it up: `applyForSource` now
  runs on `presentedModel` as well as on the three source paths, so it now fires on paths
  it did not fire on before.

  **And there is a root cause worth writing down before the item is picked up, because it is
  checkable without a build.** `applyEchogramMode` is the only thing in v2 that writes
  `isSideScan2DView` and `isHorizontalGrid` — the two properties that decide which way the
  echogram flows. It is reachable from exactly one place, `applyScreenId`, which begins:

  ```
  if (pulseSettings.uiVariant !== "v2" || !pulseRuntimeSettings.offersScreenChoice)
      return
  ```

  and `offersScreenChoice` is `!displayIs2DTransducer`. **So for a 2D picture the orientation
  is never written at all.** A red demo, a red log and a red live feed all inherit whichever
  way the last side scan left those two properties, and nothing puts them back. That is
  precisely "like it inherited the blue render prefs", and it is not caused by Group B —
  Group B only made it visible, by applying everything else correctly around it.

  The fix shape, when the item comes up: a 2D picture has an orientation too, and something
  has to state it. Either `applyForSource` writes the 2D orientation directly when
  `displayIs2DTransducer`, or `applyEchogramMode` stops being reachable only through a
  control that a 2D transducer is not offered. The second is the shape that stops it
  recurring — it is the same "a call whose only caller lives behind a control the branch
  never reaches" as the rest of this list.

---

## Asked for, not a bug — the speed gauge

**From the professional dealer, via Olav, 15 Sept 2026.** Not a defect and not scheduled
here; recorded so it is not lost.

- **The data already exists.** The autopilot sends `GLOBAL_POSITION_INT`, whose `vx`/`vy`
  are cm/s; `DeviceManager` reduces them to a horizontal velocity and
  `device_manager_wrapper.h:29` publishes it as
  `Q_PROPERTY(float vruVelocityH READ vruVelocityH NOTIFY vruChanged)`. `deviceManagerWrapper`
  is a root context property, so a QML overlay can read it directly — nothing C++ is needed.
- **Where it goes:** below the depth readout, and below the temperature when that is shown.
  So it is a third line on the depth/temperature overlay rather than a new surface, and it
  inherits that overlay's corner-follows-the-flow rule for free.
- **The unit is the user's:** m/s, km/h, or the imperial equivalents, **one decimal**.
- **The setting lives under the `Screen & echogram` category** in the settings list.

Two things to settle when it is built rather than now: whether the row is absent or shows a
dash when no MAVLink is present (the settings list's own rule is absent, and
`pulseRuntimeSettings.mavlinkDetected` already answers the question), and whether it is
suppressed while paused the way the depth readout is.

## The mosaic TVG, and the expert switches that could end a profile binding — **DONE, 15 Sept 2026**

| Commit | What |
|---|---|
| `50ff1f42` | the mosaic gets the side scan TVG, because it was built and switched off |
| `00b5b0a3` | an expert switch can no longer end the profile's say over the gain law |

**Olav, 15 Sept:** *"We must enable the TVG for side scan mosaic. The result looks terrible
when far away areas are darker."*

### Nothing was missing. The default was false.

`EchogramSideScanTvg`, the per-epoch `ssTvgCompensated` buffer, `MosaicProcessor`'s
`ensureMosaicSource()` and `mosaicSourceBuf()`, and `qPlot2D::setSsTvgMosaicEnabled` were all
in the tree, with `Plot2D.qml` pushing the value and `main.qml:138` rebuilding the mosaic when
it changed. `sideScanTvgMosaicEnabled` was declared `false` and the switch sat in the expert
tier.

**And the buffer was already being built.** `pulseBlue` carries `sideScanTvgEnabled: true`, so
`resolveEchogramCompensation()` returns imageType 3 and the **waterfall already renders from
`ssTvgCompensated`** — for every epoch it draws. The mosaic was reading `compensated`, the AGC
buffer, beside it. So the two surfaces drew **the same data through two different gain laws**:
AGC normalises local contrast, TVG corrects level over range, and the edges of the swath go
dark under one and not the other. Switching the mosaic over costs almost nothing, because the
buffer it wants is already there.

It became **profile data**, beside `sideScanTvgEnabled` where it belongs: `true` on blue (and
blue-IP, which merges it), `false` on red, which has no mosaic to draw.

### And then the sweep, which is the part that stops it happening again

`echogramTvgEnabled` and `sideScanTvgEnabled` were bindings on `activeProfile` **that the
expert controls assigned to** — v2's settings list through `settingChanged("runtime", …)`,
classic's expert panel through `SettingsCheckBox.targetPropertyName`. An assignment destroys a
binding permanently, so **the first touch of either switch ended the profile's say over the
gain law for the rest of the run**: swap the transducer after that and the echogram renders
with the law of the device that is no longer there.

Classic's rows already carried `writeBackOnUserActionOnly: true` with a comment naming this
exact failure. That narrows the window to a real click without closing it, and a real click is
what the control is for.

All three now take the shape rule 2 asks for: **one binding on the profile, one tri-state
override (0 follow / 1 force on / 2 force off), and nothing assigns the value.** The value is
`readonly`, so a future control reaching for the old spelling gets a loud *"Cannot assign to
read-only property"* on the first click instead of a picture that quietly stops following the
device; all three names join `runtimeKeysQmlOwns` so a bus echo is skipped rather than thrown.

**It was a sweep, not a spot fix.** Those two were the *only* profile-bound properties in
`PulseRuntimeSettings` with an assignment anywhere in the QML, and there are now no writers
left to any of the three.

**To check on the device:** tiles already drawn keep their pixels until re-traced, and at
startup the value is simply already true, so nothing changes and nothing triggers the rebuild.
A log that was open from before may look half-and-half until the mosaic update action is used.
On a **fresh** open it should be right from the first tile — if it is not, that is a real
finding.

---

## The mosaic and the water body filter — **filter DONE `77c23cad`, the nadir band diagnosed and parked**

Found on the 15 Sept build, immediately after the mosaic TVG landed. Olav: *"The mosaic is
now good. But with one exception. It does not distinguish the water body filter, filter
values is global and the filter darkens the entire bottom render."*

### The filter was the mosaic's black point

Both v2 appliers called

```
MosaicViewControlMenuController.onLevelChanged(pulseSettings.filterRealValue,
                                               pulseSettings.intensityRealValue)
```

and that signature is `(lowLevel, highLevel)`. It lands in
`mosaic::PlotColorTable::update()`, where `lowLevel` is a **black point**:
`indexOffset = lowLevel * 2.5`, and every amplitude below it clamps to colour index 0. So the
water body filter — a **water column** idea — was wired to a global contrast floor over the
**bottom**. Raise it and the whole seabed render crushes.

A side scan mosaic has no water column to filter. It is a map of the bottom by construction,
so there is nothing for the filter to remove and everything for it to damage.

**Zero**, not `PlotColorTable`'s own default of 10, on Olav's answer: zero is what the mosaic
already got with the filter down, which is the render the TVG was judged on. And with the
side scan TVG now correcting level over range, a floor has nothing left to do except throw
away real signal at the edges of the swath — the very darkness the TVG was turned on to fix.
`applyWaterBodyFilter` no longer touches the mosaic at all; the levels follow intensity, which
is legitimate because intensity is a brightness control.

**`PulseAppClassic` has the same wiring in three places and was NOT touched** — classic is the
`uiVariant` fallback and is not disturbed without cause. Worth one commit if classic is ever
used on a side scan in anger.

### The water body left in the map — checked, and our geometry is not at fault

Olav: *"For side scan mosaic the water body is by design removed from the equation… but the
upstream author did not exactly nail it as there is a portion of the water body kept present."*

The sample lookup is honest slant range:

```
QVector3D segFCurrPhPos(x, y, segFDistProc);        // z = the processed depth
sampleIndex(segFCharts, segFCurrPhPos.distanceToPoint(segFBoatPos))
```

`distanceToPoint` is a true 3D distance from the boat to a seabed point, so a ground point at
horizontal offset *x* reads the sample at `sqrt(x² + depth²)`. **There is no slant-range error
to fix.**

**The dark band along the track is the nadir null, and it is physical.** A side scan
transducer has no useful return directly beneath it. Upstream paints that wedge anyway, near
black, which is why it reads as a strip of water body laid into the map. The two honest
treatments are the ones the industry uses:

- **Blank it** — leave the nadir wedge transparent out to roughly the depth, so the map says
  "no data" instead of drawing black ground. Needs a per-epoch width from the bottom track and
  a transparency path through the tile writer that may not exist yet.
- **Interpolate across it** — which is the *same work* as Olav's standing note: *"We should
  work with interpolating the two channels into one view for downscan."* That closes the nadir
  **and** gives the downscan, so it is worth doing once rather than twice.

**Parked deliberately**, and it wants the split-screen/downscan decision made first so it is
not built twice. Not started tonight on Olav's own steer: *"We do not have to fix the part
waterbody instantly if it is complex."*

---

## Asked for, twice — burst playback instead of the file-open freeze

**Olav, 15 Sept 2026, and he has raised it before:** *"My file opening is nothing to be proud
of. The old UI had a 'please wait…' for a good reason. These logs take like forever to open,
and the entire UI becomes unresponsive. Could we utilize the file opening mechanism used by
the demo? It plays 1 record per 50 ms. What if we could simply blast through as fast as
possible using the demo playback mechanism? Then the screen would fill fairly quickly and
let the UI remain responsive."*

### Why it freezes, which is worth knowing before choosing a fix

`CMakeLists.txt:13` declares `option(SEPARATE_READING "Data reception in a separate thread"
OFF)`, and **OFF is what ships**. On that branch `device_manager_wrapper.cpp:32` connects
`sendOpenFile` → `DeviceManager::openFile` with **`Qt::DirectConnection`** — so the entire
parse runs **on the GUI thread**, inside a `while (true)` that reads 1 MB at a time and
parses every frame in it. The `QCoreApplication::processEvents()` inside that loop is
`#ifdef SEPARATE_READING`, so on the shipping build **it is not there**. The event loop does
not run again until the whole file is parsed. That is the freeze exactly, and it is why
`Core::openLogFile`'s 15 ms `singleShot` exists at all — it buys one repaint before the
stall, which is where a "please wait…" used to get drawn.

Note also that `DeviceManager::openFile` already computes a `progress_` percentage in that
loop **and throws it away** on this branch. The number exists; it has nowhere to go.

### Olav's idea is the right one, and the machinery is already built

`demoTick()` is not "one epoch per timer tick" — it is **clock-driven and frame-budgeted**,
and its own comment says why. It delivers whatever the recording says is due, capped by
`kDemoMaxEpochsPerTick = 4` and `kDemoTickBudgetMs = 12`, then **returns to the event loop**.
That is already the shape a responsive fast-forward needs.

**A burst is `demoPeriodMs_ = 0`.** With the period at zero the clock is always behind, so
every tick delivers until the 12 ms budget or the epoch cap is hit, and the UI breathes in
between. Two knobs would want raising: the per-tick cap (4 is a catch-up allowance for a
paced replay, not a throughput number) and the tick interval (`qMax(5, demoPeriodMs_ / 3)`
floors at 5 ms). **The 12 ms budget should NOT be raised** — it is what guarantees a frame.

Three things that make it the demo **transport** rather than demo **mode**, and all three
have to be got right or this trades a freeze for a worse bug:

- **`wasKlfFileOpened` must stay TRUE.** `enterDemoMode` deliberately clears it, because that
  flag is what switches OFF live-style `Plot2D` behaviour and a demo wants live follow, the
  old-data indicator and the rest of it ON. A burst-opened file wants the opposite — scroll
  back, the timeline, no live follow. So a burst sets the **file** flags, never the demo ones.
- **It must not close the links.** `Core::startDemo` calls `closeOpenedLinks()`; opening a
  file deliberately does not, which is why a plain opened file still asks about a device swap.
- **`demoPrescan` can be skipped entirely.** It exists to settle the pacing by reading up to
  `kDemoPrescanMaxBytes` before the first epoch. A burst has no pacing to settle, so skipping
  it also removes the one remaining up-front read.

**What it does and does not buy.** Total CPU is the same or slightly more — the work is the
same parse plus the same per-epoch dataset, bottom-track and mosaic cost. What changes is
that the app stays alive and the picture **fills progressively**, which is what the user is
actually asking for. Do not promise a shorter open; promise a visible one.

### The other route, already half-written in the tree

Turning `SEPARATE_READING` **ON** moves `openFile` onto `DevManThread` — and that branch
already has the `processEvents()`, the `break_` escape hatch and the
`fileStartOpening` / `fileStopsOpening` signals, with a matching `Core::openLogFile` written
for it at `src/core.cpp:683`. It is the **smaller** change by a wide margin and it gives a
cancellable open for free. Against it: it is a build option nobody currently ships, so it is
untested on Android, and it changes the threading of the whole reception path rather than
just the file open.

**Not chosen here.** The two are not exclusive either — the option gives responsiveness, the
burst gives a picture that fills while you wait. Whichever is taken, v2 has **no progress
surface at all** today, and `progress_` is already being computed for one.

---

## The manual-choice matrix, 15 Sept evening — **FIXED, `a47c1114`, awaiting a device build**

Olav ran the same procedure twice on the evening build: **start the app, choose the model
FIRST, then re-enter source and play a log of that model.** This is the cleanest evidence the
device-change problem has produced, because it isolates one variable.

| | blue → blue log | red → red log |
|---|---|---|
| Colour profiles offered | blue's | red's, favourites correct |
| Chosen colour applied | yes | yes |
| Echogram orientation | correct | **VERTICAL — renders as a blue single channel** |
| Screen choice | remembered and applied | (n/a on red) |
| Max depth | remembered and applied | **remembered as 13, applied as about 2** |
| Intensity | remembered and applied | yes |
| Water body filter | remembered and applied | yes |

**Blue is clean on every row. Red fails on exactly two, and they are almost certainly one
fault.**

### Both red rows fall out of the root cause already recorded above

`applyEchogramMode` is the only writer of `isSideScan2DView` and `isHorizontalGrid`. It is
reachable only from `applyScreenId`, which begins:

```
if (pulseSettings.uiVariant !== "v2" || !pulseRuntimeSettings.offersScreenChoice)
    return
```

and `offersScreenChoice` is `!displayIs2DTransducer`. **So for a 2D picture the orientation is
never written at all**, and red inherits whatever the last side scan left: `isSideScan2DView`
false, `isHorizontalGrid` false — which is *side scan*, drawn vertically. That is row 3 exactly,
and "blue single channel" is precisely how it should look.

**And row 4 follows from row 3 rather than being its own bug.** `applyMaxRange` branches on the
pane, not on the preference:

```
if (panes[i].isViewHorizontal())
    panes[i].plotDistanceRange2d(v)
else
    panes[i].plotDistanceRange(v)
```

With the grid stuck on side scan, `isViewHorizontal()` answers false and a red 2D range of 13
goes through `plotDistanceRange()` — the side scan call — instead of `plotDistanceRange2d()`.
The stored value is right, the read is right, and the picture is ranged by the wrong law. That
is the "remembered 13, applied about 2".

**So the prediction is one fix, two rows.** Giving a 2D picture an orientation writer should
close both. If it closes row 3 and not row 4, the range branch is a second fault and wants its
own look.

### What was built, `a47c1114` — and the one correction to the derivation above

**Row 4 does not follow from row 3.** Both follow from the same uncalled function.
`applyEchogramMode` writes the orientation *and* restarts the timer that calls
`setHorizontalNow()`/`setVerticalNow()` — the sole writer of the C++ `isHorizontal_` that
`applyMaxRange` later branches on. Two pieces of state, one function, and red was missing it
entirely. Not a cascade.

**The guard was the second fault shape.** `offersScreenChoice` answers *"may the user pick a
screen"*; `applyScreenId` was reading it as *"does this picture have a layout"*. So the fix is
reachability, not a second orientation writer in `applyForSource`. The guard stays and a branch
is taken — `screenForId()` for a 2D picture returns a blue entry and would pin panes that do not
exist:

```
if (!pulseRuntimeSettings.offersScreenChoice) {
    applyEchogramMode("down")
    waterViewFirst.setGridMode("")
    waterViewSecond.setGridMode("")
    return
}
```

**`applyEchogramMode` could not simply be called — it had the polarity bug inside it.**
`isSideScan2DView = down` is correct for the only caller it ever had and a lie for a red:
`flipImage` is `isSideScanOnLeftHandSide_ && isSideScan2DView_` in **both** `plot2D.cpp` and
`plot2D_grid.cpp`, so a red would render mirrored with an inverted ruler, and
`PulseDepthEngine.pictureIsSideScan` would change its mind. Classic already answered it — the
`showAs2DTransducer` branch of `setUserInterface()` sets the grid horizontal and never touches
`isSideScan2DView`. It is now `down && !displayIs2DTransducer`, and `chartOffset` — a device
write — moved onto that same condition.

**Blue is unchanged by construction**: `displayIs2DTransducer` is false there, so the new
branch is unreachable and the polarity expression collapses to `down`. If blue regresses, the
polarity is backwards.

### To check on the device, in this order

`applyEchogramMode` now logs on every call:

```
MODE: down -> horizontal | side scan as 2D false | 2D device | range 13 from maxDepthValue
```

- **No `MODE:` line on a red** → still unreachable, nothing here worked.
- **`vertical`, or `side scan as 2D true`** → polarity backwards.
- **Line right, picture still vertical** → the write is not reaching the renderer; look at the
  settings bus, not at this function.
- **Row 3 closes, row 4 does not** → *do not start at `applyMaxRange`'s branch.* Start at
  whether the timer fired. `applyForSource` calls `applyMaxRange()` immediately, before the
  10 ms timer lands, so its `isViewHorizontal()` read is the outgoing value and the timer is
  the last writer. `applyMaxRange` asking the **pane** how it is drawn when the answer belongs
  to the **preference** is the borrowed-property shape one layer down — a separate commit,
  because it is a separate idea.

**QML only. Not compiled and not on a device.**

### Olav's idea for the shape of it, recorded as given

> *"We have additional issues when we automatically adapt the UI to the log that is to be used.
> Maybe we should read some log content, let the app abilities do the app setup (but not try to
> configure the transducer as it is a file) and THEN show the content? Just an idea, for
> inspiration only."*

**This is already how the demo path works and is exactly what the file path lacks.**
`DeviceManager::demoPrescan()` reads up to `kDemoPrescanMaxBytes` before the first epoch and
answers "2D or side scan" from the recording itself — which is why `demoIsSideScan` is settled
before `enterDemoMode` emits `sourceChosen`. The file path has no equivalent: it starts
rendering and the channel list arrives later, which is why `applyForSource` had to be given a
second trigger on `presentedModel`.

A file-side prescan would turn that second trigger from a repair into a non-event: decide the
picture, set the app up, *then* show the content. **And it shares its one expensive step with
the burst-playback item** — both want the log read ahead of rendering — so the two should be
designed together rather than each growing its own prescan.

---

## The cold-start demo — **FIXED, `3ef7249a` + `f0b4bcb3`, awaiting a device build**

The matrix one level further: **no manual model choice — start the app, go straight to a
demo.** Red clean. Blue came up with red's palette, max depth, intensity and water body
filter, **no chooser button on the rail at all**, and a pill correctly reading *"Demo · PULSE
blue"*. That contradiction is the diagnosis.

**Two faults, and it is the pair that sticks the app between identities.**

- **`demoIsSideScan` is stale when the demo says a source was chosen.** `enterDemoMode`
  claimed the prescan reports before `core.startDemo()` returns. It does not — `Core::startDemo`
  hands off to a worker on `DevManThread` with `Qt::AutoConnection`, which is **queued**. Stale
  is `false` and false is **red**, so red passed by accident and blue got red's everything.
  Moved into `demoSourceClassified()`, called from `onDemoPeriodChanged` where the answer
  actually lands. *(`f0b4bcb3`)*

- **The settings bus echo was destroying the binding.** `onRuntimeChanged` does
  `pulseRuntimeSettings[k] = m[k]`; `displayIs2DTransducer` was published, not `readonly`, and
  not in `runtimeKeysQmlOwns`. `flushRuntime()` emits only *changed* keys, so the property
  froze at the first answer it ever gave — the committed device on the manual path (right, so
  everything looked fine) and **red** on a cold-start demo (wrong, permanently). This is also
  why Group B's `onPresentedModelChanged` repair never repaired anything: the property it was
  meant to move could no longer move. *(`3ef7249a`)*

**The 15 Sept sweep could not have found the second one.** It searched for visible assignments;
`pulseRuntimeSettings[k] = m[k]` matches no grep for a property name. The comment above that
loop had already named the hazard for `maximumDepth` and the lesson was not generalised.

**Only two keys of the fifteen published were exposed** — `displayIs2DTransducer` and
`is2DTransducer`. Both are now `readonly` and in `runtimeKeysQmlOwns`. New rule, in the
strategy doc: **a binding that is published is a binding that will be assigned.**

**The rail's "missing two controls" was one control.** `buttonId: offersCone ? "cone" :
"screen"`, `visible: offersScreen || offersCone` — neither question claimed it.

### To check on the device

- `DEMO: the replay is classified - …` must appear **after** `DEMO: running at N ms/epoch`,
  and the `SOURCE:` line after it must name the right model.
- **The loop restart.** Set a range by hand mid-demo and let the file loop: it must stay put,
  and the classification line must not appear twice. That guard is the only reason
  `demoSourceApplied` exists.
- **Black stripes on a blue cold-start demo** were wrong before this too and never reported —
  look for gaps or empty columns.

---

## Still owed, from earlier sessions

- The logcat check for `SETTINGS: persistent settings injected into pulseRuntimeSettings
  -> ok` with no `ReferenceError` above it.
- `feature/device-profiles-step4` has never been merged to master.
- `feature/pulse-ui-v2-rail` is now **94 commits unpushed**.
- Three C++ changes in this branch are **uncompiled in this shell**: the per-pane grid
  (`2efbccb3`), the loupe crash guard (`e3d75733`) and the held demo restart (`2b2074f8`).
  The last one adds a `Q_INVOKABLE` to `Core`, so `moc` has to re-run — a clean-ish build
  rather than an incremental one if Qt Creator is stubborn about it.

## Not blocking, with Olav

The boat run with two transducers, the real device swap, the PULSEblue-IP acceptance test.

---

## The order, and why

1. ~~**A**~~ — **done**, `d75e4f12`.
2. ~~**B**~~ — **done**, `e8634060` … `b5849994`. Untested on a device.
3. ~~**C**~~ — **done**, `2b2074f8`. Uncompiled, and it is the third C++ change on the
   branch waiting for a build.
4. **The manual-choice matrix** — fixed, `a47c1114`, awaiting the device build that confirms
   both red rows closed together.
5. **D** — D-1 and D-3 done (`2cf5c267`); D-2 waits on one `THEME:` log line.
6. **E** — last of the tablet work, and it is already half of the phone work.
7. **Phone sizing** — after all of the above, deliberately.
