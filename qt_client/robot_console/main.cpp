#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <gst/gst.h>

#include "core/GstVideoReceiver.h"
#include "core/VideoStreamItem.h"
#include "core/RobotRpcClient.h"

int main(int argc, char *argv[])
{
    // 初始化 GStreamer 多媒体框架
    gst_init(&argc, &argv);

    // 适配 Wayland / Hyprland 环境，强制锁定 Basic 控件样式，防止崩溃
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    QQuickStyle::setStyle("Basic");

    QGuiApplication app(argc, argv);
    app.setOrganizationName("MHS");
    app.setApplicationName("RobotDigitalTwinConsole");

    // 向 QML 引擎注册 C++ 核心组件
    qmlRegisterType<GstVideoReceiver>("robot_console", 1, 0, "GstVideoReceiver");
    qmlRegisterType<VideoStreamItem>("robot_console", 1, 0, "VideoStreamItem");
    qmlRegisterType<RobotRpcClient>("robot_console", 1, 0, "RobotRpcClient");

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("robot_console", "Main");

    int ret = QGuiApplication::exec();

    // 退出时释放 GStreamer 资源
    gst_deinit();
    return ret;
}
