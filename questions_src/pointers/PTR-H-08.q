@@@ meta
id: PTR-H-08
topic: Pointers
difficulty: Hard
type: FUNCTION
title: RTOS Software Timers on an Intrusive List with container_of
tags: embedded, container-of, intrusive-list, offsetof, rtos, callback
@@@ statement_md
RTOS kernels and the Linux kernel avoid allocating list nodes. Instead, the list links are **embedded inside the objects** (an *intrusive* list), and the enclosing object is recovered from a pointer to its link member with **`container_of`**. Build the software-timer queue of a small RTOS this way.

```c
struct list_head {
    struct list_head *next, *prev;
};

struct sw_timer {
    char name[8];
    uint32_t expiry;          /* absolute tick */
    uint32_t period;          /* used by the caller's callback; 0 = one-shot */
    struct list_head link;    /* NOT the first member! */
};
```

The queue is a **circular doubly linked list with a sentinel** head: an empty list has `h->next == h->prev == h`. A timer that is in no list has its `link` pointing to itself.

Implement:
- `container_of(ptr, type, member)` (a macro): given a pointer to `member` inside a `type` object, yield a pointer to that object.
- `void list_init(struct list_head *h)`: make `h` an empty list / an unlinked node.
- `void timer_add(struct list_head *h, struct sw_timer *t)`: insert `t` (currently unlinked) so the queue stays sorted by **ascending `expiry`**. Timers with equal expiry keep insertion order, so `t` goes after them.
- `int timer_cancel(struct sw_timer *t)`: if `t` is queued, unlink it (leaving it self-linked) and return 1. Otherwise return 0.
- `int timer_expire(struct list_head *h, uint32_t now, void (*fire)(struct sw_timer *))`: while the first timer has `expiry <= now`, unlink it (self-linked), then call `fire(t)`. Return the number of timers fired.
  - **The callback may call `timer_add` on the same queue** (periodic timers re-arm themselves with `expiry += period`). A re-armed timer that is due again fires again in the same call.

**How it is tested.** The harness owns up to 16 timers (each initialised with `list_init(&t->link)`) and a queue head. Its `fire` callback prints `  fire <name>@<expiry>` and re-arms the timer if `period > 0`. The harness walks the queue with **your** `container_of` and checks the `prev` links.

**Commands**
- `add NAME EXP PERIOD`: set the fields and call `timer_add` (prints nothing).
- `cancel NAME`: prints `cancel NAME -> R`.
- `tick NOW`: prints the fired timers, then `tick NOW -> R`.
- `list`: prints `list: name@expiry ...` or `list: (empty)`.

**Example**
```
Input:
add a 30 0
add b 10 0
add c 20 0
add d 20 0
list
tick 20
list

Output:
list: b@10 c@20 d@20 a@30
  fire b@10
  fire c@20
  fire d@20
tick 20 -> 3
list: a@30
```
@@@ constraints_md
- At most 16 timers and 60 commands; `0 <= expiry < 2^31` (no wrap-around handling needed).
- No dynamic memory. O(n) per insertion, O(1) per cancel.
- `add` is only used on timers that are not queued.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>

struct list_head {
    struct list_head *next, *prev;
};

struct sw_timer {
    char name[8];
    uint32_t expiry;
    uint32_t period;
    struct list_head link;    /* NOT the first member */
};

/* TODO: this naive cast is wrong because `link` is not the first member */
#define container_of(ptr, type, member) ((type *)(ptr))

void list_init(struct list_head *h)
{
    /* TODO */
    (void)h;
}

void timer_add(struct list_head *h, struct sw_timer *t)
{
    /* TODO: sorted, stable insert */
    (void)h;
    (void)t;
}

int timer_cancel(struct sw_timer *t)
{
    /* TODO */
    (void)t;
    return 0;
}

int timer_expire(struct list_head *h, uint32_t now, void (*fire)(struct sw_timer *))
{
    /* TODO */
    (void)h;
    (void)now;
    (void)fire;
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include <stdint.h>

/*USER_CODE*/

#define MAXT 16
static struct list_head queue;
static struct sw_timer timers[MAXT];
static int ntimers;

static struct sw_timer *timer_by_name(const char *nm)
{
    for (int i = 0; i < ntimers; i++)
        if (strcmp(timers[i].name, nm) == 0) return &timers[i];
    if (ntimers == MAXT) return NULL;
    struct sw_timer *t = &timers[ntimers++];
    snprintf(t->name, sizeof t->name, "%.7s", nm);
    list_init(&t->link);
    return t;
}

static void on_fire(struct sw_timer *t)
{
    if (t < timers || t >= timers + ntimers) {
        printf("  FIRE WITH BAD TIMER POINTER\n");
        return;
    }
    printf("  fire %s@%u\n", t->name, (unsigned)t->expiry);
    if (t->period > 0) {
        t->expiry += t->period;
        timer_add(&queue, t);
    }
}

static void print_list(void)
{
    int count = 0;
    printf("list:");
    if (queue.next == &queue && queue.prev == &queue) {
        printf(" (empty)\n");
        return;
    }
    for (struct list_head *p = queue.next; p != &queue; p = p->next) {
        if (p->next->prev != p || p->prev->next != p || ++count > MAXT) {
            printf(" BROKEN LINKS\n");
            return;
        }
        struct sw_timer *t = container_of(p, struct sw_timer, link);
        if (t < timers || t >= timers + ntimers) {
            printf(" BAD CONTAINER POINTER\n");
            return;
        }
        printf(" %s@%u", t->name, (unsigned)t->expiry);
    }
    printf("\n");
}

int main(void)
{
    char cmd[16], nm[16];
    list_init(&queue);
    while (scanf("%15s", cmd) == 1) {
        if (strcmp(cmd, "add") == 0) {
            unsigned e, per;
            if (scanf("%15s %u %u", nm, &e, &per) != 3) return 0;
            struct sw_timer *t = timer_by_name(nm);
            if (t == NULL) return 0;
            t->expiry = e;
            t->period = per;
            timer_add(&queue, t);
        } else if (strcmp(cmd, "cancel") == 0) {
            if (scanf("%15s", nm) != 1) return 0;
            struct sw_timer *t = timer_by_name(nm);
            if (t == NULL) return 0;
            int r = timer_cancel(t);
            printf("cancel %s -> %d%s\n", nm, r,
                   (t->link.next == &t->link && t->link.prev == &t->link) ? "" : " NOT SELF-LINKED");
        } else if (strcmp(cmd, "tick") == 0) {
            unsigned now;
            if (scanf("%u", &now) != 1) return 0;
            int r = timer_expire(&queue, now, on_fire);
            printf("tick %u -> %d\n", now, r);
        } else if (strcmp(cmd, "list") == 0) {
            print_list();
        }
    }
    return 0;
}
@@@ sample_input
add a 30 0
add b 10 0
add c 20 0
add d 20 0
list
tick 20
list
@@@ sample_output
list: b@10 c@20 d@20 a@30
  fire b@10
  fire c@20
  fire d@20
tick 20 -> 3
list: a@30

@@@ sample_input
add hb 10 10
add io 15 0
tick 35
list
cancel hb
cancel io
list
@@@ sample_output
  fire hb@10
  fire io@15
  fire hb@20
  fire hb@30
tick 35 -> 4
list: hb@40
cancel hb -> 1
cancel io -> 0
list: (empty)

@@@ hidden_input
tick 100
list
cancel x
@@@ hidden_output
tick 100 -> 0
list: (empty)
cancel x -> 0

@@@ hidden_input
add p 5 0
add q 5 0
add r 5 0
cancel q
list
tick 4
tick 5
list
@@@ hidden_output
cancel q -> 1
list: p@5 r@5
tick 4 -> 0
  fire p@5
  fire r@5
tick 5 -> 2
list: (empty)

@@@ hidden_input
add x 1 0
tick 1
cancel x
add x 7 0
list
cancel x
cancel x
list
@@@ hidden_output
  fire x@1
tick 1 -> 1
cancel x -> 0
list: x@7
cancel x -> 1
cancel x -> 0
list: (empty)

@@@ hidden_input
add f 0 3
add g 4 0
tick 10
list
@@@ hidden_output
  fire f@0
  fire f@3
  fire g@4
  fire f@6
  fire f@9
tick 10 -> 5
list: f@12

@@@ hidden_input
add a 10 10
add b 20 0
tick 10
list
@@@ hidden_output
  fire a@10
tick 10 -> 1
list: b@20 a@20

@@@ hidden_input
add m 2147483647 0
add n 0 0
add o 1000 0
list
tick 999
list
@@@ hidden_output
list: n@0 o@1000 m@2147483647
  fire n@0
tick 999 -> 1
list: o@1000 m@2147483647

@@@ hint
`container_of` subtracts the member's offset from the member's address, using **byte** arithmetic: `((type *)((char *)(ptr) - offsetof(type, member)))`. Casting the link pointer directly to `struct sw_timer *` is wrong whenever `link` is not at offset 0.
@@@ hint
Write two private helpers: `insert_before(pos, node)` (four pointer assignments) and `unlink(node)` (two assignments, then `list_init(node)` so it is self-linked). Insertion walks from `h->next` while `entry->expiry <= t->expiry`, then inserts before the stopping node (which may be `h` itself, meaning "at the tail"). In `timer_expire`, re-read `h->next` on every iteration, because the callback may have changed the list.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>

struct list_head {
    struct list_head *next, *prev;
};

struct sw_timer {
    char name[8];
    uint32_t expiry;
    uint32_t period;
    struct list_head link;    /* NOT the first member */
};

/* member pointer -> enclosing object: step back by the member's offset, in bytes */
#define container_of(ptr, type, member) \
    ((type *)(void *)((char *)(ptr) - offsetof(type, member)))

void list_init(struct list_head *h)
{
    h->next = h;
    h->prev = h;
}

static void insert_before(struct list_head *pos, struct list_head *node)
{
    node->prev = pos->prev;
    node->next = pos;
    pos->prev->next = node;
    pos->prev = node;
}

static void unlink_node(struct list_head *node)
{
    node->prev->next = node->next;
    node->next->prev = node->prev;
    list_init(node);                       /* self-linked = "not queued" */
}

void timer_add(struct list_head *h, struct sw_timer *t)
{
    struct list_head *pos = h->next;
    while (pos != h && container_of(pos, struct sw_timer, link)->expiry <= t->expiry)
        pos = pos->next;                   /* <= keeps equal expiries in insertion order */
    insert_before(pos, &t->link);          /* pos == h means append at the tail */
}

int timer_cancel(struct sw_timer *t)
{
    if (t->link.next == &t->link)
        return 0;                          /* not queued */
    unlink_node(&t->link);
    return 1;
}

int timer_expire(struct list_head *h, uint32_t now, void (*fire)(struct sw_timer *))
{
    int fired = 0;
    while (h->next != h) {                 /* re-read the head: fire() may re-arm timers */
        struct sw_timer *t = container_of(h->next, struct sw_timer, link);
        if (t->expiry > now)
            break;
        unlink_node(&t->link);             /* unlink BEFORE the callback */
        fire(t);
        fired++;
    }
    return fired;
}
@@@ explanation_md
**Approach.**

*container_of.* The queue only knows `struct list_head`. To get from a link back to its timer, subtract the link's offset inside `struct sw_timer` from the link's address:

```
struct sw_timer @ 0x1000:  name[8] | expiry | period | link(next,prev)
                           0x1000            0x1010 <- &t->link
container_of(0x1010, struct sw_timer, link) = 0x1010 - offsetof(..., link) = 0x1000
```

The subtraction must be done on a `char *` (byte arithmetic); `offsetof` supplies the byte distance at compile time. A plain cast works only when the member happens to be first, which is why the starter's version fails here.

*Sentinel circular list.* With a head node that is never a timer, insertion and removal never deal with `NULL`: every node always has a valid `prev` and `next`. Self-linking an unlinked node gives a cheap "am I queued?" test and makes a double `cancel` harmless.

*Callback-safe expiry.* `fire()` may re-insert the timer it was given (or others), so the loop must not keep a stale "next" pointer. It unlinks the head before the callback and re-reads `h->next` each time.

**Complexity.** `timer_add` is O(n). `timer_cancel` is O(1), since a doubly linked node can unlink itself. `timer_expire` is O(k * n) for k firings (each re-arm is an insertion). No dynamic memory; the links live inside the timers.

**Common mistakes**
- `(struct sw_timer *)node`. It works in tests where the link is the first member and returns garbage otherwise.
- Pointer arithmetic on `struct list_head *` in the macro (`ptr - offsetof(...)`). That subtracts `offsetof * 16` bytes.
- Iterating with a saved `next` pointer while the callback modifies the list. Either it skips re-armed timers or it follows a link that was rewritten.
- Calling `fire` before unlinking. A re-arming callback then inserts a node that is still linked, which corrupts the list (`BROKEN LINKS`).
- Using `<` in the insertion walk, which breaks the stable order of equal expiries.

**Interview follow-ups**
- Implement `list_for_each_entry_safe` as a macro, and explain why the `_safe` variant needs an extra cursor.
- Make the expiry comparison robust against 32-bit tick wrap-around (`(int32_t)(now - t->expiry) >= 0`). How does that interact with sorted insertion?
- How does FreeRTOS or Zephyr avoid O(n) insertion for many timers (delta lists, timer wheels)?
- Why is `container_of` type-unsafe, and how does the Linux kernel version add a compile-time type check?
