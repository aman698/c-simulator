@@@ meta
id: RTM-M-01
topic: Software Timers
difficulty: Medium
type: FUNCTION
title: Button Debounce With xTimerResetFromISR
tags: freertos, software-timers, debounce, xtimerresetfromisr, isr, embedded, asked-in-automotive
@@@ statement_md
A steering-wheel button is wired to a GPIO with an edge interrupt on **both** edges. The contact bounces, so a single press can cause a burst of edges. Debounce it with **one one-shot software timer** that the ISR restarts on every edge. Report a new stable state only once the pin has been quiet for `window` ticks.

```c
int  button_read(void);           /* provided: current raw pin level, 1 = pressed (ISR- and task-safe) */
void button_report(int pressed);  /* provided: prints "[t=<tick>] PRESSED" or "[t=<tick>] RELEASED" */

void debounce_init(TickType_t window);   /* you write: called before the scheduler starts */
void button_isr(void);                   /* you write: runs in INTERRUPT context on every edge */
```

Behaviour:
- Before the first edge the stable state is **released** (0). No timer runs until the first edge.
- Every edge at tick `t` restarts the debounce window, so the timer expires at `t + window`. Several edges in a row keep pushing the expiry out.
- When the timer expires, the callback reads `button_read()`. If the level differs from the last **reported** stable state, call `button_report(level)` and remember it. Otherwise report nothing, because it was only a glitch.

Rules:
- `button_isr()` runs in interrupt context. Use only `...FromISR()` APIs and finish with `portYIELD_FROM_ISR()`. The task versions (`xTimerReset`, `xTimerStart`, ...) are banned, and so are `vTaskDelay()` and creating tasks.
- `button_report()` must be called from the timer callback. The harness also counts how many times your timer expires, so a polling timer is detected.

**Same-tick ordering.** An interrupt at tick `T` is handled before the timer service task processes tick `T`. When the timer service task wakes up, it processes the **queued commands before** it looks for expired timers. So an edge that arrives exactly at the tick when the timer would expire resets the timer: it does **not** expire at that tick, and the window restarts.

**How it is tested.** The hidden `main()` calls `debounce_init()`. At each listed edge tick, an interrupt toggles the raw pin level and then calls `button_isr()`. Several edges can share a tick. The scheduler runs up to and including tick `D`. Then the harness prints the number of edges, how many times your timer expired, and the final reported state.

**Input**
```
<window> <n>
<t1> ... <tn>        (sorted, may repeat; the line is absent when n = 0)
<D>
```

**Example**
```
Input:
10 6
5 7 9 50 52 53
100

Output:
[t=19] PRESSED
[t=63] RELEASED
edges=6
timer expirations=2
state: RELEASED
```
After the edges at 5, 7 and 9 the pin is 1. The last edge was at 9, so the timer expires at 19 and reports PRESSED. The edges at 50, 52 and 53 leave the pin at 0, so RELEASED is reported at 53 + 10 = 63.
@@@ constraints_md
- 1 <= window <= 500, 0 <= n <= 100, 1 <= t1 <= ... <= tn <= D <= 5000.
- At most 3 edges share one tick.
- Exactly one software timer.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

int  button_read(void);
void button_report(int pressed);

static void debounce_cb(TimerHandle_t xTimer)
{
    (void)xTimer;
    /* TODO: read the pin, report if the stable state changed */
}

void debounce_init(TickType_t window)
{
    /* TODO: create a one-shot timer (do not start it yet) */
    (void)window;
    (void)debounce_cb;
}

void button_isr(void)
{
    /* TODO: restart the debounce window from the ISR */
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"
#include "sim.h"

static volatile int g_pin;
static int g_reported;
static unsigned g_edges, g_expirations, g_ntimers;
static int g_bad_ctx;
static TimerCallbackFunction_t g_user_cb;

int button_read(void) { return g_pin; }

void button_report(int pressed)
{
    if (xTaskGetCurrentTaskHandle() != xTimerGetTimerDaemonTaskHandle()) g_bad_ctx = 1;
    g_reported = pressed ? 1 : 0;
    printf("[t=%u] %s\n", (unsigned)xTaskGetTickCount(), pressed ? "PRESSED" : "RELEASED");
}

static void h_trampoline(TimerHandle_t t)
{
    g_expirations++;
    g_user_cb(t);
}

static TimerHandle_t h_timer_create(const char *name, TickType_t period, BaseType_t reload,
                                    void *id, TimerCallbackFunction_t cb)
{
    g_ntimers++;
    g_user_cb = cb;
    return xTimerCreate(name, period, reload, id, h_trampoline);
}

#define xTimerCreate(a, b, c, d, e) h_timer_create(a, b, c, d, e)
#define xTimerCreateStatic(...) xTimerCreateStatic_is_not_allowed_here
#define xTaskCreate(...) xTaskCreate_is_not_allowed_here
#define xTaskCreateStatic(...) xTaskCreateStatic_is_not_allowed_here
#define vTaskDelay(x) vTaskDelay_is_not_allowed_here
#undef xTimerReset
#define xTimerReset(...) xTimerReset_is_not_allowed_here
#undef xTimerStart
#define xTimerStart(...) xTimerStart_is_not_allowed_here

/*USER_CODE*/

#undef xTimerCreate
#undef xTimerCreateStatic
#undef xTaskCreate
#undef xTaskCreateStatic
#undef vTaskDelay
#undef xTimerReset
#undef xTimerStart

static void edge_irq(void *arg)
{
    (void)arg;
    g_pin = !g_pin;
    g_edges++;
    button_isr();
}

int main(void)
{
    unsigned window, n, dur, i, t;

    if (scanf("%u %u", &window, &n) != 2) return 1;
    debounce_init((TickType_t)window);
    for (i = 0; i < n; i++) {
        if (scanf("%u", &t) != 1) return 1;
        xSimScheduleInterrupt((TickType_t)t, edge_irq, NULL);
    }
    if (scanf("%u", &dur) != 1) return 1;

    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    if (g_bad_ctx) printf("FAIL: button_report() called outside the timer service task\n");
    if (g_ntimers != 1) printf("FAIL: %u timers created (expected 1)\n", g_ntimers);
    printf("edges=%u\n", g_edges);
    printf("timer expirations=%u\n", g_expirations);
    printf("state: %s\n", g_reported ? "PRESSED" : "RELEASED");
    return 0;
}
@@@ sample_input
10 6
5 7 9 50 52 53
100
@@@ sample_output
[t=19] PRESSED
[t=63] RELEASED
edges=6
timer expirations=2
state: RELEASED
@@@ sample_input
5 5
10 15 20 40 41
60
@@@ sample_output
[t=25] PRESSED
edges=5
timer expirations=2
state: PRESSED
@@@ hidden_input
10 0
100
@@@ hidden_output
edges=0
timer expirations=0
state: RELEASED
@@@ hidden_input
1 2
1 3
10
@@@ hidden_output
[t=2] PRESSED
[t=4] RELEASED
edges=2
timer expirations=2
state: RELEASED
@@@ hidden_input
20 5
30 30 70 70 70
200
@@@ hidden_output
[t=90] PRESSED
edges=5
timer expirations=2
state: PRESSED
@@@ hidden_input
8 21
3 6 9 12 15 18 21 24 27 30 33 36 39 42 45 48 51 54 57 60 100
150
@@@ hidden_output
[t=108] PRESSED
edges=21
timer expirations=2
state: PRESSED
@@@ hidden_input
50 2
100 300
350
@@@ hidden_output
[t=150] PRESSED
[t=350] RELEASED
edges=2
timer expirations=2
state: RELEASED
@@@ hidden_input
10 4
10 20 30 40
100
@@@ hidden_output
edges=4
timer expirations=1
state: RELEASED
@@@ hint
Create the timer one-shot and dormant in `debounce_init()`. In the ISR, `xTimerResetFromISR(h, &woken)` both starts a dormant timer and restarts a running one, with expiry = ISR tick + window.
@@@ hint
ISR: `BaseType_t w = pdFALSE; xTimerResetFromISR(h, &w); portYIELD_FROM_ISR(w);`. Callback: `int lvl = button_read(); if (lvl != stable) { stable = lvl; button_report(lvl); }`, where `stable` is a static that starts at 0.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

int  button_read(void);
void button_report(int pressed);

static TimerHandle_t s_db;
static int s_stable;          /* last reported state, only touched by the timer task */

static void debounce_cb(TimerHandle_t xTimer)
{
    int lvl = button_read();

    (void)xTimer;
    if (lvl != s_stable) {     /* quiet for a full window and different: a real change */
        s_stable = lvl;
        button_report(lvl);
    }                          /* same as before: it was a glitch, ignore it */
}

void debounce_init(TickType_t window)
{
    s_stable = 0;
    s_db = xTimerCreate("debounce", window, pdFALSE, NULL, debounce_cb);
}

void button_isr(void)
{
    BaseType_t woken = pdFALSE;

    /* (re)start the window: expiry = tick of this interrupt + window */
    xTimerResetFromISR(s_db, &woken);
    portYIELD_FROM_ISR(woken);
}
@@@ explanation_md
**Approach.** The ISR does the minimum: it restarts a one-shot timer with `xTimerResetFromISR()`. The command records the tick at which it was sent (`xTaskGetTickCountFromISR()`), so the expiry is *edge tick + window* even if the timer task handles the command a little later. Every new edge pushes the expiry out again. The timer therefore expires only after `window` quiet ticks, and the callback, running in task context, samples the settled level. It compares that level with the last **reported** state. A press-release glitch that ends back at the old level produces no report.

The boundary case comes from the timer task's main loop. When the timer task wakes at tick `T`, it drains its command queue before it checks the active list. An edge interrupt at `T` has already queued a reset, so the timer is moved to `T + window` before it can expire.

**Complexity.** O(1) per edge: one queue message from the ISR and one active-list insertion. Per press, one callback. CPU load is proportional to the number of edges, with no polling. RAM: one timer and two statics.

**Common mistakes**
- Calling `xTimerReset()` (task API) inside the ISR. On a real port this corrupts the kernel or asserts. The simulator reports a Runtime Error.
- Forgetting `portYIELD_FROM_ISR()`. The command is then handled later. The expiry tick does not change, because it is stamped at send time, but deferred work behind it is delayed.
- Reading the pin in the ISR and reporting from there: you report the bounce, not the settled level.
- Reporting on every expiry instead of on a *change*: a glitch produces a duplicate PRESSED.
- Debouncing with a periodic 1 ms polling timer. It works, but it wakes the CPU 1000 times a second, and the harness counts the expirations.
- Ignoring the return value of `xTimerResetFromISR()`. With a bouncy switch and a slow timer task, 16 queued commands fill the timer queue and the reset is lost. Mention it, and size `configTIMER_QUEUE_LENGTH` accordingly.

**Interview follow-ups**
- Why not just disable the edge interrupt for 20 ms after the first edge? What is lost?
- The timer task has priority 7 here. What changes if it is lower than the task that consumes button events?
- How would you debounce 16 buttons on one port with a single timer?
- How do you detect a long press (held for more than 2 s) using the same timer?
