import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"
import robot_console 1.0

// 卡片 1: 任务状态机流水线
CyberCard {
    id: root

    property RobotRpcClient robotRpc: null

    title: "任务状态机流水线"
    subTitle: "当前阶段: " + (robotRpc ? robotRpc.stageName : "待机就绪")
    accentColor: Theme.primary

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        // 5 步流水线横向节点
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: [
                    { id: 1, name: "1. 视觉识别" },
                    { id: 2, name: "2. 预抓取逼近" },
                    { id: 3, name: "3. 闭环抓取" },
                    { id: 4, name: "4. 轨迹运送" },
                    { id: 5, name: "5. 放置归位" }
                ]

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 24
                        height: 24
                        radius: 12

                        property bool isPast: root.robotRpc ? root.robotRpc.currentStage > modelData.id : false
                        property bool isCurrent: root.robotRpc ? root.robotRpc.currentStage === modelData.id : false

                        color: isCurrent ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                                         : (isPast ? Qt.rgba(Theme.tertiary.r, Theme.tertiary.g, Theme.tertiary.b, 0.2)
                                                   : Theme.surfaceContainer)
                        border.color: isCurrent ? Theme.primary : (isPast ? Theme.tertiary : Theme.border)
                        border.width: isCurrent ? 2 : 1

                        Text {
                            anchors.centerIn: parent
                            text: parent.isPast ? "OK" : modelData.id.toString()
                            color: parent.isCurrent ? Theme.primary : (parent.isPast ? Theme.tertiary : Theme.textDim)
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    Text {
                        text: modelData.name
                        color: (root.robotRpc && root.robotRpc.currentStage === modelData.id) ? Theme.primary : Theme.textMuted
                        font.family: Theme.fontTitle
                        font.pixelSize: 9
                        font.bold: root.robotRpc && root.robotRpc.currentStage === modelData.id
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }

        // 执行控制按钮组
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            // 主启动按钮
            CyberButton {
                Layout.fillWidth: true
                height: 32
                btnType: "primary"
                text: "[启动] 全自动抓取搬运周期"
                onClicked: {
                    if (root.robotRpc) root.robotRpc.startAutoCycle()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                CyberButton {
                    Layout.fillWidth: true
                    height: 28
                    btnType: "secondary"
                    text: "[随机] 偏置工件位置"
                    onClicked: {
                        if (root.robotRpc) root.robotRpc.randomizeTarget()
                    }
                }

                CyberButton {
                    Layout.fillWidth: true
                    height: 28
                    btnType: "secondary"
                    text: "[暂停] 轨迹插补"
                    onClicked: {
                        if (root.robotRpc) root.robotRpc.pauseTrajectory()
                    }
                }
            }
        }
    }
}
