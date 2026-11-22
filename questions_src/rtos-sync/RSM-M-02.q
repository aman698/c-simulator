@@@ meta
id: RSM-M-02
topic: Semaphores & Mutexes
difficulty: Medium
type: FUNCTION
title: Thread-Safe Nested Logger With a Recursive Mutex
tags: freertos, recursive-mutex, mutex, reentrancy, logging, embedded
@@@ statement_md
A body-control ECU logs to one UART. Every task may call `log_line()` for a single line, and some tasks print a multi-line **block** (a header, some lines, a footer) with `log_block()`. A block must appear on the UART **as one piece**: no line of another task may land between its header and footer. Lines written with separate `log_line()` calls may be interleaved with other tasks' output.

`log_block()` is naturally written on top of `log_line()`, so the lock is taken twice by the same task: once in `log_block()` and again inside each `log_line()`. With an ordinary mutex the second take blocks forever (the task waits for itself). Implement the logger with a **recursive mutex**.

```c
/* provided by the hidden harness: prints "[t=<tick>] <task name>: <text>",
   then takes 1 tick of CPU time (the UART is slow) */
void uart_write_line(const char *text);

SemaphoreHandle_t g_log_mutex;   /* you define and create it; the harness inspects it */

void logger_init(void);                       /* create g_log_mutex (called before the scheduler starts) */
void log_line(const char *text);              /* write one line atomically */
void log_block(const char *title, const char *const *lines, int n);
        /* atomically: log_line(title); log_line(lines[0..n-1]); log_line("<<end>>"); */
```

Requirements:
- `g_log_mutex` is created with `xSemaphoreCreateRecursiveMutex()`. Plain mutexes, binary/counting semaphores, critical sections and `vTaskSuspendAll()` are not allowed (they do not compile in this exercise).
- `log_line()` holds the lock while it calls `uart_write_line()`. `log_block()` holds it for the whole block and calls `log_line()` for every line, including the title and the `<<end>>` footer.
- Wait forever for the lock. Every take must be matched by a give: when a task returns from `log_line()`/`log_block()`, it must not hold the lock any more.

**How it is tested.** The hidden harness creates the logging tasks: each one waits `start` ticks, then either calls `log_block("<<NAME>>", lines, count)` with lines `NAME.1 ... NAME.count` (kind `B`) or calls `log_line("NAME.i")` `count` times in a row (kind `L`), then deletes itself. `uart_write_line()` checks that the caller holds `g_log_mutex` and that blocks are not interleaved. After the run (up to and including tick `D`) it prints whether every task finished and a verdict (`LOG OK`, `INTERLEAVED`, `UNLOCKED WRITE`, `DEADLOCK` or `LOCK LEAKED`).

Timing: a task that blocks on the logger mutex raises the holder to its own priority (FreeRTOS recursive mutexes have priority inheritance). When the holder releases the mutex completely, the highest-priority waiter is woken up and takes the mutex when it runs: at the same tick if it has a higher priority than the releasing task. There is no hand-off: a higher-priority releasing task that calls `log_line()` again right away takes the mutex again first.

**Input**
```
<n>
<name> <priority> <start> <B|L> <count>     (n lines)
<D>
```

**Example 1**
```
Input:
3
A 1 1 B 3
B 3 2 L 2
C 2 3 B 1
50

Output:
[t=1] A: <<A>>
[t=2] A: A.1
[t=3] A: A.2
[t=4] A: A.3
[t=5] A: <<end>>
[t=6] B: B.1
[t=7] B: B.2
[t=8] C: <<C>>
[t=9] C: C.1
[t=10] C: <<end>>
all 3 tasks finished
LOG OK
```
B wakes at t=2 while A is inside its block. B blocks on the mutex and A inherits priority 3, so C (priority 2, ready at t=3) cannot run either. A releases the mutex after its footer (t=6), then B writes its two lines, then C.

**Example 2**
```
Input:
2
X 1 1 L 3
Y 4 2 B 1
30

Output:
[t=1] X: X.1
[t=2] Y: <<Y>>
[t=3] Y: Y.1
[t=4] Y: <<end>>
[t=5] X: X.2
[t=6] X: X.3
all 2 tasks finished
LOG OK
```
X's three separate lines may be interleaved: Y's whole block fits between `X.1` and `X.2`.
@@@ constraints_md
- 1 <= n <= 5, priorities are different and in 1..6, 1 <= start <= 100, 0 <= count <= 6, D <= 500.
- Simulated time: 1 tick = 1 ms. Each `uart_write_line()` takes 1 tick of CPU time.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

void uart_write_line(const char *text);

SemaphoreHandle_t g_log_mutex;

void logger_init(void)
{
    /* TODO: create g_log_mutex as a recursive mutex */
}

void log_line(const char *text)
{
    /* TODO: lock */
    uart_write_line(text);
    /* TODO: unlock */
}

void log_block(const char *title, const char *const *lines, int n)
{
    int i;

    /* TODO: hold the lock for the whole block */
    log_line(title);
    for (i = 0; i < n; i++) log_line(lines[i]);
    log_line("<<end>>");
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "sim.h"

extern SemaphoreHandle_t g_log_mutex;
void logger_init(void);
void log_line(const char *text);
void log_block(const char *title, const char *const *lines, int n);

static TaskHandle_t g_block_owner;
static int g_interleaved, g_unlocked, g_finished;

void uart_write_line(const char *text)
{
    TaskHandle_t me = xTaskGetCurrentTaskHandle();

    printf("[t=%u] %s: %s\n", (unsigned)xTaskGetTickCount(), pcTaskGetName(NULL), text);
    if (g_log_mutex == NULL || xSemaphoreGetMutexHolder(g_log_mutex) != me) g_unlocked++;
    if (g_block_owner != NULL && g_block_owner != me) g_interleaved++;
    if (strcmp(text, "<<end>>") == 0) {
        if (g_block_owner == me) g_block_owner = NULL;
    } else if (strncmp(text, "<<", 2) == 0) {
        g_block_owner = me;
    }
    vSimBusyWork(1);
}

#undef xSemaphoreCreateMutex
#undef xSemaphoreCreateBinary
#undef xSemaphoreCreateCounting
#undef taskENTER_CRITICAL
#define xSemaphoreCreateMutex() xSemaphoreCreateMutex_is_not_allowed_use_a_recursive_mutex()
#define xSemaphoreCreateBinary() xSemaphoreCreateBinary_is_not_allowed_use_a_recursive_mutex()
#define xSemaphoreCreateCounting(a, b) xSemaphoreCreateCounting_is_not_allowed_use_a_recursive_mutex()
#define taskENTER_CRITICAL() taskENTER_CRITICAL_is_not_allowed_here()
#define vTaskSuspendAll() vTaskSuspendAll_is_not_allowed_here()

/*USER_CODE*/

#undef xSemaphoreCreateMutex
#undef xSemaphoreCreateBinary
#undef xSemaphoreCreateCounting
#undef taskENTER_CRITICAL
#undef vTaskSuspendAll

typedef struct {
    char name[8];
    TickType_t start;
    char kind;
    int count;
    char text[6][16];
    const char *lines[6];
    char title[16];
} LogJob;

static LogJob g_jobs[5];

static void log_task(void *p)
{
    LogJob *j = (LogJob *)p;
    int i;

    vTaskDelay(j->start);
    if (j->kind == 'B') {
        log_block(j->title, j->lines, j->count);
    } else {
        for (i = 0; i < j->count; i++) log_line(j->text[i]);
    }
    g_finished++;
    vTaskDelete(NULL);
}

int main(void)
{
    int n, i, k;
    unsigned prio, start, d;

    if (scanf("%d", &n) != 1 || n < 1 || n > 5) return 1;
    logger_init();
    for (i = 0; i < n; i++) {
        LogJob *j = &g_jobs[i];
        if (scanf("%7s %u %u %c %d", j->name, &prio, &start, &j->kind, &j->count) != 5) return 1;
        if (j->count < 0 || j->count > 6) return 1;
        j->start = (TickType_t)start;
        snprintf(j->title, sizeof j->title, "<<%s>>", j->name);
        for (k = 0; k < j->count; k++) {
            snprintf(j->text[k], sizeof j->text[k], "%s.%d", j->name, k + 1);
            j->lines[k] = j->text[k];
        }
        xTaskCreate(log_task, j->name, configMINIMAL_STACK_SIZE, j, (UBaseType_t)prio, NULL);
    }
    if (scanf("%u", &d) != 1) return 1;

    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();

    if (g_finished == n) printf("all %d tasks finished\n", n);
    else printf("%d of %d tasks never finished\n", n - g_finished, n);
    if (g_finished != n) printf("DEADLOCK\n");
    else if (g_unlocked) printf("UNLOCKED WRITE\n");
    else if (g_interleaved) printf("INTERLEAVED\n");
    else if (g_log_mutex == NULL || xSemaphoreGetMutexHolder(g_log_mutex) != NULL) printf("LOCK LEAKED\n");
    else printf("LOG OK\n");
    return 0;
}
@@@ sample_input
3
A 1 1 B 3
B 3 2 L 2
C 2 3 B 1
50
@@@ sample_output
[t=1] A: <<A>>
[t=2] A: A.1
[t=3] A: A.2
[t=4] A: A.3
[t=5] A: <<end>>
[t=6] B: B.1
[t=7] B: B.2
[t=8] C: <<C>>
[t=9] C: C.1
[t=10] C: <<end>>
all 3 tasks finished
LOG OK
@@@ sample_input
2
X 1 1 L 3
Y 4 2 B 1
30
@@@ sample_output
[t=1] X: X.1
[t=2] Y: <<Y>>
[t=3] Y: Y.1
[t=4] Y: <<end>>
[t=5] X: X.2
[t=6] X: X.3
all 2 tasks finished
LOG OK
@@@ hidden_input
1
S 2 1 B 0
20
@@@ hidden_output
[t=1] S: <<S>>
[t=2] S: <<end>>
all 1 tasks finished
LOG OK
@@@ hidden_input
2
P 5 4 B 2
Q 6 4 B 2
40
@@@ hidden_output
[t=4] Q: <<Q>>
[t=5] Q: Q.1
[t=6] Q: Q.2
[t=7] Q: <<end>>
[t=8] P: <<P>>
[t=9] P: P.1
[t=10] P: P.2
[t=11] P: <<end>>
all 2 tasks finished
LOG OK
@@@ hidden_input
4
A 1 1 B 6
B 2 2 L 4
C 3 3 B 2
D 4 5 L 1
100
@@@ hidden_output
[t=1] A: <<A>>
[t=2] A: A.1
[t=3] A: A.2
[t=4] A: A.3
[t=5] A: A.4
[t=6] A: A.5
[t=7] A: A.6
[t=8] A: <<end>>
[t=9] D: D.1
[t=10] C: <<C>>
[t=11] C: C.1
[t=12] C: C.2
[t=13] C: <<end>>
[t=14] B: B.1
[t=15] B: B.2
[t=16] B: B.3
[t=17] B: B.4
all 4 tasks finished
LOG OK

@@@ hidden_input
5
V 1 1 L 6
W 2 3 B 3
X 3 4 L 0
Y 5 6 B 1
Z 6 6 L 2
120
@@@ hidden_output
[t=1] V: V.1
[t=2] V: V.2
[t=3] W: <<W>>
[t=4] W: W.1
[t=5] W: W.2
[t=6] W: W.3
[t=7] W: <<end>>
[t=8] Z: Z.1
[t=9] Z: Z.2
[t=10] Y: <<Y>>
[t=11] Y: Y.1
[t=12] Y: <<end>>
[t=13] V: V.3
[t=14] V: V.4
[t=15] V: V.5
[t=16] V: V.6
all 5 tasks finished
LOG OK

@@@ hidden_input
3
K 6 10 L 2
J 1 2 B 5
I 3 11 B 0
60
@@@ hidden_output
[t=2] J: <<J>>
[t=3] J: J.1
[t=4] J: J.2
[t=5] J: J.3
[t=6] J: J.4
[t=7] J: J.5
[t=8] J: <<end>>
[t=10] K: K.1
[t=11] K: K.2
[t=12] I: <<I>>
[t=13] I: <<end>>
all 3 tasks finished
LOG OK

@@@ hint
A recursive mutex counts how many times its **owner** has taken it. Use the dedicated calls `xSemaphoreTakeRecursive()` / `xSemaphoreGiveRecursive()`; the plain `xSemaphoreTake()` on the same task twice blocks forever.
@@@ hint
`log_line`: `xSemaphoreTakeRecursive(g_log_mutex, portMAX_DELAY); uart_write_line(text); xSemaphoreGiveRecursive(g_log_mutex);`. `log_block`: take once, call `log_line()` for title, lines and footer (each nests one level deeper), give once. Other tasks get the mutex only when the count is back to 0.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

void uart_write_line(const char *text);

SemaphoreHandle_t g_log_mutex;

void logger_init(void)
{
    g_log_mutex = xSemaphoreCreateRecursiveMutex();
}

void log_line(const char *text)
{
    xSemaphoreTakeRecursive(g_log_mutex, portMAX_DELAY);   /* depth +1 (no blocking if we already own it) */
    uart_write_line(text);
    xSemaphoreGiveRecursive(g_log_mutex);                  /* depth -1 */
}

void log_block(const char *title, const char *const *lines, int n)
{
    int i;

    xSemaphoreTakeRecursive(g_log_mutex, portMAX_DELAY);   /* held for the whole block */
    log_line(title);
    for (i = 0; i < n; i++) log_line(lines[i]);
    log_line("<<end>>");
    xSemaphoreGiveRecursive(g_log_mutex);                  /* depth 0: other tasks may log */
}
@@@ explanation_md
**Approach.** A recursive mutex stores its owner and a nesting counter (`uxRecursiveCallCount`). `xSemaphoreTakeRecursive()` by the owner only increments the counter; by another task it blocks like a normal mutex (with priority inheritance). `xSemaphoreGiveRecursive()` decrements the counter and releases the mutex only when it reaches zero. So `log_block()` takes the mutex once for the whole block and every nested `log_line()` takes it again without blocking. Another task can get the mutex only after the footer, which keeps the block in one piece. Separate `log_line()` calls release the mutex between lines, so other tasks may slip in between (Example 2).

Example 1 also shows inheritance through the recursive mutex: B blocks on it at t=2, A runs at priority 3 until it has released the mutex completely, so C (priority 2) cannot slip in.

**Complexity.** O(1) per take/give, plus an O(waiting tasks) insertion when a task blocks. A task waits at most for the longest block another task is printing (here: `count + 2` ticks). RAM: one mutex object; the nesting counter is stored inside it, no per-task memory.

**Common mistakes**
- Using `xSemaphoreTake()`/`xSemaphoreGive()` on a recursive mutex, or a plain mutex with nested takes: the second take by the same task blocks forever (self-deadlock).
- Unbalanced takes and gives (an early `return` on an error path): the counter never reaches zero and every other logger blocks forever.
- Locking only in `log_line()`: each line is atomic but blocks get interleaved.
- Using a critical section to protect slow UART output: interrupts are disabled for the whole transmission.
- Recursive mutexes hiding a design problem: many teams prefer an internal `log_line_unlocked()` helper and a plain mutex. Be ready to discuss both.

**Interview follow-ups**
- How would you implement the same logger with a plain mutex? (Internal unlocked helper called by both public functions.)
- Why can a recursive mutex not be given by a task that does not own it, and not be used from an ISR?
- Logging from an ISR: how would you do it without blocking? (Ring buffer / stream buffer drained by a logger task.)
- How large can the nesting depth get, and what happens when a recursive give is called once too often?
