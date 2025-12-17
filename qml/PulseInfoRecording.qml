import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 1.2
import Echo.UI 1.0

Rectangle {
    id: settingsPopup

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    readonly property real platformScale: _isAndroid ? 0.9 : 0.75
    readonly property real s: Ui.scale * platformScale
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
    readonly property int baseHeight: 400
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

    FileDialog {
        id: newFileDialog
        title: qsTr("Please choose a file")
        folder: shortcuts.home

        nameFilters: ["Logs (*.plog *.PLOG *.ubx *.UBX *.xtf *.XTF)", "Kogger log files (*.plog *.PLOG)", "U-blox (*.ubx *.UBX)"]

        onAccepted: {
            pathText.text = newFileDialog.fileUrl.toString().replace("file:///", Qt.platform.os === "windows" ? "" : "/")

            var name_parts = newFileDialog.fileUrl.toString().split('.')

            core.openLogFile(pathText.text, false, false);
            //TODO: Make it async
            //core.openLogFileAsync(pathText.text, false, false)
            pulseRuntimeSettings.klfFilePath = pathText.text
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
            GridLayout.row: 0
            GridLayout.column: 0
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
            GridLayout.row: 0
            GridLayout.column: 1
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
                enabled: !pulseRuntimeSettings.wasKlfFileOpened
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
            GridLayout.row: 1
            GridLayout.column: 0
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
            GridLayout.row: 1
            GridLayout.column: 1
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
            GridLayout.row: 1
            GridLayout.column: 2
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
            GridLayout.row: 1
            GridLayout.column: 2
            Layout.minimumWidth: Math.round(400 * s) //_isAndroid ? 400: 270
            Layout.preferredWidth: Math.round(400 * s) //_isAndroid ? 400: 270

            text: pulseRuntimeSettings.klfFilePath
            placeholderText: qsTr("Enter path")
            inputMethodHints: Qt.ImhActionDone

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
            GridLayout.row: 2
            GridLayout.column: 0
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
            GridLayout.row: 2
            GridLayout.column: 1
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
                    if (pulseRuntimeSettings.echogramCompensationFile === 0) {
                        pulseRuntimeSettings.echogramCompensationFile = 1
                        fileformatting.text = "(sidescan)"
                    } else {
                        pulseRuntimeSettings.echogramCompensationFile = 0
                        fileformatting.text = "(raw)"
                    }
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
            GridLayout.row: 2
            GridLayout.column: 0
            anchors.left: fileOpenedIcon.right
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: Math.round(20 * s) //20
        }

        Connections {
            target: pulseRuntimeSettings
             function onEchogramCompensationFileChanged () {
                if (pulseRuntimeSettings.echogramCompensationFile === 0) {
                    fileformatting.text = "(raw)"
                } else {
                    fileformatting.text = "(sidescan)"
                }
             }
        }

        Component.onCompleted: {
            if (pulseRuntimeSettings.echogramCompensationFile === 0) {
                fileformatting.text = "(raw)"
            } else {
                fileformatting.text = "(sidescan)"
            }
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
                if (pulseRuntimeSettings.is2DTransducer) {
                    pulseRuntimeSettings.echogramCompensationFile = 0
                    console.log("FileOpening from recording completed, enforce RAW")
                } else {
                    pulseRuntimeSettings.echogramCompensationFile = 1
                    console.log("FileOpening from recording completed, enforce SIDE SCAN")
                }
            }
        }
    }

}

