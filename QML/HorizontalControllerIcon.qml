import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Item {
    id: root
    width: 310
    height: 80 // Oval height
    property int selectedIndex: 0 // Tracks the currently selected icon
    property var model: [] // List of icon file paths
    signal iconSelected(int index) // Notify when an icon is selected
    property string iconSource: ""

    // Outer oval shape for styling
    Rectangle {
        id: outerShape
        width: parent.width
        height: parent.height
        radius: parent.height / 2 // Oval shape
        color: "#80000000" // Grey background for outer oval
        border.color: "transparent"
        border.width: 2

        RowLayout {
            anchors.centerIn: parent
            spacing: 10

            Image {
                id: controlIcon
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                fillMode: Image.PreserveAspectFit
                source: root.iconSource  // Bind icon source to the external property
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                Layout.leftMargin: 12
            }

            // Minus Button
            Rectangle {
                id: selectorMinusButton
                width: 64
                height: 64
                radius: 20
                color: "transparent"
                Layout.leftMargin: 4

                Text {
                    anchors.centerIn: parent
                    text: "-"
                    font.pixelSize: 64
                    color: "white"
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        selectedIndex = (selectedIndex - 1 + model.length) % model.length; // Wrap to the last if at the first
                        root.iconSelected(selectedIndex);
                    }
                }
            }

            // Value Display with Icon and Vertical Dividers
            Rectangle {
                id: valueFieldBackground
                width: 100
                height: 50
                //radius: 25
                color: "transparent"
                border.color: "transparent"
                border.width: 2

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5

                    // Divider on the left
                    Rectangle {
                        width: 2
                        height: parent.height * 0.8
                        color: "white"
                    }

                    // Icon Display
                    Rectangle {
                        width: 64
                        height: 64
                        radius: 5
                        color: "transparent"
                        //anchors.centerIn: parent
                        //Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

                        Item {
                            anchors.fill: parent
                            anchors.centerIn: parent

                            Image {
                                //anchors.fill: parent
                                //anchors.centerIn: parent
                                source: model[selectedIndex] // Dynamically set icon
                                width: 64
                                height: 64
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                            }
                        }
                    }

                    // Divider on the right
                    Rectangle {
                        width: 2
                        height: parent.height * 0.8
                        color: "white"
                    }
                }
            }

            // Plus Button
            Rectangle {
                id: selectorPlusButton
                width: 64
                height: 64
                radius: 20
                color: "transparent"
                Layout.rightMargin: 4
                //color: "#555555"

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.pixelSize: 64
                    color: "white"
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        selectedIndex = (selectedIndex + 1) % model.length; // Wrap to the first if at the last
                        root.iconSelected(selectedIndex);
                    }

                }

            }
        }
    }

}
