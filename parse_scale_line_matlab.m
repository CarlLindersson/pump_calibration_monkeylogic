function reading = parse_scale_line_matlab(line)
%PARSE_SCALE_LINE_MATLAB Parse one scale output line.
%
% Expected normal weighing output is like:
%   GS   123.45g
%   G S   123.45 g
%   NT    -1.20g

reading = [];
text = strtrim(char(line));
if isempty(text) || startsWith(upper(text), 'ERR')
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
suffix = strtrim(text(number_end + 1:end));
unit = regexp(suffix, '^[A-Za-z%./0-9]+', 'match', 'once');
if isempty(unit)
    unit = '';
end

status = '';
if any(strcmpi(prefix, {'GS', 'NT', 'G', 'N'}))
    status = upper(prefix);
end

reading = struct();
reading.weight_g = weight;
reading.unit = unit;
reading.status = status;
reading.raw = text;
end
