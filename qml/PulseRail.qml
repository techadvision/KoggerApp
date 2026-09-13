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
//   WHICH BUTTONS EXIST reads the COMMITTED profile (offersView / offersCone). A chooser
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
    property bool offersView: false
    property bool offersCone: false

    // --- app state the rail shows ---
    property bool recording:     false
    property bool presentingLog: false

    // THE SOURCE BUTTON CARRIES NO STATE YET, on purpose. The link's one honest line -
    // talking / identifying / lost / wasConnected / found / absent, and its colour - is
    // derived inside PulseConnectionScreen, and QML ids do not cross files, so this rail
    // cannot read it from there. Recomputing it here would be a second opinion about the
    // same facts, which is precisely what that screen was built to stop. The next commit
    // hoists the derivation onto pulseRuntimeSettings - one computation, two readers - and
    // this button gets its dot then.

    // SCAFFOLDING, removed by stage 4 (b). The switch that turns v2 on lives in the expert
    // settings INSIDE the classic UI, and uiVariant is persisted - so until the settings
    // panel exists, v2 must carry its own way back or turning it on strands the app.
    property bool showBackToClassic: true

    // COLLAPSED. One binding on the persisted setting, set by the host; the toggle writes
    // the SETTING, never this property - assigning here would destroy the binding and the
    // rail would stop following the stored value for the rest of the run.
    property bool collapsed: false

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
            source: "./icons/ui/pulse_setting_show.svg"
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
        anchors.topMargin:    Math.round(10 * rail.uiScale) + rail.topInset
        anchors.bottomMargin: Math.round(10 * rail.uiScale) + rail.safeBottom

        spacing: Math.round(8 * rail.uiScale)

        PulseRailButton {
            uiScale: rail.uiScale
            buttonId: "colours"
            label: "Colours"
            iconSource: "./icons/ui/pulse_color_choice.svg"
            onActivated: rail.buttonActivated(buttonId)
        }

        // ONE BUTTON, TWO QUESTIONS - a VIEW on blue, a CONE on red - and absent entirely
        // when the committed device offers neither. Absent rather than greyed out: a
        // control that cannot be used is not a control, and the profile map already says
        // "never offer a choice of one".
        //
        // The icon is static in this slice. Showing the CURRENT selection's icon means
        // reading ecoViewId / ecoConeId, and that belongs with the chooser itself in
        // stage 4 (b) - the profile map already carries a per-entry icon for it.
        PulseRailButton {
            uiScale: rail.uiScale
            buttonId: rail.offersCone ? "cone" : "view"
            label: rail.offersCone ? "Cone" : "View"
            visible: rail.offersView || rail.offersCone
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
            iconSource: "./icons/ui/pulse_play_pause.svg"
            onActivated: rail.buttonActivated(buttonId)
        }

        // RECORDING A REPLAY would produce a confusing second-generation log, which is why
        // the Recording tab has always refused it. Here the button is absent rather than
        // dead, and the pill on the picture says why: it reads "Demo - PULSE blue".
        PulseRailButton {
            uiScale: rail.uiScale
            buttonId: "record"
            label: "Record"
            visible: !rail.presentingLog
            active: rail.recording
            iconSource: rail.recording ? "./icons/ui/pulse_recording_active.svg"
                                       : "./icons/ui/pulse_recording_inactive.svg"
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

            // PLACEHOLDER GLYPH. device-transducer.svg is upstream's, so it is not drawn in
            // the PULSE icon family the rest of this rail uses. Worth one of Olav's own.
            Image {
                anchors.centerIn: parent
                width:  Math.round(34 * rail.uiScale)
                height: width
                source: "./icons/ui/device-transducer.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true
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
        PulseRailButton {
            uiScale: rail.uiScale
            buttonId: "collapse"
            label: "Hide the rail"
            iconSource: "./icons/ui/pulse_setting_collapse.svg"
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

        // The wordmark leaves the picture and comes to the foot of the rail, which is what
        // takes the watermark off the echogram itself. Rotation does not change an item's
        // layout size, so the box is sized for the ROTATED result and the image is centred
        // inside it.
        Item {
            Layout.preferredWidth:  Math.round(40 * rail.uiScale)
            Layout.preferredHeight: Math.round(150 * rail.uiScale)
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(10 * rail.uiScale)

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
}
