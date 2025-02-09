import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs 1.2
import Qt.labs.settings 1.1
import org.techadvision.settings 1.0


ColumnLayout {
    id: columnItem
    spacing: 0
    Layout.margins: 0
    property var dev: null
    property bool settingsCompleted: false
    property bool deviceIdentified: false
    property bool persistentSettingsChecked: false
    //property string pulseSideScanTransducer: "NAME_OF_SIDESCAN"
    //property string pulse2DTransducer: "ECHO20"
    property string pulseSideScanTransducer: "ECHO20"
    property string pulse2DTransducer: "NAME_OF_SIDESCAN"
    property string transducerName: "not_determined"

    signal transducerDetected(string transducer)

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

    Timer {
        id: delayTimer
        interval: 3000
        repeat: !settingsCompleted || !deviceIdentified
        onTriggered: {

            /* -- PULSE: DEFAULT SETTINGS AT STARTUP -- */
            if (settingsCompleted && deviceIdentified) {
                console.log("TAV: No further trying to modify settings after we've set it once");
                return
            }

            if (dev === null) {
                console.log("TAV: DEV is still null");
                return
            }

            if (!persistentSettingsChecked) {
                persistentSettingsChecked = true
                console.log("TAV: setting maxDepthValue ", PulseSettings.maxDepthValue);
                console.log("TAV: setting autoRange ", PulseSettings.autoRange);
                console.log("TAV: setting intensityDisplayValue ", PulseSettings.intensityDisplayValue);
                console.log("TAV: setting intensityRealValue ", PulseSettings.intensityRealValue);
                console.log("TAV: setting filterDisplayValue ", PulseSettings.filterDisplayValue);
                console.log("TAV: setting filterRealValue ", PulseSettings.filterRealValue);
                console.log("TAV: setting colorMapIndex ", PulseSettings.colorMapIndex);
                console.log("TAV: setting ecoViewIndex ", PulseSettings.ecoViewIndex);
                console.log("TAV: setting ecoConeIndex ", PulseSettings.ecoConeIndex);
                console.log("TAV: setting useMetricValues ", PulseSettings.useMetricValues);
                console.log("TAV: setting useEchogram ", PulseSettings.useEchogram);
                console.log("TAV: setting useDistance ", PulseSettings.useDistance);
                console.log("TAV: setting useTemperature ", PulseSettings.useTemperature);
                console.log("TAV: setting is2DTransducer ", PulseSettings.is2DTransducer);
            }

            if (!settingsCompleted || !deviceIdentified) {

                if (!settingsCompleted) {
                    settingsCompleted = true

                    // ECHOGRAM
                    dev.chartResolution = 10            // Resolution mm:           2D & SS: 10
                    dev.chartSamples    = 2000          // Number of samples:       2D: 2000, SS: 4000
                    dev.chartOffset     = 0             // Offset of samples:       2D & SS: 0

                    // RANGEFINDER
                    dev.distMax         = 50000         // Max distance mm:         2D & SS: 50000
                    dev.distDeadZone    = 0             // Dead zone:               2D & SS: 0
                    dev.distConfidence  = 14            // Confidence Threshold:    2D & SS: 14

                    // TRANSDUCER
                    dev.transPulse      = 10            // Pulse Count:             2D & SS: 10
                    dev.transFreq       = 710           // Frequency, kHz:          2D & SS: 710 (235 = 21 degrees, 735 = 7 degrees)
                    dev.transBoost      = 0             // Booster:                 2D: 0 & SS: 1

                    // DSP
                    dev.dspHorSmooth    = 0             // Horizontal Smoothing:    2D & SS: 0
                    dev.soundSpeed      = 1480 * 1000   // Speed of sound m/s:      2D & SS: 1480

                    // DATASET
                    dev.ch1Period       = 50            // Period:                  2D & SS: 50
                    dev.datasetChart    = 1             // Echogram:                2D & SS: 1 ("8-bit")
                    dev.datasetDist     = 1             // Rangefinder:             2D & SS: 2 ("NMEA"), 1 = "on"
                    dev.datasetEuler    = 0             // AHRS:                    2D & SS: 0  "OFF"
                    dev.datasetTemp     = 0             // Temperature              2D & SS: 0  "OFF" (for now, later "1")
                    dev.datasetTimestamp= 0             // Timestamp                2D & SS: 0  "OFF"

                    // LOG EVENT
                    console.log("TAV: Applied general TechAdVision settings");
                }

                if (!deviceIdentified) {
                    if (dev.devName === pulseSideScanTransducer) {
                        deviceIdentified = true
                        dev.chartSamples    = 4000
                        PulseSettings.useTemperature = false
                        PulseSettings.is2DTransducer = false
                        detectTransducer(dev.devName)
                        console.log("TAV: Adapted settings for a side scan sonar");
                        console.log("TAV: useTemperature: ", PulseSettings.useTemperature);
                        console.log("TAV: is2DTransducer: ", PulseSettings.is2DTransducer);
                        PulseSettings.transducerChangeDetected = false
                        PulseSettings.transducerChangeDetected = true
                    }
                    if (dev.devName === pulse2DTransducer) {
                        deviceIdentified = true
                        PulseSettings.useTemperature = true
                        PulseSettings.is2DTransducer = true
                        detectTransducer(dev.devName)
                        console.log("TAV: Adapted settings for a 2D sonar");
                        console.log("TAV: useTemperature: ", PulseSettings.useTemperature);
                        console.log("TAV: is2DTransducer: ", PulseSettings.is2DTransducer);
                        PulseSettings.transducerChangeDetected = false
                        PulseSettings.transducerChangeDetected = true
                    }
                    if (!deviceIdentified) {
                        console.log("TAV: Transducer named as ", dev.devName);
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("TAV Device item completed, let's set the standardized settings");
        //PREFERENCES
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
