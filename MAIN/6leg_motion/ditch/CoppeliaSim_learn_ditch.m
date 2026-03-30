function CoppeliaSim_learn_ditch()
% =========================================================================
% CoppeliaSim_learn_ditch.m —— 六足机器人深沟跨越闭环控制系统 (最终版)
% 
% 核心控制架构：
%   1. 异步动态探测策略：融合“跌落短路检测”与“踩实防抖逻辑”，实现高速避险。
%   2. 稳健触地锁定：通过原位锁定法 (In-place Freezing) 消除垂直冲击。
%   3. 闭环步幅不对称补偿：动态调节左右步距以实时抵消波浪步态偏航。
%   4. 重心位姿管理：包含跨坑重心前移 (CoG Shift) 保护机制。
% =========================================================================

%% 1. 环境准备与数据加载
clear; clc; close all;

% 作为独立入口运行时，先把项目根目录及其子目录加入搜索路径，
% 否则在干净 MATLAB 会话里找不到 lib/MatlabVrep.m 等依赖。
project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(project_root));
fprintf('--- 启动完全体物理示教模式 (Hexapod Ditch Crossing v4) ---\n');

run_start_str = datestr(now,'yyyy-mm-dd HH:MM:SS');
run_start_now = now;
run_timer = tic;

project_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
base_path = fullfile(fileparts(mfilename('fullpath')), 'export_data', 'xyz_base.mat');
load(base_path, 'xq', 'x0', 'y0', 'z0', 'xb', 'yb', 'zb', 'zf0');

Data_Num = length(xq); 
Control_T = 5; 
vrobot = MatlabVrep(Control_T);
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
has_retreated = false;                 % 探坑腿是否已完成避险后退
is_shifting_x = false;                 % 记录重心是否正在前移
front_leg_confirmed = false(1, 6);     % 前腿是否已在对岸形成稳定支撑
front_leg_hard_confirmed = false(1, 6);% 前腿是否已明显越过深沟，可长期保持确认
middle_leg_confirmed = false(1, 6);    % 中腿是否已在对岸形成稳定支撑
middle_leg_hard_confirmed = false(1, 6);% 中腿是否已明显越过深沟，可长期保持确认
last_cog_stage = -1;                   % 记录上一次重心阶段，避免重复打印
cog_control_finished = false;          % 本次过坑的重心补偿是否已完成，完成后不再重新进入

% 避险反射相关计数器与变量 (Reflex States)
recover_state = zeros(1, 6);           % 反射状态机: 1=直接前跨, 2=失败后退回, 3=退回后二次跨越, 4=最终止损, 5=单腿脱困
recover_frame = zeros(1, 6);           % 反射动作执行帧计数
reflex_start_x = zeros(1, 6);          % 记录反射动作起始坐标
reflex_start_z = zeros(1, 6);
offset_x = zeros(1, 6);                % 足端 X 轴累积偏移
trap_escape_count = zeros(1, 6);       % 单腿脱困尝试计数，避免陷入重复脱困
escape_step_len = zeros(1, 6);         % 每条腿当前单腿脱困的前跨距离

% 平滑过渡与锁定变量 (Smoothing & Locking)
locked_z_val = zf0 * ones(1, 6);       % 存储支撑相时的物理坐标锁定值
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
pit_edge_x = 1.5;                      % 深沟前沿世界坐标
pit_trap_x_min = 1.5;                  % 足端若落在此区间内，视为仍处于坑内/坑边
pit_trap_x_max = 2.2;
front_confirm_margin = 0.05;           % 前腿完全越过坑中区间后，再额外留出的确认余量
front_hard_confirm_x = 2.4;            % 前腿明显越过深沟后的永久确认阈值
middle_hard_confirm_x = 2.4;           % 中腿明显越过深沟后的永久确认阈值
cog_control_enter_x = 0.25;            % 重心补偿逻辑的启用阈值
cog_control_exit_x = 4.8;              % 重心补偿逻辑的退出阈值，适当放宽避免边界抖动反复进出
x_offset_stage0 = -0.15;               % 阶段0：前腿均未确认，重心后移保稳定
x_offset_stage1 = 0.00;                % 阶段1：前腿未全确认前，重心保持中性
x_offset_stage2 = 0.20;                % 阶段2：两条前腿均确认，先补偿 20cm
x_offset_stage3 = 0.40;                % 阶段3：两条中腿也确认，再额外补偿 20cm

% 单腿脱困参数：仅在“已踩实但落脚 X 仍处于坑中区间”时触发
single_escape_step_x = 0.55;           % 当前腿自己落入坑中区间时的单腿脱困步长
assist_escape_step_x = 0.30;           % 其他腿被顺带检测出仍在坑中区间时，使用较小的补跨步长
single_escape_peak_h = 0.30;           % 单腿脱困抬腿高度
single_escape_land_z = zf0 - 0.085;    % 脱困后保留轻微深探，继续验证是否踩实
max_trap_escape_attempts = 1;          % 单腿脱困最多尝试一次，失败后转入常规退回补救

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

realX_log = []; realY_log = []; realZ_log = [];
real_body = [xb(1); yb(1); NOMINAL_BODY_Z];
air_count = zeros(1, 6);               % 支撑相连续失载计数器

%% 3. 主仿真循环
while kk <= Data_Num
    
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
        cur_front_x = x0(front_leg, kk) + offset_x(front_leg);
        if front_leg <= 3
            cur_front_x = cur_front_x + delta_step_compensation;
        else
            cur_front_x = cur_front_x - delta_step_compensation;
        end
        front_world_x = real_body(1) + (cur_front_x - xb(kk));

        % 一级确认条件：仍按“稳定锁定 + 越过坑中区间”判断
        front_leg_is_stable = ...
            z_locked(front_leg) && ...
            ~is_recovering(front_leg) && ...
            probe_wait(front_leg) == 0;
        front_leg_soft_confirmed = front_leg_is_stable && ...
            front_world_x > (pit_trap_x_max + front_confirm_margin);

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
        cur_middle_x = x0(middle_leg, kk) + offset_x(middle_leg);
        if middle_leg <= 3
            cur_middle_x = cur_middle_x + delta_step_compensation;
        else
            cur_middle_x = cur_middle_x - delta_step_compensation;
        end
        middle_world_x = real_body(1) + (cur_middle_x - xb(kk));

        middle_leg_is_stable = ...
            z_locked(middle_leg) && ...
            ~is_recovering(middle_leg) && ...
            probe_wait(middle_leg) == 0;
        middle_leg_soft_confirmed = middle_leg_is_stable && ...
            middle_world_x > (pit_trap_x_max + front_confirm_margin);

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
            target_x_offset = x_offset_stage0;
        elseif confirmed_front_count < numel(front_legs)
            raw_cog_stage_id = 1;
            target_x_offset = x_offset_stage1;
        elseif confirmed_middle_count < numel(middle_legs)
            raw_cog_stage_id = 2;
            target_x_offset = x_offset_stage2;
        else
            raw_cog_stage_id = 3;
            target_x_offset = x_offset_stage3;
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
        
        % 传感数据采样
        if sim_frame > WARMUP_FRAMES
            force_mag = norm(F(leg, :));
            [~, foot_pos] = vrobot.Main.simxGetObjectPosition(vrobot.ClientID, vrobot.Force_sensor_Handle(leg), -1, vrobot.Main.simx_opmode_oneshot);
            real_foot_x = foot_pos(1);
            real_foot_z = foot_pos(3);
        else
            force_mag = 9999; 
            real_foot_x = real_body(1) + (cur_x - xb(kk));
            real_foot_z = 1.05;
        end

        % [模块 C]: 腿部控制与反射管理
        if is_recovering(leg)
            recover_frame(leg) = recover_frame(leg) + 1;
            rf = recover_frame(leg);
            
            if recover_state(leg) == 1 % 行为阶段 1：优先直接前跨试探
                safe_x = reflex_start_x(leg) + 0.75;
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
                        if real_foot_x >= pit_trap_x_min && real_foot_x <= pit_trap_x_max && trap_escape_count(leg) < max_trap_escape_attempts
                            recover_state(leg) = 5;
                            recover_frame(leg) = 0;
                            reflex_start_x(leg) = cur_x;
                            reflex_start_z(leg) = cur_z;
                            trap_escape_count(leg) = trap_escape_count(leg) + 1;
                            escape_step_len(leg) = single_escape_step_x;
                            fprintf('  [单腿脱困] 腿 %d 已踩实但 X=%.2f 仍在坑中区间，启动单腿脱困。\n', leg, real_foot_x);
                        elseif real_foot_x >= pit_trap_x_min && real_foot_x <= pit_trap_x_max
                            recover_state(leg) = 2;
                            recover_frame(leg) = 0;
                            reflex_start_x(leg) = cur_x;
                            reflex_start_z(leg) = cur_z;
                            fprintf('  [避险调整] 腿 %d 落脚仍在坑中区间且脱困次数已用尽，转入退回补救。\n', leg);
                        else
                            z_locked(leg) = true;
                            locked_z_val(leg) = cur_z;
                            offset_x(leg) = cur_x - x0(leg, kk);
                            recover_state(leg) = 0;
                            is_recovering(leg) = false;
                            trap_escape_count(leg) = 0;
                            escape_step_len(leg) = 0;
                            fprintf('  [避险成功] 腿 %d 直接前跨成功落位。物理Z=%.3f\n', leg, real_foot_z);
                            for other_leg = 1:6
                                if other_leg ~= leg && z_locked(other_leg) && ~is_recovering(other_leg) && probe_wait(other_leg) == 0 && recover_state(other_leg) == 0 && trap_escape_count(other_leg) < max_trap_escape_attempts
                                    other_cur_x = x0(other_leg, kk) + offset_x(other_leg);
                                    if other_leg <= 3
                                        other_cur_x = other_cur_x + delta_step_compensation;
                                    else
                                        other_cur_x = other_cur_x - delta_step_compensation;
                                    end
                                    other_world_x = real_body(1) + (other_cur_x - xb(kk));
                                    if other_world_x >= pit_trap_x_min && other_world_x <= pit_trap_x_max
                                        recover_state(other_leg) = 5;
                                        is_recovering(other_leg) = true;
                                        recover_frame(other_leg) = 0;
                                        reflex_start_x(other_leg) = other_cur_x;
                                        reflex_start_z(other_leg) = locked_z_val(other_leg);
                                        trap_escape_count(other_leg) = trap_escape_count(other_leg) + 1;
                                        escape_step_len(other_leg) = assist_escape_step_x;
                                        fprintf('  [单腿脱困] 腿 %d 已踩实，发现腿 %d 的 X=%.2f 仍在坑中区间，触发小步单腿脱困。\n', leg, other_leg, other_world_x);
                                    end
                                end
                            end
                        end
                    else
                        recover_state(leg) = 2;
                        recover_frame(leg) = 0;
                        reflex_start_x(leg) = cur_x;
                        reflex_start_z(leg) = cur_z;
                        fprintf('  [避险调整] 腿 %d 直接前跨未踩实，转入退回补救。\n', leg);
                    end
                end
                
            elseif recover_state(leg) == 2 % 行为阶段 2：直接前跨失败后退回安全区
                safe_x = reflex_start_x(leg) - 0.8;
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
                    recover_state(leg) = 3;
                    recover_frame(leg) = 0;
                    reflex_start_x(leg) = cur_x;
                    reflex_start_z(leg) = cur_z;
                    has_retreated = true;
                    fprintf('  [避险反射] 腿 %d 已退回安全区，开始二次跨越。\n', leg);
                end
                
            elseif recover_state(leg) == 3 % 行为阶段 3：退回后的二次跨越
                safe_x = reflex_start_x(leg) + 0.85;
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
                        if real_foot_x >= pit_trap_x_min && real_foot_x <= pit_trap_x_max && trap_escape_count(leg) < max_trap_escape_attempts
                            recover_state(leg) = 5;
                            recover_frame(leg) = 0;
                            reflex_start_x(leg) = cur_x;
                            reflex_start_z(leg) = cur_z;
                            trap_escape_count(leg) = trap_escape_count(leg) + 1;
                            escape_step_len(leg) = single_escape_step_x;
                            fprintf('  [单腿脱困] 腿 %d 二次跨越后已踩实，但 X=%.2f 仍在坑中区间，启动单腿脱困。\n', leg, real_foot_x);
                        elseif real_foot_x >= pit_trap_x_min && real_foot_x <= pit_trap_x_max
                            recover_state(leg) = 4;
                            recover_frame(leg) = 0;
                            reflex_start_x(leg) = cur_x;
                            reflex_start_z(leg) = cur_z;
                            fprintf('  *** [避险失败] 腿 %d 二次跨越后仍落在坑中区间且脱困次数已用尽，转入最终止损。\n', leg);
                        else
                            z_locked(leg) = true;
                            locked_z_val(leg) = cur_z;
                            offset_x(leg) = cur_x - x0(leg, kk);
                            recover_state(leg) = 0;
                            is_recovering(leg) = false;
                            trap_escape_count(leg) = 0;
                            escape_step_len(leg) = 0;
                            fprintf('  [避险成功] 腿 %d 二次跨越成功落位。物理Z=%.3f\n', leg, real_foot_z);
                            for other_leg = 1:6
                                if other_leg ~= leg && z_locked(other_leg) && ~is_recovering(other_leg) && probe_wait(other_leg) == 0 && recover_state(other_leg) == 0 && trap_escape_count(other_leg) < max_trap_escape_attempts
                                    other_cur_x = x0(other_leg, kk) + offset_x(other_leg);
                                    if other_leg <= 3
                                        other_cur_x = other_cur_x + delta_step_compensation;
                                    else
                                        other_cur_x = other_cur_x - delta_step_compensation;
                                    end
                                    other_world_x = real_body(1) + (other_cur_x - xb(kk));
                                    if other_world_x >= pit_trap_x_min && other_world_x <= pit_trap_x_max
                                        recover_state(other_leg) = 5;
                                        is_recovering(other_leg) = true;
                                        recover_frame(other_leg) = 0;
                                        reflex_start_x(other_leg) = other_cur_x;
                                        reflex_start_z(other_leg) = locked_z_val(other_leg);
                                        trap_escape_count(other_leg) = trap_escape_count(other_leg) + 1;
                                        escape_step_len(other_leg) = assist_escape_step_x;
                                        fprintf('  [单腿脱困] 腿 %d 已踩实，发现腿 %d 的 X=%.2f 仍在坑中区间，触发小步单腿脱困。\n', leg, other_leg, other_world_x);
                                    end
                                end
                            end
                        end
                    else
                        recover_state(leg) = 4;
                        recover_frame(leg) = 0;
                        reflex_start_x(leg) = cur_x;
                        reflex_start_z(leg) = cur_z;
                        fprintf('  *** [避险失败] 腿 %d 二次跨越仍未踩实，转入最终止损。\n', leg);
                    end
                end

            elseif recover_state(leg) == 4 % 行为阶段 4：二次失败后的最终止损
                safe_x = reflex_start_x(leg) - 0.8;
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
                    z_locked(leg) = true;
                    locked_z_val(leg) = cur_z;
                    offset_x(leg) = cur_x - x0(leg, kk);
                    recover_state(leg) = 0;
                    is_recovering(leg) = false;
                    trap_escape_count(leg) = 0;
                    escape_step_len(leg) = 0;
                    fprintf('  [避险止损] 腿 %d 已退回安全区，进入保护性静止状态。\n', leg);
                end

            elseif recover_state(leg) == 5 % 行为阶段 5：已踩实但仍落在坑中区间，执行单腿脱困
                safe_x = reflex_start_x(leg) + max(escape_step_len(leg), assist_escape_step_x);
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
                    if real_foot_z >= 0.98 && ~(real_foot_x >= pit_trap_x_min && real_foot_x <= pit_trap_x_max)
                        z_locked(leg) = true;
                        locked_z_val(leg) = cur_z;
                        offset_x(leg) = cur_x - x0(leg, kk);
                        recover_state(leg) = 0;
                        is_recovering(leg) = false;
                        trap_escape_count(leg) = 0;
                        escape_step_len(leg) = 0;
                        fprintf('  [单腿脱困成功] 腿 %d 已脱离坑中区间并重新落稳。X=%.2f, Z=%.3f\n', leg, real_foot_x, real_foot_z);
                        for other_leg = 1:6
                            if other_leg ~= leg && z_locked(other_leg) && ~is_recovering(other_leg) && probe_wait(other_leg) == 0 && recover_state(other_leg) == 0 && trap_escape_count(other_leg) < max_trap_escape_attempts
                                other_cur_x = x0(other_leg, kk) + offset_x(other_leg);
                                if other_leg <= 3
                                    other_cur_x = other_cur_x + delta_step_compensation;
                                else
                                    other_cur_x = other_cur_x - delta_step_compensation;
                                end
                                other_world_x = real_body(1) + (other_cur_x - xb(kk));
                                if other_world_x >= pit_trap_x_min && other_world_x <= pit_trap_x_max
                                    recover_state(other_leg) = 5;
                                    is_recovering(other_leg) = true;
                                    recover_frame(other_leg) = 0;
                                    reflex_start_x(other_leg) = other_cur_x;
                                    reflex_start_z(other_leg) = locked_z_val(other_leg);
                                    trap_escape_count(other_leg) = trap_escape_count(other_leg) + 1;
                                    escape_step_len(other_leg) = assist_escape_step_x;
                                    fprintf('  [单腿脱困] 腿 %d 已踩实，发现腿 %d 的 X=%.2f 仍在坑中区间，触发小步单腿脱困。\n', leg, other_leg, other_world_x);
                                end
                            end
                        end
                    else
                        recover_state(leg) = 2;
                        recover_frame(leg) = 0;
                        reflex_start_x(leg) = cur_x;
                        reflex_start_z(leg) = cur_z;
                        escape_step_len(leg) = 0;
                        fprintf('  [单腿脱困失败] 腿 %d 脱困后仍不稳定，转入退回补救。X=%.2f, Z=%.3f\n', leg, real_foot_x, real_foot_z);
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
                        real_foot_x = real_body(1) + (cur_x - xb(kk));
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
                    end
                end
            end
            
            % [子模块 C2]: 着陆动态探测 (跌落极速短路响应机制)
            if z0(leg, kk) < zf0 - 0.098 && ~z_locked(leg) && ~any(is_recovering)
                probe_wait(leg) = probe_wait(leg) + 1;
                real_foot_x = real_body(1) + (cur_x - xb(kk));
                
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
                    has_retreated = false;  
                    trap_escape_count(leg) = 0;
                    target_yaw_cmd = 0;     
                    current_yaw_cmd = 0;
                    
                % 稳健判定：坚持 30 帧以上高度正常，判定为坚实地面
                elseif probe_wait(leg) > probe_confirm_frames
                    if real_foot_x >= pit_trap_x_min && real_foot_x <= pit_trap_x_max && trap_escape_count(leg) < max_trap_escape_attempts
                        recover_state(leg) = 5;
                        is_recovering(leg) = true;
                        probe_wait(leg) = 0;
                        recover_frame(leg) = 0;
                        reflex_start_x(leg) = cur_x;
                        reflex_start_z(leg) = cur_z;
                        trap_escape_count(leg) = trap_escape_count(leg) + 1;
                        escape_step_len(leg) = single_escape_step_x;
                        fprintf('  [单腿脱困] 腿 %d 探测踩实，但 X=%.2f 落在坑中区间，启动单腿脱困。\n', leg, real_foot_x);
                    elseif real_foot_x >= pit_trap_x_min && real_foot_x <= pit_trap_x_max
                        recover_state(leg) = 1;
                        is_recovering(leg) = true;
                        probe_wait(leg) = 0;
                        recover_frame(leg) = 0;
                        reflex_start_x(leg) = cur_x;
                        reflex_start_z(leg) = cur_z;
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
                        for other_leg = 1:6
                            if other_leg ~= leg && z_locked(other_leg) && ~is_recovering(other_leg) && probe_wait(other_leg) == 0 && recover_state(other_leg) == 0 && trap_escape_count(other_leg) < max_trap_escape_attempts
                                other_cur_x = x0(other_leg, kk) + offset_x(other_leg);
                                if other_leg <= 3
                                    other_cur_x = other_cur_x + delta_step_compensation;
                                else
                                    other_cur_x = other_cur_x - delta_step_compensation;
                                end
                                other_world_x = real_body(1) + (other_cur_x - xb(kk));
                                if other_world_x >= pit_trap_x_min && other_world_x <= pit_trap_x_max
                                    recover_state(other_leg) = 5;
                                    is_recovering(other_leg) = true;
                                    recover_frame(other_leg) = 0;
                                    reflex_start_x(other_leg) = other_cur_x;
                                    reflex_start_z(other_leg) = locked_z_val(other_leg);
                                    trap_escape_count(other_leg) = trap_escape_count(other_leg) + 1;
                                    escape_step_len(other_leg) = assist_escape_step_x;
                                    fprintf('  [单腿脱困] 腿 %d 已踩实，发现腿 %d 的 X=%.2f 仍在坑中区间，触发小步单腿脱困。\n', leg, other_leg, other_world_x);
                                end
                            end
                        end
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
        for j = 1:3; Joint_Learned(sim_frame, j + 3*leg - 3) = robot_ik(j + 3*leg - 2).q; end
    end
    
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
run_end_str = datestr(now,'yyyy-mm-dd HH:MM:SS');
wall_time_sec = toc(run_timer);
Joint_Learned(sim_frame:end, :) = [];

fprintf('\n闭环示教完成！(总实际物理帧数：%d)\n', size(Joint_Learned, 1));
learned_path = fullfile(fileparts(mfilename('fullpath')), 'export_data', 'walk_ditch_learned.mat');
save(learned_path, 'Joint_Learned');
fprintf('已保存: %s\n', learned_path);

%% ================= 绘图与摘要生成 =================
cleanup_and_export(run_start_now, run_start_str, run_end_str, wall_time_sec, realX_log, realY_log, realZ_log, FL1, FL2, FL3, FR1, FR2, FR3, Joint_Learned, Control_T, learned_path, project_root);
end

function cleanup_and_export(run_start_now, run_start_str, run_end_str, wall_time_sec, realX_log, realY_log, realZ_log, FL1, FL2, FL3, FR1, FR2, FR3, Joint_Learned, Control_T, learned_path, project_root)
    F_all = FL1+FL2+FL3+FR1+FR2+FR3;
    h_fig1 = figure('Name', '各腿末端受力', 'NumberTitle', 'off', 'Visible', 'off');
    subplot(2,3,1); plot(FL1(:,3)); title('左腿1受力'); subplot(2,3,2); plot(FL2(:,3)); title('左腿2受力');
    subplot(2,3,3); plot(FL3(:,3)); title('左腿3受力'); subplot(2,3,4); plot(FR1(:,3)); title('右腿1受力');
    subplot(2,3,5); plot(FR2(:,3)); title('右腿2受力'); subplot(2,3,6); plot(FR3(:,3)); title('右腿3受力');
    
    h_fig3 = figure('Name', '轨迹追踪', 'NumberTitle', 'off', 'Visible', 'off');
    subplot(3,1,1); plot(realX_log); title('X 位移'); subplot(3,1,2); plot(realY_log); title('Y 偏航');
    subplot(3,1,3); plot(realX_log, realZ_log); title('Z-X 垂直面轨迹');

    log_root = fullfile(project_root, 'log');
    run_output_dir = fullfile(log_root, datestr(run_start_now, 'yymmdd'), sprintf('%s_learn', datestr(run_start_now, 'HH.MM')));
    if ~exist(run_output_dir, 'dir'), mkdir(run_output_dir); end
    
    saveas(h_fig1, fullfile(run_output_dir, 'leg_force.png'));
    saveas(h_fig3, fullfile(run_output_dir, 'trajectory.png'));
    fprintf('仿真图表已存入 %s\n', run_output_dir);
end
