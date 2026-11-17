@@@ meta
id: STC-H-08
topic: Structures
difficulty: Hard
type: FUNCTION
title: Reorder a List as First-Last-Second-Second-Last In Place
tags: linked-list, find-middle, two-pointers, reversal, in-place, iterative
@@@ statement_md
Given a singly linked list `L0 -> L1 -> ... -> Ln-1`, reorder it **in place** to

```
L0 -> Ln-1 -> L1 -> Ln-2 -> L2 -> Ln-3 -> ...
```

```c
struct Node {
    int          val;
    struct Node *next;
};

void list_reorder(struct Node *head);
```

- Relink the existing nodes. Do not allocate memory, do not copy or swap `val`, and do not use an array of node pointers: O(1) extra memory. The harness checks node identity.
- Iterate. Do not recurse: one hidden test has 200000 nodes.
- `head` may be `NULL`. The head node stays the head, which is why the function returns nothing.

`struct Node` is already defined by the judge.

**Input (read by the hidden harness)**
- Line 1: `n`.
- If `n <= 2000`, line 2 holds the values. Otherwise the values are `1, 2, ..., n`.

**Output (printed by the harness)**
- Line 1: the reordered values separated by spaces (`EMPTY` if `n = 0`). For `n > 2000`, only the first 6 and last 6 values are printed, with ` ... ` between them.
- Line 2: `OK` if the nodes are exactly the original nodes in the required order and the list ends in `NULL`; otherwise `FAIL: ...`.

**Example**
```
Input:
5
1 2 3 4 5

Output:
1 5 2 4 3
OK
```
@@@ constraints_md
- `0 <= n <= 200000`
- O(n) time, O(1) extra memory, no recursion.
@@@ starter_code
#include <stddef.h>

/* Already defined by the judge:
 *
 * struct Node { int val; struct Node *next; };
 */

void list_reorder(struct Node *head)
{
    /* TODO: find the middle, reverse the second half, weave the halves */
    (void)head;
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
    int n;
    if (scanf("%d", &n) != 1 || n < 0 || n > 200000) return 0;
    struct Node **all = malloc((size_t)(n ? n : 1) * sizeof *all);
    if (!all) return 0;
    for (int i = 0; i < n; i++) {
        int v = i + 1;
        if (n <= 2000 && scanf("%d", &v) != 1) return 0;
        all[i] = malloc(sizeof **all);
        if (!all[i]) return 0;
        all[i]->val = v;
        all[i]->next = NULL;
        if (i) all[i - 1]->next = all[i];
    }

    list_reorder(n ? all[0] : NULL);

    if (n == 0) printf("EMPTY");
    int k = 0, ok = 1;
    for (struct Node *p = n ? all[0] : NULL; p != NULL; p = p->next, k++) {
        if (k >= n) { ok = 0; break; }                       /* too long: cycle */
        int want = (k % 2 == 0) ? k / 2 : n - 1 - k / 2;
        if (p != all[want]) ok = 0;
        if (n <= 2000 || k < 6 || k >= n - 6) {
            if (n > 2000 && k == n - 6) printf(" ...");
            printf("%s%d", k ? " " : "", p->val);
        }
    }
    printf("\n");
    if (k != n) ok = 0;
    printf(ok ? "OK\n" : "FAIL: wrong nodes, wrong order or broken list\n");

    for (int i = 0; i < n; i++) free(all[i]);
    free(all);
    return 0;
}
@@@ sample_input
5
1 2 3 4 5
@@@ sample_output
1 5 2 4 3
OK

@@@ sample_input
4
1 2 3 4
@@@ sample_output
1 4 2 3
OK

@@@ hidden_input
0
@@@ hidden_output
EMPTY
OK

@@@ hidden_input
1
7
@@@ hidden_output
7
OK

@@@ hidden_input
2
1 2
@@@ hidden_output
1 2
OK

@@@ hidden_input
3
10 20 30
@@@ hidden_output
10 30 20
OK

@@@ hidden_input
6
9 9 9 9 9 9
@@@ hidden_output
9 9 9 9 9 9
OK

@@@ hidden_input
7
-3 -2 -1 0 1 2 2147483647
@@@ hidden_output
-3 2147483647 -2 2 -1 1 0
OK

@@@ hidden_input
200000
@@@ hidden_output
1 200000 2 199999 3 199998 ... 99998 100003 99999 100002 100000 100001
OK

@@@ hint
Split the problem into three passes you already know: (1) find the middle with slow/fast pointers, (2) cut the list after the middle and reverse the second half, (3) merge the two halves alternately.
@@@ hint
Use `slow = head, fast = head->next` and loop while `fast && fast->next`. Then the first half is `head .. slow` (one node longer for odd n). Set `second = slow->next; slow->next = NULL;`, reverse `second`, and weave: `t1 = a->next; t2 = b->next; a->next = b; b->next = t1; a = t1; b = t2;` until `b` is `NULL`.
@@@ solution_code
#include <stddef.h>

void list_reorder(struct Node *head)
{
    if (head == NULL || head->next == NULL)
        return;

    /* 1. middle: slow ends at the last node of the first half */
    struct Node *slow = head, *fast = head->next;
    while (fast != NULL && fast->next != NULL) {
        slow = slow->next;
        fast = fast->next->next;
    }

    /* 2. cut and reverse the second half */
    struct Node *second = slow->next;
    slow->next = NULL;
    struct Node *prev = NULL;
    while (second != NULL) {
        struct Node *nx = second->next;
        second->next = prev;
        prev = second;
        second = nx;
    }

    /* 3. weave: first half is never shorter than the reversed second half */
    struct Node *a = head, *b = prev;
    while (b != NULL) {
        struct Node *an = a->next;
        struct Node *bn = b->next;
        a->next = b;
        b->next = an;
        a = an;
        b = bn;
    }
}
@@@ explanation_md
**Approach.** Three linear passes combine three classic techniques:
1. **Find the middle** (tortoise and hare). With `fast` starting one node ahead, `slow` stops at the end of the first half: the first half has `ceil(n/2)` nodes and the second has `floor(n/2)`.
2. **Reverse** the second half in place, after cutting the link (`slow->next = NULL`).
3. **Weave** the halves together. Since the first half is never shorter, the loop runs while the reversed half has nodes, and the middle node of an odd list naturally ends up last with `next == NULL`.

```
1 2 3 4 5 -> halves: 1 2 3 | 4 5 -> reverse: 5 4 -> weave: 1 5 2 4 3
1 2 3 4   -> halves: 1 2 | 3 4   -> reverse: 4 3 -> weave: 1 4 2 3
```

**Complexity.** Time O(n) (three passes), space O(1). An array of node pointers or a stack makes the problem easy but costs O(n) memory. A recursive solution needs O(n) stack.

**Common mistakes**
- Forgetting to cut the first half (`slow->next = NULL`). The first half then still points into the reversed second half, which creates a cycle.
- Wrong middle for even lengths (`slow` one node too far). For `1 2 3 4` that gives `1 4 2 3` with a dangling or duplicated node, or `1 3 2 4`-style order errors.
- Saving only one "next" pointer during the weave and losing the rest of a half.
- Swapping values instead of relinking. It fails the identity check and is O(n^2) without extra memory.
- Not handling `n = 0, 1, 2`, where nothing should change.

**Interview follow-ups**
- Undo the operation: given `L0 Ln-1 L1 Ln-2 ...`, restore the original order in O(1) memory.
- Check whether the list is a palindrome with the same "middle + reverse" idea, and restore it afterwards.
- How would the solution change for a **doubly** linked list with a tail pointer?
- Split a list into odd- and even-indexed nodes in one pass (`L0 L2 L4 ... L1 L3 ...`).
