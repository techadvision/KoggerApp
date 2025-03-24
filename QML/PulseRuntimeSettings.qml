// Non-persistent settings, storage for runtime preferences
pragma Singleton

import QtQuick 2.15

QtObject {
    id: pulseRuntimeSettings

    //DEVICES
    property string devName:                "..."
    property string modelPulseRed:          "ECHO20"
    property string modelPulseBlue:         "NanoSSS"
    property string userManualSetName:      "..."
    property string udpGateway:             "192.168.10.1"

    //CONNECTIONS UUID
    property string uuidIpGateway:          "{2ad43efc-61d1-4321-a925-a8e0cd188ca2}"
    property string uuidUsbSerial:          "{2ad43efc-61d1-4321-a925-a8e0cd188cd0}"
    property string uuidSuccessfullyOpened: ""

    //GENERAL SETUP STATES
    property bool   devDetected:            false   // App automatically detected the transducer by name
    property bool   devIdentified:          false   // The app recognizes the transducer as one of our supported models
    property bool   devConfigured:          false   // Initial config for the recongnized device is completed
    property bool   devManualSelected:      false   // The user selected one of our selected models
    property bool   appConfigured:          false   // Setup steps for the app recongnized device is completed
    property bool   expertMode:             false   // Hidden feeatures shown when true
    property bool   isSideScan2DView:       false   // Side scan is detected, but user wants to show it as a 2D transducer (aka downscan)
    property bool   isOpeningKlfFile:       false

    //TRAFFIC STATES
    property bool   isReceivingData:        false   // When data is received, true
    property bool   didEverReceiveData:     false   // When data is received, true
    property bool   hasDeviceLostConnection:false   // if didEverReceiveData = true, and isReceivingData = false

    //UI AUTO CONTROL
    property double autoDepthMinLevel:      2       // The minimum chart level display allowed
    property double autoDepthMaxLevel:      2       // The current max level displayed, used for automatic change of display based on depth measure
    property double autoDepthLevelStep:     1       // The step in meters to evaluate when to automatically change the display
    property double autoDepthDistanceBelow: 1       // The additional distance below the measured depth and the step to show some screen below the measure
    property bool   shouldDoAutoRange:      false   // Should app automatically adjust the display according to depth measure or not?
    property double manualSetLevel:         0.0     // The fixe value of the screen display desired by the user, when manual fixing is desired
    property int    dynamicResolutionMin:   90      // The minimum allowed resolution in mm, here 30 mm resolution
    property int    dynamicResolutionMax:   3       // The maximum allowed resolution in mm, here 3 mm resolution
    property int    dynamicResolution:      30      // Initial value for resolution in mm, this value is possible to manipulate to alter resolution based on conditions
    property int    scrollingSpeed:         50      // Initial value for scrolling speed
    //COLOR MAP
    property var    fullThemeArray: [
        "./icons/pulse_color_ss_blue.svg",
        "./icons/pulse_color_ss_sepia.svg",
        "./icons/pulse_color_ss_gray.svg",
        "./icons/pulse_color_ss_red.svg",
        "./icons/pulse_color_ss_green.svg",
        "./icons/pulse_color_2d_e500_black.svg",
        "./icons/pulse_color_2d_e500_white.svg",
        "./icons/pulse_color_2d_furuno_black.svg",
        "./icons/pulse_color_2d_furuno_white.svg",
        "./icons/pulse_color_2d_sonic_black.svg",
        "./icons/pulse_color_2d_sonic_white.svg",
        "./icons/pulse_color_ss_sepia.svg"
    ]


    //PER DEVICE PROPERTIES
    property bool   settingVersion:     devName === pulseRed.devName ? pulseRed.settingVersion    : pulseBlue.settingVersion
    property bool   useTemperature:     devName === pulseRed.devName ? pulseRed.useTemperature    : pulseBlue.useTemperature
    property bool   is2DTransducer:     devName === pulseRed.devName ? pulseRed.is2DTransducer    : pulseBlue.is2DTransducer
    property int    chartResolution:    devName === pulseRed.devName ? pulseRed.chartResolution   : pulseBlue.chartResolution
    property int    chartSamples:       devName === pulseRed.devName ? pulseRed.chartSamples      : pulseBlue.chartSamples
    property int    chartOffset:        devName === pulseRed.devName ? pulseRed.chartOffset       : pulseBlue.chartOffset
    property int    distMax:            devName === pulseRed.devName ? pulseRed.distMax           : pulseBlue.distMax
    property int    distDeadZone:       devName === pulseRed.devName ? pulseRed.distDeadZone      : pulseBlue.distDeadZone
    property int    distConfidence:     devName === pulseRed.devName ? pulseRed.distConfidence    : pulseBlue.distConfidence
    property int    transPulse:         devName === pulseRed.devName ? pulseRed.transPulse        : pulseBlue.transPulse
    property int    transFreq:          devName === pulseRed.devName ? pulseRed.transFreq         : pulseBlue.transFreq
    property int    transBoost:         devName === pulseRed.devName ? pulseRed.transBoost        : pulseBlue.transBoost
    property int    dspHorSmooth:       devName === pulseRed.devName ? pulseRed.dspHorSmooth      : pulseBlue.dspHorSmooth
    property int    soundSpeed:         devName === pulseRed.devName ? pulseRed.soundSpeed        : pulseBlue.soundSpeed
    property int    ch1Period:          devName === pulseRed.devName ? pulseRed.ch1Period         : pulseBlue.ch1Period
    property int    datasetChart:       devName === pulseRed.devName ? pulseRed.datasetChart      : pulseBlue.datasetChart
    property int    datasetDist:        devName === pulseRed.devName ? pulseRed.datasetDist       : pulseBlue.datasetDist
    property int    datasetSDDBT:       devName === pulseRed.devName ? pulseRed.datasetSDDBT      : pulseBlue.datasetSDDBT
    property int    datasetEuler:       devName === pulseRed.devName ? pulseRed.datasetEuler      : pulseBlue.datasetEuler
    property int    datasetTemp:        devName === pulseRed.devName ? pulseRed.datasetTemp       : pulseBlue.datasetTemp
    property int    datasetTimestamp:   devName === pulseRed.devName ? pulseRed.datasetTimestamp  : pulseBlue.datasetTimestamp
    property int    transFreqWide:      devName === pulseRed.devName ? pulseRed.transFreqWide     : pulseBlue.transFreqWide
    property int    transFreqNarrow:    devName === pulseRed.devName ? pulseRed.transFreqNarrow   : pulseBlue.transFreqNarrow
    property int    maximumDepth:       devName === pulseRed.devName ? pulseRed.maximumDepth      : pulseBlue.maximumDepth
    property bool   processBottomTrack: devName === pulseRed.devName ? pulseRed.processBottomTrack: pulseBlue.processBottomTrack
    property var    distProcessing:     devName === pulseRed.devName ? distProcPulseRed           : distProcPulseBlue

    property var pulseRed: {
        "devName":              "ECHO20",
        "settingVersion":       1,
        "is2DTransducer":       true,
        "useTemperature":       false,
        "chartResolution":      30,
        "chartSamples":         500,
        "chartOffset":          0,
        "distMax":              50000,
        "distDeadZone":         0,
        "distConfidence":       14,
        "transPulse":           10,
        "transFreq":            810,
        "transBoost":           0,
        "dspHorSmooth":         0,
        "soundSpeed":           1480*1000,
        "ch1Period":            50,
        "datasetChart":         1,
        "datasetDist":          0,
        "datasetSDDBT":         1,
        "datasetEuler":         0,
        "datasetTemp":          0,
        "datasetTimestamp":     0,
        "transFreqWide":        510,
        "transFreqNarrow":      810,
        "maximumDepth":         45,
        "processBottomTrack":   false
    }

    property var pulseBlue: {
        "devName":              "NanoSSS",
        "settingVersion":       1,
        "is2DTransducer":       false,
        "useTemperature":       false,
        "chartResolution":      30,
        "chartSamples":         1358,
        "chartOffset":          25,
        "distMax":              50000,
        "distDeadZone":         0,
        "distConfidence":       14,
        "transPulse":           10,
        "transFreq":            540,
        "transBoost":           1,
        "dspHorSmooth":         0,
        "soundSpeed":           1480*1000,
        "ch1Period":            50,
        "datasetChart":         1,
        "datasetDist":          0,
        "datasetSDDBT":         1,
        "datasetEuler":         0,
        "datasetTemp":          0,
        "datasetTimestamp":     0,
        "transFreqWide":        540,
        "transFreqNarrow":      540,
        "maximumDepth":         21,
        "processBottomTrack":   false
    }

    //PER DEVICE DISTANCE PROCESSING
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
    property var    distProcPulseRed: [
        0,
        1,
        0,
        0,
        0.1,
        0.02,
        0.0,
        0,
        0,
        0
    ]

    property var    distProcPulseBlue: [
        2,
        1,
        0,
        0,
        0.1,
        0.02,
        0.0,
        0,
        0,
        0
    ]

}


