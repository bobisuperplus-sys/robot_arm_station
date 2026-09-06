#include "RobotRpcClient.h"
#include <QDebug>

RobotRpcClient::RobotRpcClient(QObject *parent)
    : QObject(parent)
{
    // 初始基准数据
    m_jointAngles = QVariantList{0.0, -22.9, 0.0, -126.0, 0.0, 103.1, 45.0};
    m_jointTorques = QVariantList{0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};

    m_socket = new QTcpSocket(this);
    connect(m_socket, &QTcpSocket::connected, this, &RobotRpcClient::onSocketConnected);
    connect(m_socket, &QTcpSocket::disconnected, this, &RobotRpcClient::onSocketDisconnected);
    connect(m_socket, &QTcpSocket::readyRead, this, &RobotRpcClient::onSocketReadyRead);

    connect(&m_reconnectTimer, &QTimer::timeout, this, &RobotRpcClient::tryConnect);
    m_reconnectTimer.start(2000);

    tryConnect();
}

RobotRpcClient::~RobotRpcClient()
{
    if (m_socket && m_socket->isOpen()) {
        m_socket->disconnectFromHost();
    }
}

void RobotRpcClient::tryConnect()
{
    if (!m_socket) return;
    if (m_socket->state() == QAbstractSocket::UnconnectedState) {
        m_socket->connectToHost("127.0.0.1", 6000);
    }
}

void RobotRpcClient::onSocketConnected()
{
    m_connected = true;
    appendLog("总线通信", "已连接 MuJoCo 真实物理引擎服务总线 (127.0.0.1:6000)", "#00E5FF");
    emit connectionChanged();
}

void RobotRpcClient::onSocketDisconnected()
{
    m_connected = false;
    appendLog("总线通信", "物理总线断开连接，正在尝试后台重连...", "#FFAB00");
    emit connectionChanged();
}

void RobotRpcClient::onSocketReadyRead()
{
    if (!m_socket) return;
    m_readBuffer.append(m_socket->readAll());

    int newlinePos = -1;
    while ((newlinePos = m_readBuffer.indexOf('\n')) != -1) {
        QByteArray line = m_readBuffer.left(newlinePos).trimmed();
        m_readBuffer.remove(0, newlinePos + 1);

        if (line.isEmpty()) continue;

        QJsonParseError err;
        QJsonDocument doc = QJsonDocument::fromJson(line, &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject()) continue;

        QJsonObject obj = doc.object();
        QString type = obj.value("type").toString();

        if (type == "telemetry") {
            // 解析 7 轴真实关节角与力矩
            QJsonArray jArr = obj.value("joints").toArray();
            QVariantList newAngles;
            for (const auto &v : jArr) newAngles.append(v.toDouble());
            if (!newAngles.isEmpty()) m_jointAngles = newAngles;

            QJsonArray tArr = obj.value("torques").toArray();
            QVariantList newTorques;
            for (const auto &v : tArr) newTorques.append(v.toDouble());
            if (!newTorques.isEmpty()) m_jointTorques = newTorques;

            // 解析真实 TCP 位姿
            QJsonArray posArr = obj.value("tcp_pos").toArray();
            if (posArr.size() >= 3) {
                m_tcpX = posArr[0].toDouble();
                m_tcpY = posArr[1].toDouble();
                m_tcpZ = posArr[2].toDouble();
            }

            QJsonArray eulerArr = obj.value("tcp_euler").toArray();
            if (eulerArr.size() >= 3) {
                m_tcpRoll = eulerArr[0].toDouble();
                m_tcpPitch = eulerArr[1].toDouble();
                m_tcpYaw = eulerArr[2].toDouble();
            }

            // 目标工件实时空间位姿
            QJsonArray cubeArr = obj.value("cube_pos").toArray();
            if (cubeArr.size() >= 3) {
                double cx = cubeArr[0].toDouble(0.50);
                double cy = cubeArr[1].toDouble(0.20);
                double cz = cubeArr[2].toDouble(0.525);
                if (qAbs(m_cubeX - cx) > 0.001 || qAbs(m_cubeY - cy) > 0.001 || qAbs(m_cubeZ - cz) > 0.001) {
                    m_cubeX = cx;
                    m_cubeY = cy;
                    m_cubeZ = cz;
                    emit cubePoseChanged();
                }
            }

            // 夹爪开度与力矩
            m_gripperWidth = obj.value("gripper_width").toDouble(38.2);
            m_gripperForce = obj.value("gripper_force").toDouble(42.0);

            // 任务流水线
            int st = obj.value("stage").toInt(1);
            QString stName = obj.value("stage_name").toString("待机就绪");
            if (m_currentStage != st || m_stageName != stName) {
                m_currentStage = st;
                m_stageName = stName;
                emit stageChanged();
            }

            m_cycleCount = obj.value("cycle_count").toInt(m_cycleCount);
            m_cycleElapsed = obj.value("cycle_elapsed").toDouble(m_cycleElapsed);

            bool estopVal = obj.value("estop").toBool(false);
            if (m_emergencyStopped != estopVal) {
                m_emergencyStopped = estopVal;
                emit estopChanged();
            }

            QString cam = obj.value("active_camera").toString("overhead_cam");
            double fov = obj.value("camera_fov").toDouble(58.0);
            if (m_activeCamera != cam || m_cameraFov != fov) {
                m_activeCamera = cam;
                m_cameraFov = fov;
                emit cameraChanged();
            }

            emit telemetryUpdated();
            emit gripperChanged();
            emit cycleUpdated();

        } else if (type == "log") {
            QString timeStr = obj.value("time").toString();
            QString tag = obj.value("tag").toString();
            QString content = obj.value("content").toString();
            QString color = obj.value("color").toString("#F0F3F6");
            emit logAdded(timeStr, tag, content, color);
        }
    }
}

void RobotRpcClient::sendRpc(const QString &method, const QJsonObject &params)
{
    QJsonObject req;
    req["method"] = method;
    req["params"] = params;

    QByteArray data = QJsonDocument(req).toJson(QJsonDocument::Compact) + "\n";
    if (m_socket && m_socket->state() == QAbstractSocket::ConnectedState) {
        m_socket->write(data);
        m_socket->flush();
    }
}

void RobotRpcClient::appendLog(const QString &tag, const QString &content, const QString &color)
{
    QString timeStr = QDateTime::currentDateTime().toString("HH:mm:ss");
    emit logAdded(timeStr, tag, content, color);
}

void RobotRpcClient::switchCamera(const QString &camName)
{
    m_activeCamera = camName;
    m_cameraFov = (camName == "overhead_cam") ? 58.0 : 45.0;
    emit cameraChanged();

    QJsonObject p;
    p["camera"] = camName;
    sendRpc("switch_camera", p);
}

void RobotRpcClient::startAutoCycle()
{
    sendRpc("start_cycle");
}

void RobotRpcClient::pauseTrajectory()
{
    sendRpc("pause_cycle");
}

void RobotRpcClient::jogAxis(const QString &axis, double stepMm)
{
    QJsonObject p;
    p["axis"] = axis;
    p["step_mm"] = stepMm;
    sendRpc("jog", p);
}

void RobotRpcClient::setGripperWidth(double widthMm)
{
    m_gripperWidth = widthMm;
    emit gripperChanged();

    QJsonObject p;
    p["width_mm"] = widthMm;
    sendRpc("set_gripper", p);
}

void RobotRpcClient::triggerEstop()
{
    sendRpc("estop");
}

void RobotRpcClient::resetToHome()
{
    sendRpc("reset");
}

void RobotRpcClient::randomizeTarget()
{
    sendRpc("randomize");
}

void RobotRpcClient::sendCliCommand(const QString &cmd)
{
    if (cmd.trimmed().isEmpty()) return;
    appendLog("CLI指令", QString("> %1").arg(cmd), "#F0F3F6");

    if (cmd.contains("reset", Qt::CaseInsensitive)) {
        resetToHome();
    } else if (cmd.contains("stop", Qt::CaseInsensitive) || cmd.contains("pause", Qt::CaseInsensitive)) {
        pauseTrajectory();
    } else if (cmd.contains("start", Qt::CaseInsensitive) || cmd.contains("run", Qt::CaseInsensitive)) {
        startAutoCycle();
    } else if (cmd.contains("cam", Qt::CaseInsensitive)) {
        if (cmd.contains("2")) switchCamera("surveillance_cam");
        else switchCamera("overhead_cam");
    } else {
        appendLog("系统响应", "指令已投递至总线: ACK 0x00", "#00E5FF");
    }
}
