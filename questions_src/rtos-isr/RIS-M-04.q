@@@ meta
id: RIS-M-04
topic: Interrupts & ISRs
difficulty: Medium
type: FUNCTION
title: Consistent Snapshot of Multi-Field ISR State
tags: freertos, isr, critical-section, shared-data, torn-read, snapshot, embedded, asked-in-automotive
@@@ statement_md
An ABS wheel-speed sensor raises an interrupt on every tooth edge. The ISR keeps **three** shared variables up to date, and a periodic task publishes them to the brake controller. If the task reads `g_edge_count` and an edge interrupt fires before it reads `g_last_edge`, the published record mixes two different edges: a **torn read**. The brake controller would then compute a wrong speed.

```c
/* provided, shared with the ISR (all start at 0):
 *   volatile uint32_t g_edge_count;   number of edges so far
 *   volatile uint32_t g_last_edge;    tick of the most recent edge
 *   volatile uint32_t g_period;       ticks between the two most recent edges (0 until the 2nd edge)
 */
typedef struct {                      /* provided */
    uint32_t edge_count;
    uint32_t last_edge;
    uint32_t period;
} WheelSnapshot;

void publish(const WheelSnapshot *s); /* provided: prints and checks; computes for W ticks */

void wheel_isr(void);                 /* you write */
void app_start(TickType_t period);    /* you write */
```

Rules:
- `wheel_isr()` reads the tick with `xTaskGetTickCountFromISR()` and updates the three variables. `g_period` becomes `now - g_last_edge` only from the second edge on.
- `app_start(period)` creates one task with **priority 2**. Every `period` ticks (t = period, 2*period, ...) it copies the three variables into a local `WheelSnapshot` **inside one critical section**, leaves the critical section, and then calls `publish(&snapshot)`.
- `publish()` computes for W ticks. Never call it inside the critical section: interrupts and the tick are masked there. The judge reports that as `FAIL`.

**How the race is modelled.** Code takes zero time in this simulator, so the judge models a real CPU: every task access to one of the three variables **outside** a critical section takes 1 tick, during which interrupts fire, and is counted as `unprotected`.

**How it is tested.** Edges fire at the given ticks. An edge at the same tick as a snapshot is included in it. `publish()` prints

```
[t=<now>] edges=<edge_count> last=<last_edge> period=<period>
```

with ` TORN` appended if the three values never existed together, and ` STALE` if edges happened between the snapshot and the call. The run includes tick `D`. Finally: `snapshots=<n> torn=<n> stale=<n> unprotected=<n>`.

**Input**
```
D P W
N
t1 t2 ... tN      (non-decreasing; empty line when N = 0)
```

**Example**
```
Input:
12 4 2
6
1 2 4 7 11 12

Output:
[t=4] edges=3 last=4 period=2
[t=8] edges=4 last=7 period=3
[t=12] edges=6 last=12 period=1
snapshots=3 torn=0 stale=0 unprotected=0
```
At t=4 the edge of t=4 has already been counted (interrupts run right after the tick changes). While `publish()` computes during ticks 5-6 no edge arrives. At t=12, the edges of t=11 and t=12 give a period of 1.
@@@ constraints_md
- 1 <= P <= 1000, 0 <= W <= 5, W < P, 1 <= D <= 20000, 0 <= N <= 500, 1 <= ti <= D.
- One task, priority 2. Do not declare the shared variables or `WheelSnapshot` yourself: the judge provides them.
- Do not call `vSimBusyWork()`, `publish()` or any blocking API inside a critical section.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

/* provided: volatile uint32_t g_edge_count, g_last_edge, g_period;
 *           typedef struct { uint32_t edge_count, last_edge, period; } WheelSnapshot;
 *           void publish(const WheelSnapshot *s); */

static void wheel_task(void *pvParameters)
{
    TickType_t period = (TickType_t)(uintptr_t)pvParameters;
    TickType_t last = xTaskGetTickCount();

    for (;;) {
        vTaskDelayUntil(&last, period);
        /* TODO: consistent snapshot, then publish() */
    }
}

void wheel_isr(void)
{
    /* TODO */
}

void app_start(TickType_t period)
{
    /* TODO: create the task (priority 2) */
    (void)period;
    (void)wheel_task;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

typedef struct {
    uint32_t edge_count;
    uint32_t last_edge;
    uint32_t period;
} WheelSnapshot;

void publish(const WheelSnapshot *s);
void wheel_isr(void);
void app_start(TickType_t period);

#define MAXEV 500
static volatile uint32_t s_count, s_last, s_period;
static uint32_t g_hist_last[MAXEV + 1], g_hist_period[MAXEV + 1];
static unsigned g_raised, g_snaps, g_torn, g_stale, g_unprot, g_errors, g_cost;
static int g_prot, g_masked;

static inline void h_enter(void) { g_prot++; vPortEnterCritical(); }
static inline void h_exit(void) { g_prot--; vPortExitCritical(); }
static inline void h_disable(void) { g_masked = 1; vPortDisableInterrupts(); }
static inline void h_enable(void) { g_masked = 0; vPortEnableInterrupts(); }
static inline UBaseType_t h_setmask(void) { UBaseType_t m = uxPortSetInterruptMask(); g_masked = 1; return m; }
static inline void h_clearmask(UBaseType_t m) { g_masked = (int)m; vPortClearInterruptMask(m); }

static volatile uint32_t *shared_ref(volatile uint32_t *p)
{
    BaseType_t st;

    if (xPortIsInsideInterrupt() || g_prot > 0 || g_masked) return p;
    st = xTaskGetSchedulerState();
    if (st == taskSCHEDULER_NOT_STARTED) return p;
    g_unprot++;
    if (st == taskSCHEDULER_RUNNING) vSimBusyWork(1);   /* an interruptible load/store */
    return p;
}

void publish(const WheelSnapshot *s)
{
    unsigned now = (unsigned)xTaskGetTickCount();
    int torn, stale;

    if (xPortIsInsideInterrupt()) {
        printf("FAIL: publish() called from the ISR\n");
        g_errors++;
        return;
    }
    if (g_prot > 0 || g_masked) {
        printf("FAIL: publish() called inside a critical section (interrupts are masked for W ticks)\n");
        g_errors++;
        return;
    }
    torn = s->edge_count > g_raised || s->last_edge != g_hist_last[s->edge_count] ||
           s->period != g_hist_period[s->edge_count];
    stale = !torn && s->edge_count != g_raised;
    printf("[t=%u] edges=%u last=%u period=%u%s%s\n", now, (unsigned)s->edge_count, (unsigned)s->last_edge,
           (unsigned)s->period, torn ? " TORN" : "", stale ? " STALE" : "");
    g_snaps++;
    g_torn += (unsigned)torn;
    g_stale += (unsigned)stale;
    if (g_cost) vSimBusyWork((TickType_t)g_cost);
}

#undef portENTER_CRITICAL
#define portENTER_CRITICAL() h_enter()
#undef portEXIT_CRITICAL
#define portEXIT_CRITICAL() h_exit()
#undef portDISABLE_INTERRUPTS
#define portDISABLE_INTERRUPTS() h_disable()
#undef portENABLE_INTERRUPTS
#define portENABLE_INTERRUPTS() h_enable()
#undef portSET_INTERRUPT_MASK_FROM_ISR
#define portSET_INTERRUPT_MASK_FROM_ISR() h_setmask()
#undef portCLEAR_INTERRUPT_MASK_FROM_ISR
#define portCLEAR_INTERRUPT_MASK_FROM_ISR(x) h_clearmask(x)
#define g_edge_count (*shared_ref(&s_count))
#define g_last_edge (*shared_ref(&s_last))
#define g_period (*shared_ref(&s_period))

/*USER_CODE*/

#undef g_edge_count
#undef g_last_edge
#undef g_period

static void irq_entry(void *arg)
{
    uint32_t now = (uint32_t)xTaskGetTickCountFromISR();

    (void)arg;
    /* the judge's own model of the correct state after this edge */
    g_hist_last[g_raised + 1] = now;
    g_hist_period[g_raised + 1] = g_raised == 0 ? 0 : now - g_hist_last[g_raised];
    g_raised++;
    wheel_isr();
}

int main(void)
{
    unsigned d, p, n, i, t;

    if (scanf("%u %u %u %u", &d, &p, &g_cost, &n) != 4 || n > MAXEV) return 1;
    app_start((TickType_t)p);
    for (i = 0; i < n; i++) {
        if (scanf("%u", &t) != 1) return 1;
        xSimScheduleInterrupt((TickType_t)t, irq_entry, NULL);
    }
    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();
    printf("snapshots=%u torn=%u stale=%u unprotected=%u\n", g_snaps, g_torn, g_stale, g_unprot);
    if (s_count != g_raised || s_last != g_hist_last[g_raised] || s_period != g_hist_period[g_raised])
        printf("ISR STATE WRONG: edges=%u last=%u period=%u\n", (unsigned)s_count, (unsigned)s_last, (unsigned)s_period);
    if (g_errors) printf("ERRORS: %u\n", g_errors);
    return 0;
}
@@@ sample_input
12 4 2
6
1 2 4 7 11 12
@@@ sample_output
[t=4] edges=3 last=4 period=2
[t=8] edges=4 last=7 period=3
[t=12] edges=6 last=12 period=1
snapshots=3 torn=0 stale=0 unprotected=0
@@@ sample_input
30 10 3
5
2 5 9 10 21
@@@ sample_output
[t=10] edges=4 last=10 period=1
[t=20] edges=4 last=10 period=1
[t=30] edges=5 last=21 period=11
snapshots=3 torn=0 stale=0 unprotected=0
@@@ hidden_input
9 3 1
0
<<BLANK>>
@@@ hidden_output
[t=3] edges=0 last=0 period=0
[t=6] edges=0 last=0 period=0
[t=9] edges=0 last=0 period=0
snapshots=3 torn=0 stale=0 unprotected=0
@@@ hidden_input
16 4 3
16
1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16
@@@ hidden_output
[t=4] edges=4 last=4 period=1
[t=8] edges=8 last=8 period=1
[t=12] edges=12 last=12 period=1
[t=16] edges=16 last=16 period=1
snapshots=4 torn=0 stale=0 unprotected=0

@@@ hidden_input
25 5 4
7
5 6 6 6 13 20 25
@@@ hidden_output
[t=5] edges=1 last=5 period=0
[t=10] edges=4 last=6 period=0
[t=15] edges=5 last=13 period=7
[t=20] edges=6 last=20 period=7
[t=25] edges=7 last=25 period=5
snapshots=5 torn=0 stale=0 unprotected=0

@@@ hidden_input
20000 2500 5
9
1 3 2500 2501 2502 2502 9000 19999 20000
@@@ hidden_output
[t=2500] edges=3 last=2500 period=2497
[t=5000] edges=6 last=2502 period=0
[t=7500] edges=6 last=2502 period=0
[t=10000] edges=7 last=9000 period=6498
[t=12500] edges=7 last=9000 period=6498
[t=15000] edges=7 last=9000 period=6498
[t=17500] edges=7 last=9000 period=6498
[t=20000] edges=9 last=20000 period=1
snapshots=8 torn=0 stale=0 unprotected=0

@@@ hidden_input
21 7 0
10
1 3 6 7 8 10 14 15 20 21
@@@ hidden_output
[t=7] edges=4 last=7 period=1
[t=14] edges=7 last=14 period=4
[t=21] edges=10 last=21 period=1
snapshots=3 torn=0 stale=0 unprotected=0

@@@ hint
Copy all three fields between one `taskENTER_CRITICAL()` / `taskEXIT_CRITICAL()` pair into a local `WheelSnapshot`, then call `publish(&snap)` after `taskEXIT_CRITICAL()`. Three separate critical sections, one per field, are still torn.
@@@ hint
In the ISR read the old `g_last_edge` **before** overwriting it: `now = xTaskGetTickCountFromISR(); if (g_edge_count > 0) g_period = now - g_last_edge; g_last_edge = now; g_edge_count++;`. The ISR itself needs no critical section: the task cannot preempt it.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

/* provided: volatile uint32_t g_edge_count, g_last_edge, g_period;
 *           typedef struct { uint32_t edge_count, last_edge, period; } WheelSnapshot;
 *           void publish(const WheelSnapshot *s); */

static void wheel_task(void *pvParameters)
{
    TickType_t period = (TickType_t)(uintptr_t)pvParameters;
    TickType_t last = xTaskGetTickCount();
    WheelSnapshot snap;

    for (;;) {
        vTaskDelayUntil(&last, period);

        taskENTER_CRITICAL();              /* all three fields from the same edge */
        snap.edge_count = g_edge_count;
        snap.last_edge  = g_last_edge;
        snap.period     = g_period;
        taskEXIT_CRITICAL();

        publish(&snap);                    /* long work with interrupts enabled */
    }
}

void wheel_isr(void)
{
    uint32_t now = (uint32_t)xTaskGetTickCountFromISR();

    if (g_edge_count > 0) {
        g_period = now - g_last_edge;      /* uses the previous edge's time */
    }
    g_last_edge = now;
    g_edge_count++;
}

void app_start(TickType_t period)
{
    xTaskCreate(wheel_task, "wheel", configMINIMAL_STACK_SIZE, (void *)(uintptr_t)period, 2, NULL);
}
@@@ explanation_md
**Approach.** Single 32-bit loads are atomic on a 32-bit MCU, but a *record* of three words is not. Between the task's first and last load, the ISR can run and update all three, leaving the copy with an edge count from one edge and a timestamp from the next. The fix: take a **snapshot** of all fields inside one critical section, which is short (three loads), then do the long work (`publish()`, W ticks) on the private copy with interrupts enabled. The harness models the hardware race by making every unprotected access interruptible (1 tick), so torn snapshots really happen in the naive version.

In the ISR the order matters too: compute the period from the *old* `g_last_edge`, then overwrite it, then bump the count. The ISR needs no lock: on a single core a task never runs in the middle of an ISR. (On an SMP part, or with nested interrupts that touch the same data, it would.)

**Complexity.** O(1) per edge and per snapshot. Critical section: 3 loads + 3 stores, so the added interrupt latency is a few cycles, regardless of W. RAM: 12 bytes of shared state and a 12-byte snapshot on the task stack.

**Common mistakes**
- Reading the fields one by one without protection (torn), or protecting each field separately (still torn: the ISR can run between the sections).
- Putting `publish()` / the computation inside the critical section. The snapshot is then consistent, but interrupts and the tick are masked for W ticks: edges are delayed, the tick drifts, and on real hardware you miss deadlines. Here, `vSimBusyWork()` inside a critical section is a Runtime Error.
- `vTaskSuspendAll()` as the "lock": it does not stop interrupts.
- Updating `g_last_edge` before computing `g_period`: the period is always 0.
- Declaring the shared variables without `volatile`.

**Interview follow-ups**
- How does a **sequence lock** (ISR increments a sequence number before and after the update; the reader retries if it changed or is odd) avoid masking interrupts? When is it better?
- How would double buffering (the ISR writes the inactive copy and flips an index) solve the same problem?
- Why is a 64-bit timestamp on a 32-bit Cortex-M a torn-read hazard even as a *single* variable?
- What changes on a dual-core MCU, where `taskENTER_CRITICAL()` on one core does not stop the ISR on the other?
