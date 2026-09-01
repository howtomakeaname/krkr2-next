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
