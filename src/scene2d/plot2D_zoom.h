#ifndef PLOT2D_ZOOM_H
#define PLOT2D_ZOOM_H

#pragma once

#include <QRect>
#include <QPoint>
#include <QPointF>
#include <QPixmap>
#include <QPainter>
#include <QFont>

class UiMetrics;

class Plot2DZoom
{
public:
    struct Input {
        const QPixmap* echPixmap = nullptr; // cached echogram pixmap (same size as canvas)
        QPoint         anchorPx;            // device-space anchor near the tap
        QPointF        centerWorld;         // world/pixmap coords under crosshair
        QRect          viewport;            // painter->viewport()
        int            scale = 1;           // UI scale factor from Plot2DAim
        double         depthMeters = NAN;   // depth at bottom
        double         crossMeters = NAN;   // depth at crosshair
        bool           showAddBtn = false;  // show "Add WP"
        bool           rotateForView = false; // !parent->isHorizontal()
        bool           flipForLeftHand = false; // SS 2D view + left-hand
        int            boxSizePx = 180;     // visible zoom square (before margins)
        int            zoomFactor = 3;      // magnification
        int            dirSide = 0;         // Which side of the echogram
        bool           isDualSideScan = false;
        bool           isMetric = true;     // User may have a metric or an imperial preference
        bool           captureTile = false; // User wants to  capture tile image
    };

    struct Output {
        QRect   panelRect;      // full panel (for outside-tap dismissal)
        QRect   addRect;        // Add WP button (if empty → hidden)
        QRect   abortRect;      // abort button
        QRect   tapDeadRect;    // dead area to avoid tapping
        QPixmap zoomTile;       // image source to be shared
        QRect   zoomSrcRect;
    };

    Plot2DZoom() = default;

    // Draws the zoom panel and returns hit rects in device space.
    Output draw(QPainter* p, const Input& in) const;

private:
    void drawOutlinedDepth(QPainter* p, const QRect& zoomRect,
                           const QFont& font, int titlePad, int scale,
                           double depthMeters) const;

    static inline int clampi(int v, int lo, int hi) { return (v < lo) ? lo : (v > hi) ? hi : v; }
};

#endif // PLOT2D_ZOOM_H
