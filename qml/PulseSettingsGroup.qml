import QtQuick 2.15

// AN EXPANDABLE CATEGORY in the settings list (Stage 4 b, tier 2).
//
// THE PROBLEM IT SOLVES. The list as first drawn told a category apart from a setting by a
// chevron and nothing else, so a row under a header did not read as belonging to it. Olav,
// on the Android Wi-Fi list in dark mode: a combination of blue and white fonts makes it
// "super readable". He chose COLOUR AND INDENT together as the most intuitive of the three
// treatments put to him, and turned down the third - a brighter card under the open group.
//
// THE COLOUR RULE, which is the part worth stating once: BLUE IS WHAT VARIES, WHITE IS WHAT
// IS FIXED. A closed category is only a label, so it is white. Open it and its name turns
// blue, because it is now the thing you are inside. Every value in the panel is blue for the
// same reason and every static label is white - so the panel gains no new meaning for blue,
// it applies the one it already had.
//
// THE INDENT IS ONE STEP AND ONE ONLY - 6 px of gap, a 2 px rule, then 16 px. There is no
// second level of nesting to distinguish: categories, then rows. A second step would be
// inventing a hierarchy that does not exist.
//
// THE CHEVRON IS DRAWN, NOT LOADED. Two rectangles rotating about a shared right-hand
// vertex, so it needs no SVG - which also means no new icon that could ship without a
// stated colour and draw black on a black panel, the way three rail controls did.
Item {
    id: group

    property real uiScale: 1.0

    property string title: ""
    property bool   open:  false

    // ROWS ARE ASSIGNED, NOT NESTED, AND THIS IS DELIBERATE.
    //
    // The obvious shape is `default property alias content: kids.data`, so a caller can
    // write rows straight inside the tag. It is a trap: aliasing the DEFAULT property
    // redirects every child declared under this root - including the header and body
    // declared in THIS file - into kids, which lives inside body. The component would try
    // to contain itself, and there is no compiler in this shell to catch it.
    //
    // A named alias instead, so `content: [ ... ]` at the call site says which items are
    // rows and the file's own visuals stay where they are written.
    property alias content: kids.data

    // AND THE ROWS TAKE THEIR WIDTH FROM HERE, not from `parent`. Items assigned through a
    // list are reparented after creation, so a row that binds parent.width is binding to
    // something that is not its parent yet.
    readonly property real contentWidth: Math.max(0, width - indent)

    signal toggled()

    readonly property real indent: Math.round(24 * uiScale)

    implicitHeight: header.height + (open ? body.height : 0)
    height: implicitHeight
    clip: true

    // ---- The header ---------------------------------------------------------

    Item {
        id: header

        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   parent.top
        height: Math.round(52 * group.uiScale)

        readonly property color mark: group.open ? "#8ad3ff" : "#7f8b98"

        Item {
            id: chevron

            anchors.left: parent.left
            anchors.leftMargin: Math.round(2 * group.uiScale)
            anchors.verticalCenter: parent.verticalCenter
            width:  Math.round(14 * group.uiScale)
            height: width

            // Closed points right, open points down. One rotation on the whole glyph, so
            // the two arms cannot get out of step with each other.
            rotation: group.open ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            Rectangle {
                width:  Math.round(7 * group.uiScale)
                height: Math.max(2, Math.round(2 * group.uiScale))
                radius: height / 2
                x: chevron.width - width - Math.round(2 * group.uiScale)
                y: (chevron.height - height) / 2
                transformOrigin: Item.Right
                rotation: 45
                color: header.mark
            }

            Rectangle {
                width:  Math.round(7 * group.uiScale)
                height: Math.max(2, Math.round(2 * group.uiScale))
                radius: height / 2
                x: chevron.width - width - Math.round(2 * group.uiScale)
                y: (chevron.height - height) / 2
                transformOrigin: Item.Right
                rotation: -45
                color: header.mark
            }
        }

        Text {
            anchors.left: chevron.right
            anchors.leftMargin: Math.round(10 * group.uiScale)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: group.title
            color: group.open ? "#8ad3ff" : "#eaf1f8"
            font.pixelSize: Math.round(17 * group.uiScale)
            font.bold: group.open
        }

        // THE WHOLE HEADER IS THE TARGET, not the chevron. This is operated from shore,
        // sometimes one-handed - the same reason the slider's knob is 30 du across.
        MouseArea {
            anchors.fill: parent
            onClicked: group.toggled()
        }
    }

    // ---- The children -------------------------------------------------------

    Item {
        id: body

        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   header.bottom

        visible: group.open
        height:  visible ? kids.height + Math.round(12 * group.uiScale) : 0

        // THE RULE THAT SAYS "THESE HANG OFF THAT". It runs the height of the children
        // rather than the height of this Item, so it stops where the last row stops
        // instead of trailing into the gap before the next category.
        Rectangle {
            x: Math.round(6 * group.uiScale)
            y: 0
            width:  Math.max(2, Math.round(2 * group.uiScale))
            height: kids.height
            color: "#2a4459"
        }

        Column {
            id: kids

            x: group.indent
            width: parent.width - group.indent
            spacing: 0
        }
    }
}
