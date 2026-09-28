import QtQuick 2.15

// THE MOSAIC PILL (28 Sept 2026) - Wipe, and Pause / Resume, on the mosaic itself.
//
// Olav: "If I could wipe, start, pause then the resulting render could become amazing."
// The boat is switched on ashore, slid in and driven out - all of it painted - and a turn
// smears about 35 m either side over what was already captured. Wipe throws away what is
// drawn; Pause stops the mosaic taking new pings until Resume. Both are Core's
// (mosaicWipe / mosaicSetPaused) and are kept as epoch ranges in MosaicMask, so a wiped
// area never comes back on a re-trace.
//
// ON THE MOSAIC PANE, AT THE TOP. It acts on that pane and on nothing else, so it sits on
// it rather than in the app-wide pill column - which is at the foot, right, and in a side +
// mosaic split would be on the mosaic too, one on top of the other.
//
// WIPE ASKS ONCE. It cannot be undone, and it is a finger's width from Pause. The first tap
// turns the button into "Tap to wipe" for three seconds; only a second tap in that time
// wipes. No dialog: a boat is moving while this is used.
Item {
    id: pill

    property real uiScale: 1.0
    property bool paused:  false

    signal wipeRequested()
    signal pauseRequested(bool paused)

    implicitWidth:  body.width
    implicitHeight: body.height

    property bool armed: false
    Timer {
        id: disarm
        interval: 3000
        onTriggered: pill.armed = false
    }

    Rectangle {
        id: body

        width:  row.width  + 2 * Math.round(10 * pill.uiScale)
        height: row.height + 2 * Math.round(7 * pill.uiScale)
        radius: height / 2
        color: "#ee0f1317"
        border.width: 1
        border.color: pill.paused ? "#d8a21f" : "#3d7fd0"

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Math.round(10 * pill.uiScale)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.paused ? qsTr("Mosaic paused") : qsTr("Mosaic")
                color: pill.paused ? "#d8a21f" : "#eaf1f8"
                font.pixelSize: Math.round(16 * pill.uiScale)
                font.bold: pill.paused
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Math.round(22 * pill.uiScale)
                color: "#30ffffff"
            }

            Repeater {
                // Two buttons, one shape.
                model: [ "wipe", "pause" ]

                delegate: Rectangle {
                    id: btn
                    readonly property bool isWipe: modelData === "wipe"

                    anchors.verticalCenter: parent.verticalCenter
                    width:  label.implicitWidth + 2 * Math.round(14 * pill.uiScale)
                    height: Math.round(34 * pill.uiScale)
                    radius: height / 2
                    color: area.pressed                    ? "#2f7fb5"
                         : (isWipe && pill.armed)          ? "#5a1d1d"
                         : (!isWipe && pill.paused)        ? "#3a2f12"
                         :                                   "#1d3446"
                    border.width: 1
                    border.color: (isWipe && pill.armed) ? "#e05a4f"
                                : (!isWipe && pill.paused) ? "#d8a21f"
                                : "#3d7fd0"

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: btn.isWipe ? (pill.armed ? qsTr("Tap to wipe") : qsTr("Wipe"))
                                         : (pill.paused ? qsTr("Resume") : qsTr("Pause"))
                        color: "#cfe0f2"
                        font.pixelSize: Math.round(16 * pill.uiScale)
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        // A little more than the drawn button: it is used from a moving boat.
                        anchors.margins: -Math.round(6 * pill.uiScale)
                        onClicked: {
                            if (btn.isWipe) {
                                if (pill.armed) {
                                    pill.armed = false
                                    disarm.stop()
                                    pill.wipeRequested()
                                } else {
                                    pill.armed = true
                                    disarm.restart()
                                }
                            } else {
                                pill.armed = false
                                pill.pauseRequested(!pill.paused)
                            }
                        }
                    }
                }
            }
        }
    }
}
