function robot=all_fkinematic(robot,j)
if j==0
    return;
end
if j~=1
    i=robot(j).mother;    
    %%
    robot(j).p=robot(i).R*robot(j).b+robot(i).p;
    robot(j).R=robot(i).R*rodrigues(robot(j).a*robot(j).q);
    %%
    sw=robot(i).R*robot(j).a;
    sv=cross(robot(j).p,sw);
    robot(j).w=robot(i).w+sw*robot(j).dq;
    robot(j).vo=robot(i).vo+sv*robot(j).dq;
%     test_v=robot(j).vo+cross(robot(j).w,robot(j).p);
    %%
    dsv=cross(robot(i).w,sv)+cross(robot(i).vo,sw);
    dsw=cross(robot(i).w,sw);
    robot(j).dw=robot(i).dw+dsw*robot(j).dq+sw*robot(j).ddq;
    robot(j).dvo=robot(i).dvo+dsv*robot(j).dq+sv*robot(j).ddq;
    robot(j).sw=sw;
    robot(j).sv=sv;
end

robot=all_fkinematic(robot,robot(j).sister);
robot=all_fkinematic(robot,robot(j).child);