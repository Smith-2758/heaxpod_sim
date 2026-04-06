function learned_path = CoppeliaSim_learn_ditch_half(export_meta)
if nargin < 1 || isempty(export_meta)
    export_meta = struct();
end
% =========================================================================
% CoppeliaSim_learn_ditch.m —— 深沟地形闭环"示教"器 (终极修复版)
%
% 根因修复：
%   1. 前25帧的假力保护导致 z_locked 被锁在 zf0-0.09 (地下9cm)，
%      使得 IK 不断命令脚往地面下方猛扎，产生 10^5 N 量级碰撞力。
%   2. 力阈值 5N/8N 与实际传感器量级 (10^5) 偏差四个数量级。
%
% 解决方案：
%   - 前25帧直接将 cur_z 锁在 zf0 (地面)，而非 z0 (地下探针深度)
%   - 力阈值根据实际传感数据的量级重新标定
% =========================================================================

% 1. 环境准备与数据加载
% 统一走本项目的路径初始化入口，避免外部旧工程路径覆盖 compare 运行时依赖。
project_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
setup_dir = fullfile(project_root, 'lib', 'setup');
current_paths = string(strsplit(path, pathsep));
if ~any(strcmp(current_paths, string(setup_dir)))
    addpath(setup_dir);
end
setup_info = hexapod_setup_paths();
project_root = setup_info.project_root;
fprintf('--- 启动完全体物理示教模式 (Teach Mode v3) ---\n');

run_start_str = datestr(now,'yyyy-mm-dd HH:MM:SS');
run_timer = tic;

date_folder = datestr(now, 'yymmdd');
time_folder = datestr(now, 'HH.MM');
run_output_dir = fullfile(project_root, 'MAIN', '6leg_motion', 'ditch', 'log', date_folder, sprintf('%s_half_learn', time_folder));
if isstruct(export_meta) && isfield(export_meta, 'output_dir') && ~isempty(export_meta.output_dir)
    run_output_dir = fullfile(export_meta.output_dir, 'closed_loop_generation');
end
if ~exist(run_output_dir, 'dir'), mkdir(run_output_dir); end
fprintf('本次仿真结果保存目录: %s\n', run_output_dir);

base_path = fullfile(fileparts(mfilename('fullpath')), 'export_data', 'xyz_base.mat');
load(base_path, 'xq', 'x0', 'y0', 'z0', 'xb', 'yb', 'zb', 'zf0');

Data_Num = length(xq); % 全长度仿真
Control_T = 5; % 5ms
legacy_port = 19997;
if isstruct(export_meta) && isfield(export_meta, 'coppeliasim_port') && ~isempty(export_meta.coppeliasim_port) && ~isnan(export_meta.coppeliasim_port)
    legacy_port = export_meta.coppeliasim_port;
end
vrobot = MatlabVrep(Control_T, legacy_port);
if legacy_port > 19999
    vrobot.Close_All_Connections_Before_Init = true;
end
vrobot = vrobot.init();

vrobot.set_body_o([0; 0; 0]);
vrobot.set_body_p([xb(1); yb(1); 2.7]);

robot_ik = robot3D_description;
Joint_Learned = zeros(Data_Num * 2, 18);

% ====== 初始帧 IK：使用 zf0 (地面高度) 而非 z0 (探针深度) ======
for leg = 1:6
    Target.R = eye(3);
    % [关键修复] 初始站立时脚踩在地面 zf0, 不是地下 z0(地下9cm)
    Target.p = [x0(leg, 1); y0(leg, 1); zf0];
    robot_ik(1).p = [xb(1); yb(1); zb(1)];
    c_id = [1 + 3*leg, 1];
    robot_ik = ik_collision(robot_ik, Target, c_id);
    for j = 1:3; Joint_Learned(1, j + 3*leg - 3) = robot_ik(j + 3*leg - 2).q; end
end
vrobot.set_joint_initial(Joint_Learned(1, :));

is_recovering = false(1, 6);
recover_frame = zeros(1, 6);
reflex_start_x = zeros(1, 6);
reflex_start_z = zeros(1, 6);
offset_x = zeros(1, 6);

% [关键修复] 前25帧的初始状态：所有腿锁定在地面高度 zf0，不是探针深度！
z_locked = true(1, 6);
locked_z_val = zf0 * ones(1, 6);  % 锁在地面！

% 力阈值（根据实测数据标定）
% 真正悬空的力阈值（保留用于“驻足失足”平移判断）
F_AIR_THRESH    = 10;    % 低于此值判定为真正悬空 (N)

% 连续帧防抖与延后探测计数器
air_count = zeros(1, 6);           % 连续悬空帧计数
AIR_CONFIRM_FRAMES = 10;           % 需要连续10帧(50ms)确认悬空
probe_wait = zeros(1, 6);          % 探底后的延后检测计数器

vrobot.go();

kk = 1;
sim_frame = 1;
WARMUP_FRAMES = 30; % 物理引擎预热帧数
NOMINAL_BODY_Z = 2.7; % CoppeliaSim中机身初始世界高度
world_ground_z = NOMINAL_BODY_Z + zf0; % 地面在CoppeliaSim世界坐标中的Z (≈0.65)

realX_log = []; realY_log = []; realZ_log = [];
real_body = [xb(1); yb(1); NOMINAL_BODY_Z]; % 初始真实机身位置

while kk <= Data_Num
    
    [F, ~] = vrobot.get_force_sensor();
    
    % [核心] 每帧读取CoppeliaSim中机身的真实世界位置（用于日志和真实X计算，不补偷Z）
    [~, real_body] = vrobot.Main.simxGetObjectPosition(vrobot.ClientID, vrobot.Body_Handle, -1, vrobot.Main.simx_opmode_oneshot);
    
    for leg = 1:6
        cur_x = x0(leg, kk) + offset_x(leg);
        cur_y = y0(leg, kk);
        cur_z = z0(leg, kk);
        
        % 计算合力和物理坐标
        if sim_frame > WARMUP_FRAMES
            force_mag = norm(F(leg, :));
            [~, foot_pos] = vrobot.Main.simxGetObjectPosition(vrobot.ClientID, vrobot.Force_sensor_Handle(leg), -1, vrobot.Main.simx_opmode_oneshot);
            real_foot_z = foot_pos(3);
        else
            force_mag = 9999; % 预热期间假装踩实
            real_foot_z = 1.05;
        end

        if is_recovering(leg)
            % === 反射恢复态 ===
            t_ratio = recover_frame(leg) / 160;
            peak_z = zf0 + 0.25;
            land_z = zf0;
            
            % [修复] 用相对距离而非绝对世界坐标
            % 前腿：往回缩0.4m（退到安全地带）
            % 中后腿：往前伸0.6m（跨过深坑）
            if leg == 1 || leg == 4
                safe_x = reflex_start_x(leg) - 0.4;
            else
                safe_x = reflex_start_x(leg) + 0.6;
            end
            
            if t_ratio <= 0.3
                pt = t_ratio / 0.3;
                cur_x = reflex_start_x(leg);
                cur_z = reflex_start_z(leg) + (peak_z - reflex_start_z(leg)) * (1 - cos(pi*pt))/2;
            elseif t_ratio <= 0.7
                pt = (t_ratio - 0.3) / 0.4;
                cur_x = reflex_start_x(leg) + (safe_x - reflex_start_x(leg)) * (1 - cos(pi*pt))/2;
                cur_z = peak_z;
            else
                pt = (t_ratio - 0.7) / 0.3;
                cur_x = safe_x;
                cur_z = peak_z + (land_z - peak_z) * (1 - cos(pi*pt))/2;
            end
            
            recover_frame(leg) = recover_frame(leg) + 1;
            
            if recover_frame(leg) >= 160
                offset_x(leg) = offset_x(leg) + (safe_x - reflex_start_x(leg));
                is_recovering(leg) = false;
                z_locked(leg) = true;
                locked_z_val(leg) = zf0;
                fprintf('  --> [警报解除] 腿 %d 安全着陆 (X=%.2f)\n', leg, safe_x);
            end
            
        else
            % === 正常监控态 ===
            
            % 用原始意图 z0 判断是否处于摆动抬腿相
            if z0(leg, kk) >= zf0 + 0.05
                z_locked(leg) = false;
            end
            
            if z_locked(leg)
                cur_z = locked_z_val(leg);
                
                % [支撑相持续地面监听 + 连续帧防抖]
                if sim_frame > WARMUP_FRAMES
                    if force_mag < F_AIR_THRESH
                        air_count(leg) = air_count(leg) + 1;
                    else
                        air_count(leg) = 0; % 只要有一帧力恢复，计数器清零
                    end
                    
                    % 连续 N 帧力极低 → 确认地面真的消失了
                    if air_count(leg) >= AIR_CONFIRM_FRAMES && ~any(is_recovering)
                        real_foot_x = real_body(1) + (cur_x - xb(kk));
                        fprintf('  *** [警报-支撑失地] 腿 %d (kk=%d, 真实X=%.2f) 连续%d帧力<%.0fN，地面消失！\n', ...
                            leg, kk, real_foot_x, AIR_CONFIRM_FRAMES, F_AIR_THRESH);
                        air_count(leg) = 0;
                        z_locked(leg) = false;
                        is_recovering(leg) = true;
                        recover_frame(leg) = 0;
                        reflex_start_x(leg) = cur_x;
                        reflex_start_z(leg) = cur_z;
                    end
                end
            end
            
            % ==========================================================
            % 3. 着陆区深探检测（探到底部后强制延后检测窗口）
            % ==========================================================
            % 等到数学指令彻底扎到坑里 (-0.085m)，并额外等待 10 帧(50ms) 彻底散去下落惯性延迟，再看真实世界。
            if z0(leg, kk) < zf0 - 0.085 && ~z_locked(leg) && ~any(is_recovering)
                probe_wait(leg) = probe_wait(leg) + 1;
                if probe_wait(leg) > 10 % 延后10帧
                    real_foot_x = real_body(1) + (cur_x - xb(kk));
                    
                    if real_foot_z >= 0.95
                        % 物理脚被实地（或腿的极限长度）挡在 0.95m 以上
                        z_locked(leg) = true;
                        locked_z_val(leg) = zf0; 
                        probe_wait(leg) = 0;
                        if sim_frame < 3000
                            fprintf('  [踩实归位] 腿%d kk=%d (延后10帧确认, 真实X=%.2f, 物理Z=%.3f)\n', ...
                                leg, kk, real_foot_x, real_foot_z);
                        end
                    else
                        % 物理脚终于突破了 0.95m
                        fprintf('  *** [警报-探入深坑] 腿 %d (kk=%d, 真实X=%.2f, 物理Z=%.3fm) 跌落悬崖！\n', ...
                            leg, kk, real_foot_x, real_foot_z);
                        is_recovering(leg) = true;
                        recover_frame(leg) = 0;
                        reflex_start_x(leg) = cur_x;
                        reflex_start_z(leg) = cur_z;
                        probe_wait(leg) = 0;
                    end
                end
            else
                probe_wait(leg) = 0; % 非探底状态，重置计数器
            end
        end
        
        Target.R = eye(3);
        Target.p = [cur_x; cur_y; cur_z];
        robot_ik(1).p = [xb(kk); yb(kk); zb(kk)];
        c_id = [1 + 3*leg, 1];
        
        robot_ik = ik_collision(robot_ik, Target, c_id);
        for j = 1:3; Joint_Learned(sim_frame, j + 3*leg - 3) = robot_ik(j + 3*leg - 2).q; end
    end
    
    vrobot.Joint = Joint_Learned(sim_frame, :);
    vrobot.set_joint();
    vrobot.trigger();
    
    % ================= 记录绘图数据 =================
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
    % ================================================

    if ~any(is_recovering)
        kk = kk + 1;
    end
    sim_frame = sim_frame + 1;
    
    if mod(sim_frame, 500) == 0
        fprintf('  当前进度: 第 %d 仿真物理帧 (kk=%d)...\n', sim_frame, kk);
    end
end

vrobot.pause();
vrobot.stop();
Joint_Learned(sim_frame:end, :) = [];

fprintf('\n闭环示教完成！(总实际物理帧数：%d)\n', size(Joint_Learned, 1));
default_learned_path = fullfile(fileparts(mfilename('fullpath')), 'export_data', 'walk_ditch_half_generated.mat');
save(default_learned_path, 'Joint_Learned');
artifact_learned_path = default_learned_path;
if isstruct(export_meta) && isfield(export_meta, 'artifact_output_dir') && ~isempty(export_meta.artifact_output_dir)
    if ~exist(export_meta.artifact_output_dir, 'dir')
        mkdir(export_meta.artifact_output_dir);
    end
    artifact_learned_path = fullfile(export_meta.artifact_output_dir, 'ditch_half_mid_generated_joint.mat');
    save(artifact_learned_path, 'Joint_Learned');
end
learned_path = artifact_learned_path;
fprintf('已保存: %s\n', learned_path);

%% ================= 绘图 =================
F_all = FL1+FL2+FL3+FR1+FR2+FR3;

h_fig1 = figure('Name', '各腿末端受力', 'NumberTitle', 'off');
subplot(2,3,1); plot(FL1(:,3)); title('左腿1末端受力'); ylabel('N'); xlabel('时间步');
subplot(2,3,2); plot(FL2(:,3)); title('左腿2末端受力'); ylabel('N'); xlabel('时间步');
subplot(2,3,3); plot(FL3(:,3)); title('左腿3末端受力'); ylabel('N'); xlabel('时间步');
subplot(2,3,4); plot(FR1(:,3)); title('右腿1末端受力'); ylabel('N'); xlabel('时间步');
subplot(2,3,5); plot(FR2(:,3)); title('右腿2末端受力'); ylabel('N'); xlabel('时间步');
subplot(2,3,6); plot(FR3(:,3)); title('右腿3末端受力'); ylabel('N'); xlabel('时间步');

h_fig2 = figure('Name', '末端总受力', 'NumberTitle', 'off');
plot(F_all(:,3)); title('末端总力'); ylabel('N'); xlabel('时间步'); grid on;

h_fig3 = figure('Name', '轨迹追踪对比', 'NumberTitle', 'off');
if ~isempty(realX_log)
    subplot(3,1,1); plot(realX_log, 'b-', 'LineWidth', 1.5);
    title('实际机器人中心 X 坐标位移 (Learn)'); xlabel('仿真帧数'); ylabel('世界 X (m)');
    subplot(3,1,2); plot(realY_log, 'g-', 'LineWidth', 1.5);
    title('实际机器人中心 Y 偏航随时间变化'); xlabel('仿真帧数'); ylabel('世界 Y (m)');
    subplot(3,1,3); plot(realX_log, realZ_log, 'r-', 'LineWidth', 1.5);
    title('Z 高度随 X 变化'); xlabel('世界 X (m)'); ylabel('世界 Z (m)');
end

h_fig4 = figure('Name', '机体速度曲线', 'NumberTitle', 'off');
if length(realX_log) >= 2
    step_dist = sqrt(diff(realX_log).^2 + diff(realY_log).^2 + diff(realZ_log).^2);
    speed = step_dist ./ (Control_T/1000);
    plot(speed, 'm-', 'LineWidth', 1.2);
    title('机体瞬时速度'); xlabel('仿真帧数'); ylabel('速度 (m/s)'); grid on;
end

saveas(h_fig1, fullfile(run_output_dir, '01_leg_force.png'));
saveas(h_fig2, fullfile(run_output_dir, '02_total_force.png'));
saveas(h_fig3, fullfile(run_output_dir, '03_trajectory_tracking.png'));
saveas(h_fig4, fullfile(run_output_dir, '04_body_speed.png'));
savefig(h_fig1, fullfile(run_output_dir, '01_leg_force.fig'));
savefig(h_fig2, fullfile(run_output_dir, '02_total_force.fig'));
savefig(h_fig3, fullfile(run_output_dir, '03_trajectory_tracking.fig'));
savefig(h_fig4, fullfile(run_output_dir, '04_body_speed.fig'));

fprintf('图表已存入 %s\n', run_output_dir);
end

