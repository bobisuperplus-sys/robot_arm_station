import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "theme"
import "components"
import "views"
import robot_console 1.0

ApplicationWindow {
    id: window
    width: 1560
    height: 940
    minimumWidth: 1200
    minimumHeight: 760
    visible: true
    title: qsTr("MHS 具身机械臂视觉自主抓取数字孪生控制台")
    color: Theme.canvas

    // 后端核心业务与流媒体对象
    RobotRpcClient {
        id: robotRpc
    }

    GstVideoReceiver {
        id: videoReceiver
        Component.onCompleted: {
            // 自动开启 UDP:5002 H.264 视频流接收
            startStream(5002)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 顶部 HUD 状态与急停导航栏
        TopHeaderBar {
            Layout.fillWidth: true
            robotRpc: robotRpc
            receiver: videoReceiver
        }

        // 双栏响应式主工作区 (左 64% 视讯与 HUD / 右 36% 控制与遥测)
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 8
            spacing: 8

            // 左侧：多相机视讯与 HUD 视觉感知面板 (64%)
            VideoViewport {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.preferredWidth: (window.width - 24) * 0.64
                Layout.minimumWidth: 640
                robotRpc: robotRpc
                receiver: videoReceiver
            }

            // 右侧：4 大控制与遥测卡片列 (36%)
            ScrollView {
                id: rightScroll
                Layout.fillHeight: true
                Layout.preferredWidth: (window.width - 24) * 0.36
                Layout.minimumWidth: 380
                clip: true
                contentWidth: availableWidth
                contentHeight: rightCol.implicitHeight
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    id: rightCol
                    width: rightScroll.availableWidth
                    spacing: 8

                    // 卡片 1: 5 步任务流水线
                    TaskPipelineCard {
                        Layout.fillWidth: true
                        robotRpc: robotRpc
                    }

                    // 卡片 2: 7 轴关节空间实时遥测
                    JointTelemetryCard {
                        Layout.fillWidth: true
                        robotRpc: robotRpc
                    }

                    // 卡片 3: 末端夹爪与空间点动控制
                    GripperJogCard {
                        Layout.fillWidth: true
                        robotRpc: robotRpc
                    }

                    // 卡片 4: 硬件通信与事件日志
                    TerminalLogCard {
                        Layout.fillWidth: true
                        robotRpc: robotRpc
                    }
                }
            }
        }
    }
}
