function info = vsProbe(cfg, boxKey)
%VSPROBE Is a box reachable?
%   INFO = VSPROBE(CFG, BOXKEY) runs the bridge's reflection probe against
%   the box and returns its report: reachable, service, methods, reflection.
%   With no BOXKEY every configured box is probed.
%
%   A probe costs about a second; a call to a box that is down costs a full
%   timeout, so this is worth doing before a long run.
%
%   Octave build: MATLAB's vsProbe returns a table for the all-boxes form.
%   Octave has no table, so this returns a 1xN struct array with the same
%   three fields - box, host, reachable - and prints them when you call it
%   without a semicolon. struct2cell / [info.reachable] read it easily:
%
%       info = vsProbe(cfg);
%       down = {info(~[info.reachable]).box};
%
%   See also VSCONFIG, VSRUN.

if nargin < 2
    keys = fieldnames(cfg.hosts)';
    info = struct('box', {}, 'host', {}, 'reachable', {});
    for k = 1:numel(keys)
        one = vsProbe(cfg, keys{k});
        info(end+1) = struct('box', keys{k}, ...
                             'host', vsHost(cfg, keys{k}), ...
                             'reachable', isfield(one, 'reachable') && ...
                                          logical(one.reachable));  %#ok<AGROW>
    end
    return
end

boxKey = vsChar(boxKey);
host = vsHost(cfg, boxKey);
cmd = sprintf('%s "%s" probe --host %s', cfg.python, cfg.runner, host);
[~, output] = system(cmd);

info = struct('reachable', false, 'host', host);
lines = vsSplitLines(output);
for k = numel(lines):-1:1
    line = strtrim(lines{k});
    if ~isempty(line) && line(1) == '{'
        try
            info = jsondecode(line);
            return
        catch
        end
    end
end
end
