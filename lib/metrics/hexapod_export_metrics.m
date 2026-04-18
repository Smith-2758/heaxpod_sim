function [metrics, run_output_dir] = hexapod_export_metrics(project_root, telemetry, meta)
if nargin < 3 || isempty(meta)
    meta = struct();
end

scene_name = get_struct_field(meta, 'scene_name', get_struct_field(meta, 'entry_pattern', 'unknown'));
scene_info = hexapod_scene_info(scene_name);
meta.scene_name = scene_info.scene_name;
if ~isfield(meta, 'scene_label') || isempty(meta.scene_label)
    meta.scene_label = scene_info.scene_label;
end
if ~isfield(meta, 'scene_variant') || isempty(meta.scene_variant)
    meta.scene_variant = scene_info.scene_variant;
end
if ~isfield(meta, 'run_now') || isempty(meta.run_now)
    meta.run_now = now;
end
if ~isfield(meta, 'run_timestamp') || isempty(meta.run_timestamp)
    meta.run_timestamp = datestr(meta.run_now, 'yyyy-mm-dd HH:MM:SS');
end
if ~isfield(meta, 'output_dir') || isempty(meta.output_dir)
    [run_output_dir, run_id] = hexapod_prepare_output_dir(project_root, meta.scene_name, meta.run_now);
    meta.output_dir = run_output_dir;
    meta.run_id = run_id;
else
    run_output_dir = meta.output_dir;
    if ~exist(run_output_dir, 'dir')
        mkdir(run_output_dir);
    end
end

metrics = hexapod_compute_metrics(telemetry, meta);
save(fullfile(run_output_dir, 'metrics.mat'), 'metrics');

plot_paths = export_plots(metrics, run_output_dir);
write_metrics_summary(fullfile(run_output_dir, 'metrics_summary.md'), metrics, plot_paths);
end

function plot_paths = export_plots(metrics, run_output_dir)
plot_paths = struct();
leg_labels = {'右腿1', '右腿2', '右腿3', '左腿1', '左腿2', '左腿3'};
[rel_x, rel_y, rel_z] = normalize_position_series( ...
    metrics.series.realX, metrics.series.realY, metrics.series.realZ);

h1 = figure('Name', '各腿末端受力', 'NumberTitle', 'off', 'Visible', 'off');
for leg_idx = 1:6
    subplot(2, 3, leg_idx);
    plot(metrics.series.leg_force_N(:, leg_idx), 'LineWidth', 1.1);
    title(sprintf('%s受力', leg_labels{leg_idx}));
    xlabel('采样点');
    ylabel('N');
    grid on;
end
plot_paths.leg_force = save_plot_pair(h1, run_output_dir, '01_leg_force');

h2 = figure('Name', '末端总受力', 'NumberTitle', 'off', 'Visible', 'off');
plot(metrics.series.total_force_N, 'LineWidth', 1.1);
title('末端总受力');
xlabel('采样点');
ylabel('N');
grid on;
plot_paths.total_force = save_plot_pair(h2, run_output_dir, '02_total_force');

h3 = figure('Name', '轨迹追踪对比', 'NumberTitle', 'off', 'Visible', 'off');
subplot(3, 1, 1);
plot(metrics.series.time_s, rel_x, 'LineWidth', 1.1);
title('机身 X 相对位移');
xlabel('时间 (s)');
ylabel('\DeltaX (m)');
grid on;
subplot(3, 1, 2);
plot(metrics.series.time_s, rel_y, 'LineWidth', 1.1);
title('机身 Y 相对位移');
xlabel('时间 (s)');
ylabel('\DeltaY (m)');
grid on;
subplot(3, 1, 3);
plot(rel_x, rel_z, 'LineWidth', 1.1);
title('机身 X-Z 相对轨迹');
xlabel('\DeltaX (m)');
ylabel('\DeltaZ (m)');
grid on;
plot_paths.trajectory = save_plot_pair(h3, run_output_dir, '03_trajectory_tracking');

h4 = figure('Name', '机体速度曲线', 'NumberTitle', 'off', 'Visible', 'off');
if isempty(metrics.series.speed_mps)
    axis off;
    text(0.2, 0.5, '速度数据不足，无法生成曲线', 'FontSize', 11);
else
    plot(metrics.series.speed_time_s, metrics.series.speed_mps, 'LineWidth', 1.1);
    title('机体速度曲线');
    xlabel('时间 (s)');
    ylabel('速度 (m/s)');
    grid on;
end
plot_paths.speed = save_plot_pair(h4, run_output_dir, '04_body_speed');

h5 = figure('Name', '机体姿态曲线', 'NumberTitle', 'off', 'Visible', 'off');
plot(metrics.series.time_s, metrics.series.roll_deg, 'LineWidth', 1.1); hold on;
plot(metrics.series.time_s, metrics.series.pitch_deg, 'LineWidth', 1.1);
plot(metrics.series.time_s, metrics.series.yaw_deg, 'LineWidth', 1.1); hold off;
title('机体姿态曲线');
xlabel('时间 (s)');
ylabel('角度 (deg)');
legend({'roll', 'pitch', 'yaw'}, 'Location', 'best');
grid on;
plot_paths.attitude = save_plot_pair(h5, run_output_dir, '05_body_attitude');

h6 = figure('Name', 'ZMP Stability', 'NumberTitle', 'off', 'Visible', 'off');
subplot(3, 1, 1);
plot(metrics.series.time_s, metrics.series.stability_margin, 'LineWidth', 1.1);
title('稳定裕度 SM');
xlabel('时间 (s)');
ylabel('SM (m)');
grid on;

subplot(3, 1, 2);
plot(metrics.series.time_s, metrics.series.zmp_x, 'LineWidth', 1.1); hold on;
plot(metrics.series.time_s, metrics.series.zmp_y, 'LineWidth', 1.1); hold off;
title('ZMP 位置');
xlabel('时间 (s)');
ylabel('位置 (m)');
legend({'zmp\_x', 'zmp\_y'}, 'Location', 'best');
grid on;

subplot(3, 1, 3);
plot(metrics.series.time_s, metrics.series.stance_count, 'LineWidth', 1.1); hold on;
stairs(metrics.series.time_s, double(metrics.series.zmp_inside_polygon_flag), '--', 'LineWidth', 1.0); hold off;
title('支撑腿数量与 ZMP 是否在多边形内');
xlabel('时间 (s)');
ylabel('计数 / 标志');
legend({'stance\_count', 'inside\_polygon'}, 'Location', 'best');
grid on;
plot_paths.zmp_stability = save_plot_pair(h6, run_output_dir, '06_zmp_stability');
end

function paths = save_plot_pair(fig_handle, run_output_dir, base_name)
png_path = fullfile(run_output_dir, [base_name, '.png']);
fig_path = fullfile(run_output_dir, [base_name, '.fig']);
saveas(fig_handle, png_path);
savefig(fig_handle, fig_path);
close(fig_handle);
paths = struct('png', png_path, 'fig', fig_path);
end

function [rel_x, rel_y, rel_z] = normalize_position_series(x, y, z)
rel_x = x;
rel_y = y;
rel_z = z;

if isempty(x) || isempty(y) || isempty(z)
    return;
end

valid_idx = find(~(isnan(x) | isnan(y) | isnan(z)), 1, 'first');
if isempty(valid_idx)
    return;
end

rel_x = x - x(valid_idx);
rel_y = y - y(valid_idx);
rel_z = z - z(valid_idx);
end

function write_metrics_summary(md_path, metrics, plot_paths)
fid = fopen(md_path, 'w', 'n', 'UTF-8');
if fid == -1
    warning('无法写入指标摘要文件: %s', md_path);
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# Hexapod Metrics Summary\n\n');
fprintf(fid, '## 场景信息\n\n');
fprintf(fid, '- 场景类别: `%s`\n', metrics.meta.scene_name);
fprintf(fid, '- 场景名称: %s\n', metrics.meta.scene_label);
fprintf(fid, '- 方案标识: `%s`\n', metrics.meta.scene_variant);
fprintf(fid, '- 来源流程: `%s`\n', metrics.meta.source_flow);
fprintf(fid, '- 入口动作: `%s`\n', metrics.meta.entry_pattern);
fprintf(fid, '- 运行时间: %s\n', metrics.meta.run_timestamp);
fprintf(fid, '- 输出目录: `%s`\n', metrics.meta.output_dir);
fprintf(fid, '- 控制周期: %.3f s\n', metrics.meta.control_dt_sec);
fprintf(fid, '- 样本数: %d\n', metrics.meta.sample_count);
write_optional_meta(fid, '实验组', get_struct_field(metrics.meta, 'compare_group_id', ''));
write_optional_meta(fid, 'Case ID', get_struct_field(metrics.meta, 'case_id', ''));
write_optional_meta(fid, 'Case 描述', get_struct_field(metrics.meta, 'case_description', ''));
write_optional_meta(fid, '重复序号', render_numeric(get_struct_field(metrics.meta, 'repeat_index', NaN)));
write_optional_meta(fid, '目标总帧数', render_numeric(get_struct_field(metrics.meta, 'target_total_frames', NaN)));
write_optional_meta(fid, '原始总帧数', render_numeric(get_struct_field(metrics.meta, 'natural_total_frames', NaN)));
write_optional_meta(fid, '实际总帧数', render_numeric(get_struct_field(metrics.meta, 'actual_total_frames', NaN)));
write_optional_meta(fid, '帧数归一化策略', get_struct_field(metrics.meta, 'frame_normalization', ''));
write_optional_meta(fid, '轨迹工件', get_struct_field(metrics.meta, 'source_artifact_path', ''));
fprintf(fid, '\n');

fprintf(fid, '## 公共指标\n\n');
write_struct_metrics(fid, metrics.common);

fprintf(fid, '\n## 场景专项指标\n\n');
write_struct_metrics(fid, metrics.scene);

fprintf(fid, '\n## 图表文件\n\n');
plot_fields = fieldnames(plot_paths);
for idx = 1:numel(plot_fields)
    item = plot_paths.(plot_fields{idx});
    fprintf(fid, '- `%s`: `%s`\n', plot_fields{idx}, item.png);
end
end

function write_struct_metrics(fid, values)
fields = fieldnames(values);
for idx = 1:numel(fields)
    field_name = fields{idx};
    field_value = values.(field_name);
    fprintf(fid, '- `%s`: %s\n', field_name, render_value(field_value));
end
end

function write_optional_meta(fid, label_text, value)
if isempty(value)
    return;
end
if isstring(value)
    if all(strlength(value) == 0)
        return;
    end
elseif ischar(value)
    if isempty(strtrim(value))
        return;
    end
end
fprintf(fid, '- %s: %s\n', label_text, value);
end

function rendered = render_numeric(value)
if isempty(value) || (isnumeric(value) && isnan(value))
    rendered = '';
elseif isnumeric(value)
    rendered = sprintf('%.0f', value);
else
    rendered = char(string(value));
end
end

function rendered = render_decimal(value)
if isempty(value) || (isnumeric(value) && isnan(value))
    rendered = '';
elseif isnumeric(value)
    rendered = sprintf('%.3f', value);
else
    rendered = char(string(value));
end
end

function rendered = render_value(field_value)
if isnumeric(field_value) && isscalar(field_value)
    if isnan(field_value)
        rendered = 'NaN';
    else
        rendered = sprintf('%.6f', field_value);
    end
elseif ischar(field_value)
    rendered = field_value;
elseif isstring(field_value) && isscalar(field_value)
    rendered = char(field_value);
else
    rendered = '[complex value]';
end
end

function value = get_struct_field(s, field_name, default_value)
if isstruct(s) && isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end
