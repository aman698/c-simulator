/*
 * heapcheck.c - implementation of the portable heap checker (see heapcheck.h).
 * Compiled together with the submission when real sanitizers are unavailable.
 * The judge recognises the "==CSIM-HEAPCHECK==" markers on stderr.
 */
#undef malloc
#undef calloc
#undef realloc
#undef free

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * When the program is ALSO built with AddressSanitizer (but the platform has no
 * LeakSanitizer, e.g. clang on Windows), run in leak-tracking-only mode: no back
 * redzone (it would hide small overflows from ASan) and no quarantine (ASan has its own).
 */
#if defined(__SANITIZE_ADDRESS__)
#define HC_UNDER_ASAN 1
#elif defined(__has_feature)
#if __has_feature(address_sanitizer)
#define HC_UNDER_ASAN 1
#endif
#endif
#ifndef HC_UNDER_ASAN
#define HC_UNDER_ASAN 0
#endif

#define HC_MAGIC_LIVE 0xA110CA7Eu
#define HC_MAGIC_FREED 0xDEADF4EEu
#define HC_FRONT_FILL 0xFAu
#define HC_BACK_FILL 0xFBu
#define HC_NEW_FILL 0xBEu
#define HC_FREED_FILL 0xDDu
#define HC_BACK_REDZONE (HC_UNDER_ASAN ? 0u : 16u)
#define HC_QUARANTINE_LIMIT ((size_t)8 << 20)
#define HC_MAX_ALLOC ((size_t)256 << 20)
#define HC_EXIT_LEAK 23
#define HC_EXIT_ERROR 99

typedef struct hc_hdr {
    size_t size;
    const char *file;
    struct hc_hdr *prev;
    struct hc_hdr *next;
    unsigned int line;
    unsigned int magic;
    unsigned char front[24]; /* front redzone; header is 64 bytes total */
} hc_hdr;

#define HC_HDR_SIZE ((sizeof(hc_hdr) + 15u) & ~(size_t)15u)

static hc_hdr *live_head;
static size_t live_count;
static size_t live_bytes;
static hc_hdr *q_head;
static hc_hdr *q_tail;
static size_t q_bytes;

static unsigned char *hc_user(hc_hdr *h) { return (unsigned char *)h + HC_HDR_SIZE; }
static hc_hdr *hc_header(void *p) { return (hc_hdr *)(void *)((unsigned char *)p - HC_HDR_SIZE); }

static void hc_die(const char *what, const char *file, int line, const hc_hdr *h)
{
    fflush(stdout);
    fprintf(stderr, "==CSIM-HEAPCHECK== ERROR: %s", what);
    if (file) fprintf(stderr, " at %s:%d", file, line);
    if (h) fprintf(stderr, " (block of %zu bytes allocated at %s:%u)", h->size, h->file, h->line);
    fputc('\n', stderr);
    fflush(stderr);
    _Exit(HC_EXIT_ERROR);
}

static int hc_redzones_ok(hc_hdr *h)
{
    size_t i;
    unsigned char *u = hc_user(h);
    for (i = 0; i < sizeof h->front; i++)
        if (h->front[i] != HC_FRONT_FILL) return 0;
    for (i = 0; i < HC_BACK_REDZONE; i++)
        if (u[h->size + i] != HC_BACK_FILL) return 0;
    return 1;
}

static int hc_poison_ok(hc_hdr *h)
{
    size_t i;
    unsigned char *u = hc_user(h);
    for (i = 0; i < h->size; i++)
        if (u[i] != HC_FREED_FILL) return 0;
    return 1;
}

static void hc_check_quarantined(hc_hdr *h)
{
    if (!hc_poison_ok(h))
        hc_die("heap-use-after-free: memory was written after it was freed", NULL, 0, h);
    if (!hc_redzones_ok(h))
        hc_die("heap-buffer-overflow: write outside a freed block's bounds", NULL, 0, h);
}

static void hc_at_exit(void)
{
    hc_hdr *h;
    size_t shown = 0;
    for (h = q_head; h; h = h->next) hc_check_quarantined(h);
    for (h = live_head; h; h = h->next)
        if (!hc_redzones_ok(h))
            hc_die("heap-buffer-overflow: write past the end (or before the start) of an allocated block", NULL, 0, h);
    if (live_count == 0) return;
    fflush(stdout);
    fprintf(stderr, "==CSIM-HEAPCHECK== ERROR: memory leak detected: %zu byte(s) in %zu allocation(s) were never freed\n",
            live_bytes, live_count);
    for (h = live_head; h && shown < 10; h = h->next, shown++)
        fprintf(stderr, "    leaked %zu byte(s) allocated at %s:%u\n", h->size, h->file, h->line);
    if (live_count > shown) fprintf(stderr, "    ... and %zu more allocation(s)\n", live_count - shown);
    fflush(stderr);
    _Exit(HC_EXIT_LEAK);
}

__attribute__((constructor)) static void hc_init(void) { atexit(hc_at_exit); }

void *csim_hc_malloc(size_t n, const char *file, int line)
{
    hc_hdr *h;
    if (n > HC_MAX_ALLOC) return NULL;
    h = (hc_hdr *)malloc(HC_HDR_SIZE + n + HC_BACK_REDZONE);
    if (!h) return NULL;
    h->size = n;
    h->file = file;
    h->line = (unsigned int)line;
    h->magic = HC_MAGIC_LIVE;
    memset(h->front, HC_FRONT_FILL, sizeof h->front);
    memset(hc_user(h), HC_NEW_FILL, n);
    memset(hc_user(h) + n, HC_BACK_FILL, HC_BACK_REDZONE);
    h->prev = NULL;
    h->next = live_head;
    if (live_head) live_head->prev = h;
    live_head = h;
    live_count++;
    live_bytes += n;
    return hc_user(h);
}

void *csim_hc_calloc(size_t count, size_t size, const char *file, int line)
{
    void *p;
    if (size != 0 && count > SIZE_MAX / size) return NULL;
    p = csim_hc_malloc(count * size, file, line);
    if (p) memset(p, 0, count * size);
    return p;
}

static hc_hdr *hc_validate(void *p, const char *op, const char *file, int line)
{
    static char msg[160];
    hc_hdr *h = hc_header(p);
    if (h->magic == HC_MAGIC_FREED) {
        snprintf(msg, sizeof msg, "%s on memory that was already freed (double free / use-after-free)", op);
        hc_die(msg, file, line, h);
    }
    if (h->magic != HC_MAGIC_LIVE) {
        snprintf(msg, sizeof msg, "%s on a pointer that was not returned by malloc/calloc/realloc (invalid pointer)", op);
        hc_die(msg, file, line, NULL);
    }
    if (!hc_redzones_ok(h))
        hc_die("heap-buffer-overflow: write past the end (or before the start) of an allocated block", file, line, h);
    return h;
}

void csim_hc_free(void *p, const char *file, int line)
{
    hc_hdr *h;
    if (!p) return;
    h = hc_validate(p, "free()", file, line);
    if (h->prev) h->prev->next = h->next; else live_head = h->next;
    if (h->next) h->next->prev = h->prev;
    live_count--;
    live_bytes -= h->size;
    h->magic = HC_MAGIC_FREED;
    if (HC_UNDER_ASAN) {
        free(h); /* let ASan's own quarantine detect use-after-free / double free */
        return;
    }
    memset(hc_user(h), HC_FREED_FILL, h->size);
    h->next = NULL;
    h->prev = q_tail;
    if (q_tail) q_tail->next = h; else q_head = h;
    q_tail = h;
    q_bytes += h->size + HC_HDR_SIZE;
    while (q_bytes > HC_QUARANTINE_LIMIT && q_head) {
        hc_hdr *old = q_head;
        hc_check_quarantined(old);
        q_head = old->next;
        if (q_head) q_head->prev = NULL; else q_tail = NULL;
        q_bytes -= old->size + HC_HDR_SIZE;
        free(old);
    }
}

void *csim_hc_realloc(void *p, size_t n, const char *file, int line)
{
    hc_hdr *h;
    void *q;
    if (!p) return csim_hc_malloc(n, file, line);
    h = hc_validate(p, "realloc()", file, line);
    if (n == 0) {
        csim_hc_free(p, file, line);
        return NULL;
    }
    q = csim_hc_malloc(n, file, line);
    if (!q) return NULL; /* original block untouched, like real realloc */
    memcpy(q, p, h->size < n ? h->size : n);
    csim_hc_free(p, file, line);
    return q;
}
