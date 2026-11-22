@@@ meta
id: RTM-E-01
topic: Software Timers
difficulty: Easy
type: FUNCTION
title: Auto-Reload Blink Timer That Stops After N Toggles
tags: freertos, software-timers, auto-reload, xtimercreate, xtimerstop, embedded
@@@ statement_md
A body-control ECU blinks a status LED. A whole task just for blinking wastes a stack, so you must do it with **one FreeRTOS software timer**.

```c
void led_toggle(void);   /* provided: toggles the LED and prints "[t=<tick>] LED ON" or "LED OFF" */

TimerHandle_t app_start(TickType_t period, unsigned max_toggles);   /* you write this (and the callback) */
```

`app_start()` is called **before** the scheduler starts. It must:

1. create an **auto-reload** timer with period `period`,
2. start it, and
3. return its handle.

Each time the timer expires, the callback calls `led_toggle()` once. The LED starts OFF, so the first toggle turns it ON. A timer started before the scheduler starts counts from tick 0, so with period 5 the LED toggles at t = 5, 10, 15, ...

If `max_toggles > 0`, the callback must **stop the timer** right after the `max_toggles`-th toggle. If `max_toggles == 0`, the LED blinks forever.

Rules:
- `led_toggle()` must be called from the timer callback, which runs in the **timer service task**. The harness checks this.
- A timer callback must never block. Use a block time of `0` for any timer command you issue from inside it.
- Creating tasks and calling `vTaskDelay()` are not allowed (both are banned by the harness).

**How it is tested.** The hidden `main()` reads `period`, `max_toggles` and a duration `D`. It calls `app_start()` and runs the scheduler up to and including tick `D`. Then it prints the number of toggles, whether the returned timer is auto-reload, and whether it is still active (`xTimerIsTimerActive()`).

**Input**
```
<period> <max_toggles> <D>
```

**Output**
One line per toggle, then:
```
toggles=<count>
auto-reload: yes|no
active: yes|no
```

**Example**
```
Input:
5 3 30

Output:
[t=5] LED ON
[t=10] LED OFF
[t=15] LED ON
toggles=3
auto-reload: yes
active: no
```
The timer expires at 5, 10 and 15. After the third toggle the callback stops the timer, so nothing happens at 20, 25 or 30, and the timer is no longer active at the end.
@@@ constraints_md
- 1 <= period <= 1000, 0 <= max_toggles <= 100, 1 <= D <= 5000.
- Exactly one software timer. No tasks, no `vTaskDelay()`.
- Simulated time: 1 tick = 1 ms. Code runs in zero ticks.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

void led_toggle(void);

static void blink_cb(TimerHandle_t xTimer)
{
    /* TODO: toggle the LED; stop the timer after max_toggles toggles */
    (void)xTimer;
}

TimerHandle_t app_start(TickType_t period, unsigned max_toggles)
{
    /* TODO: create an auto-reload timer, start it, return its handle */
    (void)period;
    (void)max_toggles;
    (void)blink_cb;
    return NULL;
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"
#include "sim.h"

static unsigned g_toggles;
static int g_led;
static int g_bad_ctx;

void led_toggle(void)
{
    if (xTaskGetCurrentTaskHandle() != xTimerGetTimerDaemonTaskHandle()) g_bad_ctx = 1;
    g_led = !g_led;
    g_toggles++;
    printf("[t=%u] LED %s\n", (unsigned)xTaskGetTickCount(), g_led ? "ON" : "OFF");
}

#define xTaskCreate(...) xTaskCreate_is_not_allowed_here
#define xTaskCreateStatic(...) xTaskCreateStatic_is_not_allowed_here
#define vTaskDelay(x) vTaskDelay_is_not_allowed_here
#define xTaskDelayUntil(...) xTaskDelayUntil_is_not_allowed_here

/*USER_CODE*/

#undef xTaskCreate
#undef xTaskCreateStatic
#undef vTaskDelay
#undef xTaskDelayUntil

int main(void)
{
    unsigned period, max_toggles, dur;
    TimerHandle_t h;

    if (scanf("%u %u %u", &period, &max_toggles, &dur) != 3) return 1;

    h = app_start((TickType_t)period, max_toggles);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    if (g_bad_ctx) printf("FAIL: led_toggle() called outside the timer service task\n");
    printf("toggles=%u\n", g_toggles);
    if (h == NULL) {
        printf("FAIL: app_start() returned NULL\n");
        return 0;
    }
    printf("auto-reload: %s\n", uxTimerGetReloadMode(h) == pdTRUE ? "yes" : "no");
    printf("active: %s\n", xTimerIsTimerActive(h) != pdFALSE ? "yes" : "no");
    return 0;
}
@@@ sample_input
5 3 30
@@@ sample_output
[t=5] LED ON
[t=10] LED OFF
[t=15] LED ON
toggles=3
auto-reload: yes
active: no
@@@ sample_input
4 0 13
@@@ sample_output
[t=4] LED ON
[t=8] LED OFF
[t=12] LED ON
toggles=3
auto-reload: yes
active: yes
@@@ hidden_input
1 0 5
@@@ hidden_output
[t=1] LED ON
[t=2] LED OFF
[t=3] LED ON
[t=4] LED OFF
[t=5] LED ON
toggles=5
auto-reload: yes
active: yes
@@@ hidden_input
100 2 50
@@@ hidden_output
toggles=0
auto-reload: yes
active: yes
@@@ hidden_input
10 2 20
@@@ hidden_output
[t=10] LED ON
[t=20] LED OFF
toggles=2
auto-reload: yes
active: no
@@@ hidden_input
7 1 100
@@@ hidden_output
[t=7] LED ON
toggles=1
auto-reload: yes
active: no
@@@ hidden_input
250 0 1000
@@@ hidden_output
[t=250] LED ON
[t=500] LED OFF
[t=750] LED ON
[t=1000] LED OFF
toggles=4
auto-reload: yes
active: yes
@@@ hidden_input
3 5 30
@@@ hidden_output
[t=3] LED ON
[t=6] LED OFF
[t=9] LED ON
[t=12] LED OFF
[t=15] LED ON
toggles=5
auto-reload: yes
active: no
@@@ hint
`xTimerCreate(name, period, pdTRUE, id, callback)` creates an auto-reload timer (`pdTRUE` = auto-reload). `xTimerStart(h, 0)` before the scheduler queues a start command that the timer service task handles at tick 0.
@@@ hint
Keep a counter (a `static` variable, or the timer ID) and in the callback do `led_toggle(); if (max && ++count == max) xTimerStop(xTimer, 0);`. The block time must be 0 because a callback must never block.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

void led_toggle(void);

static unsigned s_max;      /* 0 = forever */
static unsigned s_count;

static void blink_cb(TimerHandle_t xTimer)
{
    led_toggle();
    s_count++;
    if (s_max != 0 && s_count == s_max) {
        /* runs in the timer service task: never block here */
        xTimerStop(xTimer, 0);
    }
}

TimerHandle_t app_start(TickType_t period, unsigned max_toggles)
{
    TimerHandle_t h;

    s_max = max_toggles;
    s_count = 0;
    h = xTimerCreate("blink", period, pdTRUE, NULL, blink_cb);
    if (h != NULL) {
        /* scheduler not running yet: the command is queued, block time is ignored */
        xTimerStart(h, 0);
    }
    return h;
}
@@@ explanation_md
**Approach.** `xTimerCreate(..., pdTRUE, ...)` makes an auto-reload timer. `xTimerStart()` does not start anything by itself. It posts a *start* command to the timer command queue. The timer service task (priority 7 here) reads the command and puts the timer in its active list, with expiry = (tick when the command was sent) + period. Before the scheduler starts, that tick is 0.

When the timer expires, the service task first reloads it: the next expiry is the previous expiry + period, so there is no drift. Then it calls the callback. The callback toggles the LED and, after the last toggle, sends a *stop* command with block time 0. The service task processes that command as soon as the callback returns, so the timer becomes dormant and `xTimerIsTimerActive()` reports `pdFALSE`.

**Complexity.** Per expiry: O(1) work in the callback plus one insertion into the active timer list (O(number of active timers)). RAM: one timer control block (a few dozen bytes) instead of a task stack. The timer task's stack is shared by all callbacks.

**Common mistakes**
- Creating a one-shot timer (`pdFALSE`) and restarting it from the callback. It works, but it is not what was asked, and it drifts if the callback is ever delayed. The harness checks `uxTimerGetReloadMode()`.
- Blocking in a callback (`vTaskDelay`, `xTimerStop(h, portMAX_DELAY)`, waiting on a queue). This stalls the timer service task, so every other timer in the system is late.
- Forgetting `xTimerStart()`: `xTimerCreate()` leaves the timer dormant.
- Assuming `xTimerStop()` stops the timer synchronously. It only queues a command. With a high-priority timer task the command is handled almost at once, but from a lower-priority timer task it could be handled later.

**Interview follow-ups**
- In which task does the callback run, and why does its priority matter (`configTIMER_TASK_PRIORITY`)?
- What happens if the timer command queue (`configTIMER_QUEUE_LENGTH`) is full when you call `xTimerStart(h, 0)`?
- How would you store per-timer state without globals (`pvTimerGetTimerID` / `vTimerSetTimerID`)?
- A timer versus a task with `vTaskDelayUntil()`: what does each cost, and when would you pick each one?
