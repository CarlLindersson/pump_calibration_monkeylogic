function results = analyze_pump_calibration(csv_path, include_dry_reward)
%ANALYZE_PUMP_CALIBRATION Summarize and fit pump calibration output.
%
% Usage:
%   analyze_pump_calibration
%   analyze_pump_calibration('data/pump_calibration_YYYYMMDD_HHMMSS.csv')
%   analyze_pump_calibration('', true)  % include dry-reward rows
%
% The nonlinear fit is:
%   delivered_uL = offset + gain * (duration_seconds ^ exponent)

if nargin < 1
    csv_path = '';
end
if nargin < 2
    include_dry_reward = false;
end

if isempty(csv_path)
    csv_path = latest_pump_calibration_csv();
end

data = readtable(csv_path);

required_columns = {'duration_ms', 'delivered_uL'};
for i = 1:numel(required_columns)
    if ~any(strcmp(data.Properties.VariableNames, required_columns{i}))
        error('analyze_pump_calibration:MissingColumn', ...
            'CSV is missing required column: %s', required_columns{i});
    end
end

data = filter_calibration_rows(data, include_dry_reward);

[summary_table, fit] = summarize_and_fit(data);
prediction_table = make_prediction_table(fit, (100:100:3000)');

[folder, base_name] = fileparts(csv_path);
if isempty(folder)
    folder = pwd;
end

summary_path = fullfile(folder, [base_name, '_summary.csv']);
prediction_path = fullfile(folder, [base_name, '_fit_predictions.csv']);
plot_path = fullfile(folder, [base_name, '_fit.png']);

writetable(summary_table, summary_path);
writetable(prediction_table, prediction_path);
plot_pump_calibration(summary_table, prediction_table, fit, plot_path);

results = struct();
results.csv_path = csv_path;
results.summary_path = summary_path;
results.prediction_path = prediction_path;
results.plot_path = plot_path;
results.fit = fit;
results.summary = summary_table;
results.predictions = prediction_table;

fprintf('Pump calibration analysis complete.\n');
fprintf('  Summary:     %s\n', summary_path);
fprintf('  Predictions: %s\n', prediction_path);
fprintf('  Plot:        %s\n', plot_path);
fprintf('  Fit: volume_uL = %.4f + %.4f * seconds ^ %.4f, R^2 = %.4f\n', ...
    fit.offset_uL, fit.gain, fit.exponent, fit.r_squared);
end


function csv_path = latest_pump_calibration_csv()
cfg = pump_calibration_config();
files = dir(fullfile(cfg.output_dir, 'pump_calibration_*.csv'));

keep = true(numel(files), 1);
for i = 1:numel(files)
    name = files(i).name;
    if ~isempty(strfind(name, '_summary')) || ~isempty(strfind(name, '_fit_predictions'))
        keep(i) = false;
    end
end
files = files(keep);

if isempty(files)
    error('analyze_pump_calibration:NoCsv', ...
        'No pump_calibration_*.csv files found in %s.', cfg.output_dir);
end

[~, newest_idx] = max([files.datenum]);
csv_path = fullfile(cfg.output_dir, files(newest_idx).name);
end


function data = filter_calibration_rows(data, include_dry_reward)
if any(strcmp(data.Properties.VariableNames, 'dry_reward')) && ~include_dry_reward
    keep = data.dry_reward == 0;
    if ~any(keep)
        error('analyze_pump_calibration:OnlyDryRewardRows', ...
            ['CSV contains only dry-reward rows. Run with ' ...
            'analyze_pump_calibration(csv_path, true) to analyze them.']);
    end
    data = data(keep, :);
end

valid = ~isnan(data.duration_ms) & ~isnan(data.delivered_uL);
data = data(valid, :);
if isempty(data)
    error('analyze_pump_calibration:NoValidRows', ...
        'No valid rows with duration_ms and delivered_uL were found.');
end
end


function [summary_table, fit] = summarize_and_fit(data)
[durations, ~, group_idx] = unique(data.duration_ms);
delivered_uL = data.delivered_uL;

n = accumarray(group_idx, 1);
mean_uL = accumarray(group_idx, delivered_uL, [], @mean);
std_uL = accumarray(group_idx, delivered_uL, [], @std);
sem_uL = std_uL ./ sqrt(n);

summary_table = table(durations, n, mean_uL, sem_uL, ...
    'VariableNames', {'duration_ms', 'n', 'mean_delivered_uL', 'sem_delivered_uL'});

if numel(durations) < 3
    error('analyze_pump_calibration:TooFewDurations', ...
        'At least 3 unique durations are needed for the nonlinear fit.');
end

fit = fit_power_model(durations, mean_uL);
end


function fit = fit_power_model(duration_ms, delivered_uL)
x_seconds = duration_ms(:) / 1000;
y = delivered_uL(:);

linear_fit = polyfit(x_seconds, y, 1);
initial_offset = linear_fit(2);
initial_gain = max(abs(linear_fit(1)), eps);
initial_exponent = 1;
initial_params = [initial_offset, log(initial_gain), log(initial_exponent)];

model = @(params, x) params(1) + exp(params(2)) .* (x .^ exp(params(3)));
objective = @(params) sum((y - model(params, x_seconds)).^2);

options = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
params = fminsearch(objective, initial_params, options);

fitted = model(params, x_seconds);
ss_res = sum((y - fitted).^2);
ss_tot = sum((y - mean(y)).^2);
if 0 == ss_tot
    r_squared = NaN;
else
    r_squared = 1 - ss_res / ss_tot;
end

fit = struct();
fit.offset_uL = params(1);
fit.gain = exp(params(2));
fit.exponent = exp(params(3));
fit.r_squared = r_squared;
fit.model_name = 'offset_power_law';
fit.model_description = 'delivered_uL = offset + gain * duration_seconds ^ exponent';
end


function prediction_table = make_prediction_table(fit, duration_ms)
duration_seconds = duration_ms(:) / 1000;
predicted_uL = fit.offset_uL + fit.gain .* (duration_seconds .^ fit.exponent);
predicted_g = predicted_uL / 1000;

prediction_table = table(duration_ms(:), predicted_uL(:), predicted_g(:), ...
    'VariableNames', {'duration_ms', 'predicted_delivered_uL', 'predicted_delivered_g'});
end


function plot_pump_calibration(summary_table, prediction_table, fit, plot_path)
fig = figure('Visible', 'off');
hold on

errorbar(summary_table.duration_ms, summary_table.mean_delivered_uL, ...
    summary_table.sem_delivered_uL, 'ko', ...
    'MarkerFaceColor', 'k', 'LineWidth', 1.2);
plot(prediction_table.duration_ms, prediction_table.predicted_delivered_uL, ...
    'r-', 'LineWidth', 2);

xlabel('goodmonkey duration (ms)');
ylabel('Delivered volume (\muL)');
title(sprintf('Pump calibration: offset power law, R^2 = %.3f', fit.r_squared));
legend({'Mean \pm SEM', 'Nonlinear fit'}, 'Location', 'NorthWest');
grid on
box off

print(fig, plot_path, '-dpng', '-r300');
close(fig);
end
