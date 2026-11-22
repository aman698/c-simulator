@@@ meta
id: RMM-E-02
topic: RTOS Memory Management
difficulty: Easy
type: FUNCTION
title: Measure A Task's Heap Footprint And Reclaim Self-Deleted Tasks
tags: freertos, heap-4, xportgetfreeheapsize, vtaskdelete, idle-task, embedded
@@@ statement_md
During a memory review you are asked two things: *"how many bytes of FreeRTOS heap does one task really cost?"* and *"do short-lived worker tasks give all their memory back?"*. Write two helper functions that answer them with `xPortGetFreeHeapSize()`.

```c
#define WORKER_PRIO 4

void worker_done(void);                                 /* provided: a worker calls it once */

size_t task_footprint(configSTACK_DEPTH_TYPE words);    /* you write these two */
void   spawn_and_reclaim(unsigned n);
```

Both are called from the harness's test task, which runs at **priority 3**.

**`task_footprint(words)`** creates one probe task with `xTaskCreate()` (stack depth `words`, priority **1**, so it never gets the CPU while the test task is busy). It measures how much the free heap dropped, deletes the probe with `vTaskDelete(handle)` and returns the drop in bytes. When it returns, the heap must be **exactly** as before the call.

**`spawn_and_reclaim(n)`** creates `n` one-shot workers with `xTaskCreate()` (stack `configMINIMAL_STACK_SIZE`, priority `WORKER_PRIO`). Each worker calls `worker_done()` once and then deletes **itself** with `vTaskDelete(NULL)`. The function may return only when all `n` workers have run **and** all their memory is back in the heap.

Background: a task that deletes another task has its TCB and stack freed at once. A task that deletes **itself** cannot free the stack it is running on: it is put on a termination list, and the **idle task** frees it later. The idle task runs only when every higher-priority task is blocked.

**How it is tested.** The hidden test task executes a list of commands:

- `F <words>`: calls `task_footprint(words)`. It compares your result with the drop it measures itself for an identical `xTaskCreate()` call, and checks that the heap is restored. It prints `footprint(<words>): ok` or `WRONG`, then `heap restored` or `LEAK`. From the second `F` on, it also prints the difference to the **first** `F` result, as `diff vs footprint(<w0>): <signed bytes>`.
- `R <n>`: calls `spawn_and_reclaim(n)` and prints how many workers ran and the heap delta over the call (0 if everything was reclaimed).

The heap delta of a task is its TCB plus its stack, each with heap_4's 16-byte block header and rounded up to 16 bytes. You do not need these numbers: you measure them. Here, `StackType_t` is 8 bytes, so 128 extra stack words cost exactly 1024 extra bytes.

**Input**
```
<count>
<command>      (count lines: "F <words>" or "R <n>")
```

**Example**
```
Input:
3
F 128
F 256
R 2

Output:
footprint(128): ok, heap restored
footprint(256): ok, heap restored, diff vs footprint(128): +1024
reclaim(2): workers ran=2 heap delta=0
```
@@@ constraints_md
- 1 <= count <= 10. For `F`: 64 <= words <= 4096. For `R`: 0 <= n <= 20.
- Use `xTaskCreate()` / `vTaskDelete()`; do not leave tasks or blocks behind.
- Simulated time: 1 tick = 1 ms. Code between two blocking calls takes zero ticks.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"

#define WORKER_PRIO 4

void worker_done(void);

size_t task_footprint(configSTACK_DEPTH_TYPE words)
{
    /* TODO: free heap before, xTaskCreate(probe, ..., words, ..., 1, &h),
       free heap after, vTaskDelete(h), return the drop */
    (void)words;
    return 0;
}

void spawn_and_reclaim(unsigned n)
{
    /* TODO: create n workers at WORKER_PRIO that call worker_done() and
       vTaskDelete(NULL); return only when their memory is back */
    (void)n;
}
@@@ harness_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

static unsigned g_done;

void worker_done(void)
{
    g_done++;
}

/*USER_CODE*/

static void ref_probe(void *p)
{
    (void)p;
    for (;;) vTaskDelay(1000);
}

static size_t ref_footprint(configSTACK_DEPTH_TYPE words)
{
    TaskHandle_t h = NULL;
    size_t before = xPortGetFreeHeapSize(), cost;

    if (xTaskCreate(ref_probe, "ref", words, NULL, 1, &h) != pdPASS) return 0;
    cost = before - xPortGetFreeHeapSize();
    vTaskDelete(h);
    return cost;
}

static int g_count;
static char g_cmd[10];
static unsigned g_arg[10];

static void test_task(void *p)
{
    size_t first = 0;
    unsigned first_words = 0;
    int i, have_first = 0;
    (void)p;

    for (i = 0; i < g_count; i++) {
        size_t before = xPortGetFreeHeapSize(), after;
        if (g_cmd[i] == 'F') {
            size_t ref = ref_footprint((configSTACK_DEPTH_TYPE)g_arg[i]);
            size_t got;
            before = xPortGetFreeHeapSize();
            got = task_footprint((configSTACK_DEPTH_TYPE)g_arg[i]);
            after = xPortGetFreeHeapSize();
            printf("footprint(%u): %s, %s", g_arg[i], got == ref ? "ok" : "WRONG",
                   after == before ? "heap restored" : "LEAK");
            if (have_first) {
                printf(", diff vs footprint(%u): %+d", first_words, (int)got - (int)first);
            } else {
                have_first = 1;
                first = got;
                first_words = g_arg[i];
            }
            printf("\n");
        } else {
            g_done = 0;
            spawn_and_reclaim(g_arg[i]);
            after = xPortGetFreeHeapSize();
            printf("reclaim(%u): workers ran=%u heap delta=%d\n", g_arg[i], g_done,
                   (int)before - (int)after);
        }
    }
    vTaskDelete(NULL);
}

int main(void)
{
    int i;

    if (scanf("%d", &g_count) != 1 || g_count < 1 || g_count > 10) return 1;
    for (i = 0; i < g_count; i++) {
        if (scanf(" %c %u", &g_cmd[i], &g_arg[i]) != 2) return 1;
    }
    xTaskCreate(test_task, "test", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
    vSimSetTickLimit(1000);
    vTaskStartScheduler();
    return 0;
}
@@@ sample_input
3
F 128
F 256
R 2
@@@ sample_output
footprint(128): ok, heap restored
footprint(256): ok, heap restored, diff vs footprint(128): +1024
reclaim(2): workers ran=2 heap delta=0
@@@ sample_input
2
R 1
F 300
@@@ sample_output
reclaim(1): workers ran=1 heap delta=0
footprint(300): ok, heap restored
@@@ hidden_input
1
R 0
@@@ hidden_output
reclaim(0): workers ran=0 heap delta=0
@@@ hidden_input
4
F 4096
F 64
F 4096
F 1000
@@@ hidden_output
footprint(4096): ok, heap restored
footprint(64): ok, heap restored, diff vs footprint(4096): -32256
footprint(4096): ok, heap restored, diff vs footprint(4096): +0
footprint(1000): ok, heap restored, diff vs footprint(4096): -24768
@@@ hidden_input
3
R 20
R 5
R 20
@@@ hidden_output
reclaim(20): workers ran=20 heap delta=0
reclaim(5): workers ran=5 heap delta=0
reclaim(20): workers ran=20 heap delta=0
@@@ hidden_input
5
F 256
R 3
F 258
R 1
F 257
@@@ hidden_output
footprint(256): ok, heap restored
reclaim(3): workers ran=3 heap delta=0
footprint(258): ok, heap restored, diff vs footprint(256): +16
reclaim(1): workers ran=1 heap delta=0
footprint(257): ok, heap restored, diff vs footprint(256): +16
@@@ hidden_input
2
F 65
F 64
@@@ hidden_output
footprint(65): ok, heap restored
footprint(64): ok, heap restored, diff vs footprint(65): -16
@@@ hint
Read `xPortGetFreeHeapSize()` before and after `xTaskCreate()`. Delete the probe through its handle: deleting **another** task frees its memory immediately. For the workers, think about who frees the memory of a task that deleted itself, and when that code gets the CPU.
@@@ hint
In `spawn_and_reclaim()`, remember the free heap, create the workers (they run at once, because priority 4 > 3), then `while (xPortGetFreeHeapSize() != before) vTaskDelay(1);`. Blocking lets the idle task run `prvCheckTasksWaitingTermination()`, which frees the TCBs and stacks.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"

#define WORKER_PRIO 4

void worker_done(void);

static void probe_task(void *pv)
{
    (void)pv;
    for (;;) {
        vTaskDelay(1000);          /* never reached while the caller holds the CPU */
    }
}

size_t task_footprint(configSTACK_DEPTH_TYPE words)
{
    TaskHandle_t h = NULL;
    size_t before = xPortGetFreeHeapSize();
    size_t cost;

    if (xTaskCreate(probe_task, "probe", words, NULL, 1, &h) != pdPASS) {
        return 0;
    }
    cost = before - xPortGetFreeHeapSize();   /* TCB + stack + 2 block headers */
    vTaskDelete(h);                            /* not running: freed immediately */
    return cost;
}

static void worker_task(void *pv)
{
    (void)pv;
    worker_done();
    vTaskDelete(NULL);   /* goes to xTasksWaitingTermination; idle frees it */
}

void spawn_and_reclaim(unsigned n)
{
    size_t before = xPortGetFreeHeapSize();
    unsigned i;

    for (i = 0; i < n; i++) {
        /* priority 4 > caller's 3: the worker runs and self-deletes right here */
        xTaskCreate(worker_task, "wrk", configMINIMAL_STACK_SIZE, NULL, WORKER_PRIO, NULL);
    }
    /* Block so that the idle task can free the self-deleted TCBs and stacks. */
    while (xPortGetFreeHeapSize() != before) {
        vTaskDelay(1);
    }
}
@@@ explanation_md
**Approach.** `xTaskCreate()` makes two heap allocations: the stack (`words * sizeof(StackType_t)` bytes) and the TCB. heap_4 puts a block header in front of each one and rounds each block up to the port alignment (16 bytes here). The free-heap drop measured around one `xTaskCreate()` is therefore the real cost of a task, and the only number that matters in a memory budget. Because the probe has priority 1, it never runs, and `vTaskDelete(h)` from another task returns both blocks to the heap at once.

The harness output shows the rounding: 256 → 258 words is +16 bytes (2 words, rounded up to one 16-byte unit), and 257 words also costs +16 bytes.

A task cannot free the stack it is running on. So `vTaskDelete(NULL)` only moves the TCB to `xTasksWaitingTermination`, and the **idle task** frees it in `prvCheckTasksWaitingTermination()`. The idle task has priority 0: it runs only when everything else is blocked. `spawn_and_reclaim()` must therefore **block** (here `vTaskDelay(1)` until the free heap is back) before it can claim that all memory came back. Without that wait, the harness sees a heap delta of `n` task footprints.

**Complexity.** `task_footprint()` is O(1) plus one heap_4 allocate/free (O(number of free blocks)). `spawn_and_reclaim(n)` makes O(n) allocations and waits one tick: the idle task frees all `n` TCBs in its first pass. Peak extra RAM: `n` task footprints, until idle runs.

**Common mistakes**
- Returning right after creating the self-deleting workers: their memory is still allocated, because the idle task never got the CPU.
- An idle task starved by a busy loop: in a real product, self-deleted tasks then leak forever. A classic field bug in "create a task per request" designs.
- Computing the cost as `words * 4`: the stack depth is in words of `StackType_t` (8 bytes on this 64-bit simulator, 4 on a Cortex-M), and the TCB and the block headers come on top.
- Comparing `xPortGetMinimumEverFreeHeapSize()` instead of `xPortGetFreeHeapSize()`: that is the low-water mark, and it never goes back up.
- Reading the free heap before the heap is initialised: heap_4 reports 0 until the first `pvPortMalloc()`.

**Interview follow-ups**
- heap_1 vs heap_2 vs heap_4 vs heap_5: which can free, which coalesces adjacent free blocks, which supports non-contiguous RAM?
- Why is "create a task per event" an anti-pattern on a small MCU, and what would you use instead (a worker pool, a queue)?
- How would you track the worst-case heap usage over a whole drive cycle (`xPortGetMinimumEverFreeHeapSize`, `vPortGetHeapStats`)?
- What happens to the memory a task allocated with `pvPortMalloc()` when it is deleted?
