function [out, report] = vsInternvl(cfg, varargin)
%VSINTERNVL Ask InternVL3 a question about images; get text answers back.
%   OUT = VSINTERNVL(CFG, 'images', PATHS) describes each image.
%   OUT = VSINTERNVL(CFG, 'images', PATHS, 'texts', QUESTIONS) asks QUESTIONS:
%   one question for every image, or one per image, in order.
%   OUT = VSINTERNVL(CFG, 'images', PATHS, 'question', Q, 'mode', 'together')
%   asks one question about all the images at once; the model sees them as
%   Image-1, Image-2, ... and the question can refer to them that way.
%   OUT = VSINTERNVL(CFG, 'command', 'info') says which model the box holds,
%   on which device and in which precision. 'reset' is the standard no-op.
%
%   The model is fixed when the box's image is built (InternVL3-1B by
%   default, or a fine-tuned checkpoint such as OpenFACADES'); there is no
%   model argument. Run one box per model, on different ports.
%
%   Name/value
%     'images'          char or cellstr of image paths (required for 'ask')
%     'texts'           char or cellstr of questions, sent as data
%     'question'        one question, sent as a parameter - use 'texts' or
%                       'question', not both. Neither: 'Describe this image
%                       in detail.'
%     'command'         'ask' (default) | 'info' | 'reset'
%     'mode'            'each' (default): one answer per image
%                       'together': one answer about all the images
%     'max_tiles'       448x448 tiles per image, 1-40 (box default 12). Lower
%                       it first if the GPU runs out of memory.
%     'max_new_tokens'  longest answer in tokens (box default 512)
%     'parse_json'      logical: also return each answer decoded as JSON, for
%                       questions that ask for a JSON record
%     'do_sample'       logical, default false (deterministic answers)
%     'temperature'     with do_sample (box default 0.7)
%     'top_p'           with do_sample (box default 0.9)
%     'batch_size'      images per forward pass in 'each' mode (box default 4)
%
%   OUT fields, 'ask'
%     answers      N x 1 cellstr, one per image ('each') or 1 x 1 ('together')
%     parsed       with 'parse_json': jsondecode of the parsed answers - a
%                  cell array with [] where an answer was not JSON (a struct
%                  array when every answer parsed to the same fields)
%     config_json  the box's reply: model, device, dtype, tiles per image,
%                  num_parsed, runtime
%
%   OUT fields, 'info'
%     info         struct: model, loaded, device, dtype, flash_attn, image_size
%
%   Example
%     out = vsInternvl(cfg, 'images', {'facade1.jpg', 'facade2.jpg'}, ...
%                      'texts', 'What is the main facade material?');
%     out.answers
%
%     q = 'Return JSON only: {"building_type": ..., "floors": <int>}';
%     out = vsInternvl(cfg, 'images', 'facade1.jpg', 'question', q, ...
%                      'parse_json', true);
%     out.parsed
%
%   See also VSOPENCLIP, VSLANGSAM, VSRESET.

p = inputParser;
p.FunctionName = 'vsInternvl';
addParameter(p, 'images', {});
addParameter(p, 'texts', {});
addParameter(p, 'question', '');
addParameter(p, 'command', '');
addParameter(p, 'mode', '');
addParameter(p, 'max_tiles', []);
addParameter(p, 'max_new_tokens', []);
addParameter(p, 'parse_json', []);
addParameter(p, 'do_sample', []);
addParameter(p, 'temperature', []);
addParameter(p, 'top_p', []);
addParameter(p, 'batch_size', []);
addParameter(p, 'name', 'internvl');
parse(p, varargin{:});
a = p.Results;

images   = vsCellstr(a.images);
texts    = vsCellstr(a.texts);
question = vsChar(a.question);
command  = vsChar(a.command);
mode     = lower(vsChar(a.mode));
if isempty(command)
    command = 'ask';
end
if ~any(strcmp(command, {'ask', 'info', 'reset'}))
    error('visionist:internvl', ...
          '''command'' must be ask, info or reset (got %s)', command);
end
if strcmp(command, 'ask')
    if isempty(images)
        error('visionist:internvl', 'command ask needs ''images''');
    end
    if ~isempty(texts) && ~isempty(question)
        error('visionist:internvl', 'give ''texts'' or ''question'', not both');
    end
    if ~isempty(mode) && ~any(strcmp(mode, {'each', 'together'}))
        error('visionist:internvl', ...
              '''mode'' must be each or together (got %s)', mode);
    end
    if strcmp(mode, 'together') && numel(texts) > 1
        error('visionist:internvl', ...
              'mode together takes one question (got %d)', numel(texts));
    end
    if ~strcmp(mode, 'together') && numel(texts) > 1 && numel(texts) ~= numel(images)
        error('visionist:internvl', ...
              '%d questions for %d images: give one, or one per image', ...
              numel(texts), numel(images));
    end
end

section = struct('command', command);

if strcmp(command, 'ask')
    params = struct();
    params = vsSet(params, 'question',       question);
    params = vsSet(params, 'mode',           mode);
    params = vsSet(params, 'max_tiles',      a.max_tiles);
    params = vsSet(params, 'max_new_tokens', a.max_new_tokens);
    if ~isempty(a.parse_json); params.parse_json = logical(a.parse_json); end
    if ~isempty(a.do_sample);  params.do_sample  = logical(a.do_sample);  end
    params = vsSet(params, 'temperature',    a.temperature);
    params = vsSet(params, 'top_p',          a.top_p);
    params = vsSet(params, 'batch_size',     a.batch_size);
    if ~isempty(fieldnames(params))
        section.parameters = params;
    end
end

io = struct('name', vsChar(a.name));
if strcmp(command, 'ask')
    io.files.images = images;
    if ~isempty(texts); io.texts.texts = texts; end
end

[out, report] = vsRun(cfg, 'internvl', section, io);

if isfield(out, 'answers')
    out.answers = vsCellstr(out.answers)';
end
if isfield(out, 'parsed_json')
    out.parsed = jsondecode(out.parsed_json);
end
if strcmp(command, 'info') && isfield(out, 'config_json')
    reply = jsondecode(out.config_json);
    if isfield(reply, 'internvl')
        out.info = reply.internvl;
    end
end
end
