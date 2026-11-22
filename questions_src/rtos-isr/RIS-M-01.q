@@@ meta
id: RIS-M-01
topic: Interrupts & ISRs
difficulty: Medium
type: FUNCTION
title: Crank Sensor ISR: Measure and Fix the Wake-Up Latency
tags: freertos, isr, portyield-from-isr, interrupt-latency, xqueuesendfromisr, timestamp, embedded, asked-in-automotive
@@@ statement_md
An engine ECU gets one interrupt per crankshaft tooth. A legacy driver deferred the processing to a task, but the timing team measured jitter: the handler sometimes ran one tick after the tooth, sometimes in the same tick. The legacy ISR sent the tooth's timestamp to the handler task but **never called `portYIELD_FROM_ISR()`**.

Your job: rebuild the driver so that it **measures** the latency of each tooth, then make the fix switchable, so both behaviours can be compared.

```c
typedef struct {
    uint32_t handled;        /* teeth processed by the handler task      */
    uint32_t max_latency;    /* largest latency seen, in ticks            */
    uint32_t total_latency;  /* sum of all latencies, in ticks            */
} LatencyStats;

void on_tooth(TickType_t isr_tick, TickType_t latency); /* provided: task context, prints one line */
void stamp_overrun(void);                               /* provided: call from the ISR when a stamp is dropped */

void crank_isr(void);                                   /* you write */
void app_start(int use_yield);                          /* you write */
void get_latency_stats(LatencyStats *out);              /* you write */
```

Rules:
- `app_start(use_yield)` runs before the scheduler. It creates a queue of **8 `TickType_t` timestamps** and a handler task with **priority 4**, and remembers `use_yield`.
- `crank_isr()` reads the current tick **with the ISR-safe API** and sends it with `xQueueSendFromISR()`. If the queue is full, it calls `stamp_overrun()`. If `use_yield` is 1, it ends with `portYIELD_FROM_ISR(woken)`. If it is 0, it behaves like the legacy driver: no yield at all.
- The handler loops: receive a stamp (block forever), compute `latency = now - stamp`, update its `LatencyStats`, and call `on_tooth(stamp, latency)`.
- `get_latency_stats()` is called by `main()` after the scheduler has stopped. Fill `*out`.

**The load.** The hidden `main()` also runs an application task with priority 2 that loops forever: `vSimBusyWork(W); vTaskDelay(G);`. It computes for W ticks, then sleeps for G ticks. It starts at t=0, so it computes during ticks 1..W and sleeps until t=W+G.

**When does the handler run without the yield?** At the **next context switch**, which is one of:
- the next tick interrupt: latency 1;
- the running task blocking earlier in the same tick, for example the load task finishing its `vSimBusyWork()` and calling `vTaskDelay()`: latency 0;
- a tick interrupt at the same tick that already needs a switch (it woke the load task): latency 0.

With the yield, the handler always runs at the tooth's tick.

**How it is tested.** `on_tooth()` prints `[t=<now>] tooth irq t=<stamp> latency <latency>` and checks the stamp and the latency against the judge's own records. The run includes tick `D`. Finally `main()` prints `teeth=<interrupts> handled=<n> overruns=<n> max_latency=<n> total_latency=<n>` from your `LatencyStats` and the judge's counters, plus `STATS MISMATCH` if your statistics disagree with what was printed.

**Input**
```
D W G use_yield
N
t1 t2 ... tN      (non-decreasing; empty line when N = 0)
```

**Example 1** (legacy, no yield)
```
Input:
30 3 2 0
5
2 8 12 14 20

Output:
[t=3] tooth irq t=2 latency 1
[t=8] tooth irq t=8 latency 0
[t=13] tooth irq t=12 latency 1
[t=15] tooth irq t=14 latency 1
[t=20] tooth irq t=20 latency 0
teeth=5 handled=5 overruns=0 max_latency=1 total_latency=3
```
The load task computes in ticks 1-3, 6-8, 11-13, 16-18, ... and wakes at t=5, 10, 15, 20, ... The tooth at t=2 arrives mid-computation, so the handler waits for tick 3. At t=8 the load task finishes its computation in that very tick and blocks, so the handler runs at once. At t=14 the CPU is idle and nothing switches until tick 15. At t=20 the tick interrupt wakes the load task, so a switch happens anyway, and it picks the higher-priority handler.

**Example 2** (fixed): the same teeth with `use_yield = 1` all have latency 0.
@@@ constraints_md
- 1 <= D <= 20000, 1 <= W <= 20, 1 <= G <= 20, use_yield in {0, 1}, 0 <= N <= 300, 1 <= ti <= D.
- Queue length 8 of `TickType_t`, handler priority 4, one handler task.
- In the ISR only `...FromISR()` APIs. `xTaskGetTickCount()` is not ISR-safe: the judge reports `FAIL` if the ISR calls it.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    uint32_t handled;
    uint32_t max_latency;
    uint32_t total_latency;
} LatencyStats;

void on_tooth(TickType_t isr_tick, TickType_t latency);   /* provided */
void stamp_overrun(void);                                 /* provided */

static QueueHandle_t s_stamps;
static int s_use_yield;
static LatencyStats s_stats;

static void tooth_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: receive a stamp, measure the latency, update s_stats, on_tooth() */
        vTaskDelay(1000);
    }
}

void crank_isr(void)
{
    /* TODO */
}

void app_start(int use_yield)
{
    s_use_yield = use_yield;
    /* TODO: create the queue and the handler task (priority 4) */
    (void)s_stamps;
    (void)tooth_task;
}

void get_latency_stats(LatencyStats *out)
{
    *out = s_stats;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

/* LatencyStats is defined by the user code */
void on_tooth(TickType_t isr_tick, TickType_t latency);
void stamp_overrun(void);
void crank_isr(void);
void app_start(int use_yield);

#define MAXEV 300
static TickType_t g_fifo[MAXEV];
static unsigned g_head, g_tail, g_raised, g_overruns, g_errors, g_overrun_now;
static unsigned g_handled, g_max, g_total;
static unsigned g_w, g_g;

static inline TickType_t h_tick_count(void)
{
    if (xPortIsInsideInterrupt()) {
        printf("FAIL: xTaskGetTickCount() called from the ISR, use xTaskGetTickCountFromISR()\n");
        g_errors++;
    }
    return xTaskGetTickCount();
}

void stamp_overrun(void)
{
    if (!xPortIsInsideInterrupt()) {
        printf("FAIL: stamp_overrun() must be called from the ISR\n");
        g_errors++;
        return;
    }
    g_overrun_now++;
}

void on_tooth(TickType_t isr_tick, TickType_t latency)
{
    unsigned now = (unsigned)xTaskGetTickCount();

    if (xPortIsInsideInterrupt()) {
        printf("FAIL: on_tooth() called from the ISR\n");
        g_errors++;
        return;
    }
    if (g_head == g_tail) {
        printf("[t=%u] ERROR: tooth irq t=%u was never queued\n", now, (unsigned)isr_tick);
        g_errors++;
        return;
    }
    if (g_fifo[g_head] != isr_tick) {
        printf("[t=%u] ERROR: stamp %u, expected the tooth of t=%u\n", now, (unsigned)isr_tick, (unsigned)g_fifo[g_head]);
        g_errors++;
    } else if ((unsigned)latency != now - (unsigned)isr_tick) {
        printf("[t=%u] ERROR: latency %u reported for irq t=%u, real latency is %u\n", now, (unsigned)latency,
               (unsigned)isr_tick, now - (unsigned)isr_tick);
        g_errors++;
    } else {
        printf("[t=%u] tooth irq t=%u latency %u\n", now, (unsigned)isr_tick, (unsigned)latency);
    }
    g_head++;
    g_handled++;
    g_total += now - (unsigned)isr_tick;
    if (now - (unsigned)isr_tick > g_max) g_max = now - (unsigned)isr_tick;
}

#define xTaskGetTickCount() h_tick_count()

/*USER_CODE*/

#undef xTaskGetTickCount

static void irq_entry(void *arg)
{
    (void)arg;
    g_raised++;
    g_fifo[g_tail++] = xTaskGetTickCountFromISR();
    g_overrun_now = 0;
    crank_isr();
    if (g_overrun_now) {
        g_tail--;
        g_overruns++;
    }
}

static void load_task(void *p)
{
    (void)p;
    for (;;) {
        vSimBusyWork((TickType_t)g_w);
        vTaskDelay((TickType_t)g_g);
    }
}

int main(void)
{
    unsigned d, y, n, i, t;
    LatencyStats st = { 0, 0, 0 };

    if (scanf("%u %u %u %u %u", &d, &g_w, &g_g, &y, &n) != 5 || n > MAXEV) return 1;
    app_start((int)y);
    xTaskCreate(load_task, "load", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
    for (i = 0; i < n; i++) {
        if (scanf("%u", &t) != 1) return 1;
        xSimScheduleInterrupt((TickType_t)t, irq_entry, NULL);
    }
    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();
    get_latency_stats(&st);
    printf("teeth=%u handled=%u overruns=%u max_latency=%u total_latency=%u\n", g_raised, (unsigned)st.handled,
           g_overruns, (unsigned)st.max_latency, (unsigned)st.total_latency);
    if (st.handled != g_handled || st.max_latency != g_max || st.total_latency != g_total) printf("STATS MISMATCH\n");
    if (g_errors) printf("ERRORS: %u\n", g_errors);
    return 0;
}
@@@ sample_input
30 3 2 0
5
2 8 12 14 20
@@@ sample_output
[t=3] tooth irq t=2 latency 1
[t=8] tooth irq t=8 latency 0
[t=13] tooth irq t=12 latency 1
[t=15] tooth irq t=14 latency 1
[t=20] tooth irq t=20 latency 0
teeth=5 handled=5 overruns=0 max_latency=1 total_latency=3
@@@ sample_input
30 3 2 1
5
2 8 12 14 20
@@@ sample_output
[t=2] tooth irq t=2 latency 0
[t=8] tooth irq t=8 latency 0
[t=12] tooth irq t=12 latency 0
[t=14] tooth irq t=14 latency 0
[t=20] tooth irq t=20 latency 0
teeth=5 handled=5 overruns=0 max_latency=0 total_latency=0
@@@ hidden_input
50 5 5 1
0
<<BLANK>>
@@@ hidden_output
teeth=0 handled=0 overruns=0 max_latency=0 total_latency=0
@@@ hidden_input
20 4 1 0
11
1 3 3 3 3 3 3 3 3 3 3
@@@ hidden_output
[t=2] tooth irq t=1 latency 1
[t=4] tooth irq t=3 latency 1
[t=4] tooth irq t=3 latency 1
[t=4] tooth irq t=3 latency 1
[t=4] tooth irq t=3 latency 1
[t=4] tooth irq t=3 latency 1
[t=4] tooth irq t=3 latency 1
[t=4] tooth irq t=3 latency 1
[t=4] tooth irq t=3 latency 1
teeth=11 handled=9 overruns=2 max_latency=1 total_latency=9

@@@ hidden_input
20 4 1 1
11
1 3 3 3 3 3 3 3 3 3 3
@@@ hidden_output
[t=1] tooth irq t=1 latency 0
[t=3] tooth irq t=3 latency 0
[t=3] tooth irq t=3 latency 0
[t=3] tooth irq t=3 latency 0
[t=3] tooth irq t=3 latency 0
[t=3] tooth irq t=3 latency 0
[t=3] tooth irq t=3 latency 0
[t=3] tooth irq t=3 latency 0
[t=3] tooth irq t=3 latency 0
teeth=11 handled=9 overruns=2 max_latency=0 total_latency=0

@@@ hidden_input
40 2 3 0
12
1 2 3 4 5 6 7 8 9 10 11 40
@@@ hidden_output
[t=2] tooth irq t=1 latency 1
[t=2] tooth irq t=2 latency 0
[t=4] tooth irq t=3 latency 1
[t=4] tooth irq t=4 latency 0
[t=5] tooth irq t=5 latency 0
[t=7] tooth irq t=6 latency 1
[t=7] tooth irq t=7 latency 0
[t=9] tooth irq t=8 latency 1
[t=9] tooth irq t=9 latency 0
[t=10] tooth irq t=10 latency 0
[t=12] tooth irq t=11 latency 1
[t=40] tooth irq t=40 latency 0
teeth=12 handled=12 overruns=0 max_latency=1 total_latency=5

@@@ hidden_input
40 2 3 1
12
1 2 3 4 5 6 7 8 9 10 11 40
@@@ hidden_output
[t=1] tooth irq t=1 latency 0
[t=2] tooth irq t=2 latency 0
[t=3] tooth irq t=3 latency 0
[t=4] tooth irq t=4 latency 0
[t=5] tooth irq t=5 latency 0
[t=6] tooth irq t=6 latency 0
[t=7] tooth irq t=7 latency 0
[t=8] tooth irq t=8 latency 0
[t=9] tooth irq t=9 latency 0
[t=10] tooth irq t=10 latency 0
[t=11] tooth irq t=11 latency 0
[t=40] tooth irq t=40 latency 0
teeth=12 handled=12 overruns=0 max_latency=0 total_latency=0

@@@ hidden_input
20000 7 13 0
8
19 20 21 999 1000 12345 19999 20000
@@@ hidden_output
[t=20] tooth irq t=19 latency 1
[t=20] tooth irq t=20 latency 0
[t=22] tooth irq t=21 latency 1
[t=1000] tooth irq t=999 latency 1
[t=1000] tooth irq t=1000 latency 0
[t=12346] tooth irq t=12345 latency 1
[t=20000] tooth irq t=19999 latency 1
[t=20000] tooth irq t=20000 latency 0
teeth=8 handled=8 overruns=0 max_latency=1 total_latency=5

@@@ hint
Timestamp with `xTaskGetTickCountFromISR()`, send it with `xQueueSendFromISR(q, &stamp, &woken)`, and only then decide `if (s_use_yield) portYIELD_FROM_ISR(woken);`. The handler computes `xTaskGetTickCount() - stamp` right after `xQueueReceive()` returns.
@@@ hint
The latency is decided by **when the next context switch happens**, not by priorities alone. With the yield, the switch happens when the ISR returns. Without it, the switch waits for the next tick interrupt, unless the running task blocks first, or the tick interrupt of the same tick already requested a switch.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    uint32_t handled;
    uint32_t max_latency;
    uint32_t total_latency;
} LatencyStats;

void on_tooth(TickType_t isr_tick, TickType_t latency);   /* provided */
void stamp_overrun(void);                                 /* provided */

#define STAMP_QUEUE_LEN 8

static QueueHandle_t s_stamps;
static int s_use_yield;
static LatencyStats s_stats;      /* written by the handler task only */

static void tooth_task(void *pvParameters)
{
    TickType_t stamp, lat;

    (void)pvParameters;
    for (;;) {
        if (xQueueReceive(s_stamps, &stamp, portMAX_DELAY) != pdPASS) continue;
        lat = xTaskGetTickCount() - stamp;           /* wrap-safe unsigned subtraction */
        s_stats.handled++;
        s_stats.total_latency += (uint32_t)lat;
        if ((uint32_t)lat > s_stats.max_latency) s_stats.max_latency = (uint32_t)lat;
        on_tooth(stamp, lat);
    }
}

void crank_isr(void)
{
    BaseType_t woken = pdFALSE;
    TickType_t stamp = xTaskGetTickCountFromISR();   /* ISR-safe tick read */

    if (xQueueSendFromISR(s_stamps, &stamp, &woken) != pdPASS) {
        stamp_overrun();
    }
    if (s_use_yield) {
        portYIELD_FROM_ISR(woken);                   /* the fix */
    }
    /* legacy: no yield, the handler waits for the next context switch */
}

void app_start(int use_yield)
{
    s_use_yield = use_yield;
    s_stamps = xQueueCreate(STAMP_QUEUE_LEN, sizeof(TickType_t));
    configASSERT(s_stamps != NULL);
    xTaskCreate(tooth_task, "tooth", configMINIMAL_STACK_SIZE, NULL, 4, NULL);
}

void get_latency_stats(LatencyStats *out)
{
    *out = s_stats;               /* scheduler stopped: no concurrent writer */
}
@@@ explanation_md
**Approach.** Take the timestamp **in the ISR**, the only place that knows when the event happened, and carry it to the task through the queue. The task subtracts it from its own tick count: that difference is exactly the deferral latency. The queue also keeps the stamps of a burst separate and in order.

`xQueueSendFromISR()` never switches context itself. It only reports through `woken` that a higher-priority task became ready. A pending switch is then performed at the **next context switch**:
- `portYIELD_FROM_ISR(woken)`: when the ISR returns (latency 0, the fix);
- otherwise, the next tick interrupt (latency 1 tick; on real hardware anything up to a full tick period, i.e. jitter);
- or earlier if the running task blocks in the same tick (the load task finishing its burst at t=8), or if the tick interrupt of that tick already requested a switch (the load task waking at t=20).

That is why the legacy driver showed *jitter* (0 or 1 tick) rather than a constant delay. That kind of bug is hard to find on a bench.

**Complexity.** ISR: O(1) (one tick read, one 4-byte queue copy). Task: O(1) per tooth. RAM: 8 x 4 bytes of queue storage, the queue control block, one stack, 12 bytes of statistics. Worst-case latency: 0 ticks with the yield; 1 tick period without it.

**Common mistakes**
- Timestamping in the task instead of the ISR: you measure nothing (latency is always 0), and the angle computation uses the wrong time.
- `xTaskGetTickCount()` in the ISR: not interrupt-safe on every port. The FromISR variant exists for that reason.
- Calling `portYIELD_FROM_ISR(pdTRUE)` unconditionally. It is harmless but wasteful: it forces a switch even when no higher-priority task was woken.
- Computing latency with signed arithmetic or `abs()`. `now - stamp` on unsigned `TickType_t` is correct even across tick-counter wrap-around.
- Queue too short for a burst: the overrun must be counted, not ignored.

**Interview follow-ups**
- On a Cortex-M, how is `portYIELD_FROM_ISR` implemented (setting PendSV), and why does the switch happen only after the ISR returns?
- A 1 ms tick gives 1 ms resolution. How would you timestamp teeth with microsecond accuracy (input capture timer)?
- Why does `configUSE_PREEMPTION = 0` change all of this?
- Would a direct-to-task notification carrying the stamp (`xTaskNotifyFromISR` with `eSetValueWithOverwrite`) work for bursts? What would be lost?
