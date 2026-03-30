function robot=fvelocity(robot,j)
if j==0 
    return;
end
if j~=1
    i=robot(j).mother;
    robot(j).v=robot(i).v+cross(robot(i).w,robot(i).R*robot(j).b);
    robot(j).w=robot(i).w+robot(i).R*(robot(j).a*robot(j).dq);
end
robot=fvelocity(robot,robot(j).sister);
robot=fvelocity(robot,robot(j).child);