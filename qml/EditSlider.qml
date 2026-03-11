import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Reusable labelled slider row for the photo-editor panel.
// Properties:  label, value, from, to
// Signals:     moved(real value), reset()
Item {
    id: slideRoot

    property string label: ""
    property real   value: 0.0
    property real   from:  -1.0
    property real   to:     1.0

    signal moved(real value)
    signal reset()

    width:  parent ? parent.width : 260
    height: 52

    // ── label row ─────────────────────────────────────────────────────────
    RowLayout {
        id: labelRow
        anchors.top:         slideRoot.top
        anchors.left:        slideRoot.left
        anchors.right:       slideRoot.right
        anchors.leftMargin:  20
        anchors.rightMargin: 20
        anchors.topMargin:   6
        height: 18

        Label {
            text:  slideRoot.label
            color: "#cccccc"
            font.pixelSize: 12
            Layout.fillWidth: true
        }

        Label {
            text: {
                var v = slideRoot.value
                if (Math.abs(v) < 0.005) return "\u2014"
                return (v > 0 ? "+" : "") + Math.round(v * 100)
            }
            color:          Math.abs(slideRoot.value) > 0.005 ? root.accentColor : "#555555"
            font.pixelSize: 11
            font.family:    "Monospace"
        }

        // Reset (×) – shown only when non-zero
        Label {
            text: "\u2715"
            color: resetArea.containsMouse ? "#ffffff" : "#666666"
            font.pixelSize: 10
            visible: Math.abs(slideRoot.value) > 0.005
            MouseArea {
                id: resetArea
                anchors.fill:    parent
                anchors.margins: -4
                hoverEnabled:    true
                cursorShape:     Qt.PointingHandCursor
                onClicked: slideRoot.reset()
            }
        }
    }

    // ── slider ────────────────────────────────────────────────────────────
    Slider {
        id: slider
        anchors.top:         labelRow.bottom
        anchors.left:        slideRoot.left
        anchors.right:       slideRoot.right
        anchors.leftMargin:  14
        anchors.rightMargin: 14
        from:     slideRoot.from
        to:       slideRoot.to
        value:    slideRoot.value
        stepSize: 0.01

        onMoved: slideRoot.moved(value)

        background: Rectangle {
            x:      slider.leftPadding
            y:      slider.topPadding + slider.availableHeight / 2 - height / 2
            width:  slider.availableWidth
            height: 3
            radius: 1.5
            color:  "#333333"

            Rectangle {
                width:  slider.visualPosition * parent.width
                height: parent.height
                color:  root.accentColor
                radius: 1.5
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding  + slider.availableHeight / 2 - height / 2
            width:  14
            height: 14
            radius: 7
            color:  slider.pressed ? Qt.lighter(root.accentColor, 1.2) : "#e0e0e0"
        }
    }
}
