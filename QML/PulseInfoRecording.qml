import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 1.2

Rectangle {
    id: settingsPopup
    focus: true
    width: 900
    height: 400
    anchors.centerIn: parent
    color: "white"
    radius: 8

    signal pulsePreferenceClosed()
    signal pulsePreferenceValueChanged(double newValue)

    FileDialog {
        id: newFileDialog
        title: qsTr("Please choose a file")
        folder: shortcuts.home

        nameFilters: ["Logs (*.klf *.KLF *.ubx *.UBX *.xtf *.XTF)", "Kogger log files (*.klf *.KLF)", "U-blox (*.ubx *.UBX)"]

        onAccepted: {
            pathText.text = newFileDialog.fileUrl.toString().replace("file:///", Qt.platform.os === "windows" ? "" : "/")

            var name_parts = newFileDialog.fileUrl.toString().split('.')

            core.openLogFile(pathText.text, false, false);
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
            font.pixelSize: 30

            height: 80
            GridLayout.row: 0
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
            Layout.topMargin: 20
        }

        // record
        Rectangle {
            id: recording
            Layout.preferredWidth: 80
            Layout.preferredHeight: 80
            radius: 5
            GridLayout.row: 0
            GridLayout.column: 1
            color: "transparent"
            Layout.topMargin: 20
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

            Image {
                id: iconRecording
                source: pulseRuntimeSettings.isRecordingKlf === true ? "./icons/pulse_recording_active.svg" : "./icons/pulse_recording_inactive.svg"
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    pulseRuntimeSettings.isRecordingKlf = !pulseRuntimeSettings.isRecordingKlf
                    core.loggingKlf = pulseRuntimeSettings.isRecordingKlf
                }
            }
        }

        // --- Row 2
        Text {
            text: "View a file"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 1
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.leftMargin: 20
        }

        // Open
        Rectangle {
            width: 80
            height: 80
            Layout.preferredWidth: 80
            Layout.preferredHeight: 80
            radius: 5
            GridLayout.row: 1
            GridLayout.column: 1
            color: "transparent"
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

            Image {
                id: iconOpen
                source: "./icons/pulse_open.svg"
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

        CTextField {
            id: pathText
            hoverEnabled: true
            GridLayout.row: 1
            GridLayout.column: 2
            Layout.minimumWidth: 400
            Layout.preferredWidth: 400

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
                    //console.log("log viewer: Keys.onPressed triggered by ", event.key)
                }
            }
        }

        // --- Row 3

    }

}

