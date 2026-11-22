@@@ meta
id: RDS-M-02
topic: RTOS Design Patterns
difficulty: Medium
type: FUNCTION
title: Command Dispatcher With High Normal And Low Priority Lanes
tags: freertos, command-dispatcher, priority-queue, counting-semaphore, xqueuesendfromisr, embedded, asked-in-automotive
@@@ statement_md
A diagnostic gateway receives commands over CAN. Each command belongs to a **lane**: `HIGH` (safety requests), `NORMAL` (diagnostic services) or `LOW` (logging and housekeeping). A single dispatcher task executes them one at a time, and must always prefer the most urgent lane.

```c
typedef enum { LANE_HIGH, LANE_NORMAL, LANE_LOW } Lane;
typedef struct { uint16_t id; uint8_t lane; uint8_t cost; } Cmd;

/* provided by the judge */
void cmd_execute(const Cmd *c); /* prints "[t=<tick>] EXEC <id> <LANE>", then keeps the CPU busy for c->cost ticks */
void cmd_reject(const Cmd *c);  /* prints "[t=<tick>] REJECT <id> <LANE>"; may be called from an ISR */

/* you write these */
void dispatcher_start(void);          /* called before the scheduler starts */
void cmd_post_from_isr(const Cmd *c); /* called from the CAN RX interrupt */
```

Requirements:

- `dispatcher_start()` creates **one queue per lane, each of length 4**, holding `Cmd` **by value**, and a dispatcher task named `"DISP"` with priority **3**.
- `cmd_post_from_isr()` copies the command into its lane's queue. If that lane is full, it calls `cmd_reject(c)`, and the other lanes are not used. It wakes the dispatcher and calls `portYIELD_FROM_ISR()` when needed.
- The dispatcher blocks while all lanes are empty (no polling, no `vTaskDelay` loops). Each time it is free, it takes the **oldest command of the highest-priority non-empty lane** and calls `cmd_execute()`. A running command is never interrupted by a newer one: lane priority only decides which command starts next.

**How it is tested.** The hidden `main()` calls `dispatcher_start()`, creates a background task of priority 1 that keeps the CPU busy, and schedules one CAN interrupt per input line. Each interrupt calls `cmd_post_from_isr()`. The scheduler runs up to tick `D`. The judge keeps its own list of accepted commands, and `cmd_execute()` prints `FAIL: wrong command` if the started command is not the one the rules require. At the end it prints how many commands of each lane were executed, how many were rejected, and the longest wait of a HIGH command (start tick - arrival tick).

All interrupts of a tick run before any task. So commands arriving at the same tick are all queued (or rejected) before the dispatcher picks one.

**Input**
```
<D>
<m>
<tick> <id> <H|N|L> <cost>     (m lines, ticks non-decreasing)
```

**Example**
```
Input:
100
6
5 1 L 10
6 2 N 3
7 3 H 2
8 4 L 1
8 5 H 1
30 6 N 0

Output:
[t=5] EXEC 1 LOW
[t=15] EXEC 3 HIGH
[t=17] EXEC 5 HIGH
[t=18] EXEC 2 NORMAL
[t=21] EXEC 4 LOW
[t=30] EXEC 6 NORMAL
executed HIGH=2 NORMAL=2 LOW=2 rejected=0
max HIGH wait=9
```
Command 1 starts at once and runs until t=15. By then commands 2, 3, 4 and 5 are waiting. The two HIGH ones go first, in arrival order (3, then 5), then the NORMAL one, then the LOW one. Command 5 waited from t=8 to t=17.
@@@ constraints_md
- 1 <= D <= 5000, 0 <= m <= 60, 1 <= tick < D, 0 <= cost <= 50, ids unique.
- Lane queues: length 4, element type `Cmd`. Dispatcher: name `"DISP"`, priority 3, stack `configMINIMAL_STACK_SIZE`.
- Only `cmd_execute()` consumes CPU time.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"

typedef enum { LANE_HIGH, LANE_NORMAL, LANE_LOW } Lane;
typedef struct { uint16_t id; uint8_t lane; uint8_t cost; } Cmd;

void cmd_execute(const Cmd *c);
void cmd_reject(const Cmd *c);

static void dispatcher_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: block until a command is available, take the most urgent one, execute it */
        vTaskDelay(1000);
    }
}

void dispatcher_start(void)
{
    /* TODO: three lane queues (length 4) + the "DISP" task (priority 3) */
    (void)dispatcher_task;
}

void cmd_post_from_isr(const Cmd *c)
{
    /* TODO */
    (void)c;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "sim.h"

/*USER_CODE*/

static const char *const k_lane[] = { "HIGH", "NORMAL", "LOW" };

typedef struct {
    Cmd cmd;
    unsigned tick;
    int state;          /* 0 not arrived, 1 pending, 2 started, 3 rejected */
} Slot;

static Slot g_slot[60];
static int g_m;
static unsigned g_exec[3], g_rejected, g_max_high_wait;

static int slot_of(const Cmd *c)
{
    int i;
    for (i = 0; i < g_m; i++) if (g_slot[i].cmd.id == c->id) return i;
    return -1;
}

void cmd_reject(const Cmd *c)
{
    int i = slot_of(c);
    printf("[t=%u] REJECT %u %s\n", (unsigned)xTaskGetTickCountFromISR(), (unsigned)c->id,
           c->lane < 3 ? k_lane[c->lane] : "?");
    if (i >= 0 && g_slot[i].state == 1) { g_slot[i].state = 3; g_rejected++; }
}

void cmd_execute(const Cmd *c)
{
    TickType_t now = xTaskGetTickCount();
    int i = slot_of(c), j, best = -1;

    /* the rule: oldest pending command of the most urgent non-empty lane */
    for (j = 0; j < g_m; j++) {
        if (g_slot[j].state != 1) continue;
        if (best < 0 || g_slot[j].cmd.lane < g_slot[best].cmd.lane) best = j;
    }
    if (i < 0 || i != best) {
        printf("[t=%u] FAIL: wrong command %u\n", (unsigned)now, (unsigned)c->id);
        return;
    }
    printf("[t=%u] EXEC %u %s\n", (unsigned)now, (unsigned)c->id, k_lane[c->lane]);
    g_slot[i].state = 2;
    g_exec[c->lane]++;
    if (c->lane == LANE_HIGH && now - g_slot[i].tick > g_max_high_wait)
        g_max_high_wait = (unsigned)(now - g_slot[i].tick);
    vSimBusyWork((TickType_t)c->cost);
}

static void can_rx_isr(void *arg)
{
    int i = (int)(intptr_t)arg;
    Cmd copy = g_slot[i].cmd;           /* the driver's buffer: reused after the ISR */

    g_slot[i].state = 1;
    cmd_post_from_isr(&copy);
    memset(&copy, 0xA5, sizeof copy);
}

static void background_task(void *p)
{
    (void)p;
    for (;;) vSimBusyWork(1);
}

int main(void)
{
    unsigned dur, tick, id, cost;
    char lane[4];
    int i;

    if (scanf("%u %d", &dur, &g_m) != 2 || g_m < 0 || g_m > 60) return 1;
    dispatcher_start();
    xTaskCreate(background_task, "BG", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    for (i = 0; i < g_m; i++) {
        if (scanf("%u %u %3s %u", &tick, &id, lane, &cost) != 4) return 1;
        g_slot[i].cmd.id = (uint16_t)id;
        g_slot[i].cmd.lane = (uint8_t)(lane[0] == 'H' ? LANE_HIGH : lane[0] == 'N' ? LANE_NORMAL : LANE_LOW);
        g_slot[i].cmd.cost = (uint8_t)cost;
        g_slot[i].tick = tick;
        xSimScheduleInterrupt((TickType_t)tick, can_rx_isr, (void *)(intptr_t)i);
    }
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("executed HIGH=%u NORMAL=%u LOW=%u rejected=%u\n", g_exec[0], g_exec[1], g_exec[2], g_rejected);
    printf("max HIGH wait=%u\n", g_max_high_wait);
    return 0;
}
@@@ sample_input
100
6
5 1 L 10
6 2 N 3
7 3 H 2
8 4 L 1
8 5 H 1
30 6 N 0
@@@ sample_output
[t=5] EXEC 1 LOW
[t=15] EXEC 3 HIGH
[t=17] EXEC 5 HIGH
[t=18] EXEC 2 NORMAL
[t=21] EXEC 4 LOW
[t=30] EXEC 6 NORMAL
executed HIGH=2 NORMAL=2 LOW=2 rejected=0
max HIGH wait=9
@@@ sample_input
50
7
10 1 N 2
10 2 H 2
10 3 H 2
10 4 H 2
10 5 H 2
10 6 H 2
11 7 L 0
@@@ sample_output
[t=10] REJECT 6 HIGH
[t=10] EXEC 2 HIGH
[t=12] EXEC 3 HIGH
[t=14] EXEC 4 HIGH
[t=16] EXEC 5 HIGH
[t=18] EXEC 1 NORMAL
[t=20] EXEC 7 LOW
executed HIGH=4 NORMAL=1 LOW=1 rejected=1
max HIGH wait=6
@@@ hidden_input
100
0
@@@ hidden_output
executed HIGH=0 NORMAL=0 LOW=0 rejected=0
max HIGH wait=0
@@@ hidden_input
20
3
1 10 L 0
1 11 N 0
1 12 H 0
@@@ hidden_output
[t=1] EXEC 12 HIGH
[t=1] EXEC 11 NORMAL
[t=1] EXEC 10 LOW
executed HIGH=1 NORMAL=1 LOW=1 rejected=0
max HIGH wait=0
@@@ hidden_input
200
12
1 1 L 5
2 2 L 5
3 3 L 5
4 4 L 5
5 5 L 5
6 6 L 5
3 7 H 4
7 8 H 4
11 9 H 4
15 10 H 4
19 11 H 4
23 12 N 4
@@@ hidden_output
[t=1] EXEC 1 LOW
[t=6] REJECT 6 LOW
[t=6] EXEC 7 HIGH
[t=10] EXEC 8 HIGH
[t=14] EXEC 9 HIGH
[t=18] EXEC 10 HIGH
[t=22] EXEC 11 HIGH
[t=26] EXEC 12 NORMAL
[t=30] EXEC 2 LOW
[t=35] EXEC 3 LOW
[t=40] EXEC 4 LOW
[t=45] EXEC 5 LOW
executed HIGH=5 NORMAL=1 LOW=5 rejected=1
max HIGH wait=3

@@@ hidden_input
300
13
10 1 N 20
11 2 N 1
11 3 N 1
11 4 N 1
11 5 N 1
11 6 N 1
12 7 L 1
12 8 L 1
12 9 L 1
12 10 L 1
12 11 L 1
29 12 H 1
30 13 H 1
@@@ hidden_output
[t=10] EXEC 1 NORMAL
[t=11] REJECT 6 NORMAL
[t=12] REJECT 11 LOW
[t=30] EXEC 12 HIGH
[t=31] EXEC 13 HIGH
[t=32] EXEC 2 NORMAL
[t=33] EXEC 3 NORMAL
[t=34] EXEC 4 NORMAL
[t=35] EXEC 5 NORMAL
[t=36] EXEC 7 LOW
[t=37] EXEC 8 LOW
[t=38] EXEC 9 LOW
[t=39] EXEC 10 LOW
executed HIGH=2 NORMAL=5 LOW=4 rejected=2
max HIGH wait=1

@@@ hidden_input
1000
8
100 21 H 0
100 22 H 0
100 23 H 0
100 24 H 0
100 25 H 0
100 26 N 0
100 27 L 0
101 28 H 50
@@@ hidden_output
[t=100] REJECT 25 HIGH
[t=100] EXEC 21 HIGH
[t=100] EXEC 22 HIGH
[t=100] EXEC 23 HIGH
[t=100] EXEC 24 HIGH
[t=100] EXEC 26 NORMAL
[t=100] EXEC 27 LOW
[t=101] EXEC 28 HIGH
executed HIGH=5 NORMAL=1 LOW=1 rejected=1
max HIGH wait=0

@@@ hidden_input
500
10
5 101 N 7
6 102 L 3
9 103 H 2
12 104 N 7
13 105 H 9
13 106 L 1
20 107 H 0
40 108 L 4
41 109 N 4
42 110 H 4
@@@ hidden_output
[t=5] EXEC 101 NORMAL
[t=12] EXEC 103 HIGH
[t=14] EXEC 105 HIGH
[t=23] EXEC 107 HIGH
[t=23] EXEC 104 NORMAL
[t=30] EXEC 102 LOW
[t=33] EXEC 106 LOW
[t=40] EXEC 108 LOW
[t=44] EXEC 110 HIGH
[t=48] EXEC 109 NORMAL
executed HIGH=4 NORMAL=3 LOW=3 rejected=0
max HIGH wait=3

@@@ hint
The dispatcher needs one thing to block on that means "some lane has a command". A **counting semaphore** works well: the ISR gives it once per accepted command (`xSemaphoreGiveFromISR`), and the dispatcher takes it, then checks the lanes HIGH -> NORMAL -> LOW with `xQueueReceive(lane, &cmd, 0)`.
@@@ hint
Do not use a queue set and execute "the queue that became ready". `xQueueSelectFromSet()` returns queues in the order in which they received data, not by priority. A single queue with `xQueueSendToFront()` for HIGH commands breaks FIFO among the HIGH ones. In the ISR, only give the semaphore if `xQueueSendFromISR()` succeeded, OR the two "woken" flags, and yield once.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"

typedef enum { LANE_HIGH, LANE_NORMAL, LANE_LOW } Lane;
typedef struct { uint16_t id; uint8_t lane; uint8_t cost; } Cmd;

void cmd_execute(const Cmd *c);
void cmd_reject(const Cmd *c);

#define LANES      3
#define LANE_DEPTH 4

static QueueHandle_t s_lane[LANES];
static SemaphoreHandle_t s_pending;     /* counts commands sitting in all lanes */

static void dispatcher_task(void *pvParameters)
{
    Cmd c;
    int l;

    (void)pvParameters;
    for (;;) {
        xSemaphoreTake(s_pending, portMAX_DELAY);
        for (l = 0; l < LANES; l++) {               /* most urgent lane first */
            if (xQueueReceive(s_lane[l], &c, 0) == pdPASS) {
                cmd_execute(&c);
                break;
            }
        }
    }
}

void dispatcher_start(void)
{
    int l;

    for (l = 0; l < LANES; l++) s_lane[l] = xQueueCreate(LANE_DEPTH, sizeof(Cmd));
    s_pending = xSemaphoreCreateCounting(LANES * LANE_DEPTH, 0);
    xTaskCreate(dispatcher_task, "DISP", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
}

void cmd_post_from_isr(const Cmd *c)
{
    BaseType_t woken = pdFALSE;

    if (c->lane >= LANES || xQueueSendFromISR(s_lane[c->lane], c, &woken) != pdPASS) {
        cmd_reject(c);
        return;
    }
    xSemaphoreGiveFromISR(s_pending, &woken);
    portYIELD_FROM_ISR(woken);
}
@@@ explanation_md
**Approach.** One queue per lane keeps FIFO order inside a lane for free. A **counting semaphore** counts the commands waiting in all lanes. The dispatcher blocks on it, so it uses no CPU while there is no work. Each take is "one command is available", and the dispatcher then scans the lanes in priority order with zero-timeout receives. The ISR gives the semaphore only after a successful enqueue, so the count always equals the number of queued commands, and the scan always finds one.

In the example, command 1 (LOW, 10 ticks) runs to completion, because commands are not preempted. When it finishes at t=15, four commands are pending, and the scan picks HIGH 3, HIGH 5, NORMAL 2, LOW 4. Sample 2 shows back-pressure per lane: the fifth HIGH command at t=10 is rejected even though the NORMAL and LOW lanes have room. This keeps a flood of one class from consuming the buffers of the others.

**Complexity.** Post: O(1). Dispatch: O(lanes) = O(3). RAM: 3 x 4 x `sizeof(Cmd)` (4 bytes) plus a semaphore. Worst-case wait of a HIGH command = the longest single command running (no preemption) + the HIGH commands queued before it. Lower lanes can **starve** under sustained HIGH traffic (hidden test with a stream of HIGH commands).

**Common mistakes**
- Using a queue set and executing whichever queue `xQueueSelectFromSet()` returns: that is arrival order, not priority order.
- One shared queue with `xQueueSendToFront()` for HIGH commands: HIGH commands then come out in reverse (LIFO) order.
- Giving the semaphore even when the enqueue failed: the dispatcher wakes with every lane empty. Or giving it before the enqueue, which is a race in a real preemptive ISR.
- Polling the three queues in a loop with `vTaskDelay(1)`: one tick of extra latency and wasted CPU.
- Storing the `const Cmd *` pointer instead of the value. The CAN driver reuses its buffer right after the ISR (the judge scribbles over it).

**Interview follow-ups**
- How do you prevent starvation of the LOW lane (aging, or a budget of N HIGH commands before one LOW)?
- How would you allow a HIGH command to abort a running LOW command (a cooperative cancel flag checked inside long commands)?
- Could you replace the counting semaphore with a task notification used as a counter (`vTaskNotifyGiveFromISR` / `ulTaskNotifyTake(pdFALSE, ...)`)?
- What changes if two dispatcher tasks share the lanes?
