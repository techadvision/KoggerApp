import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: settingsPopup
    //modal: true
    focus: true
    width: 900
    height: 400
    anchors.centerIn: parent
    color: "white"
    radius: 8

    signal pulsePreferenceClosed()
    signal pulsePreferenceValueChanged(double newValue)


    GridLayout {
        id: layout
        anchors.fill: parent
        //anchors.margins: 10
        rowSpacing: 20
        columnSpacing: 20
        columns: 3
        //rows: 5

        // --- Row 1: Auto Level - Step
        Text {
            text: "Auto Depth Step"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 0
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
            Layout.topMargin: 20
        }

        HorizontalControllerDoubleSettings {
            id: stepSelector
            values: [1.0, 2.0, 3.0, 4.0]
            currentValue: pulseRuntimeSettings.autoDepthLevelStep
            onPulsePreferenceValueChanged: {
                console.log("PulseSettingsValue Shift step changed to", newValue)
                pulseRuntimeSettings.autoDepthLevelStep = newValue
                settingsPopup.pulsePreferenceValueChanged(newValue)
            }

            height: 80
            Layout.preferredWidth: 280
            GridLayout.row: 0
            GridLayout.column: 2
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            Layout.topMargin: 20
        }

        // --- Row 2: Auto Level - Depth below last known
        Text {
            text: "Distance below"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 1
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
        }

        HorizontalControllerDoubleSettings {
            id: depthSelector
            values: [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]
            currentValue: pulseRuntimeSettings.autoDepthDistanceBelow
            onPulsePreferenceValueChanged: {
                console.log("PulseSettingsValue Distance below last measure changed to", newValue)
                pulseRuntimeSettings.autoDepthDistanceBelow = newValue
                settingsPopup.pulsePreferenceValueChanged(newValue)
            }

            height: 80
            Layout.preferredWidth: 280
            GridLayout.row: 1
            GridLayout.column: 2
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

        // --- Row 3: Depth - Minimum measure unit
        Text {
            text: "Minimum Measure"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 2
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
        }

        HorizontalControllerDoubleSettings {
            id: minMeasureSelector
            values: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]
            currentValue: pulseRuntimeSettings.autoDepthMinLevel
            onPulsePreferenceValueChanged: {
                console.log("PulseSettingsValue Minimum Measure changed to", newValue)
                pulseRuntimeSettings.autoDepthMinLevel = newValue
                settingsPopup.pulsePreferenceValueChanged(newValue)
            }

            height: 80
            Layout.preferredWidth: 280
            GridLayout.row: 2
            GridLayout.column: 2
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

        // --- Row 4: Speed of display (low = lower range)
        Text {
            text: "Scroll Speed"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 3
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
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
            GridLayout.row: 3
            GridLayout.column: 2
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }
    }
}
