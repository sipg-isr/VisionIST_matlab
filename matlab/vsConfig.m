function cfg = vsConfig(varargin)
%VSCONFIG Settings shared by every vs* function.
%   CFG = VSCONFIG() returns the defaults. Override any of them with
%   name/value pairs, or edit the returned struct afterwards:
%
%       cfg = vsConfig('workdir', "/tmp/vs", 'session_id', "alice");
%       cfg.hosts.moge = "ifetch.isr.tecnico.ulisboa.pt:9067";
%
%   Fields
%     python      interpreter to launch ("py -3" on Windows)
%     runner      path to visionist_run.py (the box-agnostic bridge)
%     workdir     where .mat results, request JSON and binary assets land
%     session_id  default session for the stateful boxes
%     hosts       struct of box key -> "host:port" (permanent ports, see below)
%     ports       OBSOLETE, kept so old scripts still run; the port map is
%                 now the registry's one and only convention
%     timeout     per-request seconds
%     verbose     print each command before running it
%
%   The host keys are the boxes' own config_json section names, which is
%   also what every vs* function passes to vsRun - so "sbert", not
%   "textEmbedding", and "lang_sam", not "lang_segm".
%
%   See also VSRUN, VSPROBE, VSRESET.

p = inputParser;
p.FunctionName = 'vsConfig';
addParameter(p, 'python', "python3");
addParameter(p, 'runner', "");
addParameter(p, 'workdir', "");
addParameter(p, 'session_id', "matlab");
addParameter(p, 'timeout', 1800);
addParameter(p, 'verbose', true);
addParameter(p, 'hostPrefix', "localhost");
addParameter(p, 'ports', "legacy");     % obsolete - see below
addParameter(p, 'basePort', 9061);      % obsolete - ports are per box now
parse(p, varargin{:});
a = p.Results;

cfg = struct();
cfg.python     = string(a.python);
cfg.timeout    = a.timeout;
cfg.verbose    = logical(a.verbose);
cfg.session_id = string(a.session_id);

if strlength(a.runner) > 0
    cfg.runner = string(a.runner);
else
    % Default: the bridge in the repository root, one level up. It is
    % shared with the Octave build, so it does not live beside either.
    here = fileparts(mfilename('fullpath'));
    cfg.runner = string(fullfile(fileparts(here), 'visionist_run.py'));
end

if strlength(a.workdir) > 0
    cfg.workdir = string(a.workdir);
else
    cfg.workdir = string(fullfile(pwd, "visionist_out"));
end
if ~isfolder(cfg.workdir)
    mkdir(cfg.workdir);
end

% Fleet port map. One convention now: each box has a PERMANENT host port,
% issued once in the order boxes arrived and recorded in the registry's
% registry/ports.json. A new box takes the next free port, so nothing here
% ever moves and a box answers on the same port in every fleet - full or
% partial. This replaces the old "legacy" / "generated" split, which
% disagreed because the generator used to renumber alphabetically.
%
% The fleet you are actually running is still the authority: its
% docker-compose.yml has the host ports and its data/fleet.json the
% service-name addresses. Override any single one afterwards:
%
%     cfg = vsConfig();
%     cfg.hosts.d4rt = "ifetch.isr.tecnico.ulisboa.pt:9072";

h = string(a.hostPrefix);

% box -> port, in the order the boxes were added to the registry.
assigned = struct( ...
    'clip',       9061, ...
    'sbert',      9062, ...   % the textEmbedding box
    'tapnext',    9063, ...
    'lang_sam',   9064, ...   % the lang_segm box
    'opencv',     9065, ...
    'vggt',       9066, ...
    'moge',       9067, ...
    'yolo',       9068, ...
    'lightglue',  9069, ...
    'unimatch',   9070, ...
    'features',   9071, ...
    'd4rt',       9072, ...
    'open_clip',  9073, ...
    'sfm',        9074, ...
    'pycv',       9075);      % next new box: 9076

names = string(fieldnames(assigned))';
cfg.hosts = struct();
for k = 1:numel(names)
    cfg.hosts.(names(k)) = h + ":" + string(assigned.(names(k)));
end

if string(a.ports) ~= "legacy"
    warning("vsConfig:portsIgnored", ...
            "'ports' is obsolete: the two conventions have converged on the " + ...
            "registry's permanent port map, which is what you got.");
end

if ~isfile(cfg.runner)
    warning("vsConfig:noRunner", ...
            "visionist_run.py not found at %s - set cfg.runner", cfg.runner);
end
end
