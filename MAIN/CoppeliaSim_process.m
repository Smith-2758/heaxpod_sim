function CoppeliaSim_process(pattern,Joint)
rad2deg=180/pi;
global turn_flag;
num=length(pattern);
Control_T = 5;%4
run_start_str = datestr(now,'yyyy-mm-dd HH:MM:SS');
run_timer = tic;

% 结果保存路径：项目根目录/log/日期(YYMMDD)/时间(HH.MM)
project_root = fileparts(fileparts(mfilename('fullpath')));
log_root = fullfile(project_root, 'log');
date_folder = datestr(now, 'yymmdd');
time_folder = datestr(now, 'HH.MM');
run_output_dir = fullfile(log_root, date_folder, time_folder);
suffix_id = 1;
while exist(run_output_dir, 'dir')
    run_output_dir = fullfile(log_root, date_folder, sprintf('%s_%02d', time_folder, suffix_id));
    suffix_id = suffix_id + 1;
end
mkdir(run_output_dir);
fprintf('本次仿真结果保存目录: %s\n', run_output_dir);

% Total_Time = (Data_Num) * Control_T;
vrobot = MatlabVrep(Control_T);
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
        frame_idx = nnn;
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

% 计算所有腿的总受力（用于后续分析）
F_all = FL1+FL2+FL3+FR1+FR2+FR3;

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

qqq=0;  % 占位变量（未使用）

% 基础统计信息（用于图表标题/markdown摘要）
total_frames = sum(Data_Num_List);
control_step_sec = Control_T / 1000;
sim_time_sec = total_frames * control_step_sec;
scene_name = get_scene_name_from_main_v2(project_root);

has_track_log = exist('realX_log', 'var') && ~isempty(realX_log);
avg_speed_mps = NaN;
peak_speed_mps = NaN;
track_distance_m = NaN;
net_displacement_m = NaN;
speed_log = [];

if has_track_log
    valid_idx = ~(isnan(realX_log) | isnan(realY_log) | isnan(realZ_log));
    x_valid = realX_log(valid_idx);
    y_valid = realY_log(valid_idx);
    z_valid = realZ_log(valid_idx);
    if length(x_valid) >= 2
        step_distance = sqrt(diff(x_valid).^2 + diff(y_valid).^2 + diff(z_valid).^2);
        speed_log = step_distance ./ control_step_sec;
        track_distance_m = sum(step_distance);
        net_displacement_m = sqrt((x_valid(end)-x_valid(1))^2 + (y_valid(end)-y_valid(1))^2 + (z_valid(end)-z_valid(1))^2);
        avg_speed_mps = track_distance_m / max(sim_time_sec, eps);
        peak_speed_mps = max(speed_log);
    end
end

%% ========== 第四部分: 绘制仿真结果图表 ==========
% 【注意】这些图表会在仿真停止后自动弹出
% 如果图表没有显示，说明仿真可能还在运行或出现了错误

fprintf('正在绘制力传感器数据图表...\n');

% 创建第一个图表窗口：各腿末端受力（6个子图）
h_fig1 = figure('Name', '各腿末端受力', 'NumberTitle', 'off');
subplot(2,3,1);
plot(FL1(:,3))
title(['左腿1末端受力']);
ylabel('N');
xlabel('时间步');

subplot(2,3,2);
plot(FL2(:,3))
title(['左腿2末端受力']);
ylabel('N');
xlabel('时间步');

subplot(2,3,3);
plot(FL3(:,3))
title(['左腿3末端受力']);
ylabel('N');
xlabel('时间步');

subplot(2,3,4);
plot(FR1(:,3))
title(['右腿1末端受力']);
ylabel('N');
xlabel('时间步');

subplot(2,3,5);
plot(FR2(:,3))
title(['右腿2末端受力']);
ylabel('N');
xlabel('时间步');

subplot(2,3,6);
plot(FR3(:,3))
title(['右腿3末端受力']);
ylabel('N');
xlabel('时间步');

% 创建第二个图表窗口：所有腿的总受力
h_fig2 = figure('Name', '末端总受力', 'NumberTitle', 'off');
plot(F_all(:,3))
title(['末端总力']);
ylabel('N');
xlabel('时间步');
grid on;

% === [新增追踪绘图] 比较离线生成的基座轨迹与 CoppeliaSim 物理引擎中机器人的实际轨迹 ===
% === [新增追踪绘图] 比较离线生成的基座轨迹与 CoppeliaSim 物理引擎中机器人的实际轨迹 ===
h_fig3 = figure('Name', ['轨迹追踪对比 - ' pattern{1}], 'NumberTitle', 'off');
if has_track_log
    
    subplot(3,1,1);
    plot(realX_log, 'b-', 'LineWidth', 1.5);
    title(['实际机器人中心 X 坐标位移 (' pattern{1} ')']); 
    xlabel('仿真帧数'); ylabel('世界 X (m)');
    
    subplot(3,1,2);
    plot(realY_log, 'g-', 'LineWidth', 1.5);
    title('实际机器人中心 Y 偏航随时间变化'); 
    xlabel('仿真帧数'); ylabel('世界 Y (m)');

    subplot(3,1,3);
    plot(realX_log, realZ_log, 'r-', 'LineWidth', 1.5);
    title('实际机器人中心 Z 高度随X变化'); 
    xlabel('世界 X (m)'); ylabel('世界 Z (m)');
else
    axis off;
    text(0.2, 0.5, '轨迹日志不可用，未采集到有效坐标数据', 'FontSize', 12);
end
% =========================================================================================

% 第四个图表窗口：机体速度曲线
h_fig4 = figure('Name', '机体速度曲线', 'NumberTitle', 'off');
if ~isempty(speed_log)
    plot(speed_log, 'm-', 'LineWidth', 1.2);
    title('机体瞬时速度曲线');
    xlabel('仿真帧数');
    ylabel('速度 (m/s)');
    grid on;
else
    axis off;
    text(0.2, 0.5, '速度日志不可用，无法计算速度曲线', 'FontSize', 12);
end

% 保存4张图像到输出目录
img1_path = fullfile(run_output_dir, '01_leg_force.png');
img2_path = fullfile(run_output_dir, '02_total_force.png');
img3_path = fullfile(run_output_dir, '03_trajectory_tracking.png');
img4_path = fullfile(run_output_dir, '04_body_speed.png');
fig1_path = fullfile(run_output_dir, '01_leg_force.fig');
fig2_path = fullfile(run_output_dir, '02_total_force.fig');
fig3_path = fullfile(run_output_dir, '03_trajectory_tracking.fig');
fig4_path = fullfile(run_output_dir, '04_body_speed.fig');
saveas(h_fig1, img1_path);
saveas(h_fig2, img2_path);
saveas(h_fig3, img3_path);
saveas(h_fig4, img4_path);
savefig(h_fig1, fig1_path);
savefig(h_fig2, fig2_path);
savefig(h_fig3, fig3_path);
savefig(h_fig4, fig4_path);

% 写入运行摘要Markdown
md_path = fullfile(run_output_dir, 'simulation_summary.md');
write_simulation_markdown( ...
    md_path, run_start_str, run_end_str, wall_time_sec, ...
    scene_name, pattern, Data_Num_List, total_frames, ...
    Control_T, sim_time_sec, ...
    track_distance_m, net_displacement_m, avg_speed_mps, peak_speed_mps, ...
    img1_path, img2_path, img3_path, img4_path, ...
    fig1_path, fig2_path, fig3_path, fig4_path);
fprintf('结果文件已保存：\n');
fprintf('  图像: %s\n', run_output_dir);
fprintf('  摘要: %s\n', md_path);

fprintf('图表绘制完成！\n');
fprintf('========================================\n');
fprintf('【仿真完成】\n');
fprintf('你现在可以：\n');
fprintf('  1. 查看CoppeliaSim中的机器人最终状态\n');
fprintf('  2. 分析MATLAB中显示的力传感器数据图表\n');
fprintf('  3. 运行新的仿真（修改main_v2.m中的pattern后重新运行）\n');
fprintf('========================================\n');    
% subplot(2,3,4);
% plot(taoR1(:))
% title(['左腿1末端力矩']);
% ylabel('Nm');
% subplot(2,3,5);
% plot(taoL2(:))
% title(['右腿2末端力矩']);
% ylabel('Nm');
% subplot(2,3,6);
% plot(taoR3(:))
% title(['左腿3末端力矩']);
% ylabel('Nm');

end

function scene_name = get_scene_name_from_main_v2(project_root)
scene_name = '未知场景';
main_v2_path = fullfile(project_root, 'MAIN', 'main_v2.m');
if ~exist(main_v2_path, 'file')
    return;
end

file_txt = fileread(main_v2_path);
token = regexp(file_txt, '打开场景\s*([^\s；;，,]+\.ttt)', 'tokens', 'once');
if ~isempty(token)
    scene_name = token{1};
    return;
end

token = regexp(file_txt, '([A-Za-z0-9_\-]+\.ttt)', 'tokens', 'once');
if ~isempty(token)
    scene_name = token{1};
end
end

function write_simulation_markdown( ...
    md_path, run_start_str, run_end_str, wall_time_sec, ...
    scene_name, pattern, Data_Num_List, total_frames, ...
    Control_T, sim_time_sec, ...
    track_distance_m, net_displacement_m, avg_speed_mps, peak_speed_mps, ...
    img1_path, img2_path, img3_path, img4_path, ...
    fig1_path, fig2_path, fig3_path, fig4_path)

fid = fopen(md_path, 'w');
if fid == -1
    warning('无法写入摘要文件: %s', md_path);
    return;
end

fprintf(fid, '# CoppeliaSim 仿真记录\n\n');
fprintf(fid, '- 开始时间: %s\n', run_start_str);
fprintf(fid, '- 结束时间: %s\n', run_end_str);
fprintf(fid, '- 场景文件: `%s`\n', scene_name);
fprintf(fid, '- 模式序列: `%s`\n\n', strjoin(pattern, ', '));

fprintf(fid, '## 帧数与时间\n\n');
fprintf(fid, '- 总帧数: `%d`\n', total_frames);
fprintf(fid, '- 控制周期: `%d ms/帧`\n', Control_T);
fprintf(fid, '- 理论仿真时长: `%.3f s`\n', sim_time_sec);
fprintf(fid, '- 程序实际运行时长: `%.3f s`\n\n', wall_time_sec);

fprintf(fid, '## 速度与位移\n\n');
if isnan(avg_speed_mps)
    fprintf(fid, '- 轨迹数据不足，未能计算速度/位移。\n\n');
else
    fprintf(fid, '- 总路径长度: `%.4f m`\n', track_distance_m);
    fprintf(fid, '- 起终点直线位移: `%.4f m`\n', net_displacement_m);
    fprintf(fid, '- 平均速度: `%.4f m/s`\n', avg_speed_mps);
    fprintf(fid, '- 峰值速度: `%.4f m/s`\n\n', peak_speed_mps);
end

fprintf(fid, '## 各动作帧数\n\n');
fprintf(fid, '| 序号 | 动作 | 帧数 |\n');
fprintf(fid, '|---|---|---:|\n');
for i = 1:length(pattern)
    fprintf(fid, '| %d | %s | %d |\n', i, pattern{i}, Data_Num_List(i));
end
fprintf(fid, '\n');

fprintf(fid, '## 输出文件\n\n');
[~, img1_name, img1_ext] = fileparts(img1_path);
[~, img2_name, img2_ext] = fileparts(img2_path);
[~, img3_name, img3_ext] = fileparts(img3_path);
[~, img4_name, img4_ext] = fileparts(img4_path);
[~, fig1_name, fig1_ext] = fileparts(fig1_path);
[~, fig2_name, fig2_ext] = fileparts(fig2_path);
[~, fig3_name, fig3_ext] = fileparts(fig3_path);
[~, fig4_name, fig4_ext] = fileparts(fig4_path);
fprintf(fid, '- PNG:\n');
fprintf(fid, '- %s%s\n', img1_name, img1_ext);
fprintf(fid, '- %s%s\n', img2_name, img2_ext);
fprintf(fid, '- %s%s\n', img3_name, img3_ext);
fprintf(fid, '- %s%s\n', img4_name, img4_ext);
fprintf(fid, '- FIG:\n');
fprintf(fid, '- %s%s\n', fig1_name, fig1_ext);
fprintf(fid, '- %s%s\n', fig2_name, fig2_ext);
fprintf(fid, '- %s%s\n', fig3_name, fig3_ext);
fprintf(fid, '- %s%s\n', fig4_name, fig4_ext);

fclose(fid);
end
