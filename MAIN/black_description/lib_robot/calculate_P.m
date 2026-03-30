function P=calculate_P(robot,j)
if j==0 
    P=0;
else
    c1=robot(j).R*robot(j).c;
    P=robot(j).m*(robot(j).v+cross(robot(j).w,c1));
    P=P+calculate_P(robot,robot(j).sister)+calculate_P(robot,robot(j).child);
end