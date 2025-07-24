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
    property bool allowLongPressControl: true

    // Custom properties for auto depth behavior
    property bool isAutoRangeActive: false
    // Custom properties for auto filter behavior
    property bool isAutoFilterActive: PulseSettings.autoFilter && (pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseRed || pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseRedProto)

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
                minValue = 1;  // Min depth
                maxValue = pulseRuntimeSettings.maximumDepth
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

    Connections {
        target: pulseRuntimeSettings
        function onUserManualSetNameChanged () {
            console.log("Auto function: onUserManualSetNameCganged triggered for", pulseRuntimeSettings.userManualSetName);
            if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.pulseBlueBeta) {
                if (root.controleName === 'selectorMaxDepth') {
                    // use max range as default
                    let maxRange = pulseRuntimeSettings.maximumDepth * 1.0
                    PulseSettings.maxDepthValuePulseBlue = maxRange
                    PulseSettings.maxDepthValuePulseBlueFixed = maxRange
                    //root.defaultValue = maxRange
                    valueField.text = maxRange
                    console.log("Auto function: horizontal controller setting defaultValue", maxRange);
                    // auto range part
                    PulseSettings.autoRange = false
                    root.isAutoRangeActive = false;
                    root.distanceFixedRangeRequested();
                    console.log("Auto function: horizontal controller setting auto range to", PulseSettings.autoRange);
                }
                if (root.controleName === 'selectorFiltering') {
                    // auto filter part
                    PulseSettings.autoFilter = false
                    root.isAutoFilterActive = false
                    root.filterFixedRangeRequested();
                    console.log("Auto function: horizontal controller setting auto filter to", PulseSettings.autoFilter);
                }
            } else {
                console.log("Auto function: horizontal controller, no change for", pulseRuntimeSettings.userManualSetName, "needed");
            }
        }
        function onIsSideScan2DViewChanged () {
            if (root.controleName !== 'selectorMaxDepth')
                return
            if (pulseRuntimeSettings.is2DTransducer) {
                return
            }
            if (pulseRuntimeSettings.isSideScan2DView) {
                valueField.text = PulseSettings.maxDepthValuePulseBlue
            } else {
                valueField.text = PulseSettings.maxDepthValuePulseBlueFixed
            }
        }
    }

    // Outer oval shape for styling
    Rectangle {
        id: outerShape
        z: 100
        width: parent.width
        height: parent.height
        radius: parent.height / 2 // Oval shape
        color: "#80000000" // Grey background for outer oval
        border.color: "#40ffffff"
        border.width: 1

        RowLayout {
            anchors.centerIn: parent
            spacing: 5

            Image {
                id: controlIcon
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                fillMode: Image.PreserveAspectFit
                source: root.iconSource  // Bind icon source to the external property
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                Layout.leftMargin: 12
            }

            // Minus Button
            Rectangle {
                id: selectorMinusButton
                width: 80
                height: 80
                radius: 30
                color: minusMouseArea.pressed ? "#666666" : "transparent"
                Layout.leftMargin: 4

                Text {
                    anchors.centerIn: parent
                    text: "-"
                    font.pixelSize: 100
                    color: minusMouseArea.pressed ? "#80000000" : "white"
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    id: minusMouseArea
                    onClicked: {
                        longPressControlTimer.stop();
                        if (root.isAutoRangeActive && controleName === "selectorMaxDepth") {
                            //console.log("TAV: Auto range was active, should disable");
                            root.distanceFixedRangeRequested();
                            root.isAutoRangeActive = false;
                        } else {
                            //console.log("TAV: Auto range was not active, just do minus");
                        }
                        if (root.isAutoFilterActive && controleName === "selectorFiltering") {
                            //console.log("TAV: Auto filter was active, should disable");
                            root.filterFixedRangeRequested();
                            root.isAutoFilterActive = false;
                        } else {
                            //console.log("TAV: Auto filterwas not active, just do minus");
                        }

                        let newValue = Math.max(minValue, parseInt(valueField.text) - step);
                        valueField.text = newValue;
                        root.quickChangeMaxRangeValue = newValue;
                        root.selectorValueChanged(newValue);
                    }

                    onPressed: {
                        longPressControlTimer.buttonPressed = 'minus';
                        longPressControlTimer.pressDuration = 0;  // Reset the press duration
                        if (allowLongPressControl) {
                            longPressControlTimer.start();  // Start the shared timer
                        }
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
                                if (pulseRuntimeSettings.devName === "...") {
                                    return
                                }
                                if (pulseRuntimeSettings.pulseBetaName !== "...") {
                                    if (pulseRuntimeSettings.pulseBetaName === pulseRuntimeSettings.pulseBlueBeta){
                                        console.log("TAV: Auto function not allowed for real", pulseRuntimeSettings.devName, "beta name", pulseRuntimeSettings.pulseBlueBeta);
                                        return
                                    }
                                }
                                if (pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseBlue) {
                                    console.log("TAV: Auto function not allowed for", pulseRuntimeSettings.devName);
                                    return
                                }
                                console.log("TAV: Auto function is allowed for", pulseRuntimeSettings.devName);
                                if (controleName==="selectorMaxDepth") {
                                    if (root.isAutoRangeActive) {
                                        //console.log("TAV: Auto range was active, should disable");
                                        root.distanceFixedRangeRequested();
                                        root.isAutoRangeActive = false;
                                    } else {
                                        //console.log("TAV: Auto range was not active, should enable");
                                        root.distanceAutoRangeRequested();
                                        root.isAutoRangeActive = true;
                                    }
                                }
                                if (controleName==="selectorFiltering") {
                                    if (root.isAutoFilterActive) {
                                        //console.log("TAV: Auto filter was active, should disable");
                                        root.filterFixedRangeRequested();
                                        root.isAutoFilterActive = false;
                                    } else {
                                        //console.log("TAV: Auto filter was not active, should enable");
                                        root.filterAutoRangeRequested();
                                        root.isAutoFilterActive = true;
                                    }
                                }
                            }
                        }

                        Component.onCompleted: {
                            if (controleName==="selectorMaxDepth") {
                                root.isAutoRangeActive = PulseSettings.autoRange
                                root.isAutoFilterActive = PulseSettings.autoFilter
                            }
                        }
                    }
                }
            }

            // Plus Button
            Rectangle {
                id: selectorPlusButton
                width: 80
                height: 80
                radius: 30
                color: plusMouseArea.pressed ? "#666666" : "transparent"
                Layout.rightMargin: 4
                //color: "#555555"

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.pixelSize: 80
                    color: plusMouseArea.pressed ? "#80000000" : "white"
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    id: plusMouseArea
                    onClicked: {
                        longPressControlTimer.stop();
                        if (root.isAutoRangeActive && controleName === "selectorMaxDepth") {
                            //console.log("TAV: Auto range was active, should disable");
                            root.distanceFixedRangeRequested();
                            root.isAutoRangeActive = false;
                        } else {
                            //console.log("TAV: Auto range was not active, just do minus");
                        }
                        if (root.isAutoFilterActive && controleName === "selectorFiltering") {
                            //console.log("TAV: Auto filter was active, should disable");
                            root.filterFixedRangeRequested();
                            root.isAutoFilterActive = false;
                        } else {
                            //console.log("TAV: Auto filterwas not active, just do minus");
                        }

                        let newValue = Math.min(root.maxValue, parseInt(valueField.text) + step);
                        console.log("TAV: new plus value is", newValue, "for maxvalue", maxValue, "and root.maxValue", root.maxValue, "for userManualSetName", pulseRuntimeSettings.userManualSetName);
                        valueField.text = newValue;
                        root.quickChangeMaxRangeValue = newValue;
                        root.selectorValueChanged(newValue);
                    }

                    onPressed: {
                        longPressControlTimer.buttonPressed = 'plus';
                        longPressControlTimer.pressDuration = 0;  // Reset the press duration
                        if (allowLongPressControl) {
                            longPressControlTimer.start();  // Start the shared timer
                        }
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
    /*
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
    */

    // Timer to hide the progress bar after 2 seconds
    /*
    Timer {
        id: progressBarTimer
        interval: 2000
        repeat: false
        onTriggered: progressBar.visible = false
    }
    */
}
