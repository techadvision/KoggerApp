import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Echo.UI 1.0
import QtQuick.Window

Flickable {
    id: root

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real platformScale: _isAndroid ? 0.9 : 0.75
    //readonly property real s: Ui.scale * platformScale
    readonly property real shortSide: Math.min(Screen.width, Screen.height)
    readonly property real s: Math.max(1.0, shortSide / 1100) // tune 800 to your “10-inch baseline”


    // Platform related sizes
    property int controlIconSize: Math.round(24 * s)
    property int pressButtonSize: Math.round(56 * s)
    property int displayPixels:   Math.round(60 * s)
    property int valueTextWidth:  Math.round(60 * s)
    property int valueTextHeigh:  Math.round(40 * s)
    property int valuePixels:     Math.round(42 * s)
    property int autoPixels:      Math.round(32 * s)
    property int selectIconSize:  Math.round(64 * s)
    property int selectCheckSize: Math.round(48 * s)

    /*
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
    */

    focus: true
    width: Math.round(900 * s) //_isAndroid ? 900 : 600

    property string appVersion: "unknown"

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
        source: pulseRuntimeSettings.is2DTransducer ? "./image/pulse_info_red_black_large.png" : "./image/pulse_info_blue_large.png"
        /*
        source: (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed ||
                 pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto)
                   ? "./image/pulse_info_red_black_large.png"
                   : "./image/pulse_info_blue_large.png"
        */
        fillMode: Image.PreserveAspectFit

        // Make width = 40% of the Flickable's width
        width: root.width * 0.4
        height: width * implicitHeight / implicitWidth

        // 10 px margin from top and left of the Flickable
        anchors.left: parent.left
        //anchors.verticalCenter: deviceLogo.verticalCenter
    }

    // ——————————————————————————————————————————————————————————
    // Right side: stack everything that used to be in GridLayout.column:1
    // inside a Column. Each child is wrapped in a Rectangle just as an example.
    // ——————————————————————————————————————————————————————————
    Column {
        id: rightColumn
        spacing: Math.round(20 * s)//20

        // Anchor the top of this column to the top of appIcon,
        // and place it immediately to the right of appIcon.
        anchors.top: appIcon.top
        anchors.left: appIcon.right
        anchors.leftMargin: Math.round(20 * s)//20

        // Make the column take the rest of the Flickable’s width,
        // accounting for the 10px left margin of appIcon + 20px gap + 10px right margin.
        // (You can tweak these margins as needed.)
        width: root.width - appIcon.width - Math.round(40 * s)//40

        // ——————————————————————————————
        // 0) App icon
        // ——————————————————————————————
        Rectangle {
            id: appIconRect
            width: parent.width
            height: Math.round(135 * s)//_isAndroid ? 135 : 90
            color: "transparent"
            radius: 4
            anchors.topMargin: 20

            // Center the text vertically/horizontally within its Rectangle
            Image {
                id: appIconImage
                source: "./image/logo_icon.png"
                height: Math.round(125 * s)//_isAndroid ? 125 : 80
                width: Math.round(125 * s)//_isAndroid ? 125 : 80
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
                text: root.appVersion
                font.bold: true
                font.pixelSize: Ui.fontXL// root.infoPixelsSize
                //anchors.top: appIconRect.bottom
                anchors.top: parent.top
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
            height: Math.max(
                        deviceContent.visible ? deviceContent.implicitHeight : 0,
                        noDeviceText.visible ? noDeviceText.implicitHeight : 0
                    ) + 10
            anchors.topMargin: Math.round(20 * s)//20
            color: "transparent"
            radius: 4

            // "No device" fallback
            Text {
                id: noDeviceText
                //visible: pulseRuntimeSettings.devName === "..."
                text: {
                    if (pulseRuntimeSettings.devName === "...")
                        return "Device:\nNo device connected"
                    if (pulseRuntimeSettings.wasKlfFileOpened)
                        return "Showing content rendered as"
                    return "Connected to:"
                }
                font.pixelSize: Ui.fontXL// root.infoPixelsSize
                //anchors.top: appNameRect.bottom
                anchors.top: parent.top
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
                    source: pulseRuntimeSettings.is2DTransducer ? "./image/pulse_logo_red.png" : "./image/pulse_logo_blue.png"
                    fillMode: Image.PreserveAspectFit
                    width: Math.round(245 * s)//245

                }

                Image {
                    id: deviceLogoBlack
                    visible: pulseRuntimeSettings.is2DTransducer
                    source: "./image/pulse_logo_black.png"
                    anchors.verticalCenter: deviceLogo.verticalCenter
                    fillMode: Image.PreserveAspectFit
                    width: Math.round(270 * s)//270
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
                    if (pulseRuntimeSettings.wasKlfFileOpened && pulseRuntimeSettings.uuidSuccessfullyOpened !== "") {
                        return "\nWas connected when opening log:"
                    }

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
                font.pixelSize: Ui.fontXL// root.infoPixelsSize
                //anchors.top: deviceNameRect.bottom
                anchors.top: parent.top
                anchors.topMargin: Math.round(20 * s)//20
                anchors.left: parent.left
                anchors.leftMargin: 5
            }
        }

        Rectangle {
            id:reconnectRect
            visible: (pulseRuntimeSettings.wasKlfFileOpened && pulseRuntimeSettings.uuidSuccessfullyOpened !== "")
            width: parent.width
            height: iconReconnect.implicitHeight + 10


            Text {
                id: reconnectText
                text: "Try reconnect?"
                font.pixelSize: Ui.fontXL// root.infoPixelsSize
                anchors.left: parent.left
                anchors.topMargin: Math.round(20 * s)//20
                anchors.leftMargin: 5
            }

            Image {
                id: iconReconnect
                source: "./icons/ui/pulse_reconnect.svg"
                width: Ui.iconTouch//_isAndroid ? 80: 54
                height: Ui.iconTouch//_isAndroid ? 80: 54
                anchors.left: reconnectText.right
                anchors.leftMargin: Math.round(10 * s)//10
                anchors.top: reconnectText.top
                anchors.bottom: reconnectText.bottom
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                anchors.fill: iconReconnect
                onClicked: {
                    pulseRuntimeSettings.reconnectAfterLogView = true
                }
            }
        }

    }

    // ——————————————————————————————————————————————————————————
    // Your existing function to load version.txt can stay here
    // ——————————————————————————————————————————————————————————

    /*
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
    */

    function loadVersion() {
        var xhr = new XMLHttpRequest();

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE){
                console.log("loadVersion: xhr.readyState !== XMLHttpRequest.DONE")
                return;
            }

            if (xhr.status === 200) {
                root.appVersion = xhr.responseText.trim().split(/\r?\n/)[0];
                console.log("loadVersion: xhr.status === 200")

            } else {
                console.error("loadVersion: Failed to load version.txt, status:", xhr.status, "url:", xhr.responseURL);
                root.appVersion = "unknown";
            }
        }

        // Pick ONE of these depending on where version.txt is in the qrc:
        //xhr.open("GET", Qt.resolvedUrl("version.txt"));              // only if beside PulseInfo.qml
        //xhr.open("GET", "qrc:/resources/version.txt");                 // likely correct if it is under /resources
        xhr.open("GET", "./version.txt");
        xhr.send();
    }


    Component.onCompleted: {
        loadVersion();
        root.gatewayIp = pulseSettings.udpGateway;
    }
}
