import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 1.2
import Qt.labs.settings 1.1

import WaterFall 1.0

WaterFall {
    id: plot

    property bool is3dVisible: false
    property int indx: 0
    property int instruments: instrumentsGradeList.currentIndex

    horizontal: horisontalVertical.checked

    //Component.onCompleted: plot.setSettingsBus(settingsBus)

    function setLevels(low, high) {
        echogramLevelsSlider.startValue = low
        echogramLevelsSlider.stopValue = high
        echogramLevelsSlider.startPointY = echogramLevelsSlider.valueToPosition(low);
        echogramLevelsSlider.stopPointY = echogramLevelsSlider.valueToPosition(high);
        echogramLevelsSlider.update()
    }

    function closeSettings() {
        plotCheckButton.checked = false
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

    signal plotCursorChanged(int indx, real from, real to)
    signal updateOtherPlot(int indx)
    signal plotPressed(int indx, int mousex, int mousey)
    signal plotReleased(int indx)
    signal settingsClicked()

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

    Rectangle {
        id: configurationInProgressIndicator
        // start hidden
        visible: !pulseRuntimeSettings.devConfigured && pulseRuntimeSettings.dataUpdateActive
        anchors.top: parent.top
        anchors.topMargin: 60 + insetTop()
        anchors.left: parent.left
        anchors.leftMargin: 20

        // styling: semi-transparent black, rounded corners
        color: "#80000000"
        //opacity: 0.6
        radius: height / 2

        // padding around the text
        property int contentMargin: 12

        // size to fit the text + padding
        implicitWidth: configurationInProgressText.width + contentMargin*2
        implicitHeight: _isAndroid ? 80 : 60 //configurationInProgressText.height + contentMargin*2

        // the actual label
        Text {
            id: configurationInProgressText
            text: {
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
        interval: 5000
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
                if (pulseRuntimeSettings.is2DTransducer) {
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
                }
            }

            /*
            else {
                if (Math.abs(pinchStartPos.x - pinch.center.x) > thresholdXAxis) {
                    movementX = true
                }
                else if (Math.abs(pinchStartPos.y - pinch.center.y) > thresholdYAxis) {
                    movementY = true
                }
                else if (pinch.scale > (1.0 + zoomThreshold) || pinch.scale < (1.0 - zoomThreshold)) {
                    zoomY = true
                }
            }
            */
            //***************
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

            onPressed: {
                lastMouseX = mouse.x
                //Pulse addition
                lastMouseY = mouse.y
                mousearea.pressButton = mouse.button
                //**************

                if (pulseRuntimeSettings.echogramPause) {
                    startMousePos = Qt.point(mouse.x, mouse.y)
                }
                plot.draggingInPaused = false

                if (pulseRuntimeSettings.echogramPause &&
                    mouse.button === Qt.LeftButton &&
                    plot.isTapInsideZoomForQml(mouse.x, mouse.y)) {

                    // Forward to C++ so Plot2DAim can handle buttons/panel,
                    // but do NOT treat this as an echogram tap.
                    plot.plotMousePosition(mouse.x, mouse.y)

                    longPressTimer.stop()
                    mousearea.wasMoved = false
                    mousearea.draggingInPaused = false
                    mousearea.longPressFired = false

                    return
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

            onReleased: {
                lastMouseX = -1
                //Pulse addition
                lastMouseY = -1
                //**************

                var insideZoom = pulseRuntimeSettings.echogramPause &&
                                     plot.isTapInsideZoomForQml(mouse.x, mouse.y)

                if (insideZoom && mouse.button === Qt.LeftButton) {
                    // Popup tap/drag release:
                    //  - C++ already processed the press for buttons/panel
                    //  - We just clean up gesture state and go home.
                    if (Qt.platform.os === "android") {
                        longPressTimer.stop()
                    }

                    draggingInPaused = false
                    wasMoved = false
                    startMousePos = Qt.point(-1, -1)
                    dragCommitX = -1
                    dragCommitY = -1

                    return
                }

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
                lastMouseX = -1
                //Pulse addition
                lastMouseY = -1
                //**************
                if (pulseRuntimeSettings.echogramPause || draggingInPaused) {
                    //plot.setDragActive(false)
                }
                draggingInPaused = false
                plot.draggingInPaused = false

                if (Qt.platform.os === "android") {
                    longPressTimer.stop()
                }

                wasMoved = false
                startMousePos = Qt.point(-1, -1)
                plotReleased(indx)
            }

            onPositionChanged: {
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
                            plot.draggingInPaused = true
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
                    //plot.simplePlotMousePosition(mouse.x, mouse.y)
                    //plotPressed(indx, mouse.x, mouse.y)
                    //plotReleased(indx)
                    //wasMoved = false
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
        function _hasInsets() { return _isAndroid && (typeof Insets !== "undefined"); }
        // Safe accessors (0 on non-Android or when Insets missing)
        function insetTop()    { return _hasInsets() && Insets.dexEnabled ? Insets.top    : 0; }
        function insetBottom() { return _hasInsets() ? Insets.bottom : 0; }
        function insetLeft()   { return _hasInsets() ? Insets.left   : 0; }
        function insetRight()  { return _hasInsets() ? Insets.right  : 0; }
        function insetsIme()   { return _hasInsets() ? Insets.ime  : 0; }

        width: _isAndroid ? 710 : 480
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

        function doAutoFilter() {
            if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
                    || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlueProto) {
                //console.log("TAV: auto filter not be set for pulseBlue")
                return
            }

            if (pulseSettings.autoFilter) {
                let currentMaxDept = pulseRuntimeSettings.autoDepthMaxLevel

                let filter = getFilterForDepth (currentMaxDept)
                filter = Math.ceil(filter * 2.5)
                plot.setFilteringValue(filter)
                plot.updatePlot()
                //console.log("TAV: auto filter updated plot to real newFilterValue", filter);

            } else {
                //console.log("TAV: auto filter not active");
            }
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
            GridLayout.row: 0
            GridLayout.column: 0
            Layout.rowSpan: 2
            Layout.preferredWidth: _isAndroid ? 370 : 260
            //Layout.preferredWidth: 370
            opacity: (quickChangeObjects.isDeviceDetected) ? 1 : 1
            enabled: (quickChangeObjects.isDeviceDetected)
        }

        HorizontalController {
            id: selectorMaxDepth
            visible: pulseSettings.areUiControlsVisible && !pulseRuntimeSettings.echogramPause

            GridLayout.row: 0
            GridLayout.column: 1
            Layout.preferredWidth: _isAndroid ? 330 : 220
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
                console.log("pinch: onSelectorValueChanged: ", value);
                plot.quickChangeMaxRangeValue = value;
                if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                    pulseSettings.maxDepthValue = value;
                } else {
                    if (pulseRuntimeSettings.isSideScan2DView) {
                        pulseSettings.maxDepthValuePulseBlue = value;
                    } else {
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

            Component.onCompleted: {
                if (pulseSettings.autoRange) {
                    if (pulseRuntimeSettings.is2DTransducer) {
                    //if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                        pulseRuntimeSettings.shouldDoAutoRange = true
                        plot.plotDistanceAutoRange(0);
                    }
                } else {
                    pulseRuntimeSettings.shouldDoAutoRange = false
                    plot.plotDistanceAutoRange(-1);
                    if (pulseRuntimeSettings.is2DTransducer) {
                    //if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                        plot.plotDistanceRange(pulseSettings.maxDepthValue * 1.0)
                        pulseRuntimeSettings.manualSetLevel = pulseSettings.maxDepthValue * 1.0
                    } else {
                        if (pulseRuntimeSettings.isSideScan2DView) {
                            plot.plotDistanceRange(pulseSettings.maxDepthValuePulseBlue * 1.0)
                            pulseRuntimeSettings.manualSetLevel = pulseSettings.maxDepthValuePulseBlue * 1.0
                        } else {
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
            GridLayout.row: 1
            GridLayout.column: 1
            Layout.preferredWidth: _isAndroid ? 330 : 220
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
                    console.log("DEVICE CONFIGURED: Device configuration completed, set proper value for intensity")
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
            GridLayout.row: 2
            GridLayout.column: 1
            Layout.preferredWidth: _isAndroid ? 330 : 220
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
                plot.setFilteringValue(actualValue)
                //console.log("TAV: selectorFiltering changed filter (presented):", value, " (actual):", actualValue);
            }

            Component.onCompleted: {
                if (pulseRuntimeSettings.is2DTransducer) {
                //if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                    plot.setFilteringValue(pulseSettings.filterRealValue)
                    if (pulseSettings.autoFilter) {
                        quickChangeObjects.doAutoFilter()
                    }
                }
            }

            onFilterAutoRangeRequested: {
                //console.log("TAV: Auto filter requested");
                if (!pulseRuntimeSettings.is2DTransducer)
                    return
                pulseSettings.autoFilter = true
                quickChangeObjects.doAutoFilter()
            }

            onFilterFixedRangeRequested: {
                //console.log("TAV: Fixed filter requested");
                pulseSettings.autoFilter = false;
                let preferredValue = pulseSettings.filterRealValue
                plot.setFilteringValue(preferredValue)

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
                    if (pulseRuntimeSettings.is2DTransducer) {
                    //if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                        plot.setFilteringValue(pulseSettings.filterRealValue)
                        if (pulseSettings.autoFilter) {
                            quickChangeObjects.doAutoFilter()
                        }
                        plot.updatePlot()
                    }
                }
            }
        }

        RowLayout {
            id: quickChangeMedia
            spacing: 2
            Layout.topMargin: 10

            GridLayout.row: 3
            GridLayout.column: 1
            Layout.preferredWidth: _isAndroid ? 350 : 220

            HorizontalCheckController {
                id: echogramPlayPause
                iconSource: "./icons/ui/pulse_crosshair.svg"
                controleName: "echogramPlayPause"
                checked: false
                onStateChanged: {
                    pulseRuntimeSettings.echogramPause = checked
                    if (checked) {
                        oldDataWarningRemovalTimer.stop()
                        oldDataIndicator.visible = false
                        pauseDataIndicator.visible = true
                    } else {
                        pauseDataIndicator.visible = false
                        let nowLive = plot.timelinePosition >= 0.999
                        if (!nowLive && !pulseRuntimeSettings.wasKlfFileOpened) {
                            oldDataIndicator.visible = true
                            oldDataWarningRemovalTimer.start()
                        }
                    }
                }
            }
            HorizontalCheckController {
                id: recordingStartStop
                iconSource: "./icons/ui/pulse_recording_mini.svg"
                controleName: "RecordKlf"
                checked: false
                visible: pulseSettings.areUiControlsVisible && !pulseRuntimeSettings.echogramPause && !pulseRuntimeSettings.wasKlfFileOpened
                onStateChanged: {
                    pulseRuntimeSettings.isRecordingKlf = checked
                    core.loggingKlf = pulseRuntimeSettings.isRecordingKlf
                }
            }
        }

        RowLayout {
            id: quickChangeTheme
            spacing: 2
            Layout.topMargin: 10
            visible: pulseSettings.areUiControlsVisible && !pulseRuntimeSettings.echogramPause

            GridLayout.row: 2
            GridLayout.column: 0
            Layout.preferredWidth: _isAndroid ? 350 : 220


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

                function recalcSelectedIndex() {
                    if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue)
                        return
                    // 1. Figure out where in the *visible* list we live
                    var idx = themeList.findIndex(function(item){
                        return item.id === pulseSettings.colorMapIndexReal
                    })
                    selectedIndex = idx >= 0 ? idx : 0

                    // 2. Grab that theme object
                    var theme = themeList[selectedIndex]

                    // 3. Map it back into the *master* red‐themes array
                    var globalIdx = pulseRuntimeSettings.themeModelRed.findIndex(function(i){
                        return i.id === theme.id
                    })

                    // 4. Always update BOTH your stored indices
                    pulseSettings.colorMapIndex2D   = globalIdx
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
                            plot.plotEchogramTheme(pulseSettings.colorMapIndexReal)
                            plot.updatePlot()
                        }
                    }
                }
            }

            HorizontalPopUpController {
                id: themeSelector2
                visible: !pulseRuntimeSettings.is2DTransducer
                model: [
                    "./icons/ui/pulse_view_down_scan_460.svg",
                    "./icons/ui/pulse_view_down_scan_820.svg",
                    "./icons/ui/pulse_view_side_scan_460.svg",
                    "./icons/ui/pulse_view_side_scan_820.svg"
                ]
                iconSource: "./icons/ui/pulse_glasses.svg"
                selectedIndex: pulseSettings.ecoViewIndex
                hostWindow: plot ? plot : undefined
                //allowExpertModeByMultiTap: false
                onIconSelected: {
                    plot.plotEchogramCompensation(selectedIndex);
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
                    //Set the offset TODO: DIABLED FOR NOW
                    /*
                    if (pulseSettings === null)
                        return
                    let sideScanOffet = pulseSettings.pulseBlueOffset
                    pulseRuntimeSettings.chartOffset = sideScanOffet
                    */
                    //Set the frequency
                    pulseRuntimeSettings.transFreq = frequency
                }

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

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onUserManualSetNameChanged () {
                        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
                                || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlueProto) {

                            setPulseBlueEcoViewOnAppStart.start()
                        }
                    }
                }

                Connections {
                    target: pulseSettings ? pulseSettings : undefined
                    function onColorMapIndexSideScanChanged () {
                        if (pulseSettings === null)
                            return
                        themeSelectorColor2D.selectedIndex = pulseSettings.colorMapIndexSideScan
                        //console.log("TAV: colormap updated to index:", pulseSettings.colorMapIndexSideScan);
                    }
                    function onPulseBlueOffsetChanged () {
                        if (pulseSettings === null)
                            return
                        if (pulseRuntimeSettings == null)
                            return
                        if (pulseRuntimeSettings.is2DTransducer)
                                return
                        //TODO DISABLED FOR NOW
                        /*
                        let sideScanOffet = pulseSettings.pulseBlueOffset
                        if (pulseRuntimeSettings.isSideScan2DView) {
                            pulseRuntimeSettings.chartOffset = 0
                        } else {
                            pulseRuntimeSettings.chartOffset = sideScanOffet
                        }
                        */

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
                        themeSelectorColor2D.selectedIndex = pulseSettings.colorMapIndex2D
                        console.log("TAV: colormap updated to index for 2D to:", pulseSettings.colorMapIndex2D);
                    }
                }
            }
        }

        RowLayout {
            id: quickChangeUserOptions
            spacing: 2
            Layout.topMargin: 10

            GridLayout.row: 3
            GridLayout.column: 0
            Layout.preferredWidth: _isAndroid ? 350 : 220


            HorizontalCheckController {
                id: showMyControls
                iconSource: "./icons/ui/pulse_controls.svg"
                checked: pulseSettings.areUiControlsVisible
                visible: !pulseRuntimeSettings.echogramPause

                onStateChanged: {
                    //console.log("Checkbox state changed:", checked)
                    pulseSettings.areUiControlsVisible = checked
                    if (!pulseSettings.areUiControlsVisible) {
                        pulseRuntimeSettings.echogramVisible = true
                    }
                }

            }

            HorizontalCheckController {
                id: showInfo
                iconSource: "./icons/ui/pulse_info.svg"
                checked: false
                visible: pulseSettings.areUiControlsVisible  && !pulseRuntimeSettings.echogramPause

                onStateChanged: {
                    //console.log("Checkbox state changed:", checked)
                    pulseInfoLoader.active = checked

                }

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
        anchors.bottomMargin: 40 + Math.max(insetBottom(), insetsIme())
        anchors.left: quickChangeObjects.right
        anchors.leftMargin: 40
        width: 360
        height: 43
        opacity: 60
        visible: pulseRuntimeSettings.devManualSelected
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

        MenuFrame {
            id: leftPanel
            isOpacityControlled: true
            Layout.alignment: Qt.AlignLeft
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

            MenuFrame {
                id: plotSettings

                ParamGroup {
                    groupName: qsTr("Plot")

                    RowLayout {
                        id: rowDataset
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
                            Layout.preferredWidth: rowDataset.width / 3
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
                            Layout.preferredWidth: rowDataset.width / 3
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
                            model: [qsTr("Blue"), qsTr("Sepia"), qsTr("WRGBD"), qsTr("WhiteBlack"), qsTr("BlackWhite")]
                            currentIndex: 0

                            onCurrentIndexChanged: plotEchogramTheme(currentIndex)
                            Component.onCompleted: plotEchogramTheme(currentIndex)

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

                            onCurrentIndexChanged: plotEchogramCompensation(currentIndex) // TODO
                            Component.onCompleted: plotEchogramCompensation(currentIndex) // TODO

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
                                    if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                                        echogramTypesList.currentIndex = 0
                                    } else {
                                        echogramTypesList.currentIndex = 1
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        visible: instruments > 0
                        CCheck {
                            id: bottomTrackVisible
                            Layout.fillWidth: true
                            text: qsTr("Bottom-Track")
                            onCheckedChanged: plotBottomTrackVisible(checked)
                            Component.onCompleted: plotBottomTrackVisible(checked)
                        }

                        CCombo  {
                            id: bottomTrackThemeList
                            //                        Layout.fillWidth: true
                            //                        Layout.preferredWidth: 150
                            model: [qsTr("Line1"), qsTr("Line2"), qsTr("Dot1"), qsTr("Dot2"), qsTr("DotLine")]
                            currentIndex: pulseRuntimeSettings !== null ? pulseRuntimeSettings.bottomTrackVisibleModel : 0

                            onCurrentIndexChanged: plotBottomTrackTheme(currentIndex)
                            Component.onCompleted: plotBottomTrackTheme(currentIndex)

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
                                bottomTrackVisible.checked = pulseRuntimeSettings.bottomTrackVisible
                                console.log("DistProcessing: set bottomTrackVisible", pulseRuntimeSettings.bottomTrackVisible)
                            }
                            function onBottomTrackVisibleChanged () {
                                if (pulseRuntimeSettings === null)
                                    return
                                if (pulseRuntimeSettings.userManualSetName === "...") {
                                    return
                                }
                                if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                                    bottomTrackVisible.checked = false
                                    return
                                }

                                console.log("DistProcessing: toggle bottomTrack visibility, show it?", pulseRuntimeSettings.bottomTrackVisible)
                                bottomTrackVisible.checked = pulseRuntimeSettings.bottomTrackVisible
                            }
                        }
                    }

                    RowLayout {
                        CCheck {
                            id: rangefinderVisible
                            Layout.fillWidth: true
                            text: qsTr("Rangefinder")
                            checked: pulseRuntimeSettings !== null ? pulseRuntimeSettings.rangefinderVisible : false
                            onCheckedChanged: plotRangefinderVisible(checked)
                            Component.onCompleted: plotRangefinderVisible(checked)
                        }

                        CCombo  {
                            id: rangefinderThemeList
                            model: [qsTr("Text"), qsTr("Line"), qsTr("Dot")]
                            currentIndex: pulseRuntimeSettings !== null ? pulseRuntimeSettings.rangefinderVisibleModel : 0

                            onCurrentIndexChanged: plotRangefinderTheme(currentIndex)
                            Component.onCompleted: plotRangefinderTheme(currentIndex)

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

                    Settings {
                        category: "Plot2D_" + plot.indx

                        property alias echogramVisible: echogramVisible.checked
                        property alias rangefinderVisible: rangefinderVisible.checked
                        property alias postProcVisible: bottomTrackVisible.checked
                        property alias ahrsVisible: ahrsVisible.checked
                        property alias gridVisible: gridVisible.checked
                        property alias dopplerBeamVisible: dopplerBeamVisible.checked
                        property alias dopplerInstrumentVisible: dopplerInstrumentVisible.checked
                        property alias horisontalVertical: horisontalVertical.checked
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
