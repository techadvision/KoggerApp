import QtQuick 2.15

// THE CENTRE-ON-BOAT PILL (22 Nov 2026) - beside the mosaic pill, same shape and colours.
//
// Olav: a pill "to activate/deactivate centre on boat", looking like the Pause pill. It is the
// way back to the boat when the map is somewhere else. While it is on, the map follows the
// boat; a drag or pinch lets go for a few seconds and the map then flies back (the view's own
// follow, GraphicsScene3dView::setTrackLastData / flyToLastPosition - upstream's location
// button, which sits on the 3D toolbar v2 hides).
//
// It reports and stores nothing: `following` is bound by main.qml to the stored preference and
// a tap asks for the other state.
Item {
    id: pill

    property real uiScale:   1.0
    property bool following: false

    signal followRequested(bool follow)

    implicitWidth:  body.width
    implicitHeight: body.height

    Rectangle {
        id: body

        width:  btn.width  + 2 * Math.round(10 * pill.uiScale)
        height: btn.height + 2 * Math.round(7 * pill.uiScale)
        radius: height / 2
        color: "#ee0f1317"
        border.width: 1
        border.color: pill.following ? "#6fb6ff" : "#3d7fd0"

        Rectangle {
            id: btn

            anchors.centerIn: parent
            width:  label.implicitWidth + 2 * Math.round(14 * pill.uiScale)
            height: Math.round(34 * pill.uiScale)
            radius: height / 2
            color: area.pressed     ? "#2f7fb5"
                 : pill.following   ? "#1f5f8f"
                 :                    "#1d3446"
            border.width: 1
            border.color: pill.following ? "#6fb6ff" : "#3d7fd0"

            Text {
                id: label
                anchors.centerIn: parent
                text: qsTr("Centre on boat")
                color: pill.following ? "#ffffff" : "#cfe0f2"
                font.pixelSize: Math.round(16 * pill.uiScale)
                font.bold: pill.following
            }

            MouseArea {
                id: area
                anchors.fill: parent
                // A little more than the drawn button: it is used from a moving boat.
                anchors.margins: -Math.round(6 * pill.uiScale)
                onClicked: pill.followRequested(!pill.following)
            }
        }
    }
}
