import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Echo.UI 1.0
import QtQuick.Window

Item {
    id: root

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real platformScale: _isAndroid ? 0.9 : 0.75
    //readonly property real s: Ui.scale * platformScale
    readonly property real shortSide: Math.min(Screen.width, Screen.height)
    readonly property real s: Math.max(1.0, shortSide / 1200) // tune 800 to your “10-inch baseline”

    // Platform related sizes
    property int pressButtonSize: Math.round(56 * s)
    property int displayPixels:   Math.round(50 * s)
    property int valueTextWidth:  Math.round(150 * s)
    property int valuePixels:     Math.round(42 * s)

    /*
    property int pressButtonSize: _isAndroid ? 54 : 32
    property int displayPixels:   _isAndroid ? 80 : 40
    property int valueTextWidth:  _isAndroid ? 120 : 80
    property int valuePixels:     _isAndroid ? 30 : 22
    */


    property var values: [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
    property int currentIndex: 0
    property bool thisControllerWasTapped: false

    signal pulsePreferenceValueChanged(double newValue)

    implicitWidth: Math.round(100 * s) //_isAndroid ? 280 : 180
    implicitHeight: Math.round(54 * s) //_isAndroid ? 54 : 32
    //implicitHeight: _isAndroid ? 80 : 54

    onCurrentIndexChanged: {
        pulsePreferenceValueChanged(values[currentIndex])
    }

    Timer {
        id: resetTappedStatusTimer
        interval: 200
        repeat: false
        running: false
        onTriggered: {
            thisControllerWasTapped = false
        }
    }


    Row {
        anchors.fill: parent
        width: parent.width
        height: parent.height
        //width: root._isAndroid ? 300 : 200
        //height: root._isAndroid ? 80 : 54

        Button {
            id: minusButton
            text: "-"
            font.pixelSize: root.displayPixels
            width: root.pressButtonSize
            height: root.pressButtonSize
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
                // set tapped state
                thisControllerWasTapped = true
                resetTappedStatusTimer.start()
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
            width: root.valueTextWidth
            height: root.pressButtonSize
            //width: 120
            //height: 60
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.width: 1
            border.color: "#dddddd"

            Text {
                id: valueDisplay
                text: root.values[root.currentIndex]
                font.pixelSize: Ui.fontXL //root.valuePixels
                anchors.centerIn: parent
            }
        }

        Button {
            id: plusButton
            text: "+"
            font.pixelSize: root.displayPixels
            width: root.pressButtonSize
            height: root.pressButtonSize
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

