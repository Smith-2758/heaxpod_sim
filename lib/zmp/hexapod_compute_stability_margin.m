function out = hexapod_compute_stability_margin(support_xy, zmp_xy)
%HEXAPOD_COMPUTE_STABILITY_MARGIN Signed margin to support polygon boundary.

out = struct( ...
    'support_polygon_xy', zeros(0, 2), ...
    'polygon_valid', false, ...
    'zmp_inside_polygon_flag', false, ...
    'stability_margin', NaN, ...
    'front_margin', NaN, ...
    'lateral_offset', NaN);

support_xy = double(support_xy);
zmp_xy = double(zmp_xy(:)).';

if size(support_xy, 1) < 3
    return;
end

try
    hull_idx = convhull(support_xy(:, 1), support_xy(:, 2));
catch
    return;
end

polygon_xy = support_xy(hull_idx(1:end-1), :);
polygon_area = polyarea(polygon_xy(:, 1), polygon_xy(:, 2));

out.support_polygon_xy = polygon_xy;

if polygon_area < 1e-10
    return;
end

out.polygon_valid = true;
out.zmp_inside_polygon_flag = inpolygon(zmp_xy(1), zmp_xy(2), polygon_xy(:, 1), polygon_xy(:, 2));

distances = point_to_polygon_edge_distances(zmp_xy, polygon_xy);
nearest_distance = min(distances);

if out.zmp_inside_polygon_flag
    out.stability_margin = nearest_distance;
else
    out.stability_margin = -nearest_distance;
end

out.front_margin = max(polygon_xy(:, 1)) - zmp_xy(1);
out.lateral_offset = zmp_xy(2) - mean(polygon_xy(:, 2));
end

function distances = point_to_polygon_edge_distances(point_xy, polygon_xy)
vertex_count = size(polygon_xy, 1);
distances = zeros(vertex_count, 1);

for idx = 1:vertex_count
    start_xy = polygon_xy(idx, :);
    end_xy = polygon_xy(mod(idx, vertex_count) + 1, :);
    distances(idx) = point_to_segment_distance(point_xy, start_xy, end_xy);
end
end

function distance = point_to_segment_distance(point_xy, start_xy, end_xy)
segment = end_xy - start_xy;
segment_norm_sq = sum(segment .^ 2);

if segment_norm_sq <= eps
    distance = norm(point_xy - start_xy);
    return;
end

t = dot(point_xy - start_xy, segment) / segment_norm_sq;
t = min(max(t, 0), 1);
projection = start_xy + t .* segment;
distance = norm(point_xy - projection);
end
