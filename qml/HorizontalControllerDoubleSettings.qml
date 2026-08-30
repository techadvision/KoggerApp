import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Echo.UI 1.0
import QtQuick.Window

Item {
    id: root

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real platformScale: _isAndroid ? 0.9 : 0.75
    //readonly property real s: Ui.scale * platformScale
    readonly property real shortSide: Math.min(Screen.width, Screen.height)
    readonly property real s: Math.max(1.0, shortSide / 1200) // tune 800 to your “10-inch baseline”

    // Platform related sizes
    property int pressButtonSize: Math.round(56 * s)
    property int displayPixels:   Math.round(50 * s)
    property int valueTextWidth:  Math.round(150 * s)
    property int valuePixels:     Math.round(42 * s)

    /*
    property int pressButtonSize: _isAndroid ? 54 : 32
    property int displayPixels:   _isAndroid ? 80 : 40
    property int valueTextWidth:  _isAndroid ? 120 : 80
    property int valuePixels:     _isAndroid ? 30 : 22
    */


    property var values: [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
    property int currentIndex: 0

    // Delay (ms) a finger must be held before auto-repeat begins. A scroll
    // gesture cancels the press well before this, so it never triggers.
    property int holdDelay: 450
    // Interval (ms) between auto-repeat steps once holding.
    property int repeatInterval: 150

    signal pulsePreferenceValueChanged(double newValue)

    // PULSE: emit pulsePreferenceValueChanged ONLY for a real user step.
    //
    // The default (false) is the historic behaviour: the signal fires on ANY change,
    // including the programmatic seed in Component.onCompleted and the Connections
    // re-sync. That has two bad effects on a property that is BOUND to a device
    // profile: the seed writes the value straight back and destroys the binding, and
    // a re-sync that cannot find the current value falls back to the first entry and
    // WRITES THAT to the device. Rows driving bound or device-critical parameters
    // opt in; everything else keeps the old behaviour untouched.
    property bool emitOnUserActionOnly: false
    property bool _userDriven: false

    // The ONLY user-driven path. QML emits the change signal synchronously during the
    // assignment, so _userDriven is still set when onCurrentIndexChanged runs.
    function _stepBy(delta) {
        var next = currentIndex + delta
        if (next < 0 || next > values.length - 1 || next === currentIndex)
            return
        _userDriven = true
        currentIndex = next
        _userDriven = false
    }

    implicitWidth: Math.round(100 * s) //_isAndroid ? 280 : 180
    implicitHeight: Math.round(54 * s) //_isAndroid ? 54 : 32
    //implicitHeight: _isAndroid ? 80 : 54

    onCurrentIndexChanged: {
        if (emitOnUserActionOnly && !_userDriven)
            return
        pulsePreferenceValueChanged(values[currentIndex])
    }

    Row {
        anchors.fill: parent
        width: parent.width
        height: parent.height
        //width: root._isAndroid ? 300 : 200
        //height: root._isAndroid ? 80 : 54

        Button {
            id: minusButton
            text: "-"
            font.pixelSize: root.displayPixels
            width: root.pressButtonSize
            height: root.pressButtonSize
            anchors.top: valueRect.top
            anchors.bottom: valueRect.bottom

            // true once auto-repeat has begun, so the trailing onClicked
            // (which fires on release) does not add an extra step.
            property bool _repeating: false

            background: Item {
                width: minusButton.width
                height: minusButton.height
                clip: true

                Rectangle {
                    id: leftCap
                    width: height
                    height: parent.height
                    color: minusButton.down ? "#666666" : "#dddddd"
                    radius: height/2
                }

                Rectangle {
                    x: leftCap.width/2
                    width: parent.width - leftCap.width/2
                    height: parent.height
                    color: minusButton.down ? "#666666" : "#dddddd"

                }
            }

            // Arms auto-repeat only after a genuine hold; a scroll cancels
            // the press before this fires.
            Timer {
                id: minusHoldTimer
                interval: root.holdDelay
                repeat: false
                running: false
                onTriggered: {
                    minusButton._repeating = true
                    minusRepeatTimer.start()
                }
            }

            Timer {
                id: minusRepeatTimer
                interval: root.repeatInterval
                repeat: true
                running: false
                onTriggered: {
                    if (currentIndex > 0)
                        root._stepBy(-1)
                    else
                        minusRepeatTimer.stop()
                }
            }

            // Do NOT step on press: a press may turn into a scroll. Just arm
            // the hold timer for the press-and-hold auto-repeat.
            onPressed: {
                _repeating = false
                minusHoldTimer.restart()
            }
            onReleased: { minusHoldTimer.stop(); minusRepeatTimer.stop() }
            onCanceled: { minusHoldTimer.stop(); minusRepeatTimer.stop(); _repeating = false }
            // Single confirmed tap (release without drag). The Flickable
            // cancels this when the gesture becomes a scroll.
            onClicked: {
                if (!_repeating && currentIndex > 0)
                    root._stepBy(-1)
            }
        }

        Rectangle {
            id: valueRect
            width: root.valueTextWidth
            height: root.pressButtonSize
            //width: 120
            //height: 60
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.width: 1
            border.color: "#dddddd"

            Text {
                id: valueDisplay
                text: root.values[root.currentIndex]
                font.pixelSize: Ui.fontXL //root.valuePixels
                anchors.centerIn: parent
            }
        }

        Button {
            id: plusButton
            text: "+"
            font.pixelSize: root.displayPixels
            width: root.pressButtonSize
            height: root.pressButtonSize
            anchors.top: valueRect.top
            anchors.bottom: valueRect.bottom

            // true once auto-repeat has begun, so the trailing onClicked
            // (which fires on release) does not add an extra step.
            property bool _repeating: false

            background: Item {
                width: plusButton.width
                height: plusButton.height
                clip: true

                Rectangle {
                    x: parent.width - parent.height
                    width: parent.height
                    height: parent.height
                    color: plusButton.down ? "#666666" : "#dddddd"
                    radius: parent.height / 2
                }

                Rectangle {
                    width: parent.width - parent.height / 2
                    height: parent.height
                    color: plusButton.down ? "#666666" : "#dddddd"
                    radius: 0
                }
            }

            // Arms auto-repeat only after a genuine hold; a scroll cancels
            // the press before this fires.
            Timer {
                id: plusHoldTimer
                interval: root.holdDelay
                repeat: false
                running: false
                onTriggered: {
                    plusButton._repeating = true
                    plusRepeatTimer.start()
                }
            }

            Timer {
                id: plusRepeatTimer
                interval: root.repeatInterval
                repeat: true
                running: false
                onTriggered: {
                    if (currentIndex < values.length - 1)
                        root._stepBy(1)
                    else
                        plusRepeatTimer.stop()
                }
            }

            // Do NOT step on press: a press may turn into a scroll. Just arm
            // the hold timer for the press-and-hold auto-repeat.
            onPressed: {
                _repeating = false
                plusHoldTimer.restart()
            }
            onReleased: { plusHoldTimer.stop(); plusRepeatTimer.stop() }
            onCanceled: { plusHoldTimer.stop(); plusRepeatTimer.stop(); _repeating = false }
            // Single confirmed tap (release without drag). The Flickable
            // cancels this when the gesture becomes a scroll.
            onClicked: {
                if (!_repeating && currentIndex < values.length - 1)
                    root._stepBy(1)
            }
        }
    }
}

