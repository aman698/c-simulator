@@@ meta
id: RTK-H-02
topic: Tasks & Scheduling
difficulty: Hard
type: FUNCTION
title: Supervisor That Detects and Restarts Hung Tasks
tags: freertos, software-watchdog, vtaskdelete, xtaskcreate, task-restart, fault-recovery, embedded, asked-in-automotive
@@@ statement_md
A gateway ECU runs up to four worker tasks. A worker can **hang**: it deadlocks (blocks forever), or it gets stuck in an endless loop. Write a **software watchdog**: a supervisor task that detects hung workers and restarts them, with a per-worker restart limit.

```c
/* provided by the test harness */
void worker_cycle(unsigned i);                 /* one unit of work of worker i (may never return!) */
void report_restart(unsigned i, unsigned n);   /* prints "[t=<tick>] W<i> restarted (<n>)" */
void report_give_up(unsigned i);               /* prints "[t=<tick>] W<i> given up"         */

typedef struct {
    unsigned   n;            /* number of workers, 1..4 (workers are numbered 1..n) */
    TickType_t period[4];    /* worker i sleeps period[i-1] ticks after each cycle  */
    TickType_t check;        /* supervisor period                                    */
    unsigned   max_restarts; /* per worker                                          */
} WdCfg;

void app_start(const WdCfg *cfg);   /* you write this, the worker task and the supervisor */
```

**Workers.** Worker `i` has priority `i` (W1 = 1 ... W4 = 4). It loops forever: `worker_cycle(i)`, **check in** (record that it is alive), `vTaskDelay(period[i-1])`. Every `period` is `<= check`, so a healthy worker checks in at least once per supervisor period.

**Supervisor.** Priority **5**, runs at t = check, 2·check, ... (use `vTaskDelayUntil`). At each run it looks at every worker that has not been given up, in order W1..Wn:

- If the worker checked in since the previous supervisor run, it is healthy.
- Otherwise it is **hung**:
  - If it has been restarted fewer than `max_restarts` times: delete it, create a **fresh** worker task for the same `i`, and call `report_restart(i, count)`. Here `count` is that worker's restart number (1, 2, ...).
  - Otherwise: delete it, call `report_give_up(i)`, and never check it again.
- Then clear all check-ins for the next period.

The supervisor has the highest priority, so at a tick where it runs, workers that become ready at that same tick run after it. A restarted worker therefore starts its first cycle (and checks in) right after the supervisor blocks. A worker that cannot run because a higher-priority worker hogs the CPU is also hung from the supervisor's point of view.

**How it is tested.** `worker_cycle()` hangs according to a list of events `i t B|L`: the first cycle of worker `i` that starts at tick `>= t` hangs forever. `B` means it blocks forever on a semaphore. `L` means it loops forever on the CPU. Each event is used once. The harness prints hangs as they happen. After tick `D` it prints the number of completed cycles per worker and the number of worker tasks still alive.

**Input**
```
<n> <check> <max_restarts> <D>
<period 1> ... <period n>
<m>
<worker> <tick> <B|L>     (m lines)
```

**Example**
```
Input:
2 10 2 60
3 4
1
2 12 B

Output:
[t=12] W2 hangs (blocked)
[t=20] W2 restarted (1)
cycles: W1=21 W2=14
workers alive: 2
```
W2 checks in at t=0, 4 and 8. Its cycle at t=12 blocks forever, so there is no check-in during t=10..19. The supervisor restarts it at t=20, and the new W2 runs at t=20, 24, ..., 60 (3 + 11 = 14 cycles).
@@@ constraints_md
- 1 <= n <= 4, 1 <= period <= check <= 100, 0 <= max_restarts <= 5, 1 <= D <= 5000, 0 <= m <= 10.
- The `WdCfg` stays valid for the whole run. Stack size `configMINIMAL_STACK_SIZE`.
- Never use the handle of a deleted task again.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

void worker_cycle(unsigned i);
void report_restart(unsigned i, unsigned n);
void report_give_up(unsigned i);

typedef struct {
    unsigned   n;
    TickType_t period[4];
    TickType_t check;
    unsigned   max_restarts;
} WdCfg;

static const WdCfg *g_cfg;

static void worker_task(void *pv)
{
    unsigned i = (unsigned)(uintptr_t)pv;
    for (;;) {
        worker_cycle(i);
        /* TODO: check in */
        vTaskDelay(g_cfg->period[i - 1]);
    }
}

static void supervisor_task(void *pv)
{
    (void)pv;
    for (;;) {
        vTaskDelay(1000);     /* TODO */
    }
}

void app_start(const WdCfg *cfg)
{
    unsigned i;
    g_cfg = cfg;
    for (i = 1; i <= cfg->n; i++)
        xTaskCreate(worker_task, "worker", configMINIMAL_STACK_SIZE, (void *)(uintptr_t)i, i, NULL);
    (void)supervisor_task;   /* TODO: create the supervisor */
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "sim.h"

static SemaphoreHandle_t g_never;          /* never given: blocking on it = deadlock */
static unsigned g_m;
static unsigned g_ev_worker[10];
static TickType_t g_ev_tick[10];
static char g_ev_kind[10];
static int g_ev_used[10];
static unsigned g_cycles[5];

void worker_cycle(unsigned i)
{
    TickType_t now = xTaskGetTickCount();
    unsigned e;
    for (e = 0; e < g_m; e++) {
        if (!g_ev_used[e] && g_ev_worker[e] == i && g_ev_tick[e] <= now) {
            g_ev_used[e] = 1;
            if (g_ev_kind[e] == 'B') {
                printf("[t=%u] W%u hangs (blocked)\n", (unsigned)now, i);
                xSemaphoreTake(g_never, portMAX_DELAY);
            } else {
                printf("[t=%u] W%u hangs (loop)\n", (unsigned)now, i);
                for (;;) vSimBusyWork(1);
            }
        }
    }
    g_cycles[i]++;
}

void report_restart(unsigned i, unsigned n)
{
    printf("[t=%u] W%u restarted (%u)\n", (unsigned)xTaskGetTickCount(), i, n);
}

void report_give_up(unsigned i)
{
    printf("[t=%u] W%u given up\n", (unsigned)xTaskGetTickCount(), i);
}

/*USER_CODE*/

int main(void)
{
    static WdCfg cfg;
    unsigned n, check, maxr, D, i, p, w, t;
    char k;

    if (scanf("%u %u %u %u", &n, &check, &maxr, &D) != 4 || n < 1 || n > 4) return 1;
    cfg.n = n;
    cfg.check = (TickType_t)check;
    cfg.max_restarts = maxr;
    for (i = 0; i < n; i++) {
        if (scanf("%u", &p) != 1) return 1;
        cfg.period[i] = (TickType_t)p;
    }
    if (scanf("%u", &g_m) != 1 || g_m > 10) return 1;
    for (i = 0; i < g_m; i++) {
        if (scanf("%u %u %c", &w, &t, &k) != 3) return 1;
        g_ev_worker[i] = w;
        g_ev_tick[i] = (TickType_t)t;
        g_ev_kind[i] = k;
    }
    g_never = xSemaphoreCreateBinary();

    app_start(&cfg);
    vSimSetTickLimit((TickType_t)D);
    vTaskStartScheduler();

    printf("cycles:");
    for (i = 1; i <= n; i++) printf(" W%u=%u", i, g_cycles[i]);
    printf("\n");
    /* minus idle, timer service task and the supervisor */
    printf("workers alive: %u\n", (unsigned)uxTaskGetNumberOfTasks() - 3u);
    return 0;
}
@@@ sample_input
2 10 2 60
3 4
1
2 12 B
@@@ sample_output
[t=12] W2 hangs (blocked)
[t=20] W2 restarted (1)
cycles: W1=21 W2=14
workers alive: 2
@@@ sample_input
2 10 1 70
5 5
2
2 13 L
2 25 L
@@@ sample_output
[t=15] W2 hangs (loop)
[t=30] W1 restarted (1)
[t=30] W2 restarted (1)
[t=30] W2 hangs (loop)
[t=40] W1 given up
[t=40] W2 given up
cycles: W1=3 W2=3
workers alive: 0

@@@ hidden_input
1 5 3 30
5
0
@@@ hidden_output
cycles: W1=7
workers alive: 1

@@@ hidden_input
3 20 0 100
10 20 5
2
1 30 B
3 41 B
@@@ hidden_output
[t=30] W1 hangs (blocked)
[t=45] W3 hangs (blocked)
[t=60] W1 given up
[t=80] W3 given up
cycles: W1=3 W2=6 W3=9
workers alive: 1

@@@ hidden_input
4 10 5 200
2 3 4 10
4
4 1 B
4 15 B
4 31 L
1 50 B
@@@ hidden_output
[t=10] W4 hangs (blocked)
[t=20] W4 restarted (1)
[t=20] W4 hangs (blocked)
[t=30] W4 restarted (2)
[t=40] W4 hangs (loop)
[t=50] W1 restarted (1)
[t=50] W2 restarted (1)
[t=50] W3 restarted (1)
[t=50] W4 restarted (3)
[t=50] W1 hangs (blocked)
[t=60] W1 restarted (2)
cycles: W1=91 W2=65 W3=48 W4=18
workers alive: 4

@@@ hidden_input
1 8 2 100
8
3
1 1 B
1 9 B
1 17 B
@@@ hidden_output
[t=8] W1 hangs (blocked)
[t=16] W1 restarted (1)
[t=16] W1 hangs (blocked)
[t=24] W1 restarted (2)
[t=24] W1 hangs (blocked)
[t=32] W1 given up
cycles: W1=1
workers alive: 0

@@@ hidden_input
3 10 1 80
4 4 4
2
3 22 L
3 35 L
@@@ hidden_output
[t=24] W3 hangs (loop)
[t=40] W1 restarted (1)
[t=40] W2 restarted (1)
[t=40] W3 restarted (1)
[t=40] W3 hangs (loop)
[t=50] W1 given up
[t=50] W2 given up
[t=50] W3 given up
cycles: W1=6 W2=6 W3=6
workers alive: 0

@@@ hint
Keep a handle, a check-in flag and a restart counter per worker. The worker sets its flag after `worker_cycle()` returns. The supervisor (priority 5, `vTaskDelayUntil`) tests and clears the flags. Pass the worker number as `pvParameters`.
@@@ hint
Restart = `vTaskDelete(handle)` + `xTaskCreate(..., &handle)` with the same parameters. Deleting another task frees it at once, so the deleted handle must be overwritten before any further use. A given-up worker gets `handle = NULL` and is skipped from then on.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

void worker_cycle(unsigned i);
void report_restart(unsigned i, unsigned n);
void report_give_up(unsigned i);

typedef struct {
    unsigned   n;
    TickType_t period[4];
    TickType_t check;
    unsigned   max_restarts;
} WdCfg;

static const WdCfg *g_cfg;
static TaskHandle_t g_worker[5];          /* index 1..4; NULL = given up */
static volatile int g_checkin[5];
static unsigned g_restarts[5];

static void worker_task(void *pv)
{
    unsigned i = (unsigned)(uintptr_t)pv;
    for (;;) {
        worker_cycle(i);
        g_checkin[i] = 1;                 /* single writer: plain flag is enough */
        vTaskDelay(g_cfg->period[i - 1]);
    }
}

static void start_worker(unsigned i)
{
    g_checkin[i] = 0;
    xTaskCreate(worker_task, "worker", configMINIMAL_STACK_SIZE,
                (void *)(uintptr_t)i, (UBaseType_t)i, &g_worker[i]);
}

static void supervisor_task(void *pv)
{
    TickType_t last = xTaskGetTickCount();
    unsigned i;
    (void)pv;

    for (;;) {
        vTaskDelayUntil(&last, g_cfg->check);
        for (i = 1; i <= g_cfg->n; i++) {
            if (g_worker[i] == NULL || g_checkin[i]) continue;   /* given up / healthy */
            vTaskDelete(g_worker[i]);                            /* hung: kill it */
            g_worker[i] = NULL;
            if (g_restarts[i] < g_cfg->max_restarts) {
                g_restarts[i]++;
                start_worker(i);           /* lower priority: runs after we block */
                report_restart(i, g_restarts[i]);
            } else {
                report_give_up(i);
            }
        }
        for (i = 1; i <= g_cfg->n; i++) g_checkin[i] = 0;
    }
}

void app_start(const WdCfg *cfg)
{
    unsigned i;
    g_cfg = cfg;
    for (i = 1; i <= cfg->n; i++) start_worker(i);
    xTaskCreate(supervisor_task, "supervisor", configMINIMAL_STACK_SIZE, NULL, 5, NULL);
}
@@@ explanation_md
**Approach.** This is a *software watchdog* with per-task check-ins:

- Each worker writes its own flag after every completed cycle. That is a single writer per flag, and the supervisor only reads and clears it, so no lock is needed on a single core.
- The supervisor runs periodically at the highest application priority. A worker that is stuck in an endless loop cannot starve it, and the supervisor sees a consistent snapshot because no worker runs while it checks.
- A missing check-in for a whole supervisor period means the worker is hung. This covers both failure modes: blocked forever (deadlock, lost event) and CPU-bound (endless loop). It also flags workers that are **starved** by a hung higher-priority worker. In the second sample, W2's endless loop starves W1, so W1 misses a check-in as well and is restarted. That is a real effect of priority-based watchdogs, worth mentioning in an interview.
- Recovery deletes the task and creates a new one with the same parameters. `vTaskDelete()` on another task removes it from every list (ready, delayed, or the semaphore's waiting list), so even a task blocked forever can be killed. Its TCB and stack are freed immediately, which is why the handle is overwritten at once.
- A restart limit prevents an endless restart loop for a permanently broken worker. In production the "give up" path would set a DTC and degrade the function.

**Complexity.** Supervisor: O(n) per period. Worker overhead: one flag write per cycle. RAM: a handle, a flag and a counter per worker. A restart costs one free and one allocation of TCB plus stack, and with heap_4 this does not fragment, because the freed block is reused by the new task of the same size.

**Common mistakes**
- Supervisor priority lower than a worker: an endless loop in that worker starves the supervisor, and nothing is ever restarted.
- Checking `eTaskGetState() == eBlocked` to detect a hang. A healthy worker is blocked most of the time too. Only missing progress means "hung".
- Using the handle after `vTaskDelete()` (for example `vTaskDelete(h)` twice, or comparing states) — use-after-free inside the kernel heap.
- Forgetting to clear the check-ins after each period. A worker that hangs right after one check-in is then never detected.
- Deleting a task that holds a mutex. The mutex is never released (not exercised here, but the classic follow-up).

**Interview follow-ups**
- What if a hung worker holds a mutex when it is deleted? How would you design for that?
- Should the supervisor itself kick the **hardware** watchdog? Under which condition exactly?
- How do you distinguish a starved worker from a hung one?
- Why do many safety standards prefer a reset of the whole ECU over restarting a single task?
