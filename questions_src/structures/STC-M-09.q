@@@ meta
id: STC-M-09
topic: Structures
difficulty: Medium
type: FIND_THE_BUG
title: Unsubscribing the First CAN ID Corrupts the List
tags: embedded, linked-list, delete-node, double-pointer, use-after-free
@@@ statement_md
A CAN gateway keeps a singly linked list of **subscriptions** (CAN IDs that it forwards to another bus). The same ID may be subscribed several times. The program processes commands:

- `ADD <id>`: append a subscription at the tail.
- `DEL <id>`: remove **all** subscriptions with that ID and print `DEL 0x<ID> removed=<count>`.
- `SHOW`: print the IDs from head to tail as `0x%03X` separated by spaces, or `(empty)`.

At the end, every node is freed.

**Symptom.** Removing IDs from the middle or the end of the list works. But as soon as the **first** subscription is removed, later output is garbage or the judge reports a **Runtime Error** (`heap-use-after-free` or `double free`).

Find and fix the bug. The output format must not change.

**Input**
- One command per line (`ADD`/`DEL` take a hex ID).

**Output**
- As described above. `ADD` prints nothing.

**Example**
```
Input:
ADD 100
ADD 200
ADD 300
SHOW
DEL 200
SHOW
DEL 100
SHOW

Output:
0x100 0x200 0x300
DEL 0x200 removed=1
0x100 0x300
DEL 0x100 removed=1
0x300
```
@@@ constraints_md
- At most 1000 commands; IDs are `0x000 .. 0x7FF`.
- Every node must be freed exactly once, and no node may be accessed after being freed.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

struct Sub {
    uint16_t    id;
    struct Sub *next;
};

static void sub_add(struct Sub **head, uint16_t id)
{
    struct Sub *n = malloc(sizeof *n);
    if (n == NULL)
        return;
    n->id = id;
    n->next = NULL;
    while (*head != NULL)
        head = &(*head)->next;
    *head = n;
}

/* Remove every subscription with this id; returns how many were removed. */
static int sub_remove_all(struct Sub *head, uint16_t id)
{
    struct Sub *prev = NULL;
    struct Sub *cur = head;
    int removed = 0;

    while (cur != NULL) {
        if (cur->id == id) {
            struct Sub *dead = cur;
            cur = cur->next;
            if (prev != NULL)
                prev->next = cur;
            else
                head = cur;
            free(dead);
            removed++;
        } else {
            prev = cur;
            cur = cur->next;
        }
    }
    return removed;
}

static void sub_show(const struct Sub *head)
{
    if (head == NULL) {
        printf("(empty)\n");
        return;
    }
    for (const struct Sub *p = head; p != NULL; p = p->next)
        printf("%s0x%03X", p == head ? "" : " ", (unsigned)p->id);
    printf("\n");
}

static void sub_free_all(struct Sub *head)
{
    while (head != NULL) {
        struct Sub *next = head->next;
        free(head);
        head = next;
    }
}

int main(void)
{
    struct Sub *subs = NULL;
    char cmd[8];
    unsigned id;

    while (scanf("%7s", cmd) == 1) {
        if (strcmp(cmd, "SHOW") == 0) {
            sub_show(subs);
        } else if (scanf("%x", &id) == 1) {
            if (strcmp(cmd, "ADD") == 0) {
                sub_add(&subs, (uint16_t)id);
            } else if (strcmp(cmd, "DEL") == 0) {
                int r = sub_remove_all(subs, (uint16_t)id);
                printf("DEL 0x%03X removed=%d\n", id, r);
            }
        }
    }
    sub_free_all(subs);
    return 0;
}
@@@ sample_input
ADD 100
ADD 200
ADD 300
SHOW
DEL 200
SHOW
DEL 100
SHOW
@@@ sample_output
0x100 0x200 0x300
DEL 0x200 removed=1
0x100 0x300
DEL 0x100 removed=1
0x300

@@@ sample_input
DEL 7DF
SHOW
@@@ sample_output
DEL 0x7DF removed=0
(empty)

@@@ hidden_input
ADD 1
ADD 1
ADD 1
DEL 1
SHOW
ADD 2
SHOW
@@@ hidden_output
DEL 0x001 removed=3
(empty)
0x002

@@@ hidden_input
ADD 5
ADD 5
ADD 6
ADD 5
ADD 7
DEL 5
SHOW
@@@ hidden_output
DEL 0x005 removed=3
0x006 0x007

@@@ hidden_input
ADD 1
ADD 2
ADD 3
DEL 3
SHOW
ADD 4
SHOW
@@@ hidden_output
DEL 0x003 removed=1
0x001 0x002
0x001 0x002 0x004

@@@ hidden_input
ADD 7FF
ADD 000
DEL 123
SHOW
@@@ hidden_output
DEL 0x123 removed=0
0x7FF 0x000

@@@ hidden_input
ADD 10
DEL 10
@@@ hidden_output
DEL 0x010 removed=1

@@@ hidden_input
ADD 3
ADD 1
ADD 3
ADD 2
ADD 3
DEL 3
SHOW
DEL 1
SHOW
DEL 2
SHOW
@@@ hidden_output
DEL 0x003 removed=3
0x001 0x002
DEL 0x001 removed=1
0x002
DEL 0x002 removed=1
(empty)

@@@ hidden_input
ADD 10
ADD 111
ADD 212
ADD 313
ADD 414
ADD 515
DEL 616
ADD 717
ADD 18
ADD 10
ADD 111
ADD 212
ADD 313
DEL 414
ADD 515
ADD 616
ADD 717
ADD 18
ADD 10
ADD 111
DEL 212
ADD 313
ADD 414
ADD 515
ADD 616
SHOW
ADD 717
ADD 18
DEL 10
ADD 111
ADD 212
ADD 313
ADD 414
ADD 515
ADD 616
DEL 717
ADD 18
ADD 10
ADD 111
ADD 212
ADD 313
ADD 414
DEL 515
ADD 616
ADD 717
ADD 18
ADD 10
ADD 111
ADD 212
DEL 313
ADD 414
SHOW
ADD 515
ADD 616
ADD 717
ADD 18
ADD 10
DEL 111
ADD 212
ADD 313
ADD 414
ADD 515
ADD 616
ADD 717
DEL 18
ADD 10
ADD 111
ADD 212
ADD 313
ADD 414
ADD 515
DEL 616
ADD 717
ADD 18
ADD 10
ADD 111
ADD 212
SHOW
ADD 313
DEL 414
ADD 515
ADD 616
ADD 717
ADD 18
ADD 10
ADD 111
DEL 212
ADD 313
ADD 414
ADD 515
ADD 616
ADD 717
ADD 18
DEL 10
ADD 111
ADD 212
ADD 313
ADD 414
ADD 515
ADD 616
DEL 717
ADD 18
ADD 10
SHOW
ADD 111
ADD 212
ADD 313
ADD 414
DEL 515
ADD 616
ADD 717
ADD 18
ADD 10
ADD 111
ADD 212
DEL 313
ADD 414
ADD 515
ADD 616
ADD 717
ADD 18
ADD 10
DEL 111
ADD 212
ADD 313
ADD 414
ADD 515
ADD 616
ADD 717
SHOW
DEL 18
ADD 10
ADD 111
ADD 212
ADD 313
ADD 414
ADD 515
DEL 616
ADD 717
ADD 18
ADD 10
ADD 111
ADD 212
ADD 313
DEL 414
ADD 515
ADD 616
ADD 717
ADD 18
ADD 10
ADD 111
DEL 212
ADD 313
ADD 414
ADD 515
SHOW
ADD 616
ADD 717
ADD 18
DEL 10
ADD 111
ADD 212
ADD 313
ADD 414
ADD 515
ADD 616
DEL 717
ADD 18
ADD 10
ADD 111
ADD 212
ADD 313
ADD 414
DEL 515
ADD 616
ADD 717
ADD 18
ADD 10
ADD 111
ADD 212
DEL 313
SHOW
ADD 414
ADD 515
ADD 616
ADD 717
ADD 18
ADD 10
DEL 111
ADD 212
ADD 313
ADD 414
ADD 515
ADD 616
ADD 717
DEL 18
ADD 10
ADD 111
ADD 212
ADD 313
ADD 414
ADD 515
DEL 616
ADD 717
ADD 18
ADD 10
ADD 111
SHOW
ADD 212
ADD 313
DEL 414
ADD 515
ADD 616
ADD 717
ADD 18
ADD 10
ADD 111
DEL 212
ADD 313
ADD 414
ADD 515
ADD 616
ADD 717
ADD 18
DEL 10
ADD 111
ADD 212
ADD 313
ADD 414
ADD 515
ADD 616
DEL 717
ADD 18
SHOW
ADD 10
ADD 111
ADD 212
ADD 313
ADD 414
DEL 515
ADD 616
ADD 717
ADD 18
ADD 10
ADD 111
ADD 212
DEL 313
ADD 414
ADD 515
ADD 616
ADD 717
ADD 18
ADD 10
DEL 111
ADD 212
ADD 313
ADD 414
ADD 515
ADD 616
SHOW
ADD 717
DEL 18
ADD 10
ADD 111
ADD 212
ADD 313
ADD 414
ADD 515
DEL 616
ADD 717
ADD 18
ADD 10
ADD 111
ADD 212
ADD 313
DEL 414
ADD 515
ADD 616
ADD 717
ADD 18
ADD 10
ADD 111
DEL 212
ADD 313
ADD 414
SHOW
ADD 515
ADD 616
ADD 717
ADD 18
DEL 10
ADD 111
ADD 212
ADD 313
ADD 414
ADD 515
ADD 616
DEL 717
ADD 18
ADD 10
ADD 111
ADD 212
ADD 313
ADD 414
DEL 515
ADD 616
ADD 717
ADD 18
ADD 10
ADD 111
ADD 212
SHOW
SHOW
@@@ hidden_output
DEL 0x616 removed=0
DEL 0x414 removed=1
DEL 0x212 removed=2
0x010 0x111 0x313 0x515 0x717 0x018 0x010 0x111 0x313 0x515 0x616 0x717 0x018 0x010 0x111 0x313 0x414 0x515 0x616
DEL 0x010 removed=3
DEL 0x717 removed=3
DEL 0x515 removed=4
DEL 0x313 removed=5
0x111 0x018 0x111 0x616 0x018 0x111 0x414 0x616 0x018 0x111 0x212 0x414 0x616 0x018 0x010 0x111 0x212 0x414 0x616 0x717 0x018 0x010 0x111 0x212 0x414
DEL 0x111 removed=6
DEL 0x018 removed=6
DEL 0x616 removed=6
0x414 0x212 0x414 0x010 0x212 0x414 0x717 0x010 0x212 0x414 0x515 0x717 0x010 0x212 0x313 0x414 0x515 0x717 0x010 0x111 0x212 0x313 0x414 0x515 0x717 0x018 0x010 0x111 0x212
DEL 0x414 removed=6
DEL 0x212 removed=6
DEL 0x010 removed=6
DEL 0x717 removed=6
0x515 0x313 0x515 0x111 0x313 0x515 0x018 0x111 0x313 0x515 0x616 0x018 0x111 0x313 0x414 0x515 0x616 0x018 0x111 0x212 0x313 0x414 0x515 0x616 0x018 0x010
DEL 0x515 removed=6
DEL 0x313 removed=6
DEL 0x111 removed=6
0x018 0x616 0x018 0x414 0x616 0x018 0x212 0x414 0x616 0x018 0x010 0x212 0x414 0x616 0x717 0x018 0x010 0x212 0x414 0x515 0x616 0x717 0x018 0x010 0x212 0x313 0x414 0x515 0x616 0x717
DEL 0x018 removed=6
DEL 0x616 removed=6
DEL 0x414 removed=6
DEL 0x212 removed=6
0x010 0x717 0x010 0x515 0x717 0x010 0x313 0x515 0x717 0x010 0x111 0x313 0x515 0x717 0x018 0x010 0x111 0x313 0x515 0x616 0x717 0x018 0x010 0x111 0x313 0x414 0x515
DEL 0x010 removed=6
DEL 0x717 removed=6
DEL 0x515 removed=6
DEL 0x313 removed=6
0x111 0x018 0x111 0x616 0x018 0x111 0x414 0x616 0x018 0x111 0x212 0x414 0x616 0x018 0x010 0x111 0x212 0x414 0x616 0x717 0x018 0x010 0x111 0x212
DEL 0x111 removed=6
DEL 0x018 removed=6
DEL 0x616 removed=6
0x414 0x212 0x414 0x010 0x212 0x414 0x717 0x010 0x212 0x414 0x515 0x717 0x010 0x212 0x313 0x414 0x515 0x717 0x010 0x111 0x212 0x313 0x414 0x515 0x717 0x018 0x010 0x111
DEL 0x414 removed=6
DEL 0x212 removed=6
DEL 0x010 removed=6
DEL 0x717 removed=6
0x515 0x313 0x515 0x111 0x313 0x515 0x018 0x111 0x313 0x515 0x616 0x018 0x111 0x313 0x414 0x515 0x616 0x018 0x111 0x212 0x313 0x414 0x515 0x616 0x018
DEL 0x515 removed=6
DEL 0x313 removed=6
DEL 0x111 removed=6
0x018 0x616 0x018 0x414 0x616 0x018 0x212 0x414 0x616 0x018 0x010 0x212 0x414 0x616 0x717 0x018 0x010 0x212 0x414 0x515 0x616 0x717 0x018 0x010 0x212 0x313 0x414 0x515 0x616
DEL 0x018 removed=6
DEL 0x616 removed=6
DEL 0x414 removed=6
DEL 0x212 removed=6
0x010 0x717 0x010 0x515 0x717 0x010 0x313 0x515 0x717 0x010 0x111 0x313 0x515 0x717 0x018 0x010 0x111 0x313 0x515 0x616 0x717 0x018 0x010 0x111 0x313 0x414
DEL 0x010 removed=6
DEL 0x717 removed=6
DEL 0x515 removed=6
0x313 0x111 0x313 0x018 0x111 0x313 0x616 0x018 0x111 0x313 0x414 0x616 0x018 0x111 0x212 0x313 0x414 0x616 0x018 0x010 0x111 0x212 0x313 0x414 0x616 0x717 0x018 0x010 0x111 0x212
0x313 0x111 0x313 0x018 0x111 0x313 0x616 0x018 0x111 0x313 0x414 0x616 0x018 0x111 0x212 0x313 0x414 0x616 0x018 0x010 0x111 0x212 0x313 0x414 0x616 0x717 0x018 0x010 0x111 0x212

@@@ hint
C passes every argument by value, and that includes pointers. When the first node is deleted, which variable gets the new head, and does `main` ever see that change?
@@@ hint
Pass the **address** of the head pointer (`struct Sub **head`) and assign through it (`*head = cur`), or return the new head and have the caller store it. `sub_add` already shows the first pattern.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

struct Sub {
    uint16_t    id;
    struct Sub *next;
};

static void sub_add(struct Sub **head, uint16_t id)
{
    struct Sub *n = malloc(sizeof *n);
    if (n == NULL)
        return;
    n->id = id;
    n->next = NULL;
    while (*head != NULL)
        head = &(*head)->next;
    *head = n;
}

/* Remove every subscription with this id; returns how many were removed. */
static int sub_remove_all(struct Sub **head, uint16_t id)   /* FIX: take the address of the head pointer */
{
    struct Sub *prev = NULL;
    struct Sub *cur = *head;                                 /* FIX */
    int removed = 0;

    while (cur != NULL) {
        if (cur->id == id) {
            struct Sub *dead = cur;
            cur = cur->next;
            if (prev != NULL)
                prev->next = cur;
            else
                *head = cur;                                 /* FIX: update the caller's head */
            free(dead);
            removed++;
        } else {
            prev = cur;
            cur = cur->next;
        }
    }
    return removed;
}

static void sub_show(const struct Sub *head)
{
    if (head == NULL) {
        printf("(empty)\n");
        return;
    }
    for (const struct Sub *p = head; p != NULL; p = p->next)
        printf("%s0x%03X", p == head ? "" : " ", (unsigned)p->id);
    printf("\n");
}

static void sub_free_all(struct Sub *head)
{
    while (head != NULL) {
        struct Sub *next = head->next;
        free(head);
        head = next;
    }
}

int main(void)
{
    struct Sub *subs = NULL;
    char cmd[8];
    unsigned id;

    while (scanf("%7s", cmd) == 1) {
        if (strcmp(cmd, "SHOW") == 0) {
            sub_show(subs);
        } else if (scanf("%x", &id) == 1) {
            if (strcmp(cmd, "ADD") == 0) {
                sub_add(&subs, (uint16_t)id);
            } else if (strcmp(cmd, "DEL") == 0) {
                int r = sub_remove_all(&subs, (uint16_t)id);   /* FIX: pass &subs */
                printf("DEL 0x%03X removed=%d\n", id, r);
            }
        }
    }
    sub_free_all(subs);
    return 0;
}
@@@ explanation_md
**Bug.** `sub_remove_all(struct Sub *head, ...)` receives a **copy** of `main`'s `subs` pointer. When the first node matches, `head = cur;` updates only that local copy. `main` still points at the node that was just freed, so:
- the next `SHOW` reads freed memory (`heap-use-after-free`);
- the final `sub_free_all` frees it again (`double free`);
- without sanitizers, the output shows whatever the allocator wrote into the freed chunk.

Deleting from the middle or the tail works, because there the change goes through `prev->next`, which lives inside a node both sides can see. That is why this bug often survives unit tests.

**Fix.** Pass `&subs` and write `*head = cur`. The alternative is to return the new head (`subs = sub_remove_all(subs, id, &removed);`). An even cleaner version uses the same pointer-to-pointer walk as `sub_add` and needs no `prev` at all:
```c
struct Sub **pp = head;
while (*pp) {
    if ((*pp)->id == id) { struct Sub *d = *pp; *pp = d->next; free(d); removed++; }
    else pp = &(*pp)->next;
}
```

**Complexity.** `DEL` is O(n), `ADD` is O(n) (walk to the tail), and space is O(n).

**Common mistakes**
- "Fixing" it by refusing to delete the head, or by copying the second node's data into the head (this breaks external pointers to nodes, and the last node can't be deleted that way).
- Updating `*head` but forgetting the initial `cur = *head`, which no longer compiles once the type changes, or worse, compiles with a cast.
- Advancing `prev` after a deletion. `prev` must stay where it is when `cur` is removed, otherwise consecutive matches (`5 5 6 5`) are skipped.

**Interview follow-ups**
- Rewrite `sub_remove_all` with the `struct Sub **pp` idiom (Linus Torvalds' "good taste" example). Why does it eliminate the special case?
- `ADD` is O(n) because it walks to the tail. How do you make it O(1), and which invariant must `DEL` then maintain?
- The gateway's RX interrupt reads this list while a task modifies it. What must you protect, and why is "free after unlink" dangerous without RCU-style deferral?
- How would you make lookup O(1) for 2048 possible 11-bit IDs?
