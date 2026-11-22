@@@ meta
id: RTM-H-02
topic: Software Timers
difficulty: Hard
type: FUNCTION
title: Multiplex Many Soft Timers On A Single FreeRTOS Timer
tags: freertos, software-timers, timer-multiplexing, xtimerchangeperiod, data-structures, embedded
@@@ statement_md
A legacy AUTOSAR-style stack expects 32 "OS alarms", but the platform team allows the module **one** FreeRTOS software timer. Build a small **soft-timer service** that multiplexes all alarms on that one timer. The FreeRTOS timer must wake up **only** when at least one soft timer is due (no 1 ms polling).

```c
void st_fired(int id);    /* provided: prints "[t=<tick>] fire <id>"; call it from the timer callback */

void st_init(void);                                           /* you write: before the scheduler */
void st_start(int id, TickType_t delay, TickType_t period);   /* you write: called from a task */
void st_stop(int id);                                         /* you write: called from a task */
```

Semantics (ids are 0..31):
- `st_start(id, delay, period)` arms soft timer `id`. If it is already armed, it is re-armed from scratch. It first fires at `now + delay` (`delay >= 1`). If `period > 0`, it then fires every `period` ticks with no drift: next due = previous due + `period`. If `period == 0`, it fires once and is disarmed.
- `st_stop(id)` disarms `id`. Stopping a timer that is not armed does nothing.
- When several soft timers are due at the same tick, they fire in **increasing id** order, in one callback.
- The FreeRTOS timer must expire **exactly** at the ticks where at least one soft timer is due, and at no other tick. The harness counts the expirations of your FreeRTOS timer and the "wasted" ones, where nothing fired.

Rules:
- Exactly **one** FreeRTOS timer. `xTimerCreateStatic`, `xTimerPendFunctionCall*`, task creation and `vTaskDelay()` are banned.
- `st_start()`/`st_stop()` run in a task of priority 3. The timer service task has priority 7, so a timer command sent by that task is handled **before the call returns**. Use block time `0`. Callbacks must not block.
- At any tick, the timer service task runs before the command task. So a soft timer that is due at tick `T` has already fired when a command at `T` is executed.

**How it is tested.** A hidden task (priority 3) executes the commands at their ticks, in input order. The scheduler runs up to and including tick `D`. Then the harness prints the number of fires, the number of FreeRTOS timer expirations, and the number of wasted wake-ups.

**Input**
```
<n> <D>
<tick> START <id> <delay> <period>
<tick> STOP <id>                        (n command lines in total, ticks non-decreasing)
```

**Example**
```
Input:
4 40
1 START 0 10 10
1 START 1 5 0
2 START 2 4 3
13 STOP 2

Output:
[t=6] fire 1
[t=6] fire 2
[t=9] fire 2
[t=11] fire 0
[t=12] fire 2
[t=21] fire 0
[t=31] fire 0
fires=7
timer expirations=6
wasted wakeups=0
```
Soft timer 2 is due at 6, 9, 12, ... and is stopped at 13. Soft timer 1 fires once at 6, in the same callback as timer 2 (lower id first). The FreeRTOS timer expires at 6, 9, 11, 12, 21 and 31: six expirations, and none of them is wasted.
@@@ constraints_md
- 0 <= n <= 200, 1 <= D <= 20000, 1 <= tick <= D.
- 0 <= id <= 31, 1 <= delay <= 5000, 0 <= period <= 5000.
- Exactly one FreeRTOS software timer.
@@@ starter_code
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

void st_fired(int id);

#define ST_MAX 32

static void mux_cb(TimerHandle_t xTimer)
{
    (void)xTimer;
    /* TODO: fire every due soft timer, then program the next wake-up */
}

void st_init(void)
{
    /* TODO: create the single FreeRTOS timer */
    (void)mux_cb;
}

void st_start(int id, TickType_t delay, TickType_t period)
{
    /* TODO */
    (void)id;
    (void)delay;
    (void)period;
}

void st_stop(int id)
{
    /* TODO */
    (void)id;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"
#include "sim.h"

static unsigned g_fires, g_expirations, g_wasted, g_ntimers;
static int g_bad_ctx, g_bad_id;
static TimerCallbackFunction_t g_user_cb;

void st_fired(int id)
{
    if (xTaskGetCurrentTaskHandle() != xTimerGetTimerDaemonTaskHandle()) g_bad_ctx = 1;
    if (id < 0 || id > 31) g_bad_id = 1;
    g_fires++;
    printf("[t=%u] fire %d\n", (unsigned)xTaskGetTickCount(), id);
}

static void h_trampoline(TimerHandle_t t)
{
    unsigned before = g_fires;
    g_expirations++;
    g_user_cb(t);
    if (g_fires == before) g_wasted++;
}

static TimerHandle_t h_timer_create(const char *name, TickType_t period, BaseType_t reload,
                                    void *id, TimerCallbackFunction_t cb)
{
    g_ntimers++;
    if (g_ntimers > 1) return NULL;
    g_user_cb = cb;
    return xTimerCreate(name, period, reload, id, h_trampoline);
}

#define xTimerCreate(a, b, c, d, e) h_timer_create(a, b, c, d, e)
#define xTimerCreateStatic(...) xTimerCreateStatic_is_not_allowed_here
#define xTimerPendFunctionCall(...) xTimerPendFunctionCall_is_not_allowed_here
#define xTimerPendFunctionCallFromISR(...) xTimerPendFunctionCallFromISR_is_not_allowed_here
#define xTaskCreate(...) xTaskCreate_is_not_allowed_here
#define xTaskCreateStatic(...) xTaskCreateStatic_is_not_allowed_here
#define vTaskDelay(x) vTaskDelay_is_not_allowed_here
#define xTaskDelayUntil(...) xTaskDelayUntil_is_not_allowed_here

/*USER_CODE*/

#undef xTimerCreate
#undef xTimerCreateStatic
#undef xTimerPendFunctionCall
#undef xTimerPendFunctionCallFromISR
#undef xTaskCreate
#undef xTaskCreateStatic
#undef vTaskDelay
#undef xTaskDelayUntil

#define H_MAXC 200
typedef struct { TickType_t tick; int start; int id; TickType_t delay, period; } Cmd;
static Cmd g_cmd[H_MAXC];
static unsigned g_ncmd;

static void cmd_task(void *p)
{
    unsigned i;
    (void)p;
    for (i = 0; i < g_ncmd; i++) {
        TickType_t now = xTaskGetTickCount();
        if (g_cmd[i].tick > now) vTaskDelay(g_cmd[i].tick - now);
        if (g_cmd[i].start) st_start(g_cmd[i].id, g_cmd[i].delay, g_cmd[i].period);
        else st_stop(g_cmd[i].id);
    }
    for (;;) vTaskDelay(portMAX_DELAY);
}

int main(void)
{
    unsigned dur, i, t, id, d, p;
    char word[8];

    if (scanf("%u %u", &g_ncmd, &dur) != 2 || g_ncmd > H_MAXC) return 1;
    for (i = 0; i < g_ncmd; i++) {
        if (scanf("%u %7s %u", &t, word, &id) != 3 || id > 31) return 1;
        g_cmd[i].tick = (TickType_t)t;
        g_cmd[i].id = (int)id;
        g_cmd[i].start = strcmp(word, "START") == 0;
        if (g_cmd[i].start) {
            if (scanf("%u %u", &d, &p) != 2) return 1;
            g_cmd[i].delay = (TickType_t)d;
            g_cmd[i].period = (TickType_t)p;
        }
    }

    st_init();
    xTaskCreate(cmd_task, "cmd", configMINIMAL_STACK_SIZE, NULL, 3, NULL);
    vSimSetTickLimit((TickType_t)dur);
    vTaskStartScheduler();

    if (g_ntimers != 1) printf("FAIL: %u FreeRTOS timers requested (exactly 1 allowed)\n", g_ntimers);
    if (g_bad_ctx) printf("FAIL: st_fired() called outside the timer service task\n");
    if (g_bad_id) printf("FAIL: st_fired() called with a bad id\n");
    printf("fires=%u\n", g_fires);
    printf("timer expirations=%u\n", g_expirations);
    printf("wasted wakeups=%u\n", g_wasted);
    return 0;
}
@@@ sample_input
4 40
1 START 0 10 10
1 START 1 5 0
2 START 2 4 3
13 STOP 2
@@@ sample_output
[t=6] fire 1
[t=6] fire 2
[t=9] fire 2
[t=11] fire 0
[t=12] fire 2
[t=21] fire 0
[t=31] fire 0
fires=7
timer expirations=6
wasted wakeups=0
@@@ sample_input
5 50
5 START 3 10 0
5 START 7 20 0
10 STOP 3
25 STOP 7
30 START 7 1 5
@@@ sample_output
[t=25] fire 7
[t=31] fire 7
[t=36] fire 7
[t=41] fire 7
[t=46] fire 7
fires=5
timer expirations=5
wasted wakeups=0
@@@ hidden_input
0 100
@@@ hidden_output
fires=0
timer expirations=0
wasted wakeups=0
@@@ hidden_input
1 5
1 START 0 1 1
@@@ hidden_output
[t=2] fire 0
[t=3] fire 0
[t=4] fire 0
[t=5] fire 0
fires=4
timer expirations=4
wasted wakeups=0
@@@ hidden_input
4 200
1 START 4 10 0
5 START 4 10 0
20 START 5 100 0
30 START 5 5 0
@@@ hidden_output
[t=15] fire 4
[t=35] fire 5
fires=2
timer expirations=2
wasted wakeups=0
@@@ hidden_input
5 60
2 START 9 18 0
4 START 3 16 20
6 START 6 14 0
20 STOP 31
40 STOP 3
@@@ hidden_output
[t=20] fire 3
[t=20] fire 6
[t=20] fire 9
[t=40] fire 3
fires=4
timer expirations=2
wasted wakeups=0
@@@ hidden_input
120 6000
37 STOP 5
55 START 13 10 60
84 STOP 27
122 START 19 269 0
142 START 16 160 321
158 START 4 181 79
192 START 6 145 284
202 START 31 167 442
203 START 14 66 333
235 START 21 173 0
260 START 31 59 148
290 START 28 178 0
327 START 20 97 107
355 STOP 19
373 START 22 296 316
410 STOP 20
415 START 14 90 130
453 START 12 273 0
484 START 22 90 0
500 START 10 89 152
506 STOP 11
533 START 4 63 119
570 START 19 200 332
580 START 8 179 221
592 STOP 6
598 START 14 260 330
630 START 8 112 449
640 STOP 18
658 STOP 24
689 START 28 108 310
697 START 5 264 127
721 STOP 23
745 START 31 255 362
770 START 9 151 247
805 START 5 292 124
822 STOP 22
838 START 25 37 157
860 START 5 250 374
861 STOP 10
873 START 9 1 0
894 START 13 123 324
901 START 27 81 188
921 START 21 119 0
921 START 0 141 0
943 START 23 24 0
946 START 30 276 229
980 STOP 15
995 START 12 76 119
1005 START 29 240 0
1005 START 24 194 257
1012 START 14 76 0
1037 STOP 10
1045 START 30 300 410
1065 START 29 216 155
1101 START 2 272 401
1103 STOP 4
1112 STOP 22
1136 STOP 28
1145 START 17 47 80
1154 START 10 249 402
1164 START 22 254 162
1195 START 23 95 342
1216 START 27 298 409
1238 STOP 22
1273 STOP 1
1305 START 13 30 436
1316 STOP 30
1326 START 26 2 246
1364 STOP 0
1376 START 26 68 0
1404 START 14 203 311
1429 STOP 22
1437 START 23 54 334
1462 START 19 70 294
1480 START 12 141 81
1511 START 12 267 149
1525 START 6 248 178
1564 STOP 27
1570 START 5 193 423
1578 START 18 5 68
1609 START 15 132 118
1646 START 8 119 0
1648 START 8 127 0
1681 START 2 224 0
1698 START 30 28 267
1723 START 3 65 412
1732 STOP 13
1732 START 16 10 410
1767 START 9 47 0
1776 STOP 6
1794 STOP 21
1818 START 23 269 0
1843 START 13 240 175
1846 START 21 253 195
1866 STOP 16
1902 STOP 21
1928 START 10 11 407
1963 START 15 95 0
1965 START 5 101 0
1992 START 20 125 199
1992 STOP 3
1999 START 0 47 0
2015 START 26 54 360
2054 STOP 22
2073 START 11 152 0
2075 START 6 147 0
2084 START 2 95 402
2094 START 25 80 0
2117 START 15 246 0
2123 START 12 260 187
2127 START 23 156 172
2154 STOP 31
2168 STOP 10
2170 STOP 18
2183 START 1 3 0
2219 STOP 20
2220 START 6 65 0
2232 START 3 115 253
2250 START 3 127 83
2265 START 19 44 289
@@@ hidden_output
[t=65] fire 13
[t=125] fire 13
[t=185] fire 13
[t=245] fire 13
[t=269] fire 14
[t=302] fire 16
[t=305] fire 13
[t=319] fire 31
[t=337] fire 6
[t=339] fire 4
[t=365] fire 13
[t=408] fire 21
[t=418] fire 4
[t=425] fire 13
[t=467] fire 31
[t=468] fire 28
[t=485] fire 13
[t=497] fire 4
[t=505] fire 14
[t=545] fire 13
[t=574] fire 22
[t=589] fire 10
[t=596] fire 4
[t=605] fire 13
[t=615] fire 31
[t=623] fire 16
[t=665] fire 13
[t=715] fire 4
[t=725] fire 13
[t=726] fire 12
[t=741] fire 10
[t=742] fire 8
[t=770] fire 19
[t=785] fire 13
[t=797] fire 28
[t=834] fire 4
[t=845] fire 13
[t=858] fire 14
[t=874] fire 9
[t=875] fire 25
[t=944] fire 16
[t=953] fire 4
[t=967] fire 23
[t=982] fire 27
[t=1000] fire 31
[t=1017] fire 13
[t=1032] fire 25
[t=1040] fire 21
[t=1062] fire 0
[t=1071] fire 12
[t=1072] fire 4
[t=1088] fire 14
[t=1102] fire 19
[t=1107] fire 28
[t=1110] fire 5
[t=1170] fire 27
[t=1189] fire 25
[t=1190] fire 12
[t=1191] fire 8
[t=1192] fire 17
[t=1199] fire 24
[t=1265] fire 16
[t=1272] fire 17
[t=1281] fire 29
[t=1290] fire 23
[t=1309] fire 12
[t=1328] fire 26
[t=1335] fire 13
[t=1346] fire 25
[t=1352] fire 17
[t=1362] fire 31
[t=1373] fire 2
[t=1403] fire 10
[t=1428] fire 12
[t=1432] fire 17
[t=1434] fire 19
[t=1436] fire 29
[t=1444] fire 26
[t=1456] fire 24
[t=1484] fire 5
[t=1491] fire 23
[t=1503] fire 25
[t=1512] fire 17
[t=1514] fire 27
[t=1532] fire 19
[t=1583] fire 18
[t=1586] fire 16
[t=1591] fire 29
[t=1592] fire 17
[t=1607] fire 14
[t=1640] fire 8
[t=1651] fire 18
[t=1660] fire 25
[t=1672] fire 17
[t=1713] fire 24
[t=1719] fire 18
[t=1724] fire 31
[t=1726] fire 30
[t=1741] fire 15
[t=1742] fire 16
[t=1746] fire 29
[t=1752] fire 17
[t=1763] fire 5
[t=1773] fire 6
[t=1775] fire 8
[t=1778] fire 12
[t=1787] fire 18
[t=1788] fire 3
[t=1805] fire 10
[t=1814] fire 9
[t=1817] fire 25
[t=1826] fire 19
[t=1832] fire 17
[t=1855] fire 18
[t=1859] fire 15
[t=1901] fire 29
[t=1905] fire 2
[t=1912] fire 17
[t=1918] fire 14
[t=1923] fire 18
[t=1927] fire 12
[t=1939] fire 10
[t=1970] fire 24
[t=1974] fire 25
[t=1991] fire 18
[t=1992] fire 17
[t=1993] fire 30
[t=2046] fire 0
[t=2056] fire 29
[t=2058] fire 15
[t=2059] fire 18
[t=2066] fire 5
[t=2069] fire 26
[t=2072] fire 17
[t=2076] fire 12
[t=2083] fire 13
[t=2086] fire 31
[t=2087] fire 23
[t=2117] fire 20
[t=2120] fire 19
[t=2127] fire 18
[t=2152] fire 17
[t=2174] fire 25
[t=2179] fire 2
[t=2186] fire 1
[t=2211] fire 29
[t=2225] fire 11
[t=2227] fire 24
[t=2229] fire 14
[t=2232] fire 17
[t=2258] fire 13
[t=2260] fire 30
[t=2283] fire 23
[t=2285] fire 6
[t=2309] fire 19
[t=2312] fire 17
[t=2363] fire 15
[t=2366] fire 29
[t=2377] fire 3
[t=2383] fire 12
[t=2392] fire 17
[t=2429] fire 26
[t=2433] fire 13
[t=2455] fire 23
[t=2460] fire 3
[t=2472] fire 17
[t=2484] fire 24
[t=2521] fire 29
[t=2527] fire 30
[t=2540] fire 14
[t=2543] fire 3
[t=2552] fire 17
[t=2570] fire 12
[t=2581] fire 2
[t=2598] fire 19
[t=2608] fire 13
[t=2626] fire 3
[t=2627] fire 23
[t=2632] fire 17
[t=2676] fire 29
[t=2709] fire 3
[t=2712] fire 17
[t=2741] fire 24
[t=2757] fire 12
[t=2783] fire 13
[t=2789] fire 26
[t=2792] fire 3
[t=2792] fire 17
[t=2794] fire 30
[t=2799] fire 23
[t=2831] fire 29
[t=2851] fire 14
[t=2872] fire 17
[t=2875] fire 3
[t=2887] fire 19
[t=2944] fire 12
[t=2952] fire 17
[t=2958] fire 3
[t=2958] fire 13
[t=2971] fire 23
[t=2983] fire 2
[t=2986] fire 29
[t=2998] fire 24
[t=3032] fire 17
[t=3041] fire 3
[t=3061] fire 30
[t=3112] fire 17
[t=3124] fire 3
[t=3131] fire 12
[t=3133] fire 13
[t=3141] fire 29
[t=3143] fire 23
[t=3149] fire 26
[t=3162] fire 14
[t=3176] fire 19
[t=3192] fire 17
[t=3207] fire 3
[t=3255] fire 24
[t=3272] fire 17
[t=3290] fire 3
[t=3296] fire 29
[t=3308] fire 13
[t=3315] fire 23
[t=3318] fire 12
[t=3328] fire 30
[t=3352] fire 17
[t=3373] fire 3
[t=3385] fire 2
[t=3432] fire 17
[t=3451] fire 29
[t=3456] fire 3
[t=3465] fire 19
[t=3473] fire 14
[t=3483] fire 13
[t=3487] fire 23
[t=3505] fire 12
[t=3509] fire 26
[t=3512] fire 17
[t=3512] fire 24
[t=3539] fire 3
[t=3592] fire 17
[t=3595] fire 30
[t=3606] fire 29
[t=3622] fire 3
[t=3658] fire 13
[t=3659] fire 23
[t=3672] fire 17
[t=3692] fire 12
[t=3705] fire 3
[t=3752] fire 17
[t=3754] fire 19
[t=3761] fire 29
[t=3769] fire 24
[t=3784] fire 14
[t=3787] fire 2
[t=3788] fire 3
[t=3831] fire 23
[t=3832] fire 17
[t=3833] fire 13
[t=3862] fire 30
[t=3869] fire 26
[t=3871] fire 3
[t=3879] fire 12
[t=3912] fire 17
[t=3916] fire 29
[t=3954] fire 3
[t=3992] fire 17
[t=4003] fire 23
[t=4008] fire 13
[t=4026] fire 24
[t=4037] fire 3
[t=4043] fire 19
[t=4066] fire 12
[t=4071] fire 29
[t=4072] fire 17
[t=4095] fire 14
[t=4120] fire 3
[t=4129] fire 30
[t=4152] fire 17
[t=4175] fire 23
[t=4183] fire 13
[t=4189] fire 2
[t=4203] fire 3
[t=4226] fire 29
[t=4229] fire 26
[t=4232] fire 17
[t=4253] fire 12
[t=4283] fire 24
[t=4286] fire 3
[t=4312] fire 17
[t=4332] fire 19
[t=4347] fire 23
[t=4358] fire 13
[t=4369] fire 3
[t=4381] fire 29
[t=4392] fire 17
[t=4396] fire 30
[t=4406] fire 14
[t=4440] fire 12
[t=4452] fire 3
[t=4472] fire 17
[t=4519] fire 23
[t=4533] fire 13
[t=4535] fire 3
[t=4536] fire 29
[t=4540] fire 24
[t=4552] fire 17
[t=4589] fire 26
[t=4591] fire 2
[t=4618] fire 3
[t=4621] fire 19
[t=4627] fire 12
[t=4632] fire 17
[t=4663] fire 30
[t=4691] fire 23
[t=4691] fire 29
[t=4701] fire 3
[t=4708] fire 13
[t=4712] fire 17
[t=4717] fire 14
[t=4784] fire 3
[t=4792] fire 17
[t=4797] fire 24
[t=4814] fire 12
[t=4846] fire 29
[t=4863] fire 23
[t=4867] fire 3
[t=4872] fire 17
[t=4883] fire 13
[t=4910] fire 19
[t=4930] fire 30
[t=4949] fire 26
[t=4950] fire 3
[t=4952] fire 17
[t=4993] fire 2
[t=5001] fire 12
[t=5001] fire 29
[t=5028] fire 14
[t=5032] fire 17
[t=5033] fire 3
[t=5035] fire 23
[t=5054] fire 24
[t=5058] fire 13
[t=5112] fire 17
[t=5116] fire 3
[t=5156] fire 29
[t=5188] fire 12
[t=5192] fire 17
[t=5197] fire 30
[t=5199] fire 3
[t=5199] fire 19
[t=5207] fire 23
[t=5233] fire 13
[t=5272] fire 17
[t=5282] fire 3
[t=5309] fire 26
[t=5311] fire 24
[t=5311] fire 29
[t=5339] fire 14
[t=5352] fire 17
[t=5365] fire 3
[t=5375] fire 12
[t=5379] fire 23
[t=5395] fire 2
[t=5408] fire 13
[t=5432] fire 17
[t=5448] fire 3
[t=5464] fire 30
[t=5466] fire 29
[t=5488] fire 19
[t=5512] fire 17
[t=5531] fire 3
[t=5551] fire 23
[t=5562] fire 12
[t=5568] fire 24
[t=5583] fire 13
[t=5592] fire 17
[t=5614] fire 3
[t=5621] fire 29
[t=5650] fire 14
[t=5669] fire 26
[t=5672] fire 17
[t=5697] fire 3
[t=5723] fire 23
[t=5731] fire 30
[t=5749] fire 12
[t=5752] fire 17
[t=5758] fire 13
[t=5776] fire 29
[t=5777] fire 19
[t=5780] fire 3
[t=5797] fire 2
[t=5825] fire 24
[t=5832] fire 17
[t=5863] fire 3
[t=5895] fire 23
[t=5912] fire 17
[t=5931] fire 29
[t=5933] fire 13
[t=5936] fire 12
[t=5946] fire 3
[t=5961] fire 14
[t=5992] fire 17
[t=5998] fire 30
fires=404
timer expirations=397
wasted wakeups=0

@@@ hidden_input
6 100
10 START 0 30 0
10 START 1 40 0
11 STOP 0
12 STOP 1
50 START 2 7 7
70 STOP 2
@@@ hidden_output
[t=57] fire 2
[t=64] fire 2
fires=2
timer expirations=2
wasted wakeups=0
@@@ hint
Keep a table `{armed, due, period}` per id. After **every** change (start, stop, or a callback that fired timers), find the earliest `due` of all armed entries and re-program the one FreeRTOS timer (one-shot) with `xTimerChangePeriod(h, earliest - now, 0)`. If nothing is armed, `xTimerStop(h, 0)`.
@@@ hint
In the callback: `now = xTaskGetTickCount()`. Loop over the ids in increasing order and fire every armed entry with `due == now`. Then set `due += period`, or disarm it if `period == 0`. Finally re-program. From the callback, `xTimerChangePeriod()` is processed right after the callback returns, with "now" = the same tick, so the expiry is exactly `earliest`. Protect the table with `taskENTER_CRITICAL()` in `st_start`/`st_stop`.
@@@ solution_code
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"

void st_fired(int id);

#define ST_MAX 32

typedef struct {
    int        armed;
    TickType_t due;       /* absolute tick of the next fire */
    TickType_t period;    /* 0 = one-shot */
} SoftTimer;

static SoftTimer s_st[ST_MAX];
static TimerHandle_t s_hw;

/* Program the single FreeRTOS timer for the earliest due soft timer.
   Never blocks: the command is handled by the timer task (prio 7). */
static void reprogram(TickType_t now)
{
    int i, found = 0;
    TickType_t best = 0;

    for (i = 0; i < ST_MAX; i++) {
        if (s_st[i].armed && (!found || s_st[i].due < best)) {
            best = s_st[i].due;
            found = 1;
        }
    }
    if (found) {
        xTimerChangePeriod(s_hw, best - now, 0);   /* expiry = now + (best - now) = best */
    } else {
        xTimerStop(s_hw, 0);
    }
}

static void mux_cb(TimerHandle_t xTimer)
{
    TickType_t now = xTaskGetTickCount();
    int i;

    (void)xTimer;
    for (i = 0; i < ST_MAX; i++) {                   /* increasing id order */
        if (s_st[i].armed && s_st[i].due == now) {
            if (s_st[i].period) s_st[i].due += s_st[i].period;   /* no drift */
            else s_st[i].armed = 0;
            st_fired(i);
        }
    }
    reprogram(now);
}

void st_init(void)
{
    /* one-shot: it only ever runs up to the next due soft timer */
    s_hw = xTimerCreate("stmux", 1, pdFALSE, NULL, mux_cb);
}

void st_start(int id, TickType_t delay, TickType_t period)
{
    TickType_t now;

    taskENTER_CRITICAL();
    now = xTaskGetTickCount();
    s_st[id].armed = 1;
    s_st[id].due = now + delay;
    s_st[id].period = period;
    taskEXIT_CRITICAL();
    reprogram(now);
}

void st_stop(int id)
{
    int was_armed;

    taskENTER_CRITICAL();
    was_armed = s_st[id].armed;
    s_st[id].armed = 0;
    taskEXIT_CRITICAL();
    if (was_armed) reprogram(xTaskGetTickCount());
}
@@@ explanation_md
**Approach.** This is a *tickless* soft-timer service. The table holds an absolute `due` tick per soft timer. The single FreeRTOS timer is a one-shot that is always programmed for the **earliest** due time:
- **Start/stop** change the table. If that changes the earliest due time, `xTimerChangePeriod(h, earliest - now, 0)` moves the one-shot. The timer task (priority 7) preempts the caller and moves it before the call returns. If nothing is armed any more, the FreeRTOS timer is stopped. Otherwise it would wake up for nothing, and the harness counts that as a wasted wake-up.
- **Callback** at tick `now`: fire every entry with `due == now`, in increasing id order. Advance periodic entries by `period` (relative to `due`, not `now`, so there is no drift) and disarm one-shots. Then re-program. A command sent from inside the callback is handled right after the callback returns, with the same "now", so the next expiry is exact.

A sorted linked list (or a min-heap) with the earliest entry at the head makes "find the earliest" O(1). Insertion is then O(n) or O(log n). With 32 entries, the linear scan is simpler and fast enough. It also keeps the "increasing id" order at equal due times trivial.

**Complexity.** Linear table: O(N) per start/stop/expiry, with N = 32. Sorted list: O(1) to find the earliest, O(N) to insert. Heap: O(log N). Wake-ups: exactly one per distinct due tick. RAM: 12 bytes per soft timer and one FreeRTOS timer, instead of 32 timer control blocks.

**Common mistakes**
- A 1-tick auto-reload "polling" timer: simple, but it wakes the CPU 1000 times a second and kills low-power modes. The harness reports the wasted wake-ups.
- Not re-programming on `st_stop()` or on a re-arm to a *later* time: the FreeRTOS timer still expires at the old time and finds nothing due.
- Computing the next due time from `now` instead of from the previous `due`: periodic alarms drift whenever the callback runs late.
- Using `xTimerReset()` to re-program: it keeps the old period. You need `xTimerChangePeriod()` (or `xTimerChangePeriod()` plus a reload).
- Unsigned wrap-around: `best - now` is correct with `TickType_t` arithmetic, but comparing absolute `due` values breaks when the tick count wraps. Production code compares `(TickType_t)(due - now)` instead.
- Shared table without protection: `st_start()` runs in another task. Here, the only preemption point is the timer command, but on real hardware the tick interrupt can preempt a half-updated entry.

**Interview follow-ups**
- How does the FreeRTOS kernel itself solve the same problem for its own timers (two active lists, sorted by expiry, and the overflow list swap)?
- Make it O(log N) with a binary heap. How do you support `st_stop()` of an arbitrary id efficiently?
- How would you handle tick-count overflow (`TickType_t` wraps after 49.7 days at 1 kHz with 32 bits)?
- What changes if callbacks of the soft timers may call `st_start()`/`st_stop()` themselves (re-entrancy during the fire loop)?
