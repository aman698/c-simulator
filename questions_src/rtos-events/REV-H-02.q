@@@ meta
id: REV-H-02
topic: Event Groups & Notifications
difficulty: Hard
type: FUNCTION
title: Sensor Overrun Detection With eSetValueWithoutOverwrite
tags: freertos, task-notifications, esetvaluewithoutoverwrite, overrun, critical-section, isr, embedded, asked-in-automotive
@@@ statement_md
A wheel-speed sensor interrupt delivers one 32-bit sample at a time. The value is passed to a processing task **inside the task notification value**: no queue, no buffer. Processing is slow, so samples can arrive faster than the task consumes them. A newer sample must **never silently overwrite** an unread one. The ISR must detect the overrun, drop the new sample and count it. The task then reports the gap before it processes the next sample, so the signal chain knows data is missing.

```c
void process_sample(uint32_t v);    /* provided: prints "[t=<tick>] process <v>", takes `work` ticks of CPU */
void report_gap(uint32_t dropped);  /* provided: prints "[t=<tick>] gap <dropped>"                      */
void log_overrun(uint32_t v);       /* provided, ISR-safe: prints "[t=<tick>] OVERRUN drop <v>"         */
void sensor_timeout(void);          /* provided: prints "[t=<tick>] sensor timeout"                     */

void app_start(UBaseType_t priority, TickType_t timeout);  /* you write: create the task          */
void sensor_isr(uint32_t sample);   /* you write: called in INTERRUPT context, once per sample   */
```

**ISR.** Deliver the sample with `xTaskNotifyFromISR(task, sample, eSetValueWithoutOverwrite, &woken)`. If the call returns `pdFAIL` (the previous sample is still unread), call `log_overrun(sample)` and increment a drop counter that is shared with the task. Always finish with `portYIELD_FROM_ISR(woken)`.

**Task** (priority `priority`). It loops forever:
1. Wait for a sample with `xTaskNotifyWait()`, for at most `timeout` ticks.
2. On timeout, call `sensor_timeout()`.
3. Otherwise **read and reset** the drop counter (it is shared with the ISR, so protect it). If it was non-zero, call `report_gap(count)`. Then call `process_sample(v)`.

Note that **0 is a valid sample**. "Value 0" cannot mean "no data", so use the return value of `xTaskNotifyWait()`.

Queues, semaphores and event groups are disabled in this exercise.

**How it is tested.** The hidden `main()` reads the scenario, calls `app_start()`, schedules one interrupt per sample and runs the scheduler up to and including tick `D`. Several interrupts at one tick all run (in input order) before any task. The harness tracks every delivered sample as accepted (no `log_overrun`) or dropped, and checks:
- that `process_sample()` receives exactly the accepted samples, in order;
- that every drop is reported by `report_gap()` before the next processed sample.

It prints `ERROR: ...` on any violation. At the end it prints `delivered=.. processed=.. dropped=.. unprocessed=..` and `CHECK OK` if no error was found.

**Input**
```
<priority> <work> <timeout> <D>
<n>
<tick> <value>      (n lines, ticks non-decreasing)
```

**Example**
```
Input:
3 4 30 60
5
2 100
3 0
4 7
5 8
20 9

Output:
[t=2] process 100
[t=4] OVERRUN drop 7
[t=5] OVERRUN drop 8
[t=6] gap 2
[t=6] process 0
[t=20] process 9
[t=54] sensor timeout
delivered=5 processed=3 dropped=2 unprocessed=0
CHECK OK
```
Sample 100 is being processed during t=2..6. When `xTaskNotifyWait()` returned, the notification went back to "not pending", so the sample at t=3 is **accepted** and waits in the notification value. The samples at t=4 and t=5 find it still unread and are dropped. At t=6 the task gets sample 0 immediately, reports the gap of 2, and processes it. After sample 9 (t=20..24), nothing arrives, and the task times out at t=24+30=54.
@@@ constraints_md
- 1 <= priority <= 6, 1 <= work <= 50, 1 <= timeout <= 1000, 1 <= D <= 10000, 0 <= n <= 200, 1 <= tick < D.
- 0 <= value <= 4294967295. No sample arrives exactly when a wait times out, and processing never runs into `D`.
- One task; it must block in `xTaskNotifyWait()`.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

void process_sample(uint32_t v);
void report_gap(uint32_t dropped);
void log_overrun(uint32_t v);
void sensor_timeout(void);

static TaskHandle_t sensor_task_handle;
static TickType_t sensor_wait;

static void sensor_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: wait for a sample (with timeout), report gaps, process */
        vTaskDelay(1000);
    }
}

void app_start(UBaseType_t priority, TickType_t timeout)
{
    /* TODO */
    (void)priority;
    (void)sensor_task;
    (void)sensor_task_handle;
    sensor_wait = timeout;
}

void sensor_isr(uint32_t sample)
{
    /* TODO: deliver without overwriting; count and log overruns */
    (void)sample;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "event_groups.h"
#include "sim.h"

static TickType_t g_work;
static uint32_t g_vals[200];
static uint32_t g_fifo[256];          /* accepted, not yet processed */
static unsigned g_fhead, g_ftail;
static unsigned g_delivered, g_processed, g_dropped, g_unreported, g_errors;
static int g_in_isr, g_dropped_now;

void log_overrun(uint32_t v)
{
    printf("[t=%u] OVERRUN drop %u\n", (unsigned)xTaskGetTickCount(), (unsigned)v);
    if (!g_in_isr) {
        printf("ERROR: log_overrun() outside the ISR\n");
        g_errors++;
        return;
    }
    g_dropped_now = 1;
    g_dropped++;
    g_unreported++;
}

void report_gap(uint32_t dropped)
{
    printf("[t=%u] gap %u\n", (unsigned)xTaskGetTickCount(), (unsigned)dropped);
    if (dropped != g_unreported) {
        printf("ERROR: %u samples were dropped since the last report\n", g_unreported);
        g_errors++;
    }
    g_unreported = 0;
}

void process_sample(uint32_t v)
{
    printf("[t=%u] process %u\n", (unsigned)xTaskGetTickCount(), (unsigned)v);
    if (g_unreported) {
        printf("ERROR: %u dropped samples not reported before this one\n", g_unreported);
        g_errors++;
        g_unreported = 0;
    }
    if (g_fhead == g_ftail) {
        printf("ERROR: no accepted sample is waiting\n");
        g_errors++;
    } else {
        if (g_fifo[g_fhead % 256u] != v) {
            printf("ERROR: expected sample %u\n", (unsigned)g_fifo[g_fhead % 256u]);
            g_errors++;
        }
        g_fhead++;
    }
    g_processed++;
    vSimBusyWork(g_work);
}

void sensor_timeout(void)
{
    printf("[t=%u] sensor timeout\n", (unsigned)xTaskGetTickCount());
}

/* the sample travels in the notification value */
#define xQueueGenericCreate(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueGenericCreateStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateCountingSemaphore(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateCountingSemaphoreStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateMutex(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateMutexStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xEventGroupCreate(...) event_groups_are_disabled_in_this_exercise
#define xEventGroupCreateStatic(...) event_groups_are_disabled_in_this_exercise

/*USER_CODE*/

#undef xQueueGenericCreate
#undef xQueueGenericCreateStatic
#undef xQueueCreateCountingSemaphore
#undef xQueueCreateCountingSemaphoreStatic
#undef xQueueCreateMutex
#undef xQueueCreateMutexStatic
#undef xEventGroupCreate
#undef xEventGroupCreateStatic

static void sample_irq(void *arg)
{
    uint32_t v = *(const uint32_t *)arg;

    g_delivered++;
    g_in_isr = 1;
    g_dropped_now = 0;
    sensor_isr(v);
    g_in_isr = 0;
    if (!g_dropped_now) {
        g_fifo[g_ftail % 256u] = v;
        g_ftail++;
    }
}

int main(void)
{
    unsigned prio, work, timeout, dur, n, i, t, v;

    if (scanf("%u %u %u %u", &prio, &work, &timeout, &dur) != 4) return 1;
    if (scanf("%u", &n) != 1 || n > 200) return 1;
    g_work = (TickType_t)work;
    for (i = 0; i < n; i++) {
        if (scanf("%u %u", &t, &v) != 2) return 1;
        g_vals[i] = (uint32_t)v;
        xSimScheduleInterrupt((TickType_t)t, sample_irq, &g_vals[i]);
    }

    app_start((UBaseType_t)prio, (TickType_t)timeout);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("delivered=%u processed=%u dropped=%u unprocessed=%u\n",
           g_delivered, g_processed, g_dropped, g_ftail - g_fhead);
    if (g_errors == 0) printf("CHECK OK\n");
    return 0;
}
@@@ sample_input
3 4 30 60
5
2 100
3 0
4 7
5 8
20 9
@@@ sample_output
[t=2] process 100
[t=4] OVERRUN drop 7
[t=5] OVERRUN drop 8
[t=6] gap 2
[t=6] process 0
[t=20] process 9
[t=54] sensor timeout
delivered=5 processed=3 dropped=2 unprocessed=0
CHECK OK
@@@ sample_input
2 1 5 18
2
1 0
1 5
@@@ sample_output
[t=1] OVERRUN drop 5
[t=1] gap 1
[t=1] process 0
[t=7] sensor timeout
[t=12] sensor timeout
[t=17] sensor timeout
delivered=2 processed=1 dropped=1 unprocessed=0
CHECK OK
@@@ hidden_input
4 3 100 250
0
@@@ hidden_output
[t=100] sensor timeout
[t=200] sensor timeout
delivered=0 processed=0 dropped=0 unprocessed=0
CHECK OK
@@@ hidden_input
6 2 50 100
6
10 11
10 12
10 13
10 14
10 15
11 16
@@@ hidden_output
[t=10] OVERRUN drop 12
[t=10] OVERRUN drop 13
[t=10] OVERRUN drop 14
[t=10] OVERRUN drop 15
[t=10] gap 4
[t=10] process 11
[t=12] process 16
[t=64] sensor timeout
delivered=6 processed=2 dropped=4 unprocessed=0
CHECK OK
@@@ hidden_input
1 5 1000 100
4
1 4294967295
6 0
11 1
16 2
@@@ hidden_output
[t=1] process 4294967295
[t=6] process 0
[t=11] process 1
[t=16] process 2
delivered=4 processed=4 dropped=0 unprocessed=0
CHECK OK
@@@ hidden_input
3 10 200 400
9
5 1
6 2
7 3
16 4
30 5
31 6
40 7
41 8
42 9
@@@ hidden_output
[t=5] process 1
[t=7] OVERRUN drop 3
[t=15] gap 1
[t=15] process 2
[t=25] process 4
[t=31] OVERRUN drop 6
[t=35] gap 1
[t=35] process 5
[t=41] OVERRUN drop 8
[t=42] OVERRUN drop 9
[t=45] gap 2
[t=45] process 7
[t=255] sensor timeout
delivered=9 processed=5 dropped=4 unprocessed=0
CHECK OK

@@@ hidden_input
5 3 20 300
10
1 100
2 200
3 300
4 400
5 500
6 600
7 700
8 800
9 900
10 1000
@@@ hidden_output
[t=1] process 100
[t=3] OVERRUN drop 300
[t=4] OVERRUN drop 400
[t=4] gap 2
[t=4] process 200
[t=6] OVERRUN drop 600
[t=7] OVERRUN drop 700
[t=7] gap 2
[t=7] process 500
[t=9] OVERRUN drop 900
[t=10] OVERRUN drop 1000
[t=10] gap 2
[t=10] process 800
[t=33] sensor timeout
[t=53] sensor timeout
[t=73] sensor timeout
[t=93] sensor timeout
[t=113] sensor timeout
[t=133] sensor timeout
[t=153] sensor timeout
[t=173] sensor timeout
[t=193] sensor timeout
[t=213] sensor timeout
[t=233] sensor timeout
[t=253] sensor timeout
[t=273] sensor timeout
[t=293] sensor timeout
delivered=10 processed=4 dropped=6 unprocessed=0
CHECK OK

@@@ hint
`xTaskNotifyFromISR(h, v, eSetValueWithoutOverwrite, &woken)` fails only while the task has a notification **pending**: it was sent but not yet received. The state goes back to "not pending" the moment `xTaskNotifyWait()` returns, so one sample can wait in the value while the previous one is being processed.
@@@ hint
Task: `if (xTaskNotifyWait(0, 0, &v, wait) == pdFALSE) { sensor_timeout(); continue; }`. Then `taskENTER_CRITICAL(); n = drops; drops = 0; taskEXIT_CRITICAL();` (the ISR uses a plain `drops++` on a `volatile uint32_t`). Then `if (n) report_gap(n); process_sample(v);`.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

void process_sample(uint32_t v);
void report_gap(uint32_t dropped);
void log_overrun(uint32_t v);
void sensor_timeout(void);

static TaskHandle_t sensor_task_handle;
static TickType_t sensor_wait;
static volatile uint32_t drops;      /* written by the ISR, read+cleared by the task */

static void sensor_task(void *pvParameters)
{
    uint32_t v, n;

    (void)pvParameters;
    for (;;) {
        /* the return value, not the sample value, says whether a sample came (0 is valid data) */
        if (xTaskNotifyWait(0u, 0u, &v, sensor_wait) == pdFALSE) {
            sensor_timeout();
            continue;
        }
        taskENTER_CRITICAL();        /* read-and-clear must not be split by the ISR */
        n = drops;
        drops = 0;
        taskEXIT_CRITICAL();
        if (n != 0)
            report_gap(n);
        process_sample(v);
    }
}

void app_start(UBaseType_t priority, TickType_t timeout)
{
    sensor_wait = timeout;
    xTaskCreate(sensor_task, "sensor", configMINIMAL_STACK_SIZE, NULL, priority, &sensor_task_handle);
}

void sensor_isr(uint32_t sample)
{
    BaseType_t woken = pdFALSE;

    if (xTaskNotifyFromISR(sensor_task_handle, sample, eSetValueWithoutOverwrite, &woken) == pdFAIL) {
        drops++;                     /* previous sample still unread: keep it, drop this one */
        log_overrun(sample);
    }
    portYIELD_FROM_ISR(woken);
}
@@@ explanation_md
**Approach.** `eSetValueWithoutOverwrite` turns the notification value into a **one-slot mailbox with overrun detection**:
- if the task has no notification pending, the value is written, marked pending, and the task is woken if it waits;
- if a notification is still pending (sent, not yet received), the call returns `pdFAIL` and the value is left unchanged. The *oldest* data wins, and the ISR knows it dropped something.

"Pending" is a **state**, not a value. It is cleared when `xTaskNotifyWait()` returns, not when processing ends. So the effective buffer depth is 1 (in the value) plus the sample being processed. In the example, the sample at t=3 is accepted although the task is busy, and only t=4 and t=5 overrun.

The drop counter is shared between the ISR and the task. The ISR's `drops++` cannot be interrupted by the task. The task's read-then-clear could be split by the ISR on real hardware (a drop counted between the read and the clear would be lost), so it runs inside `taskENTER_CRITICAL()`/`taskEXIT_CRITICAL()`. On a Cortex-M that masks interrupts up to `configMAX_SYSCALL_INTERRUPT_PRIORITY` for a few instructions. In the simulator, zero-time code is never interrupted, so the bug could not be shown by a test, but an interviewer will ask about it.

**Complexity.** O(1) per sample in the ISR and the task. RAM: 4 bytes for the counter, nothing else. The design deliberately has no queue: the price is that at most 1 sample can wait, so throughput is bounded by `work` ticks per sample, and anything faster is counted and dropped.

**Common mistakes**
- `eSetValueWithOverwrite`: never fails, newer samples silently replace older ones, and no gap is ever reported.
- Treating `v == 0` as "no data" (or using `ulTaskNotifyTake`, which blocks on value 0): sample 0 is lost or misread.
- Believing the overrun window is "while the task is processing". It is "while a sample is pending". Clearing the value with `ulBitsToClearOnExit` does not change the pending state.
- Reading and clearing the shared counter without a critical section (or in two separate critical sections).
- Calling `report_gap()` from the ISR: printing and slow work belong in the task.

**Interview follow-ups**
- How would you get a deeper buffer without a queue (a ring buffer in the ISR plus a counting notification), and when do you need a stream buffer instead?
- On a Cortex-M3+, how could `drops` be updated lock-free (LDREX/STREX, C11 atomics)?
- Why does `taskENTER_CRITICAL()` not mask *all* interrupts, and which interrupts may call FreeRTOS APIs?
- How would you timestamp each overrun so the signal processing can interpolate across the gap?
