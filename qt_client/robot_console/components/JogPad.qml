import QtQuick
import QtQuick.Layouts
import "../theme"

// 3D 笛卡尔空间点动控制盘
Item {
    id: root

    property double stepMm: 5.0
    signal jogCommand(string axis, double step)
    signal homeRequested()

    implicitHeight: 110
    Layout.fillWidth: true

    RowLayout {
        anchors.fill: parent
        spacing: 8

        // X/Y 平面九宫格点动阵列
        Rectangle {
            Layout.preferredWidth: 150
            Layout.fillHeight: true
            color: Theme.surfaceContainerLowest
            radius: Theme.radiusSm
            border.color: Theme.border
            border.width: 1

            GridLayout {
                anchors.centerIn: parent
                columns: 3
                rowSpacing: 4
                columnSpacing: 4

                Item { width: 34; height: 30 }

                // +Y
                Rectangle {
                    width: 34; height: 30
                    radius: Theme.radiusSm
                    color: yPlusMouse.pressed ? Theme.primary : (yPlusMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                    border.color: Theme.border; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "+Y"
                        color: yPlusMouse.pressed ? Theme.textOnPrimary : Theme.primary
                        font.family: Theme.fontMono; font.pixelSize: 11; font.bold: true
                    }
                    MouseArea {
                        id: yPlusMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.jogCommand("+Y", root.stepMm)
                    }
                }

                Item { width: 34; height: 30 }

                // -X
                Rectangle {
                    width: 34; height: 30
                    radius: Theme.radiusSm
                    color: xMinusMouse.pressed ? Theme.primary : (xMinusMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                    border.color: Theme.border; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "-X"
                        color: xMinusMouse.pressed ? Theme.textOnPrimary : Theme.primary
                        font.family: Theme.fontMono; font.pixelSize: 11; font.bold: true
                    }
                    MouseArea {
                        id: xMinusMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.jogCommand("-X", root.stepMm)
                    }
                }

                // 中心参考原点
                Rectangle {
                    width: 34; height: 30
                    color: "transparent"
                    Rectangle {
                        width: 8; height: 8; radius: 4; anchors.centerIn: parent
                        color: Theme.primary
                    }
                }

                // +X
                Rectangle {
                    width: 34; height: 30
                    radius: Theme.radiusSm
                    color: xPlusMouse.pressed ? Theme.primary : (xPlusMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                    border.color: Theme.border; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "+X"
                        color: xPlusMouse.pressed ? Theme.textOnPrimary : Theme.primary
                        font.family: Theme.fontMono; font.pixelSize: 11; font.bold: true
                    }
                    MouseArea {
                        id: xPlusMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.jogCommand("+X", root.stepMm)
                    }
                }

                Item { width: 34; height: 30 }

                // -Y
                Rectangle {
                    width: 34; height: 30
                    radius: Theme.radiusSm
                    color: yMinusMouse.pressed ? Theme.primary : (yMinusMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                    border.color: Theme.border; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "-Y"
                        color: yMinusMouse.pressed ? Theme.textOnPrimary : Theme.primary
                        font.family: Theme.fontMono; font.pixelSize: 11; font.bold: true
                    }
                    MouseArea {
                        id: yMinusMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.jogCommand("-Y", root.stepMm)
                    }
                }

                Item { width: 34; height: 30 }
            }
        }

        // Z 轴高低升降与旋转微调矩阵
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surfaceContainerLowest
            radius: Theme.radiusSm
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    // +Z
                    Rectangle {
                        Layout.fillWidth: true; height: 26; radius: Theme.radiusSm
                        color: zUpMouse.pressed ? Theme.tertiary : (zUpMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                        border.color: Theme.border; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "[+Z] 上升"
                            color: zUpMouse.pressed ? Theme.surfaceContainerLowest : Theme.tertiary
                            font.family: Theme.fontMono; font.pixelSize: 10; font.bold: true
                        }
                        MouseArea {
                            id: zUpMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.jogCommand("+Z", root.stepMm)
                        }
                    }

                    // -Z
                    Rectangle {
                        Layout.fillWidth: true; height: 26; radius: Theme.radiusSm
                        color: zDownMouse.pressed ? Theme.tertiary : (zDownMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                        border.color: Theme.border; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "[-Z] 下降"
                            color: zDownMouse.pressed ? Theme.surfaceContainerLowest : Theme.tertiary
                            font.family: Theme.fontMono; font.pixelSize: 10; font.bold: true
                        }
                        MouseArea {
                            id: zDownMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.jogCommand("-Z", root.stepMm)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    // 逆时针旋
                    Rectangle {
                        Layout.fillWidth: true; height: 24; radius: Theme.radiusSm
                        color: rLeftMouse.pressed ? Theme.secondary : (rLeftMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                        border.color: Theme.border; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "逆旋 R-"
                            color: rLeftMouse.pressed ? "#FFFFFF" : Theme.secondary
                            font.family: Theme.fontMono; font.pixelSize: 10
                        }
                        MouseArea {
                            id: rLeftMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.jogCommand("R-", root.stepMm)
                        }
                    }

                    // 顺时针旋
                    Rectangle {
                        Layout.fillWidth: true; height: 24; radius: Theme.radiusSm
                        color: rRightMouse.pressed ? Theme.secondary : (rRightMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                        border.color: Theme.border; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "顺旋 R+"
                            color: rRightMouse.pressed ? "#FFFFFF" : Theme.secondary
                            font.family: Theme.fontMono; font.pixelSize: 10
                        }
                        MouseArea {
                            id: rRightMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.jogCommand("R+", root.stepMm)
                        }
                    }
                }

                // 复位待机位
                Rectangle {
                    Layout.fillWidth: true; height: 26; radius: Theme.radiusSm
                    color: homeMouse.pressed ? Theme.primary : (homeMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                    border.color: Theme.border; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "[复位] 回初始待机位"
                        color: homeMouse.pressed ? Theme.textOnPrimary : Theme.textMain
                        font.family: Theme.fontTitle; font.pixelSize: 10; font.bold: true
                    }
                    MouseArea {
                        id: homeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.homeRequested()
                    }
                }
            }
        }
    }
}
