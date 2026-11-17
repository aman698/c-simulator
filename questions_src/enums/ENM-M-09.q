@@@ meta
id: ENM-M-09
topic: Enums
difficulty: Medium
type: CODE
title: Watchdog Alive Supervision With Severity-Ordered States
tags: embedded, watchdog, alive-supervision, state-machine, autosar-wdgm
@@@ statement_md
Implement a simplified AUTOSAR **Watchdog Manager alive supervision**. Each of `T` tasks must report a number of *alive indications* in every supervision cycle that lies between `min` and `max`. The supervisor keeps a **local state** per task and a **global state**, both from this enum:

```c
typedef enum { SUP_OK, SUP_FAILED, SUP_EXPIRED } SupState;   /* ordered by severity */
```

**Events**
- `A i`: task `i` reports alive. If `i` is not a valid task index (`0..T-1`), print `invalid task <i>`. Alive indications of a task whose local state is `EXPIRED` are ignored.
- `C`: end of a supervision cycle (cycles are numbered from 1). For every task whose local state is **not** `EXPIRED`:
  - if `min <= count <= max`: local state `OK`, and its failed-cycle counter is reset to 0;
  - otherwise the failed-cycle counter goes up by 1. If it is now **greater than** the task's tolerance `tol`, the local state becomes `EXPIRED` (latched forever). Otherwise it becomes `FAILED`.
  - In both cases the task's alive count is reset to 0.

  The global state is the **most severe** local state. Print `cycle <k>: <GLOBAL> (<s0>,<s1>,...)`. The **first** time the global state is `EXPIRED`, print an extra line `RESET` (the watchdog is no longer fed).

**Input**
- Line 1: `T`. Next `T` lines: `min max tol` for task 0..T-1.
- Next line: `m`, then `m` lines, each `A i` or `C`.

**Output**
- The lines described above, in event order.

**Example**
```
Input:
2
1 2 1
2 3 0
9
A 0
A 1
A 1
C
A 1
C
A 0
A 1
C

Output:
cycle 1: OK (OK,OK)
cycle 2: EXPIRED (FAILED,EXPIRED)
RESET
cycle 3: EXPIRED (OK,EXPIRED)
```
@@@ constraints_md
- `1 <= T <= 8`, `0 <= min <= max <= 100`, `0 <= tol <= 10`
- `0 <= m <= 1000`. `i` is any 32-bit `int`.
- All tasks start `OK` with count 0 and failed counter 0.
@@@ starter_code
#include <stdio.h>

typedef enum { SUP_OK, SUP_FAILED, SUP_EXPIRED } SupState;

static const char *const sup_name[] = { "OK", "FAILED", "EXPIRED" };

#define MAX_TASKS 8

int main(void)
{
    int T;
    if (scanf("%d", &T) != 1) return 0;
    int min[MAX_TASKS], max[MAX_TASKS], tol[MAX_TASKS];
    for (int i = 0; i < T; i++)
        if (scanf("%d %d %d", &min[i], &max[i], &tol[i]) != 3) return 0;

    int m;
    if (scanf("%d", &m) != 1) return 0;
    for (int e = 0; e < m; e++) {
        char kind[4];
        if (scanf("%3s", kind) != 1) break;
        if (kind[0] == 'A') {
            int i;
            if (scanf("%d", &i) != 1) break;
            /* TODO: alive indication */
        } else {
            /* TODO: end of supervision cycle */
        }
    }
    (void)sup_name;
    return 0;
}
@@@ sample_input
2
1 2 1
2 3 0
9
A 0
A 1
A 1
C
A 1
C
A 0
A 1
C
@@@ sample_output
cycle 1: OK (OK,OK)
cycle 2: EXPIRED (FAILED,EXPIRED)
RESET
cycle 3: EXPIRED (OK,EXPIRED)

@@@ sample_input
1
1 1 2
6
A 0
A 0
C
A 5
A 0
C
@@@ sample_output
cycle 1: FAILED (FAILED)
invalid task 5
cycle 2: OK (OK)

@@@ hidden_input
1
1 1 2
3
C
C
C
@@@ hidden_output
cycle 1: FAILED (FAILED)
cycle 2: FAILED (FAILED)
cycle 3: EXPIRED (EXPIRED)
RESET

@@@ hidden_input
1
1 1 1
5
C
A 0
C
C
C
@@@ hidden_output
cycle 1: FAILED (FAILED)
cycle 2: OK (OK)
cycle 3: FAILED (FAILED)
cycle 4: EXPIRED (EXPIRED)
RESET

@@@ hidden_input
2
0 1 0
0 0 0
5
C
A 0
C
A 1
C
@@@ hidden_output
cycle 1: OK (OK,OK)
cycle 2: OK (OK,OK)
cycle 3: EXPIRED (OK,EXPIRED)
RESET

@@@ hidden_input
2
1 5 3
1 5 3
6
A -1
A 2
A 0
A 1
A 100
C
@@@ hidden_output
invalid task -1
invalid task 2
invalid task 100
cycle 1: OK (OK,OK)

@@@ hidden_input
1
1 1 0
2
A 0
A 0
@@@ hidden_output

@@@ hidden_input
3
1 2 1
1 1 1
2 4 0
14
A 0
A 1
A 2
A 2
C
A 0
A 0
A 0
A 1
A 2
A 2
C
A 1
C
@@@ hidden_output
cycle 1: OK (OK,OK,OK)
cycle 2: FAILED (FAILED,OK,OK)
cycle 3: EXPIRED (EXPIRED,OK,EXPIRED)
RESET

@@@ hint
Order the enumerators by severity (`OK < FAILED < EXPIRED`). The global state is then simply the **maximum** of the local states, with no lookup table and no chain of `if`s.
@@@ hint
Per task keep `count`, `failed` and `state`. On `C`, skip tasks that are already `EXPIRED` (latched). Remember whether `RESET` was already printed, so that it is printed only once.
@@@ solution_code
#include <stdio.h>

typedef enum { SUP_OK, SUP_FAILED, SUP_EXPIRED } SupState;   /* severity order matters */

static const char *const sup_name[] = { "OK", "FAILED", "EXPIRED" };

#define MAX_TASKS 8

struct Task {
    int min, max, tol;
    int count;          /* alive indications in the current cycle */
    int failed;         /* consecutive failed cycles */
    SupState state;
};

int main(void)
{
    int T;
    if (scanf("%d", &T) != 1 || T < 1 || T > MAX_TASKS) return 0;
    struct Task task[MAX_TASKS] = { { 0, 0, 0, 0, 0, SUP_OK } };
    for (int i = 0; i < T; i++)
        if (scanf("%d %d %d", &task[i].min, &task[i].max, &task[i].tol) != 3) return 0;

    int m;
    if (scanf("%d", &m) != 1) return 0;
    int cycle = 0, reset_sent = 0;

    for (int e = 0; e < m; e++) {
        char kind[4];
        if (scanf("%3s", kind) != 1) break;

        if (kind[0] == 'A') {
            int i;
            if (scanf("%d", &i) != 1) break;
            if (i < 0 || i >= T) { printf("invalid task %d\n", i); continue; }
            if (task[i].state != SUP_EXPIRED) task[i].count++;
            continue;
        }

        /* 'C': evaluate the supervision cycle */
        cycle++;
        SupState global = SUP_OK;
        for (int i = 0; i < T; i++) {
            struct Task *t = &task[i];
            if (t->state != SUP_EXPIRED) {
                if (t->count >= t->min && t->count <= t->max) {
                    t->state = SUP_OK;
                    t->failed = 0;
                } else {
                    t->failed++;
                    t->state = (t->failed > t->tol) ? SUP_EXPIRED : SUP_FAILED;
                }
                t->count = 0;
            }
            if (t->state > global) global = t->state;   /* worst state wins */
        }

        printf("cycle %d: %s (", cycle, sup_name[global]);
        for (int i = 0; i < T; i++) printf("%s%s", i ? "," : "", sup_name[task[i].state]);
        printf(")\n");
        if (global == SUP_EXPIRED && !reset_sent) {
            printf("RESET\n");
            reset_sent = 1;
        }
    }
    return 0;
}
@@@ explanation_md
**Approach.** Each task runs a tiny FSM (`OK` / `FAILED` / `EXPIRED`), driven by the end-of-cycle evaluation:
- the count is inside `[min, max]` → `OK`, and the failed counter is reset;
- outside → `failed++`. The counter crossing the tolerance means `EXPIRED`, which is latched, so a dead task cannot "heal" itself.

The key enum design decision is to **order the enumerators by severity**. Then "global = worst local" is `if (local > global) global = local;`, and comparisons like `state >= SUP_FAILED` read naturally. The `RESET` line models the WdgM's choice to stop feeding the hardware watchdog, which then resets the MCU. It must happen once, not every cycle.

**Complexity.** Time O(m · T) worst case (each `C` scans all tasks), space O(T).

**Common mistakes**
- Not latching `EXPIRED`: a task that comes back after expiring must not bring the system back to `OK`, because the reset decision has already been made.
- Off-by-one on the tolerance: `failed >= tol` instead of `failed > tol`. With `tol = 0` the first failed cycle must already expire, and with `tol = 2` the third one does.
- Counting alive indications for an invalid task index, writing `task[-1].count`.
- Forgetting to reset `count` after each cycle, so that the counts accumulate across cycles.
- Ordering the enum alphabetically or arbitrarily (`EXPIRED, FAILED, OK`) and then using `>` to pick the worst state.

**Interview follow-ups**
- AUTOSAR WdgM also has *deadline* and *logical* supervision. How would you supervise "runnable A must be followed by runnable B within 5 ms"?
- Why should the watchdog be fed from the supervisor and never directly from an ISR or a low-priority background loop?
- The tasks call `Alive(i)` from different priority levels. What synchronization does `count++` need on a single-core MCU, and on a multi-core one?
