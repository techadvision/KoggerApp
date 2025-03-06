import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs 1.2
import Qt.labs.settings 1.1
import org.techadvision.settings 1.0
import org.techadvision.runtime 1.0

ColumnLayout {
    id: columnItem
    spacing: 0
    Layout.margins: 0
    property var dev: null
    /*
      State: Device is unknown

      */
    property bool settingsNotNull: false
    property bool settingsCompleted: false
    property bool deviceIdentified: false
    property bool deviceSelected: false
    property bool persistentSettingsChecked: false
    property string transducerName: "not_determined"
    property bool shouldLookForDevice: false
    property bool dataUpdateDidChange: false
    property var lostConnectionAlert: null
    property bool showLostConnection: false
    //TODO: reduce delayTimerRepeat to 200 ms when we have SSS transducer with a unique value and not ECHO20
    property int delayTimerRepeat: 200

    signal transducerDetected(string transducer)

    onDeviceIdentifiedChanged: {
        console.log("TAV: received a onDeviceIdentifiedChanged");
    }

    onTransducerDetected: {
        console.log("TAV: onTransducerDetected");
        //columnItem.transducerName = name
        //console.log("TAV: model was set:", model.toString());
    }

    function detectTransducer(name) {
        // Trigger the signal when a transducer is detected
        console.log("TAV: function detectTransducer requested with value:", name);
        columnItem.transducerName = name
        columnItem.transducerDetected(name)
    }

    function setTransducerFrequency (frequency) {
        if (dev !== null) {
            dev.transFreq = frequency
        }
    }

    function setPlotGeneral() {
        // Default values for all Pulse devices
        console.log("TAV: setPlotGeneral - start");
        targetPlot.plotEchogramVisible(true)
        targetPlot.plotRangefinderVisible(false)
        targetPlot.plotGNSSVisible(false, 1)
        targetPlot.plotGridVerticalNumber(5)
        targetPlot.plotGridFillWidth(false)
        targetPlot.plotAngleVisibility(false)
        targetPlot.plotVelocityVisible(false)
        targetPlot.plotDistanceAutoRange(0)

        // Bottom BottomTrack
        targetPlot.setPreset(0)

        console.log("TAV: setPlotGeneral - done");
    }

    function setPlotPulseRed () {
        // Device depentent values for PulseRed
        console.log("TAV: setPlotPulseRed - start");

        // General plot
        targetPlot.plotEchogramCompensation(0)
        targetPlot.plotDatasetChannel(32767, 32768)
        core.setSideScanChannels(32767, 32768)

        // Bottom tracking
        if (pulseRuntimeSettings.processBottomTrack) {
            doBottomTracking()
        }


        console.log("TAV: setPlotPulseRed - done");
    }

    function setPlotPulseBlue () {
        // Device depentent values for PulseBlue
        console.log("TAV: setPlotPulseBlue - start");

        // General plot
        targetPlot.plotEchogramCompensation(1)
        targetPlot.plotDatasetChannel(32767, 1)
        core.setSideScanChannels(32767, 1)

        // Bottom tracking
        if (pulseRuntimeSettings.processBottomTrack) {
            doBottomTracking()
        }


        console.log("TAV: setPlotPulseBlue - done");
    }

    function doBottomTracking () {
        console.log("TAV: doBottomTracking - start");
        targetPlot.plotBottomTrackVisible(true)
        targetPlot.plotRangefinderTheme(0)
        console.log("TAV: doBottomTracking - distanceParams", pulseRuntimeSettings.distProcessing);
        //targetPlot.refreshDistParams(pulseRuntimeSettings.distProcessing)
        targetPlot.refreshDistParams(
            pulseRuntimeSettings.distProcessing[0],
            pulseRuntimeSettings.distProcessing[1],
            pulseRuntimeSettings.distProcessing[2],
            pulseRuntimeSettings.distProcessing[3],
            pulseRuntimeSettings.distProcessing[4],
            pulseRuntimeSettings.distProcessing[5],
            pulseRuntimeSettings.distProcessing[6],
            pulseRuntimeSettings.distProcessing[7],
            pulseRuntimeSettings.distProcessing[8],
            pulseRuntimeSettings.distProcessing[9]
        )
        targetPlot.doDistProcessing(
            pulseRuntimeSettings.distProcessing[0],
            pulseRuntimeSettings.distProcessing[1],
            pulseRuntimeSettings.distProcessing[2],
            pulseRuntimeSettings.distProcessing[3],
            pulseRuntimeSettings.distProcessing[4],
            pulseRuntimeSettings.distProcessing[5],
            pulseRuntimeSettings.distProcessing[6],
            pulseRuntimeSettings.distProcessing[7],
            pulseRuntimeSettings.distProcessing[8],
            pulseRuntimeSettings.distProcessing[9]
        )
        console.log("TAV: doBottomTracking - done");
    }



    function configurePulseDevice () {
        // Function sets device values to match user's device, determined by the pulseRuntimeSettings.devName

        console.log("TAV: pulseRuntimeSettings, plot specific, for", pulseRuntimeSettings.devName);

        if (pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseRed) {
            setPlotPulseRed()
        } else {
            setPlotPulseBlue()
        }

        console.log("TAV: pulseRuntimeSettings - for", pulseRuntimeSettings.devName);

        // ECHOGRAM
        dev.chartResolution = pulseRuntimeSettings.chartResolution
        dev.chartSamples    = pulseRuntimeSettings.chartSamples
        dev.chartOffset     = pulseRuntimeSettings.chartOffset

        // RANGEFINDER
        dev.distMax         = pulseRuntimeSettings.distMax
        dev.distDeadZone    = pulseRuntimeSettings.distDeadZone
        dev.distConfidence  = pulseRuntimeSettings.distConfidence

        // TRANSDUCER
        dev.transPulse      = pulseRuntimeSettings.transPulse
        dev.transFreq       = pulseRuntimeSettings.transFreq
        dev.transBoost      = pulseRuntimeSettings.transBoost

        // DSP
        dev.dspHorSmooth    = pulseRuntimeSettings.dspHorSmooth
        dev.soundSpeed      = pulseRuntimeSettings.soundSpeed

        // DATASET
        dev.ch1Period       = pulseRuntimeSettings.ch1Period
        dev.datasetChart    = pulseRuntimeSettings.datasetChart
        dev.setDatasetDist  = pulseRuntimeSettings.datasetDist
        dev.datasetSDDBT    = pulseRuntimeSettings.datasetSDDBT
        dev.datasetEuler    = pulseRuntimeSettings.datasetEuler
        dev.datasetTemp     = pulseRuntimeSettings.datasetTemp
        dev.datasetTimestamp= pulseRuntimeSettings.datasetTimestamp

        pulseRuntimeSettings.devIdentified = true

        console.log("TAV: pulseSettings - done");
    }


    Connections {
        target: pulseRuntimeSettings
        //Manual selection in the user interface will trigger this.
        //We will need to be able to for browsing a KLF with proper UI when no device is connected
        /*
        function onDevManualSelectedChanged() {
            if (pulseRuntimeSettings.devManualSelected && dev.devName === "...") {
                delayTimer.stop()
                //dev.setDevName(pulseRuntimeSettings.devName)
                PulseSettings.devName = pulseRuntimeSettings.devName
                configurePulseDevice()
                pulseRuntimeSettings.devIdentified = false //???
                console.log("TAV: deviceItem onDevManualSelectedChanged true, model", echoSounderSelector.selectedDevice);
            } else {
                console.log("TAV: deviceItem onDevManualSelectedChanged false, skip");
            }
        }
        */
        //Update the runtime value
        function onTransFreqChanged() {
            dev.transFreq = pulseRuntimeSettings.transFreq
            console.log("TAV: onTransFreqChanged new frequency is", pulseRuntimeSettings.transFreq);
        }
        //DevDriver sets the pulseRuntimeSettings.devName, triggering this alert. Name will be "..." for no device or real device name
        function onDevNameChanged() {
            console.log("TAV: onDevNameChanged to:", pulseRuntimeSettings.devName);
            PulseSettings.devname = pulseRuntimeSettings.devName
            if (pulseRuntimeSettings.devName === "...") {
                pulseRuntimeSettings.devIdentified = false
                pulseRuntimeSettings.isReceivingData = false
                //deviceIdentified = false
            } else {
                //deviceIdentified = true
                pulseRuntimeSettings.devIdentified = true
                pulseRuntimeSettings.isReceivingData = true
                pulseRuntimeSettings.didEverReceiveData = true
            }
            if (pulseRuntimeSettings.hasDeviceLostConnection) {
                if (pulseRuntimeSettings.devName !== "...") {
                    if (pulseRuntimeSettings.didEverReceiveData) {
                        //dataUpdateDidChange = true
                        pulseRuntimeSettings.isReceivingData = true
                        pulseRuntimeSettings.hasDeviceLostConnection = false
                        console.log("TAV: device is present, observed onTimelinePositionChanged reconnection");
                    }
                    if (!pulseRuntimeSettings.didEverReceiveData) {
                        //dataUpdateDidChange = true
                        pulseRuntimeSettings.isReceivingData = true
                        pulseRuntimeSettings.didEverReceiveData = true
                        pulseRuntimeSettings.hasDeviceLostConnection = false
                        console.log("TAV: device is present, observed onTimelinePositionChanged");
                    }
                } else {
                    console.log("TAV: new device name is ..., cannot assume we regained connection");
                }


            }
        }
    }

    // Connections to detect the live data feed is still alive

    Connections {
        target: dataset
        //Dataupdate is triggered by receiving data from transducer, but will also be triggered by loading a KLF file
        //Data update restarts the lostConnectionTimer to avoid it being triggered
        function onDataUpdate () {
            lostConnectionTimer.restart();
        }
    }


    // Timer to detect connection loss, this is shown in main
    Timer {
        id: lostConnectionTimer
        interval: 500  // 0.5 seconds
        repeat: false
        running: false
        onTriggered: {
            if (pulseRuntimeSettings.didEverReceiveData) {
                if (pulseRuntimeSettings.devName !== "...") {
                    pulseRuntimeSettings.isReceivingData = false;
                    pulseRuntimeSettings.hasDeviceLostConnection = true
                    dataUpdateDidChange = false
                    console.log("TAV: lost connection will be triggered for device", pulseRuntimeSettings.devName);
                } else {
                    console.log("TAV: We do not loose connection for an unknown device", pulseRuntimeSettings.devNam);
                }
            } else {
                console.log("TAV: We do not loose connection when we never received any data");
            }
        }
    }


    Timer {
        //Delay timer was created when we could not reliably expect the device name to be delivered
        //With a predictable solution where DevDriver sets PulseRuntimeSetting.devName we should no longer need this
        //To be altered to a new solution:
        //Initial blockers makes sense, as do the two booleans
        id: delayTimer
        interval: delayTimerRepeat
        repeat: !settingsCompleted || !deviceIdentified
        onTriggered: {

            /* -- PULSE: DEFAULT SETTINGS AT STARTUP -- */
            if (settingsCompleted && deviceIdentified) {
                console.log("TAV: delaytimer, settingsCompleted && deviceIdentified, all done!");
                return
            }

            if (PulseSettings === null || pulseRuntimeSettings === null) {
                console.log("TAV: delayTimer, settings === null, not ready to proceed");
                return
            }

            if (dev === null && pulseRuntimeSettings.userManualSetName === "...") {
                console.log("TAV: delayTimer, dev === null, not ready to proceed");
                return
            }

            if (!settingsCompleted || !deviceIdentified) {
                if (false) {
                    //Automatically selected
                    if (pulseRuntimeSettings.devIdentified && !pulseRuntimeSettings.devConfigured) {
                        deviceIdentified = true
                        settingsCompleted = true
                        pulseRuntimeSettings.devConfigured = true
                        pulseRuntimeSettings.devName = pulseRuntimeSettings.devName
                        dev.devName === pulseRuntimeSettings.devName
                        console.log("TAV: delayTimer, device automatically detected");
                        configurePulseDevice()
                        pulseRuntimeSettings.appConfigured = true
                        //return
                    }
                }

                //Manually selected
                if (pulseRuntimeSettings.devManualSelected && !deviceSelected) {
                //if (!pulseRuntimeSettings.devIdentified && pulseRuntimeSettings.devManualSelected && !deviceSelected) {
                    deviceSelected = true
                    /*
                      TODO: The below to be removed (deviceIdentified = true) when we have proper names for the SSS transducer
                    */
                    deviceIdentified = true
                    // TODO: Remove the above later!!!
                    dev.devName === pulseRuntimeSettings.devName
                    //delayTimerRepeat = 5000
                    console.log("TAV: delayTimer, was manually selected, will still try to look for the real device at every ms", delayTimerRepeat);
                    configurePulseDevice()
                    pulseRuntimeSettings.appConfigured = true
                    //return
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("TAV deviceItem onCompleted");
        setPlotGeneral()
        delayTimer.start()
    }

    ParamGroup {
        groupName: "Echogram"

        ParamSetup {
            paramName: "Resolution, mm"

            SpinBoxCustom {
                from: 10
                to: 100
                stepSize: 10
                value: 0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.chartResolution : 0
                //devValue: dev !== null ? dev.chartResolution : 0
                isValid: dev !== null ? dev.chartSetupState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        pulseRuntimeSettings.chartResolution = value
                        dev.chartResolution = pulseRuntimeSettings.chartResolution
                    }
                    isDriverChanged = false
                }
            }
        }

        ParamSetup {
            paramName: "Number of Samples"

            SpinBoxCustom {
                from: 100
                to: 15000
                stepSize: 100
                value: 0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.chartSamples : 0
                //devValue: dev !== null ? dev.chartSamples : 0
                isValid: dev !== null ? dev.chartSetupState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        pulseRuntimeSettings.chartSamples = value
                        dev.chartSamples = pulseRuntimeSettings.chartSamples
                    }
                    isDriverChanged = false
                }
            }
        }

        ParamSetup {
            paramName: "Offset of Samples"

            SpinBoxCustom {
                from: 0
                to: 10000
                stepSize: 100
                value:0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.chartOffset : 0
                //devValue: dev !== null ? dev.chartOffset : 0
                isValid: dev !== null ? dev.chartSetupState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        pulseRuntimeSettings.chartOffset = value
                        dev.chartOffset = pulseRuntimeSettings.chartOffset
                    }
                    isDriverChanged = false
                }
            }
        }
    }

    ParamGroup {
        groupName: "Rangefinder"

        ParamSetup {
            paramName: "Max distance, mm"

            SpinBoxCustom {
                from: 0;
                to: 50000;
                stepSize: 1000
                value: 0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.distMax : 0
                //devValue: dev !== null ? dev.distMax : 0
                isValid: dev !== null ? dev.distSetupState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        pulseRuntimeSettings.distMax = value
                        dev.distMax = pulseRuntimeSettings.distMax
                    }
                    isDriverChanged = false
                }
            }
        }

        ParamSetup {
            paramName: "Dead zone, mm"

            SpinBoxCustom {
                from: 0
                to: 50000
                stepSize: 100
                value: 0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.distDeadZone : 0
                //devValue: dev !== null ? dev.distDeadZone : 0
                isValid: dev !== null ? dev.distSetupState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        pulseRuntimeSettings.distDeadZone = value
                        dev.distDeadZone = pulseRuntimeSettings.distDeadZone
                    }
                    isDriverChanged = false
                }
            }
        }

        ParamSetup {
            paramName: "Confidence threshold, %"

            SpinBoxCustom {
                from: 0
                to: 100
                stepSize: 1
                value: 0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.distConfidence : 0
                //devValue: dev !== null ? dev.distConfidence : 0
                isValid: dev !== null ? dev.distSetupState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        pulseRuntimeSettings.distConfidence = value
                        dev.distConfidence = pulseRuntimeSettings.distConfidence
                    }
                    isDriverChanged = false
                }
            }
        }
    }

    ParamGroup {
        groupName: "Transducer"

        ParamSetup {
            paramName: "Pulse count"

            SpinBoxCustom {
                from: 0
                to: 5000
                stepSize: 1
                value: 0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.transPulse : 0
                //devValue: dev !== null ? dev.transPulse : 0
                isValid: dev !== null ? dev.transcState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        pulseRuntimeSettings.transPulse = value
                        dev.transPulse = pulseRuntimeSettings.transPulse
                    }
                    isDriverChanged = false
                }
            }
        }

        ParamSetup {
            paramName: "Frequency, kHz"

            SpinBoxCustom {
                from: 40
                to: 6000
                stepSize: 5
                value: 0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.transFreq : 0
                //devValue: dev !== null ? dev.transFreq : 0
                isValid: dev !== null ? dev.transcState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        pulseRuntimeSettings.transFreq = value
                        dev.transFreq = pulseRuntimeSettings.transFreq
                    }
                    isDriverChanged = false
                }
            }
        }

        ParamSetup {
            paramName: "Booster"

            SpinBoxCustom {
                from: 0
                to: 1
                stepSize: 1
                value: 0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.transBoost : 0
                //devValue: dev !== null ? dev.transBoost : 0
                isValid: dev !== null ? dev.transcState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        pulseRuntimeSettings.transBoost = value
                        dev.transBoost = pulseRuntimeSettings.transBoost
                    }
                    isDriverChanged = false
                }

                property var items: ["Off", "On"]

                validator: RegExpValidator {
                    regExp: new RegExp("(Off|On)", "i")
                }

                textFromValue: function(value) {
                    return items[value];
                }

                valueFromText: function(text) {
                    for (var i = 0; i < items.length; ++i) {
                        if (items[i].toLowerCase().indexOf(text.toLowerCase()) === 0)
                            return i
                    }
                    return sb.value
                }
            }
        }
    }

    ParamGroup {
        groupName: "DSP"

        ParamSetup {
            paramName: "Horizontal smoothing factor"

            SpinBoxCustom {
                from: 0
                to: 4
                stepSize: 1
                value: 0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.dspHorSmooth : 0
                //devValue: dev !== null ? dev.dspHorSmooth : 0
                isValid: dev !== null ? dev.dspState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        pulseRuntimeSettings.dspHorSmooth = value
                        dev.dspHorSmooth = pulseRuntimeSettings.dspHorSmooth
                    }
                    isDriverChanged = false
                }
            }
        }

        ParamSetup {
            paramName: "Speed of Sound, m/s"

            SpinBoxCustom {
                from: 300
                to: 6000
                stepSize: 5
                value: 0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.soundSpeed / 1000 : 0
                //devValue: dev !== null ? dev.soundSpeed / 1000 : 0
                isValid: dev !== null ? dev.soundState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        pulseRuntimeSettings.soundSpeed = value * 1000
                        dev.soundSpeed = pulseRuntimeSettings.soundSpeed
                    }
                    isDriverChanged = false
                }
            }
        }
    }

    ParamGroup {
        groupName: "Dataset"

        ParamSetup {
            paramName: "Period, ms"

            SpinBoxCustom {
                from: 0
                to: 2000
                stepSize: 50
                value: 0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.ch1Period : 0
                //devValue: dev !== null ? dev.ch1Period : 0
                isValid: dev !== null ? dev.datasetState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        pulseRuntimeSettings.ch1Period = value
                        dev.ch1Period = pulseRuntimeSettings.ch1Period
                    }
                    isDriverChanged = false
                }
            }
        }

        ParamSetup {
            paramName: "Echogram"

            SpinBoxCustom {
                from: 0
                to: 1
                stepSize: 1
                value: 0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.datasetChart : 0
                //devValue: dev !== null ? dev.datasetChart === 1 : 0
                isValid: dev !== null ? dev.datasetState : false
                editable: false

                onValueChanged: {
                    if (!isDriverChanged) {
                        if (value == 1) {
                            pulseRuntimeSettings.datasetChart = 1
                        } else {
                            pulseRuntimeSettings.datasetChart = 0
                        }
                        dev.datasetChart = pulseRuntimeSettings.datasetChart
                    }
                    isDriverChanged = false
                }

                property var items: ["Off", "8-bit", "16-bit"]
                textFromValue: function(value) {
                    return items[value];
                }
            }
        }

        ParamSetup {
            paramName: "Rangefinder"

            SpinBoxCustom {
                from: 0
                to: 2
                stepSize: 1
                value: 0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? (pulseRuntimeSettings.datasetDist === 1 ? 1 : pulseRuntimeSettings.datasetSDDBT === 1 ? 2 : 0) : 0
                //devValue: dev !== null ? (dev.datasetDist === 1 ? 1 : dev.datasetSDDBT === 1 ? 2 : 0) : 0
                isValid: dev !== null ? dev.datasetState : false
                editable: false

                onValueChanged: {
                    if (!isDriverChanged) {
                        if (value == 1) {
                            pulseRuntimeSettings.datasetDist = 1
                            dev.datasetDist = pulseRuntimeSettings.datasetDist
                        }
                        else if (value == 2) {
                            pulseRuntimeSettings.datasetSDDBT = 1
                            dev.datasetSDDBT = pulseRuntimeSettings.datasetSDDBT
                        }
                        else {
                            pulseRuntimeSettings.datasetDist = 0
                            dev.datasetDist = pulseRuntimeSettings.datasetDist
                            pulseRuntimeSettings.datasetSDDBT = 0
                            dev.datasetSDDBT = pulseRuntimeSettings.datasetSDDBT
                        }
                    }
                    isDriverChanged = false
                }

                property var items: ["Off", "On", "NMEA"]
                textFromValue: function(value) {
                    return items[value];
                }
            }
        }

        ParamSetup {
            paramName: "AHRS"

            SpinBoxCustom {
                from: 0
                to: 1
                stepSize: 1
                editable: false
                value: 0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.datasetEuler : 0
                //devValue: dev !== null ? ((dev.datasetEuler & 1) === 1) : 0
                isValid: dev !== null ? dev.datasetState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        if (value == 1) {
                            pulseRuntimeSettings.datasetEuler = 1
                            dev.datasetEuler = pulseRuntimeSettings.datasetEuler
                        }
                        else if (dev.datasetEuler & 1) {
                            pulseRuntimeSettings.datasetEuler = 0
                            dev.datasetEuler = pulseRuntimeSettings.datasetEuler
                        }
                    }
                    isDriverChanged = false
                }

                property var items: ["Off", "Euler", "Quat."]
                textFromValue: function(value) {
                    return items[value];
                }
            }
        }

        ParamSetup {
            paramName: "Temperature"

            SpinBoxCustom {
                from: 0
                to: 1
                stepSize: 1
                value: 0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.datasetTemp : 0
                //devValue: dev !== null ? ((dev.datasetTemp & 1) === 1) : 0
                isValid: dev !== null ? dev.datasetState : false
                editable: false

                onValueChanged: {
                    if (!isDriverChanged) {
                        if(value == 1) {
                            pulseRuntimeSettings.datasetTemp = 1
                        } else if (dev.datasetTemp & 1) {
                            pulseRuntimeSettings.datasetTemp = 0
                        }
                        dev.datasetTemp = pulseRuntimeSettings.datasetTemp
                    }
                    isDriverChanged = false
                }

                property var items: ["Off", "On"]
                textFromValue: function(value) {
                    return items[value];
                }
            }
        }

        ParamSetup {
            paramName: "Timestamp"

            SpinBoxCustom {
                from: 0
                to: 1
                stepSize: 1
                value: 0
                devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.datasetTimestamp : 0
                //devValue: dev !== null ? ((dev.datasetTimestamp & 1) === 1) : 0
                isValid: dev !== null ? dev.datasetState : false
                editable: false

                onValueChanged: {
                    if (!isDriverChanged) {
                        if (value == 1) {
                            pulseRuntimeSettings.datasetTimestamp = 1
                        } else if (dev.datasetTimestamp & 1) {
                            pulseRuntimeSettings.datasetTimestamp = 0
                        }
                        dev.datasetTimestamp = pulseRuntimeSettings.datasetTimestamp
                    }
                    isDriverChanged = false
                }

                property var items: ["Off", "On"]
                textFromValue: function(value) {
                    return items[value];
                }
            }
        }
    }
}
