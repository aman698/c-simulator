@@@ meta
id: RTM-E-02
topic: Software Timers
difficulty: Easy
type: FUNCTION
title: Inactivity Timeout That Is Kicked By Activity
tags: freertos, software-timers, one-shot, xtimerreset, low-power, embedded
@@@ statement_md
An infotainment head unit turns its display off after `timeout` ticks without user input. Every key press or touch event restarts the countdown. Implement this with **one one-shot software timer**.

```c
void go_to_sleep(void);                    /* provided: prints "[t=<tick>] SLEEP" */

TimerHandle_t app_start(TickType_t timeout);   /* you write this */
void on_activity(void);                        /* you write this */
```

- `app_start()` is called **before** the scheduler starts. The unit starts awake, so the countdown starts at tick 0. Create a **one-shot** timer, start it, and return its handle.
- `on_activity()` is called from a **task** (priority 2) every time the user does something. It restarts the countdown, so the display goes to sleep `timeout` ticks after the **last** activity. If the unit is already asleep, the activity wakes it and starts a new countdown.
- When the timer expires, the callback calls `go_to_sleep()`.

Rules:
- Use a block time of `0` for timer commands. Creating tasks and `vTaskDelay()` are banned.
- `go_to_sleep()` must be called from the timer callback (the harness checks it).

**Same-tick ordering.** The timer service task runs at priority **7**, above the activity task. If an activity happens at exactly the tick when the timer expires, the timer task runs first. So `SLEEP` is printed first, and then the activity starts a new countdown.

**How it is tested.** The hidden `main()` calls `app_start()`. A harness task (priority 2) prints `[t=<tick>] activity` and then calls `on_activity()` at each listed tick. Ticks are sorted and may repeat. The scheduler runs up to and including tick `D`. Then the harness prints the number of sleeps, the final state, and whether your timer is one-shot and still active.

**Input**
```
<timeout> <n>
<t1> <t2> ... <tn>      (this line is absent when n = 0)
<D>
```

**Example**
```
Input:
20 2
20 25
60

Output:
[t=20] SLEEP
[t=20] activity
[t=25] activity
[t=45] SLEEP
sleeps=2
state: ASLEEP
one-shot: yes
active: no
```
The countdown started at 0 and expires at 20. The timer task runs before the activity task, so the display sleeps at t=20. The activity at t=20 then wakes it and restarts the timer (new expiry 40). The activity at t=25 moves the expiry to 45.
@@@ constraints_md
- 1 <= timeout <= 1000, 0 <= n <= 50, 1 <= t1 <= t2 <= ... <= tn <= D <= 5000.
- Exactly one one-shot software timer. No tasks, no `vTaskDelay()`.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

void go_to_sleep(void);

static void timeout_cb(TimerHandle_t xTimer)
{
    (void)xTimer;
    /* TODO */
}

TimerHandle_t app_start(TickType_t timeout)
{
    /* TODO: create a one-shot timer and start it */
    (void)timeout;
    (void)timeout_cb;
    return NULL;
}

void on_activity(void)
{
    /* TODO: restart the countdown */
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"
#include "sim.h"

static unsigned g_sleeps;
static int g_asleep;
static int g_bad_ctx;

void go_to_sleep(void)
{
    if (xTaskGetCurrentTaskHandle() != xTimerGetTimerDaemonTaskHandle()) g_bad_ctx = 1;
    g_sleeps++;
    g_asleep = 1;
    printf("[t=%u] SLEEP\n", (unsigned)xTaskGetTickCount());
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

static unsigned g_n;
static TickType_t g_ev[64];

static void activity_task(void *p)
{
    unsigned i;
    (void)p;
    for (i = 0; i < g_n; i++) {
        TickType_t now = xTaskGetTickCount();
        if (g_ev[i] > now) vTaskDelay(g_ev[i] - now);
        printf("[t=%u] activity\n", (unsigned)xTaskGetTickCount());
        g_asleep = 0;
        on_activity();
    }
    for (;;) vTaskDelay(portMAX_DELAY);
}

int main(void)
{
    unsigned timeout, dur, i, t;
    TimerHandle_t h;

    if (scanf("%u %u", &timeout, &g_n) != 2 || g_n > 64) return 1;
    for (i = 0; i < g_n; i++) {
        if (scanf("%u", &t) != 1) return 1;
        g_ev[i] = (TickType_t)t;
    }
    if (scanf("%u", &dur) != 1) return 1;

    h = app_start((TickType_t)timeout);
    xTaskCreate(activity_task, "act", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    if (g_bad_ctx) printf("FAIL: go_to_sleep() called outside the timer service task\n");
    printf("sleeps=%u\n", g_sleeps);
    printf("state: %s\n", g_asleep ? "ASLEEP" : "AWAKE");
    if (h == NULL) {
        printf("FAIL: app_start() returned NULL\n");
        return 0;
    }
    printf("one-shot: %s\n", uxTimerGetReloadMode(h) == pdFALSE ? "yes" : "no");
    printf("active: %s\n", xTimerIsTimerActive(h) != pdFALSE ? "yes" : "no");
    return 0;
}
@@@ sample_input
50 3
10 30 120
300
@@@ sample_output
[t=10] activity
[t=30] activity
[t=80] SLEEP
[t=120] activity
[t=170] SLEEP
sleeps=2
state: ASLEEP
one-shot: yes
active: no
@@@ sample_input
20 2
20 25
60
@@@ sample_output
[t=20] SLEEP
[t=20] activity
[t=25] activity
[t=45] SLEEP
sleeps=2
state: ASLEEP
one-shot: yes
active: no
@@@ hidden_input
100 0
250
@@@ hidden_output
[t=100] SLEEP
sleeps=1
state: ASLEEP
one-shot: yes
active: no
@@@ hidden_input
1 1
1
5
@@@ hidden_output
[t=1] SLEEP
[t=1] activity
[t=2] SLEEP
sleeps=2
state: ASLEEP
one-shot: yes
active: no
@@@ hidden_input
10 6
5 10 15 20 25 30
100
@@@ hidden_output
[t=5] activity
[t=10] activity
[t=15] activity
[t=20] activity
[t=25] activity
[t=30] activity
[t=40] SLEEP
sleeps=1
state: ASLEEP
one-shot: yes
active: no
@@@ hidden_input
30 4
10 10 10 50
100
@@@ hidden_output
[t=10] activity
[t=10] activity
[t=10] activity
[t=40] SLEEP
[t=50] activity
[t=80] SLEEP
sleeps=2
state: ASLEEP
one-shot: yes
active: no
@@@ hidden_input
1000 2
500 1200
2000
@@@ hidden_output
[t=500] activity
[t=1200] activity
sleeps=0
state: AWAKE
one-shot: yes
active: yes
@@@ hidden_input
100 1
300
400
@@@ hidden_output
[t=100] SLEEP
[t=300] activity
[t=400] SLEEP
sleeps=2
state: ASLEEP
one-shot: yes
active: no
@@@ hint
`xTimerReset()` restarts the countdown from "now", whether the timer is running or has already expired. A dormant one-shot timer is started again by it.
@@@ hint
Keep the handle in a `static TimerHandle_t`. `app_start`: `xTimerCreate("idle", timeout, pdFALSE, NULL, cb)` then `xTimerStart(h, 0)`. `on_activity`: `xTimerReset(h, 0)`. Callback: `go_to_sleep()`.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

void go_to_sleep(void);

static TimerHandle_t s_idle;

static void timeout_cb(TimerHandle_t xTimer)
{
    (void)xTimer;
    go_to_sleep();          /* one-shot: the timer is dormant now */
}

TimerHandle_t app_start(TickType_t timeout)
{
    s_idle = xTimerCreate("idle", timeout, pdFALSE, NULL, timeout_cb);
    if (s_idle != NULL) xTimerStart(s_idle, 0);
    return s_idle;
}

void on_activity(void)
{
    /* restarts a running timer and re-arms a dormant one: expiry = now + timeout */
    xTimerReset(s_idle, 0);
}
@@@ explanation_md
**Approach.** This is the classic *retriggerable one-shot*. `xTimerReset()` sends a reset command. The timer service task removes the timer from the active list, if it is there, and re-inserts it with expiry = (tick of the command) + period. For a dormant one-shot timer (already expired) a reset is the same as a start. So the same call both "postpones sleep" and "wakes up and starts counting".

Because the timer task has priority 7 and the activity task priority 2, `xTimerReset()` makes the timer task ready, and it preempts the caller immediately. The command is processed in the same tick. At a tick where the timer is due **and** activity happens, the timer task has already run (expiry first), and the activity task runs afterwards and restarts the countdown. That is why the sample shows `SLEEP` before `activity` at t=20.

**Complexity.** O(1) per activity (one queue message plus one list insertion, O(number of active timers)). RAM: one timer control block. A polling task that compares "last activity" timestamps would cost a stack and periodic CPU wake-ups instead.

**Common mistakes**
- Using `xTimerStart()` and expecting it to do nothing when the timer is already running. In FreeRTOS, starting a running timer restarts it, exactly like a reset. That is harmless here, but surprising in other designs.
- Deleting and re-creating the timer on every activity. This fragments the heap and costs far more than a reset.
- Using an auto-reload timer. The display would "go to sleep" again every `timeout` ticks.
- Calling `xTimerReset()` from an ISR. Use `xTimerResetFromISR()` with `portYIELD_FROM_ISR()` there.
- Expecting activity at the expiry tick to cancel the timeout. The timer service task has a higher priority, so it handles the expiry first.

**Interview follow-ups**
- How would you make the activity come from a touch-controller interrupt instead of a task? What changes at the boundary tick?
- What is the effective resolution of this timeout (tick granularity, plus command-queue latency if the timer task had a low priority)?
- How would you add a "dim at timeout/2, sleep at timeout" behaviour with as few timers as possible?
- What happens when `on_activity()` is called 1000 times per second, and how full can the timer queue get?
