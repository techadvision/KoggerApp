import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Item {
    id: root
    width: 310
    height: 80 // Oval height
    property alias value: valueField.text
    property int minValue: 0
    property int maxValue: 100
    property int step: 1
    property int defaultValue: 0
    property int progressBarHeight: 5 // Height for the progress bar
    property string iconSource: ""
    property string controleName: ""
    property string autoDepth: "auto"
    property int autoRangeState: -1

    // Custom properties for max depth behavior
    property bool isAutoRangeActive: false

    signal distanceAutoRangeRequested()
    signal distanceFixedRangeRequested()
    signal selectorValueChanged(int newValue)

    property real quickChangeMaxRangeValue: root.defaultValue  // Sync this with default value


    Timer {
        id: longPressControlTimer
        interval: 200
        repeat: true

        property real pressDuration: 0
        property string buttonPressed: "plus"

        onTriggered: {
            pressDuration += interval;
            let currentStep = (pressDuration >= 3000) ? step * 2 : step;  // Double speed after 3 seconds

            let minValue, maxValue;
            if (root.controleName === 'selectorMaxDepth') {
                minValue = 2;  // Min depth
                maxValue = 100; // Max depth
            } else if (root.controleName === 'selectorIntensity') {
                minValue = 0;  // Min value for illumination
                maxValue = 20; // Max value for illumination
            } else if (root.controleName === 'selectorFiltering') {
                minValue = 0;  // Min value for filter
                maxValue = 20; // Max value for filter
            }

            let newValue;
            if (buttonPressed === 'minus') {
                newValue = Math.max(minValue, parseInt(valueField.text) - currentStep);

            } else if (buttonPressed === 'plus') {
                newValue = Math.min(maxValue, parseInt(valueField.text) + currentStep);

            }
            if (newValue < 0) {
                newValue = minValue
            }
            if (newValue > maxValue) {
                newValue = maxValue
            }

            valueField.text = newValue;
            root.quickChangeMaxRangeValue = newValue;
            root.selectorValueChanged(newValue);
        }
    }

    // Outer oval shape for styling
    Rectangle {
        id: outerShape
        width: parent.width
        height: parent.height
        radius: parent.height / 2 // Oval shape
        color: "#80000000" // Grey background for outer oval
        border.color: "transparent"
        border.width: 2

        RowLayout {
            anchors.centerIn: parent
            spacing: 10

            Image {
                id: controlIcon
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                fillMode: Image.PreserveAspectFit
                source: root.iconSource  // Bind icon source to the external property
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                Layout.leftMargin: 12
            }

            // Minus Button
            Rectangle {
                id: selectorMinusButton
                width: 64
                height: 64
                radius: 20
                color: "transparent"
                Layout.leftMargin: 4

                Text {
                    anchors.centerIn: parent
                    text: "-"
                    font.pixelSize: 64
                    color: "white"
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        longPressControlTimer.stop();
                        if (root.isAutoRangeActive && controleName === "selectorMaxDepth") {
                            console.log("TAV: Auto was active, should disable");
                            root.distanceFixedRangeRequested();
                            root.isAutoRangeActive = false;
                        } else {
                            console.log("TAV: Auto was not active, just do minus");
                        }

                        let newValue = Math.max(minValue, parseInt(valueField.text) - step);
                        valueField.text = newValue;
                        root.quickChangeMaxRangeValue = newValue;
                        root.selectorValueChanged(newValue);
                    }

                    onPressed: {
                        longPressControlTimer.buttonPressed = 'minus';
                        longPressControlTimer.pressDuration = 0;  // Reset the press duration
                        longPressControlTimer.start();  // Start the shared timer
                    }

                    onReleased: {
                        longPressControlTimer.stop();
                        longPressControlTimer.pressDuration = 0;
                        longPressControlTimer.buttonPressed = '';
                    }
                }
            }

            // Value Display with Icon and Vertical Dividers
            Rectangle {
                id: valueFieldBackground
                width: 100
                height: 50
                //radius: 25
                color: "transparent"
                border.color: "transparent"
                border.width: 2

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5

                    // Divider on the left
                    Rectangle {
                        width: 4
                        height: parent.height * 0.8
                        color: "white"
                    }

                    // Value Display
                    Rectangle {
                        id: valueFieldRectangle
                        width: 60
                        height: 40
                        radius: 20
                        color: "transparent"

                        Text {
                            id: valueField
                            anchors.centerIn: parent
                            text: root.defaultValue
                            font.pixelSize: 42
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            onTextChanged: root.selectorValueChanged(parseInt(valueField.text))
                            visible: !root.isAutoRangeActive
                        }

                        Text {
                            id: valueFieldAuto
                            anchors.centerIn: parent
                            text: root.autoDepth
                            font.pixelSize: 32
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            onTextChanged: root.selectorValueChanged(parseInt(valueField.text))
                            visible: root.isAutoRangeActive
                        }


                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (controleName==="selectorMaxDepth") {
                                    if (root.isAutoRangeActive) {
                                        console.log("TAV: Auto was active, should disable");
                                        root.distanceFixedRangeRequested();
                                        root.isAutoRangeActive = false;
                                    } else {
                                        console.log("TAV: Auto was not active, should enable");
                                        root.distanceAutoRangeRequested();
                                        root.isAutoRangeActive = true;
                                    }
                                }
                            }
                        }

                        Component.onCompleted: {
                            if (controleName==="selectorMaxDepth") {
                                root.isAutoRangeActive = pulseSettings.autoRange
                            }
                        }
                    }

                    // Divider on the right
                    Rectangle {
                        width: 2
                        height: parent.height * 0.6
                        color: "white"
                    }
                }
            }

            // Plus Button
            Rectangle {
                id: selectorPlusButton
                width: 64
                height: 64
                radius: 20
                color: "transparent"
                Layout.rightMargin: 4
                //color: "#555555"

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.pixelSize: 64
                    color: "white"
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        longPressControlTimer.stop();
                        if (root.isAutoRangeActive && controleName === "selectorMaxDepth") {
                            console.log("TAV: Auto was active, should send -1 to disable");
                            root.distanceFixedRangeRequested();
                            root.isAutoRangeActive = false;
                        } else {
                            console.log("TAV: Auto was not active, just do plus");
                        }

                        let newValue = Math.min(maxValue, parseInt(valueField.text) + step);
                        valueField.text = newValue;
                        root.quickChangeMaxRangeValue = newValue;
                        root.selectorValueChanged(newValue);
                    }

                    onPressed: {
                        longPressControlTimer.buttonPressed = 'plus';
                        longPressControlTimer.pressDuration = 0;  // Reset the press duration
                        longPressControlTimer.start();  // Start the shared timer;
                    }

                    onReleased: {
                        longPressControlTimer.stop();  // Stop the timer when the button is released
                        longPressControlTimer.pressDuration = 0;
                        longPressControlTimer.buttonPressed = '';
                    }
                }

            }
        }
    }

    // Progress Bar
    Rectangle {
        id: progressBar
        width: parent.width - 20
        height: root.progressBarHeight
        radius: progressBarHeight / 2
        color: "#FF5722"
        anchors.bottom: outerShape.top
        anchors.bottomMargin: 10
        visible: false

        // Filling the progress bar based on the value
        Rectangle {
            width: progressBar.width * (parseInt(valueField.text) / 100)
            height: progressBar.height
            color: "#4CAF50"
        }
    }

    // Timer to hide the progress bar after 2 seconds
    Timer {
        id: progressBarTimer
        interval: 2000
        repeat: false
        onTriggered: progressBar.visible = false
    }
}
