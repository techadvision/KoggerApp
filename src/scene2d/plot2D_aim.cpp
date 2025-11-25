#include "plot2D_aim.h"
#include "plot2D.h"
#include "udp_broadcaster.h"
#include <QtMath>
#include <cmath>
#include <algorithm>
#include <QPainterPath>


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
}

//Pulse helper for echogram stretch
static inline int epochToLogicalXScaled(int i, int datasetSize, int canvasW, int visibleCols)
{
    const int last  = datasetSize - 1;
    const int start = std::max(0, last - visibleCols + 1);
    const int left  = canvasW - visibleCols;
    return left + (i - start); // may be < left (off left) or >= canvasW (off right)
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
        if (auto* ep = ds->fromIndex(j); ep && ep->isPosAvail()) {
            best.found   = true;
            best.epochIdx= j;
            best.dIdx    = std::abs(j - idx);
            best.pos     = ep->getPositionGNSS();
            return true;
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

    /*
    if (paused_ == on) return;
    auto& canvas = parent->canvas();
    auto& cursor = parent->cursor();

    echogramPause_ = on;
    paused_ = on;
    if (on) {
        lastIndexAtPause_   = parent->rightmostEpochOnScreen();
        visibleColsAtPause_ = parent->visibleColsOnScreen();
        const QTransform W = canvas.painter()->worldTransform();
        const double sx = std::max(1e-6, W.m11());
    } else {
        lastIndexAtPause_   = -1;
        visibleColsAtPause_ = 0;
        needClearUi_ = true; // (your existing UI clear flag)
    }
*/
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
}

//Draw the aim (adapted for Pulse)
bool Plot2DAim::draw(Plot2D* parent, Dataset* dataset)
{
    setPause(parent, dataset, echogramPause_);
    auto& canvas = parent->canvas();
    auto& cursor = parent->cursor();

    if (needClearUi_) {
        cand_.active = false;
        cand_.haveTarget = false;           // if you have this field
        cursor.setMouse(-1, -1);            // hide crosshair
        cand_.anchorDev = QPoint(-1, -1);
        cand_.crossDev  = QPoint(-1, -1);
        needClearUi_ = false;               // done
    }

    if(!dataset)
        return false;

    if (cursor.mouseX < 0 || cursor.mouseY < 0) {
    //if ((cursor.mouseX < 0 || cursor.mouseY < 0) && (cursor.selectEpochIndx == -1)) {
        return false;
    }

    QPainter* p = canvas.painter();

    //const int tapX = cursor.mouseX;
    //const int tapY = cursor.mouseY;

    const QTransform W = p->worldTransform();
    const QTransform Winv = W.inverted();
    const QPointF mouseLogical = Winv.map(QPointF(cursor.mouseX, cursor.mouseY));
    const double sx = std::max(1e-6, W.m11());
    const int visibleCols = visibleColsFromTransform(p->worldTransform(), canvas.width());

    //QPointF tapLogical(-1, -1);
    hasTap_ = false;
    if (beenEpochEvent_ && echogramPause_) {
        //tapLogical = QPointF(cursor.mouseX, cursor.mouseY);
        //pendingTapLogical_ = mouseLogical;
        hasTap_ = true;
    }
    if (beenEpochEvent_ && !echogramPause_) {
        beenEpochEvent_ = false; // ignore
    }
    //const QPoint tapDevAtArm = QPoint(cursor.mouseX, cursor.mouseY);

    if (cursor.selectEpochIndx != -1 && !cand_.active && !hasTap_) {
        const bool isPaused = echogramPause_;
        const int dsSizeForMap  = isPaused ? (lastAtPause() + 1) : dataset->size();
        const int visColsForMap = (isPaused && visibleColsAtPause() > 0)
                                      ? visibleColsAtPause()
                                      : visibleCols;

        const int x = epochToLogicalXScaled(cursor.selectEpochIndx, dsSizeForMap, canvas.width(), visColsForMap);
        //const int x = epochToLogicalXScaled(cursor.selectEpochIndx, dataset->size(), canvas.width(), visibleCols);
        if (x >= 0 && x < canvas.width()) {
            if (auto* ep = dataset->fromIndex(cursor.selectEpochIndx)) {
                if (const auto datasetChannels = dataset->channelsList(); !datasetChannels.empty()) {
                    auto& first = datasetChannels.at(0);
                    if (auto* chart = ep->chart(first.channelId_, first.subChannelId_)) {
                        const int y = (datasetChannels.size() == 2)
                        ? canvas.height()/2 - int(canvas.height() * (chart->bottomProcessing.distance / cursor.distance.range()))
                        : int(canvas.height() * (chart->bottomProcessing.distance / cursor.distance.range()));
                        cursor.setMouse(x, y);
                    }
                }
            }
        }
    }

    const bool isSideScan = cursor.channel1.isValid() && cursor.channel2.isValid();
    const bool isDualSS   = isSideScan && !isSideScan2DView_;

    // DID WE TAP THE PANEL?
    bool tapOnPanel = false;
    QPoint tapDev;
    if (hasTap_ && cand_.active) {
        tapDev = QPoint(cursor.mouseX, cursor.mouseY);     // device space
        if (isDualSS) {
            tapDev = devRotNeg90(tapDev, canvas.width());
        }
        tapOnPanel = cand_.infoRect.contains(tapDev);      // infoRect is device space
    }

    // CREATE CROSS HAIR FROM THE TAP
    QPen pen;
    pen.setWidth(lineWidth_);
    pen.setColor(lineColor_);
    p->setPen(pen);

    QFont font("Asap", 14 * scaleFactor_, QFont::Normal);
    font.setPixelSize(18 * scaleFactor_);
    p->setFont(font);

    // --- crosshair ---
    auto drawCrosshairAtWorld = [&](double lx, double ly){
        const int Wlog = canvas.width();
        const int Hlog = canvas.height();

        // Horizontal line at ly across full world width
        p->drawLine(QPointF(0,    ly), QPointF(Wlog, ly));
        // Vertical line at lx across full world height
        p->drawLine(QPointF(lx, 0),     QPointF(lx,  Hlog));
    };

    //bool drewCrosshair = false;

    if (cand_.active && echogramPause_) {
        if (cand_.crossDev.x() >= 0 && cand_.crossDev.y() >= 0) {

            QPoint devPt = cand_.active ? cand_.crossDev : QPoint(cursor.mouseX, cursor.mouseY);

            // dual-side SS is drawn rotated -90° → rotate the tap to match
            if (isDualSS) {
                // canvas.width() is the device width for this view
                devPt = devRotNeg90(devPt, canvas.width());
            }

            const QPointF crossWorld = Winv.map(QPointF(devPt));
            drawCrosshairAtWorld(crossWorld.x(), crossWorld.y());
            //drewCrosshair = true;
        }
    }


    // --- unified distance from device tap ---
    QPoint devPtForRange = (cand_.active ? cand_.crossDev
                                               : QPoint(cursor.mouseX, cursor.mouseY));


    // Dual-side SS view is drawn rotated -90°. Map tap back to unrotated device axes
    // before deriving the vertical fraction used by rangeTFromDeviceTap().
    if (isSideScan && !isSideScan2DView_) {
        //devPtForRange = devRotNeg90(devPtForRange, canvas.width());
    }

    double t = rangeTFromDeviceTap(devPtForRange, canvas.width(), canvas.height());

    // Single-side SS, left-hand hardware installed → axis is mirrored vertically
    if (isSideScan2DView_ && isSideScanLeftHand_)
        t = 1.0 - t;

    const double axisRange = std::abs(cursor.distance.to - cursor.distance.from);

    double cursor_distance = 0.0;
    if (isSideScan && isSideScan2DView_) {
        // single-side SS: distance from centerline (0..R), independent of from/to signs
        cursor_distance = std::abs(t * axisRange);
    } else {
        // 2D or dual-side SS: keep existing “map to axis then abs”
        const double val = cursor.distance.from + t * (cursor.distance.to - cursor.distance.from);
        cursor_distance = std::abs(val);
    }

    p->setCompositionMode(QPainter::CompositionMode_SourceOver);

    auto [channelId, subIndx, name] = parent->getSelectedChannelId();

    //Capture data for the tapped point
    // --- Capture data for the tapped point (works even if cursor.currentEpochIndx == -1) ---
    if (echogramPause_) {
        const int epochIdxForTap = cursor.currentEpochIndx;

        /*
        const int epochIdxForTapOld =
            parent->getEpochIndxByMousePosPausedAware(p,
                                                    cursor.mouseX,
                                                    cursor.mouseY,
                                                    parent->isHorizontal());
        */
        if (epochIdxForTap >= 0 && epochIdxForTap < dataset->size()) {
            const bool pausedNow = isPaused();
            const bool isSideScan = cursor.channel1.isValid() && cursor.channel2.isValid();

            // Which side (for SS)
            int side = 0;
            if (isSideScan) {
                if (isSideScan2DView_) {
                    side = isSideScanLeftHand_ ? -1 : +1;
                } else {
                    const int midY = canvas.height() / 2;
                    const int tapY = cand_.active ? cand_.crossDev.y() : cursor.mouseY;
                    side = (tapY < midY) ? -1 : +1;
                }
            }

            // Depth from the *tapped* epoch (not from cursor.currentEpochIndx)
            double depth = NAN;
            if (auto* epTap = dataset->fromIndex(epochIdxForTap)) {
                if (isSideScan) {
                    if (auto* eg = epTap->chart(channelId, subIndx)) {
                        depth = eg->bottomProcessing.getDistance();
                    }
                } else {
                    depth = epTap->rangeFinder();
                }
                if (!std::isfinite(depth) || depth < 0) depth = epTap->rangeFinder();
            }

            const int maxLookEpochs = 12;
            const int lastCap = pausedNow ? lastIndexAtPause_ : (dataset->size() - 1);

            auto nearestPos = findNearestGNSSByIndexRanged(dataset, epochIdxForTap,
                                                           maxLookEpochs, 0, lastCap);
            auto nearestYaw = findNearestYawByIndexRanged( dataset, epochIdxForTap,
                                                          maxLookEpochs, 0, lastCap);

            if (nearestPos.found) {
                qDebug () << "AIM: Looked at epoch" << epochIdxForTap << "and found position at" << nearestPos.epochIdx << "positions away" << nearestPos.dIdx;
            }

            // Fallback once across the full dataset if the frozen cap was too tight (first pause edge case)
            if (!nearestPos.found)
                nearestPos = findNearestGNSSByIndexRanged(dataset, epochIdxForTap,
                                                          maxLookEpochs, 0, dataset->size()-1);
            if (!nearestYaw.found)
                nearestYaw = findNearestYawByIndexRanged( dataset, epochIdxForTap,
                                                         maxLookEpochs, 0, dataset->size()-1);

            // Unified slant range already computed above
            const double r_slant   = cursor_distance;
            const double depthAbs  = std::isfinite(depth)   ? std::abs(depth)   : NAN;
            const double rSlantAbs = std::isfinite(r_slant) ? std::abs(r_slant) : NAN;

            // Solve target
            double txLat=NAN, txLon=NAN;
            bool haveTarget=false;
            if (nearestPos.found && nearestYaw.found) {
                const GeoPoint boat{ nearestPos.pos.lla.latitude, nearestPos.pos.lla.longitude };
                const double yaw_rad = deg2rad(nearestYaw.yawDeg);

                // Only permit lateral offsets for *dual-side* SS view.
                // Single-side SS shown as downscan (isSideScan2DView_ == true) is treated as water-column.
                const bool isDualSS = isSideScan && !isSideScan2DView_;
                const bool forceWaterColumn = !isDualSS;

                // Water column when depth unknown OR slant ≤ bottom depth, or in forced mode
                const bool waterColumn = forceWaterColumn
                                         || !std::isfinite(depthAbs)
                                         || (rSlantAbs <= depthAbs + kWaterMargin);

                if (waterColumn) {
                    // beneath the boat
                    txLat = boat.lat;
                    txLon = boat.lon;
                    haveTarget = true;
                } else {
                    // valid lateral hit → offset using yaw ± 90°
                    const auto sol = solveSidescanTap(boat, yaw_rad, rSlantAbs, depthAbs, side);
                    if (sol.ok && !sol.wasWaterColumn) {
                        txLat = sol.point.lat;
                        txLon = sol.point.lon;
                        haveTarget = true;
                    }
                }
            }

            /*
            if (nearestPos.found && nearestYaw.found) {
                const GeoPoint boat{ nearestPos.pos.lla.latitude, nearestPos.pos.lla.longitude };
                const double yaw_rad = deg2rad(nearestYaw.yawDeg);
                const bool waterColumn = !std::isfinite(depthAbs) || (rSlantAbs <= depthAbs + kWaterMargin);

                if (!isSideScan || waterColumn) {
                    txLat = boat.lat; txLon = boat.lon; haveTarget = true;
                } else {
                    const auto sol = solveSidescanTap(boat, yaw_rad, rSlantAbs, depthAbs, side);
                    if (sol.ok && !sol.wasWaterColumn) {
                        txLat = sol.point.lat; txLon = sol.point.lon; haveTarget = true;
                    }
                }
            }
            */

            // Arm candidate on a real tap (outside the panel)
            if (beenEpochEvent_ && echogramPause_ && !tapOnPanel) {
                const bool wasActive = cand_.active;
                cand_.active     = true;
                cand_.anchorDev  = QPoint(cursor.mouseX, cursor.mouseY);
                cand_.crossDev   = cand_.anchorDev;
                cand_.lat        = txLat;
                cand_.lon        = txLon;
                cand_.depth      = std::isfinite(depthAbs) ? depthAbs : NAN;
                cand_.yawDeg     = nearestYaw.found ? nearestYaw.yawDeg : NAN;
                cand_.model      = isSideScan ? "SS" : "2D";
                cand_.tapEpochIdx= epochIdxForTap;
                cand_.tapRangeM  = rSlantAbs;
                cand_.tapIsSS    = isSideScan;
                cand_.tapSide    = side;
                cand_.haveTarget = haveTarget;
                popupJustOpened_ = !wasActive;
                auto yawInDegrees = cand_.yawDeg;
                auto longitude = cand_.lon;
                auto latitude = cand_.lat;
                qDebug().noquote().nospace()
                    << qSetRealNumberPrecision(8)
                    << "[AIM] tap=" << epochIdxForTap
                    << " yaw=" << (nearestYaw.found ? nearestYaw.yawDeg : NAN)
                    << " lat=" << (nearestPos.found ? nearestPos.pos.lla.latitude  : NAN)
                    << " lon=" << (nearestPos.found ? nearestPos.pos.lla.longitude : NAN)
                    << " crossDepth=" << cursor_distance
                    << " r_slant=" << rSlantAbs
                    << " depth=" << depthAbs
                    << " side=" << side;
                const QPointF worldPt = p->worldTransform().inverted().map(QPointF(cursor.mouseX, cursor.mouseY));
                qDebug() << "[AIM] worldX=" << worldPt.x() << "worldY=" << worldPt.y()
                         << "W=" << parent->canvas().width() << "H=" << parent->canvas().height();
            }
        }
    }


    //Paint the zoom box

    if (cand_.active) {
        // compute the world-space center under the crosshair
        QPoint devPt = cand_.crossDev;
        const bool isSideScan  = cursor.channel1.isValid() && cursor.channel2.isValid();
        const bool isDualSS    = isSideScan && !isSideScan2DView_;
        QPoint devPtForSolve = QPoint(cursor.mouseX, cursor.mouseY);

        if (isDualSS) {
            //devPt = devRotNeg90(devPt, canvas.width());
            devPtForSolve = devRotNeg90(devPtForSolve, canvas.width());
        }

        const QPointF crossWorld = Winv.map(QPointF(devPtForSolve)); // world/pixmap coords

        // device-space anchor (using your existing placement convention)
        QPoint popupAnchor = cand_.anchorDev;

        if (isDualSS) {
            popupAnchor = devRotNeg90(popupAnchor, canvas.width());
        }


        Plot2DZoom::Input zin;
        zin.echPixmap      = &parent->echogramPixmap(); // forwarder getter
        zin.anchorPx       = popupAnchor;
        zin.centerWorld    = crossWorld;
        zin.viewport       = p->viewport();
        zin.scale          = scaleFactor_;
        zin.depthMeters    = std::isfinite(cand_.depth) ? std::abs(cand_.depth) : NAN;
        zin.crossMeters    = std::isfinite(cursor_distance) ? std::abs(cursor_distance) : NAN;
        zin.showAddBtn     = cand_.haveTarget;
        zin.rotateForView  = !parent->isHorizontal();         // you rotate(-90) when vertical (:contentReference[oaicite:7]{index=7})
        zin.flipForLeftHand= (isSideScan2DView_ && isSideScanLeftHand_);
        zin.boxSizePx      = 180;                             // your current size
        zin.zoomFactor     = 3;

        p->save();
        p->resetTransform(); // draw in device space
        const auto out = zoom_.draw(p, zin);
        p->restore();

        // keep your existing hit-testing flow (device space)
        cand_.infoRect     = out.panelRect;
        cand_.btnAbortRect = QRect();         // no abort button
        cand_.btnAddRect   = out.addRect;
    }

    //Handle the user taps on screen when box is shown
    if (cand_.active && hasTap_) {

        // Skip the opening tap once
        if (popupJustOpened_) {
            popupJustOpened_ = false;
            beenEpochEvent_  = false;
            return true;
        }

        // Tap mapped into painter logical coords (same space as popup rects)

        const int pad = 20 * scaleFactor_;
        const QRect abortRect = cand_.btnAbortRect.adjusted(-pad, -pad, +pad, +pad);
        const QRect addRect   = cand_.btnAddRect  .adjusted(-pad, -pad, +pad, +pad);

        // Optional: draw a small cross at tapDev
        p->save();
        p->resetTransform();
        p->setPen(QColor(255,255,0));
        p->drawLine(tapDev.x()-8, tapDev.y(), tapDev.x()+8, tapDev.y());
        p->drawLine(tapDev.x(),tapDev.y()-8, tapDev.x(),   tapDev.y()+8);
        p->restore();

        beenEpochEvent_ = false;

        //Abort
        if (abortRect.contains(tapDev)) {
            cand_.active = false;
            cand_.haveTarget = false;
            cand_.anchorDev = QPoint(-1, -1);
            cand_.crossDev  = QPoint(-1, -1);
            cursor.setMouse(-1, -1);
            qDebug() << "AddWaypoint: plot2D_aim: Abort pressed";
            return true;
        }
        //Add a waypoint
        if (cand_.haveTarget && cand_.btnAddRect.contains(tapDev)) {
            static UdpBroadcaster g_udp;
            g_udp.sendJsonPoint(
                cand_.lat, cand_.lon,
                std::isfinite(cand_.depth) ? cand_.depth : NAN,
                cand_.model, "TGT"
                );
            cand_.active = false;
            cand_.haveTarget = false;
            cand_.anchorDev = QPoint(-1, -1);
            cand_.crossDev  = QPoint(-1, -1);
            cursor.setMouse(-1, -1);
            qDebug() << "AddWaypoint: plot2D_aim: Add WP pressed";
            return true;
        }

        // Tap outside panel closes popup
        if (!cand_.infoRect.contains(tapDev)) {
            cand_.active = false;
            cand_.haveTarget = false;
            cand_.anchorDev = QPoint(-1, -1);
            cand_.crossDev  = QPoint(-1, -1);
            cursor.setMouse(-1, -1);
            qDebug() << "AddWaypoint: plot2D_aim: dismiss press";
            return true;
        }
    }
    return true;
}

void Plot2DAim::setEpochEventState(bool state)
{
    beenEpochEvent_ = state;
}




