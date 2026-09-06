#pragma once

#include <QThread>
#include <QImage>
#include <QMutex>
#include <QElapsedTimer>
#include <gst/gst.h>
#include <gst/app/gstappsink.h>

/**
 * @brief GStreamer UDP H.264/RTP 视讯拉流解调线程
 * 监听指定 UDP 端口 (默认 5002)，接收 MuJoCo 相机流，硬解/软解为 RGB888 QImage 帧。
 */
class GstVideoReceiver : public QThread
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectionStatusChanged)
    Q_PROPERTY(double currentFps READ currentFps NOTIFY fpsUpdated)
    Q_PROPERTY(int latencyMs READ latencyMs NOTIFY latencyUpdated)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusChanged)

public:
    explicit GstVideoReceiver(QObject *parent = nullptr);
    ~GstVideoReceiver() override;

    bool isConnected() const { return m_connected; }
    double currentFps() const { return m_currentFps; }
    int latencyMs() const { return m_latencyMs; }
    QString statusText() const { return m_statusText; }

public slots:
    void startStream(int port = 5002);
    void stopStream();

signals:
    void frameReceived(const QImage &image);
    void connectionStatusChanged(bool connected);
    void fpsUpdated(double fps);
    void latencyUpdated(int latency);
    void statusChanged(const QString &status);

protected:
    void run() override;

private:
    int m_port = 5002;
    std::atomic<bool> m_running{false};
    bool m_connected = false;
    double m_currentFps = 0.0;
    int m_latencyMs = 15;
    QString m_statusText = "待机监听中";

    GstElement *m_pipeline = nullptr;
    GstElement *m_sink = nullptr;

    void cleanupGst();
};
