function id_route=findroute(robot,id)
i=robot(id).mother;
if i==1
    id_route=[id];
else
    id_route=[findroute(robot,i) id];
end