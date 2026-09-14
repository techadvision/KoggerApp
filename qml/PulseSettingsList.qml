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
    readonly property bool expertOnly:       pulseRuntimeSettings ? pulseRuntimeSettings.expertMode : false
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
                }
            ]
        }

        Repeater { model: [ { id: "nmea", title: qsTr("NMEA output") } ]
                   delegate: stubCategory }

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

        Repeater { model: [ { id: "recording",       title: qsTr("Recording")       },
                            { id: "troubleshooting", title: qsTr("Troubleshooting") } ]
                   delegate: stubCategory }
    }

    // A HEADER WITH AN HONEST PLACEHOLDER, for the categories not yet filled. They are in
    // the list rather than added one at a time so it can be judged as a list on the device -
    // how far it runs, how the indent reads against closed neighbours. Each entry leaves
    // with the commit that fills its category, and this whole component goes with the last.
    //
    // Declared outside the Column: a Component is not an Item, so it would be ignored
    // there anyway, but a reader should not have to know that to see it takes no space.
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
