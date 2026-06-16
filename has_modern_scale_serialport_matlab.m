function tf = has_modern_scale_serialport_matlab()
%HAS_MODERN_SCALE_SERIALPORT_MATLAB True for MathWorks' lowercase serialport API.

tf = false;

try
    serialport_path = which('serialport');
catch
    return
end

if isempty(serialport_path)
    return
end

[~, serialport_name] = fileparts(serialport_path);
tf = strcmp(serialport_name, 'serialport');
end
