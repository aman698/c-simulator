@@@ meta
id: RSM-E-02
topic: Semaphores & Mutexes
difficulty: Easy
type: FUNCTION
title: DMA Channel Pool With a Counting Semaphore
tags: freertos, counting-semaphore, resource-pool, timeout, dma, embedded
@@@ statement_md
A microcontroller has `K` identical DMA channels. Several driver tasks need a channel for a transfer. A **counting semaphore** whose count is the number of free channels guards the pool: take it to reserve a channel, give it back when the transfer is done.

```c
typedef struct {
    const char *name;      /* "A", "B", ... */
    UBaseType_t priority;  /* FreeRTOS priority of the task */
    TickType_t  start;     /* ticks to wait before requesting a channel */
    TickType_t  duration;  /* transfer time in ticks */
    TickType_t  max_wait;  /* longest time to wait for a free channel */
} DmaJob;

/* provided by the hidden harness */
void dma_transfer(const char *name, TickType_t duration);
        /* prints "[t=<tick>] <name> start (in use <u>/<K>)", sleeps `duration` ticks
           (the DMA hardware does the copy), then prints "[t=<tick>] <name> done" */
void dma_timeout(const char *name);   /* prints "[t=<tick>] <name> timeout" */

void app_start(int channels, const DmaJob *jobs, int n);   /* you write this (and the task function) */
```

`app_start()` is called **before** the scheduler starts. It creates the semaphore for `channels` channels (all free at the start) and **one task per job** with the job's `priority`. Each job task:

1. `vTaskDelay(start)`,
2. waits at most `max_wait` ticks for a free channel,
3. on success: `dma_transfer(name, duration)`, then gives the channel back; on timeout: `dma_timeout(name)`,
4. deletes itself with `vTaskDelete(NULL)`.

**How it is tested.** The hidden `main()` reads `K`, the jobs and a duration `D`, calls `app_start()`, runs the scheduler up to and including tick `D` and prints the number of completed transfers, timeouts and the largest number of channels ever in use at once (it must never exceed `K`).

Timing rules:
- When a channel is given back and several tasks are waiting, FreeRTOS wakes the **highest-priority** waiter (not the one that waited longest), which takes the channel. If that waiter has a higher priority than the task that gave the channel, it runs at once, at the same tick.
- When several tasks become ready at the same tick, the higher-priority one runs first.
- `max_wait = 0` means "try once, do not wait".

**Input**
```
<K> <n>
<name> <priority> <start> <duration> <max_wait>     (n lines)
<D>
```

**Example**
```
Input:
1 3
L 1 1 5 100
M 2 2 2 100
H 3 3 2 100
50

Output:
[t=1] L start (in use 1/1)
[t=6] L done
[t=6] H start (in use 1/1)
[t=8] H done
[t=8] M start (in use 1/1)
[t=10] M done
completed 3, timeouts 0, max in use 1 of 1
```
M starts waiting at t=2 and H at t=3. When L gives the channel back at t=6, H gets it first because it has the higher priority, and preempts L immediately.
@@@ constraints_md
- 1 <= K <= 4, 1 <= n <= 6, priorities are different and in 1..6.
- 1 <= start, duration <= 1000, 0 <= max_wait <= 1000, D <= 5000 (long enough for every job to finish).
- Stack size `configMINIMAL_STACK_SIZE` for every task. Simulated time: 1 tick = 1 ms.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

typedef struct {
    const char *name;
    UBaseType_t priority;
    TickType_t  start;
    TickType_t  duration;
    TickType_t  max_wait;
} DmaJob;

void dma_transfer(const char *name, TickType_t duration);
void dma_timeout(const char *name);

static void job_task(void *pvParameters)
{
    const DmaJob *j = (const DmaJob *)pvParameters;

    vTaskDelay(j->start);
    /* TODO: reserve a channel (wait at most j->max_wait ticks) and release it afterwards */
    dma_transfer(j->name, j->duration);
    vTaskDelete(NULL);
}

void app_start(int channels, const DmaJob *jobs, int n)
{
    int i;

    /* TODO: create the channel pool semaphore */
    (void)channels;
    for (i = 0; i < n; i++) {
        xTaskCreate(job_task, jobs[i].name, configMINIMAL_STACK_SIZE,
                    (void *)&jobs[i], jobs[i].priority, NULL);
    }
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "sim.h"

static int g_channels;
static int g_in_use;
static int g_max_in_use;
static int g_completed;
static int g_timeouts;

void dma_transfer(const char *name, TickType_t duration)
{
    g_in_use++;
    if (g_in_use > g_max_in_use) g_max_in_use = g_in_use;
    printf("[t=%u] %s start (in use %d/%d)\n", (unsigned)xTaskGetTickCount(), name, g_in_use, g_channels);
    vTaskDelay(duration);
    g_in_use--;
    g_completed++;
    printf("[t=%u] %s done\n", (unsigned)xTaskGetTickCount(), name);
}

void dma_timeout(const char *name)
{
    g_timeouts++;
    printf("[t=%u] %s timeout\n", (unsigned)xTaskGetTickCount(), name);
}

/*USER_CODE*/

int main(void)
{
    static char names[6][8];
    static DmaJob jobs[6];
    int k, n, i;
    unsigned prio, start, dur, wait, d;

    if (scanf("%d %d", &k, &n) != 2 || n < 1 || n > 6) return 1;
    for (i = 0; i < n; i++) {
        if (scanf("%7s %u %u %u %u", names[i], &prio, &start, &dur, &wait) != 5) return 1;
        jobs[i].name = names[i];
        jobs[i].priority = (UBaseType_t)prio;
        jobs[i].start = (TickType_t)start;
        jobs[i].duration = (TickType_t)dur;
        jobs[i].max_wait = (TickType_t)wait;
    }
    if (scanf("%u", &d) != 1) return 1;

    g_channels = k;
    app_start(k, jobs, n);
    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();

    printf("completed %d, timeouts %d, max in use %d of %d\n", g_completed, g_timeouts, g_max_in_use, g_channels);
    if (g_max_in_use > g_channels) printf("OVERBOOKED\n");
    return 0;
}
@@@ sample_input
1 3
L 1 1 5 100
M 2 2 2 100
H 3 3 2 100
50
@@@ sample_output
[t=1] L start (in use 1/1)
[t=6] L done
[t=6] H start (in use 1/1)
[t=8] H done
[t=8] M start (in use 1/1)
[t=10] M done
completed 3, timeouts 0, max in use 1 of 1
@@@ sample_input
2 4
A 3 1 10 50
B 2 2 5 50
C 1 3 4 50
D 4 4 3 2
60
@@@ sample_output
[t=1] A start (in use 1/2)
[t=2] B start (in use 2/2)
[t=6] D timeout
[t=7] B done
[t=7] C start (in use 2/2)
[t=11] A done
[t=11] C done
completed 3, timeouts 1, max in use 2 of 2
@@@ hidden_input
3 5
P 1 5 10 100
Q 2 5 10 100
R 3 5 10 100
S 4 5 10 100
T 5 5 10 100
100
@@@ hidden_output
[t=5] T start (in use 1/3)
[t=5] S start (in use 2/3)
[t=5] R start (in use 3/3)
[t=15] T done
[t=15] S done
[t=15] R done
[t=15] Q start (in use 1/3)
[t=15] P start (in use 2/3)
[t=25] Q done
[t=25] P done
completed 5, timeouts 0, max in use 3 of 3
@@@ hidden_input
4 2
X 2 1 1 0
Y 1 1 1000 0
1100
@@@ hidden_output
[t=1] X start (in use 1/4)
[t=1] Y start (in use 2/4)
[t=2] X done
[t=1001] Y done
completed 2, timeouts 0, max in use 2 of 4
@@@ hidden_input
1 3
A 1 1 20 0
B 2 5 3 0
C 3 10 3 15
100
@@@ hidden_output
[t=1] A start (in use 1/1)
[t=5] B timeout
[t=21] A done
[t=21] C start (in use 1/1)
[t=24] C done
completed 2, timeouts 1, max in use 1 of 1

@@@ hidden_input
2 6
A 6 3 7 4
B 5 3 9 30
C 4 3 2 4
D 3 4 6 1
E 2 8 5 40
F 1 9 1 12
200
@@@ hidden_output
[t=3] A start (in use 1/2)
[t=3] B start (in use 2/2)
[t=5] D timeout
[t=7] C timeout
[t=10] A done
[t=10] E start (in use 2/2)
[t=12] B done
[t=12] F start (in use 2/2)
[t=13] F done
[t=15] E done
completed 4, timeouts 2, max in use 2 of 2

@@@ hidden_input
1 2
W 1 2 30 0
V 6 1 5 10
100
@@@ hidden_output
[t=1] V start (in use 1/1)
[t=2] W timeout
[t=6] V done
completed 1, timeouts 1, max in use 1 of 1

@@@ hint
Create the pool with `xSemaphoreCreateCounting(channels, channels)`: maximum count and **initial** count are both the number of free channels. An initial count of 0 would mean "no channel is free".
@@@ hint
In the task: `if (xSemaphoreTake(pool, j->max_wait) == pdTRUE) { dma_transfer(...); xSemaphoreGive(pool); } else { dma_timeout(j->name); }` then `vTaskDelete(NULL)`.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

typedef struct {
    const char *name;
    UBaseType_t priority;
    TickType_t  start;
    TickType_t  duration;
    TickType_t  max_wait;
} DmaJob;

void dma_transfer(const char *name, TickType_t duration);
void dma_timeout(const char *name);

static SemaphoreHandle_t s_pool;   /* count = number of free DMA channels */

static void job_task(void *pvParameters)
{
    const DmaJob *j = (const DmaJob *)pvParameters;

    vTaskDelay(j->start);
    if (xSemaphoreTake(s_pool, j->max_wait) == pdTRUE) {
        dma_transfer(j->name, j->duration);
        xSemaphoreGive(s_pool);           /* channel back to the pool */
    } else {
        dma_timeout(j->name);
    }
    vTaskDelete(NULL);
}

void app_start(int channels, const DmaJob *jobs, int n)
{
    int i;

    s_pool = xSemaphoreCreateCounting((UBaseType_t)channels, (UBaseType_t)channels);
    for (i = 0; i < n; i++) {
        xTaskCreate(job_task, jobs[i].name, configMINIMAL_STACK_SIZE,
                    (void *)&jobs[i], jobs[i].priority, NULL);
    }
}
@@@ explanation_md
**Approach.** A counting semaphore is a thread-safe counter of free resources. `xSemaphoreCreateCounting(K, K)` starts with all `K` channels free. `xSemaphoreTake(pool, max_wait)` decrements the count or blocks until another task gives a channel back (or the timeout expires). `xSemaphoreGive(pool)` increments it and unblocks the **highest-priority** waiting task. If that task has a higher priority than the giver, it preempts the giver immediately (H at t=6 in the example).

The semaphore only counts channels. If you also need to know *which* channel you got, keep a small free-list or bitmap protected by a mutex (or a critical section), and take the counting semaphore first so the list is never empty when you search it.

**Complexity.** O(1) per take/give plus an O(waiting tasks) sorted insertion into the semaphore's event list. Worst-case wait = the time until the earliest channel is released, bounded by `max_wait`. RAM: one queue object without a storage area (the count lives in the queue header).

**Common mistakes**
- `xSemaphoreCreateCounting(K, 0)`: the pool starts empty, so every job times out or blocks forever.
- Giving the semaphore back after a **timeout** (the task never owned a channel). The count grows beyond `K` and the pool is overbooked. FreeRTOS refuses a give above the maximum count, but only once it is already at `K`.
- Using a mutex for a pool of `K > 1` identical resources: only one user at a time.
- Expecting FIFO service. FreeRTOS wakes waiters in priority order (FIFO only among equal priorities).
- Waiting with `portMAX_DELAY` in a driver that has a deadline: use a timeout and report the error.

**Interview follow-ups**
- How would you also return the channel **number**? (Free bitmap + mutex, or a queue of channel IDs used as the pool.)
- Can the DMA-complete ISR give the semaphore? Which API and what about `portYIELD_FROM_ISR()`?
- Counting semaphore vs a queue of handles vs task notifications: memory and speed trade-offs.
- How do you avoid starvation of a low-priority job when high-priority jobs keep the pool busy?
