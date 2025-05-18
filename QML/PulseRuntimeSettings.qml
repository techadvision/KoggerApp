// Non-persistent settings, storage for runtime preferences
pragma Singleton

import QtQuick 2.15

QtObject {
    id: pulseRuntimeSettings

    //DEVICES
    property string devName:                "..."           //Stores the connected device name
    property string modelPulseRed:          "PULSEred"        //Our device name for PulseRed. Will change!
    property string modelPulseBlue:         "PULSEblue"       //Our device name dor PulseBlue. Will change!
    property string modelPulseRedProto:     "ECHO20"        //Our device name for PulseRed. Will change!
    property string modelPulseBlueProto:    "NanoSSS"       //Our device name dor PulseBlue. Will change!
    property string userManualSetName:      "..."           //Stores the manually selected name when not automatically detected in main
    property string udpGateway:             "192.168.10.1"

    //CONNECTIONS UUID
    property string uuidIpGateway:          "{2ad43efc-61d1-4321-a925-a8e0cd188ca2}"
    property string uuidIpGateway2:         "{2ad43efc-61d1-4321-a925-a8e0cd188ca3}"
    property string uuidUsbSerial:          "{2ad43efc-61d1-4321-a925-a8e0cd188cd0}"
    property string uuidSuccessfullyOpened: ""

    //GENERAL SETUP STATES
    property bool   devDetected:            false   // App automatically detected the transducer by name
    property bool   devIdentified:          false   // The app recognizes the transducer as one of our supported models
    property bool   devSettingsEnforced:    false   // Transducer settings enforced
    property bool   devManualSelected:      false   // The user selected one of our selected models
    property bool   appConfigured:          false   // Setup steps for the app recongnized device is completed
    property bool   expertMode:             false   // Hidden feeatures shown when true
    property bool   isSideScan2DView:       false   // Side scan is detected, but user wants to show it as a 2D transducer (aka downscan)
    property bool   isOpeningKlfFile:       false
    property int    numberOfDatasetChannels:0       // The number of channels in the dataset received
    property int    currentDepthSolution:   -1       // Depth reporting inactive = 0, depth distance = 1, depth NMEA = 2

    //CONFIGURATION STATES
    property bool   onDeviceVersionChanged: false
    // overall
    property bool   devConfigured:          false   // when all of the below is true we have set everything up
    // dist
    property bool   onDistSetupChanged:     false
    property bool   distMax_ok:             false
    property bool   distDeadZone_ok:        false
    property bool   distConfidence_ok:      false
    // chart
    property bool   onChartSetupChanged:    false
    property bool   chartSamples_ok:        false
    property bool   chartResolution_ok:     true    // THIS WE SET DYNAMICALLY!!!
    property bool   chartOffset_ok:         false
    // dataset
    property bool   onDatasetChanged:       false
    property bool   datasetTimestamp_ok:    false
    property bool   datasetChart_ok:        false
    property bool   datasetTemp_ok:         false
    property bool   datasetEuler_ok:        false
    property bool   datasetDist_ok:         false
    property bool   datasetSDDBT_ok:        false
    // trans
    property bool   onTransChanged:         false
    property bool   transFreq_ok:           false
    property bool   transPulse_ok:          false
    property bool   transBoost_ok:          false
    // dsp
    property bool   onDspSetupChanged:      true    // LET'S NOT USE THIS AT ALL
    property bool   dspHorSmooth_ok:        true
    // sound
    property bool   onSoundChanged:         false
    property bool   soundSpeed_ok:          false

    //TRAFFIC STATES
    property bool   isReceivingData:        false   // When data is received, true
    property bool   didEverReceiveData:     false   // When data is received, true
    property bool   hasDeviceLostConnection:false   // if didEverReceiveData = true, and isReceivingData = false
    property bool   didReceiveDepthData:    false   // Used to track if depth data is received

    //UI AUTO CONTROL
    property double autoDepthMaxLevel:      49      // The current max level displayed, used for automatic change of display based on depth measure
    property double autoDepthMinLevel:      1       // The minimum chart level display allowed
    property double autoDepthLevelStep:     1       // The step in meters to evaluate when to automatically change the display
    property double autoDepthDistanceBelow: 1       // The additional distance below the measured depth and the step to show some screen below the measure
    property bool   shouldDoAutoRange:      false   // Should app automatically adjust the display according to depth measure or not?
    property double manualSetLevel:         0.0     // The fixe value of the screen display desired by the user, when manual fixing is desired
    property int    dynamicResolutionMin:   90      // The minimum allowed resolution in mm
    property int    dynamicResolutionMax:   2       // The maximum allowed resolution in mm
    property int    dynamicResolutionMargin:2       // The margin resolution in m
    property int    dynamicResolution:      30      // Initial value for resolution in mm, this value is possible to manipulate to alter resolution based on conditions
    property double hysterisisThreshold:    0.1     // resolution hysterisis for dynamic resolution
    property int    requiredStableReading:  3       // resolution shift count threshold
    property int    scrollingSpeed:         50      // Phased out - previous solution: Initial value for scrolling speed
    property double echogramSpeed:          1.0     // New solution for speed, fully working and not impacting data rates: Initial value for scrolling speed

    //RECORDING KLF
    property bool   isRecordingKlf:         false   // If a KLF recording is started or not
    property string klfFilePath:            ""      // File path used to view a KLF file

    //Temporary UDP preference (shall use persistent settings for this purpose
    property bool   enableNmeaDbt:          true

    //FALSE DEPTH READING ALGORITHM TUNING
    property double kSmallAgreeMargin:      0.2    // Flucutations allowed in filtering
    property double kLargeJumpThreshold:    3.0     // A jump from one value to the next before considered a likely false reading
    property int    kConsistNeeded:         10       // The threshold of values required before we believe it
    
    //COLOR MAP

    property var    themeModelBlue: [
        { id: 0,        icon: "./icons/pulse_color_ss_blue.svg" },
        { id: 1,        icon: "./icons/pulse_color_ss_sepia.svg" },
        { id: 2,        icon: "./icons/pulse_color_ss_gray.svg" },
        { id: 3,        icon: "./icons/pulse_color_ss_red.svg" },
        { id: 4,        icon: "./icons/pulse_color_ss_green.svg" }
    ]

    property var    themeModelRed: [
        { id: 5,        icon: "./icons/pulse_color_2d_e500_black.svg" },
        { id: 6,        icon: "./icons/pulse_color_2d_e500_white.svg" },
        { id: 7,        icon: "./icons/pulse_color_2d_furuno_black.svg" },
        { id: 8,        icon: "./icons/pulse_color_2d_furuno_white.svg" },
        { id: 9,        icon: "./icons/pulse_color_2d_sonic_black.svg" },
        { id: 10,       icon: "./icons/pulse_color_2d_sonic_white.svg" },
        { id: 11,       icon: "./icons/pulse_color_2d_lsss_black.svg" },
        { id: 12,       icon: "./icons/pulse_color_2d_lsss_white.svg" },
        { id: 13,       icon: "./icons/pulse_color_2d_hti_black.svg" },
        { id: 14,       icon: "./icons/pulse_color_2d_hti_white.svg" },
        { id: 15,       icon: "./icons/pulse_color_2d_dt4_black.svg" },
        { id: 16,       icon: "./icons/pulse_color_2d_dt4_white.svg" },
        { id: 1,        icon: "./icons/pulse_color_ss_sepia.svg" },
        { id: 4,        icon: "./icons/pulse_color_ss_green.svg" }
    ]

    //DISPLAY SETTINGS

    property bool   echogramVisible:                true
    property bool   bottomTrackVisible:             false
    property int    bottomTrackVisibleModel:        2
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
    property int    transFreqNarrow:                userManualSetName === modelPulseRed ? pulseRed.transFreqNarrow              : pulseBlue.transFreqNarrow
    property int    maximumDepth:                   userManualSetName === modelPulseRed ? pulseRed.maximumDepth                 : pulseBlue.maximumDepth
    property bool   processBottomTrack:             userManualSetName === modelPulseRed ? pulseRed.processBottomTrack           : pulseBlue.processBottomTrack
    property var    distProcessing:                 userManualSetName === modelPulseRed ? distProcPulseRed                      : distProcPulseBlue
    property var    doDynamicResolution:            userManualSetName === modelPulseRed ? pulseRed.doDynamicResolution          : pulseBlue.doDynamicResolution
    property var    fixBlackStripesForwardSteps:    userManualSetName === modelPulseRed ? pulseRed.fixBlackStripesForwardSteps  : pulseBlue.fixBlackStripesForwardSteps
    property var    fixBlackStripesBackwardSteps:   userManualSetName === modelPulseRed ? pulseRed.fixBlackStripesBackwardSteps : pulseBlue.fixBlackStripesBackwardSteps
    property var    fixBlackStripesState:           userManualSetName === modelPulseRed ? pulseRed.fixBlackStripesState         : pulseBlue.fixBlackStripesState
    property var    temperatureCorrection:          userManualSetName === modelPulseRed ? pulseRed.temperatureCorrection        : pulseBlue.temperatureCorrection


    /* // Force bad setting for testing
    property var pulseRed: {
        "devName":                      "ECHO20",
        "settingVersion":               1,
        "is2DTransducer":               true,
        "useTemperature":               true,
        "chartResolution":              6,
        "chartSamples":                 510,
        "chartOffset":                  1,
        "distMax":                      49000,
        "distDeadZone":                 1,
        "distConfidence":               15,
        "transPulse":                   11,
        "transFreq":                    610,
        "transBoost":                   0,
        "dspHorSmooth":                 0,
        "soundSpeed":                   1380*1000,
        "ch1Period":                    50,
        "datasetChart":                 1,
        "datasetDist":                  1,
        "datasetSDDBT":                 0,
        "datasetEuler":                 0,
        "datasetTemp":                  1,
        "datasetTimestamp":             0,
        "transFreqWide":                500,
        "transFreqNarrow":              610,
        "maximumDepth":                 45,
        "processBottomTrack":           true,
        "doDynamicResolution":          true,
        "fixBlackStripesBackwardSteps": 20,
        "fixBlackStripesForwardSteps":  20,
        "fixBlackStripesState":         true,
        "temperatureCorrection":        -1.5
    }
    */


    property var pulseRed: {
        "devName":                      "ECHO20",
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
        "transFreqNarrow":              710,
        "maximumDepth":                 45,
        "processBottomTrack":           true,
        "doDynamicResolution":          true,
        "fixBlackStripesBackwardSteps": 20,
        "fixBlackStripesForwardSteps":  20,
        "fixBlackStripesState":         true,
        "temperatureCorrection":        -1.5
    }


    property var pulseBlue: {
        "devName":                      "NanoSSS",
        "settingVersion":               1,
        "is2DTransducer":               false,
        "useTemperature":               false,
        "chartResolution":              37,
        "chartSamples":                 1358,
        "chartOffset":                  25,
        "distMax":                      25000,
        "distDeadZone":                 0,
        "distConfidence":               14,
        "transPulse":                   10,
        "transFreq":                    540,
        "transBoost":                   1,
        "dspHorSmooth":                 0,
        "soundSpeed":                   1480*1000,
        "ch1Period":                    50,
        "datasetChart":                 1,
        "datasetDist":                  0,
        "datasetSDDBT":                 1,
        "datasetEuler":                 0,
        "datasetTemp":                  0,
        "datasetTimestamp":             0,
        "transFreqWide":                540,
        "transFreqNarrow":              540,
        "maximumDepth":                 25,
        "processBottomTrack":           true,
        "doDynamicResolution":          false,
        "fixBlackStripesBackwardSteps": 20,
        "fixBlackStripesForwardSteps":  20,
        "fixBlackStripesState":         true,
        "temperatureCorrection":        0
    }

    //PER DEVICE DISTANCE PROCESSING

    property var    distProcPulseRed: [
        1,
        10,
        0,
        0,
        50.0,
        2,
        0.0,
        0,
        0,
        0
    ]

    property var    distProcPulseBlue: [
        2,
        20,
        0,
        0.00,
        30.0,
        2,
        0.0,
        0,
        0,
        0
    ]
    /*
    void doDistProcessing(
    int preset,
    int window_size,
    float vertical_gap,
    float range_min,
    float range_max,
    float gain_slope,
    float threshold,
    float offsetx,
    float offsety,
    float offsetz);
    */

    property var autoFilterPulseRedNarrow: [
        { "min": 0,  "max": 1,  "filter": 16},
        { "min": 1,  "max": 2,  "filter": 15},
        { "min": 2,  "max": 3,  "filter": 14},
        { "min": 3,  "max": 4,  "filter": 13},
        { "min": 4,  "max": 5,  "filter": 12},
        { "min": 5,  "max": 6,  "filter": 11},
        { "min": 6,  "max": 7,  "filter": 10},
        { "min": 7,  "max": 8,  "filter": 9 },
        { "min": 8,  "max": 9,  "filter": 8 },
        { "min": 9,  "max": 10, "filter": 7 },
        { "min": 10, "max": 12, "filter": 6 },
        { "min": 12, "max": 14, "filter": 5 },
        { "min": 14, "max": 18, "filter": 4 },
        { "min": 18, "max": 24, "filter": 3 },
        { "min": 24, "max": 30, "filter": 2 },
        { "min": 30, "max": 40, "filter": 1 },
        { "min": 40, "max": 100,"filter": 0 }
    ]

    property var autoFilterPulseRedWide: [
        { "min": 0,  "max": 1,  "filter": 11},
        { "min": 1,  "max": 2,  "filter": 10},
        { "min": 2,  "max": 3,  "filter": 9 },
        { "min": 3,  "max": 4,  "filter": 8 },
        { "min": 4,  "max": 5,  "filter": 7 },
        { "min": 5,  "max": 6,  "filter": 6 },
        { "min": 6,  "max": 7,  "filter": 5 },
        { "min": 7,  "max": 9,  "filter": 4 },
        { "min": 9,  "max": 12, "filter": 3 },
        { "min": 12, "max": 16, "filter": 2 },
        { "min": 16, "max": 21, "filter": 1 },
        { "min": 20, "max": 100,"filter": 0 }
    ]


}


