@@@ meta
id: RTK-H-03
topic: Tasks & Scheduling
difficulty: Hard
type: FUNCTION
title: Aging: Boost a Starving Low-Priority Task With vTaskPrioritySet
tags: freertos, starvation, aging, vtaskpriorityset, counting-semaphore, isr, embedded
@@@ statement_md
An ECU writes diagnostic log entries in a **priority-1 logger task**. Log requests come from an interrupt. When a priority-3 computation runs for a long time, the logger **starves**: its requests pile up and nothing is written. Implement **aging**. A priority-6 manager watches the logger and, when it has been waiting too long, temporarily **boosts** it above the computation for exactly one job.

```c
typedef struct {
    TickType_t check;     /* manager runs at t = check, 2*check, ... */
    TickType_t starve;    /* starvation threshold in ticks          */
} AgingCfg;

/* provided by the test harness */
void log_job(void);          /* writes one entry: CPU work + "[t=<tick>] logged #<k> (prio <p>)" */
void report_boost(void);     /* prints "[t=<tick>] logger boosted"  */
void report_restore(void);   /* prints "[t=<tick>] logger restored" */

void app_start(const AgingCfg *cfg);    /* create the logger (prio 1) and the manager (prio 6) */
void log_request_from_isr(void);        /* called in interrupt context, once per request */
```

**Logger** (priority **1**): waits for a request, calls `log_job()`, and repeats. Each request produces exactly one `log_job()`. Requests must not be lost, so use a counting semaphore (or an equivalent counter).

**Waiting time.** The logger has *pending work* while `requests - completed_jobs > 0`. A request whose job has started but not finished still counts. The **wait start** is set to the current tick when pending work goes from 0 to 1, and also every time a job completes while work is still pending.

**Manager** (priority **6**), at each run: if there is pending work, the logger is not boosted, and `now - wait_start >= starve`, then set the logger's priority to **4** with `vTaskPrioritySet()` and call `report_boost()`.

**Restore:** when the logger completes a job while boosted, it calls `report_restore()`, clears its boosted state, and only then sets its own priority back to **1**. Lowering its own priority below the computation's preempts the logger **immediately**, so anything done after `vTaskPrioritySet(NULL, 1)` would only happen once the computation blocks. One boost buys exactly one job.

**How it is tested.** The harness's computation task (priority 3) runs CPU bursts at given ticks. The harness also raises log-request interrupts at given ticks (several can share a tick). `log_job()` takes `job_cost` CPU ticks and prints the logger's priority at completion. After tick `D`, the harness prints the totals.

**Input**
```
<check> <starve> <job_cost> <D>
<r> <tick 1> ... <tick r>          request interrupts (non-decreasing)
<b>
<tick> <cost>                      b computation bursts (increasing, non-overlapping)
```

**Example**
```
Input:
5 10 2 60
2 3 4
1
2 40

Output:
[t=2] burst start
[t=15] logger boosted
[t=17] logged #1 (prio 4)
[t=17] logger restored
[t=30] logger boosted
[t=32] logged #2 (prio 4)
[t=32] logger restored
[t=46] burst end
logged: 2
boosts: 2
```
Requests arrive at t=3 and t=4, during the 40-tick burst, so the wait starts at t=3. The manager boosts the logger at t=15 (15 - 3 >= 10). The logger then preempts the burst, writes entry #1 and drops back to priority 1 at t=17. The second request has waited since t=17 and is boosted at t=30. The burst lost 4 ticks to the logger and ends at t=46 instead of t=42.
@@@ constraints_md
- 1 <= check <= 50, 1 <= starve <= 500, 1 <= job_cost <= 20, 1 <= D <= 5000, 0 <= r <= 40, 0 <= b <= 10, burst cost <= 1000.
- At most 100 requests can be pending. Stack size `configMINIMAL_STACK_SIZE`.
- `log_request_from_isr()` runs in interrupt context: only `...FromISR` APIs, and request a context switch with `portYIELD_FROM_ISR()`.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

typedef struct {
    TickType_t check;
    TickType_t starve;
} AgingCfg;

void log_job(void);
void report_boost(void);
void report_restore(void);

static const AgingCfg *g_cfg;
static SemaphoreHandle_t g_requests;
static TaskHandle_t g_logger;

static void logger_task(void *pv)
{
    (void)pv;
    for (;;) {
        xSemaphoreTake(g_requests, portMAX_DELAY);
        log_job();
    }
}

static void manager_task(void *pv)
{
    (void)pv;
    for (;;) {
        vTaskDelay(1000);     /* TODO: aging */
    }
}

void app_start(const AgingCfg *cfg)
{
    g_cfg = cfg;
    g_requests = xSemaphoreCreateCounting(100, 0);
    xTaskCreate(logger_task, "logger", configMINIMAL_STACK_SIZE, NULL, 1, &g_logger);
    xTaskCreate(manager_task, "aging", configMINIMAL_STACK_SIZE, NULL, 6, NULL);
}

void log_request_from_isr(void)
{
    BaseType_t woken = pdFALSE;
    xSemaphoreGiveFromISR(g_requests, &woken);
    portYIELD_FROM_ISR(woken);
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "sim.h"

static TickType_t g_job_cost;
static unsigned g_logged, g_boosts;

void log_job(void)
{
    vSimBusyWork(g_job_cost);
    g_logged++;
    printf("[t=%u] logged #%u (prio %d)\n", (unsigned)xTaskGetTickCount(), g_logged,
           (int)uxTaskPriorityGet(NULL));
}

void report_boost(void)
{
    g_boosts++;
    printf("[t=%u] logger boosted\n", (unsigned)xTaskGetTickCount());
}

void report_restore(void)
{
    printf("[t=%u] logger restored%s\n", (unsigned)xTaskGetTickCount(),
           uxTaskPriorityGet(NULL) == 4 ? "" : " (NOT BOOSTED)");
}

/*USER_CODE*/

static unsigned g_nb;
static TickType_t g_bt[10], g_bc[10];

static void burst_task(void *pv)
{
    unsigned i;
    (void)pv;
    for (i = 0; i < g_nb; i++) {
        TickType_t now = xTaskGetTickCount();
        if (g_bt[i] > now) vTaskDelay(g_bt[i] - now);
        printf("[t=%u] burst start\n", (unsigned)xTaskGetTickCount());
        vSimBusyWork(g_bc[i]);
        printf("[t=%u] burst end\n", (unsigned)xTaskGetTickCount());
    }
    vTaskDelete(NULL);
}

static void request_isr(void *arg)
{
    (void)arg;
    log_request_from_isr();
}

int main(void)
{
    static AgingCfg cfg;
    unsigned check, starve, cost, D, r, b, i, t, c;

    if (scanf("%u %u %u %u", &check, &starve, &cost, &D) != 4) return 1;
    cfg.check = (TickType_t)check;
    cfg.starve = (TickType_t)starve;
    g_job_cost = (TickType_t)cost;
    if (scanf("%u", &r) != 1 || r > 40) return 1;
    for (i = 0; i < r; i++) {
        if (scanf("%u", &t) != 1) return 1;
        xSimScheduleInterrupt((TickType_t)t, request_isr, NULL);
    }
    if (scanf("%u", &b) != 1 || b > 10) return 1;
    g_nb = b;
    for (i = 0; i < b; i++) {
        if (scanf("%u %u", &t, &c) != 2) return 1;
        g_bt[i] = (TickType_t)t;
        g_bc[i] = (TickType_t)c;
    }

    xTaskCreate(burst_task, "burst", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
    app_start(&cfg);
    vSimSetTickLimit((TickType_t)D);
    vTaskStartScheduler();
    printf("logged: %u\n", g_logged);
    printf("boosts: %u\n", g_boosts);
    return 0;
}
@@@ sample_input
5 10 2 60
2 3 4
1
2 40
@@@ sample_output
[t=2] burst start
[t=15] logger boosted
[t=17] logged #1 (prio 4)
[t=17] logger restored
[t=30] logger boosted
[t=32] logged #2 (prio 4)
[t=32] logger restored
[t=46] burst end
logged: 2
boosts: 2
@@@ sample_input
10 25 3 100
3 5 5 50
0
@@@ sample_output
[t=8] logged #1 (prio 1)
[t=11] logged #2 (prio 1)
[t=53] logged #3 (prio 1)
logged: 3
boosts: 0

@@@ hidden_input
5 5 1 40
4 1 1 1 1
1
1 30
@@@ hidden_output
[t=1] burst start
[t=10] logger boosted
[t=11] logged #1 (prio 4)
[t=11] logger restored
[t=20] logger boosted
[t=21] logged #2 (prio 4)
[t=21] logger restored
[t=30] logger boosted
[t=31] logged #3 (prio 4)
[t=31] logger restored
[t=34] burst end
[t=35] logged #4 (prio 1)
logged: 4
boosts: 3

@@@ hidden_input
4 8 5 80
3 10 12 30
2
5 20
28 30
@@@ hidden_output
[t=5] burst start
[t=20] logger boosted
[t=25] logged #1 (prio 4)
[t=25] logger restored
[t=30] burst end
[t=30] burst start
[t=36] logger boosted
[t=41] logged #2 (prio 4)
[t=41] logger restored
[t=52] logger boosted
[t=57] logged #3 (prio 4)
[t=57] logger restored
[t=70] burst end
logged: 3
boosts: 3

@@@ hidden_input
10 100 2 200
2 20 21
1
10 150
@@@ hidden_output
[t=10] burst start
[t=120] logger boosted
[t=122] logged #1 (prio 4)
[t=122] logger restored
[t=162] burst end
[t=164] logged #2 (prio 1)
logged: 2
boosts: 1

@@@ hidden_input
1 1 1 20
1 5
1
5 10
@@@ hidden_output
[t=5] burst start
[t=6] logger boosted
[t=7] logged #1 (prio 4)
[t=7] logger restored
[t=16] burst end
logged: 1
boosts: 1

@@@ hidden_input
3 6 4 60
0
1
1 50
@@@ hidden_output
[t=1] burst start
[t=51] burst end
logged: 0
boosts: 0

@@@ hint
Keep three shared variables: `requested` (incremented in the ISR function), `completed` (incremented by the logger) and `wait_start`. Pending work is `requested - completed`. Update `wait_start` exactly at the 0 -> 1 transition (in the ISR function) and after each completed job if work is still pending. Protect the task-side updates with `taskENTER_CRITICAL()`, because the ISR writes the same variables.
@@@ hint
Boost: the manager calls `vTaskPrioritySet(g_logger, 4)` and sets a `boosted` flag. Restore: after `log_job()`, the logger checks the flag, calls `report_restore()`, clears the flag, and calls `vTaskPrioritySet(NULL, 1)` **last**: from that call on, the computation can preempt it. Raising the priority of a ready task above the running one causes a preemption as soon as the manager blocks.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

typedef struct {
    TickType_t check;
    TickType_t starve;
} AgingCfg;

void log_job(void);
void report_boost(void);
void report_restore(void);

#define LOGGER_PRIO 1
#define BOOST_PRIO  4

static const AgingCfg *g_cfg;
static SemaphoreHandle_t g_requests;
static TaskHandle_t g_logger;

static volatile unsigned g_requested, g_completed;
static volatile TickType_t g_wait_start;
static volatile int g_boosted;

static void logger_task(void *pv)
{
    (void)pv;
    for (;;) {
        xSemaphoreTake(g_requests, portMAX_DELAY);
        log_job();

        taskENTER_CRITICAL();                    /* the ISR updates the same counters */
        g_completed++;
        if (g_requested != g_completed) g_wait_start = xTaskGetTickCount();
        taskEXIT_CRITICAL();

        if (g_boosted) {                         /* one boost = one job */
            report_restore();
            g_boosted = 0;
            vTaskPrioritySet(NULL, LOGGER_PRIO); /* may preempt us right here */
        }
    }
}

static void manager_task(void *pv)
{
    TickType_t last = xTaskGetTickCount();
    (void)pv;
    for (;;) {
        int starving;
        vTaskDelayUntil(&last, g_cfg->check);

        taskENTER_CRITICAL();
        starving = g_requested != g_completed && !g_boosted &&
                   (TickType_t)(xTaskGetTickCount() - g_wait_start) >= g_cfg->starve;
        taskEXIT_CRITICAL();

        if (starving) {
            g_boosted = 1;
            vTaskPrioritySet(g_logger, BOOST_PRIO);  /* logger runs once we block */
            report_boost();
        }
    }
}

void app_start(const AgingCfg *cfg)
{
    g_cfg = cfg;
    g_requests = xSemaphoreCreateCounting(100, 0);
    xTaskCreate(logger_task, "logger", configMINIMAL_STACK_SIZE, NULL, LOGGER_PRIO, &g_logger);
    xTaskCreate(manager_task, "aging", configMINIMAL_STACK_SIZE, NULL, 6, NULL);
}

void log_request_from_isr(void)
{
    BaseType_t woken = pdFALSE;
    UBaseType_t mask = taskENTER_CRITICAL_FROM_ISR();
    if (g_requested == g_completed) g_wait_start = xTaskGetTickCountFromISR();
    g_requested++;
    taskEXIT_CRITICAL_FROM_ISR(mask);

    xSemaphoreGiveFromISR(g_requests, &woken);
    portYIELD_FROM_ISR(woken);
}
@@@ explanation_md
**Approach.** A fixed-priority scheduler never runs a ready low-priority task while a higher-priority task is ready. If the priority-3 computation runs for 40 ticks, the logger waits 40 ticks no matter how old its requests are. **Aging** raises a waiting task's priority over time, so it eventually runs.

- *Counting, not flagging.* Each interrupt gives a counting semaphore once, so bursts of requests (four at t=1 in one test) are all served. A binary semaphore would merge them into one.
- *Pending work* is `requested - completed`. This includes a job that is preempted halfway, which the semaphore count would miss: the logger has already taken that one.
- *Wait start* moves at the 0 -> 1 transition and after each completed job. The manager measures how long the logger has gone without progress while it had work to do.
- *Boost* with `vTaskPrioritySet(logger, 4)` from the priority-6 manager. When the manager blocks, the scheduler picks the logger (4) over the computation (3).
- *Restore* right after the job. The logger lowers its own priority as its **last** action, because that call immediately hands the CPU back to the computation: `vTaskPrioritySet()` on yourself is a scheduling point. One boost buys one job, so the logger cannot steal the CPU for its whole backlog.

**Synchronisation.** The ISR and the tasks share the counters. The task side uses `taskENTER_CRITICAL()`. The ISR side uses `taskENTER_CRITICAL_FROM_ISR()`, because on a real Cortex-M the interrupt can preempt the task between reading and writing a counter.

**Complexity.** O(1) per request, per job and per manager run. The worst-case logging latency becomes bounded: about `starve + check + job_cost` per job, instead of unbounded (the length of the computation).

**Common mistakes**
- Boosting forever (never restoring). The logger then runs its whole backlog at priority 4 and starves the computation instead.
- Using the semaphore count (`uxSemaphoreGetCount`) as "pending work". It misses the job that is in progress.
- A binary semaphore or a flag for the requests: simultaneous requests are lost.
- Calling `vTaskPrioritySet` or `xSemaphoreGive` from the ISR function. These are task-only APIs (Runtime Error in the simulator).
- Clearing the `boosted` flag **after** `vTaskPrioritySet(NULL, 1)`. The logger is preempted inside that call, so the flag stays set for the whole rest of the burst and the manager never boosts again.
- Restoring the priority **before** `log_job()` finishes. The computation preempts the logger in the middle of the job, and the boost achieved nothing.
- Updating shared counters without a critical section. That is a real race on hardware, even if a single-core simulation rarely shows it.

**Interview follow-ups**
- Aging vs priority inheritance: which problem does each solve?
- Would you rather give the logger a higher base priority and rate-limit it? What are the trade-offs?
- How would you implement this without a manager task (for example, a timer callback or the logger measuring its own latency)?
- What does `vTaskPrioritySet()` do if the target task currently holds a mutex and has an inherited priority?
