@@@ meta
id: RMM-M-03
topic: RTOS Memory Management
difficulty: Medium
type: FUNCTION
title: Variable-Length UART Frames Through A Message Buffer
tags: freertos, message-buffer, xmessagebuffersendfromisr, isr, variable-length, embedded, asked-in-automotive
@@@ statement_md
A diagnostic UART delivers frames of **1 to 64 bytes**. Sending them through a queue of 64-byte items would waste RAM on every short frame. A FreeRTOS **message buffer** stores each message as a length followed by exactly its bytes. Pass the frames from the receive ISR to a processing task through a message buffer.

```c
#define MB_MAX_FRAME 64

typedef struct {
    size_t  len;
    uint8_t data[80];
} Frame;

extern MessageBufferHandle_t g_rx_mb;              /* defined by the harness, created by you */

void frame_received(const uint8_t *data, size_t len); /* provided: prints + processes one frame */

/* you write these */
void     app_start(size_t mb_bytes);
void     uart_frame_isr(void *arg);                /* arg is a const Frame * */
unsigned frames_dropped(void);
unsigned frames_invalid(void);
```

- **`app_start(mb_bytes)`**, called before the scheduler starts: create `g_rx_mb` with a capacity of `mb_bytes` bytes (`xMessageBufferCreate` or `...CreateStatic`), and the **receiver task** at **priority 3**.
- **`uart_frame_isr(arg)`** runs in **interrupt context**, once per frame. If `len` is 0 or greater than `MB_MAX_FRAME`, count the frame as **invalid** and write nothing. Otherwise write it with `xMessageBufferSendFromISR()`. If it does not fit, the call returns 0: count the frame as **dropped**. End with `portYIELD_FROM_ISR()`.
- **The receiver task** loops forever: `xMessageBufferReceive()` into a local buffer of `MB_MAX_FRAME` bytes (wait forever), then `frame_received(buf, n)` for every message.
- `frames_dropped()` / `frames_invalid()` return the two counters.

Each message takes **`len + sizeof(size_t)`** bytes in the buffer: here `configMESSAGE_BUFFER_LENGTH_TYPE` is `size_t`, so the length prefix is 8 bytes. A 64-byte buffer therefore holds two 20-byte frames (2 × 28 = 56) but not three. A 64-byte frame (72 bytes) never fits.

Queues (`xQueueCreate`, `xQueueGenericCreate`) are not allowed.

**How it is tested.** The harness checks that `g_rx_mb` exists and has `mb_bytes` bytes free. Then it schedules one interrupt per input frame (several frames at one tick run back-to-back in input order, before any task runs) and runs up to and including tick `D`. `frame_received()` checks the bytes, prints `[t=<tick>] rx id=<data[0]> len=<n>`, and then simulates `P` ticks of processing with `vSimBusyWork(P)`. Interrupts keep arriving during that time. Frame bytes are `data[i] = id + i`. At the end it prints `received <r>, dropped <frames_dropped()>, invalid <frames_invalid()>, pending <bytes still in the buffer>`.

**Input**
```
<mb_bytes> <P>
<n>
<tick> <len> <id>      (n lines, non-decreasing ticks)
<D>
```

**Example**
```
Input:
64 5
7
1 20 1
2 20 2
3 20 3
4 20 4
20 0 5
21 70 6
22 64 7
30

Output:
message buffer: 64 bytes free
[t=1] rx id=1 len=20
[t=6] rx id=2 len=20
[t=11] rx id=3 len=20
received 3, dropped 2, invalid 2, pending 0
```
Frame 1 wakes the receiver at t=1, which then processes it until t=6. Meanwhile frames 2 and 3 fill 56 of the 64 bytes, and frame 4 (28 bytes) is dropped. Frames 5 (empty) and 6 (70 bytes) are invalid. Frame 7 is valid but needs 72 bytes, so it is dropped.
@@@ constraints_md
- 16 <= mb_bytes <= 1024, 0 <= P <= 50, 0 <= n <= 40, 1 <= tick <= 5000, 0 <= len <= 80, 0 <= id <= 255, D <= 10000.
- The ISR must use only `...FromISR()` APIs; the receiver must block (no polling).
@@@ starter_code
#include <stdint.h>
#include <stddef.h>
#include "FreeRTOS.h"
#include "task.h"
#include "message_buffer.h"

#define MB_MAX_FRAME 64

typedef struct {
    size_t  len;
    uint8_t data[80];
} Frame;

extern MessageBufferHandle_t g_rx_mb;

void frame_received(const uint8_t *data, size_t len);

static void rx_task(void *pv)
{
    (void)pv;
    for (;;) {
        /* TODO: xMessageBufferReceive(...) then frame_received(...) */
        vTaskDelay(1000);
    }
}

void app_start(size_t mb_bytes)
{
    /* TODO: create g_rx_mb and the receiver task (priority 3) */
    (void)mb_bytes;
    (void)rx_task;
}

void uart_frame_isr(void *arg)
{
    /* TODO */
    (void)arg;
}

unsigned frames_dropped(void) { return 0; }
unsigned frames_invalid(void) { return 0; }
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "message_buffer.h"
#include "sim.h"

MessageBufferHandle_t g_rx_mb;

static unsigned g_received;
static TickType_t g_proc;

void frame_received(const uint8_t *data, size_t len)
{
    size_t i;
    for (i = 0; i < len; i++) {
        if (data[i] != (uint8_t)(data[0] + i)) {
            printf("[t=%u] CORRUPT frame\n", (unsigned)xTaskGetTickCount());
            return;
        }
    }
    printf("[t=%u] rx id=%u len=%u\n", (unsigned)xTaskGetTickCount(), (unsigned)(len ? data[0] : 0),
           (unsigned)len);
    g_received++;
    if (g_proc > 0) vSimBusyWork(g_proc);
}

#undef xQueueCreate
#define xQueueCreate(...) xQueueCreate_is_not_allowed_here
#define xQueueGenericCreate(...) xQueueGenericCreate_is_not_allowed_here

/*USER_CODE*/

#define MAX_FRAMES 40

static Frame g_frames[MAX_FRAMES];

int main(void)
{
    unsigned mb_bytes, proc, tick, len, id, dur;
    int n, i;
    size_t k;

    if (scanf("%u %u %d", &mb_bytes, &proc, &n) != 3 || n < 0 || n > MAX_FRAMES) return 1;
    g_proc = (TickType_t)proc;

    app_start(mb_bytes);
    if (g_rx_mb == NULL) {
        printf("FAIL: g_rx_mb was not created\n");
        return 0;
    }
    printf("message buffer: %u bytes free\n", (unsigned)xMessageBufferSpacesAvailable(g_rx_mb));

    for (i = 0; i < n; i++) {
        if (scanf("%u %u %u", &tick, &len, &id) != 3 || len > 80) return 1;
        g_frames[i].len = len;
        for (k = 0; k < len; k++) g_frames[i].data[k] = (uint8_t)(id + k);
        xSimScheduleInterrupt((TickType_t)tick, uart_frame_isr, &g_frames[i]);
    }
    if (scanf("%u", &dur) != 1) return 1;

    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    printf("received %u, dropped %u, invalid %u, pending %u\n", g_received, frames_dropped(),
           frames_invalid(), (unsigned)(mb_bytes - xMessageBufferSpacesAvailable(g_rx_mb)));
    return 0;
}
@@@ sample_input
64 5
7
1 20 1
2 20 2
3 20 3
4 20 4
20 0 5
21 70 6
22 64 7
30
@@@ sample_output
message buffer: 64 bytes free
[t=1] rx id=1 len=20
[t=6] rx id=2 len=20
[t=11] rx id=3 len=20
received 3, dropped 2, invalid 2, pending 0
@@@ sample_input
100 0
4
5 1 10
5 64 20
5 2 30
6 65 40
10
@@@ sample_output
message buffer: 100 bytes free
[t=5] rx id=10 len=1
[t=5] rx id=20 len=64
[t=5] rx id=30 len=2
received 3, dropped 0, invalid 1, pending 0
@@@ hidden_input
32 1
0
50
@@@ hidden_output
message buffer: 32 bytes free
received 0, dropped 0, invalid 0, pending 0
@@@ hidden_input
32 10
5
1 24 1
2 1 2
3 24 3
12 1 4
13 1 5
15
@@@ hidden_output
message buffer: 32 bytes free
[t=1] rx id=1 len=24
[t=11] rx id=2 len=1
received 2, dropped 1, invalid 0, pending 18

@@@ hidden_input
1024 3
8
10 64 1
10 64 2
10 64 3
10 64 4
10 64 5
10 64 6
10 64 7
10 64 8
40
@@@ hidden_output
message buffer: 1024 bytes free
[t=10] rx id=1 len=64
[t=13] rx id=2 len=64
[t=16] rx id=3 len=64
[t=19] rx id=4 len=64
[t=22] rx id=5 len=64
[t=25] rx id=6 len=64
[t=28] rx id=7 len=64
[t=31] rx id=8 len=64
received 8, dropped 0, invalid 0, pending 0

@@@ hidden_input
200 20
6
1 0 1
1 80 2
1 50 3
2 50 4
3 50 5
4 50 6
100
@@@ hidden_output
message buffer: 200 bytes free
[t=1] rx id=3 len=50
[t=21] rx id=4 len=50
[t=41] rx id=5 len=50
[t=61] rx id=6 len=50
received 4, dropped 0, invalid 2, pending 0

@@@ hidden_input
16 2
4
1 8 7
1 8 8
2 9 9
4 7 250
10
@@@ hidden_output
message buffer: 16 bytes free
[t=1] rx id=7 len=8
[t=4] rx id=250 len=7
received 2, dropped 2, invalid 0, pending 0

@@@ hint
Message buffers are designed for exactly one writer and one reader, so no lock is needed between this ISR and this task. In the ISR, `xMessageBufferSendFromISR(g_rx_mb, f->data, f->len, &woken)` returns the number of bytes written: 0 means "no room for the whole message". It never writes part of a message.
@@@ hint
Validate **before** writing. A 0-byte message cannot be told apart on the receive side, because `xMessageBufferReceive()` also returns 0 on timeout. A message longer than the receiver's buffer is never delivered: the receive returns 0 and leaves it in the buffer forever. Then `portYIELD_FROM_ISR(woken)`.
@@@ solution_code
#include <stdint.h>
#include <stddef.h>
#include "FreeRTOS.h"
#include "task.h"
#include "message_buffer.h"

#define MB_MAX_FRAME 64

typedef struct {
    size_t  len;
    uint8_t data[80];
} Frame;

extern MessageBufferHandle_t g_rx_mb;

void frame_received(const uint8_t *data, size_t len);

static volatile unsigned s_dropped, s_invalid;

static void rx_task(void *pv)
{
    uint8_t buf[MB_MAX_FRAME];
    size_t n;
    (void)pv;

    for (;;) {
        n = xMessageBufferReceive(g_rx_mb, buf, sizeof buf, portMAX_DELAY);
        if (n > 0) {
            frame_received(buf, n);
        }
    }
}

void app_start(size_t mb_bytes)
{
    g_rx_mb = xMessageBufferCreate(mb_bytes);
    xTaskCreate(rx_task, "rx", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
}

void uart_frame_isr(void *arg)
{
    const Frame *f = (const Frame *)arg;
    BaseType_t woken = pdFALSE;

    if (f->len == 0 || f->len > MB_MAX_FRAME) {
        s_invalid++;                       /* never write what the reader cannot take */
    } else if (xMessageBufferSendFromISR(g_rx_mb, f->data, f->len, &woken) != f->len) {
        s_dropped++;                       /* not enough room for len + length prefix */
    }
    portYIELD_FROM_ISR(woken);
}

unsigned frames_dropped(void) { return s_dropped; }
unsigned frames_invalid(void) { return s_invalid; }
@@@ explanation_md
**Approach.** A message buffer is a stream buffer that writes a length prefix (`configMESSAGE_BUFFER_LENGTH_TYPE`, here `size_t`) in front of each message. It always delivers whole messages. The ISR is the only writer and the receiver task the only reader, which is the case message buffers are built for: no mutex and no critical section in the application. The ISR validates the length, writes with `xMessageBufferSendFromISR()`, counts a 0 return as a drop, and yields so the receiver runs at the same tick when it was waiting.

Memory is the point of this exercise. A queue of 64-byte items needs `64 * depth` bytes even if most frames are 2 bytes long. The message buffer needs `len + 8` per frame actually stored, so the same RAM absorbs far longer bursts of short frames. The cost is the 8-byte prefix and a copy into and out of the buffer.

**Complexity.** Send and receive are O(len) (two `memcpy`s, plus the prefix). RAM: `mb_bytes` of storage (the kernel allocates one extra byte internally) + the control block + the receiver's `MB_MAX_FRAME` local buffer. Worst-case latency for a frame is the processing time of the frames queued in front of it.

**Common mistakes**
- Writing 0-length messages. On the reader side, `xMessageBufferReceive()` returning 0 means "timeout" or "message too big for your buffer", so an empty frame is indistinguishable from nothing.
- Receiving into a buffer smaller than the largest message that can be written: that message blocks the buffer forever (the receive keeps returning 0).
- Forgetting the length prefix when sizing the buffer: "64 bytes is enough for one 64-byte frame" is wrong (72 needed).
- Using `xMessageBufferSend()` in the ISR (Runtime Error here, a hard fault or assert on target), or forgetting `portYIELD_FROM_ISR()` so the receiver only runs one tick later.
- Two ISRs (or two tasks) writing to the same message buffer without a lock: message buffers are single-writer / single-reader.

**Interview follow-ups**
- When do you prefer a stream buffer (byte stream, trigger level) over a message buffer (framed messages)?
- How would you make the ISR zero-copy (write directly into a block from a pool and pass a pointer through a queue)?
- How do you size the buffer for a worst-case burst of N frames at a given processing time?
- Message buffers use task notifications internally. What restriction does that put on the receiving task's own use of notifications (`configMESSAGE_BUFFER...`, notification index)?
