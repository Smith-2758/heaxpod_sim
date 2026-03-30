function robot=ik_collision(robot,Target,c_id)
% Joint_MAX = [ 180    0,   18,  90, -3,    104, 14,    0,  23,  90, -3,    103, 27,    80, -0,   3,    90,  5,    180, 128,    90,  97, 180, 128]'/180*pi;
% Joint_MIN = [-180    0, -23, -60, -135, -74, -21,     0,  -18, -60, -135, -74, -12,   -83, -50, -3,   -90, -107, -120, 0  ,   -90, -5, -134, 0  ]'/180*pi;
Joint_MIN        =  [  0               -80               -90               -120              -80               -90               -120               -80              -90              -120              -80               -90               -120              -80               -90               -120              -80               -90               -120     ]/180*pi;
Joint_MAX        =  [  0               80                90                0                 80                90                0                  80               90               0                 80                90                0                 80                90                0                 80                90                0        ]/180*pi;
%     for ii = 1:18
%         if (mod(ii - 1, 3) == 0&&ii>1)
%             Joint_MIN(ii)     = -90/180*pi;
%             Joint_MAX(ii)    = -90/180*pi;
%         end
%     end
% num_joint=length(robot)-1;
lambda=0.08;
robot=fkinematic(robot,1);
robot=fk_collision(robot);
route=findroute(robot,c_id(1));


for n=1:50
    J=calculate_jacobian(robot,route,c_id(2));
    rel.p=robot(c_id(1)).collision(c_id(2)).p;
    rel.R=robot(c_id(1)).R;
    
    err=calculate_err(Target,rel);
    if norm(err)<1e-6
        robot=fkinematic(robot,1);
        robot=fk_collision(robot);
        return
    end
    
    dq=J'*(J*J'+lambda^2*eye(6))^(-1)*err;

    for nn=1:length(route)
        j=route(nn);
        robot(j).q=robot(j).q+dq(nn);
        if robot(j).q>=Joint_MAX(j)
           robot(j).q=Joint_MAX(j);
        end
        if robot(j).q<=Joint_MIN(j)
           robot(j).q=Joint_MIN(j);
        end
    end
    robot=fkinematic(robot,1);
    robot=fk_collision(robot);
end
end