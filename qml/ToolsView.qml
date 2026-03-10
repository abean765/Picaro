import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string logText: ""

    Connections {
        target: photoImporter
        function onLogMessage(message) {
            logText += message + "\n"
            logArea.cursorPosition = logArea.length
        }
    }

    ScrollView {
        id: mainScroll
        anchors.fill: parent
        anchors.margins: 24
        contentWidth: availableWidth

        ColumnLayout {
            width: mainScroll.availableWidth
            spacing: 24

            // Header
            Label {
                text: "Tools"
                color: "#ffffff"
                font.pixelSize: 24
                font.bold: true
            }

            // Metadata re-read card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: cardContent.implicitHeight + 32
                color: "#2a2a2a"
                radius: 8

                ColumnLayout {
                    id: cardContent
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Label {
                        text: "Metadaten neu einlesen"
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Label {
                        text: "Liest EXIF-Daten, Aufnahmedatum, GPS und Bildgröße aus den originalen Dateien neu ein und aktualisiert die Datenbank. Nützlich wenn beim initialen Import Metadaten nicht erkannt wurden."
                        color: "#999999"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: 12

                        Button {
                            id: rereadBtn
                            text: photoImporter.running
                                ? "Lese Metadaten... (%1 / %2)".arg(photoImporter.progress).arg(photoImporter.totalFiles)
                                : "Metadaten neu einlesen"
                            enabled: !photoImporter.running
                            onClicked: {
                                root.logText = ""
                                photoImporter.rereadMetadata()
                            }

                            background: Rectangle {
                                color: parent.enabled
                                    ? (parent.hovered ? "#4a4a4a" : "#3a3a3a")
                                    : "#252525"
                                radius: 4
                            }
                            contentItem: Label {
                                text: parent.text
                                color: parent.enabled ? "#ffffff" : "#555555"
                                font.pixelSize: 13
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 16
                                rightPadding: 16
                            }
                        }

                        Button {
                            text: "Log leeren"
                            visible: root.logText.length > 0 && !photoImporter.running
                            onClicked: root.logText = ""

                            background: Rectangle {
                                color: parent.hovered ? "#3a3a3a" : "transparent"
                                radius: 4
                                border.color: "#444444"
                                border.width: 1
                            }
                            contentItem: Label {
                                text: parent.text
                                color: "#888888"
                                font.pixelSize: 13
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 12
                                rightPadding: 12
                            }
                        }
                    }

                    // Progress bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 4
                        radius: 2
                        color: "#333333"
                        visible: photoImporter.running

                        Rectangle {
                            width: photoImporter.totalFiles > 0
                                ? parent.width * (photoImporter.progress / photoImporter.totalFiles)
                                : 0
                            height: parent.height
                            radius: parent.radius
                            color: "#5588ff"
                            Behavior on width { NumberAnimation { duration: 80 } }
                        }
                    }

                    // Log output
                    Rectangle {
                        Layout.fillWidth: true
                        height: 320
                        color: "#1a1a1a"
                        radius: 6
                        border.color: "#333333"
                        border.width: 1
                        visible: root.logText.length > 0 || photoImporter.running
                        clip: true

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 8

                            TextArea {
                                id: logArea
                                text: root.logText
                                readOnly: true
                                wrapMode: TextArea.NoWrap
                                color: "#cccccc"
                                font.family: "Monospace"
                                font.pixelSize: 12
                                background: null
                                selectByMouse: true
                            }
                        }
                    }
                }
            }
        }
    }
}
