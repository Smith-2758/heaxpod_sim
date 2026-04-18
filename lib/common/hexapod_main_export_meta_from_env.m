function meta = hexapod_main_export_meta_from_env()
meta = struct();

meta = assign_numeric_env(meta, 'coppeliasim_port', 'HEXAPOD_COPPELIASIM_PORT');
meta = assign_text_env(meta, 'scene_name', 'HEXAPOD_SCENE_NAME');
meta = assign_text_env(meta, 'scene_label', 'HEXAPOD_SCENE_LABEL');
meta = assign_text_env(meta, 'scene_variant', 'HEXAPOD_SCENE_VARIANT');
meta = assign_text_env(meta, 'coppeliasim_scene_path', 'HEXAPOD_COPPELIASIM_SCENE_PATH');
meta = assign_text_env(meta, 'coppeliasim_exe_path', 'HEXAPOD_COPPELIASIM_EXE_PATH');
meta = assign_text_env(meta, 'coppeliasim_host', 'HEXAPOD_COPPELIASIM_HOST');
meta = assign_numeric_env(meta, 'coppeliasim_auto_restart', 'HEXAPOD_COPPELIASIM_AUTO_RESTART');
meta = assign_numeric_env(meta, 'coppeliasim_restart_performed', 'HEXAPOD_COPPELIASIM_RESTART_PERFORMED');
meta = assign_numeric_env(meta, 'coppeliasim_startup_wait_sec', 'HEXAPOD_COPPELIASIM_STARTUP_WAIT_SEC');
meta = assign_numeric_env(meta, 'coppeliasim_shutdown_wait_sec', 'HEXAPOD_COPPELIASIM_SHUTDOWN_WAIT_SEC');
meta = assign_text_env(meta, 'coppeliasim_launch_timestamp', 'HEXAPOD_COPPELIASIM_LAUNCH_TIMESTAMP');
end

function meta = assign_text_env(meta, field_name, env_name)
value = strtrim(getenv(env_name));
if isempty(value)
    return;
end
meta.(field_name) = value;
end

function meta = assign_numeric_env(meta, field_name, env_name)
value = strtrim(getenv(env_name));
if isempty(value)
    return;
end

numeric_value = str2double(value);
if ~isnan(numeric_value)
    meta.(field_name) = numeric_value;
end
end
