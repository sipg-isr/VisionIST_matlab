function [out, report] = vsSbert(cfg, varargin)
%VSSBERT Sentence-BERT text embeddings (the textEmbedding box).
%   OUT = VSSBERT(CFG, 'texts', STRINGS) embeds each string and returns the
%   pairwise similarity matrix.
%
%   The box's config section is 'sbert', not 'textEmbedding' - the directory
%   name and the section name differ for this one box.
%
%   Name/value
%     'texts'    cellstr of sentences (required)
%     'command'  omit to encode, or 'reset'
%
%   OUT fields
%     embeddings    num_texts x 384 (all-MiniLM-L6-v2, fixed)
%     similarities  num_texts x num_texts pairwise cosine similarity
%
%   Decoded over the torch codec, so the Python side needs torch installed.
%
%   Example
%     out = vsSbert(cfg, 'texts', {'a dog runs', 'a puppy sprints', 'tax law'});
%     imagesc(out.similarities); colorbar;
%
%   See also VSCLIP.

p = inputParser;
p.FunctionName = 'vsSbert';
addParameter(p, 'texts', {});
addParameter(p, 'command', '');
addParameter(p, 'name', 'sbert');
parse(p, varargin{:});
a = p.Results;

texts   = vsCellstr(a.texts);
command = vsChar(a.command);
if ~strcmp(command, 'reset') && isempty(texts)
    error('visionist:sbert', '''texts'' is required');
end

section = struct();
if ~isempty(command)
    section.command = command;
else
    section.command = 'encode';
end

io = struct('name', vsChar(a.name));
if ~isempty(texts); io.texts.texts = texts; end

[out, report] = vsRun(cfg, 'sbert', section, io);
end
