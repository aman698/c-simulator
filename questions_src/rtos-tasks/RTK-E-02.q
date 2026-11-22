@@@ meta
id: RTK-E-02
topic: Tasks & Scheduling
difficulty: Easy
type: FUNCTION
title: Alarm Task Preempts Background Jobs
tags: freertos, preemption, priorities, vsimbusywork, embedded
@@@ statement_md
A body controller runs long **background jobs** (flash writes, checksum calculations). It also has a periodic **alarm** check that must run on time. Write the two tasks and give them priorities so that the alarm is never late.

```c
typedef struct {
    TickType_t alarm_period;  /* alarm runs at t = P, 2P, 3P, ... */
    TickType_t alarm_cost;    /* CPU ticks one alarm check takes */
    unsigned   job_count;     /* 1..16 */
    TickType_t job_cost[16];  /* CPU ticks each background job takes */
} Scenario;

/* provided by the test harness */
void log_job_start(unsigned job);   /* prints "[t=<tick>] job <n> start" */
void log_job_done(unsigned job);    /* prints "[t=<tick>] job <n> done"  */
void log_alarm(void);               /* prints "[t=<tick>] alarm"         */

void app_start(const Scenario *s);  /* you write this, plus the two tasks */
```

`app_start()` is called before the scheduler starts. It creates two tasks:

- **alarm task**, priority **3**:
  ```
  last = xTaskGetTickCount();
  forever: vTaskDelayUntil(&last, alarm_period); log_alarm(); vSimBusyWork(alarm_cost);
  ```
- **background task**, priority **1**: for each job `n = 1..job_count`: `log_job_start(n)`, `vSimBusyWork(job_cost[n-1])`, `log_job_done(n)`. Then it deletes itself with `vTaskDelete(NULL)`.

`vSimBusyWork(k)` (from `sim.h`) simulates `k` ticks of CPU work. While a task is inside it, the tick keeps running, and a higher-priority task that becomes ready **preempts** it immediately. The interrupted job continues afterwards.

**How it is tested.** The hidden `main()` reads the scenario and a duration `D`, calls `app_start()`, and runs the scheduler up to tick `D`. Then it prints the number of alarms and of finished jobs. `log_alarm()` checks that every alarm runs exactly at a multiple of the period and prints `LATE` otherwise.

**Input**
```
<alarm_period> <alarm_cost> <D>
<job_count>
<job_cost 1> ... <job_cost n>
```

**Example**
```
Input:
5 1 20
3
4 7 2

Output:
[t=0] job 1 start
[t=4] job 1 done
[t=4] job 2 start
[t=5] alarm
[t=10] alarm
[t=13] job 2 done
[t=13] job 3 start
[t=15] alarm
[t=16] job 3 done
[t=20] alarm
alarms: 4
jobs done: 3
```
Job 2 needs 7 ticks of CPU and starts at t=4. The alarms at t=5 and t=10 each take 1 tick away from it, so it finishes at 4 + 7 + 2 = 13. Job 3 is also interrupted by the alarm at t=15 and finishes at t=16. Note the rule this shows: when a job's last CPU tick ends exactly at the tick where the alarm becomes due, that tick interrupt switches to the alarm first. The job's `done` line comes after the alarm.
@@@ constraints_md
- 1 <= alarm_period <= 100, 0 <= alarm_cost < alarm_period, 1 <= job_count <= 16, 0 <= job_cost <= 200, 1 <= D <= 5000.
- Stack size `configMINIMAL_STACK_SIZE` for both tasks. The `Scenario` stays valid for the whole run.
- 1 tick = 1 ms. Code outside `vSimBusyWork()` and the blocking calls takes zero ticks.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

typedef struct {
    TickType_t alarm_period;
    TickType_t alarm_cost;
    unsigned   job_count;
    TickType_t job_cost[16];
} Scenario;

void log_job_start(unsigned job);
void log_job_done(unsigned job);
void log_alarm(void);

static void alarm_task(void *pv)
{
    /* TODO */
    (void)pv;
    for (;;) {
        vTaskDelay(1000);
    }
}

static void background_task(void *pv)
{
    /* TODO */
    (void)pv;
    vTaskDelete(NULL);
}

void app_start(const Scenario *s)
{
    /* TODO: create both tasks with the right priorities */
    (void)s;
    (void)alarm_task;
    (void)background_task;
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

static unsigned g_alarms, g_jobs_done;
static TickType_t g_period;

void log_job_start(unsigned job)
{
    printf("[t=%u] job %u start\n", (unsigned)xTaskGetTickCount(), job);
}

void log_job_done(unsigned job)
{
    printf("[t=%u] job %u done\n", (unsigned)xTaskGetTickCount(), job);
    g_jobs_done++;
}

void log_alarm(void)
{
    TickType_t now = xTaskGetTickCount();
    g_alarms++;
    if (now != g_alarms * g_period)
        printf("[t=%u] alarm LATE (due at t=%u)\n", (unsigned)now, (unsigned)(g_alarms * g_period));
    else
        printf("[t=%u] alarm\n", (unsigned)now);
}

/*USER_CODE*/

int main(void)
{
    static Scenario s;
    unsigned period, cost, dur, n, c, i;

    if (scanf("%u %u %u", &period, &cost, &dur) != 3) return 1;
    if (scanf("%u", &n) != 1 || n < 1 || n > 16) return 1;
    s.alarm_period = (TickType_t)period;
    s.alarm_cost = (TickType_t)cost;
    s.job_count = n;
    for (i = 0; i < n; i++) {
        if (scanf("%u", &c) != 1) return 1;
        s.job_cost[i] = (TickType_t)c;
    }
    g_period = s.alarm_period;

    app_start(&s);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("alarms: %u\n", g_alarms);
    printf("jobs done: %u\n", g_jobs_done);
    return 0;
}
@@@ sample_input
5 1 20
3
4 7 2
@@@ sample_output
[t=0] job 1 start
[t=4] job 1 done
[t=4] job 2 start
[t=5] alarm
[t=10] alarm
[t=13] job 2 done
[t=13] job 3 start
[t=15] alarm
[t=16] job 3 done
[t=20] alarm
alarms: 4
jobs done: 3
@@@ sample_input
10 0 30
2
25 3
@@@ sample_output
[t=0] job 1 start
[t=10] alarm
[t=20] alarm
[t=25] job 1 done
[t=25] job 2 start
[t=28] job 2 done
[t=30] alarm
alarms: 3
jobs done: 2
@@@ hidden_input
4 3 16
1
5
@@@ hidden_output
[t=0] job 1 start
[t=4] alarm
[t=8] alarm
[t=11] job 1 done
[t=12] alarm
[t=16] alarm
alarms: 4
jobs done: 1
@@@ hidden_input
3 2 12
4
0 0 1 0
@@@ hidden_output
[t=0] job 1 start
[t=0] job 1 done
[t=0] job 2 start
[t=0] job 2 done
[t=0] job 3 start
[t=1] job 3 done
[t=1] job 4 start
[t=1] job 4 done
[t=3] alarm
[t=6] alarm
[t=9] alarm
[t=12] alarm
alarms: 4
jobs done: 4
@@@ hidden_input
1 0 5
1
3
@@@ hidden_output
[t=0] job 1 start
[t=1] alarm
[t=2] alarm
[t=3] alarm
[t=3] job 1 done
[t=4] alarm
[t=5] alarm
alarms: 5
jobs done: 1
@@@ hidden_input
50 10 100
3
30 30 30
@@@ hidden_output
[t=0] job 1 start
[t=30] job 1 done
[t=30] job 2 start
[t=50] alarm
[t=70] job 2 done
[t=70] job 3 start
[t=100] alarm
alarms: 2
jobs done: 2
@@@ hidden_input
7 6 40
2
10 4
@@@ hidden_output
[t=0] job 1 start
[t=7] alarm
[t=14] alarm
[t=21] alarm
[t=28] alarm
[t=34] job 1 done
[t=34] job 2 start
[t=35] alarm
alarms: 5
jobs done: 1
@@@ hint
The scheduler always runs the highest-priority **ready** task. The alarm must have the higher priority, otherwise it waits until the background task blocks or deletes itself.
@@@ hint
Create both tasks in `app_start()` and pass `s` as `pvParameters` to both. In the background task, loop over `s->job_count` jobs, call `vSimBusyWork(s->job_cost[i])` between the two log calls, then call `vTaskDelete(NULL)`. Never `return` from a task function.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

typedef struct {
    TickType_t alarm_period;
    TickType_t alarm_cost;
    unsigned   job_count;
    TickType_t job_cost[16];
} Scenario;

void log_job_start(unsigned job);
void log_job_done(unsigned job);
void log_alarm(void);

static void alarm_task(void *pv)
{
    const Scenario *s = (const Scenario *)pv;
    TickType_t last = xTaskGetTickCount();

    for (;;) {
        vTaskDelayUntil(&last, s->alarm_period);
        log_alarm();
        vSimBusyWork(s->alarm_cost);
    }
}

static void background_task(void *pv)
{
    const Scenario *s = (const Scenario *)pv;
    unsigned n;

    for (n = 1; n <= s->job_count; n++) {
        log_job_start(n);
        vSimBusyWork(s->job_cost[n - 1]);   /* preempted whenever the alarm is due */
        log_job_done(n);
    }
    vTaskDelete(NULL);                      /* a task must never return */
}

void app_start(const Scenario *s)
{
    xTaskCreate(alarm_task, "alarm", configMINIMAL_STACK_SIZE, (void *)s, 3, NULL);
    xTaskCreate(background_task, "bg", configMINIMAL_STACK_SIZE, (void *)s, 1, NULL);
}
@@@ explanation_md
**Approach.** FreeRTOS is a **fixed-priority preemptive** scheduler: at every scheduling point (tick, blocking call, give or send that wakes a task), the highest-priority ready task gets the CPU. The alarm task spends almost all its time blocked in `vTaskDelayUntil()`. At each multiple of the period it becomes ready. Because it has priority 3 and the background task has priority 1, the tick interrupt switches to it immediately, even in the middle of a background job. The job resumes where it stopped once the alarm blocks again.

So a job of cost `c` that starts at `t0` finishes at `t0 + c + (alarm CPU time that falls inside the job)`. In the example, job 2 starts at t=4 with cost 7. It is interrupted by two alarms of 1 tick each, so it finishes at t=13.

At t=0 both tasks are ready. The alarm task runs first because of its priority and blocks at once in `vTaskDelayUntil()`, which is why `job 1 start` is logged at t=0.

**Complexity.** O(1) scheduler work per alarm (one context switch in, one out). The background task's response time grows by `alarm_cost` for every alarm that falls inside a job. That is exactly the "interference" term in response-time analysis: `R = C + sum(ceil(R / T_hp) * C_hp)`.

**Common mistakes**
- Swapping the priorities. The alarm then runs only between jobs, and the harness prints `LATE`.
- Using `vTaskDelay(period)` for the alarm. After the first alarm with non-zero cost, the alarm drifts by `alarm_cost` each period.
- Returning from `background_task` after the last job instead of calling `vTaskDelete(NULL)`. On a real port this jumps to an error handler. The simulator reports a Runtime Error.
- Replacing `vSimBusyWork()` by a plain `for` loop. In the simulator that takes zero ticks; on real hardware, a busy loop for timing is a bug anyway.

**Interview follow-ups**
- What is the worst-case response time of the background job? Write the response-time analysis recurrence.
- What changes if both tasks have the same priority (time slicing)?
- The alarm must also read data written by a background job. What can go wrong, and which primitive do you use?
- Why is `configUSE_PREEMPTION = 0` (cooperative scheduling) rarely used in automotive ECUs?
