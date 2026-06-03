function reading = parse_scale_line_matlab(line)
%PARSE_SCALE_LINE_MATLAB Parse one scale output line.
%
% Expected normal weighing output is like:
%   GS   123.45g
%   G S   123.45 g
%   NT    -1.20g
%   US,NT-      0.355 g

reading = [];
text = strtrim(char(line));
if isempty(text) || strncmpi(text, 'ERR', 3)
    return
end

number_pattern = '[-+]?\d{1,3}(?:,\d{3})*(?:\.\d+)?|[-+]?\d+(?:\.\d+)?';
[number_start, number_end] = regexp(text, number_pattern, 'start', 'end', 'once');
if isempty(number_start)
    return
end

weight_text = text(number_start:number_end);
weight = str2double(strrep(weight_text, ',', ''));
if isnan(weight)
    return
end

prefix = regexprep(strtrim(text(1:number_start - 1)), '\s+', '');
if weight >= 0 && ~isempty(regexp(prefix, '[+-]$', 'once'))
    if '-' == prefix(end)
        weight = -weight;
    end
    prefix = prefix(1:end - 1);
end

suffix = strtrim(text(number_end + 1:end));
unit = regexp(suffix, '^[A-Za-z%./0-9]+', 'match', 'once');
if isempty(unit)
    unit = '';
end

status = upper(prefix);
if isempty(regexp(status, '^[A-Z,]+$', 'once'))
    status = '';
end

reading = struct();
reading.weight_g = weight;
reading.unit = unit;
reading.status = status;
reading.raw = text;
end
