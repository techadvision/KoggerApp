// File: IconSelector.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
//import QtQuick.Controls.Material 2.15
import Echo.UI 1.0
import QtQuick.Window


Item {
    id: root

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real platformScale: _isAndroid ? 0.9 : 0.75
    //readonly property real s: Ui.scale * platformScale
    readonly property int buttonIconSizeRef: Ui.iconTouch
    readonly property int controlIconSizeRef: Ui.iconIllustration
    readonly property real shortSide: Math.min(Screen.width, Screen.height)
    readonly property real s: Math.max(1.0, shortSide / 1100) // tune 800 to your “10-inch baseline”

    // Platform related sizes
    /*
    width: Math.round(125 * s)
    height: Math.round(70 * s)
    */

    // Base “design” size for this control on your 10" tablet
    readonly property int baseWidth: 125
    readonly property int baseHeight: 70

    // Natural size for layouts
    implicitWidth:  Math.round(baseWidth  * s)
    implicitHeight: Math.round(baseHeight * s)

    // Good defaults when NOT inside a layout
    width:  implicitWidth
    height: implicitHeight

    property int controlIconSize: Math.round(24 * s)
    property int pressButtonSize: Math.round(56 * s)
    property int displayPixels:   Math.round(60 * s)
    property int valueTextWidth:  Math.round(60 * s)
    property int valueTextHeigh:  Math.round(40 * s)
    property int valuePixels:     Math.round(42 * s)
    property int autoPixels:      Math.round(32 * s)
    property int selectIconSize:  Math.round(56 * s)
    property int selectCheckSize: Math.round(48 * s)

    /*
    width: _isAndroid ? 155 : 100
    height: _isAndroid ? 80 : 60
    //height: 80

    // Platform related sizes
    property int controlIconSize: _isAndroid ? 34 : 20
    property int pressButtonSize: _isAndroid ? 80 : 40
    property int displayPixels:   _isAndroid ? 100 : 40
    property int valueTextWidth:  _isAndroid ? 60 : 40
    property int valueTextHeigh:  _isAndroid ? 40 : 30
    property int valuePixels:     _isAndroid ? 42 : 32
    property int autoPixels:      _isAndroid ? 32 : 24
    property int selectIconSize:  _isAndroid ? 80 : 60
    property int selectCheckSize: _isAndroid ? 56 : 40
    */




    // ───────────────────────────────────────────────────────────────
    // Public API
    property var model: []
    property int selectedIndex: 0
    property string iconSource: ""
    property string controlName: ""
    signal iconSelected(int index)
    property Item hostWindow

    Component.onCompleted: {
        console.log("Favorite colors: Controller controlName", controlName, "iconSource", iconSource, "selectedIndex", selectedIndex)
    }

    // ───────────────────────────────────────────────────────────────
    // (A) Outer shape + current icon display
    Rectangle {
        id: outerShape
        width: parent.width
        height: parent.height
        radius: height / 2
        color: "#80000000"
        border.color: "#40ffffff"
        border.width: 1

        // CATCH‐ALL MOUSEAREA – blocks clicks from passing through to the pinch
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: false
            preventStealing: true
            onPressed: { /* nothing – absorb */ }
        }


        RowLayout {
            anchors.centerIn: parent
            spacing: 10

            // Optional “control” icon on the left
            Image {
                id: controlIcon
                Layout.preferredWidth: root.controlIconSizeRef//controlIconSize
                Layout.preferredHeight: root.controlIconSizeRef//controlIconSize
                //Layout.preferredWidth: 42
                //Layout.preferredHeight: 42
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                Layout.leftMargin: 6
            }

            // The rectangle that shows the currently selected item:
            Rectangle {
                id: iconRect
                width: root.buttonIconSizeRef //selectIconSize
                height: root.buttonIconSizeRef //selectIconSize
                //width: 80
                //height: 80
                radius: 5
                color: "transparent"

                Image {
                    anchors.centerIn: parent
                    source: root.model.length > 0
                            ? root.model[root.selectedIndex]
                            : ""
                    width: root.buttonIconSizeRef //selectIconSize
                    height: root.buttonIconSizeRef //selectIconSize
                    //width: 80
                    //height: 80
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }
        }

        // Toggle showList on click, computing positions first
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.model.length === 0) return;
                if (!showList) {
                    positionListAbove();   // compute listX/Y BEFORE making it visible
                    showList = true;
                } else {
                    showList = false;
                }
            }
        }
    }

    // ───────────────────────────────────────────────────────────────
    // (B) The “drop-up” list properties
    property bool showList: false

    property int visibleItems: 5          // max rows when there are many entries
    property int minFullRows: 4           // never clamp when list has ≤ 4 items
    property int itemMargin: 5
    property int itemSpacing: 10

    property real listX: 0
    property real listY: 0

    // Use the button icon height as the row height
    //readonly property int rowSize: iconRect.height
    readonly property int rowSize: buttonIconSizeRef

    // Un-clamped total height (all rows + spacing + margins)
    property int fullContentHeight: {
        if (model.length <= 0)
            return 0;

        return (model.length * rowSize)
             + ((model.length - 1) * itemSpacing)
             + (2 * itemMargin);
    }

    // Only clamp when we have more than minFullRows items
    property int clampedHeight: {
        console.log("PopupList: clampedHeight: model.length is", model.length, "and minFullRows", minFullRows)
        if (model.length <= minFullRows) {
            console.log("PopupList: clampedHeight: returned fullContentHeight", fullContentHeight)
            // Always show full list (no abbreviation)
            return fullContentHeight;
        }

        // Height for at most `visibleItems` rows
        var maxRows = visibleItems;
        var maxFull = (maxRows * rowSize)
                    + ((maxRows - 1) * itemSpacing)
                    + (2 * itemMargin);

        // Optionally show an extra half row to hint that it’s scrollable
        var withHalf = maxFull + rowSize / 2;
        console.log("PopupList: clampedHeight: returned Math.min(fullContentHeight, withHalf)", Math.min(fullContentHeight, withHalf))

        return Math.min(fullContentHeight, withHalf);
    }

    // ───────────────────────────────────────────────────────────────
    // (C) The List-rectangle, reparented into the real window
    Rectangle {
        id: iconListRect
        parent: hostWindow
        x: listX
        y: listY

        width: root.buttonIconSizeRef + 10 //Ui.iconTouch + 10 //Rect.width +10
        height: clampedHeight
        color: "#000000"
        radius: 10
        border.color: "#40ffffff"
        border.width: 1
        z: 1000
        visible: showList

        // ───────────────────────────────────────────────────────────
        // (D) ListView inside that shows all icons, clipped if too tall
        ListView {
            id: iconListView
            anchors.fill: parent
            anchors.margins: root.itemMargin
            spacing:       root.itemSpacing
            clip: true
            model: root.model

            delegate: Item {
                width: root.buttonIconSizeRef //selectIconSize //iconRect.width
                height: root.buttonIconSizeRef //selectIconSize //iconRect.height

                // Highlight the currently selected item
                Rectangle {
                    anchors.fill: parent
                    color: (index === root.selectedIndex)
                           ? "#50FFFFFF"
                           : "transparent"
                    radius: 5
                    z: -1
                }

                Image {
                    id: iconImage
                    source: modelData
                    width: root.buttonIconSizeRef //selectIconSize //iconRect.width
                    height: root.buttonIconSizeRef //selectIconSize //iconRect.height
                    //anchors.horizontalCenter: iconListView.horizontalCenter
                    //anchors.verticalCenter: parent.verticalCenter
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    onStatusChanged: {
                        if (status === Image.Error) {
                            console.log("POPUP: Failed to load", modelData)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.selectedIndex = index
                        root.iconSelected(index)
                        showList = false
                    }
                }
            }

            onVisibleChanged: {
                if (visible && root.model.length > 0) {
                    positionViewAtIndex(
                        root.selectedIndex,
                        ListView.Center
                    )
                }
            }
        }
    }

    // ───────────────────────────────────────────────────────────────
    // (E) Full-screen “click-catcher” to close the list when tapping outside
    Rectangle {
        id: clickCatcher
        parent: hostWindow
        anchors.fill: parent
        color: "transparent"
        z: 999
        visible: showList

        MouseArea {
            anchors.fill: parent
            onClicked: {
                showList = false
            }
        }
    }

    // ───────────────────────────────────────────────────────────────
    // (F) Helper function: compute listX, listY so “bottom of list” = “top of button”
    function positionListAbove() {
        if (!hostWindow)
            return;

        // 1) iconRect position in *hostWindow* coordinates,
        //    NOT global (null) coordinates:
        var topLeft = iconRect.mapToItem(hostWindow, 0, 0)

        // 2) Y: put list above the button
        var y = topLeft.y - clampedHeight

        // If there isn't enough room above, open below instead
        if (y -Math.round(20 * s) < 0) {
            y = topLeft.y + iconRect.height
        }
        listY = y - Math.round(20 * s)

        // 3) X: center popup horizontally over the icon
        var desiredX = topLeft.x + (iconRect.width - iconListRect.width) / 2

        // 4) Clamp horizontally so it stays inside hostWindow
        var maxX = hostWindow.width - iconListRect.width
        if (desiredX < 0)
            desiredX = 0
        else if (desiredX > maxX)
            desiredX = maxX

        listX = desiredX

        console.log("POPUP: listX =", listX, "listY =", listY,
                    "iconRect:", iconRect.width, iconRect.height,
                    "popup:", iconListRect.width, iconListRect.height)
    }

}
