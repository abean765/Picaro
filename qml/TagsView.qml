import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: tagsView

    // Editing state
    property int editingTagId: -1
    property string editName: ""
    property string editColor: "#888888"
    property string editIcon: ""

    readonly property var presetColors: [
        "#e53e3e", "#dd6b20", "#d69e2e", "#38a169",
        "#319795", "#3182ce", "#5a67d8", "#805ad5",
        "#d53f8c", "#718096", "#e2e8f0", "#f56565",
        "#ed8936", "#ecc94b", "#48bb78", "#4fd1c5"
    ]

    readonly property var presetIcons: [
        "\u2764", "\u2B50", "\u2302", "\u25A3",
        "\u2600", "\u2698", "\u2665", "\u2663",
        "\u266A", "\u266B", "\u25A0", "\u2726",
        "\u25CF", "\u2708", "\u270E", "\u26BD"
    ]

    function startCreate() {
        editingTagId = 0
        editName = ""
        editColor = "#3182ce"
        editIcon = "\u25C6"
    }

    function startEdit(id, name, color, icon) {
        editingTagId = id
        editName = name
        editColor = color
        editIcon = icon
    }

    function cancelEdit() {
        editingTagId = -1
    }

    function saveTag() {
        if (editName.trim() === "") return
        if (editingTagId === 0) {
            tagModel.createTag(editName.trim(), editColor, editIcon)
        } else {
            tagModel.updateTag(editingTagId, editName.trim(), editColor, editIcon)
        }
        editingTagId = -1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        // Header
        RowLayout {
            Layout.fillWidth: true

            Label {
                text: "Tags"
                color: "#ffffff"
                font.pixelSize: 24
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: newTagLabel.implicitWidth + 24
                implicitHeight: 32
                radius: 6
                color: newTagArea.containsMouse ? Qt.darker(root.accentColor, 1.3) : Qt.darker(root.accentColor, 1.5)

                Label {
                    id: newTagLabel
                    anchors.centerIn: parent
                    text: "+ Neuer Tag"
                    color: "#ffffff"
                    font.pixelSize: 13
                }

                MouseArea {
                    id: newTagArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tagsView.startCreate()
                }
            }
        }

        // Edit/Create form (inline)
        Rectangle {
            Layout.fillWidth: true
            visible: editingTagId >= 0
            implicitHeight: editCol.implicitHeight + 32
            color: "#2a2a2a"
            radius: 8

            ColumnLayout {
                id: editCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Label {
                    text: editingTagId === 0 ? "Neuen Tag erstellen" : "Tag bearbeiten"
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.bold: true
                }

                // Name input
                RowLayout {
                    spacing: 8

                    Label {
                        text: "Name:"
                        color: "#aaaaaa"
                        font.pixelSize: 13
                        Layout.preferredWidth: 50
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        color: "#3a3a3a"
                        radius: 4

                        TextInput {
                            id: nameInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: Text.AlignVCenter
                            color: "#ffffff"
                            font.pixelSize: 13
                            text: tagsView.editName
                            onTextChanged: tagsView.editName = text
                            clip: true

                            Keys.onReturnPressed: tagsView.saveTag()
                            Keys.onEscapePressed: tagsView.cancelEdit()
                        }
                    }
                }

                // Icon picker
                RowLayout {
                    spacing: 8

                    Label {
                        text: "Icon:"
                        color: "#aaaaaa"
                        font.pixelSize: 13
                        Layout.preferredWidth: 50
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: tagsView.presetIcons

                            Rectangle {
                                required property string modelData
                                width: 32
                                height: 32
                                radius: 4
                                color: tagsView.editIcon === modelData ? "#555555" : "#3a3a3a"
                                border.width: tagsView.editIcon === modelData ? 2 : 0
                                border.color: root.accentColor

                                Label {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: 20
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: tagsView.editIcon = modelData
                                }
                            }
                        }
                    }
                }

                // Color picker
                RowLayout {
                    spacing: 8

                    Label {
                        text: "Farbe:"
                        color: "#aaaaaa"
                        font.pixelSize: 13
                        Layout.preferredWidth: 50
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: tagsView.presetColors

                            Rectangle {
                                required property string modelData
                                width: 28
                                height: 28
                                radius: 14
                                color: modelData
                                border.width: tagsView.editColor === modelData ? 3 : 0
                                border.color: "#ffffff"

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: tagsView.editColor = modelData
                                }
                            }
                        }
                    }
                }

                // Preview + actions
                RowLayout {
                    spacing: 12

                    Label {
                        text: "Vorschau:"
                        color: "#aaaaaa"
                        font.pixelSize: 13
                    }

                    Rectangle {
                        implicitWidth: previewRow.implicitWidth + 16
                        implicitHeight: 28
                        radius: 14
                        color: tagsView.editColor

                        RowLayout {
                            id: previewRow
                            anchors.centerIn: parent
                            spacing: 4

                            Label {
                                text: tagsView.editIcon
                                font.pixelSize: 12
                                visible: text !== ""
                            }
                            Label {
                                text: tagsView.editName || "Tag"
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: cancelBtnLabel.implicitWidth + 20
                        implicitHeight: 28
                        radius: 4
                        color: cancelBtnArea.containsMouse ? "#555555" : "#3a3a3a"

                        Label {
                            id: cancelBtnLabel
                            anchors.centerIn: parent
                            text: "Abbrechen"
                            color: "#aaaaaa"
                            font.pixelSize: 12
                        }
                        MouseArea {
                            id: cancelBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tagsView.cancelEdit()
                        }
                    }

                    Rectangle {
                        implicitWidth: saveBtnLabel.implicitWidth + 20
                        implicitHeight: 28
                        radius: 4
                        color: saveBtnArea.containsMouse ? Qt.darker(root.accentColor, 1.2) : root.accentColor

                        Label {
                            id: saveBtnLabel
                            anchors.centerIn: parent
                            text: "Speichern"
                            color: "#ffffff"
                            font.pixelSize: 12
                            font.bold: true
                        }
                        MouseArea {
                            id: saveBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tagsView.saveTag()
                        }
                    }
                }
            }
        }

        // Tag list
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: tagModel
            clip: true
            spacing: 4

            delegate: Rectangle {
                required property int index
                required property var tagId
                required property string name
                required property string tagColor
                required property string tagIcon
                required property int photoCount

                width: ListView.view.width
                height: 56
                radius: 8
                color: tagItemArea.containsMouse ? "#333333" : "#2a2a2a"

                MouseArea {
                    id: tagItemArea
                    anchors.fill: parent
                    hoverEnabled: true
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    // Color dot + icon
                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: tagColor

                        Label {
                            anchors.centerIn: parent
                            text: tagIcon
                            font.pixelSize: 16
                        }
                    }

                    // Name
                    Label {
                        text: name
                        color: "#ffffff"
                        font.pixelSize: 15
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    // Photo count
                    Label {
                        text: photoCount + " Medien"
                        color: "#888888"
                        font.pixelSize: 12
                    }

                    // Send button
                    Rectangle {
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: 4
                        color: sendTagArea.containsMouse ? Qt.darker(root.accentColor, 1.3) : "transparent"
                        visible: photoCount > 0

                        Label {
                            anchors.centerIn: parent
                            text: "\u2B06"
                            font.pixelSize: 18
                        }
                        MouseArea {
                            id: sendTagArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var ids = tagModel.photoIdsForTag(tagId)
                                if (ids.length > 0) {
                                    sendSheet.openMultiple(ids)
                                }
                            }
                        }
                    }

                    // Edit button
                    Rectangle {
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: 4
                        color: editArea.containsMouse ? "#555555" : "transparent"

                        Label {
                            anchors.centerIn: parent
                            text: "\u270E"
                            color: "#cccccc"
                            font.pixelSize: 18
                        }
                        MouseArea {
                            id: editArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tagsView.startEdit(tagId, name, tagColor, tagIcon)
                        }
                    }

                    // Delete button
                    Rectangle {
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: 4
                        color: delArea.containsMouse ? "#aa3333" : "transparent"

                        Label {
                            anchors.centerIn: parent
                            text: "\u2715"
                            color: "#cccccc"
                            font.pixelSize: 18
                        }
                        MouseArea {
                            id: delArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tagModel.deleteTag(tagId)
                        }
                    }
                }
            }

            // Empty state
            Label {
                anchors.centerIn: parent
                visible: tagModel.count === 0
                text: "Keine Tags vorhanden.\nErstelle einen neuen Tag mit dem Button oben."
                color: "#666666"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
