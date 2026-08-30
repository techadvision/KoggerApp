import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
//import QtGraphicalEffects 1.15
import Echo.UI 1.0
import QtQuick.Window


Item {
    id: depthAndTemperature

    // Values for the depth
    property double rangeFinderDepth: 0.0
    property double bottomTrackDepth: 0.0

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real platformScale: _isAndroid ? 0.9 : 0.75
    //readonly property real s: Ui.scale * platformScale
    readonly property real shortSide: Math.min(Screen.width, Screen.height)
    readonly property real s: Math.max(1.0, shortSide / 1100)

    // Base “design” size for this control on your 10" tablet
    readonly property int baseWidth: 350
    readonly property int baseHeight: 200

    // Natural size for layouts

    implicitWidth:  Math.round(baseWidth  * s)
    implicitHeight: Math.round(baseHeight * s)

    // Good defaults when NOT inside a layout
    width:  Math.round(baseWidth  * s)
    height: Math.round(baseHeight * s)
    clip: true

    /*
    width: _isAndroid ? 350 : 230
    height: _isAndroid ? 200 : 140
    clip: true

    property int fontPixelsBase:        96
    property int fontPixelsDepthInt:    96
    property int fontPixelsDepthDec:    72
    property int fontPixelsDepthUnit:   33
    property int fontPixelsTempInt:     72
    property int fontPixelsTempDec:     72
    property int fontPixelsTempUnit:    33
    */
    property int fontPixelsBase:        104
    property int fontPixelsDepthInt:    Math.round(fontPixelsBase * s)
    property int fontPixelsDepthDec:    Math.round(fontPixelsBase * s * 0.75)
    property int fontPixelsDepthUnit:   Math.round(fontPixelsBase * s * 0.33)
    property int fontPixelsTempInt:     Math.round(fontPixelsBase * s * 0.75)
    property int fontPixelsTempDec:     Math.round(fontPixelsBase * s * 0.50)
    property int fontPixelsTempUnit:    Math.round(fontPixelsBase * s * 0.33)


    property bool   dataAvailable:              false
    property bool   isMetric:                   pulseSettings.useMetricDepth
    property bool   isMetricTemperature:        pulseSettings.useMetricTemperature
    property bool   userShowTemperature:        pulseSettings.showTemperatureInUi
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
    property bool   enableTemperature:          pulseRuntimeSettings.is2DTransducer && pulseRuntimeSettings.pulseBetaName === "..."

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

        //console.log("TAV: dynamicResolution called with ", candidateRes,"and depth", depth)

        // Increase resolution size to look further into bottom composition, additional steps of 1 meter
        //candidateRes = candidateRes + (2 * pulseSettings.bottomCompositionAddition)
        //console.log("TAV: dynamicResolution:  considering bottomCompositionAddition, new candidateRes ", candidateRes)

        pulseRuntimeSettings.dynamicResolution = candidateRes;
        //Back to the shortest period — numerically the minimum.
        if (pulseRuntimeSettings.dynamicPeriod !== pulseRuntimeSettings.dynamicPeriodMin) {
            pulseRuntimeSettings.dynamicPeriod = pulseRuntimeSettings.dynamicPeriodMin
        }
        //Back to the fewest samples — numerically the minimum.
        if (pulseRuntimeSettings.dynamicSamples !== pulseRuntimeSettings.dynamicSamplesMin) {
            pulseRuntimeSettings.dynamicSamples = pulseRuntimeSettings.dynamicSamplesMin
        }

        //console.log("DYNAMIC: setting dynamicResolution to", candidateRes,"for depth", depth,"compared to last stable", lastStableDepth,"and bottom composition addition", pulseSettings.doubleEchoOptimize, "with new integer level", newLevel, "compared to last level", lastLevel)
        stableCount = 0
        lastStableDepth = depth
        pulseRuntimeSettings.forceUpdateResolution = false

    }

    function calculateDynamicResolution(depth) {
        //DEMO MODE: the resolution and period are already baked into the
        //recording. Recomputing them is at best a write to a null link and at
        //worst UI oscillation as the replayed "boat" crosses depth steps.
        //The auto DISPLAY level in autoLevelCalculate() is deliberately left
        //running — it only changes what the echogram shows, and it looks right.
        if (pulseRuntimeSettings.isInDemoMode) {
            return;
        }

        if (pulseRuntimeSettings.userManualSetName !== pulseRuntimeSettings.modelPulseRed
                && pulseRuntimeSettings.userManualSetName !== pulseRuntimeSettings.modelPulseRedProto) {
            return;
        }

        const margin = pulseRuntimeSettings.dynamicResolutionMargin; // e.g., default 2 m.

        let candidateRes = Math.round((depth + margin) * 2);

        if (pulseSettings.doubleEchoOptimize) {
            candidateRes = Math.round(( 2* depth + margin) * 2);
        }

        if (candidateRes <= 50) {
            candidateRes = Math.max(candidateRes, pulseRuntimeSettings.dynamicResolutionMin);
            candidateRes = Math.min(candidateRes, pulseRuntimeSettings.dynamicResolutionMax);
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
        candidateSamples = Math.max(candidateSamples, pulseRuntimeSettings.dynamicSamplesMin);
        candidateSamples = Math.min(candidateSamples, pulseRuntimeSettings.dynamicSamplesMax);

        //dynamicResolutionMax = the COARSEST spacing (50 mm). Was spelled ...Min before the
        //2026-08-29 numeric-convention swap; the value it reads is unchanged.
        let candidatePeriod = candidateRes + (candidateRes - pulseRuntimeSettings.dynamicResolutionMax)
        //console.log("DYNAMIC: candidatePeriod suggested as", candidatePeriod)
        candidatePeriod = Math.max(candidatePeriod, pulseRuntimeSettings.dynamicPeriodMin);
        candidatePeriod = Math.min(candidatePeriod, pulseRuntimeSettings.dynamicPeriodMax);

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
        //console.log("DYNAMIC: stepped stableCount up by one")

        if (stableCount < pulseRuntimeSettings.requiredStableReading) {
            //console.log("DYNAMIC: stableCount below threshold of", pulseRuntimeSettings.requiredStableReading)
            return
        }

        // Add +20 to period if depth changed to a deeper step
        if (depth > lastStableDepth) {
            candidateSamples = candidateSamples + pulseRuntimeSettings.dynamicSamplesStep
            candidatePeriod = candidatePeriod + pulseRuntimeSettings.dynamicPeriodStep
           // console.log("DYNAMIC: increased candidateSamples ",candidateSamples, "and candidatePeriod",candidatePeriod, ": depth deeper than before ", depth," > lastStableDepth", lastStableDepth)
        }


        pulseRuntimeSettings.dynamicSamples = candidateSamples;
        pulseRuntimeSettings.dynamicPeriod = candidatePeriod;
        //console.log("DYNAMIC: set dynamicSamples ",candidateSamples, "and dynamicPeriod",candidatePeriod, "for depth", depth,"with bottom composition addition", pulseSettings.doubleEchoOptimize, "with new integer level", newLevel, "compared to last level", lastLevel, "based on candidateRes", candidateRes)
        stableCount = 0
        lastStableDepth = depth
    }

    Timer {
        id: autoLevelTimer
        interval: 100  // Poll every 100ms; adjust as needed.
        running: true
        repeat: true
        onTriggered: {
            autoLevelCalculate()
        }
    }

    function currentDepthValue() {
        if (dataset === null)
            return 0
        if (pulseRuntimeSettings === null)
            return 0

        if (pulseRuntimeSettings.isBottomTrackInitiated) {
            //console.log("DistProcessing: Depth in UI from dataset.bottomTrackDepth as", dataset.bottomTrackDepth, "since pulseRuntimeSettings.isBottomTrackInitiated is", pulseRuntimeSettings.isBottomTrackInitiated)
            //return dataset.bottomTrackDepth
            return bottomTrackDepth
        } else {
            //console.log("DistProcessing: Depth in UI from dataset.dist as", dataset.dist, "since pulseRuntimeSettings.isBottomTrackInitiated is", pulseRuntimeSettings.isBottomTrackInitiated)
            // return dataset.dist
            return rangeFinderDepth
        }
    }

    function autoLevelCalculate () {
        //let currentDepth = (dataset !== null) ? dataset.dist : 0;
        let currentDepth = currentDepthValue()
        calculateDynamicResolution(currentDepth)
        let newLevel = calculateAutoLevel(depthAndTemperature.lastStableDepth);
        if (newLevel !== depthAndTemperature.autoLevel) {
            depthAndTemperature.autoLevel = newLevel;
            if (pulseRuntimeSettings !== null) {
                pulseRuntimeSettings.autoDepthMaxLevel = newLevel
                //console.log("TAV: Auto level changed to: " + newLevel);
                //console.log("TAV: Auto level step: " + pulseRuntimeSettings.autoDepthLevelStep);
                //console.log("TAV: Auto level distance below: " + pulseRuntimeSettings.autoDepthDistanceBelow);
            } else {
                console.log("TAV: Auto level cannot be set when pulseRuntimeSettings is null");
            }
        }
    }

    Connections {
        target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined

        function onDynamicResolutionInitChanged () {
            if (pulseRuntimeSettings.dynamicResolutionInit) {
                //DEMO MODE: do not kick off a resolution pass for a ghost device.
                if (pulseRuntimeSettings.isInDemoMode) {
                    pulseRuntimeSettings.dynamicResolutionInit = false
                    return
                }
                initialAutoLevelCalculatorTimer.start()
                pulseRuntimeSettings.dynamicResolutionInit = false
            }
        }
        //function onSwapDeviceNow
    }

    Connections {
        target: pulseSettings ? pulseSettings : undefined
        function onDoubleEchoOptimizeChanged () {
            //DEMO MODE: no resolution writes while replaying.
            if (pulseRuntimeSettings.isInDemoMode)
                return
            pulseRuntimeSettings.forceUpdateResolution = true
        }
    }

    Connections {
        target: dataset ? dataset : undefined

        function onDistChanged () {
            //console.log("DistProcessing: onDistChanged observed: Distance =", dataset.dist);
            // Ignore NaN/inf so the display holds the last good value instead of showing NaN.
            if (Number.isFinite(dataset.dist)) {
                rangeFinderDepth = dataset.dist
            }
        }

        // Use the SAME filtered, offset-corrected bottom-track value that NMEA sends
        // (dataset.bottomTrackDepth = filterDepthRecords(rawDist + transducerOffsetMount + fake)).
        // Previously this read dataset.getLastDepth() (= raw, unfiltered lastDepth_), which made
        // the bottom-track display noisy and disagree with the NMEA output.
        function onBottomTrackDepthChanged () {
            //console.log("DistProcessing: onBottomTrackDepthChanged observed: Depth =", dataset.bottomTrackDepth);
            // Ignore NaN/inf (e.g. _bottomTrackDepth before the first valid bottom) so the
            // display keeps the last good value instead of showing NaN.
            if (Number.isFinite(dataset.bottomTrackDepth)) {
                bottomTrackDepth = dataset.bottomTrackDepth
            }
        }
    }

    Timer {
        id: initialAutoLevelCalculatorTimer
        repeat: false
        interval: 1000
        onTriggered: {
            //DEMO MODE: no resolution writes while replaying.
            if (pulseRuntimeSettings.isInDemoMode)
                return
            pulseRuntimeSettings.forceUpdateResolution = true
            //console.log("TAV: dynamicResolution: Set the pulseRuntimeSettings.forceUpdateResolution to", pulseRuntimeSettings.forceUpdateResolution);
        }
    }

    function formatDepth() {
        //let depthInMeters = (dataset !== null) ? dataset.dist : 0
        let depthInMeters = currentDepthValue()
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

        let tempC = dataset.temp;

        const tempF = tempC * (9/5) + 32;
        const value = isMetricTemperature ? tempC : tempF;

        return `${value.toFixed(1)} °${isMetricTemperature ? "C" : "F"}`;
    }

    property string displayDepth: depthAndTemperature.formatDepth()

    Timer {
        id: displayDepthTimer
        interval: {
            return 250
        }
        repeat: true
        running: true
        onTriggered: {
            // Only refresh when the current depth is a real number; otherwise keep the last
            // good displayDepth so the UI never shows "NaN".
            if (Number.isFinite(depthAndTemperature.currentDepthValue())) {
                displayDepth = depthAndTemperature.formatDepth()
            }
        }
    }

    property string displayTemp: depthAndTemperature.formatTemperature()

    Timer {
        id: displayTempTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            // Only refresh when temperature is a real number; otherwise keep the last good
            // value so the UI never shows "NaN".
            if (dataset && Number.isFinite(dataset.temp)) {
                tempText = depthAndTemperature
                               .formatTemperature()
                               .split(" ")[0] || "-.-";
            }
        }
    }


    Rectangle {
        id: depthTempRect
        width: depthAndTemperature.width
        height: depthAndTemperature.height
        color: "transparent"
        radius: parent.height / 2

        // CATCH‐ALL MOUSEAREA – blocks clicks from passing through to the pinch
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: false
            preventStealing: true
            onPressed: { /* nothing – absorb */ }
        }


        // Property to count the taps
        property int tapCount: 0


        // Depth Value (Whole Number Part)
        Rectangle {
            id: wholeNumberRect
            width: parent.width * 0.75
            //height: _isAndroid? 96 : 64
            height: depthAndTemperature.fontPixelsDepthInt
            color: "transparent"
            //color: "#80000000"
            anchors.right: decimalPartRect.left
            anchors.bottom: decimalPartRect.bottom
            anchors.topMargin: 20

            Text {
                id: wholeNumber
                text: displayDepth.split('.')[0] + "."
                //text: depthAndTemperature.formatDepth().split('.')[0] + "."
                color: "white"
                style: Text.Outline            // 1px outline
                styleColor: "black"            // outline color
                renderType: Text.NativeRendering  // crisper on many platforms
                font.bold: true
                //font.pixelSize: _isAndroid ? 96 : 64
                font.pixelSize: depthAndTemperature.fontPixelsDepthInt
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }

        }

        // Depth Value (Decimal Part)
        Rectangle {
            id: decimalPartRect
            width: parent.width * 0.1
            //height: _isAndroid? 96 : 64
            height: depthAndTemperature.fontPixelsDepthInt
            color: "transparent"
            //color: "#80000000"
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
                style: Text.Outline            // 1px outline
                styleColor: "black"            // outline color
                renderType: Text.NativeRendering  // crisper on many platforms
                //font.pixelSize: _isAndroid ? 72 : 48
                font.pixelSize: depthAndTemperature.fontPixelsDepthDec
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.top: parent.top
            }
        }

        // Unit (m or ft)
        Rectangle {
            id: depthUnitRect
            width: parent.width * 0.15
            //height: _isAndroid ? 96 : 64
            height: depthAndTemperature.fontPixelsDepthInt
            color: "transparent"
            //color: "#80000000"
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.rightMargin: 50

            Text {
                id: depthUnit
                text: displayDepth.split(' ')[1] // Extract the unit (m or ft)
                color: "white"
                style: Text.Outline            // 1px outline
                styleColor: "black"            // outline color
                renderType: Text.NativeRendering  // crisper on many platforms
                //font.pixelSize: _isAndroid ? 36 : 24
                font.pixelSize: depthAndTemperature.fontPixelsDepthUnit
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 15
            }
        }

        // Temperature Value
        Rectangle {
            id: temperatureValueRect
            width: parent.width * 0.73
            //height: _isAndroid ? 72 : 48
            height: depthAndTemperature.fontPixelsTempInt
            color: "transparent"
            anchors.right: decimalTempPartRect.left
            anchors.top: decimalTempPartRect.top
            //anchors.topMargin: 10
            visible: pulseRuntimeSettings.useTemperature && enableTemperature && userShowTemperature

            Text {
                id: temperatureValue
                //text: tempText
                text: tempText.split('.')[0] + "."
                color: "white"
                style: Text.Outline            // 1px outline
                styleColor: "black"            // outline color
                renderType: Text.NativeRendering  // crisper on many platforms
                //font.pixelSize: _isAndroid ? 72 : 48
                font.pixelSize: depthAndTemperature.fontPixelsTempInt
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Temperature Value (Decimal Part)
        Rectangle {
            id: decimalTempPartRect
            width: parent.width * 0.12
            //height: _isAndroid? 96 : 64
            height: depthAndTemperature.fontPixelsDepthInt
            color: "transparent"
            //color: "#80000000"
            anchors.right: temperatureUnitRect.left
            anchors.top: depthUnitRect.bottom
            anchors.topMargin: 10
            visible: pulseRuntimeSettings.useTemperature && enableTemperature && userShowTemperature

            Text {
                id: decimalTempPart
                text: {
                    var parts = tempText.split('.');
                    return parts[1] ? parts[1].split(' ')[0] : "";
                }
                //text: depthAndTemperature.formatDepth().split('.')[1] ? depthAndTemperature.formatDepth().split('.')[1].split(' ')[0] : ""
                color: "white"
                style: Text.Outline            // 1px outline
                styleColor: "black"            // outline color
                renderType: Text.NativeRendering  // crisper on many platforms
                //font.pixelSize: _isAndroid ? 72 : 48
                font.pixelSize: depthAndTemperature.fontPixelsTempDec
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.top: parent.top
            }
        }

        // Temperature Unit (°C or °F)
        Rectangle {
            id: temperatureUnitRect
            width: parent.width * 0.15
            //height: _isAndroid ? 72 :
            height: depthAndTemperature.fontPixelsTempUnit
            color: "transparent"
            //color: "#80000000"
            anchors.right: depthUnitRect.right
            anchors.top: depthUnitRect.bottom
            anchors.topMargin: 10
            visible: pulseRuntimeSettings.useTemperature && enableTemperature && userShowTemperature

            Text {
                id: temperatureUnit
                text: depthAndTemperature.formatTemperature().split(' ')[1] // Temperature unit
                color: "white"
                style: Text.Outline            // 1px outline
                styleColor: "black"            // outline color
                renderType: Text.NativeRendering  // crisper on many platforms
                //font.pixelSize: _isAndroid ? 36 : 24
                font.pixelSize: depthAndTemperature.fontPixelsTempUnit
                horizontalAlignment: Text.AlignLeft
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 15
            }
        }
    }

        Component.onCompleted: {
            pulseRuntimeSettings.useMetricDepth = pulseSettings.useMetricDepth
            //plot2DGrid.setMeasuresMetric(pulseSettings.useMetricDepth)
        }

        Connections {
            target: pulseSettings ? pulseSettings : undefined
            function onUseMetricDepthChanged () {
                pulseRuntimeSettings.useMetricDepth = pulseSettings.useMetricDepth
                //plot2DGrid.setMeasuresMetric(pulseSettings.useMetricDepth)
            }
            function onUseMetricTemperatureChanged () {
                // do nothing!
            }
            function onShowTemperatureInUiChanged () {
                // do nothing!
        }
    }
}



