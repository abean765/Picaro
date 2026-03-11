import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Fullscreen photo-editing overlay.
// Open via  editView.open(photoId, filePath, mediaType)
// Signals:  closed(), savedAndReload(photoId)
Rectangle {
    id: editView
    color: "#0d0d0d"
    visible: false

    property int    photoId:   -1
    property string filePath:  ""
    property int    mediaType: 0   // 0=Photo, 1=Video, 2=LivePhoto

    // ── edit state ──────────────────────────────────────────────────────────
    // Licht
    property real brightness: 0.0
    property real contrast:   0.0
    property real highlights: 0.0
    property real shadows:    0.0
    property real blacks:     0.0
    property real whites:     0.0
    // Farbe
    property real saturation: 0.0
    property real vibrance:   0.0
    property real warmth:     0.0
    property real tint:       0.0
    // Details
    property real clarity:         0.0
    property real sharpness:       0.0
    property real noiseReduction:  0.0
    // Effekte
    property real vignette:   0.0
    property real grain:      0.0
    // Geometrie
    property int  rotation:   0      // 0 / 90 / 180 / 270
    property bool flipH:      false

    property bool saving:     false

    // version counter – incremented by the debounce timer to trigger reload
    property int  editVersion: 0

    signal closed()
    signal savedAndReload(int photoId)

    // ── public API ──────────────────────────────────────────────────────────
    function open(pid, fp, mt) {
        photoId   = pid
        filePath  = fp
        mediaType = mt
        resetAll()
        visible   = true
        forceActiveFocus()
    }

    // Active filter name (for chip highlighting)
    property string activeFilter: "Original"

    // ── Instagram-style retro filter presets ─────────────────────────────────
    readonly property var filterPresets: [
        { name: "Original",  brightness:0,     contrast:0,     highlights:0,    shadows:0,    blacks:0,     whites:0,    saturation:0,    vibrance:0,    warmth:0,     tint:0,     clarity:0,     sharpness:0,  noiseReduction:0,   vignette:0,    grain:0    },
        // ── warm & faded ──
        { name: "Nashville", brightness:0.05,  contrast:-0.1,  highlights:0.1,  shadows:0.15, blacks:-0.05, whites:0,    saturation:-0.1, vibrance:0,    warmth:0.30,  tint:0.15,  clarity:0,     sharpness:0,  noiseReduction:0,   vignette:-0.15, grain:0.12 },
        { name: "1977",      brightness:0.05,  contrast:0.05,  highlights:0,    shadows:0.2,  blacks:-0.05, whites:0,    saturation:-0.1, vibrance:0,    warmth:0.20,  tint:0.10,  clarity:0,     sharpness:0,  noiseReduction:0,   vignette:-0.2,  grain:0.20 },
        { name: "Earlybird", brightness:0.05,  contrast:-0.1,  highlights:0.05, shadows:0.2,  blacks:0,     whites:0,    saturation:-0.2, vibrance:0,    warmth:0.30,  tint:0.10,  clarity:0,     sharpness:0,  noiseReduction:0.1, vignette:-0.30, grain:0.15 },
        { name: "Rise",      brightness:0.10,  contrast:-0.1,  highlights:0.05, shadows:0.25, blacks:-0.05, whites:0.05, saturation:-0.1, vibrance:0.10, warmth:0.35,  tint:0.05,  clarity:0,     sharpness:0,  noiseReduction:0,   vignette:-0.15, grain:0.08 },
        { name: "Valencia",  brightness:0.05,  contrast:0.05,  highlights:0.10, shadows:0.10, blacks:-0.05, whites:0.05, saturation:-0.05,vibrance:0.15, warmth:0.20,  tint:0,     clarity:0,     sharpness:0,  noiseReduction:0,   vignette:-0.10, grain:0.05 },
        // ── rich & vivid ──
        { name: "Lo-Fi",     brightness:-0.05, contrast:0.30,  highlights:-0.1, shadows:-0.2, blacks:0.10,  whites:0,    saturation:0.30, vibrance:0.20, warmth:0,     tint:0,     clarity:0.20,  sharpness:0.2,noiseReduction:0,   vignette:-0.70, grain:0    },
        { name: "Hefe",      brightness:0,     contrast:0.25,  highlights:0,    shadows:-0.1, blacks:0.15,  whites:0,    saturation:0.15, vibrance:0.20, warmth:0.25,  tint:0,     clarity:0.10,  sharpness:0.1,noiseReduction:0,   vignette:-0.30, grain:0.05 },
        { name: "X-Pro II",  brightness:-0.05, contrast:0.40,  highlights:0,    shadows:0.05, blacks:0.10,  whites:0,    saturation:0.25, vibrance:0.10, warmth:0.10,  tint:0,     clarity:0,     sharpness:0.1,noiseReduction:0,   vignette:-0.80, grain:0    },
        { name: "Toaster",   brightness:0,     contrast:0.20,  highlights:0,    shadows:-0.1, blacks:0.20,  whites:0,    saturation:-0.1, vibrance:0,    warmth:0.40,  tint:0,     clarity:0,     sharpness:0,  noiseReduction:0,   vignette:-0.90, grain:0.10 },
        // ── cool & faded ──
        { name: "Brannan",   brightness:0,     contrast:0.30,  highlights:-0.05,shadows:0,    blacks:0.10,  whites:0,    saturation:-0.1, vibrance:0,    warmth:-0.20, tint:-0.05, clarity:0,     sharpness:0.2,noiseReduction:0,   vignette:-0.50, grain:0.08 },
        { name: "Hudson",    brightness:0.10,  contrast:0.05,  highlights:0.05, shadows:0.10, blacks:-0.05, whites:0.10, saturation:-0.15,vibrance:0,    warmth:-0.25, tint:0,     clarity:0,     sharpness:0,  noiseReduction:0,   vignette:-0.20, grain:0    },
        { name: "Walden",    brightness:0.05,  contrast:-0.05, highlights:0.05, shadows:0.20, blacks:-0.05, whites:0.05, saturation:-0.15,vibrance:0,    warmth:-0.10, tint:-0.05, clarity:0,     sharpness:0,  noiseReduction:0.1, vignette:-0.10, grain:0.10 },
        // ── matte & soft ──
        { name: "Sierra",    brightness:0,     contrast:-0.15, highlights:0.05, shadows:0.20, blacks:-0.10, whites:0.05, saturation:-0.15,vibrance:0,    warmth:0.05,  tint:0,     clarity:-0.05, sharpness:0,  noiseReduction:0.1, vignette:-0.15, grain:0.08 },
        { name: "Sutro",     brightness:-0.10, contrast:0.10,  highlights:-0.1, shadows:0.10, blacks:0.05,  whites:0,    saturation:-0.3, vibrance:0,    warmth:0.10,  tint:0.05,  clarity:0.10,  sharpness:0,  noiseReduction:0.1, vignette:-0.60, grain:0.12 },
        // ── black & white ──
        { name: "Inkwell",   brightness:0,     contrast:0.10,  highlights:0,    shadows:0,    blacks:0,     whites:0,    saturation:-1.0, vibrance:0,    warmth:0,     tint:0,     clarity:0.10,  sharpness:0.1,noiseReduction:0,   vignette:-0.15, grain:0.10 },
    ]

    function applyFilter(f) {
        brightness    = f.brightness
        contrast      = f.contrast
        highlights    = f.highlights
        shadows       = f.shadows
        blacks        = f.blacks
        whites        = f.whites
        saturation    = f.saturation
        vibrance      = f.vibrance
        warmth        = f.warmth
        tint          = f.tint
        clarity       = f.clarity
        sharpness     = f.sharpness
        noiseReduction = f.noiseReduction
        vignette      = f.vignette
        grain         = f.grain
        activeFilter  = f.name
    }

    function resetAll() {
        brightness = 0; contrast  = 0; highlights = 0; shadows = 0
        blacks     = 0; whites    = 0; saturation = 0; vibrance = 0
        warmth     = 0; tint      = 0; clarity    = 0; sharpness = 0
        noiseReduction = 0; vignette = 0; grain = 0
        rotation   = 0; flipH     = false
        activeFilter = "Original"
        editVersion = 0
    }

    // Trigger debounced preview refresh whenever any param changes
    onBrightnessChanged:    updateTimer.restart()
    onContrastChanged:      updateTimer.restart()
    onHighlightsChanged:    updateTimer.restart()
    onShadowsChanged:       updateTimer.restart()
    onBlacksChanged:        updateTimer.restart()
    onWhitesChanged:        updateTimer.restart()
    onSaturationChanged:    updateTimer.restart()
    onVibranceChanged:      updateTimer.restart()
    onWarmthChanged:        updateTimer.restart()
    onTintChanged:          updateTimer.restart()
    onClarityChanged:       updateTimer.restart()
    onSharpnessChanged:     updateTimer.restart()
    onNoiseReductionChanged: updateTimer.restart()
    onVignetteChanged:      updateTimer.restart()
    onGrainChanged:         updateTimer.restart()
    onRotationChanged:      updateTimer.restart()
    onFlipHChanged:         updateTimer.restart()

    Timer {
        id: updateTimer
        interval: 90
        onTriggered: editVersion++
    }

    // Build the provider URL – version suffix forces reload on param change
    readonly property string previewUrl: {
        if (photoId <= 0 || !visible) return ""
        return "image://editor/"
            + photoId + "_v" + editVersion
            + "?b="  + brightness.toFixed(3)
            + "&c="  + contrast.toFixed(3)
            + "&hl=" + highlights.toFixed(3)
            + "&sh=" + shadows.toFixed(3)
            + "&bl=" + blacks.toFixed(3)
            + "&wp=" + whites.toFixed(3)
            + "&s="  + saturation.toFixed(3)
            + "&vi=" + vibrance.toFixed(3)
            + "&w="  + warmth.toFixed(3)
            + "&ti=" + tint.toFixed(3)
            + "&cl=" + clarity.toFixed(3)
            + "&sp=" + sharpness.toFixed(3)
            + "&nr=" + noiseReduction.toFixed(3)
            + "&vg=" + vignette.toFixed(3)
            + "&gr=" + grain.toFixed(3)
            + "&r="  + rotation
            + "&fh=" + (flipH ? 1 : 0)
    }

    // ── keyboard shortcuts ──────────────────────────────────────────────────
    focus: true
    Keys.onEscapePressed: { if (!saving) editView.closed() }

    // ── top bar ──────────────────────────────────────────────────────────────
    Rectangle {
        id: topBar
        anchors.top:   parent.top
        anchors.left:  parent.left
        anchors.right: parent.right
        height: 52
        color: "#1a1a1a"

        // Cancel
        Rectangle {
            anchors.left:           parent.left
            anchors.leftMargin:     16
            anchors.verticalCenter: parent.verticalCenter
            width:  cancelLbl.implicitWidth + 24
            height: 32
            radius: 6
            color:  cancelArea.containsMouse ? "#3a3a3a" : "#2a2a2a"
            enabled: !saving

            Label {
                id: cancelLbl
                anchors.centerIn: parent
                text: "Abbrechen"
                color: "#cccccc"
                font.pixelSize: 13
            }
            MouseArea {
                id: cancelArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onClicked: editView.closed()
            }
        }

        // Title
        Label {
            anchors.centerIn: parent
            text: "Bearbeiten"
            color: "#ffffff"
            font.pixelSize: 15
            font.bold: true
        }

        // Save
        Rectangle {
            id: saveBtn
            anchors.right:          parent.right
            anchors.rightMargin:    16
            anchors.verticalCenter: parent.verticalCenter
            width:  saveLbl.implicitWidth + 24
            height: 32
            radius: 6
            color: saving ? "#555555"
                          : (saveArea.containsMouse ? Qt.lighter(root.accentColor, 1.15)
                                                    : root.accentColor)
            enabled: !saving

            Label {
                id: saveLbl
                anchors.centerIn: parent
                text: saving ? "Speichern …" : "Speichern"
                color: "#ffffff"
                font.pixelSize: 13
                font.bold: true
            }
            MouseArea {
                id: saveArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onClicked: {
                    if (saving) return
                    saving = true
                    var p = {
                        brightness:    editView.brightness,
                        contrast:      editView.contrast,
                        highlights:    editView.highlights,
                        shadows:       editView.shadows,
                        blacks:        editView.blacks,
                        whites:        editView.whites,
                        saturation:    editView.saturation,
                        vibrance:      editView.vibrance,
                        warmth:        editView.warmth,
                        tint:          editView.tint,
                        clarity:       editView.clarity,
                        sharpness:     editView.sharpness,
                        noiseReduction: editView.noiseReduction,
                        vignette:      editView.vignette,
                        grain:         editView.grain,
                        rotation:      editView.rotation,
                        flipH:         editView.flipH
                    }
                    photoEditor.saveEdits(editView.photoId, p)
                }
            }
        }
    }

    // ── main area: preview on left, controls panel on right ──────────────────
    Item {
        id: previewArea
        anchors.top:    topBar.bottom
        anchors.left:   parent.left
        anchors.right:  controlPanel.left
        anchors.bottom: parent.bottom

        // Previous image (shown while next is loading to avoid flash)
        Image {
            id: previousImage
            anchors.fill:    parent
            anchors.margins: 12
            fillMode:        Image.PreserveAspectFit
            visible:         currentImage.status !== Image.Ready
        }

        Image {
            id: currentImage
            anchors.fill:    parent
            anchors.margins: 12
            fillMode:        Image.PreserveAspectFit
            source:          editView.previewUrl
            cache:           false
            asynchronous:    true

            opacity: status === Image.Ready ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            onStatusChanged: {
                if (status === Image.Ready)
                    previousImage.source = source
            }
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: currentImage.status === Image.Loading
            visible: running
        }

        // "Video-Bearbeitung nicht unterstützt" overlay for videos
        Rectangle {
            anchors.centerIn: parent
            width:  noEditLbl.implicitWidth + 32
            height: 44
            radius: 8
            color:  "#80000000"
            visible: editView.mediaType === 1

            Label {
                id: noEditLbl
                anchors.centerIn: parent
                text: "Videobearbeitung: nur Drehen/Spiegeln verfügbar"
                color: "#cccccc"
                font.pixelSize: 13
            }
        }
    }

    // ── right control panel ──────────────────────────────────────────────────
    Rectangle {
        id: controlPanel
        anchors.top:    topBar.bottom
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        width: 290
        color: "#161616"

        ScrollView {
            anchors.fill: parent
            contentWidth: controlPanel.width
            clip: true

            Column {
                id: controlCol
                width: controlPanel.width
                spacing: 0

                // ── Filter presets ────────────────────────────────────────────
                Item { width: controlCol.width; height: 12; visible: editView.mediaType !== 1 }

                Label {
                    leftPadding: 20
                    text: "Filter"
                    color: "#888888"
                    font.pixelSize: 11
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    width: controlCol.width
                    visible: editView.mediaType !== 1
                }
                Item { width: controlCol.width; height: 8; visible: editView.mediaType !== 1 }

                // Horizontally scrollable filter chip row
                Flickable {
                    width: controlCol.width
                    height: 62
                    contentWidth: filterRow.implicitWidth + 32
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    visible: editView.mediaType !== 1

                    Row {
                        id: filterRow
                        x: 16
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: editView.filterPresets

                            delegate: Rectangle {
                                width:  chipLbl.implicitWidth + 20
                                height: 46
                                radius: 8
                                color:  editView.activeFilter === modelData.name
                                        ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25)
                                        : (chipArea.containsMouse ? "#333333" : "#252525")
                                border.color: editView.activeFilter === modelData.name
                                              ? root.accentColor : "transparent"
                                border.width: 1.5

                                Label {
                                    id: chipLbl
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    font.pixelSize: 11
                                    color: editView.activeFilter === modelData.name
                                           ? root.accentColor : "#cccccc"
                                }
                                MouseArea {
                                    id: chipArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape:  Qt.PointingHandCursor
                                    onClicked:    editView.applyFilter(modelData)
                                }
                            }
                        }
                    }
                }

                Item { width: controlCol.width; height: 4; visible: editView.mediaType !== 1 }

                // Section: Drehen & Spiegeln
                Rectangle {
                    width:  controlCol.width
                    height: 1
                    color:  "#2a2a2a"
                }
                Item { width: controlCol.width; height: 16 }

                Label {
                    leftPadding: 20
                    text: "Drehen & Spiegeln"
                    color: "#888888"
                    font.pixelSize: 11
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    width: controlCol.width
                }
                Item { width: controlCol.width; height: 10 }

                // Rotate / flip buttons
                Row {
                    leftPadding:  20
                    spacing:      10

                    // Rotate left
                    Rectangle {
                        width: 44; height: 44; radius: 8
                        color: rotLArea.containsMouse ? "#3a3a3a" : "#252525"
                        Label {
                            anchors.centerIn: parent
                            text: "\u21B6"   // ↶ counterclockwise arrow
                            font.pixelSize: 22
                            color: "#dddddd"
                        }
                        MouseArea {
                            id: rotLArea
                            anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                editView.rotation = (editView.rotation - 90 + 360) % 360
                            }
                        }
                        ToolTip.delay: 600; ToolTip.text: "Links drehen (90°)"
                        ToolTip.visible: rotLArea.containsMouse
                    }

                    // Rotate right
                    Rectangle {
                        width: 44; height: 44; radius: 8
                        color: rotRArea.containsMouse ? "#3a3a3a" : "#252525"
                        Label {
                            anchors.centerIn: parent
                            text: "\u21B7"   // ↷ clockwise arrow
                            font.pixelSize: 22
                            color: "#dddddd"
                        }
                        MouseArea {
                            id: rotRArea
                            anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                editView.rotation = (editView.rotation + 90) % 360
                            }
                        }
                        ToolTip.delay: 600; ToolTip.text: "Rechts drehen (90°)"
                        ToolTip.visible: rotRArea.containsMouse
                    }

                    // Flip horizontal
                    Rectangle {
                        width: 44; height: 44; radius: 8
                        color: flipHArea.containsMouse ? "#3a3a3a" : "#252525"
                        border.color: editView.flipH ? root.accentColor : "transparent"
                        border.width: editView.flipH ? 2 : 0
                        Label {
                            anchors.centerIn: parent
                            text: "\u21C4"   // ⇄ left-right arrows
                            font.pixelSize: 20
                            color: editView.flipH ? root.accentColor : "#dddddd"
                        }
                        MouseArea {
                            id: flipHArea
                            anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: editView.flipH = !editView.flipH
                        }
                        ToolTip.delay: 600; ToolTip.text: "Horizontal spiegeln"
                        ToolTip.visible: flipHArea.containsMouse
                    }
                }

                Item { width: controlCol.width; height: 20 }

                // ── Colour section header ─────────────────────────────────────
                Rectangle {
                    width:  controlCol.width
                    height: 1
                    color:  "#2a2a2a"
                    visible: editView.mediaType !== 1
                }

                Item { width: controlCol.width; height: 16; visible: editView.mediaType !== 1 }

                Label {
                    leftPadding: 20
                    text: "Licht & Farbe"
                    color: "#888888"
                    font.pixelSize: 11
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    width: controlCol.width
                    visible: editView.mediaType !== 1
                }

                Item { width: controlCol.width; height: 8; visible: editView.mediaType !== 1 }

                // ── Sliders (hidden for video) ────────────────────────────────
                Column {
                    width: controlCol.width
                    spacing: 0
                    visible: editView.mediaType !== 1

                    EditSlider {
                        label:       "Belichtung"
                        value:       editView.brightness
                        from:        -1.0
                        to:          1.0
                        onMoved:     editView.brightness = value
                        onReset:     editView.brightness = 0
                    }
                    EditSlider {
                        label:   "Kontrast"
                        value:   editView.contrast
                        from:    -1.0; to: 1.0
                        onMoved: editView.contrast = value
                        onReset: editView.contrast = 0
                    }
                    EditSlider {
                        label:   "Lichter"
                        value:   editView.highlights
                        from:    -1.0; to: 1.0
                        onMoved: editView.highlights = value
                        onReset: editView.highlights = 0
                    }
                    EditSlider {
                        label:   "Schatten"
                        value:   editView.shadows
                        from:    -1.0; to: 1.0
                        onMoved: editView.shadows = value
                        onReset: editView.shadows = 0
                    }
                    EditSlider {
                        label:   "Schwarzwert"
                        value:   editView.blacks
                        from:    -1.0; to: 1.0
                        onMoved: editView.blacks = value
                        onReset: editView.blacks = 0
                    }
                    EditSlider {
                        label:   "Weißpunkt"
                        value:   editView.whites
                        from:    -1.0; to: 1.0
                        onMoved: editView.whites = value
                        onReset: editView.whites = 0
                    }
                }

                Rectangle {
                    width:  controlCol.width
                    height: 1
                    color:  "#2a2a2a"
                    visible: editView.mediaType !== 1
                }
                Item { width: controlCol.width; height: 16; visible: editView.mediaType !== 1 }

                Label {
                    leftPadding: 20
                    text: "Farbe"
                    color: "#888888"
                    font.pixelSize: 11
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    width: controlCol.width
                    visible: editView.mediaType !== 1
                }
                Item { width: controlCol.width; height: 8; visible: editView.mediaType !== 1 }

                Column {
                    width: controlCol.width
                    spacing: 0
                    visible: editView.mediaType !== 1

                    EditSlider {
                        label:   "Lebendigkeit"
                        value:   editView.vibrance
                        from:    -1.0; to: 1.0
                        onMoved: editView.vibrance = value
                        onReset: editView.vibrance = 0
                    }
                    EditSlider {
                        label:   "Sättigung"
                        value:   editView.saturation
                        from:    -1.0; to: 1.0
                        onMoved: editView.saturation = value
                        onReset: editView.saturation = 0
                    }
                    EditSlider {
                        label:   "Farbtemperatur"
                        value:   editView.warmth
                        from:    -1.0; to: 1.0
                        onMoved: editView.warmth = value
                        onReset: editView.warmth = 0
                    }
                    EditSlider {
                        label:   "Tönung"
                        value:   editView.tint
                        from:    -1.0; to: 1.0
                        onMoved: editView.tint = value
                        onReset: editView.tint = 0
                    }
                }

                Rectangle {
                    width:  controlCol.width
                    height: 1
                    color:  "#2a2a2a"
                    visible: editView.mediaType !== 1
                }
                Item { width: controlCol.width; height: 16; visible: editView.mediaType !== 1 }

                Label {
                    leftPadding: 20
                    text: "Details"
                    color: "#888888"
                    font.pixelSize: 11
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    width: controlCol.width
                    visible: editView.mediaType !== 1
                }
                Item { width: controlCol.width; height: 8; visible: editView.mediaType !== 1 }

                Column {
                    width: controlCol.width
                    spacing: 0
                    visible: editView.mediaType !== 1

                    EditSlider {
                        label:   "Klarheit"
                        value:   editView.clarity
                        from:    -1.0; to: 1.0
                        onMoved: editView.clarity = value
                        onReset: editView.clarity = 0
                    }
                    EditSlider {
                        label:   "Schärfe"
                        value:   editView.sharpness
                        from:    0.0; to: 1.0
                        onMoved: editView.sharpness = value
                        onReset: editView.sharpness = 0
                    }
                    EditSlider {
                        label:   "Rauschreduzierung"
                        value:   editView.noiseReduction
                        from:    0.0; to: 1.0
                        onMoved: editView.noiseReduction = value
                        onReset: editView.noiseReduction = 0
                    }
                }

                // ── Effekte section ───────────────────────────────────────────
                Rectangle {
                    width:  controlCol.width
                    height: 1
                    color:  "#2a2a2a"
                    visible: editView.mediaType !== 1
                }
                Item { width: controlCol.width; height: 16; visible: editView.mediaType !== 1 }

                Label {
                    leftPadding: 20
                    text: "Effekte"
                    color: "#888888"
                    font.pixelSize: 11
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    width: controlCol.width
                    visible: editView.mediaType !== 1
                }
                Item { width: controlCol.width; height: 8; visible: editView.mediaType !== 1 }

                Column {
                    width: controlCol.width
                    spacing: 0
                    visible: editView.mediaType !== 1

                    EditSlider {
                        label:   "Vignette"
                        value:   editView.vignette
                        from:    -1.0; to: 1.0
                        onMoved: editView.vignette = value
                        onReset: editView.vignette = 0
                    }
                    EditSlider {
                        label:   "Körnung"
                        value:   editView.grain
                        from:    0.0; to: 1.0
                        onMoved: editView.grain = value
                        onReset: editView.grain = 0
                    }
                }

                Item { width: controlCol.width; height: 20 }

                // ── Reset all button ──────────────────────────────────────────
                Rectangle {
                    width:  controlCol.width
                    height: 1
                    color:  "#2a2a2a"
                }
                Item { width: controlCol.width; height: 16 }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width:  resetLbl.implicitWidth + 32
                    height: 34
                    radius: 6
                    color:  resetAllArea.containsMouse ? "#3a3a3a" : "#252525"

                    Label {
                        id: resetLbl
                        anchors.centerIn: parent
                        text: "Alle zurücksetzen"
                        color: "#aaaaaa"
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: resetAllArea
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: editView.resetAll()
                    }
                }

                Item { width: controlCol.width; height: 20 }
            }
        }
    }

    // ── Connections to photoEditor C++ object ─────────────────────────────────
    Connections {
        target: photoEditor
        function onEditsSaved(pid) {
            if (pid === editView.photoId) {
                saving = false
                editView.savedAndReload(pid)
                editView.closed()
            }
        }
        function onEditFailed(pid, error) {
            if (pid === editView.photoId) {
                saving = false
                console.warn("Speichern fehlgeschlagen:", error)
            }
        }
    }
}
