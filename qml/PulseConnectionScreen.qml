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
// above both Plot2D panes - which is what let step 3 move the swap prompt here and
// retire its `indx === 1` gate, since one surface above both panes cannot draw twice.
//
//   step 1  the selection: the cards, the one binding, the status strip
//   step 2  the card list moves into the profile map, asserted by pulse-profile-check.js
//   step 3  the swap prompt moves off PulseAppClassic and becomes a MODE of this screen
//   step 4  the rail's source button and the demo indicator, which wait for PulseAppV2
//
// A SWAP IS THIS SCREEN'S OWN QUESTION IN OTHER WORDS - "PULSE blue detected, you are set
// up for PULSE red" - so it is a mode of the panel and not a sheet drawn on it. A sheet
// would be a second box with its own width, breakpoint, insets and scrolling, on top of a
// panel that already answers all four, and two boxes asking one question at phone width.
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
        pulseRuntimeSettings ? pulseRuntimeSettings.nothingIdentified : false

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

    // A DIFFERENT TRANSDUCER IS ON THE WIRE. Detection found one that disagrees with what
    // the app is configured for, and a swap re-runs the whole device setup - so it asks
    // rather than doing it and offering an undo. The state is all in PulseRuntimeSettings;
    // this screen only draws the question and routes the two answers.
    readonly property bool swapPending:
        pulseRuntimeSettings ? pulseRuntimeSettings.deviceSwapPending : false

    readonly property string swapTo:
        (pulseRuntimeSettings && swapPending)
            ? pulseRuntimeSettings.modelDisplayName(pulseRuntimeSettings.pendingSwapToModel)
            : ""
    readonly property string swapFrom:
        (pulseRuntimeSettings && swapPending)
            ? pulseRuntimeSettings.modelDisplayName(pulseRuntimeSettings.pendingSwapFromModel)
            : ""

    readonly property bool chooserAsking:
           // THE USER IS CHOOSING. This term used to read swapDeviceNow, which was reaching
           // for exactly this meaning and could not carry it: DeviceItem clears that flag
           // synchronously, so by the time anything read it, it was false and the screen
           // was being held up by nothingIdentified instead. awaitingUserChoice is the
           // honest version, and it is also what stops detection answering underneath.
           (pulseRuntimeSettings ? pulseRuntimeSettings.awaitingUserChoice : false)
        || swapPending
        || (nothingIdentified
            && !(pulseRuntimeSettings ? pulseRuntimeSettings.isPresentingLog : false)
            && (graceElapsed || !somethingMayStillAnswer))

    // WHICH QUESTION THE PANEL ASKS when both could apply is settled in the panel itself,
    // by `visible: connectionScreen.swapPending` on the swap block and its negation on the
    // cards. The swap wins, and that is safe for the one reason that matters: both of its
    // answers settle a model, so the screen still cannot strand itself behind a raised
    // sheet.

    // ---- Who is asking ------------------------------------------------------
    //
    // TWO SOURCES, ONE BINDING, ONE OVERRIDE. chooserAsking is the app's own reason for
    // being here. userAsked is the user's: the rail's source button in PulseAppV2 is the
    // permanent door to this screen, and it raises the flag on pulseRuntimeSettings
    // because QML ids do not cross files and this component lives in main.qml.
    //
    // `visible` stays ONE binding over both and is never assigned by anything. That is the
    // whole point: an assignment would destroy the binding permanently the first time a
    // handler ran, which is the defect class this UI is being rewritten to make impossible
    // rather than to keep fixing.
    //
    // Both ways out of this screen clear the override, and both commit a model, so it
    // still cannot strand itself behind a raised sheet.
    readonly property bool userAsked:
        pulseRuntimeSettings ? pulseRuntimeSettings.connectionScreenRequested : false

    readonly property bool screenShowing: chooserAsking || userAsked

    visible: screenShowing
    enabled: screenShowing

    // ---- What can be gone back to -------------------------------------------

    // The last thing the app was actually configured for. It is what makes cancelling
    // possible, and it is why this screen can never strand itself: every way out of it
    // commits a model, so `nothingIdentified` cannot stay true behind a raised sheet.
    property string lastCommittedModel: ""
    readonly property bool canCancel: lastCommittedModel !== ""

    // AND WHAT THE USER'S OWN REQUEST CAN GO BACK TO. Opening this screen from the rail's
    // source button while a demo is running is the case canCancel cannot answer: nothing
    // has ever been committed, so canCancel is false, yet there IS something behind the
    // screen to return to. The second term is deliberately gated on !chooserAsking - when
    // the app genuinely needs an answer there is no way back, and offering a button that
    // would leave the screen up is worse than offering none.
    readonly property bool canGoBack: canCancel || (userAsked && !chooserAsking)

    // Which CARD was tapped. Not derivable from the committed model - red and black are
    // two cards on one profile, which is the whole point of the card list.
    property string chosenCardId: ""

    // ---- The cards ----------------------------------------------------------
    //
    // Data, not code, and the data is not here: it lives in the profile map beside
    // ui.views / ui.cones, one list per record, in the record each card commits to. This
    // screen reads it the way the choosers read theirs, and a new model is one more entry
    // in a profile record with nothing to change in this file.
    //
    // Every entry arrives in the same shape - id, name, tagline, art, logo, badge,
    // profile - with `logo` already resolved from that record's own ui.brand wordmark.
    // Two entries can still share one profile: red and black are the same hardware at
    // 510 / 710 / 810 kHz, and the owner gets to pick the one he bought.
    readonly property var cards: pulseRuntimeSettings ? pulseRuntimeSettings.uiCards : []

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
                    "| swapPending", swapPending, "-> to", swapTo,
                    "| presentingLog", pulseRuntimeSettings ? pulseRuntimeSettings.isPresentingLog : "?",
                    "| mayStillAnswer", somethingMayStillAnswer,
                    "| grace", graceElapsed,
                    "| canCancel", canCancel)
    }

    Component.onCompleted:
        console.log("CONN_SCREEN: built", cards.length, "cards | uiScale", uiScale)

    // Committing a card writes userManualSetName and nothing else, so the whole
    // configuration path behaves exactly as it did through the old selectors.
    //
    // NO SWAP BRANCH HERE, and that is decided rather than forgotten: the cards are not
    // drawn while a swap is pending - the panel asks the swap question in their slot - so
    // deviceSwapPending cannot be true on this path. If cards are ever shown beside a
    // pending swap, this needs routing and not a guard: the TARGET's card is acceptSwap(),
    // any other card is declineDeviceSwap() and then this. Tapping the target and landing
    // here would commit the new model with the old device's setup still standing, which is
    // exactly the order acceptDeviceSwap() exists to get right.
    function commitCard(card) {
        if (!pulseRuntimeSettings || !card)
            return

        // The user's own request is answered by any commit, however the screen was raised.
        pulseRuntimeSettings.connectionScreenRequested = false

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
    // This screen is the answer to "there is no transducer - what am I looking at", so it is
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

    // VIEW A FILE (Stage 4 b).
    //
    // THE RECORDING TAB HAD THREE JOBS AND TWO OF THEM ARE GONE. Starting and stopping a
    // recording is the rail's Record button and the pill's question; starting a demo is the
    // button above this one. Opening a file to look at is the one that had no home, and
    // Olav put it here: this screen is the answer to "there is no transducer - what am I
    // looking at", and a file is one of the answers.
    //
    // A SEPARATE DIALOG FROM THE SIMULATION'S, on purpose and not by accident of copying.
    // They are different acts on different machinery: enterDemoMode() closes the live links
    // and paces the file as if the transducer were speaking, core.openLogFile() renders the
    // whole recording and sets wasKlfFileOpened so the app knows it is browsing. They also
    // accept different files - a demo can only pace a .plog, while browsing reads .ubx and
    // .xtf too.
    //
    // Both make isPresentingLog true, so this screen closes itself either way and needs no
    // dismissal path of its own.
    FileDialog {
        id: viewFileDialog
        title: "Choose a recording to view"
        currentFolder: connectionScreen.lastLogFolder
        nameFilters: ["Logs (*.plog *.PLOG *.ubx *.UBX *.xtf *.XTF)",
                      "Kogger log files (*.plog *.PLOG)",
                      "U-blox (*.ubx *.UBX)"]

        onCurrentFolderChanged: connectionScreen.lastLogFolder = currentFolder

        onAccepted: {
            const file = viewFileDialog.selectedFile
            if (!file) {
                console.log("CONN_SCREEN: view a file - the dialog returned nothing")
                return
            }
            connectionScreen.lastLogFolder = viewFileDialog.currentFolder
            const fileStr = file.toString()
            const localPath = fileStr.replace("file:///",
                                              Qt.platform.os === "windows" ? "" : "/")
            console.log("CONN_SCREEN: view a file ->", localPath)
            core.openLogFile(localPath, false, false)
            pulseRuntimeSettings.klfFilePath = localPath
        }
    }

    // ACCEPTING A SWAP IS NOT commitCard(). commitCard() clears swapDeviceNow and writes
    // the model itself; acceptDeviceSwap() raises swapDeviceNow FIRST - which is what runs
    // DeviceItem's reset synchronously - and commits the target after, because committing
    // it first would be undone a line later. So this is a thin wrapper and never a second
    // path to the same place.
    //
    // chosenCardId is cleared because a swap was not a tap. Left set, the old card would
    // wear the chosen border the next time the cards are shown, against a model it does
    // not commit.
    function acceptSwap() {
        if (!pulseRuntimeSettings)
            return
        console.log("CONN_SCREEN: swap accepted ->", pulseRuntimeSettings.pendingSwapToModel)
        chosenCardId = ""
        pulseRuntimeSettings.acceptDeviceSwap()
    }

    // Cancel means "I meant to keep what I had". A force reselection has already cleared
    // every setup state, so keeping it re-commits the same model and re-runs the same
    // configuration pass the card would have - it is a choice, not an undo.
    function keepCurrent() {
        if (!pulseRuntimeSettings)
            return

        // ABOVE EVERYTHING, including the canCancel guard below: a screen the user opened
        // by hand must close on cancel even in a state where there is nothing to cancel
        // back to. Leave it under the guard and the source button becomes a trap.
        pulseRuntimeSettings.connectionScreenRequested = false

        // DECLINING COMES FIRST, and deliberately ABOVE the canCancel guard: it is the
        // only thing on this screen that clears pendingSwapToModel, and chooserAsking now
        // reads that. Skip it and the screen never falls, and the same device is asked
        // about again the moment it is detected.
        if (swapPending) {
            console.log("CONN_SCREEN: swap declined - keeping",
                        pulseRuntimeSettings.pendingSwapFromModel)
            pulseRuntimeSettings.declineDeviceSwap()
        }

        if (!canCancel)
            return

        console.log("CONN_SCREEN: cancelled - keeping", lastCommittedModel)
        // A no-op after a declined swap - nothing was torn down, so userManualSetName is
        // already this value and assigning it emits nothing. After a force reselection it
        // is the re-commit that re-runs the configuration pass. One path covers both.
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
                        color: pulseRuntimeSettings.linkColor
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(2 * connectionScreen.uiScale)

                        Text {
                            Layout.fillWidth: true
                            text: pulseRuntimeSettings.linkHeadline
                            color: "#e6eaf0"
                            font.pixelSize: Math.round(15 * connectionScreen.uiScale)
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: pulseRuntimeSettings.linkDetail
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
                        // Stands down in swap mode: the question below is the headline
                        // there, and two headlines compete.
                        visible: !connectionScreen.swapPending
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
                        // NOT DRAWN WHILE A SWAP IS PENDING, and that is what removes the
                        // trap rather than special-casing it: with no card on screen there
                        // is no way to commit the detected device by hand and skip the
                        // reset. It costs nothing - red and black commit the same profile,
                        // so a detected swap has exactly two honest answers and never a
                        // third. See commitCard().
                        visible: !connectionScreen.swapPending
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

                    // THE SWAP QUESTION - the body in swap mode, in the slot the cards
                    // occupy, at the same two weights the prompt on the echogram used.
                    // Text only, deliberately: a swap to PULSEred matches TWO cards, red
                    // and black, so "the detected device's picture" has no single answer
                    // and inventing one would be a change rather than a move.
                    Column {
                        visible: connectionScreen.swapPending
                        width: panelCol.width
                        spacing: Math.round(6 * connectionScreen.uiScale)

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: connectionScreen.swapTo + " detected"
                            color: "#f2f4f7"
                            font.pixelSize: Math.round(22 * connectionScreen.uiScale)
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: "The app is set up for " + connectionScreen.swapFrom
                                  + ". Switching re-runs the device setup."
                            color: "#9aa3ae"
                            font.pixelSize: Math.round(15 * connectionScreen.uiScale)
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

                        // THE FIRST SLOT HOLDS THE PRIMARY ANSWER, and which one that is
                        // depends on the mode: a simulation when the screen is asking
                        // which transducer, Switch when it is asking about a swap. Two
                        // pills in one slot with one of them visible, rather than one pill
                        // with its text, colour and action all on ternaries - a RowLayout
                        // drops invisible children, so the three-spacer chain from step 1
                        // never learns that a third button exists.
                        Rectangle {
                            id: simPill
                            visible: !connectionScreen.swapPending
                            Layout.alignment: Qt.AlignTop
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

                        // Accepting goes through acceptDeviceSwap(), which is the only
                        // order the re-setup survives. Amber and filled, carried over from
                        // the prompt this replaces: it is the answer the device is
                        // proposing, and the only primary action this screen has.
                        Rectangle {
                            id: switchPill
                            visible: connectionScreen.swapPending
                            Layout.alignment: Qt.AlignTop
                            implicitWidth:  switchLabel.implicitWidth
                                            + Math.round(40 * connectionScreen.uiScale)
                            implicitHeight: Math.round(44 * connectionScreen.uiScale)
                            radius: height / 2
                            color: switchArea.pressed ? "#ffdd55" : "#ffcc00"

                            Text {
                                id: switchLabel
                                anchors.centerIn: parent
                                text: "Switch to " + connectionScreen.swapTo
                                color: "#102030"
                                font.pixelSize: Math.round(15 * connectionScreen.uiScale)
                                font.bold: true
                            }

                            MouseArea {
                                id: switchArea
                                anchors.fill: parent
                                onClicked: connectionScreen.acceptSwap()
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            visible: viewPill.visible
                        }

                        // VIEW A FILE sits between the simulation and Keep, where Olav put
                        // it. Hidden during a swap for the same reason the simulation is:
                        // the screen is asking one question then, and a third answer that
                        // does not answer it is clutter.
                        //
                        // Outlined like the simulation rather than filled: neither is the
                        // primary answer to "which transducer", they are both ways of
                        // getting a picture without one.
                        Rectangle {
                            id: viewPill
                            visible: !connectionScreen.swapPending
                            Layout.alignment: Qt.AlignTop
                            implicitWidth:  viewLabel.implicitWidth
                                            + Math.round(40 * connectionScreen.uiScale)
                            implicitHeight: Math.round(44 * connectionScreen.uiScale)
                            radius: height / 2
                            color: viewArea.pressed ? "#223243" : "#182430"
                            border.width: 1
                            border.color: "#3d7fd0"

                            Text {
                                id: viewLabel
                                anchors.centerIn: parent
                                text: "View a file"
                                color: "#cfe0f2"
                                font.pixelSize: Math.round(15 * connectionScreen.uiScale)
                            }

                            MouseArea {
                                id: viewArea
                                anchors.fill: parent
                                onClicked: viewFileDialog.open()
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            visible: connectionScreen.canGoBack || connectionScreen.swapPending
                        }

                        // Cancelling is possible whenever there is something to go
                        // back to. On a cold start there is not, and the screen
                        // correctly offers no way out but a choice. A pending swap
                        // always has one - the model it says the app is set up for,
                        // and so does a screen the user opened himself.
                        Rectangle {
                            id: keepPill
                            visible: connectionScreen.canGoBack || connectionScreen.swapPending
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
                                // In swap mode it names pendingSwapFromModel rather than
                                // lastCommittedModel: the swap's Keep is about the model
                                // the SWAP says you are set up for, which is the fact the
                                // question was built on.
                                text: "Keep " + (connectionScreen.swapPending
                                                 ? connectionScreen.swapFrom
                                                 : (pulseRuntimeSettings
                                                    ? pulseRuntimeSettings.modelDisplayName(connectionScreen.lastCommittedModel)
                                                    : ""))
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

                    // The caption is NOT in the chain. It is wider than either button, so
                    // as a chain item it made the simulation button's slot far wider than
                    // the button, and the three gaps came out equal between the SLOTS
                    // while looking wrong between the buttons. Out here it costs the chain
                    // nothing and still sits under the button it explains rather than
                    // under the middle of a panel it is not talking about.
                    Text {
                        id: simCaption
                        // Goes with the pill it explains - and its x reads simPill.x,
                        // which means nothing while that pill is not laid out.
                        visible: !connectionScreen.swapPending
                        x: Math.max(0, Math.min(panelCol.width - width,
                                                simPill.x + (simPill.width - width) / 2))
                        topPadding: Math.round(6 * connectionScreen.uiScale)
                        width: Math.min(implicitWidth, panelCol.width)
                        text: "Replays a recording as if the transducer were live."
                        color: "#69727d"
                        font.pixelSize: Math.round(12 * connectionScreen.uiScale)
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
