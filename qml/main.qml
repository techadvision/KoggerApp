import QtQuick 2.15
import SceneGraphRendering 1.0
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import QtQuick.Controls 2.15
import WaterFall 1.0
//import KoggerCommon 1.0
//import QtGraphicalEffects 1.15
import BottomTrack 1.0
import QtCore
import Echo.UI 1.0
import QtQuick.Window


ApplicationWindow  {
    id:            mainview
    visible:       true
    width:         1280 // 21:9
    minimumWidth:  640
    height:        540
    minimumHeight: 272
    color:         "black"
    title:         qsTr("Pulse, TechAdVision")

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

    header: Item {
        Behavior on height { NumberAnimation { duration: 500 } }
        height: insetTop()        // <- no ReferenceError on Windows
        //height: Insets.dexEnabled ? Insets.top : 0
    }

    readonly property int _rightBarWidth:                360
    readonly property int _activeObjectParamsMenuHeight: 500
    readonly property int _sceneObjectsListHeight:       300

    property bool windowShadow: false
    property var lostConnectionAlert: null

    Settings {
            id: appSettings
            property bool isFullScreen: false
            property real sceneSplitRatio: 0.5
            //property int savedX: 100
            //property int savedY: 100
    }

    function setFullScreenMode(enabled) {
        appSettings.isFullScreen = enabled
        if (enabled) {
            mainview.showFullScreen()
        }
        else {
            mainview.showNormal()
        }
    }

    Connections {
        target: pulseRuntimeSettings
        //User interface automated control and optional settings
        function onIsSideScanLeftHandChanged()      { settingsBus.updateRuntime({ isSideScanLeftHand:       pulseRuntimeSettings.isSideScanLeftHand         }) }
        function onIsSideScan2DViewChanged()        { settingsBus.updateRuntime({ isSideScan2DView:         pulseRuntimeSettings.isSideScan2DView           }) }
        function onEchogramSpeedChanged()           { settingsBus.updateRuntime({ echogramSpeed:            pulseRuntimeSettings.echogramSpeed              }) }
        function onIs2DTransducerChanged()          { settingsBus.updateRuntime({ is2DTransducer:           pulseRuntimeSettings.is2DTransducer             }) }
        function onShouldDoAutoRangeChanged()       { settingsBus.updateRuntime({ shouldDoAutoRange:        pulseRuntimeSettings.shouldDoAutoRange          }) }
        function onAutoDepthMaxLevelChanged()       { settingsBus.updateRuntime({ autoDepthMaxLevel:        pulseRuntimeSettings.autoDepthMaxLevel          }) }
        function onMaximumDepthChanged()            { settingsBus.updateRuntime({ maximumDepth:             pulseRuntimeSettings.maximumDepth               }) }
        function onIsHorizontalGridChanged()        { settingsBus.updateRuntime({ isHorizontalGrid:         pulseRuntimeSettings.isHorizontalGrid           }) }
        function onUseMetricDepthChanged()          { settingsBus.updateRuntime({ useMetricDepth:           pulseRuntimeSettings.useMetricDepth             }) }
        //function onAutoDepthMaxLevelChanged()       { settingsBus.updateRuntime({ autoRange:                pulseRuntimeSettings.autoDepthMaxLevel          }) }
        //Note: The onAutoDepthMaxLevelChanged above was initialluy onautoDepthMaxLevelChanged (ona..., non existing. May influence some missing behavior
        //Bottom track
        //function onUpdateBottomTrackChanged()       { settingsBus.updateRuntime({ updateBottomTrack:        pulseRuntimeSettings.updateBottomTrack          }) }
        function onIsBottomTrackInitiatedChanged()  { settingsBus.updateRuntime({ isBottomTrackInitiated:   pulseRuntimeSettings.isBottomTrackInitiated     }) }
        //Play/Pause echogram
        function onEchogramPauseChanged()           { settingsBus.updateRuntime({ echogramPause:            pulseRuntimeSettings.echogramPause              }) }
        //App is ready configured, ensure C++ values are up to date:
        function onUserManualSetNameChanged () {
            if (pulseRuntimeSettings.userManualSetName === "...")
                return
            pulseSettings.nmeaBroadcastAddress = pulseRuntimeSettings.nmeaBroadcastAddress
            let shouldBroadcastMtw = pulseSettings.enableNmeaMtw && pulseRuntimeSettings.is2DTransducer
            //Enable bottomTrack for red/blue if the user is an expert
            if (pulseRuntimeSettings.expertMode && pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                pulseRuntimeSettings.processBottomTrack = true
            }

            settingsBus.updatePersistent({
                    filterRealValue:         pulseSettings.filterRealValue,
                    intensityRealValue:      pulseSettings.intensityRealValue,
                    colorMapIndexReal:       pulseSettings.colorMapIndexReal,
                    // NMEA
                    enableNmeaDbt:           pulseSettings.enableNmeaDbt,
                    enableNmeaMtw:           shouldBroadcastMtw,
                    nmeaPort:                pulseSettings.nmeaPort,
                    nmeaSendPerMilliSec:     pulseSettings.nmeaSendPerMilliSec,
                    nmeaTempPeriodMs:        pulseSettings.nmeaTempPeriodMs,
                    nmeaBroadcastAddress:    pulseSettings.nmeaBroadcastAddress
                })
            pulseRuntimeSettings.isSideScanLeftHand = pulseSettings.isSideScanOnLeftHandSide
            settingsBus.updateRuntime({
                    isSideScanLeftHand:       pulseRuntimeSettings.isSideScanLeftHand,
                    isSideScan2DView:         pulseRuntimeSettings.isSideScan2DView,
                    echogramSpeed:            pulseRuntimeSettings.echogramSpeed,
                    is2DTransducer:           pulseRuntimeSettings.is2DTransducer,
                    shouldDoAutoRange:        pulseRuntimeSettings.shouldDoAutoRange,
                    autoDepthMaxLevel:        pulseRuntimeSettings.autoDepthMaxLevel,
                    maximumDepth:             pulseRuntimeSettings.maximumDepth,
                    isHorizontalGrid:         pulseRuntimeSettings.isHorizontalGrid,
                    useMetricDepth:           pulseRuntimeSettings.useMetricDepth,
                    //uuidIpGateway:            pulseRuntimeSettings.uuidIpGateway,
                    //uuidUsbSerial:            pulseRuntimeSettings.uuidUsbSerial,
                    updateBottomTrack:        pulseRuntimeSettings.updateBottomTrack,
                    isBottomTrackInitiated:   pulseRuntimeSettings.isBottomTrackInitiated
                })
            //Temperature
            if (pulseRuntimeSettings.useTemperature) {
                dataset.setTemperatureCorrection(pulseRuntimeSettings.temperatureCorrection)
            }
            //Other stuff
            dataset.setTransducerOffsetMount(pulseSettings.transducerOffsetMount)
            if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue ||
                    pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlueProto) {
                pulseRuntimeSettings.echogramSpeed = 1
            }


        }
        function onUuidSuccessfullyOpenedChanged () {
            console.log("LinkManager: main.qml onUuidSuccessfullyOpenedChanged new value", pulseRuntimeSettings.uuidSuccessfullyOpened)
        }
        function onUuidUsbSerialChanged () {
            console.log("LinkManager: main.qml onUuidUsbSerialChanged new value", pulseRuntimeSettings.uuidUsbSerial)
        }
        function onUuidIpGatewayChanged () {
            console.log("LinkManager: main.qml onUuidIpGatewayChanged new value", pulseRuntimeSettings.uuidIpGateway)
        }

    }

    Connections {
        target: pulseSettings   // <-- note lowercase
        //User interface
        function onFilterRealValueChanged()         { settingsBus.updatePersistent({ filterRealValue:       pulseSettings.filterRealValue       }) }
        function onIntensityRealValueChanged()      { settingsBus.updatePersistent({ intensityRealValue:    pulseSettings.intensityRealValue    }) }
        function onColorMapIndexRealChanged()       { settingsBus.updatePersistent({ colorMapIndexReal:     pulseSettings.colorMapIndexReal     }) }
        //Transducer interface
        function onUdpGatewayChanged()              { settingsBus.updatePersistent({ udpGateway:            pulseSettings.udpGateway            }) }
        function onUdpPortChanged()                 { settingsBus.updatePersistent({ udpPort:               pulseSettings.udpPort               }) }
        function onUsbSerialBaudChanged()           { settingsBus.updatePersistent({ usbSerialBaud:         pulseSettings.usbSerialBaud         }) }
        //Special user privilidges
        function onIsBetaTesterChanged()            { settingsBus.updatePersistent({ isBetaTester:          pulseSettings.isBetaTester          }) }
        function onIsExpertChanged()                { settingsBus.updatePersistent({ isExpert:              pulseSettings.isExpert              }) }
        //NMEA
        function onEnableNmeaDbtChanged()           { settingsBus.updatePersistent({ enableNmeaDbt:         pulseSettings.enableNmeaDbt         }) }
        function onEnableNmeaMtwChanged()           { settingsBus.updatePersistent({ enableNmeaMtw:         pulseSettings.enableNmeaMtw         }) }
        function onNmeaPortChanged()                { settingsBus.updatePersistent({ nmeaPort:              pulseSettings.nmeaPort              }) }
        function onNmeaSendPerMilliSecChanged()     { settingsBus.updatePersistent({ nmeaSendPerMilliSec:   pulseSettings.nmeaSendPerMilliSec   }) }
        function onNmeaTempPeriodMsChanged()        { settingsBus.updatePersistent({ nmeaTempPeriodMs:      pulseSettings.nmeaTempPeriodMs      }) }
        function onNmeaBroadcastAddressChanged()    { settingsBus.updatePersistent({ nmeaBroadcastAddress:  pulseSettings.nmeaBroadcastAddress  }) }
        //Echogram speed moved to the persistent settings, workaround to keep the runtime integration as is:
        function onEchogramSpeedChanged ()          { pulseRuntimeSettings.echogramSpeed = pulseSettings.echogramSpeed                             }
        function onAutoRangeChanged ()              { pulseRuntimeSettings.shouldDoAutoRange = pulseSettings.autoRange                             }
        //function onUsbSerialBaudChanged ()          { pulseRuntimeSettings.usbSerialBaud = pulseSettings.usbSerialBaud                             }
    }

    Connections {
        target: settingsBus
        function onRuntimeChanged(m) {
            //dumpMap("settingsBus.runtimeChanged", m)
            for (var k in m) {
                if (k in pulseRuntimeSettings) {
                    pulseRuntimeSettings[k] = m[k]
                    //console.log("applied -> pulseRuntimeSettings." + k, "=", toStr(m[k]))
                } else {
                    console.warn("IGNORED runtime key (no such property):", k, "=", toStr(m[k]))
                }
            }
        }

        function onPersistentChanged(m) {
            //dumpMap("settingsBus.persistentChanged", m)
            for (var k in m) {
                if (k in pulseSettings) {
                    pulseSettings[k] = m[k]
                    //console.log("applied -> pulseSettings." + k, "=", toStr(m[k]))
                } else {
                    console.warn("IGNORED persistent key (no such property):", k, "=", toStr(m[k]))
                }
            }
        }
    }

    function toggleFullScreenMode() {
        setFullScreenMode(mainview.visibility !== Window.FullScreen)
    }

    Connections {
        target: core ? core : undefined
        function onSendIsFileOpening() {
            //console.log("TAV main onSendIsFileOpening");
            let isFileOpening = core.getIsFileOpening()
            console.log ("FILE OPENING: isFileOpening euals", isFileOpening)
            pulseRuntimeSettings.isOpeningKlfFile = isFileOpening
            if (isFileOpening) {
                pulseRuntimeSettings.wasKlfFileOpened = true
            }
        }
    }

    function handleUpdateBottomTrack() {
        menuBar.updateBottomTrack()
    }

    function refreshAllGraphicsAfterResume() {
        if (renderer) {
            renderer.update()
            renderer.onCameraMoved()
        }

        if (waterViewFirst) {
            waterViewFirst.update()
        }

        if (waterViewSecond && waterViewSecond.visible) {
            waterViewSecond.update()
        }

        if (syncLoupePlot3D) {
            syncLoupePlot3D.update()
        }

        if (syncLoupeOverlay && syncLoupeOverlay.visible) {
            syncLoupeOverlay.refreshLoupePlot()
        }

        mainview.update()
    }

    function scheduleResumeRefreshIfNeeded() {
        if (Qt.platform.os !== "android") {
            return
        }

        if (Qt.application.state !== Qt.ApplicationActive) {
            return
        }

        // Defer refresh until window/surface is active again.
        Qt.callLater(refreshAllGraphicsAfterResume)
    }

    function handleAndroidBack() {
        if (Qt.platform.os !== "android") {
            return false
        }

        // Step 1: close modal/popup/menu overlays.
        if (profilePickDialog.visible) {
            profilePickDialog.close()
            return true
        }

        if (profilesDialog.visible) {
            profilesDialog.close()
            return true
        }

        if (showBanner) {
            showBanner = false
            return true
        }

        if (typeof contactDialog !== "undefined" && contactDialog.visible) {
            contactDialog.visible = false
            return true
        }

        if (menuBlock.visible) {
            menuBlock.visible = false
            return true
        }

        if (geoMenuBlock.visible) {
            geoMenuBlock.visible = false
            return true
        }

        if (rulerMenuBlock.visible) {
            rulerMenuBlock.visible = false
            return true
        }

        if (waterViewFirst.closeTransientUi && waterViewFirst.closeTransientUi()) {
            return true
        }

        if (waterViewSecond.visible && waterViewSecond.closeTransientUi && waterViewSecond.closeTransientUi()) {
            return true
        }

        // Step 2: cancel active editing modes.
        if (renderer.geoJsonEnabled) {
            const geo = renderer.geoJsonController
            if (geo && geo.drawing) {
                renderer.geojsonCancelDrawing()
                return true
            }
        }

        if (renderer.rulerDrawing) {
            renderer.rulerCancelDrawing()
            return true
        }

        if (renderer.rulerEnabled || renderer.rulerSelected || renderer.rulerHasGeometry) {
            renderer.clearRuler()
            return true
        }

        // Step 3: close settings panels.
        let settingsClosed = false

        if (waterViewFirst.settingsOpen) {
            waterViewFirst.closeSettings()
            settingsClosed = true
        }

        if (waterViewSecond.visible && waterViewSecond.settingsOpen) {
            waterViewSecond.closeSettings()
            settingsClosed = true
        }

        if (menuBar.hasOpenMenus) {
            menuBar.closeMenus()
            settingsClosed = true
        }

        if (settingsClosed) {
            return true
        }

        // Step 4: root screen -> send app to background.
        core.moveAppToBackground()
        return true
    }

    onVisibilityChanged: function(windowVisibility) {
        if (windowVisibility === Window.FullScreen) {
            scheduleResumeRefreshIfNeeded()
        }
    }

    Connections {
        target: Qt.application

        function onStateChanged() {
            scheduleResumeRefreshIfNeeded()
        }
    }

    onWidthChanged:  Ui.windowWidth  = width
    onHeightChanged: Ui.windowHeight = height

    Component.onCompleted: {
        Ui.windowWidth = width
        Ui.windowHeight = height
        pulseRuntimeSettings.isSideScanLeftHand = pulseSettings.isSideScanOnLeftHandSide
        pulseRuntimeSettings.echogramSpeed = pulseSettings.echogramSpeed
        var code     = pulseSettings.keyCode
        var isBeta   = pulseRuntimeSettings.betaKeyCodes.indexOf(code)   !== -1
        var isExpert = pulseRuntimeSettings.expertKeyCodes.indexOf(code) !== -1
        var saltMatches  = (pulseSettings.validateSalt === installToken.currentSalt)
        if (!saltMatches && (isBeta || isExpert)) {
            isBeta = false
            isExpert = false
            pulseSettings.keyCode = "not_set"
            pulseSettings.validateSalt = ""
        }
        pulseRuntimeSettings.expertMode = isExpert
        pulseRuntimeSettings.betaMode   = isExpert || isBeta
        pulseSettings.isBetaTester = isBeta
        pulseSettings.isExpert = isExpert
        console.log(
            "Key Code: component on completed: expertMode", pulseRuntimeSettings.expertMode,
            "and betaMode", pulseRuntimeSettings.betaMode,
            "and validateSalt", pulseSettings.validateSalt, "for code", pulseSettings.keyCode
        )
        settingsBus.updateRuntime({
            devName:                "..."
        })
        settingsBus.updatePersistent({
            udpGateway:              pulseSettings.udpGateway,
            udpPort:                 pulseSettings.udpPort,
            isBetaTester:            pulseSettings.isBetaTester,
            isExpert:                pulseSettings.isExpert,
            usbSerialBaud:           pulseSettings.usbSerialBaud
        })
        console.log("App start code check: code=", code, ", isBeta", isBeta, "isExpert", isExpert)
        //console.log("App start code check: pulseSettings.isBetaTester=", pulseSettings.isBetaTester, "pulseSettings.isExpert=", pulseSettings.isExpert)
        theme.updateResCoeff()

        //Important settings:

        console.log("LinkMamnager main: Let's get a snapshot from the settingsbus")

        // one-shot hydration from the bus’ current state
            var snap = settingsBus.runtimeSnapshot();
            if (snap.devName !== undefined && snap.devName !== null)
                pulseRuntimeSettings.devName = snap.devName;

            if (snap.uuidUsbSerial){
                console.log("LinkMamnager main: Snapshot uuid serial:", snap.uuidUsbSerial)
                pulseRuntimeSettings.uuidUsbSerial = snap.uuidUsbSerial;
            }
            if (snap.uuidIpGateway){
                console.log("LinkMamnager main: Snapshot uuid wifi:", snap.uuidIpGateway)
                pulseRuntimeSettings.uuidIpGateway = snap.uuidIpGateway;
            }
            if (snap.uuidSuccessfullyOpened) {
                console.log("LinkMamnager main: Snapshot uuid opened:", snap.uuidSuccessfullyOpened)
                pulseRuntimeSettings.uuidSuccessfullyOpened = snap.uuidSuccessfullyOpened;
            }

        //-------------------

        scene3DToolbar.updateBottomTrack.connect(handleUpdateBottomTrack)
        menuBar.languageChanged.connect(handleChildSignal)
        menuBar.syncPlotEnabled.connect(handleSyncPlotEnabled)
        waterViewFirst.plotCursorChanged.connect(handlePlotCursorChanged)
        waterViewSecond.plotCursorChanged.connect(handlePlotCursorChanged)
        waterViewFirst.updateOtherPlot.connect(handleUpdateOtherPlot)
        waterViewSecond.updateOtherPlot.connect(handleUpdateOtherPlot)
        waterViewFirst. plotPressed.connect(handlePlotPressed)
        waterViewSecond.plotPressed.connect(handlePlotPressed)
        waterViewFirst. plotReleased.connect(handlePlotReleased)
        waterViewSecond.plotReleased.connect(handlePlotReleased)
        waterViewFirst.settingsClicked.connect(onPlotSettingsClicked)
        waterViewSecond.settingsClicked.connect(onPlotSettingsClicked)
        menuBar.menuBarSettingOpened.connect(onMenuBarSettingsOpened)

        scene3DToolbar.mosaicLAngleOffsetChanged.connect(handleMosaicLOffsetChanged)
        scene3DToolbar.mosaicRAngleOffsetChanged.connect(handleMosaicROffsetChanged)

        if (appSettings.isFullScreen) {
            mainview.showFullScreen()
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

        settingsBus.replayRuntime()
    }

    // banner on languageChanged
    property bool showBanner: false
    property string selectedLanguageStr: qsTr("Undefined")

    function showLostConnection () {

        if (pulseRuntimeSettings.wasKlfFileOpened) {
            //console.log("TAV: showLostConnection, please do not when viewing a file");
            return
        }

        if (lostConnectionAlert === null) {
            var component = Qt.createComponent("LostConnectionOverlay.qml")
            lostConnectionAlert = component.createObject( mainview, {"x": 0, "y": 0 } )
            if (lostConnectionAlert !== null) {
                //lostConnectionAlert.anchors.centerIn = echoSounderSelectorRect
                lostConnectionAlert.anchors.bottom = overlay.anchors.bottom
                lostConnectionAlert.anchors.right = overlay.anchors.right
                lostConnectionAlert.anchors.rightMargin = mainview.insetRight() + 20
                lostConnectionAlert.anchors.bottomMargin = mainview.insetBottom() + 120
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

        onEntered: function(drag) {
            if (!showBanner) {
                draggedFilePath = ""
                if (drag.hasUrls) {
                    for (var i = 0; i < drag.urls.length; ++i) {
                        var url = drag.urls[i]
                        var localPath = url.toLocalFile ? url.toLocalFile() : ""
                        var filePath = (localPath && localPath.length ? localPath : url.toString()).toLowerCase()
                        if (filePath.endsWith(".plog") ||
                            filePath.endsWith(".xtf")) {
                            draggedFilePath = filePath
                            overlay.opacity = 0.3
                            break
                        }
                        /*
                        if (filePath.endsWith(".klf") ||
                            filePath.endsWith(".plog") ||
                            filePath.endsWith(".xtf")) {
                            draggedFilePath = filePath
                            overlay.opacity = 0.3
                            break
                        }
                        */
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

        Keys.onReleased: function(event) {
             /*
            if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
                if (handleAndroidBack()) {
                    event.accepted = true
                    return
                }
            }

            let sc = event.nativeScanCode.toString()
            let hotkeyData = hotkeysMapScan[sc];
            if (hotkeyData === undefined) {
                return
            }

            let fn = hotkeyData["functionName"];
            let p = hotkeyData["parameter"];

            // high priority
            if (fn === "toggleFullScreen") {
                toggleFullScreenMode()
                return;
            }
            if (fn === "openFile") {
                core.openLogFile(menuBar.filePath, false, false)
                return;
            }
            if (fn === "openFileDialog") {
                menuBar.openFileDialog()
                return;
            }
            if (fn === "closeFile") {
                core.closeLogFile()
                return;
            }
            if (fn === "updateBottomTrack") {
                menuBar.updateBottomTrack()
            }
            if (fn === "updateMosaic") {
                scene3DToolbar.updateMosaic()
            }
            if (fn === "closeSettings") {
                waterViewFirst.closeSettings()
                if (waterViewSecond.enabled) {
                    waterViewSecond.closeSettings()
                }
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
                    waterViewFirst.horScrollEvent(-p)
                    if (waterViewSecond.enabled) {
                        waterViewSecond.horScrollEvent(-p)
                    }
                    break
                }
                case "horScrollRight": {
                    waterViewFirst.horScrollEvent(p)
                    if (waterViewSecond.enabled) {
                        waterViewSecond.horScrollEvent(p)
                    }
                    break
                }
                case "verScrollUp": {
                    waterViewFirst.verScrollEvent(-p)
                    if (waterViewSecond.enabled) {
                        waterViewSecond.verScrollEvent(-p)
                    }
                    break
                }
                case "verScrollDown": {
                    waterViewFirst.verScrollEvent(p)
                    if (waterViewSecond.enabled) {
                        waterViewSecond.verScrollEvent(p)
                    }
                    break
                }
                case "verZoomOut": {
                    waterViewFirst.verZoomEvent(-p)
                    if (waterViewSecond.enabled) {
                        waterViewSecond.verZoomEvent(-p)
                    }
                    break
                }
                case "verZoomIn": {
                    waterViewFirst.verZoomEvent(p)
                    if (waterViewSecond.enabled) {
                        waterViewSecond.verZoomEvent(p)
                    }
                    break
                }
                case "scene3dZoomIn": {
                    if (menuBar.is3DVisible) {
                        renderer.zoomStepTrigger(1)
                    }
                    break
                }
                case "scene3dZoomOut": {
                    if (menuBar.is3DVisible) {
                        renderer.zoomStepTrigger(-1)
                    }
                    break
                }
                case "mosaicPrevTheme": {
                    if (menuBar.is3DVisible) {
                        scene3DToolbar.mosaicPrevTheme()
                    }
                    break
                }
                case "mosaicNextTheme": {
                    if (menuBar.is3DVisible) {
                        scene3DToolbar.mosaicNextTheme()
                    }
                    break
                }
                case "mosaicLowLevelUp": {
                    if (menuBar.is3DVisible) {
                        scene3DToolbar.mosaicLowLevelUp(p)
                    }
                    break
                }
                case "mosaicLowLevelDown": {
                    if (menuBar.is3DVisible) {
                        scene3DToolbar.mosaicLowLevelDown(p)
                    }
                    break
                }
                case "mosaicHighLevelUp": {
                    if (menuBar.is3DVisible) {
                        scene3DToolbar.mosaicHighLevelUp(p)
                    }
                    break
                }
                case "mosaicHighLevelDown": {
                    if (menuBar.is3DVisible) {
                        scene3DToolbar.mosaicHighLevelDown(p)
                    }
                    break
                }
                case "surfacePrevTheme": {
                    if (menuBar.is3DVisible) {
                        scene3DToolbar.surfacePrevTheme()
                    }
                    break
                }
                case "surfaceNextTheme": {
                    if (menuBar.is3DVisible) {
                        scene3DToolbar.surfaceNextTheme()
                    }
                    break
                }
                case "surfaceStepDown": {
                    if (menuBar.is3DVisible) {
                        scene3DToolbar.surfaceStepDown(p)
                    }
                    break
                }
                case "surfaceStepUp": {
                    if (menuBar.is3DVisible) {
                        scene3DToolbar.surfaceStepUp(p)
                    }
                    break
                }
                case "toggleBottomTrack3D": {
                    if (menuBar.is3DVisible) {
                        scene3DToolbar.toggleBottomTrack()
                    }
                    break
                }
                case "toggleIsobaths3D": {
                    if (menuBar.is3DVisible) {
                        scene3DToolbar.toggleIsobaths()
                    }
                    break
                }
                case "toggleMosaic3D": {
                    if (menuBar.is3DVisible) {
                        scene3DToolbar.toggleMosaic()
                    }
                    break
                }
                case "cameraShiftXMinus3D": {
                    if (menuBar.is3DVisible) {
                        renderer.panStepTrigger(-1, 0)
                    }
                    break
                }
                case "cameraShiftXPlus3D": {
                    if (menuBar.is3DVisible) {
                        renderer.panStepTrigger(1, 0)
                    }
                    break
                }
                case "cameraShiftYMinus3D": {
                    if (menuBar.is3DVisible) {
                        renderer.panStepTrigger(0, -1)
                    }
                    break
                }
                case "cameraShiftYPlus3D": {
                    if (menuBar.is3DVisible) {
                        renderer.panStepTrigger(0, 1)
                    }
                    break
                }
                case "resetCameraTop3D": {
                    if (menuBar.is3DVisible) {
                        renderer.resetCameraAngleTrigger()
                    }
                    break
                }
                case "cameraShiftZMinus3D": {
                    if (menuBar.is3DVisible) {
                        renderer.zStepTrigger(-1)
                    }
                    break
                }
                case "cameraShiftZPlus3D": {
                    if (menuBar.is3DVisible) {
                        renderer.zStepTrigger(1)
                    }
                    break
                }
                case "resetDepthZoom3D": {
                    if (menuBar.is3DVisible) {
                        Scene3dToolBarController.onCancelZoomButtonClicked()
                    }
                    break
                }
                case "increaseLowLevel": {
                    let newLow = Math.min(120, waterViewFirst.getLowEchogramLevel() + p)
                    let newHigh = waterViewFirst.getHighEchogramLevel()
                    if (newLow > newHigh) newHigh = newLow
                    waterViewFirst.plotEchogramSetLevels(newLow, newHigh)
                    waterViewFirst.setLevels(newLow, newHigh)
                    if (waterViewSecond.enabled) {
                        let newSLow = Math.min(120, waterViewSecond.getLowEchogramLevel() + p)
                        let newSHigh = waterViewSecond.getHighEchogramLevel()
                        if (newSLow > newSHigh) newSHigh = newSLow
                        waterViewSecond.plotEchogramSetLevels(newSLow, newSHigh)
                        waterViewSecond.setLevels(newSLow, newSHigh)
                    }
                    break
                }
                case "decreaseLowLevel": {
                    let newLow = Math.max(0, waterViewFirst.getLowEchogramLevel() - p)
                    let newHigh = waterViewFirst.getHighEchogramLevel()
                    waterViewFirst.plotEchogramSetLevels(newLow, newHigh)
                    waterViewFirst.setLevels(newLow, newHigh)
                    if (waterViewSecond.enabled) {
                        let newSLow = Math.max(0, waterViewSecond.getLowEchogramLevel() - p)
                        let newSHigh = waterViewSecond.getHighEchogramLevel()
                        waterViewSecond.plotEchogramSetLevels(newSLow, newSHigh)
                        waterViewSecond.setLevels(newSLow, newSHigh)
                    }
                    break
                }
                case "increaseHighLevel": {
                    let newHigh = Math.min(120, waterViewFirst.getHighEchogramLevel() + p)
                    let newLow = waterViewFirst.getLowEchogramLevel()
                    waterViewFirst.plotEchogramSetLevels(newLow, newHigh)
                    waterViewFirst.setLevels(newLow, newHigh)
                    if (waterViewSecond.enabled) {
                        let newSHigh = Math.min(120, waterViewSecond.getHighEchogramLevel() + p)
                        let newSLow = waterViewSecond.getLowEchogramLevel()
                        waterViewSecond.plotEchogramSetLevels(newSLow, newSHigh)
                        waterViewSecond.setLevels(newSLow, newSHigh)
                    }
                    break
                }
                case "decreaseHighLevel": {
                    let newHigh = Math.max(0, waterViewFirst.getHighEchogramLevel() - p)
                    let newLow = waterViewFirst.getLowEchogramLevel()
                    if (newHigh < newLow) newLow = newHigh
                    waterViewFirst.plotEchogramSetLevels(newLow, newHigh)
                    waterViewFirst.setLevels(newLow, newHigh)
                    if (waterViewSecond.enabled) {
                        let newSHigh = Math.max(0, waterViewSecond.getHighEchogramLevel() - p)
                        let newSLow = waterViewSecond.getLowEchogramLevel()
                        if (newSHigh < newSLow) newSLow = newSHigh
                        waterViewSecond.plotEchogramSetLevels(newSLow, newSHigh)
                        waterViewSecond.setLevels(newSLow, newSHigh)
                    }
                    break
                }
                case "prevTheme": {
                    let themeId = waterViewFirst.getThemeId()
                    if (themeId > 0) waterViewFirst.plotEchogramTheme(themeId - 1)
                    if (waterViewSecond.enabled) {
                        let themeSId = waterViewSecond.getThemeId()
                        if (themeSId > 0) waterViewSecond.plotEchogramTheme(themeSId - 1)
                    }
                    break
                }
                case "nextTheme": {
                    let themeId = waterViewFirst.getThemeId()
                    if (themeId < 9) waterViewFirst.plotEchogramTheme(themeId + 1)
                    if (waterViewSecond.enabled) {
                        let themeSId = waterViewSecond.getThemeId()
                        if (themeSId < 9) waterViewSecond.plotEchogramTheme(themeSId + 1)
                    }
                    break
                }
                case "toggleEchogramType": {
                    waterViewFirst.toggleEchogramType()
                    if (waterViewSecond.enabled) {
                        waterViewSecond.toggleEchogramType()
                    }
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

        Item {
            id:                   visualisationLayout
            SplitView.fillHeight: true
            SplitView.fillWidth:  true
            Layout.fillHeight: true
            Layout.fillWidth:  true

            readonly property bool landscapeMode: mainview.width > mainview.height
            readonly property int rows: landscapeMode ? 1 : 2
            readonly property int columns: landscapeMode ? 2 : 1

            property int lastKeyPressed: Qt.Key_unknown
            property real splitRatio: 0.5
            property real dragRatio: 0.5
            property bool splitDragging: false
            property bool splitRatioSyncFromUi: false
            readonly property real splitDragMinRatio: 0.0
            readonly property real splitDragMaxRatio: 1.0
            readonly property real splitMidRatio: 0.5
            readonly property var splitSnapRatios: [0.25, 0.375, 0.5, 0.625, 0.75]
            readonly property int splitGripMainSize: Math.max(38, Math.round(48 * theme.resCoeff))
            readonly property int splitGripCrossSize: Math.max(14, Math.round(16 * theme.resCoeff))
            readonly property int splitGripRadius: Math.max(5, Math.round(7 * theme.resCoeff))
            // ── PULSE: 3D view intentionally disabled for now ──────────────────────────────
            // Upstream's split-view layout (movable divider between 2D echogram and 3D scene)
            // is kept in place but NOT used by Pulse yet. We force has3DView=false so:
            //   • splitActive becomes false  -> the divider/handle hides (sceneSplitHandle.visible)
            //   • the 3D pane width collapses to 0
            //   • plotsContainer (the 2D echogram) gets x=0 and full width -> fills the screen
            // The GraphicsScene3dView object still EXISTS (see renderer below, visible:false), so
            // Core::UILoad's findChild<GraphicsScene3dView*>() wiring stays intact — do not remove it.
            //
            // REVISIT LATER: to bring the 3D view back, two options —
            //   (a) Full-screen 3D toggle: add a button in the Pulse UI that flips which pane is
            //       shown, reusing this same has3DView / has2DView mechanism (mirror of how 2D is
            //       full-screen today).
            //   (b) Real split view: restore the original binding below to re-enable the divider.
            // Original upstream binding was:
            //   readonly property bool has3DView: (menuBar !== null) ? menuBar.is3DVisible : false
            readonly property bool has3DView: false
            readonly property bool has2DView: (menuBar !== null) ? menuBar.is2DVisible : false
            readonly property bool splitActive: has3DView && has2DView
            readonly property real primaryLength: landscapeMode ? width : height
            readonly property real splitLength: Math.max(0, primaryLength)
            readonly property real firstPaneLength: splitActive
                                                    ? Math.round(splitLength * splitRatio)
                                                    : (has3DView ? primaryLength : 0)
            readonly property real handlePaneLength: splitActive
                                                     ? Math.round(splitLength * (splitDragging ? dragRatio : splitRatio))
                                                     : firstPaneLength
            readonly property real previewSourceRatio: splitDragging ? dragRatio : splitRatio
            readonly property real previewSnapRatio: nearestSplitRatio(previewSourceRatio)
            readonly property real previewPaneLength: splitActive
                                                      ? Math.round(splitLength * previewSnapRatio)
                                                      : firstPaneLength
            readonly property int previewBandThickness: Math.max(3, Math.round(4 * theme.resCoeff))

            function clampSplitRatio(ratio) {
                if (!isFinite(ratio)) {
                    return splitMidRatio
                }
                return Math.max(splitDragMinRatio, Math.min(splitDragMaxRatio, ratio))
            }

            function nearestSplitRatio(ratio) {
                const clamped = clampSplitRatio(ratio)
                const targets = splitSnapRatios
                if (!targets || targets.length === 0) {
                    return splitMidRatio
                }
                let nearest = targets[0]
                let minDiff = Math.abs(clamped - nearest)
                for (let i = 1; i < targets.length; ++i) {
                    const diff = Math.abs(clamped - targets[i])
                    if (diff < minDiff) {
                        minDiff = diff
                        nearest = targets[i]
                    }
                }
                return nearest
            }

            onSplitActiveChanged: {
                splitDragging = false
                if (splitActive) {
                    splitRatio = nearestSplitRatio(splitRatio)
                }
                dragRatio = splitRatio
            }

            onLandscapeModeChanged: {
                splitDragging = false
                splitRatio = nearestSplitRatio(splitRatio)
                dragRatio = splitRatio
            }
            onSplitRatioChanged: {
                if (!splitDragging) {
                    splitRatioSyncFromUi = true
                    appSettings.sceneSplitRatio = clampSplitRatio(splitRatio)
                    splitRatioSyncFromUi = false
                }
            }

            function applySceneSplitRatioFromSettings() {
                const restoredRatio = nearestSplitRatio(appSettings.sceneSplitRatio)
                if (Math.abs(splitRatio - restoredRatio) > 0.0001) {
                    splitRatio = restoredRatio
                }
                dragRatio = splitRatio
            }

            Connections {
                target: appSettings
                function onSceneSplitRatioChanged() {
                    if (!visualisationLayout.splitDragging && !visualisationLayout.splitRatioSyncFromUi) {
                        visualisationLayout.applySceneSplitRatioFromSettings()
                    }
                }
            }

            Component.onCompleted: {
                applySceneSplitRatioFromSettings()
            }

            Behavior on splitRatio {
                enabled: !visualisationLayout.splitDragging
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            Keys.onPressed: function(event) {
                visualisationLayout.lastKeyPressed = event.key;
            }

            Keys.onReleased: {
                visualisationLayout.lastKeyPressed = Qt.Key_unknown;
            }

            GraphicsScene3dView {
                id:                renderer
                // PULSE: 3D view hidden for now. Kept instantiated (object must exist for
                // Core::UILoad's findChild<GraphicsScene3dView*>()). Its width is also forced to 0
                // via has3DView=false above. To re-enable a 3D view later, restore the original
                // binding and see the "REVISIT LATER" note on has3DView in visualisationLayout.
                //visible: menuBar.is3DVisible //- PULSE: hide
                visible: false
                objectName: "GraphicsScene3dView"
                x: 0
                y: 0
                width: visualisationLayout.landscapeMode
                       ? (visualisationLayout.splitActive
                          ? visualisationLayout.firstPaneLength
                          : (visualisationLayout.has3DView ? visualisationLayout.width : 0))
                       : visualisationLayout.width
                height: visualisationLayout.landscapeMode
                        ? visualisationLayout.height
                        : (visualisationLayout.splitActive
                           ? visualisationLayout.firstPaneLength
                           : (visualisationLayout.has3DView ? visualisationLayout.height : 0))
                focus:             true

                property bool longPressTriggered: false
                property int currentZoom: -1
                property bool syncLoupeUiAllowed: (menuBar !== null) ? (menuBar.is3DVisible && !menuBar.is2DVisible) : false

                function resetScenePointerState() {
                    //console.info("resetScenePointerState")
                    mousearea3D.startMousePos = Qt.point(-1, -1)
                    mousearea3D.wasMoved = false
                    mousearea3D.vertexMode = false
                    mousearea3D.lastMouseKeyPressed = Qt.NoButton
                    longPressTimer.stop()
                    renderer.longPressTriggered = false
                    renderer.cancelPointerInteraction()
                }

                onSyncLoupeUiAllowedChanged: {
                    setSyncLoupeUiAllowed(syncLoupeUiAllowed)
                }

                Component.onCompleted: {
                    setSyncLoupeUiAllowed(syncLoupeUiAllowed)
                }

                onSendDataZoom: function(zoom) {
                    currentZoom = zoom;
                }

                PinchArea {
                    id:           pinch3D
                    anchors.fill: parent
                    enabled:      !extraInfoPanel.touchInteractionActive

                    onPinchStarted: {
                        menuBlock.visible = false
                        mousearea3D.enabled = false
                    }

                    onPinchUpdated: function(pinch) {
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
                        Keys.onDeletePressed: function(event) { renderer.keyPressTrigger(event.key) }
                        Keys.onReturnPressed: function(event) { renderer.keyPressTrigger(event.key) }
                        Keys.onEnterPressed:  function(event) { renderer.keyPressTrigger(event.key) }
                        Keys.onEscapePressed: function(event) {
                            if (Qt.platform.os === "android") {
                                if (mainview.handleAndroidBack()) {
                                    event.accepted = true
                                    return
                                }
                            }
                            if (renderer.geoJsonEnabled) {
                                renderer.geojsonCancelDrawing()
                            } else {
                                renderer.clearRuler()
                            }
                        }

                        property int lastMouseKeyPressed: Qt.NoButton // TODO: maybe this mouseArea should be outside pinchArea
                        property point startMousePos: Qt.point(-1, -1)
                        property bool wasMoved: false
                        property real mouseThreshold: 15
                        property bool vertexMode: false

                        onEntered: {
                            mousearea3D.forceActiveFocus();
                        }

                        onWheel: function(wheel) {
                            renderer.mouseWheelTrigger(wheel.buttons, wheel.x, wheel.y, wheel.angleDelta, visualisationLayout.lastKeyPressed)
                        }

                        onPositionChanged: function(mouse) {
                            if (Qt.platform.os === "android") {
                                if (!wasMoved) {
                                    var delta = Math.sqrt(Math.pow((mouse.x - startMousePos.x), 2) + Math.pow((mouse.y - startMousePos.y), 2));
                                    if (delta > mouseThreshold) {
                                        wasMoved = true;
                                    }
                                }
                                if (renderer.longPressTriggered && !wasMoved) {
                                    if (renderer.geoJsonEnabled || renderer.rulerEnabled || renderer.rulerHasGeometry) {
                                        vertexMode = true
                                    } else {
                                        if (!vertexMode) {
                                            renderer.switchToBottomTrackVertexComboSelectionMode(mouse.x, mouse.y)
                                        }
                                        vertexMode = true
                                    }
                                }
                            }

                            const activeButtons = (Qt.platform.os === "android" && lastMouseKeyPressed !== Qt.NoButton)
                                    ? lastMouseKeyPressed
                                    : mouse.buttons
                            renderer.mouseMoveTrigger(activeButtons, mouse.x, mouse.y, visualisationLayout.lastKeyPressed)
                        }

                        onPressed: function(mouse) {
                            menuBlock.visible = false
                            geoMenuBlock.visible = false
                            rulerMenuBlock.visible = false
                            startMousePos = Qt.point(mouse.x, mouse.y)
                            wasMoved = false
                            vertexMode = false
                            longPressTimer.start()
                            renderer.longPressTriggered = false

                            lastMouseKeyPressed = mouse.buttons
                            renderer.mousePressTrigger(mouse.buttons, mouse.x, mouse.y, visualisationLayout.lastKeyPressed)
                        }

                        onReleased: function(mouse) {
                            startMousePos = Qt.point(-1, -1)
                            wasMoved = false
                            longPressTimer.stop()

                            renderer.mouseReleaseTrigger(lastMouseKeyPressed, mouse.x, mouse.y, visualisationLayout.lastKeyPressed)

                            if (mouse.button === Qt.RightButton || (Qt.platform.os === "android" && vertexMode)) {
                                if (renderer.geoJsonEnabled) {
                                    geoMenuBlock.position(mouse.x, mouse.y)
                                } else if (renderer.rulerEnabled || renderer.rulerSelected) {
                                    rulerMenuBlock.position(mouse.x, mouse.y)
                                } else {
                                    menuBlock.position(mouse.x, mouse.y)
                                }
                            }

                            vertexMode = false

                            lastMouseKeyPressed = Qt.NoButton
                        }

                        onCanceled: {
                            renderer.resetScenePointerState()
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
                    view: renderer
                    //anchors.horizontalCenter: parent.horizontalCenter
                    // anchors.rightMargin:      20
                    Keys.forwardTo:           [mousearea3D]
                }

                Scene3DRightToolbar {
                    id: scene3DRightToolbar
                    anchors.right: renderer.right
                    anchors.top: renderer.top
                    anchors.bottom: renderer.bottom
                    geo: renderer.geoJsonController
                    view: renderer
                    z: 3
                }

                Item {
                    id: syncLoupeOverlay
                    property int previewEpochIndex: waterViewFirst.getPreferredLoupeEpochIndex(renderer.syncLoupeEpochIndex)
                    visible: renderer.visible
                             && menuBar.is3DVisible
                             && (renderer.syncLoupeOverlayVisible || (renderer.syncLoupeZoomAdjusting && previewEpochIndex >= 0))
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: Math.round(12 * theme.resCoeff)
                    anchors.bottomMargin: Math.round(12 * theme.resCoeff)
                    z: 1002

                    property real sizeMultiplier: renderer.syncLoupeSize === 2 ? 1.5 : (renderer.syncLoupeSize === 3 ? 2.25 : 1.0)
                    property int baseSide: Math.round(180 * theme.resCoeff * sizeMultiplier)
                    property int maxSide: Math.max(64, Math.min(renderer.width, renderer.height) - 2 * anchors.rightMargin)
                    property int side: Math.max(64, Math.min(baseSide, maxSide))
                    property int sourceDepthReferencePx: 0

                    width: side
                    height: side

                    function refreshLoupePlot() {
                        const previewEpoch = previewEpochIndex
                        if (!visible || previewEpoch < 0) {
                            return
                        }

                        const zoomMultiplier = 1.0 + Math.max(0, Math.min(renderer.syncLoupeZoom, 300)) * 0.01
                        const previewSourceBaseSize = Math.max(8, Math.floor(syncLoupeOverlay.side))
                        const previewSourceSize = Math.max(4, Math.floor(previewSourceBaseSize / zoomMultiplier))
                        const ch1Name = waterViewFirst.plotDatasetChannelName()
                        const ch2Name = waterViewFirst.plotDatasetChannel2Name()
                        let mainDepthPxCandidate = waterViewFirst.horizontal ? Math.floor(waterViewFirst.height) : Math.floor(waterViewFirst.width)
                        if (mainDepthPxCandidate <= 0) {
                            const outerRows = Math.max(1, visualisationLayout.rows)
                            const outerCols = Math.max(1, visualisationLayout.columns)
                            const twoDCellHeight = Math.max(1, Math.floor(visualisationLayout.height / outerRows))
                            const twoDCellWidth = Math.max(1, Math.floor(visualisationLayout.width / outerCols))
                            const sliderHeight = Math.max(1, Math.floor(theme.controlHeight))
                            const plotsCount = menuBar.numPlots === 2 ? 2 : 1
                            const syntheticPlotHeight = Math.max(1, Math.floor((twoDCellHeight - sliderHeight) / plotsCount))
                            const syntheticPlotWidth = Math.max(1, twoDCellWidth)
                            mainDepthPxCandidate = waterViewFirst.horizontal ? syntheticPlotHeight : syntheticPlotWidth
                        }
                        if (mainDepthPxCandidate > 0) {
                            sourceDepthReferencePx = mainDepthPxCandidate
                        }
                        if (sourceDepthReferencePx <= 0) {
                            sourceDepthReferencePx = Math.max(1, Math.floor(syncLoupePlot3D.height))
                        }

                        const from2D = waterViewFirst.cursorFrom()
                        const to2D = waterViewFirst.cursorTo()
                        const has2DRange = isFinite(from2D) && isFinite(to2D) && Math.abs(to2D - from2D) > 0.0001
                        const cursorFrom = has2DRange ? from2D : renderer.syncLoupeDepthFrom
                        const cursorTo = has2DRange ? to2D : renderer.syncLoupeDepthTo
                        const centerDepth = waterViewFirst.getLoupeDepthForEpoch(previewEpoch)

                        syncLoupePlot3D.horizontal = waterViewFirst.horizontal
                        syncLoupePlot3D.plotDatasetChannelFromStrings(ch1Name, ch2Name)
                        syncLoupePlot3D.plotEchogramTheme(waterViewFirst.getThemeId())
                        syncLoupePlot3D.plotEchogramSetLevels(waterViewFirst.getLowEchogramLevel(), waterViewFirst.getHighEchogramLevel())
                        syncLoupePlot3D.plotEchogramCompensation(waterViewFirst.getEchogramCompensation())
                        syncLoupePlot3D.plotBottomTrackVisible(waterViewFirst.getBottomTrackVisible())
                        syncLoupePlot3D.plotBottomTrackTheme(waterViewFirst.getBottomTrackThemeId())
                        syncLoupePlot3D.plotRangefinderVisible(waterViewFirst.getRangefinderVisible())
                        syncLoupePlot3D.plotRangefinderTheme(waterViewFirst.getRangefinderThemeId())

                        syncLoupePlot3D.setCursorFromTo(cursorFrom, cursorTo)
                        syncLoupePlot3D.setTimelinePositionByEpochCentered(previewEpoch)
                        syncLoupePlot3D.setZoomPreviewSourceSize(previewSourceSize)
                        syncLoupePlot3D.setZoomPreviewReferenceDepthPixels(sourceDepthReferencePx)
                        syncLoupePlot3D.setZoomPreviewFlipY(renderer.syncLoupeFlipY)
                        syncLoupePlot3D.setZoomPreviewSourceByEpochDepth(previewEpoch, centerDepth)
                        syncLoupePlot3D.update()
                    }

                    onVisibleChanged: {
                        if (visible) {
                            refreshLoupePlot()
                        }
                    }

                    onWidthChanged: {
                        if (visible) {
                            refreshLoupePlot()
                        }
                    }

                    Connections {
                        target: renderer
                        function onSyncLoupeStateChanged() {
                            syncLoupeOverlay.refreshLoupePlot()
                        }
                    }

                    Connections {
                        target: waterViewFirst
                        function onTimelinePositionChanged() {
                            syncLoupeOverlay.refreshLoupePlot()
                        }
                        function onEchogramThemeChanged(themeId) {
                            syncLoupeOverlay.refreshLoupePlot()
                        }
                    }

                    Rectangle {
                        id: syncLoupeFrame
                        anchors.fill: parent
                        color: "black"
                        border.color: "#545E84"
                        border.width: Math.max(1, Math.round(2 * theme.resCoeff))
                        radius: Math.max(1, Math.round(2 * theme.resCoeff))
                        clip: true

                        WaterFall {
                            id: syncLoupePlot3D
                            objectName: "syncLoupe3DPlot"
                            anchors.fill: parent
                            anchors.margins: syncLoupeFrame.border.width
                            horizontal: true
                            enabled: false

                            Component.onCompleted: {
                                core.registerSyncLoupePlot(syncLoupePlot3D)
                                setZoomPreviewMode(true)
                                plotAttitudeVisible(false)
                                plotTemperatureVisible(false)
                                plotDopplerBeamVisible(false, 0)
                                plotDopplerInstrumentVisible(false)
                                plotGNSSVisible(false, 0)
                                plotAcousticAngleVisible(false)
                                plotVelocityVisible(false)
                                plotAngleVisibility(false)
                                plotGridVerticalNumber(0)
                                plotGridFillWidth(false)
                                plotGridInvert(false)
                                plotDistanceAutoRange(-1)
                                plotEchogramCompensation(0)
                            }
                        }
                    }
                }

                Rectangle {
                    id: mosaicQualityBadge
                    visible: renderer.cameraPerspective
                             && (dataset.spatialPreparing
                                 || (scene3DToolbar.showMosaicQualityLabel
                                     && renderer.currentZoom > 0
                                     && (scene3DToolbar.mosaicEnabled || renderer.updateSurface)))
                    readonly property int tileSidePx: 256
                    readonly property int heightMatrixRatio: 8
                    readonly property int mosaicCmPerPix: renderer.currentZoom > 0
                                                           ? Math.pow(2, renderer.currentZoom - 1)
                                                           : 0
                    readonly property int surfaceCmPerCell: mosaicCmPerPix > 0
                                                             ? Math.round(mosaicCmPerPix * tileSidePx / heightMatrixRatio)
                                                             : 0
                    color: "#00000080"
                    radius: 4
                    anchors.left: scene3DToolbar.right
                    anchors.verticalCenter: scene3DToolbar.verticalCenter
                    anchors.leftMargin: 8
                    z: 1000
                    implicitWidth: mosaicQualityText.implicitWidth + 12
                    implicitHeight: mosaicQualityText.implicitHeight + 8
                    opacity: 1.0

                    SequentialAnimation {
                        id: mosaicQualityPreparingAnimation
                        running: dataset.spatialPreparing
                        loops: Animation.Infinite
                        NumberAnimation { target: mosaicQualityBadge; property: "opacity"; to: 0.35; duration: 500 }
                        NumberAnimation { target: mosaicQualityBadge; property: "opacity"; to: 1.0; duration: 500 }
                    }

                    onVisibleChanged: {
                        if (!visible) {
                            opacity = 1.0
                        }
                    }

                    Connections {
                        target: dataset
                        function onSpatialPreparingChanged() {
                            if (!dataset.spatialPreparing) {
                                mosaicQualityBadge.opacity = 1.0
                            }
                        }
                    }

                    Text {
                        id: mosaicQualityText
                        text: {
                            if (dataset.spatialPreparing) {
                                return qsTr("Data prepairing...")
                            }
                            var parts = [];
                            if (renderer.currentZoom > 0 && scene3DToolbar.mosaicEnabled) {
                                parts.push(qsTr("Mosaic: ") + mosaicQualityBadge.mosaicCmPerPix + qsTr(" cm/pix"));
                            }
                            if (renderer.currentZoom > 0 && renderer.updateSurface) {
                                parts.push(qsTr("Surface: ") + mosaicQualityBadge.surfaceCmPerCell + qsTr(" cm/cell"));
                            }
                            return parts.join("\n");
                        }
                        color: "#ffffff"
                        font: theme.textFont
                        anchors.centerIn: parent
                    }
                }                CContact {
                    id: contactDialog
                    visible: false
                    offsetOpacityArea: 20 // increase in 3D

                    onInputAccepted: {
                        contacts.setContact(contactDialog.indx, contactDialog.inputFieldText)
                    }
                    onSetActiveButtonClicked: {
                        contacts.setActiveContact(contactDialog.indx)
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
                        icon.source: "qrc:/icons/ui/arrow_bar_to_down.svg"
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
                        icon.source: "qrc:/icons/ui/arrow_bar_to_up.svg"
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
                        icon.source: "qrc:/icons/ui/eraser.svg"
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
                        icon.source: "qrc:/icons/ui/x.svg"
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

                RowLayout {
                    id: geoMenuBlock
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 1
                    visible: false
                    Layout.margins: 0

                    property var geo: renderer.geoJsonController

                    onGeoChanged: {
                        //console.log("GeoJson menu updated, drawing: " + geo.drawing + ", selectedFeatureId: " + geo.selectedFeatureId)
                    }

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

                    CheckButton {
                        icon.source: "qrc:/icons/ui/plus.svg"
                        backColor: theme.controlBackColor
                        checkable: false
                        implicitWidth: theme.controlHeight
                        visible: geoMenuBlock.geo && geoMenuBlock.geo.drawing

                        onClicked: {
                            renderer.geojsonFinishDrawing()
                            geoMenuBlock.visible = false
                        }
                    }

                    CheckButton {
                        icon.source: "qrc:/icons/ui/stack_backward.svg"
                        backColor: theme.controlBackColor
                        checkable: false
                        implicitWidth: theme.controlHeight
                        visible: geoMenuBlock.geo && geoMenuBlock.geo.drawing

                        onClicked: {
                            renderer.geojsonUndoLastVertex()
                            geoMenuBlock.visible = false
                        }
                    }

                    CheckButton {
                        icon.source: "qrc:/icons/ui/x.svg"
                        backColor: theme.controlBackColor
                        checkable: false
                        implicitWidth: theme.controlHeight
                        visible: geoMenuBlock.geo && geoMenuBlock.geo.drawing

                        onClicked: {
                            renderer.geojsonCancelDrawing()
                            geoMenuBlock.visible = false
                        }
                    }

                    CheckButton {
                        icon.source: "qrc:/icons/ui/timeline_event_x.svg"
                        backColor: theme.controlBackColor
                        checkable: false
                        implicitWidth: theme.controlHeight
                        visible: geoMenuBlock.geo && !geoMenuBlock.geo.drawing && geoMenuBlock.geo.selectedFeatureId !== ""

                        onClicked: {
                            renderer.geojsonDeleteSelectedFeature()
                            geoMenuBlock.visible = false
                        }
                    }
                }

                RowLayout {
                    id: rulerMenuBlock
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

                    CheckButton {
                        icon.source: "qrc:/icons/ui/file-check.svg"
                        backColor: theme.controlBackColor
                        checkable: false
                        implicitWidth: theme.controlHeight
                        visible: renderer.rulerEnabled && renderer.rulerDrawing

                        onClicked: {
                            renderer.rulerFinishDrawing()
                            rulerMenuBlock.visible = false
                        }
                    }

                    CheckButton {
                        icon.source: "qrc:/icons/ui/x.svg"
                        backColor: theme.controlBackColor
                        checkable: false
                        implicitWidth: theme.controlHeight
                        visible: renderer.rulerEnabled || renderer.rulerSelected

                        onClicked: {
                            if (renderer.rulerDrawing) {
                                renderer.rulerCancelDrawing()
                            }
                            rulerMenuBlock.visible = false
                        }
                    }

                    CheckButton {
                        icon.source: "qrc:/icons/ui/timeline_event_x.svg"
                        backColor: theme.controlBackColor
                        checkable: false
                        implicitWidth: theme.controlHeight
                        visible: !renderer.rulerDrawing && renderer.rulerSelected

                        onClicked: {
                            renderer.rulerDeleteSelected()
                            rulerMenuBlock.visible = false
                        }
                    }
                }
            }

            Rectangle {
                id: splitSnapPreview
                visible: visualisationLayout.splitActive && visualisationLayout.splitDragging
                x: visualisationLayout.landscapeMode
                   ? Math.round(visualisationLayout.previewPaneLength - width / 2)
                   : 0
                y: visualisationLayout.landscapeMode
                   ? 0
                   : Math.round(visualisationLayout.previewPaneLength - height / 2)
                width: visualisationLayout.landscapeMode
                       ? visualisationLayout.previewBandThickness
                       : visualisationLayout.width
                height: visualisationLayout.landscapeMode
                        ? visualisationLayout.height
                        : visualisationLayout.previewBandThickness
                color: "#558D8D8D"
                border.color: "#B8D0D0D0"
                border.width: 1
                z: 9995
            }

            Item {
                id: sceneSplitHandle
                visible: visualisationLayout.splitActive
                x: visualisationLayout.landscapeMode
                   ? Math.round(visualisationLayout.handlePaneLength - width / 2)
                   : Math.round((visualisationLayout.width - width) / 2)
                y: visualisationLayout.landscapeMode
                   ? Math.round((visualisationLayout.height - height) / 2)
                   : Math.round(visualisationLayout.handlePaneLength - height / 2)
                width: visualisationLayout.landscapeMode ? visualisationLayout.splitGripCrossSize : visualisationLayout.splitGripMainSize
                height: visualisationLayout.landscapeMode ? visualisationLayout.splitGripMainSize : visualisationLayout.splitGripCrossSize
                z: 10000

                Rectangle {
                    anchors.fill: parent
                    radius: visualisationLayout.splitGripRadius
                    color: (sceneSplitHandleMouse.containsMouse || sceneSplitHandleMouse.pressed)
                           ? "#8D8D8D"
                           : "#237A7A7A"
                    border.color: (sceneSplitHandleMouse.containsMouse || sceneSplitHandleMouse.pressed)
                                  ? "#D0D0D0"
                                  : "#4A969696"
                    border.width: 1
                }

                Image {
                    anchors.centerIn: parent
                    source: "qrc:/icons/ui/direction_horizontal.svg"
                    fillMode: Image.PreserveAspectFit
                    width: Math.round(parent.width * 0.65)
                    height: Math.round(parent.height * 0.65)
                    transformOrigin: Item.Center
                    rotation: visualisationLayout.landscapeMode ? 0 : 90
                    opacity: sceneSplitHandleMouse.containsMouse || sceneSplitHandleMouse.pressed ? 1.0 : 0.42
                }

                MouseArea {
                    id: sceneSplitHandleMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: visualisationLayout.landscapeMode ? Qt.SplitHCursor : Qt.SplitVCursor
                    property real dragStartGlobalPos: 0
                    property real dragStartRatio: visualisationLayout.dragRatio

                    onPressed: function(mouse) {
                        visualisationLayout.splitDragging = true
                        visualisationLayout.dragRatio = visualisationLayout.splitRatio
                        dragStartRatio = visualisationLayout.dragRatio
                        const mappedPos = sceneSplitHandleMouse.mapToItem(visualisationLayout, mouse.x, mouse.y)
                        dragStartGlobalPos = visualisationLayout.landscapeMode ? mappedPos.x : mappedPos.y
                    }

                    onPositionChanged: function(mouse) {
                        if (!pressed || !visualisationLayout.splitActive || visualisationLayout.splitLength <= 0) {
                            return
                        }

                        const mappedPos = sceneSplitHandleMouse.mapToItem(visualisationLayout, mouse.x, mouse.y)
                        const currentGlobalPos = visualisationLayout.landscapeMode ? mappedPos.x : mappedPos.y
                        const delta = currentGlobalPos - dragStartGlobalPos
                        const startLength = dragStartRatio * visualisationLayout.splitLength
                        const newRatio = (startLength + delta) / visualisationLayout.splitLength
                        visualisationLayout.dragRatio = visualisationLayout.clampSplitRatio(newRatio)
                    }

                    onReleased: {
                        visualisationLayout.splitDragging = false
                        visualisationLayout.splitRatio = visualisationLayout.nearestSplitRatio(visualisationLayout.dragRatio)
                        visualisationLayout.dragRatio = visualisationLayout.splitRatio
                    }

                    onCanceled: {
                        visualisationLayout.splitDragging = false
                        visualisationLayout.splitRatio = visualisationLayout.nearestSplitRatio(visualisationLayout.dragRatio)
                        visualisationLayout.dragRatio = visualisationLayout.splitRatio
                    }

                    onDoubleClicked: {
                        visualisationLayout.splitDragging = false
                        visualisationLayout.dragRatio = visualisationLayout.splitMidRatio
                        visualisationLayout.splitRatio = visualisationLayout.splitMidRatio
                    }
                }
            }

            Item {
                id: plotsContainer
                visible: menuBar.is2DVisible
                x: visualisationLayout.landscapeMode
                   ? (visualisationLayout.splitActive
                      ? visualisationLayout.firstPaneLength
                      : 0)
                   : 0
                y: visualisationLayout.landscapeMode
                   ? 0
                   : (visualisationLayout.splitActive
                      ? visualisationLayout.firstPaneLength
                      : 0)
                width: visualisationLayout.landscapeMode
                       ? (visualisationLayout.splitActive
                          ? Math.max(0, visualisationLayout.width - visualisationLayout.firstPaneLength)
                          : visualisationLayout.width)
                       : visualisationLayout.width
                height: visualisationLayout.landscapeMode
                        ? visualisationLayout.height
                        : (visualisationLayout.splitActive
                           ? Math.max(0, visualisationLayout.height - visualisationLayout.firstPaneLength)
                           : visualisationLayout.height)

                GridLayout {
                    anchors.fill: parent
                    rows    : 2
                    columns : 1
                    columnSpacing: 0
                    rowSpacing: 0

                    Plot2D {
                        id: waterViewFirst
                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        Layout.rowSpan   : 1
                        Layout.columnSpan: 1
                        focus: true
                        instruments: menuBar.instruments
                        indx: 1
                        is3dVisible: menuBar.is3DVisible

                        onTimelinePositionChanged: {
                            historyScroll.value = waterViewFirst.timelinePosition
                            historyTimeLineScroll.timeLineScrollerPosition = timelinePosition
                        }

                        Component.onCompleted: {
                            waterViewFirst.setIndx(waterViewFirst.indx);
                        }
                    }

                    Plot2D {
                        id: waterViewSecond

                        enabled: menuBar.numPlots === 2
                        visible: menuBar.numPlots === 2

                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        Layout.rowSpan   : 1
                        Layout.columnSpan: 1
                        focus: true
                        instruments: menuBar.instruments
                        indx: 2

                        onEnabledChanged: {
                            waterViewSecond.setPlotEnabled(enabled)
                        }

                        onVisibleChanged: {
                            if (visible && menuBar.syncPlots) {
                                setCursorFromTo(waterViewFirst.cursorFrom(), waterViewFirst.cursorTo())
                                update()
                            }
                        }

                        onTimelinePositionChanged: {
                            historyScroll.value = timelinePosition
                            historyTimeLineScroll.timeLineScrollerPosition = timelinePosition
                        }

                        Component.onCompleted: {
                            setIndx(waterViewSecond.indx);
                        }
                    }

                    CSlider {
                        id: historyScroll
                        //Pulse: hide
                        visible: false
                        Layout.margins: 0
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.columnSpan: parent.columns
                        implicitHeight: theme.controlHeight
                        height: theme.controlHeight
                        //value: waterViewFirst.timelinePosition
                        stepSize: 0.0001
                        from: 0
                        to: 1
                        barWidth: 50 * theme.resCoeff
                        onValueChanged: {
                            core.setTimelinePosition(value);
                        }
                        onMoved: {
                            core.resetAim()
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
    
    TimeLineShifter {
        id: historyTimeLineScroll
        visibleWhenPaused: pulseRuntimeSettings.echogramPause
        //visibleWhenPaused: false
        from: 0
        to: 1
        stepSize: 0.0001
        Layout.fillWidth: pulseRuntimeSettings.isHorizontalGrid
        Layout.fillHeight: !pulseRuntimeSettings.isHorizontalGrid
        //onValueChanged: core.setTimelinePosition(value)
        //onMoved: core.resetAim()
    }

    Item {
        id: profilesFloatBtn
        z: 9999
        visible: menuBar.profilesBtnVis

        property int  margin: 12
        property real idleOpacity: 0.45
        property real buttonWidth: theme.controlHeight * 4
        property real buttonHeight: theme.controlHeight

        opacity: idleOpacity
        width: profilesContainer.implicitWidth
        height: profilesContainer.implicitHeight

        function clampToWindow() {
            x = Math.max(margin, Math.min(x, mainview.width  - width  - margin))
            y = Math.max(margin, Math.min(y, mainview.height - height - margin))
        }

        Component.onCompleted: {
            x = mainview.width - width - margin
            y = margin
            clampToWindow()
        }

        Connections {
            target: mainview
            function onWidthChanged()  { profilesFloatBtn.clampToWindow() }
            function onHeightChanged() { profilesFloatBtn.clampToWindow() }
        }

        Behavior on opacity { NumberAnimation { duration: 120 } }

        Column {
            id: profilesContainer
            spacing: 6
            anchors.horizontalCenter: parent.horizontalCenter

            CheckButton {
                id: profilesBtn
                width: profilesFloatBtn.buttonWidth
                height: profilesFloatBtn.buttonHeight
                text: qsTr("Profiles...")
                backColor: theme.controlBackColor
                borderColor: "transparent"
                onClicked: profilesDialog.open()
            }

            Repeater {
                id: quickButtonsRepeater
                model: profilesModel

                delegate: CButton {
                    text: (index + 1).toString()
                    enabled: path && path.length > 0
                    width: profilesBtn.width
                    height: profilesBtn.height
                    onClicked: {
                        if (path && path.length > 0) {
                            menuBar.applyProfileToAllDevices(path)
                        }
                    }
                }
            }
        }

        DragHandler {
            id: profilesDrag
            target: profilesFloatBtn
            xAxis.minimum: profilesFloatBtn.margin
            xAxis.maximum: Math.max(profilesFloatBtn.margin, mainview.width - profilesFloatBtn.width - profilesFloatBtn.margin)
            yAxis.minimum: profilesFloatBtn.margin
            yAxis.maximum: Math.max(profilesFloatBtn.margin, mainview.height - profilesFloatBtn.height - profilesFloatBtn.margin)
            onActiveChanged: {
                if (!active) {
                    profilesFloatBtn.clampToWindow()
                }
            }
        }

        HoverHandler {
            id: profilesHover
            target: profilesContainer
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: {
                if (hovered) {
                    profilesFloatBtn.opacity = 1.0
                }
                else {
                    profilesFloatBtn.opacity = profilesFloatBtn.idleOpacity
                }
            }
        }
    }

    Dialog {
        id: profilesDialog
        title: qsTr("Profiles")
        modal: true
        focus: true
        width: Math.min(parent ? parent.width * 0.9 : 700, 700)
        standardButtons: Dialog.Close

        property int browseRow: -1

        Settings {
            id: profilesStorage
            property var savedProfiles: []
            property var lastProfileFolder: StandardPaths.writableLocation(StandardPaths.HomeLocation)
        }

        function loadSavedProfiles() {
            profilesModel.clear()
            var stored = profilesStorage.savedProfiles
            if (!stored || stored.length === 0) {
                return
            }
            for (var i = 0; i < stored.length; ++i) {
                var path = stored[i] ? stored[i] : ""
                profilesModel.append({ path: path, displayPath: pathToDisplay(path) })
            }
        }

        function saveProfiles() {
            var stored = []
            for (var i = 0; i < profilesModel.count; ++i) {
                var data = profilesModel.get(i)
                stored.push(data.path ? data.path : "")
            }
            profilesStorage.savedProfiles = stored
        }

        Component.onCompleted: {
            loadSavedProfiles()
            standardButton(Dialog.Close).text = qsTr("Close")
        }

        function urlToPath(u) {
            if (!u) return ""
            var localPath = u.toLocalFile ? u.toLocalFile() : ""
            return localPath && localPath.length ? localPath : u.toString()
        }

        function pathToDisplay(path) {
            if (!path || !path.length) {
                return ""
            }

            if (path.startsWith("file:///")) {
                path = Qt.platform.os === "windows" ? path.slice(8) : path.slice(7)
            } else if (path.startsWith("file://")) {
                path = path.slice(7)
            }

            try {
                return decodeURIComponent(path)
            } catch (error) {
                return path
            }
        }

        function effectivePath(displayText, storedPath) {
            if (!displayText || !displayText.length) {
                return ""
            }

            if (storedPath && displayText === pathToDisplay(storedPath)) {
                return storedPath
            }

            return displayText
        }

        ListModel {
            id: profilesModel
            //profilesModel.append({ path: "" })
        }

        FileDialog {
            id: profilePickDialog
            title: qsTr("Select profile XML")
            fileMode: FileDialog.OpenFile
            currentFolder: profilesStorage.lastProfileFolder
            nameFilters: Qt.platform.os === "android" ? ["*/*"] : ["XML files (*.xml)"]

            onCurrentFolderChanged: {
                profilesStorage.lastProfileFolder = currentFolder
            }

            onAccepted: {
                if (profilesDialog.browseRow < 0) return
                profilesStorage.lastProfileFolder = profilePickDialog.currentFolder
                const p = profilesDialog.urlToPath(profilePickDialog.selectedFile)
                profilesModel.setProperty(profilesDialog.browseRow, "path", p)
                profilesModel.setProperty(profilesDialog.browseRow, "displayPath", pathToDisplay(p))
                profilesDialog.browseRow = -1
                profilesDialog.saveProfiles()
            }
        }

        contentItem: ColumnLayout {
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: qsTr("Add profiles and apply them")
                    Layout.fillWidth: true
                    color: "white"
                }

                CButton {
                    text: "+"
                    onClicked: {
                        profilesModel.append({ path: "", displayPath: "" })
                        profilesDialog.saveProfiles()
                    }
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 320
                clip: true

                ListView {
                    id: profilesList
                    model: profilesModel
                    spacing: 8

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 52
                        radius: 8
                        color: "#202020"
                        border.color: "#909090"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            CTextField {
                                id: pathField
                                Layout.fillWidth: true
                                placeholderText: qsTr("Path to profile .xml")
                                text: displayPath
                                color: "white"
                                onEditingFinished: {
                                    const sourcePath = effectivePath(text, path)
                                    profilesModel.setProperty(index, "path", sourcePath)
                                    profilesModel.setProperty(index, "displayPath", pathToDisplay(sourcePath))
                                    profilesDialog.saveProfiles()
                                }
                            }

                            CButton {
                                text: qsTr("Browse")
                                onClicked: {
                                    profilesDialog.browseRow = index
                                    profilePickDialog.currentFolder = profilesStorage.lastProfileFolder
                                    profilePickDialog.open()
                                }
                            }

                            CButton {
                                text: qsTr("Apply")
                                enabled: (pathField.text && pathField.text.length > 0)
                                onClicked: {
                                    menuBar.applyProfileToAllDevices(effectivePath(pathField.text, path))
                                }
                            }

                            CButton {
                                text: "✕"
                                onClicked: {
                                    profilesModel.remove(index)
                                    profilesDialog.saveProfiles()
                                }
                            }
                        }
                    }
                }
            }
        }

        background: Rectangle {
            color: theme.controlBackColor
            radius: 8
        }
    }

    ExtraInfoPanel {
        id: extraInfoPanel
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 12
        menuBarState: menuBar
        datasetState: dataset
        showBanner: mainview.showBanner
    }
    
    // бровь
    MenuFrame {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !showBanner && (deviceManagerWrapper.pilotArmState >= 0) && menuBar.autopilotInfofVis
        isDraggable: true
        isOpacityControlled: true
        Keys.forwardTo: [splitLayer]

        ColumnLayout {
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                CheckButton {
                    // text: checked ? "Armed" : "Disarmed"
                    icon.source: checked ? "qrc:/icons/ui/propeller.svg" : "qrc:/icons/ui/propeller_off.svg"
                    checked: deviceManagerWrapper.pilotArmState === 1
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
                    icon.source: "qrc:/icons/ui/direction_arrows.svg"
                    checked: deviceManagerWrapper.pilotModeState === 0 // "Manual"
                    onCheckedChanged: {
                    }
                    ButtonGroup.group: autopilotModeGroup
                    implicitWidth: theme.controlHeight
                }

                CheckButton {
                    // Layout.fillWidth: true
                    icon.source: "qrc:/icons/ui/route.svg"
                    checked: deviceManagerWrapper.pilotModeState === 10 // "Auto"
                    onCheckedChanged: {
                    }
                    ButtonGroup.group: autopilotModeGroup
                    implicitWidth: theme.controlHeight
                }

                CheckButton {
                    // Layout.fillWidth: true
                    icon.source: "qrc:/icons/ui/anchor.svg"
                    checked: deviceManagerWrapper.pilotModeState === 5 // "Loiter"
                    onCheckedChanged: {
                    }
                    ButtonGroup.group: autopilotModeGroup
                    implicitWidth: theme.controlHeight
                }

                CheckButton {
                    // Layout.fillWidth: true
                    icon.source: "qrc:/icons/ui/map_pin.svg"
                    checked: deviceManagerWrapper.pilotModeState === 15 // "Guided"
                    onCheckedChanged: {
                    }
                    ButtonGroup.group: autopilotModeGroup
                    implicitWidth: theme.controlHeight
                }

                CheckButton {
                    // Layout.fillWidth: true
                    icon.source: "qrc:/icons/ui/home.svg"
                    checked: deviceManagerWrapper.pilotModeState === 11 || deviceManagerWrapper.pilotModeState === 12  // "RTL" || "SmartRTL"
                    onCheckedChanged: {
                    }
                    ButtonGroup.group: autopilotModeGroup
                    implicitWidth: theme.controlHeight
                }

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

    MainMenuBar {
        id:                menuBar
        objectName:        "menuBar"
        Layout.fillHeight: true
        Keys.forwardTo:    [splitLayer, mousearea3D]
        height: visualisationLayout.height

        Component.onCompleted: {
            menuBar.targetPlot = waterViewFirst
            y = y + 40
        }

        //Pulse: Hide. MenuBar is item holding the water view button
        visible: false
        //visible: !showBanner
    }

    function handleChildSignal(langStr) {
        mainview.showBanner = true
        selectedLanguageStr = langStr
    }

    function handleSyncPlotEnabled() {
        waterViewSecond.setCursorFromTo(waterViewFirst.cursorFrom(), waterViewFirst.cursorTo())
        waterViewSecond.update()
    }

    function handlePlotCursorChanged(indx, from, to) {
        if (!menuBar.syncPlots) {
            if (syncLoupeOverlay.visible) {
                syncLoupeOverlay.refreshLoupePlot()
            }
            return;
        }

        if (indx === 1 && waterViewSecond.enabled) {
            waterViewSecond.setCursorFromTo(from, to)
            waterViewSecond.update()
        }
        if (indx === 2) {
            waterViewFirst.setCursorFromTo(from, to)
            waterViewFirst.update()
        }

        if (syncLoupeOverlay.visible) {
            syncLoupeOverlay.refreshLoupePlot()
        }
    }

    function handleUpdateOtherPlot(indx) {
        if (indx === 1 && waterViewSecond.enabled) {
            waterViewSecond.update()
        }
        if (indx === 2) {
            waterViewFirst.update()
        }
    }
    function handlePlotPressed(indx, mouseX, mouseY) {
        let r = core.getConvertedMousePos(indx, mouseX, mouseY)

        if (indx === 1 && waterViewSecond.enabled) {
            waterViewSecond.setAim(r.x, r.y)
        }
        if (indx === 2) {
            waterViewFirst.setAim(r.x, r.y)
        }
    }
    function handlePlotReleased(indx) {
        if (indx === 1 && waterViewSecond.enabled) {
            waterViewSecond.resetAim()
        }
        if (indx === 2) {
            waterViewFirst.resetAim()
        }
    }
    function onPlotSettingsClicked() {
        menuBar.closeMenus()
    }
    function onMenuBarSettingsOpened() {
        waterViewFirst.closeSettings()
        waterViewSecond.closeSettings()
    }
    function handleMosaicLOffsetChanged(val) {
        waterViewFirst.mosaicLOffsetChanged(val)
        waterViewSecond.mosaicLOffsetChanged(val)
    }
    function handleMosaicROffsetChanged(val) {
        waterViewFirst.mosaicROffsetChanged(val)
        waterViewSecond.mosaicROffsetChanged(val)
    }


    // banner on file opening
    Rectangle {
        id: fileOpeningOverlay
        color: theme.controlBackColor
        opacity: 0.8
        radius: 10
        anchors.centerIn: parent
        //Do we need this?
        //visible: core.isFileOpening && !core.isSeparateReading
        visible: false
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
                source: "./icons/ui/patternDots.svg"
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
            text: "Echogram speed: " + pulseSettings.echogramSpeed
            //text: "Echogram speed: " + pulseRuntimeSettings.echogramSpeed
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
                //zoomText.text = "Horizontal zoom: " + pulseRuntimeSettings.echogramSpeed
                zoomText.text = "Echogram speed: " + pulseSettings.echogramSpeed
                console.log("Echogram speed: New value", pulseRuntimeSettings.echogramSpeed)
                zoomIndicator.visible = true
                hideTimer.restart()
            }
        }
    }


    // echosounder selector Screen
    Rectangle {
        id: echoSounderSelectorRect
        width: Math.round(1000 * s)
        height: Math.round(350 * s)
        //width: 1000
        //height: 350
        anchors.centerIn: parent
        color: "transparent"

        // Decides when the whole selector is allowed to appear
        property bool revealGate: false
        visible: revealGate || selectionMade
        opacity: 1
        // These properties control which item was selected.
        property bool selectionMade: false
        property string selectedDevice: ""

        Timer {
            id: selectorDelayTimer
            interval: 1000
            repeat: false
            onTriggered: {
                if (!echoSounderSelectorRect.selectionMade) {
                    // only show the full selector if nothing auto-selected
                    echoSounderSelectorRect.revealGate = true
                    mainview.windowShadow = true
                }
            }
        }

        Component.onCompleted: selectorDelayTimer.start()

        Connections {
            target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
            function onSwapDeviceNowChanged () {
                if (pulseRuntimeSettings.swapDeviceNow) {
                    console.log("DEV_RESELECT initialize in main")

                    // 1) Don't force it visible now; let the gate control it
                    echoSounderSelectorRect.revealGate     = false
                    echoSounderSelectorRect.selectionMade  = false
                    echoSounderSelectorRect.selectedDevice = ""

                    // 2) Show both choices when/if the gate opens
                    pulseRedSelector.visible  = true
                    pulseBlueSelector.visible = true

                    // 3) Clear any lingering state + restart the reveal delay
                    echoSounderSelectorRect.state = ""
                    selectorDelayTimer.restart()

                    // 4) Clear other UI bits
                    pulseRuntimeSettings.devManualSelected = false
                    pulseRuntimeSettings.swapDeviceNow = false
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

            function onDevNameChanged () {
                console.log("onDevnameChanged in main.qml: name", pulseRuntimeSettings.devName)
                let detectedModel = "";
                console.log("DEVICE: received an onDevNameChanged, devName is", pulseRuntimeSettings.devName);
                if (pulseRuntimeSettings.devName === "...") {
                    console.log("DEVICE: aborting this method for devName", pulseRuntimeSettings.devName);
                    return
                }
                console.log("devName no longer ..., dataset numberOfDatasetChannels", pulseRuntimeSettings.numberOfDatasetChannels, "for devName", pulseRuntimeSettings.devName, "and rawDev_devName", pulseRuntimeSettings.rawDev_devName)
                if (pulseRuntimeSettings.devName === "PULSEred") {
                    detectedModel = pulseRuntimeSettings.modelPulseRed
                }
                if (pulseRuntimeSettings.devName === "PULSEblue") {
                    detectedModel = pulseRuntimeSettings.modelPulseBlue
                }
                //TODO: Auto select does not work for Basic2D inb USB connection mode
                if (pulseRuntimeSettings.devName === "Basic2D") {
                    const channelsList = dataset.channelsNameList();
                    const values = channelsList
                        .filter(Boolean)
                        .map(String)
                        .filter(v => v !== "None");
                    //const isBlue = values.some(v => /UDP\([^)]+\)\|\d+\|1\b/.test(v));
                    const isBlue = values.some(v =>
                            /^(?:UDP\([^)]+\)|bus\/usb\/\d+\/\d+)\|\d+\|1$/.test(v)
                        );
                    if (isBlue) {
                        detectedModel = pulseRuntimeSettings.modelPulseBlue
                        pulseRuntimeSettings.pulseBetaName = pulseRuntimeSettings.pulseBlueBeta
                    } else {
                        detectedModel = pulseRuntimeSettings.modelPulseRed
                        pulseRuntimeSettings.pulseBetaName = pulseRuntimeSettings.pulseRedBeta
                    }
                    pulseRuntimeSettings.devManualSelected = true
                    console.log("DEV_PARAM: observed this channel list and will use it to auto select for Basic2D", channelsList)
                }

                if (detectedModel !== "") {
                    pulseRuntimeSettings.userManualSetName = detectedModel
                    echoSounderSelectorRect.selectedDevice = detectedModel
                    echoSounderSelectorRect.selectionMade = true
                    pulseRuntimeSettings.devManualSelected = true
                    console.log("DEV_PARAM: Automatically detected device and set pulseRuntimeSettings.userManualSetName to", pulseRuntimeSettings.userManualSetName)
                } else {
                    //ECHO20 has become "Basic2D"
                    //TODO Still have not set the beta name. ow to do that?
                    console.log("DEVICE: devName not auto selected, name is", pulseRuntimeSettings.devName);
                }
            }

            function onNumberOfDatasetChannelsChanged () {
                if (pulseRuntimeSettings.swapDeviceNow) {
                    return
                }
                console.log("dataset numberOfDatasetChannels", pulseRuntimeSettings.numberOfDatasetChannels, "for devName", pulseRuntimeSettings.devName, "and rawDev_devName", pulseRuntimeSettings.rawDev_devName)

                let detectedModel = "";
                if (pulseRuntimeSettings.numberOfDatasetChannels === 1) {
                    if (pulseRuntimeSettings.devName === "Basic2D") {
                        detectedModel = pulseRuntimeSettings.modelPulseRed
                        pulseRuntimeSettings.pulseBetaName = pulseRuntimeSettings.pulseRedBeta
                    }
                } else if (pulseRuntimeSettings.numberOfDatasetChannels === 2) {
                    if (pulseRuntimeSettings.devName === "Basic2D") {
                        detectedModel = pulseRuntimeSettings.modelPulseBlue
                        pulseRuntimeSettings.pulseBetaName = pulseRuntimeSettings.pulseBlueBeta
                    }
                }
                if (detectedModel !== "") {
                    pulseRuntimeSettings.userManualSetName = detectedModel
                    echoSounderSelectorRect.selectedDevice = detectedModel
                    echoSounderSelectorRect.selectionMade = true
                    pulseRuntimeSettings.devManualSelected = true
                    console.log("DEV_PARAM: Automatically detected beta device and set pulseRuntimeSettings.userManualSetName to", pulseRuntimeSettings.userManualSetName)
                } else {
                    console.log("DEV_PARAM: onNumberOfDatasetChannelsChanged, but channels are 0 so nothing happened")
                }
            }
        }

        Connections {
            target: core
            function onChannelListUpdated() {
                let list = []
                list = dataset.channelsNameList()
                if (list.length < 2)
                    return

                pulseRuntimeSettings.numberOfDatasetChannels = list.length -1

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
                    //guardTimer.restart()
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
                //pulseRuntimeSettings.dataUpdateActive = false
                // If we’re still inside our initial window, reboot:
                if (pulseRuntimeSettings.guardActive && !pulseRuntimeSettings.echogramPausedForConfig) {
                    console.log("DATAFLOW: Auto-reboot (data became stale within guard window)")
                    pulseRuntimeSettings.dataUpdateActive = false
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
            //width: 1000; height: 800
            width: Math.round(1000 * s)
            height: Math.round(800 * s)
            anchors.centerIn: parent
            property int spacing: Math.round(100 * s) //100
            property int center: Math.round(550 * s) //550

            EchoSounderSelector {
                id: pulseRedSelector
                //width: 450
                width: Math.round(450 * s)
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                backgroundColor: "transparent"   // light red background
                title: "PULSEred"
                titleColor: "red"
                description: "High-performance 2D echo sounder"
                //illustrationSource: "./image/PulseRedForApp.jpg"
                illustrationSource: "./image/pulse_info_red_black_large.png"
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
                //width: 450
                width: Math.round(450 * s)
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                backgroundColor: "transparent"   // light blue background
                title: "PULSEblue"
                titleColor: "blue"
                description: "High-performance side-scan echo sounder"
                //illustrationSource: "./image/PulseBlueForApp.jpg"
                illustrationSource: "./image/pulse_info_blue_large.png"
                //versions: ["v1.0"]
                //version: "v1.0"
                onVisibleChanged: {
                    console.log("DEV_SELECTION: pulseBlueSelector visible?", visible)
                    console.log("DEV_SELECTION: pulseBlueSelector visible? echoSounderSelectorRect.selectedDevice", echoSounderSelectorRect.selectedDevice)
                    console.log("DEV_SELECTION: pulseBlueSelector visible? echoSounderSelectorRect.selectionMade", echoSounderSelectorRect.selectionMade)
                }

                onSelected: {
                    //This is set for a device that was configured, bit not for device manually selected. Always set it at selection?
                    pulseRuntimeSettings.chartResolution = pulseSettings.echogramWidth //- This workaround will lower resolution but keep the data rate unchanged. Fits anglers, but not SAR
                    pulseRuntimeSettings.distMax = 1000 * pulseSettings.echogramWidth
                    pulseRuntimeSettings.maximumDepth = pulseSettings.echogramWidth
                    //
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
                    x: (freeContainer.width - pulseBlueSelector.width)/2
                    y: (freeContainer.height - pulseBlueSelector.height)/2
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
