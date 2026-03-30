function R=rodrigues(v)
theta=norm(v);
if theta==0
    R=eye(3);
else
v=v./theta;
tmp_matrix=[0 -v(3) v(2);v(3) 0 -v(1);-v(2) v(1) 0];
R=cos(theta)*eye(3)+(1-cos(theta))*(v*v')+sin(theta)*tmp_matrix;
end