    import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Flickable {
    id: root

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    // Platform related sizes
    property int controlIconSize: _isAndroid ? 34 : 20
    property int pressButtonSize: _isAndroid ? 80 : 40
    property int displayPixels:   _isAndroid ? 100 : 40
    property int valueTextWidth:  _isAndroid ? 60 : 40
    property int valueTextHeigh:  _isAndroid ? 40 : 30
    property int valuePixels:     _isAndroid ? 42 : 32
    property int autoPixels:      _isAndroid ? 32 : 24
    property int selectIconSize:  _isAndroid ? 80 : 60
    property int selectCheckSize: _isAndroid ? 56 : 40
    property int infoPixelsSize:  _isAndroid ? 32 : 22

    focus: true
    width: _isAndroid ? 900 : 600


    // Make the Flickable scrollable vertically
    flickableDirection: Flickable.VerticalFlick
    contentWidth: width
    // Let contentHeight track the total children height
    contentHeight: contentItem.childrenRect.height
    property string gatewayIp: pulseSettings.udpGateway

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
                   ? "./image/pulse_info_red_black_large.png"
                   : "./image/pulse_info_blue_large.png"
        fillMode: Image.PreserveAspectFit

        // Make width = 40% of the Flickable's width
        width: root.width * 0.4
        height: width * implicitHeight / implicitWidth

        // 10 px margin from top and left of the Flickable
        //anchors.top: parent.top
        anchors.left: parent.left
        anchors.verticalCenter: deviceLogo.verticalCenter
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
            height: _isAndroid ? 135 : 90
            color: "transparent"
            radius: 4
            anchors.topMargin: 20

            // Center the text vertically/horizontally within its Rectangle
            Image {
                id: appIconImage
                source: "./image/logo_icon.png"
                height: _isAndroid ? 125 : 80
                width: _isAndroid ? 125 : 80
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
                font.pixelSize: root.infoPixelsSize
                anchors.top: appIconRect.bottom
                anchors.left: parent.left
                anchors.leftMargin: 5
            }
        }

        // ——————————————————————————————
        // 2) Device name text (with Connections to pulseRuntimeSettings.devName changes)
        // ——————————————————————————————
        // ——————————————————————————————
        // 2) Device logo (and beta badge) or "No device" text
        // ——————————————————————————————
        Rectangle {
            id: deviceNameRect
            width: parent.width
            // Auto-size to content
            height: Math.max(
                        deviceContent.visible ? deviceContent.implicitHeight : 0,
                        noDeviceText.visible ? noDeviceText.implicitHeight : 0
                    ) + 10
            anchors.topMargin: 20
            color: "transparent"
            radius: 4

            // "No device" fallback
            Text {
                id: noDeviceText
                //visible: pulseRuntimeSettings.devName === "..."
                text: {
                    if (pulseRuntimeSettings.devName === "...")
                        return "Device:\nNo device connected"
                    return "Connected to:"
                }
                font.pixelSize: root.infoPixelsSize
                anchors.top: appNameRect.bottom
                anchors.left: parent.left
                anchors.leftMargin: 5
            }

            // Device logo + optional beta badge
            Row {
                id: deviceContent
                visible: pulseRuntimeSettings.devName !== "..."
                spacing: 8
                anchors.top: noDeviceText.bottom
                anchors.left: parent.left
                anchors.leftMargin: 5

                // Transducer logo (red/blue)
                Image {
                    id: deviceLogo
                    source: {
                        // If it's a beta, decide by exact beta name
                        if (pulseRuntimeSettings.pulseBetaName !== "...") {
                            if (pulseRuntimeSettings.pulseBetaName === pulseRuntimeSettings.pulseRedBeta)
                                return "./image/pulse_logo_red.png";
                            if (pulseRuntimeSettings.pulseBetaName === pulseRuntimeSettings.pulseBlueBeta)
                                return "./image/pulse_logo_blue.png";
                            // Unknown beta type -> default to blue
                            return "./image/pulse_logo_blue.png";
                        }

                        // Non-beta: fall back to userManualSetName (same logic as your app icon)
                        var isRed = (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed
                                     || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto);
                        return isRed ? "./image/pulse_logo_red.png" : "./image/pulse_logo_blue.png";
                    }
                    fillMode: Image.PreserveAspectFit
                    // Good, platform-aware size you already use
                    //height: root.selectIconSize
                    width: 265
                }

                Image {
                    id: deviceLogoBlack
                    visible: pulseRuntimeSettings.pulseBetaName === pulseRuntimeSettings.pulseRedBeta
                    source: "./image/pulse_logo_black.png"
                    anchors.verticalCenter: deviceLogo.verticalCenter
                    fillMode: Image.PreserveAspectFit
                    width: 300
                }

                // Beta badge (only when beta)
                Image {
                    id: betaBadge
                    visible: pulseRuntimeSettings.pulseBetaName !== "..."
                    source: "./icons/ui/pulse_beta_feature.svg"
                    fillMode: Image.PreserveAspectFit
                    // Size relative to the logo so it looks balanced
                    height: deviceLogo.height
                    //width: height
                    anchors.verticalCenter: deviceLogo.verticalCenter
                }
            }
        }


        /*
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
                font.pixelSize: root.infoPixelsSize
                anchors.top: appNameRect.bottom
                anchors.left: parent.left
                anchors.leftMargin: 5
            }
        }
        */

        // ——————————————————————————————
        // 3) App IP / Mode text
        // ——————————————————————————————
        Rectangle {
            id: appIpRect
            visible: pulseRuntimeSettings.devName !== "..."
            width: parent.width
            height: appIpText.implicitHeight + 10
            color: "transparent"
            radius: 4

            Text {
                id: appIpText
                text: {
                    console.log("pulseRuntimeSettings.uuidSuccessfullyOpened is", pulseRuntimeSettings.uuidSuccessfullyOpened);
                    if (pulseRuntimeSettings.uuidSuccessfullyOpened === pulseRuntimeSettings.uuidUsbSerial) {
                        return "\nConnected by:\nPulse USB connection"
                    } else {
                        if (root.gatewayIp) {
                            if (pulseRuntimeSettings.expertMode) {
                                return "\nConnected by WiFi:\nGateway:" + root.gatewayIp
                            } else {
                                return "\nConnected by:\nWiFi Gateway"
                            }

                        }
                    }
                }
                font.pixelSize: root.infoPixelsSize
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
        root.gatewayIp = pulseSettings.udpGateway;
    }
}
