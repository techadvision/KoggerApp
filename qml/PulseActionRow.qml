import QtQuick 2.15

// AN ACTION ROW (Stage 4 b) - row type six of seven. A row that DOES something rather than
// holding a value.
//
// IT CONFIRMS IN THE ROW, NEVER IN A DIALOG. That is the canvas's rule and it is the same
// answer the recording question already gives: the pill column asks about recording where
// the recording state is shown, rather than raising a second surface the eye has to learn.
// A modal over a settings list is a worse version of the same idea - it covers the thing
// you were reading to decide.
//
// AND THE TWO ANSWERS ARE NOT EQUAL. Amber and filled for the one that acts, outlined for
// the one that changes nothing - the pairing the setup card's escape hatch and the
// recording question both use, so a third question in this app reads like the first two.
//
// A PLAIN STATE PROPERTY with one writer and nothing bound to it, which is not the shape
// rule 2 forbids - the same `asking` that PulsePillColumn carries.
Item {
    id: actionRow

    property real uiScale: 1.0

    property string label:      ""
    property string hint:       ""
    property string actionText: ""

    // Set both to make the row ask first. An action that needs no question leaves them
    // empty and fires on the first tap.
    property string question:    ""
    property string confirmText: ""

    readonly property bool asks: question !== "" && confirmText !== ""

    signal activated()

    property bool _asking: false

    function dismiss() { _asking = false }

    implicitHeight: Math.round(40 * uiScale)
                    + Math.round(44 * uiScale)
                    + Math.round(26 * uiScale)
    height: implicitHeight

    Text {
        id: labelText

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.round(14 * actionRow.uiScale)

        text: actionRow.label
        color: "#eaf1f8"
        font.pixelSize: Math.round(16 * actionRow.uiScale)
        wrapMode: Text.WordWrap
    }

    // ONE LINE, TWO JOBS. While the row is asking, the question stands where the hint was
    // rather than below it - so the row does not change height and the list does not jump
    // under the finger that just tapped.
    Text {
        id: secondLine

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: labelText.bottom
        anchors.topMargin: Math.round(2 * actionRow.uiScale)

        text: actionRow._asking ? actionRow.question : actionRow.hint
        color: actionRow._asking ? "#f4ead6" : "#8a929c"
        font.pixelSize: Math.round(13 * actionRow.uiScale)
        wrapMode: Text.WordWrap
    }

    Item {
        id: control

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: secondLine.bottom
        anchors.topMargin: Math.round(10 * actionRow.uiScale)
        height: Math.round(44 * actionRow.uiScale)

        // ---- At rest --------------------------------------------------------

        Rectangle {
            id: actionButton

            visible: !actionRow._asking
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width:  actionLabel.width + Math.round(36 * actionRow.uiScale)
            height: Math.round(44 * actionRow.uiScale)
            radius: height / 2

            color: actionArea.pressed ? "#223243" : "#182430"
            border.width: 1
            border.color: "#3d7fd0"

            Text {
                id: actionLabel
                anchors.centerIn: parent
                text: actionRow.actionText
                color: "#cfe0f2"
                font.pixelSize: Math.round(15 * actionRow.uiScale)
            }

            MouseArea {
                id: actionArea
                anchors.fill: parent
                onClicked: {
                    if (actionRow.asks)
                        actionRow._asking = true
                    else
                        actionRow.activated()
                }
            }
        }

        // ---- Asking ---------------------------------------------------------

        Row {
            visible: actionRow._asking
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(10 * actionRow.uiScale)

            Rectangle {
                width:  confirmLabel.width + Math.round(32 * actionRow.uiScale)
                height: Math.round(44 * actionRow.uiScale)
                radius: height / 2
                color: confirmArea.pressed ? "#b8860b" : "#d8a21f"

                Text {
                    id: confirmLabel
                    anchors.centerIn: parent
                    text: actionRow.confirmText
                    color: "#1a1400"
                    font.pixelSize: Math.round(15 * actionRow.uiScale)
                    font.bold: true
                }

                MouseArea {
                    id: confirmArea
                    anchors.fill: parent
                    onClicked: {
                        actionRow._asking = false
                        actionRow.activated()
                    }
                }
            }

            Rectangle {
                width:  cancelLabel.width + Math.round(32 * actionRow.uiScale)
                height: Math.round(44 * actionRow.uiScale)
                radius: height / 2
                color: cancelArea.pressed ? "#2a303a" : "transparent"
                border.width: 1
                border.color: "#6d7480"

                Text {
                    id: cancelLabel
                    anchors.centerIn: parent
                    text: qsTr("Not now")
                    color: "#cfd6de"
                    font.pixelSize: Math.round(15 * actionRow.uiScale)
                }

                MouseArea {
                    id: cancelArea
                    anchors.fill: parent
                    onClicked: actionRow._asking = false
                }
            }
        }
    }
}
