function joint_out = hexapod_resample_joint_matrix(joint_in, target_total_frames)
if nargin < 2 || isempty(target_total_frames)
    joint_out = double(joint_in);
    return;
end

joint_in = double(joint_in);
if size(joint_in, 2) ~= 18
    error('hexapod_resample_joint_matrix:InvalidShape', 'joint_in 必须是 N x 18。');
end

joint_out = hexapod_resample_series(joint_in, target_total_frames, 1);
joint_out(1, :) = joint_in(1, :);
joint_out(end, :) = joint_in(end, :);
end
