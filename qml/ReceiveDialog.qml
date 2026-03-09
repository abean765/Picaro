import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Overlay notification when someone wants to send photos
Rectangle {
    id: receiveDialog
    color: "#cc000000"
    visible: false

    property string senderName: ""
    property int fileCount: 0
    property real totalSize: 0

    function show(sender, count, size) {
        senderName = sender
        fileCount = count
        totalSize = size
        visible = true
    }

    function hide() {
        visible = false
    }

    MouseArea {
        anchors.fill: parent
        // Block clicks behind dialog
    }

    Rectangle {
        id: recvDialog
        anchors.centerIn: parent
        width: 420
        height: recvCol.implicitHeight + 48
        color: "#2a2a2a"
        radius: 12
        border.color: "#444444"
        border.width: 1

        ColumnLayout {
            id: recvCol
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // Title
            RowLayout {
                spacing: 8

                Label {
                    text: "\u{1F4E5}"
                    font.pixelSize: 24
                }
                Label {
                    text: "Eingehende Übertragung"
                    color: "#ffffff"
                    font.pixelSize: 20
                    font.bold: true
                }
            }

            // Info
            Label {
                text: "<b>" + senderName + "</b> möchte " + fileCount +
                      " Datei" + (fileCount !== 1 ? "en" : "") + " senden."
                textFormat: Text.RichText
                color: "#cccccc"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // Size info
            Label {
                text: {
                    if (totalSize < 1024) return "Größe: " + totalSize + " B"
                    if (totalSize < 1024 * 1024) return "Größe: " + (totalSize / 1024).toFixed(1) + " KB"
                    if (totalSize < 1024 * 1024 * 1024) return "Größe: " + (totalSize / (1024*1024)).toFixed(1) + " MB"
                    return "Größe: " + (totalSize / (1024*1024*1024)).toFixed(2) + " GB"
                }
                color: "#999999"
                font.pixelSize: 13
            }

            // Receive folder info
            Label {
                text: "Speicherort: " + appSettings.receiveFolder
                color: "#666666"
                font.pixelSize: 12
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }

            // Receive progress (visible during transfer)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: recvProgressCol.implicitHeight + 16
                color: "#1e1e1e"
                radius: 6
                visible: networkManager.receiving

                ColumnLayout {
                    id: recvProgressCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Label {
                        text: "Empfange... " + networkManager.receiveProgress + " / " + networkManager.receiveTotal
                        color: "#ffffff"
                        font.pixelSize: 13
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 4
                        radius: 2
                        color: "#333333"

                        Rectangle {
                            width: networkManager.receiveTotal > 0
                                ? parent.width * (networkManager.receiveProgress / networkManager.receiveTotal)
                                : 0
                            height: parent.height
                            radius: 2
                            color: root.accentColor
                        }
                    }
                }
            }

            // Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: !networkManager.receiving

                Item { Layout.fillWidth: true }

                Button {
                    text: "Ablehnen"
                    onClicked: {
                        networkManager.rejectTransfer()
                        receiveDialog.hide()
                    }

                    background: Rectangle {
                        color: parent.hovered ? "#4a4a4a" : "#3a3a3a"
                        radius: 6
                    }
                    contentItem: Label {
                        text: parent.text
                        color: "#aaaaaa"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 20
                        rightPadding: 20
                    }
                }

                Button {
                    text: "Annehmen"
                    onClicked: {
                        networkManager.acceptTransfer(appSettings.receiveFolder)
                    }

                    background: Rectangle {
                        color: parent.hovered ? Qt.lighter(root.accentColor, 1.2) : root.accentColor
                        radius: 6
                    }
                    contentItem: Label {
                        text: parent.text
                        color: "#ffffff"
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 20
                        rightPadding: 20
                    }
                }
            }
        }
    }

    Connections {
        target: networkManager
        function onReceiveFinished(success, count, message) {
            receiveDialog.hide()
        }
    }
}
