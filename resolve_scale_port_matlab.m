function port = resolve_scale_port_matlab(cfg)
%RESOLVE_SCALE_PORT_MATLAB Resolve the scale COM port from config.

configured_port = char(cfg.scale_port);
if ~strcmpi(configured_port, 'auto')
    port = configured_port;
    return
end

available_ports = scale_available_ports_matlab();

if isempty(available_ports)
    error('resolve_scale_port_matlab:NoSerialPorts', ...
        'No serial ports found. Connect the scale USB serial adapter and try again.');
end

if isfield(cfg, 'preferred_scale_port') && ~isempty(cfg.preferred_scale_port)
    preferred_port = char(cfg.preferred_scale_port);
    match = strcmpi(available_ports, preferred_port);
    if any(match)
        port = available_ports{find(match, 1)};
        return
    end
end

if isscalar(available_ports)
    port = available_ports{1};
    return
end

if isfield(cfg, 'auto_probe_scale_port') && cfg.auto_probe_scale_port
    port = detect_scale_port_matlab(cfg);
    return
end

port_list = strjoin(available_ports, ', ');
error('resolve_scale_port_matlab:AmbiguousSerialPorts', ...
    ['Multiple serial ports found: %s. Set cfg.scale_port in ' ...
    'pump_calibration_config.m to the scale port, for example ''COM7'', ' ...
    'or set cfg.auto_probe_scale_port = true to probe for the scale.'], ...
    port_list);
end
