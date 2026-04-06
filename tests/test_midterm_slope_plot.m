function tests = test_midterm_slope_plot
tests = functiontests(localfunctions);
end

function test_trajectory_figure_hides_repeat_runs(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
compare_root = fullfile(project_root, 'log', 'slope', 'compare_user_slope_repeat3_20260331');
verifyTrue(testCase, isfolder(compare_root), ...
    sprintf('缺少斜坡对比目录: %s', compare_root));

initialize_project_paths(project_root);
clear hexapod_plot_midterm_slope;
rehash;

output_dir = fullfile(tempdir, ['midterm_slope_plot_test_', char(java.util.UUID.randomUUID)]);
mkdir(output_dir);
cleanup_obj = onCleanup(@() cleanup_output_dir(output_dir)); %#ok<NASGU>

outputs = hexapod_plot_midterm_slope(compare_root, output_dir);
figure1_fig = fullfile(output_dir, 'figure1_slope_trajectory_comparison.fig');
verifyTrue(testCase, isfile(figure1_fig), ...
    sprintf('未生成 figure1 fig 文件: %s', figure1_fig));

fig = openfig(figure1_fig, 'invisible');
fig_cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
axes_list = findall(fig, 'Type', 'Axes');
positions = cell2mat(get(axes_list, 'Position'));
if isvector(positions)
    positions = reshape(positions, 1, []);
end
top_ax = axes_list(argmax(positions(:, 2)));
bottom_ax = axes_list(argmin(positions(:, 2)));

line_objects = findall(top_ax, 'Type', 'Line');
verifyEqual(testCase, numel(line_objects), 2, ...
    sprintf('图1 顶部应只保留 2 条主对比曲线，当前检测到 %d 条。', numel(line_objects)));

legend_obj = findall(fig, 'Type', 'Legend');
verifyEqual(testCase, string(legend_obj.String), ["传统方案均值", "当前方案均值"], ...
    '图1 图例口径应统一为“传统方案”。');

guide_lines = findall(top_ax, 'Type', 'ConstantLine');
[guide_values, order] = sort([guide_lines.Value]);
guide_labels = strings(1, numel(order));
for idx = 1:numel(order)
    guide_labels(idx) = string(guide_lines(order(idx)).Label);
end
verifyEqual(testCase, guide_values, [0.425, 3.925], 'AbsTol', 1e-9, ...
    '图1 上方参考线位置应仅保留前腿到达坡面前沿和机身完全上坡。');
verifyEqual(testCase, guide_labels, ["前腿到达坡面前沿", "机身完全上坡"], ...
    '图1 上方参考线标签口径不正确。');

patch_objects = findall(bottom_ax, 'Type', 'Patch');
verifyEqual(testCase, numel(patch_objects), 0, ...
    sprintf('图1 底部不应保留波动带残留，当前检测到 %d 个 patch。', numel(patch_objects)));
end

function test_trajectory_figure_normalizes_absolute_start_pose(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);
clear hexapod_plot_midterm_slope;
rehash;

compare_root = fullfile(tempdir, ['midterm_slope_compare_', char(java.util.UUID.randomUUID)]);
output_dir = fullfile(tempdir, ['midterm_slope_plot_', char(java.util.UUID.randomUUID)]);
mkdir(compare_root);
mkdir(output_dir);
cleanup_compare = onCleanup(@() cleanup_output_dir(compare_root)); %#ok<NASGU>
cleanup_output = onCleanup(@() cleanup_output_dir(output_dir)); %#ok<NASGU>

write_fake_compare_dataset(compare_root);
hexapod_plot_midterm_slope(compare_root, output_dir);

fig = openfig(fullfile(output_dir, 'figure1_slope_trajectory_comparison.fig'), 'invisible');
fig_cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
axes_list = findall(fig, 'Type', 'Axes');
positions = cell2mat(get(axes_list, 'Position'));
if isvector(positions)
    positions = reshape(positions, 1, []);
end
top_ax = axes_list(argmax(positions(:, 2)));
line_objects = findall(top_ax, 'Type', 'Line');

for idx = 1:numel(line_objects)
    x_data = line_objects(idx).XData;
    y_data = line_objects(idx).YData;
    verifyEqual(testCase, x_data(1), 0, 'AbsTol', 1e-9, ...
        '轨迹图横轴应使用相对真实起点的位移。');
    verifyEqual(testCase, y_data(1), 0, 'AbsTol', 1e-9, ...
        '轨迹图纵轴应使用相对真实起点的高度变化。');
end
end

function test_generated_assets_use_traditional_scheme_wording(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
compare_root = fullfile(project_root, 'log', 'slope', 'compare_user_slope_repeat3_20260331');
verifyTrue(testCase, isfolder(compare_root), ...
    sprintf('缺少斜坡对比目录: %s', compare_root));

initialize_project_paths(project_root);
clear hexapod_plot_midterm_slope;
rehash;

output_dir = fullfile(tempdir, ['midterm_slope_wording_', char(java.util.UUID.randomUUID)]);
mkdir(output_dir);
cleanup_obj = onCleanup(@() cleanup_output_dir(output_dir)); %#ok<NASGU>

outputs = hexapod_plot_midterm_slope(compare_root, output_dir);
section_text = string(fileread(outputs.section_md));
verifyFalse(testCase, contains(section_text, "基准方案"), ...
    '斜坡小节正文不应再使用“基准方案”表述。');
verifyTrue(testCase, contains(section_text, "传统方案"), ...
    '斜坡小节正文应改为“传统方案”表述。');
verifyFalse(testCase, contains(section_text, "有效推进距离"), ...
    '斜坡小节正文中的距离指标应统一为“通过距离”。');
verifyFalse(testCase, contains(section_text, "爬升高度"), ...
    '斜坡小节正文中的高度指标应统一为“高度增益”。');
verifyTrue(testCase, contains(section_text, "通过距离"), ...
    '斜坡小节正文应使用“通过距离”表述。');
verifyTrue(testCase, contains(section_text, "高度增益"), ...
    '斜坡小节正文应使用“高度增益”表述。');
verifyFalse(testCase, contains(section_text, "总支撑力峰值"), ...
    '斜坡小节正文中的受力指标应改为总受力均方根。');
verifyTrue(testCase, contains(section_text, "总受力均方根"), ...
    '斜坡小节正文应明确使用总受力均方根指标。');

figure2_fig = fullfile(output_dir, 'figure2_slope_passability_comparison.fig');
verifyTrue(testCase, isfile(figure2_fig), ...
    sprintf('未生成 figure2 fig 文件: %s', figure2_fig));
fig = openfig(figure2_fig, 'invisible');
fig_cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
axes_list = findall(fig, 'Type', 'Axes');
chart_axes = axes_list(arrayfun(@(ax) ~isempty(ax.XTickLabel), axes_list));
for idx = 1:numel(chart_axes)
    verifyEqual(testCase, reshape(string(chart_axes(idx).XTickLabel), 1, []), ["传统方案", "当前方案"], ...
        '指标图横轴标签口径应统一为“传统方案”。');
end
title_texts_2 = strings(1, 0);
for idx = 1:numel(chart_axes)
    if isprop(chart_axes(idx), 'Title') && ~isempty(chart_axes(idx).Title.String)
        title_texts_2(end + 1) = string(chart_axes(idx).Title.String); %#ok<AGROW>
    end
end
verifyTrue(testCase, any(title_texts_2 == "通过距离"), ...
    '图2 应使用“通过距离”表述。');
verifyTrue(testCase, any(title_texts_2 == "高度增益"), ...
    '图2 应使用“高度增益”表述。');
verifyFalse(testCase, any(title_texts_2 == "有效推进距离"), ...
    '图2 不应继续使用“有效推进距离”表述。');
verifyFalse(testCase, any(title_texts_2 == "爬升高度"), ...
    '图2 不应继续使用“爬升高度”表述。');

figure3_fig = fullfile(output_dir, 'figure3_slope_stability_comparison.fig');
verifyTrue(testCase, isfile(figure3_fig), ...
    sprintf('未生成 figure3 fig 文件: %s', figure3_fig));
fig3 = openfig(figure3_fig, 'invisible');
fig3_cleanup = onCleanup(@() close(fig3)); %#ok<NASGU>
axes_list_3 = findall(fig3, 'Type', 'Axes');
title_texts = strings(1, 0);
for idx = 1:numel(axes_list_3)
    if isprop(axes_list_3(idx), 'Title') && ~isempty(axes_list_3(idx).Title.String)
        title_texts(end + 1) = string(axes_list_3(idx).Title.String); %#ok<AGROW>
    end
end
verifyTrue(testCase, any(title_texts == "总受力均方根"), ...
    '图3 应使用总受力均方根指标。');
verifyFalse(testCase, any(title_texts == "总支撑力峰值"), ...
    '图3 不应继续使用总支撑力峰值指标。');
end

function test_export_metrics_trajectory_plot_normalizes_start_pose(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);

output_dir = fullfile(tempdir, ['export_metrics_plot_', char(java.util.UUID.randomUUID)]);
mkdir(output_dir);
cleanup_obj = onCleanup(@() cleanup_output_dir(output_dir)); %#ok<NASGU>

telemetry = build_fake_export_telemetry();
meta = struct( ...
    'scene_name', 'slope', ...
    'scene_label', '斜坡', ...
    'scene_variant', 'test', ...
    'source_flow', 'unit_test', ...
    'entry_pattern', 'slope_test', ...
    'run_now', now, ...
    'run_timestamp', '2026-04-01 00:00:00', ...
    'output_dir', output_dir, ...
    'control_dt_ms', 1000);

hexapod_export_metrics(project_root, telemetry, meta);

fig = openfig(fullfile(output_dir, '03_trajectory_tracking.fig'), 'invisible');
fig_cleanup = onCleanup(@() close(fig)); %#ok<NASGU>

axes_list = findall(fig, 'Type', 'Axes');
positions = cell2mat(get(axes_list, 'Position'));
if isvector(positions)
    positions = reshape(positions, 1, []);
end

top_ax = axes_list(argmax(positions(:, 2)));
bottom_ax = axes_list(argmin(positions(:, 2)));
middle_mask = positions(:, 2) ~= positions(argmax(positions(:, 2)), 2) & ...
    positions(:, 2) ~= positions(argmin(positions(:, 2)), 2);
middle_ax = axes_list(find(middle_mask, 1, 'first'));

top_line = findall(top_ax, 'Type', 'Line');
verifyEqual(testCase, top_line.YData(:), [0; 0.4; 1.0], 'AbsTol', 1e-9, ...
    'X 时间曲线应相对真实起点归一化。');

middle_line = findall(middle_ax, 'Type', 'Line');
verifyEqual(testCase, middle_line.YData(:), [0; 0.1; 0.3], 'AbsTol', 1e-9, ...
    'Y 时间曲线应相对真实起点归一化。');

bottom_line = findall(bottom_ax, 'Type', 'Line');
verifyEqual(testCase, bottom_line.XData(:), [0; 0.4; 1.0], 'AbsTol', 1e-9, ...
    'X-Z 轨迹横轴应相对真实起点归一化。');
verifyEqual(testCase, bottom_line.YData(:), [0; 0.05; 0.2], 'AbsTol', 1e-9, ...
    'X-Z 轨迹纵轴应相对真实起点归一化。');
end

function initialize_project_paths(project_root)
setup_dir = fullfile(project_root, 'lib', 'setup');
if exist(setup_dir, 'dir') == 7
    addpath(setup_dir);
end
compare_dir = fullfile(project_root, 'MAIN', 'compare');
metrics_analyze_dir = fullfile(compare_dir, 'metircs_analyze');
if exist(compare_dir, 'dir') == 7
    addpath(compare_dir);
end
hexapod_setup_paths();
if exist(metrics_analyze_dir, 'dir') == 7
    addpath(metrics_analyze_dir);
end
if exist(compare_dir, 'dir') == 7
    addpath(compare_dir);
end
end

function cleanup_output_dir(output_dir)
if exist(output_dir, 'dir') == 7
    rmdir(output_dir, 's');
end
end

function write_fake_compare_dataset(compare_root)
case_names = {'slope_baseline', 'slope_current'};
progress = [1.2, 2.0];
climb = [0.3, 0.6];
path_eff = [0.7, 0.9];
backslide = [0.4, 0.2];
force_peak = [1000, 800];
force_rms = [900, 700];
roll_peak = [5, 2];
yaw_drift = [3, 1];

scene_name = repmat("slope", 2, 1);
scene_label = repmat("斜坡", 2, 1);
scene_variant = ["baseline"; "current"];
case_id = string(case_names(:));
case_description = ["斜坡旧版轨迹"; "当前斜坡方案"];
compare_group_id = repmat("test_group", 2, 1);

tbl = table(scene_name, scene_label, scene_variant, case_id, case_description, compare_group_id, ...
    progress', climb', path_eff', backslide', force_peak', force_rms', roll_peak', yaw_drift', ...
    'VariableNames', { ...
    'scene_name', 'scene_label', 'scene_variant', 'case_id', 'case_description', 'compare_group_id', ...
    'scene_slope_progress_m_mean', 'scene_climb_height_gain_m_mean', 'common_path_efficiency_mean', ...
    'scene_backslide_distance_m_mean', 'common_total_force_peak_N_mean', 'common_total_force_rms_N_mean', ...
    'common_roll_peak_deg_mean', 'common_yaw_drift_deg_mean'});
writetable(tbl, fullfile(compare_root, 'compare_aggregate_latest3.csv'));

for idx = 1:numel(case_names)
    run_dir = fullfile(compare_root, case_names{idx}, 'run_01');
    mkdir(run_dir);
    metrics = struct();
    metrics.series = struct();
    metrics.series.time_s = [0; 1; 2];
    metrics.series.realX = [3.8; 4.4; 5.1] + (idx - 1) * [0; 0.2; 0.7];
    metrics.series.realY = [0; 0; 0];
    metrics.series.realZ = [2.7; 2.8; 3.0] + (idx - 1) * [0; 0.1; 0.2];
    metrics.series.pitch_deg = [0; -6; -12] - (idx - 1) * [0; 1; 2];
    save(fullfile(run_dir, 'metrics.mat'), 'metrics');
end
end

function telemetry = build_fake_export_telemetry()
telemetry = struct();
telemetry.realX = [3.2; 3.6; 4.2];
telemetry.realY = [-0.5; -0.4; -0.2];
telemetry.realZ = [1.1; 1.15; 1.3];
telemetry.bodyEulerDeg = zeros(3, 3);
telemetry.legForceMag = zeros(3, 6);
telemetry.control_dt_sec = 1.0;
end

function idx = argmax(values)
[~, idx] = max(values);
end

function idx = argmin(values)
[~, idx] = min(values);
end
