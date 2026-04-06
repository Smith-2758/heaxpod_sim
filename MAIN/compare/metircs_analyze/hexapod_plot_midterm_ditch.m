function outputs = hexapod_plot_midterm_ditch(compare_root, output_dir)
% 生成中期报告深沟场景图表与配套文字
% - 图1：三阶段过程收敛对比（X/Y位移、俯仰、航向）
% - 图2：通过性指标对比
% - 图3：稳定性指标对比

if nargin < 1 || isempty(compare_root)
    project_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    compare_root = fullfile(project_root, 'log', 'ditch', 'compare_user_ditch_repeat3_20260331');
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
    error('hexapod_plot_midterm_ditch:MissingAggregateCsv', ...
        '未找到聚合指标文件: %s', aggregate_csv);
end

aggregate_table = readtable(aggregate_csv, 'TextType', 'string');
initial_row = pick_case_row(aggregate_table, "ditch_initial");
half_row = pick_case_row(aggregate_table, "ditch_half_mid");
final_row = pick_case_row(aggregate_table, "ditch_final_replay");

initial_runs = load_case_runs(fullfile(compare_root, 'ditch_initial'));
half_runs = load_case_runs(fullfile(compare_root, 'ditch_half_mid'));
final_runs = load_case_runs(fullfile(compare_root, 'ditch_final_replay'));

font_name = pick_font_name();
colors = struct( ...
    'initial', [0.45, 0.45, 0.45], ...
    'half', [0.16, 0.47, 0.75], ...
    'final', [0.85, 0.33, 0.10], ...
    'guide', [0.15, 0.15, 0.15]);

case_rows = {initial_row, half_row, final_row};
case_labels = {'传统方案', '优化方案', '当前方案'};
case_colors = [colors.initial; colors.half; colors.final];
case_runs = {initial_runs, half_runs, final_runs};

figure1_png = fullfile(output_dir, 'figure1_ditch_process_comparison.png');
figure1_fig = fullfile(output_dir, 'figure1_ditch_process_comparison.fig');
export_process_figure(figure1_png, figure1_fig, case_runs, case_labels, case_colors, font_name, colors);

figure2_png = fullfile(output_dir, 'figure2_ditch_passability_comparison.png');
figure2_fig = fullfile(output_dir, 'figure2_ditch_passability_comparison.fig');
export_metric_grid_figure(figure2_png, figure2_fig, case_rows, case_labels, case_colors, ...
    { ...
    struct('label', '成功标志', 'field', 'common_success_flag_mean', 'unit', '', 'decimals', 0); ...
    struct('label', '通过距离', 'field', 'scene_ditch_crossing_distance_m_mean', 'unit', 'm', 'decimals', 3); ...
    struct('label', '直线净位移', 'field', 'common_net_displacement_m_mean', 'unit', 'm', 'decimals', 3); ...
    struct('label', '路径效率', 'field', 'common_path_efficiency_mean', 'unit', '', 'decimals', 3) ...
    }, ...
    [2, 2], font_name);

figure3_png = fullfile(output_dir, 'figure3_ditch_stability_comparison.png');
figure3_fig = fullfile(output_dir, 'figure3_ditch_stability_comparison.fig');
export_metric_grid_figure(figure3_png, figure3_fig, case_rows, case_labels, case_colors, ...
    { ...
    struct('label', '总受力均方根', 'field', 'common_total_force_rms_N_mean', 'unit', 'N', 'decimals', 0); ...
    struct('label', '阶段俯仰峰值', 'field', 'scene_ditch_stage_pitch_peak_deg_mean', 'unit', '°', 'decimals', 3); ...
    struct('label', '阶段横滚峰值', 'field', 'scene_ditch_stage_roll_peak_deg_mean', 'unit', '°', 'decimals', 3); ...
    struct('label', '航向漂移', 'field', 'common_yaw_drift_deg_mean', 'unit', '°', 'decimals', 3) ...
    }, ...
    [2, 2], font_name);

section_md = fullfile(output_dir, 'section_1_2_3_ditch_revised.md');
write_section_markdown(section_md, initial_row, half_row, final_row);

outputs = struct();
outputs.compare_root = compare_root;
outputs.output_dir = output_dir;
outputs.figure1_png = figure1_png;
outputs.figure2_png = figure2_png;
outputs.figure3_png = figure3_png;
outputs.section_md = section_md;

disp('已生成中期报告深沟场景图表与配套文字：');
disp(outputs);
end

function cleanup_old_outputs(output_dir)
obsolete_names = { ...
    'figure1_ditch_process_comparison.png', ...
    'figure1_ditch_process_comparison.fig', ...
    'figure2_ditch_passability_comparison.png', ...
    'figure2_ditch_passability_comparison.fig', ...
    'figure3_ditch_stability_comparison.png', ...
    'figure3_ditch_stability_comparison.fig', ...
    'section_1_2_3_ditch_revised.md'};

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
    error('hexapod_plot_midterm_ditch:MissingCase', '聚合表中未找到 case_id=%s。', case_id);
end
row = tbl(find(match, 1, 'first'), :);
end

function run_data = load_case_runs(case_dir)
metric_files = dir(fullfile(case_dir, 'run_*', 'metrics.mat'));
if isempty(metric_files)
    error('hexapod_plot_midterm_ditch:MissingMetrics', '未找到指标文件目录: %s', case_dir);
end

time_runs = cell(numel(metric_files), 1);
x_runs = cell(numel(metric_files), 1);
y_runs = cell(numel(metric_files), 1);
pitch_runs = cell(numel(metric_files), 1);
yaw_runs = cell(numel(metric_files), 1);

for idx = 1:numel(metric_files)
    data = load(fullfile(metric_files(idx).folder, metric_files(idx).name), 'metrics');
    metrics = data.metrics;

    time_vec = metrics.series.time_s(:)';
    x_vec = metrics.series.realX(:)';
    y_vec = metrics.series.realY(:)';
    pitch_vec = abs(metrics.series.pitch_deg(:)');
    yaw_vec = abs(metrics.series.yaw_deg(:)');

    [time_vec, x_vec, y_vec, pitch_vec, yaw_vec] = trim_leading_placeholder( ...
        time_vec, x_vec, y_vec, pitch_vec, yaw_vec);

    time_runs{idx} = time_vec;
    x_runs{idx} = x_vec;
    y_runs{idx} = y_vec;
    pitch_runs{idx} = pitch_vec;
    yaw_runs{idx} = yaw_vec;
end

[time_mat, x_mat, y_mat, pitch_mat, yaw_mat] = align_run_series( ...
    time_runs, x_runs, y_runs, pitch_runs, yaw_runs);

run_data = struct();
run_data.time_mean = mean(time_mat, 1, 'omitnan');
run_data.x_mean = mean(x_mat, 1, 'omitnan');
run_data.y_mean = mean(y_mat, 1, 'omitnan');
run_data.pitch_mean = mean(pitch_mat, 1, 'omitnan');
run_data.yaw_mean = mean(yaw_mat, 1, 'omitnan');
run_data.time_max = max(time_mat, [], 'all', 'omitnan');
run_data.x_max = max(x_mat, [], 'all', 'omitnan');
run_data.y_abs_max = max(abs(y_mat), [], 'all', 'omitnan');
run_data.pitch_max = max(pitch_mat, [], 'all', 'omitnan');
run_data.yaw_max = max(yaw_mat, [], 'all', 'omitnan');
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

function export_process_figure(png_path, fig_path, case_runs, case_labels, case_colors, font_name, colors)
fig = figure('Color', 'w', 'Position', [120, 80, 1080, 760], 'Visible', 'off');
t = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

max_time = max(cellfun(@(s) s.time_max, case_runs));
max_x = max(cellfun(@(s) s.x_max, case_runs));
max_y = max(cellfun(@(s) s.y_abs_max, case_runs));
max_pitch = max(cellfun(@(s) s.pitch_max, case_runs));
max_yaw = max(cellfun(@(s) s.yaw_max, case_runs));

ax1 = nexttile(t, 1);
hold(ax1, 'on');
plot_case_series(ax1, case_runs, case_labels, case_colors, 'x_mean');
grid(ax1, 'on');
box(ax1, 'on');
xlim(ax1, [0, max_time]);
ylim(ax1, [0, max(max_x * 1.08, 1)]);
xlabel(ax1, '时间 / s', 'FontName', font_name);
ylabel(ax1, '前向位移 x / m', 'FontName', font_name);
title(ax1, '(a) 前向推进过程对比', 'FontWeight', 'normal', 'FontName', font_name);
legend(ax1, case_labels, 'Location', 'northwest', 'Box', 'off', 'FontName', font_name);
set(ax1, 'FontName', font_name, 'LineWidth', 1.0, 'FontSize', 11);

ax2 = nexttile(t, 2);
hold(ax2, 'on');
plot_case_series(ax2, case_runs, case_labels, case_colors, 'y_mean');
yline(ax2, 0, ':', '侧向零偏移参考', 'Color', colors.guide, 'LineWidth', 1.0, ...
    'FontName', font_name, 'FontSize', 9, 'LabelHorizontalAlignment', 'left');
grid(ax2, 'on');
box(ax2, 'on');
xlim(ax2, [0, max_time]);
ylim(ax2, [-max(max_y * 1.15, 0.2), max(max_y * 1.15, 0.2)]);
xlabel(ax2, '时间 / s', 'FontName', font_name);
ylabel(ax2, '横向位移 y / m', 'FontName', font_name);
title(ax2, '(b) 横向漂移过程对比', 'FontWeight', 'normal', 'FontName', font_name);
set(ax2, 'FontName', font_name, 'LineWidth', 1.0, 'FontSize', 11);

ax3 = nexttile(t, 3);
hold(ax3, 'on');
plot_case_series(ax3, case_runs, case_labels, case_colors, 'pitch_mean');
grid(ax3, 'on');
box(ax3, 'on');
xlim(ax3, [0, max_time]);
ylim(ax3, [0, max(max_pitch * 1.10, 1)]);
xlabel(ax3, '时间 / s', 'FontName', font_name);
ylabel(ax3, '俯仰角绝对值 / (°)', 'FontName', font_name);
title(ax3, '(c) 俯仰扰动对比', 'FontWeight', 'normal', 'FontName', font_name);
set(ax3, 'FontName', font_name, 'LineWidth', 1.0, 'FontSize', 11);

ax4 = nexttile(t, 4);
hold(ax4, 'on');
plot_case_series(ax4, case_runs, case_labels, case_colors, 'yaw_mean');
grid(ax4, 'on');
box(ax4, 'on');
xlim(ax4, [0, max_time]);
ylim(ax4, [0, max(max_yaw * 1.10, 1)]);
xlabel(ax4, '时间 / s', 'FontName', font_name);
ylabel(ax4, '航向角绝对值 / (°)', 'FontName', font_name);
title(ax4, '(d) 航向偏移对比', 'FontWeight', 'normal', 'FontName', font_name);
set(ax4, 'FontName', font_name, 'LineWidth', 1.0, 'FontSize', 11);

exportgraphics(fig, png_path, 'Resolution', 320);
savefig(fig, fig_path);
close(fig);
end

function plot_case_series(ax, case_runs, case_labels, case_colors, field_name)
line_styles = {'--', '-.', '-'};
line_widths = [2.0, 2.0, 2.3];

for idx = 1:numel(case_runs)
    runs = case_runs{idx};
    label = case_labels{idx}; %#ok<NASGU>
    plot(ax, runs.time_mean, runs.(field_name), line_styles{idx}, ...
        'Color', case_colors(idx, :), 'LineWidth', line_widths(idx));
end
end

function export_metric_grid_figure(png_path, fig_path, case_rows, case_labels, case_colors, metric_defs, grid_shape, font_name)
fig = figure('Color', 'w', 'Position', [120, 100, 1030, 660], 'Visible', 'off');
t = tiledlayout(fig, grid_shape(1), grid_shape(2), 'TileSpacing', 'compact', 'Padding', 'compact');

subplot_count = grid_shape(1) * grid_shape(2);
for idx = 1:subplot_count
    ax = nexttile(t, idx);
    if idx > numel(metric_defs)
        axis(ax, 'off');
        continue;
    end

    def = metric_defs{idx};
    values = nan(1, numel(case_rows));
    scale = get_metric_option(def, 'scale', 1);
    for row_idx = 1:numel(case_rows)
        values(row_idx) = case_rows{row_idx}.(def.field) * scale;
    end

    bar_handle = bar(ax, 1:numel(values), values, 0.60, 'FaceColor', 'flat', 'EdgeColor', 'none');
    bar_handle.CData = case_colors;

    set(ax, 'XTick', 1:numel(values), 'XTickLabel', case_labels, ...
        'FontName', font_name, 'LineWidth', 1.0, 'FontSize', 10);
    grid(ax, 'on');
    box(ax, 'on');
    ylabel(ax, build_y_label(def), 'FontName', font_name);
    title(ax, def.label, 'FontWeight', 'normal', 'FontName', font_name);

    valid_values = values(~isnan(values));
    if isempty(valid_values)
        ylim(ax, [0, 1]);
    else
        y_min = min([valid_values, 0]);
        y_max = max([valid_values, 0]);
        y_pad = max((y_max - y_min) * 0.15, 0.05 * max(abs([valid_values, 1])));
        lower_lim = y_min - y_pad;
        upper_lim = y_max + y_pad;
        if y_min >= 0
            lower_lim = 0;
        elseif y_max <= 0
            upper_lim = 0;
        end
        ylim(ax, [lower_lim, upper_lim]);

        for value_idx = 1:numel(values)
            if isnan(values(value_idx))
                continue;
            end
            text(ax, value_idx, values(value_idx) + sign_with_default(values(value_idx)) * y_pad * 0.20, ...
                format_metric_value(values(value_idx), def), ...
                'HorizontalAlignment', 'center', 'FontName', font_name, 'FontSize', 10);
        end
    end
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

function write_section_markdown(md_path, initial_row, half_row, final_row)
crossing_pct = percent_change(final_row.scene_ditch_crossing_distance_m_mean, initial_row.scene_ditch_crossing_distance_m_mean);
net_disp_pct = percent_change(final_row.common_net_displacement_m_mean, initial_row.common_net_displacement_m_mean);
path_pct = percent_change(final_row.common_path_efficiency_mean, initial_row.common_path_efficiency_mean);
force_pct = percent_drop(final_row.common_total_force_rms_N_mean, half_row.common_total_force_rms_N_mean);
pitch_pct = percent_drop(final_row.scene_ditch_stage_pitch_peak_deg_mean, half_row.scene_ditch_stage_pitch_peak_deg_mean);
roll_pct = percent_drop(final_row.scene_ditch_stage_roll_peak_deg_mean, half_row.scene_ditch_stage_roll_peak_deg_mean);
yaw_pct = percent_drop(final_row.common_yaw_drift_deg_mean, half_row.common_yaw_drift_deg_mean);
lateral_pct = percent_drop(final_row.scene_max_lateral_drift_m_mean, half_row.scene_max_lateral_drift_m_mean);

fid = fopen(md_path, 'w', 'n', 'UTF-8');
if fid == -1
    error('hexapod_plot_midterm_ditch:WriteMarkdownFailed', '无法写入正文草稿文件: %s', md_path);
end
cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '#### 1.2.3 深沟场景下的半闭环跨越优化与结果分析\n\n');
fprintf(fid, '深沟场景主要用于评估六足机器人在未知落脚条件下的跨越能力。与斜坡和高台场景不同，该场景除考察前向通过能力外，还要求控制系统能够在足端踩空后完成状态识别、恢复决策与姿态约束，否则容易出现无效折返、方向偏移和整机失稳。因此，本节将深沟实验划分为传统方案、优化方案和当前方案三个阶段，用于分析控制策略由传统开环跨坑向半闭环收敛的演化过程。\n\n');
fprintf(fid, '传统方案来自 `walk3step.m` 的原始跨坑段，其本质为三角步态下的开环跨坑策略。三角步态在规则支撑条件下具有较高的瞬时静稳定性，因此部分姿态指标数值相对保守；但在深沟边缘，支撑域一旦因踩空而发生突变，该方案缺乏有效的在线补救机制，难以形成可靠的跨越能力。为增强单腿探测与恢复能力，后续方案改为以 `walk_ditch.m` 为基准的波浪步态，并引入力觉探测和闭环恢复逻辑。波浪步态提高了深沟场景下的可操作性，但同时也带来了横向漂移、偏航累积和姿态波动更易放大的问题。\n\n');
fprintf(fid, '优化方案已经建立起基本的力觉探测与闭环恢复框架，使机器人具备了踩空识别和二次跨越的能力，但恢复顺序、姿态约束和方向抑制仍不充分；当前方案则在此基础上进一步加入“先直接前跨、失败后再退回”的恢复顺序、单腿脱困、原位锁定、左右步幅差分纠偏以及分级重心前移等策略，从而实现对波浪步态跨沟过程的进一步收束。\n\n');
fprintf(fid, '【图1 此处插入：深沟场景三阶段过程收敛对比图】\n\n');
fprintf(fid, '从图1可以看出，传统方案在前向位移曲线上较早出现推进停滞，说明机器人在到达坑边后难以继续完成有效跨越；其姿态曲线虽未表现出优化方案那样持续扩大的发散趋势，但这主要反映的是三角步态在尚未真正进入连续过沟阶段前已失去推进能力，而不能据此认为其在深沟场景下更优。优化方案能够实现一定程度的继续推进，但横向位移和航向角在中后段持续累积，表明波浪步态与闭环恢复机制虽已具备作用，却仍伴随较明显的偏航与横摆。相比之下，当前方案的前向推进过程更连续，横向偏移和姿态曲线也更为收敛，尤其是在航向角和俯仰角绝对值曲线上均明显低于优化方案，说明恢复顺序重排、原位锁定与步幅差分纠偏后，波浪步态在跨沟过程中的姿态发散得到了有效抑制。\n\n');
fprintf(fid, '【图2 此处插入：深沟场景通过性指标对比图】\n\n');
fprintf(fid, '从通过性指标来看，传统方案和优化方案的成功标志均为 0，而当前方案提升到 1，表明当前方案已经能够完成稳定跨沟。这里需要说明两类位移指标的含义：图中的“通过距离”与前两节斜坡、高台场景的口径一致，均定义为机身沿主推进方向 X 轴的首末位移差；深沟场景内部变量名虽仍记作 `ditch_crossing_distance`，但在报告中统一表述为“通过距离”。“直线净位移”则表示机身起点到终点的空间直线距离，该指标会受到横向漂移和无效折返的影响，因此作为辅助指标使用。按此口径，传统方案的通过距离由 %.3f m 提高到当前方案的 %.3f m，提升了 %.1f%%；直线净位移由 %.3f m 提高到 %.3f m，提升了 %.1f%%；路径效率由 %.3f 提高到 %.3f，提升了 %.1f%%。同时，优化方案的通过距离已提升到 %.3f m，说明改用波浪步态并引入力觉探测后，机器人已经具备一定的过沟能力，但由于恢复链条仍较保守、无效折返较多，尚未达到稳定完成跨越的水平。当前方案在路径效率和直线净位移上的进一步提高，则说明恢复顺序重构与单腿脱困策略有效减少了坑边反复试探和无效回撤。\n\n', ...
        initial_row.scene_ditch_crossing_distance_m_mean, final_row.scene_ditch_crossing_distance_m_mean, crossing_pct, ...
        initial_row.common_net_displacement_m_mean, final_row.common_net_displacement_m_mean, net_disp_pct, ...
        initial_row.common_path_efficiency_mean, final_row.common_path_efficiency_mean, path_pct, ...
        half_row.scene_ditch_crossing_distance_m_mean);
fprintf(fid, '【图3 此处插入：深沟场景稳定性指标对比图】\n\n');
fprintf(fid, '从稳定性指标来看，当前方案相对优化方案的总受力均方根由 %.0f N 下降到 %.0f N，下降了 %.1f%%；阶段俯仰峰值由 %.3f° 降到 %.3f°，下降了 %.1f%%；阶段横滚峰值由 %.3f° 降到 %.3f°，下降了 %.1f%%；航向漂移由 %.3f° 降到 %.3f°，下降了 %.1f%%。此外，最大横向漂移也由 %.3f m 降到 %.3f m，下降了 %.1f%%。需要指出的是，部分指标上当前方案未必优于传统方案，这并不构成矛盾。原因在于，传统方案采用三角步态，在尚未真正进入持续过沟阶段前，其姿态曲线往往表现得相对保守，但其根本问题在于缺乏可靠的跨坑能力；而优化方案与当前方案改用波浪步态后，首先解决的是“能否跨越”的问题，随后才进一步处理由波浪步态带来的偏航累积与姿态发散。因此，深沟场景下更合理的稳定性比较对象应为优化方案与当前方案，因为这两者均属于同一类波浪步态半闭环框架，而当前方案的改进正是针对优化方案暴露出的姿态不稳定问题展开的。上述结果也与原位锁定减冲击、分级重心前移和左右步幅差分纠偏等控制策略的作用机理相一致。\n\n', ...
        half_row.common_total_force_rms_N_mean, final_row.common_total_force_rms_N_mean, force_pct, ...
        half_row.scene_ditch_stage_pitch_peak_deg_mean, final_row.scene_ditch_stage_pitch_peak_deg_mean, pitch_pct, ...
        half_row.scene_ditch_stage_roll_peak_deg_mean, final_row.scene_ditch_stage_roll_peak_deg_mean, roll_pct, ...
        half_row.common_yaw_drift_deg_mean, final_row.common_yaw_drift_deg_mean, yaw_pct, ...
        half_row.scene_max_lateral_drift_m_mean, final_row.scene_max_lateral_drift_m_mean, lateral_pct);
fprintf(fid, '综合来看，深沟场景下的优化重点并不在于单纯增大步长或提高探测深度，而在于对“步态选择、探测恢复、脱困补救、重心调节与姿态纠偏”这一整条闭环链路进行系统收束。传统方案对应的是三角步态下的开环跨坑思路，其主要局限在于坑边失稳后缺乏有效补救；优化方案对应的是波浪步态半闭环框架，其首先解决了跨沟过程中的探测与恢复问题，但同时暴露出新的偏航和姿态波动；当前方案则进一步表明，只有将恢复顺序、单腿脱困、重心补偿与偏航抑制协同起来，波浪步态才能在深沟场景中同时获得通过能力与稳定性。\n');
end

function [time_mat, x_mat, y_mat, pitch_mat, yaw_mat] = align_run_series(time_runs, x_runs, y_runs, pitch_runs, yaw_runs)
max_len = max(cellfun(@numel, time_runs));
run_count = numel(time_runs);

time_mat = nan(run_count, max_len);
x_mat = nan(run_count, max_len);
y_mat = nan(run_count, max_len);
pitch_mat = nan(run_count, max_len);
yaw_mat = nan(run_count, max_len);

for idx = 1:run_count
    cur_len = numel(time_runs{idx});
    time_mat(idx, 1:cur_len) = time_runs{idx};
    x_mat(idx, 1:cur_len) = x_runs{idx};
    y_mat(idx, 1:cur_len) = y_runs{idx};
    pitch_mat(idx, 1:cur_len) = pitch_runs{idx};
    yaw_mat(idx, 1:cur_len) = yaw_runs{idx};
end
end

function [time_vec, x_vec, y_vec, pitch_vec, yaw_vec] = trim_leading_placeholder(time_vec, x_vec, y_vec, pitch_vec, yaw_vec)
valid_start = find(~(isnan(x_vec) | isnan(y_vec)), 1, 'first');
if isempty(valid_start)
    valid_start = 1;
end

time_offset = time_vec(valid_start);
x_origin = x_vec(valid_start);
y_origin = y_vec(valid_start);

time_vec = time_vec(valid_start:end) - time_offset;
x_vec = x_vec(valid_start:end) - x_origin;
y_vec = y_vec(valid_start:end) - y_origin;
pitch_vec = pitch_vec(valid_start:end);
yaw_vec = yaw_vec(valid_start:end);
end

function s = sign_with_default(value)
if value < 0
    s = -1;
else
    s = 1;
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
