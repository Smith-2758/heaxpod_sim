function outputs = hexapod_plot_midterm_step_extra_curves(compare_root, output_dir)
% 生成中期报告高台场景补充曲线图

if nargin < 1 || isempty(compare_root)
    project_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    compare_root = fullfile(project_root, 'log', 'step', 'compare_user_step_repeat3_20260401_fixbaseline');
end
if nargin < 2 || isempty(output_dir)
    output_dir = fullfile(compare_root, 'midterm_assets_extra');
end

config = struct();
config.scene_key = 'step';
config.scene_title = '高台';
config.compare_root = compare_root;
config.output_dir = output_dir;
config.case_specs = [ ...
    struct('case_id', 'step_initial', 'label', '传统方案', 'case_dir', fullfile(compare_root, 'step_initial'), 'color', [0.45, 0.45, 0.45], 'line_style', '--');
    struct('case_id', 'step_current', 'label', '当前方案', 'case_dir', fullfile(compare_root, 'step_current'), 'color', [0.85, 0.33, 0.10], 'line_style', '-') ...
    ];

outputs = hexapod_plot_midterm_extra_curves_common(config);
disp('已生成高台场景补充曲线图：');
disp(outputs);
end
