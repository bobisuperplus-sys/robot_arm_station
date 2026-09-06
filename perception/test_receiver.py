#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
机械臂工作站视讯拉流测试客户端 (Stream Receiver Tester)
从 UDP:5002 接收 H.264 / RTP 视频流并实时解析显示
"""

import sys
import cv2


def main(port: int = 5002):
    print(f"正在监听视讯流: udp://127.0.0.1:{port} ...")
    gst_pipe = (
        f"udpsrc port={port} "
        f"caps=\"application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H264, payload=(int)96\" ! "
        f"rtph264depay ! h264parse ! avdec_h264 ! videoconvert ! video/x-raw, format=BGR ! appsink drop=true sync=false"
    )

    cap = cv2.VideoCapture(gst_pipe, cv2.CAP_GSTREAMER)
    if not cap.isOpened():
        print("错误: 无法打开 GStreamer 拉流管道，请检查推流服务是否正在运行。")
        sys.exit(1)

    print("已成功捕获实时视讯流，正在接收画面 (按 Q 键退出)...")
    try:
        while True:
            ret, frame = cap.read()
            if not ret or frame is None:
                continue
            cv2.imshow("Robot Arm Live Feed (UDP:5002)", frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
    finally:
        cap.release()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
