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

    property var    target
    property string targetPropertyName: ""
    property bool   initialValue:       false
    property string showIconSource:     "./icons/ui/pulse_setting_show.svg"
    property bool   expanded:           initialValue

    implicitWidth:  Math.round(64 * s)
    implicitHeight: Math.round(64 * s)

    Image {
        id: icon
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        source: showIconSource

        transformOrigin: Item.Center
        rotation: expanded ? 90 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: 250
                easing.type: Easing.InOutQuad
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            expanded = !expanded;
            if (target && targetPropertyName && target.hasOwnProperty(targetPropertyName)) {
                target[targetPropertyName] = expanded;
            }
        }
    }

    Component.onCompleted: {
        expanded = initialValue;
    }
}

