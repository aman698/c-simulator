@@@ meta
id: MEM-E-09
topic: Dynamic Memory
difficulty: Easy
type: FUNCTION
title: Truncate a Linked Log and Free Its Tail
tags: embedded, linked-list, free, dangling-pointer, double-pointer
@@@ statement_md
A gateway ECU keeps its recent diagnostic events in a singly linked list of heap nodes, newest first. When memory gets low, it keeps only the newest `k` events and releases the rest. Implement

```c
struct node {
    int value;
    struct node *next;
};

int list_truncate(struct node **head, int k);
```

- Keep the first `k` nodes. Free **every** node after them, and return the number of nodes freed.
- The new last node must end the list (`next == NULL`). Do not leave it pointing at freed memory.
- If `k <= 0`, free the whole list and set `*head = NULL`.
- If the list has `k` nodes or fewer, change nothing and return 0.
- If `head` itself is `NULL`, return 0.

**How it is tested.** The hidden `main()` builds each list with `malloc` (in input order, so the first value is the head) and calls `list_truncate(&head, k)`. It then prints the return value, walks the remaining list, and frees it. A node that is not freed is reported as a **Memory Leak**. A dangling `next` pointer makes the walk read freed memory, which is a **Runtime Error**.

**Input (read by the hidden harness)**
- Line 1: `T`, the number of cases.
- Each case: a line `n k`, then a line with `n` values (the line is empty or absent when `n = 0`).

**Output (printed by the harness)**
- Per case: `freed=<r> list: <values...>`, or `freed=<r> list: (empty)`.

**Example**
```
Input:
1
5 2
50 40 30 20 10

Output:
freed=3 list: 50 40
```
@@@ constraints_md
- `1 <= T <= 20`, `0 <= n <= 1000`, `-5 <= k <= 2000`
- Values fit in an `int`.
- Use `free` only on nodes after position `k`. Do not reallocate or copy nodes.
@@@ starter_code
#include <stdlib.h>

struct node {
    int value;
    struct node *next;
};

/* Keep the first k nodes, free the rest, return how many were freed. */
int list_truncate(struct node **head, int k)
{
    /* TODO */
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>

/*USER_CODE*/

int main(void)
{
    int t;
    if (list_truncate(NULL, 0) != 0)
        printf("FAIL: list_truncate(NULL, 0) must return 0\n");
    if (scanf("%d", &t) != 1)
        return 0;
    while (t-- > 0) {
        int n, k;
        if (scanf("%d %d", &n, &k) != 2)
            return 0;
        struct node *head = NULL, **tail = &head;
        for (int i = 0; i < n; i++) {
            struct node *nd = malloc(sizeof *nd);
            if (nd == NULL)
                return 1;
            if (scanf("%d", &nd->value) != 1)
                nd->value = 0;
            nd->next = NULL;
            *tail = nd;
            tail = &nd->next;
        }

        int r = list_truncate(&head, k);
        printf("freed=%d list:", r);
        if (head == NULL)
            printf(" (empty)");
        int guard = 0;
        for (struct node *p = head; p != NULL && guard <= n; p = p->next, guard++)
            printf(" %d", p->value);
        printf("\n");

        while (head != NULL) {               /* harness frees what is left */
            struct node *next = head->next;
            free(head);
            head = next;
        }
    }
    return 0;
}
@@@ sample_input
1
5 2
50 40 30 20 10
@@@ sample_output
freed=3 list: 50 40

@@@ sample_input
2
3 0
1 2 3
3 3
7 8 9
@@@ sample_output
freed=3 list: (empty)
freed=0 list: 7 8 9

@@@ hidden_input
1
0 3
@@@ hidden_output
freed=0 list: (empty)

@@@ hidden_input
1
1 1
42
@@@ hidden_output
freed=0 list: 42

@@@ hidden_input
1
1 0
42
@@@ hidden_output
freed=1 list: (empty)

@@@ hidden_input
3
4 1
-1 -2 -3 -4
4 -5
5 5 5 5
2 2000
1 2
@@@ hidden_output
freed=3 list: -1
freed=4 list: (empty)
freed=0 list: 1 2

@@@ hidden_input
2
6 5
1 2 3 4 5 6
6 4
2147483647 -2147483648 0 1 2 3
@@@ hidden_output
freed=1 list: 1 2 3 4 5
freed=2 list: 2147483647 -2147483648 0 1

@@@ hidden_input
1
10 3
10 9 8 7 6 5 4 3 2 1
@@@ hidden_output
freed=7 list: 10 9 8

@@@ hint
Walk `k - 1` steps to reach the node that will become the new last node. Everything after it must go. Handle `k <= 0` separately, because then the "cut point" is the head pointer itself.
@@@ hint
Use a pointer-to-pointer: walk `struct node **link = head` forward `k` times (`link = &(*link)->next`). Then detach the tail with `struct node *rest = *link; *link = NULL;`, and free `rest` node by node, saving `next` **before** each `free`.
@@@ solution_code
#include <stdlib.h>

struct node {
    int value;
    struct node *next;
};

/* Keep the first k nodes, free the rest, return how many were freed. */
int list_truncate(struct node **head, int k)
{
    if (head == NULL)
        return 0;

    /* link points at the pointer that must become NULL: *head for k <= 0,
       otherwise the next field of the k-th node */
    struct node **link = head;
    for (int i = 0; i < k && *link != NULL; i++)
        link = &(*link)->next;

    struct node *rest = *link;
    *link = NULL;                 /* cut first: no dangling pointer survives */

    int freed = 0;
    while (rest != NULL) {
        struct node *next = rest->next;   /* read BEFORE free */
        free(rest);
        rest = next;
        freed++;
    }
    return freed;
}
@@@ explanation_md
**Approach.** Find the **link** that must become `NULL`. That is `*head` when `k <= 0`, otherwise the `next` field of node `k`. A `struct node **` covers both cases with no special case for the head. Detach the tail by storing `NULL` into that link, then free the detached nodes one by one.

```
k = 2:  head -> [50] -> [40] -> [30] -> [20] -> [10] -> NULL
                          link ──^ (&node40->next)
after:  head -> [50] -> [40] -> NULL      freed: 30, 20, 10
```

**Free loop.** `free(p); p = p->next;` reads `p->next` from memory that was just freed. That is a use-after-free. It often "works" on a desktop and fails under ASan or on an RTOS heap. Always save `next` first.

**Complexity.** Time O(n), where n is the list length (walk + free). Extra space O(1).

**Common mistakes**
- Freeing the tail but leaving `node_k->next` pointing at it. The next traversal walks into freed memory.
- Reading `p->next` after `free(p)`.
- Passing `struct node *head` instead of `struct node **head`. For `k <= 0` the caller's head would keep pointing to freed memory.
- Off-by-one: keeping `k + 1` or `k - 1` nodes. Test with `k = 1` and `k = n`.

**Interview follow-ups**
- Write `list_destroy(struct node **head)` recursively. Why is the recursive version dangerous on an MCU with a 2 KB stack and a 10,000-node list?
- In an ECU with no `malloc`, these nodes come from a fixed pool. What changes in the free loop? (`pool_free(node)` instead of `free`; the logic stays the same.)
- How would you keep the **oldest** `k` events instead, if the list is newest-first?
