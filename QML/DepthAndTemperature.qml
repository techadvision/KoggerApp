import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.15
import org.techadvision.settings 1.0
import org.techadvision.runtime 1.0


Item {
    id: depthAndTemperature
    width: 350
    height: 200
    clip: true

    property bool dataAvailable: false
    property bool isMetric: PulseSettings.useMetricValues
    property int datasetUpdatedCounter: 0
    property int autoLevel: 2   // default value (for depth 0)

    signal swapUnits()
    //signal pulseAutoLevelChanged(int newAutoLevel)

    // Function to calculate the autoLevel based on the current depth value.
    function calculateAutoLevel(depth) {
        if (depth === 0) {
            return 2;
        } else if (depth <= 1) {
            return 3;
        } else {
            // Compute autoLevel based on depth (floor value + 3), with a max of 100.
            return Math.min(Math.floor(depth) + 3, pulseRuntimeSettings.maximumDepth + 3);
        }
    }

    Timer {
        id: autoLevelTimer
        interval: 100  // Poll every 100ms; adjust as needed.
        running: true
        repeat: true
        onTriggered: {
            let currentDepth = (dataset !== null) ? dataset.dist : 0;
            let newLevel = calculateAutoLevel(currentDepth);
            if (newLevel !== autoLevel) {
                depthAndTemperature.autoLevel = newLevel;
                if (pulseRuntimeSettings !== null) {
                    pulseRuntimeSettings.autoDepthMaxLevel = newLevel
                    console.log("TAV: Auto level changed to: " + newLevel);
                } else {
                    console.log("TAV: Auto level cannot be set when pulseRuntimeSettings is null");
                }

                //depthAndTemperature.autoLevelChanged(newLevel);
            }
        }
    }

    function formatDepth() {
        let depthInMeters = (dataset !== null) ? dataset.dist : 0
        let decimalPlaces = 1;

        return isMetric
            ? depthInMeters.toFixed(decimalPlaces) + ' m'
            : (depthInMeters * 3.28084).toFixed(decimalPlaces) + ' ft'; // Convert to feet if not metric
    }

    function formatTemperature() {
        let temperatureInDegrees = (dataset !== null) ? dataset.temp : 0
        let temperatureInFarenheit = temperatureInDegrees * (9 / 2) + 32
        let decimalPlacesTemp = 1;
        return isMetric
                ? Math.round(temperatureInDegrees * 10) / 10 + ' \u00B0C'
                : Math.round(temperatureInFarenheit * 10) / 10 + ' \u00B0F';
    }


    Rectangle {
        id: depthTempRect
        width: depthAndTemperature.width
        height: depthAndTemperature.height
        color: "transparent" // Use transparent for layout
        radius: parent.height / 2

        // Property to count the taps
        property int tapCount: 0
        // Timer to reset the tap count after 5 seconds
        Timer {
            id: tapResetTimer
            interval: 5000  // 5 seconds
            repeat: false
            onTriggered: depthTempRect.tapCount = 0
        }

        MouseArea {
            width: parent.width
            height: parent.height
            anchors.centerIn: parent
            onClicked: {
                // Start the timer on first tap
                if (!tapResetTimer.running)
                    tapResetTimer.start();

                depthTempRect.tapCount++;

                depthAndTemperature.isMetric = !depthAndTemperature.isMetric
                PulseSettings.useMetricValues = depthAndTemperature.isMetric
                setMeasuresMetricNow(depthAndTemperature.isMetric)

                // If more than 10 taps within 5 seconds, activate hidden feature
                if (depthTempRect.tapCount > 10) {
                    // Set your hidden feature flag (or call a function to enable tuning mode)
                    pulseRuntimeSettings.expertMode = !pulseRuntimeSettings.expertMode;
                    console.log("TAV: Activated the hidden features");

                    // Optionally, reset tap count and timer if you want one activation per sequence
                    tapResetTimer.stop();
                    depthTempRect.tapCount = 0;
                }
            }
        }

        // Depth Value (Whole Number Part)
        Rectangle {
            id: wholeNumberRect
            width: parent.width * 0.75
            height: 96
            color: "#80000000"
            anchors.right: decimalPartRect.left
            anchors.bottom: decimalPartRect.bottom
            anchors.topMargin: 20

            Text {
                id: wholeNumber
                text: depthAndTemperature.formatDepth().split('.')[0] + "."
                color: "white"
                font.bold: true
                font.pixelSize: 96
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }

        }

        // Depth Value (Decimal Part)
        Rectangle {
            id: decimalPartRect
            width: parent.width * 0.1
            height: 96
            color: "#80000000"
            anchors.right: depthUnitRect.left
            anchors.top: parent.top
            anchors.topMargin: 10

            Text {
                id: decimalPart
                text: depthAndTemperature.formatDepth().split('.')[1] ? depthAndTemperature.formatDepth().split('.')[1].split(' ')[0] : ""
                color: "white"
                font.pixelSize: 72
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.top: parent.top
            }
        }

        // Unit (m or ft)
        Rectangle {
            id: depthUnitRect
            width: parent.width * 0.15
            height: 96
            color: "#80000000"
            anchors.right: parent.right
            anchors.top: parent.top
            //anchors.top: decimalPartRect.bottom
            anchors.topMargin: 10
            anchors.rightMargin: 50

            Text {
                id: depthUnit
                text: depthAndTemperature.formatDepth().split(' ')[1] // Extract the unit (m or ft)
                color: "white"
                font.pixelSize: 36
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 15
            }
        }

        // Temperature Value
        Rectangle {
            id: temperatureValueRect
            width: parent.width * 0.85
            height: 72
            color: "#80000000"
            anchors.right: temperatureUnitRect.left
            anchors.top: temperatureUnitRect.top
            visible: pulseRuntimeSettings.useTemperature

            Text {
                id: temperatureValue
                text: depthAndTemperature.formatTemperature().split(' ')[0] || "-.-"
                color: "white"
                font.pixelSize: 72
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Temperature Unit (°C or °F)
        Rectangle {
            id: temperatureUnitRect
            width: parent.width * 0.15
            height: 72
            color: "#80000000"
            anchors.right: depthUnitRect.right
            anchors.top: depthUnitRect.bottom
            anchors.topMargin: 20
            visible: pulseRuntimeSettings.useTemperature

            Text {
                id: temperatureUnit
                text: depthAndTemperature.formatTemperature().split(' ')[1] // Temperature unit
                color: "white"
                font.pixelSize: 36
                horizontalAlignment: Text.AlignLeft
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 15
            }
        }
    }

    Component.onCompleted: {
        setMeasuresMetricNow(PulseSettings.useMetricValues)
    }

}



