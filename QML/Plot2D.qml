import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 1.2
import Qt.labs.settings 1.1

import WaterFall 1.0
import org.techadvision.settings 1.0
import org.techadvision.runtime 1.0

WaterFall {
    id: plot

    property int topMarginExpertMode: 0
    property real quickChangeMaxRangeValue: 15
    signal echogramWasZoomed(real updatedMaxValue)
    property bool isLiveView: true

    function setLevels(low, high) {
        echogramLevelsSlider.startValue = low
        echogramLevelsSlider.stopValue = high
        echogramLevelsSlider.startPointY = echogramLevelsSlider.valueToPosition(low);
        echogramLevelsSlider.stopPointY = echogramLevelsSlider.valueToPosition(high);
        echogramLevelsSlider.update()
    }

    Connections {
        target: plot
        onTimelinePositionChanged: {

            // compute the new boolean
            var nowLive = plot.timelinePosition >= 0.999

            // only update (and log) when it actually flips
            if (nowLive !== plot.isLiveView) {
                plot.isLiveView = nowLive
                console.log("TAV: horizontal live-view is now", plot.isLiveView,
                            "timeline position", plot.timelinePosition)
                if (!pulseRuntimeSettings.isOpeningKlfFile) {
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
        interval: 5000
        repeat: false
        onTriggered: {
            oldDataIndicator.visible = false
            plot.timelinePosition = 1
        }
    }

    Rectangle {
        id: oldDataIndicator
        // start hidden
        visible: false
        anchors.top: parent.top
        anchors.topMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 20

        // styling: semi-transparent black, rounded corners
        color: "#80000000"
        //opacity: 0.6
        radius: 8

        // padding around the text
        property int contentMargin: 12

        // size to fit the text + padding
        implicitWidth: oldDataText.width + contentMargin*2
        implicitHeight: oldDataText.height + contentMargin*2

        // the actual label
        Text {
            id: oldDataText
            text: "Old data"
            font.pixelSize: 40
            color: "white"
            anchors.centerIn: parent
        }
    }

    Rectangle {
        id: configurationInProgressIndicator
        // start hidden
        visible: !pulseRuntimeSettings.devConfigured
        anchors.top: parent.top
        anchors.topMargin: 20
        anchors.left: parent.left
        anchors.leftMargin: 20

        // styling: semi-transparent black, rounded corners
        color: "#80000000"
        //opacity: 0.6
        radius: 8

        // padding around the text
        property int contentMargin: 12

        // size to fit the text + padding
        implicitWidth: configurationInProgressText.width + contentMargin*2
        implicitHeight: configurationInProgressText.height + contentMargin*2

        // the actual label
        Text {
            id: configurationInProgressText
            text: "Verifying transducer..."
            font.pixelSize: 40
            color: "white"
            anchors.centerIn: parent
        }
    }

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
        property bool zoomX: false
        property point pinchStartPos: Qt.point(-1, -1)
        property double oldSpeed: pulseRuntimeSettings.echogramSpeed

        // true until the user scrolls/pinches *away* from the live edge:
        property bool isLiveView: true

        function clearPinchMovementState() {
            movementX = false
            movementY = false
            zoomY = false
            zoomX = false
            oldSpeed = pulseRuntimeSettings.echogramSpeed
        }

        onPinchStarted: {
            //console.log("TAV: onPinchStarted");
            menuBlock.visible = false

            mousearea.enabled = false
            plot.plotMousePosition(-1, -1)

            clearPinchMovementState()
            pinchStartPos = Qt.point(pinch.center.x, pinch.center.y)

            // get the two fingers’ starting positions
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
        }

        onPinchUpdated: {

            if (movementX) {
                plot.horScrollEvent(-(pinch.previousCenter.x - pinch.center.x))
                console.log("Someone scrolled me X ways")
            }

            else if (movementY) {
                plot.verScrollEvent(pinch.previousCenter.y - pinch.center.y)
                console.log("Someone scrolled me Y ways")
            }

            if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
                    ||pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlueProto)
                return

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
                    /*
                    if (dx > dy) {
                        zoomX = true
                    } else {
                        zoomY = true
                    }
                    */
                }
            }

            else if (zoomY) {
                //console.log("TAV: onPinchUpdated, view is horizontal: ", plot.isViewHorizontal());
                if (plot.isViewHorizontal()) {
                    plot.verZoomEvent((pinch.previousScale - pinch.scale)*100.0)
                } else {
                    //plot.verZoomEvent((pinch.previousScale - pinch.scale)*500.0)
                    plot.verZoomEvent((pinch.previousScale - pinch.scale)*50.0)
                }

                let newMaxDepthValue = plot.getMaxDepth()

                plot.quickChangeMaxRangeValue = newMaxDepthValue
                selectorMaxDepth.value = newMaxDepthValue
                //console.log("TAV: onPinchUpdated, new max is: ", plot.quickChangeMaxRangeValue);
                plot.echogramWasZoomed(plot.quickChangeMaxRangeValue)
            }

            else if  (zoomX) {
                if (pulseRuntimeSettings.userManualSetName !== pulseRuntimeSettings.modelPulseBlue
                        && pulseRuntimeSettings.userManualSetName !== pulseRuntimeSettings.modelPulseBlueProto) {
                    // 1) compute horizontal “ratio”
                    var hRatio = (pinch.scale - pinch.previousScale) * 50;
                    // 2) fraction of the 4-unit speed range
                    var deltaS = (hRatio * 0.01) * (5.0 - 1.0);
                    // 3) apply, clamp, round
                    var raw     = pulseRuntimeSettings.echogramSpeed + deltaS;
                    var clamped = Math.min(5.0, Math.max(1.0, raw));
                    var rounded = Math.round(clamped * 10) / 10;

                    // 4) only write (and thus emit) if it really changed
                    if (rounded !== pulseRuntimeSettings.echogramSpeed) {
                        pulseRuntimeSettings.echogramSpeed = rounded;
                        //console.log("TAV: zoomX → echogramSpeed changed to", rounded);
                    }
                }
            }
        }       

        onPinchFinished: {
            //console.log("TAV: onPinchFinished");
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
            property int lastMouseY: -1
            property bool wasMoved: false
            property point startMousePos: Qt.point(-1, -1)
            property real mouseThreshold: 15
            property int contactMouseX: -1
            property int contactMouseY: -1

            hoverEnabled: true

            Timer {
                id: longPressTimer
                interval: 500
                repeat: false
                onTriggered: {
                    if (Qt.platform.os === "android" && theme.instrumentsGrade !== 0 && !mousearea.wasMoved) {
                        //menuBlock.position(mousearea.mouseX, mousearea.mouseY)
                        plot.onCursorMoved(mousearea.mouseX, mousearea.mouseY)
                        mousearea.contactMouseX = mousearea.mouseX
                        mousearea.contactMouseY = mousearea.mouseY
                        plot.simplePlotMousePosition(mousearea.mouseX, mousearea.mouseY)

                        menuBlock.position(mousearea.mouseX, mousearea.mouseY)
                    }
                }
            }

            /*
            onClicked: {
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
            */

            onPressed: {
                //console.log("TAV: mouse - onPressed");
                lastMouseX = mouse.x
                lastMouseY = mouse.y

                if (Qt.platform.os === "android") {
                    startMousePos = Qt.point(mouse.x, mouse.y)
                    longPressTimer.start()
                }
                /*

                if (mouse.button === Qt.LeftButton) {
                    menuBlock.visible = false
                    plot.plotMousePosition(mouse.x, mouse.y)
                }
                */

                if (mouse.button === Qt.RightButton) {
                    contactMouseX = mouse.x
                    contactMouseY = mouse.y

                    plot.simplePlotMousePosition(mouse.x, mouse.y)
                }

                wasMoved = false
            }

            onReleased: {
                //console.log("TAV: mouse - onReleased");
                lastMouseX = -1
                lastMouseY = -1

                if (Qt.platform.os === "android") {
                    longPressTimer.stop()
                }

                /*

                if (mouse.button === Qt.LeftButton) {
                    plot.plotMousePosition(-1, -1)
                }
                */

                if (mouse.button === Qt.RightButton) {
                    contactMouseX = mouse.x
                    contactMouseY = mouse.y

                    plot.simplePlotMousePosition(mouse.x, mouse.y)
                }

                wasMoved = false
                startMousePos = Qt.point(-1, -1)
            }

            onCanceled: {
                //console.log("TAV: mouse - onCanceled");
                lastMouseX = -1
                lastMouseY = -1

                if (Qt.platform.os === "android") {
                    longPressTimer.stop()
                }

                wasMoved = false
                startMousePos = Qt.point(-1, -1)
            }

            onPositionChanged: {
                //console.log("TAV: mouse - onPositionChanged");
                plot.onCursorMoved(mouse.x, mouse.y)

                if (Qt.platform.os === "android") {
                    if (!wasMoved) {
                        var currDelta = Math.sqrt(Math.pow((mouse.x - startMousePos.x), 2) + Math.pow((mouse.y - startMousePos.y), 2));
                        if (currDelta > mouseThreshold) {
                            wasMoved = true;
                        }
                    }
                }

                //console.log("TAV: mouse - onPositionChanged wasMoved?", wasMoved);

                var delta = mouse.x - lastMouseX
                lastMouseX = mouse.x
                var deltaY = mouse.y - lastMouseY
                lastMouseY = mouse.y

                if (mousearea.pressedButtons & Qt.LeftButton) {
                    /*
                    plot.plotMousePosition(mouse.x, mouse.y)
                    */

                    //if (theme.instrumentsGrade === 0) {
                    if (true) {
                        if (plot.isViewHorizontal()) {
                            plot.horScrollEvent(delta)
                            if (oldDataIndicator.visible) {
                                oldDataWarningRemovalTimer.restart()
                            }
                        } else {
                            plot.horScrollEvent(deltaY)
                            if (oldDataIndicator.visible) {
                                oldDataWarningRemovalTimer.restart()
                            }
                        }
                        //plot.horScrollEvent(delta)
                    }

                }

                if (mouse.button === Qt.RightButton) {
                    contactMouseX = mouse.x
                    contactMouseY = mouse.y

                    plot.simplePlotMousePosition(mouse.x, mouse.y)
                }
            }

            /*
            onWheel: {
                if (wheel.modifiers & Qt.ControlModifier) {
                    plot.verZoomEvent(-wheel.angleDelta.y)
                }
                else if (wheel.modifiers & Qt.ShiftModifier) {
                    plot.verScrollEvent(-wheel.angleDelta.y)
                }
                else {
                    plot.horScrollEvent(wheel.angleDelta.y)
                }
            }
            */

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

    Rectangle {
        id: pulseInfoViewer
    }


    GridLayout  {

        id: quickChangeObjects
        width: 710
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
        anchors.bottomMargin: 20
        //anchors.leftMargin: 20
        //anchors.bottomMargin: 20

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
                plot.setGridHorizontalNow(true)
            } else {
                if (PulseSettings.ecoViewIndex === 0) {
                    plot.setGridHorizontalNow(true)
                } else {
                    plot.setGridHorizontalNow(false)
                }
            }

        }

        function pulsePlotPresets () {

            // DATASET CHANNELS
            //plot.plotDatasetChannel(32768, 32767) //dataset true, plot first, none: None=32767,First = 32768
            //core.setSideScanChannels(32768, 32767)//dataset true, plot first, none: None=32767,First = 32768
            // None = 32768, First = 32767, 1 = 1, 0 = 0

            // ECHOGRAM - Comment out what we want the user to be able to do
            plot.plotEchogramVisible(true)      // We always want this
            //plot.plotEchogramTheme(0)         // colors 0-3 = [qsTr("Blue"), qsTr("Sepia"), qsTr("WRGBD"), qsTr("WhiteBlack")]
            //plot.plotEchogramCompensation(0)  // model: [qsTr("Raw"), qsTr("Side-Scan")], 0 and 1

            // BOTTOM BOTTOM TRACK - Unsure of the usage
            plot.plotBottomTrackVisible(false)
            //plot.plotBottomTrackTheme(1)       // model: [qsTr("Line1"), qsTr("Line2"), qsTr("Dot1"), qsTr("Dot2"), qsTr("DotLine")] values 0-3

            // RANGE FINDER - Will paint a bottom tracking line, text or dot
            plot.plotRangefinderVisible(true)
            plot.plotRangefinderTheme(0)         // model: [qsTr("Text"), qsTr("Line"), qsTr("Dot")], values 0-2

            // ATTITUDE - Think this we do not want to use
            plot.plotAttitudeVisible(false)

            // DOPPLER
            /*
            TODO: Doppler Beams: false
            */
            /*
            TODO: Doppler Instrument: false
            */
            /*
            TODO: Doppler Profiler: false
            */

            // GNSS
            plot.plotGNSSVisible(false, 1)

            // GRID
            plot.plotGridVerticalNumber(5)
            plot.plotGridFillWidth(false)

            // ANGLE RANGE
            plot.plotAngleVisibility(false)

            // VELOCITY
            plot.plotVelocityVisible(false)
            //plot.plotVelocityRange(0.5)

            // DISTANCE AUTO RANGE
            plot.plotDistanceAutoRange(0)     // model: [qsTr("Last data"), qsTr("Last on screen"), qsTr("Max on screen")] are values 0-2

            // HORIZONTAL OR VERTICAAL - We do not want to fix this, should be automatically set to vertical for side scan and hprizontal for 2D
            /*
            //TODO: Horizontal: false (note: should be true when side scan)
            Unclear how this is implemented!!!
            */

            //console.log("TAV pulsePlotPresets ran");

        }

        function pulseBottomTrackingProcessingPresets () {

        }

        function setUserInterface () {
            //console.log("TAV function setUserInterface, pulseRuntimeSettings.devName =", pulseRuntimeSettings.devName);

            isDevice2DTransducer()

            if (showAs2DTransducer) {
                //console.log("TAV: setUserInterface horizontal - pulseRed");
                plot.setHorizontalNow()
                plot.setGridHorizontalNow(true)
                plot.plotDistanceRange2d(PulseSettings.maxDepthValue * 1.0)
                //console.log("TAV: setUserInterface horizontal - pulseRed - done");
            } else {
                if (PulseSettings.ecoViewIndex === 1) {
                    //console.log("TAV: setUserInterface vertical - pulseBlue viewIndex 1");
                    plot.setVerticalNow()
                    plot.setGridHorizontalNow(false)
                    plot.plotDistanceRange(PulseSettings.maxDepthValue * 1.0)
                    //console.log("TAV: setUserInterface vertical - pulseBlue viewIndex 1 - done");
                } else {
                    //console.log("TAV: setUserInterface horizontal - pulseBlue viewIndex 0");
                    plot.setHorizontalNow()
                    plot.setGridHorizontalNow(true)
                    plot.plotDistanceRange2d(PulseSettings.maxDepthValue * 1.0)
                    //console.log("TAV: setUserInterface horizontal - pulseBlue viewIndex 0 - done");
                }
            }
            /*
            if (showAs2DTransducer) {
            //if (!pulseRuntimeSettings.is2DTransducer) {
                plot.plotEchogramTheme(PulseSettings.colorMapIndex2D + quickChangeTheme.themeOffset)
            } else {
                plot.plotEchogramTheme(PulseSettings.colorMapIndexSideScan + quickChangeTheme.themeOffset)
            }
            */

            reArrangeQuickChangeObject()
            plot.updatePlot()
        }

        function getFilterForDepth (depth) {
            //var autoFilter = pulseRuntimeSettings.autoFilterPulseRed;

            if (PulseSettings.ecoConeIndex === 0) {
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

            /*
            for (var i = 0; i < autoFilter.length; i++) {
                if (depth >= autoFilter[i].min && depth < autoFilter[i].max) {
                    return autoFilter[i].filter;
                }
            }
            */
            return 0;
        }

        function doAutoFilter() {
            if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
                    || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlueProto) {
                //console.log("TAV: auto filter not be set for pulseBlue")
                return
            }

            if (PulseSettings.autoFilter) {
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
            target: PulseSettings
            function onEcoConeIndexChanged () {
                if (PulseSettings.autoFilter) {
                    doAutoFilter()
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
            target: pulseRuntimeSettings
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
                        if (PulseSettings.ecoConeIndex === 0) {
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

            function onExpertModeChanged() {
                //console.log("TAV: onExpertModeChanged detected");
                if (pulseRuntimeSettings.expertMode) {
                    //console.log("TAV: onExpertModeChanged true, change the UI");
                    plot.topMarginExpertMode = 100;
                    quickChangeObjects.setUserInterface();
                } else {
                    plot.topMarginExpertMode = 0;
                    quickChangeObjects.setUserInterface();
                    //console.log("TAV: onExpertModeChanged false, skip");
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


        DepthAndTemperature {
            id: thisDepthAndTemperature
            GridLayout.row: 0
            GridLayout.column: 0
            Layout.rowSpan: 2
            Layout.preferredWidth: 370
            Layout.preferredHeight: 200
            //visible: true
            //opacity: (quickChangeObjects.isDeviceDetected) ? 1 : 0
            opacity: (quickChangeObjects.isDeviceDetected) ? 1 : 1
            enabled: (quickChangeObjects.isDeviceDetected)
        }


        HorizontalController {
            id: selectorMaxDepth
            visible: PulseSettings.areUiControlsVisible

            GridLayout.row: 1
            GridLayout.column: 1
            Layout.preferredWidth: 310
            controleName: "selectorMaxDepth"
            minValue: 1
            maxValue: pulseRuntimeSettings.maximumDepth
            step: 1
            defaultValue: PulseSettings.maxDepthValue
            iconSource: "./icons/pulse_ruler.svg"

            onSelectorValueChanged: {
                plot.quickChangeMaxRangeValue = value;
                PulseSettings.maxDepthValue = value;
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
                plot.plotDistanceAutoRange(0)
                PulseSettings.autoRange = true
                pulseRuntimeSettings.shouldDoAutoRange = true
                plot.updatePlot()
                //console.log("TAV: Auto range requested");
            }

            onDistanceFixedRangeRequested: {
                plot.plotDistanceAutoRange(-1)
                PulseSettings.autoRange = false;
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
                if (PulseSettings.autoRange) {
                    pulseRuntimeSettings.shouldDoAutoRange = true
                    plot.plotDistanceAutoRange(0);
                } else {
                    pulseRuntimeSettings.shouldDoAutoRange = false
                    plot.plotDistanceAutoRange(-1);
                    plot.plotDistanceRange(PulseSettings.maxDepthValue * 1.0)
                    pulseRuntimeSettings.manualSetLevel = PulseSettings.maxDepthValue * 1.0
                }
                plot.updatePlot();
            }

        }


        HorizontalController {
            id: selectorIntensity
            visible: PulseSettings.areUiControlsVisible
            GridLayout.row: 2
            GridLayout.column: 1
            Layout.preferredWidth: 310
            controleName: "selectorIntensity"
            minValue: 0
            maxValue: 20
            step: 1
            defaultValue: PulseSettings.intensityDisplayValue
            //defaultValue: Math.round((120 - echogramLevelsSlider.stopValue) / 3)
            iconSource: "./icons/pulse_sun.svg"

            onSelectorValueChanged: {
                let actualValue = Math.round(120 - (value * 4));
                PulseSettings.intensityRealValue = actualValue;
                PulseSettings.intensityDisplayValue = value;
                quickChangeObjects.quickChangeStopValue = actualValue;
                plot.setIntensityValue(actualValue * 1.0)
                //console.log("TAV: selectorIntensity changed intensity (presented):", value, " (actual):", actualValue);
            }

            Component.onCompleted: {
                plot.setIntensityValue(PulseSettings.intensityRealValue * 1.0)
                plot.updatePlot()
            }
        }

        HorizontalController {
            id: selectorFiltering
            visible: PulseSettings.areUiControlsVisible
            controleName: "selectorFiltering"
            GridLayout.row: 3
            GridLayout.column: 1
            Layout.preferredWidth: 310
            minValue: 0
            maxValue: 20
            step: 1
            defaultValue: PulseSettings.filterDisplayValue
            //defaultValue: Math.round(echogramLevelsSlider.startValue / 2.5)
            iconSource: "./icons/pulse_filter.svg"
            onSelectorValueChanged: {
                let actualValue = Math.round(value * 2.5);
                PulseSettings.filterRealValue = actualValue
                PulseSettings.filterDisplayValue = value
                quickChangeObjects.quickChangeStartValue = actualValue;
                plot.setFilteringValue(actualValue)
                //console.log("TAV: selectorFiltering changed filter (presented):", value, " (actual):", actualValue);
            }

            Component.onCompleted: {
                plot.setFilteringValue(PulseSettings.filterRealValue)
                if (PulseSettings.autoFilter) {
                    quickChangeObjects.doAutoFilter()
                }
            }

            onFilterAutoRangeRequested: {
                //console.log("TAV: Auto filter requested");
                PulseSettings.autoFilter = true
                quickChangeObjects.doAutoFilter()
            }

            onFilterFixedRangeRequested: {
                //console.log("TAV: Fixed filter requested");
                PulseSettings.autoFilter = false;
                let preferredValue = PulseSettings.filterRealValue
                plot.setFilteringValue(preferredValue)

                plot.updatePlot()
            }

        }


        RowLayout {
            id: quickChangeTheme
            spacing: 2
            Layout.topMargin: 10
            visible: PulseSettings.areUiControlsVisible

            GridLayout.row: 2
            GridLayout.column: 0
            Layout.preferredWidth: 350


            HorizontalTapSelectController {
                id: themeSelectorColorSS
                visible: !quickChangeObjects.showAs2DTransducer
                model: pulseRuntimeSettings.themeModelBlue.map(function(item) {return item.icon;})
                iconSource: "./icons/pulse_paint.svg"
                selectedIndex: PulseSettings.colorMapIndexSideScan
                allowExpertModeByMultiTap: true
                onIconSelected: {
                    //console.log("TAV: colormap for:", pulseRuntimeSettings.userManualSetName);
                    PulseSettings.colorMapIndexSideScan = selectedIndex;
                    var selectedTheme = pulseRuntimeSettings.themeModelBlue[selectedIndex]
                    //console.log("TAV: colormap selectedIndex", selectedIndex, "matches selectedTheme.id", selectedTheme.id);
                    PulseSettings.colorMapIndexReal = selectedTheme.id
                    plot.plotEchogramTheme(selectedTheme.id);
                    plot.updatePlot();
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onUserManualSetNameChanged () {
                        //console.log("TAV: colormap for:", pulseRuntimeSettings.userManualSetName);
                        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
                                || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlueProto) {
                            var preferredIndex = PulseSettings.colorMapIndexSideScan
                            var selectedTheme = pulseRuntimeSettings.themeModelBlue[preferredIndex]
                            //console.log("TAV: colormap preferredIndex", preferredIndex, "matches preferredTheme.id", selectedTheme.id);
                            plot.plotEchogramTheme(selectedTheme.id)
                            PulseSettings.colorMapIndexReal = selectedTheme.id
                            plot.updatePlot();
                        } else {
                            //console.log("TAV: colormap is 2D transducer, do not set for side scan");
                       }
                    }
                }
            }

            HorizontalTapSelectController {
                id: themeSelectorColor2D
                visible: quickChangeObjects.showAs2DTransducer
                model: pulseRuntimeSettings.themeModelRed.map(function(item) {return item.icon;})
                iconSource: "./icons/pulse_paint.svg"
                selectedIndex: PulseSettings.colorMapIndex2D
                allowExpertModeByMultiTap: true
                onIconSelected: {
                    //console.log("TAV: colormap for:", pulseRuntimeSettings.userManualSetName);
                    PulseSettings.colorMapIndex2D = selectedIndex;
                    var selectedTheme = pulseRuntimeSettings.themeModelRed[selectedIndex]
                    //console.log("TAV: colormap selectedIndex", selectedIndex, "matches selectedTheme.id", selectedTheme.id);
                    plot.plotEchogramTheme(selectedTheme.id);
                    PulseSettings.colorMapIndexReal = selectedTheme.id
                    plot.updatePlot();
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onUserManualSetNameChanged () {
                        //console.log("TAV: colormap for:", pulseRuntimeSettings.userManualSetName);
                        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed
                                || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto) {
                            var preferredIndex = PulseSettings.colorMapIndex2D
                            var selectedTheme = pulseRuntimeSettings.themeModelRed[preferredIndex]
                            //console.log("TAV: colormap preferredIndex", preferredIndex, "matches preferredTheme.id", selectedTheme.id);
                            plot.plotEchogramTheme(selectedTheme.id)
                            PulseSettings.colorMapIndexReal = selectedTheme.id
                            plot.updatePlot();
                        } else {
                             //console.log("TAV: colormap is side scan, do not set for 2D");
                        }
                    }
                }
            }

            HorizontalTapSelectController {
                id: themeSelector2
                visible: !pulseRuntimeSettings.is2DTransducer
                model: [
                    "./icons/pulse_view_downscan.svg",
                    "./icons/pulse_view_sidescan.svg"
                ]
                iconSource: "./icons/pulse_glasses.svg"
                selectedIndex: PulseSettings.ecoViewIndex
                allowExpertModeByMultiTap: false
                onIconSelected: {
                    plot.plotEchogramCompensation(selectedIndex);
                    PulseSettings.ecoViewIndex = selectedIndex
                    if (selectedIndex === 0) {
                        pulseRuntimeSettings.isSideScan2DView = true
                        plot.setHorizontalNow()
                        plot.plotDistanceRange2d(plot.quickChangeMaxRangeValue * 1.0)
                    } else {
                        pulseRuntimeSettings.isSideScan2DView = false
                        plot.setVerticalNow()
                        plot.plotDistanceRange(plot.quickChangeMaxRangeValue * 1.0)
                    }
                    quickChangeObjects.reArrangeQuickChangeObject()

                }
                Connections {
                    target: pulseRuntimeSettings
                    function onUserManualSetNameChanged () {
                        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
                                || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlueProto) {
                            if (PulseSettings.ecoViewIndex === 0) {
                                plot.setHorizontalNow()
                                plot.plotDistanceRange2d(plot.quickChangeMaxRangeValue * 1.0)
                                pulseRuntimeSettings.isSideScan2DView = true
                            } else {
                                plot.setVerticalNow()
                                plot.plotDistanceRange(plot.quickChangeMaxRangeValue * 1.0)
                                pulseRuntimeSettings.isSideScan2DView = false
                            }
                            //console.log("TAV: viewSelector is side scan");
                            plot.updatePlot();
                        } else {
                            //console.log("TAV: viewSelector is 2D transducer, do not set for side scan");
                       }
                    }
                }

                Connections {
                    target: PulseSettings
                    function onColorMapIndexSideScanChanged () {
                        themeSelectorColor2D.selectedIndex = PulseSettings.colorMapIndexSideScan
                        //console.log("TAV: colormap updated to index:", PulseSettings.colorMapIndexSideScan);
                    }
                }

            }

            HorizontalTapSelectController {
                id: themeSelector3
                visible: pulseRuntimeSettings.is2DTransducer

                model: [
                    "./icons/pulse_cone_wide.svg",
                    "./icons/pulse_cone_narrow_ultra.svg"
                ]
                /*
                model: [
                    "./icons/pulse_cone_narrow_ultra.svg"
                ]
                */
                iconSource: "./icons/pulse_glasses.svg"
                //selectedIndex: 0
                selectedIndex: PulseSettings.ecoConeIndex
                allowExpertModeByMultiTap: false

                onIconSelected: {
                    if (selectedIndex === 1) {
                        //DeviceItem.transFreq = themeSelector3.coneNarrow
                        pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqNarrow
                        //console.log("TAV: Selected echosounder cone (frequency):", pulseRuntimeSettings.transFreq);
                    } else {
                        pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqWide
                        //DeviceItem.transFreq = themeSelector3.coneWide
                        //console.log("TAV: Selected echosounder cone (frequency):", pulseRuntimeSettings.transFreq);
                    }
                    PulseSettings.ecoConeIndex = selectedIndex

                    //console.log("TAV: Selected echosounder cone index:", themeSelector3.selectedIndex);
                }

                Connections {
                    target: pulseRuntimeSettings
                    function onUserManualSetNameChanged () {
                        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed
                                || pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRedProto) {
                            pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqNarrow
                            //console.log("TAV: viewSelector is 2D");
                            plot.updatePlot()
                        } else {
                            //console.log("TAV: viewSelector is side scan transducer, do not set for 2D");
                       }
                    }
                }

                Connections {
                    target: PulseSettings
                    function onColorMapIndex2DChanged () {
                        themeSelectorColor2D.selectedIndex = PulseSettings.colorMapIndex2D
                        //console.log("TAV: colormap updated to index:", PulseSettings.colorMapIndex2D);
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
            Layout.preferredWidth: 350


            HorizontalCheckController {
                id: showMyControls
                iconSource: "./icons/pulse_controls.svg"
                checked: PulseSettings.areUiControlsVisible  // Bind this to your persistent setting

                onStateChanged: {
                    //console.log("Checkbox state changed:", checked)
                    PulseSettings.areUiControlsVisible = checked
                    if (PulseSettings.areUiControlsVisible) {
                        plot.plotGridVerticalNumber(5)
                    } else {
                        plot.plotGridVerticalNumber(0)
                    }

                    // Update persistent settings or trigger other UI actions here
                }

            }

            HorizontalCheckController {
                id: showInfo
                iconSource: "./icons/pulse_info.svg"
                checked: false
                visible: PulseSettings.areUiControlsVisible

                onStateChanged: {
                    //console.log("Checkbox state changed:", checked)
                    pulseInfoLoader.active = checked

                }

                onVisibleChanged: {
                    if (!visible) {
                        pulseInfoLoader.active = false;
                        checked = false;
                    }
                }

            }


        }

    }


    Loader {
        id: pulseInfoLoader
        source: "qrc:/PulseTabbedSettings.qml"
        //source: "PulseInfo.qml"
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
        anchors.bottomMargin: 40
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
            source: "./icons/pulse_recording_active.svg"
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
            target: pulseRuntimeSettings
            function onIsRecordingKlfChanged () {
                recordingOnScreen.visible = pulseRuntimeSettings.isRecordingKlf
            }
        }

    }

    /*
    Button {
        id: recordingOnScreen
        checkable: true
        visible: pulseRuntimeSettings.isRecordingKlf

        // Force the size.
        width: 60
        height: 60
        implicitWidth: 60
        implicitHeight: 60

        anchors.bottom: companyWaterMark.top
        anchors.left: companyWaterMark.left
        anchors.right: companyWaterMark.right
        // If your style uses padding, setting it to 0 helps.
        padding: 0

        // Override the background to avoid the default styling interfering.
        background: Rectangle {
             anchors.fill: parent
             color: "transparent"
        }

        // Use contentItem to show your icon.
        contentItem: Image {
             // Prevent this Image from intercepting mouse events.
             enabled: false
             source: recordingOnScreen.checked ? "./icons/pulse_recording_active.svg" : "./icons/pulse_recording_inactive.svg"
             anchors.fill: parent
             fillMode: Image.PreserveAspectCrop
        }

        onCheckedChanged: {
             console.log("TAV: Recording? ", recordingOnScreen.checked)
             pulseRuntimeSettings.isRecordingKlf = recordingOnScreen.checked
             core.loggingKlf = recordingOnScreen.checked
        }

        Connections {
            target: pulseRuntimeSettings
            function onIsRecordingKlfChanged () {
                recordingOnScreen.checked = pulseRuntimeSettings.isRecordingKlf
            }
        }
    }
    */

    Timer {
        id: closePulseSettingsTimer
        interval: 15000   // 30 seconds in milliseconds
        repeat: false
        onTriggered: {
            pulseSettingsLoader.active = false;
        }
    }


    /*
    Timer {
        id: closePulseInfoTimer
        interval: 6000   // 6 seconds in milliseconds
        repeat: false
        onTriggered: {
            pulseInfoLoader.active = false;
            showInfo.checked = false
        }
    }
    */


    MenuFrame {
        Layout.alignment: Qt.AlignHCenter
        //This is the standard solution with upper slider defining intensity and lower defining filter. We replace this with other controls
        visible: false
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 4
        margins: 0

        //isDraggable: true
        isOpacityControlled: true

        ColumnLayout {

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

                /*
                onStartValueChanged: {
                    plot.plotEchogramSetLevels(startValue, stopValue);
                }

                onStopValueChanged: {
                    plot.plotEchogramSetLevels(startValue, stopValue);
                }

                Component.onCompleted: {
                    plot.plotEchogramSetLevels(startValue, stopValue);
                }
                */

                Settings {
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

    CContact {
        id: contactDialog
        visible: false

        onVisibleChanged: {
            if (!visible) {
                parent.focus = true

                if (accepted) {
                    plot.setContact(contactDialog.indx, contactDialog.inputFieldText)
                    accepted = false
                }
                contactDialog.info = ""
                contactDialog.inputFieldText = ""
            }
        }

        onDeleteButtonClicked: {
            plot.deleteContact(contactDialog.indx)
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

        ButtonGroup {
            id: pencilbuttonGroup
        }

        CheckButton {
            icon.source: "./icons/direction-arrows.svg"
            visible: false
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
            icon.source: "./icons/arrow-bar-to-down.svg"
            backColor: theme.controlBackColor
            implicitWidth: theme.controlHeight
            visible: false

            onCheckedChanged: {
                if (checked) {
                    plot.plotMouseTool(2)
                }
            }

            ButtonGroup.group: pencilbuttonGroup
        }

        CheckButton {
            icon.source: "./icons/pencil.svg"
            backColor: theme.controlBackColor
            implicitWidth: theme.controlHeight
            visible: false

            onCheckedChanged: {
                if (checked) {
                    plot.plotMouseTool(3)
                }
            }

            ButtonGroup.group: pencilbuttonGroup
        }

        CheckButton {
            icon.source: "./icons/arrow-bar-to-up.svg"
            backColor: theme.controlBackColor
            implicitWidth: theme.controlHeight
            visible: false

            onCheckedChanged: {
                if (checked) {
                    plot.plotMouseTool(4)
                }
            }

            ButtonGroup.group: pencilbuttonGroup
        }

        CheckButton {
            icon.source: "./icons/eraser.svg"
            backColor: theme.controlBackColor
            implicitWidth: theme.controlHeight
            visible: false

            onCheckedChanged: {
                if (checked) {
                    plot.plotMouseTool(5)
                }
            }

            ButtonGroup.group: pencilbuttonGroup
        }

        CheckButton {
            icon.source: "./icons/anchor.svg"
            backColor: theme.controlBackColor
            implicitWidth: theme.controlHeight
            visible: false
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
            icon.source: "./icons/x.svg"
            backColor: theme.controlBackColor
            checkable: false
            implicitWidth: theme.controlHeight
            visible: false

            onClicked: {
                menuBlock.visible = false
            }

            ButtonGroup.group: pencilbuttonGroup
        }
    }
}
//}
