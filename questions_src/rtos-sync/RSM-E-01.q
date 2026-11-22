@@@ meta
id: RSM-E-01
topic: Semaphores & Mutexes
difficulty: Easy
type: FUNCTION
title: Mutex-Protected Shared Odometer Counter
tags: freertos, mutex, race-condition, critical-section, read-modify-write, embedded
@@@ statement_md
Several tasks of an instrument-cluster ECU add distance pulses to one shared **odometer** counter. An update is a slow read-modify-write: read the counter, spend some CPU time (scaling, plausibility checks), then write back the new value. Without protection, a higher-priority task can preempt a lower one between its read and its write, and an update is lost.

Write the code that creates the worker tasks and protects the read-modify-write with a **FreeRTOS mutex**.

```c
typedef struct {
    const char *name;      /* "A", "B", ... */
    UBaseType_t priority;  /* FreeRTOS priority of the task */
    TickType_t  period;    /* ticks to wait before each update */
    TickType_t  work;      /* CPU ticks between the read and the write */
    int         updates;   /* number of updates this task performs */
} WorkerCfg;

/* provided by the hidden harness */
int  odo_read(void);                       /* returns the counter */
void odo_work(TickType_t ticks);           /* CPU-bound work, takes `ticks` ticks of CPU time */
void odo_write(const char *who, int value);/* stores the counter, prints "[t=<tick>] <who> wrote <value>" */

void app_start(const WorkerCfg *cfg, int n);   /* you write this (and the task function) */
```

`app_start()` is called **before** the scheduler starts. It must create the mutex and **one task per entry** of `cfg` with the entry's `priority`. Each task does this `updates` times:

1. `vTaskDelay(period)`,
2. take the mutex (wait forever),
3. `v = odo_read();` `odo_work(work);` `odo_write(name, v + 1);`
4. give the mutex.

After its last update the task deletes itself with `vTaskDelete(NULL)`. A task with `updates = 0` deletes itself immediately.

**Rules**
- Use `xSemaphoreCreateMutex()`. Binary/counting semaphores, `vTaskSuspendAll()` and `vTaskPrioritySet()` are not allowed (they do not compile in this exercise).
- `odo_work()` really takes CPU time: ticks advance while it runs and a higher-priority task that wakes up preempts it. So the critical section must cover the **whole** read-work-write sequence.

**How it is tested.** The hidden `main()` reads the workers and a duration `D`, calls `app_start()` and runs the scheduler up to and including tick `D` (always long enough for every update). It then prints the counter, the expected value (sum of all `updates`) and a verdict: `RESULT: RACE` if two read-modify-writes ever overlapped, `RESULT: INCOMPLETE` if updates are missing, otherwise `RESULT: OK`.

Timing: a task that holds the mutex keeps running until its write even when a higher-priority worker wakes up, because that worker blocks on the mutex (and the holder inherits its priority). When the holder gives the mutex, the waiting higher-priority task takes it and runs at the **same tick**.

**Input**
```
<n>
<name> <priority> <period> <work> <updates>     (n lines)
<D>
```

**Example**
```
Input:
2
A 2 5 3 3
B 1 4 4 2
40

Output:
[t=8] B wrote 1
[t=11] A wrote 2
[t=19] B wrote 3
[t=22] A wrote 4
[t=30] A wrote 5
odometer = 5 (expected 5)
RESULT: OK
```
At t=4 B takes the mutex and reads 0. At t=5 A wakes up and preempts B, but blocks on the mutex. B finishes its 4 ticks of work at t=8 and writes 1. A then gets the mutex at t=8, reads 1 and writes 2 at t=11. Without the mutex, A would read 0 at t=5 too, and one update would be lost.
@@@ constraints_md
- 1 <= n <= 4, priorities are different and in 1..6.
- 1 <= period <= 100, 1 <= work <= 20, 0 <= updates <= 10, D <= 3000.
- Stack size `configMINIMAL_STACK_SIZE` for every task. Simulated time: 1 tick = 1 ms; only `vTaskDelay`, blocking waits and `odo_work()` take time.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

typedef struct {
    const char *name;
    UBaseType_t priority;
    TickType_t  period;
    TickType_t  work;
    int         updates;
} WorkerCfg;

int  odo_read(void);
void odo_work(TickType_t ticks);
void odo_write(const char *who, int value);

static void worker_task(void *pvParameters)
{
    /* TODO: repeat cfg->updates times:
       vTaskDelay(period); lock; v = odo_read(); odo_work(work); odo_write(name, v + 1); unlock;
       then vTaskDelete(NULL). */
    (void)pvParameters;
    vTaskDelete(NULL);
}

void app_start(const WorkerCfg *cfg, int n)
{
    /* TODO: create the mutex and one task per worker */
    (void)cfg;
    (void)n;
    (void)worker_task;
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "sim.h"

static int g_odometer;
static int g_in_rmw;
static int g_overlaps;
static int g_writes;

int odo_read(void)
{
    g_in_rmw++;
    if (g_in_rmw > 1) g_overlaps++;
    return g_odometer;
}

void odo_work(TickType_t ticks)
{
    vSimBusyWork(ticks);
}

void odo_write(const char *who, int value)
{
    g_odometer = value;
    if (g_in_rmw > 0) g_in_rmw--;
    g_writes++;
    printf("[t=%u] %s wrote %d\n", (unsigned)xTaskGetTickCount(), who, value);
}

#undef xSemaphoreCreateBinary
#undef xSemaphoreCreateCounting
#define xSemaphoreCreateBinary() xSemaphoreCreateBinary_is_not_allowed_use_a_mutex()
#define xSemaphoreCreateCounting(a, b) xSemaphoreCreateCounting_is_not_allowed_use_a_mutex()
#define vTaskSuspendAll() vTaskSuspendAll_is_not_allowed_here()
#define vTaskPrioritySet(t, p) vTaskPrioritySet_is_not_allowed_here()

/*USER_CODE*/

#undef xSemaphoreCreateBinary
#undef xSemaphoreCreateCounting
#undef vTaskSuspendAll
#undef vTaskPrioritySet

int main(void)
{
    static char names[4][8];
    static WorkerCfg cfg[4];
    int n, i, expected = 0;
    unsigned prio, period, work, dur;
    int updates;

    if (scanf("%d", &n) != 1 || n < 1 || n > 4) return 1;
    for (i = 0; i < n; i++) {
        if (scanf("%7s %u %u %u %d", names[i], &prio, &period, &work, &updates) != 5) return 1;
        cfg[i].name = names[i];
        cfg[i].priority = (UBaseType_t)prio;
        cfg[i].period = (TickType_t)period;
        cfg[i].work = (TickType_t)work;
        cfg[i].updates = updates;
        expected += updates;
    }
    if (scanf("%u", &dur) != 1) return 1;

    app_start(cfg, n);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("odometer = %d (expected %d)\n", g_odometer, expected);
    if (g_overlaps > 0 || g_odometer != g_writes)
        printf("RESULT: RACE\n");
    else if (g_writes != expected)
        printf("RESULT: INCOMPLETE\n");
    else
        printf("RESULT: OK\n");
    return 0;
}
@@@ sample_input
2
A 2 5 3 3
B 1 4 4 2
40
@@@ sample_output
[t=8] B wrote 1
[t=11] A wrote 2
[t=19] B wrote 3
[t=22] A wrote 4
[t=30] A wrote 5
odometer = 5 (expected 5)
RESULT: OK
@@@ sample_input
3
C 1 2 6 1
A 3 3 1 2
B 2 4 2 1
40
@@@ sample_output
[t=8] C wrote 1
[t=9] A wrote 2
[t=11] B wrote 3
[t=13] A wrote 4
odometer = 4 (expected 4)
RESULT: OK
@@@ hidden_input
1
X 1 1 1 5
30
@@@ hidden_output
[t=2] X wrote 1
[t=4] X wrote 2
[t=6] X wrote 3
[t=8] X wrote 4
[t=10] X wrote 5
odometer = 5 (expected 5)
RESULT: OK
@@@ hidden_input
2
A 4 10 2 0
B 2 3 2 2
20
@@@ hidden_output
[t=5] B wrote 1
[t=10] B wrote 2
odometer = 2 (expected 2)
RESULT: OK
@@@ hidden_input
3
L 1 10 5 2
M 2 10 5 2
H 3 10 5 2
200
@@@ hidden_output
[t=15] H wrote 1
[t=20] M wrote 2
[t=25] L wrote 3
[t=30] H wrote 4
[t=35] M wrote 5
[t=50] L wrote 6
odometer = 6 (expected 6)
RESULT: OK

@@@ hidden_input
4
A 1 7 9 3
B 2 5 4 4
C 5 3 2 5
D 6 11 1 2
300
@@@ hidden_output
[t=5] C wrote 1
[t=9] B wrote 2
[t=11] C wrote 3
[t=12] D wrote 4
[t=21] A wrote 5
[t=23] C wrote 6
[t=24] D wrote 7
[t=28] B wrote 8
[t=30] C wrote 9
[t=35] C wrote 10
[t=39] B wrote 11
[t=48] A wrote 12
[t=52] B wrote 13
[t=68] A wrote 14
odometer = 14 (expected 14)
RESULT: OK

@@@ hidden_input
2
S 1 1 20 2
F 6 2 1 10
500
@@@ hidden_output
[t=21] S wrote 1
[t=22] F wrote 2
[t=43] S wrote 3
[t=44] F wrote 4
[t=47] F wrote 5
[t=50] F wrote 6
[t=53] F wrote 7
[t=56] F wrote 8
[t=59] F wrote 9
[t=62] F wrote 10
[t=65] F wrote 11
[t=68] F wrote 12
odometer = 12 (expected 12)
RESULT: OK

@@@ hint
The mutex must be created in `app_start()` (before any task runs) and live in a `static` variable that every task can see. Pass each task its own `WorkerCfg` through `pvParameters`.
@@@ hint
Wrap the whole sequence: `xSemaphoreTake(mtx, portMAX_DELAY); v = odo_read(); odo_work(c->work); odo_write(c->name, v + 1); xSemaphoreGive(mtx);`. A lock around only the read or only the write still loses updates.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

typedef struct {
    const char *name;
    UBaseType_t priority;
    TickType_t  period;
    TickType_t  work;
    int         updates;
} WorkerCfg;

int  odo_read(void);
void odo_work(TickType_t ticks);
void odo_write(const char *who, int value);

static SemaphoreHandle_t s_odo_mutex;

static void worker_task(void *pvParameters)
{
    const WorkerCfg *c = (const WorkerCfg *)pvParameters;
    int i, v;

    for (i = 0; i < c->updates; i++) {
        vTaskDelay(c->period);
        xSemaphoreTake(s_odo_mutex, portMAX_DELAY);   /* whole read-modify-write is the critical section */
        v = odo_read();
        odo_work(c->work);                            /* may be preempted: others block on the mutex */
        odo_write(c->name, v + 1);
        xSemaphoreGive(s_odo_mutex);
    }
    vTaskDelete(NULL);
}

void app_start(const WorkerCfg *cfg, int n)
{
    int i;

    s_odo_mutex = xSemaphoreCreateMutex();
    for (i = 0; i < n; i++) {
        xTaskCreate(worker_task, cfg[i].name, configMINIMAL_STACK_SIZE,
                    (void *)&cfg[i], cfg[i].priority, NULL);
    }
}
@@@ explanation_md
**Approach.** The counter update is a read-modify-write that takes CPU time. If a higher-priority worker preempts a lower one between `odo_read()` and `odo_write()`, both read the same old value and one increment is lost. A FreeRTOS mutex around the **whole** sequence serialises the updates: a preempting worker calls `xSemaphoreTake()`, finds the mutex held and blocks, so the holder continues and finishes its write. Its `xSemaphoreGive()` unblocks the highest-priority waiter, which runs at the same tick (that is why `A` writes at t=8+3 in the example).

A FreeRTOS mutex also has **priority inheritance**: while `A` waits, `B` runs at `A`'s priority, so a medium-priority task cannot delay the update. In this question it changes nothing visible, but it is the reason to prefer a mutex over a binary semaphore for mutual exclusion.

**Complexity.** O(1) per update plus one event-list insertion for each task that has to wait. The worst-case blocking time of a worker is the longest critical section of any other worker (`work` of the holder). RAM: one mutex (a queue object of about 80 bytes) plus one TCB and stack per task.

**Common mistakes**
- Locking only `odo_read()` or only `odo_write()`. Each call is protected, but the sequence is not atomic, so updates are still lost.
- Creating the mutex inside the task function: every task creates its own mutex, which protects nothing.
- Forgetting `xSemaphoreGive()` on one path: the other workers block forever.
- Using a critical section (`taskENTER_CRITICAL`) around slow work. It blocks every interrupt for the whole computation (and is a Runtime Error in the simulator when ticks must advance inside it).
- Returning from the task after the last update instead of calling `vTaskDelete(NULL)`.

**Interview follow-ups**
- Why is a mutex preferred over a binary semaphore for mutual exclusion? (Priority inheritance, ownership.)
- The counter is a single `uint32_t` updated without the slow work: is it atomic on a Cortex-M? What about a `uint64_t`?
- When is a critical section (`taskENTER_CRITICAL`) or `vTaskSuspendAll()` a better choice than a mutex?
- Can you take a mutex from an ISR? What would you do if an ISR also has to update the counter?
