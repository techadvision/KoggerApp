import QtQuick 2.15

// A CHOICE ROW (Stage 4 b) - the third of the canvas's seven row types, drawn segmented.
//
// SEGMENTED WHILE THE CHOICES ARE FEW. The canvas's rule is segmented up to four values and
// a list in the same panel beyond that; every choice in tier 2 is two or three, so the list
// half is not written until something needs it. Writing it now would be guessing at a shape
// no caller has asked for.
//
// THE OPTIONS NAME THEIR OWN VALUE. `{ value, title }`, and the value is whatever the key
// holds - a bool for metric depth, a number for the scan width. The row never maps an INDEX
// onto a meaning, which is the mistake the positional ecoViewIndex/ecoConeIndex preferences
// made: a stored 1 that means something different after the list changes is a defect that
// only shows up on somebody else's device.
//
// IT REPORTS, IT DOES NOT STORE. `current` is a binding the host supplies and `chosen` is
// what this row emits. Same division as the slider and switch rows.
Item {
    id: segmentRow

    property real uiScale: 1.0

    property string label: ""
    property string hint:  ""

    // [{ value: <any>, title: "..." }, ...]
    property var options: []

    property var current: undefined

    signal chosen(var value)

    readonly property real segmentHeight: Math.round(40 * uiScale)

    // AS TALL AS ITS CONTENT - see PulseStepperRow.
    implicitHeight: segments.y + segments.height + Math.round(14 * uiScale)
    height: implicitHeight

    Text {
        id: labelText

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.round(14 * segmentRow.uiScale)

        text: segmentRow.label
        color: "#eaf1f8"
        font.pixelSize: Math.round(16 * segmentRow.uiScale)
        wrapMode: Text.WordWrap
    }

    Text {
        id: hintText

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: labelText.bottom
        anchors.topMargin: Math.round(2 * segmentRow.uiScale)

        visible: segmentRow.hint !== ""
        text: segmentRow.hint
        color: "#8a929c"
        font.pixelSize: Math.round(13 * segmentRow.uiScale)
        wrapMode: Text.WordWrap
    }

    Row {
        id: segments

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: hintText.visible ? hintText.bottom : labelText.bottom
        anchors.topMargin: Math.round(10 * segmentRow.uiScale)

        spacing: Math.round(6 * segmentRow.uiScale)

        // A positioner, not a Layout, so a plain width on a child is correct here. The
        // width is shared evenly and the remainder goes nowhere visible.
        readonly property int count: segmentRow.options ? segmentRow.options.length : 0
        readonly property real cellWidth:
            count > 0 ? (width - spacing * (count - 1)) / count : 0

        Repeater {
            model: segmentRow.options

            Rectangle {
                width:  segments.cellWidth
                height: segmentRow.segmentHeight
                radius: Math.round(8 * segmentRow.uiScale)

                readonly property bool selected: modelData.value === segmentRow.current

                color: selected ? "#1f4a6b"
                                : (cellTouch.pressed ? "#1c2530" : "transparent")
                border.width: 1
                border.color: selected ? "#3d7fd0" : "#2a3644"

                Text {
                    anchors.centerIn: parent
                    width: parent.width - Math.round(10 * segmentRow.uiScale)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: modelData.title
                    color: parent.selected ? "#eaf1f8" : "#b9c4d0"
                    font.pixelSize: Math.round(15 * segmentRow.uiScale)
                    font.bold: parent.selected
                }

                MouseArea {
                    id: cellTouch
                    anchors.fill: parent
                    onClicked: segmentRow.chosen(modelData.value)
                }
            }
        }
    }
}
