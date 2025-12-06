import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 1.2

Rectangle {
    id: settingsPopup

    // Platform helpers
    readonly property bool _isAndroid: Qt.platform.os === "android"
    // Platform related sizes
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

    focus: true
    width: _isAndroid ? 900 : 600
    height: _isAndroid ? 400 : 270
    anchors.centerIn: parent
    color: "white"
    radius: 8

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
        rowSpacing: 20
        columnSpacing: 20
        columns: 3

        // --- Row 1
        Text {
            text: pulseRuntimeSettings.isRecordingKlf === true ? "Recording..." : "Record a file"
            font.pixelSize: settingsPopup.infoPixelsSize

            height: _isAndroid ? 80: 54
            GridLayout.row: 0
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
            Layout.topMargin: 20
        }

        // record
        Rectangle {
            id: recording
            Layout.preferredWidth: _isAndroid ? 80: 54
            Layout.preferredHeight: _isAndroid ? 80: 54
            radius: 5
            GridLayout.row: 0
            GridLayout.column: 1
            color: "transparent"
            Layout.topMargin: 20
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

            font.pixelSize: settingsPopup.infoPixelsSize

            height: _isAndroid ? 80: 54
            GridLayout.row: 1
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
        }

        // view a file statement
        Rectangle {
            visible: !pulseRuntimeSettings.isRecordingKlf
            width: _isAndroid ? 80: 54
            height: _isAndroid ? 80: 54
            Layout.preferredWidth: _isAndroid ? 80: 54
            Layout.preferredHeight: _isAndroid ? 80: 54
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
            Layout.leftMargin: 20
            Layout.minimumWidth: _isAndroid ? 400 : 270
            Layout.preferredWidth: Layout.minimumWidth

            RowLayout {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: qsTr("Wait - opening file ...")
                    font.pixelSize: settingsPopup.infoPixelsSize
                    height: _isAndroid ? 80: 54
                    Layout.leftMargin: 20
                }

                Image {
                    id: iconToWait
                    source: "./icons/ui/pulse_waiting.svg"
                    Layout.preferredWidth: _isAndroid ? 54 : 42
                    Layout.preferredHeight: _isAndroid ? 54 : 42
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
            Layout.minimumWidth: _isAndroid ? 400: 270
            Layout.preferredWidth: _isAndroid ? 400: 270

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
            //visible: pulseRuntimeSettings.wasKlfFileOpened
            visible: false
            text: "Reconnect"

            font.pixelSize: settingsPopup.infoPixelsSize

            height: _isAndroid ? 80: 54
            GridLayout.row: 2
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
        }

        Rectangle {
            //visible: pulseRuntimeSettings.wasKlfFileOpened
            visible: false
            width: _isAndroid ? 80: 54
            height: _isAndroid ? 80: 54
            Layout.preferredWidth: _isAndroid ? 80: 54
            Layout.preferredHeight: _isAndroid ? 80: 54
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
                    pulseRuntimeSettings.reconnectAfterLogView = true
                }
            }
        }

    }

}

