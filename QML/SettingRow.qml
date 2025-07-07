import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15


GridLayout {
    id: root
    // caller can tweak the width of the label column in one place:
    property int labelWidth: 560
    property bool toggle: false

    property bool show: true
    property bool _fadingOut: false

    visible: toggle || show || _fadingOut
    opacity: (toggle || show) ? 1 : 0

    columns: 3
    rowSpacing: 0
    columnSpacing: 20


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
    Text {
        id: label
        text: ""
        font.pixelSize: 28
        wrapMode: Text.Wrap
        Layout.preferredWidth: root.labelWidth
        Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        Layout.leftMargin: toggle ? 20 : 40
        color: toggle ? "black" : "#464646"
    }

    // ——— spacer ———
    Item {
        id: controlSpacer
        visible: !toggle
        width: toggle ? 0 : 20
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
