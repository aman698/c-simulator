@@@ meta
id: STC-H-05
topic: Structures
difficulty: Hard
type: FUNCTION
title: Bounded TX Priority Queue with FIFO Ties and Eviction
tags: embedded, priority-queue, binary-heap, array-of-structs, static-memory, can-bus
@@@ statement_md
A CAN transmit scheduler buffers outgoing messages in a **fixed-capacity priority queue** (no `malloc`, as on a real ECU). Implement it:

```c
#define PQ_MAX 64

struct Msg {                 /* defined by the judge */
    uint32_t can_id;
    uint8_t  prio;           /* 0 = most urgent, 255 = least urgent */
    uint8_t  dlc;
    uint8_t  data[8];
};

struct MsgQueue;             /* YOU define the complete type */

void   pq_init(struct MsgQueue *q, size_t cap);                          /* 1 <= cap <= PQ_MAX */
int    pq_push(struct MsgQueue *q, const struct Msg *m, struct Msg *evicted);
int    pq_pop(struct MsgQueue *q, struct Msg *out);
size_t pq_count(const struct MsgQueue *q);
```

**Ordering.** `pq_pop` removes the message with the **smallest `prio`**. Messages with equal `prio` leave in **arrival order** (FIFO). Arrival order is the order of the successful `pq_push` calls.

**`pq_push`**
- If the queue has room: store a copy of `*m` and return `0`.
- If it is full, the **victim** is the message that would be popped **last**: the largest `prio`, and among those the most recently arrived. If `m->prio < victim.prio`, remove the victim, copy it to `*evicted`, store `*m` and return `1`. Otherwise return `-1` and drop `m`. A message never evicts one of equal priority.

**`pq_pop`** copies the next message to `*out` and returns `0`, or returns `-1` if the queue is empty.

`pq_init` may be called again to reset the queue. The harness declares `static struct MsgQueue q;`.

**Input (read by the hidden harness)**: one command per line.
- `INIT <cap>`
- `PUSH <id hex> <prio> <dlc> <dlc hex bytes>` prints `PUSH 0x<ID> -> OK`, `-> FULL` or `-> EVICT 0x<ID> p=<prio> [<dlc>] <bytes>`.
- `POP` prints `POP 0x<ID> p=<prio> [<dlc>] <bytes>` or `POP EMPTY`.
- `COUNT` prints `count=<n>`.
- `GEN <n> <seed>` runs `n` pseudo-random push/pop operations and prints one summary line with counters and a hash of every message that left the queue (popped or evicted), in order.

IDs are printed as `%03X`.

**Example**
```
Input:
INIT 2
PUSH 10 5 0
PUSH 11 5 0
PUSH 12 5 0
PUSH 13 2 1 AB
PUSH 14 7 0
COUNT
POP
POP

Output:
PUSH 0x010 -> OK
PUSH 0x011 -> OK
PUSH 0x012 -> FULL
PUSH 0x013 -> EVICT 0x011 p=5 [0]
PUSH 0x014 -> FULL
count=2
POP 0x013 p=2 [1] AB
POP 0x010 p=5 [0]
```
@@@ constraints_md
- `1 <= cap <= 64`; at most 200 commands; `GEN` performs at most 20000 operations.
- No dynamic allocation. The whole queue lives inside `struct MsgQueue`.
- Aim for O(log n) push/pop (a binary heap). O(n) per operation also passes for `cap <= 64`.
@@@ starter_code
#include <stdint.h>
#include <stddef.h>
#include <string.h>

/* Already defined by the judge:
 *
 * #define PQ_MAX 64
 * struct Msg { uint32_t can_id; uint8_t prio; uint8_t dlc; uint8_t data[8]; };
 */

struct MsgQueue {
    struct Msg slot[PQ_MAX];
    size_t     count;
    size_t     cap;
    /* TODO: whatever else you need (arrival counter, ...) */
};

void pq_init(struct MsgQueue *q, size_t cap)
{
    q->count = 0;
    q->cap = cap;
}

int pq_push(struct MsgQueue *q, const struct Msg *m, struct Msg *evicted)
{
    /* TODO */
    (void)q;
    (void)m;
    (void)evicted;
    return -1;
}

int pq_pop(struct MsgQueue *q, struct Msg *out)
{
    /* TODO */
    (void)q;
    (void)out;
    return -1;
}

size_t pq_count(const struct MsgQueue *q)
{
    return q->count;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>

#define PQ_MAX 64

struct Msg {
    uint32_t can_id;
    uint8_t  prio;
    uint8_t  dlc;
    uint8_t  data[8];
};

/*USER_CODE*/

static struct MsgQueue q;

static void print_msg(const struct Msg *m)
{
    printf("0x%03X p=%u [%u]", (unsigned)m->can_id, (unsigned)m->prio, (unsigned)m->dlc);
    for (int i = 0; i < m->dlc && i < 8; i++) printf(" %02X", (unsigned)m->data[i]);
}

static uint32_t hash_msg(uint32_t h, const struct Msg *m)
{
    h = h * 31u + m->can_id * 256u + m->prio;
    for (int i = 0; i < m->dlc && i < 8; i++) h = h * 7u + m->data[i];
    return h;
}

int main(void)
{
    char cmd[8];
    pq_init(&q, PQ_MAX);
    while (scanf("%7s", cmd) == 1) {
        if (strcmp(cmd, "INIT") == 0) {
            unsigned cap;
            if (scanf("%u", &cap) != 1 || cap < 1 || cap > PQ_MAX) break;
            pq_init(&q, cap);
        } else if (strcmp(cmd, "PUSH") == 0) {
            struct Msg m, ev;
            unsigned id, prio, dlc;
            memset(&m, 0, sizeof m);
            if (scanf("%x %u %u", &id, &prio, &dlc) != 3 || dlc > 8) break;
            m.can_id = id; m.prio = (uint8_t)prio; m.dlc = (uint8_t)dlc;
            for (unsigned i = 0; i < dlc; i++) {
                unsigned b;
                if (scanf("%x", &b) != 1) return 0;
                m.data[i] = (uint8_t)b;
            }
            memset(&ev, 0xCC, sizeof ev);
            int r = pq_push(&q, &m, &ev);
            printf("PUSH 0x%03X -> ", id);
            if (r == 0) printf("OK\n");
            else if (r == -1) printf("FULL\n");
            else if (r == 1) { printf("EVICT "); print_msg(&ev); printf("\n"); }
            else printf("BAD RETURN %d\n", r);
        } else if (strcmp(cmd, "POP") == 0) {
            struct Msg out;
            memset(&out, 0xCC, sizeof out);
            if (pq_pop(&q, &out) == 0) { printf("POP "); print_msg(&out); printf("\n"); }
            else printf("POP EMPTY\n");
        } else if (strcmp(cmd, "COUNT") == 0) {
            printf("count=%u\n", (unsigned)pq_count(&q));
        } else if (strcmp(cmd, "GEN") == 0) {
            unsigned n, seed;
            if (scanf("%u %u", &n, &seed) != 2) break;
            uint32_t x = seed, h = 0;
            unsigned ok = 0, ev_n = 0, full = 0, pops = 0, empty = 0;
            for (unsigned k = 0; k < n; k++) {
                x = x * 1103515245u + 12345u;
                uint32_t r = x >> 8;
                if (r % 4 == 0) {
                    struct Msg out;
                    if (pq_pop(&q, &out) == 0) { pops++; h = hash_msg(h, &out); }
                    else empty++;
                } else {
                    struct Msg m, ev;
                    memset(&m, 0, sizeof m);
                    m.can_id = (r >> 3) % 0x800;
                    m.prio = (uint8_t)((r >> 14) % 8);
                    m.dlc = (uint8_t)((r >> 17) % 9);
                    for (int i = 0; i < m.dlc; i++) m.data[i] = (uint8_t)(r >> (i % 3));
                    int res = pq_push(&q, &m, &ev);
                    if (res == 0) ok++;
                    else if (res == 1) { ev_n++; h = hash_msg(h, &ev); }
                    else full++;
                }
            }
            printf("GEN ok=%u evict=%u full=%u pop=%u empty=%u hash=%08X\n", ok, ev_n, full, pops, empty, (unsigned)h);
        }
    }
    return 0;
}
@@@ sample_input
INIT 2
PUSH 10 5 0
PUSH 11 5 0
PUSH 12 5 0
PUSH 13 2 1 AB
PUSH 14 7 0
COUNT
POP
POP
@@@ sample_output
PUSH 0x010 -> OK
PUSH 0x011 -> OK
PUSH 0x012 -> FULL
PUSH 0x013 -> EVICT 0x011 p=5 [0]
PUSH 0x014 -> FULL
count=2
POP 0x013 p=2 [1] AB
POP 0x010 p=5 [0]

@@@ sample_input
INIT 4
PUSH 100 3 1 AA
PUSH 200 1 0
PUSH 300 3 2 01 02
PUSH 050 1 1 FF
POP
POP
POP
POP
POP
@@@ sample_output
PUSH 0x100 -> OK
PUSH 0x200 -> OK
PUSH 0x300 -> OK
PUSH 0x050 -> OK
POP 0x200 p=1 [0]
POP 0x050 p=1 [1] FF
POP 0x100 p=3 [1] AA
POP 0x300 p=3 [2] 01 02
POP EMPTY

@@@ hidden_input
INIT 1
POP
PUSH 1 0 0
PUSH 2 0 0
COUNT
POP
PUSH 3 255 8 01 02 03 04 05 06 07 08
PUSH 4 254 0
POP
POP
@@@ hidden_output
POP EMPTY
PUSH 0x001 -> OK
PUSH 0x002 -> FULL
count=1
POP 0x001 p=0 [0]
PUSH 0x003 -> OK
PUSH 0x004 -> EVICT 0x003 p=255 [8] 01 02 03 04 05 06 07 08
POP 0x004 p=254 [0]
POP EMPTY

@@@ hidden_input
INIT 8
PUSH 1 4 0
PUSH 2 4 0
POP
PUSH 3 4 0
PUSH 1 4 0
POP
POP
POP
POP
@@@ hidden_output
PUSH 0x001 -> OK
PUSH 0x002 -> OK
POP 0x001 p=4 [0]
PUSH 0x003 -> OK
PUSH 0x001 -> OK
POP 0x002 p=4 [0]
POP 0x003 p=4 [0]
POP 0x001 p=4 [0]
POP EMPTY

@@@ hidden_input
INIT 3
PUSH A 9 1 0A
PUSH B 9 1 0B
PUSH C 4 1 0C
PUSH D 1 1 0D
PUSH E 1 1 0E
PUSH F 1 1 0F
PUSH 7FF 1 0
COUNT
POP
POP
POP
POP
@@@ hidden_output
PUSH 0x00A -> OK
PUSH 0x00B -> OK
PUSH 0x00C -> OK
PUSH 0x00D -> EVICT 0x00B p=9 [1] 0B
PUSH 0x00E -> EVICT 0x00A p=9 [1] 0A
PUSH 0x00F -> EVICT 0x00C p=4 [1] 0C
PUSH 0x7FF -> FULL
count=3
POP 0x00D p=1 [1] 0D
POP 0x00E p=1 [1] 0E
POP 0x00F p=1 [1] 0F
POP EMPTY

@@@ hidden_input
INIT 5
PUSH 101 7 0
PUSH 102 3 0
PUSH 103 7 0
PUSH 104 0 0
PUSH 105 3 0
PUSH 106 3 0
PUSH 107 7 0
PUSH 108 2 0
POP
POP
POP
POP
POP
POP
@@@ hidden_output
PUSH 0x101 -> OK
PUSH 0x102 -> OK
PUSH 0x103 -> OK
PUSH 0x104 -> OK
PUSH 0x105 -> OK
PUSH 0x106 -> EVICT 0x103 p=7 [0]
PUSH 0x107 -> FULL
PUSH 0x108 -> EVICT 0x101 p=7 [0]
POP 0x104 p=0 [0]
POP 0x108 p=2 [0]
POP 0x102 p=3 [0]
POP 0x105 p=3 [0]
POP 0x106 p=3 [0]
POP EMPTY

@@@ hidden_input
INIT 64
GEN 20000 1
COUNT
INIT 5
GEN 5000 77
COUNT
@@@ hidden_output
GEN ok=5066 evict=4771 full=5158 pop=5004 empty=1 hash=3004BAFD
count=62
GEN ok=1244 evict=1067 full=1444 pop=1240 empty=5 hash=9B89A1BC
count=4

@@@ hidden_input
INIT 64
GEN 3000 12345
POP
POP
POP
INIT 2
POP
COUNT
@@@ hidden_output
GEN ok=816 evict=740 full=691 pop=753 empty=0 hash=B4360387
POP 0x15E p=1 [4] F5 7A BD F5
POP 0x00A p=1 [3] 55 2A 15
POP 0x07F p=1 [6] F9 FC FE F9 FC FE
POP EMPTY
count=0

@@@ hint
Store each message together with an arrival number: `struct Entry { struct Msg msg; uint32_t seq; }`. The key is the pair `(prio, seq)`, and smaller pops first. Equal priorities then come out FIFO automatically, even though a heap is not stable.
@@@ hint
In a min-heap the **largest** element is always a leaf (indices `count/2 .. count-1`), so the victim is found by scanning only the leaves. To remove it, move the last element into its slot, decrement `count`, then sift that element up (a leaf cannot need sifting down).
@@@ solution_code
#include <stdint.h>
#include <stddef.h>
#include <string.h>

struct PqEntry {
    struct Msg msg;
    uint32_t   seq;                 /* arrival order: FIFO tie-break */
};

struct MsgQueue {
    struct PqEntry heap[PQ_MAX];    /* binary min-heap on (prio, seq) */
    size_t   count;
    size_t   cap;
    uint32_t next_seq;
};

/* a before b?  smaller prio first, then earlier arrival */
static int before(const struct PqEntry *a, const struct PqEntry *b)
{
    if (a->msg.prio != b->msg.prio) return a->msg.prio < b->msg.prio;
    return a->seq < b->seq;
}

static void swap_e(struct PqEntry *a, struct PqEntry *b)
{
    struct PqEntry t = *a; *a = *b; *b = t;           /* struct assignment copies everything */
}

static void sift_up(struct MsgQueue *q, size_t i)
{
    while (i > 0) {
        size_t parent = (i - 1) / 2;
        if (!before(&q->heap[i], &q->heap[parent])) break;
        swap_e(&q->heap[i], &q->heap[parent]);
        i = parent;
    }
}

static void sift_down(struct MsgQueue *q, size_t i)
{
    for (;;) {
        size_t l = 2 * i + 1, r = l + 1, best = i;
        if (l < q->count && before(&q->heap[l], &q->heap[best])) best = l;
        if (r < q->count && before(&q->heap[r], &q->heap[best])) best = r;
        if (best == i) return;
        swap_e(&q->heap[i], &q->heap[best]);
        i = best;
    }
}

void pq_init(struct MsgQueue *q, size_t cap)
{
    q->count = 0;
    q->cap = cap > PQ_MAX ? PQ_MAX : cap;
    q->next_seq = 0;
}

int pq_push(struct MsgQueue *q, const struct Msg *m, struct Msg *evicted)
{
    int ret = 0;
    if (q->count == q->cap) {
        /* victim = maximum (prio, seq) = popped last; in a min-heap it is a leaf */
        size_t v = q->count / 2;
        for (size_t i = v + 1; i < q->count; i++)
            if (before(&q->heap[v], &q->heap[i])) v = i;
        if (!(m->prio < q->heap[v].msg.prio))
            return -1;                                 /* not more urgent: drop the newcomer */
        *evicted = q->heap[v].msg;
        q->heap[v] = q->heap[--q->count];              /* fill the hole with the last element */
        if (v < q->count) sift_up(q, v);               /* a leaf slot only ever needs to rise */
        ret = 1;
    }
    struct PqEntry *e = &q->heap[q->count];
    e->msg = *m;
    e->seq = q->next_seq++;
    sift_up(q, q->count++);
    return ret;
}

int pq_pop(struct MsgQueue *q, struct Msg *out)
{
    if (q->count == 0)
        return -1;
    *out = q->heap[0].msg;
    q->heap[0] = q->heap[--q->count];
    sift_down(q, 0);
    return 0;
}

size_t pq_count(const struct MsgQueue *q)
{
    return q->count;
}
@@@ explanation_md
**Approach.**
- **Total order.** A binary heap is not stable, so FIFO among equal priorities must be part of the key. Each entry carries an arrival counter `seq`, and the heap orders by `(prio, seq)`. This is the same trick RTOS ready queues and AUTOSAR ComM/PduR TX buffers use.
- **Push / pop.** These are the textbook heap operations on an array of structs, O(log n). Whole `struct Msg` objects are copied with plain assignment.
- **Eviction.** The element popped last is the maximum of `(prio, seq)`. In a min-heap the maximum is always a leaf, so you only scan `count/2 .. count-1`. Remove it by moving the last entry into the hole and sifting it up. Its new parent may be larger, but it has no children.
- **Policy.** A newcomer evicts only when it is **strictly** more urgent. Equal priority never evicts, because that would break FIFO fairness.

```
cap 3: A(9) B(9) C(4)    push D(1): victim = max(prio,seq) = B(9, newest) -> EVICT B
                         push E(1): victim = A(9)                         -> EVICT A
                         push F(1): victim = C(4)                         -> EVICT C
                         push 7FF(1): victim = F(1), 1 < 1 is false       -> FULL
```

**Complexity.** Push O(log n), plus O(n/2) for the leaf scan when the queue is full. Pop O(log n). Space O(cap), all static.

**Common mistakes**
- Ordering by `prio` only. The heap then shuffles equal-priority messages, and the CAN bus sees them out of order.
- Evicting the *oldest* lowest-priority message, or evicting on equal priority.
- Calling `sift_down` instead of `sift_up` after replacing an evicted leaf, which leaves a heap violation.
- Returning a pointer into the heap array instead of copying the message. The slot is overwritten by the next push.
- `uint8_t seq`. The counter wraps after 256 pushes and the FIFO order breaks.

**Interview follow-ups**
- `seq` is 32 bits and wraps after 4 billion messages. How do you compare sequence numbers wrap-safely, or renumber?
- CAN arbitration already prioritizes by ID. Why do drivers still need a priority-ordered **software** TX queue? (Priority inversion inside the 3 hardware mailboxes.)
- How would you make push/pop safe when a task pushes and the TX-complete ISR pops?
- For only 8 priority levels, what O(1) structure beats a heap? (8 FIFO rings plus a bitmap, then count-leading-zeros.)
