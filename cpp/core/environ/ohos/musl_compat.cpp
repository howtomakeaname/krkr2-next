// musl-compat stubs for OpenHarmony.
//
// OHOS libc does not implement thread cancellation at all: pthread_cancel,
// pthread_setcancelstate and pthread_setcanceltype are absent from both the
// headers and libc.so. Portable code pulled in through vcpkg (SDL2's
// SDL_systhread.c at least) calls the state setters unconditionally, so
// provide no-op definitions so the final link resolves.
#include <pthread.h>

extern "C" {

int pthread_setcancelstate(int state, int *oldstate) {
    if(oldstate)
        *oldstate = PTHREAD_CANCEL_DISABLE;
    return 0;
}

int pthread_setcanceltype(int type, int *oldtype) {
    if(oldtype)
        *oldtype = PTHREAD_CANCEL_DEFERRED;
    return 0;
}

} // extern "C"
