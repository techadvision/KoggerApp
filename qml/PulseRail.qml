import QtQuick 2.15
import QtQuick.Layouts 1.15

// THE EDGE RAIL (Stage 4 a) - Direction A, decided 11 Sept 2026.
//
// Tier 1 only: the seven controls that are always on screen, change the picture now, and
// are one tap away. The panel they open is stage 4 (b) and does not exist yet, so every
// tier-1 button here emits `buttonActivated` and nothing else. That is deliberate: this
// slice is the surface and its geometry, and a rail missing two buttons has the wrong
// proportions to judge on a device.
//
// TWO MASTERS, NAMED RATHER THAN BLURRED. This is rule 1 as it applies to a control
// surface, and getting it wrong here is how defect A's whole family recurs:
//
//   WHICH BUTTONS EXIST reads the COMMITTED profile for the cone and the DISPLAY model
//   for the screen (offersCone / offersScreen) - see the two property blocks. A chooser
//   offers HARDWARE choices - you cannot change the cone of a transducer you do not have -
//   so it follows what is connected, never a log that happens to be playing.
//
//   EVERYTHING DRAWN ABOUT THE PICTURE reads the DISPLAY model (displayIs2D). With a blue
//   log presenting on a committed red, this rail must not say "cone" over a side scan.
//
// Nothing in this file reads is2DTransducer, and nothing in it should ever start to.
Item {
    id: rail

    property real uiScale:    1.0
    property real safeTop:    0
    property real safeBottom: 0
    property real safeLeft:   0

    // --- what the picture is (DISPLAY) ---
    property bool displayIs2D: true

    // --- what the hardware offers (COMMITTED) ---
    property bool offersCone: false

    // --- what the PICTURE offers (DISPLAY) ---
    //
    // The screen chooser replaced the view chooser on 14 Sept, and it changed which model
    // answers. A cone is a hardware choice and follows what is connected; a screen layout
    // is a thing you judge by looking at it, so it follows displayIs2D and a side scan log
    // on a red device still offers its layouts.
    property bool offersScreen: false

    // --- app state the rail shows ---
    property bool recording: false

    // WHETHER RECORDING IS EVEN POSSIBLE, not whether a log is playing. The Recording tab
    // has always refused to record a replay - a second-generation log is a confusing
    // artefact - and it refuses an opened file and a file still being opened for the same
    // reason. `isPresentingLog` is the wrong test for it: with a transducer connected AND a
    // file open that flag is false, and the button would come back over a picture that is
    // still a file. So the host passes the real condition and this file does not guess.
    property bool canRecord: true

    // THE SOURCE BUTTON'S STATE. Read, never recomputed: the derivation lives on
    // pulseRuntimeSettings and the connection screen reads the same one. The rail can
    // therefore never disagree with the screen it opens - which is the whole reason the
    // strip was hoisted out of that screen rather than copied into this one.
    //
    // A dot, not a word. At 76 du there is no room for "Connected, identifying the
    // transducer", and the screen one tap away says it in full; what the rail owes the
    // user from across a boat is whether the source is answering, not what it is called.
    property string sourceState: "absent"
    property color  sourceColor: "#6d7480"

    // THE WAY BACK TO CLASSIC IS GONE FROM THE RAIL, 16 Sept 2026. It was scaffolding from
    // the first day of stage 4 (a): the switch that turns v2 on had only ever lived in the
    // CLASSIC expert settings, and uiVariant is persisted - so turning v2 on removed its own
    // off switch from the screen and the rail had to carry one or a tester was stranded.
    //
    // The settings list's Experimental group now carries "New UI (PULSE UI v2)", and it has
    // been used on a device. Olav: "Drop that 'return to classic' arrow. We do not need it."
    // So the exception is retired rather than kept "just in case" - and the rail, which is
    // 68 design units short of fitting a phone, gets the first of them back.

    // COLLAPSED. One binding on the persisted setting, set by the host; the toggle writes
    // the SETTING, never this property - assigning here would destroy the binding and the
    // rail would stop following the stored value for the rest of the run.
    property bool collapsed: false

    // WHICH GROUP THE PANEL IS SHOWING, "" when it is closed. The rail does not own the
    // panel and does not decide anything about it - it only wears the state, so the button
    // that opened a group is the one lit while it is open.
    property string openGroup: ""

    property bool paused: false

    // WHETHER POSITIONS ARE ARRIVING NOW (live, demo, stream) or, for an opened file,
    // whether the file carries any. main.qml derives it; the rail only wears it on Pause.
    property bool positionsAvailable: false

    signal buttonActivated(string id)
    signal sourceActivated()
    signal collapseToggled()

    // THE APP DRAWS FULL-BLEED UNDER THE STATUS BAR, on purpose - an echogram wants every
    // pixel - so main.qml's insetTop() answers 0 unless DeX is on, and safeTop arrives as
    // zero on an ordinary tablet. That is right for the picture and wrong for a control:
    // the first device build put the top button half under the Android clock.
    //
    // Same floor, same constant as PulseConnectionScreen, which met this first and for the
    // same reason. The two surfaces must agree, or the rail and the screen it opens sit at
    // different heights.
    readonly property bool onAndroid: Qt.platform.os === "android"
    readonly property real topInset: Math.max(safeTop, onAndroid ? Math.round(34 * uiScale) : 0)

    readonly property real railWidth: Math.round(76 * uiScale) + safeLeft
    readonly property real tabWidth:  Math.round(30 * uiScale) + safeLeft

    // ── THE RAIL HAS TO FIT THE SCREEN IT IS DRAWN ON (16 Sept 2026) ────────────────────
    //
    // The app forces landscape from the Java activity, so on a phone the SHORT side is the
    // height this column has to live in. The column needs about 983 design units with a
    // live blue on it and a Samsung S23 Ultra does not have that many, so the ColumnLayout
    // squeezed every item it could - and the one item that does not squeeze ran off the
    // bottom of the screen. Olav: "I can barely see the 'N' in the TechAdVision artwork."
    //
    // THAT 'N' IS THE DIAGNOSIS, not a complaint. The wordmark's Image kept a fixed
    // 150 x 30 and was only CENTRED in a box the layout had shrunk, so it overflowed. At
    // -90 degrees the original left edge maps to the bottom, so what stays on screen is the
    // END of the word. TechAdVisio-n.
    //
    // AND BOTH OF THE APP'S SCALES ARE FLOORED. uiScale is mainview.s, which is
    // Math.max(1.0, shortSide / 1100) - it grows on a tablet and can never shrink on a
    // phone - exactly as UiMetrics::scale() sits on its own 0.75 floor. Nothing that scales
    // down reaches this, which is why the answer is a BUDGET rather than a smaller number.
    //
    // THE WORDMARK IS THE ONLY THING ON THIS RAIL THAT IS NOT A CONTROL, so it is the one
    // that gives - and it gives completely rather than partly. Olav, on the three shapes:
    // elastic, and absent below its natural size. A wordmark drawn at half size reads as a
    // smudge and spends the room anyway; absent spends nothing and says nothing false.
    //
    // ONLY EVER SHRINKS, which is bf80ab02's clamp in a second place: on a tablet there is
    // room, the slot is reserved exactly as the Layout.topMargin + 150 used to be, and the
    // geometry is identical to before this commit.
    //
    // NO HAND-WRITTEN SUM, and that is the whole reason the wordmark leaves the layout. The
    // question "is there room" needs the controls' natural height, and column.implicitHeight
    // is that number, kept by the layout itself - so a button added or withdrawn is counted
    // with nothing to remember. Adding up the column here would have been the "hook is only
    // as good as the list it re-applies" fault in a new place.
    //
    // AND IT CANNOT LOOP. implicitHeight is the sum of the CHILDREN's preferred heights; it
    // does not read the layout's own geometry or its margins. So the reservation below is
    // downstream of the measurement and never feeds back into it. (This is why the wordmark
    // could not simply be hidden in place: hiding it inside the layout would drop
    // implicitHeight, which would make it fit, which would show it again.)
    readonly property real columnTopMargin:    Math.round(10 * uiScale) + topInset
    readonly property real columnBottomMargin: Math.round(10 * uiScale) + safeBottom
    readonly property real columnSpacing:      Math.round(8 * uiScale)

    // ── THE RAIL SCROLLS, BELOW ITS THREE SETTERS (session 4, 28 Sept 2026) ─────────────
    //
    // With Interface size at Larger, or on the 320 dpi phone even at Normal, the controls
    // are taller than the screen. Three pieces, and only the middle one moves:
    //
    //   HEAD - Max range, Intensity, Water body filter. PINNED. They were moved to the top
    //          on 27 Sept to be the three most obvious controls on the screen, and a scroll
    //          that could carry them away would undo that.
    //   BODY - Colours, Cone/Screen, Pause, Record, then the source button and Settings.
    //          SCROLLS, and only when it has to. Olav, 28 Sept: Pause and Record scroll too.
    //   FOOT - Hide the rail. PINNED to the bottom, so the tab that brings the rail back
    //          can sit exactly where this button was - one spot under one thumb.
    //
    // THE USER MUST SEE THAT THERE IS MORE. A fade at the edge that has more behind it, with
    // a chevron drawn in the fade - an overlay, never a layout item, because two touch-sized
    // arrows would cost almost a button's height on exactly the screen that has none. Each
    // one is also tappable and scrolls most of a page.
    //
    // NO LOOP, for the reason the wordmark's measurement had none: every number below is an
    // implicitHeight, which is the children's PREFERRED heights and never reads the geometry
    // the anchors give the head, the body or the foot.
    readonly property real controlsRoom:    Math.max(0, height - columnTopMargin - columnBottomMargin)
    readonly property real controlsNatural: head.implicitHeight + bodyColumn.implicitHeight
                                            + foot.implicitHeight + 2 * columnSpacing
    readonly property bool bodyScrolls:     !collapsed && bodyColumn.implicitHeight > bodyFlick.height + 0.5

    // ── THE BRAND, AFTER THE CONTROLS HAVE HAD THEIR ROOM ───────────────────────────────
    //
    // The vertical wordmark is gone from the rail. It lives horizontally at the foot of the
    // panel now, where there is width for it (PulsePanel), and the rail carries the MARK:
    // the "D" of the Techadvision app icon, white on transparent, the wordmark cropped off.
    // Transparent rather than colour-matched, because the rail is #cc0f1317 over the
    // echogram and an opaque square would show as a box.
    //
    // The same rule as 3ed258c9: the only thing on the rail that is not a control is the one
    // that gives, and it gives completely. It sits between the body and the foot, so the
    // foot never moves, and it is absent whenever the body would otherwise need to scroll.
    readonly property real brandSize: Math.round(40 * uiScale)
    readonly property real brandSlot: brandSize + columnSpacing
    readonly property bool brandFits: !collapsed && (controlsRoom - controlsNatural) >= brandSlot

    // WHAT THE PICTURE OWES THE RAIL. Zero when collapsed - the echogram takes the whole
    // screen and the tab floats over it - and the rail's full width otherwise. This is the
    // one number a host has to read to give the echogram the rest of the screen.
    readonly property real inset: collapsed ? 0 : railWidth

    // A plain width is correct here: the rail is ANCHORED by its parent, not a Layout child.
    width: collapsed ? tabWidth : railWidth

    function scrollBody(direction) {
        const maxY = Math.max(0, bodyFlick.contentHeight - bodyFlick.height)
        scrollAnimation.to = Math.max(0, Math.min(maxY, bodyFlick.contentY + direction * bodyFlick.height * 0.75))
        scrollAnimation.restart()
    }

    Rectangle {
        anchors.fill: parent
        visible: !rail.collapsed
        color: "#cc0f1317"
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: !rail.collapsed
        width: 1
        color: "#20ffffff"
    }

    // THE WAY BACK. Collapsing has to be reversible from the picture itself, or the rail
    // is not collapsed but gone - and the only way back would be a restart, because the
    // state is persisted.
    //
    // AT THE FOOT, WHERE THE HIDE BUTTON WAS, since 28 Sept. It used to be vertically
    // centred, and that is the one place on the left edge that two Android features also
    // want: in split screen the divider's grab handle sits at the vertical centre of the
    // divider, and a tester running Pulse as the right-hand app hit the divider every time
    // he reached for the tab. The left edge is also the back-gesture edge under gesture
    // navigation. The foot is clear of the handle, and it is the spot the thumb that
    // collapsed the rail is already on.
    Rectangle {
        id: showTab
        visible: rail.collapsed
        // ROUNDED ON THE RIGHT ONLY, without per-corner radii. topRightRadius and
        // bottomRightRadius are Qt 6.7 additions and this file declares `import QtQuick
        // 2.15`, which pins the TYPE version whatever Qt the app is built with - so they
        // are not available here and the whole QML tree fails to load if they are used.
        // Instead the tab is a plain rounded rectangle pushed left by its own radius, so
        // its left corners sit off the screen edge and only the right pair is ever seen.
        anchors.left: parent.left
        anchors.leftMargin: rail.safeLeft - radius
        anchors.bottom: parent.bottom
        anchors.bottomMargin: rail.columnBottomMargin
        width:  Math.round(30 * rail.uiScale) + radius
        // The hide button's own height, so the two occupy the same spot.
        height: Math.round(60 * rail.uiScale)
        radius: Math.round(8 * rail.uiScale)
        color: showArea.pressed ? "#dd2a3644" : "#cc0f1317"
        border.width: 1
        border.color: "#20ffffff"

        Image {
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            // Centred on the VISIBLE part, not on the item: the item is wider than what
            // can be seen by exactly the radius it was pushed out by.
            anchors.horizontalCenterOffset: Math.round(showTab.radius / 2)
            width:  Math.round(20 * rail.uiScale)
            height: width
            source: "./icons/ui/pulse_rail_show.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: 0.9
        }

        MouseArea {
            id: showArea
            anchors.fill: parent
            onClicked: rail.collapseToggled()
        }
    }

    // ── HEAD: the three setters, pinned ─────────────────────────────────────────────────
    //
    // WHAT IS OPEN, SAID ONCE PER COLUMN. Every PulseRailButton defaults its own `openGroup`
    // from its parent and compares it with its own buttonId, so the button that opened a
    // group is the one lit. There are three columns now and each declares it once; a button
    // added to any of them needs no line of its own.
    ColumnLayout {
        id: head

        visible: !rail.collapsed
        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   parent.top
        anchors.leftMargin: rail.safeLeft
        anchors.topMargin:  rail.columnTopMargin

        spacing: rail.columnSpacing

        property string openGroup: rail.openGroup

        // THE ORDER, from Olav 27 Sept: the three setters a user reaches for most first -
        // max range, intensity, filter - then colours, cone/screen and pause. Record stays
        // last of the group because it is the one that asks before it acts.
        PulseRailButton {
            uiScale: rail.uiScale
            buttonId: "range"
            label: "Max range"
            iconSource: "./icons/ui/pulse_ruler.svg"
            onActivated: rail.buttonActivated(buttonId)
        }

        // SPEED, pinned beside the range (Olav, 30 Sept: the non-scrolling part). How deep
        // and how fast are the two controls anyone reaches for. On a side scan it sets the
        // boat speed that makes the picture true; on 2D the echogram speed.
        PulseRailButton {
            uiScale: rail.uiScale
            buttonId: "speed"
            label: "Speed"
            iconSource: "./icons/ui/pulse_speed.svg"
            onActivated: rail.buttonActivated(buttonId)
        }

        PulseRailButton {
            uiScale: rail.uiScale
            buttonId: "intensity"
            label: "Intensity"
            iconSource: "./icons/ui/pulse_sun.svg"
            onActivated: rail.buttonActivated(buttonId)
        }

        PulseRailButton {
            uiScale: rail.uiScale
            buttonId: "filter"
            label: "Water body filter"
            iconSource: "./icons/ui/pulse_filter.svg"
            onActivated: rail.buttonActivated(buttonId)
        }
    }

    // ── BODY: everything else, scrolling only when it must ──────────────────────────────
    Flickable {
        id: bodyFlick

        visible: !rail.collapsed
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.top:    head.bottom
        anchors.bottom: foot.top
        anchors.leftMargin:   rail.safeLeft
        anchors.topMargin:    rail.columnSpacing
        anchors.bottomMargin: rail.brandFits ? rail.brandSlot + rail.columnSpacing
                                             : rail.columnSpacing

        clip: true
        contentWidth:  width
        // At least the viewport, so the fill-height spacer still pushes the source button
        // and Settings to the bottom when everything fits - the tablet layout, unchanged.
        contentHeight: Math.max(height, bodyColumn.implicitHeight)
        interactive: rail.bodyScrolls
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        // A body that stops scrolling (a larger screen, a smaller Interface size) must not be
        // left scrolled away with no arrow to bring it back.
        onContentHeightChanged: if (contentY > Math.max(0, contentHeight - height)) contentY = Math.max(0, contentHeight - height)

        NumberAnimation {
            id: scrollAnimation
            target: bodyFlick
            property: "contentY"
            duration: 220
            easing.type: Easing.OutCubic
        }

        ColumnLayout {
            id: bodyColumn

            width:  bodyFlick.width
            height: bodyFlick.contentHeight
            spacing: rail.columnSpacing

            property string openGroup: rail.openGroup

            PulseRailButton {
                uiScale: rail.uiScale
                buttonId: "colours"
                label: "Colours"
                iconSource: "./icons/ui/pulse_color_bucket.svg"
                onActivated: rail.buttonActivated(buttonId)
            }

            // ONE BUTTON, TWO QUESTIONS - a SCREEN on blue, a CONE on red - and absent entirely
            // when neither is offered. Absent rather than greyed out: a control that cannot be
            // used is not a control, and the profile map already says "never offer a choice of
            // one".
            //
            // THE RAIL'S BUTTON COUNT DOES NOT GROW, which is the decision recorded under the
            // roadmap: the screen chooser took the view chooser's place rather than a place of
            // its own, because once the layout says which picture is on screen a separate
            // "which view" question has nothing left to answer.
            //
            // The icon is static, as it was for the view. Showing the CURRENT layout means
            // drawing it, and PulseScreenMark draws it at 56 px in the panel where it is worth
            // the room; at 24 px on the rail a split reads as a smudge.
            PulseRailButton {
                uiScale: rail.uiScale
                buttonId: rail.offersCone ? "cone" : "screen"
                label: rail.offersCone ? "Cone" : "Screen"
                visible: rail.offersScreen || rail.offersCone
                iconSource: rail.offersCone ? "./icons/ui/pulse_cone.svg"
                                            : "./icons/ui/pulse_view_side_scan.svg"
                onActivated: rail.buttonActivated(buttonId)
            }

            PulseRailButton {
                uiScale: rail.uiScale
                buttonId: "pause"
                label: "Pause and inspect"
                // Never true while the rail is showing - pausing replaces the rail with the
                // gutter - but the property is what a later "pause is pending" state would use,
                // and a button that cannot show its own state is a button to fix later.
                active: rail.paused
                // POSITIONS ARE ARRIVING - the V1 UI made this button green on mavlinkDetected,
                // which never went out again. This one follows the positions themselves, so a
                // lost fix takes the mark away: at a glance, and on a customer's screenshot,
                // it says whether a waypoint could be placed right now.
                indicator: rail.positionsAvailable
                iconSource: "./icons/ui/pulse_play_pause.svg"
                onActivated: rail.buttonActivated(buttonId)
            }

            // Absent rather than dead when recording is impossible, and the pill on the picture
            // says why: it reads "Demo - PULSE blue" or "Viewing recording - PULSE blue".
            PulseRailButton {
                uiScale: rail.uiScale
                buttonId: "record"
                label: "Record"
                visible: rail.canRecord
                active: rail.recording
                // pulse_recording_inactive.svg declares NEITHER fill NOR stroke, so SVG's default
                // applies and it draws BLACK - invisible on a #cc0f1317 rail. The button was
                // there and tappable the whole time; nothing could be seen to tap. Every other
                // icon on this rail states #ffffff or #FFFFF0, and pulse_recording_mini is the
                // white one of this pair. Red when it IS recording, which the pill echoes.
                iconSource: rail.recording ? "./icons/ui/pulse_recording_active.svg"
                                           : "./icons/ui/pulse_recording_mini.svg"
                onActivated: rail.buttonActivated(buttonId)
            }

            Item { Layout.fillHeight: true; Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth:  Math.round(36 * rail.uiScale)
                Layout.preferredHeight: 1
                Layout.alignment: Qt.AlignHCenter
                color: "#30ffffff"
            }

            // THE SOURCE BUTTON - the permanent door to the connection screen, and the thing
            // backlog item 9 never had.
            Item {
                id: sourceButton

                Layout.preferredWidth:  Math.round(64 * rail.uiScale)
                Layout.preferredHeight: Math.round(64 * rail.uiScale)
                Layout.alignment: Qt.AlignHCenter

                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(10 * rail.uiScale)
                    color: sourceTouch.pressed ? "#2a3644" : "transparent"
                    border.width: 1
                    border.color: "#28ffffff"
                }

                // device-transducer.svg was upstream's, and it carries stroke="currentColor" -
                // a CSS idea with nothing to resolve it in a QML Image, so it drew dark against
                // a dark rail while every PULSE icon beside it is white. pulse_source.svg is the
                // same geometry with the stroke stated, named for what the button does.
                Image {
                    id: sourceGlyph
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -Math.round(5 * rail.uiScale)
                    width:  Math.round(32 * rail.uiScale)
                    height: width
                    source: "./icons/ui/pulse_source.svg"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                // GREEN IS A CLAIM ABOUT NOW - it is `talking`, which needs data arriving now
                // and nothing else. Amber is the ordinary wifi drop with the identity retained;
                // gray is history, or nothing at all. The screen behind this button spells all
                // six out in words.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: sourceGlyph.bottom
                    anchors.topMargin: Math.round(3 * rail.uiScale)
                    width:  Math.round(8 * rail.uiScale)
                    height: width
                    radius: width / 2
                    color: rail.sourceColor
                }

                MouseArea {
                    id: sourceTouch
                    anchors.fill: parent
                    onClicked: rail.sourceActivated()
                }
            }

            PulseRailButton {
                uiScale: rail.uiScale
                buttonId: "settings"
                label: "Settings"
                iconSource: "./icons/ui/pulse_settings.svg"
                onActivated: rail.buttonActivated(buttonId)
            }
        }
    }

    // ── THE TWO "THERE IS MORE" CUES ────────────────────────────────────────────────────
    //
    // Drawn over the body's edges, never inside its layout. Each is shown only on the side
    // that has something behind it, and both are gone when the body fits.
    Repeater {
        model: [ -1, 1 ]    // -1: more above, 1: more below

        delegate: Item {
            id: cue

            readonly property bool above: modelData < 0
            readonly property real maxY: Math.max(0, bodyFlick.contentHeight - bodyFlick.height)

            visible: rail.bodyScrolls
                     && (above ? bodyFlick.contentY > 1 : bodyFlick.contentY < maxY - 1)

            // A Canvas that was created hidden has nothing painted until it is asked.
            onVisibleChanged: if (visible) chevron.requestPaint()

            x: bodyFlick.x
            y: above ? bodyFlick.y : bodyFlick.y + bodyFlick.height - height
            width:  bodyFlick.width
            height: Math.round(30 * rail.uiScale)

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: cue.above ? "#f20f1317" : "#000f1317" }
                    GradientStop { position: 1.0; color: cue.above ? "#000f1317" : "#f20f1317" }
                }
            }

            // A plain Canvas chevron, so there is no SVG whose missing fill could draw it black.
            Canvas {
                id: chevron
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: cue.above ? -Math.round(4 * rail.uiScale)
                                                        :  Math.round(4 * rail.uiScale)
                width:  Math.round(18 * rail.uiScale)
                height: Math.round(10 * rail.uiScale)
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    const lw = Math.max(1.5, 2 * rail.uiScale)
                    ctx.reset()
                    ctx.strokeStyle = "#e6ffffff"
                    ctx.lineWidth = lw
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    if (cue.above) {
                        ctx.moveTo(lw, height - lw); ctx.lineTo(width / 2, lw); ctx.lineTo(width - lw, height - lw)
                    } else {
                        ctx.moveTo(lw, lw); ctx.lineTo(width / 2, height - lw); ctx.lineTo(width - lw, lw)
                    }
                    ctx.stroke()
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: rail.scrollBody(cue.above ? -1 : 1)
            }
        }
    }

    // ── THE MARK ────────────────────────────────────────────────────────────────────────
    Image {
        id: brandMark

        visible: rail.brandFits

        anchors.horizontalCenter: parent.horizontalCenter
        // Centred on the CONTENT area, which starts at safeLeft.
        anchors.horizontalCenterOffset: Math.round(rail.safeLeft / 2)
        anchors.bottom: foot.top
        anchors.bottomMargin: rail.columnSpacing

        width:  rail.brandSize
        height: rail.brandSize
        source: "./image/pulse_brand_mark.png"
        sourceSize.width:  rail.brandSize * 2
        sourceSize.height: rail.brandSize * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        opacity: 0.45
    }

    // ── FOOT: hide the rail, pinned ─────────────────────────────────────────────────────
    ColumnLayout {
        id: foot

        visible: !rail.collapsed
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin:   rail.safeLeft
        anchors.bottomMargin: rail.columnBottomMargin

        spacing: rail.columnSpacing

        property string openGroup: rail.openGroup

        // COLLAPSE, not "back". The first device build proved these two read as one thing
        // when they share a glyph: the arrow was tapped expecting the rail to get out of
        // the way, and it left the whole UI instead.
        //
        // pulse_setting_collapse / _show were a colourless chevron PAIR pointing up and
        // down - so they drew black on a black rail, and they pointed the wrong way for a
        // control that moves sideways. pulse_rail_hide / _show are white and point the way
        // the rail actually goes.
        PulseRailButton {
            uiScale: rail.uiScale
            buttonId: "collapse"
            label: "Hide the rail"
            iconSource: "./icons/ui/pulse_rail_hide.svg"
            onActivated: rail.collapseToggled()
        }
    }
}
