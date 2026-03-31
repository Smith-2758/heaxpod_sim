function joint = hexapod_generate_origin_walk3step(varargin)
warning('hexapod_generate_origin_walk3step:Deprecated', ...
    'hexapod_generate_origin_walk3step 已废弃，默认转到高台最初版生成器。');
[joint, ~] = hexapod_generate_origin_initial('step', struct());
end
