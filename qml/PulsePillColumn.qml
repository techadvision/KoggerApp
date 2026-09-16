import QtQuick 2.15

// THE INDICATOR PILLS (Stage 4 a) - what the echogram on screen actually IS, and the way
// out of it.
//
// ALWAYS AT THE FOOT, RIGHT. This column used to switch corners with the flow - foot for
// a side scan, top for a 2D picture - and that rule NEVER ONCE RAN. It was written as
//
//     anchors.top:    displayIs2D ? parent.top : undefined
//     anchors.bottom: displayIs2D ? undefined  : parent.bottom
//
// and an anchor binding that evaluates to undefined does NOT clear an anchor that has
// already been set: undefined is not a value an anchor line accepts, so the old one
// silently stays. displayIs2D defaults to true, so parent.top was established at creation
// - before pulseRuntimeSettings resolved - and nothing could ever take it off again. The
// pills have sat top right on every picture since the day this file was written.
//
// Olav, 16 Sept 2026, on a blue: "It is top right. And if I have a side scan it overlaps
// the right part of the tick ruler on the top." The side scan tick ruler is a band across
// the TOP of the pane (plot2D_grid.cpp:210-219), so that corner was never available.
//
// THE RULE IS NOW ONE CORNER, NOT A CHOICE. The foot, right - bottom LEFT is the depth
// readout's on a side scan, so the two do not contend. One anchor, no ternary, and so no
// undefined to assign: the fix and the trap leave together. Rule 1 still governs what the
// pills SAY; it no longer governs where they sit.
//
// THE TELL, for the next one: `? something : undefined` on an anchor line. There was
// exactly one other in v2, the hairline in PulsePausedGutter.qml, and it is gone too.
//
// ONE INSTANCE ABOVE BOTH PANES. Everything it reports is app-wide rather than pane-wide -
// a demo is running or it is not - so it is hosted in main.qml beside the rail rather than
// inside PulseAppV2, which is built once per pane.
Item {
    id: pillColumn

    property real uiScale:    1.0
    property real safeTop:    0
    property real safeBottom: 0
    property real safeRight:  0

    // RULE 1: what the PICTURE is, never what is connected.
    property bool displayIs2D: true

    property bool   presentingLog:  false
    property bool   isDemo:         false
    property string presentedName:  ""

    property bool   recording:      false

    // ---- OLD DATA -----------------------------------------------------------
    //
    // A BINDING, NOT AN ARMING. Classic arms this from a drag handler, runs a 6 s
    // countdown and two timers, and then drags the picture back to live by itself.
    // Olav: "The 6 Sec countdown can then be removed. User can decide for himself,
    // and the warning is anyway on the screen." So there is no countdown, no auto
    // return and no timer in this file - the pill is simply up while the timeline is
    // off the head, and it goes when the timeline returns. One value, one holder,
    // nothing to keep in step.
    property bool   scrolledBack:   false

    signal goLive()

    // ---- ECHOGRAM SPEED, AND WHY IT IS TWO PROPERTIES ------------------------
    //
    // echogramSpeed is pulseRuntimeSettings' - what the PICTURE is running at, and so
    // what this pill SAYS, by rule 1. echogramSpeedSetting is pulseSettings' - what the
    // user has set, and it is the TRIGGER and nothing else.
    //
    // They are not the same number and splitting the two jobs between them is what keeps
    // the pill honest at both edges. setEchogramPaused writes 1.0 into the runtime one on
    // pause and restores it on resume: triggering on the runtime value would flash "1.0x"
    // as the picture freezes and "1.8x" again as it thaws, neither of which anyone asked
    // for. Triggering on the persistent one shows the pill exactly when a person changed
    // the speed.
    //
    // And when the two genuinely disagree - main.qml forces the runtime speed to 1 for a
    // blue profile and nothing puts it back when the profile returns to red - the pill
    // reports what the picture is doing rather than what the setting still says. That
    // defect is not fixed here; this makes it visible instead of hiding it.
    property real   echogramSpeed:        1.0
    property real   echogramSpeedSetting: 1.0

    signal stopDemo()
    signal closeFile()
    signal startRecording()
    signal stopRecording()

    // ---- THE RECORDING QUESTION ---------------------------------------------
    //
    // Olav, who wrote the control this replaces: "Even I have pressed recording on multiple
    // occasions when I should not have, and I made the UI. It is needed!" So recording asks
    // in BOTH directions, and the question is a pill in this column rather than a dialog.
    //
    // WHY HERE AND NOT BESIDE THE RAIL BUTTON THAT RAISES IT. One subject, one place:
    // whether the app is recording already lives in this column, so the question about it
    // belongs next to the answer rather than in a second surface the eye has to learn. The
    // tap is acknowledged where it happened - the rail's Record button lights - and this
    // column sits in the corner the picture's own flow already points the user at.
    //
    // A PLAIN STATE PROPERTY with exactly one writer and no binding on it. That is not the
    // shape rule 2 forbids: rule 2 is about a value with TWO sources, where a binding gets
    // destroyed by a handler. Nothing binds this.
    property string asking: ""        // "" | "start" | "stop"

    // A PLAIN STATE PROPERTY with one writer, the same shape as `asking` below and for the
    // same reason: nothing binds it.
    property bool speedShown: false

    // Bindings evaluate once on the way up, and the stored speed arriving after the 1.0
    // default is a change like any other. Without this the pill greets every launch.
    property bool _speedArmed: false
    Component.onCompleted: _speedArmed = true

    onEchogramSpeedSettingChanged: {
        if (!_speedArmed)
            return
        // RULE 1 AGAIN: the speed only applies to a picture that flows sideways. On a side
        // scan the number is real but it is not what the user is looking at.
        if (!displayIs2D)
            return
        speedShown = true
        speedHideTimer.restart()
    }

    Timer {
        id: speedHideTimer
        interval: 1500
        repeat: false
        onTriggered: pillColumn.speedShown = false
    }

    function askRecordStart() { asking = "start" }
    function askRecordStop()  { asking = "stop" }
    function dismissQuestion(){ asking = "" }

    // topInset and its Android status-bar floor are gone with the top anchor. safeTop is
    // kept declared because main.qml assigns it and a later top-edge overlay will want it.

    // A positioner, not a Layout - so a plain width on a child is correct throughout this
    // file, and an invisible pill simply takes no space.
    // THE BLOCKER, and it is what makes the two buttons above safe to offer at all.
    //
    // DeviceManager::openFile yields to the event loop while parsing, so taps arrive while
    // the parse is still on the stack. The first version of that commit excluded user input
    // precisely to stop a second file open landing on top of the first - and excluding input
    // also excludes Stop and Close. So input is admitted and the re-entrancy is removed a
    // better way: while an open runs, nothing but this column can be reached.
    //
    // INSIDE THIS ITEM, deliberately. It fills the same area the pills do and sits under
    // them in one file, so there is no z value for two files to agree about and no way for
    // the blocker to end up above the buttons it exists to protect. The rail, the panel and
    // both panes are siblings declared earlier in main.qml, so this covers all of them.
    MouseArea {
        anchors.fill: parent
        visible: pillColumn.openingFile
        enabled: visible
        acceptedButtons: Qt.AllButtons
        preventStealing: true
        onWheel: function (wheel) { wheel.accepted = true }
    }

    Column {
        id: stack

        anchors.right: parent.right
        anchors.rightMargin: pillColumn.safeRight + Math.round(16 * pillColumn.uiScale)

        // ONE ANCHOR. See the head of this file: the pair of ternaries this replaces could
        // not express "not anchored", so the top one was permanent and the bottom one was
        // decorative.
        anchors.bottom: parent.bottom
        anchors.bottomMargin: pillColumn.safeBottom + Math.round(14 * pillColumn.uiScale)

        spacing: Math.round(10 * pillColumn.uiScale)

        // OPENING A FILE. First in the column for the same arithmetic the old-data pill
        // records: a Column anchored at its bottom grows upward, so nothing below moves.
        //
        // THE BLUE FAMILY, because this IS the file family - identical to the "Viewing
        // recording" pill below, which is what this becomes when the open finishes.
        Rectangle {
            id: openingPill

            visible: pillColumn.openingFile
            height:  openingBody.height + Math.round(22 * pillColumn.uiScale)
            width:   openingBody.width  + Math.round(28 * pillColumn.uiScale)
            radius:  Math.round(18 * pillColumn.uiScale)

            color: "#ee0f1317"
            border.width: 1
            border.color: "#3d7fd0"

            Column {
                id: openingBody
                anchors.centerIn: parent
                spacing: Math.round(8 * pillColumn.uiScale)

                Row {
                    id: openingRow
                    spacing: Math.round(12 * pillColumn.uiScale)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        // THE PERCENTAGE, NOT A BAR. The echogram filling underneath is
                        // already a better progress bar than a progress bar: it shows what
                        // you are getting rather than only how much. This is the number for
                        // when the picture is still mostly empty.
                        text: qsTr("Opening")
                              + (pillColumn.openingName === ""
                                 ? "" : "   ·   " + pillColumn.openingName)
                              + "   ·   " + pillColumn.openingProgress + " %"
                        color: "#eaf1f8"
                        font.pixelSize: Math.round(17 * pillColumn.uiScale)
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width:  1
                        height: Math.round(24 * pillColumn.uiScale)
                        color: "#30ffffff"
                    }

                    // A WORD, NOT A GLYPH, for the reason the log pill's action states:
                    // one symbol cannot carry two consequences.
                    Rectangle {
                        id: openingStopButton

                        anchors.verticalCenter: parent.verticalCenter
                        width:  openingStopLabel.width + Math.round(26 * pillColumn.uiScale)
                        height: Math.round(34 * pillColumn.uiScale)
                        radius: height / 2
                        color: openingStopArea.pressed ? "#2f7fb5" : "#1d3446"
                        border.width: 1
                        border.color: "#3d7fd0"

                        Text {
                            id: openingStopLabel
                            anchors.centerIn: parent
                            text: qsTr("Stop")
                            color: "#cfe0f2"
                            font.pixelSize: Math.round(16 * pillColumn.uiScale)
                            font.bold: true
                        }

                        MouseArea {
                            id: openingStopArea
                            anchors.fill: parent
                            onClicked: pillColumn.stopOpening()
                        }
                    }

                    Rectangle {
                        id: openingCloseButton

                        anchors.verticalCenter: parent.verticalCenter
                        width:  openingCloseLabel.width + Math.round(26 * pillColumn.uiScale)
                        height: Math.round(34 * pillColumn.uiScale)
                        radius: height / 2
                        color: openingCloseArea.pressed ? "#2f7fb5" : "#1d3446"
                        border.width: 1
                        border.color: "#3d7fd0"

                        Text {
                            id: openingCloseLabel
                            anchors.centerIn: parent
                            text: qsTr("Close")
                            color: "#cfe0f2"
                            font.pixelSize: Math.round(16 * pillColumn.uiScale)
                            font.bold: true
                        }

                        MouseArea {
                            id: openingCloseArea
                            anchors.fill: parent
                            onClicked: pillColumn.abortOpening()
                        }
                    }
                }

                // THE SENTENCE UNDER THE CONTROLS, which is the loupe's pattern - "No
                // position - you can inspect the echogram, but not mark it". Two words
                // cannot carry which one keeps the picture, and this is the one moment a
                // user cannot try a control to find out what it does.
                Text {
                    width: openingRow.width
                    wrapMode: Text.WordWrap
                    text: qsTr("Stop keeps what has loaded   ·   Close discards the file")
                    color: "#8fa6bd"
                    font.pixelSize: Math.round(14 * pillColumn.uiScale)
                }
            }
        }

        // OLD DATA. Olav's sentence, and the demo pill's pattern in a warning accent -
        // same capsule, same body, same divider, same word in the action slot. What
        // separates them is the colour and the fact that this one is about to be acted
        // on: "Stop" ends a demo, "Live now" ends a scroll.
        //
        // FIRST IN THE COLUMN. It is the most urgent thing the column can say, and the
        // arithmetic works in its favour: a Column anchored at its BOTTOM - which is now
        // where this column always sits - grows upward when a first child appears, so
        // nothing below it moves. That was written as an intention and is finally true.
        //
        // NO BUTTON THAT ONLY WAITS. The action does exactly what classic's timer did
        // after six seconds, at the moment the user asks for it instead.
        Rectangle {
            id: oldDataPill

            visible: pillColumn.scrolledBack
            height:  Math.round(46 * pillColumn.uiScale)
            width:   oldDataRow.width + Math.round(28 * pillColumn.uiScale)
            radius:  height / 2

            color: "#cc0f1317"
            border.width: 1
            border.color: "#d8a21f"

            Row {
                id: oldDataRow
                anchors.centerIn: parent
                spacing: Math.round(12 * pillColumn.uiScale)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("You scrolled back")
                    color: "#f4ead6"
                    font.pixelSize: Math.round(17 * pillColumn.uiScale)
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width:  1
                    height: Math.round(24 * pillColumn.uiScale)
                    color: "#30ffffff"
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width:  oldDataActionLabel.width + Math.round(26 * pillColumn.uiScale)
                    height: Math.round(34 * pillColumn.uiScale)
                    radius: height / 2
                    color: oldDataActionArea.pressed ? "#8f7318" : "#3a2f14"
                    border.width: 1
                    border.color: "#d8a21f"

                    Text {
                        id: oldDataActionLabel
                        anchors.centerIn: parent
                        text: qsTr("Live now")
                        color: "#f4dfae"
                        font.pixelSize: Math.round(16 * pillColumn.uiScale)
                        font.bold: true
                    }

                    MouseArea {
                        id: oldDataActionArea
                        anchors.fill: parent
                        onClicked: pillColumn.goLive()
                    }
                }
            }
        }

        // WHAT THE APP IS PRESENTING AS. This is backlog item 8's claim made visible: with
        // nothing connected, the log decides the whole interface, so the app is calling
        // itself a device it is not connected to. At a stand somebody will ask, and this is
        // the answer.
        Rectangle {
            id: logPill

            visible: pillColumn.presentingLog
            height:  Math.round(46 * pillColumn.uiScale)
            width:   pillRow.width + Math.round(28 * pillColumn.uiScale)
            radius:  height / 2

            color: "#cc0f1317"
            border.width: 1
            border.color: "#3d7fd0"

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: Math.round(12 * pillColumn.uiScale)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // Olav's words for the two cases. "Demo" is a paced replay the app
                    // experiences as a live connection; "Viewing recording" is a file being
                    // rendered. They are genuinely different states - one closed the links
                    // on its way in and the other did not - so they are not one word.
                    text: (pillColumn.isDemo ? qsTr("Demo") : qsTr("Viewing recording"))
                          + (pillColumn.presentedName === ""
                             ? "" : "   ·   " + pillColumn.presentedName)
                    color: "#eaf1f8"
                    font.pixelSize: Math.round(17 * pillColumn.uiScale)
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width:  1
                    height: Math.round(24 * pillColumn.uiScale)
                    color: "#30ffffff"
                }

                // A WORD, NOT A GLYPH. The rail's arrow already proved what a glyph costs
                // when one symbol can mean two consequences: it was tapped expecting the
                // rail to hide and it left the whole UI. Stopping a demo and closing a file
                // are different acts on different machinery, so they say which they are.
                Rectangle {
                    id: actionButton

                    anchors.verticalCenter: parent.verticalCenter
                    width:  actionLabel.width + Math.round(26 * pillColumn.uiScale)
                    height: Math.round(34 * pillColumn.uiScale)
                    radius: height / 2
                    color: actionArea.pressed ? "#2f7fb5" : "#1d3446"
                    border.width: 1
                    border.color: "#3d7fd0"

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: pillColumn.isDemo ? qsTr("Stop") : qsTr("Close")
                        color: "#cfe0f2"
                        font.pixelSize: Math.round(16 * pillColumn.uiScale)
                        font.bold: true
                    }

                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        onClicked: {
                            if (pillColumn.isDemo)
                                pillColumn.stopDemo()
                            else
                                pillColumn.closeFile()
                        }
                    }
                }
            }
        }

        // RECORDING, AND THE WAY TO STOP IT. The control this replaces was a one-tap stop
        // with no question - and a live example of the defect V2 exists to prevent, since
        // it carried `visible: isRecordingKlf` AND a handler that assigned that same
        // `visible`, destroying the binding the first time recording was toggled.
        Rectangle {
            id: recordingPill

            visible: pillColumn.recording && pillColumn.asking !== "stop"
            height:  Math.round(46 * pillColumn.uiScale)
            width:   recordingRow.width + Math.round(28 * pillColumn.uiScale)
            radius:  height / 2

            color: "#cc0f1317"
            border.width: 1
            border.color: "#d81f26"

            Row {
                id: recordingRow
                anchors.centerIn: parent
                spacing: Math.round(12 * pillColumn.uiScale)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width:  Math.round(12 * pillColumn.uiScale)
                    height: width
                    radius: width / 2
                    color: "#d81f26"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Recording")
                    color: "#eaf1f8"
                    font.pixelSize: Math.round(17 * pillColumn.uiScale)
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width:  1
                    height: Math.round(24 * pillColumn.uiScale)
                    color: "#30ffffff"
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width:  recordingStopLabel.width + Math.round(26 * pillColumn.uiScale)
                    height: Math.round(34 * pillColumn.uiScale)
                    radius: height / 2
                    color: recordingStopArea.pressed ? "#8f1a20" : "#3a1418"
                    border.width: 1
                    border.color: "#d81f26"

                    Text {
                        id: recordingStopLabel
                        anchors.centerIn: parent
                        text: qsTr("Stop")
                        color: "#f2cfd2"
                        font.pixelSize: Math.round(16 * pillColumn.uiScale)
                        font.bold: true
                    }

                    MouseArea {
                        id: recordingStopArea
                        anchors.fill: parent
                        // ASKS. It does not stop.
                        onClicked: pillColumn.askRecordStop()
                    }
                }
            }
        }

        // THE QUESTION. One pill, both directions, so there is one thing to recognise
        // rather than two. It replaces the recording pill while it is up - two red pills
        // saying different things about the same subject would be worse than one.
        Rectangle {
            id: questionPill

            visible: pillColumn.asking !== ""
            height:  Math.round(56 * pillColumn.uiScale)
            width:   questionRow.width + Math.round(28 * pillColumn.uiScale)
            radius:  Math.round(14 * pillColumn.uiScale)

            color: "#ee141a1f"
            border.width: 1
            border.color: "#d8a21f"

            Row {
                id: questionRow
                anchors.centerIn: parent
                spacing: Math.round(12 * pillColumn.uiScale)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: pillColumn.asking === "start"
                          ? qsTr("Record the echogram now?")
                          : qsTr("Stop recording the echogram now?")
                    color: "#f4ead6"
                    font.pixelSize: Math.round(17 * pillColumn.uiScale)
                }

                // THE ANSWER THAT CHANGES SOMETHING is filled and amber, the one that
                // changes nothing is an outline - the same pairing the setup card's escape
                // hatch uses, so a second question in this app reads like the first.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width:  confirmLabel.width + Math.round(28 * pillColumn.uiScale)
                    height: Math.round(38 * pillColumn.uiScale)
                    radius: height / 2
                    color: confirmArea.pressed ? "#b8860b" : "#d8a21f"

                    Text {
                        id: confirmLabel
                        anchors.centerIn: parent
                        text: pillColumn.asking === "start" ? qsTr("Record") : qsTr("Stop")
                        color: "#1a1400"
                        font.pixelSize: Math.round(16 * pillColumn.uiScale)
                        font.bold: true
                    }

                    MouseArea {
                        id: confirmArea
                        anchors.fill: parent
                        onClicked: {
                            var wasAsking = pillColumn.asking
                            pillColumn.dismissQuestion()
                            if (wasAsking === "start")
                                pillColumn.startRecording()
                            else if (wasAsking === "stop")
                                pillColumn.stopRecording()
                        }
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width:  dismissLabel.width + Math.round(28 * pillColumn.uiScale)
                    height: Math.round(38 * pillColumn.uiScale)
                    radius: height / 2
                    color: dismissArea.pressed ? "#2a303a" : "transparent"
                    border.width: 1
                    border.color: "#6d7480"

                    Text {
                        id: dismissLabel
                        anchors.centerIn: parent
                        text: pillColumn.asking === "start" ? qsTr("Not now")
                                                           : qsTr("Keep recording")
                        color: "#cfd6de"
                        font.pixelSize: Math.round(16 * pillColumn.uiScale)
                    }

                    MouseArea {
                        id: dismissArea
                        anchors.fill: parent
                        onClicked: pillColumn.dismissQuestion()
                    }
                }
            }
        }

        // ECHOGRAM SPEED. The family's capsule with nothing to press, because there is
        // nothing to undo - it reports a gesture that has already happened and then goes
        // away. Blue: informational, the same accent the demo pill wears.
        //
        // LAST IN THE COLUMN on purpose. It is the only pill that comes and goes on its
        // own, and a transient item above stable ones would shuffle them every time the
        // picture is pinched. Last, nothing above it moves on a 2D picture - which is the
        // only picture it appears on.
        //
        // The label is dim and the value is not, so the eye lands on the number. Classic
        // prints "Echogram speed: 1.3" in the top centre of the screen; the words are
        // Olav's and they stay, and the bare number gains the x that says it is a factor -
        // the same correction the loupe's magnification got.
        Rectangle {
            id: speedPill

            visible: pillColumn.speedShown
            height:  Math.round(46 * pillColumn.uiScale)
            width:   speedRow.width + Math.round(28 * pillColumn.uiScale)
            radius:  height / 2

            color: "#cc0f1317"
            border.width: 1
            border.color: "#3d7fd0"

            Row {
                id: speedRow
                anchors.centerIn: parent
                spacing: Math.round(12 * pillColumn.uiScale)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Echogram speed")
                    color: "#9fb3c8"
                    font.pixelSize: Math.round(17 * pillColumn.uiScale)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // THE RUNTIME VALUE - what the picture is running at. See the two
                    // properties at the top of this file for why it is not the other one.
                    text: pillColumn.echogramSpeed.toFixed(1) + "\u00D7"
                    color: "#eaf1f8"
                    font.pixelSize: Math.round(19 * pillColumn.uiScale)
                    font.bold: true
                }
            }
        }
    }
}
