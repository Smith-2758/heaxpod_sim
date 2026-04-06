function [stance_mask, stance_count, contact_flags] = hexapod_detect_stance_legs(force_input, prev_mask, cfg)
%HEXAPOD_DETECT_STANCE_LEGS Detect support legs with hysteresis thresholds.

force_input = double(force_input(:)).';
prev_mask = logical(prev_mask(:)).';

leg_count = min(numel(force_input), 6);
stance_mask = false(1, 6);
stance_mask(1:min(numel(prev_mask), 6)) = prev_mask(1:min(numel(prev_mask), 6));

for idx = 1:leg_count
    if force_input(idx) >= cfg.F_enter
        stance_mask(idx) = true;
    elseif force_input(idx) <= cfg.F_exit
        stance_mask(idx) = false;
    end
end

contact_flags = stance_mask;
stance_count = sum(stance_mask);
end
