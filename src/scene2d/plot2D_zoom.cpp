#include "plot2D_zoom.h"
#include <QPainterPath>
#include <QPainterPathStroker>
#include <QFontMetrics>
#include <QtMath>
#include <QSvgRenderer>
#include <QFileInfo>
#include <QLocale>


// Draw white text with a black outline inside rect, honoring alignment.
// Uses the painter's current font. outlinePx is the outline thickness in device px.
static void drawOutlinedText(QPainter* p, const QRect& rect,
                             const QString& text, Qt::Alignment align, int outlinePx)
{
    if (!p || text.isEmpty()) return;

    const QFont font = p->font();
    QFontMetrics fm(font);

    // Get a layout rect for the text with alignment
    QRect br = fm.boundingRect(rect, align, text);

    // Convert that into a baseline origin for QPainterPath::addText
    const int x = br.left();
    const int baselineY = br.top() + fm.ascent();

    QPainterPath glyphs;
    glyphs.addText(QPointF(x, baselineY), font, text);

    QPainterPathStroker stroker;
    stroker.setWidth(qMax(1.0, double(outlinePx)));
    stroker.setJoinStyle(Qt::RoundJoin);
    stroker.setMiterLimit(2.0);

    const QPainterPath outline = stroker.createStroke(glyphs);

    p->setRenderHint(QPainter::Antialiasing, true);
    p->setRenderHint(QPainter::TextAntialiasing, true);
    p->fillPath(outline, QColor(0,0,0,200));
    p->fillPath(glyphs,  Qt::white);
}



static void drawSvgCentered(QPainter* p, const QString& path, const QRect& slotRect, int iconPx)
{
    auto resolvePath = [](const QString& in) -> QString {
        if (QFileInfo::exists(in)) return in;
        QString qrc = in;
        if (qrc.startsWith("./")) qrc.replace(0, 2, ":/");
        else if (!qrc.startsWith(":/")) qrc.prepend(":/");
        return QFileInfo::exists(qrc) ? qrc : QString();
    };

    const QString usePath = resolvePath(path);
    if (usePath.isEmpty()) return;

    QSvgRenderer svg(usePath);
    if (!svg.isValid()) return;

    const int side = qMin(iconPx, qMin(slotRect.width(), slotRect.height())); // square
    const int x = slotRect.center().x() - side/2;
    const int y = slotRect.center().y() - side/2;
    svg.render(p, QRectF(x, y, side, side));
}



Plot2DZoom::Output Plot2DZoom::draw(QPainter* p, const Input& in) const
{
    Output out;
    if (!p || !in.echPixmap || in.echPixmap->isNull())
        return out;

    const int scale     = qMax(1, in.scale);
    const int innerSize = qMax(30, in.boxSizePx * scale);
    const int margin    = 6 * scale;
    const int titlePad  = 8 * scale;   // gap from top of zoom to baseline
    const int btnH      = 42 * scale;
    const int btnW      = 42 * scale;
    const int btnPad    = 8 * scale;
    const int iconPx    = 32 * scale;

    // Layout: content == innerSize x innerSize
    const int contentW = innerSize;
    const int contentH = innerSize;

    const int xShift = 50 * scale;
    const int yShift = 40 * scale;

    // Decide which side to place the panel relative to anchor (device px)
    const int vpW = in.viewport.width();
    const bool onTheRight  = (vpW - in.anchorPx.x() - (xShift + 15*scale)) < contentW;
    const int  spaceBelow  = in.anchorPx.y();
    const int  neededBelow = contentH + (yShift + 15*scale);
    const bool placeAbove  = (spaceBelow < neededBelow);

    QPoint topLeft;
    if (!placeAbove) {
        topLeft = onTheRight
                      ? QPoint(in.anchorPx.x() - xShift - contentW, in.anchorPx.y() - yShift - contentH)
                      : QPoint(in.anchorPx.x() + xShift,            in.anchorPx.y() - yShift - contentH);
    } else {
        topLeft = onTheRight
                      ? QPoint(in.anchorPx.x() - xShift - contentW, in.anchorPx.y() + yShift)
                      : QPoint(in.anchorPx.x() + xShift,            in.anchorPx.y() + yShift);
    }

    QRect contentRect(topLeft, QSize(contentW, contentH));
    QRect panelRect = contentRect.adjusted(-margin, -margin, +margin, +margin);

    // Zoom rect centered in panel
    QRect zoomRect(QPoint(0,0), QSize(innerSize, innerSize));
    zoomRect.moveCenter(panelRect.center());


    // --- panel bg + frame ---
    p->save();
    p->resetTransform();              // draw UI in device coords
    p->setPen(Qt::NoPen);
    p->setBrush(QColor(45,45,45));
    p->drawRect(panelRect);
    p->setPen(QColor(255,255,255));
    p->drawRect(zoomRect.adjusted(-1,-1,+1,+1));

    // --- source crop in pixmap coords centered at world point ---
    const int imgW = in.echPixmap->width();
    const int imgH = in.echPixmap->height();

    const double srcW = double(innerSize) / double(qMax(1, in.zoomFactor));
    QRectF src(in.centerWorld.x() - srcW/2.0,
               in.centerWorld.y() - srcW/2.0,
               srcW, srcW);

    // clamp to image bounds
    if (src.left()   < 0)        src.moveLeft(0);
    if (src.top()    < 0)        src.moveTop(0);
    if (src.right()  > imgW-1)   src.moveRight(imgW-1);
    if (src.bottom() > imgH-1)   src.moveBottom(imgH-1);

    QPixmap tile = in.echPixmap->copy(src.toRect());
    //if (in.rotateForView)   tile = tile.transformed(QTransform().rotate(90));
    if (in.rotateForView)   tile = tile.transformed(QTransform().rotate(-90));
    if (in.flipForLeftHand) tile = tile.transformed(QTransform().scale(1, -1));

    // draw zoom tile
    p->drawPixmap(zoomRect, tile);

    // subtle small cross at tap point (10 px arms), not full-width
    {
        const int cx = zoomRect.center().x();
        const int cy = zoomRect.center().y();
        const int arm = 10 * scale;
        QPen crossPen(QColor(255,255,255,180)); // slightly stronger alpha
        crossPen.setWidthF(qMax(1.0, 1.0 * double(scale)));
        p->setPen(crossPen);
        p->drawLine(cx - arm, cy, cx + arm, cy);
        p->drawLine(cx, cy - arm, cx, cy + arm);
    }

    // --------- INFO BAR (values) ---------
    {
        const int pad = 8 * scale;

        // Two small top rectangles inside the zoom image
        QRect leftRect (zoomRect.left() + pad,                 zoomRect.top() + pad,
                       zoomRect.width()/2 - 2*pad,            24 * scale);
        QRect rightRect(zoomRect.left() + zoomRect.width()/2 + pad, zoomRect.top() + pad,
                        zoomRect.width()/2 - 2*pad,            24 * scale);

        // Prepare text
        QFont f("Asap", 14 * scale, QFont::DemiBold);
        f.setPixelSize(18 * scale);
        p->setFont(f);

        const QLocale us = QLocale::c(); // force US-style formatting (decimal dot)
        const float conversionFactor = in.isMetric ? 1.0f : 3.28084f;

        const double depthAbs = std::isfinite(in.depthMeters) ? std::abs(in.depthMeters * conversionFactor) : NAN;
        const double crossAbs = std::isfinite(in.crossMeters) ? std::abs(in.crossMeters * conversionFactor) : NAN;

        QString leftText = std::isfinite(depthAbs)
                               ? in.isMetric
                                     ? QStringLiteral("D: %1 m").arg(us.toString(depthAbs, 'f', 1))
                                     : QStringLiteral("D: %1 ft").arg(us.toString(depthAbs, 'f', 1))
                               : QString();

        QString rightText;
        if (std::isfinite(crossAbs)) {
            if (!in.isDualSideScan) {
                // 2D: always down
                rightText = QStringLiteral("v: %1 m").arg(us.toString(crossAbs, 'f', 1));
            } else {
                if (!std::isfinite(depthAbs) || crossAbs <= depthAbs + 1e-6) {
                    rightText = in.isMetric
                                    ? QStringLiteral("v: %1 m").arg(us.toString(crossAbs, 'f', 1))
                                    : QStringLiteral("v: %1 ft").arg(us.toString(crossAbs, 'f', 1));
                } else {
                    const double lateral = qMax(0.0, crossAbs - depthAbs);
                    const QChar arrow = (in.dirSide < 0) ? QLatin1Char('<') : QLatin1Char('>');
                    rightText = in.isMetric
                                    ? QStringLiteral("%1: %2 m").arg(QString(arrow), us.toString(lateral, 'f', 1))
                                    : QStringLiteral("%1: %2 ft").arg(QString(arrow), us.toString(lateral, 'f', 1));
                }
            }
        }

        // Draw with outline for legibility
        if (!leftText.isEmpty())
            drawOutlinedText(p, leftRect,  leftText,  Qt::AlignVCenter | Qt::AlignLeft,  2 * scale);
        if (!rightText.isEmpty())
            drawOutlinedText(p, rightRect, rightText, Qt::AlignVCenter | Qt::AlignRight, 2 * scale);
    }

    // --- Full-width button bar at the bottom (left = Abort, right = Add) ---
    const int bottomMargin = 0 * scale;
    const int barTop = zoomRect.bottom() - bottomMargin - btnH;
    QRect barRect(zoomRect.left(), barTop, zoomRect.width(), btnH);

    // Split the bar into two equal halves
    QRect abortRect(barRect.left(), barRect.top(), barRect.width()/2, barRect.height());

    QRect addRect;
    if (in.showAddBtn) {
        addRect = QRect(barRect.left() + barRect.width()/2, barRect.top(),
                        barRect.width()/2, barRect.height());
    } else {
        addRect = QRect(); // no add button
    }

    p->setBrush(QColor(70,70,70));
    p->setPen(QColor(200,200,200));

    // Abort button
    p->drawRoundedRect(abortRect, 6*scale, 6*scale);
    drawSvgCentered(p, QStringLiteral("./icons/ui/pulse_zoom_close.svg"), abortRect, iconPx);

    // Add button
    if (!addRect.isEmpty()) {
        p->drawRoundedRect(addRect, 6*scale, 6*scale);
        drawSvgCentered(p, QStringLiteral("./icons/ui/pulse_zoom_add_marker.svg"), addRect, iconPx);
    }

    // Define a "dead tap" area above the button bar
    QRect tapDeadRect = zoomRect.adjusted(0, 0, 0, -(btnH + bottomMargin));
    // outputs for hit-testing
    out.panelRect = panelRect;
    out.tapDeadRect = tapDeadRect;
    out.addRect   = addRect;
    out.abortRect = abortRect;

    p->restore();
    return out;
}
