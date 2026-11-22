@@@ meta
id: RDS-E-01
topic: RTOS Design Patterns
difficulty: Easy
type: FUNCTION
title: Gatekeeper Task Owning A Shared UART
tags: freertos, gatekeeper, xqueuesend, resource-ownership, embedded
@@@ statement_md
Several tasks of an ECU write diagnostic lines to **one** debug UART. If two tasks write at the same time, their characters interleave. Instead of a mutex, use the **gatekeeper pattern**: exactly one task owns the UART, and every other task sends it a message through a queue.

```c
typedef struct {
    const char *name;      /* client name, e.g. "ENG" (at most 8 chars) */
    TickType_t  period;    /* ticks between two messages */
    UBaseType_t priority;  /* 2..6, all different */
} ClientCfg;

/* provided by the judge */
void uart_write(const char *line); /* prints "[t=<tick>] <line>", then the transmission keeps the
                                      CPU busy for tx ticks. Only the task named "GK" may call it. */
void log_drop(const char *name);   /* prints "[t=<tick>] DROP <name>" */

void app_start(const ClientCfg *cfg, int n);   /* you write this (and the tasks) */
```

`app_start()` is called before the scheduler starts. It must create:

- **The gatekeeper**: a task named exactly `"GK"`, priority **1**, that owns a queue of **4** messages. It loops forever: block on the queue, then pass the message text to `uart_write()`.
- **One client task per entry** of `cfg`, with the entry's priority. A client loops forever:
  1. `vTaskDelay(period)`,
  2. build the text `"<name> #<k>"`, where `k` = 1, 2, 3, ... counts the messages this client has **produced** (dropped ones included),
  3. send it to the gatekeeper queue **without blocking** (timeout 0). If the queue is full, call `log_drop(name)`.

A client must never wait for the slow UART: that is the point of the pattern. `printf`, `puts`, `putchar`, `fputs`, `fprintf` and `fwrite` are not available to your code; `snprintf` is.

**How it is tested.** The hidden `main()` reads the clients, the UART transmission time `tx` and a duration `D`, calls `app_start()`, and runs the scheduler up to tick `D`. It checks that `uart_write()` is only called by `GK` and never re-entered, and then prints, for every client in input order, how many of its lines were printed and how many were dropped, plus the total number of UART lines.

Clients have higher priorities than the gatekeeper. When several clients wake at the same tick, they run in priority order (highest first) and all of them queue their message **before** the gatekeeper prints anything. A client that wakes while the gatekeeper is transmitting preempts it.

**Input**
```
<n> <tx> <D>
<name> <period> <priority>     (n lines)
```

**Example**
```
Input:
2 2 55
A 10 3
B 15 2

Output:
[t=10] A #1
[t=15] B #1
[t=20] A #2
[t=30] A #3
[t=32] B #2
[t=40] A #4
[t=45] B #3
[t=50] A #5
A: printed=5 dropped=0
B: printed=3 dropped=0
uart lines=8
```
At t=30 both clients wake. A (priority 3) queues `A #3`, then B queues `B #2`, then the gatekeeper runs. It transmits `A #3` from t=30 to t=32, so `B #2` starts at t=32.
@@@ constraints_md
- 1 <= n <= 5, 0 <= tx <= 20, 1 <= period <= 200, 1 <= D <= 5000.
- Client priorities are distinct and in 2..6. Gatekeeper: name `"GK"`, priority 1, queue length 4, message = the text (at most 31 chars + NUL).
- Stack size `configMINIMAL_STACK_SIZE` for every task. The `cfg` array stays valid for the whole run.
- Simulated time: 1 tick = 1 ms. Code between two blocking calls takes zero ticks; only `uart_write()` consumes CPU time.
@@@ starter_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    const char *name;
    TickType_t  period;
    UBaseType_t priority;
} ClientCfg;

void uart_write(const char *line);
void log_drop(const char *name);

typedef struct {
    char text[32];
} LogMsg;

static void gatekeeper_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: receive a LogMsg and pass its text to uart_write() */
        vTaskDelay(1000);
    }
}

static void client_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: delay, build "<name> #<k>", send to the gatekeeper without blocking */
        vTaskDelay(1000);
    }
}

void app_start(const ClientCfg *cfg, int n)
{
    /* TODO: create the queue, the gatekeeper "GK" (priority 1) and one client per entry */
    (void)cfg;
    (void)n;
    (void)gatekeeper_task;
    (void)client_task;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

static TickType_t g_tx;
static int g_n;
static char g_names[5][16];
static unsigned g_printed[5], g_dropped[5], g_lines;
static int g_busy;

static int client_index(const char *s)
{
    int i;
    for (i = 0; i < g_n; i++) {
        size_t len = strlen(g_names[i]);
        if (strncmp(s, g_names[i], len) == 0 && (s[len] == ' ' || s[len] == '\0')) return i;
    }
    return -1;
}

void uart_write(const char *line)
{
    const char *who = pcTaskGetName(NULL);
    int i;

    if (strcmp(who, "GK") != 0) {
        printf("FAIL: uart_write() called from task \"%s\"\n", who);
        return;
    }
    if (g_busy) {
        printf("FAIL: UART collision\n");
        return;
    }
    g_busy = 1;
    printf("[t=%u] %s\n", (unsigned)xTaskGetTickCount(), line);
    g_lines++;
    i = client_index(line);
    if (i >= 0) g_printed[i]++;
    vSimBusyWork(g_tx);
    g_busy = 0;
}

void log_drop(const char *name)
{
    int i = client_index(name);
    printf("[t=%u] DROP %s\n", (unsigned)xTaskGetTickCount(), name);
    if (i >= 0) g_dropped[i]++;
}

/* only the gatekeeper talks to the UART */
#define printf(...)  printf_is_not_allowed_use_the_gatekeeper
#define puts(s)      puts_is_not_allowed_use_the_gatekeeper
#define putchar(c)   putchar_is_not_allowed_use_the_gatekeeper
#define fputs(...)   fputs_is_not_allowed_use_the_gatekeeper
#define fprintf(...) fprintf_is_not_allowed_use_the_gatekeeper
#define fwrite(...)  fwrite_is_not_allowed_use_the_gatekeeper

/*USER_CODE*/

#undef printf
#undef puts
#undef putchar
#undef fputs
#undef fprintf
#undef fwrite

int main(void)
{
    static ClientCfg cfg[5];
    unsigned tx, dur, period, prio;
    int i;

    if (scanf("%d %u %u", &g_n, &tx, &dur) != 3 || g_n < 1 || g_n > 5) return 1;
    g_tx = (TickType_t)tx;
    for (i = 0; i < g_n; i++) {
        if (scanf("%15s %u %u", g_names[i], &period, &prio) != 3) return 1;
        cfg[i].name = g_names[i];
        cfg[i].period = (TickType_t)period;
        cfg[i].priority = (UBaseType_t)prio;
    }

    app_start(cfg, g_n);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    for (i = 0; i < g_n; i++)
        printf("%s: printed=%u dropped=%u\n", g_names[i], g_printed[i], g_dropped[i]);
    printf("uart lines=%u\n", g_lines);
    return 0;
}
@@@ sample_input
2 2 55
A 10 3
B 15 2
@@@ sample_output
[t=10] A #1
[t=15] B #1
[t=20] A #2
[t=30] A #3
[t=32] B #2
[t=40] A #4
[t=45] B #3
[t=50] A #5
A: printed=5 dropped=0
B: printed=3 dropped=0
uart lines=8
@@@ sample_input
3 3 21
X 4 4
Y 4 3
Z 4 2
@@@ sample_output
[t=4] X #1
[t=7] Y #1
[t=10] Z #1
[t=12] DROP Y
[t=12] DROP Z
[t=13] X #2
[t=16] DROP Y
[t=16] DROP Z
[t=16] Y #2
[t=19] Z #2
[t=20] DROP Z
X: printed=2 dropped=0
Y: printed=2 dropped=2
Z: printed=2 dropped=3
uart lines=6
@@@ hidden_input
1 0 10
SOLO 20 6
@@@ hidden_output
SOLO: printed=0 dropped=0
uart lines=0
@@@ hidden_input
1 0 5
ONE 1 4
@@@ hidden_output
[t=1] ONE #1
[t=2] ONE #2
[t=3] ONE #3
[t=4] ONE #4
[t=5] ONE #5
ONE: printed=5 dropped=0
uart lines=5
@@@ hidden_input
5 1 3
P 1 2
Q 1 3
R 1 4
S 1 5
T 1 6
@@@ hidden_output
[t=1] DROP P
[t=1] T #1
[t=2] DROP S
[t=2] DROP R
[t=2] DROP Q
[t=2] DROP P
[t=2] S #1
[t=3] DROP S
[t=3] DROP R
[t=3] DROP Q
[t=3] DROP P
[t=3] R #1
P: printed=0 dropped=3
Q: printed=0 dropped=2
R: printed=1 dropped=2
S: printed=1 dropped=2
T: printed=1 dropped=0
uart lines=3

@@@ hidden_input
2 5 100
ENG 7 2
BRK 11 5
@@@ hidden_output
[t=7] ENG #1
[t=12] BRK #1
[t=17] ENG #2
[t=22] ENG #3
[t=27] BRK #2
[t=32] ENG #4
[t=37] BRK #3
[t=42] ENG #5
[t=47] ENG #6
[t=52] BRK #4
[t=57] ENG #7
[t=62] BRK #5
[t=67] ENG #8
[t=72] ENG #9
[t=77] BRK #6
[t=82] ENG #10
[t=87] BRK #7
[t=92] ENG #11
[t=97] ENG #12
ENG: printed=12 dropped=0
BRK: printed=7 dropped=0
uart lines=19

@@@ hidden_input
3 20 200
LOW 30 2
MID 25 3
HIGH 10 6
@@@ hidden_output
[t=10] HIGH #1
[t=30] HIGH #2
[t=50] DROP HIGH
[t=50] DROP MID
[t=50] MID #1
[t=60] DROP LOW
[t=70] DROP HIGH
[t=70] HIGH #3
[t=80] DROP HIGH
[t=90] DROP HIGH
[t=90] DROP LOW
[t=90] LOW #1
[t=100] DROP MID
[t=110] DROP HIGH
[t=110] HIGH #4
[t=120] DROP LOW
[t=125] DROP MID
[t=130] DROP HIGH
[t=130] HIGH #6
[t=150] DROP HIGH
[t=150] DROP MID
[t=150] DROP LOW
[t=150] MID #3
[t=170] DROP HIGH
[t=170] HIGH #10
[t=180] DROP HIGH
[t=180] DROP LOW
[t=190] DROP HIGH
[t=190] HIGH #12
[t=200] DROP MID
LOW: printed=1 dropped=5
MID: printed=2 dropped=5
HIGH: printed=7 dropped=10
uart lines=10

@@@ hidden_input
2 4 61
A 6 5
B 6 4
@@@ hidden_output
[t=6] A #1
[t=10] B #1
[t=14] A #2
[t=18] B #2
[t=22] A #3
[t=26] B #3
[t=30] A #4
[t=34] B #4
[t=38] A #5
[t=42] DROP B
[t=42] B #5
[t=46] A #6
[t=50] B #6
[t=54] DROP B
[t=54] A #7
[t=58] A #8
A: printed=8 dropped=0
B: printed=6 dropped=2
uart lines=14

@@@ hint
Create the queue **before** any task that uses it (in `app_start()`), as a file-scope `static QueueHandle_t`. The message type can simply be a `char text[32]` buffer: queues copy by value, so the client's local buffer can be reused right after `xQueueSend()` returns.
@@@ hint
Client: `snprintf(m.text, sizeof m.text, "%s #%u", c->name, ++k); if (xQueueSend(q, &m, 0) != pdPASS) log_drop(c->name);`. Gatekeeper: `xQueueReceive(q, &m, portMAX_DELAY); uart_write(m.text);`. Pass each client its `ClientCfg` through `pvParameters`.
@@@ solution_code
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    const char *name;
    TickType_t  period;
    UBaseType_t priority;
} ClientCfg;

void uart_write(const char *line);
void log_drop(const char *name);

typedef struct {
    char text[32];
} LogMsg;

static QueueHandle_t s_uart_q;

/* The only task that ever touches the UART: no mutex needed, no interleaving possible. */
static void gatekeeper_task(void *pvParameters)
{
    LogMsg m;

    (void)pvParameters;
    for (;;) {
        if (xQueueReceive(s_uart_q, &m, portMAX_DELAY) == pdPASS) {
            uart_write(m.text);
        }
    }
}

static void client_task(void *pvParameters)
{
    const ClientCfg *c = (const ClientCfg *)pvParameters;
    unsigned k = 0;
    LogMsg m;

    for (;;) {
        vTaskDelay(c->period);
        snprintf(m.text, sizeof m.text, "%s #%u", c->name, ++k);
        /* never wait for the slow UART: drop and count instead */
        if (xQueueSend(s_uart_q, &m, 0) != pdPASS) {
            log_drop(c->name);
        }
    }
}

void app_start(const ClientCfg *cfg, int n)
{
    int i;

    s_uart_q = xQueueCreate(4, sizeof(LogMsg));
    xTaskCreate(gatekeeper_task, "GK", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    for (i = 0; i < n; i++) {
        xTaskCreate(client_task, cfg[i].name, configMINIMAL_STACK_SIZE,
                    (void *)&cfg[i], cfg[i].priority, NULL);
    }
}
@@@ explanation_md
**Approach.** The gatekeeper is the **only owner** of the UART. Other tasks never touch the peripheral: they copy their text into a queue message and continue. Because exactly one task calls `uart_write()`, lines can never interleave, and no mutex is needed. That also removes priority inversion and deadlock risks around the peripheral.

The gatekeeper has the **lowest** application priority. Clients therefore post their message and return to their real work at once, and the UART is drained in the background in FIFO order. In the example at t=30, both clients queue first (A, then B, by priority), and only then does the gatekeeper start transmitting. When the queue is full, a client drops the line and counts it (sample 2) instead of blocking. A blocking client would inherit the UART's speed, which defeats the pattern.

**Complexity.** Per line: one queue copy in (32 bytes) and one out, O(1). RAM: 4 x 32 bytes of queue storage plus the gatekeeper's TCB and stack. Worst-case wait of a client: zero, because it never blocks on the UART. Worst-case latency of a line: (queue depth + 1) x tx ticks, plus preemption by clients.

**Common mistakes**
- Sending with `portMAX_DELAY`: the client then runs at the UART's speed and misses its own period whenever the queue is full.
- Putting a `char *` in the queue instead of the text: the client's buffer is overwritten by its next message before the gatekeeper prints it.
- Giving the gatekeeper a **higher** priority than the clients. Every line is then transmitted inside the client's time slot, and the clients are delayed by the UART.
- Creating the queue after the tasks, or inside the gatekeeper task: a higher-priority client may use a NULL handle.
- Calling `uart_write()` directly from a client "just for one line". The judge prints `FAIL`.

**Interview follow-ups**
- Gatekeeper vs mutex around the UART: what are the trade-offs (latency, priority inversion, RAM)?
- How would an ISR log through the gatekeeper (`xQueueSendFromISR` + `portYIELD_FROM_ISR`)?
- How would you avoid copying 32 bytes per message (a pool of buffers + queue of indexes, or a stream buffer)?
- The UART has a DMA: how does the gatekeeper wait for "transmission complete" without polling (task notification from the DMA ISR)?
