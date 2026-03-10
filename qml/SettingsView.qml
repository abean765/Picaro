import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia

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

            // Appearance section
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: colorSection.implicitHeight + 32
                color: "#2a2a2a"
                radius: 8

                ColumnLayout {
                    id: colorSection
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Label {
                        text: "Aussehen"
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Label {
                        text: "Akzentfarbe für Buttons, Auswahl-Rahmen und aktive Elemente."
                        color: "#999999"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // Color preset grid
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                "#4a9eff", "#3b82f6", "#6366f1", "#8b5cf6",
                                "#a855f7", "#d946ef", "#ec4899", "#f43f5e",
                                "#ef4444", "#f97316", "#eab308", "#22c55e",
                                "#14b8a6", "#06b6d4", "#0ea5e9", "#64748b"
                            ]

                            Rectangle {
                                required property string modelData
                                required property int index
                                width: 36
                                height: 36
                                radius: 18
                                color: modelData
                                border.color: Qt.colorEqual(appSettings.accentColor, modelData) ? "#ffffff" : "transparent"
                                border.width: 3

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: "#ffffff"
                                    visible: Qt.colorEqual(appSettings.accentColor, parent.modelData)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: appSettings.accentColor = parent.modelData
                                }
                            }
                        }
                    }

                    // Custom color input
                    RowLayout {
                        spacing: 8

                        Label {
                            text: "Eigene Farbe:"
                            color: "#cccccc"
                            font.pixelSize: 13
                        }

                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: appSettings.accentColor

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: colorDialog.open()
                            }
                        }

                        Rectangle {
                            implicitWidth: 90
                            implicitHeight: 28
                            color: "#1e1e1e"
                            border.color: "#444444"
                            border.width: 1
                            radius: 4

                            TextInput {
                                id: hexInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: Text.AlignVCenter
                                color: "#cccccc"
                                font.pixelSize: 13
                                text: appSettings.accentColor.toString().toUpperCase()
                                maximumLength: 7
                                validator: RegularExpressionValidator { regularExpression: /^#[0-9A-Fa-f]{0,6}$/ }
                                onAccepted: {
                                    if (text.length === 7) {
                                        appSettings.accentColor = text
                                    }
                                }
                            }
                        }

                        Button {
                            text: "Standard"
                            onClicked: appSettings.resetAccentColor()

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
                }
            }

            // Fotoordner section
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: photoFolderSection.implicitHeight + 32
                color: "#2a2a2a"
                radius: 8

                ColumnLayout {
                    id: photoFolderSection
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Label {
                        text: "Fotoordner"
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Label {
                        text: "Ordner, in dem Fotos dauerhaft gespeichert werden. Beim Empfangen über Local Send werden Fotos hier abgelegt."
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
                                text: appSettings.photoFolder
                                color: "#cccccc"
                                font.pixelSize: 13
                                elide: Text.ElideMiddle
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Button {
                            text: "Ändern..."
                            onClicked: photoFolderDialog.open()

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
                            onClicked: appSettings.resetPhotoFolder()

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
                }
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
                        text: "Speicherort der SQLite-Datenbank (picaro.db). Hier werden alle Metadaten und Thumbnails gespeichert."
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

            // Local Send section
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: localSendSection.implicitHeight + 32
                color: "#2a2a2a"
                radius: 8

                ColumnLayout {
                    id: localSendSection
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Label {
                        text: "Local Send"
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Label {
                        text: "Fotos und Videos über das lokale Netzwerk an andere Picaro-Instanzen senden und empfangen."
                        color: "#999999"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // Computer name
                    Label {
                        text: "Computername"
                        color: "#cccccc"
                        font.pixelSize: 13
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

                            TextInput {
                                id: computerNameInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: Text.AlignVCenter
                                color: "#cccccc"
                                font.pixelSize: 13
                                text: appSettings.computerName
                                onAccepted: appSettings.computerName = text
                                onEditingFinished: appSettings.computerName = text
                            }
                        }

                        Button {
                            text: "Standard"
                            onClicked: {
                                appSettings.resetComputerName()
                                computerNameInput.text = appSettings.computerName
                            }

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

                    // Network visibility toggle
                    RowLayout {
                        spacing: 12

                        Switch {
                            id: visibilitySwitch
                            checked: appSettings.networkVisible
                            onCheckedChanged: {
                                appSettings.networkVisible = checked
                                if (checked) {
                                    networkManager.startDiscovery(appSettings.computerName)
                                } else {
                                    networkManager.stopDiscovery()
                                }
                            }
                        }

                        Label {
                            text: visibilitySwitch.checked
                                ? "Im lokalen Netzwerk sichtbar"
                                : "Nicht sichtbar im Netzwerk"
                            color: visibilitySwitch.checked ? "#22c55e" : "#999999"
                            font.pixelSize: 13
                        }
                    }

                    // Status info
                    RowLayout {
                        spacing: 8
                        visible: networkManager.discoveryActive

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: "#22c55e"
                        }

                        Label {
                            text: {
                                var count = peerModel.count
                                if (count === 0)
                                    return "Aktiv \u2013 suche nach Geräten..."
                                return "Aktiv \u2013 " + count + " Gerät" + (count !== 1 ? "e" : "") + " gefunden"
                            }
                            color: "#22c55e"
                            font.pixelSize: 12
                        }
                    }
                }
            }

            // Audio section
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: audioSection.implicitHeight + 32
                color: "#2a2a2a"
                radius: 8

                ColumnLayout {
                    id: audioSection
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Label {
                        text: "Audio"
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Label {
                        text: "Prüfe ob die Audio-Ausgabe für die Videowiedergabe funktioniert."
                        color: "#999999"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    AudioOutput { id: testAudio }
                    MediaPlayer {
                        id: testPlayer
                        audioOutput: testAudio
                    }

                    RowLayout {
                        spacing: 12

                        Button {
                            text: testPlayer.playbackState === MediaPlayer.PlayingState
                                ? "Wird abgespielt..."
                                : "Audio testen"
                            enabled: testPlayer.playbackState !== MediaPlayer.PlayingState
                            onClicked: {
                                var path = appSettings.generateTestTone();
                                if (path !== "") {
                                    testPlayer.source = (Qt.platform.os === "windows" ? "file:///" : "file://") + path;
                                    testPlayer.play();
                                }
                            }

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

            // GPU HEIC Import section
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: gpuSection.implicitHeight + 32
                color: "#2a2a2a"
                radius: 8

                ColumnLayout {
                    id: gpuSection
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Label {
                        text: "GPU HEIC Import"
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Label {
                        text: "Prüfe ob GPU-beschleunigtes Dekodieren von HEIC/HEIF-Bildern " +
                              "(via NVDEC, VAAPI oder VideoToolbox) auf diesem System verfügbar ist."
                        color: "#999999"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: 12

                        Button {
                            text: "Test HEIC GPU Import"
                            onClicked: {
                                var result = appSettings.testGpuHeicDecode()
                                gpuResultLabel.visible = true
                                if (!result.compiled) {
                                    gpuResultIcon.text = "\u26A0"
                                    gpuResultIcon.color = "#ffaa00"
                                    gpuResultText.text = "Nicht kompiliert: FFmpeg HW-Beschleunigung " +
                                                         "wurde beim Build nicht aktiviert (HAVE_FFMPEG_HW=OFF)."
                                    gpuResultText.color = "#ffaa00"
                                } else if (result.available) {
                                    gpuResultIcon.text = "\u2713"
                                    gpuResultIcon.color = "#22c55e"
                                    gpuResultText.text = "GPU HEIC-Dekodierung ist verfügbar und aktiv."
                                    gpuResultText.color = "#22c55e"
                                } else {
                                    gpuResultIcon.text = "\u2717"
                                    gpuResultIcon.color = "#ef4444"
                                    gpuResultText.text = "Keine GPU-Beschleunigung gefunden. " +
                                                         "HEIC-Import verwendet Software-Dekodierung (libheif)."
                                    gpuResultText.color = "#ef4444"
                                }
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
                    }

                    RowLayout {
                        id: gpuResultLabel
                        visible: false
                        spacing: 8

                        Label {
                            id: gpuResultIcon
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Label {
                            id: gpuResultText
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    ColorDialog {
        id: colorDialog
        title: "Akzentfarbe wählen"
        selectedColor: appSettings.accentColor
        onAccepted: appSettings.accentColor = selectedColor
    }

    FolderDialog {
        id: photoFolderDialog
        title: "Fotoordner wählen"
        onAccepted: {
            var path = selectedFolder.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace("file:///", "")
            } else {
                path = path.replace("file://", "")
            }
            appSettings.photoFolder = path
        }
    }

    FolderDialog {
        id: dbFileDialog
        title: "Speicherort für Datenbank wählen"
        onAccepted: {
            var path = selectedFolder.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace("file:///", "")
            } else {
                path = path.replace("file://", "")
            }
            appSettings.databasePath = path + "/picaro.db"
        }
    }
}
