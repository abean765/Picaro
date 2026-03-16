import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: root
    width: 1400
    height: 900
    visible: true
    title: "Picaro"
    color: "#1a1a1a"

    // Navigation state
    property string currentView: "photos"

    // Accent color from settings
    property color accentColor: appSettings.accentColor

    Connections {
        target: appSettings
        function onAccentColorChanged() {
            root.accentColor = appSettings.accentColor
        }
    }

    // Derive darker variant for button backgrounds
    function darkenColor(c, factor) {
        return Qt.darker(c, factor)
    }

    // Photo selection state
    property int selectedPhotoId: -1
    property int infoPhotoId: -1      // photo whose metadata overlay is shown (-1 = closed)

    // Multi-selection: array of selected photo IDs (always contains selectedPhotoId for single clicks)
    property var selectedPhotoIds: []
    // Anchor for SHIFT+click range selection (last CTRL-click or normal click)
    property int selectionAnchorId: -1

    function selectPhoto(photoId) {
        if (selectedPhotoId === photoId && photoId > 0) {
            detailPanel.replay()
            return
        }
        selectedPhotoId = photoId
        selectedPhotoIds = photoId > 0 ? [photoId] : []
        selectionAnchorId = photoId
        if (photoId > 0) {
            appSettings.lastSelectedPhotoId = photoId
            detailPanel.forceActiveFocus()
        }
    }

    function scrollPhotoIntoView(photoId) {
        // PhotoPanel scrolls automatically via its own content;
        // there is no global grid to scroll.
    }

    // Restore last selected photo once the model has finished its initial load.
    property bool _restoredSelection: false
    Connections {
        target: photoModel
        function onModelReloaded() {
            if (root._restoredSelection) return
            root._restoredSelection = true
            var id = appSettings.lastSelectedPhotoId
            if (id > 0 && photoModel.filePathForId(id) !== "")
                root.selectPhoto(id)
        }
    }

    // ── Panel state persistence ──────────────────────────────────────────────

    function _savePanelStates() {
        var states = []
        for (var i = 0; i < panelsModel.count; i++) {
            var p = panelsRepeater.itemAt(i)
            states.push({
                tagId:        p ? p.selectedTagId  : panelsModel.get(i).tagId,
                tagName:      p ? p.selectedTagName : panelsModel.get(i).tagName,
                fitMode:      p ? p.fitMode         : panelsModel.get(i).fitMode,
                photosPerRow: p ? p.photosPerRow    : panelsModel.get(i).photosPerRow,
                timelineMonth: p ? p.activeTimelineMonthKey : ""
            })
        }
        appSettings.savePanelStates(states)
    }

    function _loadPanelStates() {
        var states = appSettings.loadPanelStates()
        if (!states || states.length === 0) {
            panelsModel.append({ tagId: -1, tagName: "", fitMode: false, photosPerRow: 10 })
            return
        }
        for (var i = 0; i < states.length; i++) {
            var s = states[i]
            panelsModel.append({
                tagId:        s.tagId        !== undefined ? s.tagId        : -1,
                tagName:      s.tagName      !== undefined ? s.tagName      : "",
                fitMode:      s.fitMode      !== undefined ? s.fitMode      : false,
                photosPerRow: s.photosPerRow !== undefined ? s.photosPerRow : 10
            })
        }
        // Restore timeline positions after panels are built
        Qt.callLater(function() {
            for (var j = 0; j < states.length; j++) {
                var panel = panelsRepeater.itemAt(j)
                if (panel && states[j].timelineMonth)
                    panel.scrollToMonthKey(states[j].timelineMonth)
            }
        })
    }

    Component.onCompleted: {
        _loadPanelStates()
        if (appSettings.networkVisible) {
            networkManager.startDiscovery(appSettings.computerName)
        }
    }

    // Called from PhotoGridView cells — handles CTRL and SHIFT modifiers.
    function handleCellClick(photoId, modifiers) {
        var ctrl  = (modifiers & Qt.ControlModifier) !== 0
        var shift = (modifiers & Qt.ShiftModifier)   !== 0

        if (shift && selectionAnchorId > 0) {
            // Range selection: select all photos between anchor and this one
            var ids = photoModel.visiblePhotoIds()
            var a = ids.indexOf(selectionAnchorId)
            var b = ids.indexOf(photoId)
            if (a < 0 || b < 0) { selectPhoto(photoId); return }
            if (a > b) { var tmp = a; a = b; b = tmp }
            var range = []
            for (var i = a; i <= b; i++) range.push(ids[i])
            selectedPhotoIds = range
            // Update detail view to the clicked photo without changing the anchor
            selectedPhotoId = photoId
            detailPanel.forceActiveFocus()
        } else if (ctrl) {
            // Toggle this photo in/out of selection
            var arr  = selectedPhotoIds.slice()
            var idx  = arr.indexOf(photoId)
            if (idx >= 0) arr.splice(idx, 1)
            else          arr.push(photoId)
            selectedPhotoIds  = arr
            selectionAnchorId = photoId
            selectedPhotoId   = photoId
            detailPanel.forceActiveFocus()
        } else {
            // Normal click: single select + open detail (existing behaviour)
            selectPhoto(photoId)
        }
    }

    function closeDetail() {
        selectedPhotoId = -1
        selectedPhotoIds = []
        selectionAnchorId = -1
    }

    // F11 toggles fullscreen
    Shortcut {
        sequence: "F11"
        onActivated: {
            if (root.visibility === Window.FullScreen)
                root.showNormal()
            else
                root.showFullScreen()
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Sidebar
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 200
            color: "#222222"

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 12
                spacing: 2

                // App title
                Label {
                    text: "Picaro"
                    color: "#ffffff"
                    font.pixelSize: 22
                    font.bold: true
                    Layout.leftMargin: 16
                    Layout.bottomMargin: 16
                }

                SidebarButton {
                    text: "Fotos"
                    icon: "\u25A3"
                    active: currentView === "photos"
                    onClicked: currentView = "photos"
                }

                SidebarButton {
                    text: "Tags"
                    icon: "\u25C6"
                    active: currentView === "tags"
                    onClicked: currentView = "tags"
                }

                SidebarButton {
                    text: "Übersicht"
                    icon: "\u25C9"
                    active: currentView === "overview"
                    onClicked: currentView = "overview"
                }

                SidebarButton {
                    text: "Einstellungen"
                    icon: "\u2699"
                    active: currentView === "settings"
                    onClicked: currentView = "settings"
                }

                SidebarButton {
                    text: "Tools"
                    icon: "\u2692"
                    active: currentView === "tools"
                    onClicked: currentView = "tools"
                }

                Item { Layout.fillHeight: true }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 2
                    height: 1
                    color: "#333333"
                }

                // Slideshow
                SidebarButton {
                    text: "Slideshow"
                    icon: "\u25B6"
                    active: false
                    visible: currentView === "photos"
                    onClicked: slideshowDialog.open()
                }

                // Add new panel
                SidebarButton {
                    text: "Neues Panel"
                    icon: "\u25A3"
                    active: panelsModel.count > 1
                    visible: currentView === "photos"
                    onClicked: panelsModel.append({ tagId: -1, tagName: "", fitMode: false, photosPerRow: 10 })
                }

                // Vollbild toggle
                SidebarButton {
                    text: "Vollbild"
                    icon: root.visibility === Window.FullScreen ? "\u2716" : "\u26F6"
                    active: root.visibility === Window.FullScreen
                    onClicked: {
                        if (root.visibility === Window.FullScreen)
                            root.showNormal()
                        else
                            root.showFullScreen()
                    }
                }

                // Import button at bottom of sidebar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 8
                    implicitHeight: 36
                    opacity: photoImporter.running ? 0.4 : 1.0
                    color: !photoImporter.running && importBtnArea.containsMouse
                           ? Qt.darker(root.accentColor, 1.3)
                           : Qt.darker(root.accentColor, 1.5)
                    radius: 6

                    Label {
                        anchors.centerIn: parent
                        text: "Ordner importieren"
                        color: "#ffffff"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: importBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: photoImporter.running ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (!photoImporter.running)
                                importDlg.open()
                        }
                    }
                }
            }
        }

        // Main content area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Import progress bar
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: photoImporter.running ? 32 : 0
                color: "#2d2d2d"
                visible: photoImporter.running
                clip: true

                Behavior on implicitHeight { NumberAnimation { duration: 200 } }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: photoImporter.totalFiles > 0
                           ? parent.width * (photoImporter.progress / photoImporter.totalFiles)
                           : 0
                    color: root.accentColor
                    Behavior on width { NumberAnimation { duration: 100 } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 4

                    Label {
                        Layout.fillWidth: true
                        text: "Importiere " + photoImporter.currentDirectory + " \u2013 " + photoImporter.progress + " / " + photoImporter.totalFiles
                        color: "#ffffff"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Rectangle {
                        implicitWidth: cancelLabel.implicitWidth + 16
                        implicitHeight: 22
                        radius: 4
                        color: cancelArea.containsMouse ? "#aa4444" : "#664444"

                        Label {
                            id: cancelLabel
                            anchors.centerIn: parent
                            text: "Abbrechen"
                            color: "#ffffff"
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: cancelArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: photoImporter.cancel()
                        }
                    }
                }
            }

            // Stacked views
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: currentView === "photos" ? 0
                            : currentView === "tags" ? 1
                            : currentView === "overview" ? 2
                            : currentView === "settings" ? 3
                            : 4

                // Photos view with timeline + grid + splitter + detail
                Item {
                    id: photosViewRoot

                    // Split ratio between panels-area and detail panel
                    property real splitRatio: 0.55
                    readonly property bool detailVisible: root.selectedPhotoId > 0

                    // Width allocated to all panels together
                    readonly property real panelsAreaWidth: detailVisible
                        ? width * splitRatio
                        : width

                    // ── Panel model — each entry: {tagId, tagName, fitMode, photosPerRow} ──
                    ListModel { id: panelsModel }

                    // ── Panels row ────────────────────────────────────────────
                    Item {
                        id: panelsRow
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: photosViewRoot.panelsAreaWidth

                        Repeater {
                            id: panelsRepeater
                            model: panelsModel

                            PhotoPanel {
                                required property int index

                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                x: index * (panelsRow.width / Math.max(1, panelsModel.count))
                                width: panelsRow.width / Math.max(1, panelsModel.count)

                                panelsRepeater:  panelsRepeater
                                showLeftDivider: index > 0

                                // Initialise from saved state (avoids naming collision
                                // by reading directly from the model by index)
                                Component.onCompleted: {
                                    var m = panelsModel.get(index)
                                    if (m.tagId > 0)
                                        selectTag(m.tagId, m.tagName)
                                    else
                                        reloadPhotos()
                                    fitMode = m.fitMode
                                    setPhotosPerRow(m.photosPerRow)
                                }

                                // Write-back: keep model in sync for save-on-close
                                onFitModeChanged:      panelsModel.setProperty(index, "fitMode",      fitMode)
                                onPhotosPerRowChanged: panelsModel.setProperty(index, "photosPerRow", photosPerRow)
                                onSelectedTagIdChanged: {
                                    panelsModel.setProperty(index, "tagId",   selectedTagId > 0 ? selectedTagId : -1)
                                    panelsModel.setProperty(index, "tagName", selectedTagName)
                                }

                                onCloseRequested: {
                                    if (panelsModel.count > 1)
                                        panelsModel.remove(index)
                                }
                            }
                        }
                    }

                    // ── Drag ghost ────────────────────────────────────────────
                    Rectangle {
                        id: dragGhost
                        parent: photosViewRoot
                        z: 999
                        width: 72; height: 72
                        radius: 6; clip: true
                        border.width: 2
                        color: "#1affffff"

                        // These bindings iterate all panels and register QML dependencies
                        // on each panel's relevant properties so they update reactively.
                        readonly property int _id: {
                            for (var i = 0; i < panelsRepeater.count; i++) {
                                var p = panelsRepeater.itemAt(i)
                                if (p && p.draggingPhotoId > 0) return p.draggingPhotoId
                            }
                            return -1
                        }
                        readonly property point _sp: {
                            for (var i = 0; i < panelsRepeater.count; i++) {
                                var p = panelsRepeater.itemAt(i)
                                if (p) {
                                    var sp = p.dragScenePos  // register dep
                                    if (p.draggingPhotoId > 0) return sp
                                }
                            }
                            return Qt.point(0, 0)
                        }

                        visible: _id > 0

                        border.color: {
                            var srcTagId = -1
                            var hasRemoveTarget = false
                            for (var i = 0; i < panelsRepeater.count; i++) {
                                var p = panelsRepeater.itemAt(i)
                                if (!p) continue
                                if (p.draggingPhotoId > 0) srcTagId = p.selectedTagId
                                if (p.dragOver && p.selectedTagId <= 0) hasRemoveTarget = true
                            }
                            return (hasRemoveTarget && srcTagId > 0) ? "#cc4444" : root.accentColor
                        }

                        readonly property point _local:
                            photosViewRoot.mapFromItem(null, _sp.x, _sp.y)

                        x: _local.x - width  / 2
                        y: _local.y - height / 2

                        Image {
                            anchors.fill: parent; anchors.margins: 2
                            source: dragGhost._id > 0
                                    ? "image://thumbnail/" + dragGhost._id : ""
                            fillMode: Image.PreserveAspectCrop
                            cache: true
                        }

                        opacity: 0.88
                        Behavior on opacity { NumberAnimation { duration: 80 } }
                    }

                    // ── Draggable splitter handle ─────────────────────────────
                    Rectangle {
                        id: splitterHandle
                        visible: photosViewRoot.detailVisible
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        x: photosViewRoot.panelsAreaWidth - 3
                        width: 6
                        color: splitterMouse.containsMouse || splitterMouse.pressed
                               ? root.accentColor : "#333333"
                        z: 10

                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            id: splitterMouse
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.SplitHCursor
                            property real _startX: 0
                            property real _startRatio: 0

                            onPressed: function(mouse) {
                                _startX     = mouse.x + splitterHandle.x
                                _startRatio = photosViewRoot.splitRatio
                            }
                            onPositionChanged: function(mouse) {
                                if (!pressed) return
                                var delta    = (mouse.x + splitterHandle.x) - _startX
                                var newRatio = _startRatio + delta / photosViewRoot.width
                                photosViewRoot.splitRatio = Math.max(0.2, Math.min(0.8, newRatio))
                            }
                        }
                    }

                    // ── Detail panel ──────────────────────────────────────────
                    DetailView {
                        id: detailPanel
                        visible: photosViewRoot.detailVisible
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: splitterHandle.right
                        anchors.right: parent.right
                        photoId: root.selectedPhotoId
                        gridView: null    // panels use GridView, not ListView
                        onClosed: root.closeDetail()
                        onNavigateNext: {
                            var nextId = photoModel.nextPhotoId(root.selectedPhotoId)
                            if (nextId > 0) root.selectPhoto(nextId)
                        }
                        onNavigatePrevious: {
                            var prevId = photoModel.previousPhotoId(root.selectedPhotoId)
                            if (prevId > 0) root.selectPhoto(prevId)
                        }
                        onSendRequested: function(photoId) { sendSheet.open(photoId) }
                        onEditRequested: function(photoId, filePath, mediaType) {
                            photoEditOverlay.open(photoId, filePath, mediaType)
                        }
                    }
                }

                TagsView {}

                OverviewView {}

                SettingsView {}

                ToolsView {}
            }
        }
    }

    // Refresh view when import finishes or is cancelled
    Connections {
        target: photoImporter
        function onImportFinished(imported, skipped) {
            photoModel.reload()
        }
    }

    // Import dialog overlay
    ImportDialog {
        id: importDlg
        anchors.fill: parent
        z: 200
    }

    // Send sheet overlay
    SendSheet {
        id: sendSheet
        anchors.fill: parent
        z: 100
    }

    // Receive dialog overlay
    ReceiveDialog {
        id: receiveDialogOverlay
        anchors.fill: parent
        z: 100
    }

    // Photo edit view (fullscreen overlay)
    PhotoEditView {
        id: photoEditOverlay
        anchors.fill: parent
        z: 180
        onClosed: {
            photoEditOverlay.visible = false
            { var p = panelsRepeater.itemAt(0); if (p) p.forceActiveFocus() }
        }
        onSavedAndReload: function(photoId) {
            photoModel.reload()
        }
    }

    // Slideshow view (fullscreen overlay)
    SlideshowView {
        id: slideshowOverlay
        anchors.fill: parent
        onClosed: {
            // Return focus to grid
            { var p = panelsRepeater.itemAt(0); if (p) p.forceActiveFocus() }
        }
    }

    // Slideshow start dialog
    Rectangle {
        id: slideshowDialog
        anchors.fill: parent
        color: "#cc000000"
        visible: false
        z: 150

        function open() {
            ssIntervalSlider.value = 5
            ssSelectedTagId = -1
            visible = true
            ssDialogContent.forceActiveFocus()
        }

        function close() {
            visible = false
        }

        property int ssSelectedTagId: -1

        MouseArea {
            anchors.fill: parent
            onClicked: slideshowDialog.close()
        }

        Rectangle {
            id: ssDialogContent
            anchors.centerIn: parent
            width: 420
            height: ssDialogCol.implicitHeight + 48
            color: "#2a2a2a"
            radius: 12
            border.color: "#444444"
            border.width: 1
            focus: true

            Keys.onEscapePressed: slideshowDialog.close()

            MouseArea {
                anchors.fill: parent
                // Prevent click-through
            }

            ColumnLayout {
                id: ssDialogCol
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                // Title
                RowLayout {
                    spacing: 8

                    Label {
                        text: "\u25B6"
                        font.pixelSize: 20
                    }
                    Label {
                        text: "Slideshow starten"
                        color: "#ffffff"
                        font.pixelSize: 20
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: "\u2715"
                        color: "#888888"
                        font.pixelSize: 16
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: slideshowDialog.close()
                        }
                    }
                }

                // Interval setting
                RowLayout {
                    spacing: 12

                    Label {
                        text: "Anzeigedauer:"
                        color: "#aaaaaa"
                        font.pixelSize: 13
                    }

                    Slider {
                        id: ssIntervalSlider
                        from: 2
                        to: 30
                        value: 5
                        stepSize: 1
                        Layout.fillWidth: true
                    }

                    Label {
                        text: Math.round(ssIntervalSlider.value) + " Sek."
                        color: "#ffffff"
                        font.pixelSize: 13
                        Layout.preferredWidth: 50
                    }
                }

                // Tag selection
                Label {
                    text: "Tag auswählen:"
                    color: "#aaaaaa"
                    font.pixelSize: 13
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(ssTagListCol.implicitHeight + 16, 250)
                    color: "#1e1e1e"
                    radius: 6
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 8
                        contentHeight: ssTagListCol.implicitHeight
                        clip: true

                        Column {
                            id: ssTagListCol
                            width: parent.width
                            spacing: 4

                            // "All photos" option
                            Rectangle {
                                width: ssTagListCol.width
                                height: 40
                                radius: 6
                                color: slideshowDialog.ssSelectedTagId === -1 ? "#444444"
                                     : ssAllArea.containsMouse ? "#333333" : "transparent"
                                border.width: slideshowDialog.ssSelectedTagId === -1 ? 2 : 0
                                border.color: root.accentColor

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: "#555555"

                                        Label {
                                            anchors.centerIn: parent
                                            text: "\u25A3"
                                            font.pixelSize: 14
                                        }
                                    }

                                    Label {
                                        text: "Alle Medien"
                                        color: "#ffffff"
                                        font.pixelSize: 14
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }

                                    Label {
                                        text: photoModel.totalPhotos + " Medien"
                                        color: "#888888"
                                        font.pixelSize: 12
                                    }
                                }

                                MouseArea {
                                    id: ssAllArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: slideshowDialog.ssSelectedTagId = -1
                                }
                            }

                            // Tag entries
                            Repeater {
                                model: tagModel

                                Rectangle {
                                    required property var tagId
                                    required property string name
                                    required property string tagColor
                                    required property string tagIcon
                                    required property int photoCount

                                    width: ssTagListCol.width
                                    height: 40
                                    radius: 6
                                    color: slideshowDialog.ssSelectedTagId === tagId ? "#444444"
                                         : ssTagArea.containsMouse ? "#333333" : "transparent"
                                    border.width: slideshowDialog.ssSelectedTagId === tagId ? 2 : 0
                                    border.color: root.accentColor
                                    visible: photoCount > 0

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 10

                                        Rectangle {
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: tagColor

                                            Label {
                                                anchors.centerIn: parent
                                                text: tagIcon
                                                font.pixelSize: 14
                                            }
                                        }

                                        Label {
                                            text: name
                                            color: "#ffffff"
                                            font.pixelSize: 14
                                            font.bold: true
                                            Layout.fillWidth: true
                                        }

                                        Label {
                                            text: photoCount + " Medien"
                                            color: "#888888"
                                            font.pixelSize: 12
                                        }
                                    }

                                    MouseArea {
                                        id: ssTagArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: slideshowDialog.ssSelectedTagId = tagId
                                    }
                                }
                            }

                            // Empty state
                            Label {
                                visible: tagModel.count === 0
                                text: "Keine Tags vorhanden"
                                color: "#666666"
                                font.pixelSize: 12
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                padding: 12
                            }
                        }
                    }
                }

                // Start button
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 8
                    color: ssGoArea.containsMouse ? Qt.darker(root.accentColor, 1.2) : root.accentColor

                    Label {
                        anchors.centerIn: parent
                        text: "\u25B6  Slideshow starten"
                        color: "#ffffff"
                        font.pixelSize: 15
                        font.bold: true
                    }

                    MouseArea {
                        id: ssGoArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var ids
                            if (slideshowDialog.ssSelectedTagId === -1) {
                                ids = photoModel.visiblePhotoIds()
                            } else {
                                ids = tagModel.photoIdsForTag(slideshowDialog.ssSelectedTagId)
                            }

                            if (ids.length > 0) {
                                slideshowDialog.close()
                                slideshowOverlay.start(ids, Math.round(ssIntervalSlider.value))
                            }
                        }
                    }
                }
            }
        }
    }

    // Incoming transfer notification
    Connections {
        target: networkManager
        function onIncomingTransfer(senderName, fileCount, totalSize) {
            receiveDialogOverlay.show(senderName, fileCount, totalSize)
        }
        function onReceiveFinished(success, count, message) {
            if (success && count > 0) {
                photoModel.reload()
                statsProvider.refresh()
            }
        }
    }




    // Photo metadata overlay
    PhotoInfoOverlay {
        visible: root.infoPhotoId > 0
    }

    // Sidebar button component
    component SidebarButton: Rectangle {
        id: sidebarBtn
        property string text: ""
        property string icon: ""
        property bool active: false

        signal clicked()

        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        implicitHeight: 36
        color: active ? "#3a3a3a" : (btnArea.containsMouse ? "#2d2d2d" : "transparent")
        radius: 6

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            spacing: 10

            Label {
                text: sidebarBtn.icon
                color: sidebarBtn.active ? root.accentColor : "#888888"
                font.pixelSize: 16
            }

            Label {
                text: sidebarBtn.text
                color: sidebarBtn.active ? "#ffffff" : "#bbbbbb"
                font.pixelSize: 14
            }

            Item { Layout.fillWidth: true }
        }

        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sidebarBtn.clicked()
        }
    }
}
