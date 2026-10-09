# Octave build of the VisionIST MATLAB client

The functions in this folder are the same client as the one in
[`../matlab`](../matlab), rewritten to run under **GNU Octave**. Same function names, same
arguments, same wire payloads — verified byte-for-byte against the box
contract by `vsSelfTest`.

```matlab
addpath('octave');                 % not ../matlab: the names collide
cfg = vsConfig();
out = vsYolo(cfg, 'video', 'clip.mp4', 'frame_step', 30, 'conf', 0.4);
vsSelfTest                         % 26 checks, no fleet needed
```

Tested on Octave 8.4. `visionist_run.py` in the repository root is the bridge,
shared with the MATLAB build and unchanged — it is plain Python and never
needed porting.

## Why a separate build was unavoidable

Octave does not implement MATLAB's `string` class, and is not planning to.
That is not one missing function but a different data model, and the MATLAB
client is built on it:

| MATLAB | under Octave |
|---|---|
| `"a" + ":" + "b"` | **arithmetic on character codes** — silently wrong, no error |
| `["a" "b"]` | a 1x4 `char`, not a 2-element list |
| `strlength`, `string`, `contains`, `table`, `strings` | not implemented |
| `arguments ... end` blocks | parse error |

The first two are the dangerous ones: they produce a wrong answer rather than
an error, so a shim could not paper over them. Everything here therefore uses
`char` and `cellstr`.

## What changes for a caller

**Lists of text are cellstr.** Where the MATLAB build takes `["a.jpg"
"b.jpg"]`, pass `{'a.jpg', 'b.jpg'}`. A single value can stay a bare
`'a.jpg'`.

**Single values are char.** `'reset'`, not `"reset"`.

Both builds accept either when run on their own interpreter: `vsChar` and
`vsCellstr` normalise char, cellstr *and* MATLAB strings, so these files also
run unchanged in MATLAB. `../matlab` remains the MATLAB build; this one is the
portable one.

**Two return types differ**, because Octave has no `table`:

| | MATLAB | here |
|---|---|---|
| `vsProbe(cfg)` with no box | table | 1xN struct array, fields `box`, `host`, `reachable` |
| `vsOpenClip(..., 'command', 'models')` → `out.models` | table | 1xN struct array, fields `model`, `pretrained` |

```matlab
info = vsProbe(cfg);
down = {info(~[info.reachable]).box};        % the boxes that did not answer
```

**Video reading needs ffmpeg.** `VideoReader` does not exist in Octave, so
`vsTrackStream` and the walkthrough's trajectory plot shell out to `ffmpeg`
(on `PATH`). Passing frames yourself as a cellstr of image paths avoids it
entirely. Everything else — `imshow`, `imread`, `imagesc`, `quiver`,
`scatter`, `subplot` — is core Octave; the `image` package is loaded if
present but nothing here requires it.

## What did not change

The config JSON on the wire, field for field, including the three places the
contract is easy to get wrong:

- `lang_sam`'s `text_prompt` sits at the **top of the section**, as a JSON
  array even for one phrase
- `session_id` sits at the top of the section for `yolo` and `tapnext`, but
  **inside `parameters`** for `lightglue`
- a one-element list parameter stays a JSON **array**: `'classes', 16` sends
  `"classes":[16]`, and `'attn_splits_list', 2` sends `[2]` — Octave's
  `jsonencode` agrees with MATLAB's on `{16}` vs `16`, which is what makes
  this work

`vsObservation` is the same computation, checked on fixtures with a known
answer: both association modes, the NaN-gap bridging that distinguishes them,
and the empty-stream case.

## Files

```
vsChar.m  vsCellstr.m        text normalisers: the whole `string` port, really
vsContainsAny.m  vsSplitLines.m   the two missing string builtins used here
vsSelfTest.m                 26 checks against a stub bridge - run after any change
vsConfig.m  vsRun.m  vsHost.m  vsSet.m  vsProbe.m  vsReset.m      the core
vsClip  vsD4rt  vsFeatures  vsLangSam  vsLightglue  vsMoge        one per box
vsOpenClip  vsOpencv  vsPycv  vsSbert  vsTapnext  vsUnimatch  vsVggt  vsYolo
vsTrackStream.m  vsObservation.m   stream -> tracks -> observation matrix
visionist_walkthrough.m      the five demos, as a plain script
```

No box has a `vsSfm.m` in either build yet; `cfg.hosts.sfm` is configured
(port 9074) so a call can be made through `vsRun` directly.

## Keeping the two in step

A change to a box's contract has to land in both folders. The files are
deliberately line-for-line comparable — `diff ../matlab/vsYolo.m vsYolo.m` is
small and readable, and the differences are only the ones this README lists. After
any change here, run `vsSelfTest`; it fails loudly on a payload that drifted.
