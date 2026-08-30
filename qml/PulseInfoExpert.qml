import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Echo.UI 1.0
import QtQuick.Window


Flickable {
    id: settingsPopup

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real platformScale: _isAndroid ? 0.9 : 0.75
    //readonly property real s: Ui.scale * platformScale
    readonly property real shortSide: Math.min(Screen.width, Screen.height)
    readonly property real s: Math.max(1.0, shortSide / 1100) // tune 800 to your “10-inch baseline”

    // Platform related sizes
    property int controlIconSize: Math.round(24 * s)
    property int pressButtonSize: Math.round(56 * s)
    property int displayPixels:   Math.round(60 * s)
    property int valueTextWidth:  Math.round(60 * s)
    property int valueTextHeigh:  Math.round(40 * s)
    property int valuePixels:     Ui.fontL//Math.round(42 * s)
    property int autoPixels:      Math.round(32 * s)
    property int selectIconSize:  Math.round(64 * s)
    property int selectCheckSize: Math.round(48 * s)

    focus: true
    width: _isAndroid ? 900 : 600

    anchors.fill: parent
    flickableDirection: Flickable.VerticalFlick
    // Hold a child's press briefly so a drag becomes a scroll instead of
    // reaching the +/- buttons. Defense-in-depth alongside the control's
    // own tap/hold handling.
    pressDelay: 200

    // Scrollbar always visible
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AlwaysOn
        width: 16
    }

    contentWidth: width
    //contentHeight: contentItem.childrenRect.height
    contentHeight: settingsColumn.y + settingsColumn.implicitHeight

    signal pulsePreferenceClosed()
    signal pulsePreferenceValueChanged(double newValue)
    //signal stateChanged(bool checked)

    Rectangle{
        id: spacer
        width: 900
        height: 20
    }

    ColumnLayout {
        id: settingsColumn
        spacing: 20
        anchors.top: spacer.bottom

        //Category: Expert mode

        SettingRow {
            toggle: true
            checkbox: false
            text: "Expert mode enabled"
            visible: pulseRuntimeSettings.expertMode
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "expertMode"
                initialChecked: pulseRuntimeSettings.expertMode
            }
        }

        SettingRow {
            toggle: true
            text: "Experimental settings"
            visible: pulseRuntimeSettings.expertMode
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatExperimental"
                initialValue: pulseRuntimeSettings.showCatExperimental
            }
        }

        SettingRow {
            toggle: false
            checkbox: true
            id: echogramToggle
            text: "Use echogram"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "datasetChart"
                initialChecked: pulseRuntimeSettings.datasetChart
                clearAfter: false
            }
        }

        SettingRow {
            toggle: false
            text: "Pulse blue booster"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental && pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
            HorizontalControllerDoubleSettings {
                id: transBoostSelection
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [0, 1]

                //onPulsePreferenceValueChanged: pulseRuntimeSettings.transBoost = newValue
                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.transBoost = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.transBoost)
                    currentIndex = idx >= 0 ? idx : 0
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onTransBoostChanged () {
                        console.log("Detected pulseRuntimeSettings.transBoost got new value ", pulseRuntimeSettings.transBoost)
                        var idx = transBoostSelection.values.indexOf(pulseRuntimeSettings.transBoost)
                        transBoostSelection.currentIndex = idx >= 0 ? idx : 0
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Pulse blue High/Low Frequenzy"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental && pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
            HorizontalControllerDoubleSettings {
                id: blueHiLoFrequency
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [460, 820]

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.transFreq = newValue
                    console.log("Expert changed frequency for Pulse Blue to", newValue)
                    if (newValue === 820) {
                        pulseRuntimeSettings.useBlueHighFrequency = true
                    } else {
                        pulseRuntimeSettings.useBlueHighFrequency = false
                    }
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.transFreq)
                    currentIndex = idx >= 0 ? idx : 0
                }

                /*
                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onTransFreqChanged () {
                        console.log("Detected pulseRuntimeSettings.transFreq got new value ", pulseRuntimeSettings.transFreq)
                        var idx = frequencySelection.values.indexOf(pulseRuntimeSettings.transFreq)
                        frequencySelection.currentIndex = idx >= 0 ? idx : 0
                    }
                }
                */
            }
        }

        //SUSPECTED TO INTRODUCE AN OFFSET WHEN WE REBOOT
        /*
        SettingRow {
            toggle: false
            text: "Offset adjust"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            HorizontalControllerDoubleSettings {
                id: chartOffsetSelection
                values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
                    11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
                    21, 22, 23, 24, 25, 26, 27, 28, 29, 30]

                onPulsePreferenceValueChanged: pulseRuntimeSettings.chartOffset = newValue
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.chartOffset)
                    currentIndex = idx >= 0 ? idx : 0
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onChartOffsetChanged () {
                        console.log("DEV_PARAM: Detected pulseRuntimeSettings.chartOffset got new value ", pulseRuntimeSettings.chartOffset)
                        var idx = chartOffsetSelection.values.indexOf(pulseRuntimeSettings.chartOffset)
                        chartOffsetSelection.currentIndex = idx >= 0 ? idx : 0
                    }
                }
            }
        }
        */


        SettingRow {
            toggle: false
            text: "Frequency adjust"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            HorizontalControllerDoubleSettings {
                id: frequencySelection
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [300, 310, 320, 330, 340, 350, 360, 370, 380, 390,
                        400, 410, 420, 430, 440, 450, 460, 470, 480, 490,
                        500, 510, 520, 530, 540, 550, 560, 570, 580, 590,
                        600, 610, 620, 630, 640, 650, 660, 670, 680, 690,
                        700, 710, 720, 730, 740, 750, 760, 770, 780, 790,
                        800, 810, 820, 830, 840, 850, 860, 870, 880, 890,
                        900, 910, 920, 930, 940, 950, 960, 970, 980, 990]

                //onPulsePreferenceValueChanged: pulseRuntimeSettings.transFreq = newValue
                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.transFreq = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.transFreq)
                    currentIndex = idx >= 0 ? idx : 0
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onTransFreqChanged () {
                        console.log("Detected pulseRuntimeSettings.transFreq got new value ", pulseRuntimeSettings.transFreq)
                        var idx = frequencySelection.values.indexOf(pulseRuntimeSettings.transFreq)
                        frequencySelection.currentIndex = idx >= 0 ? idx : 0
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Period, ms"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            HorizontalControllerMinMaxSettings {
                id: periodSelection
                //MinMax rather than a fixed values[] list (changed 2026-08-29): this
                //parameter is driven dynamically for the Red, so the live value is
                //routinely OUTSIDE any list we could write down. The old stepper then
                //fell back to values[0] and displayed a number the device never had.
                //Olav measured 156 ms on a live Red while the stepper showed 10.
                minimum: 0
                maximum: 2000
                stepSize: 1
                //Never write on a programmatic seed or re-sync — only on a real step.
                //Without this the seed alone would break the profile binding on
                //ch1Period, and a re-sync could push a wrong value to the transducer.
                emitOnUserActionOnly: true

                //DISPLAY the device read-back, so this row always agrees with the
                //"Device parameter information" category further down. ch1Period_Copy is -1
                //until the first read, so fall back to the value the app intends.
                //
                //Held in its own bound property rather than a Connections block: the
                //change handler for ch1Period_Copy would have to be spelled
                //onCh1Period_CopyChanged, and Qt 6 treats a mistyped signal name in
                //Connections as an error. A property we own has an unambiguous handler.
                property int deviceValue: (pulseRuntimeSettings.ch1Period_Copy >= 0)
                                            ? pulseRuntimeSettings.ch1Period_Copy
                                            : pulseRuntimeSettings.ch1Period

                //Programmatic, so emitOnUserActionOnly keeps it from writing back.
                onDeviceValueChanged: currentValue = deviceValue

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.ch1Period = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: currentValue = deviceValue
            }
        }

        SettingRow {
            toggle: false
            text: "Samples"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            HorizontalControllerMinMaxSettings {
                id: samplesSelection
                //MinMax rather than a fixed values[] list (changed 2026-08-29): this
                //parameter is driven dynamically for the Red, so the live value is
                //routinely OUTSIDE any list we could write down. The old stepper then
                //fell back to values[0] and displayed a number the device never had.
                //Device range per DeviceItem's "Number of Samples" SpinBox: 100-15000.
                minimum: 100
                maximum: 15000
                stepSize: 50
                //Never write on a programmatic seed or re-sync — only on a real step.
                //Without this the seed alone would break the profile binding on
                //chartSamples, and a re-sync could push a wrong value to the transducer.
                emitOnUserActionOnly: true

                //DISPLAY the device read-back, so this row always agrees with the
                //"Device parameter information" category further down. chartSamples_Copy is -1
                //until the first read, so fall back to the value the app intends.
                //
                //Held in its own bound property rather than a Connections block: the
                //change handler for chartSamples_Copy would have to be spelled
                //onChartSamples_CopyChanged, and Qt 6 treats a mistyped signal name in
                //Connections as an error. A property we own has an unambiguous handler.
                property int deviceValue: (pulseRuntimeSettings.chartSamples_Copy >= 0)
                                            ? pulseRuntimeSettings.chartSamples_Copy
                                            : pulseRuntimeSettings.chartSamples

                //Programmatic, so emitOnUserActionOnly keeps it from writing back.
                onDeviceValueChanged: currentValue = deviceValue

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.chartSamples = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: currentValue = deviceValue
            }
        }

        SettingRow {
            toggle: false
            text: "Sample spacing, mm"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            HorizontalControllerMinMaxSettings {
                id: resolutionSelection
                //MinMax rather than a fixed values[] list (changed 2026-08-29): this
                //parameter is driven dynamically for the Red, so the live value is
                //routinely OUTSIDE any list we could write down. The old stepper then
                //fell back to values[0] and displayed a number the device never had.
                //Renamed from "Resolution": high resolution is a LOW number, which misreads every time. Sample spacing is a length, so bigger is plainly coarser.
                minimum: 1
                maximum: 100
                stepSize: 1
                //Never write on a programmatic seed or re-sync — only on a real step.
                //Without this the seed alone would break the profile binding on
                //chartResolution, and a re-sync could push a wrong value to the transducer.
                emitOnUserActionOnly: true

                //DISPLAY the device read-back, so this row always agrees with the
                //"Device parameter information" category further down. chartResolution_Copy is -1
                //until the first read, so fall back to the value the app intends.
                //
                //Held in its own bound property rather than a Connections block: the
                //change handler for chartResolution_Copy would have to be spelled
                //onChartResolution_CopyChanged, and Qt 6 treats a mistyped signal name in
                //Connections as an error. A property we own has an unambiguous handler.
                property int deviceValue: (pulseRuntimeSettings.chartResolution_Copy >= 0)
                                            ? pulseRuntimeSettings.chartResolution_Copy
                                            : pulseRuntimeSettings.chartResolution

                //Programmatic, so emitOnUserActionOnly keeps it from writing back.
                onDeviceValueChanged: currentValue = deviceValue

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.chartResolution = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: currentValue = deviceValue
            }
        }

        SettingRow {
            toggle: false
            text: "Maximum depth adjust"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            HorizontalControllerDoubleSettings {
                id: depthSelection
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [25000, 30000, 35000, 40000, 45000, 50000, 55000, 60000, 65000,
                        70000, 75000, 80000, 85000, 90000, 95000, 100000]

                onPulsePreferenceValueChanged: function(newValue) {
                let newMaximumDepth = newValue / 1000
                if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed ||
                    pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto) {
                    newMaximumDepth = newMaximumDepth + 2
                }
                pulseRuntimeSettings.maximumDepth = newMaximumDepth
                pulseRuntimeSettings.distMax = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.distMax)
                    currentIndex = idx >= 0 ? idx : 0
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onDistMaxChanged () {
                        console.log("Detected pulseRuntimeSettings.distMax got new value ", pulseRuntimeSettings.distMax)
                        var idx = depthSelection.values.indexOf(pulseRuntimeSettings.distMax)
                        depthSelection.currentIndex = idx >= 0 ? idx : 0
                    }
                }
            }
        }

        //PULSE 2026-08-29: three more device parameters exposed to the expert, on request.
        //All three are ALREADY wired in DeviceItem.qml — it has live Connections on
        //onDistConfidenceChanged, onTransPulseChanged and onSoundSpeedChanged that push
        //straight into dev.*, so writing the pulseRuntimeSettings property is all that is
        //needed here. Same shape as the rows above: writing a per-device property breaks
        //its profile binding for the session, which is the intended expert behaviour.

        SettingRow {
            toggle: false
            text: "Dist confidence adjust (14)"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            HorizontalControllerDoubleSettings {
                id: distConfidenceSelection
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                //Full 0-100 in steps of 1, matching the device range in DeviceItem's
                //"Confidence threshold, %" SpinBox. Full fidelity on purpose: the list
                //must always contain whatever the device reports, otherwise
                //values.indexOf() misses and the control falls back to showing 0.
                values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
                    11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
                    21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
                    31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
                    41, 42, 43, 44, 45, 46, 47, 48, 49, 50,
                    51, 52, 53, 54, 55, 56, 57, 58, 59, 60,
                    61, 62, 63, 64, 65, 66, 67, 68, 69, 70,
                    71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
                    81, 82, 83, 84, 85, 86, 87, 88, 89, 90,
                    91, 92, 93, 94, 95, 96, 97, 98, 99, 100]

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.distConfidence = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.distConfidence)
                    currentIndex = idx >= 0 ? idx : 0
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onDistConfidenceChanged () {
                        console.log("Detected pulseRuntimeSettings.distConfidence got new value ", pulseRuntimeSettings.distConfidence)
                        var idx = distConfidenceSelection.values.indexOf(pulseRuntimeSettings.distConfidence)
                        distConfidenceSelection.currentIndex = idx >= 0 ? idx : 0
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Transducer pulse adjust (10)"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            HorizontalControllerDoubleSettings {
                id: transPulseSelection
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                //1-50 in steps of 1. DeviceItem's "Pulse count" SpinBox nominally accepts
                //0-5000, which is far too wide for a stepper; this covers experimentation
                //around the profile default of 10 without stepping into four-digit values
                //by accident.
                values: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
                    11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
                    21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
                    31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
                    41, 42, 43, 44, 45, 46, 47, 48, 49, 50]

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.transPulse = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.transPulse)
                    currentIndex = idx >= 0 ? idx : 0
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onTransPulseChanged () {
                        console.log("Detected pulseRuntimeSettings.transPulse got new value ", pulseRuntimeSettings.transPulse)
                        var idx = transPulseSelection.values.indexOf(pulseRuntimeSettings.transPulse)
                        transPulseSelection.currentIndex = idx >= 0 ? idx : 0
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Sound of speed adjust (1480)"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            HorizontalControllerDoubleSettings {
                id: soundSpeedSelection
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                //Same list as the regular user control in PulseInfoSettings.qml — the
                //expert just wants it reachable from one place. IMPORTANT: soundSpeed is
                //stored in the runtime settings MULTIPLIED BY 1000 (profile: 1480*1000),
                //so the stepper works in m/s and converts on the way in and out.
                values: [1400, 1405, 1410, 1415, 1420, 1425, 1430,
                    1435, 1440, 1445, 1450, 1455, 1460, 1465, 1470,
                    1475, 1480, 1485, 1490, 1495, 1500, 1505, 1510,
                    1515, 1520, 1525, 1530, 1535, 1540, 1545, 1550]

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.soundSpeed = newValue * 1000
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.soundSpeed / 1000)
                    currentIndex = idx >= 0 ? idx : 0
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onSoundSpeedChanged () {
                        console.log("Detected pulseRuntimeSettings.soundSpeed got new value ", pulseRuntimeSettings.soundSpeed)
                        var idx = soundSpeedSelection.values.indexOf(pulseRuntimeSettings.soundSpeed / 1000)
                        soundSpeedSelection.currentIndex = idx >= 0 ? idx : 0
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            text: "USB baud rate"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            HorizontalControllerDoubleSettings {
                id: baudSelection
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [115200, 921600]

                //onPulsePreferenceValueChanged: pulseSettings.usbSerialBaud = newValue
                onPulsePreferenceValueChanged: function(newValue) {
                    pulseSettings.usbSerialBaud = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseSettings.usbSerialBaud)
                    currentIndex = idx >= 0 ? idx : 0
                }

                Connections {
                    target: pulseSettings ? pulseSettings : undefined
                    function onUsbSerialBaudChanged () {
                        console.log("Detected pulseSettings.usbSerialBaud got new value ", pulseSettings.usbSerialBaud)
                        var idx = baudSelection.values.indexOf(pulseSettings.usbSerialBaud)
                        baudSelection.currentIndex = idx >= 0 ? idx : 0
                    }
                }
            }
        }

        //Category: water body filter (Stage B) — moved out of Experimental
        //2026-08-17; activation independent of both TVG toggles.
        SettingRow {
            toggle: true
            text: "Water body filter"
            visible: pulseRuntimeSettings.expertMode
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatWaterBody"
                initialValue: pulseRuntimeSettings.showCatWaterBody
            }
        }

        //PULSE water-body filter: the filter control acts on the water column +
        //surface band only (bottom-guarded) instead of the global low-cut.
        //Independent of the TVG toggles — applies to every image type (raw,
        //side scan AGC, 2D TVG, side scan TVG) whenever enabled.
        SettingRow {
            toggle: false
            checkbox: true
            id: waterBodyFilterToggle
            text: "Water-body filtering"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatWaterBody
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "echogramWaterBodyFilterEnabled"
                initialChecked: pulseRuntimeSettings.echogramWaterBodyFilterEnabled
                clearAfter: false
            }
        }

        SettingRow {
            toggle: false
            text: "Filter bottom margin (m)"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatWaterBody && pulseRuntimeSettings.echogramWaterBodyFilterEnabled
            HorizontalControllerDoubleSettings {
                id: waterBodyMarginSelection
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [0.0, 0.05, 0.1, 0.15, 0.2, 0.3, 0.5]

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.echogramWaterBodyBottomMargin = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.echogramWaterBodyBottomMargin)
                    currentIndex = idx >= 0 ? idx : values.indexOf(0.05)
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onEchogramWaterBodyBottomMarginChanged () {
                        var idx = waterBodyMarginSelection.values.indexOf(pulseRuntimeSettings.echogramWaterBodyBottomMargin)
                        waterBodyMarginSelection.currentIndex = idx >= 0 ? idx : waterBodyMarginSelection.values.indexOf(0.05)
                    }
                }
            }
        }


        //Category: 2D TVG (Stage A) — moved out of Experimental 2026-08-17
        SettingRow {
            toggle: true
            text: "TVG 2D settings"
            visible: pulseRuntimeSettings.expertMode
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCat2DTvg"
                initialValue: pulseRuntimeSettings.showCat2DTvg
            }
        }

        //PULSE TVG (Stage A): depth compensation for the 2D echogram, display-only
        SettingRow {
            toggle: false
            checkbox: true
            id: tvgToggle
            text: "TVG depth compensation (2D)"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCat2DTvg
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "echogramTvgEnabled"
                initialChecked: pulseRuntimeSettings.echogramTvgEnabled
                // Profile-driven default: never write back unless the expert really clicks,
                // otherwise the first device identification kills the profile binding.
                writeBackOnUserActionOnly: true
                clearAfter: false
            }
        }

        SettingRow {
            toggle: false
            text: "TVG gain (dB/m)"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCat2DTvg && pulseRuntimeSettings.echogramTvgEnabled
            HorizontalControllerDoubleSettings {
                id: tvgDbPerMeterSelection
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.4, 1.6, 1.8, 2.0]

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.echogramTvgDbPerMeter = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.echogramTvgDbPerMeter)
                    currentIndex = idx >= 0 ? idx : values.indexOf(0.9)
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onEchogramTvgDbPerMeterChanged () {
                        var idx = tvgDbPerMeterSelection.values.indexOf(pulseRuntimeSettings.echogramTvgDbPerMeter)
                        tvgDbPerMeterSelection.currentIndex = idx >= 0 ? idx : tvgDbPerMeterSelection.values.indexOf(0.9)
                    }
                }
            }
        }


        //PULSE side scan TVG (side scan phase): its own category. Log-law range
        //gain for the side scan waterfall (imageType 3) and optionally the map
        //mosaic. Validated offline on SS_pulse_log_2026.07.20 — "variant 4"
        //(TVG + noise floor) as the core, detail boost stepper morphs it
        //gradually toward "variant 5".
        SettingRow {
            toggle: true
            text: "TVG side scan settings"
            visible: pulseRuntimeSettings.expertMode
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatTvg"
                initialValue: pulseRuntimeSettings.showCatTvg
            }
        }

        SettingRow {
            toggle: false
            checkbox: true
            id: sideScanTvgToggle
            text: "Side scan TVG (waterfall)"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatTvg
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "sideScanTvgEnabled"
                initialChecked: pulseRuntimeSettings.sideScanTvgEnabled
                // Profile-driven default: never write back unless the expert really clicks,
                // otherwise the first device identification kills the profile binding.
                writeBackOnUserActionOnly: true
                clearAfter: false
            }
        }

        SettingRow {
            toggle: false
            checkbox: true
            id: sideScanTvgMosaicToggle
            text: "Use TVG for mosaic"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatTvg
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "sideScanTvgMosaicEnabled"
                initialChecked: pulseRuntimeSettings.sideScanTvgMosaicEnabled
                clearAfter: false
            }
        }

        SettingRow {
            toggle: false
            text: "Noise floor subtraction"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatTvg
            HorizontalControllerDoubleSettings {
                id: ssTvgNoiseFloorSelection
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [0, 0.1, 0.15, 0.2, 0.25, 0.4, 0.5, 0.75, 1.0]

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.sideScanTvgNoiseFloor = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.sideScanTvgNoiseFloor)
                    currentIndex = idx >= 0 ? idx : values.indexOf(0.1)
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onSideScanTvgNoiseFloorChanged () {
                        var idx = ssTvgNoiseFloorSelection.values.indexOf(pulseRuntimeSettings.sideScanTvgNoiseFloor)
                        ssTvgNoiseFloorSelection.currentIndex = idx >= 0 ? idx : ssTvgNoiseFloorSelection.values.indexOf(0.1)
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Spreading (dB/decade)"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatTvg
            HorizontalControllerDoubleSettings {
                id: ssTvgSpreadingSelection
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [0, 2.5, 5, 7.5, 10, 12.5, 15, 20, 25, 30, 35, 40]

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.sideScanTvgSpreading = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.sideScanTvgSpreading)
                    currentIndex = idx >= 0 ? idx : values.indexOf(5)
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onSideScanTvgSpreadingChanged () {
                        var idx = ssTvgSpreadingSelection.values.indexOf(pulseRuntimeSettings.sideScanTvgSpreading)
                        ssTvgSpreadingSelection.currentIndex = idx >= 0 ? idx : ssTvgSpreadingSelection.values.indexOf(5)
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Absorption (dB/m)"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatTvg
            HorizontalControllerDoubleSettings {
                id: ssTvgAbsorptionSelection
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [0, 0.02, 0.05, 0.1, 0.15, 0.2, 0.3, 0.5, 0.8, 1.0]

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.sideScanTvgAbsorption = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.sideScanTvgAbsorption)
                    currentIndex = idx >= 0 ? idx : values.indexOf(0)
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onSideScanTvgAbsorptionChanged () {
                        var idx = ssTvgAbsorptionSelection.values.indexOf(pulseRuntimeSettings.sideScanTvgAbsorption)
                        ssTvgAbsorptionSelection.currentIndex = idx >= 0 ? idx : ssTvgAbsorptionSelection.values.indexOf(0)
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Reference range (m)"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatTvg
            HorizontalControllerDoubleSettings {
                id: ssTvgRefRangeSelection
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [2, 5, 10, 15, 20, 30, 50]

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.sideScanTvgRefRange = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.sideScanTvgRefRange)
                    currentIndex = idx >= 0 ? idx : values.indexOf(15)
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onSideScanTvgRefRangeChanged () {
                        var idx = ssTvgRefRangeSelection.values.indexOf(pulseRuntimeSettings.sideScanTvgRefRange)
                        ssTvgRefRangeSelection.currentIndex = idx >= 0 ? idx : ssTvgRefRangeSelection.values.indexOf(15)
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Detail boost"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatTvg
            HorizontalControllerDoubleSettings {
                id: ssTvgBoostSelection
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [0, 0.1, 0.2, 0.3, 0.5, 0.7, 0.9, 1.2, 1.5]

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.sideScanTvgBoost = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.sideScanTvgBoost)
                    currentIndex = idx >= 0 ? idx : values.indexOf(1.2)
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onSideScanTvgBoostChanged () {
                        var idx = ssTvgBoostSelection.values.indexOf(pulseRuntimeSettings.sideScanTvgBoost)
                        ssTvgBoostSelection.currentIndex = idx >= 0 ? idx : ssTvgBoostSelection.values.indexOf(1.2)
                    }
                }
            }
        }


        SettingRow {
            toggle: true
            text: "Depth manipulation settings"
            visible: pulseRuntimeSettings.expertMode
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatDepthTricks"
                initialValue: pulseRuntimeSettings.showCatDepthTricks
            }
        }

        SettingRow {
            toggle: false
            text: "Fake depth addition"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDepthTricks
            HorizontalControllerMinMaxSettings {
                id: fakeDepthAddition
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                minimum: 0
                maximum: 60
                stepSize: 0.1

                onPulsePreferenceValueChanged: {
                    pulseRuntimeSettings.fakeDepthAddition = newValue
                    if (dataset) {
                        dataset.setFakeDepthAddition(newValue)
                    }
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    fakeDepthAddition.currentValue = pulseRuntimeSettings.fakeDepthAddition
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onFakeDepthAdditionChanged () {
                        console.log("Detected pulseRuntimeSettings.fakeDepthAddition got new value ", pulseRuntimeSettings.fakeDepthAddition)
                        fakeDepthAddition.currentValue = pulseRuntimeSettings.fakeDepthAddition
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            checkbox: true
            id: fakeDepthPushToggle
            text: "Push fake depth to KLF view"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDepthTricks
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "pushFakeDepth"
                initialChecked: pulseRuntimeSettings.pushFakeDepth
                clearAfter: true
            }
            Connections {
                target: pulseRuntimeSettings
                function onPushFakeDepthChanged () {
                    if (pulseRuntimeSettings.pushFakeDepth) {
                        if (dataset) {
                            dataset.addRangefinder(0, pulseRuntimeSettings.fakeDepthAddition)
                        }
                    }
                    //dataset.addRangefinder(0, pulseRuntimeSettings.fakeDepthAddition)
                    //pulseRuntimeSettings.pushFakeDepth = false
                }
            }
        }

        SettingRow {
            toggle: false
            checkbox: true
            id: resetFakeDepthPushToggle
            text: "Reset false depth"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDepthTricks
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "resetFakeDepth"
                initialChecked: pulseRuntimeSettings.resetFakeDepth
                clearAfter: true
            }
            Connections {
                target: pulseRuntimeSettings
                function onResetFakeDepthChanged () {
                    if (pulseRuntimeSettings.resetFakeDepth) {
                        pulseRuntimeSettings.fakeDepthAddition = 0;
                        pulseRuntimeSettings.resetBottomTrackActive = true
                    } else {
                        pulseRuntimeSettings.resetBottomTrackActive = false
                    }
                }
            }
        }

        SettingRow {
            toggle: true
            text: "Bottom track settings"
            visible: pulseRuntimeSettings.expertMode
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatBottomTrack"
                initialValue: pulseRuntimeSettings.showCatBottomTrack
            }
        }

        SettingRow {
            toggle: false
            checkbox: true
            id: bottomTrackToggle
            text: "Use bottom track depth"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatBottomTrack
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "processBottomTrack"
                initialChecked: pulseRuntimeSettings.processBottomTrack
            }
            Connections {
                target: pulseRuntimeSettings
                function onProcessBottomTrackChanged () {
                    if (pulseRuntimeSettings.processBottomTrack) {
                        pulseRuntimeSettings.isBottomTrackInitiated = true
                        core.setBottomTrackRealtimeFromSettings(true)
                    } else {
                        pulseRuntimeSettings.isBottomTrackInitiated = false
                        core.setBottomTrackRealtimeFromSettings(false)
                    }
                    console.log("DEV_PARAM: Measure by bottom track (instead of range finder)?", pulseRuntimeSettings.processBottomTrack, ", initiated?", pulseRuntimeSettings.isBottomTrackInitiated)
                }
            }
        }

        SettingRow {
            toggle: false
            checkbox: true
            id: bottomTrackToggleShowLines
            text: "Show visible bottom tracks"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatBottomTrack
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "bottomTrackVisible"
                initialChecked: pulseRuntimeSettings.bottomTrackVisible
            }
        }

        SettingRow {
            toggle: false
            checkbox: true
            id: rangefinderTrackToggleShowLines
            text: "Show visible rangefinder track"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatBottomTrack
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "rangefinderTrackVisible"
                initialChecked: pulseRuntimeSettings.rangefinderTrackVisible
            }
        }

        SettingRow {
            toggle: false
            text: "Bottom track gain slope"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatBottomTrack
            HorizontalControllerDoubleSettings {
                id: bottomTrackGainSlopeValue
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0,
                        2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 3.0]

                onPulsePreferenceValueChanged: function(newValue) {
                    if (pulseRuntimeSettings.distProcessing[5] !== newValue) {
                        pulseRuntimeSettings.distProcessing[5] = newValue
                        pulseRuntimeSettings.distProcessing = pulseRuntimeSettings.distProcessing
                    }
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.distProcessing[5])
                    currentIndex = idx >= 0 ? idx : 0
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Bottom track window"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatBottomTrack
            HorizontalControllerDoubleSettings {
                id: bottomTrackWindowValue
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [3, 4, 5, 6, 7, 8, 9, 10,
                    11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
                    21, 22, 23, 24, 25, 26, 27, 28, 29, 30]

                onPulsePreferenceValueChanged: function(newValue) {
                    if (pulseRuntimeSettings.distProcessing[1] !== newValue) {
                        pulseRuntimeSettings.distProcessing[1] = newValue
                        pulseRuntimeSettings.distProcessing = pulseRuntimeSettings.distProcessing
                    }
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.distProcessing[1])
                    currentIndex = idx >= 0 ? idx : 0
                }
            }
        }


        SettingRow {
            toggle: false
            text: "Bottom track vertical gap"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatBottomTrack
            HorizontalControllerDoubleSettings {
                id: bottomTrackVerticalGapValue
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
                    11, 12, 13, 14, 15, 16, 17, 18, 19, 20]

                onPulsePreferenceValueChanged: function(newValue) {
                    if (pulseRuntimeSettings.distProcessing[2] !== newValue) {
                        pulseRuntimeSettings.distProcessing[2] = newValue
                        pulseRuntimeSettings.distProcessing = pulseRuntimeSettings.distProcessing
                    }
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.distProcessing[2])
                    currentIndex = idx >= 0 ? idx : 0
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Bottom track min depth evaluation"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatBottomTrack
            HorizontalControllerDoubleSettings {
                id: bottomTrackMinDepthValue
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [0.0, 0.5, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50]

                onPulsePreferenceValueChanged: function(newValue) {
                    if (pulseRuntimeSettings.distProcessing[3] !== newValue) {
                        pulseRuntimeSettings.distProcessing[3] = newValue
                        pulseRuntimeSettings.distProcessing = pulseRuntimeSettings.distProcessing
                    }
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.distProcessing[3])
                    currentIndex = idx >= 0 ? idx : 0
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Bottom track max depth evaluation"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatBottomTrack
            HorizontalControllerDoubleSettings {
                id: bottomTrackMaxDepthValue
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
                        31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
                        41, 42, 43, 44, 45, 46, 47, 48, 49, 50]

                onPulsePreferenceValueChanged: function(newValue) {
                    if (pulseRuntimeSettings.distProcessing[4] !== newValue) {
                        pulseRuntimeSettings.distProcessing[4] = newValue
                        pulseRuntimeSettings.distProcessing = pulseRuntimeSettings.distProcessing
                    }
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.distProcessing[4])
                    currentIndex = idx >= 0 ? idx : 0
                }
            }
        }

        SettingRow {
            toggle: true
            text: "Black stripes settings"
            visible: pulseRuntimeSettings.expertMode
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatBlackStripes"
                initialValue: pulseRuntimeSettings.showCatBlackStripes
            }
        }

        SettingRow {
            toggle: false
            text: "Black stripes remove: Forward"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatBlackStripes
            HorizontalControllerDoubleSettings {
                id: blackStripesSizeForward
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
                    11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
                    21, 22, 23, 25, 25, 26, 27, 28, 29, 30]
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.fixBlackStripesForwardSteps)
                    currentIndex = idx >= 0 ? idx : 0
                }

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.fixBlackStripesForwardSteps  = newValue
                    core.fixBlackStripesForwardSteps  = newValue
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Black stripes remove: Backward"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatBlackStripes
            HorizontalControllerDoubleSettings {
                id: blackStripesSizeBackward
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
                    11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
                    21, 22, 23, 25, 25, 26, 27, 28, 29, 30]
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.fixBlackStripesBackwardSteps)
                    currentIndex = idx >= 0 ? idx : 0
                }

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.fixBlackStripesBackwardSteps = newValue
                    core.fixBlackStripesBackwardSteps = newValue
                }
            }
        }

        SettingRow {
            toggle: true
            text: "Depth filter tuning"
            visible: pulseRuntimeSettings.expertMode
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatDepthFiltering"
                initialValue: pulseRuntimeSettings.showCatDepthFiltering
            }
        }

        SettingRow {
            toggle: false
            checkbox: true
            id: activateDepthFilterToggle
            text: "Use depth filter"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDepthFiltering && pulseRuntimeSettings.is2DTransducer
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "useDepthFilter"
                initialChecked: pulseRuntimeSettings.useDepthFilter
                clearAfter: false
            }
            Connections {
                target: pulseRuntimeSettings
                function onUseDepthFilterChanged () {
                    if (dataset) {
                        dataset.setDepthFilterActive(pulseRuntimeSettings.useDepthFilter)
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            checkbox: true
            id: activateDepthFilterBottomTrackToggle
            text: "Use depth filter w/bottom track"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDepthFiltering && !pulseRuntimeSettings.is2DTransducer
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "useFilterWithBottomTrack"
                initialChecked: pulseRuntimeSettings.useFilterWithBottomTrack
                clearAfter: false
            }
            Connections {
                target: pulseRuntimeSettings
                function onUseFilterWithBottomTrackChanged () {
                    if (dataset) {
                        dataset.setDepthFilterBottomTrackActive(pulseRuntimeSettings.useFilterWithBottomTrack)
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Filter: Fluctuation margin (m)"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDepthFiltering && pulseRuntimeSettings.is2DTransducer
            HorizontalControllerDoubleSettings {
                id: kSmallAgreeMargin
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.kSmallAgreeMargin)
                    currentIndex = idx >= 0 ? idx : 0
                }

                onPulsePreferenceValueChanged: function(newValue) {
                    //console.log("WOW changed kSmallAgreeMargin to ", newValue)
                    pulseRuntimeSettings.kSmallAgreeMargin = newValue
                    if (dataset) {
                        dataset.setSmallAgreeMargin(newValue)
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Filter: Suspicious jump larger than (m)"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDepthFiltering
            HorizontalControllerDoubleSettings {
                id: kLargeJumpThreshold
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0,
                        11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0]
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.kLargeJumpThreshold)
                    currentIndex = idx >= 0 ? idx : 0
                }

                onPulsePreferenceValueChanged: function(newValue) {
                    //console.log("WOW changed kLargeJumpThreshold to ", newValue)
                    pulseRuntimeSettings.kLargeJumpThreshold = newValue
                    if (dataset) {
                        dataset.setLargeJumpThreshold(newValue)
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Filter: Stable records to accept jump"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDepthFiltering
            HorizontalControllerDoubleSettings {
                id: kConsistNeeded
                //PULSE 2026-08-29: never write on the programmatic seed or re-sync,
                //only on a real user step. See HorizontalControllerDoubleSettings.
                emitOnUserActionOnly: true
                values: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
                    11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.kConsistNeeded)
                    currentIndex = idx >= 0 ? idx : 0
                }

                onPulsePreferenceValueChanged: function(newValue) {
                    //console.log("WOW changed kConsistNeeded to ", newValue)
                    pulseRuntimeSettings.kConsistNeeded = newValue
                    if (dataset) {
                        dataset.setConsistNeeded(newValue)
                    }
                }
            }
        }

        //Category: Device info

        SettingRow {
            toggle: true
            text: "Device raw information"
            visible: pulseRuntimeSettings.expertMode
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatDeviceRawInfo"
                initialValue: pulseRuntimeSettings.showCatDeviceRawInfo
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Device name"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.rawDev_devName
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Device type"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.rawDev_devType
            }
        }

        SettingRow {
            toggle: false
            text: "Device: devList dump"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                //font.pixelSize: settingsPopup.valuePixels
                font.pixelSize: Ui.fontS
                text: pulseRuntimeSettings.rawDev_devListDump
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Baud rate"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.rawDev_devBaudRate
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Serial number"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.rawDev_devSerialNumber
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Firmware version"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.rawDev_firmwareVersion
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Is a sonar?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.rawDev_isSonar
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Supports chart?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.rawDev_isChartSupport
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Is a transducer?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.rawDev_isTransducerSupport
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Supports distance?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.rawDev_isDistSupport
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Supports dataset?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.rawDev_isDatasetSupport
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Supports sound of speed?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.rawDev_isSoundSpeedSupport
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Can be upgraded?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.rawDev_isUpgradeSupport
            }
        }

        //Category: Swap device

        SettingRow {
            toggle: true
            text: "Device swap"
            visible: pulseRuntimeSettings.expertMode
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatSwapDevice"
                initialValue: pulseRuntimeSettings.showCatSwapDevice
            }
        }

        SettingRow {
            text: "Force reselection of device"
            checkbox: true
            show: pulseRuntimeSettings.showCatSwapDevice
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "swapDeviceNow"
                initialChecked: pulseRuntimeSettings.swapDeviceNow
                clearAfter: true
            }
        }

        //Category: Parameter info

        SettingRow {
            toggle: true
            text: "Device parameter information"
            visible: pulseRuntimeSettings.expertMode
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatParameterInfo"
                initialValue: pulseRuntimeSettings.showCatParameterInfo
            }
        }

        SettingRow {
            toggle: false
            id: mod_chartResolution
            text: "Chart: Resolution"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.chartResolution_Copy
                //text: dev.chartResolution
            }
        }

        SettingRow {
            toggle: false
            id: mod_chartSamples
            text: "Chart: Samples"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.chartSamples_Copy
                //text: dev.chartSamples
            }
        }

        SettingRow {
            toggle: false
            text: "Chart: Offset"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.chartOffset_Copy
                //text: dev.chartOffset
            }
        }

        SettingRow {
            toggle: false
            text: "Distance: Max"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.distMax_Copy
                //text: dev.distMax
            }
        }

        SettingRow {
            toggle: false
            id: mod_distDeadZone
            text: "Distance: Dead Zone"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.distDeadZone_Copy
                //text: dev.distDeadZone
            }
        }

        SettingRow {
            toggle: false
            text: "Distance: Confidence"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.distConfidence_Copy
                //text: dev.distConfidence
            }
        }

        SettingRow {
            toggle: false
            id: mod_transPulse
            text: "Transducer: Pulse"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.transPulse_Copy
                //text: dev.transPulse
            }
        }

        SettingRow {
            toggle: false
            text: "Transducer: Frequency"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.transFreq_Copy
                //text: dev.transFreq
            }
        }

        SettingRow {
            toggle: false
            id: mod_transBoost
            text: "Transducer: Boost"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.transBoost_Copy
                //text: dev.transBoost
            }
        }

        SettingRow {
            toggle: false
            id: mod_dspHorSmooth
            text: "Horizontal Smoothing"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.dspHorSmooth_Copy
                //text: dev.dspHorSmooth
            }
        }

        SettingRow {
            toggle: false
            text: "Sound Of Speed"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.soundSpeed_Copy
                //text: dev.soundSpeed
            }
        }

        SettingRow {
            toggle: false
            text: "Ch1 Period"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.ch1Period_Copy
                //text: dev.ch1Period
            }

        }

        SettingRow {
            toggle: false
            text: "Show chart"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.datasetChart_Copy ? "On" : "Off"
                //text: dev.datasetChart ? "On" : "Off"
            }
        }

        SettingRow {
            toggle: false
            text: "Use Distance"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.datasetDist_Copy ? "On" : "Off"
                //text: dev.datasetDist ? "On" : "Off"
            }
        }

        SettingRow {
            toggle: false
            text: "Use Distance NMEA"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.datasetSDDBT_Copy ? "On" : "Off"
                //text: dev.datasetSDDBT ? "On" : "Off"
            }
        }

        SettingRow {
            toggle: false
            text: "Use Euler"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.datasetEuler_Copy ? "On" : "Off"
                //text: dev.datasetEuler ? "On" : "Off"
            }
        }

        SettingRow {
            toggle: false
            text: "Use Temperature"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.datasetTemp_Copy ? "On" : "Off"
                //text: dev.datasetTemp ? "On" : "Off"
            }
        }

        SettingRow {
            toggle: false
            text: "Use Time Stamp"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.datasetTimestamp_Copy ? "On" : "Off"
                //text: dev.datasetTimestamp ? "On" : "Off"
            }
        }

        //Category: Config info

        SettingRow {
            toggle: true
            text: "Device/App config info"
            visible: pulseRuntimeSettings.expertMode
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatAppConfigInfo"
                initialValue: pulseRuntimeSettings.showCatAppConfigInfo
            }
        }

        SettingRow {
            toggle: false
            text: "UUID opened"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: Ui.fontS
                text: {
                    console.log("pulseRuntimeSettings.uuidSuccessfullyOpened", pulseRuntimeSettings.uuidSuccessfullyOpened)
                    return pulseRuntimeSettings.uuidSuccessfullyOpened
                }
            }
        }

        SettingRow {
            toggle: false
            text: "UUID serial"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: Ui.fontS
                text: {
                    console.log("pulseRuntimeSettings.uuidSuccessfullyOpened", pulseRuntimeSettings.uuidUsbSerial)
                    return pulseRuntimeSettings.uuidUsbSerial
                }
            }
        }

        SettingRow {
            toggle: false
            text: "UUID wifi"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: Ui.fontS
                text: {
                    console.log("pulseRuntimeSettings.uuidSuccessfullyOpened", pulseRuntimeSettings.uuidIpGateway)
                    return pulseRuntimeSettings.uuidIpGateway
                }
            }
        }

        SettingRow {
            toggle: false
            text: "UUID proxy"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: Ui.fontS
                text: {
                    console.log("pulseRuntimeSettings.uuidProxyLink", pulseRuntimeSettings.uuidProxyLink)
                    return pulseRuntimeSettings.uuidProxyLink
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Is a 2D device?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.is2DTransducer
            }
        }

        SettingRow {
            toggle: false
            text: "Should use temperature?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.useTemperature
            }
        }

        SettingRow {
            toggle: false
            text: "Temperature correction"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo && pulseRuntimeSettings.useTemperature
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.temperatureCorrection
            }
        }

        SettingRow {
            toggle: false
            text: "Frequency: wide"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.transFreqWide
            }
        }

        SettingRow {
            toggle: false
            text: "Frequency: medium"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.transFreqMedium
            }
        }

        SettingRow {
            toggle: false
            text: "Frequency: narrow"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.transFreqNarrow
            }
        }

        SettingRow {
            toggle: false
            text: "Maximum depth for App"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.maximumDepth
            }
        }


        //Category: Debug info

        SettingRow {
            toggle: true
            text: "Debug information"
            visible: pulseRuntimeSettings.expertMode
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatDebug"
                initialValue: pulseRuntimeSettings.showCatDebug
            }
        }

        SettingRow {
            toggle: false
            text: "Distance config"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDebug
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.onDistSetupChanged === true ?
                          "OK" :
                          "Not verified (struggle?)"
            }
        }

        SettingRow {
            toggle: false
            text: "Transducer echogram config"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDebug
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.onChartSetupChanged === true ?
                          "OK" :
                          "Not verified (struggle?)"
            }
        }

        SettingRow {
            toggle: false
            text: "Dataset config"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDebug
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.onDatasetChanged === true ?
                          "OK" :
                          "Not verified (struggle?)"
            }
        }

        SettingRow {
            toggle: false
            text: "Transducer config"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDebug
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.onTransChanged === true ?
                          "OK" :
                          "Not verified (struggle?)"
            }
        }

        SettingRow {
            toggle: false
            text: "Sound speed config"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDebug
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.onSoundChanged ? "OK" : "Not verified (struggle?)"
            }
        }

        SettingRow {
            toggle: false
            text: "Echogram enabled"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDebug
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                font.pixelSize: settingsPopup.valuePixels
                text: pulseRuntimeSettings.datasetChart_ok === true ?
                          "OK" :
                          "Not verified (struggle?)"
            }
        }

    }

}
