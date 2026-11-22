@@@ meta
id: RIS-E-01
topic: Interrupts & ISRs
difficulty: Easy
type: FUNCTION
title: Deferred Button Handler With a Binary Semaphore
tags: freertos, isr, deferred-interrupt, binary-semaphore, portyield-from-isr, embedded
@@@ statement_md
A body-control ECU reads a door button. The button interrupt must stay **short**: it only signals a handler task, and the task does the real work (debounce, CAN message, ...). This is the classic *deferred interrupt handling* pattern. Write it with a **binary semaphore**.

```c
void service_button(void);   /* provided: services ALL button events latched so far (task context only) */

void button_isr(void);       /* you write: the interrupt handler */
void app_start(void);        /* you write: create the semaphore and the handler task */
```

Rules:
- `app_start()` is called **before** the scheduler starts. It creates a binary semaphore (`xSemaphoreCreateBinary()`) and one handler task with **priority 3**.
- The handler task loops forever: wait for the semaphore with `portMAX_DELAY`, then call `service_button()`.
- `button_isr()` runs in interrupt context. It may only use `...FromISR()` APIs: give the semaphore with `xSemaphoreGiveFromISR()` and request a context switch with `portYIELD_FROM_ISR()`, so the handler runs **at the tick of the interrupt** (latency 0), not one tick later.
- `service_button()` must never be called from the ISR.

**How it is tested.** The hidden `main()` also creates a background task with priority 1 that is always busy (it computes all the time). Interrupts fire at the ticks given in the input. Each call of `service_button()` prints:

```
[t=<now>] serviced <k> event(s), latency <now - tick of the oldest unserviced event>
```

followed by ` LATE` when the latency is not 0. Several interrupts at the same tick give the (binary) semaphore several times, but the handler wakes only once: that is fine, because `service_button()` services every event latched so far. The run includes tick `D`: an interrupt at tick `D` must still be serviced at tick `D`. Finally `main()` prints `interrupts=<n> serviced=<n> late=<n>`.

**Input**
```
D N
t1 t2 ... tN
```
The interrupt ticks are non-decreasing (the second line is empty when `N = 0`).

**Example**
```
Input:
20 4
3 7 7 15

Output:
[t=3] serviced 1 event(s), latency 0
[t=7] serviced 2 event(s), latency 0
[t=15] serviced 1 event(s), latency 0
interrupts=4 serviced=4 late=0
```
At t=7 two interrupts fire back to back, before any task runs. The first give wakes the handler; the second give fails because a binary semaphore holds at most one "token". The ISR returns, `portYIELD_FROM_ISR(pdTRUE)` switches to the handler (priority 3 beats the busy priority-1 task) still at t=7, and it services both events. Without `portYIELD_FROM_ISR` every line would show `t+1` and `latency 1 LATE`.
@@@ constraints_md
- 1 <= D <= 20000, 0 <= N <= 200, 1 <= t1 <= t2 <= ... <= tN <= D.
- Use a binary semaphore and exactly one handler task (priority 3). No polling, no `vTaskDelay` in the handler.
- Only `...FromISR()` APIs inside `button_isr()`; calling a task-level API there is a Runtime Error.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

void service_button(void);   /* provided */

static SemaphoreHandle_t s_button_sem;

static void button_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: wait for the semaphore, then call service_button() */
        vTaskDelay(1000);
    }
}

void button_isr(void)
{
    /* TODO: give the semaphore from the ISR and request a context switch */
}

void app_start(void)
{
    /* TODO: create the binary semaphore and the handler task (priority 3) */
    (void)s_button_sem;
    (void)button_task;
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "sim.h"

void button_isr(void);
void app_start(void);
void service_button(void);

static unsigned g_raised, g_serviced, g_late, g_pending;
static TickType_t g_oldest;
static int g_in_isr;

void service_button(void)
{
    unsigned now, lat;

    if (g_in_isr) {
        printf("FAIL: service_button() called from the ISR (it is task-level work)\n");
        g_pending = 0;
        return;
    }
    now = (unsigned)xTaskGetTickCount();
    if (g_pending == 0) {
        printf("[t=%u] spurious wake-up: nothing to service\n", now);
        return;
    }
    lat = now - (unsigned)g_oldest;
    printf("[t=%u] serviced %u event(s), latency %u%s\n", now, g_pending, lat, lat ? " LATE" : "");
    g_serviced += g_pending;
    if (lat) g_late += g_pending;
    g_pending = 0;
}

/*USER_CODE*/

static void irq_entry(void *arg)
{
    (void)arg;
    g_raised++;
    if (g_pending++ == 0) g_oldest = xTaskGetTickCountFromISR();
    g_in_isr = 1;
    button_isr();
    g_in_isr = 0;
}

static void background_task(void *p)
{
    (void)p;
    for (;;) vSimBusyWork(1);   /* main application loop: always computing */
}

int main(void)
{
    unsigned d, n, i, t;

    if (scanf("%u %u", &d, &n) != 2) return 1;
    app_start();
    xTaskCreate(background_task, "bg", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    for (i = 0; i < n; i++) {
        if (scanf("%u", &t) != 1) return 1;
        xSimScheduleInterrupt((TickType_t)t, irq_entry, NULL);
    }
    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();
    printf("interrupts=%u serviced=%u late=%u\n", g_raised, g_serviced, g_late);
    return 0;
}
@@@ sample_input
20 4
3 7 7 15
@@@ sample_output
[t=3] serviced 1 event(s), latency 0
[t=7] serviced 2 event(s), latency 0
[t=15] serviced 1 event(s), latency 0
interrupts=4 serviced=4 late=0
@@@ sample_input
10 3
1 2 10
@@@ sample_output
[t=1] serviced 1 event(s), latency 0
[t=2] serviced 1 event(s), latency 0
[t=10] serviced 1 event(s), latency 0
interrupts=3 serviced=3 late=0
@@@ hidden_input
50 0
<<BLANK>>
@@@ hidden_output
interrupts=0 serviced=0 late=0
@@@ hidden_input
30 6
5 5 5 5 5 30
@@@ hidden_output
[t=5] serviced 5 event(s), latency 0
[t=30] serviced 1 event(s), latency 0
interrupts=6 serviced=6 late=0
@@@ hidden_input
12 12
1 2 3 4 5 6 7 8 9 10 11 12
@@@ hidden_output
[t=1] serviced 1 event(s), latency 0
[t=2] serviced 1 event(s), latency 0
[t=3] serviced 1 event(s), latency 0
[t=4] serviced 1 event(s), latency 0
[t=5] serviced 1 event(s), latency 0
[t=6] serviced 1 event(s), latency 0
[t=7] serviced 1 event(s), latency 0
[t=8] serviced 1 event(s), latency 0
[t=9] serviced 1 event(s), latency 0
[t=10] serviced 1 event(s), latency 0
[t=11] serviced 1 event(s), latency 0
[t=12] serviced 1 event(s), latency 0
interrupts=12 serviced=12 late=0

@@@ hidden_input
20000 5
1 999 1000 1000 20000
@@@ hidden_output
[t=1] serviced 1 event(s), latency 0
[t=999] serviced 1 event(s), latency 0
[t=1000] serviced 2 event(s), latency 0
[t=20000] serviced 1 event(s), latency 0
interrupts=5 serviced=5 late=0

@@@ hidden_input
100 3
40 40 41
@@@ hidden_output
[t=40] serviced 2 event(s), latency 0
[t=41] serviced 1 event(s), latency 0
interrupts=3 serviced=3 late=0

@@@ hint
The ISR body is three lines: a local `BaseType_t woken = pdFALSE;`, `xSemaphoreGiveFromISR(sem, &woken);`, `portYIELD_FROM_ISR(woken);`. The task is a `for (;;)` loop around `xSemaphoreTake(sem, portMAX_DELAY)`.
@@@ hint
`xSemaphoreGiveFromISR()` sets `woken` to `pdTRUE` when the give unblocked a task with a higher priority than the one that was interrupted (here: the priority-3 handler vs the priority-1 background task). `portYIELD_FROM_ISR(woken)` then switches to it as soon as the ISR returns. Forgetting it delays the handler until the next tick interrupt.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

void service_button(void);   /* provided */

static SemaphoreHandle_t s_button_sem;

static void button_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* block (no CPU used) until the ISR signals */
        if (xSemaphoreTake(s_button_sem, portMAX_DELAY) == pdTRUE) {
            service_button();          /* the real work, in task context */
        }
    }
}

void button_isr(void)
{
    BaseType_t woken = pdFALSE;        /* must start as pdFALSE */

    xSemaphoreGiveFromISR(s_button_sem, &woken);  /* fails harmlessly if already given */
    portYIELD_FROM_ISR(woken);         /* run the handler now, not at the next tick */
}

void app_start(void)
{
    s_button_sem = xSemaphoreCreateBinary();      /* created "empty" */
    configASSERT(s_button_sem != NULL);
    xTaskCreate(button_task, "button", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
}
@@@ explanation_md
**Approach.** The ISR does the minimum: one `xSemaphoreGiveFromISR()` and one `portYIELD_FROM_ISR()`. The handler task sleeps in `xSemaphoreTake(..., portMAX_DELAY)` and does the work in task context, where it may block, print, take mutexes, and so on. A binary semaphore created with `xSemaphoreCreateBinary()` starts empty, so the task blocks until the first interrupt.

`xSemaphoreGiveFromISR()` cannot switch context by itself. It only reports, through `pxHigherPriorityTaskWoken`, that the task it unblocked has a higher priority than the interrupted task. `portYIELD_FROM_ISR(woken)` turns that report into a context switch at the end of the ISR, so the priority-3 handler preempts the busy priority-1 task **at the same tick**. Without it, the switch waits for the next tick interrupt: latency 1 tick (on real hardware: up to one full tick period). An interrupt at the last tick `D` is the sharpest test: without the yield, it is never serviced at all.

A binary semaphore is a one-bit "something happened" flag. Two interrupts before the handler runs collapse into one wake-up. That is correct here only because `service_button()` services every latched event, just as a real handler reads the device's status register and handles everything it finds. RIS-M-03 shows what goes wrong when each event must be counted.

**Complexity.** ISR: O(1), a few dozen instructions. Handler: O(1) per wake-up plus the service work. RAM: one semaphore (a queue of length 0, ~80 bytes) plus one task stack. Worst-case latency with the yield: the ISR time plus one context switch (0 ticks here).

**Common mistakes**
- Forgetting `portYIELD_FROM_ISR(woken)`: every event is handled one tick late (`LATE`), and an event at the last tick is lost.
- Not initialising `woken` to `pdFALSE`. The API only ever sets it to `pdTRUE`, so garbage may force a needless switch.
- Calling `xSemaphoreGive()` (the task version) from the ISR: a Runtime Error here, a hard fault or corrupted lists on real hardware.
- Doing the work (`service_button()`) inside the ISR: long ISRs block other interrupts and the tick.
- Creating the semaphore after the scheduler starts or after enabling the interrupt: an early interrupt then uses a NULL handle.

**Interview follow-ups**
- Why is a direct-to-task notification (`vTaskNotifyGiveFromISR`) faster and smaller than a binary semaphore here, and when can you not use it?
- What is the maximum interrupt priority from which you may call FreeRTOS APIs on a Cortex-M (`configMAX_SYSCALL_INTERRUPT_PRIORITY`)?
- If the handler had a *lower* priority than the busy task, what would `woken` be, and when would the handler run?
- How would you lose events with this design if `service_button()` serviced only one event per call?
