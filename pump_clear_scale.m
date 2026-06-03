function pump_clear_scale(scale)
%PUMP_CLEAR_SCALE Best-effort cleanup for a MATLAB scale serial object.

try
    flush_scale_serial_matlab(scale);
catch
end

if ~is_modern_scale_serial_matlab(scale)
    try
        if strcmp(get(scale, 'Status'), 'open')
            fclose(scale);
        end
    catch
    end

    try
        delete(scale);
    catch
    end
end
end
