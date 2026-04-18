%% =====================================================================
% walk_slope_3m_4m_3m.m
%
% Generate a six-leg walking trajectory for a 15 deg terrain made of:
% flat -> 3 m uphill -> 4 m top platform -> 3 m downhill -> flat.
%
% Output:
%   export_data/walk_slope_3m_4m_3m.mat
%   variables: joint, xb, zb, pitch0
%% =====================================================================
clearvars; close all; clc
addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

%% Basic parameters
body_x = 3.8;   % Must match CoppeliaSim initial position(1)
body_y = 0;
body_z = 0;

x01 = 1.75 + body_x;
x02 = 0    + body_x;
x03 = -1.75 + body_x;
yr0 = -2.23 + body_y;
yl0 =  2.23 + body_y;
zf0 = -2.05 + body_z;

v = 0.30;
tt = abs(0.9 / 6 / v);
foott = tt * 2;
stept = foott + foott + foott;

step0 = v * stept;
step1 = step0 / 2;
steph = 0.3;

%% Terrain constants
slope_angle = 15 * pi / 180;
slope_up_start_x = 5.975;
slope_top_start_x = slope_up_start_x + 3.0;
slope_top_end_x = slope_top_start_x + 4.0;
slope_down_end_x = slope_top_end_x + 3.0;
slope_top_height = (slope_top_start_x - slope_up_start_x) * tan(slope_angle);

body_half_length = 1.75;
body_front_offset_x = body_half_length;
body_rear_offset_x = body_half_length;

slope_coeff_start = 0.2;
slope_coeff_end = 0.7;
recovery_margin_x = 1.0;
post_flat_stop_margin_x = 2.5;

%% Time axis (same phase structure as walk_slope.m, extended to finish recovery)
min_duration = ((slope_down_end_x + body_half_length + recovery_margin_x) - body_x) / v;
t_total = max(30, ceil(min_duration / stept) * stept);

k = fix(t_total / stept);
t = zeros(1, 6 * k + 1);
for i = 0:k-1
    t(6 * i + 1) = stept * i;
    t(6 * i + 2) = stept * i + tt;
    t(6 * i + 3) = stept * i + foott;
    t(6 * i + 4) = stept * i + foott + tt;
    t(6 * i + 5) = stept * i + foott * 2;
    t(6 * i + 6) = stept * i + foott * 2 + tt;
end
t(6 * k + 1) = stept * k;

%% Base trajectory initialization
xbb = zeros(1, length(t));
ybb = body_y * ones(1, length(t));
zbb = body_z * ones(1, length(t));

%% Foot Y/Z initialization
y = zeros(6, length(t));
for ii = 1:length(t)
    y(1, ii) = yr0; y(2, ii) = yr0; y(3, ii) = yr0;
    y(4, ii) = yl0; y(5, ii) = yl0; y(6, ii) = yl0;
end

z = zf0 * ones(6, length(t));
for ii = 1:length(t)
    if mod(ii, 6) == 2
        z(1, ii) = zf0 + steph;
        z(6, ii) = zf0 + steph;
    end
    if mod(ii, 6) == 4
        z(3, ii) = zf0 + steph;
        z(4, ii) = zf0 + steph;
    end
    if mod(ii, 6) == 0
        z(2, ii) = zf0 + steph;
        z(5, ii) = zf0 + steph;
    end
end

%% Foot X assignment and stepping loop
x_0 = [x01; x02; x03; x01; x02; x03];
x = repmat(x_0, 1, length(t));

for ii = 1:length(t)
    if mod(ii, 6) == 2
        x(1, ii:end) = x(1, ii:end) + step1;
        x(1, ii+1:end) = x(1, ii+1:end) + step1;
        x(6, ii:end) = x(6, ii:end) + step1;
        x(6, ii+1:end) = x(6, ii+1:end) + step1;
    end
    if mod(ii, 6) == 4
        x(3, ii:end) = x(3, ii:end) + step1;
        x(3, ii+1:end) = x(3, ii+1:end) + step1;
        x(4, ii:end) = x(4, ii:end) + step1;
        x(4, ii+1:end) = x(4, ii+1:end) + step1;
    end
    if mod(ii, 6) == 0
        x(2, ii:end) = x(2, ii:end) + step1;
        x(2, ii+1:end) = x(2, ii+1:end) + step1;
        x(5, ii:end) = x(5, ii:end) + step1;
        x(5, ii+1:end) = x(5, ii+1:end) + step1;
    end

    for jj = 1:6
        xbb(ii) = xbb(ii) + x(jj, ii) / 6;
    end
end

%% Terrain support height for each foot (flat -> up -> top -> down -> flat)
for ii = 1:length(t)
    for jj = 1:6
        z(jj, ii) = z(jj, ii) + terrain_height_piecewise( ...
            x(jj, ii), slope_up_start_x, slope_top_start_x, ...
            slope_top_end_x, slope_down_end_x, slope_angle, slope_top_height);
    end
end

%% Smooth body pitch and body height across the five terrain stages
pitch_bb = zeros(1, length(t));
coeff_bb = zeros(1, length(t));
terrain_body = zeros(1, length(t));

for ii = 1:length(t)
    x_front = xbb(ii) + body_front_offset_x;
    x_rear = xbb(ii) - body_rear_offset_x;

    z_front = terrain_height_piecewise( ...
        x_front, slope_up_start_x, slope_top_start_x, ...
        slope_top_end_x, slope_down_end_x, slope_angle, slope_top_height);
    z_rear = terrain_height_piecewise( ...
        x_rear, slope_up_start_x, slope_top_start_x, ...
        slope_top_end_x, slope_down_end_x, slope_angle, slope_top_height);

    terrain_body(ii) = 0.5 * (z_front + z_rear);
    terrain_ratio = min(max(terrain_body(ii) / max(slope_top_height, eps), 0), 1);
    coeff_bb(ii) = slope_coeff_start + smoothstep01(terrain_ratio) * (slope_coeff_end - slope_coeff_start);
    zbb(ii) = terrain_body(ii) * coeff_bb(ii);

    pitch_bb(ii) = body_pitch_piecewise( ...
        xbb(ii), body_half_length, slope_up_start_x, slope_top_start_x, ...
        slope_top_end_x, slope_down_end_x, slope_angle);
end

%% Interpolate to continuous timeline
xq = 0:0.005:stept * k;

xhr = makima(t, x);
yhr = makima(t, y);
zhr = makima(t, z);
x0 = ppval(xhr, xq);
y0 = ppval(yhr, xq);
z0 = ppval(zhr, xq);

xhrr = makima(t, xbb);
yhrr = makima(t, ybb);
zhrr = makima(t, zbb);
xb = ppval(xhrr, xq);
yb = ppval(yhrr, xq);
zb = ppval(zhrr, xq);

pitch_hr = makima(t, pitch_bb);
pitch0 = ppval(pitch_hr, xq);

%% Plot checks
figure('Name', 'walk_slope_3m_4m_3m - foot X');
plot(x0'); hold on; plot(xb');
xlabel('step'); ylabel('X (m)'); title('Foot X trajectory');

figure('Name', 'walk_slope_3m_4m_3m - foot Z');
plot(z0');
xlabel('step'); ylabel('Z (m)'); title('Foot Z trajectory');

figure('Name', 'walk_slope_3m_4m_3m - body states');
yyaxis left; plot(zb'); ylabel('Zb (m)');
yyaxis right; plot(pitch0' * 180 / pi); ylabel('Pitch (deg)');
xlabel('step'); title('Body height and pitch');

%% Inverse kinematics
robot = robot3D_description;
joint = zeros(length(xq), 18);
fprintf('Start inverse kinematics (%d frames)...\n', length(xq));
for i = 1:length(xq)
    theta = -pitch0(i);
    Ry = [cos(theta), 0, sin(theta);
          0,          1, 0;
         -sin(theta), 0, cos(theta)];

    for ii = 1:6
        target.R = eye(3);
        target.p = [x0(ii, i); y0(ii, i); z0(ii, i)];

        robot(1).p = [xb(i); yb(i); zb(i)];
        robot(1).R = Ry;

        c_id = [1 + 3 * ii, 1];
        robot = ik_collision(robot, target, c_id);
        for jj = 1:3
            joint(i, jj + 3 * ii - 3) = robot(jj + 3 * ii - 2).q;
        end
    end

    if mod(i, 500) == 0
        fprintf('  progress: %d/%d\n', i, length(xq));
    end
end

%% Save result
[joint, xb, trimmed_extra] = hexapod_trim_trajectory_tail_by_body_x( ...
    joint, xb, slope_down_end_x + post_flat_stop_margin_x, struct('zb', zb, 'pitch0', pitch0));
zb = trimmed_extra.zb;
pitch0 = trimmed_extra.pitch0;

saveDir = fullfile(fileparts(mfilename('fullpath')), 'export_data');
if ~exist(saveDir, 'dir')
    mkdir(saveDir);
end
save(fullfile(saveDir, 'walk_slope_3m_4m_3m.mat'), 'joint', 'xb', 'zb', 'pitch0');
fprintf('Saved export_data/walk_slope_3m_4m_3m.mat (%d frames).\n', size(joint, 1));

function h = terrain_height_piecewise(x_world, slope_up_start_x, slope_top_start_x, slope_top_end_x, slope_down_end_x, slope_angle, slope_top_height)
if x_world <= slope_up_start_x
    h = 0;
elseif x_world <= slope_top_start_x
    h = (x_world - slope_up_start_x) * tan(slope_angle);
elseif x_world <= slope_top_end_x
    h = slope_top_height;
elseif x_world <= slope_down_end_x
    h = slope_top_height - (x_world - slope_top_end_x) * tan(slope_angle);
else
    h = 0;
end
end

function pitch = body_pitch_piecewise(x_body, body_half_length, slope_up_start_x, slope_top_start_x, slope_top_end_x, slope_down_end_x, slope_angle)
up_start = slope_up_start_x - body_half_length;
up_end = slope_up_start_x + body_half_length;
top_start = slope_top_start_x - body_half_length;
top_end = slope_top_start_x + body_half_length;
down_start = slope_top_end_x - body_half_length;
down_end = slope_top_end_x + body_half_length;
recover_start = slope_down_end_x - body_half_length;
recover_end = slope_down_end_x + body_half_length;

if x_body <= up_start
    pitch = 0;
elseif x_body <= up_end
    p = (x_body - up_start) / (up_end - up_start);
    pitch = smoothstep01(p) * slope_angle;
elseif x_body <= top_start
    pitch = slope_angle;
elseif x_body <= top_end
    p = (x_body - top_start) / (top_end - top_start);
    pitch = slope_angle * (1 - smoothstep01(p));
elseif x_body <= down_start
    pitch = 0;
elseif x_body <= down_end
    p = (x_body - down_start) / (down_end - down_start);
    pitch = -smoothstep01(p) * slope_angle;
elseif x_body <= recover_start
    pitch = -slope_angle;
elseif x_body <= recover_end
    p = (x_body - recover_start) / (recover_end - recover_start);
    pitch = -slope_angle * (1 - smoothstep01(p));
else
    pitch = 0;
end
end

function y = smoothstep01(x)
x = min(max(x, 0), 1);
y = 3 * x.^2 - 2 * x.^3;
end
