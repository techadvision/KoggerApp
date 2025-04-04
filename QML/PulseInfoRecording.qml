import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 1.2

Rectangle {
    id: settingsPopup
    //modal: true
    focus: true
    width: 900
    height: 600
    anchors.centerIn: parent
    color: "white"
    radius: 8

    signal pulsePreferenceClosed()
    signal pulsePreferenceValueChanged(double newValue)


    GridLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 10
        rowSpacing: 20
        columnSpacing: 10
        columns: 3
        rows: 5

        // --- Row 1: Auto Level - Step
        Text {
            text: "Record a KLF file"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 0
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        }

        Button {
            id: recording
            checkable: true

            // Force the size.
            width: 60
            height: 60
            implicitWidth: 60
            implicitHeight: 60

            GridLayout.row: 0
            GridLayout.column: 1
            // If your style uses padding, setting it to 0 helps.
            padding: 0

            // Override the background to avoid the default styling interfering.
            background: Rectangle {
                 anchors.fill: parent
                 color: "transparent"
            }

            // Use contentItem to show your icon.
            contentItem: Image {
                 // Prevent this Image from intercepting mouse events.
                 enabled: false
                 source: recording.checked ? "./icons/pulse_recording_active.svg" : "./icons/pulse_recording_inactive.svg"
                 anchors.fill: parent
                 fillMode: Image.PreserveAspectCrop
            }

            onCheckedChanged: {
                 console.log("TAV: Recording? ", recording.checked)
                 pulseRuntimeSettings.isRecordingKlf = recording.checked
                 core.loggingKlf = recording.checked
            }

            Component.onCompleted: {
                 recording.checked = pulseRuntimeSettings.isRecordingKlf
                 core.loggingKlf = recording.checked
            }
            Connections {
                target: pulseRuntimeSettings
                function onIsRecordingKlfChanged () {
                    recording.checked = pulseRuntimeSettings.isRecordingKlf
                }
            }
        }

        // --- Row 2: Auto Level - Depth below last known
        Text {
            text: "View a KLF file"
            font.pixelSize: 30

            height: 80
            GridLayout.row: 1
            GridLayout.column: 0
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        }

        CTextField {
            id: pathText
            hoverEnabled: true
            Layout.fillWidth: true
            GridLayout.row: 1
            GridLayout.column: 1

            text: core.filePath
            placeholderText: qsTr("Enter path")

            Keys.onPressed: {
                if (event.key === 16777220 || event.key === Qt.Key_Enter) {
                    pulseRuntimeSettings.klfFilePath = pathText.text
                    core.openLogFile(pathText.text, false, false);
                }
            }
            Component.onCompleted: pulseRuntimeSettings.klfFilePath = core.filePath

        }

        CheckButton {
            icon.source: "./icons/file.svg"
            checkable: false
            GridLayout.row: 1
            GridLayout.column: 2
            backColor: theme.controlSolidBackColor
            borderWidth: 0
            implicitWidth: theme.controlHeight

            onClicked: {
                newFileDialog.open()
            }

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
        }




    }
}
