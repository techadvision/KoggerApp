import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
//import NMEASender 1.0


Flickable {
    id: settingsPopup
    focus: true
    width: 900

    anchors.fill: parent
    flickableDirection: Flickable.VerticalFlick

    // Scrollbar always visible
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AlwaysOn
        width: 16
    }

    //color: "white"
    //radius: 8
    //implicitWidth:  layout.implicitWidth
    //implicitHeight: layout.implicitHeight + spacer.height

    contentWidth: width
    contentHeight: contentItem.childrenRect.height

    signal pulsePreferenceClosed()
    signal pulsePreferenceValueChanged(double newValue)
    signal stateChanged(bool checked)

    Rectangle{
        id: spacer
        width: 900
        height: 20
    }

    ColumnLayout {
        spacing: 20
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
            text: PulseSettings.useMetricDepth ? "Metric depth (checked)" : "Imperial depth (unchecked)"
            show: pulseRuntimeSettings.showCatScreen
            SettingsCheckBox {
                target: PulseSettings ? PulseSettings : undefined
                targetPropertyName: "useMetricDepth"
                initialChecked: PulseSettings.useMetricDepth
            }

        }

        SettingRow {
            toggle: false
            text: "Display temperature on screen"
            show: pulseRuntimeSettings.showCatScreen && pulseRuntimeSettings.useTemperature
            SettingsCheckBox {
                target: PulseSettings ? PulseSettings : undefined
                targetPropertyName: "showTemperatureInUi"
                initialChecked: PulseSettings.showTemperatureInUi
            }
        }

        SettingRow {
            toggle: false
            text: PulseSettings.useMetricTemperature ? "Metric temperature (checked)" : "Imperial temperature (unchecked)"
            show: pulseRuntimeSettings.showCatScreen && pulseRuntimeSettings.useTemperature && PulseSettings.showTemperatureInUi
            SettingsCheckBox {
                target: PulseSettings ? PulseSettings : undefined
                targetPropertyName: "useMetricTemperature"
                initialChecked: PulseSettings.useMetricTemperature
            }
        }

        SettingRow {
            toggle: false
            text: "Optimize to include second echo"
            show: pulseRuntimeSettings.showCatScreen
            SettingsCheckBox {
                target: PulseSettings ? PulseSettings : undefined
                targetPropertyName: "doubleEchoOptimize"
                initialChecked: PulseSettings.doubleEchoOptimize
            }
        }

        SettingRow {
            toggle: false
            text: "Echogram screen speed (1-5)"
            show: pulseRuntimeSettings.showCatScreen
            HorizontalControllerDoubleSettings {
                id: speedSelector
                values: [1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9,
                    2.0, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9,
                    3.0, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9,
                    4.0, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 5.0]
                height: 80
                Layout.preferredWidth: 280
                Component.onCompleted: {
                    var idx = values.indexOf(pulseRuntimeSettings.echogramSpeed)
                    //console.log("PulseSettingsValue speedSelector Component.onCompleted idx calculated to ", idx)
                    currentIndex = idx >= 0 ? idx : 0
                }

                onPulsePreferenceValueChanged: {
                    //console.log("PulseSettingsValue speedSelector changed to", newValue)
                    pulseRuntimeSettings.echogramSpeed = newValue
                }

                Connections {
                    target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
                    function onEchogramSpeedChanged () {
                        var idx = speedSelector.values.indexOf(pulseRuntimeSettings.echogramSpeed)
                        if (idx >= 0) speedSelector.currentIndex = idx
                    }
                }
            }
        }

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
            text: "Enable UDP NMEA server"
            show: pulseRuntimeSettings.showCatNmea
            SettingsCheckBox {
                target: pulseSettings ? pulseSettings : undefined
                targetPropertyName: "enableNmeaDbt"
                initialChecked: pulseSettings.enableNmeaDbt
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

                onPulsePreferenceValueChanged: {
                    pulseSettings.nmeaPort = newValue
                }
            }
        }

        SettingRow {
            text: "NMEA send to IP"
            show: pulseRuntimeSettings.showCatNmea
            Text {
                text: "Localhost (this device)"
                font.pixelSize: 30
                color: "gray"

                height: 80
                Layout.preferredWidth: 280
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
                //currentValue: PulseSettings.transducerOffsetMount
                onPulsePreferenceValueChanged: {
                    console.log("transducerOffsetMount updated to", newValue)
                    PulseSettings.transducerOffsetMount = newValue
                }
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    // If your singleton already has a value, pick that up,
                    // otherwise fall back to your minimum.
                    if (typeof PulseSettings.transducerOffsetMount === "number") {
                        currentValue = PulseSettings.transducerOffsetMount
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
            show: pulseRuntimeSettings.showCatInstallation && pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
            SettingsCheckBox {
                target: PulseSettings ? PulseSettings : undefined
                targetPropertyName: "isSideScanOnLeftHandSide"
                initialChecked: PulseSettings.isSideScanOnLeftHandSide
            }

            Connections {
                target: PulseSettings
                function onIsSideScanOnLeftHandSideChanged() {
                    pulseRuntimeSettings.isSideScanLeftHand = PulseSettings.isSideScanOnLeftHandSide
                    console.log("DEVICE_INSTALLATION: pulseRuntimeSettings.isSideScanLeftHand new value", pulseRuntimeSettings.isSideScanLeftHand)
                }
            }
        }

        SettingRow {
            text: "PULSEblue: Cable facing front"
            toggle: false
            show: pulseRuntimeSettings.showCatInstallation && pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
            SettingsCheckBox {
                target: PulseSettings ? PulseSettings : undefined
                targetPropertyName: "isSideScanCableFacingFront"
                initialChecked: PulseSettings.isSideScanCableFacingFront
            }
        }

        SettingRow {
            text: "Pulse Wi-Fi Server UDP port"
            toggle: false
            show: pulseRuntimeSettings.showCatInstallation && pulseRuntimeSettings.expertMode
            HorizontalControllerDoubleSettings {
                id: udpPortSelection
                values: [14550, 14560]
                onPulsePreferenceValueChanged: PulseSettings.udpPort = newValue
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                Component.onCompleted: {
                    var idx = values.indexOf(PulseSettings.udpPort)
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
                height: 80
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignRight
                anchors.bottom: betaTesters.bottom
                anchors.top: betaTesters.top
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
