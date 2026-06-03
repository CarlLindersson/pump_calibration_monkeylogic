function [matched, reading] = probe_scale_port_matlab(port, cfg)
%PROBE_SCALE_PORT_MATLAB Return true if a serial port looks like the scale.

matched = false;
reading = [];

try
    scale = open_scale_serial_matlab(port, cfg, min(0.5, cfg.scale_probe_timeout_s));
    cleanup = onCleanup(@() pump_clear_scale(scale));
    flush_scale_serial_matlab(scale);
catch
    return
end

started = tic;
while toc(started) < cfg.scale_probe_timeout_s
    try
        line = readline_scale_serial_matlab(scale);
    catch
        continue
    end

    reading = parse_scale_line_matlab(line);
    if ~isempty(reading)
        matched = true;
        return
    end
end
end
