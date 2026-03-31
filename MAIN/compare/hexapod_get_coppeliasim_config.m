function cfg = hexapod_get_coppeliasim_config(scene_name, options)
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
    error('hexapod_get_coppeliasim_config:SceneNotMapped', '未配置场景 %s 对应的 .ttt 文件。', cfg.scene_name);
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
