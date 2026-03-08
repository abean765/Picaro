import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Rectangle {
    id: detailView
    color: "#111111"

    property int photoId: -1

    signal closed()
    signal navigateNext()
    signal navigatePrevious()

    // Derived properties from current photoId
    readonly property string filePath: photoId > 0 ? photoModel.filePathForId(photoId) : ""
    readonly property int mediaType: photoId > 0 ? photoModel.mediaTypeForId(photoId) : 0
    readonly property string liveVideoPath: photoId > 0 ? photoModel.liveVideoPathForId(photoId) : ""
    readonly property bool isVideo: mediaType === 1
    readonly property bool isLivePhoto: mediaType === 2
    readonly property bool hasContent: photoId > 0 && filePath !== ""

    // Stop video when photo changes or view closes
    // Query model directly to avoid stale derived properties (QML binding order is not guaranteed)
    onPhotoIdChanged: {
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
        cache: false

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
    MediaPlayer {
        id: detailPlayer
        videoOutput: detailVideoOutput
        loops: isLivePhoto ? MediaPlayer.Infinite : 1
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
                text: {
                    var pos = Math.floor(detailPlayer.position / 1000)
                    var dur = Math.floor(detailPlayer.duration / 1000)
                    var fm = function(s) {
                        var m = Math.floor(s / 60)
                        var sec = s % 60
                        return m + ":" + (sec < 10 ? "0" : "") + sec
                    }
                    return fm(pos) + " / " + fm(dur)
                }
                color: "#cccccc"
                font.pixelSize: 12
            }
        }
    }

    // LivePhoto badge
    Rectangle {
        visible: isLivePhoto && hasContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 16
        width: liveBadge.implicitWidth + 16
        height: liveBadge.implicitHeight + 8
        radius: 6
        color: "#90000000"

        Label {
            id: liveBadge
            anchors.centerIn: parent
            text: "LIVE"
            color: "#ffffff"
            font.pixelSize: 14
            font.bold: true
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

    // File name and resolution at bottom
    Label {
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
