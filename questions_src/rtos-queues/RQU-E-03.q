@@@ meta
id: RQU-E-03
topic: Queues
difficulty: Easy
type: FUNCTION
title: Queue of Sensor Structs With Per-Channel Min/Max Aggregation
tags: freertos, queue, struct, copy-semantics, aggregation, embedded
@@@ statement_md
A battery-management ECU scans `nch` cell-temperature channels every `period` ticks. An acquisition task packs every reading into a small struct and queues it. A lower-priority statistics task keeps **per-channel** count, sum, min and max. Write both tasks.

```c
typedef struct {
    uint8_t  channel;   /* 0 .. nch-1 */
    int16_t  value;     /* temperature reading */
    uint32_t seq;       /* global sequence number 1, 2, 3, ... */
} SensorMsg;

typedef struct {
    uint32_t count;
    int32_t  sum;
    int16_t  min;
    int16_t  max;
} ChannelStats;

void read_channel(uint8_t ch, SensorMsg *out);   /* provided: fills all three fields */
void on_message(const SensorMsg *m);             /* provided: prints "[t=<tick>] ch<c> #<seq> <value>" */

void app_start(uint8_t nch, TickType_t period);  /* you write this */
const ChannelStats *app_stats(void);             /* you write this: array of nch entries */
```

Requirements:

- Create **one queue of 8 items of type `SensorMsg`**. The items are the structs themselves, **not pointers**.
- **Acquisition task**, priority **3**. Forever: `vTaskDelay(period)`, then for `ch = 0 .. nch-1`: fill **one local `SensorMsg` variable** with `read_channel(ch, &msg)` and send it with `xQueueSend(..., portMAX_DELAY)`. The same local variable is reused for every channel.
- **Statistics task**, priority **2**. Forever: receive one `SensorMsg` (block with `portMAX_DELAY`), call `on_message(&msg)`, then update the stats of `msg.channel`. `min`/`max` must be the real extremes of the received values, even if every value is negative or every value is positive.

Since the acquisition task has the higher priority, it queues a whole scan (at most 8 messages) before the statistics task runs.

**How it is tested.** The hidden `main()` reads `nch`, `period`, two generator parameters and a duration `D`. It calls `app_start()` and runs the scheduler up to and including tick `D`. `on_message()` checks every message against what `read_channel()` produced and prints `CORRUPT` on a mismatch. At the end the harness prints `app_stats()` for every channel: `ch<c>: n=<count> min=<min> max=<max> sum=<sum>`, or `ch<c>: no data` when `count == 0`.

**Input**
```
<nch> <period> <mul> <off> <D>
```
The harness generates the reading with sequence number `s` on channel `c` as `(s*mul + c*11) % 201 - off`.

**Example**
```
Input:
2 10 37 100 20

Output:
[t=10] ch0 #1 -63
[t=10] ch1 #2 -15
[t=20] ch0 #3 11
[t=20] ch1 #4 59
ch0: n=2 min=-63 max=11 sum=-52
ch1: n=2 min=-15 max=59 sum=44
```
At t=10 the acquisition task (priority 3) queues both channels, then sleeps. Only then the statistics task (priority 2) receives and prints them, in FIFO order.
@@@ constraints_md
- 1 <= nch <= 8, 1 <= period <= 1000, 1 <= mul <= 1000, 0 <= off <= 300, 1 <= D <= 20000.
- Queue: length 8, item size `sizeof(SensorMsg)`. Two tasks, stack `configMINIMAL_STACK_SIZE`, priorities 3 and 2.
- Only the statistics task touches the `ChannelStats` array while the scheduler runs.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    uint8_t  channel;
    int16_t  value;
    uint32_t seq;
} SensorMsg;

typedef struct {
    uint32_t count;
    int32_t  sum;
    int16_t  min;
    int16_t  max;
} ChannelStats;

void read_channel(uint8_t ch, SensorMsg *out);
void on_message(const SensorMsg *m);

static ChannelStats s_stats[8];

static void acq_task(void *pvParameters)
{
    /* TODO: forever: vTaskDelay(period); for each channel: read_channel + xQueueSend */
    (void)pvParameters;
    for (;;) {
        vTaskDelay(1000);
    }
}

static void stats_task(void *pvParameters)
{
    /* TODO: forever: receive a SensorMsg, on_message(&msg), update s_stats[msg.channel] */
    (void)pvParameters;
    for (;;) {
        vTaskDelay(1000);
    }
}

void app_start(uint8_t nch, TickType_t period)
{
    /* TODO: create the queue (8 x SensorMsg) and both tasks */
    (void)nch;
    (void)period;
    (void)acq_task;
    (void)stats_task;
}

const ChannelStats *app_stats(void)
{
    return s_stats;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

static unsigned g_mul, g_off;
static uint32_t g_seq;          /* last sequence number produced */
static uint32_t g_expect = 1;   /* next sequence number the consumer must see */

static int16_t gen_value(uint32_t s, unsigned ch)
{
    return (int16_t)((int)((s * g_mul + ch * 11u) % 201u) - (int)g_off);
}

/*USER_CODE*/

void read_channel(uint8_t ch, SensorMsg *out)
{
    out->seq = ++g_seq;
    out->channel = ch;
    out->value = gen_value(out->seq, ch);
}

void on_message(const SensorMsg *m)
{
    printf("[t=%u] ch%u #%u %d\n", (unsigned)xTaskGetTickCount(), (unsigned)m->channel,
           (unsigned)m->seq, (int)m->value);
    if (m->seq != g_expect || m->value != gen_value(m->seq, m->channel))
        printf("CORRUPT: expected message #%u\n", (unsigned)g_expect);
    g_expect = m->seq + 1;
}

int main(void)
{
    unsigned nch, period, dur, c;
    const ChannelStats *st;

    if (scanf("%u %u %u %u %u", &nch, &period, &g_mul, &g_off, &dur) != 5) return 1;

    app_start((uint8_t)nch, (TickType_t)period);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    st = app_stats();
    for (c = 0; c < nch; c++) {
        if (st[c].count == 0)
            printf("ch%u: no data\n", c);
        else
            printf("ch%u: n=%u min=%d max=%d sum=%d\n", c, (unsigned)st[c].count,
                   (int)st[c].min, (int)st[c].max, (int)st[c].sum);
    }
    return 0;
}
@@@ sample_input
2 10 37 100 20
@@@ sample_output
[t=10] ch0 #1 -63
[t=10] ch1 #2 -15
[t=20] ch0 #3 11
[t=20] ch1 #4 59
ch0: n=2 min=-63 max=11 sum=-52
ch1: n=2 min=-15 max=59 sum=44
@@@ sample_input
3 5 50 0 10
@@@ sample_output
[t=5] ch0 #1 50
[t=5] ch1 #2 111
[t=5] ch2 #3 172
[t=10] ch0 #4 200
[t=10] ch1 #5 60
[t=10] ch2 #6 121
ch0: n=2 min=50 max=200 sum=250
ch1: n=2 min=60 max=111 sum=171
ch2: n=2 min=121 max=172 sum=293
@@@ hidden_input
1 1 7 3 5
@@@ hidden_output
[t=1] ch0 #1 4
[t=2] ch0 #2 11
[t=3] ch0 #3 18
[t=4] ch0 #4 25
[t=5] ch0 #5 32
ch0: n=5 min=4 max=32 sum=90
@@@ hidden_input
4 500 9 50 300
@@@ hidden_output
ch0: no data
ch1: no data
ch2: no data
ch3: no data
@@@ hidden_input
8 100 97 100 1000
@@@ hidden_output
[t=100] ch0 #1 -3
[t=100] ch1 #2 -96
[t=100] ch2 #3 12
[t=100] ch3 #4 -81
[t=100] ch4 #5 27
[t=100] ch5 #6 -66
[t=100] ch6 #7 42
[t=100] ch7 #8 -51
[t=200] ch0 #9 -31
[t=200] ch1 #10 77
[t=200] ch2 #11 -16
[t=200] ch3 #12 92
[t=200] ch4 #13 -1
[t=200] ch5 #14 -94
[t=200] ch6 #15 14
[t=200] ch7 #16 -79
[t=300] ch0 #17 -59
[t=300] ch1 #18 49
[t=300] ch2 #19 -44
[t=300] ch3 #20 64
[t=300] ch4 #21 -29
[t=300] ch5 #22 79
[t=300] ch6 #23 -14
[t=300] ch7 #24 94
[t=400] ch0 #25 -87
[t=400] ch1 #26 21
[t=400] ch2 #27 -72
[t=400] ch3 #28 36
[t=400] ch4 #29 -57
[t=400] ch5 #30 51
[t=400] ch6 #31 -42
[t=400] ch7 #32 66
[t=500] ch0 #33 86
[t=500] ch1 #34 -7
[t=500] ch2 #35 -100
[t=500] ch3 #36 8
[t=500] ch4 #37 -85
[t=500] ch5 #38 23
[t=500] ch6 #39 -70
[t=500] ch7 #40 38
[t=600] ch0 #41 58
[t=600] ch1 #42 -35
[t=600] ch2 #43 73
[t=600] ch3 #44 -20
[t=600] ch4 #45 88
[t=600] ch5 #46 -5
[t=600] ch6 #47 -98
[t=600] ch7 #48 10
[t=700] ch0 #49 30
[t=700] ch1 #50 -63
[t=700] ch2 #51 45
[t=700] ch3 #52 -48
[t=700] ch4 #53 60
[t=700] ch5 #54 -33
[t=700] ch6 #55 75
[t=700] ch7 #56 -18
[t=800] ch0 #57 2
[t=800] ch1 #58 -91
[t=800] ch2 #59 17
[t=800] ch3 #60 -76
[t=800] ch4 #61 32
[t=800] ch5 #62 -61
[t=800] ch6 #63 47
[t=800] ch7 #64 -46
[t=900] ch0 #65 -26
[t=900] ch1 #66 82
[t=900] ch2 #67 -11
[t=900] ch3 #68 97
[t=900] ch4 #69 4
[t=900] ch5 #70 -89
[t=900] ch6 #71 19
[t=900] ch7 #72 -74
[t=1000] ch0 #73 -54
[t=1000] ch1 #74 54
[t=1000] ch2 #75 -39
[t=1000] ch3 #76 69
[t=1000] ch4 #77 -24
[t=1000] ch5 #78 84
[t=1000] ch6 #79 -9
[t=1000] ch7 #80 99
ch0: n=10 min=-87 max=86 sum=-84
ch1: n=10 min=-96 max=82 sum=-9
ch2: n=10 min=-100 max=73 sum=-135
ch3: n=10 min=-81 max=97 sum=141
ch4: n=10 min=-85 max=88 sum=15
ch5: n=10 min=-94 max=84 sum=-111
ch6: n=10 min=-98 max=75 sum=-36
ch7: n=10 min=-79 max=99 sum=39

@@@ hidden_input
4 7 13 300 50
@@@ hidden_output
[t=7] ch0 #1 -287
[t=7] ch1 #2 -263
[t=7] ch2 #3 -239
[t=7] ch3 #4 -215
[t=14] ch0 #5 -235
[t=14] ch1 #6 -211
[t=14] ch2 #7 -187
[t=14] ch3 #8 -163
[t=21] ch0 #9 -183
[t=21] ch1 #10 -159
[t=21] ch2 #11 -135
[t=21] ch3 #12 -111
[t=28] ch0 #13 -131
[t=28] ch1 #14 -107
[t=28] ch2 #15 -284
[t=28] ch3 #16 -260
[t=35] ch0 #17 -280
[t=35] ch1 #18 -256
[t=35] ch2 #19 -232
[t=35] ch3 #20 -208
[t=42] ch0 #21 -228
[t=42] ch1 #22 -204
[t=42] ch2 #23 -180
[t=42] ch3 #24 -156
[t=49] ch0 #25 -176
[t=49] ch1 #26 -152
[t=49] ch2 #27 -128
[t=49] ch3 #28 -104
ch0: n=7 min=-287 max=-131 sum=-1520
ch1: n=7 min=-263 max=-107 sum=-1352
ch2: n=7 min=-284 max=-128 sum=-1385
ch3: n=7 min=-260 max=-104 sum=-1217

@@@ hidden_input
5 1000 123 0 20000
@@@ hidden_output
[t=1000] ch0 #1 123
[t=1000] ch1 #2 56
[t=1000] ch2 #3 190
[t=1000] ch3 #4 123
[t=1000] ch4 #5 56
[t=2000] ch0 #6 135
[t=2000] ch1 #7 68
[t=2000] ch2 #8 1
[t=2000] ch3 #9 135
[t=2000] ch4 #10 68
[t=3000] ch0 #11 147
[t=3000] ch1 #12 80
[t=3000] ch2 #13 13
[t=3000] ch3 #14 147
[t=3000] ch4 #15 80
[t=4000] ch0 #16 159
[t=4000] ch1 #17 92
[t=4000] ch2 #18 25
[t=4000] ch3 #19 159
[t=4000] ch4 #20 92
[t=5000] ch0 #21 171
[t=5000] ch1 #22 104
[t=5000] ch2 #23 37
[t=5000] ch3 #24 171
[t=5000] ch4 #25 104
[t=6000] ch0 #26 183
[t=6000] ch1 #27 116
[t=6000] ch2 #28 49
[t=6000] ch3 #29 183
[t=6000] ch4 #30 116
[t=7000] ch0 #31 195
[t=7000] ch1 #32 128
[t=7000] ch2 #33 61
[t=7000] ch3 #34 195
[t=7000] ch4 #35 128
[t=8000] ch0 #36 6
[t=8000] ch1 #37 140
[t=8000] ch2 #38 73
[t=8000] ch3 #39 6
[t=8000] ch4 #40 140
[t=9000] ch0 #41 18
[t=9000] ch1 #42 152
[t=9000] ch2 #43 85
[t=9000] ch3 #44 18
[t=9000] ch4 #45 152
[t=10000] ch0 #46 30
[t=10000] ch1 #47 164
[t=10000] ch2 #48 97
[t=10000] ch3 #49 30
[t=10000] ch4 #50 164
[t=11000] ch0 #51 42
[t=11000] ch1 #52 176
[t=11000] ch2 #53 109
[t=11000] ch3 #54 42
[t=11000] ch4 #55 176
[t=12000] ch0 #56 54
[t=12000] ch1 #57 188
[t=12000] ch2 #58 121
[t=12000] ch3 #59 54
[t=12000] ch4 #60 188
[t=13000] ch0 #61 66
[t=13000] ch1 #62 200
[t=13000] ch2 #63 133
[t=13000] ch3 #64 66
[t=13000] ch4 #65 200
[t=14000] ch0 #66 78
[t=14000] ch1 #67 11
[t=14000] ch2 #68 145
[t=14000] ch3 #69 78
[t=14000] ch4 #70 11
[t=15000] ch0 #71 90
[t=15000] ch1 #72 23
[t=15000] ch2 #73 157
[t=15000] ch3 #74 90
[t=15000] ch4 #75 23
[t=16000] ch0 #76 102
[t=16000] ch1 #77 35
[t=16000] ch2 #78 169
[t=16000] ch3 #79 102
[t=16000] ch4 #80 35
[t=17000] ch0 #81 114
[t=17000] ch1 #82 47
[t=17000] ch2 #83 181
[t=17000] ch3 #84 114
[t=17000] ch4 #85 47
[t=18000] ch0 #86 126
[t=18000] ch1 #87 59
[t=18000] ch2 #88 193
[t=18000] ch3 #89 126
[t=18000] ch4 #90 59
[t=19000] ch0 #91 138
[t=19000] ch1 #92 71
[t=19000] ch2 #93 4
[t=19000] ch3 #94 138
[t=19000] ch4 #95 71
[t=20000] ch0 #96 150
[t=20000] ch1 #97 83
[t=20000] ch2 #98 16
[t=20000] ch3 #99 150
[t=20000] ch4 #100 83
ch0: n=20 min=6 max=195 sum=2127
ch1: n=20 min=11 max=200 sum=1993
ch2: n=20 min=1 max=193 sum=1859
ch3: n=20 min=6 max=195 sum=2127
ch4: n=20 min=11 max=200 sum=1993

@@@ hidden_input
2 3 1 100 4
@@@ hidden_output
[t=3] ch0 #1 -99
[t=3] ch1 #2 -87
ch0: n=1 min=-99 max=-99 sum=-99
ch1: n=1 min=-87 max=-87 sum=-87
@@@ hint
`xQueueCreate(8, sizeof(SensorMsg))`: FreeRTOS copies `sizeof(SensorMsg)` bytes in on send and out on receive. That is why reusing one local struct in the producer is safe, and why queueing a **pointer** to it would not be.
@@@ hint
Statistics task: `SensorMsg m; xQueueReceive(q, &m, portMAX_DELAY); on_message(&m); ChannelStats *s = &s_stats[m.channel]; if (s->count == 0) { s->min = s->max = m.value; } else { if (m.value < s->min) s->min = m.value; if (m.value > s->max) s->max = m.value; } s->sum += m.value; s->count++;`
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    uint8_t  channel;
    int16_t  value;
    uint32_t seq;
} SensorMsg;

typedef struct {
    uint32_t count;
    int32_t  sum;
    int16_t  min;
    int16_t  max;
} ChannelStats;

void read_channel(uint8_t ch, SensorMsg *out);
void on_message(const SensorMsg *m);

static ChannelStats s_stats[8];
static QueueHandle_t s_queue;
static uint8_t s_nch;
static TickType_t s_period;

static void acq_task(void *pvParameters)
{
    SensorMsg msg;   /* one local, reused: the queue keeps its own copies */
    uint8_t ch;

    (void)pvParameters;
    for (;;) {
        vTaskDelay(s_period);
        for (ch = 0; ch < s_nch; ch++) {
            read_channel(ch, &msg);
            xQueueSend(s_queue, &msg, portMAX_DELAY);
        }
    }
}

static void stats_task(void *pvParameters)
{
    SensorMsg m;

    (void)pvParameters;
    for (;;) {
        if (xQueueReceive(s_queue, &m, portMAX_DELAY) == pdPASS) {
            ChannelStats *s = &s_stats[m.channel];

            on_message(&m);
            if (s->count == 0) {           /* first sample defines min and max */
                s->min = m.value;
                s->max = m.value;
            } else {
                if (m.value < s->min) s->min = m.value;
                if (m.value > s->max) s->max = m.value;
            }
            s->sum += m.value;
            s->count++;
        }
    }
}

void app_start(uint8_t nch, TickType_t period)
{
    s_nch = nch;
    s_period = period;
    s_queue = xQueueCreate(8, sizeof(SensorMsg));
    xTaskCreate(acq_task, "acq", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
    xTaskCreate(stats_task, "stats", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
}

const ChannelStats *app_stats(void)
{
    return s_stats;
}
@@@ explanation_md
**Approach.** FreeRTOS queues have **copy semantics**. `xQueueSend()` copies `uxItemSize` bytes from the address you pass into the queue's own storage, and `xQueueReceive()` copies them out into the receiver's variable. So the producer can fill one local `SensorMsg`, send it, and overwrite it for the next channel straight away. Each queued item is an independent snapshot.

The consumer owns the statistics: only one task writes them, so no mutex is needed. The first sample of a channel initialises `min` and `max`. Later samples compare against them. `count` is the "has data" flag.

**Complexity.** Per message: O(1) CPU, two copies of `sizeof(SensorMsg)` = 8 bytes (with padding). RAM: 8 x 8 = 64 bytes of queue storage plus the control block, and 12 bytes of stats per channel. A full scan (up to 8 messages) fits in the queue, so the producer never blocks.

**Common mistakes**
- Creating the queue with `sizeof(SensorMsg *)` and sending `&ptr` to the local struct. The consumer runs after the whole scan, so every pointer refers to the **same** local, which by then holds the last channel: `CORRUPT`. Worse, the local can go out of scope.
- Initialising `min = max = 0`. Wrong when every value is positive (min stays 0) or every value is negative (max stays 0).
- Updating stats in the producer, or in both tasks, without protection.
- Using `sizeof(msg)` on a pointer parameter instead of the struct type when creating the queue.
- Indexing the stats array with an unchecked channel from the message. Fine here, but validate it in production code.

**Interview follow-ups**
- When does copying become too expensive, and what is the alternative? (A queue of pointers plus an ownership protocol or a buffer pool.)
- `sizeof(SensorMsg)` is 8, not 7. Why? How would you pack it, and what does packing cost on a Cortex-M?
- How would you compute a running average without the sum overflowing over hours of operation?
- How would another task read consistent stats while the statistics task updates them?
