import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Rectangle {
    id: slideshowView
    color: "#000000"
    visible: false
    z: 200

    property var photoIds: []
    property int currentIndex: 0
    property int intervalSeconds: 5
    property bool running: false

    readonly property qint64 currentPhotoId: photoIds.length > 0 ? photoIds[currentIndex] : -1
    readonly property string filePath: currentPhotoId > 0 ? photoModel.filePathForId(currentPhotoId) : ""
    readonly property int mediaType: currentPhotoId > 0 ? photoModel.mediaTypeForId(currentPhotoId) : 0
    readonly property string liveVideoPath: currentPhotoId > 0 ? photoModel.liveVideoPathForId(currentPhotoId) : ""
    readonly property bool isVideo: mediaType === 1
    readonly property bool isLivePhoto: mediaType === 2
    readonly property bool hasContent: currentPhotoId > 0 && filePath !== ""

    signal closed()

    function start(ids, seconds) {
        if (ids.length === 0) return
        photoIds = ids
        intervalSeconds = seconds
        currentIndex = 0
        visible = true
        running = true
        forceActiveFocus()
        loadCurrentMedia()
    }

    function stop() {
        running = false
        slideshowTimer.stop()
        ssPlayer.stop()
        ssPlayer.source = ""
        visible = false
        closed()
    }

    function goNext() {
        if (photoIds.length === 0) return
        if (currentIndex < photoIds.length - 1) {
            currentIndex++
        } else {
            // Loop back to start
            currentIndex = 0
        }
        loadCurrentMedia()
    }

    function goPrevious() {
        if (photoIds.length === 0) return
        if (currentIndex > 0) {
            currentIndex--
        } else {
            currentIndex = photoIds.length - 1
        }
        loadCurrentMedia()
    }

    function loadCurrentMedia() {
        slideshowTimer.stop()
        ssPlayer.stop()
        ssPlayer.source = ""

        if (!hasContent) return

        if (isVideo) {
            ssPlayer.source = "file:///" + filePath
            // Timer starts when video ends
        } else if (isLivePhoto && liveVideoPath !== "") {
            ssPlayer.source = "file:///" + liveVideoPath
            // Timer starts when live video ends
        } else {
            // Static photo — start timer
            if (running) {
                slideshowTimer.interval = intervalSeconds * 1000
                slideshowTimer.start()
            }
        }
    }

    // Auto-advance timer
    Timer {
        id: slideshowTimer
        repeat: false
        onTriggered: {
            if (slideshowView.running) {
                slideshowView.goNext()
            }
        }
    }

    // Keyboard
    focus: true
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            slideshowView.stop()
            event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Space) {
            slideshowView.goNext()
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            slideshowView.goPrevious()
            event.accepted = true
        }
    }

    // Full-size image
    Image {
        id: ssImage
        anchors.fill: parent
        visible: hasContent && !isVideo
        source: hasContent && !isVideo ? "file:///" + filePath : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: false

        opacity: status === Image.Ready ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    // Video player
    AudioOutput { id: ssAudio }
    MediaPlayer {
        id: ssPlayer
        videoOutput: ssVideoOutput
        audioOutput: ssAudio
        loops: 1

        onSourceChanged: {
            if (source.toString() !== "") {
                play()
            }
        }

        onPlaybackStateChanged: {
            // When video/live photo finishes playing, advance
            if (playbackState === MediaPlayer.StoppedState && source.toString() !== "" && slideshowView.running) {
                slideshowView.goNext()
            }
        }
    }

    VideoOutput {
        id: ssVideoOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
        visible: hasContent && (isVideo || isLivePhoto)
                 && ssPlayer.playbackState !== MediaPlayer.StoppedState
    }

    // Loading spinner
    BusyIndicator {
        anchors.centerIn: parent
        running: hasContent && !isVideo && ssImage.status === Image.Loading
        visible: running
    }

    // Click to pause/resume
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (slideshowView.running) {
                slideshowView.running = false
                slideshowTimer.stop()
                if (ssPlayer.playbackState === MediaPlayer.PlayingState)
                    ssPlayer.pause()
            } else {
                slideshowView.running = true
                if (ssPlayer.playbackState === MediaPlayer.PausedState) {
                    ssPlayer.play()
                } else if (!slideshowView.isVideo && !slideshowView.isLivePhoto) {
                    slideshowTimer.interval = slideshowView.intervalSeconds * 1000
                    slideshowTimer.start()
                }
            }
        }
    }

    // Navigation arrows (visible on mouse movement)
    property bool controlsVisible: true
    Timer {
        id: hideControlsTimer
        interval: 3000
        onTriggered: slideshowView.controlsVisible = false
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: {
            slideshowView.controlsVisible = true
            hideControlsTimer.restart()
        }
    }

    // Previous arrow
    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 20
        width: 48
        height: 48
        radius: 24
        color: prevSSArea.containsMouse ? "#80ffffff" : "#40ffffff"
        visible: controlsVisible && photoIds.length > 1
        opacity: controlsVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Label {
            anchors.centerIn: parent
            text: "\u276E"
            color: "#ffffff"
            font.pixelSize: 24
        }

        MouseArea {
            id: prevSSArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: slideshowView.goPrevious()
        }
    }

    // Next arrow
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 20
        width: 48
        height: 48
        radius: 24
        color: nextSSArea.containsMouse ? "#80ffffff" : "#40ffffff"
        visible: controlsVisible && photoIds.length > 1
        opacity: controlsVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Label {
            anchors.centerIn: parent
            text: "\u276F"
            color: "#ffffff"
            font.pixelSize: 24
        }

        MouseArea {
            id: nextSSArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: slideshowView.goNext()
        }
    }

    // Bottom info bar
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 40
        color: "#80000000"
        visible: controlsVisible
        opacity: controlsVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20

            // Pause/Play indicator
            Label {
                text: slideshowView.running ? "\u23F8" : "\u25B6"
                color: "#ffffff"
                font.pixelSize: 16
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (slideshowView.running) {
                            slideshowView.running = false
                            slideshowTimer.stop()
                            if (ssPlayer.playbackState === MediaPlayer.PlayingState)
                                ssPlayer.pause()
                        } else {
                            slideshowView.running = true
                            slideshowView.loadCurrentMedia()
                        }
                    }
                }
            }

            // Counter
            Label {
                text: (slideshowView.currentIndex + 1) + " / " + slideshowView.photoIds.length
                color: "#cccccc"
                font.pixelSize: 13
            }

            Item { Layout.fillWidth: true }

            // Close button
            Label {
                text: "ESC Beenden"
                color: "#999999"
                font.pixelSize: 12
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: slideshowView.stop()
                }
            }
        }
    }
}
