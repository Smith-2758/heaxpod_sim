function out = hexapod_compute_quasistatic_zmp(foot_pos, force_vec, stance_mask, ~)
%HEXAPOD_COMPUTE_QUASISTATIC_ZMP Force-weighted quasi-static ZMP estimate.

stance_mask = logical(stance_mask(:)).';
stance_idx = find(stance_mask);

out = struct();
out.valid = ~isempty(stance_idx);
out.mode = "invalid";
out.zmp_xy = [NaN, NaN];
out.stance_mask = stance_mask;
out.stance_count = numel(stance_idx);
out.support_xy = zeros(0, 2);

if isempty(stance_idx)
    return;
end

support_xy = double(foot_pos(stance_idx, 1:2));
weights = vecnorm(double(force_vec(stance_idx, :)), 2, 2);

out.valid = true;
out.support_xy = support_xy;

if sum(weights) > eps
    out.mode = "force_weighted";
    out.zmp_xy = sum(support_xy .* weights, 1) ./ sum(weights);
else
    out.mode = "fallback_centroid";
    out.zmp_xy = mean(support_xy, 1);
end
end
