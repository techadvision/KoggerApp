import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Item {
    id: root
    width: 155           // Reduced width for small screens
    height: 80           // Retain the original height
    property int selectedIndex: 0
    property var model: []    // List of icon file paths
    signal iconSelected(int index)  // Notify when an icon is selected
    property string iconSource: ""
    property bool allowExpertModeByMultiTap: false

    Timer {
        id: tapResetTimer
        interval: 5000  // 5 seconds
        repeat: false
        onTriggered: iconRect.tapCount = 0
    }

    // Outer rounded rectangle
    Rectangle {
        id: outerShape
        width: parent.width
        height: parent.height
        radius: height / 2
        color: "#80000000"
        border.color: "#40ffffff"
        border.width: 1

        // CATCH‐ALL MOUSEAREA – blocks clicks from passing through to the pinch
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: false
            preventStealing: true
            onPressed: { /* nothing – absorb */ }
        }


        RowLayout {
            anchors.centerIn: parent
            spacing: 10

            // Topic icon (for context)
            Image {
                id: controlIcon
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                fillMode: Image.PreserveAspectFit
                source: root.iconSource
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                Layout.leftMargin: 6
            }

            // Icon representing the current choice.
            // Tapping it cycles to the next icon in the model.
            Rectangle {
                id: iconRect
                width: 64
                height: 64
                radius: 5
                color: "transparent"
                property int tapCount: 0

                Image {
                    anchors.fill: parent
                    anchors.centerIn: parent
                    source: model[selectedIndex]
                    width: 64
                    height: 64
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        selectedIndex = (selectedIndex + 1) % model.length;
                        root.iconSelected(selectedIndex);

                        if (!root.allowExpertModeByMultiTap)
                            return

                        // Start the timer on first tap
                        if (!tapResetTimer.running)
                            tapResetTimer.start();

                        iconRect.tapCount++;
                        //console.log("TAV: Tapped the icon for time", iconRect.tapCount);

                        // If more than 10 taps within 5 seconds, activate hidden feature
                        if (iconRect.tapCount > 10) {
                            // Set your hidden feature flag (or call a function to enable tuning mode)
                            //pulseRuntimeSettings.expertMode = !pulseRuntimeSettings.expertMode;
                            //console.log("TAV: Activated the hidden features");

                            // Optionally, reset tap count and timer if you want one activation per sequence
                            tapResetTimer.stop();
                            iconRect.tapCount = 0;
                        }
                    }
                }
            }
        }
    }
}

