import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root;
    width: 155;
    height: 80
    property int selectedIndex: 0
    property var model: []
    signal iconSelected(int index)
    property bool longPressed: false
    property string iconSource: ""

    Timer {
        id: longPressTimer;
        interval: 800;
        repeat: false
        onTriggered: { root.longPressed = true; selectionPopup.open() }
    }

    Popup {
        id: selectionPopup
        modal: true;
        focus: true
        clip: true

        width: 92
        height: model.length * (iconRect.height + 10)

        // internal clamp bounds
        property real dragMin: 0
        property real dragMax: 0

        background: Rectangle {
            color: "transparent"
        }

        onOpened: {
            iconRect.opacity = 0

            // global pos of the bottom icon
            var pos = iconRect.mapToItem(root, 0, 0)
            var top = pos.y
            var left = pos.x

            // popup may not go above/below the bottom icon
            dragMax = top
            dragMin = top + iconRect.height - height

            console.log("selectionPopup: dragMax", dragMax)
            console.log("selectionPopup: dragMin", dragMin)
            console.log("selectionPopup: height", selectionPopup.height)

            // center horizontally over iconRect
            x = left + (iconRect.width - width)/2 -10

            // center the selected icon under iconRect:
            // popup.y + 5px margin + index*iconHeight + iconHeight/2 == top + iconHeight/2
            // ⇒ popup.y = top - (5 + index*iconHeight)
            var idealY = top - (5 + root.selectedIndex * iconRect.height) -15
            y = Math.min(dragMax, Math.max(dragMin, idealY))
            console.log("selectionPopup: idealY", idealY)
            console.log("selectionPopup: y", y)
        }

        onClosed: {
            iconRect.opacity = 1
        }

        // your exact same overlap-based selection logic:
       Timer {
           id: selectionTimer
           interval: 2000
           repeat: false
           onTriggered: {
               var bestIdx = 0, bestOverlap = -1
               var rectTop    = iconRect.mapToItem(contentItem, 0, 0).y
               var rectBottom = rectTop + iconRect.height

               for (var i = 0; i < model.length; ++i) {
                   var itemTop    = 5 + i * iconRect.height
                   var itemBottom = itemTop + iconRect.height
                   var overlap = Math.min(itemBottom, rectBottom)
                               - Math.max(itemTop,    rectTop)
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

        // everything else exactly as before, unchanged:
        Item {
            id: contentItem
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                color: "#80000000"
                radius: 5
            }

            Column {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 0

                Repeater {
                    model: root.model
                    delegate: Item {
                        width: iconRect.width
                        height: iconRect.height

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            radius: 5
                            width: 80
                            height: 80

                            Image {
                                anchors.fill: parent
                                source: modelData
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                width: 80
                                height: 80
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
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

        // drag the Popup itself, clamped to dragMin/dragMax:
        MouseArea {
            z: 99
            anchors.fill: parent
            drag.target:   selectionPopup ? selectionPopup : undefined
            drag.axis:     Drag.YAxis
            drag.minimumY: selectionPopup.dragMin
            drag.maximumY: selectionPopup.dragMax

            // stop/start the snap-timer just like before
            onPressed:  selectionTimer.stop()
            onReleased: selectionTimer.restart()

            // let clicks through to the icon MouseAreas
            propagateComposedEvents: true
        }
    }

    Rectangle {
        id: outerShape
        width: parent.width;
        height: parent.height
        radius: height/2;
        color: "#80000000";
        border.width: 2
        border.color: "transparent"
        RowLayout {
            anchors.centerIn: parent;
            spacing: 10
            Image {
                id: controlIcon;
                Layout.preferredWidth: 42;
                Layout.preferredHeight: 42
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
            }
            Rectangle {
                id: iconRect;
                width: 80;
                height: 80;
                radius: 5;
                color: "transparent"
                Image {
                    anchors.centerIn: parent
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
                            root.selectedIndex = (root.selectedIndex + 1) % model.length
                            root.iconSelected(root.selectedIndex)
                        }
                    }
                }
            }
        }
    }
}
