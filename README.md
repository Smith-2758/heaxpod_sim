# Hexapod Simulation Core

六足机器人轨迹仿真核心工程（MATLAB + CoppeliaSim）。

本仓库用于生成六足机器人关节轨迹，并通过 CoppeliaSim 远程 API 执行仿真，输出受力、轨迹与速度等结果。

如果你的目标是快速判断“该怎么回放某条轨迹、该用 compare 还是老入口、直接执行什么命令”，优先阅读：

- [轨迹回放操作手册（AI 友好版）](/D:/codehub/hexapod/hexapod_sim_core/docs/trajectory-replay-guide.zh-CN.md)

## 1. Project Scope

当前代码包含两类流程：

1. 主流程（`main_v2.m -> PG.m -> CoppeliaSim_process.m`）
- 适用于平地、台阶/墙面、斜坡、深沟开环回放等模式。

2. 深沟半闭环专项流程（`MAIN/6leg_motion/ditch`）
- 适用于深沟跨越的在线探测与避险策略验证。

## 2. Core Pipeline

```text
main_v2.m
  -> PG.m (select/generate/load Joint)
  -> CoppeliaSim_process.m
  -> MatlabVrep.m + remApi/remoteApi.dll
  -> CoppeliaSim scene execution
  -> log/<YYMMDD>/<HH.MM>/ outputs
```

核心数据结构：
- `Joint{k}`: `N x 18` 关节角矩阵（弧度）
- `N`: 时间帧数（默认 5ms 控制周期）
- `18`: 6 条腿 x 每腿 3 个关节

## 3. Repository Layout

```text
hexapod_sim_core/
├─ MAIN/
│  ├─ main_v2.m                    # 主入口
│  ├─ PG.m                         # 轨迹调度器
│  ├─ CoppeliaSim_process.m        # 仿真执行 + 记录输出
│  ├─ bothsides_differ_spline.m    # 轨迹平滑
│  ├─ 6leg_motion/                 # 地形/步态轨迹脚本
│  │  ├─ walk.m
│  │  ├─ walk3step_high.m
│  │  ├─ walk_slope.m
│  │  ├─ ditch/
│  │  │  ├─ walk_ditch.m
│  │  │  ├─ CoppeliaSim_learn_ditch.m
│  │  │  └─ main_ditch.m
│  │  └─ export_data/*.mat
│  └─ black_description/           # 机器人模型与运动学/动力学参数
├─ lib/
│  ├─ MatlabVrep.m
│  ├─ remApi.m
│  ├─ remoteApi.dll
│  └─ TSpline_S_V_A.m
├─ log/                            # 仿真输出目录（自动生成）
└─ README.md
```

## 4. Runtime Requirements

- MATLAB（建议使用较新版本，需支持当前脚本语法与 `makima`）
- CoppeliaSim（已配置含六足机器人模型的场景）
- CoppeliaSim Remote API 文件（仓库已包含）
  - `lib/remApi.m`
  - `lib/remoteApi.dll`
  - `lib/remoteApiProto.m`

注意：
- MATLAB 与 `remoteApi.dll` 的位数需匹配（均为 64-bit）。
- 运行前确保 CoppeliaSim 场景已打开，且远程接口可连接。

## 5. Quick Start (Main Pipeline)

### Step 1: 打开仿真场景

在 CoppeliaSim 中加载对应六足场景（项目默认说明中使用 `6leg_xiugai_4.ttt`）。

### Step 2: 进入入口目录并选择模式

在 MATLAB 中执行：

```matlab
cd('D:\codehub\hexapod\轨迹仿真程序\hexapod_sim_core\MAIN');
edit main_v2.m
```

在 `main_v2.m` 中只保留一个 `pattern = {'...'};`。

### Step 3: 运行入口

```matlab
main_v2
```

程序会自动：
- 生成或读取轨迹
- 连接 CoppeliaSim 执行动作
- 保存图像、FIG、运行摘要到 `log/` 目录

## 6. Supported Patterns in `PG.m`

| Pattern | 用途 | 轨迹来源 |
|---|---|---|
| `walk` | 平地步态 | `walk.m` 实时生成 |
| `climb2wall` | 台阶/爬高回放 | `walk3step_high.mat` |
| `climbing` | 墙面/台阶连续动作 | `dais3step.mat` |
| `Legstretch` | 伸腿测试 | `hello1.m` |
| `slope` | 15° 斜坡 | `walk_slope.mat` |
| `ditch` | 深沟开环回放 | `walk_ditch.mat` |

说明：
- 除 `walk` 和 `Legstretch` 外，其他模式主要依赖离线 `.mat` 轨迹文件。
- 若轨迹文件不存在，请先运行对应轨迹脚本生成。

## 7. Terrain-Specific Workflows

### 7.1 Slope (15°)

1. 先生成轨迹：

```matlab
cd('D:\codehub\hexapod\轨迹仿真程序\hexapod_sim_core\MAIN\6leg_motion');
walk_slope
```

2. 回到入口执行：

```matlab
cd('D:\codehub\hexapod\轨迹仿真程序\hexapod_sim_core\MAIN');
% 在 main_v2.m 里设置 pattern = {'slope'}
main_v2
```

### 7.2 Step / Climb

1. 先生成轨迹：

```matlab
cd('D:\codehub\hexapod\轨迹仿真程序\hexapod_sim_core\MAIN\6leg_motion');
walk3step_high
```

2. 回放：

```matlab
cd('D:\codehub\hexapod\轨迹仿真程序\hexapod_sim_core\MAIN');
% 在 main_v2.m 里设置 pattern = {'climb2wall'}
main_v2
```

### 7.3 Ditch (Open Loop in Main Pipeline)

```matlab
cd('D:\codehub\hexapod\轨迹仿真程序\hexapod_sim_core\MAIN');
% 在 main_v2.m 里设置 pattern = {'ditch'}
main_v2
```

该模式读取 `walk_ditch.mat` 执行开环回放。

### 7.4 Ditch (Semi-Closed-Loop Experimental Pipeline)

该流程不经过 `main_v2 -> PG -> CoppeliaSim_process`，用于深沟专项控制实验。

1. 生成基准轨迹库：

```matlab
cd('D:\codehub\hexapod\轨迹仿真程序\hexapod_sim_core\MAIN\6leg_motion\ditch');
walk_ditch
```

2. 运行半闭环学习控制：

```matlab
CoppeliaSim_learn_ditch
```

3. （可选）回放学习结果：

```matlab
main_ditch
```

## 8. Output and Logs

主流程运行后自动创建：

```text
log/<YYMMDD>/<HH.MM>/
├─ 01_leg_force.png / .fig
├─ 02_total_force.png / .fig
├─ 03_trajectory_tracking.png / .fig
├─ 04_body_speed.png / .fig
└─ simulation_summary.md
```

`simulation_summary.md` 包含：
- 起止时间、模式序列、总帧数
- 理论仿真时长与程序实际运行时长
- 速度/位移统计
- 输出文件清单

## 9. Common Issues

1. `git push` 已解决但 MATLAB 运行失败
- 通常是场景未打开或 Remote API 连接失败。
- 先在 CoppeliaSim 中加载场景，再运行 `main_v2`。

2. 轨迹文件缺失（`walk_slope.mat`, `walk3step_high.mat`, `walk_ditch.mat`）
- 先运行对应 `MAIN/6leg_motion/` 脚本生成。

3. `remoteApi.dll` 无法调用
- 检查 MATLAB 与 DLL 位数一致性。
- 确认 `lib/` 在 MATLAB 搜索路径内（`main_v2` 已自动 `addpath(genpath(...))`）。

4. 深沟新流程与主流程行为不一致
- 这是预期现状：深沟半闭环是专项实验链路，尚未并入主流程调度。

## 10. Development Notes

- 入口脚本：`MAIN/main_v2.m`
- 调度逻辑：`MAIN/PG.m`
- 仿真执行与日志：`MAIN/CoppeliaSim_process.m`
- 深沟实验：`MAIN/6leg_motion/ditch/`

建议后续统一点：
- 将深沟半闭环流程与主流程日志格式统一。
- 将 `pattern` 说明与实际 `PG.m` 可用分支保持同步。

## 11. License

仓库当前未显式提供 License 文件。如需开源发布，建议补充 `LICENSE`。
