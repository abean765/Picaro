import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Karten-Komponente mit OSM-Tiles und Pin-Markern.
// points: [{lat: double, lon: double, id?: int}]
Item {
    id: root
    clip: true

    property var points: []
    property int zoom: 3
    property double centerLat: 20
    property double centerLon: 10

    // Call fitAll() after points and size are known
    onPointsChanged:    Qt.callLater(fitAll)
    onWidthChanged:     Qt.callLater(fitAll)
    onHeightChanged:    Qt.callLater(fitAll)
    Component.onCompleted: Qt.callLater(fitAll)

    // ---------- helpers ----------

    function tileX(lon, z) {
        return (lon + 180) / 360 * Math.pow(2, z)
    }
    function tileY(lat, z) {
        var lr = lat * Math.PI / 180
        return (1 - Math.log(Math.tan(lr) + 1 / Math.cos(lr)) / Math.PI) / 2 * Math.pow(2, z)
    }

    function fitAll() {
        if (root.width <= 0 || root.height <= 0) return
        if (points.length === 0) {
            centerLat = 20; centerLon = 10; zoom = 2; return
        }
        var minLat = points[0].lat, maxLat = points[0].lat
        var minLon = points[0].lon, maxLon = points[0].lon
        for (var i = 1; i < points.length; i++) {
            if (points[i].lat < minLat) minLat = points[i].lat
            if (points[i].lat > maxLat) maxLat = points[i].lat
            if (points[i].lon < minLon) minLon = points[i].lon
            if (points[i].lon > maxLon) maxLon = points[i].lon
        }
        centerLat = (minLat + maxLat) / 2
        centerLon = (minLon + maxLon) / 2
        if (points.length === 1) {
            zoom = 14; return
        }
        var dLon = Math.max(maxLon - minLon, 0.001)
        var dLat = Math.max(maxLat - minLat, 0.001)
        var zLon = Math.log(root.width  * 0.65 * 360 / (256 * dLon)) / Math.LN2
        var zLat = Math.log(root.height * 0.65 * 180 / (256 * dLat)) / Math.LN2
        zoom = Math.max(1, Math.min(Math.floor(Math.min(zLon, zLat)), 14))
    }

    // ---------- derived geometry ----------

    // Top-left corner in fractional tile coords
    readonly property double originTX: tileX(centerLon, zoom) - root.width  / 512
    readonly property double originTY: tileY(centerLat, zoom) - root.height / 512

    // Tile list covering the viewport (+1 tile margin each side)
    readonly property var tileList: {
        var list = []
        var tW = Math.ceil(root.width  / 256) + 2
        var tH = Math.ceil(root.height / 256) + 2
        var sx = Math.floor(originTX)
        var sy = Math.floor(originTY)
        var maxT = Math.pow(2, zoom)
        for (var dy = 0; dy < tH; dy++) {
            for (var dx = 0; dx < tW; dx++) {
                var ty = sy + dy
                if (ty < 0 || ty >= maxT) continue
                var tx = ((sx + dx) % maxT + maxT) % maxT
                list.push({ tx: tx, ty: ty, offX: sx + dx, offY: ty })
            }
        }
        return list
    }

    // ---------- OSM tiles ----------

    Repeater {
        model: root.tileList
        Image {
            required property var modelData
            x: (modelData.offX - root.originTX) * 256
            y: (modelData.offY - root.originTY) * 256
            width: 256; height: 256
            source: "https://tile.openstreetmap.org/%1/%2/%3.png"
                .arg(root.zoom).arg(modelData.tx).arg(modelData.ty)
            fillMode: Image.Stretch
            cache: true
            Rectangle {
                anchors.fill: parent
                color: "#3a4535"
                visible: parent.status !== Image.Ready
            }
        }
    }

    // ---------- pin markers ----------

    Repeater {
        model: root.points
        Item {
            required property var modelData
            readonly property double px: (root.tileX(modelData.lon, root.zoom) - root.originTX) * 256
            readonly property double py: (root.tileY(modelData.lat, root.zoom) - root.originTY) * 256
            x: px - 11
            y: py - 28
            z: 1

            Label {
                text: "\u{1F4CD}"
                font.pixelSize: 22
                style: Text.Outline
                styleColor: "#000000"
            }
        }
    }

    // ---------- OSM attribution ----------

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 4
        color: "#c0ffffff"
        radius: 3
        implicitWidth: attrLabel.implicitWidth + 8
        implicitHeight: attrLabel.implicitHeight + 4

        Label {
            id: attrLabel
            anchors.centerIn: parent
            text: "© OpenStreetMap contributors"
            font.pixelSize: 10
            color: "#333333"
        }
    }

    // ---------- zoom controls ----------

    Column {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        spacing: 2

        Repeater {
            model: [
                { label: "+", action: function() { root.zoom = Math.min(root.zoom + 1, 18) } },
                { label: "\u2212", action: function() { root.zoom = Math.max(root.zoom - 1, 1) } },
                { label: "\u29C4", action: function() { root.fitAll() } }
            ]
            Rectangle {
                required property var modelData
                width: 32; height: 32; radius: 6
                color: zCtrl.containsMouse ? "#555555" : "#2a2a2aCC"
                border.color: "#55ffffff"
                border.width: 1

                Label {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.bold: true
                }

                MouseArea {
                    id: zCtrl
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.action()
                }
            }
        }
    }
}
