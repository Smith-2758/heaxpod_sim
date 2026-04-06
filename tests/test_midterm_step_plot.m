function tests = test_midterm_step_plot
tests = functiontests(localfunctions);
end

function test_step_metric_labels_and_relative_axis_wording(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);
clear hexapod_plot_midterm_step;
rehash;

compare_root = fullfile(tempdir, ['midterm_step_compare_', char(java.util.UUID.randomUUID)]);
output_dir = fullfile(tempdir, ['midterm_step_plot_', char(java.util.UUID.randomUUID)]);
mkdir(compare_root);
mkdir(output_dir);
cleanup_compare = onCleanup(@() cleanup_output_dir(compare_root)); %#ok<NASGU>
cleanup_output = onCleanup(@() cleanup_output_dir(output_dir)); %#ok<NASGU>

write_fake_step_compare_dataset(compare_root);
outputs = hexapod_plot_midterm_step(compare_root, output_dir);

section_text = string(fileread(outputs.section_md));
verifyTrue(testCase, contains(section_text, "通过距离"), ...
    '高台小节正文应使用“通过距离”表述。');
verifyTrue(testCase, contains(section_text, "高度增益"), ...
    '高台小节正文应使用“高度增益”表述。');
verifyFalse(testCase, contains(section_text, "跨越距离"), ...
    '高台小节正文不应继续使用“跨越距离”表述。');
verifyTrue(testCase, contains(section_text, "相对起点"), ...
    '高台小节正文应说明横轴为相对起点的前进距离。');

fig2 = openfig(fullfile(output_dir, 'figure2_step_key_metrics.fig'), 'invisible');
fig2_cleanup = onCleanup(@() close(fig2)); %#ok<NASGU>
axes_list = findall(fig2, 'Type', 'Axes');
chart_axes = axes_list(arrayfun(@(ax) ~isempty(ax.XTickLabel), axes_list));
title_texts = strings(1, 0);
for idx = 1:numel(chart_axes)
    title_texts(end + 1) = string(chart_axes(idx).Title.String); %#ok<AGROW>
end
verifyTrue(testCase, any(title_texts == "通过距离"), ...
    '高台图2 应使用“通过距离”表述。');
verifyTrue(testCase, any(title_texts == "高度增益"), ...
    '高台图2 应使用“高度增益”表述。');
verifyFalse(testCase, any(title_texts == "跨越距离"), ...
    '高台图2 不应继续使用“跨越距离”表述。');
end

function test_step_trajectory_uses_relative_forward_distance(testCase)
project_root = fileparts(fileparts(mfilename('fullpath')));
initialize_project_paths(project_root);
clear hexapod_plot_midterm_step;
rehash;

compare_root = fullfile(tempdir, ['midterm_step_compare_', char(java.util.UUID.randomUUID)]);
output_dir = fullfile(tempdir, ['midterm_step_plot_', char(java.util.UUID.randomUUID)]);
mkdir(compare_root);
mkdir(output_dir);
cleanup_compare = onCleanup(@() cleanup_output_dir(compare_root)); %#ok<NASGU>
cleanup_output = onCleanup(@() cleanup_output_dir(output_dir)); %#ok<NASGU>

write_fake_step_compare_dataset(compare_root);
hexapod_plot_midterm_step(compare_root, output_dir);

fig1 = openfig(fullfile(output_dir, 'figure1_step_trajectory_comparison.fig'), 'invisible');
fig1_cleanup = onCleanup(@() close(fig1)); %#ok<NASGU>
axes_list = findall(fig1, 'Type', 'Axes');
positions = cell2mat(get(axes_list, 'Position'));
if isvector(positions)
    positions = reshape(positions, 1, []);
end
left_ax = axes_list(argmin(positions(:, 1)));

verifyEqual(testCase, string(left_ax.XLabel.String), "机身前进距离 x / m", ...
    '高台轨迹图横轴应统一为相对起点的前进距离。');

line_objects = findall(left_ax, 'Type', 'Line');
curve_lines = line_objects(arrayfun(@(line_obj) isempty(line_obj.DisplayName), line_objects));
for idx = 1:numel(curve_lines)
    verifyEqual(testCase, curve_lines(idx).XData(1), 0, 'AbsTol', 1e-9, ...
        '高台轨迹图横轴应相对真实起点归一化。');
end

guide_lines = findall(left_ax, 'Type', 'ConstantLine');
verifyEqual(testCase, numel(guide_lines), 1, ...
    '高台轨迹图应只保留“前腿到达台阶前沿”参考线。');
verifyEqual(testCase, guide_lines(1).Value, 0.425, 'AbsTol', 1e-9, ...
    '高台轨迹图参考线位置应按相对起点坐标换算。');
verifyEqual(testCase, string(guide_lines(1).Label), "前腿到达台阶前沿", ...
    '高台轨迹图参考线标签口径不正确。');
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

function write_fake_step_compare_dataset(compare_root)
mkdir(fullfile(compare_root, 'step_initial', 'run_01'));
mkdir(fullfile(compare_root, 'step_current', 'run_01'));

tbl = table(["step"; "step"], ["高台"; "高台"], ["initial"; "current"], ["step_initial"; "step_current"], ...
    'VariableNames', {'scene_name', 'scene_label', 'scene_variant', 'case_id'});
writetable(tbl, fullfile(compare_root, 'compare_aggregate_latest3.csv'));

metrics = struct();
metrics.series = struct();
metrics.series.time_s = [0; 1; 2];
metrics.series.realX = [3.8; 4.0; 4.6];
metrics.series.realY = [0; 0.02; 0.03];
metrics.series.realZ = [2.7; 2.8; 3.0];
metrics.series.total_force_N = [100; 120; 110];
save(fullfile(compare_root, 'step_initial', 'run_01', 'metrics.mat'), 'metrics');

metrics.series.realX = [3.8; 4.2; 4.9];
metrics.series.realY = [0; 0.01; 0.01];
metrics.series.realZ = [2.7; 2.9; 3.15];
metrics.series.total_force_N = [90; 100; 95];
save(fullfile(compare_root, 'step_current', 'run_01', 'metrics.mat'), 'metrics');
end

function idx = argmin(values)
[~, idx] = min(values);
end
