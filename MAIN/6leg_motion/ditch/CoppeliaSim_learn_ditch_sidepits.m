function CoppeliaSim_learn_ditch_sidepits(export_meta)
% =========================================================================
% CoppeliaSim_learn_ditch.m —— 六足机器人深沟跨越闭环控制系统 (最终版)
%
% 核心控制架构：
%   1. 异步动态探测策略：融合“跌落短路检测”与“踩实防抖逻辑”，实现高速避险。
%   2. 稳健触地锁定：通过原位锁定法 (In-place Freezing) 消除垂直冲击。
%   3. 闭环步幅不对称补偿：动态调节左右步距以实时抵消波浪步态偏航。
%   4. 重心位姿管理：包含跨坑重心前移 (CoG Shift) 保护机制。
% =========================================================================

if nargin < 1 || isempty(export_meta)
    export_meta = struct();
end

%% 1. 环境准备与数据加载
clc; close all;

% 作为独立入口运行时，仅引导到统一路径初始化入口，避免散乱的 genpath 依赖。
project_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
setup_dir = fullfile(project_root, 'lib', 'setup');
current_paths = string(strsplit(path, pathsep));
if ~any(strcmp(current_paths, string(setup_dir)))
    addpath(setup_dir);
end
setup_info = hexapod_setup_paths();
project_root = setup_info.project_root;
fprintf('--- 启动完全体物理示教模式 (Hexapod Ditch Crossing v4) ---\n');

run_start_str = datestr(now,'yyyy-mm-dd HH:MM:SS');
run_start_now = now;
run_timer = tic;

base_path = fullfile(fileparts(mfilename('fullpath')), 'export_data', 'xyz_base.mat');
load(base_path, 'xq', 'x0', 'y0', 'z0', 'xb', 'yb', 'zb', 'zf0');

natural_total_frames = numel(xq);
target_total_frames = natural_total_frames;
if isfield(export_meta, 'target_total_frames') && ~isempty(export_meta.target_total_frames)
    target_total_frames = export_meta.target_total_frames;
end
if target_total_frames ~= natural_total_frames
    xq = hexapod_resample_series(xq, target_total_frames, 2);
    x0 = hexapod_resample_series(x0, target_total_frames, 2);
    y0 = hexapod_resample_series(y0, target_total_frames, 2);
    z0 = hexapod_resample_series(z0, target_total_frames, 2);
    xb = hexapod_resample_series(xb, target_total_frames, 2);
    yb = hexapod_resample_series(yb, target_total_frames, 2);
    zb = hexapod_resample_series(zb, target_total_frames, 2);
end

Data_Num = length(xq);
Control_T = 5;
legacy_port = 19997;
if isstruct(export_meta) && isfield(export_meta, 'coppeliasim_port') && ~isempty(export_meta.coppeliasim_port) && ~isnan(export_meta.coppeliasim_port)
    legacy_port = export_meta.coppeliasim_port;
end
vrobot = MatlabVrep(Control_T, legacy_port);
if legacy_port > 19999
    vrobot.Close_All_Connections_Before_Init = true;
end
vrobot = vrobot.init();

% 设置初始机身高度与位姿
vrobot.set_body_o([0; 0; 0]);
vrobot.set_body_p([xb(1); yb(1); 2.7]);

robot_ik = robot3D_description;
Joint_Learned = zeros(Data_Num * 2, 18);

%% 2. 控制参数与状态管理初始化
% -------------------------------------------------------------------------
% 状态标志 (State Flags)
z_locked = true(1, 6);                 % 支撑相锁定标志
is_recovering = false(1, 6);           % 正在执行避险反射
is_crossing_ditch = false;             % 是否处于跨坑保护区间

is_shifting_x = false;                 % 记录重心是否正在前移
front_leg_confirmed = false(1, 6);     % 前腿是否已在对岸形成稳定支撑
front_leg_hard_confirmed = false(1, 6);% 前腿是否已明显越过深沟，可长期保持确认
middle_leg_confirmed = false(1, 6);    % 中腿是否已在对岸形成稳定支撑
middle_leg_hard_confirmed = false(1, 6);% 中腿是否已明显越过深沟，可长期保持确认
last_cog_stage = -1;                   % 记录上一次重心阶段，避免重复打印
cog_control_finished = false;          % 本次过坑的重心补偿是否已完成，完成后不再重新进入

% 避险反射相关计数器与变量 (Reflex States)
recover_state = zeros(1, 6);           % 反射状态机: 1=第一次前跨, 2=退回补救后再试, 3=第二次跨越, 4=最终止损回撤, 5=单腿脱困, 6=单腿脱困受阻后的回撤等待
recover_frame = zeros(1, 6);           % 反射动作执行帧计数
reflex_start_x = zeros(1, 6);          % 记录反射动作起始坐标
reflex_start_z = zeros(1, 6);
offset_x = zeros(1, 6);                % 足端 X 轴累积偏移
trap_escape_count = zeros(1, 6);       % 单腿脱困尝试计数，避免陷入重复脱困
escape_step_len = zeros(1, 6);         % 每条腿当前单腿脱困的前跨距离
recover_pit_idx = zeros(1, 6);         % 当前恢复流程锁定的坑编号，避免在多坑间误切换
retreat_target_world_x = NaN(1, 6);    % 动态回撤的世界坐标目标 X
retry_step_len = zeros(1, 6);          % 当前二次跨越的前探距离
single_escape_target_world_x = NaN(1, 6); % 单腿脱困在世界坐标系下的最终目标 X

% 平滑过渡与锁定变量 (Smoothing & Locking)
locked_z_val = zf0 * ones(1, 6);       % 存储支撑相时的物理坐标锁定值
real_foot_x_log = zeros(1, 6);         % 各腿最近一次物理 X 坐标
real_foot_y_log = zeros(1, 6);         % 各腿最近一次物理 Y 坐标
real_foot_z_log = zf0 * ones(1, 6);    % 各腿最近一次物理 Z 坐标
smoothing_frames = zeros(1, 6);        % 剩余平滑帧数
smooth_duration = 15;                  % 平滑插补时长 (75ms)
locked_start_z = zf0 * ones(1, 6);     % 记录平滑起始高度

% 重心控制变量 (CoM Control)
target_cog = 0;                        % 目标中心质心偏移 (Z轴)
current_cog = 0;                       % 当前平滑质心偏移 (Z轴)
target_x_offset = 0;                   % 目标推进前身偏移 (X轴)
current_x_offset = 0;                  % 当前平滑推进偏移 (X轴)

% 航向偏差与纠偏变量 (Yaw Control)
target_yaw_cmd = 0;                    % 目标航向旋转角度校正
current_yaw_cmd = 0;                   % 当前平滑旋转角度
yaw_step_gain = 1.5;                   % P 增益：偏航对步幅的闭环修正系数
delta_step_compensation = 0;           % 当前左右步幅补偿量

% 物理感知参数 (Physical Sensing)
F_AIR_THRESH = 10;                     % 悬空判定的综合力阈值 (N)
AIR_CONFIRM_FRAMES = 20;               % 滑落判定的连续确认帧数
probe_wait = zeros(1, 6);              % 触地后的稳健监测倒计时
probe_confirm_frames = 30;             % 稳健判定帧数：30 帧即可确认踩实

% 深沟前腿确认与三段重心参数 (Three-stage CoM Shift)
front_legs = [1, 4];                   % 当前编号下，1/4 为前腿
middle_legs = [2, 5];                  % 当前编号下，2/5 为中腿
rear_legs = [3, 6];                    % 当前编号下，3/6 为后腿
% 多坑定义：每行 [x_min, x_max, y_side]
% y_side: 0=全通道, 1=左侧(y>0,腿4/5/6), -1=右侧(y<0,腿1/2/3)
pit_defs = [1.5, 2.1,  0;
            3.2, 3.8,  1;
            4.7, 5.3, -1];
pit_trap_x_max = pit_defs(1,2);  % 主深沟后沿，用于重心确认逻辑
final_pit_x_max = max(pit_defs(:,2));  % 最后一个坑的后沿，用于后腿完成判停
front_hard_confirm_x = 2.4;
middle_hard_confirm_x = 2.4;
cog_control_enter_x = 0.25;
cog_control_exit_x = 8.3;
x_offset_stage0 = -0.15;               % 阶段0：前腿均未确认，重心后移保稳定
x_offset_stage1 = 0.00;                % 阶段1：前腿未全确认前，重心保持中性
x_offset_stage2 = 0.20;                % 阶段2：两条前腿均确认，先补偿 20cm
x_offset_stage3 = 0.40;                % 阶段3：两条中腿也确认，再额外补偿 20cm

% 单腿脱困参数：仅在“已踩实但落脚 X 仍处于坑中区间”时触发
single_escape_step_x = 0.55;           % 当前腿自己落入坑中区间时的单腿脱困步长
assist_escape_step_x = 0.30;           % 其他腿被顺带检测出仍在坑中区间时，使用较小的补跨步长
single_escape_peak_h = 0.30;           % 单腿脱困抬腿高度
single_escape_land_z = zf0 - 0.085;    % 脱困后保留轻微深探，继续验证是否踩实
same_side_leg_clearance = 0.25;        % 同侧前后腿在单腿脱困时必须保留的最小安全净距
single_escape_min_progress = 0.05;     % 净距限幅后，若单腿脱困剩余前进量不足 5cm，则放弃前跨转入回撤等待
same_side_lead_leg = [0, 1, 2, 0, 4, 5]; % 同侧前邻腿映射：2<-1, 3<-2, 5<-4, 6<-5
max_trap_escape_attempts = 1;          % 单腿脱困最多尝试一次，失败后转入常规退回补救
first_cross_step_x = 0.75;             % 第一次前跨试探的目标步长
retry_extra_step_x = 0.10;             % 直接重试时在第一次落点基础上再前探 10cm，使第二次总前跨达到 0.85m
retry_after_retreat_step_x = 0.85;     % 退回安全区后再次跨越时，统一按 0.85m 前跨
retreat_clearance = 0.10;              % 动态回撤统一退到坑前沿外 10cm 的位置

% -------------------------------------------------------------------------

% 初始帧 IK 解算 (强制各腿踩在标定地平面 zf0)
for leg = 1:6
    Target.R = eye(3);
    Target.p = [x0(leg, 1); y0(leg, 1); zf0];
    robot_ik(1).p = [xb(1); yb(1); zb(1)];
    c_id = [1 + 3*leg, 1];
    robot_ik = ik_collision(robot_ik, Target, c_id);
    for j = 1:3; Joint_Learned(1, j + 3*leg - 3) = robot_ik(j + 3*leg - 2).q; end
end
vrobot.set_joint_initial(Joint_Learned(1, :));

vrobot.go();
kk = 1;
sim_frame = 1;
WARMUP_FRAMES = 30;
NOMINAL_BODY_Z = 2.7;

max_log_frames = size(Joint_Learned, 1);
realX_log = NaN(max_log_frames, 1); realY_log = NaN(max_log_frames, 1); realZ_log = NaN(max_log_frames, 1);
bodyRoll_log = NaN(max_log_frames, 1);
bodyPitch_log = NaN(max_log_frames, 1);
bodyYaw_log = NaN(max_log_frames, 1);
recover_count_total = 0;
real_body = [xb(1); yb(1); NOMINAL_BODY_Z];
air_count = zeros(1, 6);               % 支撑相连续失载计数器

% 预分配力记录数组，避免循环中动态扩展
est_force_frames = max(Data_Num * 2 - WARMUP_FRAMES, 1);
FR1 = zeros(est_force_frames, 3); FR2 = zeros(est_force_frames, 3); FR3 = zeros(est_force_frames, 3);
FL1 = zeros(est_force_frames, 3); FL2 = zeros(est_force_frames, 3); FL3 = zeros(est_force_frames, 3);

%% 3. 主仿真循环
while kk <= Data_Num
    recovering_prev = is_recovering;

    [F, ~] = vrobot.get_force_sensor();
    [~, real_body] = vrobot.Main.simxGetObjectPosition(vrobot.ClientID, vrobot.Body_Handle, -1, vrobot.Main.simx_opmode_oneshot);

    % [模块 B]: 偏航闭环控制 (机身扭转与步幅动态调节)
    if mod(sim_frame, 500) == 0 && sim_frame > WARMUP_FRAMES
        [res, obj_orient] = vrobot.Main.simxGetObjectOrientation(vrobot.ClientID, vrobot.Body_Handle, -1, vrobot.Main.simx_opmode_oneshot);
        if (res == vrobot.Main.simx_return_ok || res == 0) && length(obj_orient) >= 3
            actual_yaw = obj_orient(3);
            target_yaw_cmd = -0.6 * actual_yaw; % 姿态纠正

            % 航向纠正限幅与日志
            max_drift = deg2rad(5);
            target_yaw_cmd = max(-max_drift, min(max_drift, target_yaw_cmd));
            fprintf('  [偏航修正] 第 %d 帧，真实 Yaw: %.2f°，闭环施加纠正量: %.2f°\n', ...
                sim_frame, rad2deg(actual_yaw), rad2deg(target_yaw_cmd));

            % 步幅差分补正：机身偏左(Actual_Yaw>0)则减小右侧步幅、放大左侧步幅以纠偏
            delta_step_compensation = -yaw_step_gain * actual_yaw;
            delta_step_compensation = max(-0.10, min(0.10, delta_step_compensation));
            fprintf('  [步幅补偿] 偏航 %.2f°，右侧步幅+%.1fmm / 左侧步幅-%.1fmm\n', ...
                rad2deg(actual_yaw), delta_step_compensation*1000, delta_step_compensation*1000);
        end
    end
    current_yaw_cmd = current_yaw_cmd + (target_yaw_cmd - current_yaw_cmd) * 0.05;

    % 每帧先统一采样 6 条腿的真实足端位置，后续判坑/阶段判断只使用这套物理坐标
    for leg = 1:6
        [~, foot_pos] = vrobot.Main.simxGetObjectPosition( ...
            vrobot.ClientID, vrobot.Force_sensor_Handle(leg), -1, vrobot.Main.simx_opmode_oneshot);
        real_foot_x_log(leg) = foot_pos(1);
        real_foot_y_log(leg) = foot_pos(2);
        if sim_frame > WARMUP_FRAMES
            real_foot_z_log(leg) = foot_pos(3);
        else
            real_foot_z_log(leg) = 1.05;
        end
    end

    % [模块 A]: 机身平衡管理 (重心高度与三段式前后移控制)
    target_cog = 0; % Z 轴下潜补偿已停用，保持标定步态高度
    current_cog = current_cog + (target_cog - current_cog) * 0.01;

    % 只在接近并穿越深沟的主工作区间内启用三段重心策略，避免平地阶段被干扰。
    is_crossing_ditch = ~cog_control_finished && real_body(1) > cog_control_enter_x && real_body(1) < cog_control_exit_x;

    % 用“两级确认 + 前腿/中腿分级推进”来决定当前重心补偿阶段：
    %   阶段0：前腿都未确认 -> 重心后移，优先保住后方支撑
    %   阶段1：前腿未全部确认 -> 暂时保持中性
    %   阶段2：两条前腿都确认 -> 先前移 20cm
    %   阶段3：两条中腿也确认 -> 再额外前移 20cm
    confirmed_front_count = 0;
    confirmed_middle_count = 0;
    for front_leg = front_legs
        front_world_x = real_foot_x_log(front_leg);

        % 一级确认条件：仍按“稳定锁定 + 越过坑中区间”判断
        front_leg_is_stable = ...
            z_locked(front_leg) && ...
            ~is_recovering(front_leg) && ...
            probe_wait(front_leg) == 0;
        front_leg_soft_confirmed = front_leg_is_stable && ...
            front_world_x >= pit_trap_x_max;

        % 二级确认条件：当同一条前腿稳定超过 2.4m 后，直接锁定为长期确认。
        % 这样在明显过坑后，重心策略不会再因为每帧重复判断而变得过于保守。
        if ~front_leg_hard_confirmed(front_leg) && front_leg_is_stable && front_world_x > front_hard_confirm_x
            front_leg_hard_confirmed(front_leg) = true;
        end

        front_leg_confirmed(front_leg) = front_leg_hard_confirmed(front_leg) || front_leg_soft_confirmed;

        if front_leg_confirmed(front_leg)
            confirmed_front_count = confirmed_front_count + 1;
        end
    end

    for middle_leg = middle_legs
        middle_world_x = real_foot_x_log(middle_leg);

        middle_leg_is_stable = ...
            z_locked(middle_leg) && ...
            ~is_recovering(middle_leg) && ...
            probe_wait(middle_leg) == 0;
        middle_leg_soft_confirmed = middle_leg_is_stable && ...
            middle_world_x >= pit_trap_x_max;

        if ~middle_leg_hard_confirmed(middle_leg) && middle_leg_is_stable && middle_world_x > middle_hard_confirm_x
            middle_leg_hard_confirmed(middle_leg) = true;
        end

        middle_leg_confirmed(middle_leg) = middle_leg_hard_confirmed(middle_leg) || middle_leg_soft_confirmed;

        if middle_leg_confirmed(middle_leg)
            confirmed_middle_count = confirmed_middle_count + 1;
        end
    end

    if is_crossing_ditch
        if confirmed_front_count == 0
            raw_cog_stage_id = 0;
        elseif confirmed_front_count < numel(front_legs)
            raw_cog_stage_id = 1;
        elseif confirmed_middle_count < numel(middle_legs)
            raw_cog_stage_id = 2;
        else
            raw_cog_stage_id = 3;
        end

        % 重心阶段在一次过坑过程中只允许前进，不允许从 3 再退回 2。
        % 这样可以避免中腿在摆动/落地交替时，日志里出现 2/3 来回切换。
        if last_cog_stage >= 0
            current_cog_stage_id = max(raw_cog_stage_id, last_cog_stage);
        else
            current_cog_stage_id = raw_cog_stage_id;
        end

        if current_cog_stage_id == 0
            target_x_offset = x_offset_stage0;
        elseif current_cog_stage_id == 1
            target_x_offset = x_offset_stage1;
        elseif current_cog_stage_id == 2
            target_x_offset = x_offset_stage2;
        else
            target_x_offset = x_offset_stage3;
        end

        if current_cog_stage_id ~= last_cog_stage
            if current_cog_stage_id == 0
                fprintf('  [重心平衡] 阶段0：前腿尚未确认，重心后移 %.2fm，优先防止前栽。\n', x_offset_stage0);
            elseif current_cog_stage_id == 1
                fprintf('  [重心平衡] 阶段1：前腿未全部确认，重心保持中性，继续等待前腿站稳。\n');
            elseif current_cog_stage_id == 2
                fprintf('  [重心平衡] 阶段2：两条前腿均已确认，重心前移 %.2fm，开始协助中后腿过坑。\n', x_offset_stage2);
            else
                fprintf('  [重心平衡] 阶段3：两条中腿也已确认，重心前移 %.2fm，继续协助后腿完成过坑。\n', x_offset_stage3);
            end
            last_cog_stage = current_cog_stage_id;
        end

        is_shifting_x = true;
    else
        if is_shifting_x
            fprintf('  [重心平衡] 越障区域结束，全局重心平滑退回原位。\n');
            if last_cog_stage >= 2 && real_body(1) >= cog_control_exit_x
                cog_control_finished = true;
            end
        end
        is_shifting_x = false;
        target_x_offset = 0;
        front_leg_confirmed(front_legs) = false;
        front_leg_hard_confirmed(front_legs) = false;
        middle_leg_confirmed(middle_legs) = false;
        middle_leg_hard_confirmed(middle_legs) = false;
        last_cog_stage = -1;
    end
    current_x_offset = current_x_offset + (target_x_offset - current_x_offset) * 0.01;

    for leg = 1:6
        cur_x = x0(leg, kk) + offset_x(leg);
        % 应用左右侧步幅不对称补偿
        if leg <= 3
            cur_x = cur_x + delta_step_compensation;  % 右侧
        else
            cur_x = cur_x - delta_step_compensation;  % 左侧
        end
        cur_y = y0(leg, kk);
        cur_z = z0(leg, kk);

        % 使用本帧统一采样到的真实足端位置，避免在不同判定链路里混入估算坐标
        if sim_frame > WARMUP_FRAMES
            force_mag = norm(F(leg, :));
        else
            force_mag = 9999;
        end
        real_foot_x = real_foot_x_log(leg);
        real_foot_y = real_foot_y_log(leg);
        real_foot_z = real_foot_z_log(leg);

        % [模块 C]: 腿部控制与反射管理
        if is_recovering(leg)
            recover_frame(leg) = recover_frame(leg) + 1;
            rf = recover_frame(leg);

            if recover_state(leg) == 1 % 行为阶段 1：优先直接前跨试探
                safe_x = reflex_start_x(leg) + first_cross_step_x;
                peak_z = reflex_start_z(leg) + 0.35;
                land_z = zf0 - 0.085; % 直接前跨后仍保留深探，用于确认是否真正落到实地

                t_ratio = rf / 160;
                pt_up = min(1, t_ratio / 0.3);
                pt_fwd = min(1, max(0, t_ratio - 0.3) / 0.4);
                pt_dn = min(1, max(0, t_ratio - 0.7) / 0.3);
                cur_x = reflex_start_x(leg) + (safe_x - reflex_start_x(leg)) * (1 - cos(pi*pt_fwd))/2;
                if t_ratio <= 0.7
                    cur_z = reflex_start_z(leg) + (peak_z - reflex_start_z(leg)) * (1 - cos(pi*pt_up))/2;
                else
                    cur_z = peak_z + (land_z - peak_z) * (1 - cos(pi*pt_dn))/2;
                end

                if rf >= 160
                    if real_foot_z >= 0.98
                        if is_in_any_trap(real_foot_x, real_foot_y, pit_defs) && trap_escape_count(leg) < max_trap_escape_attempts
                            recover_state(leg) = 5;
                            recover_frame(leg) = 0;
                            reflex_start_x(leg) = cur_x;
                            reflex_start_z(leg) = cur_z;
                            recover_pit_idx(leg) = find_active_recover_pit_idx(real_foot_x, real_foot_y, pit_defs);
                            retreat_target_world_x(leg) = NaN;
                            single_escape_target_world_x(leg) = NaN;
                            trap_escape_count(leg) = trap_escape_count(leg) + 1;
                            escape_step_len(leg) = single_escape_step_x;
                            fprintf('  [单腿脱困] 腿 %d 已踩实但 X=%.2f 仍在坑中区间，启动单腿脱困。\n', leg, real_foot_x);
                        elseif is_in_any_trap(real_foot_x, real_foot_y, pit_defs)
                            if recover_pit_idx(leg) == 0
                                recover_pit_idx(leg) = find_active_recover_pit_idx(real_foot_x, real_foot_y, pit_defs);
                            end
                            recover_state(leg) = 3;
                            recover_frame(leg) = 0;
                            reflex_start_x(leg) = cur_x;
                            reflex_start_z(leg) = cur_z;
                            retreat_target_world_x(leg) = NaN;
                            retry_step_len(leg) = retry_extra_step_x;
                            fprintf('  [避险调整] 腿 %d 首次前跨落脚仍在坑中区间，直接进入二次跨越。\n', leg);
                        else
                            z_locked(leg) = true;
                            locked_z_val(leg) = cur_z;
                            offset_x(leg) = cur_x - x0(leg, kk);
                            recover_state(leg) = 0;
                            is_recovering(leg) = false;
                            trap_escape_count(leg) = 0;
                            escape_step_len(leg) = 0;
                            recover_pit_idx(leg) = 0;
                            retreat_target_world_x(leg) = NaN;
                            retry_step_len(leg) = 0;
                        fprintf('  [避险成功] 腿 %d 直接前跨成功落位。物理Z=%.3f\n', leg, real_foot_z);
                        [is_recovering, recover_state, recover_frame, reflex_start_x, reflex_start_z, trap_escape_count, escape_step_len, single_escape_target_world_x] = ...
                            try_trigger_assist_escape(leg, z_locked, is_recovering, probe_wait, recover_state, recover_frame, ...
                                reflex_start_x, reflex_start_z, trap_escape_count, escape_step_len, max_trap_escape_attempts, ...
                                assist_escape_step_x, x0, kk, offset_x, delta_step_compensation, real_foot_x_log, real_foot_y_log, locked_z_val, pit_defs, single_escape_target_world_x);
                        end
                    else
                        if recover_pit_idx(leg) == 0
                            recover_pit_idx(leg) = find_active_recover_pit_idx(real_foot_x, real_foot_y, pit_defs);
                        end
                        recover_state(leg) = 3;
                        recover_frame(leg) = 0;
                        reflex_start_x(leg) = cur_x;
                        reflex_start_z(leg) = cur_z;
                        retreat_target_world_x(leg) = NaN;
                        retry_step_len(leg) = retry_extra_step_x;
                        fprintf('  [避险调整] 腿 %d 首次前跨未踩实，直接进入二次跨越。\n', leg);
                    end
                end

            elseif recover_state(leg) == 2 % 行为阶段 2：退回补救后再尝试二次跨越
                if ~isfinite(retreat_target_world_x(leg))
                    retreat_target_world_x(leg) = compute_retreat_target_world_x( ...
                        real_foot_x, real_foot_y, recover_pit_idx(leg), pit_defs, retreat_clearance);
                end
                safe_x = retreat_target_world_x(leg) - real_body(1) + xb(kk);
                peak_z = reflex_start_z(leg) + 0.35;
                land_z = zf0;

                t_ratio = rf / 160;
                pt_up = min(1, t_ratio / 0.3);
                pt_fwd = min(1, max(0, t_ratio - 0.3) / 0.4);
                pt_dn = min(1, max(0, t_ratio - 0.7) / 0.3);
                cur_x = reflex_start_x(leg) + (safe_x - reflex_start_x(leg)) * (1 - cos(pi*pt_fwd))/2;
                if t_ratio <= 0.7
                    cur_z = reflex_start_z(leg) + (peak_z - reflex_start_z(leg)) * (1 - cos(pi*pt_up))/2;
                else
                    cur_z = peak_z + (land_z - peak_z) * (1 - cos(pi*pt_dn))/2;
                end

                if rf >= 160
                    if real_foot_z >= 0.98 && ~is_in_any_trap(real_foot_x, real_foot_y, pit_defs)
                        recover_state(leg) = 3;
                        recover_frame(leg) = 0;
                        reflex_start_x(leg) = cur_x;
                        reflex_start_z(leg) = cur_z;
                        retreat_target_world_x(leg) = NaN;
                        retry_step_len(leg) = retry_after_retreat_step_x;
                        fprintf('  [避险反射] 腿 %d 已退回安全区，开始二次跨越。\n', leg);
                    else
                        if recover_pit_idx(leg) == 0
                            recover_pit_idx(leg) = find_active_recover_pit_idx(real_foot_x, real_foot_y, pit_defs);
                        end
                        retreat_target_world_x(leg) = compute_retreat_target_world_x( ...
                            real_foot_x, real_foot_y, recover_pit_idx(leg), pit_defs, retreat_clearance);
                        recover_frame(leg) = 0;
                        reflex_start_x(leg) = cur_x;
                        reflex_start_z(leg) = cur_z;
                        fprintf('  [避险调整] 腿 %d 退回后仍未脱离风险，继续扩大回撤至目标X=%.2f。\n', leg, retreat_target_world_x(leg));
                    end
                end

            elseif recover_state(leg) == 3 % 行为阶段 3：第二次跨越
                safe_x = reflex_start_x(leg) + max(retry_step_len(leg), retry_extra_step_x);
                peak_z = reflex_start_z(leg) + 0.35;
                land_z = zf0 - 0.085;

                t_ratio = rf / 160;
                pt_up = min(1, t_ratio / 0.3);
                pt_fwd = min(1, max(0, t_ratio - 0.3) / 0.4);
                pt_dn = min(1, max(0, t_ratio - 0.7) / 0.3);
                cur_x = reflex_start_x(leg) + (safe_x - reflex_start_x(leg)) * (1 - cos(pi*pt_fwd))/2;
                if t_ratio <= 0.7
                    cur_z = reflex_start_z(leg) + (peak_z - reflex_start_z(leg)) * (1 - cos(pi*pt_up))/2;
                else
                    cur_z = peak_z + (land_z - peak_z) * (1 - cos(pi*pt_dn))/2;
                end

                if rf >= 160
                    if real_foot_z >= 0.98
                        if is_in_any_trap(real_foot_x, real_foot_y, pit_defs)
                            if recover_pit_idx(leg) == 0
                                recover_pit_idx(leg) = find_active_recover_pit_idx(real_foot_x, real_foot_y, pit_defs);
                            end
                            recover_state(leg) = 4;
                            recover_frame(leg) = 0;
                            reflex_start_x(leg) = cur_x;
                            reflex_start_z(leg) = cur_z;
                            retreat_target_world_x(leg) = compute_retreat_target_world_x( ...
                                real_foot_x, real_foot_y, recover_pit_idx(leg), pit_defs, retreat_clearance);
                            fprintf('  *** [避险失败] 腿 %d 二次跨越后仍落在坑中区间，转入动态回撤止损，目标X=%.2f。\n', leg, retreat_target_world_x(leg));
                        else
                            z_locked(leg) = true;
                            locked_z_val(leg) = cur_z;
                            offset_x(leg) = cur_x - x0(leg, kk);
                            recover_state(leg) = 0;
                            is_recovering(leg) = false;
                            trap_escape_count(leg) = 0;
                            escape_step_len(leg) = 0;
                            recover_pit_idx(leg) = 0;
                            retreat_target_world_x(leg) = NaN;
                            retry_step_len(leg) = 0;
                            fprintf('  [避险成功] 腿 %d 二次跨越成功落位。物理Z=%.3f\n', leg, real_foot_z);
                            [is_recovering, recover_state, recover_frame, reflex_start_x, reflex_start_z, trap_escape_count, escape_step_len, single_escape_target_world_x] = ...
                                try_trigger_assist_escape(leg, z_locked, is_recovering, probe_wait, recover_state, recover_frame, ...
                                    reflex_start_x, reflex_start_z, trap_escape_count, escape_step_len, max_trap_escape_attempts, ...
                                    assist_escape_step_x, x0, kk, offset_x, delta_step_compensation, real_foot_x_log, real_foot_y_log, locked_z_val, pit_defs, single_escape_target_world_x);
                        end
                    else
                        if recover_pit_idx(leg) == 0
                            recover_pit_idx(leg) = find_active_recover_pit_idx(real_foot_x, real_foot_y, pit_defs);
                        end
                        recover_state(leg) = 4;
                        recover_frame(leg) = 0;
                        reflex_start_x(leg) = cur_x;
                        reflex_start_z(leg) = cur_z;
                        retreat_target_world_x(leg) = compute_retreat_target_world_x( ...
                            real_foot_x, real_foot_y, recover_pit_idx(leg), pit_defs, retreat_clearance);
                        fprintf('  *** [避险失败] 腿 %d 二次跨越仍未踩实，转入动态回撤止损，目标X=%.2f。\n', leg, retreat_target_world_x(leg));
                    end
                end

            elseif recover_state(leg) == 4 % 行为阶段 4：二次失败后的最终止损回撤
                if ~isfinite(retreat_target_world_x(leg))
                    retreat_target_world_x(leg) = compute_retreat_target_world_x( ...
                        real_foot_x, real_foot_y, recover_pit_idx(leg), pit_defs, retreat_clearance);
                end
                safe_x = retreat_target_world_x(leg) - real_body(1) + xb(kk);
                peak_z = reflex_start_z(leg) + 0.35;
                land_z = zf0;

                t_ratio = rf / 160;
                pt_up = min(1, t_ratio / 0.3);
                pt_fwd = min(1, max(0, t_ratio - 0.3) / 0.4);
                pt_dn = min(1, max(0, t_ratio - 0.7) / 0.3);
                cur_x = reflex_start_x(leg) + (safe_x - reflex_start_x(leg)) * (1 - cos(pi*pt_fwd))/2;
                if t_ratio <= 0.7
                    cur_z = reflex_start_z(leg) + (peak_z - reflex_start_z(leg)) * (1 - cos(pi*pt_up))/2;
                else
                    cur_z = peak_z + (land_z - peak_z) * (1 - cos(pi*pt_dn))/2;
                end

                if rf >= 160
                    if real_foot_z >= 0.98 && ~is_in_any_trap(real_foot_x, real_foot_y, pit_defs)
                        z_locked(leg) = true;
                        locked_z_val(leg) = cur_z;
                        offset_x(leg) = cur_x - x0(leg, kk);
                        recover_state(leg) = 0;
                        is_recovering(leg) = false;
                        trap_escape_count(leg) = 0;
                        escape_step_len(leg) = 0;
                        recover_pit_idx(leg) = 0;
                        retreat_target_world_x(leg) = NaN;
                        retry_step_len(leg) = 0;
                        fprintf('  [避险止损] 腿 %d 已退回安全区，进入保护性静止状态。\n', leg);
                    else
                        if recover_pit_idx(leg) == 0
                            recover_pit_idx(leg) = find_active_recover_pit_idx(real_foot_x, real_foot_y, pit_defs);
                        end
                        retreat_target_world_x(leg) = compute_retreat_target_world_x( ...
                            real_foot_x, real_foot_y, recover_pit_idx(leg), pit_defs, retreat_clearance);
                        recover_frame(leg) = 0;
                        reflex_start_x(leg) = cur_x;
                        reflex_start_z(leg) = cur_z;
                        fprintf('  [避险止损] 腿 %d 回撤后仍未完全脱离风险，继续扩大回撤至目标X=%.2f。\n', leg, retreat_target_world_x(leg));
                    end
                end

            elseif recover_state(leg) == 5 % 行为阶段 5：已踩实但仍落在坑中区间，执行单腿脱困
                if ~isfinite(single_escape_target_world_x(leg))
                    desired_safe_x = reflex_start_x(leg) + max(escape_step_len(leg), assist_escape_step_x);
                    desired_target_world_x = real_body(1) + (desired_safe_x - xb(kk));
                    lead_leg = same_side_lead_leg(leg);
                    if lead_leg > 0
                        lead_leg_world_x = real_foot_x_log(lead_leg);
                        limited_target_world_x = min(desired_target_world_x, lead_leg_world_x - same_side_leg_clearance);
                        fprintf('  [单腿脱困限幅] 腿 %d 原目标X=%.2f, 前邻腿 %d 真实X=%.2f, 限幅后目标X=%.2f\n', ...
                            leg, desired_target_world_x, lead_leg, lead_leg_world_x, limited_target_world_x);

                        if limited_target_world_x - real_foot_x < single_escape_min_progress || ...
                                is_in_any_trap(limited_target_world_x, real_foot_y, pit_defs)
                            if recover_pit_idx(leg) == 0
                                recover_pit_idx(leg) = find_active_recover_pit_idx(real_foot_x, real_foot_y, pit_defs);
                            end
                            recover_state(leg) = 6;
                            recover_frame(leg) = 0;
                            reflex_start_x(leg) = cur_x;
                            reflex_start_z(leg) = cur_z;
                            retreat_target_world_x(leg) = compute_retreat_target_world_x( ...
                                real_foot_x, real_foot_y, recover_pit_idx(leg), pit_defs, retreat_clearance);
                            single_escape_target_world_x(leg) = NaN;
                            fprintf('  [单腿脱困受阻] 腿 %d 与前邻腿 %d 净距不足，可用前进量仅 %.2fm，转入回撤等待，目标X=%.2f\n', ...
                                leg, lead_leg, limited_target_world_x - real_foot_x, retreat_target_world_x(leg));
                        else
                            single_escape_target_world_x(leg) = limited_target_world_x;
                        end
                    else
                        single_escape_target_world_x(leg) = desired_target_world_x;
                    end
                end

                if recover_state(leg) == 5
                    safe_x = single_escape_target_world_x(leg) - real_body(1) + xb(kk);
                    peak_z = reflex_start_z(leg) + single_escape_peak_h;
                    land_z = single_escape_land_z;

                    t_ratio = rf / 140;
                    pt_up = min(1, t_ratio / 0.3);
                    pt_fwd = min(1, max(0, t_ratio - 0.3) / 0.4);
                    pt_dn = min(1, max(0, t_ratio - 0.7) / 0.3);
                    cur_x = reflex_start_x(leg) + (safe_x - reflex_start_x(leg)) * (1 - cos(pi*pt_fwd))/2;
                    if t_ratio <= 0.7
                        cur_z = reflex_start_z(leg) + (peak_z - reflex_start_z(leg)) * (1 - cos(pi*pt_up))/2;
                    else
                        cur_z = peak_z + (land_z - peak_z) * (1 - cos(pi*pt_dn))/2;
                    end

                    if rf >= 140
                        if real_foot_z >= 0.98 && ~is_in_any_trap(real_foot_x, real_foot_y, pit_defs)
                            z_locked(leg) = true;
                            locked_z_val(leg) = cur_z;
                            offset_x(leg) = cur_x - x0(leg, kk);
                            recover_state(leg) = 0;
                            is_recovering(leg) = false;
                            trap_escape_count(leg) = 0;
                            escape_step_len(leg) = 0;
                            recover_pit_idx(leg) = 0;
                            retreat_target_world_x(leg) = NaN;
                            retry_step_len(leg) = 0;
                            single_escape_target_world_x(leg) = NaN;
                            fprintf('  [单腿脱困成功] 腿 %d 已脱离坑中区间并重新落稳。X=%.2f, Z=%.3f\n', leg, real_foot_x, real_foot_z);
                            [is_recovering, recover_state, recover_frame, reflex_start_x, reflex_start_z, trap_escape_count, escape_step_len, single_escape_target_world_x] = ...
                                try_trigger_assist_escape(leg, z_locked, is_recovering, probe_wait, recover_state, recover_frame, ...
                                    reflex_start_x, reflex_start_z, trap_escape_count, escape_step_len, max_trap_escape_attempts, ...
                                    assist_escape_step_x, x0, kk, offset_x, delta_step_compensation, real_foot_x_log, real_foot_y_log, locked_z_val, pit_defs, single_escape_target_world_x);
                        else
                            if recover_pit_idx(leg) == 0
                                recover_pit_idx(leg) = find_active_recover_pit_idx(real_foot_x, real_foot_y, pit_defs);
                            end
                            recover_state(leg) = 2;
                            recover_frame(leg) = 0;
                            reflex_start_x(leg) = cur_x;
                            reflex_start_z(leg) = cur_z;
                            escape_step_len(leg) = 0;
                            single_escape_target_world_x(leg) = NaN;
                            retreat_target_world_x(leg) = compute_retreat_target_world_x( ...
                                real_foot_x, real_foot_y, recover_pit_idx(leg), pit_defs, retreat_clearance);
                            fprintf('  [单腿脱困失败] 腿 %d 脱困后仍不稳定，转入退回补救。X=%.2f, Z=%.3f, 回撤目标X=%.2f\n', ...
                                leg, real_foot_x, real_foot_z, retreat_target_world_x(leg));
                        end
                    end
                end

            elseif recover_state(leg) == 6 % 行为阶段 6：单腿脱困受阻后的回撤等待
                if ~isfinite(retreat_target_world_x(leg))
                    retreat_target_world_x(leg) = compute_retreat_target_world_x( ...
                        real_foot_x, real_foot_y, recover_pit_idx(leg), pit_defs, retreat_clearance);
                end
                safe_x = retreat_target_world_x(leg) - real_body(1) + xb(kk);
                peak_z = reflex_start_z(leg) + 0.35;
                land_z = zf0;

                t_ratio = rf / 160;
                pt_up = min(1, t_ratio / 0.3);
                pt_fwd = min(1, max(0, t_ratio - 0.3) / 0.4);
                pt_dn = min(1, max(0, t_ratio - 0.7) / 0.3);
                cur_x = reflex_start_x(leg) + (safe_x - reflex_start_x(leg)) * (1 - cos(pi*pt_fwd))/2;
                if t_ratio <= 0.7
                    cur_z = reflex_start_z(leg) + (peak_z - reflex_start_z(leg)) * (1 - cos(pi*pt_up))/2;
                else
                    cur_z = peak_z + (land_z - peak_z) * (1 - cos(pi*pt_dn))/2;
                end

                if rf >= 160
                    if real_foot_z >= 0.98 && ~is_in_any_trap(real_foot_x, real_foot_y, pit_defs)
                        z_locked(leg) = true;
                        locked_z_val(leg) = cur_z;
                        offset_x(leg) = cur_x - x0(leg, kk);
                        recover_state(leg) = 0;
                        is_recovering(leg) = false;
                        trap_escape_count(leg) = 0;
                        escape_step_len(leg) = 0;
                        recover_pit_idx(leg) = 0;
                        retreat_target_world_x(leg) = NaN;
                        retry_step_len(leg) = 0;
                        single_escape_target_world_x(leg) = NaN;
                        fprintf('  [单腿脱困释放] 腿 %d 已回到安全区，退出恢复态，等待正常步态重新组织。\n', leg);
                    else
                        if recover_pit_idx(leg) == 0
                            recover_pit_idx(leg) = find_active_recover_pit_idx(real_foot_x, real_foot_y, pit_defs);
                        end
                        retreat_target_world_x(leg) = compute_retreat_target_world_x( ...
                            real_foot_x, real_foot_y, recover_pit_idx(leg), pit_defs, retreat_clearance);
                        recover_frame(leg) = 0;
                        reflex_start_x(leg) = cur_x;
                        reflex_start_z(leg) = cur_z;
                        fprintf('  [单腿脱困释放] 腿 %d 回撤后仍未脱离风险，继续回撤至目标X=%.2f。\n', ...
                            leg, retreat_target_world_x(leg));
                    end
                end
            end

            cur_y = y0(leg, kk);
        else
            % [子模块 C1]: 支撑相维持 (原位锁定与滑落监听)
            if z0(leg, kk) >= zf0 + 0.05 && z_locked(leg)
                z_locked(leg) = false;
                smoothing_frames(leg) = smooth_duration;
                locked_start_z(leg) = locked_z_val(leg);
            end

            if z_locked(leg)
                cur_z = locked_z_val(leg);
                % 支撑时期的滑脱监测：若力值跌落说明脚下已滑落深坑
                if sim_frame > WARMUP_FRAMES
                    if force_mag < F_AIR_THRESH
                        air_count(leg) = air_count(leg) + 1;
                    else
                        air_count(leg) = 0;
                    end

                    if air_count(leg) >= AIR_CONFIRM_FRAMES && ~any(is_recovering)
                        % real_foot_x 已在本帧传感器采样中获取，无需估算覆盖
                    fprintf('  *** [滑落预警] 腿 %d (真实X=%.2f) 丢失地面。最后侦测受力: %.2fN\n', ...
                            leg, real_foot_x, force_mag);
                        air_count(leg) = 0;
                        trap_escape_count(leg) = 0;
                        z_locked(leg) = false;
                        recover_state(leg) = 1;
                        is_recovering(leg) = true;
                        recover_frame(leg) = 0;
                        reflex_start_x(leg) = cur_x;
                        reflex_start_z(leg) = cur_z;
                        recover_pit_idx(leg) = find_active_recover_pit_idx(real_foot_x, real_foot_y, pit_defs);
                        retreat_target_world_x(leg) = NaN;
                        retry_step_len(leg) = 0;
                    end
                end
            end

            % [子模块 C2]: 着陆动态探测 (跌落极速短路响应机制)
            if z0(leg, kk) < zf0 - 0.098 && ~z_locked(leg) && ~any(is_recovering)
                probe_wait(leg) = probe_wait(leg) + 1;

                % 紧急检测：若探地首期内高度突降，立即判定为踩空
                if real_foot_z < 0.98
                    fprintf('  *** [探底坠落] 腿 %d 在探测第 %d 帧跌破底线 (物理Z=%.3fm)，启动避险。\n', ...
                        leg, probe_wait(leg), real_foot_z);
                    recover_state(leg) = 1;
                    is_recovering(leg) = true;
                    probe_wait(leg) = 0;
                    recover_frame(leg) = 0;
                    reflex_start_x(leg) = cur_x;
                    reflex_start_z(leg) = cur_z;
                    recover_pit_idx(leg) = find_active_recover_pit_idx(real_foot_x, real_foot_y, pit_defs);
                    retreat_target_world_x(leg) = NaN;
                    retry_step_len(leg) = 0;

                    trap_escape_count(leg) = 0;
                    target_yaw_cmd = 0;
                    current_yaw_cmd = 0;

                % 稳健判定：坚持 30 帧以上高度正常，判定为坚实地面
                elseif probe_wait(leg) > probe_confirm_frames
                    if is_in_any_trap(real_foot_x, real_foot_y, pit_defs) && trap_escape_count(leg) < max_trap_escape_attempts
                        recover_state(leg) = 5;
                        is_recovering(leg) = true;
                        probe_wait(leg) = 0;
                        recover_frame(leg) = 0;
                        reflex_start_x(leg) = cur_x;
                        reflex_start_z(leg) = cur_z;
                        recover_pit_idx(leg) = find_active_recover_pit_idx(real_foot_x, real_foot_y, pit_defs);
                        retreat_target_world_x(leg) = NaN;
                        single_escape_target_world_x(leg) = NaN;
                        retry_step_len(leg) = 0;
                        trap_escape_count(leg) = trap_escape_count(leg) + 1;
                        escape_step_len(leg) = single_escape_step_x;
                        fprintf('  [单腿脱困] 腿 %d 探测踩实，但 X=%.2f 落在坑中区间，启动单腿脱困。\n', leg, real_foot_x);
                    elseif is_in_any_trap(real_foot_x, real_foot_y, pit_defs)
                        recover_state(leg) = 1;
                        is_recovering(leg) = true;
                        probe_wait(leg) = 0;
                        recover_frame(leg) = 0;
                        reflex_start_x(leg) = cur_x;
                        reflex_start_z(leg) = cur_z;
                        recover_pit_idx(leg) = find_active_recover_pit_idx(real_foot_x, real_foot_y, pit_defs);
                        retreat_target_world_x(leg) = NaN;
                        retry_step_len(leg) = 0;
                        trap_escape_count(leg) = 0;
                        escape_step_len(leg) = 0;
                        fprintf('  [避险调整] 腿 %d 探测踩实但仍落在坑中区间，转入常规前跨补救。\n', leg);
                    else
                        z_locked(leg) = true;
                        locked_z_val(leg) = cur_z;
                        probe_wait(leg) = 0;
                        trap_escape_count(leg) = 0;
                        escape_step_len(leg) = 0;
                        if sim_frame < 3000
                            fprintf('  [踩实归位] 腿%d (探测通过, 真实X=%.2f, 物理Z=%.3f)\n', ...
                                leg, real_foot_x, real_foot_z);
                        end
                        [is_recovering, recover_state, recover_frame, reflex_start_x, reflex_start_z, trap_escape_count, escape_step_len, single_escape_target_world_x] = ...
                            try_trigger_assist_escape(leg, z_locked, is_recovering, probe_wait, recover_state, recover_frame, ...
                                reflex_start_x, reflex_start_z, trap_escape_count, escape_step_len, max_trap_escape_attempts, ...
                                assist_escape_step_x, x0, kk, offset_x, delta_step_compensation, real_foot_x_log, real_foot_y_log, locked_z_val, pit_defs, single_escape_target_world_x);
                    end
                end
            else
                probe_wait(leg) = 0;
            end

            % [子模块 C3]: Z 轴平滑软启动插补
            if ~z_locked(leg) && ~is_recovering(leg)
                if smoothing_frames(leg) > 0
                    s_ratio = (smooth_duration - smoothing_frames(leg) + 1) / smooth_duration;
                    smooth_factor = (1 - cos(pi * s_ratio)) / 2;
                    cur_z = locked_start_z(leg) + (z0(leg, kk) - locked_start_z(leg)) * smooth_factor;
                    smoothing_frames(leg) = smoothing_frames(leg) - 1;
                else
                    cur_z = z0(leg, kk);
                end
            end
        end

        % IK 求解与注入
        Target.R = eye(3);
        Target.p = [cur_x; cur_y; cur_z];
        robot_ik(1).p = [xb(kk) + current_x_offset; yb(kk); zb(kk) + current_cog];
        robot_ik(1).R = [cos(current_yaw_cmd), -sin(current_yaw_cmd), 0; ...
                         sin(current_yaw_cmd),  cos(current_yaw_cmd), 0; ...
                                            0,                     0, 1];
        c_id = [1 + 3*leg, 1];
        robot_ik = ik_collision(robot_ik, Target, c_id);
        % 动态扩展保护：避免极端多坑场景中 sim_frame 超出预分配
        if sim_frame > size(Joint_Learned, 1)
            Joint_Learned(end+1:sim_frame+Data_Num, :) = 0;
        end
        for j = 1:3; Joint_Learned(sim_frame, j + 3*leg - 3) = robot_ik(j + 3*leg - 2).q; end
    end
    recover_count_total = recover_count_total + sum(is_recovering & ~recovering_prev);

    % 执行物理指令推送
    vrobot.Joint = Joint_Learned(sim_frame, :);
    vrobot.set_joint();
    vrobot.trigger();

    % 记录仿真遥测曲线
    if sim_frame > WARMUP_FRAMES
        idx = sim_frame - WARMUP_FRAMES;
        FR1(idx,:) = F(1,:); FR2(idx,:) = F(2,:); FR3(idx,:) = F(3,:);
        FL1(idx,:) = F(4,:); FL2(idx,:) = F(5,:); FL3(idx,:) = F(6,:);
        FR1(idx,3) = norm(F(1,:)); FR2(idx,3) = norm(F(2,:)); FR3(idx,3) = norm(F(3,:));
        FL1(idx,3) = norm(F(4,:)); FL2(idx,3) = norm(F(5,:)); FL3(idx,3) = norm(F(6,:));
    end

    [~, body_p] = vrobot.Main.simxGetObjectPosition(vrobot.ClientID, vrobot.Body_Handle, -1, vrobot.Main.simx_opmode_oneshot);
    if exist('body_p', 'var') && length(body_p) == 3
        realX_log(sim_frame) = body_p(1);
        realY_log(sim_frame) = body_p(2);
        realZ_log(sim_frame) = body_p(3);
    else
        realX_log(sim_frame) = NaN; realY_log(sim_frame) = NaN; realZ_log(sim_frame) = NaN;
    end
    body_eul = vrobot.get_body_eul();
    if exist('body_eul', 'var') && numel(body_eul) == 3
        bodyRoll_log(sim_frame) = body_eul(1) * 180 / pi;
        bodyPitch_log(sim_frame) = body_eul(2) * 180 / pi;
        bodyYaw_log(sim_frame) = body_eul(3) * 180 / pi;
    else
        bodyRoll_log(sim_frame) = NaN; bodyPitch_log(sim_frame) = NaN; bodyYaw_log(sim_frame) = NaN;
    end

    rear_legs_finished = true;
    for rear_leg = rear_legs
        rear_leg_is_stable = z_locked(rear_leg) && ~is_recovering(rear_leg) && probe_wait(rear_leg) == 0;
        if ~(rear_leg_is_stable && real_foot_x_log(rear_leg) >= final_pit_x_max)
            rear_legs_finished = false;
            break;
        end
    end
    if rear_legs_finished
        fprintf('  [结束判定] 两条后腿均已稳定越过最后一个坑后沿 %.2fm，腿3 X=%.2f，腿6 X=%.2f，提前结束仿真。\n', ...
            final_pit_x_max, real_foot_x_log(rear_legs(1)), real_foot_x_log(rear_legs(2)));
        break;
    end

    % 物理同步机制：探测深坑期间强制暂停步态时钟
    if ~any(is_recovering) && ~any(probe_wait > 0)
        kk = kk + 1;
    end
    sim_frame = sim_frame + 1;

    if mod(sim_frame, 500) == 0
        fprintf('  当前进度: 第 %d 仿真物理帧 (kk=%d)...\n', sim_frame, kk);
    end
end

% 5. 仿真收尾与数据保存
vrobot.pause();
vrobot.stop();
vrobot.Main.delete();  % 释放 remoteApi 库资源，避免下次运行端口占用
run_end_str = datestr(now,'yyyy-mm-dd HH:MM:SS');
wall_time_sec = toc(run_timer);
Joint_Learned(sim_frame:end, :) = [];

fprintf('\n闭环示教完成！(总实际物理帧数：%d)\n', size(Joint_Learned, 1));
learned_path = fullfile(fileparts(mfilename('fullpath')), 'export_data', 'walk_ditch_learned.mat');
save(learned_path, 'Joint_Learned');
fprintf('Saved: %s\n', learned_path);

artifact_learned_path = learned_path;
if isfield(export_meta, 'artifact_output_dir') && ~isempty(export_meta.artifact_output_dir)
    if ~exist(export_meta.artifact_output_dir, 'dir')
        mkdir(export_meta.artifact_output_dir);
    end
    artifact_learned_path = fullfile(export_meta.artifact_output_dir, 'ditch_final_closed_loop_joint_used.mat');
    save(artifact_learned_path, 'Joint_Learned');
end

%% ================= 统一指标导出 =================
scene_info = hexapod_scene_info('ditch');
if exist('FR1', 'var') && ~isempty(FR1)
    leg_force_mag = [FR1(:,3), FR2(:,3), FR3(:,3), FL1(:,3), FL2(:,3), FL3(:,3)];
else
    leg_force_mag = zeros(0, 6);
end

telemetry = struct();
logged_frame_count = max(sim_frame - 1, 0);
telemetry.realX = realX_log(1:logged_frame_count);
telemetry.realY = realY_log(1:logged_frame_count);
telemetry.realZ = realZ_log(1:logged_frame_count);
telemetry.bodyEulerDeg = [bodyRoll_log(1:logged_frame_count), bodyPitch_log(1:logged_frame_count), bodyYaw_log(1:logged_frame_count)];
telemetry.legForceMag = leg_force_mag;
telemetry.control_dt_sec = Control_T / 1000;
telemetry.extra = struct();
telemetry.extra.recover_count_total = recover_count_total;
telemetry.extra.learned_path = learned_path;

meta = struct();
meta.scene_name = scene_info.scene_name;
meta.scene_label = scene_info.scene_label;
meta.scene_variant = 'ditch_sidepits';
meta.source_flow = 'CoppeliaSim_learn_ditch';
meta.entry_pattern = 'ditch';
meta.run_now = run_start_now;
meta.run_timestamp = run_start_str;
meta.control_dt_ms = Control_T;
meta.run_end_str = run_end_str;
meta.wall_time_sec = wall_time_sec;
meta.learned_path = learned_path;
meta.natural_total_frames = natural_total_frames;
meta.target_total_frames = target_total_frames;
meta.source_artifact_path = artifact_learned_path;
meta.frame_normalization = 'resampled_reference';
if target_total_frames == natural_total_frames
    meta.frame_normalization = 'none';
end

if isfield(export_meta, 'scene_name') && ~isempty(export_meta.scene_name)
    meta.scene_name = export_meta.scene_name;
end
if isfield(export_meta, 'scene_label') && ~isempty(export_meta.scene_label)
    meta.scene_label = export_meta.scene_label;
end
if isfield(export_meta, 'scene_variant') && ~isempty(export_meta.scene_variant)
    meta.scene_variant = export_meta.scene_variant;
end
if isfield(export_meta, 'source_flow') && ~isempty(export_meta.source_flow)
    meta.source_flow = export_meta.source_flow;
end
if isfield(export_meta, 'entry_pattern') && ~isempty(export_meta.entry_pattern)
    meta.entry_pattern = export_meta.entry_pattern;
end
copy_fields = {'compare_group_id', 'case_id', 'case_description', 'repeat_index', ...
    'target_total_frames', 'natural_total_frames', 'source_artifact_path', ...
    'frame_normalization', 'output_dir'};
for copy_idx = 1:numel(copy_fields)
    field_name = copy_fields{copy_idx};
    if isfield(export_meta, field_name) && ~isempty(export_meta.(field_name))
        meta.(field_name) = export_meta.(field_name);
    end
end

if ~isfield(meta, 'output_dir') || isempty(meta.output_dir)
    [run_output_dir, ~] = hexapod_prepare_output_dir(project_root, meta.scene_name, meta.run_now);
    meta.output_dir = run_output_dir;
else
    run_output_dir = meta.output_dir;
    if ~exist(run_output_dir, 'dir')
        mkdir(run_output_dir);
    end
end

log_learned_path = fullfile(run_output_dir, 'walk_ditch_learned.mat');
save(log_learned_path, 'Joint_Learned');
fprintf('Log Saved: %s\n', log_learned_path);

if (~isfield(export_meta, 'artifact_output_dir') || isempty(export_meta.artifact_output_dir)) && ...
        (~isfield(meta, 'source_artifact_path') || isempty(meta.source_artifact_path) || strcmp(meta.source_artifact_path, learned_path))
    meta.source_artifact_path = log_learned_path;
end

[metrics, run_output_dir] = hexapod_export_metrics(project_root, telemetry, meta);

fprintf('统一指标文件已保存：\n');
fprintf('  输出目录: %s\n', run_output_dir);
fprintf('  指标文件: %s\n', fullfile(run_output_dir, 'metrics.mat'));
fprintf('  摘要文件: %s\n', fullfile(run_output_dir, 'metrics_summary.md'));
fprintf('  场景类别: %s (%s)\n', metrics.meta.scene_name, metrics.meta.scene_label);
fprintf('  避险恢复总次数: %.0f\n', metrics.scene.recover_count_total);
end

function result = is_in_any_trap(foot_x, foot_y, pits)
    result = false;
    for pit_idx = 1:size(pits, 1)
        if foot_x >= pits(pit_idx,1) && foot_x <= pits(pit_idx,2)
            side = pits(pit_idx,3);
            if is_pit_side_match(foot_y, side)
                result = true;
                return;
            end
        end
    end
end

function pit_idx = find_active_recover_pit_idx(foot_x, foot_y, pits)
% find_active_recover_pit_idx  为当前恢复流程锁定坑编号。
%   规则：
%   1) 若足端已落在兼容坑区间内，直接返回该坑；
%   2) 否则只在前沿位于足端后方的兼容坑里选择 x_min 最大的那个；
%   3) 若不存在后方兼容坑，则返回 0，由上层决定保守退让目标。
    pit_idx = 0;
    candidate_idx = [];

    for idx = 1:size(pits, 1)
        side = pits(idx, 3);
        if ~is_pit_side_match(foot_y, side)
            continue;
        end

        if foot_x >= pits(idx,1) && foot_x <= pits(idx,2)
            pit_idx = idx;
            return;
        end

        if pits(idx,1) <= foot_x
            candidate_idx(end + 1) = idx; %#ok<AGROW>
        end
    end

    if ~isempty(candidate_idx)
        [~, local_idx] = max(pits(candidate_idx, 1));
        pit_idx = candidate_idx(local_idx);
    end
end

function target_world_x = compute_retreat_target_world_x(foot_x, foot_y, pit_idx, pits, clearance)
% compute_retreat_target_world_x  计算动态回撤的世界坐标目标 X。
%   动态回撤统一退到当前坑前沿外 clearance 的位置。
    if pit_idx <= 0
        pit_idx = find_active_recover_pit_idx(foot_x, foot_y, pits);
    end

    if pit_idx > 0
        target_world_x = pits(pit_idx, 1) - clearance;
    else
        target_world_x = foot_x - clearance;
    end
end

function result = is_pit_side_match(foot_y, side)
    result = side == 0 || (side == 1 && foot_y > 0) || (side == -1 && foot_y < 0);
end

function [is_recovering, recover_state, recover_frame, reflex_start_x, reflex_start_z, ...
          trap_escape_count, escape_step_len, single_escape_target_world_x] = ...
    try_trigger_assist_escape(trigger_leg, z_locked, is_recovering, probe_wait, ...
        recover_state, recover_frame, reflex_start_x, reflex_start_z, ...
        trap_escape_count, escape_step_len, max_attempts, assist_step, ...
        x0, kk, offset_x, delta_step_compensation, real_foot_x_log, real_foot_y_log, locked_z_val, pit_defs, single_escape_target_world_x)
% try_trigger_assist_escape  当前腿踩实后，检查其余支撑腿是否仍落在坑中区间，
%   若是则触发小步单腿脱困。
    for other_leg = 1:6
        if other_leg ~= trigger_leg && z_locked(other_leg) && ~is_recovering(other_leg) ...
                && probe_wait(other_leg) == 0 && recover_state(other_leg) == 0 ...
                && trap_escape_count(other_leg) < max_attempts
            other_cur_x = x0(other_leg, kk) + offset_x(other_leg);
            if other_leg <= 3
                other_cur_x = other_cur_x + delta_step_compensation;
            else
                other_cur_x = other_cur_x - delta_step_compensation;
            end
            other_real_x = real_foot_x_log(other_leg);
            if is_in_any_trap(other_real_x, real_foot_y_log(other_leg), pit_defs)
                recover_state(other_leg) = 5;
                is_recovering(other_leg) = true;
                recover_frame(other_leg) = 0;
                reflex_start_x(other_leg) = other_cur_x;
                reflex_start_z(other_leg) = locked_z_val(other_leg);
                trap_escape_count(other_leg) = trap_escape_count(other_leg) + 1;
                escape_step_len(other_leg) = assist_step;
                single_escape_target_world_x(other_leg) = NaN;
                fprintf('  [单腿脱困] 腿 %d 已踩实，发现腿 %d 的 X=%.2f 仍在坑中区间，触发小步单腿脱困。\n', ...
                    trigger_leg, other_leg, other_real_x);
            end
        end
    end
end
