@@@ meta
id: BIT-H-09
topic: Bit Manipulation
difficulty: Hard
type: FIND_THE_BUG
title: UART Ring Buffer With Free-Running uint8_t Indices
tags: embedded, ring-buffer, integer-promotion, power-of-two, uart, isr, lock-free
@@@ statement_md
A UART receive path uses the classic lock-free single-producer/single-consumer ring buffer:
- the RX ISR is the only writer of `rb_head`, and the application task is the only writer of `rb_tail`;
- both indices are **free-running** 8-bit counters that are never wrapped explicitly. The slot is `index & RB_MASK`, and the fill level is "head minus tail";
- the size (16) is a power of two that divides 256, so the 8-bit counters wrap consistently.

Required behaviour: `rb_put` stores a byte unless the buffer holds 16 bytes (then the byte is dropped and counted). `rb_get` returns the oldest byte, or reports "empty".

The code passed every bench test. On the vehicle, after a few hundred bytes have passed through, the ECU starts **dropping bytes although the buffer is nearly empty**, and the diagnostic stream becomes garbled. Find and fix the bug. Do not change the data structure (free-running `uint8_t` indices) or the output format.

**Input (the test driver simulates ISR and task)**
- Line 1: `q`.
- Next `q` lines:
  - `W k`: the ISR receives `k` bytes. The byte values continue a global counter `0, 1, 2, ...` modulo 256.
  - `R k`: the task reads up to `k` bytes and prints `read n=<bytes read> sum=<sum of their values> last=<last byte as %02X, or -->`.
  - `L t w r`: repeat `t` times { `W w`, then read up to `r` bytes }, and print **one** `read ...` line for all reads of the loop.
- Finally the program prints `dropped=<number of dropped bytes>`.

**Example**
```
Input:
4
W 5
R 3
W 20
R 100

Output:
read n=3 sum=3 last=02
read n=16 sum=168 last=12
dropped=6
```
@@@ constraints_md
- `1 <= q <= 20`, `1 <= t <= 1000`, `0 <= k, w, r <= 100`
- Keep `rb_head`/`rb_tail` as free-running `uint8_t` counters and `RB_SIZE` = 16.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

#define RB_SIZE 16u                     /* power of two that divides 256 */
#define RB_MASK (RB_SIZE - 1u)

static uint8_t rb_buf[RB_SIZE];
static volatile uint8_t rb_head;        /* written only by the RX ISR   */
static volatile uint8_t rb_tail;        /* written only by the task     */
static unsigned dropped;

static unsigned rb_count(void)
{
    return rb_head - rb_tail;           /* free-running counters: difference = fill level */
}

/* UART RX ISR context */
static void rb_put(uint8_t byte)
{
    if (rb_count() >= RB_SIZE) {
        dropped++;
        return;
    }
    rb_buf[rb_head & RB_MASK] = byte;
    rb_head++;
}

/* task context: returns 1 and stores the byte, or 0 if empty */
static int rb_get(uint8_t *byte)
{
    if (rb_count() == 0u)
        return 0;
    *byte = rb_buf[rb_tail & RB_MASK];
    rb_tail++;
    return 1;
}

/* ---------------- test driver (simulates ISR and task) ---------------- */
static unsigned seq;
static int n_read;
static long long sum_read;
static int last_read;

static void isr_receive(int k)
{
    for (int i = 0; i < k; i++)
        rb_put((uint8_t)(seq++ & 0xFFu));
}

static void task_read(int k)
{
    uint8_t b;
    for (int i = 0; i < k && rb_get(&b); i++) {
        n_read++;
        sum_read += b;
        last_read = b;
    }
}

static void report(void)
{
    if (last_read < 0)
        printf("read n=%d sum=%lld last=--\n", n_read, sum_read);
    else
        printf("read n=%d sum=%lld last=%02X\n", n_read, sum_read, (unsigned)last_read);
    n_read = 0;
    sum_read = 0;
    last_read = -1;
}

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    last_read = -1;
    for (int c = 0; c < q; c++) {
        char op;
        int a, w, r;
        if (scanf(" %c %d", &op, &a) != 2) return 0;
        if (op == 'W') {
            isr_receive(a);
        } else if (op == 'R') {
            task_read(a);
            report();
        } else {
            if (scanf("%d %d", &w, &r) != 2) return 0;
            for (int i = 0; i < a; i++) {
                isr_receive(w);
                task_read(r);
            }
            report();
        }
    }
    printf("dropped=%u\n", dropped);
    return 0;
}
@@@ sample_input
4
W 5
R 3
W 20
R 100
@@@ sample_output
read n=3 sum=3 last=02
read n=16 sum=168 last=12
dropped=6

@@@ sample_input
1
L 30 10 10
@@@ sample_output
read n=300 sum=33586 last=2B
dropped=0

@@@ hidden_input
4
W 16
W 1
R 16
R 1
@@@ hidden_output
read n=16 sum=120 last=0F
read n=0 sum=0 last=--
dropped=1

@@@ hidden_input
2
L 100 7 5
R 100
@@@ hidden_output
read n=500 sum=57319 last=AA
read n=11 sum=1966 last=B9
dropped=189

@@@ hidden_input
3
L 25 10 10
W 10
R 16
@@@ hidden_output
read n=250 sum=31125 last=F9
read n=10 sum=1521 last=03
dropped=0

@@@ hidden_input
3
R 5
W 3
R 5
@@@ hidden_output
read n=0 sum=0 last=--
read n=3 sum=3 last=02
dropped=0

@@@ hidden_input
1
L 1000 3 3
@@@ hidden_output
read n=3000 sum=375876 last=B7
dropped=0

@@@ hidden_input
2
L 60 20 4
R 100
@@@ hidden_output
read n=240 sum=27784 last=63
read n=12 sum=1650 last=9F
dropped=948

@@@ hint
The design relies on `rb_head - rb_tail` wrapping modulo 256, which is true for 8-bit arithmetic. But in what type does C actually perform `rb_head - rb_tail` when both operands are `uint8_t`? Trace `rb_head = 2`, `rb_tail = 250` (8 bytes queued just after the head counter wrapped).
@@@ hint
Both operands are promoted to `int`, so `2 - 250 = -248`. Returned as `unsigned`, that is 4294967048, which is ">= 16": the buffer looks **full**, and the ISR drops every byte until the tail wraps too. Truncate the difference back to 8 bits before using it.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

#define RB_SIZE 16u                     /* power of two that divides 256 */
#define RB_MASK (RB_SIZE - 1u)

static uint8_t rb_buf[RB_SIZE];
static volatile uint8_t rb_head;        /* written only by the RX ISR   */
static volatile uint8_t rb_tail;        /* written only by the task     */
static unsigned dropped;

static unsigned rb_count(void)
{
    /* FIX: uint8_t operands are promoted to int, so the difference can be negative;
       cast back to uint8_t to get the modulo-256 distance the design relies on */
    return (uint8_t)(rb_head - rb_tail);
}

/* UART RX ISR context */
static void rb_put(uint8_t byte)
{
    if (rb_count() >= RB_SIZE) {
        dropped++;
        return;
    }
    rb_buf[rb_head & RB_MASK] = byte;
    rb_head++;
}

/* task context: returns 1 and stores the byte, or 0 if empty */
static int rb_get(uint8_t *byte)
{
    if (rb_count() == 0u)
        return 0;
    *byte = rb_buf[rb_tail & RB_MASK];
    rb_tail++;
    return 1;
}

/* ---------------- test driver (simulates ISR and task) ---------------- */
static unsigned seq;
static int n_read;
static long long sum_read;
static int last_read;

static void isr_receive(int k)
{
    for (int i = 0; i < k; i++)
        rb_put((uint8_t)(seq++ & 0xFFu));
}

static void task_read(int k)
{
    uint8_t b;
    for (int i = 0; i < k && rb_get(&b); i++) {
        n_read++;
        sum_read += b;
        last_read = b;
    }
}

static void report(void)
{
    if (last_read < 0)
        printf("read n=%d sum=%lld last=--\n", n_read, sum_read);
    else
        printf("read n=%d sum=%lld last=%02X\n", n_read, sum_read, (unsigned)last_read);
    n_read = 0;
    sum_read = 0;
    last_read = -1;
}

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    last_read = -1;
    for (int c = 0; c < q; c++) {
        char op;
        int a, w, r;
        if (scanf(" %c %d", &op, &a) != 2) return 0;
        if (op == 'W') {
            isr_receive(a);
        } else if (op == 'R') {
            task_read(a);
            report();
        } else {
            if (scanf("%d %d", &w, &r) != 2) return 0;
            for (int i = 0; i < a; i++) {
                isr_receive(w);
                task_read(r);
            }
            report();
        }
    }
    printf("dropped=%u\n", dropped);
    return 0;
}
@@@ explanation_md
**Bug.** The design is right: with free-running counters and a power-of-two size that divides 256, `(head - tail) mod 256` is always the fill level (0..16), even after either counter wraps. But C never subtracts in 8 bits. Both `uint8_t` operands are **promoted to `int`** (C11 6.3.1.1), and the subtraction is done in `int`:

```
head = 2, tail = 250  (8 bytes queued, head has wrapped)
int:      2 - 250 = -248
unsigned: 4294967048   -> ">= 16" -> buffer "full"
(uint8_t)(2 - 250)  = 8    <- what the design needs
```

While `head` has wrapped and `tail` has not, every `rb_put` sees a "full" buffer and drops the byte. Bench tests with fewer than 256 bytes never wrap, so they pass. In the vehicle, the bug appears after the first 256 bytes and then every 256 bytes, which matches the "few hundred bytes" symptom.

**Fix.** `return (uint8_t)(rb_head - rb_tail);`. The cast reduces the `int` result modulo 256, exactly the 8-bit arithmetic the design assumed. The mask `& 0xFFu` works too. `RB_MASK` alone would be wrong: a full buffer (difference 16) would read as empty.

**Complexity.** O(1) per put/get, O(total bytes) per test, O(RB_SIZE) memory.

**Common mistakes**
- "Fixing" with `& RB_MASK`. Then `count == 16` (full) becomes 0 (empty), and the reader reads stale data. Free-running indices need the counter width, not the buffer width, for the distance.
- Making the indices `uint32_t` without understanding why. It works (unsigned 32-bit arithmetic is not promoted), but on an 8-bit or 16-bit MCU the index update is no longer a single atomic write, which breaks the lock-free argument.
- Choosing `RB_SIZE` = 24 (not a power of two, does not divide 256). The free-running scheme then breaks at every wrap.
- Wrapping the indices with `head = (head + 1) % RB_SIZE` **and** using `head == tail` for both full and empty. That is the classic ambiguity the free-running design avoids.

**Interview follow-ups**
- Why is this ring buffer safe without disabling interrupts on a single-core Cortex-M, as long as each index has one writer? What would you need on a multi-core MCU (memory barriers, `__DMB()`)?
- Where must `volatile` be used here, and is it sufficient? (It prevents caching, but not reordering of the data write versus the `head` update on a weakly ordered core.)
- Rewrite `rb_count` for `uint16_t` indices. Does the same promotion bug exist on a 32-bit MCU? And on a 16-bit MCU where `int` is 16 bits?
- How would you extend this to DMA-driven reception, where the DMA hardware owns the write index?
