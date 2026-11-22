@@@ meta
id: RTM-M-03
topic: Software Timers
difficulty: Medium
type: FUNCTION
title: Deferred CAN Frame Processing With xTimerPendFunctionCallFromISR
tags: freertos, software-timers, xtimerpendfunctioncall, deferred-interrupt-processing, isr, can, embedded, asked-in-automotive
@@@ statement_md
A body controller receives CAN frames on two buses. Processing a frame is too slow for an ISR, but a dedicated handler task per bus is too expensive in RAM. Instead, **defer the work to the timer service task** with `xTimerPendFunctionCallFromISR()`.

```c
/* provided, ISR-safe: pops the oldest frame of the bus's hardware RX FIFO.
   Returns 1 and stores it in *frame, or returns 0 if the FIFO is empty. */
int  can_fifo_read(int bus, uint32_t *frame);

/* provided: the slow processing. Must run in the timer service task.
   Prints "[t=<tick>] CAN<bus> 0x<id>" */
void frame_process(int bus, uint32_t frame);

/* provided, ISR-safe: report a frame that could not be deferred.
   Prints "[t=<tick>] DROP CAN<bus> 0x<id>" */
void frame_dropped(int bus, uint32_t frame);

void can_rx_isr(int bus);   /* you write: the RX interrupt handler of bus 0 or 1 */
```

`can_rx_isr(bus)` runs in **interrupt context**. It must:

1. drain the bus's FIFO completely (the harness checks that it is empty when the ISR returns),
2. for each frame, pend a call that later runs `frame_process(bus, frame)` in the timer service task. Use the two parameters of the pended function to pass the bus and the frame;
3. if `xTimerPendFunctionCallFromISR()` fails (the timer command queue is full), call `frame_dropped(bus, frame)` for that frame;
4. request a context switch with `portYIELD_FROM_ISR()`, so the deferred work runs at **the same tick**.

**Timing rules.** The timer service task has priority 7, so a deferred call preempts every application task. Here a priority-2 task is always busy. The timer command queue holds **16** commands and is processed in FIFO order. All interrupts that occur at one tick run before the timer service task gets the CPU, so they share the 16 slots.

Rules: no tasks, no timers, no queues of your own. `frame_process()` must not be called from the ISR. Use the ISR-safe APIs only.

**How it is tested.** At each listed tick, the hidden interrupt pushes the listed frames into the bus FIFO and calls `can_rx_isr(bus)`. Interrupts at the same tick run in input order. The scheduler runs up to and including tick `D`. Then the harness prints how many frames were processed or dropped, and the worst processing latency (processing tick minus arrival tick).

**Input**
```
<n>
<tick> <bus> <k> <id_1> ... <id_k>     (n lines, ticks non-decreasing, ids in hex, all distinct)
<D>
```

**Example**
```
Input:
3
7 1 1 2A0
7 0 2 0F0 0F1
30 0 1 7FF
40

Output:
[t=7] CAN1 0x2A0
[t=7] CAN0 0x0F0
[t=7] CAN0 0x0F1
[t=30] CAN0 0x7FF
processed=4
dropped=0
max latency=0
```
Both interrupts at t=7 run first: bus 1, then bus 0. They queue three deferred calls, and the timer service task then runs them in FIFO order at the same tick.
@@@ constraints_md
- 0 <= n <= 20, bus is 0 or 1, 0 <= k <= 32, 1 <= tick < D <= 5000, ids are 11-bit (0x000 .. 0x7FF).
- Timer command queue length: 16 (`configTIMER_QUEUE_LENGTH`).
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

int  can_fifo_read(int bus, uint32_t *frame);
void frame_process(int bus, uint32_t frame);
void frame_dropped(int bus, uint32_t frame);

static void deferred_frame(void *pvParameter1, uint32_t ulParameter2)
{
    /* TODO: runs in the timer service task */
    (void)pvParameter1;
    (void)ulParameter2;
}

void can_rx_isr(int bus)
{
    /* TODO: drain the FIFO and defer each frame */
    (void)bus;
    (void)deferred_frame;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "timers.h"
#include "sim.h"

#define FIFO_MAX 64
#define MAX_EV 32
#define MAX_FR 1024

static uint32_t g_fifo[2][FIFO_MAX];
static unsigned g_head[2], g_tail[2];
static uint32_t g_fr_id[MAX_FR];
static TickType_t g_fr_tick[MAX_FR];
static unsigned g_nfr;
static volatile int g_in_isr;
static unsigned g_processed, g_dropped, g_max_lat;
static int g_bad_ctx, g_not_drained, g_unknown;

int can_fifo_read(int bus, uint32_t *frame)
{
    if (bus < 0 || bus > 1 || frame == NULL) return 0;
    if (g_head[bus] == g_tail[bus]) return 0;
    *frame = g_fifo[bus][g_head[bus] % FIFO_MAX];
    g_head[bus]++;
    return 1;
}

static void account(uint32_t frame, int processed)
{
    unsigned i;
    for (i = 0; i < g_nfr; i++) {
        if (g_fr_id[i] == frame) {
            if (processed) {
                unsigned lat = (unsigned)(xTaskGetTickCount() - g_fr_tick[i]);
                if (lat > g_max_lat) g_max_lat = lat;
            }
            return;
        }
    }
    g_unknown = 1;
}

void frame_process(int bus, uint32_t frame)
{
    if (g_in_isr || xTaskGetCurrentTaskHandle() != xTimerGetTimerDaemonTaskHandle()) g_bad_ctx = 1;
    printf("[t=%u] CAN%d 0x%03X\n", (unsigned)xTaskGetTickCount(), bus, (unsigned)frame);
    g_processed++;
    account(frame, 1);
}

void frame_dropped(int bus, uint32_t frame)
{
    printf("[t=%u] DROP CAN%d 0x%03X\n", (unsigned)xTaskGetTickCountFromISR(), bus, (unsigned)frame);
    g_dropped++;
    account(frame, 0);
}

#define xTaskCreate(...) xTaskCreate_is_not_allowed_here
#define xTaskCreateStatic(...) xTaskCreateStatic_is_not_allowed_here
#define xTimerCreate(...) xTimerCreate_is_not_allowed_here
#define xTimerCreateStatic(...) xTimerCreateStatic_is_not_allowed_here
#undef xQueueCreate
#define xQueueCreate(...) xQueueCreate_is_not_allowed_here
#define vTaskDelay(x) vTaskDelay_is_not_allowed_here

/*USER_CODE*/

#undef xTaskCreate
#undef xTaskCreateStatic
#undef xTimerCreate
#undef xTimerCreateStatic
#undef xQueueCreate
#undef vTaskDelay

typedef struct { int bus; unsigned k; uint32_t ids[32]; } RxEvent;
static RxEvent g_ev[MAX_EV];

static void rx_irq(void *arg)
{
    RxEvent *e = (RxEvent *)arg;
    unsigned i;
    for (i = 0; i < e->k; i++) {
        g_fifo[e->bus][g_tail[e->bus] % FIFO_MAX] = e->ids[i];
        g_tail[e->bus]++;
        if (g_nfr < MAX_FR) {
            g_fr_id[g_nfr] = e->ids[i];
            g_fr_tick[g_nfr] = xTaskGetTickCountFromISR();
            g_nfr++;
        }
    }
    g_in_isr = 1;
    can_rx_isr(e->bus);
    g_in_isr = 0;
    if (g_head[e->bus] != g_tail[e->bus]) {
        g_not_drained = 1;
        g_head[e->bus] = g_tail[e->bus];
    }
}

static void busy_app(void *p)
{
    (void)p;
    for (;;) vSimBusyWork(5);   /* the CPU is never idle */
}

int main(void)
{
    unsigned n, i, j, t, b, k, dur, id;

    if (scanf("%u", &n) != 1 || n > MAX_EV) return 1;
    for (i = 0; i < n; i++) {
        if (scanf("%u %u %u", &t, &b, &k) != 3 || b > 1 || k > 32) return 1;
        g_ev[i].bus = (int)b;
        g_ev[i].k = k;
        for (j = 0; j < k; j++) {
            if (scanf("%x", &id) != 1) return 1;
            g_ev[i].ids[j] = (uint32_t)id;
        }
        xSimScheduleInterrupt((TickType_t)t, rx_irq, &g_ev[i]);
    }
    if (scanf("%u", &dur) != 1) return 1;

    xTaskCreate(busy_app, "app", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    if (g_bad_ctx) printf("FAIL: frame_process() called outside the timer service task\n");
    if (g_not_drained) printf("FAIL: the RX FIFO was not drained by the ISR\n");
    if (g_unknown) printf("FAIL: unknown frame id reported\n");
    printf("processed=%u\n", g_processed);
    printf("dropped=%u\n", g_dropped);
    printf("max latency=%u\n", g_max_lat);
    return 0;
}
@@@ sample_input
3
7 1 1 2A0
7 0 2 0F0 0F1
30 0 1 7FF
40
@@@ sample_output
[t=7] CAN1 0x2A0
[t=7] CAN0 0x0F0
[t=7] CAN0 0x0F1
[t=30] CAN0 0x7FF
processed=4
dropped=0
max latency=0
@@@ sample_input
2
5 0 18 300 301 302 303 304 305 306 307 308 309 30A 30B 30C 30D 30E 30F 310 311
6 1 1 123
10
@@@ sample_output
[t=5] DROP CAN0 0x310
[t=5] DROP CAN0 0x311
[t=5] CAN0 0x300
[t=5] CAN0 0x301
[t=5] CAN0 0x302
[t=5] CAN0 0x303
[t=5] CAN0 0x304
[t=5] CAN0 0x305
[t=5] CAN0 0x306
[t=5] CAN0 0x307
[t=5] CAN0 0x308
[t=5] CAN0 0x309
[t=5] CAN0 0x30A
[t=5] CAN0 0x30B
[t=5] CAN0 0x30C
[t=5] CAN0 0x30D
[t=5] CAN0 0x30E
[t=5] CAN0 0x30F
[t=6] CAN1 0x123
processed=17
dropped=2
max latency=0
@@@ hidden_input
0
50
@@@ hidden_output
processed=0
dropped=0
max latency=0
@@@ hidden_input
1
1 0 1 001
3
@@@ hidden_output
[t=1] CAN0 0x001
processed=1
dropped=0
max latency=0
@@@ hidden_input
2
9 0 10 400 401 402 403 404 405 406 407 408 409
9 1 10 500 501 502 503 504 505 506 507 508 509
20
@@@ hidden_output
[t=9] DROP CAN1 0x506
[t=9] DROP CAN1 0x507
[t=9] DROP CAN1 0x508
[t=9] DROP CAN1 0x509
[t=9] CAN0 0x400
[t=9] CAN0 0x401
[t=9] CAN0 0x402
[t=9] CAN0 0x403
[t=9] CAN0 0x404
[t=9] CAN0 0x405
[t=9] CAN0 0x406
[t=9] CAN0 0x407
[t=9] CAN0 0x408
[t=9] CAN0 0x409
[t=9] CAN1 0x500
[t=9] CAN1 0x501
[t=9] CAN1 0x502
[t=9] CAN1 0x503
[t=9] CAN1 0x504
[t=9] CAN1 0x505
processed=16
dropped=4
max latency=0
@@@ hidden_input
2
3 0 16 600 601 602 603 604 605 606 607 608 609 60A 60B 60C 60D 60E 60F
4 0 1 610
10
@@@ hidden_output
[t=3] CAN0 0x600
[t=3] CAN0 0x601
[t=3] CAN0 0x602
[t=3] CAN0 0x603
[t=3] CAN0 0x604
[t=3] CAN0 0x605
[t=3] CAN0 0x606
[t=3] CAN0 0x607
[t=3] CAN0 0x608
[t=3] CAN0 0x609
[t=3] CAN0 0x60A
[t=3] CAN0 0x60B
[t=3] CAN0 0x60C
[t=3] CAN0 0x60D
[t=3] CAN0 0x60E
[t=3] CAN0 0x60F
[t=4] CAN0 0x610
processed=17
dropped=0
max latency=0
@@@ hidden_input
3
10 1 0
11 1 2 0AA 0AB
2000 0 1 0CC
3000
@@@ hidden_output
[t=11] CAN1 0x0AA
[t=11] CAN1 0x0AB
[t=2000] CAN0 0x0CC
processed=3
dropped=0
max latency=0
@@@ hidden_input
4
100 0 3 010 011 012
100 1 2 020 021
101 0 1 013
101 1 1 022
200
@@@ hidden_output
[t=100] CAN0 0x010
[t=100] CAN0 0x011
[t=100] CAN0 0x012
[t=100] CAN1 0x020
[t=100] CAN1 0x021
[t=101] CAN0 0x013
[t=101] CAN1 0x022
processed=7
dropped=0
max latency=0
@@@ hint
`xTimerPendFunctionCallFromISR(fn, pvParam1, ulParam2, &woken)` queues "call `fn(pvParam1, ulParam2)`" to the timer service task. The bus fits in `pvParam1` (for example `(void *)(uintptr_t)bus`) and the frame in `ulParam2`.
@@@ hint
`BaseType_t w = pdFALSE; uint32_t f; while (can_fifo_read(bus, &f)) { if (xTimerPendFunctionCallFromISR(deferred_frame, (void *)(uintptr_t)bus, f, &w) != pdPASS) frame_dropped(bus, f); } portYIELD_FROM_ISR(w);`. The deferred function casts back: `frame_process((int)(uintptr_t)p1, p2);`.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

int  can_fifo_read(int bus, uint32_t *frame);
void frame_process(int bus, uint32_t frame);
void frame_dropped(int bus, uint32_t frame);

/* runs in the timer service task (priority 7), never in the ISR */
static void deferred_frame(void *pvParameter1, uint32_t ulParameter2)
{
    frame_process((int)(uintptr_t)pvParameter1, ulParameter2);
}

void can_rx_isr(int bus)
{
    BaseType_t woken = pdFALSE;
    uint32_t f;

    while (can_fifo_read(bus, &f)) {            /* always drain the hardware FIFO */
        if (xTimerPendFunctionCallFromISR(deferred_frame, (void *)(uintptr_t)bus, f, &woken) != pdPASS) {
            frame_dropped(bus, f);              /* timer queue full: account for it */
        }
    }
    portYIELD_FROM_ISR(woken);                  /* run the deferred work at this tick */
}
@@@ explanation_md
**Approach.** `xTimerPendFunctionCallFromISR()` posts a special command to the timer command queue: "execute this function with these two parameters". The timer service task, a daemon that already exists, picks it up and calls the function in task context. You get deferred interrupt processing with **no extra task, stack or queue**. The ISR only drains the hardware FIFO, which must always be done or the controller overruns, and queues one command per frame.

`woken` becomes `pdTRUE` because the timer service task (priority 7) is unblocked. `portYIELD_FROM_ISR(woken)` makes it run as soon as the interrupt returns, at the same tick, ahead of the busy priority-2 application task. Without the yield, the deferred work waits for the next tick interrupt, and the latency becomes 1 tick.

The queue is the limit: 16 entries, shared by everything that sends timer commands. All interrupts of one tick run before the daemon can drain anything. In the example with 18 frames, the 17th and 18th pend calls fail and must be accounted for. The DROP lines appear first because they are printed inside the ISR, before any deferred call runs.

**Complexity.** Per frame: O(1) in the ISR (one queue copy of a small command struct), and O(1) plus `frame_process` in the daemon. Worst-case latency: the time to run all commands queued before it (FIFO). RAM: nothing extra, but the timer task stack must be large enough for the deepest deferred function.

**Common mistakes**
- Missing `portYIELD_FROM_ISR()`: the work is done one tick late. The harness reports the latency.
- Processing the frame in the ISR (the "it's only a printf" trap): long ISRs delay every other interrupt.
- Ignoring the return value: frames silently disappear when the queue is full, and nobody knows.
- Reading only one frame per interrupt: the FIFO keeps the rest, and the next interrupt may never come (level vs. edge interrupt).
- Passing a pointer to a local `uint32_t` as `pvParameter1`: the ISR stack frame is gone when the daemon runs. Pass values, or pointers to static storage.
- Blocking inside the deferred function: it stalls every software timer in the system.

**Interview follow-ups**
- How would you size `configTIMER_QUEUE_LENGTH`, and what other code competes for that queue?
- When is a dedicated handler task with a stream/message buffer a better choice than the timer daemon?
- The daemon runs at the highest priority here. What if `frame_process` takes 3 ms? Who suffers?
- How do you deliver frames to the application without dropping them when the queue is full (double buffering in the ISR, a counting semaphore, a ring buffer)?
