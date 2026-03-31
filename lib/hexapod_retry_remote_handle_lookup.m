function [handle_value, attempts] = hexapod_retry_remote_handle_lookup(fetch_fn, object_name, timeout_sec, poll_sec)
if nargin < 3 || isempty(timeout_sec)
    timeout_sec = 30;
end
if nargin < 4 || isempty(poll_sec)
    poll_sec = 0.5;
end

start_tic = tic;
attempts = 0;
handle_value = 0;
last_ret_code = NaN;
last_error_message = '';

while toc(start_tic) <= timeout_sec
    attempts = attempts + 1;
    try
        [last_ret_code, handle_value] = fetch_fn(object_name);
        last_error_message = '';
    catch ME
        last_ret_code = NaN;
        handle_value = 0;
        last_error_message = ME.message;
    end

    if isequal(last_ret_code, 0) && isnumeric(handle_value) && isscalar(handle_value) && handle_value > 0
        return;
    end

    if poll_sec > 0
        pause(poll_sec);
    end
end

if isempty(last_error_message)
    error('hexapod_retry_remote_handle_lookup:Timeout', ...
        '在 %.1f 秒内未获取到对象 %s 的句柄。最后 ret_code=%s, handle=%g。', ...
        timeout_sec, object_name, num2str(last_ret_code), handle_value);
end
error('hexapod_retry_remote_handle_lookup:Timeout', ...
    '在 %.1f 秒内未获取到对象 %s 的句柄。最后错误: %s', ...
    timeout_sec, object_name, last_error_message);
end
