import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    // Range and step properties
    property double minimum: 0.0
    property double maximum: 10.0
    property double stepSize: 0.01
    property double currentValue: minimum
    // Dynamically compute decimal precision from stepSize
    property int precision: calcPrecision(stepSize)

    signal pulsePreferenceValueChanged(double newValue)

    implicitWidth: 280
    implicitHeight: 80

    // Recompute precision if stepSize changes
    onStepSizeChanged: precision = calcPrecision(stepSize)

    // Notify when the value is changed
    onCurrentValueChanged: pulsePreferenceValueChanged(currentValue)

    Row {
        anchors.fill: parent
        width: 300
        height: 80

        // Minus button
        Button {
            id: minusButton
            text: "-"
            font.pixelSize: 80
            width: 80;
            height: 60
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
            width: 120; height: 60
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.width: 1; border.color: "#dddddd"

            Text {
                anchors.centerIn: parent
                font.pixelSize: 30
                // Format with dynamic precision
                text: root.currentValue.toFixed(root.precision)
            }
        }

        // Plus button
        Button {
            id: plusButton
            text: "+"
            font.pixelSize: 60
            width: 80; height: 60
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
