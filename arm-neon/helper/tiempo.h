/*
 * tiempo.h — versión ARM AArch64
 *
 * Reemplazo del tiempo.h original que usaba RDTSC (x86).
 * Usa clock_gettime(CLOCK_MONOTONIC) para medir tiempo en nanosegundos,
 * que es portable y funciona en cualquier ARM Linux.
 */

#ifndef __TIEMPO_H__
#define __TIEMPO_H__

#include <time.h>

static inline unsigned long long _leer_tiempo_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (unsigned long long)ts.tv_sec * 1000000000ULL + (unsigned long long)ts.tv_nsec;
}

#define MEDIR_TIEMPO(var)                                   \
{                                                           \
    (var) = _leer_tiempo_ns();                              \
}

#define MEDIR_TIEMPO_START(start)                           \
{                                                           \
    /* warm up ... */                                       \
    MEDIR_TIEMPO(start);                                    \
    MEDIR_TIEMPO(start);                                    \
    MEDIR_TIEMPO(start);                                    \
}

#define MEDIR_TIEMPO_STOP(end)                              \
{                                                           \
    MEDIR_TIEMPO(end);                                      \
}

#endif /* !__TIEMPO_H__ */
