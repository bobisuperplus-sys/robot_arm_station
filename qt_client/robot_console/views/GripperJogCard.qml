import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"
import robot_console 1.0

// 卡片 3: 末端夹爪与空间点动控制
CyberCard {
    id: root

    property RobotRpcClient robotRpc: null
    property double selectedStepMm: 5.0

    title: "末端夹爪与空间点动控制"
    subTitle: "基座坐标系"
    accentColor: Theme.primary

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        // 夹爪交互控制与力矩指示面板
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 88
            color: Theme.surfaceContainerLowest
            radius: Theme.radiusSm
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // 读数信息行
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "夹爪状态: " + ((root.robotRpc && root.robotRpc.gripperWidth < 15) ? "夹紧闭合" : ((root.robotRpc && root.robotRpc.gripperWidth > 70) ? "完全张开" : "自由行程"))
                        color: Theme.tertiary
                        font.family: Theme.fontTitle; font.pixelSize: 10; font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "开度: " + (root.robotRpc ? root.robotRpc.gripperWidth.toFixed(1) : "0.0") + " mm | 阻抗力: " + (root.robotRpc ? Math.abs(root.robotRpc.gripperForce).toFixed(1) : "0.0") + " N"
                        color: Theme.primary
                        font.family: Theme.fontMono; font.pixelSize: 10; font.bold: true
                    }
                }

                // 交互式开度调节滑槽 (支持点击与水平拖动)
                Rectangle {
                    id: sliderTrack
                    Layout.fillWidth: true
                    height: 10
                    radius: 5
                    color: Theme.surfaceContainer
                    border.color: Theme.border; border.width: 1

                    Rectangle {
                        id: sliderFill
                        width: parent.width * Math.min(1.0, Math.max(0.0, (root.robotRpc ? root.robotRpc.gripperWidth / 80.0 : 0.0)))
                        height: parent.height
                        radius: 5
                        color: Theme.tertiary
                    }

                    // 滑块手柄
                    Rectangle {
                        x: Math.max(0, Math.min(sliderTrack.width - width, sliderFill.width - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14; height: 14; radius: 7
                        color: Theme.primary
                        border.color: "#FFFFFF"; border.width: 1.5
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function applyPosition(mouseX) {
                            var ratio = Math.max(0.0, Math.min(1.0, mouseX / width))
                            var targetWidth = ratio * 80.0
                            if (root.robotRpc) root.robotRpc.setGripperWidth(targetWidth)
                        }
                        onClicked: function(mouse) { applyPosition(mouse.x) }
                        onPositionChanged: function(mouse) {
                            if (pressed) applyPosition(mouse.x)
                        }
                    }
                }

                // 快捷操作与微调按钮栏
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // 闭合按钮
                    Rectangle {
                        Layout.fillWidth: true
                        height: 22
                        radius: Theme.radiusSm
                        color: Theme.surfaceContainer
                        border.color: Theme.border; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "闭合 (0mm)"
                            color: Theme.textMain; font.family: Theme.fontTitle; font.pixelSize: 9; font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.robotRpc) root.robotRpc.setGripperWidth(0.0)
                            }
                        }
                    }

                    // 微调收拢 (-5mm)
                    Rectangle {
                        width: 38
                        height: 22
                        radius: Theme.radiusSm
                        color: Theme.surfaceContainer
                        border.color: Theme.border; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "-5mm"
                            color: Theme.textMuted; font.family: Theme.fontMono; font.pixelSize: 9
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.robotRpc) {
                                    var cur = root.robotRpc.gripperWidth
                                    root.robotRpc.setGripperWidth(Math.max(0.0, cur - 5.0))
                                }
                            }
                        }
                    }

                    // 微调开张 (+5mm)
                    Rectangle {
                        width: 38
                        height: 22
                        radius: Theme.radiusSm
                        color: Theme.surfaceContainer
                        border.color: Theme.border; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "+5mm"
                            color: Theme.textMuted; font.family: Theme.fontMono; font.pixelSize: 9
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.robotRpc) {
                                    var cur = root.robotRpc.gripperWidth
                                    root.robotRpc.setGripperWidth(Math.min(80.0, cur + 5.0))
                                }
                            }
                        }
                    }

                    // 全开按钮
                    Rectangle {
                        Layout.fillWidth: true
                        height: 22
                        radius: Theme.radiusSm
                        color: Theme.surfaceContainer
                        border.color: Theme.border; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "张开 (80mm)"
                            color: Theme.textMain; font.family: Theme.fontTitle; font.pixelSize: 9; font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.robotRpc) root.robotRpc.setGripperWidth(80.0)
                            }
                        }
                    }
                }
            }
        }

        // 步长切换条
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "步长选择:"
                color: Theme.textMuted
                font.family: Theme.fontTitle; font.pixelSize: 10
            }

            Repeater {
                model: [1.0, 5.0, 10.0, 25.0]

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 22
                    radius: Theme.radiusSm
                    color: root.selectedStepMm === modelData ? Theme.primary : Theme.surfaceContainer
                    border.color: Theme.border; border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.toFixed(0) + "mm"
                        color: root.selectedStepMm === modelData ? Theme.textOnPrimary : Theme.textMuted
                        font.family: Theme.fontMono; font.pixelSize: 10; font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedStepMm = modelData
                    }
                }
            }
        }

        // 3D 空间点动矩阵
        JogPad {
            stepMm: root.selectedStepMm
            onJogCommand: function(axis, step) {
                if (root.robotRpc) root.robotRpc.jogAxis(axis, step)
            }
            onHomeRequested: {
                if (root.robotRpc) root.robotRpc.resetToHome()
            }
        }
    }
}
