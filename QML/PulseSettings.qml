// PulseSettings.qml
pragma Singleton
import QtQuick 2.15
import Qt.labs.settings 1.1

Settings {
    id: pulseSettings

    property int    settingsVersion:            1       //This MUST be updated (+1) if we decide to change the default runtime values

    // User interface control settings
    property int    maxDepthValue:              15
    property int    maxDepthValuePulseBlue:     25
    property int    maxDepthValuePulseBlueFixed:35
    property bool   autoRange:                  false
    property bool   autoFilter:                 false
    property int    intensityDisplayValue:      10
    property int    intensityRealValue:         90
    property int    filterDisplayValue:         2
    property int    filterRealValue:            5
    property int    ecoViewIndex:               0
    property int    ecoConeIndex:               0
    property bool   useMetricValues:            true  //Not used anymore
    property bool   useMetricDepth:             true  //Metric split for depth and temperature
    property bool   useMetricTemperature:       true  //Metric split for depth and temperature
    property bool   showTemperatureInUi:        true
    property int    colorMapIndexSideScan:      0
    property int    colorMapIndex2D:            0
    property int    colorMapIndexReal:          0
    property bool   areUiControlsVisible:       true
    property int    bottomCompositionAddition:  0
    property bool   doubleEchoOptimize:         false

    // Transducer telemetry settings
    property bool   useEchogram:                true
    property bool   useDistance:                true
    property bool   transducerChangeDetected:   false
    property int    preferredBaudRate:          921600

    // Device dependent Settings
    property string devName:                    "pulseRed"
    property string userManualSetName:          "..."
    property string udpGateway:                 "192.168.10.1"
    property bool   useWifiLongRange:           false
    property int    udpPort:                    14560

    // NMEA settings
    property int    nmeaPort:                   3500
    property int    nmeaSendPerMilliSec:        250
    property bool   enableNmeaDbt:              true

    // Transducer installation settings
    property double transducerOffsetMount:      0.0   // Submerge measure, m (transducer below water surface)
    property bool   isSideScanOnLeftHandSide:   true  // important for catamaran as the other hull side will be visible in the down scan (used to chose side for downscan)
    property bool   isSideScanCableFacingFront: true  // true = cable up from device mounted front, false = cable up from device facing stern

    // Beta testers
    property string keyCode:                    "not_set"
    property bool   isBetaTester:               false
    property bool   isExpert:                   false

    // Experimental
    property bool   stopEchogramToConfigure:    false

    // NMEA signals to keep C++ in sync
    signal                                      settingsChanged()


    onNmeaPortChanged: {
        console.log("settingsChanged, triggered by onNmeaPortChanged")
        settingsChanged()
    }
    onNmeaSendPerMilliSecChanged: {
        console.log("settingsChanged, triggered by onNmeaSendPerMilliSecChanged")
        settingsChanged()
    }
    onEnableNmeaDbtChanged: {
        console.log("settingsChanged, triggered by onEnableNmeaDbtChanged")
        settingsChanged()
    }

    // Offset mount update to keep C++ in sync
    onTransducerOffsetMountChanged: {
        if (dataset) {
            dataset.updateTransducerOffset(transducerOffsetMount)
            console.log("onTransducerOffsetMountChanged, notified dataset")
        } else {
            console.log("onTransducerOffsetMountChanged, but dataset null")
        }
    }

    // Favorite color themes, for Pulse Red, maintains a subset of PulseRuntimeSettings.themeModelRed
    property    bool    useFavoriteThemes2D:    false
    property    var     favoriteThemes2DNew:    []

    function addFavorite2DNew(obj) {
        if (favoriteThemes2DNew.find(function(x){ return x.id === obj.id }))
            return

        var arr = favoriteThemes2DNew.concat([ obj ])
        var masterOrder = pulseRuntimeSettings.themeModelRed
                              .map(function(t) { return t.id })

        arr.sort(function(a, b) {
            return masterOrder.indexOf(a.id)
                 - masterOrder.indexOf(b.id)
        })

        favoriteThemes2DNew = arr
    }

    function removeFavorite2DNew(obj) {
        favoriteThemes2DNew = favoriteThemes2DNew.filter(function(x){
            return x.id !== obj.id
        })

        if (useFavoriteThemes2D && colorMapIndexReal === obj.id) {
            if (favoriteThemes2DNew.length > 0) {
                // pick the new first favorite
                var pick = favoriteThemes2DNew[0]
                colorMapIndexReal = pick.id
                // update the numeric index into the full master list
                for (var i = 0; i < pulseRuntimeSettings.themeModelRed.length; ++i) {
                    if (pulseRuntimeSettings.themeModelRed[i].id === pick.id) {
                        colorMapIndex2D = i
                        break
                    }
                }
            } else {
                // no favorites left → leave colorMapIndexReal alone?
                // or you could reset to default 0:
                // colorMapIndexReal = pulseRuntimeSettings.themeModelRed[0].id
                // colorMapIndex2D     = 0
            }
        }
    }

    Component.onCompleted: {
        favoriteThemes2DNew = favoriteThemes2DNew.map(function(x) {
            return typeof x === "string" ? parseInt(x, 10) : x
        })

    }


}
