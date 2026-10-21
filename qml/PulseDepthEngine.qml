import QtQuick 2.15
import "PulsePerfEngine.js" as PerfMath

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
// nowhere else. THE CHOICE OF THE DEPTH IS NOT MADE HERE ANY MORE (P7, 18 Oct 2026): Dataset
// chooses - bottom track, gated and outlier-filtered at the epoch write; the rangefinder only
// in the shallows, and only while the bottom track agrees it is shallow - and publishes ONE
// depth, dataset.chosenDepth, that NMEA reads too. This file only reads it, so the readouts,
// NMEA and the dynamic scheme cannot disagree about what the depth is.
//
// Deliberately NOT carried over from the old file: newAutoLevel, pulseBlueResSetOnce,
// initialResolutionSet, dynamicResStableCount, lastDirection and a local
// forceUpdateResolution shadowing the runtime key of the same name. Each is declared once
// in DepthAndTemperature.qml and read nowhere, in this file or any other.
//
// The shallow crossover lives in C++ (Dataset::chooseDepth, depth_gates.h ChoiceParams):
// keyed on the rangefinder, 0.5 m in / 0.7 m out, and only while the bottom track agrees.
Item {
    id: depthEngine

    visible: false
    width:   0
    height:  0

    // ---- The two sources, for the DEPTH: instrument only -----------------------
    //
    // Informational since P7: the choice is dataset.chosenDepth. Held at their last finite value.

    property double rangeFinderDepth: 0.0
    property double bottomTrackDepth: 0.0

    // ---- The chosen depth - READ from the dataset, ONE writer of the runtime key ----
    //
    // Dataset::chooseDepth() publishes one depth for the readout, NMEA and the dynamic scheme
    // (P7, 18 Oct 2026), gated and outlier-filtered at the epoch write (P3-P5b), the rangefinder
    // only in the shallows and only while the bottom track agrees; NaN when there is no depth to
    // show (no bottom, or the shore). The old rule here - bottom track if isBottomTrackInitiated or
    // a side scan, else the rangefinder, 0.0 standing in for "never produced a value" - is gone
    // with its flags: what the Dataset processes (processBottomTrack, a profile value) is what it
    // chooses from. selectedDepth holds the last finite chosen depth.
    //
    // NO BOTTOM AND THE SHORE ON SCREEN (P8). The chosen depth is NaN when no epoch of the pass
    // survived the gates. In the water that is a lost bottom for a moment: the readout HOLDS the
    // last value for 2 s, then shows a dash (shownDepth NaN). On the shore - dataset.onShore: no
    // bottom AND the rangefinder steady at its ringdown or silent - the dash comes at once (Olav:
    // a dash only when sure). NMEA follows on its own: Dataset sends it no depth, and its DBT
    // fields empty after its own stale time. The readouts show a dash for a NaN depthMeters.
    property double selectedDepth: 0.0
    property double shownDepth: NaN
    property double noBottomSinceMs: -1
    readonly property int holdMs: 2000

    onSelectedDepthChanged: {
        // the DEPTH: instrument's 1 m crossing (see logDepthSources)
        const shallow = selectedDepth < 1.0
        if (shallow !== depthLogWasShallow) {
            depthLogWasShallow = shallow
            if (depthLogLive)
                logDepthSources(shallow ? "crossed below 1 m" : "crossed above 1 m")
        }
    }

    onShownDepthChanged: {
        if (pulseRuntimeSettings)
            pulseRuntimeSettings.depthMeters = shownDepth
    }

    function takeChosenDepth() {
        if (!dataset)
            return
        const c = dataset.chosenDepth
        if (Number.isFinite(c)) {
            selectedDepth = c
            shownDepth = c
            noBottomSinceMs = -1
            return
        }
        if (dataset.onShore) {
            if (Number.isFinite(shownDepth) && depthLogLive)
                console.log("DEPTH: on the shore - no bottom, rangefinder at its ringdown or silent - dash")
            shownDepth = NaN
            noBottomSinceMs = -1
            return
        }
        if (noBottomSinceMs < 0)
            noBottomSinceMs = Date.now()      // hold the last value, holdTimer decides when it goes
    }

    Timer {
        id: holdTimer
        interval: 250
        repeat: true
        running: depthEngine.noBottomSinceMs >= 0 && Number.isFinite(depthEngine.shownDepth)
        onTriggered: {
            if (Date.now() - depthEngine.noBottomSinceMs >= depthEngine.holdMs) {
                if (depthEngine.depthLogLive)
                    console.log("DEPTH: no bottom for " + (depthEngine.holdMs / 1000) + " s - dash")
                depthEngine.shownDepth = NaN
            }
        }
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
    // ---- The link-fit plan for red and black (Task 2b, 4 Oct 2026) ------------
    //
    // ONE WRITER of dynamicResolution / dynamicSamples / dynamicPeriod, which DeviceItem turns
    // into chartResolution, chartSamples and ch1Period. The arithmetic is PulsePerfEngine's
    // redPlan, checked by tools/pulse-perf-check.js against the 4 Oct desk run. The baud is the
    // device's own (ID_UART) when the measured rate does not refute it, else 115200 - every
    // red and black in the field.
    //
    // ORDER: DeviceItem sends each of the three as its own message, so a ping that grows is
    // given its longer period first and a ping that shrinks loses its samples first - the
    // link is never asked to carry the bigger ping at the shorter period in between.
    //
    // HELD UNTIL THE DEVICE IS CONFIGURED (4 Oct 2026, the first device run). The plan logged
    // "600 x 4 mm" while the LINK: line kept reading 500 samples. The first plan runs at the
    // initial resolution pass, before the commit: committedProfileKey still named the
    // previous device (PULSEblue at start), so DeviceItem's onDynamicSamplesChanged ->
    // setParam("chartSamples", 600) wrote into THAT profile's map, and the red's own key kept
    // the profile's 500. Every later plan asked the same 600, dynamicSamples did not change,
    // and nothing was sent again. So a plan made before devConfigured is held, and applied
    // the moment the device is configured; and after every plan the three managed params are
    // checked against it and set directly if a handler did not get them there - a line says so.
    property real pendingPlanRangeMm: -1
    property real lastPlanRangeMm: -1

    function applyRedPlan(rangeMm, why) {
        lastPlanRangeMm = rangeMm
        if (!pulseRuntimeSettings.devConfigured) {
            if (pendingPlanRangeMm < 0)
                console.log("DYNAMIC: plan " + why + " for " + (rangeMm / 1000).toFixed(1) + " m held - the device is not configured yet")
            pendingPlanRangeMm = rangeMm
            return
        }
        pendingPlanRangeMm = -1
        const w = (typeof deviceManagerWrapper !== "undefined") ? deviceManagerWrapper : null
        const baud = (w && w.linkBaud > 0 && w.linkBaudPlausible) ? w.linkBaud : 115200
        const p = PerfMath.redPlan({
            rangeMm:     rangeMm,
            baud:        baud,
            floorMs:     pulseRuntimeSettings.dynamicPeriodMin,
            periodMaxMs: pulseRuntimeSettings.dynamicPeriodMax,
            coarsestMm:  pulseRuntimeSettings.dynamicResolutionMax,
            finestMm:    pulseRuntimeSettings.dynamicResolutionMin,
            samplesMax:  pulseRuntimeSettings.dynamicSamplesMax,
            // the PROFILE's samples, not the live param this plan itself writes
            floorSamples: (pulseRuntimeSettings.committedProfile
                           && pulseRuntimeSettings.committedProfile.chartSamples > 0)
                          ? pulseRuntimeSettings.committedProfile.chartSamples : 0,
            soundSpeed:  1480
        })
        const grows = p.samples > pulseRuntimeSettings.dynamicSamples
        if (grows && pulseRuntimeSettings.dynamicPeriod !== p.periodMs)
            pulseRuntimeSettings.dynamicPeriod = p.periodMs
        if (!grows && pulseRuntimeSettings.dynamicSamples !== p.samples)
            pulseRuntimeSettings.dynamicSamples = p.samples
        if (pulseRuntimeSettings.dynamicResolution !== p.spacingMm)
            pulseRuntimeSettings.dynamicResolution = p.spacingMm
        if (grows && pulseRuntimeSettings.dynamicSamples !== p.samples)
            pulseRuntimeSettings.dynamicSamples = p.samples
        if (!grows && pulseRuntimeSettings.dynamicPeriod !== p.periodMs)
            pulseRuntimeSettings.dynamicPeriod = p.periodMs
        // the params must follow (see above); setParam is idempotent, so this is a no-op when
        // the handlers already did it
        const missed = []
        if (pulseRuntimeSettings.paramValue("chartSamples") !== p.samples) {
            missed.push("chartSamples " + pulseRuntimeSettings.paramValue("chartSamples") + " -> " + p.samples)
            pulseRuntimeSettings.setParam("chartSamples", p.samples)
        }
        if (pulseRuntimeSettings.paramValue("ch1Period") !== p.periodMs) {
            missed.push("ch1Period " + pulseRuntimeSettings.paramValue("ch1Period") + " -> " + p.periodMs)
            pulseRuntimeSettings.setParam("ch1Period", p.periodMs)
        }
        if (missed.length > 0)
            console.log("DYNAMIC: the params had not followed the plan - set directly: " + missed.join(", ")
                        + " | profile " + pulseRuntimeSettings.committedProfileKey)
        console.log("DYNAMIC: plan " + why + " | range wanted " + (rangeMm / 1000).toFixed(1) + " m -> "
                    + p.samples + " x " + p.spacingMm + " mm @ " + p.periodMs + " ms = "
                    + (p.rangeMm / 1000).toFixed(1) + " m | " + p.pingsPerS.toFixed(1) + " pings/s, "
                    + p.loadPercent.toFixed(0) + "% of " + baud + " | " + p.limitedBy)
    }

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

        // LINK-FIT (Task 2b, 4 Oct 2026): candidateRes still says what range is wanted - 500
        // samples at that spacing, depth + margin - and the plan decides how it is acquired:
        // at the 72 ms floor, 600 samples spent on finer spacing.
        applyRedPlan(500 * candidateRes, "shallow")

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

        // LINK-FIT (Task 2b, 4 Oct 2026): candidateSamples x the coarsest spacing is the range
        // wanted, as before; the plan replaces the 2 x res - 50 period with the shortest one the
        // link carries at 85% (and never below the 72 ms floor). candidatePeriod is no longer sent.
        applyRedPlan(candidateSamples * pulseRuntimeSettings.dynamicResolutionMax, "deep (today's rule asked " + candidatePeriod + " ms)")
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

    // ---- The dynamic scheme on no bottom (P9, 18 Oct 2026) ----------------------
    //
    // The scheme used to be fed whatever the bottom track said, so on the shore the false far-end
    // bottom dragged the range out (3 -> 51 m in three seconds) and the range then let the false
    // bottom climb further. Since P3-P5 a pass without a bottom publishes NaN, and NaN is never fed
    // here: the range HOLDS. On the shore (dataset.onShore) it holds, full stop. In the water with no
    // bottom for 3 s the scheme SEARCHES: it doubles the wanted range every ~2 s up to the maximum
    // until a bottom is found, then the normal rule takes over with a fresh plan. This is the one
    // thing the runaway did by accident that was useful - a red started over 10 m of water at its
    // 3 m range only found the bottom because the false bottom pulled the range out - and P3 removed
    // the accident, so the search must land with it.
    property double schemeNoBottomSinceMs: -1
    property double schemeLastSearchStepMs: -1
    property bool   schemeSearching: false
    readonly property int searchAfterMs: 3000
    readonly property int searchStepMs: 2000

    function schemeManagesThisDevice() {
        return pulseRuntimeSettings && !pulseRuntimeSettings.isInDemoMode && pulseRuntimeSettings.devConfigured
                && (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed
                    || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto)
    }

    function searchOnNoBottom() {
        const now = Date.now()
        if (dataset && (dataset.onShore || dataset.rangefinderAtRingdown || dataset.rangefinderSteady)) {
            // the range holds; nothing to look for on the shore - and not while the rangefinder hears only itself:
            // on 19 Oct the red's shore state flickered, the search took the range from 3 to 14 m and the far-end
            // noise followed it (no runaway, but no business searching with the rangefinder at 0.12 either).
            // Nor while the rangefinder reads the bottom steadily under 1 m (21 Oct): the shallows are known, and the
            // bottom track's "no bottom" there is the veto at work, not a bottom out of reach
            schemeNoBottomSinceMs = -1
            if (schemeSearching) {
                console.log("DYNAMIC: search stopped - on the shore, the range holds at " + (lastPlanRangeMm / 1000).toFixed(1) + " m")
                schemeSearching = false
            }
            return
        }
        if (schemeNoBottomSinceMs < 0) {
            schemeNoBottomSinceMs = now
            return
        }
        if (now - schemeNoBottomSinceMs < searchAfterMs || !schemeManagesThisDevice())
            return
        if (now - schemeLastSearchStepMs < searchStepMs)
            return
        const maxMm = pulseRuntimeSettings.dynamicSamplesMax * pulseRuntimeSettings.dynamicResolutionMax
        const fromMm = lastPlanRangeMm > 0 ? lastPlanRangeMm : 500 * pulseRuntimeSettings.dynamicResolutionMin
        if (fromMm >= maxMm) {
            if (!schemeSearching || now - schemeLastSearchStepMs >= 10000) {
                console.log("DYNAMIC: search at the maximum range " + (maxMm / 1000).toFixed(1) + " m, still no bottom")
                schemeLastSearchStepMs = now
            }
            schemeSearching = true
            return
        }
        const wantMm = Math.min(maxMm, 2 * fromMm)
        schemeSearching = true
        schemeLastSearchStepMs = now
        console.log("DYNAMIC: search - no bottom for " + ((now - schemeNoBottomSinceMs) / 1000).toFixed(1)
                    + " s, range " + (fromMm / 1000).toFixed(1) + " -> " + (wantMm / 1000).toFixed(1) + " m")
        applyRedPlan(wantMm, "search")
    }

    function autoLevelCalculate () {
        // THE DEPTH THE SCHEME IS FED is the dataset's chosen depth of this pass - never the held
        // readout value, never a rejected epoch. NaN means hold (and, in the water, search).
        const currentDepth = dataset ? dataset.chosenDepth : NaN
        if (!Number.isFinite(currentDepth)) {
            searchOnNoBottom()
            return
        }
        schemeNoBottomSinceMs = -1
        if (schemeSearching) {
            schemeSearching = false
            console.log("DYNAMIC: search found a bottom at " + currentDepth.toFixed(2) + " m - the normal rule resumes")
            if (pulseRuntimeSettings && !pulseRuntimeSettings.isInDemoMode)
                pulseRuntimeSettings.forceUpdateResolution = true   // a fresh plan from the real depth, no hysteresis wait
        }
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

    // ---- The DEPTH: instrument (Task 2b step 1, 4 Oct 2026) -----------------
    //
    // BOTTOM TRACK - TWO OPEN PROBLEMS (backlog): false depths with no real bottom that
    // follow the acquisition range, and no bottom-track depth below ~0.5 m. Nothing is
    // fixed before this line is read. It puts the two sources side by side with what the
    // readout shows and what the transducer is acquiring, from the chart stream itself:
    // on a red the dynamic scheme sizes the range from the depth, so a false depth that
    // follows the range would make the two feed each other - the range column says so.
    //
    // Every 10 s from a live device (never a demo or a file), and at once when the shown
    // depth crosses 1 m either way - the shallow case is the one a 10 s line would miss.
    readonly property bool depthLogLive:
        pulseRuntimeSettings ? (pulseRuntimeSettings.devConfigured && !pulseRuntimeSettings.logIsOnScreen) : false
    property bool depthLogWasShallow: false

    function logDepthSources(why) {
        const w = (typeof deviceManagerWrapper !== "undefined") ? deviceManagerWrapper : null
        const ss = w ? w.linkStreamSamples : 0
        const sp = w ? w.linkStreamSpacingMm : 0
        const sideScan = pulseRuntimeSettings ? !pulseRuntimeSettings.displayIs2DTransducer : false
        const rangeM = (ss > 0 && sp > 0) ? (ss * sp / 1000 / (sideScan ? 2 : 1)) : -1
        const raw = (dataset && Number.isFinite(dataset.dist)) ? dataset.dist.toFixed(2) : "-"
        const bt = (dataset && Number.isFinite(dataset.bottomTrackDepth)) ? dataset.bottomTrackDepth.toFixed(2) : "-"
        // "now" is dataset.dist, frozen while the bottom track is the source (addRangefinder returns
        // first); "live" is the raw device reading recorded before that return, with its age
        const rfAge = dataset ? dataset.rangefinderLiveAgeS() : -1
        const rfLive = (rfAge >= 0 && Number.isFinite(dataset.rangefinderLive()))
                ? dataset.rangefinderLive().toFixed(2) + " raw, " + rfAge.toFixed(1) + " s old" : "none"
        const chosen = (dataset && Number.isFinite(dataset.chosenDepth)) ? dataset.chosenDepth.toFixed(2) : "-"
        console.log("DEPTH: " + why
                    + " | shown " + (Number.isFinite(shownDepth) ? shownDepth.toFixed(2) + " m" : "dash") + " from " + (dataset ? dataset.chosenDepthSource : "?")
                    + " (chosen now " + chosen + (dataset && dataset.noBottom ? ", no bottom" : "") + (dataset && dataset.onShore ? ", shore" : "") + ")"
                    + " | rangefinder " + rangeFinderDepth.toFixed(2) + " (now " + raw + ", live " + rfLive + ")"
                    + " | bottom track " + bottomTrackDepth.toFixed(2) + " (now " + bt + ")"
                    + " | acquiring " + (rangeM >= 0 ? rangeM.toFixed(1) + " m (" + ss + " x " + sp + " mm)" : "-")
                    + " | dynamic " + (pulseRuntimeSettings && pulseRuntimeSettings.doDynamicResolution ? "on" : "off")
                    + " " + (pulseRuntimeSettings ? pulseRuntimeSettings.dynamicResolution + " mm, "
                             + pulseRuntimeSettings.dynamicSamples + " x, " + pulseRuntimeSettings.dynamicPeriod + " ms" : "")
                    + " | last stable " + lastStableDepth.toFixed(1) + " m")
    }

    Timer {
        interval: 10000
        repeat: true
        running: depthEngine.depthLogLive
        onTriggered: depthEngine.logDepthSources("every 10 s")
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

        // THE ONE DEPTH (P7). Once per bottom-track pass, and per rangefinder reading when the
        // rangefinder is the source. NaN is handled (P8), not ignored.
        function onChosenDepthChanged () {
            takeChosenDepth()
        }
    }

    Connections {
        target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined

        function onDevConfiguredChanged () {
            if (!pulseRuntimeSettings.devConfigured)
                return
            const r = pendingPlanRangeMm >= 0 ? pendingPlanRangeMm : lastPlanRangeMm
            if (r >= 0 && !pulseRuntimeSettings.isInDemoMode
                    && pulseRuntimeSettings.doDynamicResolution
                    && (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed
                        || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto))
                applyRedPlan(r, "the device is configured")
        }

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
