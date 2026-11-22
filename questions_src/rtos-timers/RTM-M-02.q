@@@ meta
id: RTM-M-02
topic: Software Timers
difficulty: Medium
type: FUNCTION
title: Adaptive Blink Rate With xTimerChangePeriod
tags: freertos, software-timers, xtimerchangeperiod, xtimerstop, state-machine, embedded
@@@ statement_md
A charging-port LED shows the charger state: **off**, **slow blink** (charging) or **fast blink** (fault). A supervisor task changes the mode at run time. Drive the LED with **one auto-reload software timer** whose period you change with `xTimerChangePeriod()`.

```c
enum { MODE_OFF = 0, MODE_SLOW = 1, MODE_FAST = 2 };

void led_set(int on);     /* provided: prints "[t=<tick>] LED ON" or "[t=<tick>] LED OFF" */

TimerHandle_t blink_init(TickType_t slow, TickType_t fast);  /* you write: before the scheduler */
void set_mode(int mode);                                     /* you write: called from a task */
```

Behaviour:
- At start the mode is `MODE_OFF`, the LED is off and no timer runs. `blink_init()` creates the timer, leaves it dormant, and returns its handle.
- While blinking, every expiry of the timer toggles the LED (`led_set(!current)`).
- `set_mode(m)` with the **same** mode as the current one does **nothing**. In particular, it must not disturb the blink phase.
- Switching to `MODE_SLOW` or `MODE_FAST` from any other mode: the next toggle happens exactly one new period after the call (`now + slow` or `now + fast`). The LED keeps its current state until then.
- Switching to `MODE_OFF`: stop the timer and, **if the LED is on**, switch it off with `led_set(0)`.

Rules:
- Exactly one timer for the whole run. Deleting timers, creating tasks and `vTaskDelay()` are banned.
- `set_mode()` runs in a task of priority 3. Use block time `0` for timer commands.

**Same-tick ordering.** The timer service task (priority 7) runs before the supervisor task. If a mode change happens at a tick where the timer is due, the toggle happens first, and then the mode change takes effect.

**How it is tested.** The hidden supervisor task prints `[t=<tick>] mode <OFF|SLOW|FAST>` and then calls `set_mode()` at each listed tick, in input order. The scheduler runs up to and including tick `D`. Then the harness prints the number of `led_set()` calls and whether the timer is active. If the timer is active, it also prints the timer's period.

**Input**
```
<slow> <fast> <n>
<tick> <OFF|SLOW|FAST>     (n lines, ticks non-decreasing)
<D>
```

**Example**
```
Input:
10 3 4
5 SLOW
31 FAST
38 FAST
41 OFF
60

Output:
[t=5] mode SLOW
[t=15] LED ON
[t=25] LED OFF
[t=31] mode FAST
[t=34] LED ON
[t=37] LED OFF
[t=38] mode FAST
[t=40] LED ON
[t=41] mode OFF
[t=41] LED OFF
led writes=6
active: no
```
At t=31 the period changes to 3, so the next toggle is at 31 + 3 = 34. The second `FAST` at t=38 changes nothing: the toggle at 40 stays on its phase (a restart would have moved it to 41). At t=41 the LED is on, so going OFF switches it off.
@@@ constraints_md
- 1 <= fast, slow <= 500, 0 <= n <= 50, 1 <= tick <= D <= 5000.
- Exactly one software timer, never deleted.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

enum { MODE_OFF = 0, MODE_SLOW = 1, MODE_FAST = 2 };

void led_set(int on);

static void blink_cb(TimerHandle_t xTimer)
{
    (void)xTimer;
    /* TODO: toggle the LED */
}

TimerHandle_t blink_init(TickType_t slow, TickType_t fast)
{
    /* TODO: create the (dormant) auto-reload timer */
    (void)slow;
    (void)fast;
    (void)blink_cb;
    return NULL;
}

void set_mode(int mode)
{
    /* TODO */
    (void)mode;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"
#include "sim.h"

static unsigned g_writes, g_ntimers;
static int g_led;

void led_set(int on)
{
    g_led = on ? 1 : 0;
    g_writes++;
    printf("[t=%u] LED %s\n", (unsigned)xTaskGetTickCount(), g_led ? "ON" : "OFF");
}

static TimerHandle_t h_timer_create(const char *name, TickType_t period, BaseType_t reload,
                                    void *id, TimerCallbackFunction_t cb)
{
    g_ntimers++;
    return xTimerCreate(name, period, reload, id, cb);
}

#define xTimerCreate(a, b, c, d, e) h_timer_create(a, b, c, d, e)
#define xTimerCreateStatic(...) xTimerCreateStatic_is_not_allowed_here
#undef xTimerDelete
#define xTimerDelete(...) xTimerDelete_is_not_allowed_here
#define xTaskCreate(...) xTaskCreate_is_not_allowed_here
#define xTaskCreateStatic(...) xTaskCreateStatic_is_not_allowed_here
#define vTaskDelay(x) vTaskDelay_is_not_allowed_here

/*USER_CODE*/

#undef xTimerCreate
#undef xTimerCreateStatic
#undef xTimerDelete
#undef xTaskCreate
#undef xTaskCreateStatic
#undef vTaskDelay

static unsigned g_n;
static TickType_t g_tick[64];
static int g_mode[64];
static const char *const g_names[3] = { "OFF", "SLOW", "FAST" };

static void supervisor(void *p)
{
    unsigned i;
    (void)p;
    for (i = 0; i < g_n; i++) {
        TickType_t now = xTaskGetTickCount();
        if (g_tick[i] > now) vTaskDelay(g_tick[i] - now);
        printf("[t=%u] mode %s\n", (unsigned)xTaskGetTickCount(), g_names[g_mode[i]]);
        set_mode(g_mode[i]);
    }
    for (;;) vTaskDelay(portMAX_DELAY);
}

int main(void)
{
    unsigned slow, fast, dur, i, t;
    char word[8];
    TimerHandle_t h;

    if (scanf("%u %u %u", &slow, &fast, &g_n) != 3 || g_n > 64) return 1;
    for (i = 0; i < g_n; i++) {
        if (scanf("%u %7s", &t, word) != 2) return 1;
        g_tick[i] = (TickType_t)t;
        g_mode[i] = strcmp(word, "SLOW") == 0 ? 1 : strcmp(word, "FAST") == 0 ? 2 : 0;
    }
    if (scanf("%u", &dur) != 1) return 1;

    h = blink_init((TickType_t)slow, (TickType_t)fast);
    xTaskCreate(supervisor, "sup", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    if (g_ntimers != 1) printf("FAIL: %u timers created (expected 1)\n", g_ntimers);
    printf("led writes=%u\n", g_writes);
    if (h == NULL) {
        printf("FAIL: blink_init() returned NULL\n");
        return 0;
    }
    if (xTimerIsTimerActive(h) != pdFALSE) {
        printf("active: yes\n");
        printf("timer period=%u\n", (unsigned)xTimerGetPeriod(h));
    } else {
        printf("active: no\n");
    }
    return 0;
}
@@@ sample_input
10 3 4
5 SLOW
31 FAST
38 FAST
41 OFF
60
@@@ sample_output
[t=5] mode SLOW
[t=15] LED ON
[t=25] LED OFF
[t=31] mode FAST
[t=34] LED ON
[t=37] LED OFF
[t=38] mode FAST
[t=40] LED ON
[t=41] mode OFF
[t=41] LED OFF
led writes=6
active: no
@@@ sample_input
5 2 2
1 FAST
9 SLOW
20
@@@ sample_output
[t=1] mode FAST
[t=3] LED ON
[t=5] LED OFF
[t=7] LED ON
[t=9] LED OFF
[t=9] mode SLOW
[t=14] LED ON
[t=19] LED OFF
led writes=6
active: yes
timer period=5
@@@ hidden_input
10 2 0
50
@@@ hidden_output
led writes=0
active: no
@@@ hidden_input
1 1 1
1 SLOW
6
@@@ hidden_output
[t=1] mode SLOW
[t=2] LED ON
[t=3] LED OFF
[t=4] LED ON
[t=5] LED OFF
[t=6] LED ON
led writes=5
active: yes
timer period=1
@@@ hidden_input
4 2 4
2 SLOW
6 OFF
8 OFF
10 SLOW
20
@@@ hidden_output
[t=2] mode SLOW
[t=6] LED ON
[t=6] mode OFF
[t=6] LED OFF
[t=8] mode OFF
[t=10] mode SLOW
[t=14] LED ON
[t=18] LED OFF
led writes=4
active: yes
timer period=4
@@@ hidden_input
7 3 5
10 SLOW
12 FAST
13 SLOW
14 FAST
15 SLOW
30
@@@ hidden_output
[t=10] mode SLOW
[t=12] mode FAST
[t=13] mode SLOW
[t=14] mode FAST
[t=15] mode SLOW
[t=22] LED ON
[t=29] LED OFF
led writes=2
active: yes
timer period=7
@@@ hidden_input
6 2 2
5 FAST
5 SLOW
25
@@@ hidden_output
[t=5] mode FAST
[t=5] mode SLOW
[t=11] LED ON
[t=17] LED OFF
[t=23] LED ON
led writes=3
active: yes
timer period=6
@@@ hidden_input
100 25 3
1 FAST
100 SLOW
1000 OFF
1200
@@@ hidden_output
[t=1] mode FAST
[t=26] LED ON
[t=51] LED OFF
[t=76] LED ON
[t=100] mode SLOW
[t=200] LED OFF
[t=300] LED ON
[t=400] LED OFF
[t=500] LED ON
[t=600] LED OFF
[t=700] LED ON
[t=800] LED OFF
[t=900] LED ON
[t=1000] LED OFF
[t=1000] mode OFF
led writes=12
active: no
@@@ hint
`xTimerChangePeriod(h, p, 0)` sets the new period **and** (re)starts the timer: the next expiry is (tick of the call) + p, even if the timer was dormant. So you do not need a separate `xTimerStart()`.
@@@ hint
Keep `static int mode, led;`. In `set_mode`: return if the mode is unchanged. For OFF: `xTimerStop(h, 0); if (led) { led = 0; led_set(0); }`. Otherwise: `xTimerChangePeriod(h, m == MODE_SLOW ? slow : fast, 0)`. Callback: `led = !led; led_set(led);`.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

enum { MODE_OFF = 0, MODE_SLOW = 1, MODE_FAST = 2 };

void led_set(int on);

static TimerHandle_t s_tmr;
static TickType_t s_slow, s_fast;
static int s_mode = MODE_OFF;
static int s_led;              /* only changed by the timer task or by set_mode while stopped */

static void blink_cb(TimerHandle_t xTimer)
{
    (void)xTimer;
    s_led = !s_led;
    led_set(s_led);
}

TimerHandle_t blink_init(TickType_t slow, TickType_t fast)
{
    s_slow = slow;
    s_fast = fast;
    s_mode = MODE_OFF;
    s_led = 0;
    /* the period given here is only a placeholder until the first mode change */
    s_tmr = xTimerCreate("blink", slow, pdTRUE, NULL, blink_cb);
    return s_tmr;
}

void set_mode(int mode)
{
    if (mode == s_mode) return;                 /* do not disturb the phase */
    s_mode = mode;

    if (mode == MODE_OFF) {
        /* the timer task (prio 7) handles the stop before we continue */
        xTimerStop(s_tmr, 0);
        if (s_led) {
            s_led = 0;
            led_set(0);
        }
    } else {
        /* new period, next expiry = now + period; also starts a dormant timer */
        xTimerChangePeriod(s_tmr, mode == MODE_SLOW ? s_slow : s_fast, 0);
    }
}
@@@ explanation_md
**Approach.** One auto-reload timer, three operations:
- **Blink at a new rate:** `xTimerChangePeriod(h, p, 0)`. The timer service task removes the timer from the active list, stores the new period and re-inserts it with expiry = *now + p*. If the timer was dormant, this also starts it. So OFF -> SLOW is a single call.
- **Stop:** `xTimerStop(h, 0)`. Because the timer task (priority 7) preempts the supervisor (priority 3), the stop is processed inside the `xTimerStop()` call. No expiry can sneak in afterwards, and it is safe to switch the LED off in task context right after.
- **Same mode:** do nothing. Calling `xTimerChangePeriod()` with the same period is *not* a no-op: it restarts the timer and shifts the phase. The second `FAST` in the example would move the toggle from 40 to 41.

**Complexity.** O(1) per mode change and per toggle (one command message and one active-list insertion). RAM: one timer and three statics. There is no blink task stack.

**Common mistakes**
- Calling `xTimerChangePeriod()` on every `set_mode()`. The phase jumps whenever the supervisor repeats the current mode (it often re-asserts the state periodically).
- `xTimerChangePeriod()` followed by `xTimerStart()`: harmless but redundant, because the period change already starts the timer. On a timer task with a *lower* priority, the two commands would also be handled at different times.
- Deleting and re-creating the timer to change its rate: heap churn, and a window where callbacks can run on a deleted handle.
- Leaving the LED on when going OFF, or calling `led_set(0)` when it is already off (a redundant write to a slow I/O expander).
- Assuming that `xTimerStop()` from a task with a **higher** priority than the timer task takes effect immediately. It does not: the command waits in the queue, and an expiry can still be processed first.

**Interview follow-ups**
- How does `xTimerChangePeriod()` behave when called from the timer's own callback? From an ISR?
- If the timer task had priority 1 and the supervisor priority 3, which LED writes could happen *after* `set_mode(MODE_OFF)` returned?
- How would you add a "breathing" (PWM-faded) mode without a second timer?
- Why can `set_mode()` safely read and write `s_led` here, and what would make it a race?
