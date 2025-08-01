import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 1.2
import Qt.labs.settings 1.1
import org.techadvision.runtime 1.0

GridLayout {
    id: control

    property int numPlots: numPlotsSpinBox.value
    property bool syncPlots: plotSyncCheckBox.checked
    property int instruments: instrumentsGradeList.currentIndex
    property var targetPlot: null

    signal languageChanged(string langStr)
    signal syncPlotEnabled()

    function updateBottomTrack() {
        updateBottomTrackButton.clicked()
    }

    ColumnLayout {
        id: columnItem
        spacing: 24
        Layout.margins: 10

        ParamGroup {
            visible: instruments > 1

            groupName: qsTr("Plot")

            RowLayout {
                CText {
                    Layout.fillWidth: true
                    text: qsTr("Number of graphs:")
                }
                SpinBoxCustom {
                    id: numPlotsSpinBox
                    from: 1
                    to: 2
                    stepSize: 1
                    value: 1

                    Settings {
                        property alias numPlotsSpinBox: numPlotsSpinBox.value
                    }
                }
            }

            CCheck {
                id: plotSyncCheckBox
                Layout.fillWidth: true
                checked: false
                text: qsTr("Synchronization")
                visible: numPlotsSpinBox.value === 2

                onCheckedChanged: {
                    if (checked) {
                        syncPlotEnabled()
                    }
                }

                Settings {
                    property alias plotSyncCheckBox: plotSyncCheckBox.checked
                }
            }
        }

        ParamGroup {
            visible: instruments > 1

            groupName: qsTr("Dataset")

            RowLayout {

                CCheck {
                    id: fixBlackStripesCheckButton
                    Layout.fillWidth: true
                    checked: false
                    text: qsTr("FBS, f/b")

                    onCheckedChanged: core.fixBlackStripesState = fixBlackStripesCheckButton.checked
                    Component.onCompleted: core.fixBlackStripesState = fixBlackStripesCheckButton.checked

                    Settings {
                        property alias fixBlackStripesCheckButton: fixBlackStripesCheckButton.checked
                    }

                    Connections {
                        target: pulseRuntimeSettings !== null ? pulseRuntimeSettings : undefined
                        function onUserManualSetNameChanged () {
                            console.log("DEV_SETUP: DisplaySettings, fixBlackStripesCheckButton, onUserManualSetNameChanged - let's enable")
                            if (pulseRuntimeSettings === null) {
                                console.log("DEV_SETUP: fixBlackStripesCheckButton - pulseRuntimeSettings === null, abort")
                                return
                            }
                            if (pulseRuntimeSettings.userManualSetName === "...") {
                                console.log("DEV_SETUP: fixBlackStripesCheckButton - userManualSetName === ..., abort")
                                return
                            }
                            fixBlackStripesCheckButton.checked = true
                        }
                    }
                }

                SpinBoxCustom {
                    id: fixBlackStripesForwardStepsSpinBox
                    from: 0
                    to: 100
                    stepSize: 1
                    value: 15

                    onValueChanged: core.fixBlackStripesForwardSteps = fixBlackStripesForwardStepsSpinBox.currValue
                    Component.onCompleted: core.fixBlackStripesForwardSteps = fixBlackStripesForwardStepsSpinBox.currValue

                    property int currValue: value

                    validator: DoubleValidator {
                        bottom: Math.min(fixBlackStripesForwardStepsSpinBox.from, fixBlackStripesForwardStepsSpinBox.to)
                        top:  Math.max(fixBlackStripesForwardStepsSpinBox.from, fixBlackStripesForwardStepsSpinBox.to)
                    }

                    textFromValue: function(value, locale) {
                        return Number(value).toLocaleString(locale, 'f', 0)
                    }

                    valueFromText: function(text, locale) {
                        return Number.fromLocaleString(locale, text)
                    }

                    onCurrValueChanged: core.fixBlackStripesForwardSteps = currValue

                    Settings {
                        property alias fixBlackStripesForwardStepsSpinBox: fixBlackStripesForwardStepsSpinBox.value
                    }

                    Connections {
                        target: pulseRuntimeSettings !== null ? pulseRuntimeSettings : undefined
                        function onUserManualSetNameChanged () {
                            console.log("DEV_SETUP: DisplaySettings, fixBlackStripesForwardStepsSpinBox, onUserManualSetNameChanged - let's enable")
                            if (pulseRuntimeSettings === null) {
                                console.log("DEV_SETUP: fixBlackStripesForwardStepsSpinBox - pulseRuntimeSettings === null, abort")
                                return
                            }
                            if (pulseRuntimeSettings.userManualSetName === "...") {
                                console.log("DEV_SETUP: fixBlackStripesForwardStepsSpinBox - userManualSetName === ..., abort")
                                return
                            }
                            fixBlackStripesForwardStepsSpinBox.value = pulseRuntimeSettings.fixBlackStripesForwardSteps
                            console.log("DEV_SETUP: fixBlackStripesForwardStepsSpinBox - set value to", pulseRuntimeSettings.fixBlackStripesForwardSteps)
                        }
                    }
                }

                SpinBoxCustom {
                    id: fixBlackStripesBackwardStepsSpinBox
                    from: 0
                    to: 100
                    stepSize: 1
                    value: 15

                    onValueChanged: core.fixBlackStripesBackwardSteps = fixBlackStripesBackwardStepsSpinBox.currValue
                    Component.onCompleted: core.fixBlackStripesBackwardSteps = fixBlackStripesBackwardStepsSpinBox.currValue

                    property int currValue: value

                    validator: DoubleValidator {
                        bottom: Math.min(fixBlackStripesBackwardStepsSpinBox.from, fixBlackStripesBackwardStepsSpinBox.to)
                        top:  Math.max(fixBlackStripesBackwardStepsSpinBox.from, fixBlackStripesBackwardStepsSpinBox.to)
                    }

                    textFromValue: function(value, locale) {
                        return Number(value).toLocaleString(locale, 'f', 0)
                    }

                    valueFromText: function(text, locale) {
                        return Number.fromLocaleString(locale, text)
                    }

                    onCurrValueChanged: core.fixBlackStripesBackwardSteps = currValue

                    Settings {
                        property alias fixBlackStripesBackwardStepsSpinBox: fixBlackStripesBackwardStepsSpinBox.value
                    }

                    Connections {
                        target: pulseRuntimeSettings !== null ? pulseRuntimeSettings : undefined
                        function onUserManualSetNameChanged () {
                            console.log("DEV_SETUP: DisplaySettings, fixBlackStripesBackwardStepsSpinBox, onUserManualSetNameChanged - let's enable")
                            if (pulseRuntimeSettings === null) {
                                console.log("DEV_SETUP: fixBlackStripesBackwardStepsSpinBox - pulseRuntimeSettings === null, abort")
                                return
                            }
                            if (pulseRuntimeSettings.userManualSetName === "...") {
                                console.log("DEV_SETUP: fixBlackStripesBackwardStepsSpinBox - userManualSetName === ..., abort")
                                return
                            }
                            fixBlackStripesBackwardStepsSpinBox.value = pulseRuntimeSettings.fixBlackStripesBackwardSteps
                             console.log("DEV_SETUP: fixBlackStripesBackwardStepsSpinBox - set value to", pulseRuntimeSettings.fixBlackStripesBackwardSteps)
                        }
                    }
                }
            }
        }

        ParamGroup {
            visible: instruments > 0
            id: bottomTrackProcessingGroup
            groupName: qsTr("Bottom-Track processing")

            property bool autoApplyChange: false

            /*
            Component.onCompleted: {
                if (targetPlot) {
                    targetPlot.refreshDistParams(bottomTrackList.currentIndex,
                                                 bottomTrackWindow.checked ? bottomTrackWindowValue.value : 1,
                                                 bottomTrackVerticalGap.checked ? bottomTrackVerticalGapValue.value* 0.01 : 0,
                                                 bottomTrackMinRange.checked ? bottomTrackMinRangeValue.realValue : 0,
                                                 bottomTrackMaxRange.checked ? bottomTrackMaxRangeValue.realValue : 1000,
                                                 bottomTrackGainSlope.checked ? bottomTrackGainSlopeValue.realValue : 1,
                                                 bottomTrackThreshold.checked ? bottomTrackThresholdValue.realValue : 0,
                                                 bottomTrackSensorOffset.checked ? bottomTrackSensorOffsetValueX.value *  0.001 : 0,
                                                 bottomTrackSensorOffset.checked ? bottomTrackSensorOffsetValueY.value *  0.001 : 0,
                                                 bottomTrackSensorOffset.checked ? bottomTrackSensorOffsetValueZ.value * -0.001 : 0)
                }
            }
            */

            function updateProcessing() {
                if (targetPlot) {
                    targetPlot.doDistProcessing(bottomTrackList.currentIndex,
                                                bottomTrackWindow.checked ? bottomTrackWindowValue.value : 1,
                                                bottomTrackVerticalGap.checked ? bottomTrackVerticalGapValue.value*0.01 : 0,
                                                bottomTrackMinRange.checked ? bottomTrackMinRangeValue.realValue : 0,
                                                bottomTrackMaxRange.checked ? bottomTrackMaxRangeValue.realValue : 1000,
                                                bottomTrackGainSlope.checked ? bottomTrackGainSlopeValue.realValue : 1,
                                                bottomTrackThreshold.checked ? bottomTrackThresholdValue.realValue : 0,
                                                bottomTrackSensorOffset.checked ? bottomTrackSensorOffsetValueX.value*0.001 : 0,
                                                bottomTrackSensorOffset.checked ? bottomTrackSensorOffsetValueY.value*0.001 : 0,
                                                bottomTrackSensorOffset.checked ? -bottomTrackSensorOffsetValueZ.value*0.001 : 0
                                                );
                    console.log("DistProcessing: bottomTrackProcessingGroup, did doDistProcessing")
                }
            }

            function prepareDistProcessing () {
                let list = []
                list = dataset.channelsNameList()
                if (list.length < 3) {
                    console.log("DistProcessing: prepareDistProcessing, not enough channels:", list, ". Abort!")
                    return
                }
                if (pulseRuntimeSettings === null) {
                    console.log("DistProcessing: prepareDistProcessing, pulseRuntimeSettings === null. Abort")
                    return
                }
                if (pulseRuntimeSettings.userManualSetName === "...") {
                    console.log("DistProcessing: prepareDistProcessing, userManualSetName === .... Abort")
                    return
                }
                if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                    console.log("DistProcessing: prepareDistProcessing, pulseRuntimeSettings.userManualSetName", pulseRuntimeSettings.userManualSetName, ". Abort")
                    return
                }
                if (!pulseRuntimeSettings.processBottomTrack) {
                    console.log("DistProcessing: prepareDistProcessing, pulseRuntimeSettings.processBottomTrack", pulseRuntimeSettings.processBottomTrack, ". Abort")
                    return
                }
                // Configure everything
                console.log("DistProcessing: prepareDistProcessing, all checks OK - let's configure and then enable")

                //Make sure all checkboxes are unchecked
                bottomTrackWindow.checked = false
                bottomTrackVerticalGap.checked = false
                bottomTrackMinRange.checked = false
                bottomTrackMaxRange.checked = false
                bottomTrackGainSlope.checked = false
                bottomTrackThreshold.checked = false
                bottomTrackSensorOffset.checked = false

                //Set values
                bottomTrackWindowValue.value = pulseRuntimeSettings.distProcessing[1]
                bottomTrackVerticalGapValue.value = pulseRuntimeSettings.distProcessing[2]
                bottomTrackMinRangeValue.value = pulseRuntimeSettings.distProcessing[3] * 1000
                bottomTrackMaxRangeValue.value = pulseRuntimeSettings.distProcessing[4] * 1000
                bottomTrackGainSlopeValue.value = pulseRuntimeSettings.distProcessing[5] * 100
                bottomTrackThresholdValue.value = pulseRuntimeSettings.distProcessing[6]
                bottomTrackSensorOffsetValueX.value = pulseRuntimeSettings.distProcessing[7]
                bottomTrackSensorOffsetValueY.value = pulseRuntimeSettings.distProcessing[8]
                bottomTrackSensorOffsetValueZ.value = pulseRuntimeSettings.distProcessing[9]

                //Set proper preset
                bottomTrackList.currentIndex = pulseRuntimeSettings.distProcessing[0]

                //Enable select checkboxes
                bottomTrackWindow.checked = true
                bottomTrackVerticalGap.checked = true
                bottomTrackMinRange.checked = true
                bottomTrackMaxRange.checked = true
                bottomTrackGainSlope.checked = true
                bottomTrackThreshold.checked = false
                bottomTrackSensorOffset.checked = false

                //Go ahead
                bottomTrackProcessingGroup.startDistProcessing()
            }

            function startDistProcessing () {
                console.log("DistProcessing: bottomTrackProcessingGroup - let's configure")

                let channelsList = []
                channelsList = dataset.channelsNameList()

                if (channelsList.length < 3) {
                    console.log("DistProcessing: bottomTrackProcessingGroup - channels list length only",channelsList.length, ", abort")
                    return
                }
                console.log("DistProcessing: bottomTrackProcessingGroup - channels list OK",channelsList, ". Continue!")

                if (targetPlot) {
                    /*
                    targetPlot.refreshDistParams(bottomTrackList.currentIndex,
                                                 bottomTrackWindow.checked ? bottomTrackWindowValue.value : 1,
                                                 bottomTrackVerticalGap.checked ? bottomTrackVerticalGapValue.value* 0.01 : 0,
                                                 bottomTrackMinRange.checked ? bottomTrackMinRangeValue.realValue : 0,
                                                 bottomTrackMaxRange.checked ? bottomTrackMaxRangeValue.realValue : 1000,
                                                 bottomTrackGainSlope.checked ? bottomTrackGainSlopeValue.realValue : 1,
                                                 bottomTrackThreshold.checked ? bottomTrackThresholdValue.realValue : 0,
                                                 bottomTrackSensorOffset.checked ? bottomTrackSensorOffsetValueX.value *  0.001 : 0,
                                                 bottomTrackSensorOffset.checked ? bottomTrackSensorOffsetValueY.value *  0.001 : 0,
                                                 bottomTrackSensorOffset.checked ? bottomTrackSensorOffsetValueZ.value * -0.001 : 0)
                    console.log("DistProcessing: bottomTrackProcessingGroup, did refreshDistParams")
                    */
                    bottomTrackProcessingGroup.updateProcessing()
                    triggerProcessingTimer.start()
                } else {
                    console.log("DistProcessing: bottomTrackProcessingGroup, could not refreshDistParams since no target plot")
                }
            }

            Connections {
                target: core
                function onChannelListUpdated() {
                    bottomTrackProcessingGroup.prepareDistProcessing()
                }
            }

            Connections {
                target: pulseRuntimeSettings !== null ? pulseRuntimeSettings : undefined

                function onProcessBottomTrackChanged () {
                    if (pulseRuntimeSettings === null) {
                        console.log("DistProcessing: onProcessBottomTrackChanged - pulseRuntimeSettings === null, abort")
                        return
                    }
                    if (pulseRuntimeSettings.userManualSetName === "...") {
                        console.log("DistProcessing: onProcessBottomTrackChanged - userManualSetName === ..., abort")
                        return
                    }
                    if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                        console.log("DistProcessing: onProcessBottomTrackChanged - userManualSetName ===", pulseRuntimeSettings.userManualSetName,", should not use bottom track")
                        return
                    }
                    if (pulseRuntimeSettings.processBottomTrack) {
                        //Turned on
                        console.log("DistProcessing: onProcessBottomTrackChanged - let us initiate tracking")
                        bottomTrackProcessingGroup.prepareDistProcessing()
                    }
                }

                function onUserManualSetNameChanged () {
                    bottomTrackProcessingGroup.prepareDistProcessing()
                }

                function onDistProcessingChanged () {
                    if (pulseRuntimeSettings === null) {
                        console.log("DistProcessing: bottomTrackWindowValue - pulseRuntimeSettings === null, abort")
                        return
                    }
                    if (pulseRuntimeSettings.userManualSetName === "...") {
                        console.log("DistProcessing: bottomTrackWindowValue - userManualSetName === ..., abort")
                        return
                    }
                    if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                        console.log("DistProcessing: bottomTrackWindowValue - userManualSetName ===", pulseRuntimeSettings.userManualSetName,", should not use bottom track")
                        return
                    }
                    if (!pulseRuntimeSettings.processBottomTrack) {
                        console.log("DistProcessing: bottomTrackWindowValue - use bottom track", pulseRuntimeSettings.processBottomTrack)
                        return
                    }
                    console.log("DistProcessing: value of bottom track parameter will be changed")
                    pulseRuntimeSettings.isBottomTrackActive = false
                    pulseRuntimeSettings.isBottomTrackInitiated = false
                    if (dataset) {
                        dataset.setIsBottomTrackInitiated(false)
                        dataset.setIsBottomTrackActive(false)
                    }

                    triggerBottomTrackParameterChange.start()
                }
            }

            Timer {
                id: triggerBottomTrackParameterChange
                repeat: false
                interval: 100
                onTriggered: {
                    bottomTrackProcessingGroup.prepareDistProcessing()
                }
            }


            Timer {
                id: triggerProcessingTimer
                repeat: false
                interval: 1000
                onTriggered: {
                    pulseRuntimeSettings.processBottomTrack = true
                    pulseRuntimeSettings.isBottomTrackInitiated = true
                    if (dataset) {
                        dataset.setProcessBottomTrack(pulseRuntimeSettings.processBottomTrack)
                        dataset.setIsBottomTrackInitiated(pulseRuntimeSettings.isBottomTrackInitiated)
                    }
                }
            }

            RowLayout {
                ParamSetup {
                    paramName: qsTr("Preset:")

                    CCombo  {
                        id: bottomTrackList
                        //                        Layout.fillWidth: true
                        Layout.preferredWidth: 250
                        model: [qsTr("Normal 2D"), qsTr("Narrow 2D"), qsTr("Echogram Side-Scan")]
                        currentIndex: 0

//                        onCurrentIndexChanged: bottomTrackProcessingGroup.updateProcessing()

                        onCurrentIndexChanged: {
                            if (targetPlot) {
                                targetPlot.setPreset(bottomTrackList.currentIndex)
                            }
                        }

                        Settings {
                            property alias bottomTrackList: bottomTrackList.currentIndex
                        }
                    }
                }
            }

            RowLayout {
                CCheck {
                    id: bottomTrackGainSlope
                    Layout.fillWidth: true
                    text: qsTr("Gain slope:")

                    onCheckedChanged: {
                        if (checked) {
                            if (targetPlot) {
                                targetPlot.setGainSlope(bottomTrackGainSlopeValue.realValue)
                            }
                        }
                    }

                    Settings {
                        property alias bottomTrackGainSlope: bottomTrackGainSlope.checked
                    }
                }

                SpinBoxCustom {
                    id: bottomTrackGainSlopeValue
                    from: 0
                    to: 300
                    stepSize: 10
                    value: 100

                    property int decimals: 2
                    property real realValue: value / 100

                    validator: DoubleValidator {
                        bottom: Math.min(bottomTrackGainSlopeValue.from, bottomTrackGainSlopeValue.to)
                        top:  Math.max(bottomTrackGainSlopeValue.from, bottomTrackGainSlopeValue.to)
                    }

                    textFromValue: function(value, locale) {
                        return Number(value / 100).toLocaleString(locale, 'f', decimals)
                    }

                    valueFromText: function(text, locale) {
                        return Number.fromLocaleString(locale, text) * 100
                    }

                    onRealValueChanged: {
                        if (bottomTrackGainSlope.checked) {
                            if (targetPlot) {
                                targetPlot.setGainSlope(bottomTrackGainSlopeValue.realValue)
                            }
                        }
                    }

                    Settings {
                        property alias bottomTrackGainSlopeValue: bottomTrackGainSlopeValue.value
                    }
                }
            }

            RowLayout {
                CCheck {
                    id: bottomTrackThreshold
                    Layout.fillWidth: true
                    text: qsTr("Threshold:")

                    onCheckedChanged: {
                        if (checked) {
                            if (targetPlot) {
                                targetPlot.setThreshold(bottomTrackThresholdValue.realValue)
                            }
                        }
                    }

                    Settings {
                        property alias bottomTrackThreshold: bottomTrackThreshold.checked
                    }
                }

                SpinBoxCustom {
                    id: bottomTrackThresholdValue
                    from: 0
                    to: 200
                    stepSize: 5
                    value: 0

                    property int decimals: 2
                    property real realValue: value / 100

                    validator: DoubleValidator {
                        bottom: Math.min(bottomTrackThresholdValue.from, bottomTrackThresholdValue.to)
                        top:  Math.max(bottomTrackThresholdValue.from, bottomTrackThresholdValue.to)
                    }

                    textFromValue: function(value, locale) {
                        return Number(value / 100).toLocaleString(locale, 'f', decimals)
                    }

                    valueFromText: function(text, locale) {
                        return Number.fromLocaleString(locale, text) * 100
                    }

                    onRealValueChanged: {
                        if (bottomTrackThreshold.checked) {
                            if (targetPlot) {
                                targetPlot.setThreshold(bottomTrackThresholdValue.realValue)
                            }
                        }
                    }

                    Settings {
                        property alias bottomTrackThresholdValue: bottomTrackThresholdValue.value
                    }
                }
            }

            RowLayout {
                CCheck {
                    id: bottomTrackWindow
                    Layout.fillWidth: true
                    text: qsTr("Horizontal window:")

                    onCheckedChanged: {
                        if (checked) {
                            if (targetPlot) {
                                targetPlot.setWindowSize(bottomTrackWindowValue.value)
                            }
                        }
                    }

                    Settings {
                        property alias bottomTrackWindow: bottomTrackWindow.checked
                    }
                }

                SpinBoxCustom {
                    id: bottomTrackWindowValue
                    from: 1
                    to: 100
                    stepSize: 2
                    value: 1

                    onValueChanged: {
                        if (bottomTrackWindow.checked) {
                            if (targetPlot) {
                                targetPlot.setWindowSize(bottomTrackWindowValue.value)
                            }
                        }
                    }

                    Settings {
                        property alias bottomTrackWindowValue: bottomTrackWindowValue.value
                    }

                }
            }


            RowLayout {
                CCheck {
                    id: bottomTrackVerticalGap
                    Layout.fillWidth: true
                    text: qsTr("Vertical gap, %:")
//                    onCheckedChanged: bottomTrackProcessingGroup.updateProcessing()

                    onCheckedChanged: {
                        if (checked) {
                            if (targetPlot) {
                                targetPlot.setVerticalGap(bottomTrackVerticalGapValue.value * 0.01)
                            }
                        }
                    }

                    Settings {
                        property alias bottomTrackVerticalGap: bottomTrackVerticalGap.checked
                    }
                }

                SpinBoxCustom {
                    id: bottomTrackVerticalGapValue
                    from: 0
                    to: 100
                    stepSize: 2
                    value: 10
//                    onValueChanged: bottomTrackProcessingGroup.updateProcessing()

                    onValueChanged: {
                        if (bottomTrackVerticalGap.checked) {
                            if (targetPlot) {
                                targetPlot.setVerticalGap(bottomTrackVerticalGapValue.value * 0.01)
                            }
                        }
                    }

                    Settings {
                        property alias bottomTrackVerticalGapValue: bottomTrackVerticalGapValue.value
                    }
                }
            }

            RowLayout {
                CCheck {
                    id: bottomTrackMinRange
                    Layout.fillWidth: true
                    text: qsTr("Min range, m:")
//                    onCheckedChanged: bottomTrackProcessingGroup.updateProcessing()

                    onCheckedChanged: {
                        if (checked) {
                            if (targetPlot) {
                                targetPlot.setRangeMin(bottomTrackMinRangeValue.realValue)
                            }
                        }
                    }

                    Settings {
                        property alias bottomTrackMinRange: bottomTrackMinRange.checked
                    }
                }


                SpinBoxCustom {
                    id: bottomTrackMinRangeValue
                    from: 0
                    to: 200000
                    stepSize: 10
                    value: 0

                    property int decimals: 2
                    property real realValue: value / 1000

                    validator: DoubleValidator {
                        bottom: Math.min(bottomTrackMinRangeValue.from, bottomTrackMinRangeValue.to)
                        top:  Math.max(bottomTrackMinRangeValue.from, bottomTrackMinRangeValue.to)
                    }

                    textFromValue: function(value, locale) {
                        return Number(value / 1000).toLocaleString(locale, 'f', decimals)
                    }

                    valueFromText: function(text, locale) {
                        return Number.fromLocaleString(locale, text) * 1000
                    }

//                    onRealValueChanged: bottomTrackProcessingGroup.updateProcessing()

                    onRealValueChanged: {
                        if (bottomTrackMinRange.checked) {
                            if (targetPlot) {
                                targetPlot.setRangeMin(bottomTrackMinRangeValue.realValue)
                            }
                        }
                    }

                    Settings {
                        property alias bottomTrackMinRangeValue: bottomTrackMinRangeValue.value
                    }
                }
            }

            RowLayout {
                CCheck {
                    id: bottomTrackMaxRange
                    Layout.fillWidth: true
                    text: qsTr("Max range, m:")
//                    onCheckedChanged: bottomTrackProcessingGroup.updateProcessing()

                    onCheckedChanged: {
                        if (checked) {
                            if (targetPlot) {
                                targetPlot.setRangeMax(bottomTrackMaxRangeValue.realValue)
                            }
                        }
                    }

                    Settings {
                        property alias bottomTrackMaxRange: bottomTrackMaxRange.checked
                    }
                }

                SpinBoxCustom {
                    id: bottomTrackMaxRangeValue
                    from: 0
                    to: 200000
                    stepSize: 1000
                    value: 100000

                    property int decimals: 2
                    property real realValue: value / 1000

                    validator: DoubleValidator {
                        bottom: Math.min(bottomTrackMaxRangeValue.from, bottomTrackMaxRangeValue.to)
                        top:  Math.max(bottomTrackMaxRangeValue.from, bottomTrackMaxRangeValue.to)
                    }

                    textFromValue: function(value, locale) {
                        return Number(value / 1000).toLocaleString(locale, 'f', decimals)
                    }

                    valueFromText: function(text, locale) {
                        return Number.fromLocaleString(locale, text) * 1000
                    }

//                    onRealValueChanged: bottomTrackProcessingGroup.updateProcessing()

                    onRealValueChanged: {
                        if (bottomTrackMaxRange.checked) {
                            if (targetPlot) {
                                targetPlot.setRangeMax(bottomTrackMaxRangeValue.realValue)
                            }
                        }
                    }

                    Settings {
                        property alias bottomTrackMaxRangeValue: bottomTrackMaxRangeValue.value
                    }
                }
            }

            RowLayout {
                CCheck {
                    id: bottomTrackSensorOffset
                    Layout.fillWidth: true
                    text: qsTr("Sonar offset XYZ, mm:")
//                    onCheckedChanged: bottomTrackProcessingGroup.updateProcessing()

                    onCheckedChanged: {
                        if (checked) {
                            if (targetPlot) {
                                targetPlot.setOffsetX(bottomTrackSensorOffsetValueX.value * 0.001)
                                targetPlot.setOffsetY(bottomTrackSensorOffsetValueY.value * 0.001)
                                targetPlot.setOffsetZ(bottomTrackSensorOffsetValueZ.value * 0.001)
                            }
                        }
                    }

                    Settings {
                        property alias bottomTrackSensorOffset: bottomTrackSensorOffset.checked
                    }
                }

                SpinBoxCustom {
                    id: bottomTrackSensorOffsetValueX
                    spinner: false
                    implicitWidth: 65
                    from: -9999
                    to: 9999
                    stepSize: 50

//                    onRealValueChanged: bottomTrackProcessingGroup.updateProcessing()

                    onValueChanged: {
                        if (bottomTrackSensorOffset.checked) {
                            if (targetPlot) {
                                targetPlot.setOffsetX(bottomTrackSensorOffsetValueX.value * 0.001)
                            }
                        }
                    }

                    Settings {
                        property alias bottomTrackSensorOffsetValueX: bottomTrackSensorOffsetValueX.value
                    }
                }

                SpinBoxCustom {
                    id: bottomTrackSensorOffsetValueY
                    spinner: false
                    implicitWidth: 65
                    from: -9999
                    to: 9999
                    stepSize: 50

//                    onRealValueChanged: bottomTrackProcessingGroup.updateProcessing()

                    onValueChanged: {
                        if (bottomTrackSensorOffset.checked) {
                            if (targetPlot) {
                                targetPlot.setOffsetY(bottomTrackSensorOffsetValueY.value * 0.001)
                            }
                        }
                    }

                    Settings {
                        property alias bottomTrackSensorOffsetValueY: bottomTrackSensorOffsetValueY.value
                    }
                }

                SpinBoxCustom {
                    id: bottomTrackSensorOffsetValueZ
                    spinner: false
                    implicitWidth: 65
                    from: -9999
                    to: 9999
                    stepSize: 50

//                    onRealValueChanged: bottomTrackProcessingGroup.updateProcessing()

                    onValueChanged: {
                        if (bottomTrackSensorOffset.checked) {
                            if (targetPlot) {
                                targetPlot.setOffsetZ(bottomTrackSensorOffsetValueZ.value * 0.001)
                            }
                        }
                    }

                    Settings {
                        property alias bottomTrackSensorOffsetValueZ: bottomTrackSensorOffsetValueZ.value
                    }
                }
            }

            RowLayout {
                CButton {
                    id: updateBottomTrackButton
                    text: qsTr("Processing")
                    Layout.fillWidth: true
                    onClicked: {
                        bottomTrackProcessingGroup.updateProcessing()
                    }
                }
            }
        }

        ParamGroup {
            visible: instruments > 0
            groupName: qsTr("Export")

            ColumnLayout {
                RowLayout {
                    CTextField {
                        id: exportPathText
                        hoverEnabled: true
                        Layout.fillWidth: true

                        // text: shortcuts.home // TODO

                        placeholderText: qsTr("Enter path")
                        Keys.onPressed: {
                        }
                    }


                    CButton {
                        text: "..."
                        Layout.fillWidth: false
                        onClicked: exportFileDialog.open()
                    }

                    FileDialog {
                        id: exportFileDialog
                        folder: shortcuts.home
                        selectExisting: true
                        selectFolder: true

                        onAccepted: {
                            exportPathText.text = exportFileDialog.folder.toString()
                        }

                        onRejected: { }
                    }

                    Settings {
                        property alias exportFolder: exportFileDialog.folder
                    }

                    Settings {
                        property alias exportFolderText: exportPathText.text
                    }
                }

                RowLayout {
                    CCheck {
                        id: exportDecimation
                        Layout.fillWidth: true
                        text: qsTr("Decimation, m:")
    //                    onCheckedChanged: bottomTrackProcessingGroup.updateProcessing()
                        Settings {
                            property alias exportDecimation: exportDecimation.checked
                        }
                    }

                    SpinBoxCustom {
                        id: exportDecimationValue
                        implicitWidth: 100
                        from: 0
                        to: 100
                        stepSize: 1
                        value: 10
                        Settings {
                            property alias exportDecimationValue: exportDecimationValue.value
                        }
                    }

                    CButton {
                        text: qsTr("Export to CSV")
                        Layout.fillWidth: true
                        onClicked: {
                            if (targetPlot) {
                                core.exportPlotAsCVS(exportPathText.text, targetPlot.plotDatasetChannel(), exportDecimation.checked ? exportDecimationValue.value : 0);
                            }
                        }
                    }
                }

                RowLayout {
                    CButton {
                        text: qsTr("Export to XTF")
                        Layout.fillWidth: true
                        onClicked: core.exportPlotAsXTF(exportPathText.text);
                    }
                }

                RowLayout {
                    CButton {
                        text: qsTr("Complex signal to CSV")
                        Layout.fillWidth: true
                        onClicked: core.exportComplexToCSV(exportPathText.text);
                    }
                }

                RowLayout {
                    CButton {
                        text: qsTr("USBL to CSV")
                        Layout.fillWidth: true
                        onClicked: core.exportUSBLToCSV(exportPathText.text);
                    }
                }

            }
        }

        ParamGroup {
            groupName: qsTr("Preference")

            ParamSetup {
                paramName: qsTr("Language:")

                CCombo  {
                    id: appLanguage
                    Layout.fillWidth: true
                    model: [qsTr("English"), qsTr("Russian"), qsTr("Polish")]
                    currentIndex: 0

                    function getLanguageByIndex(index) {
                            switch (index) {
                                case 0:
                                    return qsTr("English");
                                case 1:
                                    return qsTr("Russian");
                                case 2:
                                    return qsTr("Polish");
                                default:
                                    return qsTr("English");
                            }
                        }

                    onCurrentIndexChanged: {
                        control.languageChanged(getLanguageByIndex(currentIndex))
                    }

                    Settings {
                        property alias appLanguage: appLanguage.currentIndex
                    }
                }
            }

            ParamSetup {
                paramName: qsTr("Display theme:")

                CCombo  {
                    id: appTheme
                    Layout.fillWidth: true
                    model: [qsTr("Dark"), qsTr("Super Dark"), qsTr("Light"), qsTr("Super Light")]
                    currentIndex: 0

                    onCurrentIndexChanged: theme.themeID = currentIndex
                    Component.onCompleted: theme.themeID = currentIndex

                    Settings {
                        property alias appTheme: appTheme.currentIndex
                    }
                }
            }

            ParamSetup {
                paramName: qsTr("Instrumets grade:")

                CCombo  {
                    id: instrumentsGradeList
                    Layout.fillWidth: true
                    model: [qsTr("Fish Finders"), qsTr("Bottom Tracking"), qsTr("Maximum")]
                    currentIndex: 0

                    onCurrentIndexChanged: theme.instrumentsGrade = currentIndex
                    Component.onCompleted: theme.instrumentsGrade = currentIndex

                    Settings {
                        property alias instrumentsGradeList: instrumentsGradeList.currentIndex
                    }
                }
            }
        }

        ParamGroup {
            visible: instruments > 1
            groupName: qsTr("Interface")

            CCheck {
                id: consoleVisible
                text: qsTr("Console")

                onCheckedChanged: theme.consoleVisible = checked
                Component.onCompleted: theme.consoleVisible = checked

                Settings {
                    property alias consoleVisible: consoleVisible.checked
                }
            }
        }
    }
}
