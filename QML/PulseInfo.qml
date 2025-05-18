import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {

    id: root
    focus: true
    width: 900
    //height: 400
    //anchors.centerIn: parent
    color: "white"
    radius: 8
    implicitWidth:  layout.implicitWidth
    implicitHeight: layout.implicitHeight

    property string gatewayIp: PulseSettings.udpGateway

    // Function to load the version string from a text file
    function loadVersion() {
        var xhr = new XMLHttpRequest();
        // Adjust the path if necessary (e.g., "qrc:/version.txt" if in resources)
        xhr.open("GET", "./version.txt", false); // Synchronous request for simplicity
        xhr.send();
        if (xhr.status === 200) {
            var lines = xhr.responseText.split("\n");
            return lines[0]; // Return the first line as version
        } else {
            console.error("Failed to load version.txt, status:", xhr.status);
            return "unknown";
        }
    }

    Component.onCompleted: {
        var versionString = loadVersion();
        root.gatewayIp = pulseSettings.udpGateway
        //console.log("TAV - App version:", versionString);
        // You can now use versionString in your UI, e.g., assign it to a Text element
    }



    GridLayout {
        id: layout
        rowSpacing: 20
        columnSpacing: 20
        columns: 2

        Image {
            id: appIcon
            source: (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto) ? "./image/PulseRedImage400.png" : "./image/PulseBlueImage400"
            //Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            //Layout.leftMargin: 20
            //Layout.topMargin: 20
            width: 325
            height: 192
            fillMode: Image.PreserveAspectFit

            GridLayout.row: 0
            GridLayout.column: 0
            GridLayout.rowSpan: 4

        }


        Text {
            id: appNameText
            text: "" + loadVersion()  // Replace with your actual app name
            font.bold: true
            font.pixelSize: 24
            GridLayout.row: 0
            GridLayout.column: 1
            Layout.topMargin: 20
        }


        Text {
            id: deviceNameText
            text: "Device: " + pulseRuntimeSettings.devName
            font.pixelSize: 24
            GridLayout.row: 1
            GridLayout.column: 1

            Connections {
                target: pulseRuntimeSettings
                function onDevNameChanged () {
                    text = "Device: " + pulseRuntimeSettings.devName
                }
            }
        }

        Text {
            id: appIpText
            text: pulseRuntimeSettings.uuidSuccessfullyOpened === pulseRuntimeSettings.uuidUsbSerial ?
                      "Pulse Long Range" :
                      "Pulse Wifi, IP=" + root.gatewayIp
            font.pixelSize: 24
            GridLayout.row: 2
            GridLayout.column: 1
        }

        Image {
            id: companyLogo
            source: "./image/logo_techadvision_gray.png"  // Update the path as needed
            anchors.topMargin: 40
            width: 360
            height: 43
            GridLayout.row: 3
            GridLayout.column: 1
        }

        Text {
            id: debugTitleText
            text: "Additional debug information"
            font.pixelSize: 24
            GridLayout.row: 4
            GridLayout.column: 1
        }

        Text {
            id: onDistSetupChangedText
            text: pulseRuntimeSettings.onDistSetupChanged === true ?
                      "Transducer distance config? OK" :
                      "Transducer distance config? Not verified"
            font.pixelSize: 24
            GridLayout.row: 5
            GridLayout.column: 1
        }

        Text {
            id: onChartSetupChangedTest
            text: pulseRuntimeSettings.onChartSetupChanged === true ?
                      "Transducer echogram config? OK" :
                      "Transducer echogram config? Not verified"
            font.pixelSize: 24
            GridLayout.row: 6
            GridLayout.column: 1
        }
        Text {
            id: onDatasetChangedText
            text: pulseRuntimeSettings.onDatasetChanged === true ?
                      "Transducer data config? OK" :
                      "Transducer data config? Not verified"
            font.pixelSize: 24
            GridLayout.row: 7
            GridLayout.column: 1
        }
        Text {
            id: onTransChangedText
            text: pulseRuntimeSettings.onTransChanged === true ?
                      "Transducer base config? OK" :
                      "Transducer base config? Not verified"
            font.pixelSize: 24
            GridLayout.row: 8
            GridLayout.column: 1
        }
        Text {
            id: onSoundChangedText
            text: pulseRuntimeSettings.onSoundChanged === true ?
                      "Transducer speed of sound config? OK" :
                      "Transducer speed of sound config? Not verified"
            font.pixelSize: 24
            GridLayout.row: 9
            GridLayout.column: 1
        }
        Text {
            id: chartEnabledText
            text: pulseRuntimeSettings.datasetChart_ok === true ?
                      "Echogram enabled? Yes" :
                      "Echogram enabled? No"
            font.pixelSize: 24
            GridLayout.row: 10
            GridLayout.column: 1
        }

    }

}


