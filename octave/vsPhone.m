function [out, report] = vsPhone(cfg, varargin)
%VSPHONE A phone as a capture and annotation terminal (phone box).
%   OUT = VSPHONE(CFG, 'command', 'setup', 'labels', {'door', 'valve'}, ...
%                 'public_url', 'https://lab.example.org') prepares the page a
%   phone opens and returns the pairing link. 'get' polls what the phone
%   captured; 'show' pushes a result (text, an image, a 3D model) back to it.
%
%   The box stores and forwards: it never runs another box. You poll it, run
%   whatever you like on the photos, and show the answer.
%
%   Name/value, by command (an argument for another command is an error)
%     'command'        'get' (default) | 'setup' | 'show' | 'status' | 'reset'
%     'session'        session id               (default: cfg.session_id)
%                      'reset' without 'all' drops just this session
%
%     setup:
%     'title'          heading on the phone page (setup, show: card heading)
%     'labels'         cellstr, one tap-to-toggle button each
%     'mode'           'single' (default) | 'burst'  (several photos at once)
%     'burst_max'      photos per burst, default 8
%     'camera'         'environment' (default, rear) | 'user' (front)
%     'max_side'       the phone shrinks photos to this many px; 0 = original
%     'jpeg_quality'   0.3 .. 1, default 0.9
%     'sensors'        cellstr from {'location','orientation','motion'}
%     'note'           true (default) shows a note field
%     'custom_labels'  true lets the phone user add labels
%     'require_label'  true refuses a photo with no label
%     'public_url'     the page's external URL, e.g. https://lab.example.org/phone
%                      (else the box's PUBLIC_URL; without either there is no
%                      link or QR code, only a relative path)
%     'rotate'         true issues a new token (old phones are refused)
%     'qr'             false skips the QR PNG
%     'qr_scale'       pixels per QR module, 2..32
%
%     get:
%     'after'          only submissions with seq > after  (use reply.next_after)
%     'max_items'      most submissions per reply, 1..64 (default 8)
%     'max_mb'         soft cap on image bytes per reply
%     'wait_s'         block up to this long for a new photo (long poll)
%     'latest'         true -> only the newest
%     'pop'            true -> delete what is returned
%
%     show:
%     'text'           text for the result card
%     'image'          path of a JPEG/PNG/WebP result image
%     'glb'            path of a binary glTF shown as a rotatable 3D view
%     'ref_seq'        the submission this answers ("Re #n")
%     'replace'        true clears the phone's earlier results first
%
%   OUT fields (besides config_json and field_map_json)
%     reply        the box's reply section as a struct: status, and per command
%                  url / token / path / warnings (setup), count / seq /
%                  next_after / pending / dropped (get), card_id (show)...
%     meta         get: one entry per submission - seq, labels, note, device,
%                  sensors, n_images, first_image, mime, bytes, t, client_t
%     images_files get: newline-separated paths of the photos, submissions in
%                  order; meta(i).first_image / .n_images say which are whose
%     images_count get: how many photo files
%     qr_file      setup: path of the pairing QR code PNG
%
%   Things worth knowing
%   1. The link carries the token after '#', so it never reaches a server log.
%   2. Over plain http (not localhost) the phone page cannot show a live
%      preview and offers the phone's own camera app instead; setup warns.
%   3. Everything is held in the box's memory: it is bounded, oldest first,
%      and reply.dropped tells you how many submissions you missed.
%   4. wait_s must stay below cfg.timeout.
%
%   Example
%     r = vsPhone(cfg, 'command', 'setup', 'labels', {'door','valve'}, ...
%                 'public_url', 'https://lab.example.org');
%     disp(r.reply.url)                       % open it on the phone, or scan r.qr_file
%     after = 0;
%     while true
%         g = vsPhone(cfg, 'command', 'get', 'after', after, 'wait_s', 10);
%         after = g.reply.next_after;
%         if g.reply.count == 0, continue, end
%         files = strsplit(strtrim(g.images_files), "\n");
%         % ... run a box on files{1} ...
%         vsPhone(cfg, 'command', 'show', 'text', 'found 2 doors', ...
%                 'ref_seq', g.meta{1}.seq);
%     end
%
%   See also VSMEDIAPIPE, VSYOLO, VSLANGSAM.
p = inputParser;
p.FunctionName = 'vsPhone';
addParameter(p, 'command', 'get');
addParameter(p, 'session', '');
addParameter(p, 'title', '');
addParameter(p, 'labels', {});
addParameter(p, 'mode', '');
addParameter(p, 'burst_max', []);
addParameter(p, 'camera', '');
addParameter(p, 'max_side', []);
addParameter(p, 'jpeg_quality', []);
addParameter(p, 'sensors', {});
addParameter(p, 'note', []);
addParameter(p, 'custom_labels', []);
addParameter(p, 'require_label', []);
addParameter(p, 'public_url', '');
addParameter(p, 'rotate', []);
addParameter(p, 'qr', []);
addParameter(p, 'qr_scale', []);
addParameter(p, 'after', []);
addParameter(p, 'max_items', []);
addParameter(p, 'max_mb', []);
addParameter(p, 'wait_s', []);
addParameter(p, 'latest', []);
addParameter(p, 'pop', []);
addParameter(p, 'text', '');
addParameter(p, 'image', '');
addParameter(p, 'glb', '');
addParameter(p, 'ref_seq', []);
addParameter(p, 'replace', []);
addParameter(p, 'name', 'phone');
parse(p, varargin{:});
a = p.Results;

command = lower(vsChar(a.command));
if ~any(strcmp(command, {'setup', 'get', 'show', 'status', 'reset'}))
    error('visionist:phone', ...
          'command must be setup, get, show, status or reset, got ''%s''', command);
end

% Which arguments belong to which command: one that does not would be
% silently ignored by the box, so refuse it here.
belongs = struct( ...
    'setup', {{'labels', 'mode', 'burst_max', 'camera', 'max_side', 'jpeg_quality', ...
               'sensors', 'note', 'custom_labels', 'require_label', 'public_url', ...
               'rotate', 'qr', 'qr_scale', 'title'}}, ...
    'get',   {{'after', 'max_items', 'max_mb', 'wait_s', 'latest', 'pop'}}, ...
    'show',  {{'title', 'text', 'image', 'glb', 'ref_seq', 'replace'}}, ...
    'status', {{}}, 'reset', {{}});
allArgs = {'labels', 'mode', 'burst_max', 'camera', 'max_side', 'jpeg_quality', ...
           'sensors', 'note', 'custom_labels', 'require_label', 'public_url', ...
           'rotate', 'qr', 'qr_scale', 'title', 'after', 'max_items', 'max_mb', ...
           'wait_s', 'latest', 'pop', 'text', 'image', 'glb', 'ref_seq', 'replace'};
for k = 1:numel(allArgs)
    key = allArgs{k};
    if ~isempty(a.(key)) && ~any(strcmp(key, belongs.(command)))
        error('visionist:phone', '''%s'' does not apply to command ''%s''', key, command);
    end
end
if strcmp(command, 'show') && isempty(vsChar(a.text)) ...
        && isempty(vsChar(a.image)) && isempty(vsChar(a.glb))
    error('visionist:phone', 'show needs at least one of text, image, glb');
end

session = vsChar(a.session);
if isempty(session)
    session = cfg.session_id;
end

% session_id at the top of the section (same contract as yolo and tapnext).
section = struct('command', command, 'session_id', session);

params = struct();
params = vsSet(params, 'title',        vsChar(a.title));
params = vsSet(params, 'labels',       vsCellstr(a.labels));
params = vsSet(params, 'mode',         lower(vsChar(a.mode)));
params = vsSet(params, 'burst_max',    a.burst_max);
params = vsSet(params, 'camera',       lower(vsChar(a.camera)));
params = vsSet(params, 'max_side',     a.max_side);
params = vsSet(params, 'jpeg_quality', a.jpeg_quality);
params = vsSet(params, 'sensors',      vsCellstr(a.sensors));
params = vsSet(params, 'public_url',   vsChar(a.public_url));
params = vsSet(params, 'qr_scale',     a.qr_scale);
params = vsSet(params, 'after',        a.after);
params = vsSet(params, 'max_items',    a.max_items);
params = vsSet(params, 'max_mb',       a.max_mb);
params = vsSet(params, 'wait_s',       a.wait_s);
params = vsSet(params, 'text',         vsChar(a.text));
params = vsSet(params, 'ref_seq',      a.ref_seq);
% Logicals go through vsSet as logicals so jsonencode writes true/false; an
% argument the caller never set must not reach the box at all, and
% logical([]) is NOT empty to vsSet, so the guard is here.
flags = {'note', 'custom_labels', 'require_label', 'rotate', 'qr', 'latest', 'pop', 'replace'};
for k = 1:numel(flags)
    if ~isempty(a.(flags{k}))
        params = vsSet(params, flags{k}, logical(a.(flags{k})));
    end
end
if ~isempty(fieldnames(params))
    section.parameters = params;
end

io = struct('name', vsChar(a.name));
if ~isempty(vsChar(a.image)); io.files.image = vsCellstr(a.image); end
if ~isempty(vsChar(a.glb));   io.files.glb   = vsCellstr(a.glb);   end

[out, report] = vsRun(cfg, 'phone', section, io);

% The box's scalars (url, token, next_after, count...) live in the reply
% section, and its per-submission metadata arrives as JSON: decode both so a
% polling loop does not have to.
if isfield(out, 'config_json')
    try
        whole = jsondecode(out.config_json);
        if isfield(whole, 'phone'); out.reply = whole.phone; end
    catch
    end
end
if isfield(out, 'meta_json')
    try
        out.meta = jsondecode(out.meta_json);
        if isstruct(out.meta); out.meta = num2cell(out.meta); end   % always a cell
    catch
    end
end
end
