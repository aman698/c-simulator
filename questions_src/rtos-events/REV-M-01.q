@@@ meta
id: REV-M-01
topic: Event Groups & Notifications
difficulty: Medium
type: FUNCTION
title: Sensor-Fusion Rendezvous With xEventGroupSync
tags: freertos, event-groups, xeventgroupsync, rendezvous, barrier, embedded, asked-in-automotive
@@@ statement_md
An ADAS sensor-fusion ECU runs three acquisition tasks: camera, radar and lidar. In every cycle, each task first acquires its own frame, which takes a different time per sensor and per cycle. Fusion may only start when **all three** frames of the cycle are there. So the three tasks must meet at a **rendezvous** (barrier) before any of them goes on. Implement it with **`xEventGroupSync()`**.

```c
typedef struct {
    const char *name;
    UBaseType_t priority;
} SensorCfg;

void acquire(int idx, int cycle);   /* provided: blocks for this sensor's acquisition time of that cycle */
void arrive(int idx, int cycle);    /* provided: prints "[t=<tick>] <name> arrives <cycle>"            */
void depart(int idx, int cycle);    /* provided: prints "[t=<tick>] <name> go <cycle>"                 */

void app_start(const SensorCfg cfg[3], int cycles);   /* you write */
```

`app_start()` runs before the scheduler. It creates one event group and three tasks. Task `i` has priority `cfg[i].priority` and receives `i` through `pvParameters`. Each task runs `cycles` cycles (`cycle` = 1, 2, ..., `cycles`):

1. `acquire(i, cycle);`
2. `arrive(i, cycle);`
3. rendezvous: set its own bit `(1 << i)` and wait, **without timeout**, until all three bits are set: `xEventGroupSync(eg, 1 << i, 0x7, portMAX_DELAY)`;
4. `depart(i, cycle);`

After the last cycle the task deletes itself. `xEventGroupWaitBits()`, queues, semaphores and task notifications are disabled in this exercise. `xEventGroupSync()` sets the caller's bit and waits **in one atomic operation**. It also clears the three bits when the rendezvous completes, so the next cycle starts from 0.

**Who goes first.** When the last task arrives, every waiting task is released at the same tick. Then they run in **priority order** (all priorities are distinct). If the last arriver has a lower priority than a released task, it is preempted inside `xEventGroupSync()`. Otherwise it continues first, and the others run when it blocks in its next `acquire()` or deletes itself.

**How it is tested.** The hidden `main()` reads the scenario, calls `app_start()` and runs the scheduler up to and including tick `D`. `depart()` prints `ERROR: ...` if a task leaves a cycle before all three have arrived. Then the harness prints the number of cycles that all three tasks completed, and `OK` if no error was seen.

**Input**
```
<cycles> <D>
<name> <priority> <t1> ... <t_cycles>     (3 lines: acquisition time of each cycle)
```

**Example**
```
Input:
2 100
CAM 3 10 5
RAD 2 4 12
LID 1 7 7

Output:
[t=4] RAD arrives 1
[t=7] LID arrives 1
[t=10] CAM arrives 1
[t=10] CAM go 1
[t=10] RAD go 1
[t=10] LID go 1
[t=15] CAM arrives 2
[t=17] LID arrives 2
[t=22] RAD arrives 2
[t=22] CAM go 2
[t=22] RAD go 2
[t=22] LID go 2
cycles completed=2
OK
```
In cycle 1, CAM arrives last and has the highest priority, so it goes on at once. RAD and LID run after CAM blocks in its next acquisition. In cycle 2, RAD arrives last at t=22. That releases CAM (priority 3), which preempts RAD inside `xEventGroupSync()`, so CAM's `go` comes first.
@@@ constraints_md
- 1 <= cycles <= 10, 1 <= acquisition time <= 500, 1 <= D <= 20000.
- The three priorities are distinct and in 1..5.
- Use `xEventGroupSync()` with `portMAX_DELAY`. No polling, no extra tasks.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"

typedef struct {
    const char *name;
    UBaseType_t priority;
} SensorCfg;

void acquire(int idx, int cycle);
void arrive(int idx, int cycle);
void depart(int idx, int cycle);

static EventGroupHandle_t sync_group;
static int n_cycles;

static void sensor_task(void *pvParameters)
{
    int idx = (int)(intptr_t)pvParameters;
    int c;

    for (c = 1; c <= n_cycles; c++) {
        acquire(idx, c);
        arrive(idx, c);
        /* TODO: rendezvous with the two other tasks */
        depart(idx, c);
    }
    vTaskDelete(NULL);
}

void app_start(const SensorCfg cfg[3], int cycles)
{
    /* TODO: create the event group and the three tasks */
    (void)cfg;
    (void)sensor_task;
    (void)sync_group;
    n_cycles = cycles;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "event_groups.h"
#include "sim.h"

/* SensorCfg is defined by the user code (as in the statement) */

static char g_names[3][16];
static unsigned g_work[3][10];
static int g_cycles;
static int g_arrived[11];     /* arrivals per cycle */
static int g_departed[11];
static int g_errors;

void acquire(int idx, int cycle)
{
    if (idx < 0 || idx > 2 || cycle < 1 || cycle > g_cycles) {
        printf("ERROR: acquire(%d, %d) out of range\n", idx, cycle);
        g_errors++;
        vTaskDelay(1);
        return;
    }
    vTaskDelay((TickType_t)g_work[idx][cycle - 1]);
}

void arrive(int idx, int cycle)
{
    if (idx < 0 || idx > 2 || cycle < 1 || cycle > g_cycles) {
        printf("ERROR: arrive(%d, %d) out of range\n", idx, cycle);
        g_errors++;
        return;
    }
    printf("[t=%u] %s arrives %d\n", (unsigned)xTaskGetTickCount(), g_names[idx], cycle);
    g_arrived[cycle]++;
}

void depart(int idx, int cycle)
{
    if (idx < 0 || idx > 2 || cycle < 1 || cycle > g_cycles) {
        printf("ERROR: depart(%d, %d) out of range\n", idx, cycle);
        g_errors++;
        return;
    }
    printf("[t=%u] %s go %d\n", (unsigned)xTaskGetTickCount(), g_names[idx], cycle);
    if (g_arrived[cycle] != 3) {
        printf("ERROR: %s left cycle %d before all three arrived\n", g_names[idx], cycle);
        g_errors++;
    }
    g_departed[cycle]++;
}

/* the exercise is xEventGroupSync() */
#define xEventGroupWaitBits(...) use_xEventGroupSync_in_this_exercise
#define xQueueGenericCreate(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueGenericCreateStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateCountingSemaphore(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateCountingSemaphoreStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateMutex(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateMutexStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xTaskGenericNotify(...) notifications_are_disabled_in_this_exercise
#define xTaskGenericNotifyWait(...) notifications_are_disabled_in_this_exercise
#define ulTaskGenericNotifyTake(...) notifications_are_disabled_in_this_exercise

/*USER_CODE*/

#undef xEventGroupWaitBits
#undef xQueueGenericCreate
#undef xQueueGenericCreateStatic
#undef xQueueCreateCountingSemaphore
#undef xQueueCreateCountingSemaphoreStatic
#undef xQueueCreateMutex
#undef xQueueCreateMutexStatic
#undef xTaskGenericNotify
#undef xTaskGenericNotifyWait
#undef ulTaskGenericNotifyTake

int main(void)
{
    static SensorCfg cfg[3];
    unsigned dur, prio;
    int i, c, done = 0;

    if (scanf("%d %u", &g_cycles, &dur) != 2 || g_cycles < 1 || g_cycles > 10) return 1;
    for (i = 0; i < 3; i++) {
        if (scanf("%15s %u", g_names[i], &prio) != 2) return 1;
        for (c = 0; c < g_cycles; c++)
            if (scanf("%u", &g_work[i][c]) != 1) return 1;
        cfg[i].name = g_names[i];
        cfg[i].priority = (UBaseType_t)prio;
    }

    app_start(cfg, g_cycles);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    for (c = 1; c <= g_cycles; c++)
        if (g_departed[c] == 3) done = c;
        else break;
    printf("cycles completed=%d\n", done);
    if (g_errors == 0) printf("OK\n");
    return 0;
}
@@@ sample_input
2 100
CAM 3 10 5
RAD 2 4 12
LID 1 7 7
@@@ sample_output
[t=4] RAD arrives 1
[t=7] LID arrives 1
[t=10] CAM arrives 1
[t=10] CAM go 1
[t=10] RAD go 1
[t=10] LID go 1
[t=15] CAM arrives 2
[t=17] LID arrives 2
[t=22] RAD arrives 2
[t=22] CAM go 2
[t=22] RAD go 2
[t=22] LID go 2
cycles completed=2
OK
@@@ sample_input
1 20
A 1 5
B 4 5
C 2 5
@@@ sample_output
[t=5] B arrives 1
[t=5] C arrives 1
[t=5] A arrives 1
[t=5] B go 1
[t=5] C go 1
[t=5] A go 1
cycles completed=1
OK
@@@ hidden_input
3 200
CAM 5 1 1 1
RAD 4 1 1 1
LID 3 1 1 1
@@@ hidden_output
[t=1] CAM arrives 1
[t=1] RAD arrives 1
[t=1] LID arrives 1
[t=1] CAM go 1
[t=1] RAD go 1
[t=1] LID go 1
[t=2] CAM arrives 2
[t=2] RAD arrives 2
[t=2] LID arrives 2
[t=2] CAM go 2
[t=2] RAD go 2
[t=2] LID go 2
[t=3] CAM arrives 3
[t=3] RAD arrives 3
[t=3] LID arrives 3
[t=3] CAM go 3
[t=3] RAD go 3
[t=3] LID go 3
cycles completed=3
OK
@@@ hidden_input
3 1000
CAM 1 100 10 10
RAD 2 10 100 10
LID 3 10 10 100
@@@ hidden_output
[t=10] LID arrives 1
[t=10] RAD arrives 1
[t=100] CAM arrives 1
[t=100] LID go 1
[t=100] RAD go 1
[t=100] CAM go 1
[t=110] LID arrives 2
[t=110] CAM arrives 2
[t=200] RAD arrives 2
[t=200] LID go 2
[t=200] RAD go 2
[t=200] CAM go 2
[t=210] RAD arrives 3
[t=210] CAM arrives 3
[t=300] LID arrives 3
[t=300] LID go 3
[t=300] RAD go 3
[t=300] CAM go 3
cycles completed=3
OK

@@@ hidden_input
4 60
CAM 2 10 10 10 10
RAD 3 5 20 5 20
LID 1 1 1 1 50
@@@ hidden_output
[t=1] LID arrives 1
[t=5] RAD arrives 1
[t=10] CAM arrives 1
[t=10] RAD go 1
[t=10] CAM go 1
[t=10] LID go 1
[t=11] LID arrives 2
[t=20] CAM arrives 2
[t=30] RAD arrives 2
[t=30] RAD go 2
[t=30] CAM go 2
[t=30] LID go 2
[t=31] LID arrives 3
[t=35] RAD arrives 3
[t=40] CAM arrives 3
[t=40] RAD go 3
[t=40] CAM go 3
[t=40] LID go 3
[t=50] CAM arrives 4
[t=60] RAD arrives 4
cycles completed=3
OK

@@@ hidden_input
2 30
X 5 3 40
Y 1 2 2
Z 3 6 2
@@@ hidden_output
[t=2] Y arrives 1
[t=3] X arrives 1
[t=6] Z arrives 1
[t=6] X go 1
[t=6] Z go 1
[t=6] Y go 1
[t=8] Z arrives 2
[t=8] Y arrives 2
cycles completed=1
OK

@@@ hidden_input
5 5000
FRONT 4 33 33 33 33 33
LEFT 2 25 50 25 50 25
RIGHT 3 40 20 40 20 40
@@@ hidden_output
[t=25] LEFT arrives 1
[t=33] FRONT arrives 1
[t=40] RIGHT arrives 1
[t=40] FRONT go 1
[t=40] RIGHT go 1
[t=40] LEFT go 1
[t=60] RIGHT arrives 2
[t=73] FRONT arrives 2
[t=90] LEFT arrives 2
[t=90] FRONT go 2
[t=90] RIGHT go 2
[t=90] LEFT go 2
[t=115] LEFT arrives 3
[t=123] FRONT arrives 3
[t=130] RIGHT arrives 3
[t=130] FRONT go 3
[t=130] RIGHT go 3
[t=130] LEFT go 3
[t=150] RIGHT arrives 4
[t=163] FRONT arrives 4
[t=180] LEFT arrives 4
[t=180] FRONT go 4
[t=180] RIGHT go 4
[t=180] LEFT go 4
[t=205] LEFT arrives 5
[t=213] FRONT arrives 5
[t=220] RIGHT arrives 5
[t=220] FRONT go 5
[t=220] RIGHT go 5
[t=220] LEFT go 5
cycles completed=5
OK

@@@ hint
`xEventGroupSync(eg, myBit, allBits, portMAX_DELAY)` = "set my bit, then wait until all bits are set", **atomically**. The kernel clears `allBits` as soon as the rendezvous completes, so the barrier can be reused in the next cycle without extra code.
@@@ hint
The naive version `xEventGroupSetBits(eg, myBit); xEventGroupWaitBits(eg, all, pdTRUE, pdTRUE, ...)` breaks: the `SetBits` of the last task releases the others, and their clear-on-exit erases the bits **before** the last task reaches its own `WaitBits`. The last task then waits forever. Pass the task index with `(void *)(intptr_t)i`.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"

typedef struct {
    const char *name;
    UBaseType_t priority;
} SensorCfg;

void acquire(int idx, int cycle);
void arrive(int idx, int cycle);
void depart(int idx, int cycle);

#define ALL_SENSORS ((EventBits_t)0x7)

static EventGroupHandle_t sync_group;
static int n_cycles;

static void sensor_task(void *pvParameters)
{
    int idx = (int)(intptr_t)pvParameters;
    int c;

    for (c = 1; c <= n_cycles; c++) {
        acquire(idx, c);
        arrive(idx, c);
        /* set my bit + wait for all three, atomically; bits are cleared on completion */
        (void)xEventGroupSync(sync_group, (EventBits_t)1 << idx, ALL_SENSORS, portMAX_DELAY);
        depart(idx, c);
    }
    vTaskDelete(NULL);
}

void app_start(const SensorCfg cfg[3], int cycles)
{
    int i;

    n_cycles = cycles;
    sync_group = xEventGroupCreate();
    for (i = 0; i < 3; i++)
        xTaskCreate(sensor_task, cfg[i].name, configMINIMAL_STACK_SIZE,
                    (void *)(intptr_t)i, cfg[i].priority, NULL);
}
@@@ explanation_md
**Approach.** A rendezvous (barrier) for N tasks takes one bit per task. `xEventGroupSync(eg, myBit, all, timeout)` does three things with the scheduler suspended:
1. it sets `myBit`, which may release tasks that are already waiting;
2. if `all` is now complete, it clears `all` and returns **without blocking**;
3. otherwise it blocks until the last participant arrives.

The kernel clears the bits at the moment of completion, so the same event group serves every cycle.

Order of the `go` lines: all waiters are released at the same tick, and then plain priority scheduling decides. `xTaskResumeAll()` at the end of `xEventGroupSync()` yields if a released task has a higher priority than the last arriver. That is why CAM's `go 2` comes before RAD's in the example, although RAD arrived last.

**Complexity.** Each arrival: O(number of waiting tasks) to scan the event list. Each task blocks at most once per cycle. RAM: one event group for up to 24 participants. Cycle time = the **slowest** participant's acquisition time (plus zero-time code): a barrier always runs at the speed of the slowest member.

**Common mistakes**
- `SetBits` followed by `WaitBits`: not atomic. With clear-on-exit, the last task deadlocks. Without clear-on-exit, nobody resets the bits and the next cycle passes the barrier at once.
- Clearing the bits manually after the barrier: a fast task may already have set its bit for the next cycle, and that bit is lost.
- Waiting for `allBits` but setting a bit outside the mask (wrong index), or passing `&i` as the parameter.
- Using a timeout without handling the case where the barrier did not complete. Check the return value: `(ret & all) == all`.

**Interview follow-ups**
- How would you add a timeout so one dead sensor cannot freeze fusion forever, and how do you recover the barrier state afterwards?
- Why can `xEventGroupSync()` not be called from an ISR?
- How would you build the same barrier with task notifications or semaphores, and what does it cost?
- What changes if the participants run on different cores (SMP)?
