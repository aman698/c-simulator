@@@ meta
id: RQU-M-03
topic: Queues
difficulty: Medium
type: FUNCTION
title: Queue Set Gateway Blocking on Two Queues and a Flush Semaphore
tags: freertos, queue-set, xqueueselectfromset, semaphore, isr, embedded, asked-in-automotive
@@@ statement_md
A telematics gateway task must react to three event sources, all fed by interrupts:

- a **speed** queue (`uint16_t`, length 4),
- a **temperature** queue (`int16_t`, length 4),
- a **flush** binary semaphore: "publish what you have collected now".

A task can block on only one object at a time, so you will use a **queue set**. The task waits on the set, learns which member has data, and reads **exactly one** item from that member. If nothing at all arrives for `idle_timeout` ticks, the task reports `IDLE`.

```c
typedef struct {
    QueueHandle_t     speed_q;    /* you create: 4 x uint16_t */
    QueueHandle_t     temp_q;     /* you create: 4 x int16_t  */
    SemaphoreHandle_t flush_sem;  /* you create: binary semaphore */
} GwHandles;

typedef struct {
    uint32_t n_speed;     /* speed samples since the last publish */
    uint16_t last_speed;  /* most recent of them */
    uint32_t n_temp;      /* temperature samples since the last publish */
    int16_t  max_temp;    /* highest of them */
} Summary;

void on_speed(uint16_t v);       /* provided: prints "[t=<tick>] speed <v>" */
void on_temp(int16_t v);         /* provided: prints "[t=<tick>] temp <v>" */
void publish(const Summary *s);  /* provided: prints "[t=<tick>] PUBLISH speeds=.. last=.. temps=.. tmax=.." */
void on_idle(void);              /* provided: prints "[t=<tick>] IDLE" */

void app_start(GwHandles *h, TickType_t idle_timeout);  /* you write this */
```

`app_start()` must:

1. create the two queues and the binary semaphore, and store their handles in `*h` (the harness's interrupts post to them with `...FromISR()` and `portYIELD_FROM_ISR()`);
2. create a **queue set** big enough to hold an event for **every** item that can be pending in its members at the same time, and add the three members (all empty at that point);
3. create the **gateway** task with priority **3**. Forever:
   - `m = xQueueSelectFromSet(set, idle_timeout)`;
   - `NULL`: call `on_idle()`;
   - speed queue: receive one value with timeout 0, call `on_speed(v)`, update the summary;
   - temperature queue: the same with `on_temp(v)`;
   - flush semaphore: take it with timeout 0, call `publish(&summary)`, then reset the summary to all zeros.

`publish()` prints `-` for `last` when `n_speed == 0` and for `tmax` when `n_temp == 0`. `max_temp` must be correct for negative temperatures too.

**How it is tested.** The hidden `main()` reads `idle_timeout`, the event list and the duration `D`. It calls `app_start()`, schedules one interrupt per event and runs the scheduler up to and including tick `D`. An interrupt that finds its queue full prints `OVERFLOW`, and a flush while a flush is already pending prints `flush already pending`. At the end the harness prints how many items are left in each member.

**Timing rules**
- All interrupts of one tick run back to back, in input order, **before** the gateway runs. The queue set then hands the gateway the members in the order the items were posted.
- The idle timeout restarts at every `xQueueSelectFromSet()` call. If an event arrives at the very tick at which the timeout would expire, the event wins: the call returns the member, not `NULL`.
- The `vTaskDelay` family is not available: the gateway must block on the set.

**Input**
```
<idle_timeout> <n>
<tick> S <speed> | <tick> T <temp> | <tick> F      (n lines, sorted by tick)
<D>
```

**Example**
```
Input:
10 4
3 S 120
3 T 25
5 T -4
8 F
30

Output:
[t=3] speed 120
[t=3] temp 25
[t=5] temp -4
[t=8] PUBLISH speeds=1 last=120 temps=2 tmax=25
[t=18] IDLE
[t=28] IDLE
left: speed 0, temp 0, flush 0
```
Both interrupts at t=3 post before the gateway runs. The set returns the speed queue first, then the temperature queue. After the flush at t=8 nothing arrives, so the 10-tick timeout expires at t=18 and t=28.
@@@ constraints_md
- 1 <= idle_timeout <= 1000, 0 <= n <= 200, 1 <= tick <= D <= 10000, -300 <= temp <= 300, 0 <= speed <= 400.
- Queue lengths 4 and 4 with item sizes 2 bytes; one binary semaphore; one queue set; one task (priority 3, stack `configMINIMAL_STACK_SIZE`).
- Read exactly one item from the member returned by `xQueueSelectFromSet()`, with timeout 0.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"

typedef struct {
    QueueHandle_t     speed_q;
    QueueHandle_t     temp_q;
    SemaphoreHandle_t flush_sem;
} GwHandles;

typedef struct {
    uint32_t n_speed;
    uint16_t last_speed;
    uint32_t n_temp;
    int16_t  max_temp;
} Summary;

void on_speed(uint16_t v);
void on_temp(int16_t v);
void publish(const Summary *s);
void on_idle(void);

static void gateway_task(void *pvParameters)
{
    /* TODO: block on the queue set, dispatch on the returned member */
    (void)pvParameters;
    for (;;) {
        on_idle();
        vTaskSuspend(NULL);
    }
}

void app_start(GwHandles *h, TickType_t idle_timeout)
{
    /* TODO: create the members, the queue set, add the members, create the task */
    (void)h;
    (void)idle_timeout;
    (void)gateway_task;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "sim.h"

#define vTaskDelay(x) vTaskDelay_is_not_allowed_here
#define xTaskDelayUntil(a, b) xTaskDelayUntil_is_not_allowed_here
#undef vTaskDelayUntil
#define vTaskDelayUntil(a, b) vTaskDelayUntil_is_not_allowed_here
/*USER_CODE*/
#undef vTaskDelay
#undef xTaskDelayUntil
#undef vTaskDelayUntil

static GwHandles g_h;

void on_speed(uint16_t v)
{
    printf("[t=%u] speed %u\n", (unsigned)xTaskGetTickCount(), (unsigned)v);
}

void on_temp(int16_t v)
{
    printf("[t=%u] temp %d\n", (unsigned)xTaskGetTickCount(), (int)v);
}

void publish(const Summary *s)
{
    printf("[t=%u] PUBLISH speeds=%u last=", (unsigned)xTaskGetTickCount(), (unsigned)s->n_speed);
    if (s->n_speed) printf("%u", (unsigned)s->last_speed); else printf("-");
    printf(" temps=%u tmax=", (unsigned)s->n_temp);
    if (s->n_temp) printf("%d\n", (int)s->max_temp); else printf("-\n");
}

void on_idle(void)
{
    printf("[t=%u] IDLE\n", (unsigned)xTaskGetTickCount());
}

typedef struct {
    char kind;
    int  value;
} Ev;

static Ev g_ev[200];

static void ev_irq(void *arg)
{
    const Ev *e = (const Ev *)arg;
    BaseType_t woken = pdFALSE;
    unsigned t = (unsigned)xTaskGetTickCountFromISR();

    if (e->kind == 'S') {
        uint16_t v = (uint16_t)e->value;
        if (xQueueSendToBackFromISR(g_h.speed_q, &v, &woken) != pdPASS)
            printf("[t=%u] OVERFLOW speed %u\n", t, (unsigned)v);
    } else if (e->kind == 'T') {
        int16_t v = (int16_t)e->value;
        if (xQueueSendToBackFromISR(g_h.temp_q, &v, &woken) != pdPASS)
            printf("[t=%u] OVERFLOW temp %d\n", t, (int)v);
    } else {
        if (xSemaphoreGiveFromISR(g_h.flush_sem, &woken) != pdPASS)
            printf("[t=%u] flush already pending\n", t);
    }
    portYIELD_FROM_ISR(woken);
}

int main(void)
{
    unsigned tmo, n, i, tick, dur;
    char kind[4];

    if (scanf("%u %u", &tmo, &n) != 2 || n > 200) return 1;
    for (i = 0; i < n; i++) {
        if (scanf("%u %3s", &tick, kind) != 2) return 1;
        g_ev[i].kind = kind[0];
        g_ev[i].value = 0;
        if (kind[0] != 'F' && scanf("%d", &g_ev[i].value) != 1) return 1;
        xSimScheduleInterrupt((TickType_t)tick, ev_irq, &g_ev[i]);
    }
    if (scanf("%u", &dur) != 1) return 1;

    app_start(&g_h, (TickType_t)tmo);
    if (g_h.speed_q == NULL || g_h.temp_q == NULL || g_h.flush_sem == NULL) {
        printf("ERROR: create the two queues and the semaphore in app_start()\n");
        return 0;
    }
    if (uxQueueGetQueueLength(g_h.speed_q) != 4 || uxQueueGetQueueItemSize(g_h.speed_q) != sizeof(uint16_t) ||
        uxQueueGetQueueLength(g_h.temp_q) != 4 || uxQueueGetQueueItemSize(g_h.temp_q) != sizeof(int16_t) ||
        uxQueueGetQueueLength(g_h.flush_sem) != 1) {
        printf("ERROR: wrong queue / semaphore geometry\n");
        return 0;
    }
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("left: speed %u, temp %u, flush %u\n", (unsigned)uxQueueMessagesWaiting(g_h.speed_q),
           (unsigned)uxQueueMessagesWaiting(g_h.temp_q), (unsigned)uxQueueMessagesWaiting(g_h.flush_sem));
    return 0;
}
@@@ sample_input
10 4
3 S 120
3 T 25
5 T -4
8 F
30
@@@ sample_output
[t=3] speed 120
[t=3] temp 25
[t=5] temp -4
[t=8] PUBLISH speeds=1 last=120 temps=2 tmax=25
[t=18] IDLE
[t=28] IDLE
left: speed 0, temp 0, flush 0
@@@ sample_input
100 8
1 S 10
1 S 20
1 S 30
1 S 40
1 S 50
1 T 7
1 F
1 F
5
@@@ sample_output
[t=1] OVERFLOW speed 50
[t=1] flush already pending
[t=1] speed 10
[t=1] speed 20
[t=1] speed 30
[t=1] speed 40
[t=1] temp 7
[t=1] PUBLISH speeds=4 last=40 temps=1 tmax=7
left: speed 0, temp 0, flush 0
@@@ hidden_input
10 0
25
@@@ hidden_output
[t=10] IDLE
[t=20] IDLE
left: speed 0, temp 0, flush 0
@@@ hidden_input
5 3
5 T -12
10 F
15 F
20
@@@ hidden_output
[t=5] temp -12
[t=10] PUBLISH speeds=0 last=- temps=1 tmax=-12
[t=15] PUBLISH speeds=0 last=- temps=0 tmax=-
[t=20] IDLE
left: speed 0, temp 0, flush 0
@@@ hidden_input
50 9
2 T -50
2 S 1
2 T -7
2 S 2
2 T -300
2 S 3
2 T -8
2 S 4
2 F
60
@@@ hidden_output
[t=2] temp -50
[t=2] speed 1
[t=2] temp -7
[t=2] speed 2
[t=2] temp -300
[t=2] speed 3
[t=2] temp -8
[t=2] speed 4
[t=2] PUBLISH speeds=4 last=4 temps=4 tmax=-7
[t=52] IDLE
left: speed 0, temp 0, flush 0
@@@ hidden_input
7 6
7 S 100
14 S 200
14 F
20 T 0
27 S 300
40 F
40
@@@ hidden_output
[t=7] speed 100
[t=14] speed 200
[t=14] PUBLISH speeds=2 last=200 temps=0 tmax=-
[t=20] temp 0
[t=27] speed 300
[t=34] IDLE
[t=40] PUBLISH speeds=1 last=300 temps=1 tmax=0
left: speed 0, temp 0, flush 0

@@@ hidden_input
3 12
1 F
2 S 5
2 S 6
2 S 7
2 S 8
2 S 9
2 S 10
3 T 300
3 T 299
3 T -300
9 F
9 F
15
@@@ hidden_output
[t=1] PUBLISH speeds=0 last=- temps=0 tmax=-
[t=2] OVERFLOW speed 9
[t=2] OVERFLOW speed 10
[t=2] speed 5
[t=2] speed 6
[t=2] speed 7
[t=2] speed 8
[t=3] temp 300
[t=3] temp 299
[t=3] temp -300
[t=6] IDLE
[t=9] flush already pending
[t=9] PUBLISH speeds=4 last=8 temps=3 tmax=300
[t=12] IDLE
[t=15] IDLE
left: speed 0, temp 0, flush 0

@@@ hidden_input
1000 10
100 S 50
200 T 21
300 T 22
400 S 51
500 F
1600 S 52
2600 T -1
2600 F
2600 F
5000 F
6000
@@@ hidden_output
[t=100] speed 50
[t=200] temp 21
[t=300] temp 22
[t=400] speed 51
[t=500] PUBLISH speeds=2 last=51 temps=2 tmax=22
[t=1500] IDLE
[t=1600] speed 52
[t=2600] flush already pending
[t=2600] temp -1
[t=2600] PUBLISH speeds=1 last=52 temps=1 tmax=-1
[t=3600] IDLE
[t=4600] IDLE
[t=5000] PUBLISH speeds=0 last=- temps=0 tmax=-
[t=6000] IDLE
left: speed 0, temp 0, flush 0

@@@ hint
The queue set itself is a queue of **handles**. Each item posted to a member also posts that member's handle to the set, so the set length must be the sum of the member lengths: 4 + 4 + 1 = 9. Members must be empty when they are added (`xQueueAddToSet(member, set)`), which is why you add them in `app_start()` before any interrupt can fire.
@@@ hint
`QueueSetMemberHandle_t m = xQueueSelectFromSet(set, timeout); if (m == NULL) on_idle(); else if (m == (QueueSetMemberHandle_t)h->speed_q) { uint16_t v; xQueueReceive(h->speed_q, &v, 0); ... } else if (m == (QueueSetMemberHandle_t)h->temp_q) { ... } else { xSemaphoreTake(h->flush_sem, 0); publish(&s); memset(&s, 0, sizeof s); }`. Initialise `max_temp` from the first sample after a reset (`n_temp == 0`), not from 0.
@@@ solution_code
#include <stdint.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"

typedef struct {
    QueueHandle_t     speed_q;
    QueueHandle_t     temp_q;
    SemaphoreHandle_t flush_sem;
} GwHandles;

typedef struct {
    uint32_t n_speed;
    uint16_t last_speed;
    uint32_t n_temp;
    int16_t  max_temp;
} Summary;

void on_speed(uint16_t v);
void on_temp(int16_t v);
void publish(const Summary *s);
void on_idle(void);

#define SPEED_LEN 4
#define TEMP_LEN  4

static QueueSetHandle_t s_set;
static const GwHandles *s_h;
static TickType_t s_idle;

static void gateway_task(void *pvParameters)
{
    Summary s;

    (void)pvParameters;
    memset(&s, 0, sizeof s);
    for (;;) {
        QueueSetMemberHandle_t m = xQueueSelectFromSet(s_set, s_idle);

        if (m == NULL) {
            on_idle();
        } else if (m == (QueueSetMemberHandle_t)s_h->speed_q) {
            uint16_t v;
            if (xQueueReceive(s_h->speed_q, &v, 0) == pdPASS) {
                on_speed(v);
                s.last_speed = v;
                s.n_speed++;
            }
        } else if (m == (QueueSetMemberHandle_t)s_h->temp_q) {
            int16_t v;
            if (xQueueReceive(s_h->temp_q, &v, 0) == pdPASS) {
                on_temp(v);
                if (s.n_temp == 0 || v > s.max_temp) {
                    s.max_temp = v;   /* first sample defines the max */
                }
                s.n_temp++;
            }
        } else if (m == (QueueSetMemberHandle_t)s_h->flush_sem) {
            if (xSemaphoreTake(s_h->flush_sem, 0) == pdPASS) {
                publish(&s);
                memset(&s, 0, sizeof s);
            }
        }
    }
}

void app_start(GwHandles *h, TickType_t idle_timeout)
{
    h->speed_q = xQueueCreate(SPEED_LEN, sizeof(uint16_t));
    h->temp_q = xQueueCreate(TEMP_LEN, sizeof(int16_t));
    h->flush_sem = xSemaphoreCreateBinary();

    /* one set slot per item that can be pending in any member */
    s_set = xQueueCreateSet(SPEED_LEN + TEMP_LEN + 1);
    xQueueAddToSet(h->speed_q, s_set);
    xQueueAddToSet(h->temp_q, s_set);
    xQueueAddToSet(h->flush_sem, s_set);

    s_h = h;
    s_idle = idle_timeout;
    xTaskCreate(gateway_task, "gw", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
}
@@@ explanation_md
**Approach.** A queue set lets one task block on several queues and semaphores at once. Internally it is a queue of **member handles**. Every successful send or give to a member also writes that member's handle into the set, in posting order. `xQueueSelectFromSet()` is a blocking receive on that handle queue. The rules that make it work:

- **Size.** The set length must be at least the sum of the member lengths (4 + 4 + 1 = 9). Otherwise a burst can fill the set while a member still has space, and the kernel asserts. The hidden test with 9 events at one tick checks this.
- **Members start empty.** `xQueueAddToSet()` fails on a non-empty member, because the set would otherwise miss the items already there.
- **One read per select.** After the set returns a member, read exactly one item from it, with timeout 0. The set holds one handle per item. Reading two items, or ignoring one, desynchronises the set from the members.
- **Timeout.** The timeout of `xQueueSelectFromSet()` is the "nothing happened for W ticks" detector. An event posted at the same tick the timeout expires is still found by the receive, so the event wins.

**Complexity.** Per event: O(1) CPU, one item copy plus one handle copy into the set. RAM: member storage (8 + 8 bytes + semaphore) plus 9 handles in the set. One task and one stack instead of one task per source, which is the main reason to use a queue set. The worst-case reaction time to an event is the time spent handling the events posted before it.

**Common mistakes**
- Set length 3 ("one per member"): a burst of 5 items overflows the set, and the kernel asserts.
- Reading from the members in a fixed order ("check speed first, then temp") instead of the member the set returned: this breaks the order and the handle accounting.
- Adding a member after the interrupts have already started posting to it.
- Initialising `max_temp` to 0: wrong when every temperature is negative.
- Polling every member with timeout 0 inside a `vTaskDelay(1)` loop: higher CPU load and latency, and no clean idle detection.

**Interview follow-ups**
- Queue set vs. one queue of tagged unions vs. event group plus queues: what are the trade-offs in RAM, latency and code complexity?
- Why does FreeRTOS discourage queue sets in favour of a single queue when that is possible?
- Can a mutex be a queue-set member? Why not?
- How would you give the flush event priority over the queued samples?
