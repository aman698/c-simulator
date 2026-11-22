@@@ meta
id: RSM-M-01
topic: Semaphores & Mutexes
difficulty: Medium
type: FUNCTION
title: Priority Inversion: Binary Semaphore vs Mutex With Inheritance
tags: freertos, priority-inversion, priority-inheritance, mutex, binary-semaphore, embedded, asked-in-automotive
@@@ statement_md
Three tasks share a CAN transmit buffer: **L** (priority 1, diagnostics), **M** (priority 2, a CPU-heavy calculation that never touches the buffer) and **H** (priority 3, brake status). L and H protect the buffer with one lock. Your job is to build the scenario twice, once with a **binary semaphore** and once with a **mutex**, and observe the difference: with the semaphore, M can delay H for an unbounded time (priority inversion); with the mutex, L inherits H's priority and M cannot run in between.

```c
typedef struct {
    int        use_mutex;          /* 1: lock = mutex, 0: lock = binary semaphore */
    TickType_t l_start, l_work;    /* L: start delay, CPU ticks inside the lock */
    TickType_t m_start, m_work;    /* M: start delay, CPU ticks (no lock)        */
    TickType_t h_start, h_work;    /* H: start delay, CPU ticks inside the lock */
} InvCfg;

/* provided by the hidden harness */
void trace(const char *who, const char *what);
        /* prints "[t=<tick>] <who> <what> (prio <p>)", p = current priority of the calling task */
void cpu_work(TickType_t ticks);   /* CPU-bound work, `ticks` ticks of CPU time */

void app_start(const InvCfg *cfg); /* you write this (and the three task functions) */
```

`app_start()` is called **before** the scheduler starts. It creates the lock (a mutex or a binary semaphore, depending on `use_mutex`) so that it is initially **free**, and the three tasks with priorities L = 1, M = 2, H = 3. Each task runs once and then deletes itself:

- **L**: `vTaskDelay(l_start)`; take the lock (wait forever); `trace("L", "lock")`; `cpu_work(l_work)`; `trace("L", "unlock")`; give the lock.
- **M**: `vTaskDelay(m_start)`; `trace("M", "start")`; `cpu_work(m_work)`; `trace("M", "done")`.
- **H**: `vTaskDelay(h_start)`; `trace("H", "wants lock")`; take the lock (wait forever); `trace("H", "lock")`; `cpu_work(h_work)`; `trace("H", "unlock")`; give the lock.

**How it is tested.** The hidden `main()` reads the mode (`MUTEX` or `BINARY`), the three `start work` pairs and a duration `D`, calls `app_start()` and runs the scheduler up to and including tick `D` (always long enough for all three tasks). It then prints how long H waited for the lock, how many ticks of M's work ran while H was blocked, and a verdict: `VERDICT: PRIORITY INVERSION` if M ran while H was blocked, otherwise `VERDICT: BOUNDED`.

Timing rules: `cpu_work()` takes CPU time, ticks advance while it runs and a task with a higher (possibly inherited) priority that becomes ready preempts it at once. A give that unblocks a higher-priority task lets that task run at the same tick. The `(prio p)` printed by `trace()` shows inheritance: L prints `unlock (prio 3)` when it holds the mutex while H waits.

**Input**
```
<MUTEX|BINARY>
L <l_start> <l_work>
M <m_start> <m_work>
H <h_start> <h_work>
<D>
```

**Example 1**
```
Input:
MUTEX
L 1 6
M 4 5
H 3 2
40

Output:
[t=1] L lock (prio 1)
[t=3] H wants lock (prio 3)
[t=7] L unlock (prio 3)
[t=7] H lock (prio 3)
[t=9] H unlock (prio 3)
[t=9] M start (prio 2)
[t=14] M done (prio 2)
H waited 4 ticks for the lock
M ran 0 ticks while H was blocked
VERDICT: BOUNDED
```
H blocks at t=3 and L inherits priority 3. M becomes ready at t=4 but cannot preempt L. L finishes its 6 ticks of work at t=7 and H gets the lock immediately.

**Example 2** (same timing, binary semaphore)
```
Input:
BINARY
L 1 6
M 4 5
H 3 2
40

Output:
[t=1] L lock (prio 1)
[t=3] H wants lock (prio 3)
[t=4] M start (prio 2)
[t=9] M done (prio 2)
[t=12] L unlock (prio 1)
[t=12] H lock (prio 3)
[t=14] H unlock (prio 3)
H waited 9 ticks for the lock
M ran 5 ticks while H was blocked
VERDICT: PRIORITY INVERSION
```
Without inheritance L keeps priority 1, so M preempts it at t=4 and runs all 5 ticks while H is still waiting for L.
@@@ constraints_md
- 1 <= start <= 100, 1 <= work <= 50 for every task, D <= 1000.
- Priorities are fixed: L = 1, M = 2, H = 3. Stack size `configMINIMAL_STACK_SIZE`.
- Simulated time: 1 tick = 1 ms. Only `vTaskDelay`, blocking waits and `cpu_work()` take time.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

typedef struct {
    int        use_mutex;
    TickType_t l_start, l_work;
    TickType_t m_start, m_work;
    TickType_t h_start, h_work;
} InvCfg;

void trace(const char *who, const char *what);
void cpu_work(TickType_t ticks);

static SemaphoreHandle_t s_lock;
static const InvCfg *s_cfg;

static void task_l(void *p)
{
    (void)p;
    /* TODO */
    vTaskDelete(NULL);
}

static void task_m(void *p)
{
    (void)p;
    /* TODO */
    vTaskDelete(NULL);
}

static void task_h(void *p)
{
    (void)p;
    /* TODO */
    vTaskDelete(NULL);
}

void app_start(const InvCfg *cfg)
{
    s_cfg = cfg;
    /* TODO: create the lock (free!) and the three tasks */
    (void)s_lock;
    (void)task_l;
    (void)task_m;
    (void)task_h;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "sim.h"

static int g_h_blocked;
static int g_h_got;
static int g_m_ticks_while_h_blocked;
static TickType_t g_h_want, g_h_lock;
static int g_m_done;

void trace(const char *who, const char *what)
{
    TickType_t now = xTaskGetTickCount();

    printf("[t=%u] %s %s (prio %d)\n", (unsigned)now, who, what, (int)uxTaskPriorityGet(NULL));
    if (strcmp(who, "H") == 0 && strcmp(what, "wants lock") == 0) {
        g_h_blocked = 1;
        g_h_want = now;
    } else if (strcmp(who, "H") == 0 && strcmp(what, "lock") == 0) {
        g_h_blocked = 0;
        g_h_got = 1;
        g_h_lock = now;
    } else if (strcmp(who, "M") == 0 && strcmp(what, "done") == 0) {
        g_m_done = 1;
    }
}

void cpu_work(TickType_t ticks)
{
    const char *me = pcTaskGetName(NULL);

    while (ticks-- > 0) {
        if (g_h_blocked && strcmp(me, "M") == 0) g_m_ticks_while_h_blocked++;
        vSimBusyWork(1);
    }
}

/*USER_CODE*/

int main(void)
{
    static InvCfg cfg;
    char mode[16];
    unsigned ls, lw, ms, mw, hs, hw, d;

    if (scanf("%15s", mode) != 1) return 1;
    if (scanf(" L %u %u M %u %u H %u %u %u", &ls, &lw, &ms, &mw, &hs, &hw, &d) != 7) return 1;
    cfg.use_mutex = strcmp(mode, "MUTEX") == 0;
    cfg.l_start = (TickType_t)ls; cfg.l_work = (TickType_t)lw;
    cfg.m_start = (TickType_t)ms; cfg.m_work = (TickType_t)mw;
    cfg.h_start = (TickType_t)hs; cfg.h_work = (TickType_t)hw;

    app_start(&cfg);
    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();

    if (!g_h_got) {
        printf("H never got the lock\n");
        printf("VERDICT: DEADLOCK\n");
        return 0;
    }
    printf("H waited %u ticks for the lock\n", (unsigned)(g_h_lock - g_h_want));
    printf("M ran %d ticks while H was blocked\n", g_m_ticks_while_h_blocked);
    if (!g_m_done) printf("M never finished\n");
    printf("VERDICT: %s\n", g_m_ticks_while_h_blocked > 0 ? "PRIORITY INVERSION" : "BOUNDED");
    return 0;
}
@@@ sample_input
MUTEX
L 1 6
M 4 5
H 3 2
40
@@@ sample_output
[t=1] L lock (prio 1)
[t=3] H wants lock (prio 3)
[t=7] L unlock (prio 3)
[t=7] H lock (prio 3)
[t=9] H unlock (prio 3)
[t=9] M start (prio 2)
[t=14] M done (prio 2)
H waited 4 ticks for the lock
M ran 0 ticks while H was blocked
VERDICT: BOUNDED
@@@ sample_input
BINARY
L 1 6
M 4 5
H 3 2
40
@@@ sample_output
[t=1] L lock (prio 1)
[t=3] H wants lock (prio 3)
[t=4] M start (prio 2)
[t=9] M done (prio 2)
[t=12] L unlock (prio 1)
[t=12] H lock (prio 3)
[t=14] H unlock (prio 3)
H waited 9 ticks for the lock
M ran 5 ticks while H was blocked
VERDICT: PRIORITY INVERSION
@@@ hidden_input
MUTEX
L 5 3
M 20 4
H 1 2
60
@@@ hidden_output
[t=1] H wants lock (prio 3)
[t=1] H lock (prio 3)
[t=3] H unlock (prio 3)
[t=5] L lock (prio 1)
[t=8] L unlock (prio 1)
[t=20] M start (prio 2)
[t=24] M done (prio 2)
H waited 0 ticks for the lock
M ran 0 ticks while H was blocked
VERDICT: BOUNDED
@@@ hidden_input
BINARY
L 1 10
M 3 4
H 5 1
80
@@@ hidden_output
[t=1] L lock (prio 1)
[t=3] M start (prio 2)
[t=5] H wants lock (prio 3)
[t=7] M done (prio 2)
[t=15] L unlock (prio 1)
[t=15] H lock (prio 3)
[t=16] H unlock (prio 3)
H waited 10 ticks for the lock
M ran 2 ticks while H was blocked
VERDICT: PRIORITY INVERSION

@@@ hidden_input
MUTEX
L 1 10
M 3 4
H 5 1
80
@@@ hidden_output
[t=1] L lock (prio 1)
[t=3] M start (prio 2)
[t=5] H wants lock (prio 3)
[t=13] L unlock (prio 3)
[t=13] H lock (prio 3)
[t=14] H unlock (prio 3)
[t=16] M done (prio 2)
H waited 8 ticks for the lock
M ran 0 ticks while H was blocked
VERDICT: BOUNDED

@@@ hidden_input
BINARY
L 2 3
M 2 3
H 2 3
50
@@@ hidden_output
[t=2] H wants lock (prio 3)
[t=2] H lock (prio 3)
[t=5] H unlock (prio 3)
[t=5] M start (prio 2)
[t=8] M done (prio 2)
[t=8] L lock (prio 1)
[t=11] L unlock (prio 1)
H waited 0 ticks for the lock
M ran 0 ticks while H was blocked
VERDICT: BOUNDED

@@@ hidden_input
BINARY
L 1 20
M 2 30
H 10 5
200
@@@ hidden_output
[t=1] L lock (prio 1)
[t=2] M start (prio 2)
[t=10] H wants lock (prio 3)
[t=32] M done (prio 2)
[t=51] L unlock (prio 1)
[t=51] H lock (prio 3)
[t=56] H unlock (prio 3)
H waited 41 ticks for the lock
M ran 22 ticks while H was blocked
VERDICT: PRIORITY INVERSION

@@@ hidden_input
MUTEX
L 1 20
M 2 30
H 10 5
200
@@@ hidden_output
[t=1] L lock (prio 1)
[t=2] M start (prio 2)
[t=10] H wants lock (prio 3)
[t=29] L unlock (prio 3)
[t=29] H lock (prio 3)
[t=34] H unlock (prio 3)
[t=56] M done (prio 2)
H waited 19 ticks for the lock
M ran 0 ticks while H was blocked
VERDICT: BOUNDED

@@@ hint
`xSemaphoreCreateBinary()` returns an **empty** semaphore: as a lock it starts "taken". Give it once right after creating it. `xSemaphoreCreateMutex()` is created free. Both are taken and given with the same `xSemaphoreTake()` / `xSemaphoreGive()` calls.
@@@ hint
Only the creation differs: `s_lock = cfg->use_mutex ? xSemaphoreCreateMutex() : xSemaphoreCreateBinary();` followed by `if (!cfg->use_mutex) xSemaphoreGive(s_lock);`. The kernel does the rest: a task blocking on a **mutex** raises the holder's priority to its own until the holder gives it back.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

typedef struct {
    int        use_mutex;
    TickType_t l_start, l_work;
    TickType_t m_start, m_work;
    TickType_t h_start, h_work;
} InvCfg;

void trace(const char *who, const char *what);
void cpu_work(TickType_t ticks);

static SemaphoreHandle_t s_lock;
static const InvCfg *s_cfg;

static void task_l(void *p)
{
    (void)p;
    vTaskDelay(s_cfg->l_start);
    xSemaphoreTake(s_lock, portMAX_DELAY);
    trace("L", "lock");
    cpu_work(s_cfg->l_work);        /* with a mutex: runs at H's priority once H waits */
    trace("L", "unlock");
    xSemaphoreGive(s_lock);         /* priority drops back to 1 here */
    vTaskDelete(NULL);
}

static void task_m(void *p)
{
    (void)p;
    vTaskDelay(s_cfg->m_start);
    trace("M", "start");
    cpu_work(s_cfg->m_work);
    trace("M", "done");
    vTaskDelete(NULL);
}

static void task_h(void *p)
{
    (void)p;
    vTaskDelay(s_cfg->h_start);
    trace("H", "wants lock");
    xSemaphoreTake(s_lock, portMAX_DELAY);
    trace("H", "lock");
    cpu_work(s_cfg->h_work);
    trace("H", "unlock");
    xSemaphoreGive(s_lock);
    vTaskDelete(NULL);
}

void app_start(const InvCfg *cfg)
{
    s_cfg = cfg;
    if (cfg->use_mutex) {
        s_lock = xSemaphoreCreateMutex();          /* created available, has priority inheritance */
    } else {
        s_lock = xSemaphoreCreateBinary();         /* created EMPTY ... */
        xSemaphoreGive(s_lock);                    /* ... so make it available */
    }
    xTaskCreate(task_l, "L", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    xTaskCreate(task_m, "M", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
    xTaskCreate(task_h, "H", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
}
@@@ explanation_md
**Approach.** The code of the three tasks is identical in both modes; only the lock object changes.

- **Binary semaphore**: when H blocks on a semaphore held by L, nothing changes for L, which still runs at priority 1. Any task between L and H (M) preempts L and runs to completion while H waits. H's blocking time becomes "L's critical section + all medium-priority work", which is unbounded. This is the Mars Pathfinder bug.
- **Mutex**: `xSemaphoreTake()` on a held mutex calls `xTaskPriorityInherit()`, which raises the holder L to H's priority. M can no longer preempt L, L finishes its critical section, `xSemaphoreGive()` restores L's base priority (`xTaskPriorityDisinherit()`) and H runs at the same tick. H's blocking time is bounded by L's critical section.

The printed `(prio 3)` for `L unlock` in mutex mode is the inherited priority. Note that M only *starts* after H has finished: inheritance holds M off for the whole critical section, not only while H is waiting.

**Complexity.** Take/give are O(1) plus an O(n) event-list insertion. Inheritance costs a ready-list move of the holder (O(1)). Worst-case blocking of H with a mutex: the longest critical section of a lower-priority task that uses the same mutex (plus transitive chains with nested mutexes). With a binary semaphore it is unbounded.

**Common mistakes**
- Forgetting that `xSemaphoreCreateBinary()` starts **empty**: L blocks forever and the run ends in a deadlock.
- Giving a mutex from a task that does not hold it (or from an ISR): mutexes have an owner, FreeRTOS asserts.
- Believing inheritance removes all blocking: H still waits for L's critical section. Keep critical sections short.
- Holding a mutex across a long blocking call (a queue receive, `vTaskDelay`): inheritance cannot speed that up.
- Nested mutexes: FreeRTOS restores the base priority only when the holder has released **all** mutexes it holds, so a task can keep an inherited priority longer than expected.

**Interview follow-ups**
- Explain the Mars Pathfinder incident and how it was fixed in the field.
- Priority inheritance vs priority ceiling (immediate ceiling, used by OSEK/AUTOSAR): pros and cons.
- Can a mutex be used from an ISR? Why not?
- How would you detect priority inversion on a real target (trace tools, blocking-time measurements)?
