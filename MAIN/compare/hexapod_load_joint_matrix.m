function joint = hexapod_load_joint_matrix(mat_path)
if ~exist(mat_path, 'file')
    error('hexapod_load_joint_matrix:FileNotFound', '未找到轨迹文件: %s', mat_path);
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

error('hexapod_load_joint_matrix:NoJointData', '文件中未找到可用的 18 列关节轨迹: %s', mat_path);
end

function joint = normalize_joint(candidate)
if iscell(candidate)
    if isempty(candidate)
        error('hexapod_load_joint_matrix:EmptyCell', '关节轨迹 cell 为空。');
    end
    candidate = candidate{1};
end
joint = double(candidate);
if size(joint, 2) ~= 18
    error('hexapod_load_joint_matrix:InvalidShape', '关节轨迹必须是 N x 18，当前大小为 %d x %d。', size(joint,1), size(joint,2));
end
end
