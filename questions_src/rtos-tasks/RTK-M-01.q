@@@ meta
id: RTK-M-01
topic: Tasks & Scheduling
difficulty: Medium
type: FUNCTION
title: Drift-Free ADC Sampler With vTaskDelayUntil
tags: freertos, vtaskdelayuntil, periodic-task, jitter, drift, embedded, asked-in-automotive
@@@ statement_md
A battery-management ECU samples cell voltages every `P` ticks. The samples feed a digital filter whose coefficients assume a **fixed sampling grid**: sample `k` must be taken at `t = k * P`. Each sample is followed by some filter work whose CPU cost varies from sample to sample. A higher-priority CAN task sometimes occupies the CPU as well.

```c
/* provided by the test harness */
void       adc_sample(void);     /* takes sample k (k = 1, 2, ...) and logs it      */
TickType_t filter_cost(void);    /* CPU ticks of the filter work for this sample     */

void app_start(TickType_t period);   /* you write this and the sampler task */
```

`app_start()` is called before the scheduler starts. It creates the **sampler task** with priority **2**. The task repeats forever:

1. wait until the next grid point `k * P`,
2. call `adc_sample()`,
3. do the filter work: `vSimBusyWork(filter_cost())`.

The first sample is at `t = P`.

**Late samples.** A sample is late when the CPU is busy at its grid point: either the CAN task (priority 4) is running, or the previous filter work has not finished yet (an **overrun**). A late sample is taken as soon as possible. Later samples must return to the grid. After a long overrun, every missed grid point is still sampled, back to back, as soon as the CPU is free (catch-up). This is exactly what `vTaskDelayUntil()` does.

**How it is tested.** The hidden `main()` creates the CAN task, calls `app_start(P)`, and runs the scheduler up to tick `D`. `adc_sample()` prints `[t=<tick>] sample <k> <lateness>`, where lateness = `t - k*P` with a sign. The CAN task prints `[t=<tick>] CAN burst` each time it starts a burst. At the end the harness prints the number of samples and the maximum lateness.

**Input**
```
<P> <D>
<n> <cost 1> ... <cost n>          filter costs, used cyclically
<m>                                number of CAN bursts
<tick> <cost>                      m lines: burst starts at <tick>, takes <cost> CPU ticks
```

**Example**
```
Input:
10 60
3 3 15 2
1
48 4

Output:
[t=10] sample 1 +0
[t=20] sample 2 +0
[t=35] sample 3 +5
[t=40] sample 4 +0
[t=48] CAN burst
[t=52] sample 5 +2
samples: 5
max lateness: 5
```
Sample 2's filter work takes 15 ticks and ends at t=35, which overruns grid point 30. Sample 3 is taken immediately at t=35 (+5). Sample 4 is back on the grid at t=40. The CAN burst occupies the CPU during t=48..52, so sample 5 (due at 50) comes at t=52. Its 15-tick filter work is still running when the run ends at t=60.
@@@ constraints_md
- 1 <= P <= 100, 1 <= D <= 5000, 1 <= n <= 10, 0 <= cost <= 300, 0 <= m <= 20.
- CAN bursts are given in increasing tick order and do not overlap.
- The sampler task must block between samples. Use stack size `configMINIMAL_STACK_SIZE`.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

void       adc_sample(void);
TickType_t filter_cost(void);

static TickType_t g_period;

static void sampler_task(void *pv)
{
    (void)pv;
    for (;;) {
        vTaskDelay(g_period);              /* TODO: this drifts - fix it */
        adc_sample();
        vSimBusyWork(filter_cost());
    }
}

void app_start(TickType_t period)
{
    g_period = period;
    xTaskCreate(sampler_task, "sampler", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

static TickType_t g_P;
static unsigned g_k;
static int g_max_late;
static unsigned g_ncost, g_cost_idx;
static TickType_t g_cost[10];
static unsigned g_nburst;
static TickType_t g_burst_t[20], g_burst_c[20];

void adc_sample(void)
{
    int now = (int)xTaskGetTickCount();
    int late;
    g_k++;
    late = now - (int)(g_k * g_P);
    if (late > g_max_late) g_max_late = late;
    printf("[t=%d] sample %u %+d\n", now, g_k, late);
}

TickType_t filter_cost(void)
{
    return g_cost[g_cost_idx++ % g_ncost];
}

static void can_task(void *pv)
{
    unsigned i;
    (void)pv;
    for (i = 0; i < g_nburst; i++) {
        TickType_t now = xTaskGetTickCount();
        if (g_burst_t[i] > now) vTaskDelay(g_burst_t[i] - now);
        printf("[t=%u] CAN burst\n", (unsigned)xTaskGetTickCount());
        vSimBusyWork(g_burst_c[i]);
    }
    vTaskDelete(NULL);
}

/*USER_CODE*/

int main(void)
{
    unsigned P, D, i, a, b;

    if (scanf("%u %u", &P, &D) != 2) return 1;
    if (scanf("%u", &g_ncost) != 1 || g_ncost < 1 || g_ncost > 10) return 1;
    for (i = 0; i < g_ncost; i++) {
        if (scanf("%u", &a) != 1) return 1;
        g_cost[i] = (TickType_t)a;
    }
    if (scanf("%u", &g_nburst) != 1 || g_nburst > 20) return 1;
    for (i = 0; i < g_nburst; i++) {
        if (scanf("%u %u", &a, &b) != 2) return 1;
        g_burst_t[i] = (TickType_t)a;
        g_burst_c[i] = (TickType_t)b;
    }
    g_P = (TickType_t)P;

    xTaskCreate(can_task, "can", configMINIMAL_STACK_SIZE, NULL, 4, NULL);
    app_start(g_P);
    vSimSetTickLimit((TickType_t)D);
    vTaskStartScheduler();

    printf("samples: %u\n", g_k);
    printf("max lateness: %d\n", g_max_late);
    return 0;
}
@@@ sample_input
10 60
3 3 15 2
1
48 4
@@@ sample_output
[t=10] sample 1 +0
[t=20] sample 2 +0
[t=35] sample 3 +5
[t=40] sample 4 +0
[t=48] CAN burst
[t=52] sample 5 +2
samples: 5
max lateness: 5
@@@ sample_input
10 50
1 3
0
@@@ sample_output
[t=10] sample 1 +0
[t=20] sample 2 +0
[t=30] sample 3 +0
[t=40] sample 4 +0
[t=50] sample 5 +0
samples: 5
max lateness: 0
@@@ hidden_input
5 40
1 4
2
9 3
20 2
@@@ hidden_output
[t=5] sample 1 +0
[t=9] CAN burst
[t=12] sample 2 +2
[t=16] sample 3 +1
[t=20] CAN burst
[t=22] sample 4 +2
[t=26] sample 5 +1
[t=30] sample 6 +0
[t=35] sample 7 +0
[t=40] sample 8 +0
samples: 8
max lateness: 2
@@@ hidden_input
10 60
2 25 1
0
@@@ hidden_output
[t=10] sample 1 +0
[t=35] sample 2 +15
[t=36] sample 3 +6
samples: 3
max lateness: 15
@@@ hidden_input
1 6
1 0
1
3 2
@@@ hidden_output
[t=1] sample 1 +0
[t=2] sample 2 +0
[t=3] CAN burst
[t=5] sample 3 +2
[t=5] sample 4 +1
[t=5] sample 5 +0
[t=6] sample 6 +0
samples: 6
max lateness: 2
@@@ hidden_input
20 100
4 19 7 0 12
1
40 6
@@@ hidden_output
[t=20] sample 1 +0
[t=40] CAN burst
[t=46] sample 2 +6
[t=60] sample 3 +0
[t=80] sample 4 +0
[t=100] sample 5 +0
samples: 5
max lateness: 6
@@@ hidden_input
7 30
1 6
0
@@@ hidden_output
[t=7] sample 1 +0
[t=14] sample 2 +0
[t=21] sample 3 +0
[t=28] sample 4 +0
samples: 4
max lateness: 0
@@@ hint
`vTaskDelay(P)` waits `P` ticks **from now**. Every tick spent in the filter work (or preempted by CAN) is added to the period, and the error accumulates. You need a wake-up time computed from the previous *planned* wake-up time, not from the current time.
@@@ hint
Initialise `TickType_t last = xTaskGetTickCount();` **once**, before the loop, then call `vTaskDelayUntil(&last, P)` at the top of each iteration. It sets `last += P`, blocks until that tick, and returns immediately if that tick has already passed.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

void       adc_sample(void);
TickType_t filter_cost(void);

static TickType_t g_period;

static void sampler_task(void *pv)
{
    TickType_t last = xTaskGetTickCount();   /* reference point: set ONCE */
    (void)pv;

    for (;;) {
        /* last += period, block until then (or return at once if already past) */
        vTaskDelayUntil(&last, g_period);
        adc_sample();
        vSimBusyWork(filter_cost());
    }
}

void app_start(TickType_t period)
{
    g_period = period;
    xTaskCreate(sampler_task, "sampler", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
}
@@@ explanation_md
**Approach.** `vTaskDelay(P)` is a *relative* delay: it blocks for `P` ticks counted from the moment it is called. The period of a loop `delay; sample; work` is therefore `P + work + preemption`, and the sampling instant drifts further away from the grid every cycle. With a filter cost of 3 and `P = 10`, the samples come at 10, 23, 36, 49, ... instead of 10, 20, 30, 40.

`vTaskDelayUntil(&last, P)` is an *absolute* delay. It keeps the previous planned wake-up time in `last`, advances it by exactly `P`, and blocks until that tick. Work and preemption only delay the sample in which they happen (jitter). They never shift later samples (no drift).

Overruns: if `last + P` has already passed when the task calls `vTaskDelayUntil()`, the call returns immediately (`xTaskDelayUntil()` returns `pdFALSE`). `last` still advances by only one period. For example, with `P = 10` and a first filter run of 25 ticks (t=10..35), grid points 20 and 30 are both missed. Samples 2 and 3 are taken back to back at t=35 and t=36 (catch-up). If catch-up is not wanted, compare the return value or the tick count and skip whole periods (see RTK-M-04).

**Complexity.** O(1) per period plus the delayed-list insertion. The worst-case lateness of a sample is the interference from higher-priority tasks plus any overrun of the previous filter work. It does not grow over time, which a relative delay cannot guarantee.

**Common mistakes**
- `vTaskDelay(P)`: accumulating drift. All tests with non-zero filter cost fail.
- Calling `last = xTaskGetTickCount()` **inside** the loop before `vTaskDelayUntil()`. That turns it back into a relative delay.
- Computing `vTaskDelay(P - cost)`. It ignores preemption and gives a negative (huge, because unsigned) delay on overruns.
- Using busy waiting on `xTaskGetTickCount()` instead of blocking. That starves lower-priority tasks and the idle task.

**Interview follow-ups**
- What does `xTaskDelayUntil()` return, and how would you count overruns with it?
- The tick counter wraps around after 2^32 ticks. Does `vTaskDelayUntil()` still work across the wrap? Why?
- How would you make the sampling itself jitter-free, independent of task scheduling? (A hardware timer triggers the ADC and DMA; the task only processes.)
- Which priority assignment rule would you use for a set of periodic tasks like this one (rate-monotonic)?
