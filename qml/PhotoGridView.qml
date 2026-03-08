import QtQuick
import QtQuick.Controls

ListView {
    id: gridView

    property var model

    clip: true
    cacheBuffer: 1000  // Cache 1000px above and below viewport
    reuseItems: true   // Critical for performance: reuse delegates

    model: gridView.model

    // Smooth scrolling
    flickDeceleration: 3000
    maximumFlickVelocity: 8000

    // Use a scrollbar
    ScrollBar.vertical: ScrollBar {
        active: true
        policy: ScrollBar.AsNeeded
    }

    delegate: Loader {
        id: rowLoader
        width: gridView.width
        height: model.rowType === "header" ? 52 : cellHeight

        readonly property real cellHeight: (gridView.width / photoModel.photosPerRow)

        sourceComponent: model.rowType === "header" ? headerComponent : photoRowComponent

        // Header delegate
        Component {
            id: headerComponent

            Item {
                width: gridView.width
                height: 52

                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    text: model.headerText
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.bold: true
                }
            }
        }

        // Photo row delegate - renders N thumbnails in a row
        Component {
            id: photoRowComponent

            Row {
                spacing: 2

                Repeater {
                    model: cells  // cells role from PhotoModel

                    Item {
                        width: (gridView.width - (photoModel.photosPerRow - 1) * 2) / photoModel.photosPerRow
                        height: rowLoader.cellHeight

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

                            // Fade in on load
                            opacity: status === Image.Ready ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        // Loading placeholder
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            color: "#2a2a2a"
                            visible: thumbImage.status !== Image.Ready
                        }

                        // Video/Live Photo badge
                        Rectangle {
                            visible: modelData.mediaType > 0
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
                                text: modelData.mediaType === 2 ? "LIVE" : "▶"
                                color: "#ffffff"
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        // Click handler
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                // TODO: Open fullscreen viewer
                                console.log("Clicked photo ID:", modelData.id)
                            }
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
