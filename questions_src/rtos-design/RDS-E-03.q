@@@ meta
id: RDS-E-03
topic: RTOS Design Patterns
difficulty: Easy
type: FUNCTION
title: Periodic Sample Filter Publish Pipeline
tags: freertos, pipeline, vtaskdelayuntil, queues, moving-average, embedded
@@@ statement_md
A sensor ECU samples an ADC periodically, smooths the value with a moving average, and publishes it on the vehicle bus. Build it as a **three-stage pipeline** of tasks connected by queues, so that a slow filter never disturbs the sampling period.

```c
typedef struct { unsigned seq; int raw; } Sample;     /* sampler -> filter   */
typedef struct { unsigned seq; int avg; } Filtered;   /* filter  -> publisher */

/* provided by the judge */
int  adc_read(void);                 /* conversion keeps the CPU busy for 1 tick, returns the raw value */
void filter_work(void);              /* DSP work: keeps the CPU busy for W ticks */
void publish(unsigned seq, int avg); /* prints "[t=<tick>] #<seq> avg=<avg>" */
void report_overrun(unsigned seq);   /* prints "[t=<tick>] OVERRUN #<seq>" */

void pipeline_start(TickType_t period);   /* you write this (and the three tasks) */
```

`pipeline_start()` is called before the scheduler starts. It creates two queues of length **4** and three tasks:

| Task | Priority | Loop body |
|---|---|---|
| sampler | 4 | wait for the next release; `raw = adc_read()`; `seq` = 1, 2, 3, ...; send `{seq, raw}` to the filter queue **without blocking**. If the queue is full, call `report_overrun(seq)` (the sample is lost). |
| publisher | 3 | receive a `Filtered`, call `publish(seq, avg)` |
| filter | 2 | receive a `Sample`; call `filter_work()`; `avg` = integer average (`sum / count`) of the raw values of the last **4** samples the filter received (fewer at the start); send `{seq, avg}` to the publisher queue (wait if needed) |

**Sampling must be drift-free.** Releases are at exactly `period`, `2*period`, `3*period`, ..., even though `adc_read()` itself takes 1 tick. `vTaskDelay(period)` would drift by one tick per cycle. The judge prints `LATE SAMPLE` when `adc_read()` is not called on the period grid.

**How it is tested.** The hidden `main()` reads `period`, `W`, the duration `D` and a list of raw ADC values (`adc_read()` returns them in order, cycling back to the first). It calls `pipeline_start()` and runs the scheduler up to tick `D`. Then it prints `samples=<adc reads> published=<publish calls> overruns=<overrun reports>`.

Priorities matter. The sampler preempts the filter in the middle of `filter_work()`. When the filter sends a result, the publisher (higher priority) prints it at once, before the filter takes the next sample.

**Input**
```
<period> <W> <D>
<n> <v1> ... <vn>
```

**Example**
```
Input:
10 3 65
5 100 200 300 400 500

Output:
[t=14] #1 avg=100
[t=24] #2 avg=150
[t=34] #3 avg=200
[t=44] #4 avg=250
[t=54] #5 avg=350
[t=64] #6 avg=325
samples=6 published=6 overruns=0
```
Sample 1 is released at t=10. The conversion ends at t=11, and the filter works from t=11 to t=14, when the result is published. Sample 6 reads 100 again (the values cycle), and the average of the last 4 values is (300+400+500+100)/4 = 325.
@@@ constraints_md
- 2 <= period <= 100, 0 <= W <= 50, 1 <= D <= 5000, 1 <= n <= 20, 0 <= v <= 10000.
- Priorities: sampler 4, publisher 3, filter 2. Both queues have length 4. Stack `configMINIMAL_STACK_SIZE`.
- Simulated time: only `adc_read()` and `filter_work()` consume CPU time; everything else takes zero ticks.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct { unsigned seq; int raw; } Sample;
typedef struct { unsigned seq; int avg; } Filtered;

int  adc_read(void);
void filter_work(void);
void publish(unsigned seq, int avg);
void report_overrun(unsigned seq);

static void sampler_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: drift-free release, adc_read(), non-blocking send */
        vTaskDelay(1000);
    }
}

static void filter_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: receive, filter_work(), moving average of the last 4, send */
        vTaskDelay(1000);
    }
}

static void publisher_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: receive, publish() */
        vTaskDelay(1000);
    }
}

void pipeline_start(TickType_t period)
{
    /* TODO: create two queues (length 4) and the three tasks */
    (void)period;
    (void)sampler_task;
    (void)filter_task;
    (void)publisher_task;
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

static int g_vals[20];
static int g_n;
static unsigned g_idx, g_samples, g_published, g_overruns;
static TickType_t g_period, g_w;

int adc_read(void)
{
    TickType_t now = xTaskGetTickCount();
    int v;

    if (now % g_period != 0) printf("[t=%u] LATE SAMPLE\n", (unsigned)now);
    v = g_vals[g_idx % (unsigned)g_n];
    g_idx++;
    g_samples++;
    vSimBusyWork(1);            /* ADC conversion time */
    return v;
}

void filter_work(void)
{
    vSimBusyWork(g_w);
}

void publish(unsigned seq, int avg)
{
    printf("[t=%u] #%u avg=%d\n", (unsigned)xTaskGetTickCount(), seq, avg);
    g_published++;
}

void report_overrun(unsigned seq)
{
    printf("[t=%u] OVERRUN #%u\n", (unsigned)xTaskGetTickCount(), seq);
    g_overruns++;
}

/*USER_CODE*/

int main(void)
{
    unsigned period, w, dur;
    int i;

    if (scanf("%u %u %u %d", &period, &w, &dur, &g_n) != 4 || g_n < 1 || g_n > 20) return 1;
    for (i = 0; i < g_n; i++)
        if (scanf("%d", &g_vals[i]) != 1) return 1;
    g_period = (TickType_t)period;
    g_w = (TickType_t)w;

    pipeline_start(g_period);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("samples=%u published=%u overruns=%u\n", g_samples, g_published, g_overruns);
    return 0;
}
@@@ sample_input
10 3 65
5 100 200 300 400 500
@@@ sample_output
[t=14] #1 avg=100
[t=24] #2 avg=150
[t=34] #3 avg=200
[t=44] #4 avg=250
[t=54] #5 avg=350
[t=64] #6 avg=325
samples=6 published=6 overruns=0
@@@ sample_input
5 12 58
4 10 20 30 40
@@@ sample_output
[t=21] #1 avg=10
[t=36] OVERRUN #7
[t=36] #2 avg=15
[t=46] OVERRUN #9
[t=51] OVERRUN #10
[t=51] #3 avg=20
samples=11 published=3 overruns=3
@@@ hidden_input
50 5 49
3 1 2 3
@@@ hidden_output
samples=0 published=0 overruns=0
@@@ hidden_input
2 0 21
3 7 8 10
@@@ hidden_output
[t=3] #1 avg=7
[t=5] #2 avg=7
[t=7] #3 avg=8
[t=9] #4 avg=8
[t=11] #5 avg=8
[t=13] #6 avg=8
[t=15] #7 avg=8
[t=17] #8 avg=8
[t=19] #9 avg=8
[t=21] #10 avg=8
samples=10 published=10 overruns=0

@@@ hidden_input
7 6 100
6 0 0 0 10000 10000 10000
@@@ hidden_output
[t=15] #1 avg=0
[t=22] #2 avg=0
[t=29] #3 avg=0
[t=36] #4 avg=2500
[t=43] #5 avg=5000
[t=50] #6 avg=7500
[t=57] #7 avg=7500
[t=64] #8 avg=5000
[t=71] #9 avg=2500
[t=78] #10 avg=2500
[t=85] #11 avg=5000
[t=92] #12 avg=7500
[t=99] #13 avg=7500
samples=14 published=13 overruns=0

@@@ hidden_input
4 3 62
2 5 6
@@@ hidden_output
[t=9] #1 avg=5
[t=13] #2 avg=5
[t=17] #3 avg=5
[t=21] #4 avg=5
[t=25] #5 avg=5
[t=29] #6 avg=5
[t=33] #7 avg=5
[t=37] #8 avg=5
[t=41] #9 avg=5
[t=45] #10 avg=5
[t=49] #11 avg=5
[t=53] #12 avg=5
[t=57] #13 avg=5
[t=61] #14 avg=5
samples=15 published=14 overruns=0

@@@ hidden_input
3 50 200
1 9
@@@ hidden_output
[t=19] OVERRUN #6
[t=22] OVERRUN #7
[t=25] OVERRUN #8
[t=28] OVERRUN #9
[t=31] OVERRUN #10
[t=34] OVERRUN #11
[t=37] OVERRUN #12
[t=40] OVERRUN #13
[t=43] OVERRUN #14
[t=46] OVERRUN #15
[t=49] OVERRUN #16
[t=52] OVERRUN #17
[t=55] OVERRUN #18
[t=58] OVERRUN #19
[t=61] OVERRUN #20
[t=64] OVERRUN #21
[t=67] OVERRUN #22
[t=70] OVERRUN #23
[t=73] OVERRUN #24
[t=76] OVERRUN #25
[t=79] OVERRUN #26
[t=79] #1 avg=9
[t=85] OVERRUN #28
[t=88] OVERRUN #29
[t=91] OVERRUN #30
[t=94] OVERRUN #31
[t=97] OVERRUN #32
[t=100] OVERRUN #33
[t=103] OVERRUN #34
[t=106] OVERRUN #35
[t=109] OVERRUN #36
[t=112] OVERRUN #37
[t=115] OVERRUN #38
[t=118] OVERRUN #39
[t=121] OVERRUN #40
[t=124] OVERRUN #41
[t=127] OVERRUN #42
[t=130] OVERRUN #43
[t=133] OVERRUN #44
[t=136] OVERRUN #45
[t=139] OVERRUN #46
[t=142] OVERRUN #47
[t=145] OVERRUN #48
[t=148] OVERRUN #49
[t=151] OVERRUN #50
[t=154] OVERRUN #51
[t=154] #2 avg=9
[t=160] OVERRUN #53
[t=163] OVERRUN #54
[t=166] OVERRUN #55
[t=169] OVERRUN #56
[t=172] OVERRUN #57
[t=175] OVERRUN #58
[t=178] OVERRUN #59
[t=181] OVERRUN #60
[t=184] OVERRUN #61
[t=187] OVERRUN #62
[t=190] OVERRUN #63
[t=193] OVERRUN #64
[t=196] OVERRUN #65
[t=199] OVERRUN #66
samples=66 published=2 overruns=59

@@@ hidden_input
100 20 2050
5 3 1 4 1 5
@@@ hidden_output
[t=121] #1 avg=3
[t=221] #2 avg=2
[t=321] #3 avg=2
[t=421] #4 avg=2
[t=521] #5 avg=2
[t=621] #6 avg=3
[t=721] #7 avg=2
[t=821] #8 avg=3
[t=921] #9 avg=2
[t=1021] #10 avg=2
[t=1121] #11 avg=3
[t=1221] #12 avg=2
[t=1321] #13 avg=3
[t=1421] #14 avg=2
[t=1521] #15 avg=2
[t=1621] #16 avg=3
[t=1721] #17 avg=2
[t=1821] #18 avg=3
[t=1921] #19 avg=2
[t=2021] #20 avg=2
samples=20 published=20 overruns=0

@@@ hint
Sampler: `TickType_t last = xTaskGetTickCount();` once, then `vTaskDelayUntil(&last, period);` in the loop. The wake-up times are then computed from the previous **release**, not from "now", so the 1-tick conversion does not shift them. Send with `xQueueSend(q, &s, 0)` and report an overrun on failure.
@@@ hint
Filter: keep a ring of 4 raw values plus a count (`ring[i++ % 4] = raw; if (cnt < 4) cnt++;`) and divide the sum of the valid entries by `cnt`. Give each task its queue handles through file-scope `static` variables created in `pipeline_start()` before the tasks.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct { unsigned seq; int raw; } Sample;
typedef struct { unsigned seq; int avg; } Filtered;

int  adc_read(void);
void filter_work(void);
void publish(unsigned seq, int avg);
void report_overrun(unsigned seq);

static QueueHandle_t s_raw_q, s_out_q;
static TickType_t s_period;

static void sampler_task(void *pvParameters)
{
    TickType_t last = xTaskGetTickCount();
    Sample s = { 0, 0 };

    (void)pvParameters;
    for (;;) {
        vTaskDelayUntil(&last, s_period);    /* release grid: period, 2*period, ... */
        s.raw = adc_read();
        s.seq++;
        if (xQueueSend(s_raw_q, &s, 0) != pdPASS) {
            report_overrun(s.seq);           /* never block the time-critical stage */
        }
    }
}

static void filter_task(void *pvParameters)
{
    int ring[4];
    unsigned head = 0, cnt = 0, i;
    Sample s;
    Filtered f;

    (void)pvParameters;
    for (;;) {
        int sum = 0;

        xQueueReceive(s_raw_q, &s, portMAX_DELAY);
        filter_work();
        ring[head++ % 4u] = s.raw;
        if (cnt < 4u) cnt++;
        for (i = 0; i < cnt; i++) sum += ring[i];
        f.seq = s.seq;
        f.avg = sum / (int)cnt;
        xQueueSend(s_out_q, &f, portMAX_DELAY);
    }
}

static void publisher_task(void *pvParameters)
{
    Filtered f;

    (void)pvParameters;
    for (;;) {
        xQueueReceive(s_out_q, &f, portMAX_DELAY);
        publish(f.seq, f.avg);
    }
}

void pipeline_start(TickType_t period)
{
    s_period = period;
    s_raw_q = xQueueCreate(4, sizeof(Sample));
    s_out_q = xQueueCreate(4, sizeof(Filtered));
    xTaskCreate(sampler_task, "SAMP", configMINIMAL_STACK_SIZE, NULL, 4, NULL);
    xTaskCreate(publisher_task, "PUB", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
    xTaskCreate(filter_task, "FILT", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
}
@@@ explanation_md
**Approach.** Each stage is a task, and each pair of stages is joined by a queue. The design follows **rate-monotonic** thinking. The sampler has a hard timing requirement, so it gets the highest priority and blocks only in `vTaskDelayUntil()`. It never waits on a queue: if the filter falls behind, the newest sample is reported as an overrun instead of shifting the sampling grid. The filter is the long, CPU-heavy stage, so it runs at the lowest priority and is preempted by the sampler in the middle of `filter_work()`. The publisher is short, so it sits in between and prints each result as soon as the filter sends it.

`vTaskDelayUntil(&last, period)` adds `period` to the previous **wake time**, not to the current time. The 1-tick ADC conversion therefore does not accumulate. With `vTaskDelay(period)`, releases would be at 10, 21, 32, ... (`LATE SAMPLE`).

Sample 2 (W=12 > period=5) shows the overload behaviour. The filter needs 15 ticks per sample (12 of its own work plus 3 conversions that preempt it), while samples arrive every 5 ticks. The queue of 4 fills up, and from then on samples 7, 9 and 10 are dropped. The sampling grid stays perfect, though.

**Complexity.** Per sample: O(1) queue copies and O(4) for the average. RAM: two 4-entry queues (8 bytes per entry) plus 3 TCBs and stacks. Latency of a sample = 1 (conversion) + W + queueing delay. The pipeline is stable when W + W/period < period, roughly W < period - 1.

**Common mistakes**
- `vTaskDelay(period)` in the sampler: the period becomes period+1.
- Blocking `xQueueSend(..., portMAX_DELAY)` in the sampler: an overloaded filter then shifts the sampling time (jitter) instead of producing a visible overrun.
- Giving the filter the highest priority: sampling then waits for every `filter_work()`.
- Averaging over a running total that is never reduced, or dividing by 4 before 4 samples exist.
- Sending a pointer to a stack `Sample` through the queue instead of the value.

**Interview follow-ups**
- How would you detect and report jitter on the sampling task?
- Replace the moving average with an IIR filter `y += (x - y) >> 2`: what changes in RAM and latency?
- Should the ADC conversion be started by a hardware timer and finished by a DMA/ISR instead of busy-waiting?
- How would you size the queues for a burst of N slow filter iterations?
