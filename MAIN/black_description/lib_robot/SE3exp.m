function [p2,R2]=SE3exp(robot,j,dt)
norm_w=norm(robot(j).w);
if norm_w<eps
    p2=robot(j).p+dt*robot(j).vo;
    R2=robot(j).R;
else
    th=norm_w*dt;
    wn=robot(j).w/norm_w;
    vo=robot(j).vo/norm_w;
    rot=rodrigues(wn,th);
    p2=rot*robot(j).p+(eye(3)-rot)*cross(wn,vo)+wn*wn'*vo*th;
    R2=rot*robot(j).R;
end