import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window

// THE NEW PULSE UI - the edge-rail design decided on 11 Sept 2026.
//
// Stage 4 (a) built the CONTROL SURFACE - the rail, its tier-1 buttons, the source button
// at its foot - and then moved it OUT of this file, for the reason set out at the bottom.
// What is left here is the variant contract and the platform helpers the overlay pieces
// will need; see "WHERE THE CONTROL SURFACE WENT" below.
//
// It still satisfies the variant contract declared at the top of PulseApp.qml.
// applyFiltering() and armOldDataWarning() are still deliberate no-ops: while this
// variant is showing, the water-body filter and the old-data warning are driven by
// nothing, and that is expected rather than a fault. Both arrive with the controls that
// own them in 4 (b).
Item {
    id: pulseAppV2

    // Set by PulseApp.qml at construction - see PulseAppClassic.qml.
    property var plot:  parent
    property var pinch: null

    anchors.fill: parent

    // ---- Variant contract (see PulseApp.qml) --------------------------------

    // THE PINCH. Plot2D writes this through PulseApp.setMaxDepth() when the picture is
    // pinched, and it was a BINDING on plot.quickChangeMaxRangeValue - so the first pinch
    // destroyed the binding and nothing stored the result. A pinch in v2 changed the range
    // and forgot it.
    //
    // A plain property with one handler instead, routing to the same writer the panel's
    // slider uses. Which of the three keys it lands in is the runtime object's business,
    // and it is the same answer either way in.
    property real maxDepthValue: 0

    onMaxDepthValueChanged: {
        if (maxDepthValue > 0 && pulseRuntimeSettings)
            pulseRuntimeSettings.storeDisplayMaxRange(Math.round(maxDepthValue))
    }

    function applyFiltering(value) {
        // no-op until stage 4 (b) builds the filter control
    }

    function armOldDataWarning() {
        // no-op until stage 4 (b) builds the readout
    }

    // ---- Platform helpers, ON THE ROOT --------------------------------------
    //
    // Deliberately here rather than on a child. In PulseAppClassic these live on
    // `quickChangeObjects`, and four alert blocks bind `insetTop()` and `_isAndroid`
    // from OUTSIDE it - quickChangeObjects is their SIBLING, not their root, so those
    // bindings never resolved and never could. Declaring them on the root is the fix by
    // construction, and it is why nothing in this file needs the insets passed in.
    readonly property bool _isAndroid: Qt.platform.os === "android"
    function _hasInsets()  { return _isAndroid && (typeof Insets !== "undefined"); }
    function insetTop()    { return _hasInsets() && Insets.dexEnabled ? Insets.top : 0; }
    function insetBottom() { return _hasInsets() ? Insets.bottom : 0; }
    function insetLeft()   { return _hasInsets() ? Insets.left   : 0; }
    function insetRight()  { return _hasInsets() ? Insets.right  : 0; }

    readonly property real shortSide: Math.min(Screen.width, Screen.height)
    readonly property real s: Math.max(1.0, shortSide / 1100)

    // ---- Rule 1: which model answers which question -------------------------
    //
    // The ONE display-side read in this file. Anything the user judges by LOOKING at it
    // comes from here; is2DTransducer answers "what is connected" and nothing that draws
    // may ask it.
    readonly property bool displayIs2D:
        pulseRuntimeSettings ? pulseRuntimeSettings.displayIs2DTransducer : true

    // ---- WHERE THE CONTROL SURFACE WENT ------------------------------------
    //
    // The rail is NOT here. It is one PulseRail in main.qml, inside plotsContainer and
    // beside the pane GridLayout, and this file no longer draws anything.
    //
    // It had to move for a reason worth stating once, because the settings panel in
    // stage 4 (b) meets it too: qPlot2D paints the echogram across its ENTIRE item, and
    // PulseApp is that item's child. Nothing built in here can take width from the
    // picture - it can only cover it. Everything the edge-rail direction does by
    // compressing the echogram rather than covering it therefore has to be the panes'
    // SIBLING. The same move also retires the per-pane gate this file carried: one rail
    // above both panes, the way PulseConnectionScreen and PulseSetupOverlay already are.
    //
    // WHAT STILL LANDS HERE is everything that genuinely belongs ON the picture and takes
    // no width from it: the depth and temperature readout, the demo / log / recording
    // indicator stack, and the paused crosshair and loupe. That is why displayIs2D and the
    // inset helpers above stay - the indicator stack is the next commit, and it chooses its
    // corner by the flow rule, top right on a 2D picture and bottom right on a side scan.

    Component.onCompleted: console.log("PULSE UI: v2 on pane", plot ? plot.indx : "?",
                                       "| plot is", plot ? "set" : "NULL",
                                       "| display is", displayIs2D ? "2D" : "side scan",
                                       "| the rail is in main.qml")
}
