import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    width: 1000
    height: 550

    property real scaleFactor: Qt.application.primaryScreen.width / 480

    signal closeRequested()

    // Overlay background (semi-transparent)
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
    }

    // Main settings panel
    Rectangle {
        id: mainPanel
        width: parent.width * 0.99
        height: parent.height * 0.98
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
                    text: "Device"
                    font.pointSize: 14 * root.scaleFactor
                    icon.source: "qrc:/icons/pulse_info.svg"
                }

                TabButton {
                    height: tabBar.height
                    display: AbstractButton.TextBesideIcon
                    text: "Settings"
                    font.pointSize: 14 * root.scaleFactor
                    icon.source: "qrc:/icons/pulse_settings.svg"
                }

                TabButton {
                    height: tabBar.height
                    display: AbstractButton.TextBesideIcon
                    text: "NMEA"
                    font.pointSize: 14 * root.scaleFactor
                    icon.source: "qrc:/icons/pulse_settings.svg"
                }

                TabButton {
                    height: tabBar.height
                    display: AbstractButton.TextBesideIcon
                    text: "Recording"
                    font.pointSize: 14 * root.scaleFactor
                    icon.source: "qrc:/icons/pulse_recording_inactive.svg"
                }

                TabButton {
                    height: tabBar.height
                    display: AbstractButton.TextBesideIcon
                    text: "Colors"
                    font.pointSize: 14 * root.scaleFactor
                    icon.source: "qrc:/icons/pulse_color_2d_e500_white.svg"
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
                PulseInfoNmeaSettings {
                    id: tabbedPulseNmeaSettings
                }
            }

            Page {
                PulseInfoRecording {
                    id: tabbedPulseRecording
                }
            }

            Page {
                PulseInfoColorScheme {
                    id: tabbedPulseColors
                }
            }

        }
    }
}
