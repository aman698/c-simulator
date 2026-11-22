@@@ meta
id: RSM-M-03
topic: Semaphores & Mutexes
difficulty: Medium
type: FUNCTION
title: Bounded Buffer From Two Counting Semaphores and a Mutex
tags: freertos, counting-semaphore, mutex, producer-consumer, bounded-buffer, embedded
@@@ statement_md
Build the classic **bounded buffer** (producer/consumer ring) without FreeRTOS queues: two counting semaphores count the free and the filled slots, and a mutex protects the ring itself. This is what `xQueueSend`/`xQueueReceive` do internally, and a favourite interview whiteboard question.

The ring storage is provided by the hidden harness. Copying an element in or out takes CPU time, so the copy must be protected.

```c
/* provided by the hidden harness */
void ring_store(int value);   /* prints "[t=<tick>] <task> stores <value>", 1 tick of CPU, appends to the ring */
int  ring_load(void);         /* prints "[t=<tick>] <task> loads <value>",  1 tick of CPU, removes the oldest */

/* you write these */
void bb_init(int capacity);   /* called before the scheduler starts; ring capacity is 1..8 */
void bb_put(int value);       /* block while the buffer is full, then ring_store(value) */
int  bb_get(void);            /* block while the buffer is empty, then return ring_load() */
```

Use exactly this design:
- `slots_free`: counting semaphore, max = initial = `capacity`;
- `slots_used`: counting semaphore, max = `capacity`, initial = 0;
- `ring_mutex`: a mutex around every `ring_store()` / `ring_load()` call.

`bb_put` waits (forever) for a free slot **before** it locks the mutex, and signals a used slot after unlocking; `bb_get` is symmetric. Queues, stream/message buffers, event groups and task notifications are not allowed (they do not compile in this exercise).

**How it is tested.** The harness creates the producer and consumer tasks (with the given priorities) and calls `bb_init()`. A producer waits `start` ticks, then puts `count` values with `vTaskDelay(gap)` between two puts. The `j`-th producer of the input puts `j*100+1, j*100+2, ...`. A consumer waits `start` ticks, then gets `count` values with `vTaskDelay(proc)` between two gets. The run goes up to and including tick `D`. The ring reports `OVERFLOW` (store into a full ring), `UNDERFLOW` (load from an empty ring) and `RACE` (two copies at the same time). The summary prints the totals, the highest fill level, and `RESULT: OK` or the first error; `RESULT: DEADLOCK` if a task did not finish.

Timing rules: `ring_store()`/`ring_load()` print first, then take 1 tick of CPU. A higher-priority task that wakes during a copy preempts it, and if it needs the mutex it blocks and the holder inherits its priority. A give wakes the highest-priority waiting task, which runs at once if it has a higher priority than the giver.

**Input**
```
<capacity> <n>
P <name> <priority> <start> <count> <gap>      (producer)
C <name> <priority> <start> <count> <proc>     (consumer)   n lines in total, any order
<D>
```

**Example**
```
Input:
2 2
P P 2 1 4 1
C C 1 1 4 3
40

Output:
[t=1] P stores 101
[t=2] C loads 101
[t=3] P stores 102
[t=5] P stores 103
[t=7] C loads 102
[t=8] P stores 104
[t=12] C loads 103
[t=16] C loads 104
produced 4, consumed 4, max fill 2 of 2
RESULT: OK
```
At t=3 P wakes up during C's load and blocks on the mutex, then stores right after C unlocks. At t=7 the ring is full (102, 103): P blocks on `slots_free` until C has loaded 102 and given a free slot, so 104 is stored at t=8.
@@@ constraints_md
- 1 <= capacity <= 8, 2 <= n <= 5 (at least one producer and one consumer), priorities different and in 1..6.
- 1 <= start, gap, proc <= 50, 1 <= count <= 10; total produced == total consumed; D <= 2000.
- Simulated time: 1 tick = 1 ms.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

void ring_store(int value);
int  ring_load(void);

static SemaphoreHandle_t slots_free, slots_used, ring_mutex;

void bb_init(int capacity)
{
    /* TODO: create the two counting semaphores and the mutex */
    (void)capacity;
    (void)slots_free;
    (void)slots_used;
    (void)ring_mutex;
}

void bb_put(int value)
{
    /* TODO: wait for a free slot, lock, store, unlock, signal a used slot */
    ring_store(value);
}

int bb_get(void)
{
    /* TODO: wait for a used slot, lock, load, unlock, signal a free slot */
    return ring_load();
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "sim.h"

void bb_init(int capacity);
void bb_put(int value);
int  bb_get(void);

static int g_ring[8];
static int g_cap, g_head, g_fill, g_max_fill;
static int g_busy, g_race, g_overflow, g_underflow;
static int g_produced, g_consumed, g_finished;

void ring_store(int value)
{
    printf("[t=%u] %s stores %d\n", (unsigned)xTaskGetTickCount(), pcTaskGetName(NULL), value);
    if (g_busy++) g_race++;
    vSimBusyWork(1);
    if (g_fill == g_cap) {
        g_overflow++;
    } else {
        g_ring[(g_head + g_fill) % g_cap] = value;
        g_fill++;
        if (g_fill > g_max_fill) g_max_fill = g_fill;
    }
    g_busy--;
}

int ring_load(void)
{
    int v = -1;

    if (g_fill > 0) v = g_ring[g_head];
    printf("[t=%u] %s loads %d\n", (unsigned)xTaskGetTickCount(), pcTaskGetName(NULL), v);
    if (g_busy++) g_race++;
    vSimBusyWork(1);
    if (g_fill == 0) {
        g_underflow++;
    } else {
        v = g_ring[g_head];
        g_head = (g_head + 1) % g_cap;
        g_fill--;
    }
    g_busy--;
    return v;
}

#undef xQueueCreate
#undef xQueueCreateStatic
#undef xStreamBufferCreate
#undef xMessageBufferCreate
#define xQueueCreate(a, b) xQueueCreate_is_not_allowed_here()
#define xQueueCreateStatic(a, b, c, d) xQueueCreateStatic_is_not_allowed_here()
#define xQueueGenericCreate(...) xQueueGenericCreate_is_not_allowed_here()
#define xQueueGenericCreateStatic(...) xQueueGenericCreateStatic_is_not_allowed_here()
#define xStreamBufferCreate(a, b) xStreamBufferCreate_is_not_allowed_here()
#define xMessageBufferCreate(a) xMessageBufferCreate_is_not_allowed_here()
#define xStreamBufferGenericCreate(...) xStreamBufferGenericCreate_is_not_allowed_here()
#define xEventGroupCreate() xEventGroupCreate_is_not_allowed_here()
#define xTaskGenericNotify(...) task_notifications_are_not_allowed_here()
#define ulTaskGenericNotifyTake(...) task_notifications_are_not_allowed_here()
#define xTaskGenericNotifyWait(...) task_notifications_are_not_allowed_here()

/*USER_CODE*/

#undef xQueueCreate
#undef xQueueCreateStatic
#undef xQueueGenericCreate
#undef xQueueGenericCreateStatic
#undef xStreamBufferCreate
#undef xMessageBufferCreate
#undef xStreamBufferGenericCreate
#undef xEventGroupCreate
#undef xTaskGenericNotify
#undef ulTaskGenericNotifyTake
#undef xTaskGenericNotifyWait

typedef struct {
    char role;
    char name[8];
    TickType_t start, pause;
    int count;
    int base;
} Actor;

static Actor g_actors[5];

static void producer_task(void *p)
{
    const Actor *a = (const Actor *)p;
    int k;

    vTaskDelay(a->start);
    for (k = 1; k <= a->count; k++) {
        bb_put(a->base + k);
        g_produced++;
        if (k < a->count) vTaskDelay(a->pause);
    }
    g_finished++;
    vTaskDelete(NULL);
}

static void consumer_task(void *p)
{
    const Actor *a = (const Actor *)p;
    int k;

    vTaskDelay(a->start);
    for (k = 1; k <= a->count; k++) {
        (void)bb_get();
        g_consumed++;
        if (k < a->count) vTaskDelay(a->pause);
    }
    g_finished++;
    vTaskDelete(NULL);
}

int main(void)
{
    int n, i, nprod = 0;
    unsigned prio, start, count, pause, d;

    if (scanf("%d %d", &g_cap, &n) != 2 || g_cap < 1 || g_cap > 8 || n < 2 || n > 5) return 1;
    bb_init(g_cap);
    for (i = 0; i < n; i++) {
        Actor *a = &g_actors[i];
        if (scanf(" %c %7s %u %u %u %u", &a->role, a->name, &prio, &start, &count, &pause) != 6) return 1;
        a->start = (TickType_t)start;
        a->count = (int)count;
        a->pause = (TickType_t)pause;
        if (a->role == 'P') a->base = 100 * ++nprod;
        xTaskCreate(a->role == 'P' ? producer_task : consumer_task, a->name,
                    configMINIMAL_STACK_SIZE, a, (UBaseType_t)prio, NULL);
    }
    if (scanf("%u", &d) != 1) return 1;

    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();

    printf("produced %d, consumed %d, max fill %d of %d\n", g_produced, g_consumed, g_max_fill, g_cap);
    if (g_overflow) printf("RESULT: OVERFLOW\n");
    else if (g_underflow) printf("RESULT: UNDERFLOW\n");
    else if (g_race) printf("RESULT: RACE\n");
    else if (g_finished != n) printf("RESULT: DEADLOCK\n");
    else printf("RESULT: OK\n");
    return 0;
}
@@@ sample_input
2 2
P P 2 1 4 1
C C 1 1 4 3
40
@@@ sample_output
[t=1] P stores 101
[t=2] C loads 101
[t=3] P stores 102
[t=5] P stores 103
[t=7] C loads 102
[t=8] P stores 104
[t=12] C loads 103
[t=16] C loads 104
produced 4, consumed 4, max fill 2 of 2
RESULT: OK
@@@ sample_input
1 3
P P1 3 1 2 5
P P2 2 1 2 5
C C 4 1 4 1
40
@@@ sample_output
[t=1] P1 stores 101
[t=2] C loads 101
[t=3] P2 stores 201
[t=4] C loads 201
[t=8] P1 stores 102
[t=9] C loads 102
[t=10] P2 stores 202
[t=11] C loads 202
produced 4, consumed 4, max fill 1 of 1
RESULT: OK
@@@ hidden_input
3 2
C C 5 1 3 1
P P 1 10 3 1
40
@@@ hidden_output
[t=10] P stores 101
[t=11] C loads 101
[t=13] P stores 102
[t=14] C loads 102
[t=16] P stores 103
[t=17] C loads 103
produced 3, consumed 3, max fill 1 of 3
RESULT: OK
@@@ hidden_input
4 2
P P 6 1 10 1
C C 1 30 10 1
200
@@@ hidden_output
[t=1] P stores 101
[t=3] P stores 102
[t=5] P stores 103
[t=7] P stores 104
[t=30] C loads 101
[t=31] P stores 105
[t=33] C loads 102
[t=34] P stores 106
[t=36] C loads 103
[t=37] P stores 107
[t=39] C loads 104
[t=40] P stores 108
[t=42] C loads 105
[t=43] P stores 109
[t=45] C loads 106
[t=46] P stores 110
[t=48] C loads 107
[t=50] C loads 108
[t=52] C loads 109
[t=54] C loads 110
produced 10, consumed 10, max fill 4 of 4
RESULT: OK

@@@ hidden_input
2 4
P A 5 1 3 2
P B 4 1 3 3
C X 2 2 3 1
C Y 1 2 3 4
200
@@@ hidden_output
[t=1] A stores 101
[t=2] B stores 201
[t=3] X loads 101
[t=4] A stores 102
[t=5] Y loads 201
[t=6] X loads 102
[t=7] A stores 103
[t=8] B stores 202
[t=9] X loads 103
[t=12] B stores 203
[t=14] Y loads 202
[t=19] Y loads 203
produced 6, consumed 6, max fill 2 of 2
RESULT: OK

@@@ hidden_input
8 3
P F 3 2 6 1
C S 2 1 5 7
C T 1 3 1 1
300
@@@ hidden_output
[t=2] F stores 101
[t=3] S loads 101
[t=4] F stores 102
[t=5] T loads 102
[t=6] F stores 103
[t=8] F stores 104
[t=10] F stores 105
[t=12] F stores 106
[t=13] S loads 103
[t=21] S loads 104
[t=29] S loads 105
[t=37] S loads 106
produced 6, consumed 6, max fill 4 of 8
RESULT: OK

@@@ hidden_input
1 5
C K 6 1 4 1
P A 1 1 1 1
P B 2 1 1 1
P C 3 1 1 1
P D 4 1 1 1
100
@@@ hidden_output
[t=1] D stores 401
[t=2] K loads 401
[t=3] C stores 301
[t=4] K loads 301
[t=5] B stores 201
[t=6] K loads 201
[t=7] A stores 101
[t=8] K loads 101
produced 4, consumed 4, max fill 1 of 1
RESULT: OK

@@@ hint
Three objects: `slots_free = xSemaphoreCreateCounting(cap, cap)`, `slots_used = xSemaphoreCreateCounting(cap, 0)`, `ring_mutex = xSemaphoreCreateMutex()`. The semaphores make tasks **wait** for space or data; the mutex only makes the copy atomic.
@@@ hint
`bb_put`: `take(slots_free); take(ring_mutex); ring_store(v); give(ring_mutex); give(slots_used);`. `bb_get` is the mirror image. Never wait for a slot while holding the mutex: the task that would free the slot needs the mutex first (deadlock).
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

void ring_store(int value);
int  ring_load(void);

static SemaphoreHandle_t slots_free, slots_used, ring_mutex;

void bb_init(int capacity)
{
    slots_free = xSemaphoreCreateCounting((UBaseType_t)capacity, (UBaseType_t)capacity);
    slots_used = xSemaphoreCreateCounting((UBaseType_t)capacity, 0);
    ring_mutex = xSemaphoreCreateMutex();
}

void bb_put(int value)
{
    xSemaphoreTake(slots_free, portMAX_DELAY);   /* wait for space first ... */
    xSemaphoreTake(ring_mutex, portMAX_DELAY);   /* ... then lock only for the copy */
    ring_store(value);
    xSemaphoreGive(ring_mutex);
    xSemaphoreGive(slots_used);                  /* wakes a waiting consumer */
}

int bb_get(void)
{
    int v;

    xSemaphoreTake(slots_used, portMAX_DELAY);
    xSemaphoreTake(ring_mutex, portMAX_DELAY);
    v = ring_load();
    xSemaphoreGive(ring_mutex);
    xSemaphoreGive(slots_free);                  /* wakes a waiting producer */
    return v;
}
@@@ explanation_md
**Approach.** The two counting semaphores track the state of the ring: `slots_free + slots_used` (plus elements being copied) always equals the capacity. A producer first reserves a free slot (`take(slots_free)` blocks while the ring is full), then locks the mutex only for the copy, unlocks, and finally publishes the element with `give(slots_used)`, which wakes the highest-priority waiting consumer. The consumer does the mirror image. The semaphores provide **condition synchronisation** (wait for space/data), the mutex provides **mutual exclusion** (no two copies at the same time). With one producer and one consumer the mutex could even be dropped by giving each side its own index, but with several producers or consumers it is required.

The order of the two takes matters. Taking the mutex first and then waiting for `slots_free` while holding it is a deadlock: the consumer that would free a slot needs the mutex first.

**Complexity.** O(1) per put/get plus O(waiters) for the event-list insertions. RAM: the ring (`capacity` elements) plus three kernel objects (two semaphores, one mutex). A FreeRTOS queue does the same work with one object and one critical section, which is why you normally use `xQueueSend`/`xQueueReceive`.

**Common mistakes**
- Swapping the order (mutex, then slot semaphore): deadlock as soon as the ring is full or empty.
- Creating `slots_used` with an initial count of `capacity` (or `slots_free` with 0): consumers read garbage, producers never start.
- Using one binary semaphore for "not empty": several puts in a row collapse into one signal and a consumer sleeps while data is waiting.
- Giving `slots_used` **before** the copy is complete: a consumer can load a slot that is still being written.
- Holding the mutex while doing slow work on the element (processing it, logging it): copy out quickly, release, then process.

**Interview follow-ups**
- How does a FreeRTOS queue implement the same thing internally (one critical section, `xTasksWaitingToSend`/`xTasksWaitingToReceive` lists)?
- Single-producer/single-consumer lock-free ring: what do you need (`volatile` indices, memory barriers on a multi-core MCU)?
- How would you add a timeout to `bb_put()`, and what must be undone on the timeout path?
- What changes if the producer is an ISR?
