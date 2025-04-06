import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 1.2
import Pulse.Plot 1.0

Rectangle {
    id: colorsPopup
    focus: true
    width: 900
    height: 400
    anchors.centerIn: parent
    color: "white"
    radius: 8

    function getThemeId () {
        let selectedThemeIndexBlue = PulseSettings.colorMapIndexSideScan
        let selectedThemeIndexRed = PulseSettings.colorMapIndex2D
        var selectedTheme
        if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue) {
            selectedTheme = pulseRuntimeSettings.themeModelBlue[selectedThemeIndexBlue]
        } else {
            selectedTheme = pulseRuntimeSettings.themeModelRed[selectedThemeIndexRed]
        }
        return selectedTheme.id
    }

    // Create an instance of Plot2DEchogram
    Plot2DEchogram {
        id: plot2DEchogram
        themeId: getThemeId()

        // Set your desired initial theme ID here.
        // You can set initial properties here if needed.
    }


    Rectangle {
        id: colorBarLegend
        width: 700
        height: 100
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 30
        anchors.topMargin: 20
        color: "transparent"

        Row {
            id: colorLegend
            width: 300
            height: 50
            spacing: 0
            Layout.topMargin: 60

            Text {
                text: "Your color scheme"
                font.pixelSize: 30
                height: 80
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                Layout.leftMargin: 20
            }
        }

        HorizontalTapSelectController {
            id: themeSelectorColorSS
            visible: pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
            model: pulseRuntimeSettings.themeModelBlue.map(function(item) {return item.icon;})
            iconSource: "./icons/pulse_paint.svg"
            selectedIndex: PulseSettings.colorMapIndexSideScan
            allowExpertModeByMultiTap: false
            anchors.left: colorLegend.left
            anchors.top: colorLegend.bottom
            onIconSelected: {
                console.log("TAV: colormap for:", pulseRuntimeSettings.userManualSetName);
                PulseSettings.colorMapIndexSideScan = selectedIndex;
                var selectedTheme = pulseRuntimeSettings.themeModelBlue[selectedIndex]
                console.log("TAV: colormap selectedIndex", selectedIndex, "matches selectedTheme.id", selectedTheme.id);
                plot.plotEchogramTheme(selectedTheme.id);
                plot.updatePlot();
            }

            Connections {
                target: pulseRuntimeSettings
                function onUserManualSetNameChanged () {
                    console.log("TAV: colormap for:", pulseRuntimeSettings.userManualSetName);
                    if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue) {
                        var preferredIndex = PulseSettings.colorMapIndexSideScan
                        var selectedTheme = pulseRuntimeSettings.themeModelBlue[preferredIndex]
                        console.log("TAV: colormap preferredIndex", preferredIndex, "matches preferredTheme.id", selectedTheme.id);
                        plot.plotEchogramTheme(selectedTheme.id)
                        PulseSettings.colorMapIndexReal = selectedTheme.id
                        plot.updatePlot();
                    } else {
                        console.log("TAV: colormap is 2D transducer, do not set for side scan");
                   }
                }
            }

            Connections {
                target: PulseSettings
                function onColorMapIndexSideScanChanged () {
                    themeSelectorColor2D.selectedIndex = PulseSettings.colorMapIndexSideScan
                    console.log("TAV: colormap updated to index:", PulseSettings.colorMapIndexSideScan);
                }
            }
        }

        HorizontalTapSelectController {
            id: themeSelectorColor2D
            visible: pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed
            model: pulseRuntimeSettings.themeModelRed.map(function(item) {return item.icon;})
            iconSource: "./icons/pulse_paint.svg"
            selectedIndex: PulseSettings.colorMapIndex2D
            allowExpertModeByMultiTap: false
            anchors.top: colorLegend.bottom
            onIconSelected: {
                console.log("TAV: colormap for:", pulseRuntimeSettings.userManualSetName);
                PulseSettings.colorMapIndex2D = selectedIndex;
                var selectedTheme = pulseRuntimeSettings.themeModelRed[selectedIndex]
                console.log("TAV: colormap selectedIndex", selectedIndex, "matches selectedTheme.id", selectedTheme.id);
                plot.plotEchogramTheme(selectedTheme.id);
                plot.updatePlot();
            }

            Connections {
                target: pulseRuntimeSettings
                function onUserManualSetNameChanged () {
                    console.log("TAV: colormap for:", pulseRuntimeSettings.userManualSetName);
                    if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseRed) {
                        var preferredIndex = PulseSettings.colorMapIndex2D
                        var selectedTheme = pulseRuntimeSettings.themeModelRed[preferredIndex]
                        console.log("TAV: colormap preferredIndex", preferredIndex, "matches preferredTheme.id", selectedTheme.id);
                        plot.plotEchogramTheme(selectedTheme.id)
                        PulseSettings.colorMapIndexReal = selectedTheme.id
                        plot.updatePlot();
                    } else {
                         console.log("TAV: colormap is side scan, do not set for 2D");
                    }
                }
            }

            Connections {
                target: PulseSettings
                function onColorMapIndex2DChanged () {
                    themeSelectorColor2D.selectedIndex = PulseSettings.colorMapIndex2D
                    console.log("TAV: colormap updated to index:", PulseSettings.colorMapIndex2D);
                }
            }
        }

    }

    Rectangle {
        id: colorBar
        width: 850
        height: 30
        anchors.left: parent.left
        anchors.topMargin: 50
        anchors.leftMargin: 30
        anchors.top: colorBarLegend.bottom
        color: "transparent"

        property int themeColorCount: plot2DEchogram.themeColors.length
        property int useWidth: width / themeColorCount

        Row {
            anchors.fill: parent
            spacing: 0
            Layout.topMargin: 20

            Repeater {
                model: plot2DEchogram.themeColors

                Rectangle {
                    //width: 12
                    width: colorBar.useWidth
                    height: colorBar.height
                    color: modelData
                }
            }
        }

        Component.onCompleted: {
            var colors = plot2DEchogram.themeColors
            console.log("Colors from plot2DEchogram.themeColors:", colors)
        }

        Connections {
            target: plot2DEchogram
            function onThemeColorsChanged() {
                console.log("Theme colors changed to:", plot2DEchogram.themeColors)
                colorRepeater.model = []   // clear old model
                colorRepeater.model = plot2DEchogram.themeColors
                themeColorCount = plot2DEchogram.themeColors.length
            }
        }
    }

    Rectangle {
        id: infoLeftContainer
        width: 42
        height: 42
        color:  "transparent"

        anchors.left: colorBar.left
        anchors.top: colorBar.bottom
        anchors.topMargin: 10
        //visible: pulseRuntimeSettings.devDetected || pulseRuntimeSettings.devManualSelected

        Image {
            anchors.centerIn: infoLeftContainer
            width: 42
            height: 42
            source: pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue ?
                        "./icons/pulse_return_signal_weak_ss.svg" :
                        "./icons/pulse_return_signal_weak.svg"
            fillMode: Image.PreserveAspectFit
        }
    }

    Rectangle {
        id: infoRightContainer
        width: 42
        height: 42
        color:  "transparent"

        anchors.right: colorBar.right
        anchors.top: colorBar.bottom
        anchors.topMargin: 10
        //visible: pulseRuntimeSettings.devDetected || pulseRuntimeSettings.devManualSelected

        Image {
            anchors.centerIn: infoRightContainer
            width: 42
            height: 42
            source: pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue ?
                        "./icons/pulse_return_signal_strong_ss.svg" :
                        "./icons/pulse_return_signal_hard.svg"
            fillMode: Image.PreserveAspectFit
        }
    }




}
