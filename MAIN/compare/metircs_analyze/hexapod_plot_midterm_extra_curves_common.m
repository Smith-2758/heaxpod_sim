function outputs = hexapod_plot_midterm_extra_curves_common(config)
% 生成中期报告补充曲线图的通用入口

validate_config(config);

compare_root = char(config.compare_root);
output_dir = char(config.output_dir);
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

font_name = pick_font_name();
run_sets = load_case_runs(config.case_specs);

foot_png = fullfile(output_dir, sprintf('figure_extra_%s_footend_curve.png', config.scene_key));
foot_fig = fullfile(output_dir, sprintf('figure_extra_%s_footend_curve.fig', config.scene_key));
export_foot_curve_figure(foot_png, foot_fig, run_sets, font_name, config);

force_png = fullfile(output_dir, sprintf('figure_extra_%s_total_force_curve.png', config.scene_key));
force_fig = fullfile(output_dir, sprintf('figure_extra_%s_total_force_curve.fig', config.scene_key));
export_total_force_figure(force_png, force_fig, run_sets, font_name, config);

outputs = struct();
outputs.compare_root = compare_root;
outputs.output_dir = output_dir;
outputs.foot_png = foot_png;
outputs.foot_fig = foot_fig;
outputs.force_png = force_png;
outputs.force_fig = force_fig;
outputs.data_note = '每个 case 使用排序后的首个 run 作为报告补图数据源。';
end

function validate_config(config)
required_fields = {'scene_key', 'scene_title', 'compare_root', 'output_dir', 'case_specs'};
for idx = 1:numel(required_fields)
    if ~isfield(config, required_fields{idx}) || isempty(config.(required_fields{idx}))
        error('hexapod_plot_midterm_extra_curves_common:MissingConfig', ...
            '缺少配置字段: %s', required_fields{idx});
    end
end
end

function run_sets = load_case_runs(case_specs)
run_sets = cell(numel(case_specs), 1);
for idx = 1:numel(case_specs)
    run_sets{idx} = load_single_case(case_specs(idx));
end
run_sets = vertcat(run_sets{:});
end

function run_data = load_single_case(case_spec)
metric_files = dir(fullfile(case_spec.case_dir, 'run_*', 'metrics.mat'));
if isempty(metric_files)
    error('hexapod_plot_midterm_extra_curves_common:MissingMetrics', ...
        '未找到指标文件目录: %s', case_spec.case_dir);
end

[~, sort_idx] = sort({metric_files.folder});
metric_path = fullfile(metric_files(sort_idx(1)).folder, metric_files(sort_idx(1)).name);
data = load(metric_path, 'metrics');
metrics = data.metrics;

run_data = struct();
run_data.case_id = case_spec.case_id;
run_data.label = case_spec.label;
run_data.color = case_spec.color;
run_data.line_style = case_spec.line_style;
run_data.metric_path = metric_path;
run_data.force_time = metrics.series.time_s(:)';
run_data.force_series = metrics.series.total_force_N(:)';

joint_path = char(metrics.meta.source_artifact_path);
if exist(joint_path, 'file') ~= 2
    error('hexapod_plot_midterm_extra_curves_common:MissingJointArtifact', ...
        '未找到关节轨迹工件: %s', joint_path);
end

joint_data = load(joint_path, 'joint');
if ~isfield(joint_data, 'joint')
    error('hexapod_plot_midterm_extra_curves_common:InvalidJointArtifact', ...
        '关节轨迹工件中未找到 joint 变量: %s', joint_path);
end

dt = metrics.meta.control_dt_sec;
if isempty(dt) || isnan(dt)
    dt = 0.005;
end
run_data.joint_path = joint_path;
run_data.foot_pair_height = compute_pair_height_series(joint_data.joint);
run_data.foot_time = (0:size(run_data.foot_pair_height, 1) - 1) * dt;
end

function pair_height = compute_pair_height_series(joint)
robot_template = robot3D_description();
foot_link_ids = [4, 7, 10, 13, 16, 19];
pair_map = [1, 4; 2, 5; 3, 6];
frame_count = size(joint, 1);
foot_height = nan(frame_count, 6);

for frame_idx = 1:frame_count
    robot = robot_template;
    for joint_idx = 1:18
        robot(joint_idx + 1).q = joint(frame_idx, joint_idx);
    end
    robot = fkinematic(robot, 1);
    robot = fk_collision(robot);
    for leg_idx = 1:6
        foot_height(frame_idx, leg_idx) = robot(foot_link_ids(leg_idx)).collision(1).p(3);
    end
end

pair_height = nan(frame_count, 3);
for pair_idx = 1:size(pair_map, 1)
    pair_height(:, pair_idx) = mean(foot_height(:, pair_map(pair_idx, :)), 2, 'omitnan');
    pair_height(:, pair_idx) = pair_height(:, pair_idx) - pair_height(1, pair_idx);
end
end

function export_foot_curve_figure(png_path, fig_path, run_sets, font_name, config)
pair_names = {'前足对', '中足对', '后足对'};
fig = figure('Color', 'w', 'Position', [100, 70, 980, 760], 'Visible', 'off');
t = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

global_min = inf;
global_max = -inf;
for idx = 1:numel(run_sets)
    global_min = min(global_min, min(run_sets(idx).foot_pair_height, [], 'all'));
    global_max = max(global_max, max(run_sets(idx).foot_pair_height, [], 'all'));
end
if ~isfinite(global_min)
    global_min = -0.05;
end
if ~isfinite(global_max)
    global_max = 0.15;
end

for pair_idx = 1:3
    ax = nexttile(t, pair_idx);
    hold(ax, 'on');
    for case_idx = 1:numel(run_sets)
        plot(ax, run_sets(case_idx).foot_time, run_sets(case_idx).foot_pair_height(:, pair_idx), ...
            'LineStyle', run_sets(case_idx).line_style, ...
            'Color', run_sets(case_idx).color, ...
            'LineWidth', 2.0);
    end
    grid(ax, 'on');
    box(ax, 'on');
    xlim(ax, [0, max(cellfun(@(x) max(x), {run_sets.foot_time}))]);
    ylim(ax, [global_min - 0.02, global_max + 0.02]);
    ylabel(ax, sprintf('%s相对高度 / m', pair_names{pair_idx}), 'FontName', font_name);
    title(ax, sprintf('(%c) %s足端相对高度', char('a' + pair_idx - 1), pair_names{pair_idx}), ...
        'FontWeight', 'normal', 'FontName', font_name);
    set(ax, 'FontName', font_name, 'LineWidth', 1.0, 'FontSize', 11);
    if pair_idx == 1
        legend(ax, {run_sets.label}, 'Location', 'northwest', 'Box', 'off', 'FontName', font_name);
    end
    if pair_idx == 3
        xlabel(ax, '时间 / s', 'FontName', font_name);
    end
end

title(t, sprintf('%s场景足端过程曲线对比', config.scene_title), 'FontName', font_name, 'FontWeight', 'normal');
exportgraphics(fig, png_path, 'Resolution', 320);
savefig(fig, fig_path);
close(fig);
end

function export_total_force_figure(png_path, fig_path, run_sets, font_name, config)
fig = figure('Color', 'w', 'Position', [110, 110, 980, 420], 'Visible', 'off');
ax = axes(fig);
hold(ax, 'on');

for idx = 1:numel(run_sets)
    plot(ax, run_sets(idx).force_time, run_sets(idx).force_series, ...
        'LineStyle', run_sets(idx).line_style, ...
        'Color', run_sets(idx).color, ...
        'LineWidth', 2.0);
end

grid(ax, 'on');
box(ax, 'on');
xlim(ax, [0, max(cellfun(@(x) max(x), {run_sets.force_time}))]);
ylim(ax, [0, max(cellfun(@(x) max(x), {run_sets.force_series})) * 1.05]);
xlabel(ax, '时间 / s', 'FontName', font_name);
ylabel(ax, '总受力 / N', 'FontName', font_name);
title(ax, sprintf('%s场景总受力全过程对比', config.scene_title), ...
    'FontWeight', 'normal', 'FontName', font_name);
legend(ax, {run_sets.label}, 'Location', 'northwest', 'Box', 'off', 'FontName', font_name);
set(ax, 'FontName', font_name, 'LineWidth', 1.0, 'FontSize', 11);

exportgraphics(fig, png_path, 'Resolution', 320);
savefig(fig, fig_path);
close(fig);
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
