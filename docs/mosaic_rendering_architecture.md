# Side-Scan Mosaic & Surface Rendering — Architecture and Options

Status: working notes captured during the `feature/enable-3d-mosaic` trial (June 2026).
Scope: how the 3D side-scan mosaic / surface / isobaths rendering works in Pulse,
why it behaved the way it did during first testing, and the options that follow for
**live-data rendering** and **multi-layer KMZ export**. This is a decision-support
document, not a spec — code references are given as `file:line` against the trial branch.

---

## 1. TL;DR

- The mosaic is a **quadtree tile pyramid**, not a single image. Tiles are
  **256×256**, across **7 zoom levels** (zoom 1 = finest ≈100 px/m, zoom 7 = coarsest
  ≈1.6 px/m).
- Tiles are **local-metric**: indexed in **NED world meters anchored at the dataset's
  LLA reference**, *not* geographic web-mercator tiles. NED-north equals true north,
  so every tile is a **north-aligned rectangle** in lat/lon.
- Rendering is **viewport-driven**: the visible map quad is converted to a tile set at
  the current zoom; only those tiles are produced. Tiles are served from a **RAM
  hot-cache → session SQLite (`surface.db`) → recompute-from-epochs**, in that order.
- The tile store (`surface.db`) is a **per-session scratch cache, deleted on close**.
  Reopening a log recomputes the mosaic from scratch (fast, but from zero).
- The first-test blocker was a Pulse-introduced `if (true) return;` stub in
  `Dataset::calcDimensionRects()` (added 2026-04-12 in `85d478e1`, absent upstream),
  which disabled all tile assignment. Removing it restored rendering.

---

## 2. Pipeline overview

```
Sonar epochs (echo) ─┐
GNSS position  ──────┤ Dataset (epoch pool, spatial index)
MAVLink ATTITUDE ────┘     │
                           │  DataHorizon advances per-quantity frontiers
                           ▼
              calcDimensionRects()  ← assigns each epoch's swath to TileKeys (all zooms)
                           │  emit sendTilesByZoom(epoch, tilesByZoom)
                           ▼
                   DataProcessor (worker threads)
                     - onCameraMoved / handleVisibleTilesChanged: pick visible tiles
                     - pumpVisible: hot-cache → surface.db → compute
                     - MosaicProcessor: paints tile textures from swath samples
                           │  tiles (mosaic RAW8 + height + marks)
                           ▼
                   SurfaceView (scene3d)  ← draws textured tile quads (mosaic/isobaths)
```

Key types: `TileKey{x, y, zoom}` (`data_processor_defs.h`), `MosaicIndexProvider`
(`mosaic_index_provider.h`), `HotTileCache` (`hot_tile_cache.h`), `MosaicDB`
(`mosaic_db.h`), `SurfaceView` (`scene3d/domain/surface_view.cpp`).

---

## 3. What the mosaic requires per epoch

The mosaic frontier in `DataHorizon::tryCalcAndEmitMosaicIndx()`
(`data_horizon.cpp:278`) advances to the **minimum** of four independent frontiers:

```
mosaicIndx = min( bottomTrackIndx, chartIndx, max(attitudeIndx, artificialAttIndx), sonarPosIndx )
```

So a swath epoch paints only when **all** of the following exist for it:

1. **Sonar echo** on the configured side-scan channel(s) — `chartIndx`, and
   `chart(mosaicChId)->range()` must be non-empty.
2. **Bottom track / depth** — `bottomTrackIndx` (enable bottom track).
3. **Position** — `sonarPosIndx`, derived from GNSS (interpolated between fixes).
4. **Heading/yaw** — real `ATTITUDE`, else artificial yaw from GNSS movement
   (`tryRetValidYaw()`, `epoch.h:403`).

Footprint geometry is computed in `Dataset::calcDimensionRects()`
(`dataset.cpp:1919+`): for each consecutive epoch pair it casts left/right range rays
from position along heading, takes the bounding quad, and asks
`MosaicIndexProvider::tilesInQuadNed()` which tiles that swath covers — at the base
zoom, then up the pyramid via `buildTilesByZoom`.

### 3.1 Interpolation is interpolation-only (no extrapolation)

`DataInterpolator` (`data_interpolator.cpp`) fills position/attitude **between** two
raw anchor samples. It does **not** extrapolate past the last anchor. Consequences for
sparse, asynchronous inputs (e.g. MAVLink forwarded at low rate):

- Interior epochs between fixes interpolate fine — sufficient for point lookups such
  as the Loupe/aim waypoint feature.
- Any tail of epochs **after the last fix** cannot be positioned → those stay pending
  forever → the "Data prepairing…" badge never clears for that tail.

During the trial the test logs were dense (position/heading tracked the echo frontier
to within a few epochs), so this was not the blocker — but it remains the thing to
watch with genuinely sparse live MAVLink.

---

## 4. The first-test blocker (resolved)

`Dataset::calcDimensionRects()` had a hard `if (true) return;` at the top
(`dataset.cpp`, added 2026-04-12 in commit `85d478e1` "Tuning and bugfix after general
lift to upstream version 14"; **not present in upstream 0.14.3**). It short-circuited
the whole function, so:

- `lastDimRectindx_` never advanced past 0;
- the chunked spatial catch-up spun forever (`dimPending=true`), so
  `spatialPreparing` stayed true and "Data prepairing…" never cleared;
- no tiles were ever published to the processor, so nothing painted.

Removing the stub restored upstream behaviour. This is logged here as a
**non-obvious, Pulse-specific resolution** per the project's merge-gotcha discipline:
if the function ever misbehaves (it was presumably stubbed for a reason in April),
this is the line to revert, and the `PULSE_MOSAIC_DEBUG` instrumentation (section 8)
will show exactly where.

---

## 5. Coordinate & zoom model

- **Tiles are NED-metric.** `TileKey.x/y` index a grid of `tileSideMeters =
  256 * mppFromZoom(zoom)` (`data_processor_defs.h`). Tile origin =
  `worldOriginFromKey = (x·S, y·S)` in NED meters from the dataset's `llaRef`.
- **NED-north = true north**, so each tile is an axis-aligned, north-up rectangle in
  geographic space. Converting a tile to lat/lon is just its 4 NED corners through the
  existing `LLARef` (NED↔LLA both directions already exist).
- **Zoom levels 1..7** (`mosaic_index_provider.h`, `ZL[]` in
  `data_processor_defs.h`). Zoom 1 finest. `getMaxZoom()=1`, `getMinZoom()=7`.
- Each epoch's swath is registered at the **base zoom and every coarser level**
  (pyramid), so any zoom has tile→epoch coverage available.

This is the single most important fact for export: **the mosaic is already a
north-aligned, multi-resolution tile set in a known geodetic frame.**

---

## 6. Caching & why pan/zoom "replays"

`DataProcessor::handleVisibleTilesChanged()` (`data_processor.cpp:2085+`) converts the
view quad to a tile set at the requested zoom and diffs against the last set:

- **Pan, same zoom** → only newly revealed tiles (`addedTiles = new − old`) are
  produced; on-screen tiles persist. (Observed: "move around, result stays.")
- **Zoom or tilt** → requested zoom changes → the visible set is a *different* pyramid
  level, whose tiles may not exist yet → they are produced → "plays over again." Tilt
  also changes effective resolution and visible extent.

Production order in `DataProcessor::pumpVisible()` (`data_processor.cpp:1850+`):

1. skip tiles already rendered / in-flight;
2. serve from **HotTileCache** (RAM LRU, bounded, evicts under pressure);
3. serve remaining from **`surface.db`** (SQLite);
4. only true misses are **recomputed from epochs**.

So revisiting a zoom you already built is a fast cache replay, not a full recompute.
The visible replay is first-visit-per-zoom or post-eviction.

### 6.1 Tile store persistence

- `MosaicDB` path is a **single shared `surface.db`** in AppData
  (`mosaic_db.cpp:48`); the KLF path argument is `Q_UNUSED`.
- The **writer opens with `deleteOnClose = true`** (`data_processor.cpp:1730`), so the
  store is a **session scratch cache, deleted on close**. It does not persist across
  reopen or app restart.
- Each tile is stored compressed: **`mosaicBlob` (RAW8) + `heightBlob` + `marksBlob`**,
  tagged with `engineVer` (currently `1`, `data_processor.cpp:87`). `engineVer` is the
  invalidation hook for a future tile-format/engine change.

---

## 7. Implications & options

### 7.1 Live-data rendering

The viewport-driven, incremental model suits live capture: new epochs register to the
tiles they touch, and only visible tiles compute (`onCameraMoved` trims pending work to
the view). Two things to validate during live testing:

- **Throughput at ~20 Hz.** Building the full pyramid per epoch may be CPU-heavy.
  *Option A (default):* keep current behaviour, measure. *Option B:* compute only the
  visible zoom level live and lazily build other levels on zoom-out. Lever lives in
  `calcDimensionRects` / `buildTilesByZoom` and the visible-tile selection.
- **Sparse MAVLink tail.** With low-rate forwarded position/heading, the most-recent
  epochs (after the last fix) won't render until the next fix arrives — expected, and
  benign, given interpolation-only. If it proves annoying live, *Option:* hold last
  heading / short bounded extrapolation for the trailing edge (explicitly a product
  decision — it trades correctness for immediacy).

### 7.2 Multi-layer KMZ export (anticipated request)

Feasibility is good because the data is already a north-aligned tile set with separable
layers. Options, lowest-effort first:

- **Option 1 — Flat per-tile GroundOverlay (recommended first cut).** For each tile:
  decode `mosaicBlob` + colormap → PNG; compute `<LatLonBox>` from the tile's NED
  corners via `LLARef`; emit a KML `GroundOverlay` (no rotation needed — tiles are
  north-up). Bundle PNGs + KML into a `.kmz`. Pick one export zoom (or the current
  view zoom). Simple, robust, opens in Google Earth and most GIS.
- **Option 2 — Single stitched overlay.** Composite all visible tiles into one image
  with one bounding `LatLonBox`. Fewer files, coarser control, easy for users.
- **Option 3 — KML super-overlay (Region/LOD).** Use the existing zoom pyramid as a
  proper level-of-detail super-overlay so Google Earth streams resolution by altitude.
  Most faithful to the on-device experience; most work.
- **Layers.** The DB already separates `mosaicBlob` (side-scan), `heightBlob`
  (depth/surface colour) and `marksBlob`/isobaths — so "multi-layer" maps onto distinct
  KML folders/overlays straight from the tile store.

**Export prerequisite — persistence.** Because `surface.db` is deleted on close, export
must run **while the session/file is open**, OR the store must be made durable. The
clean enabling change:

- flip the writer's `deleteOnClose` to `false`, and
- key the DB to a **per-KLF path** (currently `Q_UNUSED(klfPath)` → single shared
  `surface.db`).

That converts the scratch cache into a durable, per-log, exportable tile store —
likely the right foundation for KMZ and for "reopen without recompute." Note it also
changes disk-usage and lifecycle (need cleanup/versioning by `engineVer`), so it's a
deliberate decision rather than a free win.

---

## 8. Diagnostics available (trial only)

Behind `PULSE_MOSAIC_DEBUG` (defined in `data_horizon.h`), ~1 Hz logging:

- `DataHorizon::dbgLogHorizon()` — dumps epoch/chart/pos/att/artAtt/sonarPos/dimRect/
  mosaic frontiers + gaps; the column that trails `epoch` is the starving stream.
- `Dataset::setSpatialPreparing()` / `scheduleSpatialCatchup()` — logs the
  "Data prepairing…" transitions and whether `sonarPos`/`dimRect` done-indices converge
  on their pending targets.

These are **trial-only** and should be stripped (or left compiled-out) before any merge
to `master`. Comment the `#define` to silence without removing code.

---

## 9. Open decisions before the initial test version

1. **Keep `calcDimensionRects` enabled** as restored (recommended) — verify on-device
   with both file replay and live input before merging.
2. **Live pyramid strategy** — measure first; only switch to visible-zoom-only if
   throughput demands it.
3. **Tile-store persistence** — decide whether to make `surface.db` durable + per-KLF
   now (enables export + no-recompute reopen) or defer until KMZ work starts.
4. **KMZ scope** — flat GroundOverlay (Option 1) for a first release; super-overlay
   later if users want streamed LOD.
5. **Strip vs keep `PULSE_MOSAIC_DEBUG`** — strip for the production line; optionally
   keep behind the flag on an integration branch.
