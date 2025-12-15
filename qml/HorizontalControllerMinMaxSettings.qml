import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Echo.UI 1.0

Item {
    id: root


    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real platformScale: _isAndroid ? 0.9 : 0.75
    readonly property real s: Ui.scale * platformScale

    // Platform related sizes
    property int pressButtonSize: Math.round(54 * s)
    property int displayPixels:   Math.round(80 * s)
    property int valueTextWidth:  Math.round(120 * s)
    property int valuePixels:     Math.round(30 * s)
    /*
    property int pressButtonSize: _isAndroid ? 54 : 32
    property int displayPixels:   _isAndroid ? 80 : 40
    property int valueTextWidth:  _isAndroid ? 120 : 80
    property int valuePixels:     _isAndroid ? 30 : 22
    */

    // Range and step properties
    property double minimum: 0.0
    property double maximum: 10.0
    property double stepSize: 0.01
    property double currentValue: minimum
    // Dynamically compute decimal precision from stepSize
    property int precision: calcPrecision(stepSize)

    signal pulsePreferenceValueChanged(double newValue)

    implicitWidth: Math.round(280 * s) //_isAndroid ? 280 : 180
    implicitHeight: Math.round(54 * s) //_isAndroid? 54 : 32
    //implicitHeight: _isAndroid? 80 : 54

    // Recompute precision if stepSize changes
    onStepSizeChanged: precision = calcPrecision(stepSize)

    // Notify when the value is changed
    onCurrentValueChanged: pulsePreferenceValueChanged(currentValue)

    Row {
        //anchors.fill: parent
        anchors.left: parent.left
        width: parent.width
        height: parent.height

        //height: root._isAndroid ? 80 : 54

        // Minus button
        Button {
            id: minusButton
            text: "-"
            font.pixelSize: root.displayPixels
            width: root.pressButtonSize
            height: root.pressButtonSize
            anchors.top: valueRect.top;
            anchors.bottom: valueRect.bottom

            background: Item {
                width: parent.width;
                height: parent.height;
                clip: true
                Rectangle {
                    width: height;
                    height: parent.height;
                    color: minusButton.down ? "#666666" : "#dddddd";
                    radius: height/2 }
                Rectangle {
                    x: height/2;
                    width: parent.width - height/2;
                    height: parent.height;
                    color: minusButton.down ? "#666666" : "#dddddd" }
            }

            Timer {
                id: minusRepeatTimer;
                interval: 200;
                repeat: true;
                running: false;
                onTriggered: adjust(-stepSize)
            }
            onPressed: { adjust(-stepSize); minusRepeatTimer.start() }
            onReleased: minusRepeatTimer.stop()
            onCanceled: minusRepeatTimer.stop()
        }

        // Display
        Rectangle {
            id: valueRect
            width: root.valueTextWidth
            height: root.pressButtonSize
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.width: 1; border.color: "#dddddd"

            Text {
                anchors.centerIn: parent
                font.pixelSize: root.valuePixels
                // Format with dynamic precision
                text: root.currentValue.toFixed(root.precision)
            }
        }

        // Plus button
        Button {
            id: plusButton
            text: "+"
            font.pixelSize: root.displayPixels
            width: root.pressButtonSize
            height: root.pressButtonSize
            anchors.top: valueRect.top; anchors.bottom: valueRect.bottom

            background: Item {
                width: parent.width;
                height: parent.height;
                clip: true
                Rectangle {
                    x: parent.width - parent.height;
                    width: parent.height;
                    height: parent.height;
                    color: plusButton.down ? "#666666" : "#dddddd";
                    radius: height/2 }
                Rectangle {
                    width: parent.width - height/2;
                    height: parent.height;
                    color: plusButton.down ? "#666666" : "#dddddd" }
            }

            Timer {
                id: plusRepeatTimer;
                interval: 300;
                repeat: true;
                running: false;
                onTriggered: adjust(stepSize)
            }
            onPressed: { adjust(stepSize); plusRepeatTimer.start() }
            onReleased: plusRepeatTimer.stop()
            onCanceled: plusRepeatTimer.stop()
        }
    }

    // Adjust and clamp
    function adjust(delta) {
        var newVal = currentValue + delta;
        newVal = Math.max(minimum, Math.min(newVal, maximum));
        // Round to precision to avoid floating errors
        var factor = Math.pow(10, precision);
        newVal = Math.round(newVal * factor) / factor;
        if (newVal !== currentValue) currentValue = newVal;
    }

    // Helper to determine decimal places from stepSize
    function calcPrecision(size) {
        var s = size.toString();
        if (s.indexOf('.') >= 0) return s.split('.')[1].length;
        return 0;
    }
}
