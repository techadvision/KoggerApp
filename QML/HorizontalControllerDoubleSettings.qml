import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    property var values: [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
    property int currentIndex: 0

    signal pulsePreferenceValueChanged(double newValue)

    implicitWidth: 280
    implicitHeight: 80

    onCurrentIndexChanged: {
        pulsePreferenceValueChanged(values[currentIndex])
    }

    Row {
        anchors.fill: parent
        width: 300
        height: 80

        Button {
            id: minusButton
            text: "-"
            font.pixelSize: 80
            width: 80
            height: 60
            anchors.top: valueRect.top
            anchors.bottom: valueRect.bottom

            background: Item {
                width: minusButton.width
                height: minusButton.height
                clip: true

                Rectangle {
                    id: leftCap
                    width: height
                    height: parent.height
                    color: minusButton.down ? "#666666" : "#dddddd"
                    radius: height/2
                }

                Rectangle {
                    x: leftCap.width/2
                    width: parent.width - leftCap.width/2
                    height: parent.height
                    color: minusButton.down ? "#666666" : "#dddddd"

                }
            }

            Timer {
                id: minusRepeatTimer
                interval: 200
                repeat: true
                running: false
                onTriggered: {
                    if (currentIndex > 0) {
                        currentIndex--
                        /*
                        valueDisplay.text = values[currentIndex]
                        pulsePreferenceValueChanged(values[currentIndex])
                        */
                    } else {
                        minusRepeatTimer.stop()
                    }
                }
            }

            onPressed: {
                // step immediately
                if (currentIndex > 0) {
                    currentIndex--
                    /*
                    valueDisplay.text = values[currentIndex]
                    pulsePreferenceValueChanged(values[currentIndex])
                    */
                }
                // then start repeating
                minusRepeatTimer.start()
            }
            onReleased:  minusRepeatTimer.stop()
            onCanceled:  minusRepeatTimer.stop()

        }

        Rectangle {
            id: valueRect
            width: 120; height: 60
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.width: 1
            border.color: "#dddddd"

            Text {
                id: valueDisplay
                text: root.values[root.currentIndex]
                font.pixelSize: 30
                anchors.centerIn: parent
            }
        }

        Button {
            id: plusButton
            text: "+"
            font.pixelSize: 60
            width: 80
            height: 60
            anchors.top: valueRect.top
            anchors.bottom: valueRect.bottom

            background: Item {
                width: plusButton.width
                height: plusButton.height
                clip: true

                Rectangle {
                    x: parent.width - parent.height
                    width: parent.height
                    height: parent.height
                    color: plusButton.down ? "#666666" : "#dddddd"
                    radius: parent.height / 2
                }

                Rectangle {
                    width: parent.width - parent.height / 2
                    height: parent.height
                    color: plusButton.down ? "#666666" : "#dddddd"
                    radius: 0
                }
            }

            Timer {
                id: plusRepeatTimer
                interval: 200
                repeat: true
                running: false
                onTriggered: {
                    if (currentIndex < values.length - 1) {
                        currentIndex++
                        /*
                        valueDisplay.text = values[currentIndex]
                        pulsePreferenceValueChanged(values[currentIndex])
                        */
                    } else {
                        plusRepeatTimer.stop()
                    }
                }
            }

            onPressed: {
                if (currentIndex < values.length - 1) {
                    currentIndex++
                    /*
                    valueDisplay.text = values[currentIndex]
                    pulsePreferenceValueChanged(values[currentIndex])
                    */
                }
                plusRepeatTimer.start()
            }
            onReleased:  plusRepeatTimer.stop()
            onCanceled:  plusRepeatTimer.stop()

        }
    }
}

