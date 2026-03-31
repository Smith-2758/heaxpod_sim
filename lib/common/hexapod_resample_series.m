function data_out = hexapod_resample_series(data_in, target_count, sample_dim)
if nargin < 3 || isempty(sample_dim)
    sample_dim = 1;
end
if nargin < 2 || isempty(target_count)
    data_out = double(data_in);
    return;
end
if ~isscalar(target_count) || target_count < 2 || target_count ~= floor(target_count)
    error('hexapod_resample_series:InvalidTarget', 'target_count 必须是大于等于 2 的整数。');
end

if isempty(data_in)
    data_out = data_in;
    return;
end

data_in = double(data_in);
original_count = size(data_in, sample_dim);
if original_count == target_count
    data_out = data_in;
    return;
end
if original_count < 2
    error('hexapod_resample_series:TooShort', '原始序列长度必须大于等于 2。');
end

work = data_in;
restore_as_column = false;
if isvector(data_in)
    restore_as_column = iscolumn(data_in);
    work = data_in(:).';
    sample_dim = 2;
elseif sample_dim == 1
    work = data_in.';
elseif sample_dim ~= 2
    error('hexapod_resample_series:InvalidDim', 'sample_dim 仅支持 1 或 2。');
end

source_axis = linspace(0, 1, size(work, 2));
target_axis = linspace(0, 1, target_count);
resampled = interp1(source_axis, work.', target_axis, 'pchip').';

if isvector(data_in)
    if restore_as_column
        data_out = resampled.';
    else
        data_out = resampled;
    end
elseif sample_dim == 1
    data_out = resampled.';
else
    data_out = resampled;
end
end
