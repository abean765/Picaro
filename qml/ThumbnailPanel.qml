import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: thumbnailPanel

    color: "#1e1e1e"

    // ── Signals ────────────────────────────────────────────────────────────────

    signal closeRequested()

    // ── Public API ─────────────────────────────────────────────────────────────

    // Currently selected tag (-1 = none)
    property int    selectedTagId:   -1
    property string selectedTagName: ""

    // Set to true by Main.qml while a drag ghost from an external source hovers
    // over this panel (shows drop-zone highlight).
    property bool dragOver: false

    // Photo IDs in user-defined order (default = DB order, modifiable via reorder).
    // Replaces tagPhotoIds from TagFilterPanel.
    property var orderedPhotoIds: []

    // ── Panel-internal multi-selection ─────────────────────────────────────────
    property var selectedPanelIds:    []
    property int panelSelectionAnchor: -1

    // ── Cross-panel drag state (read by Main.qml) ──────────────────────────────
    // Set while the user drags a photo OUT of this panel.
    property int   panelDraggingPhotoId: -1
    property point panelDragScenePos:    Qt.point(0, 0)

    // ── Reorder state (internal) ───────────────────────────────────────────────
    property int  reorderDraggingId:   -1   // photo currently being reordered
    property int  reorderInsertIndex:  -1   // target insertion slot (-1 = outside grid)
    readonly property bool isReordering: reorderInsertIndex >= 0 && reorderDraggingId > 0

    // ── Effective model: orderedPhotoIds with a gap sentinel (-1) ──────────────
    // During a reorder drag the dragging photo is hidden from its original
    // position and a gap (-1) appears at the target insertion slot.
    readonly property var effectiveModel: {
        if (!isReordering) return orderedPhotoIds
        // Source array without the dragging item
        var src = orderedPhotoIds.filter(function(id) { return id !== reorderDraggingId })
        var result = src.slice()
        var at = Math.min(reorderInsertIndex, result.length)
        result.splice(at, 0, -1)   // -1 = empty gap cell
        return result
    }

    // ── Helper functions ───────────────────────────────────────────────────────

    // Map a scene-space position to a grid insertion index.
    function calcInsertIndex(scenePos) {
        var lp    = panelGrid.mapFromItem(null, scenePos.x, scenePos.y)
        var sy    = lp.y + panelGrid.contentY
        var cW    = panelGrid.cellWidth
        var cH    = panelGrid.cellHeight
        var cols  = 3

        var col = Math.max(0, Math.min(cols - 1, Math.floor(lp.x / cW)))
        var row = Math.max(0, Math.floor(sy / cH))
        var idx = row * cols + col

        // Insert after the cell if cursor is in its right half
        if (lp.x - col * cW > cW / 2) idx++

        var total = orderedPhotoIds.filter(function(id) {
            return id !== reorderDraggingId
        }).length
        return Math.max(0, Math.min(total, idx))
    }

    // Apply the current reorderInsertIndex to orderedPhotoIds.
    function applyReorder() {
        if (reorderDraggingId <= 0 || reorderInsertIndex < 0) return
        var arr = orderedPhotoIds.filter(function(id) { return id !== reorderDraggingId })
        arr.splice(Math.min(reorderInsertIndex, arr.length), 0, reorderDraggingId)
        orderedPhotoIds = arr
    }

    function handlePanelCellClick(photoId, modifiers) {
        var ctrl  = (modifiers & Qt.ControlModifier) !== 0
        var shift = (modifiers & Qt.ShiftModifier)   !== 0

        if (shift && panelSelectionAnchor > 0) {
            var ids = orderedPhotoIds
            var a = ids.indexOf(panelSelectionAnchor)
            var b = ids.indexOf(photoId)
            if (a < 0 || b < 0) { selectedPanelIds = [photoId]; return }
            if (a > b) { var tmp = a; a = b; b = tmp }
            var range = []
            for (var i = a; i <= b; i++) range.push(ids[i])
            selectedPanelIds = range
        } else if (ctrl) {
            var arr = selectedPanelIds.slice()
            var idx = arr.indexOf(photoId)
            if (idx >= 0) arr.splice(idx, 1)
            else          arr.push(photoId)
            selectedPanelIds     = arr
            panelSelectionAnchor = photoId
        } else {
            selectedPanelIds     = [photoId]
            panelSelectionAnchor = photoId
            root.selectPhoto(photoId)
        }
    }

    // Called by Main.qml when selected panel photos are dragged to a destination
    // without a tag (= remove this panel's tag from those photos).
    function removeDraggedPhotos(photoIds) {
        if (selectedTagId <= 0) return
        for (var i = 0; i < photoIds.length; i++) {
            if (photoIds[i] > 0)
                tagModel.removeTagFromPhoto(photoIds[i], selectedTagId)
        }
        selectedPanelIds = selectedPanelIds.filter(function(id) {
            return photoIds.indexOf(id) < 0
        })
        // refreshPhotos() fires automatically via tagsChanged
    }

    // Called by Main.qml when photos are dropped onto this panel (add this tag).
    function acceptDrop(photoIds) {
        if (selectedTagId <= 0) return
        for (var i = 0; i < photoIds.length; i++) {
            if (photoIds[i] > 0)
                tagModel.addTagToPhoto(photoIds[i], selectedTagId)
        }
    }

    function refreshPhotos() {
        orderedPhotoIds = selectedTagId > 0
            ? tagModel.photoIdsForTag(selectedTagId) : []
    }

    function selectTag(tagId, tagName) {
        selectedTagId        = tagId
        selectedTagName      = tagName
        tagInput.text        = tagName
        dropdownVisible      = false
        selectedPanelIds     = []
        panelSelectionAnchor = -1
        refreshPhotos()
    }

    function clearTag() {
        selectedTagId        = -1
        selectedTagName      = ""
        tagInput.text        = ""
        orderedPhotoIds      = []
        selectedPanelIds     = []
        panelSelectionAnchor = -1
    }

    // Re-fetch photo list whenever tagModel changes
    Connections {
        target: tagModel
        function onTagsChanged() {
            thumbnailPanel.refreshPhotos()
            thumbnailPanel.rebuildTagList()
        }
    }

    // ── Internal state ─────────────────────────────────────────────────────────

    property bool dropdownVisible: false
    property var  allTags:        []
    property var  filteredTags:   []

    function rebuildTagList() {
        allTags = tagModel.allTagsFlat()
        applyFilter()
    }

    function applyFilter() {
        var f = tagInput.text.trim().toLowerCase()
        filteredTags = f === "" ? allTags : allTags.filter(function(t) {
            return t.name.toLowerCase().indexOf(f) >= 0
        })
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
                    text: thumbnailPanel.selectedTagId > 0
                          ? thumbnailPanel.selectedTagName : "Thumbnail-Panel"
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
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
                        onClicked: thumbnailPanel.closeRequested()
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
                            thumbnailPanel.applyFilter()
                            thumbnailPanel.dropdownVisible = true
                        }
                        onActiveFocusChanged: {
                            if (activeFocus) {
                                thumbnailPanel.rebuildTagList()
                                thumbnailPanel.dropdownVisible = true
                            }
                        }
                        Keys.onEscapePressed: {
                            thumbnailPanel.dropdownVisible = false
                            tagInput.focus = false
                        }
                        Keys.onReturnPressed: {
                            if (thumbnailPanel.filteredTags.length > 0) {
                                var t = thumbnailPanel.filteredTags[0]
                                thumbnailPanel.selectTag(t.id, t.name)
                            }
                        }
                    }

                    Rectangle {
                        width: 18; height: 18; radius: 9
                        visible: tagInput.text.length > 0 || thumbnailPanel.selectedTagId > 0
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
                            onClicked: thumbnailPanel.clearTag()
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
            visible: thumbnailPanel.dropdownVisible && thumbnailPanel.filteredTags.length > 0
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
                model: thumbnailPanel.filteredTags
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
                        onClicked: thumbnailPanel.selectTag(modelData.id, modelData.name)
                    }
                }
            }
        }

        // ── Selected tag chip ─────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            height: thumbnailPanel.selectedTagId > 0 ? 36 : 0
            visible: thumbnailPanel.selectedTagId > 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Rectangle {
                    implicitWidth: chipRow.implicitWidth + 14
                    height: 22
                    radius: 11
                    color: thumbnailPanel.selectedTagId > 0
                           ? tagModel.tagColor(thumbnailPanel.selectedTagId)
                           : "#888888"

                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 4
                        Label {
                            text: thumbnailPanel.selectedTagId > 0
                                  ? tagModel.tagIcon(thumbnailPanel.selectedTagId) : ""
                            font.pixelSize: 10
                            visible: text !== ""
                        }
                        Label {
                            text: thumbnailPanel.selectedTagName
                            color: "#ffffff"
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }

                Label {
                    text: thumbnailPanel.orderedPhotoIds.length + " Foto" +
                          (thumbnailPanel.orderedPhotoIds.length === 1 ? "" : "s")
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
            visible: thumbnailPanel.selectedTagId > 0
        }

        // ── Content area: thumbnail grid + overlays ───────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Close dropdown when clicking in content area
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: thumbnailPanel.dropdownVisible = false
            }

            // Drop zone highlight (external drag ghost hovering over this panel)
            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                z: 20
                radius: 8
                visible: thumbnailPanel.dragOver
                color: thumbnailPanel.selectedTagId > 0 ? "#25ffffff" : "#15ffffff"
                border.color: thumbnailPanel.selectedTagId > 0
                              ? root.accentColor : "#666666"
                border.width: 2

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: thumbnailPanel.selectedTagId > 0 ? "\u25BC" : "\u26A0"
                        color: thumbnailPanel.selectedTagId > 0
                               ? root.accentColor : "#aaaaaa"
                        font.pixelSize: 28
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            if (thumbnailPanel.selectedTagId <= 0)
                                return "Zuerst einen Tag\noben wählen"
                            var n = root.selectedPhotoIds.length
                            var photoStr = n > 1 ? n + " Fotos" : "Foto"
                            return photoStr + " mit Tag\n\"" +
                                   thumbnailPanel.selectedTagName + "\"\nverknüpfen"
                        }
                        color: thumbnailPanel.selectedTagId > 0 ? "#ffffff" : "#aaaaaa"
                        font.pixelSize: 13
                        font.bold: thumbnailPanel.selectedTagId > 0
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // ── Thumbnail grid ─────────────────────────────────────────────────
            GridView {
                id: panelGrid
                anchors.fill: parent
                anchors.margins: 4
                model: thumbnailPanel.effectiveModel
                clip: true
                visible: !thumbnailPanel.dragOver

                readonly property real _cellSize: Math.max(60, Math.floor((width - 6) / 3))
                cellWidth:  _cellSize + 2
                cellHeight: _cellSize + 2

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Item {
                    id: cellDelegate
                    required property var modelData
                    required property int index
                    width:  panelGrid.cellWidth
                    height: panelGrid.cellHeight

                    readonly property bool isGap:      modelData === -1
                    readonly property bool isSelected:
                        !isGap &&
                        thumbnailPanel.selectedPanelIds.indexOf(modelData) >= 0
                    readonly property bool isDragging:
                        !isGap && modelData === thumbnailPanel.reorderDraggingId

                    // ── Gap cell (insertion preview) ───────────────────────────
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        visible: cellDelegate.isGap
                        color: "#20" + root.accentColor.toString().substring(1)
                        border.color: root.accentColor
                        border.width: 2
                        radius: 4

                        // Animated pulse to make the gap visible
                        SequentialAnimation on opacity {
                            running: cellDelegate.isGap
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 500 }
                            NumberAnimation { to: 1.0; duration: 500 }
                        }
                    }

                    // ── Real photo cell ────────────────────────────────────────
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        visible: !cellDelegate.isGap
                        color: "#2a2a2a"
                        // Dim while this photo is being reorder-dragged
                        opacity: cellDelegate.isDragging ? 0.25 : 1.0

                        Image {
                            anchors.fill: parent
                            source: !cellDelegate.isGap && modelData > 0
                                    ? "image://thumbnail/" + modelData : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            opacity: status === Image.Ready ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                        }

                        // Selection highlight
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: root.accentColor
                            border.width: cellDelegate.isSelected ? 3 : 0
                            z: 2
                        }

                        // Dim unselected when a selection exists
                        Rectangle {
                            anchors.fill: parent
                            color: "#60000000"
                            visible: thumbnailPanel.selectedPanelIds.length > 0 &&
                                     !cellDelegate.isSelected && !cellDelegate.isGap
                            z: 1
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            z: 3
                            enabled: !cellDelegate.isGap
                            onClicked: function(mouse) {
                                thumbnailPanel.handlePanelCellClick(modelData, mouse.modifiers)
                            }
                        }

                        // ── Drag handler ───────────────────────────────────────
                        // Handles both intra-panel reorder and cross-panel drag.
                        DragHandler {
                            id: cellDragHandler
                            target: null
                            enabled: !cellDelegate.isGap

                            onActiveChanged: {
                                if (active) {
                                    thumbnailPanel.reorderDraggingId  = modelData
                                    thumbnailPanel.panelDraggingPhotoId = modelData
                                } else {
                                    // Determine if we dropped inside the GridView
                                    var sp = thumbnailPanel.panelDragScenePos
                                    var lp = panelGrid.mapFromItem(null, sp.x, sp.y)
                                    var inGrid = lp.x >= 0 && lp.y >= 0 &&
                                                 lp.x < panelGrid.width &&
                                                 lp.y < panelGrid.height

                                    if (inGrid && thumbnailPanel.reorderDraggingId > 0) {
                                        // ── Intra-panel reorder ────────────────
                                        thumbnailPanel.reorderInsertIndex =
                                            thumbnailPanel.calcInsertIndex(sp)
                                        thumbnailPanel.applyReorder()
                                        thumbnailPanel.reorderInsertIndex  = -1
                                        thumbnailPanel.reorderDraggingId   = -1
                                        thumbnailPanel.panelDraggingPhotoId = -1
                                    } else {
                                        // ── Cross-panel / grid drag ────────────
                                        thumbnailPanel.reorderInsertIndex  = -1
                                        thumbnailPanel.reorderDraggingId   = -1
                                        // panelDraggingPhotoId cleared by Main.qml
                                        // after it processes the drop.
                                        if (thumbnailPanel.panelDraggingPhotoId === modelData)
                                            thumbnailPanel.panelDraggingPhotoId = -1
                                    }
                                }
                            }

                            onCentroidChanged: {
                                if (!active) return
                                var sp = centroid.scenePosition
                                thumbnailPanel.panelDragScenePos = sp

                                // Update reorder preview while inside the GridView
                                var lp = panelGrid.mapFromItem(null, sp.x, sp.y)
                                if (lp.x >= 0 && lp.y >= 0 &&
                                    lp.x < panelGrid.width && lp.y < panelGrid.height) {
                                    thumbnailPanel.reorderInsertIndex =
                                        thumbnailPanel.calcInsertIndex(sp)
                                } else {
                                    thumbnailPanel.reorderInsertIndex = -1
                                }
                            }
                        }
                    }
                }
            }

            // ── Reorder ghost: small thumbnail following the cursor within panel ──
            Rectangle {
                id: reorderGhost
                parent: thumbnailPanel
                visible: thumbnailPanel.isReordering
                z: 100
                width:  panelGrid.cellWidth  - 6
                height: panelGrid.cellHeight - 6
                radius: 4
                clip: true
                border.color: root.accentColor
                border.width: 2
                opacity: 0.75

                readonly property point _local: {
                    var sp = thumbnailPanel.panelDragScenePos
                    return thumbnailPanel.mapFromItem(null, sp.x, sp.y)
                }
                x: _local.x - width  / 2
                y: _local.y - height / 2

                Image {
                    anchors.fill: parent
                    source: thumbnailPanel.reorderDraggingId > 0
                            ? "image://thumbnail/" + thumbnailPanel.reorderDraggingId : ""
                    fillMode: Image.PreserveAspectCrop
                    cache: true
                }
            }

            // ── Empty state: no tag selected ───────────────────────────────────
            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: thumbnailPanel.selectedTagId <= 0 && !thumbnailPanel.dragOver

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

            // ── Empty state: tag selected but no photos ────────────────────────
            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: thumbnailPanel.selectedTagId > 0 &&
                         thumbnailPanel.orderedPhotoIds.length === 0 &&
                         !thumbnailPanel.dragOver

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
