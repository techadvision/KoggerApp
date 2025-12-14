import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import Echo.UI 1.0

Item {
    id: root

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real platformScale: _isAndroid ? 0.9 : 0.75
    readonly property real s: Ui.scale * platformScale

    width: Math.round(1000 * s)
    height: Math.round(550 * s)

    // Tab styling derived from UiMetrics
    readonly property int tabFontSize: Ui.fontM      // try fontM; switch to fontS if it feels big
    readonly property int headerHeight: Math.round(44 * s)

    /*
    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"

    width: _isAndroid ? 1000 : 650
    height:_isAndroid ? 550 : 400


    //property real scaleFactor: Qt.application.primaryScreen.width / 480
    property real scaleFactor: 1
    property real _dpi: Screen.pixelDensity * 25.4
    property real dpScale: _dpi / 160.0

    function dp(x)   {
        return Math.round(x * dpScale);
    } // density-independent pixels

    function sp(x)   {
        console.log("Font using SP for", x, "returning", dp(x))
        return dp(x);
    } // if you don't read user "font scale", use dp as sp
    */

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
            //height: 55
            height: headerHeight
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
                    //font.pixelSize: sp(15)
                    font.pixelSize: tabFontSize
                    font.pointSize: -1
                    icon.source: "qrc:/icons/ui/pulse_info.svg"
                }
                TabButton {
                    height: tabBar.height
                    display: AbstractButton.TextBesideIcon
                    text: "Settings"
                    //font.pixelSize: sp(15)
                    font.pixelSize: tabFontSize
                    font.pointSize: -1
                    icon.source: "qrc:/icons/ui/pulse_settings.svg"
                }
                TabButton {
                    height: tabBar.height
                    display: AbstractButton.TextBesideIcon
                    text: "Recording"
                    //font.pixelSize: sp(15)
                    font.pixelSize: tabFontSize
                    font.pointSize: -1
                    icon.source: "qrc:/icons/ui/pulse_recording_inactive.svg"
                }
                TabButton {
                    height: tabBar.height
                    display: AbstractButton.TextBesideIcon
                    text: "Colors"
                    //font.pixelSize: sp(15)
                    font.pixelSize: tabFontSize
                    font.pointSize: -1
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

    Component.onCompleted: {
        console.log("FONT SIZES: dpi=", _dpi, "dpScale=", dpScale,
                    "px(Device)=", sp(10), "px(Settings)=", sp(15))
    }

}
