@@@ meta
id: STC-H-06
topic: Structures
difficulty: Hard
type: FUNCTION
title: Fixed-Block Memory Pool with a Union Free List
tags: embedded, union, memory-pool, free-list, static-memory, misra, asked-in-automotive
@@@ statement_md
MISRA C forbids `malloc` after start-up, so the ECU allocates CAN buffers from a **static pool of fixed-size blocks**. A free block stores the free-list link **inside itself**. An allocated block uses the same bytes for payload. This is done with a union:

```c
#define POOL_BLOCK_SIZE 24
#define POOL_MAX_BLOCKS 16

typedef union PoolBlock {
    union PoolBlock *next;                      /* meaningful while the block is FREE      */
    uint8_t          payload[POOL_BLOCK_SIZE];  /* meaningful while the block is ALLOCATED */
} PoolBlock;

struct Pool {
    PoolBlock  blocks[POOL_MAX_BLOCKS];
    PoolBlock *free_list;                       /* head of the singly linked free list */
    uint8_t    in_use[POOL_MAX_BLOCKS];
    size_t     nblocks;                         /* blocks actually managed (<= POOL_MAX_BLOCKS) */
    size_t     used;
    size_t     high_water;                      /* maximum value `used` ever reached */
};
```

Both types are defined by the judge. Implement:

```c
void  pool_init(struct Pool *p, size_t nblocks);
void *pool_alloc(struct Pool *p);
int   pool_free(struct Pool *p, void *ptr);
```

- **`pool_init`** manages `blocks[0 .. nblocks-1]`. The free list is in **ascending** order (`blocks[0]` first), `in_use` is cleared, and `used = high_water = 0`. It may be called again to reset the pool.
- **`pool_alloc`** takes the **head** of the free list, marks it in use, updates `used`/`high_water`, and returns its address. It returns `NULL` when no block is free. O(1).
- **`pool_free`** returns
  - `-1` if `ptr` is `NULL`, outside `blocks[0 .. nblocks-1]`, or not the **start** of a block;
  - `-2` if the block is not currently allocated (double free);
  - `0` on success, after pushing the block onto the **head** of the free list (LIFO reuse). O(1).

  Validate pointers with `uintptr_t` arithmetic. The caller fills the whole payload after `pool_alloc`, which overwrites the `next` link, so never keep information in an allocated block.

**How it is tested.** The harness keeps handles `h[s]` and processes commands. After every successful `ALLOC` it fills all 24 payload bytes with a pattern, and it checks that pattern before every `FREE`.
- `INIT n`
- `ALLOC s` prints `ALLOC s -> block k` or `ALLOC s -> NULL`.
- `FREE s` prints `FREE s -> <ret>`. `FREEOFF s off` frees `(uint8_t *)h[s] + off`. `FREEX` frees the address of a local variable. `FREEEND` frees `&blocks[nblocks]`.
- `STAT` prints `used=U high=H free: <block indices in free-list order>` (`-` if empty).

**Example**
```
Input:
INIT 4
ALLOC 0
ALLOC 1
ALLOC 2
FREE 1
ALLOC 3
STAT
FREE 0
FREE 0
STAT

Output:
ALLOC 0 -> block 0
ALLOC 1 -> block 1
ALLOC 2 -> block 2
FREE 1 -> 0
ALLOC 3 -> block 1
STAT used=3 high=3 free: 3
FREE 0 -> 0
FREE 0 -> -2
STAT used=2 high=3 free: 0 3
```
@@@ constraints_md
- `0 <= n <= 16`; handle slots `0 <= s < 64`; at most 200 commands.
- No dynamic memory. Every operation is O(1).
- Do not compare pointers to different objects with `<`/`>`. Convert them to `uintptr_t` first.
@@@ starter_code
#include <stdint.h>
#include <stddef.h>

/* Already defined by the judge:
 *
 * #define POOL_BLOCK_SIZE 24
 * #define POOL_MAX_BLOCKS 16
 * typedef union PoolBlock { union PoolBlock *next; uint8_t payload[POOL_BLOCK_SIZE]; } PoolBlock;
 * struct Pool { PoolBlock blocks[POOL_MAX_BLOCKS]; PoolBlock *free_list;
 *               uint8_t in_use[POOL_MAX_BLOCKS]; size_t nblocks, used, high_water; };
 */

void pool_init(struct Pool *p, size_t nblocks)
{
    /* TODO */
    (void)p;
    (void)nblocks;
}

void *pool_alloc(struct Pool *p)
{
    /* TODO */
    (void)p;
    return NULL;
}

int pool_free(struct Pool *p, void *ptr)
{
    /* TODO */
    (void)p;
    (void)ptr;
    return -1;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>

#define POOL_BLOCK_SIZE 24
#define POOL_MAX_BLOCKS 16

typedef union PoolBlock {
    union PoolBlock *next;
    uint8_t          payload[POOL_BLOCK_SIZE];
} PoolBlock;

struct Pool {
    PoolBlock  blocks[POOL_MAX_BLOCKS];
    PoolBlock *free_list;
    uint8_t    in_use[POOL_MAX_BLOCKS];
    size_t     nblocks;
    size_t     used;
    size_t     high_water;
};

/*USER_CODE*/

static struct Pool pool;
static void *h[64];
static int live[64];

static int block_index(const void *ptr)
{
    uintptr_t a = (uintptr_t)ptr, b = (uintptr_t)pool.blocks;
    if (ptr == NULL || a < b) return -1;
    uintptr_t off = a - b;
    if (off % sizeof(PoolBlock) != 0 || off / sizeof(PoolBlock) >= POOL_MAX_BLOCKS) return -1;
    return (int)(off / sizeof(PoolBlock));
}

static uint8_t pattern(int s) { return (uint8_t)(0x11 * (s % 15 + 1)); }

int main(void)
{
    char cmd[12];
    while (scanf("%11s", cmd) == 1) {
        if (strcmp(cmd, "INIT") == 0) {
            unsigned n;
            if (scanf("%u", &n) != 1 || n > POOL_MAX_BLOCKS) break;
            memset(&pool, 0xEE, sizeof pool);                /* the user must initialise everything */
            pool_init(&pool, n);
            memset(h, 0, sizeof h);
            memset(live, 0, sizeof live);
        } else if (strcmp(cmd, "ALLOC") == 0) {
            int s;
            if (scanf("%d", &s) != 1 || s < 0 || s >= 64) break;
            void *ptr = pool_alloc(&pool);
            int k = block_index(ptr);
            if (ptr == NULL) {
                printf("ALLOC %d -> NULL\n", s);
            } else if (k < 0 || (size_t)k >= pool.nblocks) {
                printf("ALLOC %d -> BAD POINTER\n", s);
                return 0;
            } else {
                printf("ALLOC %d -> block %d\n", s, k);
                memset(ptr, pattern(s), POOL_BLOCK_SIZE);     /* clobbers the old `next` link */
                h[s] = ptr;
                live[s] = 1;
            }
        } else if (strcmp(cmd, "FREE") == 0 || strcmp(cmd, "FREEOFF") == 0) {
            int s, off = 0;
            if (scanf("%d", &s) != 1 || s < 0 || s >= 64) break;
            if (cmd[4] == 'O' && scanf("%d", &off) != 1) break;
            if (live[s] && off == 0) {
                const uint8_t *q = h[s];
                for (int i = 0; i < POOL_BLOCK_SIZE; i++)
                    if (q[i] != pattern(s)) { printf("CORRUPTED %d\n", s); break; }
            }
            void *ptr = h[s] ? (void *)((uint8_t *)h[s] + off) : NULL;
            int r = pool_free(&pool, ptr);
            if (r == 0 && off == 0) live[s] = 0;
            if (off) printf("FREEOFF %d %d -> %d\n", s, off, r);
            else printf("FREE %d -> %d\n", s, r);
        } else if (strcmp(cmd, "FREEX") == 0) {
            int local = 0;
            printf("FREEX -> %d\n", pool_free(&pool, &local));
        } else if (strcmp(cmd, "FREEEND") == 0) {
            printf("FREEEND -> %d\n", pool_free(&pool, &pool.blocks[pool.nblocks]));
        } else if (strcmp(cmd, "STAT") == 0) {
            printf("STAT used=%u high=%u free:", (unsigned)pool.used, (unsigned)pool.high_water);
            int cnt = 0;
            for (PoolBlock *b = pool.free_list; b != NULL; b = b->next) {
                int k = block_index(b);
                if (k < 0 || cnt > POOL_MAX_BLOCKS) { printf(" ?"); break; }
                printf(" %d", k);
                cnt++;
            }
            printf("%s\n", cnt ? "" : " -");
        }
    }
    return 0;
}
@@@ sample_input
INIT 4
ALLOC 0
ALLOC 1
ALLOC 2
FREE 1
ALLOC 3
STAT
FREE 0
FREE 0
STAT
@@@ sample_output
ALLOC 0 -> block 0
ALLOC 1 -> block 1
ALLOC 2 -> block 2
FREE 1 -> 0
ALLOC 3 -> block 1
STAT used=3 high=3 free: 3
FREE 0 -> 0
FREE 0 -> -2
STAT used=2 high=3 free: 0 3

@@@ sample_input
INIT 2
ALLOC 0
ALLOC 1
ALLOC 2
STAT
FREE 2
@@@ sample_output
ALLOC 0 -> block 0
ALLOC 1 -> block 1
ALLOC 2 -> NULL
STAT used=2 high=2 free: -
FREE 2 -> -1

@@@ hidden_input
INIT 4
ALLOC 0
FREEOFF 0 1
FREEOFF 0 23
FREEOFF 0 24
FREEX
FREEEND
STAT
FREE 0
STAT
@@@ hidden_output
ALLOC 0 -> block 0
FREEOFF 0 1 -> -1
FREEOFF 0 23 -> -1
FREEOFF 0 24 -> -2
FREEX -> -1
FREEEND -> -1
STAT used=1 high=1 free: 1 2 3
FREE 0 -> 0
STAT used=0 high=1 free: 0 1 2 3

@@@ hidden_input
INIT 3
ALLOC 0
ALLOC 1
FREE 0
FREE 0
FREE 1
ALLOC 2
ALLOC 3
ALLOC 4
ALLOC 5
STAT
@@@ hidden_output
ALLOC 0 -> block 0
ALLOC 1 -> block 1
FREE 0 -> 0
FREE 0 -> -2
FREE 1 -> 0
ALLOC 2 -> block 1
ALLOC 3 -> block 0
ALLOC 4 -> block 2
ALLOC 5 -> NULL
STAT used=3 high=3 free: -

@@@ hidden_input
INIT 0
ALLOC 0
STAT
FREEEND
INIT 1
ALLOC 0
ALLOC 1
FREE 0
ALLOC 2
STAT
@@@ hidden_output
ALLOC 0 -> NULL
STAT used=0 high=0 free: -
FREEEND -> -1
ALLOC 0 -> block 0
ALLOC 1 -> NULL
FREE 0 -> 0
ALLOC 2 -> block 0
STAT used=1 high=1 free: -

@@@ hidden_input
INIT 16
ALLOC 0
ALLOC 1
ALLOC 2
ALLOC 3
ALLOC 4
ALLOC 5
ALLOC 6
ALLOC 7
ALLOC 8
ALLOC 9
ALLOC 10
ALLOC 11
ALLOC 12
ALLOC 13
ALLOC 14
ALLOC 15
ALLOC 16
FREEEND
FREE 3
FREE 15
FREE 0
STAT
ALLOC 20
ALLOC 21
ALLOC 22
ALLOC 23
STAT
@@@ hidden_output
ALLOC 0 -> block 0
ALLOC 1 -> block 1
ALLOC 2 -> block 2
ALLOC 3 -> block 3
ALLOC 4 -> block 4
ALLOC 5 -> block 5
ALLOC 6 -> block 6
ALLOC 7 -> block 7
ALLOC 8 -> block 8
ALLOC 9 -> block 9
ALLOC 10 -> block 10
ALLOC 11 -> block 11
ALLOC 12 -> block 12
ALLOC 13 -> block 13
ALLOC 14 -> block 14
ALLOC 15 -> block 15
ALLOC 16 -> NULL
FREEEND -> -1
FREE 3 -> 0
FREE 15 -> 0
FREE 0 -> 0
STAT used=13 high=16 free: 0 15 3
ALLOC 20 -> block 0
ALLOC 21 -> block 15
ALLOC 22 -> block 3
ALLOC 23 -> NULL
STAT used=16 high=16 free: -

@@@ hidden_input
INIT 5
ALLOC 0
ALLOC 1
ALLOC 2
FREE 2
FREE 1
FREE 0
STAT
ALLOC 3
ALLOC 4
STAT
INIT 5
STAT
@@@ hidden_output
ALLOC 0 -> block 0
ALLOC 1 -> block 1
ALLOC 2 -> block 2
FREE 2 -> 0
FREE 1 -> 0
FREE 0 -> 0
STAT used=0 high=3 free: 0 1 2 3 4
ALLOC 3 -> block 0
ALLOC 4 -> block 1
STAT used=2 high=3 free: 2 3 4
STAT used=0 high=0 free: 0 1 2 3 4

@@@ hidden_input
INIT 6
ALLOC 0
ALLOC 1
ALLOC 2
ALLOC 3
FREE 1
FREE 3
FREE 1
ALLOC 4
ALLOC 5
ALLOC 6
ALLOC 7
ALLOC 8
STAT
FREE 4
FREE 5
FREE 6
FREE 7
FREE 0
FREE 2
STAT
@@@ hidden_output
ALLOC 0 -> block 0
ALLOC 1 -> block 1
ALLOC 2 -> block 2
ALLOC 3 -> block 3
FREE 1 -> 0
FREE 3 -> 0
FREE 1 -> -2
ALLOC 4 -> block 3
ALLOC 5 -> block 1
ALLOC 6 -> block 4
ALLOC 7 -> block 5
ALLOC 8 -> NULL
STAT used=6 high=6 free: -
FREE 4 -> 0
FREE 5 -> 0
FREE 6 -> 0
FREE 7 -> 0
FREE 0 -> 0
FREE 2 -> 0
STAT used=0 high=6 free: 2 0 5 4 1 3

@@@ hint
`pool_init`: `for (i = 0; i + 1 < n; i++) p->blocks[i].next = &p->blocks[i + 1];`, terminate the last block with `NULL`, and set `free_list = n ? &p->blocks[0] : NULL`. Alloc pops the head; free pushes onto the head. Both are two pointer assignments.
@@@ hint
Validate in `pool_free` with integers: `off = (uintptr_t)ptr - (uintptr_t)p->blocks`. It must satisfy `(uintptr_t)ptr >= base`, `off % sizeof(PoolBlock) == 0` and `off / sizeof(PoolBlock) < p->nblocks`. Only then look at `in_use[idx]`. Checking `in_use` before pushing is what keeps a double free from linking the same block twice, which would create a cycle in the free list.
@@@ solution_code
#include <stdint.h>
#include <stddef.h>

void pool_init(struct Pool *p, size_t nblocks)
{
    if (nblocks > POOL_MAX_BLOCKS)
        nblocks = POOL_MAX_BLOCKS;
    p->nblocks = nblocks;
    p->used = 0;
    p->high_water = 0;
    for (size_t i = 0; i < POOL_MAX_BLOCKS; i++)
        p->in_use[i] = 0;
    for (size_t i = 0; i + 1 < nblocks; i++)
        p->blocks[i].next = &p->blocks[i + 1];      /* free block: union holds the link */
    if (nblocks)
        p->blocks[nblocks - 1].next = NULL;
    p->free_list = nblocks ? &p->blocks[0] : NULL;
}

void *pool_alloc(struct Pool *p)
{
    PoolBlock *b = p->free_list;
    if (b == NULL)
        return NULL;
    p->free_list = b->next;                         /* read the link BEFORE the caller overwrites it */
    p->in_use[b - p->blocks] = 1;
    if (++p->used > p->high_water)
        p->high_water = p->used;
    return b->payload;                              /* same address as b */
}

int pool_free(struct Pool *p, void *ptr)
{
    if (ptr == NULL)
        return -1;
    uintptr_t base = (uintptr_t)p->blocks;
    uintptr_t addr = (uintptr_t)ptr;
    if (addr < base)
        return -1;
    uintptr_t off = addr - base;
    if (off % sizeof(PoolBlock) != 0)
        return -1;                                  /* points into the middle of a block */
    size_t idx = (size_t)(off / sizeof(PoolBlock));
    if (idx >= p->nblocks)
        return -1;                                  /* beyond the managed blocks */
    if (!p->in_use[idx])
        return -2;                                  /* double free */

    PoolBlock *b = &p->blocks[idx];
    p->in_use[idx] = 0;
    p->used--;
    b->next = p->free_list;                         /* payload is dead: reuse the bytes as the link */
    p->free_list = b;
    return 0;
}
@@@ explanation_md
**Approach.** The union is the whole trick. A block is **either** free (its first 8 bytes are the `next` link) **or** allocated (all 24 bytes are user payload), never both. The free list therefore costs no extra RAM. Allocation pops the head and freeing pushes onto the head: O(1), deterministic, no fragmentation. This is why such pools are the standard replacement for `malloc` in AUTOSAR and RTOS code (FreeRTOS `heap_1`-style pools, ThreadX block pools).

Pointer validation uses integer arithmetic on `uintptr_t`. Relational comparison of pointers into different objects (`ptr < p->blocks`) is undefined (C11 6.5.8p5). The `in_use` table makes double-free detection O(1). Without it, freeing a block twice links it into the list twice, the list becomes cyclic, and two later `pool_alloc` calls return the **same** block.

```
init 4:      free -> 0 -> 1 -> 2 -> 3
alloc x3:    free -> 3              (0, 1, 2 handed out; their links get overwritten)
free 1:      free -> 1 -> 3         (LIFO: block 1 is warm in the cache)
```

**Complexity.** `pool_alloc` and `pool_free` are O(1). `pool_init` is O(n). Space: `n * 24` bytes of blocks plus `n` flag bytes. The links live inside the blocks.

**Common mistakes**
- Reading `b->next` **after** returning the block. The caller has already overwritten it with payload (the harness's pattern fill makes this fail immediately).
- Accepting interior pointers (`ptr + 1`) or `&blocks[nblocks]` when `nblocks < POOL_MAX_BLOCKS`. Validate against `nblocks`, not the array size.
- No double-free check, which corrupts the free list into a cycle.
- Forgetting `high_water`, the number every ECU memory budget report asks for.
- Making `PoolBlock` a struct with separate `next` and `payload` members. It works, but every block then wastes 8 bytes.

**Interview follow-ups**
- The union is 24 bytes and pointer-aligned. How do you guarantee alignment for payloads that hold `double` or `uint64_t` on a 32-bit target? (Add a `max_align_t` or `uint64_t` member.)
- Make `pool_alloc`/`pool_free` safe to call from an ISR and a task at the same time. (Critical section, or a lock-free stack with an ABA tag.)
- How would you support several block sizes (32/64/256 bytes) with one API?
- Why is a fixed-block pool considered deterministic (WCET-analyzable) while `malloc` is not?
