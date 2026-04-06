function outputs = hexapod_plot_midterm_step(compare_root, output_dir)
% 生成中期报告高台场景图表与配套文字
% - 图1：高台场景机身轨迹与机身高度变化
% - 图2：高台场景关键指标对比

if nargin < 1 || isempty(compare_root)
    project_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    compare_root = fullfile(project_root, 'log', 'step', 'compare_user_step_repeat3_20260401_fixbaseline');
end
if nargin < 2 || isempty(output_dir)
    output_dir = fullfile(compare_root, 'midterm_assets');
end
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

cleanup_old_outputs(output_dir);

aggregate_csv = fullfile(compare_root, 'compare_aggregate_latest3.csv');
if exist(aggregate_csv, 'file') ~= 2
    error('hexapod_plot_midterm_step:MissingAggregateCsv', ...
        '未找到聚合指标文件: %s', aggregate_csv);
end

baseline_runs = load_case_runs(fullfile(compare_root, 'step_initial'));
current_runs = load_case_runs(fullfile(compare_root, 'step_current'));
baseline_stats = baseline_runs.summary;
current_stats = current_runs.summary;

font_name = pick_font_name();
colors = struct( ...
    'baseline', [0.45, 0.45, 0.45], ...
    'baseline_light', [0.80, 0.80, 0.80], ...
    'current', [0.85, 0.33, 0.10], ...
    'current_light', [0.98, 0.82, 0.72], ...
    'guide', [0.15, 0.15, 0.15], ...
    'shade', [0.95, 0.95, 0.95]);

figure1_png = fullfile(output_dir, 'figure1_step_trajectory_comparison.png');
figure1_fig = fullfile(output_dir, 'figure1_step_trajectory_comparison.fig');
export_transition_figure(figure1_png, figure1_fig, baseline_runs, current_runs, font_name, colors);

figure2_png = fullfile(output_dir, 'figure2_step_key_metrics.png');
figure2_fig = fullfile(output_dir, 'figure2_step_key_metrics.fig');
export_metric_grid_figure(figure2_png, figure2_fig, baseline_stats, current_stats, ...
    { ...
    struct('label', '通过距离', 'field', 'scene_step_crossing_distance_m_mean', 'unit', 'm', 'decimals', 3); ...
    struct('label', '总受力均方根', 'field', 'common_total_force_rms_N_mean', 'unit', 'N', 'decimals', 0); ...
    struct('label', '垂向平滑指标', 'field', 'scene_vertical_smoothness_idx_mean', 'unit', '', 'display_unit', '×10^-5', 'scale', 1e5, 'decimals', 2); ...
    struct('label', '阶段俯仰峰值', 'field', 'scene_step_stage_pitch_peak_deg_mean', 'unit', '°', 'decimals', 3) ...
    }, ...
    [2, 2], font_name, colors);

section_md = fullfile(output_dir, 'section_1_2_2_step_revised.md');
write_section_markdown(section_md, baseline_stats, current_stats);

outputs = struct();
outputs.compare_root = compare_root;
outputs.output_dir = output_dir;
outputs.figure1_png = figure1_png;
outputs.figure2_png = figure2_png;
outputs.section_md = section_md;

disp('已生成中期报告高台场景图表与配套文字：');
disp(outputs);
end

function cleanup_old_outputs(output_dir)
obsolete_names = { ...
    'figure1_step_trajectory_transition.png', ...
    'figure1_step_trajectory_transition.fig', ...
    'figure2_step_metric_improvements.png', ...
    'figure2_step_metric_improvements.fig', ...
    'table1_step_key_metrics.png', ...
    'table1_step_key_metrics.csv', ...
    'table1_step_key_metrics.md'};

for idx = 1:numel(obsolete_names)
    target = fullfile(output_dir, obsolete_names{idx});
    if exist(target, 'file') == 2
        delete(target);
    end
end
end

function run_data = load_case_runs(case_dir)
metric_files = dir(fullfile(case_dir, 'run_*', 'metrics.mat'));
if isempty(metric_files)
    error('hexapod_plot_midterm_step:MissingMetrics', '未找到指标文件目录: %s', case_dir);
end

time_runs = cell(numel(metric_files), 1);
x_runs = cell(numel(metric_files), 1);
z_runs = cell(numel(metric_files), 1);
crossing_runs = nan(numel(metric_files), 1);
force_rms_runs = nan(numel(metric_files), 1);
vertical_smoothness_runs = nan(numel(metric_files), 1);
stage_pitch_runs = nan(numel(metric_files), 1);
x_origin_runs = nan(numel(metric_files), 1);

for idx = 1:numel(metric_files)
    data = load(fullfile(metric_files(idx).folder, metric_files(idx).name), 'metrics');
    metrics = data.metrics;

    time_vec = metrics.series.time_s(:)';
    x_vec = metrics.series.realX(:)';
    z_vec = metrics.series.realZ(:)';
    force_vec = metrics.series.total_force_N(:)';
    [time_vec, x_vec, z_vec, x_origin] = trim_leading_placeholder(time_vec, x_vec, z_vec);
    force_vec = force_vec(end - numel(x_vec) + 1:end);
    x_origin_runs(idx) = x_origin;

    crossing_runs(idx) = get_nested_metric(metrics, {'scene', 'step_crossing_distance_m'}, x_vec(end) - x_vec(1));
    force_rms_runs(idx) = get_nested_metric(metrics, {'common', 'total_force_rms_N'}, sqrt(mean(force_vec .^ 2)));
    vertical_smoothness_runs(idx) = get_nested_metric(metrics, {'scene', 'vertical_smoothness_idx'}, NaN);
    stage_pitch_runs(idx) = get_nested_metric(metrics, {'scene', 'step_stage_pitch_peak_deg'}, NaN);

    time_runs{idx} = time_vec;
    x_runs{idx} = x_vec;
    z_runs{idx} = z_vec;
end

[time_mat, x_mat, z_mat] = align_run_series(time_runs, x_runs, z_runs);

run_data = struct();
run_data.time_mean = mean(time_mat, 1, 'omitnan');
run_data.x_mean = mean(x_mat, 1, 'omitnan');
run_data.z_mean = mean(z_mat, 1, 'omitnan');
run_data.z_std = std(z_mat, 0, 1, 'omitnan');
run_data.x_max = max(x_mat, [], 'all', 'omitnan');
run_data.z_max = max(z_mat, [], 'all', 'omitnan');
run_data.x_min = min(x_mat, [], 'all', 'omitnan');
run_data.z_min = min(z_mat, [], 'all', 'omitnan');
run_data.x_origin_mean = mean(x_origin_runs, 'omitnan');
run_data.summary = struct( ...
    'scene_step_crossing_distance_m_mean', mean(crossing_runs, 'omitnan'), ...
    'common_total_force_rms_N_mean', mean(force_rms_runs, 'omitnan'), ...
    'scene_vertical_smoothness_idx_mean', mean(vertical_smoothness_runs, 'omitnan'), ...
    'scene_step_stage_pitch_peak_deg_mean', mean(stage_pitch_runs, 'omitnan'));
end

function font_name = pick_font_name()
font_name = 'Microsoft YaHei';
try
    font_list = listfonts;
    candidates = {'Microsoft YaHei', 'SimHei', 'Arial Unicode MS'};
    for idx = 1:numel(candidates)
        if any(strcmpi(font_list, candidates{idx}))
            font_name = candidates{idx};
            return;
        end
    end
catch
end
end

function export_transition_figure(png_path, fig_path, baseline_runs, current_runs, font_name, colors)
fig = figure('Color', 'w', 'Position', [120, 80, 1100, 520], 'Visible', 'off');
t = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

step_edge_world_x = 5.975;
front_leg_offset_x = 1.75;
start_x_world = mean([baseline_runs.x_origin_mean, current_runs.x_origin_mean], 'omitnan');
front_leg_reach_edge_x = step_edge_world_x - front_leg_offset_x - start_x_world;

ax1 = nexttile(t, 1);
hold(ax1, 'on');
plot(ax1, baseline_runs.x_mean, baseline_runs.z_mean, '--', 'Color', colors.baseline, 'LineWidth', 2.0);
plot(ax1, current_runs.x_mean, current_runs.z_mean, '-', 'Color', colors.current, 'LineWidth', 2.2);
xline(ax1, front_leg_reach_edge_x, '--', '前腿到达台阶前沿', 'Color', colors.guide, 'LineWidth', 1.0, ...
    'FontName', font_name, 'FontSize', 9, 'LabelVerticalAlignment', 'bottom');
grid(ax1, 'on');
box(ax1, 'on');
xlim(ax1, [floor(min([baseline_runs.x_min, current_runs.x_min]) * 10) / 10, ceil(max([baseline_runs.x_max, current_runs.x_max]) * 10) / 10]);
ylim(ax1, [floor(min([baseline_runs.z_min, current_runs.z_min]) * 10) / 10 - 0.1, ceil(max([baseline_runs.z_max, current_runs.z_max]) * 10) / 10 + 0.1]);
xlabel(ax1, '机身前进距离 x / m', 'FontName', font_name);
ylabel(ax1, '机身质心 Z 坐标 / m', 'FontName', font_name);
title(ax1, '(a) 机身轨迹对比', 'FontWeight', 'normal', 'FontName', font_name);
legend(ax1, {'传统方案均值', '当前方案均值'}, ...
    'Location', 'northwest', 'Box', 'off', 'FontName', font_name);
set(ax1, 'FontName', font_name, 'LineWidth', 1.0, 'FontSize', 11);

ax2 = nexttile(t, 2);
hold(ax2, 'on');
plot(ax2, baseline_runs.time_mean, baseline_runs.z_mean, '--', 'Color', colors.baseline, 'LineWidth', 2.0);
plot(ax2, current_runs.time_mean, current_runs.z_mean, '-', 'Color', colors.current, 'LineWidth', 2.2);
grid(ax2, 'on');
box(ax2, 'on');
xlim(ax2, [0, max(current_runs.time_mean, [], 'omitnan')]);
ylim(ax2, [floor(min([baseline_runs.z_min, current_runs.z_min]) * 10) / 10 - 0.1, ceil(max([baseline_runs.z_max, current_runs.z_max]) * 10) / 10 + 0.1]);
xlabel(ax2, '时间 / s', 'FontName', font_name);
ylabel(ax2, '机身质心 Z 坐标 / m', 'FontName', font_name);
title(ax2, '(b) 机身高度变化对比', 'FontWeight', 'normal', 'FontName', font_name);
legend(ax2, {'传统方案均值', '当前方案均值'}, ...
    'Location', 'southeast', 'Box', 'off', 'FontName', font_name);
set(ax2, 'FontName', font_name, 'LineWidth', 1.0, 'FontSize', 11);

exportgraphics(fig, png_path, 'Resolution', 320);
savefig(fig, fig_path);
close(fig);
end

function export_metric_grid_figure(png_path, fig_path, baseline_row, current_row, metric_defs, grid_shape, font_name, colors)
fig = figure('Color', 'w', 'Position', [120, 100, 1020, 640], 'Visible', 'off');
t = tiledlayout(fig, grid_shape(1), grid_shape(2), 'TileSpacing', 'compact', 'Padding', 'compact');

for idx = 1:(grid_shape(1) * grid_shape(2))
    ax = nexttile(t, idx);
    if idx > numel(metric_defs)
        axis(ax, 'off');
        continue;
    end

    def = metric_defs{idx};
    hold(ax, 'on');
    scale = get_metric_option(def, 'scale', 1);
    base_val = baseline_row.(def.field) * scale;
    cur_val = current_row.(def.field) * scale;
    bar(ax, 1, base_val, 0.55, 'FaceColor', colors.baseline, 'EdgeColor', 'none');
    bar(ax, 2, cur_val, 0.55, 'FaceColor', colors.current, 'EdgeColor', 'none');
    set(ax, 'XTick', [1, 2], 'XTickLabel', {'传统方案', '当前方案'}, ...
        'FontName', font_name, 'LineWidth', 1.0, 'FontSize', 10);
    grid(ax, 'on');
    box(ax, 'on');
    ylabel(ax, build_y_label(def), 'FontName', font_name);
    title(ax, def.label, 'FontWeight', 'normal', 'FontName', font_name);

    y_min = min([base_val, cur_val, 0]);
    y_max = max([base_val, cur_val, 0]);
    y_pad = max((y_max - y_min) * 0.15, 0.05 * max(abs([base_val, cur_val, 1])));
    lower_lim = y_min - y_pad;
    upper_lim = y_max + y_pad;
    if y_min >= 0
        lower_lim = 0;
    elseif y_max <= 0
        upper_lim = 0;
    end
    ylim(ax, [lower_lim, upper_lim]);
    text(ax, 1, base_val + sign_with_default(base_val) * y_pad * 0.25, format_metric_value(base_val, def), ...
        'HorizontalAlignment', 'center', 'FontName', font_name, 'FontSize', 10);
    text(ax, 2, cur_val + sign_with_default(cur_val) * y_pad * 0.25, format_metric_value(cur_val, def), ...
        'HorizontalAlignment', 'center', 'FontName', font_name, 'FontSize', 10);
end

exportgraphics(fig, png_path, 'Resolution', 320);
savefig(fig, fig_path);
close(fig);
end

function label_text = build_y_label(def)
unit_name = get_metric_option(def, 'display_unit', def.unit);
if isempty(unit_name)
    label_text = '指标值';
else
    label_text = sprintf('指标值 / %s', unit_name);
end
end

function text_value = format_metric_value(value, def)
decimals = get_metric_option(def, 'decimals', 3);
text_value = sprintf(sprintf('%%.%df', decimals), value);
end

function write_section_markdown(md_path, baseline_row, current_row)
crossing_pct = percent_change(current_row.scene_step_crossing_distance_m_mean, baseline_row.scene_step_crossing_distance_m_mean);
force_pct = percent_drop(current_row.common_total_force_rms_N_mean, baseline_row.common_total_force_rms_N_mean);
vertical_smoothness_pct = percent_drop(current_row.scene_vertical_smoothness_idx_mean, baseline_row.scene_vertical_smoothness_idx_mean);
pitch_pct = percent_drop(current_row.scene_step_stage_pitch_peak_deg_mean, baseline_row.scene_step_stage_pitch_peak_deg_mean);

fid = fopen(md_path, 'w', 'n', 'UTF-8');
if fid == -1
    error('hexapod_plot_midterm_step:WriteMarkdownFailed', '无法写入正文草稿文件: %s', md_path);
end
cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '1.2.2 0.5 m高台场景结果分析\n\n');
fprintf(fid, '高台场景下，传统方案主要依赖阈值切换完成高度补偿。根据本次修正后的对比结果，旧方案虽然能够完成上台，但越台阶段的机身高度调整较为零散，接近台阶前沿以及后腿跟进阶段更容易出现局部突变，进而带来较明显的姿态波动。\n\n');
fprintf(fid, '针对这一问题，当前方案对越台阶段的机体高度调节进行了重新组织。具体做法是将机体整体抬升改为连续平滑过渡，利用 3p^2-2p^3 函数控制上抬过程，并适当后移抬升峰值；同时将最高底盘高度由 0.5 m 下调至 0.4 m，以减轻后腿悬空和机体前倾。\n\n');
fprintf(fid, '【图X 此处插入：高台场景下传统方案与当前方案的质心轨迹对比】\n\n');
fprintf(fid, '从图X可以看出，两种方案在越台阶段的质心高度变化存在明显差别。传统方案曲线在接近台阶前沿以及后续跟进阶段出现多次斜率变化，说明机体抬升与足端动作之间的衔接不够稳定。相比之下，当前方案在中段抬升区间的曲线更连续，过渡也更缓，这与平滑抬升曲线和抬升峰值后移的设计是一致的。抬升峰值降低后，越台后段的平台段波动也有所减弱，说明机体姿态调整更协调。\n\n');
fprintf(fid, '【图Y 此处插入：高台场景下传统方案与当前方案关键指标对比】\n\n');
fprintf(fid, '如图Y所示，当前方案的通过距离由 %.3f m 提高到 %.3f m，提高了 %.1f%%；总受力均方根由 %.0f N 下降到 %.0f N，下降了 %.1f%%，说明机器人在完成越台动作后还能保持更长的稳定前进距离，接触过程中的整体冲击也有所减小。\n\n', ...
        baseline_row.scene_step_crossing_distance_m_mean, current_row.scene_step_crossing_distance_m_mean, crossing_pct, ...
        baseline_row.common_total_force_rms_N_mean, current_row.common_total_force_rms_N_mean, force_pct);
fprintf(fid, '为进一步描述越台过程中的稳定性，本文引入了垂向平滑指标和阶段俯仰峰值。垂向平滑指标由 %.2e 降到 %.2e，下降了 %.1f%%。该指标越小，说明质心高度变化越平顺，能够反映平滑抬升曲线和峰值后移后的效果。阶段俯仰峰值由 %.3f° 降到 %.3f°，下降了 %.1f%%。该指标越小，说明越台阶段前后俯仰扰动越小，也表明在最高底盘高度下调到 0.4 m 后，机体姿态控制更加稳定。\n\n', ...
        baseline_row.scene_vertical_smoothness_idx_mean, current_row.scene_vertical_smoothness_idx_mean, vertical_smoothness_pct, ...
        baseline_row.scene_step_stage_pitch_peak_deg_mean, current_row.scene_step_stage_pitch_peak_deg_mean, pitch_pct);
fprintf(fid, '总体来看，当前方案的优化重点不在于单纯提高机身抬升幅度，而在于协调抬升节奏、姿态变化与接触受力。按这组修正后的结果，高台场景下的改进主要体现在越台过程更平顺，姿态控制也更稳定。\n');
end

function [time_mat, x_mat, z_mat] = align_run_series(time_runs, x_runs, z_runs)
max_len = max(cellfun(@numel, time_runs));
run_count = numel(time_runs);
time_mat = nan(run_count, max_len);
x_mat = nan(run_count, max_len);
z_mat = nan(run_count, max_len);

for idx = 1:run_count
    cur_len = numel(time_runs{idx});
    time_mat(idx, 1:cur_len) = time_runs{idx};
    x_mat(idx, 1:cur_len) = x_runs{idx};
    z_mat(idx, 1:cur_len) = z_runs{idx};
end
end

function [time_vec, x_vec, z_vec, x_origin] = trim_leading_placeholder(time_vec, x_vec, z_vec)
valid_start = find(abs(x_vec) > 1e-6 | abs(z_vec) > 1e-6, 1, 'first');
if isempty(valid_start)
    valid_start = 1;
end
time_offset = time_vec(valid_start);
x_origin = x_vec(valid_start);
time_vec = time_vec(valid_start:end) - time_offset;
x_vec = x_vec(valid_start:end) - x_origin;
z_vec = z_vec(valid_start:end);
end

function s = sign_with_default(value)
if value < 0
    s = -1;
else
    s = 1;
end
end

function value = get_nested_metric(source_struct, path_parts, fallback)
value = fallback;
cursor = source_struct;
for idx = 1:numel(path_parts)
    field_name = path_parts{idx};
    if ~isstruct(cursor) || ~isfield(cursor, field_name)
        return;
    end
    cursor = cursor.(field_name);
end

if isnumeric(cursor) && isscalar(cursor)
    value = cursor;
end
end

function value = get_metric_option(def, field_name, default_value)
if isfield(def, field_name)
    value = def.(field_name);
else
    value = default_value;
end
end

function value = percent_change(current_value, baseline_value)
value = (current_value - baseline_value) / baseline_value * 100;
end

function value = percent_drop(current_value, baseline_value)
value = (baseline_value - current_value) / baseline_value * 100;
end
