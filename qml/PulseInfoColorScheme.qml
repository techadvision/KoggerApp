import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 1.2
//Pulse Plot not installed, but do we need it? Not needed!
//import Pulse.Plot 1.0


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

    contentWidth: width
    contentHeight: contentItem.childrenRect.height

    Rectangle {
        id: colorsPopup
        focus: true
        width: 900
        implicitHeight: childrenRect.height   // auto-grow to fit all the children
        clip: true                            // hide overflow if you want
        //height: 400
        color: "white"
        radius: 8

        function getThemeId () {
            console.log("Color theme: function getThemeId")
            let selectedThemeIndexBlue = PulseSettings.colorMapIndexSideScan
            let selectedThemeIndexRed = PulseSettings.colorMapIndex2D
            var selectedTheme
            if (pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue
                    ||pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlueProto) {
                selectedTheme = pulseRuntimeSettings.themeModelBlue[selectedThemeIndexBlue]
            } else {
                selectedTheme = pulseRuntimeSettings.themeModelRed[selectedThemeIndexRed]
            }
            console.log("Color theme: function getThemeId returns", selectedTheme.id)
            return selectedTheme.id
        }

        Rectangle {
            id: colorBarLegend2D
            width: 700
            height: 80
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 10
            anchors.topMargin: 10
            color: "transparent"
            visible: pulseRuntimeSettings.is2DTransducer

            /*
            // helper to grab the 2D theme object by the persisted index
            function getSelected2DTheme() {
                var i = PulseSettings.colorMapIndex2D
                return pulseRuntimeSettings.themeModelRed[i] || { icon: "", title: "" }
            }

            Connections {
                target: PulseSettings
                function onUseFavoriteThemes2DChanged() {
                    console.log("Favorites toggled → perhaps update colorBarLegend2D")
                    colorBarLegend2D.getSelected2DTheme()
                }
                function onFavoriteThemes2DNewChanged()   {
                    console.log("Favorites changed → perhaps update colorBarLegend2D")
                    colorBarLegend2D.getSelected2DTheme()
                }
                function onColorMapIndex2DChanged () {
                    console.log("Favorites color map index updated → perhaps update colorBarLegend2D")
                    colorBarLegend2D.getSelected2DTheme()
                }
            }
            */


            /*
            // 1) Define a binding property for the currently selected theme object:
            property var selected2DTheme: {
                var i = PulseSettings.colorMapIndex2D
                // if favorites‐only is on, make sure your singleton has already
                // fallen back on removal, otherwise this just reads the index.
                return pulseRuntimeSettings.themeModelRed[i] || { icon:"", title:"" }
            }
            */

            Row {
                anchors.top: parent.top
                anchors.left: parent.left
                spacing: 12
                //anchors.margins: 8

                Image {
                    id: colorImage2D
                    source: (pulseRuntimeSettings.themeModelRed[PulseSettings.colorMapIndex2D] || {}).icon
                    //source: colorBarLegend2D.getSelected2DTheme().icon
                    //source: colorBarLegend2D.selected2DTheme.icon
                    width: 80; height: 80
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: (pulseRuntimeSettings.themeModelRed[PulseSettings.colorMapIndex2D] || {}).title
                    //text: colorBarLegend2D.getSelected2DTheme().title
                    //text: colorBarLegend2D.selected2DTheme.title
                    anchors.leftMargin: 10
                    font {
                            pixelSize: 40
                            bold: true
                            italic: true
                        }
                    anchors.verticalCenter: colorImage2D.verticalCenter
                }
            }
        }

        Rectangle {
            id: colorBarLegendSS
            width: 700
            height: 80
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 10
            anchors.topMargin: 10
            color: "transparent"
            visible: !pulseRuntimeSettings.is2DTransducer

            // helper to grab the 2D theme object by the persisted index
            function getSelectedSSTheme() {
                var i = PulseSettings.colorMapIndexSideScan
                return pulseRuntimeSettings.themeModelBlue[i] || { icon: "", title: "" }
            }


            Row {
                anchors.top: parent.top
                anchors.left: parent.left
                spacing: 12
                //anchors.margins: 8

                Image {
                    id: colorImageSS
                    source: colorBarLegendSS.getSelectedSSTheme().icon
                    width: 80; height: 80
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: colorBarLegendSS.getSelectedSSTheme().title
                    font {
                            pixelSize: 40
                            bold: true
                            italic: true
                        }
                    anchors.leftMargin: 10
                    anchors.verticalCenter: colorImageSS.verticalCenter
                }
            }
        }

        Rectangle {
            id: colorBar
            width: 850
            height: 30
            anchors.left: parent.left
            anchors.topMargin: 5
            anchors.leftMargin: 20
            anchors.top: pulseRuntimeSettings.is2DTransducer ? colorBarLegend2D.bottom : colorBarLegendSS.bottom
            color: "transparent"

            property int themeColorCount: pulseRuntimeSettings.currentThemeColors.length
            property int useWidth: width / themeColorCount

            Row {
                id: colorRow
                anchors.fill: parent
                spacing: 0
                Layout.topMargin: 20

                Repeater {
                    id: colorRepeater
                    model: pulseRuntimeSettings.currentThemeColors
                    delegate: Rectangle {
                            width: colorBar.useWidth
                            height: colorBar.height
                            color: modelData
                            border.color: "gray"
                            border.width: 1
                        }
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

            Image {
                anchors.centerIn: infoLeftContainer
                width: 42
                height: 42
                source: "./icons/ui/pulse_return_signal_weak.svg"
                fillMode: Image.PreserveAspectFit
            }
        }

        Rectangle {
            id: infoRightContainer
            width: 42
            height: 42
            color:  "transparent"

            anchors.top: colorBar.bottom
            anchors.topMargin: 10
            x: colorRow.x + colorRow.implicitWidth - width + 15

            Image {
                anchors.centerIn: infoRightContainer
                width: 42
                height: 42
                source: "./icons/ui/pulse_return_signal_hard.svg"
                fillMode: Image.PreserveAspectFit
            }
        }

        SettingRow {
            id: favoriteColors
            toggle: true
            text: "Use favorite themes only"
            anchors.top: infoLeftContainer.bottom
            //anchors.left: colorBar.left
            anchors.topMargin: 20
            visible: pulseRuntimeSettings.is2DTransducer
            SettingsCheckBox {
                target: PulseSettings ? PulseSettings : undefined
                targetPropertyName: "useFavoriteThemes2D"
                initialChecked: PulseSettings.useFavoriteThemes2D
            }
        }

        GridView {
            id: grid
            visible: PulseSettings.useFavoriteThemes2D && pulseRuntimeSettings.is2DTransducer
            anchors.top: favoriteColors.bottom
            anchors.left: favoriteColors.left
            clip: true
            anchors.leftMargin: 15
            anchors.topMargin: 10
            width: 900; height: 400
            cellWidth: 150; cellHeight: 80
            model: pulseRuntimeSettings.themeModelRed
            delegate: Item {
                width: grid.cellWidth; height: grid.cellHeight

                SettingsCheckBox {
                    id: checkBox
                    initialChecked: PulseSettings.favoriteThemes2DNew.findIndex(function(x){ return x.id === modelData.id }) !== -1
                    //initialChecked: PulseSettings.favoriteThemes2D.indexOf(modelData.id) !== -1
                    clearAfter: false                // turn off auto-clear for favorites
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10

                    onCheckedChanged: {
                        if (!pulseRuntimeSettings.is2DTransducer)
                            return
                        if (checked) {
                            PulseSettings.addFavorite2DNew(modelData)
                            //PulseSettings.addFavorite2D(modelData.id)
                            console.log("Favorite Colors: Added id", modelData.id, "with name", modelData.title, "and icon", modelData.icon)
                            console.log("Favorite Colors: favoriteThemes2DNew contains", PulseSettings.favoriteThemes2DNew)

                        } else {
                            PulseSettings.removeFavorite2DNew(modelData)
                            //PulseSettings.removeFavorite2D(modelData.id)
                            console.log("Favorite Colors: removed id", modelData.id, "with name", modelData.title)
                            console.log("Favorite Colors: favoriteThemes2DNew contains", PulseSettings.favoriteThemes2DNew)
                        }
                    }
                }

                Image {
                    source: modelData.icon
                    width: 64
                    height: 64
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: checkBox.right
                    anchors.leftMargin: 5
                    fillMode: Image.PreserveAspectFit
                }

            }
        }
    }
}


