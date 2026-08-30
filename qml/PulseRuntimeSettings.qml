// Non-persistent settings, storage for runtime preferences
//pragma Singleton

import QtQuick 2.15

QtObject {
    id: pulseRuntimeSettings

    //DEVICES
    property string devName:                "..."           //Stores the connected device name
    property string modelPulseRed:          "PULSEred"      //Our device name for PulseRed.
    property string modelPulseBlue:         "PULSEblue"     //Our device name dor PulseBlue.
    property string modelPulseRedProto:     "Basic2D"        //Our device name for PulseRed. Will change!
    property string modelPulseBlueProto:    "Basic2D"       //Our device name dor PulseBlue. Will change!
    property string userManualSetName:      "..."           //Stores the manually selected name when not automatically detected in main
    //EXPERIMENT toggle: when true, model detection is driven by dev.devType (board enum, transport-agnostic)
    //in ConnectionViewer.selectCorrectDevice, and the old devName-string path in main.qml is disabled.
    //Set false to fall back to the previous main.qml onDevNameChanged detection.
    property bool   useDevTypeDetection:    true
    property string udpGateway:             "192.168.10.1"
    property string pulseRedBeta:           "PULSEred BETA"
    property string pulseBlueBeta:          "PULSEblue BETA"
    property string pulseBetaName:          "..."

    //CONNECTIONS UUID
    property string uuidIpGateway:          "{2ad43efc-61d1-4321-a925-a8e0cd188ca2}"
    //property string uuidIpGateway2:         "{2ad43efc-61d1-4321-a925-a8e0cd188ca3}"
    property string uuidUsbSerial:          "{2ad43efc-61d1-4321-a925-a8e0cd188cd0}"
    property string uuidProxyLink:          "{2ad43efc-61d1-4321-a925-a8e0cd188cd5}"
    property string uuidSuccessfullyOpened: ""
    property int    usbSerialBaud:          921600

    //GENERAL SETUP STATES
    property bool   devDetected:            false   // App automatically detected the transducer by name
    property bool   devIdentified:          false   // The app recognizes the transducer as one of our supported models
    property bool   devSettingsEnforced:    false   // Transducer settings enforced
    property bool   devManualSelected:      false   // The user selected one of our selected models
    property bool   appConfigured:          false   // Setup steps for the app recongnized device is completed
    property bool   expertMode:             false   // Hidden feeatures shown when true
    property bool   betaMode:               false
    property bool   isSideScan2DView:       false   // Side scan is detected, but user wants to show it as a 2D transducer (aka downscan)
    property bool   isSideScanLeftHand:     false   // Side scan mounted on the left side
    property bool   isOpeningKlfFile:       false
    property bool   wasKlfFileOpened:       false
    //DEMO MODE (Stage 1) — see demo_mode_plan.md.
    //A .plog file is replayed as if a live transducer were streaming it. This is
    //a THIRD state, not file view: wasKlfFileOpened MUST stay false during a
    //demo, because that flag is what disables the live-style UI all over
    //Plot2D.qml. isInDemoMode instead silences the things that talk to, or react
    //to, a device that is not really there.
    property bool   isInDemoMode:           false
    property string demoFilePath:           ""      // File chosen for replay
    property int    demoMeasuredPeriodMs:   0       // 0 = unknown; else the pacing in use (ms/epoch)
    property bool   demoIsSideScan:         false   // What the prescan classified the log as
    property int    numberOfDatasetChannels:0       // The number of channels in the dataset received
    property int    currentDepthSolution:   -1      // Depth reporting inactive = 0, depth distance = 1, depth NMEA = 2
    property bool   disableAllSetup:        false
    property bool   forceUpdateResolution:  false
    property bool   pulseBlueResSetOnce:    false   // Will be set to true provided we set resolution once for the blue
    property bool   reconnectAfterLogView:  false   // Used to reset all states when we want to reconnect

    //CHANGE DEVICE STATE
    property bool   swapDeviceNow:          false   // Should reset and restart the setup

    //CONFIGURATION STATES
    property bool   onDeviceVersionChanged: false
    // overall
    property bool   devConfigured:          false   // when all of the below is true we have set everything up
    // safe configuration
    property bool   echogramPausedForConfig:false   // If desired, the echogram is now paused to reduce traffic during parameter config
    property bool   echogramEnabledByConfig:false   // Programmatically reneable from paused state
    // dist
    property bool   onDistSetupChanged:     false   // Dist is complete
    property bool   distMax_ok:             false   // distMax parameter is OK
    property bool   distDeadZone_ok:        false   // distDeadZone parameter is OK. Let's not configure this
    property bool   distConfidence_ok:      false   // distConfidence parameter is OK. Let's not configure this
    // chart
    property bool   onChartSetupChanged:    false   // Chart is complete
    property bool   chartSamples_ok:        false   // chartSamples parameter is OK
    property bool   chartResolution_ok:     false   // THIS WE SET DYNAMICALLY!!! But not for Pulse Blue!!!
    property bool   chartOffset_ok:         false   // chartOffset parameter is OK
    // dataset
    property bool   onDatasetChanged:       false   // Dataset is complete
    property bool   ch1Period_ok:           false   // ch1Period parameter is OK
    property bool   datasetTimestamp_ok:    false   // datasetTimestamp parameter is OK. Let's not configure this
    property bool   datasetChart_ok:        false   // datasetChart parameter is OK.
    property bool   datasetTemp_ok:         false   // datasetTemp parameter is OK.
    property bool   datasetEuler_ok:        false   // datasetEuler parameter is OK. Let's not configure this
    property bool   datasetDist_ok:         false   // datasetDist parameter is OK.
    property bool   datasetSDDBT_ok:        false   // datasetSDDBT parameter is OK.
    // trans
    property bool   onTransChanged:         false   // Transducer is complete
    property bool   transFreq_ok:           false   // transFreq parameter is OK
    property bool   transPulse_ok:          false   // transPulse parameter is OK
    property bool   transBoost_ok:          false   // transBoost parameter is OK
    // dsp
    property bool   onDspSetupChanged:      true    // LET'S NOT USE THIS AT ALL
    property bool   dspHorSmooth_ok:        true    // Avoided
    // sound
    property bool   onSoundChanged:         true    // Sound is complete. Let's not configure this
    property bool   soundSpeed_ok:          true    // soundSpeed parameter is OK. Let's not configure this
    // problem
    property bool   unableToConfigure:      false   // Used to signal that config takes too much time

    //TRAFFIC STATES
    property bool   isReceivingData:        false   // When data is received, true
    property bool   didEverReceiveData:     false   // When data is received at least at some point, true
    property bool   hasDeviceLostConnection:false   // if didEverReceiveData = true, and isReceivingData = false
    property bool   didReceiveDepthData:    false   // Used to track if depth data is received
    property bool   forceBreakConnection:   false   // Used to break connection if we do not like the device

    //TRAFFIC STATE CHANGE CONTROL
    property bool   dataUpdateActive:       false   // If dataUpdate is being signalled, this should be true
    property bool   echoSounderReboot:      false   // Manual expert reboot trigger (PulseInfoSettings -> DeviceItem dev.reboot())
    // PULSE: rebootWindowMs / resetWindowMs / firstDataTs / guardActive / dataIsStaleElapseTime were
    // removed together with the auto-reboot "dataflow guard" timers in main.qml (band-aid for the old
    // stuck-configuring state; root cause now fixed in selectCorrectDevice).

    //UI AUTO CONTROL
    property double autoDepthMaxLevel:      49      // The current max level displayed, used for automatic change of display based on depth measure
    property double autoDepthMinLevel:      1       // The minimum chart level display allowed
    property double autoDepthLevelStep:     1       // The step in meters to evaluate when to automatically change the display
    property double autoDepthDistanceBelow: 1       // The additional distance below the measured depth and the step to show some screen below the measure
    property bool   shouldDoAutoRange:      false   // Should app automatically adjust the display according to depth measure or not?
    property double manualSetLevel:         0.0     // The fixe value of the screen display desired by the user, when manual fixing is desired
    property double hysterisisThreshold:    0.1     // resolution hysterisis for dynamic resolution
    property int    requiredStableReading:  3       // resolution shift count threshold
    property int    scrollingSpeed:         50      // Phased out - previous solution: Initial value for scrolling speed
    property double echogramSpeed:          1.0     // New solution for speed, fully working and not impacting data rates: Initial value for scrolling speed
    property bool   echogramPause:          false   // Pause the echogram, also to enable/disable clicking functions in the echogram
    property int    echogramCompensationFile:0      // EXPERIMENTAL: 0 (raw), 1 (side scan) or 2 (TVG)

    //Water-body filter — Stage B (display-only). When enabled the Pulse
    //filter control drives the new water-column/surface filter instead of the upstream
    //global low-cut (which is then pinned to 0; the upstream method itself is untouched).
    //DEFAULT ON since the external-tester build (2026-08-29): validated by the expert
    //testers on 2D, side scan and live Red/Blue. Experts can still switch it off.
    property bool   echogramWaterBodyFilterEnabled: true
    property double echogramWaterBodyBottomMargin: 0.05   // Bottom guard in m: zone above the bottom the filter never touches
    //Minimum "real" filter value (0-50 scale) used for the water body strength while the
    //filter is enabled. The filter slider is PERSISTENT, so a tester upgrading from an
    //older build can arrive with it at 0 — which would leave EchogramWaterColumn at
    //strength 0 (isActive() false) while the checkbox reads "on". Flooring the strength
    //here keeps the promise the toggle makes; raising the slider still works normally.
    //5/50 = 0.10, the same gentle level the slider default (5) gives.
    property int    echogramWaterBodyMinRealValue:  5

    //Which device profile is actually rendering right now. "" = nothing committed yet.
    //
    //userManualSetName is the committed model and is set by BOTH selection paths
    //(ConnectionViewer.selectCorrectDevice via modelForBoard(), and the manual pick in
    //main.qml). It is "..." before detection settles — including inside the Basic2D
    //settle window — and is reset to "..." on a device swap / disconnect.
    //
    //Everything per-device binds through `userManualSetName === modelPulseRed ? red : blue`,
    //which means the UNCOMMITTED state silently falls through to the BLUE profile. That was
    //harmless while both TVG toggles defaulted to false, but with the profile-driven
    //defaults below it would put the side scan log-law gain (imageType 3) on a 2D echogram
    //— exactly what a tester sees when a saved 2D log is opened before any device has been
    //identified. So on the LIVE path: no committed model -> no TVG at all (see
    //resolveEchogramCompensation). File and demo playback classify from the data instead.
    //
    //WHEN THE DATA IS NOT LIVE, THE DATA DECIDES. A demo or an opened log carries its own
    //identity, and that identity — not whatever transducer happens to be plugged in — is
    //what must drive the display gain. Two reasons this matters in practice:
    //  * cold start: a demonstrator opens a saved log with no transducer ever identified.
    //    On the committed model alone activeModel would be "" and the log would render
    //    with no TVG at all, which is precisely what the demo is meant to show off.
    //  * wrong device committed: the app was started as a Blue and a Red log is played.
    //    The committed model would put the side scan log-law gain on a 2D echogram.
    //Classification sources, both already maintained elsewhere:
    //  * demo    -> demoIsSideScan, from the prescan (core.onDemoPeriodChanged).
    //  * file    -> numberOfDatasetChannels, from core.onChannelListUpdated in main.qml.
    //               1 channel = 2D, 2 = dual side scan — the same rule ConnectionViewer
    //               .modelForBoard() uses to split the Basic2D batch. 0 = not known yet,
    //               so fall back to the committed model until the channel list arrives.
    //enterDemoMode() already prefers the prescan over the device for the black-stripes
    //profile, so this is the established pattern for display-side settings, not a new one.
    //
    //NOTE: this covers the DISPLAY path only. Resolution, samples, ranges and dist
    //processing still come from the committed device profile, so playing a log that does
    //not match the connected transducer is still something the demonstrator has to be
    //aware of — until there is a proper way to re-identify the sounder and re-run setup.
    property string committedModel:
        (userManualSetName === modelPulseRed || userManualSetName === modelPulseBlue) ? userManualSetName
      : ""

    property string activeModel:
        isInDemoMode ? (demoIsSideScan ? modelPulseBlue : modelPulseRed)
      : (wasKlfFileOpened || isOpeningKlfFile)
            ? (numberOfDatasetChannels >= 2 ? modelPulseBlue
             : numberOfDatasetChannels === 1 ? modelPulseRed
             : committedModel)
      : committedModel

    //TVG — Stage A (display-only). See tvg_analysis_and_recommendation.md v2.
    //PER-PROFILE DEFAULT since 2026-08-29: 2D TVG and side scan TVG are never both the
    //"right" answer, so the default now comes from the device profile (pulseRed /
    //pulseBlue below) instead of a flat false. Writing to either property from the expert
    //panel breaks this binding for the rest of the session — deliberate: a manual expert
    //choice must not be silently undone by a reconnect. Restart restores the profile
    //default, as with every other runtime TVG value.
    property bool   echogramTvgEnabled:     activeModel === modelPulseRed  ? pulseRed.echogramTvgEnabled
                                          : activeModel === modelPulseBlue ? pulseBlue.echogramTvgEnabled
                                          : false
    property double echogramTvgDbPerMeter:  0.9     // Net decay constant in dB/m (Dreamlake harvest: 0.66-1.11, mean ~0.9)

    //Side scan TVG — side scan phase (expert-gated, display-only). Log-law range
    //gain (imageType 3) validated offline on SS_pulse_log_2026.07.20: consistent
    //intensity over range (brightness = bottom hardness) instead of the AGC's
    //local-contrast normalization. Defaults mirror EchogramSideScanTvg constants.
    property bool   sideScanTvgEnabled:      activeModel === modelPulseRed  ? pulseRed.sideScanTvgEnabled
                                           : activeModel === modelPulseBlue ? pulseBlue.sideScanTvgEnabled
                                           : false    // waterfall uses TVG (3) instead of AGC (1)
    property double sideScanTvgSpreading:    5      // S in dB/decade (field-tuned 2026-08-16; deeper water/chirp may want more)
    property double sideScanTvgAbsorption:   0.0    // a in dB/m (field-tuned: 0 on 25 m ranges; matters for chirp long range)
    property double sideScanTvgRefRange:     15     // gain = 1 at this range (m): near field keeps familiar brightness
    property double sideScanTvgNoiseFloor:   0.1    // noise-floor subtraction strength 0..1 (0 = off; base level for partner testing 2026-08-17)
    property double sideScanTvgBoost:        1.2    // detail boost beta (field-tuned: essential for crispness)
    property bool   sideScanTvgMosaicEnabled:false  // mosaic renders TVG buffer instead of AGC (rebuild applied on switch)

    // Single source of truth for the echogram compensation id.
    // 2D uses TVG (2) when enabled, else raw (0); side scan uses side scan
    // TVG (3) when enabled, else AGC (1).
    //
    // Keyed on activeModel, NOT on is2DTransducer: is2DTransducer is derived from the
    // same red/blue binding and therefore reads "side scan" whenever nothing is committed.
    // With no committed model we render neutral raw (0) rather than guessing — one frame
    // of un-gained echogram is a far better failure than a side scan gain curve stretched
    // over a 2D log.
    function resolveEchogramCompensation() {
        if (activeModel === "") {
            return 0
        }
        return (activeModel === modelPulseRed) ? (echogramTvgEnabled  ? 2 : 0)
                                               : (sideScanTvgEnabled ? 3 : 1)
    }

    //DEMO MODE: put the CONFIGURATION STATES block into "nothing left to do".
    //
    //The guards in DeviceItem stop the configuration machinery from running, but
    //the UI reads these flags for its "device ready" affordances and
    //completeDeviceConfigurationTimer binds `repeat:` to !devConfigured — so
    //without this the timer keeps ticking against a device that does not exist.
    //Mirror image of DeviceItem.resetAllSetupStates().
    //
    //  setConfigStatesForDemo(true)  -> entering demo: everything reads "done"
    //  setConfigStatesForDemo(false) -> leaving demo: back to the declared
    //                                   fresh-start defaults
    //
    //onDsp*/onSound* are declared true at rest and are never configured, so they
    //stay true in BOTH directions. That asymmetry is deliberate.
    function setConfigStatesForDemo(inDemo) {
        var v = inDemo

        onDeviceVersionChanged  = false
        devConfigured           = v

        echogramPausedForConfig = false
        echogramEnabledByConfig = false

        onDistSetupChanged      = v
        distMax_ok              = v
        distDeadZone_ok         = v
        distConfidence_ok       = v

        onChartSetupChanged     = v
        chartSamples_ok         = v
        chartResolution_ok      = v
        chartOffset_ok          = v

        onDatasetChanged        = v
        ch1Period_ok            = v
        datasetTimestamp_ok     = v
        datasetChart_ok         = v
        datasetTemp_ok          = v
        datasetEuler_ok         = v
        datasetDist_ok          = v
        datasetSDDBT_ok         = v

        onTransChanged          = v
        transFreq_ok            = v
        transPulse_ok           = v
        transBoost_ok           = v

        // Never used / never configured — true at rest, true in demo.
        onDspSetupChanged       = true
        dspHorSmooth_ok         = true
        onSoundChanged          = true
        soundSpeed_ok           = true

        unableToConfigure       = false

        console.log("DEMO: setConfigStatesForDemo(", inDemo, ") applied")
    }

    //Black stripes removal. This is a DISPLAY setting: it does not touch the
    //transducer, it tells core how to paper over the gaps left by missing data.
    //It therefore matters just as much in demo mode as it does live — without it
    //the empty "black stripe" columns show up in the replayed echogram.
    //
    //Single source of truth on purpose: DeviceItem.configurePulseDevice() and
    //enterDemoMode() both call this, so the two paths cannot drift apart. The
    //guarded writes are a literal transcription of the original block.
    function applyBlackStripesToCore(forwardSteps, backwardSteps, state) {
        if (core === null) {
            return
        }
        if (core.fixBlackStripesForwardSteps !== forwardSteps) {
            core.fixBlackStripesForwardSteps = forwardSteps
            console.log("DEV_CONFIG: core.fixBlackStripesForwardSteps changed to ", core.fixBlackStripesForwardSteps)
        }
        if (core.fixBlackStripesBackwardSteps !== backwardSteps) {
            core.fixBlackStripesBackwardSteps = backwardSteps
            console.log("DEV_CONFIG: core.fixBlackStripesBackwardSteps changed to ", core.fixBlackStripesBackwardSteps)
        }
        if (core.fixBlackStripesState !== state) {
            core.fixBlackStripesState = state
            console.log("DEV_CONFIG: core.fixBlackStripesState changed to ", core.fixBlackStripesState)
        }
    }

    //DEMO MODE: entering and leaving, in one place so the Recording tab, the
    //end-of-file path and any later kiosk autostart all take the same route.
    //
    //These live here rather than in main.qml because pulseRuntimeSettings is a
    //root context property and is therefore reachable from every QML file —
    //main.qml's `mainview` id is not (QML ids do not cross files).
    //
    //Note what is deliberately NOT touched: wasKlfFileOpened stays false. Demo
    //wants the live-style Plot2D behaviour that flag switches off.
    function enterDemoMode(path) {
        if (isInDemoMode) {
            console.log("DEMO: already running")
            return
        }
        if (!path || path.length === 0) {
            console.log("DEMO: no file chosen")
            return
        }

        console.log("DEMO: entering demo mode with", path)

        // Starting a demo on top of an opened file view is allowed — the open has
        // already finished, we were only rendering it. But wasKlfFileOpened MUST be
        // cleared: that flag is what switches OFF the live-style behaviour all over
        // Plot2D (live follow, the old-data indicator, the UI controls row), and a
        // demo wants all of it ON. core.startDemo() drops the file on its side.
        if (wasKlfFileOpened || isOpeningKlfFile) {
            console.log("DEMO: leaving the file view behind")
            wasKlfFileOpened = false
            isOpeningKlfFile = false
            klfFilePath = ""
        }

        demoFilePath = path
        isInDemoMode = true

        // Quieten the configuration machinery before the first frame arrives.
        setConfigStatesForDemo(true)

        // Honour the TVG / water-body toggles from the first epoch, exactly as
        // the file-open path does.
        echogramCompensationFile = resolveEchogramCompensation()

        core.startDemo(path)

        //Black stripes removal must be enforced for the replay too, otherwise the
        //gaps from missing data show as empty columns. Done AFTER startDemo on
        //purpose: the prescan has run by then, so demoIsSideScan tells us which
        //profile the LOG needs — we do not have to rely on device detection,
        //which for a ghost device may never settle on a model.
        //No echogram pause around this: unlike a real parameter write, these are
        //display-side settings and are safe to change with the echogram flowing.
        var prof = demoIsSideScan ? pulseBlue : pulseRed
        console.log("DEMO: applying black stripes profile for",
                    demoIsSideScan ? "side scan" : "2D")
        applyBlackStripesToCore(prof.fixBlackStripesForwardSteps,
                                prof.fixBlackStripesBackwardSteps,
                                prof.fixBlackStripesState)
    }

    function exitDemoMode() {
        if (!isInDemoMode) {
            return
        }
        console.log("DEMO: leaving demo mode")

        // No-op when core already stopped itself at end of file.
        core.stopDemo()

        isInDemoMode = false
        demoMeasuredPeriodMs = 0
        setConfigStatesForDemo(false)

        // Leave nothing behind that makes the app think it should configure a
        // device. dataUpdateActive in particular drives Plot2D's
        // "Configuring transducer..." overlay, which after 10 s escalates to
        // "Fixing transducer com link...".
        // Stage 2 replaces this with the consolidated resetAppToFreshState().
        didEverReceiveData = false
        hasDeviceLostConnection = false
        isReceivingData = false
        dataUpdateActive = false
        devConfigured = false
        unableToConfigure = false
        devDetected = false
        devIdentified = false
        appConfigured = false
        numberOfDatasetChannels = 0
        devName = "..."
        userManualSetName = "..."
        pulseBetaName = "..."
    }

    //APP DYNAMIC CONTROLS
    //NUMERIC convention since 2026-08-29: Min is always the SMALLER number, whatever the
    //quantity means. These six bounds used to be named after resolution QUALITY (finer
    //resolution = fewer mm), so dynamicResolutionMin held 50 and Max held 2 — and that
    //inverted convention had been copied to samples and period as well. The clamp code
    //has always been Math.max(candidate, <lower>) then Math.min(result, <upper>); after
    //the swap those read Min then Max, which is idiomatic for the first time.
    property int    dynamicResolutionMin:   2       // Finest sample spacing allowed, mm
    property int    dynamicResolutionMax:   50      // Coarsest sample spacing allowed, mm (reduced from 90)
    property int    dynamicResolutionMargin:2       // The margin resolution in m
    property int    dynamicResolution:      30      // Initial value for resolution in mm, this value is possible to manipulate to alter resolution based on conditions
    property bool   dynamicResolutionInit:  false   // The initial dynamic resolution was performed
    property int    dynamicSamplesMin:      500     // When sample spacing is at its coarsest, we alter the number of samples and the period
    property int    dynamicSamplesMax:      1020
    property int    dynamicSamplesStep:     20
    property int    dynamicPeriodMin:       50      // When sample spacing is at its coarsest, we alter the period and the number of samples
    property int    dynamicPeriodMax:       154
    property int    dynamicPeriodStep:      2
    property int    dynamicSamples:         500     //
    property int    dynamicPeriod:          50      //

    //APP PULSESETTINGS AND OTHER SYNC C++ PROBLEMS WORKAROUNDS
    property bool   useMetricDepth:         true    // Workaround for missing ability to sync the c++ and qml settings
    //property bool   isSideScanLeftHand:true    // Workaround already present
    property bool   isHorizontalGrid:       true    // Workaround for missing ability to sync the c++ and qml settings
    property string nmeaBroadcastAddress:   "255.255.255.255"
    //Temporary UDP preference (shall use persistent settings for this purpose
    property bool   enableNmeaDbt:              true

    //RECORDING KLF
    property bool   isRecordingKlf:         false   // If a KLF recording is started or not
    property string klfFilePath:            ""      // File path used to view a KLF file

    //MAVLINK RELATED
    property bool   mavlinkDetected:        false   // If mavlink is presently available in Pulse app

    //SETTING CATEGORY FILTERS
    property bool   showCatScreen:         false
    property bool   showCatNmea:            false
    property bool   showCatPositionSource:  false
    property bool   showCatInstallation:    false
    property bool   showCatTroubleShoot:    false
    property bool   showCatRecording:       false
    property bool   showCatExperimental:    false
    property bool   showCatTvg:             false
    property bool   showCat2DTvg:           false
    property bool   showCatWaterBody:       false
    property bool   showCatDepthTricks:     false
    property bool   showCatBottomTrack:     false
    property bool   showCatDebug:           false
    property bool   showCatBlackStripes:    false
    property bool   showCatDepthFiltering:  false
    property bool   showCatDeviceRawInfo:   false
    property bool   showCatParameterInfo:   false
    property bool   showCatAppConfigInfo:   false
    property bool   showCatBetaTesters:     false
    property bool   showCatSwapDevice:      false

    //RAW DATA FROM DEVICE
    property string rawDev_devName:             "not set"
    property int    rawDev_devType:             -1
    property int    rawDev_devBaudRate:         -1
    property int    rawDev_devSerialNumber:     -1
    property string rawDev_devPN:               "not set"
    property string rawDev_firmwareVersion:     "not set"
    property bool   rawDev_isSonar:             false
    property bool   rawDev_isChartSupport:      false
    property bool   rawDev_isTransducerSupport: false
    property bool   rawDev_isDistSupport:       false
    property bool   rawDev_isDatasetSupport:    false
    property bool   rawDev_isSoundSpeedSupport: false
    property bool   rawDev_isUpgradeSupport:    false
    property string rawDev_devListDump:         "not set"   // DIAGNOSTIC: full devList snapshot (count, type, name, sn; '*' = selected)

    //FALSE DEPTH READING ALGORITHM TUNING
    property double kSmallAgreeMargin:          0.5    // Fluctuations allowed in filtering
    property double kLargeJumpThreshold:        5.0    // A jump from one value to the next before considered a likely false reading
    property int    kConsistNeeded:             10     // The threshold of values required before we believe it
    property bool   useDepthFilter:             true   // Ability to turn off/on for expert testers
    property bool   useFilterWithBottomTrack:   true   // Ability to turn off/on for expert testers

    //TESTING PROPERTIES
    property double fakeDepthAddition:          0.0
    property bool   pushFakeDepth:              false
    property bool   resetFakeDepth:             false
    property bool   resetBottomTrackActive:     false
    property bool   useBlueHighFrequency:       false

    //PROPERTY CONTROLLING BOTTOM TRACK
    property bool   isBottomTrackInitiated:     false   //Setup for bottom track is prepared
    property bool   isBottomTrackActive:        false   //If bottom track is to be used and is active, this is true: MMAY BE REDUNDANT
    property double bottomTrackMinDepth:        0.5     //Below this depth, the rangefinder shall always be used
    property bool   rangefinderTrackVisible:    false   //Expert-only: paint the raw rangefinder line on the echogram for analysis (never the value text)
    
    //COLOR MAP

    property var    themeModelBlue: [
        { id: 0,        icon: "./icons/ui/pulse_color_ss_blue.svg",        title: "Blue"   },
        { id: 1,        icon: "./icons/ui/pulse_color_ss_sepia.svg",       title: "Yellow"   },
        { id: 2,        icon: "./icons/ui/pulse_color_ss_gray.svg",        title: "Gray"   },
        { id: 3,        icon: "./icons/ui/pulse_color_ss_red.svg",         title: "Red"   },
        { id: 4,        icon: "./icons/ui/pulse_color_ss_green.svg",       title: "Green" },
        { id: 26,       icon: "./icons/ui/pulse_color_hq_orange.svg",      title: "High Quality Orange" },
    ]

    property var    themeModelRed: [
        { id: 5,        icon: "./icons/ui/pulse_color_2d_e500_black.svg",  title: "E Dark" },
        { id: 6,        icon: "./icons/ui/pulse_color_2d_e500_white.svg",  title: "E Bright"  },
        { id: 7,        icon: "./icons/ui/pulse_color_2d_furuno_black.svg",title: "F Dark"  },
        { id: 8,        icon: "./icons/ui/pulse_color_2d_furuno_white.svg",title: "F Bright"  },
        { id: 9,        icon: "./icons/ui/pulse_color_2d_sonic_black.svg", title: "S Dark"  },
        { id: 10,       icon: "./icons/ui/pulse_color_2d_sonic_white.svg", title: "S Bright"  },
        { id: 11,       icon: "./icons/ui/pulse_color_2d_lsss_black.svg",  title: "L Dark"  },
        { id: 12,       icon: "./icons/ui/pulse_color_2d_lsss_white.svg",  title: "L Bright"  },
        { id: 13,       icon: "./icons/ui/pulse_color_2d_hti_black.svg",   title: "H Dark"  },
        { id: 14,       icon: "./icons/ui/pulse_color_2d_hti_white.svg",   title: "H Bright"  },
        { id: 15,       icon: "./icons/ui/pulse_color_2d_dt4_black.svg",   title: "D Dark"  },
        { id: 16,       icon: "./icons/ui/pulse_color_2d_dt4_white.svg",   title: "D Bright"  },
        { id: 19,       icon: "./icons/ui/pulse_color_blue_red.svg",       title: "Pulse Blue-Red"  },
        { id: 20,       icon: "./icons/ui/pulse_color_2d_rainbow.svg",     title: "Pulse Pink-Red"  },
        { id: 0,        icon: "./icons/ui/pulse_color_ss_blue.svg",        title: "Blue"   },
        { id: 1,        icon: "./icons/ui/pulse_color_ss_sepia.svg",       title: "Yellow"   },
        { id: 2,        icon: "./icons/ui/pulse_color_ss_gray.svg",        title: "Gray"   },
        { id: 3,        icon: "./icons/ui/pulse_color_ss_red.svg",         title: "Red"   },
        { id: 4,        icon: "./icons/ui/pulse_color_ss_green.svg",       title: "Green" },
        { id: 26,       icon: "./icons/ui/pulse_color_hq_orange.svg",      title: "High Quality Orange" },
    ]

    property var    currentThemeColors: []

    //DISPLAY SETTINGS

    property bool   echogramVisible:                true
    //property bool   bottomTrackVisible:             false     //moved to device dependent model
    //property int    bottomTrackVisibleModel:        2         //moved to device dependent model
    property bool   rangefinderVisible:             true
    property int    rangefinderVisibleModel:        0
    property bool   ahrsVisible:                    false
    property bool   gnssVisible:                    false
    property bool   gridVisible:                    true
    property bool   fillWidthGrid:                  false
    property int    gridNumber:                     5
    property bool   angleVisible:                   false
    property bool   velocityVisible:                false
    property bool   distanceAutoRange:              false
    property int    distanceAutoRangeCurrentIndex:  -1
    
    
    //PER DEVICE PROPERTIES
    property bool   settingVersion:                 userManualSetName === modelPulseRed ? pulseRed.settingVersion               : pulseBlue.settingVersion
    property bool   useTemperature:                 userManualSetName === modelPulseRed ? pulseRed.useTemperature               : pulseBlue.useTemperature
    property bool   is2DTransducer:                 userManualSetName === modelPulseRed ? pulseRed.is2DTransducer               : pulseBlue.is2DTransducer
    property int    chartResolution:                userManualSetName === modelPulseRed ? pulseRed.chartResolution              : pulseBlue.chartResolution
    property int    chartSamples:                   userManualSetName === modelPulseRed ? pulseRed.chartSamples                 : pulseBlue.chartSamples
    property int    chartOffset:                    userManualSetName === modelPulseRed ? pulseRed.chartOffset                  : pulseBlue.chartOffset
    property int    distMax:                        userManualSetName === modelPulseRed ? pulseRed.distMax                      : pulseBlue.distMax
    property int    distDeadZone:                   userManualSetName === modelPulseRed ? pulseRed.distDeadZone                 : pulseBlue.distDeadZone
    property int    distConfidence:                 userManualSetName === modelPulseRed ? pulseRed.distConfidence               : pulseBlue.distConfidence
    property int    transPulse:                     userManualSetName === modelPulseRed ? pulseRed.transPulse                   : pulseBlue.transPulse
    property int    transFreq:                      userManualSetName === modelPulseRed ? pulseRed.transFreq                    : pulseBlue.transFreq
    property int    transBoost:                     userManualSetName === modelPulseRed ? pulseRed.transBoost                   : pulseBlue.transBoost
    property int    dspHorSmooth:                   userManualSetName === modelPulseRed ? pulseRed.dspHorSmooth                 : pulseBlue.dspHorSmooth
    property int    soundSpeed:                     userManualSetName === modelPulseRed ? pulseRed.soundSpeed                   : pulseBlue.soundSpeed
    property int    ch1Period:                      userManualSetName === modelPulseRed ? pulseRed.ch1Period                    : pulseBlue.ch1Period
    property int    datasetChart:                   userManualSetName === modelPulseRed ? pulseRed.datasetChart                 : pulseBlue.datasetChart
    property int    datasetDist:                    userManualSetName === modelPulseRed ? pulseRed.datasetDist                  : pulseBlue.datasetDist
    property int    datasetSDDBT:                   userManualSetName === modelPulseRed ? pulseRed.datasetSDDBT                 : pulseBlue.datasetSDDBT
    property int    datasetEuler:                   userManualSetName === modelPulseRed ? pulseRed.datasetEuler                 : pulseBlue.datasetEuler
    property int    datasetTemp:                    userManualSetName === modelPulseRed ? pulseRed.datasetTemp                  : pulseBlue.datasetTemp
    property int    datasetTimestamp:               userManualSetName === modelPulseRed ? pulseRed.datasetTimestamp             : pulseBlue.datasetTimestamp
    property int    transFreqWide:                  userManualSetName === modelPulseRed ? pulseRed.transFreqWide                : pulseBlue.transFreqWide
    property int    transFreqMedium:                userManualSetName === modelPulseRed ? pulseRed.transFreqMedium              : pulseBlue.transFreqMedium
    property int    transFreqNarrow:                userManualSetName === modelPulseRed ? pulseRed.transFreqNarrow              : pulseBlue.transFreqNarrow
    property int    maximumDepth:                   userManualSetName === modelPulseRed ? pulseRed.maximumDepth                 : pulseBlue.maximumDepth
    property var    doDynamicResolution:            userManualSetName === modelPulseRed ? pulseRed.doDynamicResolution          : pulseBlue.doDynamicResolution
    property var    fixBlackStripesForwardSteps:    userManualSetName === modelPulseRed ? pulseRed.fixBlackStripesForwardSteps  : pulseBlue.fixBlackStripesForwardSteps
    property var    fixBlackStripesBackwardSteps:   userManualSetName === modelPulseRed ? pulseRed.fixBlackStripesBackwardSteps : pulseBlue.fixBlackStripesBackwardSteps
    property var    fixBlackStripesState:           userManualSetName === modelPulseRed ? pulseRed.fixBlackStripesState         : pulseBlue.fixBlackStripesState
    property var    temperatureCorrection:          userManualSetName === modelPulseRed ? pulseRed.temperatureCorrection        : pulseBlue.temperatureCorrection
    property var    bottomTrackVisible:             userManualSetName === modelPulseRed ? pulseRed.bottomTrackVisible           : pulseBlue.bottomTrackVisible
    property var    bottomTrackVisibleModel:        userManualSetName === modelPulseRed ? pulseRed.bottomTrackVisibleModel      : pulseBlue.bottomTrackVisibleModel
    property bool   processBottomTrack:             userManualSetName === modelPulseRed ? pulseRed.processBottomTrack           : pulseBlue.processBottomTrack
    property var    distProcessing:                 userManualSetName === modelPulseRed ? distProcPulseRed                      : distProcPulseBlue

    //ACTUAL DEVICE PARAMETER VALUE COPY

    //PER DEVICE PROPERTIES
    property int    chartResolution_Copy:                -1
    property int    chartSamples_Copy:                   -1
    property int    chartOffset_Copy:                    -1
    property int    distMax_Copy:                        -1
    property int    distDeadZone_Copy:                   -1
    property int    distConfidence_Copy:                 -1
    property int    transPulse_Copy:                     -1
    property int    transFreq_Copy:                      -1
    property int    transBoost_Copy:                     -1
    property int    dspHorSmooth_Copy:                   -1
    property int    soundSpeed_Copy:                     -1
    property int    ch1Period_Copy:                      -1
    property int    datasetChart_Copy:                   -1
    property int    datasetDist_Copy:                    -1
    property int    datasetSDDBT_Copy:                   -1
    property int    datasetEuler_Copy:                   -1
    property int    datasetTemp_Copy:                    -1
    property int    datasetTimestamp_Copy:               -1


    //TVG defaults are part of the profile: the Red is a 2D transducer, so the 2D TVG
    //(echogramTvgEnabled -> imageType 2) is the correct one and the side scan log-law
    //gain must stay off. The two are never both right at once.
    property var pulseRed: {
        "devName":                      "PULSEred",
        "settingVersion":               1,
        "is2DTransducer":               true,
        "useTemperature":               true,
        "chartResolution":              2,
        "chartSamples":                 500,
        "chartOffset":                  0,
        "distMax":                      50000,
        "distDeadZone":                 0,
        "distConfidence":               14,
        "transPulse":                   10,
        "transFreq":                    710,
        "transBoost":                   0,
        "dspHorSmooth":                 0,
        "soundSpeed":                   1480*1000,
        "ch1Period":                    50,
        "datasetChart":                 1,
        "datasetDist":                  0,
        "datasetSDDBT":                 1,
        "datasetEuler":                 0,
        "datasetTemp":                  1,
        "datasetTimestamp":             0,
        "transFreqWide":                510,
        "transFreqMedium":              710,
        "transFreqNarrow":              810,
        "maximumDepth":                 52,
        "processBottomTrack":           true,
        "doDynamicResolution":          true,
        "fixBlackStripesBackwardSteps": 5,
        "fixBlackStripesForwardSteps":  3,
        "fixBlackStripesState":         true,
        "temperatureCorrection":        -2.0,
        "bottomTrackVisible":           false,
        "bottomTrackVisibleModel":      0,
        "echogramTvgEnabled":           true,
        "sideScanTvgEnabled":           false
    }


    //TVG defaults are part of the profile: the Blue is a dual side scan, so the side scan
    //TVG (sideScanTvgEnabled -> imageType 3) is the correct one and the 2D TVG must stay
    //off. The two are never both right at once.
    property var pulseBlue: {
        "devName":                      "PULSEblue",
        "settingVersion":               1,
        "is2DTransducer":               false,
        "useTemperature":               false,
        "chartResolution":              25,
        "chartSamples":                 2000,
        "chartOffset":                  0,
        "distMax":                      1000 * 25,
        "distDeadZone":                 0,
        "distConfidence":               14,
        "transPulse":                   10,
        "transFreq":                    460,
        "transBoost":                   1,
        "dspHorSmooth":                 0,
        "soundSpeed":                   1480*1000,
        "ch1Period":                    70,
        "datasetChart":                 1,
        "datasetDist":                  0,
        "datasetSDDBT":                 1,
        "datasetEuler":                 0,
        "datasetTemp":                  0,
        "datasetTimestamp":             0,
        "transFreqWide":                460,
        "transFreqMedium":              460,
        "transFreqNarrow":              460,
        "maximumDepth":                 25,
        "processBottomTrack":           true,
        "doDynamicResolution":          false,
        "fixBlackStripesBackwardSteps": 5,
        "fixBlackStripesForwardSteps":  1,
        "fixBlackStripesState":         true,
        "temperatureCorrection":        0,
        "bottomTrackVisible":           false,
        "bottomTrackVisibleModel":      0,
        "echogramTvgEnabled":           false,
        "sideScanTvgEnabled":           true
    }

    property var    distProcPulseRed: [
        1,
        5,
        4,
        0.25,
        50,
        2,
        0,
        0,
        0,
        0
    ]

    property var    distProcPulseBlue: [
        2,
        5,
        4,
        0.25,
        35,
        2,
        0,
        0,
        0,
        0
    ]

    /*
    property var    distProcPulseBlue: [
        2,      0
        22,     1
        0,      2
        0,      3
        1000,   4
        200,    5
        0,      6
        0,      7
        0,      8
        0       9
    ]
    */


    /*
    void doDistProcessing(
    0 - int preset,
    1 - int window_size,
    2 - float vertical_gap,
    3 - float range_min,
    4 - float range_max,
    5 - float gain_slope,
    6 - float threshold,
    7 - float offsetx,
    8 - float offsety,
    9 - float offsetz);
    */


    //RETIRED 2026-08-29 — no longer read by anything (doAutoFilter() in Plot2D.qml is now
    //a no-op). Kept for reference until we are sure the water body filter covers every case
    //these tables used to handle.
    //They mapped depth -> filter strength because the old global low-cut also dimmed the
    //BOTTOM render, so the value had to be re-tuned per depth: too little left high-frequency
    //noise in the water column, too much faded the bottom out. The water body filter touches
    //the water column only and TVG makes the bottom render depth-independent, so one value
    //chosen to taste now works at every depth.
    property var autoFilterPulseRedNarrow: [
        { "min": 0,  "max": 1,  "filter": 23},
        { "min": 1,  "max": 2,  "filter": 22},
        { "min": 2,  "max": 3,  "filter": 21},
        { "min": 3,  "max": 4,  "filter": 20},
        { "min": 4,  "max": 5,  "filter": 19},
        { "min": 5,  "max": 6,  "filter": 18},
        { "min": 6,  "max": 7,  "filter": 17},
        { "min": 7,  "max": 8,  "filter": 16},
        { "min": 8,  "max": 9,  "filter": 15},
        { "min": 9,  "max": 10, "filter": 14},
        { "min": 10, "max": 11, "filter": 13},
        { "min": 11, "max": 12, "filter": 12},
        { "min": 12, "max": 13, "filter": 11},
        { "min": 13, "max": 14, "filter": 10},
        { "min": 14, "max": 15, "filter": 9 },
        { "min": 15, "max": 16, "filter": 8 },
        { "min": 16, "max": 17, "filter": 7 },
        { "min": 17, "max": 18, "filter": 6 },
        { "min": 18, "max": 19, "filter": 5 },
        { "min": 19, "max": 20, "filter": 4 },
        { "min": 20, "max": 22, "filter": 3 },
        { "min": 22, "max": 24, "filter": 2 },
        { "min": 24, "max": 30, "filter": 1 },
        { "min": 30, "max": 40, "filter": 0 },
        { "min": 40, "max": 100,"filter": 0 }
    ]


    property var autoFilterPulseRedWide: [
        { "min": 0,  "max": 1,  "filter": 14},
        { "min": 1,  "max": 2,  "filter": 13},
        { "min": 2,  "max": 3,  "filter": 12},
        { "min": 3,  "max": 4,  "filter": 11},
        { "min": 4,  "max": 5,  "filter": 10},
        { "min": 5,  "max": 6,  "filter": 9 },
        { "min": 6,  "max": 7,  "filter": 8 },
        { "min": 7,  "max": 8,  "filter": 7 },
        { "min": 8,  "max": 9,  "filter": 6 },
        { "min": 9,  "max": 10, "filter": 5 },
        { "min": 10, "max": 11, "filter": 4 },
        { "min": 11, "max": 13, "filter": 3 },
        { "min": 13, "max": 16, "filter": 2 },
        { "min": 16, "max": 21, "filter": 1 },
        { "min": 21, "max": 100,"filter": 0 }
    ]

    property var betaKeyCodes: [
        "k7d-4m9-zx3",
        "t3g-5r1-vq8",
        "p8b-2s7-lm0",
        "j2n-6z4-yr5",
        "w9q-1x6-ub2",
        "h5v-3k8-od9",
        "c4r-7t0-nj6",
        "bet-aus-ers",
        "3dr-550-560",
        "m6f-8q2-pa7",
        "r1x-3n9-vc4",
        "b9t-0k5-yw6",
        "z4p-7d1-hm8",
        "q2v-6s0-ln3"
    ]

    property var expertKeyCodes: [
        "n5f-8v2-mq1",
        "x3k-7t4-zr6",
        "y2b-5w9-jd3"
    ]


}


