import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
//import QtQuick.Controls.Material 2.15
import Echo.UI 1.0
import QtQuick.Window

Item {
    id: root

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real platformScale: _isAndroid ? 0.9 : 0.75
    //readonly property real s: Ui.scale * platformScale
    //readonly property real s: Math.max(1.0, Ui.scale * platformScale)
    readonly property real shortSide: Math.min(Screen.width, Screen.height)
    readonly property real s: Math.max(1.0, shortSide / 1100) // tune 800 to your “10-inch baseline”

    // Platform related sizes
    /*
    width: Math.round(125 * s)
    height: Math.round(70 * s)
    */

    // Base “design” size for this control on your 10" tablet
    readonly property int baseWidth: 125
    readonly property int baseHeight: 70

    // Natural size for layouts
    implicitWidth:  Math.round(baseWidth  * s)
    implicitHeight: Math.round(baseHeight * s)

    // Good defaults when NOT inside a layout
    width:  implicitWidth
    height: implicitHeight

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
    width: _isAndroid ? 155 : 100
    height: _isAndroid ? 80 : 60

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
    */

    property string controleName: ""

    // Expose the checkbox state and icon source for external control
    property alias checked: checkBox.checked
    property alias iconSource: controlIcon.source

    // Signal emitted when the checkbox state changes
    signal controllerStateChanged(bool checked)

    // Outer rounded rectangle for consistent UI look
    Rectangle {
        id: outerShape
        width: parent.width
        height: parent.height
        radius: height / 2
        color: "#80000000"
        border.color: "#40ffffff"
        border.width: 1

        RowLayout {
            anchors.centerIn: parent
            spacing: 5

            // Icon to indicate the type of controller
            Image {
                id: controlIcon
                Layout.preferredWidth: root.controlIconSize
                Layout.preferredHeight: root.controlIconSize
                //Layout.preferredWidth: 34
                //Layout.preferredHeight: 34
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                Layout.leftMargin: 0
                Layout.rightMargin: 16
            }

            // The checkbox component with a larger custom indicator
            CheckBox {
                id: checkBox
                implicitWidth: root.selectCheckSize
                implicitHeight: root.selectCheckSize

                // Custom white background with a subtle border
                background: Rectangle {
                    anchors.fill: parent
                    //color: "white"
                    color: {
                        if (root.controleName === "echogramPlayPause") {
                            if (pulseRuntimeSettings.mavlinkDetected) {
                                return "green"
                            } else {
                                return "white"
                            }
                        }
                        if (!root.checked)
                            return "white"
                        if (root.controleName === "RecordKlf")
                            return "red"
                        return "white"
                    }
                    radius: 8
                    border.width: 1
                    border.color: "gray"
                }

                // Override the indicator to draw a larger check mark
                indicator: Item {
                    id: indicatorItem
                    anchors.fill: parent

                    Canvas {
                        id: indicatorCanvas
                        anchors.fill: parent

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            if (checkBox.checked) {
                                ctx.strokeStyle = "black";
                                ctx.lineWidth = Math.max(width, height) * 0.1;
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                ctx.beginPath();
                                ctx.moveTo(width * 0.2, height * 0.5);
                                ctx.lineTo(width * 0.45, height * 0.75);
                                ctx.lineTo(width * 0.8, height * 0.3);
                                ctx.stroke();
                            }
                        }

                        // Force the Canvas to repaint when the checked state changes
                        Connections {
                            target: checkBox
                            function onCheckedChanged () {
                                indicatorCanvas.requestPaint()
                            }

                            //onCheckedChanged: indicatorCanvas.requestPaint()
                        }
                    }
                }

                onCheckedChanged: {
                    root.controllerStateChanged(checked)
                }
            }
        }

        // ───────────────────────────────
        // MouseArea that covers the entire outerShape:
        MouseArea {
            anchors.fill: parent
            hoverEnabled: false

            onClicked: {
                // If the click is NOT inside the CheckBox, toggle it.
                // Otherwise do nothing here, so the CheckBox itself picks up the event.
                if (!checkBox.containsMouse) {
                    checkBox.checked = !checkBox.checked
                }
            }
        }
        // ───────────────────────────────
    }
}
