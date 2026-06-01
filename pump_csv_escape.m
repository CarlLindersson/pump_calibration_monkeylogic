function out = pump_csv_escape(value)
%PUMP_CSV_ESCAPE Return a quoted CSV field.

if isnumeric(value)
    value = num2str(value);
end

text = char(value);
text = strrep(text, '"', '""');
out = ['"', text, '"'];
end
