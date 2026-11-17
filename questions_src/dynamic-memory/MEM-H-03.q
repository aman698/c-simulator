@@@ meta
id: MEM-H-03
topic: Dynamic Memory
difficulty: Hard
type: FUNCTION
title: aligned_malloc, aligned_free and aligned_realloc
tags: embedded, alignment, aligned-malloc, dma, uintptr-t, size-overflow, asked-in-automotive
@@@ statement_md
DMA engines, cache maintenance and MPU regions need buffers aligned to 32, 64 or even 4096 bytes. `malloc` only guarantees alignment for ordinary types (16 on x86-64). C11 `aligned_alloc` is missing from some C libraries (the Windows CRT, many embedded libcs), so firmware teams write their own on top of a plain allocator:

```c
void *xmalloc(size_t n);   /* provided: like malloc, the harness can make it fail; release with free() */

void *aligned_malloc(size_t size, size_t align);
void  aligned_free(void *p);
void *aligned_realloc(void *p, size_t new_size, size_t align);
```

- `aligned_malloc(size, align)`: return a pointer `p` with `(uintptr_t)p % align == 0` and at least `size` usable bytes. Return `NULL` if `size == 0`, if `align` is **not a power of two** (0, 3, 24, ...), if computing the request size would **overflow** `size_t`, or if `xmalloc` fails. Use exactly one `xmalloc` call per successful allocation.
- `aligned_free(p)`: release a block from `aligned_malloc`/`aligned_realloc`. `NULL` is a no-op. (Calling plain `free(p)` on it would be an invalid free, which is why this function exists.)
- `aligned_realloc(p, new_size, align)`:
  - `p == NULL` behaves like `aligned_malloc(new_size, align)`;
  - otherwise return a new block aligned to `align`, holding the first `min(old_size, new_size)` bytes of `p`, and release `p`;
  - if `new_size == 0`, `align` is invalid, or the allocation fails, return `NULL` and leave `p` **valid and unchanged**.

Hint about the design: you need to find the original `xmalloc` pointer (and, for realloc, the old size) from `p` alone.

**Input (read by the hidden harness)**
- Line 1: `fail <k>`: the `k`-th call to `xmalloc` returns `NULL` (`0` = never).
- Then operations (successful allocations get handle numbers 1, 2, 3, ...):
  - `M <size> <align>`: prints `M#<k>(size,align) -> aligned` / `misaligned`, or `M(size,align) -> NULL`.
  - `Q <size> <align>`: same, but through `aligned_realloc(NULL, size, align)`.
  - `R <k> <size> <align>`: realloc handle `k`. Prints `R#<k>(size,align) -> aligned, data kept` (or `data LOST`), or `-> NULL, old intact`.
  - `F <k>`: `aligned_free`. `N`: `aligned_free(NULL)`. `G <n> <seed>`: random stress, then a summary.
- The harness fills every block with a pattern and frees everything still live at the end with your `aligned_free`.

**Example**
```
Input:
fail 0
M 100 64
M 10 1
M 1 4096
M 5 3
F 1
F 2
F 3
N

Output:
M#1(100,64) -> aligned
M#2(10,1) -> aligned
M#3(1,4096) -> aligned
M(5,3) -> NULL
F #1
F #2
F #3
N ok
```
@@@ constraints_md
- `0 <= size < 2^64`, `0 <= align < 2^64`. Real allocations in the tests are at most 100000 bytes with `align <= 4096`.
- Overflow must be detected **before** calling `xmalloc` (the harness reports a wrapped request size).
- `aligned_alloc`, `posix_memalign` and `_aligned_malloc` are not allowed. Leak checking is on.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

void *xmalloc(size_t n); /* provided: like malloc, may fail on demand; release with free() */

void *aligned_malloc(size_t size, size_t align)
{
    /* TODO */
    return NULL;
}

void aligned_free(void *p)
{
    /* TODO */
}

void *aligned_realloc(void *p, size_t new_size, size_t align)
{
    /* TODO */
    return NULL;
}
@@@ harness_code
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int g_calls;
static int g_fail_at;
static size_t g_last_request;

void *xmalloc(size_t n)
{
    g_calls++;
    g_last_request = n;
    if (g_calls == g_fail_at)
        return NULL;
    if (n > ((size_t)64 << 20))
        return NULL;                       /* the "target" has 64 MB of RAM */
    return malloc(n);
}

/*USER_CODE*/

#define MAXH 4000
static unsigned char *h[MAXH + 1];
static size_t hsize[MAXH + 1];
static int nh;

static int pattern_ok(int k, size_t n)
{
    for (size_t i = 0; i < n; i++)
        if (h[k][i] != (unsigned char)(k * 13 + 5))
            return 0;
    return 1;
}

static const char *verdict(const void *p, size_t align)
{
    return ((uintptr_t)p % align == 0) ? "aligned" : "misaligned";
}

static int wrapped(size_t size, int calls_before)
{
    return g_calls > calls_before && g_last_request < size;
}

int main(void)
{
    char op[4];
    char word[8];
    if (scanf("%7s %d", word, &g_fail_at) != 2)
        return 0;
    while (scanf("%3s", op) == 1) {
        if (op[0] == 'M' || op[0] == 'Q') {
            unsigned long long s, a;
            if (scanf("%llu %llu", &s, &a) != 2)
                break;
            int before = g_calls;
            unsigned char *p = op[0] == 'M' ? aligned_malloc((size_t)s, (size_t)a)
                                            : aligned_realloc(NULL, (size_t)s, (size_t)a);
            if (wrapped((size_t)s, before)) {
                printf("%c(%llu,%llu) -> BAD: wrapped request size\n", op[0], s, a);
                return 0;
            }
            if (p == NULL) {
                printf("%c(%llu,%llu) -> NULL\n", op[0], s, a);
                continue;
            }
            if (nh >= MAXH || s > 100000u)
                return 0;
            h[++nh] = p;
            hsize[nh] = (size_t)s;
            memset(p, (nh * 13 + 5) & 0xFF, (size_t)s);
            printf("%c#%d(%llu,%llu) -> %s\n", op[0], nh, s, a, verdict(p, (size_t)a));
        } else if (op[0] == 'R') {
            int k;
            unsigned long long s, a;
            if (scanf("%d %llu %llu", &k, &s, &a) != 3 || k < 1 || k > nh || h[k] == NULL)
                break;
            int before = g_calls;
            unsigned char *q = aligned_realloc(h[k], (size_t)s, (size_t)a);
            if (wrapped((size_t)s, before)) {
                printf("R#%d -> BAD: wrapped request size\n", k);
                return 0;
            }
            if (q == NULL) {
                printf("R#%d(%llu,%llu) -> NULL, old %s\n", k, s, a, pattern_ok(k, hsize[k]) ? "intact" : "CORRUPTED");
                continue;
            }
            size_t keep = hsize[k] < (size_t)s ? hsize[k] : (size_t)s;
            h[k] = q;
            int kept = pattern_ok(k, keep);
            hsize[k] = (size_t)s;
            memset(q, (k * 13 + 5) & 0xFF, (size_t)s);
            printf("R#%d(%llu,%llu) -> %s, data %s\n", k, s, a, verdict(q, (size_t)a), kept ? "kept" : "LOST");
        } else if (op[0] == 'F') {
            int k;
            if (scanf("%d", &k) != 1 || k < 1 || k > nh || h[k] == NULL)
                break;
            if (!pattern_ok(k, hsize[k]))
                printf("F #%d: data CORRUPTED\n", k);
            aligned_free(h[k]);
            h[k] = NULL;
            printf("F #%d\n", k);
        } else if (op[0] == 'N') {
            aligned_free(NULL);
            printf("N ok\n");
        } else if (op[0] == 'G') {
            int n;
            unsigned int seed;
            if (scanf("%d %u", &n, &seed) != 2)
                break;
            int ok = 0, bad = 0, nulls = 0, lost = 0;
            for (int i = 0; i < n && nh < MAXH; i++) {
                seed = seed * 1103515245u + 12345u;
                unsigned int r = (seed >> 16) & 0x7FFFu;
                size_t align = (size_t)1 << (r % 13u);
                seed = seed * 1103515245u + 12345u;
                size_t size = 1u + ((seed >> 16) & 0x7FFFu) % 3000u;
                int live_k = 0;
                for (int k = nh; k >= 1 && k > nh - 8; k--)
                    if (h[k] != NULL) {
                        live_k = k;
                        break;
                    }
                if (r % 4u == 0u && live_k) {
                    aligned_free(h[live_k]);
                    h[live_k] = NULL;
                } else if (r % 4u == 1u && live_k) {
                    unsigned char *q = aligned_realloc(h[live_k], size, align);
                    if (q == NULL) {
                        nulls++;
                        continue;
                    }
                    size_t keep = hsize[live_k] < size ? hsize[live_k] : size;
                    h[live_k] = q;
                    if (!pattern_ok(live_k, keep))
                        lost++;
                    hsize[live_k] = size;
                    memset(q, (live_k * 13 + 5) & 0xFF, size);
                    if ((uintptr_t)q % align == 0)
                        ok++;
                    else
                        bad++;
                } else {
                    unsigned char *p = aligned_malloc(size, align);
                    if (p == NULL) {
                        nulls++;
                        continue;
                    }
                    h[++nh] = p;
                    hsize[nh] = size;
                    memset(p, (nh * 13 + 5) & 0xFF, size);
                    if ((uintptr_t)p % align == 0)
                        ok++;
                    else
                        bad++;
                }
            }
            printf("G aligned=%d misaligned=%d nulls=%d lost=%d\n", ok, bad, nulls, lost);
        }
    }
    for (int k = 1; k <= nh; k++)
        if (h[k] != NULL)
            aligned_free(h[k]);
    return 0;
}
@@@ sample_input
fail 0
M 100 64
M 10 1
M 1 4096
M 5 3
F 1
F 2
F 3
N
@@@ sample_output
M#1(100,64) -> aligned
M#2(10,1) -> aligned
M#3(1,4096) -> aligned
M(5,3) -> NULL
F #1
F #2
F #3
N ok

@@@ sample_input
fail 0
M 16 8
R 1 4000 64
R 1 3 2
F 1
@@@ sample_output
M#1(16,8) -> aligned
R#1(4000,64) -> aligned, data kept
R#1(3,2) -> aligned, data kept
F #1

@@@ hidden_input
fail 0
M 8 0
M 8 24
M 8 4097
M 0 16
M 8 2
M 8 1024
M 33 32
@@@ hidden_output
M(8,0) -> NULL
M(8,24) -> NULL
M(8,4097) -> NULL
M(0,16) -> NULL
M#1(8,2) -> aligned
M#2(8,1024) -> aligned
M#3(33,32) -> aligned

@@@ hidden_input
fail 0
M 18446744073709551600 64
M 9223372036854775808 9223372036854775808
M 18446744073709551615 1
M 1 9223372036854775808
M 7 16
@@@ hidden_output
M(18446744073709551600,64) -> NULL
M(9223372036854775808,9223372036854775808) -> NULL
M(18446744073709551615,1) -> NULL
M(1,9223372036854775808) -> NULL
M#1(7,16) -> aligned

@@@ hidden_input
fail 2
M 64 32
R 1 128 32
R 1 128 32
R 1 0 32
R 1 50 48
F 1
@@@ hidden_output
M#1(64,32) -> aligned
R#1(128,32) -> NULL, old intact
R#1(128,32) -> aligned, data kept
R#1(0,32) -> NULL, old intact
R#1(50,48) -> NULL, old intact
F #1

@@@ hidden_input
fail 1
M 10 8
Q 10 8
Q 0 8
Q 20 4096
R 2 9000 4096
N
@@@ hidden_output
M(10,8) -> NULL
Q#1(10,8) -> aligned
Q(0,8) -> NULL
Q#2(20,4096) -> aligned
R#2(9000,4096) -> aligned, data kept
N ok

@@@ hidden_input
fail 0
G 1500 7
@@@ hidden_output
G aligned=1129 misaligned=0 nulls=0 lost=0

@@@ hidden_input
fail 200
G 900 3
G 900 4
@@@ hidden_output
G aligned=671 misaligned=0 nulls=1 lost=0
G aligned=680 misaligned=0 nulls=0 lost=0

@@@ hint
Over-allocate: `size + (align - 1) + room for a small header`. Round the address up with integer arithmetic, `aligned = (start + align - 1) & ~(uintptr_t)(align - 1)`, where `start` leaves space for the header. Then store the **original** pointer (and the requested size, for realloc) in the bytes just before `aligned`. A power of two has exactly one bit set: `align != 0 && (align & (align - 1)) == 0`.
@@@ hint
`aligned_free` reads the header at `p - sizeof(header)` (copy it out with `memcpy` so you make no alignment or aliasing assumptions) and calls `free(raw)`, never `free(p)`. Check overflow with `size > SIZE_MAX - (align - 1 + header)` before adding. `aligned_realloc` = new aligned block + `memcpy(min)` + `aligned_free(old)`; on any failure return `NULL` before touching `p`.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

void *xmalloc(size_t n); /* provided: like malloc, may fail on demand; release with free() */

/* stored immediately before every aligned pointer */
struct ahdr {
    void *raw;      /* pointer returned by xmalloc */
    size_t size;    /* usable size requested by the caller */
};

static int is_pow2(size_t a)
{
    return a != 0 && (a & (a - 1)) == 0;
}

static struct ahdr read_hdr(const void *p)
{
    struct ahdr hd;
    memcpy(&hd, (const unsigned char *)p - sizeof hd, sizeof hd);   /* may be unaligned */
    return hd;
}

void *aligned_malloc(size_t size, size_t align)
{
    if (size == 0 || !is_pow2(align))
        return NULL;
    size_t extra = sizeof(struct ahdr) + (align - 1);     /* cannot overflow: align <= 2^63 */
    if (size > SIZE_MAX - extra)
        return NULL;                                      /* request size would wrap */

    unsigned char *raw = xmalloc(size + extra);
    if (raw == NULL)
        return NULL;

    uintptr_t start = (uintptr_t)raw + sizeof(struct ahdr);           /* leave room for header */
    uintptr_t aligned = (start + (align - 1)) & ~(uintptr_t)(align - 1);
    unsigned char *p = raw + (aligned - (uintptr_t)raw);              /* stay inside the block */

    struct ahdr hd = { raw, size };
    memcpy(p - sizeof hd, &hd, sizeof hd);
    return p;
}

void aligned_free(void *p)
{
    if (p == NULL)
        return;
    free(read_hdr(p).raw);
}

void *aligned_realloc(void *p, size_t new_size, size_t align)
{
    if (p == NULL)
        return aligned_malloc(new_size, align);
    if (new_size == 0 || !is_pow2(align))
        return NULL;                                      /* p stays valid */

    void *q = aligned_malloc(new_size, align);
    if (q == NULL)
        return NULL;                                      /* p stays valid */
    size_t old = read_hdr(p).size;
    memcpy(q, p, old < new_size ? old : new_size);
    aligned_free(p);
    return q;
}
@@@ explanation_md
**Approach: over-allocate, round up, remember the original.**

```
raw (from xmalloc)                         p = aligned (multiple of align)
|<-- slack (0 .. align-1) -->|[raw | size]|<------- size bytes ------->|
                              ^ header: 16 bytes directly before p
request = size + sizeof(header) + align - 1
```

1. **Validate.** `size > 0`; `align` is a power of two (`a & (a-1) == 0`, the single-bit test); and `size + header + align - 1` must not wrap. Check it as `size > SIZE_MAX - extra` **before** adding.
2. **Round up** with integer arithmetic on `uintptr_t`: `(start + align - 1) & ~(align - 1)`. The mask trick only works because `align` is a power of two. Starting from `raw + sizeof(header)` guarantees room for the header in front of `p`. The slack in front is at most `align - 1` bytes, which is why the request includes `align - 1`.
3. **Remember** the original pointer and size in the header just before `p`. `aligned_free` reads it back and frees the **original** pointer. Passing `p` itself to `free` is undefined behavior (an invalid free).
4. **Realloc.** Allocate new, copy `min(old, new)`, free old. All failure exits happen before `p` is touched, which is the same contract as `realloc`. In-place growth is impossible here anyway, because a different alignment can need a different slack.

Use `memcpy` for the header. Here `p - 16` happens to be suitably aligned, because `xmalloc` returns 16-byte-aligned blocks and the header is 16 bytes. With a smaller header, or a base allocator with weaker alignment (many RTOS heaps align to 4 or 8), a direct `*(void **)(p - 16)` load could be misaligned (UB, and a HardFault on Cortex-M0). `memcpy` also avoids strict-aliasing problems and compiles to the same load.

**Complexity.** O(1) bookkeeping plus O(min(old, new)) copying for realloc. Space overhead is at most `align - 1 + 16` bytes per block.

**Common mistakes**
- Forgetting to reserve room for the header, so it is written **before** `raw` (heap underflow).
- `size + align` overflow: `aligned_malloc(SIZE_MAX - 8, 64)` must fail, not return a 60-byte block.
- Accepting `align = 24` or `0`: the mask trick silently produces misaligned or garbage addresses.
- Calling `free(p)` instead of `aligned_free(p)`. Mixing allocator families is a classic production bug (`new`/`free`, `_aligned_malloc`/`free`).
- `aligned_realloc` that frees the old block before the new allocation succeeded.

**Interview follow-ups**
- On Cortex-M7 with a D-cache, why must a DMA RX buffer be aligned to **and** sized as a multiple of 32 bytes (cache line)? What breaks if another variable shares its last cache line?
- How would you get aligned buffers with **no heap at all**? (`_Alignas(64) static uint8_t buf[...]`, or a linker section with `ALIGN(64)`.)
- How does C11 `aligned_alloc` differ (size must be a multiple of the alignment, and the result is freed with plain `free`)? Why can glibc do that, when this design cannot?
- MPU regions on ARMv7-M must be aligned to their own (power-of-two) size. How would you allocate a 4 KB task stack that is MPU-protectable?
