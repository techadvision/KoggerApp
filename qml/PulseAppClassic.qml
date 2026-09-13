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

    //THE DEVICE SWAP PROMPT HAS MOVED (Stage 4, step 3). It is a mode of
    //PulseConnectionScreen.qml now, which is instantiated once in main.qml above both
    //Plot2D panes - so the `plot.indx === 1` gate this block carried, to stop a split
    //screen drawing two of them, is gone rather than moved: one surface above both panes
    //cannot draw twice. The state it read is unchanged and still lives in
    //PulseRuntimeSettings: deviceSwapPending, acceptDeviceSwap(), declineDeviceSwap().

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
    //
    //BACKLOG ITEM 8: it now also names the device the app is PRESENTING as, and appears
    //for a plain opened log as well as for a demo, whenever nothing is connected. With
    //nothing on the wire the log decides the whole interface, so the app is claiming to be
    //a device it is not connected to — at a stand somebody will ask, and this is the
    //answer. It says nothing extra while a transducer is connected, because then nothing
    //has been relaxed.
    Rectangle {
        id: demoModeBadge
        visible: pulseRuntimeSettings.isInDemoMode || pulseRuntimeSettings.isPresentingLog
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
            text: {
                var base = pulseRuntimeSettings.isInDemoMode ? qsTr("Demo") : qsTr("Log")
                if (!pulseRuntimeSettings.isPresentingLog)
                    return base
                return base + " · " + pulseRuntimeSettings.modelDisplayName(
                            pulseRuntimeSettings.presentedModel)
            }
            font.pixelSize: 32
            color: "white"
            anchors.centerIn: parent
        }
    }

    //THE CONFIGURATION OVERLAY HAS MOVED (Stage 4, step 6). It is
    //qml/PulseSetupOverlay.qml now, instantiated ONCE in main.qml above both Plot2D panes.
    //
    //PulseApp is instantiated inside Plot2D, so this block existed once per pane and a
    //split screen drew two of them - the same defect the swap prompt carried, without even
    //the `indx === 1` that hid it there. It also bound `60 + insetTop()` and
    //`_isAndroid ? 80 : 60`, both declared on quickChangeObjects - a SIBLING of this block,
    //not its root - so neither could ever resolve. The new component takes the insets as
    //properties, so that is gone by construction.

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
        //Is the PICTURE a 2D echogram? Not "is the committed device a 2D transducer" —
        //see the note further down. Everything this gates is display: the grid direction,
        //the plot orientation, and which colour palette is offered.
        property bool showAs2DTransducer: pulseRuntimeSettings ? pulseRuntimeSettings.displayIs2DTransducer
                                                               : false
        //Qt.callLater, NOT a direct call. This property is one binding in a chain that all
        //moves at once — activeProfile, committedProfileKey, uiProfile, uiViews — and QML
        //gives no order within it. Called directly, setUserInterface() ran while
        //showAs2DTransducer already said "blue" but uiViews was still the RED profile's
        //(empty) list, so viewModeForId(ecoViewId) could not answer "side" and the echogram
        //was drawn HORIZONTALLY for a side scan log. That is what made the first playback
        //of a mismatched log come out wrong while every later one was right: by then the
        //committed device had been cleared and the profile had already settled on blue.
        //Deferring to the end of the current event processing lets the whole chain settle
        //first, and Qt.callLater coalesces repeats, so the double call in the log goes too.
        onShowAs2DTransducerChanged: {
            console.log("DEV_UI: showAs2DTransducer ->", showAs2DTransducer,
                        "| active", pulseRuntimeSettings ? pulseRuntimeSettings.activeModel : "(none)",
                        "| committed", pulseRuntimeSettings ? pulseRuntimeSettings.userManualSetName : "(none)")
            Qt.callLater(quickChangeObjects.applyDisplayModel)
        }

        //Everything that has to be re-run imperatively when the picture changes device.
        //setUserInterface() carries the geometry; the theme is pushed by whichever colour
        //selector has just become the visible one.
        function applyDisplayModel() {
            if (!plot)
                return
            console.log("DEV_UI: applying display model, 2D?", showAs2DTransducer,
                        "| view", pulseRuntimeSettings.viewModeForId(pulseSettings.ecoViewId))
            setUserInterface()
        }
        property bool isDeviceDetected: false

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: insetBottom() + 20
        anchors.leftMargin: 20

        //Pulse functions
        //***************

        //BACKLOG ITEMS 7 AND 10 — this was a variable, and that is what made a device swap
        //and a mismatched replay come out half-right. isDevice2DTransducer() computed it
        //from userManualSetName (falling back to devName), matched NEITHER branch while
        //that name was "..." — silently keeping the previous device's answer — and was only
        //ever re-run by setUserInterface() and reArrangeQuickChangeObject(), which in turn
        //ran on devManualSelected going TRUE (which a swap clears and never re-raises) and
        //on any change of appConfigured, the first of which is its reset to false. A swap
        //therefore left the echogram orientation and the colour chooser on the old device.
        //
        //It is now a BINDING on the display model, so both follow a swap, a replayed log
        //and a demo by construction. The imperative side of it — setHorizontalNow(),
        //setGridHorizontal(), the range push — is driven by the onShowAs2DTransducerChanged
        //handler on the property above, which is the one thing a binding cannot do for us.

        function reArrangeQuickChangeObject () {
            if (!plot)
                return

            if (showAs2DTransducer) {
                plot2DGrid.setGridHorizontal(true)
            } else {
                //Ask the profile what the selected view IS, rather than assuming index 0 is
                //down scan and everything else is side scan. That assumption was only true
                //while the list had exactly two entries, and it is what would have broken
                //the moment 820 was added back.
                plot2DGrid.setGridHorizontal(
                    pulseRuntimeSettings.viewModeForId(pulseSettings.ecoViewId) !== "side")
            }

        }


        function setUserInterface () {
            //Guarded: showAs2DTransducer is a binding now, so this can be reached before
            //the plot exists. reArrangeQuickChangeObject() below guards for the same reason.
            if (!plot)
                return

            if (showAs2DTransducer) {
                //console.log("TAV: setUserInterface horizontal - pulseRed");
                plot.setHorizontalNow()
                pulseRuntimeSettings.isHorizontalGrid = true
                //plot2DGrid.setGridHorizontal(true)
                //plot.setGridHorizontalNow(true)
                plot.plotDistanceRange2d(pulseSettings.maxDepthValue * 1.0)
                //console.log("TAV: setUserInterface horizontal - pulseRed - done");
            } else {
                //Same rule as reArrangeQuickChangeObject: the view's own mode decides,
                //not its position in the list.
                if (pulseRuntimeSettings.viewModeForId(pulseSettings.ecoViewId) === "side") {
                    plot.setVerticalNow()
                    pulseRuntimeSettings.isHorizontalGrid = false
                    plot.plotDistanceRange(pulseSettings.maxDepthValuePulseBlue * 1.0)
                } else {
                    plot.setHorizontalNow()
                    pulseRuntimeSettings.isHorizontalGrid = true
                    plot.plotDistanceRange2d(pulseSettings.maxDepthValuePulseBlue * 1.0)
                }
            }

            reArrangeQuickChangeObject()
            plot.updatePlot()
        }

        function getFilterForDepth (depth) {
            //var autoFilter = pulseRuntimeSettings.autoFilterPulseRed;

            //The WIDE cone by id, not by position: "the first button" stops being the
            //wide one the moment a list gains an entry above it.
            if (pulseRuntimeSettings.resolveConeId(pulseSettings.ecoConeId) === "wide") {
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
                        if (pulseRuntimeSettings.resolveConeId(pulseSettings.ecoConeId) === "wide") {
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
            //THE PICTURE, NOT THE COMMITTED DEVICE. Every question this control asks — how
            //deep can it go, in what steps, may it be held down, and what value should it be
            //showing — is about the echogram on screen, so all of it reads
            //displayIs2DTransducer. A side scan steps in 5 m and a 2D in 1 m; switching from
            //one picture to the other has to switch the stepping with it, which it did not
            //when these branched on the committed device.
            minValue: {
                if (pulseRuntimeSettings.displayIs2DTransducer) {
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
                if (pulseRuntimeSettings.displayIs2DTransducer) {
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
                if (pulseRuntimeSettings.displayIs2DTransducer) {
                    return true
                } else {
                    if (pulseRuntimeSettings.isSideScan2DView) {
                        return true
                    } else {
                        return false
                    }
                }
            }
            //Each device keeps its own preferred max depth. Reading it through the display
            //model is what makes the stored value come back when the picture changes instead
            //of the previous device's number staying on screen.
            defaultValue: pulseRuntimeSettings.displayIs2DTransducer ? pulseSettings.maxDepthValue
                                                                     : pulseSettings.maxDepthValuePulseBlue
            //defaultValue: pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed ? pulseSettings.maxDepthValue : pulseSettings.maxDepthValuePulseBlue
            iconSource: "./icons/ui/pulse_ruler.svg"

            onSelectorValueChanged: {
                //console.log("EchogramWidth: max depth onSelectorValueChanged: ", value);
                plot.quickChangeMaxRangeValue = value;
                //Write back into the SAME slot defaultValue reads from, keyed the same way.
                //These two disagreeing is how a value lands in one device's preference and is
                //read out of the other's. presentedModel rather than userManualSetName for
                //the same reason: while a log is being presented, its device is the one whose
                //preference the user is adjusting.
                if (pulseRuntimeSettings.presentedModel === "..."
                        || pulseRuntimeSettings.presentedModel === "")
                    return
                if (pulseRuntimeSettings.displayIs2DTransducer) {
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
                if (!pulseRuntimeSettings.displayIs2DTransducer)
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
                    if (pulseRuntimeSettings.displayIs2DTransducer) {
                        //console.log("EchogramWidth: Component.onComplete autoRange for is2DTransducer")
                    //if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                        pulseRuntimeSettings.shouldDoAutoRange = true
                        plot.plotDistanceAutoRange(0);
                    }
                } else {
                    console.log("EchogramWidth: max depth Component.onComplete not autoRange")
                    pulseRuntimeSettings.shouldDoAutoRange = false
                    plot.plotDistanceAutoRange(-1);
                    if (pulseRuntimeSettings.displayIs2DTransducer) {
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
                    if (pulseRuntimeSettings.displayIs2DTransducer) {
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

                //A palette is not applied by being SHOWN. This control switching to the blue
                //list changed which swatches the user sees and nothing else, so a red-committed
                //app replaying a side scan drew the log with the RED theme still loaded in the
                //plot — the chooser said HQ while the picture was S-Dark. The 2D selector had a
                //recalcSelectedIndex() on becoming visible that did push its theme; this one had
                //no equivalent. Now it does, and both are driven the same way.
                function applyStoredTheme() {
                    if (!plot)
                        return
                    var master = pulseRuntimeSettings.themeModelBlue
                    if (!master || master.length === 0)
                        return
                    var idx = pulseSettings.colorMapIndexSideScan
                    var theme = (idx >= 0 && idx < master.length) ? master[idx] : master[0]
                    console.log("THEME: side scan palette ->", theme.id,
                                "(stored index", idx + ")")
                    pulseSettings.colorMapIndexReal = theme.id
                    plot.plotEchogramTheme(theme.id)
                    plot.updatePlot()
                    MosaicViewControlMenuController.onThemeChanged(theme.id)
                }

                onVisibleChanged: if (visible) applyStoredTheme()
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
                    //The DISPLAY model, not the committed one: this control stands aside
                    //whenever the picture is a side scan, including a side scan log played on
                    //a red-committed app. Asking userManualSetName let it push the red theme
                    //over a blue picture.
                    if (!quickChangeObjects.showAs2DTransducer)
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
                //The VIEW chooser. Everything about it now comes from the committed
                //profile's ui.views: whether it exists at all, what the buttons are, and
                //what each one does. The 820 option was removed by commenting out a second
                //model array and a second onIconSelected here; it comes back by adding two
                //entries to the profile.
                visible: pulseRuntimeSettings.offersViewChoice
                model: pulseRuntimeSettings.uiViewIcons
                iconSource: "./icons/ui/pulse_glasses.svg"
                //The preference is an ENTRY ID; this turns it into a position in the list
                //being shown right now. A stored id that is not currently offered (an
                //expert-only view with expert mode off) resolves to the same mode at another
                //frequency without the stored id being touched, so the expert's own choice
                //survives the round trip. Re-evaluates on expertMode, which is what lets the
                //list grow and shrink with no restart.
                selectedIndex: pulseRuntimeSettings.viewIndexForId(pulseSettings.ecoViewId)

                hostWindow: plot ? plot : undefined
                onIconSelected: {
                    //A real tap is the ONLY thing that writes the preference.
                    pulseSettings.ecoViewId = pulseRuntimeSettings.viewIdAt(selectedIndex)
                    applyView(selectedIndex)
                    plot.updatePlot()
                    quickChangeObjects.reArrangeQuickChangeObject()
                }

                //The one place a view index becomes an action. Adding a view to the profile
                //needs no change here, because the entry carries both what it is and what
                //frequency it runs at.
                function applyView (index) {
                    applyViewEntry(pulseRuntimeSettings.viewAt(pulseRuntimeSettings.clampViewIndex(index)))
                }

                //By stored id — what restoring a preference should use. Resolution happens
                //inside viewForId(), so an expert-only view that is hidden right now applies
                //the visible view of the same mode instead of transmitting at a frequency
                //the chooser is not showing.
                function applyViewId (id) {
                    applyViewEntry(pulseRuntimeSettings.viewForId(id))
                }

                function applyViewEntry (v) {
                    if (!v)
                        return
                    if (v.mode === "side")
                        setSideScan(v.freq)
                    else
                        setDownScan(v.freq)
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

                Timer {
                    id: setPulseBlueEcoViewOnAppStart
                    repeat: false
                    interval: 1000
                    onTriggered: themeSelector2.applyViewId(pulseSettings.ecoViewId)
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
                //The CONE chooser - the same control asking a different question. Same rule
                //as the view chooser: the profile decides whether it exists, what it shows
                //and what each button transmits at.
                visible: pulseRuntimeSettings.offersConeChoice
                model: pulseRuntimeSettings.uiConeIcons
                iconSource: "./icons/ui/pulse_glasses.svg"
                //Same as the view chooser: the preference is an id, this is its position
                //in the list being shown.
                selectedIndex: pulseRuntimeSettings.coneIndexForId(pulseSettings.ecoConeId)
                hostWindow: plot ? plot : undefined
                //allowExpertModeByMultiTap: false

                onIconSelected: {
                    applyCone(selectedIndex)
                    pulseSettings.ecoConeId = pulseRuntimeSettings.coneIdAt(selectedIndex)
                }

                //Applies a cone index without writing the preference back, so it is safe to
                //call when restoring the stored choice on a device change.
                function applyCone (index) {
                    applyConeEntry(pulseRuntimeSettings.coneAt(index))
                }

                //By stored id — what restoring a preference should use.
                function applyConeId (id) {
                    applyConeEntry(pulseRuntimeSettings.coneForId(id))
                }

                function applyConeEntry (c) {
                    if (!c)
                        return
                    pulseRuntimeSettings.transFreq = c.freq
                    console.log("TAV: Selected echosounder cone (frequency):", pulseRuntimeSettings.transFreq)
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onUserManualSetNameChanged () {
                        if (pulseRuntimeSettings.offersConeChoice) {
                            themeSelector3.applyConeId(pulseSettings.ecoConeId)
                            plot.updatePlot()
                            console.log("TAV: viewSelector offers cones, restored", pulseSettings.ecoConeId);
                        } else {
                            console.log("TAV: viewSelector device has no cone choice, nothing to restore");
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
