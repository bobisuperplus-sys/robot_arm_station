#pragma once

#include <QObject>
#include <QVariantList>
#include <QTimer>
#include <QDateTime>
#include <QTcpSocket>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>

/**
 * @brief 机械臂控制与遥测总线控制器
 * 管理 7 轴关节空间、TCP 笛卡尔位姿、末端夹爪、5 阶段任务状态机、多机位切换与 TCP JSON-RPC 全双工通信。
 */
class RobotRpcClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList jointAngles READ jointAngles NOTIFY telemetryUpdated)
    Q_PROPERTY(QVariantList jointTorques READ jointTorques NOTIFY telemetryUpdated)
    Q_PROPERTY(double tcpX READ tcpX NOTIFY telemetryUpdated)
    Q_PROPERTY(double tcpY READ tcpY NOTIFY telemetryUpdated)
    Q_PROPERTY(double tcpZ READ tcpZ NOTIFY telemetryUpdated)
    Q_PROPERTY(double tcpRoll READ tcpRoll NOTIFY telemetryUpdated)
    Q_PROPERTY(double tcpPitch READ tcpPitch NOTIFY telemetryUpdated)
    Q_PROPERTY(double tcpYaw READ tcpYaw NOTIFY telemetryUpdated)
    Q_PROPERTY(double gripperWidth READ gripperWidth WRITE setGripperWidth NOTIFY gripperChanged)
    Q_PROPERTY(double gripperForce READ gripperForce NOTIFY gripperChanged)
    Q_PROPERTY(int currentStage READ currentStage NOTIFY stageChanged)
    Q_PROPERTY(QString stageName READ stageName NOTIFY stageChanged)
    Q_PROPERTY(int cycleCount READ cycleCount NOTIFY cycleUpdated)
    Q_PROPERTY(double cycleElapsed READ cycleElapsed NOTIFY cycleUpdated)
    Q_PROPERTY(double cycleTotalEstimate READ cycleTotalEstimate NOTIFY cycleUpdated)
    Q_PROPERTY(bool emergencyStopped READ emergencyStopped NOTIFY estopChanged)
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectionChanged)
    Q_PROPERTY(QString activeCamera READ activeCamera NOTIFY cameraChanged)
    Q_PROPERTY(double cameraFov READ cameraFov NOTIFY cameraChanged)
    Q_PROPERTY(double cubeX READ cubeX NOTIFY cubePoseChanged)
    Q_PROPERTY(double cubeY READ cubeY NOTIFY cubePoseChanged)
    Q_PROPERTY(double cubeZ READ cubeZ NOTIFY cubePoseChanged)
    Q_PROPERTY(QString targetCubeInfo READ targetCubeInfo NOTIFY cubePoseChanged)
    Q_PROPERTY(QString poseDeltaInfo READ poseDeltaInfo NOTIFY cubePoseChanged)

public:
    explicit RobotRpcClient(QObject *parent = nullptr);
    ~RobotRpcClient() override;

    QVariantList jointAngles() const { return m_jointAngles; }
    QVariantList jointTorques() const { return m_jointTorques; }

    double tcpX() const { return m_tcpX; }
    double tcpY() const { return m_tcpY; }
    double tcpZ() const { return m_tcpZ; }
    double tcpRoll() const { return m_tcpRoll; }
    double tcpPitch() const { return m_tcpPitch; }
    double tcpYaw() const { return m_tcpYaw; }

    double gripperWidth() const { return m_gripperWidth; }
    double gripperForce() const { return m_gripperForce; }

    int currentStage() const { return m_currentStage; }
    QString stageName() const { return m_stageName; }

    int cycleCount() const { return m_cycleCount; }
    double cycleElapsed() const { return m_cycleElapsed; }
    double cycleTotalEstimate() const { return m_cycleTotalEstimate; }

    bool emergencyStopped() const { return m_emergencyStopped; }
    bool isConnected() const { return m_connected; }

    QString activeCamera() const { return m_activeCamera; }
    double cameraFov() const { return m_cameraFov; }

    double cubeX() const { return m_cubeX; }
    double cubeY() const { return m_cubeY; }
    double cubeZ() const { return m_cubeZ; }
    QString targetCubeInfo() const {
        return QString("目标工件: 青色方块 [%1, %2, %3]")
            .arg(m_cubeX, 0, 'f', 2)
            .arg(m_cubeY, 0, 'f', 2)
            .arg(m_cubeZ, 0, 'f', 2);
    }
    QString poseDeltaInfo() const {
        double dx = m_tcpX - m_cubeX;
        double dy = m_tcpY - m_cubeY;
        double distMm = std::sqrt(dx * dx + dy * dy) * 1000.0;
        return QString("视觉偏差: ΔXY %1mm | 抓取法向对齐").arg(distMm, 0, 'f', 1);
    }

public slots:
    void switchCamera(const QString &camName);
    void startAutoCycle();
    void randomizeTarget();
    void pauseTrajectory();
    void jogAxis(const QString &axis, double stepMm);
    void setGripperWidth(double widthMm);
    void triggerEstop();
    void resetToHome();
    void sendCliCommand(const QString &cmd);

private slots:
    void onSocketConnected();
    void onSocketDisconnected();
    void onSocketReadyRead();
    void tryConnect();

signals:
    void telemetryUpdated();
    void gripperChanged();
    void stageChanged();
    void cycleUpdated();
    void estopChanged();
    void connectionChanged();
    void cameraChanged();
    void cubePoseChanged();
    void logAdded(const QString &timestamp, const QString &tag, const QString &content, const QString &color);

private:
    QTcpSocket *m_socket = nullptr;
    QTimer m_reconnectTimer;
    QByteArray m_readBuffer;

    QVariantList m_jointAngles;
    QVariantList m_jointTorques;

    double m_tcpX = 0.500;
    double m_tcpY = 0.200;
    double m_tcpZ = 0.525;
    double m_tcpRoll = 179.8;
    double m_tcpPitch = 0.4;
    double m_tcpYaw = -45.2;

    double m_cubeX = 0.500;
    double m_cubeY = 0.200;
    double m_cubeZ = 0.525;

    double m_gripperWidth = 38.2;
    double m_gripperForce = 42.0;

    int m_currentStage = 1;
    QString m_stageName = "待机就绪";

    int m_cycleCount = 142;
    double m_cycleElapsed = 1.84;
    double m_cycleTotalEstimate = 3.20;

    bool m_emergencyStopped = false;
    bool m_connected = false;

    QString m_activeCamera = "overhead_cam";
    double m_cameraFov = 58.0;

    void sendRpc(const QString &method, const QJsonObject &params = QJsonObject());
    void appendLog(const QString &tag, const QString &content, const QString &color = "#F0F3F6");
};
