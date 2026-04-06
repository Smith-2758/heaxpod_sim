function tests = test_compute_metrics_placeholders
tests = functiontests(localfunctions);
end

function test_slope_metrics_ignore_leading_placeholder_sample(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

telemetry = struct();
telemetry.realX = [0; 3.8; 4.3; 5.0];
telemetry.realY = [0; 0; 0; 0];
telemetry.realZ = [0; 2.7; 2.8; 3.0];
telemetry.bodyEulerDeg = zeros(4, 3);
telemetry.legForceMag = zeros(4, 6);
telemetry.control_dt_sec = 0.1;

meta = struct();
meta.scene_name = 'slope';

metrics = hexapod_compute_metrics(telemetry, meta);

verifyEqual(testCase, metrics.scene.slope_progress_m, 1.2, 'AbsTol', 1e-9, ...
    '斜坡推进距离应从真实起点而不是伪零点开始计算。');
verifyEqual(testCase, metrics.scene.climb_height_gain_m, 0.3, 'AbsTol', 1e-9, ...
    '斜坡爬升高度应从真实起点而不是伪零点开始计算。');
verifyEqual(testCase, metrics.common.net_displacement_m, hypot(1.2, 0.3), 'AbsTol', 1e-9, ...
    '净位移应忽略前导伪零点。');
end

function test_true_origin_start_is_not_trimmed(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

telemetry = struct();
telemetry.realX = [0; 0.05; 0.12];
telemetry.realY = [0; 0; 0];
telemetry.realZ = [0; 0.01; 0.02];
telemetry.bodyEulerDeg = zeros(3, 3);
telemetry.legForceMag = zeros(3, 6);
telemetry.control_dt_sec = 0.1;

meta = struct();
meta.scene_name = 'slope';

metrics = hexapod_compute_metrics(telemetry, meta);

verifyEqual(testCase, metrics.scene.slope_progress_m, 0.12, 'AbsTol', 1e-9, ...
    '真实从原点起步的数据不应被误判为伪零点并裁掉。');
verifyEqual(testCase, metrics.scene.climb_height_gain_m, 0.02, 'AbsTol', 1e-9);
end

function initialize_project_paths(project_root)
setup_dir = fullfile(project_root, 'lib', 'setup');
if exist(setup_dir, 'dir') == 7 && isempty(which('hexapod_setup_paths'))
    addpath(setup_dir);
end
hexapod_setup_paths();
end
