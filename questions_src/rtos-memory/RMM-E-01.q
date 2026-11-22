@@@ meta
id: RMM-E-01
topic: RTOS Memory Management
difficulty: Easy
type: FUNCTION
title: Sensor Tasks Created With xTaskCreateStatic
tags: freertos, xtaskcreatestatic, static-allocation, vtaskdelete, embedded, asked-in-automotive
@@@ statement_md
A safety-relevant ECU must not use the FreeRTOS heap after start-up, so every task is created with **`xTaskCreateStatic()`**: the application supplies the stack and the task control block (TCB) itself. Write the function that starts one sampling task per sensor.

```c
#define MAX_SENSORS        3
#define SENSOR_STACK_WORDS 256

typedef struct {
    const char *name;      /* e.g. "T" */
    TickType_t  period;    /* ticks between two samples */
    UBaseType_t priority;  /* FreeRTOS priority of the task */
    unsigned    samples;   /* number of samples, then the task deletes itself */
} SensorCfg;

void sensor_log(const char *name, unsigned k);   /* provided: prints "[t=<tick>] <name> sample <k>" */

TaskHandle_t sensor_start(const SensorCfg *cfg); /* you write this (and the task function) */
```

`sensor_start()` is called once per sensor (at most `MAX_SENSORS` times), **before** the scheduler starts. Each call must create one task with `xTaskCreateStatic()`:

- task name `cfg->name`, priority `cfg->priority`, stack depth `SENSOR_STACK_WORDS` words,
- its **own** stack array and its **own** `StaticTask_t`: two sensors must never share a buffer,
- `pvParameters` = `cfg` (the `SensorCfg` stays valid for the whole run).

Return the task handle. The task does, for `k = 1 .. samples`: wait `period` ticks with `vTaskDelay()`, then call `sensor_log(name, k)`. After the last sample (immediately if `samples` is 0) it deletes itself with `vTaskDelete(NULL)`.

`xTaskCreate()` and `pvPortMalloc()` are **not allowed** (compile error).

**How it is tested.** The hidden `main()` initialises the heap, then calls `sensor_start()` for every sensor and checks the handle: it must be non-NULL, distinct from the handles returned before, and the task must have the right name and priority. It prints `created <name> prio <p>` (or a `FAIL` line). Then it runs the scheduler up to and including tick `D`. At the end it prints, per sensor, the number of samples logged and the task state (`deleted` if the task has deleted itself, `alive` otherwise), and the change of the free FreeRTOS heap over the whole run (`heap delta 0` when nothing was allocated from the heap).

All priorities are different, so at a tick where several tasks wake up, the higher-priority task logs first.

**Input**
```
<n>
<name> <period> <priority> <samples>      (n lines)
<D>
```

**Example**
```
Input:
2
T 10 2 3
P 25 1 2
100

Output:
created T prio 2
created P prio 1
[t=10] T sample 1
[t=20] T sample 2
[t=25] P sample 1
[t=30] T sample 3
[t=50] P sample 2
T: samples=3 state=deleted
P: samples=2 state=deleted
heap delta 0
```
@@@ constraints_md
- 1 <= n <= 3, 1 <= period <= 1000, 0 <= samples <= 20, 1 <= D <= 20000. Priorities are distinct, in 1..6.
- Only `xTaskCreateStatic()`; no FreeRTOS heap (the heap delta must be 0).
- Simulated time: 1 tick = 1 ms, code between two blocking calls takes zero ticks.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"

#define MAX_SENSORS        3
#define SENSOR_STACK_WORDS 256

typedef struct {
    const char *name;
    TickType_t  period;
    UBaseType_t priority;
    unsigned    samples;
} SensorCfg;

void sensor_log(const char *name, unsigned k);

static void sensor_task(void *pvParameters)
{
    /* TODO: for k = 1..samples: vTaskDelay(period); sensor_log(name, k);
       then vTaskDelete(NULL) */
    (void)pvParameters;
    vTaskDelete(NULL);
}

TaskHandle_t sensor_start(const SensorCfg *cfg)
{
    /* TODO: pick a free stack + StaticTask_t and call xTaskCreateStatic() */
    (void)cfg;
    (void)sensor_task;
    return NULL;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

static unsigned g_samples[3];
static char g_names[3][8];
static int g_n;

void sensor_log(const char *name, unsigned k)
{
    int i;
    printf("[t=%u] %s sample %u\n", (unsigned)xTaskGetTickCount(), name, k);
    for (i = 0; i < g_n; i++) {
        if (strcmp(name, g_names[i]) == 0) g_samples[i]++;
    }
}

#define xTaskCreate(...) xTaskCreate_is_not_allowed_here
#define pvPortMalloc(...) pvPortMalloc_is_not_allowed_here

/*USER_CODE*/

#undef xTaskCreate
#undef pvPortMalloc

int main(void)
{
    static SensorCfg cfg[3];
    TaskHandle_t h[3];
    unsigned period, prio, samples, dur;
    size_t before;
    int i, j;

    if (scanf("%d", &g_n) != 1 || g_n < 1 || g_n > 3) return 1;
    for (i = 0; i < g_n; i++) {
        if (scanf("%7s %u %u %u", g_names[i], &period, &prio, &samples) != 4) return 1;
        cfg[i].name = g_names[i];
        cfg[i].period = (TickType_t)period;
        cfg[i].priority = (UBaseType_t)prio;
        cfg[i].samples = samples;
    }
    if (scanf("%u", &dur) != 1) return 1;

    vPortFree(pvPortMalloc(16));              /* initialise heap_4 so the free size is meaningful */
    before = xPortGetFreeHeapSize();

    for (i = 0; i < g_n; i++) {
        h[i] = sensor_start(&cfg[i]);
        if (h[i] == NULL) {
            printf("FAIL: sensor_start(%s) returned NULL\n", g_names[i]);
            return 0;
        }
        for (j = 0; j < i; j++) {
            if (h[j] == h[i]) {
                printf("FAIL: %s and %s share the same TCB\n", g_names[j], g_names[i]);
                return 0;
            }
        }
        if (strcmp(pcTaskGetName(h[i]), g_names[i]) != 0) {
            printf("FAIL: task %s has name \"%s\"\n", g_names[i], pcTaskGetName(h[i]));
            return 0;
        }
        printf("created %s prio %d\n", pcTaskGetName(h[i]), (int)uxTaskPriorityGet(h[i]));
    }

    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    for (i = 0; i < g_n; i++) {
        /* static TCBs stay valid after vTaskDelete(), so the state can still be queried */
        printf("%s: samples=%u state=%s\n", g_names[i], g_samples[i],
               eTaskGetState(h[i]) == eDeleted ? "deleted" : "alive");
    }
    printf("heap delta %d\n", (int)before - (int)xPortGetFreeHeapSize());
    return 0;
}
@@@ sample_input
2
T 10 2 3
P 25 1 2
100
@@@ sample_output
created T prio 2
created P prio 1
[t=10] T sample 1
[t=20] T sample 2
[t=25] P sample 1
[t=30] T sample 3
[t=50] P sample 2
T: samples=3 state=deleted
P: samples=2 state=deleted
heap delta 0
@@@ sample_input
3
A 7 3 2
B 5 2 0
C 3 1 4
12
@@@ sample_output
created A prio 3
created B prio 2
created C prio 1
[t=3] C sample 1
[t=6] C sample 2
[t=7] A sample 1
[t=9] C sample 3
[t=12] C sample 4
A: samples=1 state=alive
B: samples=0 state=deleted
C: samples=4 state=deleted
heap delta 0
@@@ hidden_input
1
X 1 1 0
5
@@@ hidden_output
created X prio 1
X: samples=0 state=deleted
heap delta 0
@@@ hidden_input
3
L 4 1 5
M 4 4 5
H 4 6 5
20
@@@ hidden_output
created L prio 1
created M prio 4
created H prio 6
[t=4] H sample 1
[t=4] M sample 1
[t=4] L sample 1
[t=8] H sample 2
[t=8] M sample 2
[t=8] L sample 2
[t=12] H sample 3
[t=12] M sample 3
[t=12] L sample 3
[t=16] H sample 4
[t=16] M sample 4
[t=16] L sample 4
[t=20] H sample 5
[t=20] M sample 5
[t=20] L sample 5
L: samples=5 state=deleted
M: samples=5 state=deleted
H: samples=5 state=deleted
heap delta 0
@@@ hidden_input
1
S 999 5 20
20000
@@@ hidden_output
created S prio 5
[t=999] S sample 1
[t=1998] S sample 2
[t=2997] S sample 3
[t=3996] S sample 4
[t=4995] S sample 5
[t=5994] S sample 6
[t=6993] S sample 7
[t=7992] S sample 8
[t=8991] S sample 9
[t=9990] S sample 10
[t=10989] S sample 11
[t=11988] S sample 12
[t=12987] S sample 13
[t=13986] S sample 14
[t=14985] S sample 15
[t=15984] S sample 16
[t=16983] S sample 17
[t=17982] S sample 18
[t=18981] S sample 19
[t=19980] S sample 20
S: samples=20 state=deleted
heap delta 0

@@@ hidden_input
2
F 1 2 20
G 3 1 3
15
@@@ hidden_output
created F prio 2
created G prio 1
[t=1] F sample 1
[t=2] F sample 2
[t=3] F sample 3
[t=3] G sample 1
[t=4] F sample 4
[t=5] F sample 5
[t=6] F sample 6
[t=6] G sample 2
[t=7] F sample 7
[t=8] F sample 8
[t=9] F sample 9
[t=9] G sample 3
[t=10] F sample 10
[t=11] F sample 11
[t=12] F sample 12
[t=13] F sample 13
[t=14] F sample 14
[t=15] F sample 15
F: samples=15 state=alive
G: samples=3 state=deleted
heap delta 0
@@@ hidden_input
3
Q 50 6 0
R 30 5 1
Z 40 4 2
100
@@@ hidden_output
created Q prio 6
created R prio 5
created Z prio 4
[t=30] R sample 1
[t=40] Z sample 1
[t=80] Z sample 2
Q: samples=0 state=deleted
R: samples=1 state=deleted
Z: samples=2 state=deleted
heap delta 0
@@@ hint
`xTaskCreateStatic(fn, name, depth, pvParameters, priority, stack, &tcb)` returns the handle. The stack and the `StaticTask_t` must outlive the task, so they cannot be locals of `sensor_start()`: make them `static` arrays.
@@@ hint
Keep `static StackType_t stacks[MAX_SENSORS][SENSOR_STACK_WORDS]; static StaticTask_t tcbs[MAX_SENSORS]; static int used;` and give call number `used++` its own row. In the task: `const SensorCfg *c = pvParameters; for (k = 1; k <= c->samples; k++) { vTaskDelay(c->period); sensor_log(c->name, k); } vTaskDelete(NULL);`
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"

#define MAX_SENSORS        3
#define SENSOR_STACK_WORDS 256

typedef struct {
    const char *name;
    TickType_t  period;
    UBaseType_t priority;
    unsigned    samples;
} SensorCfg;

void sensor_log(const char *name, unsigned k);

/* One stack and one TCB per sensor, in .bss: sized at link time, never freed. */
static StackType_t  s_stacks[MAX_SENSORS][SENSOR_STACK_WORDS];
static StaticTask_t s_tcbs[MAX_SENSORS];
static int          s_used;

static void sensor_task(void *pvParameters)
{
    const SensorCfg *c = (const SensorCfg *)pvParameters;
    unsigned k;

    for (k = 1; k <= c->samples; k++) {
        vTaskDelay(c->period);
        sensor_log(c->name, k);
    }
    vTaskDelete(NULL);   /* static TCB: nothing is freed, the buffers simply become unused */
}

TaskHandle_t sensor_start(const SensorCfg *cfg)
{
    int i;

    if (s_used >= MAX_SENSORS) {
        return NULL;     /* out of static slots: fail instead of corrupting a running task */
    }
    i = s_used++;
    return xTaskCreateStatic(sensor_task, cfg->name, SENSOR_STACK_WORDS, (void *)cfg,
                             cfg->priority, s_stacks[i], &s_tcbs[i]);
}
@@@ explanation_md
**Approach.** `xTaskCreateStatic()` takes the same arguments as `xTaskCreate()` plus two buffers: a `StackType_t` array of `depth` words and a `StaticTask_t`, which the kernel uses as the TCB. The returned handle is the address of that `StaticTask_t`. Because the task keeps using both buffers after `sensor_start()` returns, they must have static storage duration. Every call takes the next free row of `s_stacks` / `s_tcbs`, so two tasks never share a buffer. The task body is a counted loop with `vTaskDelay()`, followed by `vTaskDelete(NULL)`.

For a static task, `vTaskDelete()` frees nothing: the kernel only unlinks the TCB from its lists (the idle task does the clean-up for a self-deleting task). That is why the harness can still call `eTaskGetState()` on the handle afterwards and see `eDeleted`. With a dynamically created task, the same call after deletion would read freed memory. The heap delta stays 0 because no object in this program comes from the FreeRTOS heap.

**Complexity.** `sensor_start()` is O(1). RAM is fixed at link time: `MAX_SENSORS * (SENSOR_STACK_WORDS * sizeof(StackType_t) + sizeof(StaticTask_t))`, reserved even if fewer sensors are started. That is the price of static allocation: worst-case memory is visible in the map file, and there is no fragmentation and no out-of-memory at run time.

**Common mistakes**
- Declaring the stack or the `StaticTask_t` as a **local** of `sensor_start()`: the task runs on a dead stack frame. The kernel does not detect it, and it corrupts memory later.
- One `static` buffer pair shared by all calls: the second `xTaskCreateStatic()` re-initialises a TCB that is still linked into the ready list.
- Passing the stack size in **bytes**. The depth is in words (`StackType_t`), as for `xTaskCreate()`.
- Reusing a static TCB for a new task right after `vTaskDelete(NULL)`: the idle task may not have cleaned it up yet.
- No bound check on the slot index, so a fourth call writes past the arrays.

**Interview follow-ups**
- With `configSUPPORT_STATIC_ALLOCATION` = 1, why must the application provide `vApplicationGetIdleTaskMemory()` (and the timer-task equivalent)? What does `configKERNEL_PROVIDED_STATIC_MEMORY` change?
- How do you size a task stack, and how do you detect an overflow in the field (`configCHECK_FOR_STACK_OVERFLOW`, stack painting)?
- Can a static task be deleted and its buffers reused for a new task? What must you wait for?
- When would you still allow dynamic allocation, but only during initialisation?
