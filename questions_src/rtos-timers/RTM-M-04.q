@@@ meta
id: RTM-M-04
topic: Software Timers
difficulty: Medium
type: FUNCTION
title: Timer Command Queue Limits At Boot And In An ISR Burst
tags: freertos, software-timers, timer-command-queue, timer-task-priority, isr, embedded, asked-in-automotive
@@@ statement_md
A data logger samples up to 40 channels, each with its own **auto-reload** software timer. Your first version started all timers in `app_init()` and restarted them all from an interrupt. On the bench, some channels never sample, and some ignore the restart. Find out why, and write a version that works.

```c
void sample_channel(int ch);          /* provided: the channel's periodic work (call it from the timer callback) */

void app_init(int n, const TickType_t period[]);   /* you write: called BEFORE the scheduler starts */
void resync_isr(void);                             /* you write: runs in INTERRUPT context */
```

Requirements:
- Channel `i` (0 <= i < n) has an auto-reload timer with period `period[i]`. It samples at t = period[i], 2*period[i], ..., counted from tick 0.
- A **resync** interrupt at tick `T` restarts **every** channel, so channel `i` next samples at exactly `T + period[i]` and then every `period[i]` after that. No channel may miss a resync.
- `period[]` stays valid for the whole run.

What you need to know about this configuration:
- Timer API calls do not touch the timer directly. They post a command to the **timer command queue**, which holds **16** commands. The timer service task (priority **7**) drains it in FIFO order. Each command is stamped with the tick at which it was **sent**, so `xTimerStart()`/`xTimerReset()` give expiry = send tick + period, even when the command is handled later.
- Before the scheduler starts, nobody drains the queue, and the block time of a timer call is ignored (it is treated as 0).
- When a task of priority 1..6 sends a command, the timer service task preempts it at once and handles the command before the call returns.
- An ISR cannot block. All interrupts of one tick run before the timer service task gets the CPU.

You **may** create one helper task (priority 1..6) and use task notifications. The harness checks that `sample_channel()` is only called from the timer service task.

**How it is tested.** The hidden `main()` calls `app_init()`, and at each resync tick an interrupt prints `[t=<tick>] RESYNC` and calls `resync_isr()`. The scheduler runs up to and including tick `D`. Then the harness prints, for each channel, how often it sampled and when it last sampled (`-` if never). A resync tick is never a tick at which any channel is due.

**Input**
```
<n>
<period_0> ... <period_n-1>
<m>
<resync_1> ... <resync_m>     (sorted, distinct; the line is absent when m = 0)
<D>
```

**Example**
```
Input:
3
10 20 30
1
25
70

Output:
[t=25] RESYNC
ch0 count=6 last=65
ch1 count=3 last=65
ch2 count=1 last=55
```
Channel 0 samples at 10 and 20. The resync at 25 moves its phase, so it then samples at 35, 45, 55 and 65. Channel 1 samples at 20, 45 and 65. Channel 2 would have sampled at 30, but the resync moved it to 55.
@@@ constraints_md
- 1 <= n <= 40, 2 <= period[i] <= 1000, 0 <= m <= 10, 1 <= resync < D <= 5000.
- No channel is due at a resync tick.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

void sample_channel(int ch);

#define MAX_CH 40
static TimerHandle_t s_tmr[MAX_CH];
static int s_n;

static void chan_cb(TimerHandle_t xTimer)
{
    sample_channel((int)(uintptr_t)pvTimerGetTimerID(xTimer));
}

/* First version: works on the desk with 3 channels, fails on the bench with 40. */
void app_init(int n, const TickType_t period[])
{
    int i;

    s_n = n;
    for (i = 0; i < n; i++) {
        s_tmr[i] = xTimerCreate("ch", period[i], pdTRUE, (void *)(uintptr_t)i, chan_cb);
        xTimerStart(s_tmr[i], 0);
    }
}

void resync_isr(void)
{
    BaseType_t woken = pdFALSE;
    int i;

    for (i = 0; i < s_n; i++) {
        xTimerResetFromISR(s_tmr[i], &woken);
    }
    portYIELD_FROM_ISR(woken);
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"
#include "sim.h"

#define H_MAX_CH 40

static unsigned g_count[H_MAX_CH];
static unsigned g_last[H_MAX_CH];
static int g_bad_ctx, g_bad_ch;

void sample_channel(int ch)
{
    if (xTaskGetCurrentTaskHandle() != xTimerGetTimerDaemonTaskHandle()) g_bad_ctx = 1;
    if (ch < 0 || ch >= H_MAX_CH) { g_bad_ch = 1; return; }
    g_count[ch]++;
    g_last[ch] = (unsigned)xTaskGetTickCount();
}

/*USER_CODE*/

static void resync_irq(void *arg)
{
    (void)arg;
    printf("[t=%u] RESYNC\n", (unsigned)xTaskGetTickCountFromISR());
    resync_isr();
}

int main(void)
{
    static TickType_t period[H_MAX_CH];
    unsigned i, p, m, t, dur;
    int n;

    if (scanf("%d", &n) != 1 || n < 1 || n > H_MAX_CH) return 1;
    for (i = 0; i < (unsigned)n; i++) {
        if (scanf("%u", &p) != 1) return 1;
        period[i] = (TickType_t)p;
    }
    if (scanf("%u", &m) != 1) return 1;
    for (i = 0; i < m; i++) {
        if (scanf("%u", &t) != 1) return 1;
        xSimScheduleInterrupt((TickType_t)t, resync_irq, NULL);
    }
    if (scanf("%u", &dur) != 1) return 1;

    app_init(n, period);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    if (g_bad_ctx) printf("FAIL: sample_channel() called outside the timer service task\n");
    if (g_bad_ch) printf("FAIL: sample_channel() called with a bad channel\n");
    for (i = 0; i < (unsigned)n; i++) {
        if (g_count[i]) printf("ch%u count=%u last=%u\n", i, g_count[i], g_last[i]);
        else printf("ch%u count=0 last=-\n", i);
    }
    return 0;
}
@@@ sample_input
3
10 20 30
1
25
70
@@@ sample_output
[t=25] RESYNC
ch0 count=6 last=65
ch1 count=3 last=65
ch2 count=1 last=55
@@@ sample_input
20
5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
0
24
@@@ sample_output
ch0 count=4 last=20
ch1 count=4 last=24
ch2 count=3 last=21
ch3 count=3 last=24
ch4 count=2 last=18
ch5 count=2 last=20
ch6 count=2 last=22
ch7 count=2 last=24
ch8 count=1 last=13
ch9 count=1 last=14
ch10 count=1 last=15
ch11 count=1 last=16
ch12 count=1 last=17
ch13 count=1 last=18
ch14 count=1 last=19
ch15 count=1 last=20
ch16 count=1 last=21
ch17 count=1 last=22
ch18 count=1 last=23
ch19 count=1 last=24
@@@ hidden_input
1
7
2
3 12
30
@@@ hidden_output
[t=3] RESYNC
[t=12] RESYNC
ch0 count=3 last=26
@@@ hidden_input
16
100 100 100 100 100 100 100 100 100 100 100 100 100 100 100 100
2
1 150
400
@@@ hidden_output
[t=1] RESYNC
[t=150] RESYNC
ch0 count=3 last=350
ch1 count=3 last=350
ch2 count=3 last=350
ch3 count=3 last=350
ch4 count=3 last=350
ch5 count=3 last=350
ch6 count=3 last=350
ch7 count=3 last=350
ch8 count=3 last=350
ch9 count=3 last=350
ch10 count=3 last=350
ch11 count=3 last=350
ch12 count=3 last=350
ch13 count=3 last=350
ch14 count=3 last=350
ch15 count=3 last=350

@@@ hidden_input
17
40 40 40 40 40 40 40 40 40 40 40 40 40 40 40 40 40
1
50
200
@@@ hidden_output
[t=50] RESYNC
ch0 count=4 last=170
ch1 count=4 last=170
ch2 count=4 last=170
ch3 count=4 last=170
ch4 count=4 last=170
ch5 count=4 last=170
ch6 count=4 last=170
ch7 count=4 last=170
ch8 count=4 last=170
ch9 count=4 last=170
ch10 count=4 last=170
ch11 count=4 last=170
ch12 count=4 last=170
ch13 count=4 last=170
ch14 count=4 last=170
ch15 count=4 last=170
ch16 count=4 last=170

@@@ hidden_input
40
101 103 107 109 113 127 131 137 139 149 151 157 163 167 173 179 181 191 193 197 199 211 223 227 229 233 239 241 251 257 263 269 271 277 281 283 293 307 311 313
3
1 2 3
2000
@@@ hidden_output
[t=1] RESYNC
[t=2] RESYNC
[t=3] RESYNC
ch0 count=19 last=1922
ch1 count=19 last=1960
ch2 count=18 last=1929
ch3 count=18 last=1965
ch4 count=17 last=1924
ch5 count=15 last=1908
ch6 count=15 last=1968
ch7 count=14 last=1921
ch8 count=14 last=1949
ch9 count=13 last=1940
ch10 count=13 last=1966
ch11 count=12 last=1887
ch12 count=12 last=1959
ch13 count=11 last=1840
ch14 count=11 last=1906
ch15 count=11 last=1972
ch16 count=11 last=1994
ch17 count=10 last=1913
ch18 count=10 last=1933
ch19 count=10 last=1973
ch20 count=10 last=1993
ch21 count=9 last=1902
ch22 count=8 last=1787
ch23 count=8 last=1819
ch24 count=8 last=1835
ch25 count=8 last=1867
ch26 count=8 last=1915
ch27 count=8 last=1931
ch28 count=7 last=1760
ch29 count=7 last=1802
ch30 count=7 last=1844
ch31 count=7 last=1886
ch32 count=7 last=1900
ch33 count=7 last=1942
ch34 count=7 last=1970
ch35 count=7 last=1984
ch36 count=6 last=1761
ch37 count=6 last=1845
ch38 count=6 last=1869
ch39 count=6 last=1881

@@@ hidden_input
40
50 50 50 50 50 50 50 50 50 50 50 50 50 50 50 50 50 50 50 50 60 60 60 60 60 60 60 60 60 60 60 60 60 60 60 60 60 60 60 60
3
70 135 333
500
@@@ hidden_output
[t=70] RESYNC
[t=135] RESYNC
[t=333] RESYNC
ch0 count=8 last=483
ch1 count=8 last=483
ch2 count=8 last=483
ch3 count=8 last=483
ch4 count=8 last=483
ch5 count=8 last=483
ch6 count=8 last=483
ch7 count=8 last=483
ch8 count=8 last=483
ch9 count=8 last=483
ch10 count=8 last=483
ch11 count=8 last=483
ch12 count=8 last=483
ch13 count=8 last=483
ch14 count=8 last=483
ch15 count=8 last=483
ch16 count=8 last=483
ch17 count=8 last=483
ch18 count=8 last=483
ch19 count=8 last=483
ch20 count=7 last=453
ch21 count=7 last=453
ch22 count=7 last=453
ch23 count=7 last=453
ch24 count=7 last=453
ch25 count=7 last=453
ch26 count=7 last=453
ch27 count=7 last=453
ch28 count=7 last=453
ch29 count=7 last=453
ch30 count=7 last=453
ch31 count=7 last=453
ch32 count=7 last=453
ch33 count=7 last=453
ch34 count=7 last=453
ch35 count=7 last=453
ch36 count=7 last=453
ch37 count=7 last=453
ch38 count=7 last=453
ch39 count=7 last=453

@@@ hidden_input
2
1000 999
0
5000
@@@ hidden_output
ch0 count=5 last=5000
ch1 count=5 last=4995
@@@ hint
Count the commands. Before the scheduler starts, `n` start commands go into a 16-entry queue that nobody drains, so commands 17..n fail. In the ISR, `n` reset commands are sent at once and the timer task cannot run in between, so again only 16 fit. Check the return values to see it.
@@@ hint
Send the commands from a **task** instead. The timer service task has priority 7, so it handles each command before `xTimerStart()`/`xTimerReset()` returns, and the queue never fills. A helper task starts all timers at tick 0. The ISR only does `vTaskNotifyGiveFromISR(helper, &w); portYIELD_FROM_ISR(w);`, and the helper (woken at the same tick) resets every timer. The send tick is still T, so the expiry is T + period.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

void sample_channel(int ch);

#define MAX_CH 40
static TimerHandle_t s_tmr[MAX_CH];
static int s_n;
static TaskHandle_t s_helper;

static void chan_cb(TimerHandle_t xTimer)
{
    sample_channel((int)(uintptr_t)pvTimerGetTimerID(xTimer));
}

/* Priority 6 (< timer task 7): every timer command it sends is processed
   before the call returns, so the 16-entry command queue never fills. */
static void timer_helper(void *pv)
{
    int i;

    (void)pv;
    for (i = 0; i < s_n; i++) {
        xTimerStart(s_tmr[i], portMAX_DELAY);          /* tick 0: expiry = period */
    }
    for (;;) {
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);       /* one notification per resync */
        for (i = 0; i < s_n; i++) {
            xTimerReset(s_tmr[i], portMAX_DELAY);      /* expiry = now + period */
        }
    }
}

void app_init(int n, const TickType_t period[])
{
    int i;

    s_n = n;
    for (i = 0; i < n; i++) {
        /* create only: do not queue 40 start commands before the scheduler runs */
        s_tmr[i] = xTimerCreate("ch", period[i], pdTRUE, (void *)(uintptr_t)i, chan_cb);
    }
    xTaskCreate(timer_helper, "tmrhelp", configMINIMAL_STACK_SIZE, NULL, 6, &s_helper);
}

void resync_isr(void)
{
    BaseType_t woken = pdFALSE;

    /* one cheap notification instead of n queue writes from the ISR */
    vTaskNotifyGiveFromISR(s_helper, &woken);
    portYIELD_FROM_ISR(woken);   /* helper runs at this tick, so the resync tick is T */
}
@@@ explanation_md
**Approach.** Two separate bugs come from the same 16-entry timer command queue:

1. **Boot.** `xTimerStart()` before `vTaskStartScheduler()` only queues a command. The timer service task does not exist yet, so nothing drains the queue, and the block time is forced to 0. Starts 17..n return `pdFAIL`, and those channels never run. That is sample 2: with the starter, channels 16..19 stay silent.
2. **ISR burst.** `xTimerResetFromISR()` cannot block, and the daemon cannot run until the ISR (and every other ISR of that tick) has returned. Again only 16 resets fit.

The fix is to send the commands from a **task**. The timer service task (priority 7) preempts any application task the moment a command arrives, so each `xTimerStart()`/`xTimerReset()` is processed before it returns, and the queue holds at most one command at a time. The ISR does the cheapest possible thing: one task notification, with `portYIELD_FROM_ISR()` so the helper runs at the **same tick**. The commands are then stamped with tick T, and every channel gets expiry `T + period[i]`.

Starting the first 16 timers in `app_init()` and the rest from the helper also works. So does sending 16 resets from the ISR and deferring the rest. The rule is the same: never send more commands than the queue can hold before the daemon gets a chance to run.

**Complexity.** Boot: n commands, O(n) total, each handled immediately. Resync: O(1) in the ISR, O(n) in the helper, plus O(n * active timers) for the list insertions. RAM: one helper task stack and one TCB, instead of a timer queue sized for the worst burst (`configTIMER_QUEUE_LENGTH` >= 40 would also work, but it costs RAM and only hides the design issue).

**Common mistakes**
- Ignoring the `pdFAIL` return of `xTimerStart()`/`xTimerResetFromISR()`: the failure is silent.
- Waking the helper without `portYIELD_FROM_ISR()`: it runs one tick late, so every channel resyncs to `T + 1 + period`.
- Thinking `xTimerStart(h, portMAX_DELAY)` before the scheduler waits for space: the block time is ignored there.
- Giving the helper a priority above the timer task (not possible here, since 7 is the maximum). In general, a sender with a higher priority than the daemon can fill the queue even from task context.
- Assuming that a reset from an ISR at the exact expiry tick still lets the old expiry fire. When the timer task wakes, it drains the command queue before it checks for expired timers, so the reset wins. Resync ticks avoid this case here.

**Interview follow-ups**
- Why does FreeRTOS stamp each command with its send time instead of the processing time? What would go wrong otherwise?
- How would you choose `configTIMER_TASK_PRIORITY`? What breaks when it is the lowest application priority?
- How could one auto-reload timer plus a per-channel phase table replace 40 timers here?
- What does `xTimerPendFunctionCallFromISR()` add to the same queue, and how does that change the sizing?
