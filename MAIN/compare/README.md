# Compare 使用说明

## 1. 这套对比流程是做什么的

`MAIN/compare` 这一套脚本用于把不同版本的轨迹方案放到同一场景下做统一对比，并把结果按统一目录和统一指标格式导出，便于后续写中期报告和整理实验数据。

当前支持的核心思路是：

- 同一批次只比较同一类场景，例如只跑斜坡，或者只跑高台，或者只跑深沟
- 同一批次内所有 case 使用统一总帧数，避免因为轨迹长度不同导致指标不方便横向比较
- 每个 case 可以重复运行多次，默认取最近三次做聚合
- 对比结果统一落到 `log/<scene>/<compare_group_id>/` 下
- 对比流程会自动重启 CoppeliaSim，并准备 MATLAB 所需的 legacy remoteApi 端口

## 2. 当前支持的 case

case 定义集中在 [hexapod_compare_cases.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_compare_cases.m)。

目前可用的 case 如下：

- `slope_current`：当前斜坡方案
- `slope_baseline`：斜坡旧版轨迹，来源于 `walk_slope_backup.mat`
- `step_current`：当前高台方案
- `step_initial`：高台最初版，来源于 `origin/walk3step.m` 拆分生成
- `ditch_initial`：深沟最初版，来源于 `origin/walk3step.m` 拆分生成
- `ditch_half_mid`：深沟中间版，来源于早期 half 脚本
- `ditch_final_replay`：深沟最终版回放轨迹
- `ditch_final_closed_loop`：深沟最终版闭环流程

注意：

- 一次 `hexapod_run_compare_batch(...)` 只能放同一场景下的 case
- 深沟场景可以用三组对比去体现演进关系：`ditch_initial`、`ditch_half_mid`、`ditch_final_replay` 或 `ditch_final_closed_loop`

## 3. 最常用的运行方法

主入口是 [hexapod_run_compare_batch.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_run_compare_batch.m)。

### 3.1 斜坡对比

```matlab
hexapod_run_compare_batch({'slope_current','slope_baseline'});
```

### 3.2 斜坡对比并在同一实验组下重复 3 次

```matlab
hexapod_run_compare_batch( ...
    {'slope_current','slope_baseline'}, ...
    struct('num_repeats', 3));
```

这条命令的含义是：

- 建立一个新的 `compare_时间戳` 实验组
- 在同一个实验组目录下分别运行 `slope_current` 和 `slope_baseline`
- 每个 case 各运行 3 次
- 汇总每个 case 最近 3 次结果

如果你只写 `num_repeats = 1`，那这个实验组下自然只有一次结果。

### 3.3 高台对比

```matlab
hexapod_run_compare_batch( ...
    {'step_current','step_initial'}, ...
    struct('num_repeats', 3));
```

### 3.4 深沟对比

对比最初版和最终版回放：

```matlab
hexapod_run_compare_batch( ...
    {'ditch_initial','ditch_final_replay'}, ...
    struct('num_repeats', 3));
```

对比中间版和最终版回放：

```matlab
hexapod_run_compare_batch( ...
    {'ditch_half_mid','ditch_final_replay'}, ...
    struct('num_repeats', 3));
```

如果要把闭环版也纳入：

```matlab
hexapod_run_compare_batch( ...
    {'ditch_initial','ditch_half_mid','ditch_final_closed_loop'}, ...
    struct('num_repeats', 3));
```

## 4. 运行时会询问什么

[hexapod_prompt_total_frames.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_prompt_total_frames.m) 会在每次批处理开始前询问统一总帧数，例如：

```text
[斜坡] 请输入总帧数，直接回车使用默认 6001 帧:
```

含义是：

- 直接回车：使用参考 case 的自然帧数
- 手动输入整数：所有 case 都会被统一到这个总帧数

当前流程里，统一总帧数是为了保证不同方案之间的横向比较更稳定，尤其适合你后续做表格和画图。

## 5. 输出目录结构

[hexapod_prepare_compare_run_dir.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_prepare_compare_run_dir.m) 负责创建输出目录。目录结构如下：

```text
log/
  slope/
    compare_20260331_150000/
      slope_current/
        run_01_20260331_150010/
        run_02_20260331_150210/
        run_03_20260331_150410/
      slope_baseline/
        run_01_20260331_150620/
        run_02_20260331_150820/
        run_03_20260331_151020/
      compare_run_index.csv
      compare_latest3_index.csv
      compare_aggregate_latest3.csv
      compare_latest3_summary.md
```

每个 `run_xx_时间戳` 目录下通常会包含：

- 当前这一次仿真的 `metrics.mat`
- 统一导出的图和表
- `source_artifacts/`

`source_artifacts/` 里通常保存本次真正送进仿真的关节轨迹，例如：

- 重采样后的 `joint`
- 从旧脚本生成后再统一帧数的 `joint`

这一步很重要，因为它把“实际送入仿真的是哪一份轨迹”固定下来了，便于后面追溯。

## 6. 汇总文件分别表示什么

[hexapod_collect_compare_metrics.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_collect_compare_metrics.m) 会扫描 `metrics.mat` 并写出 4 份核心汇总文件。

### 6.1 `compare_run_index.csv`

每一次运行一行，属于完整运行索引。适合做原始核对。

### 6.2 `compare_latest3_index.csv`

每个 case 只保留最近三次。这个文件更适合直接喂给后续统计脚本或手工做表。

### 6.3 `compare_aggregate_latest3.csv`

按 case 聚合最近三次结果，自动给出：

- `mean`
- `std`
- `min`
- `max`

如果你要在中期报告里写“某场景下重复 3 次实验的平均值和波动”，这份表就是最直接的数据源。

### 6.4 `compare_latest3_summary.md`

简要列出实验组和聚合 case 概览，适合快速查看有没有跑全。

## 7. 现在这套自动重启和连接机制

当前流程不是直接依赖 CoppeliaSim 默认的 `19997` 端口，而是走下面这条链路：

1. 自动关闭旧的 `coppeliaSim` 进程
2. 重新启动 CoppeliaSim 并打开对应场景
3. 等待 ZMQ remote API 服务就绪，默认端口 `23000`
4. 通过 Python 脚本在 CoppeliaSim 内部临时拉起一个 legacy remoteApi 服务，默认端口 `20001`
5. MATLAB 通过 `20001` 建立 legacy remoteApi 连接

对应文件：

- [hexapod_get_coppeliasim_config.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_get_coppeliasim_config.m)
- [hexapod_restart_coppeliasim_for_scene.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_restart_coppeliasim_for_scene.m)
- [hexapod_build_legacy_remote_api_activate_command.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_build_legacy_remote_api_activate_command.m)
- [hexapod_legacy_remote_api_ctl.py](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_legacy_remote_api_ctl.py)

当前默认配置是：

- CoppeliaSim 程序：`C:\Program Files\CoppeliaRobotics\CoppeliaSimEdu\coppeliaSim.exe`
- 斜坡场景：`D:\codehub\hexapod\6leg_slope.ttt`
- 深沟场景：`D:\codehub\hexapod\6leg_ditch.ttt`
- 高台场景：`D:\codehub\hexapod\6leg.ttt`
- ZMQ 端口：`23000`
- 临时 legacy remoteApi 端口：`20001`

## 8. 正常输出大概长什么样

一套正常启动的日志，一般会依次看到下面这些关键信息：

```text
===== 启动对比实验组 =====
场景: slope (斜坡)
实验组: compare_...
Case 数量: 2
重复次数: 3
统一总帧数: 6001

===== [1/2] 运行 case: slope_current | repeat 1/3 =====
[CoppeliaSim] 正在关闭旧进程...
[CoppeliaSim] 旧进程已退出，耗时 ...
[CoppeliaSim] 正在启动程序并打开场景...
[CoppeliaSim] 正在等待进程启动...
[CoppeliaSim] 进程已启动，耗时 ...
[CoppeliaSim] 正在等待 ZMQ 远程接口 127.0.0.1:23000 就绪...
[CoppeliaSim] ZMQ 远程接口已就绪，耗时 ...
[CoppeliaSim] 正在准备临时 legacy remoteApi 服务端口 20001...
[CoppeliaSim] 临时 legacy remoteApi 已准备，耗时 ...
[MatlabVrep] 正在连接 remoteApi 127.0.0.1:20001...
[MatlabVrep] remoteApi 已连接...
[MatlabVrep] 正在获取 18 个关节句柄...
...
===== 对比实验组完成 =====
最新三次索引: ...
聚合结果: ...
摘要文件: ...
```

只要整体趋势是：

- 进程重启成功
- ZMQ 就绪
- 临时 legacy remoteApi 建立成功
- MATLAB 连上 `20001`
- 18 个关节句柄拿到
- 最后写出聚合文件

那就说明这一批次流程是正常的。

## 9. `MAIN/compare` 下各文件的作用

### 9.1 主入口和 case 调度

- [hexapod_run_compare_batch.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_run_compare_batch.m)
  批量对比主入口。检查 case 是否属于同一场景，询问统一总帧数，控制重复次数，重启 CoppeliaSim，逐个运行 case，最后汇总最近三次结果。

- [hexapod_run_compare_case.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_run_compare_case.m)
  单个 case 的执行入口。根据 `source_type` 分发到当前 PG、旧 `.mat` 轨迹、origin 初始版生成器、half 脚本回放或者深沟闭环流程。

- [hexapod_compare_cases.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_compare_cases.m)
  所有 case 的注册表，包括 `case_id`、场景、说明、来源类型、关联脚本和轨迹路径。

### 9.2 CoppeliaSim 启动和连接

- [hexapod_get_coppeliasim_config.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_get_coppeliasim_config.m)
  提供 CoppeliaSim 程序路径、场景路径、主机与端口、ZMQ 设置和 legacy remoteApi 激活方式。

- [hexapod_restart_coppeliasim_for_scene.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_restart_coppeliasim_for_scene.m)
  对比批处理中的自动重启核心。负责停旧进程、启新进程、等待进程、等待 ZMQ、准备临时 legacy remoteApi 服务。

- [hexapod_build_coppeliasim_start_command.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_build_coppeliasim_start_command.m)
  生成用于启动 CoppeliaSim 并打开指定场景的 PowerShell 命令。

- [hexapod_build_coppeliasim_stop_command.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_build_coppeliasim_stop_command.m)
  生成用于关闭旧 CoppeliaSim 进程的 PowerShell 命令。

- [hexapod_build_legacy_remote_api_activate_command.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_build_legacy_remote_api_activate_command.m)
  生成调用 Python 激活脚本的命令行。

- [hexapod_legacy_remote_api_ctl.py](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_legacy_remote_api_ctl.py)
  通过 CoppeliaSim 的 ZMQ API 临时创建 legacy remoteApi 服务端口。

- [hexapod_wait_for_tcp_port.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_wait_for_tcp_port.m)
  通用 TCP 端口等待函数，用于确认端口是否真的已监听。

- [hexapod_wait_for_coppeliasim_scene_ready.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_wait_for_coppeliasim_scene_ready.m)
  场景对象预探针函数。当前默认配置中通常跳过，主要保留作兜底。

### 9.3 轨迹准备和统一帧数

- [hexapod_prompt_total_frames.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_prompt_total_frames.m)
  询问用户本次批处理统一总帧数。

- [hexapod_probe_case_frame_count.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_probe_case_frame_count.m)
  估算某个 case 的自然帧数，用于给出默认总帧数。

- [hexapod_resample_joint_matrix.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_resample_joint_matrix.m)
  把 `N x 18` 关节矩阵重采样为目标帧数。

- [hexapod_load_joint_matrix.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_load_joint_matrix.m)
  从 `.mat` 文件中加载 `joint`，兼容多种变量名。

- [hexapod_generate_origin_initial.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_generate_origin_initial.m)
  从最初版 `origin/walk3step.m` 中拆分生成高台或深沟的初始基线轨迹。

- [hexapod_generate_origin_walk3step.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_generate_origin_walk3step.m)
  兼容包装函数，当前默认转到高台最初版生成器。

- [hexapod_run_ditch_half_baseline.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_run_ditch_half_baseline.m)
  执行早期 deep ditch half 脚本，并回收生成的 `walk_ditch_learned.mat`。

- [hexapod_prepare_compare_run_dir.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_prepare_compare_run_dir.m)
  生成实验组目录、case 目录和每次运行目录。

### 9.4 结果汇总

- [hexapod_collect_compare_metrics.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/compare/hexapod_collect_compare_metrics.m)
  扫描各次运行的 `metrics.mat`，汇总成运行索引、最近三次索引、最近三次聚合表和摘要文件。

## 10. 它和主流程、深沟闭环流程是什么关系

这套 compare 本质上是一个“统一外层包装”：

- 斜坡和高台的回放仿真最终还是走 [CoppeliaSim_process.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/CoppeliaSim_process.m)
- 深沟闭环最终还是走 [CoppeliaSim_learn_ditch.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/MAIN/6leg_motion/ditch/CoppeliaSim_learn_ditch.m)
- MATLAB 与 CoppeliaSim 的通信底层仍然是 [MatlabVrep.m](D:/codehub/hexapod/轨迹仿真程序/hexapod_sim_core/lib/MatlabVrep.m)

所以 compare 并不是另起一套仿真逻辑，而是把现有斜坡、高台、深沟流程统一包装成可重复、可汇总、可横向比较的实验入口。

## 11. 常见问题

### 11.1 为什么一个实验组里只有一次结果

因为你运行时只设置了：

```matlab
struct('num_repeats', 1)
```

如果你想在同一个 `compare_时间戳` 目录下得到 3 次结果，必须在同一次调用里设置：

```matlab
struct('num_repeats', 3)
```

### 11.2 为什么不同 case 的总帧数最后一致

这是 compare 的设计目标之一。旧轨迹、生成轨迹和当前方案轨迹会在进入仿真前统一到同一个总帧数，便于对比。

### 11.3 为什么不再直接用 19997

因为默认 legacy remoteApi 端口在批处理自动重启场景下不稳定，容易出现端口监听正常但对象和句柄还未完全就绪的问题。当前流程改为：

- 先让 CoppeliaSim 自己稳定启动
- 再通过 ZMQ 临时拉起一个新的 legacy remoteApi 端口

这样在批量对比里更稳。

### 11.4 如果重复跑很多次，旧结果会不会被覆盖

不会。每次批处理都会新建一个新的 `compare_时间戳` 目录；每次运行也会生成新的 `run_xx_时间戳` 子目录。

### 11.5 后续整理中期报告时优先看哪些文件

优先顺序建议如下：

1. `compare_aggregate_latest3.csv`
2. `compare_latest3_index.csv`
3. 单次运行目录中的 `metrics.mat`
4. 单次运行目录中的图和 `source_artifacts/`
