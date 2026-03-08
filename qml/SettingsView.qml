import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: settingsView

    ScrollView {
        anchors.fill: parent
        anchors.margins: 32
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 24

            // Title
            Label {
                text: "Einstellungen"
                color: "#ffffff"
                font.pixelSize: 28
                font.bold: true
            }

            // Database section
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: dbSection.implicitHeight + 32
                color: "#2a2a2a"
                radius: 8

                ColumnLayout {
                    id: dbSection
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Label {
                        text: "Datenbank"
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Label {
                        text: "Pfad zur SQLite-Datenbank. Hier werden alle Metadaten und Thumbnails gespeichert."
                        color: "#999999"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            color: "#1e1e1e"
                            border.color: "#444444"
                            border.width: 1
                            radius: 4

                            Label {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                text: appSettings.databasePath
                                color: "#cccccc"
                                font.pixelSize: 13
                                elide: Text.ElideMiddle
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Button {
                            text: "Ändern..."
                            onClicked: dbFileDialog.open()

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
                                leftPadding: 12
                                rightPadding: 12
                            }
                        }

                        Button {
                            text: "Standard"
                            onClicked: appSettings.resetDatabasePath()

                            background: Rectangle {
                                color: parent.hovered ? "#4a4a4a" : "#333333"
                                radius: 4
                            }
                            contentItem: Label {
                                text: parent.text
                                color: "#aaaaaa"
                                font.pixelSize: 13
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 12
                                rightPadding: 12
                            }
                        }
                    }

                    Label {
                        text: "Hinweis: Nach dem Ändern des Datenbankpfads muss die App neu gestartet werden."
                        color: "#ffaa00"
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            // Maintenance section
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: maintSection.implicitHeight + 32
                color: "#2a2a2a"
                radius: 8

                ColumnLayout {
                    id: maintSection
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Label {
                        text: "Wartung"
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Label {
                        text: "Video-Thumbnails aus dem ersten Frame des Videos neu generieren. Nützlich wenn Videos zuvor nur einen grauen Platzhalter hatten."
                        color: "#999999"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: 12

                        Button {
                            text: photoImporter.running
                                ? "Wird generiert... (%1/%2)".arg(photoImporter.progress).arg(photoImporter.totalFiles)
                                : "Video Thumbnails neu generieren"
                            enabled: !photoImporter.running
                            onClicked: photoImporter.regenerateVideoThumbnails()

                            background: Rectangle {
                                color: parent.enabled
                                    ? (parent.hovered ? "#4a4a4a" : "#3a3a3a")
                                    : "#2a2a2a"
                                radius: 4
                            }
                            contentItem: Label {
                                text: parent.text
                                color: parent.enabled ? "#ffffff" : "#666666"
                                font.pixelSize: 13
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 16
                                rightPadding: 16
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    FileDialog {
        id: dbFileDialog
        title: "Datenbank-Datei auswählen"
        nameFilters: ["SQLite Datenbank (*.db)", "Alle Dateien (*)"]
        onAccepted: {
            var path = selectedFile.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace("file:///", "")
            } else {
                path = path.replace("file://", "")
            }
            appSettings.databasePath = path
        }
    }
}
