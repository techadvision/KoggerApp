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
    property bool   isMetric:                   PulseSettings.useMetricDepth
    property bool   isMetricTemperature:        PulseSettings.useMetricTemperature
    property bool   userShowTemperature:        PulseSettings.showTemperatureInUi
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
    property bool   forceUpdateResolution:      false
    property bool   enableTemperature:          false

    signal swapUnits()
    //signal pulseAutoLevelChanged(int newAutoLevel)

    // Function to calculate the autoLevel based on the current depth value.
    function calculateAutoLevel(depth) {
        const { autoDepthMinLevel, autoDepthLevelStep, autoDepthDistanceBelow, autoDepthMaxLevel } = pulseRuntimeSettings;


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

        if (!pulseRuntimeSettings.forceUpdateResolution) {
            if (newLevel === lastLevel) {
                stableCount = 0;
                return;
            }

            stableCount ++;

            if (stableCount < pulseRuntimeSettings.requiredStableReading) {
                return
            }

            // Add +2 to resolution if depth changed to a deeper step
            if (depth > lastStableDepth) {
                candidateRes = candidateRes + 2
                console.log("DYNAMIC: dynamicResolution: depth ", depth," > lastStableDepth", lastStableDepth, ", new candidateRes ", candidateRes)
            }
        }

        console.log("TAV: dynamicResolution called with ", candidateRes,"and depth", depth)

        // Increase resolution size to look further into bottom composition, additional steps of 1 meter
        //candidateRes = candidateRes + (2 * PulseSettings.bottomCompositionAddition)
        console.log("TAV: dynamicResolution:  considering bottomCompositionAddition, new candidateRes ", candidateRes)

        pulseRuntimeSettings.dynamicResolution = candidateRes;
        if (pulseRuntimeSettings.dynamicPeriod !== pulseRuntimeSettings.dynamicPeriodMax) {
            pulseRuntimeSettings.dynamicPeriod = pulseRuntimeSettings.dynamicPeriodMax
        }
        if (pulseRuntimeSettings.dynamicSamples !== pulseRuntimeSettings.dynamicSamplesMax) {
            pulseRuntimeSettings.dynamicSamples = pulseRuntimeSettings.dynamicSamplesMax
        }

        console.log("DYNAMIC: setting dynamicResolution to", candidateRes,"for depth", depth,"compared to last stable", lastStableDepth,"and bottom composition addition", PulseSettings.doubleEchoOptimize, "with new integer level", newLevel, "compared to last level", lastLevel)
        stableCount = 0
        lastStableDepth = depth
        pulseRuntimeSettings.forceUpdateResolution = false

    }

    function calculateDynamicResolution(depth) {
        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
                || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlueProto) {
            if (!pulseRuntimeSettings.pulseBlueResSetOnce) {
                pulseRuntimeSettings.pulseBlueResSetOnce = true;
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

        if (PulseSettings.doubleEchoOptimize) {
            candidateRes = Math.round(( 2* depth + margin) * 2);
        }

        if (candidateRes <= 50) {
            candidateRes = Math.max(candidateRes, pulseRuntimeSettings.dynamicResolutionMax);
            candidateRes = Math.min(candidateRes, pulseRuntimeSettings.dynamicResolutionMin);
            updateDynamicResolutionWithStep(depth, candidateRes);
        } else {
            updateDynamicSamplesAndPeriod (depth, candidateRes)
        }


    }

    function updateDynamicSamplesAndPeriod (depth, candidateRes) {

        if (!pulseRuntimeSettings.devConfigured) {
            console.log("DYNAMIC: avoid updateDynamicSamplesAndPeriod until dev is configured")
            return
        }

        let candidateSamples = candidateRes * 10
        //console.log("DYNAMIC: candidateSamples suggested as", candidateSamples)
        candidateSamples = Math.max(candidateSamples, pulseRuntimeSettings.dynamicSamplesMax);
        candidateSamples = Math.min(candidateSamples, pulseRuntimeSettings.dynamicSamplesMin);

        let candidatePeriod = candidateRes + (candidateRes - pulseRuntimeSettings.dynamicResolutionMin)
        //console.log("DYNAMIC: candidatePeriod suggested as", candidatePeriod)
        candidatePeriod = Math.max(candidatePeriod, pulseRuntimeSettings.dynamicPeriodMax);
        candidatePeriod = Math.min(candidatePeriod, pulseRuntimeSettings.dynamicPeriodMin);

        //console.log("DYNAMIC: allowed candidateSamples of", candidateSamples, "and candidatePeriod of", candidatePeriod)

        updateDynamicPeriodAndSamplesWithStep (depth, candidatePeriod, candidateSamples, candidateRes)
    }

    function updateDynamicPeriodAndSamplesWithStep(depth, candidatePeriod, candidateSamples, candidateRes) {
        const step = pulseRuntimeSettings.autoDepthLevelStep || 1;

        let newLevel = Math.floor(depth / step);
        let lastLevel = Math.floor(lastStableDepth / step);

        if (newLevel === lastLevel) {
            stableCount = 0;
            return;
        }

        stableCount ++;
        console.log("DYNAMIC: stepped stableCount up by one")

        if (stableCount < pulseRuntimeSettings.requiredStableReading) {
            console.log("DYNAMIC: stableCount below threshold of", pulseRuntimeSettings.requiredStableReading)
            return
        }

        // Add +20 to period if depth changed to a deeper step
        if (depth > lastStableDepth) {
            candidateSamples = candidateSamples + pulseRuntimeSettings.dynamicSamplesStep
            candidatePeriod = candidatePeriod + pulseRuntimeSettings.dynamicPeriodStep
            console.log("DYNAMIC: increased candidateSamples ",candidateSamples, "and candidatePeriod",candidatePeriod, ": depth deeper than before ", depth," > lastStableDepth", lastStableDepth)
        }


        pulseRuntimeSettings.dynamicSamples = candidateSamples;
        pulseRuntimeSettings.dynamicPeriod = candidatePeriod;
        console.log("DYNAMIC: set dynamicSamples ",candidateSamples, "and dynamicPeriod",candidatePeriod, "for depth", depth,"with bottom composition addition", PulseSettings.doubleEchoOptimize, "with new integer level", newLevel, "compared to last level", lastLevel, "based on candidateRes", candidateRes)
        stableCount = 0
        lastStableDepth = depth
    }

    Timer {
        id: autoLevelTimer
        interval: 100  // Poll every 100ms; adjust as needed.
        running: true
        repeat: true
        onTriggered: {
            if (!pulseRuntimeSettings.isReceivingData) {
                //console.log("TAV: autoLevelTimer, not yet receiving data");
                //return  // We should maybe not do this as depth data is OK to process anyway
            }
            if (!pulseRuntimeSettings.devConfigured) {
                //console.log("TAV: autoLevelTimer, device not yet configured");
                return  // We should maybe not do this as depth data is OK to process anyway
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
        target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined

        function onDynamicResolutionInitChanged () {
            if (pulseRuntimeSettings.dynamicResolutionInit) {
                initialAutoLevelCalculatorTimer.start()
                pulseRuntimeSettings.dynamicResolutionInit = false
            }
        }
        //function onSwapDeviceNow
    }

    Connections {
        target: PulseSettings ? PulseSettings : undefined
        function onDoubleEchoOptimizeChanged () {
            pulseRuntimeSettings.forceUpdateResolution = true
        }
    }

    Timer {
        id: initialAutoLevelCalculatorTimer
        repeat: false
        interval: 1000
        onTriggered: {
            pulseRuntimeSettings.forceUpdateResolution = true
            console.log("TAV: dynamicResolution: Set the pulseRuntimeSettings.forceUpdateResolution to", pulseRuntimeSettings.forceUpdateResolution);
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
            return isMetricTemperature
              ? "0.0 °C"
              : "32.0 °F";
        }

        if (dataset) {
            if (dataset.temp) {
                if (dataset.temp !== 0) {
                    if (userShowTemperature) {
                        enableTemperature = true
                    }
                }
            }
        }

        let tempC = dataset.temp;

        const tempF = tempC * (9/5) + 32;
        const value = isMetricTemperature ? tempC : tempF;

        return `${value.toFixed(1)} °${isMetricTemperature ? "C" : "F"}`;
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
        /*
        Timer {
            id: tapResetTimer
            interval: 5000  // 5 seconds
            repeat: false
            onTriggered: depthTempRect.tapCount = 0
        }
        */

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
            anchors.topMargin: 10
            anchors.rightMargin: 50

            Text {
                id: depthUnit
                text: displayDepth.split(' ')[1] // Extract the unit (m or ft)
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
            visible: pulseRuntimeSettings.useTemperature && enableTemperature && userShowTemperature

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
            visible: pulseRuntimeSettings.useTemperature && enableTemperature && userShowTemperature

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

        Connections {
        target: PulseSettings
        function onUseMetricDepthChanged () {
            setMeasuresMetricNow(PulseSettings.useMetricDepth)
        }
        function onUseMetricTemperatureChanged () {
            // do nothing!
        }
        function onShowTemperatureInUiChanged () {
            // do nothing!
        }
    }
}



