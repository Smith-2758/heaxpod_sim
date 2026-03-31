function out = hexapod_compare_report(action, varargin)
bootstrap_setup_paths();
if nargin < 1 || isempty(action)
    error('hexapod_compare_report:MissingAction', '必须提供 action。');
end
action = char(string(action));

switch action
    case 'prepare_run_dir'
        if numel(varargin) < 4
            error('hexapod_compare_report:MissingPrepareArgs', 'prepare_run_dir 需要 project_root, scene_name, compare_group_id, case_id。');
        end
        repeat_index = 1;
        if numel(varargin) >= 5 && ~isempty(varargin{5})
            repeat_index = varargin{5};
        end
        [run_output_dir, group_root] = prepare_compare_run_dir(varargin{1}, varargin{2}, varargin{3}, varargin{4}, repeat_index);
        out = {run_output_dir, group_root};
    case 'collect_metrics'
        log_root = [];
        options = struct();
        if numel(varargin) >= 1
            log_root = varargin{1};
        end
        if numel(varargin) >= 2 && ~isempty(varargin{2})
            options = varargin{2};
        end
        out = collect_compare_metrics(log_root, options);
    otherwise
        error('hexapod_compare_report:UnknownAction', '未知 action: %s', action);
end
end

function [run_output_dir, group_root] = prepare_compare_run_dir(project_root, scene_name, compare_group_id, case_id, repeat_index)
if nargin < 5 || isempty(repeat_index)
    repeat_index = 1;
end
if nargin < 4 || isempty(case_id)
    error('hexapod_compare_report:MissingCaseId', '必须提供 case_id。');
end
if nargin < 3 || isempty(compare_group_id)
    error('hexapod_compare_report:MissingGroupId', '必须提供 compare_group_id。');
end

scene_info = hexapod_scene_info(scene_name);
group_root = fullfile(project_root, 'log', scene_info.scene_name, compare_group_id);
case_root = fullfile(group_root, case_id);
if ~exist(case_root, 'dir')
    mkdir(case_root);
end

run_id = sprintf('run_%02d_%s', repeat_index, datestr(now, 'yyyymmdd_HHMMSS'));
run_output_dir = fullfile(case_root, run_id);
suffix_id = 1;
while exist(run_output_dir, 'dir')
    run_output_dir = fullfile(case_root, sprintf('%s_%02d', run_id, suffix_id));
    suffix_id = suffix_id + 1;
end
mkdir(run_output_dir);
end

function summary = collect_compare_metrics(log_root, options)
if nargin < 1 || isempty(log_root)
    project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    log_root = fullfile(project_root, 'log');
end
if nargin < 2 || isempty(options)
    options = struct();
end

metric_files = dir(fullfile(log_root, '**', 'metrics.mat'));
rows = cell(0, 1);
for idx = 1:numel(metric_files)
    data = load(fullfile(metric_files(idx).folder, metric_files(idx).name), 'metrics');
    if ~isfield(data, 'metrics')
        continue;
    end
    metrics = data.metrics;
    if ~matches_filters(metrics, options)
        continue;
    end
    rows{end + 1, 1} = flatten_metrics(metrics, metric_files(idx)); %#ok<AGROW>
end

run_table = rows_to_table(rows);
if ~isempty(run_table)
    run_table = sortrows(run_table, {'scene_name', 'case_id', 'run_sort_key', 'repeat_index'});
end
latest_table = pick_latest_runs(run_table, get_option(options, 'max_runs_per_case', 3));
aggregate_table = aggregate_latest_runs(latest_table);

output_root = get_output_root(log_root, options, latest_table);
latest_csv = fullfile(output_root, 'compare_latest3_index.csv');
aggregate_csv = fullfile(output_root, 'compare_aggregate_latest3.csv');
summary_md = fullfile(output_root, 'compare_latest3_summary.md');
run_csv = fullfile(output_root, 'compare_run_index.csv');

if ~exist(output_root, 'dir')
    mkdir(output_root);
end
writetable(run_table, run_csv);
writetable(latest_table, latest_csv);
writetable(aggregate_table, aggregate_csv);
write_summary_md(summary_md, latest_table, aggregate_table, get_option(options, 'compare_group_id', ''));

summary = struct();
summary.run_table = run_table;
summary.latest_table = latest_table;
summary.aggregate_table = aggregate_table;
summary.output_root = output_root;
summary.run_csv = run_csv;
summary.latest_csv = latest_csv;
summary.aggregate_csv = aggregate_csv;
summary.summary_md = summary_md;
end

function tf = matches_filters(metrics, options)
meta = get_struct_field(metrics, 'meta', struct());
compare_group_id = string(get_option(options, 'compare_group_id', ''));
scene_name = string(get_option(options, 'scene_name', ''));
case_id = string(get_option(options, 'case_id', ''));

tf = true;
if strlength(compare_group_id) > 0
    tf = tf && string(get_struct_field(meta, 'compare_group_id', '')) == compare_group_id;
end
if strlength(scene_name) > 0
    tf = tf && string(get_struct_field(meta, 'scene_name', '')) == scene_name;
end
if strlength(case_id) > 0
    tf = tf && string(get_struct_field(meta, 'case_id', get_struct_field(meta, 'source_flow', ''))) == case_id;
end
end

function row = flatten_metrics(metrics, file_info)
meta = get_struct_field(metrics, 'meta', struct());
row = struct();
row.scene_name = string(get_struct_field(meta, 'scene_name', ''));
row.scene_variant = string(get_struct_field(meta, 'scene_variant', ''));
row.scene_label = string(get_struct_field(meta, 'scene_label', ''));
row.source_flow = string(get_struct_field(meta, 'source_flow', ''));
row.entry_pattern = string(get_struct_field(meta, 'entry_pattern', ''));
row.case_id = string(get_struct_field(meta, 'case_id', get_struct_field(meta, 'source_flow', '')));
row.case_description = string(get_struct_field(meta, 'case_description', ''));
row.compare_group_id = string(get_struct_field(meta, 'compare_group_id', ''));
row.run_timestamp = string(get_struct_field(meta, 'run_timestamp', ''));
row.output_dir = string(get_struct_field(meta, 'output_dir', file_info.folder));
row.source_artifact_path = string(get_struct_field(meta, 'source_artifact_path', ''));
row.frame_normalization = string(get_struct_field(meta, 'frame_normalization', ''));
row.coppeliasim_exe_path = string(get_struct_field(meta, 'coppeliasim_exe_path', ''));
row.coppeliasim_scene_path = string(get_struct_field(meta, 'coppeliasim_scene_path', ''));
row.coppeliasim_host = string(get_struct_field(meta, 'coppeliasim_host', ''));
row.coppeliasim_port = to_double(get_struct_field(meta, 'coppeliasim_port', NaN));
row.coppeliasim_auto_restart = to_double(get_struct_field(meta, 'coppeliasim_auto_restart', NaN));
row.coppeliasim_restart_performed = to_double(get_struct_field(meta, 'coppeliasim_restart_performed', NaN));
row.coppeliasim_startup_wait_sec = to_double(get_struct_field(meta, 'coppeliasim_startup_wait_sec', NaN));
row.coppeliasim_shutdown_wait_sec = to_double(get_struct_field(meta, 'coppeliasim_shutdown_wait_sec', NaN));
row.coppeliasim_launch_timestamp = string(get_struct_field(meta, 'coppeliasim_launch_timestamp', ''));
row.repeat_index = to_double(get_struct_field(meta, 'repeat_index', NaN));
row.target_total_frames = to_double(get_struct_field(meta, 'target_total_frames', NaN));
row.natural_total_frames = to_double(get_struct_field(meta, 'natural_total_frames', NaN));
row.actual_total_frames = to_double(get_struct_field(meta, 'actual_total_frames', get_struct_field(meta, 'sample_count', NaN)));
row.sample_count = to_double(get_struct_field(meta, 'sample_count', NaN));
row.run_sort_key = parse_sort_key(row.run_timestamp, file_info.datenum);
row.file_datenum = file_info.datenum;
row = attach_scalar_fields(row, get_struct_field(metrics, 'common', struct()), 'common_');
row = attach_scalar_fields(row, get_struct_field(metrics, 'scene', struct()), 'scene_');
end

function row = attach_scalar_fields(row, values, prefix)
if ~isstruct(values)
    return;
end
fields = fieldnames(values);
for idx = 1:numel(fields)
    field_name = fields{idx};
    field_value = values.(field_name);
    if isnumeric(field_value) && isscalar(field_value)
        row.([prefix, field_name]) = double(field_value);
    end
end
end

function table_out = rows_to_table(rows)
if isempty(rows)
    table_out = table();
    return;
end

all_fields = string.empty(1, 0);
for idx = 1:numel(rows)
    all_fields = union(all_fields, string(fieldnames(rows{idx})), 'stable');
end

prototype = struct();
for field_idx = 1:numel(all_fields)
    field_name = char(all_fields(field_idx));
    prototype.(field_name) = infer_default_value(rows, field_name);
end

normalized = repmat(prototype, numel(rows), 1);
for idx = 1:numel(rows)
    item = rows{idx};
    item_fields = fieldnames(item);
    for field_idx = 1:numel(item_fields)
        field_name = item_fields{field_idx};
        normalized(idx).(field_name) = item.(field_name);
    end
end

table_out = struct2table(normalized);
end

function default_value = infer_default_value(rows, field_name)
default_value = NaN;
for idx = 1:numel(rows)
    item = rows{idx};
    if isfield(item, field_name)
        value = item.(field_name);
        if isstring(value)
            default_value = string(missing);
        elseif ischar(value)
            default_value = '';
        elseif isnumeric(value)
            default_value = NaN;
        else
            default_value = [];
        end
        return;
    end
end
end

function latest_table = pick_latest_runs(run_table, max_runs_per_case)
if isempty(run_table)
    latest_table = run_table;
    return;
end
case_ids = unique(run_table.case_id, 'stable');
latest_table = run_table([],:);
for idx = 1:numel(case_ids)
    case_mask = run_table.case_id == case_ids(idx);
    case_rows = run_table(case_mask, :);
    if height(case_rows) > max_runs_per_case
        case_rows = case_rows(end - max_runs_per_case + 1:end, :);
    end
    latest_table = [latest_table; case_rows]; %#ok<AGROW>
end
end

function aggregate_table = aggregate_latest_runs(latest_table)
if isempty(latest_table)
    aggregate_table = table();
    return;
end

numeric_mask = varfun(@isnumeric, latest_table, 'OutputFormat', 'uniform');
numeric_names = latest_table.Properties.VariableNames(numeric_mask);
exclude_names = {'run_sort_key', 'file_datenum', 'repeat_index'};
numeric_names = setdiff(numeric_names, exclude_names, 'stable');
case_ids = unique(latest_table.case_id, 'stable');
rows = cell(0, 1);
for idx = 1:numel(case_ids)
    case_mask = latest_table.case_id == case_ids(idx);
    case_rows = latest_table(case_mask, :);
    row = struct();
    row.scene_name = case_rows.scene_name(1);
    row.scene_label = case_rows.scene_label(1);
    row.scene_variant = case_rows.scene_variant(1);
    row.case_id = case_rows.case_id(1);
    row.case_description = case_rows.case_description(1);
    row.compare_group_id = case_rows.compare_group_id(1);
    row.run_count = height(case_rows);
    for name_idx = 1:numel(numeric_names)
        var_name = numeric_names{name_idx};
        values = case_rows.(var_name);
        row.([var_name, '_mean']) = mean(values, 'omitnan');
        row.([var_name, '_std']) = std(values, 0, 'omitnan');
        row.([var_name, '_min']) = min(values, [], 'omitnan');
        row.([var_name, '_max']) = max(values, [], 'omitnan');
    end
    rows{end + 1, 1} = row; %#ok<AGROW>
end
aggregate_table = rows_to_table(rows);
end

function output_root = get_output_root(log_root, options, latest_table)
output_root = get_option(options, 'output_root', '');
if ~isempty(output_root)
    return;
end
compare_group_id = get_option(options, 'compare_group_id', '');
if ~isempty(compare_group_id)
    output_root = fullfile(log_root, compare_group_id);
else
    output_root = log_root;
end
if ~isempty(latest_table) && ~isempty(compare_group_id)
    scene_names = unique(latest_table.scene_name);
    if numel(scene_names) == 1 && ~contains(output_root, char(scene_names(1)))
        output_root = fullfile(log_root, compare_group_id);
    end
end
end

function write_summary_md(md_path, latest_table, aggregate_table, compare_group_id)
fid = fopen(md_path, 'w', 'n', 'UTF-8');
if fid == -1
    warning('hexapod_compare_report:WriteFailed', '无法写入摘要文件: %s', md_path);
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# Hexapod Compare Summary\n\n');
if ~isempty(compare_group_id)
    fprintf(fid, '- 实验组: `%s`\n', compare_group_id);
end
fprintf(fid, '- 最新三次索引行数: `%d`\n', height(latest_table));
fprintf(fid, '- 聚合 case 数量: `%d`\n\n', height(aggregate_table));

if isempty(aggregate_table)
    fprintf(fid, '未找到符合条件的指标文件。\n');
    return;
end

fprintf(fid, '## 聚合概览\n\n');
for idx = 1:height(aggregate_table)
    fprintf(fid, '- `%s`: `%s`，run_count=%d\n', ...
        aggregate_table.case_id(idx), aggregate_table.case_description(idx), aggregate_table.run_count(idx));
end
end

function value = get_option(options, field_name, default_value)
if isstruct(options) && isfield(options, field_name)
    value = options.(field_name);
else
    value = default_value;
end
end

function value = get_struct_field(s, field_name, default_value)
if isstruct(s) && isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end

function value = to_double(value)
if isempty(value)
    value = NaN;
elseif isnumeric(value)
    value = double(value);
else
    value = double(str2double(string(value)));
end
end

function sort_key = parse_sort_key(run_timestamp, fallback_datenum)
run_timestamp = char(run_timestamp);
try
    sort_key = datenum(run_timestamp, 'yyyy-mm-dd HH:MM:SS');
catch
    sort_key = fallback_datenum;
end
if isempty(sort_key) || isnan(sort_key)
    sort_key = fallback_datenum;
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
