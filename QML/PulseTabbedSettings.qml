import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    width: 1000
    height: 550

    property real scaleFactor: Qt.application.primaryScreen.width / 480
    signal closeRequested()

    // ─── Semi-transparent background overlay ───────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
    }

    /*
    Rectangle {
       id: panelShadow
       width: parent.width * 0.99
       height: parent.height * 0.98

       // Anchor to center, then shift right/down by 5px (tweak as desired)
       anchors.horizontalCenter: parent.horizontalCenter
       anchors.verticalCenter: parent.verticalCenter
       anchors.horizontalCenterOffset: 10
       anchors.verticalCenterOffset: 10

       color: "#40000000"   // semi‐transparent black (25% opacity)
       radius: 8
       z: 0
   }
   */

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

            // ─────────────────────────────────────────────────────────
            // (Optional) “X” close button. Remove/comment if you don’t want it:
            //
            // Button {
            //     id: closeButton
            //     width: 66; height: 60
            //     text: "X"
            //     font.pixelSize: 48
            //     flat: true
            //     font.bold: true
            //     anchors.right: parent.right
            //     anchors.top: parent.top
            //     onClicked: root.closeRequested()
            // }
            // ─────────────────────────────────────────────────────────

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
                    font.pointSize: 24 * root.scaleFactor
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
                // ─────────────────────────────────────────────────
                // (No placeholder TabButton here—Expert will be inserted dynamically.)
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

            // ────────────────────────────────────────────────────────────
            // (We do NOT declare an “Expert” Page here. It will be inserted below.)
        }

        // ─────── COMPONENTS FOR DYNAMIC “EXPERT” TAB + PAGE ──────────────
        Component {
            id: expertTabComponent
            TabButton {
                height: tabBar.height
                display: AbstractButton.TextBesideIcon
                text: "Expert"
                font.pointSize: 14 * root.scaleFactor
                icon.source: "qrc:/icons/pulse_settings.svg"
            }
        }
        Component {
            id: expertPageComponent
            Item {
                // Note: no explicit width/height here!
                // SwipeView will automatically set this Item’s size to match itself.
                id: expertContainer

                PulseInfoExpert {
                    id: tabbedPulseExpertSettings
                    anchors.fill: parent
                }
            }
            /*
            Page {
                PulseInfoExpert { id: tabbedPulseExpertSettings }
            }
            */
        }

        // ───────────────────────────────────────────────────────────────
        // 1) ON CE: if expertMode was already true at load time, insert both tab & page
        Component.onCompleted: {
            if (pulseRuntimeSettings.expertMode) {
                var newTab0 = expertTabComponent.createObject(tabBar)
                tabBar.insertItem(tabBar.count, newTab0)
                var newPage0 = expertPageComponent.createObject(null)
                swipeView.insertItem(swipeView.count, newPage0)
            }
        }

        // ───────────────────────────────────────────────────────────────
        // 2) ON TOGGLING expertMode: insert or remove that fifth tab/page on the fly
        Connections {
            target: pulseRuntimeSettings
            function onExpertModeChanged() {
                console.log("Expert Mode: onExpertModeChanged to", pulseRuntimeSettings.expertMode)
                if (pulseRuntimeSettings.expertMode) {
                    var newTab = expertTabComponent.createObject(tabBar)
                    tabBar.insertItem(tabBar.count, newTab)
                    var newPage = expertPageComponent.createObject(null)
                    swipeView.insertItem(swipeView.count, newPage)
                }
                else {
                    // ─── Turned OFF: remove last TabButton + Page if present ───
                    if (tabBar.count > 4) {
                        tabBar.removeItem(tabBar.count - 1)
                    }
                    if (swipeView.count > 4) {
                        var lastPg = swipeView.itemAt(swipeView.count - 1)
                        swipeView.removeItem(lastPg)
                    }
                    // If user was on index=4, snap back into 0–3 range
                    if (swipeView.currentIndex >= swipeView.count)
                        swipeView.currentIndex = 0
                    if (tabBar.currentIndex >= tabBar.count)
                        tabBar.currentIndex = 0
                }
            }
        }
    }
}
