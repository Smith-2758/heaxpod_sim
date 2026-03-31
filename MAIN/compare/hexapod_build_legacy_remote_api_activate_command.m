function command_text = hexapod_build_legacy_remote_api_activate_command(cfg)
if ~isfield(cfg, 'legacy_remote_api_activation') || ~strcmp(cfg.legacy_remote_api_activation, 'zmq_temporary_service')
    error('hexapod_build_legacy_remote_api_activate_command:UnsupportedMode', ...
        '不支持的 legacy remoteApi 激活模式: %s', string(getfield(cfg, 'legacy_remote_api_activation'))); %#ok<GFLD>
end
if ~isfield(cfg, 'legacy_remote_api_python_exe') || isempty(cfg.legacy_remote_api_python_exe)
    error('hexapod_build_legacy_remote_api_activate_command:MissingPython', '未配置 legacy remoteApi 激活所需的 Python 可执行文件。');
end
if ~isfield(cfg, 'legacy_remote_api_script_path') || isempty(cfg.legacy_remote_api_script_path)
    error('hexapod_build_legacy_remote_api_activate_command:MissingScript', '未配置 legacy remoteApi 激活脚本路径。');
end

python_exe = quote_single(cfg.legacy_remote_api_python_exe);
script_path = quote_single(cfg.legacy_remote_api_script_path);
host = quote_single(cfg.zmq_host);
pre_enable_trigger = quote_single(logical_text(cfg.legacy_remote_api_pre_enable_trigger));
command_text = sprintf('& %s %s --host %s --rpc-port %d --legacy-port %d --mode ensure-temporary --pre-enable-trigger %s', ...
    python_exe, script_path, host, cfg.zmq_rpc_port, cfg.port, pre_enable_trigger);
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
