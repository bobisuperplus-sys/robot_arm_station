import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"
import robot_console 1.0

// 卡片 4: 硬件通信与事件日志
CyberCard {
    id: root

    property RobotRpcClient robotRpc: null

    title: "硬件通信与事件日志"
    subTitle: "总线事件"
    accentColor: Theme.primary

    ListModel {
        id: logModel

        Component.onCompleted: {
            append({ timeStr: "12:00:01", tag: "JSON-RPC", content: "通信总线连接正常 (v2.4.1)", colorStr: "#00E5FF" })
            append({ timeStr: "12:00:02", tag: "AI视觉", content: "目标工件检测成功: CUBE_CYAN_01 (0.50, 0.20, 0.52)", colorStr: "#D500F9" })
            append({ timeStr: "12:00:03", tag: "轨迹规划", content: "逆运动学求解完成: 7航路点耗时18ms", colorStr: "#00DAF3" })
            append({ timeStr: "12:00:04", tag: "安全监控", content: "末端线速度 0.18 m/s (限制 0.50 m/s)", colorStr: "#00E676" })
        }
    }

    Connections {
        target: root.robotRpc
        function onLogAdded(timestamp, tag, content, color) {
            logModel.append({ timeStr: timestamp, tag: tag, content: content, colorStr: color })
            if (logModel.count > 50) logModel.remove(0)
            logListView.positionViewAtEnd()
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        // 日志滚动显示区
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            implicitHeight: 140
            color: "#0A0C0F"
            radius: Theme.radiusSm
            border.color: Theme.border
            border.width: 1

            ListView {
                id: logListView
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                model: logModel
                spacing: 3

                delegate: Item {
                    width: logListView.width
                    height: 18

                    RowLayout {
                        anchors.fill: parent
                        spacing: 6

                        Text {
                            text: "[" + model.timeStr + "]"
                            color: Theme.textDim
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                        }

                        Text {
                            text: "[" + model.tag + "]"
                            color: model.colorStr
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            font.bold: true
                        }

                        Text {
                            text: model.content
                            color: Theme.textMain
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        // 底部 CLI 指令输入框与清空按钮
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                height: 24
                radius: Theme.radiusSm
                color: "#0A0C0F"
                border.color: Theme.borderActive
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 4

                    Text {
                        text: "指令 >"
                        color: Theme.primary
                        font.family: Theme.fontMono; font.pixelSize: 10; font.bold: true
                    }

                    TextInput {
                        id: cmdInput
                        Layout.fillWidth: true
                        color: Theme.textMain
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        clip: true
                        selectByMouse: true
                        onAccepted: {
                            if (root.robotRpc) {
                                root.robotRpc.sendCliCommand(text)
                            }
                            text = ""
                        }
                    }
                }
            }

            Rectangle {
                width: 50
                height: 24
                radius: Theme.radiusSm
                color: Theme.surfaceContainer
                border.color: Theme.border; border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "清空"
                    color: Theme.textMuted
                    font.family: Theme.fontTitle; font.pixelSize: 10
                }

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: logModel.clear()
                }
            }
        }
    }
}
