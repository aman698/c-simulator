@@@ meta
id: RDS-H-03
topic: RTOS Design Patterns
difficulty: Hard
type: FUNCTION
title: AUTOSAR Style 1 10 100 ms Runnable Tasks With Overrun Detection
tags: freertos, autosar, rate-monotonic, overrun-detection, deadline-monitoring, embedded, asked-in-automotive
@@@ statement_md
An AUTOSAR-like ECU maps its runnables onto three periodic OS tasks: `Task_1ms`, `Task_10ms` and `Task_100ms`, with rate-monotonic priorities. Sometimes a runnable takes longer than planned (a spike), and an activation does not finish before its next release. Detect this **overrun**, report it, and **skip** the missed releases instead of running a burst of late catch-up activations.

```c
/* provided by the judge */
void run_runnables(int rate_ms, TickType_t release);
    /* executes the runnables of that rate for the activation released at 'release':
       keeps the CPU busy for the configured cost (it is preempted by higher-priority tasks) */
void report_overrun(int rate_ms, TickType_t release, TickType_t finish, unsigned skipped);
    /* prints "[t=<tick>] OVERRUN <rate>ms release=<release> finish=<finish> skipped=<skipped>" */

/* you write this (and the task code) */
void os_start(void);   /* called before the scheduler starts */
```

`os_start()` creates three tasks:

| Task | Period P | Priority |
|---|---|---|
| `Task_1ms` | 1 | 6 |
| `Task_10ms` | 10 | 5 |
| `Task_100ms` | 100 | 4 |

The releases of a task are at multiples of its period: `0, P, 2P, ...`. For each activation, the task calls `run_runnables(P, release)`. When it returns, at tick `finish`:

- if `finish <= release + P`, the deadline is met, and the next release is `release + P` (possibly "now", in which case the task continues at once);
- otherwise it is an **overrun**. The next release is the **first multiple of P that is >= finish**. The releases in between are skipped. Call `report_overrun(P, release, finish, skipped)` with `skipped` = the number of skipped releases, then wait for the next release.

Releases must be computed from the period grid (no drift), and a task must block until its next release (`vTaskDelay`/`xTaskDelayUntil`, no polling).

**How it is tested.** The input gives the base cost of each rate (ticks of CPU per activation) and a list of spikes: extra cost for the activation of one rate released at one specific tick. The judge checks that every `release` is on the grid, later than the previous one, not in the future, and that `run_runnables()` runs at the right priority. It runs the scheduler up to tick `D` and then prints, for each rate, the number of activations, the number of reported overruns, and the number of releases that were really skipped (gaps on the grid).

Ordinary code takes zero time, so `Task_1ms` with cost 0 runs at every tick without disturbing anyone. CPU time only passes inside `run_runnables()`, where higher-priority tasks preempt lower ones.

**Input**
```
<cost_1ms> <cost_10ms> <cost_100ms> <D>
<s>
<rate_ms> <release_tick> <extra_cost>       (s spike lines)
```

**Example**
```
Input:
0 2 30 255
1
10 30 9

Output:
[t=41] OVERRUN 10ms release=30 finish=41 skipped=1
1ms: activations=256 overruns=0 skipped=0
10ms: activations=25 overruns=1 skipped=1
100ms: activations=3 overruns=0 skipped=0
```
The 10 ms activation released at 30 costs 2+9 = 11 ticks and finishes at 41, after its deadline of 40. The release at 40 is skipped, and the next activation is released at 50. `Task_100ms` (released at 0, 30 ticks of work) is preempted by every 10 ms activation and finishes at t=47, well within its period.
@@@ constraints_md
- `cost_1ms` is 0 (one tick is the whole 1 ms period). 0 <= cost_10ms <= 9, 0 <= cost_100ms <= 200, 1 <= D <= 3000, 0 <= s <= 10, 0 <= extra_cost <= 300.
- Spike release ticks are multiples of their rate's period. A spike on a release that is skipped has no effect.
- Use exactly the priorities in the table. Stack `configMINIMAL_STACK_SIZE`.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"

void run_runnables(int rate_ms, TickType_t release);
void report_overrun(int rate_ms, TickType_t release, TickType_t finish, unsigned skipped);

static void os_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: run the activation, detect overruns, compute the next release, block until it */
        vTaskDelay(1000);
    }
}

void os_start(void)
{
    /* TODO: create Task_1ms (prio 6), Task_10ms (prio 5), Task_100ms (prio 4) */
    (void)os_task;
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

typedef struct { unsigned rate, release, extra; } Spike;

static unsigned g_cost[3];
static Spike g_spike[10];
static int g_ns;
static unsigned g_act[3], g_ovr[3], g_gap[3];
static TickType_t g_prev[3];
static int g_started[3];
static int g_fail;

static int rate_index(int rate_ms)
{
    return rate_ms == 1 ? 0 : rate_ms == 10 ? 1 : rate_ms == 100 ? 2 : -1;
}

static void fail(const char *msg, int rate_ms)
{
    if (!g_fail) printf("[t=%u] FAIL: %s (%dms)\n", (unsigned)xTaskGetTickCount(), msg, rate_ms);
    g_fail = 1;
}

void run_runnables(int rate_ms, TickType_t release)
{
    static const UBaseType_t k_prio[3] = { 6, 5, 4 };
    int r = rate_index(rate_ms), k;
    TickType_t now = xTaskGetTickCount();
    unsigned cost;

    if (r < 0) { fail("unknown rate", rate_ms); return; }
    if (uxTaskPriorityGet(NULL) != k_prio[r]) { fail("wrong task priority", rate_ms); return; }
    if (release % (TickType_t)rate_ms != 0) { fail("release not on the period grid", rate_ms); return; }
    if (release > now) { fail("release in the future", rate_ms); return; }
    if (g_started[r]) {
        if (release <= g_prev[r]) { fail("release not increasing", rate_ms); return; }
        g_gap[r] += (unsigned)((release - g_prev[r]) / (TickType_t)rate_ms) - 1u;
    } else {
        g_gap[r] += (unsigned)(release / (TickType_t)rate_ms);
        g_started[r] = 1;
    }
    g_prev[r] = release;
    g_act[r]++;

    cost = g_cost[r];
    for (k = 0; k < g_ns; k++)
        if (g_spike[k].rate == (unsigned)rate_ms && g_spike[k].release == (unsigned)release) cost += g_spike[k].extra;
    vSimBusyWork((TickType_t)cost);
}

void report_overrun(int rate_ms, TickType_t release, TickType_t finish, unsigned skipped)
{
    int r = rate_index(rate_ms);

    printf("[t=%u] OVERRUN %dms release=%u finish=%u skipped=%u\n", (unsigned)xTaskGetTickCount(),
           rate_ms, (unsigned)release, (unsigned)finish, skipped);
    if (r >= 0) g_ovr[r]++;
}

/*USER_CODE*/

int main(void)
{
    static const char *const k_name[3] = { "1ms", "10ms", "100ms" };
    unsigned dur;
    int i;

    if (scanf("%u %u %u %u %d", &g_cost[0], &g_cost[1], &g_cost[2], &dur, &g_ns) != 5) return 1;
    if (g_ns < 0 || g_ns > 10) return 1;
    for (i = 0; i < g_ns; i++)
        if (scanf("%u %u %u", &g_spike[i].rate, &g_spike[i].release, &g_spike[i].extra) != 3) return 1;

    os_start();
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    for (i = 0; i < 3; i++)
        printf("%s: activations=%u overruns=%u skipped=%u\n", k_name[i], g_act[i], g_ovr[i], g_gap[i]);
    return 0;
}
@@@ sample_input
0 2 30 255
1
10 30 9
@@@ sample_output
[t=41] OVERRUN 10ms release=30 finish=41 skipped=1
1ms: activations=256 overruns=0 skipped=0
10ms: activations=25 overruns=1 skipped=1
100ms: activations=3 overruns=0 skipped=0
@@@ sample_input
0 6 50 415
0
@@@ sample_output
[t=128] OVERRUN 100ms release=0 finish=128 skipped=1
[t=328] OVERRUN 100ms release=200 finish=328 skipped=1
1ms: activations=416 overruns=0 skipped=0
10ms: activations=42 overruns=0 skipped=0
100ms: activations=3 overruns=2 skipped=2
@@@ hidden_input
0 0 0 99
0
@@@ hidden_output
1ms: activations=100 overruns=0 skipped=0
10ms: activations=10 overruns=0 skipped=0
100ms: activations=1 overruns=0 skipped=0
@@@ hidden_input
0 3 40 305
2
1 50 3
10 50 5
@@@ hidden_output
[t=53] OVERRUN 1ms release=50 finish=53 skipped=2
[t=61] OVERRUN 10ms release=50 finish=61 skipped=1
1ms: activations=304 overruns=1 skipped=2
10ms: activations=30 overruns=1 skipped=1
100ms: activations=4 overruns=0 skipped=0

@@@ hidden_input
0 8 25 505
0
@@@ hidden_output
[t=129] OVERRUN 100ms release=0 finish=129 skipped=1
[t=329] OVERRUN 100ms release=200 finish=329 skipped=1
1ms: activations=506 overruns=0 skipped=0
10ms: activations=51 overruns=0 skipped=0
100ms: activations=3 overruns=2 skipped=2

@@@ hidden_input
0 1 100 1005
3
100 100 0
100 300 1
10 590 17
@@@ hidden_output
[t=112] OVERRUN 100ms release=0 finish=112 skipped=1
[t=312] OVERRUN 100ms release=200 finish=312 skipped=1
[t=512] OVERRUN 100ms release=400 finish=512 skipped=1
[t=608] OVERRUN 10ms release=590 finish=608 skipped=1
[t=719] OVERRUN 100ms release=600 finish=719 skipped=1
[t=912] OVERRUN 100ms release=800 finish=912 skipped=1
1ms: activations=1006 overruns=0 skipped=0
10ms: activations=100 overruns=1 skipped=1
100ms: activations=6 overruns=5 skipped=5

@@@ hidden_input
0 2 81 2995
4
1 7 25
10 1000 20
10 1020 9
100 2000 300
@@@ hidden_output
[t=32] OVERRUN 1ms release=7 finish=32 skipped=24
[t=34] OVERRUN 10ms release=10 finish=34 skipped=2
[t=128] OVERRUN 100ms release=0 finish=128 skipped=1
[t=303] OVERRUN 100ms release=200 finish=303 skipped=1
[t=503] OVERRUN 100ms release=400 finish=503 skipped=1
[t=703] OVERRUN 100ms release=600 finish=703 skipped=1
[t=903] OVERRUN 100ms release=800 finish=903 skipped=1
[t=1022] OVERRUN 10ms release=1000 finish=1022 skipped=2
[t=1123] OVERRUN 100ms release=1000 finish=1123 skipped=1
[t=1303] OVERRUN 100ms release=1200 finish=1303 skipped=1
[t=1503] OVERRUN 100ms release=1400 finish=1503 skipped=1
[t=1703] OVERRUN 100ms release=1600 finish=1703 skipped=1
[t=1903] OVERRUN 100ms release=1800 finish=1903 skipped=1
[t=2477] OVERRUN 100ms release=2000 finish=2477 skipped=4
[t=2603] OVERRUN 100ms release=2500 finish=2603 skipped=1
[t=2803] OVERRUN 100ms release=2700 finish=2803 skipped=1
1ms: activations=2972 overruns=1 skipped=24
10ms: activations=296 overruns=2 skipped=4
100ms: activations=14 overruns=13 skipped=16

@@@ hidden_input
0 5 0 155
2
10 100 15
1 133 1
@@@ hidden_output
[t=120] OVERRUN 10ms release=100 finish=120 skipped=1
1ms: activations=156 overruns=0 skipped=0
10ms: activations=15 overruns=1 skipped=1
100ms: activations=2 overruns=0 skipped=0

@@@ hint
Keep the release time of the current activation in a local variable (start at 0). After `run_runnables()` returns, compare `now = xTaskGetTickCount()` with `release + P`. On an overrun, the next release is `((now + P - 1) / P) * P`, and `skipped = (next - release) / P - 1`.
@@@ hint
One task function for all three rates, with a small `{period, priority}` config passed through `pvParameters`. Block with `vTaskDelay(next - now)` when `next > now` (or set `last = next - P` and call `xTaskDelayUntil(&last, P)`). Do **not** simply loop on `xTaskDelayUntil(&last, P)`: after an overrun it returns immediately for every missed period, which is exactly the catch-up burst you must avoid.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"

void run_runnables(int rate_ms, TickType_t release);
void report_overrun(int rate_ms, TickType_t release, TickType_t finish, unsigned skipped);

typedef struct {
    const char *name;
    TickType_t  period;
    UBaseType_t priority;
} OsTaskCfg;

static const OsTaskCfg s_cfg[3] = {
    { "Task_1ms",   1,   6 },
    { "Task_10ms",  10,  5 },
    { "Task_100ms", 100, 4 },
};

static void os_task(void *pvParameters)
{
    const OsTaskCfg *c = (const OsTaskCfg *)pvParameters;
    const TickType_t P = c->period;
    TickType_t release = 0;

    for (;;) {
        TickType_t now, next;

        run_runnables((int)P, release);
        now = xTaskGetTickCount();
        if (now <= release + P) {
            next = release + P;                       /* deadline met */
        } else {
            next = ((now + P - 1) / P) * P;           /* first grid point >= finish */
            report_overrun((int)P, release, now, (unsigned)((next - release) / P - 1));
        }
        release = next;
        if (next > now) vTaskDelay(next - now);       /* absolute grid: no drift */
    }
}

void os_start(void)
{
    int i;

    for (i = 0; i < 3; i++) {
        xTaskCreate(os_task, s_cfg[i].name, configMINIMAL_STACK_SIZE,
                    (void *)&s_cfg[i], s_cfg[i].priority, NULL);
    }
}
@@@ explanation_md
**Approach.** Every OS task runs the same loop: run the activation, measure the finish tick, compare it with the deadline `release + P`, and compute the next release **on the period grid**. The release time is an absolute value derived from the grid, not from "now plus period", so there is no drift. `vTaskDelay(next - now)` executes in zero simulated time right after `now` is read, so it lands exactly on `next`. On an overrun, the next release is rounded **up** to the grid. All releases in between are dropped and reported in one `OVERRUN` line. That is AUTOSAR's usual policy (the OS rejects the extra activations, `E_OS_LIMIT`, and a timing-protection hook reports them). It keeps the schedule aligned with the other ECUs and avoids a burst of stale work.

Rate-monotonic priorities make the effect of a spike local. In the example, the 10 ms spike delays only the 10 ms task (and the 100 ms task, which simply has more slack). Sample 2 shows a structural overload: with 6 ticks of every 10 used by `Task_10ms`, `Task_100ms` only gets 4 ticks per 10. Its 50 ticks of work need 128 ticks, so every second 100 ms release is skipped.

**Complexity.** Per activation: O(1) bookkeeping (one division on an overrun). RAM: three TCBs and stacks plus a constant config table. CPU utilisation U = c1/1 + c10/10 + c100/100. The Liu & Layland bound for 3 tasks is about 0.78: below it, rate-monotonic scheduling guarantees that every deadline is met. Sample 2 has U = 0.6 + 0.5 = 1.1 > 1, so overruns are unavoidable.

**Common mistakes**
- Looping on `xTaskDelayUntil(&last, P)` without resynchronising: after an overrun it returns at once for every missed period (catch-up burst), and the judge sees releases in the past back-to-back.
- `vTaskDelay(P)` after the work: the period becomes P + execution time (drift).
- Using `finish > release + P` with an off-by-one (`>=`): finishing exactly at the next release is **not** an overrun.
- Rounding the next release with `now / P * P + P`: when `finish` is exactly on the grid, a release is skipped that could have run.
- Reversed priorities (100 ms highest): the 10 ms and 1 ms tasks then overrun whenever the 100 ms task runs.

**Interview follow-ups**
- How would you measure the actual execution time and worst-case response time of each task (trace hooks, `configGENERATE_RUN_TIME_STATS`)?
- AUTOSAR OS timing protection: how do execution budgets and inter-arrival times differ from the deadline check here?
- What would you do instead of skipping, for a control loop that needs every sample (catch up once, degrade, or report to the mode manager)?
- How does the picture change with a dual-core ECU and runnables mapped to both cores?
