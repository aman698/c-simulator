@@@ meta
id: RIS-M-03
topic: Interrupts & ISRs
difficulty: Medium
type: FUNCTION
title: Interrupt Bursts: Counting Semaphore Instead of Binary
tags: freertos, isr, counting-semaphore, binary-semaphore, lost-events, xsemaphoregivefromisr, embedded
@@@ statement_md
A parking-sensor ECU counts ultrasonic echo interrupts. Each echo must be processed **individually**. The legacy firmware used a binary semaphore. During a burst (several echoes while the handler is still busy with an earlier one) it processed only one of them, and nobody noticed that the others were missing.

A binary semaphore is a flag: giving it twice is the same as giving it once. A **counting semaphore** remembers *how many* events are pending, up to its maximum count. Rewrite the driver with one, and account for every event: each one is either processed, still pending, or explicitly reported as lost.

```c
void handle_event(void);                              /* provided: task context, processes the oldest event (C ticks) */
void event_lost(void);                                /* provided: call from the ISR when an event cannot be recorded */

void echo_isr(void);                                  /* you write */
SemaphoreHandle_t app_start(UBaseType_t max_pending); /* you write: returns the semaphore */
```

Rules:
- `app_start(max_pending)` runs before the scheduler. It creates a **counting** semaphore with maximum count `max_pending` and initial count 0, creates a handler task with **priority 3**, and returns the semaphore handle. After the run, `main()` reads the number of pending events with `uxSemaphoreGetCount()`.
- `echo_isr()` gives the semaphore with `xSemaphoreGiveFromISR()`. If the give fails (the count is already at `max_pending`), it calls `event_lost()`. It yields with `portYIELD_FROM_ISR()`.
- The handler loops: take the semaphore (block forever), then call `handle_event()` once. One take = one event.

**How it is tested.** A background task with priority 1 is always busy. `handle_event()` prints `[t=<now>] event irq t=<tick of that event>` (oldest unprocessed event first) and then works for `C` ticks, while new echoes keep arriving. The run includes tick `D`. Finally `main()` prints

```
irqs=<n> handled=<n> lost=<n> pending=<semaphore count>
```

followed by `CONSISTENT` if `irqs == handled + lost + pending` and the pending count matches the events the judge still has queued, or by `MISMATCH` otherwise.

**Input**
```
D C max_pending
N
t1 t2 ... tN      (non-decreasing; empty line when N = 0)
```

**Example**
```
Input:
30 2 5
5
3 3 3 4 20

Output:
[t=3] event irq t=3
[t=5] event irq t=3
[t=7] event irq t=3
[t=9] event irq t=4
[t=20] event irq t=20
irqs=5 handled=5 lost=0 pending=0
CONSISTENT
```
The three echoes at t=3 raise the count to 3. The first give unblocks the handler, which runs at t=3 thanks to the yield. While it works (ticks 4-5), the echo at t=4 raises the count again, so each event gets its own `handle_event()`. A binary semaphore would have produced only the lines at t=3 and t=5, and three echoes would have vanished without a trace.
@@@ constraints_md
- 1 <= D <= 20000, 0 <= C <= 5, 1 <= max_pending <= 20, 0 <= N <= 300, 1 <= ti <= D.
- One handler task (priority 3); exactly one `handle_event()` per successful take.
- Only `...FromISR()` APIs inside `echo_isr()`.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

void handle_event(void);   /* provided */
void event_lost(void);     /* provided */

static SemaphoreHandle_t s_echo_sem;

static void echo_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: take the semaphore (block forever), then handle_event() */
        vTaskDelay(1000);
    }
}

void echo_isr(void)
{
    /* TODO */
}

SemaphoreHandle_t app_start(UBaseType_t max_pending)
{
    /* TODO: create a counting semaphore (max_pending, 0) and the task (priority 3) */
    (void)max_pending;
    (void)echo_task;
    s_echo_sem = xSemaphoreCreateBinary();
    return s_echo_sem;
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "sim.h"

void echo_isr(void);
SemaphoreHandle_t app_start(UBaseType_t max_pending);
void handle_event(void);
void event_lost(void);

#define MAXEV 300
static TickType_t g_fifo[MAXEV];
static unsigned g_head, g_tail, g_raised, g_handled, g_lost, g_lost_now, g_errors, g_cost;

void event_lost(void)
{
    if (!xPortIsInsideInterrupt()) {
        printf("FAIL: event_lost() must be called from the ISR\n");
        g_errors++;
        return;
    }
    g_lost_now++;
}

void handle_event(void)
{
    unsigned now = (unsigned)xTaskGetTickCount();

    if (xPortIsInsideInterrupt()) {
        printf("FAIL: handle_event() called from the ISR\n");
        g_errors++;
        return;
    }
    if (g_head == g_tail) {
        printf("[t=%u] ERROR: handle_event() without a pending event\n", now);
        g_errors++;
        return;
    }
    printf("[t=%u] event irq t=%u\n", now, (unsigned)g_fifo[g_head++]);
    g_handled++;
    if (g_cost) vSimBusyWork((TickType_t)g_cost);
}

/*USER_CODE*/

static void irq_entry(void *arg)
{
    (void)arg;
    g_raised++;
    g_fifo[g_tail++] = xTaskGetTickCountFromISR();
    g_lost_now = 0;
    echo_isr();
    if (g_lost_now > 1) {
        printf("FAIL: event_lost() called %u times for one echo\n", g_lost_now);
        g_errors++;
    }
    if (g_lost_now) {
        g_tail--;
        g_lost++;
    }
}

static void background_task(void *p)
{
    (void)p;
    for (;;) vSimBusyWork(1);
}

int main(void)
{
    unsigned d, maxp, n, i, t, pending;
    SemaphoreHandle_t sem;

    if (scanf("%u %u %u %u", &d, &g_cost, &maxp, &n) != 4 || n > MAXEV) return 1;
    sem = app_start((UBaseType_t)maxp);
    if (sem == NULL) {
        printf("FAIL: app_start() returned NULL\n");
        return 0;
    }
    xTaskCreate(background_task, "bg", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    for (i = 0; i < n; i++) {
        if (scanf("%u", &t) != 1) return 1;
        xSimScheduleInterrupt((TickType_t)t, irq_entry, NULL);
    }
    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();
    pending = (unsigned)uxSemaphoreGetCount(sem);
    printf("irqs=%u handled=%u lost=%u pending=%u\n", g_raised, g_handled, g_lost, pending);
    printf("%s\n", (g_raised == g_handled + g_lost + pending && pending == g_tail - g_head && !g_errors)
                       ? "CONSISTENT" : "MISMATCH");
    return 0;
}
@@@ sample_input
30 2 5
5
3 3 3 4 20
@@@ sample_output
[t=3] event irq t=3
[t=5] event irq t=3
[t=7] event irq t=3
[t=9] event irq t=4
[t=20] event irq t=20
irqs=5 handled=5 lost=0 pending=0
CONSISTENT
@@@ sample_input
10 1 3
7
2 2 2 2 2 2 10
@@@ sample_output
[t=2] event irq t=2
[t=3] event irq t=2
[t=4] event irq t=2
[t=10] event irq t=10
irqs=7 handled=4 lost=3 pending=0
CONSISTENT
@@@ hidden_input
100 3 4
0
<<BLANK>>
@@@ hidden_output
irqs=0 handled=0 lost=0 pending=0
CONSISTENT
@@@ hidden_input
40 3 1
8
1 1 2 3 10 11 12 13
@@@ hidden_output
[t=1] event irq t=1
[t=4] event irq t=2
[t=10] event irq t=10
[t=13] event irq t=11
irqs=8 handled=4 lost=4 pending=0
CONSISTENT

@@@ hidden_input
20 5 10
12
1 1 1 1 1 1 1 1 1 1 1 1
@@@ hidden_output
[t=1] event irq t=1
[t=6] event irq t=1
[t=11] event irq t=1
[t=16] event irq t=1
irqs=12 handled=4 lost=2 pending=6
CONSISTENT

@@@ hidden_input
50 0 2
9
5 5 5 6 7 7 7 7 50
@@@ hidden_output
[t=5] event irq t=5
[t=5] event irq t=5
[t=6] event irq t=6
[t=7] event irq t=7
[t=7] event irq t=7
[t=50] event irq t=50
irqs=9 handled=6 lost=3 pending=0
CONSISTENT

@@@ hidden_input
20000 4 20
25
1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 19996
@@@ hidden_output
[t=1] event irq t=1
[t=5] event irq t=2
[t=9] event irq t=3
[t=13] event irq t=4
[t=17] event irq t=5
[t=21] event irq t=6
[t=25] event irq t=7
[t=29] event irq t=8
[t=33] event irq t=9
[t=37] event irq t=10
[t=41] event irq t=11
[t=45] event irq t=12
[t=49] event irq t=13
[t=53] event irq t=14
[t=57] event irq t=15
[t=61] event irq t=16
[t=65] event irq t=17
[t=69] event irq t=18
[t=73] event irq t=19
[t=77] event irq t=20
[t=81] event irq t=21
[t=85] event irq t=22
[t=89] event irq t=23
[t=93] event irq t=24
[t=19996] event irq t=19996
irqs=25 handled=25 lost=0 pending=0
CONSISTENT

@@@ hint
`xSemaphoreCreateCounting(max_pending, 0)` creates it. In the ISR, `xSemaphoreGiveFromISR()` returns `pdTRUE` when it incremented the count and `errQUEUE_FULL` when the count was already at the maximum: that is your "lost" case.
@@@ hint
The handler is `for (;;) { xSemaphoreTake(s, portMAX_DELAY); handle_event(); }`. Each take decrements the count by one, so a burst of k echoes produces k iterations, without any loop over a count in your code.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

void handle_event(void);   /* provided */
void event_lost(void);     /* provided */

static SemaphoreHandle_t s_echo_sem;

static void echo_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        if (xSemaphoreTake(s_echo_sem, portMAX_DELAY) == pdTRUE) {
            handle_event();               /* exactly one event per token */
        }
    }
}

void echo_isr(void)
{
    BaseType_t woken = pdFALSE;

    if (xSemaphoreGiveFromISR(s_echo_sem, &woken) != pdTRUE) {
        event_lost();                     /* count saturated: make the loss visible */
    }
    portYIELD_FROM_ISR(woken);
}

SemaphoreHandle_t app_start(UBaseType_t max_pending)
{
    s_echo_sem = xSemaphoreCreateCounting(max_pending, 0);
    configASSERT(s_echo_sem != NULL);
    xTaskCreate(echo_task, "echo", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
    return s_echo_sem;
}
@@@ explanation_md
**Approach.** A counting semaphore is a queue of length `max_pending` with zero-size items. Its "count" is the number of items. Every `xSemaphoreGiveFromISR()` adds one token and every `xSemaphoreTake()` removes one, so a burst of k events that arrives while the handler is busy is remembered as k, and the handler loops k times. A binary semaphore is the same thing with a maximum of 1: the 2nd..kth gives of a burst fail, and those events silently disappear.

Even a counting semaphore saturates. When the count is already `max_pending`, the give fails (`errQUEUE_FULL`). The ISR must then **report** the loss instead of ignoring it, which is what makes the accounting `irqs = handled + lost + pending` hold. In the second example, six echoes at t=2 meet a maximum of 3: three are recorded and three are reported lost, all before the handler gets the CPU.

**Complexity.** ISR: O(1). Handler: O(1) per event plus `C` ticks of work. RAM: one queue control block (~80 bytes) and no item storage. Choose `max_pending` >= the worst burst length minus what the handler drains during the burst.

**Common mistakes**
- A binary semaphore (or a task notification used as binary with `ulTaskNotifyTake(pdTRUE, ...)`) when every event matters.
- Ignoring the return value of the give: overflow becomes invisible.
- Creating the counting semaphore with initial count = max (`xSemaphoreCreateCounting(n, n)`): that is the *resource-counting* pattern, and the handler would process n phantom events at start-up.
- Looping in the ISR, or calling `handle_event()` there.
- Forgetting `portYIELD_FROM_ISR()`: correct counts, but every first event of a burst is handled one tick late.

**Interview follow-ups**
- How would you do the same with a direct-to-task notification (`vTaskNotifyGiveFromISR` + `ulTaskNotifyTake(pdFALSE, ...)`)? What is its maximum count?
- Event counting vs resource counting: what is the initial count in each case, and who gives/takes?
- If each echo also carries a timestamp, why is a counting semaphore no longer enough, and what do you use instead?
- How do you size `max_pending` from the interrupt rate and the handler's worst-case execution time?
