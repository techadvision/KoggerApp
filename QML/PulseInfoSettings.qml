import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: settingsPopup
    focus: true
    width: 900
    //height: 950
    //anchors.centerIn: parent
    color: "white"
    radius: 8
    implicitWidth:  layout.implicitWidth
    implicitHeight: layout.implicitHeight

    signal pulsePreferenceClosed()
    signal pulsePreferenceValueChanged(double newValue)
    property alias checked: checkBoxLeftHandBlue.checked
    signal stateChanged(bool checked)


    GridLayout {
        id: layout
        //anchors.fill: parent
        //anchors.margins: 10
        rowSpacing: 20
        columnSpacing: 20
        columns: 3

        //rows: 5

        // --- Row 0: Pulse Blue - installed left hand side? - enable
        Text {
            text: "Pulse Blue installed left side"
            font.pixelSize: 30
            height: 80
            GridLayout.row: 0
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
            Layout.topMargin: 30
        }

        CheckBox {
            id: checkBoxLeftHandBlue
            implicitWidth: 48
            implicitHeight: 48
            GridLayout.row: 0
            GridLayout.column: 2
            Layout.alignment: Qt.AlignVCenter
            anchors.horizontalCenter: speedSelector.horizontalCenter
            checked: PulseSettings.isSideScanOnLeftHandSide

            // Custom white background with a subtle border
            background: Rectangle {
                anchors.fill: parent
                color: "white"
                radius: 4
                border.width: 1
                border.color: "black"
            }

            // Override the indicator to draw a larger check mark
            indicator: Item {
                id: indicatorItem
                anchors.fill: parent

                Canvas {
                    id: indicatorCanvas
                    anchors.fill: parent
                    // Removed renderPolicy as it's not supported in your version

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        if (checkBoxLeftHandBlue.checked) {
                            // Set stroke style relative to the size
                            ctx.strokeStyle = "black"; // or change to "#333333" for dark grey
                            ctx.lineWidth = Math.max(width, height) * 0.1;
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";
                            ctx.beginPath();
                            // Draw a check mark that fills a good portion of the area
                            ctx.moveTo(width * 0.2, height * 0.5);
                            ctx.lineTo(width * 0.45, height * 0.75);
                            ctx.lineTo(width * 0.8, height * 0.3);
                            ctx.stroke();
                        }
                    }
                }
            }

            Component.onCompleted: {
                indicatorCanvas.requestPaint()
            }

            onCheckedChanged: {
                pulseSettings.isSideScanOnLeftHandSide = checked;
                indicatorCanvas.requestPaint();
            }

        }

        // --- Row 1: Echogram scroll speed (widens the picture horizontally)
        Text {
            text: "Echogram screen speed"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 1
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
        }

        HorizontalControllerDoubleSettings {
            id: speedSelector
            height: 80
            Layout.preferredWidth: 280
            GridLayout.row: 1
            GridLayout.column: 2
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            values: [1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9,
                2.0, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9,
                3.0, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9,
                4.0, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 5.0]

            //currentValue: pulseRuntimeSettings.echogramSpeed

            Component.onCompleted: {
                var idx = values.indexOf(pulseRuntimeSettings.echogramSpeed)
                //console.log("PulseSettingsValue speedSelector Component.onCompleted idx calculated to ", idx)
                currentIndex = idx >= 0 ? idx : 0
            }

            onPulsePreferenceValueChanged: {
                //console.log("PulseSettingsValue speedSelector changed to", newValue)
                pulseRuntimeSettings.echogramSpeed = newValue
            }

            Connections {
                target: pulseRuntimeSettings
                function onEchogramSpeedChanged () {
                    var idx = speedSelector.values.indexOf(pulseRuntimeSettings.echogramSpeed)
                    if (idx >= 0) speedSelector.currentIndex = idx
                }
            }
        }

        // --- Row 2: UDP port solution
        Text {
            text: "UDP port selection"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 2
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
        }

        HorizontalControllerDoubleSettings {
            id: udpPortSelection
            values: [14550, 14560]
            //currentValue: PulseSettings.udpPort
            onPulsePreferenceValueChanged: PulseSettings.udpPort = newValue
            height: 80
            Layout.preferredWidth: 280
            GridLayout.row: 2
            GridLayout.column: 2
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

            Component.onCompleted: {
                var idx = values.indexOf(PulseSettings.udpPort)
                currentIndex = idx >= 0 ? idx : 0
            }
        }

        // --- Row 3: Black stripes removal solution
        Text {
            text: "Black stripes removal size"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 3
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
        }

        HorizontalControllerDoubleSettings {
            id: blackStripesSize
            values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 25, 25, 26, 27, 28, 29, 30]
            //currentValue: pulseRuntimeSettings.fixBlackStripesForwardSteps

            Component.onCompleted: {
                var idx = values.indexOf(pulseRuntimeSettings.fixBlackStripesForwardSteps)
                currentIndex = idx >= 0 ? idx : 0
            }

            onPulsePreferenceValueChanged: {
                pulseRuntimeSettings.fixBlackStripesForwardSteps  = newValue
                pulseRuntimeSettings.fixBlackStripesBackwardSteps = newValue
                core.fixBlackStripesForwardSteps  = newValue
                core.fixBlackStripesBackwardSteps = newValue
            }

            height: 80
            Layout.preferredWidth: 280
            GridLayout.row: 3
            GridLayout.column: 2
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }



        // --- Row 4: Depth filter adjustment: kSmallAgreeMargin

        Text {
            text: "Depth filter: fluctuation margin (m)"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 4
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
        }

        HorizontalControllerDoubleSettings {
            id: kSmallAgreeMargin
            values: [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]
            //currentValue: pulseRuntimeSettings.kSmallAgreeMargin

            Component.onCompleted: {
                var idx = values.indexOf(pulseRuntimeSettings.kSmallAgreeMargin)
                currentIndex = idx >= 0 ? idx : 0
            }

            onPulsePreferenceValueChanged: {
                //console.log("WOW changed kSmallAgreeMargin to ", newValue)
                pulseRuntimeSettings.kSmallAgreeMargin = newValue
            }

            height: 80
            Layout.preferredWidth: 280
            GridLayout.row: 4
            GridLayout.column: 2
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

        // --- Row 5: Depth filter adjustment: kLargeJumpThreshold
        Text {
            text: "Depth filter: suspicious jump (m)"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 5
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
        }

        HorizontalControllerDoubleSettings {
            id: kLargeJumpThreshold
            values: [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]
            //currentValue: pulseRuntimeSettings.kLargeJumpThreshold

            Component.onCompleted: {
                var idx = values.indexOf(pulseRuntimeSettings.kLargeJumpThreshold)
                currentIndex = idx >= 0 ? idx : 0
            }

            onPulsePreferenceValueChanged: {
                //console.log("WOW changed kLargeJumpThreshold to ", newValue)
                pulseRuntimeSettings.kLargeJumpThreshold = newValue
            }

            height: 80
            Layout.preferredWidth: 280
            GridLayout.row: 5
            GridLayout.column: 2
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

        // --- Row 6: Depth filter adjustment: kConsistNeeded
        Text {
            text: "Depth filter: accept jump min. records"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 6
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
        }

        HorizontalControllerDoubleSettings {
            id: kConsistNeeded
            values: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
            //currentValue: pulseRuntimeSettings.kConsistNeeded

            Component.onCompleted: {
                var idx = values.indexOf(pulseRuntimeSettings.kConsistNeeded)
                currentIndex = idx >= 0 ? idx : 0
            }

            onPulsePreferenceValueChanged: {
                //console.log("WOW changed kConsistNeeded to ", newValue)
                pulseRuntimeSettings.kConsistNeeded = newValue
            }

            height: 80
            Layout.preferredWidth: 280
            GridLayout.row: 6
            GridLayout.column: 2
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

        // --- Row 5: Depth reporting solution
        /*
        Text {
            text: "Depth reporting solution"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 5
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
        }

        HorizontalControllerDoubleSettings {
            id: depthReportingSolution
            values: [-1, 0, 1, 2]
            currentValue: {
                if (pulseRuntimeSettings.datasetDist === 0
                    && pulseRuntimeSettings.datasetSDDBT === 0) {
                    return 0
                }
                else if (pulseRuntimeSettings.datasetDist === 1) {
                    return 1
                }
                else {
                    return 2
                }
            }
            onPulsePreferenceValueChanged: {
                //console.log("WOW changed depthReportingSolution to ", newValue)
                if (newValue === 0) {
                    pulseRuntimeSettings.datasetDist = 0
                    pulseRuntimeSettings.datasetSDDBT = 0
                } else if (newValue === 1) {
                    pulseRuntimeSettings.datasetDist = 1
                } else {
                    pulseRuntimeSettings.datasetSDDBT = 1
                }

                pulseRuntimeSettings.currentDepthSolution = newValue
            }

            height: 80
            Layout.preferredWidth: 280
            GridLayout.row: 5
            GridLayout.column: 2
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }
        */
    }
}
