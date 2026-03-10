import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// Import dialog overlay – directory, owner, tag selection
Rectangle {
    id: importDlg
    anchors.fill: parent
    color: "#cc000000"
    visible: false
    z: 200

    property var selectedTagIds: []

    function open() {
        dirLabel.text = appSettings.importDirectory
        ownerInput.text = appSettings.importOwner
        selectedTagIds = []
        visible = true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: importDlg.visible = false
    }

    FolderDialog {
        id: importFolderDialog
        title: "Import-Verzeichnis auswählen"
        onAccepted: {
            var path = selectedFolder.toString()
            if (Qt.platform.os === "windows")
                path = path.replace("file:///", "")
            else
                path = path.replace("file://", "")
            appSettings.importDirectory = path
            dirLabel.text = path
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(540, parent.width - 64)
        height: Math.min(contentCol.implicitHeight + 48, parent.height - 64)
        color: "#2a2a2a"
        radius: 12
        border.color: "#444444"
        border.width: 1
        clip: true

        MouseArea { anchors.fill: parent }

        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth

            ColumnLayout {
                id: contentCol
                width: parent.width
                spacing: 20

                Item { height: 4 }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 16

                    Label {
                        text: "Medien importieren"
                        color: "#ffffff"
                        font.pixelSize: 20
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Label {
                        text: "\u2715"
                        color: "#888888"
                        font.pixelSize: 16
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: importDlg.visible = false
                        }
                    }
                }

                // Directory
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    spacing: 6

                    Label { text: "Verzeichnis"; color: "#aaaaaa"; font.pixelSize: 13 }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 34
                            color: "#1e1e1e"
                            radius: 4
                            border.color: "#555555"
                            border.width: 1

                            Label {
                                id: dirLabel
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                color: text !== "" ? "#cccccc" : "#555555"
                                font.pixelSize: 12
                                elide: Text.ElideLeft
                                clip: true
                            }
                        }

                        Rectangle {
                            implicitWidth: chooseLbl.implicitWidth + 20
                            implicitHeight: 34
                            radius: 4
                            color: chooseArea.containsMouse ? "#555555" : "#3a3a3a"

                            Label {
                                id: chooseLbl
                                anchors.centerIn: parent
                                text: "Auswählen"
                                color: "#ffffff"
                                font.pixelSize: 13
                            }
                            MouseArea {
                                id: chooseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: importFolderDialog.open()
                            }
                        }
                    }
                }

                // Owner
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    spacing: 6

                    Label { text: "Eigentümer"; color: "#aaaaaa"; font.pixelSize: 13 }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 34
                        color: "#1e1e1e"
                        radius: 4
                        border.color: ownerInput.activeFocus ? root.accentColor : "#555555"
                        border.width: 1

                        TextInput {
                            id: ownerInput
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            color: "#ffffff"
                            font.pixelSize: 13
                            clip: true
                            Keys.onReturnPressed: importDlg.startImport()
                        }
                    }
                }

                // Tags
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    spacing: 6
                    visible: tagModel.count > 0

                    Label { text: "Tags beim Import zuweisen"; color: "#aaaaaa"; font.pixelSize: 13 }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: tagModel

                            Rectangle {
                                required property var tagId
                                required property string name
                                required property string tagColor
                                required property string tagIcon

                                readonly property bool selected:
                                    importDlg.selectedTagIds.indexOf(tagId) >= 0

                                implicitWidth: tagChipRow.implicitWidth + 20
                                implicitHeight: 30
                                radius: 15
                                color: selected ? tagColor : "#3a3a3a"
                                border.color: selected ? Qt.lighter(tagColor, 1.4) : "transparent"
                                border.width: selected ? 2 : 0

                                RowLayout {
                                    id: tagChipRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Label {
                                        text: tagIcon
                                        color: "#ffffff"
                                        font.pixelSize: 11
                                        visible: text !== ""
                                    }
                                    Label {
                                        text: name
                                        color: "#ffffff"
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var ids = importDlg.selectedTagIds.slice()
                                        var idx = ids.indexOf(tagId)
                                        if (idx >= 0)
                                            ids.splice(idx, 1)
                                        else
                                            ids.push(tagId)
                                        importDlg.selectedTagIds = ids
                                    }
                                }
                            }
                        }
                    }
                }

                // Buttons
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.bottomMargin: 4
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: cancelLbl.implicitWidth + 24
                        implicitHeight: 36
                        radius: 6
                        color: cancelArea2.containsMouse ? "#555555" : "#3a3a3a"

                        Label {
                            id: cancelLbl
                            anchors.centerIn: parent
                            text: "Abbrechen"
                            color: "#aaaaaa"
                            font.pixelSize: 13
                        }
                        MouseArea {
                            id: cancelArea2
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: importDlg.visible = false
                        }
                    }

                    Rectangle {
                        implicitWidth: importLbl.implicitWidth + 24
                        implicitHeight: 36
                        radius: 6
                        color: dirLabel.text !== ""
                            ? (startArea.containsMouse
                                ? Qt.darker(root.accentColor, 1.2)
                                : root.accentColor)
                            : "#555555"

                        Label {
                            id: importLbl
                            anchors.centerIn: parent
                            text: "Importieren"
                            color: "#ffffff"
                            font.pixelSize: 13
                            font.bold: true
                        }
                        MouseArea {
                            id: startArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: dirLabel.text !== ""
                                ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: importDlg.startImport()
                        }
                    }
                }

                Item { height: 4 }
            }
        }
    }

    function startImport() {
        if (dirLabel.text === "") return
        appSettings.importOwner = ownerInput.text
        photoImporter.importDirectory(dirLabel.text, ownerInput.text, importDlg.selectedTagIds)
        importDlg.visible = false
    }
}
