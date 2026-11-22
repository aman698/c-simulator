@@@ meta
id: RTK-M-04
topic: Tasks & Scheduling
difficulty: Medium
type: FUNCTION
title: Hand-Written Periodic Wait That Skips Missed Periods
tags: freertos, periodic-task, overrun, vtaskdelay, tick-arithmetic, embedded, asked-in-automotive
@@@ statement_md
`vTaskDelayUntil()` keeps a fixed grid but **catches up** after an overrun: every missed period is executed late, back to back. A motor-control loop must not do that. Running three stale control cycles in a row is worse than skipping them. Write your own periodic wait **without** `vTaskDelayUntil()` / `xTaskDelayUntil()`. It keeps the grid `t0 + k*P` and **skips** grid points that have already passed.

```c
typedef struct {
    TickType_t next;     /* next grid point to run at */
    TickType_t period;
} PeriodicTimer;

void     periodic_init(PeriodicTimer *pt, TickType_t period);
unsigned periodic_wait(PeriodicTimer *pt);
```

- `periodic_init()` is called once, at `t0 = xTaskGetTickCount()`. The first grid point is `t0 + period`.
- `periodic_wait()` blocks until the next grid point and returns the number of grid points it had to **skip**:
  - If the next grid point is now or in the future, block until it (do not block if it is now) and return 0.
  - If it is already in the past, skip forward to the first grid point that is `>=` now. Block until it and return how many grid points were skipped.
  - In both cases, afterwards `next` is the grid point after the one just waited for.

**How it is tested.** The hidden control task (priority 2) runs:

```c
periodic_init(&pt, P);
for (k = 1;; k++) {
    skipped = periodic_wait(&pt);
    log_run(k, skipped);          /* "[t=<tick>] run <k> skipped <n>", OFF-GRID if not on the grid */
    vSimBusyWork(cost_k);         /* costs from the input, used cyclically */
}
```

The run ends at tick `D`. Then the harness prints the number of runs and the total number of skipped grid points. `vTaskDelayUntil` and `xTaskDelayUntil` are not available (compile error).

**Input**
```
<P> <D>
<n> <cost 1> ... <cost n>
```

**Example**
```
Input:
10 80
3 3 25 4

Output:
[t=10] run 1 skipped 0
[t=20] run 2 skipped 0
[t=50] run 3 skipped 2
[t=60] run 4 skipped 0
[t=70] run 5 skipped 0
runs: 5
skipped: 2
```
Run 2 starts at t=20 and its 25 ticks of work end at t=45. Grid points 30 and 40 have passed, so they are skipped. The next run waits for t=50. `vTaskDelayUntil()` would instead have run immediately at t=45 and t=46.
@@@ constraints_md
- 1 <= P <= 100, 1 <= D <= 5000, 1 <= n <= 10, 0 <= cost <= 300.
- The task must **block** while waiting (no busy loop on `xTaskGetTickCount()`).
- No tick wrap-around happens in the tests, but your arithmetic should be written in a wrap-safe way (see the explanation).
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"

typedef struct {
    TickType_t next;
    TickType_t period;
} PeriodicTimer;

void periodic_init(PeriodicTimer *pt, TickType_t period)
{
    pt->period = period;
    pt->next = xTaskGetTickCount() + period;
}

unsigned periodic_wait(PeriodicTimer *pt)
{
    /* TODO: this version ignores overruns */
    TickType_t now = xTaskGetTickCount();
    if (pt->next > now) vTaskDelay(pt->next - now);
    pt->next += pt->period;
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

#undef vTaskDelayUntil
#define vTaskDelayUntil(a, b) vTaskDelayUntil_is_not_allowed_here
#define xTaskDelayUntil(a, b) xTaskDelayUntil_is_not_allowed_here
/*USER_CODE*/
#undef vTaskDelayUntil
#undef xTaskDelayUntil

static TickType_t g_P, g_t0;
static unsigned g_ncost;
static TickType_t g_cost[10];
static unsigned g_runs, g_skipped;

static void log_run(unsigned k, unsigned skipped)
{
    TickType_t now = xTaskGetTickCount();
    g_runs++;
    g_skipped += skipped;
    printf("[t=%u] run %u skipped %u%s\n", (unsigned)now, k, skipped,
           ((now - g_t0) % g_P == 0 && now != g_t0) ? "" : " OFF-GRID");
}

static void control_task(void *pv)
{
    PeriodicTimer pt;
    unsigned k;
    (void)pv;
    g_t0 = xTaskGetTickCount();
    periodic_init(&pt, g_P);
    for (k = 1;; k++) {
        unsigned s = periodic_wait(&pt);
        log_run(k, s);
        vSimBusyWork(g_cost[(k - 1) % g_ncost]);
    }
}

int main(void)
{
    unsigned P, D, i, c;
    if (scanf("%u %u", &P, &D) != 2) return 1;
    if (scanf("%u", &g_ncost) != 1 || g_ncost < 1 || g_ncost > 10) return 1;
    for (i = 0; i < g_ncost; i++) {
        if (scanf("%u", &c) != 1) return 1;
        g_cost[i] = (TickType_t)c;
    }
    g_P = (TickType_t)P;
    xTaskCreate(control_task, "ctrl", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
    vSimSetTickLimit((TickType_t)D);
    vTaskStartScheduler();
    printf("runs: %u\n", g_runs);
    printf("skipped: %u\n", g_skipped);
    return 0;
}
@@@ sample_input
10 80
3 3 25 4
@@@ sample_output
[t=10] run 1 skipped 0
[t=20] run 2 skipped 0
[t=50] run 3 skipped 2
[t=60] run 4 skipped 0
[t=70] run 5 skipped 0
runs: 5
skipped: 2
@@@ sample_input
10 70
2 20 1
@@@ sample_output
[t=10] run 1 skipped 0
[t=30] run 2 skipped 1
[t=40] run 3 skipped 0
[t=60] run 4 skipped 1
[t=70] run 5 skipped 0
runs: 5
skipped: 2
@@@ hidden_input
5 30
1 0
@@@ hidden_output
[t=5] run 1 skipped 0
[t=10] run 2 skipped 0
[t=15] run 3 skipped 0
[t=20] run 4 skipped 0
[t=25] run 5 skipped 0
[t=30] run 6 skipped 0
runs: 6
skipped: 0
@@@ hidden_input
10 60
1 10
@@@ hidden_output
[t=10] run 1 skipped 0
[t=20] run 2 skipped 0
[t=30] run 3 skipped 0
[t=40] run 4 skipped 0
[t=50] run 5 skipped 0
[t=60] run 6 skipped 0
runs: 6
skipped: 0
@@@ hidden_input
7 100
1 50
@@@ hidden_output
[t=7] run 1 skipped 0
[t=63] run 2 skipped 7
runs: 2
skipped: 7
@@@ hidden_input
1 10
1 0
@@@ hidden_output
[t=1] run 1 skipped 0
[t=2] run 2 skipped 0
[t=3] run 3 skipped 0
[t=4] run 4 skipped 0
[t=5] run 5 skipped 0
[t=6] run 6 skipped 0
[t=7] run 7 skipped 0
[t=8] run 8 skipped 0
[t=9] run 9 skipped 0
[t=10] run 10 skipped 0
runs: 10
skipped: 0
@@@ hidden_input
3 40
3 2 5 8
@@@ hidden_output
[t=3] run 1 skipped 0
[t=6] run 2 skipped 0
[t=12] run 3 skipped 1
[t=21] run 4 skipped 2
[t=24] run 5 skipped 0
[t=30] run 6 skipped 1
[t=39] run 7 skipped 2
runs: 7
skipped: 6
@@@ hint
Compute `late = now - pt->next` with unsigned `TickType_t` arithmetic and interpret it as signed (`(int32_t)late > 0` means the grid point has passed). Never compare `now > next` directly: that breaks when the tick counter wraps.
@@@ hint
Number of grid points to skip when late: `ceil(late / P) = (late + P - 1) / P`. Advance `next` by that many periods, then `vTaskDelay(next - now)` if it is not zero, and finally `next += P`.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

typedef struct {
    TickType_t next;
    TickType_t period;
} PeriodicTimer;

void periodic_init(PeriodicTimer *pt, TickType_t period)
{
    pt->period = period;
    pt->next = xTaskGetTickCount() + period;
}

unsigned periodic_wait(PeriodicTimer *pt)
{
    TickType_t now = xTaskGetTickCount();
    TickType_t late = now - pt->next;          /* wraps correctly: modulo 2^32 */
    unsigned skipped = 0;

    if ((int32_t)late > 0) {                   /* grid point already passed */
        skipped = (unsigned)((late + pt->period - 1) / pt->period);
        pt->next += (TickType_t)skipped * pt->period;
    }
    if (pt->next != now)
        vTaskDelay(pt->next - now);            /* block, never busy-wait */
    pt->next += pt->period;
    return skipped;
}
@@@ explanation_md
**Approach.** Keep the *planned* time of the next run (`next`), never the time the task actually woke up. That is what makes the loop drift-free. At each wait:

1. `late = now - next`, computed in unsigned tick arithmetic. Read as a signed number, `late <= 0` means the grid point is now or in the future, and `late > 0` means it has passed.
2. If late, skip `ceil(late / P)` grid points. That is the smallest number of periods that brings `next` to `>= now`. In the example, `next = 30` and `now = 45`, so `ceil(15 / 10) = 2`, and `next` becomes 50.
3. Block with a relative `vTaskDelay(next - now)`. Because `next` is absolute, the relative delay is recomputed from the current time every cycle, and no error accumulates.
4. Advance `next` by one period for the following call.

**Why the signed difference?** `TickType_t` wraps from `0xFFFFFFFF` to 0 (after about 49.7 days at 1 kHz). `now > next` gives the wrong answer right after a wrap. `(int32_t)(now - next) > 0` is correct as long as the two times are less than 2^31 ticks apart. The kernel itself uses the same idea.

**Complexity.** O(1) per call: one division in the overrun case. No extra RAM except the two-field struct.

**Common mistakes**
- Catching up (running immediately when late) instead of skipping. That is what `vTaskDelayUntil()` does, and it is what this question forbids.
- `pt->next = now + P` after each wait. That turns the loop back into a relative delay that drifts with the work time.
- Off-by-one in the skip count: using `late / P` (floor) leaves `next` in the past when `late` is not a multiple of `P`. Waiting for a grid point that is exactly *now* must not skip it (second hidden test: work of exactly one period).
- `vTaskDelay(next - now)` when `next` is in the past: the unsigned subtraction becomes a huge delay, about 49 days.
- Comparing ticks with `<` / `>` instead of signed differences.

**Interview follow-ups**
- How would you report the overruns to a diagnostic monitor (DTC) without disturbing the control timing?
- Catch-up vs skip: which one do you want for a data logger, and which for a PWM/motor control loop? Why?
- What changes if the period is not an integer number of ticks (e.g. 2.5 ms at a 1 kHz tick)?
- Why is a hardware timer interrupt plus a task notification often preferred for hard real-time control loops?
