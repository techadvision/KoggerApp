import QtQuick 2.15
import QtQuick.Controls 2.15


Item {
    id: root
    property var    target
    property string targetPropertyName: ""
    property bool   initialValue:       false
    property string showIconSource:     "./icons/pulse_setting_show.svg"
    property bool   expanded:           initialValue

    width: 64
    height: 64

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

