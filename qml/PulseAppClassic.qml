import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import QtCore
import Echo.UI 1.0
import QtQuick.Window

// The Pulse user interface as it ships today - the "classic" variant.
//
// Stage 1 lifted this out of Plot2D.qml unchanged. Stage 2 renamed the file and
// changed nothing else: PulseApp.qml is now a dispatcher that loads this, or a
// different variant, according to pulseSettings.uiVariant. This file stays alive
// and shipping until a new one has won on the water.
//
// Everything here used to live inside the WaterFall root, which is why it still
// talks to it as `plot`: that property is the same object it always was. Two
// other things it reached for stay behind in Plot2D and are passed in BY
// PulseApp.qml, which is the only thing that instantiates this:
//   plot   - the WaterFall root (plot.quickChangeMaxRangeValue, plot.updatePlot(), ...)
//   pinch  - the PinchArea, for its isLiveView flag
//
// Nothing else crosses the boundary. See the variant contract at the top of
// PulseApp.qml for what a variant has to provide.

Item {
    id: pulseAppClassic

    // Set by PulseApp.qml at construction. The default is a fallback only: inside
    // a Loader `parent` is the Loader, not the WaterFall, so nothing should ever
    // rely on it.
    property var plot:  parent
    property var pinch: null

    anchors.fill: parent

    // ---- API used by Plot2D -------------------------------------------------

    property alias maxDepthValue: selectorMaxDepth.value

    function applyFiltering(value) {
        quickChangeObjects.applyFiltering(value)
    }

    // Arms the "you are looking at old data" warning. Was five statements inline
    // in Plot2D's mousearea; the timers and the indicator all live here now.
    function armOldDataWarning() {
        countdownTimer.stop()
        oldDataIndicator._setCountdown(plot.oldDataResetSeconds)
        oldDataWarningRemovalTimer.interval = plot.oldDataResetSeconds * 1000
        oldDataWarningRemovalTimer.restart()
        countdownTimer.start()
    }

    // -------------------------------------------------------------------------

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
            if (nowLive !== pinch.isLiveView) {
                pinch.isLiveView = nowLive
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
        // keep single-shot timer; interval is derived from plot.oldDataResetSeconds
        interval: plot.oldDataResetSeconds * 1000
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
                    oldDataIndicator._setCountdown(plot.oldDataResetSeconds)
                    // ensure main timer matches the configured seconds
                    oldDataWarningRemovalTimer.interval = plot.oldDataResetSeconds * 1000
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
                    oldDataIndicator._setCountdown(plot.oldDataResetSeconds)
                    oldDataWarningRemovalTimer.interval = plot.oldDataResetSeconds * 1000
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
}
