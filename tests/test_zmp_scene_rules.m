function tests = test_zmp_scene_rules
tests = functiontests(localfunctions);
end

function test_ditch_rules_freeze_when_margin_is_critical(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

cfg = hexapod_zmp_defaults();
state = struct( ...
    'scene_name', 'ditch', ...
    'stability_margin', min(cfg.SM_critical / 2, cfg.SM_critical - eps), ...
    'front_margin', cfg.SM_safe, ...
    'lateral_offset', 0.0, ...
    'polygon_valid', true);

rules = hexapod_apply_scene_zmp_rules(state, cfg);

verifyTrue(testCase, rules.freeze_progression);
verifyEqual(testCase, rules.delta_yaw_zmp_deg, 0, 'AbsTol', 1e-12);
end

function test_non_ditch_scene_returns_log_only_behavior(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

cfg = hexapod_zmp_defaults();
state = struct( ...
    'scene_name', 'slope', ...
    'stability_margin', 0.001, ...
    'front_margin', 0.0, ...
    'lateral_offset', 0.2, ...
    'polygon_valid', false);

rules = hexapod_apply_scene_zmp_rules(state, cfg);

verifyFalse(testCase, rules.freeze_progression);
verifyEqual(testCase, rules.delta_yaw_zmp_deg, 0, 'AbsTol', 1e-12);
verifyEqual(testCase, rules.delta_x_guard_m, 0, 'AbsTol', 1e-12);
end

function test_ditch_rules_limit_yaw_and_x_guard_output(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

cfg = hexapod_zmp_defaults();
state = struct( ...
    'scene_name', 'ditch', ...
    'stability_margin', cfg.SM_critical + max(0.01, 0.25 * cfg.SM_safe), ...
    'front_margin', 0.002, ...
    'lateral_offset', 0.2, ...
    'polygon_valid', true);

rules = hexapod_apply_scene_zmp_rules(state, cfg);

verifyFalse(testCase, rules.freeze_progression, ...
    'polygon 有效且稳定裕度未跌破临界值时不应冻结推进。');
verifyLessThanOrEqual(testCase, abs(rules.delta_yaw_zmp_deg), cfg.yaw_assist_limit_deg);
verifyLessThanOrEqual(testCase, abs(rules.delta_x_guard_m), cfg.x_guard_limit_m);
verifyGreaterThan(testCase, rules.delta_x_guard_m, 0, ...
    '当前 front_margin 小于 SM_safe 时应生成正向保护量。');
end

function test_ditch_rules_freeze_when_polygon_is_invalid(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

cfg = hexapod_zmp_defaults();
state = struct( ...
    'scene_name', 'ditch', ...
    'stability_margin', NaN, ...
    'front_margin', NaN, ...
    'lateral_offset', 0.0, ...
    'polygon_valid', false);

rules = hexapod_apply_scene_zmp_rules(state, cfg);

verifyTrue(testCase, rules.freeze_progression);
verifyEqual(testCase, rules.delta_yaw_zmp_deg, 0, 'AbsTol', 1e-12);
verifyEqual(testCase, rules.delta_x_guard_m, 0, 'AbsTol', 1e-12);
end

function initialize_project_paths(project_root)
setup_dir = fullfile(project_root, 'lib', 'setup');
if exist(setup_dir, 'dir') == 7
    addpath(setup_dir, '-begin');
end
hexapod_setup_paths();
end
