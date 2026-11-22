@@@ meta
id: RMM-H-03
topic: RTOS Memory Management
difficulty: Hard
type: FUNCTION
title: Fully Static Sensor System With No Heap Allocation At All
tags: freertos, static-allocation, xtimercreatestatic, xeventgroupcreatestatic, misra, iso-26262, embedded, asked-in-automotive
@@@ statement_md
For an ASIL-B wheel-speed monitor, the safety concept says: **the FreeRTOS heap is never used**. Every kernel object is allocated statically and appears in the linker map. Build the whole application this way.

```c
#define SAMPLE_Q_LEN     8
#define TASK_STACK_WORDS 256
#define ALARM_BIT        ((EventBits_t)1u << 0)

typedef struct {
    TickType_t period;      /* sampling period in ticks */
    uint16_t   threshold;   /* alarm when sample >= threshold */
    unsigned   count;       /* number of samples, then sampling stops */
} AppCfg;

/* defined by the harness, set by you */
extern TaskHandle_t       g_filter_task, g_alarm_task;
extern QueueHandle_t      g_sample_q;
extern TimerHandle_t      g_sample_timer;
extern EventGroupHandle_t g_events;
extern SemaphoreHandle_t  g_uart_mutex;

/* provided */
uint16_t sensor_read(void);          /* next sample */
void report_sample(uint16_t v);      /* "[t=..] sample <v>" - caller must hold g_uart_mutex */
void report_alarm(uint16_t v);       /* "[t=..] ALARM <v>"  - caller must hold g_uart_mutex */

void app_start(const AppCfg *cfg);   /* you write this, the tasks and the timer callback */
```

`app_start()` runs before the scheduler. It creates **six static objects** and starts the timer:

| object | how | details |
|---|---|---|
| `g_sample_q` | `xQueueCreateStatic` | `SAMPLE_Q_LEN` items of `uint16_t` |
| `g_uart_mutex` | `xSemaphoreCreateMutexStatic` | |
| `g_events` | `xEventGroupCreateStatic` | |
| `g_sample_timer` | `xTimerCreateStatic` | period `cfg->period`, **auto-reload** |
| `g_filter_task` | `xTaskCreateStatic` | priority **3**, `TASK_STACK_WORDS` |
| `g_alarm_task` | `xTaskCreateStatic` | priority **2**, `TASK_STACK_WORDS` |

Behaviour:
- **Timer callback** (runs in the timer service task): `v = sensor_read()` and `xQueueSend(g_sample_q, &v, 0)`. After the `count`-th sample, the callback stops the timer (`xTimerStop(timer, 0)`). Start the timer in `app_start()` with `xTimerStart(timer, 0)`, unless `count` is 0: then it is never started. The first sample is taken at `t = period`.
- **Filter task**: receive a sample (wait forever). Under the UART mutex, `report_sample(v)`. If `v >= threshold`, store `v` for the alarm task and set `ALARM_BIT` in `g_events`.
- **Alarm task**: wait for `ALARM_BIT` (clear on exit, wait forever). Under the UART mutex, `report_alarm(v)`.

Every dynamic creation function (`xTaskCreate`, `xQueueCreate`, `xSemaphoreCreate...`, `xTimerCreate`, `xEventGroupCreate`, ...), `pvPortMalloc` and `malloc` cause a **compile error**.

**How it is tested.** After `app_start()`, the harness checks every handle. Each object must be statically allocated (`x...GetStaticBuffer(s)`), with the right type and parameters (queue length and item size, timer period and auto-reload, task priorities, mutex type). It prints `static objects: OK` or a `FAIL: ...` line (and stops). The report functions check that the caller holds the mutex (`NO LOCK`) and is the right task (`WRONG TASK`). The scheduler runs up to and including tick `D`. Then the harness prints how many samples were read, whether the timer is still active, and the heap delta over the whole run.

The timer task (priority 7) sends the sample, then the filter (3) runs, then the alarm task (2), all at the same tick.

**Input**
```
<period> <threshold> <count>
<n> <v1> ... <vn>          (sensor values; sensor_read() returns 0 after them)
<D>
```

**Example**
```
Input:
10 100 4
4 50 120 90 130
100

Output:
static objects: OK
[t=10] sample 50
[t=20] sample 120
[t=20] ALARM 120
[t=30] sample 90
[t=40] sample 130
[t=40] ALARM 130
samples read: 4
timer active: no
heap delta 0
```
@@@ constraints_md
- 1 <= period <= 1000, 0 <= threshold <= 65535, 0 <= count <= 20, 0 <= n <= 20, D <= 20000.
- No FreeRTOS heap at all (heap delta 0); every buffer must outlive its object.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "timers.h"
#include "event_groups.h"

#define SAMPLE_Q_LEN     8
#define TASK_STACK_WORDS 256
#define ALARM_BIT        ((EventBits_t)1u << 0)

typedef struct {
    TickType_t period;
    uint16_t   threshold;
    unsigned   count;
} AppCfg;

extern TaskHandle_t       g_filter_task, g_alarm_task;
extern QueueHandle_t      g_sample_q;
extern TimerHandle_t      g_sample_timer;
extern EventGroupHandle_t g_events;
extern SemaphoreHandle_t  g_uart_mutex;

uint16_t sensor_read(void);
void report_sample(uint16_t v);
void report_alarm(uint16_t v);

void app_start(const AppCfg *cfg)
{
    /* TODO: static buffers + xQueueCreateStatic, xSemaphoreCreateMutexStatic,
       xEventGroupCreateStatic, xTimerCreateStatic, 2 x xTaskCreateStatic,
       then xTimerStart (if cfg->count > 0) */
    (void)cfg;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "timers.h"
#include "event_groups.h"
#include "sim.h"

TaskHandle_t       g_filter_task, g_alarm_task;
QueueHandle_t      g_sample_q;
TimerHandle_t      g_sample_timer;
EventGroupHandle_t g_events;
SemaphoreHandle_t  g_uart_mutex;

static uint16_t g_vals[20];
static int g_nvals, g_next;
static unsigned g_reads;

uint16_t sensor_read(void)
{
    g_reads++;
    return g_next < g_nvals ? g_vals[g_next++] : 0;
}

static void check_ctx(TaskHandle_t expect)
{
    if (g_uart_mutex == NULL || xSemaphoreGetMutexHolder(g_uart_mutex) != xTaskGetCurrentTaskHandle())
        printf("[t=%u] NO LOCK\n", (unsigned)xTaskGetTickCount());
    if (xTaskGetCurrentTaskHandle() != expect)
        printf("[t=%u] WRONG TASK\n", (unsigned)xTaskGetTickCount());
}

void report_sample(uint16_t v)
{
    check_ctx(g_filter_task);
    printf("[t=%u] sample %u\n", (unsigned)xTaskGetTickCount(), (unsigned)v);
}

void report_alarm(uint16_t v)
{
    check_ctx(g_alarm_task);
    printf("[t=%u] ALARM %u\n", (unsigned)xTaskGetTickCount(), (unsigned)v);
}

#define xTaskCreate(...) xTaskCreate_is_not_allowed_here
#define xQueueGenericCreate(...) dynamic_queue_creation_is_not_allowed_here
#define xQueueCreateMutex(...) dynamic_mutex_creation_is_not_allowed_here
#define xQueueCreateCountingSemaphore(...) dynamic_semaphore_creation_is_not_allowed_here
#define xTimerCreate(...) xTimerCreate_is_not_allowed_here
#define xEventGroupCreate(...) xEventGroupCreate_is_not_allowed_here
#define xStreamBufferGenericCreate(...) xStreamBufferCreate_is_not_allowed_here
#define pvPortMalloc(...) pvPortMalloc_is_not_allowed_here
#define malloc(...) malloc_is_not_allowed_here

/*USER_CODE*/

#undef pvPortMalloc

static int fail(const char *what)
{
    printf("FAIL: %s\n", what);
    return 0;
}

int main(void)
{
    static AppCfg cfg;
    unsigned period, thr, count, dur, v;
    StackType_t *stack = NULL;
    StaticTask_t *tcb = NULL;
    uint8_t *qstore = NULL;
    StaticQueue_t *sq = NULL;
    StaticSemaphore_t *ss = NULL;
    StaticTimer_t *st = NULL;
    StaticEventGroup_t *se = NULL;
    size_t before;
    int i;

    if (scanf("%u %u %u %d", &period, &thr, &count, &g_nvals) != 4 || g_nvals < 0 || g_nvals > 20) return 1;
    for (i = 0; i < g_nvals; i++) {
        if (scanf("%u", &v) != 1) return 1;
        g_vals[i] = (uint16_t)v;
    }
    if (scanf("%u", &dur) != 1) return 1;
    cfg.period = (TickType_t)period;
    cfg.threshold = (uint16_t)thr;
    cfg.count = count;

    vPortFree(pvPortMalloc(16));             /* initialise heap_4 */
    before = xPortGetFreeHeapSize();
    app_start(&cfg);

    if (!g_filter_task || !g_alarm_task || !g_sample_q || !g_sample_timer || !g_events || !g_uart_mutex)
        return fail("a handle is NULL");
    if (xTaskGetStaticBuffers(g_filter_task, &stack, &tcb) != pdTRUE ||
        xTaskGetStaticBuffers(g_alarm_task, &stack, &tcb) != pdTRUE)
        return fail("a task is not statically allocated");
    if (uxTaskPriorityGet(g_filter_task) != 3 || uxTaskPriorityGet(g_alarm_task) != 2)
        return fail("wrong task priority");
    if (xQueueGetStaticBuffers(g_sample_q, &qstore, &sq) != pdTRUE || qstore == NULL)
        return fail("sample queue is not statically allocated");
    if (ucQueueGetQueueType(g_sample_q) != queueQUEUE_TYPE_BASE || uxQueueGetQueueLength(g_sample_q) != 8 ||
        uxQueueGetQueueItemSize(g_sample_q) != sizeof(uint16_t))
        return fail("sample queue has the wrong type, length or item size");
    if (xSemaphoreGetStaticBuffer(g_uart_mutex, &ss) != pdTRUE)
        return fail("uart mutex is not statically allocated");
    if (ucQueueGetQueueType(g_uart_mutex) != queueQUEUE_TYPE_MUTEX)
        return fail("uart mutex is not a mutex");
    if (xEventGroupGetStaticBuffer(g_events, &se) != pdTRUE)
        return fail("event group is not statically allocated");
    if (xTimerGetStaticBuffer(g_sample_timer, &st) != pdTRUE)
        return fail("timer is not statically allocated");
    if (xTimerGetPeriod(g_sample_timer) != cfg.period || uxTimerGetReloadMode(g_sample_timer) != pdTRUE)
        return fail("timer period or reload mode is wrong");
    if (xPortGetFreeHeapSize() != before)
        return fail("app_start() used the FreeRTOS heap");
    printf("static objects: OK\n");

    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("samples read: %u\n", g_reads);
    printf("timer active: %s\n", xTimerIsTimerActive(g_sample_timer) ? "yes" : "no");
    printf("heap delta %d\n", (int)before - (int)xPortGetFreeHeapSize());
    return 0;
}
@@@ sample_input
10 100 4
4 50 120 90 130
100
@@@ sample_output
static objects: OK
[t=10] sample 50
[t=20] sample 120
[t=20] ALARM 120
[t=30] sample 90
[t=40] sample 130
[t=40] ALARM 130
samples read: 4
timer active: no
heap delta 0
@@@ sample_input
7 0 3
2 5 6
50
@@@ sample_output
static objects: OK
[t=7] sample 5
[t=7] ALARM 5
[t=14] sample 6
[t=14] ALARM 6
[t=21] sample 0
[t=21] ALARM 0
samples read: 3
timer active: no
heap delta 0
@@@ hidden_input
5 10 0
3 100 100 100
100
@@@ hidden_output
static objects: OK
samples read: 0
timer active: no
heap delta 0
@@@ hidden_input
1 65535 20
5 65535 65534 1 65535 2
30
@@@ hidden_output
static objects: OK
[t=1] sample 65535
[t=1] ALARM 65535
[t=2] sample 65534
[t=3] sample 1
[t=4] sample 65535
[t=4] ALARM 65535
[t=5] sample 2
[t=6] sample 0
[t=7] sample 0
[t=8] sample 0
[t=9] sample 0
[t=10] sample 0
[t=11] sample 0
[t=12] sample 0
[t=13] sample 0
[t=14] sample 0
[t=15] sample 0
[t=16] sample 0
[t=17] sample 0
[t=18] sample 0
[t=19] sample 0
[t=20] sample 0
samples read: 20
timer active: no
heap delta 0

@@@ hidden_input
999 500 20
20 1 2 3 4 5 6 7 8 9 10 600 12 13 14 15 16 17 18 19 500
20000
@@@ hidden_output
static objects: OK
[t=999] sample 1
[t=1998] sample 2
[t=2997] sample 3
[t=3996] sample 4
[t=4995] sample 5
[t=5994] sample 6
[t=6993] sample 7
[t=7992] sample 8
[t=8991] sample 9
[t=9990] sample 10
[t=10989] sample 600
[t=10989] ALARM 600
[t=11988] sample 12
[t=12987] sample 13
[t=13986] sample 14
[t=14985] sample 15
[t=15984] sample 16
[t=16983] sample 17
[t=17982] sample 18
[t=18981] sample 19
[t=19980] sample 500
[t=19980] ALARM 500
samples read: 20
timer active: no
heap delta 0

@@@ hidden_input
3 50 10
6 10 60 70 20 80 90
25
@@@ hidden_output
static objects: OK
[t=3] sample 10
[t=6] sample 60
[t=6] ALARM 60
[t=9] sample 70
[t=9] ALARM 70
[t=12] sample 20
[t=15] sample 80
[t=15] ALARM 80
[t=18] sample 90
[t=18] ALARM 90
[t=21] sample 0
[t=24] sample 0
samples read: 8
timer active: yes
heap delta 0
@@@ hidden_input
2 1 1
0
10
@@@ hidden_output
static objects: OK
[t=2] sample 0
samples read: 1
timer active: no
heap delta 0
@@@ hint
Every `...CreateStatic()` needs a control-block variable (`StaticTask_t`, `StaticQueue_t`, `StaticSemaphore_t`, `StaticEventGroup_t`, `StaticTimer_t`) with static storage duration, plus a stack array per task and a storage array for the queue (`SAMPLE_Q_LEN * sizeof(uint16_t)` bytes). Declare them at file scope.
@@@ hint
Timer callback: `static unsigned n; uint16_t v = sensor_read(); xQueueSend(g_sample_q, &v, 0); if (++n >= cfg->count) xTimerStop(t, 0);`. Keep `cfg` in a static pointer, or pass it as the timer ID (`pvTimerGetTimerID`). Alarm task: `xEventGroupWaitBits(g_events, ALARM_BIT, pdTRUE, pdFALSE, portMAX_DELAY)`, then take the mutex and report.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "timers.h"
#include "event_groups.h"

#define SAMPLE_Q_LEN     8
#define TASK_STACK_WORDS 256
#define ALARM_BIT        ((EventBits_t)1u << 0)

typedef struct {
    TickType_t period;
    uint16_t   threshold;
    unsigned   count;
} AppCfg;

extern TaskHandle_t       g_filter_task, g_alarm_task;
extern QueueHandle_t      g_sample_q;
extern TimerHandle_t      g_sample_timer;
extern EventGroupHandle_t g_events;
extern SemaphoreHandle_t  g_uart_mutex;

uint16_t sensor_read(void);
void report_sample(uint16_t v);
void report_alarm(uint16_t v);

/* ---- all kernel memory, visible in the map file ---- */
static uint8_t            s_q_storage[SAMPLE_Q_LEN * sizeof(uint16_t)];
static StaticQueue_t      s_q_cb;
static StaticSemaphore_t  s_mutex_cb;
static StaticEventGroup_t s_events_cb;
static StaticTimer_t      s_timer_cb;
static StackType_t        s_filter_stack[TASK_STACK_WORDS];
static StackType_t        s_alarm_stack[TASK_STACK_WORDS];
static StaticTask_t       s_filter_tcb;
static StaticTask_t       s_alarm_tcb;

static const AppCfg *s_cfg;
static unsigned      s_taken;
static uint16_t      s_alarm_value;    /* written by filter, read by alarm task */

static void sample_cb(TimerHandle_t t)
{
    uint16_t v = sensor_read();

    (void)xQueueSend(g_sample_q, &v, 0);          /* timer task must never block */
    if (++s_taken >= s_cfg->count) {
        (void)xTimerStop(t, 0);
    }
}

static void filter_task(void *pv)
{
    uint16_t v;
    (void)pv;

    for (;;) {
        if (xQueueReceive(g_sample_q, &v, portMAX_DELAY) != pdPASS) {
            continue;
        }
        xSemaphoreTake(g_uart_mutex, portMAX_DELAY);
        report_sample(v);
        xSemaphoreGive(g_uart_mutex);
        if (v >= s_cfg->threshold) {
            s_alarm_value = v;
            (void)xEventGroupSetBits(g_events, ALARM_BIT);
        }
    }
}

static void alarm_task(void *pv)
{
    (void)pv;

    for (;;) {
        EventBits_t b = xEventGroupWaitBits(g_events, ALARM_BIT, pdTRUE, pdFALSE, portMAX_DELAY);
        if (b & ALARM_BIT) {
            xSemaphoreTake(g_uart_mutex, portMAX_DELAY);
            report_alarm(s_alarm_value);
            xSemaphoreGive(g_uart_mutex);
        }
    }
}

void app_start(const AppCfg *cfg)
{
    s_cfg = cfg;
    g_sample_q = xQueueCreateStatic(SAMPLE_Q_LEN, sizeof(uint16_t), s_q_storage, &s_q_cb);
    g_uart_mutex = xSemaphoreCreateMutexStatic(&s_mutex_cb);
    g_events = xEventGroupCreateStatic(&s_events_cb);
    g_sample_timer = xTimerCreateStatic("sample", cfg->period, pdTRUE, NULL, sample_cb, &s_timer_cb);
    g_filter_task = xTaskCreateStatic(filter_task, "filter", TASK_STACK_WORDS, NULL, 3,
                                      s_filter_stack, &s_filter_tcb);
    g_alarm_task = xTaskCreateStatic(alarm_task, "alarm", TASK_STACK_WORDS, NULL, 2,
                                     s_alarm_stack, &s_alarm_tcb);
    if (cfg->count > 0) {
        (void)xTimerStart(g_sample_timer, 0);    /* queued; processed when the scheduler starts */
    }
}
@@@ explanation_md
**Approach.** Every FreeRTOS object has a `...CreateStatic()` variant that takes the control block (and, for queues and tasks, the storage or stack) from the caller. The whole system's kernel memory then becomes a set of file-scope variables. Their sizes are known at link time and appear in the map file, which is what an ISO 26262 / MISRA review wants to see: no allocator in the run-time path, no out-of-memory, no fragmentation. The idle and timer service tasks also need memory. With `configKERNEL_PROVIDED_STATIC_MEMORY = 1` the kernel supplies it, so this system has a heap delta of exactly 0. The harness proves it with the `x...GetStaticBuffer(s)` queries and the free-heap check.

The data flow uses one object per job:
- the **timer** gives a jitter-free sampling period (auto-reload) and stops itself after `count` samples;
- the **queue** carries the values (with a 0 timeout in the callback: the timer service task must never block);
- the **event group** signals the alarm (a bit instead of a value, so the value is passed through a variable);
- the **mutex** serialises the shared UART between the two tasks.

`xTimerStart()` before the scheduler starts only posts a command to the timer queue. The timer task processes it at t=0, so the first expiry is at `t = period`.

**Complexity.** Per sample: O(1) in the timer callback, one queue transfer, and at most one event-group set/wait. RAM is fixed: 2 × (`TASK_STACK_WORDS * sizeof(StackType_t)` + `sizeof(StaticTask_t)`) + 16 bytes of queue storage + the `StaticQueue_t`/`StaticSemaphore_t`/`StaticEventGroup_t`/`StaticTimer_t` control blocks.

**Common mistakes**
- Sharing a control block between two objects, or declaring a buffer inside `app_start()`: the object outlives the stack frame.
- Queue storage sized `SAMPLE_Q_LEN` bytes instead of `SAMPLE_Q_LEN * sizeof(uint16_t)`.
- Blocking in the timer callback (`xQueueSend(..., portMAX_DELAY)`, `vTaskDelay`): that stalls every software timer in the system.
- Starting the timer when `count == 0`, or never stopping it: `timer active: yes` and extra samples.
- Calling `report_*` without the mutex, or reporting the alarm from the filter task: the harness prints `NO LOCK` / `WRONG TASK`.

**Interview follow-ups**
- With `configSUPPORT_DYNAMIC_ALLOCATION = 0`, which application callbacks become mandatory (`vApplicationGetIdleTaskMemory`, `vApplicationGetTimerTaskMemory`), and what does `configKERNEL_PROVIDED_STATIC_MEMORY` change?
- How would you prove "no heap use" in CI (link without a heap_x.c, map-file checks, a `pvPortMalloc` that asserts after init)?
- Two alarms arrive before the alarm task runs: what does the event group lose, and how would a queue or a task notification with a counter fix it?
- Why must the stack and the TCB of a static task stay untouched after `vTaskDelete()` until the idle task has run?
