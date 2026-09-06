pragma Singleton
import QtQuick

// Cyber-Physical HUD 工业级设计系统 Token
QtObject {
    id: root

    // 背景与底色结构
    readonly property color canvas: "#101216"
    readonly property color surface: "#181B20"
    readonly property color surfaceLow: "#1A1C20"
    readonly property color surfaceContainerLow: "#1A1C20"
    readonly property color surfaceContainer: "#1E2024"
    readonly property color surfaceContainerHigh: "#282A2E"
    readonly property color surfaceContainerHighest: "#333539"
    readonly property color surfaceContainerLowest: "#0C0E12"

    // 边框与网格结构线
    readonly property color border: "#282C35"
    readonly property color borderActive: "#333842"
    readonly property color borderBright: "#3B494C"

    // 高对比度文本与次级标注
    readonly property color textMain: "#F0F3F6"
    readonly property color textMuted: "#8C95A6"
    readonly property color textDim: "#5C6473"

    // 状态与数据色板
    readonly property color primary: "#00E5FF"              // 运动学、轨迹、主操作 (霓虹青)
    readonly property color primaryDim: "#00DAF3"
    readonly property color textOnPrimary: "#001F24"
    readonly property color primaryContainer: "#00363D"

    readonly property color secondary: "#D500F9"            // AI 视觉包围盒、点云、感知 (电光紫)
    readonly property color secondaryLight: "#F8ACFF"
    readonly property color secondaryContainer: "#4C005A"

    readonly property color tertiary: "#00E676"             // 链路联通、安全准许、标称运行 (翠绿)
    readonly property color tertiaryContainer: "#22EF7E"

    readonly property color warning: "#FFAB00"              // 临界警告、抖动、减速区 (琥珀黄)
    readonly property color error: "#E53935"                // 碰撞联锁、急停、硬故障 (工业安全红)
    readonly property color errorContainer: "#93000A"

    // 字体族配置
    readonly property string fontTitle: "Inter, sans-serif"
    readonly property string fontMono: "JetBrains Mono, monospace"

    // 圆角规范
    readonly property int radiusSm: 2
    readonly property int radiusMd: 4
    readonly property int radiusLg: 6
    readonly property int radiusPill: 9999

    // 间距规范
    readonly property int space2xs: 2
    readonly property int spaceXs: 4
    readonly property int spaceSm: 8
    readonly property int spaceMd: 12
    readonly property int spaceLg: 16
    readonly property int spaceXl: 24
}
