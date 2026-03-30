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
    end
    
    methods
        function vrep = MatlabVrep(control_time)
            vrep.Joint_Num = 18;
            vrep.Control_Time = control_time;
            vrep.Joint_Name = cell(1,vrep.Joint_Num);
            vrep.Joint_Name = {...
                {'Rleg1_joint1'},{'Rleg1_joint2'},{'Rleg1_joint3'},...%����1
                {'Rleg2_joint1'},{'Rleg2_joint2'},{'Rleg2_joint3'},...%����2
                {'Rleg3_joint1'},{'Rleg3_joint2'},{'Rleg3_joint3'},...%����3
                {'Lleg1_joint1'},{'Lleg1_joint2'},{'Lleg1_joint3'},...%����1
                {'Lleg2_joint1'},{'Lleg2_joint2'},{'Lleg2_joint3'},...%����2
                {'Lleg3_joint1'},{'Lleg3_joint2'},{'Lleg3_joint3'},...%����3
                };
            vrep.Joint = zeros(1,vrep.Joint_Num);
            vrep.Joint_Handle = zeros(1,vrep.Joint_Num);
            
            vrep.Body_Name = 'body';
            vrep.Body_Handle = 64;
            
            vrep.Force_sensor_Num=6;
            vrep.Force_sensor_Name=cell(1,vrep.Force_sensor_Num);
            vrep.Force_sensor_Name={{'Force_sensorR1'},{'Force_sensorR2'},{'Force_sensorR3'},...
                                    {'Force_sensorL1'},{'Force_sensorL2'},{'Force_sensorL3'}};
            
            vrep.Port = 19997;
            vrep.Main = remApi('remoteApi');
            
            vrep.CoM_Name = 'centerOfMassVisualizer';
            vrep.CoM_Handle = 0;
            
        end
        
        function mvrep = init(vrep)
            mvrep = vrep;
            mvrep.Main.simxFinish(-1);
            mvrep.ClientID = mvrep.Main.simxStart('127.0.0.1',mvrep.Port,true,true,5000,mvrep.Control_Time);
            fprintf('ClientID =  %d\n',mvrep.ClientID);
            for i =1:1:mvrep.Joint_Num
                joint_name = mvrep.Joint_Name{i};
                if i>0
                    joint_name = joint_name{1};
                end
                [~,mvrep.Joint_Handle(i)] = mvrep.Main.simxGetObjectHandle(mvrep.ClientID,joint_name,mvrep.Main.simx_opmode_oneshot_wait);
                
                mvrep.set_pid(i,200000000000000000.0,0.875,0.0000,0.00);
                
                mvrep.Joint = deg2rad([ 0.637545278259961	0.0450419165267497	-0.155111380092159	0.230034597310950	0.122401063594318	-0.171622785812620	-0.269907585133548	0.523756779999759	-0.429272560193322	-0.614965135391140	0.0496637629143356	-0.177494606701057	-0.262004632871993	0.113967877539100	-0.153962259870747	0.302669876095158	0.538170378463627	-0.423694761759906
%                     0 0 9.85  -20.08  10.23  0,...%����
%                     0 0 9.85  -20.08  10.23  0,...%����
%                     0,0,0,...%��
%                     0,0,0,0,...%����
%                     0,0,0,0%����
                    ]);
                mvrep.set_joint();
                fprintf('Joint Handle %d = %d\n',i,mvrep.Joint_Handle(i));
            end
%             mvrep.set_pid(14,999999,1,0.0000,0.00);
%             mvrep.set_pid(14,500,1,0.0000,0.00);
            mvrep.get_body_p();
            
            [~,mvrep.Body_Handle] = mvrep.Main.simxGetObjectHandle(mvrep.ClientID,mvrep.Body_Name,mvrep.Main.simx_opmode_oneshot_wait);
            fprintf('body Handle = %d\n',mvrep.Body_Handle);
            [~,mvrep.UpBody_Handle] = mvrep.Main.simxGetObjectHandle(mvrep.ClientID,mvrep.UpBody_Name,mvrep.Main.simx_opmode_oneshot_wait);
            fprintf('Upbody Handle = %d\n',mvrep.UpBody_Handle);
            
            
            for ii=1:mvrep.Force_sensor_Num
                force_sensor_name = mvrep.Force_sensor_Name{ii}{1};
                [~,mvrep.Force_sensor_Handle(ii)] = mvrep.Main.simxGetObjectHandle(mvrep.ClientID,force_sensor_name,mvrep.Main.simx_opmode_oneshot_wait);
                fprintf('Force sensor Handle = %d\n',mvrep.Force_sensor_Handle(ii));
            end
            [~,mvrep.CoM_Handle] = mvrep.Main.simxGetObjectHandle(mvrep.ClientID,mvrep.CoM_Name,mvrep.Main.simx_opmode_oneshot_wait);
            fprintf('CoM Handle = %d\n',mvrep.CoM_Handle);
        end
        
        function [] = go(vrep)
            vrep.Main.simxSynchronous(vrep.ClientID,true);
            vrep.Main.simxStartSimulation(vrep.ClientID,vrep.Main.simx_opmode_blocking);
            vrep.trigger();
        end
        
        function [] = trigger(vrep)
            vrep.Main.simxSynchronousTrigger(vrep.ClientID);
        end
        
        function [] = pause(vrep)
            vrep.Main.simxPauseSimulation(vrep.ClientID,vrep.Main.simx_opmode_blocking);
        end
        
        function [] = stop(vrep)
            % stop the simulation:
            vrep.Main.simxStopSimulation(vrep.ClientID,vrep.Main.simx_opmode_blocking);
            % Now close the connection to V-REP:
            vrep.Main.simxFinish(vrep.ClientID);
        end
        
        function [] = set_joint(vrep)
            for i=1:1:vrep.Joint_Num
                vrep.Main.simxSetJointTargetPosition(vrep.ClientID,vrep.Joint_Handle(i),vrep.Joint(i),vrep.Main.simx_opmode_oneshot);
            end
        end
        
        function [] = set_joint_initial(vrep,joint_initial)
            for i=1:1:vrep.Joint_Num
                vrep.Main.simxSetJointPosition(vrep.ClientID,vrep.Joint_Handle(i),joint_initial(i),vrep.Main.simx_opmode_oneshot);
            end
        end
        
        function [] = keep_time(vrep)
            vrep.Main.simxGetPingTime(vrep.ClientID)
        end
        
        function [] = set_pid(vrep,joint_num,torque_limit,p,i,d)
            vrep.Main.simxSetJointForce(vrep.ClientID,vrep.Joint_Handle(joint_num),torque_limit,vrep.Main.simx_opmode_oneshot);
            vrep.Main.simxSetObjectFloatParameter(vrep.ClientID,vrep.Joint_Handle(joint_num),2002,p,vrep.Main.simx_opmode_oneshot);
            vrep.Main.simxSetObjectFloatParameter(vrep.ClientID,vrep.Joint_Handle(joint_num),2003,i,vrep.Main.simx_opmode_oneshot);
            vrep.Main.simxSetObjectFloatParameter(vrep.ClientID,vrep.Joint_Handle(joint_num),2004,d,vrep.Main.simx_opmode_oneshot);
        end
        
        function [] = set_body_o(vrep,eulerAngles)
            vrep.Main.simxSetObjectOrientation(vrep.ClientID, vrep.Body_Handle, -1,eulerAngles,vrep.Main.simx_opmode_oneshot);
        end
        
        function [] = set_body_p(vrep,position)
            vrep.Main.simxSetObjectPosition(vrep.ClientID, vrep.Body_Handle, -1,position,vrep.Main.simx_opmode_oneshot);
        end
            
        function [body_v,ang_v] = get_body_v(vrep)
            [~,body_v,ang_v]= vrep.Main.simxGetObjectVelocity(vrep.ClientID, vrep.Body_Handle, vrep.Main.simx_opmode_oneshot);
        end
        
        function body_p = get_body_p(vrep)
            [~,body_p]= vrep.Main.simxGetObjectPosition(vrep.ClientID, vrep.Body_Handle, -1, vrep.Main.simx_opmode_oneshot);
        end
        
        function body_eul=get_body_eul(vrep)
            [~,body_eul] = vrep.Main.simxGetObjectOrientation(vrep.ClientID, vrep.Body_Handle, -1, vrep.Main.simx_opmode_oneshot);
        end
        
        function q_rel = get_Joint_position(vrep)
            q_rel = zeros(1,vrep.Joint_Num);
            for i=1:1:vrep.Joint_Num
                [~,position] = vrep.Main.simxGetJointPosition(vrep.ClientID,vrep.Joint_Handle(i),vrep.Main.simx_opmode_oneshot);
                q_rel(i) = position;
            end
        end
        
        function [F,tao]=get_force_sensor(vrep)
            F=zeros(2,3);
            tao=zeros(2,3);
            for ii=1:vrep.Force_sensor_Num
                [~,~,forceVector,torqueVector]= vrep.Main.simxReadForceSensor(vrep.ClientID,vrep.Force_sensor_Handle(ii),vrep.Main.simx_opmode_oneshot);
                F(ii,:)=forceVector;
                tao(ii,:)=torqueVector;
            end
        end
        
        function p_CoM=get_CoM_position(vrep)
            [~,p_CoM]= vrep.Main.simxGetObjectPosition(vrep.ClientID, vrep.CoM_Handle, -1, vrep.Main.simx_opmode_oneshot);
        end
        
        function [] = Push(vrep,forceX,forceY,forceZ)
            [~,ore] = vrep.Main.simxGetObjectOrientation(vrep.ClientID,vrep.UpBody_Handle,-1,vrep.Main.simx_opmode_oneshot);
            R = eul2rotm(ore,'xyz');
            wF = [forceX,forceY,forceZ]';
            bF = R'*wF;
            
            vrep.Main.simxSetFloatSignal(vrep.ClientID,'forceX',bF(1),vrep.Main.simx_opmode_oneshot);
            vrep.Main.simxSetFloatSignal(vrep.ClientID,'forceY',bF(2),vrep.Main.simx_opmode_oneshot);
            vrep.Main.simxSetFloatSignal(vrep.ClientID,'forceZ',bF(3),vrep.Main.simx_opmode_oneshot);
        end
        
        function [] = Stop_Push(vrep)
            vrep.Main.simxSetFloatSignal(vrep.ClientID,'forceX',0,vrep.Main.simx_opmode_oneshot);
            vrep.Main.simxSetFloatSignal(vrep.ClientID,'forceY',0,vrep.Main.simx_opmode_oneshot);
            vrep.Main.simxSetFloatSignal(vrep.ClientID,'forceZ',0,vrep.Main.simx_opmode_oneshot);
        end
        
        function f=get_Joint_force(vrep)
            f = zeros(1,vrep.Joint_Num);
            for i=1:1:vrep.Joint_Num
                [~,force] = vrep.Main.simxGetJointForce(vrep.ClientID,vrep.Joint_Handle(i),vrep.Main.simx_opmode_oneshot);
                f(i) = force;
            end
        end
        function tau=GetJointForce(vrep)
            tau=zeros(vrep.Joint_Num,1);
            for i=1:vrep.Joint_Num
                [~,tau(i)] = vrep.Main.simxGetJointForce(vrep.ClientID,vrep.Joint_Handle(i),vrep.Main.simx_opmode_oneshot);
            end
        end 
    end
    
end


