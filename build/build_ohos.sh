#!/usr/bin/env bash
#
# build_ohos.sh — One-step build script for krkr2 OpenHarmony (Flutter)
#
# Usage:
#   ./build_ohos.sh [debug|release]
#
# Output: Flutter OHOS HAP with bundled native engine
#   apps/flutter_app/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap
#
# This script will:
#   1. Resolve the toolchain (OpenHarmony Flutter fork, DevEco Studio SDK,
#      ohpm/hvigor/node, DevEco's bundled JBR for hvigor's hap packager)
#   2. Build libengine_api.so with the OpenHarmony NDK (API 20 sysroot)
#   3. Strip it and stage it with libc++_shared.so/libomp.so into
#      entry/libs/arm64-v8a (hvigor packs that directory into the HAP)
#   4. Run `flutter build hap` (exits non-zero on the debug-signing check —
#      unsigned HAPs install fine on OpenHarmony emulator/dev images, so the
#      script treats "HAP produced" as success)
#
# Environment overrides:
#   FLUTTER_OHOS_DIR   OpenHarmony Flutter fork (default: sibling of repo)
#   DEVECO_SDK_HOME    DevEco SDK (default: /Applications/DevEco-Studio.app/Contents/sdk)
#   OHOS_NDK           OpenHarmony native SDK used for the engine (default: ~/Library/OpenHarmony/Sdk/20/native)

set -euo pipefail

# ============================================================
# Configuration
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BUILD_TYPE="${1:-debug}"
BUILD_TYPE_LOWER="$(echo "$BUILD_TYPE" | tr '[:upper:]' '[:lower:]')"
if [[ "$BUILD_TYPE_LOWER" != "debug" && "$BUILD_TYPE_LOWER" != "release" ]]; then
    echo "Error: Invalid build type '$BUILD_TYPE'. Use 'debug' or 'release'."
    exit 1
fi

FLUTTER_OHOS_DIR="${FLUTTER_OHOS_DIR:-$(cd "$PROJECT_ROOT/.." && pwd)/flutter_flutter_ohos}"
DEVECO_APP="${DEVECO_APP:-/Applications/DevEco-Studio.app}"
DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-$DEVECO_APP/Contents/sdk}"
OHOS_NDK="${OHOS_NDK:-$HOME/Library/OpenHarmony/Sdk/20/native}"

export PATH="$FLUTTER_OHOS_DIR/bin:$DEVECO_APP/Contents/tools/ohpm/bin:$DEVECO_APP/Contents/tools/hvigor/bin:$DEVECO_APP/Contents/tools/node/bin:$PATH"
export DEVECO_SDK_HOME
export NODE_HOME="${NODE_HOME:-$DEVECO_APP/Contents/tools/node}"
# hvigor's HAP packager is a Java tool; DevEco ships a JBR for exactly this.
export JAVA_HOME="${JAVA_HOME:-$DEVECO_APP/Contents/jbr/Contents/Home}"

TOOLCHAIN_FILE="$OHOS_NDK/build/cmake/ohos.toolchain.cmake"
LIBS_OUT="$PROJECT_ROOT/apps/flutter_app/ohos/entry/libs/arm64-v8a"
HAP_OUT="$PROJECT_ROOT/apps/flutter_app/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap"

echo "==> flutter: $(command -v flutter)"
echo "==> DEVECO_SDK_HOME=$DEVECO_SDK_HOME"
echo "==> OHOS_NDK=$OHOS_NDK"

for f in "$FLUTTER_OHOS_DIR/bin/flutter" "$DEVECO_SDK_HOME" "$TOOLCHAIN_FILE"; do
    [[ -e "$f" ]] || { echo "Error: missing $f"; exit 1; }
done

# ============================================================
# 1. Native engine (libengine_api.so) via vcpkg + CMake
# ============================================================
NINJA_BUILD="$PROJECT_ROOT/build/ohos/cmake-build"
VCPKG_TOOLCHAIN="$PROJECT_ROOT/.devtools/vcpkg/scripts/buildsystems/vcpkg.cmake"
VCPKG_TRIPLET="${VCPKG_TRIPLET:-arm64-ohos}"
echo "==> [1/3] building libengine_api.so ($BUILD_TYPE_LOWER)"
cmake -S "$PROJECT_ROOT" -B "$NINJA_BUILD" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_TOOLCHAIN_FILE="$VCPKG_TOOLCHAIN" \
    -DOHOS_STL=c++_shared \
    -DOHOS_ARCH=arm64-v8a \
    -DOHOS_PLATFORM=OHOS \
    -DVCPKG_TARGET_TRIPLET="$VCPKG_TRIPLET" \
    -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="$TOOLCHAIN_FILE"
cmake --build "$NINJA_BUILD" --target engine_api

ENGINE_SO="$NINJA_BUILD/bridge/engine_api/libengine_api.so"
[[ -f "$ENGINE_SO" ]] || { echo "Error: $ENGINE_SO not built"; exit 1; }

# ============================================================
# 2. Stage native libraries for the HAP
# ============================================================
echo "==> [2/3] staging native libs into entry/libs/arm64-v8a"
mkdir -p "$LIBS_OUT"
"$OHOS_NDK/llvm/bin/llvm-strip" --strip-unneeded "$ENGINE_SO" -o "$LIBS_OUT/libengine_api.so"
cp -f "$OHOS_NDK/llvm/lib/aarch64-linux-ohos/libc++_shared.so" "$LIBS_OUT/"
cp -f "$OHOS_NDK/llvm/lib/aarch64-linux-ohos/libomp.so" "$LIBS_OUT/"
ls -la "$LIBS_OUT"

# ============================================================
# 3. Flutter HAP
# ============================================================
echo "==> [3/3] flutter build hap --$BUILD_TYPE_LOWER"
cd "$PROJECT_ROOT/apps/flutter_app"
# Enable the OHOS dependency overrides (kept out of pubspec.yaml so other
# platforms build from a fresh clone without the sibling packages checkout).
cp -f pubspec_overrides.ohos.yaml pubspec_overrides.yaml
flutter pub get
# `flutter build hap` always exits non-zero while app/signingConfigs is empty
# (its debug-signing precheck), but hvigor has already produced the unsigned
# HAP by then — verify the artifact instead of the exit code.
flutter build hap "--$BUILD_TYPE_LOWER" || true

if [[ -f "$HAP_OUT" ]]; then
    echo "OK: $HAP_OUT"
    ls -la "$HAP_OUT"
else
    echo "Error: HAP was not produced"
    exit 1
fi
