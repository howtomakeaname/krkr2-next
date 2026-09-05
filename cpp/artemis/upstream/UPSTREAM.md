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
  cancels a subtree) and `[trans]` crossfades (last composited frame is
  captured with glCopyTexImage2D and faded out over the new state; `rule=`
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
