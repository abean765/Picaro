import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Rectangle {
    id: detailView
    color: "#111111"

    property int photoId: -1

    property ListView gridView: null

    signal closed()
    signal navigateNext()
    signal navigatePrevious()
    signal sendRequested(int photoId)

    // Derived properties from current photoId
    readonly property string filePath: photoId > 0 ? photoModel.filePathForId(photoId) : ""
    readonly property int mediaType: photoId > 0 ? photoModel.mediaTypeForId(photoId) : 0
    readonly property string liveVideoPath: photoId > 0 ? photoModel.liveVideoPathForId(photoId) : ""
    readonly property bool isVideo: mediaType === 1
    readonly property bool isLivePhoto: mediaType === 2
    readonly property bool hasContent: photoId > 0 && filePath !== ""

    readonly property var gpsCoords: photoId > 0 ? photoModel.coordinatesForId(photoId) : null
    readonly property bool hasGps: gpsCoords !== null && gpsCoords !== undefined && Object.keys(gpsCoords).length > 0

    property bool mapVisible: false

    // Stop video when photo changes or view closes
    // Query model directly to avoid stale derived properties (QML binding order is not guaranteed)
    onPhotoIdChanged: {
        mapVisible = false
        detailPlayer.stop()
        detailPlayer.source = ""
        if (photoId <= 0) return
        var mt = photoModel.mediaTypeForId(photoId)
        var fp = photoModel.filePathForId(photoId)
        var lvp = photoModel.liveVideoPathForId(photoId)
        if (mt === 1 && fp !== "") {
            detailPlayer.source = "file:///" + fp
        } else if (mt === 2 && lvp !== "") {
            detailPlayer.source = "file:///" + lvp
        }
    }

    // Keyboard navigation
    focus: true
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Right) {
            detailView.navigateNext()
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            detailView.navigatePrevious()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            detailView.closed()
            event.accepted = true
        } else if (event.key === Qt.Key_Space && (isVideo || isLivePhoto)) {
            if (detailPlayer.playbackState === MediaPlayer.PlayingState)
                detailPlayer.pause()
            else
                detailPlayer.play()
            event.accepted = true
        } else if (gridView) {
            // Forward scroll keys to the grid
            if (event.key === Qt.Key_PageDown) {
                gridView.contentY = Math.min(gridView.contentY + gridView.height * 0.9,
                                             gridView.contentHeight - gridView.height)
                gridView.forceLayout()
                event.accepted = true
            } else if (event.key === Qt.Key_PageUp) {
                gridView.contentY = Math.max(gridView.contentY - gridView.height * 0.9, 0)
                gridView.forceLayout()
                event.accepted = true
            } else if (event.key === Qt.Key_Home) {
                gridView.contentY = 0
                gridView.forceLayout()
                event.accepted = true
            } else if (event.key === Qt.Key_End) {
                gridView.contentY = gridView.contentHeight - gridView.height
                gridView.forceLayout()
                event.accepted = true
            }
        }
    }

    // Full-size image (photos and live photos)
    Image {
        id: fullImage
        anchors.fill: parent
        anchors.margins: 8
        visible: hasContent && !isVideo
        source: hasContent && !isVideo ? "file:///" + filePath : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true

        opacity: status === Image.Ready ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    // Loading spinner
    BusyIndicator {
        anchors.centerIn: parent
        running: hasContent && !isVideo && fullImage.status === Image.Loading
        visible: running
    }

    // Video/LivePhoto player
    AudioOutput { id: detailAudio }
    MediaPlayer {
        id: detailPlayer
        videoOutput: detailVideoOutput
        audioOutput: detailAudio
        loops: 1
        onSourceChanged: {
            if (source.toString() !== "") {
                play()
            }
        }
    }

    VideoOutput {
        id: detailVideoOutput
        anchors.fill: parent
        anchors.margins: 8
        fillMode: VideoOutput.PreserveAspectFit
        visible: hasContent && (isVideo || isLivePhoto)
                 && detailPlayer.playbackState !== MediaPlayer.StoppedState
    }

    // Video controls overlay
    Rectangle {
        visible: isVideo && hasContent
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        height: 40
        color: "#80000000"
        radius: 4

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            // Play/Pause
            Label {
                text: detailPlayer.playbackState === MediaPlayer.PlayingState ? "\u23F8" : "\u25B6"
                color: "#ffffff"
                font.pixelSize: 18
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (detailPlayer.playbackState === MediaPlayer.PlayingState)
                            detailPlayer.pause()
                        else
                            detailPlayer.play()
                    }
                }
            }

            // Progress bar
            Slider {
                Layout.fillWidth: true
                from: 0
                to: detailPlayer.duration
                value: detailPlayer.position
                onMoved: detailPlayer.position = value
            }

            // Duration label
            Label {
                text: formatTime(detailPlayer.position) + " / " + formatTime(detailPlayer.duration)

                function formatTime(ms) {
                    var s = Math.floor(ms / 1000)
                    var m = Math.floor(s / 60)
                    var sec = s % 60
                    return m + ":" + (sec < 10 ? "0" : "") + sec
                }
                color: "#cccccc"
                font.pixelSize: 12
            }
        }
    }

    // LivePhoto badge – hover to replay
    Rectangle {
        visible: isLivePhoto && hasContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 16
        width: liveBadge.implicitWidth + 16
        height: liveBadge.implicitHeight + 8
        radius: 6
        color: liveBadgeArea.containsMouse ? "#c0000000" : "#90000000"

        Label {
            id: liveBadge
            anchors.centerIn: parent
            text: "LIVE"
            color: liveBadgeArea.containsMouse ? "#ffffff" : "#cccccc"
            font.pixelSize: 14
            font.bold: true
        }

        MouseArea {
            id: liveBadgeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                detailPlayer.position = 0
                detailPlayer.play()
            }
        }
    }

    // Navigation arrows
    Rectangle {
        id: prevButton
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 8
        width: 40
        height: 40
        radius: 20
        color: prevArea.containsMouse ? "#60ffffff" : "#30ffffff"
        visible: hasContent && photoModel.previousPhotoId(photoId) > 0

        Label {
            anchors.centerIn: parent
            text: "\u276E"
            color: "#ffffff"
            font.pixelSize: 20
        }

        MouseArea {
            id: prevArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: detailView.navigatePrevious()
        }
    }

    Rectangle {
        id: nextButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 8
        width: 40
        height: 40
        radius: 20
        color: nextArea.containsMouse ? "#60ffffff" : "#30ffffff"
        visible: hasContent && photoModel.nextPhotoId(photoId) > 0

        Label {
            anchors.centerIn: parent
            text: "\u276F"
            color: "#ffffff"
            font.pixelSize: 20
        }

        MouseArea {
            id: nextArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: detailView.navigateNext()
        }
    }

    // GPS map button (only visible for geotagged photos)
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: 92
        anchors.topMargin: 12
        width: 32
        height: 32
        radius: 16
        color: mapVisible ? "#80ffffff" : (mapBtnArea.containsMouse ? "#60ffffff" : "#30ffffff")
        visible: hasContent && hasGps

        Label {
            anchors.centerIn: parent
            text: "\u25CF"
            font.pixelSize: 14
        }

        MouseArea {
            id: mapBtnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: detailView.mapVisible = !detailView.mapVisible
        }
    }

    // Map overlay panel
    Rectangle {
        id: mapPanel
        visible: detailView.mapVisible && hasGps
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 52
        anchors.rightMargin: 12
        width: 300
        height: 240
        radius: 10
        color: "#222222"
        border.color: "#555555"
        border.width: 1
        z: 30
        clip: true

        // OSM tile map with 3×3 tile grid
        Item {
            id: tileGrid
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 200
            clip: true

            property int zoom: 14
            property double lat: hasGps ? detailView.gpsCoords.lat : 0
            property double lon: hasGps ? detailView.gpsCoords.lon : 0

            // Tile coordinates of center tile
            property int centerTileX: Math.floor((lon + 180) / 360 * Math.pow(2, zoom))
            property int centerTileY: {
                var lr = lat * Math.PI / 180
                return Math.floor((1 - Math.log(Math.tan(lr) + 1 / Math.cos(lr)) / Math.PI) / 2 * Math.pow(2, zoom))
            }

            // Pixel offset of pin within center tile (0–256)
            property double pinPxX: ((lon + 180) / 360 * Math.pow(2, zoom) - centerTileX) * 256
            property double pinPxY: {
                var lr = lat * Math.PI / 180
                return ((1 - Math.log(Math.tan(lr) + 1 / Math.cos(lr)) / Math.PI) / 2 * Math.pow(2, zoom) - centerTileY) * 256
            }

            // Scale 3×3 tile grid (768×768) into the 300px wide panel
            property double scale: tileGrid.width / 768

            // Rendered 3×3 tile images
            Repeater {
                model: 9
                Image {
                    required property int index
                    property int dx: (index % 3) - 1  // -1, 0, 1
                    property int dy: Math.floor(index / 3) - 1  // -1, 0, 1
                    x: (dx + 1) * 256 * tileGrid.scale
                    y: (dy + 1) * 256 * tileGrid.scale
                    width:  256 * tileGrid.scale
                    height: 256 * tileGrid.scale
                    source: "https://tile.openstreetmap.org/%1/%2/%3.png"
                        .arg(tileGrid.zoom)
                        .arg(tileGrid.centerTileX + dx)
                        .arg(tileGrid.centerTileY + dy)
                    fillMode: Image.Stretch
                    // Grey placeholder while loading
                    Rectangle {
                        anchors.fill: parent
                        color: "#333333"
                        visible: parent.status !== Image.Ready
                    }
                }
            }

            // Pin marker at exact GPS location
            Label {
                x: (256 + tileGrid.pinPxX) * tileGrid.scale - width / 2
                y: (256 + tileGrid.pinPxY) * tileGrid.scale - height + 2
                text: "\u25CF"
                font.pixelSize: 28
                style: Text.Outline
                styleColor: "#000000"
            }
        }

        // Coordinates + "Open in browser" row
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8
            height: 32

            Label {
                text: hasGps
                    ? "%1° %2,  %3° %4"
                        .arg(Math.abs(detailView.gpsCoords.lat).toFixed(5))
                        .arg(detailView.gpsCoords.lat >= 0 ? "N" : "S")
                        .arg(Math.abs(detailView.gpsCoords.lon).toFixed(5))
                        .arg(detailView.gpsCoords.lon >= 0 ? "E" : "W")
                    : ""
                color: "#aaaaaa"
                font.pixelSize: 11
                font.family: "Monospace"
                Layout.fillWidth: true
            }

            Label {
                text: "OpenStreetMap \u2197"
                color: "#5588ff"
                font.pixelSize: 11
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally(
                        "https://www.openstreetmap.org/?mlat=%1&mlon=%2&zoom=14"
                        .arg(detailView.gpsCoords.lat)
                        .arg(detailView.gpsCoords.lon))
                }
            }
        }
    }

    // Send button
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: 52
        anchors.topMargin: 12
        width: 32
        height: 32
        radius: 16
        color: sendBtnArea.containsMouse ? "#60ffffff" : "#30ffffff"
        visible: hasContent

        Label {
            anchors.centerIn: parent
            text: "\u2B06"
            font.pixelSize: 14
        }

        MouseArea {
            id: sendBtnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: detailView.sendRequested(detailView.photoId)
        }
    }

    // Close button
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
        width: 32
        height: 32
        radius: 16
        color: closeArea.containsMouse ? "#60ffffff" : "#30ffffff"

        Label {
            anchors.centerIn: parent
            text: "\u2715"
            color: "#ffffff"
            font.pixelSize: 16
        }

        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: detailView.closed()
        }
    }

    // Heart rating (1-5)
    Row {
        id: heartRow
        anchors.bottom: tagRow.top
        anchors.bottomMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4
        visible: hasContent

        property int currentRating: hasContent ? photoModel.ratingForId(photoId) : 0

        Connections {
            target: detailView
            function onPhotoIdChanged() {
                heartRow.currentRating = detailView.hasContent ? photoModel.ratingForId(detailView.photoId) : 0
            }
        }

        Repeater {
            model: 5

            Label {
                required property int index
                readonly property int heartIndex: index + 1
                text: heartIndex <= heartRow.currentRating ? "\u2764" : "\u2661"
                color: heartIndex <= heartRow.currentRating ? "#e53e3e" : "#666666"
                font.pixelSize: 22
                opacity: heartArea.containsMouse ? 1.0 : 0.85

                Behavior on color { ColorAnimation { duration: 150 } }

                MouseArea {
                    id: heartArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var newRating = heartIndex === heartRow.currentRating ? 0 : heartIndex
                        photoModel.setRating(detailView.photoId, newRating)
                        heartRow.currentRating = newRating
                    }
                }
            }
        }
    }

    // Tag chips row
    Row {
        id: tagRow
        anchors.bottom: fileInfoLabel.top
        anchors.bottomMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        visible: hasContent

        property var assignedTags: hasContent ? tagModel.tagsForPhoto(photoId) : []
        property bool dropdownOpen: false

        Connections {
            target: detailView
            function onPhotoIdChanged() {
                tagRow.assignedTags = detailView.hasContent ? tagModel.tagsForPhoto(detailView.photoId) : []
                tagRow.dropdownOpen = false
            }
        }

        Connections {
            target: tagModel
            function onTagsChanged() {
                if (detailView.hasContent)
                    tagRow.assignedTags = tagModel.tagsForPhoto(detailView.photoId)
            }
        }

        // Assigned tag chips
        Repeater {
            model: tagRow.assignedTags

            Rectangle {
                required property var modelData
                implicitWidth: chipRow.implicitWidth + 12
                implicitHeight: 24
                radius: 12
                color: tagModel.tagColor(modelData)

                RowLayout {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 3

                    Label {
                        text: tagModel.tagIcon(modelData)
                        font.pixelSize: 10
                        visible: text !== ""
                    }
                    Label {
                        text: tagModel.tagName(modelData)
                        color: "#ffffff"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    Label {
                        text: "\u2715"
                        color: "#dddddd"
                        font.pixelSize: 9

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                tagModel.removeTagFromPhoto(detailView.photoId, modelData)
                                tagRow.assignedTags = tagModel.tagsForPhoto(detailView.photoId)
                            }
                        }
                    }
                }
            }
        }

        // Add tag button
        Rectangle {
            implicitWidth: 24
            implicitHeight: 24
            radius: 12
            color: addTagBtnArea.containsMouse ? "#555555" : "#3a3a3a"

            Label {
                anchors.centerIn: parent
                text: "+"
                color: "#aaaaaa"
                font.pixelSize: 14
            }

            MouseArea {
                id: addTagBtnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tagRow.dropdownOpen = !tagRow.dropdownOpen
            }
        }
    }

    // Tag dropdown
    Rectangle {
        visible: tagRow.dropdownOpen && hasContent
        anchors.bottom: fileInfoLabel.top
        anchors.bottomMargin: 36
        anchors.horizontalCenter: parent.horizontalCenter
        width: 220
        height: Math.min(tagDropdownCol.implicitHeight + 16, 200)
        radius: 8
        color: "#2a2a2a"
        border.width: 1
        border.color: "#444444"
        z: 20
        clip: true

        Flickable {
            anchors.fill: parent
            anchors.margins: 8
            contentHeight: tagDropdownCol.implicitHeight
            clip: true

            Column {
                id: tagDropdownCol
                width: parent.width
                spacing: 2

                Label {
                    visible: tagModel.count === 0
                    text: "Keine Tags vorhanden"
                    color: "#888888"
                    font.pixelSize: 12
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    padding: 8
                }

                Repeater {
                    model: tagModel

                    Rectangle {
                        required property var tagId
                        required property string name
                        required property string tagColor
                        required property string tagIcon

                        readonly property bool isAssigned: {
                            for (var i = 0; i < tagRow.assignedTags.length; ++i) {
                                if (tagRow.assignedTags[i] === tagId) return true
                            }
                            return false
                        }

                        width: tagDropdownCol.width
                        height: 30
                        radius: 4
                        color: dropItemArea.containsMouse ? "#444444" : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                color: tagColor
                            }

                            Label {
                                text: tagIcon
                                font.pixelSize: 11
                                visible: text !== ""
                            }

                            Label {
                                text: name
                                color: "#ffffff"
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }

                            Label {
                                text: isAssigned ? "\u2713" : ""
                                color: root.accentColor
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: dropItemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (isAssigned) {
                                    tagModel.removeTagFromPhoto(detailView.photoId, tagId)
                                } else {
                                    tagModel.addTagToPhoto(detailView.photoId, tagId)
                                }
                                tagRow.assignedTags = tagModel.tagsForPhoto(detailView.photoId)
                            }
                        }
                    }
                }
            }
        }
    }

    // File name and resolution at bottom
    Label {
        id: fileInfoLabel
        anchors.bottom: isVideo ? parent.bottom : parent.bottom
        anchors.bottomMargin: isVideo ? 56 : 12
        anchors.horizontalCenter: parent.horizontalCenter
        text: {
            if (filePath === "") return ""
            var name = filePath.split("/").pop()
            var res = photoModel.resolutionForId(photoId)
            return res !== "" ? name + "  ·  " + res : name
        }
        color: "#888888"
        font.pixelSize: 11
        visible: hasContent
    }
}
