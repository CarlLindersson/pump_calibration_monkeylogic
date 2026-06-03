function reading = read_scale_weight_matlab(scale, cfg)
%READ_SCALE_WEIGHT_MATLAB Read fresh readings from the continuous scale stream.

if cfg.scale_flush_before_read
    flush_scale_serial_matlab(scale);
end

weights = nan(cfg.scale_samples, 1);
raw_lines = cell(cfg.scale_samples, 1);
statuses = cell(cfg.scale_samples, 1);
units = cell(cfg.scale_samples, 1);

sample_count = 0;
started = tic;
while sample_count < cfg.scale_samples && toc(started) < cfg.scale_timeout_s
    if isfield(cfg, 'scale_request') && ~isempty(cfg.scale_request)
        write_scale_serial_matlab(scale, cfg.scale_request);
    end

    try
        line = readline_scale_serial_matlab(scale);
    catch
        continue
    end

    parsed = parse_scale_line_matlab(line);
    if isempty(parsed)
        continue
    end
    if isfield(cfg, 'scale_require_stable') && cfg.scale_require_stable ...
            && ~isempty(strfind(upper(parsed.status), 'US')) %#ok<STREMP>
        continue
    end

    sample_count = sample_count + 1;
    weights(sample_count) = parsed.weight_g;
    raw_lines{sample_count} = parsed.raw;
    statuses{sample_count} = parsed.status;
    units{sample_count} = parsed.unit;
end

if 0 == sample_count
    error('read_scale_weight_matlab:Timeout', ...
        'No parseable scale readings received within %.1f seconds.', cfg.scale_timeout_s);
end

reading = struct();
valid_weights = weights(1:sample_count);
valid_weights = valid_weights(~isnan(valid_weights));
reading.weight_g = median(valid_weights);
reading.n_samples = sample_count;
reading.raw = strjoin(raw_lines(1:sample_count), ' | ');
reading.status = statuses{sample_count};
reading.unit = units{sample_count};
end
