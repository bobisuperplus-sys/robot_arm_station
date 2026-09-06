import QtQuick
import "../theme"

// 工业级状态药丸胶囊指示灯
Item {
    id: root

    property string text: ""
    property color statusColor: Theme.tertiary
    property bool pulse: false

    implicitWidth: badgeRow.implicitWidth + 16
    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: Qt.rgba(root.statusColor.r, root.statusColor.g, root.statusColor.b, 0.12)
        border.color: Qt.rgba(root.statusColor.r, root.statusColor.g, root.statusColor.b, 0.40)
        border.width: 1

        Row {
            id: badgeRow
            anchors.centerIn: parent
            spacing: 6

            // 状态指示原点
            Rectangle {
                id: dot
                width: 6
                height: 6
                radius: 3
                color: root.statusColor
                anchors.verticalCenter: parent.verticalCenter

                // 呼吸脉冲动画
                SequentialAnimation on opacity {
                    running: root.pulse
                    loops: Animation.Infinite
                    PropertyAnimation { to: 0.3; duration: 800 }
                    PropertyAnimation { to: 1.0; duration: 800 }
                }
            }

            Text {
                text: root.text
                color: root.statusColor
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
