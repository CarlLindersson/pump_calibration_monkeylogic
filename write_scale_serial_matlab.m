function write_scale_serial_matlab(scale, data)
%WRITE_SCALE_SERIAL_MATLAB Write bytes to a scale connection.

bytes = uint8(data);
if is_modern_scale_serial_matlab(scale)
    write(scale, bytes, 'uint8');
    return
end

fwrite(scale, bytes, 'uint8');
end
