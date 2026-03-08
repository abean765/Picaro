import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

ApplicationWindow {
    id: root
    width: 1400
    height: 900
    visible: true
    title: "Picaro"
    color: "#1a1a1a"

    // Properties exposed from C++
    // photoModel: PhotoModel instance
    // photoImporter: PhotoImporter instance

    header: ToolBar {
        background: Rectangle { color: "#2d2d2d" }
        height: 48

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            Label {
                text: "Picaro"
                color: "#ffffff"
                font.pixelSize: 20
                font.bold: true
            }

            Label {
                text: photoModel.totalPhotos + " Fotos"
                color: "#aaaaaa"
                font.pixelSize: 14
            }

            Item { Layout.fillWidth: true }

            // Zoom slider for grid density
            Label {
                text: "Größe"
                color: "#aaaaaa"
                font.pixelSize: 12
            }

            Slider {
                id: zoomSlider
                from: 3
                to: 12
                value: 5
                stepSize: 1
                implicitWidth: 120

                onValueChanged: {
                    photoModel.photosPerRow = Math.round(value)
                }
            }

            Button {
                text: "Ordner importieren"
                onClicked: folderDialog.open()

                background: Rectangle {
                    color: parent.hovered ? "#4a4a4a" : "#3a3a3a"
                    radius: 4
                }

                contentItem: Label {
                    text: parent.text
                    color: "#ffffff"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // Import progress bar
    Rectangle {
        id: progressBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: photoImporter.running ? 32 : 0
        color: "#2d2d2d"
        visible: height > 0

        Behavior on height { NumberAnimation { duration: 200 } }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: photoImporter.totalFiles > 0
                   ? parent.width * (photoImporter.progress / photoImporter.totalFiles)
                   : 0
            color: "#4a9eff"

            Behavior on width { NumberAnimation { duration: 100 } }
        }

        Label {
            anchors.centerIn: parent
            text: "Importiere... " + photoImporter.progress + " / " + photoImporter.totalFiles
            color: "#ffffff"
            font.pixelSize: 12
        }
    }

    // Main content
    PhotoGridView {
        anchors.top: progressBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        model: photoModel
    }

    // Folder picker dialog
    FolderDialog {
        id: folderDialog
        title: "Foto-Ordner auswählen"
        onAccepted: {
            photoImporter.importDirectory(selectedFolder.toString().replace("file://", ""))
        }
    }

    // Model reload is handled in C++ via signal connection
}
