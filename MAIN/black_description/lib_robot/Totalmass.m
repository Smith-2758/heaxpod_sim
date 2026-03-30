function m=Totalmass(robot,j)
if j==0
    m=0;
else
    m=robot(j).m+Totalmass(robot,robot(j).sister)+Totalmass(robot,robot(j).child);
end