function err=calculate_err(ref,rel)
if isempty(ref.p)
    p_err=[0;0;0];
else
    p_err=ref.p-rel.p;
end

if isempty(ref.R)
%     R_err=eye(3);
	w_err=[0;0;0];
else
    R_err=rel.R^(-1)*ref.R;
	w_err=rel.R*rot2omega(R_err);
end


alpha=1;beta=0.01;
err=[alpha*p_err;beta*w_err];
% err