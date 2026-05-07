import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

//import Qt.labs.settings 1.1
import QtQuick.Dialogs



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
            /*
            if (dev.devName === null) {
                console.log("DEV_PARAM onDeviceVersionChanged, but devName was null. Aborting.")
                return
            }
            */

            if (pulseRuntimeSettings.devName === "..." && !pulseRuntimeSettings.devConfigured) {
            //if (dev.devName === "..." && !pulseRuntimeSettings.devConfigured) {
                //console.log("DEV_PARAM onDeviceVersionChanged, but devName was ", pulseRuntimeSettings.devName, ". Aborting.")
                return
            }

            if (pulseRuntimeSettings.wasKlfFileOpened) {
                //console.log("DEV_PARAM onDeviceVersionChanged, we do not want to reconfigure the device if we just opened a file")
                return
            }

            if (pulseRuntimeSettings.devName === "..." && pulseRuntimeSettings.devConfigured) {
            //if (dev.devName === "..." && pulseRuntimeSettings.devConfigured) {
                console.log("DEV_PARAM onDeviceVersionChanged, devName ... but device was already configured. Must have lost connection. Reset state")
                resetAllSetupStates()
                pulseRuntimeSettings.onDeviceVersionChanged = false;
                pulseRuntimeSettings.devConfigured = false;
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

            //Abort if already OK
            if (pulseRuntimeSettings.onDistSetupChanged)
                return

            // TODO: Safe to disable this?
            /*
            if (true)
                return

            //Check if settings are OK
            if (!pulseRuntimeSettings.distMax_ok) {
                if (dev.distMax !== pulseRuntimeSettings.distMax) {
                    pulseRuntimeSettings.distMax_ok = false
                    pulseRuntimeSettings.onDistSetupChanged = false
                    console.log("DEV_PARAM onDistSetupChanged, found deviation for dev.distMax", dev.distMax)
                } else {
                    pulseRuntimeSettings.distMax_ok = true
                }
            }

            if (!pulseRuntimeSettings.distDeadZone_ok) {
                if (dev.distDeadZone !== pulseRuntimeSettings.distDeadZone) {
                    pulseRuntimeSettings.distDeadZone_ok = false
                    pulseRuntimeSettings.onDistSetupChanged = false
                    console.log("DEV_PARAM onDistSetupChanged, found deviation for dev.distDeadZone", dev.distDeadZone)
                } else {
                    pulseRuntimeSettings.distDeadZone_ok = true
                }
            }

            if (!pulseRuntimeSettings.distConfidence_ok) {
                if (dev.distConfidence !== pulseRuntimeSettings.distConfidence) {
                    pulseRuntimeSettings.distConfidence_ok = false
                    pulseRuntimeSettings.onDistSetupChanged = false
                    console.log("DEV_PARAM onDistSetupChanged, found deviation for dev.distConfidence", dev.distConfidence)
                } else {
                    pulseRuntimeSettings.distConfidence_ok = true
                }
            }
            */

            //Redo settings if needed
            /*
            if (!pulseRuntimeSettings.onDistSetupChanged) {
                console.log("DEV_PARAM onDistSetupChanged, found deviation - run chartSetup")
                distSetup()
            }
            */
        }

        function onChartSetupChanged () {
            if (pulseRuntimeSettings.userManualSetName === "...")
                return

            //For expert review screen
            pulseRuntimeSettings.chartResolution_Copy = dev.chartResolution
            pulseRuntimeSettings.chartSamples_Copy = dev.chartSamples
            pulseRuntimeSettings.chartOffset_Copy = dev.chartOffset

            //Abort if already OK
            if (pulseRuntimeSettings.onChartSetupChanged)
                return

            // TODO: Safe to disable this?
            /*

            if (true)
                return

            //Check if settings are OK
            if (!pulseRuntimeSettings.chartResolution_ok) {
                if (dev.chartResolution !== pulseRuntimeSettings.chartResolution) {
                    if (pulseRuntimeSettings.doDynamicResolution) {
                        pulseRuntimeSettings.chartResolution_ok = true
                        console.log("DEV_PARAM onChartSetupChanged, dev.chartResolution OK as", dev.chartResolution, "using doDynamicResolution")
                    } else {
                        pulseRuntimeSettings.chartResolution_ok = false
                        pulseRuntimeSettings.onChartSetupChanged = false
                        console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.chartResolution", dev.chartResolution)
                    }
                }
            }

            if (!pulseRuntimeSettings.chartSamples_ok) {
                if (dev.chartSamples !== pulseRuntimeSettings.chartSamples) {
                    pulseRuntimeSettings.chartSamples_ok = false
                    pulseRuntimeSettings.onChartSetupChanged = false
                    console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.chartSamples", dev.chartSamples)
                } else {
                    pulseRuntimeSettings.chartSamples_ok = true
                }
            }

            if (!pulseRuntimeSettings.chartOffset_ok) {
                if (dev.chartOffset !== pulseRuntimeSettings.chartOffset) {
                    pulseRuntimeSettings.chartOffset_ok = false
                    pulseRuntimeSettings.onChartSetupChanged = false
                    console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.chartOffset", dev.chartOffset)
                } else {
                    pulseRuntimeSettings.chartOffset_ok = true
                }
            }
            */


            //Redo settings if needed
            /*
            if (!pulseRuntimeSettings.onChartSetupChanged) {
                console.log("DEV_PARAM onChartSetupChanged, found deviation - run chartSetup")
                chartSetup()
            }
            */
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

            //Abort if already OK
            if (pulseRuntimeSettings.onDatasetChanged)
                return

            // TODO: Safe to disable this?
            /*

            if (true)
                return

            //Check if settings are OK
            if (!pulseRuntimeSettings.ch1Period_ok) {
                if (dev.ch1Period !== pulseRuntimeSettings.ch1Period) {
                    pulseRuntimeSettings.ch1Period_ok = false
                    pulseRuntimeSettings.onDatasetChanged = false
                    console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.ch1Period", dev.ch1Period)
                } else {
                    pulseRuntimeSettings.ch1Period_ok = true
                }
            }

            if (!pulseRuntimeSettings.datasetChart_ok) {
                if (dev.datasetChart !== pulseRuntimeSettings.datasetChart) {
                    pulseRuntimeSettings.datasetChart_ok = false
                    pulseRuntimeSettings.onDatasetChanged = false
                    console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.datasetChart", dev.datasetChart)
                } else {
                    pulseRuntimeSettings.datasetChart_ok = true
                }
            }

            if (!pulseRuntimeSettings.datasetDist_ok) {
                if (dev.datasetDist !== pulseRuntimeSettings.datasetDist) {
                    pulseRuntimeSettings.datasetDist_ok = false
                    pulseRuntimeSettings.onDatasetChanged = false
                    console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.datasetDist", dev.datasetDist)
                } else {
                    pulseRuntimeSettings.datasetDist_ok = true
                }
            }

            if (!pulseRuntimeSettings.datasetSDDBT_ok) {
                if (dev.datasetSDDBT !== pulseRuntimeSettings.datasetSDDBT) {
                    pulseRuntimeSettings.datasetSDDBT_ok = false
                    pulseRuntimeSettings.onDatasetChanged = false
                    console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.datasetSDDBT", dev.datasetSDDBT)
                } else {
                    pulseRuntimeSettings.datasetSDDBT_ok = true
                }
            }

            if (!pulseRuntimeSettings.datasetEuler_ok) {
                if (dev.datasetEuler !== pulseRuntimeSettings.datasetEuler) {
                    pulseRuntimeSettings.datasetEuler_ok = false
                    pulseRuntimeSettings.onDatasetChanged = false
                    console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.datasetEuler", dev.datasetEuler)
                } else {
                    pulseRuntimeSettings.datasetEuler_ok = true
                }
            }

            if (!pulseRuntimeSettings.datasetTemp_ok) {
                if (dev.datasetTemp !== pulseRuntimeSettings.datasetTemp) {
                    pulseRuntimeSettings.datasetTemp_ok = false
                    pulseRuntimeSettings.onDatasetChanged = false
                    console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.datasetTemp", dev.datasetTemp)
                } else {
                    pulseRuntimeSettings.datasetTemp_ok = true
                }
            }

            if (!pulseRuntimeSettings.datasetTimestamp_ok) {
                if (dev.datasetTimestamp !== pulseRuntimeSettings.datasetTimestamp) {
                    pulseRuntimeSettings.datasetTimestamp_ok = false
                    pulseRuntimeSettings.onDatasetChanged = false
                    console.log("DEV_PARAM onChartSetupChanged, found deviation for dev.datasetTimestamp", dev.datasetTimestamp)
                } else {
                    pulseRuntimeSettings.datasetTimestamp_ok = true
                }
            }

            */

            //Redo settings if needed
            /*
            if (!pulseRuntimeSettings.onDatasetChanged) {
                console.log("DEV_PARAM onChartSetupChanged, found deviation - run datasetSetup")
                datasetSetup()
            }
            */

        }

        function onTransChanged () {
            if (pulseRuntimeSettings.userManualSetName === "...")
                return

            //For expert review screen
            pulseRuntimeSettings.transPulse_Copy = dev.transPulse
            pulseRuntimeSettings.transFreq_Copy = dev.transFreq
            pulseRuntimeSettings.transBoost_Copy = dev.transBoost

            //Abort if already OK
            if (pulseRuntimeSettings.onTransChanged)
                return

            // TODO: Safe to disable this?
            /*

            if (true)
                return

            //Check if settings are OK
            if (!pulseRuntimeSettings.transPulse_ok) {
                if (dev.transPulse !== pulseRuntimeSettings.transPulse) {
                    pulseRuntimeSettings.transPulse_ok = false
                    pulseRuntimeSettings.onTransChanged = false
                    console.log("DEV_PARAM onTransChanged, found deviation for dev.transPulse", dev.transPulse)
                } else {
                    pulseRuntimeSettings.transPulse_ok = true
                }
            }

            if (!pulseRuntimeSettings.transFreq_ok) {
                if (dev.transFreq !== pulseRuntimeSettings.transFreq) {
                    pulseRuntimeSettings.transFreq_ok = false
                    pulseRuntimeSettings.onTransChanged = false
                    console.log("DEV_PARAM onTransChanged, found deviation for dev.transFreq", dev.transFreq)
                } else {
                    pulseRuntimeSettings.transFreq_ok = true
                }
            }

            if (!pulseRuntimeSettings.transBoost_ok) {
                if (dev.transBoost !== pulseRuntimeSettings.transBoost) {
                    pulseRuntimeSettings.transBoost_ok = false
                    pulseRuntimeSettings.onTransChanged = false
                    console.log("DEV_PARAM onTransChanged, found deviation for dev.transBoost", dev.transBoost)
                } else {
                    pulseRuntimeSettings.transBoost_ok = true
                }
            }

            */
            //Redo settings if needed
            /*
            if (!pulseRuntimeSettings.onTransChanged) {
                console.log("DEV_PARAM onTransChanged, found deviation - run transSetup")
                transSetup()
            }
            */
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

            //Abort if already OK
            if (pulseRuntimeSettings.onSoundChanged)
                return

            // TODO: Safe to disable this?
            /*
            if (true)
                return

            //Check if settings are OK
            if (!pulseRuntimeSettings.soundSpeed_ok) {
                if (dev.soundSpeed !== pulseRuntimeSettings.soundSpeed) {
                    pulseRuntimeSettings.soundSpeed_ok = false
                    pulseRuntimeSettings.onSoundChanged = false
                    console.log("DEV_PARAM onSoundChanged, found deviation for dev.soundSpeed", dev.soundSpeed)
                }  else {
                    pulseRuntimeSettings.soundSpeed_ok = true
                }
            }

            */

            //Redo settings if needed
            /*
            if (!pulseRuntimeSettings.onSoundChanged) {
                console.log("DEV_PARAM onSoundChanged, found deviation - run soundSetup")
                soundSetup()
            }
            */
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

    function safeNum(val, fallback) {
        return (val === undefined || val === null) ? fallback : val
    }

    function safeBool(val) {
        return val === true
    }

    ParamGroup {
        groupName: qsTr("Echogram")

        ParamSetup {
            paramName: qsTr("Resolution, mm")

            SpinBoxCustom {
                from: 10
                to: 100
                stepSize: 10
                value: 0

                devValue: 0

                /*
                devValue: {
                    if (dev !== null && pulseRuntimeSettings !== null) {
                        if (pulseRuntimeSettings.doDynamicResolution) {
                            console.log("DEV_PARAM: chartResolution as devValue should be ", pulseRuntimeSettings.dynamicResolution), " by doDynamicResolution";
                            return pulseRuntimeSettings.dynamicResolution
                        } else {
                            console.log("DEV_PARAM: chartResolution as devValue should be", pulseRuntimeSettings.chartResolution, "for", pulseRuntimeSettings.devName);
                            return pulseRuntimeSettings.chartResolution
                        }
                    } else {
                        console.log("DEV_PARAM: dev is null, resolution is 0 for now");
                        return 0
                    }
                }
                */

                //isValid: dev !== null ? dev.chartSetupState : false

                //devValue: safeNum(dev && dev.chartResolution, 0)
                isValid: safeBool(dev && dev.chartSetupState)

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
                        console.log("DEV_PARAM: onDynamicResolutionChanged")
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
                            if (pulseRuntimeSettings.devName !== "...") {
                            //if (dev.devName !== "...") {
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
                devValue: 0

                //devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.chartSamples : 0

                isValid: safeBool(dev && dev.chartSetupState)

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
                                //console.log("DYNAMIC: Set the dev.chartSamples to ", dev.chartSamples, " using source pulseRuntimeSettings.chartSamples of ", pulseRuntimeSettings.chartSamples)
                            }
                        }
                    }
                    function onDynamicSamplesChanged () {
                        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue) {
                            return
                        }
                        pulseRuntimeSettings.chartSamples = pulseRuntimeSettings.dynamicSamples
                        //console.log("DYNAMIC: received onDynamicSamplesChanged value ", pulseRuntimeSettings.dynamicSamples)
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

                devValue: 0
                /*
                devValue: {
                    if (dev !== null && pulseRuntimeSettings !== null) {
                        console.log("DEV_PARAM: chartOffset as devValue set to ", pulseRuntimeSettings.chartOffset);
                        return pulseRuntimeSettings.chartResolution
                    } else {
                        console.log("DEV_PARAM: dev is null, offset is 0 for now");
                        return 0
                    }
                }
                */

                isValid: safeBool(dev && dev.chartSetupState)

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

                devValue: 0
                //devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.distMax : 0

                isValid: safeBool(dev && dev.distSetupState)

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

                devValue: 0
                //devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.distDeadZone : 0

                //isValid: dev !== null ? dev.distSetupState : false

                //devValue: safeNum(dev && dev.distDeadZone, 0)
                isValid: safeBool(dev && dev.distSetupState)

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

                devValue: 0
                //devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.distConfidence : 0

                isValid: safeBool(dev && dev.distSetupState)

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

                devValue: 0
                //devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.transPulse : 0

                isValid: safeBool(dev && dev.transcState)

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

                devValue: 0
                //devValue: pulseRuntimeSettings.transFreq

                isValid: safeBool(dev && dev.transcState)

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

                devValue: 0
                //devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.transBoost : 0

                isValid: safeBool(dev && dev.transcState)

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

                validator: RegularExpressionValidator {
                    regularExpression: new RegExp(spinBoxBooster ? spinBoxBooster.regExpPattern : "(Off|On)", "i")
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

                devValue: 0
                //devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.dspHorSmooth : 0

                isValid: safeBool(dev && dev.dspState)


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

                devValue: 0
                //devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.soundSpeed / 1000 : 0

                isValid: safeBool(dev && dev.soundState)


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

                devValue: 0
                //devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.ch1Period : 0

                isValid: safeBool(dev && dev.datasetState)

                onValueChanged: {
                    if (!isDriverChanged) {
                        if (dev === null)
                            return
                        //pulseRuntimeSettings.ch1Period = value
                        //console.log("DYNAMIC: Set the dev.ch1Period to ", dev.ch1Period, " onValueChanged ", value)
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
                                //console.log("DYNAMIC: Set the dev.ch1Period to ", dev.ch1Period, " using source pulseRuntimeSettings.ch1Period of ", pulseRuntimeSettings.ch1Period)
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

                devValue: 0
                //devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.datasetChart : 0

                isValid: safeBool(dev && dev.datasetState)

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

                        if (value === 1) {
                            //dev.datasetChart = 1
                        }
                        else {
                            //dev.datasetChart = 0

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

                devValue: 0
                //devValue: (dev !== null && pulseRuntimeSettings !== null) ? (pulseRuntimeSettings.datasetDist === 1 ? 1 : pulseRuntimeSettings.datasetSDDBT === 1 ? 2 : 0) : 0

                isValid: safeBool(dev && dev.datasetState)

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

                        if (value === 1) {
                            //dev.datasetDist = 1
                        }
                        else if (value === 2) {
                            //dev.datasetSDDBT = 1

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

                devValue: 0
                //devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.datasetEuler : 0

                isValid: safeBool(dev && dev.datasetState)

                onValueChanged: {
                    if (!isDriverChanged) {
                        if (value === 1) {
                            //dev.datasetEuler = 1

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

                devValue: 0
                //devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.datasetTemp : 0

                isValid: safeBool(dev && dev.datasetState)

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

                        if(value === 1) {
                            //dev.datasetTemp = 1
                        }
                        else if (dev.datasetTemp & 1) {
                            //dev.datasetTemp = 0

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

                devValue: 0
                //devValue: (dev !== null && pulseRuntimeSettings !== null) ? pulseRuntimeSettings.datasetTimestamp : 0

                isValid: safeBool(dev && dev.datasetState)

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

                        if (value === 1) {
                            //dev.datasetTimestamp = 1
                        }
                        else if (dev.datasetTimestamp & 1) {
                            //dev.datasetTimestamp = 0

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

    function configurePulseDevice () {

        if (pulseRuntimeSettings.wasKlfFileOpened){
            console.log("DEV_PARAM: We just opened a file and do not want to setup the app once more")
            return
        }

        //Disable the echogram before any parameters are changed;
        console.log("DEV_PARAM: disable echogram")
        dev.datasetChart = 0

        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed
                || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto) {
            console.log("DEV_PARAM: pulseRuntimeSettings - cone for", pulseRuntimeSettings.userManualSetName)
            if (pulseSettings.ecoConeIndex === 0) {
                pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqWide
                console.log("DEV_PARAM: pulse red wide")
            } else if (pulseSettings.ecoConeIndex === 1) {
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
            //console.log("DEV_PARAM deviceParameterSetterRepeat")
            if (pulseRuntimeSettings.wasKlfFileOpened)
                return
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

            /*
            if (pulseRuntimeSettings.devConfigured) {
                console.log("DEV_PARAM no need to repeat as devConfigured complete")
                return
            }
            */

            if (ifSetupCompleted()) {
                return
            }
            if (!pulseRuntimeSettings.echogramPausedForConfig) {
                console.log("DEV_PARAM echogram not paused, let's do this first")
                disableEchogram()
                return
            } else {
                console.log("DEV_PARAM echogram is paused, let's move on")
            }
            if (dev.datasetChart === 1 && !pulseRuntimeSettings.echogramEnabledByConfig) {
                console.log("DEV_PARAM something turned on the echogram before we were ready, let us pause it again")
                disableEchogram()
                return
            }

            //Speed up by detecting the actual difference between profile and the actual device
            //preCheckParameters()

            if (!pulseRuntimeSettings.onDistSetupChanged) {
                console.log("DEV_PARAM checking distSetup")
                distSetup()
                if (!pulseRuntimeSettings.onDistSetupChanged) {
                   return
                } else {
                     console.log("DEV_PARAM onDistSetupChanged is OK, let's move on")
                }
            } else {
                console.log("DEV_PARAM all OK distSetup")
            }

            if (!pulseRuntimeSettings.onChartSetupChanged) {
                console.log("DEV_PARAM checking chartSetup")
                chartSetup()
                if (!pulseRuntimeSettings.onChartSetupChanged) {
                   return
                } else {
                     console.log("DEV_PARAM onChartSetupChanged is OK, let's move on")
                }
            } else {
                console.log("DEV_PARAM all OK chartSetup")
            }
            if (!pulseRuntimeSettings.onTransChanged) {
                console.log("DEV_PARAM checking transSetup")
                transSetup()
                if (!pulseRuntimeSettings.onTransChanged) {
                   return
                } else {
                     console.log("DEV_PARAM onTransChanged is OK, let's move on")
                }
            } else {
                console.log("DEV_PARAM all OK transSetup")
            }
            if (!pulseRuntimeSettings.onDspSetupChanged) {
                console.log("DEV_PARAM checking dspSetup")
                dspSetup()
                if (!pulseRuntimeSettings.onDspSetupChanged) {
                   return
                } else {
                     console.log("DEV_PARAM onDspSetupChanged is OK, let's move on")
                }
            } else {
                console.log("DEV_PARAM all OK dspSetup")
            }
            if (!pulseRuntimeSettings.onSoundChanged) {
                console.log("DEV_PARAM checking soundSetup")
                soundSetup()
                if (!pulseRuntimeSettings.onSoundChanged) {
                   return
                } else {
                     console.log("DEV_PARAM onSoundChanged is OK as, let's move on")
                }
            } else {
                console.log("DEV_PARAM all OK soundSetup")
            }
            if (!pulseRuntimeSettings.onDatasetChanged) {
                console.log("DEV_PARAM checking datasetSetup")
                datasetSetup()
                return
            } else {
                console.log("DEV_PARAM all OK datasetSetup")
            }

        }
    }

    function resetAllSetupStates () {
        console.log("DEV_PARAM Lost connection, setup is suspicious, let's reset!")
        //Parameters
        //DISTANCE
        pulseRuntimeSettings.distMax_ok = false
        pulseRuntimeSettings.distDeadZone_ok = false //Why was this disabled?
        pulseRuntimeSettings.distConfidence_ok = false //Why was this disabled?
        //CHART
        pulseRuntimeSettings.chartSamples_ok = false
        pulseRuntimeSettings.chartResolution_ok = false
        pulseRuntimeSettings.chartOffset_ok = false
        //DATASET
        pulseRuntimeSettings.ch1Period_ok = false
        pulseRuntimeSettings.datasetDist_ok = false
        pulseRuntimeSettings.datasetSDDBT_ok = false
        pulseRuntimeSettings.datasetEuler_ok = false //Why was this disabled?
        pulseRuntimeSettings.datasetTemp_ok = false
        pulseRuntimeSettings.datasetTimestamp_ok = false //Why was this disabled?
        pulseRuntimeSettings.datasetChart_ok = false
        //TRANSDUCER
        pulseRuntimeSettings.transFreq_ok = false
        pulseRuntimeSettings.transPulse_ok = false
        pulseRuntimeSettings.transBoost_ok = false
        //DISABLED
        //pulseRuntimeSettings.dspHorSmooth = false //Why was this disabled?
        //pulseRuntimeSettings.soundSpeed_ok = false //Why was this disabled?
        //Categories
        pulseRuntimeSettings.onDistSetupChanged = false
        pulseRuntimeSettings.onChartSetupChanged = false
        pulseRuntimeSettings.onDatasetChanged = false
        pulseRuntimeSettings.onTransChanged = false
        //pulseRuntimeSettings.onDspSetupChanged = false
        //pulseRuntimeSettings.onSoundChanged = false //Why was this disabled?
        //Overall
        pulseRuntimeSettings.echogramPausedForConfig = false
        pulseRuntimeSettings.echogramEnabledByConfig = false
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
        } else {
            console.log("DEV_PARAM distMax_ok accepted as", dev.distMax)
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
        } else {
            console.log("DEV_PARAM distDeadZone_ok accepted as", dev.distDeadZone)
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
        } else {
            console.log("DEV_PARAM distConfidence_ok accepted as", dev.distConfidence)
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
        } else {
            console.log("DEV_PARAM chartSamples_ok accepted as", dev.chartSamples)
        }

        // chartResolution
        if (!pulseRuntimeSettings.chartResolution_ok) {
            if (pulseRuntimeSettings.doDynamicResolution) {
                pulseRuntimeSettings.chartResolution_Copy = dev.chartResolution
                pulseRuntimeSettings.chartResolution_ok = true
                console.log("DEV_PARAM chartResolution OK as", dev.chartResolution, ". We set it dynamically for 2D transducers anyway")
            } else {
                //Pulse blue
                if (dev.chartResolution === pulseRuntimeSettings.chartResolution) {
                    pulseRuntimeSettings.chartResolution_Copy = dev.chartResolution
                    pulseRuntimeSettings.chartResolution_ok = true
                    console.log("DEV_PARAM chartResolution OK for",pulseRuntimeSettings.devName ,"as", dev.chartResolution)
                } else {
                    console.log("DEV_PARAM onChartSetupChanged, found dev.chartResolution as", dev.chartResolution, " try setting dev.chartResolution set to", pulseRuntimeSettings.chartResolution)
                    dev.chartResolution = pulseRuntimeSettings.chartResolution
                    return
                }
            }
        } else {
            console.log("DEV_PARAM chartResolution_ok accepted as", dev.chartResolution)
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
        } else {
            console.log("DEV_PARAM chartOffset_ok accepted as", dev.chartOffset)
        }

        // Verify all
        if (pulseRuntimeSettings.chartSamples_ok
                && pulseRuntimeSettings.chartResolution_ok
                && pulseRuntimeSettings.chartOffset_ok) {
            pulseRuntimeSettings.onChartSetupChanged = true
            //console.log("DEV_PARAM onChartSetupChanged complete")
        }
    }

    function disableEchogram () {
        if (dev === null)
            return

        if (dev.datasetChart === 1) {
            pulseRuntimeSettings.echogramPausedForConfig = false
            dev.datasetChart = 0
        } else {
            pulseRuntimeSettings.echogramPausedForConfig = true
        }

    }

    function datasetSetup () {
        if (dev === null)
            return

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
        } else {
            console.log("DEV_PARAM ch1Period_ok accepted as", dev.ch1Period)
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
        } else {
            console.log("DEV_PARAM datasetDist_ok accepted as", dev.datasetDist)
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
        } else {
            console.log("DEV_PARAM datasetSDDBT_ok accepted as", dev.datasetSDDBT)
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
        } else {
            console.log("DEV_PARAM datasetEuler_ok accepted as", dev.datasetEuler)
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
            console.log("DEV_PARAM datasetTemp_ok accepted as", dev.datasetTemp)
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
        } else {
            console.log("DEV_PARAM datasetTimestamp_ok accepted as", dev.datasetTimestamp)
        }

        // datasetChart (let us do this as the very last parameter)
        if (!pulseRuntimeSettings.datasetChart_ok) {
            if (dev.datasetChart === pulseRuntimeSettings.datasetChart) {
                pulseRuntimeSettings.datasetChart_Copy = dev.datasetChart
                pulseRuntimeSettings.datasetChart_ok = true
                console.log("DEV_PARAM datasetChart OK as", dev.datasetChart)
            } else {
                console.log("DEV_PARAM onDatasetChanged datasetChart set to", pulseRuntimeSettings.datasetChart)
                pulseRuntimeSettings.echogramEnabledByConfig = true
                dev.datasetChart = pulseRuntimeSettings.datasetChart
                return
            }
        } else {
            console.log("DEV_PARAM datasetChart_ok accepted as", dev.datasetChart)
        }

        // Verify all
        if (
                pulseRuntimeSettings.ch1Period_ok
                && pulseRuntimeSettings.datasetDist_ok
                && pulseRuntimeSettings.datasetSDDBT_ok
                && pulseRuntimeSettings.datasetEuler_ok
                && pulseRuntimeSettings.datasetTemp_ok
                && pulseRuntimeSettings.datasetTimestamp_ok
                && pulseRuntimeSettings.datasetChart_ok
                ) {
            pulseRuntimeSettings.onDatasetChanged = true
            console.log("DEV_PARAM onDatasetChanged complete, happy with everything")
        }
    }

    function preCheckParameters () {
        // transducer
        if (dev.transFreq === pulseRuntimeSettings.transFreq)               pulseRuntimeSettings.transFreq_ok = true
        if (dev.transPulse === pulseRuntimeSettings.transPulse)             pulseRuntimeSettings.transPulse_ok = true
        if (dev.transBoost === pulseRuntimeSettings.transBoost)             pulseRuntimeSettings.transBoost_ok = true
        if (pulseRuntimeSettings.transFreq_ok
            && pulseRuntimeSettings.transPulse_ok
            && pulseRuntimeSettings.transBoost_ok)
            pulseRuntimeSettings.onTransChanged = true
        // DSPsmooth
        // sound
        if (dev.soundSpeed === pulseRuntimeSettings.soundSpeed)             pulseRuntimeSettings.soundSpeed_ok = true
        if (pulseRuntimeSettings.soundSpeed_ok)
            pulseRuntimeSettings.onSoundChanged = true
        // distance
        if (dev.distMax === pulseRuntimeSettings.distMax)                   pulseRuntimeSettings.distMax_ok = true
        if (dev.distDeadZone === pulseRuntimeSettings.distDeadZone)         pulseRuntimeSettings.distDeadZone_ok = true
        if (dev.distConfidence === pulseRuntimeSettings.distConfidence)     pulseRuntimeSettings.distConfidence_ok = true
        if (pulseRuntimeSettings.distMax_ok
            && pulseRuntimeSettings.distDeadZone_ok
            && pulseRuntimeSettings.distConfidence_ok)
            pulseRuntimeSettings.onDistSetupChanged = true
        // chart
        if (dev.chartSamples === pulseRuntimeSettings.chartSamples)         pulseRuntimeSettings.chartSamples_ok = true
        if (dev.chartOffset === pulseRuntimeSettings.chartOffset)           pulseRuntimeSettings.chartOffset_ok = true
        // dataset
        if (dev.datasetDist === pulseRuntimeSettings.datasetDist)           pulseRuntimeSettings.datasetDist_ok = true
        if (dev.datasetSDDBT === pulseRuntimeSettings.datasetSDDBT)         pulseRuntimeSettings.datasetSDDBT_ok = true
        if (dev.datasetEuler === pulseRuntimeSettings.datasetEuler)         pulseRuntimeSettings.datasetEuler_ok = true
        if (dev.datasetTemp === pulseRuntimeSettings.datasetTemp)           pulseRuntimeSettings.datasetTemp_ok = true
        if (dev.datasetTimestamp === pulseRuntimeSettings.datasetTimestamp) pulseRuntimeSettings.datasetTimestamp_ok = true
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
        } else {
            console.log("DEV_PARAM transFreq_ok accepted as", dev.transFreq)
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
        } else {
            console.log("DEV_PARAM transPulse_ok accepted as", dev.transPulse)
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
        } else {
            console.log("DEV_PARAM transBoost_ok accepted as", dev.transBoost)
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
        } else {
            console.log("DEV_PARAM dspHorSmooth_ok accepted as", dev.dspHorSmooth)
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
        } else {
            console.log("DEV_PARAM soundSpeed_ok accepted as", dev.soundSpeed)
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

        if (pulseRuntimeSettings.userManualSetName !== "...") {
            if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed
                    || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto) {
                let desiredFrequency = 0
                if (pulseSettings.ecoConeIndex === 0) {
                    desiredFrequency = pulseRuntimeSettings.transFreqWide
                    console.log("DEV_PARAM: use frequency for pulse red wide")
                } else if (pulseSettings.ecoConeIndex === 1) {
                    desiredFrequency = pulseRuntimeSettings.transFreqMedium
                    console.log("DEV_PARAM: use frequency for pulse red metium")
                } else {
                    desiredFrequency = pulseRuntimeSettings.transFreqNarrow
                    console.log("DEV_PARAM: use frequency for pulse red narrow")
                }

                pulseRuntimeSettings.transFreq = desiredFrequency

            } else {
                //Pulse Blue
                //pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqMedium
                pulseRuntimeSettings.chartResolution = pulseSettings.echogramWidth
                pulseRuntimeSettings.distMax = 1000 * pulseSettings.echogramWidth
                pulseRuntimeSettings.maximumDepth = pulseSettings.echogramWidth
            }
        }

        if (pulseSettings.positionSourceAutoPilot) {
            console.log("Autopilot is sending data: let's enable receiving it")
            linkManagerWrapper.sendCreateAndOpenAsUdpProxy("0.0.0.0", 14569, 14568)
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
    }

    Connections {
        target: pulseSettings ? pulseSettings : undefined

        function onEchogramWidthChanged () {
            if (pulseSettings === null)
                return
            if (dev === null)
                return

            let newResoultion = pulseSettings.echogramWidth
            pulseRuntimeSettings.chartResolution = newResoultion
            console.log("Got a new resolution from echogramWidth:", pulseSettings.echogramWidth," let's change chartResolution")

            let newMaxDepth = newResoultion * 1000
            pulseRuntimeSettings.distMax = newMaxDepth
        }

        function onPositionSourceAutoPilotChanged () {
            if (pulseSettings === null)
                return
            if (dev === null)
                return
            if (pulseSettings.positionSourceAutoPilot) {
                linkManagerWrapper.sendCreateAndOpenAsUdpProxy("0.0.0.0", 14569, 14568)
            } else {
                linkManagerWrapper.sendCloseUdpProxy()
            }

        }
    }


    Connections {
        target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined

        /*
        function onDataUpdateActiveChanged () {
            if (pulseRuntimeSettings.dataUpdateActive && !pulseRuntimeSettings.devConfigured) {
                console.log("DEV_PARAM: Observed data from a device, devices not yet configured")
                if (dev !== null) {
                    console.log("DEV_PARAM: Turn off the echogram before we configure anything")
                    dev.datasetChart = 0
                } else {
                    console.log("DEV_PARAM: dev null, no way to turn echogram off")
                }
            }
        }
        */

        function onReconnectAfterLogViewChanged () {
            if (pulseRuntimeSettings === null)
                return

            if (!pulseRuntimeSettings.reconnectAfterLogView)
                return

            pulseRuntimeSettings.wasKlfFileOpened = false;
            pulseRuntimeSettings.didEverReceiveData = false
            pulseRuntimeSettings.hasDeviceLostConnection = false
            resetAllSetupStates()
            pulseRuntimeSettings.pulseBetaName = "..."
            pulseRuntimeSettings.userManualSetName = "..."
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
            pulseRuntimeSettings.reconnectAfterLogView = false
            core.closeLogFile()
        }

        function onEchoSounderRebootChanged () {
            if (pulseRuntimeSettings.echoSounderReboot) {
                if (dev === null)
                    return
                //if (dev.devName === "...")
                if (pulseRuntimeSettings.devName === "...")
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

        //DevDriver sets the pulseRuntimeSettings.devName, triggering this alert. Name will be "..." for no device or real device name
        function onDevNameChanged() {
            //console.log("TAV: onDevNameChanged to:", pulseRuntimeSettings.devName);
            pulseSettings.devName = pulseRuntimeSettings.devName
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
            if (pulseRuntimeSettings.pulseBetaName === "..." && pulseRuntimeSettings.devName === "Basic2D") {
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

}
