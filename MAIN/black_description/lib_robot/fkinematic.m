function robot=fkinematic(robot,j)

if j==0
    return;
end
if j~=1
    i=robot(j).mother;
    robot(j).p=robot(i).R*robot(j).b+robot(i).p;
    robot(j).R=robot(i).R*rodrigues(robot(j).a*robot(j).q);
    k1=isa(robot(j).p,'sym');
    if k1
    robot(j).p=simplify(robot(j).p);
    end
    k2=isa(robot(j).R,'sym');
    if k2
    robot(j).R=simplify(robot(j).R);
    end
end
robot=fkinematic(robot,robot(j).sister);
robot=fkinematic(robot,robot(j).child);
