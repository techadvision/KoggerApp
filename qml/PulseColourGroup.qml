import QtQuick 2.15

// COLOURS (Stage 4 b, step 1) - the first group in the panel, and the one that could never
// be anything else. A 2D transducer offers twenty themes in dark/bright pairs; twenty
// swatches cannot be a pop-up over the echogram, which is what forced the panel in the
// first place.
//
// ONE ROW PER THEME, not a grid of thumbnails. The canvas asked for "the real ramp rather
// than an icon", and a ramp is judged by its spread: a 120x40 strip shows where a palette
// puts its midtones, and a 48px thumbnail does not. The art is unchanged - these are the
// same gradient files the pop-up uses today, given room.
//
// THIS GROUP KNOWS NOTHING ABOUT THE THREE COLOUR KEYS. It is handed a list and a current
// id and it reports taps. Which key a tap writes is the host's business, and keeping it
// there is what stops a chooser reaching a key that belongs to the other device.
Item {
    id: group

    property real uiScale: 1.0

    property var  entries:   []      // already filtered by the host
    property int  currentId: -1

    // Favourites are a 2D idea: blue has six themes and never needed them.
    // id -> [{pos, color}], supplied by the host. The stops come from the C++ colour table
    // itself, so a row shows the palette the renderer will actually use rather than a
    // picture of it.
    property var  stopsById: ({})

    property bool offerFavourites:  false
    property bool favouritesFilter: false
    property var  favouriteIds:     []

    signal themeChosen(int id)
    signal favouriteToggled(int id)
    signal favouritesFilterToggled()

    implicitHeight: column.height

    Column {
        id: column
        width: group.width
        spacing: Math.round(8 * group.uiScale)

        // THE FILTER, above the list it filters. Its own row rather than a corner icon,
        // because turning it on can empty the list, and a control that can do that should
        // say what it is in words.
        Rectangle {
            visible: group.offerFavourites
            width: parent.width
            height: Math.round(52 * group.uiScale)
            radius: Math.round(10 * group.uiScale)
            color: filterArea.pressed ? "#1d2a36" : "transparent"
            border.width: 1
            border.color: "#28ffffff"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Math.round(14 * group.uiScale)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(12 * group.uiScale)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: group.favouritesFilter ? "★" : "☆"
                    color: group.favouritesFilter ? "#f0c040" : "#8a929c"
                    font.pixelSize: Math.round(22 * group.uiScale)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Show only my favourites")
                    color: "#cfd6de"
                    font.pixelSize: Math.round(16 * group.uiScale)
                }
            }

            MouseArea {
                id: filterArea
                anchors.fill: parent
                onClicked: group.favouritesFilterToggled()
            }
        }

        // NOT AN ERROR, and not a dead end. Turning the filter on with nothing starred is
        // the one way to reach an empty list, so the list says how to leave it.
        Text {
            visible: group.entries.length === 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: qsTr("Nothing is starred yet. Turn the filter off to see every theme, "
                       + "and star the two or three you actually use.")
            color: "#8a929c"
            font.pixelSize: Math.round(15 * group.uiScale)
        }

        Repeater {
            model: group.entries

            Rectangle {
                id: row

                readonly property bool isCurrent:   modelData.id === group.currentId
                readonly property bool isFavourite: group.favouriteIds.indexOf(modelData.id) >= 0

                width:  column.width
                height: Math.round(64 * group.uiScale)
                radius: Math.round(10 * group.uiScale)

                color: rowArea.pressed ? "#2a3644" : (isCurrent ? "#16232e" : "transparent")
                border.width: isCurrent ? 2 : 1
                border.color: isCurrent ? "#3d7fd0" : "#20ffffff"

                // THE RAMP, and it is the real one. qPlot2D::echogramThemeStops(id) is
                // Q_INVOKABLE, already written, and was never called from QML: it hands back
                // the colour table the renderer itself uses, as {pos, color} stops. So the
                // row shows the palette rather than a picture of it, and there is no aspect
                // ratio to preserve - a ramp is supposed to fill its frame.
                //
                // The art these rows carried before is a BADGE, not a gradient: an oval with
                // the vendor's initials in it. Stretching one to 3:1 squashed the oval, which
                // is what Olav caught. The badge survives as the fallback below, for an id
                // the colour table does not know.
                Rectangle {
                    id: rampFrame
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(12 * group.uiScale)
                    anchors.verticalCenter: parent.verticalCenter
                    width:  Math.round(100 * group.uiScale)
                    height: Math.round(40 * group.uiScale)
                    radius: Math.round(6 * group.uiScale)
                    color: "#0b0d11"
                    border.width: 1
                    border.color: "#30ffffff"
                    clip: true

                    readonly property var stops:
                        (group.stopsById && group.stopsById[modelData.id]) ? group.stopsById[modelData.id] : []

                    Canvas {
                        id: rampCanvas
                        anchors.fill: parent
                        anchors.margins: 1
                        visible: rampFrame.stops.length > 0

                        Connections {
                            target: rampFrame
                            function onStopsChanged() { rampCanvas.requestPaint() }
                        }

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()

                            var stops = rampFrame.stops
                            if (!stops || stops.length === 0)
                                return

                            var g = ctx.createLinearGradient(0, 0, width, 0)

                            // addColorStop refuses a position that goes backwards, and a
                            // table is data - it is not this file's job to assume it arrives
                            // sorted. Clamp, and never move backwards.
                            var last = -1
                            for (var i = 0; i < stops.length; ++i) {
                                var p = Math.max(0, Math.min(1, stops[i].pos))
                                if (p < last)
                                    p = last
                                last = p
                                g.addColorStop(p, String(stops[i].color))
                            }

                            ctx.fillStyle = g
                            ctx.fillRect(0, 0, width, height)
                        }
                    }

                    // FALLBACK: the vendor badge, aspect preserved, for a theme whose id the
                    // colour table does not answer for.
                    Image {
                        anchors.fill: parent
                        anchors.margins: Math.round(4 * group.uiScale)
                        visible: rampFrame.stops.length === 0
                        source: modelData.icon
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                }

                Text {
                    anchors.left: rampFrame.right
                    anchors.leftMargin: Math.round(14 * group.uiScale)
                    anchors.right: star.left
                    anchors.rightMargin: Math.round(8 * group.uiScale)
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.title
                    elide: Text.ElideRight
                    color: row.isCurrent ? "#eaf1f8" : "#cfd6de"
                    font.pixelSize: Math.round(16 * group.uiScale)
                    font.bold: row.isCurrent
                }

                // The star is its own target, so starring a theme is not choosing it. On a
                // blue it is absent rather than dim: six themes are not a list you curate.
                Item {
                    id: star
                    visible: group.offerFavourites
                    width:  visible ? Math.round(52 * group.uiScale) : 0
                    height: parent.height
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(6 * group.uiScale)

                    Text {
                        anchors.centerIn: parent
                        text: row.isFavourite ? "★" : "☆"
                        color: row.isFavourite ? "#f0c040" : "#6d7480"
                        font.pixelSize: Math.round(22 * group.uiScale)
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: group.favouriteToggled(modelData.id)
                    }
                }

                MouseArea {
                    id: rowArea
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: star.left
                    onClicked: group.themeChosen(modelData.id)
                }
            }
        }
    }
}
