function out = hexapod_compare_runtime(action, varargin)
bootstrap_setup_paths();
if nargin < 1 || isempty(action)
    error('hexapod_compare_runtime:MissingAction', '必须提供 action。');
end
action = char(string(action));

switch action
    case 'restart_coppeliasim_for_scene'
        scene_name = varargin{1};
        options = struct();
        if numel(varargin) >= 2 && ~isempty(varargin{2})
            options = varargin{2};
        end
        out = restart_coppeliasim_for_scene(scene_name, options);
    otherwise
        error('hexapod_compare_runtime:UnknownAction', '未知 action: %s', action);
end
end

function launch_info = restart_coppeliasim_for_scene(scene_name, options)
if nargin < 2 || isempty(options)
    options = struct();
end
cfg = hexapod_compare_registry('coppeliasim_config', scene_name, options);
launch_info = cfg;
launch_info.restart_performed = false;
launch_info.startup_wait_sec = 0;
launch_info.process_ready_wait_sec = 0;
launch_info.port_probe_wait_sec = 0;
launch_info.zmq_ready_wait_sec = 0;
launch_info.legacy_service_wait_sec = 0;
launch_info.shutdown_wait_sec = 0;
launch_info.scene_ready_wait_sec = 0;
launch_info.launch_timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

if ~cfg.auto_restart
    return;
end
if ~exist(cfg.exe_path, 'file')
    error('hexapod_compare_runtime:ExeNotFound', '未找到 CoppeliaSim 可执行文件: %s', cfg.exe_path);
end
if ~exist(cfg.scene_path, 'file')
    error('hexapod_compare_runtime:SceneNotFound', '未找到场景文件: %s', cfg.scene_path);
end

fprintf('[CoppeliaSim] 正在关闭旧进程...\n');
stop_existing_processes(cfg);
launch_info.shutdown_wait_sec = wait_for_process_state(cfg, false, cfg.shutdown_timeout_sec);
fprintf('[CoppeliaSim] 旧进程已退出，耗时 %.2f s\n', launch_info.shutdown_wait_sec);

fprintf('[CoppeliaSim] 正在启动程序并打开场景...\n');
start_process_with_scene(cfg);

fprintf('[CoppeliaSim] 正在等待进程启动...\n');
launch_info.process_ready_wait_sec = wait_for_process_state(cfg, true, cfg.startup_timeout_sec);
launch_info.startup_wait_sec = launch_info.process_ready_wait_sec;
fprintf('[CoppeliaSim] 进程已启动，耗时 %.2f s\n', launch_info.process_ready_wait_sec);

if isfield(cfg, 'tcp_port_probe_timeout_sec') && cfg.tcp_port_probe_timeout_sec > 0
    fprintf('[CoppeliaSim] 正在等待远程端口 %s:%d 就绪...\n', cfg.host, cfg.port);
    launch_info.port_probe_wait_sec = wait_for_tcp_port(cfg.host, cfg.port, cfg.tcp_port_probe_timeout_sec);
    launch_info.startup_wait_sec = launch_info.startup_wait_sec + launch_info.port_probe_wait_sec;
    fprintf('[CoppeliaSim] 远程端口已就绪，耗时 %.2f s\n', launch_info.port_probe_wait_sec);
else
    fprintf('[CoppeliaSim] 已跳过 TCP 端口预探针，避免占用 legacy remoteApi 连接入口。\n');
end

if isfield(cfg, 'legacy_remote_api_activation') && strcmp(cfg.legacy_remote_api_activation, 'zmq_temporary_service')
    fprintf('[CoppeliaSim] 正在等待 ZMQ 远程接口 %s:%d 就绪...\n', cfg.zmq_host, cfg.zmq_rpc_port);
    launch_info.zmq_ready_wait_sec = wait_for_tcp_port(cfg.zmq_host, cfg.zmq_rpc_port, cfg.zmq_startup_timeout_sec);
    launch_info.startup_wait_sec = launch_info.startup_wait_sec + launch_info.zmq_ready_wait_sec;
    fprintf('[CoppeliaSim] ZMQ 远程接口已就绪，耗时 %.2f s\n', launch_info.zmq_ready_wait_sec);

    fprintf('[CoppeliaSim] 正在准备临时 legacy remoteApi 服务端口 %d...\n', cfg.port);
    launch_info.legacy_service_wait_sec = activate_legacy_remote_api_service(cfg);
    launch_info.startup_wait_sec = launch_info.startup_wait_sec + launch_info.legacy_service_wait_sec;
    fprintf('[CoppeliaSim] 临时 legacy remoteApi 已准备，耗时 %.2f s\n', launch_info.legacy_service_wait_sec);
end

if cfg.scene_ready_timeout_sec > 0
    fprintf('[CoppeliaSim] 正在等待场景对象就绪: %s\n', strjoin(cfg.scene_ready_probe_names, ', '));
    launch_info.scene_ready_wait_sec = wait_for_coppeliasim_scene_ready(scene_name, options);
    fprintf('[CoppeliaSim] 场景对象已就绪，耗时 %.2f s\n', launch_info.scene_ready_wait_sec);
else
    fprintf('[CoppeliaSim] 已跳过场景对象预探针，由 MatlabVrep.init 内部重试获取句柄。\n');
end

if cfg.settle_sec > 0
    fprintf('[CoppeliaSim] 额外静置 %.2f s...\n', cfg.settle_sec);
    pause(cfg.settle_sec);
    launch_info.startup_wait_sec = launch_info.startup_wait_sec + cfg.settle_sec;
end
launch_info.restart_performed = true;
end

function stop_existing_processes(cfg)
cmd = build_coppeliasim_stop_command(cfg.process_name);
run_powershell(cmd, 'StopFailed');
end

function start_process_with_scene(cfg)
cmd = build_coppeliasim_start_command(cfg);
run_powershell(cmd, 'StartFailed');
end

function elapsed_sec = activate_legacy_remote_api_service(cfg)
validate_legacy_remote_api_cfg(cfg);
start_tic = tic;
cmd = build_legacy_remote_api_activate_command(cfg);
run_powershell(cmd, 'LegacyRemoteApiActivateFailed');
elapsed_sec = toc(start_tic);
end

function validate_legacy_remote_api_cfg(cfg)
if contains(char(cfg.legacy_remote_api_python_exe), filesep) && exist(cfg.legacy_remote_api_python_exe, 'file') ~= 2
    error('hexapod_compare_runtime:LegacyPythonNotFound', ...
        '未找到 legacy remoteApi 激活所需的 Python 可执行文件: %s', cfg.legacy_remote_api_python_exe);
end
if exist(cfg.legacy_remote_api_script_path, 'file') ~= 2
    error('hexapod_compare_runtime:LegacyScriptNotFound', ...
        '未找到 legacy remoteApi 激活脚本: %s', cfg.legacy_remote_api_script_path);
end
end

function elapsed_sec = wait_for_process_state(cfg, should_exist, timeout_sec)
start_tic = tic;
elapsed_sec = 0;
while toc(start_tic) <= timeout_sec
    exists_now = process_exists(cfg.process_name);
    if exists_now == should_exist
        elapsed_sec = toc(start_tic);
        return;
    end
    pause(0.5);
end
if should_exist
    error('hexapod_compare_runtime:ProcessStartTimeout', '在 %.1f 秒内未检测到 CoppeliaSim 进程启动。', timeout_sec);
end
error('hexapod_compare_runtime:ProcessStopTimeout', '在 %.1f 秒内未检测到 CoppeliaSim 进程退出。', timeout_sec);
end

function tf = process_exists(process_name)
[status, output] = system(sprintf('powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "(Get-Process -Name ''%s'' -ErrorAction SilentlyContinue).Count" 2>&1', process_name));
if status ~= 0
    tf = false;
    return;
end
tf = str2double(strtrim(output)) > 0;
end

function run_powershell(command_text, error_suffix)
full_cmd = sprintf('powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "%s" 2>&1', command_text);
[status, output] = system(full_cmd);
if status ~= 0
    error(['hexapod_compare_runtime:', error_suffix], 'PowerShell 执行失败: %s', strtrim(output));
end
end

function command_text = build_coppeliasim_start_command(cfg)
args = {};
if isfield(cfg, 'launch_args') && ~isempty(cfg.launch_args)
    args = cellstr(string(cfg.launch_args));
end
scene_arg = ['-f', char(cfg.scene_path)];
args = [args(:); {scene_arg}];
quoted_args = cellfun(@quote_single, args, 'UniformOutput', false);
working_dir = fileparts(char(cfg.exe_path));
command_text = sprintf('Start-Process -FilePath ''%s'' -WorkingDirectory ''%s'' -ArgumentList @(%s)', ...
    escape_single_quotes(cfg.exe_path), escape_single_quotes(working_dir), strjoin(quoted_args, ', '));
end

function command_text = build_coppeliasim_stop_command(process_name)
if nargin < 1 || isempty(process_name)
    process_name = 'coppeliaSim';
end
command_text = sprintf([ ...
    '$p = Get-Process -Name ''%s'' -ErrorAction SilentlyContinue; ' ...
    'if ($p) { $p | Stop-Process -Force; exit 0 } ' ...
    'else { Write-Output ''no-process''; exit 0 }'], process_name);
end

function command_text = build_legacy_remote_api_activate_command(cfg)
if ~isfield(cfg, 'legacy_remote_api_activation') || ~strcmp(cfg.legacy_remote_api_activation, 'zmq_temporary_service')
    error('hexapod_compare_runtime:UnsupportedLegacyMode', ...
        '不支持的 legacy remoteApi 激活模式: %s', string(getfield(cfg, 'legacy_remote_api_activation'))); %#ok<GFLD>
end
if ~isfield(cfg, 'legacy_remote_api_python_exe') || isempty(cfg.legacy_remote_api_python_exe)
    error('hexapod_compare_runtime:MissingLegacyPython', '未配置 legacy remoteApi 激活所需的 Python 可执行文件。');
end
if ~isfield(cfg, 'legacy_remote_api_script_path') || isempty(cfg.legacy_remote_api_script_path)
    error('hexapod_compare_runtime:MissingLegacyScript', '未配置 legacy remoteApi 激活脚本路径。');
end

python_exe = quote_single(cfg.legacy_remote_api_python_exe);
script_path = quote_single(cfg.legacy_remote_api_script_path);
host = quote_single(cfg.zmq_host);
pre_enable_trigger = quote_single(logical_text(cfg.legacy_remote_api_pre_enable_trigger));
command_text = sprintf('& %s %s --host %s --rpc-port %d --legacy-port %d --mode ensure-temporary --pre-enable-trigger %s', ...
    python_exe, script_path, host, cfg.zmq_rpc_port, cfg.port, pre_enable_trigger);
end

function elapsed_sec = wait_for_coppeliasim_scene_ready(scene_name, options)
if nargin < 2 || isempty(options)
    options = struct();
end

cfg = hexapod_compare_registry('coppeliasim_config', scene_name, options);
probe_names = cfg.scene_ready_probe_names;
custom_probe_fn = get_custom_scene_ready_probe_fn(options);
api = [];
client_id = -1;
cleanupObj = onCleanup(@() cleanup_remote_api(api, client_id)); %#ok<NASGU>

if isempty(custom_probe_fn)
    [~, api] = evalc('remApi(''remoteApi'')');
end

start_tic = tic;
elapsed_sec = NaN;
while toc(start_tic) <= cfg.scene_ready_timeout_sec
    if isempty(custom_probe_fn)
        [is_ready, client_id] = default_scene_ready_probe(api, client_id, cfg, probe_names);
    else
        is_ready = custom_probe_fn(cfg, probe_names);
    end
    if is_ready
        elapsed_sec = toc(start_tic);
        return;
    end
    pause(cfg.scene_ready_poll_sec);
end

error('hexapod_compare_runtime:SceneReadyTimeout', ...
    '在 %.1f 秒内未检测到场景对象就绪: %s', ...
    cfg.scene_ready_timeout_sec, strjoin(probe_names, ', '));
end

function probe_fn = get_custom_scene_ready_probe_fn(options)
probe_fn = [];
if isstruct(options) && isfield(options, 'coppeliasim') && isstruct(options.coppeliasim)
    overrides = options.coppeliasim;
    if isfield(overrides, 'scene_ready_probe_fn') && ~isempty(overrides.scene_ready_probe_fn)
        probe_fn = overrides.scene_ready_probe_fn;
    end
end
end

function [tf, client_id] = default_scene_ready_probe(api, client_id, cfg, probe_names)
tf = false;
try
    if isempty(api)
        return;
    end
    if client_id < 0
        client_id = api.simxStart(cfg.host, cfg.port, true, true, ...
            cfg.scene_ready_connect_timeout_ms, cfg.scene_ready_comm_thread_cycle_ms);
        if client_id < 0
            return;
        end
    end

    tf = true;
    for idx = 1:numel(probe_names)
        [ret_code, ~] = api.simxGetObjectHandle(client_id, probe_names{idx}, api.simx_opmode_oneshot_wait);
        if ret_code ~= api.simx_return_ok
            tf = false;
            return;
        end
    end
catch
    tf = false;
    client_id = -1;
end
end

function cleanup_remote_api(api, client_id)
if isempty(api)
    return;
end
try
    if ~isempty(client_id) && isnumeric(client_id) && client_id >= 0
        api.simxFinish(client_id);
    end
catch
end
end

function elapsed_sec = wait_for_tcp_port(host, port, timeout_sec)
if nargin < 3 || isempty(timeout_sec)
    timeout_sec = 30;
end
start_tic = tic;
elapsed_sec = NaN;
while toc(start_tic) <= timeout_sec
    if is_tcp_port_open(host, port)
        elapsed_sec = toc(start_tic);
        return;
    end
    pause(0.5);
end
error('hexapod_compare_runtime:TcpPortTimeout', '在 %.1f 秒内未检测到 %s:%d 可连接。', timeout_sec, host, port);
end

function tf = is_tcp_port_open(host, port)
tf = false;
socket = [];
try
    socket = java.net.Socket();
    socket.connect(java.net.InetSocketAddress(host, port), 500);
    tf = true;
catch
    tf = false;
end
if ~isempty(socket)
    try
        socket.close();
    catch
    end
end
end

function text = logical_text(value)
if islogical(value)
    tf = value;
else
    tf = logical(value);
end
if tf
    text = 'true';
else
    text = 'false';
end
end

function quoted = quote_single(text_in)
quoted = sprintf('''%s''', escape_single_quotes(char(text_in)));
end

function text_out = escape_single_quotes(text_in)
text_out = strrep(text_in, '''', '''''');
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
