import QtQuick 2.15

// THE INDICATOR PILLS (Stage 4 a) - what the echogram on screen actually IS, and the way
// out of it.
//
// WHICH CORNER FOLLOWS THE FLOW, which is rule 1 applied to placement: a side scan flows
// downward and its newest pings are at the top, so every overlay belongs at the FOOT; a 2D
// picture flows sideways and its overlays sit at the TOP, clear of the bottom return. That
// is the display model's question, never the committed one - with a blue log presenting on
// a committed red, the pill must sit where the PICTURE says.
//
// ONE INSTANCE ABOVE BOTH PANES. Everything it reports is app-wide rather than pane-wide -
// a demo is running or it is not - so it is hosted in main.qml beside the rail rather than
// inside PulseAppV2, which is built once per pane.
Item {
    id: pillColumn

    property real uiScale:    1.0
    property real safeTop:    0
    property real safeBottom: 0
    property real safeRight:  0

    // RULE 1: what the PICTURE is, never what is connected.
    property bool displayIs2D: true

    property bool   presentingLog:  false
    property bool   isDemo:         false
    property string presentedName:  ""

    signal stopDemo()
    signal closeFile()

    // Same floor as the rail and the connection screen: main.qml's insetTop() answers 0
    // unless DeX is on, because the app draws full-bleed under the status bar. Right for
    // the picture, wrong for a control - and on a 2D echogram this column sits at the top.
    readonly property bool onAndroid: Qt.platform.os === "android"
    readonly property real topInset: Math.max(safeTop, onAndroid ? Math.round(34 * uiScale) : 0)

    // A positioner, not a Layout - so a plain width on a child is correct throughout this
    // file, and an invisible pill simply takes no space.
    Column {
        id: stack

        anchors.right: parent.right
        anchors.rightMargin: pillColumn.safeRight + Math.round(16 * pillColumn.uiScale)

        anchors.top:    pillColumn.displayIs2D ? parent.top : undefined
        anchors.bottom: pillColumn.displayIs2D ? undefined  : parent.bottom
        anchors.topMargin:    pillColumn.topInset    + Math.round(14 * pillColumn.uiScale)
        anchors.bottomMargin: pillColumn.safeBottom  + Math.round(14 * pillColumn.uiScale)

        spacing: Math.round(10 * pillColumn.uiScale)

        // WHAT THE APP IS PRESENTING AS. This is backlog item 8's claim made visible: with
        // nothing connected, the log decides the whole interface, so the app is calling
        // itself a device it is not connected to. At a stand somebody will ask, and this is
        // the answer.
        Rectangle {
            id: logPill

            visible: pillColumn.presentingLog
            height:  Math.round(46 * pillColumn.uiScale)
            width:   pillRow.width + Math.round(28 * pillColumn.uiScale)
            radius:  height / 2

            color: "#cc0f1317"
            border.width: 1
            border.color: "#3d7fd0"

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: Math.round(12 * pillColumn.uiScale)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // Olav's words for the two cases. "Demo" is a paced replay the app
                    // experiences as a live connection; "Viewing recording" is a file being
                    // rendered. They are genuinely different states - one closed the links
                    // on its way in and the other did not - so they are not one word.
                    text: (pillColumn.isDemo ? qsTr("Demo") : qsTr("Viewing recording"))
                          + (pillColumn.presentedName === ""
                             ? "" : "   ·   " + pillColumn.presentedName)
                    color: "#eaf1f8"
                    font.pixelSize: Math.round(17 * pillColumn.uiScale)
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width:  1
                    height: Math.round(24 * pillColumn.uiScale)
                    color: "#30ffffff"
                }

                // A WORD, NOT A GLYPH. The rail's arrow already proved what a glyph costs
                // when one symbol can mean two consequences: it was tapped expecting the
                // rail to hide and it left the whole UI. Stopping a demo and closing a file
                // are different acts on different machinery, so they say which they are.
                Rectangle {
                    id: actionButton

                    anchors.verticalCenter: parent.verticalCenter
                    width:  actionLabel.width + Math.round(26 * pillColumn.uiScale)
                    height: Math.round(34 * pillColumn.uiScale)
                    radius: height / 2
                    color: actionArea.pressed ? "#2f7fb5" : "#1d3446"
                    border.width: 1
                    border.color: "#3d7fd0"

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: pillColumn.isDemo ? qsTr("Stop") : qsTr("Close")
                        color: "#cfe0f2"
                        font.pixelSize: Math.round(16 * pillColumn.uiScale)
                        font.bold: true
                    }

                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        onClicked: {
                            if (pillColumn.isDemo)
                                pillColumn.stopDemo()
                            else
                                pillColumn.closeFile()
                        }
                    }
                }
            }
        }
    }
}
