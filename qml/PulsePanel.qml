import QtQuick 2.15

// THE SLIDING PANEL (Stage 4 b) - Direction A's other half.
//
// It COMPRESSES the echogram rather than covering it, which is the whole reason the rail
// had to leave PulseAppV2: qPlot2D paints across its entire item, so anything that takes
// width from the picture must be the panes' sibling. `inset` is the one number the host
// reads, exactly as the rail's is.
//
// ONE PANEL, ONE WIDTH, and one group open at a time. `openGroup` is the whole of that -
// there is no per-group visible flag to fall out of step, and tapping the rail button that
// opened a group closes it because the host compares the id it was given with this one.
//
// NO APPLY BUTTON ANYWHERE. Every row acts as it is touched. The single exception is the
// existing stopEchogramToConfigure, which halts the picture while a parameter is written -
// and because that is a surprise rather than a choice, the header says so while it is on.
Item {
    id: panel

    property real uiScale:    1.0
    property real safeTop:    0
    property real safeBottom: 0

    // "" is closed. Anything else is the rail button id whose group is showing.
    property string openGroup: ""

    property bool announceEchogramStop: false

    readonly property bool isOpen: openGroup !== ""
    readonly property real panelWidth: Math.round(360 * uiScale)

    // WHAT THE PICTURE OWES THE PANEL. Zero when closed, and the host adds it to the rail's
    // own inset - two numbers, one for each thing that takes width, and neither guesses
    // about the other.
    readonly property real inset: isOpen ? panelWidth : 0

    signal closeRequested()

    // ---- Colours, the only group in step 1 ----------------------------------
    property var  themeEntries:      []
    property int  currentThemeId:    -1
    property var  themeStopsById:    ({})
    property bool offerFavourites:   false
    property bool favouritesFilter:  false
    property var  favouriteIds:      []

    signal themeChosen(int id)
    signal favouriteToggled(int id)
    signal favouritesFilterToggled()

    // ---- The two slider groups ----------------------------------------------
    property int intensityValue: 0
    property int filterValue:    0
    property string filterHint:  ""

    signal intensityMoved(int v)
    signal filterMoved(int v)

    // ---- The view / cone chooser --------------------------------------------
    property var    choiceEntries:   []
    property string choiceCurrentId: ""
    property string choiceCaption:   ""

    signal choiceMade(string id)

    // ---- Max range ----------------------------------------------------------
    property int    rangeValue:   0
    property int    rangeFloor:   1
    property int    rangeCeiling: 52
    property int    rangeStep:    1
    property string rangeHint:    ""

    signal rangeMoved(int v)

    // ---- Settings, tier 2 ---------------------------------------------------
    //
    // ONE SIGNAL FOR EVERY SETTING IN THE LIST. The rows bind their values straight to the
    // two settings objects and this carries the write back to main.qml, which is the only
    // place that assigns one. A property-and-signal pair per setting would be a hundred of
    // each by the time tier 3 lands, and the rule it is there to protect - one writer per
    // key - is kept exactly as well by one.
    signal settingChanged(string target, string key, var value)

    // An action carries no value and its handler does rather than assigns, so it travels
    // on its own signal - see PulseSettingsList.
    signal actionRequested(string id)

    visible: isOpen
    width: panelWidth

    readonly property bool onAndroid: Qt.platform.os === "android"
    readonly property real topInset: Math.max(safeTop, onAndroid ? Math.round(34 * uiScale) : 0)

    readonly property string title:
          openGroup === "colours"   ? qsTr("Colours")
        : openGroup === "intensity" ? qsTr("Intensity")
        : openGroup === "filter"    ? qsTr("Water body filter")
        : openGroup === "range"     ? qsTr("Max range")
        : openGroup === "view"      ? qsTr("View")
        : openGroup === "cone"      ? qsTr("Cone")
        : openGroup === "settings"  ? qsTr("Settings")
        : openGroup === ""        ? ""
        :                           openGroup

    Rectangle {
        anchors.fill: parent
        color: "#f2101418"
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: "#20ffffff"
    }

    // ---- Header -------------------------------------------------------------

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: panel.topInset
        height: Math.round(64 * panel.uiScale)

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Math.round(18 * panel.uiScale)
            anchors.verticalCenter: parent.verticalCenter
            text: panel.title
            color: "#eaf1f8"
            font.pixelSize: Math.round(22 * panel.uiScale)
            font.bold: true
        }

        Rectangle {
            id: closeButton
            anchors.right: parent.right
            anchors.rightMargin: Math.round(10 * panel.uiScale)
            anchors.verticalCenter: parent.verticalCenter
            width:  Math.round(44 * panel.uiScale)
            height: width
            radius: Math.round(10 * panel.uiScale)
            color: closeArea.pressed ? "#2a3644" : "transparent"

            Image {
                anchors.centerIn: parent
                width:  Math.round(22 * panel.uiScale)
                height: width
                source: "./icons/ui/pulse_zoom_close.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                onClicked: panel.closeRequested()
            }
        }
    }

    // THE ONE THING THE PANEL HAS TO ANNOUNCE. stopEchogramToConfigure halts the picture
    // while a parameter is written, and a picture that stops for no visible reason is the
    // kind of thing that gets reported as a fault.
    Rectangle {
        id: announcement
        visible: panel.announceEchogramStop
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.leftMargin:  Math.round(14 * panel.uiScale)
        anchors.rightMargin: Math.round(14 * panel.uiScale)
        height: visible ? announcementText.height + Math.round(20 * panel.uiScale) : 0
        radius: Math.round(8 * panel.uiScale)
        color: "#2a2410"
        border.width: 1
        border.color: "#d8a21f"

        Text {
            id: announcementText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Math.round(12 * panel.uiScale)
            wrapMode: Text.WordWrap
            text: qsTr("The echogram stops while a setting is written to the transducer.")
            color: "#f4ead6"
            font.pixelSize: Math.round(14 * panel.uiScale)
        }
    }

    Rectangle {
        id: rule
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: announcement.bottom
        anchors.topMargin: Math.round(10 * panel.uiScale)
        height: 1
        color: "#20ffffff"
    }

    // ---- Body ---------------------------------------------------------------
    //
    // Scrolls because twenty themes at 64 du do not fit a short landscape screen, and
    // contentHeight comes from the group's own implicit height rather than a guess.
    Flickable {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: rule.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin:   Math.round(14 * panel.uiScale)
        anchors.rightMargin:  Math.round(14 * panel.uiScale)
        anchors.topMargin:    Math.round(12 * panel.uiScale)
        anchors.bottomMargin: panel.safeBottom + Math.round(12 * panel.uiScale)

        clip: true
        contentHeight: body.height
        boundsBehavior: Flickable.StopAtBounds

        // A Column, so a group that is not showing takes no height and contentHeight is the
        // one that is. Adding a group is adding a child with its own `visible`.
        Column {
        id: body
        width: parent.width
        spacing: 0

        PulseColourGroup {
            id: colourGroup

            width: parent.width
            height: visible ? implicitHeight : 0
            visible: panel.openGroup === "colours"

            uiScale: panel.uiScale

            entries:          panel.themeEntries
            stopsById:        panel.themeStopsById
            currentId:        panel.currentThemeId
            offerFavourites:  panel.offerFavourites
            favouritesFilter: panel.favouritesFilter
            favouriteIds:     panel.favouriteIds

            onThemeChosen:            function (id) { panel.themeChosen(id) }
            onFavouriteToggled:       function (id) { panel.favouriteToggled(id) }
            onFavouritesFilterToggled: panel.favouritesFilterToggled()
        }

        PulseSliderRow {
            width: parent.width
            height: visible ? implicitHeight : 0
            visible: panel.openGroup === "intensity"
            uiScale: panel.uiScale

            label: qsTr("Intensity")
            minValue: 0
            maxValue: 20
            value: panel.intensityValue
            valueText: panel.intensityValue

            onMoved: function (v) { panel.intensityMoved(v) }
        }

        PulseSliderRow {
            width: parent.width
            height: visible ? implicitHeight : 0
            visible: panel.openGroup === "filter"
            uiScale: panel.uiScale

            label: qsTr("Water body filter")
            hint: panel.filterHint
            minValue: 0
            maxValue: 20
            value: panel.filterValue
            valueText: panel.filterValue

            onMoved: function (v) { panel.filterMoved(v) }
        }

        PulseSliderRow {
            width: parent.width
            height: visible ? implicitHeight : 0
            visible: panel.openGroup === "range"
            uiScale: panel.uiScale

            label: qsTr("Max range")
            hint: panel.rangeHint
            minValue: panel.rangeFloor
            maxValue: panel.rangeCeiling
            stepSize: panel.rangeStep
            value: panel.rangeValue
            valueText: panel.rangeValue + " m"

            onMoved: function (v) { panel.rangeMoved(v) }
        }

        PulseChoiceGroup {
            width: parent.width
            height: visible ? implicitHeight : 0
            visible: panel.openGroup === "view" || panel.openGroup === "cone"
            uiScale: panel.uiScale

            entries:   panel.choiceEntries
            currentId: panel.choiceCurrentId
            caption:   panel.choiceCaption

            onChosen: function (id) { panel.choiceMade(id) }
        }

        PulseSettingsList {
            width: parent.width
            height: visible ? implicitHeight : 0
            visible: panel.openGroup === "settings"
            uiScale: panel.uiScale

            onSettingChanged: function (target, key, value) {
                panel.settingChanged(target, key, value)
            }

            onActionRequested: function (id) {
                panel.actionRequested(id)
            }
        }
        }
    }
}
