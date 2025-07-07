// KeyCodeInput.qml
import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property bool editing: false

    // Hidden helper to measure “not_set_123” at pixelSize 30
    Text {
        id: measurer
        text: "not_set_123"
        font: textField.font
        visible: false
    }

    // This function is no longer called directly by MouseArea;
    // we’ll invoke it via Qt.callLater() so textField.text is up-to-date.
    function doSaveOrEdit() {
        console.log("Key Code: doSaveOrEdit() was called; editing =", editing)
        if (editing) {
            console.log(">>> Key Code: Entering SAVE branch (editing is true)")
            var code   = textField.text.trim()
            var isBeta = pulseRuntimeSettings.betaKeyCodes.indexOf(code)   !== -1
            var isExpert = pulseRuntimeSettings.expertKeyCodes.indexOf(code) !== -1

            pulseRuntimeSettings.expertMode = isExpert
            pulseRuntimeSettings.betaMode   = isExpert || isBeta
            PulseSettings.isBetaTester      = isBeta
            PulseSettings.isExpert          = isExpert

            if (pulseRuntimeSettings.betaMode) {
                PulseSettings.keyCode = code
            } else {
                PulseSettings.keyCode = "not_set"
            }

            console.log("Key Code: User entered", code)
            console.log(
                "Key Code: result: expertMode", pulseRuntimeSettings.expertMode,
                "and betaMode", pulseRuntimeSettings.betaMode
            )
            editing = false
        } else {
            console.log(">>> Key Code: Entering EDIT branch (editing is false)")
            editing = true
            Qt.callLater(function() { textField.forceActiveFocus() })
        }
    }

    Row {
        id: rowLayout
        spacing: 4

        TextField {
            id: textField
            font.pixelSize: 30

            // Show the real key when editing; otherwise “not_set” masked
            text: editing
                  ? (PulseSettings.keyCode || "")
                  : (PulseSettings.keyCode || "not_set")
            readOnly: !editing
            echoMode: editing ? TextInput.Normal : TextInput.Password
            passwordCharacter: "*"
            width: measurer.width
            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhLowercaseOnly

            onTextChanged: {
                if (editing) {
                    var lower = text.toLowerCase()
                    if (lower !== text) {
                        // reset the field to the lowercase version
                        textField.text = lower
                    }
                }
            }

            // If user hits Enter/Return, commit immediately:
            onAccepted: {
                textField.focus = false                   // force blur
                Qt.callLater(doSaveOrEdit)                 // then run save logic
            }
        }

        Image {
            id: actionIcon
            source: editing ? "./icons/pulse_save.svg" : "./icons/pulse_edit.svg"
            width: 64
            height: 64
            fillMode: Image.PreserveAspectFit

            anchors.verticalCenter: textField.verticalCenter
            anchors.left:           textField.right
            anchors.leftMargin:     10

            MouseArea {
                anchors.fill: parent

                onReleased: {
                    if (editing) {
                        // Step 1: blur the TextField so IME can commit text
                        textField.focus = false
                        // Step 2: once blur+commit finishes, run save
                        Qt.callLater(doSaveOrEdit)
                    } else {
                        // If pencil icon was clicked, just enter edit mode
                        doSaveOrEdit()
                    }
                }
            }
        }

        Image {
            id: betaUser
            source: "./icons/pulse_beta_user.svg"
            width: 64
            height: 64
            fillMode: Image.PreserveAspectFit
            visible: PulseSettings.isBetaTester

            anchors.verticalCenter: actionIcon.verticalCenter
            anchors.left:           actionIcon.right
            anchors.leftMargin:     10

        }

        Image {
            id: expertUser
            source: "./icons/pulse_guru_user.svg"
            width: 64
            height: 64
            fillMode: Image.PreserveAspectFit
            visible: PulseSettings.isExpert

            anchors.verticalCenter: actionIcon.verticalCenter
            anchors.left:           actionIcon.right
            anchors.leftMargin:     10

        }
    }

}
