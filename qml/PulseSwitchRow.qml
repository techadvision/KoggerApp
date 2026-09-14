import QtQuick 2.15

// A SWITCH ROW (Stage 4 b) - the second of the canvas's seven row types, and the one most
// of tier 2 is made of.
//
// IT REPORTS, IT DOES NOT STORE. `checked` is a binding the host supplies and `toggled` is
// what this row emits; nothing here writes a setting and nothing here keeps a copy. That is
// the same division the slider row and the colour group use, and it is the rule that stops
// a control disagreeing with the picture.
//
// AND IT IS WHY THE KNOB IS A BINDING, NOT AN ANIMATION TARGET. The knob's x follows
// `checked` through a Behavior; nothing assigns it. Classic's recording indicator is the
// counter-example still in the tree - `visible: isRecordingKlf` AND a handler assigning the
// same `visible`, so the binding died the first time recording was toggled.
//
// THE WHOLE ROW IS THE TARGET, not the 46 px switch. Wet hands, one thumb, from shore.
Item {
    id: switchRow

    property real uiScale: 1.0

    property string label: ""
    property string hint:  ""

    property bool checked: false

    signal toggled(bool value)

    // AS TALL AS ITS CONTENT - see PulseStepperRow for why a computed height was wrong.
    // Either side can be the tallest: a wrapped label and hint on the left, or the switch
    // on the right when the label is one short word.
    implicitHeight: Math.max(track.y + track.height,
                             hintText.visible ? hintText.y + hintText.height
                                              : labelText.y + labelText.height)
                    + Math.round(14 * uiScale)
    height: implicitHeight

    Text {
        id: labelText

        anchors.left: parent.left
        anchors.right: track.left
        anchors.rightMargin: Math.round(14 * switchRow.uiScale)
        anchors.top: parent.top
        anchors.topMargin: Math.round(14 * switchRow.uiScale)

        text: switchRow.label
        color: "#eaf1f8"
        font.pixelSize: Math.round(16 * switchRow.uiScale)
        wrapMode: Text.WordWrap
    }

    Text {
        id: hintText

        anchors.left: parent.left
        anchors.right: track.left
        anchors.rightMargin: Math.round(14 * switchRow.uiScale)
        anchors.top: labelText.bottom
        anchors.topMargin: Math.round(2 * switchRow.uiScale)

        visible: switchRow.hint !== ""
        text: switchRow.hint
        color: "#8a929c"
        font.pixelSize: Math.round(13 * switchRow.uiScale)
        wrapMode: Text.WordWrap
    }

    Rectangle {
        id: track

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.round(12 * switchRow.uiScale)

        width:  Math.round(46 * switchRow.uiScale)
        height: Math.round(26 * switchRow.uiScale)
        radius: height / 2
        color: switchRow.checked ? "#1f4a6b" : "#2a333d"

        Rectangle {
            id: knob

            y: (parent.height - height) / 2
            x: switchRow.checked ? parent.width - width - Math.round(3 * switchRow.uiScale)
                                 : Math.round(3 * switchRow.uiScale)
            width:  Math.round(20 * switchRow.uiScale)
            height: width
            radius: width / 2
            color: switchRow.checked ? "#8ad3ff" : "#7f8b98"

            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: switchRow.toggled(!switchRow.checked)
    }
}
