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
    // is on, the filter is not at zero. PENDING means "its panel is open".
    property bool   active:  false

    // PENDING IS DERIVED, NOT SET AT THE CALL SITE, and that is the whole of the fix for
    // "the rail says nothing about what is open". It was one line per button before, and
    // exactly one of eleven buttons carried it: Colours lit up and Cone, Max range,
    // Intensity, Water body filter and Settings did not. A line that has to be remembered
    // once per button is a line that will be forgotten, and the next button added would
    // have been the twelfth to forget it.
    //
    // THE OPEN GROUP ARRIVES THROUGH THE PARENT because QML ids do not cross files - this
    // component cannot see PulseRail's `rail`. The rail declares `openGroup` on the
    // ColumnLayout these buttons are children of, in ONE place, and every button defaults
    // from it. So a new button needs no line at all: give it a buttonId and it lights up.
    //
    // Still a settable property rather than a readonly binding, so a button that is ever
    // nested inside something other than the column can be handed the value directly. The
    // undefined test is what makes that safe: a parent with no such property answers "",
    // which matches no buttonId, rather than throwing on every evaluation.
    property string openGroup: (parent && parent.openGroup !== undefined) ? parent.openGroup : ""

    // The empty test is not belt and braces. `collapse` and `backToClassic` carry buttonIds
    // and open no group, and "" is also what openGroup reads when the panel is closed - so
    // without it every button on a closed panel would light up at once.
    readonly property bool pending: buttonId !== "" && buttonId === openGroup

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
