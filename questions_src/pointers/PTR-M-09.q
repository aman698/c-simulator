@@@ meta
id: PTR-M-09
topic: Pointers
difficulty: Medium
type: FUNCTION
title: Event Notification Service with Callbacks and void* Context
tags: embedded, function-pointer, callback, void-pointer, observer-pattern, autosar
@@@ statement_md
In AUTOSAR-style basic software, modules do not call each other directly. They **subscribe callbacks** to events (for example, "CAN bus-off" or "ignition on"). Each callback is registered together with an opaque **context pointer** that is handed back on every call, so the same function can serve several instances.

Implement this notification service with a fixed table of at most **8 subscriptions** in total (no `malloc`):

```c
typedef void (*event_cb)(int event, int arg, void *ctx);

int ev_subscribe(int event, event_cb cb, void *ctx);
int ev_unsubscribe(int event, event_cb cb, void *ctx);
int ev_publish(int event, int arg);
```

- **`ev_subscribe`**:
  - `-1` if `event` is outside `0..15` or `cb == NULL`.
  - `-2` if the exact triple `(event, cb, ctx)` is already subscribed.
  - `-3` if 8 subscriptions already exist.
  - Otherwise store the subscription and return `0`. `ctx` may be `NULL`.
- **`ev_unsubscribe`**: remove the subscription equal to `(event, cb, ctx)` and return `0`, or `-1` if there is none.
- **`ev_publish`**:
  - `-1` if `event` is outside `0..15`.
  - Otherwise call `cb(event, arg, ctx)` for every subscription to `event`, **in the order in which they were subscribed** (oldest first). A subscription that was removed and added again counts as the newest.
  - Return the number of callbacks called.
- Callbacks never call `ev_*` functions themselves.

**How it is tested.** The hidden harness provides two callbacks and three context objects `A`, `B`, `C` (each with a name and a running total):
- `log` prints `  log[<ctx>] e=<event> arg=<arg>`.
- `acc` adds `arg` to the context's total and prints `  acc[<ctx>] total=<total>`.

A `NULL` context prints as `null` (and `acc` keeps a total of 0).

**Input (read by the hidden harness)**: one command per line.
- `sub E CB CTX` prints `sub -> R`. `unsub E CB CTX` prints `unsub -> R`. `pub E ARG` prints the callbacks' output, then `pub -> R`.
- `CB` is `log`, `acc` or `-` (`NULL`). `CTX` is `A`, `B`, `C` or `-` (`NULL`).

**Example**
```
Input:
sub 1 log A
sub 1 acc B
sub 2 log B
pub 1 10
pub 2 5
pub 3 0

Output:
sub -> 0
sub -> 0
sub -> 0
  log[A] e=1 arg=10
  acc[B] total=10
pub -> 2
  log[B] e=2 arg=5
pub -> 1
pub -> 0
```
@@@ constraints_md
- At most 8 subscriptions at any time (over all events); events are `0..15`.
- At most 50 commands.
- No dynamic memory.
@@@ starter_code
#include <stddef.h>

typedef void (*event_cb)(int event, int arg, void *ctx);

#define EV_NUM_EVENTS 16
#define EV_MAX_SUBS   8

int ev_subscribe(int event, event_cb cb, void *ctx)
{
    /* TODO */
    return -1;
}

int ev_unsubscribe(int event, event_cb cb, void *ctx)
{
    /* TODO */
    return -1;
}

int ev_publish(int event, int arg)
{
    /* TODO */
    return -1;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>

/*USER_CODE*/

struct counter {
    const char *name;
    long long total;
};

static struct counter ctx_a = {"A", 0}, ctx_b = {"B", 0}, ctx_c = {"C", 0};

static void cb_log(int event, int arg, void *ctx)
{
    const struct counter *c = ctx;
    printf("  log[%s] e=%d arg=%d\n", c ? c->name : "null", event, arg);
}

static void cb_acc(int event, int arg, void *ctx)
{
    struct counter *c = ctx;
    (void)event;
    if (c) c->total += arg;
    printf("  acc[%s] total=%lld\n", c ? c->name : "null", c ? c->total : 0LL);
}

static event_cb parse_cb(const char *s)
{
    if (strcmp(s, "log") == 0) return cb_log;
    if (strcmp(s, "acc") == 0) return cb_acc;
    return NULL;
}

static void *parse_ctx(const char *s)
{
    if (strcmp(s, "A") == 0) return &ctx_a;
    if (strcmp(s, "B") == 0) return &ctx_b;
    if (strcmp(s, "C") == 0) return &ctx_c;
    return NULL;
}

int main(void)
{
    char cmd[16];
    while (scanf("%15s", cmd) == 1) {
        if (strcmp(cmd, "pub") == 0) {
            int e, arg;
            if (scanf("%d %d", &e, &arg) != 2) return 0;
            int r = ev_publish(e, arg);
            printf("pub -> %d\n", r);
        } else {
            int e;
            char cbs[8], ctxs[8];
            if (scanf("%d %7s %7s", &e, cbs, ctxs) != 3) return 0;
            if (strcmp(cmd, "sub") == 0)
                printf("sub -> %d\n", ev_subscribe(e, parse_cb(cbs), parse_ctx(ctxs)));
            else
                printf("unsub -> %d\n", ev_unsubscribe(e, parse_cb(cbs), parse_ctx(ctxs)));
        }
    }
    return 0;
}
@@@ sample_input
sub 1 log A
sub 1 acc B
sub 2 log B
pub 1 10
pub 2 5
pub 3 0
@@@ sample_output
sub -> 0
sub -> 0
sub -> 0
  log[A] e=1 arg=10
  acc[B] total=10
pub -> 2
  log[B] e=2 arg=5
pub -> 1
pub -> 0

@@@ sample_input
sub 0 log A
sub 0 log A
sub 0 log -
sub 16 log A
sub -1 acc A
sub 3 - A
pub 0 7
pub 16 1
@@@ sample_output
sub -> 0
sub -> -2
sub -> 0
sub -> -1
sub -> -1
sub -> -1
  log[A] e=0 arg=7
  log[null] e=0 arg=7
pub -> 2
pub -> -1

@@@ hidden_input
sub 0 log A
sub 1 log A
sub 2 log A
sub 3 log A
sub 4 log A
sub 5 log A
sub 6 log A
sub 7 log A
sub 8 log A
unsub 3 log A
sub 8 log A
pub 8 1
pub 3 1
@@@ hidden_output
sub -> 0
sub -> 0
sub -> 0
sub -> 0
sub -> 0
sub -> 0
sub -> 0
sub -> 0
sub -> -3
unsub -> 0
sub -> 0
  log[A] e=8 arg=1
pub -> 1
pub -> 0

@@@ hidden_input
sub 5 log A
sub 5 log B
sub 5 log C
unsub 5 log A
sub 5 log A
pub 5 1
@@@ hidden_output
sub -> 0
sub -> 0
sub -> 0
unsub -> 0
sub -> 0
  log[B] e=5 arg=1
  log[C] e=5 arg=1
  log[A] e=5 arg=1
pub -> 3

@@@ hidden_input
sub 2 acc A
unsub 2 acc B
unsub 2 log A
unsub 3 acc A
unsub 2 acc A
unsub 2 acc A
pub 2 4
@@@ hidden_output
sub -> 0
unsub -> -1
unsub -> -1
unsub -> -1
unsub -> 0
unsub -> -1
pub -> 0

@@@ hidden_input
sub 1 acc A
sub 2 acc A
pub 1 -5
pub 2 7
pub 1 2147483647
@@@ hidden_output
sub -> 0
sub -> 0
  acc[A] total=-5
pub -> 1
  acc[A] total=2
pub -> 1
  acc[A] total=2147483649
pub -> 1

@@@ hidden_input
sub 0 log A
sub 1 log A
sub 0 log B
sub 0 acc C
unsub 0 log B
sub 0 log B
pub 0 3
@@@ hidden_output
sub -> 0
sub -> 0
sub -> 0
sub -> 0
unsub -> 0
sub -> 0
  log[A] e=0 arg=3
  acc[C] total=3
  log[B] e=0 arg=3
pub -> 3

@@@ hidden_input
sub 9 acc -
sub 9 acc -
pub 9 4
unsub 9 acc -
pub 9 4
pub -1 0
@@@ hidden_output
sub -> 0
sub -> -2
  acc[null] total=0
pub -> 1
unsub -> 0
pub -> 0
pub -> -1

@@@ hint
Store each subscription as a small struct `{ int event; event_cb cb; void *ctx; }` in a static array with a count. Function pointers and `void *` can be compared with `==` like any other pointers.
@@@ hint
To keep the "oldest first" order, keep the array **compact**: append new subscriptions at the end, and on unsubscribe shift the later entries down by one. If you reuse holes instead, a new subscription gets called before older ones.
@@@ solution_code
#include <stddef.h>

typedef void (*event_cb)(int event, int arg, void *ctx);

#define EV_NUM_EVENTS 16
#define EV_MAX_SUBS   8

struct subscription {
    int event;
    event_cb cb;
    void *ctx;              /* opaque: never dereferenced here, only handed back */
};

static struct subscription subs[EV_MAX_SUBS];
static int nsubs;           /* subs[0..nsubs-1] in subscription order */

static int find(int event, event_cb cb, void *ctx)
{
    for (int i = 0; i < nsubs; i++)
        if (subs[i].event == event && subs[i].cb == cb && subs[i].ctx == ctx)
            return i;
    return -1;
}

int ev_subscribe(int event, event_cb cb, void *ctx)
{
    if (event < 0 || event >= EV_NUM_EVENTS || cb == NULL)
        return -1;
    if (find(event, cb, ctx) >= 0)
        return -2;
    if (nsubs == EV_MAX_SUBS)
        return -3;
    subs[nsubs].event = event;
    subs[nsubs].cb = cb;
    subs[nsubs].ctx = ctx;
    nsubs++;
    return 0;
}

int ev_unsubscribe(int event, event_cb cb, void *ctx)
{
    int i = find(event, cb, ctx);
    if (i < 0)
        return -1;
    for (; i + 1 < nsubs; i++)          /* close the gap: keeps the order */
        subs[i] = subs[i + 1];
    nsubs--;
    return 0;
}

int ev_publish(int event, int arg)
{
    if (event < 0 || event >= EV_NUM_EVENTS)
        return -1;
    int called = 0;
    for (int i = 0; i < nsubs; i++) {
        if (subs[i].event == event) {
            subs[i].cb(event, arg, subs[i].ctx);   /* call through the pointer */
            called++;
        }
    }
    return called;
}
@@@ explanation_md
**Approach.** A subscription is the triple *(event, function pointer, context pointer)*. Storing them in a **compact static array** gives three properties at once:
- *order*: appending at the end and shifting on removal keeps "oldest first";
- *identity*: a duplicate or a removal is found by comparing all three fields with `==` (function pointers compare equal iff they point to the same function);
- *no heap*: the table size is fixed at compile time, as AUTOSAR/MISRA require.

The `void *ctx` is the C way to write a closure. The service never looks inside it; it just passes it back, and the callback converts it to the type it expects (`struct counter *`). This is how HAL callbacks (`HAL_UART_RxCpltCallback(huart)`), RTOS timers (`pvTimerID`) and `pthread_create` pass instance data.

**Complexity.** `subscribe` / `unsubscribe` / `publish`: O(S) for S <= 8 subscriptions. Space O(S), fixed.

**Common mistakes**
- Reusing freed slots (`subs[i].cb = NULL` on unsubscribe, then the first free slot on subscribe). A re-added subscription is then called **before** older ones.
- Matching only on `cb` when unsubscribing, which removes another module's subscription that uses the same function with a different `ctx`.
- Checking "table full" before "duplicate". With a full table, a duplicate must still report `-2`.
- Forgetting `cb == NULL` validation. Calling through a null function pointer jumps to address 0 (on a Cortex-M that is the initial stack pointer value in the vector table: an instant HardFault).

**Interview follow-ups**
- What breaks if a callback calls `ev_unsubscribe` on itself during `ev_publish`, and how would you make that safe (deferred removal, iterate over a snapshot)?
- `ev_publish` may run in an ISR while `ev_subscribe` runs in a task. Which critical sections do you need?
- Why is converting a function pointer to `void *` not allowed in ISO C, even though POSIX `dlsym` relies on it?
- How would you replace the linear search with per-event linked lists threaded through the static table?
