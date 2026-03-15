import QtQuick
import QtQuick.Controls
import QtMultimedia

ListView {
    id: gridView

    clip: true
    cacheBuffer: 4000
    reuseItems: true
    // Width available for photo content — keeps thumbnails clear of the scrollbar.
    readonly property real _contentWidth: width - 44

    model: photoModel

    // Drag state — read by Main.qml to drive the drag ghost and drop logic
    property int draggingPhotoId: -1
    property point dragScenePos: Qt.point(0, 0)

    flickDeceleration: 1500
    maximumFlickVelocity: 15000

    // The cell that is currently being previewed (null when idle).
    property Item _hoveredCell: null

    // Single MediaPlayer for the entire grid — at most one cell can be hovered
    // at a time, so there is no reason to keep one player per cell.
    MediaPlayer {
        id: sharedPlayer
        videoOutput: overlayOutput
    }

    // Single VideoOutput overlay, parented directly to the ListView so it sits
    // in viewport coordinates and is clipped by the ListView bounds.
    // Its position tracks _hoveredCell; referencing gridView.contentY in the
    // binding expression ensures it re-evaluates whenever the list scrolls.
    // Only shown once media is buffered (first frame ready) to avoid a black flash.
    VideoOutput {
        id: overlayOutput
        parent: gridView
        z: 10
        fillMode: VideoOutput.PreserveAspectCrop
        visible: gridView._hoveredCell !== null &&
                 sharedPlayer.playbackState === MediaPlayer.PlayingState &&
                 (sharedPlayer.mediaStatus === MediaPlayer.BufferedMedia ||
                  sharedPlayer.mediaStatus === MediaPlayer.EndOfMedia)

        x: gridView._hoveredCell
            ? gridView._hoveredCell.mapToItem(gridView, 0, 0).x + gridView.contentY * 0
            : 0
        y: gridView._hoveredCell
            ? gridView._hoveredCell.mapToItem(gridView, 0, 0).y + gridView.contentY * 0
            : 0
        width:  gridView._hoveredCell ? gridView._hoveredCell.width  : 0
        height: gridView._hoveredCell ? gridView._hoveredCell.height : 0
    }

    // Faster mouse wheel scrolling
    WheelHandler {
        id: wheelHandler
        target: gridView
        property: "contentY"
        rotationScale: -3.0
    }

    // Page Up / Page Down keyboard support
    focus: true
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_PageDown) {
            gridView.contentY = Math.min(gridView.contentY + gridView.height * 0.9,
                                         gridView.contentHeight - gridView.height);
            gridView.forceLayout();
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            gridView.contentY = Math.max(gridView.contentY - gridView.height * 0.9, 0);
            gridView.forceLayout();
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            gridView.contentY = 0;
            gridView.forceLayout();
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            gridView.contentY = gridView.contentHeight - gridView.height;
            gridView.forceLayout();
            event.accepted = true;
        }
    }

    ScrollBar.vertical: ScrollBar {
        id: verticalScrollBar
        active: true
        policy: ScrollBar.AsNeeded
        topPadding: 2
        bottomPadding: 2
        rightPadding: 4

        contentItem: Rectangle {
            implicitWidth: 22
            radius: 11
            color: verticalScrollBar.pressed
                   ? Qt.lighter(root.accentColor, 1.2)
                   : verticalScrollBar.hovered
                     ? root.accentColor
                     : Qt.darker(root.accentColor, 1.4)
        }

        background: Rectangle {
            implicitWidth: 32
            color: verticalScrollBar.hovered ? "#1affffff" : "transparent"
            radius: 16
        }
    }

    delegate: Item {
        id: rowDelegate
        width: gridView._contentWidth
        height: model.rowType === "header" ? 52 : cellHeight

        readonly property real cellHeight: gridView._contentWidth / photoModel.photosPerRow
        readonly property var rowCells: model.cells

        // Month header
        Label {
            visible: model.rowType === "header"
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: model.headerText ?? ""
            color: "#ffffff"
            font.pixelSize: 18
            font.bold: true
        }

        // Photo row
        Row {
            visible: model.rowType === "photos"
            spacing: 2

            Repeater {
                model: rowDelegate.rowCells

                Item {
                    id: cellItem
                    width: (gridView._contentWidth - (photoModel.photosPerRow - 1) * 2) / photoModel.photosPerRow
                    height: rowDelegate.cellHeight

                    readonly property bool isVideo: modelData.mediaType === 1
                    readonly property bool isLivePhoto: modelData.mediaType === 2
                    readonly property bool hasVideo: isVideo || isLivePhoto

                    // True once the shared player has a buffered frame for this cell.
                    // Using mediaStatus avoids the black-flash between thumbnail
                    // disappearing and the first video frame being rendered.
                    readonly property bool videoPlaying:
                        gridView._hoveredCell === cellItem &&
                        sharedPlayer.playbackState === MediaPlayer.PlayingState &&
                        (sharedPlayer.mediaStatus === MediaPlayer.BufferedMedia ||
                         sharedPlayer.mediaStatus === MediaPlayer.EndOfMedia)

                    // Selection highlight (single or multi-select)
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        color: "transparent"
                        border.color: root.accentColor
                        border.width: root.selectedPhotoIds.indexOf(modelData.id) >= 0 ? 3 : 0
                        z: 2
                    }

                    Image {
                        id: thumbImage
                        anchors.fill: parent
                        anchors.margins: 1
                        source: "image://thumbnail/" + modelData.id
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: width
                        sourceSize.height: height
                        cache: true
                        visible: !cellItem.videoPlaying

                        opacity: status === Image.Ready ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }

                    // Loading placeholder (neutral dark gray, not black)
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        color: "#2a2a2a"
                        visible: thumbImage.status !== Image.Ready && !cellItem.videoPlaying
                    }

                    // Video/Live Photo badge (hidden during playback)
                    Rectangle {
                        visible: modelData.mediaType > 0 && !cellItem.videoPlaying
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: 8
                        width: badge.implicitWidth + 14
                        height: badge.implicitHeight + 8
                        radius: 6
                        color: "#90000000"

                        Label {
                            id: badge
                            anchors.centerIn: parent
                            text: modelData.mediaType === 2 ? "LIVE" : "\u25B6"
                            color: "#ffffff"
                            font.pixelSize: parent.parent.width < 80 ? 10 : 16
                            font.bold: true
                        }
                    }

                    // Info button — bottom-left, visible on hover
                    Rectangle {
                        id: infoBtn
                        visible: hoverHandler.hovered && !cellItem.videoPlaying && parent.width >= infoBtn.width * 4
                        anchors.bottom: parent.bottom
                        anchors.left:   parent.left
                        anchors.margins: 6
                        width: 28
                        height: 28
                        radius: 14
                        color: infoBtnArea.containsMouse ? "#dddddd" : "#90000000"
                        z: 3

                        Label {
                            anchors.centerIn: parent
                            text: "i"
                            font.pixelSize: 14
                            font.bold: true
                            font.italic: true
                            color: infoBtnArea.containsMouse ? "#222222" : "#ffffff"
                        }

                        MouseArea {
                            id: infoBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                mouse.accepted = true
                                root.infoPhotoId = modelData.id
                            }
                        }
                    }

                    // Delete / Restore button (visible on hover, hidden when thumbnail
                    // is too small to select without accidentally hitting the button)
                    Rectangle {
                        id: deleteBtn
                        visible: hoverHandler.hovered && !cellItem.videoPlaying && parent.width >= deleteBtn.width * 4
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: 28
                        height: 28
                        radius: 14
                        color: deleteBtnArea.containsMouse
                               ? (photoModel.showDeleted ? "#22c55e" : "#dd3333")
                               : "#90000000"
                        z: 3

                        Label {
                            anchors.centerIn: parent
                            text: photoModel.showDeleted ? "\u21A9" : "\u2715"
                            font.pixelSize: 14
                            color: "#ffffff"
                        }

                        MouseArea {
                            id: deleteBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                mouse.accepted = true
                                if (photoModel.showDeleted)
                                    photoModel.restorePhoto(modelData.id)
                                else
                                    photoModel.deletePhoto(modelData.id)
                            }
                        }
                    }

                    HoverHandler {
                        id: hoverHandler
                    }

                    Timer {
                        id: hoverTimer
                        interval: 300
                        running: hoverHandler.hovered && cellItem.hasVideo
                        onTriggered: {
                            let path = cellItem.isLivePhoto
                                ? (modelData.liveVideoPath || "")
                                : (modelData.filePath || "");
                            if (path === "") return;

                            // Stop any previous preview before reconfiguring.
                            sharedPlayer.stop();
                            sharedPlayer.loops = 1;
                            gridView._hoveredCell = cellItem;
                            sharedPlayer.source = (Qt.platform.os === "windows" ? "file:///" : "file://") + path;
                            sharedPlayer.play();
                        }
                    }

                    Connections {
                        target: hoverHandler
                        function onHoveredChanged() {
                            if (!hoverHandler.hovered) {
                                hoverTimer.stop();
                                if (gridView._hoveredCell === cellItem) {
                                    sharedPlayer.stop();
                                    sharedPlayer.source = "";
                                    gridView._hoveredCell = null;
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: false
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            root.handleCellClick(modelData.id, mouse.modifiers)
                        }
                    }

                    // Drag handler — activates after the default drag threshold (~10px).
                    // Uses target:null so the cell itself is never moved.
                    DragHandler {
                        id: cellDragHandler
                        target: null

                        onActiveChanged: {
                            if (active) {
                                gridView.draggingPhotoId = modelData.id
                            } else {
                                // Signal drag end before clearing so Main.qml can
                                // still read draggingPhotoId in the same frame.
                                if (gridView.draggingPhotoId === modelData.id)
                                    gridView.draggingPhotoId = -1
                            }
                        }

                        onCentroidChanged: {
                            if (active)
                                gridView.dragScenePos = centroid.scenePosition
                        }
                    }

                    // Reset drag state when a reused delegate is pulled from the pool
                    // so a stale draggingPhotoId never gets stuck.
                    ListView.onPooled: {
                        if (cellDragHandler.active && gridView.draggingPhotoId === modelData.id)
                            gridView.draggingPhotoId = -1
                    }
                }
            }
        }
    }

    // Empty state
    Label {
        anchors.centerIn: parent
        visible: gridView.count === 0
        text: "Keine Fotos vorhanden.\nKlicke \"Ordner importieren\" um zu beginnen."
        color: "#666666"
        font.pixelSize: 16
        horizontalAlignment: Text.AlignHCenter
    }
}
