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

    // CAN THIS BE CHOSEN RIGHT NOW. A cone is a COMMAND TO A TRANSDUCER, and with a
    // recording on screen there is nothing for it to command that would change what is
    // being looked at. Olav's rule for it: "OK to have the bar expanded, but not clickable
    // choices."
    //
    // DISABLED RATHER THAN ABSENT, which is the opposite of what the rail and the settings
    // list do, and deliberately. Absent is right when a device does not HAVE the ability -
    // a chooser of one is not a chooser. Here the ability exists and is momentarily
    // unusable, and a row that vanishes while a log plays and returns when it stops reads
    // as a bug rather than as a rule.
    //
    // THE CURRENT ROW KEEPS ITS MARK. The chooser is the committed device's question, so
    // the highlight is still true: it is what the transducer is set to. The note below
    // says so, rather than letting the user read it as the recording's frequency.
    property bool   choosable: true
    property string note:      ""

    readonly property real _dim: choosable ? 1.0 : 0.45

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

        // WHY IT CANNOT BE TAPPED, in the caption's own voice and never as an error. It sits
        // above the rows rather than below them so it is read before the thing it explains.
        Text {
            visible: group.note !== "" && !group.choosable
            width: parent.width
            wrapMode: Text.WordWrap
            text: group.note
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

                // One opacity on the row carries the glyph, both texts and the border with
                // it, so there is a single number deciding how "unavailable" reads rather
                // than four colours to keep in step.
                opacity: group._dim

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

                // ENABLED, NOT ABSENT, and the pressed colour above follows it - so a tap
                // on a disabled row does nothing at all rather than flashing as though it
                // had been heard.
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    enabled: group.choosable
                    onClicked: group.chosen(modelData.id)
                }
            }
        }
    }
}
