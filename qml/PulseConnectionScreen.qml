import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtCore

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

    // ---- The link, as one honest line ---------------------------------------
    //
    // Everything below is already computed somewhere: ConnectionViewer publishes
    // linkIsOpen and deviceIsPresent, the device publishes devName, the channel count,
    // the firmware and the serial, and the resolver already has the address. Nothing new
    // is stored - one binding reads facts that four other places were reading anyway.
    //
    // Deliberately NOT phrased around a cable. Practically every PULSE in the field is
    // wireless - the wifi gateway, and the IP connector from the boat onwards - so
    // anything built on "wired" would describe almost nobody. What the owner actually has
    // is a sounder that is not answering, and much the commonest reason is that the thing
    // it is mounted on, a boat or a pole kit, is not switched on yet.
    readonly property bool linkLost:
        pulseRuntimeSettings ? (pulseRuntimeSettings.hasDeviceLostConnection
                                && pulseRuntimeSettings.didEverReceiveData) : false
    readonly property bool linkOpen:
        pulseRuntimeSettings ? pulseRuntimeSettings.linkIsOpen : false
    readonly property bool linkNamed:
        pulseRuntimeSettings ? (pulseRuntimeSettings.devName !== "..."
                                && pulseRuntimeSettings.devName !== "") : false
    readonly property bool linkFound:
        pulseRuntimeSettings ? pulseRuntimeSettings.deviceIsPresent : false

    readonly property string linkState:
          linkLost                ? "lost"
        : (linkOpen && linkNamed) ? "talking"
        : linkOpen                ? "identifying"
        : linkFound               ? "found"
        :                           "absent"

    readonly property color linkColor:
          linkState === "lost"    ? "#ffcc00"
        : linkState === "talking" ? "#3ec46d"
        : linkState === "absent"  ? "#6d7480"
        :                           "#3d7fd0"

    readonly property string linkHeadline:
          linkState === "lost"        ? "Connection lost"
        : linkState === "talking"     ? "Connected to " + pulseRuntimeSettings.devName
        : linkState === "identifying" ? "Connected, identifying the sounder"
        : linkState === "found"       ? "Sounder found, nothing open on it yet"
        :                               "Not connected"

    readonly property string linkDetail: {
        if (!pulseRuntimeSettings)
            return ""
        if (linkState === "lost")
            return "It stopped answering. Power and range are the usual two."
        if (linkState === "talking") {
            var bits = []
            var ch = pulseRuntimeSettings.numberOfDatasetChannels
            if (ch > 0)
                bits.push(ch === 1 ? "1 channel" : ch + " channels")
            if (pulseRuntimeSettings.connectionAddress !== "")
                bits.push(pulseRuntimeSettings.connectionAddress)
            if (pulseRuntimeSettings.rawDev_firmwareVersion !== "not set")
                bits.push("fw " + pulseRuntimeSettings.rawDev_firmwareVersion)
            if (pulseRuntimeSettings.rawDev_devSerialNumber >= 0)
                bits.push("s/n " + pulseRuntimeSettings.rawDev_devSerialNumber)
            return bits.join("   \u00b7   ")
        }
        if (linkState === "identifying")
            return "Waiting for it to say what it is."
        if (linkState === "found")
            return "A device is listed, but nothing has been opened on it yet."
        return "Nothing is answering yet. Power the sounder on - the boat, or the pole "
             + "kit - and this screen closes itself the moment it is recognised."
    }

    // ---- The cards ----------------------------------------------------------
    //
    // Data, not code. Two entries can share one profile: red and black are the same
    // hardware at 510 / 710 / 810 kHz, and the owner still gets to pick the one he
    // bought. A new model is one more entry. In step 2 this list moves into the profile
    // map beside ui.views / ui.cones, in exactly this shape, and pulse-profile-check.js
    // asserts it the way it already asserts the view list.
    readonly property var cards: !pulseRuntimeSettings ? [] : [
        { "id": "red",   "name": "PULSE red",   "tagline": "2D echo sounder",
          "art":  "./image/pulse_device_red.png",
          "logo": "./image/pulse_logo_red.png",    "badge": "#d81f26",
          "profile": pulseRuntimeSettings.modelPulseRed  },
        { "id": "black", "name": "PULSE black", "tagline": "Downscan",
          "art":  "./image/pulse_device_black.png",
          "logo": "./image/pulse_logo_black.png",  "badge": "#6d7480",
          "profile": pulseRuntimeSettings.modelPulseRed  },
        { "id": "blue",  "name": "PULSE blue",  "tagline": "Side scan",
          "art":  "./image/pulse_device_blue.png",
          "logo": "./image/pulse_logo_blue.png",   "badge": "#3d7fd0",
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

    // THE PANEL IS THE MEASURE. The card row decides its width, and the strip above it and
    // the panel itself are then the same width - so the screen reads as one object rather
    // than three things that happen to be centred. Everything below is derived from the
    // width INSIDE the panel, so the cards can never be wider than the box holding them.
    readonly property real panelPad: Math.round(20 * uiScale)
    readonly property real innerW:   Math.max(0, availW - panelPad * 2)

    readonly property int perRow:
        wide ? Math.max(1, Math.min(cards.length,
                                    Math.floor(innerW / Math.round(212 * uiScale)))) : 1

    readonly property real cardW:
        wide ? Math.min(Math.round(260 * uiScale), (innerW - (perRow - 1) * gap) / perRow)
             : Math.min(innerW, Math.round(420 * uiScale))

    readonly property real rowW:   perRow * cardW + (perRow - 1) * gap
    readonly property real panelW: Math.min(availW, rowW + panelPad * 2)

    // The two ways out share the foot of the panel as a CHAIN - equal air at the left
    // edge, between them, and at the right edge - so the simulation button stays centred
    // when it is alone and the pair stays balanced when it is not.
    //
    // Only the caption can break that: it is wider than either button, and on a narrow
    // pane it would push the chain past the panel edge. So it gets a width budget -
    // whatever the row has left once the other button and the three gaps are paid for -
    // and wraps instead of shoving. No second layout and no breakpoint: it degrades by
    // wrapping.
    readonly property real captionMax:
        canCancel ? Math.max(Math.round(160 * uiScale),
                             innerW - keepPill.implicitWidth - Math.round(70 * uiScale))
                  : innerW

    readonly property real artH:
        wide ? Math.min(Math.round(cardW * 0.88), Math.round(availH * 0.38))
             : Math.max(Math.round(52 * uiScale),
                        Math.min(Math.round(92 * uiScale), Math.round(availH * 0.16)))

    readonly property real platePad: Math.round(10 * uiScale)
    readonly property real innerGap: Math.round(8 * uiScale)
    readonly property real badgeH:   Math.max(3, Math.round(4 * uiScale))

    // THE WORDMARK GOES ON THE PLATE. pulse_logo_red / _black / _blue are the real brand
    // assets (500 x 99, the same files the profile map already names as ui.brand.logo and
    // ui.brand.logoBlack), and they are dark ink drawn for a light ground - on the dark
    // card body the PULSE lettering would simply not be there. So the light plate grows to
    // carry the render AND the wordmark, which is the background that artwork was drawn
    // for, and the dark card below it keeps only the tagline.
    readonly property real logoH:
        stacked ? Math.round(cardW * 0.17) : Math.round(artH * 0.42)

    readonly property real plateH:
        stacked ? platePad * 2 + artH + innerGap + logoH + badgeH
                : platePad * 2 + Math.max(artH, logoH) + badgeH

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

    // START A SIMULATION.
    //
    // This screen is the answer to "there is no sounder - what am I looking at", so it is
    // where the other answer belongs. enterDemoMode() is the Recording tab's demo path,
    // not its browse path: a paced replay the app experiences as a live connection, which
    // is what a stand or a kitchen table needs. Starting one makes isPresentingLog true,
    // so this screen closes itself the same way detection closes it, and the Recording
    // tab's stop button is still the way back. Step 4 gives the demo its own pill on the
    // rail; until then nothing about stopping changes.
    property var lastLogFolder: StandardPaths.writableLocation(StandardPaths.HomeLocation)

    Settings {
        //Its own key rather than ConnectionViewer's logFolder: two Settings aliases onto
        //one key is two writers onto one value, which is the thing this screen exists to
        //stop doing.
        property alias connectionScreenLogFolder: connectionScreen.lastLogFolder
    }

    FileDialog {
        id: simulationFileDialog
        title: "Choose a recording to replay"
        currentFolder: connectionScreen.lastLogFolder
        nameFilters: ["Kogger log files (*.plog *.PLOG)"]

        onCurrentFolderChanged: connectionScreen.lastLogFolder = currentFolder

        onAccepted: {
            const file = simulationFileDialog.selectedFile
            if (!file) {
                console.log("CONN_SCREEN: simulation - the dialog returned nothing")
                return
            }
            connectionScreen.lastLogFolder = simulationFileDialog.currentFolder
            const fileStr = file.toString()
            const localPath = fileStr.replace("file:///",
                                              Qt.platform.os === "windows" ? "" : "/")
            console.log("CONN_SCREEN: simulation ->", localPath)
            pulseRuntimeSettings.enterDemoMode(localPath)
        }
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
            spacing: 0

            // THE STATUS STRIP - the single honest line at the top, at the panel's width.
            //
            // Everything it says is already computed somewhere: ConnectionViewer publishes
            // linkIsOpen and deviceIsPresent, the device publishes devName, the channel
            // count, the firmware and the serial, and the resolver already has the
            // address. Nothing new is stored - one binding reads facts that four other
            // places were reading anyway.
            Rectangle {
                id: linkStrip
                anchors.horizontalCenter: parent.horizontalCenter
                width: connectionScreen.panelW
                // The row is given an explicit width rather than anchors.fill, so the
                // wrapping detail line can decide its own height without the height it
                // is asked for depending on the height it produces.
                height: stripRow.implicitHeight + Math.round(20 * connectionScreen.uiScale)
                radius: Math.round(10 * connectionScreen.uiScale)
                color: "#141821"
                border.width: 1
                border.color: "#242a33"

                RowLayout {
                    id: stripRow
                    x: Math.round(14 * connectionScreen.uiScale)
                    y: Math.round(10 * connectionScreen.uiScale)
                    width: linkStrip.width - Math.round(28 * connectionScreen.uiScale)
                    spacing: Math.round(12 * connectionScreen.uiScale)

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth:  Math.round(10 * connectionScreen.uiScale)
                        Layout.preferredHeight: Math.round(10 * connectionScreen.uiScale)
                        radius: width / 2
                        color: connectionScreen.linkColor
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(2 * connectionScreen.uiScale)

                        Text {
                            Layout.fillWidth: true
                            text: connectionScreen.linkHeadline
                            color: "#e6eaf0"
                            font.pixelSize: Math.round(15 * connectionScreen.uiScale)
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: connectionScreen.linkDetail
                            color: "#8d96a2"
                            font.pixelSize: Math.round(12 * connectionScreen.uiScale)
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            Item {
                width: 1
                height: Math.round(12 * connectionScreen.uiScale)
            }

            // THE PANEL. Everything the screen is asking lives inside it: the name of the
            // app, the question, the cards, and both ways out of it.
            Rectangle {
                id: panel
                anchors.horizontalCenter: parent.horizontalCenter
                width: connectionScreen.panelW
                height: panelCol.height + connectionScreen.panelPad * 2
                radius: Math.round(16 * connectionScreen.uiScale)
                color: "#121519"
                border.width: 1
                border.color: "#232830"

                Column {
                    id: panelCol
                    x: connectionScreen.panelPad
                    y: connectionScreen.panelPad
                    width: panel.width - connectionScreen.panelPad * 2
                    spacing: Math.round(4 * connectionScreen.uiScale)

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Pulse Echo Sounder"
                        color: "#f2f4f7"
                        font.pixelSize: Math.round(26 * connectionScreen.uiScale)
                        font.bold: true
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: connectionScreen.canCancel
                              ? "Choose your transducer"
                              : "Which transducer are you using?"
                        color: "#9aa3ae"
                        font.pixelSize: Math.round(15 * connectionScreen.uiScale)
                    }

                    Item {
                        width: 1
                        height: Math.round(14 * connectionScreen.uiScale)
                    }

                    Flow {
                        anchors.horizontalCenter: parent.horizontalCenter
                        // NOT a plain `width` inside a ColumnLayout - a Layout
                        // overwrites it with the implicit width, which for a Flow is
                        // not the row width, and every card then wrapped onto its own
                        // line however much room there was. This Column positions
                        // children in y only, so the width below is the truth.
                        width: Math.min(panelCol.width, connectionScreen.rowW)
                        spacing: connectionScreen.gap

                        Repeater {
                            model: connectionScreen.cards

                            delegate: Rectangle {
                                id: card

                                readonly property var rec: modelData
                                readonly property bool isChosen: connectionScreen.chosenCardId === rec.id

                                width:  connectionScreen.cardW
                                height: cardCol.height + connectionScreen.pad
                                radius: Math.round(12 * connectionScreen.uiScale)
                                color:  cardArea.pressed ? "#1e232b" : "#15181d"
                                border.width: Math.max(1, Math.round(1.5 * connectionScreen.uiScale))
                                border.color: (card.isChosen || cardArea.pressed) ? rec.badge : "#2b3038"

                                Column {
                                    id: cardCol
                                    anchors.centerIn: parent
                                    width: card.width - connectionScreen.pad
                                    spacing: Math.round(8 * connectionScreen.uiScale)

                                    Rectangle {
                                        width:  parent.width
                                        height: connectionScreen.plateH
                                        radius: Math.round(8 * connectionScreen.uiScale)
                                        clip: true
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "#f5f6f7" }
                                            GradientStop { position: 1.0; color: "#dbdde0" }
                                        }

                                        GridLayout {
                                            anchors.fill: parent
                                            anchors.margins: connectionScreen.platePad
                                            anchors.bottomMargin: connectionScreen.platePad
                                                                  + connectionScreen.badgeH
                                            columns: connectionScreen.stacked ? 1 : 2
                                            columnSpacing: connectionScreen.innerGap
                                            rowSpacing:    connectionScreen.innerGap

                                            // The hardware, contained and never
                                            // cropped. A cylinder, a wide block and a
                                            // wedge are three very different aspect
                                            // ratios, so each keeps its own shape at a
                                            // common height.
                                            Image {
                                                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                                Layout.preferredHeight: connectionScreen.artH
                                                Layout.fillWidth: connectionScreen.stacked
                                                Layout.preferredWidth: connectionScreen.stacked
                                                                       ? 1
                                                                       : Math.round(connectionScreen.artH * 1.35)
                                                source: card.rec.art
                                                fillMode: Image.PreserveAspectFit
                                                smooth: true
                                                mipmap: true
                                                // Three small PNGs out of the qrc.
                                                // Decoding them on the loading thread
                                                // is what made the screen assemble
                                                // itself after it was already up.
                                                asynchronous: false
                                                cache: true
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: connectionScreen.logoH
                                                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                                                Image {
                                                    id: logoImage
                                                    anchors.fill: parent
                                                    source: card.rec.logo
                                                    fillMode: Image.PreserveAspectFit
                                                    horizontalAlignment: Image.AlignHCenter
                                                    verticalAlignment: Image.AlignVCenter
                                                    smooth: true
                                                    mipmap: true
                                                    asynchronous: false
                                                    cache: true
                                                }

                                                // A card must still name its device if
                                                // the artwork is missing: a new model
                                                // arrives as a data edit, and its logo
                                                // file can land a commit later.
                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: logoImage.status !== Image.Ready
                                                    text: card.rec.name
                                                    color: "#1c2026"
                                                    font.pixelSize: Math.round(19 * connectionScreen.uiScale)
                                                    font.bold: true
                                                }
                                            }
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: connectionScreen.badgeH
                                            color: card.rec.badge
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: card.rec.tagline
                                        color: "#8d96a2"
                                        font.pixelSize: Math.round(13 * connectionScreen.uiScale)
                                        elide: Text.ElideRight
                                        horizontalAlignment: connectionScreen.stacked
                                                             ? Text.AlignHCenter : Text.AlignLeft
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

                    Item {
                        width: 1
                        height: Math.round(20 * connectionScreen.uiScale)
                    }

                    // THE ACTION CHAIN. Three stretching gaps and two buttons: with
                    // one button the outer two split the room and it sits centred;
                    // with both, all three share it and the pair is balanced against
                    // the panel's edges. One arrangement covers both cases, so there
                    // is no "where does this go when the other one appears" left to
                    // get wrong.
                    //
                    // Keep is INSIDE the panel now. It was outside on the argument
                    // that leaving is not one of the answers - true, and it still
                    // read as a button that had fallen off the box it belongs to.
                    RowLayout {
                        id: actionRow
                        width: panelCol.width
                        spacing: 0

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignTop
                            spacing: Math.round(6 * connectionScreen.uiScale)

                            Rectangle {
                                id: simPill
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth:  simLabel.implicitWidth
                                                + Math.round(40 * connectionScreen.uiScale)
                                implicitHeight: Math.round(44 * connectionScreen.uiScale)
                                radius: height / 2
                                color: simArea.pressed ? "#223243" : "#182430"
                                border.width: 1
                                border.color: "#3d7fd0"

                                Text {
                                    id: simLabel
                                    anchors.centerIn: parent
                                    text: "Start a simulation"
                                    color: "#cfe0f2"
                                    font.pixelSize: Math.round(15 * connectionScreen.uiScale)
                                }

                                MouseArea {
                                    id: simArea
                                    anchors.fill: parent
                                    onClicked: simulationFileDialog.open()
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true
                                Layout.maximumWidth: connectionScreen.captionMax
                                text: "Replays a recording as if the transducer were live."
                                color: "#69727d"
                                font.pixelSize: Math.round(12 * connectionScreen.uiScale)
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            visible: connectionScreen.canCancel
                        }

                        // Cancelling is possible whenever there is something to go
                        // back to. On a cold start there is not, and the screen
                        // correctly offers no way out but a choice.
                        Rectangle {
                            id: keepPill
                            visible: connectionScreen.canCancel
                            Layout.alignment: Qt.AlignTop
                            implicitWidth:  keepLabel.implicitWidth
                                            + Math.round(36 * connectionScreen.uiScale)
                            implicitHeight: Math.round(44 * connectionScreen.uiScale)
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

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                        }
                    }
                }
            }
        }
    }
}
