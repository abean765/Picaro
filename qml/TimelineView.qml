import QtQuick
import QtQuick.Controls

Rectangle {
    id: timeline
    color: "#1e1e1e"
    width: 80

    // Which timeline index is currently active (set externally)
    property int activeIndex: -1

    // Emitted when user clicks a month
    signal monthClicked(int timelineIndex, int rowIndex)

    ListView {
        id: timelineList
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        clip: true
        model: photoModel.timelineData
        boundsBehavior: Flickable.StopAtBounds

        // Sync timeline scroll to keep active month visible
        function ensureActiveVisible() {
            if (timeline.activeIndex >= 0 && timeline.activeIndex < count) {
                // Only reposition if active item is not already visible
                var item = itemAtIndex(timeline.activeIndex)
                if (!item || item.y < contentY || item.y + item.height > contentY + height) {
                    positionViewAtIndex(timeline.activeIndex, ListView.Center)
                }
            }
        }

        Connections {
            target: timeline
            function onActiveIndexChanged() {
                timelineList.ensureActiveVisible()
            }
        }

        delegate: Item {
            id: monthDelegate
            width: timelineList.width
            height: showYear ? 52 : 30

            required property var modelData
            required property int index

            // Show year label when year changes
            readonly property bool showYear: {
                if (index === 0) return true
                var prev = photoModel.timelineData[index - 1]
                return prev && modelData.year !== prev.year
            }

            readonly property bool isActive: timeline.activeIndex === index

            // Year separator line + label
            Item {
                visible: monthDelegate.showYear
                anchors.left: parent.left
                anchors.right: parent.right
                height: 22
                y: 0

                // Horizontal separator line
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.top: parent.top
                    anchors.topMargin: 2
                    height: 1
                    color: "#3a3a3a"
                    visible: monthDelegate.index > 0
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    text: monthDelegate.modelData.year
                    color: "#aaaaaa"
                    font.pixelSize: 13
                    font.bold: true
                }
            }

            // Month row
            Item {
                id: monthRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 26

                // Highlight background
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    radius: 4
                    color: monthDelegate.isActive ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25) : (monthMouse.containsMouse ? "#2a2a2a" : "transparent")
                }

                // Vertical connector line (between months)
                Rectangle {
                    anchors.horizontalCenter: monthDot.horizontalCenter
                    anchors.top: parent.top
                    anchors.bottom: monthDot.verticalCenter
                    width: 1
                    color: "#333333"
                    visible: monthDelegate.index > 0
                }

                // Dot on the timeline
                Rectangle {
                    id: monthDot
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: monthDelegate.isActive ? 8 : 6
                    height: width
                    radius: width / 2
                    color: monthDelegate.isActive ? root.accentColor : "#555555"
                }

                // Month abbreviation
                Label {
                    id: monthLabel
                    anchors.left: monthDot.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: monthDelegate.modelData.label
                    color: monthDelegate.isActive ? root.accentColor : "#999999"
                    font.pixelSize: 12
                    font.bold: monthDelegate.isActive
                }

                // Density bar
                Rectangle {
                    anchors.left: monthLabel.right
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: 2
                    color: monthDelegate.isActive ? root.accentColor : "#444444"
                    width: {
                        var maxBarWidth = timeline.width - monthDot.width - monthLabel.implicitWidth - 28
                        var ratio = monthDelegate.modelData.count / photoModel.timelineMaxCount
                        return Math.max(2, Math.max(0, maxBarWidth) * ratio)
                    }
                }

                // Count tooltip on hover
                ToolTip {
                    visible: monthMouse.containsMouse
                    text: monthDelegate.modelData.fullLabel + "\n" + monthDelegate.modelData.count + " Fotos"
                    delay: 400
                }

                MouseArea {
                    id: monthMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        timeline.monthClicked(monthDelegate.index, monthDelegate.modelData.rowIndex)
                    }
                }
            }

            // Vertical connector line going down to next month
            Rectangle {
                anchors.horizontalCenter: monthDot.horizontalCenter
                anchors.top: monthDot.verticalCenter
                anchors.bottom: parent.bottom
                width: 1
                color: "#333333"
            }
        }

        // Scroll with mouse wheel
        WheelHandler {
            target: timelineList
            property: "contentY"
            rotationScale: -1.0
        }
    }
}
