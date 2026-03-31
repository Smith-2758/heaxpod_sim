function launch_info = hexapod_restart_coppeliasim_for_scene(scene_name, options)
if nargin < 2 || isempty(options)
    options = struct();
end
cfg = hexapod_get_coppeliasim_config(scene_name, options);
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
    error('hexapod_restart_coppeliasim_for_scene:ExeNotFound', '未找到 CoppeliaSim 可执行文件: %s', cfg.exe_path);
end
if ~exist(cfg.scene_path, 'file')
    error('hexapod_restart_coppeliasim_for_scene:SceneNotFound', '未找到场景文件: %s', cfg.scene_path);
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
    launch_info.port_probe_wait_sec = hexapod_wait_for_tcp_port(cfg.host, cfg.port, cfg.tcp_port_probe_timeout_sec);
    launch_info.startup_wait_sec = launch_info.startup_wait_sec + launch_info.port_probe_wait_sec;
    fprintf('[CoppeliaSim] 远程端口已就绪，耗时 %.2f s\n', launch_info.port_probe_wait_sec);
else
    fprintf('[CoppeliaSim] 已跳过 TCP 端口预探针，避免占用 legacy remoteApi 连接入口。\n');
end

if isfield(cfg, 'legacy_remote_api_activation') && strcmp(cfg.legacy_remote_api_activation, 'zmq_temporary_service')
    fprintf('[CoppeliaSim] 正在等待 ZMQ 远程接口 %s:%d 就绪...\n', cfg.zmq_host, cfg.zmq_rpc_port);
    launch_info.zmq_ready_wait_sec = hexapod_wait_for_tcp_port(cfg.zmq_host, cfg.zmq_rpc_port, cfg.zmq_startup_timeout_sec);
    launch_info.startup_wait_sec = launch_info.startup_wait_sec + launch_info.zmq_ready_wait_sec;
    fprintf('[CoppeliaSim] ZMQ 远程接口已就绪，耗时 %.2f s\n', launch_info.zmq_ready_wait_sec);

    fprintf('[CoppeliaSim] 正在准备临时 legacy remoteApi 服务端口 %d...\n', cfg.port);
    launch_info.legacy_service_wait_sec = activate_legacy_remote_api_service(cfg);
    launch_info.startup_wait_sec = launch_info.startup_wait_sec + launch_info.legacy_service_wait_sec;
    fprintf('[CoppeliaSim] 临时 legacy remoteApi 已准备，耗时 %.2f s\n', launch_info.legacy_service_wait_sec);
end

if cfg.scene_ready_timeout_sec > 0
    fprintf('[CoppeliaSim] 正在等待场景对象就绪: %s\n', strjoin(cfg.scene_ready_probe_names, ', '));
    launch_info.scene_ready_wait_sec = hexapod_wait_for_coppeliasim_scene_ready(scene_name, options);
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
cmd = hexapod_build_coppeliasim_stop_command(cfg.process_name);
run_powershell(cmd, 'StopFailed');
end

function start_process_with_scene(cfg)
cmd = hexapod_build_coppeliasim_start_command(cfg);
run_powershell(cmd, 'StartFailed');
end

function elapsed_sec = activate_legacy_remote_api_service(cfg)
validate_legacy_remote_api_cfg(cfg);
start_tic = tic;
cmd = hexapod_build_legacy_remote_api_activate_command(cfg);
run_powershell(cmd, 'LegacyRemoteApiActivateFailed');
elapsed_sec = toc(start_tic);
end

function validate_legacy_remote_api_cfg(cfg)
if contains(char(cfg.legacy_remote_api_python_exe), filesep) && exist(cfg.legacy_remote_api_python_exe, 'file') ~= 2
    error('hexapod_restart_coppeliasim_for_scene:LegacyPythonNotFound', ...
        '未找到 legacy remoteApi 激活所需的 Python 可执行文件: %s', cfg.legacy_remote_api_python_exe);
end
if exist(cfg.legacy_remote_api_script_path, 'file') ~= 2
    error('hexapod_restart_coppeliasim_for_scene:LegacyScriptNotFound', ...
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
    error('hexapod_restart_coppeliasim_for_scene:ProcessStartTimeout', '在 %.1f 秒内未检测到 CoppeliaSim 进程启动。', timeout_sec);
end
error('hexapod_restart_coppeliasim_for_scene:ProcessStopTimeout', '在 %.1f 秒内未检测到 CoppeliaSim 进程退出。', timeout_sec);
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
    error(['hexapod_restart_coppeliasim_for_scene:', error_suffix], 'PowerShell 执行失败: %s', strtrim(output));
end
end
