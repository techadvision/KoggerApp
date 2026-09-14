import QtQuick 2.15

// THE SCREEN CHOOSER (Stage 4 b) - what the screen shows, as one of six pictures.
//
// This is the control the upstream author has and the Pulse app never had, and it
// REPLACES the side/down view chooser rather than joining it: once the layout says which
// picture is on screen, a separate "which view" question has nothing left to answer.
//
// WHY A LIST AND NOT A GRID OF TILES. Three treatments were drawn at the panel's real
// 360 px - a 2x3 tile grid, this list, and three-and-three under Single/Split headings -
// and Olav chose the list: "should fit well with our current fall out menu". It is
// PulseChoiceGroup's 72 px row with a screen picture where the icon was, so the panel
// gains no new row shape, and the group scrolls in the Flickable the panel already has.
//
// Like every other group here: handed a list and a current id, and it reports taps.
Item {
    id: group

    property real uiScale: 1.0

    property var    entries:   []
    property string currentId: ""
    property string caption:   ""

    signal chosen(string id)

    implicitHeight: column.height

    // ONE LINE THAT ANSWERS "DID THIS EVEN LOAD". A group that fails to build takes the
    // whole panel with it - PulsePanel is its parent - and the symptom is every rail button
    // doing nothing, which looks nothing like a QML error unless the log is read.
    Component.onCompleted: console.log("SCREEN: chooser built with", entries.length, "layouts")

    Column {
        id: column
        width: group.width
        spacing: Math.round(8 * group.uiScale)

        Text {
            visible: group.caption !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            text: group.caption
            color: "#8a929c"
            font.pixelSize: Math.round(14 * group.uiScale)
            bottomPadding: Math.round(4 * group.uiScale)
        }

        // A 2D transducer needs none of this - there is one picture and no second pane to
        // offer - so the rail offers no Screen button at all and this list is never built.
        // An empty list here can therefore only mean the entry table went wrong.
        Text {
            visible: group.entries.length === 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: qsTr("This transducer offers one picture only.")
            color: "#8a929c"
            font.pixelSize: Math.round(15 * group.uiScale)
        }

        Repeater {
            model: group.entries


            Rectangle {
                id: row

                readonly property bool isCurrent: modelData.id === group.currentId
                readonly property real pad: Math.round(14 * group.uiScale)

                width: column.width
                // A ROW IS AS TALL AS ITS CONTENT. The mark and the two lines of text are
                // both candidates for the tallest thing in the row, so the row asks them
                // rather than being told 72 - which is what it comes to at uiScale 1.
                //
                // implicitHeight, NOT height, and that is the whole difference between this
                // working and a binding loop. `label` is centred on this row, so its `height`
                // is downstream of the row's - reading it here would ask the row how tall it
                // is in order to answer how tall it is. implicitHeight comes only from the
                // Column's own children and is upstream of both.
                height: Math.max(mark.height, label.implicitHeight)
                        + 2 * Math.round(16 * group.uiScale)
                radius: Math.round(10 * group.uiScale)

                color: rowArea.pressed ? "#2a3644" : (isCurrent ? "#16232e" : "transparent")
                border.width: isCurrent ? 2 : 1
                border.color: isCurrent ? "#3d7fd0" : "#20ffffff"

                PulseScreenMark {
                    id: mark

                    anchors.left: parent.left
                    anchors.leftMargin: row.pad
                    anchors.verticalCenter: parent.verticalCenter

                    width:  Math.round(56 * group.uiScale)
                    height: Math.round(35 * group.uiScale)

                    topKind:    modelData.top
                    bottomKind: modelData.bottom !== undefined ? modelData.bottom : ""
                }

                Column {
                    id: label

                    anchors.left: mark.right
                    anchors.leftMargin: row.pad
                    anchors.right: parent.right
                    anchors.rightMargin: row.pad
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(2 * group.uiScale)

                    Text {
                        width: parent.width
                        text: modelData.title
                        elide: Text.ElideRight
                        color: row.isCurrent ? "#eaf1f8" : "#cfd6de"
                        font.pixelSize: Math.round(17 * group.uiScale)
                        font.bold: row.isCurrent
                    }

                    // FULL SCREEN OR SPLIT, said in words. The picture already shows it,
                    // but the picture is 56 px wide and the word costs nothing - the same
                    // reason the cone rows print the frequency under the name.
                    Text {
                        width: parent.width
                        text: modelData.subtitle !== undefined ? modelData.subtitle : ""
                        // The ENTRY, not this element's own `text`. Asking `text !== ""`
                        // inside a Text reads its own property, which is the sort of thing
                        // that works until the day it does not.
                        visible: modelData.subtitle !== undefined && modelData.subtitle !== ""
                        elide: Text.ElideRight
                        color: "#8a929c"
                        font.pixelSize: Math.round(14 * group.uiScale)
                    }
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    onClicked: group.chosen(modelData.id)
                }
            }
        }
    }
}
