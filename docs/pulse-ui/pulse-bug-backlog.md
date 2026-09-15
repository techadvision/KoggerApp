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

## Group C — the demo loop, and the crash that came out of it

- **The demo restarts at end of file. Keep that** — Olav wants it. **But not while
  paused:** restarting under a pause produces "huge artifacts", and it is important for
  demonstrations that a paused picture stays put.
- **It also crashed the app.** `SIGABRT`, `ASSERT "!(max < min)"` in `qBound<int>` inside
  `Plot2DAim::draw`, paused, in a split screen, with `DEMO: running at 70 ms/epoch` on the
  line above. A demo restart clears the dataset; `data_width` goes to 0; `qBound(0, x, -1)`
  aborts the process.

**The defensive half is done** — `e3d75733` makes the loupe answer "no epoch" instead of
aborting. **The behavioural half is this group:** hold the restart until the pause ends.

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

## Still owed, from earlier sessions

- The logcat check for `SETTINGS: persistent settings injected into pulseRuntimeSettings
  -> ok` with no `ReferenceError` above it.
- `feature/device-profiles-step4` has never been merged to master.
- `feature/pulse-ui-v2-rail` is now **81 commits unpushed**.
- Two C++ changes in this branch are **uncompiled in this shell**: the per-pane grid
  (`2efbccb3`) and the loupe crash guard (`e3d75733`).

## Not blocking, with Olav

The boat run with two transducers, the real device swap, the PULSEblue-IP acceptance test.

---

## The order, and why

1. ~~**A**~~ — **done**, `d75e4f12`.
2. ~~**B**~~ — **done**, `e8634060` … `b5849994`. Untested on a device.
3. **C** — rides along with B; same demo path. **Next**, and it is C++: the restart is in
   `Core::onDemoFinished`, which loops whenever `demoLoopEnabled_` is set and knows nothing
   about the pause. Note the branch already carries two uncompiled C++ changes.
4. **D** — wants B finished before it can be judged.
5. **E** — last of the tablet work, and it is already half of the phone work.
6. **Phone sizing** — after all of the above, deliberately.
