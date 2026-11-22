@@@ meta
id: RMM-E-03
topic: RTOS Memory Management
difficulty: Easy
type: FUNCTION
title: Static Queue, Binary Semaphore And Mutex Creation
tags: freertos, xqueuecreatestatic, xsemaphorecreatebinarystatic, xsemaphorecreatemutexstatic, static-allocation, embedded
@@@ statement_md
A body-control ECU receives commands in a UART interrupt and executes them in a worker task. The project's coding rules forbid the FreeRTOS heap, so the three kernel objects of this module must be created **statically**. The tasks and the ISR are already written. You write the creation code.

```c
#define CMD_QUEUE_LEN 8

typedef struct {
    uint16_t seq;
    uint8_t  id;
    uint8_t  arg;
} Cmd;                              /* 4 bytes */

extern QueueHandle_t     g_cmd_q;       /* defined by the harness */
extern SemaphoreHandle_t g_done_sem;
extern SemaphoreHandle_t g_uart_mutex;

void app_create(void);              /* you write this */
```

`app_create()` is called once, before the scheduler starts. It must set:

- `g_cmd_q`: a queue of `CMD_QUEUE_LEN` items of type `Cmd`, created with `xQueueCreateStatic()`;
- `g_done_sem`: a **binary** semaphore, created with `xSemaphoreCreateBinaryStatic()` (it starts empty);
- `g_uart_mutex`: a **mutex**, created with `xSemaphoreCreateMutexStatic()` (it starts free).

The storage area of the queue and every `StaticQueue_t` / `StaticSemaphore_t` must outlive the objects. The dynamic creation functions (`xQueueCreate`, `xSemaphoreCreateBinary`, `xSemaphoreCreateMutex`, `xQueueGenericCreate`, `xQueueCreateMutex`) and `pvPortMalloc` are **not allowed** (compile error).

**How it is tested.** The harness first checks the three handles and prints:

```
cmd queue: static, length 8, item 4 bytes
done sem: static binary, count 0
uart mutex: static mutex, free
heap delta 0
```

A wrong object prints a `FAIL: ...` line instead, and the test stops. Then it runs this system up to and including tick `D`:

- At each input `<tick> <count>`, a UART ISR posts `count` commands with `xQueueSendFromISR()`, numbered `seq = 1, 2, 3, ...` over the whole run. When the queue is full, it prints `[t=<tick>] ISR dropped seq=<s>`. At the end it calls `portYIELD_FROM_ISR()`.
- The worker task (priority 2) receives the commands one at a time. For each one it takes `g_uart_mutex`, prints `[t=<tick>] exec seq=<s>`, gives the mutex back, and gives `g_done_sem`.
- The monitor task (priority 1) waits on `g_done_sem` and prints `[t=<tick>] ack`. A binary semaphore does not count: several gives before the monitor runs produce **one** ack.

Finally it prints `executed <e>, dropped <d>, acks <a>`.

**Input**
```
<n>
<tick> <count>      (n lines, increasing ticks)
<D>
```

**Example**
```
Input:
2
5 10
9 1
20

Output:
cmd queue: static, length 8, item 4 bytes
done sem: static binary, count 0
uart mutex: static mutex, free
heap delta 0
[t=5] ISR dropped seq=9
[t=5] ISR dropped seq=10
[t=5] exec seq=1
[t=5] exec seq=2
[t=5] exec seq=3
[t=5] exec seq=4
[t=5] exec seq=5
[t=5] exec seq=6
[t=5] exec seq=7
[t=5] exec seq=8
[t=5] ack
[t=9] exec seq=11
[t=9] ack
executed 9, dropped 2, acks 2
```
The 10 commands at t=5 are all posted by one ISR before the worker runs, so the queue holds the first 8 and the last 2 are dropped.
@@@ constraints_md
- 0 <= n <= 20, 1 <= tick <= 10000 (increasing), 1 <= count <= 20, 1 <= D <= 20000.
- Static creation only; the heap delta must be 0.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "queue.h"
#include "semphr.h"

#define CMD_QUEUE_LEN 8

typedef struct {
    uint16_t seq;
    uint8_t  id;
    uint8_t  arg;
} Cmd;

extern QueueHandle_t     g_cmd_q;
extern SemaphoreHandle_t g_done_sem;
extern SemaphoreHandle_t g_uart_mutex;

void app_create(void)
{
    /* TODO: static storage + xQueueCreateStatic(), xSemaphoreCreateBinaryStatic(),
       xSemaphoreCreateMutexStatic() */
    g_cmd_q = NULL;
    g_done_sem = NULL;
    g_uart_mutex = NULL;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "sim.h"

QueueHandle_t     g_cmd_q;
SemaphoreHandle_t g_done_sem;
SemaphoreHandle_t g_uart_mutex;

#undef xQueueCreate
#undef xSemaphoreCreateBinary
#undef xSemaphoreCreateMutex
#define xQueueCreate(...) xQueueCreate_is_not_allowed_here
#define xSemaphoreCreateBinary(...) xSemaphoreCreateBinary_is_not_allowed_here
#define xSemaphoreCreateMutex(...) xSemaphoreCreateMutex_is_not_allowed_here
#define xQueueGenericCreate(...) xQueueGenericCreate_is_not_allowed_here
#define xQueueCreateMutex(...) xQueueCreateMutex_is_not_allowed_here
#define pvPortMalloc(...) pvPortMalloc_is_not_allowed_here

/*USER_CODE*/

#undef pvPortMalloc

static uint16_t g_seq;
static unsigned g_exec, g_drop, g_acks;
static unsigned g_count[20];

static void uart_isr(void *arg)
{
    unsigned k, n = *(unsigned *)arg;
    BaseType_t woken = pdFALSE;

    for (k = 0; k < n; k++) {
        Cmd c;
        c.seq = ++g_seq;
        c.id = (uint8_t)(c.seq & 0xFFu);
        c.arg = (uint8_t)(xTaskGetTickCountFromISR() & 0xFFu);
        if (xQueueSendFromISR(g_cmd_q, &c, &woken) != pdPASS) {
            printf("[t=%u] ISR dropped seq=%u\n", (unsigned)xTaskGetTickCountFromISR(), (unsigned)c.seq);
            g_drop++;
        }
    }
    portYIELD_FROM_ISR(woken);
}

static void worker_task(void *p)
{
    Cmd c;
    (void)p;
    for (;;) {
        if (xQueueReceive(g_cmd_q, &c, portMAX_DELAY) == pdPASS) {
            xSemaphoreTake(g_uart_mutex, portMAX_DELAY);
            printf("[t=%u] exec seq=%u\n", (unsigned)xTaskGetTickCount(), (unsigned)c.seq);
            g_exec++;
            xSemaphoreGive(g_uart_mutex);
            xSemaphoreGive(g_done_sem);
        }
    }
}

static void monitor_task(void *p)
{
    (void)p;
    for (;;) {
        if (xSemaphoreTake(g_done_sem, portMAX_DELAY) == pdPASS) {
            printf("[t=%u] ack\n", (unsigned)xTaskGetTickCount());
            g_acks++;
        }
    }
}

int main(void)
{
    uint8_t *storage = NULL;
    StaticQueue_t *sq = NULL;
    StaticSemaphore_t *ss = NULL;
    size_t before;
    unsigned tick, dur;
    int i, n;

    if (scanf("%d", &n) != 1 || n < 0 || n > 20) return 1;
    vPortFree(pvPortMalloc(16));          /* initialise heap_4 */
    before = xPortGetFreeHeapSize();
    app_create();

    if (g_cmd_q == NULL || g_done_sem == NULL || g_uart_mutex == NULL) {
        printf("FAIL: a handle is NULL\n");
        return 0;
    }
    if (xQueueGetStaticBuffers(g_cmd_q, &storage, &sq) != pdTRUE || storage == NULL) {
        printf("FAIL: cmd queue is not statically allocated\n");
        return 0;
    }
    if (ucQueueGetQueueType(g_cmd_q) != queueQUEUE_TYPE_BASE) {
        printf("FAIL: cmd queue is not a plain queue\n");
        return 0;
    }
    printf("cmd queue: static, length %u, item %u bytes\n", (unsigned)uxQueueGetQueueLength(g_cmd_q),
           (unsigned)uxQueueGetQueueItemSize(g_cmd_q));
    if (xSemaphoreGetStaticBuffer(g_done_sem, &ss) != pdTRUE) {
        printf("FAIL: done sem is not statically allocated\n");
        return 0;
    }
    if (ucQueueGetQueueType(g_done_sem) != queueQUEUE_TYPE_BINARY_SEMAPHORE) {
        printf("FAIL: done sem is not a binary semaphore\n");
        return 0;
    }
    printf("done sem: static binary, count %u\n", (unsigned)uxSemaphoreGetCount(g_done_sem));
    if (xSemaphoreGetStaticBuffer(g_uart_mutex, &ss) != pdTRUE) {
        printf("FAIL: uart mutex is not statically allocated\n");
        return 0;
    }
    if (ucQueueGetQueueType(g_uart_mutex) != queueQUEUE_TYPE_MUTEX) {
        printf("FAIL: uart mutex is not a mutex\n");
        return 0;
    }
    printf("uart mutex: static mutex, %s\n", uxSemaphoreGetCount(g_uart_mutex) == 1 ? "free" : "taken");
    printf("heap delta %d\n", (int)before - (int)xPortGetFreeHeapSize());

    for (i = 0; i < n; i++) {
        if (scanf("%u %u", &tick, &g_count[i]) != 2) return 1;
        xSimScheduleInterrupt((TickType_t)tick, uart_isr, &g_count[i]);
    }
    if (scanf("%u", &dur) != 1) return 1;

    xTaskCreate(worker_task, "worker", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
    xTaskCreate(monitor_task, "monitor", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("executed %u, dropped %u, acks %u\n", g_exec, g_drop, g_acks);
    return 0;
}
@@@ sample_input
2
5 10
9 1
20
@@@ sample_output
cmd queue: static, length 8, item 4 bytes
done sem: static binary, count 0
uart mutex: static mutex, free
heap delta 0
[t=5] ISR dropped seq=9
[t=5] ISR dropped seq=10
[t=5] exec seq=1
[t=5] exec seq=2
[t=5] exec seq=3
[t=5] exec seq=4
[t=5] exec seq=5
[t=5] exec seq=6
[t=5] exec seq=7
[t=5] exec seq=8
[t=5] ack
[t=9] exec seq=11
[t=9] ack
executed 9, dropped 2, acks 2
@@@ sample_input
3
1 1
2 2
3 1
10
@@@ sample_output
cmd queue: static, length 8, item 4 bytes
done sem: static binary, count 0
uart mutex: static mutex, free
heap delta 0
[t=1] exec seq=1
[t=1] ack
[t=2] exec seq=2
[t=2] exec seq=3
[t=2] ack
[t=3] exec seq=4
[t=3] ack
executed 4, dropped 0, acks 3
@@@ hidden_input
0
100
@@@ hidden_output
cmd queue: static, length 8, item 4 bytes
done sem: static binary, count 0
uart mutex: static mutex, free
heap delta 0
executed 0, dropped 0, acks 0
@@@ hidden_input
1
7 8
8
@@@ hidden_output
cmd queue: static, length 8, item 4 bytes
done sem: static binary, count 0
uart mutex: static mutex, free
heap delta 0
[t=7] exec seq=1
[t=7] exec seq=2
[t=7] exec seq=3
[t=7] exec seq=4
[t=7] exec seq=5
[t=7] exec seq=6
[t=7] exec seq=7
[t=7] exec seq=8
[t=7] ack
executed 8, dropped 0, acks 1
@@@ hidden_input
2
3 9
4 20
20
@@@ hidden_output
cmd queue: static, length 8, item 4 bytes
done sem: static binary, count 0
uart mutex: static mutex, free
heap delta 0
[t=3] ISR dropped seq=9
[t=3] exec seq=1
[t=3] exec seq=2
[t=3] exec seq=3
[t=3] exec seq=4
[t=3] exec seq=5
[t=3] exec seq=6
[t=3] exec seq=7
[t=3] exec seq=8
[t=3] ack
[t=4] ISR dropped seq=18
[t=4] ISR dropped seq=19
[t=4] ISR dropped seq=20
[t=4] ISR dropped seq=21
[t=4] ISR dropped seq=22
[t=4] ISR dropped seq=23
[t=4] ISR dropped seq=24
[t=4] ISR dropped seq=25
[t=4] ISR dropped seq=26
[t=4] ISR dropped seq=27
[t=4] ISR dropped seq=28
[t=4] ISR dropped seq=29
[t=4] exec seq=10
[t=4] exec seq=11
[t=4] exec seq=12
[t=4] exec seq=13
[t=4] exec seq=14
[t=4] exec seq=15
[t=4] exec seq=16
[t=4] exec seq=17
[t=4] ack
executed 16, dropped 13, acks 2

@@@ hidden_input
3
10 1
11 1
5000 1
20000
@@@ hidden_output
cmd queue: static, length 8, item 4 bytes
done sem: static binary, count 0
uart mutex: static mutex, free
heap delta 0
[t=10] exec seq=1
[t=10] ack
[t=11] exec seq=2
[t=11] ack
[t=5000] exec seq=3
[t=5000] ack
executed 3, dropped 0, acks 3
@@@ hidden_input
2
50 3
60 2
55
@@@ hidden_output
cmd queue: static, length 8, item 4 bytes
done sem: static binary, count 0
uart mutex: static mutex, free
heap delta 0
[t=50] exec seq=1
[t=50] exec seq=2
[t=50] exec seq=3
[t=50] ack
executed 3, dropped 0, acks 1
@@@ hint
Each static object needs a control block that outlives it: `static StaticQueue_t`, `static StaticSemaphore_t`. The queue also needs a storage area of `CMD_QUEUE_LEN * sizeof(Cmd)` bytes (`static uint8_t storage[CMD_QUEUE_LEN * sizeof(Cmd)]`).
@@@ hint
`g_cmd_q = xQueueCreateStatic(CMD_QUEUE_LEN, sizeof(Cmd), storage, &q_cb);`, `g_done_sem = xSemaphoreCreateBinaryStatic(&sem_cb);`, `g_uart_mutex = xSemaphoreCreateMutexStatic(&mtx_cb);`. Each control block needs its own variable.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "queue.h"
#include "semphr.h"

#define CMD_QUEUE_LEN 8

typedef struct {
    uint16_t seq;
    uint8_t  id;
    uint8_t  arg;
} Cmd;

extern QueueHandle_t     g_cmd_q;
extern SemaphoreHandle_t g_done_sem;
extern SemaphoreHandle_t g_uart_mutex;

/* Everything in .bss, visible in the map file, never freed. */
static uint8_t           s_cmd_storage[CMD_QUEUE_LEN * sizeof(Cmd)];
static StaticQueue_t     s_cmd_q_cb;
static StaticSemaphore_t s_done_cb;
static StaticSemaphore_t s_mutex_cb;

void app_create(void)
{
    g_cmd_q      = xQueueCreateStatic(CMD_QUEUE_LEN, sizeof(Cmd), s_cmd_storage, &s_cmd_q_cb);
    g_done_sem   = xSemaphoreCreateBinaryStatic(&s_done_cb);   /* created empty */
    g_uart_mutex = xSemaphoreCreateMutexStatic(&s_mutex_cb);   /* created available */
}
@@@ explanation_md
**Approach.** Every `...CreateStatic()` call takes a control block from the caller instead of allocating one. A queue needs two buffers: a `StaticQueue_t` (the queue header with its lists of waiting tasks) and a storage area of `length * item_size` bytes. A semaphore or mutex is a queue whose items have size 0, so it only needs a `StaticSemaphore_t`. All buffers are file-scope `static`, so they live forever. The returned handles point into them. The harness checks this with `xQueueGetStaticBuffers()` / `xSemaphoreGetStaticBuffer()` and sees a heap delta of 0.

The run shows the semantics of each object. The ISR fills the 8-slot queue before the worker runs, so the 9th and 10th commands are dropped. The mutex is created available, so the worker can take it at once. The binary semaphore is created **empty**, and several gives before the monitor runs leave it at 1, so a burst produces one ack. A counting semaphore would count them.

**Complexity.** Creation is O(1). RAM is fixed at link time: `CMD_QUEUE_LEN * sizeof(Cmd)` + `sizeof(StaticQueue_t)` + `2 * sizeof(StaticSemaphore_t)`, with no heap header per object and no possibility of fragmentation.

**Common mistakes**
- Using one `StaticSemaphore_t` for both the semaphore and the mutex: the second create overwrites the first object, and both handles end up the same.
- Storage too small: `CMD_QUEUE_LEN` bytes instead of `CMD_QUEUE_LEN * sizeof(Cmd)`. The queue then writes past the array.
- Local (stack) control blocks in `app_create()`: dangling after it returns.
- Expecting a binary semaphore to be available after creation. Since FreeRTOS v8 it starts **empty**: unlike the old `vSemaphoreCreateBinary()` macro, `xSemaphoreCreateBinary()` / `...Static()` do not give it first.
- Using a binary semaphore where a mutex is needed: no priority inheritance, and anybody can give it.

**Interview follow-ups**
- Why does a mutex support priority inheritance and a binary semaphore not? Which one may be given from an ISR?
- What does `configSUPPORT_STATIC_ALLOCATION` require from the application, and why do the idle and timer tasks need memory callbacks?
- How would you detect a queue that is too short in the field (high-water mark of `uxQueueMessagesWaiting`, drop counters)?
- When can a static object be "deleted" (`vQueueDelete`) and its buffers reused?
