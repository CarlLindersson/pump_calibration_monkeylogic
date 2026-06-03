function ports = scale_available_ports_matlab()
%SCALE_AVAILABLE_PORTS_MATLAB List serial ports on new and old MATLAB.

ports = {};

if exist('serialportlist', 'file')
    try
        ports = cellstr(serialportlist('available'));
        if isempty(ports)
            ports = cellstr(serialportlist('all'));
        end
        return
    catch
    end
end

try
    info = instrhwinfo('serial');
    if isfield(info, 'AvailableSerialPorts') && ~isempty(info.AvailableSerialPorts)
        ports = cellstr(info.AvailableSerialPorts);
    elseif isfield(info, 'SerialPorts') && ~isempty(info.SerialPorts)
        ports = cellstr(info.SerialPorts);
    end
catch
    ports = {};
end
end
