%% =====================================================================
% main_ditch.m - 回放验证入口
% 
% 直接读取由 CoppeliaSim_learn_ditch.m (也就是带物理碰撞感知的示教程序) 
% 生成的闭眼执行矩阵 `walk_ditch_learned.mat`。
% 然后利用外层的常规 CoppeliaSim_process.m 进行极其纯净的高帧率播放验证。
% 此时所有避坑跨越动作已烧录在各关节角度之中。
% =====================================================================
clear; clc; close all;

% 作为独立入口运行时，先把项目根目录及其子目录加入搜索路径，
% 否则在干净 MATLAB 会话里找不到 lib/MatlabVrep.m 等依赖。
% 先显式加入路径初始化工具，再通过统一入口补齐依赖路径。
setup_dir = fullfile(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))), 'lib', 'setup');
addpath(setup_dir);
hexapod_setup_paths();
orig_dir = pwd;
cleanup_obj = onCleanup(@() cd(orig_dir));

fprintf('===================================================\n');
fprintf('  六足机器人 深沟（Ditch） 隔离运行专属接口 \n');
fprintf('===================================================\n');

% 检查并加载已经过闭环优化的终级关节矩阵
file_path = fullfile(fileparts(mfilename('fullpath')), 'export_data', 'walk_ditch_learned.mat');

if ~exist(file_path, 'file')
    fprintf('[错误] 没有找到已录制的闭环轨迹数据。\n');
    fprintf('  -> 请先确保运行过本目录下的 CoppeliaSim_learn_ditch() \n');
    return;
end

load(file_path, 'Joint_Learned');
fprintf('[核心] 成功加载完美过坑闭环轨迹: %s\n', file_path);

% 将纯净解算结果包装成能够送给通用进程执行的格式
Joint{1} = Joint_Learned;
pattern = {'ditch'};

% 回退到 MAIN 目录（以便调用全局的 CoppeliaSim_process.m 并共享其图表统计保存逻辑）
target_dir = fullfile(fileparts(mfilename('fullpath')), '..', '..');
cd(target_dir);

fprintf('正在拉起 CoppeliaSim_process.m 投喂完美关节阵列...\n\n');

try
    CoppeliaSim_process(pattern, Joint);
catch ME
    rethrow(ME);
end

fprintf('\n[完成] 仿真播放结束，返回 ditch 专属目录。\n');
