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

    // THE HISTORY BAR, NOW IN HERE (14 Sept 2026). It used to be drawn ON the echogram -
    // TimeLineShifter is anchors.fill on the window, with the horizontal variant across the
    // top and the vertical one down the left - and that overlap is not only untidy. Olav:
    // "the old design results in a moving magnifying box also when using the current drag
    // handles (as they are present in the paused echogram areas)." Dragging the bar dragged
    // the aim underneath it, because the aim's touch handling belongs to the plot and the
    // bar was sitting on the plot. Off the picture, that cannot happen at all - which beats
    // any amount of event-swallowing, because there is no longer an event to swallow.
    //
    // The gutter REPORTS and does not store, like every other V2 control: the position is
    // handed in and a move is a signal. main.qml stays the only thing that talks to core.
    property real timelinePosition: 1.0
    signal timelineMovedByUser(real pos)

    readonly property real gutterThickness:
          alongFoot ? Math.round(92 * uiScale) + safeBottom
                    : Math.round(76 * uiScale) + safeLeft

    // WHAT IT TAKES FROM THE PICTURE, on whichever axis it is on. main.qml adds it as a
    // left margin or a bottom margin; the gutter does not know which, and should not.
    readonly property real inset: gutterThickness

    // A natural size on both axes, for a host that sets neither. main.qml sets the two it
    // needs explicitly - the gutter is anchored at the left and the bottom and NOTHING
    // else, so the orientation is carried by width and height rather than by anchors that
    // appear and disappear. See the comment at the instantiation: a conditional anchor is
    // set but never cleared, so the first orientation the gutter is born in sticks.
    implicitWidth:  gutterThickness
    implicitHeight: gutterThickness

    readonly property bool onAndroid: Qt.platform.os === "android"
    readonly property real topInset: Math.max(safeTop, onAndroid ? Math.round(34 * uiScale) : 0)

    readonly property real buttonSize: Math.round(62 * uiScale)
    readonly property real edgePad:    Math.round(14 * uiScale)
    readonly property real sliderHalo: Math.round(10 * uiScale)

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
            id: resumeLabelV
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: resumeButtonV.bottom
            anchors.topMargin: Math.round(10 * gutter.uiScale)
            text: qsTr("Resume")
            color: "#f4ead6"
            font.pixelSize: Math.round(13 * gutter.uiScale)
        }

        // PAUSED moves off the middle to make room for the bar. A ROTATED Text keeps its
        // unrotated bounding box, so anchoring the slider to its top would run the slider
        // straight through the word; the box is given the text's natural WIDTH as its
        // height instead, which is the length the word actually occupies once turned.
        Item {
            id: pausedBoxV
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: gutter.safeBottom + Math.round(16 * gutter.uiScale)
            width:  parent.width
            height: pausedTextV.implicitWidth

            Text {
                id: pausedTextV
                anchors.centerIn: parent
                rotation: -90
                text: qsTr("PAUSED")
                color: "#80d8a21f"
                font.pixelSize: Math.round(22 * gutter.uiScale)
                font.bold: true
                font.letterSpacing: Math.round(4 * gutter.uiScale)
            }
        }

        // The bar fills what is left, head to foot, the same direction the picture runs.
        TimelineSliderVertical {
            id: historyV

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top:    resumeLabelV.bottom
            anchors.topMargin:    Math.round(16 * gutter.uiScale)
            anchors.bottom: pausedBoxV.top
            anchors.bottomMargin: Math.round(16 * gutter.uiScale)

            thickness: Math.round(48 * gutter.uiScale)
            halo:      gutter.sliderHalo
            inverted:  true            // 1.0 at the TOP, as it has always been

            from: 0
            to: 1
            stepSize: 0.0001
            value: gutter.timelinePosition

            onPositionChangedByUser: function (pos) { gutter.timelineMovedByUser(pos) }
            onVisibleChanged: if (visible) setPosition(gutter.timelinePosition)
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
            id: resumeLabelH
            anchors.verticalCenter: resumeButtonH.verticalCenter
            anchors.left: resumeButtonH.right
            anchors.leftMargin: Math.round(10 * gutter.uiScale)
            text: qsTr("Resume")
            color: "#f4ead6"
            font.pixelSize: Math.round(13 * gutter.uiScale)
        }

        Text {
            id: pausedTextH
            anchors.verticalCenter: resumeButtonH.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: gutter.edgePad
            text: qsTr("PAUSED")
            color: "#80d8a21f"
            font.pixelSize: Math.round(22 * gutter.uiScale)
            font.bold: true
            font.letterSpacing: Math.round(4 * gutter.uiScale)
        }

        TimelineSliderHorizontal {
            id: historyH

            anchors.verticalCenter: resumeButtonH.verticalCenter
            anchors.left:  resumeLabelH.right
            anchors.leftMargin:  Math.round(16 * gutter.uiScale)
            anchors.right: pausedTextH.left
            anchors.rightMargin: Math.round(16 * gutter.uiScale)

            thickness: Math.round(60 * gutter.uiScale)
            halo:      gutter.sliderHalo
            inverted:  false           // 1.0 newest at the RIGHT, as it has always been

            from: 0
            to: 1
            stepSize: 0.0001
            value: gutter.timelinePosition

            onPositionChangedByUser: function (pos) { gutter.timelineMovedByUser(pos) }
            onVisibleChanged: if (visible) setPosition(gutter.timelinePosition)
        }
    }
}
