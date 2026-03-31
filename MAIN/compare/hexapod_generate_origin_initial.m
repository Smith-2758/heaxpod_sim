function [joint, info] = hexapod_generate_origin_initial(scene_name, options)
if nargin < 2 || isempty(options)
    options = struct();
end

scene_info = hexapod_scene_info(scene_name);
scene_key = scene_info.scene_name;
config = build_config(scene_key);
info = config;
info.scene_name = scene_key;
info.scene_label = scene_info.scene_label;
info.scene_variant = [scene_key, '_initial'];
info.frame_normalization = 'none';

if get_option(options, 'probe_only', false)
    joint = [];
    return;
end

project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(project_root));

[t, x, y, z, xbb, ybb, zbb] = build_base_gait(config);
switch scene_key
    case 'step'
        [x, z, zbb] = apply_step_initial(x, z, xbb, zbb, config);
    case 'ditch'
        x = apply_ditch_initial(x, z, config);
        xbb = mean(x, 1);
    otherwise
        error('hexapod_generate_origin_initial:UnsupportedScene', '不支持的场景: %s', scene_key);
end

xq = 0:config.sample_dt:(config.stept * config.k);
x0 = ppval(makima(t, x), xq);
y0 = ppval(makima(t, y), xq);
z0 = ppval(makima(t, z), xq);
xb = ppval(makima(t, xbb), xq);
yb = ppval(makima(t, ybb), xq);
zb = ppval(makima(t, zbb), xq);

joint = solve_joint_trajectory(x0, y0, z0, xb, yb, zb);
info.natural_total_frames = size(joint, 1);

target_total_frames = get_option(options, 'target_total_frames', info.natural_total_frames);
if ~isempty(target_total_frames) && target_total_frames ~= info.natural_total_frames
    joint = hexapod_resample_joint_matrix(joint, target_total_frames);
    info.frame_normalization = 'resampled_joint';
end
info.target_total_frames = size(joint, 1);
end

function config = build_config(scene_key)
config = struct();
config.walklength = 5;
config.body_y = 0;
config.body_z = 0;
config.sample_dt = 0.005;
config.v = 0.28;
config.t_total = 20;
config.steph = 0.3;
config.body_x = 0;
config.step_edge_x = 5.975;
config.step_height = 0.5;
config.pit_edge_x = 1.5;

switch scene_key
    case 'step'
        config.body_x = 3.8;
    case 'ditch'
        config.body_x = -0.75;
    otherwise
        error('hexapod_generate_origin_initial:UnsupportedScene', '不支持的场景: %s', scene_key);
end

config.x01 = 1.75 + config.body_x;
config.x02 = 0 + config.body_x;
config.x03 = -1.75 + config.body_x;
config.yr0 = -2.23 + config.body_y;
config.yl0 = 2.23 + config.body_y;
config.zf0 = -2.05 + config.body_z;
config.tt = abs(0.9 / 6 / config.v);
config.foott = config.tt * 2;
config.stept = config.foott * 3;
config.step0 = config.v * config.stept;
config.step1 = config.step0 / 2;
config.k = fix(config.t_total / config.stept);
config.natural_total_frames = numel(0:config.sample_dt:(config.stept * config.k));
end

function [t, x, y, z, xbb, ybb, zbb] = build_base_gait(config)
t = zeros(1, 6 * config.k + 1);
for i = 0:config.k - 1
    t(6 * i + 1) = config.stept * i;
    t(6 * i + 2) = config.stept * i + config.tt;
    t(6 * i + 3) = config.stept * i + config.foott;
    t(6 * i + 4) = config.stept * i + config.foott + config.tt;
    t(6 * i + 5) = config.stept * i + config.foott * 2;
    t(6 * i + 6) = config.stept * i + config.foott * 2 + config.tt;
end
t(6 * config.k + 1) = config.stept * config.k;

xbb = zeros(1, numel(t));
ybb = config.body_y * ones(1, numel(t));
zbb = config.body_z * ones(1, numel(t));

y = zeros(6, numel(t));
y(1:3, :) = config.yr0;
y(4:6, :) = config.yl0;

z = config.zf0 * ones(6, numel(t));
for ii = 1:numel(t)
    if mod(ii, 6) == 2
        z([1, 6], ii) = config.zf0 + config.steph;
    end
    if mod(ii, 6) == 4
        z([3, 4], ii) = config.zf0 + config.steph;
    end
    if mod(ii, 6) == 0
        z([2, 5], ii) = config.zf0 + config.steph;
    end
end

x0 = [config.x01; config.x02; config.x03; config.x01; config.x02; config.x03];
x = repmat(x0, 1, numel(t));
for ii = 1:numel(t)
    if mod(ii, 6) == 2
        x = apply_pair_motion(x, [1, 6], ii, config.step1, config.step1);
    end
    if mod(ii, 6) == 4
        x = apply_pair_motion(x, [3, 4], ii, config.step1, config.step1);
    end
    if mod(ii, 6) == 0
        x = apply_pair_motion(x, [2, 5], ii, config.step1, config.step1);
    end
end
xbb = mean(x, 1);
end

function [x, z, zbb] = apply_step_initial(x, z, xbb, zbb, config)
dais = config.step_edge_x;
wh = config.step_height;
body_rise_per_phase = wh / max((5 / max(config.v, eps)) / config.tt, 1);

for ii = 1:size(x, 2)
    if ii > 1
        zbb(ii) = zbb(ii - 1);
    end
    if xbb(ii) < (dais - 2.5) && xbb(ii) > (dais - 7.5)
        zbb(ii) = zbb(ii) + body_rise_per_phase;
    end
    zbb(ii) = min(zbb(ii), wh);

    for jj = 1:6
        if x(jj, ii) >= dais
            z(jj, ii) = z(jj, ii) + wh;
        end
    end
end
end

function x = apply_ditch_initial(x, z, config)
x_pit = config.pit_edge_x;
l_pit = (0.8 + 0.2 + 0.1 * 2) / 2;
l_pit0 = 1.75 / 2 - l_pit;
kk = [];
for idx = 1:size(x, 2)
    if x(6, idx) > x_pit && z(6, idx) == config.zf0
        kk = idx;
        break;
    end
end
if isempty(kk)
    error('hexapod_generate_origin_initial:DitchTriggerNotFound', '未找到深沟基线触发点。');
end

s = x(6, kk) - x_pit;
phase_ranges = { ...
    max(1, kk - 1):min(size(x, 2), kk + 4), ...
    max(1, kk + 5):min(size(x, 2), kk + 10), ...
    max(1, kk + 11):min(size(x, 2), kk + 16), ...
    max(1, kk + 17):min(size(x, 2), kk + 22), ...
    max(1, kk + 23):min(size(x, 2), kk + 28), ...
    max(1, kk + 29):min(size(x, 2), kk + 34), ...
    max(1, kk + 35):min(size(x, 2), kk + 40)};

for ii = phase_ranges{1}
    x = apply_phase_offset(x, ii, -s, 'align');
end
for ii = phase_ranges{2}
    x = apply_phase_offset(x, ii, l_pit - config.step1, 'step');
end
for ii = phase_ranges{3}
    x = apply_phase_offset(x, ii, l_pit0 - config.step1, 'step');
end
for ii = phase_ranges{4}
    x = apply_phase_offset(x, ii, l_pit - config.step1, 'step');
end
for ii = phase_ranges{5}
    x = apply_phase_offset(x, ii, l_pit0 - config.step1, 'step');
end
for ii = phase_ranges{6}
    x = apply_phase_offset(x, ii, l_pit - config.step1, 'step');
end
for ii = phase_ranges{7}
    x = apply_phase_offset(x, ii, l_pit0 - config.step1, 'step');
end
end

function x = apply_phase_offset(x, ii, delta_value, mode_name)
leg_ids = [];
switch mod(ii, 6)
    case 2
        leg_ids = [1, 6];
    case 4
        leg_ids = [3, 4];
    case 0
        leg_ids = [2, 5];
end
if isempty(leg_ids)
    return;
end
if strcmp(mode_name, 'align')
    x = apply_aligned_offset(x, ii, leg_ids, delta_value);
else
    x = apply_pair_motion(x, leg_ids, ii, delta_value, delta_value);
end
end

function x = apply_pair_motion(x, leg_ids, ii, delta_now, delta_future)
x(leg_ids, ii:end) = x(leg_ids, ii:end) + delta_now;
if ii + 1 <= size(x, 2)
    x(leg_ids, ii + 1:end) = x(leg_ids, ii + 1:end) + delta_future;
end
end

function x = apply_aligned_offset(x, ii, leg_ids, delta)
x(leg_ids, ii:end) = x(leg_ids, ii:end) + delta;
end

function joint = solve_joint_trajectory(x0, y0, z0, xb, yb, zb)
robot = robot3D_description;
joint = zeros(size(x0, 2), 18);
for i = 1:size(x0, 2)
    for leg = 1:6
        Target.R = eye(3);
        Target.p = [x0(leg, i); y0(leg, i); z0(leg, i)];
        robot(1).p = [xb(i); yb(i); zb(i)];
        c_id = [1 + 3 * leg, 1];
        robot = ik_collision(robot, Target, c_id);
        for jj = 1:3
            joint(i, jj + 3 * leg - 3) = robot(jj + 3 * leg - 2).q;
        end
    end
end
end

function value = get_option(options, field_name, default_value)
if isstruct(options) && isfield(options, field_name)
    value = options.(field_name);
else
    value = default_value;
end
end
