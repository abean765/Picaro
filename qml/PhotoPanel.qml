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

    // Tracks which tag context the current photoIds belongs to.
    // -2 = never loaded; used to detect context switches in reloadPhotos().
    property int _loadedTagId: -2

    // dragOver: set by another panel's DragHandler while hovering here
    property bool dragOver: false

    // Outgoing drag state (read by Main.qml for the ghost)
    property int   draggingPhotoId: -1
    property point dragScenePos:    Qt.point(0, 0)

    // Repeater containing all panels — used to find drop targets and for drag highlighting
    // Named 'allPanels' (not 'panelsRepeater') to avoid shadowing the Repeater id in Main.qml
    property var allPanels: null

    // ListModel keeping per-panel tag state — passed from Main.qml so we can
    // react to sibling panels' tag changes without complex cross-panel bindings.
    property var panelsListModel: null

    // Maps "photoId" -> array of tag-color strings for every sibling tag the
    // photo already carries.  Only populated when this panel has no tag.
    property var _siblingTagPhotoColors: ({})

    function _refreshSiblingTags() {
        if (!panelsListModel || selectedTagId > 0) {
            _siblingTagPhotoColors = {}
            return
        }
        var result = {}
        for (var i = 0; i < panelsListModel.count; i++) {
            var m = panelsListModel.get(i)
            if (m.tagId <= 0) continue
            var color = tagModel.tagColor(m.tagId)
            var ids   = tagModel.photoIdsForTag(m.tagId)
            for (var j = 0; j < ids.length; j++) {
                var key = "" + ids[j]
                if (!result[key]) result[key] = []
                result[key].push(color)
            }
        }
        _siblingTagPhotoColors = result
    }

    Connections {
        target: panel.panelsListModel
        function onDataChanged()  { panel._refreshSiblingTags() }
        function onRowsInserted() { panel._refreshSiblingTags() }
        function onRowsRemoved()  { panel._refreshSiblingTags() }
        function onModelReset()   { panel._refreshSiblingTags() }
    }

    Connections {
        target: tagModel
        function onTagsChanged() { panel._refreshSiblingTags() }
    }

    onSelectedTagIdChanged: _refreshSiblingTags()
    onPanelsListModelChanged: _refreshSiblingTags()

    // Show a 1 px left divider (set true for every panel after the first)
    property bool showLeftDivider: false

    // Fit/fill mode for thumbnails (false = fill/crop, true = fit/letterbox)
    property bool fitMode: false

    // Expose the inner GridView so callers (e.g. DetailView) can scroll it
    readonly property GridView innerGrid: photoGrid

    // Panel-internal multi-selection (independent of main grid selection)
    property var selectedPanelIds:     []
    property int panelSelectionAnchor: -1

    // How many photos per row (driven by the size slider in this panel's toolbar)
    property int photosPerRow: 10

    // Active month key currently shown at top of timeline (e.g. "2024-07")
    readonly property string activeTimelineMonthKey:
        (miniTimeline.activeMonth >= 0
         && miniTimeline.activeMonth < miniTimeline.monthGroups.length)
        ? miniTimeline.monthGroups[miniTimeline.activeMonth].key
        : ""

    // Emitted when the user clicks the close button
    signal closeRequested()

    // Scroll to the first photo belonging to the given month key
    function scrollToMonthKey(mk) {
        if (!mk || mk === "") return
        for (var i = 0; i < miniTimeline.monthGroups.length; i++) {
            var g = miniTimeline.monthGroups[i]
            if (g.key === mk) {
                var cols = Math.max(1, photosPerRow)
                var row  = Math.floor(g.firstIdx / cols)
                var cellH = photoGrid.width / cols
                photoGrid.contentY = Math.max(0, row * cellH - 20)
                return
            }
        }
    }

    // Set photosPerRow and sync the slider
    function setPhotosPerRow(n) {
        photosPerRow = n
        panelSizeSlider.value = panelSizeSlider.from + panelSizeSlider.to - n
    }

    // ── Internal: find which other panel (if any) is under scenePos ──────────
    function _findDropTarget(scenePos) {
        if (!allPanels) return null
        for (var i = 0; i < allPanels.count; i++) {
            var p = allPanels.itemAt(i)
            if (!p || p === panel) continue
            var local = p.mapFromItem(null, scenePos.x, scenePos.y)
            if (local.x >= 0 && local.y >= 0 && local.x < p.width && local.y < p.height)
                return p
        }
        return null
    }

    // ── Public functions ────────────────────────────────────────────────────

    function acceptDrop(photoIdArr) {
        if (selectedTagId <= 0) return
        var validIds = photoIdArr.filter(function(id) { return id > 0 })
        if (validIds.length > 0)
            tagModel.batchAddTagToPhotos(validIds, selectedTagId)
    }

    function removeDrop(photoIdArr) {
        if (selectedTagId <= 0) return
        var validIds = photoIdArr.filter(function(id) { return id > 0 })
        if (validIds.length > 0)
            tagModel.batchRemoveTagFromPhotos(validIds, selectedTagId)
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
        dropdownVisible      = false
        selectedPanelIds     = []
        panelSelectionAnchor = -1
        reloadPhotos()
    }

    // Refresh photo list from model or tag.
    // If the context (tag) changed, the new list is adopted as-is.
    // Within the same context, the current in-memory order is preserved:
    // existing IDs keep their position, removed IDs are dropped,
    // newly added IDs are appended at the end.
    function reloadPhotos() {
        var newIds
        if (selectedTagId > 0)
            newIds = tagModel.photoIdsForTag(selectedTagId)
        else
            newIds = photoModel.visiblePhotoIds()

        if (selectedTagId !== _loadedTagId) {
            // Context switch: adopt the new list without any order carry-over
            _loadedTagId = selectedTagId
            photoIds = newIds
            _rebuildDisplayModel(true)
            return
        }

        // Same context: preserve in-memory order, just add/remove IDs
        // Build a fast lookup set for the new IDs
        var newSet = {}
        for (var i = 0; i < newIds.length; i++) newSet[newIds[i]] = true

        // Keep existing IDs that are still valid, in their current order
        var kept = photoIds.filter(function(id) { return newSet[id] === true })

        // Append IDs that are new (not yet in the current list)
        var keptSet = {}
        for (var j = 0; j < kept.length; j++) keptSet[kept[j]] = true
        var added = newIds.filter(function(id) { return keptSet[id] !== true })

        var newPhotoIds = kept.concat(added)
        var same = (newPhotoIds.length === photoIds.length)
        if (same) {
            for (var k = 0; k < newPhotoIds.length; k++) {
                if (newPhotoIds[k] !== photoIds[k]) { same = false; break }
            }
        }
        if (!same) {
            photoIds = newPhotoIds
            _rebuildDisplayModel()
        }
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
    property int  _dropCount:        0   // how many photos are being dragged onto this panel
    property real _savedScrollY:    -1   // scroll position to restore after model rebuild

    property bool dropdownVisible:    false
    property var  allTags:            []
    property var  filteredTags:       []
    property int  _tagHighlightIndex: -1

    function rebuildTagList() {
        allTags = tagModel.allTagsFlat()
        _applyFilter()
    }

    function _applyFilter() {
        var f = tagInput.text.trim().toLowerCase()
        filteredTags = (f === "") ? allTags
            : allTags.filter(function(t) { return t.name.toLowerCase().indexOf(f) >= 0 })
        _tagHighlightIndex = -1
    }

    // _displayModel is normally just photoIds.
    // During a cross-panel drag over a tagged panel it also contains _dropCount
    // placeholder items (-1) at _dragInsertIndex so GridView shows the gap directly.
    function _restoreScrollY() {
        if (_savedScrollY < 0) return
        var maxY = Math.max(0, photoGrid.contentHeight + photoGrid.bottomMargin - photoGrid.height)
        photoGrid.contentY = Math.max(0, Math.min(_savedScrollY, maxY))
        _savedScrollY = -1
    }

    function _rebuildDisplayModel(resetScroll) {
        if (resetScroll) {
            _savedScrollY = -1
        } else if (_savedScrollY < 0) {
            // Only capture on the first call; subsequent calls in the same
            // event loop iteration must not overwrite with the already-reset 0.
            _savedScrollY = photoGrid.contentY
        }
        _displayModel = photoIds.slice()
        Qt.callLater(_restoreScrollY)
    }

    // Update insertion index from pointer scene position.
    // Uses GridView.indexAt() to let Qt determine which cell the cursor is over,
    // instead of error-prone manual row/column arithmetic.
    function _updateInsertIndex(scenePos) {
        var localPos = photoGrid.mapFromItem(null, scenePos.x, scenePos.y)
        var contentX = localPos.x
        var contentY = localPos.y + photoGrid.contentY
        var D = photoGrid.indexAt(contentX, contentY)

        // indexAt returns -1 when the cursor is outside/below all cells;
        // in that case, snap to the last position.
        if (D < 0) D = photoIds.length

        var newInsert = Math.max(0, Math.min(D, photoIds.length))
        if (newInsert === _dragInsertIndex) return
        _dragInsertIndex = newInsert
    }

    // Finalise reorder: apply the pending move to photoIds
    function _applyReorder() {
        var from = _dragFromIndex
        var to   = _dragInsertIndex
        _dragFromIndex   = -1
        _dragInsertIndex = -1
        if (from < 0 || to < 0) return
        var dragId = photoIds[from]
        var arr = photoIds.slice()
        arr.splice(from, 1)
        // When moving forward, removing 'from' shifts everything after it left by 1,
        // so the target position must be adjusted accordingly.
        var ins = Math.max(0, Math.min(to > from ? to - 1 : to, arr.length))
        arr.splice(ins, 0, dragId)
        photoIds = arr
        _rebuildDisplayModel()
        if (selectedTagId > 0)
            tagModel.saveTagPhotoOrder(selectedTagId, photoIds)
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
        _refreshSiblingTags()
    }

    // ── Layout ──────────────────────────────────────────────────────────────

    // Dark background
    Rectangle { anchors.fill: parent; color: "#1a1a1a" }

    // Left divider shown between panels
    Rectangle {
        visible: panel.showLeftDivider
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: "#333333"
        z: 5
    }

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

                            // When dropdown is open and no tag is selected, show
                            // an editable text field; otherwise show a static label.
                            Label {
                                visible: panel.selectedTagId > 0
                                         || !panel.dropdownVisible
                                text: panel.selectedTagId > 0
                                      ? panel.selectedTagName
                                      : "Tag wählen…"
                                color: panel.selectedTagId > 0 ? "#ffffff" : "#888888"
                                font.pixelSize: 12
                                font.bold: panel.selectedTagId > 0
                            }

                            TextInput {
                                id: tagInput
                                visible: panel.dropdownVisible
                                         && panel.selectedTagId <= 0
                                width: visible ? Math.max(80, implicitWidth + 4) : 0
                                color: "#ffffff"
                                font.pixelSize: 12
                                clip: true
                                onTextChanged: { panel._applyFilter(); panel.dropdownVisible = true }
                                Keys.onEscapePressed: { panel.dropdownVisible = false; focus = false }
                                Keys.onReturnPressed: {
                                    var idx = panel._tagHighlightIndex >= 0
                                              ? panel._tagHighlightIndex : 0
                                    if (idx < panel.filteredTags.length) {
                                        var t = panel.filteredTags[idx]
                                        panel.selectTag(t.id, t.name)
                                    }
                                }
                                Keys.onDownPressed: {
                                    if (panel.filteredTags.length === 0) return
                                    panel._tagHighlightIndex = Math.min(
                                        panel._tagHighlightIndex + 1,
                                        panel.filteredTags.length - 1)
                                    tagDropList.positionViewAtIndex(
                                        panel._tagHighlightIndex, ListView.Contain)
                                }
                                Keys.onUpPressed: {
                                    if (panel.filteredTags.length === 0) return
                                    panel._tagHighlightIndex = Math.max(
                                        panel._tagHighlightIndex - 1, 0)
                                    tagDropList.positionViewAtIndex(
                                        panel._tagHighlightIndex, ListView.Contain)
                                }
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
                        onClicked: function(mouse) {
                            // containsMouse on clearTagHover is unreliable because
                            // this MouseArea sits on top and intercepts hover events.
                            // Use explicit position mapping instead.
                            if (panel.selectedTagId > 0) {
                                var p = mapToItem(clearTagHover, mouse.x, mouse.y)
                                if (p.x >= 0 && p.x < clearTagHover.width
                                        && p.y >= 0 && p.y < clearTagHover.height) {
                                    panel.clearTag()
                                    return
                                }
                            }
                            panel.rebuildTagList()
                            panel.dropdownVisible = !panel.dropdownVisible
                            if (panel.dropdownVisible) {
                                tagInput.text = ""
                                tagInput.forceActiveFocus()
                            }
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
                    color: panel.fitMode ? "#555555" : "#3a3a3a"

                    Label {
                        id: fitLabel
                        anchors.centerIn: parent
                        text: panel.fitMode ? "\u25A1 Ganz" : "\u25A0 Füllen"
                        color: panel.fitMode ? "#ffffff" : "#aaaaaa"
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.fitMode = !panel.fitMode
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
                        onClicked: panel.closeRequested()
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
                    required property var  modelData
                    required property int  index
                    width: ListView.view.width
                    height: 30
                    radius: 4
                    color: tagDropHover.containsMouse || panel._tagHighlightIndex === index
                           ? "#3a3a3a" : "transparent"

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

            // Timeline + Scrollbar (right side) ────────────────────────────────
            // Replaces the former left mini-timeline and the built-in ScrollBar.
            // The draggable handle scrolls the photo grid; the month list scrolls
            // automatically when the handle is dragged near the top/bottom edge.
            Item {
                id: miniTimeline
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 72

                // ── Data (unchanged API) ─────────────────────────────────────
                property var monthGroups: []
                property int activeMonth: -1

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
                    // Sync active month to current scroll position after rebuild
                    var cols2 = Math.max(1, panel.photosPerRow)
                    var topIdx2 = Math.floor(photoGrid.contentY / photoGrid._cellSize) * cols2
                    activeMonth = -1
                    if (topIdx2 >= 0 && topIdx2 < panel._displayModel.length) {
                        var topId2 = panel._displayModel[topIdx2]
                        if (topId2 > 0) {
                            var mk2 = photoModel.monthKeyForId(topId2)
                            for (var m = 0; m < groups.length; m++) {
                                if (groups[m].key === mk2) { activeMonth = m; break }
                            }
                        }
                    }
                    if (activeMonth < 0 && groups.length > 0) activeMonth = 0
                }

                function _monthLabel(mk) {
                    var parts = mk.split("-")
                    var month = parseInt(parts[1])
                    var names = ["Jan","Feb","Mär","Apr","Mai","Jun","Jul","Aug","Sep","Okt","Nov","Dez"]
                    return names[month - 1] || mk
                }

                // ── Background ───────────────────────────────────────────────
                Rectangle { anchors.fill: parent; color: "#1e1e1e" }

                // Left separator line
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: "#2a2a2a"
                }

                // ── Month list ───────────────────────────────────────────────
                ListView {
                    id: monthList
                    anchors.left: parent.left
                    anchors.leftMargin: 1
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    clip: true
                    model: miniTimeline.monthGroups
                    interactive: false   // scrolling is driven by the handle / edge timer

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
                                width: isActive ? 7 : 5; height: width; radius: width / 2
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
                                    var firstIdx = modelData.firstIdx
                                    var cols     = Math.max(1, panel.photosPerRow)
                                    var row      = Math.floor(firstIdx / cols)
                                    var cellH    = photoGrid.width / cols
                                    photoGrid.contentY = Math.max(0, row * cellH - 20)
                                }
                            }
                        }
                    }
                }

                // ── Scroll handle ────────────────────────────────────────────
                // Dragging it scrolls the photo grid.
                // Independent of the month list position.
                Rectangle {
                    id: scrollHandle

                    readonly property real contentH:  Math.max(1, photoGrid.contentHeight)
                    readonly property real viewH:     photoGrid.height
                    readonly property real trackH:    miniTimeline.height
                    readonly property real fillRatio: viewH / contentH
                    readonly property real handleH:   Math.max(24, Math.min(trackH, fillRatio * trackH))
                    readonly property real maxTrackY: trackH - handleH
                    readonly property real scrollMax: Math.max(1, contentH + photoGrid.bottomMargin - viewH)

                    anchors.left:  parent.left
                    anchors.leftMargin: 3
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    height: handleH
                    y: fillRatio < 1.0 ? Math.min(maxTrackY, Math.max(0, (photoGrid.contentY / scrollMax) * maxTrackY)) : 0
                    visible: fillRatio < 1.0

                    radius: 5
                    color: handleDrag.active
                           ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                           : handleHover.containsMouse
                             ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.50)
                             : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.8)
                    border.width: 1

                    HoverHandler { id: handleHover }

                    DragHandler {
                        id: handleDrag
                        target: null
                        xAxis.enabled: false
                        yAxis.enabled: true

                        property real _startY: 0

                        onActiveChanged: {
                            if (active) _startY = scrollHandle.y
                        }

                        onTranslationChanged: {
                            var newY = Math.max(0, Math.min(scrollHandle.maxTrackY,
                                                            _startY + translation.y))
                            if (scrollHandle.maxTrackY > 0)
                                photoGrid.contentY = (newY / scrollHandle.maxTrackY)
                                                     * scrollHandle.scrollMax
                        }
                    }
                }

                // Auto-scroll the month list when the handle is dragged near the edges
                Timer {
                    id: edgeScrollTimer
                    interval: 40
                    repeat: true
                    running: handleDrag.active

                    onTriggered: {
                        var panelH  = miniTimeline.height
                        var edgePx  = Math.min(60, panelH * 0.15)
                        var maxCY   = Math.max(0, monthList.contentHeight - panelH)
                        if (maxCY <= 0) return

                        var hy = scrollHandle.y
                        var hb = hy + scrollHandle.height

                        if (hy < edgePx) {
                            monthList.contentY = Math.max(0,
                                monthList.contentY - Math.round(8 * (1.0 - hy / edgePx)))
                        } else if (hb > panelH - edgePx) {
                            monthList.contentY = Math.min(maxCY,
                                monthList.contentY + Math.round(8 * (1.0 - (panelH - hb) / edgePx)))
                        }
                    }
                }

                // ── Rebuild when photoIds change ─────────────────────────────
                onVisibleChanged: if (visible) rebuildMonths()
                Connections {
                    target: panel
                    function onPhotoIdsChanged() { Qt.callLater(miniTimeline.rebuildMonths) }
                }
            }

            // Photo grid ────────────────────────────────────────────────────
            GridView {
                id: photoGrid
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: miniTimeline.left
                clip: true
                model: panel._displayModel
                interactive: false   // WheelHandler handles scrolling; keep mouse events for DragHandler

                readonly property real _cellSize: Math.max(50, Math.floor((width - 2) / panel.photosPerRow))
                cellWidth:    _cellSize
                cellHeight:   _cellSize
                bottomMargin: _cellSize

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

                WheelHandler {
                    onWheel: function(event) {
                        var delta = event.angleDelta.y / 8 * (-3.0)
                        var maxY  = Math.max(0, photoGrid.contentHeight + photoGrid.bottomMargin - photoGrid.height)
                        photoGrid.contentY = Math.max(0, Math.min(photoGrid.contentY + delta, maxY))
                        event.accepted = true
                    }
                }

                delegate: Item {
                    id: cellDelegate
                    required property var modelData
                    required property int index

                    width:  photoGrid._cellSize
                    height: photoGrid._cellSize

                    readonly property bool isSelected:
                        modelData > 0 && panel.selectedPanelIds.indexOf(modelData) >= 0
                    readonly property bool isDragging:
                        modelData > 0 && modelData === panel.draggingPhotoId

                    // Placeholder cell shown during cross-panel drag
                    // Photo thumbnail
                    Rectangle {
                        visible: modelData > 0
                        anchors.fill: parent
                        anchors.margins: 1
                        color: "#2a2a2a"
                        clip: true
                        opacity: isDragging ? 0.35 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 80 } }

                        Image {
                            anchors.fill: parent
                            source: "image://thumbnail/" + modelData
                            fillMode: panel.fitMode
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
                            visible: panel.fitMode
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

                        // Sibling-tag dots — visible in no-tag panels to show
                        // whether this photo already belongs to a sibling panel's tag
                        Row {
                            id: siblingTagDots
                            property var tagColors: {
                                if (panel.selectedTagId > 0 || modelData <= 0) return []
                                var c = panel._siblingTagPhotoColors["" + modelData]
                                return c ? c : []
                            }
                            visible: tagColors.length > 0
                            spacing: 3
                            anchors.bottom: parent.bottom
                            anchors.left:   parent.left
                            anchors.bottomMargin: 4
                            anchors.leftMargin:   4
                            z: 4
                            Repeater {
                                model: siblingTagDots.tagColors
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: modelData
                                    border.color: Qt.rgba(0, 0, 0, 0.45)
                                    border.width: 1
                                }
                            }
                        }

                        HoverHandler { id: cellHover }

                        // X button — removes tag (tag-panel) or deletes photo (no-tag panel)
                        Rectangle {
                            visible: cellHover.hovered && !isDragging && panel._dragFromIndex < 0
                            anchors.top:    parent.top
                            anchors.right:  parent.right
                            anchors.margins: 4
                            width: 22; height: 22; radius: 11
                            color: xBtnArea.containsMouse ? "#dd3333" : "#90000000"
                            z: 5

                            Label {
                                anchors.centerIn: parent
                                text: "\u2715"
                                font.pixelSize: 11
                                color: "#ffffff"
                            }

                            MouseArea {
                                id: xBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    mouse.accepted = true
                                    if (panel.selectedTagId > 0) {
                                        tagModel.removeTagFromPhoto(modelData, panel.selectedTagId)
                                        panel.reloadPhotos()
                                    } else {
                                        photoModel.deletePhoto(modelData)
                                        panel.reloadPhotos()
                                    }
                                }
                            }
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

                                    var fp     = centroid.scenePosition
                                    var target = panel._findDropTarget(fp)

                                    if (target) {
                                        // ── Cross-panel drop ──────────────────
                                        var sel    = panel.selectedPanelIds
                                        var toMove = (sel.length > 1 && sel.indexOf(modelData) >= 0)
                                                     ? sel : [modelData]

                                        if (target.selectedTagId > 0) {
                                            // Pre-insert into target at the marker position
                                            // so that reloadPhotos() preserves the chosen order.
                                            var insertAt = Math.max(0, Math.min(
                                                target._dragInsertIndex, target.photoIds.length))
                                            var dstIds = target.photoIds.filter(
                                                function(id) { return toMove.indexOf(id) < 0 })
                                            for (var k = toMove.length - 1; k >= 0; k--)
                                                dstIds.splice(insertAt, 0, toMove[k])
                                            target.photoIds = dstIds
                                            target._rebuildDisplayModel()
                                        } else if (panel.selectedTagId > 0) {
                                            // Dropping on no-tag panel: pre-remove from source
                                            panel.photoIds = panel.photoIds.filter(
                                                function(id) { return toMove.indexOf(id) < 0 })
                                            panel._rebuildDisplayModel()
                                        }

                                        if (target.selectedTagId > 0)
                                            target.acceptDrop(toMove)
                                        else if (panel.selectedTagId > 0)
                                            panel.removeDrop(toMove)

                                        // Persist the new order on both panels
                                        if (target.selectedTagId > 0)
                                            tagModel.saveTagPhotoOrder(target.selectedTagId, target.photoIds)
                                        if (panel.selectedTagId > 0)
                                            tagModel.saveTagPhotoOrder(panel.selectedTagId, panel.photoIds)

                                        panel._dragFromIndex    = -1
                                        panel._dragInsertIndex  = -1
                                        panel.draggingPhotoId   = -1
                                        target.dragOver         = false
                                        target._dragInsertIndex = -1
                                        target._dropCount       = 0
                                        return
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

                                var hoverTarget = panel._findDropTarget(centroid.scenePosition)

                                // Update dragOver on all other panels
                                if (allPanels) {
                                    for (var pi = 0; pi < allPanels.count; pi++) {
                                        var pp = allPanels.itemAt(pi)
                                        if (!pp || pp === panel) continue
                                        var over = (pp === hoverTarget)
                                        if (over !== pp.dragOver) {
                                            pp.dragOver = over
                                            if (over) {
                                                panel._dragInsertIndex = -1
                                                var sel2 = panel.selectedPanelIds
                                                pp._dropCount = (sel2.length > 1 && sel2.indexOf(modelData) >= 0)
                                                                ? sel2.length : 1
                                            } else {
                                                pp._dragInsertIndex = -1
                                                pp._dropCount = 0
                                            }
                                        }
                                    }
                                }

                                if (hoverTarget && hoverTarget.selectedTagId > 0)
                                    hoverTarget._updateInsertIndex(centroid.scenePosition)
                                else if (!hoverTarget)
                                    panel._updateInsertIndex(centroid.scenePosition)
                            }
                        }
                    }

                    // ── Insertion-point indicator (left edge) ────────────────
                    // Shown on the cell where the dragged item would land.
                    Rectangle {
                        anchors.top:    parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin:    3
                        anchors.bottomMargin: 3
                        width: 3
                        radius: 2
                        color: root.accentColor
                        visible: (panel._dragFromIndex >= 0 || (panel.dragOver && panel.selectedTagId > 0))
                                 && panel._dragInsertIndex >= 0
                                 && panel._dragInsertIndex === index
                                 && !isDragging
                        x: 0
                        z: 20
                    }

                    // ── Insertion-point indicator (right edge, append) ───────
                    // Shown on the last cell when inserting at the very end.
                    Rectangle {
                        anchors.top:    parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin:    3
                        anchors.bottomMargin: 3
                        width: 3
                        radius: 2
                        color: root.accentColor
                        visible: (panel._dragFromIndex >= 0 || (panel.dragOver && panel.selectedTagId > 0))
                                 && panel._dragInsertIndex === panel.photoIds.length
                                 && index === panel._displayModel.length - 1
                                 && !isDragging
                        x: parent.width - 3
                        z: 20
                    }
                }
            }

            // ── Drop zone overlay (no-tag panel only: shows "remove tag") ───
            Rectangle {
                anchors.fill: photoGrid
                z: 30
                visible: panel.dragOver && panel.selectedTagId <= 0
                radius: 6
                color: "#15ffffff"
                border.color: "#cc4444"
                border.width: 2

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "\u2715"
                        color: "#cc4444"
                        font.pixelSize: 28
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Tag entfernen"
                        color: "#ff8888"
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

}
