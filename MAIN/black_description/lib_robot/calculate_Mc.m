function Mc=calculate_Mc(robot,j)
if j==0
    Mc=0;
else
    Mc=robot(j).m*(robot(j).p+robot(j).R*robot(j).c);
    Mc=Mc+calculate_Mc(robot,robot(j).sister)+calculate_Mc(robot,robot(j).child);
end