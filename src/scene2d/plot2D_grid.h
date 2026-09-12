#pragma once

#include "plot2D_plot_layer.h"
#include <QObject>
#include <QQmlContext>

class UiMetrics;

class QPainter;
class QString;
class Plot2DGrid : public QObject, public PlotLayer
//class Plot2DGrid : public PlotLayer

{
//Pulse
Q_OBJECT

enum class TextAnchor {
    TopLeft,
    BaselineLeft
};
public:
    Plot2DGrid();
    bool draw(Plot2D* parent, Dataset* dataset) override;

    void setAngleVisibility(bool state);
    bool getAngleVisibility() const { return angleVisibility_; }
    void setVetricalNumber(int grids) { _lines = grids; }
    int getVetricalNumber() const { return _lines; }
    void setVelocityVisible(bool visible) { _velocityVisible = visible; }
    bool getVelocityVisible() const { return _velocityVisible; }
    bool isFillWidth() const { return fillWidth_; }
    void setFillWidth(bool state) { fillWidth_ = state; }
    bool isInvert() const { return invert_; }
    void setInvert(bool state) { invert_ = state; }
    //void setRangeFinderVisible(bool visible) { _rangeFinderLastVisible = visible; }
    //Pulse
    Q_INVOKABLE void applyRuntime(const QVariantMap& m);
    Q_INVOKABLE void setMeasuresMetric( bool isMetric );
    Q_INVOKABLE void setGridHorizontal (bool horizontal);
    Q_INVOKABLE void setSideScanOnLeftHandSide (bool leftSideInstall);
    Q_INVOKABLE void setIsSideScan2DView(bool sideScan2DView);
    Q_INVOKABLE void setIs2DTransducer(bool is2DTransducer);
    Q_INVOKABLE int getAssessedMaxDepth();
    std::vector<int> calculateRulerTicks(int maxDepth, bool isMetric, bool is2DTransducer, bool isSideScan2DView, bool isSideScanLeftHand);
    int lastRightTextX() const { return lastRightTextX_; }

protected:
    //PULSE: 4 parameters, as ours defines it. Upstream added `vertical` and `rightAlign`
    //for their vertical-mode grid, which we did not take - and the union resolution of
    //this header pulled their declaration in over ours, which no longer matched the
    //definition in plot2D_grid.cpp.
    void drawTextWithBackdrop(QPainter* painter, int x, int baselineY, const QString& text) const;

    bool angleVisibility_;
    bool _velocityVisible = true;
    int _lines = 20;
    int _lineWidth = 1;
    //Pulse
    bool isMetric_ = true;
    bool isHorizontalGrid_ = true;
    bool isSideScanOnLeftHandSide_ = false;
    bool isSideScan2DView_   = false;
    bool is2DTransducer_   = true;
    // PULSE: the DISPLAY answer to "is this a 2D echogram", which is the one the ruler wants -
    // calculateRulerTicks() mirrors the ticks to both sides of a side scan and does not for a
    // 2D echogram, and that follows the picture being drawn rather than the transducer that
    // happens to be connected. Kept as its own member rather than sharing is2DTransducer_:
    // the settings bus sends PARTIAL maps, so one variable written by two keys ends up holding
    // whichever of them arrived last. Unset until the key is first seen, so a build or a
    // snapshot that does not carry it behaves exactly as before.
    bool displayIs2DTransducer_     = true;
    bool hasDisplayIs2DTransducer_  = false;
    int assessedMaxDepth_ = 0;
    QColor _lineColor = QColor(255, 255, 255, 255);

    void drawTextWithBackdrop(QPainter* p,
                              const QString &text,
                              const QPoint &devicePos, // reference coordinate in device space
                              TextAnchor anchor,
                              int margin = 5,
                              int forceRightEdge = -1,
                              int verticalOffset = 0,
                              const QColor &textColor = QColor(255,255,255),
                              const QColor &backdropColor = QColor(0,0,0,0x80));



    bool fillWidth_ = false;
    bool invert_ = false;
    
private:
    // ---- DPI / font scaling state & helpers ----
    qreal dpScale_ = 1.0;          // dpi / 160
    int   sp(qreal v) const;       // convert "sp" to pixels (implemented in .cpp)
    void  updateDpScale();         // recompute dpScale_ from QScreen (implemented in .cpp)

    int lastRightTextX_ = 0;
};
