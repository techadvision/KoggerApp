import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
//import QtGraphicalEffects 1.15
import Echo.UI 1.0
import QtQuick.Window


// THE CLASSIC DEPTH AND TEMPERATURE READOUT.
//
// THE ENGINE THAT USED TO LIVE HERE IS GONE - see PulseDepthEngine.qml. This file was 640
// lines of which only the last 200 drew anything; the rest took the depth off the dataset,
// ran the auto display level and computed the dynamic resolution that DeviceItem turns into
// chartSamples and ch1Period on the transducer. All of that was reachable only by
// instantiating this readout, which PulseAppV2 does not do - so in v2 nothing wrote those
// keys at all. It is one instance above both panes now, and this file reads the one key it
// publishes.
//
// Everything below is the readout exactly as it was.

Item {
    id: depthAndTemperature

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real platformScale: _isAndroid ? 0.9 : 0.75
    //readonly property real s: Ui.scale * platformScale
    readonly property real shortSide: Math.min(Screen.width, Screen.height)
    readonly property real s: Math.max(1.0, shortSide / 1100)

    // Base “design” size for this control on your 10" tablet
    readonly property int baseWidth: 350
    readonly property int baseHeight: 200

    // Natural size for layouts

    implicitWidth:  Math.round(baseWidth  * s)
    implicitHeight: Math.round(baseHeight * s)

    // Good defaults when NOT inside a layout
    width:  Math.round(baseWidth  * s)
    height: Math.round(baseHeight * s)
    clip: true

    /*
    width: _isAndroid ? 350 : 230
    height: _isAndroid ? 200 : 140
    clip: true

    property int fontPixelsBase:        96
    property int fontPixelsDepthInt:    96
    property int fontPixelsDepthDec:    72
    property int fontPixelsDepthUnit:   33
    property int fontPixelsTempInt:     72
    property int fontPixelsTempDec:     72
    property int fontPixelsTempUnit:    33
    */
    property int fontPixelsBase:        104
    property int fontPixelsDepthInt:    Math.round(fontPixelsBase * s)
    property int fontPixelsDepthDec:    Math.round(fontPixelsBase * s * 0.75)
    property int fontPixelsDepthUnit:   Math.round(fontPixelsBase * s * 0.33)
    property int fontPixelsTempInt:     Math.round(fontPixelsBase * s * 0.75)
    property int fontPixelsTempDec:     Math.round(fontPixelsBase * s * 0.50)
    property int fontPixelsTempUnit:    Math.round(fontPixelsBase * s * 0.33)


    property bool   dataAvailable:              false
    property bool   isMetric:                   pulseSettings.useMetricDepth
    property bool   isMetricTemperature:        pulseSettings.useMetricTemperature
    property bool   userShowTemperature:        pulseSettings.showTemperatureInUi
    property int    datasetUpdatedCounter:      0
    property string tempText:                   "-.-"
    property string depthText:                  "-.-"
    //useTemperature is already a profile key and is what this actually meant - a device
    //either has a temperature sensor or it does not. Same answer today (red true, blue
    //false), but it stops being a guess derived from the transducer geometry.
    property bool   enableTemperature:          pulseRuntimeSettings.useTemperature && pulseRuntimeSettings.pulseBetaName === "..."

    signal swapUnits()
    //signal pulseAutoLevelChanged(int newAutoLevel)

    // THE DEPTH THE ENGINE CHOSE. The bottom-track-first rule and the NaN filter live in
    // PulseDepthEngine.qml, one instance above both panes, so this readout and the v2 one
    // cannot disagree about which source they are showing.
    function currentDepthValue() {
        return pulseRuntimeSettings ? pulseRuntimeSettings.depthMeters : 0
    }

    function formatDepth() {
        //let depthInMeters = (dataset !== null) ? dataset.dist : 0
        let depthInMeters = currentDepthValue()
        let decimalPlaces = 1;

        return isMetric
            ? depthInMeters.toFixed(decimalPlaces) + ' m'
            : (depthInMeters * 3.28084).toFixed(decimalPlaces) + ' ft'; // Convert to feet if not metric
    }

    function formatTemperature() {
        if (!dataset) {
            return isMetricTemperature
              ? "0.0 °C"
              : "32.0 °F";
        }

        let tempC = dataset.temp;

        const tempF = tempC * (9/5) + 32;
        const value = isMetricTemperature ? tempC : tempF;

        return `${value.toFixed(1)} °${isMetricTemperature ? "C" : "F"}`;
    }

    property string displayDepth: depthAndTemperature.formatDepth()

    Timer {
        id: displayDepthTimer
        interval: {
            return 250
        }
        repeat: true
        running: true
        onTriggered: {
            // Only refresh when the current depth is a real number; otherwise keep the last
            // good displayDepth so the UI never shows "NaN".
            if (Number.isFinite(depthAndTemperature.currentDepthValue())) {
                displayDepth = depthAndTemperature.formatDepth()
            }
        }
    }

    property string displayTemp: depthAndTemperature.formatTemperature()

    Timer {
        id: displayTempTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            // Only refresh when temperature is a real number; otherwise keep the last good
            // value so the UI never shows "NaN".
            if (dataset && Number.isFinite(dataset.temp)) {
                tempText = depthAndTemperature
                               .formatTemperature()
                               .split(" ")[0] || "-.-";
            }
        }
    }


    Rectangle {
        id: depthTempRect
        width: depthAndTemperature.width
        height: depthAndTemperature.height
        color: "transparent"
        radius: parent.height / 2

        // CATCH‐ALL MOUSEAREA – blocks clicks from passing through to the pinch
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: false
            preventStealing: true
            onPressed: { /* nothing – absorb */ }
        }


        // Property to count the taps
        property int tapCount: 0


        // Depth Value (Whole Number Part)
        Rectangle {
            id: wholeNumberRect
            width: parent.width * 0.75
            //height: _isAndroid? 96 : 64
            height: depthAndTemperature.fontPixelsDepthInt
            color: "transparent"
            //color: "#80000000"
            anchors.right: decimalPartRect.left
            anchors.bottom: decimalPartRect.bottom
            anchors.topMargin: 20

            Text {
                id: wholeNumber
                text: displayDepth.split('.')[0] + "."
                //text: depthAndTemperature.formatDepth().split('.')[0] + "."
                color: "white"
                style: Text.Outline            // 1px outline
                styleColor: "black"            // outline color
                renderType: Text.NativeRendering  // crisper on many platforms
                font.bold: true
                //font.pixelSize: _isAndroid ? 96 : 64
                font.pixelSize: depthAndTemperature.fontPixelsDepthInt
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }

        }

        // Depth Value (Decimal Part)
        Rectangle {
            id: decimalPartRect
            width: parent.width * 0.1
            //height: _isAndroid? 96 : 64
            height: depthAndTemperature.fontPixelsDepthInt
            color: "transparent"
            //color: "#80000000"
            anchors.right: depthUnitRect.left
            anchors.top: parent.top
            anchors.topMargin: 10

            Text {
                id: decimalPart
                text: {
                    var parts = displayDepth.split('.');
                    return parts[1] ? parts[1].split(' ')[0] : "";
                }
                //text: depthAndTemperature.formatDepth().split('.')[1] ? depthAndTemperature.formatDepth().split('.')[1].split(' ')[0] : ""
                color: "white"
                style: Text.Outline            // 1px outline
                styleColor: "black"            // outline color
                renderType: Text.NativeRendering  // crisper on many platforms
                //font.pixelSize: _isAndroid ? 72 : 48
                font.pixelSize: depthAndTemperature.fontPixelsDepthDec
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.top: parent.top
            }
        }

        // Unit (m or ft)
        Rectangle {
            id: depthUnitRect
            width: parent.width * 0.15
            //height: _isAndroid ? 96 : 64
            height: depthAndTemperature.fontPixelsDepthInt
            color: "transparent"
            //color: "#80000000"
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.rightMargin: 50

            Text {
                id: depthUnit
                text: displayDepth.split(' ')[1] // Extract the unit (m or ft)
                color: "white"
                style: Text.Outline            // 1px outline
                styleColor: "black"            // outline color
                renderType: Text.NativeRendering  // crisper on many platforms
                //font.pixelSize: _isAndroid ? 36 : 24
                font.pixelSize: depthAndTemperature.fontPixelsDepthUnit
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 15
            }
        }

        // Temperature Value
        Rectangle {
            id: temperatureValueRect
            width: parent.width * 0.73
            //height: _isAndroid ? 72 : 48
            height: depthAndTemperature.fontPixelsTempInt
            color: "transparent"
            anchors.right: decimalTempPartRect.left
            anchors.top: decimalTempPartRect.top
            //anchors.topMargin: 10
            visible: pulseRuntimeSettings.useTemperature && enableTemperature && userShowTemperature

            Text {
                id: temperatureValue
                //text: tempText
                text: tempText.split('.')[0] + "."
                color: "white"
                style: Text.Outline            // 1px outline
                styleColor: "black"            // outline color
                renderType: Text.NativeRendering  // crisper on many platforms
                //font.pixelSize: _isAndroid ? 72 : 48
                font.pixelSize: depthAndTemperature.fontPixelsTempInt
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Temperature Value (Decimal Part)
        Rectangle {
            id: decimalTempPartRect
            width: parent.width * 0.12
            //height: _isAndroid? 96 : 64
            height: depthAndTemperature.fontPixelsDepthInt
            color: "transparent"
            //color: "#80000000"
            anchors.right: temperatureUnitRect.left
            anchors.top: depthUnitRect.bottom
            anchors.topMargin: 10
            visible: pulseRuntimeSettings.useTemperature && enableTemperature && userShowTemperature

            Text {
                id: decimalTempPart
                text: {
                    var parts = tempText.split('.');
                    return parts[1] ? parts[1].split(' ')[0] : "";
                }
                //text: depthAndTemperature.formatDepth().split('.')[1] ? depthAndTemperature.formatDepth().split('.')[1].split(' ')[0] : ""
                color: "white"
                style: Text.Outline            // 1px outline
                styleColor: "black"            // outline color
                renderType: Text.NativeRendering  // crisper on many platforms
                //font.pixelSize: _isAndroid ? 72 : 48
                font.pixelSize: depthAndTemperature.fontPixelsTempDec
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                anchors.top: parent.top
            }
        }

        // Temperature Unit (°C or °F)
        Rectangle {
            id: temperatureUnitRect
            width: parent.width * 0.15
            //height: _isAndroid ? 72 :
            height: depthAndTemperature.fontPixelsTempUnit
            color: "transparent"
            //color: "#80000000"
            anchors.right: depthUnitRect.right
            anchors.top: depthUnitRect.bottom
            anchors.topMargin: 10
            visible: pulseRuntimeSettings.useTemperature && enableTemperature && userShowTemperature

            Text {
                id: temperatureUnit
                text: depthAndTemperature.formatTemperature().split(' ')[1] // Temperature unit
                color: "white"
                style: Text.Outline            // 1px outline
                styleColor: "black"            // outline color
                renderType: Text.NativeRendering  // crisper on many platforms
                //font.pixelSize: _isAndroid ? 36 : 24
                font.pixelSize: depthAndTemperature.fontPixelsTempUnit
                horizontalAlignment: Text.AlignLeft
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 15
            }
        }
    }

}



