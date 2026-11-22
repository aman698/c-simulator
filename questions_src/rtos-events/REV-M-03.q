@@@ meta
id: REV-M-03
topic: Event Groups & Notifications
difficulty: Medium
type: FUNCTION
title: Power-Window State Machine: Wait-Any With Timeout and Clear-on-Exit
tags: freertos, event-groups, xeventgroupwaitbits, xeventgroupsetbitsfromisr, state-machine, timeout, embedded, asked-in-automotive
@@@ statement_md
A door control module drives a power-window motor. Four interrupts report events into an **event group**:

```c
#define EV_UP        0x01   /* "up" button pressed       */
#define EV_DOWN      0x02   /* "down" button pressed     */
#define EV_END       0x04   /* end-stop switch reached   */
#define EV_OBSTACLE  0x08   /* anti-pinch sensor tripped */

void motor_up(void);                  /* provided: prints "[t=<tick>] motor UP"            */
void motor_down(void);                /* provided: prints "[t=<tick>] motor DOWN"          */
void motor_stop(const char *reason);  /* provided: prints "[t=<tick>] motor STOP (<reason>)" */

void app_start(UBaseType_t priority, TickType_t max_run);  /* you write */
void window_isr(EventBits_t events);  /* you write: called in INTERRUPT context */
```

**`window_isr(events)`** sets the given bits with `xEventGroupSetBitsFromISR()` and calls `portYIELD_FROM_ISR(woken)`. Setting event-group bits is not allowed in an ISR (it walks a list of unknown length), so the FromISR version **defers** the work to the timer service task (priority 7 here). With the yield, the timer task runs at the interrupt's tick and sets the bits. Your controller task then runs right after it, **at the same tick**.

**The controller task** (priority `priority`) owns the state `IDLE`, `MOVING_UP` or `MOVING_DOWN` (initially `IDLE`). It loops forever:

1. Wait for **any** of the four bits, with **clear on exit**:
   - in `IDLE`, without timeout;
   - while moving, at most until the **deadline** = (tick at which the current movement started) + `max_run`. Pass the **remaining** time, not `max_run` again: an ignored event must not extend the deadline.
2. If no bit is returned (timeout), the motor ran too long: `motor_stop("timeout")`, go to `IDLE`.
3. Otherwise apply the returned bits **one by one in this order: OBSTACLE, END, UP, DOWN**. Each one is applied to the state left by the previous one:

| event | IDLE | MOVING_UP | MOVING_DOWN |
|---|---|---|---|
| OBSTACLE | ignore | `motor_stop("obstacle")` -> IDLE | `motor_stop("obstacle")` -> IDLE |
| END | ignore | `motor_stop("end-stop")` -> IDLE | `motor_stop("end-stop")` -> IDLE |
| UP | `motor_up()` -> MOVING_UP, start deadline | ignore | `motor_stop("button")` -> IDLE |
| DOWN | `motor_down()` -> MOVING_DOWN, start deadline | `motor_stop("button")` -> IDLE | ignore |

Use the event-group API (queues, semaphores and task notifications are disabled in this exercise).

**How it is tested.** The hidden `main()` reads the scenario, calls `app_start()`, schedules the interrupts (each calls `window_isr()` with one mask) and runs the scheduler up to and including tick `D`. Then it prints the final motor state. The motor functions print `ERROR: ...` if they are called in a state where the command makes no sense (for example `motor_up()` while already moving).

**Input**
```
<priority> <max_run> <D>
<n>
<tick> <events>      (n lines; events = names joined by '+', e.g. UP or OBSTACLE+UP)
```

**Example**
```
Input:
3 50 200
5
5 UP
30 END
40 DOWN
45 DOWN
120 UP+DOWN

Output:
[t=5] motor UP
[t=30] motor STOP (end-stop)
[t=40] motor DOWN
[t=90] motor STOP (timeout)
[t=120] motor UP
[t=120] motor STOP (button)
final: IDLE
```
The downward movement starts at t=40, so its deadline is t=90. The second DOWN press at t=45 is ignored, and the task waits again for the remaining 45 ticks, so the timeout still happens at t=90 (not t=95). At t=120 both buttons arrive together: UP starts the motor, then DOWN (applied next) stops it.
@@@ constraints_md
- 1 <= priority <= 6, 1 <= max_run <= 2000, 1 <= D <= 20000, 0 <= n <= 100, 1 <= tick < D.
- Interrupt ticks are strictly increasing, and no interrupt arrives exactly at a movement deadline (that tie is not tested).
- One event group, one controller task; no polling.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"

#define EV_UP        0x01
#define EV_DOWN      0x02
#define EV_END       0x04
#define EV_OBSTACLE  0x08

void motor_up(void);
void motor_down(void);
void motor_stop(const char *reason);

static EventGroupHandle_t window_events;
static TickType_t max_run_ticks;

static void window_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: wait for any event (with the right timeout), then run the state machine */
        vTaskDelay(1000);
    }
}

void app_start(UBaseType_t priority, TickType_t max_run)
{
    /* TODO: create the event group and the controller task */
    (void)priority;
    (void)window_task;
    (void)window_events;
    max_run_ticks = max_run;
}

void window_isr(EventBits_t events)
{
    /* TODO: set the bits from interrupt context and yield */
    (void)events;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "event_groups.h"
#include "sim.h"

static int g_state;   /* 0 idle, 1 up, 2 down */
static const char *const g_state_name[3] = { "IDLE", "MOVING_UP", "MOVING_DOWN" };

void motor_up(void)
{
    printf("[t=%u] motor UP\n", (unsigned)xTaskGetTickCount());
    if (g_state != 0) printf("ERROR: motor_up() while %s\n", g_state_name[g_state]);
    g_state = 1;
}

void motor_down(void)
{
    printf("[t=%u] motor DOWN\n", (unsigned)xTaskGetTickCount());
    if (g_state != 0) printf("ERROR: motor_down() while %s\n", g_state_name[g_state]);
    g_state = 2;
}

void motor_stop(const char *reason)
{
    printf("[t=%u] motor STOP (%s)\n", (unsigned)xTaskGetTickCount(), reason ? reason : "?");
    if (g_state == 0) printf("ERROR: motor_stop() while IDLE\n");
    g_state = 0;
}

/* this exercise is about event groups */
#define xQueueGenericCreate(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueGenericCreateStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateCountingSemaphore(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateCountingSemaphoreStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateMutex(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateMutexStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xTaskGenericNotify(...) notifications_are_disabled_in_this_exercise
#define xTaskGenericNotifyFromISR(...) notifications_are_disabled_in_this_exercise
#define vTaskGenericNotifyGiveFromISR(...) notifications_are_disabled_in_this_exercise
#define xTaskGenericNotifyWait(...) notifications_are_disabled_in_this_exercise
#define ulTaskGenericNotifyTake(...) notifications_are_disabled_in_this_exercise

/*USER_CODE*/

#undef xQueueGenericCreate
#undef xQueueGenericCreateStatic
#undef xQueueCreateCountingSemaphore
#undef xQueueCreateCountingSemaphoreStatic
#undef xQueueCreateMutex
#undef xQueueCreateMutexStatic
#undef xTaskGenericNotify
#undef xTaskGenericNotifyFromISR
#undef vTaskGenericNotifyGiveFromISR
#undef xTaskGenericNotifyWait
#undef ulTaskGenericNotifyTake

static EventBits_t g_masks[100];

static void door_irq(void *arg)
{
    window_isr(*(const EventBits_t *)arg);
}

static EventBits_t parse_events(const char *s)
{
    static const char *const names[4] = { "UP", "DOWN", "END", "OBSTACLE" };
    EventBits_t m = 0;
    char tok[16];
    int k, len;

    while (*s) {
        for (len = 0; s[len] && s[len] != '+' && len < 15; len++) tok[len] = s[len];
        tok[len] = '\0';
        for (k = 0; k < 4; k++)
            if (strcmp(tok, names[k]) == 0) m |= (EventBits_t)1 << k;
        s += len;
        if (*s == '+') s++;
    }
    return m;
}

int main(void)
{
    unsigned prio, max_run, dur, n, i, t;
    char ev[64];

    if (scanf("%u %u %u", &prio, &max_run, &dur) != 3) return 1;
    if (scanf("%u", &n) != 1 || n > 100) return 1;
    for (i = 0; i < n; i++) {
        if (scanf("%u %63s", &t, ev) != 2) return 1;
        g_masks[i] = parse_events(ev);
        xSimScheduleInterrupt((TickType_t)t, door_irq, &g_masks[i]);
    }

    app_start((UBaseType_t)prio, (TickType_t)max_run);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("final: %s\n", g_state_name[g_state]);
    return 0;
}
@@@ sample_input
3 50 200
5
5 UP
30 END
40 DOWN
45 DOWN
120 UP+DOWN
@@@ sample_output
[t=5] motor UP
[t=30] motor STOP (end-stop)
[t=40] motor DOWN
[t=90] motor STOP (timeout)
[t=120] motor UP
[t=120] motor STOP (button)
final: IDLE
@@@ sample_input
2 100 300
5
10 DOWN
20 OBSTACLE+UP
50 OBSTACLE
60 END
70 UP
@@@ sample_output
[t=10] motor DOWN
[t=20] motor STOP (obstacle)
[t=20] motor UP
[t=50] motor STOP (obstacle)
[t=70] motor UP
[t=170] motor STOP (timeout)
final: IDLE
@@@ hidden_input
4 30 100
0
@@@ hidden_output
final: IDLE
@@@ hidden_input
1 10 50
1
1 UP
@@@ hidden_output
[t=1] motor UP
[t=11] motor STOP (timeout)
final: IDLE
@@@ hidden_input
5 1000 500
4
10 DOWN
20 DOWN
30 DOWN
40 OBSTACLE+END+UP+DOWN
@@@ hidden_output
[t=10] motor DOWN
[t=40] motor STOP (obstacle)
[t=40] motor UP
[t=40] motor STOP (button)
final: IDLE
@@@ hidden_input
6 40 400
9
5 END
6 OBSTACLE
10 UP
20 UP
30 UP
45 UP
55 DOWN
60 UP
110 END
@@@ hidden_output
[t=10] motor UP
[t=50] motor STOP (timeout)
[t=55] motor DOWN
[t=60] motor STOP (button)
final: IDLE
@@@ hidden_input
3 200 150
3
10 UP
11 END+DOWN
100 UP
@@@ hidden_output
[t=10] motor UP
[t=11] motor STOP (end-stop)
[t=11] motor DOWN
[t=100] motor STOP (button)
final: IDLE
@@@ hidden_input
2 25 1000
6
100 UP
110 UP
120 UP
121 DOWN
130 END
140 UP
@@@ hidden_output
[t=100] motor UP
[t=121] motor STOP (button)
[t=140] motor UP
[t=165] motor STOP (timeout)
final: IDLE

@@@ hint
In the ISR: `BaseType_t woken = pdFALSE; xEventGroupSetBitsFromISR(eg, events, &woken); portYIELD_FROM_ISR(woken);`. The call queues a "set bits" request for the timer task. `woken` becomes `pdTRUE` because the timer task (priority 7) was unblocked.
@@@ hint
Keep `deadline` in the task. Wait time = `portMAX_DELAY` when idle, `deadline - xTaskGetTickCount()` when moving. `bits = xEventGroupWaitBits(eg, 0x0F, pdTRUE, pdFALSE, wait);` then `bits &= 0x0F;`. If `bits == 0`, it was a timeout. Otherwise test `EV_OBSTACLE`, `EV_END`, `EV_UP`, `EV_DOWN` in that order against the state as it changes.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"

#define EV_UP        0x01
#define EV_DOWN      0x02
#define EV_END       0x04
#define EV_OBSTACLE  0x08
#define EV_ALL       (EV_UP | EV_DOWN | EV_END | EV_OBSTACLE)

void motor_up(void);
void motor_down(void);
void motor_stop(const char *reason);

typedef enum { ST_IDLE, ST_UP, ST_DOWN } WinState;

static EventGroupHandle_t window_events;
static TickType_t max_run_ticks;

static void window_task(void *pvParameters)
{
    WinState st = ST_IDLE;
    TickType_t deadline = 0;

    (void)pvParameters;
    for (;;) {
        TickType_t wait = portMAX_DELAY;
        EventBits_t bits;

        if (st != ST_IDLE) {
            TickType_t now = xTaskGetTickCount();
            wait = (deadline > now) ? (TickType_t)(deadline - now) : 0;   /* remaining time */
        }
        /* any bit, clear the returned bits on exit */
        bits = xEventGroupWaitBits(window_events, EV_ALL, pdTRUE, pdFALSE, wait) & EV_ALL;

        if (bits == 0) {                       /* only possible while moving */
            motor_stop("timeout");
            st = ST_IDLE;
            continue;
        }
        if ((bits & EV_OBSTACLE) && st != ST_IDLE) {
            motor_stop("obstacle");
            st = ST_IDLE;
        }
        if ((bits & EV_END) && st != ST_IDLE) {
            motor_stop("end-stop");
            st = ST_IDLE;
        }
        if (bits & EV_UP) {
            if (st == ST_IDLE) {
                motor_up();
                st = ST_UP;
                deadline = xTaskGetTickCount() + max_run_ticks;
            } else if (st == ST_DOWN) {
                motor_stop("button");
                st = ST_IDLE;
            }
        }
        if (bits & EV_DOWN) {
            if (st == ST_IDLE) {
                motor_down();
                st = ST_DOWN;
                deadline = xTaskGetTickCount() + max_run_ticks;
            } else if (st == ST_UP) {
                motor_stop("button");
                st = ST_IDLE;
            }
        }
    }
}

void app_start(UBaseType_t priority, TickType_t max_run)
{
    max_run_ticks = max_run;
    window_events = xEventGroupCreate();
    xTaskCreate(window_task, "window", configMINIMAL_STACK_SIZE, NULL, priority, NULL);
}

void window_isr(EventBits_t events)
{
    BaseType_t woken = pdFALSE;

    /* deferred: the timer service task performs the actual set */
    (void)xEventGroupSetBitsFromISR(window_events, events, &woken);
    portYIELD_FROM_ISR(woken);
}
@@@ explanation_md
**Approach.** The controller is an event-driven state machine that blocks in one place:

```c
bits = xEventGroupWaitBits(eg, EV_ALL, /*clear on exit*/ pdTRUE, /*wait all*/ pdFALSE, wait);
```

- **Wait-any** (`xWaitForAllBits = pdFALSE`): any event must wake the controller.
- **Clear-on-exit** clears exactly the bits that are returned, atomically. An event that arrives later stays set for the next iteration. Clearing them by hand with `xEventGroupClearBits()` after the wait would leave a window where a new event is erased unseen.
- **Timeout = remaining time to a fixed deadline.** The wait returns 0 (no bits) when the motor has run `max_run` ticks. Recomputing `deadline - now` makes ignored events (a second DOWN press) harmless.

**ISR side.** `xEventGroupSetBitsFromISR()` does not touch the event group. It posts a deferred call to the timer service task, because setting bits may unblock an unbounded number of tasks, which an ISR must not do. With `portYIELD_FROM_ISR(woken)`, the timer task (priority 7) runs immediately, sets the bits, and the controller runs at the same tick. Without the yield, everything shifts by one tick. If the timer command queue is full, the call returns `pdFAIL` and the event is lost. Check it in production code.

**Complexity.** Per event: one deferred call (a queue send of a few bytes) plus O(number of waiters) inside the timer task. The state machine step is O(1). RAM: one event group, plus a slot in the timer command queue per pending ISR event. Reaction latency: 0 ticks with the yield. Timeout accuracy: exact, because the deadline is absolute.

**Common mistakes**
- Waiting `max_run` again after an ignored event: the deadline slides (t=95 instead of t=90 in the example).
- `xEventGroupSetBits()` from the ISR: a Runtime Error here, and a crash or corruption on real hardware.
- Wait-for-all (`pdTRUE`) instead of wait-any: the task waits for all four bits.
- `xClearOnExit = pdFALSE`: the same bits are returned again and again, and the task spins.
- Treating the timeout as an event: `xEventGroupWaitBits()` returns the current bit value on timeout. Mask it, and treat "no bit set" as the timeout.

**Interview follow-ups**
- What is the worst-case latency of `xEventGroupSetBitsFromISR()`, and what does it depend on (timer task priority, command queue length)?
- Why would you rather use a direct task notification (`eSetBits`) here, and what would you lose?
- How do you guarantee the anti-pinch stop within 1 ms if the controller task can be blocked by a higher-priority task?
- How would you unit-test this state machine off-target?
