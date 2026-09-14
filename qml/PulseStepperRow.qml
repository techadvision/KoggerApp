import QtQuick 2.15

// A STEPPER ROW (Stage 4 b) - row type four of seven, for a value that is set once and
// wants precision rather than a sweep.
//
// WHY NOT A SLIDER. The transducer's depth below the surface is 0 to 10 m in centimetres.
// On a 300 px track that is three centimetres per pixel, so the slider cannot express the
// precision the value is stored at - and this is a number somebody measures with a tape
// once and then leaves alone. A stepper says the step out loud and always lands on it.
//
// AND PRESS-AND-HOLD, or it would be a hundred taps to cross a metre. The rail's max-range
// control already holds to run, so this is the gesture the app has rather than a new one.
// It accelerates after two seconds because the far end of the range is where the tap count
// hurts, and the same hold that gives you 0.01 m has to be able to cross 10 m.
//
// THE ALLOWED RANGE IS ALWAYS ON SCREEN, under the label - the canvas rule the slider row
// follows too. Several of today's bounds survive only as a magic number inside a label,
// "Dist confidence adjust (14)", and a limit discovered by hitting it is a limit nobody
// knew about.
//
// IT REPORTS, IT DOES NOT STORE. `value` is the host's binding; the row emits `stepped` and
// the value comes back round through the binding. If the host declines a write the stepper
// simply stops, which is the correct behaviour at a bound and needs no second guard here.
Item {
    id: stepperRow

    property real uiScale: 1.0

    property string label: ""
    property string hint:  ""
    property string unit:  ""

    property real minValue: 0
    property real maxValue: 10
    property real stepSize: 0.01
    property int  decimals: 2

    // A LADDER THAT IS NOT EVENLY SPACED. Most of the expert values are lists like
    // [0, 0.1, 0.15, 0.2, 0.25, 0.4, 0.5, 0.75, 1.0] - ordered, but with no single step
    // between them, so min/max/step cannot describe them. Set `values` and the stepper
    // walks the list by index instead; leave it empty and it walks the arithmetic ladder.
    //
    // A STEPPER RATHER THAN A LONG LIST OF SEGMENTS, which is what the canvas's "a list in
    // the same panel" would have been. Fourteen segments do not fit a 360 px panel at all,
    // and a scrolling list inside a scrolling panel is two scrolls fighting over one
    // finger. The value is ordered, so stepping it is the natural gesture - and press-and-
    // hold already crosses a long one.
    property var  values: []

    readonly property bool listMode: values && values.length > 0

    property real value: 0

    signal stepped(real v)

    // NEAREST, NOT indexOf. A stored value can come from somewhere other than this list -
    // a profile default, an older build's list, a device report - and indexOf would answer
    // -1 and strand the control at one end. Nearest always has an answer and is right
    // whenever exact would have been.
    function _nearestIndex() {
        var best = 0
        var bestDelta = Infinity
        for (var i = 0; i < values.length; ++i) {
            var d = Math.abs(Number(values[i]) - value)
            if (d < bestDelta) { bestDelta = d; best = i }
        }
        return best
    }

    // AS TALL AS ITS CONTENT, MEASURED RATHER THAN ASSUMED. The first version added up a
    // one-line label, a one-line hint and the control - and every hint long enough to wrap
    // then overflowed the row and was overlapped by the next one. Three groups showed it on
    // the device at once, which is what a guessed height does: it is right until the words
    // change.
    //
    // No loop here: the control's y comes from an anchor chain that starts at parent.top,
    // and nothing inside reads the row's height.
    implicitHeight: control.y + control.height + Math.round(14 * uiScale)
    height: implicitHeight

    readonly property string valueText:
        value.toFixed(decimals) + (unit === "" ? "" : " " + unit)

    readonly property real _floor: listMode ? Number(values[0])                 : minValue
    readonly property real _ceil:  listMode ? Number(values[values.length - 1]) : maxValue

    // ---- The one place a step is worked out ---------------------------------

    property int  _dir:    0
    property int  _ticks:  0

    function _step(multiplier) {
        if (_dir === 0)
            return

        if (listMode) {
            var at = _nearestIndex()
            var to = Math.max(0, Math.min(values.length - 1, at + _dir * multiplier))
            var next = Number(values[to])
            if (next !== value)
                stepperRow.stepped(next)
            return
        }

        var by = stepSize * multiplier * _dir
        var raw = value + by
        // Snap to the step grid rather than accumulating: repeated float addition of 0.01
        // drifts, and a value that reads 0.30000000000000004 is a value somebody will
        // report as a fault.
        var snapped = Math.round(raw / stepSize) * stepSize
        var clamped = Math.max(minValue, Math.min(maxValue, snapped))
        var rounded = parseFloat(clamped.toFixed(decimals))
        if (rounded !== value)
            stepperRow.stepped(rounded)
    }

    Timer {
        id: repeatTimer
        interval: 450
        repeat: true
        onTriggered: {
            // First fire is the hold threshold; from then on it runs, and after roughly
            // two seconds of holding it takes ten steps at a time.
            interval = 80
            stepperRow._ticks += 1
            stepperRow._step(stepperRow._ticks > 25 ? 10 : 1)
        }
    }

    function _press(dir) {
        _dir = dir
        _ticks = 0
        repeatTimer.interval = 450
        _step(1)
        repeatTimer.restart()
    }

    function _release() {
        repeatTimer.stop()
        _dir = 0
        _ticks = 0
    }

    // ---- Label, range, and the control ---------------------------------------

    Text {
        id: labelText

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.round(14 * stepperRow.uiScale)

        text: stepperRow.label
        color: "#eaf1f8"
        font.pixelSize: Math.round(16 * stepperRow.uiScale)
        wrapMode: Text.WordWrap
    }

    Text {
        id: hintText

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: labelText.bottom
        anchors.topMargin: Math.round(2 * stepperRow.uiScale)

        visible: stepperRow.hint !== ""
        text: stepperRow.hint
        color: "#8a929c"
        font.pixelSize: Math.round(13 * stepperRow.uiScale)
        wrapMode: Text.WordWrap
    }

    Item {
        id: control

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: hintText.visible ? hintText.bottom : labelText.bottom
        anchors.topMargin: Math.round(10 * stepperRow.uiScale)
        height: Math.round(44 * stepperRow.uiScale)

        Rectangle {
            id: minus

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width:  Math.round(64 * stepperRow.uiScale)
            height: Math.round(44 * stepperRow.uiScale)
            radius: Math.round(8 * stepperRow.uiScale)

            readonly property bool atBound: stepperRow.value <= stepperRow._floor

            color: minusTouch.pressed ? "#1f4a6b" : "transparent"
            border.width: 1
            border.color: atBound ? "#222b35" : "#2a3644"

            Rectangle {
                anchors.centerIn: parent
                width:  Math.round(18 * stepperRow.uiScale)
                height: Math.max(2, Math.round(2 * stepperRow.uiScale))
                radius: height / 2
                color: minus.atBound ? "#4b535c" : "#cfe0f2"
            }

            MouseArea {
                id: minusTouch
                anchors.fill: parent
                onPressed:  stepperRow._press(-1)
                onReleased: stepperRow._release()
                onCanceled: stepperRow._release()
            }
        }

        Text {
            anchors.centerIn: parent
            text: stepperRow.valueText
            color: "#8ad3ff"
            font.pixelSize: Math.round(19 * stepperRow.uiScale)
            font.bold: true
        }

        Rectangle {
            id: plus

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width:  Math.round(64 * stepperRow.uiScale)
            height: Math.round(44 * stepperRow.uiScale)
            radius: Math.round(8 * stepperRow.uiScale)

            readonly property bool atBound: stepperRow.value >= stepperRow._ceil

            color: plusTouch.pressed ? "#1f4a6b" : "transparent"
            border.width: 1
            border.color: atBound ? "#222b35" : "#2a3644"

            Rectangle {
                anchors.centerIn: parent
                width:  Math.round(18 * stepperRow.uiScale)
                height: Math.max(2, Math.round(2 * stepperRow.uiScale))
                radius: height / 2
                color: plus.atBound ? "#4b535c" : "#cfe0f2"
            }

            Rectangle {
                anchors.centerIn: parent
                width:  Math.max(2, Math.round(2 * stepperRow.uiScale))
                height: Math.round(18 * stepperRow.uiScale)
                radius: width / 2
                color: plus.atBound ? "#4b535c" : "#cfe0f2"
            }

            MouseArea {
                id: plusTouch
                anchors.fill: parent
                onPressed:  stepperRow._press(1)
                onReleased: stepperRow._release()
                onCanceled: stepperRow._release()
            }
        }
    }
}
