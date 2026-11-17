@@@ meta
id: STC-H-07
topic: Structures
difficulty: Hard
type: FUNCTION
title: Software Timers on an Intrusive List with container_of
tags: embedded, intrusive-list, container-of, offsetof, doubly-linked-list, rtos, tick-wraparound
@@@ statement_md
Linux and many RTOS kernels do not put objects *into* list nodes. They put a list node **inside** the object (an *intrusive list*) and get back from the node to the object with `container_of`. Build an RTOS software-timer service this way.

The judge defines:

```c
struct list_node { struct list_node *next, *prev; };

struct SwTimer {
    uint32_t         id;
    uint32_t         expiry;   /* absolute tick                         */
    uint32_t         period;   /* 0 = one-shot                          */
    uint32_t         fired;    /* number of times the timer has fired   */
    struct list_node link;     /* NOT the first member!                 */
    uint8_t          active;   /* 1 while the timer is in the list      */
};

struct TimerList { struct list_node head; };   /* circular list with a sentinel head */
```

Define the macro `container_of(ptr, type, member)` (use `offsetof`) and implement:

```c
void   tl_init(struct TimerList *tl);
void   timer_start(struct TimerList *tl, struct SwTimer *t, uint32_t now, uint32_t delay, uint32_t period);
int    timer_stop(struct TimerList *tl, struct SwTimer *t);
size_t timer_process(struct TimerList *tl, uint32_t now, uint32_t *fired_ids, size_t max);
```

Rules:
- The list is sorted by `expiry`. Ticks are `uint32_t` and **wrap around**: "`a` is before `b`" means `(int32_t)(a - b) < 0`. All active expiries lie within 2^31 - 1 ticks of each other and of `now`.
- **`timer_start`**: if `t` is active, unlink it first (restart). Set `expiry = now + delay`, `period`, `active = 1`, and insert it **after** every timer whose expiry is not later than its own (FIFO among equal expiries). It does not change `fired`.
- **`timer_stop`**: if `t` is active, unlink it in **O(1)**, clear `active` and return 1. Otherwise return 0.
- **`timer_process`**: every timer with `(int32_t)(now - expiry) >= 0` fires **once**, in list order. Append its `id` to `fired_ids` and increment `fired`. A periodic timer is re-armed **drift-free** (`expiry += period`) and re-inserted (FIFO). It does **not** fire again in the same call, even if it is still due. One-shot timers become inactive. Return the number fired (`max` is always large enough).

The harness's 16 timers have `id = index` and start zeroed (inactive).

**Input (read by the hidden harness)**: commands `NOW t` (set the current tick), `START id delay period`, `STOP id` (prints `STOP id -> r`), `TICK t` (sets now = t, calls `timer_process`, prints `t=<now> fired: <ids>` or `fired: -`), `LIST` (prints `LIST: id@expiry ...` or `LIST: -`, and checks the `prev` links).

**Example**
```
Input:
START 1 100 0
START 2 50 0
START 3 100 25
LIST
TICK 60
TICK 100
TICK 125
STOP 3
STOP 1
LIST

Output:
LIST: 2@50 1@100 3@100
t=60 fired: 2
t=100 fired: 1 3
t=125 fired: 3
STOP 3 -> 1
STOP 1 -> 0
LIST: -
```
@@@ constraints_md
- At most 200 commands; timer ids `0..15`; `delay, period <= 1000000`.
- No dynamic memory; `timer_stop` is O(1); `timer_start` is O(n).
- `link` is not the first member, so a plain cast from `struct list_node *` to `struct SwTimer *` is wrong.
@@@ starter_code
#include <stdint.h>
#include <stddef.h>

/* Already defined by the judge: struct list_node, struct SwTimer, struct TimerList (see statement). */

/* TODO: #define container_of(ptr, type, member) ... */

void tl_init(struct TimerList *tl)
{
    tl->head.next = &tl->head;
    tl->head.prev = &tl->head;
}

void timer_start(struct TimerList *tl, struct SwTimer *t, uint32_t now, uint32_t delay, uint32_t period)
{
    /* TODO */
    (void)tl; (void)t; (void)now; (void)delay; (void)period;
}

int timer_stop(struct TimerList *tl, struct SwTimer *t)
{
    /* TODO */
    (void)tl; (void)t;
    return 0;
}

size_t timer_process(struct TimerList *tl, uint32_t now, uint32_t *fired_ids, size_t max)
{
    /* TODO */
    (void)tl; (void)now; (void)fired_ids; (void)max;
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>

struct list_node { struct list_node *next, *prev; };

struct SwTimer {
    uint32_t         id;
    uint32_t         expiry;
    uint32_t         period;
    uint32_t         fired;
    struct list_node link;
    uint8_t          active;
};

struct TimerList { struct list_node head; };

/*USER_CODE*/

#define H_TIMER_OF(n) ((struct SwTimer *)((char *)(n) - offsetof(struct SwTimer, link)))

static struct SwTimer timers[16];
static struct TimerList tl;

static void list_cmd(void)
{
    printf("LIST:");
    int cnt = 0;
    const struct list_node *prev = &tl.head;
    for (struct list_node *n = tl.head.next; n != &tl.head; n = n->next) {
        if (n == NULL || cnt > 16) { printf(" BROKEN\n"); return; }
        if (n->prev != prev) { printf(" BAD-PREV"); }
        struct SwTimer *t = H_TIMER_OF(n);
        printf(" %u@%u", (unsigned)t->id, (unsigned)t->expiry);
        prev = n;
        cnt++;
    }
    if (tl.head.prev != prev) printf(" BAD-TAIL");
    printf("%s\n", cnt ? "" : " -");
}

int main(void)
{
    char cmd[8];
    uint32_t now = 0;
    for (int i = 0; i < 16; i++) {
        memset(&timers[i], 0, sizeof timers[i]);
        timers[i].id = (uint32_t)i;
    }
    tl_init(&tl);
    while (scanf("%7s", cmd) == 1) {
        unsigned a, b, c;
        if (strcmp(cmd, "NOW") == 0) {
            if (scanf("%u", &a) != 1) break;
            now = a;
        } else if (strcmp(cmd, "START") == 0) {
            if (scanf("%u %u %u", &a, &b, &c) != 3 || a > 15) break;
            timer_start(&tl, &timers[a], now, b, c);
        } else if (strcmp(cmd, "STOP") == 0) {
            if (scanf("%u", &a) != 1 || a > 15) break;
            printf("STOP %u -> %d\n", a, timer_stop(&tl, &timers[a]));
        } else if (strcmp(cmd, "TICK") == 0) {
            uint32_t ids[32];
            if (scanf("%u", &a) != 1) break;
            now = a;
            size_t n = timer_process(&tl, now, ids, 32);
            printf("t=%u fired:", (unsigned)now);
            if (n == 0) printf(" -");
            for (size_t i = 0; i < n && i < 32; i++) printf(" %u", (unsigned)ids[i]);
            printf("\n");
        } else if (strcmp(cmd, "LIST") == 0) {
            list_cmd();
        } else if (strcmp(cmd, "FIRED") == 0) {
            printf("FIRED:");
            for (int i = 0; i < 16; i++)
                if (timers[i].fired) printf(" %d=%u", i, (unsigned)timers[i].fired);
            printf("\n");
        }
    }
    return 0;
}
@@@ sample_input
START 1 100 0
START 2 50 0
START 3 100 25
LIST
TICK 60
TICK 100
TICK 125
STOP 3
STOP 1
LIST
@@@ sample_output
LIST: 2@50 1@100 3@100
t=60 fired: 2
t=100 fired: 1 3
t=125 fired: 3
STOP 3 -> 1
STOP 1 -> 0
LIST: -

@@@ sample_input
NOW 4294967290
START 1 10 0
START 2 3 0
LIST
TICK 4294967295
TICK 5
@@@ sample_output
LIST: 2@4294967293 1@4
t=4294967295 fired: 2
t=5 fired: 1

@@@ hidden_input
START 3 10 10
TICK 35
LIST
TICK 36
TICK 36
TICK 36
LIST
FIRED
@@@ hidden_output
t=35 fired: 3
LIST: 3@20
t=36 fired: 3
t=36 fired: 3
t=36 fired: -
LIST: 3@40
FIRED: 3=3

@@@ hidden_input
TICK 10
STOP 0
START 0 0 0
LIST
TICK 10
LIST
START 5 20 0
START 6 20 0
START 7 20 0
START 5 20 0
LIST
STOP 6
LIST
TICK 30
@@@ hidden_output
t=10 fired: -
STOP 0 -> 0
LIST: 0@10
t=10 fired: 0
LIST: -
LIST: 6@30 7@30 5@30
STOP 6 -> 1
LIST: 7@30 5@30
t=30 fired: 7 5

@@@ hidden_input
START 1 5 5
START 2 5 5
START 3 5 5
TICK 5
LIST
TICK 10
TICK 10
LIST
STOP 2
TICK 15
FIRED
@@@ hidden_output
t=5 fired: 1 2 3
LIST: 1@10 2@10 3@10
t=10 fired: 1 2 3
t=10 fired: -
LIST: 1@15 2@15 3@15
STOP 2 -> 1
t=15 fired: 1 3
FIRED: 1=3 2=2 3=3

@@@ hidden_input
NOW 4294967000
START 0 200 300
START 1 400 0
START 2 1000 0
LIST
TICK 4294967200
LIST
TICK 104
LIST
TICK 704
LIST
@@@ hidden_output
LIST: 0@4294967200 1@104 2@704
t=4294967200 fired: 0
LIST: 1@104 0@204 2@704
t=104 fired: 1
LIST: 0@204 2@704
t=704 fired: 0 2
LIST: 0@504

@@@ hidden_input
START 0 50 0
START 1 40 0
START 2 30 0
START 3 20 0
START 4 10 0
START 5 50 0
START 6 10 0
START 7 0 0
START 8 1000000 0
START 9 1000000 1000000
START 10 25 0
START 11 25 0
START 12 25 0
START 13 25 0
START 14 25 0
START 15 25 0
LIST
STOP 12
STOP 0
STOP 8
LIST
TICK 25
TICK 999999
TICK 1000000
LIST
FIRED
@@@ hidden_output
LIST: 7@0 4@10 6@10 3@20 10@25 11@25 12@25 13@25 14@25 15@25 2@30 1@40 0@50 5@50 8@1000000 9@1000000
STOP 12 -> 1
STOP 0 -> 1
STOP 8 -> 1
LIST: 7@0 4@10 6@10 3@20 10@25 11@25 13@25 14@25 15@25 2@30 1@40 5@50 9@1000000
t=25 fired: 7 4 6 3 10 11 13 14 15
t=999999 fired: 2 1 5
t=1000000 fired: 9
LIST: 9@2000000
FIRED: 1=1 2=1 3=1 4=1 5=1 6=1 7=1 9=1 10=1 11=1 13=1 14=1 15=1

@@@ hint
`#define container_of(ptr, type, member) ((type *)((char *)(ptr) - offsetof(type, member)))`. Write two O(1) helpers: `insert_before(pos, node)` and `unlink(node)`. With a circular sentinel there are no `NULL` special cases. To insert, walk from `head.next` until the first timer that is strictly **later** (`(int32_t)(it->expiry - t->expiry) > 0`) and insert before it. If none is later, insert before `head`, which appends at the tail.
@@@ hint
In `timer_process`, first **detach** all due timers from the front into a local sentinel list, then handle them one by one: record, `fired++`, and for periodic timers `expiry += period` and re-insert. Detaching first guarantees that each timer fires at most once per call, even when the re-armed expiry is still in the past.
@@@ solution_code
#include <stdint.h>
#include <stddef.h>

#define container_of(ptr, type, member) \
    ((type *)((char *)(ptr) - offsetof(type, member)))

static void node_unlink(struct list_node *n)
{
    n->prev->next = n->next;
    n->next->prev = n->prev;
    n->next = n->prev = n;
}

static void node_insert_before(struct list_node *pos, struct list_node *n)
{
    n->prev = pos->prev;
    n->next = pos;
    pos->prev->next = n;
    pos->prev = n;
}

/* a strictly later than b, wrap-safe */
static int later(uint32_t a, uint32_t b) { return (int32_t)(a - b) > 0; }

static void insert_sorted(struct TimerList *tl, struct SwTimer *t)
{
    struct list_node *it = tl->head.next;
    while (it != &tl->head && !later(container_of(it, struct SwTimer, link)->expiry, t->expiry))
        it = it->next;                                  /* skip <= : FIFO among equal expiries */
    node_insert_before(it, &t->link);
}

void tl_init(struct TimerList *tl)
{
    tl->head.next = &tl->head;
    tl->head.prev = &tl->head;
}

void timer_start(struct TimerList *tl, struct SwTimer *t, uint32_t now, uint32_t delay, uint32_t period)
{
    if (t->active)
        node_unlink(&t->link);                          /* restart */
    t->expiry = now + delay;                            /* wraps modulo 2^32 */
    t->period = period;
    t->active = 1;
    insert_sorted(tl, t);
}

int timer_stop(struct TimerList *tl, struct SwTimer *t)
{
    (void)tl;                                           /* O(1): the node knows its neighbours */
    if (!t->active)
        return 0;
    node_unlink(&t->link);
    t->active = 0;
    return 1;
}

size_t timer_process(struct TimerList *tl, uint32_t now, uint32_t *fired_ids, size_t max)
{
    struct list_node due;                               /* local sentinel */
    due.next = due.prev = &due;

    /* 1. detach every due timer (they are at the front, in order) */
    while (tl->head.next != &tl->head) {
        struct SwTimer *t = container_of(tl->head.next, struct SwTimer, link);
        if ((int32_t)(now - t->expiry) < 0)
            break;
        node_unlink(&t->link);
        node_insert_before(&due, &t->link);
    }

    /* 2. fire them once each, re-arm periodic ones */
    size_t n = 0;
    while (due.next != &due) {
        struct SwTimer *t = container_of(due.next, struct SwTimer, link);
        node_unlink(&t->link);
        if (n < max)
            fired_ids[n] = t->id;
        n++;
        t->fired++;
        if (t->period) {
            t->expiry += t->period;                     /* drift-free: relative to the old expiry */
            insert_sorted(tl, t);
        } else {
            t->active = 0;
        }
    }
    return n;
}
@@@ explanation_md
**Approach.**
- **Intrusive list + `container_of`.** Each `SwTimer` embeds its own `list_node`, so starting a timer never allocates. A node pointer is turned back into its timer by subtracting the member offset: `(struct SwTimer *)((char *)node - offsetof(struct SwTimer, link))`. Because `link` sits at offset 16, a plain cast would read the timer's fields from the wrong address. One object can even sit on several lists through several embedded nodes.
- **Circular doubly linked list with a sentinel.** Insert and unlink are four pointer writes with no `NULL` checks, and `timer_stop` is O(1) because the node knows both neighbours.
- **Wrap-safe ordering.** `(int32_t)(a - b) < 0` is correct across the 2^32 tick wrap as long as the distance is below 2^31 (`4294967293` comes before `4`).
- **Two-phase processing.** Detach all due timers first, then fire. This makes "fire at most once per call" trivial and keeps the list consistent while timers are re-armed. Periodic timers add `period` to their **old** expiry, so lateness does not accumulate as drift.

```
START 3 10 10; TICK 35 -> fires once, expiry 20 (still due, but waits for the next call)
TICK 36 -> fires (20), expiry 30;  TICK 36 -> fires (30), expiry 40;  TICK 36 -> nothing
```

**Complexity.** `timer_start` is O(n) (sorted insert). `timer_stop` is O(1). `timer_process` is O(k * n) for k fired timers. Space O(1); all nodes live inside the timers.

**Common mistakes**
- Casting `(struct SwTimer *)node`. This only works when `link` is the first member.
- Comparing ticks with `<` on `uint32_t`. Near the wrap, a timer due "in 4 ticks" (expiry 4) sorts **before** one due in 3 ticks (expiry 4294967293).
- Re-arming with `expiry = now + period`. The period drifts by the processing latency each time.
- Re-inserting periodic timers while still walking the list. A short-period timer can then fire repeatedly, or forever, in one call.
- Restarting an active timer without unlinking it first, which links the node twice and corrupts the list.

**Interview follow-ups**
- Implement `list_for_each_entry_safe` as a macro. Why is the `_safe` variant needed when deleting during iteration?
- `offsetof` on a member of a nested struct, or of an array element: what is allowed, and why is `container_of` not ISO C strict-aliasing-proof?
- A hierarchical timer wheel makes start/stop O(1). How does it work and what does it cost?
- The tick ISR calls `timer_process` while tasks call `timer_start`. What must be locked, and why must callbacks run outside the lock?
