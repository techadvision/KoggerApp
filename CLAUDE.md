# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KoggerApp is a cross-platform C++/Qt QML application for hydrographic and survey work. It displays real-time sonar echograms, calculates isobaths, renders side-scan mosaics, and manages connections to Kogger sonar devices over serial/TCP/UDP. Targets: Windows (x86_64), Android (arm64-v8a, armeabi-v7a), Linux (x86_64, aarch64).

## Build Commands

Primary build system is **CMake**; qmake (`.pro` file) is retained for legacy/upstream parity but is **not** the recommended path on this fork.

Historical note: qmake was the only build system through Qt 5.15 and is still the upstream author's preferred path. After the move to Qt 6.8.3, qmake on this project can no longer produce a **multi-ABI** Android App Bundle suitable for Google Play (arm64-v8a + armeabi-v7a in one artifact). CMake is the only option that handles multi-ABI builds, so this fork standardises on CMake.

```bash
# Linux / desktop — preferred workflow
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
./build/KoggerApp

# qmake — legacy / upstream parity only (single-ABI Android, desktop)
qmake
make -j$(nproc)
./KoggerApp
```

**Windows:** Open the project in Qt Creator and select the LLVM-MinGW 17.0.6 / Qt 6.8.3 kit. Prefer the CMake configuration; the `.pro` import still works for desktop-only builds.

**Android:** Open in Qt Creator with the Android kit (Clang NDK 27.3.13750724 / Qt 6.8.3). For Google Play release builds (multi-ABI AAB) **use the CMake configuration**; the qmake `.pro` build is single-ABI and is only suitable for sideload/test APKs. Output goes to `android-build/`.

C++ standard: **C++23**. Qt version: **6.8.3**.

### CMake Build Options

| Option | Default | Purpose |
|---|---|---|
| `FLASHER` | OFF | Enable firmware update support |
| `SEPARATE_READING` | OFF | Data reception in a separate thread |
| `SCENE_TESTING` | OFF | Enable 3D scene testing |
| `KOGGER_BUNDLE_ANDROID_OPENSSL` | ON | Bundle OpenSSL for Android |

## Architecture

### Data Flow

```
Device (serial/TCP/UDP)
  → LinkManager → DeviceManager → FrameParser
  → Core (core.cpp)
  → Dataset (epoch storage, thread-safe via QReadWriteLock)
  → DataProcessor (worker threads)
      → BottomTrackProcessor, IsobathsProcessor, MosaicProcessor, SurfaceProcessor
  → 2D/3D Visualization ← QML UI
```

### Key Components

**`src/core.h/cpp`** — Central controller (~2500 lines). Manages the processing pipeline, device connections, file I/O (KLF log format), and exposes the dataset/device/link managers to QML via `setContextProperty`.

**`src/dataset.h/cpp`** — Central data store for sonar epochs. Thread-safe with `QReadWriteLock`. Holds depth, temperature, GNSS, and side-scan data. Caps epoch count on 32-bit devices (~7 min @ 20 Hz).

**`src/data_processor/`** — Real-time processing pipeline. `DataProcessor` spawns `ComputeWorker` threads for isobaths, bottom track, mosaic, and surface. Uses QThread-based workers.

**`src/scene2d/`** — Custom OpenGL 2D visualization engine. `qPlot2D` is the Qt wrapper; `plot2D_echogram` renders the real-time waterfall echogram. Other `plot2D_*` files handle aim, attitude, contact, encoder, and temperature displays.

**`src/scene3d/`** — OpenGL 3D scene. `scene3d_view` manages the scene; `scene3d_renderer` handles OpenGL drawing. Organized into `controllers/`, `domain/` (boat_track, bottom_track, surface_view, isobaths_view, mosaic_view), `core/`, `events/`, `processors/`, and `utils/`.

**`src/device/`** — Device discovery and protocol. `DeviceManager` coordinates multiple sonars; `DevDriver` handles the binary frame protocol.

**`src/link/`** — Connection layer. `LinkManager` manages serial, TCP, and UDP links concurrently.

**`src/tile_engine/`** — Background map tiles. `TileManager` + provider pattern (Google, OSM). SQLite-backed tile cache via `TileDb`.

**`src/SettingsBus.h/cpp`** — Central settings singleton bridging C++ and QML (NMEA broadcast, UDP gateway, expert/beta mode flags).

**`src/NMEASender.h/cpp`** — Broadcasts depth and temperature over UDP as NMEA sentences.

### QML UI

`qml/main.qml` — Root `ApplicationWindow`. Handles Android safe-area insets, dynamic DPI scaling, and a Windows fullscreen border workaround.

`qml/DeviceItem.qml` — The largest QML file (~99 KB); contains most device configuration and echogram controls.

`qml/DisplaySettings.qml` — 3D scene and display configuration (~55 KB).

Custom reusable controls live alongside the feature QML files (e.g., `CButton`, `CCombo`, `CSlider`).

### Rendering

- Desktop: Full OpenGL via Qt's OpenGL RHI backend (swap interval forced to 0).
- Android: OpenGL ES 2.0.
- Shaders: `resources/shaders.qrc` (desktop), `platform/android/shaders.qrc` (mobile).
- FreeType (prebuilt, `third_party/freetype/`) handles text rendering in OpenGL.

### Android Platform Layer

`platform/android/src/android_interface.cpp` — JNI bridge for Android-specific features.
`platform/android/src/qtandroidserialport/` — Custom Android serial port implementation (Qt's `SerialPort` module is desktop-only).

### Resource Bundles

| File | Contents |
|---|---|
| `qml/qml.qrc` | All QML source files |
| `resources/icons.qrc` | SVG/PNG icons |
| `resources/resources.qrc` | General assets |
| `resources/shaders.qrc` | Desktop GLSL shaders |
| `images.qrc` | Raster images |

### Translations

`translations/translation_{en,ru,pl}.ts` — English, Russian, Polish. Update via `scripts/win_update_translations.bat`.

## Platform Notes

- `src/main.cpp` forces `QSGRendererInterface::OpenGLRhi` and sets `QSG_RHI_BACKEND=opengl`.
- High-DPI scaling is enabled on Windows; `AA_EnableHighDpiScaling` is set before `QApplication`.
- The `.pro` file controls platform-specific module inclusion (`SerialPort` and `Widgets` are desktop-only).

## Upstream Sync Workflow (merging KoggerTech releases into Pulse)

This fork is a heavy UI/behavior divergence from upstream `koggertech/KoggerApp`. Pulse auto-applies
most device settings (users only tweak filter level etc.) and uses its own echogram colormaps and 2D-first
UI. Upstream requires manual setup and keeps a 2D/3D split view. Merges must NOT destroy Pulse behavior.

**Process that worked for 0.14.1 -> 0.14.2:**

1. Tag the exact shipped/production commit first (e.g. `pulse-v1.23-playstore`) as a rollback anchor.
2. Do all merge work on an integration branch (e.g. `merge/upstream-0.14.3`), never directly on `master`.
   `master` stays the production/hotfix line; hotfixes land on `master` and are merged forward.
3. Merge upstream tags sequentially (`0.14.2`, then `0.14.3`), not in one jump. Use
   `git merge --no-ff --no-commit <tag>` so the merge can be reviewed before committing.
4. Resolve conflicts preferring Pulse behavior; adopt upstream's efficiency/structure only where it
   doesn't fight Pulse. Flag non-obvious resolutions instead of guessing.
5. **Always do a clean rebuild AND an on-device load test after the merge.** A clean `git merge` with
   few conflict markers is MISLEADING here (see gotchas).
6. Merge the integration branch into `master` via a Pull Request (reviewable diff + clean history),
   then pull `master`. Do NOT rename branches to swap `master` (see Branch hygiene below).

**Build-config bridge (CMake vs qmake):** Pulse builds with **CMake** (only CMake produces the multi-ABI
Android AAB for Google Play). Upstream uses **qmake** (`KoggerApp.pro`). Any qmake-relevant upstream change
must be hand-translated into `CMakeLists.txt`: when `.pro` gains `SOURCES`/`HEADERS` entries, add the same
files to `APP_SOURCES`/`APP_HEADERS` (the lists are explicit, not globbed). New `.qml` files go in `qml/qml.qrc`.
(0.14.2 added no new C++ sources; 0.14.3 adds `src/hotkeys_controller.{h,cpp}` and `src/ui_state_serializer.{h,cpp}`.)

**Gotchas learned (re-check these every merge):**

- **Auto-merge silently breaks heavily-customized QML.** Git's line-based auto-merge fuses upstream UI
  refactors into Pulse's differently-structured QML with NO conflict markers, producing files that parse
  but fail to load (e.g. upstream turned a `CCheck{id:...}` into a `CText`, and Pulse's kept
  `checked`/`onCheckedChanged` ended up on the `CText` — invalid). Watch logcat for
  `Cannot assign to non-existent property` / `Type X unavailable` with a `qrc:/<file>.qml:<line>` location.
  Highest-risk files: `Plot2D.qml`, `main.qml`, `DisplaySettings.qml`, `DeviceItem.qml`.
- **A SIGSEGV at startup in `Core::UILoad` -> `findChild<GraphicsScene3dView*>` means a QML load failure.**
  `UILoad` is the `QQmlApplicationEngine::objectCreated` handler and does not null-check `object`; when the
  QML root fails to load Qt passes `object == nullptr`, so `findChild` dereferences null (fault addr 0x8).
  Fix the underlying QML error, not the C++.
- **Colormaps are Pulse's, not upstream's.** Echogram palettes live in `src/scene2d/plot2D_echogram.cpp`
  (`updateColors()`, EK500/HTI/"our own" palettes) and `src/scene3d/utils/draw_utils.cpp`; keep Pulse's.
  `src/themes.h` is UI control theming (buttons/sliders/tooltips), NOT echogram colormaps — safe to take upstream's.
- **`Plot2DEchogram::setWrapEnabled()`** (added upstream) is called from `plot2D.cpp` and declared in the
  header — must keep its definition even when keeping Pulse's `updateColors()`.
- **3D view is intentionally hidden** in `main.qml` via `has3DView: false` (collapses the split's 3D pane to
  width 0 so the 2D echogram fills the screen). The `GraphicsScene3dView` object must remain instantiated
  (`visible:false`) for `Core::UILoad`'s `findChild` wiring. See the "REVISIT LATER" comments in `main.qml`.
- **Pulse Android identity:** keep `versionCode`/`versionName` and the `org.techadvision.pulse` package in
  `AndroidManifest.xml`; never accept upstream's `org.kogger.koggerapp` / version reset (Play needs a
  monotonic versionCode).

**Open items to revisit (deliberately left as shipped during 0.14.2):**

- Rangefinder line defaults ON in C++ (`plot2D.cpp` constructor: `rangefinder_.setVisible(true)`,
  `setTheme(1)`); the QML checkbox can't override it. Flip the constructor default if the line should be off.
- Upstream's `_pixmap.fill(palette background)` in `plot2D_echogram.cpp` was NOT taken (Pulse's commented-out
  version kept) — it's a candidate fix for the side-scan "remaining artifact" TODO; test before adopting.

## Branch hygiene

Keep ONE long-lived `master` as the permanent production line — never rename it. Earlier practice
(rename `master` -> `master-backup-<date>`, promote a feature branch to `master`, change the default on
GitHub web) has produced several `master-backup-*` branches and risks history/lineage confusion across
clones and CI. Going forward: do work on feature/integration branches, merge into `master` via Pull
Request, and tag releases (the tag is the rollback point, replacing the need for backup branches).
