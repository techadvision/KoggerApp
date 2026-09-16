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

- ~~**Colours: 2D and side scan must each keep their own set.**~~ **CLOSED BY THE LOG, 15 Sept
  2026 — no migration, and no fault. See "D-2, answered" below (`af857891`).** The original
  text is kept as written: **The v2 path was read end to end this session and looks correct**:
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

## Intensity and the water body filter, per picture — **DONE, `7dc2676b`**

**Olav, 15 Sept, after the cold-start fixes landed and the model-to-model swap finally
worked:** *"As far as I can see, the water body filter and the intensity does not differ on
the models. Maybe that was always the case. But it really should not be… it makes sense to
distinguish filter for blue (usually have a LOT less clutter in the water body anyway) and of
the intensity: for red it is usually a focus on reading the colors of first and second echo to
determine hardness, while for blue it is more of a question to distinguish variation of
dullness/brightness in areas of the bottom render."*

**It was always the case.** Four flat keys with no model in them anywhere, and classic has the
same four — nothing regressed. The per-picture idea arrived with the colour theme and the max
range and these two were never brought along.

Built as `displayMaxRange`'s shape, twice: a key named once, a derived read, one writer.
**Two-way on `displayIs2DTransducer`** — the colour theme's split, not the range's three-way
one. The range needs three because a blue's swath width and its depth are different physical
quantities; a brightness is a brightness whichever way a blue is drawn.

**Only the display number splits.** `intensityRealValue` / `filterRealValue` are pure
functions of it and are what reaches the persistent bus and `plot2D_echogram.cpp`, so they
stay single and become the **shared applied value written by the applier** — the role
`colorMapIndexReal` already has. Classic's sliders and `Plot2D`'s pinch path are untouched.
Two new keys per control, not four.

**The apply triggers had to move, and that is the part worth remembering.** They watched
`intensityRealValue` / `filterRealValue`, which the appliers now write — a handler on them
would be an applier triggering itself. They now watch `displayIntensity` / `displayFilter`,
the *input*, which also covers the model changing for free: a red log after a blue one gets
red's own brightness back with nothing having to remember to restore it. Same as the range.

**Migration** is the `ecoViewId` pattern, in `PulseSettings.Component.onCompleted` (that file,
not `main.qml`, because `pulseSettings` is built by its own `QQmlComponent` first). Sentinel is
`-1`, since `0` is legitimate for both controls. **Both models inherit the user's current
value**, on Olav's answer, so nothing moves on the first build.

### To check on the device

- `SETTINGS: splitting intensity per picture - both seeded from N` and the filter equivalent,
  **once**, on the first run of this build and never again.
- Set a different intensity on a red log and on a blue log, then swap back and forth: each
  must come back to its own number, with no restore step and no flicker.
- Classic still behaves exactly as before — it reads the legacy keys, which are untouched.

**Not done, and deliberately its own idea:** `echogramWaterBodyFilterEnabled` (whether the
slider is a water-column filter or a whole-picture low cut) and `echogramWaterBodyMinRealValue`
are flat runtime properties, not profile data. Making the filter's *meaning* per-device is a
bigger change than making its *value* per-device.

---

## The demo loop loses the range — **FIXED, `d8510413`**

**Olav, 15 Sept, letting a blue replay run to the end and loop:** *"The settings in all
sliders are OK. But the settings are not applied to the echogram… max depth is applied as 2
meters only even though selector is 25 meters."* And: *"Only for blue, but my bet is that it
also applies for red."* **His bet is right — this is channel-driven, not model-driven.**

### `setDataChannel` takes the range from the dataset

`Core::onChannelsUpdated()` calls `Plot2D::setDataChannel()` on every pane, and that function
ends with:

```
datasetPtr_->getMaxDistanceRange(&from, &to, ...)
if (isfinite(from) && isfinite(to) && (to - from) > 0)
    cursor_.distance.set(from, to)
```

Whatever the app had applied is discarded. A loop restart does a full `prepareDemoPipeline()`
— `delAllDev()`, the parser context reset, the dataset cleared — so the new pass rebuilds the
channel list and the range is re-derived **from the first few epochs of a file whose bottom
has not been acquired yet**. Two metres, on a picture whose slider still reads 25.

**Only the range**, which is exactly what he observed: `setDataChannel` is the only thing that
re-derives anything, so intensity, the filter and the palette all survived. The very dark
echogram was the two-metre range showing nothing but water body.

### Why the repair is on `channelListUpdated` and not on `demoLooped`

`channelListUpdated` is emitted **after** the `setDataChannel` loop, so its handler is the
first moment at which the damage exists and can be undone.

`demoLooped` exists, is emitted by `Core::startNextDemoPass()`, and **nothing listens to it** —
it looks like the obvious hook and it is the wrong one. It is emitted *before* the queued
`invokeMethod(worker, "startDemo")`, so a handler there would apply the range and then watch
the new pass overwrite it. **The same threading trap as the prescan in `f0b4bcb3`**, one week
and one signal apart.

And the demo loop is only where it bites first. Any channel list rebuild does this — a
reconnect, a file reopened, a second transducer appearing.

### Nothing is lost by re-applying

`displayMaxRange` is the stored preference, and **every** way a user changes the range writes
it: the panel slider through `storeDisplayMaxRange`, and the pinch through
`PulseAppV2.maxDepthValue` into the same writer. So the repair restores the user's own number
rather than overriding it.

That is also why the `demoSourceApplied` guard from `f0b4bcb3` stays exactly as it is: a loop
must not re-run the whole list, only recover what the rebuild destroyed.

### To check on the device

- `RANGE: applying 25 from maxDepthValuePulseBlue | side scan law` after each loop restart.
  The line names the law as well as the number, because the two ways of getting this wrong —
  the wrong number, and the right number under the wrong law — look identical on the water.
- Let a red log loop too. It should never have worked either.
- Pinch the range mid-demo and let it loop: it must come back to the pinched value, not to
  whatever the panel last showed.

---

## D-2, answered — the colours were never broken, and the instrument was — **`af857891`**

Olav produced the `THEME:` line the item had been waiting on, for three runs.

```
app start          THEME: index undefined is not in a list of 6 - falling back to the first entry
                   THEME: display theme -> 26 | side scan | stored index 0

blue log selected  THEME: display theme -> 9  | 2D        | stored index 5
                   THEME: display theme -> 26 | side scan | stored index 4

red log selected   THEME: display theme -> 9  | 2D        | stored index 5
```

### The decision rule, applied

The item said: *side scan* with a red theme showing → migrate `colorMapIndexSideScan`;
*2D* for a blue → the display model is answering wrong, a much bigger fish.

**Neither. The log says both models answer correctly:**

- **blue log → `side scan`.** `displayIs2DTransducer` is false for the blue, which is right.
  Theme **26** is `themeModelBlue[5]`, "High Quality Orange" — an entry in **blue's own list**,
  not a red theme leaking in.
- **red log → `2D`**, theme **9** = `themeModelRed[4]`, "S Dark". Red's own list.
- Each reads its own key, each key holds a legitimate index into its own model.

**So what was the original symptom?** Almost certainly the frozen `displayIs2DTransducer`
binding — `3ef7249a`. With that property stuck at whatever it first reported, `displayThemeId`
picked the same branch forever and the colours could not differ by model however correct the
keys were. **D-2 was a symptom of the settings-bus echo and was closed by fixing that**, which
is also why the v2 path read correct end to end last session while behaving wrong on the
device.

### And the line itself was wrong, which is the part worth keeping

`themeModelRed[5]` is id 10, not 9 — id 9 is index 4. `themeModelBlue[4]` is id 4, not 26 —
id 26 is index 5. **Neither printed index matches its own printed id, and each one is exactly
the index the other picture holds.**

`displayThemeId` and `displayThemeIndex` were two separate bindings on
`displayIs2DTransducer`, and **QML does not order the re-evaluation of two bindings on the
same source.** The model changes, `displayThemeId` re-evaluates, `onDisplayThemeIdChanged`
fires immediately, and it reads an index that has not been re-evaluated yet — so the line
prints the outgoing picture's index beside the incoming picture's id.

The ids were right the whole time: `displayThemeId` reads the two keys directly, so those
reads are captured and live, and the chooser follows it **by id**. Only the report was wrong —
and it very nearly bought a migration the data never justified.

**A diagnostic must not be a binding.** A binding describing another binding may be evaluated
in any order relative to it, so it is free to describe the previous state. The values are now
read inside the handler, imperatively. The line also names the key it read, resolves the entry
so its own id and title are shown, and prints **MISMATCH** when that id and `displayThemeId`
disagree — which is the condition D-2 was actually looking for, now stated by the instrument
rather than reconstructed by hand. `displayThemeIndex` had exactly one reader and is gone.

### One benign thing the log also shows

```
THEME: index undefined is not in a list of 6 - falling back to the first entry
```

once per start. `pulseSettings.colorMapIndexSideScan` reads `undefined` on the binding's first
evaluation, before the stored values are live; `themeIdAt` catches it and the binding settles
to the right entry immediately after — the reported id is `themeModelBlue[5]`, not `[0]`, so
the fallback did not stick. **Noisy, not harmful**, and the fallback logging is doing exactly
the job it was added for. Left alone deliberately: it is the transient, and silencing it would
remove the warning that catches a real out-of-range index.

---

## The TVG appeared to disable black stripes removal — **FIXED, `bd14130f`** (C++, uncompiled)

**Olav, 15 Sept:** *"The TVG, both for side scan and for 2D, disables the use of the black
stripes removal. Clearly evident if I disable the TVG in expert settings."*

**Not a TVG fault.** Every buffer `Epoch::Echogram` derives from `amplitude` is a cache keyed
on **size**, never on contents:

```
imageType 1 (AGC)      if (compensated.isEmpty())
imageType 2 (2D TVG)   if (tvgCompensated.size()   != rawSize || version mismatch)
imageType 3 (SS TVG)   if (ssTvgCompensated.size() != rawSize || version mismatch)
imageType 4 (upstream) if (tgc.isEmpty())
imageType 0 (raw)      reads amplitude directly
```

The version tags track the **global gain constants**, not the samples. `BlackStripesProcessor`
repairs masked samples straight into the epoch's vector, **in place and at an unchanged
length**, so all four guards see nothing and `imageType 0` is the only render that shows the
repair. That is precisely what the expert switch does.

**The backward pass is why it is so obvious:** 5 steps on both profiles, so it repairs epochs
the renderer has *already drawn and already built a gain buffer for*. `Dataset` emits
`redrawEpochs()` for exactly those epochs and `Core::onRedrawEpochs` re-renders them —
faithfully, from the stale buffer. **The invalidation existed and reached the wrong layer.**

`Echogram::invalidateDerived()` clears all four and zeroes the two version tags. Called from
`Epoch::setChart` and `Epoch::setChartBySubChannelId` — so every caller is correct without
knowing the caches exist, including the processor's *"this epoch had no chart at all"* branch —
and from the repair loop itself, which writes through a reference `Epoch` cannot observe.

**And the grow path was an overread, not just a stale draw.** `chartTo()` takes `rawSize` from
`amplitude.size()`, and the `imageType` 1 and 4 guards are `isEmpty()` alone — so a
`compensated` or `tgc` buffer left at the old, shorter length is accepted and then indexed to
the new `rawSize`. The two TVG buffers are safe only because their guards compare size, which
is luck rather than design. `amplitude.resize()` now invalidates too.

### To check on the device

- Black stripes removal must work **with the TVG on**, on both red and blue, exactly as it
  does with it off. That is the whole test.
- The stripes should fill in **behind** the live edge as well as at it — that is the backward
  pass, and it is the half that was fully invisible before.
- **C++, and the branch's fourth uncompiled change** (with `2efbccb3`, `e3d75733`, `2b2074f8`).
  `Echogram` is a plain struct, so no `moc` round — an incremental build is enough.

---

## WHAT IS LEFT — the whole remaining list, grouped and prioritised (15 Sept 2026)

Groups A–E were sized "one per session" and that held. What follows is everything still open,
**grouped by what shares work** rather than by when it was noticed, because six of these items
pair off and doing either one first makes the other cheaper.

### P0 — The build, and the push — **DONE, 16 Sept 2026**

**The build was made and the branch is pushed.** Seven fixes verified on hardware, nothing
falsified — no polarity inversion, no `MISMATCH`, no crash. `origin/feature/pulse-ui-v2-rail`
now exists at 0/0, 182 commits. Check-by-check results and the two findings the checks did not
ask for are in the strategy doc, *The device build — 16 Sept 2026, the eleven checks*.

**What P0 leaves behind, none of it blocking P1:**

- **The channel count classifies before it has finished counting.** `main.qml`'s
  `if (list.length < 2) return` asks *has a list been built*, not *has the list finished
  growing*, so a blue reads `2D` for one update. The demo path is immune because `demoPrescan`
  settles the model first; **the file-open path has no prescan**, so the prediction is that a
  blue *log file* gets red's settings applied before correcting. Fault shape four. Checkable on
  the next build without writing code. The one-frame red palette at the start of a blue demo is
  the same mechanism and the same commit.
- **`bd14130f` is built and plausible, not verified.** *"I am not able to detect black stripes"*
  reads both as working and as no test case. Needs a log known to show stripes, TVG on.
- **Check 1 was run on the demo path, not the file path.** The red *log file* case is still open.
- **Check 11 still owed** — logcat was unavailable again.
- **`master` is 71 commits ahead of `origin/master`** (`feature/device-profiles-step4` sits on
  the same commit, `3b0a9abe`, so pushing master covers both). The residual risk.

The original P0 text follows, kept because it is what the checks were derived from.

**Seven fixes from the 15 Sept evening session are on the branch and none has been seen on a
device.** They interact — the orientation fix, the bus-echo `readonly` sweep and the demo
classification move all touch what the app believes it is looking at — so a device build that
exercises them together is worth more than any new work.

- Compile and run the eleven device checks now scattered through this document. They are
  gathered in the next-session prompt in the strategy doc.
- **Four uncompiled C++ changes**: the per-pane grid (`2efbccb3`), the loupe crash guard
  (`e3d75733`), the held demo restart (`2b2074f8`) and the gain-buffer invalidation
  (`bd14130f`). Only `2b2074f8` adds a `Q_INVOKABLE`, so `moc` must re-run at least once —
  a clean-ish build rather than an incremental one if Qt Creator is stubborn.
- **`feature/pulse-ui-v2-rail` is 180 commits unpushed.** This is the single largest
  unmanaged risk on the project and it is not a code problem. Push it.
- `feature/device-profiles-step4` has never been merged to master.
- The logcat check for `SETTINGS: persistent settings injected into pulseRuntimeSettings -> ok`
  with no `ReferenceError` above it — still owed from several sessions back.

### P1 — Group E, then phone sizing. One continuum, not two jobs

**These are the same work and should be one sustained effort**, which is why E has always been
scheduled last: a split pane on a tablet is roughly a phone-sized picture, so every fix in E is
most of a phone fix.

- ~~**The zoom/loupe box is too large in a split**~~ — **DONE `bf80ab02`**, 16 Sept.
- ~~**The Stop demo / Close file pill sits above the tick ruler on a side scan**~~ — **DONE
  `f7d294cf`**, 16 Sept.
- **Everything else that takes width or height from a pane** — rail, panel, setup card, paused
  gutter, depth readout — has not been walked in a split. Olav: *"likely there may be multiple
  things to adjust."* **Still open**, and the rail half of it now overlaps the phone work
  almost completely: the fit budget below is the same question a split pane asks.
- **Then phone sizing** — **started 16 Sept evening, see the block below.** The order held:
  the two named E items landed first and `bf80ab02`'s fit clamp is what the phone's base-scale
  fix will lean on.

#### Phone findings, 16 Sept 2026 — **PARKED by Olav, 16 Sept evening. The tablet is the test device.**

**Olav, after the evening build:** *"The issue is really only the small size of the button here.
The phone has room (at least this model) for the rail. And we COULD make the rail scrollable to
cater for smaller sizes. Obviously, a larger screen benefits for this app anyway, but need to
deal with it. Let us note this for later. The initial testing will be performed using a tablet.
And I will do more testing. So not priority to fix. The other parts of the UI is actually OK (a
bit tiny everything)."*

**So the phone is a known-good-enough surface, not a blocker.** What remains open on it, in one
place, so the rest of this block can be read as history:

- **The loupe's buttons are too small**, and nothing else is. `Dismiss` is the button in the
  photographs; `Add waypoint` was not even drawn because the replay carries no position. The
  measurement that decides the repair is still unread — see the legibility half below.
- **The rail fits** after `3ed258c9` + `e55c648c`, and Olav has withdrawn the second half of the
  budget: no two-column rail, no moving settings into the panel. **A scrollable rail is his own
  note for a smaller phone than this one**, not for the S23 Ultra.
- **The mosaic** is still the one functional fault, still instrumented and unread.

#### The findings as they were worked, 16 Sept evening — two closed, two waiting on a log

**Olav's own notes from a pass on a Samsung S23 Ultra.** The numbered items are kept as he
wrote them; what follows each is what the evening session found.

1. ~~**No mosaic at all on the phone.**~~ **DIAGNOSED — it is not a mosaic fault. Instrumented
   in `262be7fe`, waiting on one log line.** Olav, on the build of the same evening: *"The
   Mosaic does not [work] (nothing happens, the last full screen stays active although the
   side scan option gets selected). Multi screen: I get full screen with either side or down
   instead of the one split with mosaic. Button selection is correct."*

   **That is `has2DView`'s documented fallback firing, and the two shapes match it exactly.**
   `has3DView` is `wantsMosaic && view3dToggleAvailable`; `has2DView` is `wantsEchogram ||
   !has3DView` — *"the echogram holds the screen when the mosaic was asked for and cannot be
   drawn. Never nothing at all."* With `view3dToggleAvailable` false:

   - `single_mosaic` → `firstMode` is `""`, so `applyEchogramMode` is never called and the
     **outgoing picture stays exactly as it was**. "Nothing happens, the last full screen
     stays active."
   - `split_side_mosaic` / `split_down_mosaic` → `splitEchograms` false and `firstMode` is
     `side` / `down` → **one full-screen echogram**. "Full screen with either side or down."
   - The chooser still marks the row because the **preference was stored**. Only the pane was
     never built. "Button selection is correct."

   **So the question is which of the three terms of `view3dToggleAvailable` is false**, and
   they have three different fixes:

   - **`core.filePath` is EMPTY DURING A DEMO.** `Core::startDemo` never sets it and clears it
     if a file was open. A demo carries exactly as much position as the file it replays and is
     missed by **both** halves of the position test. **This is the leading candidate**; if the
     phone was running a demo it is the whole of it.
   - **`is2DTransducer` is the COMMITTED device**, while every other screen-chooser question
     follows the DISPLAY model (`offersScreenChoice` is `!displayIs2DTransducer`). A blue log
     on an app with nothing committed would be offered the layouts and refused the pane.
   - **`mavlinkDetected`** — raised by any MAVLink frame, a replayed one included, so this one
     is the least likely to be the culprit.

   **Do not write the fix before the line is read.** `262be7fe` prints `MOSAIC:` at startup, on
   every layout choice and whenever availability moves, naming all three terms plus
   `has3DView` / `has2DView` / `splitEchograms` **and the 3D pane's size** — so if it ever
   reads *available true* the next question is answered by the same build. D-2's precedent is
   the reason: a derivation there nearly bought a migration the data never justified.

2. ~~**`split_side_down` shows only the side scan.**~~ **CLOSED, 16 Sept 2026 — by the build,
   not by a commit.** Olav on the current build: *"The dual side/down works now."* The phone
   had been running an older APK; `c5f970a4` and the rest of the device day's eleven commits
   close it. **No phone-specific fault existed.**

3. ~~**The rail does not fit.**~~ **PART DONE, `3ed258c9` + `e55c648c`; the rest waits on a
   measurement.** The arithmetic, which turns this from an opinion into a budget — the column
   at `uiScale` = `mainview.s`:

   | | live blue | replaying (no Record) |
   |---|---|---|
   | buttons | 7 × 60 = 420 | 6 × 60 = 360 |
   | divider + source | 65 | 65 |
   | settings + collapse + back-to-classic | 180 | 180 |
   | wordmark | 150 + 10 | 150 + 10 |
   | spacing (8 between each) | 104 | 96 |
   | margins + 34 Android top inset | 54 | 54 |
   | **needs** | **983 u** | **915 u** |

   **And both of the app's scales are floored.** `uiScale` is `Math.max(1.0, shortSide / 1100)`
   — it grows on a tablet and can never shrink on a phone — exactly as `UiMetrics::scale()`
   sits on its own 0.75 floor. **Nothing that scales down reaches this**, which is why the
   answer is a budget and not a smaller number.

   **The 'N' was a prediction that came true.** The `ColumnLayout` shrinks the fill-height
   spacer to zero and then squeezes every item, but the wordmark's `Image` kept a fixed
   150 × 30 and was only *centred* in the shrunken box — so it **overflowed off the bottom of
   the screen** rather than shrinking. At −90° the original left edge maps to the bottom, so
   what stays on screen is the END of the word: TechAdVisio**n**.

   - **`3ed258c9` — the wordmark is elastic, and absent below its natural size.** Olav's choice
     of the three shapes offered; half-sized it reads as a smudge and spends the room anyway.
     It leaves the `ColumnLayout` and is anchored into a slot the column's bottom margin
     reserves. **Out of the layout is what makes the question answerable without a hand-written
     sum**: `column.implicitHeight` IS the controls' natural height, kept by the layout itself,
     so a button added or withdrawn is counted with nothing to remember. **And it cannot loop**
     — `implicitHeight` reads the children's preferred heights, never the layout's own geometry
     or margins. Hiding the wordmark *in place* would have looped: dropping `implicitHeight`
     would make it fit, which would show it again. Only ever shrinks, so a tablet is unmoved.
   - **`e55c648c` — the way back to classic is retired.** Olav: *"Drop that 'return to classic'
     arrow. We do not need it."* It was scaffolding and the file said so; the settings list's
     Experimental row has carried the variant switch since the panel was built, kept beside the
     rail's button for one build rather than instead of it. That build has been run. **68 u**,
     and that row is now the only way back — the comment there says so.
   - **Not done, on Olav's steer:** *land the wordmark and measure again.* Two columns of
     buttons on a short screen (recovers ~45% of the height for ~5% of the picture's width) and
     moving settings/collapse into the panel (128 u) are both on the table and neither is worth
     choosing against an estimated available height.

5. ~~**Two crosshairs and two zoom boxes in a split**~~ — found on the phone, **confirmed on
   the tablet, and NOT a phone problem.** **FIXED `027b35d1`, VERIFIED ON THE TABLET 16 Sept.**
   Olav: *"Loupe boxes now disappears from the first half screen when I press the second half
   screen. Solved."* Olav: *"The upper (or lower) screen
   does not clear its old when I touch the other screen. Same now in tablet, not a phone
   problem."*

   **Nothing about the sync was wrong.** `setSyncCursor()` sets `syncDepthValid_`, which is what
   makes a pane's aim *foreign*, and `Plot2DAim::draw` already refuses a foreign aim both halves
   — no crosshair, and `cand_` cleared so the panel is not tappable either. The flag was set
   correctly every time. **The pane never drew again**, so the guard never ran and the pixels
   from the previous touch stayed on screen.

   ```
   setSyncCursor()
     └ setTimelinePositionByEpoch()   if (echogramPause_) return;
         └ setTimelinePositionSec()   if (echogramPause_ && !drag) return;
             └ plotUpdate()           ← never reached
   ```

   **The loupe exists only while paused** — `Plot2D.qml` raises an aim on press exclusively
   under `echogramPause` — so the one state in which that repaint is needed is the one state in
   which it could not happen. A running echogram redraws within a frame regardless, which is why
   only a *paused split* ever showed it. `clearSyncCursor()` has always ended with
   `plotUpdate()`; the asymmetry between the two was the bug.

   **And it is the device day's own lesson nine in a new place.** `78ee70cc` deleted the mirror
   and verified the split; this gesture — touch one pane, then touch the other — was never
   tried, and the guard it added was correct the whole time.

4. **The forced landscape is on borrowed time.** The console already warns about it. If Google
   stops honouring it, *"the narrow split screen view we get as landscape today will rule"* —
   so the narrow case is not an edge case to tolerate, it is the case to design for. **Not
   started.**

**And the legibility half, which is NOT a fit problem:** the loupe and its fonts are too small
to read on the phone — *"the box is a bit too tiny (fonts are a bit tiny, specifically)"*. The
cause is in `UiMetrics::computeScale()`: it divides a **logical** short side by a reference of
1200 and the result then multiplies **device**-pixel constants. The two coincide only at
dpr 1 — the desktop window named in that function's own comment. Both the phone and a 10"
tablet were expected to land on the 0.75 clamp floor, so **nothing that scales down can help
the phone**; it needs the base scale fixed.

**LOGCAT IS NOT NEEDED, and this was not known until now.** `main.cpp:418` installs `AppLog` as
the Qt message handler, so every `console.log` in the app is written to a rolling file on the
device: `/storage/emulated/0/Documents/KoggerApp/AppLogs/kogger*.log`, under **Documents** and so
reachable over USB or any file manager, 8 MB × 5 on Android. Every `METRICS:`, `MOSAIC:`,
`THEME:`, `MODE:`, `RANGE:` and `SOURCE:` line this project has ever written is in there. `Core`
also exposes `appLogFilePath()` and `revealAppLogFolder()` as `Q_INVOKABLE` and **nothing in QML
calls either** — a settings row would turn this into a tap instead of a hunt. This retires the
"logcat was unavailable again" check that has been owed for several sessions.

**INSTRUMENTED, `b753c340`, and the code is NOT to be touched before the line is read.** One
`METRICS:` line prints the window in logical units, `Screen.devicePixelRatio`, the screen both
ways, the short side, the **raw** ratio before the clamp, the clamped `s`, `theme.resCoeff` and
three derived sizes — at startup and again 400 ms after the last resize, because the activity
forces landscape and the window is resized after QML is up. Raw and clamped both print: `0.75`
and `0.75-because-the-floor-caught-it` are otherwise the same string.

**THE NUMBER SELECTS BETWEEN TWO OPPOSITE FIXES, which is why the code is not to be touched
first.** `qPlot2D::paint` contains a cliff:

```
const qreal dpr = window()->effectiveDevicePixelRatio();
deviceScale_ = (qAbs(dpr - qRound(dpr)) > 0.01) ? dpr : 1.0;
```

An **integer** dpr takes one branch and a **fractional** dpr the other:

- **dpr ≈ 2.0 on both devices** → `deviceScale_` is 1.0 everywhere, every `UiMetrics` number is
  *logical*, and the phone's chrome is small for the plain reason that `scale()` is pinned at
  the 0.75 floor while the tablet sits above it. **Fix: the base scale**, with `bf80ab02`'s
  clamp keeping a split safe.
- **dpr ≈ 1.75 on the phone** (density 3.5 × `main.cpp`'s `QT_SCALE_FACTOR=0.5`) **and 1.0 on
  the tablet** → the phone takes the fractional branch, its canvas is 1.75× denser, and every
  constant the C++ painter draws with is **device pixels on the phone and logical units on the
  tablet**. One number, two coordinate systems. **Fix: the painter converts** — and touching
  `scale()` would then be wrong, because QML reads `Ui.iconTouch` as *logical* units in
  `SettingRow`, `KeyCodeInput` and the rest, and would inflate every control.

**Olav's own report leans to the first** — *"Text is readable. But the button size is small"*,
and a font at 18 **device** px on a 560 dpi screen would be under a millimetre tall. Leaning is
not reading.

**And the two knobs are separate.** *"The entire zoom box could actually be larger. But also
cannot be much larger for the dual screen options."* The box is already one knob —
`plot2D_aim.cpp`'s `zin.boxSizePx = isUiVariantV2_ ? 320 : 250`, named in its own comment as
*"THE ONE KNOB FOR ZOOM BOX SIZE"* — and `bf80ab02` shrinks **the tile and never the chrome**
when the pane is short, so raising it gives a bigger box full screen and takes it back in a
split with nothing to decide per layout. The **buttons** are the other knob and their minimum is
physical, not proportional. If the chrome alone ever exceeds a split pane, the honest next step
is the layout `bf80ab02` already named — buttons **beside** the tile, not beneath it — and not a
smaller button.

**And the Android case is not what the code reads like.** `main.cpp` sets
`QT_AUTO_SCREEN_SCALE_FACTOR=0` and `QT_SCALE_FACTOR=0.5`, so the logical-to-device ratio is the
device's own density times a half — **near 1 on a normal-density tablet**, which is precisely
the dpr-1 desktop window `computeScale()`'s comment names, and why the tablet has never looked
wrong. On a 560 dpi phone it is not. So the one number that decides whether this is a divergence
or a constant factor is the **dpr**, and nobody has yet read it off a device. Needed from both
the phone and the tablet.

Do the fix **after** `bf80ab02`, not before: the fit clamp is what stops a larger base scale
from putting the buttons off the pane again.

### P2 — Opening a file without freezing. Three items, one expensive step

Olav has raised this twice, and it is the worst thing a customer meets on first contact:
*"These logs take like forever to open, and the entire UI becomes unresponsive."*

**All three want the same thing — read the log ahead of rendering — and the documents already
say design them together rather than growing three prescans.**

- **Burst playback** (`demoPeriodMs_ = 0`), using the demo transport rather than demo mode.
  The three traps are recorded: `wasKlfFileOpened` must stay TRUE, the links must not close,
  `demoPrescan` can be skipped. Do not promise a shorter open; promise a **visible** one.
- **A file-side prescan** — Olav's own idea: *"read some log content, let the app abilities do
  the app setup (but not try to configure the transducer as it is a file) and THEN show the
  content."* The demo path already works this way. It would turn `applyForSource`'s
  `presentedModel` trigger from a repair into a non-event.
- **A progress surface.** `DeviceManager::openFile` already computes `progress_` **and throws
  it away** on the shipping branch. v2 has no progress surface at all. The number exists; it
  has nowhere to go.
- Noted, not chosen: turning `SEPARATE_READING` **ON** is the smaller change and gives a
  cancellable open for free, but it is a build option nobody ships and it re-threads the whole
  reception path. The two are not exclusive.

### P3 — The mosaic and downscan geometry. Two items that are one piece of work

**The nadir band and the downscan view are the same job**, and the documents say so: closing
the nadir null by interpolating across it *is* Olav's standing note *"we should work with
interpolating the two channels into one view for downscan."* Worth doing once rather than
twice.

- **The nadir band in the mosaic** — physical, not a geometry error; our slant-range lookup was
  checked and is honest. Two treatments: blank the wedge (needs a per-epoch width from the
  bottom track and a transparency path through the tile writer that may not exist), or
  interpolate across it.
- **Downscan from two channels.**
- **Deliberately after P1**, because it wants the split-screen/downscan decision settled first
  so it is not built twice.

### P4 — Small, independent, low risk. Any order, any spare half-session

- **The speed gauge** — asked for by the professional dealer. The data already exists
  (`vruVelocityH`, a root context property), it is a third line on the depth/temperature
  overlay, the unit is the user's with one decimal, and the setting belongs under
  `Screen & echogram`. Two small decisions left: absent or dashed with no MAVLink, and whether
  it is suppressed while paused.
- **Classic's mosaic filter wiring** — the same water-body-filter-as-black-point fault in three
  places in `PulseAppClassic`, deliberately not touched. One commit if classic is ever used on
  a side scan in anger.
- **The water body filter's MEANING per device.** `echogramWaterBodyFilterEnabled` and
  `echogramWaterBodyMinRealValue` are flat runtime properties, not profile data. The filter's
  *value* went per-picture on 15 Sept (`7dc2676b`); its *meaning* is a bigger idea and its own
  commit.
- **The per-pane range question** — a side pane's range is a swath width and a down pane's is a
  depth, and until there is somewhere to keep two numbers they share one (`rangeSecondPane`).
- **Backlog item 9's other half** — with `demoLoopEnabled_` false, end of file while paused
  still stops the demo, and `exitDemoMode()` then clears the committed model and asks for
  re-detection under a frozen picture. Loop is on by default, so it does not bite today.

### P5 — Not blocking, needs water or hardware

The boat run with two transducers, the real device swap, the PULSEblue-IP acceptance test.

---

## The order, and why

1. ~~**A**~~ `d75e4f12` · ~~**B**~~ `e8634060`…`b5849994` · ~~**C**~~ `2b2074f8` · ~~**D**~~
   `2cf5c267`, `af857891` — **all done.**
2. ~~**The manual-choice matrix**~~ `a47c1114` · ~~**the cold-start demo**~~ `3ef7249a`,
   `f0b4bcb3` · ~~**the demo loop range**~~ `d8510413` · ~~**per-picture intensity and
   filter**~~ `7dc2676b` · ~~**black stripes under TVG**~~ `bd14130f` — **all done, none seen
   on a device.**
3. ~~**P0 — the build and the push**~~ — **done 16 Sept 2026**, branch pushed at 0/0.
4. **P1 — E, then phone sizing.** One continuum.
5. **P2 — the file-open freeze**, designed as one piece of work.
6. **P3 — the nadir band and downscan**, after P1.
7. **P4** — whenever there is a spare half-session.
