@@@ meta
id: REV-H-01
topic: Event Groups & Notifications
difficulty: Hard
type: FUNCTION
title: Start-Up Sequencer Driven by an Event-Bit Dependency Graph
tags: freertos, event-groups, xeventgroupwaitbits, dependency-graph, startup, failure-propagation, embedded, asked-in-automotive
@@@ statement_md
An automotive ECU starts up to 8 software modules (NVM, CAN, DIAG, COM, ...). Each module may only be initialised **after all the modules it depends on are ready**. If a dependency fails, the module must not be initialised at all: it is **skipped**, and that counts as a failure for the modules that depend on it in turn. A supervisor reports when start-up is over, or gives up after a timeout (for example on a circular dependency).

Implement the sequencer with **one event group** and one task per module.

```c
typedef struct {
    const char *name;
    UBaseType_t priority;   /* 1..5 */
    uint32_t    deps;       /* bit j set = this module depends on module j */
} ModuleCfg;

int  module_init(int idx);              /* provided: logs "init start", blocks for the module's init
                                           time, logs "ready" or "FAILED", returns 1 / 0            */
void module_skip(int idx);              /* provided: logs "skipped (dependency failed)"           */
void startup_complete(void);            /* provided: logs "start-up complete"                     */
void startup_timeout(uint32_t pending); /* provided: logs "start-up timeout, pending 0x.."         */

void app_start(const ModuleCfg *cfg, int n, TickType_t timeout);   /* you write */
```

**Module task `i`** (priority `cfg[i].priority`):
- As soon as **any** dependency has failed or been skipped: call `module_skip(i)`.
- Otherwise, as soon as **all** dependencies are ready: call `module_init(i)`. A module without dependencies starts at t=0.
- Then publish the outcome (ready, or failed/skipped) in the event group so dependents and the supervisor see it, and delete the task.
- "As soon as" is checked: the provided functions print `ERROR: ... late` if a start or skip happens after the tick at which it became possible, and `ERROR: ...` if it happens too early.

The task must **block** on the event group while it waits. A simple wait-any on "the bits I am still missing, or any failure bit of my dependencies", re-evaluated after each wake-up, does it. A wait-all cannot express "all ready OR any failed". With 32-bit ticks an event group has 24 usable bits: for example ready = bit `i`, failed = bit `8+i`, done = bit `16+i`.

**Supervisor task** (priority 6): waits until **every** module is done (ready, failed or skipped), for at most `timeout` ticks from t=0. Then it calls `startup_complete()` or `startup_timeout(pending)`, with `pending` = mask of the modules that are not done. Then it deletes itself.

Queues, semaphores and task notifications are disabled in this exercise.

**How it is tested.** The hidden `main()` reads the graph, calls `app_start()` and runs the scheduler up to and including tick `D`. Module tasks may share a priority. So that the trace does not depend on the order in which equal-priority tasks run, the provided functions **buffer** their lines, and the harness prints them sorted by tick. Within one tick, the order is: first the init completions (`ready`/`FAILED`), then the `init start` and `skipped` lines, then the supervisor line. Inside each group, lines are sorted by module index. A final line counts `ready=.. failed=.. skipped=..`.

**Input**
```
<n> <timeout> <D>
<name> <priority> <init_ticks> <OK|FAIL> <deps>    (n lines; deps = comma-separated names, or -)
```

**Example**
```
Input:
5 100 200
NVM 3 10 OK -
CAN 4 5 OK NVM
DIAG 2 20 FAIL -
COM 5 3 OK CAN,DIAG
APP 1 4 OK CAN

Output:
[t=0] NVM init start
[t=0] DIAG init start
[t=10] NVM ready
[t=10] CAN init start
[t=15] CAN ready
[t=15] APP init start
[t=19] APP ready
[t=20] DIAG FAILED
[t=20] COM skipped (dependency failed)
[t=20] start-up complete
ready=3 failed=1 skipped=1
```
COM needs CAN and DIAG. CAN is ready at t=15, but COM must keep waiting for DIAG. When DIAG fails at t=20, COM is skipped at once. The last module is then done, so the supervisor reports at t=20.
@@@ constraints_md
- 1 <= n <= 8, module priorities in 1..5 (may repeat), supervisor priority 6.
- 1 <= init_ticks <= 1000, 1 <= timeout < D <= 10000. A module never depends on itself, but cycles are possible.
- No module event happens exactly at tick `timeout` (that tie is not tested).
- Block on the event group; no polling, no `vTaskDelay` loops.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"

typedef struct {
    const char *name;
    UBaseType_t priority;
    uint32_t    deps;
} ModuleCfg;

int  module_init(int idx);
void module_skip(int idx);
void startup_complete(void);
void startup_timeout(uint32_t pending);

static EventGroupHandle_t startup_events;
static const ModuleCfg *modules;
static int n_modules;
static TickType_t startup_budget;

static void module_task(void *pvParameters)
{
    int idx = (int)(intptr_t)pvParameters;

    /* TODO: wait for the dependencies, init or skip, publish the outcome */
    (void)idx;
    vTaskDelete(NULL);
}

static void supervisor_task(void *pvParameters)
{
    (void)pvParameters;
    /* TODO: wait for every module to be done (bounded), then report */
    vTaskDelete(NULL);
}

void app_start(const ModuleCfg *cfg, int n, TickType_t timeout)
{
    /* TODO: create the event group, the module tasks and the supervisor */
    modules = cfg;
    n_modules = n;
    startup_budget = timeout;
    (void)startup_events;
    (void)module_task;
    (void)supervisor_task;
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "event_groups.h"
#include "sim.h"

/* ModuleCfg is defined by the user code (as in the statement) */

#define MAXM 8
static char g_name[MAXM][16];
static unsigned g_ticks[MAXM];
static int g_ok[MAXM];
static uint32_t g_deps[MAXM];
static int g_n;

/* 0 = not started, 1 = initialising, 2 = ready, 3 = failed, 4 = skipped */
static int g_st[MAXM];
static TickType_t g_when[MAXM];    /* tick of ready / failed / skipped */
static int g_sup_reports;

typedef struct { unsigned tick; int group; int idx; unsigned seq; char text[80]; } Line;
static Line g_lines[64];
static unsigned g_nlines;

static void logline(int group, int idx, const char *text)
{
    if (g_nlines < 64) {
        Line *l = &g_lines[g_nlines];
        l->tick = (unsigned)xTaskGetTickCount();
        l->group = group;
        l->idx = idx;
        l->seq = g_nlines;
        snprintf(l->text, sizeof l->text, "%s", text);
        g_nlines++;
    }
}

static void error_line(int idx, const char *what)
{
    char buf[80];
    snprintf(buf, sizeof buf, "ERROR: %s %s", g_name[idx], what);
    logline(1, idx, buf);
}

static int bad_idx(int idx)
{
    if (idx < 0 || idx >= g_n) {
        printf("ERROR: module index %d out of range\n", idx);
        return 1;
    }
    if (g_st[idx] != 0) {
        error_line(idx, "handled twice");
        return 1;
    }
    return 0;
}

int module_init(int idx)
{
    TickType_t now = xTaskGetTickCount(), possible = 0;
    char buf[80];
    int j;

    if (bad_idx(idx)) return 0;
    for (j = 0; j < g_n; j++)
        if (g_deps[idx] & (1u << j)) {
            if (g_st[j] != 2) {
                snprintf(buf, sizeof buf, "started before %s was ready", g_name[j]);
                error_line(idx, buf);
            } else if (g_when[j] > possible) possible = g_when[j];
        }
    if (now > possible) error_line(idx, "started late");
    snprintf(buf, sizeof buf, "%s init start", g_name[idx]);
    logline(1, idx, buf);
    g_st[idx] = 1;

    vTaskDelay((TickType_t)g_ticks[idx]);

    g_when[idx] = xTaskGetTickCount();
    g_st[idx] = g_ok[idx] ? 2 : 3;
    snprintf(buf, sizeof buf, "%s %s", g_name[idx], g_ok[idx] ? "ready" : "FAILED");
    logline(0, idx, buf);
    return g_ok[idx];
}

void module_skip(int idx)
{
    TickType_t now = xTaskGetTickCount(), first = portMAX_DELAY;
    char buf[80];
    int j;

    if (bad_idx(idx)) return;
    for (j = 0; j < g_n; j++)
        if ((g_deps[idx] & (1u << j)) && g_st[j] >= 3 && g_when[j] < first) first = g_when[j];
    if (first == portMAX_DELAY) error_line(idx, "skipped although no dependency failed");
    else if (now > first) error_line(idx, "skipped late");
    snprintf(buf, sizeof buf, "%s skipped (dependency failed)", g_name[idx]);
    logline(1, idx, buf);
    g_st[idx] = 4;
    g_when[idx] = now;
}

void startup_complete(void)
{
    int j;

    logline(2, 0, "start-up complete");
    g_sup_reports++;
    for (j = 0; j < g_n; j++)
        if (g_st[j] < 2) error_line(j, "is not done at start-up complete");
}

void startup_timeout(uint32_t pending)
{
    char buf[80];
    uint32_t expect = 0;
    int j;

    for (j = 0; j < g_n; j++)
        if (g_st[j] < 2) expect |= 1u << j;
    snprintf(buf, sizeof buf, "start-up timeout, pending 0x%02x", (unsigned)pending);
    logline(2, 0, buf);
    g_sup_reports++;
    if (pending != expect) {
        snprintf(buf, sizeof buf, "ERROR: pending should be 0x%02x", (unsigned)expect);
        logline(2, 1, buf);
    }
}

/* this exercise is about event groups */
#define xQueueGenericCreate(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueGenericCreateStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateCountingSemaphore(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateCountingSemaphoreStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateMutex(...) queues_semaphores_are_disabled_in_this_exercise
#define xQueueCreateMutexStatic(...) queues_semaphores_are_disabled_in_this_exercise
#define xTaskGenericNotify(...) notifications_are_disabled_in_this_exercise
#define xTaskGenericNotifyWait(...) notifications_are_disabled_in_this_exercise
#define ulTaskGenericNotifyTake(...) notifications_are_disabled_in_this_exercise

/*USER_CODE*/

#undef xQueueGenericCreate
#undef xQueueGenericCreateStatic
#undef xQueueCreateCountingSemaphore
#undef xQueueCreateCountingSemaphoreStatic
#undef xQueueCreateMutex
#undef xQueueCreateMutexStatic
#undef xTaskGenericNotify
#undef xTaskGenericNotifyWait
#undef ulTaskGenericNotifyTake

static int cmp_line(const void *a, const void *b)
{
    const Line *x = (const Line *)a, *y = (const Line *)b;

    if (x->tick != y->tick) return x->tick < y->tick ? -1 : 1;
    if (x->group != y->group) return x->group < y->group ? -1 : 1;
    if (x->idx != y->idx) return x->idx < y->idx ? -1 : 1;
    if (x->seq != y->seq) return x->seq < y->seq ? -1 : 1;
    return 0;
}

int main(void)
{
    static ModuleCfg cfg[MAXM];
    static char deps[MAXM][160];
    unsigned timeout, dur, prio;
    char st[8];
    int i, j, nr = 0, nf = 0, ns = 0;

    if (scanf("%d %u %u", &g_n, &timeout, &dur) != 3 || g_n < 1 || g_n > MAXM) return 1;
    for (i = 0; i < g_n; i++) {
        if (scanf("%15s %u %u %7s %159s", g_name[i], &prio, &g_ticks[i], st, deps[i]) != 5) return 1;
        g_ok[i] = (st[0] == 'O');
        cfg[i].name = g_name[i];
        cfg[i].priority = (UBaseType_t)prio;
    }
    for (i = 0; i < g_n; i++) {
        char *p = deps[i];
        while (*p && strcmp(p, "-") != 0) {
            char *comma = strchr(p, ',');
            if (comma) *comma = '\0';
            for (j = 0; j < g_n && strcmp(p, g_name[j]) != 0; j++) {}
            if (j == g_n) return 1;
            g_deps[i] |= 1u << j;
            if (!comma) break;
            p = comma + 1;
        }
        cfg[i].deps = g_deps[i];
    }

    app_start(cfg, g_n, (TickType_t)timeout);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    qsort(g_lines, g_nlines, sizeof g_lines[0], cmp_line);
    for (i = 0; i < (int)g_nlines; i++) printf("[t=%u] %s\n", g_lines[i].tick, g_lines[i].text);
    for (i = 0; i < g_n; i++) {
        if (g_st[i] == 2) nr++;
        else if (g_st[i] == 3) nf++;
        else if (g_st[i] == 4) ns++;
    }
    if (g_sup_reports != 1) printf("ERROR: the supervisor reported %d times\n", g_sup_reports);
    printf("ready=%d failed=%d skipped=%d\n", nr, nf, ns);
    return 0;
}
@@@ sample_input
5 100 200
NVM 3 10 OK -
CAN 4 5 OK NVM
DIAG 2 20 FAIL -
COM 5 3 OK CAN,DIAG
APP 1 4 OK CAN
@@@ sample_output
[t=0] NVM init start
[t=0] DIAG init start
[t=10] NVM ready
[t=10] CAN init start
[t=15] CAN ready
[t=15] APP init start
[t=19] APP ready
[t=20] DIAG FAILED
[t=20] COM skipped (dependency failed)
[t=20] start-up complete
ready=3 failed=1 skipped=1
@@@ sample_input
3 50 100
A 2 5 OK B
B 2 5 OK A
C 1 7 OK -
@@@ sample_output
[t=0] C init start
[t=7] C ready
[t=50] start-up timeout, pending 0x03
ready=1 failed=0 skipped=0
@@@ hidden_input
1 10 20
SOLO 1 3 OK -
@@@ hidden_output
[t=0] SOLO init start
[t=3] SOLO ready
[t=3] start-up complete
ready=1 failed=0 skipped=0
@@@ hidden_input
5 500 600
M0 1 10 FAIL -
M1 5 10 OK M0
M2 4 10 OK M1
M3 3 10 OK M2
M4 2 10 OK M3
@@@ hidden_output
[t=0] M0 init start
[t=10] M0 FAILED
[t=10] M1 skipped (dependency failed)
[t=10] M2 skipped (dependency failed)
[t=10] M3 skipped (dependency failed)
[t=10] M4 skipped (dependency failed)
[t=10] start-up complete
ready=0 failed=1 skipped=4
@@@ hidden_input
8 1000 2000
BSW 3 20 OK -
NVM 2 30 OK BSW
CAN 2 15 OK BSW
LIN 2 15 OK BSW
DIAG 1 40 OK NVM,CAN
COM 3 10 OK CAN,LIN
APP 4 25 OK DIAG,COM
HMI 5 5 OK APP
@@@ hidden_output
[t=0] BSW init start
[t=20] BSW ready
[t=20] NVM init start
[t=20] CAN init start
[t=20] LIN init start
[t=35] CAN ready
[t=35] LIN ready
[t=35] COM init start
[t=45] COM ready
[t=50] NVM ready
[t=50] DIAG init start
[t=90] DIAG ready
[t=90] APP init start
[t=115] APP ready
[t=115] HMI init start
[t=120] HMI ready
[t=120] start-up complete
ready=8 failed=0 skipped=0

@@@ hidden_input
4 300 400
A 1 100 OK -
B 1 50 FAIL -
C 2 10 OK A,B
D 3 10 OK A
@@@ hidden_output
[t=0] A init start
[t=0] B init start
[t=50] B FAILED
[t=50] C skipped (dependency failed)
[t=100] A ready
[t=100] D init start
[t=110] D ready
[t=110] start-up complete
ready=2 failed=1 skipped=1
@@@ hidden_input
6 110 300
P 5 30 OK -
Q 5 30 OK P
R 5 30 OK Q
S 5 30 OK R
T 4 1 OK -
U 4 5 OK T,S
@@@ hidden_output
[t=0] P init start
[t=0] T init start
[t=1] T ready
[t=30] P ready
[t=30] Q init start
[t=60] Q ready
[t=60] R init start
[t=90] R ready
[t=90] S init start
[t=110] start-up timeout, pending 0x28
[t=120] S ready
[t=120] U init start
[t=125] U ready
ready=6 failed=0 skipped=0

@@@ hidden_input
4 200 300
X 2 10 OK -
Y 2 10 FAIL X
Z 3 10 OK X
W 4 10 OK Y,Z
@@@ hidden_output
[t=0] X init start
[t=10] X ready
[t=10] Y init start
[t=10] Z init start
[t=20] Y FAILED
[t=20] Z ready
[t=20] W skipped (dependency failed)
[t=20] start-up complete
ready=2 failed=1 skipped=1

@@@ hint
Per module: `need = deps` (ready bits), `fail = deps << 8` (failed bits). Loop: read the bits; if `bits & fail` -> skip; else if `(bits & need) == need` -> init; else block with `xEventGroupWaitBits(eg, (need & ~bits) | fail, pdFALSE, pdFALSE, portMAX_DELAY)` (wait-any, **no** clear) and loop. Waiting on bits that are already set returns at once, so always wait only on the **missing** ones.
@@@ hint
Publish in **one** call: `xEventGroupSetBits(eg, (ok ? READY(i) : FAILED(i)) | DONE(i))`. The supervisor waits with `xEventGroupWaitBits(eg, all_done, pdFALSE, pdTRUE, timeout)`; pending = `((bits >> 16) ^ all) & all`. Never clear bits on exit here: many tasks read the same bits.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"

typedef struct {
    const char *name;
    UBaseType_t priority;
    uint32_t    deps;
} ModuleCfg;

int  module_init(int idx);
void module_skip(int idx);
void startup_complete(void);
void startup_timeout(uint32_t pending);

#define READY_BITS(m)   ((EventBits_t)(m))                /* bits 0..7   */
#define FAILED_BITS(m)  ((EventBits_t)(m) << 8)           /* bits 8..15  */
#define DONE_BITS(m)    ((EventBits_t)(m) << 16)          /* bits 16..23 */

static EventGroupHandle_t startup_events;
static const ModuleCfg *modules;
static int n_modules;
static TickType_t startup_budget;

static void module_task(void *pvParameters)
{
    int idx = (int)(intptr_t)pvParameters;
    EventBits_t need = READY_BITS(modules[idx].deps);
    EventBits_t fail = FAILED_BITS(modules[idx].deps);
    EventBits_t me = (EventBits_t)1 << idx;
    int ok;

    for (;;) {
        EventBits_t bits = xEventGroupGetBits(startup_events);

        if (bits & fail) {                      /* any dependency failed/skipped */
            module_skip(idx);
            ok = 0;
            break;
        }
        if ((bits & need) == need) {            /* all dependencies ready */
            ok = module_init(idx);
            break;
        }
        /* block until one of the MISSING ready bits or any failure bit is set */
        (void)xEventGroupWaitBits(startup_events, (need & ~bits) | fail,
                                  pdFALSE, pdFALSE, portMAX_DELAY);
    }
    xEventGroupSetBits(startup_events, (ok ? READY_BITS(me) : FAILED_BITS(me)) | DONE_BITS(me));
    vTaskDelete(NULL);
}

static void supervisor_task(void *pvParameters)
{
    uint32_t all = ((uint32_t)1 << n_modules) - 1u;
    EventBits_t bits;
    uint32_t done;

    (void)pvParameters;
    bits = xEventGroupWaitBits(startup_events, DONE_BITS(all), pdFALSE, pdTRUE, startup_budget);
    done = (uint32_t)(bits >> 16) & all;
    if (done == all)
        startup_complete();
    else
        startup_timeout(all & ~done);
    vTaskDelete(NULL);
}

void app_start(const ModuleCfg *cfg, int n, TickType_t timeout)
{
    int i;

    modules = cfg;
    n_modules = n;
    startup_budget = timeout;
    startup_events = xEventGroupCreate();
    for (i = 0; i < n; i++)
        xTaskCreate(module_task, cfg[i].name, configMINIMAL_STACK_SIZE,
                    (void *)(intptr_t)i, cfg[i].priority, NULL);
    xTaskCreate(supervisor_task, "sup", configMINIMAL_STACK_SIZE, NULL, 6, NULL);
}
@@@ explanation_md
**Approach.** Each module owns three bits: READY (`i`), FAILED (`8+i`, also used for "skipped") and DONE (`16+i`). A module's start condition is "all READY bits of my deps" **or** "any FAILED bit of my deps". No single `xEventGroupWaitBits()` call expresses that mix of AND and OR, so the module loops:

1. read the bits (`xEventGroupGetBits`);
2. if a failure bit is set, skip; if all ready bits are set, init;
3. otherwise block with a **wait-any** on `(missing ready bits) | (failure bits)`, then go back to 1.

Waiting only on the *missing* bits is what makes this block instead of spin: a wait-any on bits that are already set returns at once. There is no lost-wake-up race between step 1 and step 3, because the wait checks the bits again atomically before blocking. The outcome is published with one `xEventGroupSetBits(READY|DONE or FAILED|DONE)`, so a skip propagates through the whole chain in zero time (hidden test: one failure skips four modules at the same tick).

The supervisor uses the opposite primitive: a **wait-all** on the DONE bits with a timeout. A circular dependency never sets those bits, so the timeout reports exactly the stuck modules (sample 2). No task ever uses clear-on-exit: the bits are shared facts that many tasks read.

**Complexity.** Each module wakes at most once per dependency event: O(deps) wake-ups, each O(1) plus the kernel's O(waiters) scan in `xEventGroupSetBits()`. Total O(n + edges) wake-ups, and O(n x waiters) kernel work in the worst case. RAM: one event group for up to 8 modules (24 bits), one short-lived task each. Start-up latency equals the critical path of init times, with zero added delay per edge.

**Common mistakes**
- Wait-all on the dependencies' ready bits: a failed dependency leaves the module (and the supervisor) blocked until the timeout.
- Wait-any on *all* ready bits (not only the missing ones) inside the loop: it returns immediately forever, time stops, and the test hits the time limit.
- `xClearOnExit = pdTRUE`: the first dependent erases a READY bit the other dependents still need.
- Two separate `SetBits` calls (READY then DONE): the supervisor can see an inconsistent state between them, and every dependent wakes twice.
- Polling with `vTaskDelay(1)`: starts become late (`ERROR ... late`) and waste CPU.
- Forgetting that a skipped module must publish a failure as well, or its dependents wait forever.

**Interview follow-ups**
- How would you detect the cycle statically at build time instead of by timeout?
- More than 8 modules: what are the options once 24 bits are not enough (several event groups, a counter of outstanding dependencies per module plus notifications)?
- How would you run independent init steps in parallel on the CPU rather than in "blocked" time, and what changes with priorities then?
- Why can the ISR side of such a design not set bits directly, and what does `xEventGroupSetBitsFromISR()` cost?
