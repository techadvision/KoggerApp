import QtQuick 2.15
import QtQuick.Controls 2.15

// Reusable CheckBox with custom indicator, background and optional auto-clear timer
CheckBox {
    id: control
    implicitWidth: 48
    implicitHeight: 48

    // Bind this to your model or initial state
    property bool initialChecked: false
    // Target object and property name to update on change
    property var target
    property string targetPropertyName: ""

    // Auto-clear behavior: if true, will reset after `clearInterval` ms when checked
    property bool clearAfter: false
    property int clearInterval: 2000

    // Initialize checked state
    checked: initialChecked

    // Custom white background with subtle border
    background: Rectangle {
        anchors.fill: parent
        color: "white"
        radius: 4
        border.width: 1
        border.color: "black"
    }

    // Custom large check indicator
    indicator: Item {
        anchors.fill: parent
        Canvas {
            id: indicatorCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (control.checked) {
                    ctx.strokeStyle = "black";
                    ctx.lineWidth = Math.max(width, height) * 0.1;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.beginPath();
                    ctx.moveTo(width * 0.2, height * 0.5);
                    ctx.lineTo(width * 0.45, height * 0.75);
                    ctx.lineTo(width * 0.8, height * 0.3);
                    ctx.stroke();
                }
            }
        }
    }

    // Timer for auto-clear
    Timer {
        id: clearTimer
        interval: clearInterval
        repeat: false
        onTriggered: {
            if (target && targetPropertyName.length > 0)
                target[targetPropertyName] = false;
            control.checked = false;
        }
    }

    // Ensure indicator is painted on startup
    Component.onCompleted: {
        indicatorCanvas.requestPaint();
    }

    // When user toggles checkbox
    onCheckedChanged: {
        // Update your model property
        if (target && targetPropertyName.length > 0)
            target[targetPropertyName] = control.checked;
        // Repaint indicator
        indicatorCanvas.requestPaint();
        // Optionally start auto-clear
        if (clearAfter && control.checked)
            clearTimer.start();
    }
}
