import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Echo.UI 1.0
import QtQuick.Window

Item {
    id: root

    // ---------------------------------------------------------------------
    // Platform / scaling
    // ---------------------------------------------------------------------

    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real shortSide: Math.min(Screen.width, Screen.height)
    readonly property real s: Math.max(1.0, shortSide / 1100)

    readonly property int baseWidth: 260
    readonly property int baseHeight: 70

    implicitWidth: Math.round(baseWidth * s)
    implicitHeight: Math.round(baseHeight * s)

    width: implicitWidth
    height: implicitHeight

    // ---------------------------------------------------------------------
    // Sizing
    // ---------------------------------------------------------------------

    property int controlIconSize: Math.round(24 * s)
    property int pressButtonSize: Math.round(56 * s)
    property int displayPixels: Math.round(60 * s)

    property int valueTextWidth: Math.round(60 * s)
    property int valueTextHeight: Math.round(40 * s)

    property int valuePixels: Math.round(36 * s)
    property int autoPixels: Math.round(32 * s)

    property int selectIconSize: Math.round(64 * s)
    property int selectCheckSize: Math.round(48 * s)

    // ---------------------------------------------------------------------
    // Public API
    // ---------------------------------------------------------------------

    property alias value: valueField.text

    property int minValue: 0
    property int maxValue: 100
    property int step: 1
    property int defaultValue: 0

    property int progressBarHeight: 5
    property string iconSource: ""
    property string controleName: ""

    property string autoDepth: "auto"
    property string autoFilter: "auto"
    property int autoRangeState: -1

    property bool allowLongPressControl: true

    property bool isAutoRangeActive: false

    property bool isAutoFilterActive: pulseSettings
                                      ? pulseSettings.autoFilter &&
                                        (
                                            pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseRed ||
                                            pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseRedProto
                                        )
                                      : false

    property real quickChangeMaxRangeValue: root.defaultValue

    signal distanceAutoRangeRequested()
    signal distanceFixedRangeRequested()

    signal filterAutoRangeRequested()
    signal filterFixedRangeRequested()

    signal selectorValueChanged(int newValue)

    // Internal guard to avoid duplicate selectorValueChanged emissions
    property bool _settingValueInternally: false

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function controlMinimum() {
        if (root.controleName === "selectorIntensity")
            return 0

        if (root.controleName === "selectorFiltering")
            return 0

        return root.minValue
    }

    function controlMaximum() {
        if (root.controleName === "selectorMaxDepth")
            return pulseRuntimeSettings.maximumDepth

        if (root.controleName === "selectorIntensity")
            return 20

        if (root.controleName === "selectorFiltering")
            return 20

        return root.maxValue
    }

    function currentNumericValue() {
        let parsed = parseInt(valueField.text, 10)

        if (isNaN(parsed))
            return root.defaultValue

        return parsed
    }

    function clampValue(value, customMaximum) {
        let minimum = root.controlMinimum()
        let maximum = customMaximum === undefined ? root.controlMaximum() : customMaximum

        return Math.max(minimum, Math.min(maximum, value))
    }

    function setSelectorValue(newValue, customMaximum) {
        let clampedValue = root.clampValue(newValue, customMaximum)

        root._settingValueInternally = true
        valueField.text = String(clampedValue)
        root._settingValueInternally = false

        root.quickChangeMaxRangeValue = clampedValue
        root.selectorValueChanged(clampedValue)
    }

    function disableAutoIfNeeded() {
        if (root.isAutoRangeActive && root.controleName === "selectorMaxDepth") {
            root.distanceFixedRangeRequested()
            root.isAutoRangeActive = false
        }

        if (root.isAutoFilterActive && root.controleName === "selectorFiltering") {
            root.filterFixedRangeRequested()
            root.isAutoFilterActive = false
        }
    }

    function adjustValue(delta) {
        root.disableAutoIfNeeded()

        let current = root.currentNumericValue()
        let s = root.step
        let nextValue

        // When the value is off the step grid (e.g. set to an in-between value by a finger
        // pinch), a tap should snap to the nearest allowed grid value in the tap's direction
        // (step 5: 12 -> tap up -> 15, tap down -> 10) rather than just adding the step
        // (12 -> 17). On-grid values step normally, so 2D (step 1) and long-press behaviour
        // are unchanged.
        if (s > 1 && (current % s) !== 0) {
            nextValue = delta > 0 ? Math.ceil(current / s) * s
                                  : Math.floor(current / s) * s
        } else {
            nextValue = current + delta
        }

        root.setSelectorValue(nextValue)
    }

    function autoFunctionAllowed() {
        if (pulseRuntimeSettings.devName === "...")
            return false

        if (pulseRuntimeSettings.pulseBetaName !== "...") {
            if (pulseRuntimeSettings.pulseBetaName === pulseRuntimeSettings.pulseBlueBeta)
                return false
        }

        if (pulseRuntimeSettings.devName === pulseRuntimeSettings.modelPulseBlue)
            return false

        return true
    }

    function toggleAutoMode() {
        if (!root.autoFunctionAllowed())
            return

        if (root.controleName === "selectorMaxDepth") {
            if (root.isAutoRangeActive) {
                root.distanceFixedRangeRequested()
                root.isAutoRangeActive = false
            } else {
                root.distanceAutoRangeRequested()
                root.isAutoRangeActive = true
            }
        }

        if (root.controleName === "selectorFiltering") {
            if (root.isAutoFilterActive) {
                root.filterFixedRangeRequested()
                root.isAutoFilterActive = false
            } else {
                root.filterAutoRangeRequested()
                root.isAutoFilterActive = true
            }
        }
    }

    // ---------------------------------------------------------------------
    // Long press handling
    // ---------------------------------------------------------------------

    Timer {
        id: longPressControlTimer

        interval: 200
        repeat: true

        property real pressDuration: 0
        property string buttonPressed: ""

        onTriggered: {
            pressDuration += interval

            let currentStep = pressDuration >= 3000
                            ? root.step * 2
                            : root.step

            if (buttonPressed === "minus")
                root.adjustValue(-currentStep)
            else if (buttonPressed === "plus")
                root.adjustValue(currentStep)
        }
    }

    // ---------------------------------------------------------------------
    // External settings connections
    // ---------------------------------------------------------------------

    Connections {
        target: pulseSettings ? pulseSettings : undefined

        function onEchogramWidthChanged() {
            if (!pulseSettings)
                return

            if (root.controleName !== "selectorMaxDepth")
                return

            if (pulseRuntimeSettings.is2DTransducer)
                return

            let newMaxDepthValue = pulseSettings.echogramWidth

            if (pulseSettings.maxDepthValuePulseBlue > newMaxDepthValue && pulseRuntimeSettings.isSideScan2DView) {
                console.log("EchogramWidth: selector max depth set pulseSettings.maxDepthValuePulseBlue from", pulseSettings.maxDepthValuePulseBlue, "to", newMaxDepthValue)
                pulseSettings.maxDepthValuePulseBlue = newMaxDepthValue
            }

            if (pulseSettings.maxDepthValuePulseBlueFixed > newMaxDepthValue && pulseRuntimeSettings.isSideScan2DView) {
                console.log("EchogramWidth: selector max depth set pulseSettings.maxDepthValuePulseBlue from", pulseSettings.maxDepthValuePulseBlueFixed, "to", newMaxDepthValue)
                pulseSettings.maxDepthValuePulseBlueFixed = newMaxDepthValue
            }

            if (root.quickChangeMaxRangeValue > newMaxDepthValue) {
                console.log("EchogramWidth: selector max depth set root.quickChangeMaxRangeValue from", root.quickChangeMaxRangeValue, "to", newMaxDepthValue)
                root.setSelectorValue(newMaxDepthValue, newMaxDepthValue)
            }
        }
    }

    Connections {
        target: pulseRuntimeSettings

        function onUserManualSetNameChanged() {
            console.log("Auto function: onUserManualSetNameChanged triggered for",
                        pulseRuntimeSettings.userManualSetName)

            let isPulseBlue =
                    pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.modelPulseBlue ||
                    pulseRuntimeSettings.userManualSetName === pulseRuntimeSettings.pulseBlueBeta ||
                    !pulseRuntimeSettings.is2DTransducer

            if (!isPulseBlue) {
                console.log("Auto function: horizontal controller, no change for",
                            pulseRuntimeSettings.userManualSetName,
                            "needed")
                return
            }

            if (root.controleName === "selectorMaxDepth") {
                let maxRange = pulseRuntimeSettings.maximumDepth * 1.0

                //pulseSettings.maxDepthValuePulseBlue = maxRange
                //pulseSettings.maxDepthValuePulseBlueFixed = maxRange

                //root.setSelectorValue(maxRange)
                if (pulseRuntimeSettings.isSideScan2DView) {
                    console.log("onUserManualSetNameChanged: selector max depth set root.setSelectorValue to value pulseSettings.maxDepthValuePulseBlue", pulseSettings.maxDepthValuePulseBlue)
                    root.setSelectorValue(pulseSettings.maxDepthValuePulseBlue)
                } else {
                    console.log("onUserManualSetNameChanged: selector max depth set root.setSelectorValue to value pulseSettings.maxDepthValuePulseBlueFixed", pulseSettings.maxDepthValuePulseBlueFixed)
                    root.setSelectorValue(pulseSettings.maxDepthValuePulseBlueFixed)
                }

                pulseSettings.autoRange = false
                root.isAutoRangeActive = false
                root.distanceFixedRangeRequested()

                console.log("Auto function: horizontal controller setting auto range to",
                            pulseSettings.autoRange)
            }

            if (root.controleName === "selectorFiltering") {
                pulseSettings.autoFilter = false
                root.isAutoFilterActive = false
                root.filterFixedRangeRequested()

                console.log("Auto function: horizontal controller setting auto filter to",
                            pulseSettings.autoFilter)
            }
        }

        function onIsSideScan2DViewChanged() {
            if (root.controleName !== "selectorMaxDepth")
                return

            if (pulseRuntimeSettings.is2DTransducer)
                return

            if (pulseRuntimeSettings.isSideScan2DView) {
                console.log("onIsSideScan2DViewChanged: selector max depth set root.setSelectorValue to value pulseSettings.maxDepthValuePulseBlue", pulseSettings.maxDepthValuePulseBlue)
                root.setSelectorValue(pulseSettings.maxDepthValuePulseBlue)
            }
            else {
                console.log("onIsSideScan2DViewChanged: selector max depth set root.setSelectorValue to value pulseSettings.maxDepthValuePulseBlueFixed", pulseSettings.maxDepthValuePulseBlueFixed)
                root.setSelectorValue(pulseSettings.maxDepthValuePulseBlueFixed)
            }
        }
    }

    // ---------------------------------------------------------------------
    // Background oval
    // ---------------------------------------------------------------------

    Rectangle {
        id: outerShape

        anchors.fill: parent

        radius: height / 2
        color: "#80000000"
        border.color: "#40ffffff"
        border.width: 1

        // Absorbs clicks outside the active controls.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: false
            preventStealing: true
            onPressed: {}
        }

        // -----------------------------------------------------------------
        // Main horizontal content
        // -----------------------------------------------------------------

        RowLayout {
            id: contentRow

            anchors.centerIn: parent

            width: implicitWidth
            height: parent.height

            spacing: Math.round(5 * root.s)

            // -------------------------------------------------------------
            // Icon
            // -------------------------------------------------------------

            Image {
                id: controlIcon

                Layout.preferredWidth: root.controlIconSize
                Layout.preferredHeight: root.controlIconSize
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Math.round(12 * root.s)

                fillMode: Image.PreserveAspectFit
                source: root.iconSource
            }

            // -------------------------------------------------------------
            // Minus button
            // -------------------------------------------------------------

            Rectangle {
                id: selectorMinusButton

                Layout.preferredWidth: root.pressButtonSize
                Layout.preferredHeight: root.pressButtonSize
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Math.round(4 * root.s)

                radius: height / 2
                color: minusMouseArea.pressed ? "#666666" : "transparent"

                Text {
                    anchors.centerIn: parent

                    text: "-"
                    font.pixelSize: root.displayPixels
                    font.bold: true
                    color: minusMouseArea.pressed ? "#80000000" : "white"
                }

                MouseArea {
                    id: minusMouseArea

                    anchors.fill: parent
                    preventStealing: true

                    onClicked: {
                        longPressControlTimer.stop()
                        root.adjustValue(-root.step)
                    }

                    onPressed: {
                        longPressControlTimer.buttonPressed = "minus"
                        longPressControlTimer.pressDuration = 0

                        if (root.allowLongPressControl)
                            longPressControlTimer.start()
                    }

                    onReleased: {
                        longPressControlTimer.stop()
                        longPressControlTimer.pressDuration = 0
                        longPressControlTimer.buttonPressed = ""
                    }

                    onCanceled: {
                        longPressControlTimer.stop()
                        longPressControlTimer.pressDuration = 0
                        longPressControlTimer.buttonPressed = ""
                    }
                }
            }

            // -------------------------------------------------------------
            // Value cell
            // -------------------------------------------------------------

            Item {
                id: valueCell

                Layout.preferredWidth: root.valueTextWidth
                Layout.preferredHeight: root.pressButtonSize
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: valueField

                    anchors.centerIn: parent

                    text: String(root.defaultValue)
                    font.pixelSize: root.valuePixels
                    color: "white"

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    visible: root.controleName === "selectorIntensity" ||
                             (root.controleName === "selectorMaxDepth" && !root.isAutoRangeActive) ||
                             (root.controleName === "selectorFiltering" && !root.isAutoFilterActive)

                    onTextChanged: {
                        if (root._settingValueInternally)
                            return

                        let parsed = parseInt(valueField.text, 10)

                        if (isNaN(parsed))
                            return

                        root.quickChangeMaxRangeValue = parsed
                        root.selectorValueChanged(parsed)
                    }
                }

                Text {
                    id: valueFieldAuto

                    anchors.centerIn: parent

                    text: root.controleName === "selectorFiltering"
                          ? root.autoFilter
                          : root.autoDepth

                    font.pixelSize: root.autoPixels
                    color: "white"

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    visible: (root.controleName === "selectorMaxDepth" && root.isAutoRangeActive) ||
                             (root.controleName === "selectorFiltering" && root.isAutoFilterActive)
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true

                    onClicked: root.toggleAutoMode()
                }
            }

            // -------------------------------------------------------------
            // Plus button
            // -------------------------------------------------------------

            Rectangle {
                id: selectorPlusButton

                Layout.preferredWidth: root.pressButtonSize
                Layout.preferredHeight: root.pressButtonSize
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: Math.round(4 * root.s)

                radius: height / 2
                color: plusMouseArea.pressed ? "#666666" : "transparent"

                Text {
                    anchors.centerIn: parent

                    text: "+"
                    font.pixelSize: root.displayPixels
                    font.bold: true
                    color: plusMouseArea.pressed ? "#80000000" : "white"
                }

                MouseArea {
                    id: plusMouseArea

                    anchors.fill: parent
                    preventStealing: true

                    onClicked: {
                        longPressControlTimer.stop()
                        root.adjustValue(root.step)
                    }

                    onPressed: {
                        longPressControlTimer.buttonPressed = "plus"
                        longPressControlTimer.pressDuration = 0

                        if (root.allowLongPressControl)
                            longPressControlTimer.start()
                    }

                    onReleased: {
                        longPressControlTimer.stop()
                        longPressControlTimer.pressDuration = 0
                        longPressControlTimer.buttonPressed = ""
                    }

                    onCanceled: {
                        longPressControlTimer.stop()
                        longPressControlTimer.pressDuration = 0
                        longPressControlTimer.buttonPressed = ""
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------------
    // Initial state sync
    // ---------------------------------------------------------------------

    Component.onCompleted: {
        root.quickChangeMaxRangeValue = root.defaultValue

        if (root.controleName === "selectorMaxDepth")
            root.isAutoRangeActive = pulseSettings ? pulseSettings.autoRange : false

        if (root.controleName === "selectorFiltering")
            root.isAutoFilterActive = pulseSettings ? pulseSettings.autoFilter : false
    }
}
