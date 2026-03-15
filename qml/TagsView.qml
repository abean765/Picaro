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
    property var editParentId: -1      // -1 = root tag

    // Collapsed tree nodes (set of tag IDs whose children are hidden)
    property var collapsedIds: ({})

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

    // Returns whether a row at list index i should be visible
    // (i.e. none of its ancestors are collapsed)
    function isVisible(index) {
        var pid = tagModel.data(tagModel.index(index, 0), 259)  // ParentIdRole = Qt.UserRole+6 = 261... use role name lookup below
        // We rely on the delegate to check ancestors via parentId chain
        return true
    }

    function hasChildren(tagId) {
        for (var i = 0; i < tagModel.count; i++) {
            if (tagModel.data(tagModel.index(i, 0), 260) === tagId)  // ParentIdRole
                return true
        }
        return false
    }

    function isAncestorCollapsed(parentId) {
        var pid = parentId
        while (pid >= 0) {
            if (collapsedIds[pid]) return true
            // walk up
            var found = false
            for (var i = 0; i < tagModel.count; i++) {
                var rowId = tagModel.data(tagModel.index(i, 0), 257)  // IdRole
                if (rowId === pid) {
                    pid = tagModel.data(tagModel.index(i, 0), 260)    // ParentIdRole
                    found = true
                    break
                }
            }
            if (!found) break
        }
        return false
    }

    function toggleCollapse(tagId) {
        var copy = Object.assign({}, collapsedIds)
        if (copy[tagId]) delete copy[tagId]
        else copy[tagId] = true
        collapsedIds = copy
    }

    function startCreate(parentId) {
        editingTagId = 0
        editName = ""
        editColor = "#3182ce"
        editIcon = "\u25C6"
        editParentId = (parentId !== undefined) ? parentId : -1
    }

    function startEdit(id, name, color, icon, parentId) {
        editingTagId = id
        editName = name
        editColor = color
        editIcon = icon
        editParentId = parentId
    }

    function cancelEdit() {
        editingTagId = -1
    }

    function saveTag() {
        if (editName.trim() === "") return
        if (editingTagId === 0) {
            tagModel.createTag(editName.trim(), editColor, editIcon, editParentId)
        } else {
            tagModel.updateTag(editingTagId, editName.trim(), editColor, editIcon, editParentId)
        }
        editingTagId = -1
    }

    // Parent tag name for display in form header
    function parentTagName(pid) {
        if (pid < 0) return ""
        return tagModel.tagName(pid)
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
                    onClicked: tagsView.startCreate(-1)
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
                    text: {
                        if (editingTagId === 0) {
                            return editParentId >= 0
                                ? "Kind-Tag erstellen unter \"" + tagsView.parentTagName(editParentId) + "\""
                                : "Neuen Tag erstellen"
                        }
                        return "Tag bearbeiten"
                    }
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
                                width: 40
                                height: 40
                                radius: 4
                                color: tagsView.editIcon === modelData ? "#555555" : "#3a3a3a"
                                border.width: tagsView.editIcon === modelData ? 2 : 0
                                border.color: root.accentColor

                                Label {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: "#ffffff"
                                    font.pixelSize: 22
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

        // Tag list (tree view via flat model with depth/parent info)
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: tagModel
            clip: true
            spacing: 2

            delegate: Item {
                required property int index
                required property var tagId
                required property string name
                required property string tagColor
                required property string tagIcon
                required property int photoCount
                required property var parentId
                required property int depth

                // Hide rows whose ancestor is collapsed
                property bool ancestorCollapsed: {
                    var pid = parentId
                    while (pid >= 0) {
                        if (tagsView.collapsedIds[pid]) return true
                        pid = tagModel.tagParentId(pid)
                    }
                    return false
                }

                property bool hasChildTags: {
                    // Recompute when collapsedIds or model changes
                    tagsView.collapsedIds
                    for (var i = 0; i < tagModel.count; i++) {
                        if (tagModel.data(tagModel.index(i, 0), 260) === tagId)
                            return true
                    }
                    return false
                }

                property bool isCollapsed: tagsView.collapsedIds[tagId] === true

                width: ListView.view.width
                height: ancestorCollapsed ? 0 : 56
                clip: true

                Behavior on height { NumberAnimation { duration: 120 } }

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: tagItemArea.containsMouse ? "#333333" : "#2a2a2a"

                    MouseArea {
                        id: tagItemArea
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16 + depth * 20   // indentation per level
                        anchors.rightMargin: 16
                        spacing: 8

                        // Collapse/expand triangle (only shown when tag has children)
                        Item {
                            width: 18
                            height: 18
                            visible: hasChildTags

                            Label {
                                anchors.centerIn: parent
                                text: isCollapsed ? "\u25B6" : "\u25BC"
                                color: "#aaaaaa"
                                font.pixelSize: 11
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tagsView.toggleCollapse(tagId)
                            }
                        }

                        // Spacer when no children (keeps alignment)
                        Item {
                            width: 18
                            height: 18
                            visible: !hasChildTags
                        }

                        // Color dot + icon
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: tagColor

                            Label {
                                anchors.centerIn: parent
                                text: tagIcon
                                font.pixelSize: 14
                            }
                        }

                        // Name
                        Label {
                            text: name
                            color: "#ffffff"
                            font.pixelSize: 14
                            font.bold: depth === 0
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
                            implicitWidth: sendBtnRow.implicitWidth + 16
                            implicitHeight: 28
                            radius: 6
                            color: sendTagArea.containsMouse
                                ? Qt.darker(root.accentColor, 1.2)
                                : root.accentColor
                            visible: photoCount > 0

                            RowLayout {
                                id: sendBtnRow
                                anchors.centerIn: parent
                                spacing: 4

                                Label {
                                    text: "\u2B06"
                                    color: "#ffffff"
                                    font.pixelSize: 13
                                }
                                Label {
                                    text: "Senden"
                                    color: "#ffffff"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
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

                        // Add child tag button
                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 4
                            color: addChildArea.containsMouse ? "#555555" : "transparent"
                            ToolTip.text: "Kind-Tag erstellen"
                            ToolTip.visible: addChildArea.containsMouse
                            ToolTip.delay: 600

                            Label {
                                anchors.centerIn: parent
                                text: "\u2795"   // heavy plus
                                color: "#aaaaaa"
                                font.pixelSize: 13
                            }
                            MouseArea {
                                id: addChildArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tagsView.startCreate(tagId)
                            }
                        }

                        // Edit button
                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 4
                            color: editArea.containsMouse ? "#555555" : "transparent"

                            Label {
                                anchors.centerIn: parent
                                text: "\u270E"
                                color: "#cccccc"
                                font.pixelSize: 16
                            }
                            MouseArea {
                                id: editArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tagsView.startEdit(tagId, name, tagColor, tagIcon, parentId)
                            }
                        }

                        // Delete button
                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 4
                            color: delArea.containsMouse ? "#aa3333" : "transparent"

                            Label {
                                anchors.centerIn: parent
                                text: "\u2715"
                                color: "#cccccc"
                                font.pixelSize: 16
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
