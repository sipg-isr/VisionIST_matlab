function tf = vsContainsAny(s, needles)
%VSCONTAINSANY Does S contain any of NEEDLES? (Octave has no `contains`.)
%   TF = VSCONTAINSANY('SUPERPOINT', {'SUPERPOINT','DISK'}) is true.
%
%   See also VSCHAR.

s = vsChar(s);
needles = vsCellstr(needles);
tf = false;
if isempty(s)
    return
end
for k = 1:numel(needles)
    if ~isempty(needles{k}) && ~isempty(strfind(s, needles{k}))  %#ok<STREMP>
        tf = true;
        return
    end
end
end
