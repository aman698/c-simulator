@@@ meta
id: RDS-M-04
topic: RTOS Design Patterns
difficulty: Medium
type: FUNCTION
title: Token Bucket Rate Limiter With A Counting Semaphore And A Timer
tags: freertos, rate-limiting, token-bucket, counting-semaphore, software-timers, embedded
@@@ statement_md
A telematics unit accepts remote diagnostic requests. A misbehaving tester (or an attacker) must not flood the ECU, so incoming requests go through a **token bucket**. The bucket holds at most `capacity` tokens, and `refill` tokens are added every `period` ticks. A request that finds a token consumes it and is served. A request that finds the bucket empty is throttled.

Build the bucket from FreeRTOS primitives:

- the **bucket is a counting semaphore** (max count = `capacity`, initially full): taking a token = taking the semaphore;
- the **refill is an auto-reload software timer** with period `period`. Its callback gives up to `refill` tokens, and the bucket never exceeds `capacity`.

```c
/* provided by the judge */
void serve(uint16_t id);     /* prints "[t=<tick>] SERVE <id>" (task context) */
void throttle(uint16_t id);  /* prints "[t=<tick>] THROTTLE <id>" (callable from an ISR) */

/* you write these */
void limiter_start(UBaseType_t capacity, UBaseType_t refill, TickType_t period); /* before the scheduler */
void request_from_isr(uint16_t id);   /* called from the diagnostic RX interrupt */
```

- `limiter_start()` creates the semaphore, the timer (started so that it first fires at tick `period`), a queue of **16** request ids, and a server task named `"SRV"` with priority **2**. The server loops: receive an id, call `serve(id)`.
- `request_from_isr()`: if a token can be taken, queue the id for the server (and yield if that woke it). Otherwise call `throttle(id)`. Use only `...FromISR` APIs.

**How it is tested.** The hidden `main()` calls `limiter_start()` and creates a background task of priority 1 that keeps the CPU busy. It then schedules bursts of requests: `<tick> <k>` means `k` interrupts at that tick, with ids numbered 1, 2, 3, ... over the whole run. The scheduler runs up to tick `D`, and then `served=<n> throttled=<n>` is printed.

**Same-tick ordering.** All interrupts of a tick run before any task. The timer callback runs in the timer service task (priority 7). So at a tick where a refill is due, the requests of that tick see the bucket **before** the refill. Within a tick, `THROTTLE` lines (printed by the interrupts) come before the `SERVE` lines (printed by the server once the interrupts are done).

**Input**
```
<capacity> <refill> <period> <D>
<m>
<tick> <k>          (m bursts, ticks strictly increasing)
```

**Example**
```
Input:
3 1 10 60
4
5 4
20 2
50 5
55 1

Output:
[t=5] THROTTLE 4
[t=5] SERVE 1
[t=5] SERVE 2
[t=5] SERVE 3
[t=20] THROTTLE 6
[t=20] SERVE 5
[t=50] THROTTLE 10
[t=50] THROTTLE 11
[t=50] SERVE 7
[t=50] SERVE 8
[t=50] SERVE 9
[t=55] SERVE 12
served=8 throttled=4
```
The bucket starts with 3 tokens, and the burst at t=5 empties it. The refill at t=10 adds 1 token. At t=20 the requests come before that tick's refill, so only request 5 gets a token. Refills at 20, 30 and 40 fill the bucket back to 3 (the cap), and the refill at 50 comes after the burst at 50.
@@@ constraints_md
- 1 <= capacity <= 16, 1 <= refill <= 16, 1 <= period <= 1000, 1 <= D <= 10000, 0 <= m <= 40, 1 <= k <= 16, 1 <= tick < D.
- The bucket must be a counting semaphore and the refill a software timer (no polling task, no tick arithmetic in the ISR).
- Server: name `"SRV"`, priority 2, stack `configMINIMAL_STACK_SIZE`; request queue length 16 of `uint16_t`.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "timers.h"

void serve(uint16_t id);
void throttle(uint16_t id);

static void server_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: receive an id, serve(id) */
        vTaskDelay(1000);
    }
}

void limiter_start(UBaseType_t capacity, UBaseType_t refill, TickType_t period)
{
    /* TODO: counting semaphore (full), auto-reload refill timer, queue of 16 ids, "SRV" task */
    (void)capacity;
    (void)refill;
    (void)period;
    (void)server_task;
}

void request_from_isr(uint16_t id)
{
    /* TODO: take a token or throttle */
    throttle(id);
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "timers.h"
#include "sim.h"

static unsigned g_served, g_throttled;

void serve(uint16_t id)
{
    printf("[t=%u] SERVE %u\n", (unsigned)xTaskGetTickCount(), (unsigned)id);
    g_served++;
}

void throttle(uint16_t id)
{
    printf("[t=%u] THROTTLE %u\n", (unsigned)xTaskGetTickCountFromISR(), (unsigned)id);
    g_throttled++;
}

/*USER_CODE*/

static void rx_isr(void *arg)
{
    request_from_isr((uint16_t)(uintptr_t)arg);
}

static void background_task(void *p)
{
    (void)p;
    for (;;) vSimBusyWork(1);
}

int main(void)
{
    unsigned cap, refill, period, dur, tick, k, j;
    unsigned id = 1;
    int m, i;

    if (scanf("%u %u %u %u %d", &cap, &refill, &period, &dur, &m) != 5) return 1;
    limiter_start((UBaseType_t)cap, (UBaseType_t)refill, (TickType_t)period);
    xTaskCreate(background_task, "BG", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    for (i = 0; i < m; i++) {
        if (scanf("%u %u", &tick, &k) != 2) return 1;
        for (j = 0; j < k; j++, id++)
            xSimScheduleInterrupt((TickType_t)tick, rx_isr, (void *)(uintptr_t)id);
    }
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("served=%u throttled=%u\n", g_served, g_throttled);
    return 0;
}
@@@ sample_input
3 1 10 60
4
5 4
20 2
50 5
55 1
@@@ sample_output
[t=5] THROTTLE 4
[t=5] SERVE 1
[t=5] SERVE 2
[t=5] SERVE 3
[t=20] THROTTLE 6
[t=20] SERVE 5
[t=50] THROTTLE 10
[t=50] THROTTLE 11
[t=50] SERVE 7
[t=50] SERVE 8
[t=50] SERVE 9
[t=55] SERVE 12
served=8 throttled=4
@@@ sample_input
2 2 4 30
4
1 3
4 3
8 1
9 2
@@@ sample_output
[t=1] THROTTLE 3
[t=1] SERVE 1
[t=1] SERVE 2
[t=4] THROTTLE 4
[t=4] THROTTLE 5
[t=4] THROTTLE 6
[t=8] SERVE 7
[t=9] SERVE 8
[t=9] SERVE 9
served=5 throttled=4
@@@ hidden_input
5 1 100 1000
0
@@@ hidden_output
served=0 throttled=0
@@@ hidden_input
16 16 1 50
3
1 16
2 16
3 16
@@@ hidden_output
[t=1] SERVE 1
[t=1] SERVE 2
[t=1] SERVE 3
[t=1] SERVE 4
[t=1] SERVE 5
[t=1] SERVE 6
[t=1] SERVE 7
[t=1] SERVE 8
[t=1] SERVE 9
[t=1] SERVE 10
[t=1] SERVE 11
[t=1] SERVE 12
[t=1] SERVE 13
[t=1] SERVE 14
[t=1] SERVE 15
[t=1] SERVE 16
[t=2] SERVE 17
[t=2] SERVE 18
[t=2] SERVE 19
[t=2] SERVE 20
[t=2] SERVE 21
[t=2] SERVE 22
[t=2] SERVE 23
[t=2] SERVE 24
[t=2] SERVE 25
[t=2] SERVE 26
[t=2] SERVE 27
[t=2] SERVE 28
[t=2] SERVE 29
[t=2] SERVE 30
[t=2] SERVE 31
[t=2] SERVE 32
[t=3] SERVE 33
[t=3] SERVE 34
[t=3] SERVE 35
[t=3] SERVE 36
[t=3] SERVE 37
[t=3] SERVE 38
[t=3] SERVE 39
[t=3] SERVE 40
[t=3] SERVE 41
[t=3] SERVE 42
[t=3] SERVE 43
[t=3] SERVE 44
[t=3] SERVE 45
[t=3] SERVE 46
[t=3] SERVE 47
[t=3] SERVE 48
served=48 throttled=0

@@@ hidden_input
1 1 5 100
8
1 1
2 1
6 1
10 2
11 1
16 1
20 1
21 1
@@@ hidden_output
[t=1] SERVE 1
[t=2] THROTTLE 2
[t=6] SERVE 3
[t=10] THROTTLE 4
[t=10] THROTTLE 5
[t=11] SERVE 6
[t=16] SERVE 7
[t=20] THROTTLE 8
[t=21] SERVE 9
served=5 throttled=4

@@@ hidden_input
4 3 7 200
6
3 6
7 2
13 5
14 1
50 6
51 3
@@@ hidden_output
[t=3] THROTTLE 5
[t=3] THROTTLE 6
[t=3] SERVE 1
[t=3] SERVE 2
[t=3] SERVE 3
[t=3] SERVE 4
[t=7] THROTTLE 7
[t=7] THROTTLE 8
[t=13] THROTTLE 12
[t=13] THROTTLE 13
[t=13] SERVE 9
[t=13] SERVE 10
[t=13] SERVE 11
[t=14] THROTTLE 14
[t=50] THROTTLE 19
[t=50] THROTTLE 20
[t=50] SERVE 15
[t=50] SERVE 16
[t=50] SERVE 17
[t=50] SERVE 18
[t=51] THROTTLE 21
[t=51] THROTTLE 22
[t=51] THROTTLE 23
served=11 throttled=12

@@@ hidden_input
10 2 1000 3000
4
1 8
999 4
1000 4
2001 6
@@@ hidden_output
[t=1] SERVE 1
[t=1] SERVE 2
[t=1] SERVE 3
[t=1] SERVE 4
[t=1] SERVE 5
[t=1] SERVE 6
[t=1] SERVE 7
[t=1] SERVE 8
[t=999] THROTTLE 11
[t=999] THROTTLE 12
[t=999] SERVE 9
[t=999] SERVE 10
[t=1000] THROTTLE 13
[t=1000] THROTTLE 14
[t=1000] THROTTLE 15
[t=1000] THROTTLE 16
[t=2001] THROTTLE 21
[t=2001] THROTTLE 22
[t=2001] SERVE 17
[t=2001] SERVE 18
[t=2001] SERVE 19
[t=2001] SERVE 20
served=14 throttled=8

@@@ hidden_input
8 1 2 40
5
10 9
11 1
12 1
13 1
30 8
@@@ hidden_output
[t=10] THROTTLE 9
[t=10] SERVE 1
[t=10] SERVE 2
[t=10] SERVE 3
[t=10] SERVE 4
[t=10] SERVE 5
[t=10] SERVE 6
[t=10] SERVE 7
[t=10] SERVE 8
[t=11] SERVE 10
[t=12] THROTTLE 11
[t=13] SERVE 12
[t=30] SERVE 13
[t=30] SERVE 14
[t=30] SERVE 15
[t=30] SERVE 16
[t=30] SERVE 17
[t=30] SERVE 18
[t=30] SERVE 19
[t=30] SERVE 20
served=18 throttled=2

@@@ hint
`xSemaphoreCreateCounting(capacity, capacity)` is a full bucket. In the ISR, `xSemaphoreTakeFromISR(bucket, &woken)` returns `pdPASS` when a token was available. Then `xQueueSendFromISR(q, &id, &woken)` and `portYIELD_FROM_ISR(woken)`.
@@@ hint
Refill timer: `xTimerCreate("refill", period, pdTRUE, NULL, refill_cb)` followed by `xTimerStart(t, 0)` (allowed before the scheduler starts). In the callback, call `xSemaphoreGive(bucket)` up to `refill` times and stop as soon as it fails: giving a counting semaphore that is already at its maximum count returns `pdFAIL`, which is exactly the "bucket is full" cap.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "timers.h"

void serve(uint16_t id);
void throttle(uint16_t id);

static SemaphoreHandle_t s_bucket;
static QueueHandle_t s_req_q;
static UBaseType_t s_refill;

static void refill_cb(TimerHandle_t t)
{
    UBaseType_t i;

    (void)t;
    for (i = 0; i < s_refill; i++) {
        if (xSemaphoreGive(s_bucket) != pdPASS) break;   /* bucket full: cap reached */
    }
}

static void server_task(void *pvParameters)
{
    uint16_t id;

    (void)pvParameters;
    for (;;) {
        if (xQueueReceive(s_req_q, &id, portMAX_DELAY) == pdPASS) serve(id);
    }
}

void limiter_start(UBaseType_t capacity, UBaseType_t refill, TickType_t period)
{
    TimerHandle_t t;

    s_refill = refill;
    s_bucket = xSemaphoreCreateCounting(capacity, capacity);   /* starts full */
    s_req_q = xQueueCreate(16, sizeof(uint16_t));
    t = xTimerCreate("refill", period, pdTRUE, NULL, refill_cb);
    xTimerStart(t, 0);
    xTaskCreate(server_task, "SRV", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
}

void request_from_isr(uint16_t id)
{
    BaseType_t woken = pdFALSE;

    if (xSemaphoreTakeFromISR(s_bucket, &woken) != pdPASS) {
        throttle(id);
        return;
    }
    if (xQueueSendFromISR(s_req_q, &id, &woken) != pdPASS) {
        throttle(id);               /* server backlog full (cannot happen with these limits) */
    }
    portYIELD_FROM_ISR(woken);
}
@@@ explanation_md
**Approach.** A counting semaphore already *is* a bounded token counter, and it can be used from interrupts. `xSemaphoreTakeFromISR()` atomically checks and decrements it, and `xSemaphoreGive()` increments it but refuses to go past the maximum count. That refusal is the bucket's cap for free. The refill is periodic, so an auto-reload software timer does it without a dedicated task: its callback runs in the timer service task and simply gives `refill` tokens. Accepted requests are passed to a normal-priority server task through a queue, so the ISR stays short.

Ordering at a refill tick follows from the priorities. Interrupts preempt everything, and the timer service task (priority 7) runs right after them. So in the example, the burst at t=20 sees 1 token (left by the refill at t=10), and the refill at t=20 only helps later requests.

**Complexity.** O(1) per request (one semaphore take and one queue send from the ISR). O(refill) per timer period. RAM: one counting semaphore, one timer, a queue of 16 x 2 bytes, and the server task. The long-term rate is limited to `refill / period` requests per tick, and bursts to `capacity`.

**Common mistakes**
- Using a binary semaphore or a mutex: there is only one token, and mutexes cannot be used from ISRs at all.
- Creating the semaphore with an initial count of 0: the first burst is throttled although the bucket should start full.
- Calling `xSemaphoreGive()` `refill` times **without** a cap and keeping a separate counter that drifts from the semaphore's count.
- Using `xSemaphoreTake(bucket, 0)` (the task API) in the ISR: Runtime Error.
- Implementing the refill with `vTaskDelay(period)` in a task: it drifts if the task is delayed, and it costs a stack. A one-shot timer restarted in its callback has the same drift problem.
- Forgetting `portYIELD_FROM_ISR()`: every SERVE line comes one tick late, because the background task keeps the CPU.

**Interview follow-ups**
- How would you give each tester (CAN id) its own bucket?
- The timer service task queue (length 16) is full when you call `xTimerStart()`: what happens, and how do you size it?
- How would you do the refill lazily in the ISR from `xTaskGetTickCountFromISR()` (no timer), and what are the trade-offs?
- How does a token bucket differ from a leaky bucket, and which one smooths the output rate?
