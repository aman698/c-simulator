@@@ meta
id: RMM-H-01
topic: RTOS Memory Management
difficulty: Hard
type: FUNCTION
title: Reference-Counted Zero-Copy Frame Buffers Shared By Several Tasks
tags: freertos, zero-copy, reference-counting, memory-pool, critical-section, queues, embedded, asked-in-automotive
@@@ statement_md
A camera/radar gateway receives frames and hands each one to up to three consumers: a logger, a CAN-FD forwarder and a diagnostic recorder. Copying every frame three times costs too much CPU and RAM. Instead, the frame is copied **once** into a buffer from a small static pool, and only the **pointer** is passed to each consumer's queue (*zero-copy*). The buffer must go back to the pool exactly when the **last** consumer has finished with it. Implement this with a **reference count**.

```c
#define NBUF        4
#define BUF_DATA    32
#define N_CONSUMERS 3

typedef struct FrameBuf {
    uint8_t          data[BUF_DATA];
    uint16_t         len;
    uint16_t         seq;
    uint32_t         refs;       /* reference count: yours to manage */
    struct FrameBuf *next;       /* free for your use (e.g. free-list link) */
} FrameBuf;

extern QueueHandle_t g_cons_q[N_CONSUMERS];   /* created by the harness, items are FrameBuf * */

/* you write these */
void     bufpool_init(void);
int      publish_frame(uint16_t seq, const uint8_t *data, uint16_t len, unsigned mask);
void     buf_release(FrameBuf *b);
unsigned buf_free_count(void);
```

- **`bufpool_init()`**: all `NBUF` buffers of your **static** pool are free. It is called before the scheduler starts.
- **`publish_frame(seq, data, len, mask)`** (task context, `len <= BUF_DATA`):
  1. Take a free buffer. If there is none, return **-1** (the frame is lost).
  2. Copy `data`, set `len` and `seq`. The publisher now holds **one** reference.
  3. For every consumer `k` (0, 1, 2 in this order) whose bit `1u << k` is set in `mask`: add a reference for that consumer, then `xQueueSend(g_cons_q[k], &b, 0)`. If the queue is full, take that reference back.
  4. Drop the publisher's own reference.

  Return the number of consumers the buffer was delivered to (0..3). With `mask == 0`, or when every queue is full, the buffer goes straight back to the pool.
- **`buf_release(b)`**: called by a consumer when it is done. It drops one reference. When the count reaches 0, the buffer goes back to the pool.
- **`buf_free_count()`**: number of free buffers.

The consumers run at different priorities and can be preempted at any point, so every read-modify-write of `refs` and of the free list must be **atomic**: use `taskENTER_CRITICAL()` / `taskEXIT_CRITICAL()`. `malloc` and `pvPortMalloc` are not allowed.

**How it is tested.** A producer task (**priority 5**) calls `publish_frame()` at the input ticks, with `data[i] = seq * 7 + i`, and prints `[t=..] pub seq=<s> -> <ret> (free=<n>)`. Consumer `Ck` (priorities 4, 3, 2 for k = 0, 1, 2; queues of length `qlen`) loops forever:

1. receive a pointer (wait forever) and print `[t=..] Ck got seq=<s>`;
2. hold the buffer with `vTaskDelay(hold_k)` (if `hold_k > 0`);
3. `buf_release()`, then print `[t=..] Ck rel seq=<s> free=<n>`.

The harness checks the buffer contents when it receives the buffer **and** just before it releases it. A buffer recycled too early prints `CORRUPT`. Every consumer of one frame must receive the **same** pointer, otherwise `COPY` is printed. The run lasts up to and including tick `D`, then the harness prints `end: free=<n>/4`.

**Input**
```
<hold_0> <hold_1> <hold_2> <qlen>
<n>
<tick> <seq> <len> <mask>       (n lines, increasing ticks)
<D>
```

**Example**
```
Input:
0 5 10 2
3
1 1 4 7
2 2 8 2
3 3 0 0
30

Output:
[t=1] pub seq=1 -> 3 (free=3)
[t=1] C0 got seq=1
[t=1] C0 rel seq=1 free=3
[t=1] C1 got seq=1
[t=1] C2 got seq=1
[t=2] pub seq=2 -> 1 (free=2)
[t=3] pub seq=3 -> 0 (free=2)
[t=6] C1 rel seq=1 free=2
[t=6] C1 got seq=2
[t=11] C1 rel seq=2 free=3
[t=11] C2 rel seq=1 free=4
end: free=4/4
```
Frame 1 is shared by three consumers. Its buffer comes back only at t=11, when C2 (the last holder) releases it. Frame 3 has no consumer, so its buffer is returned inside `publish_frame()`. At t=11, C1 and C2 wake together, and C1 (priority 3) runs first.
@@@ constraints_md
- 0 <= hold_k <= 50, 1 <= qlen <= 4, 0 <= n <= 30, 1 <= tick <= 2000 (increasing), 1 <= seq <= 60 (distinct), 0 <= len <= 32, 0 <= mask <= 7, D <= 5000.
- O(1) buffer get/return; no heap.
@@@ starter_code
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

#define NBUF        4
#define BUF_DATA    32
#define N_CONSUMERS 3

typedef struct FrameBuf {
    uint8_t          data[BUF_DATA];
    uint16_t         len;
    uint16_t         seq;
    uint32_t         refs;
    struct FrameBuf *next;
} FrameBuf;

extern QueueHandle_t g_cons_q[N_CONSUMERS];

void bufpool_init(void)
{
    /* TODO */
}

int publish_frame(uint16_t seq, const uint8_t *data, uint16_t len, unsigned mask)
{
    /* TODO: get a buffer, copy once, one reference per delivered consumer */
    (void)seq; (void)data; (void)len; (void)mask;
    return -1;
}

void buf_release(FrameBuf *b)
{
    /* TODO */
    (void)b;
}

unsigned buf_free_count(void)
{
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

QueueHandle_t g_cons_q[3];

#define malloc(...) malloc_is_not_allowed_here
#define pvPortMalloc(...) pvPortMalloc_is_not_allowed_here

/*USER_CODE*/

#undef malloc
#undef pvPortMalloc

#define MAX_EV 30

static unsigned g_hold[3];
static unsigned g_tick[MAX_EV], g_seq[MAX_EV], g_len[MAX_EV], g_mask[MAX_EV];
static int g_n;
static const FrameBuf *g_ptr_of_seq[64];
static int g_cons_id[3] = { 0, 1, 2 };

static unsigned now(void) { return (unsigned)xTaskGetTickCount(); }

static int content_ok(const FrameBuf *b, unsigned seq, unsigned len)
{
    unsigned i;
    if (b->seq != seq || b->len != len) return 0;
    for (i = 0; i < len; i++) {
        if (b->data[i] != (uint8_t)(seq * 7u + i)) return 0;
    }
    return 1;
}

static unsigned len_of_seq(unsigned seq)
{
    int i;
    for (i = 0; i < g_n; i++) {
        if (g_seq[i] == seq) return g_len[i];
    }
    return 0;
}

static void producer_task(void *pv)
{
    uint8_t buf[BUF_DATA];
    unsigned i, k;
    int r;
    (void)pv;

    for (i = 0; i < (unsigned)g_n; i++) {
        TickType_t t = xTaskGetTickCount();
        if ((TickType_t)g_tick[i] > t) vTaskDelay((TickType_t)g_tick[i] - t);
        for (k = 0; k < g_len[i]; k++) buf[k] = (uint8_t)(g_seq[i] * 7u + k);
        r = publish_frame((uint16_t)g_seq[i], buf, (uint16_t)g_len[i], g_mask[i]);
        memset(buf, 0xEE, sizeof buf);          /* the caller's copy is gone: zero-copy must not use it */
        printf("[t=%u] pub seq=%u -> %d (free=%u)\n", now(), g_seq[i], r, buf_free_count());
    }
    for (;;) vTaskDelay(1000);
}

static void consumer_task(void *pv)
{
    int k = *(const int *)pv;
    FrameBuf *b;
    unsigned seq, len;

    for (;;) {
        if (xQueueReceive(g_cons_q[k], &b, portMAX_DELAY) != pdPASS) continue;
        seq = b->seq;
        len = len_of_seq(seq);
        printf("[t=%u] C%d got seq=%u\n", now(), k, seq);
        if (seq < 64) {
            if (g_ptr_of_seq[seq] == NULL) g_ptr_of_seq[seq] = b;
            else if (g_ptr_of_seq[seq] != b) printf("[t=%u] C%d COPY of seq=%u\n", now(), k, seq);
        }
        if (!content_ok(b, seq, len)) printf("[t=%u] C%d CORRUPT seq=%u\n", now(), k, seq);
        if (g_hold[k] > 0) vTaskDelay((TickType_t)g_hold[k]);
        if (!content_ok(b, seq, len)) printf("[t=%u] C%d CORRUPT seq=%u\n", now(), k, seq);
        buf_release(b);
        printf("[t=%u] C%d rel seq=%u free=%u\n", now(), k, seq, buf_free_count());
    }
}

int main(void)
{
    unsigned qlen, dur;
    int i;

    if (scanf("%u %u %u %u %d", &g_hold[0], &g_hold[1], &g_hold[2], &qlen, &g_n) != 5 ||
        g_n < 0 || g_n > MAX_EV || qlen < 1)
        return 1;
    for (i = 0; i < g_n; i++) {
        if (scanf("%u %u %u %u", &g_tick[i], &g_seq[i], &g_len[i], &g_mask[i]) != 4 ||
            g_len[i] > BUF_DATA || g_seq[i] >= 64)
            return 1;
    }
    if (scanf("%u", &dur) != 1) return 1;

    for (i = 0; i < 3; i++) g_cons_q[i] = xQueueCreate(qlen, sizeof(FrameBuf *));
    bufpool_init();
    xTaskCreate(producer_task, "prod", configMINIMAL_STACK_SIZE, NULL, 5, NULL);
    for (i = 0; i < 3; i++) {
        xTaskCreate(consumer_task, "cons", configMINIMAL_STACK_SIZE, &g_cons_id[i], (UBaseType_t)(4 - i), NULL);
    }
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();
    printf("end: free=%u/4\n", buf_free_count());
    return 0;
}
@@@ sample_input
0 5 10 2
3
1 1 4 7
2 2 8 2
3 3 0 0
30
@@@ sample_output
[t=1] pub seq=1 -> 3 (free=3)
[t=1] C0 got seq=1
[t=1] C0 rel seq=1 free=3
[t=1] C1 got seq=1
[t=1] C2 got seq=1
[t=2] pub seq=2 -> 1 (free=2)
[t=3] pub seq=3 -> 0 (free=2)
[t=6] C1 rel seq=1 free=2
[t=6] C1 got seq=2
[t=11] C1 rel seq=2 free=3
[t=11] C2 rel seq=1 free=4
end: free=4/4
@@@ sample_input
20 20 20 1
6
1 1 32 1
2 2 32 1
3 3 32 1
4 4 32 1
5 5 32 1
6 6 32 6
50
@@@ sample_output
[t=1] pub seq=1 -> 1 (free=3)
[t=1] C0 got seq=1
[t=2] pub seq=2 -> 1 (free=2)
[t=3] pub seq=3 -> 0 (free=2)
[t=4] pub seq=4 -> 0 (free=2)
[t=5] pub seq=5 -> 0 (free=2)
[t=6] pub seq=6 -> 2 (free=1)
[t=6] C1 got seq=6
[t=6] C2 got seq=6
[t=21] C0 rel seq=1 free=2
[t=21] C0 got seq=2
[t=26] C1 rel seq=6 free=2
[t=26] C2 rel seq=6 free=3
[t=41] C0 rel seq=2 free=4
end: free=4/4
@@@ hidden_input
0 0 0 1
0
10
@@@ hidden_output
end: free=4/4
@@@ hidden_input
30 30 30 4
6
1 1 1 7
2 2 2 7
3 3 3 7
4 4 4 7
5 5 5 7
40 6 6 3
100
@@@ hidden_output
[t=1] pub seq=1 -> 3 (free=3)
[t=1] C0 got seq=1
[t=1] C1 got seq=1
[t=1] C2 got seq=1
[t=2] pub seq=2 -> 3 (free=2)
[t=3] pub seq=3 -> 3 (free=1)
[t=4] pub seq=4 -> 3 (free=0)
[t=5] pub seq=5 -> -1 (free=0)
[t=31] C0 rel seq=1 free=0
[t=31] C0 got seq=2
[t=31] C1 rel seq=1 free=0
[t=31] C1 got seq=2
[t=31] C2 rel seq=1 free=1
[t=31] C2 got seq=2
[t=40] pub seq=6 -> 2 (free=0)
[t=61] C0 rel seq=2 free=0
[t=61] C0 got seq=3
[t=61] C1 rel seq=2 free=0
[t=61] C1 got seq=3
[t=61] C2 rel seq=2 free=1
[t=61] C2 got seq=3
[t=91] C0 rel seq=3 free=1
[t=91] C0 got seq=4
[t=91] C1 rel seq=3 free=1
[t=91] C1 got seq=4
[t=91] C2 rel seq=3 free=2
[t=91] C2 got seq=4
end: free=2/4

@@@ hidden_input
0 0 0 2
4
10 10 0 7
11 11 32 5
12 12 16 0
13 13 1 2
20
@@@ hidden_output
[t=10] pub seq=10 -> 3 (free=3)
[t=10] C0 got seq=10
[t=10] C0 rel seq=10 free=3
[t=10] C1 got seq=10
[t=10] C1 rel seq=10 free=3
[t=10] C2 got seq=10
[t=10] C2 rel seq=10 free=4
[t=11] pub seq=11 -> 2 (free=3)
[t=11] C0 got seq=11
[t=11] C0 rel seq=11 free=3
[t=11] C2 got seq=11
[t=11] C2 rel seq=11 free=4
[t=12] pub seq=12 -> 0 (free=4)
[t=13] pub seq=13 -> 1 (free=3)
[t=13] C1 got seq=13
[t=13] C1 rel seq=13 free=4
end: free=4/4

@@@ hidden_input
5 3 1 1
4
1 21 10 7
2 22 10 7
3 23 10 7
4 24 10 7
30
@@@ hidden_output
[t=1] pub seq=21 -> 3 (free=3)
[t=1] C0 got seq=21
[t=1] C1 got seq=21
[t=1] C2 got seq=21
[t=2] pub seq=22 -> 3 (free=2)
[t=2] C2 rel seq=21 free=2
[t=2] C2 got seq=22
[t=3] pub seq=23 -> 1 (free=1)
[t=3] C2 rel seq=22 free=1
[t=3] C2 got seq=23
[t=4] pub seq=24 -> 1 (free=0)
[t=4] C1 rel seq=21 free=0
[t=4] C1 got seq=22
[t=4] C2 rel seq=23 free=1
[t=4] C2 got seq=24
[t=5] C2 rel seq=24 free=2
[t=6] C0 rel seq=21 free=3
[t=6] C0 got seq=22
[t=7] C1 rel seq=22 free=3
[t=11] C0 rel seq=22 free=4
end: free=4/4

@@@ hidden_input
50 0 10 3
5
1 31 8 1
2 32 8 1
3 33 8 1
4 34 8 6
5 35 8 1
200
@@@ hidden_output
[t=1] pub seq=31 -> 1 (free=3)
[t=1] C0 got seq=31
[t=2] pub seq=32 -> 1 (free=2)
[t=3] pub seq=33 -> 1 (free=1)
[t=4] pub seq=34 -> 2 (free=0)
[t=4] C1 got seq=34
[t=4] C1 rel seq=34 free=0
[t=4] C2 got seq=34
[t=5] pub seq=35 -> -1 (free=0)
[t=14] C2 rel seq=34 free=1
[t=51] C0 rel seq=31 free=2
[t=51] C0 got seq=32
[t=101] C0 rel seq=32 free=3
[t=101] C0 got seq=33
[t=151] C0 rel seq=33 free=4
end: free=4/4

@@@ hint
Keep a static array `FrameBuf s_pool[NBUF]` and a free list through `next`: getting and returning a buffer are O(1). In `publish_frame()`, set `refs = 1` for the publisher itself **before** sending to anybody. A fast, higher-priority consumer could otherwise release the buffer to 0 while you are still delivering it to the next consumer.
@@@ hint
`buf_release()`: `taskENTER_CRITICAL(); last = (--b->refs == 0); if (last) { b->next = s_free; s_free = b; s_nfree++; } taskEXIT_CRITICAL();`. In `publish_frame()`, increment `refs` before `xQueueSend()` (the receiver may run immediately) and call `buf_release()` when the send fails. End with `buf_release(b)` for the publisher's own reference.
@@@ solution_code
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

#define NBUF        4
#define BUF_DATA    32
#define N_CONSUMERS 3

typedef struct FrameBuf {
    uint8_t          data[BUF_DATA];
    uint16_t         len;
    uint16_t         seq;
    uint32_t         refs;
    struct FrameBuf *next;
} FrameBuf;

extern QueueHandle_t g_cons_q[N_CONSUMERS];

static FrameBuf  s_pool[NBUF];
static FrameBuf *s_free;            /* free list through ->next */
static unsigned  s_nfree;

void bufpool_init(void)
{
    int i;

    s_free = NULL;
    for (i = NBUF - 1; i >= 0; i--) {
        s_pool[i].refs = 0;
        s_pool[i].next = s_free;
        s_free = &s_pool[i];
    }
    s_nfree = NBUF;
}

static FrameBuf *buf_get(void)
{
    FrameBuf *b;

    taskENTER_CRITICAL();
    b = s_free;
    if (b != NULL) {
        s_free = b->next;
        s_nfree--;
        b->refs = 1;                /* the publisher's own reference */
    }
    taskEXIT_CRITICAL();
    return b;
}

static void buf_retain(FrameBuf *b)
{
    taskENTER_CRITICAL();
    b->refs++;
    taskEXIT_CRITICAL();
}

void buf_release(FrameBuf *b)
{
    taskENTER_CRITICAL();
    if (--b->refs == 0) {           /* last holder: back to the pool */
        b->next = s_free;
        s_free = b;
        s_nfree++;
    }
    taskEXIT_CRITICAL();
}

int publish_frame(uint16_t seq, const uint8_t *data, uint16_t len, unsigned mask)
{
    FrameBuf *b = buf_get();
    int k, delivered = 0;

    if (b == NULL) {
        return -1;                  /* pool exhausted: drop the frame */
    }
    memcpy(b->data, data, len);     /* the one and only copy */
    b->len = len;
    b->seq = seq;
    for (k = 0; k < N_CONSUMERS; k++) {
        if (mask & (1u << k)) {
            buf_retain(b);          /* before the send: the consumer may run at once */
            if (xQueueSend(g_cons_q[k], &b, 0) == pdPASS) {
                delivered++;
            } else {
                buf_release(b);     /* not delivered: undo that reference */
            }
        }
    }
    buf_release(b);                 /* drop the publisher's reference */
    return delivered;
}

unsigned buf_free_count(void)
{
    unsigned n;

    taskENTER_CRITICAL();
    n = s_nfree;
    taskEXIT_CRITICAL();
    return n;
}
@@@ explanation_md
**Approach.** The buffer is the unit of ownership, and `refs` counts its current owners:

1. `buf_get()` pops a buffer from the static free list and sets `refs = 1`. That reference belongs to the **publisher**. Without it, a consumer with a higher priority than the publisher could receive the pointer, release it, and drive the count to 0 while the publisher is still sending it to the next consumer. The buffer would be recycled during delivery.
2. For each consumer: `refs++` **before** `xQueueSend()`, because the receiver may run inside the send. If the queue is full, the extra reference is dropped again.
3. The publisher drops its own reference at the end. If nobody took the frame (mask 0, all queues full), that release returns the buffer to the pool at once.
4. Each consumer calls `buf_release()` when done. Whoever brings the count to 0 pushes the buffer back on the free list.

All updates of `refs`, `s_free` and `s_nfree` happen inside `taskENTER_CRITICAL()`, because consumers of different priorities release the same buffer. A plain `--b->refs` is a load-modify-store, and two tasks interleaving it can lose a decrement (leak) or free twice (corruption). A critical section is shorter than a mutex here (a few instructions), and it would also work from an ISR using the `_FROM_ISR` variants.

In sample 2, C0's queue holds one pointer. Frame 2 waits in it while C0 holds frame 1, so frames 3..5 find the queue full: each one takes a buffer, fails to deliver it, and returns it inside `publish_frame()` (`-> 0`, `free` unchanged). Frame 6 goes to C1 and C2 and comes back only at t=26, when C2 drops the last reference (C1's release at t=26 leaves `free` at 2). Every buffer is back by t=41.

**Complexity.** Get, retain, release: O(1) with interrupts briefly masked. Publishing to `c` consumers: O(len + c). RAM: `NBUF * sizeof(FrameBuf)` plus one pointer per queue slot, instead of one full frame copy per queue slot.

**Common mistakes**
- Starting with `refs = 0` and incrementing per send: the first consumer may release before the second send, and the buffer is recycled mid-publish.
- Incrementing **after** `xQueueSend()`: the consumer can run inside the send, release, and hit 0.
- Not undoing the reference when a send fails: the buffer leaks, and the pool runs dry after a few full-queue events.
- Non-atomic `refs--` and free-list updates.
- Copying the frame into every queue (`xQueueSend` of the struct): correct but defeats the purpose, and the harness reports `COPY`.

**Interview follow-ups**
- How would you let an ISR publish frames (FromISR queue sends, `taskENTER_CRITICAL_FROM_ISR`)?
- How does this compare with C11 `atomic_fetch_sub` / LDREX-STREX on a Cortex-M? When is a critical section still required?
- What happens if a consumer crashes or is deleted while holding a reference? How do you detect stuck buffers (timestamps, an owner mask)?
- How would you extend this to buffers of several sizes, or to DMA directly into pool buffers?
