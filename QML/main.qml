import QtQuick 2.15
import SceneGraphRendering 1.0
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import Qt.labs.settings 1.1
import QtQuick.Dialogs 1.2
import QtQuick.Controls 2.15
import WaterFall 1.0
import KoggerCommon 1.0
import QtGraphicalEffects 1.15



ApplicationWindow  {
    id:            mainview
    visible:       true
    width:         1024
    minimumWidth:  512
    height:        512
    minimumHeight: 256
    color:         "black"
    title:         qsTr("Pulse, TechAdVision")

    readonly property int _rightBarWidth:                360
    readonly property int _activeObjectParamsMenuHeight: 500
    readonly property int _sceneObjectsListHeight:       300

    property bool windowShadow: true
    property var lostConnectionAlert: null

    // Create an instance of the singleton.
        // You can use an Item or a dummy object if no visual representation is needed.

    Settings {
            id: appSettings
            property bool isFullScreen: false
            //property int savedX: 100
            //property int savedY: 100
    }

    Loader {
        id: stateGroupLoader
        active: (Qt.platform.os === "windows")
        sourceComponent: stateGroupComp
    }

    Component {
        id: stateGroupComp
        StateGroup {
            state: appSettings.isFullScreen ? "FullScreen" : "Windowed"

            states: [
                State {
                    name: "FullScreen"
                    StateChangeScript {
                        script: { // empty
                        }
                    }
                    PropertyChanges {
                        target: mainview ? mainview : undefined
                        visibility: "FullScreen"

                        flags: Qt.FramelessWindowHint
                        x: 0
                        y: - 1
                        width: Screen.width
                        height: Screen.height + 1
                    }
                },
                State {
                    name: "Windowed"
                    StateChangeScript {
                        script: {
                            if (Qt.platform.os !== "android") {
                                mainview.flags = Qt.Window
                            }
                        }
                    }
                    PropertyChanges {
                        target: mainview ? mainview : undefined
                        visibility: "Windowed"
                    }
                }
            ]
        }
    }

    Connections {
        target: core ? core : undefined
        function onSendIsFileOpening() {
            //console.log("TAV main onSendIsFileOpening");
            pulseRuntimeSettings.isOpeningKlfFile = true
        }
    }

    Component.onCompleted: {
        pulseRuntimeSettings.isSideScanLeftHand = PulseSettings.isSideScanOnLeftHandSide
        var code     = PulseSettings.keyCode
        var isBeta   = pulseRuntimeSettings.betaKeyCodes.indexOf(code)   !== -1
        var isExpert = pulseRuntimeSettings.expertKeyCodes.indexOf(code) !== -1
        pulseRuntimeSettings.expertMode = isExpert
        pulseRuntimeSettings.betaMode   = isExpert || isBeta
        PulseSettings.isBetaTester = isBeta
        PulseSettings.isExpert = isExpert

        //theme.updateResCoeff(); // for UI scaling

        menuBar.languageChanged.connect(handleChildSignal)

        if (Qt.platform.os !== "windows") {
            if (appSettings.isFullScreen) {
                mainview.showFullScreen();
            }
        }

        // contacts
        function setupConnections() {
            if (typeof contacts !== "undefined") {
                contactConnections.target = contacts;
            }
            else {
                Qt.callLater(setupConnections);
            }
        }
        Qt.callLater(setupConnections);
    }

    // banner on languageChanged
    property bool showBanner: false
    property string selectedLanguageStr: qsTr("Undefined")

    function showLostConnection () {

        if (pulseRuntimeSettings.isOpeningKlfFile) {
            //console.log("TAV: showLostConnection, please do not when viewing a file");
            return
        }

        if (lostConnectionAlert === null) {
            var component = Qt.createComponent("LostConnectionOverlay.qml")
            lostConnectionAlert = component.createObject( mainview, {"x": 0, "y": 0 } )
            if (lostConnectionAlert !== null) {
                lostConnectionAlert.anchors.centerIn = echoSounderSelectorRect
                //pulseRuntimeSettings.devName = "..."
                //console.log("TAV: showLostConnection, showing the alert");
            } else {
                //console.log("TAV: showLostConnection is null, cannot show the alert");
            }
        }

    }

    function removeLostConnection () {

        if (lostConnectionAlert !== null) {
            lostConnectionAlert.destroy()
            lostConnectionAlert = null
            pulseRuntimeSettings.hasDeviceLostConnection = false
            //console.log("TAV: showLostConnection, removed the alert");
        } else {
            //console.log("TAV: showLostConnection is null, cannot remove the alert or it was not there at all");
        }
    }


    Rectangle {
        id: banner
        anchors.fill: parent
        color: "black"
        opacity: 0.8
        visible: showBanner

        Column {
            anchors.centerIn: parent
            spacing: 20

            Text {
                text: qsTr("Please restart the application to apply the language change") + " (" + selectedLanguageStr + ")"
                color: "white"
                font.pixelSize: 24
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            CButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Ok")
                onClicked: {
                    mainview.showBanner = false
                }
            }
        }
    }

    //-> drag-n-drop
    property string draggedFilePath: ""

    Rectangle {
        id: overlay
        anchors.fill: parent
        color: "white"
        opacity: 0
        z: 1

        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }
    }

    DropArea {
        anchors.fill: parent
        //Do we need this?

        onEntered: {
            if (!showBanner) {
                draggedFilePath = ""
                if (drag.hasUrls) {
                    for (var i = 0; i < drag.urls.length; ++i) {
                        var url = drag.urls[i]
                        var filePath = url.replace("file:///", "").toLowerCase()
                        if (filePath.endsWith(".klf")) {
                            draggedFilePath = filePath
                            overlay.opacity = 0.3
                            break
                        }
                    }
                }
            }
        }

        onExited: {
            if (!showBanner) {
                overlay.opacity = 0
                draggedFilePath = ""
            }
        }

        onDropped: {
            if (!showBanner) {
                if (draggedFilePath !== "") {
                    core.openLogFile(draggedFilePath, false, true)
                    overlay.opacity = 0
                    draggedFilePath = ""
                }
                overlay.opacity = 0
            }
        }
    }
    // drag-n-drop <-

    SplitView {
        //Do need all of this?
        id: splitLayer
        visible: !showBanner
        Layout.fillHeight: true
        Layout.fillWidth:  true
        anchors.fill:      parent
        orientation:       Qt.Vertical

        Keys.onReleased: {
            /*
            let sc = event.nativeScanCode.toString()
            let hotkeyData = hotkeysMapScan[sc];
            if (hotkeyData === undefined) {
                return
            }

            let fn = hotkeyData["functionName"];
            let p = hotkeyData["parameter"];

            // high priority
            if (fn === "toggleFullScreen") {
                if (Qt.platform.os === "windows") {
                    appSettings.isFullScreen = !appSettings.isFullScreen
                }
                else if (Qt.platform.os === "linux") {
                    if (mainview.visibility === Window.FullScreen) {
                        mainview.showNormal();
                        appSettings.isFullScreen = false;
                    }
                    else {
                        appSettings.isFullScreen = true;
                        mainview.showFullScreen();
                    }
                }
                return;
            }
            if (fn === "closeSettings") {
                menuBar.closeMenus()
                splitLayer.focus = true
                return;
            }

            if (mainview.activeFocusItem &&
                (mainview.activeFocusItem instanceof TextEdit || mainview.activeFocusItem instanceof TextField)) {
                return;
            }

            if (fn !== undefined) {
                if (p === undefined) {
                    p = 5
                }

                switch (fn) {
                case "horScrollLeft": {
                    waterView.horScrollEvent(-p)
                    break
                }
                case "horScrollRight": {
                    waterView.horScrollEvent(p)
                    break
                }
                case "verScrollUp": {
                    waterView.verScrollEvent(-p)
                    break
                }
                case "verScrollDown": {
                    waterView.verScrollEvent(p)
                    break
                }
                case "verZoomOut": {
                    waterView.verZoomEvent(-p)
                    break
                }
                case "verZoomIn": {
                    waterView.verZoomEvent(p)
                    break
                }
                case "increaseLowLevel": {
                    let newLow = Math.min(120, waterView.getLowEchogramLevel() + p)
                    let newHigh = waterView.getHighEchogramLevel()
                    if (newLow > newHigh) newHigh = newLow
                    waterView.plotEchogramSetLevels(newLow, newHigh)
                    waterView.setLevels(newLow, newHigh)
                    break
                }
                case "decreaseLowLevel": {
                    let newLow = Math.max(0, waterView.getLowEchogramLevel() - p)
                    let newHigh = waterView.getHighEchogramLevel()
                    waterView.plotEchogramSetLevels(newLow, newHigh)
                    waterView.setLevels(newLow, newHigh)
                    break
                }
                case "increaseHighLevel": {
                    let newHigh = Math.min(120, waterView.getHighEchogramLevel() + p)
                    let newLow = waterView.getLowEchogramLevel()
                    waterView.plotEchogramSetLevels(newLow, newHigh)
                    waterView.setLevels(newLow, newHigh)
                    break
                }
                case "decreaseHighLevel": {
                    let newHigh = Math.max(0, waterView.getHighEchogramLevel() - p)
                    let newLow = waterView.getLowEchogramLevel()
                    if (newHigh < newLow) newLow = newHigh
                    waterView.plotEchogramSetLevels(newLow, newHigh)
                    waterView.setLevels(newLow, newHigh)
                    break
                }
                case "prevTheme": {
                    let themeId = waterView.getThemeId()
                    if (themeId > 0) waterView.plotEchogramTheme(themeId - 1)
                    break
                }
                case "nextTheme": {
                    let themeId = waterView.getThemeId()
                    if (themeId < 4) waterView.plotEchogramTheme(themeId + 1)
                    break
                }
                case "clickConnections": {
                    menuBar.clickConnections()
                    break
                }
                case "clickSettings": {
                    menuBar.clickSettings()
                    break
                }
                case "click3D": {
                    menuBar.click3D()
                    break
                }
                case "click2D": {
                    menuBar.click2D()
                    break
                }
                default: {
                    break
                }
                }
            }
            */
        }

        handle: Rectangle {
            // implicitWidth:  5
            implicitHeight: theme.controlHeight/2
            color:          SplitHandle.pressed ? "#A0A0A0" : "#707070"

            Rectangle {
                width:  parent.width
                height: 1
                color:  "#A0A0A0"
            }

            Rectangle {
                y:      parent.height
                width:  parent.width
                height: 1
                color:  "#A0A0A0"
            }
        }

        GridLayout {
            id:                   visualisationLayout
            SplitView.fillHeight: true
            // anchors.fill: parent
            Layout.fillHeight: true
            Layout.fillWidth:  true
            rowSpacing: 0
            columnSpacing: 0
            rows    : mainview.width > mainview.height ? 1 : 2
            columns : mainview.width > mainview.height ? 2 : 1

            property int lastKeyPressed: Qt.Key_unknown

            Keys.onPressed: {
                visualisationLayout.lastKeyPressed = event.key;
            }

            Keys.onReleased: {
                visualisationLayout.lastKeyPressed = Qt.Key_unknown;
            }

            GraphicsScene3dView {
                id:                renderer
                visible: menuBar.is3DVisible
                objectName: "GraphicsScene3dView"
                Layout.fillHeight: true
                Layout.fillWidth:  true
                focus:             true

                property bool longPressTriggered: false

                KWaitProgressBar{
                    id:        surfaceProcessingProgressBar
                    objectName: "surfaceProcessingProgressBar"
                    text:      qsTr("Calculating surface\nPlease wait...")
                    textColor: "white"
                    visible:   false
                }

                KWaitProgressBar{
                    id:        sideScanProcessingProgressBar
                    objectName: "sideScanProcessingProgressBar"
                    text:      qsTr("Calculating mosaic\nPlease wait...")
                    textColor: "white"
                    visible:  core.isMosaicUpdatingInThread && core.isSideScanPerformanceMode
                }

                PinchArea {
                    id:           pinch3D
                    anchors.fill: parent
                    enabled:      true

                    onPinchStarted: {
                        menuBlock.visible = false
                        mousearea3D.enabled = false
                    }

                    onPinchUpdated: {
                        var shiftScale = pinch.scale - pinch.previousScale;
                        var shiftAngle = pinch.angle - pinch.previousAngle;
                        renderer.pinchTrigger(pinch.previousCenter, pinch.center, shiftScale, shiftAngle)
                    }

                    onPinchFinished: {
                        mousearea3D.enabled = true
                    }

                    MouseArea {
                        id: mousearea3D
                        enabled:              true
                        anchors.fill:         parent
                        acceptedButtons:      Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        focus:                true
                        hoverEnabled:         true
                        Keys.enabled:         true
                        Keys.onDeletePressed: renderer.keyPressTrigger(event.key)

                        property int lastMouseKeyPressed: Qt.NoButton // TODO: maybe this mouseArea should be outside pinchArea
                        property point startMousePos: Qt.point(-1, -1)
                        property bool wasMoved: false
                        property real mouseThreshold: 15
                        property bool vertexMode: false

                        onEntered: {
                            mousearea3D.forceActiveFocus();
                        }

                        onWheel: {
                            renderer.mouseWheelTrigger(wheel.buttons, wheel.x, wheel.y, wheel.angleDelta, visualisationLayout.lastKeyPressed)
                        }

                        onPositionChanged: {
                            if (Qt.platform.os === "android") {
                                if (!wasMoved) {
                                    var delta = Math.sqrt(Math.pow((mouse.x - startMousePos.x), 2) + Math.pow((mouse.y - startMousePos.y), 2));
                                    if (delta > mouseThreshold) {
                                        wasMoved = true;
                                    }
                                }
                                if (renderer.longPressTriggered && !wasMoved) {
                                    if (!vertexMode) {
                                        renderer.switchToBottomTrackVertexComboSelectionMode(mouse.x, mouse.y)
                                    }
                                    vertexMode = true
                                }
                            }

                            renderer.mouseMoveTrigger(mouse.buttons, mouse.x, mouse.y, visualisationLayout.lastKeyPressed)
                        }

                        onPressed: {
                            menuBlock.visible = false
                            startMousePos = Qt.point(mouse.x, mouse.y)
                            wasMoved = false
                            vertexMode = false
                            longPressTimer.start()
                            renderer.longPressTriggered = false

                            lastMouseKeyPressed = mouse.buttons
                            renderer.mousePressTrigger(mouse.buttons, mouse.x, mouse.y, visualisationLayout.lastKeyPressed)
                        }

                        onReleased: {
                            startMousePos = Qt.point(-1, -1)
                            wasMoved = false
                            longPressTimer.stop()

                            renderer.mouseReleaseTrigger(lastMouseKeyPressed, mouse.x, mouse.y, visualisationLayout.lastKeyPressed)

                            if (mouse.button === Qt.RightButton || (Qt.platform.os === "android" && vertexMode)) {
                                menuBlock.position(mouse.x, mouse.y)
                            }

                            vertexMode = false

                            lastMouseKeyPressed = Qt.NoButton
                        }

                        onCanceled: {
                            startMousePos = Qt.point(-1, -1)
                            wasMoved = false
                            vertexMode = false
                            longPressTimer.stop()
                        }
                    }
                }

                Timer {
                    id: longPressTimer
                    interval: 500 // ms
                    repeat: false

                    onTriggered: {
                        renderer.longPressTriggered = true
                    }
                }

                Scene3DToolbar{
                    id:                       scene3DToolbar
                    // anchors.bottom:              parent.bottom
                    y:renderer.height - height - 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    // anchors.rightMargin:      20
                    Keys.forwardTo:           [mousearea3D]
                }

                CContact {
                    id: contactDialog
                    visible: false
                    offsetOpacityArea: 20 // increase in 3D

                    onInputAccepted: {
                        contacts.setContact(contactDialog.indx, contactDialog.inputFieldText)
                    }
                    onSetButtonClicked: {
                        contacts.setContact(contactDialog.indx, contactDialog.inputFieldText)
                    }
                    onDeleteButtonClicked: {
                        contacts.deleteContact(contactDialog.indx)
                    }
                    onCopyButtonClicked: {
                        contacts.update()
                    }
                }

                Connections {
                    id: contactConnections
                    target: null // contacts will init later
                    function onContactChanged() {
                        contactDialog.visible = contacts.contactVisible
                        if (contacts.contactVisible) {
                            contactDialog.info           = contacts.contactInfo
                            contactDialog.inputFieldText = contacts.contactInfo
                            contactDialog.x              = contacts.contactPositionX
                            contactDialog.y              = contacts.contactPositionY
                            contactDialog.indx           = contacts.contactIndx
                            contactDialog.lat            = contacts.contactLat
                            contactDialog.lon            = contacts.contactLon
                            contactDialog.depth          = contacts.contactDepth
                        }
                    }
                }

                RowLayout {
                    id: menuBlock
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 1
                    visible: false
                    Layout.margins: 0

                    function position(mx, my) {
                        var oy = renderer.height - (my + implicitHeight)
                        if (oy < 0) {
                            my = my + oy
                        }
                        if (my < 0) {
                            my = 0
                        }
                        var ox = renderer.width - (mx - implicitWidth)
                        if (ox < 0) {
                            mx = mx + ox
                        }
                        x = mx
                        y = my
                        visible = true
                    }

                    ButtonGroup { id: pencilbuttonGroup }

                    CheckButton {
                        icon.source: "./icons/arrow-bar-to-down.svg"
                        backColor: theme.controlBackColor
                        checkable: false
                        implicitWidth: theme.controlHeight

                        onClicked: {
                            renderer.bottomTrackActionEvent(BottomTrack.MinDistProc)
                            menuBlock.visible = false
                        }

                        ButtonGroup.group: pencilbuttonGroup
                    }

                    CheckButton {
                        icon.source: "./icons/arrow-bar-to-up.svg"
                        backColor: theme.controlBackColor
                        checkable: false
                        implicitWidth: theme.controlHeight

                        onClicked: {
                            renderer.bottomTrackActionEvent(BottomTrack.MaxDistProc)
                            menuBlock.visible = false
                        }

                        ButtonGroup.group: pencilbuttonGroup
                    }

                    CheckButton {
                        icon.source: "./icons/eraser.svg"
                        backColor: theme.controlBackColor
                        checkable: false
                        implicitWidth: theme.controlHeight

                        onClicked: {
                            renderer.bottomTrackActionEvent(BottomTrack.ClearDistProc)
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
                            renderer.bottomTrackActionEvent(BottomTrack.Undefined)

                            menuBlock.visible = false
                        }

                        ButtonGroup.group: pencilbuttonGroup
                    }
                }
            }


            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true
                visible: menuBar.is2DVisible

                GridLayout {
                    anchors.fill: parent
                    rows    : 2
                    columns : 1
                    columnSpacing: 0
                    rowSpacing: 0

                    Plot2D {
                        id: waterView
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.margins: 0

                        Layout.rowSpan   : 1
                        Layout.columnSpan: 1
                        focus: true
                        horizontal: menuBar.is2DHorizontal


                    }

                    // Plot2D {
                    //     id: waterView1

                    //     Layout.fillHeight: true
                    //     Layout.fillWidth: true

                    //     Layout.rowSpan   : 1
                    //     Layout.columnSpan: 1
                    //     focus: true
                    //     horizontal: menuBar.is2DHorizontal
                    // }

                    CSlider {
                        id: historyScroll
                        //TAV - hide
                        visible: false
                        Layout.margins: 0
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.columnSpan: parent.columns
                        implicitHeight: theme.controlHeight
                        height: theme.controlHeight
                        value: waterView.timelinePosition
                        stepSize: 0.0001
                        from: 0
                        to: 1

                        onValueChanged: {
                            core.setTimelinePosition(value);
                        }
                        onMoved: {
                            core.resetAim();
                        }
                    }
                }
            }
        }

        Console {
            id:                      console_vis
            visible:                 theme.consoleVisible
            SplitView.minimumHeight: 150
            SplitView.maximumHeight: mainview.height - theme.controlHeight/2 - theme.controlHeight
        }
    }

    MenuFrame {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        //Do we need this?
        //visible: (deviceManagerWrapper.pilotArmState >= 0) && !showBanner
        visible: false
        isDraggable: true
        isOpacityControlled: true
        Keys.forwardTo: [splitLayer]

        ColumnLayout {
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                CheckButton {
                    // text: checked ? "Armed" : "Disarmed"
                    icon.source: checked ? "./icons/propeller.svg" : "./icons/propeller-off.svg"
                    checked: deviceManagerWrapper.pilotArmState == 1
                    color: "white"
                    backColor: "red"
                    // checkedColor: "white"
                    // checkedBackColor: "transparent"
                    borderColor: "transparent"
                    checkedBorderColor: theme.textColor
                    implicitWidth: theme.controlHeight
                }

                ButtonGroup { id: autopilotModeGroup }

                CheckButton {
                    // Layout.fillWidth: true
                    icon.source: "./icons/direction-arrows.svg"
                    checked: deviceManagerWrapper.pilotModeState == 0 // "Manual"
                    onCheckedChanged: {
                    }
                    ButtonGroup.group: autopilotModeGroup
                    implicitWidth: theme.controlHeight
                }

                CheckButton {
                    // Layout.fillWidth: true
                    icon.source: "./icons/route.svg"
                    checked: deviceManagerWrapper.pilotModeState == 10 // "Auto"
                    onCheckedChanged: {
                    }
                    ButtonGroup.group: autopilotModeGroup
                    implicitWidth: theme.controlHeight
                }

                CheckButton {
                    // Layout.fillWidth: true
                    icon.source: "./icons/anchor.svg"
                    checked: deviceManagerWrapper.pilotModeState == 5 // "Loiter"
                    onCheckedChanged: {
                    }
                    ButtonGroup.group: autopilotModeGroup
                    implicitWidth: theme.controlHeight
                }

                CheckButton {
                    // Layout.fillWidth: true
                    icon.source: "./icons/map-pin.svg"
                    checked: deviceManagerWrapper.pilotModeState == 15 // "Guided"
                    onCheckedChanged: {
                    }
                    ButtonGroup.group: autopilotModeGroup
                    implicitWidth: theme.controlHeight
                }

                CheckButton {
                    // Layout.fillWidth: true
                    icon.source: "./icons/home.svg"
                    checked: deviceManagerWrapper.pilotModeState == 11 || deviceManagerWrapper.pilotModeState == 12  // "RTL" || "SmartRTL"
                    onCheckedChanged: {
                    }
                    ButtonGroup.group: autopilotModeGroup
                    implicitWidth: theme.controlHeight
                }

                // CCombo  {
                //     id: pilotModeState
                //     visible: deviceManagerWrapper.pilotModeState >= 0
                //     model: [
                //         "Manual",
                //         "Acro",
                //         "Steering",
                //         "Hold",
                //         "Loiter",
                //         "Follow",
                //         "Simple",
                //         "Dock",
                //         "Circle",
                //         "Auto",
                //         "RTL",
                //         "SmartRTL",
                //         "Guided",
                //         "Mode16",
                //         "Mode17"
                //     ]
                //     currentIndex: deviceManagerWrapper.pilotModeState

                //     onCurrentIndexChanged: {
                //         if(currentIndex != deviceManagerWrapper.pilotModeState) {
                //             currentIndex = deviceManagerWrapper.pilotModeState
                //         }
                //     }
            }

            RowLayout {
                CText {
                    id: fcTextBatt
                    // Layout.margins: 4
                    visible: isFinite(deviceManagerWrapper.vruVoltage)
                    rightPadding: 4
                    leftPadding: 4
                    text: deviceManagerWrapper.vruVoltage.toFixed(1) + qsTr(" V   ") + deviceManagerWrapper.vruCurrent.toFixed(1) + qsTr(" A   ") + deviceManagerWrapper.vruVelocityH.toFixed(2) + qsTr(" m/s ")
                }
                CText {
                    id: errText
                    //visible: isFinite(deviceManagerWrapper.vruVoltage)
                    rightPadding: 4
                    leftPadding: 4
                    text: deviceManagerWrapper.averageChartLosses + qsTr(" %")
                }
            }
        }
    }

    MenuBar {
        id:                menuBar
        objectName:        "menuBar"
        Layout.fillHeight: true
        Keys.forwardTo:    [splitLayer, mousearea3D]
        height: visualisationLayout.height
        targetPlot: waterView
        //Do we really need this
        visible: !showBanner
    }

    function handleChildSignal(langStr) {
        mainview.showBanner = true
        selectedLanguageStr = langStr
    }

    Connections {
        target: SurfaceControlMenuController ? SurfaceControlMenuController : undefined

        function onSurfaceProcessorTaskStarted() {
            surfaceProcessingProgressBar.visible = true
        }

        function onSurfaceProcessorTaskFinished() {
            surfaceProcessingProgressBar.visible = false
        }
    }

    // banner on file opening
    Rectangle {
        id: fileOpeningOverlay
        color: theme.controlBackColor
        opacity: 0.8
        radius: 10
        anchors.centerIn: parent
        //Do we need this?
        visible: core.isFileOpening && !core.isSeparateReading
        //visible: false
        implicitWidth: textItem.implicitWidth + 40
        implicitHeight: textItem.implicitHeight + 40

        Column {
            anchors.centerIn: parent
            spacing: 10

            Text {
                id: textItem
                text: qsTr("Please wait until file is opened")
                color: "white"
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }


    Rectangle {
        id: hideBackground
        anchors.fill: parent
        color: "gray"
        opacity: 0.8
        visible: mainview.windowShadow

        Image {
                anchors.fill: parent
                source: "./icons/patternDots.svg"
                fillMode: Image.Tile
                opacity: 0.8
            }

    }

    // Echogram speed change indication

    Rectangle {
        id: zoomIndicator
        // start hidden
        visible: false

        // position in the top-center with a bit of margin
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 20

        // styling: semi-transparent black, rounded corners
        color: "#80000000"
        //opacity: 0.6
        radius: 8

        // padding around the text
        property int contentMargin: 12

        // size to fit the text + padding
        implicitWidth: zoomText.width + contentMargin*2
        implicitHeight: zoomText.height + contentMargin*2

        // the actual label
        Text {
            id: zoomText
            text: "Horizontal zoom: " + pulseRuntimeSettings.echogramSpeed
            font.pixelSize: 40
            color: "white"
            anchors.centerIn: parent
        }

        // timer to hide 1 s after last speed change
        Timer {
            id: hideTimer
            interval: 1500
            repeat: false
            onTriggered: zoomIndicator.visible = false
        }

        // whenever the speed changes, update text, show, and restart timer
        Connections {
            target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
            function onEchogramSpeedChanged () {
                zoomText.text = "Horizontal zoom: " + pulseRuntimeSettings.echogramSpeed
                zoomIndicator.visible = true
                hideTimer.restart()
            }
        }
    }




    // echosounder selector Screen
    Rectangle {
        id: echoSounderSelectorRect
        width: 1000
        height: 350
        anchors.centerIn: parent
        color: "transparent"

        // These properties control which item was selected.
        property bool selectionMade: false
        property string selectedDevice: ""

        Connections {
            target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
            function onSwapDeviceNowChanged () {
                if (pulseRuntimeSettings.swapDeviceNow) {
                    console.log("DEV_RESELECT initialize in main")

                    // 1) Bring the container back
                    echoSounderSelectorRect.visible = true
                    echoSounderSelectorRect.opacity = 1

                    // 2) Reset your “selected” state so you go back to the default layout
                    echoSounderSelectorRect.selectionMade   = false
                    echoSounderSelectorRect.selectedDevice  = ""

                    // 3) Make sure both choices are shown again
                    pulseRedSelector.visible  = true
                    pulseBlueSelector.visible = true

                    // 4) (Optional) Clear any lingering state assignment
                    echoSounderSelectorRect.state = ""

                    // 5) If you only fire on the transition to ‘true’, turn it back off
                    //pulseRuntimeSettings.swapDeviceNow = false

                    // and put back your shadow, etc.
                    pulseRuntimeSettings.devManualSelected = false
                    mainview.windowShadow = true

                    console.log("DEV_RESELECT now we want to re-select the device in main")
                }
            }

            function onDevManualSelectedChanged() {
                if (pulseRuntimeSettings.devManualSelected) {
                    mainview.windowShadow = false
                } else {
                    //console.log("TAV: echoSounderSelector onDevManualSelectedChanged false, skip");
                }
            }
            function onDevConfiguredChanged() {
                if (pulseRuntimeSettings.devConfigured) {
                    echoSounderSelectorRect.selectedDevice = pulseRuntimeSettings.userManualSetName
                    echoSounderSelectorRect.selectionMade = true
                    mainview.windowShadow = false
                }
            }
            function onHasDeviceLostConnectionChanged() {
                if (pulseRuntimeSettings.didEverReceiveData) {
                    //console.log("TAV: hasDeviceLostConnection");
                    if (pulseRuntimeSettings.hasDeviceLostConnection) {
                        //console.log("TAV: hasDeviceLostConnection, show alert");
                        showLostConnection()
                    } else {
                        //console.log("TAV: hasDeviceLostConnection, remove alert");
                        removeLostConnection()
                        pulseRuntimeSettings.hasDeviceLostConnection = false
                    }
                }
            }
            function onNumberOfDatasetChannelsChanged () {
                if (pulseRuntimeSettings.swapDeviceNow) {
                    return
                }

                let detectedModel = "";
                if (pulseRuntimeSettings.numberOfDatasetChannels === 1) {
                    detectedModel = pulseRuntimeSettings.modelPulseRed
                    if (pulseRuntimeSettings.devName === "ECHO20") {
                        pulseRuntimeSettings.pulseBetaName = pulseRuntimeSettings.pulseRedBeta
                    }
                } else if (pulseRuntimeSettings.numberOfDatasetChannels === 2) {
                    detectedModel = pulseRuntimeSettings.modelPulseBlue
                    if (pulseRuntimeSettings.devName === "ECHO20") {
                        pulseRuntimeSettings.pulseBetaName = pulseRuntimeSettings.pulseBlueBeta
                    }
                }
                if (pulseRuntimeSettings.numberOfDatasetChannels > 0) {
                    pulseRuntimeSettings.userManualSetName = detectedModel
                    echoSounderSelectorRect.selectedDevice = detectedModel
                    echoSounderSelectorRect.selectionMade = true
                    pulseRuntimeSettings.devManualSelected = true
                    console.log("DEV_PARAM: Automatically detected device and set pulseRuntimeSettings.userManualSetName to", pulseRuntimeSettings.userManualSetName)
                } else {
                    console.log("DEV_PARAM: onNumberOfDatasetChannelsChanged, but channels are 0 so nothing happened")
                }
            }
        }

        Connections {
            target: dataset ? dataset : undefined

            function onDataUpdate () {
                if (lostConnectionAlert !== null && pulseRuntimeSettings.hasDeviceLostConnection) {
                    pulseRuntimeSettings.hasDeviceLostConnection = false
                    pulseRuntimeSettings.isReceivingData = true
                    //console.log("TAV: got data update when hasDeviceLostConnection, remove alert");
                    removeLostConnection()
                }
                //Mark that data is flowing
                pulseRuntimeSettings.dataUpdateActive = true

                // If this is the very first update of this “session”, record it:
                if (pulseRuntimeSettings.firstDataTs === 0) {
                    pulseRuntimeSettings.firstDataTs = Date.now()
                    pulseRuntimeSettings.guardActive = true
                    guardTimer.restart()
                    console.log("DATAFLOW: First data observed @ " + pulseRuntimeSettings.firstDataTs + ", guard window started")
                }

                //Every time data arrives, cancel any pending stale-trigger
                dataStaleTimer.restart()
                //Cancel the “reset” (we’re not in stale yet)
                resetTimer.stop()
            }
        }

        Timer {
            id: dataStaleTimer
            interval: pulseRuntimeSettings.dataIsStaleElapseTime
            repeat: false
            onTriggered: {
                console.log("DATAFLOW: Stale data detected ")
                pulseRuntimeSettings.dataUpdateActive = false
                // If we’re still inside our initial window, reboot:
                if (pulseRuntimeSettings.guardActive) {
                    console.log("DATAFLOW: Auto-reboot (data became stale within guard window)")
                    pulseRuntimeSettings.echoSounderReboot = true
                    pulseRuntimeSettings.guardActive = false
                    pulseRuntimeSettings.firstDataTs = 0
                }
                // Start/reset the resetTimer so we clear firstDataTs after resetWindowMs
                resetTimer.restart()
            }
        }

        Timer {
            id: guardTimer
            interval: pulseRuntimeSettings.rebootWindowMs
            repeat: false
            onTriggered: {
                // Window elapsed, stop guarding (no more auto-reboots this session)
                console.log("DATAFLOW: Guard window elapsed, safe to turn the dataflow guard off")
                pulseRuntimeSettings.guardActive = false
            }
        }

        Timer {
            id: resetTimer
            interval: pulseRuntimeSettings.resetWindowMs
            repeat: false
            onTriggered: {
                // Enough time has passed without data → clear our “firstDataTs” so
                pulseRuntimeSettings.firstDataTs = 0
                console.log("DATAFLOW: Resetting firstDataTs; ready for new session")
            }
        }


        Item {
            id: freeContainer
            width: 1000; height: 800
            anchors.centerIn: parent
            property int spacing: 100
            property int center: 550

            EchoSounderSelector {
                id: pulseRedSelector
                width: 450
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                backgroundColor: "#ffe0e0"   // light red background
                title: "PULSEred"
                titleColor: "red"
                description: "High-performance 2D echo sounder"
                illustrationSource: "./image/PulseRedForApp.jpg"
                onVisibleChanged: {
                    console.log("DEV_SELECTION: pulseRedSelector visible?", visible)
                    console.log("DEV_SELECTION: pulseRedSelector visible? echoSounderSelectorRect.selectedDevice", echoSounderSelectorRect.selectedDevice)
                    console.log("DEV_SELECTION: pulseRedSelector visible? echoSounderSelectorRect.selectionMade", echoSounderSelectorRect.selectionMade)

                }
                onSelected: {
                    pulseRuntimeSettings.userManualSetName = pulseRuntimeSettings.modelPulseRed
                    echoSounderSelectorRect.selectedDevice = pulseRuntimeSettings.modelPulseRed
                    echoSounderSelectorRect.selectionMade = true
                    pulseRuntimeSettings.devManualSelected = true
                    console.log("DEV_SELECTION: selected", echoSounderSelectorRect.selectedDevice)
                }
            }

            EchoSounderSelector {
                id: pulseBlueSelector
                width: 450
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                backgroundColor: "#e0e0ff"   // light blue background
                title: "PULSEblue"
                titleColor: "blue"
                description: "High-performance side-scan echo sounder"
                //illustrationSource: "./image/PulseBlueImage400.png"
                illustrationSource: "./image/PulseBlueForApp.jpg"
                //versions: ["v1.0"]
                //version: "v1.0"
                onVisibleChanged: {
                    console.log("DEV_SELECTION: pulseBlueSelector visible?", visible)
                    console.log("DEV_SELECTION: pulseBlueSelector visible? echoSounderSelectorRect.selectedDevice", echoSounderSelectorRect.selectedDevice)
                    console.log("DEV_SELECTION: pulseBlueSelector visible? echoSounderSelectorRect.selectionMade", echoSounderSelectorRect.selectionMade)
                }

                onSelected: {
                    pulseRuntimeSettings.userManualSetName = pulseRuntimeSettings.modelPulseBlue
                    echoSounderSelectorRect.selectedDevice = pulseRuntimeSettings.modelPulseBlue
                    echoSounderSelectorRect.selectionMade = true
                    pulseRuntimeSettings.devManualSelected = true
                    console.log("DEV_SELECTION: selected", echoSounderSelectorRect.selectedDevice)
                }
            }
        }


        // Define states for when a selection has been made.
        states: [
            State {
                name: "selectedRed"
                when: echoSounderSelectorRect.selectionMade && echoSounderSelectorRect.selectedDevice === pulseRuntimeSettings.modelPulseRed
                // Hide the blue selector.
                PropertyChanges {
                    target: pulseBlueSelector ? pulseBlueSelector : undefined
                    visible: false
                }
                // Re-anchor pulseRedSelector to the center.
                PropertyChanges {
                    target: pulseRedSelector ? pulseRedSelector : undefined
                    // center it exactly
                    x: (freeContainer.width - pulseRedSelector.width)/2
                    y: (freeContainer.height - pulseRedSelector.height)/2
                }
            },
            State {
                name: "selectedBlue"
                when: echoSounderSelectorRect.selectionMade && echoSounderSelectorRect.selectedDevice === pulseRuntimeSettings.modelPulseBlue
                PropertyChanges {
                    target: pulseRedSelector ? pulseRedSelector : undefined
                    visible: false }
                PropertyChanges {
                    target: pulseBlueSelector ? pulseBlueSelector : undefined
                    // center it exactly
                    x: (freeContainer.width - pulseRedSelector.width)/2
                    y: (freeContainer.height - pulseRedSelector.height)/2
                }
            }
        ]

        // Animate the movement of the selected item to the center.
        transitions: [
            Transition {
                from: ""; to: "selectedRed"
                NumberAnimation {
                    target: pulseRedSelector ? pulseRedSelector : undefined
                    properties: "x,y";
                    duration: 1500;
                    easing.type: Easing.InOutQuad
                }
            },
            Transition {
                from: ""; to: "selectedBlue"
                NumberAnimation {
                    target: pulseBlueSelector ? pulseBlueSelector : undefined
                    properties: "x,y";
                    duration: 1500;
                    easing.type: Easing.InOutQuad
                }
            }

        ]


        // After the glow effect, fade out the entire container.
        SequentialAnimation on opacity {
            // Start when a selection has been made.
            running: echoSounderSelectorRect.selectionMade
            // Wait for the glow animation to complete.
            PauseAnimation { duration: 2000 }
            NumberAnimation { from: 1; to: 0; duration: 1000 }
            PauseAnimation { duration: 500 }
            ScriptAction {
                script: {
                    //echoSounderSelector.visible = false;
                    //pulseRuntimeSettings.devManualSelected = true;
                    pulseRedSelector.visible = false;
                    pulseBlueSelector.visible = false;
                    echoSounderSelectorRect.visible = false;
                }
            }
        }
    }

}
