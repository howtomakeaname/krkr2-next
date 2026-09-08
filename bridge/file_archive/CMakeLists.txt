cmake_minimum_required(VERSION 3.19)
project(file_archive LANGUAGES C CXX)

# Standalone native tests may build the exact vendored 7-Zip sources without
# bringing up a renderer or the engine runtime.
if(SEVENZIP_SOURCE_DIR)
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)
    add_subdirectory("${SEVENZIP_SOURCE_DIR}" sevenzip)
    add_library(7zip::7zip ALIAS 7zip)
    target_include_directories(7zip INTERFACE "${SEVENZIP_SOURCE_DIR}/CPP" "${SEVENZIP_SOURCE_DIR}/C")
else()
    find_package(7zip CONFIG REQUIRED)
endif()

add_library(file_archive SHARED archive_api.cpp)
target_compile_features(file_archive PRIVATE cxx_std_17)
target_include_directories(file_archive PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
# Archive and codec registration uses static constructors. Keep the registrars
# even if no individual format handler is referenced by this translation unit.
# Link 7-Zip only once: Apple force_load or ELF whole-archive. A second
# ordinary archive link duplicates every codec symbol on lld.
# Whole-archive linking would otherwise re-export every 7-Zip symbol. Both
# this library and libengine_api.so carry their own 7-Zip, so restrict the
# dynamic symbol table to the krkr_archive_* ABI and let each copy bind to
# itself regardless of dlopen order or RTLD_GLOBAL.
if(APPLE)
    target_link_libraries(file_archive PRIVATE 7zip::7zip)
    target_link_options(file_archive PRIVATE
        "LINKER:-force_load,$<TARGET_FILE:7zip::7zip>"
        "LINKER:-exported_symbols_list,${CMAKE_CURRENT_SOURCE_DIR}/exports.apple.txt")
    set_property(TARGET file_archive APPEND PROPERTY LINK_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/exports.apple.txt")
else()
    target_link_libraries(file_archive PRIVATE "-Wl,--whole-archive" 7zip::7zip "-Wl,--no-whole-archive")
    target_link_options(file_archive PRIVATE
        "LINKER:--version-script=${CMAKE_CURRENT_SOURCE_DIR}/exports.map"
        "LINKER:--exclude-libs,ALL")
    set_property(TARGET file_archive APPEND PROPERTY LINK_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/exports.map")
endif()
set_target_properties(file_archive PROPERTIES CXX_VISIBILITY_PRESET hidden VISIBILITY_INLINES_HIDDEN YES)

