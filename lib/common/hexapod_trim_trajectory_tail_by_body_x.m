function [trimmed_joint, trimmed_body_x, trimmed_extra] = hexapod_trim_trajectory_tail_by_body_x(joint, body_x, target_end_x, extra)
if nargin < 4 || isempty(extra)
    extra = struct();
end

body_x_col = body_x(:);
cut_idx = find(body_x_col <= target_end_x, 1, 'last');
if isempty(cut_idx)
    cut_idx = 1;
end

trimmed_joint = joint(1:cut_idx, :);
trimmed_body_x = trim_value(body_x, cut_idx, numel(body_x_col));

trimmed_extra = struct();
extra_fields = fieldnames(extra);
for idx = 1:numel(extra_fields)
    field_name = extra_fields{idx};
    trimmed_extra.(field_name) = trim_value(extra.(field_name), cut_idx, numel(body_x_col));
end
end

function value_out = trim_value(value_in, cut_idx, ref_length)
if isvector(value_in) && numel(value_in) == ref_length
    value_col = value_in(:);
    value_out = value_col(1:cut_idx);
    if isrow(value_in)
        value_out = value_out.';
    end
    return;
end

if ismatrix(value_in)
    if size(value_in, 1) == ref_length
        value_out = value_in(1:cut_idx, :);
        return;
    end
    if size(value_in, 2) == ref_length
        value_out = value_in(:, 1:cut_idx);
        return;
    end
end

value_out = value_in;
end
