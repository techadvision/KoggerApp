import QtQuick 2.15

// THE SETTINGS LIST (Stage 4 b, tier 2) - the Settings button's group in the sliding panel.
//
// ONE LIST, NO DRILL-IN, NO BACK BUTTON. Categories open in place, one at a time, which is
// the rule the panel already follows for rail groups - applied twice rather than invented
// twice. Tier 3 continues this same list past a rule once the expert switch is on, so there
// is never a second screen to navigate out of.
//
// READS ARE BINDINGS, WRITES GO THROUGH ONE SIGNAL. Every row binds its value straight to
// pulseSettings or pulseRuntimeSettings - they are global, always present, and a binding
// cannot disagree with the thing it reads. Nothing here assigns one: a row emits and this
// file re-emits `settingChanged`, which main.qml answers with the single write. That keeps
// the rule that matters - no control owns a copy, and every key has exactly one writer -
// without a hundred property-and-signal pairs threaded through the panel.
//
// ABSENT RATHER THAN GREYED, at both levels. A row a profile does not offer takes no
// height; and a CATEGORY whose rows are all absent is not offered either, because an empty
// category is a promise the device cannot keep.
//
// WHERE THIS FILE SPLITS. It holds the rows inline while there is one real category. When
// the second or third lands it wants a file per category with this one reduced to the
// Column and the open-at-a-time rule - twenty-four categories inline would be unreadable,
// and splitting before the shape is known would be guessing at the seam.
Item {
    id: list

    property real uiScale: 1.0

    // "" is all closed. One open at a time.
    property string openId: ""

    signal settingChanged(string target, string key, var value)

    // AN ACTION IS NOT A SETTING, so it does not travel down the settings signal. It has no
    // value to carry and its handler has to do something rather than assign something -
    // routing it through settingChanged would mean main.qml deciding which keys are really
    // buttons, which is a lookup table waiting to fall out of step.
    signal actionRequested(string id)

    // THE KEY CODE IS NEITHER. It is not a setting - one string entered here rewrites four
    // other keys and two access levels - and it is not an action, because it carries a
    // value. Its own signal, answered by the one rule in pulseRuntimeSettings.
    signal keyCodeEntered(string code)

    implicitHeight: column.height
    height: implicitHeight

    function toggle(id) {
        openId = (openId === id) ? "" : id
        console.log("SETTINGS:", openId === "" ? "all closed" : "showing " + openId)
    }

    // WHERE THE APP'S OWN LOG IS, so a tester can find it without a cable.
    //
    // main.cpp installs AppLog as the Qt message handler, so every console.log the app
    // writes - every METRICS:, MOSAIC:, THEME:, MODE:, RANGE:, SOURCE:, BLEND: and NADIR:
    // line this project has ever emitted - lands in a rolling file under Documents on the
    // device, reachable over USB or any file manager. logcat has never been needed, and the
    // checks that kept asking for it were asking for the wrong thing.
    //
    // READ ON OPEN RATHER THAN BOUND, because appLogFilePath() is a function call with no
    // change signal: a binding on it would evaluate once at startup and then describe the
    // file the app was writing to then. The log rolls at 8 MB, so over a long test session
    // that is the wrong name. A binding that cannot notice it is stale is worse than no
    // binding - the af857891 lesson, which is why this one is imperative.
    property string appLogPath: ""

    // THE LOG VIEWER (27 Sept, experts). The tail is read when the viewer opens and on
    // Refresh - never bound, because appLogTail() reads a file.
    property bool   logViewerOpen: false
    property string logTail:       ""

    function refreshLogTail() {
        logTail = (typeof core !== "undefined" && core) ? core.appLogTail(300) : ""
    }

    // WHAT THE APP INTENDS, AND WHAT THE DEVICE SAYS IT TOOK.
    //
    // Every managed parameter has a _Copy read-back, written when the device reports its
    // own configuration. Classic showed it in a separate "Device parameter information"
    // category further down the panel, so checking whether a write landed meant scrolling
    // away from the control that made it. Here it rides on the row: the value alone while
    // the two agree, and "2400 (device 2350)" while they do not.
    //
    // THAT DISAGREEMENT IS THE SAFETY INDICATOR. A parameter the transducer refused, or
    // clamped, or has not been told about yet, is invisible in every other way - the
    // slider sits happily at a number the hardware never accepted. -1 means the device has
    // not reported yet and is not a disagreement.
    // WITH NOTHING COMMITTED paramValue answers undefined - committedProfile is empty and
    // there is no override to find. An undefined reaching a slider's int value silently
    // becomes 0, which is below every minimum here and puts the knob off the left end. The
    // group is expert-gated and can be opened before a transducer is chosen, so this is
    // reachable rather than theoretical.
    // FOUR READINGS, WRITTEN ONCE. Every row in Expert info is one of these shapes, and
    // classic spells each of them inline at every row - which is how it came to print a
    // bare "true" in some places, "On" in others and a raw -1 in a third.
    //
    // orDash is the one that carries a judgement: a _Copy of -1 means THE DEVICE HAS NOT
    // REPORTED YET, which is a different statement from a parameter whose value is minus
    // one, and an em dash says so without pretending to a number.
    function yesNo(v)   { return v ? qsTr("Yes") : qsTr("No") }
    function onOff(v)   { return v ? qsTr("On")  : qsTr("Off") }
    function okOrNot(v) { return v === true ? qsTr("OK") : qsTr("Not verified") }
    function orDash(v) {
        if (v === undefined || v === null || v === "" || v === -1)
            return "\u2014"
        return String(v)
    }

    function paramNum(name, fallback) {
        if (!pulseRuntimeSettings)
            return fallback
        var v = pulseRuntimeSettings.paramValue(name)
        return (v === undefined || v === null || isNaN(v)) ? fallback : v
    }

    function paramText(name, deviceValue, unit) {
        if (!pulseRuntimeSettings)
            return ""
        var v = pulseRuntimeSettings.paramValue(name)
        if (v === undefined || v === null || isNaN(v))
            return qsTr("not set")
        var t = v + (unit ? " " + unit : "")
        if (deviceValue !== undefined && deviceValue >= 0 && deviceValue !== v)
            t += "  (device " + deviceValue + ")"
        return t
    }

    function refreshAppLogPath() {
        appLogPath = (typeof core !== "undefined" && core) ? core.appLogFilePath() : ""
        console.log("SETTINGS: app log is at", appLogPath === "" ? "(not active)" : appLogPath)
    }

    // ---- What this device offers --------------------------------------------

    readonly property var offers: pulseRuntimeSettings ? pulseRuntimeSettings.uiOffers : ({})

    readonly property bool offersSpeed:      offers && offers.screenSpeed2D === true
    readonly property bool offersSecondEcho: offers && offers.doubleEchoOptimize === true
    readonly property bool offersWidth:      offers && offers.scanWidthMeters === true
    readonly property bool offersTemp:       pulseRuntimeSettings ? pulseRuntimeSettings.useTemperature : false
    // ABSENT, not dashed, without an autopilot - the list's own rule. The speed comes from
    // MAVLink's GLOBAL_POSITION_INT and nothing else supplies it.
    readonly property bool offersBoatSpeed:  pulseRuntimeSettings ? pulseRuntimeSettings.mavlinkDetected : false

    readonly property bool offersMounting:   offers && offers.sideScanMounting === true
    readonly property bool offersMtw:        offers && offers.nmeaMtw === true

    // THE BLEND ONLY EXISTS WHERE THERE ARE TWO CHANNELS TO BLEND, so on a 2D picture the
    // whole category is absent rather than empty - the same rule the rows follow, one
    // level up.
    //
    // Reads displayIs2DTransducer rather than offersScreenChoice, which is the same
    // expression today. offersScreenChoice answers "may the user pick a layout"; this row
    // is asking "does this picture have two channels". Borrowing the first to mean the
    // second is how applyScreenId came to skip a red entirely.
    readonly property bool offersDownBlend:
        pulseRuntimeSettings ? !pulseRuntimeSettings.displayIs2DTransducer : false

    // WHAT THE CODE BOUGHT, said in the row rather than left to two small badges. Classic
    // shows a beta icon and a guru icon beside the field; a word is unambiguous at arm's
    // length on a boat, and it answers the question the field actually raises - not "is
    // there a code" but "what does it give me".
    readonly property string keyCodeHint:
          !pulseRuntimeSettings                  ? ""
        : pulseRuntimeSettings.expertMode        ? qsTr("Expert - every setting is shown")
        : pulseRuntimeSettings.betaMode          ? qsTr("Beta tester")
        : (pulseSettings && pulseSettings.keyCode !== "not_set")
                                                 ? qsTr("this code grants nothing")
        :                                          qsTr("for testers, from Techadvision")
    readonly property bool expertOnly:       pulseRuntimeSettings ? pulseRuntimeSettings.expertMode : false

    // ENTITLEMENT IS NOT THE SAME AS THE SWITCH, and tier 3 needs both.
    //
    // expertMode is the live switch; pulseSettings.isExpert is what the key code bought and
    // survives a restart. Every expert category reads the switch - except the one that
    // CONTAINS the switch, which reads the entitlement. Classic gets this wrong in a way it
    // has learned to live with: "Expert mode enabled" is `visible: expertMode`, so turning
    // it off removes it from the screen and the only way back is typing the code again.
    readonly property bool expertEntitled:   pulseSettings ? pulseSettings.isExpert : false
    readonly property bool betaOrExpert:
        pulseRuntimeSettings ? (pulseRuntimeSettings.expertMode || pulseRuntimeSettings.betaMode) : false

    // A CATEGORY WITH NOTHING IN IT IS NOT OFFERED. Connection's two rows are both expert
    // or beta, so for an ordinary user the category is absent rather than empty - the same
    // rule the rows follow, one level up.
    readonly property bool connectionHasRows: betaOrExpert || expertOnly

    Column {
        id: column
        width: parent.width
        spacing: 0

        // ---- Screen & echogram ----------------------------------------------

        PulseSettingsGroup {
            id: screenGroup

            width: parent.width

            // No `visible` gate: the depth-unit row below is unconditional, so this
            // category always has at least one row. The absent-rather-than-empty rule
            // still holds - it simply never bites here.
            uiScale: list.uiScale
            title: qsTr("Screen & echogram")
            open: list.openId === "screen"
            onToggled: list.toggle("screen")

            // Assigned rather than nested, and the widths come from the group rather than
            // from `parent` - see PulseSettingsGroup for both reasons.
            content: [

            // INTERFACE SIZE, session 3. The screen gives a size (the short side, floored at
            // 1.0); this is the person's own factor on top, for everybody. The G30 and the
            // Galaxy Tab 8" sit at almost the same scale and were judged "very OK" and "too
            // small" - no single curve can serve both, so the reader chooses.
            PulseSegmentRow {
                width: screenGroup.contentWidth
                uiScale: list.uiScale

                label: qsTr("Interface size")
                hint:  qsTr("text, buttons, the ruler and the zoom box")
                options: [ { value: 90,  title: qsTr("Small") },
                           { value: 100, title: qsTr("Normal") },
                           { value: 115, title: qsTr("Large") },
                           { value: 130, title: qsTr("Larger") } ]
                current: pulseSettings ? pulseSettings.interfaceSize : 100

                onChosen: function (v) {
                    list.settingChanged("persistent", "interfaceSize", v)
                }
            },

            // THE SPEED IS CARRIED AS TENTHS. The slider row is integer by design - a
            // stepped control with a named step is easier to hit than a continuous one -
            // and the echogram speed is 1.0 to 2.5 in tenths. Ten to twenty-five here, divided
            // on the way out, so the row needs no float mode it would use exactly once.
            //
            // AND IT WRITES THE PERSISTENT KEY, like the pinch in Plot2D does.
            // pulseRuntimeSettings.echogramSpeed is what reaches C++, but main.qml mirrors
            // the persistent one into it; writing the runtime key here would change the
            // picture and lose the setting on restart.
            PulseSliderRow {
                width: screenGroup.contentWidth
                height: visible ? implicitHeight : 0
                visible: list.offersSpeed
                uiScale: list.uiScale

                label: qsTr("2D echogram speed")
                hint:  qsTr("stretches the picture, it does not ping faster")
                minValue: 10
                maxValue: Math.round((pulseRuntimeSettings ? pulseRuntimeSettings.echogramSpeedMax : 2.5) * 10)
                stepSize: 1
                value: Math.round((pulseSettings ? pulseSettings.echogramSpeed : 1) * 10)
                valueText: ((pulseSettings ? pulseSettings.echogramSpeed : 1)).toFixed(1) + "\u00D7"

                onMoved: function (v) {
                    list.settingChanged("persistent", "echogramSpeed", Math.round(v) / 10)
                }
            },

            // SPEED OF SOUND, 27 Sept - for everybody, not only experts, on Olav's call. The
            // machinery was built on 14 Sept (soundSpeedOverride in PulseRuntimeSettings) and
            // never given a row. RUNTIME by design: kept for the session, gone on restart,
            // and it survives a device swap because it is a property of the water. It writes
            // the override and never the bound value, so the profile keeps its say the moment
            // the override is cleared.
            //
            // The transducer uses it for its own range calculation, so it reaches a LIVE
            // device only; a recording carries the speed it was made with.
            PulseSliderRow {
                width: screenGroup.contentWidth
                uiScale: list.uiScale
                showNudges: true

                label: qsTr("Speed of sound")
                hint: (pulseRuntimeSettings && pulseRuntimeSettings.soundSpeedOverride > 0)
                      ? qsTr("set by you for this session - the profile says %1 m/s")
                            .arg(Math.round(pulseRuntimeSettings.committedProfile.soundSpeed / 1000))
                      : qsTr("the profile's value - fresh water is about 1480, sea water about 1500 to 1540")
                minValue: 1400
                maxValue: 1600
                stepSize: 1
                value: pulseRuntimeSettings ? Math.round(pulseRuntimeSettings.soundSpeed / 1000) : 1480
                valueText: (pulseRuntimeSettings ? Math.round(pulseRuntimeSettings.soundSpeed / 1000) : 1480)
                           + " m/s"

                onMoved: function (v) {
                    list.settingChanged("runtime", "soundSpeedOverride", Math.round(v) * 1000)
                }
            },

            PulseActionRow {
                width: screenGroup.contentWidth
                height: visible ? implicitHeight : 0
                visible: pulseRuntimeSettings ? pulseRuntimeSettings.soundSpeedOverride > 0 : false
                uiScale: list.uiScale

                label: qsTr("Speed of sound back to the profile")
                hint:  qsTr("forgets the value set above")
                actionText: qsTr("Reset")

                onActivated: list.settingChanged("runtime", "soundSpeedOverride", 0)
            },

            // THE SWATH, which is also the side scan's true range ceiling - backlog item
            // 11 reads this same key for the max-range slider, so the two cannot drift.
            PulseSegmentRow {
                width: screenGroup.contentWidth
                height: visible ? implicitHeight : 0
                visible: list.offersWidth
                uiScale: list.uiScale

                label: qsTr("Side scan width")
                hint:  qsTr("also the furthest the range slider will go")
                options: [ { value: 25, title: qsTr("25 m") },
                           { value: 35, title: qsTr("35 m") } ]
                current: pulseSettings ? pulseSettings.echogramWidth : 25

                onChosen: function (v) {
                    list.settingChanged("persistent", "echogramWidth", v)
                }
            },

            // UNITS ARE A CHOICE, NOT A CHECKBOX. Classic's row is a checkbox whose LABEL
            // changes - "Metric depth (checked)" / "Imperial depth (unchecked)" - so the
            // thing you are choosing and the thing you have chosen are the same words, and
            // neither state shows you the other option exists.
            PulseSegmentRow {
                width: screenGroup.contentWidth
                uiScale: list.uiScale

                label: qsTr("Depth in")
                options: [ { value: true,  title: qsTr("Metres") },
                           { value: false, title: qsTr("Feet") } ]
                current: pulseSettings ? pulseSettings.useMetricDepth : true

                onChosen: function (v) {
                    list.settingChanged("persistent", "useMetricDepth", v)
                }
            },

            PulseSwitchRow {
                width: screenGroup.contentWidth
                height: visible ? implicitHeight : 0
                visible: list.offersTemp
                uiScale: list.uiScale

                label: qsTr("Display temperature on screen")
                checked: pulseSettings ? pulseSettings.showTemperatureInUi : false

                onToggled: function (v) {
                    list.settingChanged("persistent", "showTemperatureInUi", v)
                }
            },

            // Under the switch it depends on, and gone with it - a unit for a reading that
            // is not on screen is a question about nothing.
            PulseSegmentRow {
                width: screenGroup.contentWidth
                height: visible ? implicitHeight : 0
                visible: list.offersTemp
                         && (pulseSettings ? pulseSettings.showTemperatureInUi : false)
                uiScale: list.uiScale

                label: qsTr("Temperature in")
                options: [ { value: true,  title: qsTr("\u00B0C") },
                           { value: false, title: qsTr("\u00B0F") } ]
                current: pulseSettings ? pulseSettings.useMetricTemperature : true

                onChosen: function (v) {
                    list.settingChanged("persistent", "useMetricTemperature", v)
                }
            },

            // THE SPEED GAUGE, 27 Sept - asked for by the professional dealer. Same pair of
            // rows as the temperature: a switch, and the unit under it only while it is on.
            PulseSwitchRow {
                width: screenGroup.contentWidth
                height: visible ? implicitHeight : 0
                visible: list.offersBoatSpeed
                uiScale: list.uiScale

                label: qsTr("Display boat speed on screen")
                hint:  qsTr("from the autopilot")
                checked: pulseSettings ? pulseSettings.showSpeedInUi : false

                onToggled: function (v) {
                    list.settingChanged("persistent", "showSpeedInUi", v)
                }
            },

            PulseSegmentRow {
                width: screenGroup.contentWidth
                height: visible ? implicitHeight : 0
                visible: list.offersBoatSpeed
                         && (pulseSettings ? pulseSettings.showSpeedInUi : false)
                uiScale: list.uiScale

                label: qsTr("Speed in")
                options: [ { value: "ms",  title: qsTr("m/s") },
                           { value: "kmh", title: qsTr("km/h") },
                           { value: "kn",  title: qsTr("knots") },
                           { value: "mph", title: qsTr("mph") } ]
                current: pulseSettings ? pulseSettings.speedUnit : "kmh"

                onChosen: function (v) {
                    list.settingChanged("persistent", "speedUnit", v)
                }
            },

            PulseSwitchRow {
                width: screenGroup.contentWidth
                height: visible ? implicitHeight : 0
                visible: list.offersSecondEcho
                uiScale: list.uiScale

                label: qsTr("Optimise for a second echo")
                hint:  qsTr("samples twice the depth, to read bottom hardness")
                checked: pulseSettings ? pulseSettings.doubleEchoOptimize : false

                onToggled: function (v) {
                    list.settingChanged("persistent", "doubleEchoOptimize", v)
                }
            }
            ]
        }

        // ---- Still to be built, in the document's order -----------------------

        // ---- Installation -----------------------------------------------------
        //
        // POSITION SOURCE IS A ROW HERE, NOT A CATEGORY. It was one in the strategy
        // document, on the promise of three sources - autopilot, device GPS, NMEA GPS. All
        // three keys exist in PulseSettings.qml but only positionSourceAutoPilot is ever
        // READ (DeviceItem.qml:1892 and :1933); nothing in any .qml or .cpp touches the
        // other two. Olav, told that: no plan to offer the others, and where the boat is
        // rigged is where this question belongs anyway. A category of one is a category
        // that should have been a row.
        PulseSettingsGroup {
            id: installationGroup

            width: parent.width
            uiScale: list.uiScale
            title: qsTr("Installation")
            open: list.openId === "installation"
            onToggled: list.toggle("installation")

            content: [
                PulseStepperRow {
                    width: installationGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Transducer below the water surface")
                    hint:  qsTr("0 \u2013 10 m, in centimetres \u00b7 hold to run")
                    unit:  qsTr("m")
                    minValue: 0
                    maxValue: 10
                    stepSize: 0.01
                    decimals: 2
                    value: pulseSettings ? pulseSettings.transducerOffsetMount : 0

                    onStepped: function (v) {
                        list.settingChanged("persistent", "transducerOffsetMount", v)
                    }
                },

                // "Mounted on the left-hand side" is gone from v2 (29 Sept): it only chose which
                // half the down view drew from and flipped it, and v2's down view blends both
                // channels and is never flipped. See main.qml sideScanLeftHandForPicture().
                // Classic still offers it. "Cable facing the front" below is a different thing.

                PulseSwitchRow {
                    width: installationGroup.contentWidth
                    height: visible ? implicitHeight : 0
                    visible: list.offersMounting
                    uiScale: list.uiScale

                    label: qsTr("Cable facing the front")
                    hint:  qsTr("off means the cable runs towards the stern")
                    checked: pulseSettings ? pulseSettings.isSideScanCableFacingFront : false

                    onToggled: function (v) {
                        list.settingChanged("persistent", "isSideScanCableFacingFront", v)
                    }
                },

                PulseSwitchRow {
                    width: installationGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Position from the autopilot")
                    hint:  qsTr("beta feature")
                    checked: pulseSettings ? pulseSettings.positionSourceAutoPilot : false

                    onToggled: function (v) {
                        list.settingChanged("persistent", "positionSourceAutoPilot", v)
                    }
                },

                // THE BETA KEY CODE, here on Olav's placing rather than in Troubleshooting
                // where the document had it. It belongs with the things you set up once
                // when the app is new to you, not with the things you reach for when
                // something has gone wrong.
                //
                // MASKED AT REST, plain while typing. It is a secret worth not showing over
                // a shoulder at a stand, and a field you cannot read while typing into it is
                // a field you cannot correct.
                PulseTextRow {
                    width: installationGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Beta test key code")
                    hint: list.keyCodeHint
                    placeholder: qsTr("not set")
                    masked: true
                    lowercaseOnly: true
                    value: (pulseSettings && pulseSettings.keyCode !== "not_set")
                           ? pulseSettings.keyCode : ""

                    onCommitted: function (code) { list.keyCodeEntered(code) }
                }
            ]
        }

        // ---- NMEA output ------------------------------------------------------

        PulseSettingsGroup {
            id: nmeaGroup

            width: parent.width
            uiScale: list.uiScale
            title: qsTr("NMEA output")
            open: list.openId === "nmea"
            onToggled: list.toggle("nmea")

            content: [
                PulseSwitchRow {
                    width: nmeaGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Send depth over UDP")
                    hint:  qsTr("the DBT sentence, to anything listening on the network")
                    checked: pulseSettings ? pulseSettings.enableNmeaDbt : false

                    onToggled: function (v) {
                        list.settingChanged("persistent", "enableNmeaDbt", v)
                    }
                },

                PulseSwitchRow {
                    width: nmeaGroup.contentWidth
                    height: visible ? implicitHeight : 0
                    visible: list.offersMtw
                    uiScale: list.uiScale

                    label: qsTr("Send temperature too")
                    hint:  qsTr("the MTW sentence")
                    checked: pulseSettings ? pulseSettings.enableNmeaMtw : false

                    onToggled: function (v) {
                        list.settingChanged("persistent", "enableNmeaMtw", v)
                    }
                },

                PulseSegmentRow {
                    width: nmeaGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("How often")
                    options: [ { value: 250,  title: qsTr("4 / s") },
                               { value: 500,  title: qsTr("2 / s") },
                               { value: 1000, title: qsTr("1 / s") } ]
                    current: pulseSettings ? pulseSettings.nmeaSendPerMilliSec : 500

                    onChosen: function (v) {
                        list.settingChanged("persistent", "nmeaSendPerMilliSec", v)
                    }
                },

                // A LADDER, NOT A SET OF NAMED ALTERNATIVES, so it is a stepper rather than
                // six segments. Segmented is right when the options are answers with names -
                // metres or feet, 25 m or 35 m; six four-digit port numbers in a row are
                // points on a scale, and at panel width six cells of "3000" is a squeeze
                // that gets worse on a phone.
                PulseStepperRow {
                    width: nmeaGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Send to UDP port")
                    hint:  qsTr("3000 \u2013 3500")
                    minValue: 3000
                    maxValue: 3500
                    stepSize: 100
                    decimals: 0
                    value: pulseSettings ? pulseSettings.nmeaPort : 3000

                    onStepped: function (v) {
                        list.settingChanged("persistent", "nmeaPort", v)
                    }
                },

                // READ-ONLY, AND BOUND TO THE KEY THE SENDER ACTUALLY READS. Classic prints
                // the literal "255.255.255.255" here while NMEASender reads
                // pulseSettings.nmeaBroadcastAddress, which main.qml:143 overwrites from the
                // runtime key - so the label is right until the day it is not.
                PulseReadOnlyRow {
                    width: nmeaGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Send to")
                    hint:  qsTr("broadcast - every device on the network hears it")
                    value: pulseSettings ? pulseSettings.nmeaBroadcastAddress : ""
                }
            ]
        }

        // ---- Connection -------------------------------------------------------
        //
        // Both rows are expert or beta, so an ordinary user does not see this category at
        // all - absent rather than empty, which is the row rule one level up.
        PulseSettingsGroup {
            id: connectionGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.connectionHasRows

            uiScale: list.uiScale
            title: qsTr("Connection")
            open: list.openId === "connection"
            onToggled: list.toggle("connection")

            content: [
                PulseSegmentRow {
                    width: connectionGroup.contentWidth
                    height: visible ? implicitHeight : 0
                    visible: list.betaOrExpert
                    uiScale: list.uiScale

                    label: qsTr("Pulse Wi-Fi server UDP port")
                    options: [ { value: 14550, title: "14550" },
                               { value: 14560, title: "14560" } ]
                    current: pulseSettings ? pulseSettings.udpPort : 14550

                    onChosen: function (v) {
                        list.settingChanged("persistent", "udpPort", v)
                    }
                },

                PulseSegmentRow {
                    width: connectionGroup.contentWidth
                    height: visible ? implicitHeight : 0
                    visible: list.expertOnly
                    uiScale: list.uiScale

                    label: qsTr("USB baud rate")
                    options: [ { value: 115200, title: "115200" },
                               { value: 921600, title: "921600" } ]
                    current: pulseSettings ? pulseSettings.usbSerialBaud : 115200

                    onChosen: function (v) {
                        list.settingChanged("persistent", "usbSerialBaud", v)
                    }
                }
            ]
        }

        // NO RECORDING CATEGORY. The Recording tab had three jobs and the new surface has
        // already taken all three: the rail's Record button starts it, the pill column asks
        // before stopping it, a demo starts from the connection screen - and so does opening
        // a file to view. Olav: "All redundant... But in settings we do not need this as a
        // category."

        // ---- Troubleshooting --------------------------------------------------
        //
        // NO "CHOOSE A DIFFERENT TRANSDUCER" HERE, though the strategy document lists one.
        // The rail's source button opens the connection screen, which is that action with a
        // picture of every device on it - repeating it as a row would be the duplicated
        // ability Olav wants tier 3 cleaned of, arriving fresh in tier 2.
        PulseSettingsGroup {
            id: troubleGroup

            width: parent.width
            uiScale: list.uiScale
            title: qsTr("Troubleshooting")
            open: list.openId === "troubleshooting"
            onToggled: list.toggle("troubleshooting")
            onOpenChanged: if (open) list.refreshAppLogPath()

            content: [
                // THE SAFE REPAIR FIRST, and it does not ask: it re-pushes the profile the
                // app already committed and leaves the model alone, so the connection
                // screen stays down and the echogram keeps its picture. There is nothing
                // to undo.
                //
                // EXPERT-ONLY IN CLASSIC, where it lives under the expert Device swap
                // group. Offered to everyone here because it is the honest answer to "the
                // app and the transducer have drifted apart", which is not an expert's
                // problem. One line to gate it again if Olav disagrees.
                PulseActionRow {
                    width: troubleGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Reconfigure the transducer")
                    hint:  qsTr("sends the settings again, without changing which device it is")
                    actionText: qsTr("Reconfigure")

                    onActivated: list.actionRequested("reconfigure")
                },

                // AND THE ONE THAT INTERRUPTS THE PICTURE ASKS. The question stands in the
                // row rather than in a dialog over the list.
                PulseActionRow {
                    width: troubleGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Restart the echo sounder")
                    hint:  qsTr("the echogram stops until it comes back")
                    actionText: qsTr("Restart")
                    question:    qsTr("Restart it now? The picture stops until it is back.")
                    confirmText: qsTr("Restart")

                    onActivated: list.actionRequested("restart")
                },

                // THE ONE SETTING THE DROPPED "DEVICE SWAP" CATEGORY OWNED. Its other two
                // rows are already elsewhere - reconfigure is directly above, and choosing
                // a different transducer is the rail's source button - but this is a real
                // preference with nowhere else to be, and a category being removed must not
                // quietly take a setting with it.
                //
                // Here rather than in an expert group because it is about the same subject
                // as the row above it: what happens when a different transducer turns up.
                // Still expert-gated, as it is today.
                PulseSwitchRow {
                    width: troubleGroup.contentWidth
                    height: visible ? implicitHeight : 0
                    visible: list.expertOnly
                    uiScale: list.uiScale

                    label: qsTr("Swap transducer without asking")
                    hint:  qsTr("accepting re-runs the whole setup, so it asks by default")
                    checked: pulseRuntimeSettings ? pulseRuntimeSettings.deviceSwapAutomatic : false

                    onToggled: function (v) {
                        list.settingChanged("runtime", "deviceSwapAutomatic", v)
                    }
                },

                // ---- the app's own log ---------------------------------------
                //
                // AN ABILITY, NOT A SETTING: it is how a tester gets at the evidence. Both
                // Q_INVOKABLEs have been in Core since the log handler was installed and
                // NOTHING has ever called either of them, so the logs have been written to
                // the device and then hunted for by hand every time.
                PulseReadOnlyRow {
                    width: troubleGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("App log")
                    hint:  qsTr("pulse.log - every line the app prints, kept on the device, at most 6 MB")
                    value: list.appLogPath === "" ? qsTr("not active") : list.appLogPath
                },

                // ABSENT ON ANDROID, because Core::revealInFolder is an explicit no-op
                // there - its whole body is #if defined(Q_OS_ANDROID) Q_UNUSED. A button
                // that does nothing on the platform being tested is worse than no button,
                // and the row above already names the file. Absent rather than greyed, like
                // everything else in this list.
                PulseActionRow {
                    width: troubleGroup.contentWidth
                    height: visible ? implicitHeight : 0
                    visible: Qt.platform.os !== "android"
                    uiScale: list.uiScale

                    label: qsTr("Show the log folder")
                    actionText: qsTr("Show")

                    onActivated: list.actionRequested("revealAppLog")
                },

                // SEND IT TO US, for everybody (27 Sept, Olav's choice). A regular user
                // describing a problem can attach the evidence in two taps: this builds one
                // pulse.log from the kept files and opens the share sheet with
                // olav.aamaas@techadvision.com filled in. On a desktop it reveals that file.
                PulseActionRow {
                    width: troubleGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Send the log to Techadvision")
                    hint:  qsTr("attach it to a mail describing what happened")
                    actionText: qsTr("Send")

                    onActivated: list.actionRequested("shareAppLog")
                },

                // AND READ IT HERE, for experts - the last lines, enough to see what the app
                // just said without a computer. Not for everyone: to a customer it is noise.
                PulseActionRow {
                    width: troubleGroup.contentWidth
                    height: visible ? implicitHeight : 0
                    visible: list.expertOnly
                    uiScale: list.uiScale

                    label: qsTr("View the log")
                    hint:  qsTr("the last 300 lines")
                    actionText: list.logViewerOpen ? qsTr("Hide") : qsTr("View")

                    onActivated: {
                        list.logViewerOpen = !list.logViewerOpen
                        if (list.logViewerOpen)
                            list.refreshLogTail()
                    }
                },

                Rectangle {
                    width: troubleGroup.contentWidth
                    height: visible ? Math.round(380 * list.uiScale) : 0
                    visible: list.expertOnly && list.logViewerOpen
                    color: "#0b0d11"
                    border.width: 1
                    border.color: "#28ffffff"
                    radius: Math.round(6 * list.uiScale)
                    clip: true

                    Flickable {
                        id: logFlick
                        anchors.fill: parent
                        anchors.margins: Math.round(8 * list.uiScale)
                        contentWidth: width
                        contentHeight: logText.height
                        clip: true
                        // Newest line at the foot, so open at the foot.
                        onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                        Text {
                            id: logText
                            width: logFlick.width
                            text: list.logTail === "" ? qsTr("The log is empty or not active.") : list.logTail
                            color: "#b9c6d3"
                            font.family: "monospace"
                            font.pixelSize: Math.round(11 * list.uiScale)
                            wrapMode: Text.WrapAnywhere
                            textFormat: Text.PlainText
                        }
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Math.round(8 * list.uiScale)
                        width:  refreshLabel.width + Math.round(20 * list.uiScale)
                        height: Math.round(30 * list.uiScale)
                        radius: height / 2
                        color: refreshArea.pressed ? "#2f7fb5" : "#1d3446"
                        border.width: 1
                        border.color: "#3d7fd0"

                        Text {
                            id: refreshLabel
                            anchors.centerIn: parent
                            text: qsTr("Refresh")
                            color: "#cfe0f2"
                            font.pixelSize: Math.round(13 * list.uiScale)
                        }

                        MouseArea {
                            id: refreshArea
                            anchors.fill: parent
                            onClicked: list.refreshLogTail()
                        }
                    }
                }
            ]
        }

        // ---- About ------------------------------------------------------------
        //
        // THE APP DID NOT SAY WHAT IT WAS ANYWHERE. Its name is set once in main.cpp and
        // read by nothing; the version lived on the old welcome tab and left with it. On a
        // desktop the window title carried the name by accident - on Android there is not
        // one, so a tester holding a tablet had no way to answer "which build is this".
        //
        // LAST BEFORE THE EXPERT TITLE, on Olav's placing: it is the least often wanted
        // thing an ordinary user has, and the first thing anyone asks for in a bug report.
        //
        // Both rows come from C++ rather than from a second XMLHttpRequest on version.txt:
        // a synchronous read of a compiled-in resource cannot fail halfway and needs no
        // callback, and Core can strip the name out of the line so the two rows do not both
        // say it.
        PulseSettingsGroup {
            id: aboutGroup

            width: parent.width
            uiScale: list.uiScale
            title: qsTr("About")
            open: list.openId === "about"
            onToggled: list.toggle("about")

            content: [
                PulseReadOnlyRow {
                    width: aboutGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("App")
                    value: (typeof core !== "undefined" && core) ? core.appName() : ""
                },

                PulseReadOnlyRow {
                    width: aboutGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Version")
                    hint:  qsTr("quote this in anything you report")
                    value: (typeof core !== "undefined" && core) ? core.appVersion() : ""
                }
            ]
        }

        // ======================================================================
        // TIER 3 - EXPERT
        //
        // The same list continues past a title once the code is in. Not a tab and not a
        // screen: there is nothing to navigate back out of, which is the whole reason the
        // panel has no back button anywhere.
        //
        // NO "DEVICE SWAP" CATEGORY - Olav: "For the expert we can get rid of Device swap
        // category." Its three rows are accounted for: reconfigure and the automatic-swap
        // switch are in Troubleshooting above, and choosing a different transducer is the
        // rail's source button.
        // ======================================================================

        PulseSettingsSection {
            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertEntitled
            uiScale: list.uiScale
            title: qsTr("Expert settings")
        }

        // ---- Experimental settings --------------------------------------------
        //
        // READS THE ENTITLEMENT, NOT THE SWITCH - the only category that does, because it
        // holds the switch. Turning expert mode off then leaves exactly one category on
        // screen, which is the way back. See expertEntitled above.
        PulseSettingsGroup {
            id: experimentalGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertEntitled

            uiScale: list.uiScale
            title: qsTr("Experimental settings")
            open: list.openId === "experimental"
            onToggled: list.toggle("experimental")

            content: [
                PulseSwitchRow {
                    width: experimentalGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Expert mode")
                    hint:  qsTr("off hides every expert category but this one")
                    checked: pulseRuntimeSettings ? pulseRuntimeSettings.expertMode : false

                    onToggled: function (v) {
                        list.settingChanged("runtime", "expertMode", v)
                    }
                },

                // THE VARIANT SWITCH, AND THE POINT OF PUTTING IT HERE. It has only ever
                // lived in the CLASSIC settings, so turning v2 on removed the switch from
                // the screen - which is why PulseAppV2 carried its own way back on the
                // rail, scaffolding that was always meant to leave when the settings panel
                // existed. This row was kept beside the rail's button for one build rather
                // than replacing it untested, and that build has now been run: the rail's
                // arrow was dropped on 16 Sept and THIS ROW IS THE ONLY WAY BACK. Nothing
                // else in v2 writes uiVariant, so a change here strands a tester in v2.
                //
                // uiVariant is a STRING, so the generic writer carries it unchanged - no
                // new property is needed for a third variant.
                PulseSwitchRow {
                    width: experimentalGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("New UI (PULSE UI v2)")
                    hint:  qsTr("off returns to the classic interface")
                    checked: pulseSettings ? pulseSettings.uiVariant === "v2" : false

                    onToggled: function (v) {
                        list.settingChanged("persistent", "uiVariant", v ? "v2" : "classic")
                    }
                }
            ]
        }

        // ---- Transducer -------------------------------------------------------
        //
        // THE SETTERS CLASSIC HID UNDER "Experimental", BACK, AND DELIBERATELY SO. Olav,
        // 17 Sept: "my partner will be mad at me. Because he really needs to modify several
        // settings that are now all lost under experimental settings... the upcoming
        // transducer needs to be tuned."
        //
        // WHAT MAKES IT SAFE IS NOT THE RANGE, IT IS WHERE THE VALUE LIVES. Every row here
        // writes through the "param" target into pulseRuntimeSettings.liveParams, which was
        // built on 14 Sept with three rules and no special cases:
        //
        //   RUNTIME  - every app start returns to the profile, so no experiment can outlive
        //              the session that made it. Olav, when it was built: an expert "will
        //              need to start from scratch at app start."
        //   KEYED BY PROFILE - red's and blue's never mix, and swapping away and back finds
        //              the experiment still there.
        //   READONLY - setParam is the only writer, so no stray assignment can destroy the
        //              binding that follows the committed device.
        //
        // So the honest answer to "make these safe" was not to clamp them. It was to check
        // that the container already refuses to do the dangerous thing - and it does - and
        // then to add the two things it was missing: A WAY BACK that does not need a
        // restart (the action at the foot of this group), and A READ-BACK so a value the
        // transducer never accepted is visible on the row that set it rather than in a
        // category further down the panel.
        //
        // THE RANGES ARE THE DEVICE'S OWN, taken from DeviceItem.qml's configuration
        // SpinBoxes rather than invented here - those are what the hardware is asked for
        // during setup, so nothing in this group can ask for something setup could not.
        // SAMPLES STOPS AT 5000, the firmware's maximum (2 Oct 2026). It ran to 15000 "with room
        // over", and on the G30 with a live blue prototype a drag above 5000 killed the
        // connection until the transducer was power cycled. Room over a hardware limit is not
        // room; the Performance mode engine never asks for more than 5000 either.
        //
        // SLIDERS WITH NUDGES, not steppers. Olav: the +/- stepper is "a bit slow", and
        // over 100-15000 it is unusable. But a drag alone cannot land on an exact value at
        // that width - about forty units per pixel - so the drag chooses the neighbourhood
        // and the nudge lands the number. See PulseSliderRow.
        //
        // NOT HERE: soundSpeed, which is deliberately outside the parameter map because it
        // is a property of the water rather than of the device, and wants the
        // one-binding-one-override shape instead. distDeadZone, which is not a managed key
        // - DeviceItem writes it straight to the device. And chartOffset's automatic write:
        // applyEchogramMode sets it to 0 on every mode change, so a hand value here would
        // be overwritten by the next screen change. That is on the open list as a bug in
        // applyEchogramMode, not something this group should work around.
        PulseSettingsGroup {
            id: transducerGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly

            uiScale: list.uiScale
            title: qsTr("Transducer")
            open: list.openId === "transducer"
            onToggled: list.toggle("transducer")

            content: [
                PulseSliderRow {
                    width: transducerGroup.contentWidth
                    uiScale: list.uiScale
                    showNudges: true

                    label: qsTr("Samples")
                    // HELD BY PERFORMANCE MODE (step 2): the engine is the one writer of
                    // samples, spacing and the period while it holds them, so the three rows
                    // become displays - setParam() would refuse a drag anyway, and a row that
                    // silently loses its value reads as a bug.
                    enabled: !(pulseRuntimeSettings && pulseRuntimeSettings.perfEngineOwnsAcquisition)
                    opacity: enabled ? 1.0 : 0.45
                    hint:  enabled ? qsTr("how many points the transducer returns per ping")
                                   : qsTr("held by performance mode")
                    minValue: 100
                    maxValue: 5000
                    stepSize: 50
                    value: list.paramNum("chartSamples", 100)
                    valueText: list.paramText("chartSamples",
                                              pulseRuntimeSettings ? pulseRuntimeSettings.chartSamples_Copy : -1)

                    onMoved: function (v) {
                        list.settingChanged("param", "chartSamples", v)
                    }
                },

                PulseSliderRow {
                    width: transducerGroup.contentWidth
                    uiScale: list.uiScale
                    showNudges: true

                    // "Sample spacing" rather than "Resolution", which classic renamed for
                    // the reason its own comment gives: high resolution is a LOW number and
                    // misreads every time. A spacing is a length, so bigger is plainly coarser.
                    label: qsTr("Sample spacing")
                    // Same "who is holding this" rule as Ping period below: while dynamic
                    // resolution is on, DeviceItem drives chartResolution and a hand value
                    // does not survive.
                    enabled: !(pulseRuntimeSettings && pulseRuntimeSettings.perfEngineOwnsAcquisition)
                    opacity: enabled ? 1.0 : 0.45
                    hint: !enabled ? qsTr("held by performance mode")
                        : list.paramNum("doDynamicResolution", 0)
                        ? qsTr("the app is driving this - turn Dynamic resolution off to hold it")
                        : qsTr("millimetres between points - finer costs depth, which can be the point")
                    // THE HARDWARE FLOOR, not 1: the blue prototype loses the link the instant
                    // its spacing goes below 15 mm (Olav, 2 Oct). See hardwareSpacingFloorMm.
                    minValue: pulseRuntimeSettings ? pulseRuntimeSettings.hardwareSpacingFloorMm : 1
                    // THE PROTOCOL'S CEILING (3 Oct 2026). IDBinChartSetup::setV0 keeps samples x
                    // spacing at 200 000 or less and quietly cuts the spacing to a multiple of
                    // 10 mm when it is over - so at 5000 samples a drag to 100 mm sent 40. The
                    // row stops where the protocol does instead of showing a value never sent.
                    maxValue: Math.max(minValue, Math.min(100, Math.floor(200000 / Math.max(1, list.paramNum("chartSamples", 2000)))))
                    stepSize: 1
                    value: list.paramNum("chartResolution", 1)
                    valueText: list.paramText("chartResolution",
                                              pulseRuntimeSettings ? pulseRuntimeSettings.chartResolution_Copy : -1,
                                              qsTr("mm"))

                    onMoved: function (v) {
                        list.settingChanged("param", "chartResolution", v)
                    }
                },

                PulseSliderRow {
                    width: transducerGroup.contentWidth
                    uiScale: list.uiScale
                    showNudges: true

                    label: qsTr("Transducer pulse")
                    // CYCLES PER PING, 1-10 (3 Oct). It ran 0-5000 (one byte on the wire, so 300
                    // arrived as 44; 0 transmits nothing), then 1-30 - and the hardware partner
                    // then capped it at 10: a longer pulse's transmit energy can blow resistors.
                    // About 1.6 mm of range cell per cycle at 460 kHz: 4-6 sharpens the short
                    // ranges. setParam holds the same bounds.
                    enabled: !(pulseRuntimeSettings && pulseRuntimeSettings.perfEngineHoldsPulse)
                    opacity: enabled ? 1.0 : 0.45
                    hint:  enabled ? qsTr("cycles per ping, at most 10 - fewer is sharper, more carries further")
                                   : qsTr("held by performance mode - Pulse follows the range is on")
                    minValue: 1
                    maxValue: pulseRuntimeSettings ? pulseRuntimeSettings.transPulseMaxCycles : 10
                    stepSize: 1
                    value: list.paramNum("transPulse", 0)
                    valueText: list.paramText("transPulse",
                                              pulseRuntimeSettings ? pulseRuntimeSettings.transPulse_Copy : -1)

                    onMoved: function (v) {
                        list.settingChanged("param", "transPulse", v)
                    }
                },

                // FREQUENCY, AND IT SHARES ITS KEY WITH THE RAIL'S CONE CHOOSER. Both write
                // transFreq: the chooser writes one of the profile's three cone frequencies,
                // this writes anything between the widest and the narrowest. Olav, 17 Sept:
                // "I know these makes trouble with our (particularly red/black) cone
                // adjustments. But I will still need it."
                //
                // SO THE OVERLAP IS SHOWN RATHER THAN PREVENTED. The cone chooser marks the
                // row whose stored cone id matches, so a frequency that is not one of the
                // three leaves the chooser with nothing marked - which is the truth, and is
                // better than a chooser confidently pointing at a cone the transducer is not
                // transmitting. Picking a cone afterwards overwrites this, as it should.
                //
                // The bounds on a 2D transducer are the profile's own widest and narrowest
                // cone, so this cannot ask for a frequency outside what the device is
                // configured for.
                //
                // A SIDE SCAN HAS NO CONES, so its bounds were 460..460 and 820 put the knob
                // off the end of the track. Olav, 3 Oct: the expert must be free to play,
                // anywhere from 320 to 850 kHz - which also retires the 460 / 820 buttons
                // that stood above this row for the waypoint desk check (that check is done).
                // pulseRuntimeSettings.sideScanFreqMin/Max name the span once; setParam holds it.
                PulseSliderRow {
                    width: transducerGroup.contentWidth
                    uiScale: list.uiScale
                    showNudges: true

                    readonly property bool sideScan: pulseRuntimeSettings ? !pulseRuntimeSettings.is2DTransducer : false

                    label: qsTr("Frequency")
                    hint:  sideScan
                           ? qsTr("side scan, %1-%2 kHz - the ordinary setting is 460").arg(minValue).arg(maxValue)
                           : qsTr("between the widest and narrowest cone - the cone buttons also write this")
                    minValue: !pulseRuntimeSettings ? 0
                              : sideScan ? pulseRuntimeSettings.sideScanFreqMin : pulseRuntimeSettings.transFreqWide
                    maxValue: !pulseRuntimeSettings ? 0
                              : sideScan ? pulseRuntimeSettings.sideScanFreqMax : pulseRuntimeSettings.transFreqNarrow
                    stepSize: 5
                    value: list.paramNum("transFreq", pulseRuntimeSettings ? pulseRuntimeSettings.transFreqWide : 0)
                    valueText: list.paramText("transFreq",
                                              pulseRuntimeSettings ? pulseRuntimeSettings.transFreq_Copy : -1,
                                              qsTr("kHz"))

                    onMoved: function (v) {
                        list.settingChanged("param", "transFreq", v)
                    }
                },

                // 0 or 1 on the device, so a switch rather than a slider across two values.
                PulseSwitchRow {
                    width: transducerGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Transmit boost")
                    hint:  qsTr("more power into the water")
                    checked: list.paramNum("transBoost", 0) === 1

                    onToggled: function (v) {
                        list.settingChanged("param", "transBoost", v ? 1 : 0)
                    }
                },

                // THE GATE FOR THE TWO ROWS ABOVE AND THE ONE BELOW, so it sits between
                // them rather than at the foot of the group. While it is on, DeviceItem
                // drives chartResolution and writes ch1Period from dynamicPeriod - so a
                // hand value is overwritten and the row that set it looks broken.
                //
                // Olav, 17 Sept: "Red has dynamic adjustments now. But that is for wifi
                // compromises. We may disable that entirely for IP." This is the switch
                // that lets that be tried on the water rather than decided in advance.
                PulseSwitchRow {
                    width: transducerGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Dynamic resolution")
                    hint:  qsTr("the app drives spacing and ping period - a wifi compromise")
                    checked: list.paramNum("doDynamicResolution", 0) ? true : false

                    onToggled: function (v) {
                        list.settingChanged("param", "doDynamicResolution", v)
                    }
                },

                PulseSliderRow {
                    width: transducerGroup.contentWidth
                    uiScale: list.uiScale
                    showNudges: true

                    label: qsTr("Ping period")
                    // THE HINT SAYS WHO IS HOLDING THE VALUE, because while dynamic
                    // resolution is on this row is a display and not a control: the app
                    // writes ch1Period from dynamicPeriod and a hand value does not
                    // survive. A row that silently loses its value reads as a bug.
                    enabled: !(pulseRuntimeSettings && pulseRuntimeSettings.perfEngineOwnsAcquisition)
                    opacity: enabled ? 1.0 : 0.45
                    hint: !enabled ? qsTr("held by performance mode")
                        : list.paramNum("doDynamicResolution", 0)
                        ? qsTr("the app is driving this - turn Dynamic resolution off to hold it")
                        : qsTr("milliseconds between pings - this is the echogram's speed")
                    // 40-160 ms (2 Oct 2026). It ran 0-2000: on the G30 with a live blue
                    // prototype the drag could not be placed finely and fell below 30 ms, which
                    // lost the link until the transducer was power cycled. Nothing needs more
                    // than 160 (red's dynamic scheme tops out at 154), and below 40 there is no
                    // range left to listen to. Twelve times finer per pixel than before.
                    minValue: 40
                    maxValue: 160
                    stepSize: 5
                    value: list.paramNum("ch1Period", 50)
                    valueText: list.paramText("ch1Period",
                                              pulseRuntimeSettings ? pulseRuntimeSettings.ch1Period_Copy : -1,
                                              qsTr("ms"))

                    onMoved: function (v) {
                        list.settingChanged("param", "ch1Period", v)
                    }
                },

                PulseSliderRow {
                    width: transducerGroup.contentWidth
                    uiScale: list.uiScale
                    showNudges: true

                    label: qsTr("Bottom confidence")
                    hint:  qsTr("how sure the device must be before it calls a bottom")
                    minValue: 0
                    maxValue: 100
                    stepSize: 1
                    value: list.paramNum("distConfidence", 0)
                    valueText: list.paramText("distConfidence",
                                              pulseRuntimeSettings ? pulseRuntimeSettings.distConfidence_Copy : -1)

                    onMoved: function (v) {
                        list.settingChanged("param", "distConfidence", v)
                    }
                },

                // TWO WRITES FROM ONE CONTROL, and they are not a pair that can be split:
                // distMax is the device's search ceiling in millimetres and maximumDepth is
                // the app's in metres, and classic has always moved them together. The +2 m
                // on a 2D transducer comes straight from classic's row.
                //
                // It asks is2DTransducer rather than comparing userManualSetName against
                // modelPulseRed and modelPulseRedProto, which is what classic does: the
                // question here is "is this a 2D transducer", and two name comparisons are
                // two names that will be spelt wrong when a third red arrives.
                // A 2D TRANSDUCER'S MAXIMUM DEPTH, as before: the rangefinder's search depth
                // (distMax) and the app's ceiling (maximumDepth) together.
                PulseSliderRow {
                    width: transducerGroup.contentWidth
                    height: visible ? implicitHeight : 0
                    visible: pulseRuntimeSettings ? pulseRuntimeSettings.is2DTransducer : false
                    uiScale: list.uiScale
                    showNudges: true

                    label: qsTr("Maximum depth")
                    hint:  qsTr("how deep the device searches - metres")
                    minValue: 1000
                    maxValue: 50000
                    stepSize: 1000
                    value: list.paramNum("distMax", 1000)
                    valueText: {
                        if (!pulseRuntimeSettings)
                            return ""
                        var mm  = list.paramNum("distMax", -1)
                        if (mm < 0)
                            return qsTr("not set")
                        var dev = pulseRuntimeSettings.distMax_Copy
                        var t   = Math.round(mm / 1000) + " " + qsTr("m")
                        if (dev >= 0 && dev !== mm)
                            t += "  (device " + Math.round(dev / 1000) + ")"
                        return t
                    }

                    onMoved: function (v) {
                        list.settingChanged("param", "distMax", v)
                        list.settingChanged("param", "maximumDepth",
                                            v / 1000 + (pulseRuntimeSettings && pulseRuntimeSettings.is2DTransducer ? 2 : 0))
                    }
                },

                // THE WAY BACK, and the row that makes the rest of this group safe to play
                // with. clearParams drops the committed profile's whole override entry, so
                // every key above falls through to the profile's own value at once.
                //
                // It asks, because it throws away work: a tuning session is a sequence of
                // small judgements and losing it to a mis-tap would be worse than any value
                // in it.
                PulseActionRow {
                    width: transducerGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Back to the profile")
                    hint:  qsTr("every value here returns to what this device ships with")
                    actionText: qsTr("Reset")
                    question:    qsTr("Drop every tuning change on this transducer?")
                    confirmText: qsTr("Reset")

                    onActivated: list.actionRequested("clearParams")
                }
            ]
        }

        // ---- Performance mode (Task 2a, step 1, 2 Oct 2026) --------------------
        //
        // THE EXPERT'S LIMITS, AND THE TWO READINGS THAT TELL HIM WHETHER THEY HOLD. Olav's
        // four persistent rows (claude/pulse-high-performance-mode.md, 6.2), plus Serial link
        // and Lost chart samples. STEP 1 SENDS NOTHING TO THE TRANSDUCER: the switch and the
        // limits are stored, and the engine that reads them is step 2. The read-outs are
        // what the step-2 engine's 85% headroom is measured with, on the Transducer rows
        // above, before anything relies on it.
        //
        // The readings are measured, not estimated: every frame from a live link is counted
        // as it arrives (DeviceManagerWrapper.sampleLinkStats), against the baud the
        // transducer itself reports. The loss is the chart's own seqOffset gaps, in samples;
        // a ping lost whole is invisible to it.
        PulseSettingsGroup {
            id: perfGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly

            uiScale: list.uiScale
            title: qsTr("Performance mode")
            open: list.openId === "performance"
            onToggled: list.toggle("performance")

            content: [
                PulseSwitchRow {
                    width: perfGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Enable performance mode")
                    hint:  qsTr("PULSE blue, live: spacing and samples follow Max range side; off hands the shipped settings back")
                    checked: pulseSettings ? pulseSettings.perfModeEnabled : false

                    onToggled: function (v) {
                        list.settingChanged("persistent", "perfModeEnabled", v)
                    }
                },

                // WHAT THE ENGINE DID, and what binds it - the same line as ENGINE: in the log.
                PulseReadOnlyRow {
                    width: perfGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Engine")
                    hint:  qsTr("what the transducer was last told, and what limits it")
                    value: pulseRuntimeSettings && pulseRuntimeSettings.perfEngineStatus !== ""
                           ? pulseRuntimeSettings.perfEngineStatus : "\u2014"
                },

                PulseSliderRow {
                    width: perfGroup.contentWidth
                    uiScale: list.uiScale
                    showNudges: true

                    label: qsTr("Max samples")
                    hint:  qsTr("the most the engine may ask for per ping")
                    minValue: 500
                    maxValue: 5000
                    stepSize: 50
                    value: pulseSettings ? pulseSettings.perfMaxSamples : 5000
                    valueText: String(value)

                    onMoved: function (v) {
                        list.settingChanged("persistent", "perfMaxSamples", v)
                    }
                },

                PulseSliderRow {
                    width: perfGroup.contentWidth
                    uiScale: list.uiScale
                    showNudges: true

                    label: qsTr("Min spacing blue")
                    hint:  qsTr("the finest sample spacing allowed on a side scan")
                    minValue: 1
                    maxValue: 50
                    stepSize: 1
                    value: pulseSettings ? pulseSettings.perfMinSpacingBlueMm : 15
                    valueText: value + " " + qsTr("mm")

                    onMoved: function (v) {
                        list.settingChanged("persistent", "perfMinSpacingBlueMm", v)
                    }
                },

                // A SIDE SCAN'S MAX RANGE CEILING (Olav, 3 Oct 2026), in Performance mode beside
                // the limits it works with (it began in Transducer). It replaced a blue's
                // Maximum depth row, which wrote distMax and maximumDepth, so a drag moved the
                // range on screen - which
                // the Max range sliders and the pinch already do. What the expert needs instead
                // is to say how FAR those may go: from the Side scan width (25 or 35 m) up to
                // 50 m, the longest range whose listen time still fits the fixed 70 ms. Stored
                // (a limit the expert has cleared, like the Performance mode rows), and active
                // only while performance mode holds the acquisition - only then is the range
                // beyond the Side scan width really acquired. A blue's distMax is the engine's
                // (1000 x R) while it holds, and the shipped 1000 x width otherwise.
                PulseSliderRow {
                    width: perfGroup.contentWidth
                    height: visible ? implicitHeight : 0
                    visible: pulseRuntimeSettings ? !pulseRuntimeSettings.is2DTransducer : false
                    uiScale: list.uiScale
                    showNudges: true

                    readonly property int sideWidth: pulseSettings ? Math.round(pulseSettings.echogramWidth) : 25
                    readonly property bool active: pulseRuntimeSettings ? pulseRuntimeSettings.perfEngineOwnsAcquisition : false

                    label: qsTr("Max range ceiling")
                    hint:  active
                           ? qsTr("how far Max range and the pinch may go - up to %1 m at 70 ms").arg(maxValue)
                           : qsTr("takes effect with performance mode; until then the Side scan width (%1 m) is the ceiling").arg(sideWidth)
                    minValue: sideWidth
                    maxValue: pulseRuntimeSettings ? pulseRuntimeSettings.sideScanRangeCeilingMax : 50
                    stepSize: 5
                    value: Math.max(sideWidth, pulseSettings ? pulseSettings.perfMaxRangeSideM : 0)
                    valueText: value + " " + qsTr("m")

                    onMoved: function (v) {
                        list.settingChanged("persistent", "perfMaxRangeSideM", v)
                    }
                },

                // THE PULSE FOLLOWS THE RANGE (Olav, 3 Oct 2026) - for the testers to see the
                // difference on the water and in recordings: off, every ping is the profile's 10
                // cycles; on, the engine sets about 1.2 cycles per mm of spacing, 4-10 - capped
                // at the standard 10 by the hardware partner (resistors). So it only ever
                // SHORTENS the pulse: up to about 20 m, for finer object separation.
                // Sends no extra data. The Engine row and the ENGINE: line name the count.
                PulseSwitchRow {
                    width: perfGroup.contentWidth
                    height: visible ? implicitHeight : 0
                    visible: pulseRuntimeSettings ? !pulseRuntimeSettings.is2DTransducer : false
                    uiScale: list.uiScale

                    label: qsTr("Pulse follows the range")
                    hint:  checked
                           ? qsTr("on: a shorter pulse up to ~20 m to separate nearby objects; 10 cycles beyond")
                           : qsTr("off: the same 10-cycle pulse at every range")
                    checked: pulseSettings ? pulseSettings.perfPulseFollowsRange : false

                    onToggled: function (v) {
                        list.settingChanged("persistent", "perfPulseFollowsRange", v)
                    }
                },

                PulseSliderRow {
                    width: perfGroup.contentWidth
                    uiScale: list.uiScale
                    showNudges: true

                    label: qsTr("Min spacing 2D")
                    hint:  qsTr("the finest sample spacing allowed on red and black")
                    minValue: 1
                    maxValue: 50
                    stepSize: 1
                    value: pulseSettings ? pulseSettings.perfMinSpacing2DMm : 2
                    valueText: value + " " + qsTr("mm")

                    onMoved: function (v) {
                        list.settingChanged("persistent", "perfMinSpacing2DMm", v)
                    }
                },

                PulseReadOnlyRow {
                    width: perfGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Serial link")
                    hint:  qsTr("measured on the live link over 10 s, against the baud the transducer reports; pings/s are complete pings received")
                    value: {
                        const w = deviceManagerWrapper
                        if (!w || w.linkBytesPerSecond <= 0)
                            return w && w.linkBaud > 0 ? w.linkBaud + " " + qsTr("baud, idle") : "\u2014"
                        const kb = (w.linkBytesPerSecond / 1000).toFixed(1) + " kB/s"
                        if (w.linkBaud <= 0)
                            return kb + " | " + qsTr("baud not reported")
                        if (!w.linkBaudPlausible)
                            return kb + " | " + qsTr("reported baud") + " " + w.linkBaud + " " + qsTr("cannot carry this - load unknown")
                        // the real ping rate (Task 2b step 1): what arrives, not what was asked
                        const pings = w.linkPingsPerSecond >= 0
                                      ? " | " + w.linkPingsPerSecond.toFixed(1) + " " + qsTr("pings/s") : ""
                        return w.linkBaud + " " + qsTr("baud") + " | " + kb + " | "
                               + w.linkLoadPercent.toFixed(0) + "% " + qsTr("used") + pings
                    }
                },

                PulseReadOnlyRow {
                    width: perfGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Lost chart samples")
                    hint:  qsTr("gaps inside a ping; a recording or demo counts too")
                    value: {
                        const w = deviceManagerWrapper
                        if (!w || w.chartLossPercentTotal < 0)
                            return "\u2014"
                        return (w.chartLossPercent >= 0 ? w.chartLossPercent.toFixed(2) + "% " + qsTr("last 10 s") : qsTr("none flowing"))
                               + " | " + w.chartLossPercentTotal.toFixed(2) + "% " + qsTr("since start")
                    }
                }
            ]
        }

        // ---- Water body filter ------------------------------------------------

        PulseSettingsGroup {
            id: waterBodyGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly

            uiScale: list.uiScale
            title: qsTr("Water body filter")
            open: list.openId === "waterbody"
            onToggled: list.toggle("waterbody")

            content: [
                PulseSwitchRow {
                    width: waterBodyGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Water body filtering")
                    hint:  qsTr("the rail's filter drives this instead of the global low cut")
                    checked: pulseRuntimeSettings ? pulseRuntimeSettings.echogramWaterBodyFilterEnabled : false

                    onToggled: function (v) {
                        list.settingChanged("runtime", "echogramWaterBodyFilterEnabled", v)
                    }
                },

                PulseStepperRow {
                    width: waterBodyGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Bottom margin")
                    hint:  qsTr("how far above the bottom the filter stops")
                    unit:  qsTr("m")
                    decimals: 2
                    values: [0.0, 0.05, 0.1, 0.15, 0.2, 0.3, 0.5]
                    value: pulseRuntimeSettings ? pulseRuntimeSettings.echogramWaterBodyBottomMargin : 0

                    onStepped: function (v) {
                        list.settingChanged("runtime", "echogramWaterBodyBottomMargin", v)
                    }
                }
            ]
        }

        // ---- TVG 2D -----------------------------------------------------------

        PulseSettingsGroup {
            id: tvg2dGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly

            uiScale: list.uiScale
            title: qsTr("TVG 2D")
            open: list.openId === "tvg2d"
            onToggled: list.toggle("tvg2d")

            content: [
                PulseSwitchRow {
                    width: tvg2dGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Depth compensation")
                    hint:  qsTr("gain computed from range in metres, so resolution changes do not shift it")
                    checked: pulseRuntimeSettings ? pulseRuntimeSettings.echogramTvgEnabled : false

                    // THE OVERRIDE, NEVER THE VALUE - echogramTvgEnabled is a readonly
                    // binding on the committed profile. See the note in
                    // PulseRuntimeSettings; the mosaic row below does the same.
                    onToggled: function (v) {
                        list.settingChanged("runtime", "echogramTvgOverride", v ? 1 : 2)
                    }
                },

                PulseStepperRow {
                    width: tvg2dGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Gain")
                    unit:  qsTr("dB/m")
                    decimals: 1
                    values: [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0,
                             1.1, 1.2, 1.4, 1.6, 1.8, 2.0]
                    value: pulseRuntimeSettings ? pulseRuntimeSettings.echogramTvgDbPerMeter : 1.0

                    onStepped: function (v) {
                        list.settingChanged("runtime", "echogramTvgDbPerMeter", v)
                    }
                },

                PulseSwitchRow {
                    width: tvg2dGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Compare with the upstream ramp")
                    hint:  qsTr("gain over sample index instead - moves when resolution does")
                    checked: pulseRuntimeSettings ? pulseRuntimeSettings.echogram2DUpstreamTgc : false

                    onToggled: function (v) {
                        list.settingChanged("runtime", "echogram2DUpstreamTgc", v)
                    }
                }
            ]
        }

        // ---- TVG side scan ----------------------------------------------------

        PulseSettingsGroup {
            id: tvgSideGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly

            uiScale: list.uiScale
            title: qsTr("TVG side scan")
            open: list.openId === "tvgside"
            onToggled: list.toggle("tvgside")

            content: [
                PulseSwitchRow {
                    width: tvgSideGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Side scan TVG")
                    hint:  qsTr("the waterfall")
                    checked: pulseRuntimeSettings ? pulseRuntimeSettings.sideScanTvgEnabled : false

                    // The override, never the value. Same reason as the 2D row above.
                    onToggled: function (v) {
                        list.settingChanged("runtime", "sideScanTvgOverride", v ? 1 : 2)
                    }
                },

                PulseSwitchRow {
                    width: tvgSideGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Use it for the mosaic too")
                    hint:  qsTr("on by default for a side scan; off makes the mosaic brighter at the centre of the line")
                    checked: pulseRuntimeSettings ? pulseRuntimeSettings.sideScanTvgMosaicEnabled : false

                    // THE OVERRIDE, NEVER THE VALUE. sideScanTvgMosaicEnabled is a binding
                    // on the committed profile and assigning to it would destroy that
                    // binding permanently - which is exactly what the Side scan TVG switch
                    // above still does to its own. 1 forces it on, 2 forces it off, and 0
                    // (untouched) leaves the profile deciding.
                    onToggled: function (v) {
                        list.settingChanged("runtime", "sideScanTvgMosaicOverride", v ? 1 : 2)
                    }
                },

                PulseStepperRow {
                    width: tvgSideGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Noise floor subtraction")
                    decimals: 2
                    values: [0, 0.1, 0.15, 0.2, 0.25, 0.4, 0.5, 0.75, 1.0]
                    value: pulseRuntimeSettings ? pulseRuntimeSettings.sideScanTvgNoiseFloor : 0

                    onStepped: function (v) {
                        list.settingChanged("runtime", "sideScanTvgNoiseFloor", v)
                    }
                },

                PulseStepperRow {
                    width: tvgSideGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Spreading")
                    unit:  qsTr("dB/decade")
                    decimals: 1
                    values: [0, 2.5, 5, 7.5, 10, 12.5, 15, 20, 25, 30, 35, 40]
                    value: pulseRuntimeSettings ? pulseRuntimeSettings.sideScanTvgSpreading : 0

                    onStepped: function (v) {
                        list.settingChanged("runtime", "sideScanTvgSpreading", v)
                    }
                },

                PulseStepperRow {
                    width: tvgSideGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Absorption")
                    unit:  qsTr("dB/m")
                    decimals: 2
                    values: [0, 0.02, 0.05, 0.1, 0.15, 0.2, 0.3, 0.5, 0.8, 1.0]
                    value: pulseRuntimeSettings ? pulseRuntimeSettings.sideScanTvgAbsorption : 0

                    onStepped: function (v) {
                        list.settingChanged("runtime", "sideScanTvgAbsorption", v)
                    }
                },

                PulseStepperRow {
                    width: tvgSideGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Reference range")
                    unit:  qsTr("m")
                    decimals: 0
                    values: [2, 5, 10, 15, 20, 30, 50]
                    value: pulseRuntimeSettings ? pulseRuntimeSettings.sideScanTvgRefRange : 10

                    onStepped: function (v) {
                        list.settingChanged("runtime", "sideScanTvgRefRange", v)
                    }
                },

                PulseStepperRow {
                    width: tvgSideGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Detail boost")
                    decimals: 1
                    values: [0, 0.1, 0.2, 0.3, 0.5, 0.7, 0.9, 1.2, 1.5]
                    value: pulseRuntimeSettings ? pulseRuntimeSettings.sideScanTvgBoost : 0

                    onStepped: function (v) {
                        list.settingChanged("runtime", "sideScanTvgBoost", v)
                    }
                }
            ]
        }

        // ---- Down scan --------------------------------------------------------
        //
        // The down pane draws ONE trace, and until now that trace was one of the two side
        // scan channels - channel 2, by arithmetic rather than by choice (its range is
        // 0..R, so the negative half of the two-channel draw is zero pixels wide). Port and
        // starboard are two independent looks at the same vertical return, so combining
        // them is ordinary multi-look processing. src/scene2d/echogram_blend.h has the law.
        //
        // THE DEFAULTS ARE THE RECOMMENDATION, not a neutral starting point, and these rows
        // exist so it can be FALSIFIED on the water rather than argued about. Single is
        // kept as the A/B reference against the picture this replaces.
        //
        // The nadir fill rows land in this group when the mosaic half of P3 is built. They
        // are not here yet because they would be controls for something that does not exist
        // - absent rather than greyed, at the row level too.
        PulseSettingsGroup {
            id: downScanGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly && list.offersDownBlend

            uiScale: list.uiScale
            title: qsTr("Down scan")
            open: list.openId === "downscan"
            onToggled: list.toggle("downscan")

            content: [
                PulseSegmentRow {
                    width: downScanGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Channel blend")
                    hint:  qsTr("two looks at the same return - RMS is the multi-look average")
                    options: [ { value: 0, title: qsTr("Single") },
                               { value: 1, title: qsTr("RMS") },
                               { value: 2, title: qsTr("Mean") },
                               { value: 3, title: qsTr("Max") } ]
                    current: pulseRuntimeSettings ? pulseRuntimeSettings.downScanBlendMode : 1

                    onChosen: function (v) {
                        list.settingChanged("runtime", "downScanBlendMode", v)
                    }
                },

                // ABSENT WITH NO BLEND ON, because there is then nothing for it to describe.
                PulseSegmentRow {
                    width: downScanGroup.contentWidth
                    height: visible ? implicitHeight : 0
                    visible: (pulseRuntimeSettings ? pulseRuntimeSettings.downScanBlendMode : 1) !== 0
                    uiScale: list.uiScale

                    label: qsTr("Blend the")
                    hint:  qsTr("raw is the honest one - the gain law is adaptive along each trace")
                    options: [ { value: 0, title: qsTr("Raw") },
                               { value: 1, title: qsTr("After gain") } ]
                    current: pulseRuntimeSettings ? pulseRuntimeSettings.downScanBlendDomain : 0

                    onChosen: function (v) {
                        list.settingChanged("runtime", "downScanBlendDomain", v)
                    }
                },

                // A LADDER, so a stepper rather than a segmented row - these are points on a
                // scale, not answers with names. Also absent with the blend off, for the same
                // reason the row above is.
                PulseStepperRow {
                    width: downScanGroup.contentWidth
                    height: visible ? implicitHeight : 0
                    visible: (pulseRuntimeSettings ? pulseRuntimeSettings.downScanBlendMode : 1) !== 0
                    uiScale: list.uiScale

                    label: qsTr("Channel balance")
                    hint:  qsTr("by eye - plus favours the starboard channel, half applied each way")
                    unit:  qsTr("dB")
                    decimals: 0
                    values: [-6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6]
                    value: pulseRuntimeSettings ? pulseRuntimeSettings.downScanBlendTrimDb : 0

                    onStepped: function (v) {
                        list.settingChanged("runtime", "downScanBlendTrimDb", v)
                    }
                },

                // ---- the mosaic nadir ----------------------------------------
                //
                // The dark band along the track in the mosaic is the physical nadir null,
                // not a geometry error - our slant-range lookup was checked end to end.
                // The fill interpolates ACROSS the track between the two sides' trusted
                // edge values; see src/data_processor/mosaic_nadir.h.
                //
                // TURNING IT OFF IS THE DIAGNOSTIC, which is why there is no "show the
                // nadir edge" row: off shows exactly where the band was, and a drawn
                // boundary would only approximate it.
                PulseSwitchRow {
                    width: downScanGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Fill the mosaic nadir")
                    hint:  qsTr("interpolated, not measured - off shows the band as it is")
                    checked: pulseRuntimeSettings ? pulseRuntimeSettings.nadirFillEnabled : false

                    onToggled: function (v) {
                        list.settingChanged("runtime", "nadirFillEnabled", v)
                    }
                },

                PulseStepperRow {
                    width: downScanGroup.contentWidth
                    height: visible ? implicitHeight : 0
                    visible: pulseRuntimeSettings ? pulseRuntimeSettings.nadirFillEnabled : false
                    uiScale: list.uiScale

                    label: qsTr("Fully filled inside")
                    hint:  qsTr("times the depth - the beam has nothing here")
                    decimals: 1
                    values: [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.7, 1.0]
                    value: pulseRuntimeSettings ? pulseRuntimeSettings.nadirInnerFactor : 0.3

                    onStepped: function (v) {
                        list.settingChanged("runtime", "nadirInnerFactor", v)
                    }
                },

                PulseStepperRow {
                    width: downScanGroup.contentWidth
                    height: visible ? implicitHeight : 0
                    visible: pulseRuntimeSettings ? pulseRuntimeSettings.nadirFillEnabled : false
                    uiScale: list.uiScale

                    label: qsTr("Fully real outside")
                    hint:  qsTr("times the depth - 1.0 is the 45 degree line")
                    decimals: 1
                    values: [0.4, 0.5, 0.6, 0.8, 1.0, 1.2, 1.5, 2.0]
                    value: pulseRuntimeSettings ? pulseRuntimeSettings.nadirOuterFactor : 1.0

                    onStepped: function (v) {
                        list.settingChanged("runtime", "nadirOuterFactor", v)
                    }
                }
            ]
        }

        // ---- Bottom track -----------------------------------------------------
        //
        // FIVE OF THESE EIGHT ROWS LIVE INSIDE ONE ARRAY, distProcessing, and they write
        // through setDistProcessingAt() rather than by index assignment - see
        // PulseRuntimeSettings: the binding hands back the profile's OWN array, so the old
        // controls were editing the record they read their defaults from.
        PulseSettingsGroup {
            id: bottomTrackGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly

            uiScale: list.uiScale
            title: qsTr("Bottom track")
            open: list.openId === "bottomtrack"
            onToggled: list.toggle("bottomtrack")

            content: [
                // FOUR ROWS HERE WRITE A MANAGED DEVICE PARAMETER - processBottomTrack
                // and bottomTrackVisible in this group, both black-stripe steps below - so
                // they use the "param" target rather than "runtime". Those properties are
                // readonly now and live in the per-profile parameter map; see "THE LIVE
                // DEVICE PARAMETER STATE" in PulseRuntimeSettings.qml.
                PulseSwitchRow {
                    width: bottomTrackGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Use bottom track for depth")
                    hint:  qsTr("the rangefinder answers when this is off")
                    checked: pulseRuntimeSettings ? pulseRuntimeSettings.processBottomTrack : false

                    onToggled: function (v) {
                        list.settingChanged("param", "processBottomTrack", v)
                    }
                },

                PulseSwitchRow {
                    width: bottomTrackGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Draw the bottom track")
                    checked: pulseRuntimeSettings ? pulseRuntimeSettings.bottomTrackVisible : false

                    onToggled: function (v) {
                        list.settingChanged("param", "bottomTrackVisible", v)
                    }
                },

                PulseSwitchRow {
                    width: bottomTrackGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Draw the raw rangefinder line")
                    hint:  qsTr("for comparing the two sources on the picture")
                    checked: pulseRuntimeSettings ? pulseRuntimeSettings.rangefinderTrackVisible : false

                    onToggled: function (v) {
                        list.settingChanged("runtime", "rangefinderTrackVisible", v)
                    }
                },

                PulseStepperRow {
                    width: bottomTrackGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Gain slope")
                    decimals: 1
                    values: [1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0,
                             2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 3.0]
                    value: (pulseRuntimeSettings && pulseRuntimeSettings.distProcessing)
                           ? pulseRuntimeSettings.distProcessing[5] : 1.0

                    onStepped: function (v) {
                        if (pulseRuntimeSettings)
                            pulseRuntimeSettings.setDistProcessingAt(5, v)
                    }
                },

                PulseStepperRow {
                    width: bottomTrackGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Window")
                    decimals: 0
                    values: [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
                             18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
                    value: (pulseRuntimeSettings && pulseRuntimeSettings.distProcessing)
                           ? pulseRuntimeSettings.distProcessing[1] : 3

                    onStepped: function (v) {
                        if (pulseRuntimeSettings)
                            pulseRuntimeSettings.setDistProcessingAt(1, v)
                    }
                },

                PulseStepperRow {
                    width: bottomTrackGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Vertical gap")
                    decimals: 0
                    values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
                             11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
                    value: (pulseRuntimeSettings && pulseRuntimeSettings.distProcessing)
                           ? pulseRuntimeSettings.distProcessing[2] : 0

                    onStepped: function (v) {
                        if (pulseRuntimeSettings)
                            pulseRuntimeSettings.setDistProcessingAt(2, v)
                    }
                },

                // A LADDER THAT WAS NOT ASCENDING. Classic's list for this row reads
                // [0.0, 0.5, 0.10, 0.15, ...] - 0.5 where 0.05 was plainly meant, sitting
                // second in a list that then continues at 0.10. A stepper cannot walk that:
                // the rung order IS the control. Corrected here, and classic still has the
                // typo - flagged rather than changed, because it is Olav's number.
                PulseStepperRow {
                    width: bottomTrackGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Shallowest depth evaluated")
                    unit:  qsTr("m")
                    decimals: 2
                    values: [0.0, 0.05, 0.10, 0.15, 0.20, 0.25,
                             0.30, 0.35, 0.40, 0.45, 0.50]
                    value: (pulseRuntimeSettings && pulseRuntimeSettings.distProcessing)
                           ? pulseRuntimeSettings.distProcessing[3] : 0

                    onStepped: function (v) {
                        if (pulseRuntimeSettings)
                            pulseRuntimeSettings.setDistProcessingAt(3, v)
                    }
                },

                PulseStepperRow {
                    width: bottomTrackGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Deepest depth evaluated")
                    unit:  qsTr("m")
                    decimals: 0
                    values: [20, 25, 30, 35, 40, 45, 50, 55, 60, 70, 80, 90, 100]
                    value: (pulseRuntimeSettings && pulseRuntimeSettings.distProcessing)
                           ? pulseRuntimeSettings.distProcessing[4] : 20

                    onStepped: function (v) {
                        if (pulseRuntimeSettings)
                            pulseRuntimeSettings.setDistProcessingAt(4, v)
                    }
                }
            ]
        }

        // ---- Depth filter -----------------------------------------------------

        PulseSettingsGroup {
            id: depthFilterGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly

            uiScale: list.uiScale
            title: qsTr("Depth filter")
            open: list.openId === "depthfilter"
            onToggled: list.toggle("depthfilter")

            content: [
                PulseSwitchRow {
                    width: depthFilterGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Filter the depth")
                    checked: pulseRuntimeSettings ? pulseRuntimeSettings.useDepthFilter : false

                    onToggled: function (v) {
                        list.settingChanged("runtime", "useDepthFilter", v)
                    }
                },

                PulseSwitchRow {
                    width: depthFilterGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Filter bottom track too")
                    checked: pulseRuntimeSettings ? pulseRuntimeSettings.useFilterWithBottomTrack : false

                    onToggled: function (v) {
                        list.settingChanged("runtime", "useFilterWithBottomTrack", v)
                    }
                },

                PulseStepperRow {
                    width: depthFilterGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Fluctuation margin")
                    hint:  qsTr("changes smaller than this are treated as the same depth")
                    unit:  qsTr("m")
                    decimals: 1
                    values: [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]
                    value: pulseRuntimeSettings ? pulseRuntimeSettings.kSmallAgreeMargin : 0

                    onStepped: function (v) {
                        list.settingChanged("runtime", "kSmallAgreeMargin", v)
                    }
                },

                PulseStepperRow {
                    width: depthFilterGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Suspicious jump")
                    hint:  qsTr("a step larger than this has to be confirmed")
                    unit:  qsTr("m")
                    decimals: 1
                    values: [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
                    value: pulseRuntimeSettings ? pulseRuntimeSettings.kLargeJumpThreshold : 0

                    onStepped: function (v) {
                        list.settingChanged("runtime", "kLargeJumpThreshold", v)
                    }
                },

                PulseStepperRow {
                    width: depthFilterGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Readings that confirm it")
                    decimals: 0
                    values: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
                    value: pulseRuntimeSettings ? pulseRuntimeSettings.kConsistNeeded : 1

                    onStepped: function (v) {
                        list.settingChanged("runtime", "kConsistNeeded", v)
                    }
                }
            ]
        }

        // ---- Black stripes ----------------------------------------------------

        PulseSettingsGroup {
            id: stripesGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly

            uiScale: list.uiScale
            title: qsTr("Black stripes")
            open: list.openId === "stripes"
            onToggled: list.toggle("stripes")

            content: [
                PulseStepperRow {
                    width: stripesGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Repair looking forward")
                    hint:  qsTr("missing pings guessed from the columns after the gap")
                    decimals: 0
                    values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
                    value: pulseRuntimeSettings ? pulseRuntimeSettings.fixBlackStripesForwardSteps : 0

                    onStepped: function (v) {
                        list.settingChanged("param", "fixBlackStripesForwardSteps", v)
                    }
                },

                PulseStepperRow {
                    width: stripesGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Repair looking back")
                    decimals: 0
                    values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
                    value: pulseRuntimeSettings ? pulseRuntimeSettings.fixBlackStripesBackwardSteps : 0

                    onStepped: function (v) {
                        list.settingChanged("param", "fixBlackStripesBackwardSteps", v)
                    }
                }
            ]
        }

        // ---- Depth manipulation -----------------------------------------------
        //
        // A TEST HARNESS, and the hints say so. Nothing here is a tuning knob: it makes the
        // app believe in a depth it is not measuring, which is how the display and the NMEA
        // output get exercised without a boat.
        PulseSettingsGroup {
            id: fakeDepthGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly

            uiScale: list.uiScale
            title: qsTr("Depth manipulation")
            open: list.openId === "fakedepth"
            onToggled: list.toggle("fakedepth")

            content: [
                PulseStepperRow {
                    width: fakeDepthGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Add to the measured depth")
                    hint:  qsTr("testing only - the picture is no longer what the water says")
                    unit:  qsTr("m")
                    minValue: 0
                    maxValue: 60
                    stepSize: 0.1
                    decimals: 1
                    value: pulseRuntimeSettings ? pulseRuntimeSettings.fakeDepthAddition : 0

                    onStepped: function (v) {
                        list.settingChanged("runtime", "fakeDepthAddition", v)
                    }
                },

                // NO "PUSH FAKE DEPTH TO KLF VIEW" ROW. Olav: "We actually do not need this
                // setting at all. This was used to modify the depth value when we made
                // screenshots of a file opened. Now we can make screenshots running demo,
                // and then depth value is always correct." Classic's row and the
                // pushFakeDepth key are left alone - removing them is a cleanup, not a
                // settings decision.
                PulseActionRow {
                    width: fakeDepthGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Back to the real depth")
                    actionText: qsTr("Reset")

                    onActivated: list.actionRequested("resetFakeDepth")
                }
            ]
        }

        PulseSettingsSection {
            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly
            uiScale: list.uiScale
            title: qsTr("Expert info")
        }

        // ---- Device raw information -------------------------------------------
        //
        // WHAT THE DEVICE SAYS IT IS, before the app has decided anything about it. Ported
        // from PulseInfoExpert's four read-only categories, which the placeholder that used
        // to stand here was holding the shape of.
        //
        // THE "Device: " PREFIX ON EVERY LABEL IS GONE. Classic needed it because its rows
        // sat in one long list; here the category IS the prefix, and repeating it thirteen
        // times spends the width that the value needs.
        //
        // A BOOLEAN READS Yes/No AND A DATASET FLAG READS On/Off, rather than classic's
        // bare "true". A row whose value is the word true is a row that has been printed
        // rather than written.
        PulseSettingsGroup {
            id: devrawGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly

            uiScale: list.uiScale
            title: qsTr("Device raw information")
            open: list.openId === "devraw"
            onToggled: list.toggle("devraw")

            content: [
                PulseReadOnlyRow {
                    width: devrawGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Device name")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.rawDev_devName) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devrawGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Device type")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.rawDev_devType) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devrawGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("devList dump")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.rawDev_devListDump) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devrawGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Baud rate")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.rawDev_devBaudRate) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devrawGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Serial number")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.rawDev_devSerialNumber) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devrawGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Firmware version")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.rawDev_firmwareVersion) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devrawGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Is a sonar")
                    value: pulseRuntimeSettings ? list.yesNo(pulseRuntimeSettings.rawDev_isSonar) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devrawGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Supports chart")
                    value: pulseRuntimeSettings ? list.yesNo(pulseRuntimeSettings.rawDev_isChartSupport) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devrawGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Is a transducer")
                    value: pulseRuntimeSettings ? list.yesNo(pulseRuntimeSettings.rawDev_isTransducerSupport) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devrawGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Supports distance")
                    value: pulseRuntimeSettings ? list.yesNo(pulseRuntimeSettings.rawDev_isDistSupport) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devrawGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Supports dataset")
                    value: pulseRuntimeSettings ? list.yesNo(pulseRuntimeSettings.rawDev_isDatasetSupport) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devrawGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Supports sound speed")
                    value: pulseRuntimeSettings ? list.yesNo(pulseRuntimeSettings.rawDev_isSoundSpeedSupport) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devrawGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Can be upgraded")
                    value: pulseRuntimeSettings ? list.yesNo(pulseRuntimeSettings.rawDev_isUpgradeSupport) : "\u2014"
                }
            ]
        }

        // ---- Device parameters ------------------------------------------------
        //
        // WHAT THE DEVICE REPORTS IT IS SET TO - the _Copy read-backs, written by DeviceItem
        // when the device answers. This is the other half of the Transducer group above:
        // that one says what the app asked for, this one says what came back.
        //
        // THE LABELS MATCH THE TRANSDUCER GROUP'S, deliberately, for exactly that reason.
        // Classic calls the same value "Chart: Samples" here and "Samples" there, and a
        // reader comparing the two has to do the translation themselves.
        //
        // -1 READS AS AN EM DASH, not as -1. It means the device has not reported yet,
        // which is a different statement from a parameter whose value is minus one.
        PulseSettingsGroup {
            id: devparamGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly

            uiScale: list.uiScale
            title: qsTr("Device parameters")
            open: list.openId === "devparam"
            onToggled: list.toggle("devparam")

            content: [
                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Samples")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.chartSamples_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Sample spacing")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.chartResolution_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Chart offset")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.chartOffset_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Transducer pulse")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.transPulse_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Frequency")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.transFreq_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Transmit boost")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.transBoost_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Ping period")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.ch1Period_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Bottom confidence")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.distConfidence_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Maximum depth")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.distMax_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Dead zone")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.distDeadZone_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Horizontal smoothing")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.dspHorSmooth_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Sound speed")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.soundSpeed_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Chart in the dataset")
                    value: pulseRuntimeSettings ? list.onOff(pulseRuntimeSettings.datasetChart_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Distance in the dataset")
                    value: pulseRuntimeSettings ? list.onOff(pulseRuntimeSettings.datasetDist_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Distance NMEA in the dataset")
                    value: pulseRuntimeSettings ? list.onOff(pulseRuntimeSettings.datasetSDDBT_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Euler in the dataset")
                    value: pulseRuntimeSettings ? list.onOff(pulseRuntimeSettings.datasetEuler_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Temperature in the dataset")
                    value: pulseRuntimeSettings ? list.onOff(pulseRuntimeSettings.datasetTemp_Copy) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devparamGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Time stamp in the dataset")
                    value: pulseRuntimeSettings ? list.onOff(pulseRuntimeSettings.datasetTimestamp_Copy) : "\u2014"
                }
            ]
        }

        // ---- Device and app config --------------------------------------------
        //
        // THE LINKS AND THE PROFILE'S OWN NUMBERS. The four UUID rows are what the app
        // managed to open; the cone frequencies and the maximum depth are what the
        // committed profile says.
        //
        // "Uses temperature" IS NO LONGER GATED ON ITSELF. Classic shows that row only when
        // useTemperature is true, so it can never read anything but true and answers a
        // question nobody can ask. The correction row below it stays gated, because a
        // correction with no temperature to correct is meaningless rather than merely
        // uninformative.
        PulseSettingsGroup {
            id: devconfigGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly

            uiScale: list.uiScale
            title: qsTr("Device and app config")
            open: list.openId === "devconfig"
            onToggled: list.toggle("devconfig")

            content: [
                PulseReadOnlyRow {
                    width: devconfigGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("UUID opened")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.uuidSuccessfullyOpened) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devconfigGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("UUID serial")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.uuidUsbSerial) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devconfigGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("UUID wifi")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.uuidIpGateway) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devconfigGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("UUID proxy")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.uuidProxyLink) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devconfigGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Is a 2D device")
                    value: pulseRuntimeSettings ? list.yesNo(pulseRuntimeSettings.is2DTransducer) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devconfigGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Uses temperature")
                    value: pulseRuntimeSettings ? list.yesNo(pulseRuntimeSettings.useTemperature) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devconfigGroup.contentWidth
                    height: visible ? implicitHeight : 0
                    visible: pulseRuntimeSettings ? pulseRuntimeSettings.useTemperature : false
                    uiScale: list.uiScale

                    label: qsTr("Temperature correction")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.temperatureCorrection) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devconfigGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Cone: wide")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.transFreqWide) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devconfigGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Cone: medium")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.transFreqMedium) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devconfigGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Cone: narrow")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.transFreqNarrow) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: devconfigGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Maximum depth the app asks for")
                    value: pulseRuntimeSettings ? list.orDash(pulseRuntimeSettings.maximumDepth) : "\u2014"
                }
            ]
        }

        // ---- Debug information ------------------------------------------------
        //
        // THE SIX CONFIGURATION HANDSHAKES, each OK or not. These are the flags the setup
        // overlay counts, so a device stuck part-way through configuration says which stage
        // it is stuck at here.
        //
        // "Not verified" rather than classic's "Not verified (struggle?)": the parenthesis
        // was a note to its author about what it might mean, and a row that asks the reader
        // a question is not a reading.
        PulseSettingsGroup {
            id: debugGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly

            uiScale: list.uiScale
            title: qsTr("Debug information")
            open: list.openId === "debug"
            onToggled: list.toggle("debug")

            content: [
                PulseReadOnlyRow {
                    width: debugGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Distance config")
                    value: pulseRuntimeSettings ? list.okOrNot(pulseRuntimeSettings.onDistSetupChanged) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: debugGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Transducer echogram config")
                    value: pulseRuntimeSettings ? list.okOrNot(pulseRuntimeSettings.onChartSetupChanged) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: debugGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Dataset config")
                    value: pulseRuntimeSettings ? list.okOrNot(pulseRuntimeSettings.onDatasetChanged) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: debugGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Transducer config")
                    value: pulseRuntimeSettings ? list.okOrNot(pulseRuntimeSettings.onTransChanged) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: debugGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Sound speed config")
                    value: pulseRuntimeSettings ? list.okOrNot(pulseRuntimeSettings.onSoundChanged) : "\u2014"
                },

                PulseReadOnlyRow {
                    width: debugGroup.contentWidth
                    uiScale: list.uiScale

                    label: qsTr("Echogram enabled")
                    value: pulseRuntimeSettings ? list.okOrNot(pulseRuntimeSettings.datasetChart_ok) : "\u2014"
                }
            ]
        }
    }

}
