import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Item {
    id: root
    width: 155; height: 80
    property int selectedIndex: 0
    property var model: []
    signal iconSelected(int index)
    property string iconSource: ""
    property bool dragging: false

    property bool longPressed: false
    Timer {
        id: longPressTimer;
        interval: 800;
        repeat: false
        onTriggered: {
            root.longPressed = true
            selectionPopup.open()
        }
    }

    // ————————————————————————————— REPLACE your old Popup { … } block with this —
    Popup {
        id: selectionPopup
        modal: true
        focus: true

        // how many icons to show at once
        property int visibleItems: 5
        // margins & spacing
        property int itemMargin: 5
        property int itemSpacing: 10
        // full content height if un-clipped
        property int fullContentHeight:
            model.length * iconRect.height
          + (model.length - 1) * itemSpacing
          + 2 * itemMargin

        width: 92
        // clamp height to at most visibleItems
        height: Math.min(
            fullContentHeight,
            visibleItems * iconRect.height
          + (visibleItems - 1) * itemSpacing
          + 2 * itemMargin
        )

        // fade out the current icon while open
        onOpened: {
            iconRect.opacity = 0

            // same positioning logic as before
            x = iconRect.mapToItem(root, 0, 0).x + iconRect.width/2 - width/2

            var top   = iconRect.mapToItem(root, 0, 0).y
            var ideal = top + iconRect.height/2
                      - ((root.selectedIndex)*iconRect.height + iconRect.height/2)
                      - 20
            var minY  = top + iconRect.height - height
            var maxY  = top
            y = Math.min(maxY, Math.max(minY, ideal))
        }
        onClosed: {
            iconRect.opacity = 1
        }

        // when user releases drag, pick the icon overlapping the rect most
        Timer {
            id: selectionTimer
            interval: 2000; repeat: false
            onTriggered: {
                var bestIdx     = 0
                var bestOverlap = -1
                // iconRect bounds in contentItem coordinates
                var rectTop    = iconRect.mapToItem(contentItem, 0, 0).y
                var rectBottom = rectTop + iconRect.height
                var offsetY    = iconsColumn.y

                for (var i = 0; i < model.length; ++i) {
                    var itemTop    = itemMargin
                                   + i * iconRect.height
                                   + i * itemSpacing
                                   + offsetY
                    var itemBottom = itemTop + iconRect.height
                    var overlap    = Math.min(itemBottom, rectBottom)
                                   - Math.max(itemTop,     rectTop)
                    if (overlap > bestOverlap) {
                        bestOverlap = overlap
                        bestIdx     = i
                    }
                }
                bestIdx = Math.max(0, Math.min(model.length - 1, bestIdx))
                root.selectedIndex = bestIdx
                root.iconSelected(bestIdx)
                selectionPopup.close()
            }
        }

        // ——— clipped viewport + scrollable column —————————————————
        Item {
            id: contentItem
            anchors.fill: parent
            clip: true

            // semi-transparent rounded background
            Rectangle {
                anchors.fill: parent
                color: "#80000000"
                radius: 5
            }

            // the list of icons we actually scroll
            Column {
                id: iconsColumn
                anchors {
                    top:    contentItem.top
                    bottom: contentItem.bottom
                    left:   contentItem.left
                    right:  contentItem.right
                }
                anchors.margins: selectionPopup.itemMargin
                spacing: selectionPopup.itemSpacing

                Repeater {
                    model: root.model
                    delegate: Item {
                        width: parent.width     // full width inside margins
                        height: iconRect.height

                        // the icon
                        Image {
                            anchors.centerIn: parent
                            source: modelData
                            width: iconRect.height
                            height: iconRect.height
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        // tap to select immediately
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!root.dragging) {
                                    root.selectedIndex = index
                                    root.iconSelected(index)
                                    selectionPopup.close()
                                    selectionTimer.stop()
                                }
                            }
                        }
                    }
                }
            }

            // suppress tiny jiggles
            Timer {
                id: dragSuppressTimer
                interval: 300; repeat: false
                onTriggered: { root.dragging = false }
            }

            // drag anywhere to scroll iconsColumn
            MouseArea {
                anchors.fill: parent
                z: 1
                property real startY: 0
                property real origY:   0
                property real dragMin:  0
                property real dragMax:  0

                onPressed: {
                    root.dragging = false
                    startY = mouse.y
                    origY  = iconsColumn.y
                    // allow full scroll range
                    dragMin = Math.min(0, contentItem.height - iconsColumn.height)
                    dragMax = 0
                }
                onPositionChanged: {
                    var dy = mouse.y - startY
                    if (Math.abs(dy) > 1) {
                        root.dragging = true
                        dragSuppressTimer.restart()
                        iconsColumn.y =
                            Math.min(dragMax,
                                     Math.max(dragMin, origY + dy))
                    }
                }
                onReleased: {
                    selectionTimer.restart()
                    dragSuppressTimer.start()
                }
            }
        } // — end contentItem
    }
    // ————————————————————————————— end Popup block



    /*

    Popup {
        id: selectionPopup
        modal: true; focus: true
        width: 92
        height: model.length * iconRect.height + model.length * 10
        background: Rectangle {
            color: "transparent"
            border.width: 0
        }

        // Selection timer
        Timer {
            id: selectionTimer
            interval: 2000; repeat: false
            onTriggered: {
                // choose icon overlapping iconRect most
                var bestIdx = 0;
                var bestOverlap = -1;
                // iconRect bounds in contentItem coords
                var rectTop = iconRect.mapToItem(contentItem, 0, 0).y;
                var rectBottom = rectTop + iconRect.height;
                for (var i = 0; i < model.length; ++i) {
                    // item bounds: y start at margin 5
                    var itemTop = 5 + i * iconRect.height;
                    var itemBottom = itemTop + iconRect.height;
                    var overlap = Math.min(itemBottom, rectBottom) - Math.max(itemTop, rectTop);
                    if (overlap > bestOverlap) {
                        bestOverlap = overlap;
                        bestIdx = i;
                    }
                }
                bestIdx = Math.max(0, Math.min(model.length - 1, bestIdx));
                root.selectedIndex = bestIdx;
                root.iconSelected(bestIdx);
                selectionPopup.close();
            }
        }

        onOpened: {
            iconRect.opacity = 0
            x = iconRect.mapToItem(root, 0, 0).x + iconRect.width/2 - width/2
            var top = iconRect.mapToItem(root, 0, 0).y
            var idealY = top + iconRect.height/2 - (root.selectedIndex * iconRect.height + iconRect.height/2) - 20
            var minY = top + iconRect.height - height
            var maxY = top
            y = Math.min(maxY, Math.max(minY, idealY))
            console.log("selectionPopu_old: minY", minY)
            console.log("selectionPopu_old: maxY", maxY)
            console.log("selectionPopu_old: idealY", idealY)
            console.log("selectionPopu_old: y", y)

        }

        onClosed: { iconRect.opacity = 1 }

        // Draggable background & content container
        Item {
        id: contentItem
        anchors.fill: parent

        // background
        Rectangle {
            anchors.fill: parent; color: "#80000000"; radius: 5; border.width: 0
        }

        Timer {
            id: dragSuppressTimer
            interval: 300
            repeat: false
            onTriggered: { root.dragging = false }
        }

        // manual drag
        MouseArea {
            anchors.fill: parent; z: 1
            property real startY: 0; property real origY: 0
            property real dragMin: 0; property real dragMax: 0
            propagateComposedEvents: true
            onPressed: {
                root.dragging = false
                startY = mouse.y
                origY = selectionPopup.y
                var top = iconRect.mapToItem(root, 0, 0).y
                var bottom = top + iconRect.height
                dragMin = bottom - selectionPopup.height
                dragMax = top
            }
            onPositionChanged: {
                var dy = mouse.y - startY
                if (Math.abs(dy) > 1) {
                    root.dragging = true
                    dragSuppressTimer.restart()
                    selectionPopup.y = Math.min(dragMax, Math.max(dragMin, origY + dy))
                }
            }
            onReleased: {
                selectionTimer.restart()
                dragSuppressTimer.start()
            }
        }


        // icons list
        Column {
            anchors.fill: parent;
            anchors.margins: 5;
            spacing: 0
            Repeater {
                model: root.model;
                delegate:
                    Item {
                        width: parent.width;
                        height: iconRect.height
                        Rectangle {
                            width: 80;
                            height: 80;
                            anchors.centerIn: parent;
                            color: "transparent";
                            radius: 5
                            Image {
                                anchors.fill: parent;
                                source: modelData;
                                fillMode: Image.PreserveAspectFit;
                                smooth: true
                            }
                        }
                        MouseArea {
                            anchors.fill: parent;
                            onClicked: {
                                if (!root.dragging) {
                                    root.selectedIndex = index;
                                    root.iconSelected(index);
                                    selectionPopup.close()
                                    selectionTimer.stop()
                                    console.log("Icon select in repeater");
                                }
                            }
                        }
                    }
                }
            }
        } // end of Popup contentItem
    } // end of Popup

    */

    Rectangle {
        id: outerShape;
        width: parent.width;
        height: parent.height;
        radius: height/2
        color: "#80000000";
        border.width: 2;
        border.color: "transparent"
        RowLayout {
            anchors.centerIn: parent;
            spacing: 10
            Image {
                id: controlIcon;
                Layout.preferredWidth: 42;
                Layout.preferredHeight: 42
                source: root.iconSource;
                fillMode: Image.PreserveAspectFit
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft;
                Layout.leftMargin: 6
            }
            Rectangle {
                id: iconRect;
                width: 80;
                height: 80;
                radius: 5;
                color: "transparent"
                Image {
                    anchors.centerIn: parent;
                    source: model[selectedIndex]
                    width: 80;
                    height: 80;
                    fillMode: Image.PreserveAspectFit;
                    smooth: true
                }
                MouseArea {
                    anchors.fill: parent
                    onPressed: { root.longPressed = false; longPressTimer.start() }
                    onReleased: {
                        longPressTimer.stop()
                        selectionTimer.stop()
                        if (!root.longPressed) {
                            console.log("Icon select OK");
                            root.selectedIndex = (root.selectedIndex + 1) % model.length
                            root.iconSelected(root.selectedIndex)
                        } else {
                            console.log("Icon select not possible, is long pressed");
                        }
                    }
                }
            }
        }
    }
}
