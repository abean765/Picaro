import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: overviewView

    property bool mapOverlayVisible: false
    property var geoPoints: []

    Component.onCompleted: statsProvider.refresh()

    Connections {
        target: photoImporter
        function onImportFinished() {
            statsProvider.refresh()
        }
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 32
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 24

            Label {
                text: "Übersicht"
                color: "#ffffff"
                font.pixelSize: 28
                font.bold: true
            }

            // Stats grid
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 16
                rowSpacing: 16

                StatCard {
                    title: "Fotos"
                    value: statsProvider.normalPhotos
                    icon: "\u25A3"
                    accentColor: root.accentColor
                }

                StatCard {
                    title: "Videos"
                    value: statsProvider.videos
                    icon: "\u25B6"
                    accentColor: "#ff6b6b"
                }

                StatCard {
                    title: "Live Fotos"
                    value: statsProvider.livePhotos
                    icon: "◉"
                    accentColor: "#ffd43b"
                }

                StatCard {
                    title: "Screenshots"
                    value: statsProvider.screenshots
                    icon: "\u25A6"
                    accentColor: "#69db7c"
                }

                StatCard {
                    title: "Selfies"
                    value: statsProvider.selfies
                    icon: "\u25CE"
                    accentColor: "#da77f2"
                }

                StatCard {
                    title: "Mit Metadaten"
                    value: statsProvider.withExif
                    subtitle: statsProvider.totalPhotos > 0
                        ? Math.round(statsProvider.withExif / statsProvider.totalPhotos * 100) + " %"
                        : ""
                    icon: "\u2630"
                    accentColor: "#74c0fc"
                }

                StatCard {
                    title: "Mit Standort"
                    value: statsProvider.withGeolocation
                    subtitle: statsProvider.totalPhotos > 0
                        ? Math.round(statsProvider.withGeolocation / statsProvider.totalPhotos * 100) + " %"
                        : ""
                    icon: "\u25C6"
                    accentColor: "#ff922b"
                    clickable: statsProvider.withGeolocation > 0
                    onClicked: {
                        overviewView.geoPoints = photoModel.allGeolocatedPhotos()
                        overviewView.mapOverlayVisible = true
                    }
                }

                StatCard {
                    title: "Gesamt"
                    value: statsProvider.totalPhotos
                    subtitle: statsProvider.totalSize
                    icon: "\u25A0"
                    accentColor: "#ffffff"
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // Fullscreen map overlay
    Rectangle {
        anchors.fill: parent
        color: "#d0000000"
        visible: overviewView.mapOverlayVisible
        z: 100

        MouseArea { anchors.fill: parent } // block clicks through

        Rectangle {
            anchors.fill: parent
            anchors.margins: 32
            color: "#1a1a1a"
            radius: 12
            clip: true

            // Header bar declared first so GeoMapView can anchor below it
            Rectangle {
                id: mapHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 44
                color: "#cc1a1a1a"
                radius: 12
                z: 1

                // Bottom corners not rounded
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 12
                    color: parent.color
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 8

                    Label {
                        text: "\u25C6  %1 Fotos mit Standort".arg(overviewView.geoPoints.length)
                        color: "#ffffff"
                        font.pixelSize: 15
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 32; height: 32; radius: 16
                        color: closeMapArea.containsMouse ? "#60ffffff" : "#30ffffff"

                        Label {
                            anchors.centerIn: parent
                            text: "\u2715"
                            color: "#ffffff"
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: closeMapArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: overviewView.mapOverlayVisible = false
                        }
                    }
                }
            }

            GeoMapView {
                id: geoMap
                anchors.top: mapHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                points: overviewView.geoPoints
            }
        }
    }

    // Inline component for stat cards
    component StatCard: Rectangle {
        property string title: ""
        property int value: 0
        property string subtitle: ""
        property string icon: ""
        property color accentColor: "#ffffff"
        property bool clickable: false

        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 120
        color: "#2a2a2a"
        radius: 8

        // Hover highlight (below content)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: cardArea.containsMouse && clickable ? "#15ffffff" : "transparent"
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 4

            RowLayout {
                spacing: 8
                Label {
                    text: icon
                    font.pixelSize: 20
                }
                Label {
                    text: title
                    color: "#999999"
                    font.pixelSize: 14
                }
                Item { Layout.fillWidth: true }
                Label {
                    visible: clickable
                    text: "\u25B6"
                    color: accentColor
                    font.pixelSize: 10
                    opacity: 0.7
                }
            }

            Label {
                text: value.toLocaleString()
                color: accentColor
                font.pixelSize: 36
                font.bold: true
            }

            Label {
                text: subtitle
                color: "#666666"
                font.pixelSize: 12
                visible: subtitle.length > 0
            }
        }

        MouseArea {
            id: cardArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (clickable) parent.clicked()
        }
    }
}
