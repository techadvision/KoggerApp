import QtQuick 2.15

// A SECTION TITLE in the settings list (Stage 4 b, tier 3).
//
// WHY A THIRD LEVEL OF STRUCTURE WITH NO THIRD LEVEL OF NESTING. Tier 3 adds twelve
// categories to the five tier 2 has, and Olav's read of that: "the volume of headers become
// more manageable" if they are grouped under a title. So this is a LABEL, not a container -
// it does not open, it does not indent what follows it, and nothing hangs off it. It only
// says which kind of thing the next run of categories is.
//
// TWO KINDS, and the code says so plainly rather than the title merely claiming it: every
// row under "Expert settings" is a control, and every row under "Expert info" - all
// forty-eight of them across four categories - is a Text. That is not a judgement call about
// where a group feels like it belongs; it is what the groups already are.
//
// DIMMER THAN A CATEGORY, deliberately. A category name is a thing you tap; this is not, and
// if it drew with the same weight the eye would keep trying.
Item {
    id: section

    property real uiScale: 1.0
    property string title: ""

    implicitHeight: Math.round(52 * uiScale)
    height: implicitHeight

    Text {
        id: label

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(10 * section.uiScale)

        text: section.title
        color: "#6d7784"
        font.pixelSize: Math.round(12 * section.uiScale)
        font.bold: true
        font.letterSpacing: Math.round(1.4 * section.uiScale)
        font.capitalization: Font.AllUppercase
    }

    Rectangle {
        anchors.left: label.right
        anchors.leftMargin: Math.round(12 * section.uiScale)
        anchors.right: parent.right
        anchors.verticalCenter: label.verticalCenter
        height: 1
        color: "#20ffffff"
    }
}
