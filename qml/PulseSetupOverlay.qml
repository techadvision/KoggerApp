import QtQuick 2.15
import QtQuick.Layouts 1.15

// THE SETUP OVERLAY - Stage 4, step 6 part 1.
//
// Replaces configurationInProgressIndicator, which was a block inside PulseAppClassic.
// PulseApp is instantiated inside Plot2D, so that block existed ONCE PER PANE and a split
// screen drew two of them with no gate at all - the same defect the swap prompt carried,
// minus the `indx === 1` that at least hid it. This is a PulseApp*-level component
// instantiated once in main.qml above both panes, like PulseConnectionScreen, so it cannot
// draw twice and it survives into PulseAppV2 without being built again.
//
// WHAT IT SAYS, AND WHY IT COSTS NOTHING. The handshake already knows, at every moment,
// exactly which parameter has not come back - the log has printed it all along:
//
//   DEV_PARAM checking transSetup
//   DEV_PARAM transFreq OK as 710
//   DEV_PARAM onTransChanged is OK, let's move on
//
// and the UI threw all of it away in favour of one string. Nothing new is computed here:
// four category flags and sixteen acknowledgements that four other places already read.
//
// IT GETS TALKATIVE ONLY WHEN IT STRUGGLES. A normal setup is over in a second or two and
// says one line. A slow one grows the list. A stalled one names the group that is not
// answering. That is the same principle as measuring progress instead of elapsed time:
// the interface says more exactly when there is more worth saying.
//
// PART 2 adds the question - "Start anyway", the escape hatch, and the standing marker.
// This part only reports.
Item {
    id: setupOverlay

    anchors.fill: parent
    // Below PulseConnectionScreen (9000): when the app is asking which transducer, there
    // is nothing to configure and the chooser owns the screen.
    z: 8000

    // main.qml passes mainview.s and the Android insets, exactly as for the chooser.
    property real uiScale:   1.0
    property real safeTop:    0
    property real safeBottom: 0
    property real safeLeft:   0
    property real safeRight:  0

    // The old block bound `60 + insetTop()` and `_isAndroid ? 80 : 60`, both declared on
    // quickChangeObjects - a SIBLING of that block, not its root - so neither could ever
    // resolve. Pre-existing, reported, and fixed here by construction: the insets arrive
    // as properties.
    readonly property bool onAndroid: Qt.platform.os === "android"
    readonly property real topInset:
        Math.max(safeTop, onAndroid ? Math.round(34 * uiScale) : 0)

    // ---- When it is up ------------------------------------------------------

    // A file view is not a setup, and a demo has no device to configure.
    readonly property bool configuring:
        pulseRuntimeSettings
            ? (!pulseRuntimeSettings.devConfigured
               && pulseRuntimeSettings.isAnswering
               && !pulseRuntimeSettings.isInDemoMode
               && !pulseRuntimeSettings.isOpeningKlfFile
               && !pulseRuntimeSettings.wasKlfFileOpened)
            : false

    visible: configuring

    readonly property string deviceName:
        pulseRuntimeSettings
            ? pulseRuntimeSettings.modelDisplayName(pulseRuntimeSettings.userManualSetName)
            : ""

    // ---- What it knows ------------------------------------------------------
    //
    // THE FOUR GROUPS ARE THE FOUR CATEGORY FLAGS, which is what makes the names cheap:
    // the handshake already raises exactly these and nothing else has to be tracked.
    //
    //   Depth range        onDistSetupChanged     distMax, dead zone, confidence
    //   Image quality      onChartSetupChanged    samples, resolution, offset
    //   Cone / Beam        onTransChanged         frequency, pulse, boost
    //   Echogram settings  onDatasetChanged       period, chart, depth, temperature
    //
    // dspSetup and soundSpeed are acknowledged by default and carry nothing a user would
    // recognise, so they are not shown.
    //
    // "Cone" is right for a device that offers a cone choice and wrong for one that does
    // not - a blue has no cone. Read from offersConeChoice here, which is true today; the
    // proper home for the word is the profile record, exactly where the cards went.
    readonly property string beamGroupName:
        (pulseRuntimeSettings && pulseRuntimeSettings.offersConeChoice) ? "Cone" : "Beam"

    readonly property var groups: pulseRuntimeSettings ? [
        { "name": "Depth range",        "done": pulseRuntimeSettings.onDistSetupChanged  },
        { "name": "Image quality",      "done": pulseRuntimeSettings.onChartSetupChanged },
        { "name": beamGroupName,        "done": pulseRuntimeSettings.onTransChanged      },
        { "name": "Echogram settings",  "done": pulseRuntimeSettings.onDatasetChanged    }
    ] : []

    // The one being waited on: the first that has not come back.
    readonly property int currentIndex: {
        for (var i = 0; i < groups.length; i++)
            if (!groups[i].done)
                return i
        return -1
    }
    readonly property string currentName:
        (currentIndex >= 0 && currentIndex < groups.length) ? groups[currentIndex].name : ""

    // PROGRESS, NOT ELAPSED TIME. Sixteen acknowledgements, and every one that comes back
    // is movement. The old ten-second timer measured the clock, which punishes a weak link
    // making steady progress - and a weak link is the case the halt-the-echogram rule
    // exists to protect in the first place.
    readonly property int acknowledged: !pulseRuntimeSettings ? 0 :
          (pulseRuntimeSettings.distMax_ok          ? 1 : 0)
        + (pulseRuntimeSettings.distDeadZone_ok     ? 1 : 0)
        + (pulseRuntimeSettings.distConfidence_ok   ? 1 : 0)
        + (pulseRuntimeSettings.chartSamples_ok     ? 1 : 0)
        + (pulseRuntimeSettings.chartResolution_ok  ? 1 : 0)
        + (pulseRuntimeSettings.chartOffset_ok      ? 1 : 0)
        + (pulseRuntimeSettings.transFreq_ok        ? 1 : 0)
        + (pulseRuntimeSettings.transPulse_ok       ? 1 : 0)
        + (pulseRuntimeSettings.transBoost_ok       ? 1 : 0)
        + (pulseRuntimeSettings.ch1Period_ok        ? 1 : 0)
        + (pulseRuntimeSettings.datasetDist_ok      ? 1 : 0)
        + (pulseRuntimeSettings.datasetSDDBT_ok     ? 1 : 0)
        + (pulseRuntimeSettings.datasetEuler_ok     ? 1 : 0)
        + (pulseRuntimeSettings.datasetTemp_ok      ? 1 : 0)
        + (pulseRuntimeSettings.datasetTimestamp_ok ? 1 : 0)
        + (pulseRuntimeSettings.datasetChart_ok     ? 1 : 0)

    // PLACEHOLDERS, and deliberately one edit each: the intervals are Olav's to set once
    // he has watched it on a weak link.
    property int talkativeAfterMs: 2500
    property int stalledAfterMs:   6000

    // Latches, each with one raiser and one lowerer.
    property bool talkative: false
    property bool stalled:   false

    onConfiguringChanged: {
        talkative = false
        stalled   = false
        if (configuring) {
            console.log("SETUP: configuring", deviceName)
            talkativeTimer.restart()
            stallTimer.restart()
        } else {
            talkativeTimer.stop()
            stallTimer.stop()
        }
    }

    onAcknowledgedChanged: {
        // Something came back, so nothing is stuck. This is the only thing that lowers
        // `stalled`, and it is the whole definition of progress.
        if (!configuring)
            return
        stalled = false
        stallTimer.restart()
    }

    Timer {
        id: talkativeTimer
        interval: setupOverlay.talkativeAfterMs
        repeat: false
        onTriggered: {
            setupOverlay.talkative = true
            console.log("SETUP: taking a while -", setupOverlay.acknowledged,
                        "settings acknowledged, waiting on", setupOverlay.currentName)
        }
    }

    Timer {
        id: stallTimer
        interval: setupOverlay.stalledAfterMs
        repeat: false
        onTriggered: {
            setupOverlay.talkative = true
            setupOverlay.stalled   = true
            console.log("SETUP: nothing acknowledged for", setupOverlay.stalledAfterMs,
                        "ms - waiting on", setupOverlay.currentName)
        }
    }

    // ---- Surface ------------------------------------------------------------
    //
    // A card, not a scrim: the echogram behind it is paused, not replaced, and the user
    // should be able to see what they had.
    Rectangle {
        id: card

        x: setupOverlay.safeLeft + Math.round(28 * setupOverlay.uiScale)
        y: setupOverlay.topInset + Math.round(28 * setupOverlay.uiScale)
        width:  body.width  + Math.round(40 * setupOverlay.uiScale)
        height: body.height + Math.round(36 * setupOverlay.uiScale)

        radius: Math.round(14 * setupOverlay.uiScale)
        color: "#f2121519"
        border.width: 1
        border.color: setupOverlay.stalled ? "#4a4223" : "#232830"

        Column {
            id: body
            x: Math.round(20 * setupOverlay.uiScale)
            y: Math.round(18 * setupOverlay.uiScale)
            spacing: Math.round(12 * setupOverlay.uiScale)

            Row {
                spacing: Math.round(12 * setupOverlay.uiScale)

                Rectangle {
                    width:  Math.round(10 * setupOverlay.uiScale)
                    height: width
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: setupOverlay.stalled ? "#ffcc00" : "#3d7fd0"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Setting up " + setupOverlay.deviceName
                    color: "#f2f4f7"
                    font.pixelSize: Math.round(18 * setupOverlay.uiScale)
                    font.bold: true
                }
            }

            // THE GROUP LIST, only once it is slow enough to be worth reading.
            Column {
                visible: setupOverlay.talkative
                spacing: Math.round(8 * setupOverlay.uiScale)

                Repeater {
                    model: setupOverlay.groups

                    delegate: Row {
                        readonly property bool isDone:    modelData.done
                        readonly property bool isCurrent: index === setupOverlay.currentIndex
                        readonly property bool isStuck:   isCurrent && setupOverlay.stalled

                        spacing: Math.round(10 * setupOverlay.uiScale)

                        Item {
                            width:  Math.round(17 * setupOverlay.uiScale)
                            height: width
                            anchors.verticalCenter: parent.verticalCenter

                            // Acknowledged.
                            Canvas {
                                anchors.fill: parent
                                visible: isDone
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.strokeStyle = "#3ec46d"
                                    ctx.lineWidth = Math.max(2, width * 0.15)
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.beginPath()
                                    ctx.moveTo(width * 0.20, height * 0.52)
                                    ctx.lineTo(width * 0.42, height * 0.74)
                                    ctx.lineTo(width * 0.80, height * 0.28)
                                    ctx.stroke()
                                }
                                onVisibleChanged: requestPaint()
                            }

                            // Waiting, or waiting far too long.
                            Rectangle {
                                anchors.fill: parent
                                visible: !isDone
                                radius: width / 2
                                color: "transparent"
                                border.width: Math.max(2, Math.round(2 * setupOverlay.uiScale))
                                border.color: isStuck ? "#ffcc00"
                                            : isCurrent ? "#3d7fd0" : "#5a626d"
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: isStuck ? "#f2f4f7"
                                 : isDone ? "#dfe4ea"
                                 : isCurrent ? "#dfe4ea" : "#78818d"
                            font.pixelSize: Math.round(15 * setupOverlay.uiScale)
                        }
                    }
                }
            }

            // The one line that explains itself, and changes as the news changes.
            Text {
                width: Math.round(300 * setupOverlay.uiScale)
                wrapMode: Text.WordWrap
                topPadding: setupOverlay.talkative ? Math.round(4 * setupOverlay.uiScale) : 0
                text: setupOverlay.stalled
                      ? setupOverlay.deviceName + " is not answering about the "
                        + setupOverlay.currentName.toLowerCase() + "."
                      : setupOverlay.talkative
                        ? "This is taking longer than usual. A weak wireless link can do that."
                        : "The picture is paused for a moment so the settings get through."
                color: "#8d96a2"
                font.pixelSize: Math.round(14 * setupOverlay.uiScale)
            }
        }
    }
}
