@@@ meta
id: RTK-E-01
topic: Tasks & Scheduling
difficulty: Easy
type: FUNCTION
title: Two Periodic Heartbeat Tasks With vTaskDelay
tags: freertos, xtaskcreate, vtaskdelay, task-parameters, embedded
@@@ statement_md
An ECU has two status LEDs, each driven by its own FreeRTOS task. Write the code that **creates the two tasks**. Each task blinks its LED periodically.

```c
typedef struct {
    const char *name;      /* "A" or "B" */
    TickType_t  period;    /* ticks between two blinks */
    UBaseType_t priority;  /* FreeRTOS priority of the task */
} BlinkCfg;

void blink_log(const char *name);       /* provided: prints "[t=<tick>] <name>" */

void app_start(const BlinkCfg cfg[2]);  /* you write this (and the task function) */
```

`app_start()` is called **before** the scheduler starts. It must create **one task per entry** of `cfg`, with the entry's `priority`. Each task does this forever:

1. wait `period` ticks with `vTaskDelay()`,
2. call `blink_log(name)`.

So a task with period 10 blinks at t = 10, 20, 30, ...

Use **one task function** for both tasks and hand each task its own `BlinkCfg` through the `pvParameters` argument of `xTaskCreate()`. The `cfg` array stays valid for the whole run.

**How it is tested.** The hidden `main()` reads the two configurations and a duration `D`, calls `app_start()`, and runs the scheduler up to and including tick `D`. It then prints how many times each LED blinked. When both tasks blink at the same tick, the **higher-priority** task runs first, so its line comes first.

**Input**
```
<name> <period> <priority>
<name> <period> <priority>
<D>
```

**Example**
```
Input:
A 10 2
B 15 1
60

Output:
[t=10] A
[t=15] B
[t=20] A
[t=30] A
[t=30] B
[t=40] A
[t=45] B
[t=50] A
[t=60] A
[t=60] B
A blinked 6 times
B blinked 4 times
```
At t=30 and t=60 both tasks wake up together: A (priority 2) runs before B (priority 1).
@@@ constraints_md
- 1 <= period <= 1000, 1 <= D <= 5000. The two priorities are different and in 1..6.
- Create exactly two tasks with stack size `configMINIMAL_STACK_SIZE`. No busy loops: a task must block in `vTaskDelay()`.
- Simulated time: 1 tick = 1 ms, and code between two blocking calls takes zero ticks.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"

typedef struct {
    const char *name;
    TickType_t  period;
    UBaseType_t priority;
} BlinkCfg;

void blink_log(const char *name);

static void blink_task(void *pvParameters)
{
    /* TODO: get this task's BlinkCfg from pvParameters, then loop forever:
       vTaskDelay(period); blink_log(name); */
    (void)pvParameters;
    for (;;) {
        vTaskDelay(1000);
    }
}

void app_start(const BlinkCfg cfg[2])
{
    /* TODO: create one task per configuration */
    (void)cfg;
    (void)blink_task;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

static unsigned g_blinks[2];

void blink_log(const char *name)
{
    printf("[t=%u] %s\n", (unsigned)xTaskGetTickCount(), name);
    g_blinks[strcmp(name, "A") == 0 ? 0 : 1]++;
}

/*USER_CODE*/

int main(void)
{
    static char names[2][8];
    static BlinkCfg cfg[2];
    unsigned period, prio, dur;
    int i;

    for (i = 0; i < 2; i++) {
        if (scanf("%7s %u %u", names[i], &period, &prio) != 3) return 1;
        cfg[i].name = names[i];
        cfg[i].period = (TickType_t)period;
        cfg[i].priority = (UBaseType_t)prio;
    }
    if (scanf("%u", &dur) != 1) return 1;

    app_start(cfg);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("A blinked %u times\n", g_blinks[0]);
    printf("B blinked %u times\n", g_blinks[1]);
    return 0;
}
@@@ sample_input
A 10 2
B 15 1
60
@@@ sample_output
[t=10] A
[t=15] B
[t=20] A
[t=30] A
[t=30] B
[t=40] A
[t=45] B
[t=50] A
[t=60] A
[t=60] B
A blinked 6 times
B blinked 4 times
@@@ sample_input
A 4 1
B 6 3
12
@@@ sample_output
[t=4] A
[t=6] B
[t=8] A
[t=12] B
[t=12] A
A blinked 3 times
B blinked 2 times
@@@ hidden_input
A 1 2
B 3 1
7
@@@ hidden_output
[t=1] A
[t=2] A
[t=3] A
[t=3] B
[t=4] A
[t=5] A
[t=6] A
[t=6] B
[t=7] A
A blinked 7 times
B blinked 2 times
@@@ hidden_input
A 100 4
B 30 5
90
@@@ hidden_output
[t=30] B
[t=60] B
[t=90] B
A blinked 0 times
B blinked 3 times
@@@ hidden_input
A 7 6
B 7 1
21
@@@ hidden_output
[t=7] A
[t=7] B
[t=14] A
[t=14] B
[t=21] A
[t=21] B
A blinked 3 times
B blinked 3 times
@@@ hidden_input
A 5 1
B 5 2
16
@@@ hidden_output
[t=5] B
[t=5] A
[t=10] B
[t=10] A
[t=15] B
[t=15] A
A blinked 3 times
B blinked 3 times
@@@ hidden_input
A 1000 3
B 999 2
5000
@@@ hidden_output
[t=999] B
[t=1000] A
[t=1998] B
[t=2000] A
[t=2997] B
[t=3000] A
[t=3996] B
[t=4000] A
[t=4995] B
[t=5000] A
A blinked 5 times
B blinked 5 times
@@@ hint
`xTaskCreate(fn, name, stack, pvParameters, priority, NULL)`: the 4th argument is passed unchanged to the task function. Pass a pointer to the task's own configuration.
@@@ hint
Inside the task: `const BlinkCfg *c = (const BlinkCfg *)pvParameters;` then `for (;;) { vTaskDelay(c->period); blink_log(c->name); }`. Cast away `const` only in the `xTaskCreate` call (`(void *)&cfg[i]`).
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"

typedef struct {
    const char *name;
    TickType_t  period;
    UBaseType_t priority;
} BlinkCfg;

void blink_log(const char *name);

static void blink_task(void *pvParameters)
{
    const BlinkCfg *c = (const BlinkCfg *)pvParameters;

    for (;;) {
        vTaskDelay(c->period);    /* blocked: other tasks (or idle) run meanwhile */
        blink_log(c->name);
    }
}

void app_start(const BlinkCfg cfg[2])
{
    int i;

    for (i = 0; i < 2; i++) {
        /* cfg[i] outlives the task, so passing its address is safe */
        xTaskCreate(blink_task, cfg[i].name, configMINIMAL_STACK_SIZE,
                    (void *)&cfg[i], cfg[i].priority, NULL);
    }
}
@@@ explanation_md
**Approach.** One task function, two task instances. The 4th argument of `xTaskCreate()` (`pvParameters`) is stored in the TCB and handed to the task function when the task first runs. Each instance casts it back to `const BlinkCfg *` and loops `vTaskDelay(period)` then `blink_log(name)`.

`vTaskDelay(period)` moves the task to the delayed list for `period` ticks. Meanwhile the other task, or the idle task, runs. When both tasks unblock at the same tick, the scheduler picks the highest-priority ready task first. That is why the line of the higher-priority task comes first at t=30 in the example. Equal priorities are not used here: their order would depend on the ready-list order, not on the priorities.

**Complexity.** Per blink: O(1) CPU work plus one insertion into the delayed list (O(number of delayed tasks)). RAM: one TCB plus one stack of `configMINIMAL_STACK_SIZE` words per task. No dynamic memory after start-up.

**Common mistakes**
- Passing the address of a **local** variable as `pvParameters` (for example a `BlinkCfg` copied on `app_start()`'s stack). The task first runs after `app_start()` has returned, so it reads a dead stack frame.
- Passing `&i` (the loop counter): both tasks see its final value.
- A task that does not block (busy-wait instead of `vTaskDelay`) starves every lower-priority task and the idle task. In the simulator, time stops and the test hits the time limit.
- Returning from the task function. A FreeRTOS task must loop forever or call `vTaskDelete(NULL)`.
- Ignoring the return value of `xTaskCreate()` in production code. It returns `errCOULD_NOT_ALLOCATE_REQUIRED_MEMORY` when the heap is exhausted.

**Interview follow-ups**
- `vTaskDelay(10)` inside a loop that also does 3 ms of work: what is the real period, and how does `vTaskDelayUntil()` fix the drift?
- What happens if both tasks have the same priority and wake at the same tick?
- How would you choose the stack size, and how do you check it at run time (`uxTaskGetStackHighWaterMark`)?
- Why is the idle task needed at all, and what runs in it?
