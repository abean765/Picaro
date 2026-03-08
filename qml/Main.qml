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

    // Navigation state
    property string currentView: "photos"

    // Photo selection state
    property qint64 selectedPhotoId: -1

    function selectPhoto(photoId) {
        selectedPhotoId = photoId
    }

    function closeDetail() {
        selectedPhotoId = -1
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Sidebar
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 200
            color: "#222222"

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 12
                spacing: 2

                // App title
                Label {
                    text: "Picaro"
                    color: "#ffffff"
                    font.pixelSize: 22
                    font.bold: true
                    Layout.leftMargin: 16
                    Layout.bottomMargin: 16
                }

                SidebarButton {
                    text: "Fotos"
                    icon: "\u25A3"
                    active: currentView === "photos"
                    onClicked: currentView = "photos"
                }

                SidebarButton {
                    text: "Übersicht"
                    icon: "\u25C9"
                    active: currentView === "overview"
                    onClicked: currentView = "overview"
                }

                SidebarButton {
                    text: "Einstellungen"
                    icon: "\u2699"
                    active: currentView === "settings"
                    onClicked: currentView = "settings"
                }

                Item { Layout.fillHeight: true }

                // Import button at bottom of sidebar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 8
                    implicitHeight: 36
                    color: importBtnArea.containsMouse ? "#3a6abf" : "#2d5aa0"
                    radius: 6

                    Label {
                        anchors.centerIn: parent
                        text: "Ordner importieren"
                        color: "#ffffff"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: importBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: folderDialog.open()
                    }
                }
            }
        }

        // Main content area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Import progress bar
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: photoImporter.running ? 32 : 0
                color: "#2d2d2d"
                visible: photoImporter.running
                clip: true

                Behavior on implicitHeight { NumberAnimation { duration: 200 } }

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

            // Toolbar (only for photos view)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: currentView === "photos" ? 44 : 0
                color: "#2d2d2d"
                visible: currentView === "photos"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Label {
                        text: photoModel.totalPhotos + " Medien"
                        color: "#aaaaaa"
                        font.pixelSize: 14
                    }

                    Item { Layout.fillWidth: true }

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
                }
            }

            // Stacked views
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: currentView === "photos" ? 0
                            : currentView === "overview" ? 1
                            : 2

                // Photos view with timeline + grid + detail
                Item {
                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        TimelineView {
                            id: timelineView
                            Layout.fillHeight: true
                            visible: photoModel.totalPhotos > 0
                            activeIndex: {
                                // Find which timeline month corresponds to current scroll position
                                if (!photoGrid.count) return -1
                                var topIdx = photoGrid.indexAt(0, photoGrid.contentY + 10)
                                if (topIdx < 0) return -1
                                // Walk backward to find nearest header
                                var data = photoModel.timelineData
                                var bestMatch = -1
                                for (var i = 0; i < data.length; ++i) {
                                    if (data[i].rowIndex <= topIdx) {
                                        bestMatch = i
                                    } else {
                                        break
                                    }
                                }
                                return bestMatch
                            }
                            onMonthClicked: function(timelineIndex, rowIndex) {
                                photoGrid.positionViewAtIndex(rowIndex, ListView.Beginning)
                            }
                        }

                        PhotoGridView {
                            id: photoGrid
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }

                        // Vertical separator
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            color: "#333333"
                            visible: detailPanel.visible
                        }

                        // Detail panel (right side)
                        DetailView {
                            id: detailPanel
                            Layout.fillHeight: true
                            Layout.preferredWidth: parent.width * 0.45
                            Layout.minimumWidth: 400
                            visible: root.selectedPhotoId > 0
                            photoId: root.selectedPhotoId
                            onClosed: root.closeDetail()
                            onNavigateNext: {
                                var nextId = photoModel.nextPhotoId(root.selectedPhotoId)
                                if (nextId > 0) root.selectedPhotoId = nextId
                            }
                            onNavigatePrevious: {
                                var prevId = photoModel.previousPhotoId(root.selectedPhotoId)
                                if (prevId > 0) root.selectedPhotoId = prevId
                            }
                        }
                    }
                }

                OverviewView {}

                SettingsView {}
            }
        }
    }

    // Folder picker dialog
    FolderDialog {
        id: folderDialog
        title: "Foto-Ordner auswählen"
        onAccepted: {
            var path = selectedFolder.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace("file:///", "")
            } else {
                path = path.replace("file://", "")
            }
            photoImporter.importDirectory(path)
        }
    }

    // Sidebar button component
    component SidebarButton: Rectangle {
        id: sidebarBtn
        property string text: ""
        property string icon: ""
        property bool active: false

        signal clicked()

        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        implicitHeight: 36
        color: active ? "#3a3a3a" : (btnArea.containsMouse ? "#2d2d2d" : "transparent")
        radius: 6

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            spacing: 10

            Label {
                text: sidebarBtn.icon
                color: sidebarBtn.active ? "#4a9eff" : "#888888"
                font.pixelSize: 16
            }

            Label {
                text: sidebarBtn.text
                color: sidebarBtn.active ? "#ffffff" : "#bbbbbb"
                font.pixelSize: 14
            }

            Item { Layout.fillWidth: true }
        }

        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sidebarBtn.clicked()
        }
    }
}
