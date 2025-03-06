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
            //Support for imperial and metric
            // Convert to imperial if needed (multiply by conversion factor)
            float finalRangeVal = rangeVal * conversionFactor;
            if (isMetric_) {
                //Changed to 1 decimal
                lineText.append( { QString::number(finalRangeVal, 'f', 1) + QObject::tr(" m") } );
            } else {
                //Changed to 1 decimal
                lineText.append( { QString::number(finalRangeVal, 'f', 1) + QObject::tr(" ft") } );
            }

        }

        if (isFillWidth())
            p->drawLine(0, posY, imageWidth, posY);
        else if (isHorizontal_) {
            p->drawLine(imageWidth - fm.horizontalAdvance(lineText) - textXOffset, posY, imageWidth, posY); // line
        } else {
            // For vertical mode, use a fixed line length instead of one based on text width.
            const int fixedLineLength = 50; // Adjust this value as needed.
            p->drawLine(imageWidth - textXOffset - fixedLineLength, posY, imageWidth - textXOffset, posY);
        }

        if (!lineText.isEmpty()) {
            if (isHorizontal_) {
                p->drawText(imageWidth - fm.horizontalAdvance(lineText) - textXOffset, posY - textYOffset, lineText);
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
    }

    if (cursor.distance.isValid()) {
        p->setFont(QFont("Asap", 26, QFont::Bold));
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
            p->drawText(imageWidth - textXOffset / 2 - range_text.count() * 25, imageHeight - 10, range_text);
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



