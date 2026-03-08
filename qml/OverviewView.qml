import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: overviewView

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
                    icon: "🖼"
                    accentColor: root.accentColor
                }

                StatCard {
                    title: "Videos"
                    value: statsProvider.videos
                    icon: "🎬"
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
                    icon: "📱"
                    accentColor: "#69db7c"
                }

                StatCard {
                    title: "Selfies"
                    value: statsProvider.selfies
                    icon: "🤳"
                    accentColor: "#da77f2"
                }

                StatCard {
                    title: "Gesamt"
                    value: statsProvider.totalPhotos
                    subtitle: statsProvider.totalSize
                    icon: "📊"
                    accentColor: "#ffffff"
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // Inline component for stat cards
    component StatCard: Rectangle {
        property string title: ""
        property int value: 0
        property string subtitle: ""
        property string icon: ""
        property color accentColor: "#ffffff"

        Layout.fillWidth: true
        Layout.preferredHeight: 120
        color: "#2a2a2a"
        radius: 8

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
    }
}
