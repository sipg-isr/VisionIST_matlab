function [out, report] = vsMediapipe(cfg, varargin)
%VSMEDIAPIPE MediaPipe hand, pose and face landmarks (mediapipe box).
%   OUT = VSMEDIAPIPE(CFG, 'images', A) returns the 21 hand landmarks of
%   every hand found in A. 'command' picks the model: hands, pose or face.
%
%   Name/value
%     'images'                   one or more image paths
%     'command'                  'hands' (default) | 'pose' | 'face' | 'reset'
%     'max_results'              hands/poses/faces to look for
%                                (box defaults: 2 hands, 1 pose, 1 face)
%     'model'                    'lite' (default) | 'full' | 'heavy'  (pose only)
%     'coordinates'              'normalized' (default) | 'pixels'
%     'min_detection_confidence' box default 0.5
%     'min_presence_confidence'  box default 0.5
%     'min_tracking_confidence'  box default 0.5 (VIDEO mode only, unused today)
%     'blendshapes'              true to also get the 52 expression scores (face)
%     'transformation_matrix'    true to also get the 4x4 matrix       (face)
%
%   OUT fields
%     landmarks        n_images x M x L x 3, as (x, y, z).  L is 21 (hands),
%                      33 (pose) or 478 (face)
%     counts           n_images x 1, how many of the M rows are real
%     world_landmarks  the same shape, in metres            (hands, pose)
%     handedness       n_images x M, 0 left, 1 right, -1 padding  (hands)
%     scores           n_images x M, confidence of that label      (hands)
%     visibility       n_images x M x 33, per-landmark             (pose)
%     blendshapes      n_images x M x 52                 (face, if asked)
%     blendshape_names the 52 names, in column order      (face, if asked)
%     transformation_matrixes  n_images x M x 4 x 4       (face, if asked)
%
%   Three things worth knowing before you plot anything:
%
%   1. LANDMARKS IS PADDED. M is the largest detection count in the batch,
%      so rows past counts(i) are zeros - and a zero is a legal position.
%      Always slice with counts: L1 = squeeze(out.landmarks(1, 1:out.counts(1), :, :));
%   2. COORDINATES ARE NORMALIZED to [0, 1] and ordered (x, y, z), with z on
%      roughly the same scale as x. That is the opposite order from vsTapnext,
%      which reports (y, x), and a different unit from vsOpencv, which reports
%      pixels. Pass 'coordinates', 'pixels' to get image units.
%   3. HANDEDNESS IS LABELLED AS SEEN. A webcam frame that was not
%      un-mirrored reports the opposite hand.
%
%   world_landmarks is the metric one (metres, origin at the hand centre or
%   the hips). The face model has none - use transformation_matrixes instead.
%
%   Example
%     out = vsMediapipe(cfg, 'images', frame, 'command', 'pose', ...
%                       'model', 'heavy', 'coordinates', 'pixels');
%     xy  = squeeze(out.landmarks(1, 1, :, 1:2));   % 33x2 pixels
%
%   See also VSOPENCV, VSTAPNEXT, VSYOLO.
p = inputParser;
p.FunctionName = 'vsMediapipe';
addParameter(p, 'images', {});
addParameter(p, 'command', 'hands');
addParameter(p, 'max_results', []);
addParameter(p, 'model', '');
addParameter(p, 'coordinates', '');
addParameter(p, 'min_detection_confidence', []);
addParameter(p, 'min_presence_confidence', []);
addParameter(p, 'min_tracking_confidence', []);
addParameter(p, 'blendshapes', []);
addParameter(p, 'transformation_matrix', []);
addParameter(p, 'name', 'mediapipe');
parse(p, varargin{:});
a = p.Results;

images  = vsCellstr(a.images);
command = lower(vsChar(a.command));
if ~any(strcmp(command, {'hands', 'pose', 'face', 'reset'}))
    error('visionist:mediapipe', ...
          'command must be hands, pose, face or reset, got ''%s''', command);
end
if isempty(images) && ~strcmp(command, 'reset')
    error('visionist:mediapipe', '%s needs at least one image', command);
end
if ~isempty(vsChar(a.model)) && ~strcmp(command, 'pose')
    error('visionist:mediapipe', ...
          '''model'' picks the pose bundle and only applies to command ''pose''');
end
if (~isempty(a.blendshapes) || ~isempty(a.transformation_matrix)) ...
        && ~strcmp(command, 'face')
    error('visionist:mediapipe', ...
          '''blendshapes'' and ''transformation_matrix'' only apply to command ''face''');
end

section = struct('command', command);

params = struct();
params = vsSet(params, 'max_results',              a.max_results);
params = vsSet(params, 'model',                    lower(vsChar(a.model)));
params = vsSet(params, 'coordinates',              lower(vsChar(a.coordinates)));
params = vsSet(params, 'min_detection_confidence', a.min_detection_confidence);
params = vsSet(params, 'min_presence_confidence',  a.min_presence_confidence);
params = vsSet(params, 'min_tracking_confidence',  a.min_tracking_confidence);
% Logicals go through vsSet as logicals so jsonencode writes true/false; an
% argument the caller never set must not reach the box at all, and
% logical([]) is NOT empty to vsSet, so the guard is here.
if ~isempty(a.blendshapes)
    params = vsSet(params, 'blendshapes', logical(a.blendshapes));
end
if ~isempty(a.transformation_matrix)
    params = vsSet(params, 'transformation_matrix', logical(a.transformation_matrix));
end
if ~isempty(fieldnames(params))
    section.parameters = params;
end

io = struct('name', vsChar(a.name));
if ~isempty(images); io.files.images = images; end

[out, report] = vsRun(cfg, 'mediapipe', section, io);
end
