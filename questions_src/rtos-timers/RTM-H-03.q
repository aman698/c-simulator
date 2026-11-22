@@@ meta
id: RTM-H-03
topic: Software Timers
difficulty: Hard
type: FUNCTION
title: Request Retry With Exponential Backoff Using One-Shot Timers
tags: freertos, software-timers, exponential-backoff, retransmission, isr, timer-id, embedded, asked-in-automotive
@@@ statement_md
A telematics unit sends requests to a modem over a lossy link. Each request must be acknowledged. Without an ACK in time, the request is retransmitted with **exponential backoff**, and after a maximum number of tries it fails. Up to **4 requests** can be outstanding at once. Implement the retry engine with **one one-shot software timer per slot** (4 timers).

```c
void radio_send(uint32_t seq, int attempt);        /* provided, non-blocking: prints "[t=<tick>] TX seq=<seq> try=<attempt>" */
void comm_result(uint32_t seq, int ok, int tries); /* provided, any context: prints "[t=<tick>] DONE seq=<seq> tries=<tries>"
                                                      or "[t=<tick>] FAIL seq=<seq> tries=<tries>" */

void comm_init(TickType_t base, TickType_t cap, int max_tries);  /* you write: before the scheduler */
BaseType_t comm_send(uint32_t seq);   /* you write: called from a task (priority 2) */
void ack_isr(uint32_t seq);           /* you write: runs in INTERRUPT context */
```

**Protocol.**
- `comm_send(seq)` takes the **lowest free** of the 4 slots, calls `radio_send(seq, 1)` and waits for an ACK. If all slots are busy, it returns `pdFAIL` and does nothing else. Otherwise it returns `pdPASS`.
- The ACK timeout after try `k` (1-based) is `min(base * 2^(k-1), cap)` ticks, counted from the tick of try `k`.
- If the timeout expires and `k < max_tries`, retransmit from the timer callback with `radio_send(seq, k + 1)`, then wait for the next, longer timeout.
- If the timeout of try `max_tries` expires, call `comm_result(seq, 0, max_tries)` and free the slot.
- `ack_isr(seq)`: if `seq` is outstanding, call `comm_result(seq, 1, k)` (where `k` is the number of tries sent so far), stop its timer and free the slot. ACKs for unknown, finished or failed sequence numbers are **ignored**.

**Same-tick ordering.**
- Interrupts at tick `T` run first, then the timer service task (priority 7), then the sending task (priority 2).
- So an ACK that arrives exactly at the timeout tick **wins**: the request is DONE and nothing is retransmitted.
- A slot freed by a timeout (FAIL) at tick `T` is free again for a `comm_send()` at the same tick `T`.

Rules: at most 4 timers, and callbacks must not block (block time `0`). Use only `...FromISR()` APIs in `ack_isr()`, and end it with `portYIELD_FROM_ISR()`. Creating tasks and `vTaskDelay()` are banned.

**How it is tested.** A hidden task calls `comm_send()` at each `SEND` tick and prints `[t=<tick>] BUSY seq=<seq>` if it returns `pdFAIL`. Hidden interrupts call `ack_isr()` at each `ACK` tick. At one tick, events of the same kind happen in input order. The scheduler runs up to and including tick `D`. The harness checks that the tries of every request are numbered 1, 2, 3, ... Then it prints the totals.

**Input**
```
<base> <cap> <max_tries> <D>
<n>
<tick> SEND <seq>   |   <tick> ACK <seq>      (n lines, ticks non-decreasing)
```

**Example**
```
Input:
10 40 4 200
3
5 SEND 1
8 SEND 2
30 ACK 2

Output:
[t=5] TX seq=1 try=1
[t=8] TX seq=2 try=1
[t=15] TX seq=1 try=2
[t=18] TX seq=2 try=2
[t=30] DONE seq=2 tries=2
[t=35] TX seq=1 try=3
[t=75] TX seq=1 try=4
[t=115] FAIL seq=1 tries=4
done=1 failed=1 busy=0 ignored acks=0
```
For seq 1 the timeouts are 10, 20, 40 and then min(80, 40) = 40, so the tries are at 5, 15, 35 and 75, and it fails at 115. Seq 2 is acknowledged at 30, after its second try.
@@@ constraints_md
- 1 <= base <= cap <= 5000, 1 <= max_tries <= 10, 1 <= D <= 20000, 0 <= n <= 60, 1 <= tick <= D.
- Sequence numbers of SEND lines are distinct.
- Two outstanding requests never time out at the same tick.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

void radio_send(uint32_t seq, int attempt);
void comm_result(uint32_t seq, int ok, int tries);

#define SLOTS 4

void comm_init(TickType_t base, TickType_t cap, int max_tries)
{
    /* TODO: one one-shot timer per slot (timer ID = slot index) */
    (void)base;
    (void)cap;
    (void)max_tries;
}

BaseType_t comm_send(uint32_t seq)
{
    /* TODO */
    (void)seq;
    return pdFAIL;
}

void ack_isr(uint32_t seq)
{
    /* TODO */
    (void)seq;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"
#include "sim.h"

#define H_MAXE 64

static volatile int g_in_isr;
static unsigned g_done, g_failed, g_busy, g_acks, g_ntimers;
static int g_bad_order, g_bad_result;
static uint32_t g_seq[H_MAXE];
static int g_tries[H_MAXE], g_closed[H_MAXE];
static unsigned g_nseq;

static unsigned now_tick(void)
{
    return (unsigned)(g_in_isr ? xTaskGetTickCountFromISR() : xTaskGetTickCount());
}

static int seq_index(uint32_t seq)
{
    unsigned i;
    for (i = 0; i < g_nseq; i++) if (g_seq[i] == seq) return (int)i;
    return -1;
}

void radio_send(uint32_t seq, int attempt)
{
    int i = seq_index(seq);
    printf("[t=%u] TX seq=%u try=%d\n", now_tick(), (unsigned)seq, attempt);
    if (i < 0 || g_closed[i] || attempt != g_tries[i] + 1) g_bad_order = 1;
    else g_tries[i] = attempt;
}

void comm_result(uint32_t seq, int ok, int tries)
{
    int i = seq_index(seq);
    printf("[t=%u] %s seq=%u tries=%d\n", now_tick(), ok ? "DONE" : "FAIL", (unsigned)seq, tries);
    if (i < 0 || g_closed[i] || tries != g_tries[i]) g_bad_result = 1;
    else g_closed[i] = 1;
    if (ok) g_done++;
    else g_failed++;
}

static TimerHandle_t h_timer_create(const char *name, TickType_t period, BaseType_t reload,
                                    void *id, TimerCallbackFunction_t cb)
{
    g_ntimers++;
    return xTimerCreate(name, period, reload, id, cb);
}

#define xTimerCreate(a, b, c, d, e) h_timer_create(a, b, c, d, e)
#define xTimerCreateStatic(...) xTimerCreateStatic_is_not_allowed_here
#define xTaskCreate(...) xTaskCreate_is_not_allowed_here
#define xTaskCreateStatic(...) xTaskCreateStatic_is_not_allowed_here
#define vTaskDelay(x) vTaskDelay_is_not_allowed_here
#define xTaskDelayUntil(...) xTaskDelayUntil_is_not_allowed_here

/*USER_CODE*/

#undef xTimerCreate
#undef xTimerCreateStatic
#undef xTaskCreate
#undef xTaskCreateStatic
#undef vTaskDelay
#undef xTaskDelayUntil

typedef struct { TickType_t tick; uint32_t seq; } Ev;
static Ev g_send[H_MAXE], g_ack[H_MAXE];
static unsigned g_nsend, g_nack;

static void ack_irq(void *arg)
{
    Ev *e = (Ev *)arg;
    g_acks++;
    g_in_isr = 1;
    ack_isr(e->seq);
    g_in_isr = 0;
}

static void sender(void *p)
{
    unsigned i;
    (void)p;
    for (i = 0; i < g_nsend; i++) {
        TickType_t now = xTaskGetTickCount();
        if (g_send[i].tick > now) vTaskDelay(g_send[i].tick - now);
        if (comm_send(g_send[i].seq) != pdPASS) {
            printf("[t=%u] BUSY seq=%u\n", (unsigned)xTaskGetTickCount(), (unsigned)g_send[i].seq);
            g_busy++;
            g_closed[seq_index(g_send[i].seq)] = 1;
        }
    }
    for (;;) vTaskDelay(portMAX_DELAY);
}

int main(void)
{
    unsigned base, cap, maxt, dur, n, i, t, s;
    char word[8];

    if (scanf("%u %u %u %u %u", &base, &cap, &maxt, &dur, &n) != 5 || n > H_MAXE) return 1;
    for (i = 0; i < n; i++) {
        if (scanf("%u %7s %u", &t, word, &s) != 3) return 1;
        if (strcmp(word, "SEND") == 0) {
            g_send[g_nsend].tick = (TickType_t)t;
            g_send[g_nsend].seq = (uint32_t)s;
            g_seq[g_nseq++] = (uint32_t)s;
            g_nsend++;
        } else {
            g_ack[g_nack].tick = (TickType_t)t;
            g_ack[g_nack].seq = (uint32_t)s;
            xSimScheduleInterrupt((TickType_t)t, ack_irq, &g_ack[g_nack]);
            g_nack++;
        }
    }

    comm_init((TickType_t)base, (TickType_t)cap, (int)maxt);
    xTaskCreate(sender, "send", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    if (g_ntimers > 4) printf("FAIL: %u timers created (at most 4)\n", g_ntimers);
    if (g_bad_order) printf("FAIL: tries not numbered 1, 2, 3, ... (or TX after the result)\n");
    if (g_bad_result) printf("FAIL: wrong or duplicate result\n");
    printf("done=%u failed=%u busy=%u ignored acks=%u\n", g_done, g_failed, g_busy, g_acks - g_done);
    return 0;
}
@@@ sample_input
10 40 4 200
3
5 SEND 1
8 SEND 2
30 ACK 2
@@@ sample_output
[t=5] TX seq=1 try=1
[t=8] TX seq=2 try=1
[t=15] TX seq=1 try=2
[t=18] TX seq=2 try=2
[t=30] DONE seq=2 tries=2
[t=35] TX seq=1 try=3
[t=75] TX seq=1 try=4
[t=115] FAIL seq=1 tries=4
done=1 failed=1 busy=0 ignored acks=0
@@@ sample_input
5 100 3 100
5
1 SEND 10
6 ACK 10
7 ACK 10
10 SEND 11
45 ACK 11
@@@ sample_output
[t=1] TX seq=10 try=1
[t=6] DONE seq=10 tries=1
[t=10] TX seq=11 try=1
[t=15] TX seq=11 try=2
[t=25] TX seq=11 try=3
[t=45] DONE seq=11 tries=3
done=2 failed=0 busy=0 ignored acks=1
@@@ hidden_input
10 10 3 100
0
@@@ hidden_output
done=0 failed=0 busy=0 ignored acks=0
@@@ hidden_input
3 50 1 20
4
1 ACK 7
1 SEND 7
2 SEND 8
4 SEND 9
@@@ hidden_output
[t=1] TX seq=7 try=1
[t=2] TX seq=8 try=1
[t=4] FAIL seq=7 tries=1
[t=4] TX seq=9 try=1
[t=5] FAIL seq=8 tries=1
[t=7] FAIL seq=9 tries=1
done=0 failed=3 busy=0 ignored acks=1
@@@ hidden_input
20 20 2 200
8
1 SEND 1
2 SEND 2
3 SEND 3
4 SEND 4
4 SEND 5
41 SEND 6
42 SEND 7
50 ACK 6
@@@ hidden_output
[t=1] TX seq=1 try=1
[t=2] TX seq=2 try=1
[t=3] TX seq=3 try=1
[t=4] TX seq=4 try=1
[t=4] BUSY seq=5
[t=21] TX seq=1 try=2
[t=22] TX seq=2 try=2
[t=23] TX seq=3 try=2
[t=24] TX seq=4 try=2
[t=41] FAIL seq=1 tries=2
[t=41] TX seq=6 try=1
[t=42] FAIL seq=2 tries=2
[t=42] TX seq=7 try=1
[t=43] FAIL seq=3 tries=2
[t=44] FAIL seq=4 tries=2
[t=50] DONE seq=6 tries=1
[t=62] TX seq=7 try=2
[t=82] FAIL seq=7 tries=2
done=1 failed=5 busy=1 ignored acks=0
@@@ hidden_input
100 250 5 2000
2
10 SEND 42
1100 ACK 42
@@@ hidden_output
[t=10] TX seq=42 try=1
[t=110] TX seq=42 try=2
[t=310] TX seq=42 try=3
[t=560] TX seq=42 try=4
[t=810] TX seq=42 try=5
[t=1060] FAIL seq=42 tries=5
done=0 failed=1 busy=0 ignored acks=1
@@@ hidden_input
500 4000 6 20000
4
100 SEND 1000
101 SEND 2000
3600 ACK 2000
3601 ACK 2000
@@@ hidden_output
[t=100] TX seq=1000 try=1
[t=101] TX seq=2000 try=1
[t=600] TX seq=1000 try=2
[t=601] TX seq=2000 try=2
[t=1600] TX seq=1000 try=3
[t=1601] TX seq=2000 try=3
[t=3600] DONE seq=2000 tries=3
[t=3600] TX seq=1000 try=4
[t=7600] TX seq=1000 try=5
[t=11600] TX seq=1000 try=6
[t=15600] FAIL seq=1000 tries=6
done=1 failed=1 busy=0 ignored acks=1

@@@ hidden_input
1 1 10 30
3
1 SEND 5
5 ACK 5
6 SEND 6
@@@ hidden_output
[t=1] TX seq=5 try=1
[t=2] TX seq=5 try=2
[t=3] TX seq=5 try=3
[t=4] TX seq=5 try=4
[t=5] DONE seq=5 tries=4
[t=6] TX seq=6 try=1
[t=7] TX seq=6 try=2
[t=8] TX seq=6 try=3
[t=9] TX seq=6 try=4
[t=10] TX seq=6 try=5
[t=11] TX seq=6 try=6
[t=12] TX seq=6 try=7
[t=13] TX seq=6 try=8
[t=14] TX seq=6 try=9
[t=15] TX seq=6 try=10
[t=16] FAIL seq=6 tries=10
done=1 failed=1 busy=0 ignored acks=0

@@@ hint
Give each slot a context `{active, seq, tries}` and a one-shot timer whose ID is the slot index. `xTimerChangePeriod(h, timeout, 0)` both sets the new timeout and (re)starts the timer from "now". Use it in `comm_send()` (try 1) and in the callback (try k + 1).
@@@ hint
Callback: `slot = ID; if (!active) return; if (tries == max) { active = 0; comm_result(seq, 0, tries); } else { tries++; radio_send(seq, tries); xTimerChangePeriod(xTimer, timeout(tries), 0); }` with `timeout(k) = min(base << (k-1), cap)` (compute it without overflowing). ISR: find the active slot with this seq, `active = 0`, `xTimerStopFromISR()`, `comm_result(seq, 1, tries)`, `portYIELD_FROM_ISR()`.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

void radio_send(uint32_t seq, int attempt);
void comm_result(uint32_t seq, int ok, int tries);

#define SLOTS 4

typedef struct {
    volatile int active;
    uint32_t     seq;
    int          tries;      /* tries sent so far */
    TimerHandle_t tmr;
} Slot;

static Slot s_slot[SLOTS];
static TickType_t s_base, s_cap;
static int s_max;

/* min(base * 2^(k-1), cap) without overflowing TickType_t */
static TickType_t backoff(int k)
{
    TickType_t t = s_base;
    while (--k > 0 && t < s_cap) t *= 2;
    return t < s_cap ? t : s_cap;
}

static void retry_cb(TimerHandle_t xTimer)
{
    Slot *s = &s_slot[(uintptr_t)pvTimerGetTimerID(xTimer)];

    if (!s->active) return;                      /* ACKed meanwhile: nothing to do */
    if (s->tries >= s_max) {
        s->active = 0;                           /* give up, free the slot */
        comm_result(s->seq, 0, s->tries);
    } else {
        s->tries++;
        radio_send(s->seq, s->tries);
        /* new, longer timeout counted from now; block time 0 inside a callback */
        xTimerChangePeriod(xTimer, backoff(s->tries), 0);
    }
}

void comm_init(TickType_t base, TickType_t cap, int max_tries)
{
    uintptr_t i;

    s_base = base;
    s_cap = cap;
    s_max = max_tries;
    for (i = 0; i < SLOTS; i++) {
        s_slot[i].active = 0;
        s_slot[i].tmr = xTimerCreate("retry", base, pdFALSE, (void *)i, retry_cb);
    }
}

BaseType_t comm_send(uint32_t seq)
{
    int i;

    for (i = 0; i < SLOTS; i++) {
        if (!s_slot[i].active) {
            Slot *s = &s_slot[i];
            taskENTER_CRITICAL();                /* ack_isr() reads the slot */
            s->seq = seq;
            s->tries = 1;
            s->active = 1;
            taskEXIT_CRITICAL();
            radio_send(seq, 1);
            xTimerChangePeriod(s->tmr, backoff(1), 0);   /* expiry = now + base */
            return pdPASS;
        }
    }
    return pdFAIL;
}

void ack_isr(uint32_t seq)
{
    BaseType_t woken = pdFALSE;
    int i;

    for (i = 0; i < SLOTS; i++) {
        Slot *s = &s_slot[i];
        if (s->active && s->seq == seq) {
            s->active = 0;
            /* the stop is queued before the timer task looks at tick T, so an ACK
               at the timeout tick wins; the active flag makes it safe anyway */
            xTimerStopFromISR(s->tmr, &woken);
            comm_result(seq, 1, s->tries);
            break;
        }
    }                                            /* unknown/finished seq: ignored */
    portYIELD_FROM_ISR(woken);
}
@@@ explanation_md
**Approach.** Every outstanding request owns a slot and a one-shot timer, and the timer ID is the slot index. One callback serves all slots. The timer is the request's "ACK deadline":
- **Send:** fill the slot, transmit try 1, and arm the timer with `xTimerChangePeriod(h, base, 0)`. Changing the period also starts the timer, with expiry = now + base. The timer task (priority 7) handles the command before `comm_send()` returns.
- **Timeout:** the callback runs in the timer service task. Either it gives up (FAIL, slot freed), or it retransmits and re-arms with the next backoff value. A command sent from inside a callback is handled right after the callback returns, with the same "now", so each timeout is counted exactly from its try.
- **ACK:** the ISR clears `active`, queues a stop and reports DONE. Two independent mechanisms make the race safe. First, when the timer task wakes at tick `T`, it drains its command queue (the stop) before it checks for expired timers, so an ACK at the timeout tick suppresses the expiry. Second, even if a stale expiry got through, the callback checks `active` and returns.

The backoff is computed by doubling with saturation at `cap`. `base << (k - 1)` overflows for large `k`.

**Complexity.** O(SLOTS) per send/ACK (slot search) and O(1) per timeout, plus one timer-list insertion each. Worst-case CPU in the ISR: a 4-entry scan. RAM: 4 timer control blocks and 4 small slot structs, with no retry task and no per-request stack.

**Common mistakes**
- `xTimerReset()` to re-arm after a timeout: it keeps the old period, so there is no backoff.
- Retransmitting from the ISR or from a polling task instead of the callback, or blocking in the callback (waiting for the radio).
- Forgetting the `active` check in the callback. An ACK racing with an expiry (on hardware where the timer task already started) then causes a spurious retransmission, or a FAIL after a DONE.
- Freeing the slot on ACK but leaving the timer running: the next request in that slot can be hit by the old expiry. Here the next `comm_send()` re-arms it, but only because `xTimerChangePeriod()` restarts the timer.
- `base << (k-1)` overflow, and off-by-one between "tries sent" and "timeouts seen". The harness checks that the tries are numbered 1, 2, 3, ...
- Calling task-context timer APIs (`xTimerStop`) in the ISR: a Runtime Error in the simulator, and kernel corruption on a real MCU.

**Interview follow-ups**
- Why do real protocols add random **jitter** to the backoff, and how would you add it deterministically for testing?
- How would you implement this with **one** timer for all slots (see the soft-timer multiplexing problem)? What do you gain and lose?
- What happens if the ACK arrives between `radio_send()` and `xTimerChangePeriod()` in `comm_send()`? Is the order of those two calls important?
- How would you report the round-trip time of each successful request without extra timers?
