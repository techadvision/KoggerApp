// File: IconSelector.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15
import QtQuick.Window 2.2   // for mapToItem(null, …)

Item {
    id: root
    width: 155
    height: 80

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

        RowLayout {
            anchors.centerIn: parent
            spacing: 5

            // Optional “control” icon on the left
            Image {
                id: controlIcon
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                Layout.leftMargin: 6
            }

            // The rectangle that shows the currently selected item:
            Rectangle {
                id: iconRect
                width: 80
                height: 80
                radius: 5
                color: "transparent"

                Image {
                    anchors.centerIn: parent
                    source: root.model.length > 0
                            ? root.model[root.selectedIndex]
                            : ""
                    width: 80
                    height: 80
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

    property int visibleItems: 5
    property int itemMargin: 5
    property int itemSpacing: 10

    property real listX: 0
    property real listY: 0

    // the “extra” to make one more row half‐visible:
    property int halfRowExtra: (iconRect.height + itemSpacing)/2

    // Un-clamped total height (all rows + spacing + margins):
    property int fullContentHeight:
        (model.length * iconRect.height)
      + ((model.length - 1) * itemSpacing)
      + (2 * itemMargin)

    // Clamped so we show at most `visibleItems` rows:
    /*
    property int clampedHeight: Math.min(
        fullContentHeight,
        (visibleItems * iconRect.height)
      + ((visibleItems - 1) * itemSpacing)
      + (2 * itemMargin)
    )
    */
    property int clampedHeight: {
        var maxFull = (visibleItems * iconRect.height)
                    + ((visibleItems - 1) * itemSpacing)
                    + (2 * itemMargin)
        // “5½” rows:
        var withHalf = maxFull + halfRowExtra

        return Math.min(fullContentHeight, withHalf)
    }

    // ───────────────────────────────────────────────────────────────
    // (C) The List-rectangle, reparented into the real window
    Rectangle {
        id: iconListRect
        parent: hostWindow
        x: listX
        y: listY

        width: iconRect.width +10
        height: clampedHeight
        color: "#C0000000"
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
                width: iconRect.width
                height: iconRect.height

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
                    width: iconRect.width
                    height: iconRect.height
                    anchors.horizontalCenter: iconListView.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
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
        // 1) Get outerShape’s top-left in window coordinates:
        var topLeftInWindow = iconRect.mapToItem(null, 0, 0)
        //var topLeftInWindow = outerShape.mapToItem(null, 0, 0)

        // 2) Set y so that bottom of list = topLeftInWindow.y:
        listY = (topLeftInWindow.y - clampedHeight)
        console.log("POPUP: listY =", listY)

        // 3) Set x so left edges line up, but clamp if off-screen:
        var desiredX = topLeftInWindow.x
        var wW = root.window ? root.window.width : Screen.width
        if (desiredX < 0) {
            desiredX = 0
        }
        if (desiredX + outerShape.width > wW) {
            desiredX = wW - outerShape.width
            if (desiredX < 0) {
                desiredX = 0
            }
        }
        listX = desiredX
        console.log("POPUP: listX =", listX)
    }
}
