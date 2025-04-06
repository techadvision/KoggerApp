import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {

    id: root
    focus: true
    width: 900
    height: 400
    anchors.centerIn: parent
    color: "white"
    radius: 8

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
        console.log("TAV - App version:", versionString);
        // You can now use versionString in your UI, e.g., assign it to a Text element
    }



    GridLayout {
        id: layout
        rowSpacing: 20
        columnSpacing: 20
        columns: 2

        Image {
            id: appIcon
            source: pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseRed ? "./image/PulseRedImage400.png" : "./image/PulseBlueImage400"
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
            Layout.topMargin: 20
            width: 325
            height: 192
            fillMode: Image.PreserveAspectFit

            GridLayout.row: 0
            GridLayout.column: 0
            GridLayout.rowSpan: 3

        }

        Text {
            id: appNameText
            text: "Pulse app version" + "\n" + loadVersion()  // Replace with your actual app name
            font.bold: true
            font.pixelSize: 24
            GridLayout.row: 0
            GridLayout.column: 1
            Layout.topMargin: 20
        }


        Text {
            id: appIpText
            text: pulseRuntimeSettings.uuidSuccessfullyOpened === pulseRuntimeSettings.uuidUsbSerial ?
                      "Pulse Long Range" :
                      "Pulse IP:" + "\n" + root.gatewayIp
            font.pixelSize: 24
            GridLayout.row: 1
            GridLayout.column: 1
        }

        Image {
            id: companyLogo
            source: "./image/logo_techadvision_gray.png"  // Update the path as needed
            anchors.topMargin: 40
            width: 360
            height: 43
            GridLayout.row: 2
            GridLayout.column: 1
        }

        /*
        Rectangle {
            id: appInfoRow
            GridLayout.row: 1
            GridLayout.column: 1

            Text {
                id: appNameText
                text: "Pulse app version" + "\n" + loadVersion()  // Replace with your actual app name
                anchors.centerIn: parent
                font.bold: true
                font.pixelSize: 24
            }
        }

        Rectangle {
            id: ipAddressRow
            GridLayout.row: 2
            GridLayout.column: 1

            Text {
                text: pulseRuntimeSettings.uuidSuccessfullyOpened === pulseRuntimeSettings.uuidUsbSerial ?
                          "Pulse Long Range" :
                          "Pulse IP:" + "\n" + root.gatewayIp
                anchors.centerIn: parent
                font.pixelSize: 24
            }

        }


    }

    /*
    Image {
        id: appIcon
        source: pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseRed ? "./image/PulseRedImage400.png" : "./image/PulseBlueImage400"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        width: 325
        height: 192
        fillMode: Image.PreserveAspectFit
    }
    */

    /*
    Image {
        id: companyLogo
        source: "./image/logo_techadvision_gray.png"  // Update the path as needed
        anchors.top: appIcon.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 10
        width: 360
        height: 43
    }
    */

    /*
    Rectangle {
        id: appInfoRow
        anchors.horizontalCenter: root.horizontalCenter
        anchors.top: companyLogo.bottom
        anchors.margins: 35

        Text {
            id: appNameText
            text: "Pulse app version " + loadVersion()  // Replace with your actual app name
            anchors.centerIn: parent
            font.bold: true
            font.pixelSize: 24
        }
    }

    Rectangle {
        id: ipAddressRow
        anchors.horizontalCenter: root.horizontalCenter
        anchors.top: appInfoRow.bottom
        anchors.topMargin: 35

        Text {
            text: pulseRuntimeSettings.uuidSuccessfullyOpened === pulseRuntimeSettings.uuidUsbSerial ?
                      "Pulse Long Range" :
                      "Pulse IP: " + root.gatewayIp
            anchors.centerIn: parent
            font.pixelSize: 24
        }

    }
    */

}
}

