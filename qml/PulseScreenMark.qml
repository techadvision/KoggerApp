import QtQuick 2.15

// A SMALL PICTURE OF THE WHOLE SCREEN (Stage 4 b, the screen chooser).
//
// The market scan settled the shape before the drawing: Lowrance's quick-split pages,
// Humminbird's combo views and Garmin's combo pages all present the layout and its
// CONTENTS as one picture and one tap, never as "how many panes" followed by "what goes
// in each". So the chooser's glyph is not an icon of a layout - it is a miniature of the
// picture the user will be looking at.
//
// DRAWN, NOT LOADED, and that is the point rather than a convenience. Three new icons for
// the three halves would be three more SVGs that could ship declaring no colour and draw
// black on a black panel, which is how three rail controls went missing on 13 Sept. The
// settings chevron was drawn from two rectangles for the same reason. Here every fill and
// stroke below is a named colour in this file, so tools/pulse-icon-check.js has nothing to
// find and nothing to miss.
//
// A Canvas rather than Rectangles because the mosaic is a trapezoid and the bottom is a
// curve; neither is a rectangle, and rotating one into place would be a worse lie than
// drawing the real shape.
Canvas {
    id: mark

    // WHAT EACH HALF SHOWS: "down", "side", "mosaic". `bottomKind` empty means the top
    // kind fills the whole screen - one property, not a separate `split` flag that could
    // disagree with it.
    property string topKind:    "side"
    property string bottomKind: ""

    readonly property bool split: bottomKind !== ""

    // The panel's own palette. Stated here once so the paint functions never reach for a
    // colour that is not in this file.
    readonly property color cGround:  "#080b0e"
    readonly property color cBody:    "#2c4358"
    readonly property color cLine:    "#7fb2e0"
    readonly property color cMosaic:  "#1d3346"
    readonly property color cMosLine: "#41708f"
    readonly property color cDivider: "#39424c"

    antialiasing: true

    onTopKindChanged:    requestPaint()
    onBottomKindChanged: requestPaint()
    onWidthChanged:      requestPaint()
    onHeightChanged:     requestPaint()

    // ---- The three halves ---------------------------------------------------

    // DOWN SCAN is a water column over a bottom profile, which is what a down scan
    // echogram looks like from across the boat. The curve is drawn twice - once filled to
    // the foot of the pane, once as the return itself - because the bright bottom line is
    // the thing a user recognises, not the fill under it.
    function _bottomPath(ctx, x, y, w, h) {
        var base = y + h * 0.62
        ctx.beginPath()
        ctx.moveTo(x, base)
        ctx.bezierCurveTo(x + w * 0.18, base - h * 0.12,
                          x + w * 0.32, base + h * 0.12,
                          x + w * 0.52, base + h * 0.05)
        ctx.bezierCurveTo(x + w * 0.72, base - h * 0.08,
                          x + w * 0.86, base + h * 0.07,
                          x + w,        base + h * 0.02)
    }

    function _paintDown(ctx, x, y, w, h) {
        _bottomPath(ctx, x, y, w, h)
        ctx.lineTo(x + w, y + h)
        ctx.lineTo(x, y + h)
        ctx.closePath()
        ctx.fillStyle = mark.cBody
        ctx.fill()

        _bottomPath(ctx, x, y, w, h)
        ctx.strokeStyle = mark.cLine
        ctx.lineWidth = Math.max(1, h * 0.055)
        ctx.stroke()
    }

    // SIDE SCAN is the nadir line with returns either side, mirrored and uneven. The
    // unevenness is deliberate: two identical stacks read as a bar chart.
    function _paintSide(ctx, x, y, w, h) {
        var cx = x + w / 2
        var gap = Math.max(1, w * 0.035)
        var rh  = Math.max(1, h * 0.105)

        ctx.fillStyle = mark.cBody
        for (var i = 0; i < 4; ++i) {
            var ry = y + h * (0.13 + i * 0.225)
            var lw = w * (i % 2 === 0 ? 0.40 : 0.33)
            var rw = w * (i % 2 === 0 ? 0.34 : 0.42)
            ctx.fillRect(cx - gap - lw, ry, lw, rh)
            ctx.fillRect(cx + gap,      ry, rw, rh)
        }

        ctx.fillStyle = mark.cLine
        var lwid = Math.max(1, w * 0.028)
        ctx.fillRect(cx - lwid / 2, y, lwid, h)
    }

    // THE MOSAIC IS A MAP, so it is drawn as one: the swath seen from above, widening
    // away from the boat, with the track down the middle. Of the three candidates this is
    // the one that says what the mosaic IS rather than what the sonar does to make it.
    // The track is dashed by hand rather than through setLineDash, which is one less
    // Canvas feature to depend on.
    function _paintMosaic(ctx, x, y, w, h) {
        var top = y + h * 0.08
        var bot = y + h * 0.94

        ctx.beginPath()
        ctx.moveTo(x + w * 0.15, bot)
        ctx.lineTo(x + w * 0.37, top)
        ctx.lineTo(x + w * 0.63, top)
        ctx.lineTo(x + w * 0.85, bot)
        ctx.closePath()
        ctx.fillStyle = mark.cMosaic
        ctx.fill()

        // The tile courses across the swath - what makes it a mosaic and not a cone.
        ctx.strokeStyle = mark.cMosLine
        ctx.lineWidth = Math.max(1, h * 0.03)
        for (var i = 1; i <= 2; ++i) {
            var t  = i / 3
            var yy = bot - (bot - top) * t
            var half = w * (0.35 - 0.22 * t)
            ctx.beginPath()
            ctx.moveTo(x + w * 0.5 - half, yy)
            ctx.lineTo(x + w * 0.5 + half, yy)
            ctx.stroke()
        }

        ctx.fillStyle = mark.cLine
        var twid = Math.max(1, w * 0.028)
        var seg  = Math.max(2, h * 0.09)
        for (var ty = top; ty < bot; ty += seg * 1.8)
            ctx.fillRect(x + w * 0.5 - twid / 2, ty, twid, Math.min(seg, bot - ty))
    }

    function _paintKind(ctx, kind, x, y, w, h) {
        if (kind === "down")        _paintDown(ctx, x, y, w, h)
        else if (kind === "side")   _paintSide(ctx, x, y, w, h)
        else if (kind === "mosaic") _paintMosaic(ctx, x, y, w, h)
        // Anything else draws the bare ground. A kind this file does not know is a profile
        // edit that went wrong, and an empty pane says so better than a wrong picture.
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()

        ctx.fillStyle = mark.cGround
        ctx.fillRect(0, 0, width, height)

        if (!split) {
            _paintKind(ctx, topKind, 0, 0, width, height)
            return
        }

        // SIDE SCAN ON TOP IN EVERY SPLIT - Olav, 14 Sept - and in landscape too, so the
        // divider is horizontal here whatever the screen is doing. The half that is named
        // first is the half that is drawn first, and there is no orientation to ask about.
        var dh = Math.max(1, Math.round(height * 0.035))
        var hh = (height - dh) / 2

        _paintKind(ctx, topKind, 0, 0, width, hh)
        _paintKind(ctx, bottomKind, 0, hh + dh, width, hh)

        ctx.fillStyle = mark.cDivider
        ctx.fillRect(0, hh, width, dh)
    }
}
