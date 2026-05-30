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
