import QtQuick
import QtQuick.Layouts
import "../theme"

// 单轴关节空间遥测显示组件
Rectangle {
    id: root

    property string jointId: "J1"
    property string jointName: "基座旋转"
    property double angleDeg: 0.0
    property double torqueNm: 0.0
    property double progressRatio: 0.5
    property color barColor: Theme.primary
    property bool isHighlight: false

    color: Theme.surfaceContainerLowest
    radius: Theme.radiusSm
    border.color: root.isHighlight ? Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.4) : "transparent"
    border.width: 1

    implicitHeight: 38
    Layout.fillWidth: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4

        // 标签与数值行
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.jointId
                color: root.isHighlight ? Theme.secondary : Theme.primary
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.bold: true
                Layout.preferredWidth: 26
            }

            Text {
                text: root.jointName
                color: Theme.textMuted
                font.family: Theme.fontTitle
                font.pixelSize: 11
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Text {
                text: (root.angleDeg >= 0 ? "+" : "") + root.angleDeg.toFixed(1) + "°"
                color: root.isHighlight ? Theme.secondary : Theme.textMain
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: root.torqueNm.toFixed(2) + " Nm"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: 10
                Layout.preferredWidth: 60
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // 进度刻度槽
        Rectangle {
            Layout.fillWidth: true
            height: 4
            radius: 2
            color: Theme.surfaceContainer

            Rectangle {
                width: parent.width * Math.max(0.05, Math.min(1.0, root.progressRatio))
                height: parent.height
                radius: 2
                color: root.isHighlight ? Theme.secondary : root.barColor
            }
        }
    }
}
