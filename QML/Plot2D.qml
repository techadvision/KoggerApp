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



        function clearPinchMovementState() {
            movementX = false
            movementY = false
            zoomY = false
        }

        /*
        Timer {
            id: zoomToDistanceUpdater
            interval: 200
            repeat: false
            onTriggered: {
                console.log("TAV: zoomToDistanceUpdater, new max is: ", plot.getMaxDepth());
            }
        }
        */


        onPinchStarted: {
            console.log("TAV: onPinchStarted");
            menuBlock.visible = false

            mousearea.enabled = false
            plot.plotMousePosition(-1, -1)

            clearPinchMovementState()
            pinchStartPos = Qt.point(pinch.center.x, pinch.center.y)
        }

        onPinchUpdated: {

            if (movementX) {
                plot.horScrollEvent(-(pinch.previousCenter.x - pinch.center.x))
            }
            else if (movementY) {
                plot.verScrollEvent(pinch.previousCenter.y - pinch.center.y)
            }
            else if (zoomY) {
                console.log("TAV: onPinchUpdated, view is horizontal: ", plot.isViewHorizontal());
                if (plot.isViewHorizontal()) {
                    plot.verZoomEvent((pinch.previousScale - pinch.scale)*100.0)
                } else {
                    plot.verZoomEvent((pinch.previousScale - pinch.scale)*500.0)
                }

                //plot.verZoomEvent((pinch.previousScale - pinch.scale)*500.0)
                let newMaxDepthValue = plot.getMaxDepth()
                if (newMaxDepthValue !== plot.quickChangeMaxRangeValue) {
                    plot.quickChangeMaxRangeValue = newMaxDepthValue
                    selectorMaxDepth.value = newMaxDepthValue
                    console.log("TAV: onPinchUpdated, new max is: ", plot.quickChangeMaxRangeValue);
                    plot.echogramWasZoomed(plot.quickChangeMaxRangeValue)
                }
            }
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
        }       

        onPinchFinished: {
            console.log("TAV: onPinchFinished");
            mousearea.enabled = true
            plot.plotMousePosition(-1, -1)

            clearPinchMovementState()
            pinchStartPos = Qt.point(-1, -1)
            //zoomToDistanceUpdater.stop
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
                console.log("TAV: mouse - onPressed");
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
                console.log("TAV: mouse - onReleased");
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
                console.log("TAV: mouse - onCanceled");
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
                            //console.log("TAV: mouse - horScrollEvent", delta);
                        } else {
                            plot.horScrollEvent(deltaY)
                            //console.log("TAV: mouse - verScrollEvent", deltaY);
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
        anchors.top: parent.bottom
        anchors.topMargin: 50
        //anchors.leftMargin: 20
        anchors.bottomMargin: 20

        function isDevice2DTransducer () {
            console.log("TAV isDevice2DTransducer userManualSetName ===", pulseRuntimeSettings.userManualSetName)
            if (pulseRuntimeSettings.userManualSetName !== "...") {
                //Manually selected model
                console.log("TAV isDevice2DTransducer determined by manual selection");
                if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                    console.log("TAV isDevice2DTransducer selected modelPulseRed");
                    showAs2DTransducer = true
                }
                if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue) {
                    console.log("TAV isDevice2DTransducer selected modelPulseBlue");
                    showAs2DTransducer = false
                }
            } else {
                //Detected model
                console.log("TAV isDevice2DTransducer determined by automatic detection");
                if (pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseRed) {
                    console.log("TAV isDevice2DTransducer found modelPulseRed");
                    showAs2DTransducer = true
                }
                if (pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseBlue) {
                    console.log("TAV isDevice2DTransducer found modelPulseBlue");
                    showAs2DTransducer = false
                }
            }
            console.log("TAV isDevice2DTransducer determined to be", showAs2DTransducer);
        }

        function reArrangeQuickChangeObject () {
            /*
            quickChangeObjects.anchors.left = parent.left
            quickChangeObjects.anchors.leftMargin = 20
            quickChangeObjects.anchors.bottom = parent.bottom
            quickChangeObjects.anchors.bottomMargin = 20
            */


            console.log("TAV reArrangeQuickChangeObject ran, and isViewHorizontal is :", plot.isViewHorizontal());
            quickChangeObjects.anchors.left = undefined;
            quickChangeObjects.anchors.right = undefined;
            quickChangeObjects.anchors.top = undefined;
            quickChangeObjects.anchors.bottom = undefined;
            quickChangeObjects.anchors.topMargin = undefined;
            quickChangeObjects.anchors.leftMargin = undefined;
            quickChangeObjects.anchors.bottomMargin = undefined;

            quickChangeObjects.anchors.left = parent.left
            quickChangeObjects.anchors.leftMargin = 20
            quickChangeObjects.anchors.bottom = parent.bottom
            quickChangeObjects.anchors.bottomMargin = 20

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

            //Set interface
            /*
            if (showAs2DTransducer) {
                // Horizontal
                quickChangeObjects.anchors.left = parent.left
                quickChangeObjects.anchors.top = parent.top
                quickChangeObjects.anchors.topMargin = 50 + plot.topMarginExpertMode
                quickChangeObjects.anchors.leftMargin = 20
                plot.setGridHorizontalNow(true)
            } else {
                if (PulseSettings.ecoViewIndex === 0) {
                    // Horizontal
                    quickChangeObjects.anchors.left = parent.left
                    quickChangeObjects.anchors.top = parent.top
                    quickChangeObjects.anchors.topMargin = 50 + plot.topMarginExpertMode
                    quickChangeObjects.anchors.leftMargin = 20
                    plot.setGridHorizontalNow(true)
                } else {
                    // Vertical
                    quickChangeObjects.anchors.left = parent.left
                    quickChangeObjects.anchors.leftMargin = 20
                    quickChangeObjects.anchors.bottom = parent.bottom
                    quickChangeObjects.anchors.bottomMargin = 20
                    plot.setGridHorizontalNow(false)
                }
            }
            */
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
            plot.plotRangefinderVisible(false)
            //plot.plotRangefinderTheme(1)        model: [qsTr("Text"), qsTr("Line"), qsTr("Dot")], values 0-2

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

            console.log("TAV pulsePlotPresets ran");

        }

        function pulseBottomTrackingProcessingPresets () {

            /* -- PULSE: DEFAULT BOTTOM TRACKING SETTINGS AT STARTUP -- */

            // PRESET
            // plot.setPreset(0)             //Preset: 0:Normal 2D, 1:Narrow 2D, 2: Side-Scan


            /* -- NOTE: Remaining settings not to be altered separately but as shown in DisplaySettings.qml "updateProcessing() -- */

            //gainSlope: false, value (1.00, 0-300, steps 10)
            /*
            if (false) {
                plot.setGainSlope(0.00 / 100)
            }
            */

            //Threshold: false, value (0.00)
            /*
            if (false) {
                plot.setThreshold(0.00 / 100)
            }
            */

            //Horizontal Window: false, value (1-100)
            /*
            if (false) {
                plot.setWindowSize(1)
            }
            */

            //Vertical Gap, %: value (10)
            //plot.setVerticalGap(10 * 0.01)

            //Min range, m: true, 0.00
            //plot.setRangeMin (0 / 1000)
            //Max range, m: true, 100.00
            //plot.setRangeMax (100.0 / 1000)

            //Sonar offset XYZ, mm: value, value, value
            //plot.setOffsetX(50 * 0.001)
            //plot.setOffsetY(50 * 0.001)
            //plot.setOffsetZ(50 * 0.001)

            console.log("TAV pulseBottomTrackingProcessingPresets ran");
        }

        function setUserInterface () {
            console.log("TAV function setUserInterface, pulseRuntimeSettings.devName =", pulseRuntimeSettings.devName);

            isDevice2DTransducer()
            /*
            if (pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseRed) {
                showAs2DTransducer = true
            }
            if (pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseBlue) {
                showAs2DTransducer = false
            }
            if (pulseRuntimeSettings.devName === "...") {
                if (PulseSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                    showAs2DTransducer = true
                } else {
                    showAs2DTransducer = false
                }
                console.log("TAV deviceName is ..., but userManualSetName", PulseSettings.userManualSetName);
            }
            */


            console.log("TAV setUserInterface showAs2DTransducer =", showAs2DTransducer);
            //console.log("TAV function setUserInterface,compare to", pulseRuntimeSettings.modelPulseRed);
            //if (pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseRed) {
            if (showAs2DTransducer) {
                console.log("TAV: setUserInterface horizontal - pulseRed");
                plot.setHorizontalNow()
                plot.setGridHorizontalNow(true)
                plot.plotDistanceRange2d(PulseSettings.maxDepthValue * 1.0)
                console.log("TAV: setUserInterface horizontal - pulseRed - done");
            } else {
                if (PulseSettings.ecoViewIndex === 1) {
                    console.log("TAV: setUserInterface vertical - pulseBlue viewIndex 1");
                    plot.setVerticalNow()
                    plot.setGridHorizontalNow(false)
                    plot.plotDistanceRange(PulseSettings.maxDepthValue * 1.0)
                    console.log("TAV: setUserInterface vertical - pulseBlue viewIndex 1 - done");
                } else {
                    console.log("TAV: setUserInterface horizontal - pulseBlue viewIndex 0");
                    plot.setHorizontalNow()
                    plot.setGridHorizontalNow(true)
                    plot.plotDistanceRange2d(PulseSettings.maxDepthValue * 1.0)
                    console.log("TAV: setUserInterface horizontal - pulseBlue viewIndex 0 - done");
                }
            }
            if (showAs2DTransducer) {
            //if (!pulseRuntimeSettings.is2DTransducer) {
                plot.plotEchogramTheme(PulseSettings.colorMapIndex2D + quickChangeTheme.themeOffset)
            } else {
                plot.plotEchogramTheme(PulseSettings.colorMapIndexSideScan + quickChangeTheme.themeOffset)
            }

            reArrangeQuickChangeObject()
            plot.updatePlot()
        }

        function doAutoFilter() {
            if (PulseSettings.autoFilter) {
                let currentMaxDept = pulseRuntimeSettings.autoDepthMaxLevel
                let newFilterValue = 0
                if (currentMaxDept >= 8) {
                    newFilterValue = 13
                }
                if (currentMaxDept >= 5 && currentMaxDept < 8) {
                    newFilterValue = 25
                }
                if (currentMaxDept < 5) {
                    newFilterValue = 33
                }
                plot.setFilteringValue(newFilterValue)
                plot.updatePlot()
                console.log("TAV: auto filter updated plot to real newFilterValue", newFilterValue);
            } else {
                console.log("TAV: auto filter not active");
            }
        }

        Component.onCompleted: {
            console.log("TAV Plot2D onCompleted, do nothing");
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
                console.log("TAV: onDevDetectedChanged:", pulseRuntimeSettings.devDetected);
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
                console.log("TAV: onDevManualSelectedChanged detected");
                if (pulseRuntimeSettings.devManualSelected) {
                    console.log("TAV: devManualSelected true, is this a 2D transducer?", pulseRuntimeSettings.is2DTransducer);
                    let newFrequency = pulseRuntimeSettings.transFreq
                    quickChangeObjects.isDeviceDetected = true
                    if (pulseRuntimeSettings.is2DTransducer) {
                        if (PulseSettings.ecoConeIndex === 0) {
                            newFrequency = pulseRuntimeSettings.transFreqWide
                        } else {
                            newFrequency = pulseRuntimeSettings.transFreqNarrow
                        }
                        console.log("TAV: Preferred echosounder 2D cone:", pulseRuntimeSettings.transFreq);
                    }
                    pulseRuntimeSettings.transFreq = newFrequency
                    quickChangeObjects.setUserInterface();
                } else {
                    console.log("TAV: devManualSelected false, skip");
                }
            }

            function onExpertModeChanged() {
                console.log("TAV: onExpertModeChanged detected");
                if (pulseRuntimeSettings.expertMode) {
                    console.log("TAV: onExpertModeChanged true, change the UI");
                    plot.topMarginExpertMode = 100;
                    quickChangeObjects.setUserInterface();
                } else {
                    plot.topMarginExpertMode = 0;
                    quickChangeObjects.setUserInterface();
                    console.log("TAV: onExpertModeChanged false, skip");
                }
            }

            function onAppConfiguredChanged () {
                console.log("TAV: onAppConfiguredChanged detected");
                quickChangeObjects.setUserInterface();
            }

            function onAutoDepthMaxLevelChanged () {
                console.log("TAV: onAutoDepthMaxLevelChanged is now", pulseRuntimeSettings.autoDepthMaxLevel);
                quickChangeObjects.doAutoFilter()
            }

            function onShouldDoAutoRangeChanged () {
                console.log("TAV: onShouldDoAutoRangeChanged is now", pulseRuntimeSettings.shouldDoAutoRange);
            }
        }


        DepthAndTemperature {
            id: thisDepthAndTemperature
            GridLayout.row: 0
            GridLayout.column: 0
            Layout.rowSpan: 2
            Layout.preferredWidth: 370
            //visible: true
            opacity: (quickChangeObjects.isDeviceDetected) ? 1 : 0
            enabled: (quickChangeObjects.isDeviceDetected)
        }


        HorizontalController {
            id: selectorMaxDepth

            GridLayout.row: 0
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
                console.log("TAV: Auto range requested");
                plot.plotDistanceAutoRange(0)
                PulseSettings.autoRange = true
                pulseRuntimeSettings.shouldDoAutoRange = true
                plot.updatePlot()
            }

            onDistanceFixedRangeRequested: {
                console.log("TAV: Fixed range requested");
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
            GridLayout.row: 1
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
                let actualValue = Math.round(120 - (value * 3));
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
            controleName: "selectorFiltering"
            GridLayout.row: 2
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
                console.log("TAV: Auto filter requested");
                PulseSettings.autoFilter = true
                quickChangeObjects.doAutoFilter()
            }

            onFilterFixedRangeRequested: {
                console.log("TAV: Fixed filter requested");
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

            GridLayout.row: 2
            GridLayout.column: 0
            Layout.preferredWidth: 350


            // Calculate the offset and number of items based on the transducer type.
            property int themeOffset: pulseRuntimeSettings.is2DTransducer ? 5 : 0
            property var themeModel: pulseRuntimeSettings.fullThemeArray.slice(quickChangeTheme.themeOffset, quickChangeTheme.themeOffset + (pulseRuntimeSettings.is2DTransducer ? 7 : 5));



            HorizontalTapSelectController {
                id: themeSelectorColorSS
                //visible: !pulseRuntimeSettings.is2DTransducer
                visible: !quickChangeObjects.showAs2DTransducer
                model: quickChangeTheme.themeModel
                iconSource: "./icons/pulse_paint.svg"
                selectedIndex: PulseSettings.colorMapIndexSideScan
                allowExpertModeByMultiTap: true
                onIconSelected: {
                    console.log("TAV: colormap is2DTransducer:", pulseRuntimeSettings.is2DTransducer);
                    //PulseSettings.colorMapIndex = selectedIndex;
                    PulseSettings.colorMapIndexSideScan = selectedIndex;
                    plot.plotEchogramTheme(selectedIndex + quickChangeTheme.themeOffset);
                    plot.updatePlot();
                }

                Component.onCompleted: {
                    console.log("TAV: colormap is2DTransducer:", pulseRuntimeSettings.is2DTransducer);
                    if (!pulseRuntimeSettings.is2DTransducer) {
                        plot.plotEchogramTheme(PulseSettings.colorMapIndexSideScan + quickChangeTheme.themeOffset)
                        plot.updatePlot();
                    }
                }
            }

            HorizontalTapSelectController {
                id: themeSelectorColor2D
                //visible: pulseRuntimeSettings.is2DTransducer
                visible: quickChangeObjects.showAs2DTransducer
                model: quickChangeTheme.themeModel
                iconSource: "./icons/pulse_paint.svg"
                selectedIndex: PulseSettings.colorMapIndex2D
                allowExpertModeByMultiTap: true
                onIconSelected: {
                    console.log("TAV: colormap is2DTransducer:", pulseRuntimeSettings.is2DTransducer);
                    PulseSettings.colorMapIndex2D = selectedIndex;
                    plot.plotEchogramTheme(selectedIndex + quickChangeTheme.themeOffset);
                    plot.updatePlot();
                }

                Component.onCompleted: {
                    console.log("TAV: colormap is2DTransducer:", pulseRuntimeSettings.is2DTransducer);
                    if (pulseRuntimeSettings.is2DTransducer) {
                        plot.plotEchogramTheme(PulseSettings.colorMapIndex2D + quickChangeTheme.themeOffset)
                        plot.updatePlot();
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
                        plot.setHorizontalNow()
                        plot.plotDistanceRange2d(plot.quickChangeMaxRangeValue * 1.0)
                        pulseRuntimeSettings.isSideScan2DView = true
                    } else {
                        plot.setVerticalNow()
                        plot.plotDistanceRange(plot.quickChangeMaxRangeValue * 1.0)
                        pulseRuntimeSettings.isSideScan2DView = false
                    }
                    quickChangeObjects.reArrangeQuickChangeObject()

                    //console.log("TAV: Selected echosounder index:", selectedIndex);
                }
                Component.onCompleted: {
                    if (PulseSettings.ecoViewIndex === 0) {
                        plot.setHorizontalNow()
                        plot.plotDistanceRange2d(plot.quickChangeMaxRangeValue * 1.0)
                        pulseRuntimeSettings.isSideScan2DView = true
                    } else {
                        plot.setVerticalNow()
                        plot.plotDistanceRange(plot.quickChangeMaxRangeValue * 1.0)
                        pulseRuntimeSettings.isSideScan2DView = false
                    }
                    plot.updatePlot();
                }
            }

            HorizontalTapSelectController {
                id: themeSelector3
                visible: pulseRuntimeSettings.is2DTransducer
                model: [
                    "./icons/pulse_cone_wide.svg",
                    "./icons/pulse_cone_narrow_ultra.svg"
                ]
                iconSource: "./icons/pulse_glasses.svg"
                selectedIndex: PulseSettings.ecoConeIndex
                allowExpertModeByMultiTap: false
                onIconSelected: {
                    if (selectedIndex === 1) {
                        //DeviceItem.transFreq = themeSelector3.coneNarrow
                        pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqNarrow
                        console.log("TAV: Selected echosounder cone (frequency):", pulseRuntimeSettings.transFreq);
                    } else {
                        pulseRuntimeSettings.transFreq = pulseRuntimeSettings.transFreqWide
                        //DeviceItem.transFreq = themeSelector3.coneWide
                        console.log("TAV: Selected echosounder cone (frequency):", pulseRuntimeSettings.transFreq);
                    }
                    PulseSettings.ecoConeIndex = selectedIndex

                    console.log("TAV: Selected echosounder cone index:", themeSelector3.selectedIndex);
                }
                Component.onCompleted: {

                }

            }

        }

    }

    Rectangle {
        id: toggleInfoContainer
        width: 155
        height: 80
        radius: 40
        color:  "#80000000"
        anchors.left: quickChangeObjects.left
        anchors.bottom: quickChangeObjects.top
        anchors.bottomMargin: 15
        visible: pulseRuntimeSettings.devDetected || pulseRuntimeSettings.devManualSelected

        Image {
            id: toggleInfoIcon
            anchors.centerIn: toggleInfoContainer
            width: 56
            height: 56
            source: "./icons/pulse_info.svg"  // Update this path to your SVG file
            fillMode: Image.PreserveAspectFit
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                pulseInfoLoader.active = !pulseInfoLoader.active;
            }
        }
    }

    Rectangle {
        id: toggleSettingsContainer
        width: 155
        height: 80
        radius: 40
        color:  "#80000000"
        anchors.left: toggleInfoContainer.right
        anchors.bottom: quickChangeObjects.top
        anchors.bottomMargin: 15
        anchors.leftMargin: 15
        visible: pulseRuntimeSettings.devDetected || pulseRuntimeSettings.devManualSelected

        Image {
            id: toggleSettingsIcon
            anchors.centerIn: toggleSettingsContainer
            width: 64
            height: 64
            source: "./icons/pulse_settings.svg"  // Update this path to your SVG file
            fillMode: Image.PreserveAspectFit
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                console.log("TAV: Tapped on settings icon");
                pulseSettingsLoader.active = !pulseSettingsLoader.active;
            }
        }
    }

    Loader {
        id: pulseInfoLoader
        source: "PulseInfo.qml"  // Ensure PulseInfo.qml is available at this path
        active: false           // Initially hidden
        anchors.centerIn: parent  // Adjust as needed for your layout
        onActiveChanged: {
            if (active) {
                closePulseInfoTimer.restart();
            } else {
                closePulseInfoTimer.stop();
            }
        }
    }

    Loader {
        id: pulseSettingsLoader
        source: "PulseInfoSettings.qml"  // Ensure PulseInfo.qml is available at this path
        active: false           // Initially hidden
        anchors.centerIn: parent  // Adjust as needed for your layout

        onActiveChanged: {
            console.log("TAV: pulseSettingsLoader triggered");
            if (active) {
                closePulseSettingsTimer.restart();
            } else {
                closePulseSettingsTimer.stop();
            }
        }
    }

    Connections {
        target: pulseSettingsLoader.item   // This will automatically update when the Loader loads a new item.
        function onPulsePreferenceClosed() {
            // Handle the close event here. For example, you might set active to false:
            pulseSettingsLoader.active = false;
            closePulseSettingsTimer.stop();
        }
        function onPulsePreferenceValueChanged() {
            closePulseSettingsTimer.restart();
        }
    }


    Image {
        id: companyWaterMark
        source: "./image/logo_techadvision_gray.png"  // Update the path as needed
        anchors.bottom: parent.bottom
        anchors.left: quickChangeObjects.right
        anchors.bottomMargin: 40
        anchors.leftMargin: 40
        width: 360
        height: 43
        opacity: 60
        visible: pulseRuntimeSettings.devManualSelected
    }

    Timer {
        id: closePulseSettingsTimer
        interval: 15000   // 30 seconds in milliseconds
        repeat: false
        onTriggered: {
            pulseSettingsLoader.active = false;
        }
    }


    Timer {
        id: closePulseInfoTimer
        interval: 6000   // 6 seconds in milliseconds
        repeat: false
        onTriggered: {
            pulseInfoLoader.active = false;
        }
    }


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
