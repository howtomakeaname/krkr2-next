/**
 * @file artemis_runtime.cpp
 * @brief Artemis Engine backend for the engine_api C bridge.
 *
 * The frame loop is a port of the upstream Android host
 * (artemis-compat/src/jni/native_activity.cpp: EngineThreadMain/BootScene)
 * re-shaped into a host-driven Tick(): the Flutter ticker calls us once
 * per vsync instead of the engine owning a thread, and presentation goes
 * through krkr::EGLContextManager (pbuffer readback or native window) so
 * the Dart side sees exactly the same frame contract as the krkr2 core.
 */
#include "artemis_runtime.h"

#include <algorithm>
#include <cctype>
#include <cstring>
#include <deque>
#include <dirent.h>
#include <memory>
#include <mutex>
#include <string>
#include <sys/stat.h>
#include <utility>
#include <vector>

#include <EGL/egl.h>
#include <GLES2/gl2.h>

#include "config/ini.h"
#include "log/logger.h"
#include "pack/pack_manager.h"
#include "render/compositor.h"
#include "script/asb_parser.h"
#include "script/iet_interpreter.h"
#include "script/lua_engine.h"

#include "visual/ogl/krkr_egl_context.h"

namespace krkr2_artemis {

namespace {

std::string ToLower(std::string s) {
  for (auto& c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  return s;
}

bool EndsWith(const std::string& s, const std::string& suffix) {
  return s.size() >= suffix.size() &&
         s.compare(s.size() - suffix.size(), suffix.size(), suffix) == 0;
}

bool IsDirectory(const std::string& path) {
  struct stat st {};
  return ::stat(path.c_str(), &st) == 0 && S_ISDIR(st.st_mode);
}

bool IsRegularFile(const std::string& path) {
  struct stat st {};
  return ::stat(path.c_str(), &st) == 0 && S_ISREG(st.st_mode);
}

std::string StripTrailingSlash(std::string p) {
  while (p.size() > 1 && (p.back() == '/' || p.back() == '\\')) p.pop_back();
  return p;
}

std::string DirName(const std::string& p) {
  const size_t slash = p.find_last_of("/\\");
  return slash == std::string::npos ? std::string(".") : p.substr(0, slash);
}

// Base packs are `<name>.pfs`; patch volumes `<name>.pfs.000` … are picked
// up by PackManager::OpenChain and must not be treated as roots.
std::vector<std::string> ListBasePacks(const std::string& dir) {
  std::vector<std::string> found;
  DIR* d = ::opendir(dir.c_str());
  if (d == nullptr) return found;
  while (dirent* ent = ::readdir(d)) {
    const std::string name = ent->d_name;
    if (EndsWith(ToLower(name), ".pfs")) found.push_back(dir + "/" + name);
  }
  ::closedir(d);
  // Deterministic preference: root.pfs first, then alphabetical.
  std::sort(found.begin(), found.end(), [](const std::string& a, const std::string& b) {
    const bool ra = EndsWith(ToLower(a), "/root.pfs");
    const bool rb = EndsWith(ToLower(b), "/root.pfs");
    if (ra != rb) return ra;
    return a < b;
  });
  return found;
}

// Official key ids (advkey.def): touch/tap = 1 (mouse left), BS = 8, Enter = 13.
constexpr int kKeyTap = 1;
constexpr int kKeyBack = 8;

int HostKeyToArtemis(int32_t key_code) {
  // The Flutter host sends `LogicalKeyboardKey.keyId & 0xFFFFFFFF`; for the
  // keys the framework binds (advkey.def) that is the ASCII/Unicode plane
  // value or the low bits of the 0x1_0000_03xx arrow-key ids.
  switch (key_code) {
    case 0x0d:   // enter
      return 13;
    case 0x304:  // arrowUp
      return 38;
    case 0x301:  // arrowDown
      return 40;
    case 0x302:  // arrowLeft
      return 37;
    case 0x303:  // arrowRight
      return 39;
    case 0x08:   // backspace
      return kKeyBack;
    case 0x1b:   // escape
      return 27;
    case 0x20:   // space
      return 32;
    default:
      return -1;
  }
}

}  // namespace

bool LooksLikeArtemisGame(const std::string& raw_path, std::string* out_pack_path) {
  if (raw_path.empty()) return false;
  const std::string path = StripTrailingSlash(raw_path);
  if (EndsWith(ToLower(path), ".pfs")) {
    if (!IsRegularFile(path)) return false;
    if (out_pack_path != nullptr) *out_pack_path = path;
    return true;
  }
  if (!IsDirectory(path)) return false;
  const std::vector<std::string> packs = ListBasePacks(path);
  if (packs.empty()) return false;
  if (out_pack_path != nullptr) *out_pack_path = packs.front();
  return true;
}

struct ArtemisRuntime::Impl {
  LogFn log;

  // ---- game state ----
  std::string pack_path;
  std::string save_dir;
  artc::PackManager packs;
  artc::Ini ini;
  int stage_w = 1280;
  int stage_h = 720;
  std::string os_name = "android";

  artc::Compositor compositor;
  artc::AsbRunner runner;
  std::unique_ptr<artc::LuaEngine> lua;
  bool booted = false;
  bool open = false;
  bool paused = false;

  // ---- GL / presentation ----
  bool owns_egl = false;
  bool gl_lost = false;
  uint64_t drawn_revision = ~0ull;
  bool frame_dirty = false;
  std::vector<uint8_t> frame_rgba;
  uint32_t native_win_w = 0;
  uint32_t native_win_h = 0;
  uint64_t tick_count = 0;

  // ---- input ----
  struct RawInput {
    bool is_key = false;
    bool is_move = false;
    int key = 0;
    bool down = false;
    float x = 0;
    float y = 0;
  };
  std::mutex input_mutex;
  std::deque<RawInput> input_events;

  void Log(const std::string& line) {
    if (log) log(line);
  }

  bool EnsureEgl(std::string* error);
  bool MakeCurrent(std::string* error);
  bool Boot(std::string* error);
  void ReleaseLua();
  void DrainQueuedTags();
  void ProcessInput();
  void StepScript();
  void StageFromWindow(float wx, float wy, float* sx, float* sy) const;
  void Present();
  bool ReadbackFrame();
};

ArtemisRuntime::ArtemisRuntime(LogFn log) : impl_(new Impl) {
  impl_->log = std::move(log);
}

ArtemisRuntime::~ArtemisRuntime() { Close(); }

// ---------------------------------------------------------------------------
// EGL
// ---------------------------------------------------------------------------

bool ArtemisRuntime::Impl::EnsureEgl(std::string* error) {
  auto& egl = krkr::GetEngineEGLContext();
  const uint32_t w = static_cast<uint32_t>(stage_w);
  const uint32_t h = static_cast<uint32_t>(stage_h);
  if (!egl.IsValid()) {
    // Nothing else owns a context (or a previous krkr2 session tore its
    // context down): create the headless pbuffer at stage resolution so
    // the RawImage readback returns the game's native frame.
    if (!egl.Initialize(w, h)) {
      if (error) *error = "artemis: EGL pbuffer context initialization failed";
      return false;
    }
    owns_egl = true;
    Log("artemis: created EGL pbuffer context " + std::to_string(w) + "x" + std::to_string(h));
    return true;
  }
  // Reuse the live context (a krkr2 game ran earlier in this process). The
  // krkr2 runtime cannot be restarted in-process, so resizing its pbuffer
  // to our stage size is safe.
  if (!egl.HasNativeWindow() && (egl.GetWidth() != w || egl.GetHeight() != h)) {
    if (!egl.Resize(w, h)) {
      if (error) *error = "artemis: EGL pbuffer resize failed";
      return false;
    }
  }
  if (!egl.MakeCurrent()) {
    if (error) *error = "artemis: eglMakeCurrent failed on shared context";
    return false;
  }
  Log("artemis: reusing existing EGL context");
  return true;
}

bool ArtemisRuntime::Impl::MakeCurrent(std::string* error) {
  auto& egl = krkr::GetEngineEGLContext();
  if (!egl.IsValid()) {
    if (error) *error = "artemis: EGL context is not initialized";
    return false;
  }
  if (!egl.MakeCurrent()) {
    if (error) *error = "artemis: failed to make EGL context current";
    return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Boot chain — port of native_activity.cpp BootScene()
// ---------------------------------------------------------------------------

void ArtemisRuntime::Impl::ReleaseLua() {
  // The Lua engine owns the audio backend; dropping it stops every voice.
  lua.reset();
  booted = false;
}

bool ArtemisRuntime::Impl::Boot(std::string* error) {
  compositor.ReleaseGl();
  compositor.SetPackManager(&packs);
  compositor.Init(stage_w, stage_h);  // builds the GLES2 program (ctx current)
  compositor.SetPresent(nullptr);     // presentation is driven by Tick()

  lua = std::make_unique<artc::LuaEngine>();
  lua->SetSaveDir(save_dir);
  if (!lua->Init(&packs, ini, os_name, stage_w, stage_h, &compositor)) {
    if (error) *error = "artemis: Lua engine initialization failed";
    ReleaseLua();
    return false;
  }
  Log("artemis: lua ready; running system/first.iet");
  artc::IetRunner iet(&packs, lua.get());
  if (!iet.Run("system/first.iet")) {
    if (error) *error = "artemis: system/first.iet missing or unreadable";
    ReleaseLua();
    return false;
  }
  if (iet.Stopped()) Log("artemis: boot script hit [stop]");

  runner = artc::AsbRunner();
  runner.SetPackSource(&packs);
  artc::AsbRunner* r = &runner;
  artc::LuaEngine* l = lua.get();
  lua->SetJumpHandler([this, r](const std::string& file, const std::string& label) {
    if (r->Returning()) {
      Log("asb: skip jump while returning: " + label);
      return;
    }
    r->Jump(file, label);
  });
  lua->SetCallHandler([this, r](const std::string& file, const std::string& label) {
    if (r->Returning()) {
      Log("asb: skip call while returning: " + label);
      return;
    }
    r->Call(file, label);
  });
  lua->SetStopHandler([this, r](const std::string& tag) {
    // [stop] halts the script until an explicit jump/call re-enters it
    // (choice screens park at `script.asb *select [stop]` inside the estag
    // call frame and resume through `jump select_exit → [return]`);
    // [return] pops the call frame. Popping on `stop` — the upstream
    // heuristic — let the main loop run past a pending choice.
    if (tag == "stop") {
      r->Halt();
      Log("asb: stop via lua tag (halt)");
      return;
    }
    if (!r->Return()) {
      r->Halt();
      Log("asb: " + tag + " via lua tag");
    }
  });

  booted = true;
  drawn_revision = ~0ull;  // force a readback of the first composed frame
  Log("artemis: boot sequence finished, adv framework active");
  return true;
}

bool ArtemisRuntime::Open(const std::string& game_path, std::string* error) {
  Impl& s = *impl_;
  if (s.open) {
    if (error) *error = "artemis: runtime already open";
    return false;
  }
  std::string pack_path;
  if (!LooksLikeArtemisGame(game_path, &pack_path)) {
    if (error) *error = "artemis: no .pfs pack found at " + game_path;
    return false;
  }
  s.pack_path = pack_path;
  s.save_dir = DirName(pack_path);
  s.Log("artemis: pack chain base: " + pack_path);

  if (!s.packs.OpenChain(pack_path, {})) {
    if (error) *error = "artemis: cannot open pf8 pack chain (unknown key/format): " + pack_path;
    return false;
  }
  s.Log("artemis: pack chain opened: " + std::to_string(s.packs.Packs().size()) +
        " pack(s), first pack " +
        std::to_string(s.packs.Packs().empty() ? 0u : s.packs.Packs()[0]->FileCount()) +
        " file(s)");

  std::vector<uint8_t> ini_bytes;
  if (s.packs.Read("system.ini", ini_bytes)) {
    s.ini.Parse(std::string(ini_bytes.begin(), ini_bytes.end()));
  } else {
    s.Log("artemis: system.ini not found in pack; using 1280x720 defaults");
  }
  // Stage resolution: the mobile section carries the stage size on every
  // title we know of; fall back to WINDOWS when a PC-only pack omits it.
  int w = s.ini.GetInt("ANDROID", "WIDTH", 0);
  int h = s.ini.GetInt("ANDROID", "HEIGHT", 0);
  if (w <= 0 || h <= 0) {
    w = s.ini.GetInt("WINDOWS", "WIDTH", 1280);
    h = s.ini.GetInt("WINDOWS", "HEIGHT", 720);
  }
  s.stage_w = std::max(1, w);
  s.stage_h = std::max(1, h);
  s.Log("artemis: stage " + std::to_string(s.stage_w) + "x" + std::to_string(s.stage_h) +
        " os=" + s.os_name + " save_dir=" + s.save_dir);

  if (!s.EnsureEgl(error)) return false;

  const bool ok = s.Boot(error);
  // Startup runs on a worker thread; release the context so the owner
  // thread can make it current before ticking (same as the krkr2 path).
  krkr::GetEngineEGLContext().ReleaseCurrent();
  if (!ok) {
    return false;
  }
  s.open = true;
  return true;
}

// ---------------------------------------------------------------------------
// Frame loop — port of native_activity.cpp EngineThreadMain()
// ---------------------------------------------------------------------------

void ArtemisRuntime::Impl::DrainQueuedTags() {
  // Drain the enqueueTag queue at a command boundary. A queued "wait"
  // (eqwait) engages the wait here, which stops further draining.
  while (lua && !lua->IsWaiting() && lua->HasQueuedTag()) {
    std::string name;
    std::vector<std::pair<std::string, std::string>> attrs;
    if (!lua->PopQueuedTag(&name, &attrs)) break;
    if (name == "jump" || name == "call") {
      std::string file, label;
      for (const auto& kv : attrs) {
        if (kv.first == "file") file = kv.second;
        else if (kv.first == "label") label = kv.second;
      }
      if (runner.Returning()) {
        Log("asb: skip queued [" + name + "] while returning");
      } else {
        runner.Jump(file, label);
      }
    } else {
      lua->DispatchTag(name, attrs);
    }
  }
}

void ArtemisRuntime::Impl::StageFromWindow(float wx, float wy, float* sx, float* sy) const {
  // Pbuffer mode: the host reads the stage-sized frame back and maps
  // pointer positions onto it itself, so coordinates arrive in stage space.
  if (native_win_w == 0 || native_win_h == 0) {
    *sx = wx;
    *sy = wy;
    return;
  }
  // Native window mode: letterbox the stage into the window (SIDECUT=0).
  const float sw = static_cast<float>(native_win_w) / stage_w;
  const float sh = static_cast<float>(native_win_h) / stage_h;
  const float scale = sw < sh ? sw : sh;
  const float vp_w = stage_w * scale;
  const float vp_h = stage_h * scale;
  const float vp_x = (native_win_w - vp_w) * 0.5f;
  const float vp_y = (native_win_h - vp_h) * 0.5f;
  *sx = (wx - vp_x) / vp_w * stage_w;
  *sy = (wy - vp_y) / vp_h * stage_h;
}

void ArtemisRuntime::Impl::ProcessInput() {
  std::deque<RawInput> batch;
  {
    std::lock_guard<std::mutex> lk(input_mutex);
    batch.swap(input_events);
  }
  if (!lua) return;
  int touch_count = 0;
  bool tapped = false;
  float tap_x = 0, tap_y = 0;
  for (const auto& ev : batch) {
    if (ev.is_key) {
      if (ev.down) lua->PushKeyDown(ev.key);
      else lua->PushKeyUp(ev.key);
      continue;
    }
    float sx = 0, sy = 0;
    StageFromWindow(ev.x, ev.y, &sx, &sy);
    if (ev.is_move) {
      lua->SetMousePoint(sx, sy);
      lua->DragMove(sx, sy);
      continue;
    }
    lua->SetMousePoint(sx, sy);
    if (ev.down) {
      lua->PushKeyDown(kKeyTap);
      touch_count = 1;
      lua->BeginDrag(sx, sy);
    } else {
      lua->PushKeyUp(kKeyTap);
      touch_count = 0;
      const bool was_dragging = lua->DragActive();
      lua->EndDrag();
      if (!was_dragging) {  // a clean tap, not a drag
        tapped = true;
        tap_x = sx;
        tap_y = sy;
      }
    }
    lua->SetTouchCount(touch_count);
  }
  // Hit-test taps against lyevent-registered layers (framework buttons).
  if (tapped && lua) lua->ClickAt(tap_x, tap_y);
}

void ArtemisRuntime::Impl::StepScript() {
  if (!lua) return;
  if (runner.Loaded() && !runner.Halted() && !lua->IsWaiting()) {
    for (int steps = 0; steps < 4 && runner.Loaded() && !runner.Halted(); ++steps) {
      runner.ClearReturning();  // a return was resolved last line
      const artc::AsbLine& ln = runner.Current();
      if (ln.is_label) {
        runner.Advance();
      } else if (ln.command == "\x02LUA") {
        for (const auto& kv : ln.attrs)
          if (kv.first == "code") lua->DoString(kv.second, "asb:lua");
        runner.Advance();
      } else if (ln.command == "calllua") {
        for (const auto& kv : ln.attrs)
          if (kv.first == "function") lua->CallGlobal(kv.second);
        runner.Advance();
      } else if (ln.command == "jump") {
        std::string lbl;
        for (const auto& kv : ln.attrs)
          if (kv.first == "label") lbl = kv.second;
        runner.JumpTo(lbl);
      } else if (ln.command == "stop" && ln.attrs.empty()) {
        // Halt in place; the call frame (if any) stays for the [return]
        // that the resuming flow issues later (select_exit / dialog).
        runner.Halt();
        Log("asb: [stop] reached (halt)");
      } else if (ln.command == "stop") {
        // `[stop exskip]` (script.asb *movie_play) stops the fast-forward
        // mode, not the script — nothing to do natively.
        runner.Advance();
      } else if (ln.command == "return") {
        if (!runner.Return()) {
          runner.Halt();
          Log("asb: [return] reached (halt)");
        }
      } else {
        lua->DispatchTag(ln.command, ln.attrs);
        runner.Advance();
      }
      // command-boundary queue processing (estag chains)
      DrainQueuedTags();
      if (lua->IsWaiting()) break;
    }
  } else if (!lua->IsWaiting() && lua->HasQueuedTag()) {
    // runner not loaded yet: still process queued tags (the boot estag03
    // chain enqueued by first.iet starts the asb runner).
    DrainQueuedTags();
  }
}

bool ArtemisRuntime::Impl::ReadbackFrame() {
  const uint32_t w = static_cast<uint32_t>(stage_w);
  const uint32_t h = static_cast<uint32_t>(stage_h);
  const size_t row_bytes = static_cast<size_t>(w) * 4u;
  const size_t needed = row_bytes * h;
  if (frame_rgba.size() != needed) frame_rgba.assign(needed, 0);

  glFinish();
  glPixelStorei(GL_PACK_ALIGNMENT, 4);
  glReadPixels(0, 0, static_cast<GLsizei>(w), static_cast<GLsizei>(h), GL_RGBA,
               GL_UNSIGNED_BYTE, frame_rgba.data());
  if (glGetError() != GL_NO_ERROR) return false;

  // GL rows are bottom-up; the host expects top-down.
  std::vector<uint8_t> tmp(row_bytes);
  uint8_t* bytes = frame_rgba.data();
  for (uint32_t y = 0; y < h / 2u; ++y) {
    uint8_t* top = bytes + static_cast<size_t>(y) * row_bytes;
    uint8_t* bottom = bytes + static_cast<size_t>(h - 1u - y) * row_bytes;
    std::memcpy(tmp.data(), top, row_bytes);
    std::memcpy(top, bottom, row_bytes);
    std::memcpy(bottom, tmp.data(), row_bytes);
  }
  return true;
}

void ArtemisRuntime::Impl::Present() {
  auto& egl = krkr::GetEngineEGLContext();
  const bool to_window = egl.HasNativeWindow() && native_win_w > 0 && native_win_h > 0;
  const uint64_t rev = compositor.Revision();
  if (!to_window && rev == drawn_revision) {
    // Static frame: the pbuffer still holds identical pixels; skip both
    // the GL pass and the readback (same gate as the krkr2 software path).
    frame_dirty = false;
    return;
  }

  // Reset the pieces of GL state the compositor relies on implicitly
  // (client-side vertex arrays, default framebuffer).
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glDisable(GL_SCISSOR_TEST);
  glDisable(GL_DEPTH_TEST);
  glDisable(GL_CULL_FACE);

  if (to_window) {
    // Letterbox the stage into the window (SIDECUT=0 semantics).
    const float sw = static_cast<float>(native_win_w) / stage_w;
    const float sh = static_cast<float>(native_win_h) / stage_h;
    const float scale = sw < sh ? sw : sh;
    const int vp_w = static_cast<int>(stage_w * scale);
    const int vp_h = static_cast<int>(stage_h * scale);
    const int vp_x = (static_cast<int>(native_win_w) - vp_w) / 2;
    const int vp_y = (static_cast<int>(native_win_h) - vp_h) / 2;
    glViewport(0, 0, static_cast<GLsizei>(native_win_w), static_cast<GLsizei>(native_win_h));
    glClearColor(0.f, 0.f, 0.f, 1.f);
    glClear(GL_COLOR_BUFFER_BIT);
    glViewport(vp_x, vp_y, vp_w, vp_h);
    compositor.Draw();
    if (!eglSwapBuffers(egl.GetDisplay(), egl.GetWindowSurface())) {
      Log("artemis: eglSwapBuffers failed: 0x" + std::to_string(eglGetError()));
    }
    drawn_revision = rev;
    frame_dirty = true;
    return;
  }

  glViewport(0, 0, stage_w, stage_h);
  glClearColor(0.f, 0.f, 0.f, 1.f);
  glClear(GL_COLOR_BUFFER_BIT);
  compositor.Draw();
  if (ReadbackFrame()) {
    drawn_revision = rev;
    frame_dirty = true;
  } else {
    Log("artemis: glReadPixels failed");
    frame_dirty = false;
  }
}

ArtemisRuntime::TickStatus ArtemisRuntime::Tick(std::string* error) {
  Impl& s = *impl_;
  if (!s.open) {
    if (error) *error = "artemis: runtime is not open";
    return TickStatus::kError;
  }
  s.tick_count += 1;
  s.frame_dirty = false;
  if (!s.MakeCurrent(error)) return TickStatus::kError;

  // [reset] tag = engine reboot (language-select flow ends this way):
  // drop the Lua session so the boot chain re-runs now.
  if (s.lua && s.lua->ConsumeResetRequest()) {
    s.Log("artemis: engine reset requested; re-running boot chain");
    s.ReleaseLua();
    if (!s.Boot(error)) return TickStatus::kError;
  }
  // [exit] tag = the framework's go_exit (title exit → dialog YES).
  if (s.lua && s.lua->ConsumeExitRequest()) {
    s.Log("artemis: engine exit requested");
    return TickStatus::kExitRequested;
  }
  if (!s.booted) {
    if (!s.Boot(error)) return TickStatus::kError;
  }

  if (s.paused) {
    // Keep presenting the last frame but freeze the script/input clocks.
    return TickStatus::kOk;
  }

  // 1) input → Lua key state, 2) per-frame Lua work (framework vsync),
  // 3) native script execution, 4) present.
  s.ProcessInput();
  if (s.lua) {
    s.lua->RunEnterFrame();
    s.DrainQueuedTags();  // input-dispatched calllua may enqueue (estag call etc.)
  }
  s.StepScript();
  // Advance [lytween] / [trans] animations to this frame's time before
  // compositing (bumps the layer revision while anything is moving).
  if (s.lua) s.compositor.Update(s.lua->NowMs());
  s.Present();
  if (s.lua) s.lua->EndFrame();  // clear per-frame edges

  if (s.tick_count % 600 == 0) {
    s.Log("artemis: tick=" + std::to_string(s.tick_count) +
          " waiting=" + std::to_string(s.lua && s.lua->IsWaiting() ? 1 : 0) +
          " runner=" + std::to_string(s.runner.Loaded() ? 1 : 0) +
          (s.runner.Halted() ? " halted" : "") +
          " rev=" + std::to_string(s.compositor.Revision()) +
          " draw: " + s.compositor.DescribeDrawList(24));
  }
  return TickStatus::kOk;
}

void ArtemisRuntime::QueueInput(const engine_input_event_t& event) {
  Impl& s = *impl_;
  Impl::RawInput ev;
  switch (event.type) {
    case ENGINE_INPUT_EVENT_POINTER_DOWN:
      ev.down = true;
      ev.x = static_cast<float>(event.x);
      ev.y = static_cast<float>(event.y);
      break;
    case ENGINE_INPUT_EVENT_POINTER_MOVE:
      ev.is_move = true;
      ev.x = static_cast<float>(event.x);
      ev.y = static_cast<float>(event.y);
      break;
    case ENGINE_INPUT_EVENT_POINTER_UP:
      ev.down = false;
      ev.x = static_cast<float>(event.x);
      ev.y = static_cast<float>(event.y);
      break;
    case ENGINE_INPUT_EVENT_BACK: {
      // BACK → BS (MWOFF / EXIT per advkey.def): press + release edge.
      Impl::RawInput down;
      down.is_key = true;
      down.key = kKeyBack;
      down.down = true;
      Impl::RawInput up = down;
      up.down = false;
      std::lock_guard<std::mutex> lk(s.input_mutex);
      s.input_events.push_back(down);
      s.input_events.push_back(up);
      return;
    }
    case ENGINE_INPUT_EVENT_KEY_DOWN:
    case ENGINE_INPUT_EVENT_KEY_UP: {
      const int key = HostKeyToArtemis(event.key_code);
      if (key < 0) return;
      ev.is_key = true;
      ev.key = key;
      ev.down = event.type == ENGINE_INPUT_EVENT_KEY_DOWN;
      break;
    }
    default:
      return;  // scroll / text input have no Artemis equivalent
  }
  std::lock_guard<std::mutex> lk(s.input_mutex);
  s.input_events.push_back(ev);
  if (s.input_events.size() > 512) s.input_events.pop_front();
}

void ArtemisRuntime::Pause() {
  Impl& s = *impl_;
  if (s.paused) return;
  s.paused = true;
  if (s.lua) s.lua->PauseAudio();
}

void ArtemisRuntime::Resume() {
  Impl& s = *impl_;
  if (!s.paused) return;
  s.paused = false;
  if (s.lua) s.lua->ResumeAudio();
}

void ArtemisRuntime::Close() {
  Impl& s = *impl_;
  if (!s.open && !s.lua && !s.owns_egl) return;
  auto& egl = krkr::GetEngineEGLContext();
  const bool current = egl.IsValid() && egl.MakeCurrent();
  s.ReleaseLua();
  if (current) {
    s.compositor.Shutdown();  // frees textures + program on the live context
  }
  s.runner = artc::AsbRunner();
  s.frame_rgba.clear();
  s.open = false;
  if (egl.IsValid()) {
    if (egl.HasNativeWindow()) egl.DetachNativeWindow();
    if (s.owns_egl) {
      egl.Destroy();
      s.Log("artemis: destroyed EGL context");
    } else {
      egl.ReleaseCurrent();
    }
  }
  s.owns_egl = false;
  s.native_win_w = s.native_win_h = 0;
}

bool ArtemisRuntime::IsOpen() const { return impl_->open; }
uint32_t ArtemisRuntime::StageWidth() const { return static_cast<uint32_t>(impl_->stage_w); }
uint32_t ArtemisRuntime::StageHeight() const { return static_cast<uint32_t>(impl_->stage_h); }

bool ArtemisRuntime::ConsumeFrameDirty() {
  const bool d = impl_->frame_dirty;
  impl_->frame_dirty = false;
  return d;
}

const std::vector<uint8_t>& ArtemisRuntime::FrameRgba() const { return impl_->frame_rgba; }

bool ArtemisRuntime::AttachNativeWindow(void* window, uint32_t width, uint32_t height) {
  Impl& s = *impl_;
  auto& egl = krkr::GetEngineEGLContext();
  if (!egl.IsValid() || window == nullptr || width == 0 || height == 0) return false;
  if (!egl.AttachNativeWindow(window, width, height)) return false;
  s.native_win_w = width;
  s.native_win_h = height;
  s.drawn_revision = ~0ull;  // redraw into the new surface
  s.Log("artemis: attached native window " + std::to_string(width) + "x" + std::to_string(height));
  return true;
}

void ArtemisRuntime::DetachNativeWindow() {
  Impl& s = *impl_;
  auto& egl = krkr::GetEngineEGLContext();
  if (egl.IsValid() && egl.HasNativeWindow()) egl.DetachNativeWindow();
  s.native_win_w = s.native_win_h = 0;
  s.drawn_revision = ~0ull;
}

bool ArtemisRuntime::HasNativeWindow() const {
  return impl_->native_win_w > 0 && impl_->native_win_h > 0;
}

void ArtemisRuntime::UpdateNativeWindowSize(uint32_t width, uint32_t height) {
  Impl& s = *impl_;
  if (!HasNativeWindow()) return;
  s.native_win_w = width;
  s.native_win_h = height;
  krkr::GetEngineEGLContext().UpdateNativeWindowSize(width, height);
  s.drawn_revision = ~0ull;
}

std::string ArtemisRuntime::RendererInfo() {
  std::string err;
  if (!impl_->MakeCurrent(&err)) return "Artemis compat | (no GL context)";
  const char* r = reinterpret_cast<const char*>(glGetString(GL_RENDERER));
  const char* v = reinterpret_cast<const char*>(glGetString(GL_VERSION));
  return std::string("Artemis compat | ") + (r ? r : "(unknown)") + " | " + (v ? v : "(unknown)");
}

}  // namespace krkr2_artemis
