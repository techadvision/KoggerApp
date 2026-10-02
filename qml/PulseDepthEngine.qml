import QtQuick 2.15

// THE DEPTH ENGINE - the half of DepthAndTemperature.qml that was never a readout.
//
// WHY THIS FILE EXISTS. DepthAndTemperature.qml is 640 lines of which only the last 200
// draw anything. The rest is machinery: it takes the depth off the dataset, runs the auto
// DISPLAY level, and computes the dynamic resolution - writing pulseRuntimeSettings'
// dynamicSamples and dynamicPeriod, which DeviceItem.qml turns into chartSamples and
// ch1Period on the transducer itself.
//
// That machinery was reachable only by instantiating the readout. PulseAppV2 does not
// instantiate it, so in v2 NOTHING wrote those three keys and the sounder ran at the
// defaults - 500 samples, 50 ms period - at every depth. Not a cosmetic gap: the
// resolution behaviour the classic UI depends on was simply absent behind the new one.
//
// ONE INSTANCE, ABOVE BOTH PANES, in main.qml - the same move the connection screen, the
// setup overlay and the pill column already made. Everything here is app-wide by nature:
// there is one dataset, one transducer and one set of runtime keys. Per-pane it ran twice
// in a split screen, two 100 ms timers writing the same keys from two copies of
// lastStableDepth and stableCount. That is now impossible by construction.
//
// WHAT THE READOUTS GET. One key, pulseRuntimeSettings.depthMeters, written here and
// nowhere else. The rule for CHOOSING the depth - bottom track first, rangefinder when
// bottom track is not initiated, NaN never published - lives in this file only, so the
// two readouts cannot disagree about which source they are showing.
//
// Deliberately NOT carried over from the old file: newAutoLevel, pulseBlueResSetOnce,
// initialResolutionSet, dynamicResStableCount, lastDirection and a local
// forceUpdateResolution shadowing the runtime key of the same name. Each is declared once
// in DepthAndTemperature.qml and read nowhere, in this file or any other.
//
// The bottomTrackMinDepth crossover - rangefinder below ~0.5 m, bottom track above - is
// still not implemented here. It has to key off the RANGEFINDER value to know which side
// of the threshold it is on, and it belongs with the depth readout work. It stays on the
// todo rather than arriving unannounced inside an extraction.
Item {
    id: depthEngine

    visible: false
    width:   0
    height:  0

    // ---- The two sources, held at their last GOOD value ---------------------

    property double rangeFinderDepth: 0.0
    property double bottomTrackDepth: 0.0

    // ---- The chosen depth. ONE binding, ONE writer of the runtime key -------
    //
    // The choice is a binding because isBottomTrackInitiated can flip while the app is
    // running and the answer must follow it. The publish is a handler because
    // pulseRuntimeSettings.depthMeters has exactly one writer and nothing binds it -
    // which is not the shape rule 2 forbids.
    // WHAT THE DATA IS, not how it is drawn (2 Oct 2026, for 1.42). Olav: the down scan
    // full screen "will, after you have used split screen side/down, sometimes only show
    // 0.0 meters for the depth." The test used to be !displayIs2DTransducer &&
    // !isSideScan2DView - so a blue's DOWN SCAN counted as a 2D picture and read the 2D
    // branch below: the rangefinder, because isBottomTrackInitiated is false in v2. A blue
    // has no nadir rangefinder whichever way it is drawn, so rangeFinderDepth sat at 0.0
    // (or at whatever a previous source left in it - hence "sometimes"). In the side +
    // down split the full-screen picture is the side scan, isSideScan2DView is false, and
    // the readout on the side pane was right; going to full-screen down flipped it.
    //
    // Still rule 1 - the DISPLAY model, so a blue log on a committed red is a side scan
    // here too. Only the view stopped counting.
    readonly property bool depthFromSideScan:
        pulseRuntimeSettings ? !pulseRuntimeSettings.displayIs2DTransducer : false

    onDepthFromSideScanChanged: console.log("DEPTH: source ->",
        depthFromSideScan ? "side scan data - bottom track first, rangefinder behind it"
                          : "2D - " + ((pulseRuntimeSettings && pulseRuntimeSettings.isBottomTrackInitiated)
                                       ? "bottom track" : "rangefinder"))

    // THE SIDE SCAN FOLLOWS THE BOTTOM TRACK PRIMARILY, which is what it always did -
    // Olav, 14 Sept: "Side scan should follow the bottom track depth primarily. Like it
    // used to." isBottomTrackInitiated is the wrong question to ask of it: that flag is
    // written from DisplaySettings and the expert panel, neither of which v2 instantiates,
    // so in v2 it is false unless an expert has been in and turned it on. The same shape as
    // the engine itself, which was reachable only through DepthAndTemperature.
    //
    // PRIMARILY, not only. A bottom track that has never produced a value leaves
    // bottomTrackDepth at 0.0, and 0.0 is finite, so the guards upstream let it through as
    // if it were a reading. Falling back to the rangefinder costs nothing when the bottom
    // track is working and is the difference between a number and a zero when it is not.
    readonly property double selectedDepth:
        depthFromSideScan
            ? (bottomTrackDepth > 0 ? bottomTrackDepth : rangeFinderDepth)
            : ((pulseRuntimeSettings && pulseRuntimeSettings.isBottomTrackInitiated)
                   ? bottomTrackDepth
                   : rangeFinderDepth)

    onSelectedDepthChanged: {
        if (pulseRuntimeSettings)
            pulseRuntimeSettings.depthMeters = selectedDepth
    }

    function currentDepthValue() {
        if (dataset === null)
            return 0
        if (pulseRuntimeSettings === null)
            return 0
        return selectedDepth
    }

    // ---- Auto DISPLAY level and dynamic resolution state --------------------

    property double autoLevel:       2   // default value (for depth 0)
    property double lastStableDepth: 0   // Depth at which we last updated the resolution.
    property int    stableCount:     0   // Counter for consecutive stable readings.

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

        // Increase resolution size to look further into bottom composition, additional steps of 1 meter
        //candidateRes = candidateRes + (2 * pulseSettings.bottomCompositionAddition)

        pulseRuntimeSettings.dynamicResolution = candidateRes;
        //Back to the shortest period - numerically the minimum.
        if (pulseRuntimeSettings.dynamicPeriod !== pulseRuntimeSettings.dynamicPeriodMin) {
            pulseRuntimeSettings.dynamicPeriod = pulseRuntimeSettings.dynamicPeriodMin
        }
        //Back to the fewest samples - numerically the minimum.
        if (pulseRuntimeSettings.dynamicSamples !== pulseRuntimeSettings.dynamicSamplesMin) {
            pulseRuntimeSettings.dynamicSamples = pulseRuntimeSettings.dynamicSamplesMin
        }

        stableCount = 0
        lastStableDepth = depth
        pulseRuntimeSettings.forceUpdateResolution = false
    }

    function calculateDynamicResolution(depth) {
        //DEMO MODE: the resolution and period are already baked into the
        //recording. Recomputing them is at best a write to a null link and at
        //worst UI oscillation as the replayed "boat" crosses depth steps.
        //The auto DISPLAY level in autoLevelCalculate() is deliberately left
        //running - it only changes what the echogram shows, and it looks right.
        if (pulseRuntimeSettings.isInDemoMode) {
            return false;
        }

        if (pulseRuntimeSettings.userManualSetName !== pulseRuntimeSettings.modelPulseRed
                && pulseRuntimeSettings.userManualSetName !== pulseRuntimeSettings.modelPulseRedProto) {
            return false;
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
        return true
    }

    function updateDynamicSamplesAndPeriod (depth, candidateRes) {

        if (!pulseRuntimeSettings.devConfigured) {
            console.log("DYNAMIC: avoid updateDynamicSamplesAndPeriod until dev is configured")
            return
        }

        let candidateSamples = candidateRes * 10
        candidateSamples = Math.max(candidateSamples, pulseRuntimeSettings.dynamicSamplesMin);
        candidateSamples = Math.min(candidateSamples, pulseRuntimeSettings.dynamicSamplesMax);

        //dynamicResolutionMax = the COARSEST spacing (50 mm). Was spelled ...Min before the
        //2026-08-29 numeric-convention swap; the value it reads is unchanged.
        let candidatePeriod = candidateRes + (candidateRes - pulseRuntimeSettings.dynamicResolutionMax)
        candidatePeriod = Math.max(candidatePeriod, pulseRuntimeSettings.dynamicPeriodMin);
        candidatePeriod = Math.min(candidatePeriod, pulseRuntimeSettings.dynamicPeriodMax);

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

        if (stableCount < pulseRuntimeSettings.requiredStableReading) {
            return
        }

        // Add +20 to period if depth changed to a deeper step
        if (depth > lastStableDepth) {
            candidateSamples = candidateSamples + pulseRuntimeSettings.dynamicSamplesStep
            candidatePeriod = candidatePeriod + pulseRuntimeSettings.dynamicPeriodStep
        }

        pulseRuntimeSettings.dynamicSamples = candidateSamples;
        pulseRuntimeSettings.dynamicPeriod = candidatePeriod;
        stableCount = 0
        lastStableDepth = depth
    }

    // ---- The display level's own depth tracker (27 Sept 2026) -----------------
    //
    // Olav: automatic range works on the water, but in a SIMULATION "either the end depth or
    // the start depth kind of determines the automatic range to be fixed."
    //
    // THE DISPLAY LEVEL WAS FED BY THE RESOLUTION TRACKER. autoLevel is
    // calculateAutoLevel(lastStableDepth), and lastStableDepth is written ONLY inside the two
    // dynamic-resolution updaters - which calculateDynamicResolution() deliberately never
    // reaches in a demo (the resolution is baked into the recording). So in a demo the
    // display level read a frozen number: 0 on a cold start (the shallow start range), or
    // whatever depth the last live session or demo pass left behind (the "end depth").
    // The comment in calculateDynamicResolution said the display level was "deliberately
    // left running" - the timer was, its input was not.
    //
    // THE SAME TRACKER SHAPE, ON ITS OWN STATE: the same step and the same stable-reading
    // count as the resolution's, so a demo's range moves exactly as a live one does. Used
    // whenever the resolution tracker did not run this tick - a demo, and also a live
    // transducer the dynamic resolution does not manage. The live red path is unchanged.
    property double displayStableDepth: 0
    property int    displayStableCount: 0

    function trackDisplayDepth(depth) {
        if (!Number.isFinite(depth) || depth <= 0)
            return
        const step = pulseRuntimeSettings.autoDepthLevelStep || 1;
        if (Math.floor(depth / step) === Math.floor(displayStableDepth / step)) {
            displayStableCount = 0
            return
        }
        displayStableCount++
        if (displayStableCount < pulseRuntimeSettings.requiredStableReading)
            return
        displayStableDepth = depth
        displayStableCount = 0
    }

    // A new demo, or leaving one, starts the tracker from nothing, so no depth from the
    // previous source can hold the range.
    Connections {
        target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
        function onIsInDemoModeChanged() {
            depthEngine.displayStableDepth = 0
            depthEngine.displayStableCount = 0
        }
    }

    function autoLevelCalculate () {
        let currentDepth = currentDepthValue()
        const resolutionTracked = calculateDynamicResolution(currentDepth) === true
        if (!resolutionTracked)
            trackDisplayDepth(currentDepth)
        // THE SECOND ECHO (27 Sept). A user who turns on "Optimise for a second echo" wants
        // automatic range to show the first TWO echoes, and the second one sits at twice the
        // depth. Until now only the dynamic resolution honoured it (candidateRes from
        // 2 x depth in calculateDynamicResolution) - that sizes what the transducer SAMPLES,
        // and the display level still followed the single depth, so the second echo was
        // sampled and then ranged off the screen. The same doubling now reaches the display
        // level, in every mode: live, simulation and file. It is the user's preference, not
        // a property of the recording, so nothing has to be read from the log. 2D only - the
        // same scope as the preference row and as automatic range itself.
        const echoFactor = (pulseSettings && pulseSettings.doubleEchoOptimize
                            && pulseRuntimeSettings.displayIs2DTransducer) ? 2 : 1
        let newLevel = calculateAutoLevel(echoFactor * (resolutionTracked ? depthEngine.lastStableDepth
                                                                          : depthEngine.displayStableDepth));
        if (newLevel !== depthEngine.autoLevel) {
            depthEngine.autoLevel = newLevel;
            if (pulseRuntimeSettings !== null) {
                pulseRuntimeSettings.autoDepthMaxLevel = newLevel
            } else {
                console.log("TAV: Auto level cannot be set when pulseRuntimeSettings is null");
            }
        }
    }

    Timer {
        id: autoLevelTimer
        interval: 100  // Poll every 100ms; adjust as needed.
        running: true
        repeat: true
        onTriggered: autoLevelCalculate()
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
        }
    }

    // ---- Where the two sources come from ------------------------------------

    Connections {
        target: dataset ? dataset : undefined

        function onDistChanged () {
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
            // Ignore NaN/inf (e.g. _bottomTrackDepth before the first valid bottom) so the
            // display keeps the last good value instead of showing NaN.
            if (Number.isFinite(dataset.bottomTrackDepth)) {
                bottomTrackDepth = dataset.bottomTrackDepth
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
    }

    Connections {
        target: pulseSettings ? pulseSettings : undefined

        function onDoubleEchoOptimizeChanged () {
            //DEMO MODE: no resolution writes while replaying.
            if (pulseRuntimeSettings.isInDemoMode)
                return
            pulseRuntimeSettings.forceUpdateResolution = true
        }

        // The metric mirror. A persistent key copied into the runtime one, app-wide and
        // one-way - it was in the readout only because the readout was the one thing
        // always instantiated, and in a split screen it ran once per pane.
        function onUseMetricDepthChanged () {
            pulseRuntimeSettings.useMetricDepth = pulseSettings.useMetricDepth
        }
    }

    Component.onCompleted: {
        pulseRuntimeSettings.useMetricDepth = pulseSettings.useMetricDepth
        console.log("DEPTH ENGINE: running - one instance above both panes")
    }
}
