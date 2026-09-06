import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"
import robot_console 1.0

// 卡片 2: 7 轴关节空间实时遥测
CyberCard {
    id: root

    property RobotRpcClient robotRpc: null

    title: "7 轴关节空间实时遥测"
    subTitle: "ETHERCAT 1kHz"
    accentColor: Theme.primary

    readonly property var jointNames: [
        "基座旋转", "肩部俯仰", "肘部回转", "肘部俯仰", "手腕旋转", "手腕俯仰", "法兰偏航"
    ]

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
            model: 7

            JointBar {
                jointId: "J" + (index + 1)
                jointName: (root.jointNames && root.jointNames.length > index) ? root.jointNames[index] : ("关节 " + (index + 1))
                angleDeg: (root.robotRpc && root.robotRpc.jointAngles && root.robotRpc.jointAngles.length > index)
                          ? root.robotRpc.jointAngles[index] : 0.0
                torqueNm: (root.robotRpc && root.robotRpc.jointTorques && root.robotRpc.jointTorques.length > index)
                          ? root.robotRpc.jointTorques[index] : 0.0
                progressRatio: (angleDeg + 180.0) / 360.0
                isHighlight: index === 3 // J4 突出标示
            }
        }
    }
}
