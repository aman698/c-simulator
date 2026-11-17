@@@ meta
id: ENM-H-05
topic: Enums
difficulty: Hard
type: CODE
title: Battery Charger State Machine With Fault Latch and Hysteresis
tags: embedded, bms, state-machine, fault-handling, hysteresis, ev-charging
@@@ statement_md
Implement the charge-control state machine of a Li-ion battery management system (BMS). States:

```c
typedef enum { CHG_IDLE, CHG_PRECHARGE, CHG_CC, CHG_CV, CHG_DONE, CHG_FAULT, CHG_STATE_COUNT } ChgState;
```

The BMS starts in `IDLE`. Every input line is one measurement sample `t V I T P`: time in ms, highest cell voltage in mV, charge current in mA, temperature in °C, and charger plugged (1) or not (0).

For each sample, apply the **first** matching rule from this list. At most **one** transition happens per sample, and every state entry records `t_enter = t`.

1. **Unplugged** (`P == 0`): any state other than `IDLE` goes to `IDLE` with reason `UNPLUGGED`. Stop.
2. **Fault latch**: in `FAULT`, stay. Only unplugging leaves `FAULT`. Stop.
3. **Fault checks**, in this order, in every other state:
   `T > 55` → `OVERTEMP`; `T < 0` → `UNDERTEMP`; `V > 4250` → `OVERVOLTAGE`;
   in `PRECHARGE` only: `t - t_enter >= 600000` → `PRECHARGE_TIMEOUT`. Go to `FAULT`. Stop.
4. **Normal transitions:**

| state | condition | next |
|---|---|---|
| `IDLE` | (plugged) `V < 3000` | `PRECHARGE` |
| `IDLE` | (plugged) `V >= 3000` | `CC` |
| `PRECHARGE` | `V >= 3000` | `CC` |
| `CC` | `V >= 4200` | `CV` |
| `CV` | `I <= 100` | `DONE` |
| `DONE` | `V < 4100` (recharge hysteresis) | `CC` |

**Output**
- Normal transition: `<t>: <FROM> -> <TO>`
- Fault: `<t>: <FROM> -> FAULT (<REASON>)`
- Unplug: `<t>: <FROM> -> IDLE (UNPLUGGED)`
- At the end: `final <STATE>`

**Input**
- Line 1: `n`. Next `n` lines: `t V I T P` (integers, `t` non-decreasing).

**Example**
```
Input:
5
0 2500 0 20 1
100000 2900 300 22 1
200000 3100 300 60 1
300000 3100 0 25 1
400000 3100 0 25 0

Output:
0: IDLE -> PRECHARGE
200000: PRECHARGE -> FAULT (OVERTEMP)
400000: FAULT -> IDLE (UNPLUGGED)
final IDLE
```
@@@ constraints_md
- `0 <= n <= 1000`, `0 <= t <= 2*10^9`
- `0 <= V <= 5000`, `0 <= I <= 100000`, `-40 <= T <= 125`, `P` is 0 or 1.
@@@ starter_code
#include <stdio.h>

typedef enum { CHG_IDLE, CHG_PRECHARGE, CHG_CC, CHG_CV, CHG_DONE, CHG_FAULT, CHG_STATE_COUNT } ChgState;

static const char *const chg_name[CHG_STATE_COUNT] = { "IDLE", "PRECHARGE", "CC", "CV", "DONE", "FAULT" };

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    ChgState state = CHG_IDLE;
    int t_enter = 0;

    for (int i = 0; i < n; i++) {
        int t, v, cur, temp, plugged;
        if (scanf("%d %d %d %d %d", &t, &v, &cur, &temp, &plugged) != 5) break;
        /* TODO: rules 1..4, at most one transition per sample */
    }
    printf("final %s\n", chg_name[state]);
    (void)t_enter;
    return 0;
}
@@@ sample_input
5
0 2500 0 20 1
100000 2900 300 22 1
200000 3100 300 60 1
300000 3100 0 25 1
400000 3100 0 25 0
@@@ sample_output
0: IDLE -> PRECHARGE
200000: PRECHARGE -> FAULT (OVERTEMP)
400000: FAULT -> IDLE (UNPLUGGED)
final IDLE

@@@ sample_input
7
0 3800 0 25 0
1000 3800 0 25 1
2000 4100 2000 30 1
3000 4200 1800 32 1
4000 4205 500 31 1
5000 4206 100 30 1
6000 4180 0 28 1
@@@ sample_output
1000: IDLE -> CC
3000: CC -> CV
5000: CV -> DONE
final DONE

@@@ hidden_input
3
1000 2000 100 25 1
600999 2900 100 25 1
601000 2950 100 25 1
@@@ hidden_output
1000: IDLE -> PRECHARGE
601000: PRECHARGE -> FAULT (PRECHARGE_TIMEOUT)
final FAULT

@@@ hidden_input
2
0 2999 0 25 1
600000 3000 0 25 1
@@@ hidden_output
0: IDLE -> PRECHARGE
600000: PRECHARGE -> FAULT (PRECHARGE_TIMEOUT)
final FAULT

@@@ hidden_input
6
0 4210 0 25 1
10 4210 1500 25 1
20 4210 90 25 1
30 4100 0 25 1
40 4099 0 25 1
50 4150 1500 25 1
@@@ hidden_output
0: IDLE -> CC
10: CC -> CV
20: CV -> DONE
40: DONE -> CC
final CC

@@@ hidden_input
3
0 4300 0 70 1
10 4300 0 70 0
20 3500 0 -5 1
@@@ hidden_output
0: IDLE -> FAULT (OVERTEMP)
10: FAULT -> IDLE (UNPLUGGED)
20: IDLE -> FAULT (UNDERTEMP)
final FAULT

@@@ hidden_input
4
0 3500 1000 55 1
10 4250 1000 0 1
20 4250 50 0 1
30 4251 0 20 1
@@@ hidden_output
0: IDLE -> CC
10: CC -> CV
20: CV -> DONE
30: DONE -> FAULT (OVERVOLTAGE)
final FAULT

@@@ hidden_input
0
@@@ hidden_output
final IDLE

@@@ hidden_input
4
0 3600 0 25 1
10 3600 1000 25 0
20 3600 0 25 0
30 2800 0 25 1
@@@ hidden_output
0: IDLE -> CC
10: CC -> IDLE (UNPLUGGED)
30: IDLE -> PRECHARGE
final PRECHARGE

@@@ hidden_input
4
0 2000 0 25 1
500000 2000 0 25 0
500001 2000 0 25 1
1000000 2000 0 25 1
@@@ hidden_output
0: IDLE -> PRECHARGE
500000: PRECHARGE -> IDLE (UNPLUGGED)
500001: IDLE -> PRECHARGE
final PRECHARGE

@@@ hint
Write the per-sample logic as a function `ChgState step(...)` with early `return`s in the exact priority order of the statement: unplug, fault latch, fault checks, normal transitions. A second enum for fault reasons (`FLT_NONE, FLT_OVERTEMP, ...`) plus its name table keeps the printing in one place.
@@@ hint
Remember `t_enter` on **every** state entry. The precharge timeout is `t - t_enter >= 600000`, and it is a fault check, so it wins over "voltage reached 3000" in the same sample.
@@@ solution_code
#include <stdio.h>

typedef enum { CHG_IDLE, CHG_PRECHARGE, CHG_CC, CHG_CV, CHG_DONE, CHG_FAULT, CHG_STATE_COUNT } ChgState;
typedef enum { FLT_NONE, FLT_UNPLUGGED, FLT_OVERTEMP, FLT_UNDERTEMP, FLT_OVERVOLTAGE, FLT_PRECHARGE_TIMEOUT } ChgReason;

static const char *const chg_name[CHG_STATE_COUNT] = { "IDLE", "PRECHARGE", "CC", "CV", "DONE", "FAULT" };
static const char *const reason_name[] = { "", "UNPLUGGED", "OVERTEMP", "UNDERTEMP", "OVERVOLTAGE", "PRECHARGE_TIMEOUT" };

#define T_MAX_C            55
#define T_MIN_C            0
#define V_MAX_MV           4250
#define V_PRECHARGE_MV     3000
#define V_CV_MV            4200
#define V_RECHARGE_MV      4100
#define I_TAPER_MA         100
#define PRECHARGE_LIMIT_MS 600000

static ChgState state = CHG_IDLE;
static int t_enter = 0;

/* Returns the next state; *why is set for unplug/fault transitions. */
static ChgState step(int t, int v, int cur, int temp, int plugged, ChgReason *why)
{
    *why = FLT_NONE;
    if (!plugged) {                                         /* 1) unplug */
        if (state != CHG_IDLE) *why = FLT_UNPLUGGED;
        return CHG_IDLE;
    }
    if (state == CHG_FAULT) return CHG_FAULT;               /* 2) latched */

    if (temp > T_MAX_C)       *why = FLT_OVERTEMP;          /* 3) fault checks, in order */
    else if (temp < T_MIN_C)  *why = FLT_UNDERTEMP;
    else if (v > V_MAX_MV)    *why = FLT_OVERVOLTAGE;
    else if (state == CHG_PRECHARGE && t - t_enter >= PRECHARGE_LIMIT_MS) *why = FLT_PRECHARGE_TIMEOUT;
    if (*why != FLT_NONE) return CHG_FAULT;

    switch (state) {                                        /* 4) normal transitions */
    case CHG_IDLE:      return v < V_PRECHARGE_MV ? CHG_PRECHARGE : CHG_CC;
    case CHG_PRECHARGE: return v >= V_PRECHARGE_MV ? CHG_CC : CHG_PRECHARGE;
    case CHG_CC:        return v >= V_CV_MV ? CHG_CV : CHG_CC;
    case CHG_CV:        return cur <= I_TAPER_MA ? CHG_DONE : CHG_CV;
    case CHG_DONE:      return v < V_RECHARGE_MV ? CHG_CC : CHG_DONE;
    case CHG_FAULT:     return CHG_FAULT;
    case CHG_STATE_COUNT: break;
    }
    return CHG_FAULT;                                       /* corrupted state: fail safe */
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    for (int i = 0; i < n; i++) {
        int t, v, cur, temp, plugged;
        if (scanf("%d %d %d %d %d", &t, &v, &cur, &temp, &plugged) != 5) break;

        ChgReason why;
        ChgState next = step(t, v, cur, temp, plugged, &why);
        if (next != state) {
            if (why != FLT_NONE)
                printf("%d: %s -> %s (%s)\n", t, chg_name[state], chg_name[next], reason_name[why]);
            else
                printf("%d: %s -> %s\n", t, chg_name[state], chg_name[next]);
            state = next;
            t_enter = t;                                    /* every entry restarts the state timer */
        }
    }
    printf("final %s\n", chg_name[state]);
    return 0;
}
@@@ explanation_md
**Approach.** Safety-relevant state machines are mostly about **priority**. The rules are evaluated top-down with early returns:
1. Unplugging overrides everything, because the hardware path is gone.
2. `FAULT` is **latched**. Even if the temperature recovers, charging must not restart by itself, and only a deliberate user action (unplugging) clears it.
3. Fault checks run in every operational state, before any normal transition. So a sample that is both "voltage reached 3000 mV" and "precharge timed out" is a fault (hidden boundary test).
4. Only then do the normal charge-profile transitions run. `DONE -> CC` uses a lower threshold (4100 mV) than `CC -> CV` (4200 mV). This **hysteresis** stops the charger from toggling every sample around a single threshold.

A second enum, `ChgReason`, keeps the "why" separate from the "where to". The per-state timer is simply `t_enter`, set on **every** entry, so re-entering `PRECHARGE` after an unplug restarts the 10-minute limit.

**Complexity.** Time O(n), space O(1).

**Common mistakes**
- Checking the normal transitions before the faults. An over-temperature in `CC` with `V >= 4200` would then go to `CV` and keep charging.
- Not latching `FAULT`. The temperature drops back to 54 °C and charging restarts on its own, which is unacceptable in a battery system.
- `>` instead of `>=` for the precharge timeout, or not resetting `t_enter` on re-entry.
- Using one threshold for both `CC -> CV` and recharge, which causes chattering between `DONE` and `CC`.
- Allowing two transitions per sample (for example `IDLE -> PRECHARGE -> CC` in one step), which skips the entry actions of the intermediate state.

**Interview follow-ups**
- Real BMSs debounce fault conditions (for example over-temperature for 3 consecutive samples). Where would you add that without breaking the latch?
- How would you derate the charge current between 45 °C and 55 °C instead of stopping hard? Is that a new state or a parameter of `CC`?
- Which of these checks would you duplicate in an independent monitoring path (ASIL decomposition), and why?
- How should the BMS report the latched fault: a DTC, a CAN signal to the charger (ISO 15118 / CHAdeMO), or both?
