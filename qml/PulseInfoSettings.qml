import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Echo.UI 1.0
//import NMEASender 1.0
import QtQuick.Window


Flickable {
    id: settingsPopup

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real platformScale: _isAndroid ? 0.9 : 0.75
    //readonly property real s: Ui.scale * platformScale
    readonly property real shortSide: Math.min(Screen.width, Screen.height)
    readonly property real s: Math.max(1.0, shortSide / 1100) // tune 800 to your “10-inch baseline”

    // Platform related sizes
    property int controlIconSize: Math.round(24 * s)
    property int pressButtonSize: Math.round(56 * s)
    property int displayPixels:   Math.round(60 * s)
    property int valueTextWidth:  Math.round(60 * s)
    property int valueTextHeigh:  Math.round(40 * s)
    property int valuePixels:     Math.round(42 * s)
    property int autoPixels:      Math.round(32 * s)
    property int selectIconSize:  Math.round(64 * s)
    property int selectCheckSize: Math.round(48 * s)

    /*
    property int controlIconSize: _isAndroid ? 34 : 20
    property int pressButtonSize: _isAndroid ? 80 : 40
    property int displayPixels:   _isAndroid ? 100 : 40
    property int valueTextWidth:  _isAndroid ? 60 : 40
    property int valueTextHeigh:  _isAndroid ? 40 : 30
    property int valuePixels:     _isAndroid ? 42 : 32
    property int autoPixels:      _isAndroid ? 32 : 24
    property int selectIconSize:  _isAndroid ? 80 : 60
    property int selectCheckSize: _isAndroid ? 56 : 40
    property int infoPixelsSize:  _isAndroid ? 32 : 22
    */

    focus: true
    width: Math.round(600 * s) //_isAndroid ? 900 : 600

    anchors.fill: parent
    flickableDirection: Flickable.VerticalFlick

    // Scrollbar always visible
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AlwaysOn
        width: Math.round(16 * s) //_isAndroid ? 16 : 12
    }

    //color: "white"
    //radius: 8
    //implicitWidth:  layout.implicitWidth
    //implicitHeight: layout.implicitHeight + spacer.height

    contentWidth: width
    contentHeight: contentItem.childrenRect.height

    signal pulsePreferenceClosed()
    signal pulsePreferenceValueChanged(double newValue)
    //signal stateChanged(bool checked)

    Rectangle{
        id: spacer
        width: Math.round(600 * s) //settingsPopup._isAndroid ? 900 : 600
        height: Math.round(20 * s) //settingsPopup._isAndroid ? 20 : 13
    }

    ColumnLayout {
        spacing: Math.round(20 * s) //settingsPopup._isAndroid ? 20 : 13
        anchors.top: spacer.bottom

        //Category: Screen related settings

        SettingRow {
            toggle: true
            text: "Screen / echogram settings"
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatScreen"
                initialValue: pulseRuntimeSettings.showCatScreen
            }
        }

        SettingRow {
            toggle: false
            checkbox: true
            text: pulseSettings.useMetricDepth ? "Metric depth (checked)" : "Imperial depth (unchecked)"
            show: pulseRuntimeSettings.showCatScreen
            SettingsCheckBox {
                target: pulseSettings ? pulseSettings : undefined
                targetPropertyName: "useMetricDepth"
                initialChecked: pulseSettings.useMetricDepth
            }

        }

        SettingRow {
            toggle: false
            checkbox: true
            text: "Display temperature on screen"
            show: pulseRuntimeSettings.showCatScreen && pulseRuntimeSettings.useTemperature
            SettingsCheckBox {
                target: pulseSettings ? pulseSettings : undefined
                targetPropertyName: "showTemperatureInUi"
                initialChecked: pulseSettings.showTemperatureInUi
            }
        }

        SettingRow {
            toggle: false
            checkbox: true
            text: pulseSettings.useMetricTemperature ? "Metric temperature (checked)" : "Imperial temperature (unchecked)"
            show: pulseRuntimeSettings.showCatScreen && pulseRuntimeSettings.useTemperature && pulseSettings.showTemperatureInUi
            SettingsCheckBox {
                target: pulseSettings ? pulseSettings : undefined
                targetPropertyName: "useMetricTemperature"
                initialChecked: pulseSettings.useMetricTemperature
            }
        }

        SettingRow {
            toggle: false
            checkbox: true
            text: "Optimize to include second echo"
            show: pulseRuntimeSettings.showCatScreen && pulseRuntimeSettings.is2DTransducer
            SettingsCheckBox {
                target: pulseSettings ? pulseSettings : undefined
                targetPropertyName: "doubleEchoOptimize"
                initialChecked: pulseSettings.doubleEchoOptimize
            }
        }

        SettingRow {
            toggle: false
            text: "2D echogram screen speed (1-5)"
            show: pulseRuntimeSettings.showCatScreen && pulseRuntimeSettings.is2DTransducer
            HorizontalControllerDoubleSettings {
                id: speedSelector
                values: [1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9,
                    2.0, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9,
                    3.0, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9,
                    4.0, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 5.0]
                height: 80
                Layout.preferredWidth: 280
                Component.onCompleted: {
                    var idx = values.indexOf(pulseSettings.echogramSpeed)
                    //console.log("pulseSettingssValue speedSelector Component.onCompleted idx calculated to ", idx)
                    currentIndex = idx >= 0 ? idx : 0
                }

                /*
                onPulsePreferenceValueChanged: {
                    //console.log("pulseSettingsValue speedSelector changed to", newValue)
                    pulseSettings.echogramSpeed = newValue
                }
                */
                onPulsePreferenceValueChanged: function(newValue) {
                    pulseRuntimeSettings.echogramSpeed = newValue
                }

                Connections {
                    target: pulseSettings ? pulseSettings : undefined
                    function onEchogramSpeedChanged () {
                        var idx = speedSelector.values.indexOf(pulseSettings.echogramSpeed)
                        if (idx >= 0) speedSelector.currentIndex = idx
                    }
                }
            }
        }

        SettingRow {
            toggle: false
            text: "Side-/downscan meters"
            show: pulseRuntimeSettings.showCatScreen && !pulseRuntimeSettings.is2DTransducer
            HorizontalControllerDoubleSettings {
                id: widthSelector
                values: [25, 35]
                height: 80
                Layout.preferredWidth: 280
                Component.onCompleted: {
                    var idx = values.indexOf(pulseSettings.echogramWidth)
                    //console.log("pulseSettingssValue speedSelector Component.onCompleted idx calculated to ", idx)
                    currentIndex = idx >= 0 ? idx : 0
                }

                onPulsePreferenceValueChanged: {
                    //console.log("pulseSettingsValue speedSelector changed to", newValue)
                    pulseSettings.echogramWidth = newValue
                }

                Connections {
                    target: pulseSettings ? pulseSettings : undefined
                    function onEchogramWidthChanged () {
                        var idx = widthSelector.values.indexOf(pulseSettings.echogramWidth)
                        if (idx >= 0) widthSelector.currentIndex = idx
                    }
                }
            }
        }

        /*
        SettingRow {
            toggle: false
            text: "Sidescan mid lines removal"
            show: pulseRuntimeSettings.showCatScreen && !pulseRuntimeSettings.is2DTransducer
            HorizontalControllerDoubleSettings {
                id: noiseKillSelector
                values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
                        11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
                        21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
                height: 80
                Layout.preferredWidth: 280
                Component.onCompleted: {
                    var idx = values.indexOf(pulseSettings.pulseBlueOffset)
                    currentIndex = idx >= 0 ? idx : 0
                }

                onPulsePreferenceValueChanged: {
                    //console.log("pulseSettingsValue speedSelector changed to", newValue)
                    pulseSettings.pulseBlueOffset = newValue
                }

                Connections {
                    target: pulseSettings ? pulseSettings : undefined
                    function onPulseBlueOffsethanged () {
                        var idx = noiseKillSelector.values.indexOf(pulseSettings.pulseBlueOffset)
                        if (idx >= 0) noiseKillSelector.currentIndex = idx
                    }
                }
            }
        }
        */

        //Category: NMEA

        SettingRow {
            toggle: true
            text: "NMEA Server"
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatNmea"
                initialValue: pulseRuntimeSettings.showCatNmea
            }
        }

        SettingRow {
            checkbox: true
            text: "Enable UDP NMEA server"
            show: pulseRuntimeSettings.showCatNmea
            SettingsCheckBox {
                target: pulseSettings ? pulseSettings : undefined
                targetPropertyName: "enableNmeaDbt"
                initialChecked: pulseSettings.enableNmeaDbt
            }

        }

        SettingRow {
            checkbox: true
            text: "Include MTW (temperature) message"
            show: pulseRuntimeSettings.showCatNmea
            SettingsCheckBox {
                target: pulseSettings ? pulseSettings : undefined
                targetPropertyName: "enableNmeaMtw"
                initialChecked: pulseSettings.enableNmeaMtw
            }

        }

        SettingRow {
            text: "DBT message interval ms"
            show: pulseRuntimeSettings.showCatNmea
            HorizontalControllerDoubleSettings {
                id: nmeaMessageInterval
                height: 80
                Layout.preferredWidth: 280

                values: [250, 500, 1000]

                Component.onCompleted: {
                    var idx = values.indexOf(pulseSettings.nmeaSendPerMilliSec)
                    currentIndex = idx >= 0 ? idx : 0
                }

                onPulsePreferenceValueChanged: {
                    pulseSettings.nmeaSendPerMilliSec = newValue
                }
            }
        }

        SettingRow {
            text: "NMEA send to UDP port"
            show: pulseRuntimeSettings.showCatNmea
            HorizontalControllerDoubleSettings {
                id: nmeaMessageToPort
                height: 80
                Layout.preferredWidth: 280

                values: [3000, 3100, 3200, 3300, 3400, 3500]

                Component.onCompleted: {
                    var idx = values.indexOf(pulseSettings.nmeaPort)
                    currentIndex = idx >= 0 ? idx : 0
                }

                onPulsePreferenceValueChanged: function(newValue) {
                    pulseSettings.nmeaPort = newValue
                }
            }
        }

        SettingRow {
            text: "NMEA send to IP"
            show: pulseRuntimeSettings.showCatNmea
            Text {
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                horizontalAlignment: Text.AlignLeft
                text: "255.255.255.255 "
                font.pixelSize: Ui.fontL //settingsPopup.infoPixelsSize
                color: "gray"

                //height: Math.round(54 * s) //settingsPopup._isAndroid ? 80 : 54
                //Layout.preferredWidth: Math.round(280 * s) //settingsPopup._isAndroid ? 280 : 190
            }
        }

        //Category: Position integration
        SettingRow {
            toggle: true
            text: "Positioning source"
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatPositionSource"
                initialValue: pulseRuntimeSettings.showCatPositionSource
            }
        }

        SettingRow {
            text: "Autopilot position"
            beta: true
            checkbox: true
            show: pulseRuntimeSettings.showCatPositionSource
            SettingsCheckBox {
                target: pulseSettings ? pulseSettings : undefined
                targetPropertyName: "positionSourceAutoPilot"
                initialChecked: pulseSettings.positionSourceAutoPilot
            }
            Connections {
                target: pulseSettings ? pulseSettings : undefined
                function onPositionSourceAutoPilotChanged() {
                    if (pulseSettings == null)
                        return
                    if (pulseSettings.positionSourceAutoPilot) {
                        pulseSettings.positionSourceNmeaGps = false
                        pulseSettings.positionSourceDeviceGps = false
                    }
                }
            }

        }

        //Category: Installation

        SettingRow {
            toggle: true
            text: "Installation related settings"
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatInstallation"
                initialValue: pulseRuntimeSettings.showCatInstallation
            }
        }

        SettingRow {
            text: "Transducer beneath water surface (m)"
            show: pulseRuntimeSettings.showCatInstallation
            HorizontalControllerMinMaxSettings {
                id: transducerSubmergedMeasure
                minimum: 0.0
                maximum: 10.0
                stepSize: 0.01
                //currentValue: pulseSettings.transducerOffsetMount
                onPulsePreferenceValueChanged: {
                    console.log("transducerOffsetMount updated to", newValue)
                    pulseSettings.transducerOffsetMount = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    // If your singleton already has a value, pick that up,
                    // otherwise fall back to your minimum.
                    if (typeof pulseSettings.transducerOffsetMount === "number") {
                        currentValue = pulseSettings.transducerOffsetMount
                        console.log("transducerOffsetMount from preferences used as current:", currentValue)
                    } else {
                        currentValue = minimum
                        console.log("transducerOffsetMount not a number, setting current to", minimum)
                    }
                }
            }

        }

        SettingRow {
            text: "PULSEblue: Left-hand side mount"
            toggle: false
            checkbox: true
            show: pulseRuntimeSettings.showCatInstallation && !pulseRuntimeSettings.is2DTransducer
            SettingsCheckBox {
                target: pulseSettings ? pulseSettings : undefined
                targetPropertyName: "isSideScanOnLeftHandSide"
                initialChecked: pulseSettings.isSideScanOnLeftHandSide
            }

            Connections {
                target: pulseSettings ? pulseSettings : undefined
                function onIsSideScanOnLeftHandSideChanged() {
                    pulseRuntimeSettings.isSideScanLeftHand = pulseSettings.isSideScanOnLeftHandSide
                    console.log("DEVICE_INSTALLATION: pulseRuntimeSettings.isSideScanLeftHand new value", pulseRuntimeSettings.isSideScanLeftHand)
                }
            }
        }

        SettingRow {
            text: "PULSEblue: Cable facing front"
            toggle: false
            checkbox: true
            show: pulseRuntimeSettings.showCatInstallation && !pulseRuntimeSettings.is2DTransducer
            SettingsCheckBox {
                target: pulseSettings ? pulseSettings : undefined
                targetPropertyName: "isSideScanCableFacingFront"
                initialChecked: pulseSettings.isSideScanCableFacingFront
            }
        }

        SettingRow {
            text: "Pulse Wi-Fi Server UDP port"
            toggle: false
            show: pulseRuntimeSettings.showCatInstallation && (pulseRuntimeSettings.expertMode || pulseRuntimeSettings.betaMode)
            HorizontalControllerDoubleSettings {
                id: udpPortSelection
                values: [14550, 14560]
                //onPulsePreferenceValueChanged: pulseSettings.udpPort = newValue
                onPulsePreferenceValueChanged: function(newValue) {
                    pulseSettings.udpPort = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(pulseSettings.udpPort)
                    currentIndex = idx >= 0 ? idx : 0
                }
            }
        }

        //category: Beta testers:

        SettingRow {
            toggle: true
            id: betaTesters
            text: "For beta testers only"
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatBetaTesters"
                initialValue: pulseRuntimeSettings.showCatBetaTesters
            }
        }

        SettingRow {
            text: "My beta test key code"
            show: pulseRuntimeSettings.showCatBetaTesters
            KeyCodeInput {
                height: settingsPopup._isAndroid ? 80 : 54
                Layout.preferredWidth: settingsPopup._isAndroid ? 280 : 180
                Layout.alignment: Qt.AlignRight
                //anchors.bottom: betaTesters.bottom
                //anchors.top: betaTesters.top
            }
        }

        //Category: Troubleshoot

        SettingRow {
            toggle: true
            text: "Troubleshooting"
            SettingCategoryToggle {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "showCatTroubleShoot"
                initialValue: pulseRuntimeSettings.showCatTroubleShoot
            }
        }

        SettingRow {
            text: "Restart the echo sounder"
            checkbox: true
            show: pulseRuntimeSettings.showCatTroubleShoot
            SettingsCheckBox {
                target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                targetPropertyName: "echoSounderReboot"
                initialChecked: pulseRuntimeSettings.echoSounderReboot
                clearAfter: true
            }
        }
    }
}
