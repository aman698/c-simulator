@@@ meta
id: RDS-M-03
topic: RTOS Design Patterns
difficulty: Medium
type: FUNCTION
title: Heartbeat Health Monitor Feeding The Hardware Watchdog
tags: freertos, watchdog, heartbeat, event-groups, health-monitoring, embedded, asked-in-automotive
@@@ statement_md
Kicking the hardware watchdog from a timer or from the idle task only proves that *something* still runs. A safety-relevant ECU must prove that **every** task is alive. Write a **health monitor**: every worker task checks in regularly, and the monitor kicks the watchdog only when all workers have checked in during the last window.

```c
/* provided by the judge */
void wdg_kick(void);                    /* refresh the hardware watchdog (only the monitor may call it) */
void health_report(int id, int alive);  /* prints "[t=<tick>] W<id> MISSING" (alive=0) or "... RECOVERED" (alive=1) */

/* you write these */
void health_start(int n_workers, TickType_t window); /* called before the scheduler starts */
void health_checkin(int id);                         /* called by worker id (0..n_workers-1), task context */
```

- `health_start()` creates the shared check-in state and a monitor task named `"MON"`, priority **5**.
- `health_checkin(id)` records that worker `id` is alive. Workers call it at any time, from tasks of different priorities.
- The monitor runs at exactly `window`, `2*window`, `3*window`, ... At each run it takes the set of workers that checked in **since its previous run** and clears it in **one atomic step**, so that no check-in can be lost between "read" and "clear". Then:
  - for each worker in increasing `id` order: if it was healthy and did not check in, call `health_report(id, 0)`. If it was missing and did check in, call `health_report(id, 1)`. All workers start healthy;
  - if **all** workers checked in, call `wdg_kick()`; otherwise do not kick.

The monitor has a higher priority than every worker. A check-in at the same tick as a monitor run therefore counts for the **next** window.

**How it is tested.** The judge creates `n` worker tasks. Worker `i` loops: `vTaskDelay(period_i)`, then, if a fault of this worker is active (`from <= now < to`), it misbehaves until `to`, then calls `health_checkin(i)`. A `HANG` fault blocks the worker (deadlocked on a resource). A `HOG` fault makes it spin on the CPU, which also starves every lower-priority worker. The judge's hardware watchdog (a task with priority 6) expires at `last_kick + T` unless the monitor kicks it before that tick (the first deadline is `T`). When it expires, it prints `[t=<tick>] WATCHDOG RESET` once. At tick `D` the judge prints the number of kicks and the check-ins of every worker. `T` is never a multiple of `window`.

**Input**
```
<n> <window> <T> <D>
<period> <priority>          (n lines: worker 0, 1, ...; priorities 1..4, distinct)
<f>
<HANG|HOG> <id> <from> <to>  (f lines)
```

**Example**
```
Input:
2 10 25 95
3 2
7 1
1
HANG 1 20 45

Output:
[t=30] W1 MISSING
[t=45] WATCHDOG RESET
[t=50] W1 RECOVERED
kicks=7
W0 checkins=31
W1 checkins=10
```
Worker 1 checks in at 7 and 14. It wakes at 21 inside its fault and stays blocked until 45. The window [20,30) has no check-in from it, so it is reported at t=30, and the monitor stops kicking. The last kick was at t=20, so the watchdog expires at t=45. The check-in at 45 falls in [40,50), and worker 1 recovers at t=50. Kicks: 10, 20, 50, 60, 70, 80, 90.
@@@ constraints_md
- 1 <= n <= 4, 2 <= window <= 100, 1 <= T <= 1000, 1 <= D <= 5000, 1 <= period <= 100, 0 <= f <= 6, 0 <= from < to <= D.
- Monitor: name `"MON"`, priority 5, stack `configMINIMAL_STACK_SIZE`. Release times must not drift.
- `wdg_kick()` and `health_report()` must only be called by the monitor (the judge prints `FAIL` otherwise).
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"

void wdg_kick(void);
void health_report(int id, int alive);

static void monitor_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: every window: atomically read+clear the check-ins, report changes, kick if all alive */
        vTaskDelay(1000);
    }
}

void health_start(int n_workers, TickType_t window)
{
    /* TODO: create the shared state and the "MON" task (priority 5) */
    (void)n_workers;
    (void)window;
    (void)monitor_task;
}

void health_checkin(int id)
{
    /* TODO */
    (void)id;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"
#include "sim.h"

static TaskHandle_t g_wdg;
static unsigned g_kicks;
static int g_fail;

static int from_monitor(const char *api)
{
    const char *who = pcTaskGetName(NULL);
    if (strcmp(who, "MON") == 0) return 1;
    if (!g_fail) printf("FAIL: %s() called from task \"%s\"\n", api, who);
    g_fail = 1;
    return 0;
}

void wdg_kick(void)
{
    if (!from_monitor("wdg_kick")) return;
    g_kicks++;
    if (g_wdg != NULL) xTaskNotifyGive(g_wdg);
}

void health_report(int id, int alive)
{
    if (!from_monitor("health_report")) return;
    printf("[t=%u] W%d %s\n", (unsigned)xTaskGetTickCount(), id, alive ? "RECOVERED" : "MISSING");
}

/*USER_CODE*/

typedef struct { int hog; int id; unsigned from, to; } Fault;

static int g_n, g_nf;
static unsigned g_period[4], g_prio[4], g_checkins[4];
static Fault g_fault[6];
static TickType_t g_T;

static void watchdog_task(void *p)
{
    (void)p;
    for (;;) {
        if (ulTaskNotifyTake(pdTRUE, g_T) == 0) {
            printf("[t=%u] WATCHDOG RESET\n", (unsigned)xTaskGetTickCount());
            g_wdg = NULL;
            vTaskDelete(NULL);
        }
    }
}

static void worker_task(void *p)
{
    int id = (int)(intptr_t)p, k;

    for (;;) {
        vTaskDelay((TickType_t)g_period[id]);
        for (k = 0; k < g_nf; k++) {
            TickType_t now = xTaskGetTickCount();
            if (g_fault[k].id == id && g_fault[k].from <= now && now < g_fault[k].to) {
                if (g_fault[k].hog) vSimBusyWork((TickType_t)g_fault[k].to - now);
                else vTaskDelay((TickType_t)g_fault[k].to - now);
            }
        }
        g_checkins[id]++;
        health_checkin(id);
    }
}

int main(void)
{
    unsigned window, T, dur;
    char kind[8];
    int i;

    if (scanf("%d %u %u %u", &g_n, &window, &T, &dur) != 4 || g_n < 1 || g_n > 4) return 1;
    for (i = 0; i < g_n; i++)
        if (scanf("%u %u", &g_period[i], &g_prio[i]) != 2) return 1;
    if (scanf("%d", &g_nf) != 1 || g_nf < 0 || g_nf > 6) return 1;
    for (i = 0; i < g_nf; i++) {
        if (scanf("%7s %d %u %u", kind, &g_fault[i].id, &g_fault[i].from, &g_fault[i].to) != 4) return 1;
        g_fault[i].hog = strcmp(kind, "HOG") == 0;
    }
    g_T = (TickType_t)T;

    health_start(g_n, (TickType_t)window);
    xTaskCreate(watchdog_task, "WDG", configMINIMAL_STACK_SIZE, NULL, 6, &g_wdg);
    for (i = 0; i < g_n; i++) {
        char name[8];
        snprintf(name, sizeof name, "W%d", i);
        xTaskCreate(worker_task, name, configMINIMAL_STACK_SIZE, (void *)(intptr_t)i, (UBaseType_t)g_prio[i], NULL);
    }
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("kicks=%u\n", g_kicks);
    for (i = 0; i < g_n; i++) printf("W%d checkins=%u\n", i, g_checkins[i]);
    return 0;
}
@@@ sample_input
2 10 25 95
3 2
7 1
1
HANG 1 20 45
@@@ sample_output
[t=30] W1 MISSING
[t=45] WATCHDOG RESET
[t=50] W1 RECOVERED
kicks=7
W0 checkins=31
W1 checkins=10
@@@ sample_input
3 10 15 75
5 3
4 2
6 1
1
HOG 0 30 52
@@@ sample_output
[t=40] W0 MISSING
[t=40] W1 MISSING
[t=40] W2 MISSING
[t=45] WATCHDOG RESET
[t=60] W0 RECOVERED
[t=60] W1 RECOVERED
[t=60] W2 RECOVERED
kicks=5
W0 checkins=10
W1 checkins=13
W2 checkins=8
@@@ hidden_input
1 5 12 52
1 1
0
@@@ hidden_output
kicks=10
W0 checkins=52
@@@ hidden_input
2 10 35 205
4 1
15 2
0
@@@ hidden_output
[t=10] W1 MISSING
[t=20] W1 RECOVERED
[t=30] W1 MISSING
[t=40] W1 RECOVERED
[t=60] W1 MISSING
[t=70] W1 RECOVERED
[t=90] W1 MISSING
[t=100] W1 RECOVERED
[t=120] W1 MISSING
[t=130] W1 RECOVERED
[t=150] W1 MISSING
[t=160] W1 RECOVERED
[t=180] W1 MISSING
[t=190] W1 RECOVERED
kicks=13
W0 checkins=51
W1 checkins=13

@@@ hidden_input
4 20 50 302
5 4
7 3
9 2
11 1
3
HOG 1 50 95
HANG 3 150 190
HANG 0 240 245
@@@ hidden_output
[t=80] W1 MISSING
[t=80] W2 MISSING
[t=80] W3 MISSING
[t=100] W1 RECOVERED
[t=100] W2 RECOVERED
[t=100] W3 RECOVERED
[t=160] W3 MISSING
[t=190] WATCHDOG RESET
[t=200] W3 RECOVERED
kicks=12
W0 checkins=59
W1 checkins=37
W2 checkins=30
W3 checkins=21

@@@ hidden_input
3 10 105 251
3 1
4 2
5 3
2
HOG 0 21 60
HANG 2 100 230
@@@ hidden_output
[t=30] W0 MISSING
[t=70] W0 RECOVERED
[t=110] W2 MISSING
[t=205] WATCHDOG RESET
[t=240] W2 RECOVERED
kicks=8
W0 checkins=70
W1 checkins=62
W2 checkins=24

@@@ hidden_input
2 10 25 124
3 4
3 1
2
HOG 0 9 11
HANG 1 1 120
@@@ hidden_output
[t=10] W1 MISSING
[t=25] WATCHDOG RESET
kicks=0
W0 checkins=40
W1 checkins=2

@@@ hidden_input
4 25 60 395
10 1
10 2
10 3
10 4
1
HOG 3 100 180
@@@ hidden_output
[t=125] W0 MISSING
[t=125] W1 MISSING
[t=125] W2 MISSING
[t=125] W3 MISSING
[t=160] WATCHDOG RESET
[t=200] W0 RECOVERED
[t=200] W1 RECOVERED
[t=200] W2 RECOVERED
[t=200] W3 RECOVERED
kicks=12
W0 checkins=31
W1 checkins=31
W2 checkins=31
W3 checkins=31

@@@ hint
An **event group** is made for this: each worker sets its own bit with `xEventGroupSetBits(eg, 1u << id)`. The monitor uses `xEventGroupClearBits(eg, all_bits)`. It **returns the bits as they were before clearing**, so reading and clearing happen in one atomic step.
@@@ hint
Run the monitor with `vTaskDelayUntil(&last, window)` (drift-free), keep a `healthy` bit mask, and compare it with the bits that just came back: `lost = healthy & ~seen`, `back = ~healthy & seen`. Report in id order, update `healthy = seen`, and kick only if `seen == all_bits`.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"

void wdg_kick(void);
void health_report(int id, int alive);

static EventGroupHandle_t s_alive;
static EventBits_t s_all;
static int s_n;
static TickType_t s_window;

static void monitor_task(void *pvParameters)
{
    TickType_t last = xTaskGetTickCount();
    EventBits_t healthy = s_all;
    int i;

    (void)pvParameters;
    for (;;) {
        EventBits_t seen;

        vTaskDelayUntil(&last, s_window);
        /* returns the bits *before* clearing: read-and-clear is one atomic step */
        seen = xEventGroupClearBits(s_alive, s_all) & s_all;
        for (i = 0; i < s_n; i++) {
            EventBits_t b = (EventBits_t)1 << i;
            if ((healthy & b) && !(seen & b)) health_report(i, 0);
            else if (!(healthy & b) && (seen & b)) health_report(i, 1);
        }
        healthy = seen;
        if (seen == s_all) wdg_kick();      /* prove that *every* task is alive */
    }
}

void health_start(int n_workers, TickType_t window)
{
    s_n = n_workers;
    s_window = window;
    s_all = ((EventBits_t)1 << n_workers) - 1;
    s_alive = xEventGroupCreate();
    xTaskCreate(monitor_task, "MON", configMINIMAL_STACK_SIZE, NULL, 5, NULL);
}

void health_checkin(int id)
{
    xEventGroupSetBits(s_alive, (EventBits_t)1 << id);
}
@@@ explanation_md
**Approach.** Each worker owns one bit of an event group and sets it when it completes a loop iteration. The monitor wakes on a drift-free grid (`vTaskDelayUntil`). With one call, `xEventGroupClearBits()`, it gets the bits as they were and clears them, so a check-in can never be lost between a separate "read" and "clear". Comparing the new set with the previous `healthy` mask gives edge-triggered reports (MISSING once, RECOVERED once). The watchdog is kicked **only** if every bit was set, so a single stuck task makes the hardware watchdog bite.

Sample 2 shows why this matters. Worker 0 spins (HOG) at priority 3 from t=30 to t=52. It never blocks, so workers 1 and 2 also starve, and all three miss the window [30,40). A watchdog kicked from the idle task would also have caught that. A watchdog kicked from a high-priority timer would not. In sample 1, a task blocked forever (HANG) does not stop any other task, and only a per-task heartbeat can detect it.

**Complexity.** Check-in: O(1) (one event-group operation; FreeRTOS walks the tasks waiting on the group, none here). Monitor run: O(n). RAM: one event group plus the monitor's TCB and stack. Detection latency: at most 2 x window after a task stops (one partial window plus one full window). The watchdog must have T > window. With T between window and 2 x window, a single miss resets the ECU.

**Common mistakes**
- `bits = xEventGroupGetBits(); ... xEventGroupClearBits(...)`: a check-in that happens between the two calls is cleared without ever being seen (a false MISSING).
- Kicking the watchdog from each worker, or from the idle hook: a deadlocked task (sample 1) goes unnoticed.
- `vTaskDelay(window)` in the monitor: it drifts, and the windows no longer line up with the spec.
- Giving the monitor a low priority: a hogging task then also starves the monitor, and its reports come late or never.
- Using a plain shared `uint32_t` with `|=` from several tasks without a critical section: a read-modify-write race.

**Interview follow-ups**
- How would you also check that a worker runs **often enough** or **not too often** (counters with min/max per window, as in AUTOSAR WdgM alive supervision)?
- How do you supervise the **order** of runnables (logical / program-flow supervision)?
- How should a worker that legitimately blocks for a long time (a flash erase) be handled?
- Windowed watchdogs reject kicks that come too early: how does that change the monitor?
