#include "GstVideoReceiver.h"
#include <QDebug>
#include <gst/video/video.h>

GstVideoReceiver::GstVideoReceiver(QObject *parent)
    : QThread(parent)
{
}

GstVideoReceiver::~GstVideoReceiver()
{
    stopStream();
}

void GstVideoReceiver::startStream(int port)
{
    if (isRunning()) {
        stopStream();
    }
    m_port = port;
    m_running = true;
    start();
}

void GstVideoReceiver::stopStream()
{
    m_running = false;
    if (isRunning()) {
        wait(2000);
    }
    cleanupGst();
    if (m_connected) {
        m_connected = false;
        emit connectionStatusChanged(false);
    }
}

void GstVideoReceiver::cleanupGst()
{
    if (m_pipeline) {
        gst_element_set_state(m_pipeline, GST_STATE_NULL);
        gst_object_unref(m_pipeline);
        m_pipeline = nullptr;
        m_sink = nullptr;
    }
}

void GstVideoReceiver::run()
{
    // 构建 GStreamer RTP H.264 UDP 解码接收管道
    QString pipeStr = QString(
        "udpsrc port=%1 caps=\"application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H264, payload=(int)96\" ! "
        "rtph264depay ! h264parse ! avdec_h264 ! videoconvert ! "
        "video/x-raw,format=RGB ! appsink name=sink emit-signals=false max-buffers=2 drop=true sync=false"
    ).arg(m_port);

    GError *error = nullptr;
    m_pipeline = gst_parse_launch(pipeStr.toUtf8().constData(), &error);

    if (error || !m_pipeline) {
        QString errStr = error ? QString::fromUtf8(error->message) : "未知管道错误";
        qWarning() << "[GstReceiver] 管道创建失败:" << errStr;
        if (error) g_error_free(error);
        m_statusText = "解码管道异常: " + errStr;
        emit statusChanged(m_statusText);
        return;
    }

    m_sink = gst_bin_get_by_name(GST_BIN(m_pipeline), "sink");
    if (!m_sink) {
        qWarning() << "[GstReceiver] 未找到 appsink 元素";
        cleanupGst();
        return;
    }

    gst_element_set_state(m_pipeline, GST_STATE_PLAYING);

    m_statusText = QString("正在监听 UDP:%1 视频流...").arg(m_port);
    emit statusChanged(m_statusText);

    QElapsedTimer fpsTimer;
    fpsTimer.start();
    int frameCount = 0;

    QElapsedTimer frameTimeoutTimer;
    frameTimeoutTimer.start();

    while (m_running) {
        // 每 25 毫秒尝试从 appsink 拉取样本
        GstSample *sample = gst_app_sink_try_pull_sample(GST_APP_SINK(m_sink), 25 * GST_MSECOND);
        if (!sample) {
            // 连续 3000ms 无帧时才判定断开
            if (m_connected && frameTimeoutTimer.hasExpired(3000)) {
                m_connected = false;
                m_currentFps = 0.0;
                emit connectionStatusChanged(false);
                emit fpsUpdated(0.0);
            }
            continue;
        }

        frameTimeoutTimer.restart();

        if (!m_connected) {
            m_connected = true;
            emit connectionStatusChanged(true);
            m_statusText = "视讯推流正常";
            emit statusChanged(m_statusText);
        }

        frameCount++;

        if (fpsTimer.elapsed() >= 1000) {
            m_currentFps = frameCount * 1000.0 / fpsTimer.elapsed();
            emit fpsUpdated(m_currentFps);
            frameCount = 0;
            fpsTimer.restart();
        }

        GstCaps *caps = gst_sample_get_caps(sample);
        GstStructure *s = gst_caps_get_structure(caps, 0);
        int width = 0, height = 0;
        gst_structure_get_int(s, "width", &width);
        gst_structure_get_int(s, "height", &height);

        GstBuffer *buffer = gst_sample_get_buffer(sample);
        GstMapInfo map;
        if (gst_buffer_map(buffer, &map, GST_MAP_READ)) {
            // 将 RGB 数据拷贝为独立的 QImage
            QImage img(map.data, width, height, width * 3, QImage::Format_RGB888);
            QImage frameCopy = img.copy();
            gst_buffer_unmap(buffer, &map);

            static int dbgCount = 0;
            if (++dbgCount % 60 == 1) {
                int rMid = qRed(frameCopy.pixel(width / 2, height / 2));
                int gMid = qGreen(frameCopy.pixel(width / 2, height / 2));
                int bMid = qBlue(frameCopy.pixel(width / 2, height / 2));
                int rCorner = qRed(frameCopy.pixel(10, 10));
                int gCorner = qGreen(frameCopy.pixel(10, 10));
                int bCorner = qBlue(frameCopy.pixel(10, 10));
                qDebug() << "[GstReceiver] 帧解码数据: w=" << width << "h=" << height
                         << "center RGB=(" << rMid << gMid << bMid << ")"
                         << "corner RGB=(" << rCorner << gCorner << bCorner << ")"
                         << "bytes=" << map.size;
            }

            emit frameReceived(frameCopy);
        }

        gst_sample_unref(sample);
    }

    cleanupGst();
}
