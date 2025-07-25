import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: settingsPopup
    //modal: true
    focus: true
    width: 900
    height: 400
    anchors.centerIn: parent
    color: "white"
    radius: 8

    signal pulsePreferenceClosed()
    signal pulsePreferenceValueChanged(double newValue)
    property alias checked: checkBoxNmea.checked
    signal stateChanged(bool checked)


    GridLayout {
        id: layout
        anchors.fill: parent
        //anchors.margins: 10
        rowSpacing: 20
        columnSpacing: 20
        columns: 3

        //rows: 5

        // --- Row 1: NMEA DBT - enable
        Text {
            text: "UDP NMEA server"
            font.pixelSize: 30
            height: 80
            GridLayout.row: 0
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
            Layout.topMargin: 20
        }

        CheckBox {
            id: checkBoxNmea
            implicitWidth: 48
            implicitHeight: 48
            GridLayout.row: 0
            GridLayout.column: 2
            Layout.alignment: Qt.AlignVCenter
            anchors.horizontalCenter: depthSelector.horizontalCenter
            // Bind the initial state to PulseSettings.enableNmeaDbt
            checked: PulseSettings.enableNmeaDbt

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
                        if (checkBoxNmea.checked) {
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
                pulseSettings.enableNmeaDbt = checked;
                indicatorCanvas.requestPaint();
            }

        }


        // --- Row 2: NMEA DBT - Select pause between settings
        Text {
            text: "Pause ms between DBT"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 1
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
        }

        HorizontalControllerDoubleSettings {
            id: depthSelector
            values: [250, 500, 1000]
            //currentValue: PulseSettings.nmeaSendPerMilliSec

            Component.onCompleted: {
                var idx = values.indexOf(PulseSettings.nmeaSendPerMilliSec)
                currentIndex = idx >= 0 ? idx : 0
            }

            onPulsePreferenceValueChanged: {
                //console.log("PulseSettingsValue pause between DBT messages changed to", newValue)
                PulseSettings.nmeaSendPerMilliSec = newValue
                //settingsPopup.pulsePreferenceValueChanged(newValue)
            }

            height: 80
            Layout.preferredWidth: 280
            GridLayout.row: 1
            GridLayout.column: 2
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

        // --- Row 3: NMEA DBT - select UDP port
        Text {
            text: "NMEA UDP port"
            font.pixelSize: 30
            GridLayout.row: 2
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
        }

        HorizontalControllerDoubleSettings {
            id: minMeasureSelector
            values: [3000, 3100, 3200, 3300, 3400, 3500]
            //currentValue: PulseSettings.nmeaPort

            Component.onCompleted: {
                var idx = values.indexOf(PulseSettings.nmeaPort)
                currentIndex = idx >= 0 ? idx : 0
            }

            onPulsePreferenceValueChanged: {
                //console.log("PulseSettingsValue NMEA port changed to", newValue)
                PulseSettings.nmeaPort = newValue
                //settingsPopup.pulsePreferenceValueChanged(newValue)
            }

            height: 80
            Layout.preferredWidth: 280
            GridLayout.row: 2
            GridLayout.column: 2
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

        // --- Row 4: NMEA DBT - IP (not selectable)

        Text {
            text: "NMEA IP address"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 3
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
        }

        Text {
            text: "255.255.255.255"
            font.pixelSize: 30
            color: "gray"
            anchors.horizontalCenter: depthSelector.horizontalCenter

            height: 80
            GridLayout.row: 3
            GridLayout.column: 2
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

    }
}

