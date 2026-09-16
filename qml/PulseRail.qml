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

    // SCAFFOLDING, removed by stage 4 (b). The switch that turns v2 on lives in the expert
    // settings INSIDE the classic UI, and uiVariant is persisted - so until the settings
    // panel exists, v2 must carry its own way back or turning it on strands the app.
    property bool showBackToClassic: true

    // COLLAPSED. One binding on the persisted setting, set by the host; the toggle writes
    // the SETTING, never this property - assigning here would destroy the binding and the
    // rail would stop following the stored value for the rest of the run.
    property bool collapsed: false

    // WHICH GROUP THE PANEL IS SHOWING, "" when it is closed. The rail does not own the
    // panel and does not decide anything about it - it only wears the state, so the button
    // that opened a group is the one lit while it is open.
    property string openGroup: ""

    property bool paused: false

    signal buttonActivated(string id)
    signal sourceActivated()
    signal backToClassic()
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
    readonly property real wordmarkHeight:     Math.round(150 * uiScale)
    // THE SLOT IS THE ROOM THE WORDMARK USED TO TAKE INSIDE THE LAYOUT, to the pixel: its
    // own 150, the Layout.topMargin of 10 it carried, and the column spacing that separated
    // it from the button above. Leaving the spacing out would move it 8 units up on every
    // device that already fits - and the point of this commit is that those devices do not
    // move at all. columnSpacing is read by the layout as well, so there is one spelling.
    readonly property real wordmarkSlot:       wordmarkHeight
                                               + Math.round(10 * uiScale)
                                               + columnSpacing
    readonly property real controlsRoom:       Math.max(0, height - columnTopMargin - columnBottomMargin)
    readonly property bool wordmarkFits:       !collapsed
                                               && (controlsRoom - column.implicitHeight) >= wordmarkSlot

    // WHAT THE PICTURE OWES THE RAIL. Zero when collapsed - the echogram takes the whole
    // screen and the tab floats over it - and the rail's full width otherwise. This is the
    // one number a host has to read to give the echogram the rest of the screen.
    readonly property real inset: collapsed ? 0 : railWidth

    // A plain width is correct here: the rail is ANCHORED by its parent, not a Layout child.
    width: collapsed ? tabWidth : railWidth

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
    // state is persisted. A drawer handle on the edge the rail left from, vertically
    // centred, which is the easiest place on the screen to reach one-thumb from shore.
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
        anchors.verticalCenter: parent.verticalCenter
        width:  Math.round(30 * rail.uiScale) + radius
        height: Math.round(64 * rail.uiScale)
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

    ColumnLayout {
        id: column

        visible: !rail.collapsed
        anchors.fill: parent
        anchors.leftMargin:   rail.safeLeft
        anchors.topMargin:    rail.columnTopMargin
        // THE SLOT IS RESERVED HERE, not taken by the wordmark itself. The fill-height
        // spacer sits in the MIDDLE of this column, so the lower group is bottom-aligned
        // against this margin - which is exactly where the wordmark used to push it from
        // inside. Reserving rather than squeezing is what stops the Image overflowing.
        anchors.bottomMargin: rail.columnBottomMargin
                              + (rail.wordmarkFits ? rail.wordmarkSlot : 0)

        spacing: rail.columnSpacing

        // WHAT IS OPEN, SAID ONCE, to the whole column. Every PulseRailButton below is a
        // direct child of this layout and defaults its own `openGroup` from here, then
        // compares it with its own buttonId - so the button that opened a group is the one
        // lit, and no button can be added without that being true of it. This is the single
        // line that replaces one line per button, of which exactly one was ever written.
        property string openGroup: rail.openGroup

        PulseRailButton {
            uiScale: rail.uiScale
            buttonId: "colours"
            label: "Colours"
            iconSource: "./icons/ui/pulse_color_choice.svg"
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
            buttonId: "range"
            label: "Max range"
            iconSource: "./icons/ui/pulse_ruler.svg"
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

        PulseRailButton {
            uiScale: rail.uiScale
            buttonId: "pause"
            label: "Pause and inspect"
            // Never true while the rail is showing - pausing replaces the rail with the
            // gutter - but the property is what a later "pause is pending" state would use,
            // and a button that cannot show its own state is a button to fix later.
            active: rail.paused
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
        // backlog item 9 never had. It is also the only live control in this slice.
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

        PulseRailButton {
            uiScale: rail.uiScale
            buttonId: "backToClassic"
            label: "Back to the classic UI"
            visible: rail.showBackToClassic
            iconSource: "./icons/ui/pulse_arrow_left.svg"
            onActivated: rail.backToClassic()
        }
    }

    // The wordmark leaves the picture and comes to the foot of the rail, which is what
    // takes the watermark off the echogram itself. Rotation does not change an item's
    // layout size, so the box is sized for the ROTATED result and the image is centred
    // inside it.
    //
    // OUT OF THE LAYOUT, IN THE SAME PLACE. Anchored to the foot of the rail, in the slot
    // the column's bottom margin reserves for it, so where it is drawn has not changed -
    // only what happens when there is nowhere to draw it. Centred on the CONTENT area
    // rather than on the item, which is what Layout.alignment did for it before: the
    // content starts at safeLeft, so its centre is half of safeLeft to the right of the
    // rail's own.
    Item {
        id: wordmark

        visible: rail.wordmarkFits

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: Math.round(rail.safeLeft / 2)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: rail.columnBottomMargin

        width:  Math.round(40 * rail.uiScale)
        height: rail.wordmarkHeight

        Image {
            anchors.centerIn: parent
            width:  Math.round(150 * rail.uiScale)
            height: Math.round(30 * rail.uiScale)
            rotation: -90
            source: "./image/logo_techadvision_gray.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: 0.42
        }
    }
}
