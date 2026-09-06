#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
机械臂工作站多媒体视频流推送服务 (Camera Streamer)
核心功能:
1. 通过 MuJoCo 离线渲染器 (Renderer) 毫秒级提取指定虚拟相机的 RGB 彩色像素矩阵；
2. 构建基于 GStreamer 的 H.264 / RTP 低延时推流管道；
3. 通过 UDP 广播实时视讯，支持 Qt 6 QML 上位机拉流显示与 AI 视觉模块消费。
"""

import os
import sys
import time
import subprocess
import shutil
import numpy as np
import mujoco

SCENE_XML = os.path.join(os.path.dirname(__file__), "..", "simulation", "franka_emika_panda", "workstation_scene.xml")


class WorkstationCameraStreamer:
    """机械臂工作站相机推流器"""
    def __init__(self, camera_name: str = "overhead_cam", host: str = "127.0.0.1", port: int = 5002, fps: int = 30, width: int = 960, height: int = 640):
        self.camera_name = camera_name
        self.host = host
        self.port = port
        self.fps = fps
        self.width = width
        self.height = height
        self.frame_bytes = width * height * 3

        print(f"正在加载场景模型: {SCENE_XML}")
        self.model = mujoco.MjModel.from_xml_path(SCENE_XML)
        self.data = mujoco.MjData(self.model)

        # 重置到 ready 待机姿态
        mujoco.mj_resetDataKeyframe(self.model, self.data, 1)

        # 初始化渲染器 (分辨率 960x640)
        self.renderer = mujoco.Renderer(self.model, height=self.height, width=self.width)
        self.running = False
        self.subproc = None

    def start_streaming(self):
        """启动物理迭代与 GStreamer RTP 推流"""
        gst_bin = shutil.which("gst-launch-1.0")
        if not gst_bin:
            raise RuntimeError("未检测到系统安装的 gst-launch-1.0，请确认 GStreamer 环境。")

        gst_cmd = [
            gst_bin, "-q",
            "fdsrc", "fd=0", "do-timestamp=true", f"blocksize={self.frame_bytes}", "!",
            "rawvideoparse", "format=rgb", f"width={self.width}", f"height={self.height}", f"framerate={self.fps}/1", "!",
            "videoconvert", "!",
            "video/x-raw,format=I420", "!",
            "x264enc", "tune=zerolatency", "speed-preset=ultrafast", "bitrate=2500", "key-int-max=15", "!",
            "rtph264pay", "config-interval=1", "pt=96", "!",
            "udpsink", f"host={self.host}", f"port={self.port}", "sync=false", "async=false"
        ]

        print("==================================================")
        print(f"视讯推流已启动: 摄像头 [{self.camera_name}] -> udp://{self.host}:{self.port}")
        print(f"分辨率: {self.width}x{self.height} | 目标帧率: {self.fps} FPS")
        print("==================================================")

        self.subproc = subprocess.Popen(gst_cmd, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.running = True

        frame_interval = 1.0 / self.fps
        last_t = time.time()
        frame_count = 0
        start_time = time.time()

        try:
            while self.running:
                loop_start = time.time()

                # 执行一步物理动力学更新
                mujoco.mj_step(self.model, self.data)

                # 提取相机画面
                self.renderer.update_scene(self.data, camera=self.camera_name)
                rgb_frame = self.renderer.render()

                if not rgb_frame.flags['C_CONTIGUOUS']:
                    rgb_frame = np.ascontiguousarray(rgb_frame)

                # 写入管道
                try:
                    self.subproc.stdin.write(rgb_frame.tobytes())
                    self.subproc.stdin.flush()
                except (BrokenPipeError, OSError):
                    break

                frame_count += 1
                if frame_count % (self.fps * 3) == 0:
                    real_fps = frame_count / (time.time() - start_time)
                    print(f"推流运行正常: 累计 {frame_count} 帧 | 实时帧率: {real_fps:.1f} FPS")

                elapsed = time.time() - loop_start
                sleep_time = frame_interval - elapsed
                if sleep_time > 0:
                    time.sleep(sleep_time)

        except KeyboardInterrupt:
            print("\n收到退出指令，停止视讯推流。")
        finally:
            self.stop()

    def stop(self):
        self.running = False
        if self.subproc:
            try:
                self.subproc.stdin.close()
                self.subproc.terminate()
            except Exception:
                pass
            self.subproc = None


def main():
    # 默认推流顶部相机 overhead_cam 到端口 5002 (避免与旧项目 5000 冲突)
    streamer = WorkstationCameraStreamer(camera_name="overhead_cam", port=5002)
    streamer.start_streaming()


if __name__ == "__main__":
    main()
