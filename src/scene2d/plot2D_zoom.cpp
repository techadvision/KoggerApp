#include "plot2D_zoom.h"
#include <QPainterPath>
#include <QPainterPathStroker>
#include <QFontMetrics>
#include <QtMath>

void Plot2DZoom::drawOutlinedDepth(QPainter* p, const QRect& zoomRect,
                                   const QFont& font, int titlePad, int scale,
                                   double depthMeters) const
{
    if (!std::isfinite(depthMeters)) return;

    QFontMetrics fm(font);
    const QString dtxt = QStringLiteral("Cross: ")
                         + QString::number(depthMeters, 'f', (depthMeters < 10) ? 2 : 1)
                         + QStringLiteral(" m");

    const int textW = fm.horizontalAdvance(dtxt);
    const int textX = zoomRect.center().x() - textW/2;
    const int textBaselineY = zoomRect.top() + titlePad + fm.ascent();

    QPainterPath glyphs;
    glyphs.addText(QPointF(textX, textBaselineY), font, dtxt);

    // crisp black rim behind white fill
    QPainterPathStroker stroker;
    stroker.setWidth(qMax(1.0, 2.0 * double(scale)));
    stroker.setJoinStyle(Qt::RoundJoin);
    stroker.setMiterLimit(2.0);

    const QPainterPath outline = stroker.createStroke(glyphs);

    p->setRenderHint(QPainter::Antialiasing, true);
    p->setRenderHint(QPainter::TextAntialiasing, true);
    p->fillPath(outline, Qt::black);
    p->fillPath(glyphs,  Qt::white);
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
    const int btnH      = 30 * scale;
    const int btnW      = 120 * scale;
    const int btnPad    = 8 * scale;

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

    // Button rect (inside zoom, bottom-center)
    QRect addRect;
    if (in.showAddBtn) {
        addRect = QRect(0, 0, btnW, btnH);
        addRect.moveCenter(QPoint(zoomRect.center().x(),
                                  zoomRect.bottom() - btnPad - btnH/2));
    }

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
    if (in.rotateForView)   tile = tile.transformed(QTransform().rotate(90));
    if (in.flipForLeftHand) tile = tile.transformed(QTransform().scale(1, -1));

    // draw zoom tile
    p->drawPixmap(zoomRect, tile);

    // crosshair overlay inside zoom (semi-transparent white)
    {
        const int cx = zoomRect.center().x();
        const int cy = zoomRect.center().y();
        QPen crossPen(QColor(255,255,255,153)); // ~60% alpha
        crossPen.setWidthF(qMax(1.0, 1.0 * double(scale)));
        p->setPen(crossPen);
        p->drawLine(zoomRect.left(),  cy, zoomRect.right(), cy);
        p->drawLine(cx, zoomRect.top(), cx, zoomRect.bottom());
    }

    // outlined depth text (top-center inside zoom)
    {
        QFont font("Asap", 14 * scale, QFont::Normal);
        font.setPixelSize(18 * scale);
        p->setFont(font);
        drawOutlinedDepth(p, zoomRect, font, titlePad, scale, in.depthMeters);
    }

    // Add WP button
    if (in.showAddBtn) {
        p->setBrush(QColor(70,70,70));
        p->setPen(QColor(200,200,200));
        p->drawRoundedRect(addRect, 6*scale, 6*scale);
        p->drawText(addRect, Qt::AlignCenter, QObject::tr("Add WP"));
    }

    // outputs for hit-testing
    out.panelRect = panelRect;
    out.addRect   = addRect;

    p->restore();
    return out;
}
