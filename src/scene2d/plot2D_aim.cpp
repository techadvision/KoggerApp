#include "plot2D_aim.h"
#include "plot2D.h"

#include "udp_broadcaster.h"
#include <QtMath>
#include <cmath>
#include <algorithm>
#include <QPainterPath>
#include <QBuffer>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QDateTime>

#include <cmath>

namespace {
constexpr qint64 kWaypointButtonGuardMs = 2000;
constexpr qint64 kTouchStreamFallbackReleaseMs = 2500;
}

Plot2DAim::Plot2DAim()
    : beenEpochEvent_(false),
    lineWidth_(1),
    lineColor_(255, 255, 255, 255)
{
#if defined(Q_OS_ANDROID) || defined(LINUX_ES)
    scaleFactor_ = 2;
#else
    scaleFactor_ = 1;
#endif
    //Pulse
    debounce_.start();
    touchStreamTimer_.start();
}

//Pulse helper for echogram stretch
static inline int epochToLogicalXScaled(int i, int datasetSize, int canvasW, int visibleCols)
{
    const int last  = datasetSize - 1;
    const int start = std::max(0, last - visibleCols + 1);
    const int left  = canvasW - visibleCols;
    return left + (i - start); // may be < left (off left) or >= canvasW (off right)
}

// NEW: inverse of epochToLogicalXScaled – map logical X back to epoch index
static inline int logicalXToEpochScaled(double x,
                                        int datasetSize,
                                        int canvasW,
                                        int visibleCols)
{
    if (datasetSize <= 0 || canvasW <= 0 || visibleCols <= 0)
        return -1;

    const int last  = datasetSize - 1;
    const int start = std::max(0, last - visibleCols + 1);
    const int left  = canvasW - visibleCols;

    // Map world X → column within the visible window
    const int col = static_cast<int>(std::floor(x + 0.5)) - left;
    if (col < 0 || col >= visibleCols)
        return -1;

    const int idx = start + col;
    return std::clamp(idx, 0, datasetSize - 1);
}

// Map *logical* X (after undoing painter transform) back to an epoch index
// using the current visible window: [start..end] where end = rightmostIdx
static inline int logicalXToEpochInWindow(double xLogical,
                                          int canvasW,
                                          int rightmostIdx,
                                          int visibleCols,
                                          int dataSize)
{
    if (canvasW <= 0 || visibleCols <= 0 || dataSize <= 0)
        return -1;

    // Clamp rightmost to dataset
    if (rightmostIdx < 0)
        rightmostIdx = dataSize - 1;
    rightmostIdx = std::clamp(rightmostIdx, 0, dataSize - 1);

    // Visible window [start..end] anchored to the right edge
    const int end   = rightmostIdx;
    const int start = std::max(0, end - visibleCols + 1);
    const int left  = canvasW - visibleCols;   // leftmost logical X of the window

    // Column inside the window
    const int col = static_cast<int>(std::floor(xLogical + 0.5)) - left;
    if (col < 0 || col >= visibleCols)
        return -1;

    const int idx = start + col;
    if (idx < 0 || idx >= dataSize)
        return -1;

    return idx;
}



//Pulse helper for crosshair when echogram is rotated 90 degrees
static inline QPoint devRotNeg90(const QPoint& d, int deviceW) {
    // Inverse-map a -90° rotated bitmap back to unrotated device axes
    // (x,y) -> (x',y') with x' sourced from y and y' flipped from x
    return QPoint(d.y(), deviceW - 1 - d.x());
}

static inline int visibleColsFromTransform(const QTransform& W, int canvasW) {
    // robust even when rotated: |W * (1,0)|
    const double sxMag = std::hypot(W.m11(), W.m12());
    const double sx = std::max(1e-6, sxMag);
    return std::max(1, int(std::floor(double(canvasW)/sx + 0.5)));
}

//Pulse helpers for nearest yaw
struct NearestYawIdx {
    bool   found   = false;
    int    epochIdx = -1;
    int    dIdx     = 0;     // index distance from tapped epoch
    float  yawDeg   = NAN;   // [-180,180] or [0,360] depending on how you store it
};

static NearestYawIdx findNearestYawByIndexRanged(Dataset* ds,
                                                 int idx,
                                                 int maxLookEpochs,
                                                 int minIdx,
                                                 int maxIdx)
{
    NearestYawIdx best;
    if (!ds) return best;

    const int last = ds->size() - 1;
    if (last < 0) return best;

    // clamp bounds to dataset
    minIdx = std::max(0, std::min(minIdx, last));
    maxIdx = std::max(minIdx, std::min(maxIdx, last));

    // clamp starting idx into the band
    idx = std::max(minIdx, std::min(idx, maxIdx));

    auto testAt = [&](int j)->bool {
        if (j < minIdx || j > maxIdx) return false;
        if (auto* ep = ds->fromIndex(j); ep && ep->isAttAvail()) {
            best.found    = true;
            best.epochIdx = j;
            best.dIdx     = std::abs(j - idx);
            best.yawDeg   = ep->yaw();
            return true;
        }
        return false;
    };

    if (testAt(idx)) return best;

    for (int off = 1; off <= maxLookEpochs; ++off) {
        const int j = idx - off;
        if (j >= minIdx && testAt(j)) return best;

        const int k = idx + off;
        if (k <= maxIdx && testAt(k)) return best;

        if (j < minIdx && k > maxIdx) break;
    }
    return best;
}

//Pulse hjelpers for epoch position

struct NearestPosIdx {
    bool   found   = false;
    int    epochIdx = -1;   // where the GNSS was found
    int    dIdx     = 0;    // index distance from the tapped epoch
    Position pos;           // the GNSS position
};

// Search outward by index, but clamp to [minIdx, maxIdx] (inclusive).
static NearestPosIdx findNearestGNSSByIndexRanged(Dataset* ds,
                                                  int idx,
                                                  int maxLookEpochs,
                                                  int minIdx,
                                                  int maxIdx)
{
    NearestPosIdx best;
    if (!ds) return best;

    const int last = ds->size() - 1;
    if (last < 0) return best;

    // clamp bounds to dataset
    minIdx = std::max(0, std::min(minIdx, last));
    maxIdx = std::max(minIdx, std::min(maxIdx, last));

    // clamp starting idx into the band
    idx = std::max(minIdx, std::min(idx, maxIdx));

    auto testAt = [&](int j)->bool {
        if (j < minIdx || j > maxIdx) return false;

        if (auto* ep = ds->fromIndex(j)) {

            auto dt = ep->getPositionDataType();

            // Treat both raw and interpolated GNSS as “available”
            if (dt == DataType::kRaw || dt == DataType::kInterpolated) {
                best.found    = true;
                best.epochIdx = j;
                best.dIdx     = std::abs(j - idx);
                best.pos      = ep->getPositionGNSS();
                return true;
            }
        }
        return false;
    };

    // check the tapped epoch first
    if (testAt(idx)) return best;

    // then expand symmetrically
    for (int off = 1; off <= maxLookEpochs; ++off) {
        const int j = idx - off;
        if (j >= minIdx && testAt(j)) return best;

        const int k = idx + off;
        if (k <= maxIdx && testAt(k)) return best;

        if (j < minIdx && k > maxIdx) break;
    }
    return best; // not found
}

//Pulse helpers for calculating the exact position

struct GeoPoint { double lat, lon; };
struct TapSolve {
    bool   ok = false;
    GeoPoint point{};
    bool   wasWaterColumn = true;
    double r_slant = NAN, depth = NAN, r_cross = NAN;
    int    side = 0;   // -1 left, +1 right
};

static inline double deg2rad(double d) { return d * M_PI / 180.0; }
constexpr double kWaterMargin = 0.05;

static inline double wrap2pi(double r){ double x=fmod(r, 2.0*M_PI); return x<0?x+2.0*M_PI:x; }

TapSolve solveSidescanTap(const GeoPoint& boat,
                          double yaw_rad,       // radians, 0=N, +CW
                          double r_slant_m,     // cursor_distance (m)
                          double depth_m,       // bottom distance (m)
                          int side /*-1 left, +1 right*/)
{
    TapSolve out; out.r_slant = r_slant_m; out.depth = depth_m; out.side = side;

    if (!std::isfinite(r_slant_m) || !std::isfinite(depth_m) || side==0) {
        return out; // invalid inputs
    }

    if (r_slant_m <= depth_m + 0.05) { // small margin
        out.ok = true;
        out.wasWaterColumn = true;
        out.point = boat;
        return out;
    }

    const double r_cross = std::sqrt(std::max(0.0, r_slant_m*r_slant_m - depth_m*depth_m));
    const double bearing = wrap2pi(yaw_rad + (side>0 ? +M_PI/2.0 : -M_PI/2.0));
    const double north   = r_cross * std::cos(bearing);
    const double east    = r_cross * std::sin(bearing);

    const double m_per_deg_lat = 111320.0;
    const double m_per_deg_lon = 111320.0 * std::cos(boat.lat * M_PI/180.0);

    out.point.lat = boat.lat + north / m_per_deg_lat;
    out.point.lon = boat.lon + east  / m_per_deg_lon;
    out.ok = true;
    out.wasWaterColumn = false;
    out.r_cross = r_cross;
    return out;
}

//Fix challenge with manipulated echograms

static inline double clamp01(double v){ return v < 0 ? 0 : (v > 1 ? 1 : v); }

// returns t in [0..1], where 0 means cursor.distance.from and 1 means cursor.distance.to

void Plot2DAim::setPause(Plot2D* parent, Dataset* dataset, bool on) {
    if (paused_ == on) return;

    echogramPause_ = on;
    paused_        = on;

    if (on) {
        // Make sure cursor_.indexes matches the *current* orientation/scale
        // before we freeze any “at pause” snapshots.
        parent->reindexingCursor();

        // Snapshot the rightmost (newest) epoch on screen and visible columns
        lastIndexAtPause_   = parent->rightmostEpochOnScreen();
        visibleColsAtPause_ = parent->visibleColsOnScreen();

        // (Optional) touch the transform for completeness — we don’t use it here now
        (void)dataset;
        auto& canvas = parent->canvas();
        const QTransform W = canvas.painter()->worldTransform();
        Q_UNUSED(W);
    } else {
        lastIndexAtPause_   = -1;
        visibleColsAtPause_ = 0;
        needClearUi_        = true; // clear popup/crosshair on unpause
    }
}

double Plot2DAim::rangeTFromDeviceTap(const QPoint& dev, int /*W*/, int H) const
{
    // Pure Y→t mapping in device space. No mirroring here.
    return clamp01(double(dev.y()) / double(H));
}

//Pulse, retrieve runtime preferences
void Plot2DAim::applyRuntime(const QVariantMap& m)
{
    if (m.contains("echogramPause"))
    {
        if (m.contains("echogramPause")) {
            const bool newPause = m.value("echogramPause").toBool();
            echogramPause_ = newPause;
            if (paused_ && !newPause) {
                needClearUi_ = true;
            }
        }
    }
    if (m.contains("isSideScanLeftHand"))  isSideScanLeftHand_ = m.value("isSideScanLeftHand").toBool();
    if (m.contains("isSideScan2DView"))    isSideScan2DView_   = m.value("isSideScan2DView").toBool();
    if (m.contains("useMetricDepth"))      isMetric_           = m.value("useMetricDepth").toBool();
    if (m.contains("echogramSpeed"))       echogramSpeed_      = m.value("echogramSpeed").toDouble();
}

bool Plot2DAim::isTapInsideZoom(Plot2D* parent, int devX, int devY) const
{
    if (!cand_.active)
        return false;

    const QPoint raw(devX, devY);

    //Somewhere the zoom box was tapped, regardless where
    if (cand_.infoRect.contains(raw))
        return true;

    auto& canvas = parent->canvas();
    const QPoint rot = devRotNeg90(raw, canvas.width());
    //Somewhere the zoom box was tapped, regardless where
    if (cand_.infoRect.contains(rot))
        return true;

    return false;
}

// Draw the aim (upstream cursor correctness + your Plot2DZoom panel/buttons), sync-fixed
bool Plot2DAim::draw(Plot2D* parent, Dataset* dataset)
{
    setPause(parent, dataset, echogramPause_);

    auto& canvas = parent->canvas();
    auto& cursor = parent->cursor();

    if (needClearUi_) {
        cand_.active     = false;
        cand_.haveTarget = false;
        cursor.setMouse(-1, -1);
        cand_.anchorDev  = QPoint(-1, -1);   // OVERLAY coords
        cand_.crossDev   = QPoint(-1, -1);   // LOGICAL/PIXMAP coords
        needClearUi_     = false;
    }

    if (!dataset)
        return false;

    // Ability ONLY active when paused
    const bool loupeEnabled = echogramPause_;
    if (!loupeEnabled) {
        cand_.active = false;
        cand_.haveTarget = false;
        beenEpochEvent_ = false;
        return false;
    }

    if ((cursor.mouseX < 0 || cursor.mouseY < 0) && (cursor.selectEpochIndx == -1))
        return false;

    QPainter* p = canvas.painter();

    // Pen/font like upstream
    {
        QPen pen;
        pen.setWidth(lineWidth_);
        pen.setColor(lineColor_);
        p->setPen(pen);

        QFont font("Asap", 14 * scaleFactor_, QFont::Normal);
        font.setPixelSize(18 * scaleFactor_);
        p->setFont(font);
    }

    const bool hasTap = beenEpochEvent_ && loupeEnabled;
    if (beenEpochEvent_ && !loupeEnabled)
        beenEpochEvent_ = false;

    const bool isSideScan = cursor.channel1.isValid() && cursor.channel2.isValid();
    const bool isHorizontal = parent->isHorizontal();

    // SAME condition as Plot2D::getImage() (plus side-scan guard)
    const bool flipImage = isHorizontal && isSideScan && isSideScan2DView_ && isSideScanLeftHand_;

    // -----------------------------
    // Upstream: if epoch is selected, reposition cursor.mouseX/Y
    // -----------------------------
    if (cursor.selectEpochIndx != -1) {
        auto* ep = dataset->fromIndex(cursor.selectEpochIndx);
        int offsetX = 0;
        int halfCanvas = canvas.width() / 2;
        int withoutHalf = dataset->size() - halfCanvas;

        if (cursor.selectEpochIndx >= withoutHalf) {
            offsetX = cursor.selectEpochIndx - withoutHalf;
        }

        if (ep) {
            ChannelId channelId = cursor.channel1;
            uint8_t subChannelId = cursor.subChannel1;

            const auto datasetChannels = dataset->channelsList();
            if (!channelId.isValid() && !datasetChannels.empty()) {
                channelId = datasetChannels.at(0).channelId_;
                subChannelId = datasetChannels.at(0).subChannelId_;
            }

            auto* chartPtr = ep->chart(channelId, subChannelId);
            if (!chartPtr && !datasetChannels.empty()) {
                chartPtr = ep->chart(datasetChannels.at(0).channelId_, datasetChannels.at(0).subChannelId_);
            }

            if (chartPtr) {
                const int x = canvas.width() / 2 + offsetX;

                float bottomDistance = chartPtr->bottomProcessing.distance;
                if (!std::isfinite(bottomDistance))
                    bottomDistance = 0.0f;

                const float distanceRange = cursor.distance.range();
                int y = (cursor.channel2 != channelNone()) ? canvas.height() / 2 : 0;
                if (std::isfinite(distanceRange) && std::abs(distanceRange) > 1e-6f) {
                    const float yFloat = (cursor.channel2 != channelNone())
                        ? static_cast<float>(canvas.height()) * 0.5f
                            - static_cast<float>(canvas.height()) * (bottomDistance / distanceRange)
                    : static_cast<float>(canvas.height()) * (bottomDistance / distanceRange);
                    y = qRound(yFloat);
                }

                y = qBound(0, y, qMax(0, canvas.height() - 1));
                cursor.setMouse(x, y);
            }
        }
    }

    const int H = qMax(1, canvas.height());
    const int W = qMax(1, canvas.width());

    // rawPt: what cursor currently reports (matches finger/display Y for the flip case)
    QPointF rawPt(cursor.mouseX, cursor.mouseY);
    rawPt.setX(qBound(0.0, rawPt.x(), double(W - 1)));
    rawPt.setY(qBound(0.0, rawPt.y(), double(H - 1)));

    // crossLogical: the logical/pixmap coordinate we MUST use for crosshair + zoom crop
    QPointF crossLogical = rawPt;
    if (flipImage) {
        crossLogical.setY(double(H - 1) - crossLogical.y());
    }

    // Mapping logical -> overlay/device for UI placement & hit testing
    const QRect deviceVp = p->viewport();
    const QTransform L2D = p->combinedTransform();
    auto logicalToOverlay = [&](const QPointF& pt) -> QPoint {
        return (L2D.map(pt).toPoint() - deviceVp.topLeft());
    };

    bool eventConsumed = false;
    const bool freshPressForThisEvent = touchJustPressed_;

    // ---------------------------------------------------------
    // Early drag detection (must run BEFORE the panel hit-test).
    //
    // If this event is NOT a fresh press while the zoom box is already
    // active, it is a drag continuation from the echogram.  Mark it now so
    // the panel hit-test below can skip interception.
    //
    // Without this, an echogram drag that passes through the panel area sets
    // eventConsumed = true, which prevents the crosshair from updating and
    // causes the visible "freeze + jump" flicker.
    // ---------------------------------------------------------
    if (hasTap && cand_.active && !freshPressForThisEvent) {
        touchMovedDuringPress_ = true;
    }

    // ---------------------------------------------------------
    // 1) If popup is active and we got a NON-DRAG event: PANEL/BUTTONS WIN.
    //    Save Waypoint is allowed only on a fresh press that started on that button.
    //    A drag/long-press stream that started on the echogram may pass over the
    //    button visually, but must never fire a waypoint – and must not freeze
    //    the crosshair either (hence the !touchMovedDuringPress_ guard).
    // ---------------------------------------------------------
    if (cand_.active && hasTap && !touchMovedDuringPress_) {
        const QPoint tapOverlay = logicalToOverlay(crossLogical);

        const int pad = 20 * scaleFactor_;
        const QRect panelHit = cand_.infoRect.adjusted(-pad, -pad, +pad, +pad);
        const QRect abortHit = cand_.btnAbortRect.adjusted(-pad, -pad, +pad, +pad);
        const QRect addHit   = cand_.btnAddRect  .adjusted(-pad, -pad, +pad, +pad);

        if (panelHit.contains(tapOverlay)) {
            const bool onAbort = abortHit.contains(tapOverlay);
            const bool onAdd   = (!cand_.btnAddRect.isEmpty() && addHit.contains(tapOverlay));

            beenEpochEvent_ = false;
            eventConsumed = true;

            if (onAbort) {
                qDebug() << "AddWaypoint: Hit abort";
                cand_.active = false;
                cand_.haveTarget = false;
                cand_.anchorDev = QPoint(-1, -1);
                cand_.crossDev  = QPoint(-1, -1);
                cursor.setMouse(-1, -1);
                touchJustPressed_ = false;
                return true;
            }

            const bool cleanWaypointTap = freshPressForThisEvent
                                          && !touchStartedOnEchogram_
                                          && !touchMovedDuringPress_;


            if (onAdd) {
                bool isDebounceElapsed = debounce_.elapsed() >= kWaypointButtonGuardMs;
                qDebug() << "AddWaypoint: Hit add"
                         << "cand_.haveTarget?" << cand_.haveTarget
                         << "cleanWaypointTap" << cleanWaypointTap
                         << "freshPressForThisEvent" << freshPressForThisEvent
                         << "!touchStartedOnEchogram_" << !touchStartedOnEchogram_
                         << "!touchMovedDuringPress_" << !touchMovedDuringPress_
                         << "debounce_.elapsed() >= kWaypointButtonGuardMs" << isDebounceElapsed;
            }

            if (onAdd && cand_.haveTarget
                && cleanWaypointTap
                && debounce_.elapsed() >= kWaypointButtonGuardMs) {

                qDebug() << "AddWaypoint: Hit add, and also triggered the addWaypoint";
                UdpBroadcaster::instance().sendJsonPoint(
                    cand_.lat,
                    cand_.lon,
                    std::isfinite(cand_.depth) ? cand_.depth : NAN,
                    cand_.model,
                    "Pulse"
                    );

                cand_.active = false;
                cand_.haveTarget = false;
                cand_.anchorDev = QPoint(-1, -1);
                cand_.crossDev  = QPoint(-1, -1);
                cursor.setMouse(-1, -1);
                debounce_.restart();
                touchJustPressed_ = false;
                return true;
            }

            qDebug() << "AddWaypoint: Hit the zoom, but not the buttons";

            // Tap on panel (not buttons), or a dragged touch reaching Add:
            // swallow, do not re-aim behind, and do not save a waypoint.
        }
    }

    // ---------------------------------------------------------
    // 2) If we got an event and it wasn’t consumed: aim update (tap/drag on echogram)
    // ---------------------------------------------------------
    if (hasTap && !eventConsumed) {
        // This input stream touched the echogram, so it is an aim/drag stream.
        // Even if the finger later slides into the zoom button area, it must not
        // be treated as a Save Waypoint button tap.
        touchStartedOnEchogram_ = true;
        if (!freshPressForThisEvent || cand_.active)
            touchMovedDuringPress_ = true;

        const int data_width = dataset->size();

        int epochIdxForTap = -1;
        if (cursor.selectEpochIndx != -1)
            epochIdxForTap = cursor.selectEpochIndx;
        else
            epochIdxForTap = cursor.currentEpochIndx;

        if (epochIdxForTap < 0 || epochIdxForTap >= data_width)
            epochIdxForTap = qBound(0, cursor.currentEpochIndx, data_width - 1);

        // Which side (for SS)
        int side = 0;
        if (isSideScan) {
            if (isSideScan2DView_) {
                side = isSideScanLeftHand_ ? -1 : +1;
            } else {
                const int midY = H / 2;
                // NOTE: in non-2D SS, use LOGICAL y (crossLogical) for side split
                side = (int(crossLogical.y()) < midY) ? -1 : +1;
            }
        }

        // Depth from tapped epoch
        double depth = NAN;
        if (auto* epTap = dataset->fromIndex(epochIdxForTap)) {
            if (isSideScan) {
                auto [selCh, selSub, selName] = parent->getSelectedChannelId();
                if (auto* eg = epTap->chart(selCh, selSub)) {
                    depth = eg->bottomProcessing.getDistance();
                }
            } else {
                depth = epTap->rangeFinder();
            }
            if (!std::isfinite(depth) || depth < 0) {
                depth = epTap->rangeFinder();
            }
        }

        // ---- crossMeters/slant range: compute from DISPLAY Y (finger expectation) ----
        // displayY for the tap frame is rawPt.y()
        const double axisRange = std::abs(double(cursor.distance.to - cursor.distance.from));
        double tDisp = (H > 0) ? (double(rawPt.y()) / double(H)) : 0.0;
        tDisp = qBound(0.0, tDisp, 1.0);

        double cursor_distance = 0.0;
        if (isSideScan && isSideScan2DView_) {
            cursor_distance = std::abs(tDisp * axisRange);
        } else {
            const double val = double(cursor.distance.from) + tDisp * double(cursor.distance.to - cursor.distance.from);
            cursor_distance = std::abs(val);
        }

        const double depthAbs  = std::isfinite(depth) ? std::abs(depth) : NAN;
        const double rSlantAbs = std::isfinite(cursor_distance) ? std::abs(cursor_distance) : NAN;

        // Nearest GNSS + yaw
        const int maxLookEpochs = 12;
        const int lastCap = isPaused() ? lastIndexAtPause_ : (data_width - 1);

        auto nearestPos = findNearestGNSSByIndexRanged(dataset, epochIdxForTap,
                                                       maxLookEpochs, 0, lastCap);
        auto nearestYaw = findNearestYawByIndexRanged(dataset, epochIdxForTap,
                                                      maxLookEpochs, 0, lastCap);

        if (!nearestPos.found)
            nearestPos = findNearestGNSSByIndexRanged(dataset, epochIdxForTap,
                                                      maxLookEpochs, 0, data_width - 1);
        if (!nearestYaw.found)
            nearestYaw = findNearestYawByIndexRanged(dataset, epochIdxForTap,
                                                     maxLookEpochs, 0, data_width - 1);

        // Solve target
        double txLat = NAN, txLon = NAN;
        bool haveTarget = false;

        if (nearestPos.found && nearestYaw.found) {
            const GeoPoint boat{ nearestPos.pos.lla.latitude, nearestPos.pos.lla.longitude };
            const double yaw_rad = deg2rad(nearestYaw.yawDeg);

            const bool isDualSS = isSideScan && !isSideScan2DView_;
            const bool forceWaterColumn = !isDualSS;

            const bool waterColumn = forceWaterColumn
                                     || !std::isfinite(depthAbs)
                                     || (std::isfinite(rSlantAbs) && (rSlantAbs <= depthAbs + kWaterMargin));

            if (waterColumn) {
                txLat = boat.lat;
                txLon = boat.lon;
                haveTarget = true;
            } else {
                const auto sol = solveSidescanTap(boat, yaw_rad, rSlantAbs, depthAbs, side);
                if (sol.ok && !sol.wasWaterColumn) {
                    txLat = sol.point.lat;
                    txLon = sol.point.lon;
                    haveTarget = true;
                }
            }
        }

        // Store candidate:
        const bool wasActive = cand_.active;
        cand_.active      = true;
        cand_.crossDev    = crossLogical.toPoint();          // LOGICAL/PIXMAP (flipped when needed)
        cand_.anchorDev   = logicalToOverlay(crossLogical);  // OVERLAY/DEVICE
        cand_.lat         = txLat;
        cand_.lon         = txLon;
        cand_.depth       = depthAbs;
        cand_.yawDeg      = nearestYaw.found ? nearestYaw.yawDeg : NAN;
        cand_.model       = isSideScan ? "SS" : "2D";
        cand_.tapEpochIdx = epochIdxForTap;
        cand_.tapRangeM   = rSlantAbs;
        cand_.tapIsSS     = isSideScan;
        cand_.tapSide     = side;
        cand_.haveTarget  = haveTarget;
        // NOTE: do NOT restart debounce_ here.  debounce_ is restarted only
        // after a successful Add (below), so the 2-second guard purely prevents
        // accidental double-adds rather than delaying the very first Add after
        // the zoom box appears.

        beenEpochEvent_ = false; // consume
    }

    if (hasTap)
        touchJustPressed_ = false;

    // Let it follow cursor movement when no discrete event
    if (cand_.active && !hasTap) {
        cand_.crossDev  = crossLogical.toPoint();
        cand_.anchorDev = logicalToOverlay(crossLogical);
    }

    // Final aim point for draw + zoom + telemetry
    const QPointF aimLogical = cand_.active ? QPointF(cand_.crossDev) : crossLogical;

    // ---- Telemetry crossMeters: compute from DISPLAY Y (inverse-flip if needed) ----
    double displayY = aimLogical.y();
    if (flipImage) {
        displayY = double(H - 1) - displayY;
    }
    displayY = qBound(0.0, displayY, double(H - 1));

    const double axisRange = std::abs(double(cursor.distance.to - cursor.distance.from));
    double tDisp = (H > 0) ? (displayY / double(H)) : 0.0;
    tDisp = qBound(0.0, tDisp, 1.0);

    double cursor_distance = 0.0;
    if (isSideScan && isSideScan2DView_) {
        cursor_distance = std::abs(tDisp * axisRange);
    } else {
        const double val = double(cursor.distance.from) + tDisp * double(cursor.distance.to - cursor.distance.from);
        cursor_distance = std::abs(val);
    }

    // Draw outer crosshair LAST (synced with zoom center)
    {
        const QPoint drawPt = aimLogical.toPoint();
        p->drawLine(0,          drawPt.y(), canvas.width(),  drawPt.y());
        p->drawLine(drawPt.x(), 0,          drawPt.x(),      canvas.height());
    }

    // Draw your zoom panel when active
    if (cand_.active) {
        Plot2DZoom::Input zin;
        zin.echPixmap      = &parent->echogramPixmap();
        zin.centerWorld    = QPointF(cand_.crossDev); // pixmap crop space (logical)
        zin.anchorPx       = cand_.anchorDev;         // overlay UI space
        zin.viewport       = QRect(0, 0, deviceVp.width(), deviceVp.height());
        zin.scale          = scaleFactor_;
        zin.depthMeters    = std::isfinite(cand_.depth) ? cand_.depth : NAN;
        zin.crossMeters    = std::isfinite(cursor_distance) ? cursor_distance : NAN;
        zin.showAddBtn     = cand_.haveTarget;
        zin.rotateForView  = !parent->isHorizontal();
        zin.flipForLeftHand= (isSideScan2DView_ && isSideScanLeftHand_);
        zin.boxSizePx      = 250;
        zin.zoomFactor     = 3;
        zin.dirSide        = cand_.tapSide;
        zin.isDualSideScan = (isSideScan && !isSideScan2DView_);
        zin.isMetric       = isMetric_;
        zin.captureTile    = cand_.haveTarget;

        p->save();
        p->resetTransform();
        p->setViewport(QRect(0, 0, deviceVp.width(), deviceVp.height()));
        p->setWindow  (QRect(0, 0, deviceVp.width(), deviceVp.height()));

        const auto out = zoom_.draw(p, zin);
        p->restore();

        cand_.infoRect     = out.panelRect;
        cand_.tapDeadRect  = out.tapDeadRect;
        cand_.btnAbortRect = out.abortRect;
        cand_.btnAddRect   = out.addRect;
        cand_.zoomTile     = out.zoomTile;
    }

    return true;
}


// THIS VERSION: Perfect for everything but 2D view left hand side
/*
bool Plot2DAim::draw(Plot2D* parent, Dataset* dataset)
{
    setPause(parent, dataset, echogramPause_);

    auto& canvas = parent->canvas();
    auto& cursor = parent->cursor();

    if (needClearUi_) {
        cand_.active     = false;
        cand_.haveTarget = false;
        cursor.setMouse(-1, -1);
        cand_.anchorDev  = QPoint(-1, -1);   // OVERLAY coords in this method
        cand_.crossDev   = QPoint(-1, -1);   // LOGICAL/PIXMAP coords in this method
        needClearUi_     = false;
    }

    if (!dataset)
        return false;

    // Ability ONLY active when paused
    const bool loupeEnabled = echogramPause_;
    if (!loupeEnabled) {
        cand_.active = false;
        cand_.haveTarget = false;
        beenEpochEvent_ = false;
        return false;
    }

    if ((cursor.mouseX < 0 || cursor.mouseY < 0) && (cursor.selectEpochIndx == -1))
        return false;

    QPainter* p = canvas.painter();

    // Pen/font like upstream
    {
        QPen pen;
        pen.setWidth(lineWidth_);
        pen.setColor(lineColor_);
        p->setPen(pen);

        QFont font("Asap", 14 * scaleFactor_, QFont::Normal);
        font.setPixelSize(18 * scaleFactor_);
        p->setFont(font);
    }

    const bool hasTap = beenEpochEvent_ && loupeEnabled;
    if (beenEpochEvent_ && !loupeEnabled)
        beenEpochEvent_ = false;

    // -----------------------------
    // Upstream: if epoch is selected, reposition cursor.mouseX/Y
    // -----------------------------
    if (cursor.selectEpochIndx != -1) {
        auto* ep = dataset->fromIndex(cursor.selectEpochIndx);
        int offsetX = 0;
        int halfCanvas = canvas.width() / 2;
        int withoutHalf = dataset->size() - halfCanvas;

        if (cursor.selectEpochIndx >= withoutHalf) {
            offsetX = cursor.selectEpochIndx - withoutHalf;
        }

        if (ep) {
            ChannelId channelId = cursor.channel1;
            uint8_t subChannelId = cursor.subChannel1;

            const auto datasetChannels = dataset->channelsList();
            if (!channelId.isValid() && !datasetChannels.empty()) {
                channelId = datasetChannels.at(0).channelId_;
                subChannelId = datasetChannels.at(0).subChannelId_;
            }

            auto* chartPtr = ep->chart(channelId, subChannelId);
            if (!chartPtr && !datasetChannels.empty()) {
                chartPtr = ep->chart(datasetChannels.at(0).channelId_, datasetChannels.at(0).subChannelId_);
            }

            if (chartPtr) {
                const int x = canvas.width() / 2 + offsetX;

                float bottomDistance = chartPtr->bottomProcessing.distance;
                if (!std::isfinite(bottomDistance))
                    bottomDistance = 0.0f;

                const float distanceRange = cursor.distance.range();
                int y = (cursor.channel2.isValid()) ? canvas.height() / 2 : 0;

                if (std::isfinite(distanceRange) && std::abs(distanceRange) > 1e-6f) {
                    const float yFloat = (cursor.channel2.isValid())
                    ? static_cast<float>(canvas.height()) * 0.5f
                            - static_cast<float>(canvas.height()) * (bottomDistance / distanceRange)
                    : static_cast<float>(canvas.height()) * (bottomDistance / distanceRange);
                    y = qRound(yFloat);
                }

                y = qBound(0, y, qMax(0, canvas.height() - 1));
                cursor.setMouse(x, y);
            }
        }
    }

    // Crosshair point in *logical/pixmap* space (correct crop space)
    QPointF crossLogical(cursor.mouseX, cursor.mouseY);
    crossLogical.setX(qBound(0.0, crossLogical.x(), double(qMax(0, canvas.width() - 1))));
    crossLogical.setY(qBound(0.0, crossLogical.y(), double(qMax(0, canvas.height() - 1))));

    // Mapping logical -> overlay/device for UI placement & hit testing
    const QRect deviceVp = p->viewport();
    const QTransform L2D = p->combinedTransform();
    auto logicalToOverlay = [&](const QPointF& pt) -> QPoint {
        return (L2D.map(pt).toPoint() - deviceVp.topLeft());
    };

    const bool isSideScan = cursor.channel1.isValid() && cursor.channel2.isValid();

    bool eventConsumed = false;

    // ---------------------------------------------------------
    // 1) If popup is active and we got an event: PANEL/BUTTONS MUST WIN FIRST.
    //    This is what re-enables tapping the buttons.
    // ---------------------------------------------------------
    if (cand_.active && hasTap) {
        const QPoint tapOverlay = logicalToOverlay(crossLogical);

        const int pad = 20 * scaleFactor_;
        const QRect panelHit = cand_.infoRect.adjusted(-pad, -pad, +pad, +pad);
        const QRect abortHit = cand_.btnAbortRect.adjusted(-pad, -pad, +pad, +pad);
        const QRect addHit   = cand_.btnAddRect  .adjusted(-pad, -pad, +pad, +pad);

        if (panelHit.contains(tapOverlay)) {
            const bool onAbort = abortHit.contains(tapOverlay);
            const bool onAdd   = (!cand_.btnAddRect.isEmpty() && addHit.contains(tapOverlay));

            beenEpochEvent_ = false;
            eventConsumed = true;

            if (onAbort) {
                cand_.active = false;
                cand_.haveTarget = false;
                cand_.anchorDev = QPoint(-1, -1);
                cand_.crossDev  = QPoint(-1, -1);
                cursor.setMouse(-1, -1);
                return true;
            }

            if (onAdd && cand_.haveTarget) {
                UdpBroadcaster::instance().sendJsonPoint(
                    cand_.lat,
                    cand_.lon,
                    std::isfinite(cand_.depth) ? cand_.depth : NAN,
                    cand_.model,
                    "Pulse"
                    );

                cand_.active = false;
                cand_.haveTarget = false;
                cand_.anchorDev = QPoint(-1, -1);
                cand_.crossDev  = QPoint(-1, -1);
                cursor.setMouse(-1, -1);
                return true;
            }

            // Tap on panel but not on buttons => swallow it (do NOT re-aim behind).
            // IMPORTANT: do NOT return; we still draw the panel this frame (no flicker).
        }
    }

    // ---------------------------------------------------------
    // 2) If we got an event and it wasn’t consumed by panel/buttons:
    //    treat it as “aim update” (works for both tap and drag on the echogram).
    // ---------------------------------------------------------
    if (hasTap && !eventConsumed) {
        const int data_width = dataset->size();

        int epochIdxForTap = -1;
        if (cursor.selectEpochIndx != -1)
            epochIdxForTap = cursor.selectEpochIndx;
        else
            epochIdxForTap = cursor.currentEpochIndx;

        if (epochIdxForTap < 0 || epochIdxForTap >= data_width)
            epochIdxForTap = qBound(0, cursor.currentEpochIndx, data_width - 1);

        // Which side (for SS)
        int side = 0;
        if (isSideScan) {
            if (isSideScan2DView_) {
                side = isSideScanLeftHand_ ? -1 : +1;
            } else {
                const int midY = canvas.height() / 2;
                side = (int(crossLogical.y()) < midY) ? -1 : +1;
            }
        }

        // Depth from tapped epoch
        double depth = NAN;
        if (auto* epTap = dataset->fromIndex(epochIdxForTap)) {
            if (isSideScan) {
                auto [selCh, selSub, selName] = parent->getSelectedChannelId();
                if (auto* eg = epTap->chart(selCh, selSub)) {
                    depth = eg->bottomProcessing.getDistance();
                }
            } else {
                depth = epTap->rangeFinder();
            }
            if (!std::isfinite(depth) || depth < 0) {
                depth = epTap->rangeFinder();
            }
        }

        // crossMeters from crossLogical
        const double axisRange = std::abs(double(cursor.distance.to - cursor.distance.from));
        double t = (canvas.height() > 0) ? (double(crossLogical.y()) / double(canvas.height())) : 0.0;
        t = qBound(0.0, t, 1.0);

        if (isSideScan2DView_ && isSideScanLeftHand_)
            t = 1.0 - t;

        double cursor_distance = 0.0;
        if (isSideScan && isSideScan2DView_) {
            cursor_distance = std::abs(t * axisRange);
        } else {
            const double val = double(cursor.distance.from) + t * double(cursor.distance.to - cursor.distance.from);
            cursor_distance = std::abs(val);
        }

        const double depthAbs  = std::isfinite(depth) ? std::abs(depth) : NAN;
        const double rSlantAbs = std::isfinite(cursor_distance) ? std::abs(cursor_distance) : NAN;

        // Nearest GNSS + yaw
        const int maxLookEpochs = 12;
        const int lastCap = isPaused() ? lastIndexAtPause_ : (data_width - 1);

        auto nearestPos = findNearestGNSSByIndexRanged(dataset, epochIdxForTap,
                                                       maxLookEpochs, 0, lastCap);
        auto nearestYaw = findNearestYawByIndexRanged(dataset, epochIdxForTap,
                                                      maxLookEpochs, 0, lastCap);

        if (!nearestPos.found)
            nearestPos = findNearestGNSSByIndexRanged(dataset, epochIdxForTap,
                                                      maxLookEpochs, 0, data_width - 1);
        if (!nearestYaw.found)
            nearestYaw = findNearestYawByIndexRanged(dataset, epochIdxForTap,
                                                     maxLookEpochs, 0, data_width - 1);

        // Solve target
        double txLat = NAN, txLon = NAN;
        bool haveTarget = false;

        if (nearestPos.found && nearestYaw.found) {
            const GeoPoint boat{ nearestPos.pos.lla.latitude, nearestPos.pos.lla.longitude };
            const double yaw_rad = deg2rad(nearestYaw.yawDeg);

            const bool isDualSS = isSideScan && !isSideScan2DView_;
            const bool forceWaterColumn = !isDualSS;

            const bool waterColumn = forceWaterColumn
                                     || !std::isfinite(depthAbs)
                                     || (std::isfinite(rSlantAbs) && (rSlantAbs <= depthAbs + kWaterMargin));

            if (waterColumn) {
                txLat = boat.lat;
                txLon = boat.lon;
                haveTarget = true;
            } else {
                const auto sol = solveSidescanTap(boat, yaw_rad, rSlantAbs, depthAbs, side);
                if (sol.ok && !sol.wasWaterColumn) {
                    txLat = sol.point.lat;
                    txLon = sol.point.lon;
                    haveTarget = true;
                }
            }
        }

        // Store candidate:
        cand_.active      = true;
        cand_.crossDev    = crossLogical.toPoint();          // logical/pixmap
        cand_.anchorDev   = logicalToOverlay(crossLogical);  // overlay/device
        cursor.setMouse(cand_.crossDev.x(), cand_.crossDev.y());

        cand_.lat         = txLat;
        cand_.lon         = txLon;
        cand_.depth       = depthAbs;
        cand_.yawDeg      = nearestYaw.found ? nearestYaw.yawDeg : NAN;
        cand_.model       = isSideScan ? "SS" : "2D";
        cand_.tapEpochIdx = epochIdxForTap;
        cand_.tapRangeM   = rSlantAbs;
        cand_.tapIsSS     = isSideScan;
        cand_.tapSide     = side;
        cand_.haveTarget  = haveTarget;

        beenEpochEvent_ = false; // consume
    }

    // Let it follow cursor movement when no discrete event (hover-like)
    if (cand_.active && !hasTap) {
        cand_.crossDev  = crossLogical.toPoint();
        cand_.anchorDev = logicalToOverlay(crossLogical);
    }

    // Final aim point for draw + zoom + telemetry
    const QPointF aimLogical = cand_.active ? QPointF(cand_.crossDev) : crossLogical;

    // Telemetry: crossMeters from aimLogical
    const double axisRange = std::abs(double(cursor.distance.to - cursor.distance.from));
    double t = (canvas.height() > 0) ? (double(aimLogical.y()) / double(canvas.height())) : 0.0;
    t = qBound(0.0, t, 1.0);

    if (isSideScan2DView_ && isSideScanLeftHand_)
        t = 1.0 - t;

    double cursor_distance = 0.0;
    if (isSideScan && isSideScan2DView_) {
        cursor_distance = std::abs(t * axisRange);
    } else {
        const double val = double(cursor.distance.from) + t * double(cursor.distance.to - cursor.distance.from);
        cursor_distance = std::abs(val);
    }

    // Draw outer crosshair LAST (synced with zoom center)
    {
        const QPoint drawPt = aimLogical.toPoint();
        p->drawLine(0,          drawPt.y(), canvas.width(),  drawPt.y());
        p->drawLine(drawPt.x(), 0,          drawPt.x(),      canvas.height());
    }

    // Draw your zoom panel when active
    if (cand_.active) {
        Plot2DZoom::Input zin;
        zin.echPixmap      = &parent->echogramPixmap();
        zin.centerWorld    = QPointF(cand_.crossDev); // pixmap crop space
        zin.anchorPx       = cand_.anchorDev;         // overlay UI space
        zin.viewport       = QRect(0, 0, deviceVp.width(), deviceVp.height());
        zin.scale          = scaleFactor_;
        zin.depthMeters    = std::isfinite(cand_.depth) ? cand_.depth : NAN;
        zin.crossMeters    = std::isfinite(cursor_distance) ? cursor_distance : NAN;
        zin.showAddBtn     = cand_.haveTarget;
        zin.rotateForView  = !parent->isHorizontal();
        zin.flipForLeftHand= (isSideScan2DView_ && isSideScanLeftHand_);
        zin.boxSizePx      = 250;
        zin.zoomFactor     = 3;
        zin.dirSide        = cand_.tapSide;
        zin.isDualSideScan = (isSideScan && !isSideScan2DView_);
        zin.isMetric       = isMetric_;
        zin.captureTile    = cand_.haveTarget;

        p->save();
        p->resetTransform();
        p->setViewport(QRect(0, 0, deviceVp.width(), deviceVp.height()));
        p->setWindow  (QRect(0, 0, deviceVp.width(), deviceVp.height()));

        const auto out = zoom_.draw(p, zin);
        p->restore();

        cand_.infoRect     = out.panelRect;
        cand_.tapDeadRect  = out.tapDeadRect;
        cand_.btnAbortRect = out.abortRect;
        cand_.btnAddRect   = out.addRect;
        cand_.zoomTile     = out.zoomTile;
    }

    return true;
}
*/


void Plot2DAim::setEpochEventState(bool state)
{
    const bool staleStream = touchStreamTimer_.isValid()
    && touchStreamTimer_.elapsed() > kTouchStreamFallbackReleaseMs;

    if (state) {
        // A fresh press can start either after an explicit release, or after a
        // long quiet gap. The quiet-gap fallback keeps this robust if upstream
        // only sends "true" events and never sends a matching release.
        if (!touchDown_ || staleStream) {
            touchJustPressed_ = true;
            touchStartedOnEchogram_ = false;
            touchMovedDuringPress_ = false;
        }
        touchDown_ = true;
        touchStreamTimer_.restart();
    } else {
        touchDown_ = false;
        touchJustPressed_ = false;
        touchStartedOnEchogram_ = false;
        touchMovedDuringPress_ = false;
        touchStreamTimer_.restart();
    }

    beenEpochEvent_ = state;
}




