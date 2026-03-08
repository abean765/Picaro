import QtQuick
import QtQuick.Controls

Rectangle {
    id: timeline
    color: "#1e1e1e"
    width: 56

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
            height: showYear ? 42 : 26

            required property var modelData
            required property int index

            // Show year label when year changes
            readonly property bool showYear: {
                if (index === 0) return true
                var prev = photoModel.timelineData[index - 1]
                return prev && modelData.year !== prev.year
            }

            readonly property bool isActive: timeline.activeIndex === index

            // Year label
            Label {
                id: yearLabel
                visible: monthDelegate.showYear
                text: monthDelegate.modelData.year
                color: "#888888"
                font.pixelSize: 11
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
                y: 2
            }

            // Month row
            Item {
                id: monthRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 22

                // Highlight background
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 2
                    anchors.rightMargin: 2
                    radius: 3
                    color: monthDelegate.isActive ? "#2a4a7a" : (monthMouse.containsMouse ? "#2a2a2a" : "transparent")
                }

                // Month abbreviation
                Label {
                    id: monthLabel
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: monthDelegate.modelData.label
                    color: monthDelegate.isActive ? "#4a9eff" : "#777777"
                    font.pixelSize: 10
                    font.bold: monthDelegate.isActive
                }

                // Density bar
                Rectangle {
                    anchors.left: monthLabel.right
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: 2
                    color: monthDelegate.isActive ? "#4a9eff" : "#444444"
                    width: {
                        var maxBarWidth = timeline.width - monthLabel.width - 18
                        var ratio = monthDelegate.modelData.count / photoModel.timelineMaxCount
                        return Math.max(2, maxBarWidth * ratio)
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
        }

        // Scroll with mouse wheel
        WheelHandler {
            target: timelineList
            property: "contentY"
            rotationScale: -1.0
        }
    }
}
