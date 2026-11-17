@@@ meta
id: ENM-H-07
topic: Enums
difficulty: Hard
type: FIND_THE_BUG
title: Parking Brake Table FSM Indexed With an Unchecked Event
tags: embedded, table-driven-fsm, out-of-bounds, count-sentinel, input-validation, electric-parking-brake
@@@ statement_md
The electric parking brake (EPB) ECU runs a table-driven state machine. Events arrive as **raw numbers** in a CAN message from the switch module and the gateway:

| raw | event |
|---|---|
| 0 | `SW_PULL` (driver pulls the EPB switch) |
| 1 | `SW_PUSH` (driver pushes the switch) |
| 2 | `MOTOR_DONE` (caliper motor finished) |
| 3 | `DRIVE_AWAY` (drive-away release request) |

Intended behaviour, per state (anything not listed: no action, same state):
- `RELEASED`: `SW_PULL` → *motor apply* → `APPLYING`
- `APPLYING`: `SW_PUSH` → *motor release* → `RELEASING`; `MOTOR_DONE` → *lamp ON* → `APPLIED`
- `APPLIED`: `SW_PUSH` or `DRIVE_AWAY` → *motor release* → `RELEASING`
- `RELEASING`: `SW_PULL` → *motor apply* → `APPLYING`; `MOTOR_DONE` → *lamp OFF* → `RELEASED`

Every action prints `<t>: <action>`, then every state change prints `<t>: <FROM> -> <TO>`. Any raw value that is not one of the four events must print `<t>: invalid event <raw>` and change nothing. At the end the program prints `final <STATE>`.

A fuzz test on the CAN input found that some garbage values make the brake **change state with no driver request**, and in one state the fuzzer reports a memory error. Find and fix the bug.

**Input**
- Line 1: `n`. Next `n` lines: `t raw`.

**Example**
```
Input:
3
0 4
10 -1
20 0

Output:
0: invalid event 4
10: invalid event -1
20: motor apply
20: RELEASED -> APPLYING
final APPLYING
```
@@@ constraints_md
- `0 <= n <= 1000`. `raw` is any 32-bit `int`. `t` is non-decreasing.
- The fix is one character.
@@@ starter_code
#include <stdio.h>
#include <stddef.h>

typedef enum { EPB_RELEASED, EPB_APPLYING, EPB_APPLIED, EPB_RELEASING, EPB_STATE_COUNT } EpbState;
typedef enum { EV_SW_PULL, EV_SW_PUSH, EV_MOTOR_DONE, EV_DRIVE_AWAY, EV_EVENT_COUNT } EpbEvent;

typedef void (*EpbAction)(int t);
typedef struct { EpbState next; EpbAction action; } EpbTransition;

static void motor_apply(int t)   { printf("%d: motor apply\n", t); }
static void motor_release(int t) { printf("%d: motor release\n", t); }
static void lamp_on(int t)       { printf("%d: lamp ON\n", t); }
static void lamp_off(int t)      { printf("%d: lamp OFF\n", t); }

static const char *const state_name[EPB_STATE_COUNT] = { "RELEASED", "APPLYING", "APPLIED", "RELEASING" };

static const EpbTransition epb_table[EPB_STATE_COUNT][EV_EVENT_COUNT] = {
    /*               SW_PULL                         SW_PUSH                           MOTOR_DONE                    DRIVE_AWAY */
    [EPB_RELEASED]  = { { EPB_APPLYING, motor_apply }, { EPB_RELEASED, NULL },            { EPB_RELEASED, NULL },     { EPB_RELEASED, NULL } },
    [EPB_APPLYING]  = { { EPB_APPLYING, NULL },        { EPB_RELEASING, motor_release },  { EPB_APPLIED, lamp_on },   { EPB_APPLYING, NULL } },
    [EPB_APPLIED]   = { { EPB_APPLIED, NULL },         { EPB_RELEASING, motor_release },  { EPB_APPLIED, NULL },      { EPB_RELEASING, motor_release } },
    [EPB_RELEASING] = { { EPB_APPLYING, motor_apply }, { EPB_RELEASING, NULL },           { EPB_RELEASED, lamp_off }, { EPB_RELEASING, NULL } },
};

static EpbState state = EPB_RELEASED;

static void dispatch(int t, int ev)
{
    if (ev < 0 || ev > EV_EVENT_COUNT) {
        printf("%d: invalid event %d\n", t, ev);
        return;
    }
    const EpbTransition *tr = &epb_table[state][ev];
    if (tr->action != NULL)
        tr->action(t);
    if (tr->next != state)
        printf("%d: %s -> %s\n", t, state_name[state], state_name[tr->next]);
    state = tr->next;
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    for (int i = 0; i < n; i++) {
        int t, raw;
        if (scanf("%d %d", &t, &raw) != 2) break;
        dispatch(t, raw);
    }
    printf("final %s\n", state_name[state]);
    return 0;
}
@@@ sample_input
4
0 0
100 2
2000 1
2100 2
@@@ sample_output
0: motor apply
0: RELEASED -> APPLYING
100: lamp ON
100: APPLYING -> APPLIED
2000: motor release
2000: APPLIED -> RELEASING
2100: lamp OFF
2100: RELEASING -> RELEASED
final RELEASED

@@@ sample_input
3
0 4
10 -1
20 0
@@@ sample_output
0: invalid event 4
10: invalid event -1
20: motor apply
20: RELEASED -> APPLYING
final APPLYING

@@@ hidden_input
3
0 0
50 2
500 3
@@@ hidden_output
0: motor apply
0: RELEASED -> APPLYING
50: lamp ON
50: APPLYING -> APPLIED
500: motor release
500: APPLIED -> RELEASING
final RELEASING

@@@ hidden_input
3
0 0
10 1
20 2
@@@ hidden_output
0: motor apply
0: RELEASED -> APPLYING
10: motor release
10: APPLYING -> RELEASING
20: lamp OFF
20: RELEASING -> RELEASED
final RELEASED

@@@ hidden_input
3
0 0
10 4
20 2
@@@ hidden_output
0: motor apply
0: RELEASED -> APPLYING
10: invalid event 4
20: lamp ON
20: APPLYING -> APPLIED
final APPLIED

@@@ hidden_input
2
0 255
5 2147483647
@@@ hidden_output
0: invalid event 255
5: invalid event 2147483647
final RELEASED

@@@ hidden_input
3
0 0
10 2
20 4
@@@ hidden_output
0: motor apply
0: RELEASED -> APPLYING
10: lamp ON
10: APPLYING -> APPLIED
20: invalid event 4
final APPLIED

@@@ hidden_input
4
0 1
1 2
2 3
3 1
@@@ hidden_output
final RELEASED

@@@ hidden_input
0
@@@ hidden_output
final RELEASED

@@@ hidden_input
4
0 0
10 2
20 1
30 0
@@@ hidden_output
0: motor apply
0: RELEASED -> APPLYING
10: lamp ON
10: APPLYING -> APPLIED
20: motor release
20: APPLIED -> RELEASING
30: motor apply
30: RELEASING -> APPLYING
final APPLYING

@@@ hint
The table itself matches the requirements. Look at the one place where a raw number from the CAN bus becomes an array index. Which raw value gets past the check but is **not** an event?
@@@ hint
`EV_EVENT_COUNT` is a sentinel equal to the number of events (4), so the valid indices are 0..3. With `ev == 4`, `epb_table[state][4]` silently reads the **next row's** first cell. In the last row it reads past the end of the whole table.
@@@ solution_code
#include <stdio.h>
#include <stddef.h>

typedef enum { EPB_RELEASED, EPB_APPLYING, EPB_APPLIED, EPB_RELEASING, EPB_STATE_COUNT } EpbState;
typedef enum { EV_SW_PULL, EV_SW_PUSH, EV_MOTOR_DONE, EV_DRIVE_AWAY, EV_EVENT_COUNT } EpbEvent;

typedef void (*EpbAction)(int t);
typedef struct { EpbState next; EpbAction action; } EpbTransition;

static void motor_apply(int t)   { printf("%d: motor apply\n", t); }
static void motor_release(int t) { printf("%d: motor release\n", t); }
static void lamp_on(int t)       { printf("%d: lamp ON\n", t); }
static void lamp_off(int t)      { printf("%d: lamp OFF\n", t); }

static const char *const state_name[EPB_STATE_COUNT] = { "RELEASED", "APPLYING", "APPLIED", "RELEASING" };

static const EpbTransition epb_table[EPB_STATE_COUNT][EV_EVENT_COUNT] = {
    /*               SW_PULL                         SW_PUSH                           MOTOR_DONE                    DRIVE_AWAY */
    [EPB_RELEASED]  = { { EPB_APPLYING, motor_apply }, { EPB_RELEASED, NULL },            { EPB_RELEASED, NULL },     { EPB_RELEASED, NULL } },
    [EPB_APPLYING]  = { { EPB_APPLYING, NULL },        { EPB_RELEASING, motor_release },  { EPB_APPLIED, lamp_on },   { EPB_APPLYING, NULL } },
    [EPB_APPLIED]   = { { EPB_APPLIED, NULL },         { EPB_RELEASING, motor_release },  { EPB_APPLIED, NULL },      { EPB_RELEASING, motor_release } },
    [EPB_RELEASING] = { { EPB_APPLYING, motor_apply }, { EPB_RELEASING, NULL },           { EPB_RELEASED, lamp_off }, { EPB_RELEASING, NULL } },
};

static EpbState state = EPB_RELEASED;

static void dispatch(int t, int ev)
{
    if (ev < 0 || ev >= EV_EVENT_COUNT) {   /* FIX: ">=" - EV_EVENT_COUNT is a sentinel, not an event */
        printf("%d: invalid event %d\n", t, ev);
        return;
    }
    const EpbTransition *tr = &epb_table[state][ev];
    if (tr->action != NULL)
        tr->action(t);
    if (tr->next != state)
        printf("%d: %s -> %s\n", t, state_name[state], state_name[tr->next]);
    state = tr->next;
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    for (int i = 0; i < n; i++) {
        int t, raw;
        if (scanf("%d %d", &t, &raw) != 2) break;
        dispatch(t, raw);
    }
    printf("final %s\n", state_name[state]);
    return 0;
}
@@@ explanation_md
**Bug.** The range check is `ev > EV_EVENT_COUNT`. `EV_EVENT_COUNT` (4) is the **COUNT sentinel**, one past the last real event, so it slips through and is used as an index. `epb_table` is a 2-D array laid out row after row, so `epb_table[state][4]` is the same memory as `epb_table[state + 1][0]`:
- in `RELEASED` it reads `APPLYING/SW_PULL` = `{ APPLYING, NULL }`, and the brake goes to `APPLYING` without starting the motor;
- in `APPLYING` it reads `APPLIED/SW_PULL`, and the ECU believes the brake is applied when the motor never finished;
- in `APPLIED` it reads `RELEASING/SW_PULL` and runs *motor apply*;
- in `RELEASING` it reads **past the end of the table**: an out-of-bounds read of a function pointer (ASan: global-buffer-overflow; on target, a jump to a random address).

**Fix.** `ev >= EV_EVENT_COUNT`. Every value used as an index must satisfy `0 <= ev < COUNT`. An equivalent single check is `(unsigned)ev >= EV_EVENT_COUNT`.

**Complexity.** Time O(n), space O(1) besides the constant table.

**Common mistakes**
- Reasoning "`<= COUNT` looks right because COUNT is the last enumerator". The sentinel is a *size*, not a valid member.
- Converting `raw` to `EpbEvent` before validating and then relying on the enum type. The type does not restrict the value.
- Validating only `ev` but not `state`. If `state` can ever be corrupted (no-init RAM after a warm reset), it needs the same check.
- Assuming a sanitizer will always catch this. Indexing `[state][4]` stays inside the object for 3 of the 4 rows, so ASan only fires in the last row, while the wrong behaviour happens silently in the others.

**Interview follow-ups**
- How would you design the event enum so that an all-zeros or all-ones CAN payload can never map to a valid event? (Start valid IDs at a non-zero value and reserve `0x00`/`0xFF` as invalid.)
- Add an `E2E` (CRC + alive counter) check on the CAN message. Which class of fault does it catch that range validation cannot?
- Write a unit test that feeds every value in `-1..256` in every state and checks that the table is never read out of range. How does MC/DC coverage relate to this?
