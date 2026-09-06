import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"
import robot_console 1.0

// 顶部全局工业 HUD 控制栏
Rectangle {
    id: root

    property RobotRpcClient robotRpc: null
    property GstVideoReceiver receiver: null

    height: 56
    color: Theme.surfaceContainerLowest
    border.color: Theme.border
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 16

        // 左侧 Logo 图标与标题
        RowLayout {
            spacing: 10

            Rectangle {
                width: 32
                height: 32
                radius: Theme.radiusSm
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                border.color: Theme.primary
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "MHS"
                    color: Theme.primary
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            ColumnLayout {
                spacing: 2
                Text {
                    text: "MHS 具身机械臂视觉自主抓取数字孪生控制台"
                    color: Theme.textMain
                    font.family: Theme.fontTitle
                    font.pixelSize: 15
                    font.bold: true
                }
                Text {
                    text: "STATION #04 // CELL-FRANKA-PANDA-7DOF"
                    color: Theme.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                }
            }
        }

        // 中间实时系统状态栏
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 8
            visible: root.width > 900

            Rectangle { width: 1; height: 24; color: Theme.border }

            StatusBadge {
                text: (receiver && receiver.connected)
                      ? "视讯推流: 正常 " + receiver.currentFps.toFixed(0) + " FPS"
                      : "视讯推流: 等待接入"
                statusColor: (receiver && receiver.connected) ? Theme.tertiary : Theme.warning
                pulse: receiver && receiver.connected
            }

            StatusBadge {
                text: (robotRpc && robotRpc.connected) ? "控制总线: 已连接" : "控制总线: 断开"
                statusColor: (robotRpc && robotRpc.connected) ? Theme.primary : Theme.error
            }

            StatusBadge {
                text: (robotRpc && robotRpc.emergencyStopped) ? "电子围栏: 紧急联锁" : "电子围栏: 安全 [ISO 10218-1]"
                statusColor: (robotRpc && robotRpc.emergencyStopped) ? Theme.error : Theme.tertiary
                pulse: robotRpc && robotRpc.emergencyStopped
            }
        }

        Item { Layout.fillWidth: true }

        // 右侧 E-STOP 紧急制动与操作员权限信息
        RowLayout {
            spacing: 12

            // E-STOP 紧急制动按钮
            Rectangle {
                id: estopBtn
                width: 150
                height: 34
                radius: Theme.radiusSm
                color: (robotRpc && robotRpc.emergencyStopped) ? "#D32F2F" : Theme.error
                border.color: "#FF8A80"
                border.width: 2

                SequentialAnimation on opacity {
                    running: robotRpc && robotRpc.emergencyStopped
                    loops: Animation.Infinite
                    PropertyAnimation { to: 0.4; duration: 400 }
                    PropertyAnimation { to: 1.0; duration: 400 }
                }

                Text {
                    anchors.centerIn: parent
                    text: (robotRpc && robotRpc.emergencyStopped) ? "[已锁定] 点击恢复" : "[E-STOP] 紧急制动"
                    color: "#FFFFFF"
                    font.family: Theme.fontTitle
                    font.pixelSize: 12
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.robotRpc) {
                            root.robotRpc.triggerEstop()
                        }
                    }
                }
            }

            Rectangle { width: 1; height: 24; color: Theme.border }

            ColumnLayout {
                spacing: 1
                Text {
                    text: "操作员: 视觉开发组"
                    color: Theme.textMain
                    font.family: Theme.fontTitle
                    font.pixelSize: 11
                    font.bold: true
                }
                Text {
                    text: "权限: 系统管理员"
                    color: Theme.primaryDim
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                }
            }
        }
    }
}
