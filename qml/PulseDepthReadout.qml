import QtQuick 2.15
import QtQuick.Window

// DEPTH AND TEMPERATURE ON THE V2 ECHOGRAM.
//
// The left edge says what the WATER is. The right edge - PulsePillColumn - says what the
// PICTURE is. Both pick their corner by the flow and by the same rule, so on a 2D picture
// this sits top left with the pills top right, and on a side scan both drop to the foot.
// That symmetry is the point: one design, two edges, nothing to learn twice.
//
// THE READOUT FAMILY, not the pill family. Large white numerals outlined in black and no
// container at all - a box here would hide the echogram it is sitting on, and this is the
// one overlay a user reads continuously rather than glances at. The pills earn their
// capsule by being transient; this does not.
//
// NO ANCHORS ON THE MOVING PART. Step 6 cost a round trip to an anchor that was set for
// one orientation and could not be cleared for the other. The strongest form of "an anchor
// that is only ever set cannot get stuck" is not to use one: the block's position is x and
// y, and the flow changes one number. The anchors that do appear are baselines between
// siblings in the same line, set once and never conditional.
//
// NO MOUSEAREA. Classic puts a catch-all absorber over a 350x200 patch of picture, which
// eats the pinch there, and while paused would eat the aim as well. Units are a settings
// question, not a secret tap on the echogram.
//
// WHERE THE NUMBER COMES FROM. pulseRuntimeSettings.depthMeters, written by
// PulseDepthEngine.qml and nowhere else - bottom track first, the rangefinder when bottom
// track is not initiated, never a NaN. This file does not choose a source; it formats one.
Item {
    id: readout

    // ---- What the host hands in ---------------------------------------------

    property real uiScale:    1.0
    property real safeTop:    0
    property real safeBottom: 0
    property real safeLeft:   0

    // RULE 1: what the PICTURE is, never what is connected.
    property bool displayIs2D: true

    // ---- Type scale, the classic ratios kept --------------------------------

    readonly property int fDepthInt:  Math.round(104 * uiScale)
    readonly property int fDepthDec:  Math.round(104 * uiScale * 0.75)
    readonly property int fDepthUnit: Math.round(104 * uiScale * 0.33)
    readonly property int fTempInt:   Math.round(104 * uiScale * 0.75)
    readonly property int fTempDec:   Math.round(104 * uiScale * 0.50)
    readonly property int fTempUnit:  Math.round(104 * uiScale * 0.33)

    // The same floor and the same gaps the pill column uses, so the two edges line up:
    // insetTop() answers 0 unless DeX is on, because the app draws full-bleed under the
    // status bar - right for the picture, wrong for something a user has to read.
    readonly property bool onAndroid: Qt.platform.os === "android"
    readonly property real topInset:  Math.max(safeTop, onAndroid ? Math.round(34 * uiScale) : 0)
    readonly property real edgeGap:   Math.round(14 * uiScale)
    readonly property real sideGap:   Math.round(16 * uiScale)
    readonly property real lineGap:   Math.round(6  * uiScale)
    readonly property real unitGap:   Math.round(8  * uiScale)

    // ---- The values ---------------------------------------------------------

    readonly property bool metricDepth: pulseSettings ? pulseSettings.useMetricDepth : true
    readonly property bool metricTemp:  pulseSettings ? pulseSettings.useMetricTemperature : true

    // THREE CLAUSES, AND THE THIRD IS NOT A LEFTOVER.
    //
    // useTemperature is the profile key: does this transducer have the sensor. Then the
    // user's own setting: do they want it on screen. Then pulseBetaName === "..." - no
    // beta name - which looks like debug scaffolding and is not. Beta devices of the red
    // ("basic 2D") can have the temperature hidden, and Olav puts as many as twenty
    // customers on that hardware. Dropping the clause would put a number on their screen
    // that nothing behind it can measure.
    //
    // It is blunt - it answers "beta" where the real question is "this particular beta
    // build has no temperature" - and a profile key would say it properly. That is a
    // change to the profile records, not to a readout, and it is not made here.
    readonly property bool showTemp:
        (pulseRuntimeSettings ? pulseRuntimeSettings.useTemperature : false)
        && (pulseRuntimeSettings ? pulseRuntimeSettings.pulseBetaName === "..." : false)
        && (pulseSettings ? pulseSettings.showTemperatureInUi : false)

    // ONE WRITER EACH, NO BINDING ON EITHER. The engine's key changes at the ping rate;
    // reading it straight into the text would make the last digit unreadable. Classic damps
    // it at 250 ms and 1 s and that is the behaviour being kept, not a new idea.
    property string depthShown: "-.-"
    property string tempShown:  "-.-"

    function _formatDepth() {
        var m = pulseRuntimeSettings ? pulseRuntimeSettings.depthMeters : 0
        if (!Number.isFinite(m))
            return depthShown
        return (metricDepth ? m : m * 3.28084).toFixed(1)
    }

    function _formatTemp() {
        if (!dataset || !Number.isFinite(dataset.temp))
            return tempShown
        var c = dataset.temp
        return (metricTemp ? c : c * (9 / 5) + 32).toFixed(1)
    }

    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: readout.depthShown = readout._formatDepth()
    }

    Timer {
        interval: 1000
        running: readout.showTemp
        repeat: true
        onTriggered: readout.tempShown = readout._formatTemp()
    }

    // ---- Where the block sits ------------------------------------------------
    //
    // The whole flow rule, in one number. Top of the picture when it flows sideways, foot
    // of it when it flows downward - the same answer the pill column gives on the other
    // edge.
    readonly property real blockHeight:
        depthLine.height + (showTemp ? lineGap + tempLine.height : 0)

    readonly property real blockY:
        displayIs2D ? (topInset + edgeGap)
                    : (height - blockHeight - safeBottom - edgeGap)

    readonly property real blockX: safeLeft + sideGap

    // ---- The depth line ------------------------------------------------------

    Item {
        id: depthLine

        x: readout.blockX
        y: readout.blockY
        width:  depthUnit.x + depthUnit.width
        height: depthWhole.height

        Text {
            id: depthWhole
            x: 0
            y: 0
            text: readout.depthShown.split(".")[0] + "."
            color: "white"
            style: Text.Outline
            styleColor: "black"
            renderType: Text.NativeRendering
            font.bold: true
            font.pixelSize: readout.fDepthInt
        }

        Text {
            id: depthFrac
            x: depthWhole.width
            anchors.baseline: depthWhole.baseline
            text: {
                var parts = readout.depthShown.split(".")
                return parts[1] ? parts[1] : ""
            }
            color: "white"
            style: Text.Outline
            styleColor: "black"
            renderType: Text.NativeRendering
            font.bold: true
            font.pixelSize: readout.fDepthDec
        }

        Text {
            id: depthUnit
            x: depthFrac.x + depthFrac.width + readout.unitGap
            anchors.baseline: depthWhole.baseline
            text: readout.metricDepth ? "m" : "ft"
            color: "white"
            style: Text.Outline
            styleColor: "black"
            renderType: Text.NativeRendering
            font.pixelSize: readout.fDepthUnit
        }
    }

    // ---- The temperature line ------------------------------------------------
    //
    // Secondary by weight and by colour - the pill column's text colour rather than pure
    // white - so the eye takes the depth first without the temperature having to be small.
    Item {
        id: tempLine

        visible: readout.showTemp
        x: readout.blockX
        y: depthLine.y + depthLine.height + readout.lineGap
        width:  tempUnit.x + tempUnit.width
        height: tempWhole.height

        Text {
            id: tempWhole
            x: 0
            y: 0
            text: readout.tempShown.split(".")[0] + "."
            color: "#eaf1f8"
            style: Text.Outline
            styleColor: "black"
            renderType: Text.NativeRendering
            font.bold: true
            font.pixelSize: readout.fTempInt
        }

        Text {
            id: tempFrac
            x: tempWhole.width
            anchors.baseline: tempWhole.baseline
            text: {
                var parts = readout.tempShown.split(".")
                return parts[1] ? parts[1] : ""
            }
            color: "#eaf1f8"
            style: Text.Outline
            styleColor: "black"
            renderType: Text.NativeRendering
            font.bold: true
            font.pixelSize: readout.fTempDec
        }

        Text {
            id: tempUnit
            x: tempFrac.x + tempFrac.width + readout.unitGap
            anchors.baseline: tempWhole.baseline
            text: readout.metricTemp ? "°C" : "°F"
            color: "#eaf1f8"
            style: Text.Outline
            styleColor: "black"
            renderType: Text.NativeRendering
            font.pixelSize: readout.fTempUnit
        }
    }
}
