@@@ meta
id: MEM-H-01
topic: Dynamic Memory
difficulty: Hard
type: FUNCTION
title: Fixed-Block Memory Pool With an O(1) Free List
tags: embedded, memory-pool, free-list, misra, no-malloc, deterministic, asked-in-automotive
@@@ statement_md
Safety-critical ECU software must not use `malloc`/`free` (MISRA C:2012 **Rule 21.3**, **Directive 4.12**). Still, a CAN/LIN stack needs buffers that come and go at run time. The standard answer is a **fixed-block pool**: a static area cut into equal blocks, handed out and taken back in **O(1)** through a free list stored *inside the free blocks themselves*.

The pool area is provided by the linker script (here: by the harness):

```c
#define BLOCK_SIZE 32u
#define NUM_BLOCKS 16u
extern unsigned char g_pool_area[NUM_BLOCKS * BLOCK_SIZE];   /* aligned to max_align_t */
```

Implement:

```c
void   pool_init(void);         /* (re)build the pool: all blocks free */
void  *pool_alloc(void);        /* O(1): a free block, or NULL if exhausted */
int    pool_free(void *p);      /* O(1): 0 ok, -1 invalid pointer, -2 double free */
size_t pool_available(void);    /* number of free blocks */
```

Requirements:
- **No `malloc`/`calloc`/`realloc`** (they are disabled in this exercise). Only static variables.
- After `pool_init`, blocks are handed out in address order (block 0, 1, 2, ...). The free list is **LIFO**: `pool_alloc` returns the block freed most recently.
- `pool_free(NULL)` is a no-op that returns `0`.
- `pool_free(p)` returns `-1` (and changes nothing) if `p` is not the **start** of a block inside `g_pool_area`. It returns `-2` (and changes nothing) if that block is already free (double free).
- The caller may use all `BLOCK_SIZE` bytes of an allocated block. Your bookkeeping may only live in *free* blocks or in your own static variables.
- `pool_alloc`, `pool_free` and `pool_available` must be O(1). No loops over the blocks.

**How it is tested.** The harness runs a script. After each successful allocation it fills the block with a pattern, and `S` verifies that no live block was overwritten.

**Input (read by the hidden harness)**, one operation per line:
- `I`: `pool_init()`, prints `init avail=<n>`.
- `A`: allocate. On success the block gets the next handle number `k` (1, 2, 3, ...) and the harness prints `A#<k> -> block <index>`; on failure it prints `A -> NULL` (no handle is used).
- `Z`: allocate until `NULL`. Each success gets the next handle number. Prints `Z -> <count> blocks`.
- `F <k>`: `pool_free(handle k)`, prints `F #<k> -> <rc>`.
- `N`: `pool_free(NULL)`. `X <off>`: `pool_free(g_pool_area + off)`. `O`: `pool_free(pointer to another object)`. Each prints `-> <rc>`.
- `S`: prints `avail=<n> live=<harness count> data=<ok|CORRUPTED>`.
- `R <n> <seed>`: `n` random alloc/free operations, then a summary line.

**Example**
```
Input:
I
A
A
A
F 2
A
S

Output:
init avail=16
A#1 -> block 0
A#2 -> block 1
A#3 -> block 2
F #2 -> 0
A#4 -> block 1
S avail=13 live=3 data=ok
```
@@@ constraints_md
- `BLOCK_SIZE = 32`, `NUM_BLOCKS = 16` (do not hard-code the numbers; use the macros).
- `sizeof(void *) <= BLOCK_SIZE`; `g_pool_area` is suitably aligned for any object type.
- At most 2000 operations per test.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define BLOCK_SIZE 32u
#define NUM_BLOCKS 16u
extern unsigned char g_pool_area[NUM_BLOCKS * BLOCK_SIZE]; /* provided, aligned */

void pool_init(void)
{
    /* TODO: link all blocks into a free list (block 0 first) */
}

void *pool_alloc(void)
{
    /* TODO: pop the head of the free list in O(1) */
    return NULL;
}

int pool_free(void *p)
{
    /* TODO: validate p, detect double free, push p on the free list in O(1) */
    return -1;
}

size_t pool_available(void)
{
    /* TODO */
    return 0;
}
@@@ harness_code
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

_Alignas(max_align_t) unsigned char g_pool_area[16u * 32u];
static unsigned char g_other[64];

#ifdef malloc
#undef malloc
#endif
#ifdef calloc
#undef calloc
#endif
#ifdef realloc
#undef realloc
#endif
#define malloc(n) malloc_is_not_allowed_in_a_pool_allocator
#define calloc(c, n) calloc_is_not_allowed_in_a_pool_allocator
#define realloc(p, n) realloc_is_not_allowed_in_a_pool_allocator

/*USER_CODE*/

#undef malloc
#undef calloc
#undef realloc

#define MAXH 2100
static unsigned char *h[MAXH + 1];
static int live[MAXH + 1];
static int nh;
static int nlive;

static long long block_index(const unsigned char *p)
{
    uintptr_t off = (uintptr_t)p - (uintptr_t)g_pool_area;
    if (off >= sizeof g_pool_area || off % BLOCK_SIZE != 0)
        return -1;
    return (long long)(off / BLOCK_SIZE);
}

/* returns block index, -1 for NULL, -2 for a bad pointer */
static long long do_alloc(void)
{
    unsigned char *p = pool_alloc();
    if (nh >= MAXH)
        return -1;
    if (p == NULL)
        return -1;
    long long idx = block_index(p);
    if (idx < 0)
        return -2;
    h[++nh] = p;
    live[nh] = 1;
    nlive++;
    memset(p, nh & 0xFF, BLOCK_SIZE);
    return idx;
}

static int data_ok(void)
{
    for (int k = 1; k <= nh; k++) {
        if (!live[k])
            continue;
        for (size_t i = 0; i < BLOCK_SIZE; i++)
            if (h[k][i] != (unsigned char)(k & 0xFF))
                return 0;
    }
    return 1;
}

int main(void)
{
    char op[4];
    while (scanf("%3s", op) == 1) {
        if (op[0] == 'I') {
            pool_init();
            for (int k = 1; k <= nh; k++)
                live[k] = 0;
            nlive = 0;
            printf("init avail=%zu\n", pool_available());
        } else if (op[0] == 'A') {
            int before = nh;
            long long idx = do_alloc();
            if (idx == -2) {
                printf("A -> BAD POINTER\n");
                return 0;
            }
            if (idx < 0 || nh == before)
                printf("A -> NULL\n");
            else
                printf("A#%d -> block %lld\n", nh, idx);
        } else if (op[0] == 'Z') {
            int cnt = 0;
            for (;;) {
                int before = nh;
                long long idx = do_alloc();
                if (idx == -2) {
                    printf("Z -> BAD POINTER\n");
                    return 0;
                }
                if (idx < 0 || nh == before)
                    break;
                cnt++;
                if (cnt > (int)NUM_BLOCKS)
                    break;
            }
            printf("Z -> %d blocks\n", cnt);
        } else if (op[0] == 'F') {
            int k;
            if (scanf("%d", &k) != 1 || k < 1 || k > nh)
                break;
            int rc = pool_free(h[k]);
            if (rc == 0 && live[k]) {
                live[k] = 0;
                nlive--;
            }
            printf("F #%d -> %d\n", k, rc);
        } else if (op[0] == 'N') {
            printf("N -> %d\n", pool_free(NULL));
        } else if (op[0] == 'X') {
            int off;
            if (scanf("%d", &off) != 1 || off < 0 || off > (int)sizeof g_pool_area)
                break;
            printf("X %d -> %d\n", off, pool_free(g_pool_area + off));
        } else if (op[0] == 'O') {
            printf("O -> %d\n", pool_free(g_other + 32));
        } else if (op[0] == 'S') {
            printf("S avail=%zu live=%d data=%s\n", pool_available(), nlive, data_ok() ? "ok" : "CORRUPTED");
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
                if (r % 5u < 3u || nlive == 0) {
                    int before = nh;
                    long long idx = do_alloc();
                    if (idx == -2) {
                        printf("R -> BAD POINTER\n");
                        return 0;
                    }
                    if (nh == before) {
                        nulls++;
                    } else {
                        allocs++;
                        hash = hash * 31u + (unsigned int)idx;
                    }
                } else {
                    int pick = (int)(r % (unsigned int)nlive), k;
                    for (k = 1; k <= nh; k++)
                        if (live[k] && pick-- == 0)
                            break;
                    int rc = pool_free(h[k]);
                    if (rc != 0)
                        printf("R: unexpected rc %d\n", rc);
                    live[k] = 0;
                    nlive--;
                    frees++;
                }
            }
            printf("R allocs=%d nulls=%d frees=%d hash=%u avail=%zu data=%s\n", allocs, nulls, frees, hash,
                   pool_available(), data_ok() ? "ok" : "CORRUPTED");
        }
    }
    return 0;
}
@@@ sample_input
I
A
A
A
F 2
A
S
@@@ sample_output
init avail=16
A#1 -> block 0
A#2 -> block 1
A#3 -> block 2
F #2 -> 0
A#4 -> block 1
S avail=13 live=3 data=ok

@@@ sample_input
I
A
N
X 31
X 512
O
F 1
F 1
S
@@@ sample_output
init avail=16
A#1 -> block 0
N -> 0
X 31 -> -1
X 512 -> -1
O -> -1
F #1 -> 0
F #1 -> -2
S avail=16 live=0 data=ok

@@@ hidden_input
I
Z
A
F 5
F 9
F 1
A
A
A
A
S
@@@ hidden_output
init avail=16
Z -> 16 blocks
A -> NULL
F #5 -> 0
F #9 -> 0
F #1 -> 0
A#17 -> block 0
A#18 -> block 8
A#19 -> block 4
A -> NULL
S avail=0 live=16 data=ok

@@@ hidden_input
I
A
A
A
A
F 1
F 2
F 3
F 4
A
A
A
A
A
S
@@@ hidden_output
init avail=16
A#1 -> block 0
A#2 -> block 1
A#3 -> block 2
A#4 -> block 3
F #1 -> 0
F #2 -> 0
F #3 -> 0
F #4 -> 0
A#5 -> block 3
A#6 -> block 2
A#7 -> block 1
A#8 -> block 0
A#9 -> block 4
S avail=11 live=5 data=ok

@@@ hidden_input
I
A
A
F 1
F 2
F 1
F 2
X 64
X 32
A
A
A
S
@@@ hidden_output
init avail=16
A#1 -> block 0
A#2 -> block 1
F #1 -> 0
F #2 -> 0
F #1 -> -2
F #2 -> -2
X 64 -> -2
X 32 -> -2
A#3 -> block 1
A#4 -> block 0
A#5 -> block 2
S avail=13 live=3 data=ok

@@@ hidden_input
I
Z
S
X 480
X 481
X 0
I
S
A
S
@@@ hidden_output
init avail=16
Z -> 16 blocks
S avail=0 live=16 data=ok
X 480 -> 0
X 481 -> -1
X 0 -> 0
init avail=16
S avail=16 live=0 data=ok
A#17 -> block 0
S avail=15 live=1 data=ok

@@@ hidden_input
I
R 1500 7
S
@@@ hidden_output
init avail=16
R allocs=619 nulls=278 frees=603 hash=1114331979 avail=0 data=ok
S avail=0 live=16 data=ok

@@@ hidden_input
I
R 300 1
I
R 1000 99
N
O
@@@ hidden_output
init avail=16
R allocs=130 nulls=54 frees=116 hash=3128647068 avail=2 data=ok
init avail=16
R allocs=411 nulls=194 frees=395 hash=3031120816 avail=0 data=ok
N -> 0
O -> -1

@@@ hint
A free block is unused memory, so it can store the pointer to the **next** free block. The pool then needs only a head pointer: `alloc` pops the head, `free` pushes the block back. Build the initial list from the **last** block to the first, so block 0 ends up at the head.
@@@ hint
Validate with integer arithmetic: `off = (uintptr_t)p - (uintptr_t)g_pool_area` must satisfy `off < NUM_BLOCKS * BLOCK_SIZE` and `off % BLOCK_SIZE == 0` (a pointer below the area wraps to a huge `off`). For O(1) double-free detection, keep a small static `uint8_t in_use[NUM_BLOCKS]` (or a bitmap). Store and load the next pointer with `memcpy` so you do not violate strict aliasing.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define BLOCK_SIZE 32u
#define NUM_BLOCKS 16u
extern unsigned char g_pool_area[NUM_BLOCKS * BLOCK_SIZE]; /* provided, aligned */

static unsigned char *s_head;            /* first free block, NULL when exhausted */
static size_t s_avail;
static uint8_t s_in_use[NUM_BLOCKS];     /* O(1) double-free detection */

/* the free list lives inside the free blocks: first bytes = pointer to next */
static void set_next(unsigned char *blk, unsigned char *next) { memcpy(blk, &next, sizeof next); }
static unsigned char *get_next(const unsigned char *blk)
{
    unsigned char *next;
    memcpy(&next, blk, sizeof next);
    return next;
}

void pool_init(void)
{
    s_head = NULL;
    for (size_t i = NUM_BLOCKS; i-- > 0;) {        /* last to first: block 0 ends at the head */
        unsigned char *blk = g_pool_area + i * BLOCK_SIZE;
        set_next(blk, s_head);
        s_head = blk;
        s_in_use[i] = 0;
    }
    s_avail = NUM_BLOCKS;
}

void *pool_alloc(void)
{
    unsigned char *blk = s_head;
    if (blk == NULL)
        return NULL;                                /* exhausted: deterministic failure */
    s_head = get_next(blk);
    s_in_use[(size_t)(blk - g_pool_area) / BLOCK_SIZE] = 1;
    s_avail--;
    return blk;
}

int pool_free(void *p)
{
    if (p == NULL)
        return 0;
    uintptr_t off = (uintptr_t)p - (uintptr_t)g_pool_area;   /* below the area -> wraps -> huge */
    if (off >= (uintptr_t)NUM_BLOCKS * BLOCK_SIZE || off % BLOCK_SIZE != 0)
        return -1;                                  /* not a block start inside the pool */
    size_t idx = (size_t)(off / BLOCK_SIZE);
    if (!s_in_use[idx])
        return -2;                                  /* double free: list stays intact */
    s_in_use[idx] = 0;
    unsigned char *blk = g_pool_area + idx * BLOCK_SIZE;
    set_next(blk, s_head);                          /* push: LIFO */
    s_head = blk;
    s_avail++;
    return 0;
}

size_t pool_available(void)
{
    return s_avail;
}
@@@ explanation_md
**Approach: an intrusive free list.**

```
g_pool_area: [blk0][blk1][blk2] ... [blk15]      (16 x 32 bytes, static)
after init:  head -> blk0 -> blk1 -> blk2 -> ... -> blk15 -> NULL
alloc:       p = head; head = next(p)            O(1)
free(p):     next(p) = head; head = p            O(1)
```

A free block's bytes are unused, so they hold the "next free" pointer. The pool needs no metadata per allocated block and no extra RAM except the head, a counter and a 16-byte `in_use` table for double-free detection. Allocated blocks are 100% usable by the caller.

**Validation.** Converting both pointers to `uintptr_t` and subtracting avoids relational comparison of unrelated pointers, which is undefined in ISO C. A pointer below the pool wraps to a huge unsigned offset, so one `off < size` check covers both ends. `off % BLOCK_SIZE` rejects interior pointers.

**Why pools instead of malloc in automotive code (MISRA C:2012 Rule 21.3, Dir 4.12)?**
- **Determinism / WCET.** `malloc` may search lists, split, coalesce or even call the OS. Its run time is unbounded, so worst-case execution time analysis is impossible. Pool operations take a few instructions.
- **No fragmentation.** With variable sizes, a long-running ECU can have enough free bytes but no contiguous block. All pool blocks are equal, so any free block satisfies any request.
- **Bounded, analyzable memory.** The pool size is fixed at link time, and exhaustion is a defined, testable error (`NULL`), not a surprise after 300 hours of driving.
- Typical rule set: allocate from pools only, and often only during initialization.

**Complexity.** `pool_init` is O(NUM_BLOCKS). `pool_alloc`, `pool_free` and `pool_available` are O(1). Space overhead is one pointer, one counter and `NUM_BLOCKS` bytes.

**Common mistakes**
- Building the list first-to-last, so block 15 is handed out first (works, but violates the address-order spec).
- Double-free detection by walking the free list: correct but O(n), which breaks the O(1) requirement.
- No double-free check at all: freeing a block twice creates a cycle, and two later allocations return the **same** block (the `data=CORRUPTED` symptom).
- Range check with `p < g_pool_area || p >= g_pool_area + size`. Relational comparison of pointers into different objects is UB, and compilers have optimized such checks away.
- `*(void **)blk = head;` is the textbook form. It works with GCC in practice but formally violates strict aliasing (the effective type is `unsigned char`). `memcpy` is the portable form and compiles to the same single store.

**Interview follow-ups**
- Make the pool **ISR-safe**: alloc from a CAN RX interrupt, free from a task. (Disable interrupts around the head update, or use a lock-free LDREX/STREX stack, and watch out for the ABA problem.)
- Support several block sizes (16/64/256): a pool per size class, with `alloc(size)` choosing the smallest class that fits. How do you pick the class counts?
- How would you add per-block guard words (canaries) to detect a caller writing past 32 bytes?
- How does this compare to FreeRTOS `heap_1` ... `heap_5`, or Zephyr `k_mem_slab`?
