import QtQuick
import "../theme"

// Cyber-Physical 工业交互按钮
Item {
    id: root

    property string text: ""
    property string btnType: "secondary" // "primary", "secondary", "danger"
    property bool enabledState: true

    signal clicked()

    implicitWidth: btnText.implicitWidth + 24
    implicitHeight: 32

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.radiusSm
        opacity: root.enabledState ? 1.0 : 0.4

        color: {
            if (root.btnType === "primary") {
                return mouseArea.containsMouse ? "#FFFFFF" : Theme.primary
            } else if (root.btnType === "danger") {
                return mouseArea.containsMouse ? "#FF5252" : Theme.error
            } else {
                return mouseArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
            }
        }

        border.color: {
            if (root.btnType === "primary") return Theme.primary
            if (root.btnType === "danger") return "#FF8A80"
            return mouseArea.containsMouse ? Theme.primary : Theme.border
        }
        border.width: root.btnType === "danger" ? 2 : 1

        Text {
            id: btnText
            anchors.centerIn: parent
            text: root.text
            font.family: Theme.fontTitle
            font.pixelSize: 11
            font.bold: true
            color: {
                if (root.btnType === "primary") return Theme.textOnPrimary
                if (root.btnType === "danger") return "#FFFFFF"
                return mouseArea.containsMouse ? Theme.primary : Theme.textMain
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: root.enabledState
            enabled: root.enabledState
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
