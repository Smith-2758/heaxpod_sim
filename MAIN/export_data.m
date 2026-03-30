%% =====================================================================
%  export_data.m —— 关节轨迹可视化与数据导出工具
%
%  功能简介：
%  - 接收 PG(pattern) 生成的 Joint（cell，每个元素为 N×18 的关节角度，单位：弧度）
%  - 将多个动作的关节轨迹纵向拼接后，绘制整体曲线与分腿关节角曲线
%  - 保留了数据导出接口示例（见文件底部），默认注释，可按需启用或扩展
%
%  使用方法：
%  1）在主程序生成轨迹：
%      Joint = PG(pattern);
%  2）调用本函数进行可视化/导出：
%      export_data(Joint);
%  3）时间步长假定为 0.005 s；若你修改了轨迹生成的步长，请同步调整本文件的时间轴 tt
%
%  与其他程序的关系：
%  - 上游：PG.m 负责依据 pattern 生成/加载关节轨迹 Joint；main_v2.m 在生成后可选择调用本函数
%  - 下游：CoppeliaSim_process.m 用于在仿真器中播放 Joint。本函数仅可视化，不参与仿真控制
%  - 扩展：底部示例调用的 GetRTXData_black 等导出接口可用于将 Joint 写入数据文件（示例默认注释）
%
%  输入/输出：
%  - 输入：Joint（cell），每个 Joint{k} 为 N×18 的弧度制关节角矩阵
%  - 输出：无返回值；生成多个图窗，展示关节角度随时间的变化（绘图时转换为角度制）
%
%  注意事项：
%  - 角度单位：绘图时使用 57.3 将弧度转换为度
%  - 图窗较多，批量仿真时建议按需开启或关闭绘图
%  - 时间轴 tt 的构造假定采样间隔为 0.005 s，如有变动请对应修改
%% =====================================================================
function export_data(Joint)
Joint_plot=[];
for kkk=1:length(Joint)
    Joint_plot=[Joint_plot;Joint{kkk}];
end
figure
plot(Joint_plot(:,1:end))
for jj = 1 : length(Joint_plot)
    tt(jj) = 0.005*jj;
end
for i = 1:3
    figure
    for jj = 0:5
        plot(tt,Joint_plot(:,3*jj +i)*57.3)
        hold on
    end
    legend ('右腿1','右腿2','右腿3','左腿1','左腿2','左腿3');
    title(['腿部' num2str(i) '关节角度'])
    xlabel('时间/s')
    ylabel('度/°')
end
% GetRTXData_black(Joint{1},'data_black1/change.dat');
% GetRTXData_black(Joint{1},'data_black1/roll2roll_left.dat');
% GetRTXData_black([Joint{4};Joint{5}],'data_black1/turn_over_sit.dat');
% GetRTXData_black(Joint{6},'data_black1/roll.dat');

end
