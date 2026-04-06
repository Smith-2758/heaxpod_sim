function out = hexapod_compare_registry(action, varargin)
bootstrap_setup_paths();
if nargin < 1 || isempty(action)
    action = 'cases';
end
action = char(string(action));

switch action
    case 'cases'
        out = build_cases();
    case 'resolve_cases'
        if numel(varargin) < 1
            error('hexapod_compare_registry:MissingCaseIds', 'resolve_cases 需要 case_ids。');
        end
        out = resolve_cases(build_cases(), varargin{1});
    case 'reference_case'
        if numel(varargin) < 1
            error('hexapod_compare_registry:MissingSelectedCases', 'reference_case 需要 selected_cases。');
        end
        out = select_reference_case(varargin{1});
    case 'coppeliasim_config'
        if numel(varargin) < 1
            error('hexapod_compare_registry:MissingSceneName', 'coppeliasim_config 需要 scene_name。');
        end
        options = struct();
        if numel(varargin) >= 2 && ~isempty(varargin{2})
            options = varargin{2};
        end
        out = get_coppeliasim_config(varargin{1}, options);
    otherwise
        error('hexapod_compare_registry:UnknownAction', '未知 action: %s', action);
end
end

function cases = build_cases()
root_external = 'D:\codehub\hexapod\轨迹仿真程序';
root_current = fileparts(fileparts(fileparts(mfilename('fullpath'))));

cases = struct( ...
    'case_id', { ...
        'slope_current', 'slope_baseline', 'step_current', 'step_initial', ...
        'ditch_initial', 'ditch_half_mid', 'ditch_final_replay', 'ditch_final_closed_loop'}, ...
    'scene_name', { ...
        'slope', 'slope', 'step', 'step', ...
        'ditch', 'ditch', 'ditch', 'ditch'}, ...
    'scene_variant', { ...
        'current', 'baseline', 'current', 'initial', ...
        'initial', 'half_mid', 'final_replay', 'final_closed_loop'}, ...
    'description', { ...
        '当前斜坡方案', '斜坡旧版轨迹', '当前高台方案', '高台最初版（拆分自 origin 基线）', ...
        '深沟最初版（拆分自 origin 基线）', '深沟中间版（half）', '深沟最终版回放', '深沟最终版闭环'}, ...
    'source_type', { ...
        'pg_current', 'mat_file', 'pg_current', 'origin_step_initial', ...
        'origin_ditch_initial', 'ditch_half_generate_replay', 'mat_file', 'ditch_final_closed_loop'}, ...
    'pattern', { ...
        'slope', 'slope', 'climb2wall', 'climb2wall', ...
        'ditch', 'ditch', 'ditch', 'ditch'}, ...
    'mat_path', { ...
        '', fullfile(root_external, 'MAIN', '6leg_motion', 'export_data', 'walk_slope_backup.mat'), '', '', ...
        '', '', fullfile(root_current, 'MAIN', '6leg_motion', 'ditch', 'export_data', 'walk_ditch_learned.mat'), ''}, ...
    'script_path', { ...
        '', '', '', fullfile(root_external, 'MAIN', '6leg_motion', 'export_data', 'origin', 'walk3step.m'), ...
        fullfile(root_external, 'MAIN', '6leg_motion', 'export_data', 'origin', 'walk3step.m'), fullfile(root_current, 'MAIN', '6leg_motion', 'ditch', 'CoppeliaSim_learn_ditch_half.m'), '', fullfile(root_current, 'MAIN', '6leg_motion', 'ditch', 'CoppeliaSim_learn_ditch.m')});
end

function selected_cases = resolve_cases(all_cases, case_ids)
selected_cases = repmat(all_cases(1), 0, 1);
all_ids = {all_cases.case_id};
for idx = 1:numel(case_ids)
    case_id = case_ids{idx};
    match = strcmp(all_ids, case_id);
    if ~any(match)
        error('hexapod_compare_registry:UnknownCase', '未知的对比 case: %s', case_id);
    end
    selected_cases(end + 1) = all_cases(find(match, 1, 'first')); %#ok<AGROW>
end
end

function cfg = select_reference_case(selected_cases)
priority = ["current", "final_closed_loop", "final_replay", "baseline", "initial", "half_mid"];
for idx = 1:numel(priority)
    match = find(strcmp(string({selected_cases.scene_variant}), priority(idx)), 1, 'first');
    if ~isempty(match)
        cfg = selected_cases(match);
        return;
    end
end
cfg = selected_cases(1);
end

function cfg = get_coppeliasim_config(scene_name, options)
if nargin < 2 || isempty(options)
    options = struct();
end

scene_info = hexapod_scene_info(scene_name);
compare_dir = fileparts(mfilename('fullpath'));
cfg = struct();
cfg.scene_name = scene_info.scene_name;
cfg.exe_path = 'C:\Program Files\CoppeliaRobotics\CoppeliaSimEdu\coppeliaSim.exe';
cfg.scene_paths = struct( ...
    'ditch', 'D:\codehub\hexapod\6leg_ditch.ttt', ...
    'slope', 'D:\codehub\hexapod\6leg_slope.ttt', ...
    'step', 'D:\codehub\hexapod\6leg.ttt');
cfg.host = '127.0.0.1';
cfg.port = 20001;
cfg.auto_restart = true;
cfg.startup_timeout_sec = 30;
cfg.tcp_port_probe_timeout_sec = 0;
cfg.shutdown_timeout_sec = 15;
cfg.settle_sec = 0;
cfg.scene_ready_timeout_sec = 0;
cfg.scene_ready_poll_sec = 0.5;
cfg.scene_ready_connect_timeout_ms = 5000;
cfg.scene_ready_comm_thread_cycle_ms = 5;
cfg.scene_ready_probe_names = {'Rleg1_joint1', 'body'};
cfg.launch_args = {'-xnone'};
cfg.process_name = 'coppeliaSim';
cfg.zmq_host = '127.0.0.1';
cfg.zmq_rpc_port = 23000;
cfg.zmq_startup_timeout_sec = 15;
cfg.legacy_remote_api_activation = 'zmq_temporary_service';
cfg.legacy_remote_api_python_exe = default_legacy_remote_api_python_exe();
cfg.legacy_remote_api_script_path = fullfile(compare_dir, 'hexapod_legacy_remote_api_ctl.py');
cfg.legacy_remote_api_pre_enable_trigger = true;

if isstruct(options) && isfield(options, 'coppeliasim') && isstruct(options.coppeliasim)
    overrides = options.coppeliasim;
    if isfield(overrides, 'scene_paths') && isstruct(overrides.scene_paths)
        override_fields = fieldnames(overrides.scene_paths);
        for idx = 1:numel(override_fields)
            cfg.scene_paths.(override_fields{idx}) = overrides.scene_paths.(override_fields{idx});
        end
    end
    if isfield(overrides, 'scene_ready_probe_names') && ~isempty(overrides.scene_ready_probe_names)
        cfg.scene_ready_probe_names = overrides.scene_ready_probe_names;
    end
    if isfield(overrides, 'launch_args') && ~isempty(overrides.launch_args)
        cfg.launch_args = cellstr(string(overrides.launch_args));
    end
    scalar_fields = {'exe_path', 'host', 'port', 'auto_restart', 'startup_timeout_sec', ...
        'tcp_port_probe_timeout_sec', 'shutdown_timeout_sec', 'settle_sec', 'scene_ready_timeout_sec', ...
        'scene_ready_poll_sec', 'scene_ready_connect_timeout_ms', 'scene_ready_comm_thread_cycle_ms', ...
        'process_name', 'zmq_host', 'zmq_rpc_port', 'zmq_startup_timeout_sec', ...
        'legacy_remote_api_activation', 'legacy_remote_api_python_exe', ...
        'legacy_remote_api_script_path', 'legacy_remote_api_pre_enable_trigger'};
    for idx = 1:numel(scalar_fields)
        field_name = scalar_fields{idx};
        if isfield(overrides, field_name) && ~isempty(overrides.(field_name))
            cfg.(field_name) = overrides.(field_name);
        end
    end
end

if ~isfield(cfg.scene_paths, cfg.scene_name)
    error('hexapod_compare_registry:SceneNotMapped', '未配置场景 %s 对应的 .ttt 文件。', cfg.scene_name);
end
cfg.scene_path = cfg.scene_paths.(cfg.scene_name);
end

function python_exe = default_legacy_remote_api_python_exe()
candidates = { ...
    'D:\miniconda\envs\coppelia-mcp\python.exe', ...
    'python' ...
};
python_exe = candidates{end};
for idx = 1:numel(candidates)
    candidate = candidates{idx};
    if contains(candidate, filesep)
        if exist(candidate, 'file') == 2
            python_exe = candidate;
            return;
        end
    else
        python_exe = candidate;
    end
end
end

function bootstrap_setup_paths()
project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
setup_dir = fullfile(project_root, 'lib', 'setup');
current_paths = string(strsplit(path, pathsep));
if ~any(strcmp(current_paths, string(setup_dir)))
    addpath(setup_dir);
end
hexapod_setup_paths();
end
