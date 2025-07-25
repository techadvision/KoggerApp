import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: container
    width: 440
    height: 350
    radius: 10
    color: backgroundColor   // background color configurable from outside

    // Customizable properties
    property color backgroundColor: "white"
    property string title: ""    // title text
    property color titleColor: "black"          // title color
    property string description: ""
    property url illustrationSource: ""       // background illustration image
    property url sounderImageSource: ""         // additional image (e.g. sounder illustration)
    property var versions: []
    property string version: ""
    property bool isSelected: false

    // Signal emitted when the object is clicked
    signal selected(string title, string version)

    Connections {
        target: pulseRuntimeSettings
        function onUserManualSetNameChanged () {
            isSelected = true
        }
    }

    // A low-opacity illustration image that fills the background.
    Image {
        id: illustrationImage
        anchors.fill: parent
        anchors.bottom: parent.bottom
        source: illustrationSource
        fillMode: Image.PreserveAspectFit
        //opacity: 0.2
    }

    // Title text in the top-left area.
    Text {
        id: titleText
        visible: !isSelected
        text: "My device is a ..."
        color: "white"
        font.pointSize: 20

        // Make the Text as wide as its parent (or inset by margins), so AlignHCenter takes effect
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 10
        anchors.rightMargin: 10

        // Stick to the top with a margin
        anchors.top: parent.top
        anchors.topMargin: 20

        // Center each line horizontally within this width
        horizontalAlignment: Text.AlignHCenter

        // Ensure multi‐line support (no automatic eliding)
        wrapMode: Text.NoWrap
    }
    /*
    Text {
        id: titleText
        visible: !isSelected
        text: "My device is:\n" + container.title
        color: "white"
        font.pointSize: 20
        anchors.top: parent.top
        anchors.topMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: 10
    }
    */

    // Version selection:
    // If more than one version is provided, use a ComboBox; otherwise, just display the version.
    Item {
        id: versionContainer
        anchors.top: titleText.bottom
        anchors.left: titleText.left
        anchors.topMargin: 5

        // ComboBox when multiple versions are available
        ComboBox {
            id: versionCombo
            visible: container.versions.length > 1
            model: container.versions
            currentIndex: container.versions.indexOf(container.version)
            onCurrentIndexChanged: {
                container.version = container.versions[currentIndex];
            }
        }

        // Fallback to simple text display when only one (or no) version is provided
        Text {
            id: versionText
            visible: container.versions.length <= 1
            text: container.version
            color: "grey"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Description text placed below the version information.
    Text {
        id: descriptionText
        text: container.description
        wrapMode: Text.Wrap
        anchors.top: versionContainer.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 10
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        visible: false
    }

    // An image (e.g. a sounder illustration) in the bottom right corner.
    Image {
        id: sounderImage
        source: sounderImageSource
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.rightMargin: 10
        width: 100
        height: 100
        fillMode: Image.PreserveAspectFit
        visible: false
    }

    // A MouseArea covering the whole rectangle to detect clicks.
    MouseArea {
        anchors.fill: parent
        onClicked: {
            // Emit a signal with the title and version. You can expand on this as needed.
            container.selected(title, version);
        }
    }

    // On component completion, if a versions array is provided but no version is set,
    // default to the first element.
    Component.onCompleted: {
        if (versions.length > 0 && version === "")
            version = versions[0];
    }
}
