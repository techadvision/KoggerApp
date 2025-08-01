#pragma once

#include "plot2D_plot_layer.h"
#include <QObject>
#include <QQmlContext>


class Plot2DGrid : public QObject, public PlotLayer
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
    void setRangeFinderVisible(bool visible) { _rangeFinderLastVisible = visible; }
    //Pulse
    Q_INVOKABLE void setMeasuresMetric(bool metric);
    Q_INVOKABLE void setGridHorizontal (bool horizontal);
    Q_INVOKABLE void setSideScanOnLeftHandSide (bool leftSideInstall);
    Q_INVOKABLE int getAssessedMaxDepth();
    std::vector<int> calculateRulerTicks(int maxDepth, bool isMetric, bool is2DTransducer, bool isSideScan2DView, bool isSideScanLeftHand);

protected:
    bool angleVisibility_;
    bool _velocityVisible = true;
    bool _rangeFinderLastVisible = true;
    int _lines = 20;
    int _lineWidth = 1;
    //Pulse
    bool isMetric_ = true;
    bool isHorizontalGrid_ = true;
    bool isSideScanOnLeftHandSide_ = true;
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


};
