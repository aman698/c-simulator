@@@ meta
id: RTM-E-03
topic: Software Timers
difficulty: Easy
type: FUNCTION
title: One Callback For Many Sensor Timers Using The Timer ID
tags: freertos, software-timers, timer-id, pvtimergettimerid, auto-reload, embedded
@@@ statement_md
A gateway ECU samples up to 8 sensors, each at its own rate. Each sensor gets its own **auto-reload** software timer, but all the timers must share **one** callback function. The callback finds out which sensor it serves through the **timer ID**.

```c
typedef struct {
    int        index;    /* 0 .. n-1 */
    TickType_t period;   /* sampling period in ticks */
    unsigned   limit;    /* stop this sensor after `limit` samples; 0 = never stop */
    unsigned   count;    /* free for you to use; 0 at start */
} Sensor;

void sample_sensor(int index);        /* provided: records one sample of sensor `index` */

void app_start(Sensor s[], int n);    /* you write this (and the shared callback) */
```

`app_start()` is called **before** the scheduler starts. The array `s` stays valid for the whole run. For every sensor:

1. create an auto-reload timer with period `s[i].period`,
2. start it (the first sample is at t = period), and
3. on every expiry, call `sample_sensor(s[i].index)`.

When a sensor with `limit > 0` has taken `limit` samples, stop its timer from the callback.

Rules:
- All timers must be created with the **same** callback function. The harness wraps `xTimerCreate()` and counts the distinct callbacks.
- `pcTimerGetName()`, creating tasks and `vTaskDelay()` are banned. Use the timer ID (`xTimerCreate`'s 4th argument, `pvTimerGetTimerID()`).
- The callback runs in the timer service task and must not block (block time `0`).

**How it is tested.** The hidden `main()` runs the scheduler up to and including tick `D`. Several sensors can be due at the same tick, and FreeRTOS does not promise their order. So the harness **sorts** the recorded samples by tick, then by sensor index, before it prints them. Then it prints the number of samples per sensor.

**Input**
```
<n>
<period_0> <limit_0>
...
<period_n-1> <limit_n-1>
<D>
```

**Output**
```
[t=<tick>] S<index>        (one line per sample, sorted)
distinct callbacks: <k>
S<index> samples=<count>   (one line per sensor)
```

**Example**
```
Input:
3
10 0
15 2
25 1
60

Output:
[t=10] S0
[t=15] S1
[t=20] S0
[t=25] S2
[t=30] S0
[t=30] S1
[t=40] S0
[t=50] S0
[t=60] S0
distinct callbacks: 1
S0 samples=6
S1 samples=2
S2 samples=1
```
S1 stops after its second sample (t=30), and S2 after its first (t=25). S0 has no limit.
@@@ constraints_md
- 1 <= n <= 8, 1 <= period <= 1000, 0 <= limit <= 100, 1 <= D <= 5000.
- Exactly one timer per sensor, all created with the same callback.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

typedef struct {
    int        index;
    TickType_t period;
    unsigned   limit;
    unsigned   count;
} Sensor;

void sample_sensor(int index);

static void sensor_cb(TimerHandle_t xTimer)
{
    /* TODO: find the sensor from the timer ID, sample it, stop it at its limit */
    (void)xTimer;
}

void app_start(Sensor s[], int n)
{
    /* TODO: one auto-reload timer per sensor, all with sensor_cb */
    (void)s;
    (void)n;
    (void)sensor_cb;
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"
#include "sim.h"

#define MAX_S 8
#define MAX_LOG 4096

typedef struct { unsigned tick; int idx; } Rec;
static Rec g_log[MAX_LOG];
static unsigned g_nlog, g_overflow;
static unsigned g_samples[MAX_S];
static int g_bad_ctx, g_bad_idx;
static TimerCallbackFunction_t g_cbs[MAX_S + 8];
static int g_ncbs, g_ntimers;

void sample_sensor(int index)
{
    if (xTaskGetCurrentTaskHandle() != xTimerGetTimerDaemonTaskHandle()) g_bad_ctx = 1;
    if (index < 0 || index >= MAX_S) { g_bad_idx = 1; return; }
    g_samples[index]++;
    if (g_nlog < MAX_LOG) {
        g_log[g_nlog].tick = (unsigned)xTaskGetTickCount();
        g_log[g_nlog].idx = index;
        g_nlog++;
    } else {
        g_overflow = 1;
    }
}

static TimerHandle_t h_timer_create(const char *name, TickType_t period, BaseType_t reload,
                                    void *id, TimerCallbackFunction_t cb)
{
    int i, seen = 0;
    for (i = 0; i < g_ncbs; i++) if (g_cbs[i] == cb) seen = 1;
    if (!seen && g_ncbs < MAX_S + 8) g_cbs[g_ncbs++] = cb;
    g_ntimers++;
    return xTimerCreate(name, period, reload, id, cb);
}

#define xTimerCreate(a, b, c, d, e) h_timer_create(a, b, c, d, e)
#define xTimerCreateStatic(...) xTimerCreateStatic_is_not_allowed_here
#define pcTimerGetName(x) pcTimerGetName_is_not_allowed_here
#define xTaskCreate(...) xTaskCreate_is_not_allowed_here
#define xTaskCreateStatic(...) xTaskCreateStatic_is_not_allowed_here
#define vTaskDelay(x) vTaskDelay_is_not_allowed_here

/*USER_CODE*/

#undef xTimerCreate
#undef xTimerCreateStatic
#undef pcTimerGetName
#undef xTaskCreate
#undef xTaskCreateStatic
#undef vTaskDelay

static int cmp_rec(const void *a, const void *b)
{
    const Rec *x = (const Rec *)a, *y = (const Rec *)b;
    if (x->tick != y->tick) return x->tick < y->tick ? -1 : 1;
    return (x->idx > y->idx) - (x->idx < y->idx);
}

int main(void)
{
    static Sensor s[MAX_S];
    unsigned period, limit, dur, i;
    int n;

    if (scanf("%d", &n) != 1 || n < 1 || n > MAX_S) return 1;
    for (i = 0; i < (unsigned)n; i++) {
        if (scanf("%u %u", &period, &limit) != 2) return 1;
        s[i].index = (int)i;
        s[i].period = (TickType_t)period;
        s[i].limit = limit;
        s[i].count = 0;
    }
    if (scanf("%u", &dur) != 1) return 1;

    app_start(s, n);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    /* the sort is total (tick, index) and duplicates are identical records */
    qsort(g_log, g_nlog, sizeof g_log[0], cmp_rec);
    for (i = 0; i < g_nlog; i++) printf("[t=%u] S%d\n", g_log[i].tick, g_log[i].idx);
    if (g_overflow) printf("FAIL: too many samples\n");
    if (g_bad_ctx) printf("FAIL: sample_sensor() called outside the timer service task\n");
    if (g_bad_idx) printf("FAIL: sample_sensor() called with a bad index\n");
    if (g_ntimers != n) printf("FAIL: %d timers created for %d sensors\n", g_ntimers, n);
    printf("distinct callbacks: %d\n", g_ncbs);
    for (i = 0; i < (unsigned)n; i++) printf("S%u samples=%u\n", i, g_samples[i]);
    return 0;
}
@@@ sample_input
3
10 0
15 2
25 1
60
@@@ sample_output
[t=10] S0
[t=15] S1
[t=20] S0
[t=25] S2
[t=30] S0
[t=30] S1
[t=40] S0
[t=50] S0
[t=60] S0
distinct callbacks: 1
S0 samples=6
S1 samples=2
S2 samples=1
@@@ sample_input
2
3 0
3 0
9
@@@ sample_output
[t=3] S0
[t=3] S1
[t=6] S0
[t=6] S1
[t=9] S0
[t=9] S1
distinct callbacks: 1
S0 samples=3
S1 samples=3
@@@ hidden_input
1
1 5
10
@@@ hidden_output
[t=1] S0
[t=2] S0
[t=3] S0
[t=4] S0
[t=5] S0
distinct callbacks: 1
S0 samples=5
@@@ hidden_input
4
2 0
3 0
5 3
7 1
14
@@@ hidden_output
[t=2] S0
[t=3] S1
[t=4] S0
[t=5] S2
[t=6] S0
[t=6] S1
[t=7] S3
[t=8] S0
[t=9] S1
[t=10] S0
[t=10] S2
[t=12] S0
[t=12] S1
[t=14] S0
distinct callbacks: 1
S0 samples=7
S1 samples=4
S2 samples=2
S3 samples=1
@@@ hidden_input
8
1000 0
1000 0
1000 0
1000 0
1000 0
1000 0
1000 0
1000 0
999
@@@ hidden_output
distinct callbacks: 1
S0 samples=0
S1 samples=0
S2 samples=0
S3 samples=0
S4 samples=0
S5 samples=0
S6 samples=0
S7 samples=0
@@@ hidden_input
2
1 3
2 0
6
@@@ hidden_output
[t=1] S0
[t=2] S0
[t=2] S1
[t=3] S0
[t=4] S1
[t=6] S1
distinct callbacks: 1
S0 samples=3
S1 samples=3
@@@ hidden_input
3
100 0
250 4
1000 0
2000
@@@ hidden_output
[t=100] S0
[t=200] S0
[t=250] S1
[t=300] S0
[t=400] S0
[t=500] S0
[t=500] S1
[t=600] S0
[t=700] S0
[t=750] S1
[t=800] S0
[t=900] S0
[t=1000] S0
[t=1000] S1
[t=1000] S2
[t=1100] S0
[t=1200] S0
[t=1300] S0
[t=1400] S0
[t=1500] S0
[t=1600] S0
[t=1700] S0
[t=1800] S0
[t=1900] S0
[t=2000] S0
[t=2000] S2
distinct callbacks: 1
S0 samples=20
S1 samples=4
S2 samples=2
@@@ hint
The 4th argument of `xTimerCreate()` is an opaque `void *` stored in the timer. Pass `&s[i]` there, and read it back in the callback with `pvTimerGetTimerID(xTimer)`.
@@@ hint
Callback: `Sensor *se = (Sensor *)pvTimerGetTimerID(xTimer); sample_sensor(se->index); if (se->limit && ++se->count == se->limit) xTimerStop(xTimer, 0);`
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

typedef struct {
    int        index;
    TickType_t period;
    unsigned   limit;
    unsigned   count;
} Sensor;

void sample_sensor(int index);

static void sensor_cb(TimerHandle_t xTimer)
{
    /* the ID tells us which sensor this expiry belongs to */
    Sensor *se = (Sensor *)pvTimerGetTimerID(xTimer);

    sample_sensor(se->index);
    se->count++;
    if (se->limit != 0 && se->count == se->limit) {
        xTimerStop(xTimer, 0);          /* never block inside a callback */
    }
}

void app_start(Sensor s[], int n)
{
    int i;

    for (i = 0; i < n; i++) {
        TimerHandle_t h = xTimerCreate("sensor", s[i].period, pdTRUE, &s[i], sensor_cb);
        if (h != NULL) xTimerStart(h, 0);
    }
}
@@@ explanation_md
**Approach.** Every software timer carries a `void *` ID. Store a pointer to the per-sensor context (`&s[i]`) in it. The single callback calls `pvTimerGetTimerID()` and works on that context. This is the standard way to write one callback for N identical peripherals (sensors, CAN channels, LEDs) without N copies of the code and without a lookup table of handles.

The per-sensor counter lives in the context struct, not in a `static` inside the callback (that would be shared by all sensors). `xTimerStop(xTimer, 0)` stops only the timer that expired.

**Complexity.** Per expiry: O(1) in the callback plus one active-list insertion (O(number of active timers)). RAM: one timer control block per sensor, and no task stacks.

**Common mistakes**
- One `static unsigned count` in the callback: all sensors share it and the limits are wrong.
- Passing `&i` or a local struct as the ID. The callback runs long after `app_start()` returns.
- Decoding the sensor from the timer *name* with `strcmp`/`atoi`: slow, fragile, and the name is meant only for debugging.
- Assuming timers due at the same tick fire in creation order. The active list is ordered by expiry time. For equal expiry times the order depends on when each timer was (re)inserted, which changes as auto-reload timers drift past each other.
- Starting more than `configTIMER_QUEUE_LENGTH` (16) timers before the scheduler starts: the extra start commands fail with `pdFAIL`.

**Interview follow-ups**
- How would you change the period of one sensor at run time (`xTimerChangePeriod`), and when does its next sample happen?
- `vTimerSetTimerID()` exists: when is it useful, and what race does it have with the callback?
- With 50 sensors, would you still use 50 timers, or one timer and a scheduling table? What are the trade-offs?
- How do you prove that the worst-case callback time of all sensors together fits within the shortest period?
