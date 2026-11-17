@@@ meta
id: PTR-M-10
topic: Pointers
difficulty: Medium
type: FUNCTION
title: Linked-List Insert and Remove-All with a Pointer to Pointer
tags: pointer-to-pointer, linked-list, indirect-pointer, stable-insert, asked-in-automotive
@@@ statement_md
The "good taste" linked-list technique walks a list with a **pointer to the link** (`struct node **pp`) instead of a pointer to the node. The head pointer and every `next` field are then handled by the same code, and you need no special case for the head.

Implement both functions with this technique:

```c
struct node {
    int value;
    int id;              /* set by the caller; do not change */
    struct node *next;
};

void   list_insert_sorted(struct node **head, struct node *n);
size_t list_remove_value(struct node **head, int value);
```

- `list_insert_sorted` links node `n` into the list, which is kept in **ascending** `value` order. If nodes with the same value already exist, `n` goes **after** them (stable insertion).
- `list_remove_value` unlinks **every** node whose `value` equals `value` and returns how many were removed. The nodes belong to the caller, so do **not** free them; just unlink them. The other nodes must keep their relative order.
- `*head` is `NULL` for an empty list. Both functions may change `*head`.

**How it is tested.** A hidden `main()` takes nodes from a static pool. Node `k` gets `id = k`, in the order of the insert commands. After each command the harness prints the list as `value#id`, separated by spaces (or `(empty)`).

**Input (read by the hidden harness)**: one command per line.
- `I v`: insert a fresh node with value `v`, then print the list.
- `R v`: remove all nodes with value `v`, then print `removed <count>: <list>`.

**Example**
```
Input:
I 5
I 3
I 5
I 9
R 5

Output:
5#0
3#1 5#0
3#1 5#0 5#2
3#1 5#0 5#2 9#3
removed 2: 3#1 9#3
```
@@@ constraints_md
- At most 100 commands; values are 32-bit `int` (`INT_MIN`/`INT_MAX` allowed).
- O(n) per operation, O(1) extra memory, no allocation.
@@@ starter_code
#include <stddef.h>

struct node {
    int value;
    int id;
    struct node *next;
};

void list_insert_sorted(struct node **head, struct node *n)
{
    /* TODO: walk with struct node **pp = head; */
}

size_t list_remove_value(struct node **head, int value)
{
    /* TODO */
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stddef.h>

/*USER_CODE*/

#define POOL 100
static struct node pool[POOL];
static int used;

static void print_list(const struct node *head)
{
    int count = 0;
    if (head == NULL) {
        printf("(empty)\n");
        return;
    }
    for (const struct node *p = head; p != NULL; p = p->next) {
        if (p < pool || p >= pool + used || ++count > used) {
            printf("LIST CORRUPTED\n");
            return;
        }
        printf("%d#%d%c", p->value, p->id, p->next ? ' ' : '\n');
    }
}

int main(void)
{
    struct node *head = NULL;
    char op;
    int v;
    while (scanf(" %c %d", &op, &v) == 2 && used < POOL) {
        if (op == 'I') {
            struct node *n = &pool[used];
            n->value = v;
            n->id = used;
            n->next = (struct node *)&pool[POOL - 1];   /* garbage link: must be overwritten */
            used++;
            list_insert_sorted(&head, n);
            print_list(head);
        } else {
            size_t r = list_remove_value(&head, v);
            printf("removed %zu: ", r);
            print_list(head);
        }
    }
    return 0;
}
@@@ sample_input
I 5
I 3
I 5
I 9
R 5
@@@ sample_output
5#0
3#1 5#0
3#1 5#0 5#2
3#1 5#0 5#2 9#3
removed 2: 3#1 9#3

@@@ sample_input
R 1
I 1
R 1
@@@ sample_output
removed 0: (empty)
1#0
removed 1: (empty)

@@@ hidden_input
I 2
I 2
I 2
I 3
R 2
@@@ hidden_output
2#0
2#0 2#1
2#0 2#1 2#2
2#0 2#1 2#2 3#3
removed 3: 3#3

@@@ hidden_input
I 1
I 2
I 3
R 3
@@@ hidden_output
1#0
1#0 2#1
1#0 2#1 3#2
removed 1: 1#0 2#1

@@@ hidden_input
I 10
I -2147483648
I 2147483647
I -2147483648
@@@ hidden_output
10#0
-2147483648#1 10#0
-2147483648#1 10#0 2147483647#2
-2147483648#1 -2147483648#3 10#0 2147483647#2

@@@ hidden_input
I 1
I 2
I 1
I 2
I 1
R 2
R 1
@@@ hidden_output
1#0
1#0 2#1
1#0 1#2 2#1
1#0 1#2 2#1 2#3
1#0 1#2 1#4 2#1 2#3
removed 2: 1#0 1#2 1#4
removed 3: (empty)

@@@ hidden_input
I 4
I 6
R 5
@@@ hidden_output
4#0
4#0 6#1
removed 0: 4#0 6#1

@@@ hidden_input
I 7
R 7
I 7
I 0
@@@ hidden_output
7#0
removed 1: (empty)
7#1
0#2 7#1

@@@ hint
Start with `struct node **pp = head;`. `*pp` is "the pointer that currently points to the node under consideration": first the head pointer, later some `next` field. To advance, take the address of the next link: `pp = &(*pp)->next;`.
@@@ hint
Insert: advance while `*pp != NULL && (*pp)->value <= n->value` (`<=` makes it stable), then `n->next = *pp; *pp = n;`. Remove: if `(*pp)->value == value`, unlink with `*pp = (*pp)->next;` and do **not** advance (the new `*pp` must be checked too); otherwise advance.
@@@ solution_code
#include <stddef.h>

struct node {
    int value;
    int id;
    struct node *next;
};

void list_insert_sorted(struct node **head, struct node *n)
{
    struct node **pp = head;                 /* address of the link we may rewrite */

    while (*pp != NULL && (*pp)->value <= n->value)
        pp = &(*pp)->next;                   /* step to the next link field */
    n->next = *pp;                           /* works for head, middle and tail alike */
    *pp = n;
}

size_t list_remove_value(struct node **head, int value)
{
    size_t removed = 0;
    struct node **pp = head;

    while (*pp != NULL) {
        if ((*pp)->value == value) {
            *pp = (*pp)->next;               /* unlink; stay on the same link */
            removed++;
        } else {
            pp = &(*pp)->next;
        }
    }
    return removed;
}
@@@ explanation_md
**Approach.** With a plain `struct node *cur` you have to remember the previous node to change its `next`, and the head needs a special case because it has no previous node. A `struct node **pp` instead points at **whichever pointer currently leads to the node**: first `head` itself, later `prev->next`. Rewriting `*pp` therefore relinks the list correctly in every position:

```
head ──► [3] ──► [5] ──► [5] ──► [9] ──► NULL
 ^pp      ^ pp = &head->next ...
remove 5:  *pp = (*pp)->next   (pp stays, the next 5 is checked too)
head ──► [3] ──────────────────► [9] ──► NULL
```

- *Insert:* skip all nodes with `value <= new` (that makes it stable), then splice: `n->next = *pp; *pp = n;`.
- *Remove all:* unlink with `*pp = (*pp)->next` without advancing, so runs of equal values are handled. Otherwise advance `pp`.

**Complexity.** Both operations take O(n) time and O(1) extra space.

**Common mistakes**
- Passing `struct node *head` instead of `struct node **head`. Inserting before the first node or removing it then changes only a local copy, and the caller's `head` still points to the old first node.
- Advancing after unlinking. That skips the node that moved into `*pp`, so `R 2` on `2 2 2` removes only some of them.
- Using `<` instead of `<=` in insert. That breaks stability (`5#2` before `5#0`).
- Not setting `n->next` (the harness gives each new node a garbage link). The list then gets a cycle or a dangling tail.
- Calling `free` on the unlinked nodes. Ownership stays with the caller; in embedded code the nodes are often in static pools or embedded in other structs.

**Interview follow-ups**
- Write `list_remove_if(struct node **head, int (*pred)(const struct node *, void *), void *ctx)`.
- Reverse a singly linked list in place. Can you do it recursively without `O(n)` stack on a small MCU?
- How does this technique carry over to deleting from a binary search tree (`struct tree **link`)?
- Why do the Linux kernel and many RTOSes prefer **intrusive** lists (the `next` pointer embedded in the object) over lists that allocate separate nodes?
