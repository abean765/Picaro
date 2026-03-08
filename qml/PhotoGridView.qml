import QtQuick
import QtQuick.Controls
import QtMultimedia

ListView {
    id: gridView

    clip: true
    cacheBuffer: 4000
    reuseItems: true

    model: photoModel

    flickDeceleration: 1500
    maximumFlickVelocity: 15000

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
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            gridView.contentY = Math.max(gridView.contentY - gridView.height * 0.9, 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            gridView.contentY = 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            gridView.contentY = gridView.contentHeight - gridView.height;
            event.accepted = true;
        }
    }

    ScrollBar.vertical: ScrollBar {
        active: true
        policy: ScrollBar.AsNeeded
    }

    delegate: Item {
        id: rowDelegate
        width: gridView.width
        height: model.rowType === "header" ? 52 : cellHeight

        readonly property real cellHeight: gridView.width / photoModel.photosPerRow
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
                    width: (gridView.width - (photoModel.photosPerRow - 1) * 2) / photoModel.photosPerRow
                    height: rowDelegate.cellHeight

                    readonly property bool isVideo: modelData.mediaType === 1
                    readonly property bool isLivePhoto: modelData.mediaType === 2
                    readonly property bool hasVideo: isVideo || isLivePhoto
                    property bool hovered: false

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
                        visible: !videoOutput.visible

                        opacity: status === Image.Ready ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }

                    // Loading placeholder (neutral dark gray, not black)
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        color: "#2a2a2a"
                        visible: thumbImage.status !== Image.Ready && !videoOutput.visible
                    }

                    // Video player overlay (created on hover for videos/live photos)
                    MediaPlayer {
                        id: mediaPlayer
                        videoOutput: videoOutput
                        loops: cellItem.isLivePhoto ? MediaPlayer.Infinite : 1

                        function startPreview() {
                            let path = cellItem.isLivePhoto
                                ? (modelData.liveVideoPath || "")
                                : (modelData.filePath || "");
                            if (path === "") return;
                            source = "file:///" + path;
                            play();
                        }

                        function stopPreview() {
                            stop();
                            source = "";
                        }
                    }

                    VideoOutput {
                        id: videoOutput
                        anchors.fill: parent
                        anchors.margins: 1
                        fillMode: VideoOutput.PreserveAspectCrop
                        visible: cellItem.hovered && cellItem.hasVideo
                                 && mediaPlayer.playbackState === MediaPlayer.PlayingState
                    }

                    // Video/Live Photo badge (hidden during playback)
                    Rectangle {
                        visible: modelData.mediaType > 0 && !videoOutput.visible
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: badge.width + 8
                        height: 20
                        radius: 4
                        color: "#80000000"

                        Label {
                            id: badge
                            anchors.centerIn: parent
                            text: modelData.mediaType === 2 ? "LIVE" : "\u25B6"
                            color: "#ffffff"
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    // Hover area with delay to avoid accidental triggers
                    HoverHandler {
                        id: hoverHandler
                    }

                    Timer {
                        id: hoverTimer
                        interval: 300
                        running: hoverHandler.hovered && cellItem.hasVideo
                        onTriggered: {
                            cellItem.hovered = true;
                            mediaPlayer.startPreview();
                        }
                    }

                    Connections {
                        target: hoverHandler
                        function onHoveredChanged() {
                            if (!hoverHandler.hovered) {
                                hoverTimer.stop();
                                cellItem.hovered = false;
                                mediaPlayer.stopPreview();
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        // Let HoverHandler handle hover; MouseArea handles clicks
                        hoverEnabled: false
                        onClicked: {
                            console.log("Clicked photo ID:", modelData.id)
                        }
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
