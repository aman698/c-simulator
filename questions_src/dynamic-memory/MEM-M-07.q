@@@ meta
id: MEM-M-07
topic: Dynamic Memory
difficulty: Medium
type: FIND_THE_BUG
title: Transmit Queue That Double-Frees Its Payloads
tags: embedded, double-free, shallow-copy, ownership-transfer, use-after-free, can-bus
@@@ statement_md
A diagnostic tester builds CAN messages with heap-allocated payloads and pushes them into a transmit queue of 16 slots. `queue_flush()` then "transmits" every queued message (prints it) and destroys it. Messages that do not fit into the queue are reported as dropped.

The program passes the developer's quick test, in which all messages had empty payloads. With real payloads, the judge reports **Runtime Error** (heap-use-after-free / double free), and on some machines the transmitted bytes are garbage. Find and fix the bug with a minimal change. Do not change the output format.

**Input**
- Line 1: `n`, the number of messages.
- Next `n` lines: `id len b1 ... blen` (identifier and bytes in hex, `len` in decimal).

**Output**
- For every message that does not fit (the queue already holds 16): `queue full, dropped 0x<ID>` (printed while pushing).
- Then, for every queued message in order: `TX 0x<ID> [<len>]` followed by ` <byte>` for each payload byte (`%02X`).

**Example**
```
Input:
3
123 3 01 02 03
7DF 2 02 10
456 0

Output:
TX 0x123 [3] 01 02 03
TX 0x7DF [2] 02 10
TX 0x456 [0]
```
@@@ constraints_md
- `0 <= n <= 40`, `0 <= len <= 8`, identifiers `0..0x1FFFFFFF`.
- Every payload must be freed exactly once, including those of dropped messages.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>

#define QUEUE_SLOTS 16

struct msg {
    unsigned int id;
    size_t len;
    unsigned char *payload;   /* heap block of len bytes, NULL when len == 0 */
};

struct queue {
    struct msg items[QUEUE_SLOTS];
    int count;
};

static int msg_init(struct msg *m, unsigned int id, size_t len)
{
    m->id = id;
    m->len = len;
    m->payload = NULL;
    if (len > 0) {
        m->payload = malloc(len);
        if (m->payload == NULL)
            return -1;
    }
    return 0;
}

static void msg_destroy(struct msg *m)
{
    free(m->payload);
    m->payload = NULL;
    m->len = 0;
}

/* Copies the message into the queue. On success the queue owns the payload. */
static int queue_push(struct queue *q, const struct msg *m)
{
    if (q->count == QUEUE_SLOTS)
        return -1;
    q->items[q->count++] = *m;
    return 0;
}

static void queue_flush(struct queue *q)
{
    for (int i = 0; i < q->count; i++) {
        struct msg *m = &q->items[i];
        printf("TX 0x%X [%zu]", m->id, m->len);
        for (size_t k = 0; k < m->len; k++)
            printf(" %02X", m->payload[k]);
        printf("\n");
        msg_destroy(m);
    }
    q->count = 0;
}

int main(void)
{
    struct queue q = { .count = 0 };
    int n;
    if (scanf("%d", &n) != 1)
        return 0;

    for (int i = 0; i < n; i++) {
        unsigned int id, len;
        if (scanf("%x %u", &id, &len) != 2)
            break;
        struct msg m;
        if (msg_init(&m, id, len) != 0)
            return 1;
        for (unsigned int k = 0; k < len; k++) {
            unsigned int b;
            if (scanf("%x", &b) != 1)
                b = 0;
            m.payload[k] = (unsigned char)b;
        }

        if (queue_push(&q, &m) != 0)
            printf("queue full, dropped 0x%X\n", id);
        msg_destroy(&m);              /* local copy is no longer needed */
    }

    queue_flush(&q);
    return 0;
}
@@@ sample_input
3
123 3 01 02 03
7DF 2 02 10
456 0
@@@ sample_output
TX 0x123 [3] 01 02 03
TX 0x7DF [2] 02 10
TX 0x456 [0]

@@@ sample_input
2
100 0
101 0
@@@ sample_output
TX 0x100 [0]
TX 0x101 [0]

@@@ hidden_input
0
@@@ hidden_output

@@@ hidden_input
1
18DAF110 8 02 10 03 AA BB CC DD EE
@@@ hidden_output
TX 0x18DAF110 [8] 02 10 03 AA BB CC DD EE

@@@ hidden_input
18
1 1 01
2 1 02
3 1 03
4 1 04
5 1 05
6 1 06
7 1 07
8 1 08
9 1 09
A 1 0A
B 1 0B
C 1 0C
D 1 0D
E 1 0E
F 1 0F
10 1 10
11 2 FF FF
12 0
@@@ hidden_output
queue full, dropped 0x11
queue full, dropped 0x12
TX 0x1 [1] 01
TX 0x2 [1] 02
TX 0x3 [1] 03
TX 0x4 [1] 04
TX 0x5 [1] 05
TX 0x6 [1] 06
TX 0x7 [1] 07
TX 0x8 [1] 08
TX 0x9 [1] 09
TX 0xA [1] 0A
TX 0xB [1] 0B
TX 0xC [1] 0C
TX 0xD [1] 0D
TX 0xE [1] 0E
TX 0xF [1] 0F
TX 0x10 [1] 10

@@@ hidden_input
3
7E0 0
7E0 2 3E 00
7E8 0
@@@ hidden_output
TX 0x7E0 [0]
TX 0x7E0 [2] 3E 00
TX 0x7E8 [0]

@@@ hidden_input
2
0 8 00 00 00 00 00 00 00 00
1FFFFFFF 8 FF FF FF FF FF FF FF FF
@@@ hidden_output
TX 0x0 [8] 00 00 00 00 00 00 00 00
TX 0x1FFFFFFF [8] FF FF FF FF FF FF FF FF

@@@ hint
`q->items[q->count++] = *m;` copies the struct, meaning three fields, one of which is a **pointer**. After the push, how many `struct msg` objects point at the same payload block, and how many times will that block be freed?
@@@ hint
The comment on `queue_push` gives it away: on success the **queue** owns the payload. The local `m` must only be destroyed when the push **failed** (the message was dropped). Otherwise `main` frees the block that `queue_flush` later prints and frees again.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>

#define QUEUE_SLOTS 16

struct msg {
    unsigned int id;
    size_t len;
    unsigned char *payload;   /* heap block of len bytes, NULL when len == 0 */
};

struct queue {
    struct msg items[QUEUE_SLOTS];
    int count;
};

static int msg_init(struct msg *m, unsigned int id, size_t len)
{
    m->id = id;
    m->len = len;
    m->payload = NULL;
    if (len > 0) {
        m->payload = malloc(len);
        if (m->payload == NULL)
            return -1;
    }
    return 0;
}

static void msg_destroy(struct msg *m)
{
    free(m->payload);
    m->payload = NULL;
    m->len = 0;
}

/* Copies the message into the queue. On success the queue owns the payload. */
static int queue_push(struct queue *q, const struct msg *m)
{
    if (q->count == QUEUE_SLOTS)
        return -1;
    q->items[q->count++] = *m;
    return 0;
}

static void queue_flush(struct queue *q)
{
    for (int i = 0; i < q->count; i++) {
        struct msg *m = &q->items[i];
        printf("TX 0x%X [%zu]", m->id, m->len);
        for (size_t k = 0; k < m->len; k++)
            printf(" %02X", m->payload[k]);
        printf("\n");
        msg_destroy(m);
    }
    q->count = 0;
}

int main(void)
{
    struct queue q = { .count = 0 };
    int n;
    if (scanf("%d", &n) != 1)
        return 0;

    for (int i = 0; i < n; i++) {
        unsigned int id, len;
        if (scanf("%x %u", &id, &len) != 2)
            break;
        struct msg m;
        if (msg_init(&m, id, len) != 0)
            return 1;
        for (unsigned int k = 0; k < len; k++) {
            unsigned int b;
            if (scanf("%x", &b) != 1)
                b = 0;
            m.payload[k] = (unsigned char)b;
        }

        if (queue_push(&q, &m) != 0) {
            printf("queue full, dropped 0x%X\n", id);
            msg_destroy(&m);          /* FIX: only a DROPPED message is still ours; a queued one belongs to the queue */
        }
    }

    queue_flush(&q);
    return 0;
}
@@@ explanation_md
**Bug.** Struct assignment is a **shallow copy**. After `q->items[i] = *m`, the queue slot and the local `m` hold the same `payload` pointer. `main` then calls `msg_destroy(&m)` unconditionally, which frees the block the queue still points to. Later `queue_flush` reads that freed block (use-after-free, often garbage bytes) and frees it **again** (double free). Messages with `len = 0` have `payload == NULL`, and `free(NULL)` is harmless. That is why the developer's empty-payload test passed.

```
after push:   m.payload ──┐
                          ├──► [01 02 03]   one block, two owners
q.items[0].payload ───────┘
msg_destroy(&m): block freed, q.items[0].payload dangles
queue_flush: prints freed bytes, then free() #2 -> double free
```

**Fix.** Make the ownership rule explicit and follow it: on success the queue owns the payload, so the caller must not free it. Destroy the local message only when the push fails (the dropped-message path, which must still free its payload). A stronger API is "move" semantics: `queue_push(struct queue *q, struct msg *m)` sets `m->payload = NULL` after copying, so destroying the source later is harmless.

**Complexity.** O(n * len) time; O(16 * 8) payload memory at most in the queue.

**Common mistakes**
- "Fixing" it by removing `msg_destroy` from `main` entirely, which leaks the payloads of **dropped** messages (the 18-message test).
- Deep-copying the payload in `queue_push` and keeping the unconditional destroy. That is correct, but costs an extra allocation per frame for no reason.
- Thinking `m->payload = NULL` inside `msg_destroy` protects the queue's copy. It only clears **that** struct's copy of the pointer.

**Interview follow-ups**
- Write `queue_push` with move semantics (`struct msg *m`, non-const). How does the type signature document the ownership transfer?
- When is a deep copy the right design instead? (When the producer must keep using its message, e.g. periodic retransmission.)
- On a bare-metal ECU, CAN payloads are at most 8 bytes (64 for CAN FD). Why is `unsigned char payload[8]` **inside** the struct much better than a heap pointer here? (Copying the struct then copies the data; no ownership questions.)
