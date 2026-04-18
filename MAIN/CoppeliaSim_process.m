function CoppeliaSim_process(pattern,Joint,export_meta)
rad2deg=180/pi;
if nargin < 3 || isempty(export_meta)
    export_meta = struct();
end
global turn_flag;
num=length(pattern);
Control_T = 5;%4
run_start_str = datestr(now,'yyyy-mm-dd HH:MM:SS');
run_start_now = now;
run_timer = tic;
project_root = fileparts(fileparts(mfilename('fullpath')));
% Total_Time = (Data_Num) * Control_T;
legacy_port = 19997;
if isstruct(export_meta) && isfield(export_meta, 'coppeliasim_port') && ~isempty(export_meta.coppeliasim_port) && ~isnan(export_meta.coppeliasim_port)
    legacy_port = export_meta.coppeliasim_port;
end
vrobot = MatlabVrep(Control_T, legacy_port);
if legacy_port > 19999
    vrobot.Close_All_Connections_Before_Init = true;
end
vrobot = vrobot.init();
eulerAngles=[0;90;-180]/rad2deg;
vrobot.set_body_o(eulerAngles);
position=[0;0.025;0.93];
vrobot.set_body_p(position);
joint_initial=Joint{1}(1,:);
vrobot.set_joint_initial(joint_initial)
switch pattern{1}
    case 'passive_front_fall'
        eulerAngles=[-15;90;-180]/rad2deg;
        vrobot.set_body_o(eulerAngles);
    case 'passive_back_fall'
        eulerAngles=[0;90;-165]/rad2deg;
        vrobot.set_body_o(eulerAngles);
    case 'passive_right_front_fall'
        eulerAngles=[180;75;0]/rad2deg;
        vrobot.set_body_o(eulerAngles);
    case 'passive_right_back_fall'
        eulerAngles=[180;75;0]/rad2deg;
        vrobot.set_body_o(eulerAngles);
    case 'passive_left_front_fall'
        eulerAngles=[0;75;-180]/rad2deg;
        vrobot.set_body_o(eulerAngles);
    case 'passive_left_back_fall'
        eulerAngles=[0;75;-180]/rad2deg;
        vrobot.set_body_o(eulerAngles);
    case 'roll2roll'
        position = [0;0;0.3];
        vrobot.set_body_p(position);
        if turn_flag
            eulerAngles=[0;0;180]/rad2deg;

        else
            eulerAngles=[-180;0;0]/rad2deg;
        end
        vrobot.set_body_o(eulerAngles);
        %     case 'back_roll'
        %         eulerAngles=[0;90;-165]/rad2deg;
        %         vrobot.set_body_o(eulerAngles);
    case 'fast_rise'
        eulerAngles=[95;90;-180]/rad2deg;
        vrobot.set_body_o(eulerAngles);
        position = [0;0;0.2];
        vrobot.set_body_p(position);
    case 'rise2sit'
        eulerAngles=[90;90;-180]/rad2deg;
        vrobot.set_body_o(eulerAngles);
        position = [0;0;0.2];
        vrobot.set_body_p(position);
    case 'crawl'
        eulerAngles=[-45;90;-180]/rad2deg;
        vrobot.set_body_o(eulerAngles);
        position = [0;0;0.5];
        vrobot.set_body_p(position);
    case 'low_crawl'
        eulerAngles=[-90;90;-180]/rad2deg;
        vrobot.set_body_o(eulerAngles);
        position = [0;0;0.3];
        vrobot.set_body_p(position);
    case 'turn_over'
        eulerAngles=[-90;90;-180]/rad2deg;
        vrobot.set_body_o(eulerAngles);
        position = [0;0;0.5];
        vrobot.set_body_p(position);
    case 'change'
        position = [0;0;0.3];
        vrobot.set_body_p(position);
        eulerAngles=[-180;0;0]/rad2deg;
        vrobot.set_body_o(eulerAngles);
%     case 'any_position'
%         position = [0;0;0.15];
%         vrobot.set_body_p(position);
%         eulerAngles=[-90;90;0]/rad2deg;
%         vrobot.set_body_o(eulerAngles);
    case 'any_position'
        position = [0;0;0.6];
        vrobot.set_body_p(position);
        eulerAngles=[0;-130;-90]/rad2deg;
        vrobot.set_body_o(eulerAngles);   

    case 'walk'
        position = [-2.9;10;1.0];
        vrobot.set_body_p(position);
        eulerAngles=[0;18;0]/rad2deg;
        vrobot.set_body_o(eulerAngles);
        position = [0;0;3];
        vrobot.set_body_p(position);
        eulerAngles=[0;0;0]/rad2deg;
        vrobot.set_body_o(eulerAngles);
    case 'climb2wall'
        position = [3.8;0;2.7];
        vrobot.set_body_p(position);
        eulerAngles=[0;0;0]/rad2deg;
        vrobot.set_body_o(eulerAngles);
    case 'step_platform5m'
        position = [3.8;0;2.7];
        vrobot.set_body_p(position);
        eulerAngles=[0;0;0]/rad2deg;
        vrobot.set_body_o(eulerAngles);
%                 position = [-2.9;10;3.6];
%         vrobot.set_body_p(position);
%         eulerAngles=[0;30;0]/rad2deg;
%         vrobot.set_body_o(eulerAngles);
    case 'climbing'

        position = [-3;0;2.7];
        vrobot.set_body_p(position);
        eulerAngles=[0;0;0]/rad2deg;
        vrobot.set_body_o(eulerAngles);
    case 'Legstretch'%%伸出腿
        position = [0;0;1.2];
        vrobot.set_body_p(position);
        eulerAngles=[0;0;0]/rad2deg;
        vrobot.set_body_o(eulerAngles);

    case 'slope'  %% 15度斜坡地形
        % 机器人起点：贴近地面，设置 X 为 3.8（距离坡底 5.975 - 3.8 = 2.175m）
        position = [3.8; 0; 2.7];
        vrobot.set_body_p(position);
        eulerAngles = [0; 0; 0] / rad2deg;
        vrobot.set_body_o(eulerAngles);
    case 'slope_3m_4m_3m'
        position = [3.8; 0; 2.7];
        vrobot.set_body_p(position);
        eulerAngles = [0; 0; 0] / rad2deg;
        vrobot.set_body_o(eulerAngles);

    case 'ditch'  %% 深沟地形
        % 机器人起始位置：贴近地面
        position = [-0.75; 0; 2.7];
        vrobot.set_body_p(position);
        eulerAngles = [0; 0; 0] / rad2deg;
        vrobot.set_body_o(eulerAngles);

end
%% ========== 第二部分: 执行轨迹仿真 ==========
% 【仿真执行流程】
%   1. 遍历所有动作模式(pattern)
%   2. 对每个动作，遍历所有轨迹点
%   3. 将每个轨迹点发送到CoppeliaSim执行
%   4. 采集力传感器数据
%   5. 所有轨迹执行完毕后，停止仿真并绘制结果

nnn=1;  % 轨迹点计数器
Py_log=[];  % 预留变量（未使用）
Pz_log=[];  % 预留变量（未使用）
Lx_log=[];  % 预留变量（未使用）
Data_Num_List = zeros(1, num);  % 各动作帧数记录
expected_frames = sum(cellfun(@(joint_seq) size(joint_seq, 1), Joint));
realX_log = NaN(expected_frames, 1);
realY_log = NaN(expected_frames, 1);
realZ_log = NaN(expected_frames, 1);
bodyRoll_log = NaN(expected_frames, 1);
bodyPitch_log = NaN(expected_frames, 1);
bodyYaw_log = NaN(expected_frames, 1);
foot_pos_xyz_log = NaN(expected_frames, 18);
leg_force_xyz_log = NaN(expected_frames, 18);

% 【外层循环】遍历所有动作模式
% 例如：如果pattern={'walk','climb2wall'}，则num=2，会依次执行两个动作
for jj=1:num
    [Data_Num,~] = size(Joint{jj});  % 获取第jj个动作的轨迹点数
    Data_Num_List(jj) = Data_Num;
    
    % 【重要】启动仿真（每个动作开始时调用一次）
    % 注意：如果num>1，每个新动作都会重新启动仿真
    vrobot.go();
    
    % 显示进度信息
    fprintf('开始执行动作 %d/%d: %s (共 %d 个轨迹点)\n', jj, num, pattern{jj}, Data_Num);
    
    % 【内层循环】遍历当前动作的所有轨迹点
    % Data_Num = 轨迹总点数，例如walk动作可能有400个点（2秒/0.005秒）
    for kk=1:1:Data_Num
        % 设置当前轨迹点的关节角度（18个关节）
        vrobot.Joint = Joint{jj}(kk,:);
        
        % 将关节角度发送到CoppeliaSim
        vrobot.set_joint();
        

        % 【关键】触发仿真步进
        % 每次调用trigger()，CoppeliaSim会执行一个仿真步（5ms）
        % 这是同步仿真的核心：MATLAB控制仿真速度
        vrobot.trigger();
        
        % 【进度显示】每100个点显示一次进度（可选，避免输出过多）
        if mod(kk, 100) == 0 || kk == Data_Num
            fprintf('  进度: %d/%d (%.1f%%)\n', kk, Data_Num, kk/Data_Num*100);
        end
        %         f(nnn,:)=vrobot.get_Joint_force;
        
%         if nnn==1
%             q_rel_last=zeros(1,23);
%         else
%             q_rel_last=q_rel;
%         end
%         q_rel = vrobot.get_Joint_position;
%         [body_v,ang_v] = vrobot.get_body_v;
%         body_eul=vrobot.get_body_eul;
%         if nnn>2
%             
%             vy=body_v(2);
%             vz=body_v(3);
%             ct=body_eul(3)-pi;
%             w=ang_v(1);
%             q_2D=q_rel([3,4,5,14,18,19]);
%             dq_2D=(q_rel([3,4,5,14,18,19])-q_rel_last([3,4,5,14,18,19]))/Control_T;
%             [Py,Pz,Lx]=cal_robot2D_ML(vy,vz,ct,w,q_2D,dq_2D);
%             Py_log=[Py_log,Py];
%             Pz_log=[Pz_log,Pz];
%             Lx_log=[Lx_log,Lx];
%         end
        %         if jj==num
        %
        [F,tao]=vrobot.get_force_sensor;
        frame_idx = nnn;
        for leg_idx = 1:6
            [~, foot_pos] = vrobot.Main.simxGetObjectPosition( ...
                vrobot.ClientID, vrobot.Force_sensor_Handle(leg_idx), -1, ...
                vrobot.Main.simx_opmode_oneshot);
            if exist('foot_pos', 'var') && numel(foot_pos) == 3
                foot_pos_xyz_log(frame_idx, (leg_idx - 1) * 3 + (1:3)) = foot_pos(:).';
            else
                foot_pos_xyz_log(frame_idx, (leg_idx - 1) * 3 + (1:3)) = NaN(1, 3);
            end
            if size(F, 1) >= leg_idx && size(F, 2) >= 3
                leg_force_xyz_log(frame_idx, (leg_idx - 1) * 3 + (1:3)) = F(leg_idx, 1:3);
            else
                leg_force_xyz_log(frame_idx, (leg_idx - 1) * 3 + (1:3)) = NaN(1, 3);
            end
        end
        %                     if kk>1200
        %
        %                 FR(kk-1200,:)=F(1,:)*filter_coef+FR_last*(1-filter_coef);
        % %                 FL(kk-1200,:)=F(2,:)*filter_coef+FL_last*(1-filter_coef);
        %                 taoR(kk-1200,:)=tao(1,:)*filter_coef+taoR_last*(1-filter_coef);
        % %                 taoL(kk-1200,:)=tao(2,:)*filter_coef+taoL_last*(1-filter_coef);
        %
        %                ZMP_R(kk-1200,:)=cal_ZMP(FR(kk-1200,:),taoR(kk-1200,:));
        %             else
        if kk>25
            FR1(kk-25,:)=F(1,:);
            FR2(kk-25,:)=F(2,:);
            FR3(kk-25,:)=F(3,:);
            FL1(kk-25,:)=F(4,:);
            FL2(kk-25,:)=F(5,:);
            FL3(kk-25,:)=F(6,:);
            FR1(kk-25,3)=norm(F(1,:));
            FR2(kk-25,3)=norm(F(2,:));
            FR3(kk-25,3)=norm(F(3,:));
            FL1(kk-25,3)=norm(F(4,:));
            FL2(kk-25,3)=norm(F(5,:));
            FL3(kk-25,3)=norm(F(6,:));
            taoR1(kk-25)=sqrt(tao(1,1)*tao(1,1)+tao(1,2)*tao(1,2)+tao(1,3)*tao(1,3));
            taoR2(kk-25)=sqrt(tao(2,1)*tao(2,1)+tao(2,2)*tao(2,2)+tao(2,3)*tao(2,3));
            taoR3(kk-25)=sqrt(tao(3,1)*tao(3,1)+tao(3,2)*tao(3,2)+tao(3,3)*tao(3,3));
            taoL1(kk-25)=sqrt(tao(4,1)*tao(4,1)+tao(4,2)*tao(4,2)+tao(4,3)*tao(4,3));
            taoL2(kk-25)=sqrt(tao(5,1)*tao(5,1)+tao(5,2)*tao(5,2)+tao(5,3)*tao(5,3));
            taoL3(kk-25)=sqrt(tao(6,1)*tao(6,1)+tao(6,2)*tao(6,2)+tao(6,3)*tao(6,3));
        end
        %                 ZMP_R=[0 0];
        %
        %                 FR_last=FR;
        % %                 FL_last=FL;
        %                 taoR_last=taoR;
        % %                 taoL_last=taoL;
        %                 filter_coef=0.5;
        %             end
        %         end
        
        % === [新增追踪日志] 记录每一步机器人真实坐标 ===
        [~, body_p] = vrobot.Main.simxGetObjectPosition(vrobot.ClientID, vrobot.Body_Handle, -1, vrobot.Main.simx_opmode_oneshot);
        if exist('body_p', 'var') && length(body_p) == 3
            realX_log(frame_idx) = body_p(1);
            realY_log(frame_idx) = body_p(2);
            realZ_log(frame_idx) = body_p(3);
        else
            realX_log(frame_idx) = NaN;
            realY_log(frame_idx) = NaN;
            realZ_log(frame_idx) = NaN;
        end
        body_eul = vrobot.get_body_eul();
        if exist('body_eul', 'var') && numel(body_eul) == 3
            bodyRoll_log(frame_idx) = body_eul(1) * rad2deg;
            bodyPitch_log(frame_idx) = body_eul(2) * rad2deg;
            bodyYaw_log(frame_idx) = body_eul(3) * rad2deg;
        else
            bodyRoll_log(frame_idx) = NaN;
            bodyPitch_log(frame_idx) = NaN;
            bodyYaw_log(frame_idx) = NaN;
        end
        nnn=nnn+1;
        % ==============================================
        
    end  % 内层循环结束（当前动作的所有轨迹点执行完毕）
    
    fprintf('动作 %d/%d 执行完成！\n', jj, num);
end  % 外层循环结束（所有动作执行完毕）

%% ========== 第三部分: 仿真停止和结果处理 ==========
% 【仿真停止时机】
%   仿真会在以下条件满足时自动停止：
%   1. 所有动作模式(pattern)都执行完毕（外层循环结束）
%   2. 每个动作的所有轨迹点都发送完毕（内层循环结束）
%   3. 然后执行下面的停止命令

% 【停止仿真】
fprintf('\n所有轨迹执行完毕，正在停止仿真...\n');
vrobot.pause();  % 暂停仿真（CoppeliaSim中的仿真会暂停）
vrobot.stop();   % 停止仿真并断开连接
fprintf('仿真已停止！\n\n');
run_end_str = datestr(now,'yyyy-mm-dd HH:MM:SS');
wall_time_sec = toc(run_timer);

% 【判断仿真是否停止的标志】
% 当你看到以下情况时，说明仿真已经停止：
% 1. MATLAB命令窗口显示"仿真已停止！"
% 2. CoppeliaSim中的机器人停止运动
% 3. MATLAB自动弹出力传感器数据图表（下面的subplot）
% 4. MATLAB命令提示符(>>)重新出现，可以输入新命令

control_step_sec = Control_T / 1000;
scene_name_for_export = pattern{1};
if isfield(export_meta, 'scene_name') && ~isempty(export_meta.scene_name)
    scene_name_for_export = export_meta.scene_name;
end
scene_info = hexapod_scene_info(scene_name_for_export);

if exist('FR1', 'var') && ~isempty(FR1)
    leg_force_mag = [FR1(:,3), FR2(:,3), FR3(:,3), FL1(:,3), FL2(:,3), FL3(:,3)];
else
    leg_force_mag = zeros(0, 6);
end

telemetry = struct();
logged_frame_count = max(nnn - 1, 0);
telemetry.realX = realX_log(1:logged_frame_count);
telemetry.realY = realY_log(1:logged_frame_count);
telemetry.realZ = realZ_log(1:logged_frame_count);
telemetry.bodyEulerDeg = [bodyRoll_log(1:logged_frame_count), bodyPitch_log(1:logged_frame_count), bodyYaw_log(1:logged_frame_count)];
telemetry.legForceMag = leg_force_mag;
telemetry.footPosXYZ = foot_pos_xyz_log(1:logged_frame_count, :);
telemetry.legForceXYZ = leg_force_xyz_log(1:logged_frame_count, :);
telemetry.control_dt_sec = control_step_sec;
telemetry.extra = struct();

meta = struct();
meta.scene_name = scene_info.scene_name;
meta.scene_label = scene_info.scene_label;
meta.scene_variant = 'current_main';
meta.source_flow = 'CoppeliaSim_process';
meta.entry_pattern = pattern{1};
meta.run_now = run_start_now;
meta.run_timestamp = run_start_str;
meta.control_dt_ms = Control_T;
meta.run_end_str = run_end_str;
meta.wall_time_sec = wall_time_sec;

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
[metrics, run_output_dir] = hexapod_export_metrics(project_root, telemetry, meta);

fprintf('统一指标文件已保存：\n');
fprintf('  输出目录: %s\n', run_output_dir);
fprintf('  指标文件: %s\n', fullfile(run_output_dir, 'metrics.mat'));
fprintf('  摘要文件: %s\n', fullfile(run_output_dir, 'metrics_summary.md'));
fprintf('  场景类别: %s (%s)\n', metrics.meta.scene_name, metrics.meta.scene_label);
fprintf('图表绘制完成！\n');
fprintf('========================================\n');
fprintf('【仿真完成】\n');
fprintf('你现在可以：\n');
fprintf('  1. 查看统一导出的指标文件与图表\n');
fprintf('  2. 分析 log/%s 下的场景结果\n', metrics.meta.scene_name);
fprintf('  3. 运行新的仿真并横向比较指标\n');
fprintf('========================================\n');
end




