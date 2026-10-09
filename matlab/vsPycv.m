function [out, report] = vsPycv(cfg, varargin)
%VSPYCV Run Python against OpenCV on the pycv box.
%   OUT = VSPYCV(CFG, 'expr', "cv2.Canny(vs.image, 100, 200)", 'images', PATHS)
%   evaluates one expression. OUT = VSPYCV(CFG, 'files', PATHS) sends a set of
%   .py files, one of which must be main.py.
%
%   THIS BOX RUNS THE CODE YOU SEND IT. Anything the container's user can do,
%   your script can do. Point it only at a fleet you trust.
%
%   Name/value
%     'expr'       one expression or a few statements (command eval)
%     'files'      string array of .py paths; one must be named main.py (run)
%     'images'     string array of image paths -> vs.images / vs.image
%     'texts'      string array of literals    -> vs.texts
%     'numbers'    numeric array              -> vs.numbers
%     'inputs'     path to one .npz of named arrays -> vs.inputs
%     'args'       struct of your own arguments     -> vs.args
%     'timeout'    seconds, box default 30, capped at 600
%     'entry'      which sent file to run, box default main.py
%     'max_memory_mb'  box default 2048, 0 disables the cap
%     'decode_images'  logical, box default true
%     'command'    set explicitly to send "reset"
%
%   OUT fields
%     Whatever the script emitted, one variable per vs.emit(name, value):
%     arrays arrive as numeric, bytes are written to disk with the path in
%     <name>_file, JSON values as char in <name>_json.
%     stdout, stderr   always present; the traceback lands in stderr
%     config_json      the box's reply: status, emitted, returncode, runtime
%
%   Reading a .npz the box returned, or building one to send, needs an NPY
%   reader - a .npz is a zip of .npy files, so unzip plus readNPY from
%   npy-matlab (github.com/kwikteam/npy-matlab) does it, and writeNPY plus zip
%   builds one. For most calls you will not need either: images, texts,
%   numbers and 'args' cover the usual arguments.
%
%   Example
%     out = vsPycv(cfg, 'expr', "cv2.Canny(cv2.cvtColor(vs.image, cv2.COLOR_BGR2GRAY), vs.args.lo, vs.args.hi)", ...
%                  'images', "dog.jpg", 'args', struct('lo', 50, 'hi', 150));
%     imagesc(out.result); axis image; colormap gray;
%
%   See also VSOPENCV, VSRUN.

p = inputParser;
p.FunctionName = 'vsPycv';
addParameter(p, 'expr', "");
addParameter(p, 'files', string.empty);
addParameter(p, 'images', string.empty);
addParameter(p, 'texts', string.empty);
addParameter(p, 'numbers', []);
addParameter(p, 'inputs', "");
addParameter(p, 'args', struct());
addParameter(p, 'timeout', []);
addParameter(p, 'entry', "");
addParameter(p, 'max_memory_mb', []);
addParameter(p, 'max_output_mb', []);
addParameter(p, 'decode_images', []);
addParameter(p, 'command', "");
addParameter(p, 'name', "pycv");
parse(p, varargin{:});
a = p.Results;

expr    = string(a.expr);
files   = string(a.files);
command = string(a.command);

if strlength(command) == 0
    if strlength(expr) > 0 && ~isempty(files)
        error("visionist:pycv", "'expr' and 'files' are mutually exclusive");
    elseif strlength(expr) > 0
        command = "eval";
    elseif ~isempty(files)
        command = "run";
    else
        error("visionist:pycv", "give 'expr' or 'files'");
    end
end

entry = string(a.entry);
if strlength(entry) == 0; entry = "main.py"; end
if command == "run"
    names = strings(1, numel(files));
    for k = 1:numel(files)
        [~, nm, ex] = fileparts(files(k));
        names(k) = nm + ex;
    end
    if ~any(names == entry)
        error("visionist:pycv", ...
              "none of the files is named %s (got %s)", entry, strjoin(names, ", "));
    end
end

section = struct('command', command);
if ~isempty(fieldnames(a.args))
    section.args = a.args;
end

params = struct();
params = vsSet(params, 'timeout',       a.timeout);
params = vsSet(params, 'max_memory_mb', a.max_memory_mb);
params = vsSet(params, 'max_output_mb', a.max_output_mb);
params = vsSet(params, 'decode_images', a.decode_images);
if command == "run" && entry ~= "main.py"
    params.entry = entry;
end
if ~isempty(fieldnames(params))
    section.parameters = params;
end

io = struct('name', string(a.name));
if command == "eval"
    io.texts.code = expr;            % one string: the Value `s` kind
elseif command == "run"
    io.files.code = files;
    io.texts.names = names;
end

images = string(a.images);
texts  = string(a.texts);
bundle = string(a.inputs);
if ~isempty(images);    io.files.images  = images;  end
if ~isempty(texts);     io.texts.texts   = texts;   end
if ~isempty(a.numbers); io.numbers.numbers = double(a.numbers(:)'); end
if strlength(bundle) > 0; io.files.inputs = bundle; end

[out, report] = vsRun(cfg, "pycv", section, io);
end
