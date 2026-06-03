function line = readline_scale_serial_matlab(scale)
%READLINE_SCALE_SERIAL_MATLAB Read one terminated text line from the scale.

if is_modern_scale_serial_matlab(scale)
    line = char(readline(scale));
    return
end

line = fgetl(scale);
if isnumeric(line)
    error('readline_scale_serial_matlab:Timeout', 'Timed out waiting for a scale line.');
end
end
