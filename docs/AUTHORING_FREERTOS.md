# Authoring FreeRTOS questions

Read [AUTHORING.md](AUTHORING.md) first: the `.q` format, tests, hints, explanation and portability rules
all apply. This file adds what is specific to the **FreeRTOS track**.

## 1. Track rules

| Topic | slug (folder) | ID prefix |
|---|---|---|
| Tasks & Scheduling | `rtos-tasks` | `RTK` |
| Queues | `rtos-queues` | `RQU` |
| Semaphores & Mutexes | `rtos-sync` | `RSM` |
| Event Groups & Notifications | `rtos-events` | `REV` |
| Software Timers | `rtos-timers` | `RTM` |
| Interrupts & ISRs | `rtos-isr` | `RIS` |
| RTOS Memory Management | `rtos-memory` | `RMM` |
| RTOS Design Patterns | `rtos-design` | `RDS` |

- **10 questions per topic: 3 Easy (E-01..E-03), 4 Medium (M-01..M-04), 3 Hard (H-01..H-03).**
- **Only `CODE` and `FUNCTION`.** No PREDICT_OUTPUT and no FIND_THE_BUG: every question is "write the RTOS code
  yourself". Prefer `FUNCTION` with a hidden harness (it owns `main()`, reads the scenario, schedules interrupts,
  starts the scheduler and prints the summary).
- Interview level for embedded/automotive (Bosch, Continental, KPIT, Tata Elxsi, Visteon, Aptiv, Qualcomm, NXP,
  TI, Harman, Minda). Easy 10-15 min, Medium 20-30 min, Hard 30-45 min.
- Tag questions with `freertos` plus concept tags (`vtaskdelayuntil`, `priority-inheritance`, ...). Use
  `embedded` / `asked-in-automotive` where natural (not counted for this track).

## 2. The simulator (read this carefully)

Submissions are compiled against the real **FreeRTOS-Kernel V11.3.3** (`judge-runtime/freertos/kernel`) with a
deterministic **virtual-time simulator port** (`judge-runtime/freertos/sim`). Include `FreeRTOS.h`, `task.h`,
`queue.h`, `semphr.h`, `timers.h`, `event_groups.h`, `stream_buffer.h`, `message_buffer.h` as needed, and
`sim.h` for the simulator control API.

**Time model**
- 1 tick = 1 ms (`configTICK_RATE_HZ 1000`, so `pdMS_TO_TICKS(x) == x`).
- **Ordinary code runs in zero simulated time.** The tick count advances only when every application task is
  blocked (the idle task advances it), or inside `vSimBusyWork(n)`.
- `vSimBusyWork(n)` simulates CPU-bound work that takes `n` ticks: tick and peripheral interrupts keep firing,
  higher-priority tasks preempt it, and equal-priority tasks are **time-sliced one tick at a time**. Use it for
  CPU load, time slicing, priority inversion, deadline misses, and `vTaskDelay` vs `vTaskDelayUntil` drift.
- A task that never blocks (busy loop without `vTaskDelay`/queue/semaphore waits or `vSimBusyWork`) starves the
  idle task: time stops and the test hits the 2 s **Time Limit Exceeded** (with an explanatory message).
- Everything is deterministic: same output on every run, on Linux and Windows. The validator runs every
  solution 3 times and requires identical output.

**Control API (`sim.h`)**
- `vSimSetTickLimit(N)`: `vTaskStartScheduler()` **returns** to `main()` when the tick count reaches `N`. Work
  that becomes ready at tick `N` still runs before it returns. Default `N` = 10000. After it returns, `main()`
  may only call **non-blocking** APIs (`uxQueueMessagesWaiting`, `xPortGetFreeHeapSize`, reading globals, ...).
- `xSimScheduleInterrupt(tick, handler, arg)`: run `handler(arg)` **in interrupt context** right after the tick
  count becomes `tick` (`tick >= 1`). Handlers must use `...FromISR()` APIs and `portYIELD_FROM_ISR()`. Several
  interrupts at one tick run in scheduling order. If a handler wakes a higher-priority task and calls
  `portYIELD_FROM_ISR(pdTRUE)`, that task runs at the same tick. Without the yield, it runs at the next tick
  (exactly the latency bug you see on real hardware).
- `vSimBusyWork(n)`: see above (never inside an ISR).
- `vSimSetMallocFailedHandler(fn)`: called from `vApplicationMallocFailedHook`.

**Fixed configuration** (`judge-runtime/freertos/sim/FreeRTOSConfig.h`)
- Priorities `0..7`. Use **1..6 for application tasks**: 0 is idle, and the timer service task is **7**.
- Preemption and time slicing are on. `configMINIMAL_STACK_SIZE` is 256 (words).
- heap_4 with `configTOTAL_HEAP_SIZE` = 128 KB, static and dynamic allocation.
- Enabled: mutexes, recursive mutexes, counting semaphores, queue sets, event groups, task notifications
  (3 indexes), stream/message buffers, software timers (queue length 16), `xTaskAbortDelay`, `eTaskGetState`.
- `configASSERT` failures, blocking calls inside an ISR, and task functions that return all produce a Runtime
  Error with a readable `FreeRTOS: ...` message.

**Not meaningful in the simulator (do not print or test):**
- `uxTaskGetStackHighWaterMark` (tasks run on host threads);
- run-time stats, tickless idle, SMP, MPU;
- absolute heap numbers in a **statement**. Heap *deltas* are deterministic, but explain them through the
  harness rather than hard-coding magic numbers in the text.

## 3. Writing a question

- **Statement.**
  - Give the exact API the user implements (for example `void app_start(const Config *cfg)` plus task
    functions).
  - Give the priorities to use, and the exact trace format: lines look like `[t=<tick>] <event>`.
  - State the timing rules that matter: when the first event happens, what happens at the same tick, and
    whether the simulation runs "up to and including tick N".
  - Add a worked example trace.
- **Harness.**
  - Reads a small scenario from stdin: periods, priorities, event lists such as `ISR 15 0x41`, and the
    duration.
  - Calls the user's entry function, schedules interrupts, calls `vSimSetTickLimit()` and
    `vTaskStartScheduler()`, then prints a summary (counters, queue fill level, heap delta, verdict lines).
  - Must compile warning-free.
  - Must ban shortcuts that defeat the exercise, with macros before `/*USER_CODE*/`. For example, ban
    `xTaskDelayUntil` in a question that asks for a hand-written drift-free scheduler.
  - Should verify behaviour, not just print. For example, record each consumer timestamp and print `LATE` if
    it exceeds a deadline.
- **Same-tick ordering is part of the answer.** Higher priority runs first. Equal priority follows FreeRTOS
  ready-list order (the order tasks were made ready). Prefer scenarios where the order is decided by priority
  or by explicit blocking, and explain it in the statement.
- **Printing.**
  - `printf` from tasks is fine (one task runs at a time). Print ticks as `(unsigned)xTaskGetTickCount()`.
  - Never print `BaseType_t`/`UBaseType_t` without a cast (`(int)` or `(long long)`). `long` is forbidden
    repo-wide.
- **Starter code.**
  - Includes the headers and stubs of the required functions/tasks, and must compile.
  - Typically creates nothing. The user writes the `xTaskCreate`/`xQueueCreate` calls.
- **Tests.**
  - At least 2 sample and 5 hidden.
  - Vary periods, priorities, burst sizes, ISR timings, and edge cases: zero events, an event at tick 1, an
    event exactly at the tick limit, simultaneous events, queue-full / timeout paths.
  - Keep durations at or below ~20000 ticks.
- **Explanation.** Approach, **Complexity** (CPU/RAM cost per event, worst-case latency, blocking time),
  Common mistakes (e.g. `vTaskDelay` drift, missing `portYIELD_FROM_ISR`, wrong priority, polling instead of
  blocking, unprotected shared data), and Interview follow-ups.

## 4. Workflow

```bash
npm run q -- check questions_src/rtos-tasks/RTK-E-01.q            # one file (gcc)
npm run q -- check questions_src/rtos-tasks/RTK-E-01.q --cc clang # one file (clang + ASan + UBSan)
node scripts/validate_questions.js --src --topic rtos-tasks --jobs 1
node scripts/validate_questions.js --src --topic rtos-tasks --jobs 1 --cc clang
```

The first compile of a session builds the kernel (a few seconds) and caches it in `<tmp>/csim-freertos/`.
