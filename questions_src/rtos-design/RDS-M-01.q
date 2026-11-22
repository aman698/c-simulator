@@@ meta
id: RDS-M-01
topic: RTOS Design Patterns
difficulty: Medium
type: FUNCTION
title: Publish Subscribe Event Bus With Per Subscriber Inboxes
tags: freertos, publish-subscribe, event-bus, xqueuesendfromisr, decoupling, embedded
@@@ statement_md
Software components of a gateway ECU should not call each other directly. Write a small **publish/subscribe event bus**. Components subscribe to topics by handing the bus their own inbox queue. Publishers (tasks or ISRs) publish a value on a topic, and the bus copies it into the inbox of **every** subscriber of that topic.

```c
#define BUS_MAX_SUBS 4

typedef struct {
    uint8_t    topic;   /* 0..31 */
    int32_t    value;
    TickType_t stamp;   /* tick count when the value was published */
} BusMsg;

void        bus_init(void);
BaseType_t  bus_subscribe(uint32_t topic_mask, QueueHandle_t inbox);
UBaseType_t bus_publish(uint8_t topic, int32_t value);
UBaseType_t bus_publish_from_isr(uint8_t topic, int32_t value, BaseType_t *pxHigherPriorityTaskWoken);
```

Rules:

- `bus_subscribe()` registers `inbox` (a queue of `BusMsg`) for every topic whose bit is set in `topic_mask` (bit `k` = topic `k`). The bus has room for **`BUS_MAX_SUBS` = 4** subscribers. It returns `pdPASS`, or `pdFAIL` when the table is full, `inbox` is NULL or `topic_mask` is 0.
- `bus_publish()` (task context) and `bus_publish_from_isr()` (interrupt context) build one `BusMsg`, with `stamp` set to the current tick, and deliver a copy to every matching subscriber **in subscription order**. Both return the number of inboxes that received it.
- Delivery **never blocks**. If a subscriber's inbox is full, that subscriber misses this message, and the others still get it. One slow component must never stall the publisher or the rest of the system.
- `bus_publish_from_isr()` uses only `...FromISR` APIs. It sets `*pxHigherPriorityTaskWoken` to `pdTRUE` if **any** delivery woke a higher-priority task. It never sets it back to `pdFALSE`. The caller then does `portYIELD_FROM_ISR()`.

**How it is tested.** The hidden `main()` calls `bus_init()`, creates every subscriber's inbox (its own length) and calls `bus_subscribe()` in input order. It prints `SUB <name> FAIL` when that fails. Each subscribed component is a judge task that loops: receive from its inbox, print `[t=<tick>] <name> got topic=<topic> val=<value> age=<now - stamp>`, then stay busy for `work` ticks. Publications come from:

- `ISR <tick> <topic> <value>`: a simulated interrupt calls `bus_publish_from_isr()` and prints `[t=<tick>] IRQ topic=<topic> val=<value> -> <delivered>`;
- `TASK <tick> <topic> <value>`: a judge publisher task of priority **6** calls `bus_publish()` and prints `[t=<tick>] PUB topic=<topic> val=<value> -> <delivered>` (or `FAIL` if the call blocked).

At the end, the judge prints `<name>: received=<n> waiting=<messages still in the inbox>` for every component (or `<name>: not subscribed`) and the totals. Within one tick, interrupts run first, then the publisher task, then the components by priority (highest first).

**Input**
```
<n> <D>
<name> <priority> <inbox_len> <work> <topic_mask_hex>     (n lines, priorities 1..5, distinct)
<m>
<ISR|TASK> <tick> <topic> <value>                         (m lines, ticks non-decreasing)
```

**Example**
```
Input:
3 40
LOG 1 8 0 7
ABS 4 2 0 2
HMI 2 1 5 5
6
ISR 10 1 55
ISR 10 0 7
TASK 20 2 300
TASK 20 1 60
ISR 21 0 8
ISR 22 2 9

Output:
[t=10] IRQ topic=1 val=55 -> 2
[t=10] IRQ topic=0 val=7 -> 2
[t=10] ABS got topic=1 val=55 age=0
[t=10] HMI got topic=0 val=7 age=0
[t=15] LOG got topic=1 val=55 age=5
[t=15] LOG got topic=0 val=7 age=5
[t=20] PUB topic=2 val=300 -> 2
[t=20] PUB topic=1 val=60 -> 2
[t=20] ABS got topic=1 val=60 age=0
[t=20] HMI got topic=2 val=300 age=0
[t=21] IRQ topic=0 val=8 -> 2
[t=22] IRQ topic=2 val=9 -> 1
[t=25] HMI got topic=0 val=8 age=4
[t=30] LOG got topic=2 val=300 age=10
[t=30] LOG got topic=1 val=60 age=10
[t=30] LOG got topic=0 val=8 age=9
[t=30] LOG got topic=2 val=9 age=8
LOG: received=6 waiting=0
ABS: received=2 waiting=0
HMI: received=3 waiting=0
published=6 delivered=11
```
HMI (inbox of 1, 5 ticks of work per message) is busy from t=20 to t=25, and its inbox already holds `val=8`. The publication at t=22 therefore reaches only LOG (`-> 1`). LOG has the lowest priority, so it runs only when HMI is idle.
@@@ constraints_md
- 1 <= n <= 5, 1 <= inbox_len <= 8, 0 <= work <= 20, 0 <= m <= 40, 1 <= tick < D <= 2000, topic 0..31, |value| <= 10^6.
- Do not allocate per message. The subscriber table is a fixed array of `BUS_MAX_SUBS` entries.
- Do not create tasks: the bus is a library called from the tasks and ISRs of others.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

#define BUS_MAX_SUBS 4

typedef struct {
    uint8_t    topic;
    int32_t    value;
    TickType_t stamp;
} BusMsg;

void bus_init(void)
{
    /* TODO */
}

BaseType_t bus_subscribe(uint32_t topic_mask, QueueHandle_t inbox)
{
    /* TODO */
    (void)topic_mask;
    (void)inbox;
    return pdFAIL;
}

UBaseType_t bus_publish(uint8_t topic, int32_t value)
{
    /* TODO: deliver to every matching inbox, never block */
    (void)topic;
    (void)value;
    return 0;
}

UBaseType_t bus_publish_from_isr(uint8_t topic, int32_t value, BaseType_t *pxHigherPriorityTaskWoken)
{
    /* TODO: same, from an interrupt */
    (void)topic;
    (void)value;
    (void)pxHigherPriorityTaskWoken;
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

/*USER_CODE*/

typedef struct {
    char name[16];
    unsigned prio, qlen, work, mask;
    QueueHandle_t inbox;
    int subscribed;
    unsigned received;
} Comp;

typedef struct {
    int from_isr;
    unsigned tick, topic;
    int value;
} Pub;

static Comp g_comp[5];
static Pub g_pub[40];
static int g_ncomp, g_npub;
static unsigned g_published, g_delivered;

static void comp_task(void *p)
{
    Comp *c = (Comp *)p;
    BusMsg m;

    for (;;) {
        if (xQueueReceive(c->inbox, &m, portMAX_DELAY) != pdPASS) continue;
        c->received++;
        printf("[t=%u] %s got topic=%u val=%d age=%u\n", (unsigned)xTaskGetTickCount(), c->name,
               (unsigned)m.topic, (int)m.value, (unsigned)(xTaskGetTickCount() - m.stamp));
        vSimBusyWork((TickType_t)c->work);
    }
}

static void irq_handler(void *arg)
{
    const Pub *p = (const Pub *)arg;
    BaseType_t woken = pdFALSE;
    UBaseType_t n = bus_publish_from_isr((uint8_t)p->topic, (int32_t)p->value, &woken);

    printf("[t=%u] IRQ topic=%u val=%d -> %d\n", (unsigned)xTaskGetTickCountFromISR(), p->topic, p->value, (int)n);
    g_published++;
    g_delivered += (unsigned)n;
    portYIELD_FROM_ISR(woken);
}

static void publisher_task(void *p)
{
    int i;

    (void)p;
    for (i = 0; i < g_npub; i++) {
        TickType_t before, now = xTaskGetTickCount();
        UBaseType_t n;

        if (g_pub[i].from_isr) continue;
        if ((TickType_t)g_pub[i].tick > now) vTaskDelay((TickType_t)g_pub[i].tick - now);
        before = xTaskGetTickCount();
        n = bus_publish((uint8_t)g_pub[i].topic, (int32_t)g_pub[i].value);
        if (xTaskGetTickCount() != before) {
            printf("[t=%u] PUB topic=%u FAIL: bus_publish() blocked\n", (unsigned)xTaskGetTickCount(), g_pub[i].topic);
        } else {
            printf("[t=%u] PUB topic=%u val=%d -> %d\n", (unsigned)before, g_pub[i].topic, g_pub[i].value, (int)n);
        }
        g_published++;
        g_delivered += (unsigned)n;
    }
    vTaskDelete(NULL);
}

int main(void)
{
    unsigned dur;
    int i;
    char kind[8];

    if (scanf("%d %u", &g_ncomp, &dur) != 2 || g_ncomp < 1 || g_ncomp > 5) return 1;
    bus_init();
    for (i = 0; i < g_ncomp; i++) {
        Comp *c = &g_comp[i];
        if (scanf("%15s %u %u %u %x", c->name, &c->prio, &c->qlen, &c->work, &c->mask) != 5) return 1;
        c->inbox = xQueueCreate((UBaseType_t)c->qlen, sizeof(BusMsg));
        c->subscribed = bus_subscribe((uint32_t)c->mask, c->inbox) == pdPASS;
        if (!c->subscribed) printf("SUB %s FAIL\n", c->name);
        else xTaskCreate(comp_task, c->name, configMINIMAL_STACK_SIZE, c, (UBaseType_t)c->prio, NULL);
    }
    if (scanf("%d", &g_npub) != 1 || g_npub < 0 || g_npub > 40) return 1;
    for (i = 0; i < g_npub; i++) {
        if (scanf("%7s %u %u %d", kind, &g_pub[i].tick, &g_pub[i].topic, &g_pub[i].value) != 4) return 1;
        g_pub[i].from_isr = strcmp(kind, "ISR") == 0;
        if (g_pub[i].from_isr) xSimScheduleInterrupt((TickType_t)g_pub[i].tick, irq_handler, &g_pub[i]);
    }
    xTaskCreate(publisher_task, "PUBLISHER", configMINIMAL_STACK_SIZE, NULL, 6, NULL);

    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    for (i = 0; i < g_ncomp; i++) {
        if (g_comp[i].subscribed)
            printf("%s: received=%u waiting=%d\n", g_comp[i].name, g_comp[i].received,
                   (int)uxQueueMessagesWaiting(g_comp[i].inbox));
        else
            printf("%s: not subscribed\n", g_comp[i].name);
    }
    printf("published=%u delivered=%u\n", g_published, g_delivered);
    return 0;
}
@@@ sample_input
3 40
LOG 1 8 0 7
ABS 4 2 0 2
HMI 2 1 5 5
6
ISR 10 1 55
ISR 10 0 7
TASK 20 2 300
TASK 20 1 60
ISR 21 0 8
ISR 22 2 9
@@@ sample_output
[t=10] IRQ topic=1 val=55 -> 2
[t=10] IRQ topic=0 val=7 -> 2
[t=10] ABS got topic=1 val=55 age=0
[t=10] HMI got topic=0 val=7 age=0
[t=15] LOG got topic=1 val=55 age=5
[t=15] LOG got topic=0 val=7 age=5
[t=20] PUB topic=2 val=300 -> 2
[t=20] PUB topic=1 val=60 -> 2
[t=20] ABS got topic=1 val=60 age=0
[t=20] HMI got topic=2 val=300 age=0
[t=21] IRQ topic=0 val=8 -> 2
[t=22] IRQ topic=2 val=9 -> 1
[t=25] HMI got topic=0 val=8 age=4
[t=30] LOG got topic=2 val=300 age=10
[t=30] LOG got topic=1 val=60 age=10
[t=30] LOG got topic=0 val=8 age=9
[t=30] LOG got topic=2 val=9 age=8
LOG: received=6 waiting=0
ABS: received=2 waiting=0
HMI: received=3 waiting=0
published=6 delivered=11
@@@ sample_input
5 30
A 5 2 0 1
B 4 2 0 3
C 3 2 0 2
D 2 2 0 8
E 1 2 0 1
4
ISR 1 0 -5
ISR 1 3 4
TASK 2 1 100
TASK 2 7 1
@@@ sample_output
SUB E FAIL
[t=1] IRQ topic=0 val=-5 -> 2
[t=1] IRQ topic=3 val=4 -> 1
[t=1] A got topic=0 val=-5 age=0
[t=1] B got topic=0 val=-5 age=0
[t=1] D got topic=3 val=4 age=0
[t=2] PUB topic=1 val=100 -> 2
[t=2] PUB topic=7 val=1 -> 0
[t=2] B got topic=1 val=100 age=0
[t=2] C got topic=1 val=100 age=0
A: received=1 waiting=0
B: received=2 waiting=0
C: received=1 waiting=0
D: received=1 waiting=0
E: not subscribed
published=4 delivered=5
@@@ hidden_input
2 100
X 3 4 0 ffffffff
Y 2 4 0 80000000
0
@@@ hidden_output
X: received=0 waiting=0
Y: received=0 waiting=0
published=0 delivered=0
@@@ hidden_input
2 100
FAST 4 3 0 1
SLOW 1 2 30 1
6
ISR 5 0 1
ISR 5 0 2
ISR 5 0 3
ISR 5 0 4
TASK 6 0 5
ISR 40 0 6
@@@ hidden_output
[t=5] IRQ topic=0 val=1 -> 2
[t=5] IRQ topic=0 val=2 -> 2
[t=5] IRQ topic=0 val=3 -> 1
[t=5] IRQ topic=0 val=4 -> 0
[t=5] FAST got topic=0 val=1 age=0
[t=5] FAST got topic=0 val=2 age=0
[t=5] FAST got topic=0 val=3 age=0
[t=5] SLOW got topic=0 val=1 age=0
[t=6] PUB topic=0 val=5 -> 2
[t=6] FAST got topic=0 val=5 age=0
[t=35] SLOW got topic=0 val=2 age=30
[t=40] IRQ topic=0 val=6 -> 2
[t=40] FAST got topic=0 val=6 age=0
[t=65] SLOW got topic=0 val=5 age=59
[t=95] SLOW got topic=0 val=6 age=55
FAST: received=5 waiting=0
SLOW: received=4 waiting=0
published=6 delivered=9

@@@ hidden_input
3 60
P 3 1 10 31
Q 2 1 0 4
R 5 2 3 2
7
ISR 1 31 1000000
TASK 1 2 -1000000
TASK 3 1 11
ISR 4 1 12
ISR 4 4 13
TASK 9 2 14
ISR 20 31 15
@@@ hidden_output
[t=1] IRQ topic=31 val=1000000 -> 0
[t=1] PUB topic=2 val=-1000000 -> 1
[t=1] Q got topic=2 val=-1000000 age=0
[t=3] PUB topic=1 val=11 -> 1
[t=3] R got topic=1 val=11 age=0
[t=4] IRQ topic=1 val=12 -> 1
[t=4] IRQ topic=4 val=13 -> 1
[t=6] R got topic=1 val=12 age=2
[t=9] PUB topic=2 val=14 -> 1
[t=9] P got topic=4 val=13 age=5
[t=19] Q got topic=2 val=14 age=10
[t=20] IRQ topic=31 val=15 -> 0
P: received=1 waiting=0
Q: received=2 waiting=0
R: received=2 waiting=0
published=7 delivered=5

@@@ hidden_input
4 50
S1 1 1 0 1
S2 2 1 0 1
S3 3 1 0 1
S4 4 1 0 0
3
ISR 10 0 1
TASK 10 0 2
ISR 11 0 3
@@@ hidden_output
SUB S4 FAIL
[t=10] IRQ topic=0 val=1 -> 3
[t=10] PUB topic=0 val=2 -> 0
[t=10] S3 got topic=0 val=1 age=0
[t=10] S2 got topic=0 val=1 age=0
[t=10] S1 got topic=0 val=1 age=0
[t=11] IRQ topic=0 val=3 -> 3
[t=11] S3 got topic=0 val=3 age=0
[t=11] S2 got topic=0 val=3 age=0
[t=11] S1 got topic=0 val=3 age=0
S1: received=2 waiting=0
S2: received=2 waiting=0
S3: received=2 waiting=0
S4: not subscribed
published=3 delivered=6

@@@ hidden_input
1 200
ONLY 5 8 2 1
9
ISR 100 0 1
ISR 100 0 2
ISR 100 0 3
ISR 100 0 4
ISR 100 0 5
ISR 100 0 6
ISR 100 0 7
ISR 100 0 8
ISR 100 0 9
@@@ hidden_output
[t=100] IRQ topic=0 val=1 -> 1
[t=100] IRQ topic=0 val=2 -> 1
[t=100] IRQ topic=0 val=3 -> 1
[t=100] IRQ topic=0 val=4 -> 1
[t=100] IRQ topic=0 val=5 -> 1
[t=100] IRQ topic=0 val=6 -> 1
[t=100] IRQ topic=0 val=7 -> 1
[t=100] IRQ topic=0 val=8 -> 1
[t=100] IRQ topic=0 val=9 -> 0
[t=100] ONLY got topic=0 val=1 age=0
[t=102] ONLY got topic=0 val=2 age=2
[t=104] ONLY got topic=0 val=3 age=4
[t=106] ONLY got topic=0 val=4 age=6
[t=108] ONLY got topic=0 val=5 age=8
[t=110] ONLY got topic=0 val=6 age=10
[t=112] ONLY got topic=0 val=7 age=12
[t=114] ONLY got topic=0 val=8 age=14
ONLY: received=8 waiting=0
published=9 delivered=8

@@@ hidden_input
3 120
GW 1 6 4 3
BCM 3 2 6 2
TCU 2 3 0 1
8
TASK 10 0 100
TASK 10 1 101
TASK 11 1 102
ISR 12 1 103
ISR 12 0 104
TASK 13 1 105
ISR 30 0 106
TASK 31 1 107
@@@ hidden_output
[t=10] PUB topic=0 val=100 -> 2
[t=10] PUB topic=1 val=101 -> 2
[t=10] BCM got topic=1 val=101 age=0
[t=11] PUB topic=1 val=102 -> 2
[t=12] IRQ topic=1 val=103 -> 2
[t=12] IRQ topic=0 val=104 -> 2
[t=13] PUB topic=1 val=105 -> 1
[t=16] BCM got topic=1 val=102 age=5
[t=22] BCM got topic=1 val=103 age=10
[t=28] TCU got topic=0 val=100 age=18
[t=28] TCU got topic=0 val=104 age=16
[t=28] GW got topic=0 val=100 age=18
[t=30] IRQ topic=0 val=106 -> 2
[t=30] TCU got topic=0 val=106 age=0
[t=31] PUB topic=1 val=107 -> 1
[t=31] BCM got topic=1 val=107 age=0
[t=38] GW got topic=1 val=101 age=28
[t=42] GW got topic=1 val=102 age=31
[t=46] GW got topic=1 val=103 age=34
[t=50] GW got topic=0 val=104 age=38
[t=54] GW got topic=1 val=105 age=41
[t=58] GW got topic=0 val=106 age=28
GW: received=7 waiting=0
BCM: received=4 waiting=0
TCU: received=3 waiting=0
published=8 delivered=14

@@@ hint
Keep a fixed table `{ uint32_t mask; QueueHandle_t q; }` of 4 entries and a count. Publishing is a loop over the table: `if (mask & (1u << topic))` then send with **timeout 0** (`xQueueSend(q, &m, 0)` in a task, `xQueueSendFromISR(q, &m, &woken)` in an ISR) and count the successes.
@@@ hint
In the ISR version, pass the caller's `pxHigherPriorityTaskWoken` to every `xQueueSendFromISR()` call (or OR the results together yourself): FreeRTOS only ever sets it to `pdTRUE`, so a later delivery cannot hide an earlier wake-up. Use `xTaskGetTickCountFromISR()` for the stamp. In production, protect the table with a critical section if subscriptions can happen while the scheduler runs.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

#define BUS_MAX_SUBS 4

typedef struct {
    uint8_t    topic;
    int32_t    value;
    TickType_t stamp;
} BusMsg;

typedef struct {
    uint32_t      mask;
    QueueHandle_t inbox;
} BusSub;

static BusSub s_subs[BUS_MAX_SUBS];
static UBaseType_t s_nsubs;

void bus_init(void)
{
    s_nsubs = 0;
}

BaseType_t bus_subscribe(uint32_t topic_mask, QueueHandle_t inbox)
{
    BaseType_t ok = pdFAIL;

    if (inbox == NULL || topic_mask == 0u) return pdFAIL;
    taskENTER_CRITICAL();               /* ISRs may be walking the table */
    if (s_nsubs < BUS_MAX_SUBS) {
        s_subs[s_nsubs].mask = topic_mask;
        s_subs[s_nsubs].inbox = inbox;
        s_nsubs++;
        ok = pdPASS;
    }
    taskEXIT_CRITICAL();
    return ok;
}

UBaseType_t bus_publish(uint8_t topic, int32_t value)
{
    BusMsg m;
    UBaseType_t i, n = 0;

    if (topic > 31u) return 0;
    m.topic = topic;
    m.value = value;
    m.stamp = xTaskGetTickCount();
    for (i = 0; i < s_nsubs; i++) {
        if ((s_subs[i].mask & ((uint32_t)1u << topic)) != 0u &&
            xQueueSend(s_subs[i].inbox, &m, 0) == pdPASS) {   /* never block */
            n++;
        }
    }
    return n;
}

UBaseType_t bus_publish_from_isr(uint8_t topic, int32_t value, BaseType_t *pxHigherPriorityTaskWoken)
{
    BusMsg m;
    UBaseType_t i, n = 0;
    BaseType_t woken = pdFALSE;

    if (topic > 31u) return 0;
    m.topic = topic;
    m.value = value;
    m.stamp = xTaskGetTickCountFromISR();
    for (i = 0; i < s_nsubs; i++) {
        if ((s_subs[i].mask & ((uint32_t)1u << topic)) != 0u &&
            xQueueSendFromISR(s_subs[i].inbox, &m, &woken) == pdPASS) {
            n++;
        }
    }
    if (woken != pdFALSE && pxHigherPriorityTaskWoken != NULL) {
        *pxHigherPriorityTaskWoken = pdTRUE;    /* OR, never clear */
    }
    return n;
}
@@@ explanation_md
**Approach.** The bus is a fixed table of `(topic mask, inbox queue)` pairs. Publishing walks the table and copies the message into every matching inbox with a **zero timeout**, so delivery is O(subscribers) and never blocks. Each subscriber owns its inbox and decides its own depth and priority. In the example, a slow HMI with an inbox of 1 loses `val=9` at t=22, but the publisher and LOG are not affected. The ISR variant only uses `xQueueSendFromISR()`. It merges the "woken" flags of all deliveries into the caller's flag, so the interrupt yields once at the end, and the highest-priority woken subscriber runs at the same tick.

Copying by value (12 bytes) avoids any ownership or lifetime question: the publisher's local `BusMsg` can die right after the call. `stamp` lets subscribers measure their own latency (`age`).

**Complexity.** Publish: O(S) with S <= 4 subscribers, plus one `sizeof(BusMsg)` copy per delivery. Subscribe: O(1). RAM: 4 x 8 bytes of table plus the subscribers' own queues. Worst-case publisher blocking time: **zero**.

**Common mistakes**
- Sending with `portMAX_DELAY` (or any timeout) in `bus_publish()`: a single full inbox then stalls every publisher (`FAIL: bus_publish() blocked`).
- Calling `xQueueSend()` from the ISR path: Runtime Error. Task APIs are forbidden in interrupts.
- Writing `*pxHigherPriorityTaskWoken = woken_of_last_send`: an earlier wake-up is lost, and the woken task runs a tick late.
- Stopping at the first full inbox (`break`) instead of continuing with the other subscribers.
- `1 << topic` with `topic = 31` on a signed `int`: undefined behaviour. Use an unsigned constant.
- Storing pointers to the publisher's data in the queue instead of the data.

**Interview follow-ups**
- How would you support `bus_unsubscribe()` safely while an ISR may be publishing?
- Large payloads (a 1 KB frame): what would you put in the queue instead (a pool of buffers + reference counting)?
- How would you make the bus report the subscribers that dropped messages (per-subscriber overflow counters)?
- Compare this with an event group or a queue set: what can each of them express?
