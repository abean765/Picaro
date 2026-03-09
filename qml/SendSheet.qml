import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Overlay sheet for selecting a peer and sending photos
Rectangle {
    id: sendSheet
    color: "#cc000000"
    visible: false

    property var photoIds: []

    signal closed()

    function open(pid) {
        photoIds = [pid]
        visible = true
        if (!networkManager.discoveryActive) {
            networkManager.startDiscovery(appSettings.computerName)
        }
    }

    function openMultiple(ids) {
        photoIds = ids
        visible = true
        if (!networkManager.discoveryActive) {
            networkManager.startDiscovery(appSettings.computerName)
        }
    }

    function close() {
        visible = false
        closed()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: sendSheet.close()
    }

    // Center dialog
    Rectangle {
        id: dialog
        anchors.centerIn: parent
        width: 400
        height: contentCol.implicitHeight + 48
        color: "#2a2a2a"
        radius: 12
        border.color: "#444444"
        border.width: 1

        MouseArea {
            anchors.fill: parent
            // Prevent click-through to the backdrop
        }

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // Title
            RowLayout {
                spacing: 8

                Label {
                    text: "\u{1F4E4}"
                    font.pixelSize: 20
                }
                Label {
                    text: sendSheet.photoIds.length === 1
                        ? "Foto senden"
                        : sendSheet.photoIds.length + " Medien senden"
                    color: "#ffffff"
                    font.pixelSize: 20
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: "\u2715"
                    color: "#888888"
                    font.pixelSize: 16
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sendSheet.close()
                    }
                }
            }

            // Status
            Label {
                text: networkManager.discoveryActive
                    ? "Wähle einen Empfänger im lokalen Netzwerk:"
                    : "Netzwerk-Sichtbarkeit ist deaktiviert. Bitte in den Einstellungen aktivieren."
                color: "#999999"
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // Sending progress
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: sendProgressCol.implicitHeight + 16
                color: "#1e1e1e"
                radius: 6
                visible: networkManager.sending

                ColumnLayout {
                    id: sendProgressCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Label {
                        text: "Sende... " + networkManager.sendProgress + " / " + networkManager.sendTotal
                        color: "#ffffff"
                        font.pixelSize: 13
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 4
                        radius: 2
                        color: "#333333"

                        Rectangle {
                            width: networkManager.sendTotal > 0
                                ? parent.width * (networkManager.sendProgress / networkManager.sendTotal)
                                : 0
                            height: parent.height
                            radius: 2
                            color: root.accentColor
                        }
                    }
                }
            }

            // Peer list
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.min(peerListCol.implicitHeight + 16, 300)
                color: "#1e1e1e"
                radius: 6
                visible: networkManager.discoveryActive && !networkManager.sending
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 8
                    contentHeight: peerListCol.implicitHeight
                    clip: true

                    Column {
                        id: peerListCol
                        width: parent.width
                        spacing: 4

                        // No peers message
                        Label {
                            visible: peerModel.count === 0
                            text: "Suche nach Geräten..."
                            color: "#666666"
                            font.pixelSize: 13
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            padding: 20
                        }

                        // Spinning indicator when searching
                        BusyIndicator {
                            visible: peerModel.count === 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            running: visible
                            width: 32
                            height: 32
                        }

                        Repeater {
                            model: peerModel

                            Rectangle {
                                required property string peerName
                                required property string peerAddress
                                required property int peerPort

                                width: peerListCol.width
                                height: 48
                                radius: 6
                                color: peerItemArea.containsMouse ? "#333333" : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    // Computer icon
                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: root.accentColor

                                        Label {
                                            anchors.centerIn: parent
                                            text: peerName.charAt(0).toUpperCase()
                                            color: "#ffffff"
                                            font.pixelSize: 16
                                            font.bold: true
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Label {
                                            text: peerName
                                            color: "#ffffff"
                                            font.pixelSize: 14
                                        }
                                        Label {
                                            text: peerAddress
                                            color: "#666666"
                                            font.pixelSize: 11
                                        }
                                    }

                                    Label {
                                        text: "\u276F"
                                        color: "#666666"
                                        font.pixelSize: 16
                                    }
                                }

                                MouseArea {
                                    id: peerItemArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        networkManager.sendPhotos(
                                            peerAddress, peerPort,
                                            sendSheet.photoIds,
                                            appSettings.computerName
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Handle send finished
    Connections {
        target: networkManager
        function onSendFinished(success, message) {
            sendResultLabel.text = message
            sendResultLabel.color = success ? "#22c55e" : "#ef4444"
            sendResultLabel.visible = true
            sendResultTimer.start()
        }
    }

    // Result feedback
    Label {
        id: sendResultLabel
        visible: false
        anchors.bottom: dialog.top
        anchors.bottomMargin: 12
        anchors.horizontalCenter: dialog.horizontalCenter
        font.pixelSize: 14
        font.bold: true

        padding: 12
        background: Rectangle {
            color: "#2a2a2a"
            radius: 8
            border.color: "#444444"
            border.width: 1
        }
    }

    Timer {
        id: sendResultTimer
        interval: 3000
        onTriggered: {
            sendResultLabel.visible = false
            if (!networkManager.sending) {
                sendSheet.close()
            }
        }
    }
}
