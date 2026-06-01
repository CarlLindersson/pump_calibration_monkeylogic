%ML_PUMP_CALIBRATION MonkeyLogic timing script for pump output calibration.
%
% Run this from NIMH MonkeyLogic with pump_calibration_conditions.txt, or call
% this script from your own MonkeyLogic timing file. It reads the scale before
% and after each goodmonkey pulse and writes duration-vs-output data to CSV.

cfg = pump_calibration_config();
scale_port = resolve_scale_port_matlab(cfg);

if ~exist(cfg.output_dir, 'dir')
    mkdir(cfg.output_dir);
end

if isempty(cfg.output_file)
    csv_path = fullfile(cfg.output_dir, ...
        sprintf('pump_calibration_%s.csv', datestr(now, 'yyyymmdd_HHMMSS')));
else
    csv_path = cfg.output_file;
end

durations = cfg.durations_ms(:);
trial_duration_ms = [];
trial_repetition = [];
for repetition = 1:cfg.repetitions
    trial_duration_ms = [trial_duration_ms; durations]; %#ok<AGROW>
    trial_repetition = [trial_repetition; repmat(repetition, numel(durations), 1)]; %#ok<AGROW>
end

if cfg.randomize_order
    order = randperm(numel(trial_duration_ms));
    trial_duration_ms = trial_duration_ms(order);
    trial_repetition = trial_repetition(order);
end

fprintf('Opening scale on %s at %d baud...\n', scale_port, cfg.scale_baud);
scale = serialport(scale_port, cfg.scale_baud, ...
    'DataBits', cfg.scale_databits, ...
    'Parity', cfg.scale_parity, ...
    'StopBits', cfg.scale_stopbits, ...
    'Timeout', cfg.scale_timeout_s);
configureTerminator(scale, 'LF');
flush(scale, 'input');
cleanup_scale = onCleanup(@() pump_clear_scale(scale));

fid = fopen(csv_path, 'w');
if -1 == fid
    error('ml_pump_calibration:FileOpenFailed', 'Could not open %s for writing.', csv_path);
end

cleanup_file = onCleanup(@() fclose(fid));

fprintf(fid, ['timestamp,trial,duration_ms,repetition,baseline_g,post_g,' ...
    'delta_g,delivered_uL,baseline_status,post_status,baseline_raw,post_raw\n']);

reward_args = pump_calibration_reward_args(cfg);
fprintf('Writing calibration data to %s\n', csv_path);
fprintf('Scale should be in continuous mode: F3 SEr -> S 232 -> P2 Con -> b 4800 -> 8 n 1\n');

for trial_idx = 1:numel(trial_duration_ms)
    duration_ms = trial_duration_ms(trial_idx);
    repetition = trial_repetition(trial_idx);

    msg = sprintf('Pump calibration %d/%d: %d ms, rep %d', ...
        trial_idx, numel(trial_duration_ms), duration_ms, repetition);
    fprintf('%s\n', msg);
    try
        dashboard(1, msg);
    catch
    end

    ml_pause_seconds(cfg.baseline_pause_s);
    baseline = read_scale_weight_matlab(scale, cfg);

    try
        goodmonkey(duration_ms, reward_args{:});
    catch ME
        error('ml_pump_calibration:GoodmonkeyFailed', ...
            ['goodmonkey failed. Run ml_pump_calibration.m as a MonkeyLogic ' ...
            'timing script and check cfg.juiceline in pump_calibration_config.m.\n%s'], ...
            ME.message);
    end

    ml_pause_seconds(cfg.post_pump_settle_s);
    post = read_scale_weight_matlab(scale, cfg);

    delta_g = post.weight_g - baseline.weight_g;
    delivered_uL = 1000 * delta_g / cfg.fluid_density_g_per_ml;
    timestamp = datestr(now, 'yyyy-mm-ddTHH:MM:SS.FFF');

    fprintf(fid, '%s,%d,%d,%d,%.6f,%.6f,%.6f,%.3f,%s,%s,%s,%s\n', ...
        pump_csv_escape(timestamp), ...
        trial_idx, ...
        duration_ms, ...
        repetition, ...
        baseline.weight_g, ...
        post.weight_g, ...
        delta_g, ...
        delivered_uL, ...
        pump_csv_escape(baseline.status), ...
        pump_csv_escape(post.status), ...
        pump_csv_escape(baseline.raw), ...
        pump_csv_escape(post.raw));
    fflush(fid);

    fprintf('  baseline %.6f g, post %.6f g, delivered %.3f uL\n', ...
        baseline.weight_g, post.weight_g, delivered_uL);

    ml_pause_seconds(cfg.inter_trial_pause_s);
end

clear scale cleanup_scale
fprintf('Pump calibration complete: %s\n', csv_path);

try
    trialerror(0);
catch
end

try
    escape_screen;
catch
end
