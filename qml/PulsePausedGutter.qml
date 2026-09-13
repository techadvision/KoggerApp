import QtQuick 2.15

// PAUSED IS ITS OWN MODE (Stage 4 b) - the canvas's words, and the reason this is a
// separate surface rather than a state of the rail.
//
// While the picture is frozen you are INSPECTING it: reading a hard bottom, measuring a
// feature, placing a waypoint. Nothing on the rail helps with that - you are not choosing a
// palette with a crosshair in your other hand - so the rail and the indicator pills step
// aside and what is left on the picture is the crosshair and the loupe.
//
// ONE BUTTON GETS OUT, AND IT IS THE LARGEST THING HERE. That is the whole job of this
// gutter: a frozen echogram with no obvious way back is the kind of thing a user reports as
// a crash.
//
// IT TAKES THE RAIL'S OWN WIDTH, deliberately. The canvas puts the paused gutter along the
// flow - down the left for a side scan, along the foot for a 2D picture - because that is
// where the history bar belongs once it comes off the picture. The history bar has not moved
// yet, so this gutter carries only a button, a button does not care which way the picture
// flows, and matching the rail's width means the echogram does not JUMP the moment you pause
// it. When the history bar moves in, that is the commit where the flow question is real.
Item {
    id: gutter

    property real uiScale:    1.0
    property real safeTop:    0
    property real safeBottom: 0
    property real safeLeft:   0

    signal resumeRequested()

    readonly property real gutterWidth: Math.round(76 * uiScale) + safeLeft
    readonly property real inset: gutterWidth

    width: gutterWidth

    readonly property bool onAndroid: Qt.platform.os === "android"
    readonly property real topInset: Math.max(safeTop, onAndroid ? Math.round(34 * uiScale) : 0)

    Rectangle {
        anchors.fill: parent
        color: "#ee0f1317"
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: "#40d8a21f"
    }

    Rectangle {
        id: resumeButton

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: gutter.topInset + Math.round(14 * gutter.uiScale)

        width:  Math.round(62 * gutter.uiScale)
        height: width
        radius: width / 2

        color: resumeArea.pressed ? "#b8860b" : "#d8a21f"

        Image {
            anchors.centerIn: parent
            width:  Math.round(32 * gutter.uiScale)
            height: width
            source: "./icons/ui/pulse_play_pause.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        MouseArea {
            id: resumeArea
            anchors.fill: parent
            onClicked: gutter.resumeRequested()
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: resumeButton.bottom
        anchors.topMargin: Math.round(10 * gutter.uiScale)
        text: qsTr("Resume")
        color: "#f4ead6"
        font.pixelSize: Math.round(13 * gutter.uiScale)
    }

    // The state, said once and read down the gutter rather than across the picture. The
    // classic UI puts "paused" in a pill top right, which is exactly where the indicator
    // stack now lives - and two things claiming that corner is how a corner stops being
    // read at all.
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        rotation: -90
        text: qsTr("PAUSED")
        color: "#80d8a21f"
        font.pixelSize: Math.round(22 * gutter.uiScale)
        font.bold: true
        font.letterSpacing: Math.round(4 * gutter.uiScale)
    }
}
