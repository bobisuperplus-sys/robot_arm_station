#include "VideoStreamItem.h"
#include <QPainterPath>

VideoStreamItem::VideoStreamItem(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setOpaquePainting(true);

    // 待机雷达扫描行动画定时器 (30 FPS 刷新)
    connect(&m_animTimer, &QTimer::timeout, this, [this]() {
        if (m_currentFrame.isNull() || !m_connected) {
            m_scanlinePos += 3.0;
            if (m_scanlinePos > height()) {
                m_scanlinePos = 0;
            }
            update();
        }
    });
    m_animTimer.start(33);
}

void VideoStreamItem::setReceiver(GstVideoReceiver *receiver)
{
    if (m_receiver == receiver) return;

    if (m_receiver) {
        disconnect(m_receiver, &GstVideoReceiver::frameReceived, this, &VideoStreamItem::onFrameReceived);
        disconnect(m_receiver, &GstVideoReceiver::connectionStatusChanged, this, &VideoStreamItem::onConnectionStatusChanged);
    }

    m_receiver = receiver;

    if (m_receiver) {
        connect(m_receiver, &GstVideoReceiver::frameReceived, this, &VideoStreamItem::onFrameReceived, Qt::QueuedConnection);
        connect(m_receiver, &GstVideoReceiver::connectionStatusChanged, this, &VideoStreamItem::onConnectionStatusChanged, Qt::QueuedConnection);
    }

    emit receiverChanged();
}

void VideoStreamItem::onFrameReceived(const QImage &frame)
{
    m_currentFrame = frame;
    m_connected = true;
    static int pCount = 0;
    if (++pCount % 60 == 1) {
        qDebug() << "[VideoStreamItem] 收到渲染帧:" << frame.size() << "item size:" << width() << "x" << height();
    }
    emit hasFrameChanged();
    update();
}

void VideoStreamItem::onConnectionStatusChanged(bool connected)
{
    m_connected = connected;
    if (!connected) {
        m_currentFrame = QImage();
        emit hasFrameChanged();
    }
    update();
}

void VideoStreamItem::paint(QPainter *painter)
{
    QRectF targetRect(0, 0, width(), height());

    if (!m_currentFrame.isNull() && m_connected) {
        // 计算保持宽高比的等比缩放矩形
        QSizeF imgSize = m_currentFrame.size();
        QSizeF scaled = imgSize.scaled(targetRect.size(), Qt::KeepAspectRatio);
        QRectF drawRect(
            (targetRect.width() - scaled.width()) / 2.0,
            (targetRect.height() - scaled.height()) / 2.0,
            scaled.width(),
            scaled.height()
        );

        // 背景填充纯黑，避免黑边残影
        painter->fillRect(targetRect, QColor("#0C0E12"));
        painter->setRenderHint(QPainter::SmoothPixmapTransform, true);
        painter->drawImage(drawRect, m_currentFrame);
    } else {
        // 待机工业科技网格背景
        painter->fillRect(targetRect, QColor("#0C0E12"));

        // 绘制微光网格
        painter->setPen(QPen(QColor(43, 56, 68, 60), 1, Qt::DotLine));
        for (qreal x = 0; x < width(); x += 40) {
            painter->drawLine(QPointF(x, 0), QPointF(x, height()));
        }
        for (qreal y = 0; y < height(); y += 40) {
            painter->drawLine(QPointF(0, y), QPointF(width(), y));
        }

        // 绘制中心雷达圆环
        QPointF center(width() / 2.0, height() / 2.0);
        painter->setPen(QPen(QColor(0, 229, 255, 40), 1.5));
        painter->setBrush(Qt::NoBrush);
        painter->drawEllipse(center, 90, 90);
        painter->drawEllipse(center, 180, 180);

        // 扫描线
        painter->setPen(QPen(QColor(0, 229, 255, 80), 2));
        painter->drawLine(QPointF(0, m_scanlinePos), QPointF(width(), m_scanlinePos));

        // 提示文本
        painter->setPen(QColor("#00E5FF"));
        QFont font("JetBrains Mono", 12, QFont::Bold);
        painter->setFont(font);
        QString tipText = "[正在等待视讯推流接入: UDP 5002 H.264 RTP]";
        painter->drawText(targetRect, Qt::AlignCenter, tipText);

        painter->setPen(QColor("#8C95A6"));
        QFont subFont("Inter", 10);
        painter->setFont(subFont);
        QRectF subRect = targetRect.adjusted(0, 50, 0, 50);
        painter->drawText(subRect, Qt::AlignCenter, "请确保仿真物理引擎与相机推流服务 camera_streamer.py 已启动");
    }
}
