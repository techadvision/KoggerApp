import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window

// THE NEW PULSE UI - the edge-rail design decided on 11 Sept 2026.
//
// Stage 4 (a): the CONTROL SURFACE. The rail with its tier-1 buttons, the source button
// at its foot, and the way back to the classic UI. The settings panel is stage 4 (b) and
// is the larger half; until it exists every tier-1 button logs and does nothing.
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

    property real maxDepthValue: plot && plot.quickChangeMaxRangeValue ? plot.quickChangeMaxRangeValue : 0

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

    // ---- ONE RAIL, and why it is gated --------------------------------------
    //
    // PulseApp is instantiated INSIDE Plot2D, so this file is built once per pane and a
    // split screen would draw two rails - the same defect the swap prompt carried and the
    // connection screen and the setup overlay were moved to main.qml to escape.
    //
    // The rail's final home is beside the panes in main.qml, and that one move buys two
    // things at once: a single rail above both panes, and a rail that COMPRESSES the
    // echogram instead of overlaying it (the canvas's "costs 76px of width" - which
    // cannot happen from in here, because this Item fills Plot2D and the WaterFall renders
    // underneath it). That move is blocked on the per-pane state object that blocks split
    // screen, and it touches main.qml's visualisation layout - so it waits, and until then
    // main.qml is untouched, which is what keeps the next upstream merge readable.
    //
    // Pane one only. `indx` is 1 for waterViewFirst and 2 for waterViewSecond.
    readonly property bool ownsTheRail: !plot || plot.indx !== 2

    PulseRail {
        id: rail

        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom

        visible: pulseAppV2.ownsTheRail
        enabled: pulseAppV2.ownsTheRail

        uiScale:    pulseAppV2.s
        safeTop:    pulseAppV2.insetTop()
        safeBottom: pulseAppV2.insetBottom()
        safeLeft:   pulseAppV2.insetLeft()

        displayIs2D: pulseAppV2.displayIs2D

        // ONE BINDING on the persisted value; the handler below writes the SETTING and
        // never this property. Assigning `collapsed` would destroy the binding, and the
        // rail would stop following the stored state for the rest of the run.
        collapsed: pulseSettings.v2RailCollapsed
        onCollapseToggled: {
            pulseSettings.v2RailCollapsed = !pulseSettings.v2RailCollapsed
            console.log("RAIL:", pulseSettings.v2RailCollapsed ? "collapsed" : "shown")
        }

        // COMMITTED, not display: a chooser offers hardware choices. These are the same
        // two properties the classic choosers show and hide on.
        offersView: pulseRuntimeSettings ? pulseRuntimeSettings.offersViewChoice : false
        offersCone: pulseRuntimeSettings ? pulseRuntimeSettings.offersConeChoice : false

        recording:     pulseRuntimeSettings ? pulseRuntimeSettings.isRecordingKlf : false
        presentingLog: pulseRuntimeSettings ? pulseRuntimeSettings.isPresentingLog : false

        // THE OVERRIDE, and the only writer of it.
        //
        // It goes through pulseRuntimeSettings rather than through the screen itself for
        // the reason enterDemoMode() lives there too: PulseConnectionScreen is instantiated
        // in main.qml and QML IDS DO NOT CROSS FILES, so this rail cannot reach it. A root
        // context property can be reached from everywhere, which is what awaitingUserChoice
        // and swapDeviceNow already are.
        //
        // The screen holds
        //     visible: chooserAsking || userAsked
        // as ONE binding over two sources, with connectionScreenRequested as the override
        // and nothing anywhere assigning `visible`. The two ways out of that screen -
        // commitCard() and keepCurrent() - clear the flag again, and both commit a model,
        // so the screen still cannot strand itself.
        onSourceActivated: {
            console.log("RAIL: source - opening the connection screen")
            if (pulseRuntimeSettings)
                pulseRuntimeSettings.connectionScreenRequested = true
        }

        // Scaffolding until 4 (b). The switch that turns v2 on lives in the expert settings
        // inside the CLASSIC UI, and uiVariant is persisted across restarts, so this is the
        // only way back while the new settings panel does not exist.
        onBackToClassic: {
            console.log("PULSE UI: v2 - returning to classic")
            pulseSettings.uiVariant = "classic"
        }

        // Stage 4 (b) owns every one of these. They log rather than do nothing silently,
        // so one device run says whether every target is reachable one-thumb-from-shore.
        onButtonActivated: function (id) {
            if (id === "settings")
                console.log("RAIL:", id, "- the settings panel arrives in stage 4 (b)")
            else
                console.log("RAIL:", id, "- its panel arrives in stage 4 (b)")
        }
    }

    Component.onCompleted: console.log("PULSE UI: v2 rail shown on pane",
                                       plot ? plot.indx : "?",
                                       "| plot is", plot ? "set" : "NULL",
                                       "| display is", displayIs2D ? "2D" : "side scan")
}
