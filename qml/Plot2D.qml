import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
//import QtQuick.Dialogs 1.2
//import Qt.labs.settings 1.1
//import Echo.UI 1.0
import QtQuick.Dialogs
import QtCore
import Echo.UI 1.0
import QtQuick.Window


import WaterFall 1.0

WaterFall {
    id: plot

    property bool is3dVisible: false
    property int indx: 0
    property int instruments: instrumentsGradeList.currentIndex
    property bool settingsOpen: plotCheckButton.checked
    property bool hasTransientUi: menuBlock.visible || contactDialog.visible
    property bool loupeZoomAdjusting: false
    property bool loupeZoomWasVisibleBeforeAdjust: false
    property int loupeZoomSavedAimEpoch: -1
    property real settingsMenuSpacer: Math.max(4, Math.round(theme.controlHeight * 0.2))

    horizontal: horisontalVertical.checked

    //Component.onCompleted: plot.setSettingsBus(settingsBus)

    function setLevels(low, high) {
        echogramLevelsSlider.startValue = low
        echogramLevelsSlider.stopValue = high
        echogramLevelsSlider.startPointY = echogramLevelsSlider.valueToPosition(low);
        echogramLevelsSlider.stopPointY = echogramLevelsSlider.valueToPosition(high);
        echogramLevelsSlider.update()
    }

    function updateBottomTrackPresentation() {
        const showValue = bottomTrackValueVisible.checked
        const showLine = bottomTrackGraphicsVisible.checked

        plotBottomTrackDepthTextVisible(showValue)
        plotBottomTrackTheme(showLine ? (bottomTrackThemeList.currentIndex + 1) : 0)
        plotBottomTrackVisible(showValue || showLine)
    }

    function updateRangefinderPresentation() {
        const showValue = rangefinderValueVisible.checked
        const showLine = rangefinderGraphicsVisible.checked

        plotRangefinderDepthTextVisible(showValue)
        plotRangefinderTheme(showLine ? (rangefinderThemeList.currentIndex + 1) : 0)
        plotRangefinderVisible(showValue || showLine)
    }

    function beginLoupeZoomPreview() {
        if (loupeZoomAdjusting) {
            return
        }

        loupeZoomAdjusting = true
        loupeZoomWasVisibleBeforeAdjust = loupeVisible.checked
        loupeZoomSavedAimEpoch = getAimEpochIndex()

        if (!loupeVisible.checked) {
            loupeVisible.checked = true
        }

        const previewEpoch = getPreferredLoupeEpochIndex(loupeZoomSavedAimEpoch)
        setAimEpochIndex(previewEpoch)
    }

    function updateLoupeZoomPreview() {
        if (!loupeZoomAdjusting) {
            return
        }

        const previewEpoch = getPreferredLoupeEpochIndex(getAimEpochIndex())
        setAimEpochIndex(previewEpoch)
    }

    function endLoupeZoomPreview() {
        if (!loupeZoomAdjusting) {
            return
        }

        loupeZoomAdjusting = false
        if (loupeZoomSavedAimEpoch >= 0) {
            setAimEpochIndex(loupeZoomSavedAimEpoch)
        }
        else {
            setAimEpochIndex(-1)
            resetAim()
        }

        if (!loupeZoomWasVisibleBeforeAdjust) {
            loupeVisible.checked = false
        }

        loupeZoomSavedAimEpoch = -1
    }

    function closeSettings() {
        if (!plotCheckButton.checked) {
            return false
        }
        plotCheckButton.checked = false
        return true
    }

    function toggleEchogramType() {
        if (echogramTypesList.count <= 0) {
            return
        }

        echogramTypesList.currentIndex = (echogramTypesList.currentIndex + 1) % echogramTypesList.count
    }

    function closeTransientUi() {
        let handled = false

        if (menuBlock.visible) {
            menuBlock.visible = false
            handled = true
        }

        if (contactDialog.visible) {
            contactDialog.visible = false
            handled = true
        }

        return handled
    }

    function setAim(mouseX, mouseY) {
        plotMousePosition(mouseX, mouseY, true)
    }
    function resetAim() {
        plotMousePosition(-1, -1)
    }
    function doVerZoomEvent(paramX) {
        verZoomEvent(paramX)
    }
    function doVerScrollEvent(paramX) {
        verScrollEvent(paramX)
    }

    onEnabledChanged: {
        if (enabled) {
            update();
        }
    }

    Connections {
        target: deviceManagerWrapper
        function onMavlinkWasDetected () {
            pulseRuntimeSettings.mavlinkDetected = deviceManagerWrapper.mavlinkDetected
            console.log("AddWaypoint: deviceManagerWrapper.mavlinkDetected", deviceManagerWrapper.mavlinkDetected)
        }
    }

    Connections {
        target: pulseRuntimeSettings

        function onDevManualSelectedChanged () {
            if (pulseRuntimeSettings === null)
                return
            if(pulseRuntimeSettings.devName === "...")
                return
            // PULSE TVG: centralized id resolution — side-scan 1, 2D = TVG (2) when enabled, else raw (0)
            let comp = pulseRuntimeSettings.resolveEchogramCompensation()
            console.log("EchogramCompensation: Plot2D onDevManualSelectedChanged, resolved", comp)
            plot.plotEchogramCompensation(comp)
            pulseRuntimeSettings.echogramCompensationFile = comp
            console.log("EchogramCompensation: Plot2D onDevManualSelectedChanged, value now", plot.getEchogramCompensation())
        }

        // userManualSetName is the reliable trigger: it is set by every selection path (manual tap
        // in main.qml, AND the ConnectionViewer.selectCorrectDevice auto-detect path, which never
        // toggles devManualSelected). Nail compensation here too, without gating on devName, since
        // the decision only depends on the resolved model / is2DTransducer, not on whether the raw
        // device identity string has arrived yet.
        function onUserManualSetNameChanged () {
            if (pulseRuntimeSettings === null)
                return
            if (pulseRuntimeSettings.userManualSetName === "...")
                return
            // PULSE TVG: centralized id resolution — side-scan 1, 2D = TVG (2) when enabled, else raw (0)
            let comp = pulseRuntimeSettings.resolveEchogramCompensation()
            console.log("EchogramCompensation: Plot2D onUserManualSetNameChanged, resolved", comp)
            plot.plotEchogramCompensation(comp)
            pulseRuntimeSettings.echogramCompensationFile = comp
            console.log("EchogramCompensation: Plot2D onUserManualSetNameChanged, value now", plot.getEchogramCompensation())
        }

        // PULSE: the model that is actually rendering changed — a device was identified,
        // a device was swapped, or a demo prescan classified the log. This is the ONE
        // place that guarantees C++ holds the full QML parameter set BEFORE the
        // compensation id switches.
        //
        // Needed because every per-parameter push lives in an individual toggle handler,
        // and now that the TVG toggles default ON from the device profile a session can
        // reach a TVG image type without any of those handlers ever having fired. The C++
        // defaults happen to match the QML defaults today, so this is belt and braces
        // rather than a live bug — but it stops the two drifting apart silently.
        function onActiveModelChanged () {
            if (pulseRuntimeSettings === null)
                return
            console.log("EchogramCompensation: Plot2D onActiveModelChanged ->",
                        pulseRuntimeSettings.activeModel === "" ? "(none committed)"
                                                                : pulseRuntimeSettings.activeModel)

            plot.setTvgDbPerMeter(pulseRuntimeSettings.echogramTvgDbPerMeter)
            plot.setSsTvgSpreading(pulseRuntimeSettings.sideScanTvgSpreading)
            plot.setSsTvgAbsorption(pulseRuntimeSettings.sideScanTvgAbsorption)
            plot.setSsTvgRefRange(pulseRuntimeSettings.sideScanTvgRefRange)
            plot.setSsTvgNoiseFloor(pulseRuntimeSettings.sideScanTvgNoiseFloor)
            plot.setSsTvgBoost(pulseRuntimeSettings.sideScanTvgBoost)
            plot.setSsTvgMosaicEnabled(pulseRuntimeSettings.sideScanTvgMosaicEnabled)

            // Water body filter: its strength lives in a C++ atomic and is ONLY ever
            // pushed through applyFiltering(). Push it here so the filter is genuinely
            // active on both models from the first frame instead of waiting for the
            // tester to touch the filter slider. Gated so that with the filter switched
            // off the old (2D-only) behaviour is untouched.
            plot.setWaterBodyBottomGuard(pulseRuntimeSettings.echogramWaterBodyBottomMargin)
            if (pulseRuntimeSettings.echogramWaterBodyFilterEnabled
                    || pulseRuntimeSettings.is2DTransducer) {
                quickChangeObjects.applyFiltering(pulseSettings.filterRealValue)
            }

            let comp = pulseRuntimeSettings.resolveEchogramCompensation()
            console.log("EchogramCompensation: Plot2D onActiveModelChanged, resolved", comp)
            plot.plotEchogramCompensation(comp)
            pulseRuntimeSettings.echogramCompensationFile = comp
            plot.updatePlot()
        }

        // PULSE TVG (Stage A): expert toggle. Only ever switches between raw (0)
        // and TVG (2) — never touches an active side-scan AGC (1).
        function onEchogramTvgEnabledChanged () {
            if (pulseRuntimeSettings === null)
                return
            plot.setTvgDbPerMeter(pulseRuntimeSettings.echogramTvgDbPerMeter)
            let cur = plot.getEchogramCompensation()
            // Ignore 3 as well as 1: with the TVG flags now driven by the device profile
            // this handler also fires on a device SWAP, and a Red->Blue swap would
            // otherwise land here with side scan TVG (3) already correctly applied and
            // knock it back to raw (0). The mirror guard in onSideScanTvgEnabledChanged
            // already covered both 2D ids; this one only covered the AGC.
            if (cur === 1 || cur === 3) {
                console.log("EchogramCompensation: TVG toggle ignored, side scan compensation active (", cur, ")")
                return
            }
            let comp = pulseRuntimeSettings.echogramTvgEnabled ? 2 : 0
            console.log("EchogramCompensation: Plot2D onEchogramTvgEnabledChanged, resolved", comp)
            plot.plotEchogramCompensation(comp)
            pulseRuntimeSettings.echogramCompensationFile = comp
        }

        // PULSE TVG: live tuning of the decay constant (dB/m); the C++ side
        // refreshes the echogram itself when TVG is the active compensation.
        function onEchogramTvgDbPerMeterChanged () {
            if (pulseRuntimeSettings === null)
                return
            console.log("EchogramCompensation: TVG dB/m ->", pulseRuntimeSettings.echogramTvgDbPerMeter)
            plot.setTvgDbPerMeter(pulseRuntimeSettings.echogramTvgDbPerMeter)
        }

        // PULSE side scan TVG: expert toggle. Only ever switches between the
        // side scan AGC (1) and side scan TVG (3) — never touches an active
        // 2D compensation (0/2).
        function onSideScanTvgEnabledChanged () {
            if (pulseRuntimeSettings === null)
                return
            // push the full parameter set so C++ matches QML before switching
            plot.setSsTvgSpreading(pulseRuntimeSettings.sideScanTvgSpreading)
            plot.setSsTvgAbsorption(pulseRuntimeSettings.sideScanTvgAbsorption)
            plot.setSsTvgRefRange(pulseRuntimeSettings.sideScanTvgRefRange)
            plot.setSsTvgNoiseFloor(pulseRuntimeSettings.sideScanTvgNoiseFloor)
            plot.setSsTvgBoost(pulseRuntimeSettings.sideScanTvgBoost)
            let cur = plot.getEchogramCompensation()
            if (cur === 0 || cur === 2) {
                console.log("EchogramCompensation: side scan TVG toggle ignored, 2D compensation active")
                return
            }
            let comp = pulseRuntimeSettings.sideScanTvgEnabled ? 3 : 1
            console.log("EchogramCompensation: Plot2D onSideScanTvgEnabledChanged, resolved", comp)
            plot.plotEchogramCompensation(comp)
            pulseRuntimeSettings.echogramCompensationFile = comp
        }

        // PULSE side scan TVG: live tuning — C++ refreshes the echogram
        // itself whenever side scan TVG (3) is the active compensation.
        function onSideScanTvgSpreadingChanged () {
            if (pulseRuntimeSettings === null)
                return
            console.log("EchogramCompensation: side scan TVG spreading ->", pulseRuntimeSettings.sideScanTvgSpreading)
            plot.setSsTvgSpreading(pulseRuntimeSettings.sideScanTvgSpreading)
        }
        function onSideScanTvgAbsorptionChanged () {
            if (pulseRuntimeSettings === null)
                return
            console.log("EchogramCompensation: side scan TVG absorption ->", pulseRuntimeSettings.sideScanTvgAbsorption)
            plot.setSsTvgAbsorption(pulseRuntimeSettings.sideScanTvgAbsorption)
        }
        function onSideScanTvgRefRangeChanged () {
            if (pulseRuntimeSettings === null)
                return
            console.log("EchogramCompensation: side scan TVG ref range ->", pulseRuntimeSettings.sideScanTvgRefRange)
            plot.setSsTvgRefRange(pulseRuntimeSettings.sideScanTvgRefRange)
        }
        function onSideScanTvgNoiseFloorChanged () {
            if (pulseRuntimeSettings === null)
                return
            console.log("EchogramCompensation: side scan TVG noise floor ->", pulseRuntimeSettings.sideScanTvgNoiseFloor)
            plot.setSsTvgNoiseFloor(pulseRuntimeSettings.sideScanTvgNoiseFloor)
        }
        function onSideScanTvgBoostChanged () {
            if (pulseRuntimeSettings === null)
                return
            console.log("EchogramCompensation: side scan TVG boost ->", pulseRuntimeSettings.sideScanTvgBoost)
            plot.setSsTvgBoost(pulseRuntimeSettings.sideScanTvgBoost)
        }
        function onSideScanTvgMosaicEnabledChanged () {
            if (pulseRuntimeSettings === null)
                return
            console.log("EchogramCompensation: side scan TVG mosaic ->", pulseRuntimeSettings.sideScanTvgMosaicEnabled)
            plot.setSsTvgMosaicEnabled(pulseRuntimeSettings.sideScanTvgMosaicEnabled)
        }

        // PULSE water-body filter (Stage B): re-route the current filter value
        // through the selected mode whenever the expert toggle flips.
        function onEchogramWaterBodyFilterEnabledChanged () {
            if (pulseRuntimeSettings === null)
                return
            console.log("WaterBodyFilter: toggle ->", pulseRuntimeSettings.echogramWaterBodyFilterEnabled)
            plot.setWaterBodyBottomGuard(pulseRuntimeSettings.echogramWaterBodyBottomMargin)
            quickChangeObjects.applyFiltering(pulseSettings.filterRealValue)
            plot.updatePlot()
        }

        // PULSE water-body filter: live tuning of the bottom guard (m); the
        // C++ side refreshes the echogram itself when the filter is active.
        function onEchogramWaterBodyBottomMarginChanged () {
            if (pulseRuntimeSettings === null)
                return
            console.log("WaterBodyFilter: bottom margin ->", pulseRuntimeSettings.echogramWaterBodyBottomMargin)
            plot.setWaterBodyBottomGuard(pulseRuntimeSettings.echogramWaterBodyBottomMargin)
        }
    }

    signal plotCursorChanged(int indx, real from, real to)
    signal updateOtherPlot(int indx)
    signal plotPressed(int indx, int mousex, int mousey)
    signal plotReleased(int indx)
    signal settingsClicked()
    signal echogramThemeChanged(int themeId)

    //Pulse additiona - Properties
    //****************************
    property int topMarginExpertMode: 0
    property real quickChangeMaxRangeValue: 15
    signal echogramWasZoomed(real updatedMaxValue)
    property bool isLiveView: true
    property real depthStepAccum: 0.0
    property int oldDataResetSeconds: 6

    //End of additiona - Properties
    //*****************************

    //Pulse additiona - On Screen Alerts
    //**********************************

    Connections {
        target: plot ? plot : undefined
        function onTimelinePositionChanged () {
        //onTimelinePositionChanged: {

            if (plot === null)
                return

            if (pulseRuntimeSettings.echogramPause)
                return

            // compute the new boolean
            var nowLive = plot.timelinePosition >= 0.999

            // only update (and log) when it actually flips
            if (nowLive !== pinch2D.isLiveView) {
                pinch2D.isLiveView = nowLive
                console.log("TAV: horizontal live-view is now", plot.isLiveView,
                            "timeline position", plot.timelinePosition,
                            "wasKlfFileOpened", pulseRuntimeSettings.wasKlfFileOpened)
                if (!pulseRuntimeSettings.wasKlfFileOpened) {
                    oldDataIndicator.visible = true
                    oldDataWarningRemovalTimer.restart()
                }
            }
            if (nowLive && oldDataIndicator.visible === true) {
                oldDataWarningRemovalTimer.stop()
                oldDataIndicator.visible = false
            }

        }
    }

    Timer {
        id: oldDataWarningRemovalTimer
        // keep single-shot timer; interval is derived from oldDataResetSeconds
        interval: oldDataResetSeconds * 1000
        repeat: false
        onTriggered: {
            // show "0" first, then wait 100 ms before hiding
            if (pulseRuntimeSettings.wasKlfFileOpened)
                return
            oldDataIndicator._setCountdown(0)
            hideDelayTimer.start()
        }
    }

    // tiny delay so users can *see* the zero
    Timer {
        id: hideDelayTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (pulseRuntimeSettings.wasKlfFileOpened)
                return
            oldDataIndicator.visible = false
            plot.timelinePosition = 1
        }
    }

    Rectangle {
        id: oldDataIndicator
        visible: false
        anchors.top: parent.top
        anchors.topMargin: 60 + insetTop()
        anchors.right: parent.right
        anchors.rightMargin: 20
        color: "#80000000"
        radius: height / 2
        property int contentMargin: 12
        implicitWidth: oldDataText.width + contentMargin*2
        implicitHeight: _isAndroid ? 80 : 60 //oldDataText.height + contentMargin*2 +5

        // NEW: countdown state
        property int _remaining: 0

        // helper to set text consistently
        function _setCountdown(v) {
            _remaining = v
            oldDataText.text = "Old data (" + _remaining + ")"
        }

        // per-second countdown
        Timer {
            id: countdownTimer
            interval: 1000
            repeat: true
            onTriggered: {
                // decrement but don't go negative—main timer handles the hide
                if (oldDataIndicator._remaining > 0) {
                    oldDataIndicator._setCountdown(oldDataIndicator._remaining - 1)
                } else if (oldDataIndicator._remaining === 0) {
                    // let it tick to 0 and stop; hideDelayTimer will fire next
                    stop()
                }
            }
        }

        Text {
            id: oldDataText
            text: "Old data"
            font.pixelSize: 40
            color: "white"
            anchors.centerIn: parent
        }

        // start/stop logic kept here to avoid touching other parts of the app
        onVisibleChanged: {
            if (visible) {
                plot.setHoldHistory(true)

                // (re)start countdown only if we're not paused
                if (!pauseDataIndicator.visible) {
                    countdownTimer.stop()
                    oldDataIndicator._setCountdown(oldDataResetSeconds)
                    // ensure main timer matches the configured seconds
                    oldDataWarningRemovalTimer.interval = oldDataResetSeconds * 1000
                    oldDataWarningRemovalTimer.restart()
                    countdownTimer.start()
                }
            } else {
                plot.setHoldHistory(false)
                countdownTimer.stop()
                hideDelayTimer.stop()
            }
        }
    }

    Rectangle {
        id: pauseDataIndicator
        visible: false
        anchors.top: parent.top
        anchors.topMargin: 60 + insetTop()
        anchors.right: parent.right
        anchors.rightMargin: 20
        color: "#80000000"
        radius: height / 2
        property int contentMargin: 12
        implicitWidth: oldDataText.width + contentMargin*2
        implicitHeight: _isAndroid ? 80 : 60 //oldDataText.height + contentMargin*2 +5

        Text {
            id: pausedDataText
            text: "paused"
            font.pixelSize: 40
            color: "white"
            anchors.centerIn: parent
        }

        // NEW: pause/unpause hooks
        onVisibleChanged: {
            if (visible) {
                // freeze everything while paused
                countdownTimer.stop()
                hideDelayTimer.stop()
                oldDataWarningRemovalTimer.stop()
            } else {
                // when un-paused, if "old data" is still showing, resume the countdown
                if (oldDataIndicator.visible && !pulseRuntimeSettings.wasKlfFileOpened) {
                    oldDataIndicator._setCountdown(oldDataResetSeconds)
                    oldDataWarningRemovalTimer.interval = oldDataResetSeconds * 1000
                    oldDataWarningRemovalTimer.restart()
                    countdownTimer.start()
                }
            }
        }
    }

    //DEMO MODE badge. Always visible while replaying so nobody mistakes a
    //recording for live sonar. Deliberately a LABEL, not a button: as a button it
    //invited taps (it fooled its own author), and stopping belongs where the demo
    //is started — the Recording tab. No MouseArea here on purpose.
    Rectangle {
        id: demoModeBadge
        visible: pulseRuntimeSettings.isInDemoMode
        anchors.top: parent.top
        anchors.topMargin: 60 + insetTop()
        anchors.horizontalCenter: parent.horizontalCenter

        color: "#B0000000"
        radius: height / 2
        property int contentMargin: 14
        implicitWidth: demoBadgeText.width + contentMargin * 2
        implicitHeight: _isAndroid ? 80 : 60

        Text {
            id: demoBadgeText
            text: qsTr("Demo")
            font.pixelSize: 32
            color: "white"
            anchors.centerIn: parent
        }
    }

    Rectangle {
        id: configurationInProgressIndicator
        // start hidden.
        // DEMO MODE: never offer to configure a device that is not there. During
        // a demo devConfigured is forced true anyway, but this also covers the
        // moment right after a demo ends.
        visible: !pulseRuntimeSettings.devConfigured
                 && pulseRuntimeSettings.dataUpdateActive
                 && !pulseRuntimeSettings.isInDemoMode
        anchors.top: parent.top
        anchors.topMargin: 60 + insetTop()
        anchors.left: parent.left
        anchors.leftMargin: 50

        // styling: semi-transparent black, rounded corners
        color: "#80000000"
        //opacity: 0.6
        radius: height / 2

        // padding around the text
        property int contentMargin: 12

        // size to fit the text + padding
        // (reference the Text's width, NOT the Rectangle's own width — the latter
        //  defaults back to implicitWidth and causes a binding loop)
        implicitWidth: completeDeviceConfigurationTimer.width + contentMargin*2
        implicitHeight: _isAndroid ? 80 : 60 //configurationInProgressText.height + contentMargin*2

        // the actual label
        Text {
            id: completeDeviceConfigurationTimer
            text: {
                if (pulseRuntimeSettings.isOpeningKlfFile || pulseRuntimeSettings.wasKlfFileOpened)
                    return ""
                if (pulseRuntimeSettings.isInDemoMode)
                    return ""
                if (pulseRuntimeSettings.unableToConfigure) {
                    return "Fixing transducer com link..."
                } else {
                    return "Configuring transducer..."
                }
            }
            font.pixelSize: 40
            color: "white"
            anchors.centerIn: parent
        }

        // Start/stop the timer when visibility changes
            onVisibleChanged: {
                if (visible) {
                    // ensure a fresh countdown each time it becomes visible
                    console.log("LinkManager: configure transducer, let us keep track and see if successful")
                    breakAndReconnectLinkTimer.stop()
                    breakAndReconnectLinkTimer.start()
                } else {
                    breakAndReconnectLinkTimer.stop()
                    pulseRuntimeSettings.unableToConfigure = false
                }
            }

            // Handle the case where we start already visible
            Component.onCompleted: {
                if (visible) {
                    breakAndReconnectLinkTimer.stop()
                    breakAndReconnectLinkTimer.start()
                }
            }
    }

    Timer {
        id: breakAndReconnectLinkTimer
        repeat: false
        interval: 10000
        onTriggered: {
            pulseRuntimeSettings.unableToConfigure = true
        }
    }

    //End of additiona - On Screen Alerts
    //***********************************

    PinchArea {
        id: pinch2D
        anchors.fill: parent
        enabled: true

        property int thresholdXAxis: 15
        property int thresholdYAxis: 15
        property double zoomThreshold: 0.1

        property bool movementX: false
        property bool movementY: false
        property bool zoomY: false
        property point pinchStartPos: Qt.point(-1, -1)
        //Pulse additions
        property bool zoomX: false
        property double oldSpeed: pulseSettings.echogramSpeed
        //property double oldSpeed: pulseRuntimeSettings.echogramSpeed
        property bool isLiveView: true
        //***************

        function clearPinchMovementState() {
            movementX = false
            movementY = false
            zoomY = false
            //Pulse additions
            zoomX = false
            //oldSpeed = pulseRuntimeSettings.echogramSpeed
            oldSpeed = pulseSettings.echogramSpeed
            // Reset the side-scan max-depth step accumulator at the start/end of every pinch.
            // If left to carry over, the leftover positive fraction from a zoom-out gesture makes
            // the next zoom-in need a much larger move before a step fires, so in practice only
            // zoom-out (increase) ever registered. Resetting makes both directions symmetric.
            depthStepAccum = 0.0
            //***************
        }

        onPinchStarted: {
            menuBlock.visible = false

            mousearea.enabled = false
            plot.plotMousePosition(-1, -1)

            clearPinchMovementState()
            pinchStartPos = Qt.point(pinch.center.x, pinch.center.y)

            //Pulse additions
            var p1 = pinch.startPoint1
            var p2 = pinch.startPoint2
            var dx = p2.x - p1.x
            var dy = p2.y - p1.y

            // dead-zone multiplier: require ~30% more dispersion in one axis
            if (Math.abs(dx) > Math.abs(dy) * 1.3) {
                zoomX = true       // fingers are laid out more horizontally
            } else if (Math.abs(dy) > Math.abs(dx) * 1.3) {
                zoomY = true       // fingers are stacked more vertically
            } else {
                // ambiguous (near diagonal) → fall back to vertical zoom
                zoomY = true
            }
            //***************
        }

        onPinchUpdated: {
            //console.info("onPinchUpdated")

            if (movementX) {
                let val = -(pinch.previousCenter.x - pinch.center.x)
                plot.horScrollEvent(val)
                console.log("pinch: scrolled x-way")
                updateOtherPlot(indx)
            }
            else if (movementY) {
                let val = pinch.previousCenter.y - pinch.center.y
                plot.verScrollEvent(val)
                console.log("pinch: scrolled y-way")
                plotCursorChanged(indx, cursorFrom(), cursorTo())
            }

            //Pulse additions
            if (!movementX && !movementY && !zoomX && !zoomY) {
                if (Math.abs(pinchStartPos.x - pinch.center.x) > thresholdXAxis) {
                    movementX = true
                }
                else if (Math.abs(pinchStartPos.y - pinch.center.y) > thresholdYAxis) {
                    movementY = true
                }
                // pinch.scale is uniform but we can infer axis by center movement
                else if (pinch.scale > 1.0 + zoomThreshold || pinch.scale < 1.0 - zoomThreshold) {
                    var dx = Math.abs(pinch.center.x - pinchStartPos.x)
                    var dy = Math.abs(pinch.center.y - pinchStartPos.y)
                }
            }
            //***************

            else if (zoomY) {
                //Pulse additions, replacing the logic
                if (pulseRuntimeSettings.is2DTransducer) {
                    plot.verZoomEvent((pinch.previousScale - pinch.scale)*100.0)
                    let newMaxDepthValue = Math.abs(plot.getMaxDepth())
                    plot.quickChangeMaxRangeValue = newMaxDepthValue
                    selectorMaxDepth.value = newMaxDepthValue
                } else {
                    // To overcome the complexity of blue, we modify the max depth picker directly instead of through the echogram
                    if (plot.isViewHorizontal()) {
                        let pinchDelta  = (pinch.previousScale - pinch.scale) * 10
                        depthStepAccum += pinchDelta
                        let steps = depthStepAccum > 0 ? Math.floor(depthStepAccum)
                                                       : Math.ceil(depthStepAccum)
                        if (steps !== 0) {
                            depthStepAccum -= steps   // keep the fractional remainder
                            let newVal = plot.quickChangeMaxRangeValue + steps
                            if (newVal < 1) newVal = 1
                            if (newVal > pulseRuntimeSettings.maximumDepth)
                                newVal = pulseRuntimeSettings.maximumDepth

                            plot.quickChangeMaxRangeValue = newVal
                            selectorMaxDepth.value = newVal
                        }
                    } else {
                        plot.verZoomEvent((pinch.previousScale - pinch.scale)*50.0)
                        let newMaxDepthValue = Math.abs(plot.getMaxDepth())
                        plot.quickChangeMaxRangeValue = newMaxDepthValue
                        selectorMaxDepth.value = newMaxDepthValue
                    }
                }
                //***************
            }

            //Pulse additions, replacing the logic
            else if  (zoomX) {
                if (pulseRuntimeSettings.is2DTransducer && !pulseRuntimeSettings.echogramPause) {
                    // 1) compute horizontal “ratio”
                    var hRatio = (pinch.scale - pinch.previousScale) * 50;
                    // 2) fraction of the 4-unit speed range
                    var deltaS = (hRatio * 0.01) * (5.0 - 1.0);
                    // 3) apply, clamp, round
                    //var raw     = pulseRuntimeSettings.echogramSpeed + deltaS;
                    var raw     = pulseSettings.echogramSpeed + deltaS;
                    var clamped = Math.min(5.0, Math.max(1.0, raw));
                    var rounded = Math.round(clamped * 10) / 10;

                    // 4) only write (and thus emit) if it really changed
                    if (rounded !== pulseSettings.echogramSpeed) {
                        pulseSettings.echogramSpeed = rounded;
                        //console.log("TAV: zoomX → echogramSpeed changed to", rounded);
                    }
                } else if (!pulseRuntimeSettings.is2DTransducer && plot.isViewHorizontal()) {
                    // Pulse: side scan shows the cross-track range on the X axis, so the intuitive
                    // range zoom is a horizontal (zoomX) pinch. Mirror the zoomY horizontal-view path:
                    // fingers apart -> scale up -> smaller range (zoom in); fingers together ->
                    // larger range (flatten). Bidirectional by construction.
                    let pinchDelta = (pinch.previousScale - pinch.scale) * 10
                    depthStepAccum += pinchDelta
                    let steps = depthStepAccum > 0 ? Math.floor(depthStepAccum)
                                                   : Math.ceil(depthStepAccum)
                    if (steps !== 0) {
                        depthStepAccum -= steps
                        let newVal = plot.quickChangeMaxRangeValue + steps
                        if (newVal < 1) newVal = 1
                        if (newVal > pulseRuntimeSettings.maximumDepth)
                            newVal = pulseRuntimeSettings.maximumDepth
                        plot.quickChangeMaxRangeValue = newVal
                        selectorMaxDepth.value = newVal
                    }
                }
            }
        }

        onPinchFinished: {
            mousearea.enabled = true
            plot.plotMousePosition(-1, -1)

            clearPinchMovementState()
            pinchStartPos = Qt.point(-1, -1)
        }


       MouseArea {
            id: mousearea
            enabled: true
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            property int lastMouseX: -1
            property bool wasMoved: false
            property point startMousePos: Qt.point(-1, -1)
            property real mouseThreshold: 30
            property int contactMouseX: -1
            property int contactMouseY: -1
            //Pulse addition
            property int lastMouseY: -1
            property bool longPressFired: false
            property int pressButton: Qt.LeftButton
            property bool draggingInPaused: false
            property int dragCommitX: -1
            property int dragCommitY: -1
            //**************

            hoverEnabled: true

            Connections {
                target: pulseRuntimeSettings

                function onEchogramPauseChanged () {
                    if (!pulseRuntimeSettings.echogramPause) {
                        mousearea.longPressFired = false;
                        mousearea.draggingInPaused = false
                        mousearea.lastMouseX = -1
                        mousearea.lastMouseY = -1
                        mousearea.wasMoved = false
                    }
                }
            }

            Timer {
                id: longPressTimer
                interval: 500
                repeat: false
                onTriggered: {
                    if (true)
                        return
                    // we only want this behavior when paused
                    console.log("AddWaypoint: longPressTimer, echogramPause=", pulseRuntimeSettings.echogramPause, "and !wasMoved=", !mousearea.wasMoved)
                    if (pulseRuntimeSettings.echogramPause &&
                        !mousearea.wasMoved) {
                        console.log("AddWaypoint: longPressTimer, TRIGGER")
                        if (mousearea.pressButton === Qt.LeftButton) {
                            menuBlock.visible = false
                            plot.plotMousePosition(mousearea.lastMouseX, mousearea.lastMouseY)
                            plotPressed(indx, mousearea.lastMouseX, mousearea.lastMouseY)
                        }

                        if (mousearea.pressButton === Qt.RightButton) {
                            mousearea.contactMouseX = mousearea.pressX
                            mousearea.contactMouseY = mousearea.pressY
                            plot.simplePlotMousePosition(mousearea.lastMouseX, mousearea.lastMouseY)
                        }
                        //plot.setDragActive(false)
                        mousearea.longPressFired = true
                    }
                }
            }
            
            onClicked: function(mouse) {
                lastMouseX = mouse.x
                plot.focus = true

                if (mouse.button === Qt.RightButton) {
                    contactMouseX = mouse.x
                    contactMouseY = mouse.y

                    plot.simplePlotMousePosition(mouse.x, mouse.y)

                    if (theme.instrumentsGrade !== 0) {
                        menuBlock.position(mouse.x, mouse.y)
                    }
                }

                wasMoved = false
            }

            onPressed: function(mouse) {

                lastMouseX = mouse.x
                //Pulse addition
                lastMouseY = mouse.y
                mousearea.pressButton = mouse.button
                //**************

                if (pulseRuntimeSettings.echogramPause) {
                    startMousePos = Qt.point(mouse.x, mouse.y)
                }

                if (pulseRuntimeSettings.echogramPause && !wasMoved) {
                    mousearea.longPressFired = false
                    if (mouse.button === Qt.LeftButton) {
                        menuBlock.visible = false
                        plot.plotMousePosition(mouse.x, mouse.y)
                        plotPressed(indx, mouse.x, mouse.y)
                    }

                    if (mouse.button === Qt.RightButton) {
                        contactMouseX = mouse.x
                        contactMouseY = mouse.y

                        plot.simplePlotMousePosition(mouse.x, mouse.y)
                    }
                }

                longPressFired = false
                draggingInPaused = false
                wasMoved = false
            }

            onReleased: function(mouse) {
                // Always wipe the aim touch-state machine on finger-up so the
                // next press is recognised as a fresh press.  Must run before
                // any early returns below.
                plot.notifyAimTouchEnd()

                lastMouseX = -1
                //Pulse addition
                lastMouseY = -1
                //**************

                if (mouse.button === Qt.LeftButton) {
                    if (pulseRuntimeSettings.echogramPause && wasMoved) {
                        // >>> This makes the drag behave like a normal single-tap at release <<<
                        var x = dragCommitX
                        var y = dragCommitY
                        // defend against weird sequences
                        if (x < 0 || y < 0) { x = mouse.x; y = mouse.y }

                        // exactly the same sequence your single-tap uses:
                        menuBlock.visible = false
                        //plot.plotMousePosition(x, y)
                        plotPressed(indx, x, y)
                        plotReleased(indx)

                        // reset drag state and bail out early
                        wasMoved = false
                        startMousePos = Qt.point(-1, -1)
                        dragCommitX = -1
                        dragCommitY = -1
                        return
                    }
                    // (else: not a drag — keep your existing left-button logic, if any)
                }

                /*
                if (mouse.button === Qt.RightButton) {
                    contactMouseX = mouse.x
                    contactMouseY = mouse.y

                    plot.simplePlotMousePosition(mouse.x, mouse.y)
                }
                */

                dragCommitX = -1
                dragCommitY = -1
                wasMoved = false
                startMousePos = Qt.point(-1, -1)
                plotReleased(indx)
            }

            onCanceled: {
                // Same reset path as onReleased — see comment there.
                plot.notifyAimTouchEnd()

                lastMouseX = -1
                //Pulse addition
                lastMouseY = -1
                //**************
                if (pulseRuntimeSettings.echogramPause || draggingInPaused) {
                    //plot.setDragActive(false)
                }
                draggingInPaused = false

                if (Qt.platform.os === "android") {
                    longPressTimer.stop()
                }

                wasMoved = false
                startMousePos = Qt.point(-1, -1)
                plotReleased(indx)
            }

            onPositionChanged: function(mouse) {
                plot.onCursorMoved(mouse.x, mouse.y)

                // 1) detect movement
                if (!wasMoved) {
                    var currDelta = Math.sqrt(Math.pow(mouse.x - startMousePos.x, 2) +
                                              Math.pow(mouse.y - startMousePos.y, 2))
                    if (currDelta > mouseThreshold) {
                        wasMoved = true
                        longPressTimer.stop()

                        if (pulseRuntimeSettings.echogramPause && !mousearea.longPressFired) {
                            draggingInPaused = true
                            //plot.setDragActive(true)
                        }
                    }
                }

                // 2) update deltas
                var delta = mouse.x - lastMouseX
                lastMouseX = mouse.x
                var deltaY = mouse.y - lastMouseY
                lastMouseY = mouse.y

                // 3) normal (not paused) drag
                if ((mousearea.pressedButtons & Qt.LeftButton) && !pulseRuntimeSettings.echogramPause) {
                    //plot.setDragActive(true)
                    if (plot.isViewHorizontal()) {
                        plot.horScrollEvent(delta)
                    } else {
                        plot.horScrollEvent(deltaY)
                    }
                    var nowLive = plot.timelinePosition >= 0.999
                    if (!pulseRuntimeSettings.wasKlfFileOpened) {
                        if (!nowLive) {
                            countdownTimer.stop()
                            oldDataIndicator._setCountdown(oldDataResetSeconds)
                            oldDataWarningRemovalTimer.interval = oldDataResetSeconds * 1000
                            oldDataWarningRemovalTimer.restart()
                            countdownTimer.start()
                        }
                    }

                }
                // 4) paused drag (only if we *latched* into draggingInPaused)
                else if (pulseRuntimeSettings.echogramPause && wasMoved) {
                    dragCommitX = mouse.x
                    dragCommitY = mouse.y
                    plot.plotMousePosition(mouse.x, mouse.y)
                    //plotPressed(indx, mouse.x, mouse.y)
                }

                if (mouse.button === Qt.RightButton) {
                    contactMouseX = mouse.x
                    contactMouseY = mouse.y

                    plot.simplePlotMousePosition(mouse.x, mouse.y)
                }
            }

            onWheel: function(wheel) {
                if (wheel.modifiers & Qt.ControlModifier) {
                    let val = -wheel.angleDelta.y
                    plot.verZoomEvent(val)
                    plotCursorChanged(indx, cursorFrom(), cursorTo())
                }
                else if (wheel.modifiers & Qt.ShiftModifier) {
                    let val = -wheel.angleDelta.y
                    plot.verScrollEvent(val)
                    plotCursorChanged(indx, cursorFrom(), cursorTo())
                }
                else {
                    let val = wheel.angleDelta.y
                    plot.horScrollEvent(val)
                    updateOtherPlot(indx)
                }
            }
        }
    }


    onHeightChanged: {
        if(menuBlock.visible) {
            menuBlock.position(menuBlock.x, menuBlock.y)
        }
    }

    onWidthChanged: {
        if(menuBlock.visible) {
            menuBlock.position(menuBlock.x, menuBlock.y)
        }
    }


    //Pulse additiona - UI controls and methods
    //*****************************************

    GridLayout  {

        id: quickChangeObjects

        // Platform helpers
        readonly property bool _isAndroid: Qt.platform.os === "android"
        readonly property real platformScale: _isAndroid ? 0.9 : 0.75
        //readonly property real s: Ui.scale * platformScale
        readonly property real shortSide: Math.min(Screen.width, Screen.height)
        readonly property real s: Math.max(1.0, shortSide / 1100) // tune 800 to your “10-inch baseline”


        function _hasInsets() { return _isAndroid && (typeof Insets !== "undefined"); }
        // Safe accessors (0 on non-Android or when Insets missing)
        function insetTop()    { return _hasInsets() && Insets.dexEnabled ? Insets.top    : 0; }
        function insetBottom() { return _hasInsets() ? Insets.bottom : 0; }
        function insetLeft()   { return _hasInsets() ? Insets.left   : 0; }
        function insetRight()  { return _hasInsets() ? Insets.right  : 0; }
        function insetsIme()   { return _hasInsets() ? Insets.ime  : 0; }

        //width: _isAndroid ? 710 : 480
        width: Math.round(580 * s)
        //width: 710
        clip: true
        columns: 2
        rowSpacing: 10
        columnSpacing: 0

        property real quickChangeStartValue: 0
        property real quickChangeStopValue: 120
        property real quickChangeDefaultIlluminationValue: 10
        property real quickChangeDefaultFilterValue: 1
        property bool quickChangeScanVisible: false
        property bool quickChangeConeVisible: false
        property bool showAs2DTransducer: false
        property bool isDeviceDetected: false

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: insetBottom() + 20
        anchors.leftMargin: 20

        //Pulse functions
        //***************

        function isDevice2DTransducer () {
            //console.log("TAV isDevice2DTransducer userManualSetName ===", pulseRuntimeSettings.userManualSetName)
            if (pulseRuntimeSettings.userManualSetName !== "...") {
                //Manually selected model
                //console.log("TAV isDevice2DTransducer determined by manual selection");
                if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed
                        || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto) {
                    //console.log("TAV isDevice2DTransducer selected modelPulseRed");
                    showAs2DTransducer = true
                }
                if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
                        ||pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlueProto) {
                    //console.log("TAV isDevice2DTransducer selected modelPulseBlue");
                    showAs2DTransducer = false
                }
            } else {
                //Detected model
                //console.log("TAV isDevice2DTransducer determined by automatic detection");
                if (pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseRed
                        || pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseRedProto) {
                    //console.log("TAV isDevice2DTransducer found modelPulseRed");
                    showAs2DTransducer = true
                }
                if (pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseBlue
                        ||pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseBlueProto) {
                    //console.log("TAV isDevice2DTransducer found modelPulseBlue");
                    showAs2DTransducer = false
                }
            }
            //console.log("TAV isDevice2DTransducer determined to be", showAs2DTransducer);
        }

        function reArrangeQuickChangeObject () {

            //console.log("TAV reArrangeQuickChangeObject ran, and isViewHorizontal is :", plot.isViewHorizontal());
            isDevice2DTransducer()

            if (showAs2DTransducer) {
                plot2DGrid.setGridHorizontal(true)
                //plot.setGridHorizontalNow(true)
            } else {
                if (pulseSettings.ecoViewIndex === 0) {
                    plot2DGrid.setGridHorizontal(true)
                    //plot.setGridHorizontalNow(true)
                } else {
                    plot2DGrid.setGridHorizontal(false)
                    //plot.setGridHorizontalNow(false)
                }
            }

        }


        function setUserInterface () {
            //console.log("TAV function setUserInterface, pulseRuntimeSettings.devName =", pulseRuntimeSettings.devName);

            isDevice2DTransducer()

            if (showAs2DTransducer) {
                //console.log("TAV: setUserInterface horizontal - pulseRed");
                plot.setHorizontalNow()
                pulseRuntimeSettings.isHorizontalGrid = true
                //plot2DGrid.setGridHorizontal(true)
                //plot.setGridHorizontalNow(true)
                plot.plotDistanceRange2d(pulseSettings.maxDepthValue * 1.0)
                //console.log("TAV: setUserInterface horizontal - pulseRed - done");
            } else {
                if (pulseSettings.ecoViewIndex === 1) {
                    //console.log("TAV: setUserInterface vertical - pulseBlue viewIndex 1");
                    plot.setVerticalNow()
                    //plot2DGrid.setGridHorizontal(false)
                    pulseRuntimeSettings.isHorizontalGrid = false
                    //plot.setGridHorizontalNow(false)
                    plot.plotDistanceRange(pulseSettings.maxDepthValuePulseBlue * 1.0)
                    //console.log("TAV: setUserInterface vertical - pulseBlue viewIndex 1 - done");
                } else {
                    //console.log("TAV: setUserInterface horizontal - pulseBlue viewIndex 0");
                    plot.setHorizontalNow()
                    pulseRuntimeSettings.isHorizontalGrid = true
                    //plot2DGrid.setGridHorizontal(true)
                    //plot.setGridHorizontalNow(true)
                    plot.plotDistanceRange2d(pulseSettings.maxDepthValuePulseBlue * 1.0)
                    //console.log("TAV: setUserInterface horizontal - pulseBlue viewIndex 0 - done");
                }
            }

            reArrangeQuickChangeObject()
            plot.updatePlot()
        }

        function getFilterForDepth (depth) {
            //var autoFilter = pulseRuntimeSettings.autoFilterPulseRed;

            if (pulseSettings.ecoConeIndex === 0) {
                var autoFilterWide = pulseRuntimeSettings.autoFilterPulseRedWide;
                for (var i = 0; i < autoFilterWide.length; i++) {
                    if (depth >= autoFilterWide[i].min && depth < autoFilterWide[i].max) {
                        return autoFilterWide[i].filter;
                    }
                }
            } else {
                var autoFilterNarrow = pulseRuntimeSettings.autoFilterPulseRedNarrow;
                for (var y = 0; y < autoFilterNarrow.length; y++) {
                    if (depth >= autoFilterNarrow[y].min && depth < autoFilterNarrow[y].max) {
                        return autoFilterNarrow[y].filter;
                    }
                }
            }

            return 0;
        }

        // PULSE Stage B: single routing point for the filter control.
        // realValue is the "actual" filter scale (display 0-20 × 2.5 → 0-50).
        // Water-body mode ON: upstream global low-cut pinned to 0, strength
        // [0..1] goes to the Pulse-only water-column/surface filter.
        // OFF: exactly the pre-Stage-B behavior.
        function applyFiltering(realValue) {
            if (pulseRuntimeSettings.echogramWaterBodyFilterEnabled) {
                // The filter slider is PERSISTENT. A tester upgrading into the
                // default-on build can arrive with it at 0, which would leave
                // EchogramWaterColumn::isActive() false while the checkbox reads "on".
                // Floor the strength so the toggle always means something; anything the
                // tester dials above the floor is passed straight through.
                var wbfValue = Math.max(realValue, pulseRuntimeSettings.echogramWaterBodyMinRealValue)
                plot.setFilteringValue(0)
                plot.setWaterBodyFilter(wbfValue / 50.0)
            } else {
                plot.setWaterBodyFilter(0.0)
                plot.setFilteringValue(realValue)
            }
        }

        //AUTO FILTER RETIRED 2026-08-29. The depth->filter tables
        //(pulseRuntimeSettings.autoFilterPulseRedNarrow / ...Wide) existed because the
        //old global low-cut hit the BOTTOM render as well, so the amount of filtering had
        //to be re-tuned at every depth: too little and the high frequencies left noise in
        //the water column, too much and the bottom faded out. The water body filter now
        //applies to the water column ONLY, and TVG keeps the bottom render independent of
        //depth, so a single value chosen to taste is correct at every depth and the tables
        //mean nothing.
        //
        //This function is the single choke point. The call sites are deliberately left in
        //place so that a stored autoFilter = true cannot resurrect the behaviour through
        //any of them before PulseSettings has migrated the flag away.
        function doAutoFilter() {
            return
        }

        Connections {
            target: pulseSettings ? pulseSettings : undefined
            function onEcoConeIndexChanged () {
                if (pulseSettings.autoFilter) {
                    quickChangeObjects.doAutoFilter()
                }
            }
            function onIsSideScanOnLeftHandSideChanged () {
                console.log("SIDE SCAN: installation side left?", pulseSettings.isSideScanOnLeftHandSide)
                pulseRuntimeSettings.isSideScanLeftHand = pulseSettings.isSideScanOnLeftHandSide
                //plot2DGrid.setSideScanOnLeftHandSide(pulseSettings.isSideScanOnLeftHandSide)
                //plot.setSideScanOnLeftHandSideNow(pulseSettings.isSideScanOnLeftHandSide)
                if (pulseRuntimeSettings.isSideScan2DView && !pulseRuntimeSettings.is2DTransducer) {
                    //We need to fix the echogram in this combination
                    console.log("SIDE SCAN: set user interface")
                    plot.setHorizontalNow()
                    pulseRuntimeSettings.isHorizontalGrid = true
                    plot.plotDistanceRange2d(plot.quickChangeMaxRangeValue * 1.0 +1)
                    //plot.setVerticalNow()
                    correctImageFlipTimer.start()
                } else {
                    console.log("SIDE SCAN: did not try to fix the downscan again")
                }

                //plot.updatePlot()
            }
        }

        Timer {
            id: correctImageFlipTimer
            repeat: false
            interval: 200
            onTriggered: {
                console.log("SIDE SCAN: timer ticked")
                if (plot) {
                    plot.plotDistanceRange2d(plot.quickChangeMaxRangeValue * 1.0)
                    plot.updatePlot()
                    console.log("SIDE SCAN: tried to fix the downscan")
                } else {

                    console.log("SIDE SCAN: plot is null, cannot fix downscan")
                }


            }
        }

        Component.onCompleted: {
            //console.log("TAV Plot2D onCompleted, do nothing");
            quickChangeObjects.reArrangeQuickChangeObject
            myConnectionTimer.start()
        }

        Timer {
            id: myConnectionTimer
            interval: 200
            repeat: true
            onTriggered: {
            }
        }

        Connections {
            target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
            function onDevDetectedChanged() {
                //console.log("TAV: onDevDetectedChanged:", pulseRuntimeSettings.devDetected);
                quickChangeObjects.isDeviceDetected = pulseRuntimeSettings.devDetected
            }

            function onDevIdentifiedChanged() {
                /*
                console.log("TAV: onDevIdentifiedChanged detected");
                if (pulseRuntimeSettings.devIdentified) {
                    //TODO: Should we bring this back when device is automatically identifiable?
                    //console.log("TAV: onDevIdentifiedChanged true, change the UI");
                    //quickChangeObjects.setUserInterface();
                    console.log("TAV: onDevIdentifiedChanged true, is this a 2D transducer?", pulseRuntimeSettings.is2DTransducer);
                    if (pulseRuntimeSettings.is2DTransducer) {
                        if (pulseSettings.ecoConeIndex === 0) {
                            pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqWide
                        } else {
                            pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqNarrow
                        }
                        console.log("TAV: Preferred echosounder 2D cone:", pulseRuntimeSettings.transFreq);
                    }
                } else {
                    console.log("TAV: onDevIdentifiedChanged false, skip");
                }
                */
            }

            function onDevManualSelectedChanged() {
                //console.log("TAV: onDevManualSelectedChanged detected");
                if (pulseRuntimeSettings.devManualSelected) {
                    quickChangeObjects.isDeviceDetected = true
                    //console.log("TAV: devManualSelected true, is this a 2D transducer?", pulseRuntimeSettings.is2DTransducer);

                    quickChangeObjects.setUserInterface();
                } else {
                    //console.log("TAV: devManualSelected false, skip");
                }
            }

            function onAppConfiguredChanged () {
                //console.log("TAV: onAppConfiguredChanged detected");
                quickChangeObjects.setUserInterface();
            }

            function onAutoDepthMaxLevelChanged () {
                //console.log("TAV: onAutoDepthMaxLevelChanged is now", pulseRuntimeSettings.autoDepthMaxLevel);
                quickChangeObjects.doAutoFilter()
            }

            function onShouldDoAutoRangeChanged () {
                //console.log("TAV: onShouldDoAutoRangeChanged is now", pulseRuntimeSettings.shouldDoAutoRange);
            }
        }

        //Pulse User Interface
        //********************

        DepthAndTemperature {
            id: thisDepthAndTemperature
            visible: !pulseRuntimeSettings.echogramPause
            //visible: false
            //GridLayout.row: 0
            //GridLayout.column: 0
            Layout.row: 0
            Layout.column: 0
            Layout.rowSpan: 2
            //Layout.preferredWidth: _isAndroid ? 370 : 260
            Layout.preferredWidth: Math.round(320 * s)
            //Layout.preferredWidth: 370
            opacity: (quickChangeObjects.isDeviceDetected) ? 1 : 1
            enabled: (quickChangeObjects.isDeviceDetected)
        }

        HorizontalController {
            id: selectorMaxDepth
            visible: pulseSettings.areUiControlsVisible && !pulseRuntimeSettings.echogramPause

            Layout.row: 2
            Layout.column: 1
            //Layout.preferredWidth: _isAndroid ? 330 : 220
            Layout.preferredWidth: Math.round (260 * s)
            Layout.alignment: Qt.AlignBottom
            controleName: "selectorMaxDepth"
            minValue: {
                if (pulseRuntimeSettings.is2DTransducer) {
                    return 1
                } else {
                    if (pulseRuntimeSettings.isSideScan2DView) {
                        return 1
                    } else {
                        if (pulseRuntimeSettings.expertMode) {
                            return 5
                        } else {
                            return 10
                        }
                    }
                }
            }
            maxValue: pulseRuntimeSettings.maximumDepth
            step: {
                if (pulseRuntimeSettings.is2DTransducer) {
                    return 1
                } else {
                    if (pulseRuntimeSettings.isSideScan2DView) {
                        return 1
                    } else {
                        return 5
                    }
                }
            }
            allowLongPressControl: {
                if (pulseRuntimeSettings.is2DTransducer) {
                    return true
                } else {
                    if (pulseRuntimeSettings.isSideScan2DView) {
                        return true
                    } else {
                        return false
                    }
                }
            }
            defaultValue: pulseRuntimeSettings.is2DTransducer ? pulseSettings.maxDepthValue : pulseSettings.maxDepthValuePulseBlue
            //defaultValue: pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed ? pulseSettings.maxDepthValue : pulseSettings.maxDepthValuePulseBlue
            iconSource: "./icons/ui/pulse_ruler.svg"

            onSelectorValueChanged: {
                //console.log("EchogramWidth: max depth onSelectorValueChanged: ", value);
                plot.quickChangeMaxRangeValue = value;
                if (pulseRuntimeSettings.userManualSetName === "...")
                    return
                if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                    pulseSettings.maxDepthValue = value;
                } else {
                    if (pulseRuntimeSettings.isSideScan2DView) {
                        //console.log("EchogramWidth: max depth isSideScan2DView onSelectorValueChanged, was", pulseSettings.maxDepthValuePulseBlue, "but now set to", value)
                        pulseSettings.maxDepthValuePulseBlue = value;
                    } else {
                        //console.log("EchogramWidth: max depth !isSideScan2DView onSelectorValueChanged, was", pulseSettings.maxDepthValuePulseBlueFixed, "but now set to", value)
                        pulseSettings.maxDepthValuePulseBlueFixed = value
                    }
                }
                pulseRuntimeSettings.manualSetLevel = value * 1.0
                if (plot.isViewHorizontal()) {
                    plot.plotDistanceRange2d(value * 1.0)
                } else {
                    plot.plotDistanceRange(value * 1.0)
                }
                plot.updatePlot()
                //console.log("TAV: selectorMaxDepth changed max depth:", value)
            }

            onDistanceAutoRangeRequested: {
                if (!pulseRuntimeSettings.is2DTransducer)
                    return
                plot.plotDistanceAutoRange(0)
                pulseSettings.autoRange = true
                pulseRuntimeSettings.shouldDoAutoRange = true
                plot.updatePlot()
                //console.log("TAV: Auto range requested");
            }

            onDistanceFixedRangeRequested: {
                plot.plotDistanceAutoRange(-1)
                pulseSettings.autoRange = false;
                pulseRuntimeSettings.shouldDoAutoRange = false
                pulseRuntimeSettings.manualSetLevel = plot.quickChangeMaxRangeValue * 1.0
                if (plot.isViewHorizontal()) {
                    plot.plotDistanceRange2d(plot.quickChangeMaxRangeValue * 1.0)
                } else {
                    plot.plotDistanceRange(plot.quickChangeMaxRangeValue * 1.0)
                }
                plot.updatePlot()
                //console.log("TAV: Fixed range requested");
            }

            //DEMO MODE: re-assert the user's max depth after a channel rebind.
            //
            //Plot2D::setDataChannel() (plot2D.cpp) does NOT just bind the channel —
            //it also overwrites cursor_.distance with Dataset::getMaxDistanceRange()
            //for that channel. On a demo loop restart the dataset has just been
            //reset, so at rebind time it holds only the first ping of the new pass
            //and the view snaps to that ping's shallow range (the "set as if 3 m"
            //symptom) instead of the value still showing on this controller.
            //
            //Nothing re-issues the range afterwards, because onSelectorValueChanged
            //only fires when the VALUE changes and it has not. Hence this hook.
            //core.channelListUpdated is emitted at the end of onChannelsUpdated(),
            //i.e. after every setDataChannel() call, so it is the right moment.
            //
            //This is why max depth was the only affected control: filter, intensity
            //and colour map are not touched by setDataChannel.
            //Demo-scoped on purpose — the live path is left exactly as it was.
            Connections {
                target: core
                function onChannelListUpdated() {
                    if (!pulseRuntimeSettings.isInDemoMode)
                        return
                    if (pulseRuntimeSettings.shouldDoAutoRange)
                        return      // auto range recomputes on its own
                    let v = plot.quickChangeMaxRangeValue * 1.0
                    if (v <= 0)
                        return
                    console.log("DEMO: re-applying max depth", v, "after channel rebind")
                    if (plot.isViewHorizontal()) {
                        plot.plotDistanceRange2d(v)
                    } else {
                        plot.plotDistanceRange(v)
                    }
                    plot.updatePlot()
                }
            }

            Component.onCompleted: {
                //console.log("EchogramWidth: max depth Component.onComplete")
                if (pulseSettings.autoRange) {
                    console.log("EchogramWidth: max depth Component.onComplete autoRange")
                    if (pulseRuntimeSettings.is2DTransducer) {
                        //console.log("EchogramWidth: Component.onComplete autoRange for is2DTransducer")
                    //if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                        pulseRuntimeSettings.shouldDoAutoRange = true
                        plot.plotDistanceAutoRange(0);
                    }
                } else {
                    console.log("EchogramWidth: max depth Component.onComplete not autoRange")
                    pulseRuntimeSettings.shouldDoAutoRange = false
                    plot.plotDistanceAutoRange(-1);
                    if (pulseRuntimeSettings.is2DTransducer) {
                        //console.log("EchogramWidth: max depth Component.onComplete not autoRange")
                    //if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                        plot.plotDistanceRange(pulseSettings.maxDepthValue * 1.0)
                        pulseRuntimeSettings.manualSetLevel = pulseSettings.maxDepthValue * 1.0
                    } else {
                        if (pulseRuntimeSettings.isSideScan2DView) {
                            //console.log("EchogramWidth: max depth Component.onCompleted, set pulseRuntimeSettings.manualSetLevel to pulseSettings.maxDepthValuePulseBlue * 1.0",pulseSettings.maxDepthValuePulseBlue * 1.0)
                            plot.plotDistanceRange(pulseSettings.maxDepthValuePulseBlue * 1.0)
                            pulseRuntimeSettings.manualSetLevel = pulseSettings.maxDepthValuePulseBlue * 1.0
                        } else {
                            //console.log("EchogramWidth: max depth Component.onCompleted, set pulseRuntimeSettings.manualSetLevel to pulseSettings.maxDepthValuePulseBlueFixed * 1.0",pulseSettings.maxDepthValuePulseBlueFixed * 1.0)
                            plot.plotDistanceRange(pulseSettings.maxDepthValuePulseBlueFixed * 1.0)
                            pulseRuntimeSettings.manualSetLevel = pulseSettings.maxDepthValuePulseBlueFixed * 1.0
                        }

                    }
                }
                plot.updatePlot();
            }

            Connections {
                target: pulseRuntimeSettings !== null ? pulseRuntimeSettings : undefined

                function onIsOpeningKlfFileChanged () {
                    if (pulseRuntimeSettings === null) {
                        return
                    }
                    if (pulseRuntimeSettings.isOpeningKlfFile) {
                        return
                    }
                    //A file was opened completely, let's ensure the settings are now enforced
                    console.log("FILE OPENING: A file was opened, set proper value for zoom")
                    updateZoomTimer.start()
                }

                function onDevConfiguredChanged () {
                    if (pulseRuntimeSettings === null) {
                        return
                    }
                    if (!pulseRuntimeSettings.devConfigured) {
                        return
                    }
                    //The device was set up, let's enforce the default zoom
                    console.log("DEVICE CONFIGURED: Device configuration completed, set proper value for zoom")
                    updateZoomTimer.start()
                }
            }

            Timer {
                id: updateZoomTimer
                interval: 500
                repeat: false
                onTriggered: {
                    if (pulseRuntimeSettings.is2DTransducer) {
                    //if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                        plot.plotDistanceRange2d(pulseSettings.maxDepthValue)
                        //console.log("FILE OPENING: A file was opened for pulse red, execute plot.plotDistanceRange2d with value", pulseSettings.maxDepthValue)
                    } else {
                        if (pulseRuntimeSettings.isSideScan2DView) {
                            plot.plotDistanceRange2d(pulseSettings.maxDepthValuePulseBlue)
                            //console.log("FILE OPENING: A file was opened for pulse blue, execute plot.plotDistanceRange2d with value", pulseSettings.maxDepthValuePulseBlue)
                        } else {
                            plot.plotDistanceRange(pulseSettings.maxDepthValuePulseBlueFixed)
                            //console.log("FILE OPENING: A file was opened for pulse blue, execute plot.plotDistanceRange with value", pulseSettings.maxDepthValuePulseBlueFixed)
                        }
                    }
                    plot.updatePlot()
                }
            }
        }


        HorizontalController {
            id: selectorIntensity
            visible: pulseSettings.areUiControlsVisible && !pulseRuntimeSettings.echogramPause
            Layout.row: 3
            Layout.column: 1
            //Layout.preferredWidth: _isAndroid ? 330 : 220
            Layout.preferredWidth: Math.round (260 * s)
            Layout.alignment: Qt.AlignBottom
            controleName: "selectorIntensity"
            minValue: 0
            maxValue: 20
            step: 1
            defaultValue: pulseSettings.intensityDisplayValue
            //defaultValue: Math.round((120 - echogramLevelsSlider.stopValue) / 3)
            iconSource: "./icons/ui/pulse_sun.svg"

            onSelectorValueChanged: {
                let actualValue = Math.round(120 - (value * 4));
                pulseSettings.intensityRealValue = actualValue;
                pulseSettings.intensityDisplayValue = value;
                quickChangeObjects.quickChangeStopValue = actualValue;
                plot.setIntensityValue(actualValue * 1.0)
                //console.log("TAV: selectorIntensity changed intensity (presented):", value, " (actual):", actualValue);
            }

            Component.onCompleted: {
                plot.setIntensityValue(pulseSettings.intensityRealValue * 1.0)
                plot.updatePlot()
                // PULSE TRIAL: initial sync of the master light(=high)/filter(=low) levels into the
                // 3D side-scan mosaic. low = filter, high = intensity.
                MosaicViewControlMenuController.onLevelChanged(pulseSettings.filterRealValue, pulseSettings.intensityRealValue)
            }

            Connections {
                target: pulseRuntimeSettings !== null ? pulseRuntimeSettings : undefined

                function onDevConfiguredChanged () {
                    if (pulseRuntimeSettings === null) {
                        return
                    }
                    if (!pulseRuntimeSettings.devConfigured) {
                        return
                    }
                    //The device was set up, let's enforce the default intensity
                    console.log("selectorIntensity, DEVICE CONFIGURED: Device configuration completed, set proper value for intensity")
                    updateIntensityTimer.start()
                }
            }

            Timer {
                id: updateIntensityTimer
                interval: 500
                repeat: false
                onTriggered: {
                    plot.setIntensityValue(pulseSettings.intensityRealValue * 1.0)
                    plot.updatePlot()
                }
            }
        }

        HorizontalController {
            id: selectorFiltering
            visible: pulseSettings.areUiControlsVisible && !pulseRuntimeSettings.echogramPause
            controleName: "selectorFiltering"
            Layout.row: 4
            Layout.column: 1
            //Layout.preferredWidth: _isAndroid ? 330 : 220
            Layout.preferredWidth: Math.round (260 * s)
            Layout.alignment: Qt.AlignBottom
            minValue: 0
            maxValue: 20
            step: 1
            defaultValue: pulseSettings.filterDisplayValue
            //defaultValue: Math.round(echogramLevelsSlider.startValue / 2.5)
            iconSource: "./icons/ui/pulse_filter.svg"
            onSelectorValueChanged: {
                let actualValue = Math.round(value * 2.5);
                pulseSettings.filterRealValue = actualValue
                pulseSettings.filterDisplayValue = value
                quickChangeObjects.quickChangeStartValue = actualValue;
                quickChangeObjects.applyFiltering(actualValue) // PULSE Stage B routing
                //console.log("TAV: selectorFiltering changed filter (presented):", value, " (actual):", actualValue);
            }

            Component.onCompleted: {
                // PULSE water body filter: this push used to sit entirely inside the
                // is2DTransducer gate, so on Pulse Blue setWaterBodyFilter() was never
                // called at all and the filter stayed inactive however the toggle read.
                // The filter now pushes for BOTH models; doAutoFilter stays 2D-only
                // (it is the Red depth->filter table), and with the filter switched off
                // the original 2D-only routing is preserved exactly.
                plot.setWaterBodyBottomGuard(pulseRuntimeSettings.echogramWaterBodyBottomMargin)
                if (pulseRuntimeSettings.is2DTransducer
                        || pulseRuntimeSettings.echogramWaterBodyFilterEnabled) {
                    quickChangeObjects.applyFiltering(pulseSettings.filterRealValue) // PULSE Stage B routing
                }
                if (pulseRuntimeSettings.is2DTransducer && pulseSettings.autoFilter) {
                    quickChangeObjects.doAutoFilter()
                }
            }

            onFilterAutoRangeRequested: {
                //Retired 2026-08-29 — HorizontalController no longer emits this for the
                //filter control. Kept as a hard stop so nothing can re-arm autoFilter.
                console.log("AUTO FILTER: request ignored, auto filtering is retired")
            }

            onFilterFixedRangeRequested: {
                //console.log("TAV: Fixed filter requested");
                pulseSettings.autoFilter = false;
                let preferredValue = pulseSettings.filterRealValue
                quickChangeObjects.applyFiltering(preferredValue) // PULSE Stage B routing

                plot.updatePlot()
            }

            Connections {
                target: pulseRuntimeSettings !== null ? pulseRuntimeSettings : undefined

                function onDevConfiguredChanged () {
                    if (pulseRuntimeSettings === null) {
                        return
                    }
                    if (!pulseRuntimeSettings.devConfigured) {
                        return
                    }
                    //The device was set up, let's enforce the default filter
                    console.log("DEVICE CONFIGURED: Device configuration completed, set proper value for filter")
                    updateFilterTimer.start()
                }
            }

            Timer {
                id: updateFilterTimer
                interval: 500
                repeat: false
                onTriggered: {
                    // Same widening as Component.onCompleted above: the water body filter
                    // strength must reach C++ on Pulse Blue too, not only on 2D.
                    plot.setWaterBodyBottomGuard(pulseRuntimeSettings.echogramWaterBodyBottomMargin)
                    if (pulseRuntimeSettings.is2DTransducer
                            || pulseRuntimeSettings.echogramWaterBodyFilterEnabled) {
                        quickChangeObjects.applyFiltering(pulseSettings.filterRealValue) // PULSE Stage B routing
                        if (pulseRuntimeSettings.is2DTransducer && pulseSettings.autoFilter) {
                            quickChangeObjects.doAutoFilter()
                        }
                        plot.updatePlot()
                    }
                }
            }

            // PULSE TRIAL: the echogram light(=high)/filter(=low) controls are the single master
            // for the 3D side-scan mosaic levels too. Mirror every change into the mosaic.
            // (The mosaic colour table is a copy of the echogram's, so the level scale matches.)
            Connections {
                target: pulseSettings
                function onIntensityRealValueChanged() {
                    MosaicViewControlMenuController.onLevelChanged(pulseSettings.filterRealValue, pulseSettings.intensityRealValue)
                }
                function onFilterRealValueChanged() {
                    MosaicViewControlMenuController.onLevelChanged(pulseSettings.filterRealValue, pulseSettings.intensityRealValue)
                }
            }
        }

        RowLayout {
            id: quickChangeMedia
            spacing: 2
            //Layout.topMargin: 10

            Layout.row: 4
            Layout.column: 0
            //Layout.preferredWidth: _isAndroid ? 350 : 220
            Layout.preferredWidth: Math.round (260 * s)

            HorizontalCheckController {
                id: echogramPlayPause
                iconSource: "./icons/ui/pulse_crosshair.svg"
                controleName: "echogramPlayPause"
                checked: false

                onControllerStateChanged: function(isChecked) {
                    if (isChecked) {
                        oldDataWarningRemovalTimer.stop()
                        oldDataIndicator.visible = false
                        pauseDataIndicator.visible = true
                        if (pulseRuntimeSettings.is2DTransducer) {
                            pulseRuntimeSettings.echogramSpeed = 1.0
                        }
                    } else {
                        if (pulseRuntimeSettings.is2DTransducer) {
                            pulseRuntimeSettings.echogramSpeed = pulseSettings.echogramSpeed
                        }
                        pauseDataIndicator.visible = false
                        let nowLive = plot.timelinePosition >= 0.999
                        if (!nowLive && !pulseRuntimeSettings.wasKlfFileOpened) {
                            oldDataIndicator.visible = true
                            oldDataWarningRemovalTimer.start()
                        }
                    }
                    // Let's pause AFTER we fix the settings
                    pulseRuntimeSettings.echogramPause = isChecked;
                }
                /*
                onControllerStateChanged: {
                    if (checked) {
                        oldDataWarningRemovalTimer.stop()
                        oldDataIndicator.visible = false
                        pauseDataIndicator.visible = true
                        if (pulseRuntimeSettings.is2DTransducer) {
                            pulseRuntimeSettings.echogramSpeed = 1.0
                        }
                    } else {
                        if (pulseRuntimeSettings.is2DTransducer) {
                            pulseRuntimeSettings.echogramSpeed = pulseSettings.echogramSpeed
                        }
                        pauseDataIndicator.visible = false
                        let nowLive = plot.timelinePosition >= 0.999
                        if (!nowLive && !pulseRuntimeSettings.wasKlfFileOpened) {
                            oldDataIndicator.visible = true
                            oldDataWarningRemovalTimer.start()
                        }
                    }
                    // Let's pause AFTER we fix the settings
                    pulseRuntimeSettings.echogramPause = checked
                }
                */
            }
            HorizontalCheckController {
                id: recordingStartStop
                iconSource: "./icons/ui/pulse_recording_mini.svg"
                controleName: "RecordKlf"
                checked: false
                visible: pulseSettings.areUiControlsVisible && !pulseRuntimeSettings.echogramPause && !pulseRuntimeSettings.wasKlfFileOpened
                onControllerStateChanged: function(isChecked) {
                    pulseRuntimeSettings.isRecordingKlf = isChecked
                    core.loggingKlf = pulseRuntimeSettings.isRecordingKlf
                }
                /*
                onControllerStateChanged: {
                    pulseRuntimeSettings.isRecordingKlf = checked
                    core.loggingKlf = pulseRuntimeSettings.isRecordingKlf
                }
                */
            }
        }

        RowLayout {
            id: quickChangeTheme
            spacing: 2
            //Layout.topMargin: 10
            visible: pulseSettings.areUiControlsVisible && !pulseRuntimeSettings.echogramPause

            Layout.row: 2
            Layout.column: 0
            //Layout.preferredWidth: _isAndroid ? 350 : 220
            Layout.preferredWidth: Math.round (260 * s)


            HorizontalPopUpController {
                id: themeSelectorColorSS
                visible: !quickChangeObjects.showAs2DTransducer
                model: pulseRuntimeSettings.themeModelBlue.map(function(item) {return item.icon;})
                iconSource: "./icons/ui/pulse_paint.svg"
                selectedIndex: pulseSettings.colorMapIndexSideScan
                hostWindow: plot ? plot : undefined
                //allowExpertModeByMultiTap: true
                onIconSelected: {
                    //console.log("TAV: colormap for:", pulseRuntimeSettings.userManualSetName);
                    pulseSettings.colorMapIndexSideScan = selectedIndex;
                    var selectedTheme = pulseRuntimeSettings.themeModelBlue[selectedIndex]
                    //console.log("TAV: colormap selectedIndex", selectedIndex, "matches selectedTheme.id", selectedTheme.id);
                    pulseSettings.colorMapIndexReal = selectedTheme.id
                    plot.plotEchogramTheme(selectedTheme.id);
                    plot.updatePlot();
                    // PULSE TRIAL: keep the 3D side-scan mosaic colours in sync with the echogram
                    // side-scan theme. onThemeChanged() applies themeId+1 internally, which matches
                    // the mosaic PlotColorTable enum offset (echogram ClassicTheme=0 -> mosaic=1).
                    // Shared themes: Blue/Yellow/Gray/Red/Green (ids 0-4). HQ Orange (26) has no
                    // mosaic equivalent yet, so the mosaic keeps its previous colour in that case.
                    MosaicViewControlMenuController.onThemeChanged(selectedTheme.id);
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onUserManualSetNameChanged () {
                        //console.log("TAV: colormap for:", pulseRuntimeSettings.userManualSetName);
                        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
                                || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlueProto) {
                            var preferredIndex = pulseSettings.colorMapIndexSideScan
                            var selectedTheme = pulseRuntimeSettings.themeModelBlue[preferredIndex]
                            //console.log("TAV: colormap preferredIndex", preferredIndex, "matches preferredTheme.id", selectedTheme.id);
                            plot.plotEchogramTheme(selectedTheme.id)
                            pulseSettings.colorMapIndexReal = selectedTheme.id
                            plot.updatePlot();
                            // PULSE TRIAL: sync the 3D mosaic colours to the echogram side-scan theme
                            // at startup / device identification too (see note in onIconSelected).
                            MosaicViewControlMenuController.onThemeChanged(selectedTheme.id);
                        }
                    }
                }
            }

            HorizontalPopUpController {
                id: themeSelectorColor2D
                visible: quickChangeObjects.showAs2DTransducer
                hostWindow: plot ? plot : undefined
                controlName: "themeSelectorColor2D"

                property var themeList:
                    (pulseSettings.useFavoriteThemes2D && pulseSettings.favoriteThemes2DNew.length > 0)
                      ? pulseSettings.favoriteThemes2DNew
                      : pulseRuntimeSettings.themeModelRed

                model: themeList.map(function(item){ return item.icon })

                onThemeListChanged: recalcSelectedIndex()
                iconSource: "./icons/ui//pulse_paint.svg"

                // SOURCE OF TRUTH for this control is colorMapIndex2D — the 2D model's
                // OWN stored preference, an index into the master themeModelRed.
                //
                // It used to read colorMapIndexReal instead, which is the SHARED
                // "currently applied theme id" that the side scan selector also writes.
                // themeModelRed is a superset of themeModelBlue (it carries ids 0-4 and
                // 26 too), so after using a Blue the lookup did not fail — it quietly
                // found the Blue's theme inside the red list, selected it, and wrote that
                // position back into colorMapIndex2D. The Red's own preference was
                // therefore DESTROYED, not merely displayed wrong, which is why it
                // survived a restart. Mirror image of what themeSelectorColorSS already
                // does correctly from colorMapIndexSideScan.
                function recalcSelectedIndex() {
                    if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue)
                        return

                    var master = pulseRuntimeSettings.themeModelRed
                    if (!master || master.length === 0)
                        return

                    // 1. Which theme does the 2D preference name?
                    var stored = pulseSettings.colorMapIndex2D
                    var wantId = (stored >= 0 && stored < master.length) ? master[stored].id
                                                                         : master[0].id

                    // 2. Where does it sit in the *visible* list (favorites may be a subset)?
                    var idx = themeList.findIndex(function(item){
                        return item.id === wantId
                    })
                    selectedIndex = idx >= 0 ? idx : 0

                    // 3. Grab that theme object
                    var theme = themeList[selectedIndex]
                    if (!theme)
                        return

                    // 4. Map it back into the master red-themes array and store BOTH
                    //    indices. Guard the -1: never write a negative index into the
                    //    persistent preference.
                    var globalIdx = master.findIndex(function(i){
                        return i.id === theme.id
                    })
                    if (globalIdx >= 0)
                        pulseSettings.colorMapIndex2D = globalIdx
                    pulseSettings.colorMapIndexReal = theme.id

                    // 5. And refresh the plot
                    plot.plotEchogramTheme(theme.id)
                    plot.updatePlot()

                    console.log(
                      "🔄 recalcSelectedIndex → thumb", selectedIndex,
                      "({", theme.id, "}), globalIdx =", globalIdx,
                      "themeList IDs:", themeList.map(function(x){return x.id})
                    )
                }

                Component.onCompleted:   themeSelectorColor2D.recalcSelectedIndex()
                onVisibleChanged:        if (visible) themeSelectorColor2D.recalcSelectedIndex()

                onIconSelected: {
                    var theme = themeList[selectedIndex]
                    pulseSettings.colorMapIndex2D =
                        pulseRuntimeSettings.themeModelRed.findIndex(function(item){
                            return item.id === theme.id
                        })
                    pulseSettings.colorMapIndexReal = theme.id
                    plot.plotEchogramTheme(theme.id)
                    plot.updatePlot()
                }

                Connections {
                    target: pulseSettings ? pulseSettings : undefined
                    function onUseFavoriteThemes2DChanged() {
                        console.log("Favorites toggled → validating current theme, pulseSettings. useFavoriteThemes2D is", pulseSettings.useFavoriteThemes2D)
                        //themeSelectorColor2D.ensureCurrentThemeIsValid()
                        themeSelectorColor2D.recalcSelectedIndex()
                    }
                    function onFavoriteThemes2DNewChanged()   {
                        console.log("Favorites toggled → validating current theme, pulseSettings. useFavoriteThemes2D is", pulseSettings.useFavoriteThemes2D)
                        //themeSelectorColor2D.ensureCurrentThemeIsValid()
                        themeSelectorColor2D.recalcSelectedIndex()
                    }
                    function onColorMapIndexRealChanged () {
                        console.log("Favorites real index changed → validating current theme, pulseSettings. useFavoriteThemes2D is", pulseSettings.useFavoriteThemes2D)
                        themeSelectorColor2D.recalcSelectedIndex()
                    }
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onUserManualSetNameChanged() {
                        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed
                         || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto) {
                            // Restore THIS model's own preference. Applying
                            // colorMapIndexReal here was the second half of the bug: after
                            // a Blue session that shared value still holds the Blue's
                            // theme id. recalcSelectedIndex() reads colorMapIndex2D,
                            // applies the theme and fixes the selector thumb in one go.
                            themeSelectorColor2D.recalcSelectedIndex()
                        }
                    }
                }
            }

            HorizontalPopUpController {
                id: themeSelector2
                visible: !pulseRuntimeSettings.is2DTransducer
                /* Change: No longer offer the 820 option
                model: [
                    "./icons/ui/pulse_view_down_scan_460.svg",
                    "./icons/ui/pulse_view_down_scan_820.svg",
                    "./icons/ui/pulse_view_side_scan_460.svg",
                    "./icons/ui/pulse_view_side_scan_820.svg"
                ]
                */
                model: [
                    "./icons/ui/pulse_view_down_scan.svg",
                    "./icons/ui/pulse_view_side_scan.svg"
                ]
                iconSource: "./icons/ui/pulse_glasses.svg"
                /* Change: No longer offer the 820 option */
                //selectedIndex: pulseSettings.ecoViewIndex
                selectedIndex: {
                    if (pulseSettings.ecoViewIndex > 1)
                        return 1
                    return pulseSettings.ecoViewIndex
                }

                hostWindow: plot ? plot : undefined
                /* Change: No longer offer the 820 option
                onIconSelected: {
                    //plot.plotEchogramCompensation(selectedIndex);
                    pulseSettings.ecoViewIndex = selectedIndex
                    //Downscan 460
                    if (selectedIndex === 0) {
                        setDownScan(460)
                    }
                    //Downscan 820
                    if (selectedIndex === 1) {
                        setDownScan(820)
                    }
                    //Sidescan 460
                    if (selectedIndex === 2) {
                        setSideScan(460)
                    }
                    //Sidescan 820
                    if (selectedIndex === 3) {
                        setSideScan(820)
                    }
                    plot.updatePlot()
                    quickChangeObjects.reArrangeQuickChangeObject()

                }
                */
                onIconSelected: {
                    //plot.plotEchogramCompensation(selectedIndex);
                    pulseSettings.ecoViewIndex = selectedIndex
                    //Downscan 460
                    if (selectedIndex === 0) {
                        setDownScan(460)
                    }
                    //Sidescan 460
                    if (selectedIndex === 1) {
                        setSideScan(460)
                    }
                    plot.updatePlot()
                    quickChangeObjects.reArrangeQuickChangeObject()

                }

                function setDownScan (frequency) {
                    pulseRuntimeSettings.isSideScan2DView = true
                    pulseRuntimeSettings.isHorizontalGrid = true
                     plotDistanceRange2dTimer.start()
                    //Set the offset
                    pulseRuntimeSettings.chartOffset = 0
                    //Set the frequency
                    pulseRuntimeSettings.transFreq = frequency
                }
                function setSideScan (frequency) {
                    pulseRuntimeSettings.isSideScan2DView = false
                    pulseRuntimeSettings.isHorizontalGrid = false
                    plot.quickChangeMaxRangeValue = pulseSettings.maxDepthValuePulseBlueFixed
                    plotDistanceRangeTimer.start()

                    pulseRuntimeSettings.transFreq = frequency
                }

                /* Change: No longer offer the 820 option
                Timer {
                    id: setPulseBlueEcoViewOnAppStart
                    repeat: false
                    interval: 1000
                    onTriggered: {
                        if (pulseSettings.ecoViewIndex === 0) {
                            themeSelector2.setDownScan(460)
                        }
                        if (pulseSettings.ecoViewIndex === 1) {
                            themeSelector2.setDownScan(820)
                        }
                        if (pulseSettings.ecoViewIndex === 2) {
                            themeSelector2.setSideScan(460)
                        }
                        if (pulseSettings.ecoViewIndex === 3) {
                            themeSelector2.setSideScan(820)
                        }
                    }

                }
                */
                Timer {
                    id: setPulseBlueEcoViewOnAppStart
                    repeat: false
                    interval: 1000
                    onTriggered: {
                        if (pulseSettings.ecoViewIndex === 0) {
                            themeSelector2.setDownScan(460)
                        }
                        if (pulseSettings.ecoViewIndex === 1) {
                            themeSelector2.setSideScan(460)
                        }
                    }

                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onUserManualSetNameChanged () {
                        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
                                || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlueProto) {

                            setPulseBlueEcoViewOnAppStart.start()
                        }
                    }

                    function onEchogramCompensationFileChanged () {
                        let newCompensation = pulseRuntimeSettings.echogramCompensationFile
                        console.log("FileOpening plotEchogramCompensation(newCompensation) using value", newCompensation)
                        plot.plotEchogramCompensation(newCompensation)
                        console.log("EchogramCompensation: Plot2D onEchogramCompensationFileChanged, value now", plot.getEchogramCompensation(), "from newCompensation", newCompensation)
                    }

                }

                Connections {
                    target: pulseSettings ? pulseSettings : undefined
                    // REMOVED: onColorMapIndexSideScanChanged used to drive
                    // themeSelectorColor2D.selectedIndex from the SIDE SCAN preference
                    // (clamped to 0..1, which is the only reason it never went out of
                    // range). Picking a side scan colour would move the 2D selector's
                    // thumb to an unrelated entry. The two selectors keep separate
                    // preferences — colorMapIndexSideScan and colorMapIndex2D — and must
                    // not write each other's state. themeSelectorColorSS binds its own
                    // selectedIndex to colorMapIndexSideScan already.
                    function onPulseBlueOffsetChanged () {
                        if (pulseSettings === null)
                            return
                        if (pulseRuntimeSettings == null)
                            return
                        if (pulseRuntimeSettings.is2DTransducer)
                                return

                    }
                }

                Timer {
                    id: plotDistanceRangeTimer
                    repeat: false
                    interval: 10
                    onTriggered: {
                        plot.setVerticalNow()
                        plot.plotDistanceRange(plot.quickChangeMaxRangeValue * 1.0)
                        plot.updatePlot();
                    }
                }

                Timer {
                    id: plotDistanceRange2dTimer
                    repeat: false
                    interval: 10
                    onTriggered: {
                        plot.setHorizontalNow()
                        plot.plotDistanceRange2d(plot.quickChangeMaxRangeValue * 1.0)
                        plot.updatePlot();
                    }
                }

            }

            HorizontalPopUpController {
                id: themeSelector3
                visible: pulseRuntimeSettings.is2DTransducer

                model: [
                    "./icons/ui/pulse_cone_510.svg",
                    "./icons/ui/pulse_cone_710.svg",
                    "./icons/ui/pulse_cone_810.svg"
                ]
                iconSource: "./icons/ui/pulse_glasses.svg"
                selectedIndex: pulseSettings.ecoConeIndex
                hostWindow: plot ? plot : undefined
                //allowExpertModeByMultiTap: false

                onIconSelected: {

                    if (selectedIndex === 0) {
                        pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqWide
                    } else if (selectedIndex === 1) {
                        pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqMedium
                    } else {
                        pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqNarrow
                    }
                    console.log("TAV: Selected echosounder cone (frequency):", pulseRuntimeSettings.transFreq);
                    pulseSettings.ecoConeIndex = selectedIndex
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onUserManualSetNameChanged () {
                        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed
                                || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto) {
                            if (pulseSettings.ecoConeIndex === 0) {
                                pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqWide
                            }
                            if (pulseSettings.ecoConeIndex === 1) {
                                pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqMedium
                            }
                            if (pulseSettings.ecoConeIndex === 2) {
                                pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqNarrow
                            }
                            plot.updatePlot()
                            console.log("TAV: viewSelector is 2D transducer, set the default index to", pulseSettings.ecoConeIndex);
                        } else {
                            console.log("TAV: viewSelector is side scan transducer, do not set for 2D");
                       }
                    }
                }

                Connections {
                    target: pulseSettings ? pulseSettings : undefined
                    function onColorMapIndex2DChanged () {
                        // colorMapIndex2D indexes the MASTER themeModelRed; selectedIndex
                        // indexes the VISIBLE list, which is a subset when favorites are
                        // on. Assigning one to the other was wrong whenever favorites
                        // were enabled. recalcSelectedIndex() does the master->visible
                        // mapping properly and is idempotent, so the write it makes back
                        // to colorMapIndex2D resolves to the same value and stops.
                        themeSelectorColor2D.recalcSelectedIndex()
                    }
                }
            }
        }

        RowLayout {
            id: quickChangeUserOptions
            spacing: 2
            //Layout.topMargin: 10

            Layout.row: 3
            Layout.column: 0
            //Layout.preferredWidth: _isAndroid ? 350 : 220
            Layout.preferredWidth: Math.round (260 * s)


            HorizontalCheckController {
                id: showMyControls
                iconSource: "./icons/ui/pulse_controls.svg"
                checked: pulseSettings.areUiControlsVisible
                visible: !pulseRuntimeSettings.echogramPause

                onControllerStateChanged: function(isChecked) {
                    pulseSettings.areUiControlsVisible = isChecked
                    if (!pulseSettings.areUiControlsVisible) {
                        pulseRuntimeSettings.echogramVisible = true
                    }
                }

                /*
                onControllerStateChanged: {
                    //console.log("Checkbox state changed:", checked)
                    pulseSettings.areUiControlsVisible = checked
                    if (!pulseSettings.areUiControlsVisible) {
                        pulseRuntimeSettings.echogramVisible = true
                    }
                }
                */

            }

            HorizontalCheckController {
                id: showInfo
                iconSource: "./icons/ui/pulse_info.svg"
                checked: false
                visible: pulseSettings.areUiControlsVisible  && !pulseRuntimeSettings.echogramPause

                onControllerStateChanged: function(isChecked) {
                    pulseInfoLoader.active = isChecked
                }

                /*
                onControllerStateChanged: {
                    //console.log("Checkbox state changed:", checked)
                    pulseInfoLoader.active = checked

                }
                */

                onVisibleChanged: {
                    if (!visible) {
                        pulseInfoLoader.active = false;
                        showInfo.checked = false;
                    }
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onSwapDeviceNowChanged () {
                        if (pulseRuntimeSettings.swapDeviceNow) {
                            pulseInfoLoader.active = false;
                            showInfo.checked = false;
                            console.log("DEV_RESELECT now we want to hide the info panel as well")
                        }
                    }
                }
            }
        }
    }


    Loader {
        id: pulseInfoLoader
        source: pulseRuntimeSettings.expertMode ? "qrc:/PulseTabbedSettingsExpert.qml" : "qrc:/PulseTabbedSettingsNormal.qml"
        //source: "PulseTabbedSettingsV2.qml"
        active: false
        anchors.centerIn: parent
        onItemChanged: {
            if (item) {
                // Connect the signal to set active to false when the close is requested
                item.closeRequested.connect(function() {
                    pulseInfoLoader.active = false;
                    showInfo.checked = false
                });
            }
        }
    }


    Image {
        id: companyWaterMark
        source: "./image/logo_techadvision_gray.png"
        anchors.bottom: parent.bottom
        //anchors.bottomMargin: 40 + Math.max(Insets.bottom, Insets.ime)
        anchors.bottomMargin: insetBottom() + 20
        anchors.left: quickChangeObjects.right
        anchors.leftMargin: 40
        //width: 360
        //height: 43
        width: Math.round(360 * s)
        height: Math.round(43 * s)
        opacity: 60
        visible: pulseRuntimeSettings.devManualSelected && !pulseRuntimeSettings.echogramPause
    }

    Rectangle {
        id: recordingOnScreen
        width: 80
        height: 80
        radius: 5
        anchors.bottom: companyWaterMark.top
        anchors.horizontalCenter: companyWaterMark.horizontalCenter
        //anchors.right: companyWaterMark.right
        visible: pulseRuntimeSettings.isRecordingKlf
        color: "transparent"

        Image {
            id: iconImage
            source: "./icons/ui/pulse_recording_active.svg"
            width: 80
            height: 80
            fillMode: Image.PreserveAspectFit
            smooth: true

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    //console.log("TAV: Recording stopped")
                    core.loggingKlf = false
                    pulseRuntimeSettings.isRecordingKlf = false
                }
            }
        }


        Connections {
            target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
            function onIsRecordingKlfChanged () {
                recordingOnScreen.visible = pulseRuntimeSettings.isRecordingKlf
            }
        }

    }


    Timer {
        id: closePulseSettingsTimer
        interval: 15000   // 30 seconds in milliseconds
        repeat: false
        onTriggered: {
            pulseSettingsLoader.active = false;
        }
    }


    //end of pulse additions
    //**********************

    RowLayout {
        id: settingsRow
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: settingsMenuSpacer

        MenuFrame {
            id: leftPanel
            isOpacityControlled: true
            Layout.alignment: Qt.AlignLeft | Qt.AlignBottom
            Layout.leftMargin: (indx === 1 &&
                                !is3dVisible &&
                                height > plot.height - 130 * theme.resCoeff)
                               ? width
                               : 0
            //Pulse: Hide
            visible: false

            ColumnLayout {
                id: plotControl
                spacing: 4

                CheckButton {
                    id: plotCheckButton
                    backColor: theme.controlBackColor
                    borderColor: theme.controlBackColor
                    checkedBorderColor: theme.controlBorderColor
                    iconSource: "qrc:/icons/ui/settings.svg"
                    implicitWidth: theme.controlHeight*1.2

                    onCheckedChanged: {
                        if (checked) {
                            settingsClicked()
                        }
                        else {
                            plot.endLoupeZoomPreview()
                        }
                    }
                }

                // brightess slider
                CText {
                    Layout.fillWidth: true
                    Layout.topMargin: 0
                    Layout.preferredWidth: theme.controlHeight*1.2
                    // visible: chartEnable.checked // TODO
                    horizontalAlignment: Text.AlignHCenter
                    text: echogramLevelsSlider.stopValue
                    small: true
                }

                ChartLevel {
                    // opacity: 0.8
                    Layout.fillWidth: true
                    Layout.preferredWidth: theme.controlHeight*1.2
                    id: echogramLevelsSlider
                    // visible: chartEnable.checked // TODO
                    Layout.alignment: Qt.AlignHCenter

                    onStartValueChanged: {
                        plot.plotEchogramSetLevels(startValue, stopValue);
                    }

                    onStopValueChanged: {
                        plot.plotEchogramSetLevels(startValue, stopValue);
                    }

                    Component.onCompleted: {
                        plot.plotEchogramSetLevels(startValue, stopValue);
                    }

                    Settings {
                        category: "Plot2D_" + plot.indx

                        property alias echogramLevelsStart: echogramLevelsSlider.startValue
                        property alias echogramLevelsStop: echogramLevelsSlider.stopValue
                    }
                }

                CText {
                    Layout.fillWidth: true
                    Layout.preferredWidth: theme.controlHeight*1.2
                    Layout.bottomMargin: 0
                    // visible: chartEnable.checked // TODO
                    horizontalAlignment: Text.AlignHCenter

                    text: echogramLevelsSlider.startValue
                    small: true
                }
            }
        }

        MenuScroll {
            id: settingsScroll
            //Pulse: Hide
            visible: false
            //visible: plotCheckButton.checked
            Layout.preferredHeight: parent.height

            onVisibleChanged: {
                if (!visible) {
                    plot.endLoupeZoomPreview()
                }
            }

            MenuFrame {
                id: plotSettings

                ParamGroup {
                    groupName: qsTr("Plot")

                    RowLayout {
                        id: rowDataset
                        Layout.fillWidth: true
                        visible: instruments > 1
                        property var channel1List: []
                        property var channel2List: []
                        //CCombo  {
                        //    id: datasetCombo
                        //    Layout.fillWidth: true
                        //      Layout.preferredWidth: columnItem.width/3
                        //    visible: true
                        //    onPressedChanged: {
                        //    }

                        //    Component.onCompleted: {
                        //        model = [qsTr("Dataset #1")]
                        //    }
                        //}

                        CText {
                            text: qsTr("Channels:")
                        }

                        function setChannelNamesToBackend() {
                            plotDatasetChannelFromStrings(channel1Combo.currentText, channel2Combo.currentText)
                            plotCursorChanged(indx, cursorFrom(), cursorTo())
                            if (pulseRuntimeSettings.isSideScan2DView) {
                                console.log("isSideScan2DView, let's fix")
                                if (plot) {
                                    plot.plotDistanceRange2d(plot.quickChangeMaxRangeValue * 1.0)
                                    plot.updatePlot()
                                    console.log("SIDE SCAN: tried to fix the downscan")
                                }
                            }
                        }

                        CCombo  {
                            id: channel1Combo

                            property bool suppressTextSignal: false

                            Layout.fillWidth: true
                            visible: true

                            onCurrentTextChanged: {
                                if (suppressTextSignal) {
                                    return
                                }

                                rowDataset.setChannelNamesToBackend()
                            }

                            Component.onCompleted: {
                                model = dataset.channelsNameList()

                                let index = model.indexOf(core.ch1Name)
                                if (index >= 0) {
                                    channel1Combo.currentIndex = index
                                }
                            }

                            Connections {
                                target: core
                                function onChannelListUpdated() {
                                    let list = dataset.channelsNameList()

                                    channel1Combo.suppressTextSignal = true

                                    channel1Combo.model = []
                                    channel1Combo.model = list
                                    rowDataset.channel1List = list

                                    let newIndex = list.indexOf(core.ch1Name)
                                    if (newIndex >= 0) {
                                        channel1Combo.currentIndex = newIndex
                                    }
                                    else {
                                        channel1Combo.currentIndex = 0
                                    }
                                    console.log("channel_value qml: Got list ch 1", list, "and new index is", newIndex)

                                    channel1Combo.suppressTextSignal = false
                                }
                            }
                        }

                        CCombo  {
                            id: channel2Combo

                            property bool suppressTextSignal: false

                            Layout.fillWidth: true
                            visible: true

                            onCurrentTextChanged: {
                                if (suppressTextSignal) {
                                    return
                                }

                                rowDataset.setChannelNamesToBackend()
                            }


                            Component.onCompleted: {
                                model = dataset.channelsNameList()

                                let index = model.indexOf(core.ch2Name)
                                if (index >= 0) {
                                    channel2Combo.currentIndex = index
                                }
                            }

                            Connections {
                                target: core
                                function onChannelListUpdated() {
                                    let list = dataset.channelsNameList()

                                    channel2Combo.suppressTextSignal = true

                                    channel2Combo.model = []
                                    channel2Combo.model = list
                                    rowDataset.channel2List = list

                                    let newIndex = list.indexOf(core.ch2Name)

                                    if (newIndex >= 0) {
                                        channel2Combo.currentIndex = newIndex
                                    }
                                    else {
                                        channel2Combo.currentIndex = 0
                                    }
                                    console.log("channel_value qml: Got list ch 2", list, "and new index is", newIndex)

                                    channel2Combo.suppressTextSignal = false
                                }
                            }
                        }

                        Connections {
                            target: pulseRuntimeSettings
                            function onUserManualSetNameChanged() {
                                if (!pulseRuntimeSettings || pulseRuntimeSettings.userManualSetName === "...")
                                    return

                                if (rowDataset.channel1List.length === 0 && rowDataset.channel2List.length === 0) {
                                    console.log("channel_value qml: channel list only", rowDataset.channel1List, "aborting")
                                    return
                                }

                                if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                                    console.log("channel_value qml: never need to alter channels for", pulseRuntimeSettings.modelPulseRed)
                                    return
                                }

                                let blueChannelsChanged = false

                                if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue) {
                                    if (rowDataset.channel1List.length > 2) {
                                        var ch1 = 1, ch2 = 2
                                        if (!pulseSettings.isSideScanCableFacingFront) {
                                            ch1 = 2; ch2 = 1
                                        }
                                        if (channel1Combo.currentIndex !== ch1) {
                                            console.log("channel_value qml: altering blue channel1 from", channel1Combo.currentIndex, "to", ch1)
                                            channel1Combo.currentIndex = ch1
                                            blueChannelsChanged = true
                                        } else {
                                            console.log("channel_value qml: blue channel1 was already OK")
                                        }

                                        if (channel2Combo.currentIndex !== ch2) {
                                            console.log("channel_value qml: altering blue channel2 from", channel2Combo.currentIndex, "to", ch2)
                                            channel2Combo.currentIndex = ch2
                                            blueChannelsChanged = true
                                        } else {
                                            console.log("channel_value qml: blue channel2 was already OK")
                                        }
                                    } else {
                                        console.log("channel_value qml: channel list only", rowDataset.channel1List, "aborting")
                                    }
                                }
                                if (blueChannelsChanged) {
                                    rowDataset.setChannelNamesToBackend()
                                    console.log("channel_value qml: channels needed to be changed, did setChannelNamesToBackend ")
                                }
                            }
                        }

                        Connections {
                            target: pulseSettings ? pulseSettings : undefined
                            function onIsSideScanCableFacingFrontChanged () {
                                if (pulseSettings === null)
                                    return
                                console.log("Side scan: onIsSideScanCableFacingFrontChanged observed")
                                if (rowDataset.channel1List.length < 3){
                                    //Not a side scan transducer
                                    return
                                }

                                let blueChannelsChanged = false
                                var ch1 = 1, ch2 = 2
                                if (!pulseSettings.isSideScanCableFacingFront) {
                                    ch1 = 2; ch2 = 1
                                }
                                if (channel1Combo.currentIndex !== ch1) {
                                    console.log("channel_value qml: altering blue channel1 from", channel1Combo.currentIndex, "to", ch1)
                                    channel1Combo.currentIndex = ch1
                                    blueChannelsChanged = true
                                } else {
                                    console.log("channel_value qml: blue channel1 was already OK")
                                }

                                if (channel2Combo.currentIndex !== ch2) {
                                    console.log("channel_value qml: altering blue channel2 from", channel2Combo.currentIndex, "to", ch2)
                                    channel2Combo.currentIndex = ch2
                                    blueChannelsChanged = true
                                } else {
                                    console.log("channel_value qml: blue channel2 was already OK")
                                }

                                if (blueChannelsChanged) {
                                    rowDataset.setChannelNamesToBackend()
                                    console.log("channel_value qml: channels needed to be changed, did setChannelNamesToBackend ")
                                }
                            }
                        }

                    }

                    RowLayout {
                        CCheck {
                            id: echogramVisible
                            Layout.fillWidth: true
                            //                        Layout.preferredWidth: 150
                            checked: true
                            /*
                            checked: {
                                if (pulseRuntimeSettings === null)
                                    return false
                                if (pulseRuntimeSettings.userManualSetName = "...")
                                    return false
                                return pulseRuntimeSettings.echogramVisible
                            }
                            */
                            text: qsTr("Echogram")
                            onCheckedChanged: plotEchogramVisible(checked)
                            Component.onCompleted: plotEchogramVisible(checked)

                            Connections {
                                target: pulseRuntimeSettings
                                function onUserManualSetNameChanged () {
                                    echogramVisible.checked = true
                                }
                            }
                        }

                        //TODO: We should likely implement this better
                        CCombo  {
                            id: echoTheme
                            //                        Layout.fillWidth: true
                            Layout.preferredWidth: 150
                            model: [qsTr("Blue"), qsTr("Sepia"), qsTr("Sepia New"), qsTr("WRGBD"), qsTr("WhiteBlack"), qsTr("BlackWhite"), qsTr("DeepBlue"), qsTr("Ice"), qsTr("Green"), qsTr("Midnight")]
                            currentIndex: 0

                            onCurrentIndexChanged: {
                                plotEchogramTheme(currentIndex)
                                echogramThemeChanged(currentIndex)
                            }
                            Component.onCompleted: {
                                plotEchogramTheme(currentIndex)
                                echogramThemeChanged(currentIndex)
                            }

                            Settings {
                                category: "Plot2D_" + plot.indx

                                property alias waterfallThemeId: echoTheme.currentIndex
                            }
                        }

                        CCombo  {
                            id: echogramTypesList
                            //                        Layout.fillWidth: true
                            Layout.preferredWidth: 150
                            model: [qsTr("Raw"), qsTr("Side-Scan")]
                            currentIndex: 0

                            //onCurrentIndexChanged: plotEchogramCompensation(currentIndex) // TODO
                            //Component.onCompleted: plotEchogramCompensation(currentIndex) // TODO

                            Settings {
                                category: "Plot2D_" + plot.indx

                                property alias echogramTypesList: echogramTypesList.currentIndex
                            }
                            Connections {
                                target: pulseRuntimeSettings !== null ? pulseRuntimeSettings : undefined
                                function onUserManualSetNameChanged () {
                                    if (pulseRuntimeSettings === null)
                                        return
                                    if (pulseRuntimeSettings.userManualSetName === "...") {
                                        return
                                    }
                                    if (pulseRuntimeSettings.is2DTransducer) {
                                    //if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                                        console.log("EchogramCompensation: Plot2D onUserManualSetNameChanged, is2D")
                                        echogramTypesList.currentIndex = 0
                                    } else {
                                        console.log("EchogramCompensation: Plot2D onUserManualSetNameChanged, isSideScan")
                                        echogramTypesList.currentIndex = 1
                                    }
                                    console.log("EchogramCompensation: Plot2D onUserManualSetNameChanged, value now", plot.getEchogramCompensation())
                                }
                            }
                        }
                    }

                    RowLayout {
                        visible: instruments > 0
                        CText {
                            Layout.fillWidth: true
                            text: qsTr("Bottom-Track")
                        }

                        CCheck {
                            id: bottomTrackValueVisible
                            text: qsTr("Value")
                            checked: false // We do not want this additional value for pulse

                            onCheckedChanged: plot.updateBottomTrackPresentation()
                            Component.onCompleted: plot.updateBottomTrackPresentation()
                        }

                        CCheck {
                            id: bottomTrackGraphicsVisible
                            text: qsTr("Line")
                            checked: true

                            onCheckedChanged: plot.updateBottomTrackPresentation()
                            Component.onCompleted: plot.updateBottomTrackPresentation()
                        }

                        CCombo  {
                            id: bottomTrackThemeList
                            //                        Layout.fillWidth: true
                            //                        Layout.preferredWidth: 150
                            model: [qsTr("Line1"), qsTr("Line2"), qsTr("Dot1"), qsTr("Dot2"), qsTr("DotLine")]
                            currentIndex: pulseRuntimeSettings !== null ? pulseRuntimeSettings.bottomTrackVisibleModel : 0

                            onCurrentIndexChanged: plot.updateBottomTrackPresentation()
                            Component.onCompleted: plot.updateBottomTrackPresentation()

                            Settings {
                                category: "Plot2D_" + plot.indx

                                property alias bottomTrackThemeList: bottomTrackThemeList.currentIndex
                            }
                        }

                        Connections {
                            target: pulseRuntimeSettings !== null ? pulseRuntimeSettings : undefined
                            function onUserManualSetNameChanged () {
                                if (pulseRuntimeSettings === null)
                                    return
                                if (pulseRuntimeSettings.userManualSetName === "...") {
                                    return
                                }
                                bottomTrackGraphicsVisible.checked = pulseRuntimeSettings.bottomTrackVisible
                                console.log("DistProcessing: set bottomTrackVisible", pulseRuntimeSettings.bottomTrackVisible)
                            }
                            function onBottomTrackVisibleChanged () {
                                if (pulseRuntimeSettings === null)
                                    return
                                if (pulseRuntimeSettings.userManualSetName === "...") {
                                    return
                                }
                                /* We also want the visible bottom track shown for 2D echo sounders!
                                if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                                    bottomTrackGraphicsVisible.checked = false
                                    return
                                }
                                */

                                console.log("DistProcessing: toggle bottomTrack visibility, show it?", pulseRuntimeSettings.bottomTrackVisible)
                                bottomTrackGraphicsVisible.checked = pulseRuntimeSettings.bottomTrackVisible
                            }

                            // Expert-only: paint the raw rangefinder LINE (orange) for analysis when toggled.
                            // The rangefinder value TEXT stays permanently off (forced in plot2D.cpp);
                            // theme 1 = solid line, theme 0 = no line. Draws only when distance data is present.
                            function onRangefinderTrackVisibleChanged () {
                                if (pulseRuntimeSettings === null)
                                    return
                                console.log("DistProcessing: toggle rangefinder track visibility, show it?", pulseRuntimeSettings.rangefinderTrackVisible)
                                plotRangefinderTheme(pulseRuntimeSettings.rangefinderTrackVisible ? 1 : 0)
                                plotRangefinderVisible(pulseRuntimeSettings.rangefinderTrackVisible)
                            }
                        }
                    }

                    RowLayout {
                        CText {
                            Layout.fillWidth: true
                            text: qsTr("Rangefinder")
                            Component.onCompleted: plotRangefinderVisible(false)
                            /*
                            checked: pulseRuntimeSettings !== null ? pulseRuntimeSettings.rangefinderVisible : false
                            onCheckedChanged: plotRangefinderVisible(checked)
                            Component.onCompleted: plotRangefinderVisible(checked)
                            */
                        }

                        CCheck {
                            id: rangefinderValueVisible
                            text: qsTr("Value")
                            checked: false // Pulse: disable. Pulse has its own in DepthAndTemperature.qml

                            onCheckedChanged: plot.updateRangefinderPresentation()
                            Component.onCompleted: plot.updateRangefinderPresentation()
                        }

                        CCheck {
                            id: rangefinderGraphicsVisible
                            text: qsTr("Text")
                            checked: false // Pulse: disable. Pulse has its own in DepthAndTemperature.qml

                            onCheckedChanged: plot.updateRangefinderPresentation()
                            Component.onCompleted: plot.updateRangefinderPresentation()
                        }

                        CCombo  {
                            id: rangefinderThemeList
                            model: [qsTr("Text"), qsTr("Line"), qsTr("Dot")]
                            currentIndex: pulseRuntimeSettings !== null ? pulseRuntimeSettings.rangefinderVisibleModel : 0

                            onCurrentIndexChanged: plot.updateRangefinderPresentation()
                            Component.onCompleted: plot.updateRangefinderPresentation()

                            Settings {
                                category: "Plot2D_" + plot.indx

                                property alias rangefinderThemeList: rangefinderThemeList.currentIndex
                            }
                        }
                    }


                    CCheck {
                        visible: instruments > 1
                        id: ahrsVisible
                        text: qsTr("Attitude")
                        checked: pulseRuntimeSettings !== null ? pulseRuntimeSettings.ahrsVisible : false
                        onCheckedChanged: plotAttitudeVisible(checked)
                        Component.onCompleted: plotAttitudeVisible(checked)
                    }

                    CCheck {
                        visible: instruments > 1
                        id: temperatureVisible
                        text: qsTr("Temperature")
                        onCheckedChanged: plotTemperatureVisible(checked)
                        Component.onCompleted: plotTemperatureVisible(checked)
                    }

                    RowLayout {
                        visible: instruments > 1
                        id: dopplerBeamVisibleGroup
                        spacing: 0
                        function updateDopplerBeamVisible() {
                            var beamfilter = dopplerBeam1Visible.checked*1 + dopplerBeam2Visible.checked*2 + dopplerBeam3Visible.checked*4 + dopplerBeam4Visible.checked*8
                            plotDopplerBeamVisible(dopplerBeamVisible.checked,
                                                   beamfilter)
                        }

                        CCheck {
                            id: dopplerBeamVisible
                            Layout.fillWidth: true
                            text: qsTr("Doppler Beams")
                            onCheckedChanged: dopplerBeamVisibleGroup.updateDopplerBeamVisible()
                            Component.onCompleted: dopplerBeamVisibleGroup.updateDopplerBeamVisible()
                        }

                        CCheck {
                            id: dopplerBeam1Visible
                            enabled: true
                            checked: true
                            text: "1"

                            onCheckedChanged: dopplerBeamVisibleGroup.updateDopplerBeamVisible()
                        }

                        CCheck {
                            id: dopplerBeam2Visible
                            leftPadding: 0
                            enabled: true
                            checked: true
                            text: "2"
                            onCheckedChanged: dopplerBeamVisibleGroup.updateDopplerBeamVisible()
                        }

                        CCheck {
                            id: dopplerBeam3Visible
                            leftPadding: 0
                            enabled: true
                            checked: true
                            text: "3"
                            onCheckedChanged: dopplerBeamVisibleGroup.updateDopplerBeamVisible()
                        }

                        CCheck {
                            id: dopplerBeam4Visible
                            leftPadding: 0
                            enabled: true
                            checked: true
                            text: "4"
                            onCheckedChanged: dopplerBeamVisibleGroup.updateDopplerBeamVisible()
                        }

                        CCheck {
                            id: dopplerBeamAmpVisible
                            enabled: true
                            checked: true
                            text: "A"
                            onCheckedChanged: dopplerBeamVisibleGroup.updateDopplerBeamVisible()
                        }

                        CCheck {
                            id: dopplerBeamModeVisible
                            leftPadding: 0
                            enabled: true
                            checked: true
                            text: "M"
                            onCheckedChanged: dopplerBeamVisibleGroup.updateDopplerBeamVisible()
                        }
                    }

                    RowLayout {
                        visible: instruments > 1
                        spacing: 0
                        CCheck {
                            id: dopplerInstrumentVisible
                            Layout.fillWidth: true
                            text: qsTr("Doppler Instrument")
                            onCheckedChanged: plotDopplerInstrumentVisible(checked)
                            Component.onCompleted: plotDopplerInstrumentVisible(checked)
                        }

                        CCheck {
                            id: dopplerInstrumentXVisible
                            enabled: false
                            checked: true
                            text: "X"
                            //                        onCheckedChanged: setDopplerInstrumentVis(checked)
                            //                        Component.onCompleted: setDopplerInstrumentVis(checked)
                        }

                        CCheck {
                            id: dopplerInstrumentYVisible
                            enabled: false
                            checked: true
                            text: "Y"
                            //                        onCheckedChanged: setDopplerInstrumentVis(checked)
                            //                        Component.onCompleted: setDopplerInstrumentVis(checked)
                        }

                        CCheck {
                            id: dopplerInstrumentZVisible
                            enabled: false
                            checked: true
                            text: "Z"
                            //                        onCheckedChanged: setDopplerInstrumentVis(checked)
                            //                        Component.onCompleted: setDopplerInstrumentVis(checked)
                        }
                    }

                    RowLayout {
                        visible: instruments > 1
                        id: acousticAngleGroup
                        spacing: 0

                        CCheck {
                            id: acousticAngleVisible
                            Layout.fillWidth: true
                            text: qsTr("Acoustic angle")
                            onCheckedChanged: plotAcousticAngleVisible(checked);
                            Component.onCompleted: plotAcousticAngleVisible(checked);
                        }
                    }

                    RowLayout {
                        visible: instruments > 1
                        CCheck {
                            id: adcpVisible
                            enabled: false
                            Layout.fillWidth: true
                            text: qsTr("Doppler Profiler")
                        }
                    }

                    RowLayout {
                        visible: instruments > 1
                        CCheck {
                            id: gnssVisible
                            checked: false
                            Layout.fillWidth: true
                            text: qsTr("GNSS data")

                            onCheckedChanged: plotGNSSVisible(checked, 1)
                            Component.onCompleted: plotGNSSVisible(checked, 1)

                            Settings {
                                category: "Plot2D_" + plot.indx

                                property alias gnssVisible: gnssVisible.checked
                            }
                        }
                    }


                    RowLayout {
                        RowLayout {
                            CCheck {
                                id: gridVisible
                                Layout.fillWidth: true
                                text: qsTr("Grid")
                                checked: false
                                onCheckedChanged: plotGridVerticalNumber(gridNumber.value*gridVisible.checked)
                            }
                            CCheck {
                                id: fillWidthGrid
                                Layout.fillWidth: true
                                text: qsTr("fill")
                                checked: false
                                //Pulse
                                //onCheckedChanged: plotGridFillWidth(checked)
                                onCheckedChanged: plotGridFillWidth(false)
                                visible: gridVisible.checked

                                Component.onCompleted: {
                                    plotGridFillWidth(checked)
                                }
                                Settings {
                                    category: "Plot2D_" + plot.indx

                                    property alias fillWidthGrid: fillWidthGrid.checked
                                }
                            }

                            Connections {
                                target: pulseRuntimeSettings

                                function onUserManualSetNameChanged () {
                                    if (pulseRuntimeSettings === null)
                                        return
                                    gridVisible.checked = true
                                }
                            }
                                    
                            CCheck {
                                id: invertGrid
                                Layout.fillWidth: true
                                text: qsTr("invert")
                                onCheckedChanged: plotGridInvert(checked)
                                visible: gridVisible.checked

                                Component.onCompleted: {
                                    plotGridInvert(checked)
                                }
                                Settings {
                                    category: "Plot2D_" + plot.indx
                                    property alias invertGrid: invertGrid.checked
                                }
                            }
                        }

                        SpinBoxCustom {
                            id: gridNumber
                            from: 1
                            to: 24
                            stepSize: 1
                            value: 5

                            onValueChanged: plotGridVerticalNumber(gridNumber.value*gridVisible.checked)
                            Component.onCompleted: plotGridVerticalNumber(gridNumber.value*gridVisible.checked)

                            Settings {
                                category: "Plot2D_" + plot.indx

                                property alias gridNumber: gridNumber.value
                            }
                        }
                    }

                    RowLayout {
                        visible: instruments > 1

                        CCheck {
                            id: angleVisible
                            Layout.fillWidth: true
                            text: qsTr("Angle range, °")
                            checked: pulseRuntimeSettings !== null ? pulseRuntimeSettings.angleVisible : false
                            onCheckedChanged: plotAngleVisibility(checked)
                            Component.onCompleted: plotAngleVisibility(checked)

                            Settings {
                                category: "Plot2D_" + plot.indx

                                property alias angleVisible: angleVisible.checked
                            }
                        }

                        SpinBoxCustom {
                            id: angleRange
                            from: 1
                            to: 360
                            stepSize: 1
                            value: 45

                            onValueChanged: plotAngleRange(angleRange.currValue)
                            Component.onCompleted: plotAngleRange(angleRange.currValue)

                            property int currValue: value

                            validator: DoubleValidator {
                                bottom: Math.min(angleRange.from, angleRange.to)
                                top:  Math.max(angleRange.from, angleRange.to)
                            }

                            textFromValue: function(value, locale) {
                                return Number(value).toLocaleString(locale, 'f', 0)
                            }

                            valueFromText: function(text, locale) {
                                return Number.fromLocaleString(locale, text)
                            }

                            onCurrValueChanged: plotAngleRange(currValue)

                            Settings {
                                category: "Plot2D_" + plot.indx

                                property alias angleRange: angleRange.value
                            }
                        }
                    }


                    RowLayout {
                        visible: instruments > 1
                        CCheck {
                            id: velocityVisible
                            Layout.fillWidth: true
                            text: qsTr("Velocity range, m/s")
                            checked: pulseRuntimeSettings !== null ? pulseRuntimeSettings.velocityVisible : false
                            onCheckedChanged: plotVelocityVisible(checked)
                            Component.onCompleted: plotVelocityVisible(checked)

                            Settings {
                                category: "Plot2D_" + plot.indx

                                property alias velocityVisible: velocityVisible.checked
                            }
                        }

                        SpinBoxCustom {
                            id: velocityRange
                            from: 500
                            to: 1000*8
                            stepSize: 500
                            value: 5

                            onValueChanged: plotVelocityRange(velocityRange.realValue)
                            Component.onCompleted: plotVelocityRange(velocityRange.realValue)

                            property int decimals: 1
                            property real realValue: value / 1000

                            validator: DoubleValidator {
                                bottom: Math.min(velocityRange.from, velocityRange.to)
                                top:  Math.max(velocityRange.from, velocityRange.to)
                            }

                            textFromValue: function(value, locale) {
                                return Number(value / 1000).toLocaleString(locale, 'f', decimals)
                            }

                            valueFromText: function(text, locale) {
                                return Number.fromLocaleString(locale, text) * 1000
                            }

                            onRealValueChanged: plotVelocityRange(realValue)

                            Settings {
                                category: "Plot2D_" + plot.indx

                                property alias velocityRange: velocityRange.value
                            }
                        }
                    }

                    RowLayout {
                        id: distanceAutoRangeRow
                        function distanceAutorangeMode() {
                            plotDistanceAutoRange(distanceAutoRange.checked ? distanceAutoRangeList.currentIndex : -1)
                        }

                        CCheck {
                            id: distanceAutoRange
                            checked: pulseRuntimeSettings !== null ? pulseRuntimeSettings.distanceAutoRange : false
                            Layout.fillWidth: true
                            text: qsTr("Distance auto range")

                            onCheckedChanged: {
                                distanceAutoRangeRow.distanceAutorangeMode()
                            }
                            Component.onCompleted: distanceAutoRangeRow.distanceAutorangeMode()

                            Settings {
                                category: "Plot2D_" + plot.indx

                                property alias distanceAutoRange: distanceAutoRange.checked
                            }
                        }

                        CCombo  {
                            id: distanceAutoRangeList
                            model: [qsTr("Last data       "), qsTr("Last on screen"), qsTr("Max on screen")]
                            currentIndex: pulseRuntimeSettings !== null ? pulseRuntimeSettings.distanceAutoRangeCurrentIndex : 0
                            onCurrentIndexChanged: distanceAutoRangeRow.distanceAutorangeMode()
                            Component.onCompleted: distanceAutoRangeRow.distanceAutorangeMode()

                            Settings {
                                category: "Plot2D_" + plot.indx

                                property alias distanceAutoRangeList: distanceAutoRangeList.currentIndex
                            }
                        }
                    }

                    CCheck {
                        id: horisontalVertical
                        checked: true
                        text: qsTr("Horizontal")
                    }

                    RowLayout {
                        CCheck {
                            id: loupeVisible
                            Layout.fillWidth: true
                            checked: false
                            text: qsTr("Loupe")

                            onCheckedChanged: plotLoupeVisible(checked)
                            Component.onCompleted: plotLoupeVisible(checked)
                        }

                        RowLayout {
                            visible: loupeVisible.checked

                            CText {
                                text: qsTr("size")
                            }
                            SpinBoxCustom {
                                id: loupeSize
                                from: 1
                                to: 3
                                stepSize: 1
                                value: 1

                                onValueChanged: plotLoupeSize(value)
                                Component.onCompleted: plotLoupeSize(value)
                            }
                        }
                        RowLayout {
                            visible: loupeVisible.checked
                            spacing: Math.max(6, Math.round(theme.controlHeight * 0.2))

                            CText {
                                text: qsTr("zoom")
                            }

                            ChartLevelSingle {
                                id: loupeZoom
                                Layout.fillWidth: true
                                Layout.preferredWidth: theme.controlHeight * 5
                                from: 0
                                to: 300
                                stepSize: 1
                                value: 100

                                onValueChanged: plotLoupeZoom(Math.round(value))

                                onPressedChanged: {
                                    if (pressed) {
                                        plot.beginLoupeZoomPreview()
                                    }
                                    else {
                                        plot.endLoupeZoomPreview()
                                    }
                                }

                                onMoved: {
                                    plot.updateLoupeZoomPreview()
                                }

                                Component.onCompleted: plotLoupeZoom(Math.round(value))
                            }

                            CText {
                                text: Math.round(loupeZoom.value) + "%"
                                small: true
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: theme.controlHeight * 1.7
                            }
                        }
                    }

                    Settings {
                        category: "Plot2D_" + plot.indx

                        property alias echogramVisible: echogramVisible.checked
                        property alias rangefinderVisible: rangefinderGraphicsVisible.checked
                        property alias rangefinderValueVisible: rangefinderValueVisible.checked
                        property alias postProcVisible: bottomTrackGraphicsVisible.checked
                        property alias bottomTrackValueVisible: bottomTrackValueVisible.checked
                        property alias rangefinderGraphicsVisible: rangefinderGraphicsVisible.checked
                        property alias bottomTrackGraphicsVisible: bottomTrackGraphicsVisible.checked
                        property alias ahrsVisible: ahrsVisible.checked
                        property alias temperatureVisible: temperatureVisible.checked
                        property alias gridVisible: gridVisible.checked
                        property alias dopplerBeamVisible: dopplerBeamVisible.checked
                        property alias dopplerInstrumentVisible: dopplerInstrumentVisible.checked
                        property alias horisontalVertical: horisontalVertical.checked
                        property alias loupeVisible: loupeVisible.checked
                        property alias loupeSize: loupeSize.value
                        property alias loupeZoom: loupeZoom.value
                    }
                }
            } // menu frame
        } // menu scrol
    } // row layout

    CContact {
        id: contactDialog

        onVisibleChanged: {
            if (!visible) {
                parent.focus = true

                if (accepted) {
                    plot.setContact(contactDialog.indx, contactDialog.inputFieldText)
                    updateOtherPlot(plot.indx)
                    accepted = false
                }
                contactDialog.info = ""
                contactDialog.inputFieldText = ""
            }
        }

        onDeleteButtonClicked: {
            plot.deleteContact(contactDialog.indx)
            updateOtherPlot(plot.indx)
        }

        onCopyButtonClicked: {
            plot.updateContact()
        }

        onSetActiveButtonClicked: {
            plot.setActiveContact(contactDialog.indx)
        }

        onInputAccepted: {
            contactDialog.visible = false
            plot.updateContact()
        }

        onSetButtonClicked: {
            contactDialog.visible = false
            plot.updateContact()
        }
    }


    onContactVisibleChanged: {
        contactDialog.visible = plot.contactVisible;

        if (contactDialog.visible) {
            contactDialog.info = plot.contactInfo
            contactDialog.inputFieldText =  plot.contactInfo
        }
        else {
            contactDialog.info = ""
            contactDialog.inputFieldText = ""
        }

        contactDialog.x = plot.contactPositionX
        contactDialog.y = plot.contactPositionY
        contactDialog.indx = plot.contactIndx
        contactDialog.lat = plot.contactLat
        contactDialog.lon = plot.contactLon
        contactDialog.depth = plot.contactDepth
    }


    RowLayout {
        id: menuBlock
        Layout.alignment: Qt.AlignHCenter
        spacing: 1
        //Pulse: Hide
        visible: false
        Layout.margins: 0

        function position(mx, my) {
            var oy = plot.height - (my + implicitHeight)
            if(oy < 0) {
                my = my + oy
            }

            if(my < 0) {
                my = 0
            }

            var ox = plot.width - (mx - implicitWidth)
            if(ox < 0) {
                mx = mx + ox
            }

            x = mx
            y = my
            visible = true
//            backgrn.focus = true
        }

        ButtonGroup { id: pencilbuttonGroup }

        CheckButton {
            icon.source: "qrc:/icons/ui/direction_arrows.svg"
            checked: true
            backColor: theme.controlBackColor
            implicitWidth: theme.controlHeight

            onCheckedChanged: {
                if (checked) {
                    plot.plotMouseTool(1)
                }
            }

            ButtonGroup.group: pencilbuttonGroup
        }

        CheckButton {
            icon.source: "qrc:/icons/ui/arrow_bar_to_down.svg"
            backColor: theme.controlBackColor
            implicitWidth: theme.controlHeight

            onCheckedChanged: {
                if (checked) {
                    plot.plotMouseTool(2)
                }
            }

            ButtonGroup.group: pencilbuttonGroup
        }

        CheckButton {
            icon.source: "qrc:/icons/ui/pencil.svg"
            backColor: theme.controlBackColor
            implicitWidth: theme.controlHeight

            onCheckedChanged: {
                if (checked) {
                    plot.plotMouseTool(3)
                }
            }

            ButtonGroup.group: pencilbuttonGroup
        }

        CheckButton {
            icon.source: "qrc:/icons/ui/arrow_bar_to_up.svg"
            backColor: theme.controlBackColor
            implicitWidth: theme.controlHeight

            onCheckedChanged: {
                if (checked) {
                    plot.plotMouseTool(4)
                }
            }

            ButtonGroup.group: pencilbuttonGroup
        }

        CheckButton {
            icon.source: "qrc:/icons/ui/eraser.svg"
            backColor: theme.controlBackColor
            implicitWidth: theme.controlHeight

            onCheckedChanged: {
                if (checked) {
                    plot.plotMouseTool(5)
                }
            }

            ButtonGroup.group: pencilbuttonGroup
        }

        CheckButton {
            icon.source: "qrc:/icons/ui/anchor.svg"
            backColor: theme.controlBackColor
            implicitWidth: theme.controlHeight
            checkable: false

            onClicked: {
                contactDialog.x = mousearea.contactMouseX
                contactDialog.y = mousearea.contactMouseY
                contactDialog.visible = true;

                contactDialog.indx = -1

                menuBlock.visible = false
            }

            ButtonGroup.group: pencilbuttonGroup
        }

        CheckButton {
            icon.source: "qrc:/icons/ui/x.svg"
            backColor: theme.controlBackColor
            checkable: false
            implicitWidth: theme.controlHeight

            onClicked: {
                menuBlock.visible = false
            }

            ButtonGroup.group: pencilbuttonGroup
        }
    }
}

