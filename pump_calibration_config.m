function cfg = pump_calibration_config()
%PUMP_CALIBRATION_CONFIG Settings for the MonkeyLogic pump calibration task.
%
% Edit this file before running ml_pump_calibration.m from MonkeyLogic.

% Scale serial settings. These match the scale manual and your working setup.
% Use 'auto' when moving between computers. If more than one serial port is
% available, either set scale_port manually or enable auto_probe_scale_port.
% Please note that enable auto_probe_scale_port means testin each port for 
% scale like output, which is not always be appropriate. 
cfg.scale_port = 'auto';
cfg.preferred_scale_port = '';
cfg.auto_probe_scale_port = false;
cfg.scale_probe_timeout_s = 2;
cfg.scale_baud = 4800;
cfg.scale_databits = 8;
cfg.scale_parity = 'none';
cfg.scale_stopbits = 1;
cfg.scale_timeout_s = 10;

% The scale should be in F3 SEr -> S 232 -> P2 Con -> b 4800 -> 8 n 1.
% Leave scale_request empty for continuous output. If you later use P1 Prt
% and PC-triggered print works, set this to sprintf('P\r\n').
cfg.scale_request = '';
cfg.scale_samples = 3;
cfg.scale_flush_before_read = true;
cfg.scale_require_stable = false;

% Pump durations to test. goodmonkey uses milliseconds.
cfg.durations_ms = [400 600 1000 1500 2000];
cfg.repetitions = 5;
cfg.randomize_order = false;

% Reward output. Set JuiceLine to the MonkeyLogic reward channel that drives
% the pump. Leave optional fields empty to omit them from goodmonkey().
% Set DRY_REWARD true to debug scale reading/logging without calling
% goodmonkey or turning on the pump.
cfg.DRY_REWARD = false;
cfg.juiceline = 1;
cfg.numreward = 1;
cfg.pausetime_ms = [];
cfg.triggerval = [];
cfg.eventmarker = [];
cfg.nonblocking = 0;

% Timing around each pump pulse.
cfg.baseline_pause_s = 0.5;
cfg.post_pump_settle_s = 2.0;
cfg.inter_trial_pause_s = 2.0;

% Convert mass to volume. Water is ~1 g/mL; change this for other fluids.
cfg.fluid_density_g_per_ml = 1.0;

% CSV output.
cfg.output_dir = fullfile(pwd, 'data');
cfg.output_file = '';
end
