import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: settingsPopup
    //modal: true
    focus: true
    width: 900
    height: 600
    anchors.centerIn: parent
    color: "white"
    radius: 8

    signal pulsePreferenceClosed()
    signal pulsePreferenceValueChanged(double newValue)

    // A basic background for the popup
    /*
    background: Rectangle {
        color: "white"
        radius: 8
    }
    */

    GridLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 10
        rowSpacing: 20
        columnSpacing: 10
        columns: 2
        rows: 5

        // Background for row 0:
        Rectangle {
            id: row0Background
            // Option 1: Using a hex color with alpha (0x80 = ~50% opacity)
            color: "#80FF0000"
            // Option 2: Alternatively, you can use:
            // color: "red"
            // opacity: 0.5
            z: -1  // Make sure it is behind other items
            GridLayout.row: 0
            GridLayout.column: 0
            GridLayout.columnSpan: 2
            Layout.preferredHeight: 80  // Make sure it fills the row’s height
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // --- Top row: Title (column 0) and Close Button (column 1)
        Text {
            text: "Pulse Settings"
            font.pixelSize: 48
            font.bold: true
            height: 80
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter

            GridLayout.row: 0
            GridLayout.column: 0
        }

        Button {
            text: "X"
            font.bold: true
            onClicked: pulsePreferenceClosed()

            height: 80
            GridLayout.row: 0
            GridLayout.column: 1
            width: 60
            Layout.alignment: Qt.AlignRight
        }

        // --- Row 1: Auto Level - Step
        Text {
            text: "Auto Depth - Shift step"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 1
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        }

        HorizontalControllerDoubleSettings {
            id: stepSelector
            values: [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
            currentValue: pulseRuntimeSettings.autoDepthLevelStep
            onPulsePreferenceValueChanged: {
                console.log("PulseSettingsValue Shift step changed to", newValue)
                pulseRuntimeSettings.autoDepthLevelStep = newValue
                settingsPopup.pulsePreferenceValueChanged(newValue)
            }

            height: 80
            Layout.preferredWidth: 280
            GridLayout.row: 1
            GridLayout.column: 1
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

        // --- Row 2: Auto Level - Depth below last known
        Text {
            text: "Auto Depth - Distance below measure"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 2
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        }

        HorizontalControllerDoubleSettings {
            id: depthSelector
            values: [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
            currentValue: pulseRuntimeSettings.autoDepthDistanceBelow
            onPulsePreferenceValueChanged: {
                console.log("PulseSettingsValue Distance below last measure changed to", newValue)
                pulseRuntimeSettings.autoDepthDistanceBelow = newValue
                settingsPopup.pulsePreferenceValueChanged(newValue)
            }

            height: 80
            Layout.preferredWidth: 280
            GridLayout.row: 2
            GridLayout.column: 1
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

        // --- Row 3: Depth - Minimum measure unit
        Text {
            text: "Depth - Minimum Measure"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 3
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        }

        HorizontalControllerDoubleSettings {
            id: minMeasureSelector
            values: [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
            currentValue: pulseRuntimeSettings.autoDepthMinLevel
            onPulsePreferenceValueChanged: {
                console.log("PulseSettingsValue Minimum Measure changed to", newValue)
                pulseRuntimeSettings.autoDepthMinLevel = newValue
                settingsPopup.pulsePreferenceValueChanged(newValue)
            }

            height: 80
            Layout.preferredWidth: 280
            GridLayout.row: 3
            GridLayout.column: 1
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

        // --- Row 4: Speed of display (low = lower range)
        Text {
            text: "Display - Scroll Speed"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 4
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        }

        HorizontalControllerDoubleSettings {
            id: speedSelector
            // Example array for speed:
            values: [10, 25, 50, 75, 100, 125]
            currentValue: pulseRuntimeSettings.scrollingSpeed
            onPulsePreferenceValueChanged: {
                pulseRuntimeSettings.scrollingSpeed = newValue
            }

            height: 80
            Layout.preferredWidth: 280
            GridLayout.row: 4
            GridLayout.column: 1
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }
    }
}
