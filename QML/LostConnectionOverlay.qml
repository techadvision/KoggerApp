// LostConnectionOverlay.qml
import QtQuick 2.15

Rectangle {
    id: lostConnectionOverlay
    //width: parent   // adjust or bind as needed
    //height: parent // adjust or bind as needed
    anchors.centerIn: parent
    width: 650
    height: 300
    color: "#30FF0000" // semi-transparent red (alpha ~53%)
    radius: 20         // rounded corners
    border.width: 0

    // Center the content
    Column {
        anchors.centerIn: parent
        spacing: 20

        // Spinner with partial arc and rotation animation
        Item {
            id: spinnerContainer
            width: 100
            height: 100
            rotation: 0
            anchors.horizontalCenter: parent.horizontalCenter

            Canvas {
                id: spinnerCanvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    ctx.beginPath()
                    // Draw an arc: starting at 0, covering 270°
                    var startAngle = 0
                    var endAngle = 270 * Math.PI / 180
                    // Center at (width/2, height/2) with a radius of 40
                    ctx.arc(width/2, height/2, 40, startAngle, endAngle, false)
                    ctx.lineWidth = 10
                    ctx.strokeStyle = "white"
                    ctx.stroke()
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            // Animate rotation: spins from 0° to 306° continuously
            NumberAnimation {
                target: spinnerContainer
                property: "rotation"
                from: 0
                to: 359
                duration: 3000  // duration in milliseconds (adjustable)
                loops: Animation.Infinite
                running: true
            }
        }

        // "Lost connection" text
        Text {
            text: "Lost connection"
            color: "white"
            font.pixelSize: 80
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }
    }
}

