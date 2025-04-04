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

    property bool   dataAvailable:              false
    property bool   isMetric:                   PulseSettings.useMetricValues
    property int    datasetUpdatedCounter:      0
    property double autoLevel:                  2   // default value (for depth 0)

    property int    dynamicResStableCount :     0   // counter to ensure more than one record to be considered before shifting resolution
    property double lastStableDepth:            0   // Depth at which we last updated the resolution.
    property int    stableCount:                0   // Counter for consecutive stable readings.
    property int    lastDirection :             0   // direction of shift
    property int    newAutoLevel :              1   // Shifter variable for the UI
    property bool   pulseBlueResSetOnce:        false //Set the resoution for blue only once

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

    // This is the resolution updater that takes into account both depth integer steps and hysteresis.
    function updateDynamicResolutionWithStep(depth, candidateRes) {
        // autoDepthLevelStep defines the resolution step (default 1 meter).
        const step = pulseRuntimeSettings.autoDepthLevelStep || 1;

        // Determine the integer level (bucket) for the current depth.
        // For example, if step=1, depths 1.0–1.999 are in level 1.
        let newLevel = Math.floor(depth / step);
        let lastLevel = Math.floor(lastStableDepth / step);

        // Only consider an update if we've passed an integer boundary.
        if (newLevel === lastLevel) {
            // Depth remains within the same integer "bucket": reset any counters.
            stableCount = 0;
            lastDirection = 0;
            return;
        }

        // Determine the direction of the depth change relative to the last stable depth.
        let newDirection = 0;
        if (depth > lastStableDepth + pulseRuntimeSettings.hysteresisThreshold) {
            newDirection = 1;  // Depth is significantly deeper.
        } else if (depth < lastStableDepth - pulseRuntimeSettings.hysteresisThreshold) {
            newDirection = -1; // Depth is significantly shallower.
        } else {
            // Within the hysteresis margin: ignore minor fluctuations.
            stableCount = 0;
            lastDirection = 0;
            return;
        }

        // If the new reading goes in a different direction than previous consecutive readings,
        // reset the counter.
        if (lastDirection !== 0 && lastDirection !== newDirection) {
            stableCount = 0;
        }

        // Update the direction and increment the count.
        lastDirection = newDirection;
        stableCount++;

        // Only update if we've seen the same directional change for the required number of readings.
        if (stableCount >= pulseRuntimeSettings.requiredStableReading) {
            pulseRuntimeSettings.dynamicResolution = candidateRes;
            console.log("TAV: setting dynamicResolution to", candidateRes,
                        "for depth", depth, "with new integer level", newLevel);
            // Reset counters and record this depth as the new stable reference.
            stableCount = 0;
            lastDirection = 0;
            lastStableDepth = depth;
        }
    }

    function calculateDynamicResolution(depth) {
        // If the device name indicates we should not update resolution, return.
        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue) {
            // (For pulse blue, perhaps only update once.)
            if (!pulseBlueResSetOnce) {
                pulseBlueResSetOnce = true;
                pulseRuntimeSettings.dynamicResolution = pulseRuntimeSettings.chartResolution;
                console.log("TAV: set pulseRuntimeSettings.dynamicResolution just once to",
                            pulseRuntimeSettings.dynamicResolution,
                            "for", pulseRuntimeSettings.userManualSetName);
            }
            return;
        }
        if (pulseRuntimeSettings.userManualSetName !== pulseRuntimeSettings.modelPulseRed) {
            return;
        }

        // 1. Determine a margin (in meters) for extra headroom.
        const margin = pulseRuntimeSettings.dynamicResolutionMargin; // e.g., default 2 m.

        // 2. Calculate candidate resolution (in mm), rounding as needed.
        let candidateRes = Math.round((depth + margin) * 2);

        // 3. Clamp candidate resolution to the allowed bounds.
        candidateRes = Math.max(candidateRes, pulseRuntimeSettings.dynamicResolutionMax);
        candidateRes = Math.min(candidateRes, pulseRuntimeSettings.dynamicResolutionMin);

        // 4. Update dynamic resolution only if the depth has passed an integer threshold,
        // and only after the hysteresis and consecutive reading conditions are met.
        updateDynamicResolutionWithStep(depth, candidateRes);
    }

    /*
    function calculateDynamicResolution (depth) {

        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue) {
            if (!pulseBlueResSetOnce) {
                pulseBlueResSetOnce = true
                pulseRuntimeSettings.dynamicResolution = pulseRuntimeSettings.chartResolution;
                console.log("TAV: set pulseRuntimeSettings.dynamicResolution just once to", pulseRuntimeSettings.dynamicResolution, "for", pulseRuntimeSettings.userManualSetName);
                return
            } else {
                return
            }
        }

        if (pulseRuntimeSettings.userManualSetName !== pulseRuntimeSettings.modelPulseRed) {
            //console.log("TAV: should not calculate dynamicResolution for devName ", pulseRuntimeSettings.userManualSetName);
            return
        }

        // 1. Choose a margin (in meters) to give extra headroom.
        var margin = pulseRuntimeSettings.dynamicResolutionMargin //Default is 2 meters

        // 2. Compute desired resolution in mm, round up
        //var desiredRes =  Math.round(depth *2) + margin
        var desiredRes =  Math.round((depth + margin) * 2)

        // 3. Clamp to valid bounds.
        desiredRes = Math.max(desiredRes, pulseRuntimeSettings.dynamicResolutionMax);
        desiredRes = Math.min(desiredRes, pulseRuntimeSettings.dynamicResolutionMin);

        // 4. Compare with the old resolution to avoid flicker:
        var oldRes = pulseRuntimeSettings.dynamicResolution;

        // 5. Perform the dynamicResolution update
        updateDynamicResolution(desiredRes, depth)
    }
    */

    /*
    function updateDynamicResolution(candidateRes, depth) {
        //console.log("TAV: got request to dynamicResolution for devName ", pulseRuntimeSettings.userManualSetName, ", candidateRes", candidateRes, "and depth", depth);
        const currentRes = pulseRuntimeSettings.dynamicResolution;
        const diff = candidateRes - currentRes;
        let currentDirection = 0;

        // Determine if the candidate difference is significant enough.
        if (diff > pulseRuntimeSettings.hysterisisThreshold) {
            currentDirection = 1; // Candidate is significantly deeper.
        } else if (diff < -pulseRuntimeSettings.hysterisisThreshold) {
            currentDirection = -1; // Candidate is significantly shallower.
        } else {
            // Difference is too small: reset the count and direction.
            dynamicResStableCount = 0;
            lastDirection = 0;
            return;
        }

        // If the current direction doesn't match the last direction, reset the counter.
        if (lastDirection !== 0 && lastDirection !== currentDirection) {
            dynamicResStableCount = 0;
        }

        // Update the lastDirection and count the consecutive reading.
        lastDirection = currentDirection;
        dynamicResStableCount++;

        // Update the resolution only if we've met the consecutive threshold.
        if (dynamicResStableCount >= pulseRuntimeSettings.requiredStableReading) {
            pulseRuntimeSettings.dynamicResolution = candidateRes;
            newAutoLevel = Math.ceil(depth)
            console.log("TAV: setting dynamicResolution to", candidateRes, "for depth", depth, "with newAutoLevel", newAutoLevel);
            // Reset counters after applying the update.
            dynamicResStableCount = 0;
            lastDirection = 0;
        }
    }
    */

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



