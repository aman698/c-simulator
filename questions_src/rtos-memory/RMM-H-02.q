@@@ meta
id: RMM-H-02
topic: RTOS Memory Management
difficulty: Hard
type: FUNCTION
title: Two-Class Block Pool Usable From ISRs And Tasks
tags: freertos, memory-pool, isr, critical-section, taskenter-critical-from-isr, high-water-mark, embedded, asked-in-automotive
@@@ statement_md
A CAN gateway receives frames in an interrupt. The ISR must store each frame in a buffer **immediately**, but it cannot call `malloc` or block on a mutex. Implement a deterministic **block pool with two size classes** that both interrupts and tasks can use, together with its run-time statistics.

```c
#define SMALL_SIZE 16
#define SMALL_N    8
#define LARGE_SIZE 64
#define LARGE_N    4

typedef struct {
    unsigned free_small, free_large;   /* free blocks now */
    unsigned min_small,  min_large;    /* lowest free count ever (high-water mark of use) */
    unsigned failures;                 /* allocations that returned NULL */
} PoolStats;

void  pool_init(void);
void *pool_alloc(size_t n);            /* task context */
void  pool_free(void *p);              /* task context */
void *pool_alloc_from_isr(size_t n);   /* interrupt context */
void  pool_free_from_isr(void *p);     /* interrupt context */
int   pool_block_class(const void *p); /* any context: 0 small, 1 large, -1 not a pool block */
void  pool_get_stats(PoolStats *s);    /* task context */
```

**Rules**
- The storage is static: `SMALL_N` blocks of 16 bytes and `LARGE_N` blocks of 64 bytes, every block 8-byte aligned. `pool_init()` (called before the scheduler starts) makes all blocks free and sets `min_* = SMALL_N / LARGE_N` and `failures = 0`.
- **Allocation of `n` bytes**: if `n == 0` or `n > LARGE_SIZE`, fail. If `n <= SMALL_SIZE`, take a small block, or a **large** block when no small one is left (fallback). If `SMALL_SIZE < n <= LARGE_SIZE`, take a large block. When nothing fits, return NULL and count a failure. After every successful allocation, update `min_small` / `min_large`.
- **`pool_free(p)` / `pool_free_from_isr(p)`**: NULL is ignored. Otherwise `p` is a block returned earlier, and its class must be found from its **address**, in O(1).
- All operations are **O(1)** (a free list per class).
- Mutual exclusion: the task functions use `taskENTER_CRITICAL()` / `taskEXIT_CRITICAL()`. The ISR functions use `taskENTER_CRITICAL_FROM_ISR()` / `taskEXIT_CRITICAL_FROM_ISR(saved)`. Mutexes cannot be used from an ISR. `malloc`, `pvPortMalloc`, `vTaskSuspendAll`, `xTaskResumeAll` and semaphore creation are **not allowed** (compile error).

**How it is tested.** Events come from the input:

- `<tick> I <id> <len> <hold>`: a CAN interrupt at `<tick>`. It calls `pool_alloc_from_isr(len)`, fills the block, and posts `{block, id, len, hold}` to the processing queue (length `qlen`) with `xQueueSendFromISR()`. If the queue is full, it gives the block back with `pool_free_from_isr()`. It prints `[t=..] isr id=<id> len=<len> -> <S|L|none>`, plus ` queue full` in that case. `S`/`L` is the class reported by `pool_block_class()`.
- `<tick> T <id> <len> <hold>`: the application task (priority 4) wakes at `<tick>`, calls `pool_alloc(len)`, prints `[t=..] app id=.. len=.. -> <S|L|none>`, and posts the block to the same queue (waiting if it is full).

Interrupts of a tick run first, in input order, then the tasks. The **processing task** (priority 3) receives one message at a time. It prints `[t=..] proc id=<id>`, holds the block for `hold` ticks (`vTaskDelay`), checks its content, calls `pool_free()` and prints `[t=..] free id=<id>`. The harness also checks that no block is handed out twice (`BAD`) and that the content survives until it is freed (`CORRUPT`). After tick `D` it prints the statistics:

`small free=<a>/8 min=<b>, large free=<c>/4 min=<d>, failures=<f>`

**Input**
```
<qlen>
<n>
<tick> <I|T> <id> <len> <hold>      (n lines, non-decreasing ticks)
<D>
```

**Example**
```
Input:
2
6
1 I 1 10 5
1 I 2 40 5
1 I 3 8 5
2 T 4 16 3
3 T 5 65 1
3 T 6 0 1
30

Output:
[t=1] isr id=1 len=10 -> S
[t=1] isr id=2 len=40 -> L
[t=1] isr id=3 len=8 -> S queue full
[t=1] proc id=1
[t=2] app id=4 len=16 -> S
[t=3] app id=5 len=65 -> none
[t=3] app id=6 len=0 -> none
[t=6] free id=1
[t=6] proc id=2
[t=11] free id=2
[t=11] proc id=4
[t=14] free id=4
small free=8/8 min=6, large free=4/4 min=3, failures=2
```
The three interrupts at t=1 run back-to-back before the processing task runs, so the third one finds the 2-slot queue full and returns its block from the ISR. Two small blocks were in use at the same time (min 6). The 65-byte and 0-byte requests fail.
@@@ constraints_md
- 1 <= qlen <= 12, 0 <= n <= 40, 1 <= tick <= 2000, 0 <= len <= 100, 0 <= hold <= 50, D <= 5000.
- Every operation O(1); no heap; ISR functions must not block.
@@@ starter_code
#include <stdint.h>
#include <stddef.h>
#include "FreeRTOS.h"
#include "task.h"

#define SMALL_SIZE 16
#define SMALL_N    8
#define LARGE_SIZE 64
#define LARGE_N    4

typedef struct {
    unsigned free_small, free_large;
    unsigned min_small,  min_large;
    unsigned failures;
} PoolStats;

void pool_init(void)
{
    /* TODO: static storage, two free lists, statistics */
}

void *pool_alloc(size_t n)
{
    (void)n;
    return NULL;
}

void pool_free(void *p)
{
    (void)p;
}

void *pool_alloc_from_isr(size_t n)
{
    (void)n;
    return NULL;
}

void pool_free_from_isr(void *p)
{
    (void)p;
}

int pool_block_class(const void *p)
{
    (void)p;
    return -1;
}

void pool_get_stats(PoolStats *s)
{
    s->free_small = s->free_large = s->min_small = s->min_large = s->failures = 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "sim.h"

#define malloc(...) malloc_is_not_allowed_here
#define pvPortMalloc(...) pvPortMalloc_is_not_allowed_here
#define vTaskSuspendAll(...) vTaskSuspendAll_is_not_allowed_here
#define xTaskResumeAll(...) xTaskResumeAll_is_not_allowed_here
#define xQueueGenericCreate(...) semaphores_are_not_allowed_here
#define xQueueCreateMutex(...) semaphores_are_not_allowed_here
#define xQueueCreateCountingSemaphore(...) semaphores_are_not_allowed_here
#define xQueueGenericCreateStatic(...) semaphores_are_not_allowed_here
#define xQueueCreateMutexStatic(...) semaphores_are_not_allowed_here
#define xQueueCreateCountingSemaphoreStatic(...) semaphores_are_not_allowed_here

/*USER_CODE*/

#undef malloc
#undef pvPortMalloc
#undef vTaskSuspendAll
#undef xTaskResumeAll
#undef xQueueGenericCreate

#define MAX_EV 40

typedef struct {
    uint8_t *p;
    unsigned id, len, hold;
} Msg;

static QueueHandle_t g_q;
static unsigned g_tick[MAX_EV], g_id[MAX_EV], g_len[MAX_EV], g_hold[MAX_EV];
static char g_kind[MAX_EV];
static int g_n;
static uint8_t *g_out[MAX_EV];       /* blocks currently handed out */
static int g_nout;

static const char *cls(const void *p)
{
    int c = pool_block_class(p);
    return c == 0 ? "S" : c == 1 ? "L" : "?";
}

/* Returns 0 if p is new and aligned; prints BAD otherwise. Runs in ISR or task context. */
static int track_alloc(uint8_t *p, unsigned id, TickType_t t)
{
    int i;
    if (((uintptr_t)p % 8u) != 0 || pool_block_class(p) < 0) {
        printf("[t=%u] BAD block for id=%u\n", (unsigned)t, id);
        return -1;
    }
    for (i = 0; i < g_nout; i++) {
        if (g_out[i] == p) {
            printf("[t=%u] BAD block for id=%u is already in use\n", (unsigned)t, id);
            return -1;
        }
    }
    g_out[g_nout++] = p;
    return 0;
}

static void untrack(const uint8_t *p)
{
    int i;
    for (i = 0; i < g_nout; i++) {
        if (g_out[i] == p) {
            g_out[i] = g_out[--g_nout];
            return;
        }
    }
}

static void fill(uint8_t *p, unsigned id, unsigned len)
{
    unsigned i;
    for (i = 0; i < len; i++) p[i] = (uint8_t)(id * 13u + i);
}

static void can_isr(void *arg)
{
    int k = (int)(intptr_t)arg;
    TickType_t t = xTaskGetTickCountFromISR();
    BaseType_t woken = pdFALSE;
    Msg m;

    m.p = (uint8_t *)pool_alloc_from_isr(g_len[k]);
    m.id = g_id[k];
    m.len = g_len[k];
    m.hold = g_hold[k];
    if (m.p == NULL) {
        printf("[t=%u] isr id=%u len=%u -> none\n", (unsigned)t, m.id, m.len);
        return;
    }
    if (track_alloc(m.p, m.id, t) != 0) return;
    fill(m.p, m.id, m.len);
    if (xQueueSendFromISR(g_q, &m, &woken) != pdPASS) {
        printf("[t=%u] isr id=%u len=%u -> %s queue full\n", (unsigned)t, m.id, m.len, cls(m.p));
        untrack(m.p);
        pool_free_from_isr(m.p);
    } else {
        printf("[t=%u] isr id=%u len=%u -> %s\n", (unsigned)t, m.id, m.len, cls(m.p));
    }
    portYIELD_FROM_ISR(woken);
}

static void app_task(void *pv)
{
    int k;
    Msg m;
    (void)pv;

    for (k = 0; k < g_n; k++) {
        TickType_t t;
        if (g_kind[k] != 'T') continue;
        t = xTaskGetTickCount();
        if ((TickType_t)g_tick[k] > t) vTaskDelay((TickType_t)g_tick[k] - t);
        t = xTaskGetTickCount();
        m.p = (uint8_t *)pool_alloc(g_len[k]);
        m.id = g_id[k];
        m.len = g_len[k];
        m.hold = g_hold[k];
        if (m.p == NULL) {
            printf("[t=%u] app id=%u len=%u -> none\n", (unsigned)t, m.id, m.len);
            continue;
        }
        if (track_alloc(m.p, m.id, t) != 0) continue;
        fill(m.p, m.id, m.len);
        printf("[t=%u] app id=%u len=%u -> %s\n", (unsigned)t, m.id, m.len, cls(m.p));
        xQueueSend(g_q, &m, portMAX_DELAY);
    }
    for (;;) vTaskDelay(1000);
}

static void proc_task(void *pv)
{
    Msg m;
    unsigned i;
    (void)pv;

    for (;;) {
        if (xQueueReceive(g_q, &m, portMAX_DELAY) != pdPASS) continue;
        printf("[t=%u] proc id=%u\n", (unsigned)xTaskGetTickCount(), m.id);
        if (m.hold > 0) vTaskDelay((TickType_t)m.hold);
        for (i = 0; i < m.len; i++) {
            if (m.p[i] != (uint8_t)(m.id * 13u + i)) {
                printf("[t=%u] CORRUPT id=%u\n", (unsigned)xTaskGetTickCount(), m.id);
                break;
            }
        }
        untrack(m.p);
        pool_free(m.p);
        printf("[t=%u] free id=%u\n", (unsigned)xTaskGetTickCount(), m.id);
    }
}

int main(void)
{
    unsigned qlen, dur;
    PoolStats s;
    int k;

    if (scanf("%u %d", &qlen, &g_n) != 2 || qlen < 1 || g_n < 0 || g_n > MAX_EV) return 1;
    for (k = 0; k < g_n; k++) {
        if (scanf("%u %c %u %u %u", &g_tick[k], &g_kind[k], &g_id[k], &g_len[k], &g_hold[k]) != 5 ||
            g_len[k] > 100)
            return 1;
    }
    if (scanf("%u", &dur) != 1) return 1;

    pool_init();
    g_q = xQueueCreate(qlen, sizeof(Msg));
    for (k = 0; k < g_n; k++) {
        if (g_kind[k] == 'I') xSimScheduleInterrupt((TickType_t)g_tick[k], can_isr, (void *)(intptr_t)k);
    }
    xTaskCreate(app_task, "app", configMINIMAL_STACK_SIZE, NULL, 4, NULL);
    xTaskCreate(proc_task, "proc", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    pool_get_stats(&s);
    printf("small free=%u/8 min=%u, large free=%u/4 min=%u, failures=%u\n", s.free_small, s.min_small,
           s.free_large, s.min_large, s.failures);
    return 0;
}
@@@ sample_input
2
6
1 I 1 10 5
1 I 2 40 5
1 I 3 8 5
2 T 4 16 3
3 T 5 65 1
3 T 6 0 1
30
@@@ sample_output
[t=1] isr id=1 len=10 -> S
[t=1] isr id=2 len=40 -> L
[t=1] isr id=3 len=8 -> S queue full
[t=1] proc id=1
[t=2] app id=4 len=16 -> S
[t=3] app id=5 len=65 -> none
[t=3] app id=6 len=0 -> none
[t=6] free id=1
[t=6] proc id=2
[t=11] free id=2
[t=11] proc id=4
[t=14] free id=4
small free=8/8 min=6, large free=4/4 min=3, failures=2
@@@ sample_input
4
5
1 T 1 64 10
1 T 2 64 10
1 T 3 64 10
1 T 4 64 10
1 T 5 17 10
100
@@@ sample_output
[t=1] app id=1 len=64 -> L
[t=1] app id=2 len=64 -> L
[t=1] app id=3 len=64 -> L
[t=1] app id=4 len=64 -> L
[t=1] app id=5 len=17 -> none
[t=1] proc id=1
[t=11] free id=1
[t=11] proc id=2
[t=21] free id=2
[t=21] proc id=3
[t=31] free id=3
[t=31] proc id=4
[t=41] free id=4
small free=8/8 min=8, large free=4/4 min=0, failures=1
@@@ hidden_input
1
0
10
@@@ hidden_output
small free=8/8 min=8, large free=4/4 min=4, failures=0
@@@ hidden_input
12
13
1 I 1 4 5
1 I 2 4 5
1 I 3 4 5
1 I 4 4 5
1 I 5 4 5
1 I 6 4 5
1 I 7 4 5
1 I 8 4 5
1 I 9 4 5
1 I 10 4 5
1 I 11 40 5
1 I 12 40 5
1 I 13 40 5
100
@@@ hidden_output
[t=1] isr id=1 len=4 -> S
[t=1] isr id=2 len=4 -> S
[t=1] isr id=3 len=4 -> S
[t=1] isr id=4 len=4 -> S
[t=1] isr id=5 len=4 -> S
[t=1] isr id=6 len=4 -> S
[t=1] isr id=7 len=4 -> S
[t=1] isr id=8 len=4 -> S
[t=1] isr id=9 len=4 -> L
[t=1] isr id=10 len=4 -> L
[t=1] isr id=11 len=40 -> L
[t=1] isr id=12 len=40 -> L
[t=1] isr id=13 len=40 -> none
[t=1] proc id=1
[t=6] free id=1
[t=6] proc id=2
[t=11] free id=2
[t=11] proc id=3
[t=16] free id=3
[t=16] proc id=4
[t=21] free id=4
[t=21] proc id=5
[t=26] free id=5
[t=26] proc id=6
[t=31] free id=6
[t=31] proc id=7
[t=36] free id=7
[t=36] proc id=8
[t=41] free id=8
[t=41] proc id=9
[t=46] free id=9
[t=46] proc id=10
[t=51] free id=10
[t=51] proc id=11
[t=56] free id=11
[t=56] proc id=12
[t=61] free id=12
small free=8/8 min=0, large free=4/4 min=0, failures=1

@@@ hidden_input
1
5
10 I 1 64 20
10 I 2 1 20
11 I 3 100 0
12 I 4 0 0
30 I 5 64 0
60
@@@ hidden_output
[t=10] isr id=1 len=64 -> L
[t=10] isr id=2 len=1 -> S queue full
[t=10] proc id=1
[t=11] isr id=3 len=100 -> none
[t=12] isr id=4 len=0 -> none
[t=30] isr id=5 len=64 -> L
[t=30] free id=1
[t=30] proc id=5
[t=30] free id=5
small free=8/8 min=7, large free=4/4 min=2, failures=2

@@@ hidden_input
3
8
1 T 1 16 5
1 T 2 17 5
2 I 3 15 0
2 I 4 50 0
2 I 5 64 0
3 T 6 8 0
3 T 7 30 0
40 I 8 2 0
100
@@@ hidden_output
[t=1] app id=1 len=16 -> S
[t=1] app id=2 len=17 -> L
[t=1] proc id=1
[t=2] isr id=3 len=15 -> S
[t=2] isr id=4 len=50 -> L
[t=2] isr id=5 len=64 -> L queue full
[t=3] app id=6 len=8 -> S
[t=6] free id=1
[t=6] app id=7 len=30 -> L
[t=6] proc id=2
[t=11] free id=2
[t=11] proc id=3
[t=11] free id=3
[t=11] proc id=4
[t=11] free id=4
[t=11] proc id=6
[t=11] free id=6
[t=11] proc id=7
[t=11] free id=7
[t=40] isr id=8 len=2 -> S
[t=40] proc id=8
[t=40] free id=8
small free=8/8 min=5, large free=4/4 min=1, failures=0

@@@ hidden_input
4
13
1 I 1 16 2
1 I 2 16 2
1 I 3 16 2
1 I 4 16 2
2 I 5 16 2
2 I 6 16 2
2 I 7 16 2
2 I 8 16 2
3 I 9 16 2
3 I 10 16 2
3 I 11 16 2
3 I 12 16 2
4 I 13 16 2
200
@@@ hidden_output
[t=1] isr id=1 len=16 -> S
[t=1] isr id=2 len=16 -> S
[t=1] isr id=3 len=16 -> S
[t=1] isr id=4 len=16 -> S
[t=1] proc id=1
[t=2] isr id=5 len=16 -> S
[t=2] isr id=6 len=16 -> S queue full
[t=2] isr id=7 len=16 -> S queue full
[t=2] isr id=8 len=16 -> S queue full
[t=3] isr id=9 len=16 -> S queue full
[t=3] isr id=10 len=16 -> S queue full
[t=3] isr id=11 len=16 -> S queue full
[t=3] isr id=12 len=16 -> S queue full
[t=3] free id=1
[t=3] proc id=2
[t=4] isr id=13 len=16 -> S
[t=5] free id=2
[t=5] proc id=3
[t=7] free id=3
[t=7] proc id=4
[t=9] free id=4
[t=9] proc id=5
[t=11] free id=5
[t=11] proc id=13
[t=13] free id=13
small free=8/8 min=2, large free=4/4 min=4, failures=0

@@@ hint
Use two static arrays (`uint64_t` elements keep every block 8-byte aligned) and one singly linked free list per class, threaded through the free blocks. The class of `p` is a range check: `p >= small_base && p < small_base + SMALL_N * SMALL_SIZE`. Put the real work in two lock-free helpers (`alloc_locked`, `free_locked`) and wrap them in the right critical section for each context.
@@@ hint
Task side: `taskENTER_CRITICAL(); r = alloc_locked(n); taskEXIT_CRITICAL();`. ISR side: `UBaseType_t s = taskENTER_CRITICAL_FROM_ISR(); r = alloc_locked(n); taskEXIT_CRITICAL_FROM_ISR(s);`. In `alloc_locked`, after a pop, `if (free_small < min_small) min_small = free_small;` (same for large). The small-to-large fallback is just "try the small list, then the large list".
@@@ solution_code
#include <stdint.h>
#include <stddef.h>
#include "FreeRTOS.h"
#include "task.h"

#define SMALL_SIZE 16
#define SMALL_N    8
#define LARGE_SIZE 64
#define LARGE_N    4

typedef struct {
    unsigned free_small, free_large;
    unsigned min_small,  min_large;
    unsigned failures;
} PoolStats;

typedef struct Node { struct Node *next; } Node;

/* uint64_t storage: every block is 8-byte aligned */
static uint64_t  s_small[SMALL_N][SMALL_SIZE / 8];
static uint64_t  s_large[LARGE_N][LARGE_SIZE / 8];
static Node     *s_free_small, *s_free_large;
static PoolStats s_st;

static Node *push_all(void *base, size_t size, int n)
{
    Node *head = NULL;
    int i;
    for (i = n - 1; i >= 0; i--) {
        Node *b = (Node *)(void *)((uint8_t *)base + (size_t)i * size);
        b->next = head;
        head = b;
    }
    return head;
}

void pool_init(void)
{
    s_free_small = push_all(s_small, SMALL_SIZE, SMALL_N);
    s_free_large = push_all(s_large, LARGE_SIZE, LARGE_N);
    s_st.free_small = s_st.min_small = SMALL_N;
    s_st.free_large = s_st.min_large = LARGE_N;
    s_st.failures = 0;
}

int pool_block_class(const void *p)
{
    const uint8_t *q = (const uint8_t *)p;
    const uint8_t *sb = (const uint8_t *)s_small, *lb = (const uint8_t *)s_large;

    if (q >= sb && q < sb + sizeof s_small) return 0;
    if (q >= lb && q < lb + sizeof s_large) return 1;
    return -1;
}

/* Callers hold the appropriate critical section. */
static void *alloc_locked(size_t n)
{
    Node *b = NULL;

    if (n > 0 && n <= SMALL_SIZE && s_free_small != NULL) {
        b = s_free_small;
        s_free_small = b->next;
        if (--s_st.free_small < s_st.min_small) s_st.min_small = s_st.free_small;
    } else if (n > 0 && n <= LARGE_SIZE && s_free_large != NULL) {   /* also the small fallback */
        b = s_free_large;
        s_free_large = b->next;
        if (--s_st.free_large < s_st.min_large) s_st.min_large = s_st.free_large;
    } else {
        s_st.failures++;
    }
    return b;
}

static void free_locked(void *p)
{
    Node *b = (Node *)p;
    int c = pool_block_class(p);

    if (c == 0) {
        b->next = s_free_small;
        s_free_small = b;
        s_st.free_small++;
    } else if (c == 1) {
        b->next = s_free_large;
        s_free_large = b;
        s_st.free_large++;
    }
}

void *pool_alloc(size_t n)
{
    void *p;
    taskENTER_CRITICAL();
    p = alloc_locked(n);
    taskEXIT_CRITICAL();
    return p;
}

void pool_free(void *p)
{
    if (p == NULL) return;
    taskENTER_CRITICAL();
    free_locked(p);
    taskEXIT_CRITICAL();
}

void *pool_alloc_from_isr(size_t n)
{
    void *p;
    UBaseType_t saved = taskENTER_CRITICAL_FROM_ISR();
    p = alloc_locked(n);
    taskEXIT_CRITICAL_FROM_ISR(saved);
    return p;
}

void pool_free_from_isr(void *p)
{
    UBaseType_t saved;
    if (p == NULL) return;
    saved = taskENTER_CRITICAL_FROM_ISR();
    free_locked(p);
    taskEXIT_CRITICAL_FROM_ISR(saved);
}

void pool_get_stats(PoolStats *s)
{
    taskENTER_CRITICAL();
    *s = s_st;                       /* consistent snapshot */
    taskEXIT_CRITICAL();
}
@@@ explanation_md
**Approach.** The pool is shared between interrupt and task context, so neither side may block, and a mutex is out: it cannot be taken from an ISR, and an ISR must never wait for a task. Every pool operation is a handful of pointer moves, so a **critical section** around it is short and bounded:

- task side: `taskENTER_CRITICAL()` / `taskEXIT_CRITICAL()` (masks interrupts up to `configMAX_SYSCALL_INTERRUPT_PRIORITY` and nests);
- ISR side: `taskENTER_CRITICAL_FROM_ISR()` returns the previous mask, and `taskEXIT_CRITICAL_FROM_ISR(saved)` restores exactly that. This matters for nested interrupts.

Both wrappers call the same lock-free helpers, so the logic exists once. Each class keeps an intrusive LIFO free list, and the class of a pointer comes from an address range check. That makes allocation, freeing and classification O(1), with no per-block header. The statistics are updated inside the same critical section: `min_*` is the high-water mark of use that you report to size the pool from field data, and `failures` shows that it was too small.

The small → large fallback trades RAM for availability: a burst of short frames can borrow large blocks instead of being dropped. The `min_large` value shows when that happened.

**Complexity.** O(1) per operation, with interrupts masked for a few instructions (bounded interrupt latency). RAM: `8*16 + 4*64 = 384` bytes of storage + two list heads + 20 bytes of statistics.

**Common mistakes**
- Using a mutex or `vTaskSuspendAll()` to protect the pool: neither works against an ISR (and `xSemaphoreTake` from an ISR is a Runtime Error here).
- Using `taskENTER_CRITICAL()` inside the ISR, or forgetting to restore the saved mask with the `_FROM_ISR` exit: on a Cortex-M port, that re-enables interrupts too early inside nested ISRs.
- Determining the class from the requested size at free time (the caller does not pass it, and a fallback block is large even though the request was small).
- Updating `min_*` outside the critical section, or only in the task path.
- Storage declared as `uint8_t[]`: blocks may not be aligned for the `next` pointer or for the user's data.

**Interview follow-ups**
- On a Cortex-M with `configMAX_SYSCALL_INTERRUPT_PRIORITY`, which interrupts can still preempt this critical section, and why must they never call the pool?
- Could you make it lock-free with LDREX/STREX (a Treiber stack)? What is the ABA problem?
- How would you add guard words / a magic number per block to catch double frees and overruns from DMA?
- How would you size `SMALL_N` / `LARGE_N` from the `min_*` statistics collected in a test drive?
