import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: tagFilterPanel

    color: "#1e1e1e"

    // ── Public API ─────────────────────────────────────────────────────────────

    // Currently selected tag (-1 = none)
    property int  selectedTagId:   -1
    property string selectedTagName: ""

    // Set to true by Main.qml while the drag ghost is positioned over this panel
    property bool dragOver: false

    // Photo IDs that carry the selected tag
    property var tagPhotoIds: []

    // Called by Main.qml when a photo is dropped onto this panel
    function acceptDrop(photoId) {
        if (selectedTagId <= 0 || photoId <= 0) return
        tagModel.addTagToPhoto(photoId, selectedTagId)
        // photoIdsForTag is called inside refreshPhotos via tagsChanged signal
    }

    function refreshPhotos() {
        tagPhotoIds = selectedTagId > 0 ? tagModel.photoIdsForTag(selectedTagId) : []
    }

    function selectTag(tagId, tagName) {
        selectedTagId  = tagId
        selectedTagName = tagName
        tagInput.text  = tagName
        dropdownVisible = false
        refreshPhotos()
    }

    function clearTag() {
        selectedTagId   = -1
        selectedTagName = ""
        tagInput.text   = ""
        tagPhotoIds     = []
    }

    // Re-fetch photo list whenever tagModel changes (e.g. after a drop assignment)
    Connections {
        target: tagModel
        function onTagsChanged() { tagFilterPanel.refreshPhotos() }
    }

    // ── Internal state ─────────────────────────────────────────────────────────

    property bool   dropdownVisible: false
    property var    allTags:         []   // populated from tagModel.allTagsFlat()
    property var    filteredTags:    []

    function rebuildTagList() {
        allTags = tagModel.allTagsFlat()
        applyFilter()
    }

    function applyFilter() {
        var f = tagInput.text.trim().toLowerCase()
        if (f === "") {
            filteredTags = allTags
        } else {
            filteredTags = allTags.filter(function(t) {
                return t.name.toLowerCase().indexOf(f) >= 0
            })
        }
    }

    Connections {
        target: tagModel
        function onTagsChanged() { tagFilterPanel.rebuildTagList() }
    }

    Component.onCompleted: rebuildTagList()

    // ── Layout ─────────────────────────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header bar ────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color: "#252525"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6

                Label {
                    text: "\u25C6"
                    color: root.accentColor
                    font.pixelSize: 11
                }
                Label {
                    text: "Tag-Panel"
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.bold: true
                    Layout.fillWidth: true
                }
                Rectangle {
                    width: 22; height: 22; radius: 11
                    color: closePanelArea.containsMouse ? "#555555" : "transparent"
                    Label {
                        anchors.centerIn: parent
                        text: "\u2715"
                        color: "#aaaaaa"
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: closePanelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: photosViewRoot.tagPanelVisible = false
                    }
                }
            }
        }

        // ── Tag input with autocomplete ────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            height: 44

            Rectangle {
                anchors.fill: parent
                anchors.margins: 8
                color: tagInput.activeFocus ? "#3a3a3a" : "#2e2e2e"
                radius: 10
                border.color: tagInput.activeFocus ? root.accentColor : "#444444"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 6

                    Label {
                        text: "\u25C6"
                        color: "#888888"
                        font.pixelSize: 10
                    }

                    TextInput {
                        id: tagInput
                        Layout.fillWidth: true
                        color: "#ffffff"
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                        clip: true
                        selectByMouse: true

                        onTextChanged: {
                            tagFilterPanel.applyFilter()
                            tagFilterPanel.dropdownVisible = true
                        }
                        onActiveFocusChanged: {
                            if (activeFocus) {
                                tagFilterPanel.rebuildTagList()
                                tagFilterPanel.dropdownVisible = true
                            }
                        }
                        Keys.onEscapePressed: {
                            tagFilterPanel.dropdownVisible = false
                            tagInput.focus = false
                        }
                        Keys.onReturnPressed: {
                            if (tagFilterPanel.filteredTags.length > 0) {
                                var t = tagFilterPanel.filteredTags[0]
                                tagFilterPanel.selectTag(t.id, t.name)
                            }
                        }
                    }

                    Rectangle {
                        width: 18; height: 18; radius: 9
                        visible: tagInput.text.length > 0 || tagFilterPanel.selectedTagId > 0
                        color: clearInputArea.containsMouse ? "#555555" : "transparent"
                        Label {
                            anchors.centerIn: parent
                            text: "\u2715"
                            color: "#aaaaaa"
                            font.pixelSize: 10
                        }
                        MouseArea {
                            id: clearInputArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tagFilterPanel.clearTag()
                        }
                    }
                }

                // Placeholder
                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: 30
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Tag wählen…"
                    color: "#666666"
                    font.pixelSize: 12
                    visible: tagInput.text.length === 0 && !tagInput.activeFocus
                }
            }
        }

        // ── Autocomplete dropdown ──────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: tagFilterPanel.dropdownVisible && tagFilterPanel.filteredTags.length > 0
            height: Math.min(tagDropList.contentHeight + 8, 180)
            color: "#2a2a2a"
            border.color: "#444444"
            border.width: 1
            clip: true
            z: 10

            ListView {
                id: tagDropList
                anchors.fill: parent
                anchors.margins: 4
                model: tagFilterPanel.filteredTags
                clip: true

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 28
                    radius: 4
                    color: dropTagItemArea.containsMouse ? "#3a3a3a" : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8 + modelData.depth * 12
                        anchors.rightMargin: 8
                        spacing: 6

                        Rectangle {
                            width: 10; height: 10; radius: 5
                            color: modelData.color
                        }
                        Label {
                            text: modelData.icon
                            font.pixelSize: 11
                            visible: text !== ""
                        }
                        Label {
                            text: modelData.name
                            color: "#dddddd"
                            font.pixelSize: 12
                            font.bold: modelData.depth === 0
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: dropTagItemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tagFilterPanel.selectTag(modelData.id, modelData.name)
                    }
                }
            }
        }

        // ── Selected tag chip ─────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            height: tagFilterPanel.selectedTagId > 0 ? 36 : 0
            visible: tagFilterPanel.selectedTagId > 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Rectangle {
                    implicitWidth: chipRow.implicitWidth + 14
                    height: 22
                    radius: 11
                    color: tagFilterPanel.selectedTagId > 0
                           ? tagModel.tagColor(tagFilterPanel.selectedTagId)
                           : "#888888"

                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 4
                        Label {
                            text: tagFilterPanel.selectedTagId > 0
                                  ? tagModel.tagIcon(tagFilterPanel.selectedTagId) : ""
                            font.pixelSize: 10
                            visible: text !== ""
                        }
                        Label {
                            text: tagFilterPanel.selectedTagName
                            color: "#ffffff"
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }

                Label {
                    text: tagFilterPanel.tagPhotoIds.length + " Foto" +
                          (tagFilterPanel.tagPhotoIds.length === 1 ? "" : "s")
                    color: "#888888"
                    font.pixelSize: 11
                }
                Item { Layout.fillWidth: true }
            }
        }

        // ── Thin separator ────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#333333"
            visible: tagFilterPanel.selectedTagId > 0
        }

        // ── Content area: thumbnail grid + drop zone overlay ──────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Close the dropdown when clicking anywhere in the content area
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: tagFilterPanel.dropdownVisible = false
            }

            // Drop zone highlight when a thumbnail is dragged over the panel
            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                z: 20
                radius: 8
                visible: tagFilterPanel.dragOver
                color: tagFilterPanel.selectedTagId > 0 ? "#25ffffff" : "#15ffffff"
                border.color: tagFilterPanel.selectedTagId > 0
                              ? root.accentColor : "#666666"
                border.width: 2

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tagFilterPanel.selectedTagId > 0
                              ? "\u25BC"   // down arrow = drop here
                              : "\u26A0"   // warning = no tag selected
                        color: tagFilterPanel.selectedTagId > 0
                               ? root.accentColor : "#aaaaaa"
                        font.pixelSize: 28
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tagFilterPanel.selectedTagId > 0
                              ? "Tag \"" + tagFilterPanel.selectedTagName + "\"\nzuweisen"
                              : "Zuerst einen Tag\noben wählen"
                        color: tagFilterPanel.selectedTagId > 0 ? "#ffffff" : "#aaaaaa"
                        font.pixelSize: 13
                        font.bold: tagFilterPanel.selectedTagId > 0
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Thumbnail grid
            GridView {
                id: tagPhotoGrid
                anchors.fill: parent
                anchors.margins: 4
                model: tagFilterPanel.tagPhotoIds
                clip: true
                visible: !tagFilterPanel.dragOver

                readonly property real _cellSize: Math.max(60, Math.floor((width - 6) / 3))
                cellWidth:  _cellSize + 2
                cellHeight: _cellSize + 2

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Item {
                    required property var modelData
                    width:  tagPhotoGrid.cellWidth
                    height: tagPhotoGrid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        color: "#2a2a2a"

                        Image {
                            anchors.fill: parent
                            source: "image://thumbnail/" + modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true

                            opacity: status === Image.Ready ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectPhoto(modelData)
                        }
                    }
                }
            }

            // Empty state — no tag selected
            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: tagFilterPanel.selectedTagId <= 0 && !tagFilterPanel.dragOver

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\u25C6"
                    color: "#3a3a3a"
                    font.pixelSize: 36
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Tag oben wählen\num Fotos zu sehen"
                    color: "#666666"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Fotos per Drag & Drop\nhierhier ziehen zum\nTag zuweisen"
                    color: "#444444"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // Empty state — tag selected but no photos yet
            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: tagFilterPanel.selectedTagId > 0 &&
                         tagFilterPanel.tagPhotoIds.length === 0 &&
                         !tagFilterPanel.dragOver

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Keine Fotos\nmit diesem Tag"
                    color: "#666666"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Fotos per Drag & Drop\nhierhier ziehen"
                    color: "#444444"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
