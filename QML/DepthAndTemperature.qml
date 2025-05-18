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
    property int    newAutoLevel :              0   // Shifter variable for the UI
    property bool   pulseBlueResSetOnce:        false //Set the resoution for blue only once
    //property int    initialResolutionSetter:    0
    property bool   initialResolutionSet:       true
    property string tempText:                   "-.-"
    property string depthText:                  "-.-"

    signal swapUnits()
    //signal pulseAutoLevelChanged(int newAutoLevel)

    // Function to calculate the autoLevel based on the current depth value.
    function calculateAutoLevel(depth) {
        const { autoDepthMinLevel, autoDepthLevelStep, autoDepthDistanceBelow, autoDepthMaxLevel } = pulseRuntimeSettings;

      if (depth === 0) {
        return Math.min(autoDepthDistanceBelow, autoDepthMinLevel);
      }

      if (depth < autoDepthLevelStep) {
        return autoDepthMinLevel + autoDepthDistanceBelow;
      }

      const steps = Math.floor((depth - autoDepthLevelStep) / autoDepthLevelStep) + 1;

      let displayed = autoDepthMinLevel + (steps * autoDepthLevelStep) + autoDepthDistanceBelow;

      if (typeof autoDepthMaxLevel !== "undefined") {
        displayed = Math.min(displayed, autoDepthMaxLevel + autoDepthDistanceBelow);
      }

      return displayed;
    }

    // This is the resolution updater that takes into account both depth integer steps and hysteresis.
    function updateDynamicResolutionWithStep(depth, candidateRes) {
        const step = pulseRuntimeSettings.autoDepthLevelStep || 1;

        let newLevel = Math.floor(depth / step);
        let lastLevel = Math.floor(lastStableDepth / step);

        if (newLevel === lastLevel) {
            stableCount = 0;
            return;
        }

        stableCount ++;

        if (stableCount < pulseRuntimeSettings.requiredStableReading) {
            return
        }

        pulseRuntimeSettings.dynamicResolution = candidateRes;
        console.log("TAV: setting dynamicResolution to", candidateRes,"for depth", depth, "with new integer level", newLevel);
        stableCount = 0;
        lastStableDepth = depth;

    }

    function calculateDynamicResolution(depth) {
        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
                || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlueProto) {
            if (!pulseBlueResSetOnce) {
                pulseBlueResSetOnce = true;
                pulseRuntimeSettings.dynamicResolution = pulseRuntimeSettings.chartResolution;
                console.log("TAV: set pulseRuntimeSettings.dynamicResolution just once to", pulseRuntimeSettings.dynamicResolution, "for", pulseRuntimeSettings.userManualSetName);
            }
            return;
        }
        if (pulseRuntimeSettings.userManualSetName !== pulseRuntimeSettings.modelPulseRed
                && pulseRuntimeSettings.userManualSetName !== pulseRuntimeSettings.modelPulseRedProto) {
            return;
        }

        const margin = pulseRuntimeSettings.dynamicResolutionMargin; // e.g., default 2 m.

        let candidateRes = Math.round((depth + margin) * 2);

        candidateRes = Math.max(candidateRes, pulseRuntimeSettings.dynamicResolutionMax);
        candidateRes = Math.min(candidateRes, pulseRuntimeSettings.dynamicResolutionMin);

        //console.log("TAV: set pulseRuntimeSettings.dynamicResolution just once to", pulseRuntimeSettings.dynamicResolution, "for", pulseRuntimeSettings.userManualSetName);

        updateDynamicResolutionWithStep(depth, candidateRes);
    }

    Timer {
        id: autoLevelTimer
        interval: 100  // Poll every 100ms; adjust as needed.
        running: true
        repeat: true
        onTriggered: {
            if (!pulseRuntimeSettings.isReceivingData) {
                //console.log("TAV: autoLevelTimer, not yet receiving data");
                //return  // We should maybe not do this as deoth data is OK to process anyway
            }
            if (!pulseRuntimeSettings.devConfigured) {
                //console.log("TAV: autoLevelTimer, device not yet configured");
                //return  // We should maybe not do this as deoth data is OK to process anyway
            }
            if (pulseRuntimeSettings.userManualSetName !== pulseRuntimeSettings.modelPulseRed
                    && pulseRuntimeSettings.userManualSetName !== pulseRuntimeSettings.modelPulseRedProto){
                //console.log("TAV: autoLevelTimer, Only do auto level when we have a pulseRed");
                return
            }

            autoLevelCalculate()
        }
    }

    function autoLevelCalculate () {
        let currentDepth = (dataset !== null) ? dataset.dist : 0;
        calculateDynamicResolution(currentDepth)
        let newLevel = calculateAutoLevel(depthAndTemperature.lastStableDepth);
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

    Connections {
        target: pulseRuntimeSettings
        function onDevConfiguredChanged () {
            if (pulseRuntimeSettings.devConfigured === true) {
                depthAndTemperature.initialResolutionSet = false
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
        if (!dataset) {
            return isMetric
              ? "0.0 °C"
              : "32.0 °F";
        }

        let tempC = dataset.temp;
        if (tempC !== 0) {
            tempC = tempC + pulseRuntimeSettings.temperatureCorrection
        }

        const tempF = tempC * (9/5) + 32;
        const value = isMetric ? tempC : tempF;

        return `${value.toFixed(1)} °${isMetric ? "C" : "F"}`;
    }

    property string displayDepth: depthAndTemperature.formatDepth()

    Timer {
        id: displayDepthTimer
        interval: 250
        repeat: true
        running: true
        onTriggered: {
            displayDepth = depthAndTemperature.formatDepth()
        }
    }

    property string displayTemp: depthAndTemperature.formatTemperature()

    Timer {
        id: displayTempTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            tempText = depthAndTemperature
                           .formatTemperature()
                           .split(" ")[0] || "-.-";
        }
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
                text: displayDepth.split('.')[0] + "."
                //text: depthAndTemperature.formatDepth().split('.')[0] + "."
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
                text: {
                    var parts = displayDepth.split('.');
                    return parts[1] ? parts[1].split(' ')[0] : "";
                }
                //text: depthAndTemperature.formatDepth().split('.')[1] ? depthAndTemperature.formatDepth().split('.')[1].split(' ')[0] : ""
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
                text: displayDepth.split(' ')[1] // Extract the unit (m or ft)
                //text: depthAndTemperature.formatDepth().split(' ')[1] // Extract the unit (m or ft)
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
                text: tempText
                //text: depthAndTemperature.displayTemp.split(' ')[0] || "-.-"
                //text: depthAndTemperature.formatTemperature().split(' ')[0] || "-.-"
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
        //depthAndTemperature.displayDepthTimer.start()
        //depthAndTemperature.displayTempTimer.start()
    }
}



