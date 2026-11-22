@@@ meta
id: RIS-H-01
topic: Interrupts & ISRs
difficulty: Hard
type: FUNCTION
title: Ping-Pong DMA Buffers With an ISR-to-Task Handoff
tags: freertos, isr, dma, double-buffering, ping-pong, buffer-ownership, overrun, embedded, asked-in-automotive
@@@ statement_md
A knock-sensor ADC is read by **DMA**. The DMA controller fills a block of `BLOCK = 4` samples into a RAM buffer, raises a *transfer-complete* interrupt, and must then be given the address of the **next** buffer before it continues. You have **two** buffers (ping and pong). While the DMA fills one, a task processes the other. If the task is too slow, you must **drop a block** rather than let the DMA overwrite a buffer the task is still using.

```c
#define BLOCK 4

void dma_start(uint16_t *first);          /* provided: call once in app_start(): DMA fills `first` */
void dma_set_next(uint16_t *next);        /* provided: ISR only: buffer for the following block */
void dma_overrun(void);                   /* provided: ISR only: "the block just completed is dropped" */
void process_block(const uint16_t *blk);  /* provided: task context: processes BLOCK samples (W ticks) */

void dma_complete_isr(void);              /* you write: transfer-complete ISR */
void app_start(void);                     /* you write */
```

**The DMA model.** At each completion tick, the block that just finished is in the buffer the DMA was filling. Then `dma_complete_isr()` runs. **Every** call must call `dma_set_next()` exactly once: from that moment, the DMA writes the next block into that buffer. Giving the DMA a buffer whose block has not been fully processed yet is a data-corruption bug, and the judge reports it as `FAIL`.

**Your protocol.**
- Two static buffers `uint16_t buf[2][BLOCK]`. `app_start()` calls `dma_start(buf[0])`, creates a handoff channel (a queue of buffer indexes, or a task notification), and creates the processing task with **priority 4**.
- In the ISR, let `done` be the buffer just completed and `other` the other one.
  - If `other` is free (the task has finished with it): hand `done` to the task, `dma_set_next(other)`, yield as needed.
  - Otherwise: call `dma_overrun()` (the block in `done` is dropped) and `dma_set_next(done)`, so the DMA refills the same buffer.
- The task waits for a buffer, calls `process_block(buf[i])`, and only **after** it returns marks buffer `i` free again.

**How it is tested.** A background task with priority 1 is always busy. Completions happen at the given ticks. Block `k` contains the samples `4k .. 4k+3`. `process_block()` prints `[t=<now>] block <k> in buffer <A|B> (completed t=<tick>)`, where A is the first buffer the DMA used. It then computes for W ticks, and it checks that blocks arrive in order, are not processed twice, and are not overwritten meanwhile. Interrupts that fire during the **last tick** of `process_block()` run **before** it returns, so at that moment the buffer is still in use. The run includes tick `D`. Final line: `blocks=<completed> processed=<n> dropped=<n> errors=<n>`.

**Input**
```
D W
N
t1 t2 ... tN      (completion ticks, non-decreasing; empty line when N = 0)
```

**Example**
```
Input:
40 7
5
5 10 15 20 25

Output:
[t=5] block 0 in buffer A (completed t=5)
[t=15] block 2 in buffer B (completed t=15)
[t=25] block 4 in buffer A (completed t=25)
blocks=5 processed=3 dropped=2 errors=0
```
- t=5: block 0 is in A. B is free: hand A to the task and give B to the DMA. The task processes A during ticks 6-12.
- t=10: block 1 completes in B, but A is still being processed. Drop block 1 and let the DMA refill B.
- t=12: the task finishes and frees A.
- t=15: block 2 completes in B. A is free: hand B over and give A to the DMA.
- t=20: block 3 completes in A while B is busy, so it is dropped.
- t=25: block 4 completes in A and is handed over.
@@@ constraints_md
- 1 <= D <= 20000, 0 <= W <= 20, 0 <= N <= 500, 1 <= ti <= D.
- Exactly two buffers, one processing task (priority 4). `dma_set_next()` exactly once per ISR call.
- Only `...FromISR()` APIs and the two provided DMA calls inside the ISR.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

#define BLOCK 4

void dma_start(uint16_t *first);           /* provided */
void dma_set_next(uint16_t *next);         /* provided (ISR only) */
void dma_overrun(void);                    /* provided (ISR only) */
void process_block(const uint16_t *blk);   /* provided */

static uint16_t s_buf[2][BLOCK];

static void dsp_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: wait for a full buffer, process it, then mark it free */
        vTaskDelay(1000);
    }
}

void dma_complete_isr(void)
{
    /* TODO: hand over or drop, and always give the DMA its next buffer */
    dma_set_next(s_buf[0]);
}

void app_start(void)
{
    dma_start(s_buf[0]);
    /* TODO: create the handoff channel and the task (priority 4) */
    (void)dsp_task;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

#define BLOCK 4
#define MAXEV 500
#define MAXBUF 4

void dma_start(uint16_t *first);
void dma_set_next(uint16_t *next);
void dma_overrun(void);
void process_block(const uint16_t *blk);
void dma_complete_isr(void);
void app_start(void);

static uint16_t *g_bufs[MAXBUF];
static int g_nbufs;
static int g_buf_block[MAXBUF];        /* block stored in the buffer, -1 if none */
static int g_owned[MAXBUF];            /* 1 while that block still has to be processed */
static uint16_t *g_target;             /* where the DMA writes the next block */
static uint16_t *g_next_req;
static unsigned g_completed, g_processed, g_dropped, g_errors, g_set_calls, g_overrun_calls, g_cost;
static TickType_t g_done_tick[MAXEV];
static int g_dropflag[MAXEV];
static int g_next_expected, g_stall_reported;

static int buf_id(const uint16_t *p)
{
    int i;
    for (i = 0; i < g_nbufs; i++)
        if (g_bufs[i] == p) return i;
    return -1;
}

static int register_buf(uint16_t *p)
{
    int id = buf_id(p);
    if (id < 0 && p != NULL && g_nbufs < MAXBUF) {
        id = g_nbufs++;
        g_bufs[id] = p;
        g_buf_block[id] = -1;
        g_owned[id] = 0;
    }
    return id;
}

void dma_start(uint16_t *first)
{
    if (xTaskGetSchedulerState() != taskSCHEDULER_NOT_STARTED || g_target != NULL || first == NULL) {
        printf("FAIL: dma_start() must be called once, from app_start(), with a valid buffer\n");
        g_errors++;
        return;
    }
    register_buf(first);
    g_target = first;
}

void dma_set_next(uint16_t *next)
{
    if (!xPortIsInsideInterrupt()) {
        printf("FAIL: dma_set_next() must be called from the DMA ISR\n");
        g_errors++;
        return;
    }
    g_set_calls++;
    g_next_req = next;
}

void dma_overrun(void)
{
    if (!xPortIsInsideInterrupt()) {
        printf("FAIL: dma_overrun() must be called from the DMA ISR\n");
        g_errors++;
        return;
    }
    g_overrun_calls++;
}

static int block_intact(int id, int k)
{
    int i;
    if (g_buf_block[id] != k) return 0;
    for (i = 0; i < BLOCK; i++)
        if (g_bufs[id][i] != (uint16_t)(k * BLOCK + i)) return 0;
    return 1;
}

void process_block(const uint16_t *blk)
{
    unsigned now = (unsigned)xTaskGetTickCount();
    int id, k, e;

    if (xPortIsInsideInterrupt()) {
        printf("FAIL: process_block() called from the ISR\n");
        g_errors++;
        return;
    }
    id = buf_id(blk);
    if (id < 0 || g_buf_block[id] < 0) {
        printf("[t=%u] FAIL: process_block() on a buffer that holds no completed block\n", now);
        g_errors++;
        return;
    }
    k = g_buf_block[id];
    if (!block_intact(id, k)) {
        printf("[t=%u] FAIL: buffer %c is corrupted\n", now, 'A' + id);
        g_errors++;
        return;
    }
    if (!g_owned[id]) {
        printf("[t=%u] FAIL: block %d was dropped or already processed\n", now, k);
        g_errors++;
        return;
    }
    e = g_next_expected;
    while (e < (int)g_completed && g_dropflag[e]) e++;
    if (k != e) {
        printf("[t=%u] FAIL: block %d processed, but block %d was expected next\n", now, k, e);
        g_errors++;
    }
    g_next_expected = k + 1;
    printf("[t=%u] block %d in buffer %c (completed t=%u)\n", now, k, 'A' + id, (unsigned)g_done_tick[k]);
    g_processed++;
    if (g_cost) vSimBusyWork((TickType_t)g_cost);
    if (!block_intact(id, k)) {
        printf("[t=%u] FAIL: block %d was overwritten by the DMA while being processed\n",
               (unsigned)xTaskGetTickCount(), k);
        g_errors++;
    }
    g_owned[id] = 0;
}

/*USER_CODE*/

static void dma_irq(void *arg)
{
    unsigned now = (unsigned)xTaskGetTickCountFromISR();
    int id, k, i, nid;

    (void)arg;
    if (g_target == NULL) {             /* the DMA was never (re)armed: data is lost */
        if (!g_stall_reported) printf("[t=%u] FAIL: DMA stalled, no next buffer was given\n", now);
        g_stall_reported = 1;
        g_errors++;
        return;
    }
    id = buf_id(g_target);
    k = (int)g_completed++;
    for (i = 0; i < BLOCK; i++) g_target[i] = (uint16_t)(k * BLOCK + i);
    g_buf_block[id] = k;
    g_owned[id] = 1;
    g_done_tick[k] = (TickType_t)now;

    g_set_calls = 0;
    g_overrun_calls = 0;
    g_next_req = NULL;
    dma_complete_isr();

    if (g_overrun_calls > 1) {
        printf("[t=%u] FAIL: dma_overrun() called %u times for one block\n", now, g_overrun_calls);
        g_errors++;
    }
    if (g_overrun_calls) {
        g_dropflag[k] = 1;
        g_dropped++;
        g_owned[id] = 0;
    }
    if (g_set_calls != 1) {
        printf("[t=%u] FAIL: dma_set_next() called %u times in one ISR (must be exactly once)\n", now, g_set_calls);
        g_errors++;
    }
    nid = register_buf(g_next_req);
    if (nid < 0) {
        g_target = NULL;
        return;
    }
    if (g_owned[nid]) {
        printf("[t=%u] FAIL: DMA restarted into buffer %c while block %d in it is still in use\n", now, 'A' + nid,
               g_buf_block[nid]);
        g_errors++;
    }
    g_target = g_next_req;
}

static void background_task(void *p)
{
    (void)p;
    for (;;) vSimBusyWork(1);
}

int main(void)
{
    unsigned d, n, i, t;

    if (scanf("%u %u %u", &d, &g_cost, &n) != 3 || n > MAXEV) return 1;
    app_start();
    if (g_target == NULL) {
        printf("FAIL: app_start() did not call dma_start()\n");
        g_errors++;
    }
    xTaskCreate(background_task, "bg", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    for (i = 0; i < n; i++) {
        if (scanf("%u", &t) != 1) return 1;
        xSimScheduleInterrupt((TickType_t)t, dma_irq, NULL);
    }
    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();
    printf("blocks=%u processed=%u dropped=%u errors=%u\n", g_completed, g_processed, g_dropped, g_errors);
    return 0;
}
@@@ sample_input
40 7
5
5 10 15 20 25
@@@ sample_output
[t=5] block 0 in buffer A (completed t=5)
[t=15] block 2 in buffer B (completed t=15)
[t=25] block 4 in buffer A (completed t=25)
blocks=5 processed=3 dropped=2 errors=0
@@@ sample_input
30 3
4
5 10 15 20
@@@ sample_output
[t=5] block 0 in buffer A (completed t=5)
[t=10] block 1 in buffer B (completed t=10)
[t=15] block 2 in buffer A (completed t=15)
[t=20] block 3 in buffer B (completed t=20)
blocks=4 processed=4 dropped=0 errors=0
@@@ hidden_input
100 4
0
<<BLANK>>
@@@ hidden_output
blocks=0 processed=0 dropped=0 errors=0
@@@ hidden_input
30 5
5
5 10 15 20 25
@@@ hidden_output
[t=5] block 0 in buffer A (completed t=5)
[t=15] block 2 in buffer B (completed t=15)
[t=25] block 4 in buffer A (completed t=25)
blocks=5 processed=3 dropped=2 errors=0

@@@ hidden_input
20 0
8
1 1 2 2 2 3 19 20
@@@ hidden_output
[t=1] block 0 in buffer A (completed t=1)
[t=2] block 2 in buffer B (completed t=2)
[t=3] block 5 in buffer A (completed t=3)
[t=19] block 6 in buffer B (completed t=19)
[t=20] block 7 in buffer A (completed t=20)
blocks=8 processed=5 dropped=3 errors=0

@@@ hidden_input
60 4
10
1 3 5 7 9 11 13 15 17 60
@@@ hidden_output
[t=1] block 0 in buffer A (completed t=1)
[t=7] block 3 in buffer B (completed t=7)
[t=13] block 6 in buffer A (completed t=13)
[t=60] block 9 in buffer B (completed t=60)
blocks=10 processed=4 dropped=6 errors=0

@@@ hidden_input
20000 2
6
1 2 3 4 10000 20000
@@@ hidden_output
[t=1] block 0 in buffer A (completed t=1)
[t=4] block 3 in buffer B (completed t=4)
[t=10000] block 4 in buffer A (completed t=10000)
[t=20000] block 5 in buffer B (completed t=20000)
blocks=6 processed=4 dropped=2 errors=0

@@@ hidden_input
50 6
7
3 3 9 10 16 17 50
@@@ hidden_output
[t=3] block 0 in buffer A (completed t=3)
[t=10] block 3 in buffer B (completed t=10)
[t=17] block 5 in buffer A (completed t=17)
[t=50] block 6 in buffer B (completed t=50)
blocks=7 processed=4 dropped=3 errors=0

@@@ hint
Keep a `volatile` flag per buffer, `s_in_use[2]`, set by the ISR when it hands a buffer to the task and cleared by the task after `process_block()` returns. The ISR also remembers which index the DMA is currently filling. The handoff can be a queue of `uint8_t` of length 1 (the task can never be offered more than one buffer it has not finished).
@@@ hint
ISR: `done = s_dma_idx; other = 1 - done; if (!s_in_use[other]) { s_in_use[done] = 1; xQueueSendFromISR(q, &done, &woken); s_dma_idx = other; dma_set_next(s_buf[other]); } else { dma_overrun(); dma_set_next(s_buf[done]); } portYIELD_FROM_ISR(woken);`. Clear the flag only after `process_block()` returns: the buffer is still being read until then.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

#define BLOCK 4

void dma_start(uint16_t *first);           /* provided */
void dma_set_next(uint16_t *next);         /* provided (ISR only) */
void dma_overrun(void);                    /* provided (ISR only) */
void process_block(const uint16_t *blk);   /* provided */

static uint16_t s_buf[2][BLOCK];
static volatile uint8_t s_in_use[2];       /* 1: owned by the task (queued or being processed) */
static uint8_t s_dma_idx;                  /* buffer the DMA is filling (ISR-only state) */
static QueueHandle_t s_full_q;             /* indexes of full buffers, ISR -> task */

static void dsp_task(void *pvParameters)
{
    uint8_t idx;

    (void)pvParameters;
    for (;;) {
        if (xQueueReceive(s_full_q, &idx, portMAX_DELAY) != pdPASS) continue;
        process_block(s_buf[idx]);
        s_in_use[idx] = 0;                 /* single-byte store: atomic; only now may the DMA reuse it */
    }
}

void dma_complete_isr(void)
{
    BaseType_t woken = pdFALSE;
    uint8_t done = s_dma_idx;
    uint8_t other = (uint8_t)(1u - done);

    if (!s_in_use[other]) {
        s_in_use[done] = 1;                /* ownership passes to the task */
        xQueueSendFromISR(s_full_q, &done, &woken);   /* cannot fail: at most one buffer in flight */
        s_dma_idx = other;
        dma_set_next(s_buf[other]);        /* ping -> pong */
    } else {
        dma_overrun();                     /* task still busy with `other`: drop this block */
        dma_set_next(s_buf[done]);         /* refill the same buffer */
    }
    portYIELD_FROM_ISR(woken);
}

void app_start(void)
{
    s_full_q = xQueueCreate(1, sizeof(uint8_t));
    configASSERT(s_full_q != NULL);
    s_dma_idx = 0;
    dma_start(s_buf[0]);
    xTaskCreate(dsp_task, "dsp", configMINIMAL_STACK_SIZE, NULL, 4, NULL);
}
@@@ explanation_md
**Approach.** Every buffer has exactly one owner at any time: the **DMA** (being filled), the **task** (queued or being processed), or nobody (free). The whole design is about passing ownership explicitly.
- The completion ISR takes the just-filled buffer from the DMA. If the other buffer is free, the ISR passes the filled one to the task and the free one to the DMA.
- If the other buffer is still owned by the task, there is no safe buffer for the DMA except the one just filled. Its block is sacrificed (`dma_overrun()`), and the DMA refills it. Dropping the **newest** block is the only option that never touches memory the task is reading.
- The task returns ownership only after `process_block()` has finished reading.

The flag is written by the task and read by the ISR. A single byte store is atomic, so `volatile` is enough here. A multi-field ownership record would need a critical section on the task side.

The ISR always calls `dma_set_next()`: forgetting it on the drop path stalls the DMA, and every later block is lost.

Notice the tick-boundary detail in hidden tests such as `W=5` with completions every 5 ticks. The completion at t=10 runs inside the last tick of `process_block()`, before the task has released the buffer, so it is dropped. On real hardware this is the same race, where it decides between "just in time" and "dropped". Design for a margin.

**Complexity.** ISR: O(1), no copying (zero-copy is the point of DMA double buffering). Task: O(BLOCK) plus W ticks per block. RAM: 2 x BLOCK samples, a 1-item queue, one stack. Throughput condition: the processing time per block must stay below the block period, or blocks are dropped (at most every other block is processed).

**Common mistakes**
- Freeing the buffer *before* processing it (or copying it in a hurry), or never freeing it.
- Giving the DMA the other buffer unconditionally (a "blind" ping-pong): the DMA then overwrites the block the task is reading. That is the `FAIL: DMA restarted into buffer ...` path.
- Not calling `dma_set_next()` on the overrun path: the DMA stalls forever.
- A queue longer than needed with no ownership tracking: the queue may hold an index whose buffer has already been refilled.
- Calling `xQueueSend()` instead of `xQueueSendFromISR()`, or forgetting the yield, so the task starts one tick late and the budget shrinks.

**Interview follow-ups**
- STM32 DMA has a hardware double-buffer mode (DBM, `CT` bit) and half-transfer interrupts. How do they change this design?
- With a data cache (Cortex-M7), what must you do before the task reads a DMA buffer (cache invalidate, alignment, non-cacheable MPU region)?
- How would a third buffer (triple buffering) change the drop rate, and how would you generalise ownership with a free-list queue?
- Would you rather drop the newest block or stop the DMA? What does an audio or knock-detection algorithm prefer?
