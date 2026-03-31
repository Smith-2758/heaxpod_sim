function result = hexapod_run_compare_case(case_id, options)
if nargin < 1 || isempty(case_id)
    error('hexapod_run_compare_case:MissingCaseId', '必须提供 case_id。');
end
if nargin < 2 || isempty(options)
    options = struct();
end

cases = hexapod_compare_cases();
match = strcmp({cases.case_id}, case_id);
if ~any(match)
    error('hexapod_run_compare_case:UnknownCase', '未知的对比 case: %s', case_id);
end
cfg = cases(find(match, 1, 'first'));
scene_info = hexapod_scene_info(cfg.scene_name);
project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));

repeat_index = get_option(options, 'repeat_index', 1);
compare_group_id = get_option(options, 'compare_group_id', '');
if isempty(get_option(options, 'run_output_dir', ''))
    if ~isempty(compare_group_id)
        [run_output_dir, group_root] = hexapod_prepare_compare_run_dir(project_root, scene_info.scene_name, compare_group_id, cfg.case_id, repeat_index); %#ok<ASGLU>
    else
        [run_output_dir, ~] = hexapod_prepare_output_dir(project_root, scene_info.scene_name, now);
    end
else
    run_output_dir = options.run_output_dir;
    if ~exist(run_output_dir, 'dir')
        mkdir(run_output_dir);
    end
end

artifact_dir = fullfile(run_output_dir, 'source_artifacts');
if ~exist(artifact_dir, 'dir')
    mkdir(artifact_dir);
end

export_meta = build_export_meta(cfg, options, run_output_dir, artifact_dir);
result = cfg;
result.run_output_dir = run_output_dir;
result.compare_group_id = compare_group_id;
result.repeat_index = repeat_index;
result.coppeliasim_launch_info = get_option(options, 'coppeliasim_launch_info', struct());

switch cfg.source_type
    case 'pg_current'
        [Joint, ~] = PG({cfg.pattern});
        joint = Joint{1};
        [joint, export_meta] = normalize_joint_for_export(joint, export_meta, cfg.case_id, artifact_dir);
        CoppeliaSim_process({cfg.pattern}, {joint}, export_meta);

    case 'mat_file'
        joint = hexapod_load_joint_matrix(cfg.mat_path);
        [joint, export_meta] = normalize_joint_for_export(joint, export_meta, cfg.case_id, artifact_dir);
        CoppeliaSim_process({cfg.pattern}, {joint}, export_meta);

    case 'origin_step_initial'
        [joint, info] = hexapod_generate_origin_initial('step', struct('target_total_frames', export_meta.target_total_frames));
        export_meta.natural_total_frames = info.natural_total_frames;
        export_meta.target_total_frames = size(joint, 1);
        export_meta.frame_normalization = info.frame_normalization;
        export_meta.source_artifact_path = save_joint_artifact(joint, artifact_dir, cfg.case_id);
        CoppeliaSim_process({cfg.pattern}, {joint}, export_meta);

    case 'origin_ditch_initial'
        [joint, info] = hexapod_generate_origin_initial('ditch', struct('target_total_frames', export_meta.target_total_frames));
        export_meta.natural_total_frames = info.natural_total_frames;
        export_meta.target_total_frames = size(joint, 1);
        export_meta.frame_normalization = info.frame_normalization;
        export_meta.source_artifact_path = save_joint_artifact(joint, artifact_dir, cfg.case_id);
        CoppeliaSim_process({cfg.pattern}, {joint}, export_meta);

    case 'ditch_half_replay'
        learned_mat_path = hexapod_run_ditch_half_baseline(cfg.script_path);
        joint = hexapod_load_joint_matrix(learned_mat_path);
        [joint, export_meta] = normalize_joint_for_export(joint, export_meta, cfg.case_id, artifact_dir);
        export_meta.original_source_artifact = learned_mat_path;
        CoppeliaSim_process({cfg.pattern}, {joint}, export_meta);

    case 'ditch_final_closed_loop'
        export_meta.natural_total_frames = hexapod_probe_case_frame_count(cfg);
        if isempty(export_meta.target_total_frames)
            export_meta.target_total_frames = export_meta.natural_total_frames;
        end
        if export_meta.target_total_frames == export_meta.natural_total_frames
            export_meta.frame_normalization = 'none';
        else
            export_meta.frame_normalization = 'resampled_reference';
        end
        CoppeliaSim_learn_ditch(export_meta);

    otherwise
        error('hexapod_run_compare_case:UnsupportedSource', '不支持的 source_type: %s', cfg.source_type);
end

result.target_total_frames = export_meta.target_total_frames;
result.natural_total_frames = export_meta.natural_total_frames;
result.output_dir = run_output_dir;
end

function export_meta = build_export_meta(cfg, options, run_output_dir, artifact_dir)
scene_info = hexapod_scene_info(cfg.scene_name);
export_meta = struct();
export_meta.scene_name = scene_info.scene_name;
export_meta.scene_label = scene_info.scene_label;
export_meta.scene_variant = cfg.scene_variant;
export_meta.source_flow = cfg.case_id;
export_meta.entry_pattern = cfg.pattern;
export_meta.case_id = cfg.case_id;
export_meta.case_description = cfg.description;
export_meta.compare_group_id = get_option(options, 'compare_group_id', '');
export_meta.repeat_index = get_option(options, 'repeat_index', NaN);
export_meta.target_total_frames = get_option(options, 'target_total_frames', []);
export_meta.output_dir = run_output_dir;
export_meta.artifact_output_dir = artifact_dir;
export_meta.natural_total_frames = NaN;
export_meta.frame_normalization = 'none';

launch_info = get_option(options, 'coppeliasim_launch_info', struct());
if ~isempty(launch_info)
    export_meta.coppeliasim_exe_path = get_launch_field(launch_info, 'exe_path', '');
    export_meta.coppeliasim_scene_path = get_launch_field(launch_info, 'scene_path', '');
    export_meta.coppeliasim_port = get_launch_field(launch_info, 'port', NaN);
    export_meta.coppeliasim_host = get_launch_field(launch_info, 'host', '');
    export_meta.coppeliasim_auto_restart = get_launch_field(launch_info, 'auto_restart', NaN);
    export_meta.coppeliasim_restart_performed = get_launch_field(launch_info, 'restart_performed', NaN);
    export_meta.coppeliasim_startup_wait_sec = get_launch_field(launch_info, 'startup_wait_sec', NaN);
    export_meta.coppeliasim_shutdown_wait_sec = get_launch_field(launch_info, 'shutdown_wait_sec', NaN);
    export_meta.coppeliasim_launch_timestamp = get_launch_field(launch_info, 'launch_timestamp', '');
end
end

function [joint, export_meta] = normalize_joint_for_export(joint, export_meta, artifact_name, artifact_dir)
joint = double(joint);
export_meta.natural_total_frames = size(joint, 1);
if isempty(export_meta.target_total_frames)
    export_meta.target_total_frames = export_meta.natural_total_frames;
end
if export_meta.target_total_frames ~= export_meta.natural_total_frames
    joint = hexapod_resample_joint_matrix(joint, export_meta.target_total_frames);
    export_meta.frame_normalization = 'resampled_joint';
else
    export_meta.frame_normalization = 'none';
end
export_meta.target_total_frames = size(joint, 1);
export_meta.source_artifact_path = save_joint_artifact(joint, artifact_dir, artifact_name);
end

function artifact_path = save_joint_artifact(joint, artifact_dir, artifact_name)
if ~exist(artifact_dir, 'dir')
    mkdir(artifact_dir);
end
artifact_path = fullfile(artifact_dir, sprintf('%s_joint_used.mat', artifact_name));
save(artifact_path, 'joint');
end

function value = get_option(options, field_name, default_value)
if isstruct(options) && isfield(options, field_name)
    value = options.(field_name);
else
    value = default_value;
end
end

function value = get_launch_field(launch_info, field_name, default_value)
if isstruct(launch_info) && isfield(launch_info, field_name)
    value = launch_info.(field_name);
else
    value = default_value;
end
end
