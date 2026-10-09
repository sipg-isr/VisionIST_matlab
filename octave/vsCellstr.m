function c = vsCellstr(x)
%VSCELLSTR A list of text values as a 1xN cell array of char.
%   C = VSCELLSTR(X) accepts a char row (one value), a cell array of char, a
%   char matrix (one value per row), or (under MATLAB) a string array, and
%   always returns a 1xN cellstr. [] and '' become {}.
%
%   This is what replaces the MATLAB client's string arrays: where that one
%   writes ["a.jpg" "b.jpg"], write {'a.jpg', 'b.jpg'} here.
%
%   See also VSCHAR.

c = {};
if nargin < 1 || isempty(x)
    return
end
if ischar(x)
    if size(x, 1) > 1
        c = cellstr(x)';                 % char matrix: one value per row
    else
        c = {x(:)'};
    end
    return
end
if iscell(x)
    c = cell(1, numel(x));
    for k = 1:numel(x)
        c{k} = vsChar(x{k});
    end
    return
end
if isa(x, 'string')            % only reachable under MATLAB
    c = cellstr(x(:)');
    return
end
error('visionist:notTextList', 'cannot read %s as a list of text', class(x));
end
