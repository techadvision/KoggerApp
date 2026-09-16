import QtQuick 2.15

// A SLIDER ROW (Stage 4 b) - the first of the canvas's seven row types, and the one two
// tier-1 controls need: intensity and the water body filter.
//
// THE ALLOWED RANGE IS ALWAYS ON SCREEN, under the label. That is a rule from the canvas and
// not decoration: several of today's bounds survive only as a magic number inside a label -
// "Dist confidence adjust (14)" - and a limit discovered by hitting it is a limit nobody
// knew about.
//
// UNITS SIT WITH THE VALUE, not with the label. "Intensity" and "12", not "Intensity (0-20)".
// The label says what it is, the value says how much.
//
// IT REPORTS, IT DOES NOT STORE. `value` is a binding the host supplies and `moved` is what
// this row emits; nothing here writes a setting. Same division as the colour group, and for
// the same reason - a control that owns its own copy of a value is a control that can
// disagree with the picture.
Item {
    id: sliderRow

    property real uiScale: 1.0

    property string label:     ""
    property string valueText: ""
    property string hint:      ""

    property int minValue: 0
    property int maxValue: 20
    property int stepSize:  1

    property int value: 0

    signal moved(int v)

    // AS TALL AS ITS CONTENT, MEASURED RATHER THAN ASSUMED. This one pinned the track to
    // parent.BOTTOM inside a fixed 104 du, so a hint long enough to wrap ran into the track
    // instead of pushing it down. The track now hangs under the range line and the row's
    // height follows it - the same rule every other row type now uses.
    implicitHeight: trackArea.y + trackArea.height + Math.round(10 * uiScale)
    height: implicitHeight

    readonly property int span: Math.max(1, maxValue - minValue)

    // FINE NUDGES, OPTIONAL, and the reason they exist is arithmetic rather than taste.
    // Olav: the +/- stepper is "a bit slow", and on a parameter like the sample count -
    // 100 to 15000 - it is unusable: a hundred and fifty taps to cross the range. But the
    // slider has the opposite failure at that width. A 360 du track over 14900 units is
    // about forty units per pixel, so a parameter whose step is 1 cannot be landed on
    // exactly by dragging at all.
    //
    // So the two are not alternatives. The DRAG chooses the neighbourhood and the NUDGE
    // lands the value, and a row that needs only one of them asks for only one. Off by
    // default, so every slider built before this is untouched.
    property bool showNudges: false

    readonly property int nudgeSize: Math.round(34 * uiScale)

    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.max(labelText.implicitHeight,
                         sliderRow.showNudges ? sliderRow.nudgeSize : 0)

        Text {
            id: labelText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: sliderRow.label
            color: "#eaf1f8"
            font.pixelSize: Math.round(17 * sliderRow.uiScale)
        }

        // A NUDGE IS AT A BOUND, NOT DISABLED. The same rule the stepper row follows: the
        // button stays where it is and stops answering, so the control does not move under
        // a thumb that is already on it.
        Component {
            id: nudgeButton

            Rectangle {
                property int dir: 1
                property bool atBound: dir < 0 ? sliderRow.value <= sliderRow.minValue
                                               : sliderRow.value >= sliderRow.maxValue

                width:  sliderRow.nudgeSize
                height: sliderRow.nudgeSize
                radius: height / 2
                color: tap.pressed && !atBound ? "#22303c" : "transparent"
                border.width: 1
                border.color: atBound ? "#2a323c" : "#3d7fd0"
                opacity: atBound ? 0.4 : 1.0

                Text {
                    anchors.centerIn: parent
                    text: parent.dir < 0 ? "\u2212" : "+"
                    color: "#cfe0f2"
                    font.pixelSize: Math.round(19 * sliderRow.uiScale)
                    font.bold: true
                }

                MouseArea {
                    id: tap
                    anchors.fill: parent
                    onClicked: {
                        if (parent.atBound)
                            return
                        var v = sliderRow.value + parent.dir * sliderRow.stepSize
                        v = Math.max(sliderRow.minValue, Math.min(sliderRow.maxValue, v))
                        if (v !== sliderRow.value)
                            sliderRow.moved(v)
                    }
                }
            }
        }

        Loader {
            id: plusNudge
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            active: sliderRow.showNudges
            sourceComponent: nudgeButton
            onLoaded: item.dir = 1
        }

        Text {
            id: valueLabel
            anchors.right: sliderRow.showNudges ? plusNudge.left : parent.right
            anchors.rightMargin: sliderRow.showNudges ? Math.round(8 * sliderRow.uiScale) : 0
            anchors.verticalCenter: parent.verticalCenter
            text: sliderRow.valueText
            color: "#8ad3ff"
            font.pixelSize: Math.round(19 * sliderRow.uiScale)
            font.bold: true
        }

        Loader {
            id: minusNudge
            anchors.right: valueLabel.left
            anchors.rightMargin: Math.round(8 * sliderRow.uiScale)
            anchors.verticalCenter: parent.verticalCenter
            active: sliderRow.showNudges
            sourceComponent: nudgeButton
            onLoaded: item.dir = -1
        }
    }

    Text {
        id: rangeText
        anchors.left: parent.left
        anchors.top: header.bottom
        anchors.topMargin: Math.round(2 * sliderRow.uiScale)
        text: sliderRow.hint !== "" ? sliderRow.hint
                                    : sliderRow.minValue + " – " + sliderRow.maxValue
        color: "#8a929c"
        font.pixelSize: Math.round(13 * sliderRow.uiScale)
    }

    // The track is deliberately tall and the knob large: this is operated from shore, often
    // one-handed, sometimes with wet hands. Every serious unit in the market scan assumes
    // touch will fail and keeps a hardware fallback; on an app the equivalent is a target
    // big enough to hit without looking.
    Item {
        id: trackArea

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: rangeText.bottom
        anchors.topMargin: Math.round(6 * sliderRow.uiScale)
        height: Math.round(44 * sliderRow.uiScale)

        readonly property real usable: Math.max(1, width - knob.width)
        readonly property real knobX:
            (sliderRow.value - sliderRow.minValue) / sliderRow.span * usable

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Math.round(6 * sliderRow.uiScale)
            radius: height / 2
            color: "#22303c"
        }

        Rectangle {
            anchors.left: track.left
            anchors.verticalCenter: track.verticalCenter
            width: Math.max(0, trackArea.knobX + knob.width / 2)
            height: track.height
            radius: track.radius
            color: "#3d7fd0"
        }

        Rectangle {
            id: knob
            x: trackArea.knobX
            anchors.verticalCenter: parent.verticalCenter
            width:  Math.round(30 * sliderRow.uiScale)
            height: width
            radius: width / 2
            color: drag.pressed ? "#8ad3ff" : "#cfe0f2"
            border.width: 1
            border.color: "#0b0d11"
        }

        MouseArea {
            id: drag
            anchors.fill: parent

            function valueAt(mx) {
                var t = (mx - knob.width / 2) / trackArea.usable
                t = Math.max(0, Math.min(1, t))
                var raw = sliderRow.minValue + t * sliderRow.span
                var stepped = Math.round(raw / sliderRow.stepSize) * sliderRow.stepSize
                return Math.max(sliderRow.minValue, Math.min(sliderRow.maxValue, stepped))
            }

            // EVERY MOVE ACTS. No Apply button anywhere in this panel - the whole point of
            // tuning from shore is watching the picture answer while your thumb is still on
            // the control. The host drops duplicates, so dragging across one step does not
            // write the same value forty times.
            onPressed:         sliderRow.moved(valueAt(mouse.x))
            onPositionChanged: if (pressed) sliderRow.moved(valueAt(mouse.x))
        }
    }
}
