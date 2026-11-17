@@@ meta
id: MEM-H-02
topic: Dynamic Memory
difficulty: Hard
type: FUNCTION
title: First-Fit my_malloc/my_free With Splitting and Coalescing
tags: embedded, allocator, block-header, coalescing, fragmentation, first-fit, misra
@@@ statement_md
Your bootloader has no C library, but the flashing protocol needs variable-sized buffers. Write a small general-purpose allocator over a static heap array:

```c
#define HEAP_SIZE 1024u
extern unsigned char g_heap[HEAP_SIZE];      /* provided, aligned to 8 bytes */

void  heap_init(void);
void *my_malloc(size_t n);
int   my_free(void *p);                      /* 0 ok, -1 invalid pointer or double free */
void  heap_stats(size_t *free_blocks, size_t *largest_free, size_t *total_free);
```

**Layout and policy.** These are fixed, because the harness checks the returned offsets.
- The heap is a contiguous sequence of blocks covering all 1024 bytes. Each block is an **8-byte header** (your format: payload size plus a used/free flag fits easily) followed by its **payload**. `my_malloc` returns the payload address, i.e. block start + 8.
- `heap_init()` creates **one free block** at offset 0 with a 1016-byte payload. It may be called again to reset everything.
- `my_malloc(n)`: return `NULL` if `n == 0` or if `n` cannot fit. Round `n` up to a multiple of 8 (`need`). Pick the **first** free block in address order whose payload `>= need`. **Split** it if its payload `>= need + 16`: the front part becomes the allocated block with payload `need`, and the rest becomes a new free block (header + payload) right after it. Otherwise hand out the whole block.
- `my_free(p)`: `NULL` is a no-op returning 0. If `p` is not the payload start of a currently **allocated** block, return `-1` and change nothing. Otherwise mark the block free and **coalesce** it with a free neighbor on the right, on the left, or both. Two free blocks are never adjacent.
- `heap_stats`: number of free blocks, the largest free payload, and the sum of all free payloads.
- No `malloc`/`calloc`/`realloc` (they are disabled). Your heap metadata must live in the headers inside `g_heap` (plus a few scalar statics if you like).

**Input (read by the hidden harness)**, one operation per line:
- `I`: `heap_init()`. `A <n>`: `my_malloc(n)`, prints `A#<k>(<n>) -> off <payload offset>` or `A(<n>) -> NULL`. Successful allocations get handle numbers 1, 2, 3, ..., and the harness fills `n` bytes with a pattern.
- `F <k>`: `my_free(handle k)`. `N`: `my_free(NULL)`. `X <off>`: `my_free(g_heap + off)`. Each prints `-> <rc>`.
- `S`: prints `free_blocks=<a> largest=<b> total=<c> data=<ok|CORRUPTED>`.
- `R <n> <seed>`: `n` random operations, then a summary.

**Example**
```
Input:
I
A 24
A 1
A 100
S
F 2
F 1
S

Output:
A#1(24) -> off 8
A#2(1) -> off 40
A#3(100) -> off 56
free_blocks=1 largest=856 total=856 data=ok
F #2 -> 0
F #1 -> 0
free_blocks=2 largest=856 total=896 data=ok
```
(`A 1` rounds up to 8. Freeing #1 merges it with the free block #2 on its right: 24 + 8 + 8 = 40.)
@@@ constraints_md
- `HEAP_SIZE = 1024`, header 8 bytes, alignment 8. `n` may be as large as `2^64 - 1` (must return `NULL`, no overflow).
- At most 3000 operations per test. A linear walk over the blocks per call is fine.
- Never touch bytes outside `g_heap`, and never touch the payload of an allocated block.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define HEAP_SIZE 1024u
extern unsigned char g_heap[HEAP_SIZE]; /* provided, 8-byte aligned */

void heap_init(void)
{
    /* TODO: one free block covering the whole heap */
}

void *my_malloc(size_t n)
{
    /* TODO: round up to 8, first fit, split if the rest can hold header + 8 bytes */
    return NULL;
}

int my_free(void *p)
{
    /* TODO: validate, mark free, coalesce with free neighbours */
    return -1;
}

void heap_stats(size_t *free_blocks, size_t *largest_free, size_t *total_free)
{
    /* TODO */
    *free_blocks = 0;
    *largest_free = 0;
    *total_free = 0;
}
@@@ harness_code
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

_Alignas(max_align_t) unsigned char g_heap[1024u];

#ifdef malloc
#undef malloc
#endif
#ifdef calloc
#undef calloc
#endif
#ifdef realloc
#undef realloc
#endif
#define malloc(n) malloc_is_not_available_in_this_bootloader
#define calloc(c, n) calloc_is_not_available_in_this_bootloader
#define realloc(p, n) realloc_is_not_available_in_this_bootloader

/*USER_CODE*/

#undef malloc
#undef calloc
#undef realloc

#define MAXH 3100
static unsigned char *h[MAXH + 1];
static size_t hsize[MAXH + 1];
static int live[MAXH + 1];
static int nh, nlive;

static int data_ok(void)
{
    for (int k = 1; k <= nh; k++) {
        if (!live[k])
            continue;
        for (size_t i = 0; i < hsize[k]; i++)
            if (h[k][i] != (unsigned char)(k * 7 + 1))
                return 0;
    }
    return 1;
}

/* returns 1 = allocated, 0 = NULL, -1 = bad pointer */
static int do_alloc(unsigned long long n, size_t *off_out)
{
    unsigned char *p = my_malloc((size_t)n);
    if (p == NULL || nh >= MAXH)
        return 0;
    uintptr_t off = (uintptr_t)p - (uintptr_t)g_heap;
    if (off >= sizeof g_heap || off % 8u != 0 || off + n > sizeof g_heap)
        return -1;
    h[++nh] = p;
    hsize[nh] = (size_t)n;
    live[nh] = 1;
    nlive++;
    memset(p, (nh * 7 + 1) & 0xFF, (size_t)n);
    *off_out = (size_t)off;
    return 1;
}

int main(void)
{
    char op[4];
    while (scanf("%3s", op) == 1) {
        if (op[0] == 'I') {
            heap_init();
            for (int k = 1; k <= nh; k++)
                live[k] = 0;
            nlive = 0;
        } else if (op[0] == 'A') {
            unsigned long long n;
            size_t off = 0;
            if (scanf("%llu", &n) != 1)
                break;
            int r = do_alloc(n, &off);
            if (r < 0) {
                printf("A(%llu) -> BAD POINTER\n", n);
                return 0;
            }
            if (r == 0)
                printf("A(%llu) -> NULL\n", n);
            else
                printf("A#%d(%llu) -> off %zu\n", nh, n, off);
        } else if (op[0] == 'F') {
            int k;
            if (scanf("%d", &k) != 1 || k < 1 || k > nh)
                break;
            int rc = my_free(h[k]);
            if (rc == 0 && live[k]) {
                live[k] = 0;
                nlive--;
            }
            printf("F #%d -> %d\n", k, rc);
        } else if (op[0] == 'N') {
            printf("N -> %d\n", my_free(NULL));
        } else if (op[0] == 'X') {
            int off;
            if (scanf("%d", &off) != 1 || off < 0 || off > (int)sizeof g_heap)
                break;
            printf("X %d -> %d\n", off, my_free(g_heap + off));
        } else if (op[0] == 'S') {
            size_t a, b, c;
            heap_stats(&a, &b, &c);
            printf("free_blocks=%zu largest=%zu total=%zu data=%s\n", a, b, c, data_ok() ? "ok" : "CORRUPTED");
        } else if (op[0] == 'R') {
            int n;
            unsigned int seed;
            if (scanf("%d %u", &n, &seed) != 2)
                break;
            int allocs = 0, nulls = 0, frees = 0;
            unsigned int hash = 0;
            for (int i = 0; i < n && nh < MAXH; i++) {
                seed = seed * 1103515245u + 12345u;
                unsigned int r = (seed >> 16) & 0x7FFFu;
                if (r % 7u < 4u || nlive == 0) {
                    size_t off = 0;
                    int res = do_alloc(1u + r % 200u, &off);
                    if (res < 0) {
                        printf("R -> BAD POINTER\n");
                        return 0;
                    }
                    if (res == 0) {
                        nulls++;
                    } else {
                        allocs++;
                        hash = hash * 31u + (unsigned int)off;
                    }
                } else {
                    int pick = (int)(r % (unsigned int)nlive), k;
                    for (k = 1; k <= nh; k++)
                        if (live[k] && pick-- == 0)
                            break;
                    if (my_free(h[k]) != 0)
                        printf("R: free failed\n");
                    live[k] = 0;
                    nlive--;
                    frees++;
                }
            }
            size_t a, b, c;
            heap_stats(&a, &b, &c);
            printf("R allocs=%d nulls=%d frees=%d hash=%u free_blocks=%zu largest=%zu total=%zu data=%s\n", allocs,
                   nulls, frees, hash, a, b, c, data_ok() ? "ok" : "CORRUPTED");
        }
    }
    return 0;
}
@@@ sample_input
I
A 24
A 1
A 100
S
F 2
F 1
S
@@@ sample_output
A#1(24) -> off 8
A#2(1) -> off 40
A#3(100) -> off 56
free_blocks=1 largest=856 total=856 data=ok
F #2 -> 0
F #1 -> 0
free_blocks=2 largest=856 total=896 data=ok

@@@ sample_input
I
S
A 0
A 1017
A 18446744073709551615
A 1016
A 1
S
F 1
S
@@@ sample_output
free_blocks=1 largest=1016 total=1016 data=ok
A(0) -> NULL
A(1017) -> NULL
A(18446744073709551615) -> NULL
A#1(1016) -> off 8
A(1) -> NULL
free_blocks=0 largest=0 total=0 data=ok
F #1 -> 0
free_blocks=1 largest=1016 total=1016 data=ok

@@@ hidden_input
I
A 24
A 1
A 100
F 2
F 1
A 40
F 3
S
F 4
S
@@@ hidden_output
A#1(24) -> off 8
A#2(1) -> off 40
A#3(100) -> off 56
F #2 -> 0
F #1 -> 0
A#4(40) -> off 8
F #3 -> 0
free_blocks=1 largest=968 total=968 data=ok
F #4 -> 0
free_blocks=1 largest=1016 total=1016 data=ok

@@@ hidden_input
I
A 64
A 64
A 64
A 64
F 1
F 3
S
F 2
S
F 4
S
@@@ hidden_output
A#1(64) -> off 8
A#2(64) -> off 80
A#3(64) -> off 152
A#4(64) -> off 224
F #1 -> 0
F #3 -> 0
free_blocks=3 largest=728 total=856 data=ok
F #2 -> 0
free_blocks=2 largest=728 total=936 data=ok
F #4 -> 0
free_blocks=1 largest=1016 total=1016 data=ok

@@@ hidden_input
I
A 120
A 120
A 120
A 120
A 120
A 120
A 120
A 120
S
F 1
F 3
F 5
F 7
S
A 200
F 2
S
A 200
S
@@@ hidden_output
A#1(120) -> off 8
A#2(120) -> off 136
A#3(120) -> off 264
A#4(120) -> off 392
A#5(120) -> off 520
A#6(120) -> off 648
A#7(120) -> off 776
A#8(120) -> off 904
free_blocks=0 largest=0 total=0 data=ok
F #1 -> 0
F #3 -> 0
F #5 -> 0
F #7 -> 0
free_blocks=4 largest=120 total=480 data=ok
A(200) -> NULL
F #2 -> 0
free_blocks=3 largest=376 total=616 data=ok
A#9(200) -> off 8
free_blocks=3 largest=168 total=408 data=ok

@@@ hidden_input
I
A 1000
S
A 8
A 1
F 1
A 1008
S
N
X 0
X 12
X 1024
F 2
F 2
S
@@@ hidden_output
A#1(1000) -> off 8
free_blocks=1 largest=8 total=8 data=ok
A#2(8) -> off 1016
A(1) -> NULL
F #1 -> 0
A(1008) -> NULL
free_blocks=1 largest=1000 total=1000 data=ok
N -> 0
X 0 -> -1
X 12 -> -1
X 1024 -> -1
F #2 -> 0
F #2 -> -1
free_blocks=1 largest=1016 total=1016 data=ok

@@@ hidden_input
I
A 16
A 16
A 16
F 2
X 32
F 2
F 3
S
F 1
S
@@@ hidden_output
A#1(16) -> off 8
A#2(16) -> off 32
A#3(16) -> off 56
F #2 -> 0
X 32 -> -1
F #2 -> -1
F #3 -> 0
free_blocks=1 largest=992 total=992 data=ok
F #1 -> 0
free_blocks=1 largest=1016 total=1016 data=ok

@@@ hidden_input
I
R 2500 3
@@@ hidden_output
R allocs=1080 nulls=347 frees=1073 hash=399033968 free_blocks=4 largest=152 total=232 data=ok

@@@ hidden_input
I
R 700 42
I
R 1500 2024
S
@@@ hidden_output
R allocs=289 nulls=129 frees=282 hash=2384625696 free_blocks=4 largest=168 total=312 data=ok
R allocs=620 nulls=261 frees=619 hash=4272744720 free_blocks=1 largest=888 total=888 data=ok
free_blocks=1 largest=888 total=888 data=ok

@@@ hint
Treat the heap as an implicit list: block `off` has its header at `g_heap + off`, and the next block starts at `off + 8 + payload`. `my_malloc` walks this list for the first free block that is big enough; splitting just writes a second header at `off + 8 + need`. Check `n > HEAP_SIZE - 8` **before** rounding up, so `n + 7` cannot overflow.
@@@ hint
In `my_free`, walk the list while remembering the **previous** block. When you reach the block whose payload is `p`: reject it if it is already free. Otherwise merge with the next block if it is free (payload += 8 + next payload), then, if the previous block is free, grow the previous block instead of this one. Any pointer that is not exactly a payload start of a used block returns -1 without touching anything.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define HEAP_SIZE 1024u
extern unsigned char g_heap[HEAP_SIZE]; /* provided, 8-byte aligned */

#define HDR 8u
#define ALIGN 8u

struct hdr {
    uint32_t size;   /* payload bytes */
    uint32_t used;   /* 1 = allocated, 0 = free */
};

static struct hdr rd(size_t off)
{
    struct hdr hd;
    memcpy(&hd, g_heap + off, sizeof hd);
    return hd;
}

static void wr(size_t off, size_t size, uint32_t used)
{
    struct hdr hd = { (uint32_t)size, used };
    memcpy(g_heap + off, &hd, sizeof hd);
}

void heap_init(void)
{
    wr(0, HEAP_SIZE - HDR, 0);                         /* one big free block */
}

void *my_malloc(size_t n)
{
    if (n == 0 || n > HEAP_SIZE - HDR)
        return NULL;                                   /* also prevents n + 7 overflow */
    size_t need = (n + ALIGN - 1) / ALIGN * ALIGN;

    for (size_t off = 0; off < HEAP_SIZE; off += HDR + rd(off).size) {
        struct hdr hd = rd(off);
        if (hd.used || hd.size < need)
            continue;                                  /* first fit */
        if (hd.size >= need + HDR + ALIGN) {           /* split: rest keeps >= 8 bytes */
            wr(off, need, 1);
            wr(off + HDR + need, hd.size - need - HDR, 0);
        } else {
            wr(off, hd.size, 1);                       /* hand out the whole block */
        }
        return g_heap + off + HDR;
    }
    return NULL;
}

int my_free(void *p)
{
    if (p == NULL)
        return 0;
    uintptr_t target = (uintptr_t)p - (uintptr_t)g_heap;
    if (target >= HEAP_SIZE)
        return -1;

    size_t prev = SIZE_MAX;
    for (size_t off = 0; off < HEAP_SIZE;) {
        struct hdr hd = rd(off);
        size_t next = off + HDR + hd.size;
        if (off + HDR == target) {
            if (!hd.used)
                return -1;                             /* double free */
            size_t size = hd.size;
            if (next < HEAP_SIZE && !rd(next).used)    /* coalesce right */
                size += HDR + rd(next).size;
            if (prev != SIZE_MAX && !rd(prev).used)    /* coalesce left */
                wr(prev, rd(prev).size + HDR + size, 0);
            else
                wr(off, size, 0);
            return 0;
        }
        if (off + HDR > target)
            return -1;                                 /* points into the middle of a block */
        prev = off;
        off = next;
    }
    return -1;
}

void heap_stats(size_t *free_blocks, size_t *largest_free, size_t *total_free)
{
    size_t cnt = 0, big = 0, sum = 0;
    for (size_t off = 0; off < HEAP_SIZE; off += HDR + rd(off).size) {
        struct hdr hd = rd(off);
        if (hd.used)
            continue;
        cnt++;
        sum += hd.size;
        if (hd.size > big)
            big = hd.size;
    }
    *free_blocks = cnt;
    *largest_free = big;
    *total_free = sum;
}
@@@ explanation_md
**Approach: an implicit free list with boundary-checked coalescing.**

```
off:    0        32       48             160                    1024
        [H|24 A ][H|8 A][H|  104  A   ][H|      856  free     ]
        payload offsets returned: 8, 40, 56
```

- **Header** (8 bytes): payload size + used flag. Next block = `off + 8 + size`, so the headers form a list that covers the whole heap.
- **my_malloc**: round up to 8 (alignment for any scalar up to 8 bytes), walk to the first free block that fits, and split off the tail if the remainder can hold a header **and** at least 8 payload bytes. Otherwise hand out the whole block, accepting a little internal fragmentation.
- **my_free**: find the block, then coalesce **right** (absorb the next block if it is free) and **left** (let the previous free block absorb this one). Because neighbors are merged on every free, two free blocks are never adjacent.

**Fragmentation (the sample with eight 120-byte blocks).** After freeing every other block, 480 bytes are free, but the largest hole is 120, so `my_malloc(200)` fails. This is **external fragmentation**, and it is exactly why MISRA C:2012 **Rule 21.3** bans `malloc`/`free` and **Directive 4.12** forbids dynamic allocation in safety-related code:
- The run time of `my_malloc` depends on the heap history (a linear walk here), so the **WCET is unbounded** or at least hard to analyze.
- Whether an allocation succeeds depends on the **order** of past allocations and frees, not just on the bytes in use. A test bench cannot prove the absence of failures that appear after days of uptime.
- Typical ECU alternatives: static allocation, fixed-block pools (no external fragmentation, O(1)), or "allocate during init only, never free".

**Complexity.** `my_malloc`, `my_free` and `heap_stats` are O(B) for B blocks (at most 1024/16 = 64 here). Memory overhead is 8 bytes per block plus rounding.

**Common mistakes**
- Rounding with `(n + 7) & ~7` **before** the size check: `n = SIZE_MAX` wraps to 0 and "fits".
- Splitting when the remainder has no room for its header. The new header then overlaps the next block.
- Coalescing only to the right. Freeing B in `[free A][B][free C]` must give one block A+B+C (the "free 1, 3, then 2" test).
- Validating `p` by reading the 8 bytes before it as a header. An interior or random pointer then makes you trust garbage. Walk the list and compare offsets instead.
- Writing headers through `(struct hdr *)` casts on a `char` array. That technically breaks strict aliasing; `memcpy` is the portable form, and compilers turn it into a single load/store.

**Interview follow-ups**
- Add **boundary tags** (a footer copy of the size) so `my_free` finds the left neighbor in O(1) instead of walking from the start. What does it cost per block?
- Implement **best fit** and **next fit**. Which one fragments less on this test, and which one is faster?
- How would you make `my_free` reject a pointer in O(1) without walking? (A magic value in the header plus a range check: fast but not bulletproof.)
- How do FreeRTOS `heap_4` (first fit + coalescing) and `heap_5` (multiple regions) relate to this design?
