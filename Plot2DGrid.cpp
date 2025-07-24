#include "Plot2D.h"
#include <QObject>
#include <vector>
#include <cmath>

constexpr float epsilon = 0.001f;


Plot2DGrid::Plot2DGrid() : angleVisibility_(false), isMetric_(true), isHorizontal_(true), isSideScanOnLeftHandSide_(true)
{}


bool Plot2DGrid::draw(Canvas& canvas, Dataset* dataset, DatasetCursor cursor)
{
    if (!isVisible())
        return false;

    //bool isSideScanOnLeftHandSide = false;
    bool isSideScan2DView = false;
    bool is2DTransducer = false;
    const int textPadding = 5;

    if (g_pulseRuntimeSettings) {
        isSideScanOnLeftHandSide_ = g_pulseRuntimeSettings->property("isSideScanLeftHand").toBool();
        isSideScan2DView = g_pulseRuntimeSettings->property("isSideScan2DView").toBool();
        is2DTransducer = g_pulseRuntimeSettings->property("is2DTransducer").toBool();
    }

    bool flipImage = isSideScanOnLeftHandSide_ && isSideScan2DView;

    QPen pen(_lineColor);
    pen.setWidth(_lineWidth);

    QPainter* p = canvas.painter();
    p->setPen(pen);
    p->setFont(QFont("Asap", 20, QFont::Bold));
    QFontMetrics fm(p->font());

    const int imageHeight{ canvas.height() }, imageWidth{ canvas.width() },
        linesCount{ _lines }, textXOffset{ 30 }, textYOffset{ 10 };

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

    std::vector<int> tickValues = calculateRulerTicks(static_cast<int>(logicalMaxDepth), isMetric_, is2DTransducer, isSideScan2DView, isSideScanOnLeftHandSide_);

    int linesCountNew = static_cast<int>(tickValues.size()) + 1; // +1 for final bottom value

    qreal scaleX = p->transform().m11();

    for (int i = 1; i < linesCountNew; ++i) {

        //int displayIndex = flipImage ? (linesCountNew - i) : i;
        int displayIndex = i;

        float tickValue = static_cast<float>(tickValues[displayIndex - 1]); // i starts from 1
        //qDebug() << "SIDE SCAN: Tick Value:" << tickValue;
        float tickMeters = isMetric_ ? tickValue : tickValue / 3.28084f;

        // Make sure denominator is never zero
        float totalRange = toDepth - fromDepth;
        if (totalRange == 0.0f)
            totalRange = 0.0001f; // prevent divide-by-zero crash

        float relative = (tickMeters - fromDepth) / totalRange;
        int posY = static_cast<int>(relative * imageHeight);
        int posYflipped = posY;

        //NEW
        if (flipImage) {
            posYflipped = imageHeight - posY;
        }

        QString lineText = " ";

        if (_velocityVisible && cursor.velocity.isValid()) { // velocity
            const float velFrom{ cursor.velocity.from }, velTo{ cursor.velocity.to },
                velRange{ velTo - velFrom }, attVal{ velRange * displayIndex / linesCountNew + velFrom };
            lineText.append({ QString::number(attVal , 'f', 2) + QObject::tr(" m/s    ")});
        }
        if (angleVisibility_ && cursor.attitude.isValid()) { // angle
            const float attFrom{ cursor.attitude.from }, attTo{ cursor.attitude.to },
                attRange{ attTo - attFrom }, attVal{ attRange * displayIndex / linesCountNew + attFrom };
            QString text{ QString::number(attVal, 'f', 0) + QStringLiteral("°    ") };
            lineText.append(text);
        }

        bool isNegativeTick = tickValue < 0.0f;

        if (cursor.distance.isValid()) { // depth

            float displayValue = std::abs(tickValue);  // always positive in text
            if (isMetric_) {
                lineText.append( { QString::number(displayValue, 'f', 0) + QObject::tr(" m") } );
            } else {
                lineText.append( { QString::number(displayValue, 'f', 0) + QObject::tr(" ft") } );
            }
        }

        if (!lineText.isEmpty()) {
            if (isHorizontal_) {
#ifdef Q_OS_ANDROID
                int desiredX_device = imageWidth - fm.horizontalAdvance(lineText) - textXOffset;
                int baselineY = posYflipped - textYOffset;
                //OLD
                /*
                if (flipImage) {
                    baselineY = imageHeight - baselineY;
                }
                */
                QPoint textPos(desiredX_device, posYflipped - textYOffset);
                drawTextWithBackdrop(p, lineText, textPos, TextAnchor::BaselineLeft, 5, imageWidth, 5);
#endif
#ifdef Q_OS_WINDOWS
                p->drawText(imageWidth - fm.horizontalAdvance(lineText) - textXOffset, posYflipped - textYOffset, lineText);
#endif
            } else {
                p->save();
                int textWidth = fm.horizontalAdvance(lineText);
                int pivotX = imageWidth - textXOffset;
                int pivotY = posYflipped - textYOffset;

                p->translate(pivotX, pivotY);
                p->rotate(90);

                //bool isNegative = lineText.trimmed().startsWith('-');
                bool isNegative = isNegativeTick;

                // Draw text to the left (default) or right (for negatives)
                if (isNegative) {
                    p->drawText(textPadding, fm.ascent(), lineText);  // draw to the right of the line
                } else {
                    p->drawText(-textWidth, fm.ascent(), lineText);  // draw to the left (default)
                }

                //p->drawText(-textWidth, textY, lineText);

                p->restore();

            }
        }

        if (isFillWidth())
            p->drawLine(0, posY, imageWidth, posY);
        else if (isHorizontal_) {
            if (scaleX != 1.0) {
                int desiredX_device = imageWidth - fm.horizontalAdvance(lineText) - textXOffset;
                if (scaleX != 1.0) {
                    int logicalX = static_cast<int>((desiredX_device - (1 - scaleX) * imageWidth) / scaleX);
                    p->drawLine(logicalX, posY, imageWidth, posY);
                } else {
                    p->drawLine(desiredX_device, posY, imageWidth, posY);
                }
            } else {
                p->drawLine(imageWidth - fm.horizontalAdvance(lineText) - textXOffset, posY, imageWidth, posY); // line
            }

        } else {
            // For vertical mode, use a fixed line length instead of one based on text width.
            const int fixedLineLength = 50; // Adjust this value as needed.
            p->drawLine(imageWidth - textXOffset - fixedLineLength, posY, imageWidth - textXOffset, posY);
        }
    }

    if (cursor.distance.isValid() && !flipImage && is2DTransducer) {
        p->setFont(QFont("Asap", 20, QFont::Bold));

        float val{ cursor.distance.to * conversionFactor };

        QString range_text = QString::number(val, 'f', (isMetric_ ? 0 : 1)) + (isMetric_ ? QObject::tr(" m") : QObject::tr(" ft"));

        if (isHorizontal_) {
#ifdef Q_OS_ANDROID
            int desiredX_device = imageWidth - textXOffset / 2 - range_text.count() * 25;
            int baselineY = imageHeight - 10;  // device coordinate for text baseline
            if (flipImage) {
                baselineY = imageHeight - baselineY;
            }
            drawTextWithBackdrop(p, range_text, QPoint(desiredX_device, baselineY),
                                 TextAnchor::BaselineLeft,
                                 5,            // margin
                                 imageWidth,   // forceRightEdge: backdrop extends to screen edge.
                                 5            // verticalOffset: lower the backdrop by 5 pixels.
                                 /* textColor and backdropColor default to white and semi-transparent black */ );
#endif
#ifdef Q_OS_WINDOWS
            p->drawText(imageWidth - textXOffset / 2 - range_text.count() * 25, imageHeight - 10, range_text);
#endif
        } else {
            p->save();

            int textWidth = fm.horizontalAdvance(range_text);
            int textHeight = fm.height();

            int centerX = imageWidth - textXOffset / 2 - textWidth / 2;
            int centerY = imageHeight - 30 - textHeight;

            p->translate(centerX, centerY);
            p->rotate(90);

            p->drawText(-textWidth / 2, textHeight / 2, range_text);

            p->restore();
        }
    }

    /*
    if (_rangeFinderLastVisible && cursor.distance.isValid()) {
        Epoch* lastEpoch = dataset->last();
        Epoch* preLastEpoch = dataset->lastlast();
        float distance = NAN;
        if (cursor.distance.isValid()) {
            if (lastEpoch != NULL && isfinite(lastEpoch->rangeFinder())) {
                distance = lastEpoch->rangeFinder();
            } else if (preLastEpoch != NULL && isfinite(preLastEpoch->rangeFinder())) {
                distance = preLastEpoch->rangeFinder();
            }
        } else {
            qDebug("TAV: Plot2DGrid calculated distance not valid");
        }

        if (isfinite(distance)) {
            pen.setColor(QColor(250, 100, 0));
            p->setPen(pen);
            p->setFont(QFont("Asap", 40, QFont::Normal));
            float val{ round(distance * 100.f) / 100.f };
            bool isInteger = std::abs(val - std::round(val)) < epsilon;
            QString rangeText = QString::number(val, 'f', isInteger ? 0 : 2) + QObject::tr(" m");
            p->drawText(imageWidth / 2 - rangeText.count() * 32, imageHeight - 15, rangeText);
        }
    }
    */


    return true;
}

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
    isMetric_ = metric;
}

void Plot2DGrid::setGridHorizontal(bool horizontal)
{
    isHorizontal_ = horizontal;
}

void Plot2DGrid::setSideScanOnLeftHandSide(bool isLeftSideInstalled)
{
    isSideScanOnLeftHandSide_ = isLeftSideInstalled;
}

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
    //qDebug() << "SIDE SCAN: Tick Value result general:" << bestTicks;

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



