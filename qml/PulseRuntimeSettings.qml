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
    property int    rebootWindowMs:         20000   // reboot if stale within this many ms of first data
    property int    resetWindowMs:          60000   // clear “first data” after this many ms of stale
    property int    firstDataTs:            0       // Date.now() when we first saw data this session
    property bool   guardActive:            false   // true until rebootWindowMs elapses
    property bool   echoSounderReboot:      false
    property int    dataIsStaleElapseTime:  3500    // was 3500, change to 10000

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
    property int    echogramCompensationFile:0      // EXPERIMENTAL: Should be either 0 (raw) or 1 (side scan)

    //APP DYNAMIC CONTROLS
    property int    dynamicResolutionMin:   50      // The minimum allowed resolution in mm, reduced from 90 to 50
    property int    dynamicResolutionMax:   2       // The maximum allowed resolution in mm
    property int    dynamicResolutionMargin:2       // The margin resolution in m
    property int    dynamicResolution:      30      // Initial value for resolution in mm, this value is possible to manipulate to alter resolution based on conditions
    property bool   dynamicResolutionInit:  false   // The initial dynamic resolution was performed
    property int    dynamicSamplesMax:      500     // When reolution is maxed out, we alter the number of samples and the period
    property int    dynamicSamplesMin:      1020
    property int    dynamicSamplesStep:     20
    property int    dynamicPeriodMax:       50      // When reolution is maxed out, we alter the period and the number of samples
    property int    dynamicPeriodMin:       154
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
        "processBottomTrack":           false,
        "doDynamicResolution":          true,
        "fixBlackStripesBackwardSteps": 5,
        "fixBlackStripesForwardSteps":  3,
        "fixBlackStripesState":         true,
        "temperatureCorrection":        -2.0,
        "bottomTrackVisible":           false,
        "bottomTrackVisibleModel":      0
    }


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
        "doDynamicR esolution":          false,
        "fixBlackStripesBackwardSteps": 5,
        "fixBlackStripesForwardSteps":  1,
        "fixBlackStripesState":         true,
        "temperatureCorrection":        0,
        "bottomTrackVisible":           false,
        "bottomTrackVisibleModel":      0
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


