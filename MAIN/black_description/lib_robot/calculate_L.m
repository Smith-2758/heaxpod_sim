function L=calculate_L(robot,j)
if j==0
    L=0;
else
    c1=robot(j).R*robot(j).c;
    c=robot(j).p+c1;
    P=robot(j).m*(robot(j).v+cross(robot(j).w,c1));
    L=cross(c,P)+robot(j).R*robot(j).I*robot(j).R'*robot(j).w;
    L=L+calculate_L(robot,robot(j).sister)+calculate_L(robot,robot(j).child);
end
