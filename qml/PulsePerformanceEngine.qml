import QtQuick 2.15
import "PulsePerfEngine.js" as PerfMath

// THE PERFORMANCE ENGINE, PULSE BLUE (step 2, 2 Oct 2026)
//
// What it does: while performance mode is on for a committed blue, it sets the transducer's
// sample spacing and sample count from the visible range per side (Max range side), within
// the floors (the hardware's, Min spacing blue) and the samples ceiling (Max samples), at a
// fixed 70 ms and inside an 85% budget of the serial link. The arithmetic is in
// PulsePerfEngine.js, checked by tools/pulse-perf-check.js; this file is the gate, the
// throttle and the sends. claude/pulse-high-performance-mode.md, chapters 6, 7 and 9a.
//
// THE GATE. It HOLDS the acquisition (is the one writer of spacing, samples, distMax and
// the period) while expert mode is on, Enable performance mode is on and a blue (side scan)
// is committed. It ACTS (sends) only while that device is live, configured and its chart
// data is flowing - never for a demo or a file. Turning expert mode or the switch off hands
// the shipped values back (2000 samples, spacing = Side scan width, the profile's period);
// a commit that moves to another device just drops the engine's values from the old one.
//
// ONE PARAMETER AT A TIME (the upstream author's rule, which the setup pass follows): one
// message, then wait for the transducer to show it, then the next. Spacing and samples are
// one message (DevDriver::setChartSetup), confirmed by the chart stream itself - the last
// complete ping's spacing and sample count, which is the transducer's own word. distMax and
// the period are confirmed by the device's read-back plus a short gap. A send that is not
// confirmed in 6 s stops the engine (STALLED in the log and the Engine row) rather than
// pressing on.
//
// NEVER SEARCHED FOR ON THE WATER (9a): overload does not degrade, it kills the link. The
// budget is arithmetic, the baud it is computed on is decided once per connection, and the
// period is never shortened.
//
// THE DRAG THROTTLE (6.1, simplified on Olav's agreement): the picture follows the finger as
// before; the transducer is sent the latest range only after it has rested 300 ms, and a
// chart setup at most once a second.
Item {
    id: engine

    visible: false
    width:   0
    height:  0

    readonly property var rs: pulseRuntimeSettings
    readonly property var dm: deviceManagerWrapper

    // ---------------------------------------------------------------- the gate
    readonly property bool userWantsIt:     rs.expertMode && pulseSettings.perfModeEnabled
    readonly property bool committedIsBlue: rs.userManualSetName !== "..." && rs.userManualSetName !== ""
                                            && !rs.is2DTransducer
    readonly property bool wantsHold:       userWantsIt && committedIsBlue
    readonly property bool deviceReady:     !rs.logIsOnScreen && !rs.hasDeviceLostConnection && rs.devConfigured
    readonly property bool dataFlowing:     dm.linkBytesPerSecond > 0 && dm.linkStreamSamples > 0

    // ---------------------------------------------------------------- the inputs
    // Olav, 2 Oct: the side scan view decides - Max range side, never the down pane's.
    readonly property int ceilingM:     rs.blueMaxRangeCeiling > 0 ? rs.blueMaxRangeCeiling : 35
    readonly property int rangeM:       Math.max(5, Math.min(ceilingM, rs.blueSideMaxRange > 0 ? rs.blueSideMaxRange : ceilingM))
    readonly property int expertFloorMm: pulseSettings.perfMinSpacingBlueMm
    readonly property int maxSamples:   pulseSettings.perfMaxSamples
    readonly property int askedPeriodMs: 70            // blue keeps 70 ms (settled 2 Oct)
    readonly property int tableBaud:    921600         // the blue family's UART (both prototypes' blue too)

    // ---------------------------------------------------------------- the state
    property string heldKey:       ""      // the profile whose acquisition the engine holds
    property bool   handingBack:   false
    property bool   stalled:       false
    property int    baud:          0       // decided once per connection; 0 = not yet
    property string baudSource:    ""
    property int    dataSeconds:   0       // seconds of chart data seen since the last reset
    property var    lastPlan:      null
    property var    queue:         []
    property var    current:       null    // the step sent and not yet confirmed
    property double lastChartSendMs: 0

    function log() {
        var parts = ["ENGINE:"]
        for (var i = 0; i < arguments.length; i++)
            parts.push(arguments[i])
        console.log(parts.join(" "))
    }

    function setStatus(text) {
        if (rs.perfEngineStatus !== text)
            rs.perfEngineStatus = text
    }

    function forgetConnection(why) {
        if (baud !== 0)
            log("the baud decision is dropped -", why)
        baud = 0
        baudSource = ""
        dataSeconds = 0
        queue = []
        current = null
        confirmTimer.stop()
    }

    function shippedValues() {
        var width = pulseSettings.echogramWidth > 0 ? pulseSettings.echogramWidth : 25
        return {
            chartResolution: width,
            chartSamples:    rs.committedProfile.chartSamples,
            distMax:         1000 * width,
            ch1Period:       rs.committedProfile.ch1Period
        }
    }

    // ---------------------------------------------------------------- hold and release
    function reconsider(why) {
        var key = rs.committedProfileKey

        if (heldKey !== "" && heldKey !== key) {
            // The commit moved on. Drop the engine's values from the old profile's map so that
            // blue comes back with its own; nothing is sent, it is not on the wire any more.
            rs.clearParamsFor(heldKey, rs.perfEngineKeys)
            log("released", heldKey, "- the committed device is now", key, "(" + why + ")")
            release(false)
        }

        if (wantsHold && heldKey === "") {
            heldKey = key
            handingBack = false
            stalled = false
            forgetConnection("a new hold")
            rs.perfEngineOwnsAcquisition = true
            applyCeiling("the hold starts")
            log("holds the acquisition of", key, "| range per side", rangeM, "m | floor",
                Math.max(rs.hardwareSpacingFloorMm, expertFloorMm), "mm | max samples", maxSamples, "(" + why + ")")
        } else if (wantsHold && handingBack) {
            log("the hand-back is abandoned - performance mode is wanted again (" + why + ")")
            handingBack = false
            queue = []
        } else if (!wantsHold && heldKey !== "" && !handingBack) {
            startHandBack(why)
        }

        if (heldKey !== "" && (rs.logIsOnScreen || rs.hasDeviceLostConnection))
            forgetConnection(rs.logIsOnScreen ? "a recording is on screen" : "the connection was lost")

        kick()
    }

    function release(handedBack) {
        heldKey = ""
        handingBack = false
        stalled = false
        lastPlan = null
        forgetConnection("released")
        rs.perfEngineOwnsAcquisition = false
        if (handedBack)
            restoreShippedCeiling()
        setStatus(userWantsIt ? qsTr("waiting for a committed PULSE blue") : qsTr("off"))
    }

    // THE RANGE CEILING (Olav, 3 Oct). While the engine holds, the side scan's ceiling is the
    // expert's Max range ceiling (pulseRuntimeSettings.blueMaxRangeCeiling, up to 50 m); the
    // sliders read it directly, and maximumDepth - the pinch's clamp, in QML and in the C++ -
    // is set to it here. maximumDepth goes nowhere on the wire, so it needs no confirmation.
    function applyCeiling(why) {
        if (heldKey === "" || handingBack)
            return
        if (rs.setParams({ maximumDepth: ceilingM }, "performance mode ceiling"))
            log("the range ceiling is", ceilingM, "m (" + why + ")")
    }

    // Back to the Side scan width when the engine lets go of the device it handed back: the
    // pinch's ceiling, and any stored range above it (it would draw black beyond what the
    // transducer then covers). Written straight to the two blue keys, not through
    // storeMaxRangeForPane, which picks its key from the picture on screen.
    function restoreShippedCeiling() {
        var width = shippedValues().chartResolution
        rs.setParam("maximumDepth", width)
        var keys = [rs.blueSideMaxRangeKey, rs.blueDownMaxRangeKey]
        for (var i = 0; i < keys.length; i++) {
            if (pulseSettings[keys[i]] > width) {
                console.log("RANGE:", keys[i], pulseSettings[keys[i]], "-> " + width,
                            "| above the Side scan width once performance mode let go")
                pulseSettings[keys[i]] = width
            }
        }
    }

    function startHandBack(why) {
        handingBack = true
        stalled = false
        var v = shippedValues()
        if (!deviceReady || !dataFlowing) {
            // Nothing to confirm against: put the shipped values in the map (DeviceItem sends
            // them as one chart message if a device is there at all) and let go.
            rs.setParams(v, "performance mode off")
            log("handed back without confirmation - no live data (" + why + ")")
            release(true)
            return
        }
        log("hands back the shipped values (" + why + "):", v.chartSamples, "x", v.chartResolution, "mm @", v.ch1Period, "ms")
        queue = buildSteps(v)
        current = null
        setStatus(qsTr("handing back the shipped settings"))
    }

    // ---------------------------------------------------------------- the plan
    function buildSteps(v) {
        var steps = []
        // The period first, so a larger chart never goes out at a shorter period.
        if (rs.paramValue("ch1Period") !== v.ch1Period)
            steps.push({ kind: "period", values: { ch1Period: v.ch1Period } })
        steps.push({ kind: "chart", values: { chartResolution: v.chartResolution, chartSamples: v.chartSamples } })
        if (rs.paramValue("distMax") !== v.distMax)
            steps.push({ kind: "dist", values: { distMax: v.distMax } })
        return steps
    }

    function planNow(why) {
        if (heldKey === "" || handingBack || baud === 0)
            return
        var p = PerfMath.plan({
            rangeM:        rangeM,
            channels:      2,
            hwFloorMm:     rs.hardwareSpacingFloorMm,
            expertFloorMm: expertFloorMm,
            maxSamples:    maxSamples,
            periodMs:      askedPeriodMs,
            baud:          baud,
            soundSpeed:    rs.soundSpeed / 1000
        })
        lastPlan = p
        var line = rangeM + " m per side -> " + p.spacingMm + " mm x " + p.samples + " @ " + p.periodMs
                 + " ms (real " + p.realPeriodMs.toFixed(0) + ") | " + p.loadPercent.toFixed(0) + "% of " + baud
                 + " (" + baudSource + ") | limited by " + p.limitedBy
        log(line, "(" + why + ")")
        queue = buildSteps({ chartResolution: p.spacingMm, chartSamples: p.samples,
                             distMax: 1000 * rangeM, ch1Period: askedPeriodMs })
        setStatus(line)
    }

    // ---------------------------------------------------------------- acting
    function kick() {
        if (heldKey === "")
            return
        if (stalled)
            return
        if (!deviceReady) {
            setStatus(qsTr("holding - waiting for the transducer to be configured"))
            return
        }
        if (!dataFlowing) {
            setStatus(qsTr("holding - waiting for chart data"))
            return
        }
        if (baud === 0 && !handingBack) {
            // DECIDED ONCE, after 10 s of data: the ID_UART answer settles in a second or two
            // when it settles at all, and the 10 s rate is what proves a default impossible.
            if (dataSeconds < 10) {
                setStatus(qsTr("holding - measuring the link (%1 of 10 s)").arg(dataSeconds))
                return
            }
            var b = PerfMath.chooseBaud(dm.linkBaud, dm.linkBaudPlausible, dm.linkBytesPerSecond, tableBaud)
            baud = b.baud
            baudSource = b.source
            log("budgets on", baud, "baud -", baudSource, "| reported", dm.linkBaud, "| measured",
                dm.linkBytesPerSecond, "B/s")
            planNow("the link is measured")
        }
        if (current !== null)
            return
        sendNext()
    }

    function sendNext() {
        if (queue.length === 0) {
            if (handingBack) {
                log("the shipped values are back on the transducer - released")
                release(true)
            }
            return
        }
        var step = queue[0]
        if (step.kind === "chart") {
            var wait = 1000 - (Date.now() - lastChartSendMs)
            if (wait > 0) {
                rateTimer.interval = wait
                rateTimer.restart()
                return
            }
        }
        queue = queue.slice(1)
        step.sentAt = Date.now()
        current = step
        var changed = rs.setParams(step.values, handingBack ? "performance mode hand-back" : "performance mode")
        if (step.kind === "chart")
            lastChartSendMs = Date.now()
        log("sent", step.kind, JSON.stringify(step.values), changed ? "" : "(already set - confirming)")
        confirmTimer.restart()
        checkConfirmed()
    }

    function checkConfirmed() {
        if (current === null)
            return
        var v = current.values
        var age = Date.now() - current.sentAt
        var ok = false
        if (current.kind === "chart") {
            var s = dm.linkStreamSamples
            ok = dm.linkStreamSpacingMm === v.chartResolution && s <= v.chartSamples && s >= v.chartSamples - 200
        } else if (current.kind === "period") {
            ok = rs.ch1Period_Copy === v.ch1Period && age >= 300
        } else if (current.kind === "dist") {
            ok = rs.distMax_Copy === v.distMax && age >= 300
        }
        if (ok) {
            log("confirmed", current.kind, "after", age, "ms",
                current.kind === "chart" ? "| stream " + dm.linkStreamSamples + " x " + dm.linkStreamSpacingMm + " mm" : "")
            current = null
            confirmTimer.stop()
            sendNext()
        } else if (age > 6000) {
            log("STALLED -", current.kind, JSON.stringify(v), "not confirmed in 6 s | stream",
                dm.linkStreamSamples, "x", dm.linkStreamSpacingMm, "mm | period copy", rs.ch1Period_Copy,
                "| distMax copy", rs.distMax_Copy, "- nothing more is sent until performance mode is toggled")
            setStatus(qsTr("STALLED - the transducer did not confirm %1; toggle performance mode to retry").arg(current.kind))
            current = null
            queue = []
            stalled = true
            confirmTimer.stop()
        }
    }

    Timer {
        id: confirmTimer
        interval: 250
        repeat: true
        onTriggered: engine.checkConfirmed()
    }

    Timer {
        id: rateTimer
        repeat: false
        onTriggered: engine.kick()
    }

    // THE DRAG THROTTLE: the latest input, 300 ms after it last moved.
    Timer {
        id: settleTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (engine.heldKey === "" || engine.handingBack || engine.baud === 0)
                return
            engine.planNow("the range or a limit changed")
            if (engine.current === null)
                engine.kick()
        }
    }

    onRangeMChanged:        settleTimer.restart()
    onCeilingMChanged:      applyCeiling("the ceiling changed")
    onExpertFloorMmChanged: settleTimer.restart()
    onMaxSamplesChanged:    settleTimer.restart()

    onWantsHoldChanged:   reconsider(wantsHold ? "performance mode is wanted" : "performance mode is no longer wanted")
    onDeviceReadyChanged: reconsider(deviceReady ? "the device is ready" : "the device is not ready")
    onDataFlowingChanged: reconsider(dataFlowing ? "chart data flows" : "chart data stopped")

    Connections {
        target: engine.rs
        function onCommittedProfileKeyChanged() { engine.reconsider("the committed profile changed") }
        function onHardwareSpacingFloorMmChanged() { settleTimer.restart() }
        function onCh1Period_CopyChanged() { engine.checkConfirmed() }
        function onDistMax_CopyChanged()   { engine.checkConfirmed() }
    }

    Connections {
        target: engine.dm
        function onLinkStatsChanged() {
            if (engine.dataFlowing)
                engine.dataSeconds++
            else
                engine.dataSeconds = 0
            engine.checkConfirmed()
            if (engine.heldKey !== "" && engine.current === null)
                engine.kick()
        }
    }

    Component.onCompleted: reconsider("startup")
}
