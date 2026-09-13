import QtQuick 2.15
import QtQuick.Layouts 1.15

// ONE BUTTON ON THE EDGE RAIL (Stage 4 a).
//
// Icon only, by choice. Every serious sounder in the market scan is icon-driven on its
// permanent controls, and at 76 design units of rail there is no width for a caption a
// wet thumb could read anyway. `label` is carried for the log line and for the caption
// tier 2 may want later - it is never drawn here.
//
// THE LAYOUT RULE, written here because this is the control every later one is copied
// from: a direct child of a Layout must NEVER carry a plain width or height. The Layout
// overwrites both with the implicit size, and the control silently ends up a size nobody
// wrote. Layout.preferredWidth / Layout.preferredHeight are the only correct spelling.
// (A Column or Row positioner is NOT a Layout - a plain width is fine there.)
Item {
    id: railButton

    property real   uiScale:    1.0
    property string buttonId:   ""
    property string iconSource: ""
    property string label:      ""

    // ACTIVE means "this control is doing something to the picture right now" - recording
    // is on, the filter is not at zero. PENDING means "its panel is open", and nothing
    // raises it until stage 4 (b) builds the panel.
    property bool   active:  false
    property bool   pending: false

    signal activated()

    Layout.preferredWidth:  Math.round(60 * uiScale)
    Layout.preferredHeight: Math.round(60 * uiScale)
    Layout.alignment: Qt.AlignHCenter

    Rectangle {
        anchors.fill: parent
        radius: Math.round(10 * railButton.uiScale)
        color: touch.pressed      ? "#2a3644"
             : railButton.pending ? "#1d2a36"
             :                      "transparent"
        border.width: railButton.active ? 1 : 0
        border.color: "#3d7fd0"
    }

    Image {
        anchors.centerIn: parent
        width:  Math.round(34 * railButton.uiScale)
        height: width
        source: railButton.iconSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: railButton.enabled ? 1.0 : 0.35
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        enabled: railButton.enabled
        onClicked: railButton.activated()
    }
}
