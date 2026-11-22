@@@ meta
id: REV-E-01
topic: Event Groups & Notifications
difficulty: Easy
type: FUNCTION
title: UART RX Interrupt Signals a Task Through a Binary Notification
tags: freertos, task-notifications, ultasknotifytake, isr-deferral, binary-semaphore, embedded
@@@ statement_md
A body-control ECU receives LIN frames on a UART with a 16-byte hardware FIFO. The UART raises an **RX interrupt** whenever new bytes arrive. Your job: defer the work to a task, using a **direct-to-task notification as a lightweight binary semaphore** (no semaphore object, no queue).

```c
void drain_rx_fifo(void);              /* provided: prints "[t=<tick>] drain #<n>" and takes
                                          `work` ticks of CPU time (it empties the whole FIFO) */

void app_start(UBaseType_t priority);  /* you write: create the RX task */
void uart_rx_isr(void);                /* you write: called in INTERRUPT context */
```

- `app_start()` runs before the scheduler starts. It creates **one** task with the given priority.
- The task loops forever: block until the ISR has signalled, then call `drain_rx_fifo()` **once**.
- `uart_rx_isr()` signals the task with `vTaskNotifyGiveFromISR()` and requests a context switch with `portYIELD_FROM_ISR()`, so the task runs **at the same tick** as the interrupt.
- One drain empties the whole FIFO. So if several interrupts arrive while the task is draining (or at the same tick), they need **exactly one** more drain, not one drain per interrupt. That is binary-semaphore behaviour: take the notification with `ulTaskNotifyTake(pdTRUE, ...)` (clear the count on exit).

Queues, semaphores and event groups are disabled in this exercise (using them is a compile error).

**How it is tested.** The hidden `main()` reads the scenario, calls `app_start()`, schedules one simulated interrupt (which calls `uart_rx_isr()`) per listed tick and runs the scheduler up to and including tick `D`. Simulated time only moves while every task is blocked or inside `drain_rx_fifo()`. The harness then prints the number of interrupts and drains and a verdict:
- `UNSERVED IRQ at t=<tick>`: an interrupt was never followed by a drain;
- `SPURIOUS drain at t=<tick>`: a drain ran although no interrupt had arrived since the previous drain started;
- `OK` otherwise.

**Input**
```
<priority> <work> <D>
<n>
<t1> <t2> ... <tn>      (interrupt ticks, non-decreasing; the line is absent when n = 0)
```

**Example**
```
Input:
2 5 30
4
3 5 6 20

Output:
[t=3] drain #1
[t=8] drain #2
[t=20] drain #3
interrupts=4 drains=3
OK
```
The interrupt at t=3 wakes the task and, thanks to `portYIELD_FROM_ISR`, it drains at t=3. That drain takes 5 ticks (t=3..8). The interrupts at t=5 and t=6 arrive meanwhile: the notification count becomes 2, and `ulTaskNotifyTake(pdTRUE, ...)` at t=8 returns at once and resets it to 0, so there is **one** drain at t=8. A counting take (`pdFALSE`) would drain once more at t=13 with an empty FIFO (`SPURIOUS drain`).
@@@ constraints_md
- 1 <= priority <= 6, 1 <= work <= 50, 1 <= D <= 5000, 0 <= n <= 100, 1 <= ti < D - work.
- Exactly one task, stack `configMINIMAL_STACK_SIZE`. It must block (no polling loop).
- Use task notifications only. Queues, semaphores and event groups do not compile here.
- 1 tick = 1 ms. Code between two blocking calls takes zero ticks.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"

void drain_rx_fifo(void);

static TaskHandle_t rx_task_handle;

static void rx_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: block until uart_rx_isr() signals, then drain once */
        vTaskDelay(1000);
    }
}

void app_start(UBaseType_t priority)
{
    /* TODO: create rx_task and remember its handle */
    (void)priority;
    (void)rx_task;
    (void)rx_task_handle;
}

void uart_rx_isr(void)
{
    /* TODO: notify rx_task from interrupt context and yield if needed */
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "event_groups.h"
#include "sim.h"

static TickType_t g_work;
static unsigned g_irqs, g_drains;
static int g_pending;              /* an interrupt arrived since the last drain started */
static TickType_t g_pending_tick;
static int g_bad;

void drain_rx_fifo(void)
{
    TickType_t now = xTaskGetTickCount();

    g_drains++;
    printf("[t=%u] drain #%u\n", (unsigned)now, g_drains);
    if (!g_pending) {
        printf("SPURIOUS drain at t=%u\n", (unsigned)now);
        g_bad = 1;
    }
    g_pending = 0;
    vSimBusyWork(g_work);
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

static void irq(void *arg)
{
    (void)arg;
    g_irqs++;
    if (!g_pending) g_pending_tick = xTaskGetTickCountFromISR();
    g_pending = 1;
    uart_rx_isr();
}

int main(void)
{
    unsigned prio, work, dur, n, i, t;

    if (scanf("%u %u %u", &prio, &work, &dur) != 3) return 1;
    if (scanf("%u", &n) != 1) return 1;
    g_work = (TickType_t)work;
    for (i = 0; i < n; i++) {
        if (scanf("%u", &t) != 1) return 1;
        xSimScheduleInterrupt((TickType_t)t, irq, NULL);
    }

    app_start((UBaseType_t)prio);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("interrupts=%u drains=%u\n", g_irqs, g_drains);
    if (g_pending) {
        printf("UNSERVED IRQ at t=%u\n", (unsigned)g_pending_tick);
        g_bad = 1;
    }
    if (!g_bad) printf("OK\n");
    return 0;
}
@@@ sample_input
2 5 30
4
3 5 6 20
@@@ sample_output
[t=3] drain #1
[t=8] drain #2
[t=20] drain #3
interrupts=4 drains=3
OK
@@@ sample_input
4 2 12
4
1 1 2 3
@@@ sample_output
[t=1] drain #1
[t=3] drain #2
interrupts=4 drains=2
OK
@@@ hidden_input
3 4 50
0
@@@ hidden_output
interrupts=0 drains=0
OK
@@@ hidden_input
1 1 10
1
1
@@@ hidden_output
[t=1] drain #1
interrupts=1 drains=1
OK
@@@ hidden_input
2 10 100
6
5 6 7 8 9 50
@@@ hidden_output
[t=5] drain #1
[t=15] drain #2
[t=50] drain #3
interrupts=6 drains=3
OK
@@@ hidden_input
5 3 40
4
10 13 16 30
@@@ hidden_output
[t=10] drain #1
[t=13] drain #2
[t=16] drain #3
[t=30] drain #4
interrupts=4 drains=4
OK
@@@ hidden_input
6 2 200
5
100 102 104 150 151
@@@ hidden_output
[t=100] drain #1
[t=102] drain #2
[t=104] drain #3
[t=150] drain #4
[t=152] drain #5
interrupts=5 drains=5
OK
@@@ hidden_input
3 7 300
8
20 20 20 21 40 41 42 200
@@@ hidden_output
[t=20] drain #1
[t=27] drain #2
[t=40] drain #3
[t=47] drain #4
[t=200] drain #5
interrupts=8 drains=5
OK
@@@ hint
The RX task needs its own `TaskHandle_t` (last argument of `xTaskCreate`) so the ISR knows whom to notify. In the ISR: `BaseType_t woken = pdFALSE; vTaskNotifyGiveFromISR(handle, &woken); portYIELD_FROM_ISR(woken);`.
@@@ hint
In the task: `for (;;) { ulTaskNotifyTake(pdTRUE, portMAX_DELAY); drain_rx_fifo(); }`. `pdTRUE` resets the notification value to 0 when it returns, so any number of pending "gives" collapse into a single drain (binary semaphore). `pdFALSE` would decrement by one (counting semaphore).
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"

void drain_rx_fifo(void);

static TaskHandle_t rx_task_handle;

static void rx_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* pdTRUE: clear the count on exit -> binary semaphore semantics */
        (void)ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        drain_rx_fifo();               /* empties the whole FIFO */
    }
}

void app_start(UBaseType_t priority)
{
    xTaskCreate(rx_task, "rx", configMINIMAL_STACK_SIZE, NULL, priority, &rx_task_handle);
}

void uart_rx_isr(void)
{
    BaseType_t woken = pdFALSE;

    vTaskNotifyGiveFromISR(rx_task_handle, &woken);
    portYIELD_FROM_ISR(woken);         /* run the RX task at this tick, not the next one */
}
@@@ explanation_md
**Approach.** Each task has a built-in 32-bit notification value. `vTaskNotifyGiveFromISR()` increments it and unblocks the task if it is waiting. `ulTaskNotifyTake(xClearCountOnExit, timeout)` blocks while the value is 0. When it returns, it either resets the value to 0 (`pdTRUE`) or decrements it (`pdFALSE`).

Because one `drain_rx_fifo()` empties the whole FIFO, the right semantics are those of a **binary** semaphore: "at least one interrupt happened since I last looked". So use `pdTRUE`. In the example, the interrupts at t=5 and t=6 arrive while the task is draining (the count goes to 2). The take at t=8 returns immediately and resets the count, so one drain covers both.

`portYIELD_FROM_ISR(woken)` matters: the ISR runs while the idle task (or a lower-priority task) is current. Without the yield request, the RX task only gets the CPU at the next tick interrupt, one tick late.

**Complexity.** O(1) per interrupt and per drain. RAM: no kernel object at all (the notification lives in the TCB), versus about 80 bytes for a semaphore. Notifications are also faster than a semaphore give/take. Worst-case latency from IRQ to drain start = remaining time of the current drain (at most `work` ticks) when the task is already busy, 0 ticks otherwise.

**Common mistakes**
- `ulTaskNotifyTake(pdFALSE, ...)`: counting semantics, one useless extra drain per coalesced interrupt (`SPURIOUS drain`).
- Forgetting `portYIELD_FROM_ISR(woken)`: the drain starts one tick late.
- Calling `xTaskNotifyGive()` (task version) from the ISR: a task-only API in interrupt context is a Runtime Error (and undefined behaviour on a real port).
- Notifying through a handle that was never stored (`NULL` handle): passing NULL to the FromISR API is an assert.
- Polling a volatile flag instead of blocking: wastes the CPU and starves lower-priority tasks.

**Interview follow-ups**
- When can you *not* replace a semaphore with a task notification? (Several receiving tasks; the ISR must not know the task handle; the sender must block when "full".)
- What changes if two different ISRs must wake the same task for two different reasons? (`eSetBits`, or indexed notifications.)
- How would you add a timeout to detect a dead UART (`ulTaskNotifyTake(pdTRUE, pdMS_TO_TICKS(100))` returns 0)?
- Why is `woken` initialised to `pdFALSE` and only ever set by the kernel?
