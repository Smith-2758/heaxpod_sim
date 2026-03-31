function [run_output_dir, group_root] = hexapod_prepare_compare_run_dir(project_root, scene_name, compare_group_id, case_id, repeat_index)
if nargin < 5 || isempty(repeat_index)
    repeat_index = 1;
end
if nargin < 4 || isempty(case_id)
    error('hexapod_prepare_compare_run_dir:MissingCaseId', '必须提供 case_id。');
end
if nargin < 3 || isempty(compare_group_id)
    error('hexapod_prepare_compare_run_dir:MissingGroupId', '必须提供 compare_group_id。');
end

scene_info = hexapod_scene_info(scene_name);
group_root = fullfile(project_root, 'log', scene_info.scene_name, compare_group_id);
case_root = fullfile(group_root, case_id);
if ~exist(case_root, 'dir')
    mkdir(case_root);
end

run_id = sprintf('run_%02d_%s', repeat_index, datestr(now, 'yyyymmdd_HHMMSS'));
run_output_dir = fullfile(case_root, run_id);
suffix_id = 1;
while exist(run_output_dir, 'dir')
    run_output_dir = fullfile(case_root, sprintf('%s_%02d', run_id, suffix_id));
    suffix_id = suffix_id + 1;
end
mkdir(run_output_dir);
end
