# Compare 使用说明

## 1. 这套对比流程现在是什么结构

`MAIN/compare` 已整理为 5 个主文件，加 1 个旧入口兼容壳：

- `hexapod_compare_batch.m`
  compare 主入口。负责 case 选择、统一总帧数、批次目录、重复次数控制，以及批次结束后的汇总触发。
- `hexapod_compare_registry.m`
  case 注册表和 CoppeliaSim 配置入口。负责维护 slope / step / ditch 的 case 定义，以及场景到 `.ttt`、ZMQ、legacy remoteApi 配置的映射。
- `hexapod_compare_runtime.m`
  CoppeliaSim 自动重启与远程接口准备。保留当前的 ZMQ `23000` + 临时 legacy remoteApi `20001` 链路。
- `hexapod_compare_trajectory.m`
  单 case 执行与轨迹准备。负责当前 PG、旧 `.mat` 轨迹、origin 初始版生成、ditch half 生成后回放和 ditch 闭环流程的分发。
- `hexapod_compare_report.m`
  compare 输出目录和汇总逻辑。负责 `compare_run_index.csv`、`compare_latest3_index.csv`、`compare_aggregate_latest3.csv`、`compare_latest3_summary.md`。
- `hexapod_run_compare_batch.m`
  兼容壳。保留旧调用方式，内部直接转发到 `hexapod_compare_batch(...)`。

当前 compare 主链路文件如下：

```text
MAIN/compare/
  hexapod_compare_batch.m
  hexapod_compare_registry.m
  hexapod_compare_runtime.m
  hexapod_compare_trajectory.m
  hexapod_compare_report.m
  hexapod_run_compare_batch.m
  hexapod_legacy_remote_api_ctl.py
  README.md
```

另外，工程里当前还保留一组历史报告整理脚本：

```text
MAIN/compare/metircs_analyze/
  hexapod_plot_midterm_ditch.m
  hexapod_plot_midterm_slope.m
  hexapod_plot_midterm_step.m
```

这组脚本不参与 compare 主执行链路，也不会影响批处理、CoppeliaSim 自动重启、轨迹回放或指标汇总。它们只是已有结果的后处理/出图脚本，因此这里单独说明，避免把“主链路收敛”误解成“目录里不存在任何其他脚本”。

## 2. lib 现在的分层

`lib` 已分为 4 层：

```text
lib/
  setup/
    hexapod_setup_paths.m
  remote_api/
    MatlabVrep.m
    remApi.m
    remoteApiProto.m
    remoteApi.dll
    hexapod_retry_remote_connect.m
    hexapod_retry_remote_handle_lookup.m
  metrics/
    hexapod_compute_metrics.m
    hexapod_export_metrics.m
    hexapod_prepare_output_dir.m
  common/
    hexapod_scene_info.m
    hexapod_resample_series.m
    TSpline_S_V_A.m
```

其中：

- `setup/` 只做统一路径初始化。
- `remote_api/` 只放 legacy remoteApi 依赖和连接重试工具。
- `metrics/` 只放指标计算、图表导出和输出目录工具。
- `common/` 放场景信息、通用重采样和样条工具。

## 3. 路径初始化策略

compare 不再依赖散乱的 `addpath(genpath(...))`。

现在的策略是：

1. compare 入口先做一次最小 bootstrap，只把 `lib/setup` 加入路径。
2. 然后统一调用 `hexapod_setup_paths()`。
3. 后续 compare、metrics、remoteApi、black robot description、ditch 闭环相关目录都由这个入口统一挂载。

对于 compare 用户来说，正常使用时不需要再手工 `addpath(genpath(...))`。

## 4. 当前支持的 case

case 注册在 `hexapod_compare_registry('cases')` 中，当前可用：

- `slope_current`
- `slope_baseline`
- `step_current`
- `step_initial`
- `ditch_initial`
- `ditch_half_mid`
- `ditch_final_replay`
- `ditch_final_closed_loop`

注意：

- 一次批处理只允许放同一场景下的 case。
- slope / step / ditch 三类场景都保留可运行。
- ditch_half_mid 不再绑定静态 .mat。每个 repeat 会先运行 MAIN/6leg_motion/ditch/CoppeliaSim_learn_ditch_half.m 生成当次中间轨迹，再重启 CoppeliaSim 并回放该次生成结果后计入 compare 指标。

## 5. 最常用的运行方法

### 5.1 新入口

```matlab
hexapod_compare_batch({'slope_current', 'slope_baseline'});
```

### 5.2 旧入口兼容调用

```matlab
hexapod_run_compare_batch({'slope_current', 'slope_baseline'});
```

### 5.3 指定重复次数

```matlab
hexapod_compare_batch( ...
    {'step_current', 'step_initial'}, ...
    struct('num_repeats', 3));
```

### 5.4 指定统一总帧数

```matlab
hexapod_compare_batch( ...
    {'ditch_initial', 'ditch_final_replay'}, ...
    struct('num_repeats', 3, 'target_total_frames', 6001));
```

如果没有显式给 `target_total_frames`，批处理启动时会询问一次统一总帧数。

## 6. compare 运行时仍保留的自动重启链路

当前不会回退到旧的默认 `19997` 链路。compare 仍保留下面这条自动重启机制：

1. 关闭旧的 `coppeliaSim` 进程。
2. 启动 CoppeliaSim 并打开对应场景。
3. 等待 ZMQ remote API 服务就绪，端口 `23000`。
4. 通过 `hexapod_legacy_remote_api_ctl.py` 在 CoppeliaSim 内部临时拉起 legacy remoteApi 服务，端口 `20001`。
5. MATLAB 通过 `20001` 建立 legacy remoteApi 连接。

默认配置仍然是：

- ZMQ 端口：`23000`
- 临时 legacy remoteApi 端口：`20001`
- slope 场景：`D:\codehub\hexapod\6leg_slope.ttt`
- step 场景：`D:\codehub\hexapod\6leg.ttt`
- ditch 场景：`D:\codehub\hexapod\6leg_ditch.ttt`

## 7. 输出目录结构

compare 输出目录结构保持不变：

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

每个 `run_xx_时间戳` 目录下仍会保存：

- `metrics.mat`
- 图和指标摘要
- `source_artifacts/`

因此现有汇总逻辑、目录层级和后续报告整理脚本的输入接口都没有变。

## 8. 汇总文件说明

compare 结束后仍输出 4 份核心文件：

- `compare_run_index.csv`
  每次运行一行，适合完整核对。
- `compare_latest3_index.csv`
  每个 case 只保留最近三次，适合直接统计。
- `compare_aggregate_latest3.csv`
  每个 case 聚合最近三次，给出 `mean / std / min / max`。
- `compare_latest3_summary.md`
  快速查看这次实验组有没有跑全。

## 9. 5 个主文件分别并入了哪些旧职责

- `hexapod_compare_batch.m`
  并入了旧的批处理入口、case 选择、统一总帧数提示。
- `hexapod_compare_registry.m`
  并入了旧的 case 注册表和 CoppeliaSim 配置构造。
- `hexapod_compare_runtime.m`
  并入了旧的重启、PowerShell 命令生成、端口等待、场景就绪探测。
- `hexapod_compare_trajectory.m`
  并入了旧的单 case 执行、轨迹加载、轨迹重采样、origin 初始版生成、ditch half 生成后回放。
- `hexapod_compare_report.m`
  并入了旧的 compare 目录创建和 metrics 汇总。

## 10. 最小验证建议

这次重构完成后，最小验证建议按下面 4 组命令执行：

```matlab
hexapod_compare_batch({'slope_current', 'slope_baseline'}, struct('num_repeats', 1));
hexapod_compare_batch({'step_current', 'step_initial'}, struct('num_repeats', 1));
hexapod_compare_batch({'ditch_initial', 'ditch_final_replay'}, struct('num_repeats', 1));
hexapod_run_compare_batch({'slope_current', 'slope_baseline'}, struct('num_repeats', 1));
```

如果你的目标是一次性做你要求的最小回归，可以把 `num_repeats` 先设成 `1`；确认链路通了之后，再按正式实验需要改回 `3`。

## 11. compare 和主流程、ditch 闭环流程的关系

这套 compare 仍然只是统一外层包装，并没有新开一套仿真核心：

- slope / step 回放最终还是走 `MAIN/CoppeliaSim_process.m`
- `ditch_final_closed_loop` 最终还是走 `MAIN/6leg_motion/ditch/CoppeliaSim_learn_ditch.m`
- MATLAB 与 CoppeliaSim 的通信底层仍然是 `lib/remote_api/MatlabVrep.m`

所以这次重构的重点是结构收敛和路径治理，不是改 compare 的实验语义。

## 12. 当前工程实际与 compare README 的对应关系

如果你只关心“正式对比实验怎么跑”，那 README 里关于以下几部分与工程实际是一致的：

- compare 正式入口是 `hexapod_compare_batch.m`
- 旧入口 `hexapod_run_compare_batch.m` 只是兼容转发
- case 注册来自 `hexapod_compare_registry('cases')`
- 单次执行与轨迹准备来自 `hexapod_compare_trajectory.m`
- 自动重启链路仍是 ZMQ `23000` + 临时 legacy remoteApi `20001`
- 汇总输出仍是 `compare_run_index.csv`、`compare_latest3_index.csv`、`compare_aggregate_latest3.csv`、`compare_latest3_summary.md`

唯一需要按工程实际修正理解的是目录层面：

- README 里原先写成了 `MAIN/compare` “最终只保留” 8 个文件
- 实际工程还保留了 `metircs_analyze/` 作为历史结果分析脚本目录

也就是说，compare 的主逻辑与 README 描述基本一致；不一致的地方主要是目录说明，现在已按工程现状补齐。
