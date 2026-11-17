@@@ meta
id: STC-M-08
topic: Structures
difficulty: Medium
type: FUNCTION
title: Merge Two Sorted CAN Logs by Splicing Nodes
tags: embedded, linked-list, merge, stable, iterative, can-bus
@@@ statement_md
A data logger records two CAN channels into two separate linked lists, each sorted by timestamp. For export, they must be merged into one timeline **without copying or allocating anything**: splice the existing nodes together.

```c
struct LogEntry {
    uint32_t         ts;       /* timestamp in microseconds */
    uint16_t         can_id;
    struct LogEntry *next;
};

struct LogEntry *merge_logs(struct LogEntry *a, struct LogEntry *b);
```

- Both input lists are sorted by `ts` in non-decreasing order. Either one may be `NULL`.
- The result must be sorted by `ts`, and the merge must be **stable**: for equal timestamps, entries from `a` come before entries from `b`, and entries from the same list keep their order.
- Use only the original nodes (the harness checks every node address). Do not modify `ts` or `can_id`.
- Iterate. Do not recurse: one hidden test merges two lists of 100000 nodes each.

`struct LogEntry` is already defined by the judge.

**Input (read by the hidden harness)**
- Line 1: `na nb mode`.
- If `mode` is `L`: `na` lines `ts id` for list `a` (id in hex), then `nb` lines for list `b`.
- If `mode` is `G`: no further input. The harness generates `a[i] = { 2*i, i % 0x800 }` and `b[i] = { 3*i, (5*i) % 0x800 }`.

**Output (printed by the harness)**
- `L` mode: the merged list as `ts:ID` (ID as `%03X`) separated by spaces, or `EMPTY`.
- `G` mode: `count=<n>`, then the first 5 and last 5 entries on one line separated by ` ... `.
- Last line: `OK` if the result is sorted, stable and made of exactly the original nodes; otherwise a `FAIL:` message.

**Example**
```
Input:
3 4 L
10 100
20 101
30 102
5 200
20 201
25 202
40 203

Output:
5:200 10:100 20:101 20:201 25:202 30:102 40:203
OK
```
@@@ constraints_md
- `0 <= na, nb <= 100000` (in `L` mode at most 1000 each).
- `0 <= ts <= 4294967295`. Compare with `<`/`<=`, never by subtracting.
- O(na + nb) time, O(1) extra memory.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>

/* Already defined by the judge:
 *
 * struct LogEntry { uint32_t ts; uint16_t can_id; struct LogEntry *next; };
 */

struct LogEntry *merge_logs(struct LogEntry *a, struct LogEntry *b)
{
    /* TODO: splice a and b into one sorted list (stable: a first on ties) */
    (void)b;
    return a;
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

struct LogEntry {
    uint32_t         ts;
    uint16_t         can_id;
    struct LogEntry *next;
};

/*USER_CODE*/

static struct LogEntry *build(struct LogEntry *nodes, int n)
{
    for (int i = 0; i < n; i++) nodes[i].next = (i + 1 < n) ? &nodes[i + 1] : NULL;
    return n ? &nodes[0] : NULL;
}

int main(void)
{
    int na, nb;
    char mode[4];
    if (scanf("%d %d %3s", &na, &nb, mode) != 3 || na < 0 || nb < 0 || na > 100000 || nb > 100000) return 0;
    int gen = mode[0] == 'G';
    struct LogEntry *A = calloc((size_t)na + 1, sizeof *A);
    struct LogEntry *B = calloc((size_t)nb + 1, sizeof *B);
    unsigned char *seen = calloc((size_t)na + (size_t)nb + 1, 1);
    if (!A || !B || !seen) return 0;
    for (int i = 0; i < na + nb; i++) {
        struct LogEntry *e = i < na ? &A[i] : &B[i - na];
        int k = i < na ? i : i - na;
        if (gen) {
            e->ts = i < na ? (uint32_t)(2 * k) : (uint32_t)(3 * k);
            e->can_id = (uint16_t)(i < na ? k % 0x800 : (5 * k) % 0x800);
        } else {
            unsigned ts, id;
            if (scanf("%u %x", &ts, &id) != 2) return 0;
            e->ts = (uint32_t)ts;
            e->can_id = (uint16_t)id;
        }
    }

    struct LogEntry *m = merge_logs(build(A, na), build(B, nb));

    /* walk the result (bounded), print, and verify */
    const char *fail = NULL;
    int count = 0, total = na + nb;
    int lastA = -1, lastB = -1, prevIdx = -1;
    const struct LogEntry *prev = NULL;
    uintptr_t ua = (uintptr_t)A, ub = (uintptr_t)B;
    for (const struct LogEntry *p = m; p != NULL; p = p->next) {
        if (count >= total) { fail = "result has too many nodes (cycle?)"; break; }
        int idx;
        uintptr_t up = (uintptr_t)p;
        if (up >= ua && up < ua + (uintptr_t)na * sizeof *A) idx = (int)((up - ua) / sizeof *A);
        else if (up >= ub && up < ub + (uintptr_t)nb * sizeof *B) idx = na + (int)((up - ub) / sizeof *B);
        else { fail = "result contains a node that is not from the inputs"; break; }
        if (seen[idx]) { fail = "a node appears twice"; break; }
        seen[idx] = 1;
        if (prev && prev->ts > p->ts) { if (!fail) fail = "result is not sorted"; }
        if (prev && prev->ts == p->ts && idx < na && prevIdx >= na)
            if (!fail) fail = "not stable: an entry of b precedes an equal entry of a";
        if (idx < na) { if (idx < lastA && !fail) fail = "order inside a changed"; lastA = idx; }
        else { if (idx - na < lastB && !fail) fail = "order inside b changed"; lastB = idx - na; }
        if (!gen) printf("%s%u:%03X", count ? " " : "", (unsigned)p->ts, (unsigned)p->can_id);
        else if (count < 5 || count >= total - 5)
            printf("%s%u:%03X", count == 0 ? "" : (count == total - 5 && total > 10 ? " ... " : " "),
                   (unsigned)p->ts, (unsigned)p->can_id);
        prev = p;
        prevIdx = idx;
        count++;
    }
    if (gen) printf("%scount=%d", count ? "\n" : "", count);
    if (!gen && count == 0) printf("EMPTY");
    printf("\n");
    if (!fail && count != total) fail = "nodes were lost";
    if (fail) printf("FAIL: %s\n", fail);
    else printf("OK\n");

    free(A);
    free(B);
    free(seen);
    return 0;
}
@@@ sample_input
3 4 L
10 100
20 101
30 102
5 200
20 201
25 202
40 203
@@@ sample_output
5:200 10:100 20:101 20:201 25:202 30:102 40:203
OK

@@@ sample_input
0 2 L
1 7E0
2 7E8
@@@ sample_output
1:7E0 2:7E8
OK

@@@ hidden_input
0 0 L
@@@ hidden_output
EMPTY
OK

@@@ hidden_input
2 0 L
3 123
3 124
@@@ hidden_output
3:123 3:124
OK

@@@ hidden_input
3 2 L
7 0A0
7 0A1
7 0A2
7 0B0
7 0B1
@@@ hidden_output
7:0A0 7:0A1 7:0A2 7:0B0 7:0B1
OK

@@@ hidden_input
2 3 L
100 001
200 002
1 7FD
2 7FE
3 7FF
@@@ hidden_output
1:7FD 2:7FE 3:7FF 100:001 200:002
OK

@@@ hidden_input
1 2 L
4294967295 7FF
0 000
2147483648 400
@@@ hidden_output
0:000 2147483648:400 4294967295:7FF
OK

@@@ hidden_input
4 4 L
1 1
3 3
5 5
7 7
2 2
4 4
6 6
8 8
@@@ hidden_output
1:001 2:002 3:003 4:004 5:005 6:006 7:007 8:008
OK

@@@ hidden_input
100000 100000 G
@@@ hidden_output
0:000 0:000 2:001 3:005 4:002 ... 299985:107 299988:10C 299991:111 299994:116 299997:11B
count=200000
OK

@@@ hint
Use a dummy head node on the stack (`struct LogEntry dummy; struct LogEntry *tail = &dummy;`). Repeatedly unlink the smaller front node from `a` or `b` and append it to `tail`.
@@@ hint
Take from `a` when `a->ts <= b->ts`; the `<=` is what gives stability. When one list runs out, attach the rest of the other in one step (`tail->next = a ? a : b`) and return `dummy.next`.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>

struct LogEntry *merge_logs(struct LogEntry *a, struct LogEntry *b)
{
    struct LogEntry dummy;               /* only dummy.next is ever used */
    struct LogEntry *tail = &dummy;
    dummy.next = NULL;

    while (a != NULL && b != NULL) {
        if (a->ts <= b->ts) {            /* <= : on ties, a wins -> stable */
            tail->next = a;
            a = a->next;
        } else {
            tail->next = b;
            b = b->next;
        }
        tail = tail->next;
    }
    tail->next = (a != NULL) ? a : b;    /* splice the remainder in O(1) */
    return dummy.next;
}
@@@ explanation_md
**Approach.** This is the merge step of merge sort, done on pointers. A **dummy head** removes every special case for the first node: `tail` always points at the last node of the merged list, and the answer is `dummy.next`. Each step moves one node from the front of `a` or `b` to the end of the result. When one list is empty, the other is already sorted and is attached with a single pointer assignment.

```
a: 10 20 30        b: 5 20 25 40
5(b) 10(a) 20(a) 20(b) 25(b) 30(a) | rest of b: 40
             ^ tie: a first (<=)
```

**Complexity.** Time O(na + nb), space O(1). The recursive version (`a->next = merge(a->next, b)`) is shorter, but its stack depth is na + nb. 200000 frames overflow any MCU stack and most desktop stacks.

**Common mistakes**
- Using `<` instead of `<=`, so equal timestamps from `b` jump ahead of `a`. The output is still sorted, but the stability check fails.
- Comparing with `(int)(a->ts - b->ts) < 0`. The test with `4294967295` and `0` gets the wrong sign.
- Allocating new nodes and copying the data. That doubles memory, leaks the originals, and fails the identity check.
- Forgetting to attach the leftover list, or looping over it node by node (correct, but needlessly O(n)).
- Not handling `a == NULL` or `b == NULL` at the start. The dummy-head version handles it automatically.

**Interview follow-ups**
- Use this function to write an O(n log n) merge sort for a singly linked list with O(1) extra memory (bottom-up).
- Merge **k** sorted channel logs efficiently. (A min-heap of k list heads: O(N log k).)
- Timestamps come from a 32-bit microsecond counter that wraps every 71.6 minutes. How must the comparison change?
- Why is merge sort, rather than quicksort, the natural choice for linked lists?
