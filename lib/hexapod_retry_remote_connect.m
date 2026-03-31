function [client_id, attempts] = hexapod_retry_remote_connect(connect_fn, timeout_sec, poll_sec)
if nargin < 2 || isempty(timeout_sec)
    timeout_sec = 30;
end
if nargin < 3 || isempty(poll_sec)
    poll_sec = 0.5;
end

start_tic = tic;
attempts = 0;
client_id = -1;

while toc(start_tic) <= timeout_sec
    attempts = attempts + 1;
    try
        client_id = connect_fn();
    catch
        client_id = -1;
    end

    if isnumeric(client_id) && isscalar(client_id) && client_id >= 0
        return;
    end

    if poll_sec > 0
        pause(poll_sec);
    end
end

error('hexapod_retry_remote_connect:Timeout', ...
    '在 %.1f 秒内未建立 remoteApi 连接。最后 ClientID=%d。', ...
    timeout_sec, client_id);
end
