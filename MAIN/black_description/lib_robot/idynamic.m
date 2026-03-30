function[f,tao,robot]=idynamic(robot,j)
if j==0
    f=[0 0 0]';
    tao=[0 0 0]';
    return;
end

%此处可浮动基切换，若修改为浮动基，将标志全标1;固定基基座重力项被抵消
%对于固定基，初始连杆质量应设置得极大；
if j==1
    gravity_flag=1;
else
    gravity_flag=1;
end

%
c=robot(j).R*robot(j).c+robot(j).p;
I=robot(j).R*robot(j).I*robot(j).R';
c_hat=hat3(c);
I=I+robot(j).m*(c_hat*c_hat');
P=robot(j).m*(robot(j).vo+cross(robot(j).w,c));
L=robot(j).m*cross(c,robot(j).vo)+I*robot(j).w;
f0=robot(j).m*(robot(j).dvo+cross(robot(j).dw,c)+gravity_flag*[0;0;9.8])...
    +cross(robot(j).w,P);
tao0=robot(j).m*cross(c,robot(j).dvo+gravity_flag*[0;0;9.8])+I*robot(j).dw...
    +cross(robot(j).vo,P)+cross(robot(j).w,L);
[f1,tao1,robot]=idynamic(robot,robot(j).child);
f=f0+f1;
tao=tao0+tao1;
if j~=1
    robot(j).u=robot(j).sv'*f+robot(j).sw'*tao;
end
[f2,tao2,robot]=idynamic(robot,robot(j).sister);
f=f+f2;
tao=tao+tao2;
% f;
