@@@ meta
id: RIS-M-02
topic: Interrupts & ISRs
difficulty: Medium
type: FUNCTION
title: UART RX ISR Into a Stream Buffer With Line Assembly
tags: freertos, isr, stream-buffer, uart, xstreambuffersendfromisr, line-parser, embedded
@@@ statement_md
A diagnostic UART receives AT-style commands, one byte per RX interrupt. The ISR must push each byte into a **stream buffer**, which is the cheapest FreeRTOS channel for a byte stream with one writer and one reader. A task reassembles the bytes into lines.

```c
void line_received(const char *line);  /* provided: task context, prints, then parses for P ticks */
void line_too_long(void);              /* provided: task context, prints */
void rx_overrun(void);                 /* provided: call from the ISR for every byte you drop */

void uart_rx_isr(char c);              /* you write: the RX-complete ISR */
void app_start(void);                  /* you write */
```

Rules:
- `app_start()` creates a stream buffer of **32 bytes with trigger level 1** (`xStreamBufferCreate(32, 1)`) and a line task with **priority 3**.
- `uart_rx_isr(c)` sends the single byte with `xStreamBufferSendFromISR()`. If it could not be stored (buffer full), call `rx_overrun()`. Yield with `portYIELD_FROM_ISR()` as needed.
- The line task loops: `xStreamBufferReceive(sb, buf, 16, portMAX_DELAY)` into a **16-byte local buffer**, processes **all** received bytes, then receives again. (The read size is fixed so that every correct solution frees buffer space at the same moments.)
- Line assembly:
  - `'\n'` ends a line. A non-empty line of at most **16 characters** is passed to `line_received()` as a NUL-terminated string. Empty lines are ignored.
  - A line that grows beyond 16 characters is **discarded**: drop all its bytes up to and including its `'\n'`, and call `line_too_long()` once, when that `'\n'` arrives.

**How it is tested.** Each input event is a tick and a string. Every character of the string is one RX interrupt at that tick, in order, and `|` stands for `'\n'`. All interrupts of one tick run before any task. `line_received()` prints `[t=<now>] line "<text>"` and then parses for `P` ticks (`vSimBusyWork(P)`). Bytes keep arriving meanwhile, so the 32-byte buffer can overflow. `line_too_long()` prints `[t=<now>] line too long, discarded`. The run includes tick `D`. Finally:

```
bytes=<interrupts> lines=<n> too_long=<n> overruns=<n>
```

**Input**
```
D P
N
<tick> <string>     (N lines, ticks non-decreasing, no spaces in strings)
```

**Example**
```
Input:
30 3
4
2 GO|
3 ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789|
4 END|
10 OK|

Output:
[t=2] line "GO"
[t=10] line too long, discarded
bytes=47 lines=1 too_long=1 overruns=9
```
At t=2 the task receives `GO\n`, reports it and parses during ticks 3-5. At t=3, 37 bytes arrive, but only 32 fit: `6789\n` is dropped. At t=4 the buffer is still full, so `END\n` is dropped too: 9 overruns. At t=5 the task reads the 32 bytes in two receives of 16. The line passes 16 characters, so the task switches to discarding. The `'\n'` that would have ended it was lost, so the discarded line only ends with the `'\n'` of `OK|` at t=10. That swallows `OK` as well. This is how a real overrun corrupts a text protocol.
@@@ constraints_md
- 1 <= D <= 20000, 0 <= P <= 5, 0 <= N <= 100, 1 <= tick <= D, total characters <= 2000. Strings use printable ASCII without spaces; `|` means newline.
- Stream buffer: 32 bytes, trigger level 1. Line task priority 3, receive size 16, maximum line length 16.
- Only `...FromISR()` APIs in the ISR.
@@@ starter_code
#include <stddef.h>
#include "FreeRTOS.h"
#include "task.h"
#include "stream_buffer.h"

void line_received(const char *line);   /* provided */
void line_too_long(void);               /* provided */
void rx_overrun(void);                  /* provided */

#define RX_BUF_SIZE   32
#define RX_CHUNK      16
#define MAX_LINE      16

static StreamBufferHandle_t s_rx;

static void line_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        /* TODO: receive up to RX_CHUNK bytes, assemble lines */
        vTaskDelay(1000);
    }
}

void uart_rx_isr(char c)
{
    /* TODO */
    (void)c;
}

void app_start(void)
{
    /* TODO: create the stream buffer and the line task (priority 3) */
    (void)s_rx;
    (void)line_task;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "stream_buffer.h"
#include "sim.h"

void uart_rx_isr(char c);
void app_start(void);
void line_received(const char *line);
void line_too_long(void);
void rx_overrun(void);

static unsigned g_bytes, g_lines, g_long, g_overruns, g_errors, g_cost;

void rx_overrun(void)
{
    if (!xPortIsInsideInterrupt()) {
        printf("FAIL: rx_overrun() must be called from the ISR\n");
        g_errors++;
        return;
    }
    g_overruns++;
}

void line_received(const char *line)
{
    size_t n;

    if (xPortIsInsideInterrupt()) {
        printf("FAIL: line_received() called from the ISR\n");
        g_errors++;
        return;
    }
    if (line == NULL) {
        printf("FAIL: line_received(NULL)\n");
        g_errors++;
        return;
    }
    n = strlen(line);
    if (n == 0 || n > 16) {
        printf("FAIL: line_received() with a line of length %zu\n", n);
        g_errors++;
        return;
    }
    printf("[t=%u] line \"%s\"\n", (unsigned)xTaskGetTickCount(), line);
    g_lines++;
    if (g_cost) vSimBusyWork((TickType_t)g_cost);
}

void line_too_long(void)
{
    if (xPortIsInsideInterrupt()) {
        printf("FAIL: line_too_long() called from the ISR\n");
        g_errors++;
        return;
    }
    printf("[t=%u] line too long, discarded\n", (unsigned)xTaskGetTickCount());
    g_long++;
}

/*USER_CODE*/

static char g_chars[2048];

static void irq_entry(void *arg)
{
    g_bytes++;
    uart_rx_isr(*(const char *)arg);
}

int main(void)
{
    unsigned d, n, i, t, used = 0;
    static char text[2100];
    size_t k;

    if (scanf("%u %u %u", &d, &g_cost, &n) != 3) return 1;
    app_start();
    for (i = 0; i < n; i++) {
        if (scanf("%u %2047s", &t, text) != 2) return 1;
        for (k = 0; text[k] != '\0'; k++) {
            if (used >= sizeof g_chars) return 1;
            g_chars[used] = text[k] == '|' ? '\n' : text[k];
            xSimScheduleInterrupt((TickType_t)t, irq_entry, &g_chars[used]);
            used++;
        }
    }
    vSimSetTickLimit((TickType_t)d);
    vTaskStartScheduler();
    printf("bytes=%u lines=%u too_long=%u overruns=%u\n", g_bytes, g_lines, g_long, g_overruns);
    if (g_errors) printf("ERRORS: %u\n", g_errors);
    return 0;
}
@@@ sample_input
30 3
4
2 GO|
3 ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789|
4 END|
10 OK|
@@@ sample_output
[t=2] line "GO"
[t=10] line too long, discarded
bytes=47 lines=1 too_long=1 overruns=9
@@@ sample_input
20 2
3
3 AT|
4 OK|ID|
15 x|
@@@ sample_output
[t=3] line "AT"
[t=5] line "OK"
[t=7] line "ID"
[t=15] line "x"
bytes=11 lines=4 too_long=0 overruns=0
@@@ hidden_input
50 1
0
@@@ hidden_output
bytes=0 lines=0 too_long=0 overruns=0
@@@ hidden_input
40 0
5
1 ||ABCDEFGHIJKLMNOP|
1 ABCDEFGHIJKLMNOPQ|
2 |V1|
2 partial
40 _END|
@@@ hidden_output
[t=1] line "ABCDEFGHIJKLMNOP"
[t=2] line "ABCDEFGHIJKLM"
[t=2] line "V1"
[t=40] line "partial_END"
bytes=53 lines=4 too_long=0 overruns=5

@@@ hidden_input
100 5
4
10 AT+RST|AT+GMR|AT+CWMODE=1|
11 AT+CWJAP="ssid","pw"|
12 AT|
60 AT+CIFSR|
@@@ hidden_output
[t=10] line "AT+RST"
[t=15] line "AT+GMR"
[t=20] line "AT+CWMODE=1"
[t=25] line too long, discarded
[t=60] line "AAT+CIFSR"
bytes=59 lines=4 too_long=1 overruns=2

@@@ hidden_input
30 4
3
5 0123456789abcdefghijklmnopqrstuv
6 wxyz|
30 L|
@@@ hidden_output
[t=6] line too long, discarded
[t=30] line "L"
bytes=39 lines=1 too_long=1 overruns=0

@@@ hidden_input
20000 2
6
1 A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|
2 S|T|
5000 one|two|
5001 three|
19999 last
20000 |
@@@ hidden_output
[t=1] line "A"
[t=3] line "B"
[t=5] line "C"
[t=7] line "D"
[t=9] line "E"
[t=11] line "F"
[t=13] line "G"
[t=15] line "H"
[t=17] line "I"
[t=19] line "J"
[t=21] line "K"
[t=23] line "L"
[t=25] line "M"
[t=27] line "N"
[t=29] line "O"
[t=31] line "P"
[t=33] line "S"
[t=35] line "T"
[t=5000] line "one"
[t=5002] line "two"
[t=5004] line "three"
[t=20000] line "last"
bytes=59 lines=22 too_long=0 overruns=4

@@@ hint
ISR: `BaseType_t woken = pdFALSE; if (xStreamBufferSendFromISR(s_rx, &c, 1, &woken) != 1) rx_overrun(); portYIELD_FROM_ISR(woken);`. The task keeps its line buffer (`char line[MAX_LINE + 1]`), the current length, and a `discarding` flag across receives.
@@@ hint
For each byte: on `'\n'`, if discarding call `line_too_long()` and clear the flag; else if the length is > 0, terminate and report; then reset the length. For any other byte: if discarding, skip it; if the length is already `MAX_LINE`, set discarding; otherwise append it.
@@@ solution_code
#include <stddef.h>
#include "FreeRTOS.h"
#include "task.h"
#include "stream_buffer.h"

void line_received(const char *line);   /* provided */
void line_too_long(void);               /* provided */
void rx_overrun(void);                  /* provided */

#define RX_BUF_SIZE   32
#define RX_CHUNK      16
#define MAX_LINE      16

static StreamBufferHandle_t s_rx;

static void line_task(void *pvParameters)
{
    char chunk[RX_CHUNK];
    char line[MAX_LINE + 1];
    size_t len = 0, got, i;
    int discarding = 0;

    (void)pvParameters;
    for (;;) {
        got = xStreamBufferReceive(s_rx, chunk, sizeof chunk, portMAX_DELAY);
        for (i = 0; i < got; i++) {
            char c = chunk[i];

            if (c == '\n') {
                if (discarding) {
                    line_too_long();
                    discarding = 0;
                } else if (len > 0) {
                    line[len] = '\0';
                    line_received(line);
                }
                len = 0;
            } else if (!discarding) {
                if (len == MAX_LINE) {
                    discarding = 1;       /* 17th character: drop the whole line */
                } else {
                    line[len++] = c;
                }
            }
        }
    }
}

void uart_rx_isr(char c)
{
    BaseType_t woken = pdFALSE;

    /* single writer (this ISR) + single reader (line_task): no lock needed */
    if (xStreamBufferSendFromISR(s_rx, &c, 1, &woken) != 1) {
        rx_overrun();
    }
    portYIELD_FROM_ISR(woken);
}

void app_start(void)
{
    s_rx = xStreamBufferCreate(RX_BUF_SIZE, 1);   /* wake the reader on the first byte */
    configASSERT(s_rx != NULL);
    xTaskCreate(line_task, "uart", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
}
@@@ explanation_md
**Approach.** A stream buffer is a lock-free byte ring with one built-in reader-notification. It is cheaper than a queue of single bytes: no per-item list handling, and the reader gets many bytes per wake-up. The ISR stores one byte and never blocks: a return value of 0 means the buffer is full, and the byte is counted as an overrun. With trigger level 1, the blocked reader wakes on the first byte. `woken` plus `portYIELD_FROM_ISR()` let it run in the same tick.

The task is a small state machine that survives chunk boundaries: a line buffer, its length, and a `discarding` flag. An over-long line must be dropped completely, not truncated. Otherwise its tail would be read as the start of a new command. The flag stays set until the next `'\n'`. The example also shows the nasty consequence of a lost `'\n'`: two commands merge, and the next good command (`OK`) is swallowed.

**Complexity.** ISR: O(1) per byte (a memcpy of 1 byte plus index updates). Task: O(1) per byte, O(P) ticks per line. RAM: 32 + 1 bytes of ring storage plus the control block, a 16-byte chunk and a 17-byte line buffer on the task stack. Sizing: the ring must hold all bytes that arrive while one line is being parsed (`baud rate x parse time`).

**Common mistakes**
- Using a stream buffer with **two writers** (two ISRs, or an ISR and a task) without a lock: stream buffers are only safe for one writer and one reader.
- Ignoring the return value of `xStreamBufferSendFromISR()`: overruns go unnoticed.
- Resetting the line state at every receive: a line split across two chunks gets cut in two.
- Truncating an over-long line instead of discarding it until the next newline.
- Using `xStreamBufferSend()` in the ISR (Runtime Error), or a trigger level larger than 1 (the reader then waits for several bytes and a short command stays stuck).

**Interview follow-ups**
- At 115200 baud, how long can the parser block before a 32-byte buffer overflows? How would you size it?
- How would you replace the per-byte interrupt with DMA plus the UART idle-line interrupt?
- Why can a stream buffer skip internal critical sections on the single-reader/single-writer path, while a queue cannot?
- What changes if two UARTs feed the same parser task (message buffers, a queue set, or a mutex around the writer)?
