%% =====================================================================
%  walk_step_platform5m.m
%
%  Offline trajectory generator for a hexapod walking from flat ground,
%  climbing onto a high step, traversing a 5.3 m platform, descending from
%  the far edge, and recovering back to flat-ground gait.
%
%  Output:
%  - export_data/walk_step_platform5m.mat
%  - saved variable: joint (Nx18, rad)
%% =====================================================================
clear all; close all; clc
addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

%% Basic parameters
walklength = 10;
wl = 3;

% Body pose must stay aligned with the CoppeliaSim initial position.
body_x = 3.8;
body_y = 0;
body_z = 0;

% Foot initial positions (R1, R2, R3, L1, L2, L3).
x01 = 1.75 + body_x;
x02 = 0 + body_x;
x03 = -1.75 + body_x;
yr0 = -2.23 + body_y;
yl0 = 2.23 + body_y;
zf0 = -2.05 + body_z;

% Gait timing follows walk3step_high.m.
v = 0.35;
t_total = 32;
tt = abs(0.9 / 6 / v);
foott = tt * 2;
stept = foott + foott + foott;

step0 = v * stept;
step1 = step0 / 2;
steph = 0.3;

%% Terrain geometry
step_up_edge_x = 5.975;
platform_length = 5.3;
platform_end_x = step_up_edge_x + platform_length;
step_down_edge_x = 11.275;
step_down_judgement_x = step_down_edge_x;

if abs(platform_end_x - step_down_edge_x) > 1e-9
    error('Platform geometry mismatch: platform_end_x must match step_down_edge_x.');
end

step_height = 0.5;              % Kept from walk3step_high.m.
zbb_platform = step_height * 0.8;
zbb_descend_prep = zbb_platform * 0.30;
edge_clearance_up   = 0.10;             % Step-up edge clearance (unchanged).
edge_clearance_down = 0.20;             % Step-down edge clearance (larger: apex must clear the step).
edge_window_up      = 0.20;             % Detection window for step-up apex.
edge_window_down    = 0.30;             % Detection window for step-down apex (wider to catch post-edge landings).

% Explicit body phases.
approach_end_x = step_up_edge_x - 1.5;
climb_up_end_x = step_up_edge_x + 2.2;
platform_recover_end_x = min(climb_up_end_x + 0.6, step_down_judgement_x - 2.0);
descend_prep_start_x = step_down_judgement_x - 2.3;
descend_end_x = step_down_judgement_x + 1.8;
flat_recover_end_x = descend_end_x + 0.4;

smoothstep = @(p) (3 * p.^2 - 2 * p.^3);

%% Discrete gait timeline
k = fix(t_total / stept);
for i = 0:k-1
    t(6*i+1) = stept * i;
    t(6*i+2) = stept * i + tt;
    t(6*i+3) = stept * i + foott;
    t(6*i+4) = stept * i + foott + tt;
    t(6*i+5) = stept * i + foott * 2;
    t(6*i+6) = stept * i + foott * 2 + tt;
end
t(6*k+1) = stept * k;

%% Body references
xbb = zeros(1, length(t));
ybb = body_y * ones(1, length(t));
zbb = body_z * ones(1, length(t));

%% Foot Y/Z initialization
y = zeros(6, length(t));
for ii = 1:length(t)
    y(1,ii) = yr0;
    y(2,ii) = yr0;
    y(3,ii) = yr0;
    y(4,ii) = yl0;
    y(5,ii) = yl0;
    y(6,ii) = yl0;
end

z = zf0 * ones(6, length(t));
is_swing = false(6, length(t));
for ii = 1:length(t)
    if mod(ii,6) == 2
        z(1,ii) = zf0 + steph;
        z(6,ii) = zf0 + steph;
        is_swing(1,ii) = true;
        is_swing(6,ii) = true;
    end
    if mod(ii,6) == 4
        z(3,ii) = zf0 + steph;
        z(4,ii) = zf0 + steph;
        is_swing(3,ii) = true;
        is_swing(4,ii) = true;
    end
    if mod(ii,6) == 0
        z(2,ii) = zf0 + steph;
        z(5,ii) = zf0 + steph;
        is_swing(2,ii) = true;
        is_swing(5,ii) = true;
    end
end

%% Foot X initialization and stepping logic
x_0 = [x01; x02; x03; x01; x02; x03];
x = repmat(x_0, 1, length(t));
for ii = 1:length(t)
    if mod(ii,6) == 2
        x(1,ii:end) = x(1,ii:end) + step1;
        x(1,ii+1:end) = x(1,ii+1:end) + step1;
        x(6,ii:end) = x(6,ii:end) + step1;
        x(6,ii+1:end) = x(6,ii+1:end) + step1;
    end
    if mod(ii,6) == 4
        x(3,ii:end) = x(3,ii:end) + step1;
        x(3,ii+1:end) = x(3,ii+1:end) + step1;
        x(4,ii:end) = x(4,ii:end) + step1;
        x(4,ii+1:end) = x(4,ii+1:end) + step1;
    end
    if mod(ii,6) == 0
        x(2,ii:end) = x(2,ii:end) + step1;
        x(2,ii+1:end) = x(2,ii+1:end) + step1;
        x(5,ii:end) = x(5,ii:end) + step1;
        x(5,ii+1:end) = x(5,ii+1:end) + step1;
    end
    for jj = 1:6
        xbb(ii) = x(jj,ii) / 6 + xbb(ii);
    end
end

%% Terrain support height and body height profile
support_height = zeros(6, length(t));
for ii = 1:length(t)
    % Body Z profile: approach -> climb up -> platform recovery ->
    % platform cruise -> descend prep -> descend -> flat recovery.
    if xbb(ii) <= approach_end_x
        zbb(ii) = 0;
    elseif xbb(ii) <= climb_up_end_x
        p = (xbb(ii) - approach_end_x) / (climb_up_end_x - approach_end_x);
        zbb(ii) = smoothstep(p) * zbb_platform;
    elseif xbb(ii) <= platform_recover_end_x
        zbb(ii) = zbb_platform;
    elseif xbb(ii) <= descend_prep_start_x
        zbb(ii) = zbb_platform;
    elseif xbb(ii) <= step_down_judgement_x
        p = (xbb(ii) - descend_prep_start_x) / (step_down_judgement_x - descend_prep_start_x);
        zbb(ii) = zbb_platform + smoothstep(p) * (zbb_descend_prep - zbb_platform);
    elseif xbb(ii) <= descend_end_x
        p = (xbb(ii) - step_down_judgement_x) / (descend_end_x - step_down_judgement_x);
        zbb(ii) = zbb_descend_prep + smoothstep(p) * (0 - zbb_descend_prep);
    elseif xbb(ii) <= flat_recover_end_x
        zbb(ii) = 0;
    else
        zbb(ii) = 0;
    end

    for jj = 1:6
        if x(jj,ii) < step_up_edge_x
            support_height(jj,ii) = 0;
        elseif x(jj,ii) < step_down_judgement_x
            support_height(jj,ii) = step_height;
        else
            support_height(jj,ii) = 0;
        end

        z(jj,ii) = z(jj,ii) + support_height(jj,ii);

        if is_swing(jj,ii)
            if x(jj,ii) > step_up_edge_x - edge_window_up && x(jj,ii) < step_up_edge_x + edge_window_up
                z(jj,ii) = z(jj,ii) + edge_clearance_up;
            end
            if x(jj,ii) > step_down_edge_x - edge_window_down && x(jj,ii) < step_down_edge_x + edge_window_down
                % Apex must be above the platform top + clearance, regardless of
                % whether the apex X has already crossed the edge (support_height=0).
                z_descent_apex = zf0 + step_height + edge_clearance_down;
                z(jj,ii) = max(z(jj,ii), z_descent_apex);
            end
        end
    end
end

%% Interpolate onto the 5 ms timeline
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

%% Plot checks
figure('Name','walk_step_platform5m - foot X');
plot(x0'); hold on; plot(xb');
xlabel('frame'); ylabel('X (m)'); title('Foot X trajectory');

figure('Name','walk_step_platform5m - foot Z');
plot(z0'); xlabel('frame'); ylabel('Z (m)'); title('Foot Z trajectory');

figure('Name','walk_step_platform5m - body Z');
plot(zb'); xlabel('frame'); ylabel('Zb (m)'); title('Body Z trajectory');

%% Inverse kinematics
robot = robot3D_description;
joint = zeros(length(xq), 18);
angle_deg = zeros(6, length(xq));
fprintf('Start IK solving (%d frames)...\n', length(xq));
posR = [0,0,0,0,0,0];
for i = 1:length(xq)
    for ii = 1:6
        Target(i).R = eye(3);
        Target(i).p = [x0(ii,i); y0(ii,i); z0(ii,i)];
        robot(1).p = [xb(i); yb(i); zb(i)];

        c_id = [1 + 3 * ii, 1];
        robot = ik_collision(robot, Target(i), c_id);
        for jj = 1:3
            joint(i, jj + 3 * ii - 3) = robot(jj + 3 * ii - 2).q;
        end

        pos(ii).p(i,:) = robot(c_id(1)).collision(c_id(2)).p;
        rotated_z = robot(c_id(1)).collision(c_id(2)).R(:, 3);
        z_axis = [0; 0; 1];
        dot_product = dot(rotated_z, z_axis);
        norm_rotated_z = norm(rotated_z);
        angle_rad = acos(dot_product / norm_rotated_z);
        angle_deg(ii,i) = rad2deg(angle_rad);
        if angle_deg(ii,i) > posR(ii)
            if i == 1 || z0(ii,i) == z0(ii,i-1)
                posR(ii) = angle_deg(ii,i);
            end
        end
    end
    if mod(i, 500) == 0
        fprintf('  progress: %d/%d\n', i, length(xq));
    end
end

figure
plot(pos(1).p(:,1));
hold on
plot(pos(2).p(:,1));
plot(pos(3).p(:,1));
plot(pos(4).p(:,1));
plot(pos(5).p(:,1));
plot(pos(6).p(:,1));

figure
plot(pos(1).p(:,3));
hold on
plot(pos(2).p(:,3));
plot(pos(3).p(:,3));
plot(pos(4).p(:,3));
plot(pos(5).p(:,3));
plot(pos(6).p(:,3));

%% Save result
saveDir = fullfile(fileparts(mfilename('fullpath')), 'export_data');
if ~exist(saveDir, 'dir'), mkdir(saveDir); end
save(fullfile(saveDir, 'walk_step_platform5m.mat'), 'joint')
