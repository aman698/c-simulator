@@@ meta
id: RMM-M-01
topic: RTOS Memory Management
difficulty: Medium
type: FUNCTION
title: O(1) Fixed-Block Memory Pool With Mutex And Blocking Allocation
tags: freertos, memory-pool, fixed-block-allocator, mutex, counting-semaphore, embedded, asked-in-automotive
@@@ statement_md
`malloc()` is banned in your ECU project: it is non-deterministic, it fragments, and it is not thread-safe. Implement a **fixed-block memory pool** for FreeRTOS tasks. All blocks have the same size, every operation is **O(1)**, and a task may **wait** for a block when the pool is empty.

```c
#define POOL_MAX_BLOCKS 32

int    pool_init(uint8_t *storage, size_t block_size, size_t n_blocks);
void  *pool_alloc(TickType_t timeout);
int    pool_free(void *p);
size_t pool_available(void);
```

- **`pool_init`** is called once, before the scheduler starts. `storage` is `block_size * n_blocks` bytes, aligned for any type. Return `-1` (and do nothing) if `storage` is NULL, `n_blocks` is 0 or greater than `POOL_MAX_BLOCKS`, or `block_size` is smaller than `sizeof(void *)` or not a multiple of it. Otherwise set the pool up and return 0.
- **`pool_alloc(timeout)`** returns a free block. If none is free, it waits up to `timeout` ticks (0 = do not wait) and returns NULL on timeout. When several tasks wait, the **highest-priority** one is served first.
- **`pool_free(p)`** returns the block to the pool and returns 0. It returns **-1** if `p` is not the start of a block of this pool (NULL, outside the storage, or not on a block boundary), and **-2** if that block is already free (double free). In both error cases the pool is not changed.
- **`pool_available()`** returns the number of free blocks.

**Block order (part of the answer).** Keep the free blocks in a **LIFO free list**. Right after `pool_init`, allocations return block 0, 1, 2, ... in address order. A freed block is pushed on the front, so the next allocation returns the block freed most recently (it is still warm in the cache).

Protect the pool data with a FreeRTOS **mutex**, and use a **counting semaphore** (initial count = `n_blocks`) to wait for a free block. `malloc`, `calloc`, `realloc`, `free`, `pvPortMalloc` and `vPortFree` are not allowed (compile error). Creating the semaphores with the normal FreeRTOS API is fine.

**How it is tested.** The harness calls `pool_init`. It prints `init ok, available=<n>`, or `init failed` (and stops). Then it starts scripted tasks with distinct priorities, all ready at t=0, and runs the scheduler up to and including tick `D`. Each task executes its operations in order:

| op | meaning | printed |
|---|---|---|
| `A<s>:<t>` | `slot[s] = pool_alloc(t)` | `[t=..] <task> alloc s<s> -> block <k>` or `-> timeout` |
| `F<s>` | `pool_free(slot[s])` (a slot keeps its old pointer after a free) | `[t=..] <task> free s<s> -> <ret>` |
| `X` | `pool_free(storage + 1)`, which is inside block 0 but not its start | `[t=..] <task> free bad -> <ret>` |
| `O` | `pool_free(storage + n_blocks * block_size)` (one past the end) | `[t=..] <task> free end -> <ret>` |
| `W<n>` | `vTaskDelay(n)` | nothing |

`<k>` is the block index `(p - storage) / block_size`. The harness also checks every returned pointer: inside the storage, on a block boundary, not already handed out. It fills each block with a pattern and verifies the pattern when the block is freed. Problems print `BAD ...` / `CORRUPT` lines. After the run it prints `available=<n>`.

**Input**
```
<block_size> <n_blocks>
<n_tasks>
<name> <priority> <n_ops> <op> <op> ...     (n_tasks lines)
<D>
```

**Example**
```
Input:
16 3
2
T1 3 8 A0:0 A1:0 A2:0 A3:0 W5 F1 F1 X
T2 2 3 A4:10 F4 A5:0
20

Output:
init ok, available=3
[t=0] T1 alloc s0 -> block 0
[t=0] T1 alloc s1 -> block 1
[t=0] T1 alloc s2 -> block 2
[t=0] T1 alloc s3 -> timeout
[t=5] T1 free s1 -> 0
[t=5] T1 free s1 -> -2
[t=5] T1 free bad -> -1
[t=5] T2 alloc s4 -> block 1
[t=5] T2 free s4 -> 0
[t=5] T2 alloc s5 -> block 1
available=0
```
At t=0, T2 starts waiting for a block. At t=5, T1 frees block 1. The give makes T2 ready, but T1 (priority 3) keeps the CPU until it finishes its script, and only then T2 gets block 1.
@@@ constraints_md
- 1 <= n_blocks <= 32 for valid pools (tests also use invalid parameters), block_size <= 64.
- 1 <= n_tasks <= 4, distinct priorities in 1..6, at most 16 ops per task, slots 0..15, 0 <= timeout <= 1000, D <= 5000.
- O(1) per operation: no scanning of all blocks in `pool_alloc` / `pool_free`.
@@@ starter_code
#include <stdint.h>
#include <stddef.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

#define POOL_MAX_BLOCKS 32

int pool_init(uint8_t *storage, size_t block_size, size_t n_blocks)
{
    /* TODO: validate, build the LIFO free list, create a mutex and a counting semaphore */
    (void)storage; (void)block_size; (void)n_blocks;
    return -1;
}

void *pool_alloc(TickType_t timeout)
{
    /* TODO */
    (void)timeout;
    return NULL;
}

int pool_free(void *p)
{
    /* TODO: -1 not a block of this pool, -2 double free, 0 ok */
    (void)p;
    return -1;
}

size_t pool_available(void)
{
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdlib.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "sim.h"

#define malloc(...) malloc_is_not_allowed_here
#define calloc(...) calloc_is_not_allowed_here
#define realloc(...) realloc_is_not_allowed_here
#define free(...) free_is_not_allowed_here
#define pvPortMalloc(...) pvPortMalloc_is_not_allowed_here
#define vPortFree(...) vPortFree_is_not_allowed_here

/*USER_CODE*/

#undef malloc
#undef calloc
#undef realloc
#undef free
#undef pvPortMalloc
#undef vPortFree

#define MAX_TASKS 4
#define MAX_OPS   16
#define N_SLOTS   16

static union { uint64_t align; uint8_t bytes[POOL_MAX_BLOCKS * 64 + 64]; } g_mem;
static uint8_t *g_storage = g_mem.bytes;
static size_t g_bs, g_nb;
static uint8_t *g_slot[N_SLOTS];
static int g_held[N_SLOTS];

typedef struct {
    char name[8];
    unsigned prio;
    int n_ops;
    char ops[MAX_OPS][12];
} Script;

static Script g_tasks[MAX_TASKS];

static unsigned now(void) { return (unsigned)xTaskGetTickCount(); }

static void do_alloc(const Script *s, int slot, unsigned timeout)
{
    uint8_t *p = (uint8_t *)pool_alloc((TickType_t)timeout);
    size_t off, k;
    int j;

    if (p == NULL) {
        printf("[t=%u] %s alloc s%d -> timeout\n", now(), s->name, slot);
        return;
    }
    if (p < g_storage || p >= g_storage + g_bs * g_nb || (size_t)(p - g_storage) % g_bs != 0) {
        printf("[t=%u] %s alloc s%d -> BAD pointer\n", now(), s->name, slot);
        return;
    }
    off = (size_t)(p - g_storage);
    k = off / g_bs;
    for (j = 0; j < N_SLOTS; j++) {
        if (g_held[j] && g_slot[j] == p) {
            printf("[t=%u] %s alloc s%d -> BAD block %u already held by s%d\n", now(), s->name, slot,
                   (unsigned)k, j);
            return;
        }
    }
    memset(p, 0xA0 + slot, g_bs);
    g_slot[slot] = p;
    g_held[slot] = 1;
    printf("[t=%u] %s alloc s%d -> block %u\n", now(), s->name, slot, (unsigned)k);
}

static void do_free(const Script *s, int slot)
{
    uint8_t *p = g_slot[slot];
    size_t i;
    int r, was_held;

    if (g_held[slot]) {
        for (i = 0; i < g_bs; i++) {
            if (p[i] != (uint8_t)(0xA0 + slot)) {
                printf("[t=%u] %s CORRUPT block of s%d\n", now(), s->name, slot);
                break;
            }
        }
    }
    /* A higher-priority waiter may get this block (and print) inside pool_free(). */
    was_held = g_held[slot];
    g_held[slot] = 0;
    r = pool_free(p);
    if (r != 0) g_held[slot] = was_held;
    printf("[t=%u] %s free s%d -> %d\n", now(), s->name, slot, r);
}

static void script_task(void *pv)
{
    const Script *s = (const Script *)pv;
    int i, slot;
    unsigned arg;

    for (i = 0; i < s->n_ops; i++) {
        const char *op = s->ops[i];
        switch (op[0]) {
        case 'A':
            if (sscanf(op + 1, "%d:%u", &slot, &arg) == 2) do_alloc(s, slot, arg);
            break;
        case 'F':
            if (sscanf(op + 1, "%d", &slot) == 1) do_free(s, slot);
            break;
        case 'X':
            printf("[t=%u] %s free bad -> %d\n", now(), s->name, pool_free(g_storage + 1));
            break;
        case 'O':
            printf("[t=%u] %s free end -> %d\n", now(), s->name, pool_free(g_storage + g_bs * g_nb));
            break;
        case 'W':
            if (sscanf(op + 1, "%u", &arg) == 1) vTaskDelay((TickType_t)arg);
            break;
        default:
            break;
        }
    }
    vTaskDelete(NULL);
}

int main(void)
{
    unsigned bs, nb, dur;
    int n, i, j;

    if (scanf("%u %u %d", &bs, &nb, &n) != 3 || n < 1 || n > MAX_TASKS || bs > 64 || nb > 40) return 1;
    for (i = 0; i < n; i++) {
        Script *s = &g_tasks[i];
        if (scanf("%7s %u %d", s->name, &s->prio, &s->n_ops) != 3 || s->n_ops > MAX_OPS) return 1;
        for (j = 0; j < s->n_ops; j++) {
            if (scanf("%11s", s->ops[j]) != 1) return 1;
        }
    }
    if (scanf("%u", &dur) != 1) return 1;

    g_bs = bs;
    g_nb = nb;
    if (pool_init(g_storage, g_bs, g_nb) != 0) {
        printf("init failed\n");
        return 0;
    }
    printf("init ok, available=%u\n", (unsigned)pool_available());

    for (i = 0; i < n; i++) {
        xTaskCreate(script_task, g_tasks[i].name, configMINIMAL_STACK_SIZE * 2, &g_tasks[i],
                    (UBaseType_t)g_tasks[i].prio, NULL);
    }
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();
    printf("available=%u\n", (unsigned)pool_available());
    return 0;
}
@@@ sample_input
16 3
2
T1 3 8 A0:0 A1:0 A2:0 A3:0 W5 F1 F1 X
T2 2 3 A4:10 F4 A5:0
20
@@@ sample_output
init ok, available=3
[t=0] T1 alloc s0 -> block 0
[t=0] T1 alloc s1 -> block 1
[t=0] T1 alloc s2 -> block 2
[t=0] T1 alloc s3 -> timeout
[t=5] T1 free s1 -> 0
[t=5] T1 free s1 -> -2
[t=5] T1 free bad -> -1
[t=5] T2 alloc s4 -> block 1
[t=5] T2 free s4 -> 0
[t=5] T2 alloc s5 -> block 1
available=0
@@@ sample_input
8 2
2
P 4 5 A0:0 A1:0 W10 F0 F1
C 2 2 A2:3 A3:20
40
@@@ sample_output
init ok, available=2
[t=0] P alloc s0 -> block 0
[t=0] P alloc s1 -> block 1
[t=3] C alloc s2 -> timeout
[t=10] P free s0 -> 0
[t=10] P free s1 -> 0
[t=10] C alloc s3 -> block 1
available=1
@@@ hidden_input
4 4
1
T 1 0
10
@@@ hidden_output
init failed
@@@ hidden_input
12 4
1
T 1 0
10
@@@ hidden_output
init failed
@@@ hidden_input
16 0
1
T 1 0
10
@@@ hidden_output
init failed
@@@ hidden_input
8 33
1
T 1 0
10
@@@ hidden_output
init failed
@@@ hidden_input
64 32
1
T 3 16 A0:0 A1:0 A2:0 F1 F0 A3:0 A4:0 A5:0 O X F7 F2 F2 F5 F4 F3
10
@@@ hidden_output
init ok, available=32
[t=0] T alloc s0 -> block 0
[t=0] T alloc s1 -> block 1
[t=0] T alloc s2 -> block 2
[t=0] T free s1 -> 0
[t=0] T free s0 -> 0
[t=0] T alloc s3 -> block 0
[t=0] T alloc s4 -> block 1
[t=0] T alloc s5 -> block 3
[t=0] T free end -> -1
[t=0] T free bad -> -1
[t=0] T free s7 -> -1
[t=0] T free s2 -> 0
[t=0] T free s2 -> -2
[t=0] T free s5 -> 0
[t=0] T free s4 -> 0
[t=0] T free s3 -> 0
available=32
@@@ hidden_input
8 1
4
H 6 3 W2 A0:100 W1
M 4 3 W1 A1:100 W1
L 2 3 W3 A2:100 F2
K 5 3 A3:0 W10 F3
50
@@@ hidden_output
init ok, available=1
[t=0] K alloc s3 -> block 0
[t=10] H alloc s0 -> block 0
[t=10] K free s3 -> 0
available=0
@@@ hidden_input
32 2
3
A 5 6 A0:0 A1:0 W4 F0 W4 F1
B 3 3 A2:50 W20 F2
C 1 2 A3:50 F3
60
@@@ hidden_output
init ok, available=2
[t=0] A alloc s0 -> block 0
[t=0] A alloc s1 -> block 1
[t=4] A free s0 -> 0
[t=4] B alloc s2 -> block 0
[t=8] A free s1 -> 0
[t=8] C alloc s3 -> block 1
[t=8] C free s3 -> 0
[t=24] B free s2 -> 0
available=2
@@@ hint
Thread the free list **through the free blocks themselves**: the first `sizeof(void *)` bytes of a free block hold the pointer to the next free block. Allocation pops the head and freeing pushes it: both O(1), no extra RAM except one `uint8_t used[POOL_MAX_BLOCKS]` array for double-free detection.
@@@ hint
`pool_alloc`: `xSemaphoreTake(count_sem, timeout)` first (this is the waiting part), then pop under the mutex. `pool_free`: validate (`off = p - base; off < size && off % block_size == 0`, `used[off / block_size]`), push under the mutex, then `xSemaphoreGive(count_sem)`. Build the initial list from the last block to the first, so block 0 ends up at the head.
@@@ solution_code
#include <stdint.h>
#include <stddef.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

#define POOL_MAX_BLOCKS 32

typedef struct FreeBlock { struct FreeBlock *next; } FreeBlock;

static uint8_t          *s_base;
static size_t            s_bs, s_nb, s_free;
static FreeBlock        *s_head;                 /* LIFO free list, threaded through the blocks */
static uint8_t           s_used[POOL_MAX_BLOCKS];
static SemaphoreHandle_t s_lock;                 /* mutex: protects s_head / s_used / s_free */
static SemaphoreHandle_t s_avail;                /* counting: number of free blocks */

int pool_init(uint8_t *storage, size_t block_size, size_t n_blocks)
{
    size_t i;

    if (storage == NULL || n_blocks == 0 || n_blocks > POOL_MAX_BLOCKS ||
        block_size < sizeof(void *) || block_size % sizeof(void *) != 0) {
        return -1;
    }
    s_lock = xSemaphoreCreateMutex();
    s_avail = xSemaphoreCreateCounting(n_blocks, n_blocks);
    if (s_lock == NULL || s_avail == NULL) {
        return -1;
    }
    s_base = storage;
    s_bs = block_size;
    s_nb = n_blocks;
    s_free = n_blocks;
    s_head = NULL;
    for (i = n_blocks; i-- > 0;) {               /* push last..first: block 0 ends on top */
        FreeBlock *b = (FreeBlock *)(void *)(storage + i * block_size);
        b->next = s_head;
        s_head = b;
        s_used[i] = 0;
    }
    return 0;
}

void *pool_alloc(TickType_t timeout)
{
    FreeBlock *b;

    if (xSemaphoreTake(s_avail, timeout) != pdPASS) {
        return NULL;                             /* nothing freed within the timeout */
    }
    xSemaphoreTake(s_lock, portMAX_DELAY);
    b = s_head;                                  /* the semaphore guarantees b != NULL */
    s_head = b->next;
    s_used[((uint8_t *)b - s_base) / s_bs] = 1;
    s_free--;
    xSemaphoreGive(s_lock);
    return b;
}

int pool_free(void *p)
{
    uint8_t *q = (uint8_t *)p;
    size_t off, k;
    FreeBlock *b;

    if (q == NULL || q < s_base || q >= s_base + s_bs * s_nb) {
        return -1;
    }
    off = (size_t)(q - s_base);
    if (off % s_bs != 0) {
        return -1;
    }
    k = off / s_bs;
    xSemaphoreTake(s_lock, portMAX_DELAY);
    if (!s_used[k]) {
        xSemaphoreGive(s_lock);
        return -2;                               /* double free: pool untouched */
    }
    s_used[k] = 0;
    b = (FreeBlock *)p;
    b->next = s_head;
    s_head = b;
    s_free++;
    xSemaphoreGive(s_lock);
    xSemaphoreGive(s_avail);                     /* wakes the highest-priority waiter */
    return 0;
}

size_t pool_available(void)
{
    size_t n;

    xSemaphoreTake(s_lock, portMAX_DELAY);
    n = s_free;
    xSemaphoreGive(s_lock);
    return n;
}
@@@ explanation_md
**Approach.** A fixed-block pool removes everything that makes `malloc()` dangerous in an ECU. Every block has the same size, so there is no fragmentation and no search, and the worst-case memory is fixed at link time.

- **Free list in the blocks.** A free block is not in use, so its first bytes can hold the `next` pointer. That is why `block_size >= sizeof(void *)` and must be a multiple of it, which keeps every block pointer-aligned. `pool_alloc` pops the head and `pool_free` pushes: both O(1), LIFO.
- **Validation in O(1).** `off = p - base` must be `< n * bs` and a multiple of `bs`. A one-byte-per-block `used[]` array detects double frees. Without it, a double free puts the same block in the list twice, and two owners later get the same memory.
- **Two kernel objects, two jobs.** The **counting semaphore** counts free blocks and is where tasks *wait*. FreeRTOS keeps its waiters sorted by priority, so the highest-priority waiter gets the next free block. The **mutex** only protects the list for a few instructions. Take the counting semaphore *before* the mutex: a task never sleeps while holding the lock. `pool_free` gives the counting semaphore *after* the block is back in the list, so the woken task always finds it.

In the 1-block hidden test, H, M and L wait at the same time. When K (priority 5) frees the block at t=10, H (priority 6) gets it, even though M and L started waiting earlier. H even preempts K inside `pool_free()`, so H's `alloc` line comes before K's `free` line.

**Complexity.** O(1) time for every operation (plus the O(waiters) priority-ordered insertion inside the kernel when a task blocks). RAM: the storage + `n` bytes of `used` flags + two kernel objects. There is no per-block header, unlike heap_4's 16 bytes per allocation.

**Common mistakes**
- Waiting for a block while **holding the mutex**: the task that would free a block can never get the lock. That is a deadlock.
- Giving the counting semaphore on an invalid or double free: the count no longer matches the list, and a later `pool_alloc` pops NULL.
- Building the list first-to-last, so the first allocation returns the last block.
- Using a binary semaphore for "available": it cannot count free blocks.
- Calling `pool_alloc` from an ISR: the mutex cannot be used there (see the ISR-safe pool question).

**Interview follow-ups**
- How would you make the pool usable from an ISR (critical sections instead of a mutex, no blocking)?
- How do you support several block sizes (16 / 64 / 256) without fragmentation?
- Why is a block pool deterministic while heap_4 is not, even though heap_4 also coalesces?
- How would you add per-block guard words to detect overruns, and a high-water mark of the blocks in use?
