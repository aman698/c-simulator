@@@ meta
id: RTM-H-01
topic: Software Timers
difficulty: Hard
type: FUNCTION
title: Per-Task Software Watchdog Manager Gating The Hardware Watchdog
tags: freertos, software-timers, watchdog, timer-id, functional-safety, embedded, asked-in-automotive
@@@ statement_md
In an ASIL-rated ECU, a single hardware watchdog cannot tell *which* task hung. Write a **software watchdog manager**. Every monitored task must check in ("kick") before its own deadline, and the hardware watchdog is fed only while **all** tasks are healthy.

```c
void wdg_report_miss(int id);      /* provided: prints "[t=<tick>] MISS task<id>" */
void wdg_report_recover(int id);   /* provided: prints "[t=<tick>] RECOVER task<id>" */
void hw_wdg_feed(void);            /* provided: feeds the hardware watchdog (recorded by the harness) */

void wdg_init(int n, const TickType_t timeout[], TickType_t feed_period);  /* you write: before the scheduler */
void wdg_kick(int id);                                                     /* you write: called by task `id` */
```

**Per-task supervision** (0 <= id < n):
- Task `id` has a **deadline** of `last_kick + timeout[id]`. Monitoring starts at tick 0, so the first deadline is `timeout[id]`.
- If the deadline tick arrives before the next kick, report `wdg_report_miss(id)` **once**, at the deadline tick, from a timer callback. The task is now *missed*.
- `wdg_kick(id)` sets `last_kick = now`. If the task was missed, it first reports `wdg_report_recover(id)`, and the task is healthy again.

**Hardware watchdog gate.** Every `feed_period` ticks (at `feed_period`, `2*feed_period`, ...), a timer callback decides: call `hw_wdg_feed()` **if and only if every task's deadline is strictly later than now** (`last_kick[i] + timeout[i] > now` for all `i`). A task whose deadline is exactly `now` blocks the feed, even if its own MISS callback has not run yet at that tick. Your decision must not depend on the order in which callbacks run at the same tick.

**Same-tick ordering.** The timer service task has priority 7 and the monitored tasks have priorities 1..5. So at any tick, **all timer callbacks run before any kick**. A kick exactly at the deadline tick is too late: `MISS` comes first, then `RECOVER`. A kick at a feed tick only counts for the next feed decision. If several tasks kick at the same tick, the higher-priority task runs first.

Rules: use software timers (at most one per task plus one for feeding). Timer callbacks must not block. Creating tasks and `vTaskDelay()` are banned in your code. `wdg_report_miss()` and `hw_wdg_feed()` must be called from timer callbacks (checked).

**How it is tested.** The hidden `main()` calls `wdg_init()` and creates the monitored tasks. Task `i` calls `wdg_kick(i)` at each of its listed ticks and then blocks forever. The scheduler runs up to and including tick `D`. Then the harness prints the ticks of all hardware feeds and the counts of MISS and RECOVER reports.

**Input**
```
<n> <feed_period> <D>
<timeout> <priority> <k> <kick_1> ... <kick_k>      (one line per task, kicks sorted)
```

**Output**
MISS/RECOVER lines as they happen, then:
```
feeds=<count>: <tick> <tick> ...
misses=<count> recovers=<count>
```

**Example**
```
Input:
1 10 60
20 3 2 20 30

Output:
[t=20] MISS task0
[t=20] RECOVER task0
[t=50] MISS task0
feeds=3: 10 30 40
misses=2 recovers=1
```
The deadline is 20 and the kick also comes at 20. The timer task runs first, so the MISS is reported, the feed at 20 is skipped (deadline 20 is not > 20), and then the kick recovers the task, with a new deadline of 40. The kick at 30 moves the deadline to 50. At 30 and 40 the deadline is in the future, so the watchdog is fed. At 50 the task misses again.
@@@ constraints_md
- 1 <= n <= 5, 1 <= timeout <= 1000, 1 <= feed_period <= 1000, 1 <= D <= 5000.
- Priorities are distinct, in 1..5. 0 <= k <= 100, and 1 <= kick < D.
- Two tasks never miss at the same tick.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

void wdg_report_miss(int id);
void wdg_report_recover(int id);
void hw_wdg_feed(void);

void wdg_init(int n, const TickType_t timeout[], TickType_t feed_period)
{
    /* TODO: one one-shot timer per task + one auto-reload feed timer */
    (void)n;
    (void)timeout;
    (void)feed_period;
}

void wdg_kick(int id)
{
    /* TODO */
    (void)id;
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"
#include "sim.h"

#define H_MAXT 5
#define H_MAXK 100
#define H_MAXF 6000

static unsigned g_misses, g_recovers, g_nfeeds;
static unsigned g_feeds[H_MAXF];
static int g_bad_ctx, g_bad_id, g_ntimers;

static int in_timer_task(void)
{
    return xTaskGetCurrentTaskHandle() == xTimerGetTimerDaemonTaskHandle();
}

void wdg_report_miss(int id)
{
    if (!in_timer_task()) g_bad_ctx = 1;
    if (id < 0 || id >= H_MAXT) g_bad_id = 1;
    g_misses++;
    printf("[t=%u] MISS task%d\n", (unsigned)xTaskGetTickCount(), id);
}

void wdg_report_recover(int id)
{
    if (id < 0 || id >= H_MAXT) g_bad_id = 1;
    g_recovers++;
    printf("[t=%u] RECOVER task%d\n", (unsigned)xTaskGetTickCount(), id);
}

void hw_wdg_feed(void)
{
    if (!in_timer_task()) g_bad_ctx = 1;
    if (g_nfeeds < H_MAXF) g_feeds[g_nfeeds] = (unsigned)xTaskGetTickCount();
    g_nfeeds++;
}

static TimerHandle_t h_timer_create(const char *name, TickType_t period, BaseType_t reload,
                                    void *id, TimerCallbackFunction_t cb)
{
    g_ntimers++;
    return xTimerCreate(name, period, reload, id, cb);
}

#define xTimerCreate(a, b, c, d, e) h_timer_create(a, b, c, d, e)
#define xTimerCreateStatic(...) xTimerCreateStatic_is_not_allowed_here
#define xTaskCreate(...) xTaskCreate_is_not_allowed_here
#define xTaskCreateStatic(...) xTaskCreateStatic_is_not_allowed_here
#define vTaskDelay(x) vTaskDelay_is_not_allowed_here
#define xTaskDelayUntil(...) xTaskDelayUntil_is_not_allowed_here

/*USER_CODE*/

#undef xTimerCreate
#undef xTimerCreateStatic
#undef xTaskCreate
#undef xTaskCreateStatic
#undef vTaskDelay
#undef xTaskDelayUntil

typedef struct { int id; unsigned k; TickType_t kick[H_MAXK]; } Mon;
static Mon g_mon[H_MAXT];

static void monitored_task(void *pv)
{
    Mon *m = (Mon *)pv;
    unsigned i;
    for (i = 0; i < m->k; i++) {
        TickType_t now = xTaskGetTickCount();
        if (m->kick[i] > now) vTaskDelay(m->kick[i] - now);
        wdg_kick(m->id);
    }
    for (;;) vTaskDelay(portMAX_DELAY);   /* hung (or finished): no more kicks */
}

int main(void)
{
    static TickType_t timeout[H_MAXT];
    unsigned n, feed, dur, to, prio, k, i, j, t;

    if (scanf("%u %u %u", &n, &feed, &dur) != 3 || n < 1 || n > H_MAXT) return 1;
    for (i = 0; i < n; i++) {
        if (scanf("%u %u %u", &to, &prio, &k) != 3 || k > H_MAXK) return 1;
        timeout[i] = (TickType_t)to;
        g_mon[i].id = (int)i;
        g_mon[i].k = k;
        for (j = 0; j < k; j++) {
            if (scanf("%u", &t) != 1) return 1;
            g_mon[i].kick[j] = (TickType_t)t;
        }
        xTaskCreate(monitored_task, "mon", configMINIMAL_STACK_SIZE, &g_mon[i], (UBaseType_t)prio, NULL);
    }

    wdg_init((int)n, timeout, (TickType_t)feed);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    if (g_bad_ctx) printf("FAIL: MISS/feed reported outside the timer service task\n");
    if (g_bad_id) printf("FAIL: bad task id reported\n");
    if (g_ntimers > (int)n + 1) printf("FAIL: %d timers created (at most %u allowed)\n", g_ntimers, n + 1);
    printf("feeds=%u:", g_nfeeds);
    for (i = 0; i < g_nfeeds && i < H_MAXF; i++) printf(" %u", g_feeds[i]);
    printf("\n");
    printf("misses=%u recovers=%u\n", g_misses, g_recovers);
    return 0;
}
@@@ sample_input
2 25 150
30 2 4 20 40 60 80
50 1 2 35 70
@@@ sample_output
[t=110] MISS task0
[t=120] MISS task1
feeds=4: 25 50 75 100
misses=2 recovers=0
@@@ sample_input
1 10 60
20 3 2 20 30
@@@ sample_output
[t=20] MISS task0
[t=20] RECOVER task0
[t=50] MISS task0
feeds=3: 10 30 40
misses=2 recovers=1
@@@ hidden_input
3 5 40
10 1 0
20 2 0
30 3 0
@@@ hidden_output
[t=10] MISS task0
[t=20] MISS task1
[t=30] MISS task2
feeds=1: 5
misses=3 recovers=0
@@@ hidden_input
2 50 200
40 1 2 30 100
25 3 2 20 100
@@@ hidden_output
[t=45] MISS task1
[t=70] MISS task0
[t=100] RECOVER task1
[t=100] RECOVER task0
[t=125] MISS task1
[t=140] MISS task0
feeds=0:
misses=4 recovers=2
@@@ hidden_input
1 2 6
1 4 1 1
@@@ hidden_output
[t=1] MISS task0
[t=1] RECOVER task0
[t=2] MISS task0
feeds=0:
misses=2 recovers=1
@@@ hidden_input
5 100 2000
50 1 79 25 50 75 100 125 150 175 200 225 250 275 300 325 350 375 400 425 450 475 500 525 550 575 600 625 650 675 700 725 750 775 800 825 850 875 900 925 950 975 1000 1025 1050 1075 1100 1125 1150 1175 1200 1225 1250 1275 1300 1325 1350 1375 1400 1425 1450 1475 1500 1525 1550 1575 1600 1625 1650 1675 1700 1725 1750 1775 1800 1825 1850 1875 1900 1925 1950 1975
60 2 66 30 60 90 120 150 180 210 240 270 300 330 360 390 420 450 480 510 540 570 600 630 660 690 720 750 780 810 840 870 900 930 960 990 1020 1050 1080 1110 1140 1170 1200 1230 1260 1290 1320 1350 1380 1410 1440 1470 1500 1530 1560 1590 1620 1650 1680 1710 1740 1770 1800 1830 1860 1890 1920 1950 1980
70 3 57 35 70 105 140 175 210 245 280 315 350 385 420 455 490 525 560 595 630 665 700 735 770 805 840 875 910 945 980 1015 1050 1085 1120 1155 1190 1225 1260 1295 1330 1365 1400 1435 1470 1505 1540 1575 1610 1645 1680 1715 1750 1785 1820 1855 1890 1925 1960 1995
80 4 49 40 80 120 160 200 240 280 320 360 400 440 480 520 560 600 640 680 720 760 800 840 880 920 960 1000 1040 1080 1120 1160 1200 1240 1280 1320 1360 1400 1440 1480 1520 1560 1600 1640 1680 1720 1760 1800 1840 1880 1920 1960
90 5 44 45 90 135 180 225 270 315 360 405 450 495 540 585 630 675 720 765 810 855 900 945 990 1035 1080 1125 1170 1215 1260 1305 1350 1395 1440 1485 1530 1575 1620 1665 1710 1755 1800 1845 1890 1935 1980
@@@ hidden_output
feeds=20: 100 200 300 400 500 600 700 800 900 1000 1100 1200 1300 1400 1500 1600 1700 1800 1900 2000
misses=0 recovers=0

@@@ hidden_input
3 99 1000
100 5 10 99 198 297 396 495 594 693 792 891 990
60 2 8 50 100 150 200 400 450 500 550
200 1 4 150 300 600 900
@@@ hidden_output
[t=260] MISS task1
[t=400] RECOVER task1
[t=500] MISS task2
[t=600] RECOVER task2
[t=610] MISS task1
[t=800] MISS task2
[t=900] RECOVER task2
feeds=3: 99 198 495
misses=4 recovers=3

@@@ hidden_input
2 30 90
45 2 1 45
89 4 0
@@@ hidden_output
[t=45] MISS task0
[t=45] RECOVER task0
[t=89] MISS task1
[t=90] MISS task0
feeds=2: 30 60
misses=3 recovers=1

@@@ hidden_input
1 50 120
20 2 2 15 30
@@@ hidden_output
[t=50] MISS task0
feeds=0:
misses=1 recovers=0
@@@ hint
Use one **one-shot** timer per task with the task index as its timer ID, and one shared callback. `wdg_kick()` restarts the task's timer with `xTimerReset(h[id], 0)`. When the timer expires, the task missed its deadline. Add one **auto-reload** timer with period `feed_period` for the feed decision.
@@@ hint
Do not base the feed decision on a "missed" flag: at a tick where a deadline and a feed coincide, the flag depends on which callback runs first. Store `last_kick[id]` (set in `wdg_kick()`, initially 0) and feed iff `last_kick[i] + timeout[i] > xTaskGetTickCount()` for every `i`. Keep the `missed[id]` flag only to report MISS/RECOVER once.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

void wdg_report_miss(int id);
void wdg_report_recover(int id);
void hw_wdg_feed(void);

#define WDG_MAX 5

static TimerHandle_t s_tmr[WDG_MAX];
static TickType_t s_timeout[WDG_MAX];
static TickType_t s_last[WDG_MAX];     /* tick of the last kick (0 at start) */
static int s_missed[WDG_MAX];
static int s_n;

/* one-shot, one per task: expiry = last kick + timeout -> deadline missed */
static void deadline_cb(TimerHandle_t xTimer)
{
    int id = (int)(uintptr_t)pvTimerGetTimerID(xTimer);

    s_missed[id] = 1;
    wdg_report_miss(id);
}

/* auto-reload: decide from the deadlines themselves, not from callback order */
static void feed_cb(TimerHandle_t xTimer)
{
    TickType_t now = xTaskGetTickCount();
    int i, healthy = 1;

    (void)xTimer;
    for (i = 0; i < s_n; i++) {
        if (s_last[i] + s_timeout[i] <= now) healthy = 0;
    }
    if (healthy) hw_wdg_feed();
}

void wdg_init(int n, const TickType_t timeout[], TickType_t feed_period)
{
    int i;
    TimerHandle_t feeder;

    s_n = n;
    for (i = 0; i < n; i++) {
        s_timeout[i] = timeout[i];
        s_last[i] = 0;
        s_missed[i] = 0;
        s_tmr[i] = xTimerCreate("wdg", timeout[i], pdFALSE, (void *)(uintptr_t)i, deadline_cb);
        xTimerStart(s_tmr[i], 0);      /* n + 1 <= 6 commands: fits the 16-entry queue */
    }
    feeder = xTimerCreate("feed", feed_period, pdTRUE, NULL, feed_cb);
    xTimerStart(feeder, 0);
}

void wdg_kick(int id)
{
    int was_missed;

    /* the timer task reads s_last/s_missed: update them atomically */
    taskENTER_CRITICAL();
    s_last[id] = xTaskGetTickCount();
    was_missed = s_missed[id];
    s_missed[id] = 0;
    taskEXIT_CRITICAL();

    if (was_missed) wdg_report_recover(id);
    xTimerReset(s_tmr[id], 0);         /* new deadline = now + timeout (also re-arms after a miss) */
}
@@@ explanation_md
**Approach.**
- **Deadline per task.** Each task gets a one-shot timer whose ID is the task index, and all of them share one callback. A kick is `xTimerReset()`: the timer service task (priority 7) preempts the kicking task and moves the expiry to `now + timeout` before `wdg_kick()` returns. If the timer ever expires, the task missed its deadline. The one-shot timer is then dormant, so MISS is reported exactly once. The next kick restarts it and reports RECOVER.
- **Feed gate.** An auto-reload timer runs the gate every `feed_period`. The subtle part is the same-tick case. When a deadline and a feed fall on the same tick, both callbacks run at that tick, in an order fixed by the timer list, not by you. A gate that reads a "missed" flag would feed or not feed depending on that order. The robust gate recomputes the condition from the data: `last_kick + timeout > now` for every task. Kicks always come after the callbacks at a tick (lower priority), so a kick at a feed tick naturally counts for the next decision.

**Complexity.** Kick: O(1) plus one active-list insertion (O(n)). Feed decision: O(n) every `feed_period`. RAM: n + 1 timer control blocks and three small arrays, and no supervisor task stack.

**Common mistakes**
- Feeding the hardware watchdog from a periodic task unconditionally. A hung task is then never caught, which defeats the whole design.
- Using `xTimerStart()` on an auto-reload timer per task. A missed task reports MISS every `timeout` ticks.
- An order-dependent gate (the flag approach). It passes most tests and fails when a deadline lands on a feed tick.
- Calling `wdg_report_recover()` inside the critical section, or calling `xTimerReset()` with a block time inside a critical section.
- Letting a hung **high-priority** task starve the timer service task. Here the daemon has the top priority. If it did not, a runaway task could block the gate and the hardware watchdog would reset the ECU without a diagnosis.
- Not protecting `last_kick` against the timer task. On a real CPU a tick interrupt can preempt `wdg_kick()` between its writes.

**Interview follow-ups**
- How would you add *window* supervision (a kick that comes too early is also a fault), as required by many safety standards?
- What if the timer service task itself hangs (a callback stuck in a loop)? Who supervises the supervisor?
- How do you supervise a task that legitimately blocks for a long time (waiting for a CAN message)? Pause/resume monitoring, or alive counters?
- How would you store the reason for a reset in RAM that survives the hardware watchdog reset (`.noinit` section)?
