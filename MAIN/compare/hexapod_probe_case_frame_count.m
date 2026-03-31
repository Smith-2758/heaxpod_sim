function frame_count = hexapod_probe_case_frame_count(cfg)
if nargin < 1 || isempty(cfg)
    error('hexapod_probe_case_frame_count:MissingConfig', '必须提供 case 配置。');
end

switch cfg.source_type
    case 'pg_current'
        [Joint, ~] = PG({cfg.pattern});
        frame_count = size(Joint{1}, 1);

    case 'mat_file'
        joint = hexapod_load_joint_matrix(cfg.mat_path);
        frame_count = size(joint, 1);

    case 'origin_step_initial'
        [~, info] = hexapod_generate_origin_initial('step', struct('probe_only', true));
        frame_count = info.natural_total_frames;

    case 'origin_ditch_initial'
        [~, info] = hexapod_generate_origin_initial('ditch', struct('probe_only', true));
        frame_count = info.natural_total_frames;

    case 'ditch_half_replay'
        if exist(cfg.mat_path, 'file')
            joint = hexapod_load_joint_matrix(cfg.mat_path);
            frame_count = size(joint, 1);
        else
            learned_mat_path = hexapod_run_ditch_half_baseline(cfg.script_path);
            joint = hexapod_load_joint_matrix(learned_mat_path);
            frame_count = size(joint, 1);
        end

    case 'ditch_final_closed_loop'
        base_path = fullfile(fileparts(cfg.script_path), 'export_data', 'xyz_base.mat');
        if ~exist(base_path, 'file')
            error('hexapod_probe_case_frame_count:BasePathNotFound', '未找到深沟基础轨迹: %s', base_path);
        end
        data = load(base_path, 'xq');
        frame_count = numel(data.xq);

    otherwise
        error('hexapod_probe_case_frame_count:UnsupportedSource', '不支持的 source_type: %s', cfg.source_type);
end
end
