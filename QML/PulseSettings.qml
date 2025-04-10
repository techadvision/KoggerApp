// PulseSettings.qml
pragma Singleton
import QtQuick 2.15
import Qt.labs.settings 1.1

Settings {
    id: pulseSettings

    property int    settingsVersion:            1       //This MUST be updated (+1) if we decide to change the default runtime values

    // User interface control settings
    property int    maxDepthValue:              15
    property bool   autoRange:                  false
    property bool   autoFilter:                 false
    property int    intensityDisplayValue:      10
    property int    intensityRealValue:         90
    property int    filterDisplayValue:         2
    property int    filterRealValue:            5
    property int    ecoViewIndex:               0
    property int    ecoConeIndex:               0
    property bool   useMetricValues:            true
    property int    colorMapIndexSideScan:      0
    property int    colorMapIndex2D:            0
    property int    colorMapIndexReal:          0
    property bool   areUiControlsVisible:       true

    // Transducer telemetry settings
    property bool   useEchogram:                true
    property bool   useDistance:                true
    property bool   transducerChangeDetected:   false

    // Device dependent Settings
    property string devName:                    "pulseRed"
    property string userManualSetName:          "..."
    property string udpGateway:                 "192.168.10.2"
    property bool   useWifiLongRange:           false

    // NMEA settings
    property int    nmeaPort:                   3500
    property int    nmeaSendPerMilliSec:        250
    property bool   enableNmeaDbt:              true

    // Signals
    signal                                      settingsChanged()
    onNmeaPortChanged:                          settingsChanged()
    onNmeaSendPerMilliSecChanged:               settingsChanged()
    onEnableNmeaDbtChanged:                     settingsChanged()
}
