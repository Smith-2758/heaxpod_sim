function ret=InvDyn(robot,j)
robot(1).dvo=[0 0 0]';
robot(1).dw=[0 0 0]';
if j>=1&&j<=3
    robot(1).dvo(j)=1;
elseif j>=4&&j<=6
    robot(1).dw(j-3)=1;
end
for n=1:length(robot)-1
    if n==j-6
        robot(n+1).ddq=1;
    else
        robot(n+1).ddq=0;
    end
end
robot=all_fkinematic(robot,1);
[f,tao,robot]=idynamic(robot,1);
ret=[f',tao',robot(2:end).u]';
% ret=[f',tao']';
% if isa(ret,'sym')
%     ret=simplify(ret);
% end
% ret;