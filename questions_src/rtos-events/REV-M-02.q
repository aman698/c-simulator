@@@ meta
id: REV-M-02
topic: Event Groups & Notifications
difficulty: Medium
type: FUNCTION
title: Comms Manager: Four Interrupt Sources Into One Task With eSetBits
tags: freertos, task-notifications, xtasknotifywait, esetbits, isr-deferral, embedded, asked-in-automotive
@@@ statement_md
A gateway ECU has one **comms manager task** that serves four interrupt sources. Each source owns one bit of the task's notification value:

| bit | source |
|---|---|
| `0x01` | `CAN_RX` |
| `0x02` | `LIN_WAKE` |
| `0x04` | `ETH_LINK` |
| `0x08` | `DIAG_REQ` |

Use the notification value as a lightweight **event group**: the ISRs OR their bit into it (`eSetBits`), and the task collects every pending bit with one `xTaskNotifyWait()`.

```c
void comms_wake(uint32_t bits);  /* provided: prints "[t=<tick>] wake bits=0x<bits as %02x>"           */
void handle_event(int src);      /* provided: src = 0..3 (bit index); prints "[t=<tick>] handle <NAME>"
                                    and takes that source's CPU time (from the input)                    */

void app_start(UBaseType_t priority);  /* you write: create the comms task                            */
void event_isr(int src);               /* you write: called in INTERRUPT context by source src (0..3) */
```

- `event_isr(src)` sets bit `(1 << src)` with `xTaskNotifyFromISR(handle, 1u << src, eSetBits, &woken)`, then calls `portYIELD_FROM_ISR(woken)`.
- The task loops forever:
  1. Wait with `xTaskNotifyWait()` (no timeout) and receive the bits. Clear **all** bits **on exit**, none on entry.
  2. Call `comms_wake(bits)` once.
  3. Call `handle_event(src)` for every set bit, **lowest bit first** (`CAN_RX` before `LIN_WAKE` before ...).
- A source that fires several times before the task gets to it is handled **once**: its bit was simply set again. An interrupt that arrives **while** the task is handling events stays pending and is served by the next wait.

Queues, semaphores and event groups are disabled in this exercise.

**How it is tested.** The hidden `main()` reads the scenario, calls `app_start()`, schedules the interrupts and runs the scheduler up to and including tick `D`. Simulated time only moves while every task is blocked or inside `handle_event()`. Several interrupts at the same tick all run before any task. Then the harness prints, per source, how often it interrupted and how often it was handled, and a verdict:
- `LOST <NAME> (irq at t=..)`: an interrupt was never reported by a later `comms_wake()`;
- `SPURIOUS <NAME> at t=..`: `comms_wake()` reported a source that had no interrupt since it was last reported;
- `UNHANDLED <NAME> (woken at t=..)`: a reported source was not handled before the next wake-up;
- `OK` otherwise.

Note that an interrupt arriving *after* the wake-up but *before* its source's turn in the handling loop is still handled twice: once in the current pass and once more after the next wake-up. That is expected (the task cannot know the event was already covered) and is not counted as spurious.

**Input**
```
<priority> <cost CAN_RX> <cost LIN_WAKE> <cost ETH_LINK> <cost DIAG_REQ> <D>
<n>
<tick> <NAME>      (n lines, ticks non-decreasing)
```

**Example**
```
Input:
3 2 3 1 4 40
5
5 ETH_LINK
5 CAN_RX
6 LIN_WAKE
6 CAN_RX
20 LIN_WAKE

Output:
[t=5] wake bits=0x05
[t=5] handle CAN_RX
[t=7] handle ETH_LINK
[t=8] wake bits=0x03
[t=8] handle CAN_RX
[t=10] handle LIN_WAKE
[t=20] wake bits=0x02
[t=20] handle LIN_WAKE
CAN_RX irq=2 handled=2
LIN_WAKE irq=2 handled=2
ETH_LINK irq=1 handled=1
DIAG_REQ irq=0 handled=0
OK
```
Both interrupts at t=5 run before the task, so the task wakes once with `0x05`. It handles `CAN_RX` (t=5..7), then `ETH_LINK` (t=7..8). The interrupts at t=6 arrive during that work. Their bits wait in the notification value, and the next `xTaskNotifyWait()` returns them at t=8 without blocking.
@@@ constraints_md
- 1 <= priority <= 6, 1 <= cost <= 20, 1 <= D <= 10000, 0 <= n <= 200, 1 <= tick < D.
- Every interrupt is served well before `D` in the tests.
- One task; it must block in `xTaskNotifyWait()` (no polling).
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

void comms_wake(uint32_t bits);
void handle_event(int src);

static TaskHandle_t comms_handle;

static void comms_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: wait for event bits, report them, handle them lowest bit first */
        vTaskDelay(1000);
    }
}

void app_start(UBaseType_t priority)
{
    /* TODO */
    (void)priority;
    (void)comms_task;
    (void)comms_handle;
}

void event_isr(int src)
{
    /* TODO: set bit (1 << src) in the comms task's notification value */
    (void)src;
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

static const char *const g_name[4] = { "CAN_RX", "LIN_WAKE", "ETH_LINK", "DIAG_REQ" };
static TickType_t g_cost[4];
static unsigned g_irq[4], g_handled[4];
static int g_pending[4];
static TickType_t g_pending_tick[4];
static int g_bad;
static int g_src_of[200];

static uint32_t g_wake_bits;      /* bits of the last comms_wake() */
static uint32_t g_done_bits;      /* of those, already handled */
static TickType_t g_wake_tick;

static void check_previous_wake(void)
{
    int s;

    for (s = 0; s < 4; s++)
        if ((g_wake_bits & (1u << s)) && !(g_done_bits & (1u << s))) {
            printf("UNHANDLED %s (woken at t=%u)\n", g_name[s], (unsigned)g_wake_tick);
            g_bad = 1;
        }
}

void comms_wake(uint32_t bits)
{
    TickType_t now = xTaskGetTickCount();
    int s;

    printf("[t=%u] wake bits=0x%02x\n", (unsigned)now, (unsigned)bits);
    check_previous_wake();
    if (bits & ~0xFu) {
        printf("ERROR: unknown bits 0x%x\n", (unsigned)(bits & ~0xFu));
        g_bad = 1;
    }
    for (s = 0; s < 4; s++)
        if (bits & (1u << s)) {
            if (!g_pending[s]) {
                printf("SPURIOUS %s at t=%u\n", g_name[s], (unsigned)now);
                g_bad = 1;
            }
            g_pending[s] = 0;   /* every interrupt so far is covered by this wake */
        }
    g_wake_bits = bits & 0xFu;
    g_done_bits = 0;
    g_wake_tick = now;
}

void handle_event(int src)
{
    if (src < 0 || src > 3) {
        printf("ERROR: handle_event(%d)\n", src);
        g_bad = 1;
        return;
    }
    printf("[t=%u] handle %s\n", (unsigned)xTaskGetTickCount(), g_name[src]);
    g_handled[src]++;
    if (!(g_wake_bits & (1u << src)) || (g_done_bits & (1u << src))) {
        printf("ERROR: %s handled but not reported by the last comms_wake()\n", g_name[src]);
        g_bad = 1;
    }
    g_done_bits |= 1u << src;
    vSimBusyWork(g_cost[src]);
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

static void source_irq(void *arg)
{
    int src = *(const int *)arg;

    g_irq[src]++;
    if (!g_pending[src]) g_pending_tick[src] = xTaskGetTickCountFromISR();
    g_pending[src] = 1;
    event_isr(src);
}

int main(void)
{
    unsigned prio, c[4], dur, n, i, t;
    char name[16];
    int s;

    if (scanf("%u %u %u %u %u %u", &prio, &c[0], &c[1], &c[2], &c[3], &dur) != 6) return 1;
    for (s = 0; s < 4; s++) g_cost[s] = (TickType_t)c[s];
    if (scanf("%u", &n) != 1 || n > 200) return 1;
    for (i = 0; i < n; i++) {
        if (scanf("%u %15s", &t, name) != 2) return 1;
        for (s = 0; s < 4 && strcmp(name, g_name[s]) != 0; s++) {}
        if (s == 4) return 1;
        g_src_of[i] = s;
        xSimScheduleInterrupt((TickType_t)t, source_irq, &g_src_of[i]);
    }

    app_start((UBaseType_t)prio);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    for (s = 0; s < 4; s++)
        printf("%s irq=%u handled=%u\n", g_name[s], g_irq[s], g_handled[s]);
    check_previous_wake();
    for (s = 0; s < 4; s++)
        if (g_pending[s]) {
            printf("LOST %s (irq at t=%u)\n", g_name[s], (unsigned)g_pending_tick[s]);
            g_bad = 1;
        }
    if (!g_bad) printf("OK\n");
    return 0;
}
@@@ sample_input
3 2 3 1 4 40
5
5 ETH_LINK
5 CAN_RX
6 LIN_WAKE
6 CAN_RX
20 LIN_WAKE
@@@ sample_output
[t=5] wake bits=0x05
[t=5] handle CAN_RX
[t=7] handle ETH_LINK
[t=8] wake bits=0x03
[t=8] handle CAN_RX
[t=10] handle LIN_WAKE
[t=20] wake bits=0x02
[t=20] handle LIN_WAKE
CAN_RX irq=2 handled=2
LIN_WAKE irq=2 handled=2
ETH_LINK irq=1 handled=1
DIAG_REQ irq=0 handled=0
OK
@@@ sample_input
2 1 1 1 5 50
5
1 DIAG_REQ
2 DIAG_REQ
3 DIAG_REQ
4 CAN_RX
10 DIAG_REQ
@@@ sample_output
[t=1] wake bits=0x08
[t=1] handle DIAG_REQ
[t=6] wake bits=0x09
[t=6] handle CAN_RX
[t=7] handle DIAG_REQ
[t=12] wake bits=0x08
[t=12] handle DIAG_REQ
CAN_RX irq=1 handled=1
LIN_WAKE irq=0 handled=0
ETH_LINK irq=0 handled=0
DIAG_REQ irq=4 handled=3
OK
@@@ hidden_input
4 1 1 1 1 100
0
@@@ hidden_output
CAN_RX irq=0 handled=0
LIN_WAKE irq=0 handled=0
ETH_LINK irq=0 handled=0
DIAG_REQ irq=0 handled=0
OK
@@@ hidden_input
6 3 2 4 1 100
4
1 DIAG_REQ
1 ETH_LINK
1 LIN_WAKE
1 CAN_RX
@@@ hidden_output
[t=1] wake bits=0x0f
[t=1] handle CAN_RX
[t=4] handle LIN_WAKE
[t=6] handle ETH_LINK
[t=10] handle DIAG_REQ
CAN_RX irq=1 handled=1
LIN_WAKE irq=1 handled=1
ETH_LINK irq=1 handled=1
DIAG_REQ irq=1 handled=1
OK
@@@ hidden_input
1 5 5 5 5 200
6
10 CAN_RX
15 CAN_RX
20 CAN_RX
25 CAN_RX
26 LIN_WAKE
100 ETH_LINK
@@@ hidden_output
[t=10] wake bits=0x01
[t=10] handle CAN_RX
[t=15] wake bits=0x01
[t=15] handle CAN_RX
[t=20] wake bits=0x01
[t=20] handle CAN_RX
[t=25] wake bits=0x01
[t=25] handle CAN_RX
[t=30] wake bits=0x02
[t=30] handle LIN_WAKE
[t=100] wake bits=0x04
[t=100] handle ETH_LINK
CAN_RX irq=4 handled=4
LIN_WAKE irq=1 handled=1
ETH_LINK irq=1 handled=1
DIAG_REQ irq=0 handled=0
OK
@@@ hidden_input
3 2 2 2 2 300
12
50 LIN_WAKE
51 CAN_RX
51 DIAG_REQ
52 LIN_WAKE
52 ETH_LINK
53 CAN_RX
54 LIN_WAKE
55 DIAG_REQ
56 ETH_LINK
57 CAN_RX
58 CAN_RX
200 DIAG_REQ
@@@ hidden_output
[t=50] wake bits=0x02
[t=50] handle LIN_WAKE
[t=52] wake bits=0x0f
[t=52] handle CAN_RX
[t=54] handle LIN_WAKE
[t=56] handle ETH_LINK
[t=58] handle DIAG_REQ
[t=60] wake bits=0x0f
[t=60] handle CAN_RX
[t=62] handle LIN_WAKE
[t=64] handle ETH_LINK
[t=66] handle DIAG_REQ
[t=200] wake bits=0x08
[t=200] handle DIAG_REQ
CAN_RX irq=4 handled=2
LIN_WAKE irq=3 handled=3
ETH_LINK irq=2 handled=2
DIAG_REQ irq=3 handled=3
OK

@@@ hidden_input
5 10 1 1 1 500
8
100 CAN_RX
101 DIAG_REQ
102 ETH_LINK
103 LIN_WAKE
104 LIN_WAKE
105 ETH_LINK
106 DIAG_REQ
110 CAN_RX
@@@ hidden_output
[t=100] wake bits=0x01
[t=100] handle CAN_RX
[t=110] wake bits=0x0f
[t=110] handle CAN_RX
[t=120] handle LIN_WAKE
[t=121] handle ETH_LINK
[t=122] handle DIAG_REQ
CAN_RX irq=2 handled=2
LIN_WAKE irq=2 handled=1
ETH_LINK irq=2 handled=1
DIAG_REQ irq=2 handled=1
OK

@@@ hint
`xTaskNotifyFromISR(handle, 1u << src, eSetBits, &woken)` ORs the bit into the task's value, so two different sources can never overwrite each other. Then `portYIELD_FROM_ISR(woken)`.
@@@ hint
`xTaskNotifyWait(0, 0xFFFFFFFFu, &bits, portMAX_DELAY)`: no bit is cleared on entry, all bits on exit. Bits that ISRs set while you were handling stay in the value, and the next wait returns them immediately. Then `for (src = 0; src < 4; src++) if (bits & (1u << src)) handle_event(src);`.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

void comms_wake(uint32_t bits);
void handle_event(int src);

static TaskHandle_t comms_handle;

static void comms_task(void *pvParameters)
{
    uint32_t bits;
    int src;

    (void)pvParameters;
    for (;;) {
        /* clear nothing on entry, everything we return on exit */
        (void)xTaskNotifyWait(0u, 0xFFFFFFFFu, &bits, portMAX_DELAY);
        comms_wake(bits);
        for (src = 0; src < 4; src++)
            if (bits & (1u << src))
                handle_event(src);
    }
}

void app_start(UBaseType_t priority)
{
    xTaskCreate(comms_task, "comms", configMINIMAL_STACK_SIZE, NULL, priority, &comms_handle);
}

void event_isr(int src)
{
    BaseType_t woken = pdFALSE;

    (void)xTaskNotifyFromISR(comms_handle, 1u << src, eSetBits, &woken);
    portYIELD_FROM_ISR(woken);
}
@@@ explanation_md
**Approach.** With `eSetBits`, a task's 32-bit notification value works as a private event group that ISRs can write **directly**. No deferral through the timer task is needed, unlike `xEventGroupSetBitsFromISR()`. Each source ORs in its own bit. The task waits with

```c
xTaskNotifyWait(/*clear on entry*/ 0, /*clear on exit*/ 0xFFFFFFFF, &bits, portMAX_DELAY);
```

It gets every bit that was pending and resets the value atomically. Bits set during the handling phase arrive in the "notification pending" state, so the next wait returns at once. Nothing is lost, and repeated interrupts of one source merge into one handling.

Why "clear on exit" and not "on entry": `ulBitsToClearOnEntry` is applied only when **no** notification is pending. Clearing on entry and not on exit therefore leaves the old bits in the value whenever a new interrupt came in meanwhile, and they get handled twice (`SPURIOUS`).

**Complexity.** O(1) per interrupt. Per wake-up, O(number of sources) to scan the bits, plus the handling time. RAM: zero extra kernel objects. Worst-case latency of a source = the longest handling pass in progress (here the sum of all costs).

**Common mistakes**
- `eSetValueWithOverwrite` or `eIncrement` instead of `eSetBits`: simultaneous sources overwrite each other (`LOST`).
- `xTaskNotifyWait(0xFFFFFFFF, 0, ...)`: clear on entry only, so stale bits are handled twice when new events arrived during handling.
- Handling only the first set bit per wake-up and clearing all of them: the other sources are lost.
- Calling `xTaskNotify()` (task version) from the ISR, or forgetting `portYIELD_FROM_ISR`.

**Interview follow-ups**
- Notification bits versus an event group: what can an event group do that this cannot? (Several waiting tasks, wait-for-all, `xEventGroupSync`.)
- A source must not be merged (every CAN frame counts): how do you change the design?
- How would you give `DIAG_REQ` priority over a long `CAN_RX` burst?
- Can the task also wait for a "stop" command from another task on the same value? What about index 1?
