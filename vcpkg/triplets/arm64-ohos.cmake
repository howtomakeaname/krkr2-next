# OpenHarmony (OHOS) arm64 triplet for krkr2-next.
#
# Chainloads the OHOS NDK toolchain shipped with the HarmonyOS SDK
# (~/Library/OpenHarmony/Sdk/<api>/native/build/cmake/ohos.toolchain.cmake).
# The SDK path is provided through the OHOS_NATIVE_SDK env var (see
# build/build_ohos.sh) so the triplet itself stays machine-independent.
#
# Mirrors arm64-android.cmake: static third-party libs, dynamic libc++.

set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME OHOS)
set(VCPKG_CMAKE_SYSTEM_VERSION 20)
set(VCPKG_MAKE_BUILD_TRIPLET "--host=aarch64-linux-ohos")

if(NOT DEFINED ENV{OHOS_NATIVE_SDK})
    message(FATAL_ERROR "arm64-ohos triplet requires the OHOS_NATIVE_SDK env var pointing at the HarmonyOS 'native' SDK dir")
endif()

set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "$ENV{OHOS_NATIVE_SDK}/build/cmake/ohos.toolchain.cmake")

# The OHOS toolchain passes --gcc-toolchain unconditionally; clang flags it
# as unused when compiling pure C (no libgcc lookup). Ports that build with
# -Werror (libarchive, opencv, ...) would turn that into a hard error, so
# disable the warning outright for every port.
set(VCPKG_C_FLAGS "-Wno-unused-command-line-argument")
set(VCPKG_CXX_FLAGS "-Wno-unused-command-line-argument")
set(VCPKG_CMAKE_CONFIGURE_OPTIONS
    -DOHOS_ARCH=arm64-v8a
    -DOHOS_PLATFORM=OHOS
    -DOHOS_STL=c++_shared
    -DOHOS_PLATFORM_LEVEL=20
)
