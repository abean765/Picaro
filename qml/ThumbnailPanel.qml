import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A thumbnail panel with an optional tag selector.
// Two instances are shown side-by-side in photosViewRoot.
//
// Drag semantics (coordinated by Main.qml):
//   • drop from the main grid onto this panel
//       – panel has a tag  → add that tag to the dropped photos
//       – panel has no tag → remove every tag from the dropped photos (no-op here; handled outside)
//   • drag from this panel to the other panel
//       – other panel has a tag  → add that tag
//       – other panel has no tag → remove this panel's tag from those photos
Rectangle {
    id: panel

    color: "#1e1e1e"

    // ── Public API ──────────────────────────────────────────────────────────

    // Currently selected tag (-1 = none)
    property int    selectedTagId:   -1
    property string selectedTagName: ""

    // Photo IDs that carry the selected tag (filled automatically)
    property var tagPhotoIds: []

    // Set to true by Main.qml while the drag ghost from the OTHER panel (or the
    // main grid) is positioned over this panel
    property bool dragOver: false

    // Drag state for outgoing drag (this panel → other panel / grid); read by Main.qml
    property int   draggingPhotoId: -1
    property point dragScenePos:    Qt.point(0, 0)

    // Panel-internal multi-selection
    property var selectedPanelIds:     []
    property int panelSelectionAnchor: -1

    // ── Public functions ────────────────────────────────────────────────────

    // Called by Main.qml when photos are dropped onto this panel from outside.
    function acceptDrop(photoIds) {
        if (selectedTagId <= 0) return
        for (var i = 0; i < photoIds.length; i++) {
            if (photoIds[i] > 0)
                tagModel.addTagToPhoto(photoIds[i], selectedTagId)
        }
    }

    // Called by Main.qml when a drag from this panel was dropped somewhere that
    // means "remove tag" (e.g. onto a panel without a tag, or back onto the grid
    // when removal is requested).
    function removeDraggedPhotos(photoIds) {
        if (selectedTagId <= 0) return
        for (var i = 0; i < photoIds.length; i++) {
            if (photoIds[i] > 0)
                tagModel.removeTagFromPhoto(photoIds[i], selectedTagId)
        }
        selectedPanelIds = selectedPanelIds.filter(function(id) {
            return photoIds.indexOf(id) < 0
        })
    }

    function refreshPhotos() {
        tagPhotoIds = selectedTagId > 0 ? tagModel.photoIdsForTag(selectedTagId) : []
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
        tagPhotoIds          = []
        selectedPanelIds     = []
        panelSelectionAnchor = -1
    }

    function handlePanelCellClick(photoId, modifiers) {
        var ctrl  = (modifiers & Qt.ControlModifier) !== 0
        var shift = (modifiers & Qt.ShiftModifier)   !== 0

        if (shift && panelSelectionAnchor > 0) {
            var ids = tagPhotoIds
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
            root.scrollPhotoIntoView(photoId)
        }
    }

    // Re-fetch photo list whenever tagModel changes (e.g. after a drop)
    Connections {
        target: tagModel
        function onTagsChanged() {
            panel.refreshPhotos()
            panel.rebuildTagList()
        }
    }

    // ── Internal state ──────────────────────────────────────────────────────

    property bool dropdownVisible: false
    property var  allTags:         []
    property var  filteredTags:    []

    // Reorder state: index where the insert indicator is shown, -1 when not dragging
    property int  reorderInsertIndex: -1
    // Photo being reordered within this panel (from within this panel only)
    property int  reorderingPhotoId: -1

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

    Component.onCompleted: rebuildTagList()

    // ── Layout ──────────────────────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ──────────────────────────────────────────────────────────
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
                    color: panel.selectedTagId > 0
                           ? tagModel.tagColor(panel.selectedTagId)
                           : root.accentColor
                    font.pixelSize: 11
                }
                Label {
                    text: panel.selectedTagId > 0 ? panel.selectedTagName : "Panel"
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Label {
                    visible: panel.selectedTagId > 0
                    text: panel.tagPhotoIds.length + " Foto" +
                          (panel.tagPhotoIds.length === 1 ? "" : "s")
                    color: "#888888"
                    font.pixelSize: 11
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
                        onClicked: panel.visible = false
                    }
                }
            }
        }

        // ── Tag input with autocomplete ──────────────────────────────────────
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
                            panel.applyFilter()
                            panel.dropdownVisible = true
                        }
                        onActiveFocusChanged: {
                            if (activeFocus) {
                                panel.rebuildTagList()
                                panel.dropdownVisible = true
                            }
                        }
                        Keys.onEscapePressed: {
                            panel.dropdownVisible = false
                            tagInput.focus = false
                        }
                        Keys.onReturnPressed: {
                            if (panel.filteredTags.length > 0) {
                                var t = panel.filteredTags[0]
                                panel.selectTag(t.id, t.name)
                            }
                        }
                    }

                    Rectangle {
                        width: 18; height: 18; radius: 9
                        visible: tagInput.text.length > 0 || panel.selectedTagId > 0
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
                            onClicked: panel.clearTag()
                        }
                    }
                }

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

        // ── Autocomplete dropdown ────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: panel.dropdownVisible && panel.filteredTags.length > 0
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
                model: panel.filteredTags
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
                        onClicked: panel.selectTag(modelData.id, modelData.name)
                    }
                }
            }
        }

        // ── Thin separator ───────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#333333"
        }

        // ── Content: thumbnail grid + drop overlay ───────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: panel.dropdownVisible = false
            }

            // ── Thumbnail GridView with reorder support ──────────────────────
            GridView {
                id: photoGrid
                anchors.fill: parent
                anchors.margins: 4
                model: panel.tagPhotoIds
                clip: true

                readonly property real _cellSize: Math.max(60, Math.floor((width - 6) / 3))
                cellWidth:  _cellSize + 2
                cellHeight: _cellSize + 2

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                // ── Reorder insert-position indicator ────────────────────────
                // Drawn on top of everything, shown as a bright horizontal line
                // between rows or vertical line between cells.
                Rectangle {
                    id: insertIndicator
                    visible: panel.reorderInsertIndex >= 0 && panel.reorderingPhotoId > 0
                    color: root.accentColor
                    z: 30
                    radius: 2

                    // Compute position from insert index
                    readonly property int _cols: Math.max(1, Math.floor(photoGrid.width / photoGrid.cellWidth))
                    readonly property int _idx:  Math.max(0, Math.min(panel.reorderInsertIndex, panel.tagPhotoIds.length))
                    readonly property int _row:  Math.floor(_idx / _cols)
                    readonly property int _col:  _idx % _cols
                    readonly property bool _atRowEnd: _col === 0 && _idx > 0

                    // Horizontal bar between rows when at start of a new row,
                    // vertical bar between cells otherwise.
                    readonly property bool _showHoriz: _atRowEnd || _idx === panel.tagPhotoIds.length

                    x: _showHoriz ? 4
                                  : _col * photoGrid.cellWidth + 4 - photoGrid.contentX
                    y: _showHoriz ? _row * photoGrid.cellHeight + 2 - photoGrid.contentY
                                  : _row * photoGrid.cellHeight + 4 - photoGrid.contentY

                    width:  _showHoriz ? photoGrid.width - 8 : 3
                    height: _showHoriz ? 3 : photoGrid.cellHeight - 8
                }

                delegate: Item {
                    id: cellDelegate
                    required property var modelData
                    required property int index

                    width:  photoGrid.cellWidth
                    height: photoGrid.cellHeight

                    readonly property bool isSelected:
                        panel.selectedPanelIds.indexOf(modelData) >= 0
                    readonly property bool isBeingDragged:
                        panel.reorderingPhotoId === modelData

                    // Fade out the cell being dragged so the indicator stands out
                    opacity: isBeingDragged ? 0.35 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 80 } }

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

                        // Selection highlight
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: root.accentColor
                            border.width: isSelected ? 3 : 0
                            z: 2
                        }

                        // Dim unselected cells when selection exists
                        Rectangle {
                            anchors.fill: parent
                            color: "#60000000"
                            visible: panel.selectedPanelIds.length > 0 && !isSelected
                            z: 1
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            z: 3
                            onClicked: function(mouse) {
                                panel.handlePanelCellClick(modelData, mouse.modifiers)
                            }
                        }

                        // ── Drag handler ─────────────────────────────────────
                        // Used both for cross-panel drag AND for reorder within panel.
                        // Reorder is detected in Main.qml by checking if source and
                        // destination panel are the same object.
                        DragHandler {
                            id: cellDragHandler
                            target: null

                            onActiveChanged: {
                                if (active) {
                                    panel.draggingPhotoId = modelData
                                    panel.reorderingPhotoId = modelData
                                    panel.reorderInsertIndex = index
                                } else {
                                    if (panel.draggingPhotoId === modelData)
                                        panel.draggingPhotoId = -1
                                    panel.reorderingPhotoId  = -1
                                    panel.reorderInsertIndex = -1
                                }
                            }
                            onCentroidChanged: {
                                if (active) {
                                    panel.dragScenePos = centroid.scenePosition
                                    // Update insert indicator position based on pointer
                                    panel.updateReorderIndex(centroid.position)
                                }
                            }
                        }
                    }
                }
            }

            // ── Drop zone overlay (shown during cross-panel drag) ────────────
            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                z: 20
                radius: 8
                visible: panel.dragOver
                color: panel.selectedTagId > 0 ? "#25ffffff" : "#15ffffff"
                border.color: panel.selectedTagId > 0 ? root.accentColor : "#666666"
                border.width: 2

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: panel.selectedTagId > 0 ? "\u25BC" : "\u2715"
                        color: panel.selectedTagId > 0 ? root.accentColor : "#cc4444"
                        font.pixelSize: 28
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: panel.selectedTagId > 0
                              ? "Tag \"" + panel.selectedTagName + "\"\nhinzufügen"
                              : "Tag entfernen"
                        color: panel.selectedTagId > 0 ? "#ffffff" : "#ff8888"
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // ── Empty state — no tag selected ────────────────────────────────
            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: panel.selectedTagId <= 0 && !panel.dragOver

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

            // ── Empty state — tag selected but no photos ─────────────────────
            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: panel.selectedTagId > 0 &&
                         panel.tagPhotoIds.length === 0 &&
                         !panel.dragOver

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

    // ── Reorder helper ───────────────────────────────────────────────────────
    // Compute nearest insert index from a pointer position inside the GridView.
    function updateReorderIndex(localPos) {
        var cols = Math.max(1, Math.floor(photoGrid.width / photoGrid.cellWidth))
        var col  = Math.floor(localPos.x / photoGrid.cellWidth)
        var row  = Math.floor((localPos.y + photoGrid.contentY) / photoGrid.cellHeight)
        col = Math.max(0, Math.min(col, cols - 1))
        row = Math.max(0, row)
        var idx = row * cols + col
        // Snap to right side of cell if pointer is in the right half
        var cellLocalX = localPos.x - col * photoGrid.cellWidth
        if (cellLocalX > photoGrid.cellWidth / 2)
            idx = idx + 1
        reorderInsertIndex = Math.min(idx, tagPhotoIds.length)
    }

    // Apply a reorder: move photoId to insertIndex within tagPhotoIds.
    // This is purely a display order — we store it in a local sorted list.
    // (A persistent order would require a DB column; here we do in-memory reorder.)
    function applyReorder(photoId, insertIndex) {
        var arr   = tagPhotoIds.slice()
        var from  = arr.indexOf(photoId)
        if (from < 0) return
        arr.splice(from, 1)
        var to = insertIndex
        if (to > from) to--   // adjust for removed element
        to = Math.max(0, Math.min(to, arr.length))
        arr.splice(to, 0, photoId)
        tagPhotoIds = arr
        reorderInsertIndex = -1
        reorderingPhotoId  = -1
    }
}
