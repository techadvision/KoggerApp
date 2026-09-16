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
    // THE MIRRORED PANE'S RESET, which must not broadcast a clear back at the pane the user
    // is touching. See the x == -1 branch of Plot2D::setMousePosition.
    function resetSyncAim() {
        plotMousePosition(-1, -1, true)
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
            plot.setDownBlendMode(pulseRuntimeSettings.downScanBlendMode)
            plot.setDownBlendDomain(pulseRuntimeSettings.downScanBlendDomain)
            plot.setDownBlendTrimDb(pulseRuntimeSettings.downScanBlendTrimDb)

            // Water body filter: its strength lives in a C++ atomic and is ONLY ever
            // pushed through applyFiltering(). Push it here so the filter is genuinely
            // active on both models from the first frame instead of waiting for the
            // tester to touch the filter slider. Gated so that with the filter switched
            // off the old (2D-only) behaviour is untouched.
            plot.setWaterBodyBottomGuard(pulseRuntimeSettings.echogramWaterBodyBottomMargin)
            if (pulseRuntimeSettings.echogramWaterBodyFilterEnabled
                    || pulseRuntimeSettings.is2DTransducer) {
                pulseUi.applyFiltering(pulseSettings.filterRealValue)
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
            let comp = pulseRuntimeSettings.echogramTvgEnabled ? pulseRuntimeSettings.echogram2DGainId : 0
            console.log("EchogramCompensation: Plot2D onEchogramTvgEnabledChanged, resolved", comp)
            plot.plotEchogramCompensation(comp)
            pulseRuntimeSettings.echogramCompensationFile = comp
        }

        // PULSE 2026-09-12: the 2D gain-law comparison switch. Flips a live 2D render
        // between PULSE's EchogramTvg (2) and upstream 1.0.3's linear TGC ramp (4)
        // without touching the TVG on/off state, so the two pictures can be compared
        // on the water on the same data. Ignores every side scan id and raw, exactly
        // like the TVG toggle above: with TVG off there is no gain law to choose.
        function onEchogram2DUpstreamTgcChanged () {
            if (pulseRuntimeSettings === null)
                return
            let cur = plot.getEchogramCompensation()
            if (cur !== 2 && cur !== 4) {
                console.log("EchogramCompensation: 2D gain-law switch ignored, current compensation", cur)
                return
            }
            // Push PULSE's decay constant first so C++ matches QML before the id moves,
            // the same belt-and-braces the TVG toggle does.
            plot.setTvgDbPerMeter(pulseRuntimeSettings.echogramTvgDbPerMeter)
            let comp = pulseRuntimeSettings.echogram2DGainId
            console.log("EchogramCompensation: Plot2D onEchogram2DUpstreamTgcChanged, resolved", comp,
                        pulseRuntimeSettings.echogram2DUpstreamTgc ? "(upstream TGC ramp)" : "(PULSE EchogramTvg)")
            plot.plotEchogramCompensation(comp)
            pulseRuntimeSettings.echogramCompensationFile = comp
            plot.updatePlot()
        }

        // PULSE TVG: live tuning of the decay constant (dB/m); the C++ side
        // refreshes the echogram itself when TVG is the active compensation.
        function onEchogramTvgDbPerMeterChanged () {
            if (pulseRuntimeSettings === null)
                return
            console.log("EchogramCompensation: TVG dB/m ->", pulseRuntimeSettings.echogramTvgDbPerMeter)
            plot.setTvgDbPerMeter(pulseRuntimeSettings.echogramTvgDbPerMeter)
        }

        // PULSE P3: the down scan blend - which of the two side scan channels the down
        // pane draws, and whether they are combined before or after the gain law.
        // echogram_blend.h holds the law; the C++ setters drop the per-epoch caches and
        // repaint, so the picture changes under the tester as the row is tapped.
        //
        // No guard on the compensation id, unlike the TVG handlers above: the blend sits
        // UNDER every image type rather than being one of them, so there is no current
        // id that would make the change invisible. No guard on the picture either - a
        // side scan pane's range crosses zero and never reaches the blended path, so a
        // value pushed while a side scan is up simply waits for the down pane.
        function onDownScanBlendModeChanged () {
            if (pulseRuntimeSettings === null)
                return
            console.log("BLEND: down scan channels ->", pulseRuntimeSettings.downScanBlendMode,
                        ["single", "RMS", "mean", "max"][pulseRuntimeSettings.downScanBlendMode])
            plot.setDownBlendMode(pulseRuntimeSettings.downScanBlendMode)
        }

        function onDownScanBlendDomainChanged () {
            if (pulseRuntimeSettings === null)
                return
            console.log("BLEND: down scan domain ->", pulseRuntimeSettings.downScanBlendDomain,
                        pulseRuntimeSettings.downScanBlendDomain === 1 ? "after the gain law"
                                                                       : "raw, gain applied to the blend")
            plot.setDownBlendDomain(pulseRuntimeSettings.downScanBlendDomain)
        }

        function onDownScanBlendTrimDbChanged () {
            if (pulseRuntimeSettings === null)
                return
            console.log("BLEND: channel balance ->", pulseRuntimeSettings.downScanBlendTrimDb,
                        "dB, half each way,",
                        pulseRuntimeSettings.downScanBlendTrimDb === 0 ? "matched"
                      : pulseRuntimeSettings.downScanBlendTrimDb > 0   ? "favouring channel 2"
                                                                       : "favouring channel 1")
            plot.setDownBlendTrimDb(pulseRuntimeSettings.downScanBlendTrimDb)
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
            // 4 is a 2D id too since the gain-law split (2026-09-12) — upstream's TGC ramp.
            if (cur === 0 || cur === 2 || cur === 4) {
                console.log("EchogramCompensation: side scan TVG toggle ignored, 2D compensation active (", cur, ")")
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
            pulseUi.applyFiltering(pulseSettings.filterRealValue)
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
                    pulseUi.setMaxDepth(newMaxDepthValue)
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
                            pulseUi.setMaxDepth(newVal)
                        }
                    } else {
                        plot.verZoomEvent((pinch.previousScale - pinch.scale)*50.0)
                        let newMaxDepthValue = Math.abs(plot.getMaxDepth())
                        plot.quickChangeMaxRangeValue = newMaxDepthValue
                        pulseUi.setMaxDepth(newMaxDepthValue)
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
                        pulseUi.setMaxDepth(newVal)
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
                            pulseUi.armOldDataWarning()
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


    //Pulse UI - now lives in PulseApp.qml
    //*****************************************
    PulseApp {
        id: pulseUi
        anchors.fill: parent
        pinch: pinch2D
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

