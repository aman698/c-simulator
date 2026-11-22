@@@ meta
id: RIS-H-02
topic: Interrupts & ISRs
difficulty: Hard
type: FUNCTION
title: CAN RX ISR With Acceptance Filter and Two-Class Overflow Policy
tags: freertos, isr, can, acceptance-filter, xqueuereceivefromisr, overflow-policy, embedded, asked-in-automotive
@@@ statement_md
A gateway ECU receives classic CAN frames (11-bit IDs). The RX interrupt must:
1. apply the **acceptance filter** in software;
2. sort accepted frames into two classes. IDs below `0x100` are **safety frames** (brake, steering) and go to a high-priority task. All other accepted frames go to a low-priority task;
3. never block, and handle full queues with a **different policy per class**.

```c
typedef struct { uint16_t id; uint8_t dlc; uint8_t data[8]; } CanFrame;   /* provided */
enum { CAN_FILTERED, CAN_HI_REPLACED, CAN_LO_DROPPED };                  /* provided */

void can_stat(int what);              /* provided: ISR only, counts one event of that kind */
void handle_high(const CanFrame *f);  /* provided: task context, 1 tick of work */
void handle_low(const CanFrame *f);   /* provided: task context, L ticks of work */

void can_rx_isr(const CanFrame *f);   /* you write */
void app_start(uint16_t code, uint16_t mask);   /* you write */
```

Rules:
- `app_start(code, mask)` stores the filter and creates:
  - a **high queue** of 4 `CanFrame` and a high task with **priority 5** that calls `handle_high()`;
  - a **low queue** of 8 `CanFrame` and a low task with **priority 2** that calls `handle_low()`.
- `can_rx_isr(f)`. `f` points to the controller's RX mailbox, which is **reused for the next frame** as soon as the ISR returns, so copy the frame by value.
  - If `(f->id & mask) != (code & mask)`: `can_stat(CAN_FILTERED)` and ignore the frame.
  - Safety frame (`id < 0x100`): if the high queue is full, **discard the oldest** queued safety frame (`xQueueReceiveFromISR()`), call `can_stat(CAN_HI_REPLACED)`, then queue the new one. The newest brake command always wins.
  - Other frame: if the low queue is full, **drop the new frame** and call `can_stat(CAN_LO_DROPPED)`.
  - Use **one** `BaseType_t woken` for all FromISR calls, and call `portYIELD_FROM_ISR(woken)` once at the end.

**How it is tested.** A background task with priority 1 is always busy. Each input frame is one RX interrupt at its tick (frames of the same tick run back to back, before any task). The handlers print

```
[t=<now>] HI id=0x<id> data=<bytes in hex, or - if dlc is 0>
[t=<now>] LO id=0x<id> data=<...>
```

and verify that they run in a task of the right priority. Then they work for 1 tick (high) or `L` ticks (low). A safety frame preempts the low task in the middle of its work. The run includes tick `D`. Finally:

```
frames=<n> high=<handled> low=<handled> filtered=<n> hi_replaced=<n> lo_dropped=<n> pending=<the rest>
```

**Input**
```
D L code mask        (code and mask in hex)
N
<tick> <id hex> <dlc> <data hex, or - when dlc = 0>     (N lines, ticks non-decreasing)
```

**Example**
```
Input:
30 3 000 000
5
2 0A0 2 1122
2 300 1 AA
3 301 1 BB
4 050 0 -
10 7FF 8 0102030405060708

Output:
[t=2] HI id=0x0A0 data=1122
[t=3] LO id=0x300 data=AA
[t=4] HI id=0x050 data=-
[t=7] LO id=0x301 data=BB
[t=10] LO id=0x7FF data=0102030405060708
frames=5 high=2 low=3 filtered=0 hi_replaced=0 lo_dropped=0 pending=0
```
Mask 0 accepts everything. At t=2 both tasks are woken; the high task runs first, works until t=3, then the low task starts on `0x300`. At t=4 the safety frame preempts the low task, which loses tick 5 to the high task. So its 3 ticks of work end at t=7, not t=6.
@@@ constraints_md
- 1 <= D <= 20000, 0 <= L <= 5, 0 <= N <= 400, 1 <= tick <= D, 0 <= id <= 0x7FF, 0 <= dlc <= 8, code/mask <= 0x7FF.
- High queue 4 frames, priority 5. Low queue 8 frames, priority 2. Exactly these two tasks.
- Only `...FromISR()` APIs and `can_stat()` inside the ISR.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

/* provided: typedef struct { uint16_t id; uint8_t dlc; uint8_t data[8]; } CanFrame;
 *           enum { CAN_FILTERED, CAN_HI_REPLACED, CAN_LO_DROPPED };
 *           void can_stat(int what);
 *           void handle_high(const CanFrame *f);
 *           void handle_low(const CanFrame *f); */

#define HI_QUEUE_LEN 4
#define LO_QUEUE_LEN 8
#define SAFETY_ID_LIMIT 0x100

static QueueHandle_t s_hi_q, s_lo_q;
static uint16_t s_code, s_mask;

static void hi_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO */
        vTaskDelay(1000);
    }
}

static void lo_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO */
        vTaskDelay(1000);
    }
}

void can_rx_isr(const CanFrame *f)
{
    /* TODO: filter, classify, enqueue with the right overflow policy, yield once */
    (void)f;
}

void app_start(uint16_t code, uint16_t mask)
{
    s_code = code;
    s_mask = mask;
    /* TODO: create both queues and both tasks */
    (void)s_hi_q;
    (void)s_lo_q;
    (void)hi_task;
    (void)lo_task;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

typedef struct { uint16_t id; uint8_t dlc; uint8_t data[8]; } CanFrame;
enum { CAN_FILTERED, CAN_HI_REPLACED, CAN_LO_DROPPED };

void can_stat(int what);
void handle_high(const CanFrame *f);
void handle_low(const CanFrame *f);
void can_rx_isr(const CanFrame *f);
void app_start(uint16_t code, uint16_t mask);

#define MAXEV 400
static CanFrame g_frames[MAXEV];
static CanFrame g_mailbox;               /* the controller's single RX mailbox */
static unsigned g_stats[3], g_raised, g_high, g_low, g_errors, g_cost;

void can_stat(int what)
{
    if (!xPortIsInsideInterrupt()) {
        printf("FAIL: can_stat() must be called from the ISR\n");
        g_errors++;
        return;
    }
    if (what < CAN_FILTERED || what > CAN_LO_DROPPED) {
        printf("FAIL: can_stat(%d): unknown statistic\n", what);
        g_errors++;
        return;
    }
    g_stats[what]++;
}

static void print_frame(const char *cls, const CanFrame *f)
{
    unsigned i;

    printf("[t=%u] %s id=0x%03X data=", (unsigned)xTaskGetTickCount(), cls, (unsigned)f->id);
    if (f->dlc == 0) printf("-");
    for (i = 0; i < f->dlc && i < 8; i++) printf("%02X", (unsigned)f->data[i]);
    printf("\n");
}

static int check_ctx(const char *fn, const CanFrame *f, UBaseType_t prio)
{
    if (xPortIsInsideInterrupt()) {
        printf("FAIL: %s() called from the ISR\n", fn);
        g_errors++;
        return 0;
    }
    if (f == NULL || f == &g_mailbox) {
        printf("FAIL: %s() needs a copy of the frame, not the RX mailbox\n", fn);
        g_errors++;
        return 0;
    }
    if (f->dlc > 8) {
        printf("FAIL: %s(): corrupted frame (dlc %u)\n", fn, (unsigned)f->dlc);
        g_errors++;
        return 0;
    }
    if (uxTaskPriorityGet(NULL) != prio) {
        printf("FAIL: %s() called from a task of priority %d (expected %d)\n", fn, (int)uxTaskPriorityGet(NULL), (int)prio);
        g_errors++;
    }
    return 1;
}

void handle_high(const CanFrame *f)
{
    if (!check_ctx("handle_high", f, 5)) return;
    if (f->id >= 0x100) {
        printf("FAIL: frame 0x%03X is not a safety frame\n", (unsigned)f->id);
        g_errors++;
    }
    print_frame("HI", f);
    g_high++;
    vSimBusyWork(1);
}

void handle_low(const CanFrame *f)
{
    if (!check_ctx("handle_low", f, 2)) return;
    if (f->id < 0x100) {
        printf("FAIL: safety frame 0x%03X handled by the low task\n", (unsigned)f->id);
        g_errors++;
    }
    print_frame("LO", f);
    g_low++;
    if (g_cost) vSimBusyWork((TickType_t)g_cost);
}

/*USER_CODE*/

static void can_irq(void *arg)
{
    g_raised++;
    g_mailbox = *(const CanFrame *)arg;
    can_rx_isr(&g_mailbox);
    memset(&g_mailbox, 0xEE, sizeof g_mailbox);   /* the hardware reuses the mailbox */
}

static void background_task(void *p)
{
    (void)p;
    for (;;) vSimBusyWork(1);
}

static int hexval(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return -1;
}

int main(void)
{
    unsigned d, code, mask, n, i, t, id, dlc, k, pend;
    char hex[32];

    if (scanf("%u %u %x %x %u", &d, &g_cost, &code, &mask, &n) != 5 || n > MAXEV) return 1;
    app_start((uint16_t)code, (uint16_t)mask);
    xTaskCreate(background_task, "bg", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    for (i = 0; i < n; i++) {
        if (scanf("%u %x %u %31s", &t, &id, &dlc, hex) != 4 || dlc > 8) return 1;
        g_frames[i].id = (uint16_t)id;
        g_frames[i].dlc = (uint8_t)dlc;
        for (k = 0; k < dlc; k++) {
            int hi = hexval(hex[2 * k]), lo = hi < 0 ? -1 : hexval(hex[2 * k + 1]);
            if (hi < 0 || lo < 0) return 1;
            g_frames[i].data[k] = (uint8_t)(hi * 16 + lo);
        }
        xSimScheduleInterrupt((TickType_t)t, can_irq, &g_frames[i]);
    }
    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();
    pend = g_raised - g_high - g_low - g_stats[CAN_FILTERED] - g_stats[CAN_HI_REPLACED] - g_stats[CAN_LO_DROPPED];
    printf("frames=%u high=%u low=%u filtered=%u hi_replaced=%u lo_dropped=%u pending=%d\n", g_raised, g_high, g_low,
           g_stats[CAN_FILTERED], g_stats[CAN_HI_REPLACED], g_stats[CAN_LO_DROPPED], (int)pend);
    if (g_errors) printf("ERRORS: %u\n", g_errors);
    return 0;
}
@@@ sample_input
30 3 000 000
5
2 0A0 2 1122
2 300 1 AA
3 301 1 BB
4 050 0 -
10 7FF 8 0102030405060708
@@@ sample_output
[t=2] HI id=0x0A0 data=1122
[t=3] LO id=0x300 data=AA
[t=4] HI id=0x050 data=-
[t=7] LO id=0x301 data=BB
[t=10] LO id=0x7FF data=0102030405060708
frames=5 high=2 low=3 filtered=0 hi_replaced=0 lo_dropped=0 pending=0
@@@ sample_input
19 2 000 400
17
5 010 1 01
5 011 1 02
5 012 1 03
5 013 1 04
5 014 1 05
5 015 1 06
5 500 0 -
12 300 1 A0
12 301 1 A1
12 302 1 A2
12 303 1 A3
12 304 1 A4
12 305 1 A5
12 306 1 A6
12 307 1 A7
12 308 1 A8
12 309 1 A9
@@@ sample_output
[t=5] HI id=0x012 data=03
[t=6] HI id=0x013 data=04
[t=7] HI id=0x014 data=05
[t=8] HI id=0x015 data=06
[t=12] LO id=0x300 data=A0
[t=14] LO id=0x301 data=A1
[t=16] LO id=0x302 data=A2
[t=18] LO id=0x303 data=A3
frames=17 high=4 low=4 filtered=1 hi_replaced=2 lo_dropped=2 pending=4
@@@ hidden_input
50 2 7FF 7FF
0
@@@ hidden_output
frames=0 high=0 low=0 filtered=0 hi_replaced=0 lo_dropped=0 pending=0
@@@ hidden_input
40 0 100 700
6
1 100 2 BEEF
1 1FF 1 01
1 0FF 1 02
2 200 0 -
3 180 3 C0FFEE
40 101 1 FF
@@@ hidden_output
[t=1] LO id=0x100 data=BEEF
[t=1] LO id=0x1FF data=01
[t=3] LO id=0x180 data=C0FFEE
[t=40] LO id=0x101 data=FF
frames=6 high=0 low=4 filtered=2 hi_replaced=0 lo_dropped=0 pending=0

@@@ hidden_input
40 4 000 000
10
1 400 1 01
1 401 1 02
2 001 1 11
3 002 1 12
4 003 1 13
4 004 1 14
4 005 1 15
4 006 1 16
4 007 1 17
4 008 1 18
@@@ hidden_output
[t=1] LO id=0x400 data=01
[t=2] HI id=0x001 data=11
[t=3] HI id=0x002 data=12
[t=4] HI id=0x005 data=15
[t=5] HI id=0x006 data=16
[t=6] HI id=0x007 data=17
[t=7] HI id=0x008 data=18
[t=11] LO id=0x401 data=02
frames=10 high=6 low=2 filtered=0 hi_replaced=2 lo_dropped=0 pending=0

@@@ hidden_input
20000 5 000 000
14
1 0AA 1 01
1 6AA 1 02
1 6AB 1 03
1 6AC 1 04
1 6AD 1 05
1 6AE 1 06
1 6AF 1 07
1 6B0 1 08
1 6B1 1 09
1 6B2 1 0A
1 6B3 1 0B
9999 0BB 0 -
20000 0CC 1 CC
20000 6CC 1 DD
@@@ hidden_output
[t=1] HI id=0x0AA data=01
[t=2] LO id=0x6AA data=02
[t=7] LO id=0x6AB data=03
[t=12] LO id=0x6AC data=04
[t=17] LO id=0x6AD data=05
[t=22] LO id=0x6AE data=06
[t=27] LO id=0x6AF data=07
[t=32] LO id=0x6B0 data=08
[t=37] LO id=0x6B1 data=09
[t=9999] HI id=0x0BB data=-
[t=20000] HI id=0x0CC data=CC
frames=14 high=3 low=8 filtered=0 hi_replaced=0 lo_dropped=2 pending=1

@@@ hidden_input
30 1 0F0 0F0
8
2 0F0 1 01
2 0F1 1 02
2 1F3 1 03
2 0E0 1 04
3 2F0 8 0011223344556677
3 7FF 1 05
3 0FF 1 06
30 3F0 1 07
@@@ hidden_output
[t=2] HI id=0x0F0 data=01
[t=3] HI id=0x0F1 data=02
[t=4] HI id=0x0FF data=06
[t=5] LO id=0x1F3 data=03
[t=6] LO id=0x2F0 data=0011223344556677
[t=7] LO id=0x7FF data=05
[t=30] LO id=0x3F0 data=07
frames=8 high=3 low=4 filtered=1 hi_replaced=0 lo_dropped=0 pending=0

@@@ hint
Copy first (`CanFrame fr = *f;`), then filter and classify. Use one `woken` for everything: `xQueueSendFromISR(q, &fr, &woken)` copies the whole struct into the queue. For the safety class, when `xQueueIsQueueFullFromISR(s_hi_q)` is true (or the send fails), receive one frame into a scratch variable first.
@@@ hint
`if (xQueueSendFromISR(s_hi_q, &fr, &woken) != pdPASS) { CanFrame old; xQueueReceiveFromISR(s_hi_q, &old, &woken); can_stat(CAN_HI_REPLACED); xQueueSendFromISR(s_hi_q, &fr, &woken); }`. Nothing can run between these calls (you are in the ISR), so the retry cannot fail. The low class is a plain send with `can_stat(CAN_LO_DROPPED)` on failure. End with a single `portYIELD_FROM_ISR(woken)`.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

/* provided: typedef struct { uint16_t id; uint8_t dlc; uint8_t data[8]; } CanFrame;
 *           enum { CAN_FILTERED, CAN_HI_REPLACED, CAN_LO_DROPPED };
 *           void can_stat(int what);
 *           void handle_high(const CanFrame *f);
 *           void handle_low(const CanFrame *f); */

#define HI_QUEUE_LEN 4
#define LO_QUEUE_LEN 8
#define SAFETY_ID_LIMIT 0x100

static QueueHandle_t s_hi_q, s_lo_q;
static uint16_t s_code, s_mask;

static void hi_task(void *pvParameters)
{
    CanFrame fr;

    (void)pvParameters;
    for (;;) {
        if (xQueueReceive(s_hi_q, &fr, portMAX_DELAY) == pdPASS) handle_high(&fr);
    }
}

static void lo_task(void *pvParameters)
{
    CanFrame fr;

    (void)pvParameters;
    for (;;) {
        if (xQueueReceive(s_lo_q, &fr, portMAX_DELAY) == pdPASS) handle_low(&fr);
    }
}

void can_rx_isr(const CanFrame *f)
{
    BaseType_t woken = pdFALSE;          /* one flag for every FromISR call */
    CanFrame fr = *f;                    /* the mailbox is reused after we return */

    if ((fr.id & s_mask) != (s_code & s_mask)) {
        can_stat(CAN_FILTERED);
        return;                          /* nothing woken, no yield needed */
    }
    if (fr.id < SAFETY_ID_LIMIT) {
        if (xQueueSendFromISR(s_hi_q, &fr, &woken) != pdPASS) {
            CanFrame oldest;             /* full: newest safety frame wins */
            (void)xQueueReceiveFromISR(s_hi_q, &oldest, &woken);
            can_stat(CAN_HI_REPLACED);
            (void)xQueueSendFromISR(s_hi_q, &fr, &woken);
        }
    } else if (xQueueSendFromISR(s_lo_q, &fr, &woken) != pdPASS) {
        can_stat(CAN_LO_DROPPED);        /* full: drop the new comfort frame */
    }
    portYIELD_FROM_ISR(woken);
}

void app_start(uint16_t code, uint16_t mask)
{
    s_code = code;
    s_mask = mask;
    s_hi_q = xQueueCreate(HI_QUEUE_LEN, sizeof(CanFrame));
    s_lo_q = xQueueCreate(LO_QUEUE_LEN, sizeof(CanFrame));
    configASSERT(s_hi_q != NULL && s_lo_q != NULL);
    xTaskCreate(hi_task, "can_hi", configMINIMAL_STACK_SIZE, NULL, 5, NULL);
    xTaskCreate(lo_task, "can_lo", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
}
@@@ explanation_md
**Approach.** The ISR works in three steps.
1. **Copy** the frame out of the mailbox (the hardware reuses it).
2. **Filter**: the classic acceptance rule is `(id & mask) == (code & mask)`. Mask bits set to 1 must match, bits set to 0 are "don't care". Filtering in the ISR keeps uninteresting traffic off the queues and out of the tasks.
3. **Classify and enqueue** with a per-class overflow policy:
   - Safety frames carry *state* (the latest brake request). When their queue is full, the **oldest** one is the least valuable. `xQueueReceiveFromISR()` frees a slot and the new frame is queued. Interrupts are effectively atomic here, so the re-send cannot fail.
   - Comfort/diagnostic frames carry *events in order*, and a reader would rather notice a gap than get reordered data. The new frame is dropped and counted.

A single `woken` is shared by all FromISR calls. Each call only ever sets it to `pdTRUE`, and one `portYIELD_FROM_ISR()` at the end performs the switch. The high task (priority 5) preempts the low one (priority 2) in the middle of its work, which the example trace shows as the low task's work stretching from t=3 to t=7.

**Complexity.** ISR: O(1), two struct copies (12 bytes each) and at most three queue operations. Tasks: O(1) per frame plus their work time. RAM: 4 x 12 + 8 x 12 bytes of queue storage, two queue control blocks, two stacks.

**Common mistakes**
- Queueing a **pointer** to the mailbox: by the time the task runs, the mailbox holds the next frame (here, `0xEE` garbage).
- Separate `woken` variables per call with only the last one passed to `portYIELD_FROM_ISR()`, so an earlier wake-up is lost. Or resetting `woken` to `pdFALSE` between calls.
- `xQueueOverwriteFromISR()` on a 4-deep queue: it is only valid for queues of length 1 (asserts otherwise).
- Getting the filter backwards (`(id & ~mask)`) or comparing `id & mask` with an unmasked `code`.
- Doing the frame processing in the ISR, or one task for both classes: a flood of comfort frames then delays brake commands.

**Interview follow-ups**
- How do hardware acceptance filters (bxCAN filter banks, MCAN filter elements) change the ISR? What remains in software?
- How would you use a FreeRTOS **queue set** if the same task had to service both classes but always prefer safety frames?
- At 1 Mbit/s, what is the minimum frame time, and how deep must the high queue be for a 2 ms worst-case task latency?
- How would you report bus-off and error-passive states from the error ISR into this design?
