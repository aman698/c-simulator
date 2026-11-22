@@@ meta
id: RQU-E-01
topic: Queues
difficulty: Easy
type: FUNCTION
title: Producer-Consumer Sensor Pipeline With a FreeRTOS Queue
tags: freertos, queue, xqueuesend, xqueuereceive, producer-consumer, embedded
@@@ statement_md
A body-control ECU samples a sensor in one task and processes the samples in another. The two tasks must not share a global variable: they talk **only through a FreeRTOS queue**. Write the code that creates the queue and both tasks.

```c
typedef struct {
    UBaseType_t qlen;       /* queue length (number of samples it can hold) */
    UBaseType_t burst;      /* samples read per period */
    TickType_t  period;     /* ticks between two bursts */
    UBaseType_t prod_prio;  /* priority of the producer task */
    UBaseType_t cons_prio;  /* priority of the consumer task */
} PcCfg;

int32_t sensor_read(void);          /* provided: prints "[t=<tick>] read <v>", returns 1, 2, 3, ... */
void    sample_consume(int32_t v);  /* provided: prints "[t=<tick>] got <v>" */

QueueHandle_t app_start(const PcCfg *cfg);  /* you write this (and the two task functions) */
```

`app_start()` is called **before** the scheduler starts. It must:

1. create a queue of `cfg->qlen` items of type `int32_t` and **return its handle**,
2. create a **producer** task with priority `prod_prio` that does forever:
   `vTaskDelay(period)`, then `burst` times: `v = sensor_read()` and send `v` to the back of the queue with `xQueueSend(..., portMAX_DELAY)`,
3. create a **consumer** task with priority `cons_prio` that does forever:
   receive one sample with `xQueueReceive(..., portMAX_DELAY)` and call `sample_consume(v)`.

The `cfg` structure stays valid for the whole run.

**How it is tested.** The hidden `main()` reads the configuration and a duration `D`, calls `app_start()`, and runs the scheduler up to and including tick `D`. Then it prints how many samples were read and consumed and how many are still in the queue. It also checks that the queue you returned has the right length and item size, and that the consumer receives the samples in order.

**What decides the order of lines at one tick.** A send that wakes a **higher-priority** consumer makes it run immediately (preemption), so `read` and `got` lines alternate. If the consumer has the **lower** priority, the producer reads and queues the whole burst first and the consumer drains the queue only when the producer blocks in `vTaskDelay()`.

**Input**
```
<qlen> <burst> <period> <prod_prio> <cons_prio> <D>
```

**Example**
```
Input:
4 2 10 2 3 30

Output:
[t=10] read 1
[t=10] got 1
[t=10] read 2
[t=10] got 2
[t=20] read 3
[t=20] got 3
[t=20] read 4
[t=20] got 4
[t=30] read 5
[t=30] got 5
[t=30] read 6
[t=30] got 6
read 6, consumed 6, waiting 0
```
The consumer (priority 3) is higher than the producer (priority 2). Each `xQueueSend()` makes the consumer ready, and it preempts the producer before the producer reads the next sample. With priorities swapped, every tick would show `read 1`, `read 2`, then `got 1`, `got 2`.
@@@ constraints_md
- 1 <= burst <= qlen <= 16, 1 <= period <= 1000, 1 <= D <= 10000.
- The two priorities are different and in 1..6.
- Create exactly one queue and two tasks (stack `configMINIMAL_STACK_SIZE`). Both tasks must block (`vTaskDelay`, `xQueueReceive`); no polling loops.
- Simulated time: 1 tick = 1 ms, and code between two blocking calls takes zero ticks.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    UBaseType_t qlen;
    UBaseType_t burst;
    TickType_t  period;
    UBaseType_t prod_prio;
    UBaseType_t cons_prio;
} PcCfg;

int32_t sensor_read(void);
void    sample_consume(int32_t v);

static void producer_task(void *pvParameters)
{
    /* TODO: forever: vTaskDelay(period); burst x { v = sensor_read(); send v } */
    (void)pvParameters;
    for (;;) {
        vTaskDelay(1000);
    }
}

static void consumer_task(void *pvParameters)
{
    /* TODO: forever: receive one sample (block), sample_consume(v) */
    (void)pvParameters;
    for (;;) {
        vTaskDelay(1000);
    }
}

QueueHandle_t app_start(const PcCfg *cfg)
{
    /* TODO: create the queue and the two tasks */
    (void)cfg;
    (void)producer_task;
    (void)consumer_task;
    return NULL;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

static int32_t g_next_read = 1;
static int32_t g_next_got = 1;
static unsigned g_reads, g_gots;

int32_t sensor_read(void)
{
    int32_t v = g_next_read++;
    printf("[t=%u] read %d\n", (unsigned)xTaskGetTickCount(), (int)v);
    g_reads++;
    return v;
}

void sample_consume(int32_t v)
{
    printf("[t=%u] got %d\n", (unsigned)xTaskGetTickCount(), (int)v);
    if (v != g_next_got)
        printf("ERROR: expected sample %d\n", (int)g_next_got);
    g_next_got = v + 1;
    g_gots++;
}

/*USER_CODE*/

int main(void)
{
    static PcCfg cfg;
    unsigned qlen, burst, period, pp, cp, dur;
    QueueHandle_t q;

    if (scanf("%u %u %u %u %u %u", &qlen, &burst, &period, &pp, &cp, &dur) != 6) return 1;
    cfg.qlen = (UBaseType_t)qlen;
    cfg.burst = (UBaseType_t)burst;
    cfg.period = (TickType_t)period;
    cfg.prod_prio = (UBaseType_t)pp;
    cfg.cons_prio = (UBaseType_t)cp;

    q = app_start(&cfg);
    if (q == NULL) {
        printf("ERROR: app_start() returned no queue\n");
        return 0;
    }
    if (uxQueueGetQueueLength(q) != (UBaseType_t)qlen || uxQueueGetQueueItemSize(q) != sizeof(int32_t)) {
        printf("ERROR: queue must hold %u items of sizeof(int32_t)\n", qlen);
        return 0;
    }
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("read %u, consumed %u, waiting %u\n", g_reads, g_gots, (unsigned)uxQueueMessagesWaiting(q));
    return 0;
}
@@@ sample_input
4 2 10 2 3 30
@@@ sample_output
[t=10] read 1
[t=10] got 1
[t=10] read 2
[t=10] got 2
[t=20] read 3
[t=20] got 3
[t=20] read 4
[t=20] got 4
[t=30] read 5
[t=30] got 5
[t=30] read 6
[t=30] got 6
read 6, consumed 6, waiting 0
@@@ sample_input
3 3 5 3 1 12
@@@ sample_output
[t=5] read 1
[t=5] read 2
[t=5] read 3
[t=5] got 1
[t=5] got 2
[t=5] got 3
[t=10] read 4
[t=10] read 5
[t=10] read 6
[t=10] got 4
[t=10] got 5
[t=10] got 6
read 6, consumed 6, waiting 0
@@@ hidden_input
1 1 1 4 2 5
@@@ hidden_output
[t=1] read 1
[t=1] got 1
[t=2] read 2
[t=2] got 2
[t=3] read 3
[t=3] got 3
[t=4] read 4
[t=4] got 4
[t=5] read 5
[t=5] got 5
read 5, consumed 5, waiting 0
@@@ hidden_input
5 2 100 2 1 50
@@@ hidden_output
read 0, consumed 0, waiting 0
@@@ hidden_input
8 8 1000 5 4 3000
@@@ hidden_output
[t=1000] read 1
[t=1000] read 2
[t=1000] read 3
[t=1000] read 4
[t=1000] read 5
[t=1000] read 6
[t=1000] read 7
[t=1000] read 8
[t=1000] got 1
[t=1000] got 2
[t=1000] got 3
[t=1000] got 4
[t=1000] got 5
[t=1000] got 6
[t=1000] got 7
[t=1000] got 8
[t=2000] read 9
[t=2000] read 10
[t=2000] read 11
[t=2000] read 12
[t=2000] read 13
[t=2000] read 14
[t=2000] read 15
[t=2000] read 16
[t=2000] got 9
[t=2000] got 10
[t=2000] got 11
[t=2000] got 12
[t=2000] got 13
[t=2000] got 14
[t=2000] got 15
[t=2000] got 16
[t=3000] read 17
[t=3000] read 18
[t=3000] read 19
[t=3000] read 20
[t=3000] read 21
[t=3000] read 22
[t=3000] read 23
[t=3000] read 24
[t=3000] got 17
[t=3000] got 18
[t=3000] got 19
[t=3000] got 20
[t=3000] got 21
[t=3000] got 22
[t=3000] got 23
[t=3000] got 24
read 24, consumed 24, waiting 0

@@@ hidden_input
5 5 3 1 6 9
@@@ hidden_output
[t=3] read 1
[t=3] got 1
[t=3] read 2
[t=3] got 2
[t=3] read 3
[t=3] got 3
[t=3] read 4
[t=3] got 4
[t=3] read 5
[t=3] got 5
[t=6] read 6
[t=6] got 6
[t=6] read 7
[t=6] got 7
[t=6] read 8
[t=6] got 8
[t=6] read 9
[t=6] got 9
[t=6] read 10
[t=6] got 10
[t=9] read 11
[t=9] got 11
[t=9] read 12
[t=9] got 12
[t=9] read 13
[t=9] got 13
[t=9] read 14
[t=9] got 14
[t=9] read 15
[t=9] got 15
read 15, consumed 15, waiting 0

@@@ hidden_input
16 4 7 6 1 21
@@@ hidden_output
[t=7] read 1
[t=7] read 2
[t=7] read 3
[t=7] read 4
[t=7] got 1
[t=7] got 2
[t=7] got 3
[t=7] got 4
[t=14] read 5
[t=14] read 6
[t=14] read 7
[t=14] read 8
[t=14] got 5
[t=14] got 6
[t=14] got 7
[t=14] got 8
[t=21] read 9
[t=21] read 10
[t=21] read 11
[t=21] read 12
[t=21] got 9
[t=21] got 10
[t=21] got 11
[t=21] got 12
read 12, consumed 12, waiting 0

@@@ hidden_input
2 1 999 3 5 1998
@@@ hidden_output
[t=999] read 1
[t=999] got 1
[t=1998] read 2
[t=1998] got 2
read 2, consumed 2, waiting 0
@@@ hint
`xQueueCreate(length, sizeof(int32_t))` creates the queue. Pass `cfg` to both tasks through the `pvParameters` argument of `xTaskCreate()`, and keep the queue handle in a `static` variable that both tasks can see.
@@@ hint
Producer: `for (;;) { vTaskDelay(c->period); for (i = 0; i < c->burst; i++) { int32_t v = sensor_read(); xQueueSend(q, &v, portMAX_DELAY); } }`. Consumer: `for (;;) { int32_t v; if (xQueueReceive(q, &v, portMAX_DELAY) == pdPASS) sample_consume(v); }`. The queue copies the 4 bytes, so sending the address of a local variable is fine.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    UBaseType_t qlen;
    UBaseType_t burst;
    TickType_t  period;
    UBaseType_t prod_prio;
    UBaseType_t cons_prio;
} PcCfg;

int32_t sensor_read(void);
void    sample_consume(int32_t v);

static QueueHandle_t s_queue;

static void producer_task(void *pvParameters)
{
    const PcCfg *c = (const PcCfg *)pvParameters;
    UBaseType_t i;

    for (;;) {
        vTaskDelay(c->period);
        for (i = 0; i < c->burst; i++) {
            int32_t v = sensor_read();
            /* the queue copies the value: the local can be reused at once */
            xQueueSend(s_queue, &v, portMAX_DELAY);
        }
    }
}

static void consumer_task(void *pvParameters)
{
    int32_t v;

    (void)pvParameters;
    for (;;) {
        if (xQueueReceive(s_queue, &v, portMAX_DELAY) == pdPASS) {
            sample_consume(v);
        }
    }
}

QueueHandle_t app_start(const PcCfg *cfg)
{
    s_queue = xQueueCreate(cfg->qlen, sizeof(int32_t));
    if (s_queue == NULL) {
        return NULL;
    }
    xTaskCreate(producer_task, "prod", configMINIMAL_STACK_SIZE, (void *)cfg, cfg->prod_prio, NULL);
    xTaskCreate(consumer_task, "cons", configMINIMAL_STACK_SIZE, NULL, cfg->cons_prio, NULL);
    return s_queue;
}
@@@ explanation_md
**Approach.** A FreeRTOS queue is a thread-safe FIFO that stores **copies** of fixed-size items. The producer copies each `int32_t` in with `xQueueSend()` (to the back), and the consumer copies it out with `xQueueReceive()`. The consumer blocks with `portMAX_DELAY`, so it costs no CPU while the queue is empty, and the kernel wakes it as soon as an item arrives.

The order of the lines at one tick depends only on priorities:
- **Consumer higher.** `xQueueSend()` moves the waiting consumer to the ready list. Because it has a higher priority, the kernel switches to it inside the send call. So each `read` is followed by its `got`.
- **Consumer lower.** The producer keeps the CPU until it blocks in `vTaskDelay()`. The whole burst is queued first, then the consumer drains it. This is why the queue must be at least as long as a burst: otherwise the producer would block on a full queue in the middle of the burst.

**Complexity.** Per sample: O(1) CPU (one 4-byte copy in, one out, plus at most one context switch). RAM: queue storage `qlen * sizeof(int32_t)` bytes plus the queue control block, and one TCB and stack per task. The worst-case latency from `read` to `got` is zero ticks when the consumer has the higher priority, and the rest of the burst when it has the lower one.

**Common mistakes**
- Creating the queue with `sizeof(int32_t *)` or sending a pointer. Queues copy by value, which is what makes sending a local variable safe.
- Creating the queue **inside** a task after the other task already uses the handle (NULL handle: `configASSERT` fires). Create it in `app_start()` before the scheduler starts.
- Polling with `xQueueReceive(q, &v, 0)` in a loop: the consumer never blocks, starves lower-priority tasks and burns CPU.
- Ignoring the return value of `xQueueReceive()` when a finite timeout is used: `v` is not written on timeout.
- Sharing a global variable "for speed" instead of the queue: a race between the two tasks with no synchronisation.

**Interview follow-ups**
- What happens if `burst > qlen` and the producer has the higher priority? Trace the interleaving.
- Queue vs. stream buffer vs. direct task notification: when is each one the right tool?
- How large should the queue be? Relate it to the producer burst size and the consumer worst-case latency.
- How would you send 200-byte messages without copying them twice? (Queue of pointers plus buffer ownership rules.)
