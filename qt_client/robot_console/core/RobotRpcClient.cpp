#include "RobotRpcClient.h"
#include <QRandomGenerator>

RobotRpcClient::RobotRpcClient(QObject *parent)
    : QObject(parent)
{
    // 初始化 7 轴基准角度与力矩
    m_jointAngles = QVariantList{-12.4, 28.6, 0.5, -118.2, 4.2, 94.1, 44.8};
    m_jointTorques = QVariantList{0.82, 14.10, 0.12, -18.40, 1.64, 3.80, 0.45};

    // 高频遥测微颤抖动定时器 (100ms 刷新，模拟工业 EtherCAT 遥测)
    connect(&m_tickTimer, &QTimer::timeout, this, [this]() {
        if (m_emergencyStopped) return;

        // 对力矩与微小位姿增加真实微抖动
        double jitter = (QRandomGenerator::global()->generateDouble() - 0.5) * 0.04;
        if (!m_jointTorques.isEmpty()) {
            double baseT4 = -18.40 + jitter * 2.0;
            m_jointTorques[3] = QString::number(baseT4, 'f', 2).toDouble();
            emit telemetryUpdated();
        }
    });
    m_tickTimer.start(100);

    // 任务流水线自动步进定时器
    connect(&m_cycleStepTimer, &QTimer::timeout, this, [this]() {
        if (!m_isAutoRunning || m_emergencyStopped) return;

        m_cycleElapsed += 0.5;
        if (m_cycleElapsed > m_cycleTotalEstimate) {
            m_cycleElapsed = 0.0;
            m_cycleCount++;
            emit cycleUpdated();
        }

        int nextStage = (m_currentStage % 5) + 1;
        m_currentStage = nextStage;

        switch (m_currentStage) {
        case 1:
            m_stageName = "视觉识别";
            appendLog("AI视觉", "相机视场角更新，锁定目标工件色块", "#00E5FF");
            break;
        case 2:
            m_stageName = "预抓取逼近";
            appendLog("轨迹规划", "逆运动学插补中，末端向预抓取点位下潜", "#00DAF3");
            break;
        case 3:
            m_stageName = "闭环抓取";
            setGripperWidth(38.0);
            appendLog("夹爪机构", "触觉力闭环紧固，当前夹持力 42N", "#00E676");
            break;
        case 4:
            m_stageName = "轨迹运送";
            appendLog("执行机构", "笛卡尔多项式平滑运送至目标托盘上方", "#D500F9");
            break;
        case 5:
            m_stageName = "放置归位";
            setGripperWidth(75.0);
            appendLog("任务调度", "工件成功放置在区域 B，准备复位初始位", "#22EF7E");
            break;
        }

        emit stageChanged();
        emit cycleUpdated();
    });
}

void RobotRpcClient::appendLog(const QString &tag, const QString &content, const QString &color)
{
    QString timeStr = QDateTime::currentDateTime().toString("HH:mm:ss.zzz");
    emit logAdded(timeStr, tag, content, color);
}

void RobotRpcClient::startAutoCycle()
{
    if (m_emergencyStopped) {
        appendLog("安全警告", "急停状态激活中，无法启动抓取流水线", "#E53935");
        return;
    }

    m_isAutoRunning = true;
    m_currentStage = 1;
    m_stageName = "视觉识别";
    m_cycleElapsed = 0.0;
    m_cycleStepTimer.start(1200);

    appendLog("控制指令", "启动全自动抓取搬运周期 (5 阶段状态机)", "#00E5FF");
    emit stageChanged();
    emit cycleUpdated();
}

void RobotRpcClient::randomizeTarget()
{
    double dx = (QRandomGenerator::global()->generateDouble() - 0.5) * 0.1;
    double dy = (QRandomGenerator::global()->generateDouble() - 0.5) * 0.1;
    m_tcpX = 0.500 + dx;
    m_tcpY = 0.200 + dy;

    appendLog("AI视觉", QString("目标方块位置已随机偏置至: (%1, %2, 0.525)")
                              .arg(m_tcpX, 0, 'f', 3)
                              .arg(m_tcpY, 0, 'f', 3),
              "#FFAB00");
    emit telemetryUpdated();
}

void RobotRpcClient::pauseTrajectory()
{
    m_isAutoRunning = false;
    m_cycleStepTimer.stop();
    appendLog("控制指令", "轨迹插补已暂停，保持当前关节刚度阻抗", "#FFAB00");
}

void RobotRpcClient::jogAxis(const QString &axis, double stepMm)
{
    if (m_emergencyStopped) {
        appendLog("安全警告", "急停生效中，轴动受阻", "#E53935");
        return;
    }

    double stepM = stepMm / 1000.0;
    if (axis == "+X") m_tcpX += stepM;
    else if (axis == "-X") m_tcpX -= stepM;
    else if (axis == "+Y") m_tcpY += stepM;
    else if (axis == "-Y") m_tcpY -= stepM;
    else if (axis == "+Z") m_tcpZ += stepM;
    else if (axis == "-Z") m_tcpZ -= stepM;
    else if (axis == "R+") m_tcpYaw += 5.0;
    else if (axis == "R-") m_tcpYaw -= 5.0;

    appendLog("空间点动", QString("轴向点动 [%1] 步长: %2mm -> TCP: (%3, %4, %5)")
                              .arg(axis)
                              .arg(stepMm, 0, 'f', 1)
                              .arg(m_tcpX, 0, 'f', 3)
                              .arg(m_tcpY, 0, 'f', 3)
                              .arg(m_tcpZ, 0, 'f', 3),
              "#00E5FF");
    emit telemetryUpdated();
}

void RobotRpcClient::setGripperWidth(double widthMm)
{
    m_gripperWidth = qBound(0.0, widthMm, 80.0);
    emit gripperChanged();
}

void RobotRpcClient::triggerEstop()
{
    m_emergencyStopped = !m_emergencyStopped;
    if (m_emergencyStopped) {
        m_isAutoRunning = false;
        m_cycleStepTimer.stop();
        appendLog("安全联锁", "紧急制动 (E-STOP) 已触发! 伺服断电锁死", "#E53935");
    } else {
        appendLog("安全联锁", "紧急制动已解除，系统处于低速安全待命状态", "#00E676");
    }
    emit estopChanged();
}

void RobotRpcClient::resetToHome()
{
    m_tcpX = 0.500;
    m_tcpY = 0.200;
    m_tcpZ = 0.525;
    m_tcpRoll = 179.8;
    m_tcpPitch = 0.4;
    m_tcpYaw = -45.2;
    m_gripperWidth = 38.2;
    m_currentStage = 1;
    m_stageName = "待机就绪";

    appendLog("执行机构", "机械臂已平滑复位至初始就绪姿态 (Ready Keyframe)", "#00E676");
    emit telemetryUpdated();
    emit gripperChanged();
    emit stageChanged();
}

void RobotRpcClient::sendCliCommand(const QString &cmd)
{
    if (cmd.trimmed().isEmpty()) return;
    appendLog("CLI指令", QString("> %1").arg(cmd), "#F0F3F6");

    if (cmd.contains("reset", Qt::CaseInsensitive)) {
        resetToHome();
    } else if (cmd.contains("stop", Qt::CaseInsensitive)) {
        pauseTrajectory();
    } else {
        appendLog("系统响应", "指令执行成功: ACK 0x00", "#00E5FF");
    }
}
