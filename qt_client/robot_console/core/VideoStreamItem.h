#pragma once

#include <QQuickPaintedItem>
#include <QImage>
#include <QPainter>
#include <QTimer>
#include "GstVideoReceiver.h"

/**
 * @brief QML 视讯渲染绘制组件
 * 继承自 QQuickPaintedItem，实现 GStreamer 视讯流的高性能自适应缩放绘制，
 * 并在无信号时呈现工业科技感雷达网格待机画面。
 */
class VideoStreamItem : public QQuickPaintedItem
{
    Q_OBJECT
    Q_PROPERTY(GstVideoReceiver* receiver READ receiver WRITE setReceiver NOTIFY receiverChanged)
    Q_PROPERTY(bool hasFrame READ hasFrame NOTIFY hasFrameChanged)

public:
    explicit VideoStreamItem(QQuickItem *parent = nullptr);
    ~VideoStreamItem() override = default;

    GstVideoReceiver* receiver() const { return m_receiver; }
    void setReceiver(GstVideoReceiver *receiver);

    bool hasFrame() const { return !m_currentFrame.isNull(); }

    void paint(QPainter *painter) override;

public slots:
    void onFrameReceived(const QImage &frame);
    void onConnectionStatusChanged(bool connected);

signals:
    void receiverChanged();
    void hasFrameChanged();

private:
    GstVideoReceiver *m_receiver = nullptr;
    QImage m_currentFrame;
    bool m_connected = false;
    double m_scanlinePos = 0.0;
    QTimer m_animTimer;
};
