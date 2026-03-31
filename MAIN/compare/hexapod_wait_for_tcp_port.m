function elapsed_sec = hexapod_wait_for_tcp_port(host, port, timeout_sec)
if nargin < 3 || isempty(timeout_sec)
    timeout_sec = 30;
end
start_tic = tic;
elapsed_sec = NaN;
while toc(start_tic) <= timeout_sec
    if is_tcp_port_open(host, port)
        elapsed_sec = toc(start_tic);
        return;
    end
    pause(0.5);
end
error('hexapod_wait_for_tcp_port:Timeout', '在 %.1f 秒内未检测到 %s:%d 可连接。', timeout_sec, host, port);
end

function tf = is_tcp_port_open(host, port)
tf = false;
socket = [];
try
    socket = java.net.Socket();
    socket.connect(java.net.InetSocketAddress(host, port), 500);
    tf = true;
catch
    tf = false;
end
if ~isempty(socket)
    try
        socket.close();
    catch
    end
end
end
