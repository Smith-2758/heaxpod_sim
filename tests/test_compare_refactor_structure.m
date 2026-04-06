function tests = test_compare_refactor_structure
tests = functiontests(localfunctions);
end

function test_target_compare_file_layout(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));

expected_compare_files = {
    fullfile(project_root, 'MAIN', 'compare', 'hexapod_compare_batch.m')
    fullfile(project_root, 'MAIN', 'compare', 'hexapod_compare_registry.m')
    fullfile(project_root, 'MAIN', 'compare', 'hexapod_compare_runtime.m')
    fullfile(project_root, 'MAIN', 'compare', 'hexapod_compare_trajectory.m')
    fullfile(project_root, 'MAIN', 'compare', 'hexapod_compare_report.m')
    fullfile(project_root, 'MAIN', 'compare', 'hexapod_run_compare_batch.m')
    fullfile(project_root, 'MAIN', 'compare', 'hexapod_legacy_remote_api_ctl.py')
    fullfile(project_root, 'MAIN', 'compare', 'metircs_analyze', 'hexapod_plot_midterm_slope.m')
    fullfile(project_root, 'MAIN', 'compare', 'README.md')
    };

expected_lib_files = {
    fullfile(project_root, 'lib', 'setup', 'hexapod_setup_paths.m')
    fullfile(project_root, 'lib', 'remote_api', 'MatlabVrep.m')
    fullfile(project_root, 'lib', 'remote_api', 'remApi.m')
    fullfile(project_root, 'lib', 'remote_api', 'remoteApiProto.m')
    fullfile(project_root, 'lib', 'remote_api', 'remoteApi.dll')
    fullfile(project_root, 'lib', 'remote_api', 'hexapod_retry_remote_connect.m')
    fullfile(project_root, 'lib', 'remote_api', 'hexapod_retry_remote_handle_lookup.m')
    fullfile(project_root, 'lib', 'metrics', 'hexapod_compute_metrics.m')
    fullfile(project_root, 'lib', 'metrics', 'hexapod_export_metrics.m')
    fullfile(project_root, 'lib', 'metrics', 'hexapod_prepare_output_dir.m')
    fullfile(project_root, 'lib', 'common', 'hexapod_scene_info.m')
    fullfile(project_root, 'lib', 'common', 'hexapod_resample_series.m')
    fullfile(project_root, 'lib', 'common', 'TSpline_S_V_A.m')
    };

for idx = 1:numel(expected_compare_files)
    verifyTrue(testCase, isfile(expected_compare_files{idx}), ...
        sprintf('Missing compare target file: %s', expected_compare_files{idx}));
end

for idx = 1:numel(expected_lib_files)
    verifyTrue(testCase, isfile(expected_lib_files{idx}), ...
        sprintf('Missing lib target file: %s', expected_lib_files{idx}));
end
end

function test_slope_midterm_plot_keeps_only_metrics_analyze_copy(testCase)
initialize_project_paths();
test_file = which('test_compare_refactor_structure');
if isempty(test_file)
    test_file = fullfile(pwd, 'test_compare_refactor_structure.m');
end
project_root = fileparts(fileparts(test_file));

root_copy = fullfile(project_root, 'MAIN', 'compare', 'hexapod_plot_midterm_slope.m');
canonical_copy = fullfile(project_root, 'MAIN', 'compare', 'metircs_analyze', 'hexapod_plot_midterm_slope.m');

verifyFalse(testCase, isfile(root_copy), ...
    sprintf('斜坡中期报告脚本不应再保留根目录副本: %s', root_copy));
verifyTrue(testCase, isfile(canonical_copy), ...
    sprintf('斜坡中期报告脚本应保留在 metircs_analyze: %s', canonical_copy));

resolved_path = which('hexapod_plot_midterm_slope');
verifyTrue(testCase, strcmpi(resolved_path, canonical_copy), ...
    sprintf('MATLAB 解析到的 hexapod_plot_midterm_slope 应指向 metircs_analyze，当前为: %s', resolved_path));
end

function test_ditch_compare_case_trajectory_mapping(testCase)
initialize_project_paths();
cases = hexapod_compare_registry('cases');

half_mid = cases(strcmp({cases.case_id}, 'ditch_half_mid'));
final_replay = cases(strcmp({cases.case_id}, 'ditch_final_replay'));

verifyEqual(testCase, numel(half_mid), 1, 'ditch_half_mid 映射缺失。');
verifyEqual(testCase, numel(final_replay), 1, 'ditch_final_replay 映射缺失。');

verifyEqual(testCase, string(half_mid.source_type), "ditch_half_generate_replay", ...
    sprintf('ditch_half_mid 应走生成后回放链路，当前 source_type=%s', string(half_mid.source_type)));
verifyTrue(testCase, isempty(half_mid.mat_path), ...
    sprintf('ditch_half_mid 不应依赖静态轨迹文件，当前为: %s', half_mid.mat_path));
verifyTrue(testCase, endsWith(normalize_path(half_mid.script_path), ...
    normalize_path(fullfile('MAIN', '6leg_motion', 'ditch', 'CoppeliaSim_learn_ditch_half.m'))), ...
    sprintf('ditch_half_mid 应指向本项目的 CoppeliaSim_learn_ditch_half.m，当前为: %s', half_mid.script_path));
verifyTrue(testCase, isfile(half_mid.script_path), ...
    sprintf('ditch_half_mid 生成脚本不存在: %s', half_mid.script_path));

verifyTrue(testCase, endsWith(normalize_path(final_replay.mat_path), ...
    normalize_path(fullfile('MAIN', '6leg_motion', 'ditch', 'export_data', 'walk_ditch_learned.mat'))), ...
    sprintf('ditch_final_replay 应指向最终版 walk_ditch_learned.mat，当前为: %s', final_replay.mat_path));
end

function initialize_project_paths()
test_file = which('test_compare_refactor_structure');
if isempty(test_file)
    test_file = fullfile(pwd, 'test_compare_refactor_structure.m');
end
project_root = fileparts(fileparts(test_file));
setup_dir = fullfile(project_root, 'lib', 'setup');
if exist(setup_dir, 'dir') == 7 && isempty(which('hexapod_setup_paths'))
    addpath(setup_dir);
end
hexapod_setup_paths();
end

function out = normalize_path(in)
out = strrep(char(string(in)), '/', filesep);
out = strrep(out, '\', filesep);
end
