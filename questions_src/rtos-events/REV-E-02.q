@@@ meta
id: REV-E-02
topic: Event Groups & Notifications
difficulty: Easy
type: FUNCTION
title: System Start-Up Gate: Wait for All Init Bits of an Event Group
tags: freertos, event-groups, xeventgroupwaitbits, startup, timeout, embedded, asked-in-automotive
@@@ statement_md
At power-up, an ECU must not start its control application before **every** driver (CAN, ADC, NVM, ...) has finished initialising. Each driver initialises in its own task, at its own speed. Build the start-up gate with an **event group**: one bit per driver, and the application task waits for **all** bits, with a timeout.

```c
typedef struct {
    const char *name;
    UBaseType_t priority;
} InitCfg;

int  init_module(int idx);               /* provided: initialises driver idx. Blocks for its
                                            init time, prints "[t=<tick>] <name> ready" or
                                            "[t=<tick>] <name> init FAILED", returns 1 / 0  */
void system_up(EventBits_t bits);        /* provided: prints "[t=<tick>] system up (bits=0x..)" */
void startup_timeout(EventBits_t missing); /* provided: prints "[t=<tick>] start-up timeout, missing 0x.." */

void app_start(const InitCfg *cfg, int n, UBaseType_t app_priority, TickType_t timeout); /* you write */
```

`app_start()` is called before the scheduler starts. It must create:
- **one event group**;
- **one init task per driver** `i` (priority `cfg[i].priority`). The task calls `init_module(i)`. If that returns 1, the task sets bit `(1 << i)` in the event group. Either way, the task then deletes itself (`vTaskDelete(NULL)`). A failed driver never sets its bit.
- **one application task** (priority `app_priority`). It waits until **all** `n` bits are set, but at most `timeout` ticks from the start. Then:
  - if all bits are set, it calls `system_up(bits)` with the value returned by the wait;
  - otherwise it calls `startup_timeout(missing)`, where `missing` = the bits that are still **not** set.

  Then the application task deletes itself.

`cfg` stays valid for the whole run. Queues, semaphores and task notifications are disabled in this exercise.

**How it is tested.** The hidden `main()` reads the scenario, calls `app_start()` and runs the scheduler up to and including tick `D`. Every task starts at t=0. When several tasks become ready at the same tick, the one with the **higher priority runs first** (all priorities are distinct). The provided functions check that `system_up()` is only called when every driver really is ready, and print `ERROR: ...` otherwise.

**Input**
```
<n> <app_priority> <timeout> <D>
<name> <priority> <init_ticks> <OK|FAIL>      (n lines, driver 0 first)
```

**Example 1**
```
Input:
3 5 100 150
CAN 3 10 OK
ADC 2 25 OK
NVM 4 40 OK

Output:
[t=10] CAN ready
[t=25] ADC ready
[t=40] NVM ready
[t=40] system up (bits=0x07)
```
NVM sets the last bit at t=40. The application task (priority 5) is unblocked and preempts NVM's init task at once, so `system up` is printed at t=40.

**Example 2**
```
Input:
2 3 50 100
ETH 2 5 FAIL
SPI 1 8 OK

Output:
[t=5] ETH init FAILED
[t=8] SPI ready
[t=50] start-up timeout, missing 0x01
```
@@@ constraints_md
- 1 <= n <= 5, 1 <= init_ticks <= 1000, 1 <= timeout <= 5000, timeout < D <= 10000.
- All n + 1 priorities are distinct and in 1..6.
- No driver finishes exactly at tick `timeout` (that tie is not tested).
- Use one event group and `xEventGroupWaitBits()`; no polling loop.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"

typedef struct {
    const char *name;
    UBaseType_t priority;
} InitCfg;

int  init_module(int idx);
void system_up(EventBits_t bits);
void startup_timeout(EventBits_t missing);

static void init_task(void *pvParameters)
{
    /* TODO: init the driver, set its bit on success, delete yourself */
    (void)pvParameters;
    vTaskDelete(NULL);
}

static void app_task(void *pvParameters)
{
    /* TODO: wait for all init bits (with timeout), then report */
    (void)pvParameters;
    vTaskDelete(NULL);
}

void app_start(const InitCfg *cfg, int n, UBaseType_t app_priority, TickType_t timeout)
{
    /* TODO */
    (void)cfg; (void)n; (void)app_priority; (void)timeout;
    (void)init_task; (void)app_task;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "event_groups.h"
#include "sim.h"

/* InitCfg is defined by the user code (as in the statement) */

static char g_names[5][16];
static unsigned g_ticks[5];
static int g_ok[5];
static int g_n;
static unsigned g_ready;   /* drivers that really finished OK */
static unsigned g_called;  /* init_module() already called for idx */
static int g_reported;

int init_module(int idx)
{
    if (idx < 0 || idx >= g_n) {
        printf("ERROR: init_module(%d) out of range\n", idx);
        return 0;
    }
    if (g_called & (1u << idx)) {
        printf("ERROR: %s initialised twice\n", g_names[idx]);
        return 0;
    }
    g_called |= 1u << idx;
    vTaskDelay((TickType_t)g_ticks[idx]);
    if (g_ok[idx]) {
        printf("[t=%u] %s ready\n", (unsigned)xTaskGetTickCount(), g_names[idx]);
        g_ready |= 1u << idx;
        return 1;
    }
    printf("[t=%u] %s init FAILED\n", (unsigned)xTaskGetTickCount(), g_names[idx]);
    return 0;
}

void system_up(EventBits_t bits)
{
    unsigned all = (1u << g_n) - 1u;
    int i;

    printf("[t=%u] system up (bits=0x%02x)\n", (unsigned)xTaskGetTickCount(), (unsigned)bits);
    g_reported++;
    for (i = 0; i < g_n; i++)
        if (!(g_ready & (1u << i))) printf("ERROR: system up before %s is ready\n", g_names[i]);
    if (((unsigned)bits & all) != all) printf("ERROR: bits passed to system_up() are incomplete\n");
}

void startup_timeout(EventBits_t missing)
{
    unsigned all = (1u << g_n) - 1u;

    printf("[t=%u] start-up timeout, missing 0x%02x\n", (unsigned)xTaskGetTickCount(), (unsigned)missing);
    g_reported++;
    if (((unsigned)missing & all) != (all & ~g_ready)) printf("ERROR: wrong missing mask\n");
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

int main(void)
{
    static InitCfg cfg[5];
    unsigned app_prio, timeout, dur, prio;
    char st[8];
    int i;

    if (scanf("%d %u %u %u", &g_n, &app_prio, &timeout, &dur) != 4 || g_n < 1 || g_n > 5) return 1;
    for (i = 0; i < g_n; i++) {
        if (scanf("%15s %u %u %7s", g_names[i], &prio, &g_ticks[i], st) != 4) return 1;
        g_ok[i] = (st[0] == 'O');
        cfg[i].name = g_names[i];
        cfg[i].priority = (UBaseType_t)prio;
    }

    app_start(cfg, g_n, (UBaseType_t)app_prio, (TickType_t)timeout);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    if (g_reported != 1) printf("ERROR: the application reported %d times (expected once)\n", g_reported);
    return 0;
}
@@@ sample_input
3 5 100 150
CAN 3 10 OK
ADC 2 25 OK
NVM 4 40 OK
@@@ sample_output
[t=10] CAN ready
[t=25] ADC ready
[t=40] NVM ready
[t=40] system up (bits=0x07)
@@@ sample_input
2 3 50 100
ETH 2 5 FAIL
SPI 1 8 OK
@@@ sample_output
[t=5] ETH init FAILED
[t=8] SPI ready
[t=50] start-up timeout, missing 0x01
@@@ hidden_input
1 2 10 20
CAN 1 1 OK
@@@ hidden_output
[t=1] CAN ready
[t=1] system up (bits=0x01)
@@@ hidden_input
3 1 200 300
CAN 4 30 OK
LIN 2 30 OK
ADC 6 30 OK
@@@ hidden_output
[t=30] ADC ready
[t=30] CAN ready
[t=30] LIN ready
[t=30] system up (bits=0x07)
@@@ hidden_input
4 6 60 100
CAN 2 70 OK
LIN 3 10 OK
ADC 4 61 OK
NVM 5 20 OK
@@@ hidden_output
[t=10] LIN ready
[t=20] NVM ready
[t=60] start-up timeout, missing 0x05
[t=61] ADC ready
[t=70] CAN ready
@@@ hidden_input
5 3 1000 2000
D0 1 900 OK
D1 2 100 OK
D2 4 999 OK
D3 5 500 OK
D4 6 5 OK
@@@ hidden_output
[t=5] D4 ready
[t=100] D1 ready
[t=500] D3 ready
[t=900] D0 ready
[t=999] D2 ready
[t=999] system up (bits=0x1f)
@@@ hidden_input
3 4 40 60
CAN 1 10 FAIL
LIN 2 20 FAIL
ADC 3 30 FAIL
@@@ hidden_output
[t=10] CAN init FAILED
[t=20] LIN init FAILED
[t=30] ADC init FAILED
[t=40] start-up timeout, missing 0x07
@@@ hidden_input
2 5 5 50
CAN 1 30 OK
NVM 2 40 OK
@@@ hidden_output
[t=5] start-up timeout, missing 0x03
[t=30] CAN ready
[t=40] NVM ready
@@@ hidden_input
2 2 500 600
CAN 3 50 OK
NVM 1 50 OK
@@@ hidden_output
[t=50] CAN ready
[t=50] NVM ready
[t=50] system up (bits=0x03)
@@@ hint
Create the event group with `xEventGroupCreate()` before creating the tasks, and store its handle in a `static` variable. Pass each init task its index through `pvParameters` (for example `(void *)(intptr_t)i`).
@@@ hint
`EventBits_t b = xEventGroupWaitBits(eg, all, pdFALSE, pdTRUE, timeout);` waits for **all** bits (`xWaitForAllBits = pdTRUE`). On return, `(b & all) == all` means success. Otherwise it timed out, and `all & ~b` is the missing set.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"

typedef struct {
    const char *name;
    UBaseType_t priority;
} InitCfg;

int  init_module(int idx);
void system_up(EventBits_t bits);
void startup_timeout(EventBits_t missing);

static EventGroupHandle_t init_events;
static EventBits_t all_bits;
static TickType_t startup_timeout_ticks;

static void init_task(void *pvParameters)
{
    int idx = (int)(intptr_t)pvParameters;

    if (init_module(idx))
        xEventGroupSetBits(init_events, (EventBits_t)1 << idx);
    vTaskDelete(NULL);           /* a one-shot task must not return */
}

static void app_task(void *pvParameters)
{
    EventBits_t bits;

    (void)pvParameters;
    /* no clear-on-exit, wait for ALL bits, bounded by the start-up budget */
    bits = xEventGroupWaitBits(init_events, all_bits, pdFALSE, pdTRUE, startup_timeout_ticks);
    if ((bits & all_bits) == all_bits)
        system_up(bits);
    else
        startup_timeout(all_bits & ~bits);
    vTaskDelete(NULL);
}

void app_start(const InitCfg *cfg, int n, UBaseType_t app_priority, TickType_t timeout)
{
    int i;

    init_events = xEventGroupCreate();
    all_bits = ((EventBits_t)1 << n) - 1;
    startup_timeout_ticks = timeout;

    for (i = 0; i < n; i++)
        xTaskCreate(init_task, cfg[i].name, configMINIMAL_STACK_SIZE,
                    (void *)(intptr_t)i, cfg[i].priority, NULL);
    xTaskCreate(app_task, "app", configMINIMAL_STACK_SIZE, NULL, app_priority, NULL);
}
@@@ explanation_md
**Approach.** An event group is a set of flag bits that stay set until someone clears them. Several tasks can wait on a **combination** of bits. This is exactly what a start-up gate needs: driver `i` owns bit `i`, sets it with `xEventGroupSetBits()` when it is ready, and the application waits with

```c
xEventGroupWaitBits(eg, all, /*clear*/ pdFALSE, /*all*/ pdTRUE, timeout);
```

The return value is the bit pattern at the moment the wait ended (condition met or timeout). Comparing `(b & all) == all` tells the two cases apart, and `all & ~b` gives the drivers to blame in the error log or DTC.

Order at one tick: when the last driver sets its bit, the kernel moves the waiting application task to the ready list inside `xEventGroupSetBits()`. If the application has a higher priority, it preempts the driver task immediately. Otherwise it runs as soon as the driver task deletes itself.

**Complexity.** `xEventGroupSetBits()` walks the list of waiting tasks: O(number of waiters), here 1. Each wait is O(1). RAM: one event group (a few dozen bytes) for up to 24 flags, instead of one semaphore per driver. Worst-case start-up latency: `timeout` ticks.

**Common mistakes**
- `xWaitForAllBits = pdFALSE`: the application starts as soon as the **first** driver is ready.
- `xClearOnExit = pdTRUE` when other tasks also look at the same "ready" bits: the first waiter erases them for everyone else.
- Treating the return value as "success" without masking: on timeout, `xEventGroupWaitBits()` still returns the current bits, not 0.
- Passing `&i` (the loop counter) as the task parameter: every init task would read the final value of `i`.
- Letting an init task return instead of `vTaskDelete(NULL)`.

**Interview follow-ups**
- How many bits does an event group have with 32-bit ticks, and why not 32? (24: the top 8 bits are kernel control bits.)
- Why is `xEventGroupSetBits()` not deterministic in time, and why can it not be called directly from an ISR? (It walks a list of unknown length; the FromISR version defers to the timer task.)
- How would you report a failed driver explicitly, instead of waiting for the timeout? (A second "FAILED" bit per driver and a wait-any.)
- Event group versus one counting semaphore given N times: what does the event group tell you that the semaphore cannot?
