function J=calculate_jacobian(robot,id_route,id_collision)
if nargin==2
    jsize=length(id_route);
    target=robot(id_route(end)).p;
    % J=zeros(6,jsize);
    for n=1:jsize
        j=id_route(n);
        a=robot(j).R*robot(j).a;
        dw=hat3(a);
        J(:,n)=[dw*(target-robot(j).p);a];
        %     J(:,n)=[cross(a,target-robot(j).p);a];
    end
else
    jsize=length(id_route);
    target=robot(id_route(end)).collision(id_collision).p;
    for n=1:jsize
        j=id_route(n);
        a=robot(j).R*robot(j).a;
        dw=hat3(a);
        J(:,n)=[dw*(target-robot(j).p);a];
        %     J(:,n)=[cross(a,target-robot(j).p);a];
    end
end
end