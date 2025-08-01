import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    width: 1000
    height: 550

    //property real scaleFactor: Qt.application.primaryScreen.width / 480
    property real scaleFactor: 1
    signal closeRequested()

    // ─── Semi-transparent background overlay ───────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
    }

    // ─── Main “popup” panel ────────────────────────────────────────
    Rectangle {
        id: mainPanel
        width: parent.width * 0.99
        height: parent.height * 0.98
        anchors.centerIn: parent
        color: "lightgray"
        radius: 8

        // ───────────────────────────────────────────────────────────────
        // HEADER (optional “X” + TabBar)
        Rectangle {
            id: header
            anchors.top: mainPanel.top
            anchors.left: mainPanel.left
            anchors.right: mainPanel.right
            height: 55
            color: "lightgray"

            // ─────────────────── TAB BAR (fills entire header height) ──────────────
            TabBar {
                id: tabBar
                anchors.top: header.top
                anchors.bottom: header.bottom
                anchors.left: header.left
                anchors.right: header.right

                // Make its background exactly the same gray
                background: Rectangle {
                    anchors.fill: tabBar
                    color: "lightgray"
                }

                // Sync tab index with SwipeView index
                currentIndex: swipeView.currentIndex
                onCurrentIndexChanged: swipeView.currentIndex = currentIndex

                // ────── Four “base” tabs (always present) ──────
                TabButton {
                    height: tabBar.height
                    display: AbstractButton.TextBesideIcon
                    text: "Device"
                    font.pointSize: 18 * root.scaleFactor
                    icon.source: "qrc:/icons/ui/pulse_info.svg"
                }
                TabButton {
                    height: tabBar.height
                    display: AbstractButton.TextBesideIcon
                    text: "Settings"
                    font.pointSize: 18 * root.scaleFactor
                    icon.source: "qrc:/icons/ui/pulse_settings.svg"
                }
                TabButton {
                    height: tabBar.height
                    display: AbstractButton.TextBesideIcon
                    text: "Recording"
                    font.pointSize: 18 * root.scaleFactor
                    icon.source: "qrc:/icons/ui/pulse_recording_inactive.svg"
                }
                TabButton {
                    height: tabBar.height
                    display: AbstractButton.TextBesideIcon
                    text: "Colors"
                    font.pointSize: 18 * root.scaleFactor
                    icon.source: "qrc:/icons/ui/pulse_color_2d_e500_white.svg"
                }

            }
        }

        // ───────────────────────────────────────────────────────────────
        // SWIPEVIEW: Pages 0–3 are always present. Page 4 (Expert) is inserted dynamically.
        SwipeView {
            id: swipeView
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true

            // Page #0: Device
            Page {
                PulseInfo { id: tabbedPulseInfo }
            }
            // Page #1: Settings
            Page {
                PulseInfoSettings { id: tabbedPulseSettings }
            }
            // Page #2: Recording
            Page {
                PulseInfoRecording { id: tabbedPulseRecording }
            }
            // Page #3: Colors
            Page {
                PulseInfoColorScheme { id: tabbedPulseColors }
            }
        }

    }
}
