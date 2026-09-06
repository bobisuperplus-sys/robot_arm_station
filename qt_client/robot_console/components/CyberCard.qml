import QtQuick
import QtQuick.Layouts
import "../theme"

// Cyber-Physical 工业级卡片容器
Rectangle {
    id: root

    property string title: ""
    property string subTitle: ""
    property color accentColor: Theme.primary
    default property alias content: contentContainer.data

    color: Theme.surface
    radius: Theme.radiusMd
    border.color: Theme.border
    border.width: 1

    implicitHeight: mainCol.implicitHeight + 20

    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // 顶部标题栏
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // 左侧微光状态竖条
            Rectangle {
                width: 3
                height: 14
                color: root.accentColor
                radius: 1
            }

            Text {
                text: root.title
                color: Theme.textMain
                font.family: Theme.fontTitle
                font.pixelSize: 13
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.subTitle
                color: Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: 10
                visible: root.subTitle.length > 0
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // 细线分隔栏
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.border
        }

        // 自定义内容承载区
        Item {
            id: contentContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    // 四角 HUD 科技装饰线
    Rectangle { width: 4; height: 1; color: root.accentColor; anchors.top: parent.top; anchors.left: parent.left }
    Rectangle { width: 1; height: 4; color: root.accentColor; anchors.top: parent.top; anchors.left: parent.left }
    Rectangle { width: 4; height: 1; color: root.accentColor; anchors.top: parent.top; anchors.right: parent.right }
    Rectangle { width: 1; height: 4; color: root.accentColor; anchors.top: parent.top; anchors.right: parent.right }
}
