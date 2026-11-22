@@@ meta
id: RDS-E-02
topic: RTOS Design Patterns
difficulty: Easy
type: FUNCTION
title: Active Object Door Lock State Machine Fed By A Queue
tags: freertos, active-object, state-machine, xqueuesendfromisr, embedded, asked-in-automotive
@@@ statement_md
A body control module drives the central door lock. Button and door-switch interrupts must not run the lock logic themselves. Implement the lock as an **active object**: one task owns the state, and the only way to talk to it is an **event queue**. Interrupts post events, and the task handles them one at a time (run-to-completion).

```c
typedef enum { EV_UNLOCK, EV_LOCK, EV_OPEN, EV_CLOSE, EV_TIMEOUT } Event;
typedef enum { ST_LOCKED, ST_UNLOCKED, ST_OPEN } State;

/* provided by the judge */
void sm_trace(State from, Event ev, State to);
    /* from != to: prints "[t=<tick>] <FROM> -<EV>-> <TO>"
       from == to: prints "[t=<tick>] <FROM> ignores <EV>" */

/* you write these */
void door_start(TickType_t relock_ticks); /* called before the scheduler starts */
void door_post_from_isr(Event ev);        /* called from interrupt handlers */
```

`door_start()` creates an event queue of **8** `Event`s and the active-object task, named `"DOOR"`, with priority **3**. The task starts in `ST_LOCKED`. It handles events like this:

| State | Event | Next state |
|---|---|---|
| LOCKED | UNLOCK | UNLOCKED |
| UNLOCKED | LOCK | LOCKED |
| UNLOCKED | OPEN | OPEN |
| UNLOCKED | *no event for `relock_ticks` ticks* | LOCKED (event `EV_TIMEOUT`) |
| OPEN | CLOSE | UNLOCKED |

Every other combination is ignored, and the state stays the same. Call `sm_trace(from, ev, to)` once for **every** event the task handles, including ignored ones and `EV_TIMEOUT`.

**Auto-relock.** While the state is UNLOCKED, the task waits for the next event at most `relock_ticks` ticks. If no event arrives in that time, the door relocks with `EV_TIMEOUT`. Any event received while UNLOCKED, even an ignored one, starts a new full wait. In LOCKED and OPEN the task waits forever. Implement the timeout with the **timeout argument of `xQueueReceive()`** (no timers, no polling).

`door_post_from_isr()` posts the event with `xQueueSendFromISR()` (drop it if the queue is full) and requests a context switch with `portYIELD_FROM_ISR()`.

**How it is tested.** The hidden `main()` calls `door_start()`. It schedules one simulated interrupt per input event, each calling `door_post_from_isr()`. It also creates a background task of priority 1 that keeps the CPU busy all the time. The scheduler runs up to tick `D`, and then the final state and the counters are printed. `sm_trace()` must be called from the `DOOR` task. Several events at the same tick are posted in input order, before the task runs, and the task handles them in that order, all at that tick. Thanks to `portYIELD_FROM_ISR()`, an event is handled at the tick of its interrupt even though the CPU is busy.

**Input**
```
<relock_ticks> <D>
<m>
<tick> <EVENT>      (m lines, EVENT is UNLOCK, LOCK, OPEN or CLOSE, ticks non-decreasing)
```

**Example**
```
Input:
50 120
4
10 UNLOCK
30 OPEN
40 CLOSE
45 UNLOCK

Output:
[t=10] LOCKED -UNLOCK-> UNLOCKED
[t=30] UNLOCKED -OPEN-> OPEN
[t=40] OPEN -CLOSE-> UNLOCKED
[t=45] UNLOCKED ignores UNLOCK
[t=95] UNLOCKED -TIMEOUT-> LOCKED
final=LOCKED transitions=4 ignored=1
```
The ignored UNLOCK at t=45 restarts the 50-tick wait, so the door relocks at t=95, not at t=90.
@@@ constraints_md
- 1 <= relock_ticks <= 1000, 1 <= D <= 10000, 0 <= m <= 50, 1 <= tick < D.
- At most 8 events share the same tick, so the queue never overflows in the tests. Still, handle a full queue.
- No event is scheduled exactly at the tick where an auto-relock timeout expires.
- Task: name `"DOOR"`, priority 3, stack `configMINIMAL_STACK_SIZE`. The queue holds `Event` values, length 8.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef enum { EV_UNLOCK, EV_LOCK, EV_OPEN, EV_CLOSE, EV_TIMEOUT } Event;
typedef enum { ST_LOCKED, ST_UNLOCKED, ST_OPEN } State;

void sm_trace(State from, Event ev, State to);

static void door_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: wait for an event (with the relock timeout while UNLOCKED),
           compute the next state, call sm_trace() */
        vTaskDelay(1000);
    }
}

void door_start(TickType_t relock_ticks)
{
    /* TODO: create the queue (8 events) and the "DOOR" task (priority 3) */
    (void)relock_ticks;
    (void)door_task;
}

void door_post_from_isr(Event ev)
{
    /* TODO: xQueueSendFromISR + portYIELD_FROM_ISR */
    (void)ev;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

/* must match the user's enums (same order) */
static const char *const k_ev[] = { "UNLOCK", "LOCK", "OPEN", "CLOSE", "TIMEOUT" };
static const char *const k_st[] = { "LOCKED", "UNLOCKED", "OPEN" };
static int g_final = 0;
static unsigned g_trans, g_ign;
static int g_fail;

static void trace_impl(int from, int ev, int to)
{
    const char *who = pcTaskGetName(NULL);
    if (strcmp(who, "DOOR") != 0) {
        if (!g_fail) printf("FAIL: sm_trace() called from task \"%s\"\n", who);
        g_fail = 1;
        return;
    }
    if (from < 0 || from > 2 || to < 0 || to > 2 || ev < 0 || ev > 4) {
        printf("FAIL: bad state/event value\n");
        return;
    }
    if (from == to) {
        printf("[t=%u] %s ignores %s\n", (unsigned)xTaskGetTickCount(), k_st[from], k_ev[ev]);
        g_ign++;
    } else {
        printf("[t=%u] %s -%s-> %s\n", (unsigned)xTaskGetTickCount(), k_st[from], k_ev[ev], k_st[to]);
        g_trans++;
    }
    g_final = to;
}

static void background_task(void *p)
{
    (void)p;
    for (;;) vSimBusyWork(1);   /* the rest of the application keeps the CPU busy */
}

/*USER_CODE*/

void sm_trace(State from, Event ev, State to)
{
    trace_impl((int)from, (int)ev, (int)to);
}

static void button_isr(void *arg)
{
    door_post_from_isr((Event)(intptr_t)arg);
}

int main(void)
{
    unsigned relock, dur, tick;
    int m, i, e;
    char name[16];

    if (scanf("%u %u %d", &relock, &dur, &m) != 3) return 1;
    door_start((TickType_t)relock);
    xTaskCreate(background_task, "BG", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    for (i = 0; i < m; i++) {
        if (scanf("%u %15s", &tick, name) != 2) return 1;
        for (e = 0; e < 4; e++) if (strcmp(name, k_ev[e]) == 0) break;
        if (e == 4) return 1;
        xSimScheduleInterrupt((TickType_t)tick, button_isr, (void *)(intptr_t)e);
    }
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("final=%s transitions=%u ignored=%u\n", k_st[g_final], g_trans, g_ign);
    return 0;
}
@@@ sample_input
50 120
4
10 UNLOCK
30 OPEN
40 CLOSE
45 UNLOCK
@@@ sample_output
[t=10] LOCKED -UNLOCK-> UNLOCKED
[t=30] UNLOCKED -OPEN-> OPEN
[t=40] OPEN -CLOSE-> UNLOCKED
[t=45] UNLOCKED ignores UNLOCK
[t=95] UNLOCKED -TIMEOUT-> LOCKED
final=LOCKED transitions=4 ignored=1
@@@ sample_input
20 110
6
5 OPEN
5 UNLOCK
5 OPEN
50 CLOSE
60 LOCK
80 UNLOCK
@@@ sample_output
[t=5] LOCKED ignores OPEN
[t=5] LOCKED -UNLOCK-> UNLOCKED
[t=5] UNLOCKED -OPEN-> OPEN
[t=50] OPEN -CLOSE-> UNLOCKED
[t=60] UNLOCKED -LOCK-> LOCKED
[t=80] LOCKED -UNLOCK-> UNLOCKED
[t=100] UNLOCKED -TIMEOUT-> LOCKED
final=LOCKED transitions=6 ignored=1
@@@ hidden_input
100 500
0
@@@ hidden_output
final=LOCKED transitions=0 ignored=0
@@@ hidden_input
1 10
1
1 UNLOCK
@@@ hidden_output
[t=1] LOCKED -UNLOCK-> UNLOCKED
[t=2] UNLOCKED -TIMEOUT-> LOCKED
final=LOCKED transitions=2 ignored=0
@@@ hidden_input
30 1000
8
7 UNLOCK
7 OPEN
7 LOCK
7 CLOSE
7 CLOSE
7 OPEN
7 UNLOCK
7 LOCK
@@@ hidden_output
[t=7] LOCKED -UNLOCK-> UNLOCKED
[t=7] UNLOCKED -OPEN-> OPEN
[t=7] OPEN ignores LOCK
[t=7] OPEN -CLOSE-> UNLOCKED
[t=7] UNLOCKED ignores CLOSE
[t=7] UNLOCKED -OPEN-> OPEN
[t=7] OPEN ignores UNLOCK
[t=7] OPEN ignores LOCK
final=OPEN transitions=4 ignored=4

@@@ hidden_input
25 300
7
10 UNLOCK
30 CLOSE
50 LOCK
60 LOCK
61 UNLOCK
80 OPEN
200 CLOSE
@@@ hidden_output
[t=10] LOCKED -UNLOCK-> UNLOCKED
[t=30] UNLOCKED ignores CLOSE
[t=50] UNLOCKED -LOCK-> LOCKED
[t=60] LOCKED ignores LOCK
[t=61] LOCKED -UNLOCK-> UNLOCKED
[t=80] UNLOCKED -OPEN-> OPEN
[t=200] OPEN -CLOSE-> UNLOCKED
[t=225] UNLOCKED -TIMEOUT-> LOCKED
final=LOCKED transitions=6 ignored=2

@@@ hidden_input
40 400
9
3 LOCK
4 CLOSE
6 UNLOCK
40 UNLOCK
79 OPEN
80 UNLOCK
81 LOCK
82 CLOSE
150 UNLOCK
@@@ hidden_output
[t=3] LOCKED ignores LOCK
[t=4] LOCKED ignores CLOSE
[t=6] LOCKED -UNLOCK-> UNLOCKED
[t=40] UNLOCKED ignores UNLOCK
[t=79] UNLOCKED -OPEN-> OPEN
[t=80] OPEN ignores UNLOCK
[t=81] OPEN ignores LOCK
[t=82] OPEN -CLOSE-> UNLOCKED
[t=122] UNLOCKED -TIMEOUT-> LOCKED
[t=150] LOCKED -UNLOCK-> UNLOCKED
[t=190] UNLOCKED -TIMEOUT-> LOCKED
final=LOCKED transitions=6 ignored=5

@@@ hidden_input
1000 5000
3
100 UNLOCK
1099 OPEN
1100 CLOSE
@@@ hidden_output
[t=100] LOCKED -UNLOCK-> UNLOCKED
[t=1099] UNLOCKED -OPEN-> OPEN
[t=1100] OPEN -CLOSE-> UNLOCKED
[t=2100] UNLOCKED -TIMEOUT-> LOCKED
final=LOCKED transitions=4 ignored=0

@@@ hint
The task's only blocking call is `xQueueReceive(q, &ev, wait)`, where `wait = (state == ST_UNLOCKED) ? relock_ticks : portMAX_DELAY`. If it returns `pdFALSE`, no event came in time: treat it as `EV_TIMEOUT`.
@@@ hint
ISR side: `BaseType_t woken = pdFALSE; xQueueSendFromISR(q, &ev, &woken); portYIELD_FROM_ISR(woken);`. Without the yield, the busy background task keeps the CPU until the next tick, and every trace line comes one tick late.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef enum { EV_UNLOCK, EV_LOCK, EV_OPEN, EV_CLOSE, EV_TIMEOUT } Event;
typedef enum { ST_LOCKED, ST_UNLOCKED, ST_OPEN } State;

void sm_trace(State from, Event ev, State to);

static QueueHandle_t s_evq;
static TickType_t s_relock;

static State next_state(State s, Event ev)
{
    switch (s) {
    case ST_LOCKED:
        return ev == EV_UNLOCK ? ST_UNLOCKED : s;
    case ST_UNLOCKED:
        if (ev == EV_LOCK || ev == EV_TIMEOUT) return ST_LOCKED;
        if (ev == EV_OPEN) return ST_OPEN;
        return s;
    case ST_OPEN:
        return ev == EV_CLOSE ? ST_UNLOCKED : s;
    }
    return s;
}

/* The active object: private state, one inbox, run-to-completion handling. */
static void door_task(void *pvParameters)
{
    State st = ST_LOCKED;
    Event ev;

    (void)pvParameters;
    for (;;) {
        TickType_t wait = (st == ST_UNLOCKED) ? s_relock : portMAX_DELAY;
        State nx;

        if (xQueueReceive(s_evq, &ev, wait) != pdPASS) {
            ev = EV_TIMEOUT;            /* nothing arrived within relock_ticks */
        }
        nx = next_state(st, ev);
        sm_trace(st, ev, nx);
        st = nx;
    }
}

void door_start(TickType_t relock_ticks)
{
    s_relock = relock_ticks;
    s_evq = xQueueCreate(8, sizeof(Event));
    xTaskCreate(door_task, "DOOR", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
}

void door_post_from_isr(Event ev)
{
    BaseType_t woken = pdFALSE;

    (void)xQueueSendFromISR(s_evq, &ev, &woken);   /* full queue: event dropped */
    portYIELD_FROM_ISR(woken);
}
@@@ explanation_md
**Approach.** An active object is "a task + a private state + an inbox queue". Nobody else reads or writes the state, so there are no mutexes and no races. ISRs only post events. The task blocks on its queue and handles one event completely before taking the next one (run-to-completion). The state machine is a pure function `next_state(state, event)`, which is easy to unit-test on a PC.

The auto-relock timeout needs no timer: the blocking time of `xQueueReceive()` depends on the state. In UNLOCKED the task waits at most `relock_ticks`. If the call returns `pdFALSE`, that silence is turned into the synthetic `EV_TIMEOUT` event and goes through the same transition table. In the example, the ignored UNLOCK at t=45 is a received event, so a new 50-tick wait starts and the relock happens at t=95.

The background task keeps the CPU busy. `portYIELD_FROM_ISR(woken)` makes the higher-priority `DOOR` task run **at the tick of the interrupt**. Without it, the switch would only happen at the next tick interrupt.

**Complexity.** O(1) per event (a table lookup). RAM: an 8 x `sizeof(Event)` queue plus one TCB and one stack. Worst-case reaction latency: the time to handle the events queued in front of this one. The task never polls, so it uses 0 % CPU while idle.

**Common mistakes**
- Running the state machine inside the ISR: long ISRs, and the shared state then needs critical sections.
- Calling `xQueueSend()` (task API) from the ISR. The simulator reports it as a Runtime Error, and on real hardware it can corrupt the kernel.
- Forgetting `portYIELD_FROM_ISR()`: every reaction comes one tick late.
- Using `vTaskDelay(relock)` and then checking the queue. Events arriving during the delay are handled late, and the timeout cannot be restarted.
- Timing the relock from the moment UNLOCKED was entered, while the spec restarts the wait on every received event.

**Interview follow-ups**
- How would you add a second timeout, for example "alarm if the door stays OPEN for 5 minutes"? (Track a deadline per state and wait for `deadline - now`.)
- When should an active object use a software timer that posts `EV_TIMEOUT` instead of a receive timeout?
- What do you do when the event queue overflows (drop newest, drop oldest, count, assert)?
- How would you test the state machine without the RTOS?
