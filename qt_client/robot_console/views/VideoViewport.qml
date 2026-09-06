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
    readonly property bool isStreamActive: receiver && receiver.connected
    readonly property int selectedCamera: (robotRpc && robotRpc.activeCamera === "surveillance_cam") ? 2 : 1
    property bool showGrid: true
    property bool showSafetyEnvelope: true

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
                        onClicked: {
                            if (root.robotRpc) root.robotRpc.switchCamera("overhead_cam")
                        }
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
                        onClicked: {
                            if (root.robotRpc) root.robotRpc.switchCamera("surveillance_cam")
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // 相机参数读数
                Text {
                    text: "FOV: " + (robotRpc ? robotRpc.cameraFov.toFixed(1) : (root.selectedCamera === 2 ? "45.0" : "58.0")) + "°"
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

                // 3D 电子安全包络开关 (仅在相机 02 下呈现)
                Rectangle {
                    visible: root.selectedCamera === 2
                    height: 22
                    width: envBtnText.implicitWidth + 12
                    radius: Theme.radiusSm
                    color: root.showSafetyEnvelope ? Qt.rgba(Theme.tertiary.r, Theme.tertiary.g, Theme.tertiary.b, 0.18) : Theme.surfaceContainer
                    border.color: root.showSafetyEnvelope ? Theme.tertiary : Theme.border
                    border.width: 1

                    Text {
                        id: envBtnText
                        anchors.centerIn: parent
                        text: root.showSafetyEnvelope ? "安全包络: 开" : "安全包络: 关"
                        color: root.showSafetyEnvelope ? Theme.tertiary : Theme.textDim
                        font.family: Theme.fontMono; font.pixelSize: 10; font.bold: root.showSafetyEnvelope
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showSafetyEnvelope = !root.showSafetyEnvelope
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

            // 辅助网格层 (仅在推流建立后呈现)
            Canvas {
                id: gridCanvas
                anchors.fill: parent
                visible: root.isStreamActive && root.showGrid
                opacity: 0.3
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (!root.isStreamActive) return;

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

            // 3D 虚拟安全栅栏 / 电子安全包络 (仅在推流建立后呈现)
            Canvas {
                id: envelopeCanvas
                anchors.fill: parent
                visible: root.isStreamActive && (root.selectedCamera === 1 || root.showSafetyEnvelope)
                opacity: 0.95

                Connections {
                    target: root
                    function onIsStreamActiveChanged() { envelopeCanvas.requestPaint(); }
                    function onShowSafetyEnvelopeChanged() { envelopeCanvas.requestPaint(); }
                    function onSelectedCameraChanged() { envelopeCanvas.requestPaint(); }
                }
                Connections {
                    target: root.robotRpc
                    function onCubePoseChanged() { envelopeCanvas.requestPaint(); }
                }

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    // 视讯推流未接入时彻底清屏并拦截绘制，保持待机画面纯净
                    if (!root.isStreamActive) return;

                    var imgAspect = 960.0 / 640.0; // 视频原生宽高比 1.5
                    var vW, vH, vX, vY;

                    if (width / height > imgAspect) {
                        // 窗口较宽，左右留黑边
                        vH = height;
                        vW = height * imgAspect;
                        vX = (width - vW) / 2.0;
                        vY = 0.0;
                    } else {
                        // 窗口较窄，上下留黑边 (实机工况)
                        vW = width;
                        vH = width / imgAspect;
                        vX = 0.0;
                        vY = (height - vH) / 2.0;
                    }

                    function mapPt(nu, nv) {
                        return {
                            x: vX + nu * vW,
                            y: vY + nv * vH
                        };
                    }

                    // =================== 相机 01: Eye-to-Hand 俯视机器视觉目标跟踪 HUD ===================
                    if (root.selectedCamera === 1) {
                        var cx = root.robotRpc ? root.robotRpc.cubeX : 0.50;
                        var cy = root.robotRpc ? root.robotRpc.cubeY : 0.20;
                        var cz = root.robotRpc ? root.robotRpc.cubeZ : 0.525;

                        // 俯视相机投影 (针孔逆解算映射)
                        var nu_c = 0.50 + 0.633 * (cx - 0.50);
                        var nv_c = 0.50 - 0.9495 * cy;
                        var pCube = mapPt(nu_c, nv_c);

                        var bw = vW * 0.085;
                        var bh = vH * 0.125;
                        var bx = pCube.x - bw / 2.0;
                        var by = pCube.y - bh / 2.0;

                        // 1. 目标工件锁定框 (青蓝色 + 亚像素角标)
                        ctx.strokeStyle = "#00E5FF";
                        ctx.lineWidth = 1.8;
                        ctx.strokeRect(bx, by, bw, bh);

                        var cLen = 8;
                        ctx.lineWidth = 3.0;
                        // 四角加强线
                        ctx.beginPath(); ctx.moveTo(bx, by + cLen); ctx.lineTo(bx, by); ctx.lineTo(bx + cLen, by); ctx.stroke();
                        ctx.beginPath(); ctx.moveTo(bx + bw - cLen, by); ctx.lineTo(bx + bw, by); ctx.lineTo(bx + bw, by + cLen); ctx.stroke();
                        ctx.beginPath(); ctx.moveTo(bx, by + bh - cLen); ctx.lineTo(bx, by + bh); ctx.lineTo(bx + cLen, by + bh); ctx.stroke();
                        ctx.beginPath(); ctx.moveTo(bx + bw - cLen, by + bh); ctx.lineTo(bx + bw, by + bh); ctx.lineTo(bx + bw, by + bh - cLen); ctx.stroke();

                        // 中心微准星
                        ctx.beginPath();
                        ctx.strokeStyle = "rgba(0, 229, 255, 0.8)";
                        ctx.lineWidth = 1.0;
                        ctx.moveTo(pCube.x - 6, pCube.y); ctx.lineTo(pCube.x + 6, pCube.y);
                        ctx.moveTo(pCube.x, pCube.y - 6); ctx.lineTo(pCube.x, pCube.y + 6);
                        ctx.stroke();

                        // 顶部标识头标
                        ctx.fillStyle = "#00E5FF";
                        ctx.fillRect(bx, by - 18, Math.max(130, bw + 20), 18);
                        ctx.fillStyle = "#050B14";
                        ctx.font = "bold 9px monospace";
                        ctx.fillText("AI视觉锁定: 青色工件", bx + 6, by - 5);

                        // 底部实测空间坐标脚标
                        ctx.fillStyle = "rgba(5, 11, 20, 0.85)";
                        ctx.fillRect(bx, by + bh + 4, Math.max(220, bw + 80), 18);
                        ctx.strokeStyle = "rgba(0, 229, 255, 0.4)";
                        ctx.lineWidth = 1;
                        ctx.strokeRect(bx, by + bh + 4, Math.max(220, bw + 80), 18);
                        ctx.fillStyle = "#00E5FF";
                        ctx.font = "9px monospace";
                        ctx.fillText("[" + cx.toFixed(3) + ", " + cy.toFixed(3) + ", " + cz.toFixed(3) + "] 精度: ±1.8mm", bx + 6, by + bh + 16);

                        // 2. 目标托盘放置区 B (橙色高对比度虚线标记)
                        var nu_b = 0.50;
                        var nv_b = 0.50 - 0.9495 * (-0.22);
                        var pTray = mapPt(nu_b, nv_b);
                        var tw = vW * 0.085;
                        var th = vH * 0.125;
                        var tx = pTray.x - tw / 2.0;
                        var ty = pTray.y - th / 2.0;

                        ctx.strokeStyle = "#FF7043";
                        ctx.lineWidth = 1.5;
                        ctx.setLineDash([4, 4]);
                        ctx.strokeRect(tx, ty, tw, th);
                        ctx.setLineDash([]);
                        ctx.fillStyle = "#FF7043";
                        ctx.font = "bold 9px monospace";
                        ctx.fillText("目标托盘 B [0.50, -0.22]", tx - 6, ty - 5);

                        return;
                    }

                    // =================== 相机 02: 3D 透视虚拟安全栅栏 (等比居中无扭曲对齐) ===================
                    if (!root.showSafetyEnvelope || root.selectedCamera !== 2) return;

                    // 底面: 工作台表面 Z=0.50m (物理不可击穿底限)
                    var b0 = mapPt(0.4383, 0.1683);
                    var b1 = mapPt(0.2403, 0.2946);
                    var b2 = mapPt(0.6045, 0.5991);
                    var b3 = mapPt(0.7842, 0.3649);

                    // 避障层: 高空巡航平面 Z=0.72m (门字形避障平移层)
                    var c0 = mapPt(0.4331, 0.0095);
                    var c1 = mapPt(0.2131, 0.1134);
                    var c2 = mapPt(0.6205, 0.3794);
                    var c3 = mapPt(0.8170, 0.1727);

                    // 顶盖层: 空间包络顶盖 Z=0.82m
                    var t0 = mapPt(0.4304, Math.max(0.002, -0.0720));
                    var t1 = mapPt(0.1988, 0.0178);
                    var t2 = mapPt(0.6295, 0.2555);
                    var t3 = mapPt(0.8345, 0.0699);

                    // 1. 底面工作台安全面 (绿色半透明微光 + 高亮绿底线)
                    ctx.beginPath();
                    ctx.moveTo(b0.x, b0.y);
                    ctx.lineTo(b1.x, b1.y);
                    ctx.lineTo(b2.x, b2.y);
                    ctx.lineTo(b3.x, b3.y);
                    ctx.closePath();
                    ctx.fillStyle = "rgba(0, 230, 118, 0.08)";
                    ctx.fill();
                    ctx.strokeStyle = "#00E676";
                    ctx.lineWidth = 1.8;
                    ctx.stroke();

                    // 2. 四根垂直立体防护立柱
                    ctx.strokeStyle = "#00E5FF";
                    ctx.lineWidth = 1.5;
                    var posts = [[b0, t0], [b1, t1], [b2, t2], [b3, t3]];
                    for (var i = 0; i < posts.length; i++) {
                        ctx.beginPath();
                        ctx.moveTo(posts[i][0].x, posts[i][0].y);
                        ctx.lineTo(posts[i][1].x, posts[i][1].y);
                        ctx.stroke();
                    }

                    // 3. 高空巡航避障平面 (青色半透明 + 亮青边框 + 虚线十字)
                    ctx.beginPath();
                    ctx.moveTo(c0.x, c0.y);
                    ctx.lineTo(c1.x, c1.y);
                    ctx.lineTo(c2.x, c2.y);
                    ctx.lineTo(c3.x, c3.y);
                    ctx.closePath();
                    ctx.fillStyle = "rgba(0, 229, 255, 0.10)";
                    ctx.fill();
                    ctx.strokeStyle = "#00E5FF";
                    ctx.lineWidth = 1.8;
                    ctx.stroke();

                    ctx.beginPath();
                    ctx.setLineDash([4, 4]);
                    ctx.strokeStyle = "rgba(0, 229, 255, 0.6)";
                    ctx.moveTo(c0.x, c0.y); ctx.lineTo(c2.x, c2.y);
                    ctx.moveTo(c1.x, c1.y); ctx.lineTo(c3.x, c3.y);
                    ctx.stroke();
                    ctx.setLineDash([]);

                    // 4. 空间顶盖边界 (品红色虚线)
                    ctx.beginPath();
                    ctx.setLineDash([6, 4]);
                    ctx.moveTo(t0.x, t0.y);
                    ctx.lineTo(t1.x, t1.y);
                    ctx.lineTo(t2.x, t2.y);
                    ctx.lineTo(t3.x, t3.y);
                    ctx.closePath();
                    ctx.strokeStyle = "#D500F9";
                    ctx.lineWidth = 1.2;
                    ctx.stroke();
                    ctx.setLineDash([]);

                    // 5. 标高刻度与层级标签
                    ctx.font = "bold 10px monospace";
                    ctx.fillStyle = "#00E5FF";
                    ctx.fillText("CRUISE PLANE [Z = 0.72m 避障巡航面]", c2.x + 8, c2.y + 2);

                    ctx.fillStyle = "#00E676";
                    ctx.fillText("TABLE BOUNDARY [Z = 0.50m 物理防砸硬底限]", b2.x + 8, b2.y + 4);

                    ctx.fillStyle = "#D500F9";
                    ctx.fillText("CEILING LIMIT [Z = 0.82m 空间顶盖]", t2.x + 8, t2.y - 4);
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            // 四角 HUD 瞄准括号 (仅在推流建立后呈现)
            Item {
                anchors.fill: parent
                visible: root.isStreamActive

                Rectangle { width: 14; height: 2; color: Theme.primary; anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 12 }
                Rectangle { width: 2; height: 14; color: Theme.primary; anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 12 }
                Rectangle { width: 14; height: 2; color: Theme.primary; anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 12 }
                Rectangle { width: 2; height: 14; color: Theme.primary; anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 12 }
                Rectangle { width: 14; height: 2; color: Theme.primary; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 12 }
                Rectangle { width: 2; height: 14; color: Theme.primary; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 12 }
                Rectangle { width: 14; height: 2; color: Theme.primary; anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 12 }
                Rectangle { width: 2; height: 14; color: Theme.primary; anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 12 }
            }

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
                    width: 130
                    radius: Theme.radiusSm
                    color: Qt.rgba(0.05, 0.06, 0.08, 0.8)
                    border.color: root.isStreamActive ? Theme.border : Theme.warning
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: root.isStreamActive ? "视讯流: 实时传输 (30FPS)" : "视讯流: 待机监听 (UDP:5002)"
                        color: root.isStreamActive ? Theme.tertiary : Theme.warning
                        font.family: Theme.fontMono; font.pixelSize: 9
                    }
                }
            }

            // 3D 全局透视监控安全包络指示层 (可点击切换包络显示)
            Rectangle {
                visible: root.isStreamActive && root.selectedCamera === 2
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 20
                height: 28
                width: survRow.implicitWidth + 24
                radius: Theme.radiusSm
                color: Qt.rgba(0.04, 0.06, 0.08, 0.88)
                border.color: root.showSafetyEnvelope ? Theme.tertiary : Theme.border
                border.width: 1

                RowLayout {
                    id: survRow
                    anchors.centerIn: parent
                    spacing: 8
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: root.showSafetyEnvelope ? Theme.tertiary : Theme.textDim
                    }
                    Text {
                        text: "3D 空间监控 | 电子安全包络: " + (root.showSafetyEnvelope ? "已启用 (点击隐藏)" : "已隐藏 (点击显示)")
                        color: root.showSafetyEnvelope ? Theme.textMain : Theme.textMuted
                        font.family: Theme.fontTitle; font.pixelSize: 10; font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showSafetyEnvelope = !root.showSafetyEnvelope
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
