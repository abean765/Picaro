import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string logText: ""
    property var dupGroups: []
    property bool dupSearchDone: false
    property bool showDeleteConfirm: false
    property bool showDeleteDone: false

    Connections {
        target: photoImporter
        function onLogMessage(message) {
            logText += message + "\n"
            logArea.cursorPosition = logArea.length
        }
    }

    // Confirmation dialog for delete
    Rectangle {
        anchors.fill: parent
        color: "#cc000000"
        visible: root.showDeleteConfirm
        z: 10

        Rectangle {
            anchors.centerIn: parent
            width: 420
            implicitHeight: confirmContent.implicitHeight + 40
            color: "#2a2a2a"
            radius: 10
            border.color: "#5a2020"
            border.width: 1

            ColumnLayout {
                id: confirmContent
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 24
                }
                spacing: 16

                Label {
                    text: "Wirklich alles löschen?"
                    color: "#ffffff"
                    font.pixelSize: 17
                    font.bold: true
                    Layout.topMargin: 8
                }

                Label {
                    text: "Datenbank und Import-Ordner werden unwiderruflich gelöscht. Die App muss danach neu gestartet werden."
                    color: "#aaaaaa"
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Layout.bottomMargin: 4

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Abbrechen"
                        onClicked: root.showDeleteConfirm = false

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
                            leftPadding: 16
                            rightPadding: 16
                        }
                    }

                    Button {
                        text: "Löschen"
                        onClicked: {
                            root.showDeleteConfirm = false
                            appSettings.deleteAllData()
                            root.showDeleteDone = true
                        }

                        background: Rectangle {
                            color: parent.hovered ? "#7a2020" : "#5a1515"
                            radius: 4
                        }
                        contentItem: Label {
                            text: parent.text
                            color: "#ffffff"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 20
                            rightPadding: 20
                        }
                    }
                }
            }
        }
    }

    // "Neustart erforderlich" dialog after deletion
    Rectangle {
        anchors.fill: parent
        color: "#cc000000"
        visible: root.showDeleteDone
        z: 11

        Rectangle {
            anchors.centerIn: parent
            width: 380
            implicitHeight: doneContent.implicitHeight + 40
            color: "#2a2a2a"
            radius: 10
            border.color: "#444444"
            border.width: 1

            ColumnLayout {
                id: doneContent
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 24
                }
                spacing: 16

                Label {
                    text: "Daten gelöscht"
                    color: "#ffffff"
                    font.pixelSize: 17
                    font.bold: true
                    Layout.topMargin: 8
                }

                Label {
                    text: "Datenbank und Import-Ordner wurden gelöscht. Picaro wird jetzt beendet."
                    color: "#aaaaaa"
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "OK"
                        onClicked: Qt.quit()

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
                            leftPadding: 24
                            rightPadding: 24
                        }
                    }
                }
            }
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

            // Duplicate finder card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: dupCardContent.implicitHeight + 32
                color: "#2a2a2a"
                radius: 8

                ColumnLayout {
                    id: dupCardContent
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Label {
                        text: "Duplikate finden"
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Label {
                        text: "Sucht nach Fotos mit identischem perceptual Hash (dHash). Zeigt Gruppen visuell ähnlicher oder identischer Bilder an."
                        color: "#999999"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: 12

                        Button {
                            text: "Duplikate suchen"
                            onClicked: {
                                dupGroups = statsProvider.findDuplicateGroups()
                                dupSearchDone = true
                            }

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
                                leftPadding: 16
                                rightPadding: 16
                            }
                        }

                        Label {
                            visible: dupGroups.length > 0
                            text: dupGroups.length + " Gruppe" + (dupGroups.length !== 1 ? "n" : "") + " gefunden"
                            color: "#888888"
                            font.pixelSize: 13
                        }

                        Label {
                            visible: dupSearchDone && dupGroups.length === 0
                            text: "Keine Duplikate gefunden"
                            color: "#22c55e"
                            font.pixelSize: 13
                        }
                    }

                    // Results list
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: dupGroups.length > 0

                        Repeater {
                            model: dupGroups

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: groupRow.implicitHeight + 20
                                color: "#1e1e1e"
                                radius: 6

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    Label {
                                        text: "Gruppe " + (index + 1) + "  ·  " + modelData.length + " Fotos"
                                        color: "#888888"
                                        font.pixelSize: 11
                                    }

                                    Row {
                                        id: groupRow
                                        spacing: 6

                                        Repeater {
                                            model: modelData

                                            delegate: Rectangle {
                                                required property var modelData
                                                width: 100
                                                height: 100
                                                color: "#2a2a2a"
                                                radius: 4
                                                clip: true

                                                Image {
                                                    anchors.fill: parent
                                                    source: "image://thumbnail/" + modelData
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Delete database + photo folder card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: deleteCardContent.implicitHeight + 32
                color: "#2a2a2a"
                radius: 8

                ColumnLayout {
                    id: deleteCardContent
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Label {
                        text: "Daten zurücksetzen"
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Label {
                        text: "Löscht die Datenbank (%1) und den Import-Ordner (%2) vollständig. Die App muss danach neu gestartet werden."
                            .arg(appSettings.databasePath)
                            .arg(appSettings.photoFolder)
                        color: "#999999"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "Datenbank und Import Ordner löschen"
                        onClicked: root.showDeleteConfirm = true

                        background: Rectangle {
                            color: parent.hovered ? "#5a2020" : "#3a1515"
                            radius: 4
                            border.color: "#7a3030"
                            border.width: 1
                        }
                        contentItem: Label {
                            text: parent.text
                            color: "#ff8888"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 16
                            rightPadding: 16
                        }
                    }
                }
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
