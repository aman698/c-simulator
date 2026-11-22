@@@ meta
id: RTK-M-02
topic: Tasks & Scheduling
difficulty: Medium
type: FUNCTION
title: Urgent Poll: Wake a Sleeping Task Early With xTaskAbortDelay
tags: freertos, xtaskabortdelay, task-handle, etaskgetstate, polling, embedded
@@@ statement_md
A diagnostic task polls a slow sensor every `POLL` ticks. Sometimes the diagnostic manager needs a fresh value **right now**. It must not wait up to `POLL` ticks for the next regular poll.

```c
/* provided by the test harness */
void poll_sensor(int urgent);   /* prints "[t=<tick>] poll timer" or "[t=<tick>] poll urgent" */

void app_start(TickType_t poll_period, TickType_t poll_cost);  /* creates the poller (priority 2) */
int  on_urgent(void);           /* called by the manager task (priority 4) */
```

**Poller task** (priority **2**), forever:
1. `poll_sensor(urgent)`, where `urgent` says why this poll happens. The very first poll, at t=0, is a timer poll.
2. `vSimBusyWork(poll_cost)`: the poll takes CPU time.
3. Unless an urgent request is pending (see below), sleep `POLL` ticks with `vTaskDelay(POLL)`. If the sleep ends normally, the next poll is a **timer** poll. If it was cut short by `on_urgent()`, the next poll is **urgent**.

**`on_urgent()`** runs in the higher-priority manager task.
- If the poller is currently **sleeping** in its `vTaskDelay()`, end the sleep now with `xTaskAbortDelay()` and return 1 ("woke"). The poller then runs its urgent poll in the same tick, as soon as the manager blocks.
- Otherwise the poller is in the middle of a poll (preempted by the manager, or ready to run). Record a **pending** request and return 0 ("deferred"). After the current poll's work, the poller skips its sleep and does an urgent poll immediately. Several requests during one poll count as one.

**How it is tested.** The hidden manager task calls `on_urgent()` at the tick numbers given in the input and prints `[t=<tick>] urgent woke` or `[t=<tick>] urgent deferred` from the return value. The run ends at tick `D`. The harness then prints the counts of timer and urgent polls.

At a tick where the poller's sleep ends **and** an urgent request arrives, the manager (priority 4) runs first. The poller is then already ready, not sleeping, so the request is deferred. The same applies at the tick where a poll's CPU work ends: the poller is still inside that poll when the manager runs.

**Input**
```
<POLL> <poll_cost> <D>
<m> <tick 1> ... <tick m>      increasing urgent-request ticks (>= 1)
```

**Example**
```
Input:
10 2 40
3 13 17 21

Output:
[t=0] poll timer
[t=12] poll timer
[t=13] urgent deferred
[t=14] poll urgent
[t=17] urgent woke
[t=17] poll urgent
[t=21] urgent woke
[t=21] poll urgent
[t=33] poll timer
polls: timer=3 urgent=3
```
At t=13 the poller is in its 2-tick poll that started at t=12, so the request is deferred and served at t=14. At t=17 and t=21 the poller is asleep and is woken immediately. After the urgent poll at t=21, the next regular poll is `POLL` ticks after that poll's work ends (23 + 10 = 33).
@@@ constraints_md
- 1 <= POLL <= 200, 0 <= poll_cost < POLL, 1 <= D <= 5000, 0 <= m <= 30.
- No polling of a flag with short delays: the poller sleeps exactly one `vTaskDelay(POLL)` between regular polls.
- Stack size `configMINIMAL_STACK_SIZE`.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

void poll_sensor(int urgent);

static TickType_t g_poll, g_cost;

static void poller_task(void *pv)
{
    int urgent = 0;
    (void)pv;
    for (;;) {
        poll_sensor(urgent);
        vSimBusyWork(g_cost);
        vTaskDelay(g_poll);
        urgent = 0;           /* TODO: was the sleep cut short? */
    }
}

void app_start(TickType_t poll_period, TickType_t poll_cost)
{
    g_poll = poll_period;
    g_cost = poll_cost;
    xTaskCreate(poller_task, "poller", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
}

int on_urgent(void)
{
    /* TODO */
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

static unsigned g_timer_polls, g_urgent_polls;
static unsigned g_m;
static TickType_t g_req[30];

void poll_sensor(int urgent)
{
    printf("[t=%u] poll %s\n", (unsigned)xTaskGetTickCount(), urgent ? "urgent" : "timer");
    if (urgent) g_urgent_polls++;
    else g_timer_polls++;
}

/*USER_CODE*/

static void manager_task(void *pv)
{
    unsigned i;
    (void)pv;
    for (i = 0; i < g_m; i++) {
        TickType_t now = xTaskGetTickCount();
        int r;
        if (g_req[i] > now) vTaskDelay(g_req[i] - now);
        r = on_urgent();
        printf("[t=%u] urgent %s\n", (unsigned)xTaskGetTickCount(), r ? "woke" : "deferred");
    }
    vTaskDelete(NULL);
}

int main(void)
{
    unsigned poll, cost, dur, i, t;

    if (scanf("%u %u %u", &poll, &cost, &dur) != 3) return 1;
    if (scanf("%u", &g_m) != 1 || g_m > 30) return 1;
    for (i = 0; i < g_m; i++) {
        if (scanf("%u", &t) != 1) return 1;
        g_req[i] = (TickType_t)t;
    }
    xTaskCreate(manager_task, "manager", configMINIMAL_STACK_SIZE, NULL, 4, NULL);
    app_start((TickType_t)poll, (TickType_t)cost);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();
    printf("polls: timer=%u urgent=%u\n", g_timer_polls, g_urgent_polls);
    return 0;
}
@@@ sample_input
10 2 40
3 13 17 21
@@@ sample_output
[t=0] poll timer
[t=12] poll timer
[t=13] urgent deferred
[t=14] poll urgent
[t=17] urgent woke
[t=17] poll urgent
[t=21] urgent woke
[t=21] poll urgent
[t=33] poll timer
polls: timer=3 urgent=3
@@@ sample_input
50 0 120
0
@@@ sample_output
[t=0] poll timer
[t=50] poll timer
[t=100] poll timer
polls: timer=3 urgent=0
@@@ hidden_input
10 5 30
3 1 2 3
@@@ hidden_output
[t=0] poll timer
[t=1] urgent deferred
[t=2] urgent deferred
[t=3] urgent deferred
[t=5] poll urgent
[t=20] poll timer
polls: timer=2 urgent=1
@@@ hidden_input
10 2 30
2 12 20
@@@ hidden_output
[t=0] poll timer
[t=12] urgent deferred
[t=12] poll timer
[t=14] poll urgent
[t=20] urgent woke
[t=20] poll urgent
polls: timer=2 urgent=2
@@@ hidden_input
5 0 12
4 1 2 3 4
@@@ hidden_output
[t=0] poll timer
[t=1] urgent woke
[t=1] poll urgent
[t=2] urgent woke
[t=2] poll urgent
[t=3] urgent woke
[t=3] poll urgent
[t=4] urgent woke
[t=4] poll urgent
[t=9] poll timer
polls: timer=2 urgent=4
@@@ hidden_input
100 30 250
2 30 130
@@@ hidden_output
[t=0] poll timer
[t=30] urgent deferred
[t=30] poll urgent
[t=130] urgent woke
[t=130] poll urgent
polls: timer=1 urgent=2
@@@ hidden_input
20 3 60
5 5 6 7 30 31
@@@ hidden_output
[t=0] poll timer
[t=5] urgent woke
[t=5] poll urgent
[t=6] urgent deferred
[t=7] urgent deferred
[t=8] poll urgent
[t=30] urgent woke
[t=30] poll urgent
[t=31] urgent deferred
[t=33] poll urgent
[t=56] poll timer
polls: timer=2 urgent=4
@@@ hint
Keep the poller's `TaskHandle_t` (last argument of `xTaskCreate`). `xTaskAbortDelay(h)` returns `pdPASS` only if the task really was in the Blocked state. Its return value tells you whether you woke the poller or whether it was busy.
@@@ hint
Use two flags shared between the manager and the poller. `woken` is set in `on_urgent()` right before a successful abort and tells the poller "the sleep was cut short". `pending` is set when the abort fails. The poller checks `pending` after its work: if set, it clears it and polls again without sleeping. Both tasks run on one core and the manager only touches the flags while the poller is not between reading and clearing them, but make them `volatile`.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

void poll_sensor(int urgent);

static TickType_t g_poll, g_cost;
static TaskHandle_t g_poller;
static volatile int g_woken;     /* sleep was cut short by on_urgent() */
static volatile int g_pending;   /* request arrived while the poller was busy */

static void poller_task(void *pv)
{
    int urgent = 0;
    (void)pv;
    for (;;) {
        poll_sensor(urgent);
        vSimBusyWork(g_cost);
        if (g_pending) {               /* serve a deferred request right away */
            g_pending = 0;
            urgent = 1;
            continue;
        }
        g_woken = 0;
        vTaskDelay(g_poll);            /* may end early through xTaskAbortDelay() */
        urgent = g_woken;
    }
}

void app_start(TickType_t poll_period, TickType_t poll_cost)
{
    g_poll = poll_period;
    g_cost = poll_cost;
    xTaskCreate(poller_task, "poller", configMINIMAL_STACK_SIZE, NULL, 2, &g_poller);
}

int on_urgent(void)
{
    if (eTaskGetState(g_poller) == eBlocked) {
        g_woken = 1;
        if (xTaskAbortDelay(g_poller) == pdPASS) return 1;
        g_woken = 0;                   /* cannot happen on one core, but be safe */
    }
    g_pending = 1;                     /* poller is mid-poll: serve it afterwards */
    return 0;
}
@@@ explanation_md
**Approach.** A task blocked in `vTaskDelay()` sits in the delayed list. `xTaskAbortDelay(h)` removes it from there and makes it ready immediately. `vTaskDelay()` simply returns early; the task cannot tell why unless you tell it. The solution uses a `woken` flag written by the manager right before the abort. Because the manager has the higher priority, the poller cannot run between the flag write and the abort.

If the poller is not blocked (it is in its `vSimBusyWork()` poll, preempted by the manager, or ready at the same tick its delay expired), the abort is impossible. `xTaskAbortDelay()` returns `pdFAIL`, and `eTaskGetState()` reports `eReady`. The request is then remembered in `pending`, and the poller serves it right after the current poll without sleeping. Several deferred requests during one poll collapse into one urgent poll, because a flag does not count.

Same-tick subtlety: the poller's delay expires at some tick and a request arrives at the same tick. The manager has the higher priority and runs first, but the tick interrupt has already moved the poller to the ready list. So the request is deferred, the timer poll runs, and the urgent poll follows at t=14.

**Complexity.** `on_urgent()` is O(1). The worst-case latency of an urgent request is one `poll_cost` (deferred case) instead of `POLL + poll_cost` with plain periodic polling. No extra RAM except two flags and a handle.

**Common mistakes**
- Not keeping the task handle, or calling `xTaskAbortDelay(NULL)`.
- Ignoring the return value: reporting "woke" for a busy poller and losing the request.
- Setting `woken` **after** `xTaskAbortDelay()`. Here it happens to work because the manager has the higher priority. With equal priorities or on SMP, the poller may read the flag before it is set.
- Replacing the sleep with `vTaskDelay(1)` loops that check a flag. It works only coarsely (the poll happens one tick late) and wastes CPU on every tick.
- Using `vTaskSuspend` / `vTaskResume` to wake the poller. Resuming a task suspended during `vTaskDelay()` makes it ready, but suspending it first is racy and changes its state for other observers.

**Interview follow-ups**
- Redesign this with a task notification: `ulTaskNotifyTake(pdTRUE, POLL)` in the poller and `xTaskNotifyGive()` in `on_urgent()`. Which version is simpler, and why is the "pending" case handled automatically there?
- What does `xTaskAbortDelay()` do to a task blocked on a queue receive with a timeout?
- How would `on_urgent()` be implemented if it were called from an ISR?
- Why is `INCLUDE_xTaskAbortDelay` disabled by default in many configurations?
