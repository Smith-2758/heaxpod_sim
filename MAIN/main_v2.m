%% =====================================================================
%  main_v2.m  —— 六足机器人仿真主控程序（入口脚本）
%
%  本脚本相当于“总指挥”：
%  1）根据你选择的运动模式 pattern，调用 PG.m 生成对应的关节轨迹 Joint；
%  2）再把 pattern 和 Joint 交给 CoppeliaSim_process.m，驱动 CoppeliaSim 中的六足机器人执行；
%
%  主要联动文件：
%  - PG.m                    : 轨迹/动作生成调度器（根据 pattern 选择具体动作）
%  - 6leg_motion/*.m         : 各种具体步态/动作的轨迹生成函数（如 walk.m, walk3step.m, hello1.m 等）
%  - black_description/
%       ├─ robot3D_description.m : 六足机器人模型及运动学、动力学参数（在 PG 里被调用）
%       └─ lib_robot/*.m         : fkinematic / ikinematic 等运动学求解函数
%  - CoppeliaSim_process.m   : 负责与 CoppeliaSim 通信并按 Joint 播放动作
%  - lib/MatlabVrep.m        : 封装 CoppeliaSim 远程 API 的类，真正发指令给仿真软件
%
%  使用方法（典型流程）：
%  1. 启动 CoppeliaSim，并打开场景 6leg_xiugai_4.ttt；
%  2. 在 MATLAB 中 cd 到 “轨迹仿真程序/MAIN/”；
%  3. 在下面几种 pattern 中选择一种（把对应行取消注释，其余行注释掉）；
%  4. 直接运行本脚本，机器人会在 CoppeliaSim 中执行对应动作。
%
%  建议你从 'walk' 或 'Legstretch' 这两种简单模式入手进行理解。
%% =====================================================================

close all; clear; clc;     % 关闭所有图窗，清空变量和命令行，保证在“干净环境”下执行
addpath(genpath(fileparts(fileparts(mfilename('fullpath'))))); % 将上一级目录（项目根目录）及其所有子目录添加到 MATLAB 搜索路径

%% ===================== 1. 选择要执行的动作模式 =======================
% pattern 是一个 cell 数组，这里只用到第一个元素 pattern{1}
% 你只需要在下面几行里“选一行保留，其余全部注释”即可。

% ① 六足平地行走（使用 6leg_motion/walk.m 生成一个周期的行走关节轨迹，比较基础）
% pattern = { 'walk' };

% ② 爬到墙面（'climb2wall' 对应 PG.m 中的 case 'climb2wall'，实际上会从 walk3step.mat 中读取预先算好的关节轨迹）
%    - 生成这些数据的程序是 6leg_motion/walk3step.m，并由 export_data.m 保存为 .mat
%    - 运行逻辑：PG -> 读入 walk3step.mat/joint -> CoppeliaSim_process 播放
% pattern = { 'climb2wall' };

% ③ 沿着墙面爬行（'climbing' 对应 PG.m 中的 case 'climbing'，从 dais3step.mat 中读入关节轨迹）
% pattern = { 'climbing' };

% ④ 伸腿动作（'Legstretch'）
%    - 使用 hello1.m 生成前后腿的伸展/收回轨迹，用来测试单步动作和关节极限
%    - PG.m 中 case 'Legstretch' 会调用 hello1(period_time, step_time)
% pattern = { 'Legstretch' };

% ⑤ 低位爬行（示例，当前被注释掉；如果要用，请同时在 PG.m 中打开对应 case）
pattern = { 'ditch' };  % 其他可扩展模式：'stand_crawl','crawl','low_crawl_stand','rise2sit', 等

%% ===================== 2. 调用 PG 生成关节轨迹 =======================
% Joint 是一个 cell 数组，每个元素是一个动作片段的关节角度序列：
% - Joint{k} 的大小约为 [N_k × 18]，18 表示 18 个关节（6 条腿 × 3 关节/腿）；
% - 每一行是一帧（一个时间步）的关节角度（单位：弧度）；
% - PG(pattern) 内部会：
%    a) 根据 pattern{1} 选择具体的动作 case；
%    b) 调用对应的轨迹函数（如 walk.m / hello1.m / 读取某个 .mat 文件）；
%    c) 进行必要的插值和拼接，使多个动作片段连续、平滑。

[Joint, Pitch] = PG(pattern);

% 如果希望把生成的轨迹保存下来，便于后续离线分析/画图，
% 可以在这里调用 export_data.m（实验室原始代码中通常是：export_data(Joint);）
% export_data(Joint);   % <- 可选：把 Joint 保存到 MAIN/export_data/ 目录下

% 注意：
%  - PG 会用到 robot3D_description.m（加载机器人模型和运动学参数）；
%  - robot3D_description.m 又依赖 black_description/动力学属性/ 下的若干 .mat 文件；
%  - lib_robot/ 里的 fkinematic / ikinematic / ik_collision 等函数参与逆解和碰撞检测。

%% ===================== 3. 让 CoppeliaSim 播放该轨迹 ==================
% 现在，把选好的模式 pattern 和其对应的关节轨迹 Joint，一起交给
% CoppeliaSim_process.m：
% - 内部流程大致为：
%   1）创建 MatlabVrep 对象 vrobot = MatlabVrep(Control_T);
%   2）vrobot.init() 通过 remoteApi.dll 连接 CoppeliaSim；
%   3）根据 pattern{1} 设置机体在仿真中的初始位姿（set_body_p / set_body_o）；
%   4）vrobot.go() 启动同步仿真；
%   5）遍历 Joint{k} 的每一帧，将 Joint(k,:) 发送到各关节（set_joint + trigger）；
%   6）循环过程中，实时读取力传感器/机体位姿等数据，用于后续分析；
%   7）仿真结束后，暂停并停止仿真，画出各腿受力和总受力曲线。

export_meta = hexapod_main_export_meta_from_env();
if isempty(fieldnames(export_meta))
    CoppeliaSim_process(pattern, Joint);
else
    CoppeliaSim_process(pattern, Joint, export_meta);
end

% 到这里，本脚本的任务就完成了：
%  - 上半部分负责“决定做什么动作 + 生成动作轨迹”；
%  - 下半部分负责“把轨迹送给仿真器去执行，并收集数据”。
%
% 如果你想进一步深入理解：
%  1）先看 PG.m 中对应 case 的实现（动作是如何生成/拼接的）；
%  2）再看 6leg_motion/ 下面的具体步态代码（如 walk.m, walk3step.m, hello1.m）；
%  3）最后看 CoppeliaSim_process.m 和 MatlabVrep.m（怎么和 CoppeliaSim 交互）。
% 这样顺着“主控脚本 -> 轨迹生成 -> 机器人模型/运动学 -> 仿真接口”的链条看，
% 会比较容易建立整体的理解。
