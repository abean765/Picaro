import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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

    function selectPhoto(photoId) {
        selectedPhotoId = photoId
        if (photoId > 0) {
            detailPanel.forceActiveFocus()
        }
    }

    function closeDetail() {
        selectedPhotoId = -1
        photoGrid.forceActiveFocus()
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

            // Toolbar (only for photos view)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: currentView === "photos" ? 44 : 0
                color: "#2d2d2d"
                visible: currentView === "photos"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Label {
                        text: photoModel.totalPhotos + " Medien"
                        color: "#aaaaaa"
                        font.pixelSize: 14
                    }

                    // Media type filter buttons
                    Row {
                        spacing: 1

                        Repeater {
                            id: filterRepeater
                            model: [
                                { label: "Alle", filter: -1 },
                                { label: "Fotos", filter: 0 },
                                { label: "Videos", filter: 1 }
                            ]

                            Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool isFirst: index === 0
                                readonly property bool isActive: !photoModel.showDeleted && photoModel.mediaTypeFilter === modelData.filter
                                width: filterLabel.implicitWidth + 20
                                height: 26
                                radius: isFirst ? 4 : 0
                                color: isActive ? "#555555" : "#3a3a3a"

                                // Round only left corners for first
                                Rectangle {
                                    visible: isFirst
                                    anchors.right: parent.right
                                    width: parent.width / 2
                                    height: parent.height
                                    color: parent.color
                                }

                                Label {
                                    id: filterLabel
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: isActive ? "#ffffff" : "#aaaaaa"
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        photoModel.showDeleted = false
                                        photoModel.mediaTypeFilter = modelData.filter
                                    }
                                }
                            }
                        }

                        // Deleted filter (separate toggle)
                        Rectangle {
                            width: deletedLabel.implicitWidth + 20
                            height: 26
                            radius: 4
                            color: photoModel.showDeleted ? "#664444" : "#3a3a3a"

                            // Round only right corners
                            Rectangle {
                                anchors.left: parent.left
                                width: parent.width / 2
                                height: parent.height
                                color: parent.color
                            }

                            Label {
                                id: deletedLabel
                                anchors.centerIn: parent
                                text: "\u2715 Gelöscht"
                                color: photoModel.showDeleted ? "#ff8888" : "#aaaaaa"
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    photoModel.showDeleted = !photoModel.showDeleted
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Search / filter by tag or sender
                    Item {
                        implicitWidth: 220
                        implicitHeight: 28

                        Rectangle {
                            id: searchBox
                            anchors.fill: parent
                            color: searchInput.activeFocus ? "#3a3a3a" : "#333333"
                            radius: 14
                            border.color: searchInput.activeFocus ? root.accentColor : "#444444"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 6
                                spacing: 4

                                Label {
                                    text: "\u25CB"
                                    font.pixelSize: 12
                                    opacity: 0.6
                                }

                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    verticalAlignment: Text.AlignVCenter
                                    color: "#ffffff"
                                    font.pixelSize: 12
                                    clip: true
                                    selectByMouse: true

                                    property bool suppressUpdate: false

                                    onTextChanged: {
                                        if (!suppressUpdate)
                                            photoModel.updateSuggestions(text)
                                    }

                                    Keys.onReturnPressed: {
                                        if (suggestionPopup.visible && suggestionList.currentIndex >= 0) {
                                            applySuggestion(photoModel.filterSuggestions[suggestionList.currentIndex])
                                        } else if (text.trim() !== "") {
                                            photoModel.filterText = text.trim()
                                            suggestionPopup.visible = false
                                        }
                                    }

                                    onActiveFocusChanged: {
                                        if (!activeFocus)
                                            suggestionPopup.close()
                                    }

                                    Keys.onEscapePressed: {
                                        if (suggestionPopup.visible) {
                                            suggestionPopup.close()
                                        } else {
                                            text = ""
                                            photoModel.clearFilter()
                                            focus = false
                                        }
                                    }

                                    Keys.onDownPressed: {
                                        if (suggestionPopup.visible && suggestionList.currentIndex < suggestionList.count - 1) {
                                            suggestionList.currentIndex++
                                        }
                                    }

                                    Keys.onUpPressed: {
                                        if (suggestionPopup.visible && suggestionList.currentIndex > 0) {
                                            suggestionList.currentIndex--
                                        }
                                    }
                                }

                                // Clear button
                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: clearFilterArea.containsMouse ? "#555555" : "transparent"
                                    visible: searchInput.text.length > 0 || photoModel.filterText !== ""

                                    Label {
                                        anchors.centerIn: parent
                                        text: "\u2715"
                                        color: "#888888"
                                        font.pixelSize: 10
                                    }

                                    MouseArea {
                                        id: clearFilterArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            searchInput.text = ""
                                            photoModel.clearFilter()
                                        }
                                    }
                                }
                            }

                            // Placeholder text
                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: 28
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Tag oder Sender..."
                                color: "#666666"
                                font.pixelSize: 12
                                visible: searchInput.text.length === 0 && !searchInput.activeFocus
                            }
                        }

                        // Active filter indicator
                        Rectangle {
                            anchors.left: searchBox.right
                            anchors.leftMargin: 6
                            anchors.verticalCenter: searchBox.verticalCenter
                            width: activeFilterLabel.implicitWidth + 20
                            height: 22
                            radius: 11
                            color: root.accentColor
                            visible: photoModel.filterText !== ""

                            Label {
                                id: activeFilterLabel
                                anchors.centerIn: parent
                                text: photoModel.filterText
                                color: "#ffffff"
                                font.pixelSize: 11
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchInput.text = ""
                                    photoModel.clearFilter()
                                }
                            }
                        }

                        // Autocomplete popup - rendered in overlay above all content
                        Popup {
                            id: suggestionPopup
                            x: 0
                            y: searchBox.height + 4
                            width: searchBox.width
                            height: Math.min(suggestionList.contentHeight + 8, 200)
                            padding: 0
                            modal: false
                            focus: false
                            closePolicy: Popup.NoAutoClose

                            background: Rectangle {
                                color: "#2a2a2a"
                                radius: 8
                                border.color: "#444444"
                                border.width: 1
                            }

                            contentItem: ListView {
                                id: suggestionList
                                anchors.fill: parent
                                anchors.margins: 4
                                model: photoModel.filterSuggestions
                                currentIndex: -1
                                clip: true

                                delegate: Rectangle {
                                    required property string modelData
                                    required property int index

                                    width: ListView.view.width
                                    height: 30
                                    radius: 4
                                    color: index === suggestionList.currentIndex ? "#444444"
                                         : suggItemArea.containsMouse ? "#383838" : "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 6

                                        Label {
                                            text: modelData.startsWith("Tag:") ? "\u25C6" : "\u2B07"
                                            font.pixelSize: 12
                                        }

                                        Label {
                                            text: modelData
                                            color: "#cccccc"
                                            font.pixelSize: 12
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: suggItemArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: applySuggestion(modelData)
                                    }
                                }
                            }
                        }

                        Connections {
                            target: photoModel
                            function onFilterSuggestionsChanged() {
                                if (searchInput.text.length > 0 && photoModel.filterSuggestions.length > 0) {
                                    suggestionPopup.open()
                                } else {
                                    suggestionPopup.close()
                                }
                            }
                        }

                        function applySuggestion(suggestion) {
                            // Extract the actual value after "Tag: " or "Sender: "
                            var value = suggestion
                            if (suggestion.startsWith("Tag: ")) {
                                value = suggestion.substring(5)
                            } else if (suggestion.startsWith("Sender: ")) {
                                value = suggestion.substring(8)
                            }
                            searchInput.suppressUpdate = true
                            searchInput.text = value
                            searchInput.suppressUpdate = false
                            photoModel.filterText = value
                            suggestionPopup.close()
                        }
                    }

                    Label {
                        text: "Größe"
                        color: "#aaaaaa"
                        font.pixelSize: 12
                    }

                    Slider {
                        id: zoomSlider
                        from: 3
                        to: 12
                        value: 5
                        stepSize: 1
                        implicitWidth: 120

                        onValueChanged: {
                            photoModel.photosPerRow = Math.round(value)
                        }
                    }

                    // Slideshow button
                    Rectangle {
                        implicitWidth: ssStartLabel.implicitWidth + 20
                        implicitHeight: 26
                        radius: 4
                        color: ssStartArea.containsMouse ? Qt.darker(root.accentColor, 1.3) : "#3a3a3a"

                        Label {
                            id: ssStartLabel
                            anchors.centerIn: parent
                            text: "\u25B6 Slideshow"
                            color: ssStartArea.containsMouse ? "#ffffff" : "#aaaaaa"
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: ssStartArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: slideshowDialog.open()
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

                    // Splitter position (ratio of grid width to total available width)
                    property real splitRatio: 0.55
                    // Available width after timeline
                    readonly property real contentWidth: width - timelineView.width
                    readonly property bool detailVisible: root.selectedPhotoId > 0

                    TimelineView {
                        id: timelineView
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        visible: photoModel.totalPhotos > 0
                        onMonthClicked: function(timelineIndex, rowIndex) {
                            photoGrid.positionViewAtIndex(rowIndex, ListView.Beginning)
                        }
                    }

                    // Debounced timeline activeIndex update (avoids per-pixel recomputation during scroll)
                    Timer {
                        id: timelineUpdateTimer
                        interval: 80
                        onTriggered: {
                            if (!photoGrid.count) { timelineView.activeIndex = -1; return }
                            var topIdx = photoGrid.indexAt(0, photoGrid.contentY + 10)
                            if (topIdx < 0) { timelineView.activeIndex = -1; return }
                            // Binary search through headerRowIndices
                            var data = photoModel.timelineData
                            var lo = 0, hi = data.length - 1, best = -1
                            while (lo <= hi) {
                                var mid = (lo + hi) >> 1
                                if (data[mid].rowIndex <= topIdx) {
                                    best = mid
                                    lo = mid + 1
                                } else {
                                    hi = mid - 1
                                }
                            }
                            timelineView.activeIndex = best
                        }
                    }
                    Connections {
                        target: photoGrid
                        function onContentYChanged() { timelineUpdateTimer.restart() }
                    }

                    PhotoGridView {
                        id: photoGrid
                        anchors.left: timelineView.visible ? timelineView.right : parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: photosViewRoot.detailVisible
                              ? photosViewRoot.contentWidth * photosViewRoot.splitRatio
                              : photosViewRoot.contentWidth
                    }

                    // Draggable splitter handle
                    Rectangle {
                        id: splitterHandle
                        visible: photosViewRoot.detailVisible
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        x: photoGrid.x + photoGrid.width - 3
                        width: 6
                        color: splitterMouse.containsMouse || splitterMouse.pressed ? root.accentColor : "#333333"
                        z: 10

                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            id: splitterMouse
                            anchors.fill: parent
                            anchors.margins: -3  // larger hit area
                            hoverEnabled: true
                            cursorShape: Qt.SplitHCursor
                            property real dragStartX: 0
                            property real dragStartRatio: 0

                            onPressed: function(mouse) {
                                dragStartX = mouse.x + splitterHandle.x
                                dragStartRatio = photosViewRoot.splitRatio
                            }
                            onPositionChanged: function(mouse) {
                                if (!pressed) return
                                var currentX = mouse.x + splitterHandle.x
                                var delta = currentX - dragStartX
                                var newRatio = dragStartRatio + delta / photosViewRoot.contentWidth
                                photosViewRoot.splitRatio = Math.max(0.2, Math.min(0.8, newRatio))
                            }
                        }
                    }

                    // Detail panel (right side)
                    DetailView {
                        id: detailPanel
                        visible: photosViewRoot.detailVisible
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: splitterHandle.right
                        anchors.right: parent.right
                        photoId: root.selectedPhotoId
                        gridView: photoGrid
                        onClosed: root.closeDetail()
                        onNavigateNext: {
                            var nextId = photoModel.nextPhotoId(root.selectedPhotoId)
                            if (nextId > 0) root.selectPhoto(nextId)
                        }
                        onNavigatePrevious: {
                            var prevId = photoModel.previousPhotoId(root.selectedPhotoId)
                            if (prevId > 0) root.selectPhoto(prevId)
                        }
                        onSendRequested: function(photoId) {
                            sendSheet.open(photoId)
                        }
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
            photoGrid.forceActiveFocus()
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
            photoGrid.forceActiveFocus()
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

    // Auto-start discovery if network visible
    Component.onCompleted: {
        if (appSettings.networkVisible) {
            networkManager.startDiscovery(appSettings.computerName)
        }
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
