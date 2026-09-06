import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"
import robot_console 1.0

// 左侧 65% 视讯监控与视觉感知 HUD 面板
Rectangle {
    id: root

    property RobotRpcClient robotRpc: null
    property GstVideoReceiver receiver: null
    property int selectedCamera: 1
    property bool showGrid: true

    color: Theme.surface
    radius: Theme.radiusMd
    border.color: Theme.border
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // 相机控制工具条
        Rectangle {
            Layout.fillWidth: true
            height: 38
            color: Theme.surfaceContainerLow
            radius: Theme.radiusSm
            border.color: Theme.borderActive
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                // 相机选择器
                Rectangle {
                    height: 26
                    width: cam1Text.implicitWidth + 20
                    radius: Theme.radiusSm
                    color: root.selectedCamera === 1 ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                    border.color: root.selectedCamera === 1 ? Theme.primary : Theme.border
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: root.selectedCamera === 1 ? Theme.primary : Theme.textDim
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: cam1Text
                            text: "[相机 01] 俯视视觉相机 (Eye-to-Hand)"
                            color: root.selectedCamera === 1 ? Theme.primary : Theme.textMuted
                            font.family: Theme.fontTitle; font.pixelSize: 11; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedCamera = 1
                    }
                }

                Rectangle {
                    height: 26
                    width: cam2Text.implicitWidth + 20
                    radius: Theme.radiusSm
                    color: root.selectedCamera === 2 ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                    border.color: root.selectedCamera === 2 ? Theme.primary : Theme.border
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: root.selectedCamera === 2 ? Theme.primary : Theme.textDim
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: cam2Text
                            text: "[相机 02] 3D 全局监控相机"
                            color: root.selectedCamera === 2 ? Theme.primary : Theme.textMuted
                            font.family: Theme.fontTitle; font.pixelSize: 11; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedCamera = 2
                    }
                }

                Item { Layout.fillWidth: true }

                // 相机参数读数
                Text {
                    text: "FOV: 78.5°"
                    color: Theme.textMuted
                    font.family: Theme.fontMono; font.pixelSize: 10
                }
                Text {
                    text: (receiver ? receiver.currentFps.toFixed(1) : "30.0") + " FPS"
                    color: Theme.tertiary
                    font.family: Theme.fontMono; font.pixelSize: 10; font.bold: true
                }
                Text {
                    text: "曝光: 1/250s"
                    color: Theme.textMuted
                    font.family: Theme.fontMono; font.pixelSize: 10
                }

                // 辅助网格开关
                Rectangle {
                    height: 22
                    width: gridText.implicitWidth + 12
                    radius: Theme.radiusSm
                    color: root.showGrid ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Theme.surfaceContainer
                    border.color: root.showGrid ? Theme.primary : Theme.border
                    border.width: 1

                    Text {
                        id: gridText
                        anchors.centerIn: parent
                        text: root.showGrid ? "网格: 开" : "网格: 关"
                        color: root.showGrid ? Theme.primary : Theme.textDim
                        font.family: Theme.fontMono; font.pixelSize: 10
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showGrid = !root.showGrid
                    }
                }
            }
        }

        // 核心视讯渲染与 HUD 图层
        Item {
            id: videoContainer
            Layout.fillWidth: true
            Layout.fillHeight: true

            // GStreamer C++ 视频帧渲染组件
            VideoStreamItem {
                id: streamItem
                anchors.fill: parent
                receiver: root.receiver
            }

            // 辅助网格层
            Canvas {
                id: gridCanvas
                anchors.fill: parent
                visible: root.showGrid
                opacity: 0.3
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = "#3B494C";
                    ctx.lineWidth = 0.5;
                    for (var x = 0; x < width; x += 40) {
                        ctx.beginPath();
                        ctx.moveTo(x, 0);
                        ctx.lineTo(x, height);
                        ctx.stroke();
                    }
                    for (var y = 0; y < height; y += 40) {
                        ctx.beginPath();
                        ctx.moveTo(0, y);
                        ctx.lineTo(width, y);
                        ctx.stroke();
                    }
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            // 四角 HUD 瞄准括号
            Rectangle { width: 14; height: 2; color: Theme.primary; anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 12 }
            Rectangle { width: 2; height: 14; color: Theme.primary; anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 12 }
            Rectangle { width: 14; height: 2; color: Theme.primary; anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 12 }
            Rectangle { width: 2; height: 14; color: Theme.primary; anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 12 }
            Rectangle { width: 14; height: 2; color: Theme.primary; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 12 }
            Rectangle { width: 2; height: 14; color: Theme.primary; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 12 }
            Rectangle { width: 14; height: 2; color: Theme.primary; anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 12 }
            Rectangle { width: 2; height: 14; color: Theme.primary; anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 12 }

            // 左上角水印标签
            Row {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 20
                spacing: 8

                Rectangle {
                    height: 20
                    width: 150
                    radius: Theme.radiusSm
                    color: Qt.rgba(0.05, 0.06, 0.08, 0.8)
                    border.color: Theme.border; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "仿真引擎: MUJOCO_PHYSICS_V3"
                        color: Theme.textMuted
                        font.family: Theme.fontMono; font.pixelSize: 9
                    }
                }

                Rectangle {
                    height: 20
                    width: 110
                    radius: Theme.radiusSm
                    color: Qt.rgba(0.05, 0.06, 0.08, 0.8)
                    border.color: Theme.border; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "接触求解器: 稳定"
                        color: Theme.tertiary
                        font.family: Theme.fontMono; font.pixelSize: 9; font.bold: true
                    }
                }
            }

            // AI 视觉目标方块跟踪框 (Cyan Bounding Box)
            Rectangle {
                x: parent.width * 0.44
                y: parent.height * 0.28
                width: 170
                height: 120
                color: "transparent"
                border.color: Theme.primary
                border.width: 2

                // 角落强化线
                Rectangle { width: 8; height: 3; color: Theme.primary; anchors.top: parent.top; anchors.left: parent.left }
                Rectangle { width: 3; height: 8; color: Theme.primary; anchors.top: parent.top; anchors.left: parent.left }
                Rectangle { width: 8; height: 3; color: Theme.primary; anchors.top: parent.top; anchors.right: parent.right }
                Rectangle { width: 3; height: 8; color: Theme.primary; anchors.top: parent.top; anchors.right: parent.right }
                Rectangle { width: 8; height: 3; color: Theme.primary; anchors.bottom: parent.bottom; anchors.left: parent.left }
                Rectangle { width: 3; height: 8; color: Theme.primary; anchors.bottom: parent.bottom; anchors.left: parent.left }
                Rectangle { width: 8; height: 3; color: Theme.primary; anchors.bottom: parent.bottom; anchors.right: parent.right }
                Rectangle { width: 3; height: 8; color: Theme.primary; anchors.bottom: parent.bottom; anchors.right: parent.right }

                // 目标标识头标
                Rectangle {
                    anchors.bottom: parent.top
                    anchors.left: parent.left
                    height: 18
                    width: boxTagText.implicitWidth + 12
                    color: Theme.primary
                    radius: Theme.radiusSm

                    Text {
                        id: boxTagText
                        anchors.centerIn: parent
                        text: "目标工件: 青色方块 [0.50, 0.20, 0.52]"
                        color: Theme.textOnPrimary
                        font.family: Theme.fontMono; font.pixelSize: 9; font.bold: true
                    }
                }

                // 视觉对齐信息脚标
                Rectangle {
                    anchors.top: parent.bottom
                    anchors.left: parent.left
                    height: 18
                    width: boxFootText.implicitWidth + 12
                    color: Qt.rgba(0.05, 0.06, 0.08, 0.85)
                    border.color: Theme.borderActive; border.width: 1
                    radius: Theme.radiusSm

                    Text {
                        id: boxFootText
                        anchors.centerIn: parent
                        text: "视觉偏差: Δx 0.002m | 抓取法向对齐"
                        color: Theme.primary
                        font.family: Theme.fontMono; font.pixelSize: 9
                    }
                }
            }

            // 末端 TCP 瞄准准星 (Reticle)
            Item {
                x: parent.width * 0.49
                y: parent.height * 0.36
                width: 60
                height: 60

                Rectangle {
                    anchors.centerIn: parent
                    width: 48; height: 48; radius: 24
                    color: "transparent"
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5)
                    border.width: 1
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 24; height: 24; radius: 12
                    color: "transparent"
                    border.color: Theme.primary
                    border.width: 1.5
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 4; height: 4; radius: 2
                    color: Theme.primary
                }

                Rectangle { width: 70; height: 1; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4); anchors.centerIn: parent }
                Rectangle { width: 1; height: 70; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4); anchors.centerIn: parent }

                Text {
                    anchors.left: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4
                    text: "TCP锁定: 已就位"
                    color: Theme.primary
                    font.family: Theme.fontMono; font.pixelSize: 9; font.bold: true
                }
            }

            // 底部半透明浮动遥测条
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                height: 48
                radius: Theme.radiusSm
                color: Qt.rgba(0.04, 0.05, 0.07, 0.90)
                border.color: Theme.border
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 16

                    // 传输延时
                    ColumnLayout {
                        spacing: 1
                        Text { text: "传输延时"; color: Theme.textMuted; font.family: Theme.fontMono; font.pixelSize: 9 }
                        Text {
                            text: (receiver ? receiver.latencyMs : 18) + " ms [低抖动]"
                            color: Theme.tertiary; font.family: Theme.fontMono; font.pixelSize: 11; font.bold: true
                        }
                    }

                    Rectangle { width: 1; height: 24; color: Theme.border }

                    // 视频分辨率
                    ColumnLayout {
                        spacing: 1
                        Text { text: "编码规格"; color: Theme.textMuted; font.family: Theme.fontMono; font.pixelSize: 9 }
                        Text { text: "960x640 @ 30 FPS H.264"; color: Theme.textMain; font.family: Theme.fontMono; font.pixelSize: 11 }
                    }

                    Rectangle { width: 1; height: 24; color: Theme.border }

                    // 末端 TCP 位姿
                    ColumnLayout {
                        spacing: 1
                        Text { text: "末端 TCP 空间坐标"; color: Theme.primaryDim; font.family: Theme.fontMono; font.pixelSize: 9 }
                        Text {
                            text: "X: " + (robotRpc ? robotRpc.tcpX.toFixed(3) : "0.500") + "m  " +
                                  "Y: " + (robotRpc ? robotRpc.tcpY.toFixed(3) : "0.200") + "m  " +
                                  "Z: " + (robotRpc ? robotRpc.tcpZ.toFixed(3) : "0.525") + "m"
                            color: Theme.primary; font.family: Theme.fontMono; font.pixelSize: 11; font.bold: true
                        }
                    }

                    Rectangle { width: 1; height: 24; color: Theme.border }

                    // 力矩与夹爪
                    ColumnLayout {
                        spacing: 1
                        Text { text: "传感器与夹爪"; color: Theme.secondary; font.family: Theme.fontMono; font.pixelSize: 9 }
                        Text {
                            text: "Fz: -3.42 N | 开度: " + (robotRpc ? robotRpc.gripperWidth.toFixed(1) : "38.2") + " mm"
                            color: Theme.secondary; font.family: Theme.fontMono; font.pixelSize: 11; font.bold: true
                        }
                    }
                }
            }
        }

        // 底部状态栏 (周期统计与进度)
        Rectangle {
            Layout.fillWidth: true
            height: 32
            color: Theme.surfaceContainerLow
            radius: Theme.radiusSm
            border.color: Theme.borderActive
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 16

                Text {
                    text: "周期编号 #" + (robotRpc ? robotRpc.cycleCount : 142)
                    color: Theme.textMain
                    font.family: Theme.fontTitle; font.pixelSize: 11; font.bold: true
                }

                Text {
                    text: "批次: 青色方块分拣"
                    color: Theme.textMuted
                    font.family: Theme.fontMono; font.pixelSize: 10
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "运行时间: " + (robotRpc ? robotRpc.cycleElapsed.toFixed(2) : "1.84") + "秒"
                    color: Theme.textMain
                    font.family: Theme.fontMono; font.pixelSize: 10
                }

                Text {
                    text: "预估周期: 3.20秒"
                    color: Theme.primary
                    font.family: Theme.fontMono; font.pixelSize: 10
                }

                // 进度条
                Rectangle {
                    width: 120
                    height: 6
                    radius: 3
                    color: Theme.surfaceContainerHighest

                    Rectangle {
                        width: parent.width * Math.min(1.0, (robotRpc ? robotRpc.cycleElapsed / robotRpc.cycleTotalEstimate : 0.58))
                        height: parent.height
                        radius: 3
                        color: Theme.primary
                    }
                }
            }
        }
    }
}
