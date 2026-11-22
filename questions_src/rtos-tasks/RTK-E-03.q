@@@ meta
id: RTK-E-03
topic: Tasks & Scheduling
difficulty: Easy
type: FUNCTION
title: Start-Up Init Task That Deletes Itself
tags: freertos, vtaskdelete, startup, init-task, priorities, embedded
@@@ statement_md
Many ECUs start with a single **init task**. It initialises the hardware, creates the application tasks, and then deletes itself so that its RAM can be reused. No application task may run before the hardware is ready.

```c
typedef struct {
    unsigned    worker_count;   /* 1..8 */
    UBaseType_t prio[8];        /* priority of worker i (1..5) */
    TickType_t  period[8];      /* worker i runs every period[i] ticks */
} AppCfg;

/* provided by the test harness */
void hw_init(void);             /* takes some CPU ticks, prints "[t=<tick>] hw ready" */
void worker_step(unsigned i);   /* prints "[t=<tick>] W<i>" (i is 1-based) */

void app_start(const AppCfg *cfg);  /* you write this, the init task and the worker task */
```

`app_start()` is called before the scheduler starts and must create **only the init task**, at priority **6**. The init task:

1. calls `hw_init()`,
2. creates worker `i` (`i = 1..worker_count`) with priority `prio[i-1]`,
3. deletes itself with `vTaskDelete(NULL)`.

Each worker runs forever: `worker_step(i)`, then `vTaskDelay(period[i-1])`. So it steps immediately when it first runs, and then every period.

**How it is tested.** The hidden `main()` reads the configuration, calls `app_start()`, and runs the scheduler up to tick `D`. `worker_step()` prints `EARLY` if it is called before `hw_init()` has finished. After the run, the harness prints the number of tasks that still exist, not counting the idle and timer tasks. It should equal the number of workers, because the init task is gone.

When several workers are ready at the same tick, the higher-priority one runs first. Workers with the **same** priority that become ready together at start-up run in creation order. After that, the tests never make two equal-priority workers due at the same tick.

**Input**
```
<hw_init cost in ticks> <D>
<worker_count>
<prio> <period>        (one line per worker)
```

**Example**
```
Input:
3 12
2
2 4
1 6

Output:
[t=3] hw ready
[t=3] W1
[t=3] W2
[t=7] W1
[t=9] W2
[t=11] W1
tasks: 2
```
@@@ constraints_md
- 0 <= hw_init cost <= 100, 1 <= D <= 5000, 1 <= worker_count <= 8, worker priorities 1..5, 1 <= period <= 500.
- Stack size `configMINIMAL_STACK_SIZE` for all tasks. The `AppCfg` stays valid for the whole run.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"

typedef struct {
    unsigned    worker_count;
    UBaseType_t prio[8];
    TickType_t  period[8];
} AppCfg;

void hw_init(void);
void worker_step(unsigned i);

static const AppCfg *g_cfg;

static void worker_task(void *pv)
{
    /* TODO: which worker am I? step, then delay, forever */
    (void)pv;
    for (;;) {
        vTaskDelay(1000);
    }
}

static void init_task(void *pv)
{
    /* TODO */
    (void)pv;
    (void)worker_task;
    vTaskDelete(NULL);
}

void app_start(const AppCfg *cfg)
{
    g_cfg = cfg;
    /* TODO: create the init task */
    (void)init_task;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

static TickType_t g_init_cost;
static int g_hw_ready;

void hw_init(void)
{
    vSimBusyWork(g_init_cost);
    g_hw_ready = 1;
    printf("[t=%u] hw ready\n", (unsigned)xTaskGetTickCount());
}

void worker_step(unsigned i)
{
    printf("[t=%u] W%u%s\n", (unsigned)xTaskGetTickCount(), i, g_hw_ready ? "" : " EARLY");
}

/*USER_CODE*/

int main(void)
{
    static AppCfg cfg;
    unsigned cost, dur, n, p, per, i;

    if (scanf("%u %u", &cost, &dur) != 2) return 1;
    if (scanf("%u", &n) != 1 || n < 1 || n > 8) return 1;
    cfg.worker_count = n;
    for (i = 0; i < n; i++) {
        if (scanf("%u %u", &p, &per) != 2) return 1;
        cfg.prio[i] = (UBaseType_t)p;
        cfg.period[i] = (TickType_t)per;
    }
    g_init_cost = (TickType_t)cost;

    app_start(&cfg);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    /* idle + timer service task are not application tasks */
    printf("tasks: %u\n", (unsigned)uxTaskGetNumberOfTasks() - 2u);
    return 0;
}
@@@ sample_input
3 12
2
2 4
1 6
@@@ sample_output
[t=3] hw ready
[t=3] W1
[t=3] W2
[t=7] W1
[t=9] W2
[t=11] W1
tasks: 2
@@@ sample_input
0 10
3
1 5
3 4
2 10
@@@ sample_output
[t=0] hw ready
[t=0] W2
[t=0] W3
[t=0] W1
[t=4] W2
[t=5] W1
[t=8] W2
[t=10] W3
[t=10] W1
tasks: 3
@@@ hidden_input
5 5
1
5 1
@@@ hidden_output
[t=5] hw ready
[t=5] W1
tasks: 1
@@@ hidden_input
10 30
2
5 10
4 3
@@@ hidden_output
[t=10] hw ready
[t=10] W1
[t=10] W2
[t=13] W2
[t=16] W2
[t=19] W2
[t=20] W1
[t=22] W2
[t=25] W2
[t=28] W2
[t=30] W1
tasks: 2
@@@ hidden_input
1 4
8
1 100
2 100
3 100
4 100
5 100
1 200
2 200
3 200
@@@ hidden_output
[t=1] hw ready
[t=1] W5
[t=1] W4
[t=1] W3
[t=1] W8
[t=1] W2
[t=1] W7
[t=1] W1
[t=1] W6
tasks: 8
@@@ hidden_input
100 300
1
3 50
@@@ hidden_output
[t=100] hw ready
[t=100] W1
[t=150] W1
[t=200] W1
[t=250] W1
[t=300] W1
tasks: 1
@@@ hidden_input
2 9
2
1 2
5 3
@@@ hidden_output
[t=2] hw ready
[t=2] W2
[t=2] W1
[t=4] W1
[t=5] W2
[t=6] W1
[t=8] W2
[t=8] W1
tasks: 2
@@@ hint
The init task must not be preempted by the workers it creates. Give it a priority higher than every worker (6). Then a worker becomes ready when it is created but cannot run until the init task deletes itself.
@@@ hint
Pass the worker index as `pvParameters`: `(void *)(uintptr_t)i`, and recover it with `(unsigned)(uintptr_t)pv`. Look up the period in the configuration through a file-scope pointer (`g_cfg`).
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

typedef struct {
    unsigned    worker_count;
    UBaseType_t prio[8];
    TickType_t  period[8];
} AppCfg;

void hw_init(void);
void worker_step(unsigned i);

static const AppCfg *g_cfg;

static void worker_task(void *pv)
{
    unsigned i = (unsigned)(uintptr_t)pv;          /* 1-based worker number */

    for (;;) {
        worker_step(i);
        vTaskDelay(g_cfg->period[i - 1]);
    }
}

static void init_task(void *pv)
{
    unsigned i;
    (void)pv;

    hw_init();
    for (i = 1; i <= g_cfg->worker_count; i++) {
        /* lower priority than us: ready, but cannot run before we delete ourselves */
        xTaskCreate(worker_task, "worker", configMINIMAL_STACK_SIZE,
                    (void *)(uintptr_t)i, g_cfg->prio[i - 1], NULL);
    }
    vTaskDelete(NULL);   /* TCB + stack are freed later by the idle task */
}

void app_start(const AppCfg *cfg)
{
    g_cfg = cfg;
    xTaskCreate(init_task, "init", configMINIMAL_STACK_SIZE, NULL, 6, NULL);
}
@@@ explanation_md
**Approach.** The init task has priority 6, above every worker. While it runs `hw_init()` and creates the workers, every new worker is *ready* but cannot preempt it. When the init task calls `vTaskDelete(NULL)`, the scheduler switches to the highest-priority ready worker. From then on, the workers run in priority order. That is why in the second example W2 (priority 3) steps before W3 (priority 2), which steps before W1 (priority 1), all at the same tick.

The index is passed through `pvParameters` as an integer cast to a pointer (`uintptr_t`), so no per-task storage is needed. The configuration is read through a file-scope pointer because it outlives all tasks.

**Why delete the init task?** A task that has finished its job but still exists keeps its TCB and its stack. Deleting it gives that RAM back to the heap. With dynamic allocation, the idle task frees it a moment later. That is why the idle task must get CPU time: a system that never lets it run leaks the memory of self-deleted tasks.

**Complexity.** Start-up: O(worker_count) task creations. Each worker step: O(1) plus a delayed-list insertion. RAM after start-up: one TCB and one stack per worker. The init task's memory is freed after deletion.

**Common mistakes**
- Creating the workers in `app_start()` or giving the init task a low priority. Workers then run before `hw_init()` finishes and the harness prints `EARLY`.
- Creating workers with a priority higher than the init task. Each one preempts the init task as soon as it is created.
- Passing `&i` as the parameter: by the time the workers run, `i` is out of scope (and would hold the final value anyway).
- Ending the init task with `return` or an endless `for (;;);` loop instead of `vTaskDelete(NULL)`. The first is a crash. The second burns the CPU at the highest priority and starves everything.

**Interview follow-ups**
- Another way to guarantee the workers do not run early: `vTaskSuspendAll()` / `xTaskResumeAll()` around the creation. When is that better or worse?
- Where does the memory of a self-deleted task go, and when is it freed?
- How would you report a failed `xTaskCreate()` during init on a production ECU?
- Static allocation (`xTaskCreateStatic`): does deleting the init task still free anything?
