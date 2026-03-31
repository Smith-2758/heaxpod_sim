function elapsed_sec = hexapod_wait_for_coppeliasim_scene_ready(scene_name, options)
if nargin < 2 || isempty(options)
    options = struct();
end

cfg = hexapod_get_coppeliasim_config(scene_name, options);
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

error('hexapod_wait_for_coppeliasim_scene_ready:Timeout', ...
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
