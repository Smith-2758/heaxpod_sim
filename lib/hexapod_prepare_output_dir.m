function [run_output_dir, run_id] = hexapod_prepare_output_dir(project_root, scene_name, run_now)
if nargin < 3 || isempty(run_now)
    run_now = now;
end

scene_info = hexapod_scene_info(scene_name);
scene_root = fullfile(project_root, 'log', scene_info.scene_name);
if ~exist(scene_root, 'dir')
    mkdir(scene_root);
end

run_id = datestr(run_now, 'yyyymmdd_HHMMSS');
run_output_dir = fullfile(scene_root, run_id);
suffix_id = 1;
while exist(run_output_dir, 'dir')
    run_output_dir = fullfile(scene_root, sprintf('%s_%02d', run_id, suffix_id));
    suffix_id = suffix_id + 1;
end
mkdir(run_output_dir);
end
