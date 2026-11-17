@@@ meta
id: STC-E-08
topic: Structures
difficulty: Easy
type: FUNCTION
title: Reverse a Singly Linked List In Place
tags: linked-list, self-referential-struct, reversal, iterative, misra
@@@ statement_md
An event logger pushes every new event at the **head** of a singly linked list, so the list is newest-first. Before the log is dumped over UART it must be turned oldest-first. Implement

```c
struct Node {
    int          val;
    struct Node *next;
};

struct Node *list_reverse(struct Node *head);
```

which reverses the list **in place** and returns the new head.

- Relink the existing nodes. Do not allocate nodes and do not copy or swap `val` fields. The harness checks node identity.
- No recursion (MISRA C:2012 Rule 17.2). One hidden test has 200000 nodes, and a recursive version overflows the stack.
- `head` may be `NULL`.

`struct Node` is already defined by the judge.

**Input (read by the hidden harness)**
- Line 1: `n`.
- If `n <= 2000`, line 2 holds the `n` values from head to tail. If `n > 2000`, there is no second line and the harness uses the values `1, 2, ..., n`.

**Output (printed by the harness)**
- Line 1: the reversed list, values separated by spaces (`EMPTY` if `n = 0`). For `n > 2000` only the first 5 and last 5 values are printed, with ` ... ` between them.
- Line 2: `OK` if the result consists of exactly the original nodes in reverse order and ends in `NULL`, otherwise a `FAIL:` message.

**Example**
```
Input:
5
1 2 3 4 5

Output:
5 4 3 2 1
OK
```
@@@ constraints_md
- `0 <= n <= 200000`
- Values fit in a 32-bit `int`.
- O(n) time, O(1) extra memory, no recursion.
@@@ starter_code
#include <stddef.h>

/* Already defined by the judge:
 *
 * struct Node { int val; struct Node *next; };
 */

struct Node *list_reverse(struct Node *head)
{
    /* TODO: reverse in place, return the new head */
    return head;
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
    struct Node *head = NULL, *tail = NULL;
    for (int i = 0; i < n; i++) {
        int v = i + 1;
        if (n <= 2000 && scanf("%d", &v) != 1) return 0;
        struct Node *nd = malloc(sizeof *nd);
        if (!nd) return 0;
        nd->val = v;
        nd->next = NULL;
        if (tail) tail->next = nd; else head = nd;
        tail = nd;
        all[i] = nd;
    }

    head = list_reverse(head);

    /* print (bounded walk so a cycle cannot hang the harness) */
    if (head == NULL) {
        printf("EMPTY\n");
    } else {
        int k = 0;
        for (struct Node *p = head; p && k <= n; p = p->next, k++) {
            if (n > 2000 && k >= 5 && k < n - 5) {
                if (k == 5) printf(" ...");
                continue;
            }
            printf("%s%d", k ? " " : "", p->val);
        }
        printf("\n");
    }

    /* identity check: k-th node of the result must be the original node n-1-k */
    int k = 0, ok = 1;
    for (struct Node *p = head; p && k <= n; p = p->next, k++)
        if (k >= n || p != all[n - 1 - k]) { ok = 0; break; }
    if (ok && k != n) ok = 0;
    printf(ok ? "OK\n" : "FAIL: result is not the original nodes in reverse order\n");

    for (int i = 0; i < n; i++) free(all[i]);
    free(all);
    return 0;
}
@@@ sample_input
5
1 2 3 4 5
@@@ sample_output
5 4 3 2 1
OK

@@@ sample_input
0
@@@ sample_output
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
2 1
OK

@@@ hidden_input
4
3 3 1 3
@@@ hidden_output
3 1 3 3
OK

@@@ hidden_input
3
-2147483648 0 2147483647
@@@ hidden_output
2147483647 0 -2147483648
OK

@@@ hidden_input
6
10 20 30 40 50 60
@@@ hidden_output
60 50 40 30 20 10
OK

@@@ hidden_input
200000
@@@ hidden_output
200000 199999 199998 199997 199996 ... 5 4 3 2 1
OK

@@@ hint
Keep three pointers: `prev` (the reversed part so far, initially `NULL`), `cur` (the node being moved) and `next` (saved before you overwrite `cur->next`).
@@@ hint
Loop: `next = cur->next; cur->next = prev; prev = cur; cur = next;`. When `cur` becomes `NULL`, `prev` is the new head. The old head automatically ends with `next = NULL`.
@@@ solution_code
#include <stddef.h>

struct Node *list_reverse(struct Node *head)
{
    struct Node *prev = NULL;
    struct Node *cur = head;

    while (cur != NULL) {
        struct Node *next = cur->next;   /* save the rest before breaking the link */
        cur->next = prev;                /* point this node backwards               */
        prev = cur;                      /* reversed part grows by one              */
        cur = next;                      /* continue with the unreversed part       */
    }
    return prev;                         /* NULL for an empty list */
}
@@@ explanation_md
**Approach.** Iterate once and flip each `next` pointer. At every step the list is split into a reversed prefix (`prev`) and an untouched suffix (`cur`):

```
prev=NULL  cur=1->2->3
step 1: 1->NULL          | 2->3
step 2: 2->1->NULL       | 3
step 3: 3->2->1->NULL    | (empty)  -> return prev
```

**Complexity.** Time O(n), space O(1). The recursive version is also O(n) time, but it uses O(n) **stack**. With 200000 nodes it needs several megabytes and crashes, and on an MCU with a 2 KB task stack it fails after a few dozen nodes.

**Common mistakes**
- Overwriting `cur->next` before saving it, which loses the rest of the list.
- Returning `head` (now the tail) instead of `prev`.
- Leaving the old head's `next` pointing at the second node. That makes a 2-node cycle (`1 <-> 2`); the harness reports it as "too many nodes".
- Swapping values instead of relinking. That is O(n) with an index array, or O(n^2) without one, and it breaks every external pointer to a node.

**Interview follow-ups**
- Reverse only the sublist between positions `m` and `n`, in one pass.
- Reverse the list in groups of `k` (k = 3: `1 2 3 4 5 6 7 -> 3 2 1 6 5 4 7`).
- Check whether a list is a palindrome in O(1) extra space. (Find the middle, reverse the second half, compare, and restore it.)
- Why does MISRA C forbid recursion, and how would you prove a stack bound for code that uses it anyway?
