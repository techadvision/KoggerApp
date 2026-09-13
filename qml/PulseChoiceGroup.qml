import QtQuick 2.15

// A CHOICE GROUP (Stage 4 b) - one of a short list, with the real value named.
//
// The canvas asks for segmented controls at four entries or fewer and a list above that.
// This is a list either way, on purpose: the entries carry a frequency, and 510 kHz beside
// "Wide" is the whole point of moving this out of a 76 px pop-up. A segment wide enough to
// hold both is a row.
//
// ONE BUTTON, TWO QUESTIONS. A view on PULSE blue, a cone on PULSE red - and the panel says
// which, because the same rail button opens both. That is the committed device's question:
// a chooser offers HARDWARE choices, and never follows a log.
//
// Like every other group here: it is handed a list and a current id, and it reports taps.
Item {
    id: group

    property real uiScale: 1.0

    property var    entries:   []
    property string currentId: ""
    property string caption:   ""

    signal chosen(string id)

    implicitHeight: column.height

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

        // A device that offers one of something shows no chooser at all, so an empty list
        // here can only mean a profile edit went wrong - and saying so beats a blank panel.
        Text {
            visible: group.entries.length === 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: qsTr("This transducer offers no choice here.")
            color: "#8a929c"
            font.pixelSize: Math.round(15 * group.uiScale)
        }

        Repeater {
            model: group.entries

            Rectangle {
                id: row

                readonly property bool isCurrent: modelData.id === group.currentId

                width:  column.width
                height: Math.round(72 * group.uiScale)
                radius: Math.round(10 * group.uiScale)

                color: rowArea.pressed ? "#2a3644" : (isCurrent ? "#16232e" : "transparent")
                border.width: isCurrent ? 2 : 1
                border.color: isCurrent ? "#3d7fd0" : "#20ffffff"

                Image {
                    id: glyph
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(14 * group.uiScale)
                    anchors.verticalCenter: parent.verticalCenter
                    width:  Math.round(40 * group.uiScale)
                    height: width
                    source: modelData.icon
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Text {
                    id: title
                    anchors.left: glyph.right
                    anchors.leftMargin: Math.round(14 * group.uiScale)
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(14 * group.uiScale)
                    anchors.bottom: parent.verticalCenter
                    text: modelData.title
                    elide: Text.ElideRight
                    color: row.isCurrent ? "#eaf1f8" : "#cfd6de"
                    font.pixelSize: Math.round(17 * group.uiScale)
                    font.bold: row.isCurrent
                }

                // THE REAL VALUE, NAMED. An icon can imply a cone; only a number says which
                // one, and the frequency is the thing an expert is actually choosing between.
                Text {
                    anchors.left: title.left
                    anchors.top: parent.verticalCenter
                    anchors.topMargin: Math.round(2 * group.uiScale)
                    text: modelData.freq !== undefined ? modelData.freq + " kHz" : ""
                    color: "#8a929c"
                    font.pixelSize: Math.round(14 * group.uiScale)
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
