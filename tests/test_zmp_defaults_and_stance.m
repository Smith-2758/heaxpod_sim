function tests = test_zmp_defaults_and_stance
tests = functiontests(localfunctions);
end

function test_setup_paths_include_zmp_dir(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
[setup_info, resolved_setup_path] = initialize_project_paths(project_root);

zmp_path = string(fullfile(project_root, 'lib', 'zmp'));
expected_setup_path = string(fullfile(project_root, 'lib', 'setup', 'hexapod_setup_paths.m'));

verifyEqual(testCase, string(resolved_setup_path), expected_setup_path, ...
    'hexapod_setup_paths 应解析到当前 worktree 的 lib/setup。');
verifyTrue(testCase, any(setup_info.required_paths == zmp_path), ...
    sprintf('hexapod_setup_paths required_paths 应包含 zmp 目录: %s', zmp_path));
end

function test_zmp_defaults_exposes_required_fields(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
[~, resolved_setup_path] = initialize_project_paths(project_root);
expected_setup_path = string(fullfile(project_root, 'lib', 'setup', 'hexapod_setup_paths.m'));

defaults = hexapod_zmp_defaults();
required_fields = {
    'F_enter'
    'F_exit'
    'SM_safe'
    'SM_critical'
    'K_yaw_zmp'
    'K_x_guard'
    'yaw_assist_limit_deg'
    'x_guard_limit_m'
    'yaw_filter_alpha'
    'x_guard_filter_alpha'
    'freeze_force_threshold_n'
    'freeze_hold_steps'
    };

verifyTrue(testCase, isstruct(defaults) && isscalar(defaults), ...
    'hexapod_zmp_defaults 应返回标量 struct。');
verifyEqual(testCase, string(resolved_setup_path), expected_setup_path, ...
    '默认值测试应绑定当前 worktree 的 hexapod_setup_paths。');

for idx = 1:numel(required_fields)
    verifyTrue(testCase, isfield(defaults, required_fields{idx}), ...
        sprintf('hexapod_zmp_defaults 缺少字段: %s', required_fields{idx}));
end

verifyGreaterThan(testCase, defaults.F_enter, defaults.F_exit, ...
    '应满足 F_enter > F_exit。');
verifyGreaterThan(testCase, defaults.F_exit, 0, ...
    '应满足 F_exit > 0。');
verifyGreaterThan(testCase, defaults.SM_safe, defaults.SM_critical, ...
    '应满足 SM_safe > SM_critical。');
verifyGreaterThan(testCase, defaults.SM_critical, 0, ...
    '应满足 SM_critical > 0。');
verifyGreaterThan(testCase, defaults.yaw_assist_limit_deg, 0, ...
    'yaw_assist_limit_deg 应为正值。');
verifyGreaterThan(testCase, defaults.x_guard_limit_m, 0, ...
    'x_guard_limit_m 应为正值。');

verifyGreaterThanOrEqual(testCase, defaults.yaw_filter_alpha, 0, ...
    'yaw_filter_alpha 应位于 [0, 1]。');
verifyLessThanOrEqual(testCase, defaults.yaw_filter_alpha, 1, ...
    'yaw_filter_alpha 应位于 [0, 1]。');
verifyGreaterThanOrEqual(testCase, defaults.x_guard_filter_alpha, 0, ...
    'x_guard_filter_alpha 应位于 [0, 1]。');
verifyLessThanOrEqual(testCase, defaults.x_guard_filter_alpha, 1, ...
    'x_guard_filter_alpha 应位于 [0, 1]。');

verifyGreaterThan(testCase, defaults.freeze_force_threshold_n, 0, ...
    'freeze_force_threshold_n 应为正值。');
verifyGreaterThan(testCase, defaults.freeze_hold_steps, 0, ...
    'freeze_hold_steps 应为正值。');
verifyEqual(testCase, defaults.freeze_hold_steps, round(defaults.freeze_hold_steps), ...
    'AbsTol', 1e-12, 'freeze_hold_steps 应满足接近整数的语义。');
end

function test_detect_stance_legs_uses_hysteresis(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

cfg = hexapod_zmp_defaults();
prev_mask = false(1, 6);
forces_enter = [cfg.F_enter + 1, cfg.F_enter - 1, cfg.F_exit - 1, 0, 0, 0];

[stance_mask_enter, stance_count_enter, contact_flags_enter] = ...
    hexapod_detect_stance_legs(forces_enter, prev_mask, cfg);

verifyEqual(testCase, stance_mask_enter, logical([1 0 0 0 0 0]));
verifyEqual(testCase, stance_count_enter, 1);
verifyEqual(testCase, contact_flags_enter, stance_mask_enter);

forces_hold = [0.5 * (cfg.F_enter + cfg.F_exit), cfg.F_enter - 1, cfg.F_exit - 1, 0, 0, 0];
[stance_mask_hold, stance_count_hold] = hexapod_detect_stance_legs(forces_hold, stance_mask_enter, cfg);

verifyEqual(testCase, stance_mask_hold, logical([1 0 0 0 0 0]), ...
    '处于 F_exit 与 F_enter 之间时应保持上一帧支撑状态。');
verifyEqual(testCase, stance_count_hold, 1);

forces_exit = [cfg.F_exit - 1, cfg.F_enter + 2, cfg.F_exit - 1, 0, 0, 0];
[stance_mask_exit, stance_count_exit] = hexapod_detect_stance_legs(forces_exit, stance_mask_hold, cfg);

verifyEqual(testCase, stance_mask_exit, logical([0 1 0 0 0 0]));
verifyEqual(testCase, stance_count_exit, 1);
end

function [setup_info, resolved_setup_path] = initialize_project_paths(project_root)
setup_dir = fullfile(project_root, 'lib', 'setup');
if exist(setup_dir, 'dir') == 7
    addpath(setup_dir, '-begin');
end
resolved_setup_path = which('hexapod_setup_paths');
setup_info = hexapod_setup_paths();
end
