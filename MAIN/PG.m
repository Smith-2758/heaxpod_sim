function [Joint, Pitch] = PG(pattern)
rad2deg=180/pi;
num=length(pattern);
step_time=0.005;
export_data_dir = fullfile(fileparts(mfilename('fullpath')), '6leg_motion', 'export_data');
Joint=cell(num,1);
Pitch=cell(num,1);
robot=robot3D_description;
global turn_flag;
step_time=0.005;
update_matrix=[eye(15) zeros(15,8);
    zeros(8,15) zeros(8,8)];
update_matrix(22,16)=1;
update_matrix(17,17)=1;
update_matrix(16,18)=1;
update_matrix(18,19)=1;
update_matrix(23,20)=1;
update_matrix(20,21)=1;
update_matrix(19,22)=1;
update_matrix(21,23)=1;
for ii=1:num
    motion=pattern{ii};
    switch motion
        case 'walk'
            period_time=2;
            Joint{ii} = walk(period_time,step_time);
        case 'climb2wall'
            % b=load('joint1.mat');
            b = load(fullfile(export_data_dir, 'walk3step_high.mat'));
            Joint{ii} =b.joint;
        case 'climbing'
            % b=load('joint3_1.mat');
            b = load(fullfile(export_data_dir, 'origin', 'dais3step.mat'));%_2
            Joint{ii} =b.joint;
        case 'Legstretch'
            period_time=1;
             Joint{ii}=hello1(01,period_time,step_time);
        case 'slope'  %% 15度斜坡地形
            b = load(fullfile(export_data_dir, 'walk_slope.mat'));
            Joint{ii} = b.joint;
            if isfield(b, 'pitch0')
                Pitch{ii} = b.pitch0;
            end
        case 'ditch'  %% 深沟地形（50cm宽，50cm深）
            b = load(fullfile(export_data_dir, 'walk_ditch.mat'));
            Joint{ii} = b.joint;
%         case 'passive_front_fall'
%             period_time=1;
%             Joint{ii}=fall_protection_black(1,period_time,step_time);
%         case 'passive_back_fall'
%             period_time=1;
%             Joint{ii} = fall_protection_black(2,period_time,step_time);
%         case 'passive_right_front_fall'
%             period_time=1.5;
%             Joint{ii}=fall_protection_black(4,period_time,step_time);
%         case 'passive_right_back_fall'
%             period_time=1.5;
%             Joint{ii}=fall_protection_black(3,period_time,step_time);
%         case 'passive_left_front_fall'
%             period_time=1.5;
%             Joint{ii}=fall_protection_black(6,period_time,step_time);
%         case 'passive_left_back_fall'
%             period_time=1.5;
%             Joint{ii}=fall_protection_black(5,period_time,step_time);
%         case 'active_front_fall'
%         case 'active_back_fall'
%         case 'active_right_front_fall'
%         case 'active_right_back_fall'
%         case 'front_stand'
%             period_time=2;
%             Joint{ii}=rise_up_black(1,period_time,step_time);
%         case 'back_stand'
%             period_time=2;
%             Joint{ii}=rise_up_black(2,period_time,step_time);
%         case 'right_front_stand'
%             period_time=2;
%             Joint{ii}=rise_up_black(4,period_time,step_time);
%         case 'right_back_stand'
%             period_time=2;
%             Joint{ii}=rise_up_black(3,period_time,step_time);
%         case 'left_front_stand'
%             period_time=2;
%             Joint{ii}=rise_up_black(6,period_time,step_time);
%         case 'left_back_stand'
%             period_time=2;
%             Joint{ii}=rise_up_black(5,period_time,step_time);
%         case 'crawl'
%             period_time=3;
%             Joint{ii}=crawl_originplus_black(1,period_time,step_time);
%         case 'low_crawl'
%             period_time=2;
%             Joint{ii}=LowCrawl_ljh_black(period_time,step_time);
%         case 'walk'
%             Joint{ii}=walk_black;
%         case 'walk&control'
%             walk_TPC();
%             return
%         case 'roll'
%             period_time=2.4;
%             Joint{ii} = roll_black(flag,period_time,step_time);
%         case 'back_roll'
%             period_time=3;
%             Joint{ii} = back_roll_black(flag,period_time,step_time);
%         case 'stand_roll'
%             period_time=3.5;
%             Joint{ii} = stand2roll(flag,period_time,step_time);
%         case 'stand_back_roll'
%             period_time=3.5;
%             Joint{ii} = stand2back_roll(flag,period_time,step_time);
%         case 'roll2roll'
%             period_time=2;
%             Joint_1 = roll2roll(flag,period_time,step_time);
%             if turn_flag
%                 Joint{ii}=Joint_1;
%             else
%                 Joint{ii}=mirror_operation(Joint_1);
%             end
%             
%         case 'crawl_stand'
%             period_time=3;
%             Joint{ii}=crawl2rise_up_black(flag,period_time,step_time);
%         case 'low_crawl_stand'
%             period_time=2;
%             Joint{ii}=lowcrawl2rise_up_black(period_time,step_time);
%         case 'read_offline_data'
%             run_offfline_data();
%             return
%         case 'read_opt_data'
%             Joint{ii}=read_opt_data();
%         case 'stand_jump'
%             period_time=2;
%             Joint{ii}=stand2jump(flag,period_time,step_time);
%         case 'jump'
%             Joint{ii}=jump_black();
%         case 'fast_rise'
%             period_time=2;
%             Joint{ii} = rise_up_fast(flag,period_time,step_time);
%         case 'stand_crawl'
%             period_time=2;
%             Joint{ii} = stand2crawl(flag,period_time,step_time);
%         case 'rise2sit'
%             Joint{ii}=rise2sit(step_time);
%         case 'turn_over'
%             period_time=2;
%             Joint{ii} = right_roll_black(flag,period_time,step_time);
%         case 'change'
%             period_time=2;
%             Joint{ii} = change_roll2roll(flag,period_time,step_time);
%         case 'any_position'
%             period_time=2;
%             Joint{ii} = anyposition(period_time,step_time);
%           
    end
    [n_r,n_col]=size(Joint{ii});
%     if n_col~=23
%         Joint{ii}=[Joint{ii} zeros(n_r,2)]*update_matrix;
%     end
    if ii~=1
        if norm(Joint{ii-1}(end,:)-Joint{ii}(1,:))>1e-5
            errjoint=num2str(find((Joint{ii-1}(end,:)-Joint{ii}(1,:))>1e-5));
            prompt=['所要求的动作在 ',errjoint, ' 关节包含不连续轨迹，是否使用插值过渡 ? Y/N [else=N]\n'];
            str=input(prompt,'s');
            if str=='Y'
                Joint_temp=spline_start2end(Joint{ii-1}(end,:),Joint{ii}(1,:),3,step_time,0.5)*rad2deg;
                Joint{ii}=[Joint_temp;Joint{ii}];
                fprintf('插值完成')
                
            end
        end
    end
end
end


