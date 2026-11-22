@@@ meta
id: REV-M-04
topic: Event Groups & Notifications
difficulty: Medium
type: FUNCTION
title: Gateway Task With Three Independent Indexed Notification Channels
tags: freertos, task-notifications, indexed-notifications, esetvaluewithoverwrite, request-response, embedded, asked-in-automotive
@@@ statement_md
Since FreeRTOS V10.4, every task has an **array** of notification values (`configTASK_NOTIFICATION_ARRAY_ENTRIES` = 3 here). Each index has its own value and its own pending state. A task blocked on index 2 is **not** woken by a notification on index 0 or 1. Use the three indexes of one **gateway task** as three independent channels:

| index | channel | written by | semantics |
|---|---|---|---|
| 0 `IDX_CMD` | command mailbox | `cmd_isr()` | `eSetValueWithOverwrite`: the **latest** command wins |
| 1 `IDX_RX` | received-frame counter | `rx_isr()` | `vTaskNotifyGiveIndexedFromISR`: counts frames |
| 2 `IDX_ACK` | "NVM write complete" | NVM task | give/take |

```c
#define CMD_STATUS 1u
#define CMD_SAVE   2u

void report_status(uint32_t rx_frames); /* provided: prints "[t=<tick>] status rx=<n>"           */
void report_save(int ok);               /* provided: prints "[t=<tick>] save OK" / "save TIMEOUT" */
void nvm_write(void);                   /* provided: prints "[t=<tick>] nvm write start", blocks for
                                           this write's duration, prints "[t=<tick>] nvm write done" */

void app_start(UBaseType_t gw_prio, UBaseType_t nvm_prio, TickType_t save_timeout); /* you write */
void cmd_isr(uint32_t cmd);             /* you write: INTERRUPT context, cmd = CMD_STATUS or CMD_SAVE */
void rx_isr(void);                      /* you write: INTERRUPT context, one call per received frame */
```

**Gateway task** (priority `gw_prio`). It loops forever: block on index 0 until a command arrives (clear the value on exit), then:
- `CMD_STATUS`: read **and reset** the frame counter of index 1 **without blocking**, then call `report_status(count)`.
- `CMD_SAVE`: first throw away any **stale** acknowledgement left on index 2 (a write that completed after an earlier timeout must not complete this save). Then notify the NVM task, and wait on index 2 for at most `save_timeout` ticks. Call `report_save(1)` if the acknowledgement came, `report_save(0)` on timeout.

**NVM task** (priority `nvm_prio`, lower than the gateway). It loops forever: wait for a request (on its own index 0), call `nvm_write()`, then notify the gateway on index 2.

**ISRs.** Both ISRs use the `...IndexedFromISR` API on the gateway's handle, followed by `portYIELD_FROM_ISR()`. While the gateway waits for an acknowledgement, new frames and commands must **not** wake it: they stay pending on their own index. Several commands that arrive meanwhile overwrite each other, so only the latest is executed afterwards.

Queues, semaphores and event groups are disabled in this exercise.

**How it is tested.** The hidden `main()` reads the scenario, calls `app_start()`, schedules the interrupts and runs the scheduler up to and including tick `D`. Several interrupts at one tick all run (in input order) before any task. The provided functions check every report and print `ERROR: ...` if the status count is wrong or a save is acknowledged by a stale completion. At the end the harness prints `commands=<sent> reports=<calls of report_*>` and `OK` if no error was seen.

**Input**
```
<gw_prio> <nvm_prio> <save_timeout> <D>
<w> <d1> ... <dw>        (durations of the 1st, 2nd, ... NVM write)
<n>
<tick> <RX|STATUS|SAVE>  (n lines, ticks non-decreasing)
```

**Example**
```
Input:
3 2 20 120
3 5 30 5
9
3 RX
4 RX
8 RX
10 STATUS
20 SAVE
22 RX
30 STATUS
40 SAVE
80 SAVE

Output:
[t=10] status rx=3
[t=20] nvm write start
[t=25] nvm write done
[t=25] save OK
[t=30] status rx=1
[t=40] nvm write start
[t=60] save TIMEOUT
[t=70] nvm write done
[t=80] nvm write start
[t=85] nvm write done
[t=85] save OK
commands=5 reports=5
OK
```
The RX interrupts never wake the gateway: they only count on index 1. The second write takes 30 ticks, so the save times out at t=60. Its late acknowledgement at t=70 lands on index 2 while the gateway is blocked on index 0, so it does not wake the gateway. It would complete the third save at once if it were not thrown away at t=80.
@@@ constraints_md
- 1 <= nvm_prio < gw_prio <= 6, 1 <= save_timeout <= 1000, 1 <= D <= 10000, 0 <= n <= 200, 1 <= tick < D.
- In the tests, the gateway never *starts* a SAVE while an NVM write is still in progress, and no acknowledgement arrives exactly at a timeout tick.
- Two tasks, task notifications only, no polling.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

#define CMD_STATUS 1u
#define CMD_SAVE   2u
#define IDX_CMD 0
#define IDX_RX  1
#define IDX_ACK 2

void report_status(uint32_t rx_frames);
void report_save(int ok);
void nvm_write(void);

static TaskHandle_t gw_handle, nvm_handle;
static TickType_t save_wait;

static void gateway_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: wait for a command on IDX_CMD and execute it */
        vTaskDelay(1000);
    }
}

static void nvm_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: wait for a request, nvm_write(), acknowledge on the gateway's IDX_ACK */
        vTaskDelay(1000);
    }
}

void app_start(UBaseType_t gw_prio, UBaseType_t nvm_prio, TickType_t save_timeout)
{
    /* TODO: create both tasks */
    (void)gw_prio; (void)nvm_prio;
    (void)gateway_task; (void)nvm_task;
    (void)gw_handle; (void)nvm_handle;
    save_wait = save_timeout;
}

void cmd_isr(uint32_t cmd)
{
    /* TODO */
    (void)cmd;
}

void rx_isr(void)
{
    /* TODO */
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "event_groups.h"
#include "sim.h"

static unsigned g_dur[50], g_ndur, g_writes;
static unsigned g_rx_since;          /* frames since the last status report */
static unsigned g_cmds, g_reports, g_errors;
static int g_write_busy;
static TickType_t g_last_write_start;
static TickType_t g_last_report;
static int g_any_write;

void report_status(uint32_t rx_frames)
{
    TickType_t now = xTaskGetTickCount();

    printf("[t=%u] status rx=%u\n", (unsigned)now, (unsigned)rx_frames);
    if (rx_frames != g_rx_since) {
        printf("ERROR: %u frames were received since the last status\n", g_rx_since);
        g_errors++;
    }
    g_rx_since = 0;
    g_reports++;
    g_last_report = now;
}

void report_save(int ok)
{
    TickType_t now = xTaskGetTickCount();

    printf("[t=%u] save %s\n", (unsigned)now, ok ? "OK" : "TIMEOUT");
    if (ok && (!g_any_write || g_write_busy || g_last_write_start < g_last_report)) {
        printf("ERROR: save acknowledged without a completed write for this request\n");
        g_errors++;
    }
    g_reports++;
    g_last_report = now;
}

void nvm_write(void)
{
    TickType_t d = 1;

    printf("[t=%u] nvm write start\n", (unsigned)xTaskGetTickCount());
    if (g_writes < g_ndur) d = (TickType_t)g_dur[g_writes];
    else {
        printf("ERROR: unexpected NVM write\n");
        g_errors++;
    }
    g_writes++;
    g_any_write = 1;
    g_write_busy = 1;
    g_last_write_start = xTaskGetTickCount();
    vTaskDelay(d);
    g_write_busy = 0;
    printf("[t=%u] nvm write done\n", (unsigned)xTaskGetTickCount());
}

/* this exercise is about task notifications */
#define xQueueGenericCreate(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueGenericCreateStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateCountingSemaphore(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateCountingSemaphoreStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateMutex(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateMutexStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xEventGroupCreate(...) event_groups_are_disabled_in_this_exercise
#define xEventGroupCreateStatic(...) event_groups_are_disabled_in_this_exercise

/*USER_CODE*/

#undef xQueueGenericCreate
#undef xQueueGenericCreateStatic
#undef xQueueCreateCountingSemaphore
#undef xQueueCreateCountingSemaphoreStatic
#undef xQueueCreateMutex
#undef xQueueCreateMutexStatic
#undef xEventGroupCreate
#undef xEventGroupCreateStatic

static const uint32_t g_cmd_status = CMD_STATUS;
static const uint32_t g_cmd_save = CMD_SAVE;

static void rx_irq(void *arg)
{
    (void)arg;
    g_rx_since++;
    rx_isr();
}

static void cmd_irq(void *arg)
{
    g_cmds++;
    cmd_isr(*(const uint32_t *)arg);
}

int main(void)
{
    unsigned gw, nvm, timeout, dur, n, i, t;
    char ev[16];

    if (scanf("%u %u %u %u", &gw, &nvm, &timeout, &dur) != 4) return 1;
    if (scanf("%u", &g_ndur) != 1 || g_ndur > 50) return 1;
    for (i = 0; i < g_ndur; i++)
        if (scanf("%u", &g_dur[i]) != 1) return 1;
    if (scanf("%u", &n) != 1 || n > 200) return 1;
    for (i = 0; i < n; i++) {
        if (scanf("%u %15s", &t, ev) != 2) return 1;
        if (strcmp(ev, "RX") == 0) xSimScheduleInterrupt((TickType_t)t, rx_irq, NULL);
        else if (strcmp(ev, "STATUS") == 0) xSimScheduleInterrupt((TickType_t)t, cmd_irq, (void *)&g_cmd_status);
        else if (strcmp(ev, "SAVE") == 0) xSimScheduleInterrupt((TickType_t)t, cmd_irq, (void *)&g_cmd_save);
        else return 1;
    }

    app_start((UBaseType_t)gw, (UBaseType_t)nvm, (TickType_t)timeout);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("commands=%u reports=%u\n", g_cmds, g_reports);
    if (g_errors == 0) printf("OK\n");
    return 0;
}
@@@ sample_input
3 2 20 120
3 5 30 5
9
3 RX
4 RX
8 RX
10 STATUS
20 SAVE
22 RX
30 STATUS
40 SAVE
80 SAVE
@@@ sample_output
[t=10] status rx=3
[t=20] nvm write start
[t=25] nvm write done
[t=25] save OK
[t=30] status rx=1
[t=40] nvm write start
[t=60] save TIMEOUT
[t=70] nvm write done
[t=80] nvm write start
[t=85] nvm write done
[t=85] save OK
commands=5 reports=5
OK
@@@ sample_input
4 1 50 100
1 10
4
5 SAVE
7 SAVE
9 RX
12 STATUS
@@@ sample_output
[t=5] nvm write start
[t=15] nvm write done
[t=15] save OK
[t=15] status rx=1
commands=3 reports=2
OK
@@@ hidden_input
2 1 10 50
0
0
@@@ hidden_output
commands=0 reports=0
OK
@@@ hidden_input
6 5 100 50
0
4
1 STATUS
1 RX
2 RX
3 STATUS
@@@ hidden_output
[t=1] status rx=1
[t=3] status rx=1
commands=2 reports=2
OK
@@@ hidden_input
5 2 15 300
4 40 3 30 7
8
10 SAVE
25 RX
30 STATUS
60 SAVE
100 SAVE
200 SAVE
210 STATUS
220 STATUS
@@@ hidden_output
[t=10] nvm write start
[t=25] save TIMEOUT
[t=30] status rx=1
[t=50] nvm write done
[t=60] nvm write start
[t=63] nvm write done
[t=63] save OK
[t=100] nvm write start
[t=115] save TIMEOUT
[t=130] nvm write done
[t=200] nvm write start
[t=207] nvm write done
[t=207] save OK
[t=210] status rx=0
[t=220] status rx=0
commands=7 reports=7
OK
@@@ hidden_input
3 1 30 200
3 20 20 20
10
1 RX
2 RX
5 SAVE
6 RX
7 STATUS
8 RX
9 STATUS
40 SAVE
41 SAVE
42 RX
@@@ hidden_output
[t=5] nvm write start
[t=25] nvm write done
[t=25] save OK
[t=25] status rx=4
[t=40] nvm write start
[t=60] nvm write done
[t=60] save OK
[t=60] nvm write start
[t=80] nvm write done
[t=80] save OK
commands=5 reports=4
OK

@@@ hidden_input
6 3 5 500
3 4 6 1
12
100 RX
100 RX
100 RX
100 STATUS
101 SAVE
150 SAVE
157 RX
160 STATUS
170 SAVE
171 RX
171 RX
180 STATUS
@@@ hidden_output
[t=100] status rx=3
[t=101] nvm write start
[t=105] nvm write done
[t=105] save OK
[t=150] nvm write start
[t=155] save TIMEOUT
[t=156] nvm write done
[t=160] status rx=1
[t=170] nvm write start
[t=171] nvm write done
[t=171] save OK
[t=180] status rx=2
commands=6 reports=6
OK

@@@ hint
Every notification API has an `...Indexed` form whose 2nd argument is the index: `xTaskNotifyWaitIndexed(IDX_CMD, 0, 0xFFFFFFFFu, &cmd, portMAX_DELAY)`, `ulTaskNotifyTakeIndexed(IDX_RX, pdTRUE, 0)` (non-blocking read-and-reset), `xTaskNotifyIndexedFromISR(gw, IDX_CMD, cmd, eSetValueWithOverwrite, &woken)`, `vTaskNotifyGiveIndexedFromISR(gw, IDX_RX, &woken)`.
@@@ hint
For SAVE: `(void)ulTaskNotifyTakeIndexed(IDX_ACK, pdTRUE, 0);` drops a stale acknowledgement (or use `xTaskNotifyStateClearIndexed` + `ulTaskNotifyValueClearIndexed`). Then `xTaskNotifyGive(nvm_handle); ok = ulTaskNotifyTakeIndexed(IDX_ACK, pdTRUE, save_wait) != 0;`. The NVM task acknowledges with `xTaskNotifyGiveIndexed(gw_handle, IDX_ACK)`.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

#define CMD_STATUS 1u
#define CMD_SAVE   2u
#define IDX_CMD 0
#define IDX_RX  1
#define IDX_ACK 2

void report_status(uint32_t rx_frames);
void report_save(int ok);
void nvm_write(void);

static TaskHandle_t gw_handle, nvm_handle;
static TickType_t save_wait;

static void gateway_task(void *pvParameters)
{
    uint32_t cmd;

    (void)pvParameters;
    for (;;) {
        /* index 0 only: RX frames and late acks do not wake us here */
        (void)xTaskNotifyWaitIndexed(IDX_CMD, 0u, 0xFFFFFFFFu, &cmd, portMAX_DELAY);

        if (cmd == CMD_STATUS) {
            uint32_t frames = ulTaskNotifyTakeIndexed(IDX_RX, pdTRUE, 0);  /* read + reset, no block */
            report_status(frames);
        } else if (cmd == CMD_SAVE) {
            (void)ulTaskNotifyTakeIndexed(IDX_ACK, pdTRUE, 0);   /* drop a stale completion */
            xTaskNotifyGive(nvm_handle);                         /* request (NVM's index 0) */
            report_save(ulTaskNotifyTakeIndexed(IDX_ACK, pdTRUE, save_wait) != 0);
        }
    }
}

static void nvm_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        (void)ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        nvm_write();
        xTaskNotifyGiveIndexed(gw_handle, IDX_ACK);
    }
}

void app_start(UBaseType_t gw_prio, UBaseType_t nvm_prio, TickType_t save_timeout)
{
    save_wait = save_timeout;
    xTaskCreate(gateway_task, "gw", configMINIMAL_STACK_SIZE, NULL, gw_prio, &gw_handle);
    xTaskCreate(nvm_task, "nvm", configMINIMAL_STACK_SIZE, NULL, nvm_prio, &nvm_handle);
}

void cmd_isr(uint32_t cmd)
{
    BaseType_t woken = pdFALSE;

    /* one-slot mailbox: a newer command replaces an unprocessed one */
    (void)xTaskNotifyIndexedFromISR(gw_handle, IDX_CMD, cmd, eSetValueWithOverwrite, &woken);
    portYIELD_FROM_ISR(woken);
}

void rx_isr(void)
{
    BaseType_t woken = pdFALSE;

    vTaskNotifyGiveIndexedFromISR(gw_handle, IDX_RX, &woken);
    portYIELD_FROM_ISR(woken);     /* woken stays pdFALSE: nobody waits on IDX_RX */
}
@@@ explanation_md
**Approach.** One task, three channels, three semantics:
- **Index 0, mailbox.** `eSetValueWithOverwrite` stores the command code and marks it pending. `xTaskNotifyWaitIndexed(0, 0, ~0, &cmd, ...)` returns it and clears it.
- **Index 1, counter.** Each frame `Give`s. `ulTaskNotifyTakeIndexed(1, pdTRUE, 0)` reads and resets it **without blocking**, which is a lock-free "fetch and clear".
- **Index 2, completion.** Request/response with the NVM task, with a timeout.

The key property: a task blocked on index *k* is woken only by a notification on index *k*. While the gateway waits for the NVM acknowledgement, RX frames and new commands just accumulate on their own index. While it waits for commands, a late acknowledgement accumulates on index 2. That leftover is why the SAVE path first **drains index 2**. Otherwise the third save in the example would "succeed" at t=80, before the write even started.

**Complexity.** Every operation is O(1). RAM: zero kernel objects, 3 x (4-byte value + 1-byte state) in the TCB. Worst-case command latency = `save_timeout` (the gateway is busy waiting for an acknowledgement), and only the last command of that window survives.

**Common mistakes**
- Using index 0 for everything: frames or a late acknowledgement wake the command wait with a bogus value.
- Blocking on index 1 (`ulTaskNotifyTakeIndexed(IDX_RX, pdTRUE, portMAX_DELAY)`) for STATUS: it hangs when no frame arrived.
- Not clearing the stale acknowledgement: a save is reported OK before its write happened.
- Using `eSetValueWithoutOverwrite` or `eSetBits` for the mailbox: an older command survives, or two command codes are OR-ed into garbage.
- Clearing index 2 **after** notifying the NVM task: a fast (higher-priority) NVM task could already have acknowledged, and the real acknowledgement is erased.

**Interview follow-ups**
- Why do FreeRTOS libraries (stream buffers, some drivers) reserve index 0, and how does that affect application code?
- How would you make sure no command is ever lost, and what does it cost compared with a mailbox?
- What does `xTaskNotifyStateClearIndexed()` do that `ulTaskNotifyValueClearIndexed()` does not?
- How would you tag each request with a sequence number so a stale acknowledgement can be recognised instead of just discarded?
