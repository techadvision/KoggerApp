import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    // The array of double values we can cycle through:
    property var values: [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]

    // Keep track of which index in 'values' is currently selected:
    property int currentIndex: 0

    // Expose the currentValue as a convenient alias (string or double).
    // You can also store it as a real if you prefer:
    property double currentValue: values[currentIndex]

    signal pulsePreferenceValueChanged(double newValue)

    implicitWidth: 280
    implicitHeight: 80

    // On component completion, update the currentIndex to match currentValue if set externally.
    Component.onCompleted: {
        for (var i = 0; i < values.length; i++) {
            if (values[i] === currentValue) {
                currentIndex = i;
                break;
            }
        }
        // Ensure the displayed value is in sync:
        currentValue = values[currentIndex];
    }

    // Whenever currentValue is changed externally, update currentIndex accordingly.
    onCurrentValueChanged: {
        // If the currentValue doesn't match the value at the current index, find its index.
        if (values[currentIndex] !== currentValue) {
            for (var i = 0; i < values.length; i++) {
                if (values[i] === currentValue) {
                    currentIndex = i;
                    break;
                }
            }
        }
    }

    // A simple horizontal row with minus button, displayed value, plus button
    Row {
        spacing: 20
        //anchors.centerIn: parent
        anchors.fill: parent
        width: 300
        height: 80

        Button {
            id: minusButton
            text: "-"
            font.pixelSize: 30
            width: 80
            height: 60
            onClicked: {
                currentIndex = Math.max(currentIndex - 1, 0)
                valueDisplay.text = values[currentIndex]
                pulsePreferenceValueChanged(values[currentIndex])
            }
        }

        Text {
            id: valueDisplay
            text: values[currentIndex]
            font.pixelSize: 30
            width: 80
            height: 80
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Button {
            id: plusButton
            text: "+"
            font.pixelSize: 30
            width: 80
            height: 60
            onClicked: {
                currentIndex = Math.min(currentIndex + 1, values.length - 1)
                valueDisplay.text = values[currentIndex]
                pulsePreferenceValueChanged(values[currentIndex])
            }
        }
    }
}

