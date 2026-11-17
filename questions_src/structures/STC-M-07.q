@@@ meta
id: STC-M-07
topic: Structures
difficulty: Medium
type: FUNCTION
title: Find the Loop Entry and Length in a Corrupted List (Floyd)
tags: embedded, linked-list, floyd-cycle-detection, two-pointers, memory-corruption
@@@ statement_md
A memory-corruption bug in an ECU's message pool sometimes makes a linked list loop back on itself, and the next traversal hangs the task until the watchdog resets the ECU. Write a diagnostic routine that detects this **without modifying the list and with O(1) extra memory**:

```c
struct Node {
    int          val;
    struct Node *next;
};

struct Node *find_loop(struct Node *head, size_t *loop_len);
```

- If the list ends in `NULL`, return `NULL` and set `*loop_len = 0`.
- Otherwise, return the **first node of the cycle** (the node reached twice first when walking from `head`) and set `*loop_len` to the number of nodes in the cycle.
- `head` may be `NULL`. Values may repeat, so you cannot detect the loop by comparing values.
- Do not modify any node, and do not allocate memory (no visited flags or hash sets).

`struct Node` is already defined by the judge.

**Input (read by the hidden harness)**
- Line 1: `n pos`. The harness builds `n` nodes and, if `pos >= 0`, links the last node back to node `pos` (0-based).
- Line 2: `n` values if `n <= 2000`. For `n > 2000` there is no line 2, and the values are `(i * 7) % 10`.

**Output (printed by the harness)**
- `LOOP entry=<index> val=<value> len=<L>` or `NO LOOP`.
- The harness also prints `FAIL: list was modified` if any `next` pointer changed.

**Example**
```
Input:
6 2
3 2 0 -4 5 7

Output:
LOOP entry=2 val=0 len=4
```
@@@ constraints_md
- `0 <= n <= 100000`, `-1 <= pos < n` (`pos = -1` means no loop).
- O(n) time, O(1) extra memory.
@@@ starter_code
#include <stddef.h>

/* Already defined by the judge:
 *
 * struct Node { int val; struct Node *next; };
 */

struct Node *find_loop(struct Node *head, size_t *loop_len)
{
    /* TODO: Floyd's tortoise and hare */
    (void)head;
    *loop_len = 0;
    return NULL;
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>

struct Node {
    int          val;
    struct Node *next;
};

/*USER_CODE*/

int main(void)
{
    int n, pos;
    if (scanf("%d %d", &n, &pos) != 2 || n < 0 || n > 100000 || pos >= n) return 0;
    struct Node **all = malloc((size_t)(n ? n : 1) * sizeof *all);
    struct Node **saved = malloc((size_t)(n ? n : 1) * sizeof *saved);
    if (!all || !saved) return 0;
    for (int i = 0; i < n; i++) {
        int v = (i * 7) % 10;
        if (n <= 2000 && scanf("%d", &v) != 1) return 0;
        all[i] = malloc(sizeof **all);
        if (!all[i]) return 0;
        all[i]->val = v;
        all[i]->next = NULL;
        if (i) all[i - 1]->next = all[i];
    }
    if (n > 0 && pos >= 0) all[n - 1]->next = all[pos];          /* create the cycle */
    for (int i = 0; i < n; i++) saved[i] = all[i]->next;

    size_t len = 12345;
    struct Node *e = find_loop(n ? all[0] : NULL, &len);

    int modified = 0;
    for (int i = 0; i < n; i++)
        if (all[i]->next != saved[i]) modified = 1;
    if (modified) printf("FAIL: list was modified\n");

    if (e == NULL) {
        if (len != 0) printf("FAIL: loop_len must be 0 when there is no loop\n");
        printf("NO LOOP\n");
    } else {
        int idx = -1;
        for (int i = 0; i < n; i++)
            if (all[i] == e) { idx = i; break; }
        if (idx < 0) printf("FAIL: returned a node that is not in the list\n");
        else printf("LOOP entry=%d val=%d len=%zu\n", idx, e->val, len);
    }

    if (n > 0) all[n - 1]->next = NULL;                          /* break the cycle before freeing */
    for (int i = 0; i < n; i++) free(all[i]);
    free(all);
    free(saved);
    return 0;
}
@@@ sample_input
6 2
3 2 0 -4 5 7
@@@ sample_output
LOOP entry=2 val=0 len=4

@@@ sample_input
3 -1
1 2 3
@@@ sample_output
NO LOOP

@@@ hidden_input
0 -1
@@@ hidden_output
NO LOOP

@@@ hidden_input
1 -1
5
@@@ hidden_output
NO LOOP

@@@ hidden_input
1 0
5
@@@ hidden_output
LOOP entry=0 val=5 len=1

@@@ hidden_input
2 0
1 2
@@@ hidden_output
LOOP entry=0 val=1 len=2

@@@ hidden_input
2 1
1 2
@@@ hidden_output
LOOP entry=1 val=2 len=1

@@@ hidden_input
5 4
7 7 7 7 7
@@@ hidden_output
LOOP entry=4 val=7 len=1

@@@ hidden_input
7 3
1 2 3 1 2 3 1
@@@ hidden_output
LOOP entry=3 val=1 len=4

@@@ hidden_input
100000 31234
@@@ hidden_output
LOOP entry=31234 val=8 len=68766

@@@ hidden_input
100000 -1
@@@ hidden_output
NO LOOP

@@@ hidden_input
100000 0
@@@ hidden_output
LOOP entry=0 val=0 len=100000

@@@ hint
Move `slow` one step and `fast` two steps at a time. If `fast` reaches `NULL`, there is no loop. If they meet, you are inside the cycle. Count the steps for one more lap from the meeting point to get the length.
@@@ hint
To find the entry, reset one pointer to `head` and move **both** one step at a time. They meet exactly at the first node of the cycle: if the tail before the cycle has length `a`, then `a` is congruent to the distance from the meeting point to the entry, modulo the cycle length.
@@@ solution_code
#include <stddef.h>

struct Node *find_loop(struct Node *head, size_t *loop_len)
{
    struct Node *slow = head, *fast = head;
    *loop_len = 0;

    /* phase 1: does the hare catch the tortoise? */
    while (fast != NULL && fast->next != NULL) {
        slow = slow->next;
        fast = fast->next->next;
        if (slow == fast)
            break;
    }
    if (fast == NULL || fast->next == NULL)
        return NULL;                       /* reached the end: no loop */

    /* phase 2: cycle length = steps for one full lap from the meeting point */
    size_t len = 1;
    for (const struct Node *p = slow->next; p != slow; p = p->next)
        len++;
    *loop_len = len;

    /* phase 3: entry - one pointer from head, one from the meeting point */
    slow = head;
    while (slow != fast) {
        slow = slow->next;
        fast = fast->next;
    }
    return slow;
}
@@@ explanation_md
**Approach: Floyd's tortoise and hare.**
1. `slow` moves 1 step and `fast` moves 2. Without a loop, `fast` hits `NULL`. With a loop, `fast` gains one node per step inside the cycle, so the two must meet within at most one lap.
2. **Length:** from the meeting point, walk around once and count.
3. **Entry:** let `a` = nodes before the cycle, `L` = cycle length, and `b` = distance from the entry to the meeting point. When they meet, `slow` has walked `a + b`, and `fast` has walked `2(a + b) = a + b + kL`, so `a = kL - b`. Walking `a` steps from `head` reaches the entry, and walking `a` steps from the meeting point also reaches the entry.

```
3 -> 2 -> [0] -> -4 -> 5 -> 7
            ^________________|      a = 2, L = 4
```

**Complexity.** Time O(n), space O(1). The list is only read, which matters when the routine runs as a diagnostic on a live, possibly corrupted structure.

**Common mistakes**
- Checking `fast->next->next` without first checking `fast->next`. That dereferences `NULL` on even-length lists.
- Comparing **values** (`slow->val == fast->val`) instead of node addresses. Duplicates such as `7 7 7 7 7` give false positives.
- Starting `fast = head->next` and then using the phase-3 trick. The phase-3 math assumes both pointers start at `head`.
- Marking visited nodes by modifying `next` or `val`. That destroys the evidence you are debugging and violates the read-only requirement.
- Forgetting the self-loop (`pos == n-1`, `len = 1`) and the whole-list loop (`pos = 0`).

**Interview follow-ups**
- How would you **repair** the list: break the cycle so that it ends at the node just before the entry?
- Brent's algorithm also finds cycles in O(n). Why does it usually take fewer pointer moves?
- In an RTOS, how would you protect every list walk against a corrupted loop? (An iteration bound equal to the pool size, plus an error hook.)
- Two singly linked lists may merge into a Y shape. How do you find the merge node in O(1) memory?
