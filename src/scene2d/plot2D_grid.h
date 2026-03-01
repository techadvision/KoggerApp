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
    bool draw(Plot2D* parent, Dataset* dataset);

    void setAngleVisibility(bool state);
    void setVetricalNumber(int grids) { _lines = grids; }
    void setVelocityVisible(bool visible) { _velocityVisible = visible; }
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

protected:
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

};
