function pump_clear_scale(scale)
%PUMP_CLEAR_SCALE Best-effort cleanup for a MATLAB serialport object.

try
    flush(scale);
catch
end

try
    delete(scale);
catch
end
end
