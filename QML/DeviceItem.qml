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

    //property var myDev: null
    property var devList: deviceManagerWrapper.devs
    property bool dynResolutionUpdated: false
    property int deviceParameterSetterRepeat: 500

    Connections {
        //target: dev ? dev : undefined
        target: dev

        function onDeviceVersionChanged () {
            if (pulseRuntimeSettings === null){
                console.log("DEV_PARAM onDeviceVersionChanged, but pulseRuntimeSettings was null. Aborting.")
                return
            }
            if (dev === null) {
                console.log("DEV_PARAM onDeviceVersionChanged, but dev was null. Aborting.")
                return
            }
            if (dev.devName === null) {
                console.log("DEV_PARAM onDeviceVersionChanged, but devName was null. Aborting.")
                return
            }

            if (dev.devName === "..." && !pulseRuntimeSettings.devConfigured) {
                console.log("DEV_PARAM onDeviceVersionChanged, but devName was ", dev.devName, ". Aborting.")
                return
            }

            if (dev.devName === "..." && pulseRuntimeSettings.devConfigured) {
                console.log("DEV_PARAM onDeviceVersionChanged, devName ... but device was already configured. Must have lost connection. Reset state")
                resetAllSetupStates()
                pulseRuntimeSettings.onDeviceVersionChanged = false;
                return
            }

            /*
            if (pulseRuntimeSettings.onDeviceVersionChanged) {
                console.log("DEV_PARAM onDeviceVersionChanged, but device already configured for devName ", dev.devName, ". Aborting.")
                return
            }
            */

            pulseRuntimeSettings.onDeviceVersionChanged = true
            //console.log("DEV_PARAM onDeviceVersionChanged, devName is ", dev.devName, ". Finally.")
            //myDev = dev
        }


        function onDistSetupChanged () {
            if (pulseRuntimeSettings.userManualSetName === "...")
                return

            //For expert review screen
            pulseRuntimeSettings.distMax_Copy = dev.distMax
            pulseRuntimeSettings.distDeadZone_Copy = dev.distDeadZone
            pulseRuntimeSettings.distConfidence_Copy = dev.distConfidence
            //Check if settings are OK
            if (dev.distMax !== pulseRuntimeSettings.distMax) {
                pulseRuntimeSettings.distMax_ok = false
                pulseRuntimeSettings.onDistSetupChanged = false
                console.log("DEV_PARAM onDistSetupChanged, found deviation for dev.distMax", dev.distMax)
            }
            if (dev.distDeadZone !== pulseRuntimeSettings.distDeadZone) {
                pulseRuntimeSettings.distDeadZone_ok = false
                pulseRuntimeSettings.onDistSetupChanged = false
                console.log("DEV_PARAM onDistSetupChanged, found deviation for dev.distDeadZone", dev.distDeadZone)
            }
            if (dev.distConfidence !== pulseRuntimeSettings.distConfidence) {
                pulseRuntimeSettings.distConfidence_ok = false
                pulseRuntimeSettings.onDistSetupChanged = false
                console.log("DEV_PARAM onDistSetupChanged, found deviation for dev.distConfidence", dev.distConfidence)
            }
            //Redo settings if needed
            if (!pulseRuntimeSettings.onDistSetupChanged) {
                console.log("DEV_PARAM onDistSetupChanged, found deviation - run chartSetup")
                distSetup()
            }
        }

        function onChartSetupChanged () {
            if (pulseRuntimeSettings.userManualSetName === "...")
                return

            //For expert review screen
            pulseRuntimeSettings.chartResolution_Copy = dev.chartResolution
            pulseRuntimeSettings.chartSamples_Copy = dev.chartSamples
            pulseRuntimeSettings.chartOffset_Copy = dev.chartOffset
            //Check if settings are OK
            if (dev.chartResolution !== pulseRuntimeSettings.chartResolution) {
                pulseRuntimeSettings.chartResolution_ok = false
                pulseRuntimeSettings.onChartSetupChanged = false
                console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.chartResolution", dev.chartResolution)
            }
            if (dev.chartSamples !== pulseRuntimeSettings.chartSamples) {
                pulseRuntimeSettings.chartSamples_ok = false
                pulseRuntimeSettings.onChartSetupChanged = false
                console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.chartSamples", dev.chartSamples)
            }
            if (dev.chartOffset !== pulseRuntimeSettings.chartOffset) {
                pulseRuntimeSettings.chartOffset_ok = false
                pulseRuntimeSettings.onChartSetupChanged = false
                console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.chartOffset", dev.chartOffset)
            }
            //Redo settings if needed
            if (!pulseRuntimeSettings.onChartSetupChanged) {
                console.log("DEV_PARAM onChartSetupChanged, found deviation - run chartSetup")
                chartSetup()
            }
        }

        function onDatasetChanged () {
            if (pulseRuntimeSettings.userManualSetName === "...")
                return

            //For expert review screen
            pulseRuntimeSettings.ch1Period_Copy = dev.ch1Period
            pulseRuntimeSettings.datasetChart_Copy = dev.datasetChart
            pulseRuntimeSettings.datasetDist_Copy = dev.datasetDist
            pulseRuntimeSettings.datasetSDDBT_Copy = dev.datasetSDDBT
            pulseRuntimeSettings.datasetEuler_Copy = dev.datasetEuler
            pulseRuntimeSettings.datasetTemp_Copy = dev.datasetTemp
            pulseRuntimeSettings.datasetTimestamp_Copy = dev.datasetTimestamp
            //Check if settings are OK
            if (dev.ch1Period !== pulseRuntimeSettings.ch1Period) {
                pulseRuntimeSettings.ch1Period_ok = false
                pulseRuntimeSettings.onDatasetChanged = false
                console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.ch1Period", dev.ch1Period)
            }
            if (dev.datasetChart !== pulseRuntimeSettings.datasetChart) {
                pulseRuntimeSettings.datasetChart_ok = false
                pulseRuntimeSettings.onDatasetChanged = false
                console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.datasetChart", dev.datasetChart)
            }
            if (dev.datasetDist !== pulseRuntimeSettings.datasetDist) {
                pulseRuntimeSettings.datasetDist_ok = false
                pulseRuntimeSettings.onDatasetChanged = false
                console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.datasetDist", dev.datasetDist)
            }
            if (dev.datasetSDDBT !== pulseRuntimeSettings.datasetSDDBT) {
                pulseRuntimeSettings.datasetSDDBT_ok = false
                pulseRuntimeSettings.onDatasetChanged = false
                console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.datasetSDDBT", dev.datasetSDDBT)
            }
            if (dev.datasetEuler !== pulseRuntimeSettings.datasetEuler) {
                pulseRuntimeSettings.datasetEuler_ok = false
                pulseRuntimeSettings.onDatasetChanged = false
                console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.datasetEuler", dev.datasetEuler)
            }
            if (dev.datasetTemp !== pulseRuntimeSettings.datasetTemp) {
                pulseRuntimeSettings.datasetTemp_ok = false
                pulseRuntimeSettings.onDatasetChanged = false
                console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.datasetTemp", dev.datasetTemp)
            }
            if (dev.datasetTimestamp !== pulseRuntimeSettings.datasetTimestamp) {
                pulseRuntimeSettings.datasetTimestamp_ok = false
                pulseRuntimeSettings.onDatasetChanged = false
                console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.datasetTimestamp", dev.datasetTimestamp)
            }
            //Redo settings if needed
            if (!pulseRuntimeSettings.onDatasetChanged) {
                console.log("DEV_PARAM onChartSetupChanged, found deviation - run datasetSetup")
                datasetSetup()
            }

        }

        function onTransChanged () {
            if (pulseRuntimeSettings.userManualSetName === "...")
                return

            //For expert review screen
            pulseRuntimeSettings.transPulse_Copy = dev.transPulse
            pulseRuntimeSettings.transFreq_Copy = dev.transFreq
            pulseRuntimeSettings.transBoost_Copy = dev.transBoost
            //Check if settings are OK
            if (dev.transPulse !== pulseRuntimeSettings.transPulse) {
                pulseRuntimeSettings.transPulse_ok = false
                pulseRuntimeSettings.onTransChanged = false
                console.log("DEV_PARAM onTransChanged, found deviation for dev.transPulse", dev.transPulse)
            }
            if (dev.transFreq !== pulseRuntimeSettings.transFreq) {
                pulseRuntimeSettings.transFreq_ok = false
                pulseRuntimeSettings.onTransChanged = false
                console.log("DEV_PARAM onTransChanged, found deviation for dev.transFreq", dev.transFreq)
            }
            if (dev.transBoost !== pulseRuntimeSettings.transBoost) {
                pulseRuntimeSettings.transBoost_ok = false
                pulseRuntimeSettings.onTransChanged = false
                console.log("DEV_PARAM onTransChanged, found deviation for dev.transBoost", dev.transBoost)
            }
            //Redo settings if needed
            if (!pulseRuntimeSettings.onTransChanged) {
                console.log("DEV_PARAM onTransChanged, found deviation - run transSetup")
                transSetup()
            }
        }

        function onDspSetupChanged () {
            if (pulseRuntimeSettings.userManualSetName === "...")
                return

            //For expert review screen
            pulseRuntimeSettings.dspHorSmooth_Copy = dev.dspHorSmooth
        }

        function onSoundChanged () {
            if (pulseRuntimeSettings.userManualSetName === "...")
                return

            //For expert review screen
            pulseRuntimeSettings.soundSpeed_Copy = dev.soundSpeed
            //Check if settings are OK
            if (dev.soundSpeed !== pulseRuntimeSettings.soundSpeed) {
                pulseRuntimeSettings.soundSpeed_ok = false
                pulseRuntimeSettings.onSoundChanged = false
                console.log("DEV_PARAM onSoundChanged, found deviation for dev.soundSpeed", dev.soundSpeed)
            }
            //Redo settings if needed
            if (!pulseRuntimeSettings.onSoundChanged) {
                console.log("DEV_PARAM onSoundChanged, found deviation - run soundSetup")
                soundSetup()
            }
        }

    }

    /*
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
                            console.log("DEV_PARAM: chartResolution as devValue set to ", pulseRuntimeSettings.dynamicResolution), " by doDynamicResolution";
                            return pulseRuntimeSettings.dynamicResolution
                        } else {
                            console.log("DEV_PARAM: chartResolution as devValue set to ", pulseRuntimeSettings.chartResolution, "dynamicResolution is false");
                            return pulseRuntimeSettings.chartResolution
                        }
                    } else {
                        console.log("DEV_PARAM: dev is null, resolution is 0 for now");
                        return 0
                    }
                }

                isValid: dev !== null ? dev.chartSetupState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        if (dev === null)
                            return
                        if (pulseRuntimeSettings.doDynamicResolution) {
                            if (value !== pulseRuntimeSettings.dynamicResolution) {
                                value = pulseRuntimeSettings.dynamicResolution
                                console.log("DEV_PARAM: onValueChanged, dev.chartResolution set to pulseRuntimeSettings.dynamicResolution", pulseRuntimeSettings.dynamicResolution)
                            }
                        } else {
                            if (value !== pulseRuntimeSettings.chartResolution) {
                                value = pulseRuntimeSettings.chartResolution
                                console.log("DEV_PARAM: onValueChanged, dev.chartResolution set to pulseRuntimeSettings.chartResolution", pulseRuntimeSettings.chartResolution)
                            }
                        }
                        //TODO: Is it correct to disable this?
                        //pulseRuntimeSettings.chartResolution = value
                        console.log("DEV_PARAM: chartResolution onValueChanged, but now we did not set pulseRuntimeSettings.chartResolution to ", value);
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onUserManualSetNameChanged() {
                        if (pulseRuntimeSettings.userManualSetName === "...") {
                            return
                        }
                        //TODO
                    }

                    function onChartResolutionChanged () {
                        console.log("DEV_PARAM: onChartResolutionChanged")
                        if (dev !== null) {
                            if (pulseRuntimeSettings.doDynamicResolution) {
                                if (dev.chartResolution !== pulseRuntimeSettings.dynamicResolution) {
                                    dev.chartResolution = pulseRuntimeSettings.dynamicResolution
                                    console.log("DEV_PARAM: dev.chartResolution set to pulseRuntimeSettings.dynamicResolution")
                                } else {
                                    console.log("DEV_PARAM: dev.chartResolution OK, already equal to pulseRuntimeSettings.dynamicResolution")
                                }
                            } else {
                                if (dev.chartResolution !== pulseRuntimeSettings.chartResolution) {
                                    dev.chartResolution = pulseRuntimeSettings.chartResolution
                                    console.log("DEV_PARAM: dev.chartResolution set to pulseRuntimeSettings.chartResolution", pulseRuntimeSettings.chartResolution)
                                } else {
                                    console.log("DEV_PARAM: dev.chartResolution OK, already equal to pulseRuntimeSettings.chartResolution")
                                }
                            }
                        } else {
                            console.log("DEV_PARAM: onChartResolutionChanged, but dev is null")
                        }
                    }

                    function onDynamicResolutionChanged () {
                        console.log("DEV_PARAM: onChartResolutionChanged")
                        if (pulseRuntimeSettings.hasDeviceLostConnection) {
                            console.log("DEV_PARAM: no need to set resolution dynamically when connection is lost")
                            return
                        }
                        if (!pulseRuntimeSettings.doDynamicResolution) {
                            console.log("DEV_PARAM: for this device we so not do dynamic resolutiuon")
                            return
                        }
                        //TODO: Do not touch the default pulseRuntimeSettings.chartResolution, will this work?
                        if (dev !== null) {
                            if (dev.devName !== "...") {
                                if (dev.chartResolution !== pulseRuntimeSettings.dynamicResolution) {
                                    if (pulseRuntimeSettings.is2DTransducer) {
                                        console.log("chartResolution: dev.chartResolution !== pulseRuntimeSettings.dynamicResolution. Enforce!")
                                        dev.chartResolution = pulseRuntimeSettings.dynamicResolution
                                    } else {
                                        console.log("DEV_PARAM: only set dev.chartResolution to dynamicResolution when is2DTransducer")
                                    }

                                }
                            } else {
                                console.log("DEV_PARAM: Skip chartResolution for devName ...")
                            }
                        } else {
                            console.log("DEV_PARAM: Unable to check if dev.chartResolution is OK as dev === null")
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
                        if (dev === null)
                            return
                        //pulseRuntimeSettings.chartSamples = value
                        //dev.chartSamples = pulseRuntimeSettings.chartSamples
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onChartSamplesChanged () {
                        if (dev !== null) {
                            if (dev.chartSamples !== pulseRuntimeSettings.chartSamples) {
                                dev.chartSamples = pulseRuntimeSettings.chartSamples
                                console.log("DYNAMIC: Set the dev.chartSamples to ", dev.chartSamples, " using source pulseRuntimeSettings.chartSamples of ", pulseRuntimeSettings.chartSamples)
                            }
                        }
                    }
                    function onDynamicSamplesChanged () {
                        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue) {
                            return
                        }
                        pulseRuntimeSettings.chartSamples = pulseRuntimeSettings.dynamicSamples
                        console.log("DYNAMIC: received onDynamicSamplesChanged value ", pulseRuntimeSettings.dynamicSamples)
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
                devValue: {
                    if (dev !== null && pulseRuntimeSettings !== null) {
                        console.log("DEV_PARAM: chartOffset as devValue set to ", pulseRuntimeSettings.chartOffset);
                        return pulseRuntimeSettings.chartResolution
                    } else {
                        console.log("DEV_PARAM: dev is null, offset is 0 for now");
                        return 0
                    }
                }

                //devValue: dev !== null ? dev.chartOffset : 0
                isValid: dev !== null ? dev.chartSetupState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        if (dev === null)
                            return
                        if (value !== pulseRuntimeSettings.chartOffset) {
                            console.log("DEV_PARAM: Param spinbox tried to set chartOffset to ", value, " let's use",pulseRuntimeSettings.chartOffset)
                            value = pulseRuntimeSettings.chartOffset
                        }
                        //TODO: Is it correct to disable this?
                        //pulseRuntimeSettings.chartOffset = value
                        console.log("DEV_PARAM: chartOffset onValueChanged, but now we did not set  pulseRuntimeSettings.chartOffset to", value)
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onChartOffsetChanged () {
                        if (dev !== null) {
                            if (dev.chartOffset !== pulseRuntimeSettings.chartOffset) {
                                dev.chartOffset = pulseRuntimeSettings.chartOffset
                                console.log("DEV_PARAM: Set the dev.chartOffset to ", dev.chartOffset, " using source pulseRuntimeSettings.chartOffset of ", pulseRuntimeSettings.chartOffset)
                            }
                        } else {
                            console.log("DEV_PARAM: dev is null, cannot touch offset just now");
                        }

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
                        if (dev === null)
                            return
                        //pulseRuntimeSettings.distMax = value
                        //dev.distMax = pulseRuntimeSettings.distMax
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onDistMaxChanged () {
                        if (dev !== null) {
                            if (dev.distMax !== pulseRuntimeSettings.distMax) {
                                dev.distMax = pulseRuntimeSettings.distMax
                                //console.log("DEV_CONFIG: Set the dev.distMax to ", dev.distMax, " using source pulseRuntimeSettings.distMax of ", pulseRuntimeSettings.distMax)
                            }
                        }
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
                        if (dev === null)
                            return
                        //pulseRuntimeSettings.distDeadZone = value
                        //dev.distDeadZone = pulseRuntimeSettings.distDeadZone
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onDistDeadZoneChanged () {
                        if (dev !== null) {
                            if (dev.distDeadZone !== pulseRuntimeSettings.distDeadZone) {
                                dev.distDeadZone = pulseRuntimeSettings.distDeadZone
                                //console.log("DEV_CONFIG: Set the dev.distDeadZone to ", dev.distDeadZone, " using source pulseRuntimeSettings.distDeadZone of ", pulseRuntimeSettings.distDeadZone)
                            }
                        }

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
                        if (dev === null)
                            return
                        //pulseRuntimeSettings.distConfidence = value
                        //dev.distConfidence = pulseRuntimeSettings.distConfidence
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onDistConfidenceChanged () {
                        if (dev !== null) {
                            if (dev.distConfidence !== pulseRuntimeSettings.distConfidence) {
                                dev.distConfidence = pulseRuntimeSettings.distConfidence
                                //console.log("DEV_CONFIG: Set the dev.distConfidence to ", dev.distConfidence, " using source pulseRuntimeSettings.distConfidence of ", pulseRuntimeSettings.distConfidence)
                            }
                        }
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
                        if (dev === null)
                            return
                        //pulseRuntimeSettings.transPulse = value
                        //dev.transPulse = pulseRuntimeSettings.transPulse
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onTransPulseChanged () {
                        if (dev !== null) {
                            if (dev.transPulse !== pulseRuntimeSettings.transPulse) {
                                dev.transPulse = pulseRuntimeSettings.transPulse
                                //console.log("DEV_CONFIG: Set the dev.transPulse to ", dev.transPulse, " using source pulseRuntimeSettings.transPulse of ", pulseRuntimeSettings.transPulse)
                            }
                        }
                    }
                }
            }
        }

        ParamSetup {
            paramName: qsTr("Frequency, kHz")

            SpinBoxCustom {
                from: pulseRuntimeSettings.transFreqWide
                to: pulseRuntimeSettings.transFreqNarrow
                stepSize: 5
                value: pulseRuntimeSettings.transFreq
                devValue: pulseRuntimeSettings.transFreq
                //devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.transFreq : 0
                //devValue: dev !== null ? dev.transFreq : 0
                isValid: dev !== null ? dev.transcState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        if (dev === null)
                            return
                        //pulseRuntimeSettings.transFreq = value
                        //dev.transFreq = pulseRuntimeSettings.transFreq
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onTransFreqChanged () {
                        if (dev !== null) {
                            if (dev.transFreq !== pulseRuntimeSettings.transFreq) {
                                dev.transFreq = pulseRuntimeSettings.transFreq
                                console.log("DEV_CONFIG: Set the dev.transFreq to ", dev.transFreq, " using source pulseRuntimeSettings.transFreq of ", pulseRuntimeSettings.transFreq)
                            }
                        }
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
                        if (dev === null)
                            return
                        //pulseRuntimeSettings.transBoost = value
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
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onTransBoostChanged () {
                        if (dev !== null) {
                            if (dev.transBoost !== pulseRuntimeSettings.transBoost) {
                                dev.transBoost = pulseRuntimeSettings.transBoost
                                //console.log("DEV_CONFIG: Set the dev.transBoost to ", dev.transBoost, " using source pulseRuntimeSettings.transBoost of ", pulseRuntimeSettings.transBoost)
                            }
                        }
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
                        if (dev === null)
                            return
                        //pulseRuntimeSettings.dspHorSmooth = value
                        //dev.dspHorSmooth = pulseRuntimeSettings.dspHorSmooth
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onDspHorSmoothChanged () {
                        if (dev !== null) {
                            if (dev.dspHorSmooth !== pulseRuntimeSettings.dspHorSmooth) {
                                dev.dspHorSmooth = pulseRuntimeSettings.dspHorSmooth
                                //console.log("DEV_CONFIG: Set the dev.dspHorSmooth to ", dev.dspHorSmooth, " using source pulseRuntimeSettings.dspHorSmooth of ", pulseRuntimeSettings.dspHorSmooth)
                            }
                        }
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
                        if (dev === null)
                            return
                        //pulseRuntimeSettings.soundSpeed = value * 1000
                        //dev.soundSpeed = pulseRuntimeSettings.soundSpeed
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onSoundSpeedChanged () {
                        if (dev !== null) {
                            if (dev.soundSpeed !== pulseRuntimeSettings.soundSpeed) {
                                dev.soundSpeed = pulseRuntimeSettings.soundSpeed
                                //console.log("DEV_CONFIG: Set the dev.soundSpeed to ", dev.soundSpeed, " using source pulseRuntimeSettings.soundSpeed of ", pulseRuntimeSettings.soundSpeed)
                            }
                        }
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
                        if (dev === null)
                            return
                        //pulseRuntimeSettings.ch1Period = value
                        console.log("DYNAMIC: Set the dev.ch1Period to ", dev.ch1Period, " onValueChanged ", value)
                        //dev.ch1Period = pulseRuntimeSettings.ch1Period
                    }
                    isDriverChanged = false
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onCh1PeriodChanged () {
                        if (dev !== null) {
                            if (dev.ch1Period !== pulseRuntimeSettings.ch1Period) {
                                dev.ch1Period = pulseRuntimeSettings.ch1Period
                                console.log("DYNAMIC: Set the dev.ch1Period to ", dev.ch1Period, " using source pulseRuntimeSettings.ch1Period of ", pulseRuntimeSettings.ch1Period)
                            }
                        }
                    }
                    function onDynamicPeriodChanged () {
                        pulseRuntimeSettings.ch1Period = pulseRuntimeSettings.dynamicPeriod
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
                        if (dev === null)
                            return
                        if (value == 1) {
                            //pulseRuntimeSettings.datasetChart = 1
                        } else {
                            //pulseRuntimeSettings.datasetChart = 0
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
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onDatasetChartChanged () {
                        if (dev !== null) {
                            if (dev.datasetChart !== pulseRuntimeSettings.datasetChart) {
                                dev.datasetChart = pulseRuntimeSettings.datasetChart
                                console.log("DEV_PARAM: Set the dev.datasetChart to ", dev.datasetChart, " caused by onDatasetChartChanged using source pulseRuntimeSettings.datasetChart of ", pulseRuntimeSettings.datasetChart)
                            }
                        }
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
                        if (dev === null)
                            return
                        if (value === 1) {
                            //pulseRuntimeSettings.currentDepthSolution = 1
                        }
                        else if (value === 2) {
                            //pulseRuntimeSettings.currentDepthSolution = 2
                        }
                        else {
                            //pulseRuntimeSettings.currentDepthSolution = 0
                        }
                    }
                    isDriverChanged = false
                }

                property var items: [qsTr("Off"), qsTr("On"), qsTr("NMEA")]
                textFromValue: function(value) {
                    return items[value];
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onCurrentDepthSolutionChanged() {
                        // decide on proper values
                        let newValue = pulseRuntimeSettings.currentDepthSolution
                        if (newValue === 1) {
                            //pulseRuntimeSettings.datasetDist = 1
                            //pulseRuntimeSettings.datasetSDDBT = 0
                        }
                        else if (newValue === 2 ) {
                            //pulseRuntimeSettings.datasetDist = 0
                            //pulseRuntimeSettings.datasetSDDBT = 1
                        }
                        else {
                            //pulseRuntimeSettings.datasetDist = 0
                            //pulseRuntimeSettings.datasetSDDBT = 0
                        }
                        // write if needed
                        if (dev !== null) {
                            if (dev.datasetDist !== pulseRuntimeSettings.datasetDist) {
                                dev.datasetDist = pulseRuntimeSettings.datasetDist
                            }
                            if (dev.datasetSDDBT !== pulseRuntimeSettings.datasetSDDBT) {
                                dev.datasetSDDBT = pulseRuntimeSettings.datasetSDDBT
                            }
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
                        if (dev === null)
                            return
                        if (value == 1) {
                            //pulseRuntimeSettings.datasetEuler = 1
                            //dev.datasetEuler = pulseRuntimeSettings.datasetEuler
                        }
                        else if (dev.datasetEuler & 1) {
                            //pulseRuntimeSettings.datasetEuler = 0
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
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onDatasetEulerChanged () {
                        if (dev !== null) {
                            if (dev.datasetEuler !== pulseRuntimeSettings.datasetEuler) {
                                dev.datasetEuler = pulseRuntimeSettings.datasetEuler
                                //console.log("DEV_CONFIG: Set the dev.datasetEuler to ", dev.datasetEuler, " using source pulseRuntimeSettings.datasetEuler of ", pulseRuntimeSettings.datasetEuler)
                            }
                        }
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
                        if (dev === null)
                            return
                        //console.log("Dev_value: datasetTemp isDriverChanged, new value ", value)
                        if(value == 1) {
                            //pulseRuntimeSettings.datasetTemp = 1
                        } else if (dev.datasetTemp & 1) {
                            //pulseRuntimeSettings.datasetTemp = 0
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
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onDatasetTempChanged () {
                        if (dev !== null) {
                            if (dev.datasetTemp !== pulseRuntimeSettings.datasetTemp) {
                                dev.datasetTemp = pulseRuntimeSettings.datasetTemp
                                //console.log("DEV_CONFIG: Set the dev.datasetTemp to ", dev.datasetTemp, " using source pulseRuntimeSettings.datasetTemp of ", pulseRuntimeSettings.datasetTemp)
                            }
                        }
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
                        if (dev === null)
                            return
                        if (value == 1) {
                            //pulseRuntimeSettings.datasetTimestamp = 1
                        } else if (dev.datasetTimestamp & 1) {
                            //pulseRuntimeSettings.datasetTimestamp = 0
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
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onDatasetTimestampChanged () {
                        if (dev !== null) {
                            if (dev.datasetTimestamp !== pulseRuntimeSettings.datasetTimestamp) {
                                dev.datasetTimestamp = pulseRuntimeSettings.datasetTimestamp
                                //console.log("DEV_CONFIG: Set the dev.datasetTimestamp to ", dev.datasetTimestamp, " using source pulseRuntimeSettings.datasetTimestamp of ", pulseRuntimeSettings.datasetTimestamp)
                            }
                        }
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

    /*
    function setTransducerFrequency (frequency) {
        if (dev !== null) {
            dev.transFreq = frequency
        } else {
            //console.log("TAV: FAILED to do dev.transFreq = frequency, dev == null");
        }
    }
    */

    function setPlotGeneral() {
        // Default values for all Pulse devices
        //console.log("TAV: setPlotGeneral - start");
        //targetPlot.plotEchogramVisible(pulseRuntimeSettings.echogramVisible)
        //targetPlot.plotBottomTrackVisible(pulseRuntimeSettings.bottomTrackVisible)
        //targetPlot.plotBottomTrackTheme(pulseRuntimeSettings.bottomTrackVisibleModel)
        //targetPlot.plotRangefinderVisible(pulseRuntimeSettings.rangefinderVisible)
        //targetPlot.plotGNSSVisible(pulseRuntimeSettings.gnssVisible, 1)
        //targetPlot.plotGridVerticalNumber(pulseRuntimeSettings.gridNumber)
        //targetPlot.plotGridFillWidth(pulseRuntimeSettings.fillWidthGrid)
        //targetPlot.plotAngleVisibility(pulseRuntimeSettings.angleVisible)
        //targetPlot.plotVelocityVisible(pulseRuntimeSettings.velocityVisible)

        //console.log("TAV: setPlotGeneral - done");
    }

    function setPlotPulseRed () {
        // Device depentent values for PulseRed
        console.log("TAV: setPlotPulseRed - start");

        // General plot
        /*
        targetPlot.plotEchogramCompensation(0)
        targetPlot.plotDatasetChannel(32767, 32768)
        core.setSideScanChannels(32767, 32768)

        // Bottom tracking
        //disableBottomTracking()
        /*
        if (pulseRuntimeSettings.processBottomTrack) {
            doBottomTracking()
        }
        */

        console.log("TAV: setPlotPulseRed - done");
    }

    function setPlotPulseBlue () {
        console.log("TAV: setPlotPulseBlue - start");

        /*
        let channel1 = 2
        let channel2 = 3
        console.log("Side scan: normal direction, channel1", channel1, "channel2", channel2)
        if (!PulseSettings.isSideScanCableFacingFront) {
            channel1 = 3
            channel2 = 2
            console.log("Side scan: mounted wrong direction, channel1", channel1, "channel2", channel2)
        }

        targetPlot.plotEchogramCompensation(1)
        targetPlot.plotDatasetChannel(channel1, channel2)
        core.setSideScanChannels(channel1, channel2)

        //disableBottomTracking()
        //doBottomTracking()
        */

        console.log("TAV: setPlotPulseBlue - done");
    }

    function disableBottomTracking () {
        //targetPlot.plotBottomTrackVisible = false
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
        //console.log("Bottom Track - start");
        targetPlot.plotBottomTrackVisible(pulseRuntimeSettings.bottomTrackVisible)
        if (!PulseSettings.isSideScanOnLeftHandSide) {
            pulseRuntimeSettings.bottomTrackVisibleModel = 1
            console.log("DistProcessing - use right hand line side (theme 1)")
        } else {
            console.log("DistProcessing - use default left hand line side (theme 0)")
        }

        targetPlot.plotBottomTrackTheme(pulseRuntimeSettings.bottomTrackVisibleModel)

        console.log("DistProcessing - distanceParams", pulseRuntimeSettings.distProcessing);
        console.log("DistProcessing - visible?", pulseRuntimeSettings.distProcessing, " - theme?", pulseRuntimeSettings.bottomTrackVisibleModel);

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

        /*
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
        */

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

        console.log("DEV_PARAM: pulseRuntimeSettings, plot specific, for", pulseRuntimeSettings.userManualSetName)
        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed
                || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto) {
            setPlotPulseRed()
        } else {
            setPlotPulseBlue()
        }


        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed
                || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto) {
            console.log("DEV_PARAM: pulseRuntimeSettings - cone for", pulseRuntimeSettings.userManualSetName)
            if (PulseSettings.ecoConeIndex === 0) {
                pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqWide
                console.log("DEV_PARAM: pulse red wide")
            } else if (PulseSettings.ecoConeIndex === 1) {
                pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqMedium
                console.log("DEV_PARAM: pulse red medium")
            } else {
                pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqNarrow
                console.log("DEV_PARAM: pulse red narrow")
            }
        }

        console.log("DEV_PARAM: pulseRuntimeSettings - black stripes for", pulseRuntimeSettings.userManualSetName)
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

    /*
    Timer {
        id: neverGiveUpConfigurationTimer
        repeat: !pulseRuntimeSettings.appConfigured
        interval: 1000
        onTriggered: {
            if (pulseRuntimeSettings.appConfigured) {
                console.log("DEV_CONFIG: pulseRuntimeSettings.appConfigured ", pulseRuntimeSettings.appConfigured, ". No need to repeat")
                return
            }
            configurePulseDevice()
        }
    }
    */

    function ifSetupCompleted () {
        if (pulseRuntimeSettings.onDistSetupChanged
                && pulseRuntimeSettings.onChartSetupChanged
                && pulseRuntimeSettings.onDatasetChanged
                && pulseRuntimeSettings.onTransChanged
                /*&& pulseRuntimeSettings.onDspSetupChanged*/
                && pulseRuntimeSettings.onSoundChanged) {
            pulseRuntimeSettings.devConfigured = true
            console.log("DEV_PARAM devConfigured complete")
            logAllDevSetupAsCompleted()
            return true
        } else {
            console.log("DEV_PARAM devConfigured still incomplete")
            return false
        }
    }

    Timer {
        id: completeDeviceConfigurationTimer
        interval: deviceParameterSetterRepeat
        repeat: !pulseRuntimeSettings.devConfigured
        onTriggered: {
            console.log("DEV_PARAM deviceParameterSetterRepeat")
            if (pulseRuntimeSettings.devConfigured) {
                console.log("DEV_PARAM completeDeviceConfigurationTimer no need to repeat as devConfigured complete")
                return
            }

            if (dev === null){
                console.log("DEV_PARAM completeDeviceConfigurationTimer wait, dev === null")
                return
            }

            if (pulseRuntimeSettings.userManualSetName === "...") {
                console.log("DEV_PARAM completeDeviceConfigurationTimer wait, pulseRuntimeSettings.userManualSetName === ...")
                return
            }

            if (pulseRuntimeSettings.devName === "...") {
                console.log("DEV_PARAM completeDeviceConfigurationTimer wait, pulseRuntimeSettings.devName === ...")
                return
            }

            console.log("DEV_PARAM Repeating setup for", pulseRuntimeSettings.userManualSetName)

            if (pulseRuntimeSettings.devConfigured) {
                console.log("DEV_PARAM no need to repeat as devConfigured complete")
                return
            }
            if (ifSetupCompleted()) {
                return
            }

            /*
            if (pulseRuntimeSettings.onDistSetupChanged
                && pulseRuntimeSettings.onChartSetupChanged
                && pulseRuntimeSettings.onDatasetChanged
                && pulseRuntimeSettings.onTransChanged
                && pulseRuntimeSettings.onDspSetupChanged
                && pulseRuntimeSettings.onSoundChanged)
                {
                    pulseRuntimeSettings.devConfigured = true
                    console.log("DEV_PARAM devConfigured complete")
                    logAllDevSetupAsCompleted()
                    return
            } else {
                console.log("DEV_PARAM devConfigured still incomplete")
            }
            */

            if (!pulseRuntimeSettings.onDistSetupChanged) {
                console.log("DEV_PARAM checking distSetup")
                distSetup()
                if (!pulseRuntimeSettings.onDistSetupChanged) {
                   return
                } else {
                     console.log("DEV_PARAM onDistSetupChanged is OK, let's move on")
                }

            }
            if (!pulseRuntimeSettings.onChartSetupChanged) {
                console.log("DEV_PARAM checking chartSetup")
                chartSetup()
                if (!pulseRuntimeSettings.onChartSetupChanged) {
                   return
                } else {
                     console.log("DEV_PARAM onChartSetupChanged is OK, let's move on")
                }
            }
            if (!pulseRuntimeSettings.onTransChanged) {
                console.log("DEV_PARAM checking transSetup")
                transSetup()
                if (!pulseRuntimeSettings.onTransChanged) {
                   return
                } else {
                     console.log("DEV_PARAM onTransChanged is OK, let's move on")
                }
            }
            if (!pulseRuntimeSettings.onDspSetupChanged) {
                console.log("DEV_PARAM checking dspSetup")
                dspSetup()
                if (!pulseRuntimeSettings.onDspSetupChanged) {
                   return
                } else {
                     console.log("DEV_PARAM onDspSetupChanged is OK, let's move on")
                }
            }
            if (!pulseRuntimeSettings.onSoundChanged) {
                console.log("DEV_PARAM checking soundSetup")
                soundSetup()
                if (!pulseRuntimeSettings.onSoundChanged) {
                   return
                } else {
                     console.log("DEV_PARAM onSoundChanged is OK as, let's move on")
                }
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
        pulseRuntimeSettings.ch1Period_ok = false
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
        //pulseRuntimeSettings.echogramPausedForConfig = false
        pulseRuntimeSettings.devConfigured = false
        pulseRuntimeSettings.dynamicResolutionInit = false
        pulseRuntimeSettings.dynamicResolution = 0
        //Restart the timer
        //completeDeviceConfigurationTimer.start()
    }

    function distSetup () {
        if (dev === null)
            return

        if (pulseRuntimeSettings.onDistSetupChanged)
            return

        // distMax
        if (!pulseRuntimeSettings.distMax_ok) {
            if (dev.distMax === pulseRuntimeSettings.distMax) {
                pulseRuntimeSettings.distMax_Copy = dev.distMax
                pulseRuntimeSettings.distMax_ok = true
                console.log("DEV_PARAM distMax OK as", dev.distMax)
            } else {
                console.log("DEV_PARAM onDistSetupChanged distMax set to", pulseRuntimeSettings.distMax)
                dev.distMax = pulseRuntimeSettings.distMax
                return
            }
        }

        // distDeadZone
        if (!pulseRuntimeSettings.distDeadZone_ok) {
            if (dev.distDeadZone === pulseRuntimeSettings.distDeadZone) {
                pulseRuntimeSettings.distDeadZone_Copy = dev.distDeadZone
                pulseRuntimeSettings.distDeadZone_ok = true
                console.log("DEV_PARAM distDeadZone OK as", dev.distDeadZone)
            } else {
                console.log("DEV_PARAM onDistSetupChanged distDeadZone set to", pulseRuntimeSettings.distDeadZone)
                dev.distDeadZone = pulseRuntimeSettings.distDeadZone
                return
            }
        }

        // distConfidence
        if (!pulseRuntimeSettings.distConfidence_ok) {
            if (dev.distConfidence === pulseRuntimeSettings.distConfidence) {
                pulseRuntimeSettings.distConfidence_Copy = dev.distConfidence
                pulseRuntimeSettings.distConfidence_ok = true
                console.log("DEV_PARAM distConfidence OK as", dev.distConfidence)
            } else {
                console.log("DEV_PARAM onDistSetupChanged distConfidence set to", pulseRuntimeSettings.distConfidence)
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

        if (pulseRuntimeSettings.onChartSetupChanged)
            return

        // chartSamples
        if (!pulseRuntimeSettings.chartSamples_ok) {
            if (dev.chartSamples === pulseRuntimeSettings.chartSamples) {
                pulseRuntimeSettings.chartSamples_Copy = dev.chartSamples
                pulseRuntimeSettings.chartSamples_ok = true
                console.log("DEV_PARAM chartSamples OK as", dev.chartSamples)
            } else {
                console.log("DEV_PARAM onChartSetupChanged, found dev.chartSamples as", dev.chartSamples, " try setting dev.chartSamples set to", pulseRuntimeSettings.chartSamples)
                dev.chartSamples = pulseRuntimeSettings.chartSamples
                return
            }
        }

        // chartResolution
        if (pulseRuntimeSettings.doDynamicResolution) {
            pulseRuntimeSettings.chartResolution_Copy = dev.chartResolution
            pulseRuntimeSettings.chartResolution_ok = true
            console.log("DEV_PARAM chartResolution OK as", dev.chartResolution, ", using dynamic resolution")
        }
        if (!pulseRuntimeSettings.chartResolution_ok) {
            if (dev.chartResolution === pulseRuntimeSettings.chartResolution) {
                pulseRuntimeSettings.chartResolution_Copy = dev.chartResolution
                pulseRuntimeSettings.chartResolution_ok = true
                console.log("DEV_PARAM chartResolution OK as", dev.chartResolution)
            } else {
                //console.log("DEV_PARAM onChartSetupChanged chartResolution set to", pulseRuntimeSettings.chartResolution)
                console.log("DEV_PARAM onChartSetupChanged, found dev.chartResolution as", dev.chartResolution, " try setting dev.chartResolution set to", pulseRuntimeSettings.chartResolution)
                dev.chartResolution = pulseRuntimeSettings.chartResolution
                return
            }
        }

        // chartOffset
        if (!pulseRuntimeSettings.chartOffset_ok) {
            if (dev.chartOffset === pulseRuntimeSettings.chartOffset) {
                pulseRuntimeSettings.chartOffset_Copy = dev.chartOffset
                pulseRuntimeSettings.chartOffset_ok = true
                console.log("DEV_PARAM chartOffset OK as", dev.chartOffset)
            } else {
                console.log("DEV_PARAM onChartSetupChanged, found dev.chartOffset as", dev.chartOffset, " try setting dev.chartOffset set to", pulseRuntimeSettings.chartOffset)
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

        if (pulseRuntimeSettings.onDatasetChanged){
            console.log("DEV_PARAM onDatasetChanged OK")
            console.log("DEV_PARAM ch1Period_Copy OK as", dev.ch1Period)
            console.log("DEV_PARAM datasetChart OK as", dev.datasetChart)
            console.log("DEV_PARAM datasetDist OK as", dev.datasetDist)
            console.log("DEV_PARAM datasetSDDBT OK as", dev.datasetSDDBT)
            console.log("DEV_PARAM datasetEuler OK as", dev.datasetEuler)
            console.log("DEV_PARAM datasetTemp OK as", dev.datasetTemp)
            console.log("DEV_PARAM datasetTimestamp OK as", dev.datasetTimestamp)
            return
        }

        // ch1Period
        if (!pulseRuntimeSettings.ch1Period_ok) {
            if (dev.ch1Period === pulseRuntimeSettings.ch1Period) {
                pulseRuntimeSettings.ch1Period_Copy = dev.ch1Period
                pulseRuntimeSettings.ch1Period_ok = true
                console.log("DEV_PARAM ch1Period OK as", dev.ch1Period)
            } else {
                console.log("DEV_PARAM onDatasetChanged ch1Period set to", pulseRuntimeSettings.ch1Period)
                dev.ch1Period = pulseRuntimeSettings.ch1Period
                return
            }
        }

        // datasetChart
        if (!pulseRuntimeSettings.datasetChart_ok) {
            if (dev.datasetChart === pulseRuntimeSettings.datasetChart) {
                pulseRuntimeSettings.datasetChart_Copy = dev.datasetChart
                pulseRuntimeSettings.datasetChart_ok = true
                console.log("DEV_PARAM datasetChart OK as", dev.datasetChart)
            } else {
                console.log("DEV_PARAM onDatasetChanged datasetChart set to", pulseRuntimeSettings.datasetChart)
                dev.datasetChart = pulseRuntimeSettings.datasetChart
                return
            }
        }

        // datasetDist
        if (!pulseRuntimeSettings.datasetDist_ok) {
            if (dev.datasetDist === pulseRuntimeSettings.datasetDist) {
                pulseRuntimeSettings.datasetDist_Copy = dev.datasetDist
                pulseRuntimeSettings.datasetDist_ok = true
                console.log("DEV_PARAM datasetDist OK as", dev.datasetDist)
            } else {
                console.log("DEV_PARAM onDatasetChanged datasetDist set to", pulseRuntimeSettings.datasetDist)
                dev.datasetDist = pulseRuntimeSettings.datasetDist
                return
            }
        }

        // datasetSDDBT
        if (!pulseRuntimeSettings.datasetSDDBT_ok) {
            if (dev.datasetSDDBT === pulseRuntimeSettings.datasetSDDBT) {
                pulseRuntimeSettings.datasetSDDBT_Copy = dev.datasetSDDBT
                pulseRuntimeSettings.datasetSDDBT_ok = true
                console.log("DEV_PARAM datasetSDDBT OK as", dev.datasetSDDBT)
            } else {
                console.log("DEV_PARAM onDatasetChanged datasetSDDBT set to", pulseRuntimeSettings.datasetSDDBT)
                dev.datasetSDDBT = pulseRuntimeSettings.datasetSDDBT
                return
            }
        }

        // datasetEuler
        if (!pulseRuntimeSettings.datasetEuler_ok) {
            if (dev.datasetEuler === pulseRuntimeSettings.datasetEuler) {
                pulseRuntimeSettings.datasetEuler_Copy = dev.datasetEuler
                pulseRuntimeSettings.datasetEuler_ok = true
                console.log("DEV_PARAM datasetEuler OK as", dev.datasetEuler)
            } else {
                console.log("DEV_PARAM onDatasetChanged datasetEuler set to", pulseRuntimeSettings.datasetEuler)
                dev.datasetEuler = pulseRuntimeSettings.datasetEuler
                return
            }
        }

        // datasetTemp
        if (!pulseRuntimeSettings.datasetTemp_ok) {
            if (dev.datasetTemp === pulseRuntimeSettings.datasetTemp) {
                pulseRuntimeSettings.datasetTemp_Copy = dev.datasetTemp
                pulseRuntimeSettings.datasetTemp_ok = true
                console.log("DEV_PARAM datasetTemp OK as", dev.datasetTemp)
            } else {
                console.log("DEV_PARAM onDatasetChanged datasetTemp set to", pulseRuntimeSettings.datasetTemp)
                dev.datasetTemp = pulseRuntimeSettings.datasetTemp
                return
            }
        } else {
            console.log("DEV_PARAM datasetTemp OK as", dev.datasetTemp)
        }

        // datasetTimestamp
        if (!pulseRuntimeSettings.datasetTimestamp_ok) {
            if (dev.datasetTimestamp === pulseRuntimeSettings.datasetTimestamp) {
                pulseRuntimeSettings.datasetTimestamp_Copy = dev.datasetTimestamp
                pulseRuntimeSettings.datasetTimestamp_ok = true
                console.log("DEV_PARAM datasetTimestamp OK as", dev.datasetTimestamp)
            } else {
                console.log("DEV_PARAM onDatasetChanged datasetTimestamp set to", pulseRuntimeSettings.datasetTimestamp)
                dev.datasetTimestamp = pulseRuntimeSettings.datasetTimestamp
                return
            }
        }

        // Verify all
        if (pulseRuntimeSettings.datasetTimestamp_ok
                && pulseRuntimeSettings.ch1Period_ok
                && pulseRuntimeSettings.datasetTemp_ok
                && pulseRuntimeSettings.datasetEuler_ok
                && pulseRuntimeSettings.datasetDist_ok
                && pulseRuntimeSettings.datasetSDDBT_ok) {
            pulseRuntimeSettings.onDatasetChanged = true
            console.log("DEV_PARAM onDatasetChanged complete, happy with everything")
        }
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

    Timer {
        id: turnOffConfiguringEchosounderMessageTimer
        repeat: false
        interval: 200
        onTriggered: {
            pulseRuntimeSettings.echogramPausedForConfig = false
        }
    }

    function datasetChartSetup () {
        if (dev === null)
            return
        // datasetChart
        if (!pulseRuntimeSettings.datasetChart_ok) {

            if (dev.datasetChart === "1") {
            //if (dev.datasetChart === pulseRuntimeSettings.datasetChart) {
                pulseRuntimeSettings.datasetChart_ok = true
                turnOffConfiguringEchosounderMessageTimer.start()
                logAllDevSetupAsCompleted()
                //console.log("DEV_PARAM datasetChart OK as", dev.datasetChart)
            } else {
                pulseRuntimeSettings.datasetChart = "1"
                //dev.datasetChart = pulseRuntimeSettings.datasetChart
                //console.log("DEV_PARAM onDatasetChanged datasetChart set to", pulseRuntimeSettings.datasetChart)
                return
            }
            /*
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
            */
        }
    }

    function transSetup () {
        if (dev === null)
            return

        if (pulseRuntimeSettings.onTransChanged)
            return

        // transFreq
        if (!pulseRuntimeSettings.transFreq_ok) {
            if (dev.transFreq === pulseRuntimeSettings.transFreq) {
                pulseRuntimeSettings.transFreq_Copy = dev.transFreq
                pulseRuntimeSettings.transFreq_ok = true
                console.log("DEV_PARAM transFreq OK as", dev.transFreq)
            } else {
                console.log("DEV_PARAM onTransChanged transFreq set to", pulseRuntimeSettings.transFreq)
                dev.transFreq = pulseRuntimeSettings.transFreq
                return
            }
        }

        // transPulse
        if (!pulseRuntimeSettings.transPulse_ok) {
            if (dev.transPulse === pulseRuntimeSettings.transPulse) {
                pulseRuntimeSettings.transPulse_Copy = dev.transPulse
                pulseRuntimeSettings.transPulse_ok = true
                console.log("DEV_PARAM transPulse OK as", dev.transPulse)
            } else {
                console.log("DEV_PARAM onTransChanged transPulse set to", pulseRuntimeSettings.transPulse)
                dev.transPulse = pulseRuntimeSettings.transPulse
                return
            }
        }

        // transBoost
        if (!pulseRuntimeSettings.transBoost_ok) {
            if (dev.transBoost === pulseRuntimeSettings.transBoost) {
                pulseRuntimeSettings.transBoost_Copy = dev.transBoost
                pulseRuntimeSettings.transBoost_ok = true
                console.log("DEV_PARAM transBoost OK as", dev.transBoost)
            } else {
                console.log("DEV_PARAM onTransChanged transBoost set to", pulseRuntimeSettings.transBoost)
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
            console.log("DEV_PARAM onDspSetupChanged override to ", pulseRuntimeSettings.onDspSetupChanged)
            return
        }

        if (dev === null)
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

        if (pulseRuntimeSettings.onSoundChanged)
            return

        // soundSpeed
        if (!pulseRuntimeSettings.soundSpeed_ok) {
            if (dev.soundSpeed === pulseRuntimeSettings.soundSpeed) {
                pulseRuntimeSettings.soundSpeed_Copy = dev.soundSpeed
                pulseRuntimeSettings.soundSpeed_ok = true
                console.log("DEV_PARAM soundSpeed OK as", dev.soundSpeed)
            } else {
                console.log("DEV_PARAM onSoundChanged soundSpeed set to", pulseRuntimeSettings.soundSpeed)
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
        console.log("DEV_PARAM_COMPLETE: ch1Period is ", dev.ch1Period)
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
            pulseRuntimeSettings.dynamicResolutionInit = true
            /*
            if (dev.chartResolution !== pulseRuntimeSettings.chartResolution) {
                pulseRuntimeSettings.forceUpdateResolution = true
                //dev.chartResolution = pulseRuntimeSettings.chartResolution
                //console.log("DEV_PARAM_COMPLETE: dev.chartResolution incorrect, set to ", pulseRuntimeSettings.chartResolution)
            }
            pulseRuntimeSettings.dynamicResolutionInit = true
            */
        }

        if (dev !== null) {
            pulseRuntimeSettings.rawDev_devName = dev.devName
            pulseRuntimeSettings.rawDev_devType = dev.devType
            pulseRuntimeSettings.rawDev_isSonar = dev.isSonar
            pulseRuntimeSettings.rawDev_isChartSupport = dev.isChartSupport
            pulseRuntimeSettings.rawDev_isDistSupport = dev.isDistSupport
            pulseRuntimeSettings.rawDev_isTransducerSupport = dev.isTransducerSupport
            pulseRuntimeSettings.rawDev_isDatasetSupport = dev.isDatasetSupport
            pulseRuntimeSettings.rawDev_isSoundSpeedSupport = dev.isSoundSpeedSupport
            pulseRuntimeSettings.rawDev_isUpgradeSupport = dev.isUpgradeSupport
        }

        if (pulseRuntimeSettings.userManualSetName !== "...") {
            if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed
                    || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto) {
                let desiredFrequency = 0
                if (PulseSettings.ecoConeIndex === 0) {
                    desiredFrequency = pulseRuntimeSettings.transFreqWide
                    console.log("DEV_PARAM: use frequency for pulse red wide")
                } else if (PulseSettings.ecoConeIndex === 1) {
                    desiredFrequency = pulseRuntimeSettings.transFreqMedium
                    console.log("DEV_PARAM: use frequency for pulse red metium")
                } else {
                    desiredFrequency = pulseRuntimeSettings.transFreqNarrow
                    console.log("DEV_PARAM: use frequency for pulse red narrow")
                }

                pulseRuntimeSettings.transFreq = desiredFrequency

            } else {
                //Pulse Blue
                pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqMedium
                //doBottomTracking()
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
        target: dataset ? dataset : undefined
        function onChannelsUpdated () {
            datasetChannelCounter.restart()
        }
    }

    Connections {
        target: PulseSettings
        function onIsSideScanCableFacingFrontChanged () {
            console.log("Side scan: onIsSideScanCableFacingFrontChanged observed")
            setPlotPulseBlue()
        }
    }


    Connections {
        target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined

        function onEchogramPausedForConfigChanged () {
            if (pulseRuntimeSettings.echogramPausedForConfig) {
                turnOffConfiguringEchosounderMessageTimer.start()
            }
        }

        function onEchoSounderRebootChanged () {
            if (pulseRuntimeSettings.echoSounderReboot) {
                if (dev === null)
                    return
                if (dev.devName === "...")
                    return
                dev.reboot()
                resetAllSetupStates()
                //pulseRuntimeSettings.userManualSetName = "..."
                pulseRuntimeSettings.echoSounderReboot = false
            }
        }

        function onUserManualSetNameChanged () {
            if (pulseRuntimeSettings.userManualSetName !== "...") {
                console.log("DEV_PARAM: onUserManualSetNameChanged observed, now we configure the device")
                configurePulseDevice()
            } else {
                console.log("DEV_PARAM: onUserManualSetNameChanged observed, but devName is ... so nothing will happen")
            }
        }

        function onSwapDeviceNowChanged () {
            if (pulseRuntimeSettings.swapDeviceNow) {
                pulseRuntimeSettings.didEverReceiveData = false
                pulseRuntimeSettings.hasDeviceLostConnection = false
                resetAllSetupStates()
                pulseRuntimeSettings.pulseBetaName = "..."
                pulseRuntimeSettings.userManualSetName = "..."
                //pulseRuntimeSettings.devName = "..."
                pulseRuntimeSettings.devDetected = false
                pulseRuntimeSettings.devIdentified = false
                pulseRuntimeSettings.devConfigured = false
                pulseRuntimeSettings.devSettingsEnforced = false
                pulseRuntimeSettings.appConfigured = false
                pulseRuntimeSettings.numberOfDatasetChannels = 0
                pulseRuntimeSettings.forceUpdateResolution = true
                pulseRuntimeSettings.pulseBlueResSetOnce = false
                pulseRuntimeSettings.doDynamicResolution = false
                pulseRuntimeSettings.swapDeviceNow = false
                //settingsCompleted = false
                //deviceIdentified = false
                //delayTimer.start()
                console.log("DEV_RESELECT now we want to re-select the device in deviceItem")
            } else {
                console.log("DEV_RESELECT swapDeviceNow is", pulseRuntimeSettings.swapDeviceNow)
            }
        }

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

        /*TODO - This is likely not needed!
        function onTransFreqChanged() {
            if (dev !== null)
                dev.transFreq = pulseRuntimeSettings.transFreq
            //console.log("DEV_CONFIG: separateMethod onTransFreqChanged new frequency is", dev.transFreq);
        }
        */
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
    }

    // Connections to detect the live data feed is still alive

    Connections {
        target: dataset ? dataset : undefined
        //Dataupdate is triggered by receiving data from transducer, but will also be triggered by loading a KLF file
        //Data update restarts the lostConnectionTimer to avoid it being triggered
        function onDataUpdate () {
            lostConnectionTimer.restart();
            if (!pulseRuntimeSettings.devSettingsEnforced) {
                pulseRuntimeSettings.devSettingsEnforced = true
                //configurePulseDevice()
            }
            if (pulseRuntimeSettings.pulseBetaName === "..." && pulseRuntimeSettings.devName === "ECHO20") {
                if (pulseRuntimeSettings.numberOfDatasetChannels === 1) {
                    pulseRuntimeSettings.pulseBetaName = pulseRuntimeSettings.pulseRedBeta
                }
                if (pulseRuntimeSettings.numberOfDatasetChannels === 2) {
                    pulseRuntimeSettings.pulseBetaName = pulseRuntimeSettings.pulseBlueBeta
                }
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
        //setPlotGeneral()
        //pickDev()
        //delayTimer.start()
    }
}
