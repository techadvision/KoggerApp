import QtQuick 2.15

// The Pulse user interface - one level of indirection above the interface itself.
//
// Stage 2 of the UI modernisation (docs/pulse-ui/pulse-ui-strategy.md). Plot2D
// instantiates THIS; this picks which interface to build, from the persisted
// pulseSettings.uiVariant. The point of the indirection is that a new UI can be
// developed and shipped alongside the one that works, and the two compared on the
// water by flipping a switch in expert settings rather than by swapping a build.
//
//   PulseApp.qml            <- you are here, dispatches on pulseSettings.uiVariant
//     PulseAppClassic.qml   <- today's UI, unchanged since the Stage 1 extraction
//     PulseAppV2.qml        <- the new design; a placeholder until Stage 4
//
// THE VARIANT CONTRACT. Every PulseApp* variant must provide:
//
//   property var  plot            the WaterFall root - passed in, never guessed
//   property var  pinch           Plot2D's PinchArea, for its isLiveView flag
//   property real maxDepthValue   writable; the max-depth selector's value
//   function applyFiltering(value)
//   function armOldDataWarning()
//
// Plot2D never touches a variant directly. It holds this object as `pulseUi` and
// calls the three functions under "API used by Plot2D" below. That is the whole
// seam, and it is deliberately functions rather than aliases: a Loader's item
// cannot be the target of a property alias, and a function is a contract a
// variant is free to implement however it likes.

Item {
    id: pulseApp

    // `parent` is the WaterFall root this sits in. Defaulting to it avoids the
    // `plot: plot` self-resolution trap on the instantiating side.
    property var plot:  parent
    property var pinch: null

    anchors.fill: parent

    // ---- Variant selection --------------------------------------------------

    // Anything we do not recognise resolves to classic. uiVariant is persisted,
    // so a value written by a future build, a hand-edited settings file or a
    // half-finished experiment must never be able to start the app with no
    // interface at all.
    readonly property string variant: pulseSettings.uiVariant === "v2" ? "v2" : "classic"

    readonly property Item ui: variantLoader.item

    // ---- API used by Plot2D -------------------------------------------------

    function setMaxDepth(value) {
        if (ui)
            ui.maxDepthValue = value
    }

    function applyFiltering(value) {
        if (ui)
            ui.applyFiltering(value)
    }

    function armOldDataWarning() {
        if (ui)
            ui.armOldDataWarning()
    }

    // -------------------------------------------------------------------------

    Loader {
        id: variantLoader
        anchors.fill: parent

        // sourceComponent rather than source: an inline Component binds `plot` and
        // `pinch` lexically, so the variant is created WITH them already set. Going
        // through a URL would build the object first and set the properties after,
        // and every `plot.*` binding inside would evaluate once against null on the
        // way past.
        sourceComponent: pulseApp.variant === "v2" ? variantV2 : variantClassic

        onLoaded: console.log("PULSE UI: variant loaded ->", pulseApp.variant)
    }

    Component {
        id: variantClassic
        PulseAppClassic {
            plot:  pulseApp.plot
            pinch: pulseApp.pinch
        }
    }

    Component {
        id: variantV2
        PulseAppV2 {
            plot:  pulseApp.plot
            pinch: pulseApp.pinch
        }
    }
}
