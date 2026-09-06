#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
6-DOF 阻尼最小二乘 (Damped Least Squares, DLS) 逆运动学求解器
核心特性:
1. 姿态绝对锁死约束 (限制末端垂直向下指向工作台, 杜绝乱转与翻转钻桌底);
2. 奇异点阻尼自适应回避 (Levenberg-Marquardt 正则化);
3. 关节软硬件限位安全裁剪 (Joint Limits Clamping);
4. 无副作用解算 (解算前后自动保存并恢复物理引擎瞬时状态).
"""

import numpy as np
import mujoco


class DampedLeastSquaresIK:
    """工业级 6-DOF 阻尼最小二乘逆运动学求解器"""

    # 默认工业夹爪姿态: 严格垂直向下指向工作台 (Z 轴朝下)
    DEFAULT_DOWNWARD_ROT = np.array([
        [1.0,  0.0,  0.0],
        [0.0, -1.0,  0.0],
        [0.0,  0.0, -1.0]
    ])

    def __init__(self, model, end_effector_name="hand", lambda_val=0.01):
        """
        初始化逆解器
        :param model: MuJoCo MjModel 模型对象
        :param end_effector_name: 末端执行器刚体名称 (默认为 'hand')
        :param lambda_val: 阻尼阻抗系数 (防止奇异性位姿速度爆炸)
        """
        self.model = model
        self.ee_id = mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_BODY, end_effector_name)
        if self.ee_id < 0:
            raise ValueError(f"未在模型中找到末端执行器刚体: {end_effector_name}")
        self.lambda_val = lambda_val

    def solve(self, data, target_pos, target_mat=None, q_init=None,
              max_steps=150, pos_tol=0.001, rot_tol=0.01, step_limit=0.05):
        """
        执行 6-DOF 阻尼最小二乘逆运动学求解
        :param data: MuJoCo MjData 数据对象
        :param target_pos: 目标笛卡尔空间坐标 [X, Y, Z]
        :param target_mat: 目标 3x3 旋转矩阵 (若为 None 则默认保持垂直向下)
        :param q_init: 求解迭代初始关节角 (若为 None 则采用当前关节状态)
        :param max_steps: 最大迭代步数
        :param pos_tol: 位置收敛容差 (米)
        :param rot_tol: 旋转收敛容差 (弧度)
        :param step_limit: 单步关节角更新最大步长 (弧度)
        :return: 求解后的 7 自由度目标关节角数组 np.ndarray
        """
        if target_mat is None:
            target_mat = self.DEFAULT_DOWNWARD_ROT

        # 保存物理仿真数据状态，避免干涉当前动力学演化
        saved_q = np.copy(data.qpos[:7])

        if q_init is not None:
            res_q = np.copy(q_init)
        else:
            res_q = np.copy(saved_q)

        target_pos = np.asarray(target_pos, dtype=np.float64)

        for _ in range(max_steps):
            data.qpos[:7] = res_q
            mujoco.mj_forward(self.model, data)

            cur_pos = data.xpos[self.ee_id]
            cur_mat = data.xmat[self.ee_id].reshape((3, 3))

            err_pos = target_pos - cur_pos
            err_rot = 0.5 * (
                np.cross(cur_mat[:, 0], target_mat[:, 0]) +
                np.cross(cur_mat[:, 1], target_mat[:, 1]) +
                np.cross(cur_mat[:, 2], target_mat[:, 2])
            )

            # 精度满足要求即终止迭代
            if np.linalg.norm(err_pos) < pos_tol and np.linalg.norm(err_rot) < rot_tol:
                break

            jac_p = np.zeros((3, self.model.nv))
            jac_r = np.zeros((3, self.model.nv))
            mujoco.mj_jacBody(self.model, data, jac_p, jac_r, self.ee_id)

            # 提取前 7 个机械臂关节的雅可比子矩阵
            J = np.vstack([jac_p[:, :7], jac_r[:, :7]])
            err = np.hstack([err_pos, err_rot])

            # 阻尼最小二乘方程: dq = J^T * (J * J^T + lambda^2 * I)^(-1) * err
            damp_matrix = self.lambda_val * np.eye(6)
            dq = J.T @ np.linalg.inv(J @ J.T + damp_matrix) @ err

            # 单步位移截断，保证收敛稳定性
            dq = np.clip(dq, -step_limit, step_limit)
            res_q += dq

            # 关节角度软限位安全裁剪
            for i in range(7):
                limit_range = self.model.actuator_ctrlrange[i]
                res_q[i] = np.clip(res_q[i], limit_range[0], limit_range[1])

        # 彻底恢复物理仿真瞬时状态
        data.qpos[:7] = saved_q
        mujoco.mj_forward(self.model, data)
        return res_q
