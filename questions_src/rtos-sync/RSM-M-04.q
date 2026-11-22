@@@ meta
id: RSM-M-04
topic: Semaphores & Mutexes
difficulty: Medium
type: FUNCTION
title: Readers-Preference Reader-Writer Lock From FreeRTOS Semaphores
tags: freertos, reader-writer-lock, mutex, binary-semaphore, calibration-data, embedded, asked-in-automotive
@@@ statement_md
An engine ECU keeps its calibration tables in external flash. Many tasks **read** the tables at the same time, and the calibration service occasionally **writes** a new table set, which needs exclusive access. A single mutex would serialise the readers for no reason. Build a **reader-writer lock** from FreeRTOS primitives.

```c
void rw_init(void);          /* called before the scheduler starts */
void rw_read_lock(void);
void rw_read_unlock(void);
void rw_write_lock(void);
void rw_write_unlock(void);
```

Policy (**readers preference**):
1. Any number of readers may be inside together.
2. A writer is alone inside: no reader and no other writer.
3. A reader that arrives while **no writer is inside** enters at once, even if writers are waiting.
4. When the lock becomes free for a writer (last reader leaves, or a writer leaves), the highest-priority waiting writer enters.
5. Tasks that are allowed in at the same tick enter in priority order (highest first).
6. All waits are forever (no timeouts).

Note that the task that releases the "room" for writers (the last reader leaving) is usually **not** the task that reserved it (the first reader). A FreeRTOS mutex must be given back by the task that took it, otherwise `configASSERT` fails.

**How it is tested.** The harness creates the reader and writer tasks. Each one waits `start` ticks, then does `count` accesses with `vTaskDelay(gap)` between two accesses. An access is: lock, print `[t=<tick>] <name> enter (readers <k>)` or `[t=<tick>] <name> enter (writer)`, `vTaskDelay(hold)` (the flash access sleeps), print `[t=<tick>] <name> leave`, unlock. `k` counts the readers inside at that moment, including this one. The harness checks the rules and prints the largest number of readers seen inside together and `RESULT: OK`, `RESULT: VIOLATION` (a reader together with a writer, or two writers) or `RESULT: DEADLOCK` (a task did not finish by tick `D`). The tests never have readers **and** writers waiting at the moment a writer leaves (that order is implementation-defined).

**Input**
```
<n>
<R|W> <name> <priority> <start> <hold> <count> <gap>     (n lines)
<D>
```

**Example 1**
```
Input:
4
R R1 2 1 10 1 1
R R2 3 3 4 1 1
W W 4 5 3 1 1
R R3 1 7 2 1 1
60

Output:
[t=1] R1 enter (readers 1)
[t=3] R2 enter (readers 2)
[t=7] R2 leave
[t=7] R3 enter (readers 2)
[t=9] R3 leave
[t=11] R1 leave
[t=11] W enter (writer)
[t=14] W leave
max readers inside: 2
RESULT: OK
```
W asks at t=5 and must wait for the readers. R3 arrives at t=7 while W is waiting, but no writer is inside, so R3 enters (rule 3). W enters at t=11 when the last reader, R1, leaves.

**Example 2**
```
Input:
3
W W1 2 1 5 1 1
R R1 3 2 3 1 1
R R2 4 3 3 1 1
40

Output:
[t=1] W1 enter (writer)
[t=6] W1 leave
[t=6] R2 enter (readers 1)
[t=6] R1 enter (readers 2)
[t=9] R2 leave
[t=9] R1 leave
max readers inside: 2
RESULT: OK
```
R1 and R2 wait for W1. When it leaves at t=6, both readers enter, R2 first because of its higher priority (rule 5).
@@@ constraints_md
- 1 <= n <= 6, priorities different and in 1..6.
- 1 <= start, hold, gap <= 50, 1 <= count <= 5, D <= 2000 (long enough for every access).
- Simulated time: 1 tick = 1 ms.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

void rw_init(void)
{
    /* TODO: create the kernel objects you need */
}

void rw_read_lock(void)
{
    /* TODO */
}

void rw_read_unlock(void)
{
    /* TODO */
}

void rw_write_lock(void)
{
    /* TODO */
}

void rw_write_unlock(void)
{
    /* TODO */
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "sim.h"

/*USER_CODE*/

typedef struct {
    char role;
    char name[8];
    TickType_t start, hold, gap;
    int count;
} Client;

static Client g_clients[6];
static int g_readers, g_writers, g_max_readers, g_violation, g_finished;

static void client_task(void *p)
{
    const Client *c = (const Client *)p;
    int k;

    vTaskDelay(c->start);
    for (k = 1; k <= c->count; k++) {
        if (c->role == 'R') {
            rw_read_lock();
            g_readers++;
            if (g_writers > 0) g_violation++;
            if (g_readers > g_max_readers) g_max_readers = g_readers;
            printf("[t=%u] %s enter (readers %d)\n", (unsigned)xTaskGetTickCount(), c->name, g_readers);
            vTaskDelay(c->hold);
            printf("[t=%u] %s leave\n", (unsigned)xTaskGetTickCount(), c->name);
            g_readers--;
            rw_read_unlock();
        } else {
            rw_write_lock();
            g_writers++;
            if (g_writers > 1 || g_readers > 0) g_violation++;
            printf("[t=%u] %s enter (writer)\n", (unsigned)xTaskGetTickCount(), c->name);
            vTaskDelay(c->hold);
            printf("[t=%u] %s leave\n", (unsigned)xTaskGetTickCount(), c->name);
            g_writers--;
            rw_write_unlock();
        }
        if (k < c->count) vTaskDelay(c->gap);
    }
    g_finished++;
    vTaskDelete(NULL);
}

int main(void)
{
    int n, i;
    unsigned prio, start, hold, count, gap, d;

    if (scanf("%d", &n) != 1 || n < 1 || n > 6) return 1;
    rw_init();
    for (i = 0; i < n; i++) {
        Client *c = &g_clients[i];
        if (scanf(" %c %7s %u %u %u %u %u", &c->role, c->name, &prio, &start, &hold, &count, &gap) != 7) return 1;
        c->start = (TickType_t)start;
        c->hold = (TickType_t)hold;
        c->count = (int)count;
        c->gap = (TickType_t)gap;
        xTaskCreate(client_task, c->name, configMINIMAL_STACK_SIZE, c, (UBaseType_t)prio, NULL);
    }
    if (scanf("%u", &d) != 1) return 1;

    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();

    printf("max readers inside: %d\n", g_max_readers);
    if (g_violation) printf("RESULT: VIOLATION\n");
    else if (g_finished != n) printf("RESULT: DEADLOCK\n");
    else printf("RESULT: OK\n");
    return 0;
}
@@@ sample_input
4
R R1 2 1 10 1 1
R R2 3 3 4 1 1
W W 4 5 3 1 1
R R3 1 7 2 1 1
60
@@@ sample_output
[t=1] R1 enter (readers 1)
[t=3] R2 enter (readers 2)
[t=7] R2 leave
[t=7] R3 enter (readers 2)
[t=9] R3 leave
[t=11] R1 leave
[t=11] W enter (writer)
[t=14] W leave
max readers inside: 2
RESULT: OK
@@@ sample_input
3
W W1 2 1 5 1 1
R R1 3 2 3 1 1
R R2 4 3 3 1 1
40
@@@ sample_output
[t=1] W1 enter (writer)
[t=6] W1 leave
[t=6] R2 enter (readers 1)
[t=6] R1 enter (readers 2)
[t=9] R2 leave
[t=9] R1 leave
max readers inside: 2
RESULT: OK
@@@ hidden_input
4
R A 1 1 10 1 1
R B 2 1 10 1 1
R C 3 1 10 1 1
R D 4 1 10 1 1
30
@@@ hidden_output
[t=1] D enter (readers 1)
[t=1] C enter (readers 2)
[t=1] B enter (readers 3)
[t=1] A enter (readers 4)
[t=11] D leave
[t=11] C leave
[t=11] B leave
[t=11] A leave
max readers inside: 4
RESULT: OK
@@@ hidden_input
3
W X 1 1 4 2 1
W Y 2 2 4 2 1
W Z 3 3 4 1 1
80
@@@ hidden_output
[t=1] X enter (writer)
[t=5] X leave
[t=5] Z enter (writer)
[t=9] Z leave
[t=9] Y enter (writer)
[t=13] Y leave
[t=13] X enter (writer)
[t=17] X leave
[t=17] Y enter (writer)
[t=21] Y leave
max readers inside: 0
RESULT: OK

@@@ hidden_input
5
R R1 1 1 6 3 2
R R2 2 4 6 2 3
W W1 5 3 2 2 9
R R3 3 10 1 2 1
W W2 4 30 3 1 1
200
@@@ hidden_output
[t=1] R1 enter (readers 1)
[t=4] R2 enter (readers 2)
[t=7] R1 leave
[t=9] R1 enter (readers 2)
[t=10] R3 enter (readers 3)
[t=10] R2 leave
[t=11] R3 leave
[t=12] R3 enter (readers 2)
[t=13] R3 leave
[t=13] R2 enter (readers 2)
[t=15] R1 leave
[t=17] R1 enter (readers 2)
[t=19] R2 leave
[t=23] R1 leave
[t=23] W1 enter (writer)
[t=25] W1 leave
[t=30] W2 enter (writer)
[t=33] W2 leave
[t=34] W1 enter (writer)
[t=36] W1 leave
max readers inside: 3
RESULT: OK

@@@ hidden_input
2
R Rd 6 1 5 4 1
W Wr 1 2 2 2 1
100
@@@ hidden_output
[t=1] Rd enter (readers 1)
[t=6] Rd leave
[t=6] Wr enter (writer)
[t=8] Wr leave
[t=8] Rd enter (readers 1)
[t=13] Rd leave
[t=13] Wr enter (writer)
[t=15] Wr leave
[t=15] Rd enter (readers 1)
[t=20] Rd leave
[t=21] Rd enter (readers 1)
[t=26] Rd leave
max readers inside: 1
RESULT: OK

@@@ hidden_input
6
W W1 6 1 4 1 1
R A 1 2 6 1 1
R B 2 3 6 1 1
R C 3 4 6 1 1
R D 4 5 3 1 1
W W2 5 20 2 1 1
100
@@@ hidden_output
[t=1] W1 enter (writer)
[t=5] W1 leave
[t=5] D enter (readers 1)
[t=5] C enter (readers 2)
[t=5] B enter (readers 3)
[t=5] A enter (readers 4)
[t=8] D leave
[t=11] C leave
[t=11] B leave
[t=11] A leave
[t=20] W2 enter (writer)
[t=22] W2 leave
max readers inside: 4
RESULT: OK

@@@ hint
Use two objects: a **mutex** that protects an `int readers` counter, and a **binary semaphore** `room` (created, then given once) that is held by "the writer" or by "the group of readers". A writer simply takes and gives `room`.
@@@ hint
`read_lock`: take the counter mutex; `if (++readers == 1) take(room);` give the counter mutex. `read_unlock`: take the counter mutex; `if (--readers == 0) give(room);` give the counter mutex. `room` must be a binary semaphore, not a mutex: the first reader takes it but the last reader (often another task) gives it.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

static SemaphoreHandle_t s_count_mutex;   /* protects s_readers */
static SemaphoreHandle_t s_room;          /* binary semaphore: free when nobody is inside */
static int s_readers;

void rw_init(void)
{
    s_count_mutex = xSemaphoreCreateMutex();
    s_room = xSemaphoreCreateBinary();
    xSemaphoreGive(s_room);               /* binary semaphores are created empty */
    s_readers = 0;
}

void rw_read_lock(void)
{
    xSemaphoreTake(s_count_mutex, portMAX_DELAY);
    if (++s_readers == 1) {
        xSemaphoreTake(s_room, portMAX_DELAY);   /* first reader locks writers out (waits if a writer is inside) */
    }
    xSemaphoreGive(s_count_mutex);
}

void rw_read_unlock(void)
{
    xSemaphoreTake(s_count_mutex, portMAX_DELAY);
    if (--s_readers == 0) {
        xSemaphoreGive(s_room);                  /* last reader lets writers in (may be another task than the first) */
    }
    xSemaphoreGive(s_count_mutex);
}

void rw_write_lock(void)
{
    xSemaphoreTake(s_room, portMAX_DELAY);
}

void rw_write_unlock(void)
{
    xSemaphoreGive(s_room);
}
@@@ explanation_md
**Approach.** The classic "first readers-writers" solution. `room` is a binary semaphore that is free when nobody is inside. A writer takes it for the whole write. Readers share it as a group: the **first** reader takes it (waiting if a writer is inside) and the **last** reader gives it back. A mutex protects the `readers` counter and makes "increment and maybe take room" atomic. While the first reader waits for `room`, it holds the counter mutex, so later readers queue behind it on the mutex. When the writer leaves, they all enter one after the other at the same tick (Example 2). Because a reader enters whenever `readers > 0`, a stream of overlapping readers can starve writers forever. That is the price of readers preference.

`room` cannot be a mutex: a FreeRTOS mutex has an owner and only the owner may give it. In Example 1, R1 takes `room` and R1 also gives it, but swap the hold times and R2 would have to give it, and `xTaskPriorityDisinherit()` asserts.

**Complexity.** Read lock/unlock: O(1) plus a short critical section on the counter mutex. Write lock/unlock: O(1). A writer may wait unboundedly under continuous read load (starvation). RAM: two kernel objects and one `int`.

**Common mistakes**
- Using a mutex for `room` (owner rule): `configASSERT` fails as soon as the last reader is not the first one.
- Forgetting to give the binary semaphore once after `xSemaphoreCreateBinary()`: the first reader or writer blocks forever.
- Updating `readers` without the mutex: two readers can both see `readers == 1` (or both see 0 on the way out) and take or give `room` twice.
- Implementing it with a single mutex: correct, but readers are serialised (max readers inside = 1).
- Not addressing writer starvation in a real system: calibration updates may never be applied.

**Interview follow-ups**
- How would you change it to **writers preference** (a waiting writer blocks new readers)? Which extra semaphore do you need?
- What is the worst-case blocking time of a writer, and how would you bound it?
- Could you use an event group or a counting semaphore with N tokens instead? What are the trade-offs?
- Why might a seqlock or double-buffering be a better fit for calibration data on a small MCU?
