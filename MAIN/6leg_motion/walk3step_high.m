%% =====================================================================
%  walk3step.m —— 三步步态/跨障轨迹生成脚本
%
%  功能：
%  - 生成六足机器人在平地行走 + 上高台 + 跨坑场景的足端期望轨迹
%  - 通过机器人模型与逆运动学碰撞求解，得到各关节角度序列 `joint`
%
%  使用方法：
%  1）在 MATLAB 中运行本脚本：
%     cd('轨迹仿真程序/MAIN/6leg_motion');
%     walk3step
%  2）运行结束后，工作区会得到变量 `joint`（N×18，弧度）
%  3）如需供主程序使用，可另存为：
%     % save('轨迹仿真程序/MAIN/6leg_motion/export_data/walk3step.mat','joint')
%
%  与其他程序的关系：
%  - main_v2.m：主控脚本，选择模式并调度轨迹生成/仿真
%  - PG.m：轨迹生成器，`case 'climb2wall'` 会加载 `walk3step.mat` 的 `joint`
%  - CoppeliaSim_process.m：将 `Joint`（可能由本脚本生成）在仿真器中播放
%  - robot3D_description.m：机器人模型与运动学参数，供逆解调用
%
%  注：本脚本用于离线生成复杂场景轨迹，生成的数据可复用，提升仿真效率
%% =====================================================================
clear all; close all;clc
addpath(genpath(fileparts(fileparts(mfilename('fullpath'))))); % 自动添加项目路径以识别 robot3D_description 等函数
%% 基础参数
% 设置行走距离与场景参数（可按实际需求调整）
walklength = 5;   % 计划行走总距离（当前脚本未直接使用，可作为场景参考）
wl = 3;           % 预留场景参数（未在后续计算中使用）


%body
% 机体质心初始位置（用于基座轨迹）
% 坐标系约定：X 向前，Y 向左，Z 向上；单位：米
body_x = 3.8;  % 机器人出发 X 坐标（已改为 3.8m）
body_y = 0;
body_z = 0;
%foot
% 足端初始位置（六足顺序：右1、右2、右3、左1、左2、左3）
% 腿索引映射：1=右1(R1), 2=右2(R2), 3=右3(R3), 4=左1(L1), 5=左2(L2), 6=左3(L3)
x01 = 1.75 + body_x;
x02 = 0 + body_x;
x03 = -1.75 + body_x;
yr0 = -2.23 + body_y;
yl0 = 2.23 + body_y;
zf0 = -2.05 + body_z;


%speed
% 行走速度（m/s）
v = 0.35;
%time
% 时间配置：总时长、单腿相位时间、摆动/支撑时间与步态周期
% 修改3 —— 延长总时长至 20 s（提供更长接近与抬升缓冲）
t_total = 20;
% 单腿相位时间（秒），按速度与步幅比例近似 单腿相位时间就是步态周期中一个“子阶段”的时长，用来标定某一组腿从支撑到摆动（或摆动到支撑）的微周期长度
tt = abs(0.9/6/v);% 经验近似：几何常数/腿数/速度 每个步态周期的行进距离固定为约0.9 m
% 提示：减小 tt 可加快步态节奏，增大 tt 则更平稳但更慢
foott = tt*2;
stept = foott+foott+foott;
% 一个完整步态周期由 3 段组成（每段含两个腿的摆动/支撑）
%step
% 步长与抬腿高度设置
step0 = v * stept;   % 完整步长（一个步态周期内机体位移）
step1 = step0 / 2;   % 半步长（摆动相位前移量）
steph = 0.3;
%% 轨迹
% 轨迹时间轴离散 —— 构造 6 相位的关键时刻序列
k = fix(t_total/stept);
% 完整步态周期的重复次数（向下取整）
%time
% 每个完整周期分 6 个相位，对应六足交替摆动
% t 的含义：记录各相位的关键时间点；下式为一个周期内 6 个相位的刻度
for i=0:k-1
    t(6*i+1) = stept * i;
    t(6*i+2) = stept * i + tt;
    t(6*i+3) = stept * i + foott;
    t(6*i+4) = stept * i + foott + tt;
    t(6*i+5) = stept * i + foott*2;
    t(6*i+6) = stept * i + foott*2 + tt;    
end
    t(6*k+1) = stept * k;   % 周期末尾补点，保证时间轴闭合

% body
% xbb =  body_x: v * tt : body_x + v * t(end);
% 基座（机体质心）轨迹初始化：X/Y/Z 的参考序列（后续累加足端平均位移）
xbb = zeros(1,length(t));
ybb = body_y * ones(1,length(t));
zbb = body_z * ones(1,length(t));
% 含义：xbb/ybb/zbb 为机体基座在各关键时刻的参考位置（逐步构造），长度为 length(t)

%y&z
% 足端 Y/Z 初值：Y 固定到各侧，Z 固定到初始高度
for ii=1:length(t)
    y(1,ii) = yr0;
    y(2,ii) = yr0;
    y(3,ii) = yr0;

    y(4,ii) = yl0;
    y(5,ii) = yl0;
    y(6,ii) = yl0;
end

z = zf0*ones(6,length(t));
% 依照 6 相位循环，在指定相位抬起对应的两条腿
for ii=1:length(t)
    % 抬腿规则：mod(ii,6)==2 → 抬 R1(1) 与 L3(6)；==4 → 抬 R3(3) 与 L1(4)；==0 → 抬 R2(2) 与 L2(5)
    if(mod(ii,6)==2)
        z(1,ii) = zf0 + steph;
        z(6,ii) = zf0 + steph;
    end
    if(mod(ii,6)==4)
        z(3,ii) = zf0 + steph;
        z(4,ii) = zf0 + steph;
    end
    if(mod(ii,6)==0)
        z(2,ii) = zf0 + steph;
        z(5,ii) = zf0 + steph;
    end
end
%x
% 足端 X 初值：按 6 条腿的初值展开到时间轴
x_0 = [x01;x02;x03;x01;x02;x03];
x = repmat(x_0, 1, length(t));
% 腿索引映射：1=R1，2=R2，3=R3，4=L1，5=L2，6=L3（R=右，L=左）
% 按 6 相位循环，在指定相位前移对应腿（摆动）
for ii=1:length(t)
    % 前移规则详解：
    % - 相位选择：通过 mod(ii,6) 将时间轴分为 6 段；每段两条对角腿摆动前移
    % - 步长关系：step0 = v*stept；step1 = step0/2（半步增量）
    % - 双重增量：
    %   x(leg, ii:end) += step1    → 当前刻度 ii 增加半步
    %   x(leg, ii+1:end) += step1  → 从下一刻度开始再增加半步
    %   结果：ii 列为 +step1，ii+1 及以后为 +2×step1 = step0；配合后续 makima 插值得到平滑前移
    % - 配对映射：mod(ii,6)==2 → R1(1)+L3(6)；==4 → R3(3)+L1(4)；==0 → R2(2)+L2(5)
    if(mod(ii,6)==2)
        % 该相位对 R1 与 L3 执行“半步→整步”的阶梯前移（见上说明）
        x(1,ii:end) = x(1,ii:end) + step1;
        x(1,ii+1:end) = x(1,ii+1:end) + step1;
        x(6,ii:end) = x(6,ii:end) + step1;
        x(6,ii+1:end) = x(6,ii+1:end) + step1;
    end
    if(mod(ii,6)==4)
        % 该相位对 R3 与 L1 执行“半步→整步”的阶梯前移
        x(3,ii:end) = x(3,ii:end) + step1;
        x(3,ii+1:end) = x(3,ii+1:end) + step1;
        x(4,ii:end) = x(4,ii:end) + step1;
        x(4,ii+1:end) = x(4,ii+1:end) + step1;
    end
    if(mod(ii,6)==0)
        % 该相位对 R2 与 L2 执行“半步→整步”的阶梯前移
        x(2,ii:end) = x(2,ii:end) + step1;
        x(2,ii+1:end) = x(2,ii+1:end) + step1;
        x(5,ii:end) = x(5,ii:end) + step1;
        x(5,ii+1:end) = x(5,ii+1:end) + step1;
    end
    % if  ii>5&&ii<length(t)-2
    %     if(mod(ii,6)==2)
    %         x(1,ii:end) = x(1,ii:end) + step1;
    %         x(1,ii+1:end) = x(1,ii+1:end) + step1;
    %         x(6,ii:end) = x(6,ii:end) + step1;
    %         x(6,ii+1:end) = x(6,ii+1:end) + step1;
    %     end
    %     if(mod(ii,6)==4)
    %         x(3,ii:end) = x(3,ii:end) + step1;
    %         x(3,ii+1:end) = x(3,ii+1:end) + step1;
    %         x(4,ii:end) = x(4,ii:end) + step1;
    %         x(4,ii+1:end) = x(4,ii+1:end) + step1;
    %     end
    %     if(mod(ii,6)==0)
    %         x(2,ii:end) = x(2,ii:end) + step1;
    %         x(2,ii+1:end) = x(2,ii+1:end) + step1;
    %         x(5,ii:end) = x(5,ii:end) + step1;
    %         x(5,ii+1:end) = x(5,ii+1:end) + step1;
    %     end
    % end
    % 修改1 —— 提前在前移循环内更新 xbb（取足端 X 的均值），供上高台触发判据使用
    for jj = 1:6
    xbb(ii) = x(jj,ii)/6+xbb(ii);
    end
end

%% 上高台
% 基座接近台阶区域时逐步抬高机体 Z，并抬高足端。
% 目标：从地面(Z=0)登上高度为 wh 的台阶。
dais = 5.975;    % 台阶前沿 X 坐标
wh = 0.5;        % 台阶高度
% 贝塞尔平滑过渡区间：机体从 dais_rise_x 开始抬升，到 dais_full_x 完成
dais_rise_x = dais - 1.5;   % 机体开始抬升的 X 坐标
dais_full_x = dais + 2.2;   % ★修改：由 1.0 改为 2.2，所有腿都踏上台阶后才达到最高高度
zbb_max = wh * 0.8;         % ★修改：机体最高只抬升到台阶高度的 80% (0.4m)，降低重心，保证后中腿不悬空

for ii=1:length(t)
    % 1. 机体高度控制 (zbb) —— 贝塞尔平滑过渡（借鉴 walk_slope.m）
    if xbb(ii) <= dais_rise_x
        zbb(ii) = 0;
    elseif xbb(ii) >= dais_full_x
        zbb(ii) = zbb_max;
    else
        % 归一化进度 p ∈ [0, 1]
        p = (xbb(ii) - dais_rise_x) / (dais_full_x - dais_rise_x);
        smooth_p = 3*p^2 - 2*p^3;  % 贝塞尔类平滑阶跃，防止突变
        zbb(ii) = smooth_p * zbb_max;
    end

    % 2. 足端高度控制 (z)
    for jj = 1:6
        if (x(jj,ii) >= dais)
            % 足端越过台阶后，支撑面高度增加 wh
            z(jj,ii) = z(jj,ii) + wh;
        else
            % 避障抬高只在台阶前生效（x < dais），防止脚尖踢到台阶边缘
            if ii>1 && x(jj,ii) > dais-0.2
                z(jj,ii) = z(jj,ii) + 0.1;
            end
        end
    end
end

%%基座
% 用各足端 X 的平均值近似基座 X 位移，得到机体整体前进轨迹
% 修改4 —— 取消后段重复累计 xbb，避免与前移循环内的更新重复
% for ii=1:length(t)
%     for jj = 1:6
%         xbb(ii) = x(jj,ii)/6+xbb(ii);  % 物理意义：用各足端 X 的平均位移近似机体前进
%     end
% end
%%
% 连续化插值：用 makima/ppval 将分段轨迹映射到采样时间轴 xq
xq = 0:0.005:stept * k;
% 采样时间步长为 0.005 s（与仿真触发周期一致）
xhr = makima(t,x);
yhr = makima(t,y);
zhr = makima(t,z);
% 使用 makima 获得保形平滑插值，减少高频震荡与过冲
x0 = ppval(xhr,xq);
y0 = ppval(yhr,xq);
z0 = ppval(zhr,xq);
% 形状：x0/y0/z0 为 6×|xq|；每一行对应一条腿的离散时间序列

xhrr = makima(t,xbb);
yhrr = makima(t,ybb);
zhrr = makima(t,zbb);
xb = ppval(xhrr,xq);
yb = ppval(yhrr,xq);
zb = ppval(zhrr,xq);
% 形状：xb/yb/zb 为 1×|xq|；表示机体基座的离散时间序列

% 绘图检查（与 walk_slope.m 风格一致）
figure('Name','walk3step_high - 足端X轨迹');
plot(x0'); hold on; plot(xb');
xlabel('时间步'); ylabel('X (m)'); title('足端X轨迹检查');

figure('Name','walk3step_high - 足端Z轨迹');
plot(z0'); xlabel('时间步'); ylabel('Z (m)'); title('足端Z轨迹检查');

figure('Name','walk3step_high - 机体Z轨迹');
plot(zb'); xlabel('时间步'); ylabel('Zb (m)'); title('机体Z抬升轨迹');
%% 生成
% 逆运动学/碰撞求解：根据期望足端位姿，结合机器人模型求解各关节角 joint
robot=robot3D_description;
fprintf('开始逆运动学求解（共 %d 帧）...\n', length(xq));
posR = [0,0,0,0,0,0];   % 记录各腿末端最大倾斜角（与世界 Z 夹角）
for i=1:length(xq)
    for ii = 1:6
        % joint 维度：length(xq) × 18（6 条腿 × 每腿 3 关节），单位：弧度
        % 当前时刻第 ii 条腿的期望末端位姿（R = 姿态，p = 位置）
        Target(i).R=eye(3);%roty(r0(ii,i));
        % 足端期望位置来自插值后的目标轨迹 x0/y0/z0
        Target(i).p=[x0(ii,i);y0(ii,i);z0(ii,i)];
        % 基座（机体质心）在该时刻的位姿，用于逆解参考
        robot(1).p=[xb(i);yb(i);zb(i)];
        %
        %         Target(i).p=[2.5;-2.95;2];
        %         id = 4;
        %         robot=ikinematic(robot,id,Target);
        % 选择第 ii 条腿的碰撞/末端标识（每条腿 3 个关节，索引映射到 robot 数组）
        c_id=[1 + 3 * ii , 1];
        % 带约束/碰撞的逆解求解，返回该腿各关节角
        robot=ik_collision(robot,Target(i),c_id);
        % 填充输出轨迹 joint：按腿与关节序号写入该时刻的关节角
        for jj = 1:3
            joint(i,jj + 3 * ii - 3)=robot(jj + 3 * ii - 2).q;
        end
        % 记录该腿碰撞点位姿，用于可视化与安全评估
        pos(ii).p(i,:)=robot(c_id(1)).collision(c_id(2)).p;  % 尺寸：N×3，分别为 X/Y/Z
        % 提取旋转矩阵的第三列作为向量（末端局部 Z 轴），与世界 Z 比较
        rotated_z = robot(c_id(1)).collision(c_id(2)).R(:, 3);
        z_axis = [0; 0; 1];
        dot_product = dot(rotated_z, z_axis);
        norm_rotated_z = norm(rotated_z);
        norm_z = norm(z_axis);
        angle_rad = acos(dot_product / norm_rotated_z);
        angle_deg(ii,i) = rad2deg(angle_rad);
        if angle_deg(ii,i) > posR(ii)
            if i == 1||z0(ii,i) == z0(ii,i-1)
            posR(ii) = angle_deg(ii,i);
            end
        end
    end
    if mod(i, 500) == 0
        fprintf('  进度: %d/%d\n', i, length(xq));
    end
end
 % 末端位置曲线（X 分量）：检查不同腿在时间上的位移一致性
 plot(pos(1).p(:,1));
hold on
plot(pos(2).p(:,1));
plot(pos(3).p(:,1));
plot(pos(4).p(:,1));
plot(pos(5).p(:,1));
plot(pos(6).p(:,1));
figure 
% 末端位置曲线（Z 分量）：检查抬腿与台阶/跨坑过程中的高度变化
plot(pos(1).p(:,3));
hold on
plot(pos(2).p(:,3));
plot(pos(3).p(:,3));
plot(pos(4).p(:,3));
plot(pos(5).p(:,3));
plot(pos(6).p(:,3));

saveDir = fullfile(fileparts(mfilename('fullpath')),'export_data');
% 保存目录：脚本所在目录下的 export_data（若不存在则自动创建）
if ~exist(saveDir,'dir'), mkdir(saveDir); end
% 保存文件：包含变量 joint（N×18，弧度）
save(fullfile(saveDir,'walk3step_high.mat'),'joint')
% 小贴士：运行结束后，工作区已有变量 joint（N×18，弧度）
% 如需供 PG('climb2wall') 使用，可保存到 export_data：
% save('轨迹仿真程序/MAIN/6leg_motion/export_data/walk3step.mat','joint')

