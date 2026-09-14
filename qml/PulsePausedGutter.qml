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
// IT FOLLOWS THE FLOW (14 Sept 2026). The first version took the rail's width and ran down
// the left whatever the picture was doing, so that pausing never moved the echogram
// sideways. Olav's call overrides that: "We do #2, follow the flow. That is the only
// intuitive way." A side scan flows downward and keeps the vertical gutter at the left; a
// 2D picture flows sideways and gets a horizontal one along the FOOT, which is where the
// history bar belongs once it comes off the picture.
//
// The cost is paid openly rather than hidden: pausing a 2D picture now returns the rail's
// width and takes height at the foot, so the echogram DOES reflow. That was the trade, and
// main.qml's inset comment says so rather than keeping a promise it can no longer make.
Item {
    id: gutter

    property real uiScale:    1.0
    property real safeTop:    0
    property real safeBottom: 0
    property real safeLeft:   0

    // WHICH WAY THE PICTURE FLOWS, handed in rather than worked out here. It is the same
    // flag the history bar has always used to choose between its horizontal and vertical
    // slider, so the gutter and the bar it is about to swallow cannot disagree about which
    // way the echogram runs.
    property bool alongFoot: false

    signal resumeRequested()

    readonly property real gutterThickness:
          alongFoot ? Math.round(92 * uiScale) + safeBottom
                    : Math.round(76 * uiScale) + safeLeft

    // WHAT IT TAKES FROM THE PICTURE, on whichever axis it is on. main.qml adds it as a
    // left margin or a bottom margin; the gutter does not know which, and should not.
    readonly property real inset: gutterThickness

    // Sized on BOTH axes as an IMPLICIT size, so main.qml can anchor whichever axis the
    // orientation calls for and the other falls back to this. An explicit width AND a
    // left+right anchor would be a conflict, and a conditional `width: undefined` is the
    // kind of line that works until somebody reads it.
    implicitWidth:  gutterThickness
    implicitHeight: gutterThickness

    readonly property bool onAndroid: Qt.platform.os === "android"
    readonly property real topInset: Math.max(safeTop, onAndroid ? Math.round(34 * uiScale) : 0)

    readonly property real buttonSize: Math.round(62 * uiScale)
    readonly property real edgePad:    Math.round(14 * uiScale)

    Rectangle {
        anchors.fill: parent
        color: "#ee0f1317"
    }

    // The hairline that faces the picture, on whichever side that is.
    Rectangle {
        anchors.right:  gutter.alongFoot ? undefined : parent.right
        anchors.left:   gutter.alongFoot ? parent.left : undefined
        anchors.top:    parent.top
        anchors.bottom: gutter.alongFoot ? undefined : parent.bottom
        width:  gutter.alongFoot ? parent.width : 1
        height: gutter.alongFoot ? 1 : undefined
        color: "#40d8a21f"
    }

    // ---- THE VERTICAL GUTTER: a side scan, flowing downward ------------------
    //
    // Resume at the head of the flow, the state read down the gutter. The classic UI puts
    // "paused" in a pill top right, which is exactly where the V2 indicator stack now
    // lives - and two things claiming that corner is how a corner stops being read at all.
    Item {
        id: sideColumn
        anchors.fill: parent
        visible: !gutter.alongFoot
        enabled: visible

        Rectangle {
            id: resumeButtonV

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: gutter.topInset + gutter.edgePad

            width:  gutter.buttonSize
            height: width
            radius: width / 2

            color: resumeAreaV.pressed ? "#b8860b" : "#d8a21f"

            Image {
                anchors.centerIn: parent
                width:  Math.round(32 * gutter.uiScale)
                height: width
                source: "./icons/ui/pulse_play_pause.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                id: resumeAreaV
                anchors.fill: parent
                onClicked: gutter.resumeRequested()
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: resumeButtonV.bottom
            anchors.topMargin: Math.round(10 * gutter.uiScale)
            text: qsTr("Resume")
            color: "#f4ead6"
            font.pixelSize: Math.round(13 * gutter.uiScale)
        }

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

    // ---- THE FOOT GUTTER: a 2D picture, flowing sideways ---------------------
    //
    // The same three things in the same order, turned through ninety degrees: the way out
    // first, the state last. "Resume" sits BESIDE the button rather than under it - 92 px
    // of height holds a 62 px circle and its margins and nothing else - and PAUSED is
    // upright, because a word rotated on a horizontal bar is a word nobody reads.
    Item {
        id: footRow
        anchors.fill: parent
        visible: gutter.alongFoot
        enabled: visible

        Rectangle {
            id: resumeButtonH

            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -gutter.safeBottom / 2
            anchors.left: parent.left
            anchors.leftMargin: gutter.safeLeft + gutter.edgePad

            width:  gutter.buttonSize
            height: width
            radius: width / 2

            color: resumeAreaH.pressed ? "#b8860b" : "#d8a21f"

            Image {
                anchors.centerIn: parent
                width:  Math.round(32 * gutter.uiScale)
                height: width
                source: "./icons/ui/pulse_play_pause.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                id: resumeAreaH
                anchors.fill: parent
                onClicked: gutter.resumeRequested()
            }
        }

        Text {
            anchors.verticalCenter: resumeButtonH.verticalCenter
            anchors.left: resumeButtonH.right
            anchors.leftMargin: Math.round(10 * gutter.uiScale)
            text: qsTr("Resume")
            color: "#f4ead6"
            font.pixelSize: Math.round(13 * gutter.uiScale)
        }

        Text {
            anchors.verticalCenter: resumeButtonH.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: gutter.edgePad
            text: qsTr("PAUSED")
            color: "#80d8a21f"
            font.pixelSize: Math.round(22 * gutter.uiScale)
            font.bold: true
            font.letterSpacing: Math.round(4 * gutter.uiScale)
        }
    }
}
