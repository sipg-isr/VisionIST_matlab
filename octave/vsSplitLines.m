function lines = vsSplitLines(txt)
%VSSPLITLINES Split text into a cellstr of lines (Octave has no `splitlines`).
%   Handles \n, \r\n and \r. Returns a 1xN cellstr; '' gives {''}.

txt = vsChar(txt);
txt = strrep(txt, sprintf('\r\n'), sprintf('\n'));
txt = strrep(txt, sprintf('\r'), sprintf('\n'));
lines = strsplit(txt, sprintf('\n'), 'CollapseDelimiters', false);
end
