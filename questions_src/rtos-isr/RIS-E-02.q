@@@ meta
id: RIS-E-02
topic: Interrupts & ISRs
difficulty: Easy
type: FUNCTION
title: ADC Conversion ISR Feeding a Queue
tags: freertos, isr, queue, xqueuesendfromisr, adc, overrun, embedded
@@@ statement_md
An ADC raises an interrupt each time a conversion completes. The ISR must hand the 16-bit result to a processing task through a **FreeRTOS queue**, without blocking and without losing track of samples it had to drop.

```c
void consume_sample(uint16_t sample);  /* provided: processes one sample (task context; takes C ticks of CPU) */
void adc_overrun(void);                /* provided: call it from the ISR for every sample you drop */

void adc_isr(uint16_t sample);         /* you write: the conversion-complete ISR */
void app_start(void);                  /* you write: create the queue and the consumer task */
```

Rules:
- `app_start()` runs before the scheduler. It creates a queue of **8 items of `uint16_t`** and one consumer task with **priority 3**.
- The consumer loops forever: `xQueueReceive(..., portMAX_DELAY)`, then `consume_sample(sample)`.
- `adc_isr()` sends the sample with `xQueueSendFromISR()`. If the queue is full, the sample is dropped: call `adc_overrun()` (never block or retry in an ISR). End the ISR with `portYIELD_FROM_ISR()`, so an idle consumer runs at the tick of the interrupt.

**How it is tested.** A background task with priority 1 is always busy. Each conversion interrupt fires at its given tick. `consume_sample()` prints

```
[t=<now>] sample <value> (irq t=<tick of its interrupt>)
```

and then computes for `C` ticks (`vSimBusyWork(C)`), during which new interrupts keep arriving. The harness checks that samples are consumed **in arrival order** and that every sample is either consumed, still queued at the end, or reported with `adc_overrun()`. The run includes tick `D` (an interrupt at tick `D` is consumed at tick `D` if the consumer is idle). The final line is

```
samples=<n> consumed=<n> dropped=<n> queued=<n>
```

**Input**
```
D C
N
<tick> <value>      (N lines, ticks non-decreasing)
```
Interrupts listed at the same tick run back to back, in input order, before any task runs.

**Example**
```
Input:
30 2
4
5 100
6 101
6 102
20 103

Output:
[t=5] sample 100 (irq t=5)
[t=7] sample 101 (irq t=6)
[t=9] sample 102 (irq t=6)
[t=20] sample 103 (irq t=20)
samples=4 consumed=4 dropped=0 queued=0
```
At t=5 the ISR wakes the blocked consumer and yields, so it runs at once. It computes during ticks 6 and 7. The two samples of t=6 wait in the queue meanwhile, and are consumed at t=7 and t=9.
@@@ constraints_md
- 1 <= D <= 20000, 0 <= C <= 5, 0 <= N <= 300, 1 <= tick <= D, 0 <= value <= 65535.
- Queue: length 8, item `uint16_t`. Consumer priority 3, exactly one consumer task.
- Only `...FromISR()` APIs inside `adc_isr()`; a blocking call there is a Runtime Error.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

void consume_sample(uint16_t sample);   /* provided */
void adc_overrun(void);                 /* provided */

#define ADC_QUEUE_LEN 8

static QueueHandle_t s_adc_q;

static void consumer_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: receive one sample (block forever), then consume_sample(it) */
        vTaskDelay(1000);
    }
}

void adc_isr(uint16_t sample)
{
    /* TODO: send to the queue from the ISR, report drops, yield if needed */
    (void)sample;
}

void app_start(void)
{
    /* TODO: create the queue and the consumer task (priority 3) */
    (void)s_adc_q;
    (void)consumer_task;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

void adc_isr(uint16_t sample);
void app_start(void);
void consume_sample(uint16_t sample);
void adc_overrun(void);

#define MAXEV 300
typedef struct { TickType_t tick; uint16_t value; } AdcEv;

static AdcEv g_ev[MAXEV];
static AdcEv g_fifo[MAXEV];          /* samples accepted by the ISR, in order */
static unsigned g_head, g_tail;
static unsigned g_raised, g_consumed, g_dropped, g_errors;
static unsigned g_cost;
static int g_in_isr, g_overrun_now;

void adc_overrun(void)
{
    if (!g_in_isr) {
        printf("FAIL: adc_overrun() must be called from the ISR\n");
        g_errors++;
        return;
    }
    g_overrun_now++;
}

void consume_sample(uint16_t sample)
{
    unsigned now = (unsigned)xTaskGetTickCount();

    if (g_in_isr) {
        printf("FAIL: consume_sample() called from the ISR\n");
        g_errors++;
        return;
    }
    if (g_head == g_tail) {
        printf("[t=%u] sample %u ERROR: no such sample was queued\n", now, (unsigned)sample);
        g_errors++;
    } else {
        AdcEv e = g_fifo[g_head++];
        if (e.value != sample) {
            printf("[t=%u] sample %u ERROR: expected %u (wrong order or corrupted)\n", now, (unsigned)sample, (unsigned)e.value);
            g_errors++;
        } else {
            printf("[t=%u] sample %u (irq t=%u)\n", now, (unsigned)sample, (unsigned)e.tick);
        }
    }
    g_consumed++;
    if (g_cost) vSimBusyWork((TickType_t)g_cost);
}

/*USER_CODE*/

static void irq_entry(void *arg)
{
    AdcEv *e = (AdcEv *)arg;

    g_raised++;
    g_fifo[g_tail++] = *e;
    g_overrun_now = 0;
    g_in_isr = 1;
    adc_isr(e->value);
    g_in_isr = 0;
    if (g_overrun_now > 1) {
        printf("FAIL: adc_overrun() called %d times for one sample\n", g_overrun_now);
        g_errors++;
    }
    if (g_overrun_now) {        /* dropped: it will never be consumed */
        g_tail--;
        g_dropped++;
    }
}

static void background_task(void *p)
{
    (void)p;
    for (;;) vSimBusyWork(1);
}

int main(void)
{
    unsigned d, n, i, t, v;

    if (scanf("%u %u %u", &d, &g_cost, &n) != 3 || n > MAXEV) return 1;
    app_start();
    xTaskCreate(background_task, "bg", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    for (i = 0; i < n; i++) {
        if (scanf("%u %u", &t, &v) != 2) return 1;
        g_ev[i].tick = (TickType_t)t;
        g_ev[i].value = (uint16_t)v;
        xSimScheduleInterrupt((TickType_t)t, irq_entry, &g_ev[i]);
    }
    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();
    printf("samples=%u consumed=%u dropped=%u queued=%u\n", g_raised, g_consumed, g_dropped, g_tail - g_head);
    if (g_errors) printf("ERRORS: %u\n", g_errors);
    return 0;
}
@@@ sample_input
30 2
4
5 100
6 101
6 102
20 103
@@@ sample_output
[t=5] sample 100 (irq t=5)
[t=7] sample 101 (irq t=6)
[t=9] sample 102 (irq t=6)
[t=20] sample 103 (irq t=20)
samples=4 consumed=4 dropped=0 queued=0
@@@ sample_input
12 1
10
3 1
3 2
3 3
3 4
3 5
3 6
3 7
3 8
3 9
3 10
@@@ sample_output
[t=3] sample 1 (irq t=3)
[t=4] sample 2 (irq t=3)
[t=5] sample 3 (irq t=3)
[t=6] sample 4 (irq t=3)
[t=7] sample 5 (irq t=3)
[t=8] sample 6 (irq t=3)
[t=9] sample 7 (irq t=3)
[t=10] sample 8 (irq t=3)
samples=10 consumed=8 dropped=2 queued=0
@@@ hidden_input
40 3
0
@@@ hidden_output
samples=0 consumed=0 dropped=0 queued=0
@@@ hidden_input
15 0
5
1 0
1 65535
7 7
15 4095
15 4094
@@@ hidden_output
[t=1] sample 0 (irq t=1)
[t=1] sample 65535 (irq t=1)
[t=7] sample 7 (irq t=7)
[t=15] sample 4095 (irq t=15)
[t=15] sample 4094 (irq t=15)
samples=5 consumed=5 dropped=0 queued=0
@@@ hidden_input
20 5
12
2 11
3 12
4 13
5 14
6 15
7 16
8 17
9 18
10 19
11 20
12 21
13 22
@@@ hidden_output
[t=2] sample 11 (irq t=2)
[t=7] sample 12 (irq t=3)
[t=12] sample 13 (irq t=4)
[t=17] sample 14 (irq t=5)
samples=12 consumed=4 dropped=1 queued=7

@@@ hidden_input
25 4
3
25 500
25 501
25 502
@@@ hidden_output
[t=25] sample 500 (irq t=25)
samples=3 consumed=1 dropped=0 queued=2

@@@ hidden_input
200 2
14
10 1
10 2
10 3
10 4
10 5
10 6
10 7
10 8
10 9
11 10
12 11
13 12
14 13
100 99
@@@ hidden_output
[t=10] sample 1 (irq t=10)
[t=12] sample 2 (irq t=10)
[t=14] sample 3 (irq t=10)
[t=16] sample 4 (irq t=10)
[t=18] sample 5 (irq t=10)
[t=20] sample 6 (irq t=10)
[t=22] sample 7 (irq t=10)
[t=24] sample 8 (irq t=10)
[t=26] sample 10 (irq t=11)
[t=28] sample 12 (irq t=13)
[t=100] sample 99 (irq t=100)
samples=14 consumed=11 dropped=3 queued=0

@@@ hint
Inside the ISR: `BaseType_t woken = pdFALSE; if (xQueueSendFromISR(q, &sample, &woken) != pdPASS) adc_overrun(); portYIELD_FROM_ISR(woken);`. The queue copies the 2 bytes, so passing the address of the parameter is fine.
@@@ hint
`xQueueSendFromISR()` never blocks: on a full queue it returns `errQUEUE_FULL` at once. Create the queue with `xQueueCreate(8, sizeof(uint16_t))`; the consumer receives into a local `uint16_t`.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

void consume_sample(uint16_t sample);   /* provided */
void adc_overrun(void);                 /* provided */

#define ADC_QUEUE_LEN 8

static QueueHandle_t s_adc_q;

static void consumer_task(void *pvParameters)
{
    uint16_t sample;

    (void)pvParameters;
    for (;;) {
        if (xQueueReceive(s_adc_q, &sample, portMAX_DELAY) == pdPASS) {
            consume_sample(sample);
        }
    }
}

void adc_isr(uint16_t sample)
{
    BaseType_t woken = pdFALSE;

    /* copy by value into the queue storage; never blocks */
    if (xQueueSendFromISR(s_adc_q, &sample, &woken) != pdPASS) {
        adc_overrun();                  /* queue full: drop and count, do not wait */
    }
    portYIELD_FROM_ISR(woken);          /* wake the consumer at this tick */
}

void app_start(void)
{
    s_adc_q = xQueueCreate(ADC_QUEUE_LEN, sizeof(uint16_t));
    configASSERT(s_adc_q != NULL);
    xTaskCreate(consumer_task, "adc", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
}
@@@ explanation_md
**Approach.** The queue decouples the interrupt rate from the processing rate. The ISR copies the sample into the queue with `xQueueSendFromISR()`. That call never blocks: on a full queue it returns `errQUEUE_FULL`, and the only correct reaction in an ISR is to drop the sample and count it (`adc_overrun()`). The consumer blocks in `xQueueReceive(..., portMAX_DELAY)`, so it costs no CPU while there is nothing to do.

When the consumer is blocked, the first send unblocks it and sets `woken = pdTRUE` (priority 3 > the interrupted priority-1 task). `portYIELD_FROM_ISR(woken)` makes it run at the same tick. When the consumer is busy in `consume_sample()`, new samples just pile up in the queue. That is why, in the second sample, a burst of 10 conversions at t=3 fills the 8 slots (all 10 ISRs run before any task) and the last two samples are dropped.

**Complexity.** ISR: O(1), one 2-byte copy plus list operations. Consumer: O(1) per sample plus `C` ticks of processing. RAM: 8 x 2 bytes of queue storage plus the queue control block (~80 bytes) and one task stack. Sizing rule: queue length >= the largest burst minus what the consumer can drain meanwhile.

**Common mistakes**
- `xQueueSend()` (task version) in the ISR: it may try to block, which is a Runtime Error here and a crash on real hardware.
- Ignoring the return value: the sample silently disappears and nobody knows the data stream has gaps.
- Retrying in a loop inside the ISR until the queue has space: the consumer can never run while the ISR spins, so this is a deadlock.
- Passing a pointer to a buffer instead of the value with `sizeof(uint16_t *)` items: the ISR overwrites the buffer before the task reads it.
- Forgetting `portYIELD_FROM_ISR()`: an idle consumer starts one tick late.

**Interview follow-ups**
- At 10 kHz sampling, would you still use one queue item per sample? Compare with DMA plus double buffering (RIS-H-01) or a stream buffer.
- How do you choose the queue length from the worst-case consumer blocking time?
- Should the ISR drop the newest or the oldest sample when the queue is full? How would you implement "keep the newest"?
- What does `xQueueOverwriteFromISR()` do, and when is a length-1 "mailbox" queue the right choice?
