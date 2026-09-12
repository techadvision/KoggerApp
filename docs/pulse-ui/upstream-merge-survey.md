# What is in the 537 upstream commits, and is any of it worth having

12 September 2026. Merge base `eb46efd6` (upstream 0.14.3, 15 April) → `3a7f5266`
(upstream 1.0.3, 7 September). Companion to `pulse-ui-strategy.md`, which has the
cost side; this is the value side.

---

## The short answer

**The C++ is the valuable half, and it can be taken without the UI.**

| | insertions + deletions |
|---|---|
| `qml/` | 46 264 + 10 138 across 238 files |
| `src/` | 14 978 + 3 036 across 202 files |

253 of the 537 commits touch QML only. Those are upstream's new interface, which
Pulse will never ship. 202 touch C++, and that is where everything below lives.

### The finding that decides it

`qPlot2D` — the `WaterFall` type every Pulse QML file talks to — **grew from 104
members to 140 and lost nothing.** Not one property, invokable or slot present at the
merge base was removed.

Our QML references **95 distinct `plot.*` members. Upstream dropped none of them.**

So the backend is backward-compatible at exactly the boundary that matters. Upstream's
C++ can come across while `PulseAppClassic.qml` keeps talking to it unchanged. That was
not obvious before checking, and it is the difference between a port and a merge.

Two supporting facts point the same way:

- Upstream still loads QML from a qrc (`engine.load("qrc:/qml/main.qml")`, import paths
  `qrc:/` and `qrc:/qml`). Ours loads `qrc:/main.qml`. One line apart, not two worlds.
- The only file under `src/` that we changed and upstream deleted is
  `src/scene2d/scene2d.pri` — a qmake include.

---

## What is worth having

Grouped by what it does for Pulse, not by upstream's ordering. Commit hashes are
upstream's.

### 1. The side-and-down split screen — already built, in C++

This is the one feature the strategy document named as a deliberate cherry-pick this
round: entry 3 of 5 in the view chooser, "Side + down (split)".

| | |
|---|---|
| `c260ed0da` | sync echograms in two modes; info plate on the echogram made optional and customisable |
| `a9c6d1c79` | offset accounting for echo sync |
| `ebb413322` | minimal info on the slave echo in sync mode |
| `a0031efa4` | fix multichannel echo sync |
| `7487552fd` | updated echo sync logic |

Worth more than the feature itself: it is a second opinion on the question the strategy
document left open — what is shared between two panes and what is per-pane. Upstream had
to answer it too, in C++, and the answer is readable.

### 2. Echogram rendering quality on Android

| | |
|---|---|
| `2e3ca0f52` | echo rendering at native resolution with fractional DPR (android) |
| `5bc0c38da` | C++ rendering DPI scaling |

Pulse is an Android app judged against Garmin on how the picture looks. This is the
single item most likely to be visible to a customer, and it is pure C++.

### 3. The loupe and the paused mode — the design already calls for a rebuild

| | |
|---|---|
| `88279fd2e` | loupe live preview on all echoes |
| `e201b5651` | global loupe instrument for the echogram |
| `d880aebb9` | live scrollbar |
| `6f035d2e1` | centralised mechanism for hiding UI overlays |
| `c2e82dd6b` | vertical-mode echogram: contacts, loupe, info overlays |

The design says: the pause scrollbar moves out of the picture into a gutter, the loupe
is rebuilt at roughly three times the area, and while paused the rail, readout and
recording pip all step aside. Upstream has C++ for a live scrollbar, a reworked loupe,
a centralised overlay-hiding mechanism, and specifically the **vertical-mode** echogram,
which is side scan. Most of that work currently lives in our `plot2D_aim` and
`plot2D_zoom` — the files with the heaviest conflicts, and now also the ones with the
most to gain.

### 4. Device selection and link robustness — the recurring pain

| | |
|---|---|
| `7c44b29a2` | filter unknown devices |
| `aa3bf4692` | do not autosearch baudrate on boot-attributed links |
| `47134474b`, `42a2f95f6` | device topology model and view |
| `806eeb498`, `08b6cf382`, `8d3680774` | firmware upgrade: survive the reconnect window, do not identify a device from a pre-reboot reply, gate on reported boot mode |

Compare against our own history: *harden device selection when the device is only
reachable via gateway IP*, *fix/device-selection-race*, *selecting the correct device on
Skydroid G30*, *an endless series of security exceptions for the USB*. Same territory,
independently worked. This matters more once the IP-connector profile lands, because
that adds a third way for a device to be reached and identified.

### 5. Settings migration — the profile rework wants this

| | |
|---|---|
| `1c33fb9c0` | reworked app settings, with a settings migration module and version assignment |
| `d3d6a7111` | migration: merge all previous versions sequentially |
| `c661f44f7`, `32a599e4f` | echogram state serializer |
| `4577d49e4` | import/export UI state |

`PulseSettings.qml` currently says of its own version field: *"nothing reads
settingsVersion today — it is a marker, not a migration trigger."* The planned profile
rework turns forty ternaries into a keyed map, which is exactly the kind of change that
needs stored settings migrated rather than silently reinterpreted. Upstream built the
mechanism.

### 6. Rules the design states, which upstream has already implemented

| | |
|---|---|
| `49bdecf30` | hiding echo controls based on data availability |
| `5ed3551bd` | fix hiding echo rangefinder data |
| `0aa623e8e` | echogram theme switcher |
| `452160617` | additional layers on miniplots |

"Device-dependent controls are absent rather than greyed out" is a design rule we wrote
down. Upstream shipped it.

### 7. TGC in C++

`14850a1c9` — *tgc for chart data*. We have our own TVG and water-column filtering
(`feature/tvg-echogram-filtering`, shipped in v1.38). Worth a read before the two
diverge further, whether or not we take it.

### 8. Recorder

| | |
|---|---|
| `87502b72d` | recorder: file retrieval and status |
| `d3817578b` | liveness-based download re-request — fixes echogram offset jitter |
| `41bdd7060` | fix file extension on import record |

The panel design has a Recording group with start/stop and a file list. This is its
backend.

### 9. Field diagnostics

| | |
|---|---|
| `ffb41b86f` | app logger |
| `7ce0a1dbd` | logging UI rework, updated Logger API |
| `28f0e30f9` | console split into all / app / protocol tabs |
| `28afacda5` | show the log save path in a notification |
| `a668786d3` | internal app notifications |

A SAR group on a shore in bad weather cannot send you a stack trace. This is the
machinery that lets them send you a file instead.

### 10. Battery — one real source for the status chip

`1f87bfc94` — *device battery level widget*. The strategy document had to retract an
invented "1.24 km · 84%" chip because no RSSI, battery or distance property existed
anywhere. This is one of those values, arriving from the device. Worth checking whether
it is the sounder's own level or the boat's before designing anything around it.

### 11. Crash and correctness fixes

`d7dd91f6b` null pointer dereference · `cb59660c9` crash clicking a notification with a
path · `f08341bc0` correct decoding of non-Cyrillic characters when opening a file ·
`6bdf7560a` bottom track and surface cover the full record on file open ·
`b313eaaad`, `afcb3ce00`, `ce2b3d2f5`, `1b53cfc12` mosaic task scheduling and lazy
surface DB creation.

---

## What is not worth having

- **The 253 QML-only commits.** Upstream's new interface. Readable any time from the
  remote without being in our tree.
- **USBL** — roughly ten commits building out underwater acoustic positioning. A
  different product.
- **Tile providers and the 3D scene** — Baidu and Google map versions, ruler, compass,
  3D widgets, scale bar. That is Seascape's territory, not the sounder's.
- **RTSP video streaming** — a video pool and ffmpeg decoding in the GCS.
- **Translations, language controller, Windows and Linux desktop affordances.**

---

## The merge that follows from this

Take `src/`, keep `qml/`.

1. Merge upstream, then take **ours** wholesale for `qml/` and for the build files that
   register it — our `qml.qrc` and our QML file list survive; `qml/app`, `qml/controls`,
   `qml/menus`, `qml/settings`, `qml/devices`, `qml/scene2d`, `qml/scene3d` and
   `qml/kqml_types` do not enter the tree.
2. Resolve the **C++ conflicts by hand**: roughly 28 files under `src/`, 1–10 hunks
   each, about 75 hunks in total. The heavy ones are `plot2D_aim.cpp` (10),
   `qPlot2D.cpp` (7), `plot2D_grid.cpp` (6), `plot2D.cpp` (4), `mosaic_processor.cpp`
   (4), `core.cpp` (4).
3. **`CMakeLists.txt`** is the awkward one: 666 lines of our churn against 241 of
   theirs, and theirs now adds eight QML module subdirectories we do not want. Ours
   wins, with their new `src/` files folded in.
4. **`platform/android/src/org/kogger/koggerapp/KoggerActivity.java`** — upstream
   deleted the custom activity; we have 244 lines of Skydroid G30 USB and security-
   exception handling in it. Ours stays.
5. **`src/main.cpp`** keeps our singleton publishing (`pulseSettings`,
   `pulseRuntimeSettings`, the settings bus) and our `qrc:/main.qml` load path, with
   upstream's new registrations added.

### What it costs, honestly

The conflict resolution is days, not weeks — but it is 15 000 lines of other people's
C++ arriving under a UI they never tested it with. Nothing here is provable without
the device: the same `.plog` replay that proved Stage 1, then a real session on the
water, and the echogram compared side by side against a v1.38 build.

The half of each upstream feature that is QML does not come across. The split screen,
the loupe and the scrollbar arrive as capability, not as interface — and the interface
for them is Stage 4, which we were going to write anyway.

---

## Recommendation

**Do the C++ merge, drop the QML.** The backward-compatible `qPlot2D` surface is what
makes it possible, and it will not stay that way forever — every month upstream spends
building against their own new UI is a month in which something we depend on can be
dropped without them noticing.

Order: this merge, then the device-profile rework — which now has upstream's settings
migration to build on — then Stage 4, which gets the split screen, the loupe and the
scrollbar as working C++ to build an interface over rather than as features to invent.
