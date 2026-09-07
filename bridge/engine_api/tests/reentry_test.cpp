#include <array>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

#include "engine_api.h"

namespace fs = std::filesystem;
using Color = std::array<uint8_t, 3>;
static engine_handle_t handle = nullptr;
static void Check(engine_result_t r, const char* call) {
  if (r != ENGINE_RESULT_OK) {
    const char* error = engine_get_last_error(handle);
    throw std::runtime_error(std::string(call) + ": " + std::to_string(r) + " " +
                             (error ? error : ""));
  }
}
static void Fixture(const fs::path& dir, Color color) {
  fs::create_directories(dir);
  std::ofstream script(dir / "startup.tjs");
  std::ofstream scenario(dir / "first.ks");
  scenario << "[probe value=" << int(color[0]) << "]\n";

  script << "var flagsOK = true;\n"
            "try {\nvar wave = new WaveSoundBuffer(null);\n"
            "var flags = wave.flags;\n"
            "if (flags.count != 16) throw 'invalid wave flags';\n"
            "flags.reset();\n} catch (e) { flagsOK = false; Debug.message(e); }\n"
            "var win = new Window();\nwin.setSize(64, 64);\n"
            "var layer = new Layer(win, null);\nlayer.loadImages('probe.bmp');\n"
            "layer.setSize(64, 64);\nlayer.visible = true;\nwin.visible = true;\n"
            "var parser = new KAGParser();\nparser.loadScenario('first.ks');\n"
            "var tag = parser.getNextTag();\n"
            "if (int(tag.value) != "
         << int(color[0])
         << ") {\n"
            "flagsOK = false; Debug.message('wrong scenario value: ' + tag.value); }\n"
            "if (!flagsOK) layer.fillRect(0, 0, 64, 64, 0xff000000);\n";
  std::vector<uint8_t> bmp(54 + 64 * 64 * 3, 0);
  auto put = [&](size_t at, uint32_t value, int bytes) {
    for (int i = 0; i < bytes; ++i) bmp[at + i] = (value >> (8 * i)) & 255;
  };
  bmp[0] = 'B';
  bmp[1] = 'M';
  put(2, bmp.size(), 4);
  put(10, 54, 4);
  put(14, 40, 4);
  put(18, 64, 4);
  put(22, 64, 4);
  put(26, 1, 2);
  put(28, 24, 2);
  for (size_t i = 54; i < bmp.size(); i += 3) {
    bmp[i] = color[2];
    bmp[i + 1] = color[1];
    bmp[i + 2] = color[0];
  }
  std::ofstream image(dir / "probe.bmp", std::ios::binary);
  image.write(reinterpret_cast<const char*>(bmp.data()), bmp.size());
}
static void Session(const fs::path& root, const fs::path& game, Color expected,
                    bool async, int round) {
  const std::string writable = (root / "writable").u8string();
  const std::string game_path = game.u8string();
  const std::string cache = (root / "cache").u8string();
  fs::create_directories(writable);
  fs::create_directories(cache);
  engine_create_desc_t desc{};
  desc.struct_size = sizeof(desc);
  desc.api_version = ENGINE_API_VERSION;
  desc.writable_path_utf8 = writable.c_str();
  desc.cache_path_utf8 = cache.c_str();
  Check(engine_create(&desc, &handle), "create");
  engine_option_t renderer{};
  renderer.key_utf8 = "renderer";
  renderer.value_utf8 = "opengl";
  Check(engine_set_option(handle, &renderer), "renderer");
  Check(engine_set_surface_size(handle, 64, 64), "surface size");
  if (async) {
    Check(engine_open_game_async(handle, game_path.c_str(), nullptr), "async open");
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(30);
    while (true) {
      uint32_t state = 0;
      Check(engine_get_startup_state(handle, &state), "startup state");
      if (state == ENGINE_STARTUP_STATE_SUCCEEDED) break;
      if (state == ENGINE_STARTUP_STATE_FAILED ||
          std::chrono::steady_clock::now() >= deadline)
        throw std::runtime_error("startup failed or timed out");
      std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
  } else
    Check(engine_open_game(handle, game_path.c_str(), nullptr), "sync open");
  for (int i = 0; i < 3; ++i) {
    Check(engine_tick(handle, 16), "tick");
    std::this_thread::sleep_for(std::chrono::milliseconds(16));
  }
  engine_frame_desc_t frame{};
  frame.struct_size = sizeof(frame);
  Check(engine_get_frame_desc(handle, &frame), "frame descriptor");
  if (!frame.width || !frame.height || frame.stride_bytes < frame.width * 4)
    throw std::runtime_error("invalid frame dimensions");
  std::vector<uint8_t> pixels(size_t(frame.stride_bytes) * frame.height);
  Check(engine_read_frame_rgba(handle, pixels.data(), pixels.size()), "frame pixels");
  const auto* center =
      pixels.data() + (frame.height / 2) * frame.stride_bytes + (frame.width / 2) * 4;
  std::cout << "round=" << round << " async=" << async << " center=" << int(center[0])
            << ',' << int(center[1]) << ',' << int(center[2])
            << " expected=" << int(expected[0]) << ',' << int(expected[1]) << ','
            << int(expected[2]) << std::endl;
  for (int c = 0; c < 3; ++c)
    if (std::abs(int(center[c]) - int(expected[c])) > 2)
      throw std::runtime_error(
          "startup image missing or retained from the previous game");
  Check(engine_destroy(handle), "destroy");
  handle = nullptr;
}
int main(int argc, char** argv) {
  try {
    if (argc != 2)
      throw std::runtime_error("usage: engine_reentry_test WRITABLE_TEST_DIRECTORY");
    const fs::path root = fs::absolute(argv[1]);
    const Color a{230, 45, 80}, b{30, 190, 85};
    Fixture(root / "game_a", a);
    Fixture(root / "game_b", b);
    Session(root, root / "game_a", a, true, 1);
    Session(root, root / "game_b", b, true, 2);
    Session(root, root / "game_a", a, true, 3);
    Session(root, root / "game_b", b, false, 4);
    std::cout << "PASS: async A -> B -> A and synchronous re-entry" << std::endl;
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "FAIL: " << error.what() << std::endl;
    if (handle) engine_destroy(handle);
    return 1;
  }
}
