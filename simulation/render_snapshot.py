#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
机械臂工作站离线渲染与多视角快照生成脚本
生成:
1. 侧方 3D 全局监控视角 (surveillance_cam) - 展示机械臂、工作台与正方体三维布局
2. 顶部俯视机器视觉相机 (overhead_cam) - 展示用于图像识别的鸟瞰视角
"""

import sys
import os
import mujoco
import cv2
import numpy as np

SCENE_XML = os.path.join(os.path.dirname(__file__), "franka_emika_panda", "workstation_scene.xml")
SNAPSHOT_DIR = os.path.join(os.path.dirname(__file__), "snapshots")


def main():
    os.makedirs(SNAPSHOT_DIR, exist_ok=True)

    print("正在加载仿真物理场景...")
    model = mujoco.MjModel.from_xml_path(SCENE_XML)
    data = mujoco.MjData(model)

    # 重置到初始待机姿态关键帧 (ready keyframe)
    mujoco.mj_resetDataKeyframe(model, data, 1)
    # 推进几步物理模拟让重力和接触稳定
    for _ in range(50):
        mujoco.mj_step(model, data)

    # 创建 1280x720 离线高清渲染器
    renderer = mujoco.Renderer(model, height=720, width=1280)

    # 1. 渲染全局监控视角
    renderer.update_scene(data, camera="surveillance_cam")
    img_surveillance = renderer.render()
    img_surveillance_bgr = cv2.cvtColor(img_surveillance, cv2.COLOR_RGB2BGR)

    # 绘制 OSD 标注信息
    cv2.putText(img_surveillance_bgr, "MHS ROBOTIC ARM WORKSTATION [3D PERSPECTIVE]", (30, 45),
                cv2.FONT_HERSHEY_SIMPLEX, 0.9, (255, 255, 255), 2)
    cv2.putText(img_surveillance_bgr, "Target Workpiece (A Pos): Cyan Cube 50mm", (30, 85),
                cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0, 230, 255), 2)
    cv2.putText(img_surveillance_bgr, "Destination Goal (B Pos): Orange Target Area", (30, 120),
                cv2.FONT_HERSHEY_SIMPLEX, 0.65, (50, 150, 255), 2)

    path_surveillance = os.path.join(SNAPSHOT_DIR, "scene_3d_view.jpg")
    cv2.imwrite(path_surveillance, img_surveillance_bgr)
    print(f"✅ 全局 3D 监控视角快照已保存至: {path_surveillance}")

    # 2. 渲染顶部俯视机器视觉相机
    renderer.update_scene(data, camera="overhead_cam")
    img_overhead = renderer.render()
    img_overhead_bgr = cv2.cvtColor(img_overhead, cv2.COLOR_RGB2BGR)

    cv2.putText(img_overhead_bgr, "OVERHEAD VISION SENSOR (Eye-to-Hand 1080P)", (30, 45),
                cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 128), 2)

    path_overhead = os.path.join(SNAPSHOT_DIR, "overhead_camera_view.jpg")
    cv2.imwrite(path_overhead, img_overhead_bgr)
    print(f"✅ 顶部视觉相机快照已保存至: {path_overhead}")

    # 3. 拼合双视角对比图
    img1_resized = cv2.resize(img_surveillance_bgr, (640, 360))
    img2_resized = cv2.resize(img_overhead_bgr, (640, 360))
    combined = np.hstack((img1_resized, img2_resized))

    path_combined = os.path.join(SNAPSHOT_DIR, "workstation_dual_view.jpg")
    cv2.imwrite(path_combined, combined)
    print(f"✅ 双视角对比合成图已保存至: {path_combined}")


if __name__ == "__main__":
    main()
