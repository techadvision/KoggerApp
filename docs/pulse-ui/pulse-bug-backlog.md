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

## Group D — the chooser offers what a log file cannot do

A file is not a transducer, and three controls have not been told.

- **The cone chooser cannot work during playback.** Choosing a cone sends a command to a
  transducer, and there is not one. Either preselect the file's own frequency and show it
  as chosen, or **disable the choices outright** — Olav: *"OK to have the bar expanded,
  but not clickable choices."*
- **Colours: 2D and side scan must each keep their own set.** Today the side scan gets
  the 2D favourites and choices. `colorMapIndexSideScan` and `colorMapIndex2D` both exist;
  this is the deferred *blue gets red's colour choices and favourites* item, still open
  and now several sessions old.
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

## Still owed, from earlier sessions

- The logcat check for `SETTINGS: persistent settings injected into pulseRuntimeSettings
  -> ok` with no `ReferenceError` above it.
- `feature/device-profiles-step4` has never been merged to master.
- `feature/pulse-ui-v2-rail` is now **86 commits unpushed**.
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
4. **D** — wants B finished before it can be judged.
5. **E** — last of the tablet work, and it is already half of the phone work.
6. **Phone sizing** — after all of the above, deliberately.
