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
    //INTENSITY AND THE WATER BODY FILTER ARE PER-PICTURE FROM 15 Sept 2026, on Olav's
    //reasoning: "For red it is usually a focus on reading the colors of first and second
    //echo to determine hardness, while for blue it is more of a question to distinguish
    //variation of dullness/brightness in areas of the bottom render" - and a blue usually
    //has a lot less clutter in the water body to filter out in the first place.
    //
    //ONLY THE DISPLAY NUMBER SPLITS. The two Real values below are pure functions of it
    //(120 - v*4 and v*2.5) and are what goes onto the persistent bus and into
    //plot2D_echogram.cpp, so they keep that job and become THE SHARED APPLIED VALUE,
    //written by the applier - exactly the role colorMapIndexReal already has beside
    //colorMapIndex2D and colorMapIndexSideScan. Two new keys per control, not four.
    //
    //THE TWO LEGACY KEYS STAY. They are classic's sliders and they are the migration
    //source below. Do not delete them: they are somebody's settings file.
    //
    //-1 = NOT MIGRATED YET, the ecoViewId pattern. 0 is a legitimate value for both
    //controls, so it cannot be the sentinel.
    property int    intensityDisplayValue:      10      //LEGACY + classic; migration source
    property int    intensityDisplayValue2D:    -1      //red
    property int    intensityDisplayValueSideScan: -1   //blue
    property int    intensityRealValue:         90      //SHARED applied value, written by the applier
    //Defaults raised 2 -> 8 (real 5 -> 20) on 2026-08-29, when the depth-driven auto
    //filter was retired: 8 is the value Olav found works well across the range with the
    //water body filter (real 20 -> strength 20/50 = 0.4). Qt.labs.settings only falls back
    //to a declared default when NOTHING is stored, so this affects fresh installs only —
    //anyone who has ever moved the filter slider keeps their own value.
    property int    filterDisplayValue:         8       //LEGACY + classic; migration source
    property int    filterDisplayValue2D:       -1      //red
    property int    filterDisplayValueSideScan: -1      //blue
    property int    filterRealValue:            20      //SHARED applied value, written by the applier
    //THE VIEW AND CONE PREFERENCES, as stable entry ids (step 4, 2026-09-12).
    //
    //ecoViewIndex / ecoConeIndex stored a POSITION in the profile's ui.views / ui.cones
    //list. A position only means anything while the list it came from is unchanged, and
    //those lists are exactly what must be free to change: an expert-only 820 kHz view
    //appears and disappears with expert mode, hardware gets withdrawn, a new device brings
    //its own entries. The same stored number then quietly means a different view.
    //
    //The id strings below are what is read and written now. The two integers are KEPT,
    //read-only, purely so an existing install can be migrated once in Component.onCompleted
    //below - nothing writes them any more. Do not delete them: they are somebody's settings
    //file. An id is a promise; see the note on the profile entries in PulseRuntimeSettings.
    property string ecoViewId:                  ""      //"" = not migrated yet
    property string ecoConeId:                  ""      //"" = not migrated yet
    property int    ecoViewIndex:               0       //LEGACY, migration source only
    property int    ecoConeIndex:               0       //LEGACY, migration source only
    //THE SCREEN PREFERENCE (Stage 4 b, the screen chooser). What the screen shows, as one
    //of the ids in pulseRuntimeSettings.screenViewsAll.
    //
    //PERSISTED, NOT RUNTIME, and that is the whole reason it lives here beside the view and
    //cone ids rather than in pulseRuntimeSettings with the live parameter state. A screen
    //layout is exactly the kind of thing a user sets once for how they work and expects to
    //find again next season - the opposite of an expert's sample-count experiment, which is
    //meant to be forgotten at every app start.
    property string screenViewId:               ""      //"" = not migrated yet
    property bool   useMetricValues:            true  //Not used anymore
    property bool   useMetricDepth:             true  //Metric split for depth and temperature
    property bool   useMetricTemperature:       true  //Metric split for depth and temperature
    property bool   showTemperatureInUi:        true
    property int    colorMapIndexSideScan:      0
    property int    colorMapIndex2D:            0
    property int    colorMapIndexReal:          0
    property bool   areUiControlsVisible:       true
    //UI VARIANT (Stage 2, docs/pulse-ui/pulse-ui-strategy.md). "classic" is the UI that
    //ships today; "v2" is the new one being built. PulseApp.qml resolves anything it does
    //not recognise back to classic, so a value written by a future build or a half-finished
    //experiment can never start the app without an interface. Persisted on purpose: a
    //comparison on the water has to survive the app being closed between runs.
    property string uiVariant:                  "classic"
    //AN EXPERT STARTS IN V2, ONCE. "classic" above stays the declared default, because it
    //is still what an ordinary user should meet; an expert is someone who has typed a key
    //code, and the v2 interface is what they are here to test.
    //
    //A SEED, NOT AN OVERRIDE, and the flag is the whole difference. It fires once per
    //install - the first start of a build that has this, or the moment a key code is
    //accepted - and never again, so an expert who goes back to classic in the Experimental
    //row STAYS in classic. An override would drag them back to v2 on every start and there
    //would be no way to say no that survived a restart.
    property bool   uiVariantSeededForExpert:   false
    //THE RAIL IS COLLAPSED. Direction C's "minimise promoted to a proper collapse
    //affordance", which the canvas kept as worth borrowing. Its own key rather than
    //areUiControlsVisible: that one hides the classic quick controls, and one value
    //driving two different interfaces is how a user ends up in classic wondering where
    //his controls went.
    property bool   v2RailCollapsed:            false
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

    //Two triggers, one body: the entitlement may already be stored when this object is
    //built, in which case onIsExpertChanged never fires, or it may arrive later when a key
    //code is accepted, in which case Component.onCompleted has been and gone. Neither
    //trigger alone covers both, and a seed that runs twice is harmless because the flag
    //stops the second one.
    function seedUiVariantForExpert() {
        if (uiVariantSeededForExpert || !isExpert)
            return
        console.log("SETTINGS: expert entitlement - starting in the v2 interface (was",
                    uiVariant + "); the Experimental row is the way back, and this is asked once")
        uiVariant = "v2"
        uiVariantSeededForExpert = true
    }

    onIsExpertChanged: seedUiVariantForExpert()

    Component.onCompleted: {
        seedUiVariantForExpert()

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

        //ONE-SHOT MIGRATION: the single intensity / filter preference -> one per picture.
        //
        //BOTH MODELS INHERIT THE VALUE THE USER ALREADY HAS, on Olav's answer, so nothing
        //moves on the first build and it is a clean test of whether the SPLIT works rather
        //than of new numbers. The moment either slider is touched the two part company.
        //
        //Safe to run on every start: it writes only while the key is still -1, and what it
        //writes comes from the user's own stored value rather than from a constant here, so
        //the two cannot drift apart. A fresh install has never stored anything, so the
        //legacy key is still its declared default and both new keys inherit that.
        if (intensityDisplayValue2D < 0 || intensityDisplayValueSideScan < 0) {
            console.log("SETTINGS: splitting intensity per picture - both seeded from",
                        intensityDisplayValue)
            if (intensityDisplayValue2D < 0)       intensityDisplayValue2D       = intensityDisplayValue
            if (intensityDisplayValueSideScan < 0) intensityDisplayValueSideScan = intensityDisplayValue
        }
        if (filterDisplayValue2D < 0 || filterDisplayValueSideScan < 0) {
            console.log("SETTINGS: splitting the water body filter per picture - both seeded from",
                        filterDisplayValue)
            if (filterDisplayValue2D < 0)       filterDisplayValue2D       = filterDisplayValue
            if (filterDisplayValueSideScan < 0) filterDisplayValueSideScan = filterDisplayValue
        }

        //ONE-SHOT MIGRATION: positional view/cone preference -> stable entry id.
        //
        //Safe to run on every start: it only ever writes when the id is still empty, and
        //the value it writes comes from the profile's own list rather than from a constant
        //here, so the two cannot drift apart. A fresh install has ecoViewIndex 0 and lands
        //on the first entry, which is the declared default either way.
        //
        //This is in PulseSettings for the same reason the auto-filter migration is: main.cpp
        //creates pulseRuntimeSettings BEFORE this object and main.qml after both, so this is
        //the earliest point where the profiles are readable and still before any chooser has
        //seeded itself from the stored value.
        if (typeof pulseRuntimeSettings !== "undefined" && pulseRuntimeSettings !== null) {
            var vId = pulseRuntimeSettings.migrateViewId(ecoViewId, ecoViewIndex)
            if (vId !== "") {
                console.log("SETTINGS: migrating ecoViewIndex", ecoViewIndex, "-> ecoViewId", vId)
                ecoViewId = vId
            }
            var cId = pulseRuntimeSettings.migrateConeId(ecoConeId, ecoConeIndex)
            if (cId !== "") {
                console.log("SETTINGS: migrating ecoConeIndex", ecoConeIndex, "-> ecoConeId", cId)
                ecoConeId = cId
            }

            //AND ONWARD to the screen preference, which is migrated from the view id the
            //two lines above have just settled - so the order here matters and a user who
            //was looking at side scan opens on side scan rather than on the first entry.
            var sId = pulseRuntimeSettings.migrateScreenId(screenViewId, ecoViewId, ecoViewIndex)
            if (sId !== "") {
                console.log("SETTINGS: migrating view", ecoViewId === "" ? ecoViewIndex : ecoViewId,
                            "-> screenViewId", sId)
                screenViewId = sId
            }
        } else {
            //Never expected — pulseRuntimeSettings is published first. Say so rather than
            //failing silently, because the ids would then stay empty and every chooser
            //would fall back to its first entry.
            console.log("SETTINGS: pulseRuntimeSettings not reachable, view/cone id migration SKIPPED")
        }
    }


}
