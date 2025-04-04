import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Item {
    id: root
    width: 155
    height: 80

    // Expose the checkbox state and icon source for external control
    property alias checked: checkBox.checked
    property alias iconSource: controlIcon.source

    // Signal emitted when the checkbox state changes
    signal stateChanged(bool checked)

    // Outer rounded rectangle for consistent UI look
    Rectangle {
        id: outerShape
        anchors.fill: parent
        radius: height / 2
        color: "#80000000"
        border.color: "transparent"
        border.width: 2

        RowLayout {
            anchors.centerIn: parent
            spacing: 10

            // Icon to indicate the type of controller
            Image {
                id: controlIcon
                // Default icon; override when using the component
                source: "./pulse_controls.svg"
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                fillMode: Image.PreserveAspectFit
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                Layout.leftMargin: 6
            }

            // The checkbox component with a larger custom indicator
            CheckBox {
                id: checkBox
                implicitWidth: 48
                implicitHeight: 48

                // Custom white background with a subtle border
                background: Rectangle {
                    anchors.fill: parent
                    color: "white"
                    radius: 4
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
                        // Removed renderPolicy as it's not supported in your version

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            if (checkBox.checked) {
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
    }
}
