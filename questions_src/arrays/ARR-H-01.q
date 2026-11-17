@@@ meta
id: ARR-H-01
topic: Arrays
difficulty: Hard
type: FUNCTION
title: UART RX Ring Buffer Without a Count Variable
tags: embedded, ring-buffer, circular-buffer, uart, isr, lock-free, unsigned-wraparound
@@@ statement_md
Implement the receive FIFO of a UART driver. The RX interrupt (**producer**) puts each received byte. The main loop (**consumer**) takes bytes out one at a time or in bulk. The structure is fixed by the driver team:

```c
typedef struct {
    uint8_t          *buf;   /* storage provided by the caller, 'size' bytes   */
    uint16_t          size;  /* number of slots: a power of two, 1..32768      */
    volatile uint16_t head;  /* written ONLY by the producer (ISR)             */
    volatile uint16_t tail;  /* written ONLY by the consumer (main loop)       */
} ringbuf_t;
```

There is deliberately **no `count` field and no `full` flag**. A shared counter would be written by both the ISR and the main loop and would need a critical section. With only `head` and `tail`, each side writes exactly one index, and the FIFO is lock-free for one producer and one consumer.

Requirements:
- The FIFO must hold **all `size` bytes**. The common "leave one slot empty" trick is **not** allowed here: a 16-byte UART FIFO must really hold 16 bytes.
- `head` and `tail` are `uint16_t` and **wrap around** after 65 536 bytes. The driver runs for weeks, so this must work.
- No global or `static` state (the harness runs several FIFOs at once).

```c
void     rb_init(ringbuf_t *rb, uint8_t *storage, uint16_t size);
bool     rb_put(ringbuf_t *rb, uint8_t byte);          /* false if full: byte dropped (overrun) */
bool     rb_get(ringbuf_t *rb, uint8_t *byte);         /* false if empty: *byte untouched       */
uint16_t rb_count(const ringbuf_t *rb);                /* bytes currently stored                */
uint16_t rb_read(ringbuf_t *rb, uint8_t *dst, uint16_t max);
             /* copy min(count, max) bytes in FIFO order into dst, remove them, return how many */
```

**How it is tested.** The hidden harness executes a script. `I size` (init on garbage memory), `P n v` (put `n` bytes `v, v+1, ...`), `G n` (get up to `n` bytes), `R max` (bulk read), `C` (count). `S n seed` runs `n` random burst operations on two FIFOs at once and checks every result against a reference model. Guard bytes around the storage and the `rb_read` destination detect out-of-bounds writes.

**Output (printed by the harness)** `init s`, `put ok/n`, `get: XX ... [empty]`, `read k: XX ...` (summarised when `k > 32`), `count c free f`, `stress OK ...`.

**Example**
```
Input:
I 4
P 6 200
R 3
R 10
G 1

Output:
init 4
put 4/6
read 3: C8 C9 CA
read 1: CB
get: empty
```
@@@ constraints_md
- `size` is a power of two, `1 <= size <= 32768`
- Total traffic per test: up to several million bytes, so `head` and `tail` wrap around many times.
- Every operation is O(1), except `rb_read`, which is O(k).
- Only `head` and `tail` may describe the fill level: no extra fields, no globals.
@@@ starter_code
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <string.h>

/* ringbuf_t is provided by the driver header (see the statement). */

void rb_init(ringbuf_t *rb, uint8_t *storage, uint16_t size)
{
    /* TODO */
}

uint16_t rb_count(const ringbuf_t *rb)
{
    /* TODO */
    return 0;
}

bool rb_put(ringbuf_t *rb, uint8_t byte)
{
    /* TODO: called from the RX ISR */
    return false;
}

bool rb_get(ringbuf_t *rb, uint8_t *byte)
{
    /* TODO */
    return false;
}

uint16_t rb_read(ringbuf_t *rb, uint8_t *dst, uint16_t max)
{
    /* TODO */
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

typedef struct {
    uint8_t          *buf;
    uint16_t          size;
    volatile uint16_t head;
    volatile uint16_t tail;
} ringbuf_t;

/*USER_CODE*/

#define MAXSZ 32768u
#define GUARD 16u
#define STORE_CANARY 0xCCu
#define DST_CANARY 0xDDu

static uint8_t store[GUARD + MAXSZ + GUARD];
static uint8_t dst_arena[GUARD + 65535u + GUARD];
static ringbuf_t rb;
static unsigned cur_size;

static uint8_t sa[GUARD + 64u + GUARD], sb[GUARD + 4096u + GUARD];
static uint8_t ref_q[2][4096];
static uint8_t tmp[GUARD + 128u + GUARD];

static int store_guards_ok(const uint8_t *arena, unsigned size)
{
    for (unsigned i = 0; i < GUARD; i++)
        if (arena[i] != STORE_CANARY || arena[GUARD + size + i] != STORE_CANARY) return 0;
    return 1;
}

static void stress(unsigned nops, uint32_t x)
{
    ringbuf_t r[2];
    uint8_t *arena[2] = { sa, sb };
    unsigned sz[2] = { 64u, 4096u };
    unsigned rhead[2] = {0, 0}, rcount[2] = {0, 0};
    uint8_t seq[2] = {0, 0};
    unsigned long long moved = 0;
    for (int k = 0; k < 2; k++) {
        memset(arena[k], STORE_CANARY, GUARD + sz[k] + GUARD);
        memset(&r[k], 0xA5, sizeof r[k]);
        rb_init(&r[k], arena[k] + GUARD, (uint16_t)sz[k]);
    }
    for (unsigned op = 0; op < nops; op++) {
        x = x * 1103515245u + 12345u;
        int k = (int)((x >> 8) & 1u);
        unsigned action = (x >> 9) % 8u;
        unsigned burst = (x >> 16) % 70u;
        if (action < 4) {                                   /* producer burst */
            for (unsigned i = 0; i < burst; i++) {
                bool want = rcount[k] < sz[k];
                bool got = rb_put(&r[k], seq[k]);
                if (got != want) {
                    printf("stress MISMATCH op %u: rb_put returned %d, expected %d (count %u of %u)\n", op, got, want, rcount[k], sz[k]);
                    return;
                }
                if (want) {
                    ref_q[k][(rhead[k] + rcount[k]) % sz[k]] = seq[k];
                    rcount[k]++;
                    moved++;
                }
                seq[k]++;
            }
        } else if (action < 7) {                            /* consumer, byte by byte */
            for (unsigned i = 0; i < burst; i++) {
                uint8_t b = 0x5A;
                bool got = rb_get(&r[k], &b);
                if (got != (rcount[k] > 0)) {
                    printf("stress MISMATCH op %u: rb_get returned %d with %u bytes stored\n", op, got, rcount[k]);
                    return;
                }
                if (!got) break;
                uint8_t want = ref_q[k][rhead[k]];
                if (b != want) {
                    printf("stress MISMATCH op %u: rb_get gave %02X, expected %02X\n", op, b, want);
                    return;
                }
                rhead[k] = (rhead[k] + 1u) % sz[k];
                rcount[k]--;
            }
        } else {                                            /* consumer, bulk */
            memset(tmp, DST_CANARY, sizeof tmp);
            uint16_t got = rb_read(&r[k], tmp + GUARD, (uint16_t)burst);
            unsigned want = rcount[k] < burst ? rcount[k] : burst;
            if (got != want) {
                printf("stress MISMATCH op %u: rb_read returned %u, expected %u\n", op, (unsigned)got, want);
                return;
            }
            for (unsigned i = 0; i < GUARD; i++) {
                if (tmp[i] != DST_CANARY || tmp[GUARD + burst + i] != DST_CANARY) {
                    printf("OUT OF BOUNDS WRITE in rb_read\n");
                    return;
                }
            }
            for (unsigned i = 0; i < want; i++) {
                if (tmp[GUARD + i] != ref_q[k][rhead[k]]) {
                    printf("stress MISMATCH op %u: rb_read byte %u is %02X, expected %02X\n", op, i, tmp[GUARD + i], ref_q[k][rhead[k]]);
                    return;
                }
                rhead[k] = (rhead[k] + 1u) % sz[k];
                rcount[k]--;
            }
        }
        if (rb_count(&r[k]) != rcount[k]) {
            printf("stress MISMATCH op %u: rb_count %u, expected %u\n", op, (unsigned)rb_count(&r[k]), rcount[k]);
            return;
        }
        if (!store_guards_ok(arena[k], sz[k])) {
            printf("OUT OF BOUNDS WRITE\n");
            return;
        }
    }
    printf("stress OK moved %llu bytes, left %u %u\n", moved, rcount[0], rcount[1]);
}

int main(void)
{
    char cmd[8];
    while (scanf("%7s", cmd) == 1) {
        unsigned a1 = 0, a2 = 0;
        if (cmd[0] == 'I') {
            if (scanf("%u", &a1) != 1 || a1 < 1u || a1 > MAXSZ || (a1 & (a1 - 1u)) != 0u) return 0;
            memset(store, STORE_CANARY, sizeof store);
            memset(store + GUARD, 0x77, a1);                 /* storage content is garbage */
            memset(&rb, 0xA5, sizeof rb);                    /* so is the struct */
            rb_init(&rb, store + GUARD, (uint16_t)a1);
            cur_size = a1;
            printf("init %u\n", a1);
        } else if (cmd[0] == 'P') {
            if (scanf("%u %u", &a1, &a2) != 2) return 0;
            unsigned ok = 0;
            for (unsigned i = 0; i < a1; i++)
                if (rb_put(&rb, (uint8_t)(a2 + i))) ok++;
            printf("put %u/%u\n", ok, a1);
        } else if (cmd[0] == 'G') {
            if (scanf("%u", &a1) != 1) return 0;
            printf("get:");
            for (unsigned i = 0; i < a1; i++) {
                uint8_t b = 0xEE;
                if (rb_get(&rb, &b)) {
                    printf(" %02X", b);
                } else {
                    fputs(b == 0xEE ? " empty" : " empty(byte written!)", stdout);
                    break;
                }
            }
            printf("\n");
        } else if (cmd[0] == 'R') {
            if (scanf("%u", &a1) != 1 || a1 > 65535u) return 0;
            memset(dst_arena, DST_CANARY, sizeof dst_arena);
            uint8_t *dst = dst_arena + GUARD;
            unsigned k = rb_read(&rb, dst, (uint16_t)a1);
            int oob = 0;
            for (unsigned i = 0; i < GUARD; i++)
                if (dst_arena[i] != DST_CANARY) oob = 1;
            for (unsigned i = k; i < a1 + GUARD; i++)
                if (dst[i] != DST_CANARY) oob = 1;
            if (k > a1 || oob) {
                printf("OUT OF BOUNDS WRITE in rb_read\n");
                return 0;
            }
            if (k == 0) {
                printf("read 0\n");
            } else if (k <= 32u) {
                printf("read %u:", k);
                for (unsigned i = 0; i < k; i++) printf(" %02X", dst[i]);
                printf("\n");
            } else {
                unsigned sum = 0;
                for (unsigned i = 0; i < k; i++) sum += dst[i];
                printf("read %u first=%02X last=%02X sum=%u\n", k, dst[0], dst[k - 1], sum);
            }
        } else if (cmd[0] == 'C') {
            unsigned c = rb_count(&rb);
            printf("count %u free %u\n", c, cur_size - c);
        } else if (cmd[0] == 'S') {
            if (scanf("%u %u", &a1, &a2) != 2) return 0;
            stress(a1, a2);
        } else {
            return 0;
        }
        if (cur_size && !store_guards_ok(store, cur_size)) {
            printf("OUT OF BOUNDS WRITE\n");
            return 0;
        }
    }
    return 0;
}
@@@ sample_input
I 8
P 5 1
C
G 3
P 6 100
C
G 10
@@@ sample_output
init 8
put 5/5
count 5 free 3
get: 01 02 03
put 6/6
count 8 free 0
get: 04 05 64 65 66 67 68 69 empty

@@@ sample_input
I 4
P 6 200
R 3
R 10
G 1
@@@ sample_output
init 4
put 4/6
read 3: C8 C9 CA
read 1: CB
get: empty

@@@ hidden_input
I 1
P 2 7
C
G 2
C
@@@ hidden_output
init 1
put 1/2
count 1 free 0
get: 07 empty
count 0 free 1

@@@ hidden_input
I 16
G 1
R 0
R 5
C
P 16 250
R 16
@@@ hidden_output
init 16
get: empty
read 0
read 0
count 0 free 16
put 16/16
read 16: FA FB FC FD FE FF 00 01 02 03 04 05 06 07 08 09

@@@ hidden_input
I 8
P 6 0
G 5
P 6 16
C
P 1 99
R 7
C
@@@ hidden_output
init 8
put 6/6
get: 00 01 02 03 04
put 6/6
count 7 free 1
put 1/1
read 7: 05 10 11 12 13 14 15
count 1 free 7

@@@ hidden_input
I 32768
P 32768 0
P 1 0
C
R 30000
P 30000 5
C
R 65535
C
P 5000 9
R 5000
C
P 32768 3
P 1 1
C
@@@ hidden_output
init 32768
put 32768/32768
put 0/1
count 32768 free 0
read 30000 first=00 last=2F sum=3820008
put 30000/30000
count 32768 free 0
read 32768 first=30 last=34 sum=4178160
count 0 free 32768
put 5000/5000
read 5000 first=09 last=90 sum=630564
count 0 free 32768
put 32768/32768
put 0/1
count 32768 free 0

@@@ hidden_input
S 100000 1
@@@ hidden_output
stress OK moved 1350955 bytes, left 0 2212

@@@ hidden_input
S 60000 77
@@@ hidden_output
stress OK moved 811302 bytes, left 45 2873

@@@ hint
Let the indices run freely: increment `head` on every put and `tail` on every get, and never reduce them modulo `size`. Then `head - tail` is the number of stored bytes, and the physical slot is `index & (size - 1)`. Empty means `head == tail`, full means `head - tail == size`. No slot is wasted.
@@@ hint
`uint16_t` operands are promoted to `int` before the subtraction, so `head - tail` can be **negative** after `head` wraps (`2 - 65534 = -65532`). Cast the difference back: `(uint16_t)(head - tail)`. That is arithmetic modulo 65 536, and it is exact because `size` divides 65 536. In `rb_read`, copy in at most two chunks: up to the physical end of the storage, then from slot 0.
@@@ solution_code
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <string.h>

void rb_init(ringbuf_t *rb, uint8_t *storage, uint16_t size)
{
    rb->buf = storage;
    rb->size = size;
    rb->head = 0;
    rb->tail = 0;
}

uint16_t rb_count(const ringbuf_t *rb)
{
    /* free-running indices: the difference modulo 2^16 is the fill level */
    return (uint16_t)(rb->head - rb->tail);
}

bool rb_put(ringbuf_t *rb, uint8_t byte)
{
    uint16_t head = rb->head;                       /* read the volatile index once */
    if ((uint16_t)(head - rb->tail) == rb->size)
        return false;                               /* full: overrun, drop the byte */
    rb->buf[head & (uint16_t)(rb->size - 1u)] = byte;
    rb->head = (uint16_t)(head + 1u);               /* publish only after the data is stored */
    return true;
}

bool rb_get(ringbuf_t *rb, uint8_t *byte)
{
    uint16_t tail = rb->tail;
    if (rb->head == tail)
        return false;                               /* empty */
    *byte = rb->buf[tail & (uint16_t)(rb->size - 1u)];
    rb->tail = (uint16_t)(tail + 1u);               /* free the slot only after reading it */
    return true;
}

uint16_t rb_read(ringbuf_t *rb, uint8_t *dst, uint16_t max)
{
    uint16_t tail = rb->tail;
    uint16_t avail = (uint16_t)(rb->head - tail);   /* snapshot: the ISR may add more meanwhile */
    uint16_t n = avail < max ? avail : max;
    if (n == 0)
        return 0;

    uint16_t mask = (uint16_t)(rb->size - 1u);
    uint16_t pos = (uint16_t)(tail & mask);
    uint16_t first = (uint16_t)(rb->size - pos);    /* bytes before the physical end */
    if (first > n)
        first = n;

    memcpy(dst, &rb->buf[pos], first);              /* chunk 1: pos .. end */
    memcpy(dst + first, &rb->buf[0], (size_t)(n - first));  /* chunk 2: wrapped part */
    rb->tail = (uint16_t)(tail + n);
    return n;
}
@@@ explanation_md
**Approach: free-running indices.** `head` counts every byte ever written and `tail` every byte ever read, both modulo 2^16. Then:

| quantity | expression |
|---|---|
| fill level | `(uint16_t)(head - tail)` |
| empty | `head == tail` |
| full | `(uint16_t)(head - tail) == size` |
| physical slot | `index & (size - 1)` |

Because `size` is a power of two that divides 65 536, the mapping `index & (size-1)` stays continuous when the 16-bit counters wrap, and the unsigned difference is exact as long as the fill level never exceeds 65 535. That gives the full capacity of `size` bytes without a `count` variable or a wasted slot.

**Why no count variable?** `count++` in the ISR and `count--` in the main loop are both read-modify-write sequences. If the ISR fires between the main loop's load and store, one update is lost. Fixing that needs a critical section, which adds interrupt latency. With split ownership (the ISR writes only `head`, the main loop writes only `tail`), every shared variable has exactly one writer. On a single core, with aligned 16-bit stores that are atomic, this is safe without locking.

**Ordering.** Write the data *before* publishing the new `head`, and read the data *before* publishing the new `tail`. `volatile` stops the compiler from caching or reordering the index accesses relative to each other. On a multi-core or weakly ordered CPU you would also need memory barriers (C11 `atomic_store_explicit(..., memory_order_release)`).

**Complexity.** `put`, `get`, `count`: O(1). `rb_read`: O(k), done as at most two `memcpy` calls. Space: `size` bytes plus two indices.

**Common mistakes**
- `if (rb->head - rb->tail == rb->size)`. Both operands are promoted to `int`, and after `head` wraps the difference is negative, so the FIFO never reports full and overwrites unread data. The `(uint16_t)` cast is essential.
- Reducing the indices with `% size` on every increment and then testing `head == tail`. Full and empty become indistinguishable. Classic fixes cost a slot or a flag; free-running indices cost nothing.
- Using `% size` with a size that is not a power of two together with free-running indices. The mapping jumps when the counter wraps at 65 536.
- Incrementing `head` before storing the byte. The main loop can then read a slot that has not been written yet.
- In `rb_read`, a single `memcpy` that runs past the physical end of the storage (the guard bytes catch it).

**Interview follow-ups**
- Make the buffer size arbitrary (not a power of two). (Indices wrap at `2 * size`, or keep one slot empty with `% size`.)
- Where exactly do you need a critical section if a **second** producer (e.g. a DMA half-transfer callback) is added?
- Replace the byte-wise ISR with DMA in circular mode: how do you compute `head` from the DMA's NDTR / remaining-count register?
- The ISR drops bytes when the buffer is full. How would you report the overrun to the application without a shared counter? (A producer-owned `overruns` counter that only the ISR increments.)
