classdef MatlabVrep
    %MATLABVREP Summary of this class goes here
    %   Detailed explanation goes here
    %   Data Sequence 0 RLEG1-3 0 LLEG1-3
    properties
        Joint_Num;
        Joint_Name;
        Joint_Handle;
        Joint;
        Port;
        ClientID;
        Control_Time;
        Main;

        Body_Name;
        Body_Handle;
        UpBody_Name;
        UpBody_Handle;

        Force_sensor_Num;
        Force_sensor_Name;
        Force_sensor_Handle;

        CoM;
        CoM_Name;
        CoM_Handle;

        Init_Handle_Timeout_Sec;
        Init_Handle_Poll_Sec;
        Connect_Timeout_Sec;
        Connect_Poll_Sec;
        Close_All_Connections_Before_Init;
    end

    methods
        function vrep = MatlabVrep(control_time, port)
            vrep.Joint_Num = 18;
            vrep.Control_Time = control_time;
            vrep.Joint_Name = cell(1, vrep.Joint_Num);
            vrep.Joint_Name = {...
                {'Rleg1_joint1'}, {'Rleg1_joint2'}, {'Rleg1_joint3'}, ...
                {'Rleg2_joint1'}, {'Rleg2_joint2'}, {'Rleg2_joint3'}, ...
                {'Rleg3_joint1'}, {'Rleg3_joint2'}, {'Rleg3_joint3'}, ...
                {'Lleg1_joint1'}, {'Lleg1_joint2'}, {'Lleg1_joint3'}, ...
                {'Lleg2_joint1'}, {'Lleg2_joint2'}, {'Lleg2_joint3'}, ...
                {'Lleg3_joint1'}, {'Lleg3_joint2'}, {'Lleg3_joint3'} ...
            };
            vrep.Joint = zeros(1, vrep.Joint_Num);
            vrep.Joint_Handle = zeros(1, vrep.Joint_Num);

            vrep.Body_Name = 'body';
            vrep.Body_Handle = 64;
            vrep.UpBody_Name = '';
            vrep.UpBody_Handle = 0;

            vrep.Force_sensor_Num = 6;
            vrep.Force_sensor_Name = cell(1, vrep.Force_sensor_Num);
            vrep.Force_sensor_Name = {{'Force_sensorR1'}, {'Force_sensorR2'}, {'Force_sensorR3'}, ...
                                      {'Force_sensorL1'}, {'Force_sensorL2'}, {'Force_sensorL3'}};
            vrep.Force_sensor_Handle = zeros(1, vrep.Force_sensor_Num);

            if nargin < 2 || isempty(port)
                port = 19997;
            end
            vrep.Port = port;
            vrep.Main = remApi('remoteApi');

            vrep.CoM_Name = 'centerOfMassVisualizer';
            vrep.CoM_Handle = 0;

            vrep.Init_Handle_Timeout_Sec = 60;
            vrep.Init_Handle_Poll_Sec = 0.5;
            vrep.Connect_Timeout_Sec = 30;
            vrep.Connect_Poll_Sec = 0.5;
            vrep.Close_All_Connections_Before_Init = false;
        end

        function mvrep = init(vrep)
            mvrep = vrep;

            % 无条件关闭残留连接，避免端口占用导致重连失败
            fprintf('[MatlabVrep] 正在关闭 remoteApi 库中的残留连接...\n');
            mvrep.Main.simxFinish(-1);

            fprintf('[MatlabVrep] 正在连接 remoteApi 127.0.0.1:%d...\n', mvrep.Port);
            connect_tic = tic;
            [mvrep.ClientID, connect_attempts] = hexapod_retry_remote_connect( ...
                @() mvrep.Main.simxStart('127.0.0.1', mvrep.Port, true, true, 5000, mvrep.Control_Time), ...
                mvrep.Connect_Timeout_Sec, mvrep.Connect_Poll_Sec);
            fprintf('[MatlabVrep] remoteApi 已连接，ClientID=%d，耗时 %.2f s，attempts=%d\n', ...
                mvrep.ClientID, toc(connect_tic), connect_attempts);

            mvrep.Joint = mvrep.default_joint_targets();

            fprintf('[MatlabVrep] 正在获取 %d 个关节句柄...\n', mvrep.Joint_Num);
            joint_tic = tic;
            for i = 1:mvrep.Joint_Num
                joint_name = mvrep.Joint_Name{i}{1};
                [mvrep.Joint_Handle(i), attempts] = hexapod_retry_remote_handle_lookup( ...
                    @(object_name) mvrep.Main.simxGetObjectHandle(mvrep.ClientID, object_name, mvrep.Main.simx_opmode_oneshot_wait), ...
                    joint_name, mvrep.Init_Handle_Timeout_Sec, mvrep.Init_Handle_Poll_Sec);
                fprintf('Joint Handle %d = %d (%s, attempts=%d)\n', i, mvrep.Joint_Handle(i), joint_name, attempts);
            end
            fprintf('[MatlabVrep] 关节句柄获取完成，耗时 %.2f s\n', toc(joint_tic));

            pid_tic = tic;
            for i = 1:mvrep.Joint_Num
                mvrep.set_pid(i, 200000000000000000.0, 0.875, 0.0000, 0.00);
            end
            mvrep.set_joint();
            fprintf('[MatlabVrep] 关节 PID 与初始目标已下发，耗时 %.2f s\n', toc(pid_tic));

            body_tic = tic;
            [mvrep.Body_Handle, body_attempts] = hexapod_retry_remote_handle_lookup( ...
                @(object_name) mvrep.Main.simxGetObjectHandle(mvrep.ClientID, object_name, mvrep.Main.simx_opmode_oneshot_wait), ...
                mvrep.Body_Name, mvrep.Init_Handle_Timeout_Sec, mvrep.Init_Handle_Poll_Sec);
            fprintf('body Handle = %d (attempts=%d)\n', mvrep.Body_Handle, body_attempts);

            if ~isempty(mvrep.UpBody_Name)
                [mvrep.UpBody_Handle, upbody_attempts] = hexapod_retry_remote_handle_lookup( ...
                    @(object_name) mvrep.Main.simxGetObjectHandle(mvrep.ClientID, object_name, mvrep.Main.simx_opmode_oneshot_wait), ...
                    mvrep.UpBody_Name, mvrep.Init_Handle_Timeout_Sec, mvrep.Init_Handle_Poll_Sec);
                fprintf('Upbody Handle = %d (attempts=%d)\n', mvrep.UpBody_Handle, upbody_attempts);
            else
                fprintf('Upbody Handle = 0 (skip: UpBody_Name 为空)\n');
            end

            for ii = 1:mvrep.Force_sensor_Num
                force_sensor_name = mvrep.Force_sensor_Name{ii}{1};
                [mvrep.Force_sensor_Handle(ii), attempts] = hexapod_retry_remote_handle_lookup( ...
                    @(object_name) mvrep.Main.simxGetObjectHandle(mvrep.ClientID, object_name, mvrep.Main.simx_opmode_oneshot_wait), ...
                    force_sensor_name, mvrep.Init_Handle_Timeout_Sec, mvrep.Init_Handle_Poll_Sec);
                fprintf('Force sensor Handle %d = %d (%s, attempts=%d)\n', ii, mvrep.Force_sensor_Handle(ii), force_sensor_name, attempts);
            end

            if ~isempty(mvrep.CoM_Name)
                try
                    [mvrep.CoM_Handle, com_attempts] = hexapod_retry_remote_handle_lookup( ...
                        @(object_name) mvrep.Main.simxGetObjectHandle(mvrep.ClientID, object_name, mvrep.Main.simx_opmode_oneshot_wait), ...
                        mvrep.CoM_Name, mvrep.Init_Handle_Timeout_Sec, mvrep.Init_Handle_Poll_Sec);
                    fprintf('CoM Handle = %d (attempts=%d)\n', mvrep.CoM_Handle, com_attempts);
                catch ME
                    if strcmp(ME.identifier, 'hexapod_retry_remote_handle_lookup:Timeout')
                        mvrep.CoM_Handle = 0;
                        fprintf('CoM Handle = 0 (skip: optional object %s unavailable)\n', mvrep.CoM_Name);
                    else
                        rethrow(ME);
                    end
                end
            else
                fprintf('CoM Handle = 0 (skip: CoM_Name 为空)\n');
            end
            fprintf('[MatlabVrep] 机身与传感器句柄获取完成，耗时 %.2f s\n', toc(body_tic));
        end

        function [] = go(vrep)
            vrep.Main.simxSynchronous(vrep.ClientID, true);
            vrep.Main.simxStartSimulation(vrep.ClientID, vrep.Main.simx_opmode_blocking);
            vrep.trigger();
        end

        function [] = trigger(vrep)
            vrep.Main.simxSynchronousTrigger(vrep.ClientID);
        end

        function [] = pause(vrep)
            vrep.Main.simxPauseSimulation(vrep.ClientID, vrep.Main.simx_opmode_blocking);
        end

        function [] = stop(vrep)
            vrep.Main.simxStopSimulation(vrep.ClientID, vrep.Main.simx_opmode_blocking);
            pause(0.5);  % 等待 CoppeliaSim 完全停止仿真
            vrep.Main.simxFinish(vrep.ClientID);
        end

        function [] = set_joint(vrep)
            for i = 1:1:vrep.Joint_Num
                vrep.Main.simxSetJointTargetPosition(vrep.ClientID, vrep.Joint_Handle(i), vrep.Joint(i), vrep.Main.simx_opmode_oneshot);
            end
        end

        function [] = set_joint_initial(vrep, joint_initial)
            for i = 1:1:vrep.Joint_Num
                vrep.Main.simxSetJointPosition(vrep.ClientID, vrep.Joint_Handle(i), joint_initial(i), vrep.Main.simx_opmode_oneshot);
            end
        end

        function [] = keep_time(vrep)
            vrep.Main.simxGetPingTime(vrep.ClientID);
        end

        function [] = set_pid(vrep, joint_num, torque_limit, p, i, d)
            vrep.Main.simxSetJointForce(vrep.ClientID, vrep.Joint_Handle(joint_num), torque_limit, vrep.Main.simx_opmode_oneshot);
            vrep.Main.simxSetObjectFloatParameter(vrep.ClientID, vrep.Joint_Handle(joint_num), 2002, p, vrep.Main.simx_opmode_oneshot);
            vrep.Main.simxSetObjectFloatParameter(vrep.ClientID, vrep.Joint_Handle(joint_num), 2003, i, vrep.Main.simx_opmode_oneshot);
            vrep.Main.simxSetObjectFloatParameter(vrep.ClientID, vrep.Joint_Handle(joint_num), 2004, d, vrep.Main.simx_opmode_oneshot);
        end

        function [] = set_body_o(vrep, eulerAngles)
            vrep.Main.simxSetObjectOrientation(vrep.ClientID, vrep.Body_Handle, -1, eulerAngles, vrep.Main.simx_opmode_oneshot);
        end

        function [] = set_body_p(vrep, position)
            vrep.Main.simxSetObjectPosition(vrep.ClientID, vrep.Body_Handle, -1, position, vrep.Main.simx_opmode_oneshot);
        end

        function [body_v, ang_v] = get_body_v(vrep)
            [~, body_v, ang_v] = vrep.Main.simxGetObjectVelocity(vrep.ClientID, vrep.Body_Handle, vrep.Main.simx_opmode_oneshot);
        end

        function body_p = get_body_p(vrep)
            [~, body_p] = vrep.Main.simxGetObjectPosition(vrep.ClientID, vrep.Body_Handle, -1, vrep.Main.simx_opmode_oneshot);
        end

        function body_eul = get_body_eul(vrep)
            [~, body_eul] = vrep.Main.simxGetObjectOrientation(vrep.ClientID, vrep.Body_Handle, -1, vrep.Main.simx_opmode_oneshot);
        end

        function q_rel = get_Joint_position(vrep)
            q_rel = zeros(1, vrep.Joint_Num);
            for i = 1:1:vrep.Joint_Num
                [~, position] = vrep.Main.simxGetJointPosition(vrep.ClientID, vrep.Joint_Handle(i), vrep.Main.simx_opmode_oneshot);
                q_rel(i) = position;
            end
        end

        function [F, tao] = get_force_sensor(vrep)
            F = zeros(2, 3);
            tao = zeros(2, 3);
            for ii = 1:vrep.Force_sensor_Num
                [~, ~, forceVector, torqueVector] = vrep.Main.simxReadForceSensor(vrep.ClientID, vrep.Force_sensor_Handle(ii), vrep.Main.simx_opmode_oneshot);
                F(ii, :) = forceVector;
                tao(ii, :) = torqueVector;
            end
        end

        function p_CoM = get_CoM_position(vrep)
            if isempty(vrep.CoM_Handle) || ~isnumeric(vrep.CoM_Handle) || vrep.CoM_Handle <= 0
                p_CoM = [NaN; NaN; NaN];
                return;
            end
            [~, p_CoM] = vrep.Main.simxGetObjectPosition(vrep.ClientID, vrep.CoM_Handle, -1, vrep.Main.simx_opmode_oneshot);
        end

        function [] = Push(vrep, forceX, forceY, forceZ)
            [~, ore] = vrep.Main.simxGetObjectOrientation(vrep.ClientID, vrep.UpBody_Handle, -1, vrep.Main.simx_opmode_oneshot);
            R = eul2rotm(ore, 'xyz');
            wF = [forceX, forceY, forceZ]';
            bF = R' * wF;

            vrep.Main.simxSetFloatSignal(vrep.ClientID, 'forceX', bF(1), vrep.Main.simx_opmode_oneshot);
            vrep.Main.simxSetFloatSignal(vrep.ClientID, 'forceY', bF(2), vrep.Main.simx_opmode_oneshot);
            vrep.Main.simxSetFloatSignal(vrep.ClientID, 'forceZ', bF(3), vrep.Main.simx_opmode_oneshot);
        end

        function [] = Stop_Push(vrep)
            vrep.Main.simxSetFloatSignal(vrep.ClientID, 'forceX', 0, vrep.Main.simx_opmode_oneshot);
            vrep.Main.simxSetFloatSignal(vrep.ClientID, 'forceY', 0, vrep.Main.simx_opmode_oneshot);
            vrep.Main.simxSetFloatSignal(vrep.ClientID, 'forceZ', 0, vrep.Main.simx_opmode_oneshot);
        end

        function f = get_Joint_force(vrep)
            f = zeros(1, vrep.Joint_Num);
            for i = 1:1:vrep.Joint_Num
                [~, force] = vrep.Main.simxGetJointForce(vrep.ClientID, vrep.Joint_Handle(i), vrep.Main.simx_opmode_oneshot);
                f(i) = force;
            end
        end

        function tau = GetJointForce(vrep)
            tau = zeros(vrep.Joint_Num, 1);
            for i = 1:vrep.Joint_Num
                [~, tau(i)] = vrep.Main.simxGetJointForce(vrep.ClientID, vrep.Joint_Handle(i), vrep.Main.simx_opmode_oneshot);
            end
        end
    end

    methods (Access = private)
        function joint_targets = default_joint_targets(~)
            joint_targets = deg2rad([ ...
                0.637545278259961, 0.0450419165267497, -0.155111380092159, ...
                0.230034597310950, 0.122401063594318, -0.171622785812620, ...
                -0.269907585133548, 0.523756779999759, -0.429272560193322, ...
                -0.614965135391140, 0.0496637629143356, -0.177494606701057, ...
                -0.262004632871993, 0.113967877539100, -0.153962259870747, ...
                0.302669876095158, 0.538170378463627, -0.423694761759906 ...
            ]);
        end
    end
end







