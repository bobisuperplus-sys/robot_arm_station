cmake_minimum_required(VERSION 3.16)

project(robot_console VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Network)
find_package(PkgConfig REQUIRED)
pkg_check_modules(GST REQUIRED IMPORTED_TARGET gstreamer-1.0 gstreamer-app-1.0 gstreamer-video-1.0)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(approbot_console
    main.cpp
    core/GstVideoReceiver.h
    core/GstVideoReceiver.cpp
    core/VideoStreamItem.h
    core/VideoStreamItem.cpp
    core/RobotRpcClient.h
    core/RobotRpcClient.cpp
)

qt_add_qml_module(approbot_console
    URI robot_console
    VERSION 1.0
    QML_FILES
        Main.qml
        theme/Theme.qml
        components/CyberCard.qml
        components/StatusBadge.qml
        components/CyberButton.qml
        components/JointBar.qml
        components/JogPad.qml
        views/TopHeaderBar.qml
        views/VideoViewport.qml
        views/TaskPipelineCard.qml
        views/JointTelemetryCard.qml
        views/GripperJogCard.qml
        views/TerminalLogCard.qml
    RESOURCES
        theme/qmldir
)

target_include_directories(approbot_console PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/core
)

target_link_libraries(approbot_console
    PRIVATE
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::Network
        PkgConfig::GST
)

set_target_properties(approbot_console PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

install(TARGETS approbot_console
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
