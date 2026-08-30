import QtQuick 2.15
import QtQuick.Controls 2.15
import Echo.UI 1.0
import QtQuick.Window

// Reusable CheckBox with custom indicator, background and optional auto-clear timer
CheckBox {
    id: control

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real platformScale: _isAndroid ? 0.9 : 0.75
    //readonly property real s: Ui.scale * platformScale
    readonly property real shortSide: Math.min(Screen.width, Screen.height)
    readonly property real s: Math.max(1.0, shortSide / 1100) // tune 800 to your “10-inch baseline”

    implicitWidth: Ui.iconTouch //Math.round(54 * s) //_isAndroid ? 54 : 32
    implicitHeight: Ui.iconTouch //Math.round(54 * s) //_isAndroid ? 54 : 32

    // Bind this to your model or initial state
    property bool initialChecked: false
    // Target object and property name to update on change
    property var target
    property string targetPropertyName: ""

    // Auto-clear behavior: if true, will reset after `clearInterval` ms when checked
    property bool clearAfter: false
    property int clearInterval: 2000

    // PULSE: write the target property ONLY on real user interaction.
    //
    // The historic behaviour (false) writes the target back on ANY change to `checked`,
    // including one that arrived through the `initialChecked` binding. For a plain
    // storage property that is harmless. For a property that is itself BOUND — e.g. one
    // of the per-device profile values — it is fatal: the first programmatic change
    // (a device being identified) round-trips through this write-back and permanently
    // destroys the binding, so the value never follows the device again.
    //
    // Default stays false so every existing checkbox behaves exactly as before; the
    // profile-driven rows opt in.
    property bool writeBackOnUserActionOnly: false

    // Initialize checked state
    checked: initialChecked

    // Custom white background with subtle border
    background: Rectangle {
        anchors.fill: parent
        anchors.left: parent.left
        color: "white"
        radius: 4
        border.width: 1
        border.color: "black"
    }

    // Custom large check indicator
    indicator: Item {
        anchors.fill: parent
        anchors.left: parent.left
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

    // Real user interaction only (CheckBox emits toggled() on click, never on a
    // programmatic or binding-driven change of `checked`).
    onToggled: {
        if (writeBackOnUserActionOnly && target && targetPropertyName.length > 0)
            target[targetPropertyName] = control.checked;
    }

    // When user toggles checkbox
    onCheckedChanged: {
        // Update your model property
        if (!writeBackOnUserActionOnly && target && targetPropertyName.length > 0)
            target[targetPropertyName] = control.checked;
        // Repaint indicator
        indicatorCanvas.requestPaint();
        // Optionally start auto-clear
        if (clearAfter && control.checked)
            clearTimer.start();
    }
}
