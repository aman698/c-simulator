@@@ meta
id: RTK-M-03
topic: Tasks & Scheduling
difficulty: Medium
type: FUNCTION
title: Task Controller: Suspend, Resume, Kill and Query State
tags: freertos, vtasksuspend, vtaskresume, vtaskdelete, etaskgetstate, task-handle, embedded
@@@ statement_md
A diagnostic shell on an ECU lets a tester **suspend**, **resume** and **kill** application tasks and **query** their state. Implement the task side and the four controller functions.

```c
/* provided by the test harness */
void worker_step(char name);              /* prints "[t=<tick>] <name>" */

void app_start(const TickType_t period[3]);   /* create workers 'A', 'B', 'C' */
int  ctl_suspend(char name);
int  ctl_resume(char name);
int  ctl_kill(char name);
const char *ctl_state(char name);
```

**Workers.** `app_start()` creates three tasks, `A`, `B` and `C`, with priorities **3, 2 and 1**. Each runs forever: `worker_step(name)`, then `vTaskDelay(period)`. The periods are `period[0..2]`.

**Controller functions.** They are called by the harness's controller task, which has priority **5**. So the target task is never running at that moment.

| function | effect | returns |
|---|---|---|
| `ctl_suspend(n)` | suspend task `n` | 1 if it was suspended now; 0 if it was already suspended or is killed |
| `ctl_resume(n)` | resume task `n` | 1 if it was suspended and is resumed now; 0 otherwise |
| `ctl_kill(n)` | delete task `n` | 1 if deleted now; 0 if already killed |
| `ctl_state(n)` | | `"Ready"`, `"Blocked"`, `"Suspended"` or `"Deleted"` |

Important FreeRTOS behaviour: a task that was suspended **while sleeping** in `vTaskDelay()` becomes **ready immediately** when it is resumed. Its sleep is over. It does not continue the remaining delay.

A killed task's handle is **dangling**: its TCB has been freed. Never pass it to a FreeRTOS function again.

**How it is tested.** The input gives the periods, a duration `D` and a list of commands. The controller executes each command at its tick and prints the result:

- `[t=<tick>] suspend A -> 1`
- `[t=<tick>] resume A -> 1`
- `[t=<tick>] kill A -> 1`
- `[t=<tick>] state A = Blocked`

After tick `D`, the harness prints how many steps each worker made.

**Input**
```
<period A> <period B> <period C> <D>
<m>
<tick> <S|R|K|Q> <A|B|C>          m lines, ticks >= 1, non-decreasing
```

**Example**
```
Input:
10 15 20 50
5
12 S A
25 Q A
30 R A
30 Q B
40 K C

Output:
[t=0] A
[t=0] B
[t=0] C
[t=10] A
[t=12] suspend A -> 1
[t=15] B
[t=20] C
[t=25] state A = Suspended
[t=30] resume A -> 1
[t=30] state B = Ready
[t=30] A
[t=30] B
[t=40] kill C -> 1
[t=40] A
[t=45] B
[t=50] A
steps: A=5 B=4 C=2
```
A is suspended at t=12, while it sleeps until t=20. It misses its step at t=20, and the resume at t=30 lets it run at once. At t=30, B's delay has just expired, so B is **Ready** (not Blocked) while the controller runs. C is killed at t=40, the very tick it would have stepped.
@@@ constraints_md
- 1 <= period <= 200, 1 <= D <= 5000, 0 <= m <= 40.
- Do not use `xTaskGetHandle()` (it searches all tasks by name). Keep your own handles.
- Stack size `configMINIMAL_STACK_SIZE`.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"

void worker_step(char name);

static TickType_t g_period[3];

static void worker_task(void *pv)
{
    /* TODO */
    (void)pv;
    for (;;) {
        vTaskDelay(1000);
    }
}

void app_start(const TickType_t period[3])
{
    int i;
    for (i = 0; i < 3; i++) g_period[i] = period[i];
    /* TODO: create A, B, C (priorities 3, 2, 1) and keep their handles */
    (void)worker_task;
}

int ctl_suspend(char name)
{
    (void)name;
    return 0;
}

int ctl_resume(char name)
{
    (void)name;
    return 0;
}

int ctl_kill(char name)
{
    (void)name;
    return 0;
}

const char *ctl_state(char name)
{
    (void)name;
    return "Ready";
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

static unsigned g_steps[3];

void worker_step(char name)
{
    printf("[t=%u] %c\n", (unsigned)xTaskGetTickCount(), name);
    g_steps[name - 'A']++;
}

#define xTaskGetHandle(n) xTaskGetHandle_is_not_allowed_here
/*USER_CODE*/
#undef xTaskGetHandle

static unsigned g_m;
static TickType_t g_tick[40];
static char g_cmd[40], g_name[40];

static void controller_task(void *pv)
{
    unsigned i;
    (void)pv;
    for (i = 0; i < g_m; i++) {
        TickType_t now = xTaskGetTickCount();
        unsigned t;
        if (g_tick[i] > now) vTaskDelay(g_tick[i] - now);
        t = (unsigned)xTaskGetTickCount();
        switch (g_cmd[i]) {
        case 'S': printf("[t=%u] suspend %c -> %d\n", t, g_name[i], ctl_suspend(g_name[i])); break;
        case 'R': printf("[t=%u] resume %c -> %d\n", t, g_name[i], ctl_resume(g_name[i])); break;
        case 'K': printf("[t=%u] kill %c -> %d\n", t, g_name[i], ctl_kill(g_name[i])); break;
        default:  printf("[t=%u] state %c = %s\n", t, g_name[i], ctl_state(g_name[i])); break;
        }
    }
    vTaskDelete(NULL);
}

int main(void)
{
    static TickType_t period[3];
    unsigned a, b, c, d, i, t;
    char cmd, name;

    if (scanf("%u %u %u %u", &a, &b, &c, &d) != 4) return 1;
    if (scanf("%u", &g_m) != 1 || g_m > 40) return 1;
    for (i = 0; i < g_m; i++) {
        if (scanf("%u %c %c", &t, &cmd, &name) != 3) return 1;
        g_tick[i] = (TickType_t)t;
        g_cmd[i] = cmd;
        g_name[i] = name;
    }
    period[0] = (TickType_t)a;
    period[1] = (TickType_t)b;
    period[2] = (TickType_t)c;

    xTaskCreate(controller_task, "ctl", configMINIMAL_STACK_SIZE, NULL, 5, NULL);
    app_start(period);
    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();
    printf("steps: A=%u B=%u C=%u\n", g_steps[0], g_steps[1], g_steps[2]);
    return 0;
}
@@@ sample_input
10 15 20 50
5
12 S A
25 Q A
30 R A
30 Q B
40 K C
@@@ sample_output
[t=0] A
[t=0] B
[t=0] C
[t=10] A
[t=12] suspend A -> 1
[t=15] B
[t=20] C
[t=25] state A = Suspended
[t=30] resume A -> 1
[t=30] state B = Ready
[t=30] A
[t=30] B
[t=40] kill C -> 1
[t=40] A
[t=45] B
[t=50] A
steps: A=5 B=4 C=2
@@@ sample_input
5 5 5 12
6
1 Q B
2 S B
2 S B
3 R C
4 K B
4 Q B
@@@ sample_output
[t=0] A
[t=0] B
[t=0] C
[t=1] state B = Blocked
[t=2] suspend B -> 1
[t=2] suspend B -> 0
[t=3] resume C -> 0
[t=4] kill B -> 1
[t=4] state B = Deleted
[t=5] A
[t=5] C
[t=10] A
[t=10] C
steps: A=3 B=1 C=3
@@@ hidden_input
100 100 100 300
0
@@@ hidden_output
[t=0] A
[t=0] B
[t=0] C
[t=100] A
[t=100] B
[t=100] C
[t=200] A
[t=200] B
[t=200] C
[t=300] A
[t=300] B
[t=300] C
steps: A=4 B=4 C=4
@@@ hidden_input
10 10 10 40
6
5 K A
6 K A
7 S A
8 R A
9 Q A
10 Q C
@@@ hidden_output
[t=0] A
[t=0] B
[t=0] C
[t=5] kill A -> 1
[t=6] kill A -> 0
[t=7] suspend A -> 0
[t=8] resume A -> 0
[t=9] state A = Deleted
[t=10] state C = Ready
[t=10] B
[t=10] C
[t=20] B
[t=20] C
[t=30] B
[t=30] C
[t=40] B
[t=40] C
steps: A=1 B=5 C=5
@@@ hidden_input
50 7 9 40
4
3 S C
3 S B
21 R B
22 R C
@@@ hidden_output
[t=0] A
[t=0] B
[t=0] C
[t=3] suspend C -> 1
[t=3] suspend B -> 1
[t=21] resume B -> 1
[t=21] B
[t=22] resume C -> 1
[t=22] C
[t=28] B
[t=31] C
[t=35] B
[t=40] C
steps: A=1 B=4 C=4
@@@ hidden_input
4 6 8 24
5
4 Q A
8 S A
8 Q A
16 R A
16 Q A
@@@ hidden_output
[t=0] A
[t=0] B
[t=0] C
[t=4] state A = Ready
[t=4] A
[t=6] B
[t=8] suspend A -> 1
[t=8] state A = Suspended
[t=8] C
[t=12] B
[t=16] resume A -> 1
[t=16] state A = Ready
[t=16] A
[t=16] C
[t=18] B
[t=20] A
[t=24] A
[t=24] B
[t=24] C
steps: A=5 B=5 C=4
@@@ hidden_input
3 200 200 15
3
1 K C
1 K B
2 S A
@@@ hidden_output
[t=0] A
[t=0] B
[t=0] C
[t=1] kill C -> 1
[t=1] kill B -> 1
[t=2] suspend A -> 1
steps: A=1 B=1 C=1
@@@ hint
Keep a `TaskHandle_t` per worker (last argument of `xTaskCreate`) and a "killed" flag. `eTaskGetState(h)` returns `eReady`, `eBlocked`, `eSuspended`, ... Use it to decide what `ctl_suspend` and `ctl_resume` should return.
@@@ hint
After `vTaskDelete(h)` from another task, the TCB is freed at once, so set your handle to `NULL` and answer `"Deleted"` from your own bookkeeping. Pass the worker's name (or index) through `pvParameters`: `(void *)(uintptr_t)i`.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"

void worker_step(char name);

static TickType_t g_period[3];
static TaskHandle_t g_task[3];          /* NULL once killed */

static void worker_task(void *pv)
{
    unsigned i = (unsigned)(uintptr_t)pv;
    for (;;) {
        worker_step((char)('A' + i));
        vTaskDelay(g_period[i]);
    }
}

void app_start(const TickType_t period[3])
{
    static const char *names[3] = { "A", "B", "C" };
    unsigned i;
    for (i = 0; i < 3; i++) {
        g_period[i] = period[i];
        xTaskCreate(worker_task, names[i], configMINIMAL_STACK_SIZE,
                    (void *)(uintptr_t)i, (UBaseType_t)(3 - i), &g_task[i]);
    }
}

static TaskHandle_t handle_of(char name)
{
    return (name >= 'A' && name <= 'C') ? g_task[name - 'A'] : NULL;
}

int ctl_suspend(char name)
{
    TaskHandle_t h = handle_of(name);
    if (h == NULL || eTaskGetState(h) == eSuspended) return 0;
    vTaskSuspend(h);
    return 1;
}

int ctl_resume(char name)
{
    TaskHandle_t h = handle_of(name);
    if (h == NULL || eTaskGetState(h) != eSuspended) return 0;
    vTaskResume(h);              /* ready at once: an interrupted vTaskDelay() is over */
    return 1;
}

int ctl_kill(char name)
{
    TaskHandle_t h = handle_of(name);
    if (h == NULL) return 0;
    vTaskDelete(h);              /* TCB freed now: the handle is dangling from here on */
    g_task[name - 'A'] = NULL;
    return 1;
}

const char *ctl_state(char name)
{
    TaskHandle_t h = handle_of(name);
    if (h == NULL) return "Deleted";
    switch (eTaskGetState(h)) {
    case eReady:     return "Ready";
    case eBlocked:   return "Blocked";
    case eSuspended: return "Suspended";
    case eRunning:   return "Running";
    default:         return "Deleted";
    }
}
@@@ explanation_md
**Approach.** The controller needs a handle per task, so `app_start()` stores the handles returned through the last argument of `xTaskCreate()`. The worker index travels through `pvParameters`.

- `vTaskSuspend(h)` moves the task from whatever list it is in (ready or delayed) to the suspended list. If it was sleeping, the remaining delay is forgotten.
- `vTaskResume(h)` moves a suspended task to the **ready** list. A task suspended during `vTaskDelay()` therefore returns from that delay at the moment of the resume. In the example, A steps at t=30 instead of waiting for a grid point. This surprises many people.
- `eTaskGetState(h)` reports the list the task is in. At a tick where a worker's delay expires, the tick interrupt has already moved it to the ready list before the controller (priority 5) runs. That is why B is `Ready` at t=30 in the example.
- `vTaskDelete(h)` on **another** task removes it from all lists and frees its TCB and stack immediately. The handle must never be used again: `eTaskGetState()` on it would read freed memory. Keep your own "killed" bookkeeping (here: handle set to `NULL`).

**Complexity.** Every controller operation is O(1) (list removal and insertion; `eTaskGetState` checks a few list pointers). RAM: three handles. A killed task's memory goes back to the heap at once.

**Common mistakes**
- Calling FreeRTOS functions on the handle of a deleted task. That is a use-after-free inside the FreeRTOS heap: no sanitizer sees it, and once the memory is reused by a new task you silently suspend or query the wrong task.
- Calling `vTaskResume()` on a task that is not suspended, or reporting success for it. `vTaskResume` silently ignores it, but the diagnostic shell must report 0.
- Expecting the resumed task to finish its old delay. It is ready immediately.
- Confusing `eBlocked` with `eSuspended`. Note that a task blocked **forever** (`portMAX_DELAY`) is reported as `eSuspended` by FreeRTOS.
- Searching tasks by name with `xTaskGetHandle()` on every command. It is O(n) over all tasks and disabled in many builds.

**Interview follow-ups**
- Why is suspending a task that holds a mutex dangerous? What happens to tasks waiting for that mutex?
- `vTaskSuspendAll()` vs `vTaskSuspend()`: what is the difference?
- How would you implement "pause" so that the task finishes its current step first (cooperative suspension)?
- Where does the memory of a task deleted by another task go, compared to a task that deletes itself?
