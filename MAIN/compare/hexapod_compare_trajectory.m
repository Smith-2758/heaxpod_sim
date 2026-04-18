function out = hexapod_compare_trajectory(action, varargin)
bootstrap_setup_paths();
if nargin < 1 || isempty(action)
    error('hexapod_compare_trajectory:MissingAction', '必须提供 action。');
end
action = char(string(action));

switch action
    case 'run_case'
        if numel(varargin) < 1
            error('hexapod_compare_trajectory:MissingCaseId', 'run_case 需要 case_id。');
        end
        options = struct();
        if numel(varargin) >= 2 && ~isempty(varargin{2})
            options = varargin{2};
        end
        out = run_case(varargin{1}, options);
    case 'probe_case_frame_count'
        if numel(varargin) < 1
            error('hexapod_compare_trajectory:MissingConfig', 'probe_case_frame_count 需要 case 配置。');
        end
        out = probe_case_frame_count(varargin{1});
    otherwise
        error('hexapod_compare_trajectory:UnknownAction', '未知 action: %s', action);
end
end

function result = run_case(case_id, options)
if nargin < 1 || isempty(case_id)
    error('hexapod_compare_trajectory:MissingCaseId', '必须提供 case_id。');
end
if nargin < 2 || isempty(options)
    options = struct();
end

cases = hexapod_compare_registry('cases');
match = strcmp({cases.case_id}, case_id);
if ~any(match)
    error('hexapod_compare_trajectory:UnknownCase', '未知的对比 case: %s', case_id);
end
cfg = cases(find(match, 1, 'first'));
scene_info = hexapod_scene_info(cfg.scene_name);
project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));

repeat_index = get_option(options, 'repeat_index', 1);
compare_group_id = get_option(options, 'compare_group_id', '');
if isempty(get_option(options, 'run_output_dir', ''))
    if ~isempty(compare_group_id)
        prepared_paths = hexapod_compare_report('prepare_run_dir', project_root, scene_info.scene_name, compare_group_id, cfg.case_id, repeat_index);
        run_output_dir = prepared_paths{1};
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
        joint = load_joint_matrix(cfg.mat_path);
        [joint, export_meta] = normalize_joint_for_export(joint, export_meta, cfg.case_id, artifact_dir);
        CoppeliaSim_process({cfg.pattern}, {joint}, export_meta);

    case 'origin_step_initial'
        [joint, info] = generate_origin_initial('step', struct('target_total_frames', export_meta.target_total_frames));
        export_meta.natural_total_frames = info.natural_total_frames;
        export_meta.target_total_frames = size(joint, 1);
        export_meta.frame_normalization = info.frame_normalization;
        export_meta.source_artifact_path = save_joint_artifact(joint, artifact_dir, cfg.case_id);
        CoppeliaSim_process({cfg.pattern}, {joint}, export_meta);

    case 'origin_ditch_initial'
        [joint, info] = generate_origin_initial('ditch', struct('target_total_frames', export_meta.target_total_frames));
        export_meta.natural_total_frames = info.natural_total_frames;
        export_meta.target_total_frames = size(joint, 1);
        export_meta.frame_normalization = info.frame_normalization;
        export_meta.source_artifact_path = save_joint_artifact(joint, artifact_dir, cfg.case_id);
        CoppeliaSim_process({cfg.pattern}, {joint}, export_meta);

    case 'ditch_half_generate_replay'
        [learned_mat_path, replay_launch_info] = run_ditch_half_generate_replay(cfg, options, export_meta);
        export_meta = apply_launch_info(export_meta, replay_launch_info);
        result.coppeliasim_launch_info = replay_launch_info;
        joint = load_joint_matrix(learned_mat_path);
        [joint, export_meta] = normalize_joint_for_export(joint, export_meta, cfg.case_id, artifact_dir);
        export_meta.original_source_artifact = learned_mat_path;
        CoppeliaSim_process({cfg.pattern}, {joint}, export_meta);

    case 'ditch_final_closed_loop'
        export_meta.natural_total_frames = probe_case_frame_count(cfg);
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
        error('hexapod_compare_trajectory:UnsupportedSource', '不支持的 source_type: %s', cfg.source_type);
end

result.target_total_frames = export_meta.target_total_frames;
result.natural_total_frames = export_meta.natural_total_frames;
result.output_dir = run_output_dir;
end

function frame_count = probe_case_frame_count(cfg)
if nargin < 1 || isempty(cfg)
    error('hexapod_compare_trajectory:MissingConfig', '必须提供 case 配置。');
end

switch cfg.source_type
    case 'pg_current'
        [Joint, ~] = PG({cfg.pattern});
        frame_count = size(Joint{1}, 1);

    case 'mat_file'
        joint = load_joint_matrix(cfg.mat_path);
        frame_count = size(joint, 1);

    case 'origin_step_initial'
        [~, info] = generate_origin_initial('step', struct('probe_only', true));
        frame_count = info.natural_total_frames;

    case 'origin_ditch_initial'
        [~, info] = generate_origin_initial('ditch', struct('probe_only', true));
        frame_count = info.natural_total_frames;

    case 'ditch_half_generate_replay'
        frame_count = probe_ditch_half_generation_frame_count(cfg.script_path);

    case 'ditch_final_closed_loop'
        base_path = fullfile(fileparts(cfg.script_path), 'export_data', 'xyz_base.mat');
        if ~exist(base_path, 'file')
            error('hexapod_compare_trajectory:BasePathNotFound', '未找到深沟基础轨迹: %s', base_path);
        end
        data = load(base_path, 'xq');
        frame_count = numel(data.xq);

    otherwise
        error('hexapod_compare_trajectory:UnsupportedSource', '不支持的 source_type: %s', cfg.source_type);
end
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
export_meta.zmp_mode = get_option(options, 'zmp_mode', get_struct_field(cfg, 'zmp_mode', ''));
export_meta.output_dir = run_output_dir;
export_meta.artifact_output_dir = artifact_dir;
export_meta.natural_total_frames = NaN;
export_meta.frame_normalization = 'none';

launch_info = get_option(options, 'coppeliasim_launch_info', struct());
export_meta = apply_launch_info(export_meta, launch_info);
end

function value = get_struct_field(s, field_name, default_value)
if isstruct(s) && isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end

function [joint, export_meta] = normalize_joint_for_export(joint, export_meta, artifact_name, artifact_dir)
joint = double(joint);
export_meta.natural_total_frames = size(joint, 1);
if isempty(export_meta.target_total_frames)
    export_meta.target_total_frames = export_meta.natural_total_frames;
end
if export_meta.target_total_frames ~= export_meta.natural_total_frames
    joint = resample_joint_matrix(joint, export_meta.target_total_frames);
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

function joint = load_joint_matrix(mat_path)
if ~exist(mat_path, 'file')
    error('hexapod_compare_trajectory:FileNotFound', '未找到轨迹文件: %s', mat_path);
end

data = load(mat_path);
preferred_names = {'joint', 'Joint_Learned', 'Joint', 'joint_data'};
for idx = 1:numel(preferred_names)
    name = preferred_names{idx};
    if isfield(data, name)
        joint = normalize_joint(data.(name));
        return;
    end
end

fields = fieldnames(data);
for idx = 1:numel(fields)
    candidate = data.(fields{idx});
    if isnumeric(candidate) && ndims(candidate) == 2 && size(candidate, 2) == 18
        joint = normalize_joint(candidate);
        return;
    end
end

error('hexapod_compare_trajectory:NoJointData', '文件中未找到可用的 18 列关节轨迹: %s', mat_path);
end

function joint = normalize_joint(candidate)
if iscell(candidate)
    if isempty(candidate)
        error('hexapod_compare_trajectory:EmptyCell', '关节轨迹 cell 为空。');
    end
    candidate = candidate{1};
end
joint = double(candidate);
if size(joint, 2) ~= 18
    error('hexapod_compare_trajectory:InvalidJointShape', '关节轨迹必须是 N x 18，当前大小为 %d x %d。', size(joint, 1), size(joint, 2));
end
end

function joint_out = resample_joint_matrix(joint_in, target_total_frames)
if nargin < 2 || isempty(target_total_frames)
    joint_out = double(joint_in);
    return;
end

joint_in = double(joint_in);
if size(joint_in, 2) ~= 18
    error('hexapod_compare_trajectory:InvalidResampleShape', 'joint_in 必须是 N x 18。');
end

joint_out = hexapod_resample_series(joint_in, target_total_frames, 1);
joint_out(1, :) = joint_in(1, :);
joint_out(end, :) = joint_in(end, :);
end

function [joint, info] = generate_origin_initial(scene_name, options)
if nargin < 2 || isempty(options)
    options = struct();
end

scene_info = hexapod_scene_info(scene_name);
scene_key = scene_info.scene_name;
config = build_origin_config(scene_key);
info = config;
info.scene_name = scene_key;
info.scene_label = scene_info.scene_label;
info.scene_variant = [scene_key, '_initial'];
info.frame_normalization = 'none';

if get_option(options, 'probe_only', false)
    joint = [];
    return;
end

[t, x, y, z, xbb, ybb, zbb] = build_base_gait(config);
switch scene_key
    case 'step'
        [x, z, zbb] = apply_step_initial(x, z, xbb, zbb, config);
    case 'ditch'
        x = apply_ditch_initial(x, z, config);
        xbb = mean(x, 1);
    otherwise
        error('hexapod_compare_trajectory:UnsupportedScene', '不支持的场景: %s', scene_key);
end

xq = 0:config.sample_dt:(config.stept * config.k);
x0 = ppval(makima(t, x), xq);
y0 = ppval(makima(t, y), xq);
z0 = ppval(makima(t, z), xq);
xb = ppval(makima(t, xbb), xq);
yb = ppval(makima(t, ybb), xq);
zb = ppval(makima(t, zbb), xq);

joint = solve_joint_trajectory(x0, y0, z0, xb, yb, zb);
info.natural_total_frames = size(joint, 1);

target_total_frames = get_option(options, 'target_total_frames', info.natural_total_frames);
if ~isempty(target_total_frames) && target_total_frames ~= info.natural_total_frames
    joint = resample_joint_matrix(joint, target_total_frames);
    info.frame_normalization = 'resampled_joint';
end
info.target_total_frames = size(joint, 1);
end

function config = build_origin_config(scene_key)
config = struct();
config.walklength = 5;
config.body_y = 0;
config.body_z = 0;
config.sample_dt = 0.005;
config.v = 0.28;
config.t_total = 20;
config.steph = 0.3;
config.body_x = 0;
config.step_edge_x = 5.975;
config.step_height = 0.5;
config.front_leg_offset_x = 1.75;
config.step_old_body_rise_travel_m = 5.0;
config.pit_edge_x = 1.5;

switch scene_key
    case 'step'
        config.body_x = 3.8;
    case 'ditch'
        config.body_x = -0.75;
    otherwise
        error('hexapod_compare_trajectory:UnsupportedScene', '不支持的场景: %s', scene_key);
end

config.x01 = 1.75 + config.body_x;
config.x02 = 0 + config.body_x;
config.x03 = -1.75 + config.body_x;
config.yr0 = -2.23 + config.body_y;
config.yl0 = 2.23 + config.body_y;
config.zf0 = -2.05 + config.body_z;
config.tt = abs(0.9 / 6 / config.v);
config.foott = config.tt * 2;
config.stept = config.foott * 3;
config.step0 = config.v * config.stept;
config.step1 = config.step0 / 2;
config.k = fix(config.t_total / config.stept);
config.natural_total_frames = numel(0:config.sample_dt:(config.stept * config.k));
end

function [t, x, y, z, xbb, ybb, zbb] = build_base_gait(config)
t = zeros(1, 6 * config.k + 1);
for i = 0:config.k - 1
    t(6 * i + 1) = config.stept * i;
    t(6 * i + 2) = config.stept * i + config.tt;
    t(6 * i + 3) = config.stept * i + config.foott;
    t(6 * i + 4) = config.stept * i + config.foott + config.tt;
    t(6 * i + 5) = config.stept * i + config.foott * 2;
    t(6 * i + 6) = config.stept * i + config.foott * 2 + config.tt;
end
t(6 * config.k + 1) = config.stept * config.k;

xbb = zeros(1, numel(t));
ybb = config.body_y * ones(1, numel(t));
zbb = config.body_z * ones(1, numel(t));

y = zeros(6, numel(t));
y(1:3, :) = config.yr0;
y(4:6, :) = config.yl0;

z = config.zf0 * ones(6, numel(t));
for ii = 1:numel(t)
    if mod(ii, 6) == 2
        z([1, 6], ii) = config.zf0 + config.steph;
    end
    if mod(ii, 6) == 4
        z([3, 4], ii) = config.zf0 + config.steph;
    end
    if mod(ii, 6) == 0
        z([2, 5], ii) = config.zf0 + config.steph;
    end
end

x0 = [config.x01; config.x02; config.x03; config.x01; config.x02; config.x03];
x = repmat(x0, 1, numel(t));
for ii = 1:numel(t)
    if mod(ii, 6) == 2
        x = apply_pair_motion(x, [1, 6], ii, config.step1, config.step1);
    end
    if mod(ii, 6) == 4
        x = apply_pair_motion(x, [3, 4], ii, config.step1, config.step1);
    end
    if mod(ii, 6) == 0
        x = apply_pair_motion(x, [2, 5], ii, config.step1, config.step1);
    end
end
xbb = mean(x, 1);
end

function [x, z, zbb] = apply_step_initial(x, z, xbb, zbb, config)
dais = config.step_edge_x;
wh = config.step_height;
front_reach_x = dais - config.front_leg_offset_x;
body_rise_per_phase = wh / max((config.step_old_body_rise_travel_m / max(config.v, eps)) / config.tt, 1);

for ii = 1:size(x, 2)
    if ii > 1
        zbb(ii) = zbb(ii - 1);
    end

    % 旧方案的整体抬升逻辑在前腿刚到台阶前沿时就开始介入，
    % 这里保持其“介入较早、线性抬升”的特点，但修正到和当前几何定义一致：
    % 横轴以质心为准，因此触发点应为 dais - 1.75。
    if xbb(ii) >= front_reach_x
        zbb(ii) = zbb(ii) + body_rise_per_phase;
    end
    zbb(ii) = min(zbb(ii), wh);

    for jj = 1:6
        if x(jj, ii) >= dais
            z(jj, ii) = z(jj, ii) + wh;
        end

        % 旧方案在台阶边缘附近还会叠加一层额外抬脚，
        % 这也是后续修正中要去掉的问题之一。这里保留该特征，
        % 使 compare 中的旧方案更接近原始行为。
        if ii > 1 && x(jj, ii) > (dais - 0.2)
            z(jj, ii) = z(jj, ii) + 0.1;
        end
    end
end
end

function x = apply_ditch_initial(x, z, config)
x_pit = config.pit_edge_x;
l_pit = (0.8 + 0.2 + 0.1 * 2) / 2;
l_pit0 = 1.75 / 2 - l_pit;
kk = [];
for idx = 1:size(x, 2)
    if x(6, idx) > x_pit && z(6, idx) == config.zf0
        kk = idx;
        break;
    end
end
if isempty(kk)
    error('hexapod_compare_trajectory:DitchTriggerNotFound', '未找到深沟基线触发点。');
end

s = x(6, kk) - x_pit;
phase_ranges = { ...
    max(1, kk - 1):min(size(x, 2), kk + 4), ...
    max(1, kk + 5):min(size(x, 2), kk + 10), ...
    max(1, kk + 11):min(size(x, 2), kk + 16), ...
    max(1, kk + 17):min(size(x, 2), kk + 22), ...
    max(1, kk + 23):min(size(x, 2), kk + 28), ...
    max(1, kk + 29):min(size(x, 2), kk + 34), ...
    max(1, kk + 35):min(size(x, 2), kk + 40)};

for ii = phase_ranges{1}
    x = apply_phase_offset(x, ii, -s, 'align');
end
for ii = phase_ranges{2}
    x = apply_phase_offset(x, ii, l_pit - config.step1, 'step');
end
for ii = phase_ranges{3}
    x = apply_phase_offset(x, ii, l_pit0 - config.step1, 'step');
end
for ii = phase_ranges{4}
    x = apply_phase_offset(x, ii, l_pit - config.step1, 'step');
end
for ii = phase_ranges{5}
    x = apply_phase_offset(x, ii, l_pit0 - config.step1, 'step');
end
for ii = phase_ranges{6}
    x = apply_phase_offset(x, ii, l_pit - config.step1, 'step');
end
for ii = phase_ranges{7}
    x = apply_phase_offset(x, ii, l_pit0 - config.step1, 'step');
end
end

function x = apply_phase_offset(x, ii, delta_value, mode_name)
leg_ids = [];
switch mod(ii, 6)
    case 2
        leg_ids = [1, 6];
    case 4
        leg_ids = [3, 4];
    case 0
        leg_ids = [2, 5];
end
if isempty(leg_ids)
    return;
end
if strcmp(mode_name, 'align')
    x = apply_aligned_offset(x, ii, leg_ids, delta_value);
else
    x = apply_pair_motion(x, leg_ids, ii, delta_value, delta_value);
end
end

function x = apply_pair_motion(x, leg_ids, ii, delta_now, delta_future)
x(leg_ids, ii:end) = x(leg_ids, ii:end) + delta_now;
if ii + 1 <= size(x, 2)
    x(leg_ids, ii + 1:end) = x(leg_ids, ii + 1:end) + delta_future;
end
end

function x = apply_aligned_offset(x, ii, leg_ids, delta)
x(leg_ids, ii:end) = x(leg_ids, ii:end) + delta;
end

function joint = solve_joint_trajectory(x0, y0, z0, xb, yb, zb)
robot = robot3D_description;
joint = zeros(size(x0, 2), 18);
for i = 1:size(x0, 2)
    for leg = 1:6
        Target.R = eye(3);
        Target.p = [x0(leg, i); y0(leg, i); z0(leg, i)];
        robot(1).p = [xb(i); yb(i); zb(i)];
        c_id = [1 + 3 * leg, 1];
        robot = ik_collision(robot, Target, c_id);
        for jj = 1:3
            joint(i, jj + 3 * leg - 3) = robot(jj + 3 * leg - 2).q;
        end
    end
end
end

function [learned_mat_path, replay_launch_info] = run_ditch_half_generate_replay(cfg, options, export_meta)
if nargin < 1 || isempty(cfg)
    error('hexapod_compare_trajectory:MissingConfig', 'ditch_half_generate_replay 需要 case 配置。');
end
if nargin < 2 || isempty(options)
    options = struct();
end
if nargin < 3 || isempty(export_meta)
    export_meta = struct();
end

learned_mat_path = invoke_ditch_half_generator(cfg.script_path, export_meta);
fprintf('[ditch_half_mid] 中间轨迹生成完成，准备重启 CoppeliaSim 执行回放...\n');
replay_launch_info = hexapod_compare_runtime('restart_coppeliasim_for_scene', cfg.scene_name, options);
fprintf('[ditch_half_mid] 回放场景就绪: %s\n', replay_launch_info.scene_path);
if replay_launch_info.restart_performed
    fprintf('[ditch_half_mid] 回放启动等待时间: %.2f s\n', replay_launch_info.startup_wait_sec);
end
end

function frame_count = probe_ditch_half_generation_frame_count(script_path)
if nargin < 1 || isempty(script_path)
    cases = hexapod_compare_registry('cases');
    match = strcmp({cases.case_id}, 'ditch_half_mid');
    script_path = cases(find(match, 1, 'first')).script_path;
end
if ~exist(script_path, 'file')
    error('hexapod_compare_trajectory:ScriptNotFound', '未找到脚本: %s', script_path);
end
base_path = fullfile(fileparts(script_path), 'export_data', 'xyz_base.mat');
if ~exist(base_path, 'file')
    error('hexapod_compare_trajectory:BasePathNotFound', '未找到深沟中间版基础轨迹: %s', base_path);
end
data = load(base_path, 'xq');
frame_count = numel(data.xq);
end

function learned_mat_path = invoke_ditch_half_generator(script_path, export_meta)
if nargin < 1 || isempty(script_path)
    error('hexapod_compare_trajectory:MissingScriptPath', '必须提供深沟中间版生成脚本路径。');
end
if nargin < 2 || isempty(export_meta)
    export_meta = struct();
end
if ~exist(script_path, 'file')
    error('hexapod_compare_trajectory:ScriptNotFound', '未找到脚本: %s', script_path);
end
[script_dir, function_name] = fileparts(script_path);
if isempty(which(function_name)) || ~strcmp(which(function_name), script_path)
    addpath(script_dir, '-begin');
end
generator_fn = str2func(function_name);
learned_mat_path = generator_fn(export_meta);
if isempty(learned_mat_path) || exist(learned_mat_path, 'file') ~= 2
    error('hexapod_compare_trajectory:OutputNotFound', '中间版生成脚本执行后未生成轨迹文件: %s', string(learned_mat_path));
end
end

function export_meta = apply_launch_info(export_meta, launch_info)
if nargin < 1 || isempty(export_meta)
    export_meta = struct();
end
if nargin < 2 || isempty(launch_info)
    return;
end
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

function bootstrap_setup_paths()
project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
setup_dir = fullfile(project_root, 'lib', 'setup');
current_paths = string(strsplit(path, pathsep));
if ~any(strcmp(current_paths, string(setup_dir)))
    addpath(setup_dir);
end
hexapod_setup_paths();
end
