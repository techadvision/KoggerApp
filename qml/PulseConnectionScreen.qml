import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

// THE CONNECTION SCREEN - step 1 of the Stage 4 build.
// See docs/pulse-ui/pulse-ui-strategy.md, "Prototyping complete - where the build starts".
//
// This replaces echoSounderSelectorRect / freeContainer / the two EchoSounderSelector
// panels and the windowShadow sheet that used to live at the foot of main.qml. It is a
// PulseApp*-level component rather than a main.qml block, and it is instantiated ONCE
// above both Plot2D panes - which is what lets step 3 move the swap prompt here and
// retire its `indx === 1` gate, since one surface above both panes cannot draw twice.
//
// STEP 1 IS THE SELECTION ONLY. The wire strip, the swap prompt, the source chip and the
// demo/recording pills are all drawn in the prototype and all belong to later steps:
//   step 2  the card list moves into the profile map, asserted by pulse-profile-check.js
//   step 3  the swap prompt moves off PulseAppClassic, and the wire strip gets its states
//   step 4  the rail's source button and the demo indicator, which wait for PulseAppV2
//
// THE ONE BINDING. `windowShadow` was a plain bool written by four handlers: raised by
// selectorDelayTimer.onTriggered and onSwapDeviceNowChanged, lowered by
// onDevManualSelectedChanged and onDevConfiguredChanged. Force reselection commits
// nothing, so neither lowering path ran and the sheet was raised with nothing under it -
// backlog item 10. All four are gone; `chooserAsking` below is the whole answer, which is
// last session's rule 2 (one binding and one override, never an assignment) applied
// before the bug exists rather than after.
Item {
    id: connectionScreen

    anchors.fill: parent
    z: 9000

    // main.qml passes mainview.s and the Android insets.
    property real uiScale:   1.0
    property real safeTop:    0
    property real safeBottom: 0
    property real safeLeft:   0
    property real safeRight:  0

    // main.qml's insetTop() answers 0 unless DeX is on, because the app deliberately
    // draws full-bleed under the status bar. That is right for an echogram and wrong for
    // a title: in the split-screen report the header sat under the clock. This screen
    // keeps a floor under it on Android and nowhere else.
    readonly property bool onAndroid: Qt.platform.os === "android"
    readonly property real topInset:
        Math.max(safeTop, onAndroid ? Math.round(34 * uiScale) : 0)

    // ---- The question -------------------------------------------------------

    // "..." is the app's own word for "nothing is identified". It is what DeviceItem
    // puts userManualSetName back to on a swap or a force reselection, and what a cold
    // start begins with.
    readonly property bool nothingIdentified:
        pulseRuntimeSettings ? pulseRuntimeSettings.userManualSetName === "..." : false

    // WHEN THE GRACE WINDOW IS NEEDED, AND WHEN IT IS IN THE WAY.
    //
    // It exists so the cards cannot flash during an automatic swap: acceptDeviceSwap()
    // clears userManualSetName and commits the target in the same synchronous pass, and
    // a cold start with a transducer already powered on identifies it a moment later.
    // Both of those have something that will answer.
    //
    // With nothing connected and nothing ever committed, NOTHING is going to answer, so
    // waiting is pure delay - which is what showed up on device as the screen arriving
    // after the echogram. That case opens instantly.
    readonly property bool somethingMayStillAnswer:
        (pulseRuntimeSettings ? pulseRuntimeSettings.hasConnectedDevice : false)
        || lastCommittedModel !== ""

    // A latch, not a value with two sources: the timer is the only thing that raises it
    // and re-arming is the only thing that lowers it.
    property bool graceElapsed: false

    readonly property bool chooserAsking:
           (pulseRuntimeSettings ? pulseRuntimeSettings.swapDeviceNow : false)
        || (nothingIdentified
            && !(pulseRuntimeSettings ? pulseRuntimeSettings.isPresentingLog : false)
            && (graceElapsed || !somethingMayStillAnswer))
    // STEP 3 adds `|| pulseRuntimeSettings.deviceSwapPending` here, at the same time as
    // the prompt itself moves onto this surface. Adding the term now would raise this
    // screen over a swap prompt that is still drawn in PulseAppClassic, which is a
    // regression rather than a step.

    visible: chooserAsking
    enabled: chooserAsking

    // ---- What can be gone back to -------------------------------------------

    // The last thing the app was actually configured for. It is what makes cancelling
    // possible, and it is why this screen can never strand itself: every way out of it
    // commits a model, so `nothingIdentified` cannot stay true behind a raised sheet.
    property string lastCommittedModel: ""
    readonly property bool canCancel: lastCommittedModel !== ""

    // Which CARD was tapped. Not derivable from the committed model - red and black are
    // two cards on one profile, which is the whole point of the card list.
    property string chosenCardId: ""

    // ---- The cards ----------------------------------------------------------
    //
    // Data, not code. Two entries can share one profile: red and black are the same
    // hardware at 510 / 710 / 810 kHz, and the owner still gets to pick the one he
    // bought. A new model is one more entry. In step 2 this list moves into the profile
    // map beside ui.views / ui.cones, in exactly this shape, and pulse-profile-check.js
    // asserts it the way it already asserts the view list.
    readonly property var cards: !pulseRuntimeSettings ? [] : [
        { "id": "red",   "name": "PULSE red",   "tagline": "2D echo sounder",
          "art": "./image/pulse_device_red.png",   "badge": "#d81f26",
          "profile": pulseRuntimeSettings.modelPulseRed  },
        { "id": "black", "name": "PULSE black", "tagline": "True downscan",
          "art": "./image/pulse_device_black.png", "badge": "#6d7480",
          "profile": pulseRuntimeSettings.modelPulseRed  },
        { "id": "blue",  "name": "PULSE blue",  "tagline": "Side scan",
          "art": "./image/pulse_device_blue.png",  "badge": "#3d7fd0",
          "profile": pulseRuntimeSettings.modelPulseBlue }
    ]

    // ---- Layout -------------------------------------------------------------
    //
    // Two shapes, one breakpoint, and it always scrolls if it has to. The breakpoint is
    // measured in DESIGN units (pixels divided by uiScale), so it means the same thing on
    // a phone, on a tablet and in an Android split screen - which is what "adapt to the
    // available size" has to mean when the same app runs on all three.
    //
    //   wide    render above the wordmark, as many cards per row as fit
    //   narrow  render beside the wordmark, one card per row
    //
    // Nothing is ever clipped: the whole thing lives in a Flickable that centres its
    // content when it fits and scrolls when it does not. The split screen in the report
    // cut PULSE blue in half; a phone in portrait would have been worse.
    readonly property real pad: Math.round(18 * uiScale)
    readonly property real gap: Math.round(12 * uiScale)

    readonly property real availW: Math.max(0, width  - safeLeft - safeRight - pad * 2)
    readonly property real availH: Math.max(0, height - topInset - safeBottom - pad * 2)

    readonly property real duW: uiScale > 0 ? availW / uiScale : availW
    readonly property real duH: uiScale > 0 ? availH / uiScale : availH

    readonly property bool wide: duW >= 620 && duH >= 340
    readonly property bool stacked: wide

    readonly property int perRow:
        wide ? Math.max(1, Math.min(cards.length, Math.floor(duW / 212))) : 1

    readonly property real cardW:
        wide ? Math.min(Math.round(260 * uiScale), (availW - (perRow - 1) * gap) / perRow)
             : Math.min(availW, Math.round(420 * uiScale))

    readonly property real artH:
        wide ? Math.min(Math.round(cardW * 0.88), Math.round(availH * 0.38))
             : Math.max(Math.round(52 * uiScale),
                        Math.min(Math.round(92 * uiScale), Math.round(availH * 0.16)))

    // ---- Behaviour ----------------------------------------------------------

    Timer {
        id: graceTimer
        interval: 1200
        repeat: false
        running: true               // the app's own start is the first grace window
        onTriggered: connectionScreen.graceElapsed = true
    }

    onNothingIdentifiedChanged: {
        if (nothingIdentified) {
            graceElapsed = false
            graceTimer.restart()
        }
    }

    Connections {
        target: pulseRuntimeSettings ? pulseRuntimeSettings : undefined
        function onUserManualSetNameChanged() {
            if (pulseRuntimeSettings.userManualSetName !== "...")
                connectionScreen.lastCommittedModel = pulseRuntimeSettings.userManualSetName
        }
    }

    onChooserAskingChanged: {
        console.log("CONN_SCREEN: asking ->", chooserAsking,
                    "| committed", pulseRuntimeSettings ? pulseRuntimeSettings.userManualSetName : "?",
                    "| swapNow", pulseRuntimeSettings ? pulseRuntimeSettings.swapDeviceNow : "?",
                    "| presentingLog", pulseRuntimeSettings ? pulseRuntimeSettings.isPresentingLog : "?",
                    "| mayStillAnswer", somethingMayStillAnswer,
                    "| grace", graceElapsed,
                    "| canCancel", canCancel)
    }

    Component.onCompleted:
        console.log("CONN_SCREEN: built", cards.length, "cards | uiScale", uiScale)

    // Committing a card writes userManualSetName and nothing else, so the whole
    // configuration path behaves exactly as it did through the old selectors.
    function commitCard(card) {
        if (!pulseRuntimeSettings || !card)
            return

        chosenCardId = card.id

        // Carried over VERBATIM from the old blue selector's onSelected, including the
        // order: these three are seeded before the commit, and committing is what starts
        // the configuration pass. (The maximumDepth assignment here is the third of the
        // three writers named in backlog item 11 - parked on purpose, not touched here.)
        if (card.profile === pulseRuntimeSettings.modelPulseBlue) {
            pulseRuntimeSettings.chartResolution = pulseSettings.echogramWidth
            pulseRuntimeSettings.distMax         = 1000 * pulseSettings.echogramWidth
            pulseRuntimeSettings.maximumDepth    = pulseSettings.echogramWidth
        }

        // With a device attached DeviceItem has already cleared this synchronously. With
        // nothing attached there is no DeviceItem to clear it, and a latched swapDeviceNow
        // would hold this screen open and make onNumberOfDatasetChannelsChanged return
        // early for the rest of the run.
        pulseRuntimeSettings.swapDeviceNow = false

        console.log("CONN_SCREEN: card", card.id, "-> committing", card.profile)
        pulseRuntimeSettings.userManualSetName = card.profile
        pulseRuntimeSettings.devManualSelected = true
    }

    // Cancel means "I meant to keep what I had". A force reselection has already cleared
    // every setup state, so keeping it re-commits the same model and re-runs the same
    // configuration pass the card would have - it is a choice, not an undo.
    function keepCurrent() {
        if (!pulseRuntimeSettings || !canCancel)
            return
        console.log("CONN_SCREEN: cancelled - keeping", lastCommittedModel)
        pulseRuntimeSettings.swapDeviceNow = false
        pulseRuntimeSettings.userManualSetName = lastCommittedModel
        pulseRuntimeSettings.devManualSelected = true
    }

    // ---- Surface ------------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: "#0b0d11"
        opacity: 0.96
    }

    // Nothing underneath this screen is reachable while it is asking.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel.accepted = true
    }

    Flickable {
        id: flick

        anchors.fill: parent
        anchors.topMargin:    connectionScreen.topInset   + connectionScreen.pad
        anchors.bottomMargin: connectionScreen.safeBottom + connectionScreen.pad
        anchors.leftMargin:   connectionScreen.safeLeft   + connectionScreen.pad
        anchors.rightMargin:  connectionScreen.safeRight  + connectionScreen.pad

        clip: true
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        // Centres the content when it fits (content.y > 0 pushes it down and the two
        // margins make contentHeight equal the viewport, so there is nothing to scroll)
        // and scrolls when it does not (content.y clamps to 0).
        contentHeight: content.height + content.y * 2

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: content
            width: flick.width
            y: Math.max(0, (flick.height - height) / 2)
            spacing: Math.round(6 * connectionScreen.uiScale)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Pulse Echo Sounder"
                color: "#f2f4f7"
                font.pixelSize: Math.round(26 * connectionScreen.uiScale)
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                bottomPadding: Math.round(10 * connectionScreen.uiScale)
                text: connectionScreen.canCancel ? "Choose your sounder"
                                                 : "Which sounder are you using?"
                color: "#9aa3ae"
                font.pixelSize: Math.round(15 * connectionScreen.uiScale)
            }

            Flow {
                anchors.horizontalCenter: parent.horizontalCenter
                // NOT a plain `width` inside a ColumnLayout - a Layout overwrites it with
                // the implicit width, which for a Flow is not the row width, and every
                // card then wrapped onto its own line however much room there was. This
                // Column positions children in y only, so the width below is the truth.
                width: Math.min(content.width,
                                connectionScreen.perRow * connectionScreen.cardW
                                + (connectionScreen.perRow - 1) * connectionScreen.gap)
                spacing: connectionScreen.gap

                Repeater {
                    model: connectionScreen.cards

                    delegate: Rectangle {
                        id: card

                        readonly property var rec: modelData
                        readonly property bool isChosen: connectionScreen.chosenCardId === rec.id

                        width:  connectionScreen.cardW
                        height: cardGrid.implicitHeight + connectionScreen.pad
                        radius: Math.round(12 * connectionScreen.uiScale)
                        color:  cardArea.pressed ? "#1e232b" : "#15181d"
                        border.width: Math.max(1, Math.round(1.5 * connectionScreen.uiScale))
                        border.color: (card.isChosen || cardArea.pressed) ? rec.badge : "#2b3038"

                        GridLayout {
                            id: cardGrid
                            anchors.centerIn: parent
                            width: card.width - connectionScreen.pad
                            columns: connectionScreen.stacked ? 1 : 2
                            columnSpacing: Math.round(12 * connectionScreen.uiScale)
                            rowSpacing:    Math.round(10 * connectionScreen.uiScale)

                            // The hardware, contained and never cropped. A cylinder, a
                            // wide block and a wedge are three very different aspect
                            // ratios, so each keeps its own shape at a common height. The
                            // plate is light because the hardware is dark grey and black -
                            // on a dark card the downscan block would simply disappear.
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                Layout.preferredHeight: connectionScreen.artH
                                Layout.preferredWidth: connectionScreen.stacked
                                                       ? cardGrid.width
                                                       : Math.round(connectionScreen.artH * 1.35)
                                radius: Math.round(8 * connectionScreen.uiScale)
                                clip: true
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#f5f6f7" }
                                    GradientStop { position: 1.0; color: "#dbdde0" }
                                }

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: Math.round(8 * connectionScreen.uiScale)
                                    anchors.bottomMargin: Math.round(12 * connectionScreen.uiScale)
                                    source: card.rec.art
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                    // Three small PNGs out of the qrc. Decoding them on
                                    // the loading thread is what made the screen assemble
                                    // itself after it was already on top of the echogram.
                                    asynchronous: false
                                    cache: true
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: Math.max(3, Math.round(4 * connectionScreen.uiScale))
                                    color: card.rec.badge
                                }
                            }

                            // The wordmark stays LIVE TEXT, never baked into the image.
                            // The old pulse_info_* artwork had the lettering in the
                            // pixels, so enlarging a card enlarged the lettering as pixels
                            // and it went to mush. Text that is text survives every size.
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(2 * connectionScreen.uiScale)

                                Text {
                                    Layout.fillWidth: true
                                    text: card.rec.name
                                    color: "#f2f4f7"
                                    font.pixelSize: Math.round(19 * connectionScreen.uiScale)
                                    font.bold: true
                                    elide: Text.ElideRight
                                    horizontalAlignment: connectionScreen.stacked
                                                         ? Text.AlignHCenter : Text.AlignLeft
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: card.rec.tagline
                                    color: "#8d96a2"
                                    font.pixelSize: Math.round(13 * connectionScreen.uiScale)
                                    elide: Text.ElideRight
                                    horizontalAlignment: connectionScreen.stacked
                                                         ? Text.AlignHCenter : Text.AlignLeft
                                }
                            }
                        }

                        MouseArea {
                            id: cardArea
                            anchors.fill: parent
                            onClicked: connectionScreen.commitCard(card.rec)
                        }
                    }
                }
            }

            // Cancelling is possible whenever there is something to go back to. On a cold
            // start there is not, and the screen correctly offers no way out but a choice.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: connectionScreen.canCancel
                width:  keepPill.width
                height: connectionScreen.canCancel
                        ? keepPill.height + Math.round(18 * connectionScreen.uiScale) : 0

                Rectangle {
                    id: keepPill
                    anchors.bottom: parent.bottom
                    implicitWidth:  keepLabel.implicitWidth + Math.round(36 * connectionScreen.uiScale)
                    implicitHeight: Math.round(44 * connectionScreen.uiScale)
                    width:  implicitWidth
                    height: implicitHeight
                    radius: height / 2
                    color: keepArea.pressed ? "#2a303a" : "#1b1f26"
                    border.width: 1
                    border.color: "#3a414b"

                    Text {
                        id: keepLabel
                        anchors.centerIn: parent
                        text: "Keep " + (pulseRuntimeSettings
                                         ? pulseRuntimeSettings.modelDisplayName(connectionScreen.lastCommittedModel)
                                         : "")
                        color: "#dfe4ea"
                        font.pixelSize: Math.round(15 * connectionScreen.uiScale)
                    }

                    MouseArea {
                        id: keepArea
                        anchors.fill: parent
                        onClicked: connectionScreen.keepCurrent()
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: Math.round(14 * connectionScreen.uiScale)
                text: "This closes by itself when the sounder is recognised."
                color: "#69727d"
                font.pixelSize: Math.round(12 * connectionScreen.uiScale)
                visible: connectionScreen.duH > 300
            }
        }
    }
}
