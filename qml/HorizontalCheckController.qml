import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Item {
    id: root

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"

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

    property string controleName: ""

    // Expose the checkbox state and icon source for external control
    property alias checked: checkBox.checked
    property alias iconSource: controlIcon.source

    // Signal emitted when the checkbox state changes
    signal stateChanged(bool checked)

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
                    root.stateChanged(checked)
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
