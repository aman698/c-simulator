@@@ meta
id: RSM-E-03
topic: Semaphores & Mutexes
difficulty: Easy
type: FUNCTION
title: Binary Semaphore Signal Between Two Tasks With a Watchdog Timeout
tags: freertos, binary-semaphore, task-synchronization, timeout, signalling, embedded
@@@ statement_md
A sensor task **P** tells a processing task **C** that a new frame is ready. They synchronise with a **binary semaphore**: P gives it, C takes it. C must not wait forever: if no frame arrives within `timeout` ticks it reports a timeout (a software watchdog) and waits again.

```c
typedef struct {
    UBaseType_t       prod_priority;  /* priority of task P */
    UBaseType_t       cons_priority;  /* priority of task C */
    int               n_events;       /* number of frames */
    const TickType_t *events;         /* absolute ticks of the frames, non-decreasing, >= 1 */
    TickType_t        timeout;        /* C's watchdog timeout */
    TickType_t        work;           /* C's CPU time to process one frame */
} SigCfg;

/* provided by the hidden harness */
void producer_signal(void);         /* prints "[t=<tick>] P signal" */
void consumer_got(void);            /* prints "[t=<tick>] C got signal" */
void consumer_timeout(void);        /* prints "[t=<tick>] C timeout" */
void process_frame(TickType_t work);/* CPU-bound, takes `work` ticks of CPU time */

void app_start(const SigCfg *cfg);  /* you write this (and both task functions) */
```

`app_start()` is called **before** the scheduler starts. It creates the semaphore and the two tasks with the given priorities.

- **P**, for each frame `i`: if the current tick is earlier than `events[i]`, `vTaskDelay(events[i] - now)`; then `producer_signal()` and give the semaphore. After the last frame P deletes itself. With `n_events = 0` it deletes itself at once.
- **C**, forever: take the semaphore with a timeout of `timeout` ticks. On success call `consumer_got()` then `process_frame(work)`; on timeout call `consumer_timeout()`.

A binary semaphore holds **at most one** pending signal: a give while a signal is already pending is lost (the give fails). That is the behaviour being tested, so a counting semaphore or a queue is not allowed (they do not compile in this exercise).

**How it is tested.** The hidden `main()` reads the configuration and a duration `D`, calls `app_start()` and runs the scheduler up to and including tick `D`. Then it prints how many signals P sent, how many C handled and how many timeouts occurred.

Timing rules: when a give unblocks C and C has the higher priority, C preempts P at the same tick. If C has the lower priority, it runs only after P blocks. `process_frame()` takes CPU time, so a higher-priority P that wakes up preempts it. A timeout of `timeout` ticks that starts at tick `t` expires at tick `t + timeout`.

**Input**
```
<prod_priority> <cons_priority> <timeout> <work>
<n_events> <event ticks...>
<D>
```

**Example**
```
Input:
3 2 8 4
4 5 6 6 20
39

Output:
[t=5] P signal
[t=5] C got signal
[t=6] P signal
[t=6] P signal
[t=9] C got signal
[t=20] P signal
[t=20] C got signal
[t=32] C timeout
signals 4, handled 3, timeouts 1
```
At t=5 C gets the first frame and starts 4 ticks of work. P (higher priority) preempts it at t=6 and signals twice. The first give stores one pending signal, the second is lost. C finishes at t=9, takes the pending signal immediately and finishes again at t=13. Its next wait is satisfied by the frame at t=20; after that frame (done at t=24) nothing arrives and the watchdog fires at t=24+8=32.
@@@ constraints_md
- Priorities are different and in 1..6. 1 <= timeout <= 100, 1 <= work <= 20.
- 0 <= n_events <= 20, event ticks in 1..1000, D <= 2000.
- Stack size `configMINIMAL_STACK_SIZE` for both tasks. Simulated time: 1 tick = 1 ms.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

typedef struct {
    UBaseType_t       prod_priority;
    UBaseType_t       cons_priority;
    int               n_events;
    const TickType_t *events;
    TickType_t        timeout;
    TickType_t        work;
} SigCfg;

void producer_signal(void);
void consumer_got(void);
void consumer_timeout(void);
void process_frame(TickType_t work);

static void producer_task(void *pvParameters)
{
    /* TODO: wait for each event tick, producer_signal(), give the semaphore */
    (void)pvParameters;
    vTaskDelete(NULL);
}

static void consumer_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: take the semaphore with a timeout */
        vTaskDelay(1000);
    }
}

void app_start(const SigCfg *cfg)
{
    /* TODO: create the semaphore and the two tasks */
    (void)cfg;
    (void)producer_task;
    (void)consumer_task;
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "sim.h"

static int g_sent, g_handled, g_timeouts;

void producer_signal(void)
{
    g_sent++;
    printf("[t=%u] P signal\n", (unsigned)xTaskGetTickCount());
}

void consumer_got(void)
{
    g_handled++;
    printf("[t=%u] C got signal\n", (unsigned)xTaskGetTickCount());
}

void consumer_timeout(void)
{
    g_timeouts++;
    printf("[t=%u] C timeout\n", (unsigned)xTaskGetTickCount());
}

void process_frame(TickType_t work)
{
    vSimBusyWork(work);
}

#undef xSemaphoreCreateCounting
#undef xSemaphoreCreateMutex
#undef xQueueCreate
#define xSemaphoreCreateCounting(a, b) xSemaphoreCreateCounting_is_not_allowed_use_a_binary_semaphore()
#define xSemaphoreCreateMutex() xSemaphoreCreateMutex_is_not_allowed_use_a_binary_semaphore()
#define xQueueCreate(a, b) xQueueCreate_is_not_allowed_use_a_binary_semaphore()

/*USER_CODE*/

#undef xSemaphoreCreateCounting
#undef xSemaphoreCreateMutex
#undef xQueueCreate

int main(void)
{
    static TickType_t events[20];
    static SigCfg cfg;
    unsigned pp, cp, to, work, ev, d;
    int n, i;

    if (scanf("%u %u %u %u", &pp, &cp, &to, &work) != 4) return 1;
    if (scanf("%d", &n) != 1 || n < 0 || n > 20) return 1;
    for (i = 0; i < n; i++) {
        if (scanf("%u", &ev) != 1) return 1;
        events[i] = (TickType_t)ev;
    }
    if (scanf("%u", &d) != 1) return 1;

    cfg.prod_priority = (UBaseType_t)pp;
    cfg.cons_priority = (UBaseType_t)cp;
    cfg.n_events = n;
    cfg.events = events;
    cfg.timeout = (TickType_t)to;
    cfg.work = (TickType_t)work;

    app_start(&cfg);
    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();

    printf("signals %d, handled %d, timeouts %d\n", g_sent, g_handled, g_timeouts);
    return 0;
}
@@@ sample_input
3 2 8 4
4 5 6 6 20
39
@@@ sample_output
[t=5] P signal
[t=5] C got signal
[t=6] P signal
[t=6] P signal
[t=9] C got signal
[t=20] P signal
[t=20] C got signal
[t=32] C timeout
signals 4, handled 3, timeouts 1
@@@ sample_input
1 4 5 1
2 3 15
30
@@@ sample_output
[t=3] P signal
[t=3] C got signal
[t=9] C timeout
[t=14] C timeout
[t=15] P signal
[t=15] C got signal
[t=21] C timeout
[t=26] C timeout
signals 2, handled 2, timeouts 4
@@@ hidden_input
2 1 7 1
0
24
@@@ hidden_output
[t=7] C timeout
[t=14] C timeout
[t=21] C timeout
signals 0, handled 0, timeouts 3
@@@ hidden_input
5 3 50 2
3 1 1 1
40
@@@ hidden_output
[t=1] P signal
[t=1] P signal
[t=1] P signal
[t=1] C got signal
signals 3, handled 1, timeouts 0
@@@ hidden_input
2 5 50 3
3 4 4 4
40
@@@ hidden_output
[t=4] P signal
[t=4] C got signal
[t=7] P signal
[t=7] C got signal
[t=10] P signal
[t=10] C got signal
signals 3, handled 3, timeouts 0

@@@ hidden_input
6 1 20 5
6 2 3 4 10 30 31
95
@@@ hidden_output
[t=2] P signal
[t=2] C got signal
[t=3] P signal
[t=4] P signal
[t=7] C got signal
[t=10] P signal
[t=12] C got signal
[t=30] P signal
[t=30] C got signal
[t=31] P signal
[t=35] C got signal
[t=60] C timeout
[t=80] C timeout
signals 6, handled 5, timeouts 2

@@@ hidden_input
1 2 6 2
5 10 11 12 13 40
59
@@@ hidden_output
[t=6] C timeout
[t=10] P signal
[t=10] C got signal
[t=12] P signal
[t=12] C got signal
[t=14] P signal
[t=14] C got signal
[t=16] P signal
[t=16] C got signal
[t=24] C timeout
[t=30] C timeout
[t=36] C timeout
[t=40] P signal
[t=40] C got signal
[t=48] C timeout
[t=54] C timeout
signals 5, handled 5, timeouts 6

@@@ hint
`xSemaphoreCreateBinary()` creates the semaphore **empty** (no pending signal), which is what you want here. Store the handle in a `static` variable that both tasks can see.
@@@ hint
Consumer: `if (xSemaphoreTake(sem, cfg->timeout) == pdTRUE) { consumer_got(); process_frame(cfg->work); } else { consumer_timeout(); }`. Producer: `now = xTaskGetTickCount(); if (now < ev) vTaskDelay(ev - now); producer_signal(); xSemaphoreGive(sem);`.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

typedef struct {
    UBaseType_t       prod_priority;
    UBaseType_t       cons_priority;
    int               n_events;
    const TickType_t *events;
    TickType_t        timeout;
    TickType_t        work;
} SigCfg;

void producer_signal(void);
void consumer_got(void);
void consumer_timeout(void);
void process_frame(TickType_t work);

static SemaphoreHandle_t s_frame_ready;

static void producer_task(void *pvParameters)
{
    const SigCfg *c = (const SigCfg *)pvParameters;
    int i;

    for (i = 0; i < c->n_events; i++) {
        TickType_t now = xTaskGetTickCount();
        if (now < c->events[i]) vTaskDelay(c->events[i] - now);
        producer_signal();
        (void)xSemaphoreGive(s_frame_ready);   /* fails (pdFALSE) if a signal is already pending */
    }
    vTaskDelete(NULL);
}

static void consumer_task(void *pvParameters)
{
    const SigCfg *c = (const SigCfg *)pvParameters;

    for (;;) {
        if (xSemaphoreTake(s_frame_ready, c->timeout) == pdTRUE) {
            consumer_got();
            process_frame(c->work);
        } else {
            consumer_timeout();                /* watchdog: no frame within c->timeout ticks */
        }
    }
}

void app_start(const SigCfg *cfg)
{
    s_frame_ready = xSemaphoreCreateBinary();  /* created empty */
    xTaskCreate(producer_task, "P", configMINIMAL_STACK_SIZE, (void *)cfg, cfg->prod_priority, NULL);
    xTaskCreate(consumer_task, "C", configMINIMAL_STACK_SIZE, (void *)cfg, cfg->cons_priority, NULL);
}
@@@ explanation_md
**Approach.** A binary semaphore is a one-slot event flag. `xSemaphoreCreateBinary()` creates it empty. P gives it to say "a frame is ready"; C blocks in `xSemaphoreTake(sem, timeout)` and wakes up either when P gives it (returns `pdTRUE`) or when the timeout expires (returns `pdFALSE`, the watchdog path). The consumer never polls, so it costs no CPU while waiting.

Because there is only one slot, signals given while one is already pending are **lost**. In the example P signals twice at t=6 while C is still busy with the frame from t=5, so C handles only one of them. That is fine for "something changed, go and look" events (C reads the latest data anyway) and wrong for events that must be counted. Use a counting semaphore or a queue for those.

Who runs first after a give depends on priorities only: a higher-priority C preempts P inside `xSemaphoreGive()`. A lower-priority C runs when P blocks again.

**Complexity.** O(1) per give/take. Signal latency: zero ticks if C has the higher priority and is waiting, otherwise until P blocks (plus C's current `work` if it is busy). RAM: one queue object without storage (about 80 bytes).

**Common mistakes**
- Expecting a binary semaphore to count events: bursts collapse into one signal.
- `vSemaphoreCreateBinary()` (old macro) creates the semaphore **already given**; `xSemaphoreCreateBinary()` creates it empty. Mixing them up produces a phantom first event.
- Waiting with `portMAX_DELAY` when the design needs a watchdog: a dead sensor then hangs the consumer silently.
- Using a mutex for signalling: a mutex must be given back by the task that took it, and priority inheritance makes no sense for events.
- `vTaskDelayUntil()` with an increment of 0 for two frames at the same tick: it asserts. Compute the delay and skip it when the event is already due.

**Interview follow-ups**
- How would you change the design so that no frame is ever lost? (Counting semaphore, or a queue carrying the frame index.)
- Direct-to-task notifications as a lighter binary semaphore: how much faster and smaller, and what are their limits?
- The frame-ready event comes from a DMA ISR: which API do you use and why `portYIELD_FROM_ISR()`?
- How would you detect that the consumer is too slow (overrun counter)?
