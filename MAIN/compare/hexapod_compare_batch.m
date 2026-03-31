function summary = hexapod_compare_batch(case_ids, options)
setup_info = bootstrap_setup_paths();
project_root = setup_info.project_root;
all_cases = hexapod_compare_registry('cases');
all_ids = {all_cases.case_id};

if nargin < 1 || isempty(case_ids)
    case_ids = all_ids;
elseif ischar(case_ids) || isstring(case_ids)
    case_ids = cellstr(case_ids);
end
if nargin < 2 || isempty(options)
    options = struct();
end

selected_cases = hexapod_compare_registry('resolve_cases', case_ids);
scene_names = unique(string({selected_cases.scene_name}));
if numel(scene_names) ~= 1
    error('hexapod_compare_batch:MixedScenes', '一次批处理只允许包含同一场景下的 case。');
end
scene_name = char(scene_names(1));
scene_info = hexapod_scene_info(scene_name);
num_repeats = get_option(options, 'num_repeats', 3);
if ~isscalar(num_repeats) || num_repeats < 1 || num_repeats ~= floor(num_repeats)
    error('hexapod_compare_batch:InvalidRepeatCount', 'num_repeats 必须是正整数。');
end

reference_case = hexapod_compare_registry('reference_case', selected_cases);
default_total_frames = get_option(options, 'default_total_frames', []);
if isempty(default_total_frames)
    default_total_frames = hexapod_compare_trajectory('probe_case_frame_count', reference_case);
end

target_total_frames = get_option(options, 'target_total_frames', []);
if isempty(target_total_frames)
    target_total_frames = prompt_total_frames(default_total_frames, scene_name);
end

compare_group_id = get_option(options, 'compare_group_id', '');
if isempty(compare_group_id)
    compare_group_id = sprintf('compare_%s', datestr(now, 'yyyymmdd_HHMMSS'));
end

launcher_cfg = hexapod_compare_registry('coppeliasim_config', scene_name, options);
group_root = fullfile(project_root, 'log', scene_info.scene_name, compare_group_id);
if ~exist(group_root, 'dir')
    mkdir(group_root);
end

fprintf('\n===== 启动对比实验组 =====\n');
fprintf('场景: %s (%s)\n', scene_info.scene_name, scene_info.scene_label);
fprintf('实验组: %s\n', compare_group_id);
fprintf('Case 数量: %d\n', numel(selected_cases));
fprintf('重复次数: %d\n', num_repeats);
fprintf('统一总帧数: %d\n', target_total_frames);
fprintf('结果目录: %s\n', group_root);
fprintf('CoppeliaSim 自动重启: %s\n', on_off_text(launcher_cfg.auto_restart));
fprintf('CoppeliaSim 程序: %s\n', launcher_cfg.exe_path);
fprintf('场景文件: %s\n', launcher_cfg.scene_path);

results = cell(numel(selected_cases), num_repeats);
launch_records = cell(numel(selected_cases), num_repeats);
for case_idx = 1:numel(selected_cases)
    cfg = selected_cases(case_idx);
    for repeat_idx = 1:num_repeats
        fprintf('\n===== [%d/%d] 运行 case: %s | repeat %d/%d =====\n', ...
            case_idx, numel(selected_cases), cfg.case_id, repeat_idx, num_repeats);
        launch_info = hexapod_compare_runtime('restart_coppeliasim_for_scene', scene_info.scene_name, options);
        launch_records{case_idx, repeat_idx} = launch_info;
        fprintf('CoppeliaSim 场景就绪: %s\n', launch_info.scene_path);
        if launch_info.restart_performed
            fprintf('启动等待时间: %.2f s\n', launch_info.startup_wait_sec);
            if isfield(launch_info, 'port_probe_wait_sec') && launch_info.port_probe_wait_sec > 0
                fprintf('端口探测等待时间: %.2f s\n', launch_info.port_probe_wait_sec);
            end
            fprintf('场景对象就绪等待时间: %.2f s\n', launch_info.scene_ready_wait_sec);
        end

        run_options = options;
        run_options.compare_group_id = compare_group_id;
        run_options.repeat_index = repeat_idx;
        run_options.target_total_frames = target_total_frames;
        run_options.coppeliasim_launch_info = launch_info;
        results{case_idx, repeat_idx} = hexapod_compare_trajectory('run_case', cfg.case_id, run_options);
    end
end

report = hexapod_compare_report('collect_metrics', fullfile(project_root, 'log', scene_info.scene_name), struct( ...
    'compare_group_id', compare_group_id, ...
    'max_runs_per_case', min(3, num_repeats), ...
    'output_root', group_root));

summary = struct();
summary.compare_group_id = compare_group_id;
summary.scene_name = scene_info.scene_name;
summary.scene_label = scene_info.scene_label;
summary.target_total_frames = target_total_frames;
summary.num_repeats = num_repeats;
summary.group_root = group_root;
summary.case_results = results;
summary.launch_records = launch_records;
summary.report = report;

fprintf('\n===== 对比实验组完成 =====\n');
fprintf('最新三次索引: %s\n', report.latest_csv);
fprintf('聚合结果: %s\n', report.aggregate_csv);
fprintf('摘要文件: %s\n', report.summary_md);
end

function target_total_frames = prompt_total_frames(default_total_frames, scene_name)
if nargin < 2 || isempty(scene_name)
    scene_name = 'unknown';
end
if nargin < 1 || isempty(default_total_frames)
    error('hexapod_compare_batch:MissingDefaultFrames', '必须提供默认帧数。');
end
if ~isscalar(default_total_frames) || default_total_frames < 2 || default_total_frames ~= floor(default_total_frames)
    error('hexapod_compare_batch:InvalidDefaultFrames', '默认帧数必须是大于等于 2 的整数。');
end

scene_info = hexapod_scene_info(scene_name);
prompt = sprintf('[%s] 请输入总帧数，直接回车使用默认 %d 帧: ', scene_info.scene_label, default_total_frames);
answer = strtrim(input(prompt, 's'));
if isempty(answer)
    target_total_frames = default_total_frames;
    return;
end

target_total_frames = str2double(answer);
if isnan(target_total_frames) || ~isfinite(target_total_frames) || target_total_frames < 2 || target_total_frames ~= floor(target_total_frames)
    error('hexapod_compare_batch:InvalidFrameInput', '输入的总帧数必须是大于等于 2 的整数。');
end
end

function text_out = on_off_text(flag_value)
if flag_value
    text_out = 'ON';
else
    text_out = 'OFF';
end
end

function value = get_option(options, field_name, default_value)
if isstruct(options) && isfield(options, field_name)
    value = options.(field_name);
else
    value = default_value;
end
end

function setup_info = bootstrap_setup_paths()
project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
setup_dir = fullfile(project_root, 'lib', 'setup');
current_paths = string(strsplit(path, pathsep));
if ~any(strcmp(current_paths, string(setup_dir)))
    addpath(setup_dir);
end
setup_info = hexapod_setup_paths();
end
