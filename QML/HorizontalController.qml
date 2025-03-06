import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Item {
    id: root
    width: 280
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
    property string autoFilter: "auto"
    property int autoRangeState: -1

    // Custom properties for auto depth behavior
    property bool isAutoRangeActive: false
    // Custom properties for auto filter behavior
    property bool isAutoFilterActive: false

    signal distanceAutoRangeRequested()
    signal distanceFixedRangeRequested()

    signal filterAutoRangeRequested()
    signal filterFixedRangeRequested()

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
        border.width: 0

        RowLayout {
            anchors.centerIn: parent
            spacing: 5

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
                            console.log("TAV: Auto range was active, should disable");
                            root.distanceFixedRangeRequested();
                            root.isAutoRangeActive = false;
                        } else {
                            console.log("TAV: Auto range was not active, just do minus");
                        }
                        if (root.isAutoFilterActive && controleName === "selectorFiltering") {
                            console.log("TAV: Auto filter was active, should disable");
                            root.filterFixedRangeRequested();
                            root.isAutoFilterActive = false;
                        } else {
                            console.log("TAV: Auto filterwas not active, just do minus");
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
                width: 60
                height: 50
                //radius: 25
                color: "transparent"
                border.color: "transparent"
                border.width: 2

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5

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
                            visible: root.controleName === "selectorIntensity" ? true :
                                     (root.controleName === "selectorMaxDepth" && !root.isAutoRangeActive) ||
                                     (root.controleName === "selectorFiltering" && !root.isAutoFilterActive)
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
                            visible: (root.controleName === "selectorMaxDepth" && root.isAutoRangeActive) ||
                                     (root.controleName === "selectorFiltering" && root.isAutoFilterActive)
                        }


                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (controleName==="selectorMaxDepth") {
                                    if (root.isAutoRangeActive) {
                                        console.log("TAV: Auto range was active, should disable");
                                        root.distanceFixedRangeRequested();
                                        root.isAutoRangeActive = false;
                                    } else {
                                        console.log("TAV: Auto range was not active, should enable");
                                        root.distanceAutoRangeRequested();
                                        root.isAutoRangeActive = true;
                                    }
                                }
                                if (controleName==="selectorFiltering") {
                                    if (root.isAutoFilterActive) {
                                        console.log("TAV: Auto filter was active, should disable");
                                        root.filterFixedRangeRequested();
                                        root.isAutoFilterActive = false;
                                    } else {
                                        console.log("TAV: Auto filter was not active, should enable");
                                        root.filterAutoRangeRequested();
                                        root.isAutoFilterActive = true;
                                    }
                                }
                            }
                        }

                        Component.onCompleted: {
                            if (controleName==="selectorMaxDepth") {
                                root.isAutoRangeActive = PulseSettings.autoRange
                            }
                        }
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
                            console.log("TAV: Auto range was active, should disable");
                            root.distanceFixedRangeRequested();
                            root.isAutoRangeActive = false;
                        } else {
                            console.log("TAV: Auto range was not active, just do minus");
                        }
                        if (root.isAutoFilterActive && controleName === "selectorFiltering") {
                            console.log("TAV: Auto filter was active, should disable");
                            root.filterFixedRangeRequested();
                            root.isAutoFilterActive = false;
                        } else {
                            console.log("TAV: Auto filterwas not active, just do minus");
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
