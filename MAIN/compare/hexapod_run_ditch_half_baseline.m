function learned_mat_path = hexapod_run_ditch_half_baseline(script_path)
if nargin < 1 || isempty(script_path)
    cases = hexapod_compare_cases();
    match = strcmp({cases.case_id}, 'ditch_half_mid');
    script_path = cases(find(match, 1, 'first')).script_path;
end
if ~exist(script_path, 'file')
    error('hexapod_run_ditch_half_baseline:ScriptNotFound', '未找到脚本: %s', script_path);
end
script_dir = fileparts(script_path);
learned_mat_path = fullfile(script_dir, 'export_data', 'walk_ditch_learned.mat');
orig_dir = pwd;
cleanup_obj = onCleanup(@() cd(orig_dir)); %#ok<NASGU>
cd(script_dir);
run(script_path);
if ~exist(learned_mat_path, 'file')
    error('hexapod_run_ditch_half_baseline:OutputNotFound', '脚本执行后未生成: %s', learned_mat_path);
end
end
