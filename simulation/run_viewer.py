#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
机械臂工作站 3D 交互式可视化运行器 (MuJoCo 3D Viewer)
适配 Linux Hyprland / Wayland 桌面环境，强制启用 XWayland 消除窗口定位协议警告
"""

import os
import sys
import time
import warnings

# 强制 GLFW 使用 XWayland 后端，彻底解决 Wayland 协议无法获取窗口全局坐标 (65548) 的警告与崩溃
os.environ["GLFW_PLATFORM"] = "x11"
# 过滤无关的 GLFW 原生警告
warnings.filterwarnings("ignore", category=UserWarning)

import mujoco
import mujoco.viewer

SCENE_XML = os.path.join(os.path.dirname(__file__), "franka_emika_panda", "workstation_scene.xml")


def main():
    print("正在初始化 MuJoCo 3D 物理引擎...")
    if not os.path.exists(SCENE_XML):
        print(f"错误: 未找到场景定义文件: {SCENE_XML}")
        sys.exit(1)

    model = mujoco.MjModel.from_xml_path(SCENE_XML)
    data = mujoco.MjData(model)

    # 载入待机初始位姿关键帧 (ready keyframe)
    mujoco.mj_resetDataKeyframe(model, data, 1)

    print("==================================================")
    print("机械臂工作站交互式 3D 窗口启动成功")
    print("控制提示:")
    print(" - 鼠标左键拖拽: 旋转 3D 观察视角")
    print(" - 鼠标右键拖拽: 平移 3D 视角")
    print(" - 鼠标滚轮: 缩放视角")
    print(" - 按空格键 [Space]: 暂停 / 继续物理步进")
    print(" - 双击正方体并拖拽: 施加外力拖动，观察物理碰撞")
    print(" - 关闭窗口或按 Ctrl+C: 安全退出")
    print("==================================================")

    # 使用 launch_passive 提供更高的事件循环稳定性与异常防护
    with mujoco.viewer.launch_passive(model, data) as viewer:
        try:
            while viewer.is_running():
                step_start = time.time()

                # 执行一步物理动力学计算 (步长为 0.002s)
                mujoco.mj_step(model, data)

                # 将物理状态同步渲染至 3D 窗口
                viewer.sync()

                # 保持 60 FPS 渲染节拍，避免无限制死循环占满 CPU
                time_until_next_step = model.opt.timestep - (time.time() - step_start)
                if time_until_next_step > 0:
                    time.sleep(time_until_next_step)
        except KeyboardInterrupt:
            print("\n收到退出信号，安全关闭仿真窗口。")


if __name__ == "__main__":
    main()
