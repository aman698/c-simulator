@@@ meta
id: RQU-H-02
topic: Queues
difficulty: Hard
type: FUNCTION
title: Zero-Copy Frame Buffer Pool With a Free-List Queue and a Ready Queue
tags: freertos, queue, zero-copy, buffer-pool, isr, ownership, embedded, asked-in-automotive
@@@ statement_md
An Ethernet/CAN-FD receive path cannot afford to copy every 64-byte frame through a queue twice. Instead it uses a **pool of frame buffers** and passes **pointers**:

- `free_q` holds pointers to buffers that nobody uses;
- `ready_q` holds pointers to buffers that contain a received frame waiting to be processed.

The receive interrupt takes a free buffer, fills it, and queues the pointer on `ready_q`. The consumer task processes the frame **in place** and then gives the buffer back to `free_q`. Each buffer is owned by exactly one party at any time. Implement the pool.

```c
#define POOL_MAX  8
#define FRAME_CAP 64

typedef struct {
    uint16_t len;
    uint16_t seq;
    uint8_t  data[FRAME_CAP];
} Frame;

extern Frame g_frames[POOL_MAX];   /* provided: the buffer memory (use the first n) */

typedef struct {
    QueueHandle_t free_q;    /* n x (Frame *) */
    QueueHandle_t ready_q;   /* n x (Frame *) */
} PoolHandles;

void process_frame(const Frame *f);  /* provided, task only: prints "[t=..] proc #<seq> buf<i> len=<len>",
                                        then works for `cost` ticks on the buffer */
void on_drop(uint16_t seq);          /* provided, ISR-safe: prints "[t=..] DROP #<seq>" */

void pool_init(PoolHandles *h, unsigned n);                          /* you write this */
void rx_isr(const uint8_t *bytes, uint16_t len, uint16_t seq);       /* you write this: INTERRUPT CONTEXT */
```

Requirements:

- `pool_init()` creates both queues with `n` items of size `sizeof(Frame *)`, puts `&g_frames[0] .. &g_frames[n-1]` **in this order** into `free_q`, and creates the **consumer** task with priority **3**.
- `rx_isr()` takes a buffer from `free_q` with `xQueueReceiveFromISR()`. If there is none, it calls `on_drop(seq)`: the frame is lost and **no buffer may be allocated**. Otherwise it copies `len` bytes from `bytes` into the buffer (the hardware FIFO behind `bytes` is reused after the interrupt), sets `len` and `seq`, and posts the **pointer** to `ready_q`. It ends with `portYIELD_FROM_ISR()`.
- The consumer does forever: receive a `Frame *` from `ready_q` (block), `process_frame(f)`, then return `f` to the **back** of `free_q`. Never give a buffer back before processing has finished.

`malloc`, `free` and `pvPortMalloc` are disabled in this exercise.

**How it is tested.** The hidden `main()` reads the pool size `n`, the processing cost, the duration `D` and a list of `(tick, len)` frames. Frame `k` (1-based) gets `seq = k` and deterministic contents. It calls `pool_init()` and checks the queue geometry, then schedules one interrupt per frame and runs the scheduler up to and including tick `D`. `process_frame()` prints `ERROR` for a pointer outside the pool. It prints `CORRUPT` if the contents are wrong when processing starts **or ends**, which catches buffers that were reused while still in use. At the end the harness prints the counters and how many buffers are in each queue: free + ready must equal `n` again.

**Timing rules**
- All interrupts of one tick run back to back, in input order, before the consumer runs.
- An interrupt at tick `t` also runs **before** the consumer finishes a frame whose processing ends at tick `t`. That buffer is not free yet.
- Buffer indices in the output follow from the FIFO order of `free_q`.

**Input**
```
<n> <cost> <D>
<m>
<tick> <len>      (m lines, sorted by tick)
```

**Example**
```
Input:
2 3 20
4
1 4
2 2
3 5
5 1

Output:
[t=1] proc #1 buf0 len=4
[t=3] DROP #3
[t=4] proc #2 buf1 len=2
[t=7] proc #4 buf0 len=1
processed 3, dropped 1, free 2/2, ready 0
```
Frame 1 takes buffer 0 and is processed from t=1 to t=4. Frame 2 takes buffer 1. At t=3 both buffers are in use, so frame 3 is dropped. At t=4 buffer 0 returns to the back of `free_q`, and frame 2 is processed. Frame 4 (t=5) takes buffer 0 again.
@@@ constraints_md
- 1 <= n <= 8, 1 <= cost <= 50, 0 <= m <= 200, 1 <= tick <= D <= 20000, 1 <= len <= 64.
- `free_q` and `ready_q`: length `n`, item size `sizeof(Frame *)`. Consumer priority 3, stack `configMINIMAL_STACK_SIZE`.
- No heap allocation per frame; `rx_isr()` must only use `...FromISR()` APIs. The tests end with the consumer idle.
@@@ starter_code
#include <stdint.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

#define POOL_MAX  8
#define FRAME_CAP 64

typedef struct {
    uint16_t len;
    uint16_t seq;
    uint8_t  data[FRAME_CAP];
} Frame;

extern Frame g_frames[POOL_MAX];

typedef struct {
    QueueHandle_t free_q;
    QueueHandle_t ready_q;
} PoolHandles;

void process_frame(const Frame *f);
void on_drop(uint16_t seq);

static void consumer_task(void *pvParameters)
{
    /* TODO: receive Frame* from ready_q, process_frame(f), give f back to free_q */
    (void)pvParameters;
    for (;;) {
        vTaskDelay(1000);
    }
}

void pool_init(PoolHandles *h, unsigned n)
{
    /* TODO: create free_q / ready_q (n x Frame*), fill free_q with &g_frames[0..n-1], create the consumer */
    (void)n;
    h->free_q = NULL;
    h->ready_q = NULL;
    (void)consumer_task;
}

void rx_isr(const uint8_t *bytes, uint16_t len, uint16_t seq)
{
    /* TODO: take a free buffer (or on_drop), fill it, post the pointer, portYIELD_FROM_ISR */
    (void)bytes;
    (void)len;
    on_drop(seq);
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

#define malloc(x) malloc_is_not_allowed_here
#define free(x) free_is_not_allowed_here
#define pvPortMalloc(x) pvPortMalloc_is_not_allowed_here
/*USER_CODE*/
#undef malloc
#undef free
#undef pvPortMalloc

Frame g_frames[POOL_MAX];

static unsigned g_n, g_cost, g_processed, g_dropped;
static uint16_t g_len[201];

static uint8_t gen_byte(unsigned seq, unsigned i)
{
    return (uint8_t)((seq * 31u + i * 7u + 1u) & 0xFFu);
}

static int frame_ok(const Frame *f)
{
    unsigned i;
    if (f->seq < 1 || f->seq > 200 || f->len != g_len[f->seq]) return 0;
    for (i = 0; i < f->len; i++)
        if (f->data[i] != gen_byte(f->seq, i)) return 0;
    return 1;
}

void process_frame(const Frame *f)
{
    unsigned t = (unsigned)xTaskGetTickCount();
    uint16_t seq;

    if (f < &g_frames[0] || f >= &g_frames[g_n]) {
        printf("[t=%u] ERROR: not a pool buffer\n", t);
        return;
    }
    seq = f->seq;
    printf("[t=%u] proc #%u buf%u len=%u\n", t, (unsigned)seq, (unsigned)(f - g_frames), (unsigned)f->len);
    if (!frame_ok(f)) printf("CORRUPT: frame #%u is wrong when processing starts\n", (unsigned)seq);
    g_processed++;
    vSimBusyWork((TickType_t)g_cost);
    if (f->seq != seq || !frame_ok(f))
        printf("[t=%u] CORRUPT: buffer of frame #%u was reused during processing\n",
               (unsigned)xTaskGetTickCount(), (unsigned)seq);
}

void on_drop(uint16_t seq)
{
    printf("[t=%u] DROP #%u\n", (unsigned)xTaskGetTickCountFromISR(), (unsigned)seq);
    g_dropped++;
}

static uint8_t g_hw_fifo[FRAME_CAP];   /* the "peripheral" buffer, reused by every frame */

static void frame_irq(void *arg)
{
    unsigned seq = (unsigned)(uintptr_t)arg, i;
    for (i = 0; i < g_len[seq]; i++) g_hw_fifo[i] = gen_byte(seq, i);
    rx_isr(g_hw_fifo, g_len[seq], (uint16_t)seq);
    memset(g_hw_fifo, 0xEE, sizeof g_hw_fifo);
}

int main(void)
{
    static PoolHandles h;
    unsigned dur, m, k, tick, len, nf, nr;

    if (scanf("%u %u %u %u", &g_n, &g_cost, &dur, &m) != 4 || g_n < 1 || g_n > POOL_MAX || m > 200) return 1;
    for (k = 1; k <= m; k++) {
        if (scanf("%u %u", &tick, &len) != 2 || len < 1 || len > FRAME_CAP) return 1;
        g_len[k] = (uint16_t)len;
        xSimScheduleInterrupt((TickType_t)tick, frame_irq, (void *)(uintptr_t)k);
    }

    pool_init(&h, g_n);
    if (h.free_q == NULL || h.ready_q == NULL) {
        printf("ERROR: pool_init() must create free_q and ready_q\n");
        return 0;
    }
    if (uxQueueGetQueueLength(h.free_q) != g_n || uxQueueGetQueueItemSize(h.free_q) != sizeof(Frame *) ||
        uxQueueGetQueueLength(h.ready_q) != g_n || uxQueueGetQueueItemSize(h.ready_q) != sizeof(Frame *)) {
        printf("ERROR: both queues must hold n items of sizeof(Frame *)\n");
        return 0;
    }
    if (uxQueueMessagesWaiting(h.free_q) != g_n) {
        printf("ERROR: free_q must start with all n buffers\n");
        return 0;
    }
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    nf = (unsigned)uxQueueMessagesWaiting(h.free_q);
    nr = (unsigned)uxQueueMessagesWaiting(h.ready_q);
    printf("processed %u, dropped %u, free %u/%u, ready %u\n", g_processed, g_dropped, nf, g_n, nr);
    if (nf + nr != g_n) printf("ERROR: %u buffer(s) leaked\n", g_n - nf - nr);
    return 0;
}
@@@ sample_input
2 3 20
4
1 4
2 2
3 5
5 1
@@@ sample_output
[t=1] proc #1 buf0 len=4
[t=3] DROP #3
[t=4] proc #2 buf1 len=2
[t=7] proc #4 buf0 len=1
processed 3, dropped 1, free 2/2, ready 0
@@@ sample_input
3 2 15
5
2 8
2 16
2 64
2 1
9 1
@@@ sample_output
[t=2] DROP #4
[t=2] proc #1 buf0 len=8
[t=4] proc #2 buf1 len=16
[t=6] proc #3 buf2 len=64
[t=9] proc #5 buf0 len=1
processed 4, dropped 1, free 3/3, ready 0
@@@ hidden_input
4 5 100
0
@@@ hidden_output
processed 0, dropped 0, free 4/4, ready 0
@@@ hidden_input
1 4 30
5
1 10
2 10
5 10
6 10
9 10
@@@ hidden_output
[t=1] proc #1 buf0 len=10
[t=2] DROP #2
[t=5] DROP #3
[t=6] proc #4 buf0 len=10
[t=9] DROP #5
processed 2, dropped 3, free 1/1, ready 0
@@@ hidden_input
8 1 50
10
1 1
1 2
1 3
1 4
1 5
1 6
1 7
1 8
1 9
1 10
@@@ hidden_output
[t=1] DROP #9
[t=1] DROP #10
[t=1] proc #1 buf0 len=1
[t=2] proc #2 buf1 len=2
[t=3] proc #3 buf2 len=3
[t=4] proc #4 buf3 len=4
[t=5] proc #5 buf4 len=5
[t=6] proc #6 buf5 len=6
[t=7] proc #7 buf6 len=7
[t=8] proc #8 buf7 len=8
processed 8, dropped 2, free 8/8, ready 0

@@@ hidden_input
3 10 200
9
5 64
6 63
7 62
8 61
25 1
35 2
45 3
55 4
55 5
@@@ hidden_output
[t=5] proc #1 buf0 len=64
[t=8] DROP #4
[t=15] proc #2 buf1 len=63
[t=25] proc #3 buf2 len=62
[t=35] proc #5 buf0 len=1
[t=45] proc #6 buf1 len=2
[t=55] DROP #9
[t=55] proc #7 buf2 len=3
[t=65] proc #8 buf0 len=4
processed 7, dropped 2, free 3/3, ready 0

@@@ hidden_input
2 7 60
6
3 20
3 21
10 22
17 23
17 24
50 25
@@@ hidden_output
[t=3] proc #1 buf0 len=20
[t=10] DROP #3
[t=10] proc #2 buf1 len=21
[t=17] DROP #5
[t=17] proc #4 buf0 len=23
[t=50] proc #6 buf1 len=25
processed 4, dropped 2, free 2/2, ready 0

@@@ hidden_input
5 3 2000
12
100 1
101 2
102 3
103 4
104 5
105 6
106 7
107 8
108 9
1000 64
1000 64
1990 7
@@@ hidden_output
[t=100] proc #1 buf0 len=1
[t=103] proc #2 buf1 len=2
[t=106] DROP #7
[t=106] proc #3 buf2 len=3
[t=108] DROP #9
[t=109] proc #4 buf3 len=4
[t=112] proc #5 buf4 len=5
[t=115] proc #6 buf0 len=6
[t=118] proc #8 buf1 len=8
[t=1000] proc #10 buf2 len=64
[t=1003] proc #11 buf3 len=64
[t=1990] proc #12 buf4 len=7
processed 10, dropped 2, free 5/5, ready 0

@@@ hint
Two queues of **pointers** implement ownership transfer: whoever holds the pointer owns the buffer. `free_q` is the free list, so no allocator is needed. Since `ready_q` has the same length as the pool, posting to it can never fail. The only way to run out is an empty `free_q`, and that is where the drop happens.
@@@ hint
ISR: `BaseType_t woken = pdFALSE; Frame *f; if (xQueueReceiveFromISR(s_free, &f, &woken) != pdPASS) { on_drop(seq); } else { memcpy(f->data, bytes, len); f->len = len; f->seq = seq; xQueueSendToBackFromISR(s_ready, &f, &woken); } portYIELD_FROM_ISR(woken);`. Note `&f`, the address of the pointer: the queue copies `sizeof(Frame *)` bytes, i.e. the pointer value.
@@@ solution_code
#include <stdint.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

#define POOL_MAX  8
#define FRAME_CAP 64

typedef struct {
    uint16_t len;
    uint16_t seq;
    uint8_t  data[FRAME_CAP];
} Frame;

extern Frame g_frames[POOL_MAX];

typedef struct {
    QueueHandle_t free_q;
    QueueHandle_t ready_q;
} PoolHandles;

void process_frame(const Frame *f);
void on_drop(uint16_t seq);

static QueueHandle_t s_free;
static QueueHandle_t s_ready;

static void consumer_task(void *pvParameters)
{
    Frame *f;

    (void)pvParameters;
    for (;;) {
        if (xQueueReceive(s_ready, &f, portMAX_DELAY) == pdPASS) {
            process_frame(f);                      /* in place: no copy */
            xQueueSendToBack(s_free, &f, 0);       /* ownership back to the pool, after use */
        }
    }
}

void pool_init(PoolHandles *h, unsigned n)
{
    unsigned i;

    s_free = xQueueCreate(n, sizeof(Frame *));
    s_ready = xQueueCreate(n, sizeof(Frame *));
    for (i = 0; i < n; i++) {
        Frame *f = &g_frames[i];
        xQueueSendToBack(s_free, &f, 0);   /* before the scheduler starts: never blocks */
    }
    h->free_q = s_free;
    h->ready_q = s_ready;
    xTaskCreate(consumer_task, "rx_cons", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
}

void rx_isr(const uint8_t *bytes, uint16_t len, uint16_t seq)
{
    BaseType_t woken = pdFALSE;
    Frame *f;

    if (xQueueReceiveFromISR(s_free, &f, &woken) != pdPASS) {
        on_drop(seq);                              /* pool exhausted: drop, never allocate */
    } else {
        memcpy(f->data, bytes, len);               /* the "DMA" fills the buffer */
        f->len = len;
        f->seq = seq;
        xQueueSendToBackFromISR(s_ready, &f, &woken);   /* cannot fail: ready_q holds n */
    }
    portYIELD_FROM_ISR(woken);
}
@@@ explanation_md
**Approach.** The frames never travel through a queue, only their **addresses** do. The design has three parts:

- **Free list as a queue.** `free_q` starts with all `n` buffer pointers. "Allocate" is `xQueueReceiveFromISR(free_q)`, and "free" is `xQueueSendToBack(free_q)`. Both are O(1), deterministic, interrupt-safe and fragmentation-free. No heap is involved.
- **Ownership transfer.** Exactly one party owns a buffer at any time: the free list, the ISR while it fills the buffer, `ready_q`, or the consumer while it processes it. Whoever holds the pointer may touch the data, and nobody else may.
- **Release after use.** The consumer returns the buffer only **after** `process_frame()` has finished. Return it earlier and the next interrupt may reuse the buffer under the consumer's feet. The harness checks the contents again at the end of processing to catch exactly that.

Because `ready_q` is as long as the pool, the send to it cannot fail: there are never more than `n` pointers in flight. Running out of buffers (pool empty) is the single back-pressure point, and dropping there is cheap and predictable.

**Complexity.** Per frame: O(len) for the copy from the peripheral FIFO into the buffer (a real DMA does this for free), and O(1) queue operations moving 4 or 8 bytes each instead of 68. RAM: `n * sizeof(Frame)` bytes of buffers plus 2 x `n` pointers plus two control blocks. Buffer residency = queueing delay + processing time. The number of buffers you need is roughly the peak arrival rate times that residency.

**Common mistakes**
- Creating the queues with `sizeof(Frame)`: every frame is copied twice, which is the very cost the design avoids.
- Passing `f` instead of `&f` to the send or receive call: the queue then copies `sizeof(Frame *)` bytes **from inside the frame**.
- Queueing the pointer to the peripheral FIFO (`bytes`) itself: it is overwritten after the interrupt (`CORRUPT`).
- Returning the buffer before processing, or never returning it on some path. The second is a leak: the pool shrinks until every frame is dropped.
- Calling `malloc` / `pvPortMalloc` in the ISR: non-deterministic, not ISR-safe, and it fragments the heap over time.
- Forgetting `portYIELD_FROM_ISR()`, which adds one tick of latency to every frame that arrives while the consumer is idle.

**Interview follow-ups**
- How would you share one buffer between two consumers (reference counting, and who returns it to the pool)?
- How do you detect a buffer leak in the field? (Watermark of `uxQueueMessagesWaiting(free_q)`, ownership tags in a debug build.)
- What changes with a real DMA that writes directly into the buffer (cache maintenance, alignment, buffer descriptors handed to hardware in advance)?
- Compare this with message buffers (`xMessageBufferSend`), which copy variable-length frames. When is copying actually better?
