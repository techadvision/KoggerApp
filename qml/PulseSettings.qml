// PulseSettings.qml
//pragma Singleton
import QtQuick 2.15
import Qt.labs.settings 1.1

Settings {
    id: pulseSettings

    //NOTE: nothing reads settingsVersion today — it is a marker, not a migration trigger.
    //Bumped to 2 on 2026-08-29 for the filterDisplayValue / filterRealValue default change.
    property int    settingsVersion:            2       //This MUST be updated (+1) if we decide to change the default runtime values

    //Token for the installation
    property string validateSalt:               ""

    // User interface control settings
    property int    maxDepthValue:              15
    property int    maxDepthValuePulseBlue:     25
    property int    maxDepthValuePulseBlueFixed:35
    property bool   autoRange:                  false
    //autoFilter is RETIRED (2026-08-29). Kept as a property only so an existing stored
    //"true" can be found and migrated away; nothing sets it back to true any more.
    property bool   autoFilter:                 false
    property int    intensityDisplayValue:      10
    property int    intensityRealValue:         90
    //Defaults raised 2 -> 8 (real 5 -> 20) on 2026-08-29, when the depth-driven auto
    //filter was retired: 8 is the value Olav found works well across the range with the
    //water body filter (real 20 -> strength 20/50 = 0.4). Qt.labs.settings only falls back
    //to a declared default when NOTHING is stored, so this affects fresh installs only —
    //anyone who has ever moved the filter slider keeps their own value.
    property int    filterDisplayValue:         8
    property int    filterRealValue:            20
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
    property double echogramSpeed:              1.0
    property double echogramWidth:              25
    property double pulseBlueOffset:            20

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
    property int    usbSerialBaud:              921600

    // NMEA settings
    property int    nmeaPort:                   3500
    property int    nmeaSendPerMilliSec:        250
    property bool   enableNmeaDbt:              true
    property bool   enableNmeaMtw:              false
    property int    nmeaTempPeriodMs:           1000
    property string nmeaBroadcastAddress:       "255.255.255.255"

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

    // Source of origin position and yaw
    property bool   positionSourceAutoPilot:    true
    property bool   positionSourceDeviceGps:    false
    property bool   positionSourceNmeaGps:      false


    // NMEA signals to keep C++ in sync
    /* No longer needed
    //signal                                      settingsChanged()


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
    */

    // Offset mount update to keep C++ in sync
    onTransducerOffsetMountChanged: {
        if (dataset) {
            dataset.setTransducerOffsetMount(transducerOffsetMount)
            console.log("onTransducerOffsetMountChanged, notified dataset")
        } else {
            console.log("onTransducerOffsetMountChanged, but dataset null")
        }
    }

    // Favorite color themes, for Pulse Red, maintains a subset of pulseRuntimeSettings.themeModelRed
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

        //ONE-SHOT MIGRATION: retire auto filtering.
        //
        //This belongs here rather than in main.qml because pulseSettings is created by its
        //own QQmlComponent in main.cpp BEFORE main.qml is loaded. main.qml's
        //Component.onCompleted fires AFTER its children have already seeded themselves from
        //the stored values, which would leave the filter slider showing the pre-migration
        //number while the filter itself had moved.
        //
        //STARTUP FINGERPRINT. Qt.labs.settings OVERWRITES a declared default with the
        //stored value whenever one exists, so settingsVersion is a reliable tell:
        //  prints 2 -> the store really was empty, these are the declared defaults
        //  prints 1 -> a settings file was present (restored backup, or a clear that did
        //              not actually remove it) and every value below is stored data
        //Added 2026-08-29 to settle where a fresh install's filter value comes from.
        console.log("SETTINGS: settingsVersion", settingsVersion,
                    "| filter display", filterDisplayValue, "real", filterRealValue,
                    "| autoFilter", autoFilter,
                    "| intensity display", intensityDisplayValue, "real", intensityRealValue)

        //Clear the retired flag and NOTHING ELSE. filterDisplayValue / filterRealValue are
        //written only by the slider's onSelectorValueChanged (Plot2D.qml) — never by
        //applyFiltering() or the old doAutoFilter() — so the stored pair is exactly the
        //last value the user set BY HAND before switching to auto. Turning auto off has
        //always restored it (onFilterFixedRangeRequested), and an upgrade must behave the
        //same way: the auto badge disappears and the user's own value comes back.
        //Overwriting them here would silently discard a preference the user still holds.
        //The 8 / 20 pair is the DEFAULT above, for installs that have never stored one.
        if (autoFilter) {
            console.log("AUTO FILTER: retired — clearing stored autoFilter; keeping the user's manual filter of",
                        filterDisplayValue, "(real", filterRealValue + ")")
            autoFilter = false
        }
    }


}
