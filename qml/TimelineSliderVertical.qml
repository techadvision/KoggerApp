import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property int  thickness: _isAndroid ? 80 : 60 //theme.controlHeight
    property int  halo: 10
    property bool inverted: true            // true => 1.0 at TOP, false => 1.0 at BOTTOM

    // expose slider API for binding from the shifter
    property alias value:    slider.value
    property alias from:     slider.from
    property alias to:       slider.to
    property alias stepSize: slider.stepSize
    signal positionChangedByUser(real pos)

    function setPosition(p) {
        slider.value = Math.max(slider.from, Math.min(slider.to, p));
    }

    // bar strip width; parent controls height by anchoring top/bottom
    width: thickness + halo * 2

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
        orientation: Qt.Vertical
        from: 0; to: 1; value: 0; stepSize: 0.0001
        snapMode: Slider.SnapAlways
        width: root.thickness

        // ---- USE VALUE, NOT visualPosition ----
        readonly property real norm: (to === from) ? 0 : (value - from) / (to - from)
        readonly property real drawT: root.inverted ? (1 - norm) : norm
        // drawT = 0 at TOP, 1 at BOTTOM

        // Handle position (keep the thumb centered)
        property real _yPos: topPadding + drawT * (availableHeight - handleControl.height)

        background: Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: overlayMouse.pressed ? "#80666666" : "#80000000"
            border.width: 1
            border.color: "#40fffff0"
        }
        handle: Rectangle {
            id: handleControl
            // circle whose diameter equals bar width
            width: slider.width
            height: slider.width
            radius: width / 2

            // horizontally centered using the handle width
            x: slider.leftPadding + (slider.availableWidth - width) / 2
            y: slider._yPos
            color: "#FFFFF0"
            border.width: 0
        }
    }

    // FRONT overlay – swallows input & maps Y → value
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

            // Inverse of the drawing formula:
            // drawT = (y - topPadding) / (availableHeight - handleH)
            // norm  = inverted ? (1 - drawT) : drawT
            // value = from + norm * (to - from)
            function posFromY(py) {
                var handleH = slider.handle ? slider.handle.height : slider.width; // safe fallback
                var denom = Math.max(1, slider.availableHeight - handleH);
                var drawT = clamp01((py - slider.topPadding - handleH/2) / denom); // center under finger
                var norm  = root.inverted ? (1 - drawT) : drawT;
                return slider.from + norm * (slider.to - slider.from);
            }

            function update(ev) {
                var p = mapToItem(slider, ev.x, ev.y);
                var val = posFromY(p.y);
                root.positionChangedByUser(val);     // emit up; parent will set binding
            }

            onPressed:{
                mouse.accepted = true;
                console.log("SLIDER: Vertical - Caught onPressed and prevented it from getting throught to the echogram")
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
                console.log("SLIDER: Vertical - Caught onClicked and prevented it from getting throught to the echogram")
            }
        }
    }
}
