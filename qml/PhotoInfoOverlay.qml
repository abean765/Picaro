import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Full-screen dimming overlay showing all metadata for a single photo.
// Set root.infoPhotoId > 0 to open, root.infoPhotoId = -1 to close.
Rectangle {
    id: overlay

    anchors.fill: parent
    color: "#b0000000"
    z: 200

    // Lazy-load metadata only when the overlay becomes visible
    property var meta: ({})

    onVisibleChanged: {
        if (visible && root.infoPhotoId > 0)
            meta = photoModel.fullMetadataForId(root.infoPhotoId)
    }

    // Close on background click
    MouseArea {
        anchors.fill: parent
        onClicked: root.infoPhotoId = -1
    }

    // ── Panel ─────────────────────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        width:  Math.min(560, parent.width  - 48)
        height: Math.min(contentCol.implicitHeight + 32, parent.height - 48)
        radius: 12
        color:  "#242424"
        clip:   true

        // Swallow clicks so they don't reach the background MouseArea
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Header ────────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 52
                color: "#1e1e1e"
                radius: 12

                // Square off the bottom corners
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: parent.radius
                    color: parent.color
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 12
                    spacing: 10

                    Label {
                        text: "i"
                        font.pixelSize: 16
                        font.bold: true
                        font.italic: true
                        color: root.accentColor
                    }
                    Label {
                        text: overlay.meta["fileName"] ?? ""
                        color: "#ffffff"
                        font.pixelSize: 15
                        font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
                    }
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: closeArea.containsMouse ? "#555555" : "transparent"
                        Label {
                            anchors.centerIn: parent
                            text: "\u2715"
                            color: "#aaaaaa"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.infoPhotoId = -1
                        }
                    }
                }
            }

            // ── Scrollable body ───────────────────────────────────────────────
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: contentCol.implicitHeight + 20
                clip: true

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: contentCol
                    width: parent.width
                    padding: 18
                    spacing: 0

                    // ── Helper components ─────────────────────────────────────

                    // Section header
                    component SectionHeader: Rectangle {
                        required property string title
                        width: contentCol.width - contentCol.padding * 2
                        height: 32
                        color: "transparent"

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            width: parent.width; height: 1
                            color: "#333333"
                        }

                        Label {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 8
                            text: title
                            color: root.accentColor
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 1.2
                        }
                    }

                    // Key-value row (hidden when value is empty)
                    component MetaRow: RowLayout {
                        required property string label
                        required property string value
                        width: contentCol.width - contentCol.padding * 2
                        height: value !== "" ? 26 : 0
                        visible: value !== ""
                        spacing: 0

                        Label {
                            text: label
                            color: "#888888"
                            font.pixelSize: 12
                            Layout.preferredWidth: 150
                        }
                        Label {
                            text: value
                            color: "#dddddd"
                            font.pixelSize: 12
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }
                    }

                    // ── File ─────────────────────────────────────────────────
                    SectionHeader { title: "DATEI" }

                    MetaRow {
                        label: "Name"
                        value: overlay.meta["fileName"] ?? ""
                    }
                    MetaRow {
                        label: "Pfad"
                        value: (overlay.meta["filePath"] ?? "").replace(overlay.meta["fileName"] ?? "", "")
                    }
                    MetaRow {
                        label: "Typ"
                        value: {
                            var t = overlay.meta["mediaType"]
                            return t === 1 ? "Video" : t === 2 ? "Live Photo" : "Foto"
                        }
                    }
                    MetaRow {
                        label: "MIME"
                        value: overlay.meta["mimeType"] ?? ""
                    }
                    MetaRow {
                        label: "Größe"
                        value: {
                            var b = overlay.meta["fileSize"] ?? 0
                            if (b <= 0) return ""
                            if (b < 1024)       return b + " B"
                            if (b < 1048576)    return (b / 1024).toFixed(1) + " KB"
                            return (b / 1048576).toFixed(2) + " MB"
                        }
                    }
                    MetaRow {
                        label: "Kategorie"
                        value: {
                            var c = overlay.meta["category"]
                            return c === 1 ? "Screenshot" : c === 2 ? "Selfie" : ""
                        }
                    }
                    MetaRow {
                        label: "Empfangen von"
                        value: overlay.meta["owner"] ?? ""
                    }

                    Item { width: 1; height: 12 }

                    // ── Dates ─────────────────────────────────────────────────
                    SectionHeader { title: "DATUM" }

                    MetaRow {
                        label: "Aufnahmedatum"
                        value: overlay.meta["dateTaken"] ?? ""
                    }
                    MetaRow {
                        label: "Änderungsdatum"
                        value: overlay.meta["dateModified"] ?? ""
                    }

                    Item { width: 1; height: 12 }

                    // ── Image / Video ─────────────────────────────────────────
                    SectionHeader { title: "BILD" }

                    MetaRow {
                        label: "Auflösung"
                        value: {
                            var w = overlay.meta["width"]  ?? 0
                            var h = overlay.meta["height"] ?? 0
                            if (w <= 0 || h <= 0) return ""
                            var mp = (w * h / 1000000).toFixed(1)
                            return w + " × " + h + "  (" + mp + " MP)"
                        }
                    }
                    MetaRow {
                        label: "Dauer"
                        value: {
                            var d = overlay.meta["duration"] ?? 0
                            if (d <= 0) return ""
                            var m = Math.floor(d / 60)
                            var s = Math.floor(d % 60)
                            return (m > 0 ? m + " min " : "") + s + " s"
                        }
                    }
                    MetaRow {
                        label: "Farbraum"
                        value: overlay.meta["colorSpace"] ?? ""
                    }
                    MetaRow {
                        label: "Ausrichtung"
                        value: overlay.meta["orientation"] ?? ""
                    }

                    Item { width: 1; height: 12 }

                    // ── Camera ────────────────────────────────────────────────
                    SectionHeader {
                        title: "KAMERA"
                        visible: (overlay.meta["cameraMake"]   ?? "") !== "" ||
                                 (overlay.meta["cameraModel"]  ?? "") !== "" ||
                                 (overlay.meta["fNumber"]      ?? "") !== ""
                    }

                    MetaRow {
                        label: "Hersteller"
                        value: overlay.meta["cameraMake"] ?? ""
                    }
                    MetaRow {
                        label: "Modell"
                        value: overlay.meta["cameraModel"] ?? ""
                    }
                    MetaRow {
                        label: "Objektiv"
                        value: overlay.meta["lensModel"] ?? ""
                    }
                    MetaRow {
                        label: "Blende"
                        value: overlay.meta["fNumber"] ?? ""
                    }
                    MetaRow {
                        label: "Belichtungszeit"
                        value: overlay.meta["exposureTime"] ?? ""
                    }
                    MetaRow {
                        label: "ISO"
                        value: overlay.meta["isoSpeed"] ?? ""
                    }
                    MetaRow {
                        label: "Brennweite"
                        value: {
                            var fl  = overlay.meta["focalLength"]   ?? ""
                            var fl35 = overlay.meta["focalLength35"] ?? ""
                            if (fl === "" && fl35 === "") return ""
                            if (fl35 !== "") return fl + "  (" + fl35 + " mm KB-äquiv.)"
                            return fl
                        }
                    }
                    MetaRow {
                        label: "Blitz"
                        value: overlay.meta["flash"] ?? ""
                    }
                    MetaRow {
                        label: "Weißabgleich"
                        value: overlay.meta["whiteBalance"] ?? ""
                    }
                    MetaRow {
                        label: "Belichtungsmodus"
                        value: overlay.meta["exposureMode"] ?? ""
                    }
                    MetaRow {
                        label: "Messmodus"
                        value: overlay.meta["meteringMode"] ?? ""
                    }
                    MetaRow {
                        label: "Software"
                        value: overlay.meta["software"] ?? ""
                    }

                    Item { width: 1; height: 12 }

                    // ── GPS ───────────────────────────────────────────────────
                    SectionHeader {
                        title: "STANDORT"
                        visible: overlay.meta["hasGeolocation"] === true
                    }

                    RowLayout {
                        width: contentCol.width - contentCol.padding * 2
                        height: overlay.meta["hasGeolocation"] === true ? 26 : 0
                        visible: overlay.meta["hasGeolocation"] === true
                        spacing: 0

                        Label {
                            text: "GPS"
                            color: "#888888"
                            font.pixelSize: 12
                            Layout.preferredWidth: 150
                        }
                        Label {
                            text: {
                                var lat = overlay.meta["latitude"]  ?? 0
                                var lon = overlay.meta["longitude"] ?? 0
                                return Math.abs(lat).toFixed(6) + "° " + (lat >= 0 ? "N" : "S") +
                                       ",  " +
                                       Math.abs(lon).toFixed(6) + "° " + (lon >= 0 ? "E" : "W")
                            }
                            color: "#dddddd"
                            font.pixelSize: 12
                            font.family: "Monospace"
                        }
                    }

                    // Maps link
                    RowLayout {
                        width: contentCol.width - contentCol.padding * 2
                        height: overlay.meta["hasGeolocation"] === true ? 24 : 0
                        visible: overlay.meta["hasGeolocation"] === true
                        spacing: 0

                        Item { Layout.preferredWidth: 150 }
                        Label {
                            text: "In OpenStreetMap öffnen \u2197"
                            color: root.accentColor
                            font.pixelSize: 12

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var lat = overlay.meta["latitude"]  ?? 0
                                    var lon = overlay.meta["longitude"] ?? 0
                                    Qt.openUrlExternally(
                                        "https://www.openstreetmap.org/?mlat=" + lat +
                                        "&mlon=" + lon + "#map=15/" + lat + "/" + lon)
                                }
                            }
                        }
                    }

                    Item { width: 1; height: 12 }

                    // ── Rating ────────────────────────────────────────────────
                    SectionHeader { title: "BEWERTUNG" }

                    RowLayout {
                        width: contentCol.width - contentCol.padding * 2
                        height: 28
                        spacing: 0

                        Label {
                            text: "Sterne"
                            color: "#888888"
                            font.pixelSize: 12
                            Layout.preferredWidth: 150
                        }
                        Row {
                            spacing: 2
                            Repeater {
                                model: 5
                                Label {
                                    required property int index
                                    text: (overlay.meta["rating"] ?? 0) > index ? "\u2764" : "\u2661"
                                    color: (overlay.meta["rating"] ?? 0) > index ? "#e53e3e" : "#555555"
                                    font.pixelSize: 16
                                }
                            }
                        }
                    }

                    Item { width: 1; height: 12 }

                    // ── Technical ─────────────────────────────────────────────
                    SectionHeader {
                        title: "TECHNISCH"
                        visible: (overlay.meta["phash"] ?? "") !== ""
                    }
                    MetaRow {
                        label: "Perceptual Hash"
                        value: overlay.meta["phash"] ?? ""
                    }

                    Item { width: 1; height: 8 }
                }
            }
        }
    }
}
