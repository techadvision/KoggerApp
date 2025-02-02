import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs 1.2
import Qt.labs.settings 1.1


ColumnLayout {
    id: columnItem
    spacing: 0
    Layout.margins: 0
    property var dev: null
    property bool settingsCompleted: false

    Timer {
        id: delayTimer
        interval: 3000
        repeat: !settingsCompleted
        onTriggered: {

            /* -- PULSE: DEFAULT SETTINGS AT STARTUP -- */

            if (dev === null) {
                console.log("TAV: DEV is still null");
                return
            }
            if (settingsCompleted) {
                console.log("No further trying to modify settings after we've set it once");
                return
            } else {

                settingsCompleted = true

                // ECHOGRAM
                dev.chartResolution = 10        // Resolution mm "10"
                dev.chartSamples = 2000         // Number of samples "2.000"
                dev.chartOffset = 0             // Offset of samples "0"

                // RANGEFINDER
                dev.distMax = 50000             // Max distance mm "20.000"
                dev.distDeadZone = 10           // Dead zone "10"
                dev.distConfidence = 13         // Confidence Threshold "13"

                // TRANSDUCER
                dev.transPulse = 10             // Pulse Count "10"
                dev.transFreq = 710             // Frequency, kHz "710"
                dev.transBoost = 0              // Booster "OFF"

                // DSP
                dev.dspHorSmooth = 0            // Horizontal Smoothing Factor "0"
                dev.soundSpeed = 1500 * 1000    // Speed of sound m/s "1500"

                // DATASET
                dev.ch1Period = 50              // Period "50"
                dev.datasetChart = 1            // Echogram "8-bit"
                dev.datasetDist = 1             // Rangefinder "ON"
                dev.datasetEuler = 0            // AHRS "OFF"
                dev.datasetTemp = 1             // Temperature "ON"
                dev.datasetTimestamp = 0        // Timestamp "OFF"

                // RETRIEVE CONNECTED DEVICE INFO - Non-working getters are commented out
                //console.log("TAV PULSE device address:", dev.getDevAddress);
                //console.log("TAV PULSE bus address:", dev.getBusAddress);
                console.log("TAV PULSE device name:", dev.devName);
                //console.log("TAV PULSE device:", dev.boardVersion);
                //console.log("TAV PULSE device serial number:", dev.devSerialNumber);
                //console.log("TAV PULSE device PN:", dev.devPN);
                //console.log("TAV PULSE device firmware version:", dev.fwVersion);
                //console.log("TAV PULSE device board version:", dev.boardVersion);
                console.log("TAV PULSE device is a sonar:", dev.isSonar);
                console.log("TAV PULSE device is a recording device:", dev.isRecorder);
                console.log("TAV PULSE device is a doppler device:", dev.isDoppler);
                console.log("TAV PULSE device is a usbl beacon device:", dev.isUSBLBeacon);
                console.log("TAV PULSE device is a usbl device:", dev.isUSBL);
                console.log("TAV PULSE device can chart:", dev.isChartSupport);
                console.log("TAV PULSE device can measure distance:", dev.isDistSupport);
                console.log("TAV PULSE device can do DSP:", dev.isDSPSupport);
                console.log("TAV PULSE device is transducer:", dev.isTransducerSupport);
                console.log("TAV PULSE device has datset support:", dev.isDatasetSupport);
                console.log("TAV PULSE device has sound of speed support:", dev.isSoundSpeedSupport);
                console.log("TAV PULSE device has address support:", dev.isAddressSupport);
                console.log("TAV PULSE device has upgrade support:", dev.isUpgradeSupport);


                console.log("Applied TAV PULSE settings after timer");
            }
        }
    }

    Component.onCompleted: {
        console.log("TAV Device item completed, let's set the standardized settings");
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
                devValue: dev !== null ? dev.chartResolution : 0
                isValid: dev !== null ? dev.chartSetupState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        dev.chartResolution = value
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
                devValue: dev !== null ? dev.chartSamples : 0
                isValid: dev !== null ? dev.chartSetupState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        dev.chartSamples = value
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
                devValue: dev !== null ? dev.chartOffset : 0
                isValid: dev !== null ? dev.chartSetupState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        dev.chartOffset = value
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
                devValue: dev !== null ? dev.distMax : 0
                isValid: dev !== null ? dev.distSetupState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        dev.distMax = value
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
                devValue: dev !== null ? dev.distDeadZone : 0
                isValid: dev !== null ? dev.distSetupState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        dev.distDeadZone = value
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
                devValue: dev !== null ? dev.distConfidence : 0
                isValid: dev !== null ? dev.distSetupState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        dev.distConfidence = value
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
                devValue: dev !== null ? dev.transPulse : 0
                isValid: dev !== null ? dev.transcState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        dev.transPulse = value
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
                devValue: dev !== null ? dev.transFreq : 0
                isValid: dev !== null ? dev.transcState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        dev.transFreq = value
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
                devValue: dev !== null ? dev.transBoost : 0
                isValid: dev !== null ? dev.transcState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        dev.transBoost = value
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
                devValue: dev !== null ? dev.dspHorSmooth : 0
                isValid: dev !== null ? dev.dspState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        dev.dspHorSmooth = value
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
                devValue: dev !== null ? dev.soundSpeed / 1000 : 0
                isValid: dev !== null ? dev.soundState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        dev.soundSpeed = value * 1000
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
                devValue: dev !== null ? dev.ch1Period : 0
                isValid: dev !== null ? dev.datasetState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        dev.ch1Period = value
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
                devValue: dev !== null ? dev.datasetChart === 1 : 0
                isValid: dev !== null ? dev.datasetState : false
                editable: false

                onValueChanged: {
                    if (!isDriverChanged) {
                        if (value == 1) {
                            dev.datasetChart = 1
                        }
                        else {
                            dev.datasetChart = 0
                        }
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
                devValue: dev !== null ? (dev.datasetDist === 1 ? 1 : dev.datasetSDDBT === 1 ? 2 : 0) : 0
                isValid: dev !== null ? dev.datasetState : false
                editable: false

                onValueChanged: {
                    if (!isDriverChanged) {
                        if (value == 1) {
                            dev.datasetDist = 1
                        }
                        else if (value == 2) {
                            dev.datasetSDDBT = 1
                        }
                        else {
                            dev.datasetDist = 0
                            dev.datasetSDDBT = 0
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
                devValue: dev !== null ? ((dev.datasetEuler & 1) === 1) : 0
                isValid: dev !== null ? dev.datasetState : false

                onValueChanged: {
                    if (!isDriverChanged) {
                        if (value == 1) {
                            dev.datasetEuler = 1
                        }
                        else if (dev.datasetEuler & 1) {
                            dev.datasetEuler = 0
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
                devValue: dev !== null ? ((dev.datasetTemp & 1) === 1) : 0
                isValid: dev !== null ? dev.datasetState : false
                editable: false

                onValueChanged: {
                    if (!isDriverChanged) {
                        if(value == 1) {
                            dev.datasetTemp = 1
                        }
                        else if (dev.datasetTemp & 1) {
                            dev.datasetTemp = 0
                        }
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
                devValue: dev !== null ? ((dev.datasetTimestamp & 1) === 1) : 0
                isValid: dev !== null ? dev.datasetState : false
                editable: false

                onValueChanged: {
                    if (!isDriverChanged) {
                        if (value == 1) {
                            dev.datasetTimestamp = 1
                        }
                        else if (dev.datasetTimestamp & 1) {
                            dev.datasetTimestamp = 0
                        }
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
