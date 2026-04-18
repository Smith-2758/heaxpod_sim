# Hexapod Simulation Core

六足机器人轨迹仿真核心工程（MATLAB + CoppeliaSim）。

本仓库当前主要承担四类工作：

1. 生成斜坡、高台、深沟等场景的关节轨迹或参考轨迹。
2. 通过 CoppeliaSim remote API 执行仿真，并导出统一指标与图表。
3. 通过 `MAIN/compare` 对当前方案、初始方案和中间方案做批量对比。
4. 在 `MAIN/6leg_motion/ditch` 下继续迭代深沟半闭环与复杂场景控制。

如果本地保留了 `docs/trajectory-replay-guide.zh-CN.md`，可以把它当作更偏操作手册的补充文档；本 README 更偏向工程结构与当前状态说明。

## 1. 当前工程状态

目前代码不是单一执行链路，而是并行维护了几条不同用途的流程：

1. 主流程：`main_v2.m -> PG.m -> CoppeliaSim_process.m`
适用于平地、斜坡、高台、连续斜坡、连续长平台、深沟开环回放等离线轨迹执行。

2. compare 流程：`MAIN/compare/hexapod_compare_batch.m`
适用于正式对比实验、repeat、多 case 汇总、自动重启 CoppeliaSim、统一总帧数和统一指标归档。

3. 深沟基础半闭环流程：`MAIN/6leg_motion/ditch/walk_ditch.m -> CoppeliaSim_learn_ditch.m`
适用于单深沟场景下的在线探测、避险和学习后轨迹导出。

4. 深沟复杂场景流程：`MAIN/6leg_motion/ditch/walk_ditch.m -> CoppeliaSim_learn_ditch_sidepits.m`
适用于侧坑和多坑场景，是当前深沟复杂场景的独立实现版本。

其中，斜坡和高台已经稳定走主流程；深沟则同时保留开环回放、基础半闭环和复杂场景三层结构。

## 2. 目录结构

```text
hexapod_sim_core/
├─ MAIN/
│  ├─ main_v2.m
│  ├─ PG.m
│  ├─ CoppeliaSim_process.m
│  ├─ compare/
│  │  ├─ hexapod_compare_batch.m
│  │  ├─ hexapod_compare_registry.m
│  │  ├─ hexapod_compare_runtime.m
│  │  ├─ hexapod_compare_trajectory.m
│  │  ├─ hexapod_compare_report.m
│  │  └─ README.md
│  └─ 6leg_motion/
│     ├─ walk.m
│     ├─ walk_slope.m
│     ├─ walk_slope_3m_4m_3m.m
│     ├─ walk3step_high.m
│     ├─ walk_step_platform5m.m
│     └─ ditch/
│        ├─ walk_ditch.m
│        ├─ CoppeliaSim_learn_ditch_half.m
│        ├─ CoppeliaSim_learn_ditch.m
│        ├─ CoppeliaSim_learn_ditch_sidepits.m
│        └─ main_ditch.m
├─ lib/
│  ├─ setup/
│  ├─ remote_api/
│  ├─ metrics/
│  ├─ common/
│  └─ zmp/
├─ log/
├─ docs/
└─ README.md
```

`lib` 当前已经按职责拆分：

- `setup/`：统一路径初始化。
- `remote_api/`：legacy remote API 连接与重试工具。
- `metrics/`：统一指标计算、图表导出、输出目录管理。
- `common/`：通用重采样、场景信息、轨迹截尾等工具。
- `zmp/`：ZMP 与稳定性相关工具。

## 3. 运行依赖

- MATLAB
- CoppeliaSim
- 本仓库内的 remote API 依赖
  - `lib/remote_api/remApi.m`
  - `lib/remote_api/remoteApi.dll`
  - `lib/remote_api/remoteApiProto.m`

注意事项：

- MATLAB 与 `remoteApi.dll` 需要同为 64 位。
- 主流程和深沟独立流程默认都依赖本地已打开的 CoppeliaSim 场景。
- compare 流程会自行处理 CoppeliaSim 重启与远程接口准备。

## 4. 推荐入口

### 4.1 compare 入口

如果你的目标是：

- 跑正式对比实验
- 跑一个或多个 compare case
- 自动重启 CoppeliaSim
- 做 repeat
- 统一输出到 `log/<scene>/compare_xxx/`

优先使用：

```matlab
project_root = 'D:/codehub/hexapod/hexapod_sim_core';
addpath(fullfile(project_root, 'lib', 'setup'));
hexapod_setup_paths();

hexapod_compare_batch({'slope_current'}, struct( ...
    'num_repeats', 1, ...
    'target_total_frames', 6001, ...
    'compare_group_id', 'compare_slope_current_once'));
```

当前 compare 注册表中的主要 case 包括：

- `slope_current`
- `slope_baseline`
- `step_current`
- `step_initial`
- `ditch_initial`
- `ditch_half_mid`
- `ditch_final_replay`
- `ditch_final_closed_loop_off`
- `ditch_final_closed_loop_on`

详细说明见 [MAIN/compare/README.md](./MAIN/compare/README.md)。

### 4.2 主流程入口

如果你的目标是：

- 跑 `PG.m` 里已有的历史 `pattern`
- 临时验证某条离线轨迹
- 不需要 compare 的批处理与汇总

可以使用主流程。

推荐不要手改 `main_v2.m`，而是直接在 MATLAB 命令行调用：

```matlab
project_root = 'D:/codehub/hexapod/hexapod_sim_core';
addpath(fullfile(project_root, 'lib', 'setup'));
hexapod_setup_paths();
cd(fullfile(project_root, 'MAIN'));

pattern = {'slope'};
[Joint, Pitch] = PG(pattern); %#ok<NASGU>
CoppeliaSim_process(pattern, Joint);
```

`PG.m` 当前可直接使用的主要 `pattern` 有：

- `walk`
- `climb2wall`
- `step_platform5m`
- `climbing`
- `Legstretch`
- `slope`
- `slope_3m_4m_3m`
- `ditch`

其中 `ditch` 仍然是深沟开环回放，读取的是 `MAIN/6leg_motion/export_data/walk_ditch.mat`。

### 4.3 深沟基础半闭环入口

用于单深沟场景：

```matlab
project_root = 'D:/codehub/hexapod/hexapod_sim_core';
addpath(fullfile(project_root, 'lib', 'setup'));
hexapod_setup_paths();
cd(fullfile(project_root, 'MAIN', '6leg_motion', 'ditch'));

walk_ditch
CoppeliaSim_learn_ditch
```

这里：

- `walk_ditch.m` 生成的是 `export_data/xyz_base.mat`
- `CoppeliaSim_learn_ditch.m` 会输出学习后的 `walk_ditch_learned.mat`
- 如需纯回放学习后的关节轨迹，可再运行 `main_ditch`

### 4.4 深沟复杂场景入口

用于侧坑和多坑场景：

```matlab
project_root = 'D:/codehub/hexapod/hexapod_sim_core';
addpath(fullfile(project_root, 'lib', 'setup'));
hexapod_setup_paths();
cd(fullfile(project_root, 'MAIN', '6leg_motion', 'ditch'));

walk_ditch
CoppeliaSim_learn_ditch_sidepits
```

这条链路当前已经具备：

- 真实足端坐标判坑
- 多坑几何边界 `pit_defs`
- 单腿脱困与同侧避碰
- 任务完成判停
- 学习后轨迹与统一指标导出

## 5. 常见场景的推荐用法

### 5.1 斜坡当前方案

- 日常单次运行：`compare` 入口中的 `slope_current`
- 直接跑主流程：`pattern = {'slope'}`

### 5.2 高台当前方案

- 日常单次运行：`compare` 入口中的 `step_current`
- 直接跑主流程：`pattern = {'climb2wall'}`

### 5.3 连续斜坡与连续长平台

这两类目前走主流程：

- `pattern = {'slope_3m_4m_3m'}`
- `pattern = {'step_platform5m'}`

### 5.4 深沟当前方案

需要区分三种语义：

- 深沟开环回放：主流程 `pattern = {'ditch'}`
- 深沟基础半闭环：`CoppeliaSim_learn_ditch`
- 深沟复杂场景：`CoppeliaSim_learn_ditch_sidepits`

如果用户说的是“当前方案对比实验”，通常更接近 compare 里的 `ditch_final_replay`、`ditch_final_closed_loop_off` 或 `ditch_final_closed_loop_on`，而不是老的开环 `pattern = {'ditch'}`。

## 6. 输出结果

当前主流程和深沟独立流程都已经统一接入指标导出，典型输出包括：

```text
log/<scene>/<timestamp or compare_group>/
├─ 01_leg_force.png
├─ 02_total_force.png
├─ 03_trajectory_tracking.png
├─ 04_body_speed.png
├─ 05_body_attitude.png
├─ metrics.mat
└─ metrics_summary.md
```

compare 还会额外生成：

- `compare_run_index.csv`
- `compare_latest3_index.csv`
- `compare_aggregate_latest3.csv`
- `compare_latest3_summary.md`

深沟独立流程还会在对应输出目录保存：

- `walk_ditch_learned.mat`
- 必要时的 `source_artifacts/`

## 7. 与外部历史资产的关系

当前仓库中的“当前方案”路径基本自洽，但部分 compare case 仍依赖外部历史资产：

- `slope_baseline`
- `step_initial`
- `ditch_initial`

这些 case 会引用 `D:\codehub\hexapod\轨迹仿真程序` 下的旧脚本或旧轨迹，用于和当前方案做基线对比。因此：

- 只跑当前方案时，本仓库基本够用；
- 跑完整 compare 基线对比时，需要保证外部历史目录仍然存在。

## 8. 当前最需要注意的事实

1. `main_v2.m` 默认仍写成 `pattern = {'ditch'}`，但它代表的是深沟开环回放，不是复杂场景半闭环版本。
2. `walk_ditch.m` 生成的是 `xyz_base.mat`，不是 `walk_ditch.mat`。
3. `CoppeliaSim_learn_ditch_sidepits.m` 是当前复杂深沟场景的独立实现入口，但它还没有并入 `main_v2 -> PG -> CoppeliaSim_process` 的统一调度。
4. README 中的运行建议优先服务于当前私有仓库的日常使用，不以公开发布为前提。

## 9. 相关文档

- 项目现状说明：[implementation_plan.md](./implementation_plan.md)
- 研究日志：[graduation_project_log.md](./graduation_project_log.md)
- compare 流程说明：[MAIN/compare/README.md](./MAIN/compare/README.md)
