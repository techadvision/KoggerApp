import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import Echo.UI 1.0
import QtQuick.Window
//Pulse Plot not installed, but do we need it? Not needed!
//import Pulse.Plot 1.0


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

    // Base “design” size for this control on your 10" tablet
    readonly property int baseWidth: 900
    implicitWidth:  Math.round(baseWidth  * s)
    width:  implicitWidth

    /*
    property int controlIconSize: _isAndroid ? 34 : 20
    property int pressButtonSize: _isAndroid ? 80 : 40
    property int displayPixels:   _isAndroid ? 100 : 40
    property int valueTextWidth:  _isAndroid ? 120 : 80
    property int valueTextHeigh:  _isAndroid ? 40 : 30
    property int valuePixels:     _isAndroid ? 30 : 22
    property int autoPixels:      _isAndroid ? 32 : 24
    property int selectIconSize:  _isAndroid ? 80 : 60
    property int selectCheckSize: _isAndroid ? 56 : 40
    */

    focus: true
    //width: _isAndroid ? 900 : 600

    anchors.fill: parent
    flickableDirection: Flickable.VerticalFlick

    // Scrollbar always visible
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AlwaysOn
        width: Math.round(16 * s)
        //width: _isAndroid? 16 : 12
    }

    contentWidth: width
    contentHeight: contentItem.childrenRect.height

    Rectangle {
        id: colorsPopup
        focus: true
        //width: _isAndroid ? 900 : 600
        width: Math.round(900 * s)
        implicitHeight: childrenRect.height   // auto-grow to fit all the children
        clip: true                            // hide overflow if you want
        //height: 400
        color: "white"
        radius: 8

        function getThemeId () {
            console.log("Color theme: function getThemeId")
            let selectedThemeIndexBlue = pulseSettings.colorMapIndexSideScan
            let selectedThemeIndexRed = pulseSettings.colorMapIndex2D
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
            //width: _isAndroid ? 700 : 470
            width: Math.round(700 * s)
            height: settingsPopup.selectIconSize
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Math.round(10 * s)
            //anchors.leftMargin: 10
            anchors.topMargin: Math.round(10 * s)
            //anchors.topMargin: 10
            color: "transparent"
            visible: pulseRuntimeSettings.is2DTransducer

            Row {
                anchors.top: parent.top
                anchors.left: parent.left
                //spacing: 12
                spacing: Math.round(12 * s)
                //anchors.margins: 8

                Image {
                    id: colorImage2D
                    source: (pulseRuntimeSettings.themeModelRed[pulseSettings.colorMapIndex2D] || {}).icon
                    width: settingsPopup.selectIconSize
                    height: settingsPopup.selectIconSize
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: (pulseRuntimeSettings.themeModelRed[pulseSettings.colorMapIndex2D] || {}).title
                    //text: colorBarLegend2D.getSelected2DTheme().title
                    //text: colorBarLegend2D.selected2DTheme.title
                    anchors.leftMargin: Math.round(12 * s)
                    //anchors.leftMargin: 10
                    font {
                            //pixelSize: _isAndroid ? 40 : 26
                            pixelSize: Ui.fontXL
                            bold: true
                            italic: true
                        }
                    anchors.verticalCenter: colorImage2D.verticalCenter
                }
            }
        }

        Rectangle {
            id: colorBarLegendSS
            width: _isAndroid ? 700 : 470
            height: settingsPopup.selectIconSize
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Math.round(10 * s)
            //anchors.leftMargin: 10
            anchors.topMargin: Math.round(10 * s)
            //anchors.topMargin: 10
            color: "transparent"
            visible: !pulseRuntimeSettings.is2DTransducer

            // helper to grab the 2D theme object by the persisted index
            function getSelectedSSTheme() {
                var i = pulseSettings.colorMapIndexSideScan
                return pulseRuntimeSettings.themeModelBlue[i] || { icon: "", title: "" }
            }


            Row {
                anchors.top: parent.top
                anchors.left: parent.left
                spacing: Math.round(12 * s)
                //spacing: 12
                //anchors.margins: 8

                Image {
                    id: colorImageSS
                    source: colorBarLegendSS.getSelectedSSTheme().icon
                    width: settingsPopup.selectIconSize
                    height: settingsPopup.selectIconSize
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: colorBarLegendSS.getSelectedSSTheme().title
                    font {
                            //pixelSize: _isAndroid ? 40 : 26
                            pixelSize: Ui.fontXL
                            bold: true
                            italic: true
                        }
                    anchors.leftMargin: Math.round(10 * s) //10
                    anchors.verticalCenter: colorImageSS.verticalCenter
                }
            }
        }

        Rectangle {
            id: colorBar
            width: Math.round(850 * s)
            height: Math.round(30 * s)
            //width: _isAndroid ? 850 : 560
            //height: _isAndroid ? 30 : 20
            anchors.left: parent.left
            anchors.topMargin: 5
            anchors.leftMargin: Math.round(20 * s) //20
            anchors.top: pulseRuntimeSettings.is2DTransducer ? colorBarLegend2D.bottom : colorBarLegendSS.bottom
            color: "transparent"

            property int themeColorCount: pulseRuntimeSettings.currentThemeColors.length
            property int useWidth: width / themeColorCount

            Row {
                id: colorRow
                anchors.fill: parent
                spacing: 0
                Layout.topMargin: Math.round(20 * s) //20

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
            width: Math.round(42 * s) //_isAndroid ? 42 : 28
            height: Math.round(42 * s) //_isAndroid ? 42 : 28
            color:  "transparent"

            anchors.left: colorBar.left
            anchors.top: colorBar.bottom
            anchors.topMargin: Math.round(10 * s) //10

            Image {
                anchors.centerIn: infoLeftContainer
                width: Math.round(42 * s) //_isAndroid ? 42 : 28
                height: Math.round(42 * s) //_isAndroid ? 42 : 28
                source: "./icons/ui/pulse_return_signal_weak.svg"
                fillMode: Image.PreserveAspectFit
            }
        }

        Rectangle {
            id: infoRightContainer
            width: Math.round(42 * s) //_isAndroid ? 42 : 28
            height: Math.round(42 * s) //_isAndroid ? 42 : 28
            color:  "transparent"

            anchors.top: colorBar.bottom
            anchors.topMargin: 10
            x: colorRow.x + colorRow.implicitWidth - width + 15

            Image {
                anchors.centerIn: infoRightContainer
                width: Math.round(42 * s) //_isAndroid ? 42 : 28
                height: Math.round(42 * s) //_isAndroid ? 42 : 28
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
            anchors.topMargin: Math.round(20 * s) //20
            visible: pulseRuntimeSettings.is2DTransducer
            SettingsCheckBox {
                target: pulseSettings ? pulseSettings : undefined
                targetPropertyName: "useFavoriteThemes2D"
                initialChecked: pulseSettings.useFavoriteThemes2D
            }
        }

        GridView {
            id: grid
            visible: pulseSettings.useFavoriteThemes2D && pulseRuntimeSettings.is2DTransducer
            anchors.top: favoriteColors.bottom
            anchors.left: favoriteColors.left
            clip: true
            anchors.leftMargin: Math.round(15 * s) //15
            anchors.topMargin: Math.round(10 * s) //10
            width: Math.round(900 * s)
            height: Math.round(400 * s)
            //width: _isAndroid? 900 : 600
            //height: _isAndroid ? 400 : 270
            cellWidth: Math.round(150 * s)
            cellHeight: Math.round(80 * s)
            //cellWidth: _isAndroid ? 150 : 100
            //cellHeight: _isAndroid ? 80 : 54
            model: pulseRuntimeSettings.themeModelRed
            delegate: Item {
                width: grid.cellWidth; height: grid.cellHeight

                SettingsCheckBox {
                    id: checkBox
                    initialChecked: pulseSettings.favoriteThemes2DNew.findIndex(function(x){ return x.id === modelData.id }) !== -1
                    //initialChecked: pulseSettings.favoriteThemes2D.indexOf(modelData.id) !== -1
                    clearAfter: false                // turn off auto-clear for favorites
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(19 * s) //10

                    onCheckedChanged: {
                        if (!pulseRuntimeSettings.is2DTransducer)
                            return
                        if (checked) {
                            pulseSettings.addFavorite2DNew(modelData)
                            //pulseSettings.addFavorite2D(modelData.id)
                            console.log("Favorite Colors: Added id", modelData.id, "with name", modelData.title, "and icon", modelData.icon)
                            console.log("Favorite Colors: favoriteThemes2DNew contains", pulseSettings.favoriteThemes2DNew)

                        } else {
                            pulseSettings.removeFavorite2DNew(modelData)
                            //pulseSettings.removeFavorite2D(modelData.id)
                            console.log("Favorite Colors: removed id", modelData.id, "with name", modelData.title)
                            console.log("Favorite Colors: favoriteThemes2DNew contains", pulseSettings.favoriteThemes2DNew)
                        }
                    }
                }

                Image {
                    source: modelData.icon
                    width: Math.round(64 * s) //_isAndroid ? 42 : 28
                    height: Math.round(64 * s) //_isAndroid ? 42 : 28
                    //width: _isAndroid ? 64 : 42
                    //height: _isAndroid ? 64 : 42
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: checkBox.right
                    anchors.leftMargin: 5
                    fillMode: Image.PreserveAspectFit
                }

            }
        }
    }
}


