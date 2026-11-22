@@@ meta
id: RDS-H-02
topic: RTOS Design Patterns
difficulty: Hard
type: FUNCTION
title: Worker Pool With In Order Result Collection
tags: freertos, worker-pool, reorder-buffer, queues, xqueuesendfromisr, embedded
@@@ statement_md
A gateway ECU offloads cryptographic jobs (MAC computation for secure CAN) to a hardware security module. A job keeps the HSM busy for some time, but not the CPU, so several jobs can run **in parallel**, one per worker task. The jobs may finish in any order, yet the results must be handed to the bus **in submission order**.

```c
/* provided by the judge */
uint32_t job_execute(uint16_t arg, uint16_t cost);
    /* starts the HSM job and BLOCKS the calling worker for 'cost' ticks (the CPU is free meanwhile);
       returns the result */
void pool_result(uint16_t seq, uint32_t value);
    /* prints "[t=<tick>] RESULT #<seq> = <value>"; must be called by the task "COLL",
       with seq = 0, 1, 2, ... in order */

/* you write these */
void pool_start(int n_workers, int job_queue_len);       /* called before the scheduler starts */
int  pool_submit_from_isr(uint16_t arg, uint16_t cost); /* called from an interrupt */
```

- `pool_start()` creates a job queue of length `job_queue_len`, a result queue, **`n_workers` worker tasks** (priority **2**) and one collector task named **`"COLL"`** (priority **3**).
- `pool_submit_from_isr()` gives the job the next **sequence number** (0, 1, 2, ... counting **accepted** jobs only) and queues it without blocking. It returns that number, or `-1` if the job queue is full. If a worker was woken, it yields.
- A worker loops: take a job, `value = job_execute(arg, cost)`, send `{seq, value}` to the collector.
- The collector receives results in completion order and keeps them in a **reorder buffer**. As soon as the result with the next expected `seq` is present, it calls `pool_result()` for it and for every following result that is already buffered.

**How it is tested.** The hidden `main()` calls `pool_start()`, creates a background task of priority 1 that keeps the CPU busy, and schedules one interrupt per job. The interrupt calls `pool_submit_from_isr()` and prints `[t=<tick>] SUBMIT <arg> -> #<seq>` or `[t=<tick>] REJECT <arg>`. `job_execute()` returns `arg*arg + 1` and measures how many jobs run at the same time. `pool_result()` prints `FAIL` if a result comes out of order or from another task. At tick `D` the judge prints `accepted`, `rejected`, the number of results, and `max_parallel` (the largest number of jobs that were executing at the same time).

All interrupts of a tick run before any task. A worker that finishes a job at tick `t` passes its result on and can start a queued job at the same tick `t`. The collector has a higher priority than the workers, so a result is printed at the tick at which it becomes printable.

**Input**
```
<n_workers> <job_queue_len> <D>
<m>
<tick> <arg> <cost>        (m lines, ticks non-decreasing)
```

**Example**
```
Input:
2 4 100
4
1 3 10
1 4 2
2 5 3
20 6 0

Output:
[t=1] SUBMIT 3 -> #0
[t=1] SUBMIT 4 -> #1
[t=2] SUBMIT 5 -> #2
[t=11] RESULT #0 = 10
[t=11] RESULT #1 = 17
[t=11] RESULT #2 = 26
[t=20] SUBMIT 6 -> #3
[t=20] RESULT #3 = 37
accepted=4 rejected=0 results=4 max_parallel=2
```
Both workers start at t=1: job 0 runs until 11 and job 1 until 3. The worker that finished job 1 takes job 2 at t=3 and finishes at 6. Jobs 1 and 2 wait in the reorder buffer until job 0 completes at t=11, then all three are printed in order.
@@@ constraints_md
- 1 <= n_workers <= 6, 1 <= job_queue_len <= 8, 1 <= D <= 10000, 0 <= m <= 60, 0 <= arg <= 60000, 0 <= cost <= 200, 1 <= tick < D.
- At most 60 jobs are accepted per run, so the reorder buffer can be indexed by `seq` directly.
- Workers: priority 2, any names that start with `W` (for example `"W0"`). Collector: name `"COLL"`, priority 3. Stack `configMINIMAL_STACK_SIZE`.
- The collector must block while it has nothing to do: no polling.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

uint32_t job_execute(uint16_t arg, uint16_t cost);
void pool_result(uint16_t seq, uint32_t value);

typedef struct { uint16_t seq; uint16_t arg; uint16_t cost; } Job;
typedef struct { uint16_t seq; uint32_t value; } Result;

static void worker_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: take a job, execute it, send the result to the collector */
        vTaskDelay(1000);
    }
}

static void collector_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: receive results, release them in sequence order */
        vTaskDelay(1000);
    }
}

void pool_start(int n_workers, int job_queue_len)
{
    /* TODO: queues, n_workers workers (priority 2), "COLL" (priority 3) */
    (void)n_workers;
    (void)job_queue_len;
    (void)worker_task;
    (void)collector_task;
}

int pool_submit_from_isr(uint16_t arg, uint16_t cost)
{
    /* TODO */
    (void)arg;
    (void)cost;
    return -1;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

static unsigned g_active, g_max_parallel, g_accepted, g_rejected, g_results;
static unsigned g_next_seq;
static int g_fail;

uint32_t job_execute(uint16_t arg, uint16_t cost)
{
    const char *who = pcTaskGetName(NULL);

    if (who[0] != 'W' && !g_fail) {
        printf("FAIL: job_execute() called from task \"%s\"\n", who);
        g_fail = 1;
    }
    g_active++;
    if (g_active > g_max_parallel) g_max_parallel = g_active;
    vTaskDelay((TickType_t)cost);           /* the HSM works, the CPU is free */
    g_active--;
    return (uint32_t)arg * (uint32_t)arg + 1u;
}

void pool_result(uint16_t seq, uint32_t value)
{
    const char *who = pcTaskGetName(NULL);

    if (strcmp(who, "COLL") != 0) {
        if (!g_fail) printf("FAIL: pool_result() called from task \"%s\"\n", who);
        g_fail = 1;
        return;
    }
    if ((unsigned)seq != g_next_seq) {
        printf("[t=%u] FAIL: result #%u out of order (expected #%u)\n",
               (unsigned)xTaskGetTickCount(), (unsigned)seq, g_next_seq);
        return;
    }
    printf("[t=%u] RESULT #%u = %u\n", (unsigned)xTaskGetTickCount(), (unsigned)seq, (unsigned)value);
    g_next_seq++;
    g_results++;
}

/*USER_CODE*/

typedef struct { unsigned arg, cost; } Sub;
static Sub g_sub[60];

static void submit_isr(void *a)
{
    const Sub *s = (const Sub *)a;
    int seq = pool_submit_from_isr((uint16_t)s->arg, (uint16_t)s->cost);

    if (seq < 0) {
        printf("[t=%u] REJECT %u\n", (unsigned)xTaskGetTickCountFromISR(), s->arg);
        g_rejected++;
    } else {
        printf("[t=%u] SUBMIT %u -> #%d\n", (unsigned)xTaskGetTickCountFromISR(), s->arg, seq);
        g_accepted++;
    }
}

static void background_task(void *p)
{
    (void)p;
    for (;;) vSimBusyWork(1);
}

int main(void)
{
    int n, qlen, m, i;
    unsigned dur, tick;

    if (scanf("%d %d %u %d", &n, &qlen, &dur, &m) != 4 || m < 0 || m > 60) return 1;
    pool_start(n, qlen);
    xTaskCreate(background_task, "BG", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    for (i = 0; i < m; i++) {
        if (scanf("%u %u %u", &tick, &g_sub[i].arg, &g_sub[i].cost) != 3) return 1;
        xSimScheduleInterrupt((TickType_t)tick, submit_isr, &g_sub[i]);
    }
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("accepted=%u rejected=%u results=%u max_parallel=%u\n",
           g_accepted, g_rejected, g_results, g_max_parallel);
    return 0;
}
@@@ sample_input
2 4 100
4
1 3 10
1 4 2
2 5 3
20 6 0
@@@ sample_output
[t=1] SUBMIT 3 -> #0
[t=1] SUBMIT 4 -> #1
[t=2] SUBMIT 5 -> #2
[t=11] RESULT #0 = 10
[t=11] RESULT #1 = 17
[t=11] RESULT #2 = 26
[t=20] SUBMIT 6 -> #3
[t=20] RESULT #3 = 37
accepted=4 rejected=0 results=4 max_parallel=2
@@@ sample_input
1 2 50
5
5 1 5
5 2 5
5 3 5
5 4 5
12 7 1
@@@ sample_output
[t=5] SUBMIT 1 -> #0
[t=5] SUBMIT 2 -> #1
[t=5] REJECT 3
[t=5] REJECT 4
[t=10] RESULT #0 = 2
[t=12] SUBMIT 7 -> #2
[t=15] RESULT #1 = 5
[t=16] RESULT #2 = 50
accepted=3 rejected=2 results=3 max_parallel=1
@@@ hidden_input
3 4 100
0
@@@ hidden_output
accepted=0 rejected=0 results=0 max_parallel=0
@@@ hidden_input
6 8 300
8
1 100 50
1 99 40
1 98 30
1 97 20
1 96 10
1 95 1
1 94 0
1 60000 60
@@@ hidden_output
[t=1] SUBMIT 100 -> #0
[t=1] SUBMIT 99 -> #1
[t=1] SUBMIT 98 -> #2
[t=1] SUBMIT 97 -> #3
[t=1] SUBMIT 96 -> #4
[t=1] SUBMIT 95 -> #5
[t=1] SUBMIT 94 -> #6
[t=1] SUBMIT 60000 -> #7
[t=51] RESULT #0 = 10001
[t=51] RESULT #1 = 9802
[t=51] RESULT #2 = 9605
[t=51] RESULT #3 = 9410
[t=51] RESULT #4 = 9217
[t=51] RESULT #5 = 9026
[t=51] RESULT #6 = 8837
[t=62] RESULT #7 = 3600000001
accepted=8 rejected=0 results=8 max_parallel=6

@@@ hidden_input
3 2 200
10
10 1 30
10 2 1
10 3 1
10 4 1
10 5 1
11 6 1
12 7 1
13 8 1
40 9 5
40 10 0
@@@ hidden_output
[t=10] SUBMIT 1 -> #0
[t=10] SUBMIT 2 -> #1
[t=10] REJECT 3
[t=10] REJECT 4
[t=10] REJECT 5
[t=11] SUBMIT 6 -> #2
[t=12] SUBMIT 7 -> #3
[t=13] SUBMIT 8 -> #4
[t=40] SUBMIT 9 -> #5
[t=40] SUBMIT 10 -> #6
[t=40] RESULT #0 = 2
[t=40] RESULT #1 = 5
[t=40] RESULT #2 = 37
[t=40] RESULT #3 = 50
[t=40] RESULT #4 = 65
[t=45] RESULT #5 = 82
[t=45] RESULT #6 = 101
accepted=7 rejected=3 results=7 max_parallel=2

@@@ hidden_input
2 1 500
12
1 10 7
2 11 3
3 12 3
4 13 3
5 14 3
6 15 3
7 16 3
8 17 3
9 18 3
10 19 3
11 20 3
12 21 3
@@@ hidden_output
[t=1] SUBMIT 10 -> #0
[t=2] SUBMIT 11 -> #1
[t=3] SUBMIT 12 -> #2
[t=4] REJECT 13
[t=5] REJECT 14
[t=6] SUBMIT 15 -> #3
[t=7] REJECT 16
[t=8] REJECT 17
[t=8] RESULT #0 = 101
[t=8] RESULT #1 = 122
[t=8] RESULT #2 = 145
[t=9] SUBMIT 18 -> #4
[t=10] SUBMIT 19 -> #5
[t=11] REJECT 20
[t=11] RESULT #3 = 226
[t=12] SUBMIT 21 -> #6
[t=12] RESULT #4 = 325
[t=14] RESULT #5 = 362
[t=15] RESULT #6 = 442
accepted=7 rejected=5 results=7 max_parallel=2

@@@ hidden_input
4 8 400
9
100 1 100
101 2 80
102 3 60
103 4 40
104 5 20
200 6 0
200 7 0
200 8 0
205 9 3
@@@ hidden_output
[t=100] SUBMIT 1 -> #0
[t=101] SUBMIT 2 -> #1
[t=102] SUBMIT 3 -> #2
[t=103] SUBMIT 4 -> #3
[t=104] SUBMIT 5 -> #4
[t=200] SUBMIT 6 -> #5
[t=200] SUBMIT 7 -> #6
[t=200] SUBMIT 8 -> #7
[t=200] RESULT #0 = 2
[t=200] RESULT #1 = 5
[t=200] RESULT #2 = 10
[t=200] RESULT #3 = 17
[t=200] RESULT #4 = 26
[t=200] RESULT #5 = 37
[t=200] RESULT #6 = 50
[t=200] RESULT #7 = 65
[t=205] SUBMIT 9 -> #8
[t=208] RESULT #8 = 82
accepted=9 rejected=0 results=9 max_parallel=4

@@@ hidden_input
1 8 300
6
1 5 20
2 6 0
3 7 0
21 8 0
21 9 0
22 10 10
@@@ hidden_output
[t=1] SUBMIT 5 -> #0
[t=2] SUBMIT 6 -> #1
[t=3] SUBMIT 7 -> #2
[t=21] SUBMIT 8 -> #3
[t=21] SUBMIT 9 -> #4
[t=21] RESULT #0 = 26
[t=21] RESULT #1 = 37
[t=21] RESULT #2 = 50
[t=21] RESULT #3 = 65
[t=21] RESULT #4 = 82
[t=22] SUBMIT 10 -> #5
[t=32] RESULT #5 = 101
accepted=6 rejected=0 results=6 max_parallel=1

@@@ hint
The ISR assigns the sequence number: keep a `static uint16_t next_seq`, build the `Job`, and only increment `next_seq` if `xQueueSendFromISR()` succeeded. That way rejected jobs leave no gap that the collector would wait for forever. All workers block on the same job queue: whichever is free takes the next job.
@@@ hint
Collector: `static Result buf[64]; static uint8_t ready[64]; uint16_t expect = 0;`. After each `xQueueReceive(results, &r, portMAX_DELAY)`, store it in `buf[r.seq]` and mark it ready, then `while (ready[expect]) { pool_result(expect, buf[expect].value); expect++; }`. Give the result queue room for at least `n_workers` entries, so that a worker never blocks on it for long.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

uint32_t job_execute(uint16_t arg, uint16_t cost);
void pool_result(uint16_t seq, uint32_t value);

typedef struct { uint16_t seq; uint16_t arg; uint16_t cost; } Job;
typedef struct { uint16_t seq; uint32_t value; } Result;

#define MAX_JOBS 64

static QueueHandle_t s_jobs, s_results;
static uint16_t s_next_seq;               /* only touched by the submit ISR */

static void worker_task(void *pvParameters)
{
    Job j;
    Result r;

    (void)pvParameters;
    for (;;) {
        xQueueReceive(s_jobs, &j, portMAX_DELAY);
        r.seq = j.seq;
        r.value = job_execute(j.arg, j.cost);     /* blocks this worker only */
        xQueueSend(s_results, &r, portMAX_DELAY);
    }
}

static void collector_task(void *pvParameters)
{
    static Result buf[MAX_JOBS];
    static uint8_t ready[MAX_JOBS];
    uint16_t expect = 0;
    Result r;

    (void)pvParameters;
    for (;;) {
        xQueueReceive(s_results, &r, portMAX_DELAY);
        if (r.seq >= MAX_JOBS) continue;
        buf[r.seq] = r;
        ready[r.seq] = 1;
        while (expect < MAX_JOBS && ready[expect]) {   /* release the in-order prefix */
            pool_result(expect, buf[expect].value);
            expect++;
        }
    }
}

void pool_start(int n_workers, int job_queue_len)
{
    int i;
    char name[8] = "W0";

    s_jobs = xQueueCreate((UBaseType_t)job_queue_len, sizeof(Job));
    s_results = xQueueCreate((UBaseType_t)n_workers, sizeof(Result));
    for (i = 0; i < n_workers; i++) {
        name[1] = (char)('0' + i);
        xTaskCreate(worker_task, name, configMINIMAL_STACK_SIZE, NULL, 2, NULL);
    }
    xTaskCreate(collector_task, "COLL", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
}

int pool_submit_from_isr(uint16_t arg, uint16_t cost)
{
    BaseType_t woken = pdFALSE;
    Job j;

    j.seq = s_next_seq;
    j.arg = arg;
    j.cost = cost;
    if (xQueueSendFromISR(s_jobs, &j, &woken) != pdPASS) return -1;
    s_next_seq++;                         /* numbers count accepted jobs only */
    portYIELD_FROM_ISR(woken);
    return (int)j.seq;
}
@@@ explanation_md
**Approach.** Classic **fan-out / fan-in**. One job queue is shared by `n` identical workers. FreeRTOS hands each job to one waiting task, so the queue itself is the load balancer, and no explicit "find a free worker" logic is needed. A worker is blocked inside `job_execute()` while the HSM works, so up to `n` jobs run in parallel even on one CPU (`max_parallel`). Results come back through a second queue in **completion** order. The collector turns them into **submission** order with a reorder buffer indexed by `seq`: it stores every result and releases the longest ready prefix.

The ISR numbers jobs at acceptance time. Rejected jobs (sample 2) therefore consume no number, and the collector never waits for a result that will never come. The collector's priority (3) is higher than the workers' (2), so a result is printed as soon as it is printable. In the example, job 0 completes at t=11 and releases #0, #1 and #2 in one burst.

**Complexity.** Submit: O(1). Per result: O(1) amortised (each result is released exactly once). RAM: job queue `len x 6` bytes, result queue `n x 8` bytes, reorder buffer `64 x 9` bytes, and `n + 1` task stacks: workers are the expensive part, so `n` is sized to the HSM's parallelism. Worst-case latency of a result = the completion time of the slowest job submitted before it (head-of-line blocking, as in the example).

**Common mistakes**
- Printing results as they arrive: out of order (`FAIL`).
- Incrementing the sequence number before knowing that the enqueue succeeded: a gap that blocks the collector forever.
- Busy-waiting inside a worker instead of blocking: the jobs then serialise, and `max_parallel` stays at 1.
- Giving the workers a higher priority than the collector, or using a result queue of length 1: results are printed later than possible, or workers block on the result queue.
- Creating each worker with a **stack** buffer for its name or arguments that dies after `pool_start()` returns. FreeRTOS copies the name, but not `pvParameters` data.
- Forgetting `portYIELD_FROM_ISR()`: every job starts a tick late, because the background task keeps the CPU.

**Interview follow-ups**
- Head-of-line blocking: one slow job holds back every later result. When is that acceptable, and how would you add a per-job timeout?
- How would you bound the reorder buffer when sequence numbers wrap (modulo indexing plus window flow control)?
- Thread pool on an SMP FreeRTOS (2 cores): what changes for the shared state?
- How do you size `n_workers` (Little's law: arrival rate x average service time)?
