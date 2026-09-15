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
                pulseRuntimeSettings.setParam("processBottomTrack", true)
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
        //THE SIDE-SCAN MOUNTING MIRROR, WHICH ONLY CLASSIC HAD. isSideScanLeftHand is the
        //runtime key the bus carries to Plot2D and the grid; the persistent one is
        //isSideScanOnLeftHandSide. main.qml copied it at startup and on a link event, but
        //the only ON-CHANGE mirror lived inside PulseInfoSettings.qml and
        //PulseAppClassic.qml - both classic. So under v2 the mounting switch would store a
        //value the picture never heard about. One handler here answers for both variants.
        function onIsSideScanOnLeftHandSideChanged () { pulseRuntimeSettings.isSideScanLeftHand = pulseSettings.isSideScanOnLeftHandSide            }
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
    readonly property var runtimeKeysQmlOwns: ["uiVariantIsV2",
                                               "echogramTvgEnabled",
                                               "sideScanTvgEnabled",
                                               "sideScanTvgMosaicEnabled"]

    Connections {
        target: settingsBus
        function onRuntimeChanged(m) {
            //dumpMap("settingsBus.runtimeChanged", m)
            for (var k in m) {
                if (mainview.runtimeKeysQmlOwns.indexOf(k) !== -1) {
                    continue
                }
                // AND A MANAGED DEVICE PARAMETER IS QML-OWNED TOO, by a different
                // mechanism. These are readonly and live in the per-profile parameter map,
                // so this write-back can only produce "Cannot assign to read-only property"
                // - which is exactly what maximumDepth did on the first build after the
                // conversion, from a DYNAMIC write by string that no static scan could
                // find.
                //
                // Skipping loses nothing: the C++ never pushes one of these. It publishes
                // devName and a few uuid keys and nothing else, so every managed key on
                // this signal is a value QML sent out and is being handed back.
                //
                // Asked of pulseRuntimeSettings rather than listed here, so the managed set
                // is written down once.
                if (pulseRuntimeSettings && pulseRuntimeSettings.isManagedParam(k)) {
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

            // THE FILE-OPEN PATH'S CALL, and it is here rather than beside any one of the
            // file dialogs because THIS is where every route to an opened file arrives -
            // the connection screen's "View a file", the drag and drop above, and the menu
            // bar's open. A call at each dialog would be three places to forget, which is
            // the shape Group B is about in the first place.
            //
            // ON THE FALLING EDGE, when the open has finished. The picture cannot be set up
            // from a file that is still being read, and the channel list that says what the
            // log IS has not arrived while this is true.
            if (!isFileOpening && pulseRuntimeSettings.wasKlfFileOpened)
                pulseRuntimeSettings.sourceChosen("file")

            if (isFileOpening) {
                pulseRuntimeSettings.wasKlfFileOpened = true

                // THE SCREEN COMES DOWN THE MOMENT THE FILE STARTS, not when it finishes.
                // Committing a card and starting a demo both answer the source question;
                // opening a file answered nothing, so the connection screen the user went
                // through to reach "View a file" stayed up over the file it had loaded.
                // Same two flags, same function, and on the RISING edge because the answer
                // was given when the file was chosen, not when it finished reading.
                pulseRuntimeSettings.answerSourceQuestion("opening a file")

                // AND A RUNNING DEMO IS STOPPED, because two sources feeding one picture is
                // not a picture. Here rather than beside the dialog for the reason the
                // clear above is here - every route to an opened file passes through this
                // handler - and AFTER wasKlfFileOpened is raised, so logIsOnScreen never
                // drops between the two and the connection screen cannot flash back over
                // the file that is loading.
                pulseRuntimeSettings.stopDemoPlayback("a file was opened")
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
            // ── WHICH PICTURES ARE ON SCREEN (14 Sept 2026) ──────────────────────────────────
            //
            // The screen preference is the single source of truth, and it is a BINDING rather
            // than a flag somebody sets. That was not possible a commit ago: the green pill
            // assigned mosaicViewActive, so a binding on the same value would have been
            // destroyed the first time it was tapped. Removing the pill is what allows the
            // rule this project keeps - one binding, one override, never an assignment - to be
            // kept here at last.
            //
            // The pill itself was never Pulse's control. It is upstream's draggable split
            // divider, repurposed as a tap toggle and painted green. Its geometry survives
            // below - splitRatio, the snap ratios, the preview band - because the splits it
            // was written for are exactly what arrives now.
            //
            // The GraphicsScene3dView object stays instantiated whatever this says
            // (renderer.visible follows it) so Core::UILoad's findChild wiring stays intact.
            //
            // NOTHING TRIGGERS THE MOSAIC. Olav: "I need do nothing to trigger mosaic. Simply
            // need to show it and mosaic will paint. First with history before it catches up
            // the live data." So showing the pane IS the feature; there is no start call to
            // make and no state to arm.
            readonly property var screenEntry:
                (pulseSettings.uiVariant === "v2" && pulseRuntimeSettings
                 && pulseRuntimeSettings.offersScreenChoice)
                ? pulseRuntimeSettings.screenForId(pulseSettings.screenViewId)
                : null

            readonly property bool wantsMosaic:
                screenEntry ? (screenEntry.top === "mosaic" || screenEntry.bottom === "mosaic")
                            : false
            // BOTH HALVES ARE ECHOGRAMS - the one layout that needs a second Plot2D rather
            // than the 3D scene, and the only one that could not be built out of geometry
            // alone. See Plot2D::applyRuntime for why.
            readonly property bool splitEchograms:
                screenEntry ? (screenEntry.top !== "mosaic"
                               && screenEntry.bottom !== ""
                               && screenEntry.bottom !== "mosaic")
                            : false

            readonly property bool wantsEchogram:
                screenEntry ? (screenEntry.top !== "mosaic"
                               || (screenEntry.bottom !== "" && screenEntry.bottom !== "mosaic"))
                            : true

            // Toggle is only offered when the 3D/mosaic view is meaningful: a side-scan transducer
            // is attached (NOT a 2D/downscan-only model) AND we have position data — live MAVLink
            // (mavlinkDetected, same flag that greens the play/pause checkbox) OR a loaded log file
            // (so file-replay testing still works). Relax this line for broader internal testing.
            readonly property bool view3dToggleAvailable:
                !pulseRuntimeSettings.is2DTransducer
                && (pulseRuntimeSettings.mavlinkDetected || (core.filePath && core.filePath.length > 0))

            // NO HANDLER. has3DView reads view3dToggleAvailable directly, so losing the fix
            // drops the mosaic and regaining it brings the mosaic back, both without anything
            // being told. The handler this replaces had to force a flag false and then ask the
            // applier to run again, which is two mechanisms for one fact.

            // THE CONTROL SURFACE TAKES ITS WIDTH FROM THE PICTURE RATHER THAN COVERING IT,
            // and now it takes it from BOTH pictures. This was one anchors.leftMargin on the
            // 2D GridLayout while the rail lived inside plotsContainer; the rail is a sibling
            // of both containers now, so the inset belongs to the area they share.
            //
            // Zero in the classic UI and zero while the rail is collapsed, both through the
            // rail's own `inset`, so there is still no second mechanism to keep in step.
            readonly property real controlInset: mainview.pulseRailInset + mainview.pulsePanelInset
            readonly property real contentWidth: Math.max(0, width - controlInset)

            // THE MOSAIC IS NOT ALWAYS POSSIBLE - it wants a side scan transducer and a
            // position - so availability is ANDed in here rather than checked at the point of
            // choosing. A stored preference for the mosaic then costs nothing while there is
            // no fix and takes effect the moment one arrives, with no handler to run.
            readonly property bool has3DView: wantsMosaic && view3dToggleAvailable
            // AND THE ECHOGRAM HOLDS THE SCREEN when the mosaic was asked for and cannot be
            // drawn. Never nothing at all.
            readonly property bool has2DView: wantsEchogram || !has3DView
            readonly property bool splitActive: has3DView && has2DView
            readonly property real primaryLength: landscapeMode ? contentWidth : height
            readonly property real splitLength: Math.max(0, primaryLength)
            // THE FIRST PANE IS THE ECHOGRAM NOW, where it used to be the 3D scene. "Side scan
            // first" survives the axis rule as LEADING POSITION rather than as "top": top in
            // portrait, left in landscape. Everything below measures from the first pane, so
            // this one line is the swap.
            readonly property real firstPaneLength: splitActive
                                                    ? Math.round(splitLength * splitRatio)
                                                    : (has2DView ? primaryLength : 0)
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
                // THE SECOND PANE, and after the rail. The mosaic is a picture the user
                // adjusts, so the controls compress it rather than sit on top of it, and the
                // echogram leads - left in landscape, top in portrait.
                //
                // firstPaneLength is the whole content when the echogram is alone, zero when
                // the mosaic is alone, and the split position when both are up. So these four
                // lines cover all three cases with no case in them.
                x: visualisationLayout.controlInset
                   + (visualisationLayout.landscapeMode ? visualisationLayout.firstPaneLength : 0)
                y: visualisationLayout.landscapeMode ? 0 : visualisationLayout.firstPaneLength
                width: visualisationLayout.landscapeMode
                       ? Math.max(0, visualisationLayout.primaryLength - visualisationLayout.firstPaneLength)
                       : visualisationLayout.contentWidth
                height: visualisationLayout.landscapeMode
                        ? visualisationLayout.height
                        : Math.max(0, visualisationLayout.primaryLength - visualisationLayout.firstPaneLength)
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

            Item {
                id: plotsContainer
                visible: visualisationLayout.has2DView
                // THE FIRST PANE. It starts at the rail and runs for firstPaneLength, which is
                // the whole content area when it is alone and zero when the mosaic is.
                x: visualisationLayout.controlInset
                y: 0
                width: visualisationLayout.landscapeMode
                       ? visualisationLayout.firstPaneLength
                       : visualisationLayout.contentWidth
                height: visualisationLayout.landscapeMode
                        ? visualisationLayout.height
                        : visualisationLayout.firstPaneLength

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
                    // THE LEFT INSET MOVED UP with the rail, onto plotsContainer's own x and
                    // width - see visualisationLayout.controlInset. Applying it here as well
                    // would take the width twice.
                    //
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

                        // THE SCREEN PREFERENCE DECIDES IN V2, numPlots in classic. numPlots is
                        // the old Display-settings spin box, and it has no idea the screen
                        // chooser exists.
                        enabled: pulseSettings.uiVariant === "v2"
                                 ? visualisationLayout.splitEchograms
                                 : menuBar.numPlots === 2
                        visible: enabled

                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        Layout.rowSpan   : 1
                        Layout.columnSpan: 1
                        focus: true
                        instruments: menuBar.instruments
                        indx: 2

                        onEnabledChanged: {
                            waterViewSecond.setPlotEnabled(enabled)
                            // AND RE-APPLY, because this pane's grid is pinned by
                            // applyScreenId and the order in which a binding and a handler
                            // land is not something to rely on. Re-applying is free; a pane
                            // that came up with the wrong grid is a device build.
                            if (pulseSettings.uiVariant === "v2")
                                mainview.applyScreenId(pulseSettings.screenViewId)
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

            // ---- THE V2 CONTROL SURFACE, one level up (14 Sept 2026) ----------------
            //
            // These four were children of plotsContainer, which is `visible: has2DView`.
            // So the whole control surface vanished the moment the mosaic went full screen:
            // no rail, no panel, no pills, no gutter, and - once the screen preference is
            // persisted and the pill is gone - no way back out of the mosaic at all.
            //
            // It is the SAME move the rail already made once, one level further. Stage 4 (a)
            // took it out of Plot2D because qPlot2D paints across its whole item and nothing
            // built inside a pane can take width from the picture. The same reasoning does not
            // stop at the 2D pane: the mosaic is a picture too, and a split puts a pane of each
            // on screen at once. Anything that serves both has to be their SIBLING, which is
            // here.
            //
            // Their anchors are unchanged - parent.left / top / bottom - because the new parent
            // is the whole visualisation area rather than the 2D half of it, which is exactly
            // what they should have been measuring against.



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
                offersScreen: pulseRuntimeSettings ? pulseRuntimeSettings.offersScreenChoice : false
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
                    //
                    // THIS LIST IS THE SECOND PLACE A BUTTON ID IS WRITTEN, and it is why
                    // renaming "view" to "screen" on the rail produced a button that
                    // emitted, was heard, and fell through to the "arrives later" line
                    // below - the panel never opened and nothing looked broken. A rail id
                    // has to be spelled the same in PulseRail and here; there is no third
                    // place, and the console line at the bottom is what says so.
                    if (id === "colours" || id === "intensity" || id === "filter"
                            || id === "screen" || id === "cone" || id === "range"
                            || id === "settings") {
                        pulsePanel.openGroup = (pulsePanel.openGroup === id) ? "" : id
                        console.log("PANEL:", pulsePanel.openGroup === "" ? "closed" : "showing " + id)
                        return
                    }

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

                // THE ONE WRITER for every setting the tier-2 list carries. The rows
                // bind their values and report a change; this assigns it, and nothing
                // else does. `target` says which of the two objects owns the key -
                // persistent for pulseSettings, which is where a value survives a
                // restart, runtime for pulseRuntimeSettings, which is what reaches C++.
                //
                // Writing by string works because this is an assignment; a BINDING
                // cannot be formed on a string key, which is exactly why the rows bind
                // their reads explicitly instead of being described as data.
                // ONE RULE, NOT A SECOND COPY OF IT. applyKeyCode lives on
                // pulseRuntimeSettings so that classic's KeyCodeInput and this list
                // reach the same answer; the salt is handed in because this is the
                // side that can see installToken.
                onKeyCodeEntered: function (code) {
                    if (!pulseRuntimeSettings)
                        return
                    pulseRuntimeSettings.applyKeyCode(code, installToken.currentSalt)
                }

                // THE ACTIONS THE SETTINGS LIST CAN ASK FOR. Each raises the flag its
                // existing consumer already watches and clears - echoSounderReboot is
                // cleared by DeviceItem.qml:1984, reconfigureNow by :2014 - so nothing
                // new decides when an action is finished.
                onActionRequested: function (id) {
                    if (!pulseRuntimeSettings) {
                        console.log("SETTINGS: no runtime object for action", id)
                        return
                    }
                    if (id === "restart") {
                        console.log("SETTINGS: action - restart the echo sounder")
                        pulseRuntimeSettings.echoSounderReboot = true
                        return
                    }
                    // RESET DOES THE WORK RATHER THAN RAISING A FLAG.
                    //
                    // The flag was copied from classic, where the behaviour lives in a
                    // Connections block INSIDE PulseInfoExpert.qml - a classic control
                    // v2 never instantiates - so under v2 the flag went up and nothing
                    // watched it.
                    //
                    // And classic's version does not work either, for a different
                    // reason: it sets fakeDepthAddition to 0, which re-syncs the
                    // control's thumb, but the control has emitOnUserActionOnly so
                    // dataset.setFakeDepthAddition(0) is never called and the C++
                    // offset stays. It also raises resetBottomTrackActive, which is
                    // declared once in PulseRuntimeSettings and read NOWHERE in any
                    // .qml or .cpp. Both halves are dead.
                    //
                    // So this clears the number where the number actually lives.
                    if (id === "resetFakeDepth") {
                        console.log("SETTINGS: action - back to the real depth")
                        pulseRuntimeSettings.fakeDepthAddition = 0
                        if (dataset)
                            dataset.setFakeDepthAddition(0)
                        return
                    }
                    if (id === "reconfigure") {
                        console.log("SETTINGS: action - reconfigure the transducer")
                        pulseRuntimeSettings.reconfigureNow = true
                        return
                    }
                    console.log("SETTINGS: unknown action", id)
                }

                onSettingChanged: function (target, key, value) {
                    // A THIRD TARGET, and it is not a third object. "param" is a
                    // MANAGED DEVICE PARAMETER: readonly, living in the per-profile
                    // live parameter map, and reachable only through setParam(). The
                    // row declares which kind of key it is writing, so this handler
                    // does not have to carry a list of which names are special - a
                    // list that would fall out of step the first time one is added.
                    if (target === "param") {
                        if (pulseRuntimeSettings)
                            pulseRuntimeSettings.setParam(key, value)
                        return
                    }

                    var obj = (target === "runtime") ? pulseRuntimeSettings : pulseSettings
                    if (!obj) {
                        console.log("SETTINGS: no", target, "object for", key)
                        return
                    }
                    if (obj[key] === value)
                        return
                    console.log("SETTINGS:", target, key, "->", value)
                    obj[key] = value

                    // THE ONE KEY WHOSE CONSUMER IS A CALL, NOT A BINDING.
                    // pulseRuntimeSettings.fakeDepthAddition is read by nothing -
                    // dataset._fakeDepthAddition is what actually shifts the depth, and
                    // classic's control sets the property AND calls the setter. Writing
                    // the property alone, as the generic path does, changed a number
                    // nobody reads. Handled here rather than in the row, because this
                    // is the side that can see `dataset`.
                    if (key === "fakeDepthAddition" && dataset)
                        dataset.setFakeDepthAddition(value)
                }

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
                    // ONE CALL, because this block was the app's only complete-ish apply
                    // and it ran once, at startup. It is now the startup CALLER of the
                    // shared list rather than a second copy of it - so a value added to
                    // that list is applied at startup too, without this block being
                    // remembered.
                    mainview.applyForSource("startup")
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

                // ---- The screen ---------------------------------------------
                //
                // DISPLAY, not committed - the one line that separates this chooser
                // from the two above it. What the screen shows is judged by looking at
                // it, so it follows the display model and a side scan log keeps its
                // layouts whatever is plugged in.
                screenEntries:   pulseRuntimeSettings ? pulseRuntimeSettings.screenViews : []
                screenCurrentId: pulseRuntimeSettings
                                 ? pulseRuntimeSettings.resolveScreenId(pulseSettings.screenViewId)
                                 : ""
                screenCaption: qsTr("What the screen shows. Side scan sits on top in every split.")

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

                // A REAL TAP IS THE ONLY THING THAT WRITES THE PREFERENCE, the same
                // rule the view and cone choosers follow: resolveScreenId() answers
                // "what should be showing" for a stored layout that is not offered
                // today, and never writes that answer back over the user's own choice.
                onScreenChosen: function (id) {
                    if (id === pulseSettings.screenViewId)
                        return
                    console.log("SCREEN: chosen", id)
                    pulseSettings.screenViewId = id
                }

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

                // OLD DATA, AS A BINDING ON THE ONE HOLDER OF THE POSITION.
                // historyTimeLineScroll is assigned from both panes and is what the
                // paused gutter already binds to, so there is no second idea of where
                // the timeline is. Suppressed for an opened file, where scrolling is
                // the point rather than a mistake - classic's own condition.
                scrolledBack: pulseRuntimeSettings
                              && !pulseRuntimeSettings.wasKlfFileOpened
                              && historyTimeLineScroll.timeLineScrollerPosition < 0.999

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

                // BACK TO LIVE - the same three things, in the same order, that a move
                // of the history bar does. resetAim() matters for the same reason: the
                // crosshair is anchored to an epoch, and the head is a different one.
                onGoLive: {
                    console.log("PILL: back to live from a scrolled-back echogram")
                    historyTimeLineScroll.timeLineScrollerPosition = 1
                    core.setTimelinePosition(1)
                    core.resetAim()
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

        function onScreenViewIdChanged() { mainview.applyScreenId(pulseSettings.screenViewId) }
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
    //
    // THIS WAS THE COMMIT PATH'S OWN SHORT LIST and is now a call to the shared one. It kept
    // two of the six applies, which is why committing a card left the intensity, the water
    // body filter and the max range wherever the last source had put them.
    Connections {
        target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
        enabled: pulseSettings.uiVariant === "v2"
        function onUserManualSetNameChanged() { mainview.applyForSource("commit") }
    }

    // THE OTHER TWO PATHS, and the settle that neither of them can do synchronously.
    //
    // sourceChosen is emitted by enterDemoMode and by the file-open path - see
    // PulseRuntimeSettings and the core.onSendIsFileOpening handler above. That is the
    // backlog's "called from the commit path AND the file-open path AND the demo-start
    // path", and it is the whole of the Group B fix shape.
    //
    // AND presentedModel, which is the part a call at the moment of choosing cannot cover.
    // A log does not say what it is until its channel list arrives, so activeModel - and
    // with it every key the appliers read - moves some frames AFTER the file was chosen.
    // Applying again when it moves is what makes the picture self-adapt to the log, which
    // is the thing Olav named as the source of the whole group. It costs a repaint when
    // nothing needed changing, and it is silent when the log matches what was committed -
    // which is exactly the case he reported as already working.
    Connections {
        target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
        enabled: pulseSettings.uiVariant === "v2"
        function onSourceChosen(reason) { mainview.applyForSource(reason) }
        function onPresentedModelChanged() {
            mainview.applyForSource("presenting " + pulseRuntimeSettings.presentedModel)
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

    // A SOURCE HAS BEEN CHOSEN - APPLY EVERYTHING THE PICTURE NEEDS (Group B).
    //
    // THE ONE LIST, and the reason it exists is that there were two partial ones. Committing
    // a card ran applyScreenId and applyConeId; the colour block's Component.onCompleted ran
    // applyIntensity, applyWaterBodyFilter, applyMaxRange and applyScreenId, once, at
    // startup. Nothing ran the whole set, and a demo or a file opened after startup ran none
    // of it - which is every symptom in Group B of the backlog in one sentence.
    //
    // EVERY apply IS IDEMPOTENT AND EVERY ONE IS GATED ON v2 ITSELF, so calling this twice
    // costs a repaint and nothing else. That matters, because it is called twice on purpose:
    // once when the source is chosen, and again when the picture's identity settles (see the
    // presentedModel handler below). A file does not know whether it is 2D or side scan
    // until its channel list arrives, which is several frames after the dialog closed.
    //
    // RANGE LAST, and that is ordering rather than taste: applyScreenId -> applyEchogramMode
    // writes isSideScan2DView, and that property is what decides WHICH of the three stored
    // range keys displayMaxRange reads. Range first would apply the outgoing mode's number.
    function applyForSource(reason) {
        if (pulseSettings.uiVariant !== "v2")
            return

        console.log("SOURCE:", reason, "-> applying the picture's settings |",
                    pulseRuntimeSettings.presentedModel,
                    "|", pulseRuntimeSettings.displayIs2DTransducer ? "2D" : "side scan",
                    "| range key", pulseRuntimeSettings.displayMaxRangeKey)

        applyDisplayTheme()
        applyIntensity()
        applyWaterBodyFilter()
        applyScreenId(pulseSettings.screenViewId)
        applyConeId(pulseSettings.ecoConeId)
        applyMaxRange()
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

        // AND C++ HAS TO KNOW, because the demo's end-of-file restart lives there and a
        // restart under a pause wipes the pipeline out from under a frozen picture. This
        // is the only place the pause is written, so it is the only place that tells it.
        // Harmless when no demo is running - Core keeps the flag and acts on it only when
        // a restart is actually being held.
        core.setDemoPaused(paused)
    }

    // THE SECOND PANE, ranged for its own grid. It asks the pane rather than being told,
    // the same way applyMaxRange does, so the two cannot disagree about which grid pane 2
    // is on.
    //
    // THE VALUE IS STILL THE FIRST PANE'S, and that is the parked per-pane range question
    // showing through: the side half's range is a swath width and the down half's is a
    // depth, and until there is somewhere to keep two numbers they share one.
    function rangeSecondPane() {
        if (!waterViewSecond.enabled)
            return
        var v = waterViewFirst.quickChangeMaxRangeValue * 1.0
        if (v <= 0)
            return
        waterViewSecond.quickChangeMaxRangeValue = v
        if (waterViewSecond.isViewHorizontal()) {
            waterViewSecond.setHorizontalNow()
            waterViewSecond.plotDistanceRange2d(v)
        } else {
            waterViewSecond.setVerticalNow()
            waterViewSecond.plotDistanceRange(v)
        }
        waterViewSecond.updatePlot()
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

    // THE SCREEN PREFERENCE REACHES THE PICTURE (Stage 4 b). This is what applyViewId below
    // used to do, minus the half that was never the screen's business.
    //
    // ONLY THE THREE FULL SCREENS ACT TODAY, on Olav's own sequencing: "The first ability to
    // implemented could be the three full screen options as the top three choices." They are
    // also exactly what the green pill does - "that is the only way I can swap between mosaic
    // and the side scan view I have" - which is why the pill stays until these are proven on
    // the water. Removing his only route to the mosaic before the replacement works would
    // leave him with no route at all.
    //
    // A SPLIT CHANGES NOTHING YET, and that is declined rather than missing: the row is
    // chosen, the preference is stored, and the picture holds whatever full screen it had.
    // The split axis is still an open question - see the note in the strategy document.
    //
    // THE PILL IS STILL ITS OWN WRITER in the meantime, so tapping it moves the picture
    // without moving the preference. Deliberately not fixed here: the pill is not gated on
    // the v2 variant, so teaching it to write screenViewId would change the classic UI too.
    function applyScreenId(id) {
        if (pulseSettings.uiVariant !== "v2" || !pulseRuntimeSettings.offersScreenChoice)
            return
        var e = pulseRuntimeSettings.screenForId(id)
        if (!e)
            return

        console.log("SCREEN: applying", e.id, "- top", e.top,
                    e.bottom === "" ? "(full screen)" : "+ bottom " + e.bottom)

        // WHICH PANES ARE UP IS NOT THIS FUNCTION'S BUSINESS ANY MORE. visualisationLayout
        // binds them straight to this preference, so a layout with a mosaic in it needs
        // nothing done to it - showing the pane is the whole of the feature.
        //
        // What is left is the echogram's own mode, because that is a device-side write and a
        // re-range rather than a piece of geometry. A layout with no echogram in it leaves
        // the mode exactly as it was rather than guessing at one.
        var firstMode = (e.top !== "mosaic")
                        ? e.top
                        : ((e.bottom !== "" && e.bottom !== "mosaic") ? e.bottom : "")
        var secondMode = (e.top !== "mosaic" && e.bottom !== "" && e.bottom !== "mosaic")
                         ? e.bottom
                         : ""

        if (firstMode !== "")
            applyEchogramMode(firstMode)

        // ONE BINDING AND ONE OVERRIDE, in the only shape the settings bus allows. The bus is
        // a broadcast, so the LEADING pane follows it - applyEchogramMode has just set what it
        // carries - and the second pane is the single exception, pinned to the other grid.
        // Everything else in the app that reads isSideScan2DView therefore agrees with the
        // pane at the top, which is the one the user is looking at.
        waterViewFirst.setGridMode("")
        waterViewSecond.setGridMode(secondMode)

        // THE SECOND PANE IS RANGED BY THE TIMERS, not from here. Calling applyMaxRange()
        // at this point was wrong for the reason the ten milliseconds exist at all: it
        // ranges the plot BEFORE setVerticalNow/setHorizontalNow has landed, so the picture
        // is ranged against the grid it is leaving, and then ranged again when the timer
        // fires. One re-range, after the writes, in the one place that already does it.
    }

    // THE MODE HALF, lifted out of applyViewId unchanged. The property writes decide the grid
    // and which range call is made; the ten milliseconds in the timers are the classic ones,
    // because the writes have to land before the plot is told to re-range or it ranges
    // against the grid it is leaving.
    //
    // WHAT DID NOT COME WITH IT is setParam("transFreq", ...). A screen layout is not a
    // frequency and never was the screen's business - the view chooser answered two questions
    // at once, and this is the half that is genuinely about the screen. Nothing is lost today
    // because every view blue offers is 460 kHz; a frequency chooser returns when power is
    // fixed.
    // THE STORED RANGE IS READ THROUGH displayMaxRange, ONCE, and that is the whole of the
    // change here. This function used to name a key: the side branch assigned
    // pulseSettings.maxDepthValuePulseBlueFixed by hand, and the down branch assigned
    // NOTHING - so entering down scan re-ranged the plot against whatever number the mode
    // it was leaving had left in quickChangeMaxRangeValue, and the two grids shared one
    // value by accident rather than keeping the separate ones that are already stored.
    //
    // displayMaxRangeKey exists precisely so a key is never spelled out twice; a write
    // keyed differently from the read is how a value lands in one preference and is read
    // out of another, which the strategy document records twice. Reading the derived value
    // here means the side half gets its swath width back and the down half gets its depth,
    // and neither branch knows a key name.
    //
    // ORDER IS LOAD-BEARING: displayMaxRange is a binding over displayMaxRangeKey, which is
    // a binding over isSideScan2DView. Reading it BEFORE the mode write returns the
    // outgoing mode's number, which is the bug this is fixing, one line earlier.
    function applyEchogramMode(mode) {
        // isSideScan2DView reads backwards and is not renamed here - TRUE means the blue is
        // in DOWN scan, as PulseRuntimeSettings says at displayMaxRangeKey.
        var down = (mode !== "side")

        pulseRuntimeSettings.isSideScan2DView = down
        pulseRuntimeSettings.isHorizontalGrid = down
        if (down)
            pulseRuntimeSettings.setParam("chartOffset", 0)

        var v = pulseRuntimeSettings.displayMaxRange
        if (v > 0)
            waterViewFirst.quickChangeMaxRangeValue = v

        // The ten milliseconds are the classic ones - see the timers below.
        if (down)
            plotDistanceRange2dV2Timer.restart()
        else
            plotDistanceRangeV2Timer.restart()
    }

    // DEAD FROM THIS COMMIT, and kept only until the view chooser is removed with the rest of
    // what it belonged to. Nothing calls it: the rail opens "screen" rather than "view", so
    // ecoViewId can no longer be written and its change handler is gone.
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
            pulseRuntimeSettings.setParam("chartOffset", 0)
            plotDistanceRange2dV2Timer.restart()
        }
        pulseRuntimeSettings.setParam("transFreq", v.freq)
    }

    function applyConeId(id) {
        if (pulseSettings.uiVariant !== "v2" || !pulseRuntimeSettings.offersConeChoice)
            return
        var c = pulseRuntimeSettings.coneForId(id)
        if (!c)
            return
        console.log("CONE: applying", c.id, "-", c.freq, "kHz")
        pulseRuntimeSettings.setParam("transFreq", c.freq)
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
            // AND THE SECOND PANE, which is the other grid by definition - it only exists in
            // side over down. It is ranged the way ITS grid wants, not the way this one does.
            if (waterViewSecond.enabled)
                mainview.rangeSecondPane()
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
            if (waterViewSecond.enabled)
                mainview.rangeSecondPane()
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
