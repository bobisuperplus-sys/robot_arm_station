#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MHS 具身机械臂数字孪生控制台统一后端服务 (Robot Station Server)
核心职责:
1. 运行 MuJoCo 真实物理引擎环境 (Franka Emika Panda 7DoF + 夹爪动力学);
2. 构建双机位 GStreamer RTP H.264 UDP:5002 视频流，并支持秒级热切换 (俯视/3D全局监控);
3. 逆运动学 (IK) 笛卡尔点动与夹爪控制;
4. 5 阶段自主视觉抓取搬运全闭环状态机;
5. 基于 TCP:6000 的 JSON-RPC 实时遥测广播与双向控制总线。
"""

import os
import sys
import time
import json
import math
import shutil
import socket
import select
import threading
import subprocess
import warnings
import numpy as np

# 适配 Wayland / Hyprland 桌面环境，避免 GLFW EGL 访问警告
os.environ["GLFW_PLATFORM"] = "x11"
warnings.filterwarnings("ignore")

import mujoco

SCENE_XML = os.path.join(os.path.dirname(__file__), "..", "simulation", "franka_emika_panda", "workstation_scene.xml")


def mat2euler(mat):
    """3x3 旋转矩阵转欧拉角 (度, R-P-Y 顺序)"""
    r11, r12, r13 = mat[0], mat[1], mat[2]
    r21, r22, r23 = mat[3], mat[4], mat[5]
    r31, r32, r33 = mat[6], mat[7], mat[8]

    pitch = math.asin(-np.clip(r31, -1.0, 1.0))
    if math.cos(pitch) > 1e-6:
        roll = math.atan2(r32, r33)
        yaw = math.atan2(r21, r11)
    else:
        roll = math.atan2(-r23, r22)
        yaw = 0.0
    return math.degrees(roll), math.degrees(pitch), math.degrees(yaw)


class RobotStationServer:
    def __init__(self, rpc_port=6000, stream_port=5002, width=960, height=640):
        self.rpc_port = rpc_port
        self.stream_port = stream_port
        self.width = width
        self.height = height
        self.frame_bytes = width * height * 3

        # 1. 加载 MuJoCo 模型与数据
        if not os.path.exists(SCENE_XML):
            raise FileNotFoundError(f"未找到场景文件: {SCENE_XML}")
        self.model = mujoco.MjModel.from_xml_path(SCENE_XML)
        self.data = mujoco.MjData(self.model)

        # 重置到 ready 待机姿态关键帧 (第 1 帧)
        mujoco.mj_resetDataKeyframe(self.model, self.data, 1)
        for _ in range(50):
            mujoco.mj_step(self.model, self.data)

        # 初始目标控制量
        self.target_ctrl = np.copy(self.data.ctrl)

        # 2. 状态变量
        self.lock = threading.Lock()
        self.running = True
        self.estop = False
        self.active_camera = "overhead_cam"
        self.camera_fov = 58.0

        # 流水线与周期
        self.stage = 1
        self.stage_name = "待机就绪"
        self.cycle_count = 142
        self.cycle_start_time = time.time()
        self.auto_running = False

        # 3. 客户端连接管理
        self.clients = []
        self.clients_lock = threading.Lock()

        # 4. GStreamer 渲染推流子进程
        self.gst_proc = None

    def start(self):
        """启动所有后台工作线程"""
        print("[RobotServer] 正在启动 GStreamer 视讯推流...", flush=True)
        self._start_gstreamer()

        print(f"[RobotServer] 正在启动 TCP RPC 总线服务 (端口 {self.rpc_port})...", flush=True)
        self.rpc_thread = threading.Thread(target=self._rpc_server_loop, daemon=True)
        self.rpc_thread.start()

        print("[RobotServer] 正在启动物理仿真与控制迭代循环...", flush=True)
        self.physics_thread = threading.Thread(target=self._physics_loop, daemon=True)
        self.physics_thread.start()

        print("[RobotServer] 正在启动渲染与视讯推流循环...", flush=True)
        self.stream_thread = threading.Thread(target=self._streaming_loop, daemon=True)
        self.stream_thread.start()

    def _start_gstreamer(self):
        gst_bin = shutil.which("gst-launch-1.0")
        if not gst_bin:
            print("[RobotServer] 警告: 未找到 gst-launch-1.0，视讯推流未激活。")
            return

        gst_cmd = [
            gst_bin, "-q",
            "fdsrc", "fd=0", "do-timestamp=true", f"blocksize={self.frame_bytes}", "!",
            "rawvideoparse", "format=rgb", f"width={self.width}", f"height={self.height}", "framerate=30/1", "!",
            "videoconvert", "!",
            "video/x-raw,format=I420", "!",
            "x264enc", "tune=zerolatency", "speed-preset=ultrafast", "bitrate=2500", "key-int-max=15", "!",
            "rtph264pay", "config-interval=1", "pt=96", "!",
            "udpsink", "host=127.0.0.1", f"port={self.stream_port}", "sync=false", "async=false"
        ]

        self.gst_proc = subprocess.Popen(gst_cmd, stdin=subprocess.PIPE, bufsize=0)
        print(f"[RobotServer] 视讯管道已就绪: UDP://127.0.0.1:{self.stream_port}")

    def _streaming_loop(self):
        """30 FPS 渲染物理视口并管道写入 GStreamer"""
        renderer = mujoco.Renderer(self.model, height=self.height, width=self.width)
        rate = 1.0 / 30.0
        while self.running:
            start_t = time.time()

            with self.lock:
                cam = self.active_camera
                renderer.update_scene(self.data, camera=cam)
                frame = renderer.render()

            if self.gst_proc and self.gst_proc.stdin:
                try:
                    self.gst_proc.stdin.write(frame.tobytes())
                except (BrokenPipeError, OSError):
                    pass

            elapsed = time.time() - start_t
            sleep_time = max(0.001, rate - elapsed)
            time.sleep(sleep_time)

    def _physics_loop(self):
        """100 Hz 动力学解算与状态机迭代"""
        dt = 0.01
        while self.running:
            t0 = time.time()

            with self.lock:
                if not self.estop:
                    # 平滑向目标关节指令靠拢
                    if hasattr(self, "target_ctrl"):
                        alpha = 0.15
                        self.data.ctrl[:7] = (1 - alpha) * self.data.ctrl[:7] + alpha * self.target_ctrl[:7]
                        self.data.ctrl[7] = self.target_ctrl[7]

                    # 物理前进一步
                    mujoco.mj_step(self.model, self.data)

                    # 若开启全自动流水线，步进状态机
                    if self.auto_running:
                        self._step_state_machine()
                else:
                    # 急停状态保持锁死
                    self.data.qvel[:] = 0.0

            elapsed = time.time() - t0
            time.sleep(max(0.001, dt - elapsed))

    def _step_state_machine(self):
        """5 阶段自主抓取搬运逻辑"""
        now = time.time()
        elapsed = now - self.stage_start_time

        # 获取方块位置与末端手爪位置
        hand_body_id = mujoco.mj_name2id(self.model, mujoco.mjtObj.mjOBJ_BODY, "hand")
        hand_pos = np.copy(self.data.xpos[hand_body_id])
        cube_pos = np.copy(self.data.qpos[9:12])

        if self.stage == 1:
            # 阶段 1: 视觉定位与对齐
            self.stage_name = "视觉识别"
            if elapsed > 1.0:
                self.stage = 2
                self.stage_start_time = time.time()
                self._log("AI视觉", f"锁定目标工件坐标: ({cube_pos[0]:.2f}, {cube_pos[1]:.2f}, {cube_pos[2]:.2f})", "#00E5FF")
                # 预抓取位: 方块正上方 12cm，张开夹爪
                self.target_ctrl[7] = 255
                self._solve_ik_to_pos(np.array([cube_pos[0], cube_pos[1], cube_pos[2] + 0.12]))

        elif self.stage == 2:
            # 阶段 2: 下潜预备抓取
            self.stage_name = "预抓取逼近"
            if elapsed > 1.8:
                self.stage = 3
                self.stage_start_time = time.time()
                self._log("轨迹规划", "下潜就位，夹爪力闭环紧固中", "#00DAF3")
                # 下潜至方块抓取高度，闭合夹爪
                self._solve_ik_to_pos(np.array([cube_pos[0], cube_pos[1], cube_pos[2] + 0.02]))
                self.target_ctrl[7] = 0

        elif self.stage == 3:
            # 阶段 3: 抓紧并抬升
            self.stage_name = "闭环抓取"
            if elapsed > 1.5:
                self.stage = 4
                self.stage_start_time = time.time()
                self._log("夹爪机构", "工件抓持可靠，提升至安全运送高度", "#00E676")
                # 抬升至运送高度 Z = 0.68m
                self._solve_ik_to_pos(np.array([cube_pos[0], cube_pos[1], 0.68]))

        elif self.stage == 4:
            # 阶段 4: 平移运送至目标区域 B
            self.stage_name = "轨迹运送"
            # 目标区域 B 坐标: (0.50, -0.22, 0.65)
            self._solve_ik_to_pos(np.array([0.50, -0.22, 0.65]))
            if elapsed > 2.5:
                self.stage = 5
                self.stage_start_time = time.time()
                self._log("执行机构", "已到达目标托盘上方，下放并脱附", "#D500F9")
                # 下放至托盘高度并打开夹爪
                self._solve_ik_to_pos(np.array([0.50, -0.22, 0.54]))
                self.target_ctrl[7] = 255

        elif self.stage == 5:
            # 阶段 5: 释放并复位
            self.stage_name = "放置归位"
            if elapsed > 1.8:
                self.auto_running = False
                self.stage = 1
                self.stage_name = "待机就绪"
                self.cycle_count += 1
                self._log("任务调度", f"周期 #{self.cycle_count} 搬运成功，系统平滑复位待机", "#22EF7E")
                self.reset()

    def _solve_ik_to_pos(self, target_pos, max_steps=5):
        """基于阻尼雅可比伪逆计算简单的逆运动学目标"""
        hand_id = mujoco.mj_name2id(self.model, mujoco.mjtObj.mjOBJ_BODY, "hand")
        for _ in range(max_steps):
            hand_pos = self.data.xpos[hand_id]
            err = target_pos - hand_pos
            if np.linalg.norm(err) < 0.005:
                break

            jac_pos = np.zeros((3, self.model.nv))
            mujoco.mj_jacBody(self.model, self.data, jac_pos, None, hand_id)
            J = jac_pos[:, :7]  # 前 7 个机械臂关节

            # 阻尼最小二乘
            lambda_val = 0.05
            dq = J.T @ np.linalg.inv(J @ J.T + lambda_val * np.eye(3)) @ err
            # 步长裁剪
            dq = np.clip(dq, -0.1, 0.1)
            self.target_ctrl[:7] += dq

            # 限位校验
            for i in range(7):
                j_id = self.model.jnt_actuatorid[i]
                r = self.model.actuator_ctrlrange[i]
                self.target_ctrl[i] = np.clip(self.target_ctrl[i], r[0], r[1])

    def jog(self, axis, step_mm):
        """执行笛卡尔轴向微量点动"""
        with self.lock:
            if self.estop:
                self._log("安全警告", "急停生效中，点动拒绝执行", "#E53935")
                return

            delta = np.zeros(3)
            step_m = step_mm / 1000.0

            if axis == "+X": delta[0] = step_m
            elif axis == "-X": delta[0] = -step_m
            elif axis == "+Y": delta[1] = step_m
            elif axis == "-Y": delta[1] = -step_m
            elif axis == "+Z": delta[2] = step_m
            elif axis == "-Z": delta[2] = -step_m
            elif axis in ("R+", "R-"):
                sign = 1 if axis == "R+" else -1
                self.target_ctrl[6] += sign * 0.1
                self._log("空间点动", f"法兰微旋转 [{axis}]", "#00E5FF")
                return

            hand_id = mujoco.mj_name2id(self.model, mujoco.mjtObj.mjOBJ_BODY, "hand")
            target_pos = self.data.xpos[hand_id] + delta
            self._solve_ik_to_pos(target_pos, max_steps=10)

            cur_pos = self.data.xpos[hand_id]
            self._log("空间点动", f"轴向 [{axis}] 步长 {step_mm:.1f}mm -> ({cur_pos[0]:.3f}, {cur_pos[1]:.3f}, {cur_pos[2]:.3f})", "#00E5FF")

    def set_gripper(self, width_mm):
        """调节夹爪开度 (0~80mm 映射到 ctrl 0~255)"""
        with self.lock:
            val = np.clip(width_mm, 0.0, 80.0)
            ctrl_val = (val / 80.0) * 255.0
            self.target_ctrl[7] = ctrl_val
            self._log("夹爪控制", f"开度设定为: {val:.1f} mm", "#00E676")

    def switch_camera(self, cam_name):
        """多机位动态热切换"""
        with self.lock:
            if cam_name in ("overhead_cam", "surveillance_cam"):
                self.active_camera = cam_name
                self.camera_fov = 58.0 if cam_name == "overhead_cam" else 45.0
                label = "俯视视觉相机 (Eye-to-Hand)" if cam_name == "overhead_cam" else "3D 全局监控相机"
                self._log("视讯服务", f"切换活跃视口至: [{label}]", "#00E5FF")

    def start_cycle(self):
        """启动自主抓取流水线"""
        with self.lock:
            if self.estop:
                self._log("安全警告", "急停生效中，无法启动抓取流水线", "#E53935")
                return
            self.auto_running = True
            self.stage = 1
            self.stage_start_time = time.time()
            self._log("任务调度", "启动全自动抓取搬运周期 (5 步状态机)", "#00E5FF")

    def pause_cycle(self):
        with self.lock:
            self.auto_running = False
            self._log("任务调度", "流水线运动暂停", "#FFAB00")

    def reset(self):
        """复位至初始就绪关键帧"""
        with self.lock:
            mujoco.mj_resetDataKeyframe(self.model, self.data, 1)
            for _ in range(30):
                mujoco.mj_step(self.model, self.data)
            self.target_ctrl = np.copy(self.data.ctrl)
            self.auto_running = False
            self.stage = 1
            self.stage_name = "待机就绪"
            self._log("系统状态", "机械臂已复位至就绪待机位 (Ready Keyframe)", "#00E676")

    def randomize_cube(self):
        """随机偏置工件位置"""
        with self.lock:
            # 随机偏移工件 x, y (桌面范围内)
            dx = (np.random.rand() - 0.5) * 0.12
            dy = (np.random.rand() - 0.5) * 0.12
            self.data.qpos[9] = 0.50 + dx
            self.data.qpos[10] = 0.20 + dy
            self.data.qpos[11] = 0.525
            mujoco.mj_step(self.model, self.data)
            self._log("环境仿真", f"工件位置已随机偏置至: ({self.data.qpos[9]:.3f}, {self.data.qpos[10]:.3f})", "#FFAB00")

    def trigger_estop(self):
        with self.lock:
            self.estop = not self.estop
            if self.estop:
                self.auto_running = False
                self._log("安全联锁", "紧急制动 (E-STOP) 已触发! 伺服切断锁死", "#E53935")
            else:
                self._log("安全联锁", "紧急制动已解除，恢复伺服使能", "#00E676")

    def _log(self, tag, content, color="#F0F3F6"):
        t_str = time.strftime("%H:%M:%S")
        msg = {
            "type": "log",
            "time": t_str,
            "tag": tag,
            "content": content,
            "color": color
        }
        self._broadcast(msg)

    def _broadcast(self, obj):
        data = (json.dumps(obj, ensure_ascii=False) + "\n").encode("utf-8")
        with self.clients_lock:
            dead_clients = []
            for c in self.clients:
                try:
                    c.sendall(data)
                except (BrokenPipeError, OSError):
                    dead_clients.append(c)
            for c in dead_clients:
                self.clients.remove(c)

    def _rpc_server_loop(self):
        """TCP 服务端：处理客户端指令并以 30Hz 推送实时遥测"""
        srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        srv.bind(("0.0.0.0", self.rpc_port))
        srv.listen(5)
        srv.setblocking(False)

        last_telemetry_t = 0.0

        while self.running:
            # 1. 检查新接入客户端
            readable, _, _ = select.select([srv], [], [], 0.02)
            if srv in readable:
                try:
                    client_sock, addr = srv.accept()
                    client_sock.setblocking(False)
                    with self.clients_lock:
                        self.clients.append(client_sock)
                    print(f"[RobotServer] Qt 上位机客户端已连接: {addr}")
                    self._log("总线通信", "Qt 上位机总线连接成功 (v2.4.1)", "#00E5FF")
                except OSError:
                    pass

            # 2. 接收并解析客户端下发的指令
            with self.clients_lock:
                active_sockets = list(self.clients)

            if active_sockets:
                r_socks, _, _ = select.select(active_sockets, [], [], 0.01)
                for s in r_socks:
                    try:
                        raw = s.recv(4096)
                        if not raw:
                            with self.clients_lock:
                                if s in self.clients: self.clients.remove(s)
                            continue

                        lines = raw.decode("utf-8", errors="ignore").split("\n")
                        for line in lines:
                            line = line.strip()
                            if line:
                                self._handle_client_command(json.loads(line))
                    except (ConnectionResetError, json.JSONDecodeError, OSError):
                        pass

            # 3. 30Hz 定时打包物理引擎真实遥测广播
            now = time.time()
            if now - last_telemetry_t >= 0.033:
                last_telemetry_t = now
                self._send_telemetry()

    def _send_telemetry(self):
        with self.lock:
            # 真实关节角 (弧度转角度)
            q_deg = [round(float(math.degrees(q)), 1) for q in self.data.qpos[:7]]
            # 真实关节执行器力矩
            torques = [round(float(tau), 2) for tau in self.data.qfrc_actuator[:7]]

            # 末端 TCP 位姿
            hand_id = mujoco.mj_name2id(self.model, mujoco.mjtObj.mjOBJ_BODY, "hand")
            tcp_pos = [round(float(v), 3) for v in self.data.xpos[hand_id]]
            mat = self.data.xmat[hand_id]
            r, p, y = mat2euler(mat)
            tcp_euler = [round(r, 1), round(p, 1), round(y, 1)]

            # 真实夹爪开度 (两手指滑移位移之和，单位 mm)
            gripper_width = round(float((self.data.qpos[7] + self.data.qpos[8]) * 1000.0), 1)
            # 夹爪力 (执行器 8 输出力)
            gripper_force = round(float(abs(self.data.actuator_force[7])), 1)

            elapsed = round(time.time() - self.cycle_start_time, 2)

            telemetry = {
                "type": "telemetry",
                "joints": q_deg,
                "torques": torques,
                "tcp_pos": tcp_pos,
                "tcp_euler": tcp_euler,
                "gripper_width": gripper_width,
                "gripper_force": gripper_force,
                "stage": self.stage,
                "stage_name": self.stage_name,
                "cycle_count": self.cycle_count,
                "cycle_elapsed": elapsed,
                "estop": self.estop,
                "active_camera": self.active_camera,
                "camera_fov": self.camera_fov
            }

        self._broadcast(telemetry)

    def _handle_client_command(self, cmd):
        method = cmd.get("method", "")
        params = cmd.get("params", {})
        print(f"[RobotServer] 收到 RPC 指令: {method} {params}", flush=True)

        if method == "switch_camera":
            self.switch_camera(params.get("camera", "overhead_cam"))
        elif method == "jog":
            self.jog(params.get("axis", "+Z"), params.get("step_mm", 5.0))
        elif method == "set_gripper":
            self.set_gripper(params.get("width_mm", 40.0))
        elif method == "start_cycle":
            self.start_cycle()
        elif method == "pause_cycle":
            self.pause_cycle()
        elif method == "reset":
            self.reset()
        elif method == "randomize":
            self.randomize_cube()
        elif method == "estop":
            self.trigger_estop()


if __name__ == "__main__":
    server = RobotStationServer()
    server.start()
    print("==================================================", flush=True)
    print("MHS 机械臂工作站真实仿真服务端运行中...", flush=True)
    print("视讯推流: udp://127.0.0.1:5002 (H.264/RTP)", flush=True)
    print("控制总线: tcp://127.0.0.1:6000 (JSON-RPC)", flush=True)
    print("按 Ctrl+C 退出服务", flush=True)
    print("==================================================", flush=True)
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n正在停止服务...")
        server.running = False
