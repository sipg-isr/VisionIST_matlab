function [out, report] = vsOpenClip(cfg, varargin)
%VSOPENCLIP OpenCLIP image and text embeddings, any model, per call.
%   OUT = VSOPENCLIP(CFG, 'images', PATHS, 'texts', PROMPTS) embeds both with
%   the box's default model and returns their cosine similarity and the
%   zero-shot probabilities of each image over the prompts.
%   OUT = VSOPENCLIP(CFG, 'images', PATHS) or (CFG, 'texts', PROMPTS) embeds
%   just one side - unlike vsClip, neither is mandatory.
%   OUT = VSOPENCLIP(CFG, 'command', 'models') lists what the box can load.
%   OUT = VSOPENCLIP(CFG, 'command', 'reset') unloads the models it holds.
%
%   Where vsClip is fixed to OpenAI's ViT-B/32, this picks the model on every
%   call: any (model, pretrained) pair that open_clip knows, or a Hugging Face
%   repo. Embeddings from different pairs live in different spaces and cannot
%   be compared with each other.
%
%   Name/value
%     'images'      cellstr of image paths
%     'texts'       cellstr of prompts
%     'command'     'encode' (default) | 'models' | 'reset'
%     'model'       architecture, e.g. 'ViT-L-14', 'ViT-SO400M-14-SigLIP', or
%                   'hf-hub:org/repo'. 'ViT-B/32' is accepted. For 'models',
%                   restricts the listing to this one model.
%     'pretrained'  checkpoint tag for 'model', e.g. 'datacomp_xl_s13b_b90k',
%                   or a path to a checkpoint on the box. Omit it only for the
%                   box's default model (ViT-B-32 / laion2b_s34b_b79k); any
%                   other model must name its tag.
%     'device'      'auto' (default) | 'cuda' | 'cpu'
%     'normalize'   logical, default true: unit-length embeddings. similarity
%                   and probs are cosine either way.
%     'batch_size'  items per forward pass (box default 32; memory only)
%
%   OUT fields, 'encode'
%     image_emb    num_images x D   (when images were sent; D = 512 for
%                                    ViT-B-32, 768 for ViT-L-14, ...)
%     text_emb     num_texts x D    (when texts were sent)
%     similarity   num_images x num_texts  cosine, in [-1, 1]  (both sent)
%     probs        num_images x num_texts  softmax over the prompts of
%                  logit_scale * similarity; each row sums to 1 (both sent)
%     config_json  the box's reply: model, pretrained, device, embedding_dim,
%                  logit_scale, runtime
%
%   OUT fields, 'models'
%     models       table, one row per (model, pretrained) pair
%     default      struct: model, pretrained the box uses when you name none
%     loaded       struct array of the pairs currently held in memory
%
%   Memory. The box computes in fp32, about 4 bytes per parameter: ViT-L-14
%   needs ~1.7 GB, ViT-H-14 ~3.9 GB, ViT-bigG-14 ~10 GB, on the GPU while the
%   call runs. A model the box has not loaded is downloaded on its first use,
%   so that call is slow; the box keeps one model loaded by default, so
%   alternating models reloads each time.
%
%   These arrive over the numpy codec, so - unlike vsClip - the Python side
%   does not need torch.
%
%   Example
%     out = vsOpenClip(cfg, 'images', {'dog.jpg', 'car.jpg'}, ...
%                      'texts', {'a dog', 'a cat', 'a race car'}, ...
%                      'model', 'ViT-L-14', 'pretrained', 'datacomp_xl_s13b_b90k');
%     [p, best] = max(out.probs, [], 2);        % best prompt per image
%
%     m = vsOpenClip(cfg, 'command', 'models', 'model', 'ViT-L-14');
%     m.models                                  % the tags ViT-L-14 comes in
%
%   Octave build: out.models is a 1xN struct array rather than a MATLAB
%   table; {out.models.model} gives the names.
%
%   See also VSCLIP, VSSBERT, VSRESET.
p = inputParser;
p.FunctionName = 'vsOpenClip';
addParameter(p, 'images', {});
addParameter(p, 'texts', {});
addParameter(p, 'command', '');
addParameter(p, 'model', '');
addParameter(p, 'pretrained', '');
addParameter(p, 'device', '');
addParameter(p, 'normalize', []);
addParameter(p, 'batch_size', []);
addParameter(p, 'name', 'open_clip');
parse(p, varargin{:});
a = p.Results;

images  = vsCellstr(a.images);
texts   = vsCellstr(a.texts);
command = vsChar(a.command);
if isempty(command)
    command = 'encode';
end
if ~any(strcmp(command, {'encode', 'models', 'reset'}))
    error('visionist:openclip', ...
          '''command'' must be encode, models or reset (got %s)', command);
end
if strcmp(command, 'encode') && isempty(images) && isempty(texts)
    error('visionist:openclip', 'give ''images'', ''texts'' or both');
end

section = struct('command', command);

params = struct();
params = vsSet(params, 'model', vsChar(a.model));
if strcmp(command, 'encode')
    params = vsSet(params, 'pretrained', vsChar(a.pretrained));
    params = vsSet(params, 'device',     vsChar(a.device));
    if ~isempty(a.normalize)
        params.normalize = logical(a.normalize);
    end
    params = vsSet(params, 'batch_size', a.batch_size);
end
if ~isempty(fieldnames(params)) && ~strcmp(command, 'reset')
    section.parameters = params;
end

io = struct('name', vsChar(a.name));
if ~isempty(images); io.files.images = images; end
if ~isempty(texts);  io.texts.texts  = texts;  end

[out, report] = vsRun(cfg, 'open_clip', section, io);

if strcmp(command, 'models')
    out = unpackModels(out);
end
end

% ------------------------------------------------------------------------
function out = unpackModels(out)
%UNPACKMODELS Turn the "models" reply into a listing, a default and a loaded
%   set. The model names contain hyphens, which jsondecode would rewrite into
%   different field names (ViT-B-32 -> ViT_B_32), so the listing is read from
%   the raw JSON text where the names are exactly what open_clip uses.
%
%   Octave build: MATLAB returns out.models as a table. Octave has no table,
%   so this returns a 1xN struct array with the same two fields, model and
%   pretrained. {out.models.model} gives the names.
txt = vsChar(out.config_json);

reply = jsondecode(txt);
sec = reply.open_clip;
out.default = sec.default;
if isempty(sec.loaded)
    out.loaded = struct('model', {}, 'pretrained', {});
else
    out.loaded = sec.loaded;
end

% extractBetween is MATLAB-only; regexp gets the same slice.
body = '';
tok = regexp(txt, '"models":(.*?)"num_models"', 'tokens', 'once');
if ~isempty(tok)
    body = tok{1};
end

out.models = struct('model', {}, 'pretrained', {});
if ~isempty(body)
    pairs = regexp(body, '"([^"]+)"\s*:\s*\[([^\]]*)\]', 'tokens');
    for k = 1:numel(pairs)
        tags = regexp(pairs{k}{2}, '"([^"]*)"', 'tokens');
        for j = 1:numel(tags)
            out.models(end+1) = struct('model', pairs{k}{1}, ...
                                       'pretrained', tags{j}{1});  %#ok<AGROW>
        end
    end
end
end
