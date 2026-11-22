@@@ meta
id: RQU-H-03
topic: Queues
difficulty: Hard
type: FUNCTION
title: CAN Frame Router With Per-Node Queues and Backpressure Statistics
tags: freertos, queue, can, router, backpressure, isr, embedded, asked-in-automotive
@@@ statement_md
A gateway ECU receives CAN frames in an interrupt and must dispatch each one, by identifier, to the software component ("node") that handles it. Every node has its own task and its own input queue. A slow node must **never** stall the router or the other nodes: if its queue is full, the frame for that node is dropped and counted. The statistics are read by diagnostics, so they must be exact. Implement the receive path and the router.

```c
#define MAX_NODES 4

typedef struct {
    uint16_t id;        /* 11-bit identifier */
    uint8_t  dlc;       /* 0..8 */
    uint8_t  data[8];
} CanFrame;

typedef struct {
    uint16_t    id_lo, id_hi;   /* frames with id_lo <= id <= id_hi belong to this node */
    UBaseType_t qlen;           /* length of the node's input queue */
    UBaseType_t prio;           /* priority of the node's task */
} NodeCfg;

typedef struct {
    uint32_t rx_overflow;              /* frames lost because the RX queue was full (ISR) */
    uint32_t unrouted;                 /* frames whose id matches no node */
    uint32_t delivered[MAX_NODES];     /* frames put into the node's queue */
    uint32_t dropped[MAX_NODES];       /* frames lost because the node's queue was full */
    uint32_t peak[MAX_NODES];          /* max frames waiting in the node's queue right after a delivery */
} RouterStats;

/* provided */
void node_process(unsigned node, const CanFrame *f);  /* node task only: prints "[t=..] N<node+1> id=0x... dlc=..",
                                                         then works for the node's processing time */
void on_rx_overflow(const CanFrame *f);                /* ISR-safe: prints "[t=..] RX OVERFLOW id=0x..." */
void on_unrouted(const CanFrame *f);                   /* prints "[t=..] UNROUTED id=0x..." */
void on_node_drop(unsigned node, const CanFrame *f);   /* prints "[t=..] DROP id=0x... N<node+1> full" */

/* you write */
void router_start(const NodeCfg *nodes, unsigned nnodes, UBaseType_t rxq_len);
void can_rx_isr(const CanFrame *f);
const RouterStats *router_stats(void);
```

Requirements:

- `router_start()` creates the **RX queue** (`rxq_len` x `CanFrame`), one **node queue** per node (`qlen` x `CanFrame`), one **node task** per node with that node's priority, and the **router task** with priority **5**. The `nodes` array stays valid.
- `can_rx_isr(f)` runs in **interrupt context**. It copies the frame into the RX queue with `xQueueSendToBackFromISR()`. If the queue is full, it increments `rx_overflow` and calls `on_rx_overflow(f)`. It ends with `portYIELD_FROM_ISR()`.
- **Router**, forever: receive a frame from the RX queue (block). Find the **first** node, in table order, whose range contains the id.
  - No node matches: `unrouted++`, `on_unrouted(&f)`.
  - Otherwise send to that node's queue with **timeout 0**. On success: `delivered[i]++` and update `peak[i]` with `uxQueueMessagesWaiting()` of that queue. On failure: `dropped[i]++` and `on_node_drop(i, &f)`.
- **Node task `i`**, forever: receive from its queue (block) and call `node_process(i, &f)`.

**How it is tested.** The hidden `main()` reads the RX queue length, the node table (plus each node's processing time, which only the harness uses), the frame list and the duration `D`. It calls `router_start()`, schedules one interrupt per frame (the interrupt calls `can_rx_isr()` with a frame whose data bytes the harness can check), and runs the scheduler up to and including tick `D`. `node_process()` prints `ERROR` if it runs in the wrong task, if the frame belongs to another node, or if the data is corrupt. At the end the harness prints your statistics next to its own count of processed frames, and prints `ERROR` lines if the counters disagree with what it observed (`delivered == processed + still waiting`, and the drop/overflow/unrouted counts).

**Timing rules**
- All interrupts of one tick run back to back, in input order, before any task runs. Then the router (priority 5) routes everything, and only then the node tasks run, highest priority first.
- An interrupt at tick `t` also runs before a node finishes a frame whose processing ends at `t`, and the router then runs before that node continues.
- A node's processing time is **CPU time**: while a higher-priority node (or the router) preempts it, its frame does not progress, so it finishes later.
- The tests end with every task idle.

**Input**
```
<rxq_len> <nnodes>
<id_lo> <id_hi> <qlen> <prio> <cost>     (nnodes lines, ids in hex)
<m>
<tick> <id> <dlc>                        (m lines, sorted by tick, id in hex)
<D>
```

**Example**
```
Input:
4 2
0x100 0x1FF 2 3 2
0x200 0x2FF 1 2 5
5
1 0x120 8
1 0x250 2
1 0x251 2
1 0x7DF 8
3 0x121 4
30

Output:
[t=1] DROP id=0x251 N2 full
[t=1] UNROUTED id=0x7DF
[t=1] N1 id=0x120 dlc=8
[t=3] N1 id=0x121 dlc=4
[t=5] N2 id=0x250 dlc=2
rx overflow 0, unrouted 1
N1: delivered 2, dropped 0, peak 1, processed 2
N2: delivered 1, dropped 1, peak 1, processed 1
```
At t=1 the four frames fit in the RX queue. The router delivers 0x120 to N1 and 0x250 to N2. N2's queue (length 1) is then full, so 0x251 is dropped, and 0x7DF matches no node. N1 (priority 3) runs before N2 (priority 2). N2 only starts at t=5, after N1 has also processed 0x121.
@@@ constraints_md
- 1 <= rxq_len <= 16, 1 <= nnodes <= 4, 1 <= qlen <= 8, node priorities distinct in 1..4, 1 <= cost <= 50.
- 0 <= m <= 300, 1 <= tick <= D <= 20000, ids 0x000..0x7FF, 0 <= dlc <= 8. Ranges may overlap (first match wins).
- Router priority 5; stack `configMINIMAL_STACK_SIZE` for all tasks. `can_rx_isr()` must only use `...FromISR()` APIs; the router must never block on a node queue.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

#define MAX_NODES 4

typedef struct {
    uint16_t id;
    uint8_t  dlc;
    uint8_t  data[8];
} CanFrame;

typedef struct {
    uint16_t    id_lo, id_hi;
    UBaseType_t qlen;
    UBaseType_t prio;
} NodeCfg;

typedef struct {
    uint32_t rx_overflow;
    uint32_t unrouted;
    uint32_t delivered[MAX_NODES];
    uint32_t dropped[MAX_NODES];
    uint32_t peak[MAX_NODES];
} RouterStats;

void node_process(unsigned node, const CanFrame *f);
void on_rx_overflow(const CanFrame *f);
void on_unrouted(const CanFrame *f);
void on_node_drop(unsigned node, const CanFrame *f);

static RouterStats s_stats;

static void router_task(void *pvParameters)
{
    /* TODO: receive from the RX queue, route by id, count */
    (void)pvParameters;
    for (;;) {
        vTaskDelay(1000);
    }
}

static void node_task(void *pvParameters)
{
    /* TODO: receive from this node's queue, node_process(i, &f) */
    (void)pvParameters;
    for (;;) {
        vTaskDelay(1000);
    }
}

void router_start(const NodeCfg *nodes, unsigned nnodes, UBaseType_t rxq_len)
{
    /* TODO: create the RX queue, node queues, node tasks and the router task */
    (void)nodes;
    (void)nnodes;
    (void)rxq_len;
    (void)router_task;
    (void)node_task;
}

void can_rx_isr(const CanFrame *f)
{
    /* TODO: xQueueSendToBackFromISR, count overflow, portYIELD_FROM_ISR */
    (void)f;
}

const RouterStats *router_stats(void)
{
    return &s_stats;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

/*USER_CODE*/

static NodeCfg g_nodes[MAX_NODES];
static unsigned g_cost[MAX_NODES], g_nn;
static unsigned g_processed[MAX_NODES], g_dropped[MAX_NODES], g_unrouted, g_overflow;

typedef struct {
    uint16_t id;
    uint8_t dlc;
    uint8_t seq;
} FrameDesc;

static FrameDesc g_fd[300];
static CanFrame g_rx_reg;   /* the CAN controller's receive mailbox, reused for every frame */

static int expected_node(uint16_t id)
{
    unsigned i;
    for (i = 0; i < g_nn; i++)
        if (id >= g_nodes[i].id_lo && id <= g_nodes[i].id_hi) return (int)i;
    return -1;
}

static int data_ok(const CanFrame *f)
{
    unsigned i;
    if (f->dlc > 8) return 0;
    for (i = 0; i < f->dlc; i++)
        if (f->data[i] != (uint8_t)(f->data[0] + i * 17u)) return 0;
    return 1;
}

void node_process(unsigned node, const CanFrame *f)
{
    unsigned t = (unsigned)xTaskGetTickCount();
    printf("[t=%u] N%u id=0x%03X dlc=%u\n", t, node + 1, (unsigned)f->id, (unsigned)f->dlc);
    if (node >= g_nn) {
        printf("ERROR: bad node index\n");
        return;
    }
    if (uxTaskPriorityGet(NULL) != g_nodes[node].prio)
        printf("ERROR: node_process(%u) must run in node %u's task\n", node, node + 1);
    if (expected_node(f->id) != (int)node)
        printf("ERROR: frame 0x%03X misrouted\n", (unsigned)f->id);
    if (!data_ok(f))
        printf("ERROR: frame 0x%03X data corrupt\n", (unsigned)f->id);
    g_processed[node]++;
    vSimBusyWork((TickType_t)g_cost[node]);
}

void on_rx_overflow(const CanFrame *f)
{
    printf("[t=%u] RX OVERFLOW id=0x%03X\n", (unsigned)xTaskGetTickCountFromISR(), (unsigned)f->id);
    g_overflow++;
}

void on_unrouted(const CanFrame *f)
{
    printf("[t=%u] UNROUTED id=0x%03X\n", (unsigned)xTaskGetTickCount(), (unsigned)f->id);
    g_unrouted++;
}

void on_node_drop(unsigned node, const CanFrame *f)
{
    printf("[t=%u] DROP id=0x%03X N%u full\n", (unsigned)xTaskGetTickCount(), (unsigned)f->id, node + 1);
    if (node < g_nn) g_dropped[node]++;
}

static void can_irq(void *arg)
{
    const FrameDesc *d = (const FrameDesc *)arg;
    unsigned i;

    g_rx_reg.id = d->id;
    g_rx_reg.dlc = d->dlc;
    for (i = 0; i < 8; i++) g_rx_reg.data[i] = (uint8_t)(d->seq + i * 17u);
    can_rx_isr(&g_rx_reg);
    g_rx_reg.id = 0x7FF;        /* the mailbox is overwritten by the next frame */
    g_rx_reg.data[0] ^= 0x5A;
}

int main(void)
{
    unsigned rxq, i, m, tick, id, dlc, lo, hi, ql, pr, dur;
    const RouterStats *st;

    if (scanf("%u %u", &rxq, &g_nn) != 2 || g_nn < 1 || g_nn > MAX_NODES) return 1;
    for (i = 0; i < g_nn; i++) {
        if (scanf("%x %x %u %u %u", &lo, &hi, &ql, &pr, &g_cost[i]) != 5) return 1;
        g_nodes[i].id_lo = (uint16_t)lo;
        g_nodes[i].id_hi = (uint16_t)hi;
        g_nodes[i].qlen = (UBaseType_t)ql;
        g_nodes[i].prio = (UBaseType_t)pr;
    }
    if (scanf("%u", &m) != 1 || m > 300) return 1;
    for (i = 0; i < m; i++) {
        if (scanf("%u %x %u", &tick, &id, &dlc) != 3) return 1;
        g_fd[i].id = (uint16_t)id;
        g_fd[i].dlc = (uint8_t)dlc;
        g_fd[i].seq = (uint8_t)(i * 13u + 1u);
        xSimScheduleInterrupt((TickType_t)tick, can_irq, &g_fd[i]);
    }
    if (scanf("%u", &dur) != 1) return 1;

    router_start(g_nodes, g_nn, (UBaseType_t)rxq);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    st = router_stats();
    printf("rx overflow %u, unrouted %u\n", (unsigned)st->rx_overflow, (unsigned)st->unrouted);
    if (st->rx_overflow != g_overflow || st->unrouted != g_unrouted)
        printf("ERROR: overflow/unrouted counters disagree with the callbacks (%u, %u)\n", g_overflow, g_unrouted);
    for (i = 0; i < g_nn; i++) {
        printf("N%u: delivered %u, dropped %u, peak %u, processed %u\n", i + 1, (unsigned)st->delivered[i],
               (unsigned)st->dropped[i], (unsigned)st->peak[i], g_processed[i]);
        if (st->dropped[i] != g_dropped[i])
            printf("ERROR: N%u drop counter disagrees with on_node_drop() calls (%u)\n", i + 1, g_dropped[i]);
        if (st->delivered[i] < g_processed[i] || st->peak[i] > g_nodes[i].qlen)
            printf("ERROR: N%u counters are inconsistent\n", i + 1);
    }
    return 0;
}
@@@ sample_input
4 2
0x100 0x1FF 2 3 2
0x200 0x2FF 1 2 5
5
1 0x120 8
1 0x250 2
1 0x251 2
1 0x7DF 8
3 0x121 4
30
@@@ sample_output
[t=1] DROP id=0x251 N2 full
[t=1] UNROUTED id=0x7DF
[t=1] N1 id=0x120 dlc=8
[t=3] N1 id=0x121 dlc=4
[t=5] N2 id=0x250 dlc=2
rx overflow 0, unrouted 1
N1: delivered 2, dropped 0, peak 1, processed 2
N2: delivered 1, dropped 1, peak 1, processed 1
@@@ sample_input
2 1
0x000 0x7FF 8 1 1
5
2 0x010 1
2 0x011 1
2 0x012 1
2 0x013 1
2 0x014 1
20
@@@ sample_output
[t=2] RX OVERFLOW id=0x012
[t=2] RX OVERFLOW id=0x013
[t=2] RX OVERFLOW id=0x014
[t=2] N1 id=0x010 dlc=1
[t=3] N1 id=0x011 dlc=1
rx overflow 3, unrouted 0
N1: delivered 2, dropped 0, peak 2, processed 2
@@@ hidden_input
8 3
0x100 0x1FF 4 1 1
0x200 0x2FF 4 2 1
0x300 0x3FF 4 3 1
0
50
@@@ hidden_output
rx overflow 0, unrouted 0
N1: delivered 0, dropped 0, peak 0, processed 0
N2: delivered 0, dropped 0, peak 0, processed 0
N3: delivered 0, dropped 0, peak 0, processed 0
@@@ hidden_input
16 2
0x100 0x17F 8 4 3
0x100 0x1FF 8 2 3
6
1 0x100 0
1 0x17F 8
1 0x180 8
1 0x1FF 3
1 0x200 1
1 0x0FF 2
30
@@@ hidden_output
[t=1] UNROUTED id=0x200
[t=1] UNROUTED id=0x0FF
[t=1] N1 id=0x100 dlc=0
[t=4] N1 id=0x17F dlc=8
[t=7] N2 id=0x180 dlc=8
[t=10] N2 id=0x1FF dlc=3
rx overflow 0, unrouted 2
N1: delivered 2, dropped 0, peak 2, processed 2
N2: delivered 2, dropped 0, peak 2, processed 2
@@@ hidden_input
3 2
0x000 0x3FF 2 1 10
0x400 0x7FF 8 3 1
10
1 0x001 8
2 0x002 8
3 0x003 8
4 0x004 8
5 0x005 8
5 0x400 1
5 0x401 1
5 0x402 1
5 0x403 1
12 0x7FF 8
100
@@@ hidden_output
[t=1] N1 id=0x001 dlc=8
[t=4] DROP id=0x004 N1 full
[t=5] RX OVERFLOW id=0x402
[t=5] RX OVERFLOW id=0x403
[t=5] DROP id=0x005 N1 full
[t=5] N2 id=0x400 dlc=1
[t=6] N2 id=0x401 dlc=1
[t=12] N2 id=0x7FF dlc=8
[t=14] N1 id=0x002 dlc=8
[t=24] N1 id=0x003 dlc=8
rx overflow 2, unrouted 0
N1: delivered 3, dropped 2, peak 2, processed 3
N2: delivered 3, dropped 0, peak 2, processed 3

@@@ hidden_input
4 4
0x000 0x0FF 1 4 4
0x100 0x1FF 2 3 3
0x200 0x2FF 3 2 2
0x300 0x3FF 4 1 1
16
1 0x010 1
1 0x110 2
1 0x210 3
1 0x310 4
2 0x011 1
2 0x111 2
2 0x211 3
2 0x311 4
3 0x012 1
3 0x112 2
3 0x212 3
3 0x312 4
4 0x013 1
4 0x113 2
4 0x213 3
4 0x313 4
200
@@@ hidden_output
[t=1] N1 id=0x010 dlc=1
[t=3] DROP id=0x012 N1 full
[t=3] DROP id=0x112 N2 full
[t=4] DROP id=0x013 N1 full
[t=4] DROP id=0x113 N2 full
[t=4] DROP id=0x213 N3 full
[t=5] N1 id=0x011 dlc=1
[t=9] N2 id=0x110 dlc=2
[t=12] N2 id=0x111 dlc=2
[t=15] N3 id=0x210 dlc=3
[t=17] N3 id=0x211 dlc=3
[t=19] N3 id=0x212 dlc=3
[t=21] N4 id=0x310 dlc=4
[t=22] N4 id=0x311 dlc=4
[t=23] N4 id=0x312 dlc=4
[t=24] N4 id=0x313 dlc=4
rx overflow 0, unrouted 0
N1: delivered 2, dropped 2, peak 1, processed 2
N2: delivered 2, dropped 2, peak 2, processed 2
N3: delivered 3, dropped 1, peak 3, processed 3
N4: delivered 4, dropped 0, peak 4, processed 4

@@@ hidden_input
5 2
0x123 0x123 2 2 7
0x000 0x7FF 3 1 2
12
10 0x123 8
11 0x123 8
12 0x123 8
13 0x123 8
13 0x124 8
14 0x7FF 0
40 0x123 1
40 0x555 1
40 0x123 2
40 0x555 2
40 0x123 3
40 0x555 3
150
@@@ hidden_output
[t=10] N1 id=0x123 dlc=8
[t=13] DROP id=0x123 N1 full
[t=17] N1 id=0x123 dlc=8
[t=24] N1 id=0x123 dlc=8
[t=31] N2 id=0x124 dlc=8
[t=33] N2 id=0x7FF dlc=0
[t=40] RX OVERFLOW id=0x555
[t=40] DROP id=0x123 N1 full
[t=40] N1 id=0x123 dlc=1
[t=47] N1 id=0x123 dlc=2
[t=54] N2 id=0x555 dlc=1
[t=56] N2 id=0x555 dlc=2
rx overflow 1, unrouted 0
N1: delivered 5, dropped 2, peak 2, processed 5
N2: delivered 4, dropped 0, peak 2, processed 4

@@@ hidden_input
1 1
0x700 0x7FF 1 3 1
4
1 0x7DF 8
1 0x7E0 8
19990 0x7DF 2
19990 0x100 2
20000
@@@ hidden_output
[t=1] RX OVERFLOW id=0x7E0
[t=1] N1 id=0x7DF dlc=8
[t=19990] RX OVERFLOW id=0x100
[t=19990] N1 id=0x7DF dlc=2
rx overflow 2, unrouted 0
N1: delivered 2, dropped 0, peak 1, processed 2

@@@ hint
Keep one static array of node queue handles indexed like the node table, and give each node task its index through `pvParameters` (for example `(void *)(uintptr_t)i`). All counters except `rx_overflow` are written only by the router task, and `rx_overflow` only by the ISR, so a single writer per field needs no lock.
@@@ hint
Router body: `xQueueReceive(rxq, &f, portMAX_DELAY); i = first match; if (none) { s.unrouted++; on_unrouted(&f); } else if (xQueueSend(nodeq[i], &f, 0) == pdPASS) { s.delivered[i]++; w = uxQueueMessagesWaiting(nodeq[i]); if (w > s.peak[i]) s.peak[i] = w; } else { s.dropped[i]++; on_node_drop(i, &f); }`. Timeout **0** is what keeps one slow node from stalling every other node.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

#define MAX_NODES 4

typedef struct {
    uint16_t id;
    uint8_t  dlc;
    uint8_t  data[8];
} CanFrame;

typedef struct {
    uint16_t    id_lo, id_hi;
    UBaseType_t qlen;
    UBaseType_t prio;
} NodeCfg;

typedef struct {
    uint32_t rx_overflow;
    uint32_t unrouted;
    uint32_t delivered[MAX_NODES];
    uint32_t dropped[MAX_NODES];
    uint32_t peak[MAX_NODES];
} RouterStats;

void node_process(unsigned node, const CanFrame *f);
void on_rx_overflow(const CanFrame *f);
void on_unrouted(const CanFrame *f);
void on_node_drop(unsigned node, const CanFrame *f);

static RouterStats s_stats;
static QueueHandle_t s_rxq;
static QueueHandle_t s_nodeq[MAX_NODES];
static const NodeCfg *s_nodes;
static unsigned s_nn;

static int route(uint16_t id)
{
    unsigned i;

    for (i = 0; i < s_nn; i++) {
        if (id >= s_nodes[i].id_lo && id <= s_nodes[i].id_hi) {
            return (int)i;                    /* first match wins */
        }
    }
    return -1;
}

static void router_task(void *pvParameters)
{
    CanFrame f;

    (void)pvParameters;
    for (;;) {
        int n;

        if (xQueueReceive(s_rxq, &f, portMAX_DELAY) != pdPASS) {
            continue;
        }
        n = route(f.id);
        if (n < 0) {
            s_stats.unrouted++;
            on_unrouted(&f);
        } else if (xQueueSend(s_nodeq[n], &f, 0) == pdPASS) {   /* never block on a node */
            UBaseType_t w = uxQueueMessagesWaiting(s_nodeq[n]);
            s_stats.delivered[n]++;
            if (w > s_stats.peak[n]) {
                s_stats.peak[n] = (uint32_t)w;
            }
        } else {
            s_stats.dropped[n]++;             /* backpressure: this node is too slow */
            on_node_drop((unsigned)n, &f);
        }
    }
}

static void node_task(void *pvParameters)
{
    unsigned idx = (unsigned)(uintptr_t)pvParameters;
    CanFrame f;

    for (;;) {
        if (xQueueReceive(s_nodeq[idx], &f, portMAX_DELAY) == pdPASS) {
            node_process(idx, &f);
        }
    }
}

void router_start(const NodeCfg *nodes, unsigned nnodes, UBaseType_t rxq_len)
{
    unsigned i;

    s_nodes = nodes;
    s_nn = nnodes;
    s_rxq = xQueueCreate(rxq_len, sizeof(CanFrame));
    for (i = 0; i < nnodes; i++) {
        s_nodeq[i] = xQueueCreate(nodes[i].qlen, sizeof(CanFrame));
        xTaskCreate(node_task, "node", configMINIMAL_STACK_SIZE, (void *)(uintptr_t)i, nodes[i].prio, NULL);
    }
    xTaskCreate(router_task, "router", configMINIMAL_STACK_SIZE, NULL, 5, NULL);
}

void can_rx_isr(const CanFrame *f)
{
    BaseType_t woken = pdFALSE;

    if (xQueueSendToBackFromISR(s_rxq, f, &woken) != pdPASS) {   /* copies the mailbox */
        s_stats.rx_overflow++;
        on_rx_overflow(f);
    }
    portYIELD_FROM_ISR(woken);
}

const RouterStats *router_stats(void)
{
    return &s_stats;
}
@@@ explanation_md
**Approach.** The design has three stages, each decoupled by a queue:

1. **ISR, then RX queue.** The interrupt only copies the 12-byte frame out of the controller's mailbox, which is overwritten by the next frame, and wakes the router. Work in the ISR is O(1). The only loss point here is a full RX queue, counted as `rx_overflow`.
2. **Router.** A high-priority task does the lookup (first matching range) and forwards a copy with **timeout 0**. A full node queue is that node's problem: the frame is dropped and counted for that node, and the router moves on. With a blocking send, one slow node would stall routing for everyone and soon overflow the RX queue. That failure spreads to every node and is much worse than a counted drop.
3. **Node tasks.** Each one blocks on its own queue and runs at its own priority. Queue length per node is the burst tolerance of that node.

Statistics follow the single-writer rule. The router writes `unrouted`, `delivered`, `dropped` and `peak`; the ISR writes `rx_overflow`. On a 32-bit MCU an aligned 32-bit store is atomic, so diagnostics can read the counters without a lock. `peak` is a high-water mark: measured right after each delivery, it shows how close each node came to dropping, which is the number you need to tune the queue lengths.

**Complexity.** Per frame: O(1) in the ISR, O(nnodes) for the lookup in the router (use a table or a hash for hundreds of ids), and two 12-byte copies. RAM: `(rxq_len + sum of qlen) * 12` bytes plus control blocks and one stack per node. Worst-case routing latency = the frames ahead of it in the RX queue, each routed in O(nnodes) and in zero ticks here. A node's latency is set by its queue position times its processing time.

**Common mistakes**
- `xQueueSend(nodeq, &f, portMAX_DELAY)` in the router: one slow node blocks all routing, and the RX queue overflows (`RX OVERFLOW` for frames meant for healthy nodes).
- Queueing a pointer to the CAN mailbox from the ISR: it is overwritten by the next frame (`data corrupt`, wrong ids).
- Calling `node_process()` from the router: no isolation between nodes, and the router's priority is used for application work.
- Counting a drop without calling the callback, or the reverse: diagnostics then disagree with reality.
- Passing `&i` (the loop variable) as the node index to the node tasks.
- Last-match instead of first-match routing when ranges overlap.

**Interview follow-ups**
- How would you route thousands of ids in O(1)? (Lookup table indexed by the 11-bit id, or the hardware acceptance filters of the CAN controller.)
- Some frames are periodic and only the latest value matters. How would you treat those differently? (A per-signal mailbox with `xQueueOverwrite`.)
- How would you report the statistics over UDS without tearing a multi-field snapshot?
- The CAN controller has a hardware FIFO of 3 mailboxes. How does that interact with `rxq_len` and the interrupt latency?
