import QtQuick 2.15

// A TEXT ROW (Stage 4 b) - the seventh and last of the canvas's row types. A value you type
// rather than pick.
//
// TAP TO EDIT, IN PLACE. The canvas's rule, and the reason is the same one the action row
// obeys: a settings panel that raises a dialog to edit one field covers the list the field
// belongs to. Edit and Save are the same slot, so there is one place to look.
//
// A TextInput RATHER THAN Controls' TextField. TextField carries whichever Controls style
// the app is built with and would arrive looking like neither the panel nor itself; every
// behaviour this needs - inputMethodHints, accepted(), selectByMouse - is on the primitive.
// It also keeps this file's import to plain QtQuick, like every other row.
//
// AND THE BLUR COMES BEFORE THE SAVE. On Android the input method has not necessarily given
// the field its text when a button is pressed, so focus is dropped first and the commit runs
// on the next turn of the event loop. That is not superstition - it is the sequence
// KeyCodeInput.qml already had to learn.
//
// IT REPORTS, IT DOES NOT STORE. `value` is the host's binding; the row emits `committed`.
Item {
    id: textRow

    property real uiScale: 1.0

    property string label:       ""
    property string hint:        ""
    property string value:       ""
    property string placeholder: ""

    // For a secret. The row shows dots at rest and the real thing while it is being typed -
    // a field you cannot read while typing into it is a field you cannot correct.
    property bool masked:        false
    property bool lowercaseOnly: false

    property string editText: qsTr("Edit")

    signal committed(string text)

    property bool _editing: false

    // AS TALL AS ITS CONTENT - see PulseStepperRow.
    implicitHeight: control.y + control.height + Math.round(14 * uiScale)
    height: implicitHeight

    function _beginEdit() {
        input.text = textRow.value
        _editing = true
        Qt.callLater(function () { input.forceActiveFocus() })
    }

    function _commit() {
        var text = input.text.trim()
        _editing = false
        textRow.committed(text)
    }

    function _save() {
        input.focus = false
        Qt.callLater(textRow._commit)
    }

    Text {
        id: labelText

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.round(14 * textRow.uiScale)

        text: textRow.label
        color: "#eaf1f8"
        font.pixelSize: Math.round(16 * textRow.uiScale)
        wrapMode: Text.WordWrap
    }

    Text {
        id: hintText

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: labelText.bottom
        anchors.topMargin: Math.round(2 * textRow.uiScale)

        text: textRow.hint
        color: "#8a929c"
        font.pixelSize: Math.round(13 * textRow.uiScale)
        wrapMode: Text.WordWrap
    }

    Item {
        id: control

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: hintText.bottom
        anchors.topMargin: Math.round(10 * textRow.uiScale)
        height: Math.round(44 * textRow.uiScale)

        // ---- The field ------------------------------------------------------

        Rectangle {
            id: field

            anchors.left: parent.left
            anchors.right: buttons.left
            anchors.rightMargin: Math.round(10 * textRow.uiScale)
            anchors.verticalCenter: parent.verticalCenter
            height: Math.round(44 * textRow.uiScale)
            radius: Math.round(8 * textRow.uiScale)

            color: textRow._editing ? "#0e1419" : "transparent"
            border.width: 1
            border.color: textRow._editing ? "#3d7fd0" : "#2a3644"

            // TWO ELEMENTS, NOT ONE FIELD IN TWO MODES, and that is rule 2 rather than
            // fussiness. A TextInput whose `text` is BOUND to the stored value cannot also
            // be typed into: _beginEdit would have to assign it, and the first assignment
            // destroys the binding for good - after which the row shows whatever it last
            // held rather than what is stored.
            //
            // So the resting element binds and is never written, and the editor is written
            // and never binds. The draft lives only in the editor, which is also what makes
            // Cancel free: nothing outside it ever saw the draft.
            Text {
                id: restText

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin:  Math.round(12 * textRow.uiScale)
                anchors.rightMargin: Math.round(12 * textRow.uiScale)
                anchors.verticalCenter: parent.verticalCenter

                visible: !textRow._editing
                elide: Text.ElideRight

                readonly property bool empty: textRow.value === ""

                text: empty ? textRow.placeholder
                            : (textRow.masked
                               ? Array(Math.min(textRow.value.length, 12) + 1).join("•")
                               : textRow.value)
                color: empty ? "#6d7784" : "#eaf1f8"
                font.pixelSize: Math.round(16 * textRow.uiScale)
            }

            TextInput {
                id: input

                anchors.fill: parent
                anchors.leftMargin:  Math.round(12 * textRow.uiScale)
                anchors.rightMargin: Math.round(12 * textRow.uiScale)
                verticalAlignment: TextInput.AlignVCenter

                visible: textRow._editing
                enabled: textRow._editing

                // No binding on `text` anywhere - see above. _beginEdit seeds it and the
                // user owns it from there.

                color: "#eaf1f8"
                font.pixelSize: Math.round(16 * textRow.uiScale)
                selectByMouse: true
                clip: true

                inputMethodHints: textRow.lowercaseOnly
                                  ? (Qt.ImhNoPredictiveText | Qt.ImhLowercaseOnly
                                     | Qt.ImhNoAutoUppercase)
                                  : Qt.ImhNone

                onTextChanged: {
                    if (!textRow._editing || !textRow.lowercaseOnly)
                        return
                    var lower = text.toLowerCase()
                    if (lower !== text)
                        text = lower
                }

                onAccepted: textRow._save()
            }

            // The whole field opens the editor, not just the button beside it.
            MouseArea {
                anchors.fill: parent
                visible: !textRow._editing
                enabled: !textRow._editing
                onClicked: textRow._beginEdit()
            }
        }

        // ---- Edit, or Save and Cancel ----------------------------------------

        Row {
            id: buttons

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(8 * textRow.uiScale)

            Rectangle {
                visible: !textRow._editing
                width:  editLabel.width + Math.round(28 * textRow.uiScale)
                height: Math.round(44 * textRow.uiScale)
                radius: height / 2
                color: editArea.pressed ? "#223243" : "#182430"
                border.width: 1
                border.color: "#3d7fd0"

                Text {
                    id: editLabel
                    anchors.centerIn: parent
                    text: textRow.editText
                    color: "#cfe0f2"
                    font.pixelSize: Math.round(15 * textRow.uiScale)
                }

                MouseArea {
                    id: editArea
                    anchors.fill: parent
                    onClicked: textRow._beginEdit()
                }
            }

            Rectangle {
                visible: textRow._editing
                width:  saveLabel.width + Math.round(28 * textRow.uiScale)
                height: Math.round(44 * textRow.uiScale)
                radius: height / 2
                color: saveArea.pressed ? "#2f7fb5" : "#3d7fd0"

                Text {
                    id: saveLabel
                    anchors.centerIn: parent
                    text: qsTr("Save")
                    color: "#08121b"
                    font.pixelSize: Math.round(15 * textRow.uiScale)
                    font.bold: true
                }

                MouseArea {
                    id: saveArea
                    anchors.fill: parent
                    onClicked: textRow._save()
                }
            }

            Rectangle {
                visible: textRow._editing
                width:  cancelLabel.width + Math.round(24 * textRow.uiScale)
                height: Math.round(44 * textRow.uiScale)
                radius: height / 2
                color: cancelArea.pressed ? "#2a303a" : "transparent"
                border.width: 1
                border.color: "#6d7480"

                Text {
                    id: cancelLabel
                    anchors.centerIn: parent
                    text: qsTr("Cancel")
                    color: "#cfd6de"
                    font.pixelSize: Math.round(15 * textRow.uiScale)
                }

                MouseArea {
                    id: cancelArea
                    anchors.fill: parent
                    onClicked: {
                        // The draft is simply dropped. Nothing outside the editor ever saw
                        // it, so there is nothing to put back.
                        input.focus = false
                        textRow._editing = false
                    }
                }
            }
        }
    }
}
