function info = hexapod_scene_info(scene_name)
if nargin < 1 || isempty(scene_name)
    scene_name = 'unknown';
end

scene_name = lower(strtrim(scene_name));
switch scene_name
    case {'climb2wall', 'step', 'step_up', 'high_step'}
        scene_key = 'step';
    case {'step_platform5m'}
        scene_key = 'step';
    case {'slope', 'climbing', 'slope_3m_4m_3m'}
        scene_key = 'slope';
    case {'ditch', 'pit'}
        scene_key = 'ditch';
    otherwise
        scene_key = scene_name;
end

info = struct();
info.scene_name = scene_key;
info.raw_scene_name = scene_name;
info.scene_label = scene_key;
info.scene_variant = 'current_main';
info.stage_progress_range = [0.2, 0.8];
info.ditch_crossing_x = [0.25, 4.8];

switch scene_key
    case 'slope'
        info.scene_label = '斜坡';
        info.scene_variant = 'current_main';
    case 'step'
        info.scene_label = '高台';
        info.scene_variant = 'current_main';
    case 'ditch'
        info.scene_label = '深沟';
        info.scene_variant = 'current_ditch';
    otherwise
        info.scene_label = scene_key;
        info.scene_variant = 'current_main';
end
end
