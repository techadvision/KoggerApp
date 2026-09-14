import QtQuick 2.15

// A READ-ONLY ROW (Stage 4 b) - row type five of seven. A value the app knows and the user
// does not set.
//
// DIM VALUE, NO BORDER, NO TARGET, which is the canvas's whole specification for it and is
// the point: it must not look like the rows above and below it that DO respond, or the
// first thing a user learns about it is that tapping it does nothing.
//
// AND IT BINDS TO THE KEY RATHER THAN PRINTING A CONSTANT. Classic's "NMEA send to IP" row
// draws the literal string "255.255.255.255" while NMEASender reads
// pulseSettings.nmeaBroadcastAddress - which main.qml:143 overwrites from the runtime key.
// The label is right until the day it is not, and on that day it is a row that confidently
// states the wrong address.
Item {
    id: readOnlyRow

    property real uiScale: 1.0

    property string label: ""
    property string hint:  ""
    property string value: ""

    // AS TALL AS ITS CONTENT - see PulseStepperRow.
    implicitHeight: (hintText.visible ? hintText.y + hintText.height
                                      : labelText.y + labelText.height)
                    + Math.round(14 * uiScale)
    height: implicitHeight

    Text {
        id: labelText

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: Math.round(14 * readOnlyRow.uiScale)

        text: readOnlyRow.label
        color: "#eaf1f8"
        font.pixelSize: Math.round(16 * readOnlyRow.uiScale)
    }

    Text {
        anchors.right: parent.right
        anchors.left: labelText.right
        anchors.leftMargin: Math.round(12 * readOnlyRow.uiScale)
        anchors.baseline: labelText.baseline

        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
        text: readOnlyRow.value
        color: "#8a929c"
        font.pixelSize: Math.round(16 * readOnlyRow.uiScale)
    }

    Text {
        id: hintText

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: labelText.bottom
        anchors.topMargin: Math.round(2 * readOnlyRow.uiScale)

        visible: readOnlyRow.hint !== ""
        text: readOnlyRow.hint
        color: "#8a929c"
        font.pixelSize: Math.round(13 * readOnlyRow.uiScale)
        wrapMode: Text.WordWrap
    }
}
