function tests = test_zmp_metrics_export
tests = functiontests(localfunctions);
end

function test_compute_metrics_generates_zmp_series(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

cfg = hexapod_zmp_defaults();
support_force = cfg.F_enter + max(5, 0.1 * cfg.F_enter);

telemetry = struct();
telemetry.realX = [0; 0.1; 0.2];
telemetry.realY = [0; 0; 0];
telemetry.realZ = [0.5; 0.5; 0.5];
telemetry.bodyEulerDeg = zeros(3, 3);
telemetry.legForceMag = repmat([support_force support_force support_force 0 0 0], 3, 1);
telemetry.legForceXYZ = repmat([0 0 support_force 0 0 support_force 0 0 support_force zeros(1, 9)], 3, 1);
telemetry.footPosXYZ = repmat([0 0 0 1 0 0 0 1 0 zeros(1, 9)], 3, 1);
telemetry.control_dt_sec = 0.1;
telemetry.extra = struct();

metrics = hexapod_compute_metrics(telemetry, struct('scene_name', 'slope'));

verifyEqual(testCase, numel(metrics.series.zmp_x), 3);
verifyEqual(testCase, metrics.series.stance_count, [3; 3; 3]);
verifyTrue(testCase, all(metrics.series.zmp_inside_polygon_flag));
verifyFalse(testCase, isnan(metrics.common.zmp_margin_min_m));
end

function test_compute_metrics_keeps_legacy_logs_compatible(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

telemetry = struct();
telemetry.realX = [0; 0.1; 0.2];
telemetry.realY = [0; 0; 0];
telemetry.realZ = [0.5; 0.5; 0.5];
telemetry.bodyEulerDeg = zeros(3, 3);
telemetry.legForceMag = zeros(3, 6);
telemetry.control_dt_sec = 0.1;

metrics = hexapod_compute_metrics(telemetry, struct('scene_name', 'slope'));

verifyTrue(testCase, isfield(metrics.series, 'zmp_x'));
verifyTrue(testCase, all(isnan(metrics.series.zmp_x)));
verifyTrue(testCase, isnan(metrics.common.zmp_margin_min_m));
verifyEqual(testCase, metrics.scene.slope_progress_m, 0.2, 'AbsTol', 1e-9);
end

function test_export_metrics_writes_zmp_stability_figure(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

output_dir = fullfile(project_root, 'tests', 'tmp_zmp_export');
cleanup_output_dir(output_dir);

telemetry = build_fake_zmp_telemetry();
meta = struct('scene_name', 'ditch', 'output_dir', output_dir, 'run_now', now);

[metrics, run_output_dir] = hexapod_export_metrics(project_root, telemetry, meta);

verifyTrue(testCase, exist(fullfile(run_output_dir, '06_zmp_stability.png'), 'file') == 2);
verifyTrue(testCase, exist(fullfile(run_output_dir, '06_zmp_stability.fig'), 'file') == 2);
verifyEqual(testCase, numel(metrics.series.stability_margin), numel(telemetry.realX));
end

function initialize_project_paths(project_root)
setup_dir = fullfile(project_root, 'lib', 'setup');
if exist(setup_dir, 'dir') == 7
    addpath(setup_dir, '-begin');
end
hexapod_setup_paths();
end

function telemetry = build_fake_zmp_telemetry()
cfg = hexapod_zmp_defaults();
support_force = cfg.F_enter + max(5, 0.1 * cfg.F_enter);

telemetry = struct();
telemetry.realX = [0; 0.1; 0.2];
telemetry.realY = [0; 0; 0];
telemetry.realZ = [0.5; 0.5; 0.5];
telemetry.bodyEulerDeg = zeros(3, 3);
telemetry.legForceMag = repmat([support_force support_force support_force 0 0 0], 3, 1);
telemetry.legForceXYZ = repmat([0 0 support_force 0 0 support_force 0 0 support_force zeros(1, 9)], 3, 1);
telemetry.footPosXYZ = repmat([0 0 0 1 0 0 0 1 0 zeros(1, 9)], 3, 1);
telemetry.control_dt_sec = 0.1;
telemetry.extra = struct();
end

function cleanup_output_dir(output_dir)
if exist(output_dir, 'dir') == 7
    rmdir(output_dir, 's');
end
end
