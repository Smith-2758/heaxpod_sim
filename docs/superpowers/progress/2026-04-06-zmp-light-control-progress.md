# ZMP Light Control Progress

## 当前状态
- 当前阶段：接手后完成 spec / plan / 现状核对，已完成 Task 1 code review 收尾、Task 2、Task 3 与 Task 4；准备进入 Task 5-7。
- 当前工作区：`D:\codehub\hexapod\hexapod_sim_core\.worktrees\zmp-light-control`
- 当前分支：`codex/zmp-light-control`
- 当前主线目标：按既定技术路线继续实现“统一近似 ZMP 评估层 + 深沟在线辅助闭环 + 斜坡/高台离线迭代优化”，不改大方向。
- 当前已知基线失败：
  - `tests/test_midterm_slope_plot.m`：缺少 `log/slope/compare_user_slope_repeat3_20260331` 相关输入。
  - `tests/test_midterm_step_plot.m`：现有图文生成结果与测试期望措辞不一致（如“高度增益”“相对起点前进距离”等）。
- 当前判断：上述两项属于接手时已存在的非 ZMP 基线问题，后续验证中不应误判为本次 ZMP 开发引入的新问题。

## 已完成
- 2026-04-06：阅读设计文档 `docs/superpowers/specs/2026-04-06-zmp-light-control-design.md`。
- 2026-04-06：阅读实现计划 `docs/superpowers/plans/2026-04-06-zmp-light-control-implementation.md`。
- 2026-04-06：核对 worktree 当前状态：
  - `lib/zmp/hexapod_zmp_defaults.m` 已存在。
  - `tests/test_zmp_defaults_and_stance.m` 已存在。
  - `lib/zmp/` 目前仅有 bootstrap/defaults 文件，Task 2-4 尚未落地。
  - `lib/setup/hexapod_setup_paths.m` 已注册 `lib/zmp`。
- 2026-04-06：在 worktree 下创建 progress 文档，记录接手时真实状态与后续推进基线。
- 2026-04-06：完成 Task 1 code review 收尾修复：
  - `tests/test_zmp_defaults_and_stance.m` 现在会显式把当前 worktree 的 `lib/setup` 放到 path 前列，并校验 `which('hexapod_setup_paths')` 指向当前工作区。
  - 同一测试补充了默认值不变量约束：
    - `F_enter > F_exit > 0`
    - `SM_safe > SM_critical > 0`
    - `yaw_assist_limit_deg > 0`
    - `x_guard_limit_m > 0`
    - `yaw_filter_alpha` / `x_guard_filter_alpha` 位于 `[0, 1]`
    - `freeze_force_threshold_n > 0`
    - `freeze_hold_steps > 0` 且满足近似整数语义
- 2026-04-06：完成 Task 2：
  - 新增 `lib/zmp/hexapod_detect_stance_legs.m`。
  - 在 `tests/test_zmp_defaults_and_stance.m` 中加入迟滞支撑腿识别测试，覆盖 enter / hold / exit 三段行为。
  - 当前函数接口：`[stance_mask, stance_count, contact_flags] = hexapod_detect_stance_legs(force_input, prev_mask, cfg)`。
- 2026-04-06：完成 Task 3：
  - 新增 `tests/test_zmp_quasistatic_core.m`，覆盖：
    - force-weighted ZMP 计算
    - zero-force centroid fallback
    - empty stance invalid 分支
  - 新增 `lib/zmp/hexapod_compute_quasistatic_zmp.m`。
  - 当前函数接口：`out = hexapod_compute_quasistatic_zmp(foot_pos, force_vec, stance_mask, cfg)`。
- 2026-04-06：完成 Task 4：
  - 在 `tests/test_zmp_quasistatic_core.m` 中补充支撑多边形几何测试，覆盖 inside / outside / two-point-invalid 三种情况。
  - 新增 `lib/zmp/hexapod_compute_stability_margin.m`。
  - 当前函数接口：`out = hexapod_compute_stability_margin(support_xy, zmp_xy)`。
  - 在验证过程中发现 `lateral_offset` 测试期望值写错；实现定义为 `zmp_y - mean(support_y)`，因此将测试修正为与设计一致的表达，而不是改动函数逻辑。

## 当前验证结果
- 接手说明中给出的历史状态：
  - 已通过：
    - `tests/test_compare_refactor_structure.m`
    - `tests/test_compute_metrics_placeholders.m`
    - `tests/test_zmp_defaults_and_stance.m`
  - 已知失败（基线问题）：
    - `tests/test_midterm_slope_plot.m`
    - `tests/test_midterm_step_plot.m`
- 本轮已执行验证：
  - `tests/test_zmp_defaults_and_stance.m`
    - 结果：`2 Passed, 0 Failed, 0 Incomplete`
    - 结论：Task 1 review 修复通过 targeted test 验证，未引入新失败。
  - `testsuite('tests/test_zmp_defaults_and_stance.m')` + `run(suite)`
    - 结果：`3 Passed, 0 Failed, 0 Incomplete`
    - 结论：Task 2 的新测试已被 MATLAB 正确发现，`hexapod_detect_stance_legs.m` 的最小迟滞实现通过 targeted test。
    - 备注：之前使用 `matlab_run_matlab_test_file` 的摘要输出只显示了 2 个通过项，容易产生“新测试未发现”的假象；后续以 `testsuite(...)` / `run(suite)` 的明细结果为准。
  - MATLAB Code Analyzer：`tests/test_zmp_defaults_and_stance.m`
    - 结果：无静态问题。
  - MATLAB Code Analyzer：`lib/zmp/hexapod_detect_stance_legs.m`
    - 结果：无静态问题。
  - `tests/test_zmp_quasistatic_core.m`
    - red 阶段：`3 Failed`，原因均为 `hexapod_compute_quasistatic_zmp` 未定义，符合 TDD 预期。
    - green 阶段：实现最小函数后 `3 Passed, 0 Failed, 0 Incomplete`。
  - MATLAB Code Analyzer：`tests/test_zmp_quasistatic_core.m`
    - 结果：无静态问题。
  - MATLAB Code Analyzer：`lib/zmp/hexapod_compute_quasistatic_zmp.m`
    - 结果：无静态问题。
  - `tests/test_zmp_quasistatic_core.m`（Task 4 扩展后）
    - red 阶段：总计 `6` 个测试，其中 Task 3 的 `3 Passed` 保持不变，Task 4 新增的 `3 Failed` 均因 `hexapod_compute_stability_margin` 未定义，符合 TDD 预期。
    - 初次 green 验证：`5 Passed, 1 Failed`，失败原因为测试中 `lateral_offset` 期望值错误，不是实现错误。
    - 修正测试期望后：`6 Passed, 0 Failed, 0 Incomplete`。
  - MATLAB Code Analyzer：`lib/zmp/hexapod_compute_stability_margin.m`
    - 结果：无静态问题。

## 当前技术判断
- 当前技术路线与设计文档一致，没有偏离：
  - ZMP 仍定位为轻控制型统一评估层。
  - 深沟作为唯一第一阶段在线辅助接入场景。
  - 斜坡/高台仍以离线诊断和参数迭代为主。
- 当前默认参数实现明显偏离设计文档建议区间：
  - 现实现值：`F_enter=45`, `F_exit=30`, `SM_safe=0.15`, `SM_critical=0.05`, `K_yaw_zmp=0.40`, `K_x_guard=0.20`, `yaw_assist_limit_deg=12`, `x_guard_limit_m=0.03`。
  - 设计建议区间显著更保守。
- 当前处理策略：进入 Task 5-7，把场景规则、metrics 聚合与 `06_zmp_stability` 导出串起来；默认值是否回调到设计建议区间，放到接入真实 telemetry 与规则后再决策。
- 当前进展更新：Task 1 review 收尾、Task 2、Task 3 与 Task 4 已完成，`lib/zmp` 的基础评估三件套已落地：支撑腿识别 / 准静态 ZMP 点 / 稳定裕度几何。

## 风险与待办
- 当前最大风险：
  - 默认参数目前偏激，若不尽快校验合理性，后续 Task 5-10 接入时可能造成规则过重。
  - 尽管基础评估层已就位，但尚未接入 `hexapod_compute_metrics.m` / `hexapod_export_metrics.m`，因此还没有真实日志到图表的闭环证据。
- 下一步最该做的事：
  1. 开始 Task 5：实现 `lib/zmp/hexapod_apply_scene_zmp_rules.m`，先覆盖 ditch 与非 ditch 行为测试。
  2. 开始 Task 6：把 ZMP 序列与聚合指标接入 `lib/metrics/hexapod_compute_metrics.m`。
  3. 开始 Task 7：把 `06_zmp_stability` 图接入 `lib/metrics/hexapod_export_metrics.m`。
- 当前不要碰：
  - 深沟主状态机重写。
  - 全场景重型在线控制。
  - 与 ZMP 主线无关的基线 plot 文案问题。
