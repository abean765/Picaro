import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A full-sized photo panel with toolbar, timeline and thumbnail grid.
// Two instances sit side-by-side and replace the former single main grid.
//
// Each panel maintains its own local list of photo IDs (photoIds).
//   – No tag selected  → all photos from photoModel
//   – Tag selected     → only photos carrying that tag
//
// Drag semantics (coordinated by Main.qml):
//   drop onto this panel:
//     panel has tag  → add tag to dropped photos
//     panel has no tag → remove the SOURCE panel's tag from dropped photos
//   drag from this panel → panels[other].acceptDrop / .removeDrop
//
// Reorder within this panel:
//   A DragHandler on each cell drives an in-place reorder of photoIds.
//   While dragging, a placeholder (-1) is inserted at the target index so
//   surrounding thumbnails shift to show the insertion gap.
Item {
    id: panel

    // ── Public API ──────────────────────────────────────────────────────────

    // Tag assigned to this panel (-1 = no tag)
    property int    selectedTagId:   -1
    property string selectedTagName: ""

    // photoIds: the ordered list this panel displays.
    // Initialised from photoModel; can be reordered in place.
    property var photoIds: []

    // dragOver: set by the sibling panel's DragHandler while hovering here
    property bool dragOver: false

    // Outgoing drag state (read by Main.qml for the ghost)
    property int   draggingPhotoId: -1
    property point dragScenePos:    Qt.point(0, 0)

    // Reference to the other panel (set from Main.qml)
    property var siblingPanel: null

    // Expose the inner GridView so callers (e.g. DetailView) can scroll it
    readonly property GridView innerGrid: photoGrid

    // Panel-internal multi-selection (independent of main grid selection)
    property var selectedPanelIds:     []
    property int panelSelectionAnchor: -1

    // How many photos per row (driven by the size slider in this panel's toolbar)
    property int photosPerRow: 5

    // ── Public functions ────────────────────────────────────────────────────

    function acceptDrop(photoIdArr) {
        if (selectedTagId <= 0) return
        for (var i = 0; i < photoIdArr.length; i++)
            if (photoIdArr[i] > 0)
                tagModel.addTagToPhoto(photoIdArr[i], selectedTagId)
    }

    function removeDrop(photoIdArr) {
        if (selectedTagId <= 0) return
        for (var i = 0; i < photoIdArr.length; i++)
            if (photoIdArr[i] > 0)
                tagModel.removeTagFromPhoto(photoIdArr[i], selectedTagId)
    }

    function selectTag(tagId, tagName) {
        selectedTagId        = tagId
        selectedTagName      = tagName
        tagInput.text        = tagName
        dropdownVisible      = false
        selectedPanelIds     = []
        panelSelectionAnchor = -1
        reloadPhotos()
    }

    function clearTag() {
        selectedTagId        = -1
        selectedTagName      = ""
        tagInput.text        = ""
        selectedPanelIds     = []
        panelSelectionAnchor = -1
        reloadPhotos()
    }

    // Refresh photo list from model or tag
    function reloadPhotos() {
        if (selectedTagId > 0)
            photoIds = tagModel.photoIdsForTag(selectedTagId)
        else
            photoIds = photoModel.visiblePhotoIds()
        _rebuildDisplayModel()
    }

    function handlePanelCellClick(photoId, modifiers) {
        var ctrl  = (modifiers & Qt.ControlModifier) !== 0
        var shift = (modifiers & Qt.ShiftModifier)   !== 0

        if (shift && panelSelectionAnchor > 0) {
            var ids = photoIds
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
            else arr.push(photoId)
            selectedPanelIds     = arr
            panelSelectionAnchor = photoId
        } else {
            selectedPanelIds     = [photoId]
            panelSelectionAnchor = photoId
            root.selectPhoto(photoId)
            root.scrollPhotoIntoView(photoId)
        }
    }

    // ── Internal state ──────────────────────────────────────────────────────

    // displayModel: mirror of photoIds used as GridView model.
    // During drag we do NOT insert placeholders here — the DragHandler lives
    // inside each delegate; making its parent invisible would kill the handler.
    // Instead the delegate itself renders the insertion-point indicator.
    property var _displayModel: []

    // Reorder state
    property int  _dragFromIndex:   -1   // original index of the cell being dragged
    property int  _dragInsertIndex: -1   // current insertion target index

    property bool dropdownVisible: false
    property var  allTags:         []
    property var  filteredTags:    []

    function rebuildTagList() {
        allTags = tagModel.allTagsFlat()
        _applyFilter()
    }

    function _applyFilter() {
        var f = tagInput.text.trim().toLowerCase()
        filteredTags = (f === "") ? allTags
            : allTags.filter(function(t) { return t.name.toLowerCase().indexOf(f) >= 0 })
    }

    // _displayModel is always just photoIds — no placeholder insertion.
    // The insertion indicator is rendered per-delegate via _dragInsertIndex.
    function _rebuildDisplayModel() {
        _displayModel = photoIds.slice()
    }

    // Update insertion index from pointer scene position.
    // No model rebuild — delegates react to _dragInsertIndex via bindings.
    function _updateInsertIndex(scenePos) {
        var localPos = photoGrid.mapFromItem(null, scenePos.x, scenePos.y)
        var cols = Math.max(1, photosPerRow)
        var cellW = photoGrid.width / cols

        var col = Math.floor(localPos.x / cellW)
        var row = Math.floor((localPos.y + photoGrid.contentY) / cellW)
        col = Math.max(0, Math.min(col, cols - 1))
        row = Math.max(0, row)

        var rawIdx = row * cols + col
        var cellLocalX = localPos.x - col * cellW
        if (cellLocalX > cellW / 2) rawIdx++

        var newInsert = Math.max(0, Math.min(rawIdx, photoIds.length - 1))
        _dragInsertIndex = newInsert
    }

    // Finalise reorder: apply the pending move to photoIds
    function _applyReorder() {
        if (_dragFromIndex < 0 || _dragInsertIndex < 0) return
        var dragId = photoIds[_dragFromIndex]
        var arr    = photoIds.slice()
        arr.splice(_dragFromIndex, 1)
        var to = Math.max(0, Math.min(_dragInsertIndex, arr.length))
        arr.splice(to, 0, dragId)
        _dragFromIndex   = -1
        _dragInsertIndex = -1
        photoIds         = arr
        _rebuildDisplayModel()
    }

    // Reload when the underlying model changes
    Connections {
        target: photoModel
        function onModelReloaded() { panel.reloadPhotos() }
    }
    Connections {
        target: tagModel
        function onTagsChanged() {
            panel.rebuildTagList()
            panel.reloadPhotos()
        }
    }

    Component.onCompleted: {
        rebuildTagList()
        reloadPhotos()
    }

    // ── Layout ──────────────────────────────────────────────────────────────

    // Dark background
    Rectangle { anchors.fill: parent; color: "#1a1a1a" }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ────────────────────────────────────────────────────────────────────
        // Toolbar
        // ────────────────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            color: "#2d2d2d"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                // Tag chip / selector ----------------------------------------
                Item {
                    id: tagSelectorItem
                    implicitWidth: tagSelectorRow.implicitWidth
                    implicitHeight: 28

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: panel.selectedTagId > 0
                               ? Qt.rgba(0,0,0,0)
                               : tagSelectorHover.containsMouse ? "#3a3a3a" : "#2a2a2a"
                        border.color: panel.selectedTagId > 0
                                      ? tagModel.tagColor(panel.selectedTagId)
                                      : "#555555"
                        border.width: 1

                        RowLayout {
                            id: tagSelectorRow
                            anchors.centerIn: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 5
                            // extra margins via left/right padding from outer item
                            Item { width: 4 }

                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: panel.selectedTagId > 0
                                       ? tagModel.tagColor(panel.selectedTagId)
                                       : "#666666"
                            }

                            Label {
                                text: panel.selectedTagId > 0
                                      ? panel.selectedTagName
                                      : "Tag wählen…"
                                color: panel.selectedTagId > 0 ? "#ffffff" : "#888888"
                                font.pixelSize: 12
                                font.bold: panel.selectedTagId > 0
                            }

                            Label {
                                visible: panel.selectedTagId > 0
                                text: "(" + panel.photoIds.length + ")"
                                color: "#aaaaaa"
                                font.pixelSize: 11
                            }

                            // Clear button
                            Rectangle {
                                visible: panel.selectedTagId > 0
                                width: 14; height: 14; radius: 7
                                color: clearTagHover.containsMouse ? "#666666" : "transparent"
                                Label {
                                    anchors.centerIn: parent
                                    text: "\u2715"
                                    color: "#aaaaaa"
                                    font.pixelSize: 9
                                }
                                MouseArea {
                                    id: clearTagHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { mouse.accepted = true; panel.clearTag() }
                                }
                            }

                            Item { width: 4 }
                        }
                    }

                    MouseArea {
                        id: tagSelectorHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            panel.rebuildTagList()
                            panel.dropdownVisible = !panel.dropdownVisible
                            if (panel.dropdownVisible) tagInput.forceActiveFocus()
                        }
                    }
                }

                // Invisible text input drives the autocomplete filter
                TextInput {
                    id: tagInput
                    visible: false
                    onTextChanged: { panel._applyFilter(); panel.dropdownVisible = true }
                    Keys.onEscapePressed: { panel.dropdownVisible = false; focus = false }
                    Keys.onReturnPressed: {
                        if (panel.filteredTags.length > 0) {
                            var t = panel.filteredTags[0]
                            panel.selectTag(t.id, t.name)
                        }
                    }
                }

                // Photo count
                Label {
                    text: panel.photoIds.length + " Fotos"
                    color: "#777777"
                    font.pixelSize: 11
                }

                Item { Layout.fillWidth: true }

                // Fit/Fill toggle
                Rectangle {
                    width: fitLabel.implicitWidth + 16
                    height: 26
                    radius: 4
                    color: fitToggle._fitMode ? "#555555" : "#3a3a3a"

                    Label {
                        id: fitLabel
                        anchors.centerIn: parent
                        text: fitToggle._fitMode ? "\u25A1 Ganz" : "\u25A0 Füllen"
                        color: fitToggle._fitMode ? "#ffffff" : "#aaaaaa"
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fitToggle._fitMode = !fitToggle._fitMode
                    }
                }

                // Size slider
                Label { text: "Größe"; color: "#aaaaaa"; font.pixelSize: 11 }
                Slider {
                    id: panelSizeSlider
                    from: 3; to: 12; value: 5; stepSize: 1
                    implicitWidth: 90
                    onValueChanged: panel.photosPerRow = Math.round(from + to - value)
                }

                // Close panel button
                Rectangle {
                    width: 24; height: 24; radius: 12
                    color: closePanelHover.containsMouse ? "#555555" : "transparent"
                    Label {
                        anchors.centerIn: parent
                        text: "\u2715"; color: "#888888"; font.pixelSize: 11
                    }
                    MouseArea {
                        id: closePanelHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.visible = false
                    }
                }
            }
        }

        // Tag autocomplete dropdown ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: Math.min(tagDropList.contentHeight + 8, 200)
            visible: panel.dropdownVisible && panel.filteredTags.length > 0
            color: "#262626"
            border.color: "#444444"
            border.width: 1
            clip: true
            z: 20

            ListView {
                id: tagDropList
                anchors.fill: parent
                anchors.margins: 4
                model: panel.filteredTags
                clip: true

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 30
                    radius: 4
                    color: tagDropHover.containsMouse ? "#3a3a3a" : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8 + modelData.depth * 12
                        anchors.rightMargin: 8
                        spacing: 6

                        Rectangle { width: 10; height: 10; radius: 5; color: modelData.color }
                        Label {
                            text: modelData.icon; font.pixelSize: 12
                            visible: text !== ""
                        }
                        Label {
                            text: modelData.name
                            color: "#dddddd"; font.pixelSize: 12
                            font.bold: modelData.depth === 0
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Label {
                            text: modelData.photoCount + " Fotos"
                            color: "#777777"; font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        id: tagDropHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.selectTag(modelData.id, modelData.name)
                    }
                }
            }
        }

        // ────────────────────────────────────────────────────────────────────
        // Timeline + Grid
        // ────────────────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Close dropdown when clicking content area
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: panel.dropdownVisible = false
            }

            // Mini timeline sidebar ─────────────────────────────────────────
            // Shows months derived from the panel's own photoIds
            Rectangle {
                id: miniTimeline
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 70
                color: "#1e1e1e"
                clip: true

                // Build month groups from photoIds
                property var monthGroups: []

                function rebuildMonths() {
                    if (photoIds.length === 0) { monthGroups = []; return }
                    var groups = []
                    var current = null
                    for (var i = 0; i < photoIds.length; i++) {
                        var id = photoIds[i]
                        if (id < 0) continue
                        var mk = photoModel.monthKeyForId(id)
                        if (!mk || mk === "") continue
                        if (!current || current.key !== mk) {
                            current = { key: mk, label: _monthLabel(mk), year: parseInt(mk.split("-")[0]), count: 0, firstIdx: i }
                            groups.push(current)
                        }
                        current.count++
                    }
                    monthGroups = groups
                }

                function _monthLabel(mk) {
                    var parts = mk.split("-")
                    var month = parseInt(parts[1])
                    var names = ["Jan","Feb","Mär","Apr","Mai","Jun","Jul","Aug","Sep","Okt","Nov","Dez"]
                    return names[month - 1] || mk
                }

                property int activeMonth: -1

                ListView {
                    id: monthList
                    anchors.fill: parent
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    clip: true
                    model: miniTimeline.monthGroups
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: monthList.width
                        height: showYear ? 50 : 28

                        readonly property bool showYear:
                            index === 0 ||
                            miniTimeline.monthGroups[index - 1].year !== modelData.year
                        readonly property bool isActive: miniTimeline.activeMonth === index

                        // Year label
                        Label {
                            visible: showYear
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.year
                            color: "#777777"
                            font.pixelSize: 11
                            font.bold: true
                        }

                        // Month row
                        Item {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 24

                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 2
                                anchors.rightMargin: 2
                                radius: 3
                                color: isActive
                                       ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25)
                                       : monthHover.containsMouse ? "#282828" : "transparent"
                            }

                            Rectangle {
                                id: dot
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: isActive ? 7 : 5; height: width; radius: width/2
                                color: isActive ? root.accentColor : "#555555"
                            }

                            Label {
                                anchors.left: dot.right
                                anchors.leftMargin: 5
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: isActive ? root.accentColor : "#999999"
                                font.pixelSize: 11
                                font.bold: isActive
                            }

                            MouseArea {
                                id: monthHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    // Scroll grid to the first photo of this month
                                    var firstIdx = modelData.firstIdx
                                    var cols     = Math.max(1, panel.photosPerRow)
                                    var row      = Math.floor(firstIdx / cols)
                                    var cellH    = photoGrid.width / cols
                                    photoGrid.contentY = Math.max(0, row * cellH - 20)
                                }
                            }
                        }
                    }

                    WheelHandler {
                        target: monthList
                        property: "contentY"
                        rotationScale: -1.0
                    }
                }

                // Rebuild when photoIds change
                onVisibleChanged: if (visible) rebuildMonths()
                Connections {
                    target: panel
                    function onPhotoIdsChanged() { Qt.callLater(miniTimeline.rebuildMonths) }
                }
            }

            // Left separator
            Rectangle {
                anchors.left: miniTimeline.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: "#2a2a2a"
            }

            // Photo grid ────────────────────────────────────────────────────
            GridView {
                id: photoGrid
                anchors.left: miniTimeline.right
                anchors.leftMargin: 1
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                clip: true
                model: panel._displayModel
                interactive: false   // WheelHandler handles scrolling; keep mouse events for DragHandler

                readonly property real _cellSize: Math.max(50, Math.floor((width - 2) / panel.photosPerRow))
                cellWidth:  _cellSize
                cellHeight: _cellSize

                // Update timeline active month based on scroll position
                onContentYChanged: {
                    var cols = Math.max(1, panel.photosPerRow)
                    var cellH = _cellSize
                    var topIdx = Math.floor(contentY / cellH) * cols
                    if (topIdx < 0 || topIdx >= panel._displayModel.length) return
                    var topId = panel._displayModel[topIdx]
                    if (topId <= 0) return
                    var mk = photoModel.monthKeyForId(topId)
                    for (var i = 0; i < miniTimeline.monthGroups.length; i++) {
                        if (miniTimeline.monthGroups[i].key === mk) {
                            miniTimeline.activeMonth = i
                            break
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 18
                        radius: 9
                        color: parent.pressed ? Qt.lighter(root.accentColor, 1.2)
                             : parent.hovered ? root.accentColor
                             : Qt.darker(root.accentColor, 1.4)
                    }
                    background: Rectangle {
                        implicitWidth: 28
                        color: parent.hovered ? "#1affffff" : "transparent"
                        radius: 14
                    }
                }

                WheelHandler {
                    target: photoGrid
                    property: "contentY"
                    rotationScale: -3.0
                }

                delegate: Item {
                    id: cellDelegate
                    required property var modelData
                    required property int index

                    width:  photoGrid._cellSize
                    height: photoGrid._cellSize

                    readonly property bool isSelected:
                        panel.selectedPanelIds.indexOf(modelData) >= 0
                    readonly property bool isDragging:
                        modelData === panel.draggingPhotoId

                    // Photo thumbnail
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        color: "#2a2a2a"
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: "image://thumbnail/" + modelData
                            fillMode: fitToggle._fitMode
                                      ? Image.PreserveAspectFit
                                      : Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            opacity: status === Image.Ready ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                        }

                        // Black background for fit mode
                        Rectangle {
                            anchors.fill: parent
                            color: "#000000"
                            visible: fitToggle._fitMode
                            z: -1
                        }

                        // Selection border
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: root.accentColor
                            border.width: isSelected ? 3 : 0
                            z: 2
                        }

                        // Dim unselected when multi-selection is active
                        Rectangle {
                            anchors.fill: parent
                            color: "#60000000"
                            visible: panel.selectedPanelIds.length > 0 && !isSelected
                            z: 1
                        }

                        // Dim the item that is currently being dragged
                        Rectangle {
                            anchors.fill: parent
                            color: "#88000000"
                            visible: isDragging
                            z: 4
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
                        // NOTE: kept inside the always-visible Rectangle so it
                        // is never disabled by a visibility change on a parent.
                        DragHandler {
                            id: cellDragHandler
                            target: null

                            onActiveChanged: {
                                if (active) {
                                    // Set position FIRST so ghost appears at cursor
                                    panel.dragScenePos    = centroid.scenePosition
                                    panel.draggingPhotoId = modelData
                                    panel._dragFromIndex  = panel.photoIds.indexOf(modelData)
                                    panel._dragInsertIndex = panel._dragFromIndex
                                    // No _rebuildDisplayModel() here — that would reassign
                                    // _displayModel and cause GridView to recreate this
                                    // delegate, killing the active DragHandler.
                                } else {
                                    if (panel.draggingPhotoId !== modelData) return

                                    var sibling = panel.siblingPanel

                                    // Check if released over the sibling panel
                                    if (sibling && sibling.visible) {
                                        var fp  = centroid.scenePosition
                                        var sp  = sibling.mapFromItem(null, fp.x, fp.y)
                                        var hit = (sp.x >= 0 && sp.y >= 0
                                                   && sp.x < sibling.width
                                                   && sp.y < sibling.height)
                                        if (hit) {
                                            // ── Cross-panel drop ──────────────
                                            var sel    = panel.selectedPanelIds
                                            var toMove = (sel.length > 1 && sel.indexOf(modelData) >= 0)
                                                         ? sel : [modelData]

                                            if (sibling.selectedTagId > 0)
                                                sibling.acceptDrop(toMove)
                                            else if (panel.selectedTagId > 0)
                                                panel.removeDrop(toMove)

                                            panel._dragFromIndex   = -1
                                            panel._dragInsertIndex = -1
                                            panel.draggingPhotoId  = -1
                                            sibling.dragOver       = false
                                            return
                                        }
                                    }

                                    // ── Same-panel: apply reorder ─────────────
                                    panel.draggingPhotoId = -1
                                    if (panel._dragFromIndex >= 0)
                                        panel._applyReorder()
                                }
                            }

                            onCentroidChanged: {
                                if (!active) return
                                panel.dragScenePos = centroid.scenePosition

                                var sibling = panel.siblingPanel
                                var overSibling = false
                                if (sibling && sibling.visible) {
                                    var cp = sibling.mapFromItem(null,
                                                centroid.scenePosition.x,
                                                centroid.scenePosition.y)
                                    overSibling = (cp.x >= 0 && cp.y >= 0
                                                   && cp.x < sibling.width
                                                   && cp.y < sibling.height)

                                    if (overSibling !== sibling.dragOver) {
                                        sibling.dragOver = overSibling
                                        if (overSibling)
                                            panel._dragInsertIndex = -1
                                    }
                                }

                                if (!overSibling)
                                    panel._updateInsertIndex(centroid.scenePosition)
                            }
                        }
                    }

                    // ── Insertion-point indicator ─────────────────────────────
                    // Shown on the cell where the dragged item would land.
                    // Uses a left-edge bar (before this cell) or right-edge bar
                    // (after last cell). No model rebuild needed.
                    Rectangle {
                        anchors.top:    parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin:    3
                        anchors.bottomMargin: 3
                        width: 3
                        radius: 2
                        color: root.accentColor
                        visible: panel._dragFromIndex >= 0
                                 && panel._dragInsertIndex === index
                                 && !isDragging
                        x: 0
                        z: 20
                    }
                }
            }

            // ── Drop zone overlay (shown while an external drag hovers) ──────
            Rectangle {
                anchors.fill: photoGrid
                z: 30
                visible: panel.dragOver
                radius: 6
                color: panel.selectedTagId > 0 ? "#20ffffff" : "#15ffffff"
                border.color: panel.selectedTagId > 0 ? root.accentColor : "#cc4444"
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

            // Empty state
            Column {
                anchors.centerIn: photoGrid
                spacing: 12
                visible: panel.photoIds.length === 0 && !panel.dragOver

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: panel.selectedTagId > 0 ? "Keine Fotos\nmit diesem Tag"
                                                  : "Keine Fotos"
                    color: "#555555"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Fotos per Drag & Drop\nhierhier ziehen"
                    color: "#3a3a3a"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // Reference to the fit-toggle to share with cell delegates
    Item {
        id: fitToggle
        visible: false
        property bool _fitMode: false
    }
}
