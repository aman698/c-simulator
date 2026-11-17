@@@ meta
id: MEM-M-06
topic: Dynamic Memory
difficulty: Medium
type: FUNCTION
title: Growable Ring Buffer That Unwraps on Resize
tags: embedded, ring-buffer, fifo, realloc, wrap-around
@@@ statement_md
A gateway daemon queues CAN frames in a circular FIFO. On the Linux side, the queue may grow instead of dropping frames. Growing a **ring** buffer is not like growing a plain array: once the data has wrapped around the end of the buffer, a simple `realloc` leaves the elements in the wrong order. Implement:

```c
struct fifo {
    int *buf;      /* cap slots (NULL when cap == 0) */
    size_t cap;    /* slots allocated */
    size_t head;   /* index of the oldest element */
    size_t count;  /* elements stored */
};

int  fifo_push(struct fifo *q, int v);    /* 0, or -1 if out of memory */
int  fifo_pop(struct fifo *q, int *out);  /* 0, or -1 if empty */
void fifo_free(struct fifo *q);           /* release; leave {NULL, 0, 0, 0} */
```

Rules (fixed so that the harness can check the internal state):
- A FIFO starts as `{NULL, 0, 0, 0}`. The new element goes to slot `(head + count) % cap`.
- **Growth.** If `count == cap` at a push, the capacity becomes `4` (if `cap == 0`) or `2 * cap`. After growing, the elements are stored **in FIFO order starting at slot 0** (`head = 0`). Then the new element is added.
- **Pop** returns `buf[head]`, sets `head = (head + 1) % cap` and decrements `count`. `head` is **not** reset when the FIFO becomes empty.
- No shrinking. If an allocation fails, the FIFO must be unchanged and still valid.

**Input (read by the hidden harness)**, one operation per line:
- `P v`: push. `R n seed`: push `n` LCG values `0..999`.
- `O`: pop and print `pop <v>` or `empty`. `Q k`: pop up to `k` and print `popped <count> sum=<sum>`.
- `S`: prints `cap=<cap> head=<head> count=<count>`, then `[<elements oldest first>]` when `count <= 20`, otherwise ` sum=<sum> first=<oldest> last=<newest>`.
- After any operation that changed the capacity, the harness prints `grow A->B` (before the operation's own output).

**Example**
```
Input:
P 1
P 2
P 3
P 4
O
O
P 5
P 6
S
P 7
S

Output:
grow 0->4
pop 1
pop 2
cap=4 head=2 count=4 [3 4 5 6]
grow 4->8
cap=8 head=0 count=5 [3 4 5 6 7]
```
Before the last growth the slots were `[5 6 3 4]` with `head = 2`. A plain `realloc` to 8 slots would give `[5 6 3 4 _ _ _ _]`, and appending at `head + count` would mix up the order.
@@@ constraints_md
- At most 300 script lines, at most 300000 elements in the FIFO.
- Use `malloc`/`realloc`/`free`. The harness calls `fifo_free` at the end, and leak checking is on.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

struct fifo {
    int *buf;
    size_t cap;
    size_t head;
    size_t count;
};

int fifo_push(struct fifo *q, int v)
{
    /* TODO: grow (0 -> 4, then x2) when full and unwrap so head == 0 */
    return -1;
}

int fifo_pop(struct fifo *q, int *out)
{
    /* TODO */
    return -1;
}

void fifo_free(struct fifo *q)
{
    /* TODO */
}
@@@ harness_code
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*USER_CODE*/

static void check(const struct fifo *q, size_t before)
{
    if (q->cap != before)
        printf("grow %zu->%zu\n", before, q->cap);
    if (q->count > q->cap || (q->cap > 0 && q->head >= q->cap))
        printf("FAIL: inconsistent state\n");
}

int main(void)
{
    struct fifo q = { NULL, 0, 0, 0 };
    char op[4];
    while (scanf("%3s", op) == 1) {
        size_t before = q.cap;
        if (op[0] == 'P') {
            int v;
            if (scanf("%d", &v) != 1)
                break;
            int rc = fifo_push(&q, v);
            check(&q, before);
            if (rc != 0)
                printf("push failed\n");
        } else if (op[0] == 'R') {
            int n;
            unsigned int seed;
            if (scanf("%d %u", &n, &seed) != 2)
                break;
            for (int i = 0; i < n; i++) {
                seed = seed * 1103515245u + 12345u;
                size_t b = q.cap;
                if (fifo_push(&q, (int)((seed >> 16) % 1000u)) != 0) {
                    printf("push failed\n");
                    break;
                }
                check(&q, b);
            }
        } else if (op[0] == 'O') {
            int v;
            int rc = fifo_pop(&q, &v);
            check(&q, before);
            if (rc == 0)
                printf("pop %d\n", v);
            else
                printf("empty\n");
        } else if (op[0] == 'Q') {
            int k, cnt = 0;
            long long sum = 0;
            if (scanf("%d", &k) != 1)
                break;
            for (int i = 0; i < k; i++) {
                int v;
                if (fifo_pop(&q, &v) != 0)
                    break;
                cnt++;
                sum += v;
            }
            check(&q, before);
            printf("popped %d sum=%lld\n", cnt, sum);
        } else if (op[0] == 'S') {
            printf("cap=%zu head=%zu count=%zu", q.cap, q.head, q.count);
            if (q.count <= 20) {
                printf(" [");
                for (size_t i = 0; i < q.count; i++)
                    printf("%s%d", i ? " " : "", q.buf[(q.head + i) % q.cap]);
                printf("]\n");
            } else {
                long long sum = 0;
                for (size_t i = 0; i < q.count; i++)
                    sum += q.buf[(q.head + i) % q.cap];
                printf(" sum=%lld first=%d last=%d\n", sum, q.buf[q.head],
                       q.buf[(q.head + q.count - 1) % q.cap]);
            }
        }
    }
    fifo_free(&q);
    if (q.buf != NULL || q.cap != 0 || q.count != 0 || q.head != 0)
        printf("FAIL: fifo not reset by fifo_free\n");
    return 0;
}
@@@ sample_input
P 1
P 2
P 3
P 4
O
O
P 5
P 6
S
P 7
S
@@@ sample_output
grow 0->4
pop 1
pop 2
cap=4 head=2 count=4 [3 4 5 6]
grow 4->8
cap=8 head=0 count=5 [3 4 5 6 7]

@@@ sample_input
O
S
P 9
O
O
S
@@@ sample_output
empty
cap=0 head=0 count=0 []
grow 0->4
pop 9
empty
cap=4 head=1 count=0 []

@@@ hidden_input
P 10
P 20
P 30
P 40
O
O
O
P 50
P 60
P 70
S
P 80
S
@@@ hidden_output
grow 0->4
pop 10
pop 20
pop 30
cap=4 head=3 count=4 [40 50 60 70]
grow 4->8
cap=8 head=0 count=5 [40 50 60 70 80]

@@@ hidden_input
P 1
P 2
P 3
P 4
P 5
S
Q 5
S
P -1
P -2
P -3
P -4
P -5
P -6
P -7
P -8
P -9
S
@@@ hidden_output
grow 0->4
grow 4->8
cap=8 head=0 count=5 [1 2 3 4 5]
popped 5 sum=15
cap=8 head=5 count=0 []
grow 8->16
cap=16 head=0 count=9 [-1 -2 -3 -4 -5 -6 -7 -8 -9]

@@@ hidden_input
P 2147483647
P -2147483648
O
P 0
O
O
O
S
@@@ hidden_output
grow 0->4
pop 2147483647
pop -2147483648
pop 0
empty
cap=4 head=3 count=0 []

@@@ hidden_input
R 13 1
Q 6
R 9 2
S
Q 3
R 30 3
S
@@@ hidden_output
grow 0->4
grow 4->8
grow 8->16
popped 6 sum=2974
cap=16 head=6 count=16 [778 187 980 86 749 767 84 676 817 7 682 605 95 976 865 70]
popped 3 sum=1945
grow 16->32
grow 32->64
cap=64 head=0 count=43 sum=19875 first=86 last=116

@@@ hidden_input
R 1000 5
Q 999
R 200000 6
Q 77777
R 50000 7
S
Q 300000
S
@@@ hidden_output
grow 0->4
grow 4->8
grow 8->16
grow 16->32
grow 32->64
grow 64->128
grow 128->256
grow 256->512
grow 512->1024
popped 999 sum=491782
grow 1024->2048
grow 2048->4096
grow 4096->8192
grow 8192->16384
grow 16384->32768
grow 32768->65536
grow 65536->131072
grow 131072->262144
popped 77777 sum=38696660
cap=262144 head=77777 count=172224 sum=85657031 first=998 last=29
popped 172224 sum=85657031
cap=262144 head=250001 count=0 []

@@@ hint
When the FIFO is full and wrapped, the oldest elements are at `buf[head..cap-1]` and the newest at `buf[0..head-1]`. Growth must lay them out again as `oldest ... newest` from slot 0.
@@@ hint
Simplest correct growth: `malloc` a new block of `2 * cap`, copy element `i` from `old[(head + i) % cap]` to `new[i]` for `i < count`, `free` the old block, and set `head = 0`. Do the allocation **first**, and only modify the FIFO after it succeeded.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

struct fifo {
    int *buf;
    size_t cap;
    size_t head;
    size_t count;
};

static int fifo_grow(struct fifo *q)
{
    size_t newcap = q->cap ? q->cap * 2 : 4;
    if (newcap < q->cap || newcap > SIZE_MAX / sizeof *q->buf)
        return -1;
    int *nb = malloc(newcap * sizeof *nb);
    if (nb == NULL)
        return -1;                          /* q untouched */

    /* unwrap: two contiguous runs, [head, cap) then [0, head) */
    size_t first = q->cap - q->head;        /* elements up to the physical end */
    if (first > q->count)
        first = q->count;
    if (q->count > 0) {
        memcpy(nb, q->buf + q->head, first * sizeof *nb);
        memcpy(nb + first, q->buf, (q->count - first) * sizeof *nb);
    }
    free(q->buf);
    q->buf = nb;
    q->cap = newcap;
    q->head = 0;
    return 0;
}

int fifo_push(struct fifo *q, int v)
{
    if (q->count == q->cap && fifo_grow(q) != 0)
        return -1;
    q->buf[(q->head + q->count) % q->cap] = v;
    q->count++;
    return 0;
}

int fifo_pop(struct fifo *q, int *out)
{
    if (q->count == 0)
        return -1;
    *out = q->buf[q->head];
    q->head = (q->head + 1) % q->cap;
    q->count--;
    return 0;
}

void fifo_free(struct fifo *q)
{
    free(q->buf);
    q->buf = NULL;
    q->cap = 0;
    q->head = 0;
    q->count = 0;
}
@@@ explanation_md
**Approach.** A full ring buffer that has wrapped stores its data in two runs:

```
cap = 4, head = 2:   slot: [ 5 | 6 | 3 | 4 ]
                             newest   oldest
logical order: 3 4 5 6  =  buf[2..3] followed by buf[0..1]
```

`realloc(buf, 8 * sizeof(int))` keeps the **physical** layout `[5 6 3 4 _ _ _ _]`. With `head = 2` and `count = 4`, the next push lands in slot 6, after the 4. The 5 and 6 at slots 0-1 are no longer reachable in order, so the FIFO is corrupted. Growth must **unwrap**: copy run 1 (`head..cap-1`) to the start of the new block, then run 2 (`0..head-1`) after it, and reset `head = 0`. Two `memcpy` calls do it.

An alternative keeps `realloc`: after growing, move the run `[0, head)` to `[old_cap, old_cap + head)` (it fits, because the new block has `old_cap` free slots). This leaves `head` unchanged. The statement fixes `head = 0` so that all correct solutions print the same state.

**Complexity.** Push is amortized O(1) (doubling); a growing push is O(n). Pop is O(1). Space is O(cap), with `cap < 2 * max_count` (and at least 4).

**Common mistakes**
- `realloc` without unwrapping. Every test passes until the first growth that happens while the buffer is wrapped.
- Copying with `memcpy(nb, q->buf + q->head, q->count * sizeof *nb)` in one go, which reads past the end of the old block when the data wraps.
- Updating `cap` before the allocation succeeded. On failure the FIFO then claims slots it does not have.
- Using `% cap` when `cap == 0` (division by zero) on the first push or on pop from an empty FIFO.
- Resetting `head` to 0 on every pop that empties the FIFO. That is legal in general, but violates this spec.

**Interview follow-ups**
- On an MCU the FIFO is fixed-size and shared between an ISR (producer) and a task (consumer). Why can you then drop `count` and use free-running `head`/`tail` indices with a power-of-two size? Which variables must be `volatile`, and why is that still not enough on multi-core parts?
- Why are power-of-two capacities attractive (`& (cap - 1)` instead of `% cap`)? Does doubling keep that property?
- What policy would you choose when the FIFO is full on a bare-metal ECU: drop newest, drop oldest, or block? Which one does AUTOSAR CanIf/PduR typically use for transmit buffers?
