# KiriKiri host re-entry regression

This test calls the real engine C API and reads rendered pixels through EGL.
It generates two minimal TJS games with different BMP images, then opens A → B
→ A on successive startup workers in one process, followed by a synchronous B
startup. Each round must render the current game's image before teardown. It also
creates and reads `WaveSoundBuffer.flags`, and parses distinct `first.ks`
files with the same short name to catch invalid helper-class reuse and
scenario text leaking across projects. Script-check failures render black,
so they fail the pixel assertion without opening a platform error dialog.
It needs a graphics-capable environment and a runtime-enabled `engine_api`
library; a stub-only bridge cannot run it. No commercial game assets are used.

```sh
cmake -S bridge/engine_api/tests -B /tmp/krkr-reentry-tests \
  -DENGINE_API_LIBRARY=/absolute/path/to/libengine_api.dylib
cmake --build /tmp/krkr-reentry-tests
ctest --test-dir /tmp/krkr-reentry-tests --output-on-failure
```

Use the corresponding `.so` or import library on other hosts. Keep dependent
shared libraries discoverable by the platform loader. The fixture directory
is generated inside the test build directory.

On HarmonyOS retail devices that disallow shell executables, verify in the
installed Flutter app: cold start → game A → wait for title → exit → game B
→ wait for title → exit → game A. Keep the application process alive between
games. Check the opening animation immediately on the final entry, not just
the title that is loaded later. Missing startup textures can recover when
later scripts load new images, which hides this regression after a long wait.

Also alternate game C → game D → game C → game D in one
process, exiting to the library between games. Verify every title appears and
the last game's New Game button enters a scene that advances on tap. This
sequence exercises the wave flags class and same-name scenario cache with
real projects. Record the process ID to rule out an unnoticed app restart.
Capture memory both in-game and after exit; distinguish RSS, proportional
shared memory (PSS), native heap, and GPU allocations before attributing a
remaining increase to unreleased game objects.
