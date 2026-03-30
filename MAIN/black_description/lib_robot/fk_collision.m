function robot=fk_collision(robot)

for jj=1:length(robot)
    
    for ii=1:length(robot(jj).collision)
        robot(jj).collision(ii).p=robot(jj).p+robot(jj).R* robot(jj).collision(ii).b;        
		robot(jj).collision(ii).R=robot(jj).R;        
    end
    
end
end