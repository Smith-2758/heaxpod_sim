function metrics = hexapod_compute_metrics(telemetry, meta)
if nargin < 2 || isempty(meta)
    meta = struct();
end

scene_name = get_struct_field(meta, 'scene_name', 'unknown');
scene_info = hexapod_scene_info(scene_name);
meta = fill_meta_defaults(meta, scene_info, telemetry);

x = make_column(get_struct_field(telemetry, 'realX', []));
y = make_column(get_struct_field(telemetry, 'realY', []));
z = make_column(get_struct_field(telemetry, 'realZ', []));

sample_count = min_positive_length([numel(x), numel(y), numel(z)]);
if sample_count == 0
    x = zeros(0, 1);
    y = zeros(0, 1);
    z = zeros(0, 1);
else
    x = x(1:sample_count);
    y = y(1:sample_count);
    z = z(1:sample_count);
end

dt = get_control_dt_sec(telemetry, meta);
body_euler = align_matrix(get_struct_field(telemetry, 'bodyEulerDeg', []), sample_count, 3, NaN);
leg_force = align_matrix(get_struct_field(telemetry, 'legForceMag', []), sample_count, 6, NaN);
foot_pos_xyz = align_matrix(get_struct_field(telemetry, 'footPosXYZ', []), sample_count, 18, NaN);
leg_force_xyz = align_matrix(get_struct_field(telemetry, 'legForceXYZ', []), sample_count, 18, NaN);
[x, y, z, body_euler, leg_force] = trim_leading_position_placeholders(x, y, z, body_euler, leg_force);
sample_count = numel(x);

foot_pos_xyz = align_matrix(foot_pos_xyz, sample_count, 18, NaN);
leg_force_xyz = align_matrix(leg_force_xyz, sample_count, 18, NaN);

time_s = ((0:sample_count - 1)' .* dt);
valid_pos_mask = ~(isnan(x) | isnan(y) | isnan(z));
valid_pos = [x(valid_pos_mask), y(valid_pos_mask), z(valid_pos_mask)];

if size(valid_pos, 1) >= 2
    delta_pos = diff(valid_pos, 1, 1);
    step_distance = sqrt(sum(delta_pos .^ 2, 2));
    speed_series = step_distance ./ max(dt, eps);
    track_distance_m = sum(step_distance);
    delta_net = valid_pos(end, :) - valid_pos(1, :);
    net_displacement_m = sqrt(sum(delta_net .^ 2));
    path_efficiency = net_displacement_m / max(track_distance_m, eps);
    avg_speed_mps = track_distance_m / max((size(valid_pos, 1) - 1) * dt, eps);
    peak_speed_mps = max(speed_series);
else
    speed_series = zeros(0, 1);
    track_distance_m = NaN;
    net_displacement_m = NaN;
    path_efficiency = NaN;
    avg_speed_mps = NaN;
    peak_speed_mps = NaN;
end

roll_deg = body_euler(:, 1);
pitch_deg = body_euler(:, 2);
yaw_deg = body_euler(:, 3);

total_force_series = sum_without_nan(leg_force, 2);
leg_force_peak_N = max_without_nan(leg_force(:));
time_speed_s = ((1:numel(speed_series))' .* dt);
stage_mask = false(sample_count, 1);

zmp_cfg = hexapod_zmp_defaults();
[zmp_x, zmp_y, stance_count, zmp_inside_polygon_flag, polygon_valid, ...
    stability_margin, front_margin, lateral_offset] = ...
    compute_zmp_metrics_series(foot_pos_xyz, leg_force_xyz, leg_force, zmp_cfg);

common = struct();
common.success_flag = 0;
common.track_distance_m = track_distance_m;
common.net_displacement_m = net_displacement_m;
common.path_efficiency = path_efficiency;
common.avg_speed_mps = avg_speed_mps;
common.peak_speed_mps = peak_speed_mps;
common.pitch_peak_deg = max_abs_without_nan(pitch_deg);
common.roll_peak_deg = max_abs_without_nan(roll_deg);
common.yaw_peak_deg = max_abs_without_nan(yaw_deg);
common.pitch_rms_deg = rms_without_nan(pitch_deg);
common.roll_rms_deg = rms_without_nan(roll_deg);
common.yaw_drift_deg = yaw_drift_deg(yaw_deg);
common.total_force_peak_N = max_without_nan(total_force_series);
common.total_force_rms_N = rms_without_nan(total_force_series);
common.leg_force_peak_N = leg_force_peak_N;
common.zmp_margin_min_m = min_without_nan(stability_margin);
common.zmp_margin_mean_m = mean_without_nan(stability_margin);
common.zmp_critical_frame_ratio = mean_logical_without_nan(stability_margin < zmp_cfg.SM_critical, stability_margin);
common.zmp_outside_count = sum_logical_without_nan(stability_margin < 0, stability_margin);
common.stance_count_mean = mean_without_nan(stance_count);

scene = struct();
valid_indices = find(valid_pos_mask);

switch scene_info.scene_name
    case 'slope'
        slope_progress_m = delta_along_axis(valid_pos(:, 1));
        climb_height_gain_m = delta_along_axis(valid_pos(:, 3));
        backslide_distance_m = positive_sum(-diff(valid_pos(:, 1)));
        stage_mask = progress_stage_mask(x, valid_pos_mask, scene_info.stage_progress_range);

        scene.climb_height_gain_m = climb_height_gain_m;
        scene.backslide_distance_m = backslide_distance_m;
        scene.slope_progress_m = slope_progress_m;
        scene.slope_stage_pitch_peak_deg = max_abs_without_nan(pitch_deg(stage_mask));
        scene.slope_stage_roll_peak_deg = max_abs_without_nan(roll_deg(stage_mask));
        common.success_flag = double(slope_progress_m > 0.5 && climb_height_gain_m > 0.05);

    case 'step'
        step_height_gain_m = delta_along_axis(valid_pos(:, 3));
        step_crossing_distance_m = delta_along_axis(valid_pos(:, 1));
        stage_mask = transition_window_mask(z, valid_pos_mask);
        scene.step_height_gain_m = step_height_gain_m;
        scene.step_crossing_distance_m = step_crossing_distance_m;
        scene.vertical_smoothness_idx = vertical_smoothness_idx(valid_pos(:, 3));
        scene.edge_force_peak_N = max_without_nan(total_force_series(stage_mask));
        scene.step_stage_pitch_peak_deg = max_abs_without_nan(pitch_deg(stage_mask));
        scene.step_stage_roll_peak_deg = max_abs_without_nan(roll_deg(stage_mask));
        common.success_flag = double(step_crossing_distance_m > 0.5 && step_height_gain_m > 0.05);

    case 'ditch'
        if sample_count > 0
            lateral_drift = max_without_nan(abs(y - y(1)));
        else
            lateral_drift = NaN;
        end
        ditch_crossing_distance_m = delta_along_axis(valid_pos(:, 1));
        stage_mask = ditch_stage_mask(x, valid_pos_mask, scene_info.ditch_crossing_x);
        extra = get_struct_field(telemetry, 'extra', struct());
        scene.max_lateral_drift_m = lateral_drift;
        scene.ditch_crossing_distance_m = ditch_crossing_distance_m;
        scene.ditch_stage_pitch_peak_deg = max_abs_without_nan(pitch_deg(stage_mask));
        scene.ditch_stage_roll_peak_deg = max_abs_without_nan(roll_deg(stage_mask));
        scene.recover_count_total = get_struct_field(extra, 'recover_count_total', NaN);
        scene.zmp_freeze_count = sum(get_struct_field(extra, 'zmp_freeze_flag', zeros(sample_count, 1)) > 0);
        scene.zmp_yaw_assist_peak_deg = max_abs_without_nan(get_struct_field(extra, 'zmp_yaw_assist_deg', NaN(sample_count, 1)));
        scene.zmp_x_guard_peak_m = max_abs_without_nan(get_struct_field(extra, 'zmp_x_guard_m', NaN(sample_count, 1)));
        common.success_flag = double(~isempty(valid_pos) && valid_pos(end, 1) >= scene_info.ditch_crossing_x(2));

    otherwise
        if ~isempty(valid_indices)
            stage_mask(valid_indices) = true;
        end
        common.success_flag = double(~isempty(valid_pos));
end

if ~any(stage_mask) && ~isempty(valid_indices)
    stage_mask(valid_indices) = true;
end

meta.sample_count = sample_count;
meta.actual_total_frames = sample_count;
meta.valid_position_samples = numel(valid_indices);
meta.control_dt_sec = dt;

metrics = struct();
metrics.meta = meta;
metrics.common = common;
metrics.scene = scene;
metrics.series = struct();
metrics.series.time_s = time_s;
metrics.series.speed_time_s = time_speed_s;
metrics.series.speed_mps = speed_series;
metrics.series.realX = x;
metrics.series.realY = y;
metrics.series.realZ = z;
metrics.series.roll_deg = roll_deg;
metrics.series.pitch_deg = pitch_deg;
metrics.series.yaw_deg = yaw_deg;
metrics.series.leg_force_N = leg_force;
metrics.series.total_force_N = total_force_series;
metrics.series.scene_stage_mask = stage_mask;
metrics.series.zmp_x = zmp_x;
metrics.series.zmp_y = zmp_y;
metrics.series.stance_count = stance_count;
metrics.series.zmp_inside_polygon_flag = zmp_inside_polygon_flag;
metrics.series.polygon_valid = polygon_valid;
metrics.series.stability_margin = stability_margin;
metrics.series.front_margin = front_margin;
metrics.series.lateral_offset = lateral_offset;
end

function [zmp_x, zmp_y, stance_count, zmp_inside_polygon_flag, polygon_valid, ...
    stability_margin, front_margin, lateral_offset] = compute_zmp_metrics_series(foot_pos_xyz, leg_force_xyz, leg_force_mag, zmp_cfg)
sample_count = size(foot_pos_xyz, 1);
zmp_x = NaN(sample_count, 1);
zmp_y = NaN(sample_count, 1);
stance_count = NaN(sample_count, 1);
zmp_inside_polygon_flag = false(sample_count, 1);
polygon_valid = false(sample_count, 1);
stability_margin = NaN(sample_count, 1);
front_margin = NaN(sample_count, 1);
lateral_offset = NaN(sample_count, 1);

prev_stance_mask = false(1, 6);

for idx = 1:sample_count
    foot_frame_flat = foot_pos_xyz(idx, :);
    force_frame_flat = leg_force_xyz(idx, :);
    if any(isnan(foot_frame_flat)) || any(isnan(force_frame_flat))
        continue;
    end

    foot_frame = reshape(foot_frame_flat, 3, 6).';
    force_frame = reshape(force_frame_flat, 3, 6).';

    if idx <= size(leg_force_mag, 1)
        force_mag_frame = leg_force_mag(idx, :);
    else
        force_mag_frame = vecnorm(force_frame, 2, 2).';
    end

    [stance_mask_frame, stance_count_frame] = hexapod_detect_stance_legs(force_mag_frame, prev_stance_mask, zmp_cfg);
    prev_stance_mask = stance_mask_frame;

    zmp_eval = hexapod_compute_quasistatic_zmp(foot_frame, force_frame, stance_mask_frame, zmp_cfg);
    margin_eval = hexapod_compute_stability_margin(zmp_eval.support_xy, zmp_eval.zmp_xy);

    zmp_x(idx) = zmp_eval.zmp_xy(1);
    zmp_y(idx) = zmp_eval.zmp_xy(2);
    stance_count(idx) = stance_count_frame;
    zmp_inside_polygon_flag(idx) = margin_eval.zmp_inside_polygon_flag;
    polygon_valid(idx) = margin_eval.polygon_valid;
    stability_margin(idx) = margin_eval.stability_margin;
    front_margin(idx) = margin_eval.front_margin;
    lateral_offset(idx) = margin_eval.lateral_offset;
end
end

function meta = fill_meta_defaults(meta, scene_info, telemetry)
meta.scene_name = get_struct_field(meta, 'scene_name', scene_info.scene_name);
meta.scene_label = get_struct_field(meta, 'scene_label', scene_info.scene_label);
meta.scene_variant = get_struct_field(meta, 'scene_variant', scene_info.scene_variant);
meta.source_flow = get_struct_field(meta, 'source_flow', 'unknown');
meta.entry_pattern = get_struct_field(meta, 'entry_pattern', scene_info.raw_scene_name);
meta.run_timestamp = get_struct_field(meta, 'run_timestamp', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
meta.output_dir = get_struct_field(meta, 'output_dir', '');
meta.compare_group_id = get_struct_field(meta, 'compare_group_id', '');
meta.case_id = get_struct_field(meta, 'case_id', meta.source_flow);
meta.case_description = get_struct_field(meta, 'case_description', '');
meta.repeat_index = get_struct_field(meta, 'repeat_index', NaN);
meta.target_total_frames = get_struct_field(meta, 'target_total_frames', NaN);
meta.natural_total_frames = get_struct_field(meta, 'natural_total_frames', NaN);
meta.source_artifact_path = get_struct_field(meta, 'source_artifact_path', '');
meta.frame_normalization = get_struct_field(meta, 'frame_normalization', 'none');
meta.coppeliasim_exe_path = get_struct_field(meta, 'coppeliasim_exe_path', '');
meta.coppeliasim_scene_path = get_struct_field(meta, 'coppeliasim_scene_path', '');
meta.coppeliasim_host = get_struct_field(meta, 'coppeliasim_host', '');
meta.coppeliasim_port = get_struct_field(meta, 'coppeliasim_port', NaN);
meta.coppeliasim_auto_restart = get_struct_field(meta, 'coppeliasim_auto_restart', NaN);
meta.coppeliasim_restart_performed = get_struct_field(meta, 'coppeliasim_restart_performed', NaN);
meta.coppeliasim_startup_wait_sec = get_struct_field(meta, 'coppeliasim_startup_wait_sec', NaN);
meta.coppeliasim_shutdown_wait_sec = get_struct_field(meta, 'coppeliasim_shutdown_wait_sec', NaN);
meta.coppeliasim_launch_timestamp = get_struct_field(meta, 'coppeliasim_launch_timestamp', '');
if ~isfield(meta, 'control_dt_ms')
    if isfield(telemetry, 'control_dt_sec')
        meta.control_dt_ms = telemetry.control_dt_sec * 1000;
    else
        meta.control_dt_ms = 5;
    end
end
end

function value = get_struct_field(s, field_name, default_value)
if isstruct(s) && isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end

function value = make_column(value)
if isempty(value)
    value = zeros(0, 1);
else
    value = value(:);
end
end

function count = min_positive_length(lengths)
lengths = lengths(lengths > 0);
if isempty(lengths)
    count = 0;
else
    count = min(lengths);
end
end

function matrix = align_matrix(matrix, rows, cols, fill_value)
if nargin < 4
    fill_value = NaN;
end
if isempty(matrix)
    matrix = fill_value * ones(rows, cols);
    return;
end
matrix = double(matrix);
if size(matrix, 2) < cols
    matrix(:, end + 1:cols) = fill_value;
end
if size(matrix, 2) > cols
    matrix = matrix(:, 1:cols);
end
if size(matrix, 1) < rows
    matrix(end + 1:rows, :) = fill_value;
elseif size(matrix, 1) > rows
    matrix = matrix(1:rows, :);
end
end

function dt = get_control_dt_sec(telemetry, meta)
if isfield(telemetry, 'control_dt_sec') && ~isempty(telemetry.control_dt_sec)
    dt = telemetry.control_dt_sec;
elseif isfield(meta, 'control_dt_ms') && ~isempty(meta.control_dt_ms)
    dt = meta.control_dt_ms / 1000;
else
    dt = 0.005;
end
end

function [x, y, z, body_euler, leg_force] = trim_leading_position_placeholders(x, y, z, body_euler, leg_force)
if isempty(x)
    return;
end

valid_mask = ~(isnan(x) | isnan(y) | isnan(z));
valid_indices = find(valid_mask);
if numel(valid_indices) < 2
    return;
end

valid_pos = [x(valid_indices), y(valid_indices), z(valid_indices)];
norms = sqrt(sum(valid_pos .^ 2, 2));
zero_tol = 1e-6;
jump_threshold = 0.5;
first_nonzero_rel = find(norms > zero_tol, 1, 'first');

if isempty(first_nonzero_rel) || first_nonzero_rel <= 1
    return;
end

leading_norms = norms(1:first_nonzero_rel - 1);
if any(leading_norms > zero_tol)
    return;
end

jump_distance = norm(valid_pos(first_nonzero_rel, :) - valid_pos(first_nonzero_rel - 1, :));
if jump_distance < jump_threshold
    return;
end

start_index = valid_indices(first_nonzero_rel);
x = x(start_index:end);
y = y(start_index:end);
z = z(start_index:end);
body_euler = body_euler(start_index:end, :);
leg_force = leg_force(start_index:end, :);
end

function total = sum_without_nan(values, dim)
if isempty(values)
    total = zeros(0, 1);
    return;
end
values(isnan(values)) = 0;
total = sum(values, dim);
end

function value = max_without_nan(values)
values = values(~isnan(values));
if isempty(values)
    value = NaN;
else
    value = max(values);
end
end

function value = min_without_nan(values)
values = values(~isnan(values));
if isempty(values)
    value = NaN;
else
    value = min(values);
end
end

function value = mean_without_nan(values)
values = values(~isnan(values));
if isempty(values)
    value = NaN;
else
    value = mean(values);
end
end

function value = mean_logical_without_nan(mask, reference_values)
valid_mask = ~isnan(reference_values);
if ~any(valid_mask)
    value = NaN;
else
    value = mean(double(mask(valid_mask)));
end
end

function value = sum_logical_without_nan(mask, reference_values)
valid_mask = ~isnan(reference_values);
if ~any(valid_mask)
    value = NaN;
else
    value = sum(double(mask(valid_mask)));
end
end

function value = max_abs_without_nan(values)
values = values(~isnan(values));
if isempty(values)
    value = NaN;
else
    value = max(abs(values));
end
end

function value = rms_without_nan(values)
values = values(~isnan(values));
if isempty(values)
    value = NaN;
else
    value = sqrt(mean(values .^ 2));
end
end

function value = yaw_drift_deg(yaw_deg)
yaw_deg = yaw_deg(~isnan(yaw_deg));
if numel(yaw_deg) < 2
    value = NaN;
    return;
end
delta = yaw_deg(end) - yaw_deg(1);
value = abs(mod(delta + 180, 360) - 180);
end

function value = delta_along_axis(axis_values)
if numel(axis_values) < 2
    value = NaN;
else
    value = axis_values(end) - axis_values(1);
end
end

function value = positive_sum(values)
values = values(values > 0);
if isempty(values)
    value = 0;
else
    value = sum(values);
end
end

function mask = progress_stage_mask(axis_values, valid_pos_mask, range_limits)
mask = false(size(axis_values));
valid_axis = axis_values(valid_pos_mask);
valid_indices = find(valid_pos_mask);
if numel(valid_axis) < 2
    mask(valid_indices) = true;
    return;
end
start_val = valid_axis(1);
end_val = valid_axis(end);
progress = end_val - start_val;
if abs(progress) < eps
    mask(valid_indices) = true;
    return;
end
stage_start = start_val + range_limits(1) * progress;
stage_end = start_val + range_limits(2) * progress;
low_bound = min(stage_start, stage_end);
high_bound = max(stage_start, stage_end);
stage_valid_mask = valid_axis >= low_bound & valid_axis <= high_bound;
if ~any(stage_valid_mask)
    stage_valid_mask(:) = true;
end
mask(valid_indices(stage_valid_mask)) = true;
end

function mask = transition_window_mask(z_values, valid_pos_mask)
mask = false(size(valid_pos_mask));
valid_indices = find(valid_pos_mask);
if isempty(valid_indices)
    return;
end
valid_z = z_values(valid_pos_mask);
if numel(valid_z) < 2
    mask(valid_indices) = true;
    return;
end
z_min = min(valid_z);
z_max = max(valid_z);
if abs(z_max - z_min) < eps
    mask(valid_indices) = true;
    return;
end
threshold = z_min + 0.25 * (z_max - z_min);
window_mask = valid_z >= threshold;
if ~any(window_mask)
    window_mask(:) = true;
end
mask(valid_indices(window_mask)) = true;
end

function idx = vertical_smoothness_idx(z_values)
if numel(z_values) < 3
    idx = NaN;
    return;
end
second_diff = diff(z_values, 2);
idx = rms_without_nan(second_diff);
end

function mask = ditch_stage_mask(axis_values, valid_pos_mask, crossing_range)
mask = false(size(valid_pos_mask));
valid_indices = find(valid_pos_mask);
if isempty(valid_indices)
    return;
end
valid_axis = axis_values(valid_pos_mask);
low_bound = min(crossing_range);
high_bound = max(crossing_range);
stage_valid_mask = valid_axis >= low_bound & valid_axis <= high_bound;
if ~any(stage_valid_mask)
    stage_valid_mask(:) = true;
end
mask(valid_indices(stage_valid_mask)) = true;
end
