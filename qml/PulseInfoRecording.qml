import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import Echo.UI 1.0
import QtQuick.Window
import QtCore

Rectangle {
    id: settingsPopup

    property string filePath: pathText.text
    property var lastLogFolder: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    //property var lastImportTrackFolder: StandardPaths.writableLocation(StandardPaths.HomeLocation)

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real platformScale: _isAndroid ? 0.9 : 0.75
    //readonly property real s: Ui.scale * platformScale
    readonly property real shortSide: Math.min(Screen.width, Screen.height)
    readonly property real s: Math.max(1.0, shortSide / 1100) // tune 800 to your “10-inch baseline”
    // Platform related sizes
    property int controlIconSize: Math.round(24 * s)
    property int pressButtonSize: Math.round(56 * s)
    property int displayPixels:   Math.round(60 * s)
    property int valueTextWidth:  Math.round(60 * s)
    property int valueTextHeigh:  Math.round(40 * s)
    property int valuePixels:     Math.round(42 * s)
    property int autoPixels:      Math.round(32 * s)
    property int selectIconSize:  Math.round(64 * s)
    property int selectCheckSize: Math.round(48 * s)

    // Base “design” size for this control on your 10" tablet
    readonly property int baseWidth: 900
    // 400 was exactly consumed by the original three rows plus margins. The demo
    // row needs another 80 + 20; the tabbed settings page has ~495*s available
    // (550*s * 0.98 minus the 44*s header), so 460 fits with room to spare.
    readonly property int baseHeight: 460
    implicitWidth:  Math.round(baseWidth  * s)
    implicitHeight: Math.round(baseHeight * s)
    width:  implicitWidth
    height: implicitHeight
    /*
    property int controlIconSize: _isAndroid ? 34 : 20
    property int pressButtonSize: _isAndroid ? 80 : 40
    property int displayPixels:   _isAndroid ? 100 : 40
    property int valueTextWidth:  _isAndroid ? 60 : 40
    property int valueTextHeigh:  _isAndroid ? 40 : 30
    property int valuePixels:     _isAndroid ? 42 : 32
    property int autoPixels:      _isAndroid ? 32 : 24
    property int selectIconSize:  _isAndroid ? 80 : 60
    property int selectCheckSize: _isAndroid ? 56 : 40
    property int infoPixelsSize:  _isAndroid ? 28 : 18
    */

    focus: true
    //width: _isAndroid ? 900 : 600
    //height: _isAndroid ? 400 : 270
    anchors.centerIn: parent
    color: "white"
    radius: Math.round(8 * s) //8

    signal pulsePreferenceClosed()
    signal pulsePreferenceValueChanged(double newValue)

    //DEMO MODE: short display name for the log being replayed.
    //
    //Declared on the file root, so call it qualified as
    //settingsPopup.demoDisplayName(...) — see the note on layout.compensationLabel
    //below for why unqualified function lookup is not enough here.
    //
    //The hard case is Android. The file dialog hands back a Storage Access
    //Framework URI, not a path, and it percent-encodes the real separators:
    //  content://com.android.externalstorage.documents/document/
    //      primary%3ADocuments%2FKogger%2Frecord_2026.07.15_16.32.46.plog
    //%3A is ':' and %2F is '/', so before decoding the whole thing is ONE path
    //segment and any "last segment" logic returns the entire URI — which is how
    //this ended up displaying "primary%3ADoc...7.15_16.32.46".
    //
    //Order matters: decode first, then take the last segment.
    function demoDisplayName(raw) {
        var s = String(raw)

        // decodeURIComponent throws URIError on a stray '%' (a legal filename
        // character), so a malformed escape must fall back to the raw string
        // rather than blowing up the binding.
        try {
            s = decodeURIComponent(s)
        } catch (e) {
            // keep s as-is
        }

        // Some provider URIs carry a query or fragment.
        s = s.replace(/[?#].*$/, "")

        // Last path segment (either separator), minus the FINAL extension:
        //   ([^\\\/]+?)      the segment, lazy so it stops before...
        //   (\.[^.\\\/]*)?   ...the last extension, if there is one
        //   $                anchored, so only the trailing segment can match
        // Only the last dot counts, so "record_2026.07.15_16.32.46.plog" keeps
        // its timestamp and loses just ".plog".
        var m = /([^\\\/]+?)(\.[^.\\\/]*)?$/.exec(s)
        var name = m ? m[1] : ""

        // Decoded SAF URIs leave a volume prefix on the segment when the file
        // sits at the storage root, e.g. "primary:record_....plog".
        name = name.substring(name.lastIndexOf(":") + 1)

        return name.length > 0 ? name : "starting ..."
    }

    FileDialog {
        id: newFileDialog
        title: "Choose file to render"
        //currentFolder: shortcuts.home
        currentFolder: lastLogFolder

        nameFilters: ["Logs (*.plog *.PLOG *.ubx *.UBX *.xtf *.XTF)", "Kogger log files (*.plog *.PLOG)", "U-blox (*.ubx *.UBX)"]

        onCurrentFolderChanged: {
            settingsPopup.lastLogFolder = currentFolder
        }

        onAccepted: {
            const file = newFileDialog.selectedFile
            if (!file) {
                console.log("lonAccepted: File was null, abort")
                return
            }

            settingsPopup.lastLogFolder = newFileDialog.currentFolder

            const fileStr = file.toString()
            pathText.text = fileStr.replace("file:///", Qt.platform.os === "windows" ? "" : "/")

            var name_parts = fileStr.split('.')
            core.openLogFile(pathText.text, false, false)

            pulseRuntimeSettings.klfFilePath = pathText.text
        }
        onRejected: {
        }
    }

    //DEMO MODE (Stage 1) — see demo_mode_plan.md.
    //Separate dialog from newFileDialog on purpose: that one opens a file for
    //browsing (core.openLogFile, sets wasKlfFileOpened), this one starts a paced
    //replay that the app experiences as a live connection.
    FileDialog {
        id: demoFileDialog
        title: "Choose a log to replay as a demo"
        currentFolder: lastLogFolder

        nameFilters: ["Kogger log files (*.plog *.PLOG)"]

        onCurrentFolderChanged: {
            settingsPopup.lastLogFolder = currentFolder
        }

        onAccepted: {
            const file = demoFileDialog.selectedFile
            if (!file) {
                console.log("DEMO: file dialog returned null, abort")
                return
            }

            settingsPopup.lastLogFolder = demoFileDialog.currentFolder

            const fileStr = file.toString()
            const localPath = fileStr.replace("file:///", Qt.platform.os === "windows" ? "" : "/")
            pulseRuntimeSettings.enterDemoMode(localPath)
        }
        onRejected: {
        }
    }


    GridLayout {
        id: layout
        rowSpacing: Math.round(20 * s) //20
        columnSpacing: Math.round(20 * s) //20
        columns: 3

        // --- Row 1
        Text {
            text: pulseRuntimeSettings.isRecordingKlf === true ? "Recording..." : "Record a file"
            font.pixelSize: Ui.fontL //settingsPopup.infoPixelsSize

            height: Math.round(80 * s) //_isAndroid ? 80: 54
            Layout.row: 0
            Layout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: Math.round(20 * s) //20
            Layout.topMargin: Math.round(20 * s) //20
        }

        // record
        Rectangle {
            id: recording
            Layout.preferredWidth: Math.round(80 * s) //_isAndroid ? 80: 54
            Layout.preferredHeight: Math.round(80 * s) //_isAndroid ? 80: 54
            radius: 5
            Layout.row: 0
            Layout.column: 1
            color: "transparent"
            Layout.topMargin: Math.round(20 * s) //20
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

            Image {
                id: iconRecording
                source: pulseRuntimeSettings.isRecordingKlf === true ? "./icons/ui/pulse_recording_active.svg" : "./icons/ui/pulse_recording_inactive.svg"
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                // DEMO MODE: recording a replay would produce a confusing
                // second-generation log.
                enabled: !pulseRuntimeSettings.wasKlfFileOpened && !pulseRuntimeSettings.isInDemoMode
                onClicked: {
                    pulseRuntimeSettings.isRecordingKlf = !pulseRuntimeSettings.isRecordingKlf
                    core.loggingKlf = pulseRuntimeSettings.isRecordingKlf
                }
            }
        }

        // --- Row 2
        Text {
            visible: !pulseRuntimeSettings.isRecordingKlf
            text: {
                if (core.isFileOpening) {
                    return "File chosen"
                } else {
                    if (pulseRuntimeSettings.wasKlfFileOpened) {
                        return "Showing file"
                    } else {
                        return "Show a file"
                    }
                }
            }

            font.pixelSize: Ui.fontL //settingsPopup.infoPixelsSize

            height: Math.round(80 * s) //_isAndroid ? 80: 54
            Layout.row: 1
            Layout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: Math.round(20 * s) //20
        }

        // view a file statement
        Rectangle {
            visible: !pulseRuntimeSettings.isRecordingKlf
            width: Math.round(80 * s) //_isAndroid ? 80: 54
            height: Math.round(80 * s) //_isAndroid ? 80: 54
            Layout.preferredWidth: Math.round(80 * s) //_isAndroid ? 80: 54
            Layout.preferredHeight: Math.round(80 * s) //_isAndroid ? 80: 54
            radius: 5
            Layout.row: 1
            Layout.column: 1
            color: "transparent"
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

            Image {
                id: iconOpen
                source: "./icons/ui/pulse_open.svg"
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    newFileDialog.open()
                }
            }

        }

        // show the file is being opened
        Item {
            id: openingIndicator
            visible: !pulseRuntimeSettings.isRecordingKlf && core.isFileOpening
            Layout.row: 1
            Layout.column: 2
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: Math.round(20 * s) //20
            Layout.minimumWidth: Math.round(400 * s) //_isAndroid ? 400 : 270
            Layout.preferredWidth: Layout.minimumWidth

            RowLayout {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: qsTr("Wait - opening file ...")
                    font.pixelSize: Ui.fontL //settingsPopup.infoPixelsSize
                    height: Math.round(80 * s) //_isAndroid ? 80: 54
                    Layout.leftMargin: Math.round(20 * s) //20
                }

                Image {
                    id: iconToWait
                    source: "./icons/ui/pulse_waiting.svg"
                    Layout.preferredWidth: Math.round(54 * s) //_isAndroid ? 54 : 42
                    Layout.preferredHeight: Math.round(54 * s) //_isAndroid ? 54 : 42
                    fillMode: Image.PreserveAspectFit
                    //smooth: true
                }

                /* TODO: If we can get it to open async, here is the spinning wheel ready
                PulseSpinner {
                    id: fileOpenSpinner
                    width: 24
                    height: 24
                    strokeColor: "black"
                }
                */
            }
        }

        // show the file path
        CTextField {
            id: pathText
            visible: !pulseRuntimeSettings.isRecordingKlf && !core.isFileOpening
            hoverEnabled: true
            Layout.row: 1
            Layout.column: 2
            Layout.minimumWidth: Math.round(400 * s) //_isAndroid ? 400: 270
            Layout.preferredWidth: Math.round(400 * s) //_isAndroid ? 400: 270

            text: pulseRuntimeSettings.klfFilePath
            placeholderText: "Enter path"
            //inputMethodHints: Qt.ImhActionDone

            Keys.onReturnPressed: {
                //console.log("log viewer: Keys.onReturnPressed")
                //const p = pathText.text.trim()
                if (pathText.text.length > 0) {
                    pulseRuntimeSettings.klfFilePath = pathText.text
                    //core.filePath = pathText.text
                    core.openLogFile(pathText.text, false, false)
                    //TODO: Make it async
                    //core.openLogFileAsync(pathText.text, false, false)
                    //console.log("log viewer: open file again")
                } else {
                    //console.log("log viewer: text length 0")
                }

                if (pathText.activeFocus) {
                    pathText.focus = false
                    //console.log("log viewer: clear the focus to be able to reenter keyboard later")
                } else {
                    //console.log("log viewer: does not have active focus")
                }
            }

            Keys.onPressed: {
                if (event.key === 16777220 || event.key === Qt.Key_Enter) {
                    pulseRuntimeSettings.klfFilePath = pathText.text
                    //core.filePath = pathText.text
                    core.openLogFile(pathText.text, false, false);
                    //TODO: Make it async
                    //core.openLogFileAsync(pathText.text, false, false)

                }
            }
        }

        Text {
            visible: pulseRuntimeSettings.wasKlfFileOpened && !pulseRuntimeSettings.isOpeningKlfFile && pulseSettings.isExpert
            //visible: false
            text: "Test format"

            font.pixelSize: Ui.fontL //settingsPopup.infoPixelsSize

            height: Math.round(80 * s) //_isAndroid ? 80: 54
            Layout.row: 2
            Layout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: Math.round(20 * s) //20
        }

        Rectangle {
            id: fileOpenedIcon
            visible: pulseRuntimeSettings.wasKlfFileOpened && !pulseRuntimeSettings.isOpeningKlfFile && pulseSettings.isExpert
            //visible: false
            width: Math.round(80 * s) //_isAndroid ? 80: 54
            height: Math.round(80 * s) //_isAndroid ? 80: 54
            Layout.preferredWidth: Math.round(80 * s) //_isAndroid ? 80: 54
            Layout.preferredHeight: Math.round(80 * s) //_isAndroid ? 80: 54
            radius: 5
            Layout.row: 2
            Layout.column: 1
            color: "transparent"
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

            Image {
                id: iconReconnect
                source: "./icons/ui/pulse_reconnect.svg"
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // PULSE side scan TVG: cycle raw (0) -> sidescan (1) -> sidescan tvg (3) -> raw
                    if (pulseRuntimeSettings.echogramCompensationFile === 0) {
                        pulseRuntimeSettings.echogramCompensationFile = 1
                    } else if (pulseRuntimeSettings.echogramCompensationFile === 1) {
                        pulseRuntimeSettings.echogramCompensationFile = 3
                    } else {
                        pulseRuntimeSettings.echogramCompensationFile = 0
                    }
                    fileformatting.text = layout.compensationLabel(pulseRuntimeSettings.echogramCompensationFile)
                    //pulseRuntimeSettings.reconnectAfterLogView = true
                }
            }

        }

        Text {
            id: fileformatting
            visible: pulseRuntimeSettings.wasKlfFileOpened && !pulseRuntimeSettings.isOpeningKlfFile && pulseSettings.isExpert
            //visible: false
            text: "()"

            font.pixelSize: Ui.fontL //settingsPopup.infoPixelsSize

            height: Math.round(80 * s) //_isAndroid ? 80: 54
            Layout.row: 2
            Layout.column: 2
            //anchors.left: fileOpenedIcon.right
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: Math.round(20 * s) //20
        }

        // --- Row 3: DEMO MODE (Stage 1). NOT expert-gated (2026-08-29): a demo has to be
        // startable by whoever is standing at the stand, not only by an expert build.
        // The rows above (file "Test format") stay expert-only. Starting/stopping is still
        // blocked while a recording is running, via the MouseArea `enabled` below.
        Text {
            visible: !pulseRuntimeSettings.isRecordingKlf
            text: pulseRuntimeSettings.isInDemoMode ? "Stop demo" : "Run a demo"

            font.pixelSize: Ui.fontL

            height: Math.round(80 * s)
            Layout.row: 3
            Layout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: Math.round(20 * s)
        }

        Rectangle {
            id: demoButton
            visible: !pulseRuntimeSettings.isRecordingKlf
            width: Math.round(80 * s)
            height: Math.round(80 * s)
            Layout.preferredWidth: Math.round(80 * s)
            Layout.preferredHeight: Math.round(80 * s)
            radius: 5
            Layout.row: 3
            Layout.column: 1
            color: "transparent"
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

            Image {
                id: iconDemo
                // xbox-x is the classic stop/abort glyph our expert users expect;
                // the folder-open glyph when idle matches the "Show a file" row.
                source: pulseRuntimeSettings.isInDemoMode ? "./icons/ui/xbox-x.svg"
                                                          : "./icons/ui/pulse_open.svg"
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                // An opened file view is fine to start a demo over — enterDemoMode
                // clears wasKlfFileOpened and core.startDemo drops the file. Only a
                // recording, or a file still mid-open, actually blocks it.
                enabled: pulseRuntimeSettings.isInDemoMode
                         || (!pulseRuntimeSettings.isRecordingKlf
                             && !core.isFileOpening)
                onClicked: {
                    if (pulseRuntimeSettings.isInDemoMode) {
                        pulseRuntimeSettings.exitDemoMode()
                    } else {
                        demoFileDialog.open()
                    }
                }
            }
        }

        Text {
            id: demoPathText
            visible: !pulseRuntimeSettings.isRecordingKlf
            text: {
                if (pulseRuntimeSettings.isInDemoMode) {
                    // Just the file being replayed. "Stop demo" to the left of the
                    // icon already says what the icon does, and the pacing lives in
                    // the Device tab (and the DEMO: log lines).
                    return settingsPopup.demoDisplayName(pulseRuntimeSettings.demoFilePath)
                }
                return "pick a .plog to replay"
            }

            font.pixelSize: Ui.fontL
            elide: Text.ElideMiddle

            height: Math.round(80 * s)
            Layout.row: 3
            Layout.column: 2
            Layout.minimumWidth: Math.round(400 * s)
            Layout.preferredWidth: Math.round(400 * s)
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: Math.round(20 * s)
        }

        // PULSE side scan TVG: shared label mapping for the compensation id
        // NOTE: declared on the GridLayout (id: layout). QML resolves
        // unqualified functions only against the current object, the file
        // root and ids — so every call site must use layout.compensationLabel().
        function compensationLabel(comp) {
            if (comp === 0) return "(raw)"
            if (comp === 1) return "(sidescan)"
            if (comp === 2) return "(tvg 2D)"
            if (comp === 3) return "(sidescan tvg)"
            return "()"
        }

        Connections {
            target: pulseRuntimeSettings
             function onEchogramCompensationFileChanged () {
                fileformatting.text = layout.compensationLabel(pulseRuntimeSettings.echogramCompensationFile)
             }
        }

        Component.onCompleted: {
            fileformatting.text = layout.compensationLabel(pulseRuntimeSettings.echogramCompensationFile)
        }

        Connections {
            target: core

            function onSendIsFileOpening() {
                if (core === null)
                    return
                let isFileOpening = core.getIsFileOpening()

                if (isFileOpening) {
                    console.log("FileOpening from recording, started")
                } else {
                    setCompenmsationTimer.start()
                }
            }
        }

        Timer {
            id: setCompenmsationTimer
            repeat: false
            interval: 1000
            onTriggered: {
                console.log("FileOpening from recording completed, enforce compensation?")
                if (pulseRuntimeSettings === null)
                    return
                // PULSE: honour the TVG expert toggles instead of forcing
                // raw/side scan — resolve returns 2D: TVG(2) or raw(0),
                // side scan: side scan TVG(3) or AGC(1). No more double-
                // toggling after opening a file.
                let comp = pulseRuntimeSettings.resolveEchogramCompensation()
                pulseRuntimeSettings.echogramCompensationFile = comp
                console.log("FileOpening from recording completed, enforce resolved compensation", comp)
            }
        }
    }

}

