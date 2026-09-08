#pragma once
#include <stdint.h>

#if defined(_WIN32)
#define ARCHIVE_API __declspec(dllexport)
#else
#define ARCHIVE_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// All strings passed across this boundary are UTF-8. The destination must be
// an existing empty task directory inside the authorized root. No overwrite.
typedef struct krkr_archive_status {
  int32_t state;  // 1: working, 2: succeeded, 3: failed, 4: cancelled
  uint32_t files;
  uint64_t completed;
  uint64_t total;
  char current[1024];
  char error[1024];  // Stable wire code, never a translated UI message.
} krkr_archive_status;

ARCHIVE_API void* krkr_archive_start(const char* root, const char* source,
                                    const char* destination, const char* password,
                                    uint32_t legacy_codepage);
ARCHIVE_API void krkr_archive_poll(void* job, krkr_archive_status* status);
ARCHIVE_API void krkr_archive_cancel(void* job);
// Call after a terminal status. Also cancels and joins if called early.
ARCHIVE_API void krkr_archive_destroy(void* job);

#ifdef __cplusplus
}
#endif
