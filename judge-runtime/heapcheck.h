/*
 * heapcheck.h - portable heap checker used by the judge ONLY when the compiler
 * has no AddressSanitizer/LeakSanitizer runtime (e.g. MinGW gcc on Windows).
 *
 * It is force-included into the submission with `-include heapcheck.h` and
 * heapcheck.c is linked alongside. On Linux/WSL/Docker the judge uses the real
 * -fsanitize=address,undefined (which includes LeakSanitizer) instead.
 *
 * Detects: memory leaks (exit code 23), double free, invalid free, heap buffer
 * overflow/underflow (redzones), write-after-free (quarantine poisoning).
 */
#ifndef CSIM_HEAPCHECK_H
#define CSIM_HEAPCHECK_H

#include <stdlib.h>

void *csim_hc_malloc(size_t n, const char *file, int line);
void *csim_hc_calloc(size_t count, size_t size, const char *file, int line);
void *csim_hc_realloc(void *p, size_t n, const char *file, int line);
void csim_hc_free(void *p, const char *file, int line);

#define malloc(n) csim_hc_malloc((n), __FILE__, __LINE__)
#define calloc(c, s) csim_hc_calloc((c), (s), __FILE__, __LINE__)
#define realloc(p, n) csim_hc_realloc((p), (n), __FILE__, __LINE__)
#define free(p) csim_hc_free((p), __FILE__, __LINE__)

#endif /* CSIM_HEAPCHECK_H */
