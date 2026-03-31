function target_total_frames = hexapod_prompt_total_frames(default_total_frames, scene_name)
if nargin < 2 || isempty(scene_name)
    scene_name = 'unknown';
end
if nargin < 1 || isempty(default_total_frames)
    error('hexapod_prompt_total_frames:MissingDefault', '必须提供默认帧数。');
end
if ~isscalar(default_total_frames) || default_total_frames < 2 || default_total_frames ~= floor(default_total_frames)
    error('hexapod_prompt_total_frames:InvalidDefault', '默认帧数必须是大于等于 2 的整数。');
end

scene_info = hexapod_scene_info(scene_name);
prompt = sprintf('[%s] 请输入总帧数，直接回车使用默认 %d 帧: ', scene_info.scene_label, default_total_frames);
answer = strtrim(input(prompt, 's'));
if isempty(answer)
    target_total_frames = default_total_frames;
    return;
end

target_total_frames = str2double(answer);
if isnan(target_total_frames) || ~isfinite(target_total_frames) || target_total_frames < 2 || target_total_frames ~= floor(target_total_frames)
    error('hexapod_prompt_total_frames:InvalidInput', '输入的总帧数必须是大于等于 2 的整数。');
end
end
