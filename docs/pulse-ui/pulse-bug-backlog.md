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

## Group A — the rail says nothing about what is open

One fault, five symptoms, and it is the cheapest win on the list.

- **Only the Colours button lights up when its panel is open.** Cone, Max depth,
  Intensity, Water body filter and Settings do not. `PulseRail.qml` sets
  `pending: rail.openGroup === "colours"` on exactly one button; every other
  `PulseRailButton` is missing the line. Users cannot tell which control they are
  looking at.

**Fix:** one property per button, or better, let the button compare its own `buttonId`
with `rail.openGroup` so a new button cannot be added without it. The second shape is the
one that stops this recurring.

**Session size:** minutes. Do it first — it makes everything else easier to test, because
the rail finally says what is open while you are testing something else.

---

## Group B — the file/demo path sets nothing up

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
- `feature/pulse-ui-v2-rail` is now **72 commits unpushed**.
- Two C++ changes in this branch are **uncompiled in this shell**: the per-pane grid
  (`2efbccb3`) and the loupe crash guard (`e3d75733`).

## Not blocking, with Olav

The boat run with two transducers, the real device swap, the PULSEblue-IP acceptance test.

---

## The order, and why

1. **A** — minutes, and it makes every later session easier to test.
2. **B** — the big one, and the one a customer would notice first.
3. **C** — rides along with B; same demo path.
4. **D** — wants B finished before it can be judged.
5. **E** — last of the tablet work, and it is already half of the phone work.
6. **Phone sizing** — after all of the above, deliberately.
