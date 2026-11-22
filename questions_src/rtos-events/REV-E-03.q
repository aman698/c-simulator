@@@ meta
id: REV-E-03
topic: Event Groups & Notifications
difficulty: Easy
type: FUNCTION
title: ADC Sample Counter With ulTaskNotifyTake as a Counting Semaphore
tags: freertos, task-notifications, ultasknotifytake, counting-semaphore, timeout, embedded
@@@ statement_md
An ADC converts a sensor channel and raises a **conversion-complete interrupt**. The driver's ISR (provided) stores each result in a software ring buffer, then calls **your** `adc_isr()`. A processing task must handle **every** sample exactly once, so this time the task notification is used as a **counting semaphore**. If the sensor goes silent, the task must also report it.

```c
void process_sample(uint32_t pending);  /* provided: pops the oldest sample from the ring buffer,
                                           prints "[t=<tick>] sample <value> (pending <pending>)"
                                           and takes `work` ticks of CPU time                     */
void adc_timeout(void);                 /* provided: prints "[t=<tick>] no sample (timeout)"      */

void app_start(UBaseType_t priority, TickType_t timeout); /* you write: create the task */
void adc_isr(void);                     /* you write: called in INTERRUPT context, once per sample */
```

The processing task loops forever:
1. Wait at most `timeout` ticks for a notification with `ulTaskNotifyTake(pdFALSE, timeout)`. `pdFALSE` decrements the count by one instead of clearing it.
2. If it returns 0 (timeout), call `adc_timeout()`.
3. Otherwise call `process_sample(n)`, where `n` is the value `ulTaskNotifyTake()` returned. That is the number of unprocessed samples **before** this take.

`adc_isr()` gives the notification with `vTaskNotifyGiveFromISR()` and calls `portYIELD_FROM_ISR()`, so an idle task wakes up **at the interrupt's tick**. Queues, semaphores and event groups are disabled in this exercise.

**How it is tested.** The hidden `main()` reads the scenario, calls `app_start()`, schedules one interrupt per sample and runs the scheduler up to and including tick `D`. Simulated time only moves while every task is blocked or inside `process_sample()`. Several interrupts at the same tick run one after another, before any task. The harness then prints `interrupts=.. processed=.. timeouts=.. unprocessed=..` (unprocessed = samples still in the ring buffer). `process_sample()` prints `ERROR: ...` if it is called with an empty ring buffer.

**Input**
```
<priority> <work> <timeout> <D>
<n>
<tick> <value>      (n lines, ticks non-decreasing)
```

**Example**
```
Input:
2 3 20 40
4
2 812
3 640
3 655
10 701

Output:
[t=2] sample 812 (pending 1)
[t=5] sample 640 (pending 2)
[t=8] sample 655 (pending 1)
[t=11] sample 701 (pending 1)
[t=34] no sample (timeout)
interrupts=4 processed=4 timeouts=1 unprocessed=0
```
The sample at t=2 is processed from t=2 to t=5. Meanwhile, the two interrupts at t=3 raise the count to 2. At t=5 the take returns 2 (and leaves 1), and at t=8 it returns 1. The sample of t=10 waits until t=11. The last processing ends at t=14, and the next wait times out 20 ticks later, at t=34. The wait that starts at t=34 would end at t=54, after D.
@@@ constraints_md
- 1 <= priority <= 6, 1 <= work <= 20, 1 <= timeout <= 1000, 1 <= D <= 10000, 0 <= n <= 100.
- 1 <= tick < D, 0 <= value <= 4294967295. No interrupt arrives exactly at the tick a wait times out.
- One task, no polling: the task blocks in `ulTaskNotifyTake()`.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

void process_sample(uint32_t pending);
void adc_timeout(void);

static TaskHandle_t adc_task_handle;
static TickType_t adc_wait_ticks;

static void adc_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: take one sample count (counting semantics) or report a timeout */
        vTaskDelay(1000);
    }
}

void app_start(UBaseType_t priority, TickType_t timeout)
{
    /* TODO */
    (void)priority;
    (void)timeout;
    (void)adc_task;
    (void)adc_task_handle;
    (void)adc_wait_ticks;
}

void adc_isr(void)
{
    /* TODO */
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

#define RING 128u
static uint32_t g_ring[RING];
static unsigned g_head, g_tail;     /* tail - head = samples stored */
static uint32_t g_vals[100];
static TickType_t g_work;
static unsigned g_irqs, g_processed, g_timeouts;

void process_sample(uint32_t pending)
{
    if (g_tail == g_head) {
        printf("[t=%u] ERROR: process_sample() with an empty ring buffer\n", (unsigned)xTaskGetTickCount());
        return;
    }
    printf("[t=%u] sample %u (pending %u)\n", (unsigned)xTaskGetTickCount(),
           (unsigned)g_ring[g_head % RING], (unsigned)pending);
    g_head++;
    g_processed++;
    vSimBusyWork(g_work);
}

void adc_timeout(void)
{
    printf("[t=%u] no sample (timeout)\n", (unsigned)xTaskGetTickCount());
    g_timeouts++;
}

/* this exercise is about task notifications */
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

static void conversion_done_irq(void *arg)
{
    uint32_t v = *(const uint32_t *)arg;

    g_irqs++;
    g_ring[g_tail % RING] = v;   /* n <= 100 < RING: never overflows */
    g_tail++;
    adc_isr();
}

int main(void)
{
    unsigned prio, work, timeout, dur, n, i, t, v;

    if (scanf("%u %u %u %u", &prio, &work, &timeout, &dur) != 4) return 1;
    if (scanf("%u", &n) != 1 || n > 100) return 1;
    g_work = (TickType_t)work;
    for (i = 0; i < n; i++) {
        if (scanf("%u %u", &t, &v) != 2) return 1;
        g_vals[i] = (uint32_t)v;
        xSimScheduleInterrupt((TickType_t)t, conversion_done_irq, &g_vals[i]);
    }

    app_start((UBaseType_t)prio, (TickType_t)timeout);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("interrupts=%u processed=%u timeouts=%u unprocessed=%u\n",
           g_irqs, g_processed, g_timeouts, g_tail - g_head);
    return 0;
}
@@@ sample_input
2 3 20 40
4
2 812
3 640
3 655
10 701
@@@ sample_output
[t=2] sample 812 (pending 1)
[t=5] sample 640 (pending 2)
[t=8] sample 655 (pending 1)
[t=11] sample 701 (pending 1)
[t=34] no sample (timeout)
interrupts=4 processed=4 timeouts=1 unprocessed=0
@@@ sample_input
3 2 10 35
2
5 100
5 200
@@@ sample_output
[t=5] sample 100 (pending 2)
[t=7] sample 200 (pending 1)
[t=19] no sample (timeout)
[t=29] no sample (timeout)
interrupts=2 processed=2 timeouts=2 unprocessed=0
@@@ hidden_input
1 1 1000 50
1
1 5
@@@ hidden_output
[t=1] sample 5 (pending 1)
interrupts=1 processed=1 timeouts=0 unprocessed=0
@@@ hidden_input
2 3 7 30
0
@@@ hidden_output
[t=7] no sample (timeout)
[t=14] no sample (timeout)
[t=21] no sample (timeout)
[t=28] no sample (timeout)
interrupts=0 processed=0 timeouts=4 unprocessed=0
@@@ hidden_input
5 2 100 200
10
4 1
4 2
4 3
4 4
4 5
4 6
4 7
4 8
4 9
4 10
@@@ hidden_output
[t=4] sample 1 (pending 10)
[t=6] sample 2 (pending 9)
[t=8] sample 3 (pending 8)
[t=10] sample 4 (pending 7)
[t=12] sample 5 (pending 6)
[t=14] sample 6 (pending 5)
[t=16] sample 7 (pending 4)
[t=18] sample 8 (pending 3)
[t=20] sample 9 (pending 2)
[t=22] sample 10 (pending 1)
[t=124] no sample (timeout)
interrupts=10 processed=10 timeouts=1 unprocessed=0

@@@ hidden_input
4 5 15 100
6
10 11
12 12
40 40
41 41
42 42
90 90
@@@ hidden_output
[t=10] sample 11 (pending 1)
[t=15] sample 12 (pending 1)
[t=35] no sample (timeout)
[t=40] sample 40 (pending 1)
[t=45] sample 41 (pending 2)
[t=50] sample 42 (pending 1)
[t=70] no sample (timeout)
[t=85] no sample (timeout)
[t=90] sample 90 (pending 1)
interrupts=6 processed=6 timeouts=3 unprocessed=0
@@@ hidden_input
6 1 50 60
3
1 0
2 4294967295
2 7
@@@ hidden_output
[t=1] sample 0 (pending 1)
[t=2] sample 4294967295 (pending 2)
[t=3] sample 7 (pending 1)
[t=54] no sample (timeout)
interrupts=3 processed=3 timeouts=1 unprocessed=0
@@@ hidden_input
3 20 30 65
4
50 1
51 2
52 3
53 4
@@@ hidden_output
[t=30] no sample (timeout)
[t=50] sample 1 (pending 1)
interrupts=4 processed=1 timeouts=1 unprocessed=3
@@@ hint
`vTaskNotifyGiveFromISR(handle, &woken)` increments the task's notification value by one per call, so it behaves like `xSemaphoreGiveFromISR()` on a counting semaphore. Follow it with `portYIELD_FROM_ISR(woken)`.
@@@ hint
`uint32_t n = ulTaskNotifyTake(pdFALSE, wait_ticks);` returns the count **before** the decrement, or 0 on timeout. With `pdFALSE`, it returns again immediately as long as the count is not 0, once per sample.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

void process_sample(uint32_t pending);
void adc_timeout(void);

static TaskHandle_t adc_task_handle;
static TickType_t adc_wait_ticks;

static void adc_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* pdFALSE: decrement by one -> one iteration per sample (counting semaphore) */
        uint32_t n = ulTaskNotifyTake(pdFALSE, adc_wait_ticks);

        if (n == 0)
            adc_timeout();
        else
            process_sample(n);
    }
}

void app_start(UBaseType_t priority, TickType_t timeout)
{
    adc_wait_ticks = timeout;
    xTaskCreate(adc_task, "adc", configMINIMAL_STACK_SIZE, NULL, priority, &adc_task_handle);
}

void adc_isr(void)
{
    BaseType_t woken = pdFALSE;

    vTaskNotifyGiveFromISR(adc_task_handle, &woken);
    portYIELD_FROM_ISR(woken);
}
@@@ explanation_md
**Approach.** The task's notification value is used as the count of a counting semaphore. Each interrupt increments it (`vTaskNotifyGiveFromISR`). Each `ulTaskNotifyTake(pdFALSE, timeout)` blocks while it is 0, and otherwise decrements it by one and returns the old value. So the task runs its loop body exactly once per sample, and the returned value tells it how far behind it is (`pending 2` in the example). That is a cheap backlog metric.

The timeout turns the same call into a sensor watchdog: 0 means "no sample for `timeout` ticks". The timeout restarts at every call, so it measures the silence **after the last processing**, as in the example (t=14 + 20 = t=34).

**Complexity.** O(1) per interrupt and per sample. RAM: nothing beyond the TCB. Latency: a sample waits for every earlier sample, so the worst case is `pending x work` ticks. The ring buffer must hold at least the worst-case backlog.

**Common mistakes**
- `ulTaskNotifyTake(pdTRUE, ...)`: binary semantics. Several samples collapse into one call and stay unprocessed in the ring buffer (`unprocessed` > 0).
- Treating the return value as a boolean and processing `n` samples in a loop *and* calling take again: double counting.
- Using `xTaskNotifyFromISR(..., eSetValueWithOverwrite)` to "give": the count is lost.
- Using `portMAX_DELAY` instead of the timeout: a silent sensor is never detected.
- Forgetting `portYIELD_FROM_ISR(woken)`: every sample is processed one tick late.

**Interview follow-ups**
- Notification as a counting semaphore versus `xSemaphoreCreateCounting()`: which limits apply (one receiver, no maximum count, no priority inheritance)?
- How would you bound the backlog and detect a ring-buffer overflow in the ISR?
- What happens if a sample arrives at exactly the tick the wait times out?
- How would you move the ADC result itself through the notification value instead of a ring buffer, and what would you lose?
