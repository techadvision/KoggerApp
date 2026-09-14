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

    // WHAT THE RAIL TAKES FROM THE PICTURE, named once so everything drawn on the echogram
    // can respect it with one read. Zero in the classic UI and zero while the rail is
    // collapsed, both through the rail's own `inset`.
    //
    // Anything that draws ON the echogram must add this. Anything full-bleed ABOVE
    // everything - PulseConnectionScreen at z 9000 - must not: it covers the rail too.
    // WHICHEVER EDGE CONTROL IS SHOWING ON THAT EDGE. The rail and the paused gutter are
    // never both up. They were also the same width on purpose, so that pausing never moved
    // the echogram sideways - and as of 14 Sept that promise holds for a SIDE SCAN only.
    // The gutter now follows the flow (Olav: "follow the flow. That is the only intuitive
    // way"), so a 2D picture's gutter runs along the foot instead: pausing gives the rail's
    // width back and takes height at the bottom, and the picture reflows. Stated here
    // rather than left as a comment that used to be true.
    readonly property real pulseRailInset:
          (pulsePausedGutter.visible && !pulsePausedGutter.alongFoot) ? pulsePausedGutter.inset
        : pulseRail.visible                                           ? pulseRail.inset
        :                                                               0

    // AND WHAT IT TAKES AT THE FOOT, which only the paused gutter ever does. A separate
    // number rather than a sign on the one above, because they are margins on different
    // sides and a reader who has one must not be able to apply it to the other.
    readonly property real pulsePausedFootInset:
          (pulsePausedGutter.visible && pulsePausedGutter.alongFoot) ? pulsePausedGutter.inset
        :                                                             0

    // AND WHAT THE PANEL TAKES. Two numbers, one per thing that takes width, and neither
    // guesses about the other. Only the pane layout adds both; the setup card adds only the
    // rail's, because the panel slides over the space the card would use rather than beside
    // it - and a card that jumped sideways every time a group opened would be worse than one
    // the panel covers.
    readonly property real pulsePanelInset: pulsePanel.visible ? pulsePanel.inset : 0

    readonly property int _rightBarWidth:                360
    readonly property int _activeObjectParamsMenuHeight: 500
    readonly property int _sceneObjectsListHeight:       300

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
        //The DISPLAY answer, published as its OWN key and consumed only by the ruler. The
        //scene draws what is on screen, so its scale follows the picture; is2DTransducer above
        //still means "what is connected" and everything else keeps asking that.
        function onDisplayIs2DTransducerChanged()   {
            console.log("VALUE_CHANGE: publishing displayIs2DTransducer",
                        pulseRuntimeSettings.displayIs2DTransducer)
            settingsBus.updateRuntime({ displayIs2DTransducer:  pulseRuntimeSettings.displayIs2DTransducer      })
        }
        function onShouldDoAutoRangeChanged()       { settingsBus.updateRuntime({ shouldDoAutoRange:        pulseRuntimeSettings.shouldDoAutoRange          }) }
        function onAutoDepthMaxLevelChanged()       { settingsBus.updateRuntime({ autoDepthMaxLevel:        pulseRuntimeSettings.autoDepthMaxLevel          }) }
        function onMaximumDepthChanged()            { settingsBus.updateRuntime({ maximumDepth:             pulseRuntimeSettings.maximumDepth               }) }
        function onIsHorizontalGridChanged()        { settingsBus.updateRuntime({ isHorizontalGrid:         pulseRuntimeSettings.isHorizontalGrid           }) }
        function onUseMetricDepthChanged()          { settingsBus.updateRuntime({ useMetricDepth:           pulseRuntimeSettings.useMetricDepth             }) }
        //WHICH UI IS UP. Consumed only by the aim layer, which paints the rebuilt loupe
        //for v2 and the original one for classic - the classic UI is still what uiVariant
        //falls back TO, so its loupe is not this commit's to move.
        function onUiVariantIsV2Changed()           { settingsBus.updateRuntime({ uiVariantIsV2:            pulseRuntimeSettings.uiVariantIsV2              }) }
        //function onAutoDepthMaxLevelChanged()       { settingsBus.updateRuntime({ autoRange:                pulseRuntimeSettings.autoDepthMaxLevel          }) }
        //Note: The onAutoDepthMaxLevelChanged above was initialluy onautoDepthMaxLevelChanged (ona..., non existing. May influence some missing behavior
        //Bottom track
        //function onUpdateBottomTrackChanged()       { settingsBus.updateRuntime({ updateBottomTrack:        pulseRuntimeSettings.updateBottomTrack          }) }
        function onIsBottomTrackInitiatedChanged()  { settingsBus.updateRuntime({ isBottomTrackInitiated:   pulseRuntimeSettings.isBottomTrackInitiated     }) }
        //Play/Pause echogram
        function onEchogramPauseChanged()           { settingsBus.updateRuntime({ echogramPause:            pulseRuntimeSettings.echogramPause              }) }
        //PULSE side scan TVG: full mosaic rebuild when the mosaic source
        //switch flips, so existing tiles re-trace with the selected buffer.
        //Qt.callLater ensures the Plot2D.qml handler has pushed the C++ flag
        //before the rebuild starts.
        function onSideScanTvgMosaicEnabledChanged() { Qt.callLater(function() { scene3DToolbar.updateMosaic() }) }
        //App is ready configured, ensure C++ values are up to date:
        function onUserManualSetNameChanged () {
            if (pulseRuntimeSettings.userManualSetName === "...")
                return
            pulseSettings.nmeaBroadcastAddress = pulseRuntimeSettings.nmeaBroadcastAddress
            let shouldBroadcastMtw = pulseSettings.enableNmeaMtw && pulseRuntimeSettings.is2DTransducer
            //Enable bottomTrack for red/blue if the user is an expert
            //No need to do this for Experts only anymore - we use bottom track for everyone!!!
            /*
            if (pulseRuntimeSettings.expertMode && pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                pulseRuntimeSettings.processBottomTrack = true
            }
            */

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
                    nmeaBroadcastAddress:    pulseSettings.nmeaBroadcastAddress,
                    transducerOffsetMount:   pulseSettings.transducerOffsetMount
                })
            pulseRuntimeSettings.isSideScanLeftHand = pulseSettings.isSideScanOnLeftHandSide
            settingsBus.updateRuntime({
                    isSideScanLeftHand:       pulseRuntimeSettings.isSideScanLeftHand,
                    isSideScan2DView:         pulseRuntimeSettings.isSideScan2DView,
                    echogramSpeed:            pulseRuntimeSettings.echogramSpeed,
                    is2DTransducer:           pulseRuntimeSettings.is2DTransducer,
                    displayIs2DTransducer:    pulseRuntimeSettings.displayIs2DTransducer,
                    shouldDoAutoRange:        pulseRuntimeSettings.shouldDoAutoRange,
                    autoDepthMaxLevel:        pulseRuntimeSettings.autoDepthMaxLevel,
                    maximumDepth:             pulseRuntimeSettings.maximumDepth,
                    isHorizontalGrid:         pulseRuntimeSettings.isHorizontalGrid,
                    useMetricDepth:           pulseRuntimeSettings.useMetricDepth,
                    uiVariantIsV2:            pulseRuntimeSettings.uiVariantIsV2,
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
        function onTransducerOffsetMountChanged()   { settingsBus.updatePersistent({ transducerOffsetMount: pulseSettings.transducerOffsetMount }) }
        //Echogram speed moved to the persistent settings, workaround to keep the runtime integration as is:
        function onEchogramSpeedChanged ()          { pulseRuntimeSettings.echogramSpeed = pulseSettings.echogramSpeed                             }
        function onAutoRangeChanged ()              { pulseRuntimeSettings.shouldDoAutoRange = pulseSettings.autoRange                             }
        //function onUsbSerialBaudChanged ()          { pulseRuntimeSettings.usbSerialBaud = pulseSettings.usbSerialBaud                             }
    }

    // KEYS THE QML SIDE OWNS, which the loop below must READ PAST rather than write back.
    //
    // The bus echoes every key it is handed, including the ones that only ever travel QML ->
    // C++. Those are readonly bindings here, and assigning to a readonly property throws -
    // "TypeError: Cannot assign to read-only property" on every push, which is what
    // uiVariantIsV2 did the moment it joined the bus.
    //
    // A named list rather than a try/catch, for two reasons: a swallowed exception hides the
    // day a genuinely writable key stops being writable, and a one-way key ought to have to
    // declare itself. Add to this list when you publish something the QML side computes.
    readonly property var runtimeKeysQmlOwns: ["uiVariantIsV2"]

    Connections {
        target: settingsBus
        function onRuntimeChanged(m) {
            //dumpMap("settingsBus.runtimeChanged", m)
            for (var k in m) {
                if (mainview.runtimeKeysQmlOwns.indexOf(k) !== -1) {
                    continue
                }
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
                // A NEW LOG MUST NOT BE CLASSIFIED BY THE PREVIOUS ONE'S CHANNEL COUNT.
                // activeModel classifies an opened file from numberOfDatasetChannels, and
                // onChannelListUpdated below only ever ASSIGNS it — it returns early while
                // the list is still just the placeholder, and never clears it. So the count
                // left over from the last log (or from a live device) stood until the new
                // log produced a full list, and until then the new log was displayed as
                // whatever the last one was. Observed 12 Sept 2026: committed red, open a
                // side scan log -> rendered as 2D; open a red log, then the side scan again
                // -> correct. Clearing here makes the stale value unreachable; 0 means
                // "not known yet", which activeModel already falls back to committedModel for.
                //
                // Safe for the live path: ConnectionViewer's Basic2D window latches the
                // MAXIMUM channel count seen (basic2dMaxChannels), so a transient 0 cannot
                // lower it, and onNumberOfDatasetChannelsChanged does nothing at 0.
                if (pulseRuntimeSettings.numberOfDatasetChannels !== 0) {
                    console.log("FILE OPENING: clearing the previous log's channel count of",
                                pulseRuntimeSettings.numberOfDatasetChannels)
                    pulseRuntimeSettings.numberOfDatasetChannels = 0
                }
            }
        }

        //DEMO MODE (Stage 1) — see demo_mode_plan.md.
        //The prescan reports the pacing it settled on; surface it so the expert
        //UI can show what the demo is actually running at.
        function onDemoPeriodChanged(periodMs, isSideScan) {
            pulseRuntimeSettings.demoMeasuredPeriodMs = periodMs
            pulseRuntimeSettings.demoIsSideScan = isSideScan
            console.log("DEMO: running at", periodMs, "ms/epoch,",
                        isSideScan ? "side scan" : "2D")
        }

        //End of the replayed file, or a stop initiated in C++. Undo the quieting
        //so a real device can be configured normally again.
        //enterDemoMode/exitDemoMode live on pulseRuntimeSettings, not here: it
        //is a root context property, so every QML file can reach it, while this
        //file's `mainview` id is not visible outside main.qml.
        function onDemoStopped() {
            console.log("DEMO: stopped by core, restoring normal app state")
            pulseRuntimeSettings.exitDemoMode()
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

        if (renderer.ruler.drawing) {
            renderer.ruler.cancelDrawing()
            return true
        }

        if (renderer.ruler.enabled || renderer.ruler.selected || renderer.ruler.hasGeometry) {
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
            devName:                "...",
            //AT STARTUP TOO, not only when it changes. The bulk push below lives inside
            //onUserManualSetNameChanged and so waits for a model to be committed; the aim
            //layer can be asked to draw before that, and a loupe that came up classic in
            //v2 until the first commit would be a defect nobody could reproduce twice.
            uiVariantIsV2:          pulseRuntimeSettings.uiVariantIsV2
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

        //DEMO MODE: a replay has no connection to lose.
        if (pulseRuntimeSettings.isInDemoMode) {
            return
        }

        if (lostConnectionAlert === null) {
            var component = Qt.createComponent("LostConnectionOverlay.qml")
            lostConnectionAlert = component.createObject( mainview, {"x": 0, "y": 0 } )
            if (lostConnectionAlert !== null) {
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
            // ── PULSE TRIAL (feature/enable-3d-mosaic): full-screen ECHOGRAM ⇄ 3D toggle ──────
            // Pulse does NOT use upstream's draggable 50/50 split. Instead the screen shows EITHER
            // the full-width echogram (default, always at launch) OR the full-screen 3D/mosaic view.
            // The sceneSplitHandle below is repurposed as a single tap toggle (the green oval):
            //   • echogram full  -> oval sits at the LEFT edge; tap -> 3D takes the whole screen
            //   • 3D full        -> oval sits at the RIGHT edge; tap -> back to the echogram
            // mosaicViewActive is the single source of truth. It is intentionally NOT persisted, so
            // every launch starts on the echogram (per product requirement "always full echogram").
            // The GraphicsScene3dView object stays instantiated (renderer.visible follows this flag)
            // so Core::UILoad's findChild<GraphicsScene3dView*>() wiring stays intact.
            property bool mosaicViewActive: false

            // Toggle is only offered when the 3D/mosaic view is meaningful: a side-scan transducer
            // is attached (NOT a 2D/downscan-only model) AND we have position data — live MAVLink
            // (mavlinkDetected, same flag that greens the play/pause checkbox) OR a loaded log file
            // (so file-replay testing still works). Relax this line for broader internal testing.
            readonly property bool view3dToggleAvailable:
                !pulseRuntimeSettings.is2DTransducer
                && (pulseRuntimeSettings.mavlinkDetected || (core.filePath && core.filePath.length > 0))

            // Force back to the echogram if the toggle becomes unavailable (e.g. file closed).
            onView3dToggleAvailableChanged: {
                if (!view3dToggleAvailable) {
                    mosaicViewActive = false
                }
            }

            readonly property bool has3DView: mosaicViewActive
            readonly property bool has2DView: !mosaicViewActive
            readonly property bool splitActive: has3DView && has2DView // always false now (no split) — kept for the geometry below
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
                // PULSE TRIAL: visible only when the 3D/mosaic view is toggled full-screen.
                // Object stays instantiated when hidden (Core::UILoad findChild requirement).
                visible: visualisationLayout.has3DView
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
                                    if (renderer.geoJsonEnabled || renderer.ruler.enabled || renderer.ruler.hasGeometry) {
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
                                } else if (renderer.ruler.enabled || renderer.ruler.selected) {
                                    rulerMenuBlock.position(mouse.x, mouse.y)
                                } else {
                                    // PULSE TRIAL: bottom-track edit mini-menu (down/up/eraser/x)
                                    // suppressed for the test build — Pulse does not expose manual
                                    // bottom-track editing. Re-enable by restoring the call below.
                                    // menuBlock.position(mouse.x, mouse.y)
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
                    // PULSE TRIAL: bottom button bar hidden for the test build (mosaic auto-enables,
                    // so the manual crisis fallback is no longer needed). Object stays instantiated
                    // so its Component.onCompleted wiring (incl. mosaic auto-enable) still runs.
                    // Set back to true to expose the manual buttons again.
                    visible: false
                    // anchors.bottom:              parent.bottom
                    y:renderer.height - height - 2
                    view: renderer
                    //anchors.horizontalCenter: parent.horizontalCenter
                    // anchors.rightMargin:      20
                    Keys.forwardTo:           [mousearea3D]
                }

                Scene3DRightToolbar {
                    id: scene3DRightToolbar
                    // PULSE TRIAL: top-right group (map.svg layers + ruler_measure.svg) hidden for
                    // the test build — not used by Pulse. Set back to true to restore.
                    visible: false
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
                        visible: renderer.ruler.enabled && renderer.ruler.drawing

                        onClicked: {
                            renderer.ruler.finishDrawing()
                            rulerMenuBlock.visible = false
                        }
                    }

                    CheckButton {
                        icon.source: "qrc:/icons/ui/x.svg"
                        backColor: theme.controlBackColor
                        checkable: false
                        implicitWidth: theme.controlHeight
                        visible: renderer.ruler.enabled || renderer.ruler.selected

                        onClicked: {
                            if (renderer.ruler.drawing) {
                                renderer.ruler.cancelDrawing()
                            }
                            rulerMenuBlock.visible = false
                        }
                    }

                    CheckButton {
                        icon.source: "qrc:/icons/ui/timeline_event_x.svg"
                        backColor: theme.controlBackColor
                        checkable: false
                        implicitWidth: theme.controlHeight
                        visible: !renderer.ruler.drawing && renderer.ruler.selected

                        onClicked: {
                            renderer.ruler.deleteSelected()
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

            // ── PULSE TRIAL: ECHOGRAM ⇄ 3D toggle (the green oval) ───────────────────────────
            // Repurposed from upstream's draggable split divider into a single TAP toggle.
            // Bigger hit area + green fill so it is easy to find and press on a tablet.
            // Sits at the LEFT edge while the echogram is full (tap pulls the 3D view in), and at
            // the RIGHT edge while the 3D view is full (tap returns to the echogram). Portrait uses
            // top/bottom edges. Shown only when view3dToggleAvailable.
            Item {
                id: sceneSplitHandle
                visible: visualisationLayout.view3dToggleAvailable
                z: 10000

                readonly property int edgeMargin: Math.max(4, Math.round(6 * theme.resCoeff))
                readonly property int gripThin: Math.max(26, Math.round(30 * theme.resCoeff)) // tap thickness
                readonly property int gripLong: Math.max(64, Math.round(78 * theme.resCoeff)) // length along edge

                width:  visualisationLayout.landscapeMode ? gripThin : gripLong
                height: visualisationLayout.landscapeMode ? gripLong : gripThin

                // Landscape: left edge when echogram full, right edge when 3D full.
                // Portrait:  top edge  when echogram full, bottom edge when 3D full.
                x: visualisationLayout.landscapeMode
                   ? (visualisationLayout.mosaicViewActive
                      ? (visualisationLayout.width - width - edgeMargin)
                      : edgeMargin)
                   : Math.round((visualisationLayout.width - width) / 2)
                y: visualisationLayout.landscapeMode
                   ? Math.round((visualisationLayout.height - height) / 2)
                   : (visualisationLayout.mosaicViewActive
                      ? (visualisationLayout.height - height - edgeMargin)
                      : edgeMargin)

                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(Math.min(parent.width, parent.height) / 2)
                    color: sceneSplitHandleMouse.pressed ? "#2EE06A" : "green"
                    opacity: sceneSplitHandleMouse.pressed ? 1.0 : 0.85
                    border.color: "#1B5E20"
                    border.width: 1
                }

                Image {
                    anchors.centerIn: parent
                    source: "qrc:/icons/ui/direction_horizontal.svg"
                    fillMode: Image.PreserveAspectFit
                    width: Math.round(parent.width * 0.6)
                    height: Math.round(parent.height * 0.6)
                    transformOrigin: Item.Center
                    rotation: visualisationLayout.landscapeMode ? 0 : 90
                    opacity: 0.95
                }

                MouseArea {
                    id: sceneSplitHandleMouse
                    anchors.fill: parent
                    anchors.margins: -8 // enlarge touch area beyond the visible oval
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        visualisationLayout.mosaicViewActive = !visualisationLayout.mosaicViewActive
                    }
                }
            }

            Item {
                id: plotsContainer
                visible: visualisationLayout.has2DView
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

                    // THE EDGE RAIL TAKES ITS WIDTH FROM THE PICTURE RATHER THAN COVERING IT.
                    // This one line is the whole of it, and it has to be here: the rail cannot
                    // do it from inside Plot2D, because qPlot2D paints the echogram across its
                    // entire item and PulseApp is that item's CHILD. Anything that takes width
                    // from the picture has to be the panes' SIBLING - which is also true of the
                    // sliding panel stage 4 (b) brings.
                    //
                    // Zero in the classic UI and zero while the rail is collapsed, both through
                    // the rail's own `inset`, so there is no second mechanism to keep in step.
                    anchors.leftMargin: mainview.pulseRailInset + mainview.pulsePanelInset
                    // AND AT THE FOOT, for a 2D picture's paused gutter. Zero at every
                    // other moment, through the gutter's own binding - so there is no
                    // second mechanism deciding when the bottom is taken.
                    anchors.bottomMargin: mainview.pulsePausedFootInset

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


                // THE EDGE RAIL (Stage 4 a). ONE instance above both panes, for the same
                // reason PulseConnectionScreen and PulseSetupOverlay are: PulseApp is built
                // inside Plot2D, so anything living there is drawn once per pane.
                //
                // It sits inside plotsContainer rather than at the foot of this file because
                // anchors only reach a parent or a sibling - and because plotsContainer is
                // exactly the 2D area, so the rail never intrudes on the 3D pane.
                //
                // Everything it needs is read here and passed in; the rail itself holds no
                // app state. `collapsed` is ONE binding on the persisted setting and the
                // handler writes the SETTING, never the property - assigning it would destroy
                // the binding and the rail would stop following the stored value.
                PulseRail {
                    id: pulseRail

                    // PAUSED IS ITS OWN MODE, so the rail is not merely disabled while the
                    // picture is frozen - it is gone, and the gutter takes its place.
                    visible: pulseSettings.uiVariant === "v2"
                             && !pulseRuntimeSettings.echogramPause
                    enabled: visible

                    anchors.left:   parent.left
                    anchors.top:    parent.top
                    anchors.bottom: parent.bottom

                    uiScale:    mainview.s
                    safeTop:    mainview.insetTop()
                    safeBottom: mainview.insetBottom()
                    safeLeft:   mainview.insetLeft()

                    // RULE 1. What is DRAWN about the picture reads the display model;
                    // is2DTransducer answers "what is connected" and nothing that draws may
                    // ask it. What the interface OFFERS reads the committed profile, because
                    // a chooser offers hardware choices and never follows a log.
                    displayIs2D: pulseRuntimeSettings ? pulseRuntimeSettings.displayIs2DTransducer : true
                    offersView:  pulseRuntimeSettings ? pulseRuntimeSettings.offersViewChoice : false
                    offersCone:  pulseRuntimeSettings ? pulseRuntimeSettings.offersConeChoice : false

                    recording: pulseRuntimeSettings ? pulseRuntimeSettings.isRecordingKlf : false

                    // THE CONDITION THE RECORDING TAB HAS ALWAYS USED, not isPresentingLog.
                    // A replay records as a confusing second-generation log; an opened file,
                    // or one still opening, is not live data to record at all. With a
                    // transducer connected AND a file open, isPresentingLog is false - so it
                    // would have let the button back over a picture that is still a file.
                    canRecord: pulseRuntimeSettings
                               ? (!pulseRuntimeSettings.wasKlfFileOpened
                                  && !pulseRuntimeSettings.isOpeningKlfFile
                                  && !pulseRuntimeSettings.isInDemoMode
                                  && !core.isFileOpening)
                               : false

                    // The link strip, read rather than recomputed. Same derivation the
                    // connection screen reads, so the button and the screen it opens can
                    // never disagree.
                    sourceState: pulseRuntimeSettings ? pulseRuntimeSettings.linkState : "absent"
                    sourceColor: pulseRuntimeSettings ? pulseRuntimeSettings.linkColor : "#6d7480"

                    collapsed: pulseSettings.v2RailCollapsed
                    onCollapseToggled: {
                        pulseSettings.v2RailCollapsed = !pulseSettings.v2RailCollapsed
                        console.log("RAIL:", pulseSettings.v2RailCollapsed ? "collapsed" : "shown")
                        // A PANEL WITHOUT ITS RAIL IS STRANDED. Its own close button still
                        // works, but the button that opened it has just gone, so the two
                        // move together.
                        if (pulseSettings.v2RailCollapsed)
                            pulsePanel.openGroup = ""
                    }

                    // THE OVERRIDE on the connection screen's one visibility binding. It goes
                    // through pulseRuntimeSettings rather than through pulseConnectionScreen's
                    // id because the rail is a component in its own file - and keeping the
                    // route the same from wherever the rail is hosted is worth more than the
                    // one line it saves here.
                    onSourceActivated: {
                        console.log("RAIL: source - opening the connection screen")
                        if (pulseRuntimeSettings)
                            pulseRuntimeSettings.connectionScreenRequested = true
                    }

                    // Scaffolding until 4 (b): the switch that turns v2 on lives in the expert
                    // settings inside the CLASSIC UI, and uiVariant is persisted.
                    onBackToClassic: {
                        console.log("PULSE UI: v2 - returning to classic")
                        pulseSettings.uiVariant = "classic"
                    }

                    openGroup: pulsePanel.openGroup

                    onButtonActivated: function (id) {
                        // RECORD IS THE FIRST TIER-1 BUTTON THAT DOES SOMETHING, because it
                        // is the only one that needs no settings panel - it has no value to
                        // set, only a state to enter. It does not toggle: it ASKS, in the
                        // pill column where the recording state already lives.
                        // PAUSE NEEDS NO PANEL EITHER. Like Record it has no value to set,
                        // only a mode to enter - and unlike Record it is not destructive, so
                        // it does not ask.
                        if (id === "pause") {
                            mainview.setEchogramPaused(true)
                            return
                        }

                        if (id === "record") {
                            if (pulseRuntimeSettings.isRecordingKlf)
                                pulsePillColumn.askRecordStop()
                            else
                                pulsePillColumn.askRecordStart()
                            return
                        }

                        // Any other rail tap answers an open question with "not now". A
                        // question left standing while the user has plainly moved on is
                        // clutter, and the next tap is how they said so.
                        pulsePillColumn.dismissQuestion()

                        // TAPPING THE BUTTON THAT OPENED A GROUP CLOSES IT, and one group is
                        // open at a time. Both fall out of comparing the id with openGroup
                        // rather than out of a rule written twice.
                        if (id === "colours" || id === "intensity" || id === "filter"
                                || id === "view" || id === "cone" || id === "range") {
                            pulsePanel.openGroup = (pulsePanel.openGroup === id) ? "" : id
                            console.log("PANEL:", pulsePanel.openGroup === "" ? "closed" : "showing " + id)
                            return
                        }

                        if (id === "settings")
                            console.log("RAIL:", id, "- the settings list arrives with tier 2")
                        else
                            console.log("RAIL:", id, "- its panel arrives later in stage 4 (b)")
                    }
                }

                // THE SLIDING PANEL (Stage 4 b). Beside the rail, and anchored past it, so
                // the two insets add up rather than overlap.
                PulsePanel {
                    id: pulsePanel

                    visible: pulseSettings.uiVariant === "v2" && openGroup !== ""
                    enabled: visible

                    anchors.left: parent.left
                    anchors.leftMargin: mainview.pulseRailInset
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    uiScale:    mainview.s
                    safeTop:    mainview.insetTop()
                    safeBottom: mainview.insetBottom()

                    announceEchogramStop: pulseSettings.stopEchogramToConfigure

                    onCloseRequested: openGroup = ""

                    // ---- Colours ------------------------------------------------
                    //
                    // THE LIST FOLLOWS THE DISPLAY MODEL, and so does the key a tap writes.
                    // Neither chooser can reach the other device's stored preference, which
                    // is the whole of the fix: the classic 2D selector read the SHARED
                    // applied id, found the blue's theme inside the red list and wrote that
                    // position into colorMapIndex2D, destroying red's own preference.
                    readonly property var fullThemeList:
                        pulseRuntimeSettings ? pulseRuntimeSettings.displayThemeModel : []

                    themeEntries: favouritesFilter ? pulseSettings.favoriteThemes2DNew
                                                   : fullThemeList

                    // THE COLOUR TABLES, ASKED FOR ONCE. qPlot2D::echogramThemeStops(id) is
                    // Q_INVOKABLE and has been in the tree unused; it returns the renderer's
                    // own table for ANY id, so every row can draw the palette it will get.
                    //
                    // Built once rather than bound: these tables are compiled in and cannot
                    // change while the app runs, and twenty invokes per repaint would be
                    // twenty invokes too many.
                    property var themeStopsById: ({})

                    Component.onCompleted: {
                        var out = {}
                        var all = pulseRuntimeSettings.themeModelRed
                                      .concat(pulseRuntimeSettings.themeModelBlue)
                        for (var i = 0; i < all.length; ++i) {
                            var id = all[i].id
                            if (out[id] !== undefined)
                                continue
                            out[id] = waterViewFirst.echogramThemeStops(id)
                        }
                        themeStopsById = out
                        console.log("THEME: colour tables read for", Object.keys(out).length, "themes")

                        // The stored values have to reach the renderer at least once, or v2
                        // starts on whatever the plot happened to have. The classic controls
                        // did this from their own Component.onCompleted; v2 has no control to
                        // hang it on until a panel is opened, so it happens here.
                        mainview.applyIntensity()
                        mainview.applyWaterBodyFilter()
                        mainview.applyMaxRange()
                    }
                    currentThemeId: pulseRuntimeSettings ? pulseRuntimeSettings.displayThemeId : -1

                    offerFavourites: pulseRuntimeSettings ? pulseRuntimeSettings.displayIs2DTransducer
                                                          : false
                    favouritesFilter: offerFavourites && pulseSettings.useFavoriteThemes2D
                    favouriteIds: pulseSettings.favoriteThemes2DNew.map(function (t) { return t.id })

                    // THE ONLY PLACE A COLOUR KEY IS WRITTEN in v2, and it writes exactly
                    // one - the one belonging to the model on screen. displayThemeId is a
                    // binding on these, so the picture follows without being told.
                    onThemeChosen: function (id) {
                        var is2D  = pulseRuntimeSettings.displayIs2DTransducer
                        var model = is2D ? pulseRuntimeSettings.themeModelRed
                                         : pulseRuntimeSettings.themeModelBlue
                        var idx = model.findIndex(function (e) { return e.id === id })
                        if (idx < 0) {
                            console.log("THEME: chosen id", id, "is not in the", is2D ? "2D" : "side scan", "list")
                            return
                        }
                        console.log("THEME: chosen", id, "-> storing index", idx,
                                    "in", is2D ? "colorMapIndex2D" : "colorMapIndexSideScan")
                        if (is2D)
                            pulseSettings.colorMapIndex2D = idx
                        else
                            pulseSettings.colorMapIndexSideScan = idx
                    }

                    // The two favourite functions already exist and already keep the list in
                    // master order. removeFavorite2DNew also moves colorMapIndex2D when it
                    // drops the current theme, which is exactly what v2 needs - and its write
                    // to colorMapIndexReal is harmless here, because the index move
                    // re-evaluates displayThemeId and the apply handler rewrites it.
                    onFavouriteToggled: function (id) {
                        var entry = pulseRuntimeSettings.themeModelRed.find(function (e) { return e.id === id })
                        if (!entry)
                            return
                        if (pulseSettings.favoriteThemes2DNew.find(function (x) { return x.id === id }))
                            pulseSettings.removeFavorite2DNew(entry)
                        else
                            pulseSettings.addFavorite2DNew(entry)
                    }

                    onFavouritesFilterToggled: {
                        pulseSettings.useFavoriteThemes2D = !pulseSettings.useFavoriteThemes2D
                        console.log("THEME: favourites filter",
                                    pulseSettings.useFavoriteThemes2D ? "on" : "off")
                    }

                    // ---- Intensity and the water body filter --------------------
                    //
                    // DISPLAY IN, REAL OUT, and both stored - exactly as the classic controls
                    // do it. The row shows the display number; the apply functions above read
                    // the real one. The duplicate guard matters: a drag emits on every pixel
                    // and one step is many pixels wide.
                    intensityValue: pulseSettings.intensityDisplayValue
                    filterValue:    pulseSettings.filterDisplayValue

                    // What the filter is currently doing, since the same slider means two
                    // different things depending on the expert switch beside it.
                    filterHint: pulseRuntimeSettings && pulseRuntimeSettings.echogramWaterBodyFilterEnabled
                                ? qsTr("0 – 20   ·   water column only")
                                : qsTr("0 – 20   ·   whole picture")

                    onIntensityMoved: function (v) {
                        if (v === pulseSettings.intensityDisplayValue)
                            return
                        pulseSettings.intensityDisplayValue = v
                        pulseSettings.intensityRealValue    = Math.round(120 - (v * 4))
                    }

                    onFilterMoved: function (v) {
                        if (v === pulseSettings.filterDisplayValue)
                            return
                        pulseSettings.filterDisplayValue = v
                        pulseSettings.filterRealValue    = Math.round(v * 2.5)
                    }

                    // ---- View / cone --------------------------------------------
                    //
                    // COMMITTED, not display. A chooser offers HARDWARE choices - you cannot
                    // change the cone of a transducer you do not have - so this follows what
                    // is connected and never a log that happens to be playing.
                    readonly property bool showingCone:
                        pulseRuntimeSettings ? pulseRuntimeSettings.offersConeChoice : false

                    choiceEntries: !pulseRuntimeSettings ? []
                                 : showingCone ? pulseRuntimeSettings.uiCones
                                               : pulseRuntimeSettings.uiViews
                    choiceCurrentId: !pulseRuntimeSettings ? ""
                                   : showingCone ? pulseRuntimeSettings.resolveConeId(pulseSettings.ecoConeId)
                                                 : pulseRuntimeSettings.resolveViewId(pulseSettings.ecoViewId)
                    choiceCaption: showingCone
                                   ? qsTr("A narrower cone sees less of the bottom and sees it more sharply.")
                                   : qsTr("What the transducer looks at. The frequency follows the view.")

                    // A REAL TAP IS THE ONLY THING THAT WRITES THE PREFERENCE - classic's own
                    // rule, kept. Applying is what happens when the preference moves.
                    // ---- Max range ----------------------------------------------
                    //
                    // Every term is the DISPLAY model's, including the ceiling: backlog item
                    // 11 in the one place it belongs. A 2D transducer's ceiling is hardware,
                    // a side scan's is the configured swath width, and neither is a copy that
                    // can freeze.
                    rangeValue:   pulseRuntimeSettings ? pulseRuntimeSettings.displayMaxRange        : 0
                    rangeFloor:   pulseRuntimeSettings ? pulseRuntimeSettings.displayMaxRangeFloor   : 1
                    rangeCeiling: pulseRuntimeSettings ? pulseRuntimeSettings.displayMaxRangeCeiling : 52
                    rangeStep:    pulseRuntimeSettings ? pulseRuntimeSettings.displayMaxRangeStep    : 1
                    rangeHint: pulseRuntimeSettings
                               ? (pulseRuntimeSettings.displayMaxRangeFloor + " – "
                                  + pulseRuntimeSettings.displayMaxRangeCeiling + " m"
                                  + (pulseRuntimeSettings.displayMaxRangeStep > 1
                                     ? "   ·   " + pulseRuntimeSettings.displayMaxRangeStep + " m steps" : ""))
                               : ""

                    // ONE WRITER, shared with the pinch on the picture, and it is the runtime
                    // object's - because the key it writes is the key displayMaxRange reads.
                    onRangeMoved: function (v) { pulseRuntimeSettings.storeDisplayMaxRange(v) }

                    onChoiceMade: function (id) {
                        if (showingCone) {
                            if (id === pulseSettings.ecoConeId)
                                return
                            pulseSettings.ecoConeId = id
                        } else {
                            if (id === pulseSettings.ecoViewId)
                                return
                            pulseSettings.ecoViewId = id
                        }
                    }
                }

                // THE PAUSED GUTTER (Stage 4 b). Takes the rail's place, never beside it.
                PulsePausedGutter {
                    id: pulsePausedGutter

                    visible: pulseSettings.uiVariant === "v2"
                             && pulseRuntimeSettings.echogramPause
                    enabled: visible

                    // THE FLOW, from the one flag the history bar already trusts for the
                    // same question. isHorizontalGrid is true for a 2D picture, which is
                    // the one that flows sideways and so wants its gutter at the foot.
                    alongFoot: pulseRuntimeSettings.isHorizontalGrid

                    // TWO ANCHORS THAT NEVER CHANGE, AND THE SIZE CARRIES THE ORIENTATION.
                    //
                    // The first version toggled anchors.top and anchors.right with
                    // `undefined`, and that is a trap: isHorizontalGrid DEFAULTS TO TRUE, so
                    // the gutter was born along the foot with anchors.right set - and
                    // assigning undefined to an anchor does NOT clear one that is already
                    // there. Flipping to a side scan then added the top anchor and kept the
                    // right, the gutter had all four, and it filled the window. Which is
                    // exactly what the device showed: 2D correct, side scan covering the
                    // picture with its panel and its controls centred on the screen.
                    //
                    // An anchor that is only ever set, never cleared, cannot get stuck.
                    anchors.left:   parent.left
                    anchors.bottom: parent.bottom
                    width:  alongFoot ? parent.width : inset
                    height: alongFoot ? inset        : parent.height

                    uiScale:    mainview.s
                    safeTop:    mainview.insetTop()
                    safeBottom: mainview.insetBottom()
                    safeLeft:   mainview.insetLeft()

                    onResumeRequested: mainview.setEchogramPaused(false)

                    // THE POSITION STILL LIVES WHERE IT LIVED. historyTimeLineScroll is
                    // assigned from both panes' onTimelinePositionChanged, so it stays the
                    // holder and the gutter BINDS to it - moving the bar is not the same
                    // idea as moving where the number is kept, and doing both in one commit
                    // would put two ideas on one slow device build.
                    timelinePosition: historyTimeLineScroll.timeLineScrollerPosition

                    // And a move does exactly what the old bar's handler did, in the same
                    // order. resetAim() matters: the crosshair is anchored to an epoch, and
                    // scrolling to a different part of the history leaves it pointing at a
                    // ping that is no longer under it.
                    onTimelineMovedByUser: function (pos) {
                        historyTimeLineScroll.timeLineScrollerPosition = pos
                        core.setTimelinePosition(pos)
                        core.resetAim()
                    }
                }

                // THE INDICATOR PILLS (Stage 4 a). Beside the rail and for the same reason:
                // what they report is app-wide rather than pane-wide, so one instance above
                // both panes. They draw ON the picture and take no width from it, so unlike
                // the setup card they owe the rail nothing - they sit on the right.
                PulsePillColumn {
                    id: pulsePillColumn

                    // The pills step aside with the rail. What the echogram IS matters while
                    // it is running; while it is frozen what matters is what is ON it.
                    visible: pulseSettings.uiVariant === "v2"
                             && !pulseRuntimeSettings.echogramPause
                    enabled: visible

                    anchors.fill: parent

                    uiScale:    mainview.s
                    safeTop:    mainview.insetTop()
                    safeBottom: mainview.insetBottom()
                    safeRight:  mainview.insetRight()

                    // RULE 1. Which corner is a question about the PICTURE: a side scan
                    // flows downward so its overlays belong at the foot, a 2D picture the
                    // other way up.
                    displayIs2D: pulseRuntimeSettings ? pulseRuntimeSettings.displayIs2DTransducer : true

                    // THE SPEED, IN ITS TWO JOBS. The runtime key is what the picture runs
                    // at and so what the pill says; the persistent key is what the user
                    // set and is the trigger only. PulsePillColumn explains why they are
                    // not one property.
                    echogramSpeed:        pulseRuntimeSettings ? pulseRuntimeSettings.echogramSpeed : 1.0
                    echogramSpeedSetting: pulseSettings        ? pulseSettings.echogramSpeed        : 1.0

                    presentingLog: pulseRuntimeSettings ? pulseRuntimeSettings.isPresentingLog : false
                    isDemo:        pulseRuntimeSettings ? pulseRuntimeSettings.isInDemoMode    : false
                    presentedName: pulseRuntimeSettings
                                   ? pulseRuntimeSettings.modelDisplayName(pulseRuntimeSettings.presentedModel)
                                   : ""

                    // Both already exist and both end the same way - the picture goes back
                    // to the transducer. Neither is reimplemented here.
                    onStopDemo: {
                        console.log("PILL: stopping the demo")
                        pulseRuntimeSettings.exitDemoMode()
                    }

                    // A QUESTION MUST NEVER OUTLIVE WHAT IT IS ABOUT. If recording stops or
                    // starts by any other route - the Recording tab is still there, and an
                    // opened file or a demo makes recording impossible - a standing question
                    // about it is stale, and answering it would act on a state that has
                    // already moved.
                    Connections {
                        target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                        function onIsRecordingKlfChanged() { pulsePillColumn.dismissQuestion() }
                        function onIsInDemoModeChanged()   { pulsePillColumn.dismissQuestion() }
                        function onWasKlfFileOpenedChanged(){ pulsePillColumn.dismissQuestion() }
                    }
                    onCloseFile: {
                        console.log("PILL: closing the file view")
                        pulseRuntimeSettings.exitFileView()
                    }

                    recording: pulseRuntimeSettings ? pulseRuntimeSettings.isRecordingKlf : false

                    // The same two lines the Recording tab writes, in the same order. This
                    // is the only place V2 writes them, and it is reached only through a
                    // question that has already been answered.
                    onStartRecording: {
                        console.log("PILL: recording confirmed - starting")
                        pulseRuntimeSettings.isRecordingKlf = true
                        core.loggingKlf = true
                    }
                    onStopRecording: {
                        console.log("PILL: stop confirmed - stopping")
                        pulseRuntimeSettings.isRecordingKlf = false
                        core.loggingKlf = false
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
        // STILL THE HOLDER, NO LONGER THE PICTURE. In v2 the paused gutter draws the bar,
        // so this one goes dark - but it keeps carrying timeLineScrollerPosition, which
        // both panes assign to and the gutter reads. One override on the component's own
        // binding, which is rule 2 rather than an assignment.
        visibleWhenPaused: pulseRuntimeSettings.echogramPause
                           && pulseSettings.uiVariant !== "v2"
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



    // Echogram speed change indication - CLASSIC ONLY.
    //
    // V2 says this in PulsePillColumn, in the family the rest of its overlays use, and
    // without this gate both would appear. The two are not the same indicator either:
    // this one triggers on the RUNTIME key, so under v2 it also popped up every time the
    // echogram was paused or resumed, announcing the 1.0 that setEchogramPaused writes to
    // freeze the horizontal scale. Nobody asked it anything.
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
                // Do NOT assign zoomText.text here. zoomText.text is a declarative
                // binding on pulseSettings.echogramSpeed (above); an imperative
                // assignment destroys that binding on the first change, after which the
                // label can only ever update from inside this handler. That is what made
                // a stale number stick on screen when the two properties were written
                // independently. This handler now only decides WHEN the indicator shows;
                // the binding decides WHAT it says.
                console.log("Echogram speed: New value", pulseRuntimeSettings.echogramSpeed,
                            "(persistent", pulseSettings.echogramSpeed + ")")
                // CLASSIC ONLY from here - see the comment on zoomIndicator. The line
                // above is a diagnostic Olav reads and it belongs to neither variant, so
                // the gate goes below it rather than at the top of the handler.
                if (pulseSettings.uiVariant === "v2")
                    return
                zoomIndicator.visible = true
                hideTimer.restart()
            }
        }
    }


    // DEVICE IDENTIFICATION, and the surface that asks when it fails.
    //
    // These Connections used to be nested inside echoSounderSelectorRect, which made them
    // look like chooser code. They are not: they are how the app learns what is on the
    // wire. The chooser around them is gone (see PulseConnectionScreen.qml); they are
    // hoisted here unchanged apart from the four echoSounderSelectorRect writes that
    // followed each detection, which the new screen reads from userManualSetName instead.
    Connections {
        target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
        // Force reselection and an accepted device swap both raise swapDeviceNow.
        // DeviceItem owns what that means - resetAllSetupStates(), userManualSetName
        // back to "...", and clearing the flag afterwards. This handler keeps the one
        // line of its old body that nothing else does: resetAllSetupStates() does not
        // clear devManualSelected.
        //
        // It deliberately no longer clears swapDeviceNow itself. This Connections
        // object is created at load and DeviceItem's is created later, so this handler
        // ran FIRST - and setting the flag false here re-entered the signal, leaving
        // DeviceItem's handler looking at a flag that was already false, so the reset
        // it exists to perform never ran at all. That is why force reselection left a
        // gray sheet with nothing under it (backlog item 10), and why an accepted swap
        // kept the previous device's orientation and colours on the bench. The order
        // PulseRuntimeSettings.acceptDeviceSwap() documents - reset synchronously,
        // then commit the target - only holds once this stops eating the flag.
        function onSwapDeviceNowChanged () {
            if (!pulseRuntimeSettings.swapDeviceNow)
                return
            console.log("DEV_RESELECT: raised in main - clearing devManualSelected;",
                        "DeviceItem owns the reset")
            pulseRuntimeSettings.devManualSelected = false
        }

        function onHasDeviceLostConnectionChanged() {
            //NO didEverReceiveData GATE, and its absence is the whole fix. BOTH arms used to
            //sit behind that flag - the show AND the remove - and every reset clears it
            //while only onDevNameChanged raises it. So the overlay could be put up while the
            //flag happened to be true, and then a reselection wiped it and this handler went
            //silent for the rest of the run: the box stayed on screen forever, through a
            //regained connection, a new choice and a complete reconfiguration.
            //
            //The gate was never needed here either. hasDeviceLostConnection is now raised
            //only when data WAS arriving and stopped, so by the time this runs the question
            //"did we ever receive anything" has already been answered by the thing that
            //raised it. showLostConnection() keeps its own guards for a file view and a demo.
            if (pulseRuntimeSettings.hasDeviceLostConnection)
                showLostConnection()
            else
                removeLostConnection()
        }

        function onDevNameChanged () {
            // EXPERIMENT: when dev.devType-driven detection is active, ConnectionViewer owns
            // model detection; disable the legacy devName-string path here to test it in isolation.
            if (pulseRuntimeSettings.useDevTypeDetection)
                return
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
                pulseRuntimeSettings.devManualSelected = true
                console.log("DEV_PARAM: Automatically detected device and set pulseRuntimeSettings.userManualSetName to", pulseRuntimeSettings.userManualSetName)
            } else {
                //ECHO20 has become "Basic2D"
                //TODO Still have not set the beta name. ow to do that?
                console.log("DEVICE: devName not auto selected, name is", pulseRuntimeSettings.devName);
            }
        }

        function onNumberOfDatasetChannelsChanged () {
            // EXPERIMENT: dev.devType-driven detection (ConnectionViewer) handles the Basic2D
            // channel split itself, so disable the legacy channel-based path here when active.
            if (pulseRuntimeSettings.useDevTypeDetection)
                return
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
            // Diagnostic: this is the ONLY thing that classifies an opened log as 2D or
            // side scan (activeModel reads the count), and it was silent. Log every
            // update, including the ones that return early, so a misclassified replay
            // says why in the application output instead of having to be reproduced.
            if (list.length < 2) {
                console.log("CHANNELS: list not ready yet (length", list.length,
                            ") - keeping", pulseRuntimeSettings.numberOfDatasetChannels)
                return
            }

            var channels = list.length - 1
            if (pulseRuntimeSettings.numberOfDatasetChannels !== channels)
                console.log("CHANNELS:", pulseRuntimeSettings.numberOfDatasetChannels, "->", channels,
                            "| list", JSON.stringify(list),
                            "|", channels >= 2 ? "side scan" : "2D")
            pulseRuntimeSettings.numberOfDatasetChannels = channels
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

            // PULSE: the auto-reboot "dataflow guard" (dataStaleTimer/guardTimer/resetTimer +
            // firstDataTs/guardActive) was removed. It was a band-aid for the old "stuck configuring
            // transducer" state caused by never binding a real 'dev'; that is now handled at the source
            // in selectCorrectDevice (which waits for an identified device before selecting). The guard
            // was also buggy: guardTimer.restart() was commented out, so guardActive never cleared and
            // the guard window was effectively infinite, rebooting on ANY data stall (e.g. battery
            // death). The manual expert reboot (echoSounderReboot) is intentionally kept.
        }
    }

    // PULSE: dataStaleTimer / guardTimer / resetTimer (the auto-reboot "dataflow guard") were
    // removed here. See the note in the dataset onDataUpdate handler above. Root cause (no bound
    // 'dev' -> stuck "Configuring transducer") is now handled in selectCorrectDevice; the manual
    // expert reboot remains the only reboot path.

    // THE PALETTE, APPLIED ONCE (Stage 4 b). pulseRuntimeSettings.displayThemeId is ONE
    // binding over blue's stored preference, red's stored preference and the display model;
    // this is the only thing that acts on it, and the only writer of colorMapIndexReal.
    //
    // BOTH PANES. The classic chooser lives inside Plot2D and talks to its own `plot`, so a
    // second pane keeps the previous palette - a split-screen defect nobody has had to look
    // at yet because the chooser is drawn twice there too. From here there is one theme and
    // two plots.
    //
    // GATED ON v2, because the classic chooser is still doing all of this its own way and
    // two writers of the same value is the thing being retired, not repeated.
    Connections {
        target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
        enabled: pulseSettings.uiVariant === "v2"
        function onDisplayThemeIdChanged() { mainview.applyDisplayTheme() }
    }

    Connections {
        target: pulseSettings ? pulseSettings : undefined

        // Switching INTO v2 has to apply everything v2 believes; classic may have left
        // something else in the plot, and nothing would push it until a value changed.
        function onUiVariantChanged() {
            if (pulseSettings.uiVariant !== "v2")
                return
            mainview.applyDisplayTheme()
            mainview.applyIntensity()
            mainview.applyWaterBodyFilter()
        }

        function onIntensityRealValueChanged() { mainview.applyIntensity() }
        function onFilterRealValueChanged()    { mainview.applyWaterBodyFilter() }

        function onEcoViewIdChanged() { mainview.applyViewId(pulseSettings.ecoViewId) }
        function onEcoConeIdChanged() { mainview.applyConeId(pulseSettings.ecoConeId) }
    }

    // THE RANGE FOLLOWS ITS STORED VALUE, whichever of the three keys the picture is using -
    // so it also follows the PICTURE changing, because that changes which key displayMaxRange
    // reads. A blue going from down scan to side scan gets side scan's own number back
    // without anything having to remember to restore it.
    Connections {
        target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
        enabled: pulseSettings.uiVariant === "v2"
        function onDisplayMaxRangeChanged() { mainview.applyMaxRange() }
    }

    // AND WHEN THE DEVICE CHANGES UNDER THE PREFERENCE. The stored id has not moved, so
    // neither handler above fires - but a newly committed transducer has to be told what it
    // is set to, which is what classic's onUserManualSetNameChanged did for both choosers.
    Connections {
        target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
        enabled: pulseSettings.uiVariant === "v2"
        function onUserManualSetNameChanged() {
            mainview.applyViewId(pulseSettings.ecoViewId)
            mainview.applyConeId(pulseSettings.ecoConeId)
        }
    }

    // The filter's OTHER input. Turning the water body filter on or off changes which of the
    // two calls carries the value, so the same function has to run again - the value did not
    // move, the meaning of it did.
    Connections {
        target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
        enabled: pulseSettings.uiVariant === "v2"
        function onEchogramWaterBodyFilterEnabledChanged() { mainview.applyWaterBodyFilter() }
    }

    // INTENSITY AND THE WATER BODY FILTER, applied the same way the palette is: one function,
    // both panes, gated on v2. Each stored value is a DISPLAY number the user moves and a
    // REAL number the renderer wants, and the two conversions are carried over verbatim from
    // the classic controls - real intensity is 120 - display*4, real filter is display*2.5.
    //
    // PulseAppV2.applyFiltering() is a deliberate no-op, which meant the water body filter
    // did nothing at all in v2. Plot2D calls that seam on a pinch; the filter's own value is
    // applied from here, so both routes end in the same place.
    function applyIntensity() {
        if (pulseSettings.uiVariant !== "v2")
            return
        var real = pulseSettings.intensityRealValue
        waterViewFirst.setIntensityValue(real * 1.0)
        if (waterViewSecond.enabled)
            waterViewSecond.setIntensityValue(real * 1.0)
        MosaicViewControlMenuController.onLevelChanged(pulseSettings.filterRealValue, real)
    }

    // THE BRANCH IS THE CLASSIC ONE, not a simplification of it. With the water body filter
    // enabled the strength is floored at echogramWaterBodyMinRealValue - a tester upgrading
    // into the default-on build can arrive with the slider at 0, which would leave the
    // filter inactive while the switch reads "on" - and the old global low cut is set to
    // zero. With it disabled the two swap over.
    function applyWaterBodyFilter() {
        if (pulseSettings.uiVariant !== "v2")
            return
        var real = pulseSettings.filterRealValue
        var panes = waterViewSecond.enabled ? [waterViewFirst, waterViewSecond] : [waterViewFirst]
        for (var i = 0; i < panes.length; ++i) {
            if (pulseRuntimeSettings.echogramWaterBodyFilterEnabled) {
                var wbf = Math.max(real, pulseRuntimeSettings.echogramWaterBodyMinRealValue)
                panes[i].setFilteringValue(0)
                panes[i].setWaterBodyFilter(wbf / 50.0)
            } else {
                panes[i].setWaterBodyFilter(0.0)
                panes[i].setFilteringValue(real)
            }
        }
        MosaicViewControlMenuController.onLevelChanged(real, pulseSettings.intensityRealValue)
    }

    // THE VIEW AND THE CONE - the committed device's own question, and the one tier-1 control
    // that writes to the TRANSDUCER rather than to the picture.
    //
    // The classic chooser applies inside onIconSelected, AND from a Connections on
    // userManualSetNameChanged, AND from a one-second startup timer - three call sites that
    // each have to remember the whole sequence. Here the stored id is the only input and
    // applying is what happens when it, or the committed device, moves.
    //
    // BY ID, NOT BY INDEX, and that is deliberate: viewForId() resolves an expert-only entry
    // that is hidden right now to the visible entry of the same MODE, so an expert's stored
    // 820 kHz choice survives leaving and re-entering expert mode without being transmitted
    // while the chooser is not showing it.
    // THE MAX RANGE, applied. The stored preference is the only input; the plot is told once,
    // on both panes, and the call depends on which way the picture runs.
    // ENTERING AND LEAVING THE PAUSE, in one place. The classic control does this inside a
    // checkbox handler, mixed in with the old-data warning machinery that lives beside it.
    //
    // THE SPEED SWAP IS THE PART THAT MATTERS. A 2D echogram scrolls at a configured speed;
    // while it is frozen that speed means nothing, so it goes to 1.0 and comes back from
    // pulseSettings on resume. Classic asks is2DTransducer - the COMMITTED device - and this
    // asks displayIs2DTransducer, which is a deliberate correction: echogram speed is about
    // the picture that is frozen, not about what is plugged in, and a blue log presenting on
    // a committed red would otherwise swap a speed that does not apply.
    function setEchogramPaused(paused) {
        if (pulseSettings.uiVariant !== "v2")
            return
        if (pulseRuntimeSettings.echogramPause === paused)
            return

        if (paused) {
            if (pulseRuntimeSettings.displayIs2DTransducer)
                pulseRuntimeSettings.echogramSpeed = 1.0
        } else {
            if (pulseRuntimeSettings.displayIs2DTransducer)
                pulseRuntimeSettings.echogramSpeed = pulseSettings.echogramSpeed
        }

        // A PANEL OVER A FROZEN PICTURE IS WRONG, and the button that opened it has just
        // gone with the rail. Same rule the rail's own collapse follows.
        if (paused)
            pulsePanel.openGroup = ""

        console.log("PAUSE:", paused ? "paused - inspecting" : "resumed")
        pulseRuntimeSettings.echogramPause = paused
    }

    function applyMaxRange() {
        if (pulseSettings.uiVariant !== "v2")
            return

        var v = pulseRuntimeSettings.displayMaxRange
        if (v <= 0)
            return

        pulseRuntimeSettings.manualSetLevel = v * 1.0

        var panes = waterViewSecond.enabled ? [waterViewFirst, waterViewSecond] : [waterViewFirst]
        for (var i = 0; i < panes.length; ++i) {
            panes[i].quickChangeMaxRangeValue = v
            if (panes[i].isViewHorizontal())
                panes[i].plotDistanceRange2d(v * 1.0)
            else
                panes[i].plotDistanceRange(v * 1.0)
            panes[i].updatePlot()
        }
    }

    function applyViewId(id) {
        if (pulseSettings.uiVariant !== "v2" || !pulseRuntimeSettings.offersViewChoice)
            return
        var v = pulseRuntimeSettings.viewForId(id)
        if (!v)
            return

        console.log("VIEW: applying", v.id, "-", v.mode, v.freq, "kHz")

        // Carried over verbatim from the classic applier. The mode decides the grid and the
        // range call; the frequency is a device parameter and DeviceItem picks it up.
        if (v.mode === "side") {
            pulseRuntimeSettings.isSideScan2DView = false
            pulseRuntimeSettings.isHorizontalGrid = false
            waterViewFirst.quickChangeMaxRangeValue = pulseSettings.maxDepthValuePulseBlueFixed
            plotDistanceRangeV2Timer.restart()
        } else {
            pulseRuntimeSettings.isSideScan2DView = true
            pulseRuntimeSettings.isHorizontalGrid = true
            pulseRuntimeSettings.chartOffset = 0
            plotDistanceRange2dV2Timer.restart()
        }
        pulseRuntimeSettings.transFreq = v.freq
    }

    function applyConeId(id) {
        if (pulseSettings.uiVariant !== "v2" || !pulseRuntimeSettings.offersConeChoice)
            return
        var c = pulseRuntimeSettings.coneForId(id)
        if (!c)
            return
        console.log("CONE: applying", c.id, "-", c.freq, "kHz")
        pulseRuntimeSettings.transFreq = c.freq
    }

    // THE TEN MILLISECONDS ARE THE CLASSIC ONES. The property writes above have to land
    // before the plot is told to re-range, or it ranges against the grid it is leaving.
    Timer {
        id: plotDistanceRangeV2Timer
        repeat: false
        interval: 10
        onTriggered: {
            waterViewFirst.setVerticalNow()
            waterViewFirst.plotDistanceRange(waterViewFirst.quickChangeMaxRangeValue * 1.0)
            waterViewFirst.updatePlot()
        }
    }

    Timer {
        id: plotDistanceRange2dV2Timer
        repeat: false
        interval: 10
        onTriggered: {
            waterViewFirst.setHorizontalNow()
            waterViewFirst.plotDistanceRange2d(waterViewFirst.quickChangeMaxRangeValue * 1.0)
            waterViewFirst.updatePlot()
        }
    }

    function applyDisplayTheme() {
        if (pulseSettings.uiVariant !== "v2")
            return

        var id = pulseRuntimeSettings.displayThemeId
        console.log("THEME: applying", id, "to the panes")

        waterViewFirst.plotEchogramTheme(id)
        waterViewFirst.updatePlot()
        if (waterViewSecond.enabled) {
            waterViewSecond.plotEchogramTheme(id)
            waterViewSecond.updatePlot()
        }

        // The 3D side-scan mosaic follows the echogram, as it does in classic.
        // onThemeChanged() applies themeId+1 internally, which matches the mosaic's
        // PlotColorTable enum offset. Ids 0-4 are shared; HQ Orange (26) has no mosaic
        // equivalent yet and the mosaic keeps its previous colour there.
        MosaicViewControlMenuController.onThemeChanged(id)

        // THE ONE WRITER of the shared key, which main.qml publishes to the C++ over the
        // settings bus. Six writers is what made it untrustworthy.
        pulseSettings.colorMapIndexReal = id
    }

    // THE DEPTH ENGINE (Stage 4 b). One instance, above both Plot2D panes, for the reason
    // the connection screen and the pill column are: what it does is app-wide. It was
    // reachable only through DepthAndTemperature.qml, which PulseAppV2 does not
    // instantiate - so in v2 nothing wrote dynamicSamples, dynamicPeriod or
    // autoDepthMaxLevel and the sounder ran at the defaults at every depth.
    PulseDepthEngine {
        id: pulseDepthEngine
    }

    // THE CONNECTION SCREEN (Stage 4, step 1). One instance, above both Plot2D panes.
    // Replaces echoSounderSelectorRect, freeContainer, both EchoSounderSelector panels and
    // the windowShadow sheet. Everything it shows hangs off one binding, chooserAsking.
    PulseConnectionScreen {
        id: pulseConnectionScreen
        uiScale:    mainview.s
        safeTop:    mainview.insetTop()
        safeBottom: mainview.insetBottom()
        safeLeft:   mainview.insetLeft()
        safeRight:  mainview.insetRight()
    }

    // THE SETUP OVERLAY (Stage 4, step 6). One instance, above both Plot2D panes, for the
    // same reason the chooser is: PulseApp is instantiated inside Plot2D, so the block this
    // replaces - configurationInProgressIndicator in PulseAppClassic - was drawn once per
    // pane, with no gate at all.
    PulseSetupOverlay {
        id: pulseSetupOverlay
        uiScale:    mainview.s
        safeTop:    mainview.insetTop()
        safeBottom: mainview.insetBottom()
        // THE CARD AND THE MARKER DRAW ON THE ECHOGRAM, and the echogram no longer starts
        // at the screen edge. Both are placed at `safeLeft + 28`, so adding the rail's
        // width here is the whole fix - nothing inside that file has to know the rail
        // exists. The connection screen deliberately does NOT do this: it is full-bleed
        // above everything and covers the rail as well.
        safeLeft:   mainview.insetLeft() + mainview.pulseRailInset
        safeRight:  mainview.insetRight()
    }

}
