# artemis-compat (vendored)

Upstream: https://github.com/Weiss-UltimateSavior/artemis-compat
Pinned commit: `d23ca4d6df0abd5d305da683971b55a1ae6bd2c0` (2026-09-01, "README: update")
License: GPL-3.0 (`LICENSE`), third-party components per `THIRD_PARTY_NOTICES.md`
(Lua 5.1.5 — MIT; stb_vorbis — public domain / MIT).

Only `src/` (minus `cli/` and `jni/`) and `third_party/` are vendored; the
standalone `lua.c` / `luac.c` interpreters are removed.

## Local patches (keep this list current when re-syncing)

- `src/log/logger.{h,cpp}` — added `artc::SetLogSink()` so the KrKr2-Next
  bridge can mirror engine output into its startup-log queue / engine log
  file; added an OpenHarmony `hilog` output path (tag `Artemis`, domain
  `0x0207`).
- `src/render/compositor.cpp` — the GLES2 compositor is gated on
  `ARTC_HAS_GLES` (auto-defined on Android, set by `cpp/artemis/CMakeLists.txt`
  on OpenHarmony) instead of `__ANDROID__` only.
- `src/audio/audio.cpp` is not compiled on OpenHarmony; the OHAudio backend
  lives in `cpp/artemis/ohos/audio_ohos.cpp` (same `artc::Audio` interface).
- `src/script/lua_engine.cpp` — `e:random()` returns a non-negative integer
  (C `rand()` semantics) instead of a `[0,1)` float; the adv framework uses
  `e:random() % n + 1` (sysvo.lua / config.lua / image.lua), which needs an
  integer to index tables (START on the title screen aborted otherwise).
- `src/script/lua_engine.{h,cpp}` — new `e:loadPngComments(path)` (PNG tEXt /
  iTXt keyword→text table; the framework's `getfgfilepos` reads the
  `comment` = "pos,x,y,…" anchor of face-part sprites, which were otherwise
  drawn at 0,0 and invisible) and a no-op `e:unbindSurface`.
- `src/render/compositor.{h,cpp}` — `EffectiveRect` now composes a proper
  layer transform down the id chain (offset relative to the parent + scale
  about the layer's own anchor; `xscale`/`yscale` parsed as percent, effective
  size returned to Draw/HitLayer) instead of the upstream absolute/inherit
  heuristic that subtracted the anchor. Fixes BGs dragged to -640,-360 by the
  anchored `1.0` root, face parts on positioned character containers, choice
  buttons under positioned parents, and keeps the pull-out toolbar hidden at
  `left=1240` as the real engine does. `Layers()` accessor added for tests.
- `src/script/lua_engine.cpp` — bridge `lua_pcall`s (calllua / lyevent /
  e:tag / DoString) run under a `debug.traceback` handler so framework
  errors log their Lua call chain.
- `src/script/lua_engine.cpp` — `ClickAt` dispatches to the frontmost layer
  that *owns* a click lyevent (id-chain walk) instead of whatever decorative
  child is drawn on top (choice text over its button image);
  `Compositor::HitLayers` added for that.
- `src/script/asb_parser.cpp` — `AsbRunner::Return` reloads the caller's
  script on a cross-file frame (`[call file=system/first.iet …]` from
  script.asb) instead of halting.
- `src/render/compositor.{h,cpp}` — real `[lytween]` tweens (alpha / left /
  top / xscale / yscale / zoom / w / h, delay + easing curves, `lytweendel`
  cancels a subtree) and `[trans]` crossfades (the retained composited scene is
  captured and faded out over the new state; `rule=`
  images drive a thresholded wipe with `vague` softness). `Update(now)` /
  `PendingAnimationMs()` let the host advance animations and make `[wt]` /
  `wait scenario` hold the script for their duration.
- Host-side (bridge/engine_api/artemis_runtime.cpp): `[stop]` halts without
  popping the call frame (`[return]` pops); `[stop exskip]` is a no-op. The
  upstream "stop pops a frame" heuristic let `*main` run past a pending
  choice (`script.asb *select [stop]`), which is what produced the
  `message.lua:535` / `select.lua:500` errors.
- `src/audio/audio.{h,cpp}` + `ohos/audio_ohos.cpp` — `Audio::IsPlaying(key)`.
  `src/script/lua_engine.cpp` — `[wait se=N]` releases when voice N ends,
  `setonsoundfinish`/`delonsoundfinish` fire their Lua callback once the
  voice ends (polled per frame), and a bare `[wait]` (time=0, input=0 — the
  framework's eqwait/trans_flag) waits for the running transition/tween
  instead of blocking until a tap.

- `src/audio/audio_channels.*` — shared logical BGM/SE/voice channels with
  timed gain/pan ramps, overlap for crossfades, and completed-track retirement.
- `src/audio/vorbis_stream.*` — shared block decoder with `_a` intro / `_b`
  continuation support (also for non-looping playback). Android OpenSL ES and
  the HarmonyOS OHAudio backend consume stereo blocks instead of whole-file PCM.
- `src/script/lua_engine.*` — wait input permissions no longer create an
  unconditional wait; mandatory waits survive taps; event filters, wait reasons,
  and dotted callbacks retain balanced Lua stacks. Layer events preserve the
  interrupted runner cursor and wait across script jumps/calls/returns.
- `src/script/asb_parser.*` — common reentrant instruction execution, event
  return frames, and script-stack file enumeration. The host calls `ExecuteLine`
  instead of holding script references across Lua callbacks. App resume shifts
  both active wait deadlines and waits suspended below a menu event.
- `src/render/compositor.*` — retained scene framebuffer for transition
  captures, consistent 0–255 alpha, zero/mirrored scale; em-based text with
  typographic metrics, reserved ruby line spacing, alignment, outline, explicit newlines, and font selection
  per message layer. Text rectangle origins compose with layer translations;
  empty text clears old pixels. `rt` appends a line break.
- Regression fixtures under `../tests` are synthetic scripts/audio and an
  original rectangle-glyph font; no commercial game content is included.
- HarmonyOS-only `../ohos/audio_ohos.cpp` — retire finished voices after the
  submitted frames have been presented; mute and release renderers on a worker
  so OHAudio's blocking Stop does not stall rendering. Log submitted frames and
  renderer underflows when retiring a voice.
- `src/render/compositor.*` — reloading a layer surface adopts the new natural
  dimensions and resets crop UVs, retaining the layer transform. This fixes PNG
  face-expression changes with different bounding boxes; it is not E-mote.
  Tween sets retain sequential segments per property; loop/yoyo counts and
  infinite animation waits no longer lose segments or overflow the wait timer.
- `src/script/input_state.h`, `src/script/lua_engine.*` — key overrides implement
  push/down/down-edge/up-edge/decide bits and -1 restoration. Input is dispatched
  after the frame callback so scripts can suppress a key in that frame. Confirm
  and movie-cancel roles respect overrides. Auto-read waits for text and selected
  voice channels, then the configured reading interval; click/stop can end it.
- `src/render/compositor.*`, `src/render/line_break.h`, `src/script/lua_engine.*`
  — retained pages per message layer, glyph atlases and batched draws, per-glyph
  in-tween timing, click-to-complete before advancing, and ruby ranges/tags.
  Ruby reserves its measured width and wraps with its base. Basic horizontal
  CJK prohibit/hung rules keep brackets and punctuation on suitable lines.
  Mixed style runs, vertical text, full shaping and full ruby semantics remain
  incomplete; do not remove that distinction during an upstream sync.
- `src/audio/pcm_stream.h`, `src/audio/audio.*`, `../ohos/audio_ohos.cpp` — shared
  PCM source interface and playback clocks for movie sound. Platform backends
  supply the presentation position; the common player uses it for frame timing.
- `src/render/video_decoder.*`, `src/render/video_player.*`,
  `src/script/lua_engine.*` — FFmpeg demux/decode from immutable compressed bytes,
  RGBA video and resampled stereo PCM, full-screen/layer playback and loops,
  wait reasons and cancel roles. A shorter sound track does not freeze the video
  at its last audio timestamp. Decoder failures log the failing operation.
- `src/pack/pack_manager.*` — after searching the patch/PFS chain, resolve loose
  files below the directory containing the archive, including `movie/*.mp4`.
  Relative paths are normalized; absolute and parent traversal paths are rejected.
- `src/script/expression.*`, `src/script/lua_engine.*` — evaluate `$` expressions
  and references before tag dispatch, with 32-bit integer operations, logical
  short-circuit, comparisons, strings and variable lookup. Preserve embedded NUL
  bytes in variable values. This fixes the game's video condition checks.
- Outside the vendor tree, `vcpkg/ports/ffmpeg/0002-aarch64-swscale-output-height.patch`
  fixes FFmpeg 3.3.9 NEON conversion wrappers returning zero after writing valid
  rows. The fix belongs to FFmpeg and applies to ARM64, without disabling NEON.
  `../tests/video_decoder_regressions.cpp` and GLES tests use generated movies;
  no commercial movie is committed.

- `src/render/compositor.*` — anchored rotation and independent reverse flags
  compose through the full layer ancestry, including nonuniform scales. Images
  and glyph batches transform their corners; inverse hit tests reject empty
  regions of a rotated bounding box. Uniform zoom respects explicit axis scales.
  Rotation is also a tween property, retaining sequence/loop/yoyo behavior.
- `src/script/lua_engine.cpp`, `src/render/compositor.*` — dragging maps stage
  displacement back into the parent coordinate space before applying local drag
  bounds, and updates both axes. Singular transforms ignore pointer movement.

Current save persistence and the Lua-source Pluto subset are **not** compatible
with original `BOWS` engine snapshots. Full key roles/skip, shader semantics,
E-mote, complex typography and native snapshot restoration remain incomplete.
See `doc/artemis-compatibility-audit.md` at the repository root for validation
scope and the distinction between host and signed HarmonyOS device tests.
