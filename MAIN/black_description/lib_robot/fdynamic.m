function robot=fdynamic(robot,u,dt)
nDoF=length(robot)-1+6;
A=zeros(nDoF,nDoF);
b=InvDyn(robot,0);
for n=1:nDoF
    A(:,n)=InvDyn(robot,n)-b;
end
ddq=A\(-b+u);
robot(1).dvo=ddq(1:3);
robot(1).dw=ddq(4:6);
robot(1).vo=robot(1).vo+dt*robot(1).dvo;
robot(1).w=robot(1).w+dt*robot(1).dw;
% robot(1).p=robot(1).p+dt*robot(1).vo;
[p2,R2]=SE3exp(robot,1,dt);
robot(1).p=p2;
robot(1).R=R2;
% robot(1).vo=robot(1).vo+dt*robot(1).dvo;
% robot(1).w=robot(1).w+dt*robot(1).dw;
% robot(1).p=robot(1).p+dt*robot(1).vo;
% robot(1).R=(dt*hat3(robot(1).w)+eye(3))*robot(1).R;
for j=1:length(robot)-1
    
    robot(j+1).ddq=ddq(j+6);
    robot(j+1).dq=robot(j+1).dq+dt*robot(j+1).ddq;
    robot(j+1).q=robot(j+1).q+dt*robot(j+1).dq;
end