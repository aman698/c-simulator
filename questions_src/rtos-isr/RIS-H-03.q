@@@ meta
id: RIS-H-03
topic: Interrupts & ISRs
difficulty: Hard
type: FUNCTION
title: Centralised Deferred Interrupt Handling in the Timer Daemon
tags: freertos, isr, xtimerpendfunctioncallfromisr, timer-daemon, deferred-interrupt, ring-buffer, coalescing, embedded
@@@ statement_md
A small body controller has no RAM for one handler task per peripheral. Instead, all three interrupt sources (UART RX, GPIO, ADC) defer their work to the **RTOS daemon (timer service) task** with `xTimerPendFunctionCallFromISR()`. That task already exists, runs at priority 7 (the highest here), and executes the pended functions in FIFO order. It has one problem: its command queue holds only **16** entries and is shared with every software timer. A burst of interrupts that pends one call per interrupt could fill it.

So each source buffers its values in a small **ring (4 entries)** and keeps **at most one deferred call outstanding**. That call drains everything that has accumulated, including values that arrive while it runs.

```c
enum { SRC_UART, SRC_GPIO, SRC_ADC, SRC_COUNT };   /* provided */

void on_event(int src, uint32_t value);  /* provided: must run in the daemon task (ADC: A ticks of work) */
void ring_overflow(int src);             /* provided: ISR only: a value was dropped, ring full */
void pend_failed(int src);               /* provided: ISR only: xTimerPendFunctionCallFromISR() failed */

void uart_isr(uint32_t byte);            /* you write: the three ISRs */
void gpio_isr(uint32_t pin);
void adc_isr(uint32_t value);
void app_start(void);                    /* you write: initialise your state (no tasks needed) */
```

Rules (identical for every source; write the logic once):
- **ISR**:
  1. If the source's ring is full, call `ring_overflow(src)` and drop the value. Otherwise append it.
  2. If no deferred call is outstanding for this source, pend one with `xTimerPendFunctionCallFromISR(handler, <source context>, 0, &woken)` and mark it outstanding. If the pend fails, call `pend_failed(src)` and leave it **not** outstanding, so the next interrupt retries.
  3. Finish with `portYIELD_FROM_ISR(woken)`, so the daemon runs at the tick of the interrupt.
- **Deferred handler** `void handler(void *ctx, uint32_t unused)` (runs in the daemon task). Repeat:
  1. Inside a critical section, take the oldest value from the ring. If the ring is empty, clear the "outstanding" flag and stop.
  2. Otherwise, leave the critical section and call `on_event(src, value)`.

  Checking "empty" and clearing the flag in the **same** critical section is what prevents a value that arrives just between them from being stranded.

**How it is tested.** A background task with priority 1 is always busy. The judge wraps `xTimerPendFunctionCallFromISR()` to count calls that are outstanding (pended and not yet returned) and reports the maximum. `on_event()` checks that it runs in the daemon task and that every source's values arrive in order. It prints

```
[t=<now>] UART 0x<byte, 2 hex digits> | GPIO pin <n> | ADC <n>
```

and for ADC values it then computes `A` ticks, so interrupts arrive while the daemon is busy. The run includes tick `D`. Final line:

```
irqs=<n> delivered=<n> overflow=<n> pend_failed=<n> max_outstanding=<n>
```

**Input**
```
D A
N
<tick> <U|G|A> <value>      (N lines, ticks non-decreasing, values in decimal)
```

**Example**
```
Input:
20 2
6
3 U 65
3 A 100
3 U 66
4 G 7
5 A 101
10 G 8

Output:
[t=3] UART 0x41
[t=3] UART 0x42
[t=3] ADC 100
[t=5] ADC 101
[t=7] GPIO pin 7
[t=10] GPIO pin 8
irqs=6 delivered=6 overflow=0 pend_failed=0 max_outstanding=2
```
At t=3 the first UART byte pends the UART handler, and the ADC value pends the ADC handler. The second UART byte only goes into the ring: a UART call is already outstanding. The daemon runs at t=3, drains both UART bytes, then starts on ADC 100 (work during ticks 4-5). The GPIO edge at t=4 pends the GPIO handler behind it. ADC 101 at t=5 only goes into the ring, so the running ADC handler picks it up at t=5 (work until t=7). The GPIO handler runs after it, at t=7.
@@@ constraints_md
- 1 <= D <= 20000, 0 <= A <= 5, 0 <= N <= 1000, 1 <= tick <= D, 0 <= value < 2^31 (UART values < 256).
- Ring size 4 per source, at most one outstanding deferred call per source. Create no tasks: everything deferred runs in the daemon task.
- Only `...FromISR()` APIs inside the ISRs; a blocking call is a Runtime Error.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

/* provided: enum { SRC_UART, SRC_GPIO, SRC_ADC, SRC_COUNT };
 *           void on_event(int src, uint32_t value);
 *           void ring_overflow(int src);
 *           void pend_failed(int src); */

#define RING_SIZE 4

void uart_isr(uint32_t byte)
{
    /* TODO */
    (void)byte;
}

void gpio_isr(uint32_t pin)
{
    /* TODO */
    (void)pin;
}

void adc_isr(uint32_t value)
{
    /* TODO */
    (void)value;
}

void app_start(void)
{
    /* TODO: initialise the per-source state */
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"
#include "sim.h"

enum { SRC_UART, SRC_GPIO, SRC_ADC, SRC_COUNT };

void on_event(int src, uint32_t value);
void ring_overflow(int src);
void pend_failed(int src);
void uart_isr(uint32_t byte);
void gpio_isr(uint32_t pin);
void adc_isr(uint32_t value);
void app_start(void);

#define MAXEV 1000
#define NSLOT 64
typedef struct { int src; uint32_t value; } Ev;

static Ev g_ev[MAXEV];
static uint32_t g_fifo[SRC_COUNT][MAXEV];
static unsigned g_head[SRC_COUNT], g_tail[SRC_COUNT];
static unsigned g_raised, g_delivered, g_overflow, g_pfail, g_errors, g_cost, g_ovf_now;
static int g_cur_src = -1;
static unsigned g_outstanding, g_max_outstanding;

typedef struct { PendedFunction_t fn; void *p1; int used; } Slot;
static Slot g_slot[NSLOT];

static void trampoline(void *p, uint32_t ul)
{
    Slot *s = (Slot *)p;
    PendedFunction_t fn = s->fn;
    void *p1 = s->p1;

    s->used = 0;
    fn(p1, ul);
    g_outstanding--;
}

static BaseType_t h_pend(PendedFunction_t fn, void *p1, uint32_t ul, BaseType_t *woken)
{
    int i;
    BaseType_t r;

    if (!xPortIsInsideInterrupt()) return xTimerPendFunctionCall(fn, p1, ul, 0);
    for (i = 0; i < NSLOT && g_slot[i].used; i++) {}
    if (i == NSLOT || fn == NULL) return pdFAIL;
    g_slot[i].fn = fn;
    g_slot[i].p1 = p1;
    g_slot[i].used = 1;
    r = xTimerPendFunctionCallFromISR(trampoline, &g_slot[i], ul, woken);
    if (r != pdPASS) {
        g_slot[i].used = 0;
        return r;
    }
    if (++g_outstanding > g_max_outstanding) g_max_outstanding = g_outstanding;
    return r;
}

static const char *src_ok(int src)
{
    if (src < 0 || src >= SRC_COUNT) return "unknown source";
    if (!xPortIsInsideInterrupt()) return "must be called from an ISR";
    if (src != g_cur_src) return "called for a different source than the interrupt being handled";
    return NULL;
}

void ring_overflow(int src)
{
    const char *e = src_ok(src);
    if (e) {
        printf("FAIL: ring_overflow(%d): %s\n", src, e);
        g_errors++;
        return;
    }
    g_ovf_now++;
}

void pend_failed(int src)
{
    const char *e = src_ok(src);
    if (e) {
        printf("FAIL: pend_failed(%d): %s\n", src, e);
        g_errors++;
        return;
    }
    g_pfail++;
}

void on_event(int src, uint32_t value)
{
    unsigned now = (unsigned)xTaskGetTickCount();

    if (xPortIsInsideInterrupt() || xTaskGetCurrentTaskHandle() != xTimerGetTimerDaemonTaskHandle()) {
        printf("FAIL: on_event() must run in the timer daemon task (deferred), not in an ISR or another task\n");
        g_errors++;
        return;
    }
    if (src < 0 || src >= SRC_COUNT) {
        printf("FAIL: on_event(%d): unknown source\n", src);
        g_errors++;
        return;
    }
    if (g_head[src] == g_tail[src] || g_fifo[src][g_head[src]] != value) {
        printf("[t=%u] FAIL: on_event(%d, %u): value out of order, duplicated or never accepted\n", now, src,
               (unsigned)value);
        g_errors++;
        return;
    }
    g_head[src]++;
    g_delivered++;
    if (src == SRC_UART) printf("[t=%u] UART 0x%02X\n", now, (unsigned)value);
    else if (src == SRC_GPIO) printf("[t=%u] GPIO pin %u\n", now, (unsigned)value);
    else printf("[t=%u] ADC %u\n", now, (unsigned)value);
    if (src == SRC_ADC && g_cost) vSimBusyWork((TickType_t)g_cost);
}

#define xTimerPendFunctionCallFromISR(f, p1, p2, w) h_pend((f), (p1), (p2), (w))

/*USER_CODE*/

#undef xTimerPendFunctionCallFromISR

static void irq_entry(void *arg)
{
    const Ev *e = (const Ev *)arg;

    g_raised++;
    g_fifo[e->src][g_tail[e->src]++] = e->value;
    g_ovf_now = 0;
    g_cur_src = e->src;
    if (e->src == SRC_UART) uart_isr(e->value);
    else if (e->src == SRC_GPIO) gpio_isr(e->value);
    else adc_isr(e->value);
    g_cur_src = -1;
    if (g_ovf_now > 1) {
        printf("FAIL: ring_overflow() called %u times for one interrupt\n", g_ovf_now);
        g_errors++;
    }
    if (g_ovf_now) {
        g_tail[e->src]--;
        g_overflow++;
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
    char c;

    if (scanf("%u %u %u", &d, &g_cost, &n) != 3 || n > MAXEV) return 1;
    app_start();
    xTaskCreate(background_task, "bg", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    for (i = 0; i < n; i++) {
        if (scanf("%u %c %u", &t, &c, &v) != 3) return 1;
        g_ev[i].src = c == 'U' ? SRC_UART : c == 'G' ? SRC_GPIO : SRC_ADC;
        g_ev[i].value = (uint32_t)v;
        xSimScheduleInterrupt((TickType_t)t, irq_entry, &g_ev[i]);
    }
    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();
    printf("irqs=%u delivered=%u overflow=%u pend_failed=%u max_outstanding=%u\n", g_raised, g_delivered, g_overflow,
           g_pfail, g_max_outstanding);
    if (g_errors) printf("ERRORS: %u\n", g_errors);
    return 0;
}
@@@ sample_input
20 2
6
3 U 65
3 A 100
3 U 66
4 G 7
5 A 101
10 G 8
@@@ sample_output
[t=3] UART 0x41
[t=3] UART 0x42
[t=3] ADC 100
[t=5] ADC 101
[t=7] GPIO pin 7
[t=10] GPIO pin 8
irqs=6 delivered=6 overflow=0 pend_failed=0 max_outstanding=2
@@@ sample_input
10 1
9
2 U 49
2 U 50
2 U 51
2 U 52
2 U 53
2 U 54
2 A 7
2 A 8
10 G 1
@@@ sample_output
[t=2] UART 0x31
[t=2] UART 0x32
[t=2] UART 0x33
[t=2] UART 0x34
[t=2] ADC 7
[t=3] ADC 8
[t=10] GPIO pin 1
irqs=9 delivered=7 overflow=2 pend_failed=0 max_outstanding=2
@@@ hidden_input
30 3
0
@@@ hidden_output
irqs=0 delivered=0 overflow=0 pend_failed=0 max_outstanding=0
@@@ hidden_input
40 0
24
1 G 0
1 G 1
1 G 2
1 G 3
1 G 4
1 G 5
1 G 6
1 G 7
1 U 0
1 U 255
1 U 16
1 U 17
1 U 18
1 A 0
1 A 2147483647
1 A 5
1 A 6
1 A 7
1 A 8
1 A 9
2 G 9
2 U 1
40 A 40
40 U 40
@@@ hidden_output
[t=1] GPIO pin 0
[t=1] GPIO pin 1
[t=1] GPIO pin 2
[t=1] GPIO pin 3
[t=1] UART 0x00
[t=1] UART 0xFF
[t=1] UART 0x10
[t=1] UART 0x11
[t=1] ADC 0
[t=1] ADC 2147483647
[t=1] ADC 5
[t=1] ADC 6
[t=2] GPIO pin 9
[t=2] UART 0x01
[t=40] ADC 40
[t=40] UART 0x28
irqs=24 delivered=16 overflow=8 pend_failed=0 max_outstanding=3

@@@ hidden_input
40 3
12
5 A 1
6 A 2
7 A 3
8 A 4
8 U 200
9 A 5
9 G 3
10 A 6
11 A 7
12 A 8
13 A 9
14 A 10
@@@ hidden_output
[t=5] ADC 1
[t=8] ADC 2
[t=11] ADC 3
[t=14] ADC 4
[t=17] ADC 5
[t=20] ADC 6
[t=23] ADC 8
[t=26] UART 0xC8
[t=26] GPIO pin 3
irqs=12 delivered=9 overflow=3 pend_failed=0 max_outstanding=3

@@@ hidden_input
20000 5
10
1 A 11
1 A 12
2 U 1
3 U 2
4 U 3
5 U 4
6 U 5
7 U 6
19999 G 4
20000 G 5
@@@ hidden_output
[t=1] ADC 11
[t=6] ADC 12
[t=11] UART 0x01
[t=11] UART 0x02
[t=11] UART 0x03
[t=11] UART 0x04
[t=19999] GPIO pin 4
[t=20000] GPIO pin 5
irqs=10 delivered=8 overflow=2 pend_failed=0 max_outstanding=2

@@@ hidden_input
25 2
8
3 G 1
3 U 65
3 A 1000
4 A 1001
5 A 1002
6 U 66
6 G 2
25 G 3
@@@ hidden_output
[t=3] GPIO pin 1
[t=3] UART 0x41
[t=3] ADC 1000
[t=5] ADC 1001
[t=7] ADC 1002
[t=9] UART 0x42
[t=9] GPIO pin 2
[t=25] GPIO pin 3
irqs=8 delivered=8 overflow=0 pend_failed=0 max_outstanding=3

@@@ hint
Make one descriptor per source, `typedef struct { int src; volatile uint32_t buf[RING_SIZE]; volatile uint8_t head, count; volatile uint8_t outstanding; } Source;`, and pass `&s_src[i]` as `pvParameter1` of `xTimerPendFunctionCallFromISR()`. One generic handler then serves all sources, and the three ISRs just call a common `defer(&s_src[SRC_x], value)`.
@@@ hint
Handler loop: `for (;;) { taskENTER_CRITICAL(); if (s->count == 0) { s->outstanding = 0; taskEXIT_CRITICAL(); return; } v = s->buf[s->head]; s->head = (s->head + 1) % RING_SIZE; s->count--; taskEXIT_CRITICAL(); on_event(s->src, v); }`. In the ISR: append if `count < RING_SIZE`, then `if (!s->outstanding) { if (xTimerPendFunctionCallFromISR(handler, s, 0, &woken) == pdPASS) s->outstanding = 1; else pend_failed(s->src); }`.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

/* provided: enum { SRC_UART, SRC_GPIO, SRC_ADC, SRC_COUNT };
 *           void on_event(int src, uint32_t value);
 *           void ring_overflow(int src);
 *           void pend_failed(int src); */

#define RING_SIZE 4

typedef struct {
    int src;
    volatile uint32_t buf[RING_SIZE];
    volatile uint8_t head;          /* oldest value */
    volatile uint8_t count;         /* values waiting */
    volatile uint8_t outstanding;   /* 1 while a deferred call is queued or running */
} Source;

static Source s_src[SRC_COUNT];

/* Runs in the timer daemon task: may use task APIs, must not block for long. */
static void deferred_handler(void *pvParameter1, uint32_t ulParameter2)
{
    Source *s = (Source *)pvParameter1;
    uint32_t v;

    (void)ulParameter2;
    for (;;) {
        taskENTER_CRITICAL();
        if (s->count == 0) {
            s->outstanding = 0;     /* atomically with the empty check */
            taskEXIT_CRITICAL();
            return;
        }
        v = s->buf[s->head];
        s->head = (uint8_t)((s->head + 1u) % RING_SIZE);
        s->count--;
        taskEXIT_CRITICAL();
        on_event(s->src, v);        /* may take time: interrupts stay enabled */
    }
}

static void defer_from_isr(Source *s, uint32_t value)
{
    BaseType_t woken = pdFALSE;

    if (s->count == RING_SIZE) {
        ring_overflow(s->src);
    } else {
        s->buf[(s->head + s->count) % RING_SIZE] = value;
        s->count++;
    }
    if (!s->outstanding) {          /* coalesce: one call drains everything */
        if (xTimerPendFunctionCallFromISR(deferred_handler, s, 0, &woken) == pdPASS) {
            s->outstanding = 1;
        } else {
            pend_failed(s->src);    /* daemon queue full: the next interrupt retries */
        }
    }
    portYIELD_FROM_ISR(woken);      /* the daemon (priority 7) runs at this tick */
}

void uart_isr(uint32_t byte) { defer_from_isr(&s_src[SRC_UART], byte); }
void gpio_isr(uint32_t pin)  { defer_from_isr(&s_src[SRC_GPIO], pin); }
void adc_isr(uint32_t value) { defer_from_isr(&s_src[SRC_ADC], value); }

void app_start(void)
{
    int i;

    for (i = 0; i < SRC_COUNT; i++) {
        s_src[i].src = i;
        s_src[i].head = 0;
        s_src[i].count = 0;
        s_src[i].outstanding = 0;
    }
}
@@@ explanation_md
**Approach.** `xTimerPendFunctionCallFromISR(fn, p1, ul, &woken)` posts a "call `fn(p1, ul)`" command into the timer daemon's queue. The daemon runs it in task context at `configTIMER_TASK_PRIORITY` (7 here), so `portYIELD_FROM_ISR(woken)` gets it running at the same tick. One existing task now replaces a task per peripheral: centralised deferred interrupt handling. The cost is that everything shares one FIFO and one priority, so one slow handler (ADC) delays the others (the GPIO edge at t=4 waits until t=7 in the example).

The daemon's queue is small (`configTIMER_QUEUE_LENGTH` = 16) and shared with timer commands. Pending one call **per interrupt** lets a burst of 20 interrupts fill it, which loses events and also makes `xTimerStart()` calls elsewhere fail. **Coalescing** bounds the daemon traffic to one entry per source: the ISR buffers values in a per-source ring, and pends only when no call is outstanding. The handler drains until the ring is empty, including values that arrive while it is running.

The delicate part is the hand-over: "ring is empty" and "no call outstanding" must change together, inside one critical section. Otherwise an interrupt between them adds a value, sees `outstanding == 1`, and does not pend, while the handler is about to exit. That value would be stranded until the next interrupt of that source. `pvParameter1` carries the source descriptor, so a single handler and a single ISR helper serve all sources.

**Complexity.** ISR: O(1). Handler: O(k) for k queued values, plus their work. Daemon queue usage: at most `SRC_COUNT` entries, independent of the burst size. RAM: 3 x (16 + 4) bytes. No extra task stacks: this is the RAM argument for the pattern. Worst-case latency of a source = the sum of the work of the handlers queued before it.

**Common mistakes**
- One pend per interrupt: the daemon queue overflows on bursts (watch `max_outstanding`), and timers stop working.
- Clearing `outstanding` *before* draining, or outside the critical section that checked "empty": stranded values or duplicate calls.
- Setting `outstanding = 1` even when the pend failed: that source is then dead forever.
- Blocking in the deferred function (`vTaskDelay`, `xQueueReceive(..., portMAX_DELAY)`): that stalls every software timer in the system.
- Using `xTimerPendFunctionCall()` (task version) from the ISR, or forgetting the yield, so the daemon starts one tick late.

**Interview follow-ups**
- Compare this with one handler task per peripheral: RAM, latency, priority control. When is the daemon the wrong place?
- What happens to software timer accuracy while the ADC handler computes in the daemon task?
- How would you give the GPIO source priority over ADC within this single-task design?
- Why does `configTIMER_TASK_PRIORITY` usually have to be the highest application priority for this pattern?
