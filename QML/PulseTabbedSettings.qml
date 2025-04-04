import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    width: 1000
    height: 800

    signal closeRequested()

    // Overlay background (semi-transparent)
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
    }

    // Main settings panel
    Rectangle {
        id: mainPanel
        width: parent.width * 0.9
        height: parent.height * 0.8
        anchors.centerIn: parent
        color: "white"
        radius: 8

        // Header area for the close button and TabBar
        Rectangle {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 60
            color: "lightgray"

            // Close button on the right
            Button {
                id: closeButton
                width: 66
                height: 60
                text: "X"
                font.pixelSize: 48
                flat: true
                font.bold: true
                anchors.right: parent.right
                //anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 16
                onClicked: {
                    root.closeRequested()
                }
            }

            // TabBar limited so it does not overlap the close button
            TabBar {
                id: tabBar
                anchors.left: parent.left
                anchors.bottom: closeButton.bottom
                topPadding: 15
                anchors.top: closeButton.top
                anchors.right: closeButton.left  // This limits the width of the TabBar
                currentIndex: swipeView.currentIndex
                onCurrentIndexChanged: swipeView.currentIndex = currentIndex

                TabButton {
                    height: tabBar.height
                    display: AbstractButton.TextBesideIcon
                    text: "Pulse Device"
                    font.pointSize: 16
                    icon.source: "qrc:/icons/pulse_info.svg"
                }
                TabButton {
                    height: tabBar.height
                    display: AbstractButton.TextBesideIcon
                    text: "Pulse Settings"
                    font.pointSize: 16
                    icon.source: "qrc:/icons/pulse_settings.svg"
                }
                TabButton {
                    height: tabBar.height
                    display: AbstractButton.TextBesideIcon
                    text: "Recording"
                    font.pointSize: 16
                    icon.source: "qrc:/icons/pulse_recording_inactive.svg"
                }
            }
        }


        // SwipeView placed below the header
        SwipeView {
            id: swipeView
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true   // Ensures that only the active page is visible

            Page {
                PulseInfo {
                    id: tabbedPulseInfo
                }
            }
            Page {
                PulseInfoSettings {
                    id: tabbedPulseSettings
                }
            }
            Page {
                PulseInfoRecording {
                    id: tabbedPulseRecording
                }
            }
        }
    }
}
