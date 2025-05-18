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

    property var myDev: null
    property var devList: deviceManagerWrapper.devs
    property bool dynResolutionUpdated: false
    property int deviceParameterSetterRepeat: 2000

    Connections {
        target: dev

        function onDeviceVersionChanged () {
            if (dev === null) {
                //console.log("DEV_PARAM onDeviceVersionChanged, but dev was null. Aborting.")
                return
            }
            if (dev.devName === null) {
                //console.log("DEV_PARAM onDeviceVersionChanged, but devName was null. Aborting.")
                return
            }

            if (dev.devName === "..." && !pulseRuntimeSettings.devConfigured) {
                //console.log("DEV_PARAM onDeviceVersionChanged, but devName was ", dev.devName, ". Aborting.")
                return
            }

            if (dev.devName === "..." && pulseRuntimeSettings.devConfigured) {
                //console.log("DEV_PARAM onDeviceVersionChanged, devName ... but device was already configured. Must have lost connection. Reset state")
                resetAllSetupStates()
                pulseRuntimeSettings.onDeviceVersionChanged = false;
                return
            }
            if (pulseRuntimeSettings.onDeviceVersionChanged) {
                //console.log("DEV_PARAM onDeviceVersionChanged, but device already configured for devName ", dev.devName, ". Aborting.")
                return
            }

            pulseRuntimeSettings.onDeviceVersionChanged = true
            //console.log("DEV_PARAM onDeviceVersionChanged, devName is ", dev.devName, ". Finally.")
            myDev = dev
        }

        function onDistSetupChanged () {
            if (pulseRuntimeSettings.userManualSetName === "...")
                return
            //console.log("DEV_PARAM onDistSetupChanged event received, configuring setup for ", pulseRuntimeSettings.userManualSetName)
            distSetup ()
        }

        function onChartSetupChanged () {
            if (pulseRuntimeSettings.userManualSetName === "...")
                return
            //console.log("DEV_PARAM onChartSetupChanged event received, configuring setup for ", pulseRuntimeSettings.userManualSetName)
            chartSetup()
        }

        function onDatasetChanged () {
            if (pulseRuntimeSettings.userManualSetName === "...")
                return
            //console.log("DEV_PARAM onDatasetChanged event received, configuring setup for ", pulseRuntimeSettings.userManualSetName)
            datasetSetup()
        }

        function onTransChanged () {
            if (pulseRuntimeSettings.userManualSetName === "...")
                return
            //console.log("DEV_PARAM onTransChanged event received, configuring setup for ", pulseRuntimeSettings.userManualSetName)
            transSetup()
        }

        function onDspSetupChanged () {
            if (pulseRuntimeSettings.userManualSetName === "...")
                return
            //console.log("DEV_PARAM onDspSetupChanged event received, configuring setup for ", pulseRuntimeSettings.userManualSetName)
            dspSetup()
        }

        function onSoundChanged () {
            if (pulseRuntimeSettings.userManualSetName === "...")
                return
            //console.log("DEV_PARAM onSoundChanged event received, configuring setup for ", pulseRuntimeSettings.userManualSetName)
            soundSetup()
        }
    }

    onDevListChanged: {
        if (devList.length > 0) {
            myDev = devList[0]
            //myDev = devList[ devList.length - 1 ]
            if (myDev !== null) {
                //console.log("DEV_PARAM: onDevListChanged")
                //console.log("DEV_PARAM: onDevListChanged - myDev.devName = ", myDev.devName)
                //console.log("DEV_PARAM: onDevListChanged - dev === null?", dev === null)
                if (dev !== null) {
                  //console.log("DEV_PARAM: onDevListChanged - dev.devName = ", dev.devName)
                }
            }
        } else {
            //console.log("DEV_PARAM: onDevListChanged when list length is 0")
        }
    }

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
    property int delayTimerRepeat: 2000

    signal transducerDetected(string transducer)



    ParamGroup {
        groupName: qsTr("Echogram")

        ParamSetup {
            paramName: qsTr("Resolution, mm")

            SpinBoxCustom {
                from: 10
                to: 100
                stepSize: 10
                value: 0
                devValue: {
                    if (dev !== null && pulseRuntimeSettings !== null) {
                        if (pulseRuntimeSettings.doDynamicResolution) {
                            console.log("DEV_CONFIG: chartResolution devValue set to ", pulseRuntimeSettings.dynamicResolution), " by doDynamicResolution";
                            return pulseRuntimeSettings.dynamicResolution
                        } else {
                            console.log("DEV_CONFIG: chartResolution devValue set to ", pulseRuntimeSettings.chartResolution);
                            return pulseRuntimeSettings.chartResolution
                        }
                    } else {
                        return 0
                    }
                }
                //(dev !== null && pulseRuntimeSettings !== null) ? (pulseRuntimeSettings.doDynamicResolution ? pulseRuntimeSettings.dynamicResolution : pulseRuntimeSettings.chartResolution) = 0
                //devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.chartResolution : 0
                //devValue: dev !== null ? dev.chartResolution : 0
                isValid: dev !== null ? dev.chartSetupState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        pulseRuntimeSettings.chartResolution = value
                        //dev.chartResolution = pulseRuntimeSettings.chartResolution
                        console.log("DEV_CONFIG: chartResolution onValueChanged, set pulseRuntimeSettings.chartResolution to ", value);
                        //dev.chartResolution = pulseRuntimeSettings.chartResolution
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onChartResolutionChanged () {
                        console.log("DEV_CONFIG: onChartResolutionChanged")
                        if (dev !== null) {
                            if (dev.chartResolution !== pulseRuntimeSettings.chartResolution) {
                                dev.chartResolution = pulseRuntimeSettings.chartResolution
                                console.log("DEV_CONFIG: dev.chartResolution set to pulseRuntimeSettings.chartResolution")
                            } else {
                                console.log("DEV_CONFIG: dev.chartResolution ", dev.chartResolution, " already equal to ", pulseRuntimeSettings.chartResolution)
                            }
                        } else {
                            console.log("DEV_CONFIG: onChartResolutionChanged dev is null")
                        }
                    }

                    function onDynamicResolutionChanged () {
                        console.log("DEV_CONFIG: onChartResolutionChanged")
                        if (pulseRuntimeSettings.doDynamicResolution) {
                            if (pulseRuntimeSettings.chartResolution !== pulseRuntimeSettings.dynamicResolution) {
                                pulseRuntimeSettings.chartResolution = pulseRuntimeSettings.dynamicResolution
                            } else {
                                console.log("DEV_CONFIG: pulseRuntimeSettings.chartResolution already equal to pulseRuntimeSettings.dynamicResolution")
                            }
                        } else {
                            console.log("pulseRuntimeSettings.doDynamicResolution false")
                        }
                    }
                }

                Timer {
                    id: setChartResolutionTimer
                    repeat: !columnItem.dynResolutionUpdated
                    interval: 200
                    onTriggered: {
                        console.log("DEV_CONFIG: resolution setChartResolutionTimer")
                        if (dev !== null) {
                            if (dev.devName !== "...") {
                                if (!columnItem.dynResolutionUpdated) {
                                    pulseRuntimeSettings.chartResolution = pulseRuntimeSettings.dynamicResolution
                                    dev.chartResolution = pulseRuntimeSettings.dynamicResolution
                                    columnItem.dynResolutionUpdated = true
                                    console.log("DEV_CONFIG: resolution timer: dev.chartResolution = ",dev.chartResolution, " pulseRuntimeSettings.chartResolution ", pulseRuntimeSettings.chartResolution, " pulseRuntimeSettings.dynamicResolution = ", pulseRuntimeSettings.dynamicResolution);
                                } else {
                                    console.log("DEV_CONFIG: resolution timer, columnItem.dynResolutionUpdated is already true")
                                }
                            } else {
                                console.log("DEV_CONFIG: resolution timer, dev.devName === ...")
                            }
                        } else {
                            console.log("DEV_CONFIG: resolution timer, dev === null")
                        }
                    }

                }
            }
        }

        ParamSetup {
            paramName: qsTr("Number of Samples")

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
                        //dev.chartSamples = pulseRuntimeSettings.chartSamples
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onChartSamplesChanged () {
                        dev.chartSamples = pulseRuntimeSettings.chartSamples
                        //console.log("DEV_CONFIG: Set the dev.chartSamples to ", dev.chartSamples, " using source pulseRuntimeSettings.chartSamples of ", pulseRuntimeSettings.chartSamples)
                    }
                }
            }
        }

        ParamSetup {
            paramName: qsTr("Offset of Samples")

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
                        //dev.chartOffset = pulseRuntimeSettings.chartOffset
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onChartOffsetChanged () {
                        dev.chartOffset = pulseRuntimeSettings.chartOffset
                        //console.log("DEV_CONFIG: Set the dev.chartOffset to ", dev.chartOffset, " using source pulseRuntimeSettings.chartOffset of ", pulseRuntimeSettings.chartOffset)
                    }
                }
            }
        }
    }

    ParamGroup {
        groupName: qsTr("Rangefinder")

        ParamSetup {
            paramName: qsTr("Max distance, mm")

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
                        //dev.distMax = pulseRuntimeSettings.distMax
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onDistMaxChanged () {
                        dev.distMax = pulseRuntimeSettings.distMax
                        //console.log("DEV_CONFIG: Set the dev.distMax to ", dev.distMax, " using source pulseRuntimeSettings.distMax of ", pulseRuntimeSettings.distMax)
                    }
                }
            }
        }

        ParamSetup {
            paramName: qsTr("Dead zone, mm")

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
                        //dev.distDeadZone = pulseRuntimeSettings.distDeadZone
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onDistDeadZoneChanged () {
                        dev.distDeadZone = pulseRuntimeSettings.distDeadZone
                        //console.log("DEV_CONFIG: Set the dev.distDeadZone to ", dev.distDeadZone, " using source pulseRuntimeSettings.distDeadZone of ", pulseRuntimeSettings.distDeadZone)
                    }
                }
            }
        }

        ParamSetup {
            paramName: qsTr("Confidence threshold, %")

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
                        //dev.distConfidence = pulseRuntimeSettings.distConfidence
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onDistConfidenceChanged () {
                        dev.distConfidence = pulseRuntimeSettings.distConfidence
                        //console.log("DEV_CONFIG: Set the dev.distConfidence to ", dev.distConfidence, " using source pulseRuntimeSettings.distConfidence of ", pulseRuntimeSettings.distConfidence)
                    }
                }
            }
        }
    }

    ParamGroup {
        groupName: qsTr("Transducer")

        ParamSetup {
            paramName: qsTr("Pulse count")

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
                        //dev.transPulse = pulseRuntimeSettings.transPulse
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onTransPulseChanged () {
                        dev.transPulse = pulseRuntimeSettings.transPulse
                        //console.log("DEV_CONFIG: Set the dev.transPulse to ", dev.transPulse, " using source pulseRuntimeSettings.transPulse of ", pulseRuntimeSettings.transPulse)
                    }
                }
            }
        }

        ParamSetup {
            paramName: qsTr("Frequency, kHz")

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
                        //dev.transFreq = pulseRuntimeSettings.transFreq
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onTransFreqChanged () {
                        dev.transFreq = pulseRuntimeSettings.transFreq
                        //console.log("DEV_CONFIG: Set the dev.transFreq to ", dev.transFreq, " using source pulseRuntimeSettings.transFreq of ", pulseRuntimeSettings.transFreq)
                    }
                }
            }
        }

        ParamSetup {
            paramName: qsTr("Booster")

            SpinBoxCustom {
                id: spinBoxBooster

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
                        //dev.transBoost = pulseRuntimeSettings.transBoost
                    }
                    isDriverChanged = false
                }

                property var items: [qsTr("Off"), qsTr("On")]
                property string regExpPattern: "(" + items.join("|") + ")"

                validator: RegExpValidator {
                    regExp: new RegExp(spinBoxBooster ? spinBoxBooster.regExpPattern : "(Off|On)", "i")
                }

                textFromValue: function(value) {
                    return items[value];
                }

                valueFromText: function(text) {
                    for (var i = 0; i < items.length; ++i) {
                        if (items[i].toLowerCase().indexOf(text.toLowerCase()) === 0) {
                            return i
                        }
                    }
                    return spinBoxBooster.value
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onTransBoostChanged () {
                        dev.transBoost = pulseRuntimeSettings.transBoost
                        //console.log("DEV_CONFIG: Set the dev.transBoost to ", dev.transBoost, " using source pulseRuntimeSettings.transBoost of ", pulseRuntimeSettings.transBoost)
                    }
                }
            }
        }
    }

    ParamGroup {
        groupName: qsTr("DSP")

        ParamSetup {
            paramName: qsTr("Horizontal smoothing factor")

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
                        //dev.dspHorSmooth = pulseRuntimeSettings.dspHorSmooth
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onDspHorSmoothChanged () {
                        dev.dspHorSmooth = pulseRuntimeSettings.dspHorSmooth
                        //console.log("DEV_CONFIG: Set the dev.dspHorSmooth to ", dev.dspHorSmooth, " using source pulseRuntimeSettings.dspHorSmooth of ", pulseRuntimeSettings.dspHorSmooth)
                    }
                }
            }
        }

        ParamSetup {
            paramName: qsTr("Speed of Sound, m/s")

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
                        //dev.soundSpeed = pulseRuntimeSettings.soundSpeed
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onSoundSpeedChanged () {
                        dev.soundSpeed = pulseRuntimeSettings.soundSpeed
                        //console.log("DEV_CONFIG: Set the dev.soundSpeed to ", dev.soundSpeed, " using source pulseRuntimeSettings.soundSpeed of ", pulseRuntimeSettings.soundSpeed)
                    }
                }
            }
        }
    }

    ParamGroup {
        groupName: qsTr("Dataset")

        ParamSetup {
            paramName: qsTr("Period, ms")

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
                        //dev.ch1Period = pulseRuntimeSettings.ch1Period
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onCh1PeriodChanged () {
                        dev.ch1Period = pulseRuntimeSettings.ch1Period
                        //console.log("DEV_CONFIG: Set the dev.ch1Period to ", dev.ch1Period, " using source pulseRuntimeSettings.ch1Period of ", pulseRuntimeSettings.ch1Period)
                    }
                }
            }
        }

        ParamSetup {
            paramName: qsTr("Echogram")

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
                        //dev.datasetChart = pulseRuntimeSettings.datasetChart
                    }
                    isDriverChanged = false
                }

                property var items: [qsTr("Off"), qsTr("8-bit"), qsTr("16-bit")]
                textFromValue: function(value) {
                    return items[value];
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onDatasetChartChanged () {
                        dev.datasetChart = pulseRuntimeSettings.datasetChart
                        //console.log("DEV_CONFIG: Set the dev.datasetChart to ", dev.datasetChart, " using source pulseRuntimeSettings.datasetChart of ", pulseRuntimeSettings.datasetChart)
                    }
                }
            }
        }

        ParamSetup {
            paramName: qsTr("Rangefinder")

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
                        if (value === 1) {
                            pulseRuntimeSettings.currentDepthSolution = 1
                            //pulseRuntimeSettings.datasetDist = 1
                            //pulseRuntimeSettings.datasetSDDBT = 0
                            //dev.datasetDist = pulseRuntimeSettings.datasetDist
                        }
                        else if (value === 2) {
                            pulseRuntimeSettings.currentDepthSolution = 2
                            //pulseRuntimeSettings.datasetDist = 0
                            //pulseRuntimeSettings.datasetSDDBT = 1
                            //dev.datasetSDDBT = pulseRuntimeSettings.datasetSDDBT
                        }
                        else {
                            pulseRuntimeSettings.currentDepthSolution = 0
                            //pulseRuntimeSettings.datasetDist = 0
                            //dev.datasetDist = pulseRuntimeSettings.datasetDist
                            //pulseRuntimeSettings.datasetSDDBT = 0
                            //dev.datasetSDDBT = pulseRuntimeSettings.datasetSDDBT
                        }
                    }
                    isDriverChanged = false
                }

                property var items: [qsTr("Off"), qsTr("On"), qsTr("NMEA")]
                textFromValue: function(value) {
                    return items[value];
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onCurrentDepthSolutionChanged() {
                        let newValue = pulseRuntimeSettings.currentDepthSolution
                        if (newValue === 1) {
                            pulseRuntimeSettings.datasetDist = 1
                            pulseRuntimeSettings.datasetSDDBT = 0
                            dev.datasetDist = pulseRuntimeSettings.datasetDist
                        }
                        else if (newValue === 2) {
                            pulseRuntimeSettings.datasetDist = 0
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
                }
            }
        }

        ParamSetup {
            paramName: qsTr("AHRS")

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
                            //dev.datasetEuler = pulseRuntimeSettings.datasetEuler
                        }
                    }
                    isDriverChanged = false
                }

                property var items: [qsTr("Off"), qsTr("Euler"), qsTr("Quat.")]
                textFromValue: function(value) {
                    return items[value];
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onDatasetEulerChanged () {
                        dev.datasetEuler = pulseRuntimeSettings.datasetEuler
                        //console.log("DEV_CONFIG: Set the dev.datasetEuler to ", dev.datasetEuler, " using source pulseRuntimeSettings.datasetEuler of ", pulseRuntimeSettings.datasetEuler)
                    }
                }
            }
        }

        ParamSetup {
            paramName: qsTr("Temperature")

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
                        //console.log("Dev_value: datasetTemp isDriverChanged, new value ", value)
                        if(value == 1) {
                            pulseRuntimeSettings.datasetTemp = 1
                        } else if (dev.datasetTemp & 1) {
                            pulseRuntimeSettings.datasetTemp = 0
                        }
                        //dev.datasetTemp = pulseRuntimeSettings.datasetTemp
                    }
                    isDriverChanged = false
                    //console.log("Dev_value: datasetTemp = ", dev.datasetTemp)
                }

                property var items: [qsTr("Off"), qsTr("On")]
                textFromValue: function(value) {
                    return items[value];
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onDatasetTempChanged () {
                        dev.datasetTemp = pulseRuntimeSettings.datasetTemp
                        //console.log("DEV_CONFIG: Set the dev.datasetTemp to ", dev.datasetTemp, " using source pulseRuntimeSettings.datasetTemp of ", pulseRuntimeSettings.datasetTemp)
                    }
                }
            }
        }

        ParamSetup {
            paramName: qsTr("Timestamp")

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
                        //dev.datasetTimestamp = pulseRuntimeSettings.datasetTimestamp
                    }
                    isDriverChanged = false
                }

                property var items: [qsTr("Off"), qsTr("On")]
                textFromValue: function(value) {
                    return items[value];
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onDatasetTimestampChanged () {
                        dev.datasetTimestamp = pulseRuntimeSettings.datasetTimestamp
                        //console.log("DEV_CONFIG: Set the dev.datasetTimestamp to ", dev.datasetTimestamp, " using source pulseRuntimeSettings.datasetTimestamp of ", pulseRuntimeSettings.datasetTimestamp)
                    }
                }
            }
        }
    }


    onTransducerDetected: {
        //console.log("TAV: onTransducerDetected");
        //columnItem.transducerName = name
        //console.log("TAV: model was set:", model.toString());
    }

    function detectTransducer(name) {
        // Trigger the signal when a transducer is detected
        //console.log("TAV: function detectTransducer requested with value:", name);
        columnItem.transducerName = name
        columnItem.transducerDetected(name)
    }

    function setTransducerFrequency (frequency) {
        if (dev !== null) {
            dev.transFreq = frequency
        } else {
            //console.log("TAV: FAILED to do dev.transFreq = frequency, dev == null");
        }
    }

    function setPlotGeneral() {
        // Default values for all Pulse devices
        //console.log("TAV: setPlotGeneral - start");
        targetPlot.plotEchogramVisible(pulseRuntimeSettings.echogramVisible)
        targetPlot.plotBottomTrackVisible(pulseRuntimeSettings.bottomTrackVisible)
        targetPlot.plotBottomTrackTheme(pulseRuntimeSettings.bottomTrackVisibleModel)
        targetPlot.plotRangefinderVisible(pulseRuntimeSettings.rangefinderVisible)
        targetPlot.plotGNSSVisible(pulseRuntimeSettings.gnssVisible, 1)
        targetPlot.plotGridVerticalNumber(pulseRuntimeSettings.gridNumber)
        targetPlot.plotGridFillWidth(pulseRuntimeSettings.fillWidthGrid)
        targetPlot.plotAngleVisibility(pulseRuntimeSettings.angleVisible)
        targetPlot.plotVelocityVisible(pulseRuntimeSettings.velocityVisible)

        //console.log("TAV: setPlotGeneral - done");
    }

    function setPlotPulseRed () {
        // Device depentent values for PulseRed
        //console.log("TAV: setPlotPulseRed - start");

        // General plot
        targetPlot.plotEchogramCompensation(0)
        targetPlot.plotDatasetChannel(32767, 32768)
        core.setSideScanChannels(32767, 32768)

        // Bottom tracking
        disableBottomTracking()
        /*
        if (pulseRuntimeSettings.processBottomTrack) {
            doBottomTracking()
        }
        */

        //console.log("TAV: setPlotPulseRed - done");
    }

    function setPlotPulseBlue () {

        // General plot
        targetPlot.plotEchogramCompensation(1)
        targetPlot.plotDatasetChannel(2, 3)
        core.setSideScanChannels(2, 3)

        // Bottom tracking
        disableBottomTracking()
        /*
        if (pulseRuntimeSettings.processBottomTrack) {
            doBottomTracking()
        }
        */

        //console.log("TAV: setPlotPulseBlue - done");
    }

    function disableBottomTracking () {
        targetPlot.refreshDistParams(
            pulseRuntimeSettings.distProcessing[0],
            1,
            0,
            0,
            1000,
            1,
            0,
            0,
            0,
            0
        )
    }

    function doBottomTracking () {
        //console.log("TAV: doBottomTracking - start");
        targetPlot.plotBottomTrackVisible(false)
        targetPlot.plotRangefinderTheme(0)
        //console.log("TAV: doBottomTracking - distanceParams", pulseRuntimeSettings.distProcessing);

        /* This is the right order to set the parameters, order is equal for
          doDistanceProcessing
          0 = preset = static_cast<BottomTrackPreset>(preset);
          1 = windosSize = window_size
          2 = verticalGap = vertical_gap
          3 = minDistance = range_min
          4 = maxDistance = range_max
          5 = gainSlope = gain_slope
          6 = threshold = threshold
          7 = offset.x = offsetx;
          8 = offset.y = offsety;
          9 = offset.z = offsetz;
        */

        // While this will use the actual profile data for distance processing

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

        //console.log("TAV: doBottomTracking - done");
    }


    function configurePulseDevice () {

        //console.log("DEV_CONFIG: pulseRuntimeSettings, plot specific, for", pulseRuntimeSettings.userManualSetName)
        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed
                || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto) {
            setPlotPulseRed()
        } else {
            setPlotPulseBlue()
        }

        //console.log("DEV_CONFIG: pulseRuntimeSettings - cone for", pulseRuntimeSettings.userManualSetName)
        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed
                || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto) {
            if (PulseSettings.ecoConeIndex === 0) {
                pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqWide
                //console.log("TAV: pulse red wide")
            } else {
                pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqNarrow
                //console.log("TAV: pulse red narrow")
            }
        }

        //console.log("DEV_CONFIG: pulseRuntimeSettings - black stripes for", pulseRuntimeSettings.userManualSetName)
        if (core.fixBlackStripesForwardSteps       !== pulseRuntimeSettings.fixBlackStripesForwardSteps) {
            core.fixBlackStripesForwardSteps       = pulseRuntimeSettings.fixBlackStripesForwardSteps
            //console.log("DEV_CONFIG: core.fixBlackStripesForwardSteps changed to ", core.fixBlackStripesForwardSteps)
        } else {
            //console.log("DEV_CONFIG: core.fixBlackStripesForwardSteps OK as ", core.fixBlackStripesForwardSteps)
        }
        if (core.fixBlackStripesBackwardSteps        !== pulseRuntimeSettings.fixBlackStripesBackwardSteps) {
            core.fixBlackStripesBackwardSteps        = pulseRuntimeSettings.fixBlackStripesBackwardSteps
            //console.log("DEV_CONFIG: core.fixBlackStripesBackwardSteps changed to ", core.fixBlackStripesBackwardSteps)
        } else {
            //console.log("DEV_CONFIG: core.fixBlackStripesBackwardSteps OK as ", core.fixBlackStripesBackwardSteps)
        }
        if (core.fixBlackStripesState               !== pulseRuntimeSettings.fixBlackStripesState) {
            core.fixBlackStripesState               = pulseRuntimeSettings.fixBlackStripesState
            //console.log("DEV_CONFIG: core.fixBlackStripesState changed to ", core.fixBlackStripesState)
        } else {
            //console.log("DEV_CONFIG: core.fixBlackStripesState OK as ", core.fixBlackStripesState)
        }

        pulseRuntimeSettings.devIdentified      = true
        pulseRuntimeSettings.appConfigured      = true

        completeDeviceConfigurationTimer.start()
    }

    Timer {
        id: neverGiveUpConfigurationTimer
        repeat: !pulseRuntimeSettings.appConfigured
        interval: 3000
        onTriggered: {
            if (pulseRuntimeSettings.appConfigured) {
                //console.log("DEV_CONFIG: pulseRuntimeSettings.appConfigured ", pulseRuntimeSettings.appConfigured, ". No need to repeat")
                return
            }
            configurePulseDevice()
        }
    }

    Timer {
        id: completeDeviceConfigurationTimer
        interval: deviceParameterSetterRepeat
        repeat: !pulseRuntimeSettings.devConfigured
        onTriggered: {

            if (pulseRuntimeSettings.devConfigured) {
                console.log("DEV_PARAM completeDeviceConfigurationTimer no need to repeat as devConfigured complete")
                return
            }

            if (dev === null){
                console.log("DEV_PARAM completeDeviceConfigurationTimer dev === null")
                return
            }

            if (pulseRuntimeSettings.userManualSetName === "...") {
                console.log("DEV_PARAM completeDeviceConfigurationTimer pulseRuntimeSettings.userManualSetName === null")
                return
            }

            console.log("DEV_PARAM Repeating setup for ", pulseRuntimeSettings.userManualSetName)

            if (pulseRuntimeSettings.devConfigured) {
                console.log("DEV_PARAM no need to repeat as devConfigured complete")
                return
            }
            if (pulseRuntimeSettings.onDistSetupChanged
                && pulseRuntimeSettings.onChartSetupChanged
                && pulseRuntimeSettings.onDatasetChanged
                && pulseRuntimeSettings.onTransChanged
                /*&& pulseRuntimeSettings.onDspSetupChanged*/
                && pulseRuntimeSettings.onSoundChanged)
                {
                    pulseRuntimeSettings.devConfigured = true
                    console.log("DEV_PARAM devConfigured complete")
                    logAllDevSetupAsCompleted()
                    datasetChartSetupTimer.start()
                    return
            } else {
                console.log("DEV_PARAM devConfigured still incomplete")
            }

            if (dev.datasetChart !== 0){
                deviceParameterSetterRepeat = 1000
                pulseRuntimeSettings.datasetChart = 0
                console.log("DEV_PARAM turning off chart during param update")
                //dev.datasetChart = 0
                return
            }

            if (!pulseRuntimeSettings.onDistSetupChanged) {
                console.log("DEV_PARAM checking distSetup")
                distSetup()
                return
            }
            if (!pulseRuntimeSettings.onChartSetupChanged) {
                console.log("DEV_PARAM checking chartSetup")
                chartSetup()
                return
            }
            if (!pulseRuntimeSettings.onTransChanged) {
                console.log("DEV_PARAM checking transSetup")
                transSetup()
                return
            }
            if (!pulseRuntimeSettings.onDspSetupChanged) {
                console.log("DEV_PARAM checking dspSetup")
                dspSetup()
                return
            }
            if (!pulseRuntimeSettings.onSoundChanged) {
                console.log("DEV_PARAM checking soundSetup")
                soundSetup()
            }
            if (!pulseRuntimeSettings.onDatasetChanged) {
                console.log("DEV_PARAM checking datasetSetup")
                datasetSetup()
                return
            }
        }
    }

    function resetAllSetupStates () {
        console.log("DEV_PARAM Lost connection, setup is suspicious, let's reset!")
        //Parameters
        pulseRuntimeSettings.distMax_ok = false
        pulseRuntimeSettings.distDeadZone_ok = false
        pulseRuntimeSettings.distConfidence_ok = false
        pulseRuntimeSettings.chartSamples_ok = false
        pulseRuntimeSettings.chartResolution_ok = false
        pulseRuntimeSettings.chartOffset_ok = false
        pulseRuntimeSettings.datasetTimestamp_ok = false
        pulseRuntimeSettings.datasetChart_ok = false
        pulseRuntimeSettings.datasetTemp_ok = false
        pulseRuntimeSettings.datasetEuler_ok = false
        pulseRuntimeSettings.datasetDist_ok = false
        pulseRuntimeSettings.datasetSDDBT_ok = false
        pulseRuntimeSettings.transFreq_ok = false
        pulseRuntimeSettings.transPulse_ok = false
        pulseRuntimeSettings.transBoost_ok = false
        pulseRuntimeSettings.soundSpeed_ok = false
        //Categories
        pulseRuntimeSettings.onDistSetupChanged = false
        pulseRuntimeSettings.onChartSetupChanged = false
        pulseRuntimeSettings.onDatasetChanged = false
        pulseRuntimeSettings.onTransChanged = false
        pulseRuntimeSettings.onDspSetupChanged = false
        pulseRuntimeSettings.onSoundChanged = false
        //Overall
        pulseRuntimeSettings.devConfigured = false
        //Restart the timer
        //completeDeviceConfigurationTimer.start()
    }

    function distSetup () {
        if (dev === null)
            return

        if (myDev === null)
            return

        if (pulseRuntimeSettings.onDistSetupChanged)
            return

        // distMax
        if (!pulseRuntimeSettings.distMax_ok) {
            if (dev.distMax === pulseRuntimeSettings.distMax) {
                pulseRuntimeSettings.distMax_ok = true
            } else {
                //console.log("DEV_PARAM onDistSetupChanged distMax set to", pulseRuntimeSettings.distMax)
                dev.distMax = pulseRuntimeSettings.distMax
                return
            }
        }

        // distDeadZone
        if (!pulseRuntimeSettings.distDeadZone_ok) {
            if (dev.distDeadZone === pulseRuntimeSettings.distDeadZone) {
                pulseRuntimeSettings.distDeadZone_ok = true
            } else {
                //console.log("DEV_PARAM onDistSetupChanged distDeadZone set to", pulseRuntimeSettings.distDeadZone)
                dev.distDeadZone = pulseRuntimeSettings.distDeadZone
                return
            }
        }

        // distConfidence
        if (!pulseRuntimeSettings.distConfidence_ok) {
            if (dev.distConfidence === pulseRuntimeSettings.distConfidence) {
                pulseRuntimeSettings.distConfidence_ok = true
            } else {
                //console.log("DEV_PARAM onDistSetupChanged distConfidence set to", pulseRuntimeSettings.distConfidence)
                dev.distConfidence = pulseRuntimeSettings.distConfidence
                return
            }
        }

        // Verify all
        if (pulseRuntimeSettings.distMax_ok
                && pulseRuntimeSettings.distDeadZone_ok
                && pulseRuntimeSettings.distConfidence_ok) {
            pulseRuntimeSettings.onDistSetupChanged = true
            //console.log("DEV_PARAM onDistSetupChanged complete")

        }
    }

    function chartSetup () {
        if (dev === null)
            return

        if (myDev === null)
            return

        if (pulseRuntimeSettings.onChartSetupChanged)
            return

        // chartSamples
        if (!pulseRuntimeSettings.chartSamples_ok) {
            if (dev.chartSamples === pulseRuntimeSettings.chartSamples) {
                pulseRuntimeSettings.chartSamples_ok = true
                //console.log("DEV_PARAM chartSamples OK as", dev.chartSamples)
            } else {
                //console.log("DEV_PARAM onChartSetupChanged chartSamples set to", pulseRuntimeSettings.chartSamples)
                dev.chartSamples = pulseRuntimeSettings.chartSamples
                return
            }
        }

        // chartResolution
        if (!pulseRuntimeSettings.chartResolution_ok) {
            if (dev.chartResolution === pulseRuntimeSettings.chartResolution) {
                pulseRuntimeSettings.chartResolution_ok = true
                //console.log("DEV_PARAM chartResolution OK as", dev.chartResolution)
            } else {
                //console.log("DEV_PARAM onChartSetupChanged chartResolution set to", pulseRuntimeSettings.chartResolution)
                dev.chartResolution = pulseRuntimeSettings.chartResolution
                return
            }
        }

        // chartOffset
        if (!pulseRuntimeSettings.chartOffset_ok) {
            if (dev.chartOffset === pulseRuntimeSettings.chartOffset) {
                pulseRuntimeSettings.chartOffset_ok = true
                //console.log("DEV_PARAM chartOffset OK as", dev.chartOffset)
            } else {
                //console.log("DEV_PARAM onChartSetupChanged chartOffset set to", pulseRuntimeSettings.chartOffset)
                dev.chartOffset = pulseRuntimeSettings.chartOffset
                return
            }
        }

        // Verify all
        if (pulseRuntimeSettings.chartSamples_ok
                && pulseRuntimeSettings.chartResolution_ok
                && pulseRuntimeSettings.chartOffset_ok) {
            pulseRuntimeSettings.onChartSetupChanged = true
            //console.log("DEV_PARAM onChartSetupChanged complete")
        }
    }

    function datasetSetup () {
        if (dev === null)
            return

        if (myDev === null)
            return

        if (pulseRuntimeSettings.onDatasetChanged)
            return

        // datasetTimestamp
        if (!pulseRuntimeSettings.datasetTimestamp_ok) {
            if (dev.datasetTimestamp === pulseRuntimeSettings.datasetTimestamp) {
                pulseRuntimeSettings.datasetTimestamp_ok = true
                //console.log("DEV_PARAM datasetTimestamp OK as", dev.datasetTimestamp)
            } else {
                //console.log("DEV_PARAM onDatasetChanged datasetTimestamp set to", pulseRuntimeSettings.datasetTimestamp)
                dev.datasetTimestamp = pulseRuntimeSettings.datasetTimestamp
                return
            }
        }

        /*
        // datasetChart
        if (!pulseRuntimeSettings.datasetChart_ok) {
            if (dev.datasetChart === pulseRuntimeSettings.datasetChart) {
                pulseRuntimeSettings.datasetChart_ok = true
                //console.log("DEV_PARAM datasetChart OK as", dev.datasetChart)
            } else {
                //console.log("DEV_PARAM onDatasetChanged datasetChart set to", pulseRuntimeSettings.datasetChart)
                dev.datasetChart = pulseRuntimeSettings.datasetChart
            }
        }
        */

        // datasetTemp
        if (!pulseRuntimeSettings.datasetTemp_ok) {
            if (dev.datasetTemp === pulseRuntimeSettings.datasetTemp) {
                pulseRuntimeSettings.datasetTemp_ok = true
                //console.log("DEV_PARAM datasetTemp OK as", dev.datasetTemp)
            } else {
                //console.log("DEV_PARAM onDatasetChanged datasetTemp set to", pulseRuntimeSettings.datasetTemp)
                dev.datasetTemp = pulseRuntimeSettings.datasetTemp
                return
            }
        }

        // datasetEuler
        if (!pulseRuntimeSettings.datasetEuler_ok) {
            if (dev.datasetEuler === pulseRuntimeSettings.datasetEuler) {
                pulseRuntimeSettings.datasetEuler_ok = true
                //console.log("DEV_PARAM datasetEuler OK as", dev.datasetEuler)
            } else {
                //console.log("DEV_PARAM onDatasetChanged datasetEuler set to", pulseRuntimeSettings.datasetEuler)
                dev.datasetEuler = pulseRuntimeSettings.datasetEuler
                return
            }
        }

        // datasetDist
        if (!pulseRuntimeSettings.datasetDist_ok) {
            if (dev.datasetDist === pulseRuntimeSettings.datasetDist) {
                pulseRuntimeSettings.datasetDist_ok = true
                //console.log("DEV_PARAM datasetDist OK as", dev.datasetDist)
            } else {
                //console.log("DEV_PARAM onDatasetChanged datasetDist set to", pulseRuntimeSettings.datasetDist)
                dev.datasetDist = pulseRuntimeSettings.datasetDist
                return
            }
        }

        // datasetSDDBT
        if (!pulseRuntimeSettings.datasetSDDBT_ok) {
            if (dev.datasetSDDBT === pulseRuntimeSettings.datasetSDDBT) {
                pulseRuntimeSettings.datasetSDDBT_ok = true
                //console.log("DEV_PARAM datasetSDDBT OK as", dev.datasetSDDBT)
            } else {
                //console.log("DEV_PARAM onDatasetChanged datasetSDDBT set to", pulseRuntimeSettings.datasetSDDBT)
                dev.datasetSDDBT = pulseRuntimeSettings.datasetSDDBT
                return
            }
        }

        // Verify all
        if (pulseRuntimeSettings.datasetTimestamp_ok
                && pulseRuntimeSettings.datasetTemp_ok
                && pulseRuntimeSettings.datasetEuler_ok
                && pulseRuntimeSettings.datasetDist_ok
                && pulseRuntimeSettings.datasetSDDBT_ok) {
            pulseRuntimeSettings.onDatasetChanged = true
            //console.log("DEV_PARAM onDatasetChanged complete")
        }
        /*
        if (pulseRuntimeSettings.datasetTimestamp_ok
                && pulseRuntimeSettings.datasetChart_ok
                && pulseRuntimeSettings.datasetTemp_ok
                && pulseRuntimeSettings.datasetEuler_ok
                && pulseRuntimeSettings.datasetDist_ok
                && pulseRuntimeSettings.datasetSDDBT_ok) {
            pulseRuntimeSettings.onDatasetChanged = true
            //console.log("DEV_PARAM onDatasetChanged complete")
        }
        */
    }

    Timer {
        id: datasetChartSetupTimer
        repeat: !pulseRuntimeSettings.datasetChart_ok
        interval: 1000
        onTriggered: {
            if (pulseRuntimeSettings.datasetChart_ok)
                return
            datasetChartSetup()
        }
    }

    function datasetChartSetup () {
        if (dev === null)
            return
        // datasetChart
        if (!pulseRuntimeSettings.datasetChart_ok) {
            if (dev.datasetChart === 1) {
                pulseRuntimeSettings.datasetChart_ok = true
                logAllDevSetupAsCompleted()
                //console.log("DEV_PARAM datasetChart OK as", dev.datasetChart)
            } else {
                //console.log("DEV_PARAM onDatasetChanged datasetChart set to", pulseRuntimeSettings.datasetChart)
                //dev.datasetChart = pulseRuntimeSettings.datasetChart
                pulseRuntimeSettings.datasetChart = 1
                dev.datasetChart = 1
            }
        }
    }

    function transSetup () {
        if (dev === null)
            return

        if (myDev === null)
            return

        if (pulseRuntimeSettings.onTransChanged)
            return

        // transFreq
        if (!pulseRuntimeSettings.transFreq_ok) {
            if (dev.transFreq === pulseRuntimeSettings.transFreq) {
                pulseRuntimeSettings.transFreq_ok = true
                //console.log("DEV_PARAM transFreq OK as", dev.transFreq)
            } else {
                //console.log("DEV_PARAM onTransChanged transFreq set to", pulseRuntimeSettings.transFreq)
                dev.transFreq = pulseRuntimeSettings.transFreq
                return
            }
        }

        // transPulse
        if (!pulseRuntimeSettings.transPulse_ok) {
            if (dev.transPulse === pulseRuntimeSettings.transPulse) {
                pulseRuntimeSettings.transPulse_ok = true
                //console.log("DEV_PARAM transPulse OK as", dev.transPulse)
            } else {
                //console.log("DEV_PARAM onTransChanged transPulse set to", pulseRuntimeSettings.transPulse)
                dev.transPulse = pulseRuntimeSettings.transPulse
                return
            }
        }

        // transBoost
        if (!pulseRuntimeSettings.transBoost_ok) {
            if (dev.transBoost === pulseRuntimeSettings.transBoost) {
                pulseRuntimeSettings.transBoost_ok = true
                //console.log("DEV_PARAM transBoost OK as", dev.transBoost)
            } else {
                //console.log("DEV_PARAM onTransChanged transBoost set to", pulseRuntimeSettings.transBoost)
                dev.transBoost = pulseRuntimeSettings.transBoost
                return
            }
        }

        // Verify all
        if (pulseRuntimeSettings.transFreq_ok
                && pulseRuntimeSettings.transPulse_ok
                && pulseRuntimeSettings.transBoost_ok) {
            pulseRuntimeSettings.onTransChanged = true
            //console.log("DEV_PARAM onTransChanged complete")
        }
    }

    function dspSetup () {
        // Let's just null out this check
        if (true){
            pulseRuntimeSettings.dspHorSmooth_ok = true
            pulseRuntimeSettings.onDspSetupChanged = true
            console.log("DEV_PARAM onDspSetupChanged set to ", pulseRuntimeSettings.onDspSetupChanged)
            return
        }

        if (dev === null)
            return

        if (myDev === null)
            return

        if (pulseRuntimeSettings.onDspSetupChanged)
            return

        // dspSmoothFactor
        if (!pulseRuntimeSettings.dspHorSmooth_ok) {
            if (dev.dspHorSmooth === pulseRuntimeSettings.dspHorSmooth) {
                pulseRuntimeSettings.dspHorSmooth_ok = true
                //console.log("DEV_PARAM dspHorSmooth OK as", dev.dspHorSmooth)
            } else {
                //console.log("DEV_PARAM onDspSetupChanged dspHorSmooth set to", pulseRuntimeSettings.dspHorSmooth)
                dev.dspHorSmooth = pulseRuntimeSettings.dspHorSmooth
                return
            }
        }

        // Verify all
        if (pulseRuntimeSettings.dspSmoothFactor_ok) {
            pulseRuntimeSettings.onDspSetupChanged = true
            //console.log("DEV_PARAM onDspSetupChanged complete")
        }
    }

    function soundSetup () {
        if (dev === null)
            return

        if (myDev === null)
            return

        if (pulseRuntimeSettings.onSoundChanged)
            return

        // soundSpeed
        if (!pulseRuntimeSettings.soundSpeed_ok) {
            if (dev.soundSpeed === pulseRuntimeSettings.soundSpeed) {
                pulseRuntimeSettings.soundSpeed_ok = true
                //console.log("DEV_PARAM soundSpeed OK as", dev.soundSpeed)
            } else {
                //console.log("DEV_PARAM onSoundChanged soundSpeed set to", pulseRuntimeSettings.soundSpeed)
                dev.soundSpeed = pulseRuntimeSettings.soundSpeed
                return
            }
        }

        // Verify all
        if (pulseRuntimeSettings.soundSpeed_ok) {
            pulseRuntimeSettings.onSoundChanged = true
            //console.log("DEV_PARAM onSoundChanged complete")
        }
    }

    function logAllDevSetupAsCompleted () {
        if (dev === null)
            return
        console.log("DEV_PARAM_COMPLETE: distMax is ", dev.distMax)
        console.log("DEV_PARAM_COMPLETE: distDeadZone is ", dev.distDeadZone)
        console.log("DEV_PARAM_COMPLETE: distConfidence is ", dev.distConfidence)
        console.log("DEV_PARAM_COMPLETE: chartSamples is ", dev.chartSamples)
        console.log("DEV_PARAM_COMPLETE: chartResolution is ", dev.chartResolution)
        console.log("DEV_PARAM_COMPLETE: chartOffset is ", dev.chartOffset)
        console.log("DEV_PARAM_COMPLETE: datasetTimestamp is ", dev.datasetTimestamp)
        console.log("DEV_PARAM_COMPLETE: datasetChart is ", dev.datasetChart)
        console.log("DEV_PARAM_COMPLETE: datasetTemp is ", dev.datasetTemp)
        console.log("DEV_PARAM_COMPLETE: datasetEuler is ", dev.datasetEuler)
        console.log("DEV_PARAM_COMPLETE: datasetDist is ", dev.datasetDist)
        console.log("DEV_PARAM_COMPLETE: datasetSDDBT is ", dev.datasetSDDBT)
        console.log("DEV_PARAM_COMPLETE: transFreq is ", dev.transFreq)
        console.log("DEV_PARAM_COMPLETE: transPulse is ", dev.transPulse)
        console.log("DEV_PARAM_COMPLETE: transBoost is ", dev.transBoost)
        console.log("DEV_PARAM_COMPLETE: dspHorSmooth is ", dev.dspHorSmooth)
        console.log("DEV_PARAM_COMPLETE: soundSpeed is ", dev.soundSpeed)

        if (dev != null) {
            if (dev.chartResolution !== pulseRuntimeSettings.chartResolution) {
                dev.chartResolution = pulseRuntimeSettings.chartResolution
                console.log("DEV_PARAM_COMPLETE: dev.chartResolution incorrect, set to ", pulseRuntimeSettings.chartResolution)
            }
        }
    }


    Timer {
        id: datasetChannelCounter
        interval: 100
        repeat: false
        onTriggered: {
            //console.log("number of channels:", dataset.channels.length)
            pulseRuntimeSettings.numberOfDatasetChannels = dataset.channels.length
        }
    }

    Connections {
        target: dataset
        function onChannelsUpdated () {
            datasetChannelCounter.restart()
        }
    }


    Connections {
        target: pulseRuntimeSettings

        function onHasDeviceLostConnectionChanged () {
            if (pulseRuntimeSettings.hasDeviceLostConnection) {
                console.log("DEV_PARAM alerted that device connection was lost")
                resetAllSetupStates()
            } else {
                console.log("DEV_PARAM alerted that device connection was regained (after being lost)")
                completeDeviceConfigurationTimer.start()
            }
        }

        //Update the runtime value
        function onUuidSuccessfullyOpenedChanged () {
            //console.log("DEV_UUID: onUuidSuccessfullyOpenedChanged for UUID ", pulseRuntimeSettings.uuidSuccessfullyOpened);
        }

        function onTransFreqChanged() {
            dev.transFreq = pulseRuntimeSettings.transFreq
            //console.log("DEV_CONFIG: separateMethod onTransFreqChanged new frequency is", dev.transFreq);
        }
        //DevDriver sets the pulseRuntimeSettings.devName, triggering this alert. Name will be "..." for no device or real device name
        function onDevNameChanged() {
            //console.log("TAV: onDevNameChanged to:", pulseRuntimeSettings.devName);
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
                        //console.log("TAV: device is present, observed onTimelinePositionChanged reconnection");
                    }
                    if (!pulseRuntimeSettings.didEverReceiveData) {
                        //dataUpdateDidChange = true
                        pulseRuntimeSettings.isReceivingData = true
                        pulseRuntimeSettings.didEverReceiveData = true
                        pulseRuntimeSettings.hasDeviceLostConnection = false
                        //console.log("TAV: device is present, observed onTimelinePositionChanged");
                    }
                } else {
                    //console.log("TAV: new device name is ..., cannot assume we regained connection");
                }


            }
        }
        function onAutoDepthMaxLevelChanged () {
            if (pulseRuntimeSettings.shouldDoAutoRange) {
                //dev.distMax = (pulseRuntimeSettings.autoDepthMaxLevel) * 1000
                //console.log("TAV: Adjusted max distance to ", pulseRuntimeSettings.autoDepthMaxLevel);
            }
        }
        function onManualSetLevelChanged () {
            if (!pulseRuntimeSettings.shouldDoAutoRange) {
                //dev.distMax = (pulseRuntimeSettings.manualSetLevel) * 1000
                //console.log("TAV: Adjusted max distance manual to ", pulseRuntimeSettings.manualSetLevel);
            }
        }
        /*
        function onDynamicResolutionChanged () {
            //console.log("TAV: onDynamicResolutionChanged do dynamicResolution? ", pulseRuntimeSettings.doDynamicResolution);
            if (!pulseRuntimeSettings.doDynamicResolution) {
                return
            }

            if (!pulseRuntimeSettings.userManualSetName === "...") {
                //console.log("TAV: onDynamicResolutionChanged do do not set before device is selected - name is ", pulseRuntimeSettings.userManualSetName);
                return
            }

            pulseRuntimeSettings.chartResolution = pulseRuntimeSettings.dynamicResolution
            dev.chartResolution = pulseRuntimeSettings.dynamicResolution
            //console.log("TAV: onDynamicResolutionChanged as ", pulseRuntimeSettings.dynamicResolution, ",devName ", pulseRuntimeSettings.devName, ", manSetName ", pulseRuntimeSettings.userManualSetName);
        }
        */


        /*
        function onCurrentDepthSolutionChanged () {
            //console.log("DEV_DEPTH: onCurrentDepthSolutionChanged to ", pulseRuntimeSettings.currentDepthSolution)
            if (pulseRuntimeSettings.currentDepthSolution === 0) {
                pulseRuntimeSettings.datasetDist = 0
                pulseRuntimeSettings.datasetSDDBT = 0
                dev.datasetDist = 0
                dev.datasetSDDBT = 0
            } else if (pulseRuntimeSettings.currentDepthSolution === 1) {
                pulseRuntimeSettings.datasetDist = 1
                pulseRuntimeSettings.datasetSDDBT = 0
                dev.datasetDist = 1
            } else {
                pulseRuntimeSettings.datasetDist = 0
                pulseRuntimeSettings.datasetSDDBT = 1
                dev.datasetSDDBT = 1
            }

        }
        */


    }

    // Connections to detect the live data feed is still alive

    Connections {
        target: dataset
        //Dataupdate is triggered by receiving data from transducer, but will also be triggered by loading a KLF file
        //Data update restarts the lostConnectionTimer to avoid it being triggered
        function onDataUpdate () {
            lostConnectionTimer.restart();
            if (!pulseRuntimeSettings.devSettingsEnforced) {
                pulseRuntimeSettings.devSettingsEnforced = true
                //configurePulseDevice()
            }
        }

    }



    // Timer to detect connection loss, this is shown in main
    Timer {
        id: lostConnectionTimer
        interval: 2500
        repeat: false
        running: false
        onTriggered: {
            if (pulseRuntimeSettings.didEverReceiveData) {
                if (pulseRuntimeSettings.devName !== "...") {
                    pulseRuntimeSettings.isReceivingData = false;
                    pulseRuntimeSettings.hasDeviceLostConnection = true
                    dataUpdateDidChange = false
                    //console.log("TAV: lost connection will be triggered for device", pulseRuntimeSettings.devName);
                } else {
                    //console.log("TAV: We do not loose connection for an unknown device", pulseRuntimeSettings.devNam);
                }
            } else {
                //console.log("TAV: We do not loose connection when we never received any data");
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
                //console.log("TAV: delaytimer, settingsCompleted && deviceIdentified, all done!");
                return
            }

            if (PulseSettings === null || pulseRuntimeSettings === null) {
                //console.log("TAV: delayTimer, settings === null, not ready to proceed");
                return
            }

            if ((dev === null) && pulseRuntimeSettings.userManualSetName === "...") {
                //console.log("TAV: delayTimer, dev === null, not ready to proceed");
                return
            }

            if (!settingsCompleted || !deviceIdentified) {
                if (false) {
                    //Automatically selected
                    if (pulseRuntimeSettings.devIdentified && !pulseRuntimeSettings.devConfigured) {
                        deviceIdentified = true
                        settingsCompleted = true
                        pulseRuntimeSettings.devConfigured = true
                        //pulseRuntimeSettings.devName = pulseRuntimeSettings.userManualSetName
                        //PulseSettings.devName = pulseRuntimeSettings.userManualSetName
                        //dev.devName === pulseRuntimeSettings.userManualSetName
                        //dev.devName === pulseRuntimeSettings.devName
                        //console.log("TAV: delayTimer, device automatically detected");
                        //pulseRuntimeSettings.appConfigured = true
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
                    //dev.devName === pulseRuntimeSettings.devName
                    //delayTimerRepeat = 5000
                    //console.log("TAV: delayTimer, was manually selected, will still try to look for the real device at every ms", delayTimerRepeat);
                    configurePulseDevice()
                    //pulseRuntimeSettings.appConfigured = true
                    //return
                }
            }
        }
    }

    Component.onCompleted: {
        //console.log("TAV deviceItem onCompleted");
        setPlotGeneral()
        //pickDev()
        delayTimer.start()
    }
}
