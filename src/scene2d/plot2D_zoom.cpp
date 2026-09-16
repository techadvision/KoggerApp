#include "plot2D_zoom.h"
#include <QPainterPath>
#include <QPainterPathStroker>
#include <QFontMetrics>
#include <QtMath>
#include <QSvgRenderer>
#include <QFileInfo>
#include <QLocale>
#include <QCoreApplication>
#include <cmath>
#include "UiMetrics.h"


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




// ---------------------------------------------------------------------------
// PULSE V2 LOUPE - the palette, the words, and the one helper the old path lacked
// ---------------------------------------------------------------------------

namespace {

// THE V2 VOCABULARY, the same five values PulsePausedGutter.qml and the rail paint with.
// Repeated here rather than shared because QML colours cannot be reached from a QPainter
// layer; if the rail's amber ever moves, it moves in both places or the loupe stops
// belonging to the surface it sits on.
const QColor kPanelBg   (0x0f, 0x13, 0x17, 0xee);
const QColor kAccent    (0xd8, 0xa2, 0x1f);
const QColor kAccentDim (0xd8, 0xa2, 0x1f, 0x80);
const QColor kInk       (0x0f, 0x13, 0x17);
const QColor kText      (0xf4, 0xea, 0xd6);
const QColor kTextDim   (0xf4, 0xea, 0xd6, 0xa0);
const QColor kTileEdge  (0xf4, 0xea, 0xd6, 0x60);

// THE WORDS, in one place because they are Olav's to change and he should not have to
// read a paint routine to find them. The no-position sentence is his, verbatim: it
// replaces classic's green play/pause checkbox, and it states the CONSEQUENCE rather
// than the telemetry that caused it.
inline QString kTitleZoom()     { return QCoreApplication::translate("Plot2DZoom", "ZOOM"); }
inline QString kLabelBottom()   { return QCoreApplication::translate("Plot2DZoom", "Bottom"); }
inline QString kLabelCursor()   { return QCoreApplication::translate("Plot2DZoom", "Cursor"); }
inline QString kLabelLatLeft()  { return QCoreApplication::translate("Plot2DZoom", "Lateral left"); }
inline QString kLabelLatRight() { return QCoreApplication::translate("Plot2DZoom", "Lateral right"); }
inline QString kBtnDismiss()    { return QCoreApplication::translate("Plot2DZoom", "Dismiss"); }
inline QString kBtnAdd()        { return QCoreApplication::translate("Plot2DZoom", "Add waypoint"); }
inline QString kNoPosition()    { return QCoreApplication::translate("Plot2DZoom",
                                        "No position — you can inspect the echogram, but not mark it"); }

// TINTING, which the old path never needed because every button was grey. Both loupe
// icons are drawn #fffff0, and near-white on the filled amber button is the one place
// that is wrong. QSvgRenderer cannot recolour, so the icon is rendered to a transparent
// pixmap and the colour composited into its alpha. The SVG files stay as they are, which
// keeps them right everywhere else they are used.
void drawSvgTinted(QPainter* p, const QString& path, const QRect& slotRect,
                   int iconPx, const QColor& tint)
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

    const int side = qMin(iconPx, qMin(slotRect.width(), slotRect.height()));
    if (side <= 0) return;

    QPixmap glyph(side, side);
    glyph.fill(Qt::transparent);
    {
        QPainter gp(&glyph);
        gp.setRenderHint(QPainter::Antialiasing, true);
        svg.render(&gp, QRectF(0, 0, side, side));
        gp.setCompositionMode(QPainter::CompositionMode_SourceIn);
        gp.fillRect(QRect(0, 0, side, side), tint);
    }

    p->drawPixmap(slotRect.center().x() - side / 2,
                  slotRect.center().y() - side / 2,
                  glyph);
}

// One number formatted the one way, so a value cannot read 4.5 in one band and 4.50 in
// the next. Returns an empty string for a value that is not finite, and the caller draws
// the label anyway - a labelled blank says "not known", a missing row says nothing.
QString formatDistance(double meters, bool isMetric)
{
    if (!std::isfinite(meters))
        return QString();

    const QLocale us = QLocale::c();
    const double v = std::abs(meters) * (isMetric ? 1.0 : 3.28084);
    return QStringLiteral("%1 %2").arg(us.toString(v, 'f', 1),
                                       isMetric ? QStringLiteral("m") : QStringLiteral("ft"));
}

} // namespace

Plot2DZoom::Output Plot2DZoom::draw(QPainter* p, const Input& in) const
{
    Output out;
    if (!p || !in.echPixmap || in.echPixmap->isNull())
        return out;

    // THE ONE LINE THAT KEEPS THE CLASSIC LOUPE CLASSIC. Everything below it is the
    // panel exactly as it shipped; V2's is a separate method with a separate layout.
    if (in.v2Style)
        return drawV2(p, in);

    // Prefer the global UiMetrics scale if available
    const int   scale = qMax(1, in.scale);

    // Prefer the global UiMetrics scale if available
    UiMetrics* ui = UiMetrics::instance();
    const float s = ui ? ui->scale()
                       : float(scale);   // fallback: behave like before

    // Zoom content size: scale the "design" boxSizePx
    const int innerSize = qMax(30, int(in.boxSizePx * s));

    // Panel padding and title padding
    const int margin   = qMax(2, int(6 * s));
    const int titlePad = qMax(2, int(8 * s));   // (still here if you ever use it)

    // Button & icon sizing
    const int iconPx = ui ? ui->iconTouchSmall()
                          : qMax(16, int(24 * s));  // svg icon size inside buttons

    // button height: icon + vertical padding, with a reasonable minimum
    const int btnH   = ui ? qMax(iconPx + 2 * ui->marginS(), int(32 * s))
                        : qMax(32, int(42 * s));

    // Layout: content == innerSize x innerSize (in device px)
    const int contentW = innerSize;
    const int contentH = innerSize;

    // Distance from crosshair to zoom panel
    const int xShift = qMax(20, int(40 * s));
    const int yShift = qMax(10, int(30 * s));


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
    if (in.captureTile) {
        out.zoomTile   = tile;
        out.zoomSrcRect = src.toRect();
    }

    // subtle small cross at tap point (10 px arms), not full-width
    {
        const int cx  = zoomRect.center().x();
        const int cy  = zoomRect.center().y();
        const int arm = qMax(5, int(15 * s));

        QPen crossPen(QColor(255,255,255,255));
        crossPen.setWidthF(qMax(2.0, double(qMax(1, int(3 * s)))));
        p->setPen(crossPen);

        p->drawLine(cx - arm, cy, cx + arm, cy);
        p->drawLine(cx, cy - arm, cx, cy + arm);
    }


    // --------- INFO BAR (values) ---------
    {
        const int pad  = qMax(2, int(8 * s));

        // Height of the text bar: roughly font height + padding
        const int barH = ui ? qMax(ui->fontM() + pad, int(20 * s))
                            : qMax(20, int(24 * s));

        // Two top rectangles inside the zoom image
        QRect leftRect(zoomRect.left() + pad,
                       zoomRect.top()  + pad,
                       zoomRect.width()/2 - 2*pad,
                       barH);

        QRect rightRect(zoomRect.left() + zoomRect.width()/2 + pad,
                        zoomRect.top()  + pad,
                        zoomRect.width()/2 - 2*pad,
                        barH);

        // Prepare text using UiMetrics
        QFont f("Asap");
        if (ui)
            f.setPixelSize(ui->fontM());  // consistent with other medium labels
        else
            f.setPixelSize(qMax(10, int(18 * s)));
        f.setWeight(QFont::DemiBold);
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
        const int outlinePx = qMax(1, int(2 * s));
        if (!leftText.isEmpty())
            drawOutlinedText(p, leftRect,  leftText,
                             Qt::AlignVCenter | Qt::AlignLeft,
                             outlinePx);
        if (!rightText.isEmpty())
            drawOutlinedText(p, rightRect, rightText,
                             Qt::AlignVCenter | Qt::AlignRight,
                             outlinePx);

    }

    // --- Full-width button bar at the bottom (left = Abort, right = Add) ---
    const int bottomMargin = qMax(0, int(4 * s));
    const int barTop       = zoomRect.bottom() - bottomMargin - btnH;
    QRect barRect(zoomRect.left(), barTop, zoomRect.width(), btnH);

    // Split the bar into two equal halves
    QRect abortRect(barRect.left(), barRect.top(),
                    barRect.width()/2, barRect.height());

    QRect addRect;
    if (in.showAddBtn) {
        addRect = QRect(barRect.left() + barRect.width()/2, barRect.top(),
                        barRect.width()/2, barRect.height());
    } else {
        addRect = QRect(); // no add button
    }

    p->setBrush(QColor(70,70,70));
    p->setPen(QColor(200,200,200));

    const int corner = qMax(2, int(6 * s));

    // Abort button
    p->drawRoundedRect(abortRect, corner, corner);
    drawSvgCentered(p, QStringLiteral("./icons/ui/pulse_zoom_close.svg"),
                    abortRect, iconPx);

    // Add button
    if (!addRect.isEmpty()) {
        p->drawRoundedRect(addRect, corner, corner);
        drawSvgCentered(p, QStringLiteral("./icons/ui/pulse_zoom_add_marker.svg"),
                        addRect, iconPx);
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


// ---------------------------------------------------------------------------
// THE V2 LOUPE (Stage 4 b) - what it rebuilds, and why each band exists
// ---------------------------------------------------------------------------
//
// Three of the four changes below are defects rather than styling:
//
// 1. THE VALUES WERE PAINTED ON THE DATA. `D: 12.3` and `v: 4.5` sat inside the top of
//    the zoom image - over the patch of echogram you magnified in order to read it.
//    Labelling them in place would only have made the obstruction wider, so they come
//    OUT of the tile into their own band and the panel grows to hold them. That, not
//    the font, is what "both values labelled rather than abbreviated" costs.
//
// 2. DISMISS AND ADD WERE TWO EQUAL GREY HALVES, told apart by an icon alone - a
//    destructive action and a constructive one at identical weight, inside the picture.
//    They are a ghost and a filled button now, unequal, below the tile.
//
// 3. THE MAGNIFICATION WAS INVISIBLE. The panel has always magnified by `zoomFactor` and
//    never said so. It is in the header, and it reads THE SAME FIELD the crop divides
//    by - rule 2 in C++ clothing, so the header cannot drift from the picture.
//
// 4. AND THE GREEN PAUSE BUTTON IS ANSWERED HERE. Classic greens the play/pause checkbox
//    when MAVLink is detected: the technology, announced before anyone asked, in a corner
//    with nothing to do with waypoints. Olav's verdict was "easy, but not intuitive at
//    all". V2 says NOTHING while a waypoint can be placed - the Add button being there is
//    the whole message, and a sentence repeating it would be a second thing claiming one
//    job. It states the consequence only when it cannot, in the slot the button would
//    have occupied, at the moment the question arises.
//
// The panel is sized off `in.boxSizePx` exactly as the old one was, so the phone note -
// "we may distinguish size of zoom box with phone when we get into that" - stays one
// number at the call site rather than a rebuild.
Plot2DZoom::Output Plot2DZoom::drawV2(QPainter* p, const Input& in) const
{
    Output out;

    UiMetrics* ui = UiMetrics::instance();
    const int   scale = qMax(1, in.scale);
    const float s     = ui ? ui->scale() : float(scale);

    const auto px = [s](int designPx) { return qMax(1, int(designPx * s)); };

    // ---- the bands, top to bottom -----------------------------------------
    int       tile     = qMax(60, int(in.boxSizePx * s));   // not const: the fit clamp below
    const int pad      = px(12);
    const int headerH  = px(30);
    const int rowH     = px(28);
    const int btnH     = px(46);
    const int gapS     = px(6);
    const int gapM     = px(10);
    const int margin   = px(4);   // hoisted: the fit clamp needs it before placement does

    const bool canAdd = in.showAddBtn;

    QFont fLabel("Asap");
    fLabel.setPixelSize(ui ? ui->fontS() : px(15));
    QFont fValue("Asap");
    fValue.setPixelSize(ui ? ui->fontM() : px(18));
    fValue.setWeight(QFont::DemiBold);
    QFont fNote("Asap");
    fNote.setPixelSize(ui ? ui->fontS() : px(15));

    // The sentence wraps, so its height is a measurement rather than a constant - the
    // string is Olav's and may get longer or shorter without this file being touched. It is
    // a lambda because the fit clamp below changes the width it wraps into.
    const QString noteText = canAdd ? QString() : kNoPosition();
    const auto measureNote = [&](int wrapWidth) -> int {
        if (canAdd)
            return 0;
        QFontMetrics fm(fNote);
        return fm.boundingRect(QRect(0, 0, qMax(1, wrapWidth), 0),
                               Qt::TextWordWrap | Qt::AlignLeft | Qt::AlignTop,
                               noteText).height() + gapM;
    };

    // ---- THE PANEL MUST FIT THE PANE IT IS DRAWN IN ------------------------
    //
    // in.viewport is the PANE's own canvas, not the window - fed from p->viewport() in
    // plot2D_aim.cpp. Placement has always clamped against it; nothing ever asked whether
    // the panel FITS in it. So the size followed the window while the room followed the
    // pane, and the two part company exactly where Olav found them: a 10" tablet at an
    // Android split of 50% just fits, and at 60% the buttons go under the bottom edge,
    // because a larger window lifts UiMetrics::scale() off its 0.75 floor while the
    // internal dual view still gives the panel half the height to live in.
    //
    // THE TILE ABSORBS IT, NOT THE CHROME. Scaling the whole panel down would keep the
    // buttons proportional and eventually untappable - trading "hidden underneath" for
    // "visible but too small to hit", which is the same feature lost a different way. The
    // rows and the buttons keep their size; the zoomed tile gives up pixels, which costs
    // magnification and nothing else.
    //
    // IT ONLY EVER SHRINKS. `want >= tile` breaks out untouched, so every case that fits
    // today is byte-identical - Olav: "for a tablet it need not be any bigger than it is
    // right now." Two passes because noteH wraps into the tile's width, so a narrower tile
    // can want a taller note; the second pass settles it and a third has nothing to do.
    //
    // 60 px is the existing floor, kept. Below it the honest next step is a different
    // LAYOUT - the buttons beside the tile rather than beneath it - and not a smaller one.
    const int availW = in.viewport.width()  - 2 * margin;
    const int availH = in.viewport.height() - 2 * margin;

    for (int pass = 0; pass < 2; ++pass) {
        const int chromeH = headerH + gapS + gapM + (2 * rowH) + gapM
                          + measureNote(tile) + btnH + (2 * pad);
        const int want = qMin(availW - (2 * pad), availH - chromeH);
        if (want >= tile)
            break;
        tile = qMax(60, want);
    }

    const int noteH = measureNote(tile);

    const int contentW = tile;
    const int contentH = headerH + gapS + tile + gapM + (2 * rowH) + gapM + noteH + btnH;

    const int panelW = contentW + 2 * pad;
    const int panelH = contentH + 2 * pad;

    // ---- where it goes ----------------------------------------------------
    //
    // The same side/above-below choice the old panel made, and then a CLAMP the old one
    // did not need. This panel is half as tall again, so on a phone in portrait the
    // preferred corner can simply not exist; without the clamp a loupe near the bottom
    // edge would place its buttons off screen and the tap could never be made.
    const int xShift = px(40);
    const int yShift = px(30);

    const bool onTheRight = (in.viewport.width() - in.anchorPx.x() - (xShift + px(15))) < panelW;
    const bool placeAbove = (in.anchorPx.y() < panelH + (yShift + px(15)));

    QPoint topLeft;
    if (!placeAbove) {
        topLeft = onTheRight ? QPoint(in.anchorPx.x() - xShift - panelW, in.anchorPx.y() - yShift - panelH)
                             : QPoint(in.anchorPx.x() + xShift,          in.anchorPx.y() - yShift - panelH);
    } else {
        topLeft = onTheRight ? QPoint(in.anchorPx.x() - xShift - panelW, in.anchorPx.y() + yShift)
                             : QPoint(in.anchorPx.x() + xShift,          in.anchorPx.y() + yShift);
    }

    topLeft.setX(clampi(topLeft.x(), in.viewport.left() + margin,
                        qMax(in.viewport.left() + margin, in.viewport.right() - margin - panelW)));
    topLeft.setY(clampi(topLeft.y(), in.viewport.top() + margin,
                        qMax(in.viewport.top() + margin, in.viewport.bottom() - margin - panelH)));

    const QRect panelRect(topLeft, QSize(panelW, panelH));

    p->save();
    p->resetTransform();
    p->setRenderHint(QPainter::Antialiasing, true);
    p->setRenderHint(QPainter::TextAntialiasing, true);

    // ---- the panel --------------------------------------------------------
    const int panelRadius = px(6);
    p->setPen(Qt::NoPen);
    p->setBrush(kPanelBg);
    p->drawRoundedRect(panelRect, panelRadius, panelRadius);
    p->setBrush(Qt::NoBrush);
    p->setPen(QPen(kAccentDim, 1));
    p->drawRoundedRect(panelRect, panelRadius, panelRadius);

    int y = panelRect.top() + pad;
    const int x = panelRect.left() + pad;

    // ---- header: what this is, and how much bigger it is being shown ------
    {
        const QRect headerRect(x, y, contentW, headerH);

        p->setFont(fLabel);
        p->setPen(kTextDim);
        p->drawText(headerRect, Qt::AlignVCenter | Qt::AlignLeft, kTitleZoom());

        QFont fFactor = fValue;
        p->setFont(fFactor);
        p->setPen(kAccent);
        // The SAME field the crop below divides by. Not a second constant.
        p->drawText(headerRect, Qt::AlignVCenter | Qt::AlignRight,
                    QStringLiteral("%1%2").arg(qMax(1, in.zoomFactor)).arg(QChar(0x00D7)));
    }
    y += headerH + gapS;

    // ---- the tile: the picture, and nothing else on top of it -------------
    const QRect zoomRect(x, y, tile, tile);
    {
        const int imgW = in.echPixmap->width();
        const int imgH = in.echPixmap->height();

        const double srcW = double(tile) / double(qMax(1, in.zoomFactor));
        QRectF src(in.centerWorld.x() - srcW / 2.0,
                   in.centerWorld.y() - srcW / 2.0,
                   srcW, srcW);

        if (src.left()   < 0)      src.moveLeft(0);
        if (src.top()    < 0)      src.moveTop(0);
        if (src.right()  > imgW-1) src.moveRight(imgW-1);
        if (src.bottom() > imgH-1) src.moveBottom(imgH-1);

        QPixmap tilePix = in.echPixmap->copy(src.toRect());
        if (in.rotateForView)   tilePix = tilePix.transformed(QTransform().rotate(-90));
        if (in.flipForLeftHand) tilePix = tilePix.transformed(QTransform().scale(1, -1));

        p->drawPixmap(zoomRect, tilePix);

        if (in.captureTile) {
            out.zoomTile    = tilePix;
            out.zoomSrcRect = src.toRect();
        }

        p->setBrush(Qt::NoBrush);
        p->setPen(QPen(kTileEdge, 1));
        p->drawRect(zoomRect.adjusted(0, 0, -1, -1));

        // The crosshair stays white and stays short. It marks the point; it is not a
        // ruler, and a full-width cross in a magnified tile hides the return it is
        // pointing at.
        const int cx  = zoomRect.center().x();
        const int cy  = zoomRect.center().y();
        const int arm = px(15);

        QPen crossPen(QColor(255, 255, 255));
        crossPen.setWidthF(qMax(2.0, double(px(3))));
        p->setPen(crossPen);
        p->drawLine(cx - arm, cy, cx + arm, cy);
        p->drawLine(cx, cy - arm, cx, cy + arm);
    }
    y += tile + gapM;

    // ---- the two values, labelled, out of the picture ---------------------
    //
    // Rows rather than a left/right pair, so the numbers align on their right edge and
    // can be compared at a glance. The second row's LABEL is what changes on a dual side
    // scan - the old panel changed the value's prefix to a bare `<` or `>` instead, which
    // is the abbreviation Olav asked to be rid of.
    {
        const double crossAbs = std::isfinite(in.crossMeters) ? std::abs(in.crossMeters) : NAN;
        const double depthAbs = std::isfinite(in.depthMeters) ? std::abs(in.depthMeters) : NAN;

        QString secondLabel = kLabelCursor();
        double  secondValue = crossAbs;

        if (in.isDualSideScan && std::isfinite(crossAbs)
            && std::isfinite(depthAbs) && crossAbs > depthAbs + 1e-6) {
            secondLabel = (in.dirSide < 0) ? kLabelLatLeft() : kLabelLatRight();
            secondValue = qMax(0.0, crossAbs - depthAbs);
        }

        const QString rows[2][2] = {
            { kLabelBottom(), formatDistance(depthAbs,    in.isMetric) },
            { secondLabel,    formatDistance(secondValue, in.isMetric) }
        };

        for (int i = 0; i < 2; ++i) {
            const QRect r(x, y + i * rowH, contentW, rowH);

            p->setFont(fLabel);
            p->setPen(kTextDim);
            p->drawText(r, Qt::AlignVCenter | Qt::AlignLeft, rows[i][0]);

            p->setFont(fValue);
            p->setPen(kText);
            p->drawText(r, Qt::AlignVCenter | Qt::AlignRight, rows[i][1]);
        }
    }
    y += 2 * rowH + gapM;

    // ---- the sentence, only when there is no waypoint to be had -----------
    if (!canAdd) {
        const QRect noteRect(x, y, contentW, noteH - gapM);
        p->setFont(fNote);
        p->setPen(kTextDim);
        p->drawText(noteRect, Qt::TextWordWrap | Qt::AlignTop | Qt::AlignLeft, noteText);
        y += noteH;
    }

    // ---- the buttons ------------------------------------------------------
    //
    // Ghost and filled, and the ghost is the NARROWER of the two. With no position the
    // Add button is ABSENT rather than greyed - the same rule the rail follows for a
    // choice the hardware does not offer - and Dismiss takes the whole width, because a
    // row with one button in half of it reads as a button that failed to load.
    {
        const int corner = px(6);
        const int gap    = px(12);

        QRect abortRect;
        QRect addRect;

        if (canAdd) {
            const int dismissW = int(contentW * 0.38);
            abortRect = QRect(x, y, dismissW, btnH);
            addRect   = QRect(x + dismissW + gap, y, contentW - dismissW - gap, btnH);
        } else {
            abortRect = QRect(x, y, contentW, btnH);
        }

        // Dismiss - ghost.
        p->setBrush(Qt::NoBrush);
        p->setPen(QPen(kAccentDim, qMax(1, px(1))));
        p->drawRoundedRect(abortRect, corner, corner);
        p->setFont(fLabel);
        p->setPen(kText);
        p->drawText(abortRect, Qt::AlignCenter, kBtnDismiss());

        // Add waypoint - filled, with the pin, and the pin tinted to the ink colour
        // because the file is drawn near-white and amber is the one ground it fails on.
        if (canAdd) {
            p->setPen(Qt::NoPen);
            p->setBrush(kAccent);
            p->drawRoundedRect(addRect, corner, corner);

            const int iconPx = ui ? ui->iconTouchSmall() : px(24);
            QFontMetrics fm(fLabel);
            const int textW  = fm.horizontalAdvance(kBtnAdd());
            const int blockW = iconPx + px(8) + textW;
            const int blockX = addRect.center().x() - blockW / 2;

            drawSvgTinted(p, QStringLiteral("./icons/ui/pulse_zoom_add_marker.svg"),
                          QRect(blockX, addRect.top(), iconPx, addRect.height()),
                          iconPx, kInk);

            p->setFont(fLabel);
            p->setPen(kInk);
            p->drawText(QRect(blockX + iconPx + px(8), addRect.top(), textW, addRect.height()),
                        Qt::AlignVCenter | Qt::AlignLeft, kBtnAdd());
        }

        out.abortRect = abortRect;
        out.addRect   = addRect;
    }

    // Everything above the button row is dead to the touch: a tap that lands on the
    // panel but not on a button must not re-aim through it.
    out.panelRect   = panelRect;
    out.tapDeadRect = QRect(panelRect.left(), panelRect.top(),
                            panelRect.width(), y - panelRect.top());

    p->restore();
    return out;
}
