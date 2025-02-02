import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.15

Item {
    id: depthAndTemperature
    width: 350
    height: 200
    clip: true

    property bool isMetric: pulseSettings.useMetricValues

    signal swapUnits()

    function formatDepth() {
        let depthInMeters = dataset.dist * 0.001; // Convert depth to meters
        let decimalPlaces = depthInMeters >= 100 ? 0 : (depthInMeters >= 10 ? 1 : 2);
        //let decimalPlaces = depthInMeters >= 10 ? 1 : 2; // Use 1 decimal if depth >= 10 meters, else 2 decimals

        return isMetric
            ? depthInMeters.toFixed(decimalPlaces) + ' m'
            : (depthInMeters * 3.28084).toFixed(decimalPlaces) + ' ft'; // Convert to feet if not metric
    }

    function formatTemperature() {
        console.log("TAV: Temperature raw:", dataset.temp)
        let temperatureInDegrees = dataset.temp;
        let temperatureInFarenheit = temperatureInDegrees * (9 / 2) + 32
        console.log("TAV: temperatureInFarenheit:", temperatureInFarenheit)
        let decimalPlacesTemp = 1;
        return isMetric
                ? Math.round(temperatureInDegrees * 10) / 10 + ' \u00B0C'
                : Math.round(temperatureInFarenheit * 10) / 10 + ' \u00B0F';
    }

    Rectangle {
        width: depthAndTemperature.width
        height: depthAndTemperature.height
        color: "transparent" // Use transparent for layout
        radius: parent.height / 2

        MouseArea {
            width: parent.width
            height: parent.height
            anchors.centerIn: parent
            onClicked: {
                depthAndTemperature.isMetric = !depthAndTemperature.isMetric
                pulseSettings.useMetricValues = depthAndTemperature.isMetric
                setMeasuresMetricNow(depthAndTemperature.isMetric)
            }
        }

        // Depth Value (Whole Number Part)
        Rectangle {
            id: wholeNumberRect
            width: parent.width * 0.65
            height: 96
            color: "#80000000"
            anchors.right: decimalPartRect.left
            anchors.bottom: decimalPartRect.bottom
            //anchors.right: parent.right
            //anchors.top: parent.top
            anchors.topMargin: 20

            Text {
                id: wholeNumber
                text: depthAndTemperature.formatDepth().split('.')[0] + "."
                color: "white"
                font.bold: true
                font.pixelSize: 96
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }

        }

        // Depth Value (Decimal Part)
        Rectangle {
            id: decimalPartRect
            width: parent.width * 0.2
            height: 96
            color: "#80000000"
            anchors.right: depthUnitRect.left
            //anchors.right: parent.right
            anchors.top: parent.top
            //anchors.top: wholeNumberRect.bottom
            anchors.topMargin: 10

            Text {
                id: decimalPart
                text: depthAndTemperature.formatDepth().split('.')[1] ? depthAndTemperature.formatDepth().split('.')[1].split(' ')[0] : ""
                color: "white"
                font.pixelSize: 72
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.top: parent.top
                //anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Unit (m or ft)
        Rectangle {
            id: depthUnitRect
            width: parent.width * 0.15
            height: 96
            color: "#80000000"
            anchors.right: parent.right
            anchors.top: parent.top
            //anchors.top: decimalPartRect.bottom
            anchors.topMargin: 10
            anchors.rightMargin: 50

            Text {
                id: depthUnit
                text: depthAndTemperature.formatDepth().split(' ')[1] // Extract the unit (m or ft)
                color: "white"
                font.pixelSize: 36
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 15
            }
        }

        // Temperature Value
        Rectangle {
            id: temperatureValueRect
            width: parent.width * 0.85
            height: 72
            color: "#80000000"
            anchors.right: temperatureUnitRect.left
            anchors.top: temperatureUnitRect.top
            //anchors.topMargin: 20

            Text {
                id: temperatureValue
                text: depthAndTemperature.formatTemperature().split(' ')[0] || "-.-"
                color: "white"
                font.pixelSize: 72
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Temperature Unit (°C or °F)
        Rectangle {
            id: temperatureUnitRect
            width: parent.width * 0.15
            height: 72
            color: "#80000000"
            anchors.right: depthUnitRect.right
            anchors.top: depthUnitRect.bottom
            anchors.topMargin: 20

            Text {
                id: temperatureUnit
                text: depthAndTemperature.formatTemperature().split(' ')[1] // Temperature unit
                color: "white"
                font.pixelSize: 36
                horizontalAlignment: Text.AlignLeft
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 15
            }
        }
    }

    Component.onCompleted: {
        setMeasuresMetricNow(pulseSettings.useMetricValues)
    }

}



