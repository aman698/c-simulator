@@@ meta
id: RQU-M-01
topic: Queues
difficulty: Medium
type: FUNCTION
title: Three Producers, One Consumer: Arrival Order Decided by Priorities
tags: freertos, queue, multiple-producers, priority, preemption, embedded
@@@ statement_md
Three periodic tasks of a gateway ECU (for example wheel speed, yaw rate and steering angle) report into **one shared queue**. A single consumer task forwards the messages. The queue is short, and the producers must never block: a producer that finds the queue full **drops** its message. Which messages get dropped, and in which order the lines appear, depends entirely on the **priorities**. Write the code.

```c
typedef struct {
    uint8_t  id;    /* producer 1, 2 or 3 */
    uint32_t seq;   /* 1, 2, 3, ... per producer (counts every attempt, also dropped ones) */
} Msg;

typedef struct {
    TickType_t  period;
    UBaseType_t prio;
} ProdCfg;

void on_send_result(const Msg *m, BaseType_t result); /* provided: "[t=<tick>] P<id> #<seq> sent" or "... DROP" */
void on_receive(const Msg *m);                        /* provided: "[t=<tick>] C got P<id> #<seq>" */

QueueHandle_t app_start(UBaseType_t qlen, UBaseType_t cons_prio, const ProdCfg prod[3]);
```

`app_start()` must create:

- one queue of `qlen` items of type `Msg`, and return its handle;
- three producer tasks. Producer `i` (`id = i + 1`) has priority `prod[i].prio` and does forever:
  `vTaskDelay(prod[i].period)`, increment its own `seq`, then `r = xQueueSend(q, &m, 0)` (**timeout 0**) and `on_send_result(&m, r)`;
- one consumer task with priority `cons_prio`. Forever: `xQueueReceive(q, &m, portMAX_DELAY)` and `on_receive(&m)`.

The `prod` array stays valid for the whole run.

**How it is tested.** The hidden `main()` reads the configuration and a duration `D`, calls `app_start()`, and runs the scheduler up to and including tick `D`. Then it prints, per producer, how many messages were sent and dropped. It also prints how many messages were consumed, how many are still waiting, and the **peak** queue fill level it observed. It checks that every producer's messages arrive in order and that `sent == consumed + waiting`.

**Same-tick rules (this is the point of the exercise).**
- When several producers wake at the same tick, they run in priority order, highest first.
- A consumer with a **higher** priority than the sender runs **inside** `xQueueSend()`: it is woken, preempts the sender, receives and prints before `xQueueSend()` returns. So its `C got` line comes **before** the producer's `sent` line, and the queue never holds more than one message.
- A consumer with a **lower** priority runs only when every higher-priority producer has blocked again, so messages pile up and may be dropped.

**Input**
```
<qlen> <cons_prio>
<period1> <prio1>
<period2> <prio2>
<period3> <prio3>
<D>
```

**Example**
```
Input:
2 1
10 4
20 3
20 2
40

Output:
[t=10] P1 #1 sent
[t=10] C got P1 #1
[t=20] P1 #2 sent
[t=20] P2 #1 sent
[t=20] P3 #1 DROP
[t=20] C got P1 #2
[t=20] C got P2 #1
[t=30] P1 #3 sent
[t=30] C got P1 #3
[t=40] P1 #4 sent
[t=40] P2 #2 sent
[t=40] P3 #2 DROP
[t=40] C got P1 #4
[t=40] C got P2 #2
P1: sent 4, dropped 0
P2: sent 2, dropped 0
P3: sent 0, dropped 2
consumed 6, waiting 0, peak 2
```
At t=20 all three producers wake. P1 (4) and P2 (3) fill the 2-slot queue, so P3 (2) finds it full and drops. The consumer (1) drains the queue only afterwards. With the consumer at priority 5 instead, every message would be received at once and nothing would be dropped.
@@@ constraints_md
- 1 <= qlen <= 8, 1 <= period <= 1000, 1 <= D <= 10000.
- All four priorities are different and in 1..6.
- Producers send with timeout 0 and never block on the queue. Stack size `configMINIMAL_STACK_SIZE`.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    uint8_t  id;
    uint32_t seq;
} Msg;

typedef struct {
    TickType_t  period;
    UBaseType_t prio;
} ProdCfg;

void on_send_result(const Msg *m, BaseType_t result);
void on_receive(const Msg *m);

static void producer_task(void *pvParameters)
{
    /* TODO: forever: vTaskDelay(period); seq++; xQueueSend(q, &m, 0); on_send_result(&m, r); */
    (void)pvParameters;
    for (;;) {
        vTaskDelay(1000);
    }
}

static void consumer_task(void *pvParameters)
{
    /* TODO: forever: receive (block), on_receive(&m) */
    (void)pvParameters;
    for (;;) {
        vTaskDelay(1000);
    }
}

QueueHandle_t app_start(UBaseType_t qlen, UBaseType_t cons_prio, const ProdCfg prod[3])
{
    /* TODO: create the queue, three producers and the consumer */
    (void)qlen;
    (void)cons_prio;
    (void)prod;
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

static QueueHandle_t g_q;
static unsigned g_sent[4], g_drop[4], g_last_rx[4], g_consumed, g_peak;

static void note_fill(unsigned n)
{
    if (n > g_peak) g_peak = n;
}

/*USER_CODE*/

void on_send_result(const Msg *m, BaseType_t result)
{
    unsigned id = m->id;
    if (id < 1 || id > 3) {
        printf("ERROR: bad producer id %u\n", id);
        return;
    }
    if (result == pdPASS) {
        printf("[t=%u] P%u #%u sent\n", (unsigned)xTaskGetTickCount(), id, (unsigned)m->seq);
        g_sent[id]++;
        note_fill((unsigned)uxQueueMessagesWaiting(g_q));
    } else {
        printf("[t=%u] P%u #%u DROP\n", (unsigned)xTaskGetTickCount(), id, (unsigned)m->seq);
        g_drop[id]++;
    }
    if (m->seq != g_sent[id] + g_drop[id])
        printf("ERROR: P%u seq must count every attempt\n", id);
}

void on_receive(const Msg *m)
{
    unsigned id = m->id;
    /* the message just left the queue: before the receive it held one more */
    note_fill((unsigned)uxQueueMessagesWaiting(g_q) + 1u);
    printf("[t=%u] C got P%u #%u\n", (unsigned)xTaskGetTickCount(), id, (unsigned)m->seq);
    if (id < 1 || id > 3) {
        printf("ERROR: bad producer id %u\n", id);
        return;
    }
    if (m->seq <= g_last_rx[id])
        printf("ERROR: P%u messages out of order\n", id);
    g_last_rx[id] = m->seq;
    g_consumed++;
}

int main(void)
{
    static ProdCfg prod[3];
    unsigned qlen, cprio, per, pr, dur, i, waiting, total;

    if (scanf("%u %u", &qlen, &cprio) != 2) return 1;
    for (i = 0; i < 3; i++) {
        if (scanf("%u %u", &per, &pr) != 2) return 1;
        prod[i].period = (TickType_t)per;
        prod[i].prio = (UBaseType_t)pr;
    }
    if (scanf("%u", &dur) != 1) return 1;

    g_q = app_start((UBaseType_t)qlen, (UBaseType_t)cprio, prod);
    if (g_q == NULL) {
        printf("ERROR: app_start() returned no queue\n");
        return 0;
    }
    if (uxQueueGetQueueLength(g_q) != (UBaseType_t)qlen || uxQueueGetQueueItemSize(g_q) != sizeof(Msg)) {
        printf("ERROR: queue must hold %u items of sizeof(Msg)\n", qlen);
        return 0;
    }
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    total = 0;
    for (i = 1; i <= 3; i++) {
        printf("P%u: sent %u, dropped %u\n", i, g_sent[i], g_drop[i]);
        total += g_sent[i];
    }
    waiting = (unsigned)uxQueueMessagesWaiting(g_q);
    printf("consumed %u, waiting %u, peak %u\n", g_consumed, waiting, g_peak);
    if (total != g_consumed + waiting)
        printf("ERROR: sent != consumed + waiting\n");
    return 0;
}
@@@ sample_input
2 1
10 4
20 3
20 2
40
@@@ sample_output
[t=10] P1 #1 sent
[t=10] C got P1 #1
[t=20] P1 #2 sent
[t=20] P2 #1 sent
[t=20] P3 #1 DROP
[t=20] C got P1 #2
[t=20] C got P2 #1
[t=30] P1 #3 sent
[t=30] C got P1 #3
[t=40] P1 #4 sent
[t=40] P2 #2 sent
[t=40] P3 #2 DROP
[t=40] C got P1 #4
[t=40] C got P2 #2
P1: sent 4, dropped 0
P2: sent 2, dropped 0
P3: sent 0, dropped 2
consumed 6, waiting 0, peak 2
@@@ sample_input
1 5
10 4
20 3
20 2
20
@@@ sample_output
[t=10] C got P1 #1
[t=10] P1 #1 sent
[t=20] C got P1 #2
[t=20] P1 #2 sent
[t=20] C got P2 #1
[t=20] P2 #1 sent
[t=20] C got P3 #1
[t=20] P3 #1 sent
P1: sent 2, dropped 0
P2: sent 1, dropped 0
P3: sent 1, dropped 0
consumed 4, waiting 0, peak 1
@@@ hidden_input
1 3
6 2
6 6
6 4
12
@@@ hidden_output
[t=6] P2 #1 sent
[t=6] P3 #1 DROP
[t=6] C got P2 #1
[t=6] C got P1 #1
[t=6] P1 #1 sent
[t=12] P2 #2 sent
[t=12] P3 #2 DROP
[t=12] C got P2 #2
[t=12] C got P1 #2
[t=12] P1 #2 sent
P1: sent 2, dropped 0
P2: sent 2, dropped 0
P3: sent 0, dropped 2
consumed 4, waiting 0, peak 1
@@@ hidden_input
3 2
500 5
700 4
900 3
400
@@@ hidden_output
P1: sent 0, dropped 0
P2: sent 0, dropped 0
P3: sent 0, dropped 0
consumed 0, waiting 0, peak 0
@@@ hidden_input
1 1
1 6
2 5
3 4
6
@@@ hidden_output
[t=1] P1 #1 sent
[t=1] C got P1 #1
[t=2] P1 #2 sent
[t=2] P2 #1 DROP
[t=2] C got P1 #2
[t=3] P1 #3 sent
[t=3] P3 #1 DROP
[t=3] C got P1 #3
[t=4] P1 #4 sent
[t=4] P2 #2 DROP
[t=4] C got P1 #4
[t=5] P1 #5 sent
[t=5] C got P1 #5
[t=6] P1 #6 sent
[t=6] P2 #3 DROP
[t=6] P3 #2 DROP
[t=6] C got P1 #6
P1: sent 6, dropped 0
P2: sent 0, dropped 3
P3: sent 0, dropped 2
consumed 6, waiting 0, peak 1

@@@ hidden_input
3 6
7 1
5 2
3 3
30
@@@ hidden_output
[t=3] C got P3 #1
[t=3] P3 #1 sent
[t=5] C got P2 #1
[t=5] P2 #1 sent
[t=6] C got P3 #2
[t=6] P3 #2 sent
[t=7] C got P1 #1
[t=7] P1 #1 sent
[t=9] C got P3 #3
[t=9] P3 #3 sent
[t=10] C got P2 #2
[t=10] P2 #2 sent
[t=12] C got P3 #4
[t=12] P3 #4 sent
[t=14] C got P1 #2
[t=14] P1 #2 sent
[t=15] C got P3 #5
[t=15] P3 #5 sent
[t=15] C got P2 #3
[t=15] P2 #3 sent
[t=18] C got P3 #6
[t=18] P3 #6 sent
[t=20] C got P2 #4
[t=20] P2 #4 sent
[t=21] C got P3 #7
[t=21] P3 #7 sent
[t=21] C got P1 #3
[t=21] P1 #3 sent
[t=24] C got P3 #8
[t=24] P3 #8 sent
[t=25] C got P2 #5
[t=25] P2 #5 sent
[t=27] C got P3 #9
[t=27] P3 #9 sent
[t=28] C got P1 #4
[t=28] P1 #4 sent
[t=30] C got P3 #10
[t=30] P3 #10 sent
[t=30] C got P2 #6
[t=30] P2 #6 sent
P1: sent 4, dropped 0
P2: sent 6, dropped 0
P3: sent 10, dropped 0
consumed 20, waiting 0, peak 1

@@@ hidden_input
2 4
4 6
4 5
4 3
8
@@@ hidden_output
[t=4] P1 #1 sent
[t=4] P2 #1 sent
[t=4] C got P1 #1
[t=4] C got P2 #1
[t=4] C got P3 #1
[t=4] P3 #1 sent
[t=8] P1 #2 sent
[t=8] P2 #2 sent
[t=8] C got P1 #2
[t=8] C got P2 #2
[t=8] C got P3 #2
[t=8] P3 #2 sent
P1: sent 2, dropped 0
P2: sent 2, dropped 0
P3: sent 2, dropped 0
consumed 6, waiting 0, peak 2

@@@ hidden_input
8 1
100 2
150 3
300 6
3000
@@@ hidden_output
[t=100] P1 #1 sent
[t=100] C got P1 #1
[t=150] P2 #1 sent
[t=150] C got P2 #1
[t=200] P1 #2 sent
[t=200] C got P1 #2
[t=300] P3 #1 sent
[t=300] P2 #2 sent
[t=300] P1 #3 sent
[t=300] C got P3 #1
[t=300] C got P2 #2
[t=300] C got P1 #3
[t=400] P1 #4 sent
[t=400] C got P1 #4
[t=450] P2 #3 sent
[t=450] C got P2 #3
[t=500] P1 #5 sent
[t=500] C got P1 #5
[t=600] P3 #2 sent
[t=600] P2 #4 sent
[t=600] P1 #6 sent
[t=600] C got P3 #2
[t=600] C got P2 #4
[t=600] C got P1 #6
[t=700] P1 #7 sent
[t=700] C got P1 #7
[t=750] P2 #5 sent
[t=750] C got P2 #5
[t=800] P1 #8 sent
[t=800] C got P1 #8
[t=900] P3 #3 sent
[t=900] P2 #6 sent
[t=900] P1 #9 sent
[t=900] C got P3 #3
[t=900] C got P2 #6
[t=900] C got P1 #9
[t=1000] P1 #10 sent
[t=1000] C got P1 #10
[t=1050] P2 #7 sent
[t=1050] C got P2 #7
[t=1100] P1 #11 sent
[t=1100] C got P1 #11
[t=1200] P3 #4 sent
[t=1200] P2 #8 sent
[t=1200] P1 #12 sent
[t=1200] C got P3 #4
[t=1200] C got P2 #8
[t=1200] C got P1 #12
[t=1300] P1 #13 sent
[t=1300] C got P1 #13
[t=1350] P2 #9 sent
[t=1350] C got P2 #9
[t=1400] P1 #14 sent
[t=1400] C got P1 #14
[t=1500] P3 #5 sent
[t=1500] P2 #10 sent
[t=1500] P1 #15 sent
[t=1500] C got P3 #5
[t=1500] C got P2 #10
[t=1500] C got P1 #15
[t=1600] P1 #16 sent
[t=1600] C got P1 #16
[t=1650] P2 #11 sent
[t=1650] C got P2 #11
[t=1700] P1 #17 sent
[t=1700] C got P1 #17
[t=1800] P3 #6 sent
[t=1800] P2 #12 sent
[t=1800] P1 #18 sent
[t=1800] C got P3 #6
[t=1800] C got P2 #12
[t=1800] C got P1 #18
[t=1900] P1 #19 sent
[t=1900] C got P1 #19
[t=1950] P2 #13 sent
[t=1950] C got P2 #13
[t=2000] P1 #20 sent
[t=2000] C got P1 #20
[t=2100] P3 #7 sent
[t=2100] P2 #14 sent
[t=2100] P1 #21 sent
[t=2100] C got P3 #7
[t=2100] C got P2 #14
[t=2100] C got P1 #21
[t=2200] P1 #22 sent
[t=2200] C got P1 #22
[t=2250] P2 #15 sent
[t=2250] C got P2 #15
[t=2300] P1 #23 sent
[t=2300] C got P1 #23
[t=2400] P3 #8 sent
[t=2400] P2 #16 sent
[t=2400] P1 #24 sent
[t=2400] C got P3 #8
[t=2400] C got P2 #16
[t=2400] C got P1 #24
[t=2500] P1 #25 sent
[t=2500] C got P1 #25
[t=2550] P2 #17 sent
[t=2550] C got P2 #17
[t=2600] P1 #26 sent
[t=2600] C got P1 #26
[t=2700] P3 #9 sent
[t=2700] P2 #18 sent
[t=2700] P1 #27 sent
[t=2700] C got P3 #9
[t=2700] C got P2 #18
[t=2700] C got P1 #27
[t=2800] P1 #28 sent
[t=2800] C got P1 #28
[t=2850] P2 #19 sent
[t=2850] C got P2 #19
[t=2900] P1 #29 sent
[t=2900] C got P1 #29
[t=3000] P3 #10 sent
[t=3000] P2 #20 sent
[t=3000] P1 #30 sent
[t=3000] C got P3 #10
[t=3000] C got P2 #20
[t=3000] C got P1 #30
P1: sent 30, dropped 0
P2: sent 20, dropped 0
P3: sent 10, dropped 0
consumed 60, waiting 0, peak 3

@@@ hint
Give each producer its own `ProdCfg` through `pvParameters` and derive its id from the pointer: `id = (uint8_t)(c - s_prod + 1)`, where `s_prod` is the array passed to `app_start()`. Keep `seq` as a local variable of the task function: every task has its own stack, so each producer has its own counter.
@@@ hint
Producer body: `vTaskDelay(c->period); m.seq = ++seq; r = xQueueSend(q, &m, 0); on_send_result(&m, r);`. Do **not** print or count before `xQueueSend()` returns. A higher-priority consumer already received the message inside that call, which is exactly what the expected output shows.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    uint8_t  id;
    uint32_t seq;
} Msg;

typedef struct {
    TickType_t  period;
    UBaseType_t prio;
} ProdCfg;

void on_send_result(const Msg *m, BaseType_t result);
void on_receive(const Msg *m);

static QueueHandle_t s_q;
static const ProdCfg *s_prod;

static void producer_task(void *pvParameters)
{
    const ProdCfg *c = (const ProdCfg *)pvParameters;
    Msg m;
    BaseType_t r;

    m.id = (uint8_t)(c - s_prod + 1);
    m.seq = 0;
    for (;;) {
        vTaskDelay(c->period);
        m.seq++;
        r = xQueueSend(s_q, &m, 0);   /* never block: drop if full */
        on_send_result(&m, r);
    }
}

static void consumer_task(void *pvParameters)
{
    Msg m;

    (void)pvParameters;
    for (;;) {
        if (xQueueReceive(s_q, &m, portMAX_DELAY) == pdPASS) {
            on_receive(&m);
        }
    }
}

QueueHandle_t app_start(UBaseType_t qlen, UBaseType_t cons_prio, const ProdCfg prod[3])
{
    int i;

    s_prod = prod;
    s_q = xQueueCreate(qlen, sizeof(Msg));
    if (s_q == NULL) {
        return NULL;
    }
    for (i = 0; i < 3; i++) {
        xTaskCreate(producer_task, "prod", configMINIMAL_STACK_SIZE, (void *)&prod[i], prod[i].prio, NULL);
    }
    xTaskCreate(consumer_task, "cons", configMINIMAL_STACK_SIZE, NULL, cons_prio, NULL);
    return s_q;
}
@@@ explanation_md
**Approach.** A FreeRTOS queue is safe for many writers and readers: every send and receive runs in a critical section. The interesting part is not the code but **who runs when**:

1. At a tick where several producers wake, the scheduler runs them highest priority first. Each one queues its message and blocks again in `vTaskDelay()`.
2. `xQueueSend()` that finds a task blocked in `xQueueReceive()` removes it from the queue's "waiting to receive" list. If that task has a **higher** priority than the sender, the kernel yields at once. The consumer receives and prints **inside** the sender's call, and the queue never holds more than one item.
3. If the consumer has a **lower** priority than some producers, those producers all run first. Their messages pile up, and with `timeout 0` the producers that come last at a busy tick lose theirs. Lowest priority means first to be dropped. In a real system that may be exactly the wrong signal to lose, which is why queue length and consumer priority are design decisions.

With the consumer in the middle (hidden test), the two effects mix: the producer above it queues and continues, the producers below it are served immediately.

**Complexity.** Per message: O(1) CPU, two copies of `sizeof(Msg)` (8 bytes) and at most one extra context switch. RAM: `qlen * sizeof(Msg)` bytes plus the control block. The peak fill level is at most the number of producers that can run between two consumer runs. That number, not the average rate, sizes the queue.

**Common mistakes**
- Using one global `seq` for all producers, or a `static` counter inside the shared task function: all three tasks share it.
- Passing `&i` as `pvParameters`, so every producer reads the final loop value.
- Blocking producers with `portMAX_DELAY`: they then stall behind a slow consumer, which the specification forbids.
- Printing "sent" **before** calling `xQueueSend()`: the trace then claims a message was sent that may be dropped.
- Assuming FIFO order across producers equals wake-up order. It equals **send** order, and send order follows priorities.

**Interview follow-ups**
- How would you guarantee that the safety-critical producer is never the one that drops? (Separate queues, a queue set, or a higher priority than the others.)
- When does the consumer's priority need to be above the producers', and what does that cost in context switches?
- How do you measure the real peak fill level on target? (`uxQueueMessagesWaiting` sampling, trace hooks, a high-water mark in a wrapper.)
- What changes when one producer is an ISR using `xQueueSendFromISR()`?
