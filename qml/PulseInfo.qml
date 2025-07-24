import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Flickable {
    id: root
    focus: true
    width: 900

    // Make the Flickable scrollable vertically
    flickableDirection: Flickable.VerticalFlick
    contentWidth: width
    // Let contentHeight track the total children height
    contentHeight: contentItem.childrenRect.height
    property string gatewayIp: PulseSettings.udpGateway

    // Always‐visible vertical scrollbar
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AlwaysOn
        width: 16
    }

    // ——————————————————————————————————————————————————————————
    // Left side: the app icon (40% of root.width, preserve aspect ratio)
    // ——————————————————————————————————————————————————————————
    Image {
        id: appIcon
        source: (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed ||
                 pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto)
                   ? "./image/PulseRedForApp.jpg"
                   : "./image/PulseBlueForApp.jpg"
        fillMode: Image.PreserveAspectFit

        // Make width = 40% of the Flickable's width
        width: root.width * 0.4
        // Compute height from the image's implicit dimensions to preserve aspect ratio:
        //   height = width × (originalHeight / originalWidth)
        //   implicitHeight and implicitWidth reflect the image's native size.
        height: width * implicitHeight / implicitWidth

        // 10 px margin from top and left of the Flickable
        anchors.top: parent.top
        //anchors.topMargin: 10
        anchors.left: parent.left
        //anchors.leftMargin: 10
    }

    // ——————————————————————————————————————————————————————————
    // Right side: stack everything that used to be in GridLayout.column:1
    // inside a Column. Each child is wrapped in a Rectangle just as an example.
    // ——————————————————————————————————————————————————————————
    Column {
        id: rightColumn
        spacing: 20

        // Anchor the top of this column to the top of appIcon,
        // and place it immediately to the right of appIcon.
        anchors.top: appIcon.top
        anchors.left: appIcon.right
        anchors.leftMargin: 20

        // Make the column take the rest of the Flickable’s width,
        // accounting for the 10px left margin of appIcon + 20px gap + 10px right margin.
        // (You can tweak these margins as needed.)
        width: root.width - appIcon.width - 40

        // ——————————————————————————————
        // 0) App icon
        // ——————————————————————————————
        Rectangle {
            id: appIconRect
            width: parent.width
            height: 135
            color: "transparent"
            radius: 4
            anchors.topMargin: 20

            // Center the text vertically/horizontally within its Rectangle
            Image {
                id: appIconImage
                source: "./image/logo_icon.png"
                height: 125
                width: 125
                fillMode: Image.PreserveAspectFit
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.leftMargin: 5
            }
        }


        // ——————————————————————————————
        // 1) App name and version text
        // ——————————————————————————————
        Rectangle {
            id: appNameRect
            width: parent.width
            height: appNameText.implicitHeight + 10
            color: "transparent"
            radius: 4

            // Center the text vertically/horizontally within its Rectangle
            Text {
                id: appNameText
                text: loadVersion()           // still calls your loadVersion() function
                font.bold: true
                font.pixelSize: 32
                anchors.top: appIconRect.bottom
                anchors.left: parent.left
                anchors.leftMargin: 5
            }
        }

        // ——————————————————————————————
        // 2) Device name text (with Connections to pulseRuntimeSettings.devName changes)
        // ——————————————————————————————
        Rectangle {
            id: deviceNameRect
            width: parent.width
            height: deviceNameText.implicitHeight + 10
            anchors.topMargin: 20
            color: "transparent"
            radius: 4

            Text {
                id: deviceNameText
                text: {
                    if (pulseRuntimeSettings.devName !== "...") {
                        if (pulseRuntimeSettings.pulseBetaName !== "...") {
                            return "Device:\n" + pulseRuntimeSettings.pulseBetaName
                        } else {
                            return "Device:\n" + pulseRuntimeSettings.devName
                        }
                    } else {
                        return "Device:\nNo device connected"
                    }
                }
                font.pixelSize: 32
                anchors.top: appNameRect.bottom
                anchors.left: parent.left
                anchors.leftMargin: 5
            }
        }

        // ——————————————————————————————
        // 3) App IP / Mode text
        // ——————————————————————————————
        Rectangle {
            id: appIpRect
            width: parent.width
            height: appIpText.implicitHeight + 10
            color: "transparent"
            radius: 4

            Text {
                id: appIpText
                text: {
                    if (pulseRuntimeSettings.uuidSuccessfullyOpened === pulseRuntimeSettings.uuidUsbSerial) {
                        return "Pulse Long Range"
                    } else {
                        if (root.gatewayIp) {
                            return "Wi-Fi gateway:\n" + root.gatewayIp
                        } else {
                            return "Wi-Fi:\nNo gateway detected"
                        }
                    }
                }
                font.pixelSize: 32
                anchors.top: deviceNameRect.bottom
                anchors.left: parent.left
                anchors.leftMargin: 5
            }
        }
    }

    // ——————————————————————————————————————————————————————————
    // Your existing function to load version.txt can stay here
    // ——————————————————————————————————————————————————————————
    function loadVersion() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "./version.txt", false);
        xhr.send();
        if (xhr.status === 200) {
            var lines = xhr.responseText.split("\n");
            return lines[0];
        } else {
            console.error("Failed to load version.txt, status:", xhr.status);
            return "unknown";
        }
    }

    Component.onCompleted: {
        var versionString = loadVersion();
        root.gatewayIp = PulseSettings.udpGateway;
    }
}
