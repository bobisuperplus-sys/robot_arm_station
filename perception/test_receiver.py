#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
机械臂工作站视讯拉流测试客户端 (Stream Receiver Tester)
从 UDP 端口接收 H.264 / RTP 视频流并实时解析显示
自动兼容: 支持原生 OpenCV GStreamer 或自动降级为系统 gst-launch-1.0 原生播放窗口
"""

import sys
import shutil
import subprocess
import cv2


def run_native_player(port: int = 5002):
    """当 Python OpenCV 未编译 GStreamer 支持时，直接调用系统原生 gst-launch 播放窗口"""
    gst_bin = shutil.which("gst-launch-1.0")
    if not gst_bin:
        print("错误: 系统未检测到 gst-launch-1.0 命令，请确认 GStreamer 环境安装。")
        sys.exit(1)

    print("OpenCV 未开启 GStreamer 支持，正在调用系统原生硬件/软件播放窗口 (autovideosink)...")
    cmd = [
        gst_bin, "-q",
        "udpsrc", f"port={port}",
        "caps=application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H264, payload=(int)96", "!",
        "rtph264depay", "!",
        "h264parse", "!",
        "avdec_h264", "!",
        "videoconvert", "!",
        "autovideosink", "sync=false"
    ]
    try:
        subprocess.run(cmd)
    except KeyboardInterrupt:
        print("\n拉流已停止。")


def main(port: int = 5002):
    print(f"正在监听视讯流: udp://127.0.0.1:{port} ...")
    gst_pipe = (
        f"udpsrc port={port} "
        f"caps=\"application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H264, payload=(int)96\" ! "
        f"rtph264depay ! h264parse ! avdec_h264 ! videoconvert ! video/x-raw, format=BGR ! appsink drop=true sync=false"
    )

    cap = cv2.VideoCapture(gst_pipe, cv2.CAP_GSTREAMER)
    if not cap.isOpened():
        # 自动切换到系统原生播放器
        run_native_player(port)
        return

    print("已成功捕获实时视讯流，正在接收画面 (按 Q 键退出)...")
    try:
        while True:
            ret, frame = cap.read()
            if not ret or frame is None:
                continue
            cv2.imshow(f"Robot Arm Live Feed (UDP:{port})", frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
    finally:
        cap.release()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
