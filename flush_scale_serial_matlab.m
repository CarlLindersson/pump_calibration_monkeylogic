function flush_scale_serial_matlab(scale)
%FLUSH_SCALE_SERIAL_MATLAB Clear pending input bytes from a scale connection.

if is_modern_scale_serial_matlab(scale)
    flush(scale, 'input');
    return
end

while get(scale, 'BytesAvailable') > 0
    fread(scale, get(scale, 'BytesAvailable'));
end
end
