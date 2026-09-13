// Non-persistent settings, storage for runtime preferences
//pragma Singleton

import QtQuick 2.15

QtObject {
    id: pulseRuntimeSettings

    //DEVICES
    property string devName:                "..."           //Stores the connected device name
    property string modelPulseRed:          "PULSEred"      //Our device name for PulseRed.
    property string modelPulseBlue:         "PULSEblue"     //Our device name dor PulseBlue.
    //A PROFILE KEY, not a model name — never written into userManualSetName. See the note on
    //the profile map. PULSE blue on the IP telemetry link is still a PULSE blue to every
    //comparison in the app; only its profile differs.
    property string modelPulseBlueIp:       "PULSEblue-IP"
    property string modelPulseRedProto:     "Basic2D"        //Our device name for PulseRed. Will change!
    property string modelPulseBlueProto:    "Basic2D"       //Our device name dor PulseBlue. Will change!
    property string userManualSetName:      "..."           //Stores the manually selected name when not automatically detected in main

    //THE USER IS CHOOSING, AND DETECTION MUST NOT ANSWER.
    //
    //This is the fact the app never had, and it is the whole knot. "The app does not know
    //what is on the wire" and "the user has asked to decide" were the SAME state -
    //userManualSetName === "..." - and they want opposite behaviour. A transducer that
    //comes back after a dropped link should be identified at once; a deliberate
    //reselection must not be answered ten seconds later by the app itself.
    //
    //With the two separated, detection is one rule instead of five racing handlers:
    //
    //  commit a model when a device is identified in the list
    //    AND data is arriving        (isAnswering - the device is really there)
    //    AND nothing is committed    (userManualSetName === "...")
    //    AND the user is not choosing (this flag)
    //
    //It also replaces everCommittedModel, which existed only because a first commit could
    //not safely wait for data. The transducer free-runs - confirmed on device, with the
    //echogram moving while nothing was committed - so the rule needs no exemption.
    //
    //RAISED in one place, requestDeviceChoice(). CLEARED wherever the question is actually
    //answered: a model being committed (below), and starting a simulation, which is the
    //one exit from the connection screen that commits nothing.
    property bool   awaitingUserChoice:     false

    //THE USER ASKED FOR THE CONNECTION SCREEN. The rail's source button in PulseAppV2 is
    //the permanent door to it, and this is how that door reaches it: PulseConnectionScreen
    //is instantiated in main.qml and QML IDS DO NOT CROSS FILES, so the only route from a
    //component inside Plot2D is a root context property - which is what enterDemoMode()
    //lives here for as well.
    //
    //It is an OVERRIDE, not a second opinion. The screen holds ONE binding,
    //    visible: chooserAsking || userAsked
    //and nothing anywhere assigns `visible`. commitCard() and keepCurrent() clear this
    //again, and both commit a model, so the screen still cannot strand itself behind a
    //raised sheet.
    property bool   connectionScreenRequested: false

    //The expert control's affordance. SettingsCheckBox writes a bool; this turns that into
    //the action, and clears itself so the box can be ticked again.
    property bool   chooseDeviceNow:        false

    onChooseDeviceNowChanged: {
        if (!chooseDeviceNow)
            return
        chooseDeviceNow = false
        requestDeviceChoice()
    }

    //THE LAST MODEL THIS RUN ACTUALLY KNEW ABOUT. Survives every reset on purpose - it is
    //what lets "nothing is committed" mean "do not change anything" instead of "guess".
    //See resolveProfileKey().
    property string lastKnownModel: ""

    onUserManualSetNameChanged: {
        //A model is committed, so the question is answered however it was answered - by a
        //card, by Keep, or by detection. One place rather than one per exit, so a new way
        //out of the screen cannot forget to clear it and strand the app asking.
        if (awaitingUserChoice && userManualSetName !== "..." && userManualSetName !== "") {
            console.log("DEV_CHOICE: answered ->", userManualSetName)
            awaitingUserChoice = false
        }
        if (userManualSetName !== "..." && userManualSetName !== "")
            lastKnownModel = userManualSetName
    }

    //CHOOSE A DIFFERENT TRANSDUCER - the third of the three intents, and the only one that
    //is a question for the user. The order matters: raise the flag BEFORE the tear-down,
    //so that everything reacting to the un-commit already knows nobody should answer it.
    //swapDeviceNow keeps its real job here - it is the mechanism that resets the setup and
    //puts userManualSetName back to "..." - but it is no longer asked to MEAN anything.
    function requestDeviceChoice() {
        console.log("DEV_CHOICE: the user is choosing a transducer - detection will not answer")
        awaitingUserChoice = true
        swapDeviceNow = true
    }
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
    //THE CONNECTION ADDRESS, as an input to the profile resolver. Published by
    //ConnectionViewer.refreshConnectionAddress() from LinkManagerWrapper.openedIpAddress(),
    //which reads the address off the open UDP/TCP link in the link model. "" means no IP
    //link is open (a serial device, a log, nothing connected) and is read as "no opinion".
    property string connectionAddress:      ""
    //IS THERE HARDWARE TO PROTECT? Both published by ConnectionViewer, from the link model
    //and from the device list respectively — see hasConnectedDevice below, which is the
    //only thing that reads them. Kept as two separate facts because they answer two
    //different questions: a link can be open with nothing on it, and a device can be known
    //while its link is closed (a demo closes live links).
    property bool   linkIsOpen:             false
    property bool   deviceIsPresent:        false
    //Bumped when something wants identification re-run from scratch — leaving demo mode is
    //the one caller today. A counter rather than a flag: two requests in a row must both be
    //heard, and there is no state to forget to clear. ConnectionViewer watches it.
    property int    redetectRequestId:      0
    //The IP telemetry gateway's subnet. The 5.8 GHz wifi gateway is 192.168.10.*; the IP
    //link that replaced it in June/July 2026 is 192.168.144.*, and that is the whole tell.
    property string ipVariantPrefix:        "192.168.144."
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

    //RECONFIGURE IS NOT A SWAP, and conflating them is what made the force reselection
    //dangerous. Three different intents used to go through swapDeviceNow:
    //
    //  * "push my settings to the transducer again"  - the same device, nothing to decide
    //  * "restart the transducer"                    - the same device, via the hardware
    //  * "let me choose a different transducer"      - a question for the user
    //
    //Only the third has any business un-committing a model, and swapDeviceNow un-commits
    //ALWAYS: DeviceItem's handler puts userManualSetName back to "...". That is what drags
    //the connection screen up over a working echogram, re-opens a detection question
    //nobody asked, lets a stale device list answer it, and - because "..." resolves to
    //blue - spends the whole window configuring a red as a side scan.
    //
    //A re-push needs none of that. This flag re-runs the parameter handshake on the model
    //that is ALREADY committed, so there is no window at all.
    //
    //EXACTLY ONE HANDLER MAY READ IT, in DeviceItem, and it clears the flag before doing
    //any work. Backlog item 10 was two handlers on swapDeviceNow where the first cleared
    //it and re-entered the signal, leaving the second looking at a flag already false -
    //so the reset it existed to perform never ran at all.
    property bool   reconfigureNow:         false   // Re-push the profile to the committed device

    //DEVICE SWAP — the wire between detection and re-setup (backlog item 5, step 4).
    //
    //The two halves already existed and were never connected. ConnectionViewer already
    //re-commits userManualSetName when the board enum changes; DeviceItem already does the
    //whole re-setup behind swapDeviceNow. The only thing missing was something to raise
    //swapDeviceNow other than an expert ticking a box, and the resolver is the right place
    //because it is the one thing that knows a model actually CHANGED.
    //
    //Three situations, one mechanism: the user picks one device and connects another; the
    //app is started before the transducer is powered on (the common one, by accident rather
    //than by mistake); and both a red and a blue in the boat, one powered down and the
    //other up.
    //
    //TWO RULES, and they are what keeps this safe:
    //  * A SWAP IS NEVER SILENT. The app reconfigures a transducer as a consequence, so the
    //    user sees it happen and can refuse. Asking, not undoing: a reconfiguration cannot
    //    honestly be undone, so the choice comes first. deviceSwapAutomatic turns the ask
    //    off for anyone who would rather it just happened.
    //  * PLAYBACK IS NOT A DEVICE SWAP. Opening a log that disagrees with the connected
    //    transducer must not reconfigure hardware. This keys on the CONNECTION — it is
    //    called from the detection path only — and never on activeModel, which is exactly
    //    what a log moves.
    //A first commit is not a swap either: "..." -> blue is the app learning what is on the
    //wire, not a device being changed under it.
    property string pendingSwapFromModel:   ""      // "" = nothing being asked
    property string pendingSwapToModel:     ""
    property string declinedSwapToModel:    ""      // do not ask again for this one
    property bool   deviceSwapAutomatic:    false   // expert: swap without asking
    readonly property bool deviceSwapPending: pendingSwapToModel !== ""

    function requestDeviceSwap(fromModel, toModel) {
        if (toModel === "" || toModel === "..." || toModel === fromModel)
            return
        //Not a swap: nothing was committed yet. Let the caller commit normally.
        if (fromModel === "" || fromModel === "...")
            return
        if (isInDemoMode) {
            console.log("DEV_SWAP: ignored, demo mode")
            return
        }
        //A different device from the one that was refused: the refusal was about that one.
        if (declinedSwapToModel !== "" && declinedSwapToModel !== toModel)
            declinedSwapToModel = ""
        if (toModel === declinedSwapToModel) {
            console.log("DEV_SWAP: detected", toModel, "again, but the user declined it - not asking")
            return
        }

        pendingSwapFromModel = fromModel
        pendingSwapToModel   = toModel
        console.log("DEV_SWAP: detected", toModel, "while set up as", fromModel,
                    deviceSwapAutomatic ? "- swapping automatically" : "- asking the user")
        if (deviceSwapAutomatic)
            acceptDeviceSwap()
    }

    //Order matters. swapDeviceNow runs DeviceItem.onSwapDeviceNowChanged SYNCHRONOUSLY,
    //which clears every setup state and puts userManualSetName back to "...". Committing
    //the target afterwards is therefore what starts the configuration pass for the new
    //device; committing it first would be undone a line later.
    function acceptDeviceSwap() {
        var target = pendingSwapToModel
        pendingSwapFromModel = ""
        pendingSwapToModel   = ""
        declinedSwapToModel  = ""
        if (target === "")
            return
        console.log("DEV_SWAP: accepted -> re-running setup for", target)
        swapDeviceNow = true
        userManualSetName = target
    }

    function declineDeviceSwap() {
        console.log("DEV_SWAP: declined", pendingSwapToModel, "- keeping", pendingSwapFromModel)
        declinedSwapToModel  = pendingSwapToModel
        pendingSwapFromModel = ""
        pendingSwapToModel   = ""
    }

    //For anything that shows a model to a human. Falls back to the raw string so an
    //unrecognised device is named rather than hidden.
    function modelDisplayName(m) {
        if (m === modelPulseRed)  return "PULSE red"
        if (m === modelPulseBlue) return "PULSE blue"
        if (m === modelPulseBlueIp) return "PULSE blue (IP)"
        if (m === "" || m === "...") return "no device"
        return m
    }

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

    //THE USER CHOSE THE PICTURE OVER CERTAINTY.
    //
    //Set by "Start anyway" on the setup overlay when a setting will not go through. It does
    //NOT mean the device is configured - devConfigured stays false, because that is the
    //truth, and the handshake keeps trying underneath. It means one thing only: stop
    //halting the echogram while we wait.
    //
    //Olav's reason, and it is the right one: "There may be some hickup in the data flow or
    //an error in the hardware. Maybe the user is in need of a service. But if he is at the
    //water right now then something is better than nothing."
    //
    //Cleared whenever a fresh configuration starts, so it is never inherited by a device or
    //a session that never asked for it.
    property bool   runUnconfirmed:         false

    //TRAFFIC STATES
    //IS ANYTHING ACTUALLY ARRIVING, right now. The one fact this app did not have.
    //
    //Everything else here is about an IDENTITY that was learned once: isReceivingData and
    //didEverReceiveData are both raised by onDevNameChanged, not by data, and
    //hasDeviceLostConnection needs didEverReceiveData - which every reset clears and
    //nothing re-raises while the name stays put. So after a reset with the wifi gone, the
    //app holds a complete and entirely stale picture of a connected transducer.
    //
    //This one is raised ONLY by dataset.onDataUpdate and lowered ONLY by the 2.5 s
    //lostConnectionTimer, which that same signal restarts. One raiser, one lowerer, and it
    //owes nothing to any reset. It says DATA IS FLOWING and not "hardware is present": a
    //replayed log produces onDataUpdate too, which is why the one place that reads it also
    //requires a device in the list.
    property bool   isAnswering:            false   // Data arrived within the last 2.5 s
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
    property int    echogramCompensationFile:0      // 0 raw, 1 side scan AGC, 2 PULSE 2D TVG, 3 side scan TVG, 4 upstream TGC ramp

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

    //BACKLOG ITEM 8 — with nothing connected, the log IS the device.
    //
    //The display/configuration split above is right whenever a transducer is connected: an
    //opened log must never reconfigure hardware. It is wrong when nothing is connected at
    //all, which is every demo and every exhibition laptop — there is no hardware to protect,
    //and a side scan log wrapped in a 2D interface is simply the app being wrong about
    //itself in front of an audience.
    //
    //So the CONFIGURATION path gets one more input: whether anything is connected. Either
    //an open link or a known device is enough to keep today's behaviour — the relaxation
    //only happens when there is neither, which is the one case where it cannot break
    //anything. Note what this does NOT do: it never writes userManualSetName. The committed
    //MODEL is untouched, so nothing re-commits, no configuration pass starts, and closing
    //the log puts everything back. Only the KEY the UI reads moves. That is the same
    //"a key is not a model" line step 4 drew for PULSEblue-IP.
    property bool   hasConnectedDevice: linkIsOpen || deviceIsPresent

    //DEMO MODE DOES NOT ASK. Starting a playback is the explicit act: the user went to the
    //Recording tab and chose a file, and Core::startDemo() closes the live links on the way
    //in, so there is nothing being talked to whether or not a transducer is plugged in. The
    //stop button in that tab is the way back, and the app returns to the connected device on
    //its own because presentedModel falls back to userManualSetName the moment isInDemoMode
    //goes false. A stand with the transducer in an aquarium and a log on the projector is
    //exactly this case, and it must not depend on whether a cable happens to be in.
    //
    //A plain OPENED FILE still asks, because opening one closes no links and configuration
    //keeps running: there, a connected transducer really is being talked to.
    property bool   isPresentingLog: (isInDemoMode
                                      || ((wasKlfFileOpened || isOpeningKlfFile) && !hasConnectedDevice))
                                     && activeModel !== ""

    onIsPresentingLogChanged: {
        console.log("PROFILE: presenting a log ->", isPresentingLog,
                    "| presenting", presentedModel, "| committed", userManualSetName,
                    "| demo", isInDemoMode, "| fileView", wasKlfFileOpened || isOpeningKlfFile,
                    "| linkOpen", linkIsOpen, "| devicePresent", deviceIsPresent)
    }

    //What the app should present itself AS. The committed model, except while presenting a
    //log with nothing connected, when it is the log's own identity.
    property string presentedModel: isPresentingLog ? activeModel : userManualSetName

    //TVG — Stage A (display-only). See tvg_analysis_and_recommendation.md v2.
    //PER-PROFILE DEFAULT since 2026-08-29: 2D TVG and side scan TVG are never both the
    //"right" answer, so the default now comes from the device profile (pulseRed /
    //pulseBlue below) instead of a flat false. Writing to either property from the expert
    //panel breaks this binding for the rest of the session — deliberate: a manual expert
    //choice must not be silently undone by a reconnect. Restart restores the profile
    //default, as with every other runtime TVG value.
    property bool   echogramTvgEnabled:     activeProfile !== undefined ? activeProfile.echogramTvgEnabled
                                                                        : false
    property double echogramTvgDbPerMeter:  0.9     // Net decay constant in dB/m (Dreamlake harvest: 0.66-1.11, mean ~0.9)

    //WHICH 2D GAIN LAW RENDERS — comparison switch, 2026-09-12.
    //
    //The upstream 1.0.3 merge brought in a linear TGC ramp (gain gTgcGainNear -> gTgcGainFar
    //straight across the trace) and it was written into Epoch::chartTo() at imageType 2, the
    //id PULSE's own EchogramTvg already held. Being first in the chain it shadowed ours, so
    //every "2D TVG" render since the merge was in fact upstream's ramp and EchogramTvg never
    //ran at all. Upstream's branch now lives at imageType 4 and 2 is EchogramTvg again.
    //
    //Both laws are kept because retiring one is a decision about the picture, not a merge
    //conflict: PULSE's constant is field-tuned (echogramTvgDbPerMeter 0.9, from the Dreamlake
    //harvest) and upstream's ramp is not the same law. This switch is how they are compared
    //on the water — flip it with the 2D echogram on screen and the picture changes under you.
    //
    //NOT PERSISTENT (nothing in this file is), so every launch starts on PULSE's TVG. That is
    //deliberate: the comparison is a deliberate act, never a state to wake up in. Note that
    //echogramTvgDbPerMeter does nothing while this is on — upstream's ramp has its own
    //constants (Core.setTgcGainNear / setTgcGainFar), which no PULSE UI touches today.
    property bool   echogram2DUpstreamTgc:  false
    readonly property int echogram2DGainId: echogram2DUpstreamTgc ? 4 : 2

    //Side scan TVG — side scan phase (expert-gated, display-only). Log-law range
    //gain (imageType 3) validated offline on SS_pulse_log_2026.07.20: consistent
    //intensity over range (brightness = bottom hardness) instead of the AGC's
    //local-contrast normalization. Defaults mirror EchogramSideScanTvg constants.
    property bool   sideScanTvgEnabled:      activeProfile !== undefined ? activeProfile.sideScanTvgEnabled
                                                                         : false    // waterfall uses TVG (3) instead of AGC (1)
    property double sideScanTvgSpreading:    5      // S in dB/decade (field-tuned 2026-08-16; deeper water/chirp may want more)
    property double sideScanTvgAbsorption:   0.0    // a in dB/m (field-tuned: 0 on 25 m ranges; matters for chirp long range)
    property double sideScanTvgRefRange:     15     // gain = 1 at this range (m): near field keeps familiar brightness
    property double sideScanTvgNoiseFloor:   0.1    // noise-floor subtraction strength 0..1 (0 = off; base level for partner testing 2026-08-17)
    property double sideScanTvgBoost:        1.2    // detail boost beta (field-tuned: essential for crispness)
    property bool   sideScanTvgMosaicEnabled:false  // mosaic renders TVG buffer instead of AGC (rebuild applied on switch)

    // Single source of truth for the echogram compensation id.
    // 2D uses the selected gain law (echogram2DGainId: 2 = PULSE EchogramTvg,
    // 4 = upstream's linear TGC ramp) when enabled, else raw (0); side scan uses
    // side scan TVG (3) when enabled, else AGC (1).
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
        return (activeModel === modelPulseRed) ? (echogramTvgEnabled  ? echogram2DGainId : 0)
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

        //Starting a simulation is an answer to "which transducer", and the only one that
        //commits no model - so the clear on userManualSetName cannot cover it. Without
        //this, awaitingUserChoice would still be raised when the demo stops and item 9's
        //re-detection would be refused by the rule.
        if (awaitingUserChoice) {
            console.log("DEV_CHOICE: answered by starting a simulation")
            awaitingUserChoice = false
        }

        //AND SO IS THE USER'S OWN REQUEST FOR THE SCREEN. Starting a simulation from the
        //connection screen is a way OUT of it, exactly like committing a card, so the
        //override has to fall here too - otherwise the screen the rail's source button
        //raised would stay up over the replay it just started.
        if (connectionScreenRequested) {
            console.log("DEV_CHOICE: the connection screen request is answered by the simulation")
            connectionScreenRequested = false
        }

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
        // device. The "Configuring transducer..." overlay now keys on isAnswering
        // rather than dataUpdateActive, so it cannot linger over a dead link by
        // itself; clearing the rest still matters, because devConfigured and
        // devName decide whether the app believes it is mid-setup.
        // Stage 2 replaces this with the consolidated resetAppToFreshState().
        didEverReceiveData = false
        hasDeviceLostConnection = false
        isReceivingData = false
        dataUpdateActive = false
        devConfigured = false
        devDetected = false
        devIdentified = false
        appConfigured = false
        numberOfDatasetChannels = 0
        devName = "..."
        userManualSetName = "..."
        pulseBetaName = "..."

        //BACKLOG ITEM 9 — come back to the real transducer without a restart.
        //
        //Core::startDemo() closes the live links and Core::stopDemo() deliberately does not
        //reopen them, because reopening while the app still believed it was mid-configuration
        //is what produced the stuck "Configuring transducer..." overlay. That reasoning was
        //right and the note said reconnecting should stay an explicit action — but no
        //affordance was ever given to be explicit FROM, so in practice it became "restart
        //the app".
        //
        //Pressing stop IS the explicit action. The overlay it guarded against cannot appear
        //from here: every flag that drives it — devConfigured and devName — has just been
        //cleared above, so the app reopens the link in the same state it would have had at
        //a cold start with a device attached.
        //
        //Then ask for identification to be re-run. ConnectionViewer.selectCorrectDevice()
        //otherwise only fires on a device-list change, a channel-count change and the
        //Basic2D settle timer, so a link that comes back up with a transducer already
        //talking may never produce one of those.
        if (linkManagerWrapper) {
            console.log("DEMO: reopening the links the demo closed")
            linkManagerWrapper.openClosedLinks()
        }
        redetectRequestId += 1
    }

    // "..." is the app's own word for "nothing is identified" - what DeviceItem puts
    // userManualSetName back to on a swap or a force reselection, and what a cold start
    // begins with. Stated once here because the strip's two silences turn on it.
    readonly property bool nothingIdentified: userManualSetName === "..."

    // ---- THE LINK, AS ONE HONEST LINE ---------------------------------------
    //
    // HOISTED here from PulseConnectionScreen (13 Sept 2026) because it has a second
    // reader: the rail's source button shows the same state as a coloured dot. Computing
    // it twice would be a second opinion about the same facts, which is exactly what that
    // screen was built to stop - and QML ids do not cross files, so a root context property
    // is the only place both can read it. ONE COMPUTATION, TWO READERS.
    //
    // Everything below is already computed somewhere: ConnectionViewer publishes
    // linkIsOpen and deviceIsPresent, the device publishes devName, the channel count,
    // the firmware and the serial, and the resolver already has the address. Nothing new
    // is stored - one binding reads facts that four other places were reading anyway.
    //
    // Deliberately NOT phrased around a cable. Practically every PULSE in the field is
    // wireless - the wifi gateway, and the IP connector from the boat onwards - so
    // anything built on "wired" would describe almost nobody. What the owner actually has
    // is a transducer that is not answering, and much the commonest reason is that the thing
    // it is mounted on, a boat or a pole kit, is not switched on yet.
    // GREEN IS A CLAIM ABOUT NOW, so it needs data arriving now and nothing else.
    //
    // It used to be built on linkIsOpen and devName, and a screenshot caught what that
    // costs: wifi off, the red "Lost connection" box in the corner, and this strip still
    // green with "Connected to PULSEred, 192.168.10.1, s/n 139". A UDP socket does not
    // close because the wifi went away and devName survives every reset, so both terms
    // were stale - while the "lost" branch was unreachable, because it was built on
    // didEverReceiveData, which every reset clears.
    readonly property bool linkAnswering:
        isAnswering
    readonly property bool linkNamed:
        devName !== "..." && devName !== ""
    readonly property bool linkFound:
        deviceIsPresent

    // THE TWO SILENCES ARE DIFFERENT QUESTIONS, and this is the whole of the change.
    //
    //   a model is committed and the data stopped  -> we expect it back. "Connection
    //      lost", amber, identity retained. This is the ordinary wifi drop, and the
    //      echogram keeps its screen while it waits.
    //   nothing is committed and the data stopped  -> the identity is HISTORY, not a
    //      claim. "Was connected to PULSE red", gray. Olav's past tense, and the state
    //      the old machine could not express at all.
    //
    // Which one you are in is decided by what is committed, so the strip needs no state
    // of its own - it reads facts three other things already read.
    readonly property bool linkCommitted: !nothingIdentified

    readonly property string linkState:
          (linkAnswering && linkNamed) ? "talking"
        : linkAnswering                ? "identifying"
        : linkCommitted                ? "lost"
        : lastKnownModel !== ""         ? "wasConnected"
        : linkFound                    ? "found"
        :                                "absent"

    readonly property color linkColor:
          linkState === "lost"    ? "#ffcc00"
        : linkState === "talking" ? "#3ec46d"
        : linkState === "absent"  ? "#6d7480"
        : linkState === "wasConnected" ? "#6d7480"
        :                           "#3d7fd0"

    // modelDisplayName, not the raw devName: it turns PULSEred into "PULSE red" and falls
    // back to the raw string for anything this build does not recognise, so an unknown
    // device is still named rather than hidden.
    readonly property string linkHeadline:
          linkState === "talking"      ? "Connected to "
                                         + modelDisplayName(devName)
        : linkState === "identifying"  ? "Connected, identifying the transducer"
        : linkState === "lost"         ? "Connection lost"
        : linkState === "wasConnected" ? "Was connected to "
                                         + modelDisplayName(lastKnownModel)
        : linkState === "found"        ? "Transducer found, nothing open on it yet"
        :                                "Not connected"

    readonly property string linkDetail: {
        if (linkState === "lost")
            return "It stopped answering. Power and range are the usual two."
        if (linkState === "talking") {
            var bits = []
            var ch = numberOfDatasetChannels
            if (ch > 0)
                bits.push(ch === 1 ? "1 channel" : ch + " channels")
            if (connectionAddress !== "")
                bits.push(connectionAddress)
            // An EMPTY firmware version printed the label with nothing after it - the
            // screenshot reads "192.168.10.1   fw   s/n 139". The guard only excluded the
            // string "not set".
            if (rawDev_firmwareVersion !== "not set"
                    && rawDev_firmwareVersion !== "")
                bits.push("fw " + rawDev_firmwareVersion)
            if (rawDev_devSerialNumber >= 0)
                bits.push("s/n " + rawDev_devSerialNumber)
            return bits.join("   \u00b7   ")
        }
        if (linkState === "identifying")
            return "Waiting for it to say what it is."
        if (linkState === "wasConnected") {
            // What it WAS, stated as history. The address and serial are worth keeping:
            // they are how the owner recognises which one it was.
            var was = ["Nothing is answering now."]
            if (connectionAddress !== "")
                was.push(connectionAddress)
            if (rawDev_devSerialNumber >= 0)
                was.push("s/n " + rawDev_devSerialNumber)
            return was.join("   \u00b7   ")
        }
        if (linkState === "found")
            return "A device is listed, but nothing has been opened on it yet."
        return "Nothing is answering yet. Power the transducer on and this screen closes "
             + "itself the moment it is recognised."
    }


    //LEAVING A FILE VIEW - the pill's Close, and deliberately NOT a copy of exitDemoMode().
    //
    //OPENING A FILE CLOSES NO LINKS. That is exactly why a plain opened file still asks
    //about a device swap, and why showLostConnection() returns early for it: with a
    //transducer connected the app really is still talking to it underneath the picture.
    //So there is nothing to reopen here, and - the part that matters - nothing to forget.
    //Clearing devName and userManualSetName the way the demo path does would throw away a
    //live, configured device and send it round the whole setup pass again.
    //
    //What DOES have to move is the key the interface reads. committedProfileKey resolves
    //from presentedModel, which is the log's identity while a log is showing; dropping the
    //file puts presentedModel back to userManualSetName by itself. The redetect request is
    //for the other case - nothing committed either - so detection gets a fresh chance to
    //answer instead of the app sitting on "...".
    //
    //Olav's rule for it: "similar behavior as stopping a demo - if the transducer is
    //connected then let us talk to it. This is a consistent way to operate, people will
    //understand."
    function exitFileView() {
        if (!wasKlfFileOpened && !isOpeningKlfFile) {
            console.log("FILE VIEW: nothing open to close")
            return
        }

        console.log("FILE VIEW: closing", klfFilePath === "" ? "(no path)" : klfFilePath)
        core.closeLogFile()

        wasKlfFileOpened = false
        isOpeningKlfFile = false
        klfFilePath      = ""

        redetectRequestId += 1
    }

    // ---- THE MAX RANGE, AND ITS CEILING (backlog item 11) -------------------
    //
    // ONE KEY NAME, BOTH DIRECTIONS. There are three stored preferences, and the classic
    // selector READS two of them and WRITES three:
    //
    //     read : displayIs2DTransducer ? maxDepthValue : maxDepthValuePulseBlue
    //     write: displayIs2DTransducer ? maxDepthValue
    //          : isSideScan2DView      ? maxDepthValuePulseBlue
    //          :                         maxDepthValuePulseBlueFixed
    //
    // So a blue in SIDE SCAN writes ...Fixed and reads ...PulseBlue back - while setSideScan()
    // applies ...Fixed to the plot. The control shows one number and the picture uses another.
    // That is the same class of fault the doc already records twice: a write-back keyed
    // differently from the read is how a value lands in one preference and is read out of
    // another. Naming the key ONCE and using it for both makes it impossible rather than
    // fixed.
    //
    // (isSideScan2DView reads backwards and is not renamed here: TRUE means the blue is in
    // DOWN scan. setDownScan() sets it true, setSideScan() sets it false.)
    readonly property string displayMaxRangeKey:
          displayIs2DTransducer ? "maxDepthValue"
        : isSideScan2DView      ? "maxDepthValuePulseBlue"
        :                         "maxDepthValuePulseBlueFixed"

    readonly property int displayMaxRange: pulseSettings[displayMaxRangeKey]

    // THE ONE WRITER, and both callers reach it: the panel's slider and a pinch on the
    // picture. A preference is never written while nothing is identified - with no device
    // and no log there is no device whose preference this is.
    function storeDisplayMaxRange(v) {
        if (presentedModel === "..." || presentedModel === "")
            return
        if (pulseSettings[displayMaxRangeKey] === v)
            return
        console.log("RANGE: storing", v, "in", displayMaxRangeKey)
        pulseSettings[displayMaxRangeKey] = v
    }

    // THE CEILING, as backlog item 11 says it should be.
    //
    // `maximumDepth` above is a binding on committedProfile.maximumDepth that THREE places
    // assign to - DeviceItem, the connection screen's blue seed, and the expert dist-max
    // control - so the first assignment destroys it and it freezes at whichever device was
    // current. Item 11 was parked precisely because this control was being redesigned.
    //
    // A 2D transducer's ceiling is HARDWARE: red's 52 is its 50 m dist max plus two, and
    // nothing assigns it. A side scan's ceiling is the configured SWATH WIDTH, which no
    // static profile key can hold - and echogramWidth is exactly what all three of those
    // assigners were copying into maximumDepth anyway. So read the live value instead of a
    // copy of it, and the freeze cannot happen.
    //
    // ONE OVERRIDE, for the expert dist-max control when tier 3 reaches the panel. It writes
    // THIS, never the binding - which is the whole shape rule 2 asks for. Nothing writes it
    // yet, and zero means "no override".
    property int maxRangeCeilingOverride: 0

    readonly property int displayMaxRangeCeiling:
          maxRangeCeilingOverride > 0 ? maxRangeCeilingOverride
        : displayIs2DTransducer       ? committedProfile.maximumDepth
        :                               pulseSettings.echogramWidth

    // The floor and the step are the picture's questions too - a side scan steps in 5 m and
    // everything else in 1 - so all of it reads the display model, exactly as the classic
    // control was corrected to do.
    readonly property int displayMaxRangeFloor:
          displayIs2DTransducer ? 1
        : isSideScan2DView      ? 1
        : expertMode            ? 5
        :                         10

    readonly property int displayMaxRangeStep:
          displayIs2DTransducer ? 1
        : isSideScan2DView      ? 1
        :                         5

    //APP DYNAMIC CONTROLS
    //NUMERIC convention since 2026-08-29: Min is always the SMALLER number, whatever the
    //quantity means. These six bounds used to be named after resolution QUALITY (finer
    //resolution = fewer mm), so dynamicResolutionMin held 50 and Max held 2 — and that
    //inverted convention had been copied to samples and period as well. The clamp code
    //has always been Math.max(candidate, <lower>) then Math.min(result, <upper>); after
    //the swap those read Min then Max, which is idiomatic for the first time.
    //Now declared per profile, in ui.tunable.resolution. Both devices carry 2 / 50 / 2
    //today, so this is the same three numbers arriving from a different place - but it is
    //what lets the IP profile widen them without touching any code, since the IP link no
    //longer pays for resolution in wireless range.
    //Read uiProfile directly rather than through tunable(), so the binding's dependency on
    //it is plain to see and does not rely on capture through a function call.
    property int    dynamicResolutionMin:   (uiProfile && uiProfile.tunable && uiProfile.tunable.resolution) ? uiProfile.tunable.resolution.minMm   : 2
    property int    dynamicResolutionMax:   (uiProfile && uiProfile.tunable && uiProfile.tunable.resolution) ? uiProfile.tunable.resolution.maxMm   : 50
    property int    dynamicResolutionMargin:(uiProfile && uiProfile.tunable && uiProfile.tunable.resolution) ? uiProfile.tunable.resolution.marginM : 2
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

    //WHAT THE PICTURE SHOULD BE DRAWN IN. One binding over the two stored preferences and
    //the DISPLAY model, and nothing anywhere assigns it.
    //
    //THE THREE KEYS, because two of them are constantly confused for each other:
    //  colorMapIndexSideScan  blue's OWN preference - an index into themeModelBlue
    //  colorMapIndex2D        red's OWN preference  - an index into the master themeModelRed
    //  colorMapIndexReal      the SHARED applied theme id, and what main.qml publishes to
    //                         the C++ over the settings bus
    //
    //The classic chooser assigns that third key from SIX places, and the damage is on
    //record: the 2D selector read it as its source of truth, found the blue's theme inside
    //the red list - themeModelRed is a superset, it carries ids 0-4 and 26 as well - and
    //wrote that position back into colorMapIndex2D. The red's own preference was not
    //displayed wrong, it was DESTROYED, which is why it survived a restart. The side scan
    //selector had the mirror fault: nothing applied its stored theme until the control was
    //shown, so a red-committed app replaying a side scan drew the log with the red theme
    //still loaded in the plot.
    //
    //Seven handlers keep that honest today. This binding needs none of them:
    //  - nothing has to be VISIBLE for the value to be true, so there is no apply-on-show;
    //  - the display model changing re-evaluates it, so no onUserManualSetNameChanged;
    //  - the selected swatch is a binding on the stored index, so nothing recalculates it;
    //  - and neither chooser can reach the other's key, so choosing a blue cannot touch red.
    //
    //DISPLAY, not committed - rule 1. A palette is the plainest thing on screen that is
    //judged by looking at it.
    //QUALIFIED, and that is not a style point. colorMapIndex2D and colorMapIndexSideScan
    //live on pulseSettings, NOT here - and an unqualified name that this object does not
    //own resolves to nothing, so both terms arrived as `undefined`, themeIdAt fell back to
    //model[0], and the whole binding sat on the FIRST entry of whichever list was showing.
    //Choosing a theme wrote its key correctly and changed nothing, because nothing was
    //reading the key.
    readonly property int displayThemeId: displayIs2DTransducer
        ? themeIdAt(themeModelRed,  pulseSettings.colorMapIndex2D)
        : themeIdAt(themeModelBlue, pulseSettings.colorMapIndexSideScan)

    //A stored index that is out of range can only come from a build that shortened a list,
    //so fall back to the first entry rather than let every reader get undefined.
    //
    //AND SAY SO. The silent version of this fallback hid a whole broken binding for a device
    //build: an unqualified property name resolved to `undefined`, undefined failed the range
    //test, and every call quietly answered model[0]. A fallback that cannot be seen in the
    //log is a fallback that cannot be debugged.
    function themeIdAt(model, index) {
        if (!model || model.length === 0)
            return 0
        if (index >= 0 && index < model.length)
            return model[index].id
        console.log("THEME: index", index, "is not in a list of", model.length,
                    "- falling back to the first entry")
        return model[0].id
    }

    function themeEntryAt(model, index) {
        if (!model || model.length === 0)
            return null
        return (index >= 0 && index < model.length) ? model[index] : model[0]
    }

    //The list the chooser SHOWS, and the key it writes. Both follow the display model for
    //the same reason the id above does.
    readonly property var  displayThemeModel: displayIs2DTransducer ? themeModelRed : themeModelBlue
    readonly property int  displayThemeIndex: displayIs2DTransducer
        ? pulseSettings.colorMapIndex2D
        : pulseSettings.colorMapIndexSideScan

    //Favourites are a 2D idea only - blue has six themes and never needed them.
    readonly property bool displayThemeFavouritesActive:
        displayIs2DTransducer && pulseSettings.useFavoriteThemes2D
        && pulseSettings.favoriteThemes2DNew.length > 0

    onDisplayThemeIdChanged: console.log("THEME: display theme ->", displayThemeId,
                                         "|", displayIs2DTransducer ? "2D" : "side scan",
                                         "| stored index", displayThemeIndex)


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
    
    
    //PROFILE MAP — one entry per device. Adding hardware is adding one entry here and
    //one line in the resolver below; nothing else in this file branches on the model.
    //The records themselves (pulseRed / pulseBlue) are unchanged and still further down.
    property var profiles: ({
        "PULSEred":     pulseRed,       // = modelPulseRed
        "PULSEblue":    pulseBlue,      // = modelPulseBlue
        "PULSEblue-IP": pulseBlueIp     // = modelPulseBlueIp — blue on the IP telemetry link
    })

    //A PROFILE KEY IS NOT A MODEL. The model is what the hardware IS (PULSEred / PULSEblue)
    //and is what userManualSetName holds and what every comparison outside this file means.
    //A profile key is the model PLUS how it is connected, which is why "PULSEblue-IP" exists
    //as a key and must never be written into userManualSetName: the transducer on the IP
    //gateway is an ordinary PULSE blue and everything that asks "is this a blue" must still
    //get yes.

    //TWO lookups, not one — and this is deliberate. The two paths key on different things
    //and always have (see the long note above activeModel):
    //
    //  committedProfile  the CONFIGURATION path — resolution, samples, ranges, datasets,
    //                    frequencies, dist processing. Keyed on userManualSetName, the
    //                    model the user or the detection committed to.
    //  activeProfile     the DISPLAY path — the TVG defaults only. Keyed on activeModel,
    //                    which demo mode and an opened .klf override, because a log
    //                    carries its own identity and that is what must drive display gain.
    //
    //Collapsing them into one lookup would be a behaviour change, not a tidy-up: it would
    //put an opened log's gain curve on the connected transducer's configuration, or the
    //other way round.

    //THE RESOLVER (step 4). This replaces the ternary that stood here, which read "anything
    //that is not PULSEred is blue". It takes the three things the strategy named — the
    //committed/detected model, the channel count, and the connection address — and answers
    //with a profile KEY.
    //
    //What it deliberately does NOT do is second-guess the Basic2D settle window.
    //ConnectionViewer holds back the commit while a single-channel Basic2D might still turn
    //out to be a blue whose second channel is a beat late, and userManualSetName is "..."
    //for as long as that lasts. If the resolver decided red from "one channel right now" it
    //would configure a red transducer during exactly the window that machinery exists to
    //protect. So the channel count is used ONLY where nothing else has an answer at all: an
    //identified device whose name we do not recognise, which is the case that arrives with
    //the new hardware ids. Everything known keeps the behaviour it had.
    //
    //Manual override still wins, as it always has: userManualSetName is written by the
    //manual pick in main.qml as well as by detection, and this reads it first.
    function resolveProfileKey(model, address, channels) {
        //A recognised model decides outright.
        if (model === modelPulseRed)
            return modelPulseRed
        if (model === modelPulseBlue)
            return blueKeyFor(address)

        //Unrecognised but identified: no name to go on, so the channel count answers — the
        //same rule ConnectionViewer.modelForBoard() uses to split the Basic2D batch, and the
        //only thing that generalises to hardware this build has never heard of. The proto
        //names are excluded: they go through the settle window, not through here.
        if (model !== "" && model !== "..." && model !== modelPulseRedProto && model !== modelPulseBlueProto) {
            if (channels === 1)
                return modelPulseRed
            if (channels >= 2)
                return blueKeyFor(address)
        }

        //NOTHING IS COMMITTED, and that is not a question this function should answer with
        //a guess. "..." is not an unrecognised device - it is NO device, and the honest
        //response to "I have not been told yet" is to change nothing.
        //
        //It used to fall through to blue, and the log showed what that cost. Between a
        //reset and the next commit:
        //
        //  PROFILE: committed key -> PULSEblue | model ...  | channels 0
        //  dev.chartResolution set to 25   distMax 25000   transBoost 1
        //
        //A red transducer spent the whole window being configured as a side scan - 25 m
        //instead of 50, resolution 25 instead of 2 - because every binding on
        //committedProfile snapped to blue, and those are not merely read, they are WRITTEN
        //to the device. It is also the root of the four symptoms after an accepted swap:
        //the view, the colour map, the max depth ceiling and the temperature were not four
        //regressions but four values read or assigned inside a window in which the whole
        //app believed it was a blue.
        //
        //Holding the last model changes nothing on the wire, because that model is what the
        //device is already configured for. The recursion terminates at once: lastKnownModel
        //is only ever a real model.
        if (model === "" || model === "...") {
            if (lastKnownModel !== "" && lastKnownModel !== "...")
                return resolveProfileKey(lastKnownModel, address, channels)
            //Nothing has ever been committed this run, so there is nothing to hold and no
            //device to misconfigure. Blue stays the right guess, exactly as before.
            return blueKeyFor(address)
        }

        //Still inside the Basic2D settle window: an identified device whose model is not
        //decided yet. Blue, which is what this has always fallen back to. Still the thing
        //to revisit when a second red-like device exists; with three profiles that are two
        //blues and one red it remains correct.
        return blueKeyFor(address)
    }

    //The one place the connection enters the answer. Everything blue-shaped asks this, so
    //the IP variant can never be reached by one path and missed by another.
    function blueKeyFor(address) {
        return isIpVariantAddress(address) ? modelPulseBlueIp : modelPulseBlue
    }

    //The IP telemetry gateway lives on 192.168.144.*; the 5.8 GHz wifi gateway does not.
    //An empty address means "not known" — no IP link is open, or nobody has told us — and
    //reads as NO OPINION, never as a negative, so an unknown connection behaves exactly as
    //this did before the IP variant existed.
    function isIpVariantAddress(address) {
        return typeof address === "string" && address.indexOf(ipVariantPrefix) === 0
    }

    //presentedModel, not userManualSetName: with nothing connected a replayed log decides
    //the whole interface rather than only the picture. See isPresentingLog above.
    property string committedProfileKey: resolveProfileKey(presentedModel, connectionAddress,
                                                           numberOfDatasetChannels)

    //Unknown keys can only come from a bug, but a profile that is `undefined` fails silently
    //in QML — every read becomes undefined and controls quietly vanish. Fall back rather
    //than fail, and say so in the log.
    property var committedProfile: (profiles[committedProfileKey] !== undefined)
                                       ? profiles[committedProfileKey]
                                       : profiles[modelPulseBlue]

    //undefined when nothing is identified (activeModel === ""), which is what makes the
    //TVG defaults fall back to false rather than guess. Same three-way as before.
    //
    //NOTE the asymmetry, and it is correct: activeModel is a MODEL, never a profile key, so
    //this never resolves to PULSEblue-IP. A log or a demo carries a transducer's identity,
    //not a connection — nothing about how the data reached the app changes what gain curve
    //its samples want. The IP variant only ever affects the CONFIGURATION path.
    property var activeProfile: profiles[activeModel]

    onCommittedProfileKeyChanged: {
        console.log("PROFILE: committed key ->", committedProfileKey,
                    "| model", presentedModel,
                    isPresentingLog ? "(presenting a log, nothing connected; committed "
                                      + userManualSetName + ")" : "",
                    "| address", connectionAddress === "" ? "(none)" : connectionAddress,
                    "| channels", numberOfDatasetChannels)
        if (profiles[committedProfileKey] === undefined)
            console.log("PROFILE: WARNING - no profile record for key", committedProfileKey,
                        "- falling back to", modelPulseBlue)
    }

    //WHAT THE INTERFACE OFFERS. This is the committed device's ui block, and it is the
    //answer to "should this control exist", replacing the old habit of inferring it from
    //is2DTransducer. Committed, not active: a chooser offers HARDWARE choices, so it must
    //follow the transducer that is connected, never a log that happens to be playing.
    property var uiProfile: committedProfile.ui

    //PLAIN PROPERTIES for anything a QML binding depends on. Bindings capture the property
    //reads they make, and these read uiProfile directly, so a device swap re-evaluates every
    //control that shows or hides on them. The functions further down are for imperative use
    //(handlers, timers), where capture does not come into it.
    //WHAT THE PROFILE CARRIES vs WHAT THE INTERFACE OFFERS. An entry may be expertOnly, so
    //these are two different lists and confusing them is how a stored choice goes wrong.
    //  *All  - every entry the device has. Migration and the legacy positional transFreq*
    //          readers use these, because they must not move when expert mode does.
    //  ui*   - what the chooser shows RIGHT NOW. Everything the user touches uses these.
    //Reading expertMode here is deliberate: it is a property, so the choosers grow and
    //shrink the moment it is toggled, with no restart. That is requirement 1 of the
    //forward-looking list, in this one corner.
    property var  uiViewsAll:       (uiProfile && uiProfile.views) ? uiProfile.views : []
    property var  uiConesAll:       (uiProfile && uiProfile.cones) ? uiProfile.cones : []
    property var  uiViews:          uiViewsAll.filter(function (e) { return !e.expertOnly || expertMode })
    property var  uiCones:          uiConesAll.filter(function (e) { return !e.expertOnly || expertMode })
    property var  uiViewIcons:      uiViews.map(function (e) { return e.icon })
    property var  uiConeIcons:      uiCones.map(function (e) { return e.icon })
    //Never offer a choice of one. A device with a single view or a single cone shows no
    //chooser at all, which is exactly what the Red does for views and the Blue for cones.
    property bool offersViewChoice: uiViews.length > 1
    property bool offersConeChoice: uiCones.length > 1
    //Named capability flags and per-device artwork, for the controls that used to ask
    //is2DTransducer whether they should exist.
    property var  uiOffers:         (uiProfile && uiProfile.offers) ? uiProfile.offers : ({})
    property var  uiBrand:          (uiProfile && uiProfile.brand)  ? uiProfile.brand  : ({})

    //THE CARD LIST, and it is the one ui.* list that does NOT read the committed profile.
    //Every accessor above answers "what does the transducer on the wire offer", so it reads
    //committedProfile. This one is the question asked when nothing is committed and there
    //may be nothing on the wire at all, so it spans the whole map and the connection screen
    //reads it whole.
    //
    //A VARIANT IS NOT A MODEL. PULSEblue-IP is blue's record plus overrides, so it inherits
    //blue's cards; offering them again would draw the blue card twice and hand a profile KEY
    //to userManualSetName, which must never happen. A record offers its cards only when its
    //key IS its model - which is exactly what devName says - so a variant contributes none.
    readonly property var uiCards: cardsFromProfiles(profiles)

    function cardsFromProfiles(map) {
        var out = []
        for (var key in map) {
            var prof = map[key]
            if (!prof || prof.devName !== key)
                continue
            var ui = prof.ui
            if (!ui || !ui.cards)
                continue
            for (var i = 0; i < ui.cards.length; i++)
                out.push(cardForScreen(ui.cards[i], ui.brand))
        }
        return out
    }

    //THE SHAPE THE SCREEN READS, stated once and in one place: id, name, tagline, art, logo,
    //badge, profile. The record carries `wordmark` instead of `logo` - the name of one of
    //the two wordmarks in its own brand block - and this is where that name becomes the path
    //the Image loads. A record with no second wordmark resolves to "", and the screen
    //already falls back to the live-text name when an image does not load.
    function cardForScreen(card, brand) {
        return {
            "id":      card.id,
            "name":    card.name,
            "tagline": card.tagline,
            "art":     card.art,
            "logo":    (brand && brand[card.wordmark] !== undefined) ? brand[card.wordmark] : "",
            "badge":   card.badge,
            "profile": card.profile
        }
    }

    //Cone list accessors (PULSE red). Index is a position in the OFFERED list, which is
    //what the chooser hands back; the stored preference is an id, never a position.
    function coneCount()            { return uiCones.length }
    function coneAt(i)              { return (i >= 0 && i < uiCones.length) ? uiCones[i] : null }
    //Falls back to the profile's own transFreq, which is what a device with no cone list
    //(the Blue) transmitted at anyway - the three legacy transFreq* properties below all
    //read 460 on blue for exactly that reason. Reads the FULL list: those three are legacy
    //positional readers and must not move when an expert-only entry appears.
    function coneFreq(i, fallback)  { var c = uiConesAll
                                      return (i >= 0 && i < c.length) ? c[i].freq : fallback }

    //View list accessors (PULSE blue). Same rule: index = position in the offered list.
    function viewCount()            { return uiViews.length }
    function viewAt(i)              { return (i >= 0 && i < uiViews.length) ? uiViews[i] : null }
    //A position can always outlive the list it came from - a shorter list after an entry is
    //withdrawn, a longer one in expert mode. Clamp rather than trust, always.
    function clampViewIndex(i)      { var n = viewCount(); if (n <= 0) return 0
                                      return (i < 0) ? 0 : (i >= n ? n - 1 : i) }
    //"down" or "side" for a view POSITION; "down" when there is no list, which is what a
    //2D transducer shows. Prefer viewModeForId() at anything that reads the preference.
    function viewMode(i)            { var e = viewAt(clampViewIndex(i)); return e ? e.mode : "down" }

    //-- STABLE ENTRY IDS ---------------------------------------------------------------
    //
    //ecoViewId / ecoConeId store an entry's `id`, never its position. A position means a
    //different thing in every list it outlives; an id means the same thing forever, which
    //is what lets a list grow with expert mode, shrink when hardware is withdrawn, or gain
    //a new device's entries without rewriting anybody's stored preference.
    //
    //THE FALLBACK IS NEVER WRITTEN BACK. resolve*Id() answers "what should be showing" for
    //a stored id that is not currently offered - the same MODE at another frequency where
    //there is one (side820 -> side460 on leaving expert mode), otherwise the first entry.
    //The stored id keeps the user's own choice, so turning expert mode back on restores it.
    //Only a real tap on the chooser writes the preference.
    function idAt(list, i)          { return (i >= 0 && i < list.length) ? list[i].id : "" }
    function indexOfId(list, id)    { for (var i = 0; i < list.length; i++)
                                          if (list[i].id === id) return i
                                      return -1 }
    function entryForId(list, id)   { var i = indexOfId(list, id); return i >= 0 ? list[i] : null }
    function resolveId(list, id, allList) {
        if (list.length <= 0)
            return ""
        if (indexOfId(list, id) >= 0)
            return id
        //Not offered. If the entry exists on the device but is hidden right now, keep the
        //user in the same mode rather than throwing them to the top of the list.
        var hidden = entryForId(allList, id)
        if (hidden && hidden.mode !== undefined) {
            for (var i = 0; i < list.length; i++)
                if (list[i].mode === hidden.mode)
                    return list[i].id
        }
        return list[0].id
    }

    function viewIdAt(i)            { return idAt(uiViews, i) }
    function coneIdAt(i)            { return idAt(uiCones, i) }
    function resolveViewId(id)      { return resolveId(uiViews, id, uiViewsAll) }
    function resolveConeId(id)      { return resolveId(uiCones, id, uiConesAll) }
    function viewIndexForId(id)     { var i = indexOfId(uiViews, resolveViewId(id)); return i < 0 ? 0 : i }
    function coneIndexForId(id)     { var i = indexOfId(uiCones, resolveConeId(id)); return i < 0 ? 0 : i }
    function viewForId(id)          { return entryForId(uiViews, resolveViewId(id)) }
    function coneForId(id)          { return entryForId(uiCones, resolveConeId(id)) }
    function viewModeForId(id)      { var e = viewForId(id); return e ? e.mode : "down" }

    //ONE-SHOT MIGRATION from the positional preferences, called once from
    //PulseSettings.Component.onCompleted. Returns the id to store, or "" to leave alone.
    //
    //Deliberately NOT resolved against the committed profile: nothing is committed at
    //startup, so committedProfile would fall back to blue and a red user's stored cone
    //index would be read against an empty list. Views only ever existed on the Blue and
    //cones only on the Red, so each migrates against the profile that owns it, and the
    //answer does not depend on what happens to be plugged in.
    function migrateViewId(storedId, legacyIndex) {
        if (storedId !== "")
            return ""
        var all = (pulseBlue.ui && pulseBlue.ui.views) ? pulseBlue.ui.views : []
        if (all.length <= 0)
            return ""
        var i = (legacyIndex < 0) ? 0 : (legacyIndex >= all.length ? all.length - 1 : legacyIndex)
        return all[i].id
    }
    function migrateConeId(storedId, legacyIndex) {
        if (storedId !== "")
            return ""
        var all = (pulseRed.ui && pulseRed.ui.cones) ? pulseRed.ui.cones : []
        if (all.length <= 0)
            return ""
        var i = (legacyIndex < 0) ? 0 : (legacyIndex >= all.length ? all.length - 1 : legacyIndex)
        return all[i].id
    }

    function tunable(name)          { return uiProfile && uiProfile.tunable ? uiProfile.tunable[name] : undefined }

    //PER DEVICE PROPERTIES
    property bool   settingVersion:                 committedProfile.settingVersion
    property bool   useTemperature:                 committedProfile.useTemperature
    property bool   is2DTransducer:                 committedProfile.is2DTransducer

    //THE DISPLAY SIDE OF THE SAME QUESTION (backlog items 7 and 10). is2DTransducer above is
    //a fact about the COMMITTED device and is what decides configuration and what the
    //choosers offer. This one is a fact about the PICTURE: what is on screen right now, log
    //or live. Anything the user judges by looking at it — the echogram orientation, the
    //grid, which colour palette is offered — belongs on this side, because a palette is a
    //ramp painted on the samples on screen and has nothing to do with the transducer on the
    //wire. Falls back to the committed answer when nothing is identified, which is the same
    //three-way activeProfile already does.
    property bool   displayIs2DTransducer: (activeProfile !== undefined)
                                               ? activeProfile.is2DTransducer
                                               : is2DTransducer

    //WHICH UI IS UP, as ONE binding, published to C++ on the runtime bus. The aim layer
    //needs it to know which loupe to paint, and C++ cannot read pulseSettings.uiVariant.
    //It lives here rather than as a second `=== "v2"` test beside every reader for the
    //same reason displayThemeId does: a string compared in several places is a string
    //that will be spelt differently in one of them.
    readonly property bool uiVariantIsV2:   pulseSettings.uiVariant === "v2"
    property int    chartResolution:                committedProfile.chartResolution
    property int    chartSamples:                   committedProfile.chartSamples
    property int    chartOffset:                    committedProfile.chartOffset
    property int    distMax:                        committedProfile.distMax
    property int    distDeadZone:                   committedProfile.distDeadZone
    property int    distConfidence:                 committedProfile.distConfidence
    property int    transPulse:                     committedProfile.transPulse
    property int    transFreq:                      committedProfile.transFreq
    property int    transBoost:                     committedProfile.transBoost
    property int    dspHorSmooth:                   committedProfile.dspHorSmooth
    property int    soundSpeed:                     committedProfile.soundSpeed
    property int    ch1Period:                      committedProfile.ch1Period
    property int    datasetChart:                   committedProfile.datasetChart
    property int    datasetDist:                    committedProfile.datasetDist
    property int    datasetSDDBT:                   committedProfile.datasetSDDBT
    property int    datasetEuler:                   committedProfile.datasetEuler
    property int    datasetTemp:                    committedProfile.datasetTemp
    property int    datasetTimestamp:               committedProfile.datasetTimestamp
    //Derived from the cone list so there is ONE place a frequency is written down. A device
    //with no cone list (the Blue) falls back to its own transFreq, which is what these three
    //held for it before: 460, 460, 460.
    property int    transFreqWide:                  coneFreq(0, committedProfile.transFreq)
    property int    transFreqMedium:                coneFreq(1, committedProfile.transFreq)
    property int    transFreqNarrow:                coneFreq(2, committedProfile.transFreq)
    property int    maximumDepth:                   committedProfile.maximumDepth
    property var    doDynamicResolution:            committedProfile.doDynamicResolution
    property var    fixBlackStripesForwardSteps:    committedProfile.fixBlackStripesForwardSteps
    property var    fixBlackStripesBackwardSteps:   committedProfile.fixBlackStripesBackwardSteps
    property var    fixBlackStripesState:           committedProfile.fixBlackStripesState
    property var    temperatureCorrection:          committedProfile.temperatureCorrection
    property var    bottomTrackVisible:             committedProfile.bottomTrackVisible
    property var    bottomTrackVisibleModel:        committedProfile.bottomTrackVisibleModel
    property bool   processBottomTrack:             committedProfile.processBottomTrack
    property var    distProcessing:                 committedProfile.distProcessing

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
        "sideScanTvgEnabled":           false,
        "distProcessing":               distProcPulseRed,

        //What the INTERFACE offers for this device. Read through uiProfile, never inferred
        //from is2DTransducer. Adding or removing a choice here is the whole edit.
        "ui": {
            //The Red asks a CONE question: one frequency per cone width. The order is the
            //order of the buttons; ecoConeIndex indexes this list.
            //id is the STABLE handle: it is what ecoConeId stores, and it must never be
            //reused or renamed once shipped. A cone is a beam width, so the width names it
            //and the frequency is how the width is achieved - retuning 710 must not move
            //anybody's stored choice. expertOnly exists on every entry; see the Blue's
            //view list for what it is for.
            "cones": [
                { "id": "wide",   "expertOnly": false, "icon": "./icons/ui/pulse_cone_510.svg", "freq": 510, "name": "wide",   "title": "Wide"   },
                { "id": "medium", "expertOnly": false, "icon": "./icons/ui/pulse_cone_710.svg", "freq": 710, "name": "medium", "title": "Medium" },
                { "id": "narrow", "expertOnly": false, "icon": "./icons/ui/pulse_cone_810.svg", "freq": 810, "name": "narrow", "title": "Narrow" }
            ],
            //No view chooser on a 2D transducer: it has one view.
            "views": [],
            //WHAT THIS RECORD OFFERS ON THE CONNECTION SCREEN. One entry per card the
            //owner can point at before anything is connected, and a new model is one more
            //entry here and nothing anywhere else.
            //
            //TWO CARDS, ONE PROFILE. Red and black are the same hardware at 510/710/810 kHz
            //and black is a true downscan, so `profile` is written in the card rather than
            //inferred from the record holding it: what a card commits is a MODEL, never a
            //profile key. (If bottom track or TVG ever want different numbers for black, it
            //stops being a card here and becomes a record of its own.)
            //
            //`wordmark` names an entry in `brand` below - "logo" or "logoBlack" - instead of
            //repeating its path, so renaming a model's artwork stays one edit.
            "cards": [
                { "id": "red",   "name": "PULSE red",   "tagline": "2D echo sounder",
                  "art": "./image/pulse_device_red.png",   "wordmark": "logo",
                  "badge": "#d81f26", "profile": modelPulseRed },
                { "id": "black", "name": "PULSE black", "tagline": "Downscan",
                  "art": "./image/pulse_device_black.png", "wordmark": "logoBlack",
                  "badge": "#6d7480", "profile": modelPulseRed }
            ],
            //WHAT THIS DEVICE'S INTERFACE OFFERS, by name. Every key exists on every
            //profile - absent would mean "undefined", and a control that hides because a
            //key was forgotten is the worst kind of bug to find on the water.
            "offers": {
                "doubleEchoOptimize":     true,   //2D only: optimize to include second echo
                "screenSpeed2D":          true,   //2D echogram screen speed (1-5)
                "scanWidthMeters":        false,  //side-/downscan meters
                "nmeaMtw":                true,   //NMEA MTW (temperature) sentence
                "sideScanMounting":       false,  //left-hand mount / cable facing front
                "depthFilter":            true,   //expert: use depth filter + its margin
                "depthFilterBottomTrack": false   //expert: depth filter w/bottom track
            },
            //Per-device artwork. A new device is a new set of images, not a new branch.
            //logoBlack is empty when the device has no second wordmark.
            "brand": {
                "infoImage": "./image/pulse_info_red_black_large.png",
                "logo":      "./image/pulse_logo_red.png",
                "logoBlack": "./image/pulse_logo_black.png"
            },
            //Limits the UI must respect. resolution is live (dynamicResolution* read it).
            //samples and period are declared but not yet consumed - there is nothing to
            //vary between red and blue, and the IP profile in step 4 is what makes them
            //mean something. See the note on the blue profile.
            "tunable": {
                "resolution": { "enabled": true,  "minMm": 2,   "maxMm": 50, "marginM": 2 },
                "samples":    { "enabled": false, "min": 100,   "max": 1000 },
                "period":     { "enabled": false, "minMs": 30,  "maxMs": 200 }
            }
        }
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
        "sideScanTvgEnabled":           true,
        "distProcessing":               distProcPulseBlue,

        //What the INTERFACE offers for this device. Read through uiProfile, never inferred
        //from is2DTransducer. Adding or removing a choice here is the whole edit.
        "ui": {
            //No cone chooser on the Blue: the cone is fixed, the choice is a VIEW.
            "cones": [],
            //The Blue asks a VIEW question. mode drives the grid and the range call
            //("down" = horizontal grid / plotDistanceRange2d, "side" = vertical grid /
            //plotDistanceRange); freq is what the view is transmitted at.
            //
            //820 kHz LIVES HERE, and as of step 4 it is a DATA EDIT - nothing else.
            //
            //820 was never withdrawn outright. One professional report found the current
            //blue transducer has insufficient power to render 820 properly in deeper water,
            //so it was pulled from the ORDINARY chooser only; experts can still reach it
            //from "Pulse blue High/Low Frequenzy" in the experimental expert category
            //(PulseInfoExpert.qml), which writes transFreq and useBlueHighFrequency direct.
            //
            //That is what expertOnly is for: the entry exists in the profile always, and
            //appears in the chooser only while expertMode is on. What used to make this
            //unsafe was ecoViewIndex storing a POSITION - a list that grows and shrinks with
            //expert mode would make the same stored number mean a different view in the two
            //modes. The preference now stores the entry's `id`, so a list that changes size
            //cannot change what a stored choice means. Leaving expert mode while an
            //expert-only view is selected falls back to the same MODE at another frequency
            //(side820 -> side460) and does NOT overwrite the stored id, so turning expert
            //mode back on restores the expert's own choice.
            //
            //To put 820 back, replace the two entries below with these four. Both icons are
            //already in the repo and registered in resources/icons.qrc, and the _460
            //variants exist too, so the buttons say which frequency they are:
            //    { "id": "down460", "expertOnly": false, "icon": "./icons/ui/pulse_view_down_scan_460.svg", "mode": "down", "freq": 460, "title": "Down scan" },
            //    { "id": "down820", "expertOnly": true,  "icon": "./icons/ui/pulse_view_down_scan_820.svg", "mode": "down", "freq": 820, "title": "Down scan" },
            //    { "id": "side460", "expertOnly": false, "icon": "./icons/ui/pulse_view_side_scan_460.svg", "mode": "side", "freq": 460, "title": "Side scan" },
            //    { "id": "side820", "expertOnly": true,  "icon": "./icons/ui/pulse_view_side_scan_820.svg", "mode": "side", "freq": 820, "title": "Side scan" }
            //tools/pulse-profile-check.js runs exactly that edit as its acceptance test.
            //
            //An id is a PROMISE: it is what sits in the user's settings file. Never rename
            //one and never reuse a retired one for a different view.
            "views": [
                { "id": "down460", "expertOnly": false, "icon": "./icons/ui/pulse_view_down_scan.svg", "mode": "down", "freq": 460, "title": "Down scan" },
                { "id": "side460", "expertOnly": false, "icon": "./icons/ui/pulse_view_side_scan.svg", "mode": "side", "freq": 460, "title": "Side scan" }
            ],
            //One card: the Blue is one piece of hardware. See red's list for what the
            //keys mean and why `profile` and `wordmark` are written the way they are.
            "cards": [
                { "id": "blue",  "name": "PULSE blue",  "tagline": "Side scan",
                  "art": "./image/pulse_device_blue.png",  "wordmark": "logo",
                  "badge": "#3d7fd0", "profile": modelPulseBlue }
            ],
            //WHAT THIS DEVICE'S INTERFACE OFFERS, by name. Same key set as every other
            //profile; only the answers differ.
            "offers": {
                "doubleEchoOptimize":     false,
                "screenSpeed2D":          false,
                "scanWidthMeters":        true,
                "nmeaMtw":                false,
                "sideScanMounting":       true,
                "depthFilter":            false,
                "depthFilterBottomTrack": true
            },
            "brand": {
                "infoImage": "./image/pulse_info_blue_large.png",
                "logo":      "./image/pulse_logo_blue.png",
                "logoBlack": ""
            },
            "tunable": {
                "resolution": { "enabled": true,  "minMm": 2,   "maxMm": 50, "marginM": 2 },
                "samples":    { "enabled": false, "min": 500,   "max": 4000 },
                "period":     { "enabled": false, "minMs": 50,  "maxMs": 300 }
            }
        }
    }

    //PULSEblue-IP — PULSE blue reached over the IP telemetry link instead of the 5.8 GHz
    //wifi. The transducer is the same transducer and the picture is the same picture, so
    //this is blue's record with a small set of overrides rather than a second copy of 37
    //keys that would then have to be kept in step with blue forever. mergedProfile() is a
    //two-level merge: a plain object on both sides merges, anything else is replaced.
    //
    //WHAT IS OVERRIDDEN TODAY: only ui.tunable — what the interface is ALLOWED to offer.
    //Nothing that is transmitted to the device changes, deliberately. chartResolution,
    //chartSamples and ch1Period stay exactly blue's, so committing this profile is provably
    //a no-op on the wire and the first build can prove it. The IP link affords far more
    //than wifi did — on wifi every extra sample was paid for in maximum wireless range,
    //which is why dynamic resolution exists at all — but what those numbers should BE is a
    //measurement on the water, not a guess made here. Widen them when they are known; the
    //limits below are what lets the UI expose the controls in the first place.
    property var pulseBlueIpOverrides: {
        "ui": {
            "tunable": {
                //resolution is LIVE: dynamicResolutionMin/Max/Margin read it. Left at
                //blue's 2/50/2 for now for the same reason as above.
                "resolution": { "enabled": true, "minMm": 2,  "maxMm": 50,  "marginM": 2 },
                //samples and period are declared-but-unconsumed on red and blue because
                //there was nothing to vary. This is the profile they were declared for.
                "samples":    { "enabled": true, "min": 500,  "max": 12000 },
                "period":     { "enabled": true, "minMs": 20, "maxMs": 300 }
            }
        }
    }

    property var pulseBlueIp: mergedProfile(pulseBlue, pulseBlueIpOverrides)

    //Two-level merge, and two levels is the point: ui.tunable.resolution replaces as a whole
    //object so a variant cannot accidentally inherit half a range. Arrays replace outright —
    //a views or cones list is a list, never a patch.
    function mergedProfile(base, overrides) {
        var out = {}
        var k
        for (k in base)
            out[k] = base[k]
        for (k in overrides) {
            var b = base[k], o = overrides[k]
            if (isPlainObject(b) && isPlainObject(o)) {
                var sub = {}
                for (var j in b) sub[j] = b[j]
                for (var i in o) sub[i] = o[i]
                out[k] = sub
            } else {
                out[k] = o
            }
        }
        return out
    }

    function isPlainObject(v) {
        return v !== null && typeof v === "object" && !Array.isArray(v)
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


