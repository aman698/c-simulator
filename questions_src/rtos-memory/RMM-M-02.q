@@@ meta
id: RMM-M-02
topic: RTOS Memory Management
difficulty: Medium
type: FUNCTION
title: Malloc-Failed Hook And Graceful Degradation Under Heap Pressure
tags: freertos, pvportmalloc, malloc-failed-hook, heap-4, graceful-degradation, embedded, asked-in-automotive
@@@ statement_md
A telematics unit uploads messages of variable length. Each message is copied into a buffer from the FreeRTOS heap (`pvPortMalloc`), sent over the radio, and freed. Other subsystems also use the heap, so an allocation **can fail**. When it does, the unit must keep running in a **degraded mode** instead of crashing or rebooting.

```c
#define MSG_QUEUE_LEN  16
#define DEGRADED_MAX   64     /* largest message accepted in degraded mode */
#define RECOVER_BYTES  256    /* free heap needed to leave degraded mode */

typedef struct { unsigned seq; size_t len; } Msg;

extern QueueHandle_t g_msg_q;                    /* defined by the harness, created by you */

/* provided by the harness */
void radio_send(const uint8_t *buf, size_t len, unsigned seq); /* "[t=..] #<seq> sent len=<len>" */
void log_event(unsigned seq, const char *what);                /* "[t=..] #<seq> <what>"         */
void log_mode(const char *mode);                               /* "[t=..] mode <mode>"           */

/* you write these */
void     app_start(void);
unsigned malloc_failures(void);
```

**`app_start()`** (called before the scheduler starts) must:
1. create `g_msg_q` (`MSG_QUEUE_LEN` items of `Msg`) and the **uploader task** (priority 2);
2. register your own malloc-failed hook with `vSimSetMallocFailedHandler(fn)`. In this simulator, `vApplicationMallocFailedHook()` calls `fn`. The hook only **counts** failures. **`malloc_failures()`** returns that count.

**The uploader** receives messages from `g_msg_q` (blocking forever). The mode starts as *normal*. For each message, apply these steps in order:

1. If the mode is *degraded* and `xPortGetFreeHeapSize() >= RECOVER_BYTES`, switch to normal and call `log_mode("normal")`.
2. `len == 0` is a heartbeat: `log_event(seq, "heartbeat")`. Nothing is allocated.
3. If the mode is degraded and `len > DEGRADED_MAX`: `log_event(seq, "rejected")`. No allocation is tried.
4. `buf = pvPortMalloc(len)`. If it returns NULL: `log_event(seq, "dropped")`. If the mode was normal, switch to degraded and call `log_mode("degraded")`.
5. Otherwise fill all `len` bytes with `(uint8_t)seq`, call `radio_send(buf, len, seq)`, then `vPortFree(buf)`.

**How it is tested.** The harness counts every `pvPortMalloc()` call that fails in your code, and checks that every buffer you send is filled correctly. After `app_start()`, it reserves heap so that exactly `R` bytes are free when the scheduler starts. Then a script task (priority 5) executes timed events:

- `M <len>`: send the next message (`seq = 1, 2, ...`) to `g_msg_q`;
- `H <bytes>`: another subsystem allocates `bytes` and keeps them;
- `R`: that subsystem releases everything it allocated.

All events of one tick are applied in input order **before** the uploader handles any message of that tick. In heap_4, an allocation of `n` bytes uses `n + 16` bytes rounded up to a multiple of 16, so `R = 512` fits a 100-byte message but not a 500-byte one. The tests stay well away from these boundaries.

At the end, the harness releases its own memory and prints `malloc failures: hook=<malloc_failures()> actual=<counted>`, then `heap after run: OK` (or `LEAK`).

**Input**
```
<R>
<n>
<tick> M <len> | <tick> H <bytes> | <tick> R      (n lines, ticks non-decreasing)
```

**Example**
```
Input:
512
8
1 M 100
2 M 0
3 H 400
4 M 100
5 M 40
6 M 80
7 R
8 M 80

Output:
[t=1] #1 sent len=100
[t=2] #2 heartbeat
[t=4] #3 dropped
[t=4] mode degraded
[t=5] #4 sent len=40
[t=6] #5 rejected
[t=8] mode normal
[t=8] #6 sent len=80
malloc failures: hook=1 actual=1
heap after run: OK
```
At t=3 the other subsystem takes 416 of the 512 free bytes. Message #3 needs 128 bytes, so it fails. Message #4 needs only 64, so it is sent even in degraded mode. After the release at t=7, 512 >= 256 free bytes bring the uploader back to normal mode.
@@@ constraints_md
- 64 <= R <= 16384 (multiple of 16), 0 <= n <= 30, 1 <= tick <= 1000, 0 <= len <= 4096.
- At most `MSG_QUEUE_LEN` messages are posted at the same tick. The harness's own allocations never fail.
- The simulation ends at tick 1000. Every buffer you allocate must be freed.
@@@ starter_code
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

#define MSG_QUEUE_LEN  16
#define DEGRADED_MAX   64
#define RECOVER_BYTES  256

typedef struct { unsigned seq; size_t len; } Msg;

extern QueueHandle_t g_msg_q;

void radio_send(const uint8_t *buf, size_t len, unsigned seq);
void log_event(unsigned seq, const char *what);
void log_mode(const char *mode);

static void uploader_task(void *pv)
{
    Msg m;
    (void)pv;
    for (;;) {
        if (xQueueReceive(g_msg_q, &m, portMAX_DELAY) == pdPASS) {
            /* TODO: steps 1..5 */
        }
    }
}

void app_start(void)
{
    /* TODO: create g_msg_q and the uploader task, register the malloc-failed hook */
    (void)uploader_task;
}

unsigned malloc_failures(void)
{
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

QueueHandle_t g_msg_q;

static unsigned g_failed_allocs;

static void *judge_alloc(size_t n)
{
    void *p = pvPortMalloc(n);
    if (p == NULL) g_failed_allocs++;
    return p;
}

void radio_send(const uint8_t *buf, size_t len, unsigned seq)
{
    size_t i;
    for (i = 0; i < len; i++) {
        if (buf[i] != (uint8_t)seq) {
            printf("[t=%u] #%u CORRUPT buffer\n", (unsigned)xTaskGetTickCount(), seq);
            return;
        }
    }
    printf("[t=%u] #%u sent len=%u\n", (unsigned)xTaskGetTickCount(), seq, (unsigned)len);
}

void log_event(unsigned seq, const char *what)
{
    printf("[t=%u] #%u %s\n", (unsigned)xTaskGetTickCount(), seq, what);
}

void log_mode(const char *mode)
{
    printf("[t=%u] mode %s\n", (unsigned)xTaskGetTickCount(), mode);
}

#define pvPortMalloc(n) judge_alloc(n)
#define malloc(...) malloc_is_not_allowed_here

/*USER_CODE*/

#undef pvPortMalloc
#undef malloc

#define MAX_EV 30

static unsigned g_tick[MAX_EV], g_arg[MAX_EV];
static char g_kind[MAX_EV];
static int g_nev;
static void *g_hog[MAX_EV];
static int g_nhog;

static void script_task(void *pv)
{
    unsigned seq = 0;
    int i, j;
    (void)pv;

    for (i = 0; i < g_nev; i++) {
        TickType_t now = xTaskGetTickCount();
        if ((TickType_t)g_tick[i] > now) vTaskDelay((TickType_t)g_tick[i] - now);
        if (g_kind[i] == 'M') {
            Msg m;
            m.seq = ++seq;
            m.len = g_arg[i];
            if (xQueueSend(g_msg_q, &m, 0) != pdPASS) printf("QUEUE FULL\n");
        } else if (g_kind[i] == 'H') {
            g_hog[g_nhog++] = pvPortMalloc(g_arg[i]);
        } else {
            for (j = 0; j < g_nhog; j++) vPortFree(g_hog[j]);
            g_nhog = 0;
        }
    }
    for (;;) vTaskDelay(1000);
}

int main(void)
{
    unsigned r;
    size_t free0;
    void *ballast = NULL;
    int i;

    if (scanf("%u %d", &r, &g_nev) != 2 || g_nev < 0 || g_nev > MAX_EV) return 1;
    for (i = 0; i < g_nev; i++) {
        if (scanf("%u %c", &g_tick[i], &g_kind[i]) != 2) return 1;
        if (g_kind[i] != 'R' && scanf("%u", &g_arg[i]) != 1) return 1;
    }

    xTaskCreate(script_task, "script", configMINIMAL_STACK_SIZE, NULL, 5, NULL);
    app_start();
    if (g_msg_q == NULL) {
        printf("FAIL: g_msg_q was not created\n");
        return 0;
    }
    free0 = xPortGetFreeHeapSize();
    if (free0 > (size_t)r + 16) ballast = pvPortMalloc(free0 - r - 16);

    vSimSetTickLimit(1000);
    vTaskStartScheduler();

    for (i = 0; i < g_nhog; i++) vPortFree(g_hog[i]);
    vPortFree(ballast);
    printf("malloc failures: hook=%u actual=%u\n", malloc_failures(), g_failed_allocs);
    printf("heap after run: %s\n", xPortGetFreeHeapSize() == free0 ? "OK" : "LEAK");
    return 0;
}
@@@ sample_input
512
8
1 M 100
2 M 0
3 H 400
4 M 100
5 M 40
6 M 80
7 R
8 M 80
@@@ sample_output
[t=1] #1 sent len=100
[t=2] #2 heartbeat
[t=4] #3 dropped
[t=4] mode degraded
[t=5] #4 sent len=40
[t=6] #5 rejected
[t=8] mode normal
[t=8] #6 sent len=80
malloc failures: hook=1 actual=1
heap after run: OK
@@@ sample_input
1024
4
10 M 2000
10 M 0
10 M 64
10 M 65
@@@ sample_output
[t=10] #1 dropped
[t=10] mode degraded
[t=10] mode normal
[t=10] #2 heartbeat
[t=10] #3 sent len=64
[t=10] #4 sent len=65
malloc failures: hook=1 actual=1
heap after run: OK
@@@ hidden_input
256
0
@@@ hidden_output
malloc failures: hook=0 actual=0
heap after run: OK
@@@ hidden_input
128
5
1 M 0
2 M 0
3 M 50
4 M 0
5 M 64
@@@ hidden_output
[t=1] #1 heartbeat
[t=2] #2 heartbeat
[t=3] #3 sent len=50
[t=4] #4 heartbeat
[t=5] #5 sent len=64
malloc failures: hook=0 actual=0
heap after run: OK
@@@ hidden_input
4096
10
1 H 3000
1 M 2000
2 M 60
2 M 100
3 H 900
3 M 40
3 M 4000
4 R
5 M 4000
6 M 1000
@@@ hidden_output
[t=1] #1 dropped
[t=1] mode degraded
[t=2] mode normal
[t=2] #2 sent len=60
[t=2] #3 sent len=100
[t=3] #4 sent len=40
[t=3] #5 dropped
[t=3] mode degraded
[t=5] mode normal
[t=5] #6 sent len=4000
[t=6] #7 sent len=1000
malloc failures: hook=2 actual=2
heap after run: OK
@@@ hidden_input
512
7
1 H 448
1 M 10
2 M 1
3 M 0
4 R
5 M 300
6 M 300
@@@ hidden_output
[t=1] #1 sent len=10
[t=2] #2 sent len=1
[t=3] #3 heartbeat
[t=5] #4 sent len=300
[t=6] #5 sent len=300
malloc failures: hook=0 actual=0
heap after run: OK

@@@ hidden_input
16384
6
100 M 4096
200 H 15000
300 M 4096
300 M 64
300 M 4096
900 M 8
@@@ hidden_output
[t=100] #1 sent len=4096
[t=300] #2 dropped
[t=300] mode degraded
[t=300] mode normal
[t=300] #3 sent len=64
[t=300] #4 dropped
[t=300] mode degraded
[t=900] mode normal
[t=900] #5 sent len=8
malloc failures: hook=2 actual=2
heap after run: OK

@@@ hint
`vSimSetMallocFailedHandler(on_malloc_failed)` in `app_start()`. The hook runs inside the failing `pvPortMalloc()` call, in the caller's context. Keep it tiny: increment a counter, no printing and no blocking. Do the reaction (drop, mode change) in the uploader, where you test the returned pointer.
@@@ hint
Never call `pvPortMalloc(0)`: heap_4 returns NULL for 0 bytes, and that **also** triggers the malloc-failed hook, so a heartbeat would push you into degraded mode. Check `len == 0` before allocating, and in degraded mode check `len > DEGRADED_MAX` before allocating too.
@@@ solution_code
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

#define MSG_QUEUE_LEN  16
#define DEGRADED_MAX   64
#define RECOVER_BYTES  256

typedef struct { unsigned seq; size_t len; } Msg;

extern QueueHandle_t g_msg_q;

void radio_send(const uint8_t *buf, size_t len, unsigned seq);
void log_event(unsigned seq, const char *what);
void log_mode(const char *mode);

static volatile unsigned s_failures;

/* Runs inside the failing pvPortMalloc(): count only, never block or print. */
static void on_malloc_failed(void)
{
    s_failures++;
}

unsigned malloc_failures(void)
{
    return s_failures;
}

static void uploader_task(void *pv)
{
    int degraded = 0;
    Msg m;
    (void)pv;

    for (;;) {
        if (xQueueReceive(g_msg_q, &m, portMAX_DELAY) != pdPASS) {
            continue;
        }
        if (degraded && xPortGetFreeHeapSize() >= RECOVER_BYTES) {
            degraded = 0;
            log_mode("normal");
        }
        if (m.len == 0) {                       /* pvPortMalloc(0) would "fail" */
            log_event(m.seq, "heartbeat");
            continue;
        }
        if (degraded && m.len > DEGRADED_MAX) { /* shed load without touching the heap */
            log_event(m.seq, "rejected");
            continue;
        }
        {
            uint8_t *buf = (uint8_t *)pvPortMalloc(m.len);
            if (buf == NULL) {
                log_event(m.seq, "dropped");
                if (!degraded) {
                    degraded = 1;
                    log_mode("degraded");
                }
                continue;
            }
            memset(buf, (int)(m.seq & 0xFFu), m.len);
            radio_send(buf, m.len, m.seq);
            vPortFree(buf);
        }
    }
}

void app_start(void)
{
    g_msg_q = xQueueCreate(MSG_QUEUE_LEN, sizeof(Msg));
    xTaskCreate(uploader_task, "upload", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
    vSimSetMallocFailedHandler(on_malloc_failed);
}
@@@ explanation_md
**Approach.** With `configUSE_MALLOC_FAILED_HOOK = 1`, heap_4 calls `vApplicationMallocFailedHook()` whenever `pvPortMalloc()` is about to return NULL. The hook runs synchronously, in the context of the task that called `pvPortMalloc()`, after the scheduler has been resumed. It is a good place to **record** the event (a counter, a DTC, a trace entry). It is a bad place to react: it does not know which caller failed or what that caller could do instead. The reaction belongs to the caller, which tests the returned pointer:

- drop the message, but keep the system alive;
- go into a degraded mode that sheds the expensive work (large messages) **before** touching the heap again;
- leave that mode only when there is real headroom (`RECOVER_BYTES`), so the mode does not flip on every message.

Two traps are tested on purpose. First, `pvPortMalloc(0)` returns NULL and fires the hook, so a zero-length heartbeat must never reach the allocator. Second, the order of the steps matters. The recovery check runs **before** each message, so a single oversized request that fails while plenty of heap is left (a 2000-byte message with 1024 bytes free) puts the uploader in degraded mode only until the next message: that one sees `free >= RECOVER_BYTES` and switches back to normal first. Shedding happens only while the heap really is short.

**Complexity.** Per message: one heap_4 allocation and one free, O(number of free blocks) each, plus O(len) for filling. The degraded path does no heap work at all. Extra RAM: one counter and one mode flag.

**Common mistakes**
- Calling `configASSERT(0)`, `for(;;);` or a reset in the hook. That is acceptable during start-up, but at run time it turns a recoverable condition into a watchdog reset.
- Printing, logging to flash or **allocating** inside the hook (recursion into the allocator).
- Using the buffer without checking for NULL: a hard fault on real hardware, an ASan report here.
- Allocating for zero-length messages, or allocating first and rejecting afterwards in degraded mode: that is extra heap churn exactly when memory is short.
- Forgetting `vPortFree()` on one of the paths: `heap after run: LEAK`.

**Interview follow-ups**
- Why do many safety projects allow `pvPortMalloc()` only during initialisation, and how do you enforce that (a flag checked in a wrapper, heap_1)?
- How would you use `xPortGetMinimumEverFreeHeapSize()` / `vPortGetHeapStats()` to size the heap from a field log?
- The heap has 3 KB free, but a 2 KB allocation fails. How is that possible, and how do memory pools avoid it?
- What else can fail with `errCOULD_NOT_ALLOCATE_REQUIRED_MEMORY` at run time (`xTaskCreate`, `xQueueCreate`, timer commands)?
