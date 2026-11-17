@@@ meta
id: MEM-H-05
topic: Dynamic Memory
difficulty: Hard
type: FUNCTION
title: Reference-Counted Packet Buffer Chains (lwIP pbuf Style)
tags: embedded, reference-counting, flexible-array-member, linked-list, networking, ownership
@@@ statement_md
Embedded TCP/IP stacks (lwIP, used on many automotive gateways and telematics units) pass packets around as **chains of reference-counted buffers**. A protocol layer can hold on to a buffer (for example, the TCP retransmission queue) while another layer has already "freed" it. Implement the core of that design:

```c
struct pbuf {
    struct pbuf *next;     /* next buffer of the chain; the chain holds a reference to it */
    uint16_t len;          /* payload bytes in THIS buffer */
    uint16_t ref;          /* reference count */
    uint8_t payload[];     /* flexible array member */
};

struct pbuf *pbuf_alloc(uint16_t len);
void     pbuf_ref(struct pbuf *p);
void     pbuf_chain(struct pbuf *head, struct pbuf *tail);
int      pbuf_free(struct pbuf *p);
uint32_t pbuf_tot_len(const struct pbuf *p);
uint16_t pbuf_copy_partial(const struct pbuf *p, void *dst, uint16_t len, uint16_t offset);
```

- `pbuf_alloc(len)`: **one** `malloc` for header + `len` payload bytes (`len` may be 0). Set `ref = 1`, `next = NULL` and zero the payload. Return `NULL` if allocation fails.
- `pbuf_ref(p)`: `p->ref++`. `NULL` is a no-op.
- `pbuf_chain(head, tail)`: append `tail` after the **last** buffer of `head`'s chain, and take a **new reference** to `tail` (`tail->ref++`), because the chain now points to it. The caller keeps its own reference and releases it later with `pbuf_free(tail)`.
- `pbuf_free(p)`: drop one reference to `p`. If its count reaches 0, free it **and** drop the reference it held on `p->next`, repeating down the chain. Stop at the first buffer whose count stays above 0. Return the number of buffers actually freed. `pbuf_free(NULL)` returns 0. Chains can be thousands of buffers long, so do not recurse.
- `pbuf_tot_len(p)`: sum of `len` over the chain starting at `p`.
- `pbuf_copy_partial(p, dst, len, offset)`: skip `offset` payload bytes of the chain, copy up to `len` bytes into `dst`, and return the number copied. (The bytes are spread over several buffers.)

**Input (read by the hidden harness)**, one operation per line; allocated buffers get handles 1, 2, 3, ...:
- `A <len>`: allocate. The harness fills byte `i` of handle `k` with `k*16 + i`, and prints `A#k len=<len> ref=<ref>`.
- `R <k>`: prints `ref #k -> <ref>`. `C <a> <b>`: prints `chain #a + #b -> tot=<tot_len(a)> ref#b=<ref>`.
- `F <k>`: prints `free #k -> <n> freed`. `N`: `pbuf_free(NULL)`. `T <k>`: prints `tot #k = <n>`.
- `X <k> <off> <n>`: prints `copy #k off=<off> n=<n> -> <copied>` plus the bytes in hex.
- `G <n> <seed>`: builds one chain of `n` random buffers and frees it (summary line).

The scripts never touch a buffer after its last reference is gone, and they always release every reference, so any leak is your bug.

**Example**
```
Input:
A 4
A 3
C 1 2
F 2
T 1
X 1 2 4
F 1

Output:
A#1 len=4 ref=1
A#2 len=3 ref=1
chain #1 + #2 -> tot=7 ref#2=2
free #2 -> 0 freed
tot #1 = 7
copy #1 off=2 n=4 -> 4 12 13 20 21
free #1 -> 2 freed
```
@@@ constraints_md
- `0 <= len <= 1500`, at most 5000 buffers per test, chains up to 5000 buffers.
- Reference counts stay below 1000.
- Use `malloc`/`free`. Exactly one allocation per buffer. Leak checking is on.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

struct pbuf {
    struct pbuf *next;
    uint16_t len;
    uint16_t ref;
    uint8_t payload[];
};

struct pbuf *pbuf_alloc(uint16_t len)
{
    /* TODO: one allocation: header + len payload bytes */
    return NULL;
}

void pbuf_ref(struct pbuf *p)
{
    /* TODO */
}

void pbuf_chain(struct pbuf *head, struct pbuf *tail)
{
    /* TODO */
}

int pbuf_free(struct pbuf *p)
{
    /* TODO: iterative, stop at the first buffer that is still referenced */
    return 0;
}

uint32_t pbuf_tot_len(const struct pbuf *p)
{
    /* TODO */
    return 0;
}

uint16_t pbuf_copy_partial(const struct pbuf *p, void *dst, uint16_t len, uint16_t offset)
{
    /* TODO */
    return 0;
}
@@@ harness_code
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*USER_CODE*/

#define MAXH 6000
static struct pbuf *h[MAXH + 1];
static int nh;

static struct pbuf *new_handle(uint16_t len)
{
    struct pbuf *p = pbuf_alloc(len);
    if (p == NULL || nh >= MAXH)
        return NULL;
    h[++nh] = p;
    if (p->len != len || p->ref != 1 || p->next != NULL)
        printf("FAIL: bad fresh pbuf\n");
    for (uint16_t i = 0; i < len; i++) {
        if (p->payload[i] != 0)
            printf("FAIL: payload not zeroed\n");
        p->payload[i] = (uint8_t)(nh * 16 + i);
    }
    return p;
}

static int handle(void)
{
    int k;
    if (scanf("%d", &k) != 1 || k < 1 || k > nh)
        return 0;
    return k;
}

int main(void)
{
    static uint8_t buf[70000];
    char op[4];
    while (scanf("%3s", op) == 1) {
        if (op[0] == 'A') {
            unsigned int len;
            if (scanf("%u", &len) != 1)
                break;
            struct pbuf *p = new_handle((uint16_t)len);
            if (p == NULL) {
                printf("A -> NULL\n");
                continue;
            }
            printf("A#%d len=%u ref=%u\n", nh, (unsigned int)p->len, (unsigned int)p->ref);
        } else if (op[0] == 'R') {
            int k = handle();
            if (!k)
                break;
            pbuf_ref(h[k]);
            printf("ref #%d -> %u\n", k, (unsigned int)h[k]->ref);
        } else if (op[0] == 'C') {
            int a = handle();
            int b = handle();
            if (!a || !b)
                break;
            pbuf_chain(h[a], h[b]);
            printf("chain #%d + #%d -> tot=%u ref#%d=%u\n", a, b, (unsigned int)pbuf_tot_len(h[a]), b,
                   (unsigned int)h[b]->ref);
        } else if (op[0] == 'F') {
            int k = handle();
            if (!k)
                break;
            printf("free #%d -> %d freed\n", k, pbuf_free(h[k]));
        } else if (op[0] == 'N') {
            pbuf_ref(NULL);
            printf("free NULL -> %d freed\n", pbuf_free(NULL));
        } else if (op[0] == 'T') {
            int k = handle();
            if (!k)
                break;
            printf("tot #%d = %u\n", k, (unsigned int)pbuf_tot_len(h[k]));
        } else if (op[0] == 'X') {
            int k = handle();
            unsigned int off, n;
            if (!k || scanf("%u %u", &off, &n) != 2 || n > sizeof buf)
                break;
            memset(buf, 0xEE, sizeof buf);
            uint16_t got = pbuf_copy_partial(h[k], buf, (uint16_t)n, (uint16_t)off);
            printf("copy #%d off=%u n=%u -> %u", k, off, n, (unsigned int)got);
            if (got > n || buf[got] != 0xEE)
                printf(" FAIL: wrote past the copied bytes");
            for (unsigned int i = 0; i < got && i < 64; i++)
                printf(" %02X", buf[i]);
            printf("\n");
        } else if (op[0] == 'G') {
            int n;
            unsigned int seed;
            if (scanf("%d %u", &n, &seed) != 2 || n < 1 || nh + n > MAXH)
                break;
            int first = nh + 1;
            for (int i = 0; i < n; i++) {
                seed = seed * 1103515245u + 12345u;
                if (new_handle((uint16_t)((seed >> 16) % 40u)) == NULL)
                    return 1;
                if (i > 0) {
                    pbuf_chain(h[first], h[nh]);
                    pbuf_free(h[nh]);            /* drop the creator's reference */
                }
            }
            uint32_t tot = pbuf_tot_len(h[first]);
            uint32_t sum = 0;
            uint16_t off = 0;
            for (;;) {
                uint16_t got = pbuf_copy_partial(h[first], buf, 1000, off);
                if (got == 0)
                    break;
                for (uint16_t i = 0; i < got; i++)
                    sum = sum * 31u + buf[i];
                if ((uint32_t)off + got > 65535u)
                    break;
                off = (uint16_t)(off + got);
            }
            int freed = pbuf_free(h[first]);
            printf("G n=%d tot=%u sum=%u freed=%d\n", n, (unsigned int)tot, (unsigned int)sum, freed);
        }
    }
    return 0;
}
@@@ sample_input
A 4
A 3
C 1 2
F 2
T 1
X 1 2 4
F 1
@@@ sample_output
A#1 len=4 ref=1
A#2 len=3 ref=1
chain #1 + #2 -> tot=7 ref#2=2
free #2 -> 0 freed
tot #1 = 7
copy #1 off=2 n=4 -> 4 12 13 20 21
free #1 -> 2 freed

@@@ sample_input
A 2
A 2
A 2
C 1 3
C 2 3
R 3
F 3
F 1
F 2
F 3
@@@ sample_output
A#1 len=2 ref=1
A#2 len=2 ref=1
A#3 len=2 ref=1
chain #1 + #3 -> tot=4 ref#3=2
chain #2 + #3 -> tot=4 ref#3=3
ref #3 -> 4
free #3 -> 0 freed
free #1 -> 1 freed
free #2 -> 1 freed
free #3 -> 1 freed

@@@ hidden_input
A 0
A 5
C 1 2
F 2
X 1 0 10
X 1 5 3
X 1 6 1
T 1
F 1
N
@@@ hidden_output
A#1 len=0 ref=1
A#2 len=5 ref=1
chain #1 + #2 -> tot=5 ref#2=2
free #2 -> 0 freed
copy #1 off=0 n=10 -> 5 20 21 22 23 24
copy #1 off=5 n=3 -> 0
copy #1 off=6 n=1 -> 0
tot #1 = 5
free #1 -> 2 freed
free NULL -> 0 freed

@@@ hidden_input
A 1
A 1
A 1
A 1
A 1
C 1 2
C 1 3
C 1 4
C 1 5
F 2
F 3
F 4
F 5
T 1
X 1 1 3
R 3
F 1
F 3
@@@ hidden_output
A#1 len=1 ref=1
A#2 len=1 ref=1
A#3 len=1 ref=1
A#4 len=1 ref=1
A#5 len=1 ref=1
chain #1 + #2 -> tot=2 ref#2=2
chain #1 + #3 -> tot=3 ref#3=2
chain #1 + #4 -> tot=4 ref#4=2
chain #1 + #5 -> tot=5 ref#5=2
free #2 -> 0 freed
free #3 -> 0 freed
free #4 -> 0 freed
free #5 -> 0 freed
tot #1 = 5
copy #1 off=1 n=3 -> 3 20 30 40
ref #3 -> 2
free #1 -> 2 freed
free #3 -> 3 freed

@@@ hidden_input
A 3
R 1
R 1
F 1
F 1
T 1
F 1
@@@ hidden_output
A#1 len=3 ref=1
ref #1 -> 2
ref #1 -> 3
free #1 -> 0 freed
free #1 -> 0 freed
tot #1 = 3
free #1 -> 1 freed

@@@ hidden_input
A 1500
A 1500
C 1 2
F 2
X 1 1499 3
X 1 3000 1
T 1
F 1
@@@ hidden_output
A#1 len=1500 ref=1
A#2 len=1500 ref=1
chain #1 + #2 -> tot=3000 ref#2=2
free #2 -> 0 freed
copy #1 off=1499 n=3 -> 3 EB 20 21
copy #1 off=3000 n=1 -> 0
tot #1 = 3000
free #1 -> 2 freed

@@@ hidden_input
G 5000 7
@@@ hidden_output
G n=5000 tot=97096 sum=1639545743 freed=5000

@@@ hidden_input
G 1 3
G 300 11
A 2
F 302
@@@ hidden_output
G n=1 tot=35 sum=3337748545 freed=1
G n=300 tot=5899 sum=8135675 freed=300
A#302 len=2 ref=1
free #302 -> 1 freed

@@@ hint
Allocate `sizeof(struct pbuf) + len` bytes in one block: the flexible array member `payload[]` adds nothing to `sizeof`. In `pbuf_chain`, walk to the last buffer of `head`, link `tail` there, and increment `tail->ref`, because a new pointer to it now exists.
@@@ hint
`pbuf_free` is a loop: `while (p) { if (--p->ref > 0) break; next = p->next; free(p); count++; p = next; }`. Read `next` before `free`. For `copy_partial`, first skip whole buffers while `offset >= len`, then copy from the remaining offset inside the current buffer and continue with the next buffers until `len` bytes are copied or the chain ends.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

struct pbuf {
    struct pbuf *next;
    uint16_t len;
    uint16_t ref;
    uint8_t payload[];
};

struct pbuf *pbuf_alloc(uint16_t len)
{
    struct pbuf *p = malloc(sizeof *p + len);      /* header + payload: one block */
    if (p == NULL)
        return NULL;
    p->next = NULL;
    p->len = len;
    p->ref = 1;                                    /* the caller's reference */
    memset(p->payload, 0, len);
    return p;
}

void pbuf_ref(struct pbuf *p)
{
    if (p != NULL)
        p->ref++;
}

void pbuf_chain(struct pbuf *head, struct pbuf *tail)
{
    if (head == NULL || tail == NULL)
        return;
    struct pbuf *last = head;
    while (last->next != NULL)
        last = last->next;
    last->next = tail;
    tail->ref++;                                   /* the chain now references tail */
}

int pbuf_free(struct pbuf *p)
{
    int freed = 0;
    while (p != NULL) {                            /* iterative: no recursion depth */
        if (--p->ref > 0)
            break;                                 /* still referenced elsewhere: stop */
        struct pbuf *next = p->next;               /* read before free */
        free(p);
        freed++;
        p = next;                                  /* drop the reference p held on next */
    }
    return freed;
}

uint32_t pbuf_tot_len(const struct pbuf *p)
{
    uint32_t tot = 0;
    for (; p != NULL; p = p->next)
        tot += p->len;
    return tot;
}

uint16_t pbuf_copy_partial(const struct pbuf *p, void *dst, uint16_t len, uint16_t offset)
{
    uint8_t *out = dst;
    uint16_t copied = 0;
    for (; p != NULL && copied < len; p = p->next) {
        if (offset >= p->len) {                    /* skip whole buffers */
            offset = (uint16_t)(offset - p->len);
            continue;
        }
        uint16_t avail = (uint16_t)(p->len - offset);
        uint16_t n = (uint16_t)(len - copied) < avail ? (uint16_t)(len - copied) : avail;
        memcpy(out + copied, p->payload + offset, n);
        copied = (uint16_t)(copied + n);
        offset = 0;                                /* later buffers start at their beginning */
    }
    return copied;
}
@@@ explanation_md
**Approach: references are edges.** Every pointer that keeps a buffer alive counts as one reference: the creator's handle, every explicit `pbuf_ref`, and the `next` pointer of the buffer in front of it in a chain. A buffer may be freed only when **no** edge points to it any more.

```
A#1 -> A#3 <- A#2        (two chains share the tail)
refs: #1:1  #2:1  #3:3   (creator + two chain links)
free #1 : #1 -> 0, freed; drops its link: #3 -> 2   (1 freed)
free #2 : #2 -> 0, freed; #3 -> 1                    (1 freed)
free #3 : #3 -> 0, freed                             (1 freed)
```

- `pbuf_chain` adds an edge, so `tail->ref++`.
- `pbuf_free` removes one edge. If the count drops to 0, the buffer dies, and **its** outgoing edge (`next`) disappears too, so the loop continues with `next`. It stops at the first buffer that is still referenced elsewhere. Iterating instead of recursing keeps the stack at O(1) for 5000-buffer chains (a typical lwIP task stack is 1-2 KB).
- `pbuf_alloc` uses a flexible array member, so header and payload are one allocation: one failure point, one `free`, and the payload is contiguous with its header (DMA-friendly).

**Complexity.** `alloc`/`ref` O(1) (plus O(len) zeroing). `chain` and `tot_len` are O(chain length). `free` is O(buffers freed + 1). `copy_partial` is O(buffers visited + bytes copied). Space: one header per buffer.

**Common mistakes**
- Forgetting `tail->ref++` in `pbuf_chain`. The creator's `pbuf_free(tail)` then frees a buffer that the chain still points to, and the chain reads freed memory.
- Freeing the whole chain unconditionally, which ignores a shared tail or an outstanding `pbuf_ref`.
- A recursive free (`pbuf_free(p->next)` from inside `pbuf_free`): correct, but it overflows small RTOS stacks on long chains.
- `copy_partial` that ignores `offset` across buffer boundaries, or keeps applying it to every buffer.
- Decrementing `ref` of a buffer whose count is already 0 (a use-after-free in the caller; lwIP asserts on it).

**Interview follow-ups**
- Make `ref`/`free` safe when the Ethernet RX interrupt and the TCP/IP task both touch the counter. (Atomic decrement-and-test, or a critical section; why is `--p->ref` not atomic on Cortex-M?)
- lwIP has `pbuf_cat` (no new reference: ownership of `tail` is **transferred**) and `pbuf_chain` (new reference). When would you use which?
- Reference counting cannot free cycles. Can a pbuf chain ever form one, and how would you assert against it?
- Where would a static pool (MEM-H-01 style) replace `malloc` here? (lwIP's `PBUF_POOL` type: fixed-size buffers preallocated at boot.)
