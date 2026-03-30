function x=ik_OPT(robot,target)
for ii=1:length(robot)-1
	x0(ii,1)=robot(ii+1).q;
	lb(ii,1)=robot(ii+1).lb;
	ub(ii,1)=robot(ii+1).ub;
	
end

options = optimset('MaxIter',100,'MaxFunEvals',10000,'TolX',1e-8,'TolFun',1e-8,'Display','iter');
x=fmincon(@cost,x0,[],[],[],[],lb,ub,@tgt_follow,options,robot,target);

end

function j=cost(q,~,~)
j=norm(q);
end

function [C,Ceq]=tgt_follow(q,robot,target)
C=[];
Ceq=[];
for ii=1:length(robot)-1
	robot(ii+1).q=q(ii);
end
robot=fkinematic(robot,1);
robot=fk_collision(robot);
for ii=1:length(target)
	link_num=target(ii).id(1);
	col_num=target(ii).id(2);
	
	Ceq=[Ceq;calculate_err(target(ii),robot(link_num).collision(col_num))];
end
end