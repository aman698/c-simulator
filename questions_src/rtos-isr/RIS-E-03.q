@@@ meta
id: RIS-E-03
topic: Interrupts & ISRs
difficulty: Easy
type: FUNCTION
title: Pulse Counter Shared Between an ISR and a Task
tags: freertos, isr, critical-section, taskenter-critical, shared-data, volatile, embedded
@@@ statement_md
A fuel-flow sensor produces one pulse per 0.5 ml. Every pulse raises an interrupt that increments a shared counter. A periodic task **reads and clears** the counter and reports how many pulses arrived in the last period. If an interrupt fires between the task's read and its clear, that pulse is lost forever. Protect the task's access with a **critical section**.

```c
/* provided, shared with the ISR:  volatile uint32_t g_pulses;  (starts at 0) */
void report_pulses(uint32_t n);   /* provided: prints "[t=<now>] pulses=<n>" */

void pulse_isr(void);             /* you write: increments g_pulses */
void app_start(TickType_t period);/* you write: creates the reporting task */
```

Rules:
- `pulse_isr()` adds 1 to `g_pulses`. No critical section is needed there: the task can never interrupt an ISR.
- `app_start(period)` runs before the scheduler and creates one task with **priority 2**. Every `period` ticks (at t = period, 2*period, ...) the task reads `g_pulses`, resets it to 0, and calls `report_pulses()` with the value read.
- Every access to `g_pulses` **from the task** must be inside `taskENTER_CRITICAL()` / `taskEXIT_CRITICAL()`. Keep the critical section short: call `report_pulses()` after leaving it.

**How the race is modelled.** In this simulator, code takes zero time, so an interrupt could never hit the gap between a read and a write. To model a real CPU, the judge makes every task access to `g_pulses` **outside** a critical section take 1 tick, during which interrupts fire. It also counts each such access as `unprotected`. On a real MCU, `g_pulses = 0` after `n = g_pulses` is a load, then a store, and an interrupt between them loses its pulse in exactly the same way.

**How it is tested.** Interrupts fire at the given ticks. A pulse at the same tick as a report is included in that report: the interrupt runs right after the tick count changes, before the task wakes up. The run includes tick `D`. Finally `main()` prints

```
irqs=<n> reported=<sum of reports> pending=<g_pulses at the end> lost=<irqs - reported - pending> unprotected=<n>
```

**Input**
```
D P
N
t1 t2 ... tN        (non-decreasing; empty line when N = 0)
```

**Example**
```
Input:
30 10
6
3 5 10 10 11 25

Output:
[t=10] pulses=4
[t=20] pulses=1
[t=30] pulses=1
irqs=6 reported=6 pending=0 lost=0 unprotected=0
```
The two pulses at t=10 are counted before the task wakes at t=10, so the first report contains 4 pulses.
@@@ constraints_md
- 1 <= P <= 1000, 1 <= D <= 20000, 0 <= N <= 500, 1 <= ti <= D.
- One reporting task, priority 2, period P (use `vTaskDelayUntil()` or `xTaskDelayUntil()`).
- Do not declare `g_pulses` yourself. It is provided by the judge.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

/* provided: volatile uint32_t g_pulses; */
void report_pulses(uint32_t n);

static void report_task(void *pvParameters)
{
    TickType_t period = (TickType_t)(uintptr_t)pvParameters;
    TickType_t last = xTaskGetTickCount();

    for (;;) {
        vTaskDelayUntil(&last, period);
        /* TODO: read and clear g_pulses safely, then report */
    }
}

void pulse_isr(void)
{
    /* TODO */
}

void app_start(TickType_t period)
{
    /* TODO: create the reporting task (priority 2), pass the period */
    (void)period;
    (void)report_task;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

void pulse_isr(void);
void app_start(TickType_t period);
void report_pulses(uint32_t n);

static volatile uint32_t s_pulses;
static int g_prot, g_masked;
static unsigned g_unprot, g_reported, g_raised;

/* ---- instrumentation: track critical sections / interrupt masking ---- */
static inline void h_enter(void) { g_prot++; vPortEnterCritical(); }
static inline void h_exit(void) { g_prot--; vPortExitCritical(); }
static inline void h_disable(void) { g_masked = 1; vPortDisableInterrupts(); }
static inline void h_enable(void) { g_masked = 0; vPortEnableInterrupts(); }
static inline UBaseType_t h_setmask(void) { UBaseType_t m = uxPortSetInterruptMask(); g_masked = 1; return m; }
static inline void h_clearmask(UBaseType_t m) { g_masked = (int)m; vPortClearInterruptMask(m); }

static volatile uint32_t *pulses_ref(void)
{
    BaseType_t st;

    if (xPortIsInsideInterrupt() || g_prot > 0 || g_masked) return &s_pulses;
    st = xTaskGetSchedulerState();
    if (st == taskSCHEDULER_NOT_STARTED) return &s_pulses;
    g_unprot++;
    if (st == taskSCHEDULER_RUNNING) vSimBusyWork(1);   /* an interruptible load/store */
    return &s_pulses;
}

void report_pulses(uint32_t n)
{
    if (xPortIsInsideInterrupt()) {
        printf("FAIL: report_pulses() called from the ISR\n");
        return;
    }
    printf("[t=%u] pulses=%u\n", (unsigned)xTaskGetTickCount(), (unsigned)n);
    g_reported += (unsigned)n;
}

#undef portENTER_CRITICAL
#define portENTER_CRITICAL() h_enter()
#undef portEXIT_CRITICAL
#define portEXIT_CRITICAL() h_exit()
#undef portDISABLE_INTERRUPTS
#define portDISABLE_INTERRUPTS() h_disable()
#undef portENABLE_INTERRUPTS
#define portENABLE_INTERRUPTS() h_enable()
#undef portSET_INTERRUPT_MASK_FROM_ISR
#define portSET_INTERRUPT_MASK_FROM_ISR() h_setmask()
#undef portCLEAR_INTERRUPT_MASK_FROM_ISR
#define portCLEAR_INTERRUPT_MASK_FROM_ISR(x) h_clearmask(x)
#define g_pulses (*pulses_ref())

/*USER_CODE*/

#undef g_pulses

static void irq_entry(void *arg)
{
    (void)arg;
    g_raised++;
    pulse_isr();
}

int main(void)
{
    unsigned d, p, n, i, t, pend;

    if (scanf("%u %u %u", &d, &p, &n) != 3) return 1;
    app_start((TickType_t)p);
    for (i = 0; i < n; i++) {
        if (scanf("%u", &t) != 1) return 1;
        xSimScheduleInterrupt((TickType_t)t, irq_entry, NULL);
    }
    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();
    pend = (unsigned)s_pulses;
    printf("irqs=%u reported=%u pending=%u lost=%d unprotected=%u\n",
           g_raised, g_reported, pend, (int)(g_raised - g_reported - pend), g_unprot);
    return 0;
}
@@@ sample_input
30 10
6
3 5 10 10 11 25
@@@ sample_output
[t=10] pulses=4
[t=20] pulses=1
[t=30] pulses=1
irqs=6 reported=6 pending=0 lost=0 unprotected=0
@@@ sample_input
25 10
4
1 20 21 25
@@@ sample_output
[t=10] pulses=1
[t=20] pulses=1
irqs=4 reported=2 pending=2 lost=0 unprotected=0
@@@ hidden_input
12 4
0
<<BLANK>>
@@@ hidden_output
[t=4] pulses=0
[t=8] pulses=0
[t=12] pulses=0
irqs=0 reported=0 pending=0 lost=0 unprotected=0
@@@ hidden_input
8 2
12
1 2 3 3 3 4 5 6 7 7 8 8
@@@ hidden_output
[t=2] pulses=2
[t=4] pulses=4
[t=6] pulses=2
[t=8] pulses=4
irqs=12 reported=12 pending=0 lost=0 unprotected=0

@@@ hidden_input
20000 1000
10
1 1000 1001 1001 1002 9999 10000 10001 19999 20000
@@@ hidden_output
[t=1000] pulses=2
[t=2000] pulses=3
[t=3000] pulses=0
[t=4000] pulses=0
[t=5000] pulses=0
[t=6000] pulses=0
[t=7000] pulses=0
[t=8000] pulses=0
[t=9000] pulses=0
[t=10000] pulses=2
[t=11000] pulses=1
[t=12000] pulses=0
[t=13000] pulses=0
[t=14000] pulses=0
[t=15000] pulses=0
[t=16000] pulses=0
[t=17000] pulses=0
[t=18000] pulses=0
[t=19000] pulses=0
[t=20000] pulses=2
irqs=10 reported=10 pending=0 lost=0 unprotected=0

@@@ hidden_input
15 1
6
1 1 1 9 14 15
@@@ hidden_output
[t=1] pulses=3
[t=2] pulses=0
[t=3] pulses=0
[t=4] pulses=0
[t=5] pulses=0
[t=6] pulses=0
[t=7] pulses=0
[t=8] pulses=0
[t=9] pulses=1
[t=10] pulses=0
[t=11] pulses=0
[t=12] pulses=0
[t=13] pulses=0
[t=14] pulses=1
[t=15] pulses=1
irqs=6 reported=6 pending=0 lost=0 unprotected=0

@@@ hidden_input
60 7
9
6 7 8 13 14 15 20 21 22
@@@ hidden_output
[t=7] pulses=2
[t=14] pulses=3
[t=21] pulses=3
[t=28] pulses=1
[t=35] pulses=0
[t=42] pulses=0
[t=49] pulses=0
[t=56] pulses=0
irqs=9 reported=9 pending=0 lost=0 unprotected=0

@@@ hint
Copy and clear inside one critical section: `taskENTER_CRITICAL(); n = g_pulses; g_pulses = 0; taskEXIT_CRITICAL();`. Then call `report_pulses(n)` outside it.
@@@ hint
The ISR is just `g_pulses++;`. On a single-core MCU the task cannot run while the ISR runs, so only the task side needs protection. `taskENTER_CRITICAL()` masks the interrupts (up to `configMAX_SYSCALL_INTERRUPT_PRIORITY`), which makes the read-and-clear atomic with respect to `pulse_isr()`.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

/* provided: volatile uint32_t g_pulses; */
void report_pulses(uint32_t n);

static void report_task(void *pvParameters)
{
    TickType_t period = (TickType_t)(uintptr_t)pvParameters;
    TickType_t last = xTaskGetTickCount();
    uint32_t n;

    for (;;) {
        vTaskDelayUntil(&last, period);

        taskENTER_CRITICAL();      /* no interrupt between the read and the clear */
        n = g_pulses;
        g_pulses = 0;
        taskEXIT_CRITICAL();

        report_pulses(n);          /* slow work outside the critical section */
    }
}

void pulse_isr(void)
{
    g_pulses++;                    /* an ISR is never interrupted by a task */
}

void app_start(TickType_t period)
{
    xTaskCreate(report_task, "pulses", configMINIMAL_STACK_SIZE,
                (void *)(uintptr_t)period, 2, NULL);
}
@@@ explanation_md
**Approach.** `n = g_pulses; g_pulses = 0;` compiles to *load, store 0*. If the pulse interrupt fires between the two instructions, the ISR increments the counter and the task's store then wipes that increment out: a lost pulse, and no error anywhere. A **critical section** (`taskENTER_CRITICAL()`) masks the interrupts that may call FreeRTOS APIs, so the two accesses become one indivisible step. Keep it as short as possible: copy, clear, exit, and do the reporting outside.

The ISR side needs no protection on a single core: a task can never preempt an ISR. `g_pulses` must be `volatile`, so that the compiler reloads it from memory every time instead of caching it in a register. The judge declares it that way.

**Complexity.** O(1) per pulse and per report. The critical section lasts a few instructions, so it adds only a few cycles to the worst-case interrupt latency. RAM: one 32-bit counter.

**Common mistakes**
- Reading and clearing without a critical section. The bug shows up only when an interrupt hits a 2-instruction window, so it passes bench tests and loses pulses in the field (`lost > 0` here).
- `vTaskSuspendAll()` instead of a critical section: it stops other *tasks*, not interrupts, so it does not protect against an ISR.
- Calling `report_pulses()` (or `printf`, or anything slow or blocking) inside the critical section: interrupt latency explodes, and blocking there is illegal.
- Forgetting `volatile`: the optimiser may hoist the read out of the loop.
- Using `taskENTER_CRITICAL()` inside the ISR. The ISR form is `taskENTER_CRITICAL_FROM_ISR()`, and here it is not needed at all.

**Interview follow-ups**
- On a Cortex-M3/M4, how could you read-and-clear atomically without masking interrupts (`LDREX`/`STREX`, or C11 `atomic_exchange`)?
- Why is a plain 32-bit read of the counter (without clearing) atomic on Cortex-M, but a 64-bit counter read is not?
- What interrupts does `taskENTER_CRITICAL()` actually mask on a port with `configMAX_SYSCALL_INTERRUPT_PRIORITY`?
- How would you avoid the clear entirely, by keeping a free-running counter and computing differences?
