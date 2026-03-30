function visual_robot(ulink,j)
if j==0
    return;
end

if j==1
    x=ulink(j).p(1);
    y=ulink(j).p(2);
    z=ulink(j).p(3);
    x_c=[];y_c=[];z_c=[];
    for nn=1:length(ulink(j).collision)
        x_c=[x_c,ulink(j).collision(nn).p(1)];
        y_c=[y_c,ulink(j).collision(nn).p(2)];
        z_c=[z_c,ulink(j).collision(nn).p(3)];        
    end
    plot3(x,y,z,'o','LineWidth',2);hold on;
    plot3(x_c,y_c,z_c,'x','LineWidth',2);
    view(90,0);
%     axis equal ;  
%     axis([ulink(1).p(1)-0.8,ulink(1).p(1)+0.8,ulink(1).p(2)-0.8,ulink(1).p(2)+0.8,ulink(1).p(3)-0.8,ulink(1).p(3)+0.8]); 
    axis([-0.8 0.8 -0.8 2 -0.6 1.8]);
end

if j~=1
    i = ulink(j).mother;
    x = [ulink(j).p(1),ulink(i).p(1)]; %xmin = min(xmin,min(x)); xmax = max(xmax,max(x));
    y = [ulink(j).p(2),ulink(i).p(2)]; %ymin = min(ymin,min(y)); ymax = max(ymax,max(y));
    z = [ulink(j).p(3),ulink(i).p(3)]; %zmin = min(zmin,min(z)); zmax = max(zmax,max(z));
    x_c=[];y_c=[];z_c=[];
    for nn=1:length(ulink(j).collision)
        x_c=[x_c,ulink(j).collision(nn).p(1)];
        y_c=[y_c,ulink(j).collision(nn).p(2)];
        z_c=[z_c,ulink(j).collision(nn).p(3)];        
    end
    %subplot(2,2,1);
    plot3(x,y,z,'LineWidth',2); hold on;
    plot3(x,y,z,'o','LineWidth',2);hold on;
    plot3(x_c,y_c,z_c,'x','LineWidth',2);
%     view(40,30);
    view(0,0);
    axis equal ;
    axis([ulink(1).p(1)-0.8,ulink(1).p(1)+0.8,ulink(1).p(2)-0.8,ulink(1).p(2)+0.8,ulink(1).p(3)-0.8,ulink(1).p(3)+0.8]); 
    
%     subplot(2,2,2);
%     plot3(x,y,z,'LineWidth',2); hold on;
%     plot3(x,y,z,'o','LineWidth',2);hold on;
%     plot3(x_c,y_c,z_c,'x','LineWidth',2);
%     view(90,0);
% %     axis equal ;  
% %     axis([ulink(1).p(1)-0.8,ulink(1).p(1)+0.8,ulink(1).p(2)-0.8,ulink(1).p(2)+0.8,ulink(1).p(3)-0.8,ulink(1).p(3)+0.8]); 
%     axis([-0.8 0.8 -0.8 2 -0.6 1.8]);   
%     subplot(2,2,3);
%     plot3(x,y,z,'LineWidth',2); hold on;
%     plot3(x,y,z,'o','LineWidth',2);hold on;
%     plot3(x_c,y_c,z_c,'x','LineWidth',2);
%     view(90,-90);
%     axis equal ; 
%     axis([ulink(1).p(1)-0.8,ulink(1).p(1)+0.8,ulink(1).p(2)-0.8,ulink(1).p(2)+0.8,ulink(1).p(3)-0.8,ulink(1).p(3)+0.8]); 
%     
%     subplot(2,2,4);
%     plot3(x,y,z,'LineWidth',2); hold on;
%     plot3(x,y,z,'o','LineWidth',2);hold on;
%     plot3(x_c,y_c,z_c,'x','LineWidth',2);
%     view(0,0);
%     axis equal ; 
%     axis([ulink(1).p(1)-0.8,ulink(1).p(1)+0.8,ulink(1).p(2)-0.8,ulink(1).p(2)+0.8,ulink(1).p(3)-0.8,ulink(1).p(3)+0.8]); 
%     
%     
end
visual_robot(ulink,ulink(j).child)
visual_robot(ulink,ulink(j).sister);
if j==length(ulink) 
%     subplot(2,2,1);hold off;xlabel('X');ylabel('Y');zlabel('Z');grid on;
%     subplot(2,2,2);
    hold off;xlabel('X');ylabel('Y');zlabel('Z');grid on;
%     subplot(2,2,3);hold off;xlabel('X');ylabel('Y');zlabel('Z');grid on;
%     subplot(2,2,4);hold off;xlabel('X');ylabel('Y');zlabel('Z');grid on;
    hold off;xlabel('X');ylabel('Y');zlabel('Z');
end