@@@ meta
id: RSM-H-03
topic: Semaphores & Mutexes
difficulty: Hard
type: FUNCTION
title: Immediate Priority Ceiling Protocol With vTaskPrioritySet
tags: freertos, priority-ceiling, vtaskpriorityset, osek, autosar, resource-locking, embedded, asked-in-automotive
@@@ statement_md
OSEK/AUTOSAR OS protects shared resources with the **immediate priority ceiling protocol** (ICPP): every resource has a *ceiling* priority, and a task that gets the resource is **immediately** raised to that ceiling until it releases it. On a single core this gives mutual exclusion without ever blocking, rules out deadlock between resources, and bounds priority inversion to one critical section. FreeRTOS mutexes use priority *inheritance* instead, so you implement ICPP yourself with `uxTaskPriorityGet()` and `vTaskPrioritySet()`.

```c
typedef struct {
    UBaseType_t  ceiling;     /* set by the harness: higher than the priority of every task using it */
    UBaseType_t  saved_prio;  /* for your use */
    TaskHandle_t owner;       /* for your use */
} PcpRes;

void pcp_lock(PcpRes *r);     /* you write these two */
void pcp_unlock(PcpRes *r);
```

Rules:
- `pcp_lock(r)`: remember the caller's current priority in the resource, then raise the caller to `r->ceiling`. **Never lower** a priority: if the caller already runs above the ceiling (it holds another resource with a higher ceiling), its priority stays.
- `pcp_unlock(r)`: restore the priority that was saved when `r` was locked. Resources are released in LIFO order (the last one locked is released first), so restoring the saved value gives the right priority for nested locks.
- `pcp_lock()` never blocks. On a single core, a task that could compete for `r` never runs while `r` is held, because the holder runs at or above its priority.
- FreeRTOS mutexes and recursive mutexes, `vTaskSuspendAll()` and critical sections are not allowed (they do not compile in this exercise).

**How it is tested.** The harness reads the resources (`A`, `B`, ...) with their ceilings and a script per task. Each task waits `start` ticks, prints `[t=<tick>] <name> start (prio <p>)`, runs its script and prints `[t=<tick>] <name> end (prio <p>)`, where `p` is the task's current priority. Script operations:
- `LX`: `pcp_lock(&X)`, then print `[t=<tick>] <name> locked X (prio <p>)`;
- `UX`: print `[t=<tick>] <name> unlocks X (prio <p>)`, then `pcp_unlock(&X)`;
- `Wn`: `n` ticks of CPU work (`vSimBusyWork`, preemptible).

After the run (up to and including tick `D`) the harness prints how many locks had to wait (must be 0) and a verdict: `PCP OK`, `VIOLATION` (two tasks held a resource together), `CEILING NOT APPLIED` (a task held a resource below its ceiling) or `PRIORITY NOT RESTORED` (after an unlock the priority differs from before the matching lock).

Timing rules: lowering the own priority with `vTaskPrioritySet()` below that of a ready task gives the CPU to that task at once, at the same tick. No task's base priority equals any ceiling, and the scripts lock and unlock in LIFO order.

**Input**
```
<r>
<name> <ceiling>                        (r lines, resource names A, B, ...)
<n>
<name> <priority> <start> <k> <op_1> ... <op_k>     (n lines)
<D>
```

**Example 1**
```
Input:
1
A 4
3
L 1 1 3 LA W5 UA
M 2 2 1 W3
H 3 3 3 LA W2 UA
50

Output:
[t=1] L start (prio 1)
[t=1] L locked A (prio 4)
[t=6] L unlocks A (prio 4)
[t=6] H start (prio 3)
[t=6] H locked A (prio 4)
[t=8] H unlocks A (prio 4)
[t=8] H end (prio 3)
[t=8] M start (prio 2)
[t=11] M end (prio 2)
[t=11] L end (prio 1)
locks that waited: 0
PCP OK
```
L runs at the ceiling 4 while it holds A, so neither M (woken at t=2) nor H (woken at t=3) preempts it. When L releases A at t=6 and drops back to 1, H runs at once and gets A without waiting. M, which does not even use A, was held off too: that is the price of ICPP.

**Example 2**
```
Input:
2
A 3
B 5
3
T 1 1 7 LA W2 LB W2 UB W2 UA
U 6 5 1 W1
X 4 4 3 LB W1 UB
50

Output:
[t=1] T start (prio 1)
[t=1] T locked A (prio 3)
[t=3] T locked B (prio 5)
[t=5] U start (prio 6)
[t=6] U end (prio 6)
[t=6] T unlocks B (prio 5)
[t=6] X start (prio 4)
[t=6] X locked B (prio 5)
[t=7] X unlocks B (prio 5)
[t=7] X end (prio 4)
[t=9] T unlocks A (prio 3)
[t=9] T end (prio 1)
locks that waited: 0
PCP OK
```
U (priority 6, above every ceiling) still preempts T. After releasing B, T drops to 3 (the ceiling of A, which it still holds), not to its base priority 1. X (priority 4) then preempts it.
@@@ constraints_md
- 1 <= r <= 3, ceilings in 2..6; 1 <= n <= 4, task priorities different and in 1..6.
- 1 <= start <= 50, 1 <= k <= 9, 1 <= n in `Wn` <= 20, D <= 1000 (long enough for every script).
- Each ceiling is higher than the base priority of every task that uses the resource, and no task has a base priority equal to a ceiling.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"

typedef struct {
    UBaseType_t  ceiling;
    UBaseType_t  saved_prio;
    TaskHandle_t owner;
} PcpRes;

void pcp_lock(PcpRes *r)
{
    /* TODO: save the current priority, raise to the ceiling (never lower) */
    r->owner = xTaskGetCurrentTaskHandle();
}

void pcp_unlock(PcpRes *r)
{
    /* TODO: restore the saved priority */
    r->owner = NULL;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "sim.h"

#undef xSemaphoreCreateMutex
#undef xSemaphoreCreateRecursiveMutex
#undef taskENTER_CRITICAL
#define xSemaphoreCreateMutex() mutexes_are_not_allowed_here()
#define xSemaphoreCreateRecursiveMutex() mutexes_are_not_allowed_here()
#define taskENTER_CRITICAL() critical_sections_are_not_allowed_here()
#define vTaskSuspendAll() vTaskSuspendAll_is_not_allowed_here()

/*USER_CODE*/

#undef xSemaphoreCreateMutex
#undef xSemaphoreCreateRecursiveMutex
#undef taskENTER_CRITICAL
#undef vTaskSuspendAll

typedef struct {
    char name[8];
    TickType_t start;
    int nops;
    char ops[9][8];
} Script;

static PcpRes g_res[3];
static TaskHandle_t g_holder[3];
static UBaseType_t g_prio_before[3];
static Script g_scripts[4];
static int g_nres;
static int g_waited, g_violation, g_ceiling_bad, g_not_restored;

static void say(const char *name, const char *what)
{
    printf("[t=%u] %s %s (prio %d)\n", (unsigned)xTaskGetTickCount(), name, what, (int)uxTaskPriorityGet(NULL));
}

static void script_task(void *p)
{
    const Script *s = (const Script *)p;
    TaskHandle_t me = xTaskGetCurrentTaskHandle();
    char buf[32];
    int i, x;

    vTaskDelay(s->start);
    say(s->name, "start");
    for (i = 0; i < s->nops; i++) {
        const char *op = s->ops[i];
        if (op[0] == 'W') {
            int n = 0;
            sscanf(op + 1, "%d", &n);
            vSimBusyWork((TickType_t)n);
            continue;
        }
        x = op[1] - 'A';
        if (x < 0 || x >= g_nres) {
            printf("bad operation %s\n", op);
            continue;
        }
        if (op[0] == 'L') {
            TickType_t t0 = xTaskGetTickCount();
            UBaseType_t before = uxTaskPriorityGet(NULL);
            pcp_lock(&g_res[x]);
            if (xTaskGetTickCount() != t0) g_waited++;
            if (g_holder[x] != NULL && g_holder[x] != me) g_violation++;
            g_holder[x] = me;
            g_prio_before[x] = before;
            if (uxTaskPriorityGet(NULL) < g_res[x].ceiling) g_ceiling_bad++;
            snprintf(buf, sizeof buf, "locked %c", op[1]);
            say(s->name, buf);
        } else {
            UBaseType_t before = g_prio_before[x];
            snprintf(buf, sizeof buf, "unlocks %c", op[1]);
            say(s->name, buf);
            g_holder[x] = NULL;
            pcp_unlock(&g_res[x]);
            if (uxTaskPriorityGet(NULL) != before) g_not_restored++;
        }
    }
    say(s->name, "end");
    vTaskDelete(NULL);
}

int main(void)
{
    int i, j, n;
    unsigned ceil, prio, start, d;
    char rname[8];

    if (scanf("%d", &g_nres) != 1 || g_nres < 1 || g_nres > 3) return 1;
    for (i = 0; i < g_nres; i++) {
        if (scanf("%7s %u", rname, &ceil) != 2 || rname[0] != 'A' + i) return 1;
        g_res[i].ceiling = (UBaseType_t)ceil;
        g_res[i].saved_prio = 0;
        g_res[i].owner = NULL;
    }
    if (scanf("%d", &n) != 1 || n < 1 || n > 4) return 1;
    for (i = 0; i < n; i++) {
        Script *s = &g_scripts[i];
        if (scanf("%7s %u %u %d", s->name, &prio, &start, &s->nops) != 4 || s->nops < 1 || s->nops > 9) return 1;
        s->start = (TickType_t)start;
        for (j = 0; j < s->nops; j++) {
            if (scanf("%7s", s->ops[j]) != 1) return 1;
        }
        xTaskCreate(script_task, s->name, configMINIMAL_STACK_SIZE, s, (UBaseType_t)prio, NULL);
    }
    if (scanf("%u", &d) != 1) return 1;

    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();

    printf("locks that waited: %d\n", g_waited);
    if (g_violation) printf("VIOLATION\n");
    else if (g_ceiling_bad) printf("CEILING NOT APPLIED\n");
    else if (g_not_restored) printf("PRIORITY NOT RESTORED\n");
    else printf("PCP OK\n");
    return 0;
}
@@@ sample_input
1
A 4
3
L 1 1 3 LA W5 UA
M 2 2 1 W3
H 3 3 3 LA W2 UA
50
@@@ sample_output
[t=1] L start (prio 1)
[t=1] L locked A (prio 4)
[t=6] L unlocks A (prio 4)
[t=6] H start (prio 3)
[t=6] H locked A (prio 4)
[t=8] H unlocks A (prio 4)
[t=8] H end (prio 3)
[t=8] M start (prio 2)
[t=11] M end (prio 2)
[t=11] L end (prio 1)
locks that waited: 0
PCP OK
@@@ sample_input
2
A 3
B 5
3
T 1 1 7 LA W2 LB W2 UB W2 UA
U 6 5 1 W1
X 4 4 3 LB W1 UB
50
@@@ sample_output
[t=1] T start (prio 1)
[t=1] T locked A (prio 3)
[t=3] T locked B (prio 5)
[t=5] U start (prio 6)
[t=6] U end (prio 6)
[t=6] T unlocks B (prio 5)
[t=6] X start (prio 4)
[t=6] X locked B (prio 5)
[t=7] X unlocks B (prio 5)
[t=7] X end (prio 4)
[t=9] T unlocks A (prio 3)
[t=9] T end (prio 1)
locks that waited: 0
PCP OK
@@@ hidden_input
1
A 2
1
S 1 1 5 LA W1 UA LA UA
20
@@@ hidden_output
[t=1] S start (prio 1)
[t=1] S locked A (prio 2)
[t=2] S unlocks A (prio 2)
[t=2] S locked A (prio 2)
[t=2] S unlocks A (prio 2)
[t=2] S end (prio 1)
locks that waited: 0
PCP OK
@@@ hidden_input
2
A 3
B 6
2
T 1 1 9 LB W2 LA W2 UA W2 UB W1 W1
Y 2 2 3 LA W1 UA
60
@@@ hidden_output
[t=1] T start (prio 1)
[t=1] T locked B (prio 6)
[t=3] T locked A (prio 6)
[t=5] T unlocks A (prio 6)
[t=7] T unlocks B (prio 6)
[t=7] Y start (prio 2)
[t=7] Y locked A (prio 3)
[t=8] Y unlocks A (prio 3)
[t=8] Y end (prio 2)
[t=10] T end (prio 1)
locks that waited: 0
PCP OK

@@@ hidden_input
2
A 3
B 6
4
P 1 1 7 LA W3 LB W3 UB UA W1
Q 2 2 1 W4
R 4 3 3 LB W2 UB
S 5 5 3 LB W1 UB
200
@@@ hidden_output
[t=1] P start (prio 1)
[t=1] P locked A (prio 3)
[t=3] R start (prio 4)
[t=3] R locked B (prio 6)
[t=5] R unlocks B (prio 6)
[t=5] S start (prio 5)
[t=5] S locked B (prio 6)
[t=6] S unlocks B (prio 6)
[t=6] S end (prio 5)
[t=6] R end (prio 4)
[t=7] P locked B (prio 6)
[t=10] P unlocks B (prio 6)
[t=10] P unlocks A (prio 3)
[t=10] Q start (prio 2)
[t=14] Q end (prio 2)
[t=15] P end (prio 1)
locks that waited: 0
PCP OK

@@@ hidden_input
1
A 5
4
D 1 4 3 LA W6 UA
C 2 3 3 LA W1 UA
B 3 2 3 LA W2 UA
E 4 1 3 LA W3 UA
100
@@@ hidden_output
[t=1] E start (prio 4)
[t=1] E locked A (prio 5)
[t=4] E unlocks A (prio 5)
[t=4] E end (prio 4)
[t=4] B start (prio 3)
[t=4] B locked A (prio 5)
[t=6] B unlocks A (prio 5)
[t=6] B end (prio 3)
[t=6] C start (prio 2)
[t=6] C locked A (prio 5)
[t=7] C unlocks A (prio 5)
[t=7] C end (prio 2)
[t=7] D start (prio 1)
[t=7] D locked A (prio 5)
[t=13] D unlocks A (prio 5)
[t=13] D end (prio 1)
locks that waited: 0
PCP OK

@@@ hidden_input
2
A 4
B 6
3
L 2 1 7 LA W4 LB W3 UB W3 UA
H 5 4 3 LB W2 UB
M 3 2 3 LA W1 UA
200
@@@ hidden_output
[t=1] L start (prio 2)
[t=1] L locked A (prio 4)
[t=4] H start (prio 5)
[t=4] H locked B (prio 6)
[t=6] H unlocks B (prio 6)
[t=6] H end (prio 5)
[t=7] L locked B (prio 6)
[t=10] L unlocks B (prio 6)
[t=13] L unlocks A (prio 4)
[t=13] M start (prio 3)
[t=13] M locked A (prio 4)
[t=14] M unlocks A (prio 4)
[t=14] M end (prio 3)
[t=14] L end (prio 2)
locks that waited: 0
PCP OK

@@@ hint
`uxTaskPriorityGet(NULL)` returns the caller's current priority and `vTaskPrioritySet(NULL, p)` changes it. Store the old value **in the resource** (`r->saved_prio`), not in a single global: with nested resources every level needs its own saved value.
@@@ hint
`pcp_lock`: `r->saved_prio = uxTaskPriorityGet(NULL); if (r->ceiling > r->saved_prio) vTaskPrioritySet(NULL, r->ceiling); r->owner = me;`. `pcp_unlock`: `r->owner = NULL; vTaskPrioritySet(NULL, r->saved_prio);`. The restore may let a higher-priority task run immediately, so finish all bookkeeping before it.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"

typedef struct {
    UBaseType_t  ceiling;
    UBaseType_t  saved_prio;
    TaskHandle_t owner;
} PcpRes;

void pcp_lock(PcpRes *r)
{
    UBaseType_t cur = uxTaskPriorityGet(NULL);

    configASSERT(r->owner == NULL);          /* ICPP on one core: a free resource is guaranteed */
    r->saved_prio = cur;                     /* per resource -> correct for nested (LIFO) locks */
    if (r->ceiling > cur) {
        vTaskPrioritySet(NULL, r->ceiling);  /* raise immediately; never lower */
    }
    r->owner = xTaskGetCurrentTaskHandle();
}

void pcp_unlock(PcpRes *r)
{
    UBaseType_t back = r->saved_prio;

    configASSERT(r->owner == xTaskGetCurrentTaskHandle());
    r->owner = NULL;                         /* bookkeeping first: the next line may switch tasks */
    vTaskPrioritySet(NULL, back);
}
@@@ explanation_md
**Approach.** Immediate priority ceiling protocol (also called *highest locker* or OSEK *priority ceiling*): on `pcp_lock()` the task saves its current priority in the resource and raises itself to the ceiling (only if that is higher). On `pcp_unlock()` it restores the saved priority. The ceiling of a resource is above the priority of every task that uses it. So while a task holds the resource, no other user of the resource can run (single core): mutual exclusion comes from scheduling alone, and `pcp_lock()` never blocks. A task can only be delayed **before** it starts, by at most one lower-priority critical section, and two tasks can never deadlock on two resources, because a task that holds one resource can never be preempted by another user of it.

Nested locks work because every resource stores the priority from just before its own lock. With LIFO release, restoring that value returns exactly to the priority of the enclosing level: in Example 2 T goes from 5 back to 3 (it still holds A), then to 1.

**Complexity.** O(1) per lock/unlock (`vTaskPrioritySet` moves the task between ready lists). Worst-case blocking of any task: one critical section of a lower-priority task that uses a resource with a ceiling >= its priority. RAM: two words per resource, nothing per task.

**Common mistakes**
- Saving the priority in one global or per-task variable: after the inner unlock the task drops to its base priority while it still holds the outer resource, and another user can preempt it and enter (`VIOLATION`).
- Lowering the priority when a nested resource has a lower ceiling than the current priority.
- Restoring the priority **before** clearing the owner: the restore can switch to another task that then sees the resource as taken.
- Choosing a ceiling equal to the priority of an unrelated task: time slicing at equal priority can let it run, and it is not "above" the ceiling.
- Releasing in non-LIFO order: the saved priorities no longer form a stack. OSEK forbids it; check it with an assertion in production code.

**Interview follow-ups**
- Priority inheritance vs priority ceiling: which bounds blocking better, which costs more at run time, which prevents deadlock?
- How does AUTOSAR OS implement `GetResource()`/`ReleaseResource()` and what is `RES_SCHEDULER`?
- What changes on a multicore ECU (spinlocks, MPCP/MSRP)?
- How would you compute the ceilings automatically from a static configuration (OIL/ARXML)?
