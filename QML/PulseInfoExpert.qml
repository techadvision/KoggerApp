import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15


Flickable {
    id: settingsPopup
    focus: true
    width: 900

    anchors.fill: parent
    flickableDirection: Flickable.VerticalFlick

    // Scrollbar always visible
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AlwaysOn
        width: 16
    }

    //color: "white"
    //radius: 8
    //implicitWidth:  layout.implicitWidth
    //implicitHeight: layout.implicitHeight + spacer.height

    contentWidth: width
    contentHeight: contentItem.childrenRect.height

    signal pulsePreferenceClosed()
    signal pulsePreferenceValueChanged(double newValue)
    signal stateChanged(bool checked)

    Rectangle{
        id: spacer
        width: 900
        height: 20
    }

    ColumnLayout {
        spacing: 20
        anchors.top: spacer.bottom

        //Category: Expert mode

        SettingRow {
            toggle: true
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

        /*
        SettingRow {
            toggle: false
            text: "Stop echogram during setup"
            visible: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            SettingsCheckBox {
                target: pulseSettings ? pulseSettings : undefined
                targetPropertyName: "stopEchogramToConfigure"
                initialChecked: pulseSettings.stopEchogramToConfigure
            }
        }
        */

        SettingRow {
            toggle: false
            text: "Pulse blue booster"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental && pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
            HorizontalControllerDoubleSettings {
                id: transBoostSelection
                values: [0, 1]

                onPulsePreferenceValueChanged: pulseRuntimeSettings.transBoost = newValue
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


        SettingRow {
            toggle: false
            text: "Experimental frequency adjust"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            HorizontalControllerDoubleSettings {
                id: frequencySelection
                values: [400, 410, 420, 430, 440, 450, 460, 470, 480, 490,
                500, 510, 520, 530, 540, 550, 560, 570, 580, 590,
                600, 610, 620, 630, 640, 650, 660, 670, 680, 690,
                700, 710, 720, 730, 740, 750, 760, 770, 780, 790,
                800, 810, 820, 830, 840, 850, 860, 870, 880, 890]

                onPulsePreferenceValueChanged: pulseRuntimeSettings.transFreq = newValue
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
            //text: "Experimental period adjust (50)"
            text: {
                if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                    return "Experimental period adjust (50)"
                } else {
                    return "Experimental period adjust (70)"
                }
            }
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            HorizontalControllerDoubleSettings {
                id: periodSelection
                values: {
                    if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                        return [20, 30, 40, 50, 60, 70, 80, 90, 100]
                    } else {
                        return [50, 60, 70, 80, 90, 100]
                    }
                }

                //values: [20, 30, 40, 50, 60, 70, 80, 90, 100]

                onPulsePreferenceValueChanged: pulseRuntimeSettings.ch1Period = newValue
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.ch1Period)
                    currentIndex = idx >= 0 ? idx : 0
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onCh1PeriodChanged () {
                        console.log("Detected pulseRuntimeSettings.ch1Period got new value ", pulseRuntimeSettings.ch1Period)
                        var idx = periodSelection.values.indexOf(pulseRuntimeSettings.ch1Period)
                        periodSelection.currentIndex = idx >= 0 ? idx : 0
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Experimental samples adjust (2000)"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental && !pulseRuntimeSettings.is2DTransducer
            HorizontalControllerDoubleSettings {
                id: samplesSelection
                values: [700, 750, 800, 850, 900, 950,
                    1000 ,1050, 1100, 1150, 1200, 1250, 1300,
                    1358, 1400, 1450, 1500, 1550, 1600, 1650, 1700, 1750,
                    1800, 1850, 1900, 1950, 2000]

                onPulsePreferenceValueChanged: pulseRuntimeSettings.chartSamples = newValue
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.chartSamples)
                    currentIndex = idx >= 0 ? idx : 0
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onChartSamplesChanged () {
                        console.log("Detected pulseRuntimeSettings.chartSamples got new value ", pulseRuntimeSettings.chartSamples)
                        var idx = samplesSelection.values.indexOf(pulseRuntimeSettings.chartSamples)
                        samplesSelection.currentIndex = idx >= 0 ? idx : 0
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Experimental resolution adjust (35)"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental && !pulseRuntimeSettings.is2DTransducer
            HorizontalControllerDoubleSettings {
                id: resolutionSelection
                values: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
                    11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
                    21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
                    31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
                    41, 42, 43, 44, 45, 46, 47, 48, 49, 50]

                onPulsePreferenceValueChanged: pulseRuntimeSettings.chartResolution = newValue
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.chartResolution)
                    currentIndex = idx >= 0 ? idx : 0
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onChartResolutionChanged () {
                        console.log("Detected pulseRuntimeSettings.chartResolution got new value ", pulseRuntimeSettings.chartResolution)
                        var idx = resolutionSelection.values.indexOf(pulseRuntimeSettings.chartResolution)
                        resolutionSelection.currentIndex = idx >= 0 ? idx : 0
                    }
                }
            }
        }

        /*
        SettingRow {
            toggle: false
            text: "Experimental maximum depth adjust"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            HorizontalControllerDoubleSettings {
                id: depthSelection
                values: [25000, 27000, 29000, 31000, 33000, 35000, 37000, 39000,
                    41000, 43000, 45000, 47000, 49000]

                onPulsePreferenceValueChanged: {
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
        */

        SettingRow {
            toggle: false
            text: "Experimental add fake depth"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            HorizontalControllerMinMaxSettings {
                id: fakeDepthAddition
                minimum: 0
                maximum: 60
                stepSize: 0.2

                onPulsePreferenceValueChanged: pulseRuntimeSettings.fakeDepthAddition = newValue
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
            id: fakeDeptPushToggle
            text: "Push fake depth to KLF"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "pushFakeDepth"
                initialChecked: pulseRuntimeSettings.pushFakeDepth
            }
            Connections {
                target: pulseRuntimeSettings
                function onPushFakeDepthChanged () {
                    dataset.addRangefinder(0, pulseRuntimeSettings.fakeDepthAddition)
                    pulseRuntimeSettings.pushFakeDepth = false
                }
            }
        }

        SettingRow {
            toggle: false
            id: depthMeasureToggle
            text: "Use tracker depth measure"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental && !pulseRuntimeSettings.is2DTransducer
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "bottomTrackVisible"
                initialChecked: pulseRuntimeSettings.bottomTrackVisible
            }
            Connections {
                target: pulseRuntimeSettings
                function onBottomTrackVisibleChanged () {
                    console.log("DEV_PARAM: Measure by rangefinder (instead of bottom track)?", pulseRuntimeSettings.bottomTrackVisible)
                }
            }
        }

        /*
        SettingRow {
            toggle: false
            text: "Chart: Resolution"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental && pulseRuntimeSettings.is2DTransducer
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.chartResolution
            }
        }

        SettingRow {
            toggle: false
            text: "Chart: Samples"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.chartSamples
            }
        }

        SettingRow {
            toggle: false
            text: "Ch1 Period"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatExperimental
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.ch1Period
            }

        }
        */

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
            text: "Enable black stripes removal"
            id: blackStripesToggle
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatBlackStripes
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "fixBlackStripesState"
                initialChecked: pulseRuntimeSettings.fixBlackStripesState

                /*
                onCheckedChanged: {
                    console.log("DEV_PARAM: blackStripesToggle new value", checked)
                    if (!checked) {
                        if (pulseRuntimeSettings.fixBlackStripesForwardSteps > 0) {
                            pulseRuntimeSettings.fixBlackStripesForwardSteps = 0
                            pulseRuntimeSettings.fixBlackStripesBackwardSteps = 0
                        }

                    } else {
                        if (pulseRuntimeSettings.fixBlackStripesForwardSteps === 0) {
                            pulseRuntimeSettings.fixBlackStripesForwardSteps = 1
                            pulseRuntimeSettings.fixBlackStripesBackwardSteps = 1
                        }
                    }
                }
                */

                Connections {
                    target: pulseRuntimeSettings
                    function onFixBlackStripesForwardStepsChanged () {
                        console.log("DEV_PARAM: blackStripesToggle observed onFixBlackStripesForwardStepsChanged, value", pulseRuntimeSettings.fixBlackStripesForwardSteps)
                        if (pulseRuntimeSettings.fixBlackStripesState) {
                            console.log("DEV_PARAM: blackStripesToggle is enabled")
                            if (pulseRuntimeSettings.fixBlackStripesForwardSteps === 0) {
                                pulseRuntimeSettings.fixBlackStripesState = false
                                //checked = false
                                console.log("DEV_PARAM: fixBlackStripesForwardSteps is 0, fixBlackStripesState disable")
                            }
                        } else {
                            console.log("DEV_PARAM: blackStripesToggle is disabled")
                            if (pulseRuntimeSettings.fixBlackStripesForwardSteps > 0) {
                                console.log("DEV_PARAM: fixBlackStripesForwardSteps is > 0, fixBlackStripesState enable")
                                pulseRuntimeSettings.fixBlackStripesState = true
                                //blackStripesToggle.checked = true
                            }
                        }

                    }
                }

            }

        }

        SettingRow {
            toggle: false
            text: "Black stripes removal size"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatBlackStripes
            HorizontalControllerDoubleSettings {
                id: blackStripesSize
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

                onPulsePreferenceValueChanged: {
                    pulseRuntimeSettings.fixBlackStripesForwardSteps  = newValue
                    pulseRuntimeSettings.fixBlackStripesBackwardSteps = newValue
                    core.fixBlackStripesForwardSteps  = newValue
                    core.fixBlackStripesBackwardSteps = newValue
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onFixBlackStripesStateChanged () {
                        console.log("DEV_PARAM: onFixBlackStripesStateChanged observed, pulseRuntimeSettings.fixBlackStripesState is", pulseRuntimeSettings.fixBlackStripesState)
                        if (!pulseRuntimeSettings.fixBlackStripesState) {
                            blackStripesSize.currentIndex = 0
                            pulseRuntimeSettings.fixBlackStripesForwardSteps  = 0
                            pulseRuntimeSettings.fixBlackStripesBackwardSteps = 0
                            core.fixBlackStripesForwardSteps  = 0
                            core.fixBlackStripesBackwardSteps = 0
                            console.log("DEV_PARAM: onFixBlackStripesStateChanged observed, turned off black stripes removal")
                        } else {
                            if (pulseRuntimeSettings.fixBlackStripesForwardSteps  === 0) {
                                console.log("DEV_PARAM: onFixBlackStripesStateChanged observed, turned on minimum black stripes removal")
                                blackStripesSize.currentIndex = 1
                                pulseRuntimeSettings.fixBlackStripesForwardSteps  = 1
                                pulseRuntimeSettings.fixBlackStripesBackwardSteps = 1
                                core.fixBlackStripesForwardSteps  = 1
                                core.fixBlackStripesBackwardSteps = 1
                            }
                        }
                    }
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
            text: "Filter: Fluctuation margin (m)"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDepthFiltering
            HorizontalControllerDoubleSettings {
                id: kSmallAgreeMargin
                values: [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.kSmallAgreeMargin)
                    currentIndex = idx >= 0 ? idx : 0
                }

                onPulsePreferenceValueChanged: {
                    //console.log("WOW changed kSmallAgreeMargin to ", newValue)
                    pulseRuntimeSettings.kSmallAgreeMargin = newValue
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Filter: Suspicious jump larger than (m)"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDepthFiltering
            HorizontalControllerDoubleSettings {
                id: kLargeJumpThreshold
                values: [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.kLargeJumpThreshold)
                    currentIndex = idx >= 0 ? idx : 0
                }

                onPulsePreferenceValueChanged: {
                    //console.log("WOW changed kLargeJumpThreshold to ", newValue)
                    pulseRuntimeSettings.kLargeJumpThreshold = newValue
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Filter: Stable records to accept jump"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDepthFiltering
            HorizontalControllerDoubleSettings {
                id: kConsistNeeded
                values: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
                    11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.kConsistNeeded)
                    currentIndex = idx >= 0 ? idx : 0
                }

                onPulsePreferenceValueChanged: {
                    //console.log("WOW changed kConsistNeeded to ", newValue)
                    pulseRuntimeSettings.kConsistNeeded = newValue
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
                font.pixelSize: 30
                text: pulseRuntimeSettings.rawDev_devName
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Device type"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.rawDev_devType
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Baud rate"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.rawDev_devBaudRate
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Serial number"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.rawDev_devSerialNumber
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Firmware version"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.rawDev_firmwareVersion
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Is a sonar?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.rawDev_isSonar
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Supports chart?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.rawDev_isChartSupport
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Is a transducer?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.rawDev_isTransducerSupport
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Supports distance?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.rawDev_isDistSupport
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Supports dataset?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.rawDev_isDatasetSupport
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Supports sound of speed?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.rawDev_isSoundSpeedSupport
            }
        }

        SettingRow {
            toggle: false
            text: "Device: Can be upgraded?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDeviceRawInfo
            Text {
                font.pixelSize: 30
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
                font.pixelSize: 30
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
                font.pixelSize: 30
                text: pulseRuntimeSettings.chartSamples_Copy
                //text: dev.chartSamples
            }
        }

        SettingRow {
            toggle: false
            text: "Chart: Offset"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.chartOffset_Copy
                //text: dev.chartOffset
            }
        }

        SettingRow {
            toggle: false
            text: "Distance: Max"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                font.pixelSize: 30
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
                font.pixelSize: 30
                text: pulseRuntimeSettings.distDeadZone_Copy
                //text: dev.distDeadZone
            }
        }

        SettingRow {
            toggle: false
            text: "Distance: Confidence"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                font.pixelSize: 30
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
                font.pixelSize: 30
                text: pulseRuntimeSettings.transPulse_Copy
                //text: dev.transPulse
            }
        }

        SettingRow {
            toggle: false
            text: "Transducer: Frequency"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                font.pixelSize: 30
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
                font.pixelSize: 30
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
                font.pixelSize: 30
                text: pulseRuntimeSettings.dspHorSmooth_Copy
                //text: dev.dspHorSmooth
            }
        }

        SettingRow {
            toggle: false
            text: "Sound Of Speed"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.soundSpeed_Copy
                //text: dev.soundSpeed
            }
        }

        SettingRow {
            toggle: false
            text: "Ch1 Period"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.ch1Period_Copy
                //text: dev.ch1Period
            }

        }

        SettingRow {
            toggle: false
            text: "Show chart"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.datasetChart_Copy ? "On" : "Off"
                //text: dev.datasetChart ? "On" : "Off"
            }
        }

        SettingRow {
            toggle: false
            text: "Use Distance"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.datasetDist_Copy ? "On" : "Off"
                //text: dev.datasetDist ? "On" : "Off"
            }
        }

        SettingRow {
            toggle: false
            text: "Use Distance NMEA"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.datasetSDDBT_Copy ? "On" : "Off"
                //text: dev.datasetSDDBT ? "On" : "Off"
            }
        }

        SettingRow {
            toggle: false
            text: "Use Euler"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.datasetEuler_Copy ? "On" : "Off"
                //text: dev.datasetEuler ? "On" : "Off"
            }
        }

        SettingRow {
            toggle: false
            text: "Use Temperature"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.datasetTemp_Copy ? "On" : "Off"
                //text: dev.datasetTemp ? "On" : "Off"
            }
        }

        SettingRow {
            toggle: false
            text: "Use Time Stamp"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatParameterInfo

            Text {
                font.pixelSize: 30
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
            text: "Is a 2D device?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.is2DTransducer
            }
        }

        SettingRow {
            toggle: false
            text: "Should use temperature?"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.useTemperature
            }
        }

        SettingRow {
            toggle: false
            text: "Temperature correction"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo && pulseRuntimeSettings.useTemperature
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.temperatureCorrection
            }
        }

        SettingRow {
            toggle: false
            text: "Frequency: wide"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.transFreqWide
            }
        }

        SettingRow {
            toggle: false
            text: "Frequency: medium"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.transFreqMedium
            }
        }

        SettingRow {
            toggle: false
            text: "Frequency: narrow"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.transFreqNarrow
            }
        }

        SettingRow {
            toggle: false
            text: "Maximum depth for App"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatAppConfigInfo
            Text {
                font.pixelSize: 30
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
                font.pixelSize: 30
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
                font.pixelSize: 30
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
                font.pixelSize: 30
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
                font.pixelSize: 30
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
                font.pixelSize: 30
                text: pulseRuntimeSettings.onSoundChanged === true ?
                          "OK" :
                          "Not verified (struggle?)"
            }
        }

        SettingRow {
            toggle: false
            text: "Echogram enabled"
            show: pulseRuntimeSettings.expertMode && pulseRuntimeSettings.showCatDebug
            Text {
                font.pixelSize: 30
                text: pulseRuntimeSettings.datasetChart_ok === true ?
                          "OK" :
                          "Not verified (struggle?)"
            }
        }

    }

}
