# 具身智能机械臂视觉自主抓取与数字孪生工作站 (Robot Arm Manipulation Station)

本项目为一个独立的工业级具身智能与机器人操作平台，实现机械臂基于 3D 视觉感知将目标工件从初始位姿（A 点）抓取搬运至目标位姿（B 点）的完整自主控制闭环。

---

## 1. 系统架构与工程目录

本项目按照模块化设计理念，划分为仿真底座、运动学算法、视觉感知、服务总线与上位机五大核心层级：

```text
robot_arm_station/
├── simulation/            # 物理仿真底座 (基于 MuJoCo 物理引擎与真实机器人模型)
│   ├── franka_emika_panda/    # Franka Emika Panda 7自由度机械臂与原装二指夹爪资产
│   └── universal_robots_ur5e/ # Universal Robots UR5e 六轴工业协同机械臂资产
│
├── kinematics/            # 机械臂运动学与动力学算法模块
│   ├── ik_solver.py       # 逆运动学 (Inverse Kinematics) 求解器
│   └── trajectory.py      # 五次多项式笛卡尔空间轨迹规划与插值
│
├── perception/            # 视觉感知与手眼标定模块
│   ├── camera_streamer.py # 虚拟相机 RGB-D 视频流采集与 GStreamer RTP 传输
│   └── block_detector.py  # 工件 3D 位姿估计与抓取候选点解算
│
├── service/               # 机器人驱动总线与任务状态机调度服务
│   └── robot_server.py    # MHS 驱动抽象与抓取搬运状态机控制器
│
├── qt_client/             # Qt 6 客户端工程目录
│   └── robot_console/     # 基于 Qt 6 QML / C++ 开发的数字孪生操作工作站
│
├── RULES.md               # 项目研发与文档规范
└── README.md              # 项目总体技术说明
```

---

## 2. 关键运行环境与技术指标 (实测核验)

经过底层工具实际查询与运行测试，确认以下环境参数：

- **操作系统**: Linux (x86_64)
- **Python 运行时**: Python 3.12.3
- **物理仿真引擎**: MuJoCo 3.9.0
- **主要机器人模型**: Franka Emika Panda
  - 广义坐标自由度 (nq): 9 (7 个旋转臂关节 + 2 个指尖平行移动关节)
  - 执行器驱动通道 (nu): 8
  - 刚体连杆数量 (nbody): 12
- **上位机框架**: Qt 6 (Qt Quick / QML) 结合 CMake 构建系统
- **视讯流媒体传输**: GStreamer H.264 / 实时传输协议 (RTP over UDP)
- **控制总线协议**: 基于 JSON 的远程过程调用协议 (JSON-RPC 2.0 over TCP)

---

## 3. 核心功能与工作流设计

整个自主搬运流程包含以下 5 个关键阶段：

1. **位姿感知 (Perception)**:
   - 俯视工作台虚拟摄像头捕获图像并提取工件的 3D 空间坐标与偏转角。
2. **预抓取过渡 (Pre-Grasp Approach)**:
   - 逆运动学解算末端姿态，将夹爪移动至工件正上方安全过渡点。
3. **下压抓取 (Grasp)**:
   - 垂直下潜，夹爪闭合，依靠 MuJoCo 动力学引擎计算指尖与方块的真实刚体摩擦接触。
4. **提升与路径平移 (Lift & Transit)**:
   - 提升至安全运送高度，规划平滑轨迹运送至指定 B 点上方。
5. **精准放置与复位 (Place & Home)**:
   - 下降至落点高度，张开夹爪释放工件，机械臂末端安全抬升并归位至待机姿态。
