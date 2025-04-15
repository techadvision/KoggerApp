#include "Plot2D.h"
#include <QObject>


Plot2DGrid::Plot2DGrid() : angleVisibility_(false), isMetric_(true), isHorizontal_(true)
{}


bool Plot2DGrid::draw(Canvas& canvas, Dataset* dataset, DatasetCursor cursor)
{
    if (!isVisible())
        return false;

    QPen pen(_lineColor);
    pen.setWidth(_lineWidth);
    //Changed, set the color
    //pen.setColor(QColor(255, 255, 255));

    QPainter* p = canvas.painter();
    p->setPen(pen);
    //Changed increased the font size 14 to 26
    p->setFont(QFont("Asap", 20, QFont::Bold));
    QFontMetrics fm(p->font());

    const int imageHeight{ canvas.height() }, imageWidth{ canvas.width() },
        linesCount{ _lines }, textXOffset{ 30 }, textYOffset{ 10 };

    float conversionFactor = 1.0; // Default to metric (meters)
    if (!isMetric_) {
        conversionFactor = 3.28084; // Convert to feet if not metric
    }

    qreal scaleX = p->transform().m11();

    for (int i = 1; i < linesCount; ++i) {

        const int posY = i * imageHeight / linesCount;

        QString lineText;

        if (_velocityVisible && cursor.velocity.isValid()) { // velocity
            const float velFrom{ cursor.velocity.from }, velTo{ cursor.velocity.to },
                velRange{ velTo - velFrom }, attVal{ velRange * i / linesCount + velFrom };
            lineText.append({ QString::number(attVal , 'f', 2) + QObject::tr(" m/s    ")});
        }
        if (angleVisibility_ && cursor.attitude.isValid()) { // angle
            const float attFrom{ cursor.attitude.from }, attTo{ cursor.attitude.to },
                attRange{ attTo - attFrom }, attVal{ attRange * i / linesCount + attFrom };
            QString text{ QString::number(attVal, 'f', 0) + QStringLiteral("°    ") };
            lineText.append(text);
        }
        if (cursor.distance.isValid()) { // depth
            const float distFrom{ cursor.distance.from }, distTo{ cursor.distance.to },
            distRange{ distTo - distFrom }, rangeVal{ distRange * i / linesCount + distFrom };
            float finalRangeVal = rangeVal * conversionFactor;
            if (isMetric_) {
                //Changed to 1 decimal
                lineText.append( { QString::number(finalRangeVal, 'f', 1) + QObject::tr(" m") } );
            } else {
                //Changed to 1 decimal
                lineText.append( { QString::number(finalRangeVal, 'f', 1) + QObject::tr(" ft") } );
            }

        }

        if (!lineText.isEmpty()) {
            if (isHorizontal_) {
                int desiredX_device = imageWidth - fm.horizontalAdvance(lineText) - textXOffset;
                QPoint textPos(desiredX_device, posY - textYOffset);
                drawTextWithBackdrop(p, lineText, textPos, TextAnchor::BaselineLeft, 5, imageWidth, 5);
            } else {
                p->save();
                int textWidth = fm.horizontalAdvance(lineText);
                int pivotX = imageWidth - textXOffset;
                int pivotY = posY - textYOffset;
                p->translate(pivotX, pivotY);
                p->rotate(90);
                p->drawText(-textWidth, fm.ascent(), lineText);
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

    if (cursor.distance.isValid()) {
        p->setFont(QFont("Asap", 20, QFont::Bold));
        //Support for metric and imperial
        float val{ cursor.distance.to * conversionFactor };
        //Changed to 1 decimal
        QString range_text = "";

        if (isMetric_) {
            range_text = QString::number(val, 'f', (val == static_cast<int>(val)) ? 0 : 1) + QObject::tr(" m");
        } else {
            range_text = QString::number(val, 'f', (val == static_cast<int>(val)) ? 0 : 1) + QObject::tr(" ft");
        }

        if (isHorizontal_) {
            int desiredX_device = imageWidth - textXOffset / 2 - range_text.count() * 25;
            int baselineY = imageHeight - 10;  // device coordinate for text baseline
            drawTextWithBackdrop(p, range_text, QPoint(desiredX_device, baselineY),
                                 TextAnchor::BaselineLeft,
                                 5,            // margin
                                 imageWidth,   // forceRightEdge: backdrop extends to screen edge.
                                 5            // verticalOffset: lower the backdrop by 5 pixels.
                                 /* textColor and backdropColor default to white and semi-transparent black */ );

        } else {
            p->save();
            int textWidth = fm.horizontalAdvance(range_text);
            int textHeight = fm.height();
            // In horizontal mode the text's center X is:
            int centerX = imageWidth - textXOffset / 2 - textWidth / 2;
            // The Y remains the same as the horizontal drawing (bottom edge position)
            int centerY = imageHeight - 30 - textHeight;
            // Translate to that center pivot point.
            p->translate(centerX, centerY);
            // Rotate the text by +90 degrees (clockwise).
            p->rotate(90);
            // Draw the text so that its center aligns with the pivot.
            // (drawText positions text at the baseline of the left edge,
            // so we offset by half the text width and half the text height)
            p->drawText(-textWidth / 2, textHeight / 2, range_text);
            p->restore();
        }
    }

    Epoch* lastEpoch = dataset->last();
    Epoch* preLastEpoch = dataset->lastlast();
    float distance = NAN;
    if (cursor.distance.isValid()) {
        if (lastEpoch != NULL && isfinite(lastEpoch->rangeFinder())) {
            distance = lastEpoch->rangeFinder();
            //qDebug("TAV: Plot2DGrid calculated distance lastEpoch: %f", distance);
        } else if (preLastEpoch != NULL && isfinite(preLastEpoch->rangeFinder())) {
            distance = preLastEpoch->rangeFinder();
            //qDebug("TAV: Plot2DGrid calculated distance preLastEpoch: %f", distance);
        }
    } else {
        qDebug("TAV: Plot2DGrid calculated distance not valid");
    }

    if (_rangeFinderLastVisible) {
        if (isfinite(distance)) {
            pen.setColor(QColor(250, 100, 0));
            p->setPen(pen);
            //Changed to bold and font 40 to 46
            p->setFont(QFont("Asap", 46, QFont::Bold));
            float val{ round(distance * 100.f) / 100.f };
            //Changed to 1 decimal
            QString rangeText = QString::number(val, 'f', (val == static_cast<int>(val)) ? 0 : 1) + QObject::tr(" m");
            p->drawText(imageWidth / 2 - rangeText.count() * 32, imageHeight - 15, rangeText);
            //qDebug("TAV: Plot2DGrid wrote distance to screen: %f", distance);
        }
    }


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



