// PulseSettings.qml
pragma Singleton
import QtQuick 2.15
import Qt.labs.settings 1.1

Settings {
    id: pulseSettings

    // User interface control settings
    property int    maxDepthValue:              15
    property bool   autoRange:                  false
    property int    intensityDisplayValue:      10
    property int    intensityRealValue:         90
    property int    filterDisplayValue:         2
    property int    filterRealValue:            5
    property int    colorMapIndex:              0
    property int    ecoViewIndex:               0
    property int    ecoConeIndex:               0
    property bool   useMetricValues:            true

    // Transducer settings
    property bool   useEchogram:                true
    property bool   useDistance:                true
    property bool   useTemperature:             true
    property bool   is2DTransducer:             true
    property bool   transducerChangeDetected:   false
}
