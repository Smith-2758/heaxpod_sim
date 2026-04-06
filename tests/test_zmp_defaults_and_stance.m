function tests = test_zmp_defaults_and_stance
tests = functiontests(localfunctions);
end

function test_setup_paths_include_zmp_dir(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

setup_info = hexapod_setup_paths();
zmp_path = string(fullfile(project_root, 'lib', 'zmp'));

verifyTrue(testCase, any(setup_info.required_paths == zmp_path), ...
    sprintf('hexapod_setup_paths required_paths 应包含 zmp 目录: %s', zmp_path));
end

function test_zmp_defaults_exposes_required_fields(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

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

for idx = 1:numel(required_fields)
    verifyTrue(testCase, isfield(defaults, required_fields{idx}), ...
        sprintf('hexapod_zmp_defaults 缺少字段: %s', required_fields{idx}));
end
end

function initialize_project_paths(project_root)
setup_dir = fullfile(project_root, 'lib', 'setup');
if exist(setup_dir, 'dir') == 7 && isempty(which('hexapod_setup_paths'))
    addpath(setup_dir);
end
hexapod_setup_paths();
end
