function [matched, reading] = probe_scale_port_matlab(port, cfg)
%PROBE_SCALE_PORT_MATLAB Return true if a serial port looks like the scale.

matched = false;
reading = [];

try
    scale = serialport(char(port), cfg.scale_baud, ...
        'DataBits', cfg.scale_databits, ...
        'Parity', cfg.scale_parity, ...
        'StopBits', cfg.scale_stopbits, ...
        'Timeout', min(0.5, cfg.scale_probe_timeout_s));
    cleanup = onCleanup(@() pump_clear_scale(scale));
    configureTerminator(scale, 'LF');
    flush(scale, 'input');
catch
    return
end

started = tic;
while toc(started) < cfg.scale_probe_timeout_s
    try
        line = readline(scale);
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
