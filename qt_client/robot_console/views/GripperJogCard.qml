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

        // 夹爪开度与力矩指示槽
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            color: Theme.surfaceContainerLowest
            radius: Theme.radiusSm
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "夹爪状态: " + ((root.robotRpc && root.robotRpc.gripperWidth < 45) ? "夹紧闭合 [42 N]" : "完全张开")
                        color: Theme.tertiary
                        font.family: Theme.fontTitle; font.pixelSize: 10; font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "开度: " + (root.robotRpc ? root.robotRpc.gripperWidth.toFixed(1) : "38.2") + " mm"
                        color: Theme.primary
                        font.family: Theme.fontMono; font.pixelSize: 10; font.bold: true
                    }
                }

                // 开度滑槽
                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Theme.surfaceContainer

                    Rectangle {
                        width: parent.width * Math.min(1.0, Math.max(0.02, (root.robotRpc ? root.robotRpc.gripperWidth / 80.0 : 0.48)))
                        height: parent.height
                        radius: 3
                        color: Theme.tertiary
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "0 mm (闭合)"; color: Theme.textDim; font.family: Theme.fontMono; font.pixelSize: 9 }
                    Item { Layout.fillWidth: true }
                    Text { text: "80 mm (最大)"; color: Theme.textDim; font.family: Theme.fontMono; font.pixelSize: 9 }
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
