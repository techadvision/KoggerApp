// PulseSpinner.qml
import QtQuick 2.15

Item {
    id: spinner
    width: 18
    height: 18
    //anchors.horizontalCenter: parent.horizontalCenter
    transformOrigin: Item.Center   // rotate around center

    // Customization
    property color strokeColor: "black"
    property real arcDegrees: 270
    property int lineWidth: 4
    property int radius: Math.min(width, height) / 2 - lineWidth

    Canvas {
        id: spinnerCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            ctx.beginPath()

            var startAngle = 0
            var endAngle = spinner.arcDegrees * Math.PI / 180

            ctx.arc(spinner.width / 2,
                    spinner.height / 2,
                    spinner.radius,
                    startAngle,
                    endAngle,
                    false)

            ctx.lineWidth = spinner.lineWidth
            ctx.strokeStyle = spinner.strokeColor
            ctx.stroke()
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    // Nice, self-contained animation
    /*
    NumberAnimation on rotation {
        from: 0
        to: 359
        duration: 1500
        loops: Animation.Infinite
        running: visible    // spin whenever this PulseSpinner is visible
    }
    */
    NumberAnimation {
        target: spinner
        property: "rotation"
        from: 0
        to: 359
        duration: 1500  // duration in milliseconds (adjustable)
        loops: Animation.Infinite
        running: true
    }
}
