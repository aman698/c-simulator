@@@ meta
id: RSM-H-02
topic: Semaphores & Mutexes
difficulty: Hard
type: FUNCTION
title: Reusable N-Task Barrier Built From Semaphores
tags: freertos, barrier, counting-semaphore, mutex, task-synchronization, sensor-fusion, embedded
@@@ statement_md
A sensor-fusion ECU runs `n` tasks in lock-step rounds: each task computes its part of the round (radar, camera, lidar, ...) and must not start the next round before **all** tasks have finished the current one. Implement a **reusable barrier** with semaphores and a mutex. Event groups (`xEventGroupSync`), task notifications, queues and suspend/resume are not allowed (they do not compile in this exercise).

```c
void barrier_init(int n);   /* called before the scheduler starts, 2 <= n <= 5 */
void barrier_wait(void);    /* returns only when all n tasks have called it for this round */
```

Requirements:
- `barrier_wait()` blocks the caller until the `n`-th task of the **current round** arrives. Then all `n` tasks are released.
- The barrier is used again and again. A fast task that is released, computes its next round quickly and calls `barrier_wait()` again must **not** slip through the next round, and must not steal a wake-up that belongs to a slower task of the previous round.
- No polling (`vTaskDelay` loops): waiting tasks must block on a semaphore.

**How it is tested.** The harness creates the `n` tasks (with the given priorities). Each one waits `start` ticks, then for every round `r = 1..R`: does `w_r` ticks of CPU work (`vSimBusyWork`, so higher-priority tasks preempt lower ones), prints `[t=<tick>] <name> arrives <r>` and calls `barrier_wait()`. When a task returns from `barrier_wait()` the harness checks that all `n` tasks have arrived for that round, and the **first** task to return prints `[t=<tick>] round <r> released`. After the run (up to and including tick `D`) it prints how many rounds every task passed and `BARRIER OK`, `EARLY RELEASE` (a task returned before everybody arrived) or `STUCK` (a task did not finish all rounds).

Timing rules: code outside `vSimBusyWork` takes no time, so with a correct barrier the round is released at the tick of the last arrival. Among tasks released together, the highest priority runs first. A task does its CPU work only when no higher-priority task is running. The `start` delay is a `vTaskDelay(start)` at the top of the task, so it begins when the task **first runs**: a low-priority task whose higher-priority neighbours are busy at t=0 starts counting later.

**Input**
```
<n> <R>
<name> <priority> <start> <w_1> ... <w_R>     (n lines)
<D>
```

**Example 1**
```
Input:
3 2
A 3 0 2 3
B 2 0 4 1
C 1 0 1 2
100

Output:
[t=2] A arrives 1
[t=6] B arrives 1
[t=7] C arrives 1
[t=7] round 1 released
[t=10] A arrives 2
[t=11] B arrives 2
[t=13] C arrives 2
[t=13] round 2 released
A passed 2 of 2
B passed 2 of 2
C passed 2 of 2
BARRIER OK
```
A (highest priority) computes first, then B, then C. Round 1 is released when C arrives at t=7.

**Example 2**
```
Input:
3 2
H 3 10 1 1
M 2 0 1 1
L 1 0 1 1
100

Output:
[t=1] M arrives 1
[t=2] L arrives 1
[t=11] H arrives 1
[t=11] round 1 released
[t=12] H arrives 2
[t=13] M arrives 2
[t=14] L arrives 2
[t=14] round 2 released
H passed 2 of 2
M passed 2 of 2
L passed 2 of 2
BARRIER OK
```
H arrives last in round 1 and is the highest-priority task: it computes round 2 before M and L have even run. A naive barrier ("the last task gives the semaphore `n-1` times") lets H take one of those wake-ups for itself at t=12 and pass round 2 alone.
@@@ constraints_md
- 2 <= n <= 5, 1 <= R <= 4, priorities different and in 1..6.
- 0 <= start <= 50, 1 <= w_r <= 20, D <= 2000 (long enough for a correct barrier).
- Simulated time: 1 tick = 1 ms.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

void barrier_init(int n)
{
    /* TODO: create a mutex and the semaphores you need */
    (void)n;
}

void barrier_wait(void)
{
    /* TODO: block until all n tasks of this round have arrived */
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "sim.h"

void barrier_init(int n);
void barrier_wait(void);

#undef xQueueCreate
#define xQueueCreate(a, b) xQueueCreate_is_not_allowed_here()
#define xEventGroupCreate() event_groups_are_not_allowed_here()
#define xEventGroupSync(...) event_groups_are_not_allowed_here()
#define xTaskGenericNotify(...) task_notifications_are_not_allowed_here()
#define ulTaskGenericNotifyTake(...) task_notifications_are_not_allowed_here()
#define xTaskGenericNotifyWait(...) task_notifications_are_not_allowed_here()
#define vTaskSuspend(t) vTaskSuspend_is_not_allowed_here()
#define vTaskResume(t) vTaskResume_is_not_allowed_here()

/*USER_CODE*/

#undef xQueueCreate
#undef xEventGroupCreate
#undef xEventGroupSync
#undef xTaskGenericNotify
#undef ulTaskGenericNotifyTake
#undef xTaskGenericNotifyWait
#undef vTaskSuspend
#undef vTaskResume

typedef struct {
    char name[8];
    TickType_t start;
    TickType_t work[4];
    int passed;
} Worker;

static Worker g_w[5];
static int g_n, g_rounds;
static int g_arrived[5], g_released[5];
static int g_early;

static void worker_task(void *p)
{
    Worker *w = (Worker *)p;
    int r;

    if (w->start > 0) vTaskDelay(w->start);
    for (r = 0; r < g_rounds; r++) {
        vSimBusyWork(w->work[r]);
        printf("[t=%u] %s arrives %d\n", (unsigned)xTaskGetTickCount(), w->name, r + 1);
        g_arrived[r]++;
        barrier_wait();
        if (g_arrived[r] != g_n) g_early++;
        if (!g_released[r]) {
            g_released[r] = 1;
            printf("[t=%u] round %d released\n", (unsigned)xTaskGetTickCount(), r + 1);
        }
        w->passed++;
    }
    vTaskDelete(NULL);
}

int main(void)
{
    int i, r, stuck = 0;
    unsigned prio, start, work, d;

    if (scanf("%d %d", &g_n, &g_rounds) != 2 || g_n < 2 || g_n > 5 || g_rounds < 1 || g_rounds > 4) return 1;
    barrier_init(g_n);
    for (i = 0; i < g_n; i++) {
        Worker *w = &g_w[i];
        if (scanf("%7s %u %u", w->name, &prio, &start) != 3) return 1;
        w->start = (TickType_t)start;
        for (r = 0; r < g_rounds; r++) {
            if (scanf("%u", &work) != 1) return 1;
            w->work[r] = (TickType_t)work;
        }
        xTaskCreate(worker_task, w->name, configMINIMAL_STACK_SIZE, w, (UBaseType_t)prio, NULL);
    }
    if (scanf("%u", &d) != 1) return 1;

    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();

    for (i = 0; i < g_n; i++) {
        printf("%s passed %d of %d\n", g_w[i].name, g_w[i].passed, g_rounds);
        if (g_w[i].passed != g_rounds) stuck++;
    }
    if (g_early) printf("EARLY RELEASE\n");
    else if (stuck) printf("STUCK\n");
    else printf("BARRIER OK\n");
    return 0;
}
@@@ sample_input
3 2
A 3 0 2 3
B 2 0 4 1
C 1 0 1 2
100
@@@ sample_output
[t=2] A arrives 1
[t=6] B arrives 1
[t=7] C arrives 1
[t=7] round 1 released
[t=10] A arrives 2
[t=11] B arrives 2
[t=13] C arrives 2
[t=13] round 2 released
A passed 2 of 2
B passed 2 of 2
C passed 2 of 2
BARRIER OK
@@@ sample_input
3 2
H 3 10 1 1
M 2 0 1 1
L 1 0 1 1
100
@@@ sample_output
[t=1] M arrives 1
[t=2] L arrives 1
[t=11] H arrives 1
[t=11] round 1 released
[t=12] H arrives 2
[t=13] M arrives 2
[t=14] L arrives 2
[t=14] round 2 released
H passed 2 of 2
M passed 2 of 2
L passed 2 of 2
BARRIER OK
@@@ hidden_input
2 1
X 1 0 5
Y 2 0 5
50
@@@ hidden_output
[t=5] Y arrives 1
[t=10] X arrives 1
[t=10] round 1 released
X passed 1 of 1
Y passed 1 of 1
BARRIER OK
@@@ hidden_input
5 4
A 6 30 1 1 1 1
B 5 20 2 1 3 1
C 4 0 3 2 1 4
D 3 5 1 5 2 2
E 2 1 4 1 1 1
500
@@@ hidden_output
[t=3] C arrives 1
[t=9] D arrives 1
[t=9] E arrives 1
[t=22] B arrives 1
[t=31] A arrives 1
[t=31] round 1 released
[t=32] A arrives 2
[t=33] B arrives 2
[t=35] C arrives 2
[t=40] D arrives 2
[t=41] E arrives 2
[t=41] round 2 released
[t=42] A arrives 3
[t=45] B arrives 3
[t=46] C arrives 3
[t=48] D arrives 3
[t=49] E arrives 3
[t=49] round 3 released
[t=50] A arrives 4
[t=51] B arrives 4
[t=55] C arrives 4
[t=57] D arrives 4
[t=58] E arrives 4
[t=58] round 4 released
A passed 4 of 4
B passed 4 of 4
C passed 4 of 4
D passed 4 of 4
E passed 4 of 4
BARRIER OK

@@@ hidden_input
4 3
P 1 0 1 1 1
Q 2 1 1 1 1
R 3 2 1 1 1
S 4 3 1 1 1
200
@@@ hidden_output
[t=4] S arrives 1
[t=4] R arrives 1
[t=4] Q arrives 1
[t=4] P arrives 1
[t=4] round 1 released
[t=5] S arrives 2
[t=6] R arrives 2
[t=7] Q arrives 2
[t=8] P arrives 2
[t=8] round 2 released
[t=9] S arrives 3
[t=10] R arrives 3
[t=11] Q arrives 3
[t=12] P arrives 3
[t=12] round 3 released
P passed 3 of 3
Q passed 3 of 3
R passed 3 of 3
S passed 3 of 3
BARRIER OK

@@@ hidden_input
3 4
F 5 0 20 1 20 1
G 4 40 1 20 1 20
K 3 0 1 1 1 1
800
@@@ hidden_output
[t=20] F arrives 1
[t=21] K arrives 1
[t=61] G arrives 1
[t=61] round 1 released
[t=62] F arrives 2
[t=82] G arrives 2
[t=83] K arrives 2
[t=83] round 2 released
[t=103] F arrives 3
[t=104] G arrives 3
[t=105] K arrives 3
[t=105] round 3 released
[t=106] F arrives 4
[t=126] G arrives 4
[t=127] K arrives 4
[t=127] round 4 released
F passed 4 of 4
G passed 4 of 4
K passed 4 of 4
BARRIER OK

@@@ hidden_input
2 4
Lo 1 0 1 1 1 1
Hi 6 3 1 1 1 1
100
@@@ hidden_output
[t=1] Lo arrives 1
[t=4] Hi arrives 1
[t=4] round 1 released
[t=5] Hi arrives 2
[t=6] Lo arrives 2
[t=6] round 2 released
[t=7] Hi arrives 3
[t=8] Lo arrives 3
[t=8] round 3 released
[t=9] Hi arrives 4
[t=10] Lo arrives 4
[t=10] round 4 released
Lo passed 4 of 4
Hi passed 4 of 4
BARRIER OK

@@@ hint
The naive version (a counter under a mutex, the last task gives a semaphore `n-1` times) breaks when a released task comes back before the other released tasks have actually run: its new `take()` consumes a token meant for them. You need a second phase that makes sure **everybody has left** round `r` before anyone can pass round `r+1`.
@@@ hint
Two-phase (turnstile) barrier: a mutex, a counter and two counting semaphores `in` and `out` (max `n`, initial 0). Phase 1: lock; `if (++count == n)` give `in` n times; unlock; take `in`. Phase 2: lock; `if (--count == 0)` give `out` n times; unlock; take `out`. Each task takes exactly one token of each kind per round.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

static SemaphoreHandle_t s_mutex;   /* protects s_count */
static SemaphoreHandle_t s_in;      /* phase 1 turnstile: opened when all n have arrived */
static SemaphoreHandle_t s_out;     /* phase 2 turnstile: opened when all n have left phase 1 */
static int s_n, s_count;

void barrier_init(int n)
{
    s_n = n;
    s_count = 0;
    s_mutex = xSemaphoreCreateMutex();
    s_in = xSemaphoreCreateCounting((UBaseType_t)n, 0);
    s_out = xSemaphoreCreateCounting((UBaseType_t)n, 0);
}

void barrier_wait(void)
{
    int i;

    /* phase 1: wait until everybody has arrived */
    xSemaphoreTake(s_mutex, portMAX_DELAY);
    if (++s_count == s_n) {
        for (i = 0; i < s_n; i++) xSemaphoreGive(s_in);    /* one token per task, including me */
    }
    xSemaphoreGive(s_mutex);
    xSemaphoreTake(s_in, portMAX_DELAY);

    /* phase 2: wait until everybody has taken its phase-1 token */
    xSemaphoreTake(s_mutex, portMAX_DELAY);
    if (--s_count == 0) {
        for (i = 0; i < s_n; i++) xSemaphoreGive(s_out);
    }
    xSemaphoreGive(s_mutex);
    xSemaphoreTake(s_out, portMAX_DELAY);
}
@@@ explanation_md
**Approach.** A barrier needs a counter (how many have arrived) and a place to sleep. The **two-phase turnstile** barrier (Downey, *The Little Book of Semaphores*) uses a mutex for the counter and two counting semaphores:

1. **Phase 1.** Each task increments the counter. The `n`-th one gives `in` `n` times, one token per task including itself. Then every task takes one `in` token.
2. **Phase 2.** Each task decrements the counter. The task that brings it back to 0 gives `out` `n` times. Then every task takes one `out` token.

A task can pass phase 2 only after **all** tasks have consumed their phase-1 token. So when a fast task returns for the next round, nobody is still waiting for an old token, and the `in` semaphore is empty again. The counter is back to 0, ready for the next round.

The naive single-phase barrier fails exactly as in Example 2. The last arriver H has the highest priority: it gives the semaphore twice, M and L become *ready* but do not run, H does 1 tick of work, comes back, increments the counter and **takes a token that is still sitting in the semaphore**. H passes round 2 alone and M or L sleeps forever.

**Complexity.** Per task and round: two mutex sections, two takes; the last task of each phase does `n` gives, so O(n) for one task and O(1) for the others. Release latency: zero ticks after the last arrival; the order of release follows priority. RAM: one mutex, two counting semaphores, one `int`.

**Common mistakes**
- Single-phase barrier with "give `n-1` times": token stealing by a fast, high-priority task (Example 2).
- Resetting the counter to 0 in the last arriver and reusing one semaphore: same stealing problem.
- Giving the turnstile while not holding the mutex and then re-reading `count` outside the lock: two tasks can both see `count == n`.
- Busy-waiting on `count` with `vTaskDelay(1)`: wastes CPU, adds latency, and is not a barrier.
- A binary semaphore as turnstile: `n` gives collapse into one, so only one task is released.

**Interview follow-ups**
- How does `xEventGroupSync()` implement the same thing atomically, and what are its limits (number of bits, reuse)?
- How would you add a timeout to `barrier_wait()` and leave the barrier in a consistent state?
- Could you build it with task notifications (one notification per task)?
- In a multicore (SMP) FreeRTOS build, what else changes?
