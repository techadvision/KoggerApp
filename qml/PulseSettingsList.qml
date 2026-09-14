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

    // ---- What this device offers --------------------------------------------

    readonly property var offers: pulseRuntimeSettings ? pulseRuntimeSettings.uiOffers : ({})

    readonly property bool offersSpeed:      offers && offers.screenSpeed2D === true
    readonly property bool offersSecondEcho: offers && offers.doubleEchoOptimize === true
    readonly property bool offersWidth:      offers && offers.scanWidthMeters === true
    readonly property bool offersTemp:       pulseRuntimeSettings ? pulseRuntimeSettings.useTemperature : false

    readonly property bool offersMounting:   offers && offers.sideScanMounting === true
    readonly property bool offersMtw:        offers && offers.nmeaMtw === true

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

            // THE SPEED IS CARRIED AS TENTHS. The slider row is integer by design - a
            // stepped control with a named step is easier to hit than a continuous one -
            // and the echogram speed is 1.0 to 5.0 in tenths. Ten to fifty here, divided
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
                maxValue: 50
                stepSize: 1
                value: Math.round((pulseSettings ? pulseSettings.echogramSpeed : 1) * 10)
                valueText: ((pulseSettings ? pulseSettings.echogramSpeed : 1)).toFixed(1) + "\u00D7"

                onMoved: function (v) {
                    list.settingChanged("persistent", "echogramSpeed", Math.round(v) / 10)
                }
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

                PulseSwitchRow {
                    width: installationGroup.contentWidth
                    height: visible ? implicitHeight : 0
                    visible: list.offersMounting
                    uiScale: list.uiScale

                    label: qsTr("Mounted on the left-hand side")
                    hint:  qsTr("which hull the side scan looks past")
                    checked: pulseSettings ? pulseSettings.isSideScanOnLeftHandSide : false

                    onToggled: function (v) {
                        list.settingChanged("persistent", "isSideScanOnLeftHandSide", v)
                    }
                },

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
                // the screen - which is why PulseAppV2 carries its own way back on the
                // rail, scaffolding that was always meant to leave when the settings panel
                // existed. It now exists. The rail's button stays one more build, until
                // this row is confirmed on the device: retiring the only escape hatch on
                // the strength of an untested one is how a tester gets stranded.
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

        // The seven remaining manipulation groups. USB baud rate is NOT among them: it
        // lives in Connection now, and tier 3 arriving with its own copy is exactly the
        // duplicated ability this tier is being cleaned of.
        Repeater { model: [ { id: "waterbody",   title: qsTr("Water body filter")  },
                            { id: "tvg2d",       title: qsTr("TVG 2D")             },
                            { id: "tvgside",     title: qsTr("TVG side scan")      },
                            { id: "bottomtrack", title: qsTr("Bottom track")       },
                            { id: "depthfilter", title: qsTr("Depth filter")       },
                            { id: "stripes",     title: qsTr("Black stripes")      },
                            { id: "fakedepth",   title: qsTr("Depth manipulation") } ]
                   delegate: expertStubCategory }

        PulseSettingsSection {
            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly
            uiScale: list.uiScale
            title: qsTr("Expert info")
        }

        // FOUR GROUPS, FORTY-EIGHT ROWS, EVERY ONE OF THEM A READ. That is not an
        // assessment of where they belong - it is what PulseInfoExpert.qml already
        // contains: every row in these four is a Text with no control beside it. They take
        // the read-only row and nothing else.
        Repeater { model: [ { id: "devraw",    title: qsTr("Device raw information")    },
                            { id: "devparam",  title: qsTr("Device parameters")         },
                            { id: "devconfig", title: qsTr("Device and app config")     },
                            { id: "debug",     title: qsTr("Debug information")         } ]
                   delegate: expertStubCategory }
    }

    // A HEADER WITH AN HONEST PLACEHOLDER, for the categories not yet filled. They are in
    // the list rather than added one at a time so it can be judged as a list on the device -
    // how far it runs, how the indent reads against closed neighbours. Each entry leaves
    // with the commit that fills its category, and this whole component goes with the last.
    //
    // Declared outside the Column: a Component is not an Item, so it would be ignored
    // there anyway, but a reader should not have to know that to see it takes no space.
    // The same placeholder, gated on the expert switch. A separate component rather than a
    // `visible` argument threaded through the model, because the two runs differ in exactly
    // that one binding and a model entry carrying a visibility flag is a model entry that
    // will be copied without it.
    Component {
        id: expertStubCategory

        PulseSettingsGroup {
            id: expertStubGroup

            width: column.width
            height: visible ? implicitHeight : 0
            visible: list.expertOnly

            uiScale: list.uiScale
            title: modelData.title
            open: list.openId === modelData.id
            onToggled: list.toggle(modelData.id)

            content: [
                Text {
                    width: expertStubGroup.contentWidth
                    topPadding: Math.round(12 * list.uiScale)
                    bottomPadding: Math.round(12 * list.uiScale)
                    text: qsTr("Not built yet.")
                    color: "#6d7784"
                    font.pixelSize: Math.round(15 * list.uiScale)
                    font.italic: true
                }
            ]
        }
    }

    Component {
        id: stubCategory

        PulseSettingsGroup {
            id: stubGroup

            width: column.width
            uiScale: list.uiScale
            title: modelData.title
            open: list.openId === modelData.id
            onToggled: list.toggle(modelData.id)

            content: [
                Text {
                    width: stubGroup.contentWidth
                    topPadding: Math.round(12 * list.uiScale)
                    bottomPadding: Math.round(12 * list.uiScale)
                    text: qsTr("Not built yet.")
                    color: "#6d7784"
                    font.pixelSize: Math.round(15 * list.uiScale)
                    font.italic: true
                }
            ]
        }
    }
}
