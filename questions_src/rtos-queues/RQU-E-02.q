@@@ meta
id: RQU-E-02
topic: Queues
difficulty: Easy
type: FUNCTION
title: Bounded Send Timeout and Drop Counter for a Slow Data Logger
tags: freertos, queue, queue-full, timeout, xtaskdelayuntil, embedded, asked-in-automotive
@@@ statement_md
A sampler task produces one measurement every `period` ticks and hands it to a data-logger task through a queue. The logger is slow: each record needs a flash write that keeps it away for `log_cost` ticks. When the queue is full, the sampler may wait **at most `send_timeout` ticks** for a free slot. After that it must **drop** the sample, count the drop and go on: it must never miss its next sampling slot.

```c
typedef struct {
    UBaseType_t qlen;          /* queue length */
    TickType_t  period;        /* sampling period */
    TickType_t  send_timeout;  /* max ticks the sampler waits for a free slot */
    TickType_t  log_cost;      /* ticks the logger sleeps after each record */
} LogCfg;

int32_t next_sample(void);       /* provided: returns 1, 2, 3, ... (call it once per period) */
void    on_sent(int32_t v);      /* provided: prints "[t=<tick>] sent <v>"    */
void    on_dropped(int32_t v);   /* provided: prints "[t=<tick>] DROP <v>"    */
void    on_logged(int32_t v);    /* provided: prints "[t=<tick>] logged <v>"  */

QueueHandle_t app_start(const LogCfg *cfg);  /* you write this, return the queue */
uint32_t      app_drop_count(void);           /* you write this: number of dropped samples */
```

Create a queue of `qlen` items of type `int32_t` and two tasks:

- **Sampler**, priority **3**. The k-th sample is taken at tick `k * period` exactly, so use `xTaskDelayUntil()` (initialise its reference time with `xTaskGetTickCount()` when the task starts). At each slot: `v = next_sample()`, then `xQueueSend(q, &v, send_timeout)`. On success call `on_sent(v)`. On `errQUEUE_FULL` increment your drop counter and call `on_dropped(v)`.
- **Logger**, priority **2**. Forever: receive one value (block with `portMAX_DELAY`), call `on_logged(v)`, then `vTaskDelay(log_cost)`.

**How it is tested.** The hidden `main()` reads the configuration and a duration `D`, calls `app_start()`, and runs the scheduler up to and including tick `D`. It prints `LATE` if a sample is not taken exactly at `k * period`. At the end it prints the totals and checks that `app_drop_count()` matches the drops it saw, and that `sent == logged + waiting`.

**Same-tick rules.** When the sampler and the logger wake at the same tick, the sampler (priority 3) runs first. If the sampler is blocked on a full queue and the logger takes an item, the sampler is woken by that receive and preempts the logger at once (its `sent` line comes before the logger's `logged` line).

**Input**
```
<qlen> <period> <send_timeout> <log_cost> <D>
```

**Example**
```
Input:
2 10 4 25 60

Output:
[t=10] sent 1
[t=10] logged 1
[t=20] sent 2
[t=30] sent 3
[t=35] logged 2
[t=40] sent 4
[t=54] DROP 5
[t=60] sent 6
[t=60] logged 3
sent 5, dropped 1, logged 3, waiting 2
```
The logger takes 1 at t=10 and comes back at t=35 to take 2. At t=50 the queue holds 3 and 4, so the sampler waits 4 ticks and drops 5 at t=54. At t=60 the queue is full again. The sampler blocks, then the logger receives 3, which frees a slot: the sampler preempts the logger, sends 6, and only then the logger prints `logged 3`.
@@@ constraints_md
- 1 <= qlen <= 16, 1 <= period <= 1000, 0 <= send_timeout < period, 1 <= log_cost <= 1000, 1 <= D <= 20000.
- Priorities are fixed: sampler 3, logger 2. Stack size `configMINIMAL_STACK_SIZE`.
- The sampler must block in `xTaskDelayUntil()` and in `xQueueSend()` with the given timeout; no polling.
@@@ starter_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    UBaseType_t qlen;
    TickType_t  period;
    TickType_t  send_timeout;
    TickType_t  log_cost;
} LogCfg;

int32_t next_sample(void);
void    on_sent(int32_t v);
void    on_dropped(int32_t v);
void    on_logged(int32_t v);

static void sampler_task(void *pvParameters)
{
    /* TODO: xTaskDelayUntil(period); v = next_sample(); send with timeout; count drops */
    (void)pvParameters;
    for (;;) {
        vTaskDelay(1000);
    }
}

static void logger_task(void *pvParameters)
{
    /* TODO: receive (block), on_logged(v), vTaskDelay(log_cost) */
    (void)pvParameters;
    for (;;) {
        vTaskDelay(1000);
    }
}

QueueHandle_t app_start(const LogCfg *cfg)
{
    /* TODO: create the queue and both tasks */
    (void)cfg;
    (void)sampler_task;
    (void)logger_task;
    return NULL;
}

uint32_t app_drop_count(void)
{
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

static TickType_t g_period;
static int32_t g_next = 1;
static unsigned g_sent, g_dropped, g_logged;

int32_t next_sample(void)
{
    TickType_t now = xTaskGetTickCount();
    if (now != (TickType_t)g_next * g_period)
        printf("[t=%u] LATE: sample %d was due at t=%u\n", (unsigned)now, (int)g_next,
               (unsigned)((TickType_t)g_next * g_period));
    return g_next++;
}

void on_sent(int32_t v)
{
    printf("[t=%u] sent %d\n", (unsigned)xTaskGetTickCount(), (int)v);
    g_sent++;
}

void on_dropped(int32_t v)
{
    printf("[t=%u] DROP %d\n", (unsigned)xTaskGetTickCount(), (int)v);
    g_dropped++;
}

void on_logged(int32_t v)
{
    printf("[t=%u] logged %d\n", (unsigned)xTaskGetTickCount(), (int)v);
    g_logged++;
}

/*USER_CODE*/

int main(void)
{
    static LogCfg cfg;
    unsigned qlen, period, tmo, cost, dur, waiting;
    QueueHandle_t q;

    if (scanf("%u %u %u %u %u", &qlen, &period, &tmo, &cost, &dur) != 5) return 1;
    cfg.qlen = (UBaseType_t)qlen;
    cfg.period = (TickType_t)period;
    cfg.send_timeout = (TickType_t)tmo;
    cfg.log_cost = (TickType_t)cost;
    g_period = cfg.period;

    q = app_start(&cfg);
    if (q == NULL) {
        printf("ERROR: app_start() returned no queue\n");
        return 0;
    }
    if (uxQueueGetQueueLength(q) != (UBaseType_t)qlen || uxQueueGetQueueItemSize(q) != sizeof(int32_t)) {
        printf("ERROR: queue must hold %u items of sizeof(int32_t)\n", qlen);
        return 0;
    }
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    waiting = (unsigned)uxQueueMessagesWaiting(q);
    printf("sent %u, dropped %u, logged %u, waiting %u\n", g_sent, (unsigned)app_drop_count(), g_logged, waiting);
    if (app_drop_count() != g_dropped)
        printf("ERROR: drop counter says %u but %u samples were dropped\n", (unsigned)app_drop_count(), g_dropped);
    if (g_sent != g_logged + waiting)
        printf("ERROR: sent != logged + waiting\n");
    return 0;
}
@@@ sample_input
2 10 4 25 60
@@@ sample_output
[t=10] sent 1
[t=10] logged 1
[t=20] sent 2
[t=30] sent 3
[t=35] logged 2
[t=40] sent 4
[t=54] DROP 5
[t=60] sent 6
[t=60] logged 3
sent 5, dropped 1, logged 3, waiting 2
@@@ sample_input
1 5 0 12 30
@@@ sample_output
[t=5] sent 1
[t=5] logged 1
[t=10] sent 2
[t=15] DROP 3
[t=17] logged 2
[t=20] sent 4
[t=25] DROP 5
[t=29] logged 4
[t=30] sent 6
sent 4, dropped 2, logged 3, waiting 1
@@@ hidden_input
4 1 0 1 10
@@@ hidden_output
[t=1] sent 1
[t=1] logged 1
[t=2] sent 2
[t=2] logged 2
[t=3] sent 3
[t=3] logged 3
[t=4] sent 4
[t=4] logged 4
[t=5] sent 5
[t=5] logged 5
[t=6] sent 6
[t=6] logged 6
[t=7] sent 7
[t=7] logged 7
[t=8] sent 8
[t=8] logged 8
[t=9] sent 9
[t=9] logged 9
[t=10] sent 10
[t=10] logged 10
sent 10, dropped 0, logged 10, waiting 0

@@@ hidden_input
3 50 10 5 40
@@@ hidden_output
sent 0, dropped 0, logged 0, waiting 0
@@@ hidden_input
2 10 9 100 500
@@@ hidden_output
[t=10] sent 1
[t=10] logged 1
[t=20] sent 2
[t=30] sent 3
[t=49] DROP 4
[t=59] DROP 5
[t=69] DROP 6
[t=79] DROP 7
[t=89] DROP 8
[t=99] DROP 9
[t=109] DROP 10
[t=110] sent 11
[t=110] logged 2
[t=129] DROP 12
[t=139] DROP 13
[t=149] DROP 14
[t=159] DROP 15
[t=169] DROP 16
[t=179] DROP 17
[t=189] DROP 18
[t=199] DROP 19
[t=209] DROP 20
[t=210] sent 21
[t=210] logged 3
[t=229] DROP 22
[t=239] DROP 23
[t=249] DROP 24
[t=259] DROP 25
[t=269] DROP 26
[t=279] DROP 27
[t=289] DROP 28
[t=299] DROP 29
[t=309] DROP 30
[t=310] sent 31
[t=310] logged 11
[t=329] DROP 32
[t=339] DROP 33
[t=349] DROP 34
[t=359] DROP 35
[t=369] DROP 36
[t=379] DROP 37
[t=389] DROP 38
[t=399] DROP 39
[t=409] DROP 40
[t=410] sent 41
[t=410] logged 21
[t=429] DROP 42
[t=439] DROP 43
[t=449] DROP 44
[t=459] DROP 45
[t=469] DROP 46
[t=479] DROP 47
[t=489] DROP 48
[t=499] DROP 49
sent 7, dropped 42, logged 5, waiting 2

@@@ hidden_input
1 20 15 50 100
@@@ hidden_output
[t=20] sent 1
[t=20] logged 1
[t=40] sent 2
[t=70] sent 3
[t=70] logged 2
[t=95] DROP 4
sent 3, dropped 1, logged 2, waiting 1

@@@ hidden_input
16 7 3 11 2000
@@@ hidden_output
[t=7] sent 1
[t=7] logged 1
[t=14] sent 2
[t=18] logged 2
[t=21] sent 3
[t=28] sent 4
[t=29] logged 3
[t=35] sent 5
[t=40] logged 4
[t=42] sent 6
[t=49] sent 7
[t=51] logged 5
[t=56] sent 8
[t=62] logged 6
[t=63] sent 9
[t=70] sent 10
[t=73] logged 7
[t=77] sent 11
[t=84] sent 12
[t=84] logged 8
[t=91] sent 13
[t=95] logged 9
[t=98] sent 14
[t=105] sent 15
[t=106] logged 10
[t=112] sent 16
[t=117] logged 11
[t=119] sent 17
[t=126] sent 18
[t=128] logged 12
[t=133] sent 19
[t=139] logged 13
[t=140] sent 20
[t=147] sent 21
[t=150] logged 14
[t=154] sent 22
[t=161] sent 23
[t=161] logged 15
[t=168] sent 24
[t=172] logged 16
[t=175] sent 25
[t=182] sent 26
[t=183] logged 17
[t=189] sent 27
[t=194] logged 18
[t=196] sent 28
[t=203] sent 29
[t=205] logged 19
[t=210] sent 30
[t=216] logged 20
[t=217] sent 31
[t=224] sent 32
[t=227] logged 21
[t=231] sent 33
[t=238] sent 34
[t=238] logged 22
[t=245] sent 35
[t=249] logged 23
[t=252] sent 36
[t=259] sent 37
[t=260] logged 24
[t=266] sent 38
[t=271] logged 25
[t=273] sent 39
[t=280] sent 40
[t=282] logged 26
[t=287] sent 41
[t=293] logged 27
[t=294] sent 42
[t=301] sent 43
[t=304] logged 28
[t=308] sent 44
[t=315] sent 45
[t=315] logged 29
[t=325] DROP 46
[t=326] logged 30
[t=329] sent 47
[t=337] sent 48
[t=337] logged 31
[t=346] DROP 49
[t=348] logged 32
[t=350] sent 50
[t=359] sent 51
[t=359] logged 33
[t=367] DROP 52
[t=370] logged 34
[t=371] sent 53
[t=381] DROP 54
[t=381] logged 35
[t=385] sent 55
[t=392] sent 56
[t=392] logged 36
[t=402] DROP 57
[t=403] logged 37
[t=406] sent 58
[t=414] sent 59
[t=414] logged 38
[t=423] DROP 60
[t=425] logged 39
[t=427] sent 61
[t=436] sent 62
[t=436] logged 40
[t=444] DROP 63
[t=447] logged 41
[t=448] sent 64
[t=458] DROP 65
[t=458] logged 42
[t=462] sent 66
[t=469] sent 67
[t=469] logged 43
[t=479] DROP 68
[t=480] logged 44
[t=483] sent 69
[t=491] sent 70
[t=491] logged 45
[t=500] DROP 71
[t=502] logged 47
[t=504] sent 72
[t=513] sent 73
[t=513] logged 48
[t=521] DROP 74
[t=524] logged 50
[t=525] sent 75
[t=535] DROP 76
[t=535] logged 51
[t=539] sent 77
[t=546] sent 78
[t=546] logged 53
[t=556] DROP 79
[t=557] logged 55
[t=560] sent 80
[t=568] sent 81
[t=568] logged 56
[t=577] DROP 82
[t=579] logged 58
[t=581] sent 83
[t=590] sent 84
[t=590] logged 59
[t=598] DROP 85
[t=601] logged 61
[t=602] sent 86
[t=612] DROP 87
[t=612] logged 62
[t=616] sent 88
[t=623] sent 89
[t=623] logged 64
[t=633] DROP 90
[t=634] logged 66
[t=637] sent 91
[t=645] sent 92
[t=645] logged 67
[t=654] DROP 93
[t=656] logged 69
[t=658] sent 94
[t=667] sent 95
[t=667] logged 70
[t=675] DROP 96
[t=678] logged 72
[t=679] sent 97
[t=689] DROP 98
[t=689] logged 73
[t=693] sent 99
[t=700] sent 100
[t=700] logged 75
[t=710] DROP 101
[t=711] logged 77
[t=714] sent 102
[t=722] sent 103
[t=722] logged 78
[t=731] DROP 104
[t=733] logged 80
[t=735] sent 105
[t=744] sent 106
[t=744] logged 81
[t=752] DROP 107
[t=755] logged 83
[t=756] sent 108
[t=766] DROP 109
[t=766] logged 84
[t=770] sent 110
[t=777] sent 111
[t=777] logged 86
[t=787] DROP 112
[t=788] logged 88
[t=791] sent 113
[t=799] sent 114
[t=799] logged 89
[t=808] DROP 115
[t=810] logged 91
[t=812] sent 116
[t=821] sent 117
[t=821] logged 92
[t=829] DROP 118
[t=832] logged 94
[t=833] sent 119
[t=843] DROP 120
[t=843] logged 95
[t=847] sent 121
[t=854] sent 122
[t=854] logged 97
[t=864] DROP 123
[t=865] logged 99
[t=868] sent 124
[t=876] sent 125
[t=876] logged 100
[t=885] DROP 126
[t=887] logged 102
[t=889] sent 127
[t=898] sent 128
[t=898] logged 103
[t=906] DROP 129
[t=909] logged 105
[t=910] sent 130
[t=920] DROP 131
[t=920] logged 106
[t=924] sent 132
[t=931] sent 133
[t=931] logged 108
[t=941] DROP 134
[t=942] logged 110
[t=945] sent 135
[t=953] sent 136
[t=953] logged 111
[t=962] DROP 137
[t=964] logged 113
[t=966] sent 138
[t=975] sent 139
[t=975] logged 114
[t=983] DROP 140
[t=986] logged 116
[t=987] sent 141
[t=997] DROP 142
[t=997] logged 117
[t=1001] sent 143
[t=1008] sent 144
[t=1008] logged 119
[t=1018] DROP 145
[t=1019] logged 121
[t=1022] sent 146
[t=1030] sent 147
[t=1030] logged 122
[t=1039] DROP 148
[t=1041] logged 124
[t=1043] sent 149
[t=1052] sent 150
[t=1052] logged 125
[t=1060] DROP 151
[t=1063] logged 127
[t=1064] sent 152
[t=1074] DROP 153
[t=1074] logged 128
[t=1078] sent 154
[t=1085] sent 155
[t=1085] logged 130
[t=1095] DROP 156
[t=1096] logged 132
[t=1099] sent 157
[t=1107] sent 158
[t=1107] logged 133
[t=1116] DROP 159
[t=1118] logged 135
[t=1120] sent 160
[t=1129] sent 161
[t=1129] logged 136
[t=1137] DROP 162
[t=1140] logged 138
[t=1141] sent 163
[t=1151] DROP 164
[t=1151] logged 139
[t=1155] sent 165
[t=1162] sent 166
[t=1162] logged 141
[t=1172] DROP 167
[t=1173] logged 143
[t=1176] sent 168
[t=1184] sent 169
[t=1184] logged 144
[t=1193] DROP 170
[t=1195] logged 146
[t=1197] sent 171
[t=1206] sent 172
[t=1206] logged 147
[t=1214] DROP 173
[t=1217] logged 149
[t=1218] sent 174
[t=1228] DROP 175
[t=1228] logged 150
[t=1232] sent 176
[t=1239] sent 177
[t=1239] logged 152
[t=1249] DROP 178
[t=1250] logged 154
[t=1253] sent 179
[t=1261] sent 180
[t=1261] logged 155
[t=1270] DROP 181
[t=1272] logged 157
[t=1274] sent 182
[t=1283] sent 183
[t=1283] logged 158
[t=1291] DROP 184
[t=1294] logged 160
[t=1295] sent 185
[t=1305] DROP 186
[t=1305] logged 161
[t=1309] sent 187
[t=1316] sent 188
[t=1316] logged 163
[t=1326] DROP 189
[t=1327] logged 165
[t=1330] sent 190
[t=1338] sent 191
[t=1338] logged 166
[t=1347] DROP 192
[t=1349] logged 168
[t=1351] sent 193
[t=1360] sent 194
[t=1360] logged 169
[t=1368] DROP 195
[t=1371] logged 171
[t=1372] sent 196
[t=1382] DROP 197
[t=1382] logged 172
[t=1386] sent 198
[t=1393] sent 199
[t=1393] logged 174
[t=1403] DROP 200
[t=1404] logged 176
[t=1407] sent 201
[t=1415] sent 202
[t=1415] logged 177
[t=1424] DROP 203
[t=1426] logged 179
[t=1428] sent 204
[t=1437] sent 205
[t=1437] logged 180
[t=1445] DROP 206
[t=1448] logged 182
[t=1449] sent 207
[t=1459] DROP 208
[t=1459] logged 183
[t=1463] sent 209
[t=1470] sent 210
[t=1470] logged 185
[t=1480] DROP 211
[t=1481] logged 187
[t=1484] sent 212
[t=1492] sent 213
[t=1492] logged 188
[t=1501] DROP 214
[t=1503] logged 190
[t=1505] sent 215
[t=1514] sent 216
[t=1514] logged 191
[t=1522] DROP 217
[t=1525] logged 193
[t=1526] sent 218
[t=1536] DROP 219
[t=1536] logged 194
[t=1540] sent 220
[t=1547] sent 221
[t=1547] logged 196
[t=1557] DROP 222
[t=1558] logged 198
[t=1561] sent 223
[t=1569] sent 224
[t=1569] logged 199
[t=1578] DROP 225
[t=1580] logged 201
[t=1582] sent 226
[t=1591] sent 227
[t=1591] logged 202
[t=1599] DROP 228
[t=1602] logged 204
[t=1603] sent 229
[t=1613] DROP 230
[t=1613] logged 205
[t=1617] sent 231
[t=1624] sent 232
[t=1624] logged 207
[t=1634] DROP 233
[t=1635] logged 209
[t=1638] sent 234
[t=1646] sent 235
[t=1646] logged 210
[t=1655] DROP 236
[t=1657] logged 212
[t=1659] sent 237
[t=1668] sent 238
[t=1668] logged 213
[t=1676] DROP 239
[t=1679] logged 215
[t=1680] sent 240
[t=1690] DROP 241
[t=1690] logged 216
[t=1694] sent 242
[t=1701] sent 243
[t=1701] logged 218
[t=1711] DROP 244
[t=1712] logged 220
[t=1715] sent 245
[t=1723] sent 246
[t=1723] logged 221
[t=1732] DROP 247
[t=1734] logged 223
[t=1736] sent 248
[t=1745] sent 249
[t=1745] logged 224
[t=1753] DROP 250
[t=1756] logged 226
[t=1757] sent 251
[t=1767] DROP 252
[t=1767] logged 227
[t=1771] sent 253
[t=1778] sent 254
[t=1778] logged 229
[t=1788] DROP 255
[t=1789] logged 231
[t=1792] sent 256
[t=1800] sent 257
[t=1800] logged 232
[t=1809] DROP 258
[t=1811] logged 234
[t=1813] sent 259
[t=1822] sent 260
[t=1822] logged 235
[t=1830] DROP 261
[t=1833] logged 237
[t=1834] sent 262
[t=1844] DROP 263
[t=1844] logged 238
[t=1848] sent 264
[t=1855] sent 265
[t=1855] logged 240
[t=1865] DROP 266
[t=1866] logged 242
[t=1869] sent 267
[t=1877] sent 268
[t=1877] logged 243
[t=1886] DROP 269
[t=1888] logged 245
[t=1890] sent 270
[t=1899] sent 271
[t=1899] logged 246
[t=1907] DROP 272
[t=1910] logged 248
[t=1911] sent 273
[t=1921] DROP 274
[t=1921] logged 249
[t=1925] sent 275
[t=1932] sent 276
[t=1932] logged 251
[t=1942] DROP 277
[t=1943] logged 253
[t=1946] sent 278
[t=1954] sent 279
[t=1954] logged 254
[t=1963] DROP 280
[t=1965] logged 256
[t=1967] sent 281
[t=1976] sent 282
[t=1976] logged 257
[t=1984] DROP 283
[t=1987] logged 259
[t=1988] sent 284
[t=1998] DROP 285
[t=1998] logged 260
sent 197, dropped 88, logged 182, waiting 15

@@@ hidden_input
3 4 3 9 61
@@@ hidden_output
[t=4] sent 1
[t=4] logged 1
[t=8] sent 2
[t=12] sent 3
[t=13] logged 2
[t=16] sent 4
[t=20] sent 5
[t=22] logged 3
[t=24] sent 6
[t=31] DROP 7
[t=31] logged 4
[t=32] sent 8
[t=39] DROP 9
[t=40] sent 10
[t=40] logged 5
[t=47] DROP 11
[t=49] sent 12
[t=49] logged 6
[t=55] DROP 13
[t=58] sent 14
[t=58] logged 8
sent 10, dropped 4, logged 7, waiting 3

@@@ hint
Keep the drop counter in a `static uint32_t` that only the sampler writes. `xQueueSend()` returns `pdPASS` or `errQUEUE_FULL`: the third argument is how long the caller may block waiting for space.
@@@ hint
Sampler: `TickType_t last = xTaskGetTickCount(); for (;;) { xTaskDelayUntil(&last, c->period); int32_t v = next_sample(); if (xQueueSend(q, &v, c->send_timeout) == pdPASS) on_sent(v); else { s_drops++; on_dropped(v); } }`. Because `send_timeout < period`, the wait always ends before the next slot, and `xTaskDelayUntil()` keeps the slots on the `k * period` grid.
@@@ solution_code
#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

typedef struct {
    UBaseType_t qlen;
    TickType_t  period;
    TickType_t  send_timeout;
    TickType_t  log_cost;
} LogCfg;

int32_t next_sample(void);
void    on_sent(int32_t v);
void    on_dropped(int32_t v);
void    on_logged(int32_t v);

static QueueHandle_t s_queue;
static uint32_t s_drops;   /* written only by the sampler task */

static void sampler_task(void *pvParameters)
{
    const LogCfg *c = (const LogCfg *)pvParameters;
    TickType_t last = xTaskGetTickCount();

    for (;;) {
        int32_t v;

        xTaskDelayUntil(&last, c->period);   /* fixed grid: k * period, no drift */
        v = next_sample();
        if (xQueueSend(s_queue, &v, c->send_timeout) == pdPASS) {
            on_sent(v);
        } else {                              /* errQUEUE_FULL after send_timeout ticks */
            s_drops++;
            on_dropped(v);
        }
    }
}

static void logger_task(void *pvParameters)
{
    const LogCfg *c = (const LogCfg *)pvParameters;
    int32_t v;

    for (;;) {
        if (xQueueReceive(s_queue, &v, portMAX_DELAY) == pdPASS) {
            on_logged(v);
            vTaskDelay(c->log_cost);          /* slow flash write */
        }
    }
}

QueueHandle_t app_start(const LogCfg *cfg)
{
    s_queue = xQueueCreate(cfg->qlen, sizeof(int32_t));
    if (s_queue == NULL) {
        return NULL;
    }
    xTaskCreate(sampler_task, "sampler", configMINIMAL_STACK_SIZE, (void *)cfg, 3, NULL);
    xTaskCreate(logger_task, "logger", configMINIMAL_STACK_SIZE, (void *)cfg, 2, NULL);
    return s_queue;
}

uint32_t app_drop_count(void)
{
    return s_drops;
}
@@@ explanation_md
**Approach.** The third argument of `xQueueSend()` bounds the time a sender may block when the queue is full. The kernel puts the sampler on the queue's "waiting to send" list **and** on the delayed list. Whichever comes first wakes it:
- a receive that frees a slot: the send then completes and returns `pdPASS`;
- the timeout: the send returns `errQUEUE_FULL`, and the sample is dropped and counted.

Because `send_timeout < period` and the sampler uses `xTaskDelayUntil()`, a long wait never shifts the sampling grid. The next wake-up is computed from the previous **scheduled** time, not from when the send finished.

Two same-tick effects show up in the traces:
- When the sampler and the logger wake together, the higher-priority sampler runs first, so it may find the queue still full.
- When the logger's `xQueueReceive()` frees a slot for the blocked sampler, the sampler preempts the logger **inside** that receive call. That is why `sent 6` is printed before `logged 3` at t=60.

**Complexity.** Per sample: O(1) CPU, one 4-byte copy, and at most two context switches. RAM: `qlen * 4` bytes of queue storage plus the control block. The worst-case sampler blocking time per period is `send_timeout`. Drops happen when, over a window, the logger drains fewer items than arrive: here one item per `log_cost` ticks against one per `period` ticks.

**Common mistakes**
- Sending with `portMAX_DELAY`: the sampler then blocks behind the slow logger, misses its slots and shows `LATE` (the real-world symptom is a jittery control loop).
- Using `vTaskDelay(period)` after a send that waited: the period drifts by the waiting time.
- Testing the return value against `pdTRUE`/`pdFALSE` loosely and still calling `on_sent()` on failure, or forgetting the drop counter entirely: a silent data loss you cannot diagnose in the field.
- Making the drop counter non-static or updating it from several tasks without protection.

**Interview follow-ups**
- Would you rather drop the newest or the oldest sample? How would you implement "drop oldest" with a FreeRTOS queue?
- How do you size `qlen` from the logger's worst-case flash write time and the sampling rate?
- What changes if the sample comes from an ISR (`xQueueSendFromISR`, no timeout possible)?
- How would you expose the drop counter to diagnostics (DTC, UDS read-data-by-identifier) without a race?
