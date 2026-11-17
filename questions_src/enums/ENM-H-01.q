@@@ meta
id: ENM-H-01
topic: Enums
difficulty: Hard
type: FUNCTION
title: Table-Driven Cruise Control FSM With Action Function Pointers
tags: embedded, table-driven-fsm, function-pointers, designated-initializers, cruise-control, asked-in-automotive
@@@ statement_md
Implement the cruise-control state machine of an ECU as a **table-driven FSM**: a 2-D table `[state][event]` of `{ next state, action function }`, plus one generic dispatcher. The judge defines these types, so do not redefine them:

```c
typedef enum { CC_NO_TRANSITION = 0, CC_OFF, CC_STANDBY, CC_ACTIVE, CC_OVERRIDE, CC_STATE_COUNT } CcState;
typedef enum {
    CC_EV_MAIN_ON, CC_EV_MAIN_OFF, CC_EV_SET, CC_EV_RESUME, CC_EV_CANCEL,
    CC_EV_BRAKE, CC_EV_ACCEL_PRESS, CC_EV_ACCEL_RELEASE, CC_EVENT_COUNT
} CcEvent;
typedef enum { DR_OK, DR_IGNORED, DR_REJECTED, DR_BAD_EVENT, DR_BAD_STATE } DispatchResult;

typedef struct { CcState state; int set_speed; } Cruise;           /* set_speed 0 = none */
typedef int (*CcAction)(Cruise *cc, int arg);                      /* 0 = OK, non-zero = guard failed */
typedef struct { CcState next; CcAction action; } CcTransition;
```

`CC_NO_TRANSITION` is 0 on purpose. A table cell you do not initialize is zero-filled, so it reads as "event not handled in this state". It is **not** a real state.

**1. Write the table** `const CcTransition cc_table[CC_STATE_COUNT][CC_EVENT_COUNT]` (it may be `static`). Row `CC_NO_TRANSITION` stays empty:

| state | event | action | next |
|---|---|---|---|
| `OFF` | `MAIN_ON` | | `STANDBY` |
| `STANDBY` | `MAIN_OFF` | clear | `OFF` |
| `STANDBY` | `SET` | set | `ACTIVE` |
| `STANDBY` | `RESUME` | resume | `ACTIVE` |
| `ACTIVE` | `MAIN_OFF` | clear | `OFF` |
| `ACTIVE` | `SET` | set | `ACTIVE` |
| `ACTIVE` | `CANCEL`, `BRAKE` | | `STANDBY` |
| `ACTIVE` | `ACCEL_PRESS` | | `OVERRIDE` |
| `OVERRIDE` | `MAIN_OFF` | clear | `OFF` |
| `OVERRIDE` | `SET` | set | `ACTIVE` |
| `OVERRIDE` | `CANCEL`, `BRAKE` | | `STANDBY` |
| `OVERRIDE` | `ACCEL_RELEASE` | | `ACTIVE` |

Every other combination is unhandled.

**2. Write the actions.** `arg` is the event argument (the vehicle speed for `SET`, 0 otherwise). A failing action must not modify `*cc`.
- **clear**: `set_speed = 0`. It always succeeds.
- **set**: if `30 <= arg <= 180`, `set_speed = arg`, OK. Otherwise fail.
- **resume**: fail if `set_speed == 0`, otherwise OK.

**3. Implement** `DispatchResult cc_dispatch(Cruise *cc, int event, int arg);`, applying these checks in order:
1. If `cc->state` is not one of `CC_OFF..CC_OVERRIDE` (RAM corruption), set it to `CC_OFF`, set `set_speed = 0` and return `DR_BAD_STATE`. The event is **not** processed.
2. If `event` is not in `0 .. CC_EVENT_COUNT-1`, return `DR_BAD_EVENT`.
3. If the cell's `next` is `CC_NO_TRANSITION`, return `DR_IGNORED`.
4. If the cell has an action and it fails, return `DR_REJECTED`. The state is unchanged.
5. Otherwise set `cc->state = next` and return `DR_OK`.

**How it is tested.** The harness starts with `{ CC_OFF, 0 }` and reads one event per line: an event name (`SET` is followed by a speed), `RAW <int>` for a raw event number, or `CORRUPT <int>` to overwrite `cc.state` (no dispatch, no output). After every dispatch it prints `<event>: <RESULT> <STATE> set=<set_speed>`.

**Example**
```
Input:
6
MAIN_ON
SET 25
SET 100
ACCEL_PRESS
ACCEL_RELEASE
BRAKE

Output:
MAIN_ON: OK STANDBY set=0
SET: REJECTED STANDBY set=0
SET: OK ACTIVE set=100
ACCEL_PRESS: OK OVERRIDE set=100
ACCEL_RELEASE: OK ACTIVE set=100
BRAKE: OK STANDBY set=100
```
@@@ constraints_md
- `1 <= events <= 100`. `RAW` and `CORRUPT` values are any 32-bit `int`. `SET` speeds are in `-1000..1000`.
- The table must have exactly `CC_STATE_COUNT x CC_EVENT_COUNT` cells of type `CcTransition` (the harness checks with `_Static_assert`).
- `cc_dispatch` must not contain per-state logic. All behaviour comes from the table.
@@@ starter_code
/* Types are provided by the judge (see the statement). */
#include <stddef.h>

/* ---- actions: return 0 = OK, non-zero = guard failed (and change nothing) ---- */
static int act_clear(Cruise *cc, int arg)  { (void)cc; (void)arg; /* TODO */ return 0; }
static int act_set(Cruise *cc, int arg)    { (void)cc; (void)arg; /* TODO */ return 0; }
static int act_resume(Cruise *cc, int arg) { (void)cc; (void)arg; /* TODO */ return 0; }

/* ---- transition table: cc_table[current state][event] ---- */
const CcTransition cc_table[CC_STATE_COUNT][CC_EVENT_COUNT] = {
    [CC_OFF] = {
        [CC_EV_MAIN_ON] = { CC_STANDBY, NULL },
    },
    /* TODO: rows for CC_STANDBY, CC_ACTIVE and CC_OVERRIDE */
};

DispatchResult cc_dispatch(Cruise *cc, int event, int arg)
{
    /* TODO: validate state, validate event, look up the cell, run the action */
    (void)cc;
    (void)event;
    (void)arg;
    return DR_IGNORED;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>

typedef enum { CC_NO_TRANSITION = 0, CC_OFF, CC_STANDBY, CC_ACTIVE, CC_OVERRIDE, CC_STATE_COUNT } CcState;
typedef enum {
    CC_EV_MAIN_ON, CC_EV_MAIN_OFF, CC_EV_SET, CC_EV_RESUME, CC_EV_CANCEL,
    CC_EV_BRAKE, CC_EV_ACCEL_PRESS, CC_EV_ACCEL_RELEASE, CC_EVENT_COUNT
} CcEvent;
typedef enum { DR_OK, DR_IGNORED, DR_REJECTED, DR_BAD_EVENT, DR_BAD_STATE } DispatchResult;

typedef struct { CcState state; int set_speed; } Cruise;
typedef int (*CcAction)(Cruise *cc, int arg);
typedef struct { CcState next; CcAction action; } CcTransition;

/*USER_CODE*/

_Static_assert(sizeof cc_table / sizeof cc_table[0] == CC_STATE_COUNT, "cc_table needs CC_STATE_COUNT rows");
_Static_assert(sizeof cc_table[0] / sizeof cc_table[0][0] == CC_EVENT_COUNT, "cc_table needs CC_EVENT_COUNT columns");
_Static_assert(sizeof cc_table[0][0] == sizeof(CcTransition), "cc_table cells must be CcTransition");

static const char *const h_ev[CC_EVENT_COUNT] = {
    "MAIN_ON", "MAIN_OFF", "SET", "RESUME", "CANCEL", "BRAKE", "ACCEL_PRESS", "ACCEL_RELEASE"
};
static const char *const h_st[CC_STATE_COUNT] = { "NONE", "OFF", "STANDBY", "ACTIVE", "OVERRIDE" };
static const char *const h_dr[5] = { "OK", "IGNORED", "REJECTED", "BAD_EVENT", "BAD_STATE" };

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    Cruise cc = { CC_OFF, 0 };
    for (int i = 0; i < n; i++) {
        char tok[24], label[40];
        int ev = -1, arg = 0;
        if (scanf("%23s", tok) != 1) return 0;
        if (strcmp(tok, "CORRUPT") == 0) {
            int v;
            if (scanf("%d", &v) != 1) return 0;
            cc.state = (CcState)v;
            continue;
        }
        if (strcmp(tok, "RAW") == 0) {
            if (scanf("%d", &ev) != 1) return 0;
            snprintf(label, sizeof label, "RAW(%d)", ev);
        } else {
            for (int e = 0; e < CC_EVENT_COUNT; e++)
                if (strcmp(tok, h_ev[e]) == 0) ev = e;
            if (ev < 0) return 0;
            if (ev == CC_EV_SET && scanf("%d", &arg) != 1) return 0;
            snprintf(label, sizeof label, "%s", tok);
        }
        DispatchResult r = cc_dispatch(&cc, ev, arg);
        unsigned ri = (unsigned)r, si = (unsigned)cc.state;
        printf("%s: %s %s set=%d\n", label, ri < 5u ? h_dr[ri] : "BAD_RESULT",
               (si >= 1u && si < (unsigned)CC_STATE_COUNT) ? h_st[si] : "CORRUPT", cc.set_speed);
    }
    return 0;
}
@@@ sample_input
6
MAIN_ON
SET 25
SET 100
ACCEL_PRESS
ACCEL_RELEASE
BRAKE
@@@ sample_output
MAIN_ON: OK STANDBY set=0
SET: REJECTED STANDBY set=0
SET: OK ACTIVE set=100
ACCEL_PRESS: OK OVERRIDE set=100
ACCEL_RELEASE: OK ACTIVE set=100
BRAKE: OK STANDBY set=100

@@@ sample_input
6
RESUME
MAIN_ON
RESUME
RAW 8
CORRUPT 9
CANCEL
@@@ sample_output
RESUME: IGNORED OFF set=0
MAIN_ON: OK STANDBY set=0
RESUME: REJECTED STANDBY set=0
RAW(8): BAD_EVENT STANDBY set=0
CANCEL: BAD_STATE OFF set=0

@@@ hidden_input
8
MAIN_ON
SET 120
CANCEL
RESUME
ACCEL_PRESS
SET 140
MAIN_OFF
MAIN_ON
@@@ hidden_output
MAIN_ON: OK STANDBY set=0
SET: OK ACTIVE set=120
CANCEL: OK STANDBY set=120
RESUME: OK ACTIVE set=120
ACCEL_PRESS: OK OVERRIDE set=120
SET: OK ACTIVE set=140
MAIN_OFF: OK OFF set=0
MAIN_ON: OK STANDBY set=0

@@@ hidden_input
7
MAIN_ON
SET 29
SET 30
SET 180
SET 181
SET -5
RESUME
@@@ hidden_output
MAIN_ON: OK STANDBY set=0
SET: REJECTED STANDBY set=0
SET: OK ACTIVE set=30
SET: OK ACTIVE set=180
SET: REJECTED ACTIVE set=180
SET: REJECTED ACTIVE set=180
RESUME: IGNORED ACTIVE set=180

@@@ hidden_input
6
RAW -1
RAW 2147483647
MAIN_ON
RAW 0
RAW 7
RAW 8
@@@ hidden_output
RAW(-1): BAD_EVENT OFF set=0
RAW(2147483647): BAD_EVENT OFF set=0
MAIN_ON: OK STANDBY set=0
RAW(0): IGNORED STANDBY set=0
RAW(7): IGNORED STANDBY set=0
RAW(8): BAD_EVENT STANDBY set=0

@@@ hidden_input
7
MAIN_ON
SET 50
CORRUPT 0
BRAKE
MAIN_ON
CORRUPT 5
MAIN_ON
@@@ hidden_output
MAIN_ON: OK STANDBY set=0
SET: OK ACTIVE set=50
BRAKE: BAD_STATE OFF set=0
MAIN_ON: OK STANDBY set=0
MAIN_ON: BAD_STATE OFF set=0

@@@ hidden_input
3
CORRUPT -3
ACCEL_PRESS
ACCEL_PRESS
@@@ hidden_output
ACCEL_PRESS: BAD_STATE OFF set=0
ACCEL_PRESS: IGNORED OFF set=0

@@@ hidden_input
8
BRAKE
MAIN_ON
BRAKE
SET 90
ACCEL_RELEASE
ACCEL_PRESS
ACCEL_PRESS
CANCEL
@@@ hidden_output
BRAKE: IGNORED OFF set=0
MAIN_ON: OK STANDBY set=0
BRAKE: IGNORED STANDBY set=0
SET: OK ACTIVE set=90
ACCEL_RELEASE: IGNORED ACTIVE set=90
ACCEL_PRESS: OK OVERRIDE set=90
ACCEL_PRESS: IGNORED OVERRIDE set=90
CANCEL: OK STANDBY set=90

@@@ hidden_input
7
MAIN_ON
SET 60
ACCEL_PRESS
MAIN_OFF
RESUME
MAIN_ON
RESUME
@@@ hidden_output
MAIN_ON: OK STANDBY set=0
SET: OK ACTIVE set=60
ACCEL_PRESS: OK OVERRIDE set=60
MAIN_OFF: OK OFF set=0
RESUME: IGNORED OFF set=0
MAIN_ON: OK STANDBY set=0
RESUME: REJECTED STANDBY set=0

@@@ hint
Nested designated initializers keep the table readable and order-independent: `[CC_ACTIVE] = { [CC_EV_BRAKE] = { CC_STANDBY, NULL }, [CC_EV_SET] = { CC_ACTIVE, act_set }, ... }`. Every cell you leave out is `{ CC_NO_TRANSITION, NULL }`.
@@@ hint
In the dispatcher, validate **before** indexing: `(unsigned)cc->state - CC_OFF < CC_OVERRIDE - CC_OFF + 1` (or two plain comparisons on an `int` copy) and `event >= 0 && event < CC_EVENT_COUNT`. Then `const CcTransition *t = &cc_table[cc->state][event];`. Only assign `cc->state = t->next` after the action returned 0.
@@@ solution_code
#include <stddef.h>

/* ---- actions: return 0 = OK, non-zero = guard failed (and change nothing) ---- */
static int act_clear(Cruise *cc, int arg)
{
    (void)arg;
    cc->set_speed = 0;
    return 0;
}

static int act_set(Cruise *cc, int arg)
{
    if (arg < 30 || arg > 180)
        return 1;                     /* outside the allowed set-speed window */
    cc->set_speed = arg;
    return 0;
}

static int act_resume(Cruise *cc, int arg)
{
    (void)arg;
    return cc->set_speed == 0;        /* nothing stored to resume to */
}

/* ---- transition table: cc_table[current state][event] ---- */
const CcTransition cc_table[CC_STATE_COUNT][CC_EVENT_COUNT] = {
    /* row CC_NO_TRANSITION intentionally empty */
    [CC_OFF] = {
        [CC_EV_MAIN_ON]       = { CC_STANDBY,  NULL       },
    },
    [CC_STANDBY] = {
        [CC_EV_MAIN_OFF]      = { CC_OFF,      act_clear  },
        [CC_EV_SET]           = { CC_ACTIVE,   act_set    },
        [CC_EV_RESUME]        = { CC_ACTIVE,   act_resume },
    },
    [CC_ACTIVE] = {
        [CC_EV_MAIN_OFF]      = { CC_OFF,      act_clear  },
        [CC_EV_SET]           = { CC_ACTIVE,   act_set    },
        [CC_EV_CANCEL]        = { CC_STANDBY,  NULL       },
        [CC_EV_BRAKE]         = { CC_STANDBY,  NULL       },
        [CC_EV_ACCEL_PRESS]   = { CC_OVERRIDE, NULL       },
    },
    [CC_OVERRIDE] = {
        [CC_EV_MAIN_OFF]      = { CC_OFF,      act_clear  },
        [CC_EV_SET]           = { CC_ACTIVE,   act_set    },
        [CC_EV_CANCEL]        = { CC_STANDBY,  NULL       },
        [CC_EV_BRAKE]         = { CC_STANDBY,  NULL       },
        [CC_EV_ACCEL_RELEASE] = { CC_ACTIVE,   NULL       },
    },
};

DispatchResult cc_dispatch(Cruise *cc, int event, int arg)
{
    const int s = (int)cc->state;

    if (s < (int)CC_OFF || s > (int)CC_OVERRIDE) {    /* corrupted: go to the safe state */
        cc->state = CC_OFF;
        cc->set_speed = 0;
        return DR_BAD_STATE;
    }
    if (event < 0 || event >= (int)CC_EVENT_COUNT)    /* never index with a raw value */
        return DR_BAD_EVENT;

    const CcTransition *t = &cc_table[s][event];
    if (t->next == CC_NO_TRANSITION)
        return DR_IGNORED;
    if (t->action != NULL && t->action(cc, arg) != 0)
        return DR_REJECTED;                            /* guard failed: state unchanged */

    cc->state = t->next;
    return DR_OK;
}
@@@ explanation_md
**Approach.** A table-driven FSM separates **what** the machine does (data: the `[state][event]` table) from **how** it runs (a generic dispatcher of about ten lines). The table reads exactly like the requirements table, so a reviewer can compare them cell by cell, and adding an event never touches the dispatcher.

- **Designated initializers** (`[CC_ACTIVE] = { [CC_EV_BRAKE] = {...} }`) make each cell order-independent. Every cell you do not write is zero-filled.
- **`CC_NO_TRANSITION = 0`** is what makes zero-filling safe. An empty cell is `{ CC_NO_TRANSITION, NULL }`, which the dispatcher treats as "ignore". If `CC_OFF` were 0, every forgotten cell would silently mean "go to OFF". It is the same idea as reserving 0 for "invalid" in protocol enums.
- **Actions double as guards.** They return non-zero to veto the transition, and they must only change data after the guard has passed, so a rejected `SET` leaves `set_speed` intact.
- **Defensive dispatch.** `cc->state` and `event` are both integers that can hold any value, and they are used as array indices. Both are range-checked first. A corrupted state forces the safe state, `CC_OFF`, as it should in a function with ASIL relevance.

**Complexity.** Time O(1) per event. Space O(S·E) for the table: 5 × 8 cells of 16 bytes = 640 bytes of flash, because the table is `const`.

**Common mistakes**
- Indexing `cc_table[cc->state][event]` before validating. `RAW 8`, `RAW -1` or `CORRUPT 9` then read outside the table, and on hardware they jump through a garbage function pointer.
- Checking `event > CC_EVENT_COUNT` (off by one), which lets the sentinel through.
- Committing `cc->state = t->next` before calling the action, so a rejected `SET` still activates cruise.
- Forgetting the self-transition `ACTIVE + SET -> ACTIVE` (re-set while cruising) or the `OVERRIDE + SET` cell.
- Making the table non-`const`. It then lives in RAM, where a stray write can corrupt function pointers. As `const` it goes to flash.

**Interview follow-ups**
- Add entry and exit actions per state (for example "enable throttle actuator on entering `ACTIVE`"). Where do they go in this design?
- How would you unit-test full transition coverage automatically, by iterating over every `(state, event)` pair?
- The table holds function pointers. Why might a safety standard forbid that, and what would you use instead? (An action enum plus a `switch`, or a checked index into a `const` action table.)
- What changes if an event can be posted from an ISR while the dispatcher runs in a task? (Event queue, run-to-completion semantics.)
