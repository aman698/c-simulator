@@@ meta
id: RQU-M-04
topic: Queues
difficulty: Medium
type: FUNCTION
title: Latest-Value Mailbox With xQueueOverwrite and xQueuePeek
tags: freertos, mailbox, xqueueoverwrite, xqueuepeek, isr, embedded, asked-in-automotive
@@@ statement_md
The wheel-speed interrupt of a brake ECU produces a new speed value from time to time. Several tasks need **the most recent value**, not a history of values. A long FIFO is the wrong tool: readers would process stale data, and the ISR would hit a full queue. Implement a **mailbox**: a queue of length 1 that the writer **overwrites** and that readers **peek** without removing the value.

```c
typedef struct {
    TickType_t abs_period;    /* ABS task period */
    TickType_t disp_period;   /* display task period */
} MailboxCfg;

void reader_log(const char *who, BaseType_t ok, uint16_t v);
    /* provided: prints "[t=<tick>] <who> <v>" or "[t=<tick>] <who> no data" when ok == pdFALSE */

QueueHandle_t app_start(const MailboxCfg *cfg);  /* you write this, return the mailbox */
void speed_isr(uint16_t v);                      /* you write this: runs IN INTERRUPT CONTEXT */
```

Requirements:

- The mailbox is a queue of **1** item of type `uint16_t`.
- `speed_isr(v)` publishes `v` with `xQueueOverwriteFromISR()` (it always succeeds, replacing the old value) and ends with `portYIELD_FROM_ISR()`.
- **ABS task**, priority **4**: every `abs_period` ticks (k-th read at `k * abs_period`, use `xTaskDelayUntil`), `xQueuePeek(mbox, &v, 0)` and `reader_log("ABS", ok, v)`.
- **Display task**, priority **2**: the same with `disp_period` and `"DISP"`.
- **Startup logger**, priority **3**: blocks in `xQueuePeek(mbox, &v, portMAX_DELAY)` until the mailbox holds a value, calls `reader_log("LOG first", pdTRUE, v)`, then deletes itself with `vTaskDelete(NULL)`.

Readers must never **remove** the value: every reader, at any time after the first update, must see the newest value.

**How it is tested.** The hidden `main()` reads the two periods, a list of `(tick, speed)` updates and a duration `D`. It schedules one interrupt per update (the interrupt calls `speed_isr()`), and runs the scheduler up to and including tick `D`. `reader_log()` prints `STALE` if a reader gets anything other than the newest value. At the end the harness prints the number of updates and what the mailbox holds.

**Timing rules**
- Interrupts at tick `t` run right after the tick count becomes `t`, before any task runs at `t`. A reader that wakes at `t` therefore already sees an update made at `t`. Several updates at the same tick: the last one wins.
- At the same tick, tasks run in priority order: ABS (4), then LOG (3), then DISP (2).
- `xQueueReceive` is disabled in this exercise.

**Input**
```
<abs_period> <disp_period>
<n>
<tick> <speed>      (n lines, sorted by tick)
<D>
```

**Example**
```
Input:
5 10
4
3 100
5 110
12 130
13 140
20

Output:
[t=3] LOG first 100
[t=5] ABS 110
[t=10] ABS 110
[t=10] DISP 110
[t=15] ABS 140
[t=20] ABS 140
[t=20] DISP 140
updates 4, mailbox holds 1 item: 140
```
At t=3 the first overwrite wakes the logger, and `portYIELD_FROM_ISR` makes it run at once. At t=5 the update comes before the ABS task runs, so ABS reads 110. The value 130 is never read by anyone: it was replaced at t=13 before the next read. That is exactly what a mailbox is for.
@@@ constraints_md
- 1 <= abs_period, disp_period <= 1000, 0 <= n <= 300, 1 <= tick <= D <= 10000, 0 <= speed <= 65535.
- Mailbox: length 1, item size `sizeof(uint16_t)`. Three tasks, priorities 4 / 3 / 2, stack `configMINIMAL_STACK_SIZE`.
- `speed_isr()` must only use `...FromISR()` APIs.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    TickType_t abs_period;
    TickType_t disp_period;
} MailboxCfg;

void reader_log(const char *who, BaseType_t ok, uint16_t v);

static void abs_task(void *pvParameters)
{
    /* TODO: every abs_period: peek (timeout 0), reader_log("ABS", ok, v) */
    (void)pvParameters;
    for (;;) {
        vTaskDelay(1000);
    }
}

static void disp_task(void *pvParameters)
{
    /* TODO: every disp_period: peek (timeout 0), reader_log("DISP", ok, v) */
    (void)pvParameters;
    for (;;) {
        vTaskDelay(1000);
    }
}

static void log_task(void *pvParameters)
{
    /* TODO: blocking peek, reader_log("LOG first", pdTRUE, v), vTaskDelete(NULL) */
    (void)pvParameters;
    vTaskDelete(NULL);
}

QueueHandle_t app_start(const MailboxCfg *cfg)
{
    /* TODO: create the mailbox (1 x uint16_t) and the three tasks */
    (void)cfg;
    (void)abs_task;
    (void)disp_task;
    (void)log_task;
    return NULL;
}

void speed_isr(uint16_t v)
{
    /* TODO: xQueueOverwriteFromISR + portYIELD_FROM_ISR */
    (void)v;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

static int g_have;          /* any update yet? */
static uint16_t g_latest;   /* newest value written by the ISR */
static unsigned g_updates;

void reader_log(const char *who, BaseType_t ok, uint16_t v)
{
    unsigned t = (unsigned)xTaskGetTickCount();
    if (ok == pdFALSE)
        printf("[t=%u] %s no data\n", t, who);
    else
        printf("[t=%u] %s %u\n", t, who, (unsigned)v);
    if ((ok != pdFALSE) != (g_have != 0) || (ok != pdFALSE && v != g_latest))
        printf("STALE: the newest value is %s%u\n", g_have ? "" : "none ", g_have ? (unsigned)g_latest : 0u);
}

#define xQueueReceive(q, p, t) xQueueReceive_is_not_allowed_here
/*USER_CODE*/
#undef xQueueReceive

typedef struct {
    uint16_t v;
} Upd;

static Upd g_upd[300];

static void speed_irq(void *arg)
{
    const Upd *u = (const Upd *)arg;
    g_latest = u->v;
    g_have = 1;
    g_updates++;
    speed_isr(u->v);
}

int main(void)
{
    static MailboxCfg cfg;
    unsigned pa, pd, n, i, tick, v, dur;
    QueueHandle_t q;
    uint16_t held;

    if (scanf("%u %u %u", &pa, &pd, &n) != 3 || n > 300) return 1;
    cfg.abs_period = (TickType_t)pa;
    cfg.disp_period = (TickType_t)pd;
    for (i = 0; i < n; i++) {
        if (scanf("%u %u", &tick, &v) != 2) return 1;
        g_upd[i].v = (uint16_t)v;
        xSimScheduleInterrupt((TickType_t)tick, speed_irq, &g_upd[i]);
    }
    if (scanf("%u", &dur) != 1) return 1;

    q = app_start(&cfg);
    if (q == NULL) {
        printf("ERROR: app_start() returned no mailbox\n");
        return 0;
    }
    if (uxQueueGetQueueLength(q) != 1 || uxQueueGetQueueItemSize(q) != sizeof(uint16_t)) {
        printf("ERROR: the mailbox must be a queue of 1 x uint16_t\n");
        return 0;
    }
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    if (uxQueueMessagesWaiting(q) == 0) {
        printf("updates %u, mailbox empty\n", g_updates);
    } else if (xQueuePeek(q, &held, 0) == pdPASS) {
        printf("updates %u, mailbox holds %u item: %u\n", g_updates, (unsigned)uxQueueMessagesWaiting(q),
               (unsigned)held);
    }
    return 0;
}
@@@ sample_input
5 10
4
3 100
5 110
12 130
13 140
20
@@@ sample_output
[t=3] LOG first 100
[t=5] ABS 110
[t=10] ABS 110
[t=10] DISP 110
[t=15] ABS 140
[t=20] ABS 140
[t=20] DISP 140
updates 4, mailbox holds 1 item: 140
@@@ sample_input
2 3
2
4 50
4 60
6
@@@ sample_output
[t=2] ABS no data
[t=3] DISP no data
[t=4] ABS 60
[t=4] LOG first 60
[t=6] ABS 60
[t=6] DISP 60
updates 2, mailbox holds 1 item: 60
@@@ hidden_input
4 6
0
12
@@@ hidden_output
[t=4] ABS no data
[t=6] DISP no data
[t=8] ABS no data
[t=12] ABS no data
[t=12] DISP no data
updates 0, mailbox empty
@@@ hidden_input
3 7
1
1 65535
7
@@@ hidden_output
[t=1] LOG first 65535
[t=3] ABS 65535
[t=6] ABS 65535
[t=7] DISP 65535
updates 1, mailbox holds 1 item: 65535
@@@ hidden_input
1 2
6
1 10
2 20
3 30
4 40
5 50
6 60
6
@@@ hidden_output
[t=1] ABS 10
[t=1] LOG first 10
[t=2] ABS 20
[t=2] DISP 20
[t=3] ABS 30
[t=4] ABS 40
[t=4] DISP 40
[t=5] ABS 50
[t=6] ABS 60
[t=6] DISP 60
updates 6, mailbox holds 1 item: 60

@@@ hidden_input
10 25
5
9 1
10 2
10 3
49 4
50 5
50
@@@ hidden_output
[t=9] LOG first 1
[t=10] ABS 3
[t=20] ABS 3
[t=25] DISP 3
[t=30] ABS 3
[t=40] ABS 3
[t=50] ABS 5
[t=50] DISP 5
updates 5, mailbox holds 1 item: 5

@@@ hidden_input
100 250
8
150 800
151 801
199 0
200 7
333 12
499 13
500 14
999 15
1000
@@@ hidden_output
[t=100] ABS no data
[t=150] LOG first 800
[t=200] ABS 7
[t=250] DISP 7
[t=300] ABS 7
[t=400] ABS 12
[t=500] ABS 14
[t=500] DISP 14
[t=600] ABS 14
[t=700] ABS 14
[t=750] DISP 14
[t=800] ABS 14
[t=900] ABS 14
[t=1000] ABS 15
[t=1000] DISP 15
updates 8, mailbox holds 1 item: 15

@@@ hidden_input
7 3
2
20 5
21 6
21
@@@ hidden_output
[t=3] DISP no data
[t=6] DISP no data
[t=7] ABS no data
[t=9] DISP no data
[t=12] DISP no data
[t=14] ABS no data
[t=15] DISP no data
[t=18] DISP no data
[t=20] LOG first 5
[t=21] ABS 6
[t=21] DISP 6
updates 2, mailbox holds 1 item: 6

@@@ hint
`xQueueOverwrite()` / `xQueueOverwriteFromISR()` are only valid on a queue of length 1. They write even when the queue is full, replacing the old item. `xQueuePeek()` copies the item out **without** removing it, so every reader sees it, and a blocking peek waits until the first item exists.
@@@ hint
ISR: `BaseType_t woken = pdFALSE; xQueueOverwriteFromISR(s_mbox, &v, &woken); portYIELD_FROM_ISR(woken);`. Periodic reader: `TickType_t last = xTaskGetTickCount(); for (;;) { xTaskDelayUntil(&last, period); uint16_t v = 0; BaseType_t ok = xQueuePeek(s_mbox, &v, 0); reader_log("ABS", ok, v); }`.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    TickType_t abs_period;
    TickType_t disp_period;
} MailboxCfg;

void reader_log(const char *who, BaseType_t ok, uint16_t v);

static QueueHandle_t s_mbox;
static const MailboxCfg *s_cfg;

static void periodic_reader(const char *who, TickType_t period)
{
    TickType_t last = xTaskGetTickCount();

    for (;;) {
        uint16_t v = 0;
        BaseType_t ok;

        xTaskDelayUntil(&last, period);
        ok = xQueuePeek(s_mbox, &v, 0);   /* non-destructive, never blocks */
        reader_log(who, ok, v);
    }
}

static void abs_task(void *pvParameters)
{
    (void)pvParameters;
    periodic_reader("ABS", s_cfg->abs_period);
}

static void disp_task(void *pvParameters)
{
    (void)pvParameters;
    periodic_reader("DISP", s_cfg->disp_period);
}

static void log_task(void *pvParameters)
{
    uint16_t v;

    (void)pvParameters;
    if (xQueuePeek(s_mbox, &v, portMAX_DELAY) == pdPASS) {   /* wait for the first value */
        reader_log("LOG first", pdTRUE, v);
    }
    vTaskDelete(NULL);
}

QueueHandle_t app_start(const MailboxCfg *cfg)
{
    s_cfg = cfg;
    s_mbox = xQueueCreate(1, sizeof(uint16_t));
    if (s_mbox == NULL) {
        return NULL;
    }
    xTaskCreate(abs_task, "abs", configMINIMAL_STACK_SIZE, NULL, 4, NULL);
    xTaskCreate(log_task, "log", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
    xTaskCreate(disp_task, "disp", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
    return s_mbox;
}

void speed_isr(uint16_t v)
{
    BaseType_t woken = pdFALSE;

    xQueueOverwriteFromISR(s_mbox, &v, &woken);   /* always succeeds on a length-1 queue */
    portYIELD_FROM_ISR(woken);
}
@@@ explanation_md
**Approach.** A mailbox is "the current value of X", which suits sensor values, modes and set-points. It is built from two queue primitives:

- **`xQueueOverwrite[FromISR]()`** writes into a length-1 queue whether or not it is full, so the writer never fails and never blocks. The old value is simply gone. It also wakes tasks that are blocked waiting to read.
- **`xQueuePeek()`** copies the item out but leaves it in the queue. Any number of readers can read the same value at any rate. With timeout 0 it reports "no data yet". With `portMAX_DELAY` it waits for the first value.

The trace shows the consequences:
- At the same tick, the interrupt runs before the tasks, so readers already see that tick's value. If several updates arrive at one tick, the last one wins. The startup logger in sample 2 therefore reports 60 although 50 was written first: it runs after both interrupts.
- Values that are overwritten before anyone reads them (130 in the example) are lost by design.

**Complexity.** Write: O(1), one 2-byte copy plus waking the blocked readers (at most one here, the logger). Read: O(1), one 2-byte copy. RAM: 2 bytes of storage plus one queue control block, independent of the update rate. That is the main advantage over a deep FIFO.

**Common mistakes**
- `xQueueSendFromISR()` on the length-1 queue: the second update fails because the queue is full, and readers keep reading the **first** value forever (`STALE`).
- `xQueueReceive()` in a reader: the first reader empties the mailbox, and the others see "no data".
- A deep FIFO "to not lose anything": readers then process old values with growing latency, which is fatal for a control loop.
- `xQueueOverwrite()` on a queue longer than 1: `configASSERT` fires.
- Forgetting `portYIELD_FROM_ISR()`: the startup logger runs one tick late.

**Interview follow-ups**
- Mailbox vs. a global variable protected by a critical section: when is each appropriate? What about a 64-bit value on a 32-bit MCU?
- How can a reader tell whether it already processed the current value? (Add a sequence number or timestamp to the item.)
- How would you implement the same with a direct-to-task notification (`eSetValueWithOverwrite`)? What do you lose?
- Many readers, one writer at 10 kHz: what is the CPU cost of the critical sections in the queue API, and how would you reduce it?
