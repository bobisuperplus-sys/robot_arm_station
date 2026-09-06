#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
机械臂工作站 3D 交互式可视化运行器 (MuJoCo Interactive 3D Viewer)
功能:
1. 启动硬件加速的 3D 物理交互窗口；
2. 支持鼠标左键旋转视角、右键平移、滚轮缩放；
3. 支持双击方块并拖拽施加外力，实时观测物理引擎碰撞与动力学响应。
"""

import os
import sys
import time
import mujoco
import mujoco.viewer

SCENE_XML = os.path.join(os.path.dirname(__file__), "franka_emika_panda", "workstation_scene.xml")


def main():
    print("正在初始化 MuJoCo 3D 物理引擎...")
    model = mujoco.MjModel.from_xml_path(SCENE_XML)
    data = mujoco.MjData(model)

    # 载入待机初始位姿关键帧 (ready keyframe)
    mujoco.mj_resetDataKeyframe(model, data, 1)

    print("==================================================")
    print("机械臂工作站交互式 3D 窗口已启动")
    print("控制提示:")
    print(" - 鼠标左键拖拽: 旋转 3D 视角")
    print(" - 鼠标右键拖拽: 平移 3D 视角")
    print(" - 滚轮: 缩放观察距离")
    print(" - 按空格键 [Space]: 暂停 / 继续物理仿真")
    print(" - 按 [Backspace]: 复位初始状态")
    print("==================================================")

    # 启动交互式可视化窗口
    mujoco.viewer.launch(model, data)


if __name__ == "__main__":
    main()
