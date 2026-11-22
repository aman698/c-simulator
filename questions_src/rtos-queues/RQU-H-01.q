@@@ meta
id: RQU-H-01
topic: Queues
difficulty: Hard
type: FUNCTION
title: Request/Response RPC Over Queues With Reply Handles and Stale Replies
tags: freertos, queue, rpc, request-response, timeout, xtaskcheckfortimeout, embedded, asked-in-automotive
@@@ statement_md
In an ECU, a single **server task** owns a slow resource (an EEPROM emulation, a crypto engine, ...). Several client tasks call it **synchronously**: each sends a request that carries the handle of **its own reply queue**, then blocks until the matching response arrives, **or until its timeout expires**. Implement the RPC layer.

```c
typedef struct {
    uint32_t      seq;     /* per-client sequence number of the call */
    uint8_t       op;      /* operation code */
    int32_t       arg;
    QueueHandle_t reply;   /* where the server sends the Response */
} Request;

typedef struct {
    uint32_t seq;          /* copied from the Request */
    int32_t  result;
} Response;

typedef struct {
    QueueHandle_t reply;     /* this client's reply queue (1 x Response) */
    uint32_t      next_seq;  /* seq of the next call, starts at 1 */
} RpcClient;

int32_t backend_execute(uint8_t op, int32_t arg);          /* provided: server task only, takes `op` ticks */
void    rpc_on_stale(const RpcClient *c, uint32_t seq);    /* provided: prints "[t=..] C<k> stale #<seq> dropped" */

QueueHandle_t rpc_server_start(void);   /* you write: request queue (8 x Request) + server task, return the queue */
void rpc_client_init(RpcClient *c);     /* you write: reply queue (1 x Response), next_seq = 1 */
BaseType_t rpc_call(RpcClient *c, uint8_t op, int32_t arg, TickType_t timeout, int32_t *result);
                                        /* you write: pdPASS + *result, or pdFAIL on timeout */
```

**Server task**, priority **1**. Forever: receive a `Request` (block), compute `result = backend_execute(op, arg)`, and send `{seq, result}` to `req.reply` with **`xQueueOverwrite()`**. The server must never block on a client: a reply that its client no longer waits for is simply replaced later.

**`rpc_call()`** is called by several client tasks **concurrently**, so it must be reentrant: use only `*c` and local variables.

1. Take `seq = c->next_seq++` and build the request.
2. The whole call has a budget of `timeout` ticks, counted from its start. Send the request with the remaining budget (the request queue may be full).
3. Wait on `c->reply` with the remaining budget. A response whose `seq` differs from the call's `seq` belongs to an **earlier call that timed out**: report it with `rpc_on_stale(c, resp.seq)`, discard it and keep waiting with whatever budget is left. Use `vTaskSetTimeOutState()` / `xTaskCheckForTimeOut()` (or tick arithmetic) to track that budget.
4. Return `pdPASS` with `*result` set when the matching response arrives, and `pdFAIL` when the budget runs out.

**How it is tested.** The hidden `main()` calls `rpc_server_start()`, then creates the client tasks with the given priorities (always above the server's) and calls `rpc_client_init()` for each one. Each client runs a script of steps `delay op arg timeout`: `vTaskDelay(delay)` (skipped when 0), print `[t=..] C<k> call op=.. arg=..`, call `rpc_call()`, print `[t=..] C<k> OK <result>` or `[t=..] C<k> TIMEOUT`. The backend prints `[t=..] server op=.. arg=..` when it starts. The harness knows the correct result (`arg * 10 + op`) and prints `WRONG RESULT` if a call returns someone else's answer. The run goes up to and including tick `D`. Finally the harness prints per-client counters and the number of requests served.

**Timing rules**
- `backend_execute()` keeps the server busy for `op` ticks. Clients have higher priority, so a reply sent with `xQueueOverwrite()` wakes the waiting client, and the client runs **before** the server takes its next request.
- At the same tick, clients run in priority order (highest first), so their requests are queued in that order.
- The tests never make a client wake up (end of a delay or of a budget) at the exact tick the server finishes an operation, so you never have to decide which of the two happens first.

**Input**
```
<nclients>
<prio> <nsteps>              (per client, followed by nsteps lines:)
<delay> <op> <arg> <timeout>
<D>
```

**Example**
```
Input:
1
3 3
5 3 7 10
2 6 1 4
0 2 5 10
30

Output:
[t=5] C1 call op=3 arg=7
[t=5] server op=3 arg=7
[t=8] C1 OK 73
[t=10] C1 call op=6 arg=1
[t=10] server op=6 arg=1
[t=14] C1 TIMEOUT
[t=14] C1 call op=2 arg=5
[t=16] C1 stale #2 dropped
[t=16] server op=2 arg=5
[t=18] C1 OK 52
C1: ok 2, timeout 1, stale 1
server handled 3
```
Call #2 needs 6 ticks but has a budget of 4, so it times out at t=14. Call #3 starts at once and its request waits behind #2. At t=16 the late reply to #2 lands in C1's reply queue while C1 waits for #3. Without the sequence check, C1 would return 61 (the answer to #2) as the result of #3.
@@@ constraints_md
- 1 <= nclients <= 4, client priorities distinct in 2..6, 1 <= nsteps <= 20, 0 <= delay <= 1000, 1 <= op <= 50, -10000 <= arg <= 10000, 1 <= timeout <= 1000, D <= 20000.
- Request queue: 8 x `sizeof(Request)`. Reply queue: 1 x `sizeof(Response)`. Server: priority 1, stack `configMINIMAL_STACK_SIZE`.
- The server must not block on a reply queue; clients must block (no polling).
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    uint32_t      seq;
    uint8_t       op;
    int32_t       arg;
    QueueHandle_t reply;
} Request;

typedef struct {
    uint32_t seq;
    int32_t  result;
} Response;

typedef struct {
    QueueHandle_t reply;
    uint32_t      next_seq;
} RpcClient;

int32_t backend_execute(uint8_t op, int32_t arg);
void    rpc_on_stale(const RpcClient *c, uint32_t seq);

static void server_task(void *pvParameters)
{
    /* TODO: receive Request, backend_execute, xQueueOverwrite the Response to req.reply */
    (void)pvParameters;
    for (;;) {
        vTaskDelay(1000);
    }
}

QueueHandle_t rpc_server_start(void)
{
    /* TODO: create the request queue (8 x Request) and the server task (priority 1) */
    (void)server_task;
    return NULL;
}

void rpc_client_init(RpcClient *c)
{
    /* TODO: reply queue (1 x Response), next_seq = 1 */
    c->reply = NULL;
    c->next_seq = 1;
}

BaseType_t rpc_call(RpcClient *c, uint8_t op, int32_t arg, TickType_t timeout, int32_t *result)
{
    /* TODO: send request, wait for the matching response within the budget */
    (void)c;
    (void)op;
    (void)arg;
    (void)result;
    vTaskDelay(timeout);
    return pdFAIL;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

/*USER_CODE*/

#define MAX_CLIENTS 4
#define MAX_STEPS 20

typedef struct {
    unsigned delay, op, timeout;
    int arg;
} Step;

typedef struct {
    RpcClient cl;
    unsigned prio, nsteps, ok, tmo, stale;
    Step steps[MAX_STEPS];
} ClientSlot;

static ClientSlot g_cs[MAX_CLIENTS];
static unsigned g_nc, g_served;

int32_t backend_execute(uint8_t op, int32_t arg)
{
    printf("[t=%u] server op=%u arg=%d\n", (unsigned)xTaskGetTickCount(), (unsigned)op, (int)arg);
    vSimBusyWork((TickType_t)op);
    g_served++;
    return arg * 10 + (int32_t)op;
}

static unsigned client_index(const RpcClient *c)
{
    unsigned k;
    for (k = 0; k < g_nc; k++)
        if (&g_cs[k].cl == c) return k;
    return 99;
}

void rpc_on_stale(const RpcClient *c, uint32_t seq)
{
    unsigned k = client_index(c);
    printf("[t=%u] C%u stale #%u dropped\n", (unsigned)xTaskGetTickCount(), k + 1, (unsigned)seq);
    if (k < g_nc) g_cs[k].stale++;
}

static void client_task(void *pv)
{
    ClientSlot *s = (ClientSlot *)pv;
    unsigned k = (unsigned)(s - g_cs) + 1, i;

    for (i = 0; i < s->nsteps; i++) {
        const Step *st = &s->steps[i];
        int32_t res = 0;
        if (st->delay) vTaskDelay((TickType_t)st->delay);
        printf("[t=%u] C%u call op=%u arg=%d\n", (unsigned)xTaskGetTickCount(), k, st->op, st->arg);
        if (rpc_call(&s->cl, (uint8_t)st->op, (int32_t)st->arg, (TickType_t)st->timeout, &res) == pdPASS) {
            printf("[t=%u] C%u OK %d\n", (unsigned)xTaskGetTickCount(), k, (int)res);
            if (res != (int32_t)st->arg * 10 + (int32_t)st->op)
                printf("WRONG RESULT: expected %d\n", st->arg * 10 + (int)st->op);
            s->ok++;
        } else {
            printf("[t=%u] C%u TIMEOUT\n", (unsigned)xTaskGetTickCount(), k);
            s->tmo++;
        }
    }
    for (;;) vTaskSuspend(NULL);
}

int main(void)
{
    unsigned k, i, dur;
    QueueHandle_t rq;

    if (scanf("%u", &g_nc) != 1 || g_nc < 1 || g_nc > MAX_CLIENTS) return 1;
    for (k = 0; k < g_nc; k++) {
        ClientSlot *s = &g_cs[k];
        if (scanf("%u %u", &s->prio, &s->nsteps) != 2 || s->nsteps > MAX_STEPS) return 1;
        for (i = 0; i < s->nsteps; i++)
            if (scanf("%u %u %d %u", &s->steps[i].delay, &s->steps[i].op, &s->steps[i].arg,
                      &s->steps[i].timeout) != 4) return 1;
    }
    if (scanf("%u", &dur) != 1) return 1;

    rq = rpc_server_start();
    if (rq == NULL || uxQueueGetQueueLength(rq) != 8 || uxQueueGetQueueItemSize(rq) != sizeof(Request)) {
        printf("ERROR: rpc_server_start() must return a queue of 8 x sizeof(Request)\n");
        return 0;
    }
    for (k = 0; k < g_nc; k++) {
        rpc_client_init(&g_cs[k].cl);
        if (g_cs[k].cl.reply == NULL || uxQueueGetQueueLength(g_cs[k].cl.reply) != 1 ||
            uxQueueGetQueueItemSize(g_cs[k].cl.reply) != sizeof(Response)) {
            printf("ERROR: rpc_client_init() must create a reply queue of 1 x sizeof(Response)\n");
            return 0;
        }
        xTaskCreate(client_task, "client", configMINIMAL_STACK_SIZE, &g_cs[k], (UBaseType_t)g_cs[k].prio, NULL);
    }
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    for (k = 0; k < g_nc; k++)
        printf("C%u: ok %u, timeout %u, stale %u\n", k + 1, g_cs[k].ok, g_cs[k].tmo, g_cs[k].stale);
    printf("server handled %u\n", g_served);
    return 0;
}
@@@ sample_input
1
3 3
5 3 7 10
2 6 1 4
0 2 5 10
30
@@@ sample_output
[t=5] C1 call op=3 arg=7
[t=5] server op=3 arg=7
[t=8] C1 OK 73
[t=10] C1 call op=6 arg=1
[t=10] server op=6 arg=1
[t=14] C1 TIMEOUT
[t=14] C1 call op=2 arg=5
[t=16] C1 stale #2 dropped
[t=16] server op=2 arg=5
[t=18] C1 OK 52
C1: ok 2, timeout 1, stale 1
server handled 3
@@@ sample_input
2
2 1
1 2 1 20
4 1
1 2 2 20
10
@@@ sample_output
[t=1] C2 call op=2 arg=2
[t=1] C1 call op=2 arg=1
[t=1] server op=2 arg=2
[t=3] C2 OK 22
[t=3] server op=2 arg=1
[t=5] C1 OK 12
C1: ok 1, timeout 0, stale 0
C2: ok 1, timeout 0, stale 0
server handled 2
@@@ hidden_input
1
2 2
1 10 3 5
20 1 4 5
40
@@@ hidden_output
[t=1] C1 call op=10 arg=3
[t=1] server op=10 arg=3
[t=6] C1 TIMEOUT
[t=26] C1 call op=1 arg=4
[t=26] C1 stale #1 dropped
[t=26] server op=1 arg=4
[t=27] C1 OK 41
C1: ok 1, timeout 1, stale 1
server handled 2
@@@ hidden_input
3
6 3
2 4 -100 3
0 4 -101 2
0 1 -102 20
4 2
1 3 50 12
5 3 51 2
2 3
3 2 9 30
2 2 8 1
0 2 7 30
200
@@@ hidden_output
[t=1] C2 call op=3 arg=50
[t=1] server op=3 arg=50
[t=2] C1 call op=4 arg=-100
[t=3] C3 call op=2 arg=9
[t=4] C2 OK 503
[t=4] server op=4 arg=-100
[t=5] C1 TIMEOUT
[t=5] C1 call op=4 arg=-101
[t=7] C1 TIMEOUT
[t=7] C1 call op=1 arg=-102
[t=8] C1 stale #1 dropped
[t=8] server op=2 arg=9
[t=9] C2 call op=3 arg=51
[t=10] C3 OK 92
[t=10] server op=4 arg=-101
[t=11] C2 TIMEOUT
[t=12] C3 call op=2 arg=8
[t=13] C3 TIMEOUT
[t=13] C3 call op=2 arg=7
[t=14] C1 stale #2 dropped
[t=14] server op=1 arg=-102
[t=15] C1 OK -1019
[t=15] server op=3 arg=51
[t=18] server op=2 arg=8
[t=20] C3 stale #2 dropped
[t=20] server op=2 arg=7
[t=22] C3 OK 72
C1: ok 1, timeout 2, stale 2
C2: ok 1, timeout 1, stale 0
C3: ok 2, timeout 1, stale 1
server handled 8

@@@ hidden_input
1
5 12
1 50 0 1
0 1 1 1
0 1 2 1
0 1 3 1
0 1 4 1
0 1 5 1
0 1 6 1
0 1 7 1
0 1 8 1
0 1 9 1
0 1 10 1
0 1 11 100
200
@@@ hidden_output
[t=1] C1 call op=50 arg=0
[t=1] server op=50 arg=0
[t=2] C1 TIMEOUT
[t=2] C1 call op=1 arg=1
[t=3] C1 TIMEOUT
[t=3] C1 call op=1 arg=2
[t=4] C1 TIMEOUT
[t=4] C1 call op=1 arg=3
[t=5] C1 TIMEOUT
[t=5] C1 call op=1 arg=4
[t=6] C1 TIMEOUT
[t=6] C1 call op=1 arg=5
[t=7] C1 TIMEOUT
[t=7] C1 call op=1 arg=6
[t=8] C1 TIMEOUT
[t=8] C1 call op=1 arg=7
[t=9] C1 TIMEOUT
[t=9] C1 call op=1 arg=8
[t=10] C1 TIMEOUT
[t=10] C1 call op=1 arg=9
[t=11] C1 TIMEOUT
[t=11] C1 call op=1 arg=10
[t=12] C1 TIMEOUT
[t=12] C1 call op=1 arg=11
[t=51] C1 stale #1 dropped
[t=51] server op=1 arg=1
[t=52] C1 stale #2 dropped
[t=52] server op=1 arg=2
[t=53] C1 stale #3 dropped
[t=53] server op=1 arg=3
[t=54] C1 stale #4 dropped
[t=54] server op=1 arg=4
[t=55] C1 stale #5 dropped
[t=55] server op=1 arg=5
[t=56] C1 stale #6 dropped
[t=56] server op=1 arg=6
[t=57] C1 stale #7 dropped
[t=57] server op=1 arg=7
[t=58] C1 stale #8 dropped
[t=58] server op=1 arg=8
[t=59] C1 stale #9 dropped
[t=59] server op=1 arg=11
[t=60] C1 OK 111
C1: ok 1, timeout 11, stale 9
server handled 10

@@@ hidden_input
4
3 2
10 5 10000 50
91 5 -10000 50
4 2
10 5 20 50
93 5 21 50
5 2
10 5 30 50
97 5 31 50
6 2
10 5 40 50
100 5 41 50
400
@@@ hidden_output
[t=10] C4 call op=5 arg=40
[t=10] C3 call op=5 arg=30
[t=10] C2 call op=5 arg=20
[t=10] C1 call op=5 arg=10000
[t=10] server op=5 arg=40
[t=15] C4 OK 405
[t=15] server op=5 arg=30
[t=20] C3 OK 305
[t=20] server op=5 arg=20
[t=25] C2 OK 205
[t=25] server op=5 arg=10000
[t=30] C1 OK 100005
[t=115] C4 call op=5 arg=41
[t=115] server op=5 arg=41
[t=117] C3 call op=5 arg=31
[t=118] C2 call op=5 arg=21
[t=120] C4 OK 415
[t=120] server op=5 arg=31
[t=121] C1 call op=5 arg=-10000
[t=125] C3 OK 315
[t=125] server op=5 arg=21
[t=130] C2 OK 215
[t=130] server op=5 arg=-10000
[t=135] C1 OK -99995
C1: ok 2, timeout 0, stale 0
C2: ok 2, timeout 0, stale 0
C3: ok 2, timeout 0, stale 0
C4: ok 2, timeout 0, stale 0
server handled 8

@@@ hidden_input
2
4 4
1 7 1 3
0 7 2 3
0 7 3 3
0 1 4 50
2 2
2 3 5 8
0 3 6 9
100
@@@ hidden_output
[t=1] C1 call op=7 arg=1
[t=1] server op=7 arg=1
[t=2] C2 call op=3 arg=5
[t=4] C1 TIMEOUT
[t=4] C1 call op=7 arg=2
[t=7] C1 TIMEOUT
[t=7] C1 call op=7 arg=3
[t=8] C1 stale #1 dropped
[t=8] server op=3 arg=5
[t=10] C1 TIMEOUT
[t=10] C1 call op=1 arg=4
[t=10] C2 TIMEOUT
[t=10] C2 call op=3 arg=6
[t=11] C2 stale #1 dropped
[t=11] server op=7 arg=2
[t=18] C1 stale #2 dropped
[t=18] server op=7 arg=3
[t=19] C2 TIMEOUT
[t=25] C1 stale #3 dropped
[t=25] server op=1 arg=4
[t=26] C1 OK 41
[t=26] server op=3 arg=6
C1: ok 1, timeout 3, stale 3
C2: ok 0, timeout 2, stale 1
server handled 6

@@@ hidden_input
1
3 1
1000 1 1 1000
999
@@@ hidden_output
C1: ok 0, timeout 0, stale 0
server handled 0
@@@ hint
Put the reply-queue handle **inside** the request: the server needs no knowledge of its clients, and any number of clients can share one server. Give every call a sequence number and echo it in the response. After a timeout, the late answer still arrives later, and the next call must recognise it and throw it away.
@@@ hint
`TimeOut_t to; TickType_t left = timeout; vTaskSetTimeOutState(&to); if (xQueueSend(srvq, &req, left) != pdPASS) return pdFAIL; for (;;) { if (xTaskCheckForTimeOut(&to, &left) == pdTRUE) return pdFAIL; if (xQueueReceive(c->reply, &resp, left) != pdPASS) return pdFAIL; if (resp.seq == seq) { *result = resp.result; return pdPASS; } rpc_on_stale(c, resp.seq); }`. `xTaskCheckForTimeOut()` decrements `left` by the time already spent.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    uint32_t      seq;
    uint8_t       op;
    int32_t       arg;
    QueueHandle_t reply;
} Request;

typedef struct {
    uint32_t seq;
    int32_t  result;
} Response;

typedef struct {
    QueueHandle_t reply;
    uint32_t      next_seq;
} RpcClient;

int32_t backend_execute(uint8_t op, int32_t arg);
void    rpc_on_stale(const RpcClient *c, uint32_t seq);

static QueueHandle_t s_reqq;

static void server_task(void *pvParameters)
{
    Request req;
    Response resp;

    (void)pvParameters;
    for (;;) {
        if (xQueueReceive(s_reqq, &req, portMAX_DELAY) == pdPASS) {
            resp.seq = req.seq;
            resp.result = backend_execute(req.op, req.arg);
            /* never block on a client: replace whatever (stale) reply is still there */
            xQueueOverwrite(req.reply, &resp);
        }
    }
}

QueueHandle_t rpc_server_start(void)
{
    s_reqq = xQueueCreate(8, sizeof(Request));
    if (s_reqq == NULL) {
        return NULL;
    }
    xTaskCreate(server_task, "rpc_srv", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    return s_reqq;
}

void rpc_client_init(RpcClient *c)
{
    c->reply = xQueueCreate(1, sizeof(Response));
    c->next_seq = 1;
}

BaseType_t rpc_call(RpcClient *c, uint8_t op, int32_t arg, TickType_t timeout, int32_t *result)
{
    Request req;
    Response resp;
    TimeOut_t to;
    TickType_t left = timeout;

    req.seq = c->next_seq++;
    req.op = op;
    req.arg = arg;
    req.reply = c->reply;

    vTaskSetTimeOutState(&to);                     /* the budget starts now */
    if (xQueueSend(s_reqq, &req, left) != pdPASS) {
        return pdFAIL;                              /* server queue stayed full */
    }
    for (;;) {
        if (xTaskCheckForTimeOut(&to, &left) == pdTRUE) {
            return pdFAIL;                          /* budget used up */
        }
        if (xQueueReceive(c->reply, &resp, left) != pdPASS) {
            return pdFAIL;
        }
        if (resp.seq == req.seq) {
            *result = resp.result;
            return pdPASS;
        }
        rpc_on_stale(c, resp.seq);                  /* late answer to an earlier call */
    }
}
@@@ explanation_md
**Approach.** This is the classic "client/server over queues" pattern:

- **Reply address in the request.** The request carries the client's reply-queue handle. The server is generic: it receives, executes, and answers to whatever handle the request names.
- **Server never blocks on a client.** The reply queue has length 1 and the server uses `xQueueOverwrite()`. A slow or vanished client cannot stall the server, and an unread stale reply is replaced by a newer one.
- **Correlation by sequence number.** A timeout on the client side does **not** cancel the request. It is still in the server's queue, or already executing, and its answer arrives later. Without a sequence check, the **next** call of that client would take this stale answer as its own result. That is a very real bug, and it shows up as "wrong value once in a while under load".
- **One budget for the whole call.** `vTaskSetTimeOutState()` records the start. `xTaskCheckForTimeOut()` subtracts the elapsed time from `left` each time the client waits again after a stale reply (and handles tick-count overflow), so the call never waits longer than `timeout` in total.

Same-tick behaviour comes from priorities. Clients are above the server, so `xQueueOverwrite()` in the server wakes the client, which runs immediately (it prints `OK` or `stale` before the server prints its next `server` line).

**Complexity.** Per call: O(1 + number of stale replies) CPU, two copies of the request (16 bytes) and two of the response (8 bytes). RAM: 8 x 16 bytes for the request queue, 8 bytes plus a control block per client. Worst-case latency for a call = its position in the request queue times the longest operation. That is why the budget must also cover the send.

**Common mistakes**
- No sequence number: after a timeout the next call returns the previous answer (`WRONG RESULT`).
- Draining the reply queue with `xQueueReset()` before sending: this does not help when the stale reply arrives **during** the new call (sample 1, t=16).
- Restarting the full `timeout` after each stale reply: the call can then wait far longer than its budget.
- The server using `xQueueSend(reply, ..., portMAX_DELAY)`: one client that stopped reading blocks the server for everybody.
- A global "current seq" or a shared static `Response` inside `rpc_call()`: not reentrant, and two clients corrupt each other.
- Using the address of a stack-allocated reply buffer in the request instead of a queue: when the client times out and returns, the server writes into a dead stack frame.

**Interview follow-ups**
- How would you cancel a request that timed out so the server does not waste time on it?
- Compare this to direct-to-task notifications as the reply channel (no reply queue, 32-bit result). What do you lose?
- How would you add priorities to requests (two request queues, a queue set, or `xQueueSendToFront`)?
- What happens to priority inversion when a high-priority client waits for a low-priority server? How does the server's priority choice interact with it?
