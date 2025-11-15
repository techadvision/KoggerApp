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

// Map device-X (after handling rotation) to epoch index using a frozen frame.
static inline int devXToEpochIdxPaused(int devX, int canvasW, int visibleCols, int lastAtPause)
{
    const int last  = std::max(0, lastAtPause);
    const int start = std::max(0, last - visibleCols + 1);
    const int left  = canvasW - visibleCols;
    const int i     = start + (devX - left);
    return std::clamp(i, 0, last);
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


//Pulse helper to only trigger one sending of data to UDP per screen press
static inline bool nearlyEqual(double a, double b, double eps=1e-7) {
    return std::abs(a - b) <= eps;
}

//Pulse helpers for nearest yaw
struct NearestYawIdx {
    bool   found   = false;
    int    epochIdx = -1;
    int    dIdx     = 0;     // index distance from tapped epoch
    float  yawDeg   = NAN;   // [-180,180] or [0,360] depending on how you store it
};

static inline float wrap360(float deg) {
    float d = fmodf(deg, 360.f);
    if (d < 0) d += 360.f;
    return d;
}

NearestYawIdx findNearestYawByIndex(Dataset* ds, int idx, int maxLookEpochs)
{
    NearestYawIdx best;
    if (!ds) return best;
    const int last = ds->size() - 1;
    if (idx < 0 || idx > last) return best;

    // same epoch first
    if (auto* ep0 = ds->fromIndex(idx); ep0 && ep0->isAttAvail()) {
        best = {true, idx, 0, ep0->yaw()};
        return best;
    }

    for (int off = 1; off <= maxLookEpochs; ++off) {
        int j = idx - off;
        if (j >= 0) {
            if (auto* ep = ds->fromIndex(j); ep && ep->isAttAvail()) {
                best = {true, j, off, ep->yaw()};
                return best;
            }
        }
        int k = idx + off;
        if (k <= last) {
            if (auto* ep = ds->fromIndex(k); ep && ep->isAttAvail()) {
                best = {true, k, off, ep->yaw()};
                return best;
            }
        }
        if (j < 0 && k > last) break;
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

// Search outward by index only (idx-1, idx+1, idx-2, …) up to maxLookEpochs.
NearestPosIdx findNearestGNSSByIndex(Dataset* ds, int idx, int maxLookEpochs)
{
    NearestPosIdx best;
    if (!ds) return best;

    const int last = ds->size() - 1;
    if (idx < 0 || idx > last) return best;

    // Check the tapped epoch first
    if (auto* ep0 = ds->fromIndex(idx); ep0 && ep0->isPosAvail()) {
        best = {true, idx, 0, ep0->getPositionGNSS()};
        return best;
    }

    for (int off = 1; off <= maxLookEpochs; ++off) {
        // backward
        const int j = idx - off;
        if (j >= 0) {
            if (auto* ep = ds->fromIndex(j); ep && ep->isPosAvail()) {
                best = {true, j, off, ep->getPositionGNSS()};
                return best;
            }
        }
        // forward
        const int k = idx + off;
        if (k <= last) {
            if (auto* ep = ds->fromIndex(k); ep && ep->isPosAvail()) {
                best = {true, k, off, ep->getPositionGNSS()};
                return best;
            }
        }

        if (j < 0 && k > last) break; // reached both ends
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
    //if (echogramPause_ == on) return;
    if (paused_ == on) return;
    auto& canvas = parent->canvas();
    auto& cursor = parent->cursor();

    echogramPause_ = on;
    paused_ = on;
    if (on) {
        lastIndexAtPause_   = dataset ? (dataset->size() - 1) : -1;
        // freeze the column window that was on screen when we paused
        const QTransform W = canvas.painter()->worldTransform();
        const double sx = std::max(1e-6, W.m11());
        visibleColsAtPause_ = std::max(1, int(std::floor(double(canvas.width())/sx + 0.5)));
    } else {
        lastIndexAtPause_   = -1;
        visibleColsAtPause_ = 0;
        needClearUi_ = true; // (your existing UI clear flag)
    }
}


double Plot2DAim::rangeTFromDeviceTap(const QPoint& dev, int /*W*/, int H) const
{
    // Pure Y→t mapping in device space. No mirroring here.
    return clamp01(double(dev.y()) / double(H));
}


//***************************

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
            /*
            // If pause turned OFF, schedule a clear for next draw()
            if (paused_ && !newPause) {
                needClearUi_ = true;  // draw() will clear popup + crosshair safely
            }
            paused_ = newPause;       // keep our local snapshot
            echogramPause_ = newPause;
            */
        }
    }
    if (m.contains("isSideScanLeftHand"))  isSideScanLeftHand_ = m.value("isSideScanLeftHand").toBool();
    if (m.contains("isSideScan2DView"))    isSideScan2DView_   = m.value("isSideScan2DView").toBool();
}

//Draw the aim
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

    if ((cursor.mouseX < 0 || cursor.mouseY < 0) && (cursor.selectEpochIndx == -1)) {
        return false;
    }

    QPainter* p = canvas.painter();

    //Pulse

    const QTransform W = p->worldTransform();
    const QTransform Winv = W.inverted();
    const QPointF mouseLogical = Winv.map(QPointF(cursor.mouseX, cursor.mouseY));
    const double sx = std::max(1e-6, W.m11());
    const int visibleCols = std::max(1, int(std::floor(double(canvas.width()) / sx + 0.5)));

    //Pulse
    QPointF tapLogical(-1, -1);
    hasTap_ = false;
    if (beenEpochEvent_ && echogramPause_) {
        tapLogical = QPointF(cursor.mouseX, cursor.mouseY);
        pendingTapLogical_ = mouseLogical;
        hasTap_ = true;
    }
    if (beenEpochEvent_ && !echogramPause_) {
        beenEpochEvent_ = false; // ignore
    }
    //const QPoint tapDevAtArm = W.map(pendingTapLogical_).toPoint();
    const QPoint tapDevAtArm = QPoint(cursor.mouseX, cursor.mouseY);

    //*****

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

    bool tapOnPanel = false;
    QPoint tapDev;
    if (hasTap_ && cand_.active) {
        tapDev = QPoint(cursor.mouseX, cursor.mouseY);     // device space
        if (isDualSS) {
            tapDev = devRotNeg90(tapDev, canvas.width());
        }
        tapOnPanel = cand_.infoRect.contains(tapDev);      // infoRect is device space
    }

    //*****

    QPen pen;
    pen.setWidth(lineWidth_);
    pen.setColor(lineColor_);
    p->setPen(pen);

    QFont font("Asap", 14 * scaleFactor_, QFont::Normal);
    font.setPixelSize(18 * scaleFactor_);
    p->setFont(font);

    auto drawCrosshairAtWorld = [&](double lx, double ly){
        // Draw in WORLD space — let the current painter transform (including rotate(-90))
        // place the lines correctly on the rotated echogram.
        const int Wlog = canvas.width();   // world width after canvas_.setSize(...)
        const int Hlog = canvas.height();  // world height

        // Horizontal line at ly across full world width
        p->drawLine(QPointF(0,    ly), QPointF(Wlog, ly));
        // Vertical line at lx across full world height
        p->drawLine(QPointF(lx, 0),     QPointF(lx,  Hlog));
    };

    bool drewCrosshair = false;

    if (cand_.active && echogramPause_) {
        if (cand_.crossDev.x() >= 0 && cand_.crossDev.y() >= 0) {

            QPoint devPt = cand_.crossDev;

            // dual-side SS is drawn rotated -90° → rotate the tap to match
            if (isDualSS) {
                // canvas.width() is the device width for this view
                devPt = devRotNeg90(devPt, canvas.width());
            }

            const QPointF crossWorld = Winv.map(QPointF(devPt));
            drawCrosshairAtWorld(crossWorld.x(), crossWorld.y());
            drewCrosshair = true;
        }
    }


    // --- unified distance from device tap ---
    const QPoint devPtForRange = (cand_.active ? cand_.crossDev
                                               : QPoint(cursor.mouseX, cursor.mouseY));

    double t = rangeTFromDeviceTap(devPtForRange, canvas.width(), canvas.height());

    // Single-side SS, left-hand hardware installed → axis is mirrored vertically
    if (isSideScan2DView_ && isSideScanLeftHand_)
        t = 1.0 - t;
        //t = -1.0*t;

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
    if (cursor.currentEpochIndx != -1) {

        if (auto* ep = dataset->fromIndex(cursor.currentEpochIndx)) {
            const bool pausedNow = isPaused();
            int epochIdxForTap = cursor.currentEpochIndx;

            if (pausedNow) {
                // Map device-space X back to the frozen-frame index
                QPoint devPt = cand_.active ? cand_.crossDev : QPoint(cursor.mouseX, cursor.mouseY);
                if (isDualSS) {
                    devPt = devRotNeg90(devPt, canvas.width());
                }
                const int visColsFrozen = visibleColsAtPause() > 0
                                              ? visibleColsAtPause()
                                              : visibleCols; // safe fallback
                epochIdxForTap = devXToEpochIdxPaused(devPt.x(), canvas.width(), visColsFrozen, lastAtPause());
            } else {
                // Not paused → map using current dataset size/visibleCols
                QPoint devPt = cand_.active ? cand_.crossDev : QPoint(cursor.mouseX, cursor.mouseY);
                if (isDualSS) {
                    devPt = devRotNeg90(devPt, canvas.width());
                }
                const int last  = dataset->size() - 1;
                const int start = std::max(0, last - visibleCols + 1);
                const int left  = canvas.width() - visibleCols;
                epochIdxForTap  = std::clamp(start + (devPt.x() - left), 0, last);
            }


            const int maxLookEpochs = 5; // 200 ≈ 10 s at 50 ms/epoch: 10 should be sufficient
            const QString model = isSideScan ? "SS" : "2D";

            // Which side was tapped (visually)
            int side = 0;  // -1 = left, +1 = right
            if (isSideScan) {
                if (isSideScan2DView_) {
                    // Single-side SS rendered horizontally (like 2D).
                    // The chosen channel defines the side.
                    side = isSideScanLeftHand_ ? -1 : +1;
                } else {
                    // Dual-side SS rendered vertically after rotate(-90):
                    // TOP half is LEFT  (-1), BOTTOM half is RIGHT (+1).
                    const int midY = canvas.height() / 2;
                    const int tapY = cand_.active ? cand_.crossDev.y() : cursor.mouseY; // device-Y
                    side = (tapY < midY) ? -1 : +1;
                }
            } else {
                side = 0;  // 2D echogram doesn't use lateral side for solve
            }

            // Find nearest pos/yaw
            const auto nearestPos = findNearestGNSSByIndex(dataset, epochIdxForTap, maxLookEpochs);
            const auto nearestYaw = findNearestYawByIndex(dataset, epochIdxForTap, maxLookEpochs);
            //const auto nearestPos = findNearestGNSSByIndex(dataset, cursor.currentEpochIndx, maxLookEpochs);
            //const auto nearestYaw = findNearestYawByIndex(dataset, cursor.currentEpochIndx, maxLookEpochs);

            // Depth
            double depth = NAN;
            if (isSideScan) {
                if (auto* echogram = ep->chart(channelId, subIndx); echogram)
                    depth = echogram->bottomProcessing.getDistance();
            } else {
                depth = ep->rangeFinder();
            }
            if (!std::isfinite(depth) || depth < 0) depth = ep->rangeFinder();

            // Slant (cursor) range at the tap row
            const double r_slant = cursor_distance;

            // Absolute values may be needed for the slant and the depth
            const double depthAbs  = std::isfinite(depth)   ? std::abs(depth)   : NAN;
            const double rSlantAbs = std::isfinite(r_slant) ? std::abs(r_slant) : NAN;

            // --- Compute target if possible ---
            double txLat = NAN, txLon = NAN;
            bool haveTarget = false;

            if (nearestPos.found && nearestYaw.found) {
                const GeoPoint boat{ nearestPos.pos.lla.latitude, nearestPos.pos.lla.longitude };
                const double yaw_rad = deg2rad(nearestYaw.yawDeg);
                const bool waterColumn = !std::isfinite(depthAbs) || (rSlantAbs <= depthAbs + kWaterMargin);

                if (!isSideScan || waterColumn) {
                    // 2D, or SS water-column → waypoint at boat
                    txLat = boat.lat;
                    txLon = boat.lon;
                    haveTarget = true;
                } else {
                    // SS bottom hit → offset laterally by r_cross
                    const auto sol = solveSidescanTap(boat, yaw_rad, rSlantAbs, depthAbs, side);
                    if (sol.ok && !sol.wasWaterColumn) {
                        txLat = sol.point.lat;
                        txLon = sol.point.lon;
                        haveTarget = true;
                    }
                }
            }

            // --- Arm candidate on a tap while paused and not on the panel ---
            if (beenEpochEvent_ && echogramPause_ && !tapOnPanel) {
                const bool wasActive = cand_.active;
                cand_.active     = true;
                cand_.anchorDev  = tapDevAtArm;
                cand_.crossDev   = tapDevAtArm;
                //cand_.anchorDev  = QPoint(cursor.mouseX, cursor.mouseY); // popup anchor
                //cand_.crossDev   = cand_.anchorDev;                      // crosshair
                cand_.lat        = txLat;                  // may be NAN
                cand_.lon        = txLon;                  // may be NAN
                cand_.depth      = std::isfinite(depthAbs) ? depthAbs : NAN;
                cand_.yawDeg     = nearestYaw.found ? nearestYaw.yawDeg : NAN;
                cand_.model      = model;
                //cand_.tapEpochIdx= cursor.currentEpochIndx;
                cand_.tapEpochIdx = epochIdxForTap;
                cand_.tapRangeM  = rSlantAbs;
                cand_.tapIsSS    = isSideScan;
                cand_.tapSide    = side;
                cand_.haveTarget = haveTarget;            // ← true only if we solved a position
                popupJustOpened_ = !wasActive;
            }
        }
    }

    //Paint the zoom box

    if (cand_.active) {
        // compute the world-space center under the crosshair
        QPoint devPt = cand_.crossDev;
        const bool isSideScan  = cursor.channel1.isValid() && cursor.channel2.isValid();
        const bool isDualSS    = isSideScan && !isSideScan2DView_;
        if (isDualSS) {
            devPt = devRotNeg90(devPt, canvas.width()); // your helper (:contentReference[oaicite:6]{index=6})
        }
        const QPointF crossWorld = Winv.map(QPointF(devPt)); // world/pixmap coords

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


        /*
        QPoint devPt = cand_.crossDev;
        const bool isDualSS = isSideScan && !isSideScan2DView_;
        if (isDualSS) devPt = devRotNeg90(devPt, canvas.width());
        const QPointF crossWorld = Winv.map(QPointF(devPt));

        // Get the cached echogram
        const QPixmap& echPix = parent->echogramPixmap(); // via Plot2D forwarder

        // Get the crosshair depth
        float depth = cursor_distance;

        // Orientation flags
        const bool rotateForView = !parent->isHorizontal();     // echogram was drawn with rotate(-90)
        const bool flipForLeft   = (isSideScan2DView_ && isSideScanLeftHand_);

        // Place the panel in device space anchored at the stored tap
        p->save();
        p->resetTransform();
        QPoint popupAnchor = cand_.anchorDev;
        if (isDualSS) popupAnchor = devRotNeg90(popupAnchor, canvas.width());
        const QPoint oldAnchorPx = cand_.anchorPx;
        cand_.anchorPx = popupAnchor;

        drawZoomPanel(p, echPix, crossWorld,
                      rotateForView, flipForLeft,
                      std::isfinite(depth) ? std::abs(depth) : NAN,
                      cand_.haveTarget);

        cand_.anchorPx = oldAnchorPx;
        p->restore();
        */
    }

    /*
    if (cand_.active) {
        auto [channelId, subIndx, name] = parent->getSelectedChannelId();
        //Tapped depth measure
        QString distanceText = QString(QObject::tr("%1 m")).arg(cursor_distance, 0, 'g', 3);
        //Strings in the text box
        QString boxText;
        if (std::isfinite(cand_.lat))
            boxText += QObject::tr("Lat: ") + QString::number(cand_.lat, 'f', 6);
        if (std::isfinite(cand_.lon))
            boxText += (boxText.isEmpty() ? "" : "\n") +
                       QObject::tr("Lon: ") + QString::number(cand_.lon, 'f', 6);
        boxText += "\nDepth (cross): " + distanceText;

        if (std::isfinite(cand_.depth))
            boxText += (boxText.isEmpty() ? "" : "\n") +
                       QObject::tr("Depth (bottom): ") + QString::number(cand_.depth, 'f', 2) + QObject::tr(" m");

        // Device-space placement
        p->save();
        p->resetTransform();
        const QPoint oldAnchorPx = cand_.anchorPx;

        // start from the stored tap
        QPoint popupAnchor = cand_.anchorDev;
        if (isDualSS) {
            popupAnchor = devRotNeg90(popupAnchor, canvas.width());
        }
        cand_.anchorPx = popupAnchor;
        drawPopup(p, boxText, scaleFactor_, cand_.haveTarget);
        cand_.anchorPx = oldAnchorPx;

        //const QPoint oldAnchor = cand_.anchorDev;
        //const QPoint oldAnchorPx = cand_.anchorPx;
        //cand_.anchorPx = cand_.anchorDev;
        //drawPopup(p, boxText, scaleFactor_, cand_.haveTarget);
        //cand_.anchorPx = oldAnchorPx;
        p->restore();
    }
    */

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

// --- device-space popup renderer ---
void Plot2DAim::drawPopup(QPainter* p, const QString& text, int scaleFactor, bool showAddBtn)
{
    const int margin = 6  * scaleFactor;
    const int btnH   = 30 * scaleFactor;
    const int btnW   = 90 * scaleFactor;
    const int btnGap = 10 * scaleFactor;

    QFont font("Asap", 14 * scaleFactor, QFont::Normal);
    font.setPixelSize(18 * scaleFactor);
    p->setFont(font);

    QRect textRect = p->fontMetrics()
                         .boundingRect(QRect(0, 0, 9999, 9999),
                                       Qt::AlignLeft | Qt::AlignTop, text);

    const int minButtonsWidth = showAddBtn ? (2*btnW + btnGap) : btnW;
    const int contentWidth    = qMax(textRect.width(), minButtonsWidth);
    textRect.setWidth(contentWidth);

    // --- DEVICE SPACE layout (very important) ---
    const QRect vp = p->viewport();               // <-- device pixels (correct under flips/rotations)
    const int vpW = vp.width();
    const int vpH = vp.height();

    const int xShift = 50 * scaleFactor;
    const int yShift = 40 * scaleFactor;

    // Decide which side to place the panel relative to anchor (device px)
    const bool onTheRight   = (vpW - cand_.anchorPx.x() - (xShift + 15*scaleFactor)) < textRect.width();
    const int  spaceBelow   = cand_.anchorPx.y();
    const int  neededBelow  = textRect.height() + (yShift + 15*scaleFactor);
    const bool placeAbove   = (spaceBelow < neededBelow);

    QPoint topLeft;
    if (!placeAbove) {
        topLeft = onTheRight
                      ? QPoint(cand_.anchorPx.x() - xShift - textRect.width(),
                               cand_.anchorPx.y() - yShift - textRect.height())
                      : QPoint(cand_.anchorPx.x() + xShift,
                               cand_.anchorPx.y() - yShift - textRect.height());
    } else {
        topLeft = onTheRight
                      ? QPoint(cand_.anchorPx.x() - xShift - textRect.width(),
                               cand_.anchorPx.y() + yShift)
                      : QPoint(cand_.anchorPx.x() + xShift,
                               cand_.anchorPx.y() + yShift);
    }
    textRect.moveTopLeft(topLeft);

    QRect panelRect = textRect.adjusted(-margin, -margin, +margin, +margin + btnH + margin);

    const int btnY = panelRect.bottom() - margin - btnH;
    QRect abortRect, addRect;
    if (showAddBtn) {
        const int rowW = 2*btnW + btnGap;
        const int x0   = panelRect.center().x() - rowW/2;
        abortRect = QRect(x0,                btnY, btnW, btnH);
        addRect   = QRect(abortRect.right()+btnGap, btnY, btnW, btnH);
    } else {
        const int x0   = panelRect.center().x() - btnW/2;
        abortRect = QRect(x0, btnY, btnW, btnH);
    }

    // draw (device space)
    p->setPen(Qt::NoPen);
    p->setBrush(QColor(45,45,45));
    p->drawRect(panelRect);

    p->setPen(QColor(255,255,255));
    p->drawText(textRect, Qt::AlignLeft | Qt::AlignTop, text);

    auto drawBtn = [&](const QRect& r, const QString& label){
        p->setBrush(QColor(70,70,70));
        p->setPen(QColor(200,200,200));
        p->drawRoundedRect(r, 6, 6);
        p->drawText(r, Qt::AlignCenter, label);
    };

    drawBtn(abortRect, QObject::tr("Abort"));
    if (showAddBtn) drawBtn(addRect, QObject::tr("Add WP"));

    // Save hit areas in device space (for tap hit-testing)
    cand_.infoRect     = panelRect;
    cand_.btnAbortRect = abortRect;
    cand_.btnAddRect   = addRect;
}

/*
// --- device-space zoom panel renderer ---
void Plot2DAim::drawZoomPanel(QPainter* p,
                              const QPixmap& echPix,      // cached echogram
                              const QPointF& centerWorld, // world coords under crosshair
                              bool rotateForView,         // !parent->isHorizontal()
                              bool flipForLeftHand,       // isSideScan2DView_ && isSideScanLeftHand_
                              double depthMeters,         // depth text, if any
                              bool showAddBtn)            // show "Add WP"
{
    const int scale        = scaleFactor_;
    const int boxSize      = 180 * scale;   // visible zoom content (square)
    const int zoomFactor   = 3;             // 3x zoom
    const int innerSize    = boxSize;       // zoom tile spans full panel content
    const int margin       = 6  * scale;

    // text + button inside the zoom rect
    const int titlePad     = 8  * scale;    // gap from top of zoom for text baseline
    const int btnH         = 30 * scale;
    const int btnW         = 120* scale;
    const int btnPad       = 8  * scale;    // gap above zoom bottom

    // --- Layout (device space) ---
    QFont font("Asap", 14 * scale, QFont::Normal);
    font.setPixelSize(18 * scale);
    p->setFont(font);
    QFontMetrics fm(font);

    // Place panel using your existing anchor logic (content == innerSize x innerSize)
    const QRect vp  = p->viewport();
    const int vpW   = vp.width();
    const int vpH   = vp.height();

    const int contentW = innerSize;
    const int contentH = innerSize;

    const int xShift = 50 * scale;
    const int yShift = 40 * scale;

    const bool onTheRight  = (vpW - cand_.anchorPx.x() - (xShift + 15*scale)) < contentW;
    const int  spaceBelow  = cand_.anchorPx.y();
    const int  neededBelow = contentH + (yShift + 15*scale);
    const bool placeAbove  = (spaceBelow < neededBelow);

    QPoint topLeft;
    if (!placeAbove) {
        topLeft = onTheRight
                      ? QPoint(cand_.anchorPx.x() - xShift - contentW, cand_.anchorPx.y() - yShift - contentH)
                      : QPoint(cand_.anchorPx.x() + xShift,            cand_.anchorPx.y() - yShift - contentH);
    } else {
        topLeft = onTheRight
                      ? QPoint(cand_.anchorPx.x() - xShift - contentW, cand_.anchorPx.y() + yShift)
                      : QPoint(cand_.anchorPx.x() + xShift,            cand_.anchorPx.y() + yShift);
    }

    // Panel = zoom + margins only
    QRect contentRect(topLeft, QSize(contentW, contentH));
    QRect panelRect = contentRect.adjusted(-margin, -margin, +margin, +margin);

    // Zoom rect centered inside the panel
    QRect zoomRect(QPoint(0,0), QSize(innerSize, innerSize));
    zoomRect.moveCenter(panelRect.center());

    // --- Precompute button rect (inside zoom, bottom-center)
    QRect addRect;
    if (showAddBtn) {
        addRect = QRect(0, 0, btnW, btnH);
        addRect.moveCenter(QPoint(zoomRect.center().x(),
                                  zoomRect.bottom() - btnPad - btnH/2));
    }

    // --- Panel background & frame ---
    p->save();
    p->resetTransform();                 // draw UI in device space
    p->setPen(Qt::NoPen);
    p->setBrush(QColor(45,45,45));
    p->drawRect(panelRect);
    p->setPen(QColor(255,255,255));
    p->drawRect(zoomRect.adjusted(-1,-1,+1,+1)); // white frame

    // --- Build source rect in pixmap coords (centered at crosshair)
    const double srcW = double(innerSize) / double(zoomFactor);
    QRectF src(centerWorld.x() - srcW/2.0, centerWorld.y() - srcW/2.0, srcW, srcW);
    const int imgW = echPix.width();
    const int imgH = echPix.height();
    if (src.left()   < 0)      src.moveLeft(0);
    if (src.top()    < 0)      src.moveTop(0);
    if (src.right()  > imgW-1) src.moveRight(imgW-1);
    if (src.bottom() > imgH-1) src.moveBottom(imgH-1);

    // --- Extract & orient tile to match view
    QPixmap tile = echPix.copy(src.toRect());
    if (rotateForView)  tile = tile.transformed(QTransform().rotate(90));
    if (flipForLeftHand) tile = tile.transformed(QTransform().scale(1, -1));

    // --- Draw zoom tile
    p->drawPixmap(zoomRect, tile);

    // --- (5) Crosshair inside zoomRect (semi-transparent white)
    {
        const int cx = zoomRect.center().x();
        const int cy = zoomRect.center().y();
        QPen crossPen(QColor(255,255,255,153));   // ~60% alpha
        crossPen.setWidthF(std::max(1.0, 1.0 * scale));
        p->setPen(crossPen);
        p->drawLine(zoomRect.left(),  cy, zoomRect.right(), cy);
        p->drawLine(cx, zoomRect.top(), cx, zoomRect.bottom());
    }

    // --- (3) Depth text inside zoomRect, top-center, with black outline
    if (std::isfinite(depthMeters)) {
        const QString dtxt = QStringLiteral("Cross: ")
        + QString::number(depthMeters, 'f', (depthMeters < 10) ? 2 : 1)
            + QStringLiteral(" m");

        p->setRenderHint(QPainter::Antialiasing, true);
        p->setRenderHint(QPainter::TextAntialiasing, true);

        const int textW = fm.horizontalAdvance(dtxt);
        const int textX = zoomRect.center().x() - textW/2;
        const int textBaselineY = zoomRect.top() + titlePad + fm.ascent();

        QPainterPath path;
        path.addText(QPointF(textX, textBaselineY), font, dtxt);

        // 1) Outline behind
        QPen outline(Qt::black);
        outline.setWidthF(std::max(1.0, 1.5 * scale));     // a bit thinner so it doesn’t swallow the fill
        outline.setJoinStyle(Qt::RoundJoin);
        p->setPen(outline);
        p->setBrush(Qt::NoBrush);
        p->drawPath(path);

        // 2) Fill on top
        p->fillPath(path, Qt::white);
    }

    // --- (4) Add WP button inside zoomRect bottom-center
    if (showAddBtn) {
        p->setBrush(QColor(70,70,70));
        p->setPen(QColor(200,200,200));
        p->drawRoundedRect(addRect, 6*scale, 6*scale);
        p->drawText(addRect, Qt::AlignCenter, QObject::tr("Add WP"));
    }

    // Hit areas for tap handling (device space)
    cand_.infoRect     = panelRect; // tap-outside to dismiss still uses this
    cand_.btnAbortRect = QRect();   // removed
    cand_.btnAddRect   = addRect;

    p->restore();
}
*/



