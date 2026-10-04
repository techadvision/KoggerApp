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

> **ANSWERED by session 2, 27 Sept 2026: the two fixes below are not opposites, and both
> are needed.** The branch is consistent; the ruler and the v2 loupe ignore it. See *Session 2*
> under THE NEXT STAGES. The original reasoning is kept as written.

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

### P2b — The three source choices, from Olav, 16 Sept evening — **NOT STARTED**

**His own words, recorded before they are interpreted:** *"Remove the sub text under button for
simulation (Simulate a file). Then add 'Stream a file' as new. This behavior. Then repurpose
'view a file' as 'open a file'. This to use the old behavior. But we keep the new pill that
allows the impatient user to stop and abort - and then we show the result similar to now."*

**This turns P2's burst item from a change to OPENING into a third user-visible CHOICE**, which
is a better answer than the one the design reached for: instead of one open that behaves
differently from before, there are two named acts and the user picks.

The connection screen's three rows, after:

| row | what it is | today |
|---|---|---|
| **Start a simulation** | demo mode - closes the live links and pretends to be live | `PulseConnectionScreen.qml:830`; the caption at `:980` goes |
| **Stream a file** | **NEW.** The demo TRANSPORT with the FILE flags: links stay open, `wasKlfFileOpened` stays true, the picture fills as it reads | does not exist |
| **Open a file** | read it all, then present it, with the timeline and scroll-back | `:901`, today's *View a file* |

- **Remove the caption** *"Replays a recording as if the transducer were live."* (`simCaption`,
  `:980`). One line.
- **Stream a file** is P2's burst-playback item with its three recorded traps unchanged:
  `wasKlfFileOpened` must stay **TRUE**, the links must **not** be closed, and the prescan is
  already done by `ea5cf3d3`. It is the demo *transport*, never demo *mode* - that distinction
  is the whole of the difference between this row and the first one.
- **Open a file** keeps today's behaviour **and the new pill**: `4807efea`'s yielding parse and
  `49f9b85e`'s Stop / Close stay exactly as they are, because they are what makes waiting
  bearable rather than what makes it a stream.

**ONE THING TO CONFIRM BEFORE BUILDING, and it is a reading rather than a quotation.** *"This
behavior"* against **Stream a file** is taken to mean the progressive fill - a file arriving like
a feed - and *"the old behavior"* against **Open a file** to mean read-it-all-then-show. If it is
the other way round, the two rows swap and nothing else in this item changes.

---

### P3 — The mosaic and downscan geometry. Two items that are one piece of work

**STEP 1 AND STEP 2 ARE BUILT, 16 Sept 2026, on `feature/pulse-p3-downscan-nadir`** (off the
pushed tip of `feature/pulse-ui-v2-rail`, which was confirmed at 0/0 first). Scope confirmed by
Olav before anything was written: **channel 1 and channel 2 of the SIDE SCAN blended with each
other.** The 2D transducer is not involved at any point, and the new category is absent on a red.

**ALL THREE STEPS ARE NOW BUILT.**

| commit | what |
|---|---|
| `746d199d` | the down scan is two channels, not the one that owns the half |
| `d93f3364` | the blend can be falsified: a Down scan group with the two knobs that matter |
| `57d2d848` | the RMS-against-Mean check could not have failed, and is now a different check |
| `57ed6248` | two looks are only two looks at the same level: a balance set by eye |
| `5295580d` | the nadir band is interpolated across, between the two sides' trusted edges |

**The finding that made the job smaller than it looked.** The down pane was never "the side
scan data with a different grid" — it is **channel 2 on its own**, and by arithmetic rather
than by choice. The range is signed, `plotDistanceRange2d` sets `0..R`, and
`plot2D_echogram.cpp` splits the pane at zero with `range1 = 0 - from`. With `from = 0` that
width is **zero**, so channel 1 is never drawn. So this work is not inventing a down scan, it
is giving the existing one its second ear.

**The law, from ordinary multi-look processing.** Seabed backscatter is speckled — envelope
amplitude is Rayleigh, intensity is exponential, one look has a coefficient of variation of
1.0. Averaging N independent looks **in the intensity domain** takes that to 1/√N; port and
starboard are two independent looks at the same vertical return, so N = 2 and CV goes
1.00 → 0.71, about **1.5 dB of speckle suppression**. Intensity is amplitude squared, so the
estimator mapped back into the renderer's domain is `sqrt((a² + b²)/2)` — the quadratic mean.
An arithmetic mean of *amplitudes* is a biased-low estimate of mean intensity; averaging
log-compressed values is a geometric mean and worse again. The raw byte here **is** linear
envelope amplitude: `imageType 3`'s own comment calls its side scan TVG a "log-law", so the
log is applied downstream.

**And the blend comes before the gain.** The AGC is an adaptive running normaliser along the
trace, so two channels each normalised against their own trace and then averaged have no
defined level law. Blending first and gain-shaping once gives the down pane the signal chain a
real down scan channel would have. Both of these are expert rows so they can be falsified
rather than argued about.

**Derived from the range, not carried on a flag.** "Two channels and a range that does not
cross zero" IS the down case, so the full-screen down view and the split's bottom pane are both
covered with nothing to keep in step, and a side scan — whose range does cross zero — is
untouched by construction.

**No new cache, which is the whole answer to the hazard the branch was made for.** The blend is
written into a scratch `Echogram` that `invalidateDerived()` is called on before it renders, so
it **joins** `bd14130f`'s discipline instead of becoming a fifth buffer outside it. Nothing is
stored per epoch, so nothing can go stale behind a black-stripes repair. `chartTo`'s gain
selection and its resampler were lifted out whole into `gainSource()` and `chartFrom()` so the
blended trace renders through exactly that code rather than a copy of it; the existing call
path is unchanged.

**Falls back to the primary channel alone** whenever the blend cannot honestly be made:
blending off, the other channel missing, or the two disagreeing about resolution or offset. A
blend of two traces on different grids is a quiet mis-registration, which is worse than the
single channel it replaces.

**Channel balance is deliberately not built.** Equalising port against starboard before
combining is correct practice, but the honest estimator is a slowly varying ratio of each
channel's seabed-region intensity over a few hundred pings; a per-ping ratio chases speckle and
makes the picture worse. It waits until the blend has been seen.

#### To check on the device — in this order

Open a **blue** log (or a blue demo) and put a **down** picture on screen: full screen down, or
`split_side_down` and look at the bottom pane.

- **The bottom pane must look different from before, and quieter.** The speckle is what moved;
  the level and the palette should not have. If the whole pane got brighter or darker, the
  blend is not landing where it was meant to and the domain row is the first thing to try.
- **`Down scan` appears under Expert settings on a blue and NOT on a red.** If it shows on a
  red, `offersDownBlend` is reading the wrong question.
- **Tap through Channel blend with the pane on screen.** Every tap must change the picture
  immediately — that is the unconditional cache refresh. **Single must look exactly like the
  build before this one**; if it does not, the fallback path is not actually the old path.
  ```
  BLEND: down scan channels -> 1 RMS
  ```
- **RMS against Mean — and this check was WRONG as first written, which is worth keeping.** It
  said *"RMS should be the brighter of the two; if Mean is brighter, the byte is not linear
  amplitude"*. **RMS is brighter than the arithmetic mean for every possible pair of samples**,
  by the power-mean inequality, with equality only when the two channels agree exactly. The
  outcome was fixed by arithmetic before the app was built, so the check could not have
  discriminated anything — lesson eighteen, *a check that must be ignored is worse than no
  check*, in a new place and written by me.

  **And the honest expectation is that the two look nearly identical.** For two independent
  Rayleigh looks the speckle coefficient of variation is 0.52 for a single channel, **0.363**
  for RMS and **0.370** for the arithmetic mean — a 2% difference, invisible. RMS runs about
  **6% brighter**. Both deliver essentially all of the 1.5 dB; RMS is the principled estimator
  rather than the visibly better one. **The difference that is actually visible on the water is
  Single against either of them.**

  **So the row earns its place as a DIAGNOSTIC rather than as a preference:** if RMS and Mean
  look *obviously* different, the two channels are badly mismatched in level, because that is
  the only condition under which the two estimators diverge. That is the channel-balance
  question answering itself.

  **The domain question cannot be settled by looking.** Whether the raw byte is linear envelope
  amplitude or something already squared or log-compressed is a question for the firmware and
  for Dennis's side of the house, not for the picture. `imageType 3`'s "log-law" comment is the
  evidence the code carries; it is not proof.
- **Blend the: Raw against After gain.** Raw is the recommendation; After gain is likely to
  look flatter or to breathe with the AGC. Whichever reads better on the water wins the row.
- **The side scan pane must not change at all**, in a split or full screen. Its range crosses
  zero so it never reaches the blended path; any change there is a bug in the half selection.
- **A red must not change at all**, anywhere.
- Worth watching for on a long file: the blend costs one extra pass per epoch per invalidated
  column. If scrolling back through a large log is visibly slower than before, say so — the
  cheap answer is to blend after the gain, which reuses the buffers the side pane already
  built.

**QML and C++, and NOT COMPILED — the shell has no Qt.** The C++ touches `epoch.h` (header,
no `moc`), `qPlot2D.h` (**does** carry `Q_INVOKABLE`s, so `moc` must re-run) and
`plot2D_echogram.cpp`, plus the new `echogram_blend.{h,cpp}` registered in the top-level
`CMakeLists.txt`.

### The nadir fill, `5295580d`

**Feathered, because the degradation is smooth.** Ground sample spacing in the mosaic is
`dr · r/x` — 1.41 slant samples at *x* = 1.0 × depth, 2.24 at 0.5, 4.1 at 0.25 — so a hard cut
at any single width leaves a seam, and the conventional 45° blanking also throws away usable
data between about 0.6 and 1.0 × depth. Fully filled inside **0.3 × depth**, fully real outside
**1.0 × depth**, smoothstepped between, both factors expert rows.

**The fill excludes the nadir data.** It interpolates across the track between the two sides'
**trusted edge values**, each read at its own outer edge with its own bottom track — the two
disagree on a slope. Both come off the **same epoch**, so the port and starboard half-strips
interpolate towards the same anchors and meet continuously at the track: no cross-quad state
and no dependence on rasterisation order. The lerp spans the full `2 × outer`, so at the outer
edge it *is* the real sample and the join needs no special case.

**Applied before the "both empty, skip this pixel" test**, deliberately — near the track the
real sample is very often zero, and that test is what has been leaving the band unpainted as
well as unlit. A zero anchor means *no data there*, not *black there*: one good anchor serves
both ends, and with no good anchor the epoch is left exactly as it is today rather than having
a guess painted over it.

**No refresh on the setters**, unlike the blend — these do not touch the echogram. A tile keeps
its pixels until re-traced, so the rebuild is the mosaic update action, fired from `main.qml`
through `Qt.callLater`, the same division of labour as the side scan TVG mosaic switch.

**No "show the nadir edge" row.** Turning the fill off shows exactly where the band was; a
drawn boundary would only approximate it.

**The wedge is invented data and is the tile colour only** — no bottom track, no depth readout
and no surface reads any of it.

#### To check on the device — the nadir and the balance

- **Draw a fresh mosaic on a blue and look along the track.** The dark strip should be gone,
  and the seabed should read continuously across the boat's path. **Tiles already traced keep
  their pixels** — use the mosaic update action, or a fresh log, or the band will look
  half-and-half.
- **Toggle `Fill the mosaic nadir` off and on with the mosaic on screen.** Off must restore
  exactly today's picture. That is the A/B, and it is also the honest answer to "how much of
  this is real".
- **Watch for a bright stripe rather than a dark one.** If one appears, the trusted edge is
  being read too close in and is picking up the specular nadir return — raise **Fully real
  outside** before touching anything else.
- **Watch for a seam** at the outer edge. A visible ring at a fixed multiple of depth means the
  feather is too narrow: raise the gap between the two factors.
- **`Fully filled inside` at 0** should look almost identical to 0.3 — the smoothstep does most
  of the work. If 0 looks obviously different, the inner factor is doing more than feathering
  and wants a look.
  ```
  NADIR: fill -> on
  NADIR: fully filled inside 0.3 x depth
  NADIR: fully real outside 1 x depth
  ```
- **`Channel balance` at 0 must be bit-identical to the build before `57ed6248`.** Both gains
  are exactly 1.0 there and every mode runs its untrimmed arithmetic.
- **Walk the balance to ±6 dB on a down pane.** The picture should shift towards one side's
  character without the overall level moving — that is the half-each-way construction. If the
  pane gets plainly brighter or darker as you walk it, the symmetry is wrong.
- **The nadir rows must not change the echogram at all**, and the balance must not change the
  mosaic at all. They are two different surfaces and each setter touches exactly one.

**One correction to the shape this document predicted.** "One derivation, two consumers" does
not survive contact: the blended trace cannot rescue the mosaic wedge. Inside the wedge the
ground-to-slant mapping is compressed to nothing — `d(slant)/d(ground) → 0` at nadir — and both
channels sit in the beam null, so fusing two nulls gives a null. What the two consumers share
is the **fusion rule and the nadir-width rule**, not a buffer. The mosaic's treatment is a true
interpolation with the nadir data excluded.

The original text of this item follows.


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

### The handover set — 17 Sept 2026, `c426ef6e`

Three things Olav asked for before the build goes to his partner for testing.

**An expert starts in v2.** `"classic"` stays the declared default; a one-shot seed moves an
expert to v2 on the first start of a build that has this, or the moment a key code is accepted.
**A seed, not an override** — the flag fires once per install, so an expert who goes back to
classic in the Experimental row stays there. Two triggers, one body, because the entitlement may
already be stored when `PulseSettings` is built (`onIsExpertChanged` never fires) or arrive later
(`Component.onCompleted` has been and gone).

**An About category**, last before the expert title: the app name and the version. The name is
set once in `main.cpp` and was read by nothing, and the version left with the old welcome tab —
on Android there is no window title, so a tester had no way to answer *which build is this*. Both
come from two new `Core` invokables rather than a second `XMLHttpRequest` on `version.txt`.

**The transducer setters are back**, in a `Transducer` group under Expert settings.

> **What makes them safe is not the range, it is where the value lives.** Every row writes
> through the `"param"` target into `liveParams` — **runtime** (no experiment outlives its
> session), **keyed by profile** (red's and blue's never mix), **readonly** (`setParam` is the
> only writer). The container already refuses the dangerous thing. What it lacked was a **way
> back** that does not need a restart — `clearParams()`, unused since the map was built — and a
> **read-back on the row**, so a value the transducer refused or clamped shows as
> `2400 (device 2350)` instead of a slider sitting happily at a number the hardware never took.

Ranges are the device's own, from `DeviceItem`'s configuration SpinBoxes. Samples runs to 15000.
**Sliders with nudges**, because the two are not alternatives: +/- alone is 150 taps across that
range, and a drag alone is about forty units per pixel. The drag chooses the neighbourhood, the
nudge lands the number.

**Three more adjusters, and a repair, 17 Sept** — `3d700266`, `b1710aa4`, `e776b696`.

- **Frequency** (`transFreq`) shares its key with the rail's cone chooser, and the overlap is
  **shown rather than prevented**: a frequency that is not one of the profile's three cones
  leaves the chooser with nothing marked, which is the truth. Bounds are the profile's own
  widest and narrowest cone.
- **Ping period** (`ch1Period`, 0–2000 ms) — the echogram's speed, and the row the IP connector
  work needs.
- **Dynamic resolution** (`doDynamicResolution`) sits **between the rows it gates**, because
  while it is on `DeviceItem` drives `chartResolution` and writes `ch1Period` from
  `dynamicPeriod`. Both gated rows say who is holding the value in their hint — a row that
  silently loses what you put in it reads as a fault.
- **The chart offset check compared a value with itself.** `chartOffset_Copy` is assigned from
  `dev.chartOffset` on the line directly above the comparison, so the repair has never run once
  — which is why units in the field have kept a chart offset of 25. It now compares the device
  against what the app intends (0 in both profiles), bounded at three attempts so a unit that
  refuses says so loudly instead of looping the configuration.
- **The version is derived from the manifest now.** Not a repair: `resources/version.txt` was
  already correct at 1.38. But there is a **second, stale `version.txt` at the repository root**
  reading 0.89, referenced by nothing — I read that one first and wrote a fix for a drift that
  did not exist. The derivation retires the hand-kept duplicate; the root copy is left alone and
  named in `CMakeLists.txt` so the next reader does not believe it.

**Expert info is filled — `d4f89e5b`.** All forty-eight rows, ported from `PulseInfoExpert`'s
four read-only categories, and both placeholder components retired with the last category they
served. **Tier 3 is complete.**

- **Four readings written once** — `yesNo`, `onOff`, `okOrNot`, `orDash`. Classic spells each
  shape inline at every row, which is how it came to print a bare `true` in some places, `On` in
  others and a raw `-1` in a third. `orDash` carries the judgement: **a `_Copy` of -1 means the
  device has not reported yet**, which is not the same statement as a parameter whose value is
  minus one.
- **Device parameters is the other half of the Transducer group**, and its labels now match it
  exactly. That group says what the app asked for; this one says what came back.
- Two corrections carried across rather than copied: *Uses temperature* was gated on
  `useTemperature`, so it could never read anything but true; and *"Not verified (struggle?)"*
  loses the parenthesis — a row that asks the reader a question is not a reading.

**Samples and sample spacing set the trace length together**: `samples × spacing` is the range,
so finer spacing shortens the picture at a fixed sample count. That is the interaction Olav
wants to exploit, and it is also why the Maximum depth row can appear to fight these two.

#### To check on the device

- **Start the build as an expert.** It must come up in v2, once, with
  `SETTINGS: expert entitlement - starting in the v2 interface`. Then switch to classic in the
  Experimental row, restart, and it **must stay classic** — the line must not appear again. That
  is the seed-not-override test and it is the one that matters.
- **About** names the app and a version that matches `version.txt`. If the version reads as the
  whole line including the name, the parse fell back, which is by design rather than a fault.
- **Open `Transducer` on a committed blue.** Drag Samples up and watch the echogram change.
  Then tap a nudge: exactly one step, and the number must move by 50.
- **Watch the read-back.** After each write the `(device N)` suffix should appear briefly and
  then go, as the transducer reports back. **One that stays is the finding** — that value did
  not land.
- **Reset, and then restart.** Reset must put every row back to the profile's value in one
  action; a restart must do the same thing on its own, because the map is runtime.
- **Swap red and blue and come back.** The experiment must still be there, and red must never
  show blue's numbers.
- With nothing committed the rows read **not set** rather than 0 — the group is expert-gated and
  can be opened before a transducer is chosen.

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
5. ~~**P2 — the file-open freeze**~~ — **the prescan (`ea5cf3d3`), the yielding parse
   (`4807efea`), the interrupt (`49f9b85e`) and the opening pill (`33ae511a`) are all built and
   the first three are verified on a device.** What is left of it is **P2b**, which is a product
   decision rather than a repair.
6. **P3 — the nadir band and downscan**, after P1.
7. **P4** — whenever there is a spare half-session.

---

## The field-fix set — 27 Sept 2026, `feature/pulse-v2-field-fixes`

Olav's list after a week of reviewing and testing, cut as its own branch off the pushed
tip of `feature/pulse-p3-downscan-nadir` (1.39 plus one docs commit). Twelve items, eleven
commits. **Not compiled** — the shell has no Qt. C++ in four places (`plot2D.h`,
`qPlot2D.h`, `core.{h,cpp}` with two new `Q_INVOKABLE`s, `app_log.{h,cpp}`, `main.cpp`) and
Java in `PulseActivity`, so `moc` re-runs and gradle picks up the Java.

| commit | item |
|---|---|
| `b212a569` | `chartOffset` not written under a recording; `applyViewId` deleted (no caller, no handler outside classic) |
| `ba3860e8` | echogram speed ceiling 2.5, stored values above it clamped and written back; **live scroll-back reaches the start at any speed** |
| `1ab201cd` | rail order: range, intensity, filter, colours, cone/screen, pause, record; **Pause wears a green dot while positions arrive** |
| `63e2f502` | speed of sound row under Screen & echogram, for everybody (runtime override) |
| `f82b04fd` | the speed gauge |
| `dbec72c7` | automatic max range, a switch under the range slider |
| `3df64699` | **Open a file** and **Stream a file**; the simulation caption is gone (P2b) |
| `737f2291` | a demo asks the device question an opened file asks |
| `41818ef3` | `pulse.log`, bounded, **Send the log to Techadvision**, expert viewer |
| `44ded246` | the speed ceiling moves off the Settings object |

### Findings worth keeping

- **The scroll-back limit was the clamp, not the painter.** `qPlot2D::viewportRatio()` returned
  `width / N` — one data column per pixel. Above 1.0x a horizontal picture spends
  `echogramSpeed` pixels per column, so the oldest `1 - 1/s` of a screen could never be reached
  while live. The stretch is now one function, `Plot2D::horizontalStretch()`, read by the
  painter's reindex and the clamp. Paused worked only because pausing resets the speed to 1.0.
- **`applyViewId` was dead**: no caller, and `onEcoViewIdChanged` exists only in classic. The
  panel's "view" branch still writes `ecoViewId` harmlessly and nothing reads it in v2.
- **Positions**: `dataset.hasPositionData` is sticky (set on the first fix, cleared only with the
  dataset) and V1's green used `mavlinkDetected`, also sticky. The dot follows
  `dataset.lastPositionChanged` with a 3 s staleness timer; for an opened (not streamed or demo)
  file it reads `hasPositionData`, since nothing arrives after the open.
- **Speed of sound had machinery and no row** — `soundSpeedOverride` was built 14 Sept. It
  reaches a live device only; a recording carries its own.
- **A demo swap is a commit only.** `acceptDeviceSwap` normally raises `swapDeviceNow`, whose
  DeviceItem handler closes the log file and clears every setup state — under a running replay
  that would stall. The demo branch commits the model and re-marks the demo's setup states;
  `exitDemoMode` still re-detects. A declined demo swap does not block that model on hardware.
- **A readonly property on a Qt.labs `Settings` object is a trap** — everything declared there
  is persisted. The ceiling lives on `pulseRuntimeSettings`.

### Decisions taken with Olav

- Log: **everyone** gets Send (share sheet, `olav.aamaas@techadvision.com` pre-filled); the
  viewer (last 300 lines) is expert-only. 2 MB x 3 on Android.
- Open a file: **the echogram is covered** by an opaque card with a progress bar until the open
  ends; Stream a file is the old View a file. Drag and drop and the menu bar stream.
- Demo device: **ask the swap, like Open.**
- Speed gauge: absent (settings rows and line) without MAVLink; `-.-` after 3 s without a
  velocity update. Default unit km/h.
- Auto range: 2D only, as in classic. The slider and the pinch end it.

### To check on the device

1. **Echogram speed**: set 2.5x (the slider now stops there). Scroll back while live — the start
   of the file must be reachable. A phone that had 4.0 stored shows
   `SETTINGS: echogram speed 4 is above the ceiling - set to 2.5` once, then never again.
2. **Rail**: order is range, intensity, filter, colours, cone/screen, pause. With a boat sending
   GNSS the Pause button carries a green dot; kill the autopilot link — it goes out within ~3 s.
   `POSITION: available` / `not available` in the log. An opened file with positions: dot on.
3. **Speed of sound** under Screen & echogram: move it on a live red, the depth scale must follow;
   the hint then names the profile's value and a Reset row appears. Restart: back to the profile.
4. **Speed gauge**: third line under depth (and temperature). Switch units; imperial shows mph/kn.
   Only present with MAVLink. Pull the telemetry: `-.-`.
5. **Auto range** on a red: switch on in the Max range panel, the slider reads *auto* and dims,
   the range follows the bottom. Pinch or move the slider: automatic goes off. Let a demo loop —
   automatic must survive it (`RANGE: automatic` after the rebuild). A blue never shows the switch.
6. **Open a file**: the picture is covered with *Opening the file* and a bar; Stop and Close still
   work; the file appears in one go. **Stream a file** behaves as View a file did.
   `FILE: the open has ended - the picture is uncovered`.
7. **Demo device**: commit red, start a blue simulation: *Switch to PULSE blue* appears. Accept —
   no *Configuring transducer…* stall, the connection screen shows *Keep PULSE blue*. Stop the
   demo: re-detection as before. Decline instead: the demo continues as a picture, and a real blue
   later is still offered.
8. **Log**: Troubleshooting → *Send the log to Techadvision* opens the share sheet with
   `pulse.log` attached and the address filled in. The folder holds `pulse.log`, and no
   `kogger*.log`. Expert: *View the log* shows the tail, Refresh reloads it.
9. **chartOffset**: open a blue log in down scan with a red connected — no
   `PARAM: … chartOffset -> 0` line.

### Device report on the field-fix set, and two follow-ups — 27 Sept 2026

**Passed on the device:** Open / Stream, the app log and Send, the speed gauge, the rail order
and the position dot, the demo device question, live scroll-back, the 2.5x cap. Speed of sound
is present and seen in simulation, **live check still owed**. The chartOffset guard and the
applyViewId removal cannot be exercised directly; nothing misbehaves.

- **`41d2edb9` — the Colours icon.** Olav: the painted floor made the icon hard to read. New
  `pulse_color_bucket.svg` is the bucket and the drop only, with the viewBox cropped so it reads
  the size of the sun and the filter. Checked by rendering the three side by side.
- **`3e61b72a` — automatic range in a simulation.** Olav: *"for simulation, either the end depth or the
  start depth kind of determines the automatic range to be fixed."* **Cause:** the display level
  is `calculateAutoLevel(lastStableDepth)` and `lastStableDepth` is written only by the dynamic
  resolution updaters, which `calculateDynamicResolution()` skips in a demo on purpose. So the
  range read a frozen depth: 0 on a cold start (the start range), or the last session's depth (the
  end range). The display level now has its own tracker (same step, same stable-reading count),
  used whenever the resolution tracker did not run, reset when a demo starts or ends.
  **The same fault would have hit a live transducer the dynamic resolution does not manage** — the
  tracker covers that too. Live red is unchanged.

**To check:** start a red simulation with automatic on and watch the range step with the bottom,
deeper and shallower, within about a third of a second of each change. Let it loop: the range must
come back to the start depth rather than holding the end. Live red on the water must behave as
before.

- **`7b86ef0a` — automatic range and the second echo.** Olav: users who turn on *Optimise for a
  second echo* want automatic range to show the first two echoes. The code doubled only the
  **dynamic resolution** (what the transducer samples, `2 x depth + margin`); the **display
  level** followed the single depth everywhere, live included. It now takes `2 x depth` when the
  preference is on and the picture is 2D, in every mode. The preference is the user's, so nothing
  is read from the log. **To check:** red simulation, automatic on, toggle the preference — the
  range roughly doubles and the second echo comes into view; toggle off and it returns. On the
  water, confirm it did not already look doubled before this build (if it did, the doubling
  exists somewhere this reading missed and the factor must come out again).

---

## THE NEXT STAGES — planned 27 Sept 2026, one chat session each

The field-fix set is device-verified (live water checks still owed: speed of sound, the
second-echo range). What follows is ordered by risk to a customer, not by size.

| # | Session | Branch | Needs before it starts |
|---|---|---|---|
| 0 | **Push `feature/pulse-v2-field-fixes`**, publish 1.40 to internal test, push `master` (71 ahead of origin) | — | Olav, GitHub Desktop |
| 1 | **The startup hang** (splash never shown) + the manifest's six duplicated `splash_screen_drawable` lines | `fix/startup-hang` off field-fixes | the stack of the hung main thread (below) |
| 2 | ~~**Measure, do not fix**~~ **DONE 27–28 Sept**: see *Session 2* below. The two P1 fixes are not alternatives; both are needed | none | — |
| 3 | ~~**Base scale, fonts and the loupe**~~ **DONE 28 Sept, `f7e97415` + `3c5b6408`, verified on five devices** (see *Session 3*): first the painter converts (ruler and v2 loupe × `deviceScale_`), then the base scale's floor and slope | `feature/pulse-small-screens` | session 2 |
| 4 | ~~**Layout on small screens**: insets, scrollable rail, the tab, the brand~~ **DONE 28 Sept, verified on the G30 and the 320 phone** (see *Session 4*). Its remainder moved into session 6 | `feature/pulse-small-screens` | — |
| 5 | ~~**The mosaic is offered when none can be made**~~ **DONE 28 Sept, `83cf8e7a`, verified.** Plus the mosaic view fixes (`38a2f662`, verified), Pause (`82296a2b`, verified; Wipe withdrawn), nadir fill off by default, TVG release defaults (`f853bae8`) | same branch | — |
| 6 | **Finish the UI** - the breakdown is under *Session 6, the breakdown* below: 6a device checks owed, 6b split-pane walk, 6c split direction, 6d compact connection screen, 6e small UI leftovers | same branch | the next build |
| 7 | **Side scan waypoints are BROKEN - and a desk check to prove the fix** (Olav, 28 Sept). **Only after the UI is complete.** First build the desk check: an expert switch that swaps the side scan between **460 and 820 kHz** and actually sends the command to the transducer, so waypoint placement can be verified at the desk against a map with contours and the SITL autopilot, with no trip to real water. Then find and fix the waypoint placement. | its own branch | session 6 |
| 8 | **The P4 list and the rest**: classic's mosaic filter wiring, per-pane range, the filter's meaning per device, item 9, the forced-landscape deadline, then High performance mode | as fits | — |
| 9 | **Mosaic quality and tools** (Olav's list, 28 Sept; items 1-4 are done, `38a2f662`): **(a) Wipe and pause** - a pill on the mosaic to wipe what is drawn (the slide-in from shore and the drive out) and to pause/resume while the boat turns. **(b) The nadir fill** is not very successful yet, untested properly. **(c) Is the render slightly wrong?** An object moves about 1.5 m between passes in opposite directions with an M10 (about 0.5 m expected) and a well-tuned yaw; rule out our own geometry. **(d) KMZ export.** See *Mosaic, the later list* below. | its own branch | session 6 for (a) |

**Why the hang is first.** It happens outside Qt Creator too, and a customer who meets it
thinks the app is broken. **Why measuring is its own session.** P1 recorded that the dpr decides
between two fixes that are wrong for each other; guessing buys the wrong one.

### The startup hang — what the log already says

The log stops at `ProfileInstaller` with **no line from Qt at all**. Qt's messages are forwarded to
logcat by `videoLogHandler`, so a hang after `main()` would show Qt lines. So the process stops
**before or while the native libraries load** — in Java, in `PulseActivity.onCreate` or Qt's
loader — or it is **waiting for a debugger** (`-Xcheck:jni` means a debuggable build; an
intermittent "Waiting for debugger" would look exactly like this under Qt Creator).

**What to capture the next time it hangs**, without stopping the app:

```
adb shell pidof org.techadvision.pulse
adb shell kill -3 <pid>          # SIGQUIT: ART writes every thread's stack, the app keeps running
adb logcat -d | grep -A40 '"main"'
```

The `"main"` thread's stack is the answer. Also useful: `adb logcat -d -b all > hang.txt` (the
unfiltered buffer, not the app-only view), and whether `pulse.log` got a new
`--- log opened` line for that start — if it did, `main()` ran and the hang is later than it looks.

### Session 1, 27 Sept 2026 — `fix/startup-hang`, off master at 1.40

**No hang log was available yet**, so this session read the start path end to end in Qt 6.8.3's
own Java and C++ (`QtActivityBase`, `QtActivityDelegate`, `QtLoader`, `QtThread`,
`androidjnimain.cpp`) and in `PulseActivity`. **No fix is committed for the hang. Nothing gets
fixed until one hang has been captured.**

| commit | what |
|---|---|
| `e4c259ce` | the manifest keeps one `splash_screen_drawable` line; `tools/pulse-manifest-check.js` |
| `433a05f6` | `STARTUP:` breadcrumbs from the first line of `onCreate` to `main()` (logging only) |

#### What the start path actually is, in Qt 6.8.3

1. `PulseActivity.onCreate` → `super.onCreate` → `QtLoader.loadQtLibraries()`. **The libraries
   are loaded on `qtMainLoopThread` while the UI thread waits** on a semaphore (`QtThread.run`).
   libPulse's static constructors (`Core core`, `Themes theme`, …) and then our `JNI_OnLoad`
   run in there.
2. `QtActivityDelegate.startNativeApplicationImpl` **does not start `main()`**. It adds a
   global-layout listener, and `main()` starts on the first layout.
3. After that the window can draw. **Our pre-draw gate holds every frame until the insets
   listener has run once.**

**So "no splash and no Qt line" means the UI thread never drew.** Either it is blocked, or its
frames are being cancelled. If `main()` alone were stuck, the window background, which *is* the
splash drawable, would still draw. And **`ProfileInstaller` needs the main looper twice**, once
for a frame callback and once for a ~1 s delayed message, so its line suggests the looper did
run at some point in that pid.

#### The leading candidate, and it can be checked with no build

`QtActivityBase.onDestroy` calls `QtNative.terminateQt()`, which **waits for the native `main()`
to return** and only then calls `System.exit(0)`. What would make `main()` return is Qt's
suspend path, which only calls `QCoreApplication::quit()` when event loops are blocked while
suspended. **Our manifest has `android.app.background_running=true`, which turns that off.** So
when the activity is destroyed with the process still alive, nothing tells `app.exec()` to
return. **The UI thread waits in `onDestroy` forever, and the process stays alive with its wake
lock held.** The next tap on the icon goes to that same process, its main looper is blocked, and
nothing is ever drawn. That matches what is seen on an ordinary start.

The second route to the same place: an activity recreated in a live process makes Qt call
`restartApplication()`, which does `startActivity` + `Runtime.exit(0)` **on the UI thread**. The
exit runs libPulse's static destructors (`~Core` → `shutdownBackgroundWorkers`, which includes
`BlockingQueuedConnection`) while `app.exec()` is still running.

**Not yet explained by this:** the Qt Creator case. An install kills the process, so that start
is a fresh one. It may be a second fault. The breadcrumbs cover both cases.

**Check before tapping the icon, when the app seems closed:** `adb shell pidof
org.techadvision.pulse`. **If there is a pid, the process is still alive, and a tap will land in
it.** Then `kill -3` that pid: the `"main"` stack will show `terminateQt` / `sem_wait` under
`onDestroy`, or `Runtime.exit`.

#### What the breadcrumbs say (`adb logcat -d | grep STARTUP`)

On a good start, in this order: `onCreate #1 in pid N`, `JNI_OnLoad entered` / `done`,
`Qt libraries loaded`, `nativeInit -> true`, `onCreate returned`, `first insets delivered`,
`first global layout`, `first frame drawn after K held back`, `main() entered`,
`main() is running, the log handler is installed` (also the second line of `pulse.log`).
**The last line printed is the step that did not finish.** Also:

- **`onDestroy #…` as a pid's last line** → the wait described above.
- **`onCreate #2` in one pid** → the process was reused. Qt then restarts the whole app.
- **Nothing after `onCreate #1`** → stuck in library loading or in a static constructor
  (these run before `JNI_OnLoad entered`).
- **`first frame held back` with no `first frame drawn`** → the pre-draw gate, and the insets
  never arrived.

#### Noted, not changed

- **`JNI_OnLoad` calls `hideSplashScreen(333)`**, so Qt's own splash overlay starts fading at
  library load, before anything has drawn. What the user sees is the theme's window
  background. Harmless, but pointless.
- **`notifyInsets_native` posts to `qApp` before `main()` has built it.** The first insets
  always arrive before `main()` starts (Qt starts it from the layout that follows them), and
  `invokeMethod` returns false on a null receiver, so **the first insets are dropped**. Its
  own commit if the top inset is ever wrong at startup.
- **The pre-draw gate has no way out** if the insets never come. It is left as it is so the
  breadcrumbs can show whether it was ever the cause.

#### The first device run of the breadcrumbs, 27 Sept evening

**A good start prints every breadcrumb in the predicted order.** `first frame drawn after 0 held
back`: on this tablet, the pre-draw gate never held a single frame.

**`ProfileInstaller` comes LAST on a good start**, after `App is created` and `METRICS: settled`.
It is the final app line of a successful start, not an early one. So the original report, a
log that "ends at ProfileInstaller with no Qt line", **came from a process that had already
started completely**. The Qt lines were missing from that view, not from the process. That
supports Olav's suspicion of the dev environment: Qt Creator's output following a different pid
from the one on screen.

**The two failed runs were deaths, not hangs.** Qt Creator reported `Android target
"org.techadvision.pulse" died`, and `pidof` returned nothing. So the process was gone and
`kill -3` had nothing to read. **The tool for a death after the fact is
`adb shell dumpsys activity exit-info org.techadvision.pulse`.** Android keeps the reason for
each recent process end (crash, native crash, ANR, signal, killed by install, user request),
with a timestamp. It needs no reproduction and nothing running.

**Seen in the build log, not the cause:**
- `link_manager_wrapper.cpp:267` — `getUuidFromString` returns `QUuid` and has no `return`.
  That is undefined behaviour, but nothing calls the function (no C++ caller, no QML caller).
  Worth a one-line commit of its own.
- `installtoken.cpp` includes `"InstallToken.h"` and the file on disk is `installtoken.h`.
  Harmless on macOS, which ignores case. A Linux or CI build would fail.

**Session 2's first number arrived with this log**, from the tablet (1920 x 1200 device px):
`METRICS: settled | window 2560x1600 logical | dpr 0.75 | … | raw 1.333 -> s 1.333 (not clamped)
| resCoeff 1.5`. **The dpr is 0.75, a fraction**, so the tablet takes the FRACTIONAL branch of
`qPlot2D::paint`'s `deviceScale_` test. Neither of the two outcomes P1 predicted (≈2.0 on both
devices, or 1.75 / 1.0) has happened. The first `METRICS: startup` line (`427x607`, clamped) comes
from before the landscape resize, as designed.

#### ANSWERED for Qt Creator, 27 Sept evening: the deploy kills its own launch

Olav's `exit-info` and the `-b all` log from 18:02–18:35 show all 17 process ends for the
package. **Not one was a crash, a hang or an ANR.** They are 7 × `PACKAGE UPDATED`
(`installPackageLI`), 9 × `USER REQUESTED / FORCE STOP` and 1 × `DEPENDENCY DIED`.

**Every failed run has the same four lines**, and no successful run has them:

```
18:14:02.335  am_kill   6924  stop org.techadvision.pulse due to installPackageLI   <- the install kills the running app
18:14:02.993  Start proc 7286 for next-top-activity                                 <- Android relaunches it, because it was the top activity
18:14:03.188  am_kill   7286  stop org.techadvision.pulse due to from pid 7315       <- 0.2 s later: `am force-stop` from the deploy
              (no further Start proc)                                                -> 18:14:48 Qt Creator: "target died"
```

The same shape appears at 18:07:37 (6236), 18:17:35 (8508, killed between `JNI_OnLoad done` and
`Qt libraries loaded`) and 18:34:11 (14280, the "clean" run at 18:34:56). **The app is killed
by the deploy, from outside.** Qt Creator's install kills the running app. Android relaunches it
because it was on top. Qt Creator's force-stop then kills that relaunch, and no start follows.
The screen shows nothing because nothing is running, and Qt Creator gives up after about
45 seconds and reports the pid it was watching as dead.

**Every start that was not force-stopped reached `first frame drawn after 0 held back`**, and
there are 11 of those. On this evidence the app's own start path is fine.

**Workaround:** press Home on the tablet (so the app is not the top activity) before Run in
Qt Creator. If "target died" still appears, tap the icon or press Run again. There is nothing
to fix in the app for this.

**Still open, and not seen tonight:** a hang on an ordinary start, away from Qt Creator. The
breadcrumbs stay on `fix/startup-hang` for that. If it is seen, capture `pidof` before the tap,
then `kill -3`.

**Two other findings in the same log, not acted on:**
- **A real native crash this morning:** `07:25:40 Fatal signal 6 (SIGABRT) in tid 11446
  (SerialInputOutp), pid 11097`. `SerialInputOutputManager` is the USB serial library's Java
  reader thread, so an abort on it is most likely a JNI call into our C++ from that thread. On
  a debuggable build `-Xcheck:jni` aborts on JNI misuse. **Wants `adb logcat -d -b crash`** (the
  tombstone summary, if it has not rotated out) and its own session. This is the kind of crash
  a customer with a USB transducer would meet.
- **`DEPENDENCY DIED` at 18:02:11:** Android killed the app (in the background, importance 400)
  because `com.android.externalstorage` died while the app held its provider, most likely from
  a file picked with the system picker. A background app vanishing is normal on Android, but
  the reason is worth knowing: it is a kill, not a crash of ours.

#### The manifest, and what keeps adding the lines

**Qt Creator's manifest editor adds one `splash_screen_drawable` line every time it saves.** The
history shows it one "Version update" commit at a time: 2 → 5 → 6 → 7. It also happened during
this session: the file was rewritten with one new line about a minute after the fix was
committed, while Qt Creator was open. **Seven identical copies are harmless** (Android keeps the
last value) **and are not the hang.** Set the version in the XML source view or in a text
editor, not in the manifest editor's form view, and run `node tools/pulse-manifest-check.js`
after any change to the manifest.

### Session 2, 27 Sept 2026: measured, nothing changed

**No code was changed.** Six `METRICS:` lines, Olav's impressions of each device, and a
read of the three painter files that draw text (`qPlot2D.cpp`, `plot2D_grid.cpp`,
`plot2D_zoom.cpp`, `plot2D_aim.cpp`), `UiMetrics.cpp` and `themes.h`.

#### The numbers

`startup` and `settled` are identical on every device except the emulated tablet, whose
startup line (`320x455` window, `5120x3200` screen) comes from before the landscape resize,
as designed. The table uses `settled`.

| device | device px | logical | dpr | Android density | `s` | `deviceScale_` branch | Olav |
|---|---|---|---|---|---|---|---|
| **Galaxy Tab 10"** (real) | 1920×1200 | 2560×1600 | 0.75 | 1.5 | 1.333 | fractional → 0.75 | generally good; `plot2d_grid` fonts a bit too large |
| **Skydroid G30** (real) | 1920×1200 | 2008×1255 | 0.956 | 1.9125 | 1.046 | fractional → 0.956 | very OK, the most complete UI; ruler tick values a fraction too big |
| **Galaxy Tab Pro 8"** (real) | 1920×1200 | 1920×1200 | 1.0 | 2.0 | 1.000 | integer → 1.0 | fonts generally too small; **insets fail** (below) |
| emulator, 320 dpi tablet | 2560×1600 | 2560×1600 | 1.0 | 2.0 | 1.333 | integer → 1.0 | mostly OK; PULSE black image washed out (below) |
| emulator, 320 dpi phone | 1280×720 | 1280×720 | 1.0 | 2.0 | 0.75 (raw 0.600, CLAMPED) | integer → 1.0 | a bit small everywhere; sub-texts barely readable; grid OK |
| emulator, 420 dpi phone | 2401×1080 | 1829×823 | 1.3125 | 2.625 | 0.75 (raw 0.686, CLAMPED) | fractional → 1.3125 | worse: grid really small, connection screen hard to read, loupe buttons too small |
| **S23 Ultra** (real, FHD+) | 2316×1080 | 1647×768 | 1.40625 | 2.8125 | 0.75 (raw 0.640, CLAMPED) | fractional → 1.40625 | "similar to the 420 phone" |

**The S23 line arrived on 28 Sept** (the first one pasted was the Tab 10" line again). **My
prediction was half right:** fractional branch and `s` 0.75 clamped, as predicted, but the
logical short side is **768**, not 823, and the dpr is **1.40625**, neither of the two values I
gave. The reason: Samsung sets density 2.8125 (450 dpi) at FHD+, which is not a standard Android
bucket, on a panel that is really about **376 ppi**. So a logical unit on the S23 is about 1/267
inch, **20% larger than nominal**, and the phone is still reported hard to read. The mm figures
below use the nominal density for every device, so the S23's real sizes are about 20% larger
than its row shows. None of this changes the conclusion.

**Three facts every line confirms:**

- **dpr = Android density × 0.5** (`QT_SCALE_FACTOR`), on all six. So on Android a
  logical unit is about **1/320 inch** on every device, give or take density bucket rounding
  (the Tab 10" is really 224 dpi against a nominal 240, so its logical units are about 7%
  larger than nominal).
- **`resCoeff` is 1.5 on every device.** It is not the density. `checkResolutionCoeff()` is
  `qBound(0.5, physical/logical dpi × 0.5, 1.5)` and every Android device saturates the
  ceiling. So **`renderScale()` carries no device information** beyond `deviceScale_`.
- **`s` is the logical short side over 1200**, so on Android it is really *physical short side
  ÷ ~3.75 in*. It measures **how big the screen is**, not how dense it is, and the floor at 0.75
  catches both phones.

#### What the branch actually does — P1 read it wrong

`qPlot2D::paint`:

```
deviceScale_ = (qAbs(dpr - qRound(dpr)) > 0.01) ? dpr : 1.0;
const int w = qRound(lw * deviceScale_);        // the canvas
painter->scale(1.0 / deviceScale_, ...);
g_plotRenderExtraScale = deviceScale_;          // renderScale() = resCoeff × deviceScale_
```

**`deviceScale_` is exactly "canvas pixels per logical unit", in both branches.**
Fractional: the canvas is device-sized and `deviceScale_` = dpr. Integer: the canvas is
logical-sized and `deviceScale_` = 1. **The branch is internally consistent.** It is not a
cliff between two coordinate systems. The fault is in the code that draws on the canvas and
does not ask the branch:

| surface | font law | in which units | physical size |
|---|---|---|---|
| `plot2D_aim` crosshair labels | `18 × renderScale()` = 18 × 1.5 × `deviceScale_` | **logical** (converted) | the same on every device, about 2.1 mm |
| `plot2D_grid` ruler ticks | `UiMetrics::fontM()` = 24·`s` | **canvas px, not converted** | ∝ `s / dpr` |
| `plot2D_zoom` v2 loupe (text, rows, buttons, tile) | `fontS`/`fontM`/`px(n)` = n·`s`, `iconTouchSmall` | **canvas px, not converted** | ∝ `s / dpr` |
| every QML control | `Ui.*` = n·`s` | **logical** | ∝ `s` |

**Every integer-branch device in this set has dpr exactly 1.0**, so for them canvas px and
logical units coincide and the branch makes no difference. The only case in which the two
branches would behave differently is dpr 2.0 (density 4.0), which no device here has.

> **Correction, session 3:** the v2 QML is drawn at its own `uiScale`
> (`Math.max(1.0, shortSide / 1100)`), not at `Ui.scale`. The painter columns below are right;
> the QML column is not, for v2. See *Session 3*.

**So the painter's ruler and loupe are drawn at `s / dpr` while QML is drawn at `s`.** In
millimetres, taking the grid's `fontM` and Android's nominal density:

| device | `s / dpr` | ruler / loupe text now | QML `fontM` | aim labels |
|---|---|---|---|---|
| Tab 10" | **1.78** | **3.4 mm** | 2.5 mm | 2.1 mm |
| G30 | 1.09 | 2.1 mm | 2.0 mm | 2.1 mm |
| Tab 8" | 1.00 | 1.9 mm | 1.9 mm | 2.1 mm |
| 320 phone | 0.75 | 1.4 mm | 1.4 mm | 2.1 mm |
| 420 phone | **0.57** | **1.1 mm** | 1.4 mm | 2.1 mm |
| S23 (FHD+) | **0.53** | **1.0 mm** (really ~1.2) | 1.4 mm (really ~1.7) | 2.1 mm |

**This matches every real-device impression.** On the Tab 10" the ruler is drawn 33% larger
than the QML around it: *"a bit too large"*. On the G30 the two nearly agree: *"a fraction too
big"*, and it is the device Olav calls the most complete. The phones get the smallest ruler and
loupe, getting smaller as density rises. **A 4× spread in ruler size between two devices the
app already ships on, from one uncorrected unit.**

**Emulator impressions are sizes on the Mac's screen, not on a phone.** An emulator window
fits the device's pixels to the window, so the 420 phone's 2401 px are shown about 0.53× as
large as the 320 phone's 1280. That is why the 420 emulator looks *worse* than the 320 one
even where the two phones should look identical (QML at `s` 0.75 is 1.4 mm on both). The
ranking agrees with the physics; the magnitudes do not. **The S23 is the real-hardware answer
for phones**, and it says the 420 impression was right.

#### What it means for the two fixes P1 recorded

**P1 framed them as opposites and asked the dpr to choose one. They are not opposites. Both
are needed, for two different defects, and the dpr does not choose between them.**

1. **The painter converts. This is a correctness fix, and it is right on every device
   regardless of branch.** Every `UiMetrics` size that the ruler and the v2 loupe draw on the
   canvas is multiplied by `deviceScale_` (i.e. `g_plotRenderExtraScale`), exactly as
   `plot2D_aim` already does through `renderScale()`. Afterwards the painter is drawn at `s`,
   like QML. What that does per device:
   - Tab 10": ruler 3.4 → 2.5 mm, **25% smaller**, which is the direction Olav asked for.
   - G30: 2.1 → 2.0 mm, **unchanged within 5%**. His best device stays as it is.
   - Tab 8", 320 phone, emulated tablet: **byte-identical** (dpr 1).
   - 420 phone +31%, S23 +41% (× 1.40625).
   - The loupe's tile, rows and buttons follow the same law, so `bf80ab02`'s fit clamp keeps
     working unchanged (it measures in the same canvas pixels it draws in).

   **One correction to what I wrote at the start of this session:** I suggested normalising to
   the tablet (× dpr / 0.75) so the tablet would not move. Olav's report says the tablet's ruler
   *should* move, so plain `× deviceScale_` is right and there is nothing to normalise.

2. **The base scale. This is a design fix, and it is what is left after (1).** Once (1) is in,
   everything the app draws is proportional to `s`, and `s` is proportional to screen size. So
   on a smaller screen *everything* is smaller in millimetres, which is exactly Olav's *"should
   increase fonts all over a bit"* and the Tab 8"'s *"fonts generally too small"*. What the real
   devices say about the target:
   - `s` 1.333 (Tab 10") — QML *generally good*.
   - `s` 1.046 (G30) — *very OK*.
   - `s` 1.000 (Tab 8") — *too small*.
   - `s` 0.75 (phones) — too small; the S23 is hard to read.

   So **the floor of 0.75 is too low, and the proportional slope is too steep below a
   ~7–8" screen.** Because an Android logical unit is already close to physical, the natural
   shape is a base scale that stops shrinking with the screen (a higher floor, or a flatter
   curve below the reference), not one that looks at the density. Choosing the numbers is
   session 3's job.

**P1's warning still holds, in a narrower form: do not use `scale()` to fix the painter.**
`scale()` feeds every QML control, so raising it to make the ruler legible on a phone would
inflate the whole UI. (1) is done in the painter; (2) is done in `computeScale()`.

**Order for session 3: (1) first, then (2).** (1) is mechanical, and on the three dpr-1 devices
the effect is nil, so any change seen there after (1) is a bug. (2) then has one law to tune
instead of two. After (2), the phones' height (720–823 logical) is further over the rail's
budget (915–983 u) than it is today. That is session 4's scrollable rail, and it is the reason
(2) goes after `bf80ab02` and before session 4.

**The branch itself** is harmless in this set and should stay until a dpr 2.0 device can be
measured. If a density-4.0 phone ever turns up, its canvas is logical-sized and upscaled by Qt,
so the risk there is sharpness, not size.

#### Confirmed on hardware — the S23 screenshot, 28 Sept (the first input for session 3)

Olav sent an S23 screenshot of a paused side scan with the loupe open (2316×1080, saved at
2000×932): *"Compared to the overall screen size the box seems to occupy less space overall on
the screen than the 320 DPI device. And the grid ruler up is also offered with very small
fonts. Making this more of a problem with 420 DPI than 320 DPI, no matter emulator use."*

**The pixels match the arithmetic.** The loupe's tile measures about 207 px in the screenshot,
which is **240 device px**. That is exactly `boxSizePx` 320 × `s` 0.75, drawn in device pixels
and not converted. The ruler labels are the grid's `fontM` 18 as **device** px.

- **On the 320 phone** (dpr 1) that tile is 240 of 720 px: **33% of the screen height**.
- **On the S23** (dpr 1.40625) it is 240 of 1080 px: **22%**. The ratio between the two is
  1 / dpr, which is the unconverted unit and nothing else.
- **After fix 1** the S23's tile becomes 240 × 1.40625 = 337 device px, **31%** of the height,
  the same share as on the 320 phone. The ruler and the loupe text grow by the same factor.

**So this is fix 1 observed on real hardware, not on an emulator**, and it settles what the
emulator caveat above left open: denser phones really are worse today. The QML parts of the
same screenshot (the rail's Resume label, the paused gutter, the PAUSED title) are not
visibly smaller than on the 320 phone, which is also what the model predicts: QML is drawn at
`s` on both.

#### Found on the way, for later sessions

- **Galaxy Tab Pro 8": the dual side scan ruler is drawn under the Android system bar.** The
  only device with it. Session 1 already noted that `notifyInsets_native` posts to `qApp` before
  `main()` has built it, **so the first insets are always dropped**. That is the first thing to
  check. **Session 4** (layout).
- **Emulated 320 dpi tablet: the PULSE black card's image looks washed out** next to red and
  blue in the same screenshot. It could be the image asset or a dimmed state. **Session 4.**
- **Loupe, from the 320 phone:** *"Add waypoint"* may not fit its button. Olav suggests
  *"Add WP"*. The buttons are small. **Session 3**, with (1) and (2).
- **`computeScale()`'s comment** names a 1280×800 reference and the code uses 1200. Its
  `maxScale` of 1.35 is not reached by any device here (1.333 is the largest).
- **`resCoeff` is a constant 1.5 on Android**, so `renderScale()`, and anything in classic that
  reads `theme.resCoeff`, has never adapted to a device. Not a v2 problem.

### Session 3, 28 Sept 2026: `feature/pulse-small-screens`, off master

`fix/startup-hang` was merged into master by fast-forward (master = `4637f187`, which is the
session 2 backlog commit), and the branch was cut from there. **Not compiled.** The shell has
no Qt. C++ in `themes.h`, `UiMetrics.{h,cpp}` (a new `Q_PROPERTY`, so `moc` re-runs),
`plot2D_grid.cpp`, `plot2D_zoom.cpp` and `qPlot2D.cpp`, plus QML.

| commit | what |
|---|---|
| `f7e97415` | **fix 1**: the ruler and the v2 loupe are drawn in logical units, like the QML around them |
| `3c5b6408` | **fix 2**: the base scale's floor goes from 0.75 to 1.0, and an **Interface size** setting for everybody |

Olav's choices, 28 Sept: **floor 1.0 plus a size setting**, and **keep "Add waypoint"**
(change it only if it clips on a device).

#### A correction to session 2, found while building fix 2

**The v2 QML does not use `Ui.scale`.** Session 2's "QML is drawn at `s`" was wrong for v2.
`mainview.s` and `PulseAppV2.s` are `Math.max(1.0, shortSide / 1100)`, a second law with a
floor of 1.0 and no ceiling. Every rail, panel, connection screen and overlay size comes from
it. `Ui.*` (`UiMetrics`) is read by the painter and by classic's settings components only.
So the v2 controls on the phones were **already at 1.0**, not at 0.75:

| device | v2 QML `uiScale` | `Ui.scale` before | `Ui.scale` after fix 2 |
|---|---|---|---|
| Tab 10" | 1.45 | 1.333 | 1.333 |
| G30 | 1.14 | 1.046 | 1.046 |
| Tab 8" | 1.09 | 1.000 | 1.000 |
| phones (320, 420, S23) | 1.00 | 0.75 | **1.00** |

What this changes and what it does not:

- **Fix 1 stands as it was.** The painter was at `s / dpr`, and after fix 1 it is at `Ui.scale`,
  in logical units like the controls.
- **Fix 2 is now what makes the painter agree with the controls on a phone.** After it, the
  ruler and the loupe are at 1.0 there, the same as the rail. On the tablets they are about 8%
  below the controls (1.333 against 1.45). That is left as it is: Olav wanted the tablet's
  ruler smaller, and the two laws are a merge for another day (below).
- **The phones' "a bit small everywhere" is not the floor.** Their v2 controls were at 1.0
  already, and 1.0 is the reference. **That is what the Interface size setting is for**,
  and it is why the setting multiplies both laws.
- The mm column for QML in session 2's table used the wrong law for v2. The painter columns
  are right.

#### Fix 1 — `f7e97415`

- **`plotCanvasScale()`** in `themes.h`: canvas pixels per logical unit while
  `qPlot2D::paint` runs (`g_plotRenderExtraScale`, i.e. `deviceScale_`). Its comment carries
  the measurement.
- **`plot2D_grid`**: the font (`Ui.fontM × cs`) and every size in the label layout
  (`textXOffset`, `textYOffset`, the label margin, the backdrop margins, the fixed line
  length) go through `cpx()`. `sp()` is left as it is, because it is already a dp law.
- **`Plot2DZoom::drawV2`**: one factor for the whole panel. `s = Ui.scale × cs`, and the
  fonts are `fpx(Ui.fontX)`. Tile, rows, buttons, crosshair, corners and fonts all follow.
  **The fit clamp is untouched**, because it measures in the canvas pixels it draws in.
- **Classic's loupe (`Plot2DZoom::draw`) is left as it shipped.** The grid is shared, so
  classic's ruler changes too, and that is a correction for classic as well.
- **`METRICS: plot canvas | dpr … -> … canvas px per logical unit (… branch)`**, once per
  change, from `qPlot2D::paint`.

#### Fix 2 — `3c5b6408`

- **`UiMetrics::computeScale()`**: `minScale` 1.0 (was 0.75), `maxScale` 1.35 kept, and the
  result multiplied by **`Ui.userScale`** *after* the clamp, so "larger" is larger on every
  device, the floor included.
- **`Ui.userScale`** (`Q_PROPERTY`, bounded 0.8–1.5). Its one writer is a `Binding` in
  `main.qml` on **`pulseSettings.interfaceSize`** (percent, persisted, default 100).
- **`mainview.s` and `PulseAppV2.s` are multiplied by `Ui.userScale`** too, so one setting moves
  the controls, the ruler and the loupe together.
- **Interface size** is the first row of **Screen & echogram**, for everybody: Small 90 /
  Normal 100 / Large 115 / Larger 130. Olav's own case for it: the G30 and the Tab 8" sit at
  almost the same scale and were judged "very OK" and "too small". No single curve serves
  both, so the person reading the screen chooses.
- **`Plot2D.qml` repaints on `Ui.metricsChanged`**, so a paused picture follows the setting at
  once.
- **`METRICS:`** now also prints `interface size` and `uiScale`, and marks CLAMPED against the
  new floor.

#### What the numbers should be after this build, at Normal

Ruler text, nominal mm (`Ui.fontM` = 24 × `Ui.scale`, now in logical units):

| device | before | after | change |
|---|---|---|---|
| Tab 10" | 3.4 mm | 2.5 mm | −25% (fix 1) |
| G30 | 2.1 mm | 2.0 mm | −4% (fix 1) |
| Tab 8", emulated tablet | 1.9 mm / 2.5 mm | same | none |
| 320 phone | 1.4 mm | 1.9 mm | +33% (fix 2) |
| 420 phone | 1.1 mm | 1.9 mm | +75% (both) |
| S23 | 1.0 mm (really ~1.2) | 1.9 mm (really ~2.3) | **×1.875** (both) |

The loupe's tile follows the same law: on the S23 it wants 320 × 1.0 × 1.406 = **450 device
px** full screen, about **42%** of the height. In a split the fit clamp shrinks the tile and
keeps the buttons.

#### To check on the device

1. **The two log lines.** `METRICS: plot canvas | dpr 1.40625 -> 1.40625 … (fractional
   branch)` on the S23, `dpr 1 -> 1 … (integer branch)` on a dpr-1 device. `METRICS: settled`
   on a phone reads `-> s 1 (CLAMPED) | interface size 1 | uiScale 1`.
2. **Tab 8" and the emulated tablet at Normal: nothing moves.** Both have dpr 1 and `s` ≥ 1.
   Any change there is a bug in this build.
3. **Tab 10": the ruler about a quarter smaller**, the loupe the same. **G30: no visible
   change.**
4. **S23: ruler and loupe clearly larger**, the loupe about 42% of the height full screen. The
   **Add waypoint** button must not clip. If it does, that is the trigger for the shorter
   label.
5. **A split on the S23, paused, loupe open:** the buttons stay on the pane, and only the tile
   shrinks.
6. **Interface size:** each step moves the rail, the panel, the connection screen, the ruler and
   the loupe together, **with the echogram paused as well**. It must survive a restart.
7. **Larger on a phone** may push the rail past its height budget. That is **session 4's**
   scrollable rail, not a regression: at Normal the rail is unchanged.
8. **Classic on a phone:** its `Ui.*` rows are a third bigger (the floor). That is expected.

#### Device report on session 3, 28 Sept — **VERIFIED on all five devices**

Olav: *"Visual inspection on all 5 devices: Result is now good."*

- **The loupe on the small (320 dpi) phone, in `split_side_down` only:** most of the "A" and the
  "t" of *Add waypoint* are cut off, because the pane is short. It is fine in the down scan
  and in the side scan + mosaic layouts. Olav: *"This is something I can live with."* The label
  stays as it is.
- **Asked for later, a design question rather than a bug:** *"Is the decision to show side and
  down split horizontally the best way to fix dual screens?"* The clipped label is the evidence:
  a side-above-down split halves the height, and on a landscape phone height is what there is
  least of. The alternatives worth weighing when it comes up are a side-by-side (vertical)
  split, and letting the split direction follow the pane's aspect ratio. Belongs with session
  4's layout work or after it. **Not started.**

#### Left for later, deliberately

- **Two base-scale laws.** `UiMetrics` is short side / 1200 clamped to 1.0–1.35, and v2's
  `uiScale` is short side / 1100 floored at 1.0. They agree on phones and are 8% apart on
  tablets. Merging them into one (`UiMetrics` taking v2's law, and the ~20 files that each
  compute their own `s` reading `Ui.scale`) is a tidy-up with classic in its blast radius. It is
  its own commit when classic's settings are next touched.
- **`resCoeff` is a constant 1.5 on Android**, so `renderScale()` never adapts (session 2).
  The aim's crosshair labels are drawn at 27 logical px everywhere and do not follow Interface
  size. They are small and fixed, so they are left as they are.

### Session 4, 28 Sept 2026: insets, the scrolling rail, the tab, the brand — `feature/pulse-small-screens`

**Not compiled.** C++ in `InsetsHelper.h`, `android_init.cpp`, `main.cpp`, `plot2D_grid.{h,cpp}`
(no new `Q_PROPERTY` or `Q_INVOKABLE`, so no `moc` round is forced), QML, one new image in
`images.qrc`.

| commit | what |
|---|---|
| `4c919e0e` | the insets: none dropped before `main()`, and QML reads them in logical units |
| `dcc7850a` | the v2 panes stop at the system bars (bottom, right, and left when nothing covers it) |
| `aa480398` | the rail scrolls below its three setters; the expand tab moves to the foot; the mark replaces the wordmark |
| `8eef7a03` | the wordmark at the foot of the panel, horizontally |

**Olav's decisions, 28 Sept:** Pause and Record scroll. The expand tab stays in the rail (no tab
on the echogram); he will judge the 320 phone himself. The G30 report was the **bottom** button
bar (not a side bar).

#### The two inset faults

- **Dropped.** The first insets arrive from `onCreate`/`onResume` before Qt starts `main()`, so
  `notifyInsets_native` queued them onto a null `qApp`. The JNI side now always records them in
  `InsetsHelper` (atomics, not the QObject) and `main()` applies them. **This is the likely cause of
  the G30's clipped PAUSED**: the gutter already placed it at `safeBottom + 16`, and a PAUSED that
  sinks under the bar means `safeBottom` read 0.
- **Units.** `InsetsHelper` carries device px; every QML reader used them as logical units. A 48 dp
  bar is 96 logical on every Android device (dpr = density × 0.5). The raw value was 72 on the
  Tab 10", 92 on the G30, 135 on the S23. `main.qml` and `PulseAppV2` convert in their accessors;
  `plot2D_grid` keeps px because it draws in device coordinates. **Classic is not touched.**

#### The panes own the insets (v2)

`visualisationLayout.paneOwnsInsets`: both panes end at the bottom and right bars, and at the
left one when no rail or side gutter already covers it. Nothing inside a pane has to know about
bars any more: the loupe's fit clamp keeps Dismiss / Add waypoint above the bar with no change,
`PulseAppV2`'s bottom/left/right insets are 0, `plot2D_grid` drops its own subtraction when
`uiVariantIsV2`, and the 2D foot gutter's margin takes only its height above the bar. The top
stays full-bleed.

#### The rail

- **HEAD** (range, intensity, filter) and **FOOT** (Hide the rail) are pinned; the **BODY**
  (colours, cone/screen, pause, record, source, settings) is a Flickable that is interactive only
  when it overflows. The cue is a fade + Canvas chevron drawn **over** the edge that has more,
  tappable to scroll ¾ of the body. When it fits, the tablet layout is unchanged.
- **The expand tab** sits exactly where Hide the rail was, at the foot, 60 u tall like the button.
- **The mark**: `image/pulse_brand_mark.png`, made from `logo_icon.png` (the smooth original,
  not the dithered recolour): alpha from the blue, white fill, wordmark cropped off, 256 px. Above
  the foot, 40 u, opacity 0.45, and **absent whenever the body would otherwise have to scroll**.
- **The wordmark** moved to the panel's Flickable: at the panel's foot when the group is short,
  after the last row when it is long.

#### To check on the device

1. `INSETS: at startup …` and `INSETS: applied the insets held from before main()` in the log.
   **The G30 is the test**: PAUSED fully visible, and the loupe's two buttons above the button bar.
2. **Tab 10" and S23**: every inset-aware surface moves slightly: the connection screen, the pills and
   the paused gutter get about a third more room on the Tab 10" and about 30% less on the S23. That is
   the unit fix. Nothing may end up under a bar.
3. **Ruler**: the lowest labels on a 2D picture are above the bar, not clipped.
4. **Rail on the 320 phone, Normal**: probably just scrolls (the estimate says about one button).
   The chevron shows on the side with more; tap scrolls; the three setters never move. **Larger** on
   any phone: same. Tablet at Normal: no scrolling, the mark above Hide the rail.
5. **Collapse and expand** with Pulse as the right-hand app in split screen: the tab is at the
   foot and no longer meets the divider handle.
6. **Panel**: the wordmark at the foot of a short group (Intensity), after the list in Settings.
7. **Classic** must be exactly as before.

#### Left open

- **The Tab Pro 8" ruler under the system bar** is probably one of these two faults. Check on the
  next build before touching anything else.
- **Gesture-navigation devices** now lose their thin bottom inset (~16–24 dp) from the echogram too.
  If that is too much, Java can pass `tappableElement` separately so only a button bar is taken.
- Snap-to-half-a-button was not built; the fade and chevron are the cue.

#### Device report on session 4, 28 Sept, and `86abfc09`

**Good on the device:** the scrolling rail, the tab at the foot, the panel wordmark. On the phone the
mark never shows, which is the rule working (the body needs every unit).

**Reverted in part: the panes no longer stop at the bottom and right bars.** Olav, phone with the
button bar on the right: *"we waste valuable space ... it is also not a pure edge to edge look.
There is rarely any need to press at the right hand side."* The echogram runs under the bars again.
What is read or tapped steps inside instead:

- **`Plot2D::systemBarOverlap()`**, measured in `qPlot2D::paint` every frame: how much of *this*
  pane lies under the left/right/bottom bars, in canvas px (`mapToScene` against the window less the
  insets). Zero for a pane that does not reach a bar.
- **The v2 loupe** fits and places itself in the viewport less that overlap, so the **tile shrinks**
  (the `bf80ab02` rule) and the buttons stay above a bottom bar / left of a right one.
- **`plot2D_grid`** uses the same overlap in v2, not the screen insets, so a split's upper pane
  keeps its bottom labels.
- `PulseAppV2`'s bottom/right insets are real again. **The left is kept from `dcc7850a`**: with no
  rail or side gutter on that edge the panes start after a left-hand bar.

**The G30 photo was open on one question (ANSWERED, below: the inset was right, the photo predated `86abfc09`).** The loupe's buttons sat on the taskbar (the dock
with the app icons and the back button), and the pane in that photo seemed to run to the screen
bottom even on the `dcc7850a` build. That would fit if **the reported bottom inset is smaller than
the visible taskbar**: Android reports a *transient* taskbar as a thin handle only. The pulse.log
lines decide it: `INSETS: at startup … px -> logical …` and `INSETS: pane WxH logical lies under the
bars by l r b`. If the bottom reads 0 or about 16–24 dp while the dock is about 48–60 dp, the fix is
on the Java side (read the taskbar's height), not in the loupe.

#### VERIFIED on the G30 and the 320 phone, 28 Sept — session 4 is closed

Olav: *"For me this is great!"* The loupe stays above the G30's bottom bar and clear of the phone's
right-hand bar, every button is reachable, and the crosshair can still be moved into the covered
areas, so the whole screen is used.

**The log answers the open question, and confirms the startup diagnosis:**

```
I/default : INSETS: 0 46 0 115 (l t r b, device px) held until the application exists
I/default : INSETS: applied the insets held from before main() - 0 46 0 115
D/qml     : INSETS: at startup l t r b 0 46 0 115 px -> logical 0 48 0 120 | dpr 0.95625
D/default : INSETS: pane 1921x627 logical lies under the bars by l 0 r 0 b 115 canvas px
```

- **The first insets really were arriving before `main()`**, and until `4c919e0e` they were lost.
  That was the G30's clipped PAUSED.
- **115 px is the full taskbar** (60 dp at density 1.9125), so the insets were never under-reported
  on the G30. The earlier photo came from before `86abfc09`. The Java side needs nothing.
- The unit conversion is right: 115 px → 120 logical at dpr 0.956.
- `pane 1921x627 … b 115`: the lower pane of the split, overlapped by exactly the bar.
- **`pane 58x58 … b 95`** is a small `Plot2D` (a preview), not an echogram pane. Harmless; noted
  so the line is not mistaken for a fault later.

### Session 5, redefined by Olav, 28 Sept: the mosaic is offered when none can be made

**The mosaic works on every device.** Olav: *"the UI part is good, it is the option to even
select the mosaic when none can be made that is the problem. Likely I was fooled by this. There
were never a UI error here."* So the phone finding under P1 (item 1, *"no mosaic at all on the
phone"*) was a **file without positions**, not a phone fault. The `MOSAIC:` instrument
(`262be7fe`) is no longer needed to answer it.

**Why testers ask "why is the mosaic not working".** `view3dToggleAvailable` is

```
!pulseRuntimeSettings.is2DTransducer
&& (pulseRuntimeSettings.mavlinkDetected || (core.filePath && core.filePath.length > 0))
```

**It never asks whether the recording carries a position or a heading.** Any opened file
passes the second term, and `mavlinkDetected` is sticky, so one file with MAVLink makes every
later source "available". When it is not really available, `has2DView`'s fallback puts an
echogram on screen instead, with the chooser row still marked, and that looks like a broken
mosaic.

#### What Olav asked for

1. **When the source (a demo, an opened file or a streamed file) has no position AND yaw,
   the mosaic layouts are shown but cannot be chosen.** That is the cone chooser's treatment
   under a recording (`2cf5c267`): the rows stay visible, drop to 0.45 opacity, take no taps,
   and a note above them says why.
2. **The stored preference is NOT rewritten. The picture falls back, and the preference
   waits.** Olav, 28 Sept, correcting the first reading: *"Today, if current preference is
   mosaic with either down or side, down or side already becomes full screen. Then the mosaic
   can appear when available. We need not change this part, but we do need to ensure that we
   check for position data and 'close' the mosaic pane when it has no possible use."*
   - `split_down_mosaic` → **down** full screen, and `split_side_mosaic` → **side** full screen.
     This is `has2DView`'s existing fallback, and it stays as it is.
   - **`single_mosaic` → side scan alone.** Olav: *"If Mosaic alone is the current preference,
     and no position data is available, revert to side scan alone."* **This is the one
     behaviour change in the layout.** Today `firstMode` is `""` there, so `applyEchogramMode`
     is never called and the outgoing picture simply stays.
   - The mosaic comes back **on its own** when a source with positions arrives, because the
     preference was never touched.
   - **So the real fault is the availability test**, which says "available" for a file with no
     positions. That is what keeps the mosaic pane open when it has no possible use.
3. **The Pause button's green dot must go out** when a file without positions follows one with
   them. Today it stays green.

#### Notes for whoever builds it

- **One fact, two consumers.** *"This source can make a mosaic"* is: a side scan display model
  AND positions AND yaw. The green dot is the positions half of the same fact. Both belong on
  one property, so the dot and the chooser cannot disagree.
- **The raw material exists.** `Dataset::probeMosaicEpochs()` already reports `posFinite` and
  `yawFinite` per epoch. The file-side prescan (`ea5cf3d3`) and `demoPrescan` already read ahead
  of rendering, so they are the natural place to answer the question before the first frame.
- **`is2DTransducer` is the committed device.** Every other screen question reads the display
  model (`displayIs2DTransducer`), so that term moves too.
- **The dot's sticky source.** For an opened or streamed file it reads `dataset.hasPositionData`,
  which is cleared only by `Dataset::resetRenderBuffers()` (`resetDataAvailability`). The first
  thing to check is whether that runs between two files on every path: open, stream, demo and
  a demo swap. The prediction is that one of them does not reset it.
- **Both questions are answered** (28 Sept, above): `single_mosaic` falls back to side alone,
  and the preference is never rewritten.

### Session 5, built 28 Sept 2026 — `83cf8e7a`, not compiled

C++ in `dataset.{h,cpp}` (a new `Q_PROPERTY`, so `moc` re-runs), QML in `main.qml`,
`PulsePanel.qml`, `PulseScreenGroup.qml`.

- **`Dataset::hasYawData`**: a heading from the AHRS yaw (`addAtt`) or from the track
  (`addArtificalYaw`, only reached when two positions differ). Reset with the other flags in
  `resetDataAvailability`, so it answers for the current source.
- **`mainview.mosaicPossible`** = display side scan && `hasPositionData` && `hasYawData`, the three
  things `MosaicProcessor` needs to place an epoch. `view3dToggleAvailable` now reads it, so the
  pane and the chooser cannot disagree.
- **The chooser**: mosaic rows at 0.45, no taps, and an amber note. A mosaic row that is the
  current preference keeps its mark.
- **The preference is never written.** Side + mosaic / Down + mosaic fall back as before. **Mosaic
  alone now falls back to side scan alone** (`applyScreenId`, and again when `mosaicPossible` goes
  false).
- **The dot**: an opened file reads the same `hasPositionData`. A feed's dot goes out at once when
  a new source clears positions. The fault was predicted in the notes and found: `resetDataset()`
  ends by emitting `lastPositionChanged` with the old boat coordinate still valid, which relit the
  dot for three seconds on a source with no positions.

#### To check on the device

1. **A file with no positions, after one with them** (open and stream both): the dot goes out,
   `MOSAIC: not possible | positions false …`, and the Screen panel shows the three mosaic rows
   dimmed, untappable, with the note.
2. **Mosaic alone stored, then that file**: side scan alone comes up, not the previous picture.
   Open a file with positions: the mosaic appears by itself (`MOSAIC: possible`).
3. **Side + mosaic / Down + mosaic stored**: side / down full screen without positions, the split
   back with them. The stored layout never changes (the mark stays on the row).
4. **A demo with positions**: the mosaic arrives once the first fix and heading do. **Watch the
   loop boundary**: the dataset is reset there, so the mosaic may drop out for a moment. If that
   flickers badly, the answer is to take availability from the demo prescan instead.
5. **A live blue on the boat**: the mosaic is offered from the first fix **and once the boat
   moves**, if the autopilot sends no yaw (the track heading needs two different positions). A
   moored boat with no AHRS yaw is correctly "not possible".
6. **A red**: no Screen button, as before.

### Session 5 follow-up: the mosaic view, 28 Sept 2026 — `38a2f662`, not compiled

**Session 5 verified by Olav:** the mosaic rows stay marked on a file with no positions or heading, the
mosaic comes back on a file with positions, and the green dot now follows the source. A demo run to
the end had positions all through, so there was no flicker at the loop.

**His mosaic list, items 1-4, built** (C++ only: `core.cpp`, `data_processor.cpp`,
`boat_track.cpp`, `navigation_arrow.{h,cpp}`, `scene3d_renderer.cpp`; no `moc` change):

1. **Old tiles on a demo loop** ("some remains stay on the map ... eliminated in two turns the first 5+
   seconds"). **3. The blue scan line frozen at the end-of-file position.** One cause: the old pass's
   results arrived after `GraphicsScene3dView::clear()`. `clearProcessing` only requests a cancel, a
   running mosaic job still posts, and the queued connections into `SurfaceView` are never dropped. A
   late trace line carries an end-of-file epoch, and `setTraceLines` refuses any lower index, so the
   stale line froze for most of the next pass. `resetRealtimeSessionState` now: waits for the worker
   (`prepareForFileClose`, 1500 ms), clears, **delivers** what is still queued for `SurfaceView`, then
   clears the surface once more. `postTraceLines` has the `suppressResults_` gate `postSurfaceTiles`
   had. **The scan line is kept**, as Olav preferred ("either we make it always appear or it will have
   to go").
2. **The purple driven path is not drawn at all.** It only had a switch on the hidden 3D toolbar, and
   at width 6 through `glLineWidth` (clamped to 1 px on most drivers) it came and went. The data and the
   red selected-epoch point stay.
4. **The boat**: 5 px per model unit instead of 7 (35 px desktop / 70 px Android, was 49 / 98), with a
   **white 2 px ring** drawn as geometry (a mitred outward offset of the cursor), with the depth test
   off for the ring only.

**To check:** loop a demo with positions. The map must be empty at the start of the new pass: no tiles
from the last one, and the blue line moving from the first new ping. No purple line ever. The boat is
visibly smaller with a white edge on the golden mosaic and on the map. **Watch the loop pause:** the
worker wait is bounded at 1.5 s, and it only happens if a mosaic job is running.

**VERIFIED by Olav, 28 Sept:** the leftover tiles are gone, the purple path is gone, the scan line
behaves predictably, and the boat icon is "much better".

### Wipe and Pause, and the nadir fill off by default — 28 Sept 2026, not compiled

| commit | what |
|---|---|
| `a8996372` | **the nadir fill is OFF by default.** Olav: better that the first version ships with the slight open area along the track than with the current fill. The expert row turns it on; it goes back on when it works |
| `82296a2b` | **Wipe and Pause / Resume** on the mosaic |

**How it works.** `MosaicMask` (new, `src/data_processor/mosaic_mask.{h,cpp}`, in `CMakeLists.txt`)
keeps the user's choice as **epoch ranges**: a wipe excludes everything before now, and a pause excludes
from the pause until the resume. `MosaicProcessor::updateData` refuses masked epochs on every path. That
matters because tiles are rebuilt from the dataset whenever the view needs them again, so a plain clear
would bring a wiped area back. **While paused the blue scan line still follows the boat.** A new source
resets the mask (`resetRealtimeSessionState`). `Core::mosaicWipe()` masks up to now and runs the 3D
toolbar's existing reset-processing path (mosaic, surface and isobaths plus their caches; **the bottom
track is untouched**), then clears the render. `Core::mosaicSetPaused(bool)` and `core.mosaicPaused`.

**The pill** (`PulseMosaicPill.qml`) sits at the top centre of the mosaic pane, only while the mosaic is
shown. **Wipe asks once**: the first tap shows "Tap to wipe" for 3 s, and only a second tap wipes. Pause
turns the pill amber and it reads "Mosaic paused".

#### To check

1. Demo or live with positions, mosaic on screen: **Wipe**, tap twice. The map empties, and the
   mosaic carries on painting from the boat's position onward. `MOSAIC: wiped - wiped before N …`.
2. **Zoom and pan after a wipe**, and use the mosaic update action if there is one to hand: **the wiped
   area must not come back.** That is what the mask is for.
3. **Pause** before a turn, **Resume** after it: nothing is painted in between, and the blue line keeps
   moving with the boat throughout. The pill is amber while paused.
4. **Wipe while paused**: the map empties and it stays paused.
5. **A demo loop or a new file** resets both (`MOSAIC: the wipe and pause are reset - a new source`), and
   the pill is back to "Mosaic".
6. **The risk to watch:** after a wipe the pipeline reset also closes the tile database. If the mosaic
   does **not** resume painting after a wipe, that is where to look (`resetProcessingPipeline`,
   `closeDB`), and the fallback is to clear only the mosaic's own caches.

**Not built, offered:** an **automatic pause on a turn**, from the yaw rate, is the hands-free version
for autopilot passes. It fits into the same mask as one more rule in `excludes()`.

#### Device report, and `9aea3203` + `f853bae8`

- **`9aea3203`**: moc refused a `Q_PROPERTY` placed among the `Q_INVOKABLE`s in `core.h`
  (`Parse error at ";"`). It moved to the top of the class. **moc now runs in the cloud shell**
  (`/usr/lib/qt6/libexec/moc`, Qt 6.4, from apt `qt6-base-dev-tools`), so a changed header can be
  checked before a build; `qt6-base-dev` gives QtCore headers for `-fsyntax-only` on plain files.
- **Pause works "great". Wipe is withdrawn** from the pill: Olav, *"The wipe is unpredictable, I
  struggled to get the rendering back."* `Core::mosaicWipe` and `MosaicMask::wipe` stay, for the
  expert mosaic testing (session 9); restoring it is the pill Repeater's model. The likely suspect is
  `resetProcessingPipeline` closing the tile database, which the check list above named as the risk.
- **Side scan TVG release defaults** (runtime, so every start; the C++ constants agree): noise floor
  subtraction **0.0** (was 0.1), spreading **7.5** (was 5), absorption **0.0**, reference range **10**
  (was 15), detail boost **0.9** (was 1.2). No stored value exists for any of them, so every user gets
  these from the first start of this build.

### Mosaic, the later list (session 9)

- **(a) Wipe and pause — BUILT 28 Sept (`82296a2b`), see above.** The design as first written: Olav: *"If I could wipe, start, pause then
  the resulting render could become amazing"*, and a 90° turn now smears about 35 m each side. **A
  plain clear is not enough**, because the mosaic re-traces from the dataset's epochs, so a wiped area
  would come back on the next re-trace. The shape that holds is **an epoch mask in `MosaicProcessor`**:
  - **Wipe** = exclude every epoch before now.
  - **Pause** = exclude from the pause until the resume.
  - Both survive a re-trace and a range change, because they are data and not pixels.
  - **The UI:** a pill on the mosaic pane, shown only while the mosaic is: *Wipe · Pause / Resume*.
  - **Worth offering too:** an **automatic pause on a turn**, from the yaw rate (a threshold of some
    degrees per second, with the mosaic resuming once the heading has settled). With the autopilot
    doing passes, that is the version that needs no hands.
- **(b) The nadir fill** (`5295580d`) is not very successful. It needs a proper look with the
  expert rows and the A/B against fill off.
- **(c) Accuracy.** Olav's two recordings: his own boat (no RTK, poor yaw) moves a feature a lot
  between opposite passes; a boat with a tuned yaw and an M10 still moves it about 1.5 m, where he
  expected about 0.5 m. RTK and a GNSS heading are the real cure, and he will tell users so. **Still to
  rule out on our side:** the transducer's lever arm and mounting offset, the time alignment between a
  ping and its position (a lag moves features along the track in opposite directions on opposite
  passes, which is exactly this signature), the slant-range and sound-speed assumptions, and the
  interpolation of yaw between fixes. **The opposite-pass test is the right instrument**: a shift
  ALONG the track means a latency; a shift ACROSS it means a heading or an offset.
- **(d) KMZ export.** Users will ask for it. The tiles are already georeferenced, so a KMZ of
  `GroundOverlay`s (one per tile, or the mosaic resampled onto one image) is the natural format.

### STATUS AT CLOSE, 28 Sept 2026 (evening)

- **Branch `feature/pulse-small-screens`**, 23 commits ahead of `master`, **NOT PUSHED** (no
  `origin/feature/pulse-small-screens`). `master` is 7 ahead of `origin/master`. Push both from GitHub
  Desktop.
- **Verified on a device today:** session 3 (five devices), session 4 (G30, 320 phone), session 5,
  the mosaic view fixes 1-4, Pause.
- **Built, not yet seen on a device:** `f853bae8` (Pause only, the TVG release defaults) and the moc fix
  `9aea3203`. Nadir fill off by default (`a8996372`) was in the build Olav ran.

### Session 6, the breakdown — FINISH THE UI

In this order. 6a is checks only and should be run first on the next build. 6b-6d are the real work.

- **6a. Checks owed from today (no code unless one fails).**
  - The TVG release defaults are live: Expert → side scan TVG reads 0 / 7.5 / 0 / 10 / 0.9 on a fresh start.
  - The mosaic pill shows **Pause only**.
  - **Galaxy Tab Pro 8": is the dual side scan ruler still under the system bar?** It was probably
    one of the two inset faults fixed in `4c919e0e`. Read the `INSETS:` lines.
  - **The PULSE black card looked washed out** on the emulated 320 dpi tablet (session 2 finding).
    Asset or a dimmed state; look at it on a real device first.
- **6b. The split-pane walk (Group E's remainder).** Every surface that takes width or height from a pane,
  walked in each split (side + down, side + mosaic, down + mosaic), on a tablet and on the 320 phone:
  the rail, the panel, the setup card, the paused gutter, the depth readout and speed gauge, the pills
  (demo/file pill against the mosaic pill), the connection screen over a split. Fix what overlaps or clips.
  **Known and accepted:** the loupe's *Add waypoint* clips on the 320 phone in side + down.
- **6c. The split direction.** Olav, 28 Sept: *"Is the decision to show side and down split horizontally the
  best way to fix dual screens?"* On a landscape phone height is what there is least of. Options: a
  side-by-side split, or a split that follows the pane's aspect ratio. **A decision for Olav first**:
  draw the options, then build the one he picks. It goes before 6b's fixes if it changes the layout.
- **6d. The compact connection screen.** The connection screen on the 320 phone and in a narrow split:
  cards, the three source rows (Start a simulation / Stream a file / Open a file), the link strip. Make it
  fit without scrolling where it can, and scroll cleanly where it cannot.
- **6e. Small UI leftovers**, as time allows:
  - Gesture-navigation devices give up their thin bottom inset from the loupe's room. Keep, or have the
    Java side pass `tappableElement` separately.
  - The rail scroll does not snap to half a button. Only if the fade and chevron prove not to be enough.
  - The two base-scale laws (`UiMetrics` vs v2's `uiScale`) could merge; classic is in the blast radius.
  - The forced-landscape deadline (P1 item 4): design the portrait/narrow case before Google forces it.

**After 6:** session 7 (side scan waypoints, which start with the 460/820 desk check, only once the UI is
complete), session 8 (the P4 list), session 9 (mosaic: wipe revisited, the nadir fill, the accuracy analysis, KMZ).

### Session 6, 29 Sept 2026 — 6a, the device checks

**Status correction:** `feature/pulse-small-screens` WAS pushed (`origin` at 0/0 when the session
opened). `master` is still 7 ahead of `origin/master` - push it.

| check | result |
|---|---|
| Side scan TVG reads 0 / 7.5 / 0 / 10 / 0.9 on a fresh start | **passed** |
| The mosaic pill shows Pause only | **passed** |
| Tab Pro 8": dual side scan ruler under the system bar | **passed** - it was one of the two inset faults (`4c919e0e`) |
| PULSE black card washed out | **FAILED**, and worse than reported - fixed in `71c7e2d0` |

#### The cards, `71c7e2d0` (QML only, no moc)

Olav, on the 320 phone: *"The black is not washed out, it is completely missing. The blue is washed
out. All labels are missing."* The taglines under the plates were there; the three wordmarks and the
black render were not.

**The pattern is the size ratio, not the colour.** Every card image drawn SMALLER than its file was
missing or faded, in exact order of how much it was shrunk: the wordmarks (500 x 99, drawn about
220 wide) and PULSE black (560 x 330) gone; PULSE blue (328 x 281) faded; PULSE red (116 x 229, drawn at
about its own size) perfect. That is `mipmap: true` sampling a mip chain that came back empty on this
GPU: a minified image reads mip levels 1+, a non-minified one only level 0. The emulated tablet's
larger cards shrink less, which is why it showed only "washed out" on the black.

**Fix:** `mipmap: false`, and each image is decoded at the size it is drawn (`sourceSize` from the
plate's own geometry x `Screen.devicePixelRatio`), so the GPU never minifies on any driver. No asset
changed - all six PNGs are plain 8-bit RGBA and look right.

**To check:** all three wordmarks and the black render visible on the 320 phone and the tablets, the
blue no longer faded. One line per card:
`CONN_SCREEN: card <id> | plate W x H | art box W x H | logo box W x H | decoded at dpr D | stacked S`.
**If anything is still missing, that line is the next reading** - a zero or tiny box means the
scaling after all, not the sampling.

**Same shape, not touched:** `PulseRail.qml:595` (the brand mark, 256 px drawn at 40 u) has
`mipmap: true`. It never shows on a phone by the fit rule and looked right on the tablets. Its own
commit if it is ever seen missing.

#### 6c, the split direction - Olav chose C, built as `c9807738` (QML only)

Three options were drawn: A today's stacked split, B always side by side, C follows the shape of
the area. **Olav chose C.** `visualisationLayout.panesSideBySide` is true when the 2D area is at
least as wide as it is tall; the 2D GridLayout then runs 1 x 2 instead of 2 x 1. On every landscape
device that means side by side (320 phone: each pane about 590 x 720 instead of 1180 x 360); it
stacks only in a narrow window. **The mosaic splits already did this** (`landscapeMode`), so the
three dual views now agree. Side scan stays in the LEADING position (left, or top). v2 only.

**To check, before 6b's walk:** side + down on the 320 phone and a tablet comes up side by side,
side scan on the left, `SPLIT: side and down -> side by side | 2D area W x H logical` in the log.
Pulse as one half of an Android split screen: stacked. Classic with two plots: unchanged. Then the
6b walk runs on this layout - the loupe's Add waypoint on the phone is the first thing to look at,
since its clipping was the reason for the question.

#### The phone hang after 6c, 29 Sept - suspect guarded in `a4800f81`, NOT yet confirmed

The Tab Pro 5 was good. **The 320 phone emulator opened black and went ANR.** Log: the last Pulse
line is `SPLIT: side and down -> side by side | 2D area 1204 x 0 logical`, and `METRICS: startup`,
`CONN_SCREEN: built` and `App is created` never came, so `engine.load()` never returned. The two
`uwb-service` SIGABRTs in the same log are the emulator's own UWB daemon, not Pulse.

**The ANR trace had no native stacks** (tombstoned failed), but it had the numbers: **RSS 2.4 GB, 1 GB
swapped**, the thread that logs the GL driver lines (the render thread) stuck in
`mem_cgroup_handle_over_high`, and the Qt thread waiting on a futex. So the render thread was
allocating without bound while the GUI thread waited for it.

**The one unbounded allocation in the painter:** `Plot2DGrid::calculateRulerTicks` walks every step
from 1 to the range and at step 1 pushes one int per unit. An infinite range becomes INT_MAX on arm64,
i.e. an 8 GB vector. `a4800f81` refuses any range that is not finite or is above 10 000 and prints
`GRID: ruler skipped - range A .. B is not drawable | canvas WxH` (at most 5 times).

**To read on the next start of the phone:**
- It starts **and** the `GRID:` line appears → confirmed. Then the real question is *who gave the pane
  an infinite range*, most likely a divide by a pane size of 0 in the new side-by-side geometry. Not
  fixed yet; the guard only stops it hurting.
- It still hangs, **no** `GRID:` line → it is not the ruler. Bisect: `git revert --no-commit c9807738`,
  build, `git revert --abort` (or `git checkout HEAD -- qml/main.qml` + `git revert --quit`).
- It starts with no `GRID:` line → something else changed; say so before anything else is touched.

**NOT REPRODUCED, 29 Sept evening.** After a clean restart of the emulators and Qt Creator, a clear
of storage and a reinstall, the 320 phone started in side + down (demo, then a committed blue) with
**no `GRID:` line** and cache at 3 MB. The 420 phone and the Pro 4 were fine throughout. So the ruler
was never handed an infinite range on these starts, and the hang has no confirmed cause. The most
likely one is the host: an 8 GB Mac running two emulators and Qt Creator (the emulator itself warns
it wants 16 GB), with the ANR showing 1 GB of Pulse swapped. **`a4800f81` is kept** as a guard - it
costs nothing and turns an unbounded allocation into a log line. **If the black start ever returns on
a real phone**, capture the `qtMainLoopThread` stack before anything else.

The start log also shows the side + down split flipping once during Android's portrait-first start
(`221 x 0` side by side -> `221 x 455` stacked -> `1204 x 455` side by side). Harmless: three relayouts
before the first frame.

`hang.zip` (the bugreport) is sitting untracked in the repo root - do not commit it.

#### 6b, the split-pane walk, 29 Sept - 5 of 6 passed; two commits from the sixth

Passed: loupe, paused gutter, pills, rail and panel, connection screen over a split.

- **`5d15b967` - one depth/speed readout per screen.** Testers asked, Olav agreed: in side + down
  both panes showed the same 5.2 m. Pane 2 exists only in that split and is the down pane, so it no
  longer draws the readout; the side scan pane keeps it. The mosaic splits have one echogram anyway.
- **`221affd2` - the speed that never came back.** On the 320 phone the speed line was absent for a
  whole run (any unit) while the tablet showed it on the same file; a restart brought it back. **It
  CAN happen, and this is how:** the line needs `pulseRuntimeSettings.mavlinkDetected`, whose ONLY
  writer is Plot2D's handler on `mavlinkWasDetected` - and `DeviceManager` emits that exactly once
  per process, on the first MAVLink frame, then latches `mavlinkDetected_` and never emits again. One
  lost delivery is permanent until a restart. The screenshot fits: Pause's green dot lit (positions
  arriving from MAVLink) and no speed line. The exact loss route is not pinned. The fix makes it a
  level: on every `vruChanged` (each telemetry frame), if the C++ says MAVLink and the UI copy says
  not, the copy is set and `MAVLINK: detected late - the one-shot mavlinkWasDetected never reached the
  UI` is logged. **That line is the proof** - if it ever appears, the loss happened; the log around it
  says which source was starting.

#### Two quirks from the 6b testing, 29 Sept - three commits, C++ syntax-checked, not built

**1. Two zoom boxes in side + down while the down pane is not yet filled - `f1de2428`.** Paused,
drag from the side scan into the down pane's black (empty) columns: two loupes, until the finger
reached data. Only `qPlot2D::sendSyncEvent`'s `broadcastEpochCursor` retires another pane's aim,
and it returns early without an epoch, so over empty columns nobody told the side scan pane.
`Plot2D::setMousePosition` now sends `syncClearAim()` when its epoch is -1 - **not for a sync
echo**, the same rule as the `x == -1` branch beside it (16 Sept: an echo must not echo).

**2. The down scan painted upside down, once.** Two routes found, both fixed:

- **`d3485f6f` - the pinch asked the committed device.** `Plot2D.qml`'s pinch branched on
  `is2DTransducer` (committed). A committed red viewing a blue demo or log took the 2D branch on the
  blue's down pane: `verZoomEvent` -> `zoomDistance`, whose left-hand branch writes the range as
  **0 .. -R**, the mirror of the normal **-R .. 0**, and therefore upside down under the flip. Now
  `displayIs2DTransducer`, like every other screen question.
- **`6ffeaf1d` - the range and the flip were decided at different moments.** Left-handed mounting
  (`isSideScanOnLeftHandSide` defaults to TRUE) draws the down view from the negative half:
  `setDistance` writes 0..R as -R..0, and `getImage()` flips on `isSideScanLeftHand_ &&
  isSideScan2DView_`. The range was fixed when set; the flip is read at every paint. A range set
  before the pane became a down pane (`applyMaxRange` runs before the orientation timer, and
  `setGridMode("down")` can land after the range) stayed 0..R and was then flipped. **The range is
  now conformed, not trusted:** any two-channel range that does not cross zero is rewritten into the
  form the current flags want, whenever it is written or either flag changes. Logged as
  `RANGE: down range conformed A .. B -> C .. D | left hand X, down view Y | why`. Side scan ranges
  (cross zero) and one-channel 2D ranges are untouched. **Shared C++, so classic's down view gets
  the same repair** - it is the same old quirk.

**To check:** the two-loupe drag again (one loupe only, the side scan's goes the moment the finger
enters the black area). For the down scan: commit PULSE red, run a blue demo in side + down, pinch
on the down pane - it must stay upright. Any `RANGE: down range conformed` line in the log marks
a moment the picture would have been upside down before this build.

**Offered, not done:** with the two-channel blend on, the left-hand choice only decides which
half the down pane draws from when the blend falls back to Single. v2 could drop the left-hand
negation and the flip for the down view altogether (always 0..R, never flipped), which retires
the whole class. It changes the Single fallback's channel, so it is Olav's call.

#### Device report on the two quirks, 29 Sept - one decision, one revert, one instrument

- **The down view is never mirrored in v2 - `05bc9445`.** Olav: *"Only experts use the option to
  compare with single side. So let us do it like that."* `mainview.sideScanLeftHandForPicture()`
  hands the C++ `false` under v2 (all three writers and a variant switch), so every consumer draws
  the down view 0..R and unflipped; Single shows channel 2. The Installation row *Mounted on the
  left-hand side* is gone from v2; classic keeps it. **The cable swap is untouched** - *Cable facing
  the front* swaps the physical channels in Plot2D.qml's channel combos, which is how a PULSE blue
  fitted backwards still draws port on the left. `6ffeaf1d`'s conform stays: under v2 it simply
  turns any stray negative two-channel range positive.
- **`f1de2428` reverted (`5773001b`).** One loupe only, as intended, but slow drags made the two
  loupes blink against each other - the down pane's appearing and vanishing, a ghost of the side
  scan's in antiphase. Olav preferred the two loupes over black. **The blinking is the finding:**
  two panes alternating means both are handed positions from one finger. Also seen: a slight flicker
  on the side scan alone (it may be pre-existing - look again on this build).
- **`f96f8402` - instrument.** `AIM: pane N has the finger | epoch E | mouse X,Y`, printed only when
  the pane changes, capped at 40. **Read it before fixing anything:** a drag from the side scan into
  the down pane should print two lines (1, then 2). A run of 1, 2, 1, 2 is the fault, and the mouse
  column says which pane is being fed coordinates outside itself.

#### The AIM: log read, and the fix - `8b373a83`

Olav's drag from the side scan into the down pane's empty columns printed `pane 1 | epoch 173 |
mouse 737,926+` alternating with `pane 2 | epoch -1 | mouse 2..37,46x` on every event. **Pane 1 keeps
the touch grab** - Qt goes on handing the pane the drag began in every position after the finger has
left it, and the painter clamps them to its edge (the constant epoch 173). Pane 2 is fed the same
finger at the same time. The reverse drag (down into side) printed one line per pane: no fault.
**Verified on the same build:** with `f1de2428` reverted, no flicker at all, the loupe follows the
finger smoothly, and Single under expert is good (so `05bc9445` checks out).

**Fix:** in `Plot2D.qml`'s paused drag, a position outside the pane's own bounds takes that pane's aim
down once, quietly (`plotMousePosition(-1, -1, true)` - isSync, so nothing is broadcast at the pane
the finger is in), and it aims again when the finger returns. **To check:** side into down, slowly,
over the black and over data: one loupe, no blinking, and the `AIM:` lines still alternate (the grab
is Qt's) but pane 1's box never reappears while the finger is in pane 2.

**After `8b373a83`, 29 Sept:** side into down is fixed. Down into the side scan's EMPTY columns left the
down pane's loupe up - the original fault the other way round. The down pane does not keep the grab
(the reverse-drag log had one line per pane), so only the side scan is fed, at epoch -1, and nothing
retires the down pane's aim. **`f8df7c90` re-applies `f1de2428`** (clear the other panes when an aim
lands on no epoch, not for a sync echo). It blinked before only because the side scan was fed the
finger from outside itself; `8b373a83` makes those positions inert. **To check:** both directions,
slowly, over black and over data - one loupe, no blinking.

### STATUS AT CLOSE, 29 Sept 2026 (evening) - SESSION 6 CLOSED

**The one-loupe fix is VERIFIED** (Olav: *"YES!!! Finally! Done!"*): `8b373a83` + `f8df7c90`, both
directions, over black and over data.

**Branch `feature/pulse-small-screens`, 22 commits ahead of origin - push now** (Olav held it until
the loupe was right). `master` is still 7 ahead of `origin/master`. `hang.zip` sits untracked in the
repo root - delete it or keep it out of the commit.

| item | state |
|---|---|
| 6a | TVG defaults, Pause-only pill, Tab Pro 8" ruler: passed. Card images `71c7e2d0`: built - **one look owed** (below) |
| 6b | split-pane walk verified; one readout per screen `5d15b967` verified; one loupe verified |
| 6c | split direction C `c9807738` verified |
| 6d | compact connection screen: **left as it is** (looks good on the 320 emulator; no real small phone seen) |
| 6e | gesture-nav inset: OK as is. Rail chevron: seen and OK on a red - **revisit when the new speed button joins the rail**. Base-scale merge: parked. Forced landscape: **a later todo** |
| down view | never mirrored in v2 `05bc9445`, Single under expert verified; range conform `6ffeaf1d` and the pinch on the display model `d3485f6f` stay |
| speed | `221affd2` self-heal; not reproduced since. Watch for `MAVLINK: detected late` |
| phone hang | not reproduced; ruler guard `a4800f81` stays |

**Still owed, small:**
- **The card images on the 320 phone** (`71c7e2d0`): all three wordmarks and the PULSE black render
  visible, the blue not faded. Never reported after the fix.
- **Live water, from 27 Sept:** speed of sound on a live red; the second-echo automatic range.

**The order changes (Olav, 29 Sept):** High performance mode starts NEXT, ahead of the side scan
waypoints. Its image-manipulation approach changes what the echogram shows, and therefore the base the
pause-and-set-waypoint function works from - so it has to be settled before waypoints are fixed.

| # | Session | Needs |
|---|---|---|
| 7 | **High performance mode - the start.** Read `claude/pulse-high-performance-mode.md` (Olav is updating it) and the project thread "Pulse Blue High Performance mode analysis". Agree the design first; nothing built before. Includes the rail button for echogram speed / boat speed (it will push the rail further - check the chevron then). | Olav's updated doc |
| 8 | **Side scan waypoints**: the 460/820 kHz desk-check switch, then the placement fix - on top of whatever 7 does to the picture | 7 |
| 9 | P4 list; forced-landscape design | - |
| 10 | Mosaic quality and tools (wipe revisited, nadir fill, accuracy, KMZ) | - |

### Session 7, 30 Sept 2026 - High performance mode starts: slice A, the one mapping

`feature/pulse-echogram-speed`, cut from the pushed tip `9304ea51` (Olav published it). **`master` is still 7 ahead of
`origin/master`.** Design answers are in `pulse-high-performance-mode.md`, *30 Sept*. Order agreed: **A** (the mapping,
no new controls), then **B** (side scan true proportions in km/h, the rail button, the pill).

| commit | what |
|---|---|
| `2a3fadb9` | `STRETCH:` instrument - what a screen really holds, per pane |
| `f8f94cf1` | **the stretch is the column mapping, and only the mapping** - no painter scale; `Plot2D::stretch()` for both flow directions and below 1.0 |
| `f376bd07` | a marker sits at the centre of its epoch's band |
| `c64575aa` | the aim's pause snapshot reads the column table (`rightmostEpochOnScreen_` had no writer, so it read 0); the aim's unused speed copy is gone |
| `c4af3266` | the runtime speed follows the DISPLAY model (`echogramSpeedForPicture()`): 2D gets the setting, a side scan 1.0 until slice B |
| `707f65fa` | **pause keeps the picture**: no swap to 1.0, and `Plot2D` holds the stretch frozen while paused |

**The double stretch, by reading.** `reindexingCursor` spread each epoch over s canvas columns, and `getImage` then
scaled the painter by s, right-anchored. Only the right W/s canvas columns reached the screen, holding W/s² epochs:
**a 2D setting of 2.5 drew 6.25 px per epoch.** The tap reads `cursor_.indexes[screen column]`, which named a different
epoch from the one drawn - the reason pause went to 1.0. `2a3fadb9` alone (the instrument on the old mapping) prints
`painter 2.00 | mapping 2.00 | … 4.0 px per epoch` at 2.0 if this reading is right.

**Decision on the stored 2D values (question 9), for Olav to review: they are kept as they are.** The number now means
what it says. At the same setting the 2D picture therefore flows **slower** than before - at 2.5 a screen holds 2.5×
more history than yesterday, at 1.5 1.5×; 1.0 is unchanged. Not converting, because 2D moves to km/h next and a
conversion would be thrown away. The alternative, if the old look is wanted: square the stored value (2.5 would need
6.25, above the 2.5 ceiling, so everything from 1.6 up would land on the ceiling).

**Found on the way, not touched:** the 2D pinch (`Plot2D.qml`, zoomX) asks `is2DTransducer` (committed) - the same
shape as `d3485f6f`; it belongs with slice B's controls. Classic's pause handler writes the persistent speed on resume
for a committed red, so a blue log on a committed red now stretches the side scan in classic.

#### To check on the device - slice A

`pulse.log` (Troubleshooting → View the log, or the file) or `adb logcat | grep -E "STRETCH|PAUSE"`.

1. **2D at 2.0 (red demo or log):** `STRETCH: pane 0 | horizontal | setting 2.00 | painter 1.00 | mapping 2.00 | … |
   2.0 px per epoch`. **px per epoch must equal the setting**: 1.0 at 1.0, 2.5 at 2.5. Anything else is the finding.
2. **It looks slower than yesterday at the same number.** That is the decision above, not a fault.
3. **Pause at 2.0:** the picture does not jump or re-scale. `PAUSE: aim frozen | newest epoch on screen N | columns
   with data C | stretch 2.00` - the stretch is the setting and **N is not 0** (it always was).
4. **Tap a bright target** at 2.0, then resume, set 1.0, pause and tap the same target: the loupe's crosshair sits on the
   target both times and its readings (depth, position when the log has them) agree. **This is the base session 8 needs.**
5. **Scroll back while paused at 2.0**, reach the start, resume: back to live at 2.0 with no 1.0 flash in between. Scroll
   back while live: the start is still reachable.
6. **Blue:** side scan, down and both splits: `vertical | setting 1.00 …` / `1.0 px per epoch`, and the picture exactly
   as before. **A blue log on a committed red** also runs at 1.0; a red log after it gets the 2D setting back untouched.
7. **Classic:** its 2D speed changes the same way (s, not s²); its pause still goes to 1.0.

#### Slice A VERIFIED on the device, 30 Sept

Olav: setting and mapping identical at every stretch tried; no jump on pause; **the same target gives the same lat/lon
in `pulse.log` when a waypoint is added at 2.5x and at 1.0x**; scroll back fine; blue unchanged. Slower 2D at the same
number is accepted (the ceiling can be raised later). **Classic is not retested and will not be again - v2 is the UI
from now on.**

### Session 7, slice B - the side scan in true proportions, the Speed button, the pill

| commit | what |
|---|---|
| `2b08b323` | **true proportions** in `Plot2D`: a vertical pane with `sideScanTrueProportions` takes stretch = v x T x P / swath, capped at 3; `qPlot2D.trueShortenedBy` beyond it; the paused stretch is the one in force at the pause |
| `9a597b04` | `pulseSettings.boatSpeedKmh` (3.0, kept within 1.0-5.0) and three readonly, QML-owned runtime keys: `sideScanTrueProportions`, `boatSpeedMps`, `truePingPeriodMs` (confirmed `ch1Period_Copy`, else the profile's, else 70) |
| `fc8a739c` | the pill: **Boat speed** in the gauge's unit on a side scan, echogram speed on 2D, **5 s**; a **1 : N** pill while shortened; **nothing while paused** |
| `eb3a57ae` | **Speed** on the rail, **pinned** after Max range; its panel group: Boat speed (side scan, gauge unit, nudges) or Echogram speed (2D); icon `pulse_speed.svg` |
| `f5e85ed1` | the sideways pinch asks `displayIs2DTransducer`, not the committed device |

**What a side scan looks like now.** Tablet full screen, P about 1920 canvas px, 3 km/h, 70 ms: 25 m per side ->
**2.2** px per ping, 35 m -> **1.6**, 15 m -> wants 3.7, drawn at 3, **1 : 1.2**; 10 m -> wants 5.6, **1 : 1.9**. A split halves
P and every number. Changing max range now changes the along-track scale too: the picture zooms like a map.

**Not in this slice:** interpolation between pings above ~1.5 (only worth building if the blocks at 2-3 px look bad);
2D in km/h (Olav's question 5, its own design); the down pane stays at 1.0 as it was full screen.

#### To check on the device - slice B

`pulse.log` or `adb logcat | grep -E "STRETCH|PERIOD|SETTINGS: persistent boatSpeedKmh"`.

1. **Live blue, side scan full screen:** `PERIOD: true proportions use 70 ms - confirmed by the echosounder` once the
   setup is done. `STRETCH: pane 0 | vertical | … | TRUE 0.83 m/s x 70 ms, across P px over S m -> wants W, shortened 1 : X`.
   **The first line's `mapping` must equal `wants` up to 3.00**, and `px per epoch` the mapping.
2. **A blue log or demo:** the PERIOD line names its source. `confirmed by the echosounder` means the log carried the
   device's answer; `the profile` means it did not - if the log was recorded at another period the shapes will be off by
   that ratio, and that is the reading that decides whether a recording needs its own period.
3. **Shapes:** on a recording with a known round or square object, at the speed the boat actually drove, the object
   should look as long as it is wide. Then change max range 25 -> 15: the object must keep its shape (it gets bigger in
   both directions).
4. **Speed button:** pinned under Max range. Side scan: Boat speed in the gauge's unit (switch the unit under Screen &
   echogram and look again), nudges step one tenth, ends at 1.0 and 5.0 km/h. Red: Echogram speed x, as the settings row.
5. **The pill:** after a change, *Boat speed 3.4 km/h* (or *Echogram speed 1.8x* on 2D) for 5 s. At a short range, *1 : N*
   stays up for as long as the picture is shortened and goes when the range is widened. **Pause: both pills go**, and the
   picture does not move.
6. **Pause and the loupe on a side scan** at a stretch other than 1: tap a target, add a waypoint, compare with the same
   target at another boat speed - the lat/lon in `pulse.log` must agree, as in slice A.
7. **Split side + down:** the side pane follows the boat speed, the down pane does not move. `STRETCH:` prints one line
   per pane.
8. **Rail on the 320 phone:** the head is one button taller; the body scrolls sooner. The chevron must still say so.
9. **Pinch sideways** on a blue log with a red committed: it changes the side scan range, not the 2D speed.

#### Device report on slice B, 30 Sept evening - and three follow-ups

**Passed:** proportions hold when max range changes (slider or pinch); the boat speed setting stretches the side scan
as it should - on a log driven at about 2.5 km/h, 5 km/h stretches objects along the track and 1 km/h squashes them, and
a sunken boat looks right near the recorded speed. Speed button, pill (5 s, gone on pause), the waypoint check, the
split (side follows, down does not) and the phone rail all passed. The PERIOD line on a blue log read 50 ms (the
firmware start value) and then 70 ms, both from the profile - right for this recording.

**Olav's findings, and what was done:**

| finding | commit |
|---|---|
| The `STRETCH:` line printed 92 px per epoch for a mapping of 2.98 while the screen filled, and the -1 preview plot filled the log. The mapping was right; the arithmetic counted empty columns | `b16c89c6` - px over the columns with data, echogram panes only, full screens only |
| **Speed never reached a blue's down pane** - a leftover of the old UI | `902694f2` - the down pane takes its own `echogramSpeedDown` (1.0-2.5x), full screen and split; the Speed group on a blue shows **Boat speed (side scan)** and **Down scan speed** |
| **In a split both panes took the side scan's range, and a pinch on either changed both** | `d39968f6` - each pane its own key (`maxDepthValuePulseBlueFixed` side, `maxDepthValuePulseBlue` down); the panel shows **Max range side** and **Max range down** whenever a blue is on screen; a pinch changes only its pane |

**Check 9 answered by Olav:** with red committed and the switch to blue declined, the pill says PULSE blue and the log
renders as a blue - the better choice than a blue drawn in a red UI.

**Open question for Olav:** the pill did not appear on a blue after a pinch. A pinch on a blue changes the range, never
a speed, so there is no speed pill to show. Should an along-track pinch on the side scan set the boat speed?

#### To check on the device - the three follow-ups

1. **`STRETCH:`** now prints only for panes 1 and 2 and only on a full screen. On a split at 5 km/h: pane 1 `vertical |
   … | mapping 2.98 | … | 3.0 px per epoch | TRUE …`, pane 2 `horizontal down scan | setting 1.00 …`.
2. **Down scan speed:** set it to 2.0 on a blue in full-screen down and in side + down. The down pane runs at 2.0x
   (`horizontal down scan | setting 2.00 | … | mapping 2.00 | 2.0 px per epoch`); the side pane does not change. A red
   after it keeps its own 2D echogram speed. The pill says *Down scan speed 2.0x*.
3. **Max range side / down:** open Max range on a blue - two sliders, in full screen and in the split. In side + down,
   move each: only its pane changes. `RANGE: applying N to pane 1 from maxDepthValuePulseBlueFixed | side scan law` and
   `… to pane 2 from maxDepthValuePulseBlue | 2D law`.
4. **Pinch in the split:** pinch the side pane, then the down pane. Each changes only itself, and the matching slider
   follows. `RANGE: storing N in <key> | down pane` or `| side or 2D pane`.
5. **Full screen side <-> down:** switching keeps each picture's own number, as before.
6. **A red:** one Max range slider, automatic range as before.

#### Device report on the follow-ups, 30 Sept late - all six passed, and the pinch redone

Speed and range are both available and respected; a pinch on one pane of the split changes only that pane. The
`STRETCH:` lines now read true: at 5 km/h, full-screen side scan, the swath going 40 -> 10 m wants 3.51 -> 14.04, the
mapping holds the cap 3.00 at 3.0 px per epoch and the label goes 1 : 1.2 -> 1 : 4.7. The down scan at 2.0 reads
`horizontal down scan | setting 2.00 | … | 2.0 px per epoch`, full screen and split.

| commit | what |
|---|---|
| `35dc0708` | "Boat speed (side)" - the longer label ran into the nudges |
| `4968aa52` | **the blue pinch, Olav's rule**: side scan vertical = boat speed, horizontal = max range side; down scan vertical = max range down, horizontal = down scan speed (as a red). Near-diagonal does nothing on a blue; speed pinches do nothing while paused; red unchanged |

#### To check on the device - the pinch

`adb logcat | grep PINCH` prints one line per gesture: `PINCH: pane N | side scan | vertical pinch -> boat speed`.

1. **Side scan, fingers stacked vertically (within about 37 degrees):** boat speed moves in tenths, the pill shows it,
   the Speed panel follows. Apart = faster (the picture stretches).
2. **Side scan, fingers side by side:** max range side, as the slider.
3. **Down scan, vertical:** max range down. **Horizontal:** down scan speed, pill *Down scan speed*.
4. **Split:** each pane by its own rule; the other pane never moves.
5. **A diagonal pinch on a blue:** nothing, and no PINCH line.
6. **Paused:** range pinches work, speed pinches do nothing.
7. **Red:** vertical = depth, horizontal = echogram speed, exactly as before.

#### The pinch checks passed (all 8), and `1c442705` - the same effort both ways

Olav: opening a red's depth by pinch took about three times the effort of closing it; the down scan was a little trigger
happy. **Cause:** the deltas were linear in `pinch.scale` (closing moves it 1 -> 0.5, opening 1 -> 2 for the same finger
travel), and `verZoomEvent` takes an **int**, so a closing pinch's small per-frame deltas truncated to 0. **Now:** every
pinch uses the log of the scale ratio, and the depth / side range zooms carry their fractions (`pinchZoomDistance`). Gains
unchanged near scale 1, except the down scan's range steps, 10 -> 7. Speed pinches use the same symmetric delta.

**To check:** on a red, open and close the depth by the same finger travel - the same change both ways. Same on the side
scan range and the down scan range (which should now feel calmer). Speed pinches: faster and slower equally easy. If the
down scan is now too slow, the 7 is the one number to move.

**Device report on `1c442705`:** red still uneven the other way - 12 -> 6 m took 10-13 pinches, 6 -> 12 under 3; the
blue down scan (25 -> 6 in two pinches, and back) feels natural. **Cause, read in the code:** the red pinch went through
the plot's zoom and read the range back with `getMaxDepth()`, which is `ceil()`; the value is stored and re-applied each
frame, so closing steps were rounded back up and opening steps rounded up again. **`2b55a62e`:** the red uses the down
scan's stepping (whole metres, log ratio, gain 7). The side scan range pinch still goes through the plot's zoom and the
same `ceil()` round trip - if it feels uneven, it gets the same treatment in 5 m steps.

**To check:** red, 12 -> 6 -> 12 m by pinch: about the same number of pinches each way, and the same feel as the down scan.

### STATUS AT CLOSE, 30 Sept 2026 (night) - SESSION 7 CLOSED, 1.41 to internal test

**Olav: the red pinch "is great".** Everything in slice A, slice B and the follow-ups is verified on the device, except
what session 8 is for. `feature/pulse-echogram-speed` is **merged into `master` by fast-forward**; Olav builds 1.41 from
`master` and publishes to Google Play *Internal test*.

| done and verified | commits |
|---|---|
| the one stretch mapping, pause keeps the picture, same lat/lon at 2.5x and 1.0x | `2a3fadb9` … `707f65fa` |
| side scan true proportions, boat speed in the gauge's unit, cap 3 and the 1 : N pill | `2b08b323` … `eb3a57ae` |
| down scan's own speed; Max range side / down per pane | `902694f2`, `d39968f6` |
| the blue pinch rule (along the flow = speed, across = range); symmetric pinches; the red depth pinch in whole metres | `4968aa52`, `1c442705`, `2b55a62e` |

**Added at close, not yet on a device:**
- **`730b38c0` - Expert → Transducer → *Side scan frequency* 460 / 820 kHz**, for a committed PULSE blue. Sends
  `transFreq` to the transducer (`PARAM: side scan frequency -> 820 kHz (expert)`, and Device parameters shows the
  confirmed value); runtime, so 460 again on the next start. This is what the waypoint desk check needs.
- **`912b16ca` - the manifest had two `splash_screen_drawable` lines again** (lines 51 and 54 in the 1.41 commit);
  `pulse-manifest-check.js` caught it. One is left.

**The manifest routine** (Qt Creator always opens it in *General* and writes `package=""` into `<manifest>`): set the
version in *General*, switch to the XML source view, remove `package=""`, save, then run
`node tools/pulse-manifest-check.js`. It fails on a `package` attribute and on any duplicate line.

**Still owed:** `master` must be pushed (it was 7 ahead of `origin/master` all session, and now carries all of session 7).
The side scan range pinch still reads the range back through `getMaxDepth()` (a `ceil`); it passed, but if it ever feels
uneven it gets the red's whole-step treatment. The card images on the 320 phone (`71c7e2d0`) and the live-water checks
from 27 Sept are still owed.

| # | Session | Needs |
|---|---|---|
| 8 | **Side scan waypoints, verified end to end** - on 1.41, at the desk with SITL and the 460/820 switch, then on the water. Fix only what a log line proves wrong | 1.41 on the tablet |
| 9 | High performance mode: Task 2a (blue) / 2b (red, black) - the engine, the persistent preference, the wifi warning (192.168.10.x; none on 192.168.144.x), the expert resolution floor slider 1-16 mm | 8 |
| 10 | 2D in km/h (Olav, question 5); interpolation above ~1.5x if the blocks bother anyone | - |
| 11 | P4 list; forced-landscape design; mosaic quality and tools | - |

### Session 8, 2 Oct 2026 - side scan waypoints, verified end to end - `feature/pulse-side-scan-waypoints`

Cut from `master` at `cfae0c98`, which was confirmed pushed (`origin/master` at the same commit, 0/0).

**Tester feedback on 1.41:** waypoints *"It works! Done."* Two findings, both fixed first:

| commit | what |
|---|---|
| `cf33aaa9` | **history bar, side + down: only the side scan moved.** A paused pane refuses a timeline position unless it is in a drag (`Plot2D::setTimelinePosition`), and the history bar's two sliders only ever set the drag on `waterViewFirst`. `core.setTimelinePosition` reached both panes and the down pane threw its share away. Both sliders now set it on both panes |
| `c79c8ce3` | **the zoom box that stayed after the pause.** No log of the run exists, and no route was found by reading: `Plot2DAim::draw` refuses to draw unpaused and every resume is delivered with a repaint. But the cursor kept the paused mouse position, selected epoch and sync depth through a resume. `Plot2D::applyRuntime` now clears all four on the resume edge and prints `AIM: pane N resumed - the aim is cleared | it had one: yes/no` per pane. **If it ever happens again:** a box still up after that line for its pane is a repaint fault; a box with no line for its pane is a delivery fault |
| `0d397250` | **the history bar ignored a cancelled touch**: the panes' drag was cleared on release only, so a touch the system took away left them in a drag for the rest of the pause (a paused pane in a drag re-indexes as if live). `onCanceled` now clears it too |
| `588f224e` | **the waypoint instrument** - nothing in the solution changed |

QML in the two `TimelineSlider*.qml`; C++ in `plot2D.{h,cpp}`, `qPlot2D.h`, `plot2D_aim.{h,cpp}`, `udp_broadcaster.h`. **moc and `g++ -fsyntax-only` pass on all of them in the cloud shell; the six `tools/pulse-*-check.js` pass.** No new `Q_PROPERTY` or `Q_INVOKABLE`.

#### How a side scan waypoint is solved today (read, 2 Oct)

`Plot2DAim::draw`, on the tap:

1. **Side**: a vertical side scan splits the screen at the middle - left half is **port (-1)**, right half **starboard (+1)**. The down scan and 2D have no side.
2. **Slant range** from the screen: `|from + (y / H) x (to - from)|` on the range axis.
3. **Depth** under the boat: the selected channel's bottom track at the tapped ping, the rangefinder behind it.
4. **Fix and heading**: the nearest ping within 12 that carries a GNSS position (raw or interpolated), and separately the nearest within 12 that carries an AHRS yaw (`ATTITUDE`, degrees). Searched first only up to the newest ping at the pause.
5. **Target**: if the slant is inside the water column (`<= depth + 0.05 m`), **the boat's own position**. Otherwise `across = sqrt(slant^2 - depth^2)`, bearing = yaw + 90 deg (starboard) or - 90 deg (port), flat-earth offset from the fix.
6. **Down scan and 2D always send the boat's position** (by design, `forceWaterColumn`).
7. The UDP point is JSON `{"type":"echosounder_target","lat","lon","depth_m","model":"SS"|"2D","name":"Pulse","latlong","ts_unix_ms"}` to port **14570**, to the MAVLink peer when it is fresh, else broadcast, plus a copy to 127.0.0.1.

**What the solution does not take into account, and what the tests are built to expose:** no lever arm or transducer offset from the GNSS antenna; no latency between a ping and its fix (the nearest ping with a fix is used as is); no check that the fix and the heading come from the same moment; **a side scan with no bottom track at the tapped ping takes the water-column branch and sends the boat's position** for every target; and nothing in the solve knows about *Cable facing the front* - the side comes from the screen half alone, so if that switch ever puts starboard on the left, every side scan target lands on the wrong side.

#### The new log lines

```
WAYPOINT: pane 1 | side scan | side port (-1) | tap epoch 4120 of 5300 (newest at pause 5299) |
  boat 59.1234567, 10.1234567 from epoch 4120 (0 away) | yaw 87.3 deg from epoch 4119 (1 away) |
  slant 18.40 m | depth 4.10 m | across 17.94 m | target 59.1236, 10.1232 | off track |
  screen y 310 of 1920 -> t 0.161 over range -25.00 .. 25.00 | stretch 2.21
WAYPOINT: UDP payload to port 14570 | {"type":"echosounder_target",...}
```

(one line in the log; wrapped here). `under the boat` = the water-column branch; `NO TARGET` = no fix or no heading within 12 pings, and Add then does nothing.

#### What to test - session 8, at the desk on this build

**Capture:** `adb logcat | grep -E "WAYPOINT|AddWaypoint|PAUSE:|STRETCH:|PARAM: side scan frequency|AIM: pane|RANGE: applying"`, or `pulse.log` afterwards. **For every Add, write down by hand:** which half of the screen the target was on, which object it was, and where on the map you expected it.

**Setup:** SITL autopilot connected (so `GLOBAL_POSITION_INT` and `ATTITUDE` arrive), the map with contours open on the receiving app, a blue on screen.

**T1 - a blue log with positions, side scan full screen** (the placement test - the log carries its own positions and heading):
1. Pick one distinct object on **port**, about mid swath. Pause, tap it, Add. Then one on **starboard**. Two `WAYPOINT:` lines, two payloads, and where each landed on the map.
2. **Same object, three boat speeds** (Speed -> 1.0, 3.0, 5.0 km/h; pause, tap, Add each time). The target must agree to within about the size of the object - the stretch must not move it.
3. **Same object, three ranges** (Max range side 15, 25, 40). Same expectation.
4. **The same object on a pass in the opposite direction**, if the log has one. Opposite passes are the instrument: a shift **along** the track is a latency, a shift **across** it is a heading, a side or an offset error.
5. **Tap inside the water column** (between the track and the first bottom return): `under the boat`, and the target is the fix.

**T2 - down scan full screen, same log:** tap a bottom feature, Add. Expected: `down scan | side none (0)`, `under the boat`, target = the fix at that ping.

**T3 - split side + down, same log:** the T1 port object again on the **side pane** - same target as full screen (`pane 1`); then a tap on the **down pane** (`pane 2`, the fix). Also scroll the history bar while paused: **both panes must move now** (`cf33aaa9`).

**T4 - live blue + SITL, the geometry test** (positions and heading are the simulator's, so the map cannot judge the picture; the arithmetic can):
1. SITL boat heading **0 deg**: tap one strong return on starboard at a slant clearly beyond the depth, Add. Then on port.
2. Repeat with the SITL heading **90, 180 and 270 deg** (same returns, same taps as far as possible).
3. Expected from the lines: starboard bearing boat -> target = heading + 90, port = heading - 90, distance = `across`. I will compute both from the log, so only the lines are needed.

**T5 - 460 and 820 kHz on the live blue** (Expert -> Transducer -> Side scan frequency):
1. Switch to **820**: `PARAM: side scan frequency -> 820 kHz (expert)`, and Device parameters must show 820 confirmed.
2. With the transducer looking at something at a **distance you have measured** (a wall, the far side of a tank): pause, tap it, Add, at **460** and at **820**. **`slant` must match the measured distance at both frequencies** - if one is off by a fixed factor, the range axis does not follow the frequency's sample spacing.
3. One `STRETCH:` line at each frequency.

**T6 - the two 1.41 fixes:** pause with the loupe up, resume - one `AIM: pane N resumed - the aim is cleared | it had one: yes` per pane, no box left. Any route you find that leaves a box up: say what you did, and send the log.

**Bring back:** the grep output (or `pulse.log`), the hand notes, and a screenshot of the map with the waypoints for T1-T3.

#### 1.42, 2 Oct 2026 - the last tester build before the public release

**Olav, 2 Oct:** the history bar now scrolls both panes, live and paused (`cf33aaa9` verified). The waypoint desk tests
(T1-T6 above) are still to be run, on 1.42. **1.42 goes to the testers; Olav publishes to all users on Google Play on
Sunday 4 Oct.** Performance mode gets its own branch off the pushed 1.42 and goes to internal test only until it is
right, so quick fixes to the public release can still be made from `master`.

| commit | what |
|---|---|
| `040bdb16` | **the blue down scan's depth read 0.0 m**, after side + down and *sometimes*. The depth engine chose its source from the view (`!displayIs2DTransducer && !isSideScan2DView`), so a blue drawn as a down scan took the 2D branch: the rangefinder (`isBottomTrackInitiated` is false in v2), which a blue never sends, so 0.0 or a stale value from an earlier source. The split's full-screen picture is the side scan, which is why the readout was right there. The source now follows the data (display model), not the view. `DEPTH: source -> …` is logged on every change |
| `bc9b0fe4` | **Version 1.42** (`versionCode` 142), edited in the XML; the manifest check passes |
| `9e853e6d` | Olav's 2 Oct revision of `pulse-high-performance-mode.md`, committed as it was in the tree |

**To check on 1.42:** a blue (log, demo or live) in full-screen down shows the bottom-track depth from the first ping;
go side + down -> down full screen -> side + down a few times, and it never reads 0.0 while the bottom is tracked. The
log says `DEPTH: source -> side scan data - bottom track first, rangefinder behind it` for a blue and `2D - rangefinder`
for a red (red unchanged). **One thing to watch:** if a blue down scan ever shows a depth that differs from the side
scan's at the same moment, the bottom track is per channel and the down view would need its own read - not expected,
since `dataset.bottomTrackDepth` is one value.

### Performance mode, step 1 - 2 Oct 2026 (evening) - `feature/pulse-performance-mode`

Cut from `master` at `41d5462e` = the pushed and published 1.42 (confirmed: `origin/master` at the same commit). Olav's
answers: **the engine acts only while expert mode is on**, and **step 1 first, measure, then the engine**. Performance
mode publishes to internal test only; fixes to the public release come from `master`.

| commit | what |
|---|---|
| `784ae677` | **measured, not estimated.** `DeviceManager::frameInput` counts every KP frame from a live link (never a file or a demo) with its 8 bytes of framing; `IDBinChart` counts chart bytes received and the bytes a `seqOffset` gap says never arrived; `DeviceManagerWrapper` samples once a second: `linkBaud` (the device's `ID_UART` answer, read live - not `ConnectionViewer`'s one-time copy), `linkBytesPerSecond`, `linkLoadPercent` (8N1), `chartLossPercent` (10 s) and `chartLossPercentTotal`. `LINK:` every 10 s while data flows |
| `e6cf56fb` | **Expert -> Performance mode**, after Transducer: Enable (off), Max samples 5000 (500-5000), Min spacing blue 15 mm, Min spacing 2D 2 mm (1-50), persistent; *Serial link* and *Lost chart samples* read-outs. **Nothing reads the four rows yet** - the switch's hint says so |

moc and `g++ -fsyntax-only` pass on all seven changed C++ files; the six `tools/pulse-*-check.js` pass. Three new
`Q_PROPERTY`s on `DeviceManagerWrapper` (moc re-runs), no `Q_INVOKABLE`.

**Checked on the way:** `IDBinChart` assembles a ping in a fixed 20 000-byte buffer and drops any fragment that would
overflow it. The sample count is the total over both channels (2000 = 2 x 1000 interleaved, chapter 2), so the
Transducer row's 15 000 still fits. Nothing to do.

**Olav's first try, 2 Oct:** no `LINK:` lines, and the log drowned in `Link::openAsSerial uuid not open, deleting` -
the auto-connect timer retrying a serial link that cannot open, every 500 ms (pre-existing, upstream code). **`06977775`**
prints the first failure and then every 100th. **And the instructions were unclear:** `LINK:` appears only while frames
arrive from a **live** link (a demo or a file never counts - it says nothing about a UART), and the four Performance mode
rows change nothing in step 1, so moving them prints nothing. The measurement is made with the **Transducer** rows.

**Second try, same evening, G30 + live PULSE blue prototype (Basic2D):** still no `LINK:`. **My fault, found by reading:**
`DeviceManagerWrapper` belongs to `Core core`, a global, so its constructor runs before `QGuiApplication` exists and the
read-out's `QTimer` never fired. **`445e9111`** starts it in `setSettingsBus()` (after the app is built) and
prints `LINK: the serial link read-out is running (once a second)` once at startup. The serial lines in that log are a USB
serial link that cannot open (`bus/usb/002/002`), retried every 500 ms - harmless with the transducer on IP.

**The first reading, 2 Oct night, G30 + live blue prototype at the shipped 2000 samples / 70 ms (step 1 of the
measurement): the counter agrees with the arithmetic.** 28.7-33.9 kB/s on the wire, **31-37% of 921600**, against the
predicted ~31 kB/s / 34% (14.3 pings/s x (10 fragments x 214 + 10) + the version poll). Lost chart samples 0.00-0.39% per
10 s, 0.17% since start - on the ground, close to the antenna. **The very first line read `baud 115200 -> 185.8%`**: the
device's UART answer had not arrived yet and the value is a default; it is right from the second line on (worth
remembering in step 2: **the engine must not budget until the reported baud has settled**). Each `LINK:` line now also
carries the clock time and the samples/spacing/period the transducer reports (`9febe631`).

**Found by Olav during the measurement:** the Transducer *Samples* slider ran to 15 000, and **a drag above 5000 killed
the connection** until the transducer was power cycled. **`e3f41c31`** stops it at 5000, the firmware's maximum. The
liveParams map is runtime, so a restart of the app clears any value above it that is still held.

#### The measurement (chapter 9, item 2) - on the tablet with a live blue on the IP link

`adb logcat | grep -E "LINK:|PARAM:|chartSamples|ch1Period"`, or `pulse.log`. Expert -> Transducer, with
**Dynamic resolution off** (it drives spacing and period otherwise).

1. **Baseline as shipped** (2000 samples, 70 ms): one `LINK:` line. Expected about **28-33%** used and ~0% lost. This
   checks the counter against the arithmetic of chapter 2 before anything is changed.
2. **5000 samples, spacing 3 mm, 70 ms**: run **at least 10 minutes** (an hour if you can leave it). Expected about
   **84%** used and no loss. Read *Serial link* and *Lost chart samples* in the category, and keep the `LINK:` lines.
3. **Step the ping period down** at 5000 samples: 65, 60, 55, 50 ms, two minutes each. Note where *Lost chart samples*
   (10 s) leaves 0.00% - and whether the % used stops rising (the link is full) while the loss climbs. That period is the
   real ceiling; the engine's 85% assumption becomes the measured number.
4. **Watch the picture** at step 2: no artefacts, no lag on the tablet (chapter 9, item 10).
5. **Reset** (*Back to the profile*) at the end.
6. Optional, on the wifi AP instead of the IP link: step 2 again - the loss there is the radio, not the UART (9.5).

**Bring back:** the `LINK:` lines with the period and samples each was taken at.

#### The link measurement, 2 Oct night - DONE, read in `pulse-high-performance-mode.md` 9a

G30 + blue prototype on the IP link. **5000 samples x 15 mm at 70 ms: ~84% of 921600, stable for 10+ min**; 60 ms ~96%;
**55 ms killed the link and needed a power cycle**, with no rise in lost samples first (0.1-0.3% at every load - the radio,
not the UART). At 5000 x 25 mm the firmware holds the listen time (62.5 m per side -> ~87 ms whatever is asked). The
reported baud read a default 115200 for one whole run.

| commit | what |
|---|---|
| `18ce749e` | Ping period row 40-160 ms (was 0-2000; a drag below 30 ms killed the link) |
| `32aa6e01` | the read-out averages over 10 s (1 s windows read up to 108%), and a reported baud too low for the measured rate is called impossible instead of showing 700% |

**Decided by Olav:** *"a floor is a floor"* - the prototype loses the link the instant spacing goes below 15 mm, so it
MUST be held at 15. **`ab3c5d9c`**: `pulseRuntimeSettings.hardwareSpacingFloorMm` (15 on the blue prototype - device name
Basic2D and not a 2D transducer - else 1); the Transducer row's minimum follows it and `setParam` clamps
`chartResolution` to it. To check: `PARAM: hardware spacing floor -> 15 mm | device Basic2D | 2D false` after committing
the prototype, and the spacing slider stops at 15. **Confirmed by Olav on the device:** Samples stops at 5000; the
Ping period row is capped at 40-160 and changes the echogram's height as it should.

### Performance mode, step 2 - the blue engine - 2 Oct 2026 (night), not compiled

**Design agreed with Olav before building** (his answers to the six questions):

1. **Max range side decides** the acquisition range - the side scan view, never the down pane's range.
2. **The Transducer rows go read-only** while the engine holds the acquisition (*"held by performance mode"*), rather
   than the doc's "an expert write holds the key" rule - one writer.
3. **distMax follows the range** (`1000 x R`), as the width workaround did.
4. **True proportions reads the real period**, `max(confirmed, 2R/c + 3 ms)`.
5. **Off hands the shipped values back** (2000 samples, spacing = *Side scan width*, the profile's 70 ms), keeping any
   expert Transducer experiments - not `clearParams()`.
6. **The throttle**: 300 ms of rest, a chart setup at most once a second.

**Olav's note on 6, from the upstream author:** set ONE transducer parameter at a time - set, check, OK, next. Olav's
setup procedure already follows it. **The engine does too**: period, then the chart (spacing and samples are ONE message),
then distMax, and nothing is sent until the previous one is confirmed.

| commit | what |
|---|---|
| `51822d56` | **the chart stream says what the transducer really sends**: the last complete ping's spacing (chart header) and sample count (both channels) as `linkStreamSamples` / `linkStreamSpacingMm`; the `LINK:` line adds `(stream N x M mm)`. `DevDriver::chartSamples()` / `chartResolution()` are the app's copy, written the moment a setter runs - not a confirmation |
| `22485e68` | `DevDriver::setChartSetup(resol, samples)` - spacing and samples in ONE chart message (`Q_INVOKABLE`, moc re-runs) |
| `df8f70b4` | `qml/PulsePerfEngine.js` (pure arithmetic) + **`tools/pulse-perf-check.js`** (reproduces 9a: 34% shipped, 83% at 5000 @ 70, 97% at 60, 106% at 55, 87 ms held for 62.5 m; chapter 7's tables; nothing above 85% or faster than 70 ms anywhere) |
| `1618efac` | **one writer**: `perfEngineOwnsAcquisition`; while true `setParam()` refuses chartResolution / chartSamples / distMax / ch1Period by name (the width workaround, the dynamic writers, `onEchogramWidthChanged` and the expert rows all arrive there), `clearParams()` keeps them, and DeviceItem sends spacing + samples as one chart setup (`sendPerfChartSetup`, reading `paramValue()` - D-2) |
| `791e3ee0` | **the engine**, `PulsePerformanceEngine.qml`, one instance in `main.qml` |
| `b607ef90` | expert rows: an **Engine** read-out; Samples / Sample spacing / Ping period at 0.45, no input, *held by performance mode* |
| `5fbe48cf` | **true proportions read the real period**; `PERIOD:` says *held by the listen time of N m per side* when it binds |

**How the engine behaves.**

- **Holds** (is the one writer) while expert mode, *Enable performance mode* and a committed blue (side scan) are all
  true. **Acts** only while that device is live (no demo, no file, connection not lost), configured, and chart data flows.
- **The baud is decided once per connection, after 10 s of data**, while the shipped settings still run: the reported
  baud if `linkBaudPlausible`, else 921600 from the table. At the shipped 31 kB/s a default 115200 is always refuted.
- **The plan**: spacing = max(hardware floor, Min spacing blue, ceil(2R / Max samples)); samples = ceil(2R / spacing),
  up to the next 50; coarser until the ping fits 85% of the decided baud; 70 ms, real period max(70, 2R/c + 3 ms).
- **Sends one at a time**: period (only if it differs), chart (one message), distMax. The chart is confirmed by the
  **stream** (last ping's spacing equal, samples within one fragment); period and distMax by the device's read-back
  plus 300 ms. **Not confirmed in 6 s -> STALLED**: nothing more is sent until the switch is toggled.
- **Turning expert mode or the switch off** hands back the shipped values the same way, then lets go. **A commit that
  moves to another device** drops the engine's values from the old blue's map quietly (nothing on the wire).

At the 15 mm default: 35 m -> 15 mm x 4700 (80%), 25 m -> 15 x 3350 (57%), 15 m -> 15 x 2000 (34%), 10 m -> 15 x 1350
(24%), 5 m -> 15 x 700 (14%). At a 1 mm floor every range is 5000 samples at 83%.

**Checked in the cloud shell:** moc on the four changed headers, `g++ -fsyntax-only` on the four changed .cpp, `qmlformat`
parses the four changed QML files, all seven `tools/pulse-*-check.js` pass. **Not built, not on a device.**

#### To check on the device - step 2

G30 + the blue prototype on the IP link. `adb logcat | grep -E "ENGINE:|LINK:|PARAM:|DEV_PARAM: one chart|PERIOD:"`,
or `pulse.log`. Expert mode on.

1. **Performance mode off (as shipped):** nothing changes. No `ENGINE: holds` line; the Transducer rows are live.
2. **Switch on, side scan, Max range side 25:** `ENGINE: holds the acquisition of …`, then after about 10 s
   `ENGINE: budgets on 921600 baud - reported by the device` (or `model table (the reported 115200 cannot carry …)`),
   then `ENGINE: 25 m per side -> 15 mm x 3350 @ 70 ms (real 70) | 57% of 921600 … | limited by min spacing`,
   `DEV_PARAM: one chart setup -> 15 mm x 3350 samples`, `ENGINE: confirmed chart after N ms | stream 3350 x 15 mm`,
   then distMax. **The `LINK:` lines must then read about 57%** and `(stream 3350 x 15 mm)`.
3. **The Engine row** in Performance mode shows the same line. **Transducer → Samples, Sample spacing, Ping period are
   dimmed** with *held by performance mode*; dragging them does nothing.
4. **Max range side 35 / 15 / 10 / 5** (slider and pinch): the picture follows at once; about a second later one chart
   setup per settled value - **never one per drag tick**. Expected 4700 / 2000 / 1350 / 700 samples at 15 mm.
5. **Min spacing blue to 20 mm** with the range at 25: 20 mm x 2500. **To 1 mm** on the prototype: still 15 mm
   (the hardware floor). **Max samples to 2000**: `limited by max samples`.
6. **The picture**: the side scan sharper at short range, no artefacts, no lag; the mosaic and the loupe still right.
   **A waypoint on the same target before and after** the switch: the same lat/lon.
7. **Switch off:** `ENGINE: hands back the shipped values …` and the sends one by one, then `released`; `LINK:` back to
   ~34% and 2000 x 25 mm (or 2000 x 35 at a 35 m Side scan width). The Transducer rows come back.
8. **Expert mode off with the switch on:** the same hand-back. Expert mode on again: the engine takes over again.
9. **Disconnect / power cycle the transducer while holding:** `the baud decision is dropped - the connection was lost`;
   after the setup, the measuring starts again. **Start a demo while holding:** no sends.
10. **If `ENGINE: STALLED` ever appears**, send the line: it names what was not confirmed and what the stream showed.
    The most likely reading would be the stream's spacing in a unit other than mm - that is the first thing to look at.
11. **True proportions with expert values** (switch off, Transducer 5000 x 25 mm): `PERIOD: … held by the listen time of
    62.5 m per side (asked 70 ms)` and a side scan stretched for ~88 ms.

**Not in this step:** opening it to all users (the per-link switch, the wifi warning), Task 2b (red/black), a black v2.
The two bottom-track problems stay on the list below; the engine changes the range by itself, which feeds problem 1.

### The expert Transducer rows reviewed - 3 Oct 2026, not compiled

Olav asked for moderation of every setter in Expert -> Transducer. Each row checked against what the protocol carries:

| row | before | now | commit |
|---|---|---|---|
| Samples | 100-5000 | unchanged (capped 2 Oct, `e3f41c31`) | - |
| Sample spacing | floor-100 mm | floor to **min(100, 200 000 / samples)**: `IDBinChartSetup::setV0` silently cut anything above to a multiple of 10 mm (5000 x 100 sent 40) | `f4d427bb` |
| Transducer pulse | 0-5000 | **1-30 cycles**, also clamped in `setParam`: one byte on the wire (300 arrived as 44), 0 sends nothing | `84c60524` |
| Side scan frequency (460 / 820 buttons) | PULSEblue only | **removed** - the waypoint desk check is done | `4e61bfb5` |
| Frequency | cone bounds; a side scan has none, so 460..460 and 820 sat off the track | side scan **320-850 kHz** (`sideScanFreqMin/Max`, clamped in `setParam`); 2D keeps its cones | `4e61bfb5` |
| Transmit boost, Dynamic resolution | switches | unchanged | - |
| Ping period | 40-160 ms | unchanged (2 Oct, `18ce749e`) | - |
| Bottom confidence | 0-100 | unchanged | - |
| Maximum depth | live while performance mode held distMax | **held by performance mode**, dimmed like the other three | `994e6218` |

Classic's selectors (DeviceItem's ParamSetups, PulseInfoExpert's blue high/low) are not touched.

**To check on the device:** Transducer pulse stops at 1 and 30, `PARAM: transPulse` in the log, Device parameters shows the value
taken. On any blue the Frequency row runs 320-850 with the knob on the track at 820; on a red it still runs between its cones.
At 5000 samples Sample spacing stops at 40 mm. With performance mode holding, Maximum depth is dimmed.

**Max range ceiling replaces a blue's Maximum depth row (`215af130`).** Olav, 3 Oct: the row moved the range on screen, which
the sliders and the pinch already do; the expert should set how FAR they may go instead. *Max range ceiling*, persistent
(`perfMaxRangeSideM`), from the Side scan width (25 or 35) to 50 m in 5 m steps - 50 m is the longest range whose listen time
(69.7 ms) fits the fixed 70 ms. Active only while performance mode holds the acquisition (`maxRangeCeilingOverride` is now a
binding on it): the Max range sliders and `displayMaxRangeCeiling` follow it, and the engine sets `maximumDepth` (the pinch's
clamp, QML and C++) to it. On hand-back `maximumDepth` returns to the width and a stored range above it comes down. A red
keeps its Maximum depth row. Expected at 40 / 45 / 50 m: 16 / 18 / 20 mm x 5000 at 70 ms, 83%, on both blues.

**To check:** performance mode on, *Max range ceiling* 50: the Max range side slider and a sideways pinch reach 50 m;
`ENGINE: the range ceiling is 50 m`, then `50 m per side -> 20 mm x 5000 @ 70 ms (real 70)`. With performance mode off the row
says it waits for performance mode and the sliders stop at 25 / 35. Turn performance mode off at 45 m: `RANGE:
maxDepthValuePulseBlueFixed 45 -> 25` and the picture back inside the swath.

**Tested OK with a live transducer (not in water), 3 Oct.** The *Max range ceiling* row then moved to the Performance mode
category, after Min spacing blue (`8f9fb9e1`): it only works while performance mode holds the acquisition. The partner doc
now shows 40-50 m as expert-only rows, 30-35 m as optional, standard mode stopping at 35. **Measured on the production blue,
3 Oct 16:01-16:02:** 40 m 16 mm x 5000 at 83.3-84.1%, 45 m 18 mm at 82.6-84.1%, 50 m 20 mm at 80.8-82.7%, all at 70 ms,
the stream confirming each setting, 0.00-0.03% lost.

**Pulse follows the range (`214e0e4a`), for the partner and two expert testers while Olav is away.** A persistent switch in
Performance mode (blue only, default off). On: pulse = 4 x spacing x f / c cycles, 4-30 (`PerfMath.pulseCycles`): production
blue 4 / 5 / 7 / 10 / 12 / 15 / 17 at 5-35 m, 20 / 22 / 25 at 40-50 m; the prototype's 15 mm gives 18 at every range up to
35 m. **SUPERSEDED the same day: capped at 10 cycles, see below.** Sent as one more confirmed step (period, chart, pulse, distMax). Off again or a hand-back: the profile's 10 cycles, then
the hold ends. While held, the Transducer pulse row is dimmed. The test procedure is section 6 of the partner doc.

**To check before handing over:** switch on at 10 m on a live blue: `ENGINE: … | pulse 5 cycles (follows the range)`, `sent
pulse {"transPulse":5}`, `confirmed pulse`, and Device parameters -> Transducer pulse reads 5. Switch off: `pulse 10 cycles
(fixed)` and `the pulse is the profile's 10 cycles again - released`. Performance mode off with the switch on: the pulse goes
back to 10 with the rest.

**A recording shows its whole width (`58579a33`).** Olav, 3 Oct: a recording made at 40-50 m could only be shown to the Side scan
width in playback, because the engine does not hold while a recording plays. With a side scan recording on screen, expert
mode and Enable performance mode on, the Max range ceiling applies too (`maxRangeCeilingOverride`: live OR playback). The
pinch's clamp is now `rangeClampM` (maximumDepth raised to that ceiling), published to the C++ as maximumDepth. When the raised
ceiling ends for any reason, stored blue ranges above the width come down (moved from the engine to PulseRuntimeSettings).
**To check:** record live at 45 m, stop, play it back with performance mode on: Max range side and the pinch reach 45; turn
Enable performance mode off during playback: `RANGE: … above the Side scan width once the raised ceiling ended`.

**The partner doc's testing chapter** (section 6) now covers on/off, the settings, wifi vs the IP Connector, the staircase,
recording (screen + app) and playback limits, and tests A-D; Test B (40-50 m) decides whether 50 m becomes the default.
Note for testers: Min spacing blue defaults to 15 mm, so a production blue needs it at 1 mm to reach Table 3's detail.

**The pulse is capped at 10 cycles (`0ab9dfb5`) - the hardware partner, 3 Oct.** A longer pulse's extra transmit energy can
blow resistors on the transducer. `transPulseMaxCycles` = 10 binds setParam (every writer), the expert Transducer pulse row
(1-10) and Pulse follows the range (4-10). The switch now only SHORTENS the pulse: 4 / 5 / 7 cycles at 5 / 10 / 15 m on a
production blue, 10 from ~20 m. On the prototype (15 mm) it changes nothing. The partner is not optimistic about the picture
with a shorter pulse; Olav field-tests it on a lake with tyres and logs (the partner doc, Test C).
**To check:** Transducer pulse stops at 10; the Engine row never shows more than 10 cycles; at 5 / 10 / 15 m with the switch
on, `pulse 4 / 5 / 7 cycles (follows the range)` and Device parameters -> Transducer pulse agrees.

**Pulse length as the next lever** (the partner doc, section 5): a pulse that follows the range (count ~ 1.2 x spacing in mm)
would turn more of the fine spacing into real detail at short range. Desk test first: 5 m per side, 2 mm, pulse 4 / 6 / 10 on
a sharp target. Not started.

### BOTTOM TRACK - TWO OPEN PROBLEMS, TO BE DEALT WITH (Olav, 2 Oct night)

Olav: *"The false readings we need to deal with. As we also need to deal with a seemingly inability to interpret depths
below 0.5 meters with bottom track."* Both are kept here so they are not lost; neither is started.

1. **False depths when there is no real bottom** - see the note directly below (on shore: ~19 m at 2000 samples, ~33 m
   at 5000; the false bottom follows the acquisition range). Worse with performance mode, which changes the range itself.
2. **No depth below ~0.5 m from bottom track.** Known since 14 Sept, and until now only recorded in code:
   `PulseDepthEngine.qml` (*"The bottomTrackMinDepth crossover - rangefinder below ~0.5 m, bottom track above - is still not
   implemented here"*) and `plot2D_aim.cpp` (*"Bottom track has serious trouble on the shore and below about half a
   metre"*). The planned shape: a crossover that keys off the **rangefinder** value - below ~0.5-1 m the rangefinder,
   above it bottom track - in the depth engine, so the readout, NMEA and the loupe agree. A blue has no nadir rangefinder,
   so for a side scan the question is what bottom track's own minimum (blanking / dead zone) is set to.

Suggested slot: after Task 2a (the engine changes the range, which feeds problem 1), before or with Task 2b.

#### Noted for later - the false bottom moves out with the range (Olav, 2 Oct night)

On shore (no water), the bottom track's false depth on the blue prototype was **~19 m (16-20) at 2000 samples** and **~33 m
at 5000**. Both sit near the far end of what the ping covers: 2000 x 25 mm is 25 m per side (19 m = ~0.75 of it), 5000 x
15 mm is 37.5 m per side (33 m = ~0.9). The likely reading: with no real bottom, the strongest thing in the trace is noise
that the range-dependent gain has lifted at the far end, so the "bottom" follows the range. **Why it matters for
performance mode:** the engine changes samples and spacing, and so the range, on its own. On the water a real bottom should
win, but over a soft or deep bottom a longer acquisition range gives the bottom track more far-out noise to pick. Worth a
look when the engine is on the water: whether bottom track's search should be bounded by the expected depth rather than the
full trace. Not started.

### 1.43 - the mosaic aim hotfix, 4 Oct 2026 - `fix/mosaic-aim` off master (1.42)

**VERIFIED on the tablet, 4 Oct (Olav: *"It is finally gone."*)** - side + mosaic, down + mosaic and
mosaic alone, live and paused: taps on the mosaic do not scroll the echogram or raise a loupe, and
the red dot is gone (`MOSAIC: the selected-epoch red dot is not drawn (v2)` at start).

**Seen in the same log, not touched (pre-existing, not a 1.43 matter):**
`qrc:/MosaicExtraSettings.qml:18: ReferenceError: updateMosaicButton is not defined`, once per start
and per source change. Its own commit later.

**The bug:** in a split with the mosaic (side + mosaic, down + mosaic), a press on the MOSAIC
brought the zoom box (the `Plot2DAim` loupe) up over the echogram pane, and it could stay.

| commit | what |
|---|---|
| `24bb9ddd` | instrument: `MOSAIC: press / release`, `AIM: pane N pressed`, `AIM: pane N takes/ignores a 3D epoch selection from <class>`, `AIM: pane N loupe up / down` |
| `0d3a54db` | **v2: the echogram panes ignore an epoch selected in the 3D view** |
| `15361f0e` | v2: no epoch picking on the mosaic - **reverted in `ba3ef127`** (below) |
| `4093155d` | Version 1.43 (`versionCode` 143), edited in the XML; the manifest check passes; `65a4a948` commits the derived `version.txt` |
| `0f6ec464` | **v2: the mosaic's selected-epoch red dot is not drawn** |

**What the log proved (Olav's run, 4 Oct 00:07, live side + mosaic on a demo):** every tap on the
mosaic printed `AIM: pane 1 takes a 3D epoch selection from BottomTrack | epoch 281 | paused no |
… | selected epoch -1 -> 281`, and the release printed the same with epoch -1. This is the upstream
3D picking route: `BottomTrack::mousePressEvent` / `mouseReleaseEvent` (and `BoatTrack` with no
bottom track) post `EpochSelected3d`, and `Core` installs every echogram pane as an event filter
on them. `qPlot2D::eventFilter` then called `setAimEpochEventState(true)` and
`setTimelinePositionByEpoch(epoch)`:

- **live**, the picked epoch moved the echogram's timeline (the yellow *scrolled back* pill Olav
  saw) and stayed in `selectEpochIndx`. Nothing clears that on pause, and `Plot2DAim::draw`
  raises a loupe from `selectEpochIndx`, so **the loupe came up at the picked epoch on the next
  pause**;
- the release (epoch -1) still armed the aim's epoch-event flag, which is a pending tap.

The same pick also put the **red dot** on the mosaic. Not a press reaching the Plot2D underneath:
no `AIM: pane N pressed` line came with any mosaic press.

**Olav's decision:** *"The touch on mosaic will help identify on the echogram where captured.
Which kind of makes sense. I however fear that this will confuse my users. We should disable this
ability for now, I need a clear strategy for using something like this and I currently have
none."* So both directions are off in v2:

- **`0d3a54db`**: under v2, `qPlot2D::eventFilter` logs `ignores` and returns before touching
  the aim or the timeline. One gate covers press and release, every sender (bottom track, boat
  track, contacts), live and paused, every layout and device.
- **`15361f0e`, reverted in `ba3ef127`**: turning off the 3D view's epoch sync in v2. Olav's
  device check of the first build: the mosaic no longer scrolls the echogram (*"That was the most
  important change"*), the red dot was still there, and an aim moved in the paused echogram shows
  the matching boat position on the mosaic's track. *"This is not bad, per se ... Can we leave the
  ability, just make that red dot fully transparent?"* So the sync stays on.
- **`0f6ec464`**: the red dot (and its red line to the bottom) is not drawn in v2.
  `BoatTrack` keeps making and holding the selection; `GraphicsScene3dView::setSelectedEpochMarkVisible`
  (`Q_INVOKABLE`) is called from `main.qml` at start and when the variant changes:
  `MOSAIC: the selected-epoch red dot is not drawn (v2)`. Waypoints are unaffected: Add waypoint
  places the point at the loupe's crosshair, and the autopilot can hold the boat over it.
- **Classic keeps the upstream behaviour**, red dot included.

C++ in `plot2D.h`, `plot2D_aim.h`, `qPlot2D.cpp` and `scene3d_view.h` (a new `Q_INVOKABLE`, so moc
re-runs). moc, `g++ -fsyntax-only`, qmlformat and the six `tools/pulse-*-check.js` pass.

#### To check on the device - 1.43

`adb logcat | grep -E " (MOSAIC|AIM): "` (the grep without the spaces also catches Play Store's
`Finsky … AIM:` lines).

1. At start: `MOSAIC: the selected-epoch red dot is not drawn (v2)`.
2. **Side + mosaic, live:** tap the mosaic a few times, on and off the track. **No red dot**, the
   echogram does not jump and no *scrolled back* pill. Each tap prints at most
   `AIM: pane 1 ignores a 3D epoch selection …` (the release still posts one).
3. **Pause after those taps:** no loupe. Tap the side scan: the loupe comes up where the finger
   is, as before.
4. **Paused, with a loupe up on the side scan:** tap and drag on the mosaic. The loupe does not
   move, does not go and no second one appears. `AIM: pane N loupe up / down` lines come only from
   touches on the echogram.
5. **Down + mosaic**, the same 2-4. Left- and right-hand layout, tablet and phone.
6. **The mosaic's own interaction is unchanged:** pan, zoom and the Pause pill.
7. **Paused, move the loupe's crosshair:** the epoch link to the mosaic still works as before, with no red dot.

#### 1.43, the log a tester sends - 4 Oct

Olav, reading a `pulse.log` from *Troubleshooting -> Send the log to Techadvision*: *"I rather have
no logs referring to 'kogger'."* The search over C++, QML and Java, and his log, agree: every
"kogger" in the log was a **category name** in `platform/android/src`, and all 120 lines in his log
were USB serial. Nothing in `src/` or the QML logs the name.

| commit | what |
|---|---|
| `d0d700ce` | the per-tap `MOSAIC: press/release` and `AIM: pane N pressed` lines go (the capped AIM: lines stay) |
| `6500706b` | **the log names its build**: `--- log opened: Pulse Echo Sounder 1.43` instead of a hard-coded `1-1-1`, read from the derived `:/version.txt` in `main.cpp` |
| `7c501c88` | the six Android categories become `pulse.android.init / .interface / .serial / .serialport / .serialportinfo` and `Utilities.LoggingCategoryManager` |
| `99a02975` | v2's connection screen file dialogs: *Pulse recordings (*.plog)* instead of *Kogger log files* |

`main.cpp` passes `g++ -fsyntax-only` (Qt 6.4 in the cloud shell needs a one-line `QtLogging` shim);
the category edits are string literals in JNI files the cloud shell cannot compile. QML parses and
the six checks pass.

**To check:** the first line of a new session in `pulse.log` reads `Pulse Echo Sounder 1.43`; a USB
serial warning reads `pulse.android.serialport: …`; the connection screen's *Open a file* /
*Stream a file* dialog offers *Pulse recordings*.

**Deliberately NOT renamed - they are data, not names:** `QSettings("KOGGER", "KoggerApp")` (every
stored setting lives there; renaming resets all users), the `Documents/KoggerApp/...` folders
(recordings, logs, exports; a migration), the `KoggerGeometryTree` file type, the `KOGGER_*`
developer environment variables. Classic's texts (welcome, translations, its dialogs) under the
classic rule. **Worth a later look:** the map tile requests send the user agent
`KoggerApp/1.0 (contact: support@kogger.tech)` (`tile_downloader.cpp`); the Java USB code logs to
logcat under the tag `KoggerUsbSerialManager` (logcat only, not `pulse.log`).

#### LATER - make pulse.log a troubleshooting tool (Olav, 4 Oct)

*"To make the log really useful we should add some effort later to reveal what MAY benefit
troubleshooting. Many debug logs now are remains from where I struggled to create abilities and
had a need of logs to reveal the cause. While some of the current debug logs may be useful, like
the app setup of the transducer parameters. Crashes are obviously useful, of course."*

What his log of 30 Sept - 4 Oct shows (43,335 lines, 34 starts, 5.5 MB):

- **92% is DBG** (40,056 lines). The biggest: `AddWaypoint: setMavlinkPeer change` 8,356 (19%),
  `DEMO:` statistics every 10 s 2,013, `RANGE: applying/storing` ~4,900, `DYNAMIC: avoid ...`
  1,479, `DistProcessing: ...` ~2,200, `devList: ...` ~1,400, `zoomDistance dualChannel` ~740.
- **Keep:** crashes and asserts, the transducer setup and `PARAM:` lines, `SOURCE:`/`MODE:`/`DEMO:
  started`, `LINK:`, `ENGINE:`, `WAYPOINT:`, `INSETS:`/`METRICS:` at start, and every WRN.
- **The shape:** one pass that sorts every log line into keep / cap / debug-build-only, so a
  tester's 2 MB covers days rather than hours. Its own session.

Two findings in the same log, each its own session:

- **A crash opening the USB serial link.** Four `FTL ASSERT: "m_buf" in qiodevice_p.h` on 1 Oct
  (07:30, 07:39 x2, 07:58), each milliseconds after `Link::createAsSerial ... bus/usb/001/002` with
  a USB blue. The same fault as the 27 Sept `SIGABRT` on `SerialInputOutputManager`. The assert
  aborts a debug build; a release build compiles it out and the fault is likely still there. USB
  only, but a customer on USB would meet it.
- **Two MAVLink peers alternating.** The 8,356 `setMavlinkPeer change` lines swap `127.0.0.1`
  <-> `192.168.50.92` several times a second (1 Oct morning, probably SITL and the boat both
  alive). `udp_broadcaster.h`'s own comment predicted it. Not only noise: **the waypoint UDP target
  swaps with it**, so an Add could go to either. Check during the waypoint desk tests (T1-T6).

#### FUTURE TODO - a strategy for linking the mosaic and the echogram

Upstream links the two both ways: a tap on the mosaic picks the nearest bottom-track epoch and
scrolls the echogram there (red dot), and an aim in the echogram marks the same epoch on the
mosaic. It is useful (*"the touch on mosaic will help identify on the echogram where
captured"*), but as it was it confused more than it helped: the echogram jumped with no
explanation, live, and the loupe came up later on pause. **Disabled in v2 from 1.43 until there
is a clear design.** Questions to answer first:

- Live or paused only? A live pick fights the live follow; paused, it is a navigation tool.
- What does the echogram show for a picked point: scroll only, a marker column, or the loupe on
  it (and on which pane in a split)?
- How does the user leave it: the *scrolled back* pill, a dismiss on the dot, a timeout?
- Which direction(s): mosaic -> echogram, echogram -> mosaic, or both.
- Does it belong with the waypoint flow (pick on the mosaic, confirm in the loupe, Add)?

In 1.43 the mosaic -> echogram direction is off (`qPlot2D::eventFilter`), and the echogram -> mosaic
direction is kept with its red dot hidden (`applySelectedEpochMarkForVariant` in `main.qml`).

### Task 2b - PULSE red and black, step 1: measure - 4 Oct 2026, not compiled

`master` (1.43) merged into `feature/pulse-performance-mode` (`f02156a6`; one conflict, this file). **Branch 16+
commits ahead of origin - push it.** Internal test only; it becomes 1.44.

**The order agreed with Olav:** (1) measure, with the ping rate and a depth instrument added; (2) the version poll;
(3) link-fit periods; (4) the two bottom-track problems, designed from step 1's `DEPTH:` lines. Not a performance
mode: every user, every link, no warning, never more data than today.

**A correction to the plan found while reading, before step 3:** `PulsePerfEngine.bytesPerPing()` charges every
fragment a full 214 bytes. Exact for blue's 5000 (25 full fragments); at red's 500 the last fragment holds 100
samples (114 bytes, the logs show it), so it charges 652 instead of 552 and a fitted period would come out ~67 ms
(~15 pings/s) - no gain. Chapter 8's 57-59 ms uses the exact count. Step 3 makes `bytesPerPing` exact and the poll
cost a parameter (330 -> ~50 B/s after step 2).

| commit | what |
|---|---|
| `eaff303b` | **the real ping rate**: `IDBinChart` counts complete pings; `LINK:` ends with `N pings/s (asked X = P ms)`; `linkPingsPerSecond` (`Q_PROPERTY`, moc re-runs) |
| `9eb0e015` | the *Serial link* row adds `| N pings/s` |
| `8278a19b` | **`DEPTH:`** every 10 s from a live device and on every 1 m crossing: shown depth and its source, rangefinder, bottom track, the acquisition range from the chart stream, the dynamic scheme's state |
| `aa69b59c` | **`SERIAL:`** breadcrumbs for the USB desk test: opening / opened / did not open (error), frames arriving / stopped with the baud, the baud search |
| `719151c4` | merge survey: the PULSE divergences in upstream files, the planned `link_defs.h` change |

moc and `g++ -fsyntax-only` pass on every changed C++ file; qmllint finds no syntax error in the two QML files
(qmlformat 6.4 fails its own write-out on the UNCHANGED `PulseDepthEngine.qml` as well, so it is not a check for
that file); all seven `tools/pulse-*-check.js` pass.

#### To test on the device - PULSE red on USB, at the desk (Olav, 4 Oct)

`adb logcat | grep -E " (SERIAL|LINK|DEPTH|DYNAMIC|PARAM|DEV_PARAM): "`, or `pulse.log`. Expert mode on, so
Expert -> Performance mode -> *Serial link* is visible. The transducer in a bucket or tank.

0. **Connect.** Expect `SERIAL: opening … at N baud`, `SERIAL: opened …`, `SERIAL: … frames are arriving at 115200
   baud`. A baud search first (`SERIAL: … silent - trying …`) is normal. **If the app aborts here, the last `SERIAL:`
   line places it** - send the log, and `adb logcat -d -b crash` if you can (the 1 Oct `m_buf` assert).
1. **As shipped, shallow** (Dynamic resolution on): 3 `LINK:` lines (30 s). Two outcomes, and this is what step 3
   depends on:
   - **~20 pings/s at ~98%** (552 B x 20 + polls): over USB the link carries the 50 ms; the 14-15/s of the July log
     was the wifi AP, not the UART. Link-fit then trades 20/s at the edge for 17.5/s with headroom.
   - **~14-15 pings/s at ~72%**: something other than the UART paces the pings (the firmware), and a fitted 57 ms
     may not deliver 17.5 either. Then step 3's benefit is measured, not assumed (point 3 below).
2. **Today's deep operating points, by hand** - Expert -> Transducer, Dynamic resolution OFF, then one minute each:
   samples / spacing / period = **600 / 50 mm / 70 ms**, **800 / 50 / 110**, **1000 / 50 / 150**. Expected about
   84 / 71 / 65% at 14.3 / 9.1 / 6.7 pings/s.
3. **Step 3's periods, by hand, before any code**: **500 / 20 mm / 57 ms** and **59 ms**, then **800 / 50 / 92** and
   **1000 / 50 / 114**. Expected about 86 / 84% at 17.5 / 17 pings/s, then ~10.9 and ~8.8 pings/s at ~85%. **Do not
   go below 50 ms at 500 samples** - the blue prototype died at ~106% and needed a power cycle.
4. **Depth** (Dynamic resolution back ON, *Reset* in Transducer first): a `DEPTH:` line every 10 s. Lower the
   transducer to a known depth, then raise it slowly to ~0.3 m: the `crossed below 1 m` line and the 10 s lines
   below it show which source stops reporting and when. **Then lift it out of the water for a minute**: watch
   whether `shown` and `acquiring` climb together (the runaway of problem 1). Back in the water.
5. **Unplug and replug the USB once**: `SERIAL: … data stopped`, then the open sequence again.

**Bring back:** the grep output (or `pulse.log`) and, per step, what you did and when (clock time).

#### Step 1 measured - PULSE black (SN 139) on USB, at the desk, in air, 4 Oct 14:10-14:26

*Correction, Olav 4 Oct: the unit is a **black**. It reports `PULSEred` and runs red's profile, so the assumption
that a black reports PULSEred is confirmed. It was in air: 0.13 m is the rangefinder's usual reading out of water.*

**USB:** clean. `SERIAL: opening … at 921600` -> `opened` -> `silent - trying 115200` -> `frames are arriving at 115200
baud` within 0.8 s. No abort (the 1 Oct `m_buf` assert did not reproduce). The device reports 115200 in `ID_UART`.

**The link, as shipped (500 samples, 5-6 mm, 50 ms asked), 6 minutes in two runs:**

```
LINK: 500 samples, 5 mm, 50 ms (stream 500 x 5 mm) | 8041 B/s | 115200 -> 69.8% used | lost 0.00% | 14.0 pings/s (asked 20.0)
```

- **14.0 pings/s, rock steady (13.9-14.0), at ~70% of the UART, no loss.** Outcome B of the test: **the UART is NOT
  full; something in the transducer paces the pings at ~71 ms.** The July wifi log's 14-15/s was the same pacing, not
  the AP.
- **The exact fragment count is confirmed by the wire rate:** 14.0 x 552 B + ~320 B/s of polls = 8 050 B/s, measured
  7 960-8 070. With 652 B a ping (PulsePerfEngine's full-fragment count) it would be 9 450. The correction stands.
- **What it changes for step 3:** a link-fit 57 ms only helps if the 71 ms is not a firmware floor. And today's 2D
  picture reads 50 ms where the transducer really pings every ~71 ms, so anything that reads the period (the 2D stretch,
  a later km/h speed) is ~30% off on a red. Not decided; the next measurement says which.
- The first `LINK:` after connect (100 samples, 0 ms, 10.5% lost, 5 pings/s) is the moment before the setup - harmless.

**Depth, transducer at rest:** `shown 0.32 m from bottom track | rangefinder 0.13 | bottom track 0.32`, constant.
- **The red readout follows the BOTTOM TRACK now, not the rangefinder**: `DisplaySettings` sets
  `isBottomTrackInitiated` true during the commit (2 Oct's "2D - rangefinder" is out of date for a live red). The source
  line did not say so; `6642acfe` makes it follow that flag.
- **The bottom-track processing runs with `minDistance 0.25`** (`DevDriver: doDistProcessing … minDistance 0.25`), so it
  cannot report anything shallower than ~0.25 m. With the rangefinder at 0.13 and the bottom track at 0.32, the 0.5 m
  problem looks like this floor (and the bottom track taking the next peak beyond it), with the rangefinder right.
  **Ground truth needed:** the real distance. `bottomTrackMinDepth` 0.5 exists in `PulseRuntimeSettings` and nothing
  reads it - the crossover's planned threshold.

**Frequency 510 / 710 / 810 kHz (14:24-14:26):** the ping rate does not move (13.9-14.1/s at every frequency), so the
pacing is not the pulse. In air the bottom track reads 0.32 m at 510/710 and 0.36 m at 810 - a false bottom just beyond
its 0.25 m minimum. **And after the cone change the readout switched to the rangefinder** (`shown 0.13 m from
rangefinder`): the cone path toggles the bottom track off (`DistProcessing: toggle bottomTrack …`) and the readout's
source follows `isBottomTrackInitiated`. So which source a red shows depends on whether the user has changed the cone
since the commit. To confirm with `6642acfe`'s source line, then its own fix.

**Olav on the period (4 Oct):** no designed limit on the ping period exists; there may be hardware limits he did not
know of. Red uses the bottom track on purpose - the aim is to remove the occasional false readings (a couple of 40+ m
values in a bathymetric run that ruin the picture); its parameters have not been tuned.

#### Next, on the same desk set-up (expert mode ON - it was off in this run, so the Transducer rows were hidden)

Dynamic resolution OFF, one minute each, note the clock time:

1. **500 / 6 mm / 80 ms** -> expect 12.5/s: the asked period is honoured above the floor.
2. **500 / 6 mm / 57 ms** -> 17.5/s means link-fit works; **14.0** means a ~71 ms floor, and step 3 shrinks to
   "command what is delivered".
3. **300 / 10 mm / 50 ms** and **200 / 15 mm / 50 ms** (same ~3 m range; 338 / 224 B a ping, under 60% even at 20/s):
   **~20/s** -> the pacing is the per-ping transmit time (~48 ms for 552 B, plus ~23 ms); **14/s at any size** -> a
   firmware floor of ~71 ms.
4. Today's deep points: 600/50/70, 800/50/110, 1000/50/150.
5. **Depth:** the real distance to the bottom first, then 1.0, 0.5, 0.3 and 0.15 m - wait 10 s at each for a `DEPTH:`
   line (the 1 m crossing prints by itself).

### THE PROMPTS FOR THE NEXT SESSIONS

**Status, 3 Oct 2026 (evening):** performance mode is ready for the testers and pushed. Verified on a live production blue:
5 / 10 / 15 / 20 / 25 m per side -> 2 / 4 / 6 / 8 / 10 mm x 5000 at 70 ms, 83%, pulse 4 / 5 / 7 / 10 / 10 cycles with Pulse follows
the range on (Max samples 5000, Min spacing blue 1 mm). The pulse is capped at 10 cycles everywhere (hardware partner).

**Found by Olav, the last known v2 bug - the zoom box that would not go away:** in a split screen with the MOSAIC (side +
mosaic, and probably down + mosaic too), a press on the MOSAIC pane makes the loupe pop up over the side scan pane. The
belt-and-braces of `c79c8ce3` / `0d397250` stay. The fix goes to master as 1.43 (prompt 1), then master is merged into
`feature/pulse-performance-mode`, where the red work continues (prompt 2, 1.44 internal only).

#### Prompt 1 - master, 1.43

```
We continue the Pulse Echo Sounder work (project "Modernize UI of the Pulse Echo Sounder
app"). Repo: my KoggerApp folder. This is a HOTFIX on master (1.42 is public); it becomes
1.43, published to internal test and then to the closed test group tomorrow. Cut a branch
fix/mosaic-aim off master (check that master equals origin/master first - remind me if not),
and leave feature/pulse-performance-mode alone until the fix is merged.

Read first: claude/pulse-bug-backlog.md, "THE PROMPTS FOR THE NEXT SESSIONS" and the 1.41/1.42
notes on the aim (c79c8ce3 "the zoom box that stayed after the pause", 0d397250, 8b373a83 +
f8df7c90 "one loupe" in session 6). The project memory pulse-aim-zoom has the loupe's design.

The bug, now reproducible: split screen with the MOSAIC - side + mosaic for certain, very likely
down + mosaic too. A press on the MOSAIC pane makes the zoom box (Plot2DAim loupe) appear over
the 2D echogram pane, and it can stay. The upstream aim / cursor sync can probably be activated
from the 3D/mosaic view (a sync cursor, a shared mouse position, or the press reaching the
Plot2D underneath). Required behaviour for now: a press, drag or release on the mosaic pane
must never raise, move or keep a loupe on any echogram pane. Live and paused, side + mosaic and
down + mosaic, left- and right-hand layout, tablet and phone.

Find the route first: add an AIM:/MOSAIC: log line on the path(s) that raise the aim from the
mosaic, ask me for the log, and fix only what the line proves. Keep it minimal - this ships
tomorrow. Do not touch the mosaic's own interaction (pan/zoom/pause pill) or classic.

Then bump the version to 1.43 (versionCode 143) in the manifest's XML (not Qt Creator's form
view, no package="" attribute), run node tools/pulse-manifest-check.js. Version.txt is derived.

Working rules as before: Classic is not touched; one idea per commit; nothing is fixed before
its log line is read; run moc on any changed header and a g++ -fsyntax-only check on changed
C++ in the cloud shell (apt qt6-base-dev qt6-declarative-dev qt6-base-dev-tools
qt6-declarative-dev-tools libqt6serialport6-dev qt6-positioning-dev; -I every src dir, not
third_party; qmlformat parses changed QML), plus all tools/pulse-*-check.js, before telling me
to build; update the backlog in the repo AND the project doc. When I confirm the fix on the
device: I merge fix/mosaic-aim into master and push; then merge master into
feature/pulse-performance-mode (expect a conflict only in the manifest version and the backlog).
```

#### Prompt 2 - feature/pulse-performance-mode, PULSE red (1.44, internal test only)

```
We continue the Pulse Echo Sounder work (project "Modernize UI of the Pulse Echo Sounder
app"). Repo: my KoggerApp folder, branch feature/pulse-performance-mode. First check that
master (1.43, the mosaic aim fix) has been merged into it and the branch is pushed - remind me
if not. This branch publishes to INTERNAL TEST ONLY; when I am happy it becomes 1.44.

Read first: claude/pulse-high-performance-mode.md chapters 2a, 8 (Task 2b - red and black in
the field) and 9 items 3 and 7; claude/pulse-bug-backlog.md from "Performance mode, step 2" to
the end, including "BOTTOM TRACK - TWO OPEN PROBLEMS".

Performance mode for PULSE blue is done and with the testers. Today: general improvements for
PULSE red (and black, same profile, same 115200 UART fixed by the delivered 2.4 GHz wifi AP).
Not a performance mode - for every user, every link, no warning, never more data than today.
Candidates, in the order I think they should go - agree the order and the design with me
before building:

1. MEASURE FIRST on a live red: the LINK: line at today's dynamic scheme, shallow (500 samples
   commanded at 50 ms - chapter 2a predicts ~99% of 115200 and only ~14-15 pings/s) and deep.
   Add what is missing to read it: the real ping rate (complete pings per second from the
   chart stream, like linkStreamSamples) in the LINK: line and the Serial link row.
2. The version poll (8.3): the app polls every 300 ms while data flows; ~2.3% of a 115200 link
   back by polling every ~2 s while chart data flows (requestAllCntBig 3 -> 20 in
   link_defs.h, an upstream file - note it in claude/upstream-merge-survey.md). Check the swap
   prompt still notices a changed transducer.
3. Link-fit periods (8.2, option A): PulseDepthEngine's dynamic scheme computes the period
   from the bytes per ping at 85% of the reported baud (reuse PulsePerfEngine.js) instead of
   the fixed 2 x res - 50 rule: ~57-59 ms at 500 samples in the shallows (steady ~17 pings/s
   instead of ~14-15 irregular), ~30% more pings in deep water at the same detail. Keyed on the
   reported 115200 (the red prototype Basic2D reports 115200 too). Never below the listen time.
4. The two bottom-track problems: false depths with no real bottom (they follow the
   acquisition range), and no bottom-track depth below ~0.5 m (the rangefinder crossover in
   the depth engine, so the readout, NMEA and the loupe agree).

Working rules as before: Classic is not touched; one idea per commit; nothing is fixed before
its log line is read; moc + g++ -fsyntax-only on changed C++ in the cloud shell, qmlformat on
changed QML, all tools/pulse-*-check.js (extend pulse-perf-check.js for the red arithmetic);
update the backlog in the repo AND the project docs. Waypoint desk tests T1-T6 are still owed
on my side. The partner doc "PULSE blue - what performance mode achieves" is the testers'
reference - their feedback (especially Test B, 40-50 m) may come in during this work.
```

### Emulators

Qt Creator reads the same SDK's AVD folder as Android Studio, so AVDs made in Android Studio's
Device Manager appear in Creator's device list; Creator can boot a stopped one itself. On Apple
Silicon use **arm64-v8a** system images, which match the kit. Suggested set: a small phone
(~720 x 1280, ~320 dpi), a mid phone (1080 x 2400, ~420 dpi), and a 7-8" tablet. An emulator
cannot reach a transducer, so it tests demo and files only, and its GPU is the host's through
translation — **do not judge the mosaic on an emulator**, use the S23 for session 5.
