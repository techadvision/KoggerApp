import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window

// The new Pulse UI - the edge-rail design decided on 11 Sept 2026.
//
// This is a PLACEHOLDER. Stage 2 built the switch; Stage 4 builds what is behind
// it. Everything real still lives in PulseAppClassic.qml, and the switch that got
// you here lives in the expert settings inside that UI - which is why this screen
// carries its own way back. Without it, turning the variant on would strand you,
// because pulseSettings.uiVariant is persisted and survives a restart.
//
// It satisfies the variant contract declared at the top of PulseApp.qml and does
// nothing else. applyFiltering() and armOldDataWarning() are deliberate no-ops:
// while this variant is showing, the water-body filter and the old-data warning
// are not driven by anything, and that is expected rather than a fault.

Item {
    id: pulseAppV2

    // Set by PulseApp.qml at construction - see PulseAppClassic.qml.
    property var plot:  parent
    property var pinch: null

    anchors.fill: parent

    // ---- Variant contract (see PulseApp.qml) --------------------------------

    property real maxDepthValue: plot && plot.quickChangeMaxRangeValue ? plot.quickChangeMaxRangeValue : 0

    function applyFiltering(value) {
        // no-op until Stage 4
    }

    function armOldDataWarning() {
        // no-op until Stage 4
    }

    // -------------------------------------------------------------------------

    readonly property real shortSide: Math.min(Screen.width, Screen.height)
    readonly property real s: Math.max(1.0, shortSide / 1100)

    Rectangle {
        id: card

        anchors.centerIn: parent
        width:  Math.min(parent.width  - Math.round(40 * s), Math.round(620 * s))
        height: Math.min(parent.height - Math.round(40 * s), column.implicitHeight + Math.round(56 * s))

        radius: Math.round(12 * s)
        color: "#dd101418"
        border.width: 1
        border.color: "#5affffff"

        // Swallow touches on the card only. The echogram around it stays live and
        // pinchable, which is the point of building the new UI over a real picture.
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: column
            anchors.centerIn: parent
            width: parent.width - Math.round(56 * s)
            spacing: Math.round(16 * s)

            Text {
                Layout.fillWidth: true
                text: "PULSE UI v2"
                color: "#8ad3ff"
                font.pixelSize: Math.round(30 * s)
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                text: "Nothing is built here yet.\n\n"
                    + "This variant exists so the switch can be tested end to end: "
                    + "the edge rail, the sliding panel and the phone sheet arrive in Stage 4. "
                    + "Until then the classic UI is the one that works."
                color: "#eeffffff"
                font.pixelSize: Math.round(19 * s)
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: Math.round(64 * s)
                Layout.preferredWidth:  Math.round(360 * s)

                text: "Back to the classic UI"

                background: Rectangle {
                    radius: Math.round(8 * s)
                    color: parent.pressed ? "#2f7fb5" : "#3f9fd5"
                }

                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: Math.round(20 * s)
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    console.log("PULSE UI: v2 placeholder - returning to classic")
                    pulseSettings.uiVariant = "classic"
                }
            }
        }
    }

    Component.onCompleted: console.log("PULSE UI: v2 placeholder shown; plot is",
                                       plot ? "set" : "NULL")
}
