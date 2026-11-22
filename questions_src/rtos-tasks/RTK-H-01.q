@@@ meta
id: RTK-H-01
topic: Tasks & Scheduling
difficulty: Hard
type: FUNCTION
title: Rate-Monotonic Priorities and Response-Time Analysis
tags: freertos, rate-monotonic, response-time-analysis, schedulability, vtaskdelayuntil, embedded, asked-in-automotive
@@@ statement_md
You are given a set of periodic tasks. Each task has a period `T` (its deadline is the end of the period) and a worst-case CPU cost `C`. Do two things:

1. **Run them** on FreeRTOS with **rate-monotonic** priorities: the shorter the period, the higher the priority.
2. **Predict** each task's worst-case response time with **response-time analysis** (RTA), before the scheduler starts.

The harness measures the real response times and compares them with your prediction.

```c
typedef struct {
    char       name[8];
    TickType_t period;   /* T = relative deadline */
    TickType_t cost;     /* C, executed with vSimBusyWork(C) */
} RtTask;

/* provided by the test harness */
void job_end(unsigned i);       /* call right after task i finished one job's work */

void       rm_start(const RtTask *set, unsigned n);
TickType_t rm_wcrt(const RtTask *set, unsigned n, unsigned i);
```

**`rm_start()`** is called before the scheduler starts. It creates one FreeRTOS task per entry (n <= 6) with rate-monotonic priorities. The shortest period gets priority **6**, the next one 5, and so on. Equal periods are ordered by index: the lower index gets the higher priority. Task `i` releases a job at t = 0, T, 2T, ... For each job it does `vSimBusyWork(cost)`, then `job_end(i)`, then waits for the next release with `vTaskDelayUntil()`.

**`rm_wcrt()`** returns the worst-case response time of task `i` under those priorities, using the RTA recurrence:

```
R(0)   = C_i + sum over higher-priority j of C_j
R(k+1) = C_i + sum over higher-priority j of ceil(R(k) / T_j) * C_j
```

Iterate until `R` stops changing (return it) or exceeds `T_i` (return **0** = unschedulable).

**How it is tested.** The hidden `main()` reads the task set, calls `rm_wcrt()` for every task and `rm_start()`, and runs the scheduler up to tick `D`. All tasks are released together at t = 0. That is the *critical instant*, so the response of each task's **first** job equals its worst case. The harness records the priority each task runs at, the response of its first job, and how many jobs missed their deadline. It also prints the utilisation.

The test sets avoid one corner case: a job's work ending exactly at the tick where a higher-priority job is released. In the simulator, that release preempts before the job can call `job_end()`.

**Input**
```
<n> <D>
<name> <T> <C>      (n lines)
```

**Example**
```
Input:
3 120
A 10 3
B 15 4
C 40 9

Output:
utilisation: 79.2%
A: prio=6 wcrt=3 first=3 misses=0
B: prio=5 wcrt=7 first=7 misses=0
C: prio=4 wcrt=26 first=26 misses=0
```
For C: R(0) = 9 + 3 + 4 = 16. Then R(1) = 9 + ceil(16/10)*3 + ceil(16/15)*4 = 9 + 6 + 8 = 23, and R(2) = 9 + ceil(23/10)*3 + ceil(23/15)*4 = 9 + 9 + 8 = 26. Finally R(3) = 9 + 9 + 8 = 26, which is stable.
@@@ constraints_md
- 1 <= n <= 6, 1 <= C <= T <= 200, 1 <= D <= 5000. Names are at most 7 characters.
- `rm_wcrt()` must not depend on running the scheduler (it is called before it starts).
- Stack size `configMINIMAL_STACK_SIZE` for every task.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

typedef struct {
    char       name[8];
    TickType_t period;
    TickType_t cost;
} RtTask;

void job_end(unsigned i);

static const RtTask *g_set;
static TickType_t g_release;   /* common release time of all tasks (t = 0) */

static void rt_task(void *pv)
{
    unsigned i = (unsigned)(uintptr_t)pv;
    TickType_t last = g_release;   /* NOT xTaskGetTickCount(): tasks first run at different ticks */
    for (;;) {
        vSimBusyWork(g_set[i].cost);
        job_end(i);
        vTaskDelayUntil(&last, g_set[i].period);
    }
}

void rm_start(const RtTask *set, unsigned n)
{
    unsigned i;
    g_set = set;
    g_release = xTaskGetTickCount();
    for (i = 0; i < n; i++) {
        /* TODO: rate-monotonic priority instead of a fixed one */
        xTaskCreate(rt_task, set[i].name, configMINIMAL_STACK_SIZE, (void *)(uintptr_t)i, 3, NULL);
    }
}

TickType_t rm_wcrt(const RtTask *set, unsigned n, unsigned i)
{
    /* TODO: response-time analysis */
    (void)set;
    (void)n;
    (void)i;
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

#define MAXT 6
static unsigned g_n;
static TickType_t g_T[MAXT];
static unsigned g_jobs[MAXT], g_misses[MAXT];
static int g_prio[MAXT];
static TickType_t g_first[MAXT];

void job_end(unsigned i)
{
    TickType_t now = xTaskGetTickCount();
    TickType_t release, resp;
    if (i >= g_n) return;
    release = (TickType_t)g_jobs[i] * g_T[i];
    resp = now - release;
    if (g_jobs[i] == 0) {
        g_first[i] = resp;
        g_prio[i] = (int)uxTaskPriorityGet(NULL);
    }
    if (resp > g_T[i]) g_misses[i]++;
    g_jobs[i]++;
}

/*USER_CODE*/

int main(void)
{
    static RtTask set[MAXT];
    static TickType_t wcrt[MAXT];
    unsigned D, i, T, C;
    double u = 0.0;

    if (scanf("%u %u", &g_n, &D) != 2 || g_n < 1 || g_n > MAXT) return 1;
    for (i = 0; i < g_n; i++) {
        if (scanf("%7s %u %u", set[i].name, &T, &C) != 3) return 1;
        set[i].period = (TickType_t)T;
        set[i].cost = (TickType_t)C;
        g_T[i] = (TickType_t)T;
        g_prio[i] = -1;
        u += (double)C / (double)T;
    }
    for (i = 0; i < g_n; i++) wcrt[i] = rm_wcrt(set, g_n, i);

    rm_start(set, g_n);
    vSimSetTickLimit((TickType_t)D);
    vTaskStartScheduler();

    printf("utilisation: %.1f%%\n", u * 100.0 + 1e-9);
    for (i = 0; i < g_n; i++) {
        printf("%s: prio=", set[i].name);
        if (g_prio[i] < 0) printf("?");
        else printf("%d", g_prio[i]);
        if (wcrt[i] == 0) printf(" wcrt=unschedulable");
        else printf(" wcrt=%u", (unsigned)wcrt[i]);
        if (g_jobs[i] == 0) printf(" first=none");
        else printf(" first=%u", (unsigned)g_first[i]);
        printf(" misses=%u\n", g_misses[i]);
    }
    return 0;
}
@@@ sample_input
3 120
A 10 3
B 15 4
C 40 9
@@@ sample_output
utilisation: 79.2%
A: prio=6 wcrt=3 first=3 misses=0
B: prio=5 wcrt=7 first=7 misses=0
C: prio=4 wcrt=26 first=26 misses=0
@@@ sample_input
3 180
L 9 4
M 12 4
N 30 6
@@@ sample_output
utilisation: 97.8%
L: prio=6 wcrt=4 first=4 misses=0
M: prio=5 wcrt=8 first=8 misses=0
N: prio=4 wcrt=unschedulable first=34 misses=3

@@@ hidden_input
3 210
X 30 6
Y 12 3
Z 7 2
@@@ hidden_output
utilisation: 73.6%
X: prio=4 wcrt=18 first=18 misses=0
Y: prio=5 wcrt=5 first=5 misses=0
Z: prio=6 wcrt=2 first=2 misses=0

@@@ hidden_input
3 156
F 4 1
G 6 2
H 13 3
@@@ hidden_output
utilisation: 81.4%
F: prio=6 wcrt=1 first=1 misses=0
G: prio=5 wcrt=3 first=3 misses=0
H: prio=4 wcrt=10 first=10 misses=0

@@@ hidden_input
3 200
P 20 5
Q 20 5
R 50 9
@@@ hidden_output
utilisation: 68.0%
P: prio=6 wcrt=5 first=5 misses=0
Q: prio=5 wcrt=10 first=10 misses=0
R: prio=4 wcrt=19 first=19 misses=0

@@@ hidden_input
1 9
K 3 1
@@@ hidden_output
utilisation: 33.3%
K: prio=6 wcrt=1 first=1 misses=0

@@@ hidden_input
2 72
L 9 4
M 12 4
@@@ hidden_output
utilisation: 77.8%
L: prio=6 wcrt=4 first=4 misses=0
M: prio=5 wcrt=8 first=8 misses=0

@@@ hidden_input
6 500
A 10 1
B 11 1
C 13 1
D 17 2
E 19 2
F 23 2
@@@ hidden_output
utilisation: 57.8%
A: prio=6 wcrt=1 first=1 misses=0
B: prio=5 wcrt=2 first=2 misses=0
C: prio=4 wcrt=3 first=3 misses=0
D: prio=3 wcrt=5 first=5 misses=0
E: prio=2 wcrt=7 first=7 misses=0
F: prio=1 wcrt=9 first=9 misses=0

@@@ hint
Sort the indices by `(period, index)`. The k-th task in that order (k = 0, 1, ...) gets priority `6 - k`. "Higher priority than task i" means: shorter period, or equal period and lower index.
@@@ hint
RTA in integer arithmetic: `ceil(a / b) = (a + b - 1) / b`. Start with `R = C_i + sum(C_j)` over higher-priority tasks. Loop: `next = C_i + sum(ceil(R / T_j) * C_j)`. If `next > T_i`, return 0. If `next == R`, return `R`. Otherwise set `R = next`. The sequence never decreases, so it terminates.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

typedef struct {
    char       name[8];
    TickType_t period;
    TickType_t cost;
} RtTask;

void job_end(unsigned i);

static const RtTask *g_set;
static TickType_t g_release;   /* common release time of all tasks (t = 0) */

/* j has a higher rate-monotonic priority than i */
static int higher(const RtTask *set, unsigned j, unsigned i)
{
    return set[j].period < set[i].period || (set[j].period == set[i].period && j < i);
}

static void rt_task(void *pv)
{
    unsigned i = (unsigned)(uintptr_t)pv;
    TickType_t last = g_release;   /* NOT xTaskGetTickCount(): tasks first run at different ticks */
    for (;;) {
        vSimBusyWork(g_set[i].cost);
        job_end(i);
        vTaskDelayUntil(&last, g_set[i].period);
    }
}

void rm_start(const RtTask *set, unsigned n)
{
    unsigned i, j, rank;
    g_set = set;
    g_release = xTaskGetTickCount();               /* scheduler not started yet: 0 */
    for (i = 0; i < n; i++) {
        rank = 0;                                  /* number of tasks above i */
        for (j = 0; j < n; j++)
            if (j != i && higher(set, j, i)) rank++;
        xTaskCreate(rt_task, set[i].name, configMINIMAL_STACK_SIZE,
                    (void *)(uintptr_t)i, (UBaseType_t)(6 - rank), NULL);
    }
}

TickType_t rm_wcrt(const RtTask *set, unsigned n, unsigned i)
{
    TickType_t r = set[i].cost, next;
    unsigned j;

    for (j = 0; j < n; j++)
        if (j != i && higher(set, j, i)) r += set[j].cost;

    for (;;) {
        if (r > set[i].period) return 0;           /* deadline cannot be met */
        next = set[i].cost;
        for (j = 0; j < n; j++)
            if (j != i && higher(set, j, i))
                next += ((r + set[j].period - 1) / set[j].period) * set[j].cost;
        if (next == r) return r;                   /* fixed point reached */
        r = next;
    }
}
@@@ explanation_md
**Approach.**

*Rate-monotonic assignment.* For independent periodic tasks with deadline = period, rate-monotonic (RM) is the **optimal fixed-priority assignment**: if any fixed priority order can meet all deadlines, RM can. The rank of task `i` is the number of tasks with a shorter period, or an equal period and a lower index. Its priority is `6 - rank`.

*Response-time analysis.* The worst case for task `i` happens when it is released together with all higher-priority tasks (the critical instant). Within a window of length `R`, a higher-priority task `j` is released `ceil(R / T_j)` times and steals `C_j` each time. So `R` is the smallest fixed point of `R = C_i + sum ceil(R / T_j) * C_j`. The iteration starts below the fixed point and increases monotonically, so it either converges or crosses the deadline.

*Why measurement matches.* The harness releases everything at t = 0, which is exactly the critical instant. The first job of each task therefore sees the worst interference, and its measured response equals the RTA value. Later jobs can only be faster or equal.

*Utilisation is not enough.* The second sample (L, M, N) has U = 97.8% < 100%, but N is unschedulable under RM: RTA returns 0 and the run shows deadline misses. U <= 100% is necessary. Liu & Layland's bound `n(2^(1/n) - 1)` (78% for n = 3) is only sufficient. RTA is the exact test.

**Complexity.** `rm_start`: O(n^2) to rank (n <= 6). `rm_wcrt`: O(n) per iteration, at most about `T_i / min(C)` iterations because `R` grows by at least one each step. Runtime: one context switch per preemption; no extra RAM.

**Common mistakes**
- Reversing the order (long period = high priority). Measured responses no longer match RTA, and short-period tasks miss deadlines.
- Using `R / T_j` (floor) instead of `ceil`. That underestimates interference: a job released at any time inside the window counts fully.
- Including task `i` itself or lower-priority tasks in the sum.
- Starting the iteration at `R = 0`. `ceil(0 / T) = 0`, so it stops immediately with `R = C_i`.
- Initialising the release time with `last = xTaskGetTickCount()` **inside each task**. Each task first runs at a different tick (Z at 0, Y at 2, X at 5), so their release grids are shifted. They are no longer released together, the critical instant never happens, and RTA and measurement disagree. Take one common reference time before the scheduler starts.
- Using `vTaskDelay(T)` in the task. The release times drift, and the harness's deadline check (based on the fixed grid) reports misses.

**Interview follow-ups**
- How do blocking times (shared resources with priority inheritance or ceiling) enter the RTA formula?
- Deadline < period: which assignment is optimal then (deadline-monotonic)?
- Why does the analysis assume no release jitter, and how would you add jitter?
- Your ECU has a 1 ms, 10 ms and 100 ms task. What happens to the 100 ms task when the 1 ms task overruns occasionally?
