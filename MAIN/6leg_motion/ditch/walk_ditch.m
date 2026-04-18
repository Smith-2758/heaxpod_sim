%% =====================================================================
%  walk_ditch.m —— 六足机器人深沟跨越：开环基准轨迹生成器 (V4 闭环适配版)
%
%  功能：
%  生成最基础的离散步态周期序列，不包含力觉反馈。
%  所有支撑相轨迹被设定为“过触地” (zf0 - probe_depth) 探测模式。
%  生成的 xyz_base.mat 将作为 CoppeliaSim_learn_ditch.m 的主基准库。
% =====================================================================
clear all; close all; clc
addpath(genpath('../../../'));

%% 1. 基础物理参数 (物理单位：米, 秒)
body_x = -0.75;        % 机器人初始位置 (相对于 2.0m 坑壁的安全距离)
body_y = 0;
body_z = 0;

% 初始足端相对偏移
x01 =  1.75 + body_x;  % 前腿
x02 =  0    + body_x;  % 中腿
x03 = -1.75 + body_x;  % 后腿
yr0 = -2.23 + body_y;  % 右侧 Y 坐标
yl0 =  2.23 + body_y;  % 左侧 Y 坐标
zf0 = -2.05 + body_z;  % 地面高度基准 (足端相对高度)

% 动态步态属性
v = 0.35;              % 行走速度 (m/s)
t_total = 30;          % 仿真预测总时长 (s)
stept  = 0.9 / v;      % 计算一个大周期的时长
tt     = stept / 12;   % 离散相位时长
step0  = v * stept;      % 标准总步长
step1  = step0 / 2;      % 半步步幅
steph  = 0.3;          % 正常摆动相抬腿高度 (m)

% 探测冗余深度
% 在基准层面让脚扎入地面 10cm，以确保护理端有足够的探底行程触发力觉
probe_depth = 0.10;

%% 2. 离散相位离散化与 X 轴步幅预分配
k = fix(t_total / stept);
for i = 0:k-1
    for j = 1:12
        t(12*i + j) = stept * i + (j-1) * tt;
    end
end
t(12*k + 1) = stept * k;

xbb = zeros(1, length(t));
ybb = body_y * ones(1, length(t));
zbb = body_z * ones(1, length(t));

x_0 = [x01; x02; x03; x01; x02; x03];
x   = repmat(x_0, 1, length(t));

%% 3. 足端 Y/Z 探测相生成
y = [yr0 * ones(3, length(t)); yl0 * ones(3, length(t))];

% 初始支撑相：设定为过触地探测模式 zf0 - 0.10m
z = (zf0 - probe_depth) * ones(6, length(t));

for ii = 1:length(t)
    % 按照波浪步态时序依次抬腿：
    % 顺序：右后(3) -> 左后(6) -> 右中(2) -> 左中(5) -> 右前(1) -> 左前(4)
    if mod(ii,12)==2;  z(3,ii) = zf0 + steph; end
    if mod(ii,12)==4;  z(6,ii) = zf0 + steph; end
    if mod(ii,12)==6;  z(2,ii) = zf0 + steph; end
    if mod(ii,12)==8;  z(5,ii) = zf0 + steph; end
    if mod(ii,12)==10; z(1,ii) = zf0 + steph; end
    if mod(ii,12)==0;  z(4,ii) = zf0 + steph; end
end

%% 4. 足端 X 轴离散累加 (匀速行走)
for ii = 1:length(t)
    if mod(ii,12)==2
        x(3,ii:end)=x(3,ii:end)+step1; if ii+1<=length(t), x(3,ii+1:end)=x(3,ii+1:end)+step1; end
    end
    if mod(ii,12)==4
        x(6,ii:end)=x(6,ii:end)+step1; if ii+1<=length(t), x(6,ii+1:end)=x(6,ii+1:end)+step1; end
    end
    if mod(ii,12)==6
        x(2,ii:end)=x(2,ii:end)+step1; if ii+1<=length(t), x(2,ii+1:end)=x(2,ii+1:end)+step1; end
    end
    if mod(ii,12)==8
        x(5,ii:end)=x(5,ii:end)+step1; if ii+1<=length(t), x(5,ii+1:end)=x(5,ii+1:end)+step1; end
    end
    if mod(ii,12)==10
        x(1,ii:end)=x(1,ii:end)+step1; if ii+1<=length(t), x(1,ii+1:end)=x(1,ii+1:end)+step1; end
    end
    if mod(ii,12)==0
        x(4,ii:end)=x(4,ii:end)+step1; if ii+1<=length(t), x(4,ii+1:end)=x(4,ii+1:end)+step1; end
    end
    xbb(ii)= sum(x(:,ii))/6;
end

%% 5. Makima 高阶连续插值
xq = 0:0.005:stept * k;
xhr = makima(t, x); yhr = makima(t, y); zhr = makima(t, z);
x0 = ppval(xhr, xq); y0 = ppval(yhr, xq); z0 = ppval(zhr, xq);

xhrr = makima(t, xbb); yhrr = makima(t, ybb); zhrr = makima(t, zbb);
xb = ppval(xhrr, xq); yb = ppval(yhrr, xq); zb = ppval(zhrr, xq);

%% 6. 导出数据
saveDir = fullfile(fileparts(mfilename('fullpath')), 'export_data');
if ~exist(saveDir, 'dir'), mkdir(saveDir); end
save(fullfile(saveDir, 'xyz_base.mat'), 'xq', 'x0', 'y0', 'z0', 'xb', 'yb', 'zb', 'zf0');

fprintf('【轨迹库已就绪】数据点：%d\n', length(xq));

%% 7. 轨迹检查绘图
figure('Color','w');
plot(z0'); xlabel('帧'); ylabel('高度 (m)'); title('带探测深度的基准 Z 轨迹'); grid on;
yline(zf0, 'Color', [0.2 0.8 0.2], 'LineStyle', '--', 'Label', '地平面 zf0', 'LineWidth', 1.5);
