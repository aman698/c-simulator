@@@ meta
id: REV-H-03
topic: Event Groups & Notifications
difficulty: Hard
type: FUNCTION
title: Three-Stage Pipeline With Notification Handshakes and Backpressure
tags: freertos, task-notifications, indexed-notifications, pipeline, backpressure, handshake, embedded
@@@ statement_md
A radar ECU processes detections in a three-stage pipeline: a **producer** (P) delivers raw items, **stage A** filters them, **stage B** sends the results out. Between two stages there is exactly **one single-item slot** (a plain `static int`). There are no queues: the stages synchronise with **task notifications only**, using two indexes per task:

- **index 0, "data ready"**: the upstream stage tells the downstream stage that its input slot is full;
- **index 1, "slot free"**: the downstream stage tells the upstream stage that it has copied the item out, so the slot may be overwritten.

That is **backpressure**: an upstream stage that finds the next slot still full **blocks**, and it never overwrites an unread item.

```c
TickType_t release_tick(int k);  /* provided: the tick at which item k becomes available        */
int  produce(int k);             /* provided: returns item k and prints "[t=<tick>] P put <v>",
                                    plus " (waited <w>)" if it is later than release_tick(k)      */
int  stage_a(int v);             /* provided: prints "[t=<tick>] A <v>", takes costA ticks of CPU,
                                    returns the filtered value                                     */
void stage_b(int v);             /* provided: prints "[t=<tick>] B <v>", takes costB ticks of CPU */

void app_start(int n_items);     /* you write: create the three tasks */
```

**Tasks and fixed priorities:** P = 4, B = 3, A = 2. Create them in `app_start()` and keep their handles.
- **P**: for `k = 0 .. n_items-1`: wait until `release_tick(k)` (`vTaskDelay` for the remaining ticks, or no wait if it is already due). Then wait for "slot 1 free" (own index 1), then `slot1 = produce(k)`, then "data ready" to A (A's index 0). After the last item, P **suspends itself forever** (`vTaskSuspend(NULL)`). It must not delete itself, because A still notifies it.
- **A**: when it starts, it signals "slot 1 free" to P once (the slot is empty). Then it loops: wait "data ready" (own index 0), copy `slot1` out, **immediately** signal "slot 1 free" to P, then `r = stage_a(v)`, then wait "slot 2 free" (own index 1), `slot2 = r`, "data ready" to B.
- **B**: when it starts, it signals "slot 2 free" to A once. Then it loops: wait "data ready" (own index 0), copy `slot2` out, **immediately** signal "slot 2 free" to A, then `stage_b(v)`.

Freeing a slot right after copying (before processing) lets the upstream stage refill it in parallel: double buffering. A notification to a **higher-priority** task that is waiting for it makes that task run **at once** (preemption inside `xTaskNotifyGive`). Queues, semaphores, event groups and stream buffers are disabled in this exercise.

**How it is tested.** The hidden `main()` reads the items, calls `app_start()` and runs the scheduler up to and including tick `D`. Simulated time only moves while every task is blocked or inside `stage_a()`/`stage_b()`. A higher-priority task preempts a lower-priority one at once, also in the middle of its stage work, and the preempted work resumes later. The harness checks that A sees exactly the produced items, and B exactly A's results, in order with no loss or duplicate (`ERROR: ...` otherwise). Then it prints `produced=.. a=.. b=.. max_wait=..` and `PIPELINE OK`.

**Input**
```
<costA> <costB> <D>
<n>
<release> <value>     (n lines, release non-decreasing, >= 1)
```

**Example**
```
Input:
3 5 40
3
1 10
2 20
3 30

Output:
[t=1] P put 10
[t=1] A 10
[t=2] P put 20
[t=4] B 11
[t=9] P put 30 (waited 6)
[t=9] A 20
[t=12] B 21
[t=17] A 30
[t=20] B 31
produced=3 a=3 b=3 max_wait=6
PIPELINE OK
```
(`stage_a` returns `v + 1`.) At t=1, A takes item 10, frees slot 1, and filters until t=4. P refills slot 1 with 20 at t=2. At t=3, P finds slot 1 full and blocks: backpressure. At t=4, A hands 11 to B, which preempts A and works until t=9. Only then can A copy item 20 and free slot 1. P (priority 4) preempts A at once and puts 30 at t=9, 6 ticks late. Then A filters 20 (t=9..12), and so on.
@@@ constraints_md
- 1 <= costA, costB <= 20, 1 <= n <= 50, 1 <= release <= 2000, 1 <= D <= 20000. All items finish well before D.
- Exactly three tasks with priorities P = 4, B = 3, A = 2. Only task notifications (indexes 0 and 1) for synchronisation.
- Use `configMINIMAL_STACK_SIZE` stacks.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"

TickType_t release_tick(int k);
int  produce(int k);
int  stage_a(int v);
void stage_b(int v);

#define IDX_DATA 0
#define IDX_FREE 1

static TaskHandle_t p_handle, a_handle, b_handle;
static int slot1, slot2;
static int total_items;

static void producer_task(void *pv)
{
    (void)pv;
    /* TODO */
    vTaskSuspend(NULL);
}

static void stage_a_task(void *pv)
{
    (void)pv;
    /* TODO */
    vTaskSuspend(NULL);
}

static void stage_b_task(void *pv)
{
    (void)pv;
    /* TODO */
    vTaskSuspend(NULL);
}

void app_start(int n_items)
{
    total_items = n_items;
    /* TODO: create P (prio 4), A (prio 2), B (prio 3) and keep the handles */
    (void)producer_task; (void)stage_a_task; (void)stage_b_task;
    (void)p_handle; (void)a_handle; (void)b_handle;
    (void)slot1; (void)slot2;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "event_groups.h"
#include "stream_buffer.h"
#include "sim.h"

#define MAXN 50
static int g_n;
static unsigned g_rel[MAXN];
static int g_val[MAXN];
static TickType_t g_ca, g_cb;
static int g_produced[MAXN], g_np;     /* values in production order */
static int g_aout[MAXN], g_na, g_nb;
static unsigned g_max_wait, g_errors;

TickType_t release_tick(int k)
{
    if (k < 0 || k >= g_n) {
        printf("ERROR: release_tick(%d) out of range\n", k);
        g_errors++;
        return 0;
    }
    return (TickType_t)g_rel[k];
}

int produce(int k)
{
    TickType_t now = xTaskGetTickCount();

    if (k < 0 || k >= g_n || k != g_np) {
        printf("ERROR: produce(%d) out of order\n", k);
        g_errors++;
        return 0;
    }
    if (now < (TickType_t)g_rel[k]) {
        printf("ERROR: item %d produced before its release tick\n", k);
        g_errors++;
    }
    if (now > (TickType_t)g_rel[k]) {
        unsigned w = (unsigned)(now - (TickType_t)g_rel[k]);
        printf("[t=%u] P put %d (waited %u)\n", (unsigned)now, g_val[k], w);
        if (w > g_max_wait) g_max_wait = w;
    } else {
        printf("[t=%u] P put %d\n", (unsigned)now, g_val[k]);
    }
    g_produced[g_np++] = g_val[k];
    return g_val[k];
}

int stage_a(int v)
{
    printf("[t=%u] A %d\n", (unsigned)xTaskGetTickCount(), v);
    if (g_na >= g_np || g_produced[g_na] != v) {
        printf("ERROR: stage A expected item #%d (%d)\n", g_na, g_na < g_np ? g_produced[g_na] : -1);
        g_errors++;
    }
    if (g_na < MAXN) g_aout[g_na] = v + 1;
    g_na++;
    vSimBusyWork(g_ca);
    return v + 1;
}

void stage_b(int v)
{
    printf("[t=%u] B %d\n", (unsigned)xTaskGetTickCount(), v);
    if (g_nb >= g_na || g_nb >= MAXN || g_aout[g_nb] != v) {
        printf("ERROR: stage B expected result #%d (%d)\n", g_nb, (g_nb < g_na && g_nb < MAXN) ? g_aout[g_nb] : -1);
        g_errors++;
    }
    g_nb++;
    vSimBusyWork(g_cb);
}

/* notifications only */
#define xQueueGenericCreate(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueGenericCreateStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateCountingSemaphore(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateCountingSemaphoreStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateMutex(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateMutexStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xEventGroupCreate(...) event_groups_are_disabled_in_this_exercise
#define xEventGroupCreateStatic(...) event_groups_are_disabled_in_this_exercise
#define xStreamBufferGenericCreate(...) stream_buffers_are_disabled_in_this_exercise
#define xStreamBufferGenericCreateStatic(...) stream_buffers_are_disabled_in_this_exercise

/*USER_CODE*/

#undef xQueueGenericCreate
#undef xQueueGenericCreateStatic
#undef xQueueCreateCountingSemaphore
#undef xQueueCreateCountingSemaphoreStatic
#undef xQueueCreateMutex
#undef xQueueCreateMutexStatic
#undef xEventGroupCreate
#undef xEventGroupCreateStatic
#undef xStreamBufferGenericCreate
#undef xStreamBufferGenericCreateStatic

int main(void)
{
    unsigned ca, cb, dur;
    int i;

    if (scanf("%u %u %u", &ca, &cb, &dur) != 3) return 1;
    if (scanf("%d", &g_n) != 1 || g_n < 1 || g_n > MAXN) return 1;
    for (i = 0; i < g_n; i++)
        if (scanf("%u %d", &g_rel[i], &g_val[i]) != 2) return 1;
    g_ca = (TickType_t)ca;
    g_cb = (TickType_t)cb;

    app_start(g_n);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("produced=%d a=%d b=%d max_wait=%u\n", g_np, g_na, g_nb, g_max_wait);
    if (g_errors == 0 && g_np == g_n && g_na == g_n && g_nb == g_n) printf("PIPELINE OK\n");
    return 0;
}
@@@ sample_input
3 5 40
3
1 10
2 20
3 30
@@@ sample_output
[t=1] P put 10
[t=1] A 10
[t=2] P put 20
[t=4] B 11
[t=9] P put 30 (waited 6)
[t=9] A 20
[t=12] B 21
[t=17] A 30
[t=20] B 31
produced=3 a=3 b=3 max_wait=6
PIPELINE OK
@@@ sample_input
1 1 20
2
5 1
10 2
@@@ sample_output
[t=5] P put 1
[t=5] A 1
[t=6] B 2
[t=10] P put 2
[t=10] A 2
[t=11] B 3
produced=2 a=2 b=2 max_wait=0
PIPELINE OK
@@@ hidden_input
2 2 30
1
1 0
@@@ hidden_output
[t=1] P put 0
[t=1] A 0
[t=3] B 1
produced=1 a=1 b=1 max_wait=0
PIPELINE OK
@@@ hidden_input
1 10 200
6
1 100
1 200
1 300
1 400
1 500
1 600
@@@ hidden_output
[t=1] P put 100
[t=1] P put 200
[t=1] A 100
[t=2] B 101
[t=12] P put 300 (waited 11)
[t=12] A 200
[t=13] B 201
[t=23] P put 400 (waited 22)
[t=23] A 300
[t=24] B 301
[t=34] P put 500 (waited 33)
[t=34] A 400
[t=35] B 401
[t=45] P put 600 (waited 44)
[t=45] A 500
[t=46] B 501
[t=56] A 600
[t=57] B 601
produced=6 a=6 b=6 max_wait=44
PIPELINE OK

@@@ hidden_input
10 1 300
5
1 -5
2 -4
3 -3
4 -2
5 -1
@@@ hidden_output
[t=1] P put -5
[t=1] A -5
[t=2] P put -4
[t=11] B -4
[t=12] P put -3 (waited 9)
[t=12] A -4
[t=22] B -3
[t=23] P put -2 (waited 19)
[t=23] A -3
[t=33] B -2
[t=34] P put -1 (waited 29)
[t=34] A -2
[t=44] B -1
[t=45] A -1
[t=55] B 0
produced=5 a=5 b=5 max_wait=29
PIPELINE OK

@@@ hidden_input
4 4 500
8
10 1
14 2
18 3
22 4
26 5
30 6
34 7
38 8
@@@ hidden_output
[t=10] P put 1
[t=10] A 1
[t=14] P put 2
[t=14] B 2
[t=18] P put 3
[t=18] A 2
[t=22] B 3
[t=26] P put 4 (waited 4)
[t=26] A 3
[t=30] B 4
[t=34] P put 5 (waited 8)
[t=34] A 4
[t=38] B 5
[t=42] P put 6 (waited 12)
[t=42] A 5
[t=46] B 6
[t=50] P put 7 (waited 16)
[t=50] A 6
[t=54] B 7
[t=58] P put 8 (waited 20)
[t=58] A 7
[t=62] B 8
[t=66] A 8
[t=70] B 9
produced=8 a=8 b=8 max_wait=20
PIPELINE OK

@@@ hidden_input
5 3 2000
10
1 1
1 2
1 3
100 4
100 5
100 6
100 7
500 8
501 9
1000 10
@@@ hidden_output
[t=1] P put 1
[t=1] P put 2
[t=1] A 1
[t=6] B 2
[t=9] P put 3 (waited 8)
[t=9] A 2
[t=14] B 3
[t=17] A 3
[t=22] B 4
[t=100] P put 4
[t=100] P put 5
[t=100] A 4
[t=105] B 5
[t=108] P put 6 (waited 8)
[t=108] A 5
[t=113] B 6
[t=116] P put 7 (waited 16)
[t=116] A 6
[t=121] B 7
[t=124] A 7
[t=129] B 8
[t=500] P put 8
[t=500] A 8
[t=501] P put 9
[t=505] B 9
[t=508] A 9
[t=513] B 10
[t=1000] P put 10
[t=1000] A 10
[t=1005] B 11
produced=10 a=10 b=10 max_wait=16
PIPELINE OK

@@@ hint
"Slot free" is a token: the downstream stage gives it (`xTaskNotifyGiveIndexed(up, IDX_FREE)`) once at start-up and once after each copy-out. The upstream stage takes it before every write (`ulTaskNotifyTakeIndexed(IDX_FREE, pdTRUE, portMAX_DELAY)`). "Data ready" works the same way in the other direction, on `IDX_DATA`.
@@@ hint
Order inside a stage: take DATA -> copy the slot to a local -> give FREE upstream -> process -> take FREE from downstream -> write the next slot -> give DATA downstream. Giving FREE only after processing still works, but it removes the overlap and changes the timing. Never `vTaskDelete()` the producer: A's last "slot free" would notify a deleted task.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"

TickType_t release_tick(int k);
int  produce(int k);
int  stage_a(int v);
void stage_b(int v);

#define IDX_DATA 0      /* "your input slot is full"  */
#define IDX_FREE 1      /* "your output slot is free" */

static TaskHandle_t p_handle, a_handle, b_handle;
static int slot1, slot2;            /* P -> A, A -> B */
static int total_items;

static void producer_task(void *pv)
{
    int k;

    (void)pv;
    for (k = 0; k < total_items; k++) {
        TickType_t rel = release_tick(k), now = xTaskGetTickCount();

        if (rel > now)
            vTaskDelay(rel - now);
        (void)ulTaskNotifyTakeIndexed(IDX_FREE, pdTRUE, portMAX_DELAY);   /* backpressure */
        slot1 = produce(k);
        xTaskNotifyGiveIndexed(a_handle, IDX_DATA);
    }
    vTaskSuspend(NULL);   /* stay alive: A still gives us "slot free" */
}

static void stage_a_task(void *pv)
{
    (void)pv;
    xTaskNotifyGiveIndexed(p_handle, IDX_FREE);          /* slot 1 starts empty */
    for (;;) {
        int v, r;

        (void)ulTaskNotifyTakeIndexed(IDX_DATA, pdTRUE, portMAX_DELAY);
        v = slot1;
        xTaskNotifyGiveIndexed(p_handle, IDX_FREE);      /* copied out: P may refill now */
        r = stage_a(v);
        (void)ulTaskNotifyTakeIndexed(IDX_FREE, pdTRUE, portMAX_DELAY);   /* slot 2 free? */
        slot2 = r;
        xTaskNotifyGiveIndexed(b_handle, IDX_DATA);
    }
}

static void stage_b_task(void *pv)
{
    (void)pv;
    xTaskNotifyGiveIndexed(a_handle, IDX_FREE);          /* slot 2 starts empty */
    for (;;) {
        int v;

        (void)ulTaskNotifyTakeIndexed(IDX_DATA, pdTRUE, portMAX_DELAY);
        v = slot2;
        xTaskNotifyGiveIndexed(a_handle, IDX_FREE);
        stage_b(v);
    }
}

void app_start(int n_items)
{
    total_items = n_items;
    /* create all three before the scheduler starts, so every handle is valid when used */
    xTaskCreate(producer_task, "P", configMINIMAL_STACK_SIZE, NULL, 4, &p_handle);
    xTaskCreate(stage_a_task,  "A", configMINIMAL_STACK_SIZE, NULL, 2, &a_handle);
    xTaskCreate(stage_b_task,  "B", configMINIMAL_STACK_SIZE, NULL, 3, &b_handle);
}
@@@ explanation_md
**Approach.** Each single-item slot is guarded by **two binary handshakes** (the classic "full/empty" pair, built here from task notifications):
- *data ready* (downstream's index 0): given after writing the slot, taken before reading it;
- *slot free* (upstream's index 1): given after copying the slot out, taken before writing it.

The free token starts at 1 (the downstream stage gives it once at start-up). So the writer can never be more than one item ahead of the reader. That is backpressure without any buffer memory. Two indexes are needed because a stage waits for both kinds of signal from different partners: with one index, A could take B's "slot free" while waiting for P's "data ready".

Copy-then-free gives double buffering: P can refill slot 1 while A is still filtering the previous item. With the fixed priorities (P 4 > B 3 > A 2), every give to a waiting higher-priority task preempts the giver at once. That is why `P put 30` is printed at t=9 *before* `A 20` in the example.

**Complexity.** Per item: 4 notifications (each O(1), no heap, no copy except one `int` per slot). RAM: 2 ints plus 2 notification slots per task, against two queues of control block + storage. Throughput is bounded by the slowest stage, here roughly max(costA, costB) per item at steady state. Worst-case producer wait grows with the backlog. `max_wait` shows how far backpressure pushes the producer behind its release schedule.

**Common mistakes**
- No "slot free" handshake: P overwrites slot 1 before A copies it out (`ERROR: stage A expected ...`, a lost item).
- Using index 0 for both directions: a stage consumes the wrong partner's signal.
- Forgetting the initial "slot free" token: the pipeline deadlocks at the first item.
- Freeing the slot only after processing: correct data but no overlap, so lower throughput (different timing).
- `vTaskDelete(NULL)` in the producer: A's last `xTaskNotifyGiveIndexed(p_handle, ...)` touches a deleted TCB (use after free).
- Creating a task whose handle another task needs **after** the scheduler started: the first notification may use a NULL handle.

**Interview follow-ups**
- How would you extend each slot to a ring of N items, and which notification semantics would you use then (counting give/take)?
- When is a stream buffer or message buffer the better tool for a single-writer/single-reader pipeline?
- What happens to latency and throughput if A gets the highest priority instead of P? Which priority order minimises end-to-end latency?
- How would you shut the pipeline down cleanly (poison item, abort delay, notification on index 2)?
