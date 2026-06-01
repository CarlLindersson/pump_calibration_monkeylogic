function [port, matches] = detect_scale_port_matlab(cfg)
%DETECT_SCALE_PORT_MATLAB Probe available serial ports for scale-like output.
%
% The scale must be in continuous output mode:
%   F3 SEr -> S 232 -> P2 Con -> b 4800 -> 8 n 1

available_ports = serialportlist('available');
if isempty(available_ports)
    available_ports = serialportlist('all');
end

if isempty(available_ports)
    error('detect_scale_port_matlab:NoSerialPorts', ...
        'No serial ports found. Connect the scale USB serial adapter and try again.');
end

matches = struct('port', {}, 'weight_g', {}, 'raw', {});
for i = 1:numel(available_ports)
    candidate = char(available_ports(i));
    fprintf('Probing %s for scale output...\n', candidate);
    [matched, reading] = probe_scale_port_matlab(candidate, cfg);
    if matched
        matches(end + 1).port = candidate; %#ok<AGROW>
        matches(end).weight_g = reading.weight_g;
        matches(end).raw = reading.raw;
        fprintf('  matched %s: %.6f g (%s)\n', candidate, reading.weight_g, reading.raw);
    end
end

if isempty(matches)
    error('detect_scale_port_matlab:NoScalePort', ...
        ['No serial port produced scale-like output. Check that the scale is in ' ...
        'P2 Con continuous mode, or set cfg.scale_port manually.']);
end

if numel(matches) > 1
    match_ports = strjoin({matches.port}, ', ');
    error('detect_scale_port_matlab:AmbiguousScalePorts', ...
        ['Multiple ports produced scale-like output: %s. Set cfg.scale_port ' ...
        'manually in pump_calibration_config.m.'], match_ports);
end

port = matches(1).port;
end
