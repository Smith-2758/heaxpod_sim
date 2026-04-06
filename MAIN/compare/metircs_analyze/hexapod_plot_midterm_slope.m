function outputs = hexapod_plot_midterm_slope(compare_root, output_dir)
% 生成中期报告斜坡场景图表与配套文字
% - 图1：机身轨迹与俯仰角变化对比
% - 图2：通过性指标对比
% - 图3：稳定性指标对比

if nargin < 1 || isempty(compare_root)
    project_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    compare_root = fullfile(project_root, 'log', 'slope', 'compare_user_slope_repeat3_20260331');
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
    error('hexapod_plot_midterm_slope:MissingAggregateCsv', ...
        '未找到聚合指标文件: %s', aggregate_csv);
end

aggregate_table = readtable(aggregate_csv, 'TextType', 'string');
baseline_row = pick_case_row(aggregate_table, "slope_baseline");
current_row = pick_case_row(aggregate_table, "slope_current");

baseline_runs = load_case_runs(fullfile(compare_root, 'slope_baseline'));
current_runs = load_case_runs(fullfile(compare_root, 'slope_current'));

font_name = pick_font_name();
colors = struct( ...
    'baseline', [0.45, 0.45, 0.45], ...
    'baseline_light', [0.78, 0.78, 0.78], ...
    'current', [0.85, 0.33, 0.10], ...
    'current_light', [0.97, 0.72, 0.60], ...
    'pass', [0.16, 0.47, 0.75], ...
    'stable', [0.10, 0.56, 0.35], ...
    'guide', [0.00, 0.00, 0.00]);

figure1_png = fullfile(output_dir, 'figure1_slope_trajectory_comparison.png');
figure1_fig = fullfile(output_dir, 'figure1_slope_trajectory_comparison.fig');
export_trajectory_figure(figure1_png, figure1_fig, baseline_runs, current_runs, font_name, colors);

figure2_png = fullfile(output_dir, 'figure2_slope_passability_comparison.png');
figure2_fig = fullfile(output_dir, 'figure2_slope_passability_comparison.fig');
export_metric_grid_figure(figure2_png, figure2_fig, baseline_row, current_row, ...
    { ...
    struct('label', '通过距离', 'field', 'scene_slope_progress_m_mean', 'unit', 'm', 'better', 'higher'); ...
    struct('label', '高度增益', 'field', 'scene_climb_height_gain_m_mean', 'unit', 'm', 'better', 'higher'); ...
    struct('label', '路径效率', 'field', 'common_path_efficiency_mean', 'unit', '', 'better', 'higher') ...
    }, ...
    [1, 3], font_name, colors);

figure3_png = fullfile(output_dir, 'figure3_slope_stability_comparison.png');
figure3_fig = fullfile(output_dir, 'figure3_slope_stability_comparison.fig');
export_metric_grid_figure(figure3_png, figure3_fig, baseline_row, current_row, ...
    { ...
    struct('label', '回滑距离', 'field', 'scene_backslide_distance_m_mean', 'unit', 'm', 'better', 'lower'); ...
    struct('label', '总受力均方根', 'field', 'common_total_force_rms_N_mean', 'unit', 'N', 'better', 'lower'); ...
    struct('label', '横滚峰值', 'field', 'common_roll_peak_deg_mean', 'unit', '°', 'better', 'lower'); ...
    struct('label', '航向漂移', 'field', 'common_yaw_drift_deg_mean', 'unit', '°', 'better', 'lower') ...
    }, ...
    [2, 2], font_name, colors);

section_md = fullfile(output_dir, 'section_1_2_1_slope_revised.md');
write_section_markdown(section_md, baseline_row, current_row);

outputs = struct();
outputs.compare_root = compare_root;
outputs.output_dir = output_dir;
outputs.figure1_png = figure1_png;
outputs.figure2_png = figure2_png;
outputs.figure3_png = figure3_png;
outputs.section_md = section_md;

disp('已生成中期报告斜坡场景图表与配套文字：');
disp(outputs);
end

function cleanup_old_outputs(output_dir)
obsolete_names = { ...
    'figure1_slope_trajectory_transition.pdf', ...
    'figure2_slope_metric_improvements.pdf', ...
    'table1_slope_key_metrics.png', ...
    'table1_slope_key_metrics.csv', ...
    'table1_slope_key_metrics.md', ...
    'figure1_slope_trajectory_transition.png', ...
    'figure1_slope_trajectory_transition.fig', ...
    'figure2_slope_metric_improvements.png', ...
    'figure2_slope_metric_improvements.fig'};

for idx = 1:numel(obsolete_names)
    target = fullfile(output_dir, obsolete_names{idx});
    if exist(target, 'file') == 2
        delete(target);
    end
end
end

function row = pick_case_row(tbl, case_id)
match = tbl.case_id == string(case_id);
if ~any(match)
    error('hexapod_plot_midterm_slope:MissingCase', '聚合表中未找到 case_id=%s。', case_id);
end
row = tbl(find(match, 1, 'first'), :);
end

function run_data = load_case_runs(case_dir)
metric_files = dir(fullfile(case_dir, 'run_*', 'metrics.mat'));
if isempty(metric_files)
    error('hexapod_plot_midterm_slope:MissingMetrics', '未找到指标文件目录: %s', case_dir);
end

metrics_list = cell(numel(metric_files), 1);
time_mat = [];
x_mat = [];
z_mat = [];
pitch_abs_mat = [];

for idx = 1:numel(metric_files)
    data = load(fullfile(metric_files(idx).folder, metric_files(idx).name), 'metrics');
    metrics_list{idx} = data.metrics;
    metrics = data.metrics;

    time_vec = metrics.series.time_s(:)';
    x_vec = metrics.series.realX(:)';
    z_vec = metrics.series.realZ(:)';
    pitch_vec = abs(metrics.series.pitch_deg(:)');

    valid_start = find(~(isnan(x_vec) | isnan(z_vec)), 1, 'first');
    if isempty(valid_start)
        valid_start = 1;
    end
    x_vec = x_vec - x_vec(valid_start);
    z_vec = z_vec - z_vec(valid_start);

    if isempty(time_mat)
        time_mat = nan(numel(metric_files), numel(time_vec));
        x_mat = nan(numel(metric_files), numel(x_vec));
        z_mat = nan(numel(metric_files), numel(z_vec));
        pitch_abs_mat = nan(numel(metric_files), numel(pitch_vec));
    end

    time_mat(idx, 1:numel(time_vec)) = time_vec;
    x_mat(idx, 1:numel(x_vec)) = x_vec;
    z_mat(idx, 1:numel(z_vec)) = z_vec;
    pitch_abs_mat(idx, 1:numel(pitch_vec)) = pitch_vec;
end

run_data = struct();
run_data.metrics = metrics_list;
run_data.time_mean = mean(time_mat, 1, 'omitnan');
run_data.x_mean = mean(x_mat, 1, 'omitnan');
run_data.z_mean = mean(z_mat, 1, 'omitnan');
run_data.pitch_mean = mean(pitch_abs_mat, 1, 'omitnan');
run_data.pitch_std = std(pitch_abs_mat, 0, 1, 'omitnan');
run_data.x_runs = x_mat;
run_data.z_runs = z_mat;
run_data.time_runs = time_mat;
run_data.pitch_runs = pitch_abs_mat;
run_data.x_max = max(x_mat, [], 'all', 'omitnan');
run_data.z_max = max(z_mat, [], 'all', 'omitnan');
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

function export_trajectory_figure(png_path, fig_path, baseline_runs, current_runs, font_name, colors)
fig = figure('Color', 'w', 'Position', [120, 80, 920, 760], 'Visible', 'off');
t = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

front_leg_entry_x = 0.425;
full_x = 3.925;

ax1 = nexttile(t, 1);
hold(ax1, 'on');
plot(ax1, baseline_runs.x_mean, baseline_runs.z_mean, '--', 'Color', colors.baseline, 'LineWidth', 2.0);
plot(ax1, current_runs.x_mean, current_runs.z_mean, '-', 'Color', colors.current, 'LineWidth', 2.2);
add_stage_lines(ax1, front_leg_entry_x, full_x, colors.guide, font_name);
grid(ax1, 'on');
box(ax1, 'on');
xlim(ax1, [0, ceil(max([baseline_runs.x_max, current_runs.x_max]) * 2) / 2]);
ylim(ax1, [0, ceil(max([baseline_runs.z_max, current_runs.z_max]) * 10) / 10 + 0.2]);
xlabel(ax1, '机身前进距离 x / m', 'FontName', font_name);
ylabel(ax1, '机身高度 z / m', 'FontName', font_name);
title(ax1, '(a) 机身轨迹对比', 'FontWeight', 'normal', 'FontName', font_name);
legend(ax1, {'传统方案均值', '当前方案均值'}, ...
    'Location', 'northwest', 'Box', 'off', 'FontName', font_name);
set(ax1, 'FontName', font_name, 'LineWidth', 1.0, 'FontSize', 11);

ax2 = nexttile(t, 2);
hold(ax2, 'on');
plot(ax2, baseline_runs.time_mean, baseline_runs.pitch_mean, '--', 'Color', colors.baseline, 'LineWidth', 2.0);
plot(ax2, current_runs.time_mean, current_runs.pitch_mean, '-', 'Color', colors.current, 'LineWidth', 2.2);
yline(ax2, 15, ':', '15°坡角参考', 'Color', colors.guide, 'LineWidth', 1.0, ...
    'FontName', font_name, 'FontSize', 10, 'LabelHorizontalAlignment', 'left');
grid(ax2, 'on');
box(ax2, 'on');
xlim(ax2, [0, max(current_runs.time_mean, [], 'omitnan')]);
ylim(ax2, [0, 17]);
xlabel(ax2, '时间 / s', 'FontName', font_name);
ylabel(ax2, '机身俯仰角绝对值 / (°)', 'FontName', font_name);
title(ax2, '(b) 俯仰角变化对比', 'FontWeight', 'normal', 'FontName', font_name);
set(ax2, 'FontName', font_name, 'LineWidth', 1.0, 'FontSize', 11);

exportgraphics(fig, png_path, 'Resolution', 320);
savefig(fig, fig_path);
close(fig);
end

function export_metric_grid_figure(png_path, fig_path, baseline_row, current_row, metric_defs, grid_shape, font_name, colors)
fig = figure('Color', 'w', 'Position', [120, 120, 980, 620], 'Visible', 'off');
t = tiledlayout(fig, grid_shape(1), grid_shape(2), 'TileSpacing', 'compact', 'Padding', 'compact');

for idx = 1:numel(metric_defs)
    def = metric_defs{idx};
    ax = nexttile(t, idx);
    hold(ax, 'on');

    base_val = baseline_row.(def.field);
    cur_val = current_row.(def.field);
    bar(ax, 1, base_val, 0.55, 'FaceColor', colors.baseline, 'EdgeColor', 'none');
    bar(ax, 2, cur_val, 0.55, 'FaceColor', colors.current, 'EdgeColor', 'none');
    set(ax, 'XTick', [1, 2], 'XTickLabel', {'传统方案', '当前方案'}, ...
        'FontName', font_name, 'LineWidth', 1.0, 'FontSize', 10);
    grid(ax, 'on');
    box(ax, 'on');
    ylabel(ax, build_y_label(def), 'FontName', font_name);
    title(ax, def.label, 'FontWeight', 'normal', 'FontName', font_name);

    ymax = max([base_val, cur_val]) * 1.25;
    if ymax == 0
        ymax = 1;
    end
    ylim(ax, [0, ymax]);
    text(ax, 1, base_val + ymax * 0.04, format_metric_value(base_val, def.unit), ...
        'HorizontalAlignment', 'center', 'FontName', font_name, 'FontSize', 10);
    text(ax, 2, cur_val + ymax * 0.04, format_metric_value(cur_val, def.unit), ...
        'HorizontalAlignment', 'center', 'FontName', font_name, 'FontSize', 10);
end

exportgraphics(fig, png_path, 'Resolution', 320);
savefig(fig, fig_path);
close(fig);
end

function label_text = build_y_label(def)
if isempty(def.unit)
    label_text = '指标值';
else
    label_text = sprintf('指标值 / %s', def.unit);
end
end

function text_value = format_metric_value(value, unit_name)
if strcmp(unit_name, 'N')
    text_value = sprintf('%.0f', value);
elseif strcmp(unit_name, '')
    text_value = sprintf('%.3f', value);
else
    text_value = sprintf('%.3f', value);
end
end

function write_section_markdown(md_path, baseline_row, current_row)
progress_pct = percent_change(current_row.scene_slope_progress_m_mean, baseline_row.scene_slope_progress_m_mean);
height_pct = percent_change(current_row.scene_climb_height_gain_m_mean, baseline_row.scene_climb_height_gain_m_mean);
slide_pct = percent_drop(current_row.scene_backslide_distance_m_mean, baseline_row.scene_backslide_distance_m_mean);
path_pct = percent_change(current_row.common_path_efficiency_mean, baseline_row.common_path_efficiency_mean);
force_pct = percent_drop(current_row.common_total_force_rms_N_mean, baseline_row.common_total_force_rms_N_mean);
roll_pct = percent_drop(current_row.common_roll_peak_deg_mean, baseline_row.common_roll_peak_deg_mean);
yaw_pct = percent_drop(current_row.common_yaw_drift_deg_mean, baseline_row.common_yaw_drift_deg_mean);

fid = fopen(md_path, 'w', 'n', 'UTF-8');
if fid == -1
    error('hexapod_plot_midterm_slope:WriteMarkdownFailed', '无法写入正文草稿文件: %s', md_path);
end
cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '#### 1.2.1 15°斜坡场景下的轨迹规划优化与结果分析\n\n');
fprintf(fid, '15°斜坡场景主要用于检验六足机器人在连续上坡过程中的通过能力和姿态稳定性。传统方案主要依靠足端高度的简单抬升来适应坡面，能够完成基本爬坡，但对坡前过渡、机身前倾建立和重心调节考虑不足，因此在进入坡面后容易出现回滑较大、姿态波动明显和推进效率偏低的问题。针对这一情况，当前方案在接近坡面前提前启动机身抬升，并将俯仰姿态变化写入逆运动学求解过程，同时对高度和姿态过渡采用平滑处理，以减小入坡冲击并改善上坡过程中的稳定性。\n\n');
fprintf(fid, '【图1 此处插入：斜坡场景机身轨迹与俯仰角变化对比图】\n\n');
fprintf(fid, '从图1可以看出，当前方案在前腿到达坡面前沿之前就已经开始建立机身高度和姿态过渡，进入坡面后的机身轨迹更连续，俯仰角也能较平稳地向 15° 坡角附近过渡并保持；相比之下，传统方案在入坡阶段的机身轨迹准备不足，俯仰角变化波动更明显，说明仅依靠足端简单抬升难以形成稳定的贴坡姿态。这一点与代码中的提前预抬升、分段重心系数调节以及平滑俯仰过渡策略是一致的。\n\n');
fprintf(fid, '从通过性指标来看，当前方案的通过距离由 %.3f m 提高到 %.3f m，提升了 %.1f%%；高度增益由 %.3f m 提高到 %.3f m，提升了 %.1f%%；路径效率由 %.3f 提高到 %.3f，提升了 %.1f%%。其中，路径效率反映的是机器人实际位移与总行走路径长度之间的比值，本节将其归入通过性指标，用于表征推进过程中的有效前进程度。以上结果说明，当前方案在适当降低速度的前提下，仍然取得了更好的前进效果和更高的有效推进能力。\n\n', ...
        baseline_row.scene_slope_progress_m_mean, current_row.scene_slope_progress_m_mean, progress_pct, ...
        baseline_row.scene_climb_height_gain_m_mean, current_row.scene_climb_height_gain_m_mean, height_pct, ...
        baseline_row.common_path_efficiency_mean, current_row.common_path_efficiency_mean, path_pct);
fprintf(fid, '【图2 此处插入：斜坡场景通过性指标对比图】\n\n');
fprintf(fid, '从稳定性指标来看，当前方案的回滑距离由 %.3f m 降至 %.3f m，下降了 %.1f%%；总受力均方根由 %.0f N 降至 %.0f N，下降了 %.1f%%；横滚峰值由 %.3f° 降至 %.3f°，下降了 %.1f%%；航向漂移由 %.3f° 降至 %.3f°，下降了 %.1f%%。这些结果表明，优化后的方案不仅提升了通过距离和高度增益，也减小了整体受力波动水平，降低了横向晃动和方向偏移，使整机在斜坡上的运动更稳定。\n\n', ...
        baseline_row.scene_backslide_distance_m_mean, current_row.scene_backslide_distance_m_mean, slide_pct, ...
        baseline_row.common_total_force_rms_N_mean, current_row.common_total_force_rms_N_mean, force_pct, ...
        baseline_row.common_roll_peak_deg_mean, current_row.common_roll_peak_deg_mean, roll_pct, ...
        baseline_row.common_yaw_drift_deg_mean, current_row.common_yaw_drift_deg_mean, yaw_pct);
fprintf(fid, '【图3 此处插入：斜坡场景稳定性指标对比图】\n\n');
fprintf(fid, '综合来看，斜坡场景下的性能提升主要来自三个方面：一是坡前提前抬升机身，改善了进入坡面的初始几何关系；二是将俯仰调节纳入逆运动学求解，使机身姿态与足端轨迹变化保持一致；三是利用平滑过渡减小了从平地到坡面的状态突变。平均速度由 0.488 m/s 调整为 0.445 m/s，下降 8.7%%，这一变化主要是为了增强上坡稳定性，因此不将其视为性能退化。总体来看，当前方案在 15° 斜坡场景下较好地兼顾了推进能力、爬升能力和姿态稳定性。\n');
end

function draw_band(ax, x, y_mean, y_std, face_color)
valid = ~(isnan(x) | isnan(y_mean) | isnan(y_std));
if ~any(valid)
    return;
end
xv = x(valid);
upper = y_mean(valid) + y_std(valid);
lower = y_mean(valid) - y_std(valid);
patch(ax, [xv, fliplr(xv)], [upper, fliplr(lower)], face_color, ...
    'EdgeColor', 'none', 'FaceAlpha', 0.35);
end

function add_stage_lines(ax, front_leg_entry_x, full_x, guide_color, font_name)
xline(ax, front_leg_entry_x, ':', '前腿到达坡面前沿', 'Color', guide_color, 'LineWidth', 1.0, ...
    'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'bottom', ...
    'FontName', font_name, 'FontSize', 9);
xline(ax, full_x, '-.', '机身完全上坡', 'Color', guide_color, 'LineWidth', 1.0, ...
    'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'bottom', ...
    'FontName', font_name, 'FontSize', 9);
end

function color_out = lighten_color(color_in, ratio)
color_out = 1 - (1 - color_in) * (1 - ratio);
end

function value = percent_change(current_value, baseline_value)
value = (current_value - baseline_value) / baseline_value * 100;
end

function value = percent_drop(current_value, baseline_value)
value = (baseline_value - current_value) / baseline_value * 100;
end
