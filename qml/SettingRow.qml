import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window
import Echo.UI 1.0

RowLayout {
    id: root

    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real shortSide: Math.min(Screen.width, Screen.height)
    readonly property real s: Math.max(1.0, shortSide / 1100)

    property int  labelWidth: Math.round(550 * s)
    property bool toggle: false
    property bool checkbox: false
    property bool beta: false
    property bool show: true
    property bool _fadingOut: false

    // IMPORTANT when used inside ColumnLayout / ScrollView / etc.
    Layout.fillWidth: true

    spacing: Math.round(20 * s)

    visible: toggle || show || _fadingOut
    opacity: (toggle || show) ? 1 : 0

    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
    }

    onShowChanged: {
        if (!show && !toggle) {
            _fadingOut = true
            fadeTimer.restart()
        }
    }

    Timer {
        id: fadeTimer
        interval: 150
        repeat: false
        onTriggered: _fadingOut = false
    }

    // --- label area (icon + text) ---
    RowLayout {
        id: labelRow
        Layout.fillWidth: true
        Layout.minimumWidth: 0              // allow shrinking
        Layout.preferredWidth: root.labelWidth
        Layout.maximumWidth: root.labelWidth
        spacing: 8

        // indentation (don’t use Layout.leftMargin; it increases size hints)
        Item { Layout.preferredWidth: toggle ? Math.round(10*s) : Math.round(20*s) }

        Image {
            visible: root.beta
            source: "./icons/ui/pulse_beta_feature.svg"
            fillMode: Image.PreserveAspectFit
            Layout.preferredWidth: Ui.iconTouch
            Layout.preferredHeight: Ui.iconTouch
            sourceSize.width: Math.round(52 * s)
            sourceSize.height: Math.round(52 * s)
        }

        Text {
            id: label
            Layout.fillWidth: true
            Layout.minimumWidth: 0          // allow shrinking
            text: ""
            font.pixelSize: Ui.fontL
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
            maximumLineCount: 1
            verticalAlignment: Text.AlignVCenter
            color: toggle ? "black" : "#464646"
        }
    }

    // optional gap before control
    Item {
        Layout.preferredWidth: Math.round(10 * s)
        Layout.fillWidth: !root.toggle && !root.checkbox
        //Layout.preferredWidth: toggle ? 0 : Math.round(10 * s)
    }

    // --- control slot ---
    RowLayout {
        id: controlSlot
        spacing: 0
        Layout.fillWidth: !root.toggle && !root.checkbox
        // This makes the control keep its own implicit/preferred size,
        // and the label will shrink/elide instead.
        Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft

        default property alias control: controlSlot.data
    }

    property alias text: label.text
}
