@@@ meta
id: RDS-H-01
topic: RTOS Design Patterns
difficulty: Hard
type: FUNCTION
title: Normal Degraded Safe Mode Manager With Healing And Escalation
tags: freertos, mode-manager, state-machine, functional-safety, task-notifications, embedded, asked-in-automotive
@@@ statement_md
An electric power steering ECU runs in one of three modes: **NORMAL** (full assist), **DEGRADED** (reduced assist) and **SAFE** (assist off). Fault detectors in interrupt context report faults being set and cleared. A **mode manager task** owns the mode and decides every transition. After each change it informs the torque controller task with a **direct-to-task notification**.

```c
typedef enum { MODE_NORMAL, MODE_DEGRADED, MODE_SAFE } Mode;
typedef enum { RSN_FAULT, RSN_CRITICAL, RSN_ESCALATE, RSN_HEALED, RSN_RESET } Reason;

/* provided by the judge */
void mode_changed(Mode from, Mode to, Reason why); /* prints "[t=<tick>] <FROM> -> <TO> (<REASON>)" */
void reset_rejected(void);                         /* prints "[t=<tick>] RESET REJECTED" */

/* you write these */
void mode_manager_start(TaskHandle_t actuator, TickType_t heal_ticks, TickType_t escalate_ticks);
void fault_set_from_isr(uint8_t fault);    /* fault 0..7 */
void fault_clear_from_isr(uint8_t fault);
void reset_request_from_isr(void);         /* ignition-cycle / service reset */
```

`mode_manager_start()` (called before the scheduler starts) creates an event queue of **16** entries and the manager task `"MODE"` with priority **5**. The three `..._from_isr()` functions post an event to the queue and yield if needed. The manager starts in NORMAL with no active fault. It keeps the set of active faults and applies these rules:

1. Faults **0..3 are minor**, faults **4..7 are critical**. SET of a fault that is already active, or CLEAR of an inactive one, changes nothing.
2. NORMAL, and a minor fault becomes active -> DEGRADED (`FAULT`).
3. NORMAL or DEGRADED, and a critical fault becomes active -> SAFE (`CRITICAL`).
4. **Escalation:** if the manager is still in DEGRADED `escalate_ticks` after entering it -> SAFE (`ESCALATE`).
5. **Healing:** in DEGRADED, a healing period starts when the set of active faults becomes **empty**. If no fault becomes active again for `heal_ticks` -> NORMAL (`HEALED`). A new fault cancels the healing.
6. SAFE is **latched**. A RESET in SAFE goes to NORMAL (`RESET`) if no fault is active, otherwise it calls `reset_rejected()`. A RESET in NORMAL or DEGRADED is ignored.
7. **Ordering:** a timed transition (4 or 5) due at tick `t` is applied **before** the events of tick `t`. If escalation and healing are due at the same tick, escalation wins (safety first). The events of a tick are handled in arrival order, each one completely.

After **every** mode change, call `mode_changed()` and then notify `actuator` with the new mode as the notification value, **overwriting** any unread value (`eSetValueWithOverwrite`). Timed transitions must use the **blocking timeout of the queue receive**: no polling and no periodic wake-ups.

**How it is tested.** The judge creates the torque task (priority 4). It waits for notifications and prints `[t=<tick>] TORQUE 100%|50%|0%` for NORMAL / DEGRADED / SAFE. The judge also creates a background task (priority 2) that keeps the CPU busy. Every input event is a simulated interrupt. The scheduler runs up to tick `D`, and then the judge prints the final mode and the number of mode changes. The torque task has a lower priority than the manager, so when several changes happen at one tick it only sees, and prints, the last one.

**Input**
```
<heal_ticks> <escalate_ticks> <D>
<m>
<tick> SET <f>  |  <tick> CLR <f>  |  <tick> RESET        (m lines, ticks non-decreasing)
```

**Example**
```
Input:
20 100 300
10
10 SET 1
30 CLR 1
40 SET 2
45 CLR 2
120 SET 0
150 SET 5
160 CLR 0
170 RESET
180 CLR 5
190 RESET

Output:
[t=10] NORMAL -> DEGRADED (FAULT)
[t=10] TORQUE 50%
[t=65] DEGRADED -> NORMAL (HEALED)
[t=65] TORQUE 100%
[t=120] NORMAL -> DEGRADED (FAULT)
[t=120] TORQUE 50%
[t=150] DEGRADED -> SAFE (CRITICAL)
[t=150] TORQUE 0%
[t=170] RESET REJECTED
[t=190] SAFE -> NORMAL (RESET)
[t=190] TORQUE 100%
final=NORMAL changes=5
```
The healing that starts at t=30 is cancelled by fault 2 at t=40. The healing that starts at t=45 completes at t=65 (45+20). The RESET at t=170 is rejected, because the critical fault 5 is still active.
@@@ constraints_md
- 1 <= heal_ticks, escalate_ticks <= 1000, 1 <= D <= 10000, 0 <= m <= 60, at most 8 events per tick, 1 <= tick < D.
- Manager: name `"MODE"`, priority 5, stack `configMINIMAL_STACK_SIZE`, event queue length 16.
- `mode_changed()` and `reset_rejected()` must be called from the manager task.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef enum { MODE_NORMAL, MODE_DEGRADED, MODE_SAFE } Mode;
typedef enum { RSN_FAULT, RSN_CRITICAL, RSN_ESCALATE, RSN_HEALED, RSN_RESET } Reason;

void mode_changed(Mode from, Mode to, Reason why);
void reset_rejected(void);

static void manager_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: wait for an event or the next deadline, apply due timed transitions first,
           then the event; notify the actuator after every change */
        vTaskDelay(1000);
    }
}

void mode_manager_start(TaskHandle_t actuator, TickType_t heal_ticks, TickType_t escalate_ticks)
{
    /* TODO: event queue (16) + "MODE" task (priority 5) */
    (void)actuator;
    (void)heal_ticks;
    (void)escalate_ticks;
    (void)manager_task;
}

void fault_set_from_isr(uint8_t fault)
{
    (void)fault;
}

void fault_clear_from_isr(uint8_t fault)
{
    (void)fault;
}

void reset_request_from_isr(void)
{
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

/*USER_CODE*/

static const char *const k_mode[] = { "NORMAL", "DEGRADED", "SAFE" };
static const char *const k_rsn[] = { "FAULT", "CRITICAL", "ESCALATE", "HEALED", "RESET" };
static int g_mode = 0;
static unsigned g_changes;
static int g_fail;

static int from_manager(const char *api)
{
    const char *who = pcTaskGetName(NULL);
    if (strcmp(who, "MODE") == 0) return 1;
    if (!g_fail) printf("FAIL: %s() called from task \"%s\"\n", api, who);
    g_fail = 1;
    return 0;
}

void mode_changed(Mode from, Mode to, Reason why)
{
    if (!from_manager("mode_changed")) return;
    if ((int)from < 0 || (int)from > 2 || (int)to < 0 || (int)to > 2 || (int)why < 0 || (int)why > 4) {
        printf("FAIL: bad enum value\n");
        return;
    }
    if ((int)from != g_mode) printf("FAIL: mode_changed() from %s but the mode is %s\n", k_mode[from], k_mode[g_mode]);
    printf("[t=%u] %s -> %s (%s)\n", (unsigned)xTaskGetTickCount(), k_mode[from], k_mode[to], k_rsn[why]);
    g_mode = (int)to;
    g_changes++;
}

void reset_rejected(void)
{
    if (!from_manager("reset_rejected")) return;
    printf("[t=%u] RESET REJECTED\n", (unsigned)xTaskGetTickCount());
}

static void torque_task(void *p)
{
    static const char *const k_torque[] = { "100%", "50%", "0%" };
    uint32_t v;

    (void)p;
    for (;;) {
        if (xTaskNotifyWait(0, 0xFFFFFFFFu, &v, portMAX_DELAY) == pdTRUE) {
            printf("[t=%u] TORQUE %s\n", (unsigned)xTaskGetTickCount(), v <= 2u ? k_torque[v] : "?");
        }
    }
}

static void background_task(void *p)
{
    (void)p;
    for (;;) vSimBusyWork(1);
}

static void isr_set(void *a) { fault_set_from_isr((uint8_t)(uintptr_t)a); }
static void isr_clr(void *a) { fault_clear_from_isr((uint8_t)(uintptr_t)a); }
static void isr_reset(void *a) { (void)a; reset_request_from_isr(); }

int main(void)
{
    unsigned heal, esc, dur, tick, f;
    char kind[8];
    int m, i;
    TaskHandle_t torque = NULL;

    if (scanf("%u %u %u %d", &heal, &esc, &dur, &m) != 4) return 1;
    xTaskCreate(torque_task, "TORQUE", configMINIMAL_STACK_SIZE, NULL, 4, &torque);
    xTaskCreate(background_task, "BG", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
    mode_manager_start(torque, (TickType_t)heal, (TickType_t)esc);
    for (i = 0; i < m; i++) {
        if (scanf("%u %7s", &tick, kind) != 2) return 1;
        if (strcmp(kind, "RESET") == 0) {
            xSimScheduleInterrupt((TickType_t)tick, isr_reset, NULL);
        } else {
            if (scanf("%u", &f) != 1 || f > 7) return 1;
            xSimScheduleInterrupt((TickType_t)tick, strcmp(kind, "SET") == 0 ? isr_set : isr_clr,
                                  (void *)(uintptr_t)f);
        }
    }
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("final=%s changes=%u\n", k_mode[g_mode], g_changes);
    return 0;
}
@@@ sample_input
20 100 300
10
10 SET 1
30 CLR 1
40 SET 2
45 CLR 2
120 SET 0
150 SET 5
160 CLR 0
170 RESET
180 CLR 5
190 RESET
@@@ sample_output
[t=10] NORMAL -> DEGRADED (FAULT)
[t=10] TORQUE 50%
[t=65] DEGRADED -> NORMAL (HEALED)
[t=65] TORQUE 100%
[t=120] NORMAL -> DEGRADED (FAULT)
[t=120] TORQUE 50%
[t=150] DEGRADED -> SAFE (CRITICAL)
[t=150] TORQUE 0%
[t=170] RESET REJECTED
[t=190] SAFE -> NORMAL (RESET)
[t=190] TORQUE 100%
final=NORMAL changes=5
@@@ sample_input
30 50 200
7
5 SET 3
20 CLR 3
50 SET 3
110 RESET
120 CLR 3
121 RESET
121 SET 4
@@@ sample_output
[t=5] NORMAL -> DEGRADED (FAULT)
[t=5] TORQUE 50%
[t=50] DEGRADED -> NORMAL (HEALED)
[t=50] NORMAL -> DEGRADED (FAULT)
[t=50] TORQUE 50%
[t=100] DEGRADED -> SAFE (ESCALATE)
[t=100] TORQUE 0%
[t=110] RESET REJECTED
[t=121] SAFE -> NORMAL (RESET)
[t=121] NORMAL -> SAFE (CRITICAL)
[t=121] TORQUE 0%
final=SAFE changes=6
@@@ hidden_input
10 10 100
0
@@@ hidden_output
final=NORMAL changes=0
@@@ hidden_input
5 5 50
2
1 SET 0
1 CLR 0
@@@ hidden_output
[t=1] NORMAL -> DEGRADED (FAULT)
[t=1] TORQUE 50%
[t=6] DEGRADED -> SAFE (ESCALATE)
[t=6] TORQUE 0%
final=SAFE changes=2

@@@ hidden_input
40 60 300
8
1 RESET
2 CLR 2
3 SET 7
3 SET 7
4 RESET
10 CLR 7
10 SET 1
11 RESET
@@@ hidden_output
[t=3] NORMAL -> SAFE (CRITICAL)
[t=3] TORQUE 0%
[t=4] RESET REJECTED
[t=11] RESET REJECTED
final=SAFE changes=1

@@@ hidden_input
25 100 400
10
10 SET 0
10 SET 1
10 SET 2
30 CLR 0
40 CLR 1
50 CLR 2
60 SET 3
70 CLR 3
95 SET 2
200 SET 2
@@@ hidden_output
[t=10] NORMAL -> DEGRADED (FAULT)
[t=10] TORQUE 50%
[t=95] DEGRADED -> NORMAL (HEALED)
[t=95] NORMAL -> DEGRADED (FAULT)
[t=95] TORQUE 50%
[t=195] DEGRADED -> SAFE (ESCALATE)
[t=195] TORQUE 0%
final=SAFE changes=4

@@@ hidden_input
30 40 300
6
10 SET 1
20 CLR 1
50 SET 6
50 CLR 6
50 RESET
90 SET 0
@@@ hidden_output
[t=10] NORMAL -> DEGRADED (FAULT)
[t=10] TORQUE 50%
[t=50] DEGRADED -> SAFE (ESCALATE)
[t=50] SAFE -> NORMAL (RESET)
[t=50] TORQUE 100%
[t=90] NORMAL -> DEGRADED (FAULT)
[t=90] TORQUE 50%
[t=130] DEGRADED -> SAFE (ESCALATE)
[t=130] TORQUE 0%
final=SAFE changes=5

@@@ hidden_input
15 1000 2000
12
100 SET 3
100 SET 2
110 CLR 2
114 CLR 3
129 SET 3
129 CLR 3
144 SET 1
150 CLR 1
165 RESET
500 SET 4
600 CLR 4
600 RESET
@@@ hidden_output
[t=100] NORMAL -> DEGRADED (FAULT)
[t=100] TORQUE 50%
[t=129] DEGRADED -> NORMAL (HEALED)
[t=129] NORMAL -> DEGRADED (FAULT)
[t=129] TORQUE 50%
[t=144] DEGRADED -> NORMAL (HEALED)
[t=144] NORMAL -> DEGRADED (FAULT)
[t=144] TORQUE 50%
[t=165] DEGRADED -> NORMAL (HEALED)
[t=165] TORQUE 100%
[t=500] NORMAL -> SAFE (CRITICAL)
[t=500] TORQUE 0%
[t=600] SAFE -> NORMAL (RESET)
[t=600] TORQUE 100%
final=NORMAL changes=8

@@@ hidden_input
50 30 500
7
10 SET 0
20 CLR 0
40 SET 1
40 CLR 1
90 SET 5
100 CLR 5
101 RESET
@@@ hidden_output
[t=10] NORMAL -> DEGRADED (FAULT)
[t=10] TORQUE 50%
[t=40] DEGRADED -> SAFE (ESCALATE)
[t=40] TORQUE 0%
[t=101] SAFE -> NORMAL (RESET)
[t=101] TORQUE 100%
final=NORMAL changes=3

@@@ hint
Keep two deadlines while DEGRADED: `esc_deadline` (set when entering DEGRADED) and `heal_deadline` (valid only while the fault set is empty). Block with `xQueueReceive(q, &ev, wait)`, where `wait` is `portMAX_DELAY` outside DEGRADED, and otherwise the time left until the nearer deadline (`deadline - now`, possibly 0).
@@@ hint
After **every** return of `xQueueReceive()`, whether it timed out or not, read `now`, apply the due timed transitions first (escalation before healing), and only then apply the received event, if any. At a tick where a deadline and an event coincide, the receive returns the event without reporting a timeout, so checking the deadlines only on timeout is the classic bug. Notify with `xTaskNotify(actuator, (uint32_t)mode, eSetValueWithOverwrite)`.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef enum { MODE_NORMAL, MODE_DEGRADED, MODE_SAFE } Mode;
typedef enum { RSN_FAULT, RSN_CRITICAL, RSN_ESCALATE, RSN_HEALED, RSN_RESET } Reason;

void mode_changed(Mode from, Mode to, Reason why);
void reset_rejected(void);

typedef enum { EV_SET, EV_CLR, EV_RESET } EvKind;
typedef struct { uint8_t kind; uint8_t fault; } ModeEvent;

#define MINOR_MASK    0x0Fu
#define CRITICAL_MASK 0xF0u

static QueueHandle_t s_evq;
static TaskHandle_t s_actuator;
static TickType_t s_heal, s_esc;

static Mode s_mode = MODE_NORMAL;
static uint32_t s_faults;              /* active fault bit set */
static TickType_t s_esc_deadline, s_heal_deadline;
static int s_healing;

static void enter(Mode to, Reason why)
{
    TickType_t now = xTaskGetTickCount();

    mode_changed(s_mode, to, why);
    s_mode = to;
    if (to == MODE_DEGRADED) {
        s_esc_deadline = now + s_esc;
        s_healing = 0;                 /* entered because a fault is active */
    }
    xTaskNotify(s_actuator, (uint32_t)to, eSetValueWithOverwrite);
}

static void apply_timeouts(TickType_t now)
{
    if (s_mode != MODE_DEGRADED) return;
    if ((TickType_t)(now - s_esc_deadline) < (TickType_t)0x80000000u) {
        enter(MODE_SAFE, RSN_ESCALATE);            /* safety first */
    } else if (s_healing && (TickType_t)(now - s_heal_deadline) < (TickType_t)0x80000000u) {
        enter(MODE_NORMAL, RSN_HEALED);
    }
}

static void apply_event(const ModeEvent *ev, TickType_t now)
{
    uint32_t bit = 1u << ev->fault;

    switch (ev->kind) {
    case EV_SET:
        if (s_faults & bit) return;                /* already active */
        s_faults |= bit;
        s_healing = 0;                             /* a new fault cancels healing */
        if ((bit & CRITICAL_MASK) && s_mode != MODE_SAFE) enter(MODE_SAFE, RSN_CRITICAL);
        else if ((bit & MINOR_MASK) && s_mode == MODE_NORMAL) enter(MODE_DEGRADED, RSN_FAULT);
        break;
    case EV_CLR:
        if (!(s_faults & bit)) return;
        s_faults &= ~bit;
        if (s_faults == 0u && s_mode == MODE_DEGRADED) {
            s_healing = 1;
            s_heal_deadline = now + s_heal;
        }
        break;
    case EV_RESET:
        if (s_mode != MODE_SAFE) return;
        if (s_faults == 0u) enter(MODE_NORMAL, RSN_RESET);
        else reset_rejected();
        break;
    }
}

static TickType_t time_to_next_deadline(TickType_t now)
{
    TickType_t next;

    if (s_mode != MODE_DEGRADED) return portMAX_DELAY;
    next = s_esc_deadline - now;
    if (s_healing && (TickType_t)(s_heal_deadline - now) < next) next = s_heal_deadline - now;
    return next;
}

static void manager_task(void *pvParameters)
{
    ModeEvent ev;

    (void)pvParameters;
    for (;;) {
        BaseType_t got = xQueueReceive(s_evq, &ev, time_to_next_deadline(xTaskGetTickCount()));
        TickType_t now = xTaskGetTickCount();

        apply_timeouts(now);           /* deadlines due at 'now' come before events of 'now' */
        if (got == pdPASS) apply_event(&ev, now);
    }
}

void mode_manager_start(TaskHandle_t actuator, TickType_t heal_ticks, TickType_t escalate_ticks)
{
    s_actuator = actuator;
    s_heal = heal_ticks;
    s_esc = escalate_ticks;
    s_evq = xQueueCreate(16, sizeof(ModeEvent));
    xTaskCreate(manager_task, "MODE", configMINIMAL_STACK_SIZE, NULL, 5, NULL);
}

static void post_from_isr(uint8_t kind, uint8_t fault)
{
    ModeEvent ev;
    BaseType_t woken = pdFALSE;

    ev.kind = kind;
    ev.fault = fault;
    (void)xQueueSendFromISR(s_evq, &ev, &woken);
    portYIELD_FROM_ISR(woken);
}

void fault_set_from_isr(uint8_t fault)
{
    if (fault < 8u) post_from_isr(EV_SET, fault);
}

void fault_clear_from_isr(uint8_t fault)
{
    if (fault < 8u) post_from_isr(EV_CLR, fault);
}

void reset_request_from_isr(void)
{
    post_from_isr(EV_RESET, 0);
}
@@@ explanation_md
**Approach.** The manager is an active object. ISRs only enqueue `{kind, fault}` events, and the manager task owns the fault set, the mode and two deadlines. Escalation and healing need no timers. While DEGRADED, the manager blocks on its queue with a timeout equal to the time left until the nearer deadline. Whether the receive returns an event or times out, the manager first applies every timed transition due "now", and then the event. This implements rule 7 exactly. In sample 2 at t=50, healing completes (NORMAL), and *then* `SET 3` degrades again: two changes at one tick.

The torque controller gets the mode through `xTaskNotify(..., eSetValueWithOverwrite)`: a one-word mailbox in which the newest value wins. The torque task has a lower priority, so it runs only after the manager has handled the whole tick. It prints `TORQUE 50%` once at t=50, and `TORQUE 0%` once at t=121, even though the manager notified it twice each time. That is the intended behaviour of a "latest state" channel. A queue would make the actuator replay stale intermediate modes.

SAFE is latched: only an explicit RESET with an empty fault set leaves it. That is the typical ISO 26262 pattern, where a safe state is never left automatically.

**Complexity.** O(1) per event and per deadline: bit operations on an 8-bit fault set and at most 2 mode changes per event. RAM: a 16-entry queue of 2-byte events, one TCB and stack, a few words of state. No CPU is used between events and deadlines (no polling). Reaction latency: the same tick (`portYIELD_FROM_ISR`).

**Common mistakes**
- Checking the deadlines only when `xQueueReceive()` times out. If an event arrives at the deadline tick, the timeout is never reported, and the healing/escalation that was due is applied in the wrong order or lost.
- Restarting the escalation timer on every new minor fault, or starting healing on every CLEAR instead of when the set becomes **empty**.
- Leaving SAFE automatically when the faults clear (SAFE must be latched).
- Using `eSetValueWithoutOverwrite` or `eIncrement` for the mode: the actuator can then miss the newest mode or see a meaningless counter.
- Calling `mode_changed()` from the ISR: the decision logic must stay in one task.
- Polling with `vTaskDelay(1)`: it wastes CPU, and the reaction comes up to one tick late.

**Interview follow-ups**
- How would you add a debounce, so that a fault must be present for N ms before it counts?
- The fault detectors run on another core or ECU: how would you make the mode decision robust to lost CLEAR messages?
- Where would you store the latched SAFE reason so that it survives a reset (NVM, DTC)?
- How do you prove (test) that every transition and every timing rule is covered?
