function command_text = hexapod_build_coppeliasim_start_command(cfg)
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

function quoted = quote_single(text_in)
quoted = sprintf('''%s''', escape_single_quotes(char(text_in)));
end

function text_out = escape_single_quotes(text_in)
text_out = strrep(text_in, '''', '''''');
end
