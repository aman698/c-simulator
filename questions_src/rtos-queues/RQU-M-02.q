@@@ meta
id: RQU-M-02
topic: Queues
difficulty: Medium
type: FUNCTION
title: Urgent Motor Commands Jump the Queue With xQueueSendToFrontFromISR
tags: freertos, queue, xqueuesendtofront, isr, portyield-from-isr, embedded, asked-in-automotive
@@@ statement_md
A motor-control ECU receives commands over a bus. The receive interrupt hands every command to a worker task through a queue of **4** commands. Normal commands are executed in arrival order. An **urgent** command (for example an emergency stop) must be executed **next**, before everything already waiting. Use the queue as a FIFO for normal commands, and put urgent commands at the **front**.

```c
typedef struct {
    uint16_t id;
    uint8_t  urgent;   /* 1 = urgent, 0 = normal */
    uint8_t  cost;     /* execution time in ticks */
} Cmd;

void execute(const Cmd *c);  /* provided (task context only): prints "[t=<tick>] start #<id>",
                                runs for c->cost ticks, then prints "[t=<tick>] done #<id>" */
void reject(const Cmd *c);   /* provided (ISR-safe): prints "[t=<tick>] REJECT #<id>" */

QueueHandle_t app_start(void);  /* you write this: create the queue and the worker, return the queue */
void cmd_rx_isr(const Cmd *c);  /* you write this: called by the harness IN INTERRUPT CONTEXT */
```

Requirements:

- `app_start()` creates a queue of **4** items of type `Cmd` and a **worker** task with priority **3**. The worker does forever: `xQueueReceive(q, &cmd, portMAX_DELAY)`, then `execute(&cmd)`.
- `cmd_rx_isr()` runs inside an interrupt, so it may only use `...FromISR()` APIs:
  - normal command: `xQueueSendToBackFromISR()`;
  - urgent command: `xQueueSendToFrontFromISR()`;
  - if the queue is full, the command is lost: call `reject(c)`;
  - finish with `portYIELD_FROM_ISR(xHigherPriorityTaskWoken)`, so an idle worker starts the command **at the same tick**.
- `c` points to the harness's buffer and is only valid during the call, so the queue must hold copies.

Note what "front" means when several urgent commands are waiting: each one is inserted before the previous one, so **the most recent urgent command runs first** (LIFO among urgent commands).

**How it is tested.** The hidden `main()` reads a list of received commands. For each one it schedules an interrupt that prints `[t=<tick>] rx #<id>` (plus ` URGENT`) and calls `cmd_rx_isr()`. It then runs the scheduler up to and including tick `D`, and prints how many commands were executed and rejected and how many are still waiting. Several interrupts at the same tick run back to back, in input order, **before** any task runs. A command that is still executing at tick `D` has printed `start` but not `done`.

**Input**
```
<n>
<tick> <id> <N|U> <cost>     (n lines, sorted by tick)
<D>
```

**Example**
```
Input:
4
1 1 N 5
2 2 N 3
3 3 N 2
4 4 U 1
30

Output:
[t=1] rx #1
[t=1] start #1
[t=2] rx #2
[t=3] rx #3
[t=4] rx #4 URGENT
[t=6] done #1
[t=6] start #4
[t=7] done #4
[t=7] start #2
[t=10] done #2
[t=10] start #3
[t=12] done #3
executed 4, rejected 0, waiting 0
```
Command 1 wakes the idle worker, and thanks to `portYIELD_FROM_ISR` it starts at t=1. Commands 2 and 3 queue up while it runs. The urgent command 4 is inserted in front of them, so it runs right after command 1 finishes.
@@@ constraints_md
- 0 <= n <= 64, 1 <= tick <= D <= 10000, 1 <= cost <= 50, ids are distinct.
- Queue length exactly 4, item size `sizeof(Cmd)`. One worker task, priority 3, stack `configMINIMAL_STACK_SIZE`.
- `cmd_rx_isr()` must not block and must only call `...FromISR()` APIs (a task API there is a Runtime Error).
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    uint16_t id;
    uint8_t  urgent;
    uint8_t  cost;
} Cmd;

void execute(const Cmd *c);
void reject(const Cmd *c);

static void worker_task(void *pvParameters)
{
    /* TODO: forever: receive a Cmd (block), execute(&cmd) */
    (void)pvParameters;
    for (;;) {
        vTaskDelay(1000);
    }
}

QueueHandle_t app_start(void)
{
    /* TODO: create the queue (4 x Cmd) and the worker task (priority 3) */
    (void)worker_task;
    return NULL;
}

void cmd_rx_isr(const Cmd *c)
{
    /* TODO: urgent -> front, normal -> back, full -> reject(c), then portYIELD_FROM_ISR */
    (void)c;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

static unsigned g_exec, g_rej;

/*USER_CODE*/

void execute(const Cmd *c)
{
    printf("[t=%u] start #%u\n", (unsigned)xTaskGetTickCount(), (unsigned)c->id);
    vSimBusyWork((TickType_t)c->cost);
    printf("[t=%u] done #%u\n", (unsigned)xTaskGetTickCount(), (unsigned)c->id);
    g_exec++;
}

void reject(const Cmd *c)
{
    printf("[t=%u] REJECT #%u\n", (unsigned)xTaskGetTickCount(), (unsigned)c->id);
    g_rej++;
}

static Cmd g_cmds[64];
static Cmd g_isr_buf;   /* the "bus receive buffer": reused for every interrupt */

static void rx_irq(void *arg)
{
    const Cmd *src = (const Cmd *)arg;
    g_isr_buf = *src;
    printf("[t=%u] rx #%u%s\n", (unsigned)xTaskGetTickCountFromISR(), (unsigned)src->id,
           src->urgent ? " URGENT" : "");
    cmd_rx_isr(&g_isr_buf);
    g_isr_buf.id = 0xFFFF;   /* buffer is overwritten after the call */
    g_isr_buf.cost = 0;
}

int main(void)
{
    unsigned n, i, tick, id, cost, dur;
    char kind[4];
    QueueHandle_t q;

    if (scanf("%u", &n) != 1 || n > 64) return 1;
    for (i = 0; i < n; i++) {
        if (scanf("%u %u %3s %u", &tick, &id, kind, &cost) != 4) return 1;
        g_cmds[i].id = (uint16_t)id;
        g_cmds[i].urgent = (uint8_t)(kind[0] == 'U');
        g_cmds[i].cost = (uint8_t)cost;
        xSimScheduleInterrupt((TickType_t)tick, rx_irq, &g_cmds[i]);
    }
    if (scanf("%u", &dur) != 1) return 1;

    q = app_start();
    if (q == NULL) {
        printf("ERROR: app_start() returned no queue\n");
        return 0;
    }
    if (uxQueueGetQueueLength(q) != 4 || uxQueueGetQueueItemSize(q) != sizeof(Cmd)) {
        printf("ERROR: the queue must hold 4 items of sizeof(Cmd)\n");
        return 0;
    }
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("executed %u, rejected %u, waiting %u\n", g_exec, g_rej, (unsigned)uxQueueMessagesWaiting(q));
    return 0;
}
@@@ sample_input
4
1 1 N 5
2 2 N 3
3 3 N 2
4 4 U 1
30
@@@ sample_output
[t=1] rx #1
[t=1] start #1
[t=2] rx #2
[t=3] rx #3
[t=4] rx #4 URGENT
[t=6] done #1
[t=6] start #4
[t=7] done #4
[t=7] start #2
[t=10] done #2
[t=10] start #3
[t=12] done #3
executed 4, rejected 0, waiting 0
@@@ sample_input
6
5 10 N 4
5 11 N 4
5 12 U 2
5 13 U 2
5 14 N 1
5 15 N 1
40
@@@ sample_output
[t=5] rx #10
[t=5] rx #11
[t=5] rx #12 URGENT
[t=5] rx #13 URGENT
[t=5] rx #14
[t=5] REJECT #14
[t=5] rx #15
[t=5] REJECT #15
[t=5] start #13
[t=7] done #13
[t=7] start #12
[t=9] done #12
[t=9] start #10
[t=13] done #10
[t=13] start #11
[t=17] done #11
executed 4, rejected 2, waiting 0
@@@ hidden_input
0
10
@@@ hidden_output
executed 0, rejected 0, waiting 0
@@@ hidden_input
2
3 7 U 2
20 8 N 3
20
@@@ hidden_output
[t=3] rx #7 URGENT
[t=3] start #7
[t=5] done #7
[t=20] rx #8
[t=20] start #8
executed 1, rejected 0, waiting 0
@@@ hidden_input
7
1 1 N 10
2 2 N 1
3 3 N 1
4 4 N 1
5 5 N 1
6 6 U 1
7 7 U 1
40
@@@ hidden_output
[t=1] rx #1
[t=1] start #1
[t=2] rx #2
[t=3] rx #3
[t=4] rx #4
[t=5] rx #5
[t=6] rx #6 URGENT
[t=6] REJECT #6
[t=7] rx #7 URGENT
[t=7] REJECT #7
[t=11] done #1
[t=11] start #2
[t=12] done #2
[t=12] start #3
[t=13] done #3
[t=13] start #4
[t=14] done #4
[t=14] start #5
[t=15] done #5
executed 5, rejected 2, waiting 0

@@@ hidden_input
5
10 21 N 3
10 22 U 3
13 23 U 2
13 24 N 2
15 25 U 1
12
@@@ hidden_output
[t=10] rx #21
[t=10] rx #22 URGENT
[t=10] start #22
executed 0, rejected 0, waiting 1

@@@ hidden_input
12
2 100 N 7
4 101 U 2
4 102 N 3
6 103 U 4
9 104 N 2
9 105 N 2
9 106 N 2
9 107 U 1
30 108 N 5
31 109 U 5
32 110 U 5
50 111 N 1
200
@@@ hidden_output
[t=2] rx #100
[t=2] start #100
[t=4] rx #101 URGENT
[t=4] rx #102
[t=6] rx #103 URGENT
[t=9] rx #104
[t=9] rx #105
[t=9] REJECT #105
[t=9] rx #106
[t=9] REJECT #106
[t=9] rx #107 URGENT
[t=9] REJECT #107
[t=9] done #100
[t=9] start #103
[t=13] done #103
[t=13] start #101
[t=15] done #101
[t=15] start #102
[t=18] done #102
[t=18] start #104
[t=20] done #104
[t=30] rx #108
[t=30] start #108
[t=31] rx #109 URGENT
[t=32] rx #110 URGENT
[t=35] done #108
[t=35] start #110
[t=40] done #110
[t=40] start #109
[t=45] done #109
[t=50] rx #111
[t=50] start #111
[t=51] done #111
executed 9, rejected 3, waiting 0

@@@ hidden_input
3
9999 1 N 1
9999 2 U 1
10000 3 U 1
10000
@@@ hidden_output
[t=9999] rx #1
[t=9999] rx #2 URGENT
[t=9999] start #2
[t=10000] rx #3 URGENT
[t=10000] done #2
[t=10000] start #3
executed 1, rejected 0, waiting 1

@@@ hint
In an ISR use the `FromISR` variants. They never block, return `errQUEUE_FULL` when there is no space, and report through `pxHigherPriorityTaskWoken` whether a task waiting on the queue was woken. That flag is what you pass to `portYIELD_FROM_ISR()`.
@@@ hint
`BaseType_t woken = pdFALSE; BaseType_t ok = c->urgent ? xQueueSendToFrontFromISR(q, c, &woken) : xQueueSendToBackFromISR(q, c, &woken); if (ok != pdPASS) reject(c); portYIELD_FROM_ISR(woken);`. The queue copies `*c`, so the harness may reuse its buffer right after the call.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    uint16_t id;
    uint8_t  urgent;
    uint8_t  cost;
} Cmd;

void execute(const Cmd *c);
void reject(const Cmd *c);

static QueueHandle_t s_cmdq;

static void worker_task(void *pvParameters)
{
    Cmd cmd;

    (void)pvParameters;
    for (;;) {
        if (xQueueReceive(s_cmdq, &cmd, portMAX_DELAY) == pdPASS) {
            execute(&cmd);
        }
    }
}

QueueHandle_t app_start(void)
{
    s_cmdq = xQueueCreate(4, sizeof(Cmd));
    if (s_cmdq == NULL) {
        return NULL;
    }
    xTaskCreate(worker_task, "worker", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
    return s_cmdq;
}

void cmd_rx_isr(const Cmd *c)
{
    BaseType_t woken = pdFALSE;
    BaseType_t ok;

    if (c->urgent) {
        ok = xQueueSendToFrontFromISR(s_cmdq, c, &woken);   /* next to be received */
    } else {
        ok = xQueueSendToBackFromISR(s_cmdq, c, &woken);    /* plain FIFO */
    }
    if (ok != pdPASS) {
        reject(c);                                          /* ISR cannot wait for space */
    }
    portYIELD_FROM_ISR(woken);   /* idle worker starts at this tick, not the next one */
}
@@@ explanation_md
**Approach.** A FreeRTOS queue is a ring buffer with a write pointer (back) and a read pointer (front):
- `xQueueSendToBack` writes at the back, which gives normal FIFO order.
- `xQueueSendToFront` writes the item just **before** the read pointer, so the next receive returns it.

That gives a two-class priority scheme with zero extra memory. It has one subtle property: if two urgent commands wait, the newer one is in front, so urgent commands are LIFO among themselves (sample 2: #13 before #12).

From an interrupt, only the `FromISR` variants may be used. They never block: a full queue simply returns `errQUEUE_FULL`, so the ISR has to decide what to do with the command (here: `reject`). They also do not switch context themselves. They set `*pxHigherPriorityTaskWoken`, and `portYIELD_FROM_ISR()` requests the switch when the interrupt returns. Without it the idle worker starts one tick late (in the hidden test at `t = D` it does not start at all).

**Complexity.** Per command: O(1) in the ISR (one copy of `sizeof(Cmd)` = 4 bytes, no loop), O(1) in the worker. RAM: 4 x 4 bytes plus the queue control block. Worst-case latency for an urgent command = remaining execution time of the command in progress (no preemption of an executing command). For a normal command, add the cost of everything queued before it, plus every urgent command that arrives meanwhile.

**Common mistakes**
- Calling `xQueueSendToFront()` / `xQueueSend()` (the task versions) from the ISR: illegal, a Runtime Error here and a hard fault or a corrupted scheduler on target.
- Forgetting `portYIELD_FROM_ISR()`: the worker wakes on the next tick instead of immediately.
- Queueing a **pointer** to the ISR's receive buffer: the buffer is overwritten by the next frame before the worker reads it.
- Assuming urgent commands stay FIFO among themselves.
- Trying to "wait for space" in the ISR (a loop on a full queue): the worker can never run while the ISR spins.

**Interview follow-ups**
- How would you keep urgent commands FIFO among themselves? (Two queues and a queue set, or a separate urgent queue checked first.)
- An emergency stop must not wait for a 50 ms command to finish. How would you abort the current command? (Task notification or event bit polled by `execute`, or a higher-priority safety task.)
- What if the queue is full when an urgent command arrives? Discuss reserving slots and overwrite policies.
- Why does `xQueueSendToFrontFromISR` not take a timeout parameter?
