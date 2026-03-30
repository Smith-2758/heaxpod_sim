function robot=ikinematic(robot,id,Target)
lambda=0.08;
robot=fkinematic(robot,1);
route=findroute(robot,id);
for n=1:10
    J=calculate_jacobian(robot,route);
    err=calculate_err(Target,robot(id));
    if norm(err)<1e-6
        return
    end
%     J\err
    dq=J'*(J*J'+lambda^2*eye(6))^(-1)*err;
    for nn=1:length(route)
        j=route(nn);
        robot(j).q=robot(j).q+dq(nn);
    end
    robot=fkinematic(robot,1);
end
% q_ref=robot(route).q;