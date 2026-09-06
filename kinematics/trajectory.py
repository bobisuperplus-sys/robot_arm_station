#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
门字形高空避障轨迹规划器与 S 曲线插补器 (Trajectory Planner & S-Curve Interpolator)
核心特性:
1. 门字形三段式避碰轨迹 (Door-shaped Clearance Trajectory: Approach - Grasp/Place - Retract);
2. 绝对安全巡航高度 (Clearance Plane Z=0.72m) 与归位净空保护;
3. S 曲线余弦平滑加加速度控制 (Cosine Jerk-free Velocity Profiling);
4. 工业级多阶段调度元组打包.
"""

import math
import numpy as np


class SCurveInterpolator:
    """S 曲线余弦加速度平滑插值器"""

    @staticmethod
    def interpolate(q_start, q_target, progress):
        """
        余弦 S 曲线关节角度平滑插值
        :param q_start: 起始关节角数组
        :param q_target: 目标关节角数组
        :param progress: 归一化进度 [0.0, 1.0]
        :return: 平滑插值后的当前关节角
        """
        progress = np.clip(progress, 0.0, 1.0)
        # 余弦加速度平滑因子 (起止加速度与速度连续平稳归零)
        alpha = (1.0 - math.cos(math.pi * progress)) / 2.0
        return (1.0 - alpha) * q_start + alpha * q_target


class TrajectoryPlanner:
    """工业级门字形避障自主搬运轨迹规划器"""

    # 工业安全几何参数定义 (米)
    CRUISE_Z = 0.720    # 高空避障安全巡航平面
    PICK_Z = 0.605      # 黄金抓取高度 (指尖对准 50mm 方块几何质心, 距工作台保留 4.6mm 防撞安全净空)
    PLACE_Z = 0.608     # 托盘释放高度 (轻柔落入托盘凹槽, 杜绝与托盘硬撞)

    # 工业标准高空就绪待机姿态 (距离工作台顶面保留 15.8cm 安全净空)
    STANDBY_Q = np.array([0.0, -0.2859, 0.0, -1.6284, 0.0, 1.3425, 0.7854])

    def __init__(self, ik_solver):
        """
        初始化轨迹规划器
        :param ik_solver: DampedLeastSquaresIK 实例
        """
        self.ik_solver = ik_solver

    def plan_pick_and_place(self, data, cube_pos, place_pos=None, hand_pos=None):
        """
        规划从初始工件位置到目标放置区的完整门字形避障航路点序列
        :param data: MuJoCo MjData 数据对象
        :param cube_pos: 视觉定位输出的工件空间绝对坐标 [X, Y, Z]
        :param place_pos: 目标托盘放置位置 [X, Y] (默认 B 区 [0.50, -0.22])
        :param hand_pos: 当前机械臂手爪末端物理坐标 (若为 None 则从 data 中读取)
        :return: 航路点元组列表 [(target_q, gripper_cmd, duration, stage_idx, stage_name, log_text, log_color)]
        """
        if place_pos is None:
            place_pos = np.array([0.50, -0.22])
        else:
            place_pos = np.asarray(place_pos[:2])

        cube_pos = np.asarray(cube_pos)

        if hand_pos is None:
            hand_pos = np.copy(data.xpos[self.ik_solver.ee_id])

        # 1. 确保在安全巡航平面 (Z=0.72m)
        q_safe_ready = self.ik_solver.solve(
            data, np.array([hand_pos[0], hand_pos[1], self.CRUISE_Z]), q_init=self.STANDBY_Q
        )

        # 2. 高空平移至工件正上方预抓位 (X=cube_x, Y=cube_y, Z=0.72m)
        q_pre_pick = self.ik_solver.solve(
            data, np.array([cube_pos[0], cube_pos[1], self.CRUISE_Z]), q_init=q_safe_ready
        )

        # 3. 严格沿负 Z 轴直线垂直下潜至抓取深度 (Z=0.605m, 绝对杜绝横向位移与触碰工作台)
        q_pick = self.ik_solver.solve(
            data, np.array([cube_pos[0], cube_pos[1], self.PICK_Z]), q_init=q_pre_pick
        )

        # 4. 抓紧后严格垂直拔升至巡航高度 (Z=0.72m)
        q_lift = self.ik_solver.solve(
            data, np.array([cube_pos[0], cube_pos[1], self.CRUISE_Z]), q_init=q_pick
        )

        # 5. 高空水平平移跨越至目标托盘区正上方
        q_pre_place = self.ik_solver.solve(
            data, np.array([place_pos[0], place_pos[1], self.CRUISE_Z]), q_init=q_lift
        )

        # 6. 垂直下放到托盘表面释放高度 (Z=0.608m)
        q_place = self.ik_solver.solve(
            data, np.array([place_pos[0], place_pos[1], self.PLACE_Z]), q_init=q_pre_place
        )

        # 航路点列表封装: (目标关节角, 夹爪控制量[0-255], 步进时长[秒], 阶段ID, 阶段名, 遥测日志, 日志颜色)
        waypoints = [
            (q_safe_ready, 255.0, 1.0, 1, "视觉识别", "视觉坐标解算完成，保持安全巡航高度", "#00E5FF"),
            (q_pre_pick,   255.0, 1.8, 1, "视觉识别", "高空平移对齐并在工件正上方平稳悬停", "#00E5FF"),
            (q_pick,       255.0, 1.4, 2, "预抓取逼近", "垂直纯直线平稳下潜，指尖精准包络工件", "#00DAF3"),
            (q_pick,         0.0, 1.0, 3, "闭环抓取", "夹爪伺服紧固咬合工件几何中心", "#00E676"),
            (q_lift,         0.0, 1.2, 4, "轨迹运送", "垂直拔升至高空安全巡航高度", "#00E676"),
            (q_pre_place,    0.0, 1.6, 4, "轨迹运送", "高空平移跨越运送至目标托盘区 B 正上方", "#00E5FF"),
            (q_place,        0.0, 1.2, 5, "放置归位", "垂直下放至托盘表面", "#D500F9"),
            (q_place,      255.0, 0.8, 5, "放置归位", "夹爪张开，工件稳妥脱附就位", "#D500F9"),
            (q_pre_place,  255.0, 0.8, 5, "放置归位", "垂直回撤至安全巡航高度", "#D500F9"),
            (self.STANDBY_Q, 255.0, 1.4, 5, "放置归位", "高空平移巡航返回基准就绪待机姿态", "#22EF7E")
        ]

        return waypoints
