#!/usr/bin/env bash
#
# build_ohos.sh — One-step build script for krkr2 OpenHarmony (Flutter)
#
# Usage:
#   ./build_ohos.sh [debug|release]
#
# Output: Flutter OHOS HAP with bundled native engine and archive library
#   apps/flutter_app/build/ohos/hap/entry-default-signed.hap        (local signing config)
#   apps/flutter_app/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap
#
# This script will:
#   1. Resolve the toolchain (OpenHarmony Flutter fork, DevEco Studio SDK,
#      ohpm/hvigor/node, DevEco's bundled JBR for hvigor's hap packager)
#   2. Build libengine_api.so and libfile_archive.so with the OpenHarmony
#      NDK (API 20 sysroot) through the vcpkg arm64-ohos toolchain
#   3. Strip and stage them with libc++_shared.so/libomp.so into
#      entry/libs/arm64-v8a (hvigor packs that directory into the HAP)
#   4. Run `flutter build hap` and accept only a HAP written by this run
#      whose packaged .so build IDs match the staged libraries
#
# Environment overrides:
#   FLUTTER_OHOS_DIR   OpenHarmony Flutter fork (default: sibling of repo)
#   DEVECO_SDK_HOME    DevEco SDK (default: /Applications/DevEco-Studio.app/Contents/sdk)
#   OHOS_NDK           OpenHarmony native SDK used for the engine (default: ~/Library/OpenHarmony/Sdk/20/native)
#   OHOS_NATIVE_BUILD  CMake build directory (default: build/ohos/file-manager-native)
#   VCPKG_TOOLCHAIN    vcpkg.cmake (default: this or the sibling KrKr2-Next checkout)
#   VCPKG_INSTALLED_DIR prebuilt arm64-ohos vcpkg packages

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
HAP_UNSIGNED="$PROJECT_ROOT/apps/flutter_app/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap"
# hvigor writes a signed HAP here when app/signingConfigs has a local
# 'default' entry (kept out of git); otherwise only the unsigned HAP exists.
HAP_SIGNED="$PROJECT_ROOT/apps/flutter_app/build/ohos/hap/entry-default-signed.hap"

# Every artifact must be newer than this marker. A HAP or .so left over from
# an earlier run is never accepted as the result of this build.
BUILD_STAMP="$(mktemp "${TMPDIR:-/tmp}/krkr-ohos-build.XXXXXX")"
trap 'rm -f "$BUILD_STAMP"' EXIT

echo "==> flutter: $(command -v flutter)"
echo "==> DEVECO_SDK_HOME=$DEVECO_SDK_HOME"
echo "==> OHOS_NDK=$OHOS_NDK"
echo "==> HEAD=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [[ -n "$(git -C "$PROJECT_ROOT" status --porcelain --untracked-files=no 2>/dev/null)" ]]; then
    echo "==> working tree has uncommitted tracked changes"
fi

for f in "$FLUTTER_OHOS_DIR/bin/flutter" "$DEVECO_SDK_HOME" "$TOOLCHAIN_FILE"; do
    [[ -e "$f" ]] || { echo "Error: missing $f"; exit 1; }
done

# ============================================================
# 1. Native engine (libengine_api.so) via vcpkg + CMake
# ============================================================
NINJA_BUILD="${OHOS_NATIVE_BUILD:-$PROJECT_ROOT/build/ohos/file-manager-native}"
VCPKG_TOOLCHAIN="${VCPKG_TOOLCHAIN:-}"
if [[ -z "$VCPKG_TOOLCHAIN" ]]; then
    for candidate in \
        "$PROJECT_ROOT/.devtools/vcpkg/scripts/buildsystems/vcpkg.cmake" \
        "$(cd "$PROJECT_ROOT/.." && pwd)/KrKr2-Next/.devtools/vcpkg/scripts/buildsystems/vcpkg.cmake"
    do
        if [[ -f "$candidate" ]]; then
            VCPKG_TOOLCHAIN="$candidate"
            break
        fi
    done
fi
[[ -f "$VCPKG_TOOLCHAIN" ]] || { echo "Error: vcpkg toolchain not found"; exit 1; }
VCPKG_TRIPLET="${VCPKG_TRIPLET:-arm64-ohos}"
VCPKG_INSTALLED_DIR="${VCPKG_INSTALLED_DIR:-/private/tmp/krkr-artemis-native-build/vcpkg_installed}"
echo "==> [1/3] building libengine_api.so and libfile_archive.so ($BUILD_TYPE_LOWER)"
echo "==> VCPKG_TOOLCHAIN=$VCPKG_TOOLCHAIN"
echo "==> VCPKG_INSTALLED_DIR=$VCPKG_INSTALLED_DIR"
echo "==> NINJA_BUILD=$NINJA_BUILD"
cmake -S "$PROJECT_ROOT" -B "$NINJA_BUILD" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_TOOLCHAIN_FILE="$VCPKG_TOOLCHAIN" \
    -DOHOS_STL=c++_shared \
    -DOHOS_ARCH=arm64-v8a \
    -DOHOS_PLATFORM=OHOS \
    -DOHOS_PLATFORM_LEVEL=20 \
    -DVCPKG_TARGET_TRIPLET="$VCPKG_TRIPLET" \
    -DVCPKG_INSTALLED_DIR="$VCPKG_INSTALLED_DIR" \
    -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
    -DBUILD_ENGINE_API=ON \
    -DBUILD_FILE_ARCHIVE=ON \
    -DBUILD_TOOLS=OFF \
    -DENABLE_TESTS=OFF \
    -DKRKR2_ENABLE_ARTEMIS=ON \
    -DARTC_ENABLE_FFMPEG=ON
cmake --build "$NINJA_BUILD" --target engine_api file_archive

ENGINE_SO="$NINJA_BUILD/bridge/engine_api/libengine_api.so"
ARCHIVE_SO="$NINJA_BUILD/bridge/file_archive/libfile_archive.so"
[[ -f "$ENGINE_SO" ]] || { echo "Error: $ENGINE_SO not built"; exit 1; }
[[ -f "$ARCHIVE_SO" ]] || { echo "Error: $ARCHIVE_SO not built"; exit 1; }
# file_archive must expose only its own C ABI; a second copy of the 7-Zip
# symbols next to libengine_api.so would be resolved by load order.
if "$OHOS_NDK/llvm/bin/llvm-nm" -D --defined-only "$ARCHIVE_SO" | grep -q ' GetNumberOfFormats$'; then
    echo "Error: $ARCHIVE_SO exports 7-Zip symbols; check the version script"
    exit 1
fi
for so in "$ENGINE_SO" "$ARCHIVE_SO"; do
    echo "==> $(basename "$so") $("$OHOS_NDK/llvm/bin/llvm-readelf" -n "$so" | grep -a 'Build ID' | head -1)"
done

# ============================================================
# 2. Stage native libraries for the HAP
# ============================================================
echo "==> [2/3] staging native libs into entry/libs/arm64-v8a"
mkdir -p "$LIBS_OUT"
"$OHOS_NDK/llvm/bin/llvm-strip" --strip-unneeded "$ENGINE_SO" -o "$LIBS_OUT/libengine_api.so"
"$OHOS_NDK/llvm/bin/llvm-strip" --strip-unneeded "$ARCHIVE_SO" -o "$LIBS_OUT/libfile_archive.so"
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
# `flutter build hap` can exit non-zero while app/signingConfigs is empty
# (debug-signing precheck) after hvigor has written the unsigned HAP.
# Treat a missing or incomplete artifact as failure — never `|| true`.
set +e
flutter build hap "--$BUILD_TYPE_LOWER"
hap_status=$?
set -e

HAP_OUT=""
for candidate in "$HAP_SIGNED" "$HAP_UNSIGNED"; do
    if [[ -f "$candidate" && "$candidate" -nt "$BUILD_STAMP" ]]; then
        HAP_OUT="$candidate"
        break
    fi
done
if [[ -z "$HAP_OUT" ]]; then
    echo "Error: no HAP newer than this build was produced (flutter exit $hap_status)"
    exit 1
fi

echo "OK: $HAP_OUT (flutter exit $hap_status)"
ls -la "$HAP_OUT"
for so in libengine_api.so libfile_archive.so; do
    if ! unzip -l "$HAP_OUT" | grep -q "libs/arm64-v8a/$so"; then
        echo "Error: $HAP_OUT is missing $so"
        exit 1
    fi
done
# The packaged copies must be the ones staged by this run, not older files
# hvigor happened to find. Compare the GNU build IDs.
HAP_CHECK="$(mktemp -d "${TMPDIR:-/tmp}/krkr-hap-check.XXXXXX")"
unzip -q -o "$HAP_OUT" 'libs/arm64-v8a/libengine_api.so' 'libs/arm64-v8a/libfile_archive.so' -d "$HAP_CHECK"
for so in libengine_api.so libfile_archive.so; do
    staged="$("$OHOS_NDK/llvm/bin/llvm-readelf" -n "$LIBS_OUT/$so" | grep -a 'Build ID')"
    packed="$("$OHOS_NDK/llvm/bin/llvm-readelf" -n "$HAP_CHECK/libs/arm64-v8a/$so" | grep -a 'Build ID')"
    if [[ -z "$staged" || "$staged" != "$packed" ]]; then
        echo "Error: $so inside the HAP does not match the staged build ($staged vs $packed)"
        rm -rf "$HAP_CHECK"
        exit 1
    fi
    echo "OK: $so $packed"
done
rm -rf "$HAP_CHECK"
echo "OK: HAP contains this build's libengine_api.so and libfile_archive.so"
