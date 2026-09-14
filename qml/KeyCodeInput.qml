// KeyCodeInput.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import Echo.UI 1.0
import QtQuick.Window

Item {
    id: root

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real platformScale: _isAndroid ? 0.9 : 0.75
    //readonly property real s: Ui.scale * platformScale
    readonly property real shortSide: Math.min(Screen.width, Screen.height)
    readonly property real s: Math.max(1.0, shortSide / 1100) // tune 800 to your “10-inch baseline”

    // Platform related sizes
    property int controlIconSize: Math.round(24 * s)
    property int pressButtonSize: Math.round(56 * s)
    property int displayPixels:   Math.round(60 * s)
    property int valueTextWidth:  Math.round(60 * s)
    property int valueTextHeigh:  Math.round(40 * s)
    property int valuePixels:     Math.round(42 * s)
    property int autoPixels:      Math.round(32 * s)
    property int selectIconSize:  Math.round(64 * s)
    property int selectCheckSize: Math.round(48 * s)

    /*
    property int controlIconSize: _isAndroid ? 34 : 20
    property int pressButtonSize: _isAndroid ? 80 : 40
    property int displayPixels:   _isAndroid ? 100 : 40
    property int valueTextWidth:  _isAndroid ? 120 : 80
    property int valueTextHeigh:  _isAndroid ? 40 : 30
    property int valuePixels:     _isAndroid ? 30 : 22
    property int autoPixels:      _isAndroid ? 32 : 24
    property int selectIconSize:  _isAndroid ? 80 : 60
    property int selectCheckSize: _isAndroid ? 56 : 40
    */


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
            // THE RULE MOVED, IT WAS NOT COPIED. It is pulseRuntimeSettings.applyKeyCode
            // now, because the v2 settings list needs the same answer and cannot reach a
            // classic control - and two copies of "which codes grant what" is one copy too
            // many. Every line this replaced is in that function, unchanged.
            pulseRuntimeSettings.applyKeyCode(textField.text, installToken.currentSalt)
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
            font.pixelSize: Ui.fontXL //root.valuePixels

            // Show the real key when editing; otherwise “not_set” masked
            text: editing
                  ? (pulseSettings.keyCode || "")
                  : (pulseSettings.keyCode || "not_set")
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
            source: editing ? "./icons/ui/pulse_save.svg" : "./icons/ui/pulse_edit.svg"
            width: Math.round(64 * s) //_isAndroid ? 64 : 28
            height: Math.round(64 * s) //_isAndroid ? 64 : 28
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
            source: "./icons/ui/pulse_beta_user.svg"
            width: Ui.iconTouch //_isAndroid ? 64 : 28
            height: Ui.iconTouch //_isAndroid ? 64 : 28
            fillMode: Image.PreserveAspectFit
            visible: pulseSettings.isBetaTester

            anchors.verticalCenter: actionIcon.verticalCenter
            anchors.left:           actionIcon.right
            anchors.leftMargin:     10

        }

        Image {
            id: expertUser
            source: "./icons/ui/pulse_guru_user.svg"
            width: Ui.iconTouch //_isAndroid ? 64 : 28
            height: Ui.iconTouch //_isAndroid ? 64 : 28
            fillMode: Image.PreserveAspectFit
            visible: pulseSettings.isExpert

            anchors.verticalCenter: actionIcon.verticalCenter
            anchors.left:           actionIcon.right
            anchors.leftMargin:     10

        }
    }

}
