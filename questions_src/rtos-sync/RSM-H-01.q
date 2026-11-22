@@@ meta
id: RSM-H-01
topic: Semaphores & Mutexes
difficulty: Hard
type: FUNCTION
title: Deadlock-Free Dining Philosophers With Lock Ordering and Timeouts
tags: freertos, deadlock, lock-ordering, mutex, timeout, dining-philosophers, embedded
@@@ statement_md
`n` tasks sit around a table. Between each pair of neighbours lies one fork (a **mutex**). Philosopher `i` needs forks `i` and `(i+1) % n` to eat. If every philosopher grabs his left fork first and then waits for the right one, all of them can end up holding one fork and waiting forever: a **deadlock**. In an ECU the same pattern appears when two tasks lock two shared peripherals (SPI bus + EEPROM) in different orders.

Make the table deadlock-free with two rules:
1. **Lock ordering**: always take the **lower-numbered** fork first, then the higher-numbered one.
2. **Timeouts**: never wait more than `patience` ticks for a fork. If a fork cannot be obtained in time, release what you hold and give up this meal.

```c
typedef struct {
    int         id;        /* 0..n-1 */
    UBaseType_t priority;
    TickType_t  think;     /* ticks to think before each meal attempt */
    TickType_t  eat;       /* ticks to eat */
    TickType_t  patience;  /* timeout for EACH fork */
    int         meals;     /* number of meal attempts */
} Phil;

SemaphoreHandle_t g_fork[6];   /* you define it; create g_fork[0..n-1] as mutexes */

/* provided by the hidden harness */
void fork_pause(int id);                 /* picking up a fork takes 1 tick (sleeps 1 tick) */
void phil_eat(int id, TickType_t ticks); /* checks you hold both forks, prints "[t=<tick>] P<id> eats",
                                            sleeps `ticks` */
void phil_skip(int id);                  /* prints "[t=<tick>] P<id> gives up" */

void table_start(const Phil *p, int n);  /* you write this (and the philosopher task) */
```

`table_start()` is called **before** the scheduler starts. It creates the `n` fork mutexes and one task per philosopher (priority from `p[i]`, stack `configMINIMAL_STACK_SIZE`). With `first = min(i, (i+1)%n)` and `second = max(i, (i+1)%n)`, each philosopher does `meals` times:

```
vTaskDelay(think)
take g_fork[first]  with timeout patience  -> on timeout: phil_skip(id), next attempt
fork_pause(id)
take g_fork[second] with timeout patience  -> on timeout: give g_fork[first], phil_skip(id), next attempt
fork_pause(id)
phil_eat(id, eat)
give g_fork[second], give g_fork[first]
```
and then deletes itself.

**How it is tested.** The hidden `main()` reads the philosophers and a duration `D`, calls `table_start()` and runs the scheduler up to and including tick `D`. Then it prints how many meals each philosopher ate and how often he gave up, and a verdict: `TABLE OK`, `FORK VIOLATION` (ate without holding both forks), `PROTOCOL ERROR` (did not call `fork_pause()` exactly twice before eating) or `DEADLOCK` (a philosopher did not finish by tick `D`).

Timing rules: when a fork is given back, the highest-priority philosopher waiting for it is woken and takes it; if he has a higher priority than the giver he runs at once. Philosophers that become ready at the same tick run in priority order. A take that starts at tick `t` with timeout `patience` fails at tick `t + patience`, unless a higher-priority holder gives the fork back at that very tick before the waiter runs: FreeRTOS re-checks the mutex before it reports a timeout, so the take then succeeds.

**Input**
```
<n>
<priority> <think> <eat> <patience> <meals>     (n lines, philosopher 0..n-1)
<D>
```

**Example 1**
```
Input:
3
1 1 5 20 1
2 1 5 20 1
3 1 5 20 1
100

Output:
[t=3] P2 eats
[t=9] P1 eats
[t=15] P0 eats
P0: ate 1, gave up 0
P1: ate 1, gave up 0
P2: ate 1, gave up 0
TABLE OK
```
At t=1 P2 (forks 0 then 2) takes fork 0, P1 takes fork 1, and P0 (forks 0 then 1) blocks on fork 0. At t=2 P2 takes fork 2 and P1 blocks on it. P2 eats from t=3 to t=8, then gives fork 2 (P1 wakes) and fork 0 (P0 wakes). P1 takes fork 2 and eats at t=9; P0 takes fork 0 but has to wait for fork 1 until t=14, and eats at t=15. With "left fork first", all three would hold one fork at t=1 and wait for each other.

**Example 2**
```
Input:
2
1 1 10 3 2
2 2 2 3 2
50

Output:
[t=3] P0 eats
[t=5] P1 gives up
[t=10] P1 gives up
[t=16] P0 eats
P0: ate 2, gave up 0
P1: ate 0, gave up 2
TABLE OK
```
P1 waits for fork 0 from t=2 and gives up at t=5, thinks again until t=7 and gives up at t=10, while P0 eats from t=3 to t=13.
@@@ constraints_md
- 2 <= n <= 6, priorities different and in 1..6.
- 1 <= think, eat, patience <= 100, 1 <= meals <= 5, D <= 5000 (long enough for a correct solution).
- Simulated time: 1 tick = 1 ms.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

typedef struct {
    int         id;
    UBaseType_t priority;
    TickType_t  think;
    TickType_t  eat;
    TickType_t  patience;
    int         meals;
} Phil;

SemaphoreHandle_t g_fork[6];

void fork_pause(int id);
void phil_eat(int id, TickType_t ticks);
void phil_skip(int id);

static int s_n;

static void phil_task(void *pvParameters)
{
    const Phil *p = (const Phil *)pvParameters;
    int left = p->id, right = (p->id + 1) % s_n;
    int m;

    for (m = 0; m < p->meals; m++) {
        vTaskDelay(p->think);
        /* TODO: lock ordering + timeouts (this version can deadlock) */
        xSemaphoreTake(g_fork[left], portMAX_DELAY);
        fork_pause(p->id);
        xSemaphoreTake(g_fork[right], portMAX_DELAY);
        fork_pause(p->id);
        phil_eat(p->id, p->eat);
        xSemaphoreGive(g_fork[right]);
        xSemaphoreGive(g_fork[left]);
    }
    vTaskDelete(NULL);
}

void table_start(const Phil *p, int n)
{
    int i;

    s_n = n;
    for (i = 0; i < n; i++) g_fork[i] = xSemaphoreCreateMutex();
    for (i = 0; i < n; i++) {
        xTaskCreate(phil_task, "phil", configMINIMAL_STACK_SIZE, (void *)&p[i], p[i].priority, NULL);
    }
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "sim.h"

extern SemaphoreHandle_t g_fork[6];

static int g_n;
static int g_ate[6], g_skipped[6], g_pauses[6];
static int g_violation, g_protocol;

void fork_pause(int id)
{
    if (id >= 0 && id < 6) g_pauses[id]++;
    vTaskDelay(1);
}

void phil_eat(int id, TickType_t ticks)
{
    TaskHandle_t me = xTaskGetCurrentTaskHandle();
    int l, r;

    if (id < 0 || id >= g_n) { g_violation++; return; }
    l = id;
    r = (id + 1) % g_n;
    if (xSemaphoreGetMutexHolder(g_fork[l]) != me || xSemaphoreGetMutexHolder(g_fork[r]) != me) g_violation++;
    if (g_pauses[id] != 2) g_protocol++;
    g_pauses[id] = 0;
    printf("[t=%u] P%d eats\n", (unsigned)xTaskGetTickCount(), id);
    vTaskDelay(ticks);
    g_ate[id]++;
}

void phil_skip(int id)
{
    if (id < 0 || id >= g_n) { g_violation++; return; }
    g_pauses[id] = 0;
    g_skipped[id]++;
    printf("[t=%u] P%d gives up\n", (unsigned)xTaskGetTickCount(), id);
}

/*USER_CODE*/

int main(void)
{
    static Phil phil[6];
    unsigned prio, think, eat, pat, meals, d;
    int i, stuck = 0;

    if (scanf("%d", &g_n) != 1 || g_n < 2 || g_n > 6) return 1;
    for (i = 0; i < g_n; i++) {
        if (scanf("%u %u %u %u %u", &prio, &think, &eat, &pat, &meals) != 5) return 1;
        phil[i].id = i;
        phil[i].priority = (UBaseType_t)prio;
        phil[i].think = (TickType_t)think;
        phil[i].eat = (TickType_t)eat;
        phil[i].patience = (TickType_t)pat;
        phil[i].meals = (int)meals;
    }
    if (scanf("%u", &d) != 1) return 1;

    table_start(phil, g_n);
    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();

    for (i = 0; i < g_n; i++) {
        printf("P%d: ate %d, gave up %d\n", i, g_ate[i], g_skipped[i]);
        if (g_ate[i] + g_skipped[i] != phil[i].meals) stuck++;
    }
    if (g_violation) printf("FORK VIOLATION\n");
    else if (g_protocol) printf("PROTOCOL ERROR\n");
    else if (stuck) printf("DEADLOCK\n");
    else printf("TABLE OK\n");
    return 0;
}
@@@ sample_input
3
1 1 5 20 1
2 1 5 20 1
3 1 5 20 1
100
@@@ sample_output
[t=3] P2 eats
[t=9] P1 eats
[t=15] P0 eats
P0: ate 1, gave up 0
P1: ate 1, gave up 0
P2: ate 1, gave up 0
TABLE OK
@@@ sample_input
2
1 1 10 3 2
2 2 2 3 2
50
@@@ sample_output
[t=3] P0 eats
[t=5] P1 gives up
[t=10] P1 gives up
[t=16] P0 eats
P0: ate 2, gave up 0
P1: ate 0, gave up 2
TABLE OK
@@@ hidden_input
5
1 10 4 100 2
2 10 4 100 2
3 10 4 100 2
4 10 4 100 2
5 10 4 100 2
500
@@@ hidden_output
[t=12] P4 eats
[t=17] P3 eats
[t=22] P2 eats
[t=27] P1 eats
[t=32] P0 eats
[t=33] P3 eats
[t=38] P4 eats
[t=38] P2 eats
[t=43] P1 eats
[t=48] P0 eats
P0: ate 2, gave up 0
P1: ate 2, gave up 0
P2: ate 2, gave up 0
P3: ate 2, gave up 0
P4: ate 2, gave up 0
TABLE OK

@@@ hidden_input
6
6 3 7 9 3
5 4 6 9 3
4 5 5 9 3
3 6 4 9 3
2 7 3 9 3
1 8 2 9 3
1000
@@@ hidden_output
[t=5] P0 eats
[t=7] P2 eats
[t=9] P4 eats
[t=14] P1 eats
[t=14] P3 eats
[t=14] P5 eats
[t=21] P0 eats
[t=21] P4 eats
[t=22] P2 eats
[t=29] P3 eats
[t=30] P1 eats
[t=30] P5 eats
[t=35] P4 eats
[t=37] P0 eats
[t=38] P2 eats
[t=45] P3 eats
[t=46] P1 eats
[t=46] P5 eats
P0: ate 3, gave up 0
P1: ate 3, gave up 0
P2: ate 3, gave up 0
P3: ate 3, gave up 0
P4: ate 3, gave up 0
P5: ate 3, gave up 0
TABLE OK

@@@ hidden_input
4
3 1 30 5 2
1 2 1 50 3
4 2 2 1 2
2 1 1 100 1
1000
@@@ hidden_output
[t=3] P0 eats
[t=4] P2 eats
[t=10] P2 eats
[t=35] P3 eats
[t=35] P1 eats
[t=38] P0 eats
[t=70] P1 eats
[t=75] P1 eats
P0: ate 2, gave up 0
P1: ate 3, gave up 0
P2: ate 2, gave up 0
P3: ate 1, gave up 0
TABLE OK

@@@ hidden_input
2
5 1 1 1 5
6 1 1 1 5
200
@@@ hidden_output
[t=2] P0 gives up
[t=3] P1 eats
[t=6] P1 gives up
[t=6] P0 eats
[t=9] P1 eats
[t=9] P0 gives up
[t=12] P1 gives up
[t=12] P0 eats
[t=15] P1 eats
[t=15] P0 gives up
P0: ate 2, gave up 3
P1: ate 3, gave up 2
TABLE OK

@@@ hidden_input
3
2 5 20 4 3
1 6 1 30 3
3 7 2 2 3
1000
@@@ hidden_output
[t=7] P0 eats
[t=9] P2 gives up
[t=18] P2 gives up
[t=29] P2 eats
[t=32] P1 eats
[t=34] P0 eats
[t=56] P1 eats
[t=61] P0 eats
[t=83] P1 eats
P0: ate 3, gave up 0
P1: ate 3, gave up 0
P2: ate 1, gave up 2
TABLE OK

@@@ hint
Deadlock needs a **cycle** of tasks, each holding one lock and waiting for the next. If every task takes the forks in the same global order (lowest number first), the last link of the cycle can never form: the philosopher whose two forks are `n-1` and `0` reaches for fork 0 first, like his neighbour.
@@@ hint
`if (xSemaphoreTake(g_fork[first], p->patience) != pdTRUE) { phil_skip(id); continue; }` then `fork_pause()`, then the same for `second`, but on that failure give `g_fork[first]` back **before** `phil_skip()`. Release in reverse order after eating.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

typedef struct {
    int         id;
    UBaseType_t priority;
    TickType_t  think;
    TickType_t  eat;
    TickType_t  patience;
    int         meals;
} Phil;

SemaphoreHandle_t g_fork[6];

void fork_pause(int id);
void phil_eat(int id, TickType_t ticks);
void phil_skip(int id);

static int s_n;

static void phil_task(void *pvParameters)
{
    const Phil *p = (const Phil *)pvParameters;
    int a = p->id, b = (p->id + 1) % s_n;
    int first = a < b ? a : b;        /* global lock order: lower fork number first */
    int second = a < b ? b : a;
    int m;

    for (m = 0; m < p->meals; m++) {
        vTaskDelay(p->think);
        if (xSemaphoreTake(g_fork[first], p->patience) != pdTRUE) {
            phil_skip(p->id);
            continue;
        }
        fork_pause(p->id);
        if (xSemaphoreTake(g_fork[second], p->patience) != pdTRUE) {
            xSemaphoreGive(g_fork[first]);   /* never keep a lock after a failed attempt */
            phil_skip(p->id);
            continue;
        }
        fork_pause(p->id);
        phil_eat(p->id, p->eat);
        xSemaphoreGive(g_fork[second]);
        xSemaphoreGive(g_fork[first]);
    }
    vTaskDelete(NULL);
}

void table_start(const Phil *p, int n)
{
    int i;

    s_n = n;
    for (i = 0; i < n; i++) g_fork[i] = xSemaphoreCreateMutex();
    for (i = 0; i < n; i++) {
        xTaskCreate(phil_task, "phil", configMINIMAL_STACK_SIZE, (void *)&p[i], p[i].priority, NULL);
    }
}
@@@ explanation_md
**Approach.** A deadlock needs four conditions at once (Coffman): mutual exclusion, hold-and-wait, no preemption, and a circular wait. Forks are exclusive by nature. The solution removes the last two conditions:

- **Lock ordering removes the circular wait.** With a global order (fork number) every task waits only for a fork with a higher number than any fork it holds. A cycle would need some task to wait for a lower number, which is impossible. With "left first", philosopher `n-1` holds fork `n-1` and waits for fork 0, which closes the cycle.
- **Timeouts remove the unbounded wait.** A task that cannot get a fork within `patience` releases what it holds and reports the failure. On a real ECU that turns a hang into a diagnosable error (DTC, retry, degraded mode), and it also bounds the time a task can be held up by a slow neighbour.

Ordering alone already prevents the deadlock. Timeouts alone do not: with "left first", all philosophers can time out together, retry together and fail together (livelock), which is why the two are combined.

**Complexity.** Per meal attempt O(1) work plus two mutex operations. Worst-case wait per attempt: `2 * patience` ticks. RAM: `n` mutexes and `n` tasks. With ordering, the worst-case wait chain is bounded by the length of the table, not by a cycle.

**Common mistakes**
- Taking `left` then `right` for everyone: philosopher `n-1` breaks the global order.
- Forgetting to give back the first fork when the second take times out: the fork leaks and the neighbours starve (or the next attempt deadlocks).
- Waiting with `portMAX_DELAY` and calling it "deadlock-free": it is only true with the ordering, and any later code change that breaks the ordering hangs the system silently.
- Using binary semaphores as forks: no owner and no priority inheritance, so `xSemaphoreGetMutexHolder()` cannot even tell who holds a fork.
- Releasing in the wrong task or twice: giving a mutex you do not hold asserts in FreeRTOS.

**Interview follow-ups**
- Name the four Coffman conditions and say which one each technique breaks.
- Other solutions: a waiter (counting semaphore with `n-1` seats), Chandy/Misra, an asymmetric philosopher. Trade-offs?
- How would you detect a deadlock at run time on an ECU (watchdog per task, `xSemaphoreGetMutexHolder()` graph, trace)?
- Can lock ordering still deadlock if a task also waits on a queue while holding a mutex?
