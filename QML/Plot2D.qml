import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 1.2
import Qt.labs.settings 1.1

import WaterFall 1.0
import org.techadvision.settings 1.0

WaterFall {
    id: plot

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

                console.log("TAV: mouse - onPositionChanged wasMoved?", wasMoved);

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
                            console.log("TAV: mouse - horScrollEvent", delta);
                        } else {
                            plot.horScrollEvent(deltaY)
                            console.log("TAV: mouse - verScrollEvent", deltaY);
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

    ColumnLayout {

        id: quickChangeObjects
        width: 350
        clip: true

        property real quickChangeStartValue: 0
        property real quickChangeStopValue: 120
        property real quickChangeDefaultIlluminationValue: 10
        property real quickChangeDefaultFilterValue: 1
        property bool quickChangeScanVisible: false
        property bool quickChangeConeVisible: false

        function reArrangeQuickChangeObject () {
            quickChangeObjects.anchors.left = parent.left
            quickChangeObjects.anchors.leftMargin = 20
            quickChangeObjects.anchors.bottom = parent.bottom
            quickChangeObjects.anchors.bottomMargin = 20

            //Having trouble to properly get the signal for 2D vs SideScan
            //Commented this out, always place at the bottom for now
            /*
            console.log("TAV reArrangeQuickChangeObject ran, and isViewHorizontal is :", plot.isViewHorizontal());
            quickChangeObjects.anchors.left = undefined;
            quickChangeObjects.anchors.right = undefined;
            quickChangeObjects.anchors.top = undefined;
            quickChangeObjects.anchors.bottom = undefined;
            quickChangeObjects.anchors.topMargin = undefined;
            quickChangeObjects.anchors.leftMargin = undefined;
            quickChangeObjects.anchors.bottomMargin = undefined;

            if (plot.isViewHorizontal()) {
                quickChangeObjects.anchors.left = parent.left
                quickChangeObjects.anchors.top = parent.top
                quickChangeObjects.anchors.topMargin = 50
                quickChangeObjects.anchors.leftMargin = 20
            } else {
                quickChangeObjects.anchors.left = parent.left
                quickChangeObjects.anchors.leftMargin = 20
                quickChangeObjects.anchors.bottom = parent.bottom
                quickChangeObjects.anchors.bottomMargin = 20
            }
            */
        }

        function pulsePlotPresets () {

            // DATASET CHANNELS
            //plot.plotDatasetChannel(32768, 32767) //dataset true, plot first, none: None=32767,First = 32768
            //core.setSideScanChannels(32768, 32767)//dataset true, plot first, none: None=32767,First = 32768

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
            plot.setPreset(0)             //Preset: 0:Normal 2D, 1:Narrow 2D, 2: Side-Scan


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
            console.log("TAV function setUserInterface");
            if (PulseSettings.is2DTransducer) {
                console.log("TAV horizontal setUserInterface for 2D set");
                plot.setHorizontalNow()
                plot.plotDistanceRange2d(PulseSettings.maxDepthValue * 1.0)
                console.log("TAV horizontal setUserInterface for 2D done");
            } else {
                if (PulseSettings.ecoViewIndex === 1) {
                    console.log("TAV vertical setUserInterface for SS set");
                    plot.setVerticalNow()
                    plot.plotDistanceRange(PulseSettings.maxDepthValue * 1.0)
                    console.log("TAV vertical setUserInterface for SS done");
                } else {
                    console.log("TAV horizontal setUserInterface for SS set");
                    plot.setHorizontalNow()
                    plot.plotDistanceRange2d(PulseSettings.maxDepthValue * 1.0)
                    console.log("TAV horizontal setUserInterface for SS done");
                }
            }
            reArrangeQuickChangeObject()
            plot.updatePlot()
        }

        Component.onCompleted: {
            console.log("TAV Plot2D onCompleted, let's rearrange the UI");
            quickChangeObjects.pulsePlotPresets()
            quickChangeObjects.pulseBottomTrackingProcessingPresets()
            quickChangeObjects.setUserInterface()
        }

        Connections {
            target: DeviceItem
            onTransducerDetected: {
                console.log("TAV onTransducerDetected, observed");
                quickChangeObjects.setUserInterface()
            }
        }

        Connections {
            target: PulseSettings
            // Note the use of the auto-generated property change signal: onTransducerChangeDetectedChanged
            function onTransducerChangeDetectedChanged() {
                if (PulseSettings.transducerChangeDetected) {
                    console.log("TAV: onTransducerChangeDetected observed");
                    // Reset the flag
                    PulseSettings.transducerChangeDetected = false;
                    quickChangeObjects.setUserInterface();
                }
            }
        }



        /*
        Connections {
            target: PulseSettings
            onTransducerChangeDetected: {
                console.log("TAV onTransducerChangeDetected, observed");
                if (!PulseSettings.transducerChangeDetected) {
                    console.log("TAV onTransducerChangeDetected is false, aborting");
                    return
                }
                PulseSettings.transducerChangeDetected = false
                console.log("TAV onTransducerChangeDetected, let's rearrange the UI");
                quickChangeObjects.setUserInterface()
            }
        }
        */


        RowLayout {
            spacing: 0

            DepthAndTemperature {
                id:                depthAndTemperature
                objectName:        "depthAndTemperature"
                visible:           true
                }

        }

        RowLayout {
            id: quickChangeMaxDepth
            spacing: 10
            Layout.topMargin: 10

            HorizontalController {
                id: selectorMaxDepth
                controleName: "selectorMaxDepth"
                minValue: 2
                maxValue: 50
                step: 1
                defaultValue: PulseSettings.maxDepthValue
                iconSource: "./icons/pulse_ruler.svg"

                onSelectorValueChanged: {
                    plot.quickChangeMaxRangeValue = value;
                    PulseSettings.maxDepthValue = value;
                    if (plot.isViewHorizontal()) {
                        plot.plotDistanceRange2d(value * 1.0)
                    } else {
                        plot.plotDistanceRange(value * 1.0)
                    }
                    plot.updatePlot()
                    console.log("TAV: selectorMaxDepth changed max depth:", value)
                }

                onDistanceAutoRangeRequested: {
                    console.log("TAV: Auto range requested");
                    plot.plotDistanceAutoRange(0)
                    PulseSettings.autoRange = true
                    plot.updatePlot()
                }

                onDistanceFixedRangeRequested: {
                    console.log("TAV: Fixed range requested");
                    plot.plotDistanceAutoRange(-1)
                    PulseSettings.autoRange = false;
                    if (plot.isViewHorizontal()) {
                        plot.plotDistanceRange2d(plot.quickChangeMaxRangeValue * 1.0)
                    } else {
                        plot.plotDistanceRange(plot.quickChangeMaxRangeValue * 1.0)
                    }
                    plot.updatePlot()
                }

                Component.onCompleted: {
                    if (PulseSettings.autoRange) {
                        plot.plotDistanceAutoRange(0);
                    } else {
                        plot.plotDistanceAutoRange(-1);
                        plot.plotDistanceRange(PulseSettings.maxDepthValue * 1.0)
                    }
                    plot.updatePlot();
                }

            }

        }

        RowLayout {
            id: quickChangeIntensity
            spacing: 10
            Layout.topMargin: 10

            HorizontalController {
                id: selectorIntensity
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
                    //echogramLevelsSlider.stopValue = actualValue;
                    //plot.plotEchogramSetLevels(quickChangeObjects.quickChangeStartValue, quickChangeObjects.quickChangeStopValue);
                    plot.setIntensityValue(actualValue * 1.0)
                    console.log("TAV: selectorIntensity changed intensity (presented):", value, " (actual):", actualValue);
                }

                Component.onCompleted: {
                    plot.setIntensityValue(PulseSettings.intensityRealValue * 1.0)
                }
            }

        }

        RowLayout {
            id: quickChangeFiltering
            spacing: 10
            Layout.topMargin: 10

            HorizontalController {
                id: selectorFiltering
                controleName: "selectorFiltering"
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
                    //echogramLevelsSlider.startValue = actualValue;
                    //plot.plotEchogramSetLevels(quickChangeObjects.quickChangeStartValue, quickChangeObjects.quickChangeStopValue);
                    console.log("TAV: selectorFiltering changed filter (presented):", value, " (actual):", actualValue);
                }

                Component.onCompleted: {
                    plot.setFilteringValue(PulseSettings.filterRealValue)
                }

            }
        }

        RowLayout {
            id: quickChangeTheme
            spacing: 10
            Layout.topMargin: 10

            HorizontalControllerIcon {
                id: themeSelector
                model: [
                    "./icons/pulse_color_blue.svg",
                    "./icons/pulse_color_sepia.svg",
                    "./icons/pulse_color_WRGDB.svg",
                    "./icons/pulse_color_WB.svg"
                ]
                iconSource: "./icons/pulse_paint.svg"
                selectedIndex: PulseSettings.colorMapIndex
                onIconSelected: {
                    plot.plotEchogramTheme(selectedIndex);
                    PulseSettings.colorMapIndex = selectedIndex;
                    console.log("TAV: Selected theme index:", selectedIndex);
                }

                Component.onCompleted: {
                    plot.plotEchogramTheme(PulseSettings.colorMapIndex)
                    plot.updatePlot();
                }
            }
        }

        RowLayout {
            id: quickChangeScan
            spacing: 10
            Layout.topMargin: 10

            HorizontalControllerIcon {
                id: themeSelector2
                visible: !PulseSettings.is2DTransducer
                model: [
                    "./icons/pulse_view_downscan.svg",
                    "./icons/pulse_view_sidescan.svg"
                ]
                iconSource: "./icons/pulse_glasses.svg"
                selectedIndex: PulseSettings.ecoViewIndex
                onIconSelected: {
                    plot.plotEchogramCompensation(selectedIndex);
                    PulseSettings.ecoViewIndex = selectedIndex
                    if (selectedIndex === 0) {
                        plot.setHorizontalNow()
                        plot.plotDistanceRange2d(plot.quickChangeMaxRangeValue * 1.0)
                    } else {
                        plot.setVerticalNow()
                        plot.plotDistanceRange(plot.quickChangeMaxRangeValue * 1.0)
                    }
                    quickChangeObjects.reArrangeQuickChangeObject()

                    console.log("TAV: Selected echosounder index:", selectedIndex);
                }
                Component.onCompleted: {
                    if (PulseSettings.ecoViewIndex === 0) {
                        plot.setHorizontalNow()
                        plot.plotDistanceRange2d(plot.quickChangeMaxRangeValue * 1.0)
                    } else {
                        plot.setVerticalNow()
                        plot.plotDistanceRange(plot.quickChangeMaxRangeValue * 1.0)
                    }
                    plot.updatePlot();
                }
            }
        }

        RowLayout {
            id: quickChangeCone
            spacing: 10
            Layout.topMargin: 10

            HorizontalControllerIcon {
                id: themeSelector3
                visible: PulseSettings.is2DTransducer
                property int coneWide: 235
                property int coneNarrow: 710
                model: [
                    "./icons/pulse_cone_wide.svg",
                    "./icons/pulse_cone_narrow_ultra.svg"
                ]
                iconSource: "./icons/pulse_glasses.svg"
                selectedIndex: PulseSettings.ecoConeIndex
                onIconSelected: {
                    if (selectedIndex === 1) {
                        DeviceItem.transFreq = themeSelector3.coneNarrow
                        console.log("TAV: Selected echosounder cone:", themeSelector3.coneNarrow);
                    } else {
                        DeviceItem.transFreq = themeSelector3.coneWide
                        console.log("TAV: Selected echosounder cone:", themeSelector3.coneWide);
                    }
                    PulseSettings.ecoConeIndex = selectedIndex

                    console.log("TAV: Selected echosounder cone:", themeSelector3.selectedIndex);
                }
                Component.onCompleted: {
                    console.log("TAV: quickChangeCone preference PulseSettings.ecoConeIndex:", PulseSettings.ecoConeIndex);
                    if (PulseSettings.ecoConeIndex === 0) {
                        DeviceItem.transFreq = themeSelector3.coneWide
                        console.log("TAV: Preferred echosounder cone:", themeSelector3.coneWide);
                    } else {
                        DeviceItem.transFreq = themeSelector3.coneNarrow
                        console.log("TAV: Preferred echosounder cone:", themeSelector3.coneNarrow);
                    }
                    plot.updatePlot();
                }

            }
        }
    }

    MenuFrame {
        Layout.alignment: Qt.AlignHCenter
        //visible: visible2dButton.checked
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

        ButtonGroup { id: pencilbuttonGroup }

        CheckButton {
            icon.source: "./icons/direction-arrows.svg"
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

            onClicked: {
                menuBlock.visible = false
            }

            ButtonGroup.group: pencilbuttonGroup
        }
    }
}
}
