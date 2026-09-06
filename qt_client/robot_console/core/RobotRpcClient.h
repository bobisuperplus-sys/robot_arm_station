#pragma once

#include <QObject>
#include <QVariantList>
#include <QTimer>
#include <QDateTime>

/**
 * @brief 机械臂控制与遥测总线控制器
 * 管理 7 轴关节空间、TCP 笛卡尔位姿、末端夹爪、5 阶段任务状态机与指令总线交互。
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
    Q_PROPERTY(QString targetCubeInfo READ targetCubeInfo CONSTANT)
    Q_PROPERTY(QString poseDeltaInfo READ poseDeltaInfo CONSTANT)

public:
    explicit RobotRpcClient(QObject *parent = nullptr);
    ~RobotRpcClient() override = default;

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

    QString targetCubeInfo() const { return "待抓取目标方块 [X: 0.50m, Y: 0.20m, Z: 0.52m] 置信度: 99%"; }
    QString poseDeltaInfo() const { return "视觉定位偏差: Δx: 0.002m | 姿态对齐: 良好"; }

public slots:
    void startAutoCycle();
    void randomizeTarget();
    void pauseTrajectory();
    void jogAxis(const QString &axis, double stepMm);
    void setGripperWidth(double widthMm);
    void triggerEstop();
    void resetToHome();
    void sendCliCommand(const QString &cmd);

signals:
    void telemetryUpdated();
    void gripperChanged();
    void stageChanged();
    void cycleUpdated();
    void estopChanged();
    void connectionChanged();
    void logAdded(const QString &timestamp, const QString &tag, const QString &content, const QString &color);

private:
    QVariantList m_jointAngles;
    QVariantList m_jointTorques;

    double m_tcpX = 0.500;
    double m_tcpY = 0.200;
    double m_tcpZ = 0.525;
    double m_tcpRoll = 179.8;
    double m_tcpPitch = 0.4;
    double m_tcpYaw = -45.2;

    double m_gripperWidth = 38.2;
    double m_gripperForce = 42.0;

    int m_currentStage = 3;
    QString m_stageName = "闭环抓取";

    int m_cycleCount = 142;
    double m_cycleElapsed = 1.84;
    double m_cycleTotalEstimate = 3.20;

    bool m_emergencyStopped = false;
    bool m_connected = true;
    bool m_isAutoRunning = false;

    QTimer m_tickTimer;
    QTimer m_cycleStepTimer;

    void appendLog(const QString &tag, const QString &content, const QString &color = "#F0F3F6");
};
