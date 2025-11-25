import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15


GridLayout {
    id: root

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    // Platform related sizes
    property int controlIconSize: _isAndroid ? 34 : 20
    property int pressButtonSize: _isAndroid ? 80 : 40
    property int displayPixels:   _isAndroid ? 100 : 40
    property int valueTextWidth:  _isAndroid ? 60 : 40
    property int valueTextHeigh:  _isAndroid ? 40 : 30
    property int valuePixels:     _isAndroid ? 42 : 32
    property int autoPixels:      _isAndroid ? 32 : 24
    property int selectIconSize:  _isAndroid ? 80 : 60
    property int selectCheckSize: _isAndroid ? 56 : 40
    property int infoPixelsSize:  _isAndroid ? 28 : 18

    // caller can tweak the width of the label column in one place:
    property int labelWidth: _isAndroid ? 560 : 320
    property bool toggle:    false
    property bool beta:      false

    property bool show: true
    property bool _fadingOut: false

    visible: toggle || show || _fadingOut
    opacity: (toggle || show) ? 1 : 0

    columns: 3
    rowSpacing: 0
    columnSpacing: _isAndroid ? 20 : 13


    // animate opacity changes over 150 ms
    Behavior on opacity {
        NumberAnimation { duration: 1000; easing.type: Easing.InOutQuad }
    }

    // when 'show' flips to false for a non-toggle row, keep it alive to fade out
    onShowChanged: {
        if (!show && !toggle) {
            _fadingOut = true;
            fadeTimer.restart();
        }
    }

    Timer {
            id: fadeTimer
            interval: 150
            repeat: false
            onTriggered: {
                _fadingOut = false;
            }
        }

    // ——— label ———
    RowLayout {
        id: labelRow
        Layout.preferredWidth: root.labelWidth
        Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        Layout.leftMargin: toggle ? 20 : 40
        spacing: 8

        Image {
            id: betaIcon
            visible: root.beta
            source: "./icons/ui/pulse_beta_feature.svg"
            width: 48
            height: 48
            fillMode: Image.PreserveAspectFit
            Layout.leftMargin: toggle ? 20 : 40
            sourceSize.width: 64
            sourceSize.height: 64
        }

        Text {
            id: label
            text: ""
            font.pixelSize: root.infoPixelsSize
            wrapMode: Text.Wrap
            Layout.preferredWidth: root.labelWidth
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: toggle ? 20 : 40
            color: toggle ? "black" : "#464646"
        }

    }


    /*
    Text {
        id: label
        text: ""
        font.pixelSize: root.infoPixelsSize
        wrapMode: Text.Wrap
        Layout.preferredWidth: root.labelWidth
        Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        Layout.leftMargin: toggle ? 20 : 40
        color: toggle ? "black" : "#464646"
    }
    */

    // ——— spacer ———
    Item {
        id: controlSpacer
        visible: !toggle
        width: toggle ? 0 : root._isAndroid ? 20 : 12
    }

    // ——— control ———
    Item {
        id: controlHolder
        Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        default property alias control: controlHolder.data
    }

    // expose “text” to parent
    property alias text: label.text

}
