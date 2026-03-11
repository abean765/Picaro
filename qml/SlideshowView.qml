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
    property int activeLayer: 0  // 0 = Layer A is front, 1 = Layer B is front
    property bool layerAIsVideo: false
    property bool layerBIsVideo: false

    readonly property int currentPhotoId: photoIds.length > 0 ? photoIds[currentIndex] : -1
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
        activeLayer = 0
        layerAIsVideo = false
        layerBIsVideo = false
        ssPlayerA.stop(); ssPlayerA.source = ""
        ssPlayerB.stop(); ssPlayerB.source = ""
        ssImageA.source = ""
        ssImageB.source = ""
        layerA.opacity = 0.0
        layerB.opacity = 0.0
        visible = true
        running = true
        forceActiveFocus()
        loadCurrentMedia()
    }

    function stop() {
        running = false
        slideshowTimer.stop()
        ssPlayerA.stop(); ssPlayerA.source = ""
        ssPlayerB.stop(); ssPlayerB.source = ""
        ssImageA.source = ""
        ssImageB.source = ""
        layerA.opacity = 0.0
        layerB.opacity = 0.0
        visible = false
        closed()
    }

    function goNext() {
        if (photoIds.length === 0) return
        if (currentIndex < photoIds.length - 1) {
            currentIndex++
        } else {
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

        if (!hasContent) return

        var filePrefix = Qt.platform.os === "windows" ? "file:///" : "file://"
        var isVideoContent = isVideo || (isLivePhoto && liveVideoPath !== "")

        if (activeLayer === 0) {
            // A is front — load new content into B
            ssPlayerB.stop(); ssPlayerB.source = ""
            ssImageB.source = ""
            layerBIsVideo = isVideoContent
            if (isVideo) {
                ssPlayerB.source = filePrefix + filePath
            } else if (isLivePhoto && liveVideoPath !== "") {
                ssPlayerB.source = filePrefix + liveVideoPath
            } else {
                ssImageB.source = filePrefix + filePath
            }
        } else {
            // B is front — load new content into A
            ssPlayerA.stop(); ssPlayerA.source = ""
            ssImageA.source = ""
            layerAIsVideo = isVideoContent
            if (isVideo) {
                ssPlayerA.source = filePrefix + filePath
            } else if (isLivePhoto && liveVideoPath !== "") {
                ssPlayerA.source = filePrefix + liveVideoPath
            } else {
                ssImageA.source = filePrefix + filePath
            }
        }
    }

    function crossfadeToA() {
        layerA.opacity = 1.0
        layerB.opacity = 0.0
        activeLayer = 0
        ssPlayerB.stop()
        ssPlayerB.source = ""
        ssImageB.source = ""
    }

    function crossfadeToB() {
        layerB.opacity = 1.0
        layerA.opacity = 0.0
        activeLayer = 1
        ssPlayerA.stop()
        ssPlayerA.source = ""
        ssImageA.source = ""
    }

    // Auto-advance timer (for static photos)
    Timer {
        id: slideshowTimer
        repeat: false
        onTriggered: {
            if (slideshowView.running) slideshowView.goNext()
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

    // ── Layer A ──────────────────────────────────────────────────────────────
    Item {
        id: layerA
        anchors.fill: parent
        opacity: 0.0
        Behavior on opacity { NumberAnimation { duration: 600 } }

        Image {
            id: ssImageA
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: !layerAIsVideo

            onStatusChanged: {
                if (status === Image.Ready && slideshowView.activeLayer === 1) {
                    slideshowView.crossfadeToA()
                    if (slideshowView.running) {
                        slideshowTimer.interval = slideshowView.intervalSeconds * 1000
                        slideshowTimer.start()
                    }
                }
            }
        }

        VideoOutput {
            id: ssVideoOutputA
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
            visible: layerAIsVideo
        }
    }

    // ── Layer B ──────────────────────────────────────────────────────────────
    Item {
        id: layerB
        anchors.fill: parent
        opacity: 0.0
        Behavior on opacity { NumberAnimation { duration: 600 } }

        Image {
            id: ssImageB
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: !layerBIsVideo

            onStatusChanged: {
                if (status === Image.Ready && slideshowView.activeLayer === 0) {
                    slideshowView.crossfadeToB()
                    if (slideshowView.running) {
                        slideshowTimer.interval = slideshowView.intervalSeconds * 1000
                        slideshowTimer.start()
                    }
                }
            }
        }

        VideoOutput {
            id: ssVideoOutputB
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
            visible: layerBIsVideo
        }
    }

    // ── Media Players ────────────────────────────────────────────────────────
    AudioOutput { id: ssAudioA }
    MediaPlayer {
        id: ssPlayerA
        videoOutput: ssVideoOutputA
        audioOutput: ssAudioA
        loops: 1

        onSourceChanged: {
            if (source.toString() !== "") play()
        }

        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.PlayingState && slideshowView.activeLayer === 1) {
                // A just started as new layer — crossfade in
                slideshowView.crossfadeToA()
            }
            if (playbackState === MediaPlayer.StoppedState
                    && source.toString() !== ""
                    && slideshowView.activeLayer === 0
                    && slideshowView.running) {
                // A finished playing as active layer — advance
                slideshowView.goNext()
            }
        }
    }

    AudioOutput { id: ssAudioB }
    MediaPlayer {
        id: ssPlayerB
        videoOutput: ssVideoOutputB
        audioOutput: ssAudioB
        loops: 1

        onSourceChanged: {
            if (source.toString() !== "") play()
        }

        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.PlayingState && slideshowView.activeLayer === 0) {
                // B just started as new layer — crossfade in
                slideshowView.crossfadeToB()
            }
            if (playbackState === MediaPlayer.StoppedState
                    && source.toString() !== ""
                    && slideshowView.activeLayer === 1
                    && slideshowView.running) {
                // B finished playing as active layer — advance
                slideshowView.goNext()
            }
        }
    }

    // Loading spinner
    BusyIndicator {
        anchors.centerIn: parent
        running: hasContent && !isVideo
                 && (ssImageA.status === Image.Loading || ssImageB.status === Image.Loading)
        visible: running
    }

    // Click to pause/resume
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (slideshowView.running) {
                slideshowView.running = false
                slideshowTimer.stop()
                if (ssPlayerA.playbackState === MediaPlayer.PlayingState) ssPlayerA.pause()
                if (ssPlayerB.playbackState === MediaPlayer.PlayingState) ssPlayerB.pause()
            } else {
                slideshowView.running = true
                if (ssPlayerA.playbackState === MediaPlayer.PausedState) {
                    ssPlayerA.play()
                } else if (ssPlayerB.playbackState === MediaPlayer.PausedState) {
                    ssPlayerB.play()
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
        width: 48; height: 48; radius: 24
        color: prevSSArea.containsMouse ? "#80ffffff" : "#40ffffff"
        visible: controlsVisible && photoIds.length > 1
        opacity: controlsVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Label { anchors.centerIn: parent; text: "\u276E"; color: "#ffffff"; font.pixelSize: 24 }
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
        width: 48; height: 48; radius: 24
        color: nextSSArea.containsMouse ? "#80ffffff" : "#40ffffff"
        visible: controlsVisible && photoIds.length > 1
        opacity: controlsVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Label { anchors.centerIn: parent; text: "\u276F"; color: "#ffffff"; font.pixelSize: 24 }
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

            Label {
                text: slideshowView.running ? "\u23F8" : "\u25B6"
                color: "#ffffff"
                font.pixelSize: 16
                MouseArea {
                    anchors.fill: parent; anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (slideshowView.running) {
                            slideshowView.running = false
                            slideshowTimer.stop()
                            if (ssPlayerA.playbackState === MediaPlayer.PlayingState) ssPlayerA.pause()
                            if (ssPlayerB.playbackState === MediaPlayer.PlayingState) ssPlayerB.pause()
                        } else {
                            slideshowView.running = true
                            slideshowView.loadCurrentMedia()
                        }
                    }
                }
            }

            Label {
                text: (slideshowView.currentIndex + 1) + " / " + slideshowView.photoIds.length
                color: "#cccccc"
                font.pixelSize: 13
            }

            Item { Layout.fillWidth: true }

            Label {
                text: "ESC Beenden"
                color: "#999999"
                font.pixelSize: 12
                MouseArea {
                    anchors.fill: parent; anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: slideshowView.stop()
                }
            }
        }
    }
}
