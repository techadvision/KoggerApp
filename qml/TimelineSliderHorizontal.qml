import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    // public API
    property int  thickness: _isAndroid ? 80 : 60 //theme.controlHeight
    property int  halo: 10
    property bool inverted: false               // 1.0 newest at RIGHT
    property alias value: slider.value          // safe to bind from parent
    property alias from:  slider.from
    property alias to:    slider.to
    property alias stepSize: slider.stepSize
    signal positionChangedByUser(real pos)

    // parent can push position programmatically
    function setPosition(p) {
        slider.value = Math.max(slider.from, Math.min(slider.to, p));
    }

    // wrapper height: track + halo to make tapping easy
    height: thickness + halo * 2
    // width is set by parent anchors

    // the visual slider (no core calls here)
    Slider {
        id: slider
        z: 10
        anchors {
            fill: parent
            leftMargin:  root.halo
            rightMargin: root.halo
            topMargin:   root.halo
            bottomMargin:root.halo
        }
        orientation: Qt.Horizontal
        from: 0; to: 1; value: 0; stepSize: 0.0001
        snapMode: Slider.SnapAlways
        height: root.thickness

        // Inversion for drawing only
        readonly property real effPos: root.inverted ? (1 - slider.visualPosition) : slider.visualPosition
        property real _xPos: slider.leftPadding + effPos * (slider.availableWidth - handleControl.width)
        property real _yPos: slider.topPadding + (slider.availableHeight - handleControl.height) / 2

        // track & handle per your colors
        background: Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: overlayMouse.pressed ? "#80666666" : "#80000000"
            border.width: 1
            border.color: "#40fffff0"
        }
        handle: Rectangle {
            id: handleControl
            x: slider._xPos
            y: slider._yPos
            width: slider.height
            height: slider.height
            radius: width / 2
            color: "#FFFFF0"
            border.width: 0
        }
    }

    // FRONT overlay – swallows input & maps x → pos, then emits upwards
    Item {
        anchors.fill: parent
        z: 20

        MouseArea {
            id: overlayMouse
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            preventStealing: true
            propagateComposedEvents: false

            function clamp01(x) { return Math.max(0, Math.min(1, x)); }
            function posFromX(px) {
                var nx = clamp01((px - slider.leftPadding) / slider.availableWidth);
                var t  = root.inverted ? (1 - nx) : nx;
                return slider.from + t * (slider.to - slider.from);
            }
            function update(ev) {
                var p = mapToItem(slider, ev.x, ev.y);
                var val = posFromX(p.x);
                root.positionChangedByUser(val);
            }

            onPressed:{
                mouse.accepted = true;
                console.log("SLIDER: Horizontal - Caught onPressed and prevented it from getting throught to the echogram")
                waterViewFirst.setDragActive(true);
                update(mouse);
            }
            onPositionChanged: {
                mouse.accepted = true;
                if (pressed) update(mouse);
            }
            onReleased: {
                mouse.accepted = true
                waterViewFirst.setDragActive(false);
            }
            onClicked: {
                mouse.accepted = true
                console.log("SLIDER: Horizontal - Caught onClicked and prevented it from getting throught to the echogram")
            }

        }
    }
}
