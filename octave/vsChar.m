function s = vsChar(x)
%VSCHAR One text value as a char row vector.
%   S = VSCHAR(X) accepts a char row, a 1x1 cellstr, or (when this code is
%   run under MATLAB) a scalar string, and always returns char. Empty of any
%   of those becomes ''.
%
%   Octave has no `string` class, so the MATLAB client's scalar strings
%   become char here and its "a" + "b" concatenation becomes ['a' 'b'].
%   Every vs* function funnels its text arguments through this, so a caller
%   may pass 'yolo' or {'yolo'} - or "yolo" under MATLAB - interchangeably.
%
%   See also VSCELLSTR.

if nargin < 1 || isempty(x)
    s = '';
    return
end
if ischar(x)
    s = x(:)';
    return
end
if iscell(x)
    if numel(x) > 1
        error('visionist:notScalarText', ...
              'expected one text value, got %d', numel(x));
    end
    s = vsChar(x{1});
    return
end
if isa(x, 'string')            % only reachable under MATLAB
    s = char(x);
    return
end
if isnumeric(x) || islogical(x)
    s = num2str(x);
    return
end
error('visionist:notText', 'cannot read %s as text', class(x));
end
