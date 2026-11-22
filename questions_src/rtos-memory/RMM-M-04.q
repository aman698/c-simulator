@@@ meta
id: RMM-M-04
topic: RTOS Memory Management
difficulty: Medium
type: FUNCTION
title: Leak-Free Session Open/Close Verified With Heap Deltas
tags: freertos, memory-leak, vtaskdelete, vqueuedelete, heap-4, resource-cleanup, embedded
@@@ statement_md
A gateway ECU opens a **session** for every diagnostic client. A session owns three heap objects: a context struct, a value queue and a worker task. Sessions come and go thousands of times per drive cycle, so a few leaked bytes per session will eventually exhaust the heap. Write the session manager so that **every byte comes back**, on every path.

```c
#define MAX_SESSIONS  4      /* ids 0 .. MAX_SESSIONS-1 */
#define SESSION_Q_LEN 4      /* values per session queue */

void session_report(int id, uint32_t sum, unsigned count); /* provided: "[t=..] report <id> sum=<sum> n=<count>" */

int session_open(int id);               /* you write these three */
int session_send(int id, uint32_t v);
int session_close(int id);
```

- **`session_open(id)`** allocates the context with `pvPortMalloc()`, creates a queue of `SESSION_Q_LEN` `uint32_t` values with `xQueueCreate()`, and creates a worker task with `xTaskCreate()` (stack `configMINIMAL_STACK_SIZE`, **priority 2**). The worker loops forever: it receives a value (waiting forever) and adds it to the session's `sum` and `count`. Return 0 on success, **-1** if `id` is out of range or already open. Return **-2** if any allocation fails: in that case, release everything this call already obtained, so the heap is exactly as before the call.
- **`session_send(id, v)`** posts `v` to the session queue without waiting. Return 0, **-1** if the session is not open, **-2** if its queue is full.
- **`session_close(id)`** returns -1 if the session is not open. Otherwise it adds the values **still waiting in the queue** to `sum`/`count`, calls `session_report(id, sum, count)`, and releases the worker task, the queue and the context. Then it returns 0. All memory must be back in the heap **when `session_close` returns**.

**How it is tested.** A manager task (**priority 3**) executes timed commands and calls your functions. All commands of one tick run before the workers (priority 2) get the CPU. The manager measures the free heap around every call:

- `O <id>`: prints `[t=..] open <id> -> <ret>`. A successful open records how many bytes the session took. A failed open must not change the heap, otherwise ` LEAK` is appended.
- `S <id> <v>`: prints `[t=..] send <id> <v> -> <ret>`.
- `C <id>`: prints `[t=..] close <id> -> <ret>`. On success it appends `, all freed` if exactly the bytes taken by the open came back, else `, LEAK <n> bytes`.
- `K`: prints `[t=..] check open=<n> heap <ok|LEAK n bytes>`, comparing the heap in use with the sessions that are open.
- `L <bytes>`: from now on, only `<bytes>` of heap are free (another component takes the rest). `U` gives that memory back. Neither prints anything.

The simulation runs for 1000 ticks.

**Input**
```
<n>
<tick> <command>      (n lines, non-decreasing ticks)
```

**Example**
```
Input:
7
1 O 0
1 O 1
1 S 0 5
1 S 0 7
2 S 1 10
3 C 0
3 K

Output:
[t=1] open 0 -> 0
[t=1] open 1 -> 0
[t=1] send 0 5 -> 0
[t=1] send 0 7 -> 0
[t=2] send 1 10 -> 0
[t=3] report 0 sum=12 n=2
[t=3] close 0 -> 0, all freed
[t=3] check open=1 heap ok
```
@@@ constraints_md
- 0 <= n <= 40, 1 <= tick <= 900, ids in -1..9 (out-of-range ids are tested), values < 2^20.
- `L` leaves between 16 and 4000 bytes free; a task needs well over 2000 bytes, a queue and a context much less.
- No polling; no memory may stay allocated after `session_close` returns.
@@@ starter_code
#include <stdint.h>
#include <stddef.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

#define MAX_SESSIONS  4
#define SESSION_Q_LEN 4

void session_report(int id, uint32_t sum, unsigned count);

int session_open(int id)
{
    /* TODO: context (pvPortMalloc), queue, worker task; clean up on failure */
    (void)id;
    return -1;
}

int session_send(int id, uint32_t v)
{
    (void)id; (void)v;
    return -1;
}

int session_close(int id)
{
    /* TODO: drain, report, delete task, delete queue, free context */
    (void)id;
    return -1;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

void session_report(int id, uint32_t sum, unsigned count)
{
    printf("[t=%u] report %d sum=%u n=%u\n", (unsigned)xTaskGetTickCount(), id, (unsigned)sum, count);
}

#define malloc(...) malloc_is_not_allowed_here

/*USER_CODE*/

#undef malloc

#define MAX_CMD 40

static unsigned g_tick[MAX_CMD];
static char g_kind[MAX_CMD];
static int g_a[MAX_CMD];
static unsigned g_b[MAX_CMD];
static int g_n;
static size_t g_cost[10];
static int g_open[10];
static size_t g_baseline;
static void *g_ballast;

static unsigned now(void) { return (unsigned)xTaskGetTickCount(); }

static void manager_task(void *pv)
{
    int i, k, nopen, r;
    size_t before, after, expect;
    (void)pv;

    vPortFree(pvPortMalloc(16));
    g_baseline = xPortGetFreeHeapSize();
    for (i = 0; i < g_n; i++) {
        TickType_t t = xTaskGetTickCount();
        if ((TickType_t)g_tick[i] > t) vTaskDelay((TickType_t)g_tick[i] - t);
        before = xPortGetFreeHeapSize();
        switch (g_kind[i]) {
        case 'O':
            r = session_open(g_a[i]);
            after = xPortGetFreeHeapSize();
            printf("[t=%u] open %d -> %d", now(), g_a[i], r);
            if (r == 0 && g_a[i] >= 0 && g_a[i] < 10) {
                g_open[g_a[i]] = 1;
                g_cost[g_a[i]] = before - after;
            } else if (after != before) {
                printf(" LEAK");
            }
            printf("\n");
            break;
        case 'S':
            r = session_send(g_a[i], (uint32_t)g_b[i]);
            printf("[t=%u] send %d %u -> %d\n", now(), g_a[i], g_b[i], r);
            break;
        case 'C':
            r = session_close(g_a[i]);
            after = xPortGetFreeHeapSize();
            printf("[t=%u] close %d -> %d", now(), g_a[i], r);
            if (r == 0 && g_a[i] >= 0 && g_a[i] < 10 && g_open[g_a[i]]) {
                g_open[g_a[i]] = 0;
                if (after - before == g_cost[g_a[i]]) printf(", all freed");
                else printf(", LEAK %d bytes", (int)g_cost[g_a[i]] - (int)(after - before));
            }
            printf("\n");
            break;
        case 'K':
            nopen = 0;
            expect = 0;
            for (k = 0; k < 10; k++) {
                if (g_open[k]) {
                    nopen++;
                    expect += g_cost[k];
                }
            }
            if (g_ballast != NULL) {
                printf("[t=%u] check open=%d (heap limited)\n", now(), nopen);
            } else if (g_baseline - before == expect) {
                printf("[t=%u] check open=%d heap ok\n", now(), nopen);
            } else {
                printf("[t=%u] check open=%d heap LEAK %d bytes\n", now(), nopen,
                       (int)(g_baseline - before) - (int)expect);
            }
            break;
        case 'L':
            if (g_ballast == NULL && before > (size_t)g_b[i] + 16) {
                g_ballast = pvPortMalloc(before - g_b[i] - 16);
            }
            break;
        case 'U':
            vPortFree(g_ballast);
            g_ballast = NULL;
            break;
        default:
            break;
        }
    }
    for (;;) vTaskDelay(1000);
}

int main(void)
{
    int i;

    if (scanf("%d", &g_n) != 1 || g_n < 0 || g_n > MAX_CMD) return 1;
    for (i = 0; i < g_n; i++) {
        if (scanf("%u %c", &g_tick[i], &g_kind[i]) != 2) return 1;
        if (g_kind[i] == 'O' || g_kind[i] == 'C') {
            if (scanf("%d", &g_a[i]) != 1) return 1;
        } else if (g_kind[i] == 'S') {
            if (scanf("%d %u", &g_a[i], &g_b[i]) != 2) return 1;
        } else if (g_kind[i] == 'L') {
            if (scanf("%u", &g_b[i]) != 1) return 1;
        }
    }
    xTaskCreate(manager_task, "mgr", configMINIMAL_STACK_SIZE * 2, NULL, 3, NULL);
    vSimSetTickLimit(1000);
    vTaskStartScheduler();
    return 0;
}
@@@ sample_input
7
1 O 0
1 O 1
1 S 0 5
1 S 0 7
2 S 1 10
3 C 0
3 K
@@@ sample_output
[t=1] open 0 -> 0
[t=1] open 1 -> 0
[t=1] send 0 5 -> 0
[t=1] send 0 7 -> 0
[t=2] send 1 10 -> 0
[t=3] report 0 sum=12 n=2
[t=3] close 0 -> 0, all freed
[t=3] check open=1 heap ok
@@@ sample_input
13
1 O 3
1 S 3 1
1 S 3 2
1 S 3 3
1 S 3 4
1 S 3 5
1 C 3
1 C 3
1 S 3 9
1 O 4
1 O 3
2 O 3
2 K
@@@ sample_output
[t=1] open 3 -> 0
[t=1] send 3 1 -> 0
[t=1] send 3 2 -> 0
[t=1] send 3 3 -> 0
[t=1] send 3 4 -> 0
[t=1] send 3 5 -> -2
[t=1] report 3 sum=10 n=4
[t=1] close 3 -> 0, all freed
[t=1] close 3 -> -1
[t=1] send 3 9 -> -1
[t=1] open 4 -> -1
[t=1] open 3 -> 0
[t=2] open 3 -> -1
[t=2] check open=1 heap ok
@@@ hidden_input
2
5 C 0
5 K
@@@ hidden_output
[t=5] close 0 -> -1
[t=5] check open=0 heap ok
@@@ hidden_input
9
1 L 1000
1 O 2
1 L 100
2 U
2 L 16
2 O 1
3 U
3 O 1
3 K
@@@ hidden_output
[t=1] open 2 -> -2
[t=2] open 1 -> -2
[t=3] open 1 -> 0
[t=3] check open=1 heap ok
@@@ hidden_input
5
1 L 300
1 O 0
2 U
2 O 0
2 K
@@@ hidden_output
[t=1] open 0 -> -2
[t=2] open 0 -> 0
[t=2] check open=1 heap ok
@@@ hidden_input
20
1 O 0
1 O 1
1 O 2
1 O 3
1 O -1
2 S 0 100
2 S 1 200
2 S 2 300
2 S 3 400
3 S 0 1
3 S 0 2
4 C 1
4 C 0
4 C 3
4 K
5 S 2 50
5 C 2
5 K
6 O 0
6 C 0
@@@ hidden_output
[t=1] open 0 -> 0
[t=1] open 1 -> 0
[t=1] open 2 -> 0
[t=1] open 3 -> 0
[t=1] open -1 -> -1
[t=2] send 0 100 -> 0
[t=2] send 1 200 -> 0
[t=2] send 2 300 -> 0
[t=2] send 3 400 -> 0
[t=3] send 0 1 -> 0
[t=3] send 0 2 -> 0
[t=4] report 1 sum=200 n=1
[t=4] close 1 -> 0, all freed
[t=4] report 0 sum=103 n=3
[t=4] close 0 -> 0, all freed
[t=4] report 3 sum=400 n=1
[t=4] close 3 -> 0, all freed
[t=4] check open=1 heap ok
[t=5] send 2 50 -> 0
[t=5] report 2 sum=350 n=2
[t=5] close 2 -> 0, all freed
[t=5] check open=0 heap ok
[t=6] open 0 -> 0
[t=6] report 0 sum=0 n=0
[t=6] close 0 -> 0, all freed
@@@ hidden_input
16
1 O 1
1 S 1 1000000
1 S 1 1000000
1 S 1 1000000
1 S 1 1000000
2 S 1 1
2 S 1 2
2 S 1 3
2 S 1 4
2 S 1 5
2 C 1
3 O 1
3 C 1
3 O 1
3 C 1
3 K
@@@ hidden_output
[t=1] open 1 -> 0
[t=1] send 1 1000000 -> 0
[t=1] send 1 1000000 -> 0
[t=1] send 1 1000000 -> 0
[t=1] send 1 1000000 -> 0
[t=2] send 1 1 -> 0
[t=2] send 1 2 -> 0
[t=2] send 1 3 -> 0
[t=2] send 1 4 -> 0
[t=2] send 1 5 -> -2
[t=2] report 1 sum=4000010 n=8
[t=2] close 1 -> 0, all freed
[t=3] open 1 -> 0
[t=3] report 1 sum=0 n=0
[t=3] close 1 -> 0, all freed
[t=3] open 1 -> 0
[t=3] report 1 sum=0 n=0
[t=3] close 1 -> 0, all freed
[t=3] check open=0 heap ok
@@@ hint
Keep a table `Session *s_tab[MAX_SESSIONS]`. In `session_open`, acquire the resources in order (context, queue, task) and, on failure, release them in **reverse** order before returning -2 (the classic `goto fail_queue;` ladder).
@@@ hint
In `session_close`, the worker has priority 2 and the manager 3, so the worker is blocked in `xQueueReceive` and cannot be running. Drain with `while (xQueueReceive(q, &v, 0) == pdPASS)`, report, then `vTaskDelete(worker)` **before** `vQueueDelete(q)`: a task deleted by another task is freed immediately, and a queue must not be deleted while a task is still waiting on it. Finally `vPortFree(ctx)`. Do not let the worker delete itself: the idle task would free it later, after `session_close` has returned.
@@@ solution_code
#include <stdint.h>
#include <stddef.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

#define MAX_SESSIONS  4
#define SESSION_Q_LEN 4

void session_report(int id, uint32_t sum, unsigned count);

typedef struct {
    QueueHandle_t q;
    TaskHandle_t  worker;
    uint32_t      sum;
    unsigned      count;
} Session;

static Session *s_tab[MAX_SESSIONS];

static void worker_task(void *pv)
{
    Session *s = (Session *)pv;
    uint32_t v;

    for (;;) {
        if (xQueueReceive(s->q, &v, portMAX_DELAY) == pdPASS) {
            s->sum += v;
            s->count++;
        }
    }
}

int session_open(int id)
{
    Session *s;

    if (id < 0 || id >= MAX_SESSIONS || s_tab[id] != NULL) {
        return -1;
    }
    s = (Session *)pvPortMalloc(sizeof *s);
    if (s == NULL) {
        goto fail;
    }
    s->sum = 0;
    s->count = 0;
    s->q = xQueueCreate(SESSION_Q_LEN, sizeof(uint32_t));
    if (s->q == NULL) {
        goto fail_ctx;
    }
    if (xTaskCreate(worker_task, "sess", configMINIMAL_STACK_SIZE, s, 2, &s->worker) != pdPASS) {
        goto fail_queue;
    }
    s_tab[id] = s;
    return 0;

fail_queue:                      /* release in reverse order of acquisition */
    vQueueDelete(s->q);
fail_ctx:
    vPortFree(s);
fail:
    return -2;
}

int session_send(int id, uint32_t v)
{
    if (id < 0 || id >= MAX_SESSIONS || s_tab[id] == NULL) {
        return -1;
    }
    return xQueueSend(s_tab[id]->q, &v, 0) == pdPASS ? 0 : -2;
}

int session_close(int id)
{
    Session *s;
    uint32_t v;

    if (id < 0 || id >= MAX_SESSIONS || s_tab[id] == NULL) {
        return -1;
    }
    s = s_tab[id];
    s_tab[id] = NULL;
    while (xQueueReceive(s->q, &v, 0) == pdPASS) {   /* values the worker has not seen yet */
        s->sum += v;
        s->count++;
    }
    session_report(id, s->sum, s->count);
    vTaskDelete(s->worker);   /* not running (lower priority): TCB + stack freed now */
    vQueueDelete(s->q);       /* nobody waits on it any more */
    vPortFree(s);             /* last: the task and the queue no longer reference it */
    return 0;
}
@@@ explanation_md
**Approach.** One session = three heap objects with a strict order of dependencies: the worker uses the queue and the context, and the queue lives in the context. Acquire them in that order, and release them in **reverse** order on every path:

- **Partial failure in `session_open`.** If the task cannot be created, the queue and the context are already allocated. The `goto` ladder releases exactly what was obtained. The `L` commands in the tests make the context and queue succeed but the task fail (or the queue fail), and the harness checks that a failed open changes nothing.
- **Close.** First drain the queue with a zero timeout: the manager has the higher priority, so values sent in the same tick are still queued. Then `vTaskDelete(worker)`: deleting **another** task frees its TCB and stack immediately (it is not running, so nothing is left to the idle task). Only then `vQueueDelete()`, because no task is blocked on the queue any more. Finally free the context.
- The harness measures the bytes each open took and checks that exactly those bytes come back at close. A single forgotten `vQueueDelete()` or `vPortFree()` shows up as `LEAK <n> bytes`.

**Complexity.** Open and close are O(1) plus a few heap_4 operations (O(free blocks) each). Close drains at most `SESSION_Q_LEN` values. RAM per session: context + queue (header + `4 * 4` bytes) + TCB + stack, each with a 16-byte block header.

**Common mistakes**
- Making the worker delete itself on close (a "quit" message): its memory comes back only when the idle task runs, so the heap check right after close fails. In a system that is never idle, it never comes back.
- `vQueueDelete()` while the worker still waits on that queue: the task's event-list item stays linked into freed memory. That is a corrupted list later.
- Freeing the context before deleting the task: the worker may run once more and write into freed memory.
- No cleanup on the error path of `session_open`: a few hundred bytes leak per failed attempt, and the retries make it worse exactly when memory is short.
- Losing the values still queued at close (reporting without draining).

**Interview follow-ups**
- How would you redesign this to need **no** run-time allocation at all (pre-created worker pool, static queues)?
- How do you find a slow leak in the field (`xPortGetFreeHeapSize` trend logging, `vPortGetHeapStats`, `traceMALLOC` / `traceFREE` hooks)?
- Why can heap_4 still fail an allocation after thousands of balanced open/close cycles (fragmentation), and why does heap_4's coalescing usually prevent it here?
- What changes if the worker can be **inside** a mutex when the session is closed?
