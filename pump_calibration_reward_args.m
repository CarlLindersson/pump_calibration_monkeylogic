function args = pump_calibration_reward_args(cfg)
%PUMP_CALIBRATION_REWARD_ARGS Build name-value args for MonkeyLogic goodmonkey.

args = {};

if isfield(cfg, 'juiceline') && ~isempty(cfg.juiceline)
    args = [args, {'juiceline', cfg.juiceline}];
end

if isfield(cfg, 'numreward') && ~isempty(cfg.numreward)
    args = [args, {'numreward', cfg.numreward}];
end

if isfield(cfg, 'pausetime_ms') && ~isempty(cfg.pausetime_ms)
    args = [args, {'pausetime', cfg.pausetime_ms}];
end

if isfield(cfg, 'triggerval') && ~isempty(cfg.triggerval)
    args = [args, {'triggerval', cfg.triggerval}];
end

if isfield(cfg, 'eventmarker') && ~isempty(cfg.eventmarker)
    args = [args, {'eventmarker', cfg.eventmarker}];
end

if isfield(cfg, 'nonblocking') && ~isempty(cfg.nonblocking)
    args = [args, {'nonblocking', cfg.nonblocking}];
end
end
