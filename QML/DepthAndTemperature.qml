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

    property bool   dataAvailable: false
    property bool   isMetric: PulseSettings.useMetricValues
    property int    datasetUpdatedCounter: 0
    property double autoLevel: 2   // default value (for depth 0)

    signal swapUnits()
    //signal pulseAutoLevelChanged(int newAutoLevel)

    // Function to calculate the autoLevel based on the current depth value.
    function calculateAutoLevel(depth) {
        const { autoDepthMinLevel, autoDepthLevelStep, autoDepthDistanceBelow, autoDepthMaxLevel } = pulseRuntimeSettings;

      // When depth is zero, simply return the extra distance.
      if (depth === 0) {
        return Math.min(autoDepthDistanceBelow, autoDepthMinLevel);
      }

      // For very shallow depths (greater than 0 but still below the first step),
      // display the minimum level plus the extra distance.
      if (depth < autoDepthLevelStep) {
        //return Math.min(autoDepthDistanceBelow, autoDepthMinLevel);
        return autoDepthMinLevel + autoDepthDistanceBelow;
      }

      // For deeper values, determine how many full step increments have been passed.
      // We subtract autoDepthLevelStep so that the range from 0 (exclusive) to autoDepthLevelStep
      // all use the fixed display (i.e. the minimum display).
      const steps = Math.floor((depth - autoDepthLevelStep) / autoDepthLevelStep) + 1;

      // Calculate the displayed level: start at autoDepthMinLevel,
      // add one full step for each threshold passed,
      // and then always add autoDepthDistanceBelow.
      //let displayed = (steps * autoDepthLevelStep) + autoDepthDistanceBelow;
      let displayed = autoDepthMinLevel + (steps * autoDepthLevelStep) + autoDepthDistanceBelow;

      // (Optional) Cap the display if a maximum depth is defined.
      if (typeof autoDepthMaxLevel !== "undefined") {
        displayed = Math.min(displayed, autoDepthMaxLevel + autoDepthDistanceBelow);
      }

      return displayed;
    }

    function calculateDynamicResolution (depth) {

        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue) {
            console.log("TAV: should not set dynamicResolution for devName ", pulseRuntimeSettings.userManualSetName);
            return
        }
        if (pulseRuntimeSettings.userManualSetName === "...") {
            console.log("TAV: should not set dynamicResolution for devName ", pulseRuntimeSettings.userManualSetName);
            return
        }
        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue){
            //console.log("TAV: should not set dynamicResolution for manuel set devName ", pulseRuntimeSettings.userManualSetName);
            return
        }
        // 1. Choose a margin (in meters) to give extra headroom.
        var margin = pulseRuntimeSettings.autoDepthDistanceBelow //Default is 2 meters

        // 2. Compute desired resolution in mm.
        var desiredRes = (depth + margin) *2;

        // 3. Round up (ceiling) to be conservative:
        desiredRes = Math.ceil(desiredRes);

        // 4. Clamp to valid bounds.
        desiredRes = Math.max(desiredRes, pulseRuntimeSettings.dynamicResolutionMax);
        desiredRes = Math.min(desiredRes, pulseRuntimeSettings.dynamicResolutionMin);

        // 5. Compare with the old resolution to avoid flicker:
        var oldRes = pulseRuntimeSettings.dynamicResolution;

        // Only update if new resolution differs by at least 1 mm
        if (Math.abs(desiredRes - oldRes) >= 1) {
            pulseRuntimeSettings.dynamicResolution = desiredRes;
            console.log("TAV: setting dynamicResolution to ", desiredRes, " for depth ", depth);
            //dev.chartResolution = desiredRes; //Done in deviceItem
        }
    }

    Timer {
        id: autoLevelTimer
        interval: 100  // Poll every 100ms; adjust as needed.
        running: true
        repeat: true
        onTriggered: {
            let currentDepth = (dataset !== null) ? dataset.dist : 0;
            calculateDynamicResolution(currentDepth)
            let newLevel = calculateAutoLevel(currentDepth);
            if (newLevel !== depthAndTemperature.autoLevel) {
                depthAndTemperature.autoLevel = newLevel;
                if (pulseRuntimeSettings !== null) {
                    pulseRuntimeSettings.autoDepthMaxLevel = newLevel
                    console.log("TAV: Auto level changed to: " + newLevel);
                    console.log("TAV: Auto level step: " + pulseRuntimeSettings.autoDepthLevelStep);
                    console.log("TAV: Auto level distance below: " + pulseRuntimeSettings.autoDepthDistanceBelow);
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



