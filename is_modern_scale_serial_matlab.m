function tf = is_modern_scale_serial_matlab(scale)
%IS_MODERN_SCALE_SERIAL_MATLAB True for MATLAB's newer serialport object.

tf = has_modern_scale_serialport_matlab() && isa(scale, 'serialport');
end
