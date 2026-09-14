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
    readonly property bool offersTemp:       pulseRuntimeSettings ? pulseRuntimeSettings.useTemperature : false

    readonly property bool screenHasRows: offersSpeed || offersSecondEcho || offersTemp

    Column {
        id: column
        width: parent.width
        spacing: 0

        // ---- Screen & echogram ----------------------------------------------

        PulseSettingsGroup {
            id: screenGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: list.screenHasRows

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

        // ---- The six still to be built ---------------------------------------
        //
        // Headers now, contents per commit. They are here rather than added one at a time
        // so the LIST can be judged on the device as a list - how far down it runs, how the
        // indent reads against six closed neighbours - which is the thing this commit is
        // asking about. Each placeholder leaves with the commit that fills its category.

        Repeater {
            model: [
                { id: "installation",    title: qsTr("Installation")    },
                { id: "position",        title: qsTr("Position source") },
                { id: "nmea",            title: qsTr("NMEA output")     },
                { id: "connection",      title: qsTr("Connection")      },
                { id: "recording",       title: qsTr("Recording")       },
                { id: "troubleshooting", title: qsTr("Troubleshooting") }
            ]

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
}
