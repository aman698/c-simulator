@@@ meta
id: PTR-H-09
topic: Pointers
difficulty: Hard
type: FUNCTION
title: Fixed-Block Memory Pool with an Embedded Free List
tags: embedded, memory-pool, free-list, alignment, uintptr-t, misra
@@@ statement_md
MISRA C forbids `malloc` in production ECU code, so a classic interview task is a **fixed-block pool allocator** over a static buffer. The free blocks themselves store the free list: the first bytes of each free block hold a pointer to the next free block. That needs no extra metadata.

```c
typedef struct {
    unsigned char *start;    /* first block (aligned)          */
    unsigned char *end;      /* one past the last block        */
    size_t block_size;       /* rounded block size             */
    void *free_list;         /* first free block, or NULL      */
    size_t free_count;
} pool_t;

int    pool_init(pool_t *p, void *mem, size_t mem_size, size_t block_size);
void  *pool_alloc(pool_t *p);
int    pool_free(pool_t *p, void *blk);
size_t pool_available(const pool_t *p);
```

**`pool_init`**
- Return `-1` (and write nothing anywhere) if `p` or `mem` is `NULL`, `block_size == 0`, or not a single block fits.
- Round `block_size` up to a multiple of `sizeof(void *)` (8 on the judge).
- Blocks start at the first address `>= mem` that is a multiple of `sizeof(void *)`. `mem` may be misaligned.
- The pool has `N = (mem_size - skipped bytes) / rounded_size` blocks. Block `i` starts at `start + i * rounded_size`.
- Link all blocks so that the first allocations return block 0, 1, 2, ... in order. Return `N`.

**`pool_alloc`**: take the first block from the free list, or return `NULL` when the pool is empty. A freed block is reused first (LIFO).

**`pool_free`**, in this order of checks:
- `-1` if `blk` is `NULL`;
- `-2` if `blk` is not the start of a block of this pool (outside `[start, end)` or not on a block boundary): a **wild pointer**;
- `-3` if the block is already free: a **double free**;
- otherwise put it back on the free list and return `0`.

**`pool_available`**: the number of free blocks.

**How it is tested.** The harness `malloc`s a 512-byte arena and passes `arena + off`. Every byte outside the pool's blocks must stay untouched. Allocated blocks are completely filled with data by the harness, which must survive until they are freed, so you must not keep anything inside allocated blocks.

**Commands**: `init OFF SIZE BS`, `alloc`, `allocn K` (K allocations, prints how many succeeded), `free K` (frees block `K`), `freeoff D` (frees `start + D` bytes), `freenull`, `avail`. Results are printed as `init -> R`, `alloc -> #k` / `alloc -> NULL`, `allocn -> X`, `free #K -> R`, `freeoff D -> R`, `freenull -> R`, `avail -> N`.

**Example**
```
Input:
init 0 64 16
alloc
alloc
avail
free 0
alloc
alloc
alloc
alloc

Output:
init -> 4
alloc -> #0
alloc -> #1
avail -> 2
free #0 -> 0
alloc -> #0
alloc -> #2
alloc -> #3
alloc -> NULL
```
@@@ constraints_md
- `OFF + SIZE <= 512`, at most 64 blocks, at most 60 commands.
- O(1) `pool_alloc`; `pool_free` may be O(free blocks) for the double-free check.
- No dynamic memory inside the pool; no metadata arrays besides `pool_t`.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>
#include <string.h>

typedef struct {
    unsigned char *start;
    unsigned char *end;
    size_t block_size;
    void *free_list;
    size_t free_count;
} pool_t;

int pool_init(pool_t *p, void *mem, size_t mem_size, size_t block_size)
{
    /* TODO */
    (void)p;
    (void)mem;
    (void)mem_size;
    (void)block_size;
    return -1;
}

void *pool_alloc(pool_t *p)
{
    /* TODO */
    (void)p;
    return NULL;
}

int pool_free(pool_t *p, void *blk)
{
    /* TODO */
    (void)p;
    (void)blk;
    return -1;
}

size_t pool_available(const pool_t *p)
{
    /* TODO */
    (void)p;
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stddef.h>

/*USER_CODE*/

#define ARENA 512
#define FILL 0xC3
static unsigned char *arena;
static pool_t pool;
static unsigned char *exp_start;
static size_t exp_bs, exp_n;
static unsigned char live[64];

static int memory_ok(void)
{
    for (size_t k = 0; k < ARENA; k++) {
        const unsigned char *b = arena + k;
        int inside = exp_n > 0 && b >= exp_start && b < exp_start + exp_n * exp_bs;
        if (!inside && *b != FILL) return 0;
    }
    return 1;
}

static int live_ok(void)
{
    for (size_t i = 0; i < exp_n; i++)
        if (live[i])
            for (size_t j = 0; j < exp_bs; j++)
                if (exp_start[i * exp_bs + j] != (unsigned char)(0x40 + i)) return 0;
    return 1;
}

/* returns block index, -1 for NULL, -2 for an invalid pointer */
static int take(void *blk)
{
    if (blk == NULL) return -1;
    uintptr_t a = (uintptr_t)blk, s = (uintptr_t)exp_start;
    if (a < s || a - s >= exp_n * exp_bs || (a - s) % exp_bs != 0) return -2;
    size_t i = (a - s) / exp_bs;
    if (live[i]) return -2;
    live[i] = 1;
    memset(exp_start + i * exp_bs, 0x40 + (int)i, exp_bs);
    return (int)i;
}

int main(void)
{
    char cmd[16];
    arena = malloc(ARENA);
    if (arena == NULL) return 0;
    memset(arena, FILL, ARENA);
    while (scanf("%15s", cmd) == 1) {
        if (strcmp(cmd, "init") == 0) {
            int off, size, bs;
            if (scanf("%d %d %d", &off, &size, &bs) != 3) break;
            memset(arena, FILL, ARENA);
            memset(live, 0, sizeof live);
            const size_t al = sizeof(void *);
            uintptr_t a = (uintptr_t)(arena + off);
            size_t skip = (size_t)((al - a % al) % al);
            exp_bs = (size_t)bs == 0 ? 0 : ((size_t)bs + al - 1) / al * al;
            exp_start = arena + off + skip;
            int r = pool_init(&pool, arena + off, (size_t)size, (size_t)bs);
            exp_n = (r > 0 && (size_t)size > skip && exp_bs > 0) ? ((size_t)size - skip) / exp_bs : 0;
            printf("init -> %d\n", r);
        } else if (strcmp(cmd, "alloc") == 0) {
            int k = take(pool_alloc(&pool));
            if (k == -2) { printf("BAD BLOCK RETURNED\n"); break; }
            if (k < 0) printf("alloc -> NULL\n");
            else printf("alloc -> #%d\n", k);
        } else if (strcmp(cmd, "allocn") == 0) {
            int n, got = 0;
            if (scanf("%d", &n) != 1) break;
            for (int i = 0; i < n; i++) {
                int k = take(pool_alloc(&pool));
                if (k == -2) { printf("BAD BLOCK RETURNED\n"); free(arena); return 0; }
                if (k >= 0) got++;
            }
            printf("allocn -> %d\n", got);
        } else if (strcmp(cmd, "free") == 0) {
            int k;
            if (scanf("%d", &k) != 1) break;
            int r = pool_free(&pool, exp_start + (size_t)k * exp_bs);
            if (r == 0) live[k] = 0;
            printf("free #%d -> %d\n", k, r);
        } else if (strcmp(cmd, "freeoff") == 0) {
            int d;
            if (scanf("%d", &d) != 1) break;
            printf("freeoff %d -> %d\n", d, pool_free(&pool, exp_start + d));
        } else if (strcmp(cmd, "freenull") == 0) {
            printf("freenull -> %d\n", pool_free(&pool, NULL));
        } else if (strcmp(cmd, "avail") == 0) {
            printf("avail -> %zu\n", pool_available(&pool));
        }
        if (!memory_ok()) { printf("OUT OF BOUNDS WRITE\n"); break; }
        if (!live_ok()) { printf("POOL CORRUPTED A LIVE BLOCK\n"); break; }
    }
    free(arena);
    return 0;
}
@@@ sample_input
init 0 64 16
alloc
alloc
avail
free 0
alloc
alloc
alloc
alloc
@@@ sample_output
init -> 4
alloc -> #0
alloc -> #1
avail -> 2
free #0 -> 0
alloc -> #0
alloc -> #2
alloc -> #3
alloc -> NULL

@@@ sample_input
init 3 100 12
avail
alloc
free 0
free 0
freenull
@@@ sample_output
init -> 5
avail -> 5
alloc -> #0
free #0 -> 0
free #0 -> -3
freenull -> -1

@@@ hidden_input
init 0 7 8
init 0 64 0
init 1 9 1
init 1 15 1
alloc
alloc
avail
@@@ hidden_output
init -> -1
init -> -1
init -> -1
init -> 1
alloc -> #0
alloc -> NULL
avail -> 0

@@@ hidden_input
init 8 64 16
alloc
freeoff 8
freeoff -8
freeoff 64
freeoff 72
free 1
free 0
avail
@@@ hidden_output
init -> 4
alloc -> #0
freeoff 8 -> -2
freeoff -8 -> -2
freeoff 64 -> -2
freeoff 72 -> -2
free #1 -> -3
free #0 -> 0
avail -> 4

@@@ hidden_input
init 5 200 24
alloc
alloc
alloc
free 1
free 2
alloc
alloc
alloc
avail
@@@ hidden_output
init -> 8
alloc -> #0
alloc -> #1
alloc -> #2
free #1 -> 0
free #2 -> 0
alloc -> #2
alloc -> #1
alloc -> #3
avail -> 4

@@@ hidden_input
init 0 512 1
allocn 70
avail
free 63
free 0
alloc
alloc
alloc
@@@ hidden_output
init -> 64
allocn -> 64
avail -> 0
free #63 -> 0
free #0 -> 0
alloc -> #0
alloc -> #63
alloc -> NULL

@@@ hidden_input
init 0 48 16
alloc
alloc
free 0
free 0
alloc
free 0
free 1
free 2
avail
@@@ hidden_output
init -> 3
alloc -> #0
alloc -> #1
free #0 -> 0
free #0 -> -3
alloc -> #0
free #0 -> 0
free #1 -> 0
free #2 -> -3
avail -> 3

@@@ hidden_input
init 7 41 8
allocn 5
free 4
free 2
alloc
alloc
avail
@@@ hidden_output
init -> 5
allocn -> 5
free #4 -> 0
free #2 -> 0
alloc -> #2
alloc -> #4
avail -> 0

@@@ hint
Do the address math on integers: `uintptr_t a = (uintptr_t)mem; size_t skip = (A - a % A) % A;` with `A = sizeof(void *)`. Validate everything (sizes, `skip < mem_size`, at least one block) **before** writing anything. Build the free list from the last block down to block 0, so that block 0 ends up at the head.
@@@ hint
Read and write the "next" pointer stored inside a free block with `memcpy(&next, blk, sizeof next)` / `memcpy(blk, &next, sizeof next)`. That is aliasing-safe; `*(void **)blk` also works once blocks are aligned. In `pool_free`, compare **`uintptr_t`** values for the range and modulo checks (relational `<` on pointers to different objects is undefined), then walk the free list to detect a double free.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>
#include <string.h>

typedef struct {
    unsigned char *start;
    unsigned char *end;
    size_t block_size;
    void *free_list;
    size_t free_count;
} pool_t;

#define POOL_ALIGN (sizeof(void *))

/* The free list lives INSIDE the free blocks: their first bytes hold the next pointer. */
static void *next_of(const void *blk)
{
    void *n;
    memcpy(&n, blk, sizeof n);
    return n;
}

static void set_next(void *blk, void *n)
{
    memcpy(blk, &n, sizeof n);
}

int pool_init(pool_t *p, void *mem, size_t mem_size, size_t block_size)
{
    if (p == NULL || mem == NULL || block_size == 0)
        return -1;

    size_t bs = (block_size + POOL_ALIGN - 1) / POOL_ALIGN * POOL_ALIGN;
    uintptr_t a = (uintptr_t)mem;
    size_t skip = (size_t)((POOL_ALIGN - a % POOL_ALIGN) % POOL_ALIGN);
    if (mem_size <= skip)
        return -1;
    size_t n = (mem_size - skip) / bs;
    if (n == 0)
        return -1;                                    /* nothing written yet */

    unsigned char *start = (unsigned char *)mem + skip;
    p->start = start;
    p->end = start + n * bs;
    p->block_size = bs;
    p->free_list = NULL;
    for (size_t i = n; i-- > 0;) {                    /* push N-1 ... 0: block 0 ends on top */
        set_next(start + i * bs, p->free_list);
        p->free_list = start + i * bs;
    }
    p->free_count = n;
    return (int)n;
}

void *pool_alloc(pool_t *p)
{
    if (p == NULL || p->free_list == NULL)
        return NULL;
    void *blk = p->free_list;
    p->free_list = next_of(blk);                      /* pop: O(1) */
    p->free_count--;
    return blk;
}

int pool_free(pool_t *p, void *blk)
{
    if (p == NULL || blk == NULL)
        return -1;

    uintptr_t a = (uintptr_t)blk;
    uintptr_t s = (uintptr_t)p->start;
    uintptr_t e = (uintptr_t)p->end;
    if (a < s || a >= e || (a - s) % p->block_size != 0)
        return -2;                                    /* wild pointer: not one of our blocks */

    for (void *f = p->free_list; f != NULL; f = next_of(f))
        if (f == blk)
            return -3;                                /* double free */

    set_next(blk, p->free_list);                      /* push: LIFO reuse */
    p->free_list = blk;
    p->free_count++;
    return 0;
}

size_t pool_available(const pool_t *p)
{
    return p != NULL ? p->free_count : 0;
}
@@@ explanation_md
**Approach.**

*Layout.* Round the block size up to a multiple of the pointer size, so that every block can hold the `next` pointer and stays aligned. Align the start of the first block by skipping 0..7 bytes, using integer arithmetic on `uintptr_t`:

```
mem = arena+3     skip = (8 - 3 % 8) % 8 = 5
|xxx|.....|blk0 (16)|blk1 (16)|...|tail|      N = (size - skip) / 16
         ^start
```

*Embedded free list.* A free block's payload is unused, so its first 8 bytes store the address of the next free block. The list costs zero extra RAM. Allocation pops the head and free pushes onto it, both O(1) and deterministic (no fragmentation), which is why RTOSes (FreeRTOS `heap_1`, OSEK/AUTOSAR fixed pools, Zephyr `k_mem_slab`) use this design.

*Defensive free.* `free` must not trust its argument:
- **NULL**: rejected.
- **wild** (not a block of this pool): detected by a range check plus `(a - start) % block_size`, done on `uintptr_t`, because relational comparison of unrelated pointers is undefined (C11 6.5.8p5).
- **double free**: detected by walking the free list. Without this check, the same block would be on the list twice, and two later `alloc` calls would hand the same memory to two owners.

**Complexity.** `pool_init` O(N), `pool_alloc` O(1), `pool_free` O(F) for F free blocks (O(1) without the double-free check), `pool_available` O(1). Space: O(1) metadata, in `pool_t` only.

**Common mistakes**
- Not rounding the block size. With 12-byte blocks the `next` pointer of block 1 is misaligned (UBSan: misaligned store), and on Cortex-M0 that is a HardFault.
- Ignoring a misaligned `mem`, or rounding `mem` **down** (writes before the buffer: `OUT OF BOUNDS WRITE`).
- Writing the free list before validating the arguments, then returning `-1` with a half-initialised buffer.
- Comparing `blk < p->start` with raw pointers from unrelated objects, or forgetting the block-boundary (`%`) check, which accepts interior pointers.
- Keeping metadata (headers, "in use" flags) inside allocated blocks. The application's data overwrites it.

**Interview follow-ups**
- Make the pool thread/ISR-safe. Which operations need a critical section, and is a lock-free stack (CAS on `free_list`) safe from the ABA problem?
- Replace the O(F) double-free scan with an O(1) check using a bitmap of N bits. How much RAM is that for 64 blocks?
- Why does storing a `void *` into a `static unsigned char buf[]` through `*(void **)` technically violate strict aliasing, and why does `memcpy` (or a union with `max_align_t`) avoid it?
- How would you size the pools for an ECU at design time (worst-case analysis, high-water marks via `pool_available`)?
