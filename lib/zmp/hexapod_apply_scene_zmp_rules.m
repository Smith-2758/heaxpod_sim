function rules = hexapod_apply_scene_zmp_rules(state, cfg)
%HEXAPOD_APPLY_SCENE_ZMP_RULES Apply scene-specific light ZMP assistance.

rules = struct( ...
    'freeze_progression', false, ...
    'delta_yaw_zmp_deg', 0, ...
    'delta_x_guard_m', 0);

scene_name = string(get_struct_field(state, 'scene_name', ''));
if ~strcmpi(scene_name, "ditch")
    return;
end

polygon_valid = logical(get_struct_field(state, 'polygon_valid', false));
stability_margin = double(get_struct_field(state, 'stability_margin', NaN));
front_margin = double(get_struct_field(state, 'front_margin', NaN));
lateral_offset = double(get_struct_field(state, 'lateral_offset', 0));

if ~polygon_valid || isnan(stability_margin) || stability_margin < cfg.SM_critical
    rules.freeze_progression = true;
end

if ~polygon_valid
    return;
end

yaw_cmd_deg = -cfg.K_yaw_zmp * lateral_offset * 180 / pi;
rules.delta_yaw_zmp_deg = clamp_value(yaw_cmd_deg, cfg.yaw_assist_limit_deg);

if ~isnan(front_margin) && front_margin < cfg.SM_safe
    raw_guard = cfg.K_x_guard * (cfg.SM_safe - front_margin);
    rules.delta_x_guard_m = clamp_value(raw_guard, cfg.x_guard_limit_m);
end
end

function value = get_struct_field(s, field_name, default_value)
if isstruct(s) && isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end

function clamped = clamp_value(value, limit)
clamped = max(-limit, min(limit, value));
end
