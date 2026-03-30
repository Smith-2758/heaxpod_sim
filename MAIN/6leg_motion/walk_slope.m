%% =====================================================================
%  walk_slope.m —— 六足机器人 15° 斜坡地形跨越轨迹生成脚本
%
%  场景：6leg_slope.ttt
%  功能：生成六足机器人在平地行走 + 平稳爬上 15° 斜坡的足端期望轨迹
%  斜坡参数：倾角 15°，斜坡底部前沿 X 坐标约 1.5m（距机器人初始位置）
%
%  核心策略：
%  - 机器人保持常规三角步态
%  - 当机体质心 X 超过斜坡起始坐标后，机体 Z（zbb）随坡面角度线性抬升
%  - 足端 Z（摆动相位的抬起高度）在斜坡段同步增加，避免踩不到坡面
%
%  使用方法：
%  1) cd 到 "轨迹仿真程序/MAIN/6leg_motion/"
%  2) 运行本脚本，等待计算完成
%  3) 生成 export_data/walk_slope.mat（变量 joint，N×18，弧度）
%  4) 在 main_v2.m 中选 pattern = {'slope'} 并运行
%% =====================================================================
clear all; close all; clc

%% 基础参数
walklength = 5;
wl = 3;

% 机体质心初始位置
% 必须与 CoppeliaSim_process.m 中 case 'slope' 的 position(1) 保持一致
body_x = 3.8;  % 原值3.0，现前移0.8m，设为3.8
body_y = 0;
body_z = 0;

% 足端初始位置（六足：右1/右2/右3/左1/左2/左3）
x01 = 1.75 + body_x;
x02 = 0    + body_x;
x03 = -1.75 + body_x;
yr0 = -2.23 + body_y;
yl0 =  2.23 + body_y;
zf0 = -2.05 + body_z;

% 行走速度 (m/s)
v = 0.30;   % 斜坡地形稍放慢速度

% 时间配置
t_total = 30;
tt = abs(0.9/6/v);
foott = tt * 2;
stept = foott + foott + foott;

% 步长与抬腿高度
step0 = v * stept;
step1 = step0 / 2;
steph = 0.3;   % 正常抬腿高度（m）

%% 斜坡参数
slope_start_x = 5.975; % 斜坡底部前沿的世界 X 坐标（对应 6leg_slope.ttt 场景）
                       % 来源：原 wall 物体 center_x=11.975, 长度=12m → 前沿=11.975-6=5.975
slope_angle   = 15 * pi / 180;  % 15° 坡角（弧度）
% 机体抬升高度的折减系数（动态过渡）：起始0.4（低趴求稳），完全上坡后0.85（防止头部磕地）
slope_coeff_start = 0.2;
slope_coeff_end   = 0.7;
slope_h_extra = 0.2;   % 变量保留（已不再用于腿部刚性抬高计算）

%% 轨迹时间轴离散
k = fix(t_total/stept);
for i = 0:k-1
    t(6*i+1) = stept * i;
    t(6*i+2) = stept * i + tt;
    t(6*i+3) = stept * i + foott;
    t(6*i+4) = stept * i + foott + tt;
    t(6*i+5) = stept * i + foott*2;
    t(6*i+6) = stept * i + foott*2 + tt;
end
t(6*k+1) = stept * k;

% 基座轨迹初始化
xbb = zeros(1, length(t));
ybb = body_y * ones(1, length(t));
zbb = body_z * ones(1, length(t));

%% 足端 Y/Z 赋值
for ii = 1:length(t)
    y(1,ii) = yr0;  y(2,ii) = yr0;  y(3,ii) = yr0;
    y(4,ii) = yl0;  y(5,ii) = yl0;  y(6,ii) = yl0;
end
z = zf0 * ones(6, length(t));

% 按 6 相位抬腿
for ii = 1:length(t)
    if mod(ii,6) == 2
        z(1,ii) = zf0 + steph;  z(6,ii) = zf0 + steph;
    end
    if mod(ii,6) == 4
        z(3,ii) = zf0 + steph;  z(4,ii) = zf0 + steph;
    end
    if mod(ii,6) == 0
        z(2,ii) = zf0 + steph;  z(5,ii) = zf0 + steph;
    end
end

%% 足端 X 赋值与前移循环
x_0 = [x01; x02; x03; x01; x02; x03];
x = repmat(x_0, 1, length(t));

for ii = 1:length(t)
    if mod(ii,6) == 2
        x(1,ii:end) = x(1,ii:end) + step1;  x(1,ii+1:end) = x(1,ii+1:end) + step1;
        x(6,ii:end) = x(6,ii:end) + step1;  x(6,ii+1:end) = x(6,ii+1:end) + step1;
    end
    if mod(ii,6) == 4
        x(3,ii:end) = x(3,ii:end) + step1;  x(3,ii+1:end) = x(3,ii+1:end) + step1;
        x(4,ii:end) = x(4,ii:end) + step1;  x(4,ii+1:end) = x(4,ii+1:end) + step1;
    end
    if mod(ii,6) == 0
        x(2,ii:end) = x(2,ii:end) + step1;  x(2,ii+1:end) = x(2,ii+1:end) + step1;
        x(5,ii:end) = x(5,ii:end) + step1;  x(5,ii+1:end) = x(5,ii+1:end) + step1;
    end
    % 更新基座 X（取各足端 X 均值）
    for jj = 1:6
        xbb(ii) = x(jj,ii)/6 + xbb(ii);
    end
end

%% 斜坡补偿：机体 Z 随坡面抬升 + 斜坡段足端额外抬高
for ii = 1:length(t)
    % 动态重心系数和平滑姿态由于需要完整遍历，统一放到后文专门的循环中计算

    % 斜坡段各腿足端 Z 同步抬高（降低踩空风险）
    for jj = 1:6
        if x(jj,ii) > slope_start_x
            % 去除原有的固定额外抬高量 slope_h_extra，仅按照严格坡面进行计算
            z(jj,ii) = z(jj,ii) + (x(jj,ii) - slope_start_x) * tan(slope_angle);
        end
    end
end

%% 机体 Pitch 姿态角（俯仰角）及重心抬高系数平滑过渡计算
% 根据需求，当机器人全部腿都在坡上后，身体才完全过渡到15°
% 头部到达坡面：xbb = slope_start_x - 1.75 (记录为 slope_rise_x)
% 尾部到达坡面：xbb = slope_start_x + 1.75 (全部腿均已上坡)
slope_rise_x = slope_start_x - 1.75;
slope_full_x = slope_start_x + 1.75;
pitch_bb = zeros(1, length(t));
coeff_bb = zeros(1, length(t)); % 存放动态折减系数
for ii = 1:length(t)
    if xbb(ii) <= slope_rise_x
        pitch_bb(ii) = 0;
        coeff_bb(ii) = slope_coeff_start;
    elseif xbb(ii) >= slope_full_x
        pitch_bb(ii) = slope_angle;
        coeff_bb(ii) = slope_coeff_end;
    else
        % 在机身通过坡面前沿的这 3.5m 长距离中平滑过渡
        p = (xbb(ii) - slope_rise_x) / (slope_full_x - slope_rise_x);
        smooth_p = 3*p^2 - 2*p^3; % 贝塞尔类平滑阶跃，防止突变
        pitch_bb(ii) = smooth_p * slope_angle;
        coeff_bb(ii) = slope_coeff_start + smooth_p * (slope_coeff_end - slope_coeff_start);
    end
end

% 补偿前文中的 Z 抬升（覆盖刚刚预赋的值）
for ii = 1:length(t)
    if xbb(ii) > slope_rise_x
        delta_x = xbb(ii) - slope_rise_x;
        zbb(ii) = delta_x * tan(slope_angle) * coeff_bb(ii);
    end
end

%% 插值到连续时间轴
xq = 0:0.005:stept * k;

xhr = makima(t, x);
yhr = makima(t, y);
zhr = makima(t, z);
x0  = ppval(xhr, xq);
y0  = ppval(yhr, xq);
z0  = ppval(zhr, xq);

xhrr = makima(t, xbb);
yhrr = makima(t, ybb);
zhrr = makima(t, zbb);
xb = ppval(xhrr, xq);
yb = ppval(yhrr, xq);
zb = ppval(zhrr, xq);

% 姿态角插值
pitch_hr = makima(t, pitch_bb);
pitch0 = ppval(pitch_hr, xq);

% 绘图检查
figure('Name','walk_slope - 足端X轨迹');
plot(x0'); hold on; plot(xb');
xlabel('时间步'); ylabel('X (m)'); title('足端X轨迹检查');

figure('Name','walk_slope - 足端Z轨迹');
plot(z0'); xlabel('时间步'); ylabel('Z (m)'); title('足端Z轨迹检查');

figure('Name','walk_slope - 机体Z轨迹');
plot(zb'); xlabel('时间步'); ylabel('Zb (m)'); title('机体Z抬升轨迹');

%% 逆运动学求解，生成关节角序列 joint
robot = robot3D_description;
fprintf('开始逆运动学求解（共 %d 帧）...\n', length(xq));
for i = 1:length(xq)
    
    % [核心修复] 根据当前帧的俯仰角 pitch0(i)，生成对应的机身旋转矩阵 R
    % 旋转绕 Y 轴。为了让机器人车头“抬起”，需要绕 Y 轴转负角度
    theta = -pitch0(i);
    Ry = [cos(theta),  0, sin(theta);
          0,           1, 0;
         -sin(theta),  0, cos(theta)];
         
    for ii = 1:6
        Target(i).R = eye(3);
        Target(i).p = [x0(ii,i); y0(ii,i); z0(ii,i)];
        
        robot(1).p  = [xb(i); yb(i); zb(i)];
        robot(1).R  = Ry; % 将真实的倾斜姿态赋予底盘，以便逆运动学解出准确的“倾斜支撑”下各关节角
        
        c_id = [1 + 3*ii, 1];
        robot = ik_collision(robot, Target(i), c_id);
        for jj = 1:3
            joint(i, jj + 3*ii - 3) = robot(jj + 3*ii - 2).q;
        end
    end
    if mod(i, 500) == 0
        fprintf('  进度: %d/%d\n', i, length(xq));
    end
end

%% 保存结果
saveDir = fullfile(fileparts(mfilename('fullpath')), 'export_data');
if ~exist(saveDir, 'dir'), mkdir(saveDir); end
save(fullfile(saveDir, 'walk_slope.mat'), 'joint', 'xb', 'zb', 'pitch0');
fprintf('已保存 export_data/walk_slope.mat（共 %d 帧，含基座位置及姿态参考）\n', size(joint,1));
