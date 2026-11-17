@@@ meta
id: ENM-M-04
topic: Enums
difficulty: Medium
type: CODE
title: Ignition Switch State Machine OFF/ACC/ON/CRANK With Guards
tags: embedded, state-machine, ignition, guards, asked-in-automotive
@@@ statement_md
Implement the ignition (terminal / "Klemme") state machine of a body controller. The state is one of `OFF`, `ACC`, `ON` and `CRANK`. It starts in `OFF` with the brake **released** and the vehicle speed at 0.

**Transitions** (every combination that is not listed is invalid):

| from | event | guard | to |
|---|---|---|---|
| `OFF` | `KEY_ACC` | | `ACC` |
| `ACC` | `KEY_ON` | | `ON` |
| `ACC` | `KEY_OFF` | | `OFF` |
| `ON` | `KEY_ACC` | speed == 0 | `ACC` (else error `VEHICLE_MOVING`) |
| `ON` | `KEY_START` | brake pressed **and** speed == 0 | `CRANK` (else error `CRANK_INHIBITED`) |
| `CRANK` | `KEY_RELEASE` | | `ON` |

**Input events** that only update inputs and are accepted in **every** state with no output:
- `BRAKE_PRESS`, `BRAKE_RELEASE`
- `SPEED <v>` (the new vehicle speed in km/h)

A `KEY_*` event that is not in the table for the current state (for example `KEY_OFF` in `ON`, or `KEY_START` in `CRANK`) is invalid. An invalid event or a failed guard **never** changes the state.

**Input**
- Line 1: `n`. Next `n` lines: one event. `SPEED` is followed by an integer.

**Output**
- Transition: `<FROM> -> <TO>`
- Failed guard: `ERROR <REASON>: <EVENT> in <STATE>` with `REASON` = `VEHICLE_MOVING` or `CRANK_INHIBITED`
- Event not allowed in this state: `ERROR INVALID_EVENT: <EVENT> in <STATE>`
- Unknown token: `ERROR UNKNOWN_EVENT: <token>`
- At the end: `FINAL <STATE>`

**Example**
```
Input:
7
KEY_ACC
KEY_ON
KEY_START
BRAKE_PRESS
KEY_START
KEY_RELEASE
BRAKE_RELEASE

Output:
OFF -> ACC
ACC -> ON
ERROR CRANK_INHIBITED: KEY_START in ON
ON -> CRANK
CRANK -> ON
FINAL ON
```
@@@ constraints_md
- `0 <= n <= 1000`
- `0 <= v <= 300`
- Tokens are at most 15 characters and case-sensitive.
@@@ starter_code
#include <stdio.h>
#include <string.h>

typedef enum { IGN_OFF, IGN_ACC, IGN_ON, IGN_CRANK, IGN_COUNT } IgnState;

static const char *const ign_name[IGN_COUNT] = { "OFF", "ACC", "ON", "CRANK" };

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    IgnState state = IGN_OFF;
    int brake = 0, speed = 0;

    for (int i = 0; i < n; i++) {
        char ev[16];
        if (scanf("%15s", ev) != 1) break;
        if (strcmp(ev, "SPEED") == 0) {
            if (scanf("%d", &speed) != 1) break;
            continue;
        }
        /* TODO: parse the event into an enum and run the state machine */
    }
    printf("FINAL %s\n", ign_name[state]);
    (void)brake;
    return 0;
}
@@@ sample_input
7
KEY_ACC
KEY_ON
KEY_START
BRAKE_PRESS
KEY_START
KEY_RELEASE
BRAKE_RELEASE
@@@ sample_output
OFF -> ACC
ACC -> ON
ERROR CRANK_INHIBITED: KEY_START in ON
ON -> CRANK
CRANK -> ON
FINAL ON

@@@ sample_input
5
KEY_ON
KEY_ACC
KEY_OFF
KEY_OFF
HORN
@@@ sample_output
ERROR INVALID_EVENT: KEY_ON in OFF
OFF -> ACC
ACC -> OFF
ERROR INVALID_EVENT: KEY_OFF in OFF
ERROR UNKNOWN_EVENT: HORN
FINAL OFF

@@@ hidden_input
0
@@@ hidden_output
FINAL OFF

@@@ hidden_input
6
KEY_ACC
KEY_ON
SPEED 40
KEY_ACC
SPEED 0
KEY_ACC
@@@ hidden_output
OFF -> ACC
ACC -> ON
ERROR VEHICLE_MOVING: KEY_ACC in ON
ON -> ACC
FINAL ACC

@@@ hidden_input
6
BRAKE_PRESS
KEY_ACC
KEY_ON
SPEED 5
KEY_START
KEY_OFF
@@@ hidden_output
OFF -> ACC
ACC -> ON
ERROR CRANK_INHIBITED: KEY_START in ON
ERROR INVALID_EVENT: KEY_OFF in ON
FINAL ON

@@@ hidden_input
7
BRAKE_PRESS
KEY_ACC
KEY_ON
KEY_START
KEY_OFF
KEY_START
KEY_RELEASE
@@@ hidden_output
OFF -> ACC
ACC -> ON
ON -> CRANK
ERROR INVALID_EVENT: KEY_OFF in CRANK
ERROR INVALID_EVENT: KEY_START in CRANK
CRANK -> ON
FINAL ON

@@@ hidden_input
6
KEY_ACC
KEY_ON
BRAKE_PRESS
BRAKE_RELEASE
KEY_START
KEY_RELEASE
@@@ hidden_output
OFF -> ACC
ACC -> ON
ERROR CRANK_INHIBITED: KEY_START in ON
ERROR INVALID_EVENT: KEY_RELEASE in ON
FINAL ON

@@@ hidden_input
9
BRAKE_PRESS
KEY_ACC
KEY_ON
KEY_START
KEY_RELEASE
KEY_ACC
KEY_OFF
KEY_RELEASE
KEY_ACC
@@@ hidden_output
OFF -> ACC
ACC -> ON
ON -> CRANK
CRANK -> ON
ON -> ACC
ACC -> OFF
ERROR INVALID_EVENT: KEY_RELEASE in OFF
OFF -> ACC
FINAL ACC

@@@ hidden_input
3
key_acc
KEY_ACC
KEY_ACC
@@@ hidden_output
ERROR UNKNOWN_EVENT: key_acc
OFF -> ACC
ERROR INVALID_EVENT: KEY_ACC in ACC
FINAL ACC

@@@ hint
Convert the token into an `IgnEvent` enum first, using a small table of `{ "KEY_ACC", EV_KEY_ACC }` pairs. Handle the input-only events (`BRAKE_*`, `SPEED`) before the state machine, since they are legal in every state.
@@@ hint
`switch (state)`, and inside each case `if`/`switch` on the event. Use one helper for transitions and one for errors. Any event that falls through all the checks for that state is `INVALID_EVENT`. A clean pattern is to start with `IgnState next = state; const char *err = "INVALID_EVENT";` and set them in the cases.
@@@ solution_code
#include <stdio.h>
#include <string.h>

typedef enum { IGN_OFF, IGN_ACC, IGN_ON, IGN_CRANK, IGN_COUNT } IgnState;
typedef enum {
    EV_KEY_ACC, EV_KEY_ON, EV_KEY_START, EV_KEY_RELEASE, EV_KEY_OFF,
    EV_BRAKE_PRESS, EV_BRAKE_RELEASE, EV_COUNT, EV_UNKNOWN = EV_COUNT
} IgnEvent;

static const char *const ign_name[IGN_COUNT] = { "OFF", "ACC", "ON", "CRANK" };
static const char *const ev_name[EV_COUNT] = {
    "KEY_ACC", "KEY_ON", "KEY_START", "KEY_RELEASE", "KEY_OFF", "BRAKE_PRESS", "BRAKE_RELEASE"
};

static IgnEvent parse_event(const char *s)
{
    for (int e = 0; e < EV_COUNT; e++)
        if (strcmp(s, ev_name[e]) == 0) return (IgnEvent)e;
    return EV_UNKNOWN;
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    IgnState state = IGN_OFF;
    int brake = 0, speed = 0;

    for (int i = 0; i < n; i++) {
        char tok[16];
        if (scanf("%15s", tok) != 1) break;
        if (strcmp(tok, "SPEED") == 0) {
            if (scanf("%d", &speed) != 1) break;
            continue;
        }
        IgnEvent ev = parse_event(tok);
        if (ev == EV_UNKNOWN) { printf("ERROR UNKNOWN_EVENT: %s\n", tok); continue; }
        if (ev == EV_BRAKE_PRESS)   { brake = 1; continue; }
        if (ev == EV_BRAKE_RELEASE) { brake = 0; continue; }

        IgnState next = state;
        const char *err = "INVALID_EVENT";   /* default verdict if nothing matches */

        switch (state) {
        case IGN_OFF:
            if (ev == EV_KEY_ACC) next = IGN_ACC;
            break;
        case IGN_ACC:
            if (ev == EV_KEY_ON) next = IGN_ON;
            else if (ev == EV_KEY_OFF) next = IGN_OFF;
            break;
        case IGN_ON:
            if (ev == EV_KEY_ACC) {
                if (speed == 0) next = IGN_ACC;
                else err = "VEHICLE_MOVING";
            } else if (ev == EV_KEY_START) {
                if (brake && speed == 0) next = IGN_CRANK;
                else err = "CRANK_INHIBITED";
            }
            break;
        case IGN_CRANK:
            if (ev == EV_KEY_RELEASE) next = IGN_ON;
            break;
        case IGN_COUNT:
            break;
        }

        if (next != state) {
            printf("%s -> %s\n", ign_name[state], ign_name[next]);
            state = next;
        } else {
            printf("ERROR %s: %s in %s\n", err, ev_name[ev], ign_name[state]);
        }
    }
    printf("FINAL %s\n", ign_name[state]);
    return 0;
}
@@@ explanation_md
**Approach.** Split the inputs into two kinds.
- **Input events** (`BRAKE_*`, `SPEED`) only update the context variables the guards read. They are legal in every state, so handle them before the FSM.
- **Key events** drive the FSM: `switch (state)`, then check the event. Each state lists only its legal events. Anything else falls out with the default verdict `INVALID_EVENT`. A guard failure overrides that verdict with its specific reason.

Starting from `next = state` and a default error, and then printing based on whether `next != state`, gives every path exactly one output line. This is easy to review against the requirement table, which is what an ASPICE review does.

**Complexity.** Time O(n · E) for the string parsing (E = 7 event names), O(1) per FSM step. Space O(1).

**Common mistakes**
- Changing state before checking the guard, or reporting an error **and** changing state. Invalid events must leave the state unchanged.
- Making `CRANK` reachable from `ACC` or `OFF`, or ignoring the speed guard. Cranking a moving vehicle can damage the starter. Real systems also require the gear to be in `P`/`N`.
- Forgetting that `BRAKE_PRESS` is legal in `CRANK` and `OFF` too, and reporting it as invalid.
- `switch (ev)` with a missing `break` so that `KEY_ACC` falls into `KEY_ON`'s case. That gives a double transition `OFF -> ACC -> ON` from one event.

**Interview follow-ups**
- Add a crank timeout: if `CRANK` lasts longer than 3 s, return to `ON` and set a DTC. How do you get time into the FSM?
- How would you redesign this as a table (state × event → guard, next) instead of nested `switch`es?
- With push-button start there is no `KEY_RELEASE`. Which events and guards change, and where do you put the "engine running" feedback from the ECM?
- How do you make sure a CAN message saying "ignition ON" from a different ECU never contradicts this local state?
