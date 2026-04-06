function tests = test_zmp_quasistatic_core
tests = functiontests(localfunctions);
end

function test_quasistatic_zmp_uses_force_weighted_support_points(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

cfg = hexapod_zmp_defaults();
foot_pos = [
    0.0  0.0  0.0
    1.0  0.0  0.0
    0.0  1.0  0.0
    2.0  2.0  0.0
    2.0 -2.0  0.0
   -2.0  0.0  0.0];
force_vec = zeros(6, 3);
force_vec(1, :) = [0 0 10];
force_vec(2, :) = [0 0 20];
force_vec(3, :) = [0 0 30];
stance_mask = logical([1 1 1 0 0 0]);

out = hexapod_compute_quasistatic_zmp(foot_pos, force_vec, stance_mask, cfg);

verifyTrue(testCase, out.valid, '存在有效支撑腿时应返回有效结果。');
verifyEqual(testCase, out.stance_mask, stance_mask);
verifyEqual(testCase, out.stance_count, 3);
verifyEqual(testCase, out.support_xy, foot_pos(1:3, 1:2), 'AbsTol', 1e-12);
verifyEqual(testCase, out.mode, "force_weighted");
verifyEqual(testCase, out.zmp_xy, [1/3, 1/2], 'AbsTol', 1e-12);
end

function test_quasistatic_zmp_uses_centroid_fallback_on_zero_force(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

cfg = hexapod_zmp_defaults();
foot_pos = [
    0.0 0.0 0.0
    1.0 0.0 0.0
    0.0 1.0 0.0
    5.0 5.0 0.0
    6.0 6.0 0.0
    7.0 7.0 0.0];
force_vec = zeros(6, 3);
stance_mask = logical([1 1 1 0 0 0]);

out = hexapod_compute_quasistatic_zmp(foot_pos, force_vec, stance_mask, cfg);

verifyEqual(testCase, out.mode, "fallback_centroid");
verifyEqual(testCase, out.zmp_xy, mean(foot_pos(1:3, 1:2), 1), 'AbsTol', 1e-12);
end

function test_quasistatic_zmp_returns_invalid_for_empty_stance_set(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

cfg = hexapod_zmp_defaults();
foot_pos = zeros(6, 3);
force_vec = zeros(6, 3);
stance_mask = false(1, 6);

out = hexapod_compute_quasistatic_zmp(foot_pos, force_vec, stance_mask, cfg);

verifyFalse(testCase, out.valid);
verifyEqual(testCase, out.stance_count, 0);
verifyEqual(testCase, out.mode, "invalid");
verifyTrue(testCase, all(isnan(out.zmp_xy)));
end

function test_stability_margin_is_positive_inside_polygon(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

support_xy = [0 0; 1 0; 0 1];
zmp_xy = [0.2 0.2];

out = hexapod_compute_stability_margin(support_xy, zmp_xy);

verifyTrue(testCase, out.polygon_valid);
verifyTrue(testCase, out.zmp_inside_polygon_flag);
verifyGreaterThan(testCase, out.stability_margin, 0);
verifyEqual(testCase, out.support_polygon_xy, support_xy, 'AbsTol', 1e-12);
verifyEqual(testCase, out.front_margin, 0.8, 'AbsTol', 1e-12);
verifyEqual(testCase, out.lateral_offset, 0.2 - mean(support_xy(:, 2)), 'AbsTol', 1e-12);
end

function test_stability_margin_is_negative_outside_polygon(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

support_xy = [0 0; 1 0; 0 1];
zmp_xy = [1.2 0.2];

out = hexapod_compute_stability_margin(support_xy, zmp_xy);

verifyTrue(testCase, out.polygon_valid);
verifyFalse(testCase, out.zmp_inside_polygon_flag);
verifyLessThan(testCase, out.stability_margin, 0);
end

function test_stability_margin_is_invalid_for_two_points(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

support_xy = [0 0; 1 0];
zmp_xy = [0.5 0.0];

out = hexapod_compute_stability_margin(support_xy, zmp_xy);

verifyFalse(testCase, out.polygon_valid);
verifyFalse(testCase, out.zmp_inside_polygon_flag);
verifyTrue(testCase, isnan(out.stability_margin));
verifyTrue(testCase, isnan(out.front_margin));
verifyTrue(testCase, isnan(out.lateral_offset));
end

function test_stability_margin_is_invalid_for_collinear_support_points(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

support_xy = [0 0; 1 0; 2 0];
zmp_xy = [1 0];

out = hexapod_compute_stability_margin(support_xy, zmp_xy);

verifyFalse(testCase, out.polygon_valid);
verifyFalse(testCase, out.zmp_inside_polygon_flag);
verifyTrue(testCase, isnan(out.stability_margin));
verifyTrue(testCase, isnan(out.front_margin));
verifyTrue(testCase, isnan(out.lateral_offset));
end

function initialize_project_paths(project_root)
setup_dir = fullfile(project_root, 'lib', 'setup');
if exist(setup_dir, 'dir') == 7
    addpath(setup_dir, '-begin');
end
hexapod_setup_paths();
end
