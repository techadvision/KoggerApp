#pragma once

#include "plot2D_plot_layer.h"
#include <QElapsedTimer>
#include "plot2D_zoom.h"


class Plot2DAim : public PlotLayer {

public:
    Plot2DAim();
    //PULSE
    void applyRuntime(const QVariantMap& m);
    /*
    void drawZoomPanel(QPainter* p,
                       const QPixmap& echPix,
                       const QPointF& centerWorld,
                       bool rotateForView,
                       bool flipForLeftHand,
                       double depthMeters,
                       bool showAddBtn);
    */

    bool draw(Plot2D* parent, Dataset* dataset);
    void setEpochEventState(bool state);
    void drawPopup(QPainter* p, const QString& text, int scaleFactor);
    void setPause(Plot2D* parent, Dataset* dataset, bool on);
    bool isPaused() const { return echogramPause_; }
    int  lastAtPause() const { return lastIndexAtPause_; }
    int  visibleColsAtPause() const { return visibleColsAtPause_; }

protected:
    bool beenEpochEvent_;
    int lineWidth_;
    QColor lineColor_;
    int scaleFactor_;
    bool echogramPause_;
    bool needClearUi_ = false;
    bool paused_ = false;
    bool isSideScanLeftHand_ = false;
    bool isSideScan2DView_   = false;
    int lastIndexAtPause_ = -1;
    int visibleColsAtPause_ = 0;

private:
    //Pulse
    int    lastSentEpoch_ = -1;
    double lastSentLat_   = std::numeric_limits<double>::quiet_NaN();
    double lastSentLon_   = std::numeric_limits<double>::quiet_NaN();
    QElapsedTimer debounce_;
    bool  onlySendIfArmed_ = true;

    struct Candidate {
        bool   active = false;
        int    epochIdx = -1;
        double lat = std::numeric_limits<double>::quiet_NaN();
        double lon = std::numeric_limits<double>::quiet_NaN();
        double depth = std::numeric_limits<double>::quiet_NaN();
        float  yawDeg = std::numeric_limits<float>::quiet_NaN();
        bool   haveTarget = false;
        QString model; // "2D" / "SS"
        // UI geometry from last draw
        QRect  infoRect;
        QRect  btnAbortRect;
        QRect  btnAddRect;
        // evice-space anchors
        QPoint anchorPx;
        QPoint anchorDev = QPoint(-1, -1);   // for popup
        QPoint crossDev  = QPoint(-1, -1);   // for crosshair
        // To allow the crosshair to keep moving
        int    tapEpochIdx = -1;     // epoch index when tapped
        double tapRangeM   = NAN;    // slant/bottom range at tap (meters)
        bool   tapIsSS     = false;  // sidescan vs 2D at tap time
        int    tapSide     = 0;      // -1 left, +1 right (useful if you need it later)

    } cand_;

    // While testing: if we fail to resolve a GNSS/yaw, suppress crosshair for that tap
    bool suppressCrosshairOnce_ = false;

    // Helpers
    static bool nearlyEqual(double a, double b, double eps=1e-7);
    void clearCandidate();
    void armCandidateFromTap(Plot2D* parent, Dataset* dataset,
                             int epochIdx, int mouseX, int mouseY,
                             double cursorDistance);
    //void drawPopup(QPainter* p, const QString& text, int scaleFactor, bool showAddBtn);
    bool handleClickInsideButtons(int x, int y, Dataset* dataset);
    void fireWaypointAndClose();
    double rangeTFromDeviceTap(const QPoint& dev, int W, int H) const;
    QPointF pendingTapLogical_{-1, -1};
    bool hasTap_ = false;
    bool popupJustOpened_ = false;
    Plot2DZoom zoom_;
};

