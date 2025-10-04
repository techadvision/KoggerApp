#include "plot2D_grid.h"
#include "plot2D.h"
#include <QObject>
#include <vector>
#include <cmath>
#ifdef Q_OS_ANDROID
#include "InsetsHelper.h"
#endif
#include <QGuiApplication>
#include <QScreen>
#include <limits>
#include <algorithm>
#include "math_defs.h"


Plot2DGrid::Plot2DGrid() : angleVisibility_(false), isMetric_(true), isHorizontalGrid_(true), isSideScanOnLeftHandSide_(true)
{
   updateDpScale();
}

int Plot2DGrid::sp(qreal v) const { return qRound(v * dpScale_); }

void Plot2DGrid::updateDpScale() {
    QScreen* s = QGuiApplication::primaryScreen();
    if (!s) {
        qDebug() << "updateDpScale !s";
        dpScale_ = 1.0;
        return;
    }
#ifdef Q_OS_ANDROID
    const qreal dpi = s->physicalDotsPerInch();
#else
    const qreal dpi = s->logicalDotsPerInch();
#endif
    dpScale_ = dpi / 160.0;
}

bool Plot2DGrid::draw(Plot2D* parent, Dataset* dataset)
{
    auto &canvas = parent->canvas();
    auto &cursor = parent->cursor();

    if (!isVisible())
        return false;

    const int textPadding = 5;

    float conversionFactor = 1.0; // Default to metric (meters)
    if (!isMetric_) {
        conversionFactor = 3.28084; // Convert to feet if not metric
    }

    float fromDepth = cursor.distance.from;
    float toDepth = cursor.distance.to;
    float logicalMaxDepth = std::max(std::abs(fromDepth), std::abs(toDepth));


    float totalRange = toDepth - fromDepth;
    if (totalRange == 0.0f)
        totalRange = 0.0001f;
    assessedMaxDepth_ = totalRange;

    bool flipImage = isSideScanOnLeftHandSide_ && isSideScan2DView_;
    //bool flipImage = isSideScanOnLeftHandSide_ && isSideScan2DView;
    //qDebug() << "RULER TICKS flipimage:" << flipImage << "isSideScanOnLeftHandSide_:" << isSideScanOnLeftHandSide_ << "isSideScan2DView:" << isSideScan2DView_;

    QPen pen(_lineColor);
    pen.setWidth(_lineWidth);

    QPainter* p = canvas.painter();
    p->setPen(pen);
    QFont f("Asap");
    f.setPixelSize(sp(18));   // pick an sp value
    f.setBold(true);
    p->setFont(f);
    //p->setFont(QFont("Asap", 20, QFont::Bold));
    QFontMetrics fm(p->font());

    const int imageHeight{ canvas.height() }, imageWidth{ canvas.width() },
        linesCount{ _lines }, textXOffset{ 30 }, textYOffset{ 10 };

    //SDK35 EDGE to EGDE SAFE MARGINS

#ifdef Q_OS_ANDROID
    // Pull current insets (right > 0 when 3-button bar is on the right in landscape)
    const int insetLeft   = InsetsHelper::instance()->left();
    const int insetTop    = InsetsHelper::instance()->top();
    const int insetRight  = InsetsHelper::instance()->right();
    const int insetBottom = std::max(InsetsHelper::instance()->bottom(),
                                     InsetsHelper::instance()->ime()); // lift above IME if visible
    const bool isDex      = InsetsHelper::instance()->dexEnabled();

    // Define the drawable/safe rect in device coords
    const int safeLeftEdge = insetLeft;
    int tempTopEdge        = insetTop;
    if (isDex) {
        tempTopEdge        = 0;
    }
    const int safeTopEdge    = tempTopEdge;
    const int safeRightEdge  = imageWidth  - insetRight;
    const int safeBottomEdge = imageHeight - insetBottom;
#else
    const int safeLeftEdge   = 0;
    const int safeTopEdge    = 0;
    const int safeRightEdge  = imageWidth;
    const int safeBottomEdge = imageHeight;
#endif

    const QRect safeRect(safeLeftEdge,
                         safeTopEdge,
                         safeRightEdge - safeLeftEdge,
                         safeBottomEdge - safeTopEdge);

    const int safeW = safeRightEdge - safeLeftEdge;
    const int safeH = safeBottomEdge - safeTopEdge;

    auto withDeviceSafe = [&](auto drawFn){
        p->save();
        p->resetTransform();      // draw in device coords
        p->setClipRect(safeRect); // never paint under bars
        drawFn();
        p->restore();
    };

    //SDK35 EDGE to EGDE SAFE METHODS

    auto withTopWide = [&](auto&& fn){
        p->save();
        p->resetTransform();

        const int devW = p->device()->width();
        const int devH = p->device()->height();

        const QRect band(0, safeTopEdge, devW, devH - safeTopEdge); // full width, below status bar
        p->setClipRect(band);
        fn(band);   // pass the rect we’re drawing in
        p->restore();
    };

    auto mapMetersToXVisible = [&](float meters, const QRect& band)->int {
        const float x0   = std::min(fromDepth, toDepth);
        const float x1   = std::max(fromDepth, toDepth);
        const float span = std::max(0.0001f, x1 - x0);

        float rel = (meters - x0) / span;        // x0→0, x1→1
        rel = std::clamp(rel, 0.0f, 1.0f);

        return band.left() + int(std::lround(rel * (band.width() - 1)));
    };

    std::vector<int> tickValues = calculateRulerTicks(static_cast<int>(logicalMaxDepth), isMetric_, is2DTransducer_, isSideScan2DView_, isSideScanOnLeftHandSide_);

    //CREATE DEPTH LABELS AND LINES
    int linesCountNew = static_cast<int>(tickValues.size()) + 1; // +1 for final bottom value
    for (int i = 1; i < linesCountNew; ++i) {

        int displayIndex = i;

        float tickValue = static_cast<float>(tickValues[displayIndex - 1]); // i starts from 1
        float tickMeters = isMetric_ ? tickValue : tickValue / 3.28084f;

        // Make sure denominator is never zero
        float totalRange = toDepth - fromDepth;
        if (totalRange == 0.0f)
            totalRange = 0.0001f; // prevent divide-by-zero crash

        const float d0 = std::min(fromDepth, toDepth);
        const float d1 = std::max(fromDepth, toDepth);
        const float ySpan = std::max(0.0001f, d1 - d0);

        float relativeY  = (tickMeters - d0) / ySpan;     // 0..1
        relativeY        = std::clamp(relativeY, 0.0f, 1.0f);

        int posY         = int(relativeY * imageHeight);
        int posYflipped  = flipImage ? (imageHeight - posY) : posY;

        //BUILD DEPTH LABELS
        QString lineText = " ";
        if (cursor.distance.isValid()) {

            float displayValue = std::abs(tickValue);  // always positive in text
            if (isMetric_) {
                lineText.append( { QString::number(displayValue, 'f', 0) + QObject::tr(" m") } );
            } else {
                lineText.append( { QString::number(displayValue, 'f', 0) + QObject::tr(" ft") } );
            }
        }

        //POSTTION DEPTH LABELS
        if (!lineText.isEmpty()) {
            if (isHorizontalGrid_) {
                //HORIZONTAL GRID
#ifdef Q_OS_ANDROID
                withDeviceSafe([&]{
                    const int desiredX = safeRightEdge - fm.horizontalAdvance(lineText) - textXOffset;
                    const QPoint textPos(desiredX, posYflipped - textYOffset);
                    // Force the backdrop’s right edge to the safe edge (not imageWidth)
                    drawTextWithBackdrop(p, lineText, textPos,
                                         TextAnchor::BaselineLeft,
                                         5,               // margin
                                         safeRightEdge,   // forceRightEdge
                                         5);              // verticalOffset
                });
#endif
#ifdef Q_OS_WINDOWS
                p->drawText(safeRightEdge - fm.horizontalAdvance(lineText) - textXOffset, posYflipped - textYOffset, lineText);
#endif
            } else {      
                //VERTICAL GRID
                withTopWide([&](const QRect& band){
                    const int posX      = mapMetersToXVisible(tickMeters, band);
                    const int textWidth = p->fontMetrics().horizontalAdvance(lineText);
                    const int pad       = sp(6); // small gap between line and text

                    int labelX;
                    if (tickMeters < 0.0f) {
                        // Left channel: put text to the RIGHT of the tick line
                        labelX = posX + pad;
                    } else if (tickMeters > 0.0f) {
                        // Right channel: put text to the LEFT of the tick line
                        labelX = posX - textWidth - pad;
                    } else {
                        // (optional) 0 m: center over the tick
                        labelX = posX - textWidth / 2;
                    }

                    // Clamp inside the full-width band we’re drawing in
                    labelX = std::clamp(labelX, band.left(), band.right() - textWidth);

                    const int baseY = band.top() + textYOffset + p->fontMetrics().ascent();
                    drawTextWithBackdrop(p, lineText,
                                         QPoint(labelX, baseY),
                                         TextAnchor::BaselineLeft,
                                         5,   // margin
                                         -1,  // don’t force right edge
                                         0);
                });
            }
        }

        //POSITION RULER MARK LINES
        if (isHorizontalGrid_) {
            //HORIZONTAL GRID
            if (isFillWidth()) {
                withDeviceSafe([&]{ p->drawLine(safeLeftEdge, posYflipped, safeRightEdge, posYflipped); });
            } else {
                const int startX = safeRightEdge - fm.horizontalAdvance(lineText) - textXOffset;
                withDeviceSafe([&]{ p->drawLine(startX, posYflipped, safeRightEdge, posYflipped); });
            }

        } else {
            //VERTICAL GRID
            withTopWide([&](const QRect& band){
                const int posX = mapMetersToXVisible(tickMeters, band);
                if (isFillWidth()) {
                    p->drawLine(posX, band.top(), posX, band.bottom());
                } else {
                    const int fixedLineLength = 50;
                    p->drawLine(posX, band.top(), posX, band.top() + fixedLineLength);
                }
            });
        }

    }

    // LAST DEPTH TEXT AT THE VERY BOTTOM, ONLY IN 2D VIEW
    if (cursor.distance.isValid() && !flipImage && is2DTransducer_) {
        QFont f("Asap");
        f.setPixelSize(sp(18));
        f.setBold(true);
        p->setFont(f);
        //p->setFont(QFont("Asap", 20, QFont::Bold));

        float val{ cursor.distance.to * conversionFactor };

        QString range_text = QString::number(val, 'f', (isMetric_ ? 0 : 1)) + (isMetric_ ? QObject::tr(" m") : QObject::tr(" ft"));

        if (isHorizontalGrid_) {
#ifdef Q_OS_ANDROID
            withDeviceSafe([&]{
                const int desiredX = safeRightEdge - textXOffset/2 - fm.horizontalAdvance(range_text);
                const int baseY    = safeBottomEdge - 10;   // inside the safe area
                drawTextWithBackdrop(p, range_text, QPoint(desiredX, baseY),
                                     TextAnchor::BaselineLeft,
                                     5,            // margin
                                     safeRightEdge,// forceRightEdge inside safeRect
                                     5);           // vertical offset
            });
#endif
#ifdef Q_OS_WINDOWS
            //p->drawText(imageWidth - textXOffset / 2 - range_text.count() * 25, imageHeight - 10, range_text);
            p->drawText(safeRightEdge - textXOffset / 2 - fm.horizontalAdvance(range_text),
                        safeBottomEdge - 10, range_text);
#endif
        } else {
            /*
            p->save();

            int textWidth = fm.horizontalAdvance(range_text);
            int textHeight = fm.height();

            int centerX = imageWidth - textXOffset / 2 - textWidth / 2;
            int centerY = imageHeight - 30 - textHeight;

            p->translate(centerX, centerY);
            p->rotate(90);

            p->drawText(-textWidth / 2, textHeight / 2, range_text);

            p->restore();
            */
        }

    }

    //PULSE DOES NOT USE THE ON SCREEN DEPTH VALUE FROM THE GRID CLASS
    /*

    if (cursor.distance.isValid()) {
        p->setFont(QFont("Asap", 26, QFont::Normal));
        float val{ cursor.distance.to };
        bool isInteger = std::abs(val - std::round(val)) < kmath::fltEps;
        QString rangeText = QString::number(val, 'f', isInteger ? 0 : 2) + QObject::tr(" m");
        p->drawText(imageWidth - textXOffset / 2 - rangeText.count() * 25, imageHeight - 10, rangeText);
    }

    if (_rangeFinderLastVisible && cursor.distance.isValid()) {
        Epoch* lastEpoch = dataset->last();
        Epoch* preLastEpoch = dataset->lastlast();
        float distance = NAN;

        if (lastEpoch != NULL && isfinite(lastEpoch->rangeFinder())) {
            distance = lastEpoch->rangeFinder();
        }
        else if (preLastEpoch != NULL && isfinite(preLastEpoch->rangeFinder())) {
            distance = preLastEpoch->rangeFinder();
        }

        if (isfinite(distance)) {
            pen.setColor(QColor(250, 100, 0));
            p->setPen(pen);
            p->setFont(QFont("Asap", 40, QFont::Normal));
            float val{ round(distance * 100.f) / 100.f };
            bool isInteger = std::abs(val - std::round(val)) < kmath::fltEps;
            QString rangeText = QString::number(val, 'f', isInteger ? 0 : 2) + QObject::tr(" m");
            p->drawText(imageWidth / 2 - rangeText.count() * 32, imageHeight - 15, rangeText);
        }

    }
    */

    // TEMPERATURE, NOT USED BY PULSE
    if(false) {
        Epoch* lastEpoch = dataset->last();
        Epoch* preLastEpoch = dataset->lastlast();

        Q_UNUSED(lastEpoch)
        Q_UNUSED(preLastEpoch)

        float temp = NAN;
        temp = dataset->getLastTemp();

        /* Pulse already has the temperature
        if (isfinite(temp)) {
            pen.setColor(QColor(80, 200, 0));
            p->setPen(pen);
            p->setFont(QFont("Asap", 40, QFont::Normal));
            float val{ round(temp * 100.f) / 100.f };
            bool isInteger = std::abs(val - std::round(val)) < kmath::fltEps;
            QString rangeText = QString::number(val, 'f', isInteger ? 0 : 1) + QObject::tr("°");
            p->drawText(imageWidth / 2 - 300, imageHeight - 15, rangeText);
        }
        */
    }

    return true;
}

//PULSE method
void Plot2DGrid::drawTextWithBackdrop(QPainter* p,
                                      const QString &text,
                                      const QPoint &devicePos,
                                      TextAnchor anchor,
                                      int margin,
                                      int forceRightEdge,
                                      int verticalOffset,
                                      const QColor &textColor,
                                      const QColor &backdropColor)
{
    p->save();
    QTransform savedTransform = p->transform();
    p->resetTransform();

    // Get the text bounding rectangle using the current font metrics.
    QRect textRect = p->fontMetrics().boundingRect(text);

    // Position the rectangle based on the desired anchor.
    if (anchor == TextAnchor::BaselineLeft)
        textRect.moveTopLeft(QPoint(devicePos.x(), devicePos.y() - p->fontMetrics().ascent()));
    else
        textRect.moveTopLeft(devicePos);

    // Apply the vertical offset.
    textRect.translate(0, verticalOffset);

    // If forceRightEdge is set (>= 0), override the computed right edge.
    if (forceRightEdge >= 0)
        textRect.setRight(forceRightEdge);

    // Add padding.
    textRect.adjust(-margin, -margin, margin, margin);

    // Draw the backdrop.
    p->setPen(Qt::NoPen);
    p->setBrush(backdropColor);
    p->drawRect(textRect);

    // Draw the text using the specified text color.
    p->setPen(textColor);
    p->drawText(textRect, Qt::AlignLeft | Qt::AlignVCenter, text);

    p->setTransform(savedTransform);
    p->restore();
}




void Plot2DGrid::setAngleVisibility(bool state)
{
    angleVisibility_ = state;
}

// Pulse
void Plot2DGrid::setMeasuresMetric(bool metric)
{
    qDebug() << "Called setMeasuresMetric, is metric?" << metric;
    isMetric_ = metric;
}

void Plot2DGrid::setGridHorizontal(bool horizontal)
{
    isHorizontalGrid_ = horizontal;
}

void Plot2DGrid::setSideScanOnLeftHandSide(bool isLeftSideInstalled)
{
    isSideScanOnLeftHandSide_ = isLeftSideInstalled;
    qDebug() << "isSideScanOnLeftHandSide_ plot2D_grid new value" << isSideScanOnLeftHandSide_;
}
int Plot2DGrid::getAssessedMaxDepth()
{
    return assessedMaxDepth_;
}
void Plot2DGrid::setIsSideScan2DView(bool sideScan2DView)
{
    isSideScan2DView_ =  sideScan2DView;
}
void Plot2DGrid::setIs2DTransducer(bool is2DTransducer)
{
    is2DTransducer_ =  is2DTransducer;
}

void Plot2DGrid::applyRuntime(const QVariantMap& m)
{
    if (m.contains("isSideScan2DView"))
        isSideScan2DView_ = m.value("isSideScan2DView").toBool();
    if (m.contains("isSideScanLeftHand"))
        isSideScanOnLeftHandSide_ = m.value("isSideScanLeftHand").toBool();
    if (m.contains("isHorizontalGrid"))
        isHorizontalGrid_ = m.value("isHorizontalGrid").toBool();
    if (m.contains("useMetricDepth"))
        isMetric_ = m.value("useMetricDepth").toBool();
    if (m.contains("is2DTransducer")) {
        is2DTransducer_ = m.value("is2DTransducer").toBool();
        qDebug() << "VALUE_CHANGE: is2DTransducer_ was updated to" << is2DTransducer_;
    }
}

//PULSE METHOD
std::vector<int> Plot2DGrid::calculateRulerTicks(int maxDepth, bool isMetric, bool is2DTransducer, bool isSideScan2DView, bool isSideScanLeftHand)
{
    const float conversionFactor = isMetric ? 1.0f : 3.28084f;
    const int maxDepthDisplay = static_cast<int>(std::ceil(maxDepth * conversionFactor));

    std::vector<int> bestTicks;
    int maxLines = 5;
    for (int step = 1; step <= maxDepthDisplay; ++step) {
        std::vector<int> ticks;
        for (int val = step; val < maxDepthDisplay; val += step) {
            ticks.push_back(val);
        }

        int tickCount = static_cast<int>(ticks.size());
        if (tickCount >= 1 && tickCount <= (maxLines - 1)) {
            if (tickCount > static_cast<int>(bestTicks.size())) {
                bestTicks = ticks;
            }
        }
    }
    //qDebug() << "RULER TICKS: Tick Value result general:" << bestTicks << "using input" << maxDepth << ", metric" << isMetric << "is2DTransducer" << is2DTransducer << "isSideScan2DView" << isSideScan2DView << "isSideScanLeftHand" << isSideScanLeftHand;

    if (!is2DTransducer) {
        std::vector<int> mirroredTicks;
        for (auto it = bestTicks.rbegin(); it != bestTicks.rend(); ++it) {
            mirroredTicks.push_back(-(*it));
        }
        mirroredTicks.insert(mirroredTicks.end(), bestTicks.begin(), bestTicks.end());
        //qDebug() << "SIDE SCAN: Tick Value result !is2DTransducer:" << mirroredTicks;
        return mirroredTicks;
    }

    return bestTicks;
}



